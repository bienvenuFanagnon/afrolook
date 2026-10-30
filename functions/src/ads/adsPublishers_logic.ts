/**
 * Afrolook Ads : diffuseurs (propriétaires de sites et d'applications qui affichent nos annonces). Logique pure, testée dans __tests__/adsPublishers.test.ts.
 *
 * Parcours : le diffuseur crée un PROFIL (validé par l'administration), puis ajoute un ou plusieurs SITES ou APPLICATIONS (en ligne obligatoirement).
 * Chaque site ou application est une « propriété » avec sa propre demande (acceptée ou refusée) et son propre IDENTIFIANT PUBLICITAIRE (ap_xxxxxxxxxx).
 * Audience du réseau affichée aux annonceurs = 50 000 (nos plateformes) + audience retenue des propriétés validées.
 */
import { randomBytes } from "crypto";
import { cleanAccepted } from "./adsCategories";

export const BASE_AUDIENCE = 50_000;
export const MAX_PROPERTIES = 10;

export const CATEGORIES: Record<string, string> = {
  actualites: "Actualités et médias",
  sport: "Sport",
  paris_sportifs: "Pronostics et paris sportifs",
  divertissement: "Divertissement, musique, vidéo",
  education: "Éducation et formation",
  finance: "Finance, épargne, mobile money",
  sante: "Santé et bien-être",
  boutique: "Boutique et commerce en ligne",
  technologie: "Technologie et outils",
  jeux: "Jeux",
  reseau_social: "Réseau social et communauté",
  emploi: "Emploi et annonces",
  religion: "Religion et spiritualité",
  jeunesse: "Jeunesse et famille",
  autre: "Autre",
};

export type ProfileStatus = "pending" | "active" | "refused" | "suspended";
export type PropertyStatus = "pending" | "active" | "refused" | "suspended" | "removed";

export interface ProfileInput {
  type: "individual" | "company"; name: string; country: string; city: string; phone: string; website: string; about: string;
}
export interface PropertyInput {
  kind: "site" | "app"; name: string; url: string; androidUrl: string; iosUrl: string; packageName: string;
  category: string; countries: string[]; languages: string[]; audienceMonthly: number; sessionsMonthly: number; description: string;
  /** catégories d'annonces que le diffuseur accepte d'afficher chez lui (par défaut : toutes les catégories standard ; les sensibles seulement si cochées) */
  acceptedCategories: string[];
}
type Res<T> = { ok: true; value: T } | { ok: false; error: string };

const clean = (v: unknown, n: number): string => String(v ?? "").replace(/[\u0000-\u001f<>]/g, " ").replace(/\s+/g, " ").trim().slice(0, n);
const ISO2 = /^[A-Z]{2}$/;

/** Adresse https publique d'un site : pas d'identifiants, pas de port, pas d'adresse IP, pas de localhost. Renvoie l'adresse nettoyée ou null. */
export function cleanSiteUrl(raw: unknown): string | null {
  try {
    const u = new URL(String(raw ?? "").trim());
    if (u.protocol !== "https:" || u.username || u.password || (u.port && u.port !== "443")) return null;
    const h = u.hostname.toLowerCase();
    if (!h.includes(".") || /^[0-9.]+$/.test(h) || h === "localhost" || h.endsWith(".local") || h.endsWith(".internal") || h.includes("[")) return null;
    if (h.length > 120 || !/^[a-z0-9.-]+$/.test(h)) return null;
    u.hash = "";
    return u.toString();
  } catch { return null; }
}

export function playPackage(url: string): string | null {
  try {
    const u = new URL(url);
    if (u.protocol !== "https:" || u.hostname !== "play.google.com" || u.pathname !== "/store/apps/details") return null;
    const id = u.searchParams.get("id") ?? "";
    return /^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+$/.test(id) ? id : null;
  } catch { return null; }
}
export const cleanPlayUrl = (raw: unknown): string | null => { const p = playPackage(String(raw ?? "").trim()); return p ? `https://play.google.com/store/apps/details?id=${p}` : null; };
export function cleanAppleUrl(raw: unknown): string | null {
  try {
    const u = new URL(String(raw ?? "").trim());
    if (u.protocol !== "https:" || u.hostname !== "apps.apple.com" || !/\/app\/[^/]*\/?id[0-9]{6,12}|\/app\/id[0-9]{6,12}/.test(u.pathname)) return null;
    u.search = ""; u.hash = "";
    return u.toString();
  } catch { return null; }
}

export const hostOf = (url: string): string | null => { try { return new URL(url).hostname.toLowerCase().replace(/^www\./, ""); } catch { return null; } };
/** Origines autorisées d'un site : l'adresse principale et sa variante avec ou sans www (contrôle de l'en-tête Origin des appels). */
export function originsOf(url: string): string[] {
  const h = hostOf(url); if (!h) return [];
  return [`https://${h}`, `https://www.${h}`];
}

export function validateProfile(d: unknown): Res<ProfileInput> {
  const o = (d ?? {}) as Record<string, unknown>;
  const type = o["type"] === "company" ? "company" : o["type"] === "individual" ? "individual" : "";
  if (!type) return { ok: false, error: "type de profil manquant" };
  const name = clean(o["name"], 80);
  if (name.length < 2) return { ok: false, error: "nom ou entreprise manquant" };
  const country = String(o["country"] ?? "").toUpperCase();
  if (!ISO2.test(country)) return { ok: false, error: "pays manquant" };
  const city = clean(o["city"], 60);
  if (city.length < 2) return { ok: false, error: "ville manquante" };
  const phone = String(o["phone"] ?? "").replace(/[^\d+]/g, "");
  if (!/^\+?\d{8,15}$/.test(phone)) return { ok: false, error: "numéro WhatsApp invalide" };
  const wRaw = String(o["website"] ?? "").trim();
  const website = wRaw ? cleanSiteUrl(wRaw) : "";
  if (wRaw && !website) return { ok: false, error: "adresse du site invalide (https obligatoire)" };
  const about = clean(o["about"], 300);
  if (about.length < 20) return { ok: false, error: "présentation trop courte (20 caractères au moins)" };
  if (o["acceptTerms"] !== true) return { ok: false, error: "conditions à accepter" };
  return { ok: true, value: { type, name, country, city, phone, website: website ?? "", about } };
}

export function validateProperty(d: unknown): Res<PropertyInput> {
  const o = (d ?? {}) as Record<string, unknown>;
  const kind = o["kind"] === "app" ? "app" : o["kind"] === "site" ? "site" : "";
  if (!kind) return { ok: false, error: "type manquant (site ou application)" };
  const name = clean(o["name"], 80);
  if (name.length < 2) return { ok: false, error: "nom manquant" };
  let url = "", androidUrl = "", iosUrl = "", packageName = "";
  if (kind === "site") {
    const u = cleanSiteUrl(o["url"]);
    if (!u) return { ok: false, error: "adresse du site invalide (https obligatoire, adresse publique)" };
    url = u;
  } else {
    androidUrl = cleanPlayUrl(o["androidUrl"]) ?? "";
    iosUrl = cleanAppleUrl(o["iosUrl"]) ?? "";
    if (String(o["androidUrl"] ?? "").trim() && !androidUrl) return { ok: false, error: "lien Google Play invalide" };
    if (String(o["iosUrl"] ?? "").trim() && !iosUrl) return { ok: false, error: "lien App Store invalide" };
    if (!androidUrl && !iosUrl) return { ok: false, error: "lien Google Play ou App Store obligatoire (l'application doit être en ligne)" };
    packageName = androidUrl ? playPackage(androidUrl) ?? "" : "";
  }
  const category = String(o["category"] ?? "");
  if (!Object.prototype.hasOwnProperty.call(CATEGORIES, category)) return { ok: false, error: "catégorie invalide" };
  const countries = (Array.isArray(o["countries"]) ? (o["countries"] as unknown[]) : []).map((c) => String(c ?? "").toUpperCase()).filter((c) => ISO2.test(c));
  const uniq = [...new Set(countries)].slice(0, 12);
  if (!uniq.length) return { ok: false, error: "au moins un pays d'audience" };
  const languages = [...new Set((Array.isArray(o["languages"]) ? (o["languages"] as unknown[]) : []).map((l) => String(l ?? "").toLowerCase()).filter((l) => /^[a-z]{2}$/.test(l)))].slice(0, 5);
  const audienceMonthly = Math.floor(Number(o["audienceMonthly"]));
  if (!Number.isFinite(audienceMonthly) || audienceMonthly < 100 || audienceMonthly > 100_000_000) return { ok: false, error: "audience mensuelle invalide (100 personnes au moins)" };
  const sessionsRaw = Math.floor(Number(o["sessionsMonthly"] ?? 0));
  const sessionsMonthly = Number.isFinite(sessionsRaw) && sessionsRaw > 0 ? Math.min(sessionsRaw, 1_000_000_000) : 0;
  const description = clean(o["description"], 400);
  if (description.length < 20) return { ok: false, error: "description trop courte (20 caractères au moins)" };
  return { ok: true, value: { kind, name, url, androidUrl, iosUrl, packageName, category, countries: uniq, languages, audienceMonthly, sessionsMonthly, description, acceptedCategories: cleanAccepted(o["acceptedCategories"]) } };
}

/** Identifiant publicitaire d'un site ou d'une application, à poser dans la balise ou le composant (ap_ + 10 caractères). */
export function newPropertyId(): string {
  let s = "";
  while (s.length < 10) s += randomBytes(8).toString("base64").replace(/[^a-z0-9]/gi, "").toLowerCase();
  return `ap_${s.slice(0, 10)}`;
}
export const isPropertyId = (v: unknown): boolean => /^ap_[a-z0-9]{10}$/.test(String(v ?? ""));
export const newVerifyToken = (): string => `afl-${randomBytes(12).toString("hex")}`;

/** Le site prouve qu'il appartient au diffuseur : le code est dans une balise <meta name="afrolook-ads-verify"> de l'accueil ou dans /afrolook-ads.txt. */
export function pageHasToken(body: string, token: string): boolean {
  if (!token) return false;
  const re = /<meta[^>]+name=["']afrolook-ads-verify["'][^>]*>/gi;
  const metas = body.match(re) ?? [];
  if (metas.some((m) => m.includes(token))) return true;
  return body.trim() === token;
}

export interface AudienceRow { status: string; audienceCounted?: number }
/** Audience estimée du réseau : 50 000 + audience retenue des sites et applications validés. */
export function audienceEstimate(rows: AudienceRow[]): { base: number; partners: number; total: number; count: number } {
  let partners = 0, count = 0;
  for (const r of rows) {
    if (r.status !== "active") continue;
    const n = Math.max(0, Math.floor(Number(r.audienceCounted) || 0));
    if (n > 0) { partners += n; count++; }
  }
  return { base: BASE_AUDIENCE, partners, total: BASE_AUDIENCE + partners, count };
}

/** Audience retenue par l'administration : par défaut celle déclarée, mais jamais plus que la valeur déclarée ni négative. */
export function countedAudience(declared: number, requested: unknown): number {
  const dcl = Math.max(0, Math.floor(Number(declared) || 0));
  if (requested == null || requested === "") return dcl;
  const r = Math.floor(Number(requested));
  return Number.isFinite(r) ? Math.max(0, Math.min(r, dcl)) : dcl;
}
