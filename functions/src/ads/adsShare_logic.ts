import { randomBytes } from "crypto";

/**
 * « Partage et gagne » : logique pure (sans base de données), entièrement testée. Voir docs/PARTAGE_WHATSAPP_ADS.md.
 * Un utilisateur partage une annonce sur son statut WhatsApp ou dans un groupe avec SON lien personnel suivi ; chaque clic VALIDE est payé en pièces
 * (les vues d'un statut ne sont mesurables par personne : on paie au clic seulement).
 */

export const COINS_PER_FCFA = 2.5; // 25 pièces = 10 F, comme partout dans l'application
/** Le lien suivi marche partout : on retient où il est partagé (statistiques, et plateforme affichée dans l'historique des gains). */
export const CHANNELS = ["whatsapp_status", "whatsapp_group", "telegram_group", "telegram_channel", "facebook", "tiktok", "other"] as const;
export type Channel = (typeof CHANNELS)[number];
/** Plateforme d'un canal : whatsapp, telegram, facebook, tiktok ou other. */
export const platformOf = (c: Channel): string => c.split("_")[0];
export const PLATFORM_LABEL: Record<string, string> = { whatsapp: "WhatsApp", telegram: "Telegram", facebook: "Facebook", tiktok: "TikTok", other: "Autre plateforme" };
export const validChannel = (v: unknown): Channel | null => (CHANNELS as readonly string[]).includes(String(v)) ? (v as Channel) : null;

export interface ShareConfig {
  /** Interrupteur général (coupé par défaut : rien n'est proposé tant que l'administration ne l'active pas). */
  enabled: boolean;
  /** Gain de l'utilisateur par clic valide, en FCFA (pilote : 5 F = 12,5 pièces). */
  perClickFcfa: number;
  /** Plafond de gains par utilisateur et par jour, en FCFA. */
  dailyCapFcfa: number;
  /** Heures de retenue avant que les gains deviennent des pièces. */
  holdHours: number;
  /** Liens créés par utilisateur et par jour. */
  maxLinksPerDay: number;
  /** Clics valides payés par lien et par jour. */
  maxValidPerLinkPerDay: number;
  /** Budget total payé par annonce, en FCFA (arrêt automatique). */
  budgetFcfaPerAd: number;
  /** Durée minimale de la page intermédiaire avant le clic (prouve un vrai navigateur), en ms. */
  minVisitMs: number;
  /** Annonces proposées au partage (identifiants Advertisements). */
  adIds: string[];
}
export const DEFAULT_SHARE_CONFIG: ShareConfig = { enabled: false, perClickFcfa: 5, dailyCapFcfa: 500, holdHours: 72, maxLinksPerDay: 10, maxValidPerLinkPerDay: 100, budgetFcfaPerAd: 20000, minVisitMs: 700, adIds: [] };

export function readShareConfig(d: Record<string, unknown> | undefined): ShareConfig {
  const o = d ?? {}, D = DEFAULT_SHARE_CONFIG;
  const num = (v: unknown, def: number, min: number, max: number): number => { const x = Number(v); return Number.isFinite(x) && x >= min && x <= max ? x : def; };
  return {
    enabled: o["enabled"] === true,
    perClickFcfa: num(o["perClickFcfa"], D.perClickFcfa, 0.5, 200),
    dailyCapFcfa: num(o["dailyCapFcfa"], D.dailyCapFcfa, 1, 100000),
    holdHours: Math.trunc(num(o["holdHours"], D.holdHours, 0, 720)),
    maxLinksPerDay: Math.trunc(num(o["maxLinksPerDay"], D.maxLinksPerDay, 1, 100)),
    maxValidPerLinkPerDay: Math.trunc(num(o["maxValidPerLinkPerDay"], D.maxValidPerLinkPerDay, 1, 10000)),
    budgetFcfaPerAd: num(o["budgetFcfaPerAd"], D.budgetFcfaPerAd, 0, 100_000_000),
    minVisitMs: Math.trunc(num(o["minVisitMs"], D.minVisitMs, 200, 5000)),
    adIds: (Array.isArray(o["adIds"]) ? (o["adIds"] as unknown[]) : []).map((x) => String(x)).filter((x) => /^[A-Za-z0-9_-]{6,64}$/.test(x)).slice(0, 30),
  };
}

/** Valeur d'un clic en centièmes de pièce (5 F → 12,5 pièces → 1 250). */
export const hundredthsFor = (fcfa: number): number => Math.max(0, Math.round(fcfa * COINS_PER_FCFA * 100));

/** Code court du lien personnel : 8 caractères (lettres, chiffres, - et _). */
export const newCode = (): string => randomBytes(6).toString("base64url").slice(0, 8);
export const validCode = (v: unknown): v is string => typeof v === "string" && /^[A-Za-z0-9_-]{8}$/.test(v);

/** Robots et aperçus de lien (WhatsApp lit le lien quand on l'envoie : ce n'est jamais un clic d'une personne). */
const PREVIEW_RE = /whatsapp|telegrambot|twitterbot|slackbot|linkedinbot|skypeuripreview|facebookexternalhit|facebot|discordbot|googlebot|bingbot|bot\b|crawl|spider|preview|headless|curl|wget|python|node-fetch|axios|okhttp\/[0-9.]+ \(bot/i;
export const isPreviewAgent = (ua: unknown): boolean => { const s = String(ua ?? ""); return s.length < 8 || PREVIEW_RE.test(s); };

export type ClickReason = "bot" | "inactive" | "too_fast" | "stale" | "self" | "dup" | "geo" | "link_cap" | "user_cap" | "budget";
export interface ClickInput {
  bot: boolean;
  /** durée entre l'envoi de la page intermédiaire et le retour du navigateur (prouve que le JavaScript s'exécute) */
  visitMs: number;
  /** campagne et lien actifs */
  active: boolean;
  /** même empreinte d'adresse IP que la création du lien (même jour), ou clic dans les secondes qui suivent la création */
  sameIpAsCreator: boolean;
  sinceCreationMs: number;
  /** premier clic payé de ce visiteur pour cette annonce aujourd'hui */
  firstForVisitor: boolean;
  /** pays du visiteur compatible avec la campagne */
  countryOk: boolean;
  linkValidToday: number;
  userEarnedTodayFcfa: number;
  /** gain du partageur pour CE clic, coût du clic pour l'annonceur, dépense déjà faite et budget de la campagne (0 = sans limite) */
  userPayFcfa: number;
  costFcfa: number;
  spentFcfa: number;
  budgetFcfa: number;
}
export function shareClickDecision(i: ClickInput, cfg: ShareConfig): { valid: true } | { valid: false; reason: ClickReason } {
  if (i.bot) return { valid: false, reason: "bot" };
  if (!i.active) return { valid: false, reason: "inactive" };
  if (i.visitMs < cfg.minVisitMs) return { valid: false, reason: "too_fast" };
  if (i.visitMs > 120_000) return { valid: false, reason: "stale" };
  if (i.sameIpAsCreator || i.sinceCreationMs < 10_000) return { valid: false, reason: "self" };
  if (!i.firstForVisitor) return { valid: false, reason: "dup" };
  if (!i.countryOk) return { valid: false, reason: "geo" };
  if (i.linkValidToday >= cfg.maxValidPerLinkPerDay) return { valid: false, reason: "link_cap" };
  if (i.userEarnedTodayFcfa + i.userPayFcfa > cfg.dailyCapFcfa + 1e-9) return { valid: false, reason: "user_cap" };
  if (i.budgetFcfa > 0 && i.spentFcfa + i.costFcfa > i.budgetFcfa + 1e-9) return { valid: false, reason: "budget" };
  return { valid: true };
}

/** Moment (ms) où les gains d'un jour (AAAA-MM-JJ, UTC) deviennent des pièces : fin du jour + retenue. */
export const releaseAtFor = (day: string, holdHours: number): number => Date.parse(`${day}T00:00:00Z`) + 86_400_000 + holdHours * 3_600_000;

/** Ajoute des centièmes à la réserve de l'utilisateur : pièces entières à créditer et reste à garder (même principe que la tâche « Regarder une pub »). */
export function addHundredths(carry: number, add: number): { coins: number; carry: number } {
  const total = Math.max(0, Math.floor(Number(carry) || 0)) + Math.max(0, Math.floor(Number(add) || 0));
  return { coins: Math.floor(total / 100), carry: total % 100 };
}

/** Légende proposée avec le visuel (la mention « Pub » n'est pas retirable : elle fait partie du texte construit ici). */
export function captionFor(title: string, text: string, url: string, lang: "fr" | "en"): string {
  const clip = (s: string, n: number): string => { const t = s.replace(/\s+/g, " ").trim(); return t.length > n ? `${t.slice(0, n - 1).trim()}…` : t; };
  const mark = lang === "fr" ? "Pub" : "Ad";
  return `${clip(title, 90)}\n${clip(text, 140)}\n👉 ${url}\n(${mark})`;
}
