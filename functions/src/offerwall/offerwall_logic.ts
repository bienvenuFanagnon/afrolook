import { createHash, createHmac, timingSafeEqual } from "crypto";

/**
 * Mur de tâches (Tapjoy, ayeT-Studios) : règles pures, sans accès à Firebase ni au réseau (testables telles quelles).
 * Voir docs/OFFERWALL_TACHES.md. Règles décidées par le propriétaire (27/10/2026) :
 *  - 25 pièces = 10 FCFA (1 pièce = 0,4 FCFA) ;
 *  - par tâche : 50 % de la valeur pour l'utilisateur (la régie envoie déjà ce montant en pièces, grâce au taux réglé dans son tableau de bord),
 *    10 % de la valeur pour le parrain = 20 % des pièces de l'utilisateur, pris sur la part du Studio ; le Studio garde le reste ;
 *  - les pièces sont TOUJOURS des nombres entiers (jamais de décimaux), arrondis par le bas.
 */

export interface OfferwallConfig {
  /** Interrupteur de l'écran « Tâches » dans l'application (les retours serveur sont toujours enregistrés : une conversion n'est jamais perdue). */
  enabled: boolean;
  /** Heures pendant lesquelles les pièces restent « en attente » avant d'être converties en Pièces gagnées. */
  holdHours: number;
  /** Ancienneté minimale du compte (jours) pour recevoir les pièces. */
  minAccountAgeDays: number;
  requireVerifiedEmail: boolean;
  /** Plafonds de pièces par utilisateur : au-delà, la tâche est mise « en revue » (pas refusée). */
  dailyCapCoins: number;
  weeklyCapCoins: number;
  /** Commission du parrain, en % des pièces de l'utilisateur (20 % = 10 % de la valeur de la tâche). */
  sponsorPct: number;
  /** Plus grand montant accepté pour un seul retour (garde-fou contre une valeur aberrante). */
  maxCoinsPerEvent: number;
  /** Jours après lesquels un événement en attente qui ne remplit toujours pas les conditions expire. */
  expireDays: number;
  /** Refuser les appels dont l'adresse n'est pas celle de Tapjoy (désactivé par défaut : la liste d'adresses évolue). */
  enforceIp: boolean;
  /** Interrupteurs par plateforme de l'écran « Tâches » (couper l'iPhone seul si Apple l'exige, sans toucher à Android). */
  androidEnabled: boolean;
  iosEnabled: boolean;
}

export const DEFAULT_OFFERWALL_CONFIG: OfferwallConfig = {
  enabled: true,
  holdHours: 48,
  minAccountAgeDays: 3,
  requireVerifiedEmail: true,
  dailyCapCoins: 2000,
  weeklyCapCoins: 10000,
  sponsorPct: 20,
  maxCoinsPerEvent: 100000,
  expireDays: 14,
  enforceIp: false,
  androidEnabled: true,
  iosEnabled: true,
};

/** Réglages (AppConfig/offerwall) avec valeurs de départ prudentes ; toute valeur hors bornes est ignorée. */
export function readOfferwallConfig(d: Record<string, unknown> | undefined): OfferwallConfig {
  const o = d ?? {};
  const D = DEFAULT_OFFERWALL_CONFIG;
  const n = (v: unknown, def: number, min: number, max: number): number => {
    const x = Math.trunc(Number(v));
    return Number.isFinite(x) && x >= min && x <= max ? x : def;
  };
  return {
    enabled: o["enabled"] !== false,
    holdHours: n(o["holdHours"], D.holdHours, 0, 24 * 30),
    minAccountAgeDays: n(o["minAccountAgeDays"], D.minAccountAgeDays, 0, 365),
    requireVerifiedEmail: o["requireVerifiedEmail"] !== false,
    dailyCapCoins: n(o["dailyCapCoins"], D.dailyCapCoins, 1, 10_000_000),
    weeklyCapCoins: n(o["weeklyCapCoins"], D.weeklyCapCoins, 1, 100_000_000),
    sponsorPct: n(o["sponsorPct"], D.sponsorPct, 0, 100),
    maxCoinsPerEvent: n(o["maxCoinsPerEvent"], D.maxCoinsPerEvent, 1, 100_000_000),
    expireDays: n(o["expireDays"], D.expireDays, 1, 365),
    enforceIp: o["enforceIp"] === true,
    androidEnabled: o["androidEnabled"] !== false,
    iosEnabled: o["iosEnabled"] !== false,
  };
}

/** Signature d'un retour serveur Tapjoy : MD5 de « id:snuid:currency:clé secrète » (spécification Tapjoy, monnaie auto-gérée). */
export const tapjoyVerifier = (id: string, snuid: string, currency: string, secret: string): string =>
  createHash("md5").update(`${id}:${snuid}:${currency}:${secret}`, "utf8").digest("hex");

/** Comparaison en temps constant de deux signatures hexadécimales. */
export function safeEqualHex(a: string, b: string): boolean {
  const x = Buffer.from(String(a ?? ""), "utf8");
  const y = Buffer.from(String(b ?? ""), "utf8");
  return x.length === y.length && x.length > 0 && timingSafeEqual(x, y);
}

export type ParsedCoins = { ok: true; coins: number } | { ok: false; reason: string };

/**
 * Montant de pièces reçu d'une régie → ENTIER strictement positif, arrondi par le bas.
 * Refuse : vide, négatif, non numérique, notation scientifique, nul après arrondi, supérieur au maximum.
 */
export function parseCoins(raw: unknown, max: number): ParsedCoins {
  const s = String(raw ?? "").trim();
  if (!/^\d{1,12}(\.\d{1,6})?$/.test(s)) return { ok: false, reason: "montant invalide" };
  const n = Math.floor(Number(s));
  if (!Number.isSafeInteger(n) || n <= 0) return { ok: false, reason: "montant nul" };
  if (n > max) return { ok: false, reason: "montant trop élevé" };
  return { ok: true, coins: n };
}

export interface Split { user: number; sponsor: number; studio: number }

/**
 * Répartition d'une tâche à partir des pièces de l'utilisateur (entières) :
 * parrain = ⌊pièces × % / 100⌋ (0 sans parrain), Studio = le reste de ce que la tâche rapporte, exprimé en pièces
 * (valeur totale = 2 × pièces de l'utilisateur : 50 % utilisateur ; Studio = pièces − parrain, soit 40 % avec parrain et 50 % sans).
 */
export function splitCoins(userCoins: number, sponsorPct: number, hasSponsor: boolean): Split {
  const user = Math.floor(userCoins);
  const sponsor = hasSponsor ? Math.floor((user * sponsorPct) / 100) : 0;
  return { user, sponsor, studio: user - sponsor };
}

/** « ok » si la tâche tient dans les plafonds du jour et de la semaine (pièces déjà reçues + cette tâche) ; « revue » sinon (jamais de refus sec). */
export function capDecision(todayCoins: number, weekCoins: number, coins: number, cfg: Pick<OfferwallConfig, "dailyCapCoins" | "weeklyCapCoins">): "ok" | "revue" {
  return todayCoins + coins > cfg.dailyCapCoins || weekCoins + coins > cfg.weeklyCapCoins ? "revue" : "ok";
}

const DAY = 86_400_000;
export const dayOf = (ms: number): string => new Date(ms).toISOString().slice(0, 10);
/** Les 7 derniers jours (aujourd'hui inclus), du plus récent au plus ancien. */
export const lastSevenDays = (ms: number): string[] => Array.from({ length: 7 }, (_, i) => dayOf(ms - i * DAY));

export interface UserFacts { exists: boolean; deleted: boolean; pendingDeletion: boolean; createdAt: number; emailVerified: boolean; blockedFromOffers: boolean }

/** Le compte peut-il recevoir des pièces maintenant ? Retourne la raison du blocage, ou null. */
export function blockReason(u: UserFacts, cfg: Pick<OfferwallConfig, "minAccountAgeDays" | "requireVerifiedEmail">, nowMs: number): string | null {
  if (!u.exists) return "compte inconnu";
  if (u.deleted || u.pendingDeletion) return "compte en cours de suppression";
  if (u.blockedFromOffers) return "compte suspendu des tâches";
  if (cfg.minAccountAgeDays > 0 && (!u.createdAt || nowMs - u.createdAt < cfg.minAccountAgeDays * DAY)) return "compte trop récent";
  if (cfg.requireVerifiedEmail && !u.emailVerified) return "e-mail non vérifié";
  return null;
}

/** Identifiant stable d'un événement (un retour serveur = un document, donc jamais de double crédit). */
export const eventId = (provider: string, requestId: string): string =>
  `${provider}_${createHash("sha256").update(String(requestId), "utf8").digest("hex").slice(0, 40)}`;

// ─── ayeT-Studios ────────────────────────────────────────────────────────────────────────────

/** Pièces par dollar de revenu éditeur (réglé à 750 dans le tableau de bord d'ayeT et de Tapjoy : 0,50 × 600 FCFA ÷ 0,4 FCFA). */
export const COINS_PER_USD = 750;

/**
 * Le montant en pièces envoyé par ayeT est-il cohérent avec le paiement en dollars qu'il envoie aussi ?
 * Tolérance : 5 % + 1 pièce (arrondis). Sans paiement valide, on ne peut pas juger : cohérent.
 */
export function ayetAmountsCoherent(coins: number, payoutUsd: unknown): boolean {
  const s = String(payoutUsd ?? "").trim();
  if (!/^\d{1,9}(\.\d{1,8})?$/.test(s)) return true;
  const expected = Math.floor(Number(s) * COINS_PER_USD);
  return coins <= Math.ceil(expected * 1.05) + 1;
}

const phpUrlencode = (v: string): string =>
  encodeURIComponent(v).replace(/[!'()*~]/g, (c) => "%" + c.charCodeAt(0).toString(16).toUpperCase()).replace(/%20/g, "+");

/**
 * Chaînes possibles que signe ayeT : « paramètres triés par ordre alphabétique » (leur documentation ne précise pas le format exact).
 * On teste plusieurs écritures ; la première qui correspond est reconnue (son numéro est journalisé pour figer le format après le premier test réel).
 */
export function ayetSignedStrings(params: Record<string, string>): string[] {
  const keys = Object.keys(params).sort();
  const nonEmpty = keys.filter((k) => params[k] !== "");
  const join = (ks: string[], enc: (v: string) => string, sep: string, withKey = true): string =>
    ks.map((k) => (withKey ? `${k}=${enc(params[k])}` : enc(params[k]))).join(sep);
  const id = (v: string): string => v;
  return [
    join(keys, id, "&"),
    join(keys, encodeURIComponent, "&"),
    join(keys, phpUrlencode, "&"),
    join(nonEmpty, id, "&"),
    join(nonEmpty, encodeURIComponent, "&"),
    join(nonEmpty, phpUrlencode, "&"),
    join(keys, id, ""),
    join(keys, id, "", false),
    join(nonEmpty, id, ""),
    join(nonEmpty, id, "", false),
  ];
}

/** Vérifie l'en-tête X-Ayetstudios-Security-Hash (HMAC-SHA256 avec la clé d'API éditeur). Retourne le numéro de l'écriture reconnue, ou -1. */
export function ayetVerify(params: Record<string, string>, headerHash: string, apiKey: string): number {
  const h = String(headerHash ?? "").trim();
  if (!h || !apiKey) return -1;
  const strings = ayetSignedStrings(params);
  for (let i = 0; i < strings.length; i++) {
    const mac = createHmac("sha256", apiKey).update(strings[i], "utf8");
    const raw = mac.digest();
    if (safeEqualHex(h.toLowerCase(), raw.toString("hex")) || safeEqualHex(h, raw.toString("base64"))) return i;
  }
  return -1;
}

// ─── Pubscale ────────────────────────────────────────────────────────────────────────────────

/**
 * Signature d'un retour serveur Pubscale (conversion ou annulation) : MD5 de « clé_secrète.user_id.valeur_entière.token »,
 * la valeur décimale étant tronquée à l'entier (spécification Pubscale, « Optional Parameters for fraud detection »).
 */
export const pubscaleSignature = (secret: string, userId: string, value: string, token: string): string => {
  const n = Math.trunc(Number(value));
  return createHash("md5").update(`${secret}.${userId}.${Number.isFinite(n) ? n : 0}.${token}`, "utf8").digest("hex");
};

// ─── Annulation après validation et dettes ───────────────────────────────────────────────────

/** Reprise de `amount` pièces sur un solde de pièces gagnées : ce qui peut être repris, et le manque (qui devient une dette). */
export function takeBack(balance: number, amount: number): { taken: number; debt: number } {
  const bal = Math.max(0, Math.floor(Number(balance) || 0));
  const a = Math.max(0, Math.floor(Number(amount) || 0));
  const taken = Math.min(bal, a);
  return { taken, debt: a - taken };
}

/** Un gain de `coins` pièces rembourse d'abord la dette : pièces affectées à la dette, et pièces réellement créditées. */
export function repayDebt(debt: number, coins: number): { repaid: number; credited: number } {
  const d = Math.max(0, Math.floor(Number(debt) || 0));
  const c = Math.max(0, Math.floor(Number(coins) || 0));
  const repaid = Math.min(d, c);
  return { repaid, credited: c - repaid };
}
