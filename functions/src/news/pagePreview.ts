import { cleanExcerpt, decode, httpsImage, safeUrl, text } from "./rss";

/**
 * Aperçu d'une page d'article (portée de PronoFlash) : image et description que le site publie pour les aperçus de liens (og:image, og:description),
 * comme le font WhatsApp ou Facebook. Une page par article, rien d'autre n'est conservé. Garde-fous : https seulement, pas d'adresse interne
 * (localhost, IP, réseaux privés), 6 secondes, 200 Ko lus au plus.
 */
const PRIVATE_HOST = /^(?:localhost|.*\.(?:local|internal|localdomain)|\d{1,3}(?:\.\d{1,3}){3}|\[.*\]|0x[0-9a-f]+|\d+)$/i;

/** Adresse publique en https (pas d'IP, pas de nom interne). */
export function publicHttps(u: string): boolean {
  let x: URL;
  try { x = new URL(u); } catch { return false; }
  return x.protocol === "https:" && !x.username && !x.password && !PRIVATE_HOST.test(x.hostname) && x.hostname.includes(".");
}

/** Contenu d'une balise meta (property= ou name=) ; les deux ordres d'attributs sont lus. */
export function metaContent(html: string, key: string): string | null {
  const k = key.replace(/[.:]/g, "\\$&");
  const val = "(?:\"([^\"]*)\"|'([^']*)')";
  const a = new RegExp(`<meta\\b[^>]*?(?:property|name)\\s*=\\s*["']${k}["'][^>]*?\\bcontent\\s*=\\s*${val}[^>]*>`, "i").exec(html);
  if (a) return decode(a[1] != null ? a[1] : a[2]);
  const b = new RegExp(`<meta\\b[^>]*?\\bcontent\\s*=\\s*${val}[^>]*?(?:property|name)\\s*=\\s*["']${k}["'][^>]*>`, "i").exec(html);
  return b ? decode(b[1] != null ? b[1] : b[2]) : null;
}

export interface PagePreview { image: string | null; description: string }

/** Image et description d'une page HTML ; `base` = adresse de la page (images relatives). */
export function parsePreview(html: string, base: string): PagePreview {
  const head = String(html || "").slice(0, 200_000);
  let image: string | null = null;
  for (const key of ["og:image:secure_url", "og:image", "twitter:image", "twitter:image:src"]) {
    const v = metaContent(head, key);
    if (!v) continue;
    let abs: string | null = null;
    try { abs = new URL(v, base).href; } catch { abs = null; }
    image = httpsImage(abs && safeUrl(abs));
    if (image) break;
  }
  const d = metaContent(head, "og:description") || metaContent(head, "description") || metaContent(head, "twitter:description");
  const description = d ? cleanExcerpt(text(d)) : "";
  return { image, description: description.length >= 40 ? description : "" };
}

const BOILERPLATE = /cookies?|abonnez-vous|s'abonner|newsletter|lire aussi|à lire aussi|tous droits réservés|publicité|partager cet article|suivez-nous|connectez-vous|réservé aux abonnés/i;

/**
 * Texte principal d'une page d'article : le bloc <article> s'il existe, sinon toute la page ; scripts, menus, pieds de page et formulaires retirés ; on ne garde que les
 * vrais paragraphes (au moins 70 caractères, sans formules de site). 3 500 caractères au plus. Ce texte nourrit le résumé de l'IA : il n'est jamais conservé ni affiché.
 */
export function extractArticleText(html: string, max = 3500): string {
  let h = String(html || "").slice(0, 600_000)
    .replace(/<!--[\s\S]*?-->/g, " ")
    .replace(/<(script|style|nav|footer|header|aside|form|noscript|svg|iframe)\b[\s\S]*?<\/\1>/gi, " ");
  const articles = h.match(/<article\b[\s\S]*?<\/article>/gi);
  if (articles?.length) h = articles.sort((a, b) => b.length - a.length)[0];
  const out: string[] = [];
  let total = 0;
  for (const m of h.matchAll(/<p\b[^>]*>([\s\S]*?)<\/p>/gi)) {
    const t = text(m[1]);
    if (t.length < 70 || BOILERPLATE.test(t) || out.includes(t)) continue;
    if (total + t.length > max) { // on s'arrête à la fin d'un paragraphe ; un seul paragraphe démesuré est coupé au dernier mot entier
      if (!out.length) out.push(t.slice(0, max).replace(/\s+\S*$/, ""));
      break;
    }
    out.push(t);
    total += t.length + 1;
  }
  return out.join(" ");
}

/** Télécharge une page d'article et en extrait le texte ; chaîne vide si la page est refusée, illisible ou sans vrai texte (jamais d'exception). */
export async function fetchArticleText(rawUrl: string, fetchImpl?: typeof fetch): Promise<string> {
  const url = rawUrl.replace(/^http:\/\//i, "https://"); // certains flux (Africanews) donnent des liens http qui redirigent vers https
  if (!publicHttps(url)) return "";
  const f = fetchImpl ?? fetch;
  try {
    const res = await f(url, {
      headers: { "User-Agent": "Mozilla/5.0 (compatible; AfrolookNewsBot/1.0; +https://afrolook.com)", Accept: "text/html,application/xhtml+xml", "Accept-Language": "fr,en;q=0.8" },
      redirect: "follow",
      signal: AbortSignal.timeout(8000),
    });
    if (!res.ok || (res.url && !publicHttps(res.url))) return "";
    if (!/html/i.test(String(res.headers?.get?.("content-type") ?? "text/html"))) return "";
    const body = await res.text();
    const t = extractArticleText(body);
    return t.length >= 300 ? t : ""; // moins : page à péage ou sans texte, l'extrait du flux vaut mieux
  } catch {
    return "";
  }
}

/** Télécharge et lit l'aperçu d'un article ; null si la page est refusée ou illisible (jamais d'exception). */
export async function fetchPreview(url: string, fetchImpl?: typeof fetch): Promise<PagePreview | null> {
  if (!publicHttps(url)) return null;
  const f = fetchImpl ?? fetch;
  try {
    const res = await f(url, {
      headers: { "User-Agent": "Mozilla/5.0 (compatible; AfrolookNewsBot/1.0; +https://afrolook.com)", Accept: "text/html,application/xhtml+xml" },
      redirect: "follow",
      signal: AbortSignal.timeout(6000),
    });
    if (!res.ok || (res.url && !publicHttps(res.url))) return null;
    const type = String(res.headers?.get?.("content-type") ?? "text/html");
    if (!/html/i.test(type)) return null;
    return parsePreview(await res.text(), res.url || url);
  } catch {
    return null;
  }
}
