import { onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { randomBytes } from "crypto";
import { db } from "../shared/firebase";
import { getAppCheck } from "firebase-admin/app-check";
import { getAuth } from "firebase-admin/auth";
import { notifyAdminsAll } from "../shared/user_notify";
import { fetchLimited } from "../posts/linkPreview";
import { pageHasToken } from "./adsPublishers_logic";
import { hllAdd, hllNew, hllToB64, hllCount } from "./adsHll";
import { dayStr, measure, summaryOf } from "./adsMeasure";
import { INTERNAL_ACCEPT, STANDARD_KEYS, categoryAllowed } from "./adsCategories";
import { deliveryAllowed } from "./adsGuard";
import { GeoCount, INTERNAL_CATEGORY, Targeting, deviceOf, geoAllowed, geoMatch, langOf, profileMatches, targetingOf } from "./adsTargeting";

// pays du visiteur d'après son adresse IP (base de pays embarquée : aucun service extérieur, aucune donnée envoyée)
// eslint-disable-next-line @typescript-eslint/no-require-imports
const geoip: { lookup(ip: string): { country: string } | null } = require("geoip-country");
const geoOfIp = (ip: string): { cc: string | null } => { try { const r = geoip.lookup(ip); return { cc: r && /^[A-Z]{2}$/.test(r.country) ? r.country : null }; } catch { return { cc: null }; } };
import { previewOf, splitAdText } from "./adsWeb";
import { BANNER_SIZES, bannerKeyOf } from "./adsWeb_logic";
import {
  FORMATS, INTERNAL_PUBLISHERS, Invalid, Publisher, adFitsFormat, clickDecision, completeDecision, ipHash, isBotAgent, newNonce, pickAd, publisherHealth,
  shardId, shardOf, signToken, validFormat, validPubId, validSlot, validVid, verifyToken, viewDecision, visitorHash, DeviceDay,
} from "./adsEngine_logic";

/**
 * Afrolook Ads : moteur unique (étape 1). Même chemin pour toutes les plateformes (application Afrolook, nos sites, sites et applications de diffuseurs).
 *  - adsServe : choisit UNE annonce validée pour un emplacement et la livre avec un jeton signé ;
 *  - adsEvent : enregistre une vue (ou une lecture complète) prouvée par le jeton ; tout le reste est « invalide » ;
 *  - adsGo    : redirection de clic (compte le clic puis renvoie vers le lien validé de l'annonce : la destination n'est jamais chez le diffuseur) ;
 *  - adsRollup (toutes les 5 min) : cumule les compteurs répartis dans Advertisements et AdsDaily ;
 *  - adsCleanup (chaque jour) : supprime les traces temporaires ; adsHealth (chaque jour) : santé des diffuseurs (trafic invalide).
 * Les anciens points (adsWebPublic, adsWebTrack) restent en service pendant la migration des plateformes.
 */
const OPTS = { region: "us-central1" as const, memory: "256MiB" as const };
const BASE = "https://us-central1-afrolooki.cloudfunctions.net";
const ABOUT = "https://afrolookmedia.com/ads/";
const DAY = (t = Date.now()): string => new Date(t).toISOString().slice(0, 10);

// ─── Clé de signature (générée une fois, jamais dans le dépôt) ──────────────────────────────────────────────────────

let keyCache: string | null = null;
export async function signingKey(): Promise<string> {
  if (keyCache) return keyCache;
  const ref = db.collection("AdsSecure").doc("signing");
  let key = (await ref.get()).data()?.["key"] as string | undefined;
  if (!key) {
    const fresh = randomBytes(32).toString("hex");
    try { await ref.create({ key: fresh, createdAt: Date.now() }); key = fresh; } catch { key = (await ref.get()).data()?.["key"] as string; }
  }
  keyCache = String(key);
  return keyCache;
}

// ─── Diffuseurs ─────────────────────────────────────────────────────────────────────────────────────────────────────

interface Pub extends Publisher { origins: string[]; countries: string[]; formats: string[]; category: string; accept: Set<string> }
const pubCache = new Map<string, { at: number; v: Pub | null }>();
async function publisherOf(id: string): Promise<Pub | null> {
  const c = pubCache.get(id);
  if (c && Date.now() - c.at < 60_000) return c.v;
  let v: Pub | null = null;
  if (INTERNAL_PUBLISHERS[id]) v = { ...INTERNAL_PUBLISHERS[id], origins: [], countries: [], formats: [], category: INTERNAL_CATEGORY[id] ?? "", accept: new Set(INTERNAL_ACCEPT[id] ?? STANDARD_KEYS) };
  else if (/^ap_[a-z0-9]{10}$/.test(id)) {
    const p = (await db.collection("AdProperties").doc(id).get()).data();
    if (p && p["status"] === "active") v = { id, kind: "external", name: String(p["name"] ?? id), status: "active", origins: (p["kind"] === "site" ? (p["origins"] as string[]) : []) ?? [], countries: [], formats: (p["formats"] as string[]) ?? [], category: String(p["category"] ?? ""), accept: new Set(Array.isArray(p["acceptedCategories"]) && (p["acceptedCategories"] as string[]).length ? (p["acceptedCategories"] as string[]) : STANDARD_KEYS) };
  }
  pubCache.set(id, { at: Date.now(), v });
  return v;
}
/** Un site externe ne peut appeler que depuis son propre domaine (l'en-tête Origin est envoyé par tous les navigateurs pour ces appels). */
function originOk(pub: Pub, origin: unknown): boolean {
  if (pub.kind === "internal" || !pub.origins.length) return true;
  return typeof origin === "string" && pub.origins.includes(origin);
}

/** Applications : la demande doit venir de l'application authentique (Firebase App Check). Sans cela, n'importe qui pourrait se faire passer pour l'application. */
const APP_PUBS = new Set(["afrolook", "epargneplus"]);
async function appOk(pub: Pub, token: unknown): Promise<boolean> {
  if (!APP_PUBS.has(pub.id)) return true;
  if (typeof token !== "string" || token.length < 20) return false;
  try { await getAppCheck().verifyToken(token); return true; } catch { return false; }
}
/** Application Afrolook : le visiteur est l'UTILISATEUR CONNECTÉ (jeton d'identité vérifié par le serveur), jamais un identifiant envoyé par l'appareil. Une personne = au plus 3 vues par annonce et par jour, quel que soit le téléphone. */
async function appUid(req: { headers: Record<string, unknown> }): Promise<string | null> {
  const m = /^Bearer (.{20,})$/.exec(String(req.headers["authorization"] ?? ""));
  if (!m) return null;
  try { return (await getAuth().verifyIdToken(m[1])).uid; } catch { return null; }
}
// ─── Annonces servables (cache de 60 s) ─────────────────────────────────────────────────────────────

interface Servable { id: string; title: string; text: string; video: boolean; images: string[]; thumb: string; media: string; action: string; url: string; network: boolean; targeting: Targeting; category: string; duration: number; budgetViews: number; startMs: number; endMs: number; viewsTotal: number; banners: Record<string, string> }
/** Bannières prêtes d'une annonce : seulement des images de notre stockage, aux tailles connues. */
function bannersOf(v: unknown): Record<string, string> {
  const out: Record<string, string> = {};
  if (v && typeof v === "object") for (const k of Object.keys(BANNER_SIZES)) { const u = (v as Record<string, unknown>)[k]; if (typeof u === "string" && /^https:\/\/firebasestorage\.googleapis\.com\//.test(u)) out[k] = u; }
  return out;
}
let adsCache: { at: number; items: Servable[] } | null = null;
async function loadServable(): Promise<Servable[]> {
  if (adsCache && Date.now() - adsCache.at < 60_000) return adsCache.items;
  const t = Date.now() * 1000;
  const snap = await db.collection("Advertisements").where("status", "==", "active").where("endDate", ">", t).limit(80).get();
  const ads = snap.docs.map((d) => ({ id: d.id, a: d.data() })).filter((x) => x.a["postId"] && !["defi", "route"].includes(String(x.a["actionType"] ?? "")) && x.a["hidden"] !== true);
  const posts = ads.length ? await db.getAll(...ads.map((x) => db.collection("Posts").doc(String(x.a["postId"])))) : [];
  const items: Servable[] = [];
  let build = 3;
  for (let i = 0; i < ads.length; i++) {
    const x = ads[i], p = posts[i]?.data();
    if (!p) continue;
    const video = String(p["dataType"] ?? "").toUpperCase() === "VIDEO";
    let images = Array.isArray(p["images"]) ? (p["images"] as string[]).filter(Boolean) : [];
    if (!video && !images.length && typeof p["url_media"] === "string" && p["url_media"]) images = [p["url_media"] as string];
    const { title, text } = splitAdText(x.a, String(p["description"] ?? ""));
    const action = String(x.a["actionType"] ?? "");
    const url = action && action !== "none" ? String(x.a["actionUrl"] ?? "") : "";
    let media = video ? String(p["url_media"] ?? "") : images[0] ?? "";
    let thumb = video ? String(p["thumbnail"] ?? "") : images[0] ?? "";
    // annonce sans image : image de la page du lien (aperçu), construit au plus 3 fois par rafraîchissement puis gardé 24 h
    if (!media && /^https:\/\//.test(url)) {
      const pv = await previewOf(url, build-- > 0);
      if (pv?.image) { media = pv.image; thumb = pv.image; images = [pv.image]; }
    }
    if (!media) continue;
    items.push({
      id: x.id, title, text: text.slice(0, 220), video, images: images.slice(0, 5), thumb, media, action: action && action !== "none" ? String(x.a["actionButtonText"] ?? "") : "", url: /^https:\/\//.test(url) ? url : "",
      network: x.a["network"] === true, targeting: targetingOf(x.a, p["available_countries"]), category: String(x.a["adCategory"] ?? ""), duration: Number(x.a["videoDuration"]) || 0,
      banners: bannersOf(x.a["bannerImages"]), budgetViews: Number(x.a["budgetViews"]) || 0, startMs: (Number(x.a["startDate"]) || 0) / 1000, endMs: (Number(x.a["endDate"]) || 0) / 1000, viewsTotal: Number(x.a["views"]) || 0,
    });
  }
  adsCache = { at: Date.now(), items };
  return items;
}

// ─── Ciblage par pays : au plus 40 % de vues hors cible ─────────────────────────────────────────────────────────────

const ZERO: GeoCount = { in: 0, out: 0, unknown: 0 };
let geoCache: { at: number; map: Map<string, GeoCount> } | null = null;
/** Vues valides d'aujourd'hui par annonce (relues avec les statistiques de pays) et annonces servies par CETTE instance aujourd'hui : le cumul officiel a jusqu'à 5 minutes de retard, le compteur local freine les rafales. */
const dayViews = new Map<string, number>();
const servedLocal = new Map<string, { day: string; n: number }>();
const localServed = (id: string): number => { const e = servedLocal.get(id); return e && e.day === DAY() ? e.n : 0; };
function bumpServed(id: string): void { const e = servedLocal.get(id); servedLocal.set(id, e && e.day === DAY() ? { day: e.day, n: e.n + 1 } : { day: DAY(), n: 1 }); if (servedLocal.size > 4000) servedLocal.clear(); }
/** Vues valides par annonce sur aujourd'hui et hier (dans la cible, hors cible, pays inconnu), relues chaque minute dans AdsDaily. */
async function geoStats(): Promise<Map<string, GeoCount>> {
  if (geoCache && Date.now() - geoCache.at < 60_000) return geoCache.map;
  const map = new Map<string, GeoCount>();
  dayViews.clear();
  try {
    const snap = await db.collection("AdsDaily").where("day", "in", [DAY(), DAY(Date.now() - 86_400_000)]).limit(3000).get();
    for (const d of snap.docs) {
      const v = d.data(), id = String(v["adId"]);
      const c = map.get(id) ?? { in: 0, out: 0, unknown: 0 };
      c.in += Number(v["geoIn"]) || 0; c.out += Number(v["geoOut"]) || 0; c.unknown += Number(v["geoUnk"]) || 0;
      if (v["day"] === DAY()) dayViews.set(id, (dayViews.get(id) ?? 0) + (Number(v["views"]) || 0));
      map.set(id, c);
    }
  } catch (e) { console.error("[geoStats]", e); }
  geoCache = { at: Date.now(), map };
  return map;
}
/** Une diffusion hors cible vient d'être décidée : on la compte tout de suite en mémoire (le cumul officiel n'arrive que toutes les 5 minutes). */
function bumpOff(adId: string, m: "out" | "unknown"): void {
  if (!geoCache) return;
  const c = geoCache.map.get(adId) ?? { in: 0, out: 0, unknown: 0 };
  c[m]++; geoCache.map.set(adId, c);
}

// ─── Limiteur de débit (par instance, freine les rafales) ───────────────────────────────────────────────────────────

const hits = new Map<string, number[]>();
function limited(k: string, max: number, windowMs: number): boolean {
  const t = Date.now();
  const arr = (hits.get(k) ?? []).filter((x) => t - x < windowMs);
  arr.push(t);
  hits.set(k, arr);
  if (hits.size > 8000) hits.clear();
  return arr.length > max;
}
/** Appel avec l'identifiant d'un site depuis un autre domaine : refusé, et compté (visible par l'administration, sans toucher au taux de trafic invalide du site). */
async function countForeign(pubId: string, ip: string): Promise<void> {
  if (limited(`f:${ip}`, 30, 60_000)) return;
  await db.collection("AdsPubDaily").doc(`${pubId}_${DAY()}`).set({ day: DAY(), pub: pubId, foreign: FieldValue.increment(1) }, { merge: true }).catch(() => undefined);
}
const clientIp = (req: { headers: Record<string, unknown>; ip?: string }): string => String(req.headers["x-forwarded-for"] ?? req.ip ?? "").split(",")[0].trim();
const bodyOf = (req: { body?: unknown; query?: Record<string, unknown> }): Record<string, unknown> => {
  try { if (typeof req.body === "string" && req.body) return JSON.parse(req.body) as Record<string, unknown>; } catch { /* corps invalide */ }
  return { ...(req.query ?? {}), ...((typeof req.body === "object" && req.body) ? (req.body as Record<string, unknown>) : {}) };
};

// ─── Servir une annonce ─────────────────────────────────────────────────────────────────────────────────────────────

export const adsServe = onRequest({ ...OPTS, cors: true, timeoutSeconds: 15, maxInstances: 30 }, async (req, res) => {
  if (req.method !== "GET" && req.method !== "POST") { res.status(405).send("Method Not Allowed"); return; }
  res.set("Cache-Control", "no-store");
  try {
    const q = bodyOf(req);
    const pubId = validPubId(q["pub"]), fmt = validFormat(q["fmt"]), slot = validSlot(q["slot"]);
    let vid = String(q["vid"] ?? "");
    if (!pubId || !fmt || !validVid(vid)) { res.status(400).json({ ok: false, error: "parametres" }); return; }
    const pub = await publisherOf(pubId);
    if (!pub || pub.status !== "active") { res.status(403).json({ ok: false, error: "diffuseur" }); return; }
    if (!originOk(pub, req.headers["origin"])) { await countForeign(pubId, clientIp(req)); res.status(403).json({ ok: false, error: "origine" }); return; }
    if (!(await appOk(pub, req.headers["x-firebase-appcheck"]))) { res.status(403).json({ ok: false, error: "app_non_verifiee" }); return; }
    if (pubId === "afrolook") { const uid = await appUid(req); if (!uid) { res.status(401).json({ ok: false, error: "connexion" }); return; } vid = uid; }
    if (isBotAgent(req.headers["user-agent"])) { res.json({ ok: true, ad: null }); return; }
    const ip = clientIp(req);
    if (limited(`s:${ip}`, 90, 60_000) || limited(`sv:${vid}`, 40, 60_000)) { res.status(429).json({ ok: false, error: "trop_de_demandes" }); return; }
    if (pub.formats.length && !pub.formats.includes(fmt)) { res.json({ ok: true, ad: null }); return; }

    const key = await signingKey();
    const day = DAY();
    const vh = visitorHash(vid, pubId, key);
    const devRef = db.collection("AdsCaps").doc(`${vh}_${day}`);
    const dev = (await devRef.get()).data() as DeviceDay | undefined;
    // audience mesurée : le visiteur est noté dès que la balise ou le composant se charge, qu'une annonce soit servie ou non (résumé chaque nuit dans AdsHll)
    const g = geoOfIp(ip);
    devRef.set({ pub: pubId, day, srv: FieldValue.increment(1), ...(g.cc ? { cc: g.cc } : {}) }, { merge: true }).catch(() => undefined);
    // ciblage défini par l'annonceur : pays (déterminé par NOTRE serveur, jamais par le site diffuseur), langue, appareil, type de site
    const ctx = { lang: langOf(q["lang"], req.headers["accept-language"]), device: deviceOf(req.headers["user-agent"]), category: pub.category };
    const items = await loadServable();
    const gs = await geoStats();
    const cands = items.filter((it) => adFitsFormat({ video: it.video, images: it.images.length }, fmt)
      && (pub.kind === "internal" || it.network)
      && categoryAllowed(it.category, pub.accept, pub.kind === "internal") // seulement les catégories que le diffuseur accepte
      && profileMatches(it.targeting, ctx)
      && geoAllowed(geoMatch(it.targeting, g.cc), gs.get(it.id) ?? ZERO)
      && deliveryAllowed({ budgetViews: it.budgetViews, startMs: it.startMs, endMs: it.endMs, viewsTotal: it.viewsTotal + localServed(it.id), viewsToday: Math.max(dayViews.get(it.id) ?? 0, localServed(it.id)) })); // budget total et lissage
    // l'application garde son propre choix d'annonce (pubs liées aux posts, boosts) : elle demande seulement le jeton de COMPTAGE de l'annonce qu'elle affiche
    const hint = pubId === "afrolook" ? String(q["ad"] ?? "") : "";
    // taille demandée (ex. 728x90, 320x50) : les annonces qui ont une bannière prête à cette taille passent en premier (elles ont une création faite pour l'emplacement)
    const sizeKey = bannerKeyOf(q["size"]);
    const withBanner = sizeKey ? cands.filter((c) => c.banners[sizeKey]) : [];
    const ad = hint ? await hintedAd(hint) : pickAd(withBanner.length ? withBanner : cands, dev, Math.random());
    if (!ad) { res.json({ ok: true, ad: null }); return; }
    bumpServed(ad.id);
    const gm = geoMatch(ad.targeting, g.cc);
    if (gm === "out" || gm === "unknown") bumpOff(ad.id, gm);

    const def = FORMATS[fmt];
    const token = signToken({ v: 1, a: ad.id, p: pubId, s: slot, f: fmt, t: Date.now(), n: newNonce(), g: gm === "any" ? "a" : gm === "in" ? "i" : gm === "out" ? "o" : "u", ...(g.cc ? { c: g.cc } : {}) }, key);
    res.json({
      ok: true,
      ad: {
        id: ad.id, format: fmt, label: "Annonce", title: ad.title, text: ad.text, cta: ad.action,
        media: ad.video ? { type: "video", url: ad.media, thumb: ad.thumb, duration: ad.duration } : { type: "image", url: ad.media, thumb: ad.thumb, images: ad.images },
        banner: sizeKey && ad.banners[sizeKey] ? { url: ad.banners[sizeKey], w: BANNER_SIZES[sizeKey][0], h: BANNER_SIZES[sizeKey][1] } : null,
        click: ad.url ? `${BASE}/adsGo?t=${encodeURIComponent(token)}&v=${encodeURIComponent(vid)}` : "", token, event: `${BASE}/adsEvent`, viewMs: def.viewMs, ttlMs: 30 * 60_000,
      },
    });
  } catch (e) {
    console.error("[adsServe]", e);
    res.json({ ok: true, ad: null });
  }
});

/** Annonce choisie par l'application : seulement si elle est active, visible et dans son budget. Le contenu n'est pas renvoyé (l'application l'a déjà). */
async function hintedAd(id: string): Promise<Servable | null> {
  if (!/^[A-Za-z0-9_-]{6,64}$/.test(id)) return null;
  const a = (await db.collection("Advertisements").doc(id).get()).data();
  if (!activeAd(a) || a?.["hidden"] === true) return null;
  if (!deliveryAllowed({ budgetViews: Number(a?.["budgetViews"]) || 0, startMs: (Number(a?.["startDate"]) || 0) / 1000, endMs: (Number(a?.["endDate"]) || 0) / 1000, viewsTotal: (Number(a?.["views"]) || 0) + localServed(id), viewsToday: Math.max(dayViews.get(id) ?? 0, localServed(id)) })) return null;
  const url = String(a?.["actionUrl"] ?? "");
  return { id, title: "", text: "", video: false, images: [], thumb: "", media: "", action: "", url: /^https:\/\//.test(url) ? url : "", network: false, targeting: targetingOf(a ?? {}, undefined), category: String(a?.["adCategory"] ?? ""), duration: 0, budgetViews: 0, startMs: 0, endMs: 0, viewsTotal: 0, banners: {} };
}

// ─── Compteurs répartis ─────────────────────────────────────────────────────────────────────────────────────────────

type Inc = { views?: number; uniqueViews?: number; clicks?: number; uniqueClicks?: number; completes?: number; invalid?: Invalid; geo?: "i" | "o" | "u" | "a"; cc?: string };
function shardWrite(tx: FirebaseFirestore.Transaction, adId: string, pub: string, day: string, nonce: string, inc: Inc): void {
  const ref = db.collection("AdsShards").doc(shardId(adId, day, pub, shardOf(nonce)));
  const f: Record<string, unknown> = { adId, pub, day, dirty: true, updatedAt: Date.now() };
  for (const k of ["views", "uniqueViews", "clicks", "uniqueClicks", "completes"] as const) if (inc[k]) f[k] = FieldValue.increment(inc[k]!);
  if (inc.invalid) { f["invalid"] = FieldValue.increment(1); f["inv"] = { [inc.invalid]: FieldValue.increment(1) }; }
  if (inc.views) {
    if (inc.geo === "i") f["geoIn"] = FieldValue.increment(1); else if (inc.geo === "o") f["geoOut"] = FieldValue.increment(1); else if (inc.geo === "u") f["geoUnk"] = FieldValue.increment(1);
    if (inc.cc) f["cc"] = { [inc.cc]: FieldValue.increment(1) }; // d'où viennent les vues (pays), pour contrôler la cohérence du diffuseur
  }
  tx.set(ref, f, { merge: true });
}

const activeAd = (a: Record<string, unknown> | undefined): boolean => !!a && a["status"] === "active" && Number(a["endDate"]) > Date.now() * 1000;

// ─── Enregistrer une vue ou une lecture complète ────────────────────────────────────────────────────────────────────

export const adsEvent = onRequest({ ...OPTS, cors: true, timeoutSeconds: 15, maxInstances: 40 }, async (req, res) => {
  if (req.method !== "POST") { res.status(405).send("Method Not Allowed"); return; }
  res.set("Cache-Control", "no-store");
  try {
    const q = bodyOf(req);
    const key = await signingKey();
    const p = verifyToken(q["t"], key);
    let vid = String(q["vid"] ?? "");
    const kind = q["e"] === "complete" ? "complete" : q["e"] === "view" ? "view" : q["e"] === "click" ? "click" : "";
    if (!p || !kind || (p.p !== "afrolook" && !validVid(vid))) { res.status(400).json({ ok: false, error: "jeton" }); return; }
    const pub = await publisherOf(p.p);
    if (!pub || pub.status !== "active") { res.json({ ok: true, counted: false, reason: "diffuseur" }); return; }
    if (!originOk(pub, req.headers["origin"])) { await countForeign(p.p, clientIp(req)); res.json({ ok: true, counted: false, reason: "origine" }); return; }
    if (!(await appOk(pub, req.headers["x-firebase-appcheck"]))) { res.json({ ok: true, counted: false, reason: "app_non_verifiee" }); return; }
    if (p.p === "afrolook") { const uid = await appUid(req); if (!uid) { res.json({ ok: true, counted: false, reason: "connexion" }); return; } vid = uid; }
    if (isBotAgent(req.headers["user-agent"])) { res.json({ ok: true, counted: false, reason: "bot" }); return; }
    const ip = clientIp(req);
    if (limited(`e:${ip}`, 240, 60_000)) { res.status(429).json({ ok: false, error: "trop_de_demandes" }); return; }
    if (kind === "click") {
      // un clic n'est accepté ici que pour l'application (action interne, sans lien) ; partout ailleurs il passe par la redirection adsGo
      if (p.p !== "afrolook") { res.json({ ok: true, counted: false, reason: "clic_par_redirection" }); return; }
      await registerClick(p, key, vid, ip);
      res.json({ ok: true, counted: true });
      return;
    }

    const t = Date.now(), day = DAY(t);
    const iph = ipHash(ip, day, key), vh = visitorHash(vid, p.p, key);
    const nonceRef = db.collection("AdsTokens").doc(p.n);
    const devRef = db.collection("AdsCaps").doc(`${vh}_${day}`);
    const ipRef = db.collection("AdsRate").doc(`${iph}_${day}`);
    const seenRef = db.collection("AdsWebSeen").doc(`${p.a}_${vh}`);
    const adRef = db.collection("Advertisements").doc(p.a);

    const out = await db.runTransaction(async (tx) => {
      const [nonce, dev, ipDoc, seen, ad] = await Promise.all([tx.get(nonceRef), tx.get(devRef), tx.get(ipRef), tx.get(seenRef), tx.get(adRef)]);
      const n = nonce.data() ?? {};
      const ipN = Number(ipDoc.data()?.["n"]) || 0;
      if (!activeAd(ad.data())) return { counted: false, reason: "ad_inactive" as Invalid };

      if (kind === "view") {
        const d = viewDecision(p, t, Number(q["ms"]), dev.data() as DeviceDay | undefined, ipN, n["viewed"] === true);
        if (!d.valid) {
          if (d.reason !== "replay") shardWrite(tx, p.a, p.p, day, p.n, { invalid: d.reason });
          return { counted: false, reason: d.reason };
        }
        const first = seen.data()?.["viewed"] !== true;
        tx.set(nonceRef, { a: p.a, p: p.p, viewed: true, at: t, expireAt: Timestamp.fromMillis(t + 3 * 3600_000) }, { merge: true });
        tx.set(devRef, { pub: p.p, day, total: FieldValue.increment(1), slotLast: { [p.s]: t }, adViews: { [p.a]: FieldValue.increment(1) } }, { merge: true });
        tx.set(seenRef, { viewed: true, lastViewDay: day, updatedDay: day }, { merge: true });
        tx.set(ipRef, { n: FieldValue.increment(1), day }, { merge: true });
        shardWrite(tx, p.a, p.p, day, p.n, { views: 1, uniqueViews: first ? 1 : 0, geo: p.g, cc: p.c });
        return { counted: true };
      }

      // lecture complète (vidéo, récompensée) : après une vue valide du même jeton, une seule fois, et pas plus vite que la durée de la vidéo
      const dur = (Number(ad.data()?.["videoDuration"]) || 0) * 1000;
      const d = completeDecision(p, t, n["viewed"] === true, n["completed"] === true, Math.max(3000, dur * 0.8));
      if (!d.valid || !FORMATS[p.f].complete) {
        if (d.reason && d.reason !== "replay") shardWrite(tx, p.a, p.p, day, p.n, { invalid: d.reason });
        return { counted: false, reason: d.reason ?? "token" };
      }
      tx.set(nonceRef, { completed: true, completedAt: t }, { merge: true });
      shardWrite(tx, p.a, p.p, day, p.n, { completes: 1 });
      return { counted: true };
    });
    res.json({ ok: true, ...out });
  } catch (e) {
    console.error("[adsEvent]", e);
    res.json({ ok: false });
  }
});

/** Compte un clic valide (un par jeton et par visiteur et par jour, délai minimum, plafond par adresse IP) : utilisé par la redirection adsGo et, pour l'application, par adsEvent. */
async function registerClick(p: NonNullable<ReturnType<typeof verifyToken>>, key: string, vid: string, ip: string): Promise<void> {
  const t = Date.now(), day = DAY(t);
  // visiteur : l'identifiant du navigateur s'il est fourni, sinon l'empreinte du jeton lui-même (un clic par jeton dans tous les cas)
  const vh = validVid(vid) ? visitorHash(vid, p.p, key) : visitorHash(p.n, p.p, key);
  const iph = ipHash(ip, day, key);
  const nonceRef = db.collection("AdsTokens").doc(p.n), ipRef = db.collection("AdsRate").doc(`${iph}_${day}`), seenRef = db.collection("AdsWebSeen").doc(`${p.a}_${vh}`);
  await db.runTransaction(async (tx) => {
    const [nonce, ipDoc, seen] = await Promise.all([tx.get(nonceRef), tx.get(ipRef), tx.get(seenRef)]);
    const s = seen.data() ?? {};
    const d = clickDecision(p, t, nonce.data()?.["clicked"] === true, s["lastClickDay"] === day, Number(ipDoc.data()?.["n"]) || 0);
    if (!d.valid) { if (d.reason !== "dup_click") shardWrite(tx, p.a, p.p, day, p.n, { invalid: d.reason }); return; }
    tx.set(nonceRef, { a: p.a, p: p.p, clicked: true, clickedAt: t, expireAt: Timestamp.fromMillis(t + 3 * 3600_000) }, { merge: true });
    tx.set(seenRef, { clicked: true, lastClickDay: day, updatedDay: day }, { merge: true });
    tx.set(ipRef, { n: FieldValue.increment(1), day }, { merge: true });
    shardWrite(tx, p.a, p.p, day, p.n, { clicks: 1, uniqueClicks: s["clicked"] === true ? 0 : 1 });
  }).catch((e) => console.error("[adsClick] compteur", e));
}

// ─── Redirection de clic ────────────────────────────────────────────────────────────────────────────────────────────

export const adsGo = onRequest({ ...OPTS, timeoutSeconds: 15, maxInstances: 30 }, async (req, res) => {
  res.set("Cache-Control", "no-store");
  let dest = ABOUT;
  try {
    const key = await signingKey();
    const p = verifyToken(String(req.query["t"] ?? ""), key);
    if (!p) { res.redirect(302, ABOUT); return; }
    const adRef = db.collection("Advertisements").doc(p.a);
    const a = (await adRef.get()).data();
    const url = String(a?.["actionUrl"] ?? "");
    if (!activeAd(a) || !/^https:\/\//.test(url)) { res.redirect(302, ABOUT); return; }
    dest = url;

    const pub = await publisherOf(p.p);
    const human = !isBotAgent(req.headers["user-agent"]) && !!pub && pub.status === "active";
    if (human) {
      const ip = clientIp(req);
      if (!limited(`c:${ip}`, 120, 60_000)) {
        await registerClick(p, key, String(req.query["v"] ?? ""), ip);
      }
    }
  } catch (e) {
    console.error("[adsGo]", e);
  }
  res.redirect(302, dest);
});

// ─── Cumul des compteurs répartis (toutes les 5 minutes) ────────────────────────────────────────────────────────────

export const adsRollup = onSchedule({ ...OPTS, schedule: "every 5 minutes", timeoutSeconds: 240 }, async () => {
  const snap = await db.collection("AdsShards").where("dirty", "==", true).limit(300).get();
  const docs = snap.docs;
  for (let i = 0; i < docs.length; i += 15) {
    await Promise.all(docs.slice(i, i + 15).map((d) => db.runTransaction(async (tx) => {
      const s = await tx.get(d.ref);
      const v = s.data();
      if (!v || v["dirty"] !== true) return;
      const adId = String(v["adId"]), pub = String(v["pub"]), day = String(v["day"]);
      const views = Number(v["views"]) || 0, uv = Number(v["uniqueViews"]) || 0, clicks = Number(v["clicks"]) || 0, uc = Number(v["uniqueClicks"]) || 0, comp = Number(v["completes"]) || 0, bad = Number(v["invalid"]) || 0;
      const inv = (v["inv"] ?? {}) as Record<string, number>;
      const gi = Number(v["geoIn"]) || 0, go = Number(v["geoOut"]) || 0, gu = Number(v["geoUnk"]) || 0;
      const cc = (v["cc"] ?? {}) as Record<string, number>;
      const adRef = db.collection("Advertisements").doc(adId);
      const ad = await tx.get(adRef);
      if (ad.exists && (views || clicks)) {
        const u: Record<string, FieldValue | number> = { updatedAt: Date.now() * 1000 };
        if (views) { u["views"] = FieldValue.increment(views); u[`dailyStats.${day}.views`] = FieldValue.increment(views); u[`placements.${pub}.views`] = FieldValue.increment(views); }
        if (clicks) { u["clicks"] = FieldValue.increment(clicks); u[`dailyStats.${day}.clicks`] = FieldValue.increment(clicks); u[`placements.${pub}.clicks`] = FieldValue.increment(clicks); }
        if (uv) u["uniqueViews"] = FieldValue.increment(uv);
        if (uc) u["uniqueClicks"] = FieldValue.increment(uc);
        tx.update(adRef, u);
      }
      tx.set(db.collection("AdsDaily").doc(`${day}_${adId}_${pub}`), { day, adId, pub, views: FieldValue.increment(views), clicks: FieldValue.increment(clicks), uniqueViews: FieldValue.increment(uv), uniqueClicks: FieldValue.increment(uc), completes: FieldValue.increment(comp), invalid: FieldValue.increment(bad), geoIn: FieldValue.increment(gi), geoOut: FieldValue.increment(go), geoUnk: FieldValue.increment(gu) }, { merge: true });
      const pd: Record<string, unknown> = { day, pub, valid: FieldValue.increment(views), clicks: FieldValue.increment(clicks), invalid: FieldValue.increment(bad) };
      if (bad) pd["inv"] = Object.fromEntries(Object.entries(inv).map(([k, n]) => [k, FieldValue.increment(Number(n) || 0)]));
      if (Object.keys(cc).length) pd["cc"] = Object.fromEntries(Object.entries(cc).map(([k, n]) => [k, FieldValue.increment(Number(n) || 0)]));
      tx.set(db.collection("AdsPubDaily").doc(`${pub}_${day}`), pd, { merge: true });
      tx.set(d.ref, { views: 0, uniqueViews: 0, clicks: 0, uniqueClicks: 0, completes: 0, invalid: 0, inv: FieldValue.delete(), cc: FieldValue.delete(), geoIn: 0, geoOut: 0, geoUnk: 0, dirty: false, flushedAt: Date.now() }, { merge: true });
    }).catch((e) => console.error("[adsRollup]", d.id, e))));
  }
});

// ─── Nettoyage quotidien ────────────────────────────────────────────────────────────────────────────────────────────

async function purge(q: FirebaseFirestore.Query): Promise<number> {
  const snap = await q.limit(400).get();
  if (snap.empty) return 0;
  const b = db.batch();
  snap.docs.forEach((d) => b.delete(d.ref));
  await b.commit();
  return snap.size;
}
/** Compteurs répartis déjà cumulés depuis plus de 7 jours (une seule condition sur la date : aucun index composite nécessaire ; on garde ceux qui ont de nouveau des chiffres à cumuler). */
async function purgeShards(): Promise<number> {
  const snap = await db.collection("AdsShards").where("flushedAt", "<", Date.now() - 7 * 86400_000).limit(400).get();
  const old = snap.docs.filter((d) => d.data()["dirty"] !== true);
  if (!old.length) return 0;
  const batch = db.batch();
  old.forEach((d) => batch.delete(d.ref));
  await batch.commit();
  return old.length;
}
export const adsCleanup = onSchedule({ ...OPTS, schedule: "every day 03:30", timeZone: "Africa/Lome", timeoutSeconds: 300 }, async () => {
  const cut = (days: number) => DAY(Date.now() - days * 86400_000);
  const r = await Promise.all([
    purge(db.collection("AdsTokens").where("expireAt", "<", Timestamp.now())),
    purge(db.collection("AdsCaps").where("day", "<", cut(3))),
    purge(db.collection("AdsRate").where("day", "<", cut(3))),
    purge(db.collection("AdsWebRate").where("day", "<", cut(3))),
    purge(db.collection("AdsWebSeen").where("updatedDay", "<", cut(45))),
    purgeShards(),
  ]);
  console.log("[adsCleanup] supprimés", r.join(" / "));
});

// ─── Santé des diffuseurs (chaque jour) ─────────────────────────────────────────────────────────────────────────────

export const adsHealth = onSchedule({ ...OPTS, schedule: "every day 04:15", timeZone: "Africa/Lome", timeoutSeconds: 120 }, async () => {
  const days = [DAY(), DAY(Date.now() - 86400_000), DAY(Date.now() - 2 * 86400_000)];
  const agg = new Map<string, { valid: number; invalid: number }>();
  for (const d of days) {
    const snap = await db.collection("AdsPubDaily").where("day", "==", d).limit(500).get();
    for (const x of snap.docs) {
      const v = x.data(), pub = String(v["pub"]);
      const a = agg.get(pub) ?? { valid: 0, invalid: 0 };
      a.valid += Number(v["valid"]) || 0; a.invalid += Number(v["invalid"]) || 0;
      agg.set(pub, a);
    }
  }
  for (const [pub, a] of agg) {
    const h = publisherHealth(a.valid, a.invalid);
    const prev = (await db.collection("AdsPubHealth").doc(pub).get()).data();
    await db.collection("AdsPubHealth").doc(pub).set({ pub, rate: h.rate, status: h.status, valid: a.valid, invalid: a.invalid, at: Date.now() });
    if (h.status === "ok" || prev?.["status"] === h.status) continue;
    const pct = Math.round(h.rate * 100);
    // un diffuseur externe dépassant 25 % de trafic invalide est suspendu automatiquement ; nos propres plateformes déclenchent seulement une alerte
    if (h.status === "suspend" && /^ap_/.test(pub)) await db.collection("AdProperties").doc(pub).update({ status: "suspended", reason: `Trafic invalide trop élevé (${pct} %)`, updatedAt: Date.now() }).catch(() => undefined);
    await notifyAdminsAll({ title: h.status === "suspend" ? "⛔ Trafic invalide : diffuseur suspendu" : "⚠️ Trafic invalide élevé", message: `${pub} : ${pct} % de trafic invalide sur 3 jours (${a.invalid} sur ${a.valid + a.invalid}).`, target: "ADMIN_ADS", refId: pub });
  }
});

// ─── Audience mesurée : résumé quotidien des visiteurs différents de chaque site (HyperLogLog) ───────────────────────

export const adsUniques = onSchedule({ ...OPTS, memory: "512MiB", schedule: "every day 04:30", timeZone: "Africa/Lome", timeoutSeconds: 540 }, async () => {
  const day = dayStr(Date.now() - 86_400_000);
  const props = await db.collection("AdProperties").where("status", "==", "active").limit(500).get();
  const targets: Array<{ pub: string; declared: number; countries?: string[]; ref?: FirebaseFirestore.DocumentReference }> = [
    ...Object.keys(INTERNAL_PUBLISHERS).map((pub) => ({ pub, declared: 0 })),
    ...props.docs.map((d) => ({ pub: d.id, declared: Number(d.data()["audienceDeclared"]) || 0, countries: (d.data()["countries"] as string[]) ?? [], ref: d.ref })),
  ];
  for (const t of targets) {
    try {
      const regs = hllNew();
      let n = 0;
      const geo: Record<string, number> = {};
      const stream = db.collection("AdsCaps").where("pub", "==", t.pub).where("day", "==", day).select("cc").stream() as unknown as AsyncIterable<FirebaseFirestore.QueryDocumentSnapshot>;
      for await (const doc of stream) { hllAdd(regs, doc.id.split("_")[0]); n++; const cc = doc.get("cc"); if (typeof cc === "string") geo[cc] = (geo[cc] ?? 0) + 1; }
      if (n) {
        const est = hllCount(regs);
        await db.collection("AdsHll").doc(`${t.pub}_${day}`).set({ pub: t.pub, day, regs: hllToB64(regs), n: est, geo, at: Date.now() });
        await db.collection("AdsPubDaily").doc(`${t.pub}_${day}`).set({ day, pub: t.pub, uniques: est }, { merge: true });
      }
      const m = await measure(t.pub, t.declared, 60, Date.now(), t.countries ?? []);
      if (t.ref) await t.ref.update({ measured: summaryOf(m) }).catch(() => undefined);
      else await db.collection("AdsPubHealth").doc(t.pub).set({ measured: summaryOf(m) }, { merge: true });
    } catch (e) { console.error("[adsUniques]", t.pub, e); }
  }
});

// ─── Preuve de propriété : revérifiée chaque nuit ───────────────────────────────────────────────────────────────────

const UA = "Mozilla/5.0 (compatible; AfrolookAdsBot/1.0; +https://afrolookmedia.com/ads/)";
/** Un site validé doit garder sa balise (ou son fichier /afrolook-ads.txt). Absente 3 jours de suite : diffusion suspendue et administrateurs prévenus. */
export const adsReverify = onSchedule({ ...OPTS, schedule: "every day 05:00", timeZone: "Africa/Lome", timeoutSeconds: 540 }, async () => {
  const snap = await db.collection("AdProperties").where("status", "==", "active").limit(500).get();
  const sites = snap.docs.filter((d) => d.data()["kind"] === "site");
  for (let i = 0; i < sites.length; i += 10) {
    await Promise.all(sites.slice(i, i + 10).map(async (d) => {
      const p = d.data();
      let ok = false;
      try {
        const base = new URL(String(p["url"]));
        for (const path of ["/", "/afrolook-ads.txt"]) {
          try {
            const r = await fetchLimited(new URL(path, `${base.protocol}//${base.host}`).toString(), { ua: UA, max: 300_000 });
            if (pageHasToken(r.body.toString("utf8"), String(p["verifyToken"] ?? ""))) { ok = true; break; }
          } catch { /* adresse suivante */ }
        }
      } catch { /* adresse invalide */ }
      const fails = ok ? 0 : (Number(p["verifyFails"]) || 0) + 1;
      const upd: Record<string, unknown> = { verified: ok, verifyFails: fails, verifiedCheckedAt: Date.now() };
      if (fails >= 3) {
        upd["status"] = "suspended"; upd["reason"] = "Preuve de propriété retirée du site (3 jours de suite)."; upd["audienceCounted"] = 0; upd["updatedAt"] = Date.now();
        await notifyAdminsAll({ title: "⛔ Site suspendu : preuve de propriété absente", message: `${p["name"]} (${d.id}) a perdu sa balise de vérification depuis 3 jours : diffusion suspendue.`, target: "ADMIN_ADS", refId: d.id });
      }
      await d.ref.update(upd).catch(() => undefined);
    }));
  }
});
