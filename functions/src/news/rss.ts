/**
 * Lecture de flux RSS / Atom sans dépendance (portée de PronoFlash) : titre, lien, date, court extrait, image.
 * On ne garde jamais le texte d'un article : l'extrait sert seulement à résumer avec nos propres mots, et la source est toujours citée.
 */
export interface FeedItem {
  titre: string;
  lien: string;
  date: string;
  /** Extrait court (600 caractères au plus). */
  resume: string;
  /** Extrait plus long (1 400 caractères au plus) quand le flux fournit le contenu : matière du résumé. */
  corps: string;
  image: string | null;
}

const NAMED: Record<string, string> = { amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " ", rsquo: "’", lsquo: "‘", rdquo: "”", ldquo: "“", hellip: "…", ndash: "–", mdash: "—", eacute: "é", egrave: "è", agrave: "à", ecirc: "ê", ocirc: "ô", ccedil: "ç" };

export function decode(s: string): string {
  return String(s)
    .replace(/&#x([0-9a-f]+);/gi, (_, h: string) => { try { return String.fromCodePoint(parseInt(h, 16)); } catch { return ""; } })
    .replace(/&#(\d+);/g, (_, n: string) => { try { return String.fromCodePoint(parseInt(n, 10)); } catch { return ""; } })
    .replace(/&([a-z]+);/gi, (m, n: string) => (NAMED[n.toLowerCase()] != null ? NAMED[n.toLowerCase()] : m));
}

/** Texte d'une balise : contenu CDATA ou texte, balises HTML retirées, entités décodées, espaces compactés. */
export function text(raw: unknown): string {
  if (raw == null) return "";
  let s = String(raw);
  const cd = /<!\[CDATA\[([\s\S]*?)\]\]>/.exec(s);
  s = cd ? cd[1] : decode(s);
  s = s.replace(/<[^>]*>/g, " ");
  return decode(s).replace(/\s+/g, " ").trim();
}

function tag(block: string, name: string): string | null {
  const m = new RegExp(`<${name}(?:\\s[^>]*)?>([\\s\\S]*?)</${name}>`, "i").exec(block);
  return m ? m[1] : null;
}

function atomLink(block: string): string | null {
  const m = /<link\b[^>]*?href=["']([^"']+)["'][^>]*>/i.exec(block);
  return m ? decode(m[1]) : null;
}

/** Lien web sûr (http ou https) ou null. */
export function safeUrl(u: unknown): string | null {
  if (!u) return null;
  const s = decode(String(u)).trim();
  try {
    const x = new URL(s);
    return x.protocol === "https:" || x.protocol === "http:" ? x.href : null;
  } catch {
    return null;
  }
}

function isoDate(raw: string | null): string | null {
  if (!raw) return null;
  const d = new Date(text(raw));
  return isNaN(d.getTime()) ? null : d.toISOString();
}

/** Valeur d'un attribut sur la première balise `name` du bloc (ex. media:thumbnail url="…"). */
function attrOf(block: string, name: string, attr: string, filter?: (attrs: string) => boolean): string | null {
  const re = new RegExp(`<${name}\\b([^>]*)>`, "gi");
  let m: RegExpExecArray | null;
  while ((m = re.exec(block))) {
    const a = new RegExp(`\\b${attr}\\s*=\\s*["']([^"']+)["']`, "i").exec(m[1]);
    if (a && (!filter || filter(m[1]))) return decode(a[1]);
  }
  return null;
}

/** Image d'illustration en https. */
export function httpsImage(u: unknown): string | null {
  const safe = safeUrl(u);
  return safe ? safe.replace(/^http:\/\//i, "https://") : null;
}

/** Extrait d'un flux : mentions ajoutées par les sites (« L'article … est apparu en premier sur … », « [...] »), puis coupe propre. */
export function cleanExcerpt(s: unknown, max = 600): string {
  let t = String(s || "")
    .replace(/\s*(?:The post .{1,200}? appeared first on .{1,120}?\.?|L['’]article .{1,200}? est apparu en premier sur .{1,120}?\.?|Cet article .{1,200}? est apparu en premier sur .{1,120}?\.?)\s*$/i, "")
    .replace(/\s*(?:\[(?:…|\.\.\.|&#8230;)\]|(?:Lire la suite|Read more|Continue reading)[^.]{0,60})\s*$/i, "")
    .trim();
  if (t.length > max) {
    t = t.slice(0, max);
    t = t.slice(0, Math.max(t.lastIndexOf(" "), max - 40)).replace(/[\s,;:.-]+$/, "") + "…";
  }
  return t;
}

function imageOf(block: string): string | null {
  const isVideoAttrs = (a: string) => /type\s*=\s*["']video|medium\s*=\s*["']video/i.test(a);
  const isImgAttrs = (a: string) => !isVideoAttrs(a) && !/type\s*=\s*["'](?:audio|application)/i.test(a);
  let img = attrOf(block, "media:thumbnail", "url")
    || attrOf(block, "media:content", "url", (a) => /medium\s*=\s*["']image|type\s*=\s*["']image/i.test(a))
    || attrOf(block, "enclosure", "url", (a) => /type\s*=\s*["']image/i.test(a))
    || attrOf(block, "media:content", "url", isImgAttrs);
  if (!img) {
    const html = tag(block, "content:encoded") || tag(block, "description") || "";
    const raw = (/<!\[CDATA\[([\s\S]*?)\]\]>/.exec(html) || [null, decode(html)])[1] as string;
    const m = /<img\b[^>]*?\bsrc\s*=\s*["']([^"']+)["']/i.exec(raw);
    if (m) img = decode(m[1]);
  }
  return httpsImage(img);
}

/** Éléments d'un flux (les éléments sans titre, sans lien web ou sans date sont ignorés). */
export function parseFeed(xml: string): FeedItem[] {
  const out: FeedItem[] = [];
  const blocks = String(xml || "").match(/<(item|entry)[\s>][\s\S]*?<\/\1>/gi) || [];
  for (const b of blocks) {
    const titre = text(tag(b, "title"));
    const lien = safeUrl(text(tag(b, "link")) || atomLink(b) || text(tag(b, "guid")));
    const date = isoDate(tag(b, "pubDate") || tag(b, "dc:date") || tag(b, "published") || tag(b, "updated"));
    const full = text(tag(b, "content:encoded") || tag(b, "content"));
    const short = text(tag(b, "description") || tag(b, "summary"));
    if (!titre || !lien || !date) continue;
    out.push({
      titre: titre.slice(0, 200), lien, date,
      resume: cleanExcerpt(short || full),
      corps: cleanExcerpt(full.length > short.length ? full : short, 1400),
      image: imageOf(b),
    });
  }
  return out;
}

/** Télécharge un flux (10 s, 2 Mo au plus). `fetchImpl` injectable pour les tests. */
export async function fetchFeed(url: string, fetchImpl?: typeof fetch): Promise<FeedItem[]> {
  const f = fetchImpl ?? fetch;
  const res = await f(url, {
    headers: { "User-Agent": "Mozilla/5.0 (compatible; AfrolookNewsBot/1.0; +https://afrolook.com)", Accept: "application/rss+xml, application/xml, text/xml, */*" },
    redirect: "follow",
    signal: AbortSignal.timeout(10_000),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const buf = await res.text();
  if (buf.length > 2e6) throw new Error("flux trop gros");
  return parseFeed(buf);
}
