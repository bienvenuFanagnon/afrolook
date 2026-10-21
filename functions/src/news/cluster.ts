import { createHash } from "crypto";
import { NewsCategory, NewsSourceDef } from "./sources";
import { FeedItem } from "./rss";

/**
 * Du flux brut aux sujets : regroupement des articles qui parlent de la même chose (donc des sources différentes), domaine, pays, niveau et score.
 * Fonctions pures, sans réseau ni base : tout se teste.
 */
export interface RawItem {
  sourceId: string;
  sourceName: string;
  lang: "fr" | "en";
  region: "africa" | "world";
  categoryHint: NewsCategory | null;
  titre: string;
  lien: string;
  date: string;
  resume: string;
  corps: string;
  image: string | null;
}

export const toRaw = (s: NewsSourceDef, it: FeedItem): RawItem => ({
  sourceId: s.id, sourceName: s.name, lang: s.lang, region: s.region, categoryHint: s.category,
  titre: it.titre, lien: it.lien, date: it.date, resume: it.resume, corps: it.corps, image: it.image,
});

/** Texte sans accent, en minuscules, mots séparés par une espace. */
export const strip = (s: string): string => String(s || "").normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();

const STOP = new Set(("le la les un une des de du d l et en au aux a à est sont ont par pour sur dans avec sans qui que quoi dont ce cette ces son sa ses leur leurs il elle ils elles on nous vous " +
  "plus moins tres apres avant entre vers chez comme mais ou donc car ne pas se sera sont ete etre avoir fait faire the of to in on for and is are was were by with from at as it its an be has have").split(" "));

export function titleTokens(title: string): Set<string> {
  return new Set(strip(title).split(" ").filter((w) => w.length >= 3 && !STOP.has(w)));
}

export function similar(a: Set<string>, b: Set<string>): boolean {
  let shared = 0;
  for (const w of a) if (b.has(w)) shared++;
  const union = a.size + b.size - shared;
  if (!union) return false;
  const j = shared / union;
  return (shared >= 3 && j >= 0.35) || (shared >= 4 && j >= 0.28);
}

// ── Pays ──────────────────────────────────────────────────────────────────────────────────────────

/** Expressions à plusieurs mots ramenées à un seul mot, pour qu'« Afrique du Sud » ou « Guinée équatoriale » ne soient pas pris pour l'Afrique ou la Guinée. */
const PHRASES: Array<[string, string]> = [
  ["guinee bissau", "guineebissau"], ["guinee equatoriale", "guineeequatoriale"], ["equatorial guinea", "guineeequatoriale"], ["congo brazzaville", "congobrazzaville"],
  ["rd congo", "rdcongo"], ["r d congo", "rdcongo"], ["dr congo", "rdcongo"], ["republique democratique du congo", "rdcongo"], ["congo kinshasa", "rdcongo"],
  ["cote d ivoire", "cotedivoire"], ["ivory coast", "cotedivoire"], ["afrique du sud", "afriquedusud"], ["south africa", "afriquedusud"], ["sud soudan", "soudandusud"],
  ["soudan du sud", "soudandusud"], ["south sudan", "soudandusud"], ["cap vert", "capvert"], ["cape verde", "capvert"], ["sao tome", "saotome"], ["sierra leone", "sierraleone"],
  ["burkina faso", "burkina"], ["porto novo", "portonovo"], ["le caire", "lecaire"], ["addis abeba", "addisabeba"], ["addis ababa", "addisabeba"], ["republique centrafricaine", "centrafrique"],
  ["ile maurice", "ilemaurice"], ["dar es salaam", "daressalaam"], ["n djamena", "ndjamena"], ["port louis", "portlouis"],
  ["etats unis", "etatsunis"], ["united states", "etatsunis"], ["royaume uni", "royaumeuni"], ["united kingdom", "royaumeuni"],
];

/** Mots-clés (sans accent) de chaque pays : tous les pays africains, plus la France et quelques pays d'autres continents ; nom, adjectif et capitale, en français et en anglais. */
export const COUNTRY_KEYWORDS: Record<string, string[]> = {
  DZ: ["algerie", "algerien", "algerienne", "alger", "algeria"], AO: ["angola", "angolais", "luanda"], BJ: ["benin", "beninois", "beninoise", "cotonou", "portonovo"],
  BW: ["botswana", "gaborone"], BF: ["burkina", "burkinabe", "ouagadougou"], BI: ["burundi", "burundais", "bujumbura", "gitega"],
  CM: ["cameroun", "camerounais", "camerounaise", "yaounde", "douala", "cameroon"], CV: ["capvert", "praia"], CF: ["centrafrique", "centrafricain", "bangui"],
  TD: ["tchad", "tchadien", "ndjamena"], KM: ["comores", "comorien", "moroni"], CG: ["congobrazzaville", "brazzaville"],
  CD: ["rdcongo", "rdc", "kinshasa", "goma", "lubumbashi"], CI: ["cotedivoire", "ivoirien", "ivoirienne", "abidjan", "yamoussoukro"], DJ: ["djibouti", "djiboutien"],
  EG: ["egypte", "egyptien", "egyptienne", "lecaire", "egypt"], GQ: ["guineeequatoriale", "malabo"], ER: ["erythree", "erythreen", "asmara"],
  SZ: ["eswatini", "swaziland", "mbabane"], ET: ["ethiopie", "ethiopien", "addisabeba", "ethiopia"], GA: ["gabon", "gabonais", "libreville"],
  GM: ["gambie", "gambien", "banjul"], GH: ["ghana", "ghaneen", "accra"], GN: ["guinee", "conakry", "guineen"], GW: ["guineebissau", "bissau"],
  KE: ["kenya", "kenyan", "nairobi"], LS: ["lesotho", "maseru"], LR: ["liberia", "liberien", "monrovia"], LY: ["libye", "libyen", "tripoli", "libya"],
  MG: ["madagascar", "malgache", "antananarivo"], MW: ["malawi", "malawien", "lilongwe"], ML: ["mali", "malien", "bamako"], MR: ["mauritanie", "mauritanien", "nouakchott"],
  MU: ["ilemaurice", "mauricien", "portlouis"], MA: ["maroc", "marocain", "marocaine", "rabat", "casablanca", "morocco"], MZ: ["mozambique", "mozambicain", "maputo"],
  NA: ["namibie", "namibien", "windhoek"], NE: ["niger", "nigerien", "niamey"], NG: ["nigeria", "nigerian", "lagos", "abuja"], RW: ["rwanda", "rwandais", "kigali"],
  ST: ["saotome"], SN: ["senegal", "senegalais", "senegalaise", "dakar"], SC: ["seychelles", "seychellois"], SL: ["sierraleone", "freetown"],
  SO: ["somalie", "somalien", "mogadiscio", "somalia"], ZA: ["afriquedusud", "sudafricain", "pretoria", "johannesburg"], SS: ["soudandusud", "juba"],
  SD: ["soudan", "soudanais", "khartoum", "sudan"], TZ: ["tanzanie", "tanzanien", "dodoma", "daressalaam", "tanzania"], TG: ["togo", "togolais", "togolaise", "lome"],
  TN: ["tunisie", "tunisien", "tunisienne", "tunis", "tunisia"], UG: ["ouganda", "ougandais", "kampala", "uganda"], ZM: ["zambie", "zambien", "lusaka", "zambia"],
  ZW: ["zimbabwe", "zimbabween", "harare"],
  // hors d'Afrique : peuvent être choisis comme pays suivis
  FR: ["france", "francais", "francaise", "paris", "hexagone"], BE: ["belgique", "belge", "belges", "bruxelles"], CH: ["suisse", "suisses", "berne", "geneve"],
  CA: ["canada", "canadien", "canadienne", "ottawa", "montreal", "quebec"], US: ["etatsunis", "americain", "americaine", "washington", "usa"], GB: ["royaumeuni", "britannique", "londres", "london"],
};

const KEYWORD_TO_COUNTRY = new Map<string, string>();
for (const [code, words] of Object.entries(COUNTRY_KEYWORDS)) for (const w of words) KEYWORD_TO_COUNTRY.set(w, code);

function phrased(text: string): string[] {
  let t = ` ${strip(text)} `;
  for (const [from, to] of PHRASES) t = t.split(` ${from} `).join(` ${to} `);
  return t.trim().split(" ");
}

/**
 * Pays principal d'un sujet : un mot-clé dans le titre pèse 3, dans l'extrait 1 ; il faut au moins 3 points et le double du suivant.
 * Retourne null si aucun pays ne se détache (article général ou régional).
 */
export function detectCountry(title: string, body: string): string | null {
  const score = new Map<string, number>();
  for (const w of phrased(title)) { const c = KEYWORD_TO_COUNTRY.get(w); if (c) score.set(c, (score.get(c) ?? 0) + 3); }
  for (const w of phrased(body)) { const c = KEYWORD_TO_COUNTRY.get(w); if (c) score.set(c, (score.get(c) ?? 0) + 1); }
  const ranked = [...score.entries()].sort((a, b) => b[1] - a[1]);
  if (!ranked.length || ranked[0][1] < 3) return null;
  if (ranked[1] && ranked[1][1] * 2 > ranked[0][1]) return null;
  return ranked[0][0];
}

// ── Domaine ───────────────────────────────────────────────────────────────────────────────────────

const CATEGORY_WORDS: Record<NewsCategory, string[]> = {
  sport: ["football", "foot", "match", "matchs", "ligue", "coupe", "can", "mondial", "eliminatoires", "selection", "entraineur", "joueur", "joueurs", "equipe", "equipes", "champion", "championnat", "basket", "tennis", "athletisme", "olympique", "olympiques", "cyclisme", "rugby", "boxe", "caf", "fifa", "uefa", "transfert", "gardien", "attaquant", "afcon", "soccer", "league", "cup", "goal"],
  politique: ["president", "gouvernement", "ministre", "election", "elections", "elu", "parlement", "assemblee", "senat", "opposition", "parti", "loi", "reforme", "coup", "diplomatie", "sommet", "onu", "cedeao", "referendum", "constitution", "tribunal", "sanctions", "premier", "government", "minister", "parliament", "vote"],
  musique: ["musique", "chanson", "chanteur", "chanteuse", "album", "single", "clip", "concert", "rappeur", "rappeuse", "afrobeats", "afrobeat", "amapiano", "dj", "tournee", "music", "singer", "rapper"],
  culture: ["culture", "cinema", "film", "festival", "theatre", "litterature", "livre", "roman", "exposition", "musee", "art", "danse", "patrimoine", "serie", "spectacle", "ecrivain", "auteur", "peinture"],
  tech: ["technologie", "numerique", "intelligence", "artificielle", "ia", "startup", "startups", "application", "smartphone", "internet", "cybersecurite", "logiciel", "robot", "cloud", "blockchain", "fintech", "tech", "digital", "ai"],
  voyage: ["voyage", "tourisme", "touristes", "touristique", "destination", "vol", "compagnie", "aerienne", "hotel", "plage", "visa", "aeroport", "vacances", "croisiere", "airline", "travel", "tourism", "flight"],
};

/** Domaine d'un article : le domaine du flux s'il est thématique (la musique prend le pas sur la culture), sinon les mots-clés du titre (×2) et de l'extrait. */
export function classify(item: Pick<RawItem, "titre" | "resume" | "categoryHint">): NewsCategory | null {
  const score = (cat: NewsCategory): number => {
    const words = new Set(CATEGORY_WORDS[cat]);
    let s = 0;
    for (const w of strip(item.titre).split(" ")) if (words.has(w)) s += 2;
    for (const w of strip(item.resume).split(" ")) if (words.has(w)) s += 1;
    return s;
  };
  if (item.categoryHint) {
    if (item.categoryHint === "culture" && score("musique") >= 3) return "musique";
    return item.categoryHint;
  }
  const ranked = (Object.keys(CATEGORY_WORDS) as NewsCategory[]).map((c) => [c, score(c)] as const).sort((a, b) => b[1] - a[1]);
  if (ranked[0][1] < 2) return null;
  if (ranked[1][1] === ranked[0][1] && ranked[0][1] < 4) return null; // trop ambigu
  return ranked[0][0];
}

// ── Sujets ────────────────────────────────────────────────────────────────────────────────────────

export interface Topic {
  items: RawItem[];
  category: NewsCategory;
  level: "country" | "continent" | "world";
  country: string | null;
  distinctSources: number;
  score: number;
}

/** Regroupe les articles qui parlent du même sujet (titres proches), du plus récent au plus ancien. */
export function clusterItems(items: RawItem[]): RawItem[][] {
  const sorted = [...items].sort((a, b) => b.date.localeCompare(a.date));
  const groups: Array<{ members: RawItem[]; tokens: Set<string>[] }> = [];
  for (const it of sorted) {
    const t = titleTokens(it.titre);
    const home = groups.find((g) => g.tokens.some((x) => similar(x, t)));
    if (home) { home.members.push(it); home.tokens.push(t); } else groups.push({ members: [it], tokens: [t] });
  }
  return groups.map((g) => g.members);
}

/** Pays configurés pour des articles « pays » : un sujet sur un autre pays africain part au niveau continent. */
export function scopeOf(country: string | null, configured: string[], region: "africa" | "world"): { level: Topic["level"]; country: string | null } {
  if (country && configured.includes(country)) return { level: "country", country };
  if (country || region === "africa") return { level: "continent", country: null };
  return { level: "world", country: null };
}

export function scoreTopic(items: RawItem[], nowMs: number, configuredCountry: boolean): number {
  const sources = new Set(items.map((i) => i.sourceName)).size; // médias distincts (deux flux d'un même média comptent pour un)
  const newest = Math.max(...items.map((i) => Date.parse(i.date) || 0));
  const ageH = Math.max(0, (nowMs - newest) / 3_600_000);
  const rich = items.some((i) => i.corps.length > 300) ? 1 : 0;
  return sources * 4 + Math.max(0, 4 - ageH / 6) + (items.some((i) => i.image) ? 1 : 0) + rich + (configuredCountry ? 1 : 0);
}

/** Sujets prêts à être résumés : domaine connu, récents (36 h), matière suffisante (un seul article doit avoir un vrai extrait). */
export function buildTopics(items: RawItem[], configured: string[], nowMs = Date.now()): Topic[] {
  const fresh = items.filter((i) => nowMs - (Date.parse(i.date) || 0) <= 36 * 3_600_000 && Date.parse(i.date) <= nowMs + 3_600_000);
  const topics: Topic[] = [];
  for (const members of clusterItems(fresh)) {
    const cats = members.map((m) => classify(m)).filter((c): c is NewsCategory => !!c);
    if (!cats.length) continue;
    const counts = new Map<NewsCategory, number>();
    for (const c of cats) counts.set(c, (counts.get(c) ?? 0) + 1);
    const category = [...counts.entries()].sort((a, b) => b[1] - a[1])[0][0];
    const distinct = new Set(members.map((m) => m.sourceName)).size;
    if (distinct === 1 && !members.some((m) => m.corps.length >= 200 || m.resume.length >= 160)) continue;
    const country = detectCountry(members[0].titre, members.map((m) => m.resume).join(" "));
    const region = members.some((m) => m.region === "africa") ? "africa" : "world";
    const { level, country: cc } = scopeOf(country, configured, region);
    topics.push({ items: members, category, level, country: cc, distinctSources: distinct, score: scoreTopic(members, nowMs, level === "country") });
  }
  return topics.sort((a, b) => b.score - a.score);
}

/** Mots capitalisés trop généraux pour reconnaître un événement (continents, médias, organisations, fonctions). */
const GENERIC_NAMES = new Set(["afrique", "europe", "asie", "monde", "france", "paris", "africanews", "coupe", "ligue", "champions", "league", "president", "premier", "ministre", "gouvernement"]);

/** Noms propres et nombres d'un titre (hors pays, hors début de phrase) : ils reconnaissent un même événement raconté dans une autre langue. */
export function entityTokens(title: string): Set<string> {
  const out = new Set<string>();
  String(title || "").split(/[\s«»"“”'’,:;()!?–—-]+/).filter(Boolean).forEach((w, i) => {
    if (i > 0 && /^\p{Lu}[\p{L}]{3,}$/u.test(w)) {
      const n = strip(w);
      if (n && !KEYWORD_TO_COUNTRY.has(n) && !GENERIC_NAMES.has(n)) out.add(n);
    } else if (/^\d{2,}$/.test(w) && !/^(19|20)\d{2}$/.test(w)) out.add(w);
  });
  return out;
}

export interface Fingerprint { t: Set<string>; e: Set<string> }
export const fingerprint = (title: string): Fingerprint => ({ t: titleTokens(title), e: entityTokens(title) });

/** Deux titres racontent-ils le même événement ? Titres proches, ou au moins deux noms propres / nombres en commun (même en deux langues). */
export function sameFingerprint(a: Fingerprint, b: Fingerprint): boolean {
  if (similar(a.t, b.t)) return true;
  let shared = 0;
  for (const x of a.e) if (b.e.has(x)) shared++;
  return shared >= 2;
}
export const sameStory = (a: string, b: string): boolean => sameFingerprint(fingerprint(a), fingerprint(b));

/** Identifiant stable d'un lien d'article (sert à ne jamais republier la même source). */
export const linkHash = (url: string): string => createHash("sha1").update(url.replace(/[?#].*$/, "")).digest("hex").slice(0, 20);
