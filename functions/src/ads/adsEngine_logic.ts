/**
 * Afrolook Ads : moteur unique (étape 1). Logique pure, sans base de données ni réseau (testée dans __tests__/adsEngine.test.ts).
 *
 * Principe : on ne croit jamais ce que dit le site ou l'application qui affiche l'annonce. Chaque annonce servie porte un JETON SIGNÉ (HMAC) :
 *  - une vue n'est comptée que si le jeton est valide, récent, jamais utilisé, et si l'annonce est restée visible assez longtemps ;
 *  - un clic passe par notre redirection (adsGo) et exige le même jeton ; la destination ne se trouve jamais chez le diffuseur ;
 *  - tout le reste est « invalide » : ni facturé à l'annonceur, ni payé au diffuseur.
 */
import { createHash, createHmac, randomBytes, timingSafeEqual } from "crypto";

// ─── Formats ────────────────────────────────────────────────────────────────────────────────────────────────────────

export type FormatId = "banner" | "sticky" | "native" | "carousel" | "video" | "poster" | "interstitial" | "rewarded" | "notification";
export interface FormatDef {
  id: FormatId;
  label: string;
  /** Prix annonceur, F CFA pour 1 000 affichages valides (1 000 vues complètes pour la récompensée). Réglable dans AppConfig/adsEngine. */
  cpm: number;
  /** Durée minimale d'affichage à l'écran (au moins à moitié visible) pour qu'une vue soit valide. */
  viewMs: number;
  /** Intervalle minimum entre deux affichages sur le même emplacement et pour le même appareil. */
  minIntervalMs: number;
  /** Création attendue : image(s), vidéo ≤ 15 s. */
  media: "image" | "video" | "any";
  /** Les formats « récompensée » et « vidéo » comptent aussi une lecture complète. */
  complete: boolean;
}
export const FORMATS: Record<FormatId, FormatDef> = {
  banner: { id: "banner", label: "Bannière", cpm: 1000, viewMs: 1000, minIntervalMs: 30_000, media: "image", complete: false },
  sticky: { id: "sticky", label: "Bandeau collant", cpm: 1250, viewMs: 1000, minIntervalMs: 30_000, media: "image", complete: false },
  native: { id: "native", label: "Carte native", cpm: 1500, viewMs: 1000, minIntervalMs: 20_000, media: "any", complete: false },
  carousel: { id: "carousel", label: "Carrousel", cpm: 1800, viewMs: 1000, minIntervalMs: 20_000, media: "image", complete: false },
  poster: { id: "poster", label: "Affiche", cpm: 2000, viewMs: 1000, minIntervalMs: 20_000, media: "image", complete: false },
  video: { id: "video", label: "Vidéo dans le fil", cpm: 2500, viewMs: 2000, minIntervalMs: 20_000, media: "video", complete: true },
  interstitial: { id: "interstitial", label: "Interstitiel", cpm: 3000, viewMs: 1000, minIntervalMs: 600_000, media: "any", complete: false },
  rewarded: { id: "rewarded", label: "Récompensée", cpm: 3500, viewMs: 1000, minIntervalMs: 300_000, media: "video", complete: true },
  notification: { id: "notification", label: "Notification", cpm: 0, viewMs: 0, minIntervalMs: 0, media: "image", complete: false },
};
export const validFormat = (v: unknown): FormatId | null => (typeof v === "string" && Object.prototype.hasOwnProperty.call(FORMATS, v) ? (v as FormatId) : null);

/** Une annonce (image ou vidéo) convient-elle à un format ? Le carrousel exige 2 images au moins ; vidéo et récompensée exigent une vidéo. */
export function adFitsFormat(ad: { video: boolean; images: number }, fmt: FormatId): boolean {
  const def = FORMATS[fmt];
  if (def.cpm <= 0) return false; // notification : pas encore ouverte
  if (def.media === "video") return ad.video;
  if (def.media === "image") return !ad.video && ad.images >= (fmt === "carousel" ? 2 : 1);
  return true;
}

// ─── Diffuseurs ─────────────────────────────────────────────────────────────────────────────────────────────────────

export interface Publisher { id: string; kind: "internal" | "external"; name: string; status: "active" | "suspended" }
/** Nos propres plateformes : premiers « diffuseurs » du moteur. Les diffuseurs externes (collection AdPublishers) viendront avec l'étape 4. */
export const INTERNAL_PUBLISHERS: Record<string, Publisher> = {
  afrolook: { id: "afrolook", kind: "internal", name: "Application Afrolook", status: "active" },
  site: { id: "site", kind: "internal", name: "afrolookmedia.com", status: "active" },
  slashatlas: { id: "slashatlas", kind: "internal", name: "SlashAtlas", status: "active" },
  pronoflash: { id: "pronoflash", kind: "internal", name: "PronoFlash IA", status: "active" },
  epargneplus: { id: "epargneplus", kind: "internal", name: "Épargne+", status: "active" },
};
export const validPubId = (v: unknown): string | null => (typeof v === "string" && /^[a-z0-9_]{2,24}$/.test(v) ? v : null);
export const validSlot = (v: unknown): string => (typeof v === "string" && /^[a-z0-9_-]{1,32}$/.test(v) ? v : "main");
export const validVid = (v: unknown): boolean => /^[A-Za-z0-9-]{12,64}$/.test(String(v ?? ""));

// ─── Jeton signé ────────────────────────────────────────────────────────────────────────────────────────────────────

export interface TokenPayload {
  /** version */ v: 1;
  /** annonce */ a: string;
  /** diffuseur */ p: string;
  /** emplacement */ s: string;
  /** format */ f: FormatId;
  /** émis à (ms) */ t: number;
  /** numéro unique (usage unique) */ n: string;
  /** ciblage à la diffusion : i = dans les pays visés, o = hors cible, u = pays inconnu, a = annonce sans contrainte de pays */ g?: "i" | "o" | "u" | "a";
  /** pays du visiteur (2 lettres), déterminé par le serveur à partir de l'adresse IP */ c?: string;
}
export const TOKEN_TTL_VIEW_MS = 30 * 60_000;
export const TOKEN_TTL_CLICK_MS = 2 * 3600_000;
const b64 = (b: Buffer): string => b.toString("base64url");

export function newNonce(): string { return randomBytes(9).toString("base64url"); } // 12 caractères

export function signToken(p: TokenPayload, key: string): string {
  const body = b64(Buffer.from(JSON.stringify(p)));
  const sig = b64(createHmac("sha256", key).update(body).digest());
  return `${body}.${sig}`;
}

export function verifyToken(token: unknown, key: string): TokenPayload | null {
  if (typeof token !== "string" || token.length > 600) return null;
  const i = token.indexOf(".");
  if (i < 1 || token.indexOf(".", i + 1) !== -1) return null;
  const body = token.slice(0, i), sig = token.slice(i + 1);
  const expect = b64(createHmac("sha256", key).update(body).digest());
  const a = Buffer.from(sig), e = Buffer.from(expect);
  if (a.length !== e.length || !timingSafeEqual(a, e)) return null;
  try {
    const p = JSON.parse(Buffer.from(body, "base64url").toString("utf8")) as TokenPayload;
    if (p?.v !== 1 || typeof p.a !== "string" || typeof p.p !== "string" || typeof p.s !== "string" || !validFormat(p.f) || typeof p.t !== "number" || typeof p.n !== "string") return null;
    if (!/^[A-Za-z0-9]{10,40}$/.test(p.a) || !/^[A-Za-z0-9_-]{6,20}$/.test(p.n)) return null;
    if (p.g !== undefined && !["i", "o", "u", "a"].includes(p.g)) return null;
    if (p.c !== undefined && !/^[A-Z]{2}$/.test(p.c)) return null;
    return p;
  } catch { return null; }
}

// ─── Empreintes (confidentialité) ───────────────────────────────────────────────────────────────────────────────────

/** Empreinte de l'adresse IP avec un sel qui change chaque jour : impossible de suivre une personne d'un jour à l'autre. */
export const ipHash = (ip: string, day: string, key: string): string => createHash("sha256").update(`ip:${day}:${key}:${ip}`).digest("hex").slice(0, 20);
/** Identifiant du visiteur, propre à chaque diffuseur : deux sites ne peuvent pas recouper un même visiteur. */
export const visitorHash = (vid: string, pub: string, key: string): string => createHash("sha256").update(`vid:${pub}:${key}:${vid}`).digest("hex").slice(0, 24);

// ─── Robots ─────────────────────────────────────────────────────────────────────────────────────────────────────────

const BOT_RE = /bot|crawl|spider|slurp|facebookexternalhit|preview|monitor|headless|lighthouse|curl|wget|python|axios|node-fetch|httpclient|okhttp\/[0-9.]+ \(bot|phantom|puppeteer|playwright|selenium|scrapy|go-http-client|java\//i;
export const isBotAgent = (ua: unknown): boolean => { const s = String(ua ?? ""); return s.length < 8 || BOT_RE.test(s); };

// ─── Décisions ──────────────────────────────────────────────────────────────────────────────────────────────────────

export type Invalid = "bot" | "token" | "expired" | "replay" | "too_fast" | "not_visible" | "interval" | "ad_cap" | "device_cap" | "ip_cap" | "ad_inactive" | "dup_click" | "no_view";

export const MAX_VIEWS_PER_AD_DEVICE_DAY = 3;
export const MAX_IMPRESSIONS_PER_DEVICE_DAY = 300;
export const MAX_EVENTS_PER_IP_DAY = 2000;
export const MIN_CLICK_DELAY_MS = 1000;

export interface DeviceDay { total?: number; slotLast?: Record<string, number>; adViews?: Record<string, number> }

/** Une vue est-elle valide ? visibleMs = durée d'affichage annoncée par le composant de mesure ; le serveur la recoupe avec l'heure d'émission du jeton. */
export function viewDecision(p: TokenPayload, now: number, visibleMs: number, dev: DeviceDay | undefined, ipEvents: number, replay: boolean): { valid: boolean; reason?: Invalid } {
  const def = FORMATS[p.f];
  const age = now - p.t;
  if (replay) return { valid: false, reason: "replay" };
  if (age < 0 || age > TOKEN_TTL_VIEW_MS) return { valid: false, reason: "expired" };
  const vis = Math.max(0, Math.floor(Number(visibleMs) || 0));
  if (vis < def.viewMs) return { valid: false, reason: "not_visible" };
  if (vis > age + 1500) return { valid: false, reason: "too_fast" }; // il ne peut pas avoir été visible plus longtemps que l'annonce n'existe
  if (ipEvents >= MAX_EVENTS_PER_IP_DAY) return { valid: false, reason: "ip_cap" };
  const d = dev ?? {};
  if ((d.total ?? 0) >= MAX_IMPRESSIONS_PER_DEVICE_DAY) return { valid: false, reason: "device_cap" };
  const last = d.slotLast?.[p.s];
  if (last != null && now - last < def.minIntervalMs) return { valid: false, reason: "interval" };
  if ((d.adViews?.[p.a] ?? 0) >= MAX_VIEWS_PER_AD_DEVICE_DAY) return { valid: false, reason: "ad_cap" };
  return { valid: true };
}

/** Un clic est-il valide ? (au plus un par jeton, un délai minimum après l'émission, un clic par visiteur, annonce et jour). */
export function clickDecision(p: TokenPayload, now: number, alreadyClickedToken: boolean, alreadyClickedToday: boolean, ipEvents: number): { valid: boolean; reason?: Invalid } {
  const age = now - p.t;
  if (alreadyClickedToken) return { valid: false, reason: "dup_click" };
  if (age < 0 || age > TOKEN_TTL_CLICK_MS) return { valid: false, reason: "expired" };
  if (age < MIN_CLICK_DELAY_MS) return { valid: false, reason: "too_fast" };
  if (ipEvents >= MAX_EVENTS_PER_IP_DAY) return { valid: false, reason: "ip_cap" };
  if (alreadyClickedToday) return { valid: false, reason: "dup_click" };
  return { valid: true };
}

/** Lecture complète (vidéo, récompensée) : après une vue valide du même jeton, et seulement une fois. */
export function completeDecision(p: TokenPayload, now: number, viewed: boolean, alreadyCompleted: boolean, minPlayMs: number): { valid: boolean; reason?: Invalid } {
  if (!viewed) return { valid: false, reason: "no_view" };
  if (alreadyCompleted) return { valid: false, reason: "replay" };
  if (now - p.t < Math.max(0, minPlayMs)) return { valid: false, reason: "too_fast" };
  return { valid: true };
}

// ─── Santé d'un diffuseur ───────────────────────────────────────────────────────────────────────────────────────────

export type Health = "ok" | "alert" | "suspend";
/** Barème : moins de 10 % de trafic invalide = normal ; 10 à 25 % = alerte ; plus de 25 % = emplacement suspendu. Trop peu d'évènements : pas de décision. */
export function publisherHealth(valid: number, invalid: number): { rate: number; status: Health } {
  const total = Math.max(0, valid) + Math.max(0, invalid);
  if (total < 200) return { rate: total ? invalid / total : 0, status: "ok" };
  const rate = invalid / total;
  return { rate, status: rate > 0.25 ? "suspend" : rate >= 0.1 ? "alert" : "ok" };
}

/** Taux de clic anormal (plus de 8 % avec assez de vues) : signe de clics automatiques ou incités. */
export const ctrSuspicious = (views: number, clicks: number): boolean => views >= 500 && clicks / views > 0.08;

// ─── Compteurs répartis ─────────────────────────────────────────────────────────────────────────────────────────────

export const SHARDS = 8;
export const shardOf = (nonce: string): number => { let h = 0; for (let i = 0; i < nonce.length; i++) h = (h * 31 + nonce.charCodeAt(i)) >>> 0; return h % SHARDS; };
export const shardId = (adId: string, day: string, pub: string, shard: number): string => `${adId}_${day}_${pub}_${shard}`;

/** Choix d'une annonce parmi celles qui conviennent : au hasard, en évitant celles que cet appareil a déjà vues le plus souvent aujourd'hui. */
export function pickAd<T extends { id: string }>(cands: T[], dev: DeviceDay | undefined, rnd: number): T | null {
  if (!cands.length) return null;
  const seen = (id: string) => dev?.adViews?.[id] ?? 0;
  const min = Math.min(...cands.map((c) => seen(c.id)));
  const pool = cands.filter((c) => seen(c.id) === min && seen(c.id) < MAX_VIEWS_PER_AD_DEVICE_DAY);
  if (!pool.length) return null;
  return pool[Math.floor(Math.max(0, Math.min(0.999999, rnd)) * pool.length)];
}
