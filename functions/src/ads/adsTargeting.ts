/**
 * Afrolook Ads : ciblage, comme la publicité ciblée de Google. L'ANNONCEUR définit à qui son annonce s'adresse, et nous le respectons :
 *  - pays (liste) ou toute l'Afrique (la liste des pays d'Afrique) ou le monde entier (« ALL » : aucune contrainte de pays) ;
 *  - langues, appareils (téléphone ou ordinateur) et types de sites ou d'applications (catégories), tous facultatifs.
 * Le pays du visiteur est déterminé PAR LE SERVEUR à partir de l'adresse IP (jamais par le site diffuseur, qui pourrait mentir).
 * Règle de pays : si l'annonce vise des pays précis, au plus 40 % de ses vues peuvent venir d'autres pays (marge de sécurité à 35 % à la diffusion).
 * Logique pure, testée dans __tests__/adsTargeting.test.ts.
 */

export const AFRICA = [
  "DZ", "AO", "BJ", "BW", "BF", "BI", "CM", "CV", "CF", "TD", "KM", "CG", "CD", "CI", "DJ", "EG", "GQ", "ER", "SZ", "ET", "GA", "GM", "GH", "GN", "GW", "KE", "LS", "LR", "LY", "MG", "MW", "ML",
  "MR", "MU", "MA", "MZ", "NA", "NE", "NG", "RW", "ST", "SN", "SC", "SL", "SO", "ZA", "SS", "SD", "TZ", "TG", "TN", "UG", "ZM", "ZW",
];

export const OFF_TARGET_MAX = 0.4; // limite annoncée : au plus 40 % de vues hors des pays visés
export const OFF_TARGET_GUARD = 0.35; // seuil de diffusion : marge pour les écarts entre serveurs et le temps de cumul
export const GEO_MIN_SAMPLE = 20; // en dessous, on ne diffuse hors cible que si la part reste sous le seuil avec la nouvelle vue

export interface Targeting {
  /** pays visés ; « ALL » = le monde entier */ countries: string[];
  languages: string[]; devices: Array<"mobile" | "desktop">; categories: string[];
}
const arr = (v: unknown): string[] => (Array.isArray(v) ? (v as unknown[]).map((x) => String(x ?? "")).filter(Boolean) : []);

export function targetingOf(a: Record<string, unknown>, postCountries: unknown): Targeting {
  const countries = arr(postCountries).map((c) => c.toUpperCase());
  return {
    countries: countries.length && !countries.includes("ALL") ? countries : ["ALL"],
    languages: arr(a["targetLanguages"]).map((x) => x.toLowerCase()).slice(0, 8),
    devices: arr(a["targetDevices"]).filter((x): x is "mobile" | "desktop" => x === "mobile" || x === "desktop"),
    categories: arr(a["targetCategories"]).slice(0, 12),
  };
}

export type GeoMatch = "any" | "in" | "out" | "unknown";
/** « any » : l'annonce n'a aucune contrainte de pays ; « in » : le visiteur est dans un pays visé ; « out » : dans un autre pays ; « unknown » : pays introuvable. */
export function geoMatch(t: Targeting, cc: string | null): GeoMatch {
  if (t.countries.includes("ALL")) return "any";
  if (!cc) return "unknown";
  return t.countries.includes(cc) ? "in" : "out";
}

export interface GeoCount { in: number; out: number; unknown: number }
/**
 * Peut-on diffuser à ce visiteur ? Dans les pays visés : toujours. Hors cible (autre pays ou pays inconnu) : seulement si, avec cette vue,
 * la part de vues hors cible reste sous le seuil (35 %) ET après un minimum de vues ciblées déjà obtenues : une annonce neuve n'est jamais lancée hors cible.
 */
export function geoAllowed(m: GeoMatch, c: GeoCount): boolean {
  if (m === "any" || m === "in") return true;
  const off = c.out + c.unknown, total = c.in + off;
  if (total < GEO_MIN_SAMPLE) return false;
  return (off + 1) / (total + 1) <= OFF_TARGET_GUARD;
}

export const deviceOf = (ua: unknown): "mobile" | "desktop" => (/Mobi|Android|iPhone|iPad|iPod/i.test(String(ua ?? "")) ? "mobile" : "desktop");

/** Langue du visiteur : celle annoncée par le composant (2 lettres) sinon la première de l'en-tête Accept-Language. */
export function langOf(param: unknown, header: unknown): string {
  const raw = String(param ?? "").toLowerCase();
  if (/^[a-z]{2}([-_][a-z0-9]{2,8})?$/.test(raw)) return raw.slice(0, 2);
  const h = String(header ?? "").toLowerCase().match(/^([a-z]{2})/);
  return h ? h[1] : "";
}

export interface Ctx { lang: string; device: "mobile" | "desktop"; category: string }
/** Langue, appareil et type de site : un critère vide veut dire « sans contrainte » ; une langue ou une catégorie inconnue n'exclut pas (on ne bloque pas sans preuve). */
export function profileMatches(t: Targeting, c: Ctx): boolean {
  if (t.languages.length && c.lang && !t.languages.includes(c.lang)) return false;
  if (t.devices.length && !t.devices.includes(c.device)) return false;
  if (t.categories.length && c.category && !t.categories.includes(c.category)) return false;
  return true;
}

/** Catégorie de nos propres plateformes, pour le ciblage par type de site. */
export const INTERNAL_CATEGORY: Record<string, string> = { afrolook: "reseau_social", site: "actualites", slashatlas: "technologie", pronoflash: "sport", epargneplus: "finance" };

/** Part de visiteurs venant des pays annoncés par le diffuseur (contrôle de cohérence : un site qui se dit togolais doit avoir des visiteurs togolais). */
export function declaredShare(geo: Record<string, number>, declared: string[]): { share: number; total: number } {
  let total = 0, inside = 0;
  for (const [cc, n] of Object.entries(geo)) { const v = Number(n) || 0; total += v; if (declared.includes(cc)) inside += v; }
  return { share: total ? Math.round((inside / total) * 1000) / 1000 : 0, total };
}
