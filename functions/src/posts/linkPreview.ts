import { onCall, HttpsError } from "firebase-functions/v2/https";
import { randomUUID, createHash } from "crypto";
import { lookup } from "dns/promises";
import { isIP } from "net";
import { getStorage } from "firebase-admin/storage";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { tierOf } from "../stickers/stickers";

/**
 * Aperçu d'un lien collé dans un post texte (YouTube, TikTok, Instagram, Facebook, sites web) : titre, description,
 * image, auteur. Lu côté serveur (le téléphone et le web ne peuvent pas lire ces pages), avec :
 *  - uniquement http(s), jamais d'adresse interne (protection contre l'accès au réseau de Google),
 *  - redirections suivies à la main, taille et durée limitées,
 *  - l'image est recopiée dans Firebase Storage (les images de TikTok / Instagram expirent),
 *  - aperçu de post / message : réservé aux membres Gold (contrôlé ici) ; carte « lien » du Studio : ouverte à tous ;
 *  - une petite limite par personne et par heure.
 */

export interface LinkPreview {
  url: string;
  title: string;
  description: string;
  image: string;
  siteName: string;
  provider: string;
  author: string;
  isVideo: boolean;
}

const UA = "Mozilla/5.0 (compatible; AfrolookLinkPreview/1.0; +https://afrolookmedia.com)";
const FB_UA = "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uagent.php)";
const MAX_HTML = 1_500_000;
const MAX_IMAGE = 3_000_000;
const MAX_PER_HOUR = 40;
const MAX_PER_HOUR_CARD = 20;
const CACHE_MS = 24 * 3600_000;

// ── Outils purs (testés) ────────────────────────────────────────────────────

/** Première adresse web trouvée dans un texte (sans la ponctuation finale). */
export function firstUrl(text: string): string | null {
  const m = String(text ?? "").match(/https?:\/\/[^\s<>"']+/i);
  if (!m) return null;
  return m[0].replace(/[).,;:!?»”]+$/g, "");
}

export function isPrivateIp(ip: string): boolean {
  if (isIP(ip) === 4) {
    const [a, b] = ip.split(".").map(Number);
    return a === 10 || a === 127 || a === 0 || (a === 169 && b === 254) || (a === 172 && b >= 16 && b <= 31) || (a === 192 && b === 168) || (a === 100 && b >= 64 && b <= 127) || a >= 224;
  }
  if (isIP(ip) === 6) {
    const l = ip.toLowerCase();
    if (l === "::1" || l === "::") return true;
    if (l.startsWith("fc") || l.startsWith("fd") || l.startsWith("fe8") || l.startsWith("fe9") || l.startsWith("fea") || l.startsWith("feb")) return true;
    const v4 = l.match(/^::ffff:(\d+\.\d+\.\d+\.\d+)$/);
    return v4 ? isPrivateIp(v4[1]) : false;
  }
  return true;
}

export function providerOf(host: string): string {
  const h = host.toLowerCase().replace(/^www\./, "");
  if (h === "youtu.be" || h.endsWith("youtube.com")) return "youtube";
  if (h.endsWith("tiktok.com")) return "tiktok";
  if (h.endsWith("instagram.com") || h === "instagr.am") return "instagram";
  if (h.endsWith("facebook.com") || h === "fb.watch" || h === "fb.me") return "facebook";
  if (h === "x.com" || h.endsWith("twitter.com")) return "x";
  return "web";
}

const SITE_NAMES: Record<string, string> = { youtube: "YouTube", tiktok: "TikTok", instagram: "Instagram", facebook: "Facebook", x: "X" };

const decode = (s: string) =>
  s.replace(/&amp;/g, "&").replace(/&quot;/g, '"').replace(/&#0?39;|&apos;/g, "'").replace(/&lt;/g, "<").replace(/&gt;/g, ">")
    .replace(/&#x([0-9a-f]+);/gi, (_, h) => String.fromCodePoint(parseInt(h, 16))).replace(/&#(\d+);/g, (_, d) => String.fromCodePoint(parseInt(d, 10)));

/** Lit les balises <meta> (Open Graph, Twitter) et <title> d'une page. */
export function parseMeta(html: string): Record<string, string> {
  const out: Record<string, string> = {};
  for (const tag of html.match(/<meta\s+[^>]*>/gi) ?? []) {
    const key = (tag.match(/(?:property|name)\s*=\s*["']([^"']+)["']/i) ?? [])[1];
    const val = (tag.match(/content\s*=\s*"([^"]*)"/i) ?? tag.match(/content\s*=\s*'([^']*)'/i) ?? [])[1];
    if (key && val !== undefined && !(key.toLowerCase() in out)) out[key.toLowerCase()] = decode(val).trim();
  }
  const t = html.match(/<title[^>]*>([^<]*)<\/title>/i);
  if (t) out["_title"] = decode(t[1]).trim();
  return out;
}

const clip = (s: string | undefined, n: number) => {
  const v = String(s ?? "").replace(/\s+/g, " ").trim();
  return v.length > n ? v.slice(0, n - 1) + "…" : v;
};

// ── Réseau ──────────────────────────────────────────────────────────────────

async function assertPublic(u: URL) {
  if (!/^https?:$/.test(u.protocol)) throw new Error("protocole refusé");
  if (u.username || u.password) throw new Error("identifiants refusés");
  if (u.port && !["80", "443"].includes(u.port)) throw new Error("port refusé");
  const host = u.hostname.replace(/^\[|\]$/g, "");
  if (host === "localhost" || host.endsWith(".local") || host.endsWith(".internal")) throw new Error("hôte refusé");
  const addrs = isIP(host) ? [{ address: host }] : await lookup(host, { all: true });
  if (!addrs.length || addrs.some((a) => isPrivateIp(a.address))) throw new Error("adresse refusée");
}

async function fetchLimited(url: string, opts: { ua: string; max: number; accept?: string }): Promise<{ finalUrl: string; type: string; body: Buffer }> {
  let cur = new URL(url);
  for (let hop = 0; hop < 5; hop++) {
    await assertPublic(cur);
    const ctl = new AbortController();
    const timer = setTimeout(() => ctl.abort(), 6000);
    try {
      const res = await fetch(cur.toString(), { redirect: "manual", signal: ctl.signal, headers: { "user-agent": opts.ua, accept: opts.accept ?? "text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.5", "accept-language": "fr,en;q=0.8" } });
      if (res.status >= 300 && res.status < 400 && res.headers.get("location")) {
        cur = new URL(res.headers.get("location")!, cur);
        continue;
      }
      if (!res.ok) throw new Error(`http ${res.status}`);
      const reader = res.body!.getReader();
      const chunks: Buffer[] = [];
      let n = 0;
      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        n += value.length;
        if (n > opts.max) { await reader.cancel(); break; }
        chunks.push(Buffer.from(value));
      }
      return { finalUrl: cur.toString(), type: res.headers.get("content-type") ?? "", body: Buffer.concat(chunks) };
    } finally {
      clearTimeout(timer);
    }
  }
  throw new Error("trop de redirections");
}

async function getJson(url: string): Promise<Record<string, unknown> | null> {
  try {
    const r = await fetchLimited(url, { ua: UA, max: 200_000, accept: "application/json" });
    return JSON.parse(r.body.toString("utf8"));
  } catch {
    return null;
  }
}

async function storeImage(imageUrl: string, key: string): Promise<string> {
  try {
    const r = await fetchLimited(imageUrl, { ua: UA, max: MAX_IMAGE, accept: "image/*" });
    if (!/^image\/(jpeg|png|webp|gif)/i.test(r.type) || r.body.length < 500) return "";
    const ext = r.type.includes("png") ? "png" : r.type.includes("webp") ? "webp" : r.type.includes("gif") ? "gif" : "jpg";
    const path = `link_previews/${key}.${ext}`;
    const token = randomUUID();
    const bucket = getStorage().bucket();
    await bucket.file(path).save(r.body, { contentType: r.type.split(";")[0], metadata: { cacheControl: "public,max-age=31536000", metadata: { firebaseStorageDownloadTokens: token } } });
    return `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(path)}?alt=media&token=${token}`;
  } catch (e) {
    console.warn("[linkPreview] image non copiée", e);
    return "";
  }
}

export async function buildPreview(rawUrl: string): Promise<LinkPreview | null> {
  let u: URL;
  try { u = new URL(rawUrl); } catch { return null; }
  await assertPublic(u);
  let provider = providerOf(u.hostname);
  let pageUrl = u.toString();
  const p: LinkPreview = { url: pageUrl, title: "", description: "", image: "", siteName: SITE_NAMES[provider] ?? u.hostname.replace(/^www\./, ""), provider, author: "", isVideo: provider === "youtube" || provider === "tiktok" };

  // La page (balises Open Graph) : liens courts suivis, ce qui donne aussi l'adresse finale.
  let meta: Record<string, string> = {};
  try {
    const page = await fetchLimited(pageUrl, { ua: provider === "instagram" || provider === "facebook" ? FB_UA : UA, max: MAX_HTML });
    if (/html/i.test(page.type)) meta = parseMeta(page.body.toString("utf8"));
    pageUrl = page.finalUrl;
    provider = providerOf(new URL(pageUrl).hostname);
    p.url = pageUrl.length <= 500 ? pageUrl : rawUrl;
    p.provider = provider;
    p.siteName = meta["og:site_name"] || SITE_NAMES[provider] || p.siteName;
  } catch (e) {
    console.warn("[linkPreview] page illisible", (e as Error).message);
  }

  let image = meta["og:image"] || meta["twitter:image"] || "";
  p.title = meta["og:title"] || meta["twitter:title"] || meta["_title"] || "";
  p.description = meta["og:description"] || meta["twitter:description"] || meta["description"] || "";
  if (/video/i.test(meta["og:type"] ?? "") || meta["og:video"] || meta["og:video:url"]) p.isVideo = true;

  // Services qui donnent l'aperçu par oEmbed (sans clé) : plus fiable que la page.
  if (provider === "youtube" || provider === "tiktok") {
    const endpoint = provider === "youtube" ? "https://www.youtube.com/oembed" : "https://www.tiktok.com/oembed";
    const o = await getJson(`${endpoint}?url=${encodeURIComponent(pageUrl)}&format=json`);
    if (o) {
      p.title = String(o["title"] ?? "") || p.title;
      p.author = String(o["author_name"] ?? "");
      image = String(o["thumbnail_url"] ?? "") || image;
    }
    p.isVideo = true;
  }
  if (provider === "youtube" && !image) {
    const id = u.hostname.includes("youtu.be") ? u.pathname.slice(1) : u.searchParams.get("v") ?? "";
    if (/^[\w-]{6,20}$/.test(id)) image = `https://i.ytimg.com/vi/${id}/hqdefault.jpg`;
  }

  p.title = clip(p.title, 140);
  p.description = clip(p.description, 240);
  p.author = clip(p.author, 80);
  if (provider === "instagram" && !p.title) p.title = "Publication Instagram";
  if (provider === "facebook" && !p.title) p.title = "Publication Facebook";
  if (!p.title && !image) return null;
  if (image) {
    try {
      const abs = new URL(image, pageUrl).toString();
      p.image = await storeImage(abs, createHash("sha1").update(abs).digest("hex"));
    } catch { /* sans image */ }
  }
  return p;
}

export const fetchLinkPreview = onCall({ region: "us-central1", timeoutSeconds: 30, memory: "256MiB", maxInstances: 10 }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Connexion requise.");
  // Deux usages : l'aperçu d'un post ou d'un message (réservé aux membres Gold et à l'administrateur, contrôlé ici),
  // et la carte « lien » du Studio (ouverte à tous : la carte a son propre quota et ses propres prix).
  const forCard = request.data?.purpose === "card";
  if (!forCard) {
    const userDoc = await db.collection("Users").doc(uid).get();
    if (tierOf(userDoc.data()) !== "gold") throw new HttpsError("permission-denied", "Réservé aux membres Gold.");
  }
  const url = firstUrl(String(request.data?.url ?? "")) ?? "";
  if (!url || url.length > 600) throw new HttpsError("invalid-argument", "Lien invalide.");

  // limite par personne et par heure (compteur séparé pour les cartes)
  const ref = db.collection("LinkPreviewLimits").doc(forCard ? `${uid}_card` : uid);
  const max = forCard ? MAX_PER_HOUR_CARD : MAX_PER_HOUR;
  const ok = await db.runTransaction(async (tx) => {
    const s = await tx.get(ref);
    const d = s.data() as { start?: number; n?: number } | undefined;
    const now = Date.now();
    const fresh = !d?.start || now - d.start > 3600_000;
    const n = fresh ? 0 : d?.n ?? 0;
    if (n >= max) return false;
    tx.set(ref, { start: fresh ? now : d!.start, n: n + 1, updatedAt: FieldValue.serverTimestamp() });
    return true;
  });
  if (!ok) throw new HttpsError("resource-exhausted", "Trop d'aperçus demandés, réessaie dans un moment.");

  const cacheRef = db.collection("LinkPreviews").doc(createHash("sha1").update(url).digest("hex"));
  const cached = await cacheRef.get();
  const c = cached.data() as { preview?: LinkPreview; at?: number } | undefined;
  if (c?.preview && c.at && Date.now() - c.at < CACHE_MS) return { preview: c.preview };

  let preview: LinkPreview | null = null;
  try {
    preview = await buildPreview(url);
  } catch (e) {
    console.warn("[linkPreview] refusé", url, (e as Error).message);
    throw new HttpsError("invalid-argument", "Ce lien ne peut pas être affiché.");
  }
  if (!preview) return { preview: null };
  await cacheRef.set({ preview, at: Date.now() }).catch(() => undefined);
  return { preview };
});
