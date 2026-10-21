/**
 * Géographie des actualités : continent d'un pays (code ISO à 2 lettres) et clé de périmètre d'un article.
 * Trois niveaux de diffusion : le pays de la personne en priorité, puis son continent, puis le monde.
 * La même table existe côté application (lib/utils/country_continent.dart, générée à partir de ce fichier).
 */
export type NewsLevel = "country" | "continent" | "world";
export const NEWS_LEVELS: NewsLevel[] = ["country", "continent", "world"];

/** AF Afrique · EU Europe · AS Asie · NA Amérique du Nord, centrale et Caraïbes · SA Amérique du Sud · OC Océanie. */
export const CONTINENTS = ["AF", "EU", "AS", "NA", "SA", "OC"] as const;
export type Continent = (typeof CONTINENTS)[number];

const BY_CONTINENT: Record<Continent, string> = {
  AF: "DZ AO BJ BW BF BI CM CV CF TD KM CG CD CI DJ EG GQ ER SZ ET GA GM GH GN GW KE LS LR LY MG MW ML MR MU MA MZ NA NE NG RW ST SN SC SL SO ZA SS SD TZ TG TN UG ZM ZW EH RE YT SH",
  EU: "AL AD AT BY BE BA BG HR CY CZ DK EE FO FI FR DE GI GR GG HU IS IE IM IT JE XK LV LI LT LU MT MD MC ME NL MK NO PL PT RO RU SM RS SK SI ES SJ SE CH UA GB VA AX",
  AS: "AF AM AZ BH BD BT BN KH CN GE HK IN ID IR IQ IL JP JO KZ KW KG LA LB MO MY MV MN MM NP KP OM PK PS PH QA SA SG KR LK SY TW TJ TH TL TR TM AE UZ VN YE",
  NA: "AG BS BB BZ CA CR CU DM DO SV GD GT HT HN JM MX NI PA KN LC VC TT US AI AW BM BQ VG KY CW GL GP MQ MS PR BL MF PM SX TC VI UM",
  SA: "AR BO BR CL CO EC FK GF GY PY PE SR UY VE",
  OC: "AU FJ KI MH FM NR NZ PW PG WS SB TO TV VU AS CK PF GU MP NC NU NF PN TK WF",
};

export const CONTINENT_OF: Record<string, Continent> = (() => {
  const out: Record<string, Continent> = {};
  for (const c of CONTINENTS) for (const code of BY_CONTINENT[c].split(" ")) out[code] = c;
  return out;
})();

export function continentOf(country: unknown): Continent | null {
  const code = String(country ?? "").trim().toUpperCase();
  return CONTINENT_OF[code] ?? null;
}

/**
 * Clé du périmètre d'un article, qui sert d'identifiant à l'index du fil (NewsFeed/{clé}) :
 * `country_TG`, `continent_AF` ou `world`.
 */
export function scopeKey(level: NewsLevel, country?: unknown, continent?: unknown): string | null {
  if (level === "world") return "world";
  if (level === "continent") {
    const c = String(continent ?? "").toUpperCase();
    return (CONTINENTS as readonly string[]).includes(c) ? `continent_${c}` : null;
  }
  const code = String(country ?? "").trim().toUpperCase();
  return /^[A-Z]{2}$/.test(code) ? `country_${code}` : null;
}

/** Périmètres à lire pour une personne, du plus proche au plus large : son pays, son continent, le monde. */
export function scopesForUser(country: unknown): string[] {
  const code = String(country ?? "").trim().toUpperCase();
  const out: string[] = [];
  if (/^[A-Z]{2}$/.test(code)) out.push(`country_${code}`);
  const cont = continentOf(code);
  if (cont) out.push(`continent_${cont}`);
  out.push("world");
  return out;
}
