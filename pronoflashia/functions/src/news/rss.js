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

/** Éléments d'un flux : [{ titre, lien, date, resume }] (les éléments sans titre, sans lien web ou sans date sont ignorés). */
function parseFeed(xml) {
  const out = [];
  const blocks = String(xml || '').match(/<(item|entry)[\s>][\s\S]*?<\/\1>/gi) || [];
  for (const b of blocks) {
    const titre = text(tag(b, 'title'));
    const lien = safeUrl(text(tag(b, 'link')) || atomLink(b) || text(tag(b, 'guid')));
    const date = isoDate(tag(b, 'pubDate') || tag(b, 'dc:date') || tag(b, 'published') || tag(b, 'updated'));
    const resume = text(tag(b, 'description') || tag(b, 'summary')).slice(0, 220);
    if (titre && lien && date) out.push({ titre: titre.slice(0, 200), lien, date, resume });
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

module.exports = { parseFeed, fetchFeed, text, decode, safeUrl };
