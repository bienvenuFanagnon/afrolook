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
