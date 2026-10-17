'use strict';
// Aperçu d'un article : image et description que le site d'origine publie pour les aperçus de liens (balises og:image, og:description, twitter:image),
// comme le fait WhatsApp. Une seule page par article, lue sans rien conserver d'autre que ces trois informations. Garde-fous : https seulement,
// pas d'adresse interne (localhost, IP, réseaux privés), 6 secondes, 200 Ko lus au plus.

const { decode, text, safeUrl, httpsImage, youtubeId, cleanExcerpt } = require('./rss');

const PRIVATE_HOST = /^(?:localhost|.*\.(?:local|internal|localdomain)|\d{1,3}(?:\.\d{1,3}){3}|\[.*\]|0x[0-9a-f]+|\d+)$/i;

/** Adresse publique en https (pas d'IP, pas de nom interne). */
function publicHttps(u) {
  let x;
  try { x = new URL(u); } catch { return false; }
  return x.protocol === 'https:' && !x.username && !x.password && !PRIVATE_HOST.test(x.hostname) && x.hostname.includes('.');
}

/** Contenu d'une balise meta (property= ou name=) ; les deux ordres d'attributs sont lus. */
function metaContent(html, key) {
  const k = key.replace(/[.:]/g, '\\$&');
  const val = '(?:"([^"]*)"|\'([^\']*)\')';
  const a = new RegExp(`<meta\\b[^>]*?(?:property|name)\\s*=\\s*["']${k}["'][^>]*?\\bcontent\\s*=\\s*${val}[^>]*>`, 'i').exec(html);
  if (a) return decode(a[1] != null ? a[1] : a[2]);
  const b = new RegExp(`<meta\\b[^>]*?\\bcontent\\s*=\\s*${val}[^>]*?(?:property|name)\\s*=\\s*["']${k}["'][^>]*>`, 'i').exec(html);
  return b ? decode(b[1] != null ? b[1] : b[2]) : null;
}

/** { image, description, videoId } d'une page HTML ; base = adresse de la page (images relatives). */
function parsePreview(html, base) {
  const head = String(html || '').slice(0, 200000);
  let image = null;
  for (const key of ['og:image:secure_url', 'og:image', 'twitter:image', 'twitter:image:src']) {
    const v = metaContent(head, key);
    if (!v) continue;
    let abs = null;
    try { abs = new URL(v, base).href; } catch { abs = null; }
    image = httpsImage(abs && safeUrl(abs));
    if (image) break;
  }
  const d = metaContent(head, 'og:description') || metaContent(head, 'description') || metaContent(head, 'twitter:description');
  const description = d ? cleanExcerpt(text(d)) : '';
  const videoId = youtubeId(metaContent(head, 'og:video:url') || metaContent(head, 'og:video') || metaContent(head, 'twitter:player') || '');
  return { image, description: description.length >= 40 ? description : '', videoId };
}

/** Télécharge et lit l'aperçu d'un article ; null si la page est refusée ou illisible (jamais d'exception). */
async function fetchPreview(url, fetchImpl) {
  if (!publicHttps(url)) return null;
  const f = fetchImpl || fetch;
  try {
    const res = await f(url, { headers: { 'User-Agent': 'Mozilla/5.0 (compatible; PronoFlashBot/1.0; +https://pronoflashia.web.app)', Accept: 'text/html,application/xhtml+xml' }, redirect: 'follow', signal: AbortSignal.timeout(6000) });
    if (!res.ok || (res.url && !publicHttps(res.url))) return null;
    const type = String((res.headers && res.headers.get && res.headers.get('content-type')) || 'text/html');
    if (!/html/i.test(type)) return null;
    return parsePreview(await res.text(), res.url || url);
  } catch { return null; }
}

module.exports = { publicHttps, metaContent, parsePreview, fetchPreview };
