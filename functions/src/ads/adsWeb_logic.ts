/**
 * Afrolook Ads (annonceurs sur afrolookmedia.com/ads/) : règles de validation d'une annonce déposée depuis le site.
 * Elles adaptent le système de pub existant (collection Advertisements + post lié) : mêmes boutons d'action, mêmes statuts
 * (pending → active / rejected), même validation par les administrateurs. Offre de lancement : 3 annonces gratuites en même temps,
 * 14 jours chacune. Voir docs/PROJET_MEMOIRE.md (29/10/2026).
 */
import { AFRICA } from "./adsTargeting";
import { CATEGORIES } from "./adsPublishers_logic";
import { isCategory } from "./adsCategories";

export const MAX_FREE_ADS = 3;
export const FREE_DAYS = 14;
/** Une vidéo d'annonce dure 15 secondes au maximum (décision du propriétaire, 29/10/2026) : elle doit être vue vite. */
export const MAX_VIDEO_SECONDS = 15;
export const MAX_PER_DAY = 6; // créations par jour et par compte (anti-abus, en plus des 3 annonces en même temps)
/** Une journée en microsecondes : les dates des annonces (startDate, endDate) sont en microsecondes, comme dans l'application. */
export const DAY_MICROS = 86_400_000_000;

/** Bannières prêtes à l'emploi (image seule, cliquable en entier), aux tailles standard d'AdMob : leaderboard, mini bannière du bas des applications, grande bannière, rectangle moyen. */
export const BANNER_SIZES = { b728x90: [728, 90], b320x50: [320, 50], b320x100: [320, 100], b300x250: [300, 250] } as const;
export type BannerKey = keyof typeof BANNER_SIZES;
/** « 728x90 » (paramètre d'adsServe) → clé de stockage « b728x90 » ; null si la taille n'existe pas. */
export const bannerKeyOf = (v: unknown): BannerKey | null => { const k = `b${String(v ?? "")}`; return Object.prototype.hasOwnProperty.call(BANNER_SIZES, k) ? (k as BannerKey) : null; };

export const KINDS = ["entreprise", "site", "app", "projet", "affiche"] as const; // « entreprise » couvre aussi les startups
export type AdKind = (typeof KINDS)[number];
export const ACTIONS = ["visit", "download", "learn_more", "whatsapp", "call"] as const;
export type AdAction = (typeof ACTIONS)[number];
export const ACTION_LABEL: Record<AdAction, string> = { visit: "Visiter", download: "Télécharger", learn_more: "En savoir plus", whatsapp: "WhatsApp", call: "Appeler" };

export interface AdInput {
  kind: AdKind;
  title: string;
  text: string;
  mediaType: "image" | "video";
  images: string[];
  /** bannières prêtes (facultatif) : clé de taille → image du stockage */
  bannerImages: Record<string, string>;
  videoUrl: string;
  thumbnailUrl: string;
  /** Durée de la vidéo en secondes (mesurée sur le site ; l'administrateur la revoit à la validation). */
  videoDuration: number;
  action: AdAction;
  /** Adresse du bouton (https://… ; https://wa.me/… pour WhatsApp ; tel:+… pour Appeler). */
  actionUrl: string;
  /** pays visés (« ALL » = le monde entier ; « toute l'Afrique » est développée en la liste des pays d'Afrique) */
  countries: string[];
  /** ciblage facultatif défini par l'annonceur : région (AFRICA), langues, appareils (mobile, desktop), types de sites */
  regions: string[]; languages: string[]; devices: string[]; categories: string[];
  /** catégorie de l'annonce (obligatoire) : les diffuseurs choisissent celles qu'ils acceptent d'afficher */
  category: string;
}

/** Fichiers déposés par l'annonceur dans le stockage Firebase (dossiers de l'application : ad_images, ad_videos, ad_thumbnails). */
export const mediaUrlPattern = (bucket: string): RegExp =>
  new RegExp(`^https://firebasestorage\\.googleapis\\.com/v0/b/${bucket.replace(/\./g, "\\.")}/o/ad_(images|videos|thumbnails)%2F[A-Za-z0-9._%-]{1,200}\\?alt=media(&token=[A-Za-z0-9-]{8,80})?$`);

const clean = (v: unknown, max: number): string =>
  String(v ?? "").replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g, "").replace(/<[^>]*>/g, "").trim().slice(0, max);

/** Adresse https publique plausible (pas de localhost, pas d'adresse IP, pas de schéma dangereux). */
export function safeHttpsUrl(v: unknown): string | null {
  const s = String(v ?? "").trim();
  if (s.length > 300 || !/^https:\/\//i.test(s)) return null;
  let u: URL;
  try { u = new URL(s); } catch { return null; }
  const h = u.hostname.toLowerCase();
  if (u.protocol !== "https:" || u.username || u.password) return null;
  if (!h.includes(".") || h === "localhost" || /^\d{1,3}(\.\d{1,3}){3}$/.test(h) || h.includes(":") || h.endsWith(".local")) return null;
  return u.toString();
}

/** Numéro de téléphone : chiffres avec « + » facultatif au début, 8 à 15 chiffres. Retourne le numéro nettoyé ou null. */
export function cleanPhone(v: unknown): string | null {
  const s = String(v ?? "").replace(/[\s().-]/g, "");
  return /^\+?\d{8,15}$/.test(s) ? s : null;
}

export type Validation = { ok: true; value: AdInput } | { ok: false; error: string };

export function validateAdInput(raw: unknown, bucket: string): Validation {
  const d = (raw ?? {}) as Record<string, unknown>;
  const kind = String(d["kind"] ?? "") as AdKind;
  if (!KINDS.includes(kind)) return { ok: false, error: "type d'annonce invalide" };
  const title = clean(d["title"], 60);
  const text = clean(d["text"], 220);
  if (title.length < 2) return { ok: false, error: "titre trop court" };
  if (text.length < 10) return { ok: false, error: "texte trop court (10 caractères minimum)" };

  const mediaType = d["mediaType"] === "video" ? "video" : "image";
  const re = mediaUrlPattern(bucket);
  const images = (Array.isArray(d["images"]) ? (d["images"] as unknown[]) : []).map((x) => String(x ?? "")).filter(Boolean);
  const videoUrl = String(d["videoUrl"] ?? "");
  const thumbnailUrl = String(d["thumbnailUrl"] ?? "");
  if (mediaType === "image") {
    if (images.length < 1 || images.length > 5) return { ok: false, error: "entre 1 et 5 images" };
    if (!images.every((u) => re.test(u) && u.includes("/o/ad_images%2F"))) return { ok: false, error: "image non reconnue" };
  } else {
    if (!re.test(videoUrl) || !videoUrl.includes("/o/ad_videos%2F")) return { ok: false, error: "vidéo non reconnue" };
    const dur = Number(d["videoDuration"]);
    if (!Number.isFinite(dur) || dur <= 0) return { ok: false, error: "durée de la vidéo inconnue" };
    if (dur > MAX_VIDEO_SECONDS + 0.5) return { ok: false, error: `la vidéo doit durer ${MAX_VIDEO_SECONDS} secondes maximum` };
    if (thumbnailUrl && (!re.test(thumbnailUrl) || !thumbnailUrl.includes("/o/ad_thumbnails%2F"))) return { ok: false, error: "miniature non reconnue" };
  }

  const category = String(d["category"] ?? "");
  if (!isCategory(category)) return { ok: false, error: "catégorie de l'annonce manquante" };
  const action = String(d["action"] ?? "") as AdAction;
  if (!ACTIONS.includes(action)) return { ok: false, error: "bouton d'action invalide" };
  let actionUrl: string | null;
  if (action === "whatsapp") {
    const p = cleanPhone(d["phone"] ?? d["link"]);
    actionUrl = p ? `https://wa.me/${p.replace("+", "")}` : null;
  } else if (action === "call") {
    const p = cleanPhone(d["phone"] ?? d["link"]);
    actionUrl = p ? `tel:${p.startsWith("+") ? p : `+${p}`}` : null;
  } else {
    actionUrl = safeHttpsUrl(d["link"]);
  }
  if (!actionUrl) return { ok: false, error: action === "whatsapp" || action === "call" ? "numéro de téléphone invalide" : "lien invalide (il doit commencer par https://)" };

  let countries = (Array.isArray(d["countries"]) ? (d["countries"] as unknown[]) : []).map((c) => String(c ?? "").toUpperCase());
  countries = [...new Set(countries)].slice(0, 80);
  if (countries.includes("ALL") || countries.length === 0) countries = ["ALL"];
  else if (!countries.every((c) => /^[A-Z]{2}$/.test(c))) return { ok: false, error: "pays invalide" };
  // ciblage de l'annonceur : région, langues, appareils, types de sites (tout est facultatif ; vide = sans contrainte)
  const list = (k: string): string[] => (Array.isArray(d[k]) ? (d[k] as unknown[]) : []).map((x) => String(x ?? ""));
  const regions = list("regions").filter((r) => r === "AFRICA");
  if (regions.includes("AFRICA")) countries = [...new Set([...countries.filter((c) => c !== "ALL"), ...AFRICA])];
  const languages = [...new Set(list("languages").map((l) => l.toLowerCase()).filter((l) => /^[a-z]{2}$/.test(l)))].slice(0, 5);
  const devices = [...new Set(list("devices").filter((x) => x === "mobile" || x === "desktop"))];
  const categories = [...new Set(list("categories").filter((c) => Object.prototype.hasOwnProperty.call(CATEGORIES, c)))].slice(0, 8);

  const bn = d["banners"] && typeof d["banners"] === "object" ? (d["banners"] as Record<string, unknown>) : {};
  const bannerImages: Record<string, string> = {};
  for (const k of Object.keys(BANNER_SIZES)) {
    const u = String(bn[k] ?? ""); if (!u) continue;
    if (!re.test(u) || !u.includes("/o/ad_images%2F")) return { ok: false, error: "bannière non reconnue" };
    bannerImages[k] = u;
  }

  return { ok: true, value: { category, regions, languages, devices, categories, kind, title, text, mediaType, bannerImages, images: mediaType === "image" ? images : [], videoUrl: mediaType === "video" ? videoUrl : "", thumbnailUrl: mediaType === "video" ? thumbnailUrl : "", videoDuration: mediaType === "video" ? Math.round(Number(d["videoDuration"]) * 10) / 10 : 0, action, actionUrl, countries } };
}

/** Une annonce occupe une place gratuite tant qu'elle est en attente de validation ou en ligne et pas terminée. */
export function occupiesFreeSlot(ad: { status?: unknown; endDate?: unknown }, nowMicros: number): boolean {
  const st = String(ad.status ?? "");
  if (st === "pending") return true;
  if (st === "active") return Number(ad.endDate) > nowMicros;
  return false;
}

/** Statut affiché à l'annonceur : en validation, en ligne, refusée, arrêtée, terminée. */
export function displayStatus(ad: { status?: unknown; endDate?: unknown }, nowMicros: number): "validation" | "ligne" | "refusee" | "arretee" | "terminee" {
  const st = String(ad.status ?? "");
  if (st === "pending") return "validation";
  if (st === "rejected") return "refusee";
  if (st === "cancelled") return "arretee";
  if (st === "active") return Number(ad.endDate) > nowMicros ? "ligne" : "terminee";
  return "terminee";
}

/** Jours restants (arrondi au-dessus) d'une annonce en ligne. */
export const daysLeft = (endMicros: number, nowMicros: number): number => Math.max(0, Math.ceil((endMicros - nowMicros) / DAY_MICROS));

// ─── Règles de la gratuité (décisions du propriétaire, 29/10/2026) ───────────────────────────────────────────────
/**
 * - 3 annonces gratuites AU TOTAL par compte (une annonce refusée ne compte pas : l'annonceur peut la corriger et la redéposer) ;
 * - chaque annonce reste 14 jours, puis peut être renouvelée gratuitement UNE fois (2 périodes gratuites) ;
 * - ensuite : le paiement habituel des pubs Afrolook (dans l'application) ;
 * - tout est réglable dans AppConfig/adsWeb : pour supprimer la gratuité dans quelques mois, mettre freeAds à 0 (rien d'autre à changer).
 */
export interface AdsWebConfig { enabled: boolean; freeAds: number; freePeriods: number; freeDays: number }
export const DEFAULT_ADSWEB_CONFIG: AdsWebConfig = { enabled: true, freeAds: MAX_FREE_ADS, freePeriods: 2, freeDays: FREE_DAYS };

export function readAdsWebConfig(d: Record<string, unknown> | undefined): AdsWebConfig {
  const o = d ?? {};
  const D = DEFAULT_ADSWEB_CONFIG;
  const n = (v: unknown, def: number, min: number, max: number): number => { const x = Math.trunc(Number(v)); return Number.isFinite(x) && x >= min && x <= max ? x : def; };
  return { enabled: o["enabled"] !== false, freeAds: n(o["freeAds"], D.freeAds, 0, 100), freePeriods: n(o["freePeriods"], D.freePeriods, 1, 20), freeDays: n(o["freeDays"], D.freeDays, 1, 365) };
}

/** Une annonce du site compte parmi les gratuites de la personne, sauf si elle a été refusée. */
export const countsAsFree = (ad: { source?: unknown; freeOffer?: unknown; status?: unknown }): boolean =>
  ad.source === "web" && ad.freeOffer === true && String(ad.status ?? "") !== "rejected";

export type RenewalDecision = "ok" | "not_ended" | "not_renewable" | "payment_required";

/** Peut-on renouveler cette annonce gratuitement ? Seulement quand elle est terminée ; au-delà des périodes gratuites : paiement. */
export function renewalDecision(ad: { status?: unknown; endDate?: unknown; renewalCount?: unknown }, cfg: Pick<AdsWebConfig, "freePeriods">, nowMicros: number): RenewalDecision {
  if (String(ad.status ?? "") !== "active") return "not_renewable";
  if (Number(ad.endDate) > nowMicros) return "not_ended";
  const used = Math.max(0, Math.floor(Number(ad.renewalCount) || 0));
  return used >= cfg.freePeriods - 1 ? "payment_required" : "ok";
}

/** Palier de vues franchi (100, 200, 300…) et pas encore annoncé à l'annonceur : retourne le palier à annoncer, sinon null. */
export function viewMilestone(before: unknown, after: unknown, lastSent: unknown): number | null {
  const b = Math.max(0, Math.floor(Number(before) || 0));
  const a = Math.max(0, Math.floor(Number(after) || 0));
  const m = Math.floor(a / 100) * 100;
  if (m < 100 || Math.floor(b / 100) >= Math.floor(a / 100)) return null;
  return m > (Math.floor(Number(lastSent) || 0)) ? m : null;
}

// ─── Vues et clics sur la plateforme (site /ads/, puis SlashAtlas, Pronoflash, Épargne+) ──────────────────────────
/**
 * Mêmes compteurs que dans l'application (Advertisement.views / clicks / uniqueViews / uniqueClicks / dailyStats), mais enregistrés par le serveur.
 * Règle : au plus UNE vue et UN clic par visiteur, par annonce et par jour (les rechargements et les doubles clics ne comptent pas) ;
 * le visiteur est reconnu par un identifiant anonyme du navigateur combiné à une empreinte (hachée) de l'adresse IP.
 * Définitions : « vue » = l'annonce s'affiche à l'écran ; « clic » = le visiteur ouvre l'annonce ou appuie sur son bouton d'action.
 */
export type TrackType = "view" | "click";
export interface SeenState { viewed?: boolean; clicked?: boolean; lastViewDay?: string; lastClickDay?: string }

/** Faut-il compter cet évènement ? count : +1 vue/clic du jour ; unique : première vue/clic de ce visiteur pour cette annonce. */
export function trackDecision(seen: SeenState | undefined, type: TrackType, today: string): { count: boolean; unique: boolean } {
  const s = seen ?? {};
  const lastDay = type === "view" ? s.lastViewDay : s.lastClickDay;
  const already = type === "view" ? s.viewed === true : s.clicked === true;
  return { count: lastDay !== today, unique: !already };
}

/** Robots d'indexation et de prévisualisation : jamais comptés. */
export const isBot = (ua: unknown): boolean => /bot|crawl|spider|slurp|facebookexternalhit|preview|monitor|headless|lighthouse|curl|wget|python|axios|node-fetch/i.test(String(ua ?? ""));

export const MAX_TRACK_PER_IP_DAY = 400; // évènements comptés par adresse IP et par jour (réseaux partagés inclus)
export const validVisitorId = (v: unknown): boolean => /^[A-Za-z0-9-]{12,64}$/.test(String(v ?? ""));
export const validPlacement = (v: unknown): string => (/^[a-z0-9_]{2,20}$/.test(String(v ?? "")) ? String(v) : "site");
