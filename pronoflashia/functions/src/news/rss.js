'use strict';
// Lecture de flux RSS / Atom sans dépendance : titre, lien, date, court résumé. Rien n'est conservé de l'article lui-même.

const NAMED = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ', rsquo: '’', lsquo: '‘', rdquo: '”', ldquo: '“', hellip: '…', ndash: '–', mdash: '—', eacute: 'é', egrave: 'è', agrave: 'à', ecirc: 'ê', ocirc: 'ô', ccedil: 'ç' };

function decode(s) {
  return String(s)
    .replace(/&#x([0-9a-f]+);/gi, (_, h) => { try { return String.fromCodePoint(parseInt(h, 16)); } catch { return ''; } })
    .replace(/&#(\d+);/g, (_, n) => { try { return String.fromCodePoint(parseInt(n, 10)); } catch { return ''; } })
    .replace(/&([a-z]+);/gi, (m, n) => (NAMED[n.toLowerCase()] != null ? NAMED[n.toLowerCase()] : m));
}

/** Texte d'une balise : contenu CDATA ou texte, balises HTML retirées, entités décodées, espaces compactés. */
function text(raw) {
  if (raw == null) return '';
  let s = String(raw);
  const cd = /<!\[CDATA\[([\s\S]*?)\]\]>/.exec(s);
  s = cd ? cd[1] : decode(s);
  s = s.replace(/<[^>]*>/g, ' ');
  return decode(s).replace(/\s+/g, ' ').trim();
}

function tag(block, name) {
  const m = new RegExp(`<${name}(?:\\s[^>]*)?>([\\s\\S]*?)</${name}>`, 'i').exec(block);
  return m ? m[1] : null;
}

function atomLink(block) {
  const m = /<link\b[^>]*?href=["']([^"']+)["'][^>]*>/i.exec(block);
  return m ? decode(m[1]) : null;
}

/** Lien web sûr (http ou https) ou null. */
function safeUrl(u) {
  if (!u) return null;
  const s = decode(String(u)).trim();
  try { const x = new URL(s); return x.protocol === 'https:' || x.protocol === 'http:' ? x.href : null; } catch { return null; }
}

function isoDate(raw) {
  if (!raw) return null;
  const d = new Date(text(raw));
  return isNaN(d) ? null : d.toISOString();
}

/** Valeur d'un attribut sur la première balise `name` du bloc (ex. media:thumbnail url="…"). */
function attrOf(block, name, attr, filter) {
  const re = new RegExp(`<${name}\\b([^>]*)>`, 'gi');
  let m;
  while ((m = re.exec(block))) {
    const a = new RegExp(`\\b${attr}\\s*=\\s*["']([^"']+)["']`, 'i').exec(m[1]);
    if (a && (!filter || filter(m[1]))) return decode(a[1]);
  }
  return null;
}

/** Image d'illustration en https (les adresses http sont tentées en https ; une image qui ne charge pas est masquée par le navigateur). */
function httpsImage(u) {
  const safe = safeUrl(u);
  if (!safe) return null;
  return safe.replace(/^http:\/\//i, 'https://');
}

/** YouTube / Vimeo : miniature officielle de la vidéo. */
function videoThumb(link) {
  const y = /(?:youtube\.com\/(?:watch\?v=|embed\/|shorts\/)|youtu\.be\/)([A-Za-z0-9_-]{11})/.exec(link || '');
  return y ? `https://i.ytimg.com/vi/${y[1]}/hqdefault.jpg` : null;
}

/** Identifiant d'une vidéo YouTube (lien watch, embed, shorts, youtu.be) ou null. */
function youtubeId(s) {
  const y = /(?:youtube(?:-nocookie)?\.com\/(?:watch\?(?:[^"'\s]*&)?v=|embed\/|shorts\/|v\/)|youtu\.be\/)([A-Za-z0-9_-]{11})(?![A-Za-z0-9_-])/.exec(decode(String(s || '')));
  return y ? y[1] : null;
}

/** Extrait d'un flux : mentions ajoutées par les sites (« L'article … est apparu en premier sur … », « [...] »), puis coupe propre à 600 caractères. */
function cleanExcerpt(s, max = 600) {
  let t = String(s || '')
    .replace(/\s*(?:The post .{1,200}? appeared first on .{1,120}?\.?|L['’]article .{1,200}? est apparu en premier sur .{1,120}?\.?|Cet article .{1,200}? est apparu en premier sur .{1,120}?\.?)\s*$/i, '')
    .replace(/\s*(?:\[(?:…|\.\.\.|&#8230;)\]|(?:Lire la suite|Read more|Continue reading)[^.]{0,60})\s*$/i, '')
    .trim();
  if (t.length > max) { t = t.slice(0, max); t = t.slice(0, Math.max(t.lastIndexOf(' '), max - 40)).replace(/[\s,;:.-]+$/, '') + '…'; }
  return t;
}

/** { image, video } d'un élément : balises media:*, enclosure, première image du contenu ; video = vrai si l'article est une vidéo. */
function mediaOf(block, lien) {
  const isVideoAttrs = (a) => /type\s*=\s*["']video|medium\s*=\s*["']video/i.test(a);
  const isImgAttrs = (a) => !isVideoAttrs(a) && !/type\s*=\s*["'](?:audio|application)/i.test(a);
  const video = !!(attrOf(block, 'media:content', 'url', isVideoAttrs) || attrOf(block, 'enclosure', 'url', isVideoAttrs) || videoThumb(lien) || /\/video[s]?\//i.test(lien || ''));
  let img = attrOf(block, 'media:thumbnail', 'url')
    || attrOf(block, 'media:content', 'url', (a) => /medium\s*=\s*["']image|type\s*=\s*["']image/i.test(a))
    || attrOf(block, 'enclosure', 'url', (a) => /type\s*=\s*["']image/i.test(a))
    || attrOf(block, 'media:content', 'url', isImgAttrs);
  if (!img) {
    const html = tag(block, 'content:encoded') || tag(block, 'description') || '';
    const raw = (/<!\[CDATA\[([\s\S]*?)\]\]>/.exec(html) || [null, decode(html)])[1];
    const m = /<img\b[^>]*?\bsrc\s*=\s*["']([^"']+)["']/i.exec(raw);
    if (m) img = decode(m[1]);
  }
  const html2 = tag(block, 'content:encoded') || tag(block, 'description') || '';
  const videoId = youtubeId(lien) || youtubeId(attrOf(block, 'media:content', 'url')) || youtubeId(attrOf(block, 'media:player', 'url')) || youtubeId(attrOf(block, 'enclosure', 'url')) || youtubeId((/<iframe\b[^>]*\bsrc\s*=\s*["']([^"']+)["']/i.exec((/<!\[CDATA\[([\s\S]*?)\]\]>/.exec(html2) || [null, decode(html2)])[1]) || [])[1]);
  return { image: httpsImage(img) || (videoId ? `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg` : null) || videoThumb(lien), video: video || !!videoId, videoId };
}

/** Éléments d'un flux : [{ titre, lien, date, resume }] (les éléments sans titre, sans lien web ou sans date sont ignorés). */
function parseFeed(xml) {
  const out = [];
  const blocks = String(xml || '').match(/<(item|entry)[\s>][\s\S]*?<\/\1>/gi) || [];
  for (const b of blocks) {
    const titre = text(tag(b, 'title'));
    const lien = safeUrl(text(tag(b, 'link')) || atomLink(b) || text(tag(b, 'guid')));
    const date = isoDate(tag(b, 'pubDate') || tag(b, 'dc:date') || tag(b, 'published') || tag(b, 'updated'));
    const resume = cleanExcerpt(text(tag(b, 'description') || tag(b, 'summary')));
    if (titre && lien && date) out.push(Object.assign({ titre: titre.slice(0, 200), lien, date, resume }, mediaOf(b, lien)));
  }
  return out;
}

/** Télécharge un flux (10 s, 2 Mo au plus). fetchImpl injectable pour les tests. */
async function fetchFeed(url, fetchImpl) {
  const f = fetchImpl || fetch;
  const res = await f(url, { headers: { 'User-Agent': 'Mozilla/5.0 (compatible; PronoFlashBot/1.0; +https://pronoflashia.web.app)', Accept: 'application/rss+xml, application/xml, text/xml, */*' }, redirect: 'follow', signal: AbortSignal.timeout(10000) });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const buf = await res.text();
  if (buf.length > 2e6) throw new Error('flux trop gros');
  return parseFeed(buf);
}

module.exports = { youtubeId, cleanExcerpt, httpsImage, mediaOf, parseFeed, fetchFeed, text, decode, safeUrl };
