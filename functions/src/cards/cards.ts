import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { recordAppCommission } from "../payments/coinShares";

/**
 * Studio Cartes : un post devient une carte Afrolook (image) à partager ou à publier.
 * Le serveur décide de tout (quotas du mois, prix, pass) ; l'application fabrique l'image.
 *
 * Deux usages comptés :
 * - « capture » : l'image sort de l'application (enregistrer, partager) ;
 * - « publication » : la carte est publiée dans Afrolook (post ou Chronique). Elle coûte moins cher :
 *   le contenu reste chez nous.
 *
 * Qui paie quoi, dans l'ordre : admin (jamais) → pass Studio actif → quota mensuel du plan payant
 * (Premium : 2 captures + 3 publications ; Gold : 5 captures + 20 publications) → carte d'essai (une seule fois)
 * → crédit gagné avec une pub (captures seulement) → pièces. Un style Pro coûte des pièces en plus (réduit pour Gold),
 * sauf avec le pass. Le Premium obtenu avec des pubs ne donne pas de quota.
 *
 * Réglages (AppConfig/cards, relus toutes les 60 s) : enabled, priceCapture, pricePublish, priceProStyle,
 * priceProStyleGold, passPrice, passDays, trialCards, quotas.{free,premium,gold}.{captures,publishes} (gratuit : 1 capture / 0 publication par mois), proStyles[].
 */

const DAY = 86400000;
const num = (v: unknown, def: number) => (typeof v === "number" && Number.isFinite(v) ? v : def);

export type CardKind = "capture" | "publish";
type Plan = "free" | "premium" | "gold";

interface CardsConfig {
  enabled: boolean;
  priceCapture: number;
  pricePublish: number;
  priceProStyle: number;
  priceProStyleGold: number;
  passPrice: number;
  passDays: number;
  trialCards: number;
  quotas: Record<Plan, { captures: number; publishes: number }>;
  proStyles: string[];
}

let cache: { at: number; cfg: CardsConfig } | null = null;
export async function loadCardsConfig(): Promise<CardsConfig> {
  if (cache && Date.now() - cache.at < 60000) return cache.cfg;
  const d = (await db.collection("AppConfig").doc("cards").get()).data() ?? {};
  const q = (d["quotas"] ?? {}) as Record<string, Record<string, unknown> | undefined>;
  const quota = (p: string, k: string, def: number) => Math.max(0, Math.round(num(q[p]?.[k], def)));
  const cfg: CardsConfig = {
    enabled: d["enabled"] !== false,
    priceCapture: Math.max(0, Math.round(num(d["priceCapture"], 25))),
    pricePublish: Math.max(0, Math.round(num(d["pricePublish"], 10))),
    priceProStyle: Math.max(0, Math.round(num(d["priceProStyle"], 20))),
    priceProStyleGold: Math.max(0, Math.round(num(d["priceProStyleGold"], 10))),
    passPrice: Math.max(1, Math.round(num(d["passPrice"], 400))),
    passDays: Math.max(1, Math.min(90, Math.round(num(d["passDays"], 30)))),
    trialCards: Math.max(0, Math.round(num(d["trialCards"], 0))),
    quotas: {
      free: { captures: quota("free", "captures", 1), publishes: quota("free", "publishes", 0) },
      premium: { captures: quota("premium", "captures", 2), publishes: quota("premium", "publishes", 3) },
      gold: { captures: quota("gold", "captures", 5), publishes: quota("gold", "publishes", 20) },
    },
    proStyles: Array.isArray(d["proStyles"]) ? (d["proStyles"] as unknown[]).map(String) : ["bogolan"],
  };
  cache = { at: Date.now(), cfg };
  return cfg;
}

/** Plan payant actif : le Premium obtenu en regardant des pubs ne compte pas (il n'ouvre aucun quota). */
export function planOf(u: FirebaseFirestore.DocumentData, now: number): Plan {
  const ab = (u["abonnement"] ?? {}) as { type?: string; dateFin?: string; estActif?: boolean; methodePaiement?: string };
  const end = ab.dateFin ? Date.parse(ab.dateFin) : NaN;
  const active = ab.estActif !== false && Number.isFinite(end) && end > now && ab.methodePaiement !== "pubs";
  if (active && ab.type === "gold") return "gold";
  if (active && ab.type === "premium") return "premium";
  return "free";
}

export const monthKey = (now: number) => new Date(now).toISOString().slice(0, 7).replace("-", "");
const usageRef = (uid: string, now: number) => db.collection("CardUsage").doc(`${uid}_${monthKey(now)}`);

export type Via = "admin" | "pass" | "quota" | "trial" | "ad" | "coins";
export interface Cost { via: Via; coins: number }

interface State {
  isAdmin: boolean;
  plan: Plan;
  passActive: boolean;
  trialLeft: number;
  adCredits: number;
  used: { captures: number; publishes: number };
  balance: number;
}

/** Ce que coûte une carte, dans l'ordre de priorité décrit plus haut. Fonction pure : sert au devis ET au débit. */
export function costOf(kind: CardKind, pro: boolean, s: State, cfg: CardsConfig): Cost {
  if (s.isAdmin) return { via: "admin", coins: 0 };
  if (s.passActive) return { via: "pass", coins: 0 };
  const proCoins = pro ? (s.plan === "gold" ? cfg.priceProStyleGold : cfg.priceProStyle) : 0;
  const limit = kind === "capture" ? cfg.quotas[s.plan].captures : cfg.quotas[s.plan].publishes;
  const used = kind === "capture" ? s.used.captures : s.used.publishes;
  if (used < limit) return { via: "quota", coins: proCoins };
  if (s.trialLeft > 0) return { via: "trial", coins: proCoins };
  if (kind === "capture" && s.adCredits > 0) return { via: "ad", coins: proCoins };
  return { via: "coins", coins: (kind === "capture" ? cfg.priceCapture : cfg.pricePublish) + proCoins };
}

function stateFrom(u: FirebaseFirestore.DocumentData, usage: FirebaseFirestore.DocumentData | undefined, cfg: CardsConfig, now: number): State {
  const trialUsed = num(u["cardTrialUsed"], 0);
  return {
    isAdmin: u["role"] === "ADM",
    plan: planOf(u, now),
    passActive: num(u["cardPassUntil"], 0) > now,
    trialLeft: Math.max(0, cfg.trialCards - trialUsed),
    adCredits: Math.max(0, num(u["cardAdCredits"], 0)),
    used: { captures: num(usage?.["captures"], 0), publishes: num(usage?.["publishes"], 0) },
    balance: Math.floor(num(u["giftCoinsBalance"], 0)),
  };
}

/** Devis : état du mois et coût de chaque sortie (base et style Pro), pour l'affichage dans le studio. */
export const cardQuote = onCall({ timeoutSeconds: 15, maxInstances: 10 }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const cfg = await loadCardsConfig();
  const now = Date.now();
  const [us, ug] = await Promise.all([db.collection("Users").doc(uid).get(), usageRef(uid, now).get()]);
  if (!us.exists) throw new HttpsError("not-found", "Compte introuvable.");
  const s = stateFrom(us.data()!, ug.data(), cfg, now);
  const limits = cfg.quotas[s.plan];
  return {
    enabled: cfg.enabled,
    plan: s.plan,
    passUntil: num(us.data()!["cardPassUntil"], 0),
    trialLeft: s.trialLeft,
    adCredits: s.adCredits,
    balance: s.balance,
    month: { captures: s.used.captures, publishes: s.used.publishes, capturesMax: limits.captures, publishesMax: limits.publishes },
    prices: { capture: cfg.priceCapture, publish: cfg.pricePublish, proStyle: s.plan === "gold" ? cfg.priceProStyleGold : cfg.priceProStyle, pass: cfg.passPrice, passDays: cfg.passDays },
    proStyles: cfg.proStyles,
    options: {
      capture: { base: costOf("capture", false, s, cfg), pro: costOf("capture", true, s, cfg) },
      publish: { base: costOf("publish", false, s, cfg), pro: costOf("publish", true, s, cfg) },
    },
  };
});

/**
 * Enregistre l'usage d'une carte (capture ou publication) et débite si besoin. À appeler AVANT de sortir l'image :
 * si la réponse est ok, l'application peut enregistrer, partager ou publier.
 */
export const cardCommit = onCall({ timeoutSeconds: 20, maxInstances: 10 }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const kind = request.data?.kind as CardKind;
  if (kind !== "capture" && kind !== "publish") throw new HttpsError("invalid-argument", "Type inconnu.");
  const pro = request.data?.pro === true;
  const cfg = await loadCardsConfig();
  if (!cfg.enabled) throw new HttpsError("failed-precondition", "CARDS_OFF");
  const now = Date.now();
  const userRef = db.collection("Users").doc(uid);
  const uRef = usageRef(uid, now);

  return db.runTransaction(async (tx) => {
    const [us, ug] = await Promise.all([tx.get(userRef), tx.get(uRef)]);
    if (!us.exists) throw new HttpsError("not-found", "Compte introuvable.");
    const s = stateFrom(us.data()!, ug.data(), cfg, now);
    const cost = costOf(kind, pro, s, cfg);
    if (cost.coins > s.balance) {
      throw new HttpsError("resource-exhausted", "Solde de pièces insuffisant.", { coins: cost.coins, balance: s.balance });
    }

    const userUpdate: Record<string, FirebaseFirestore.FieldValue | number> = { updatedAt: now };
    if (cost.coins > 0) {
      userUpdate["giftCoinsBalance"] = FieldValue.increment(-cost.coins);
      userUpdate["totalGiftCoinsSpent"] = FieldValue.increment(cost.coins);
    }
    if (cost.via === "trial") userUpdate["cardTrialUsed"] = FieldValue.increment(1);
    if (cost.via === "ad") userUpdate["cardAdCredits"] = FieldValue.increment(-1);
    tx.update(userRef, userUpdate);

    tx.set(uRef, {
      userId: uid, month: monthKey(now), updatedAt: now,
      [kind === "capture" ? "captures" : "publishes"]: FieldValue.increment(1),
      ...(pro ? { proCards: FieldValue.increment(1) } : {}),
      ...(cost.coins > 0 ? { coinsSpent: FieldValue.increment(cost.coins) } : {}),
    }, { merge: true });

    if (cost.coins > 0) {
      const t = db.collection("TransactionSoldes").doc();
      tx.set(t, {
        id: t.id, user_id: uid, type: "DEPENSE", statut: "VALIDER",
        description: `Carte Afrolook (${kind === "capture" ? "capture" : "publication"}${pro ? ", style Pro" : ""}) — ${cost.coins} pièces`,
        montant: cost.coins, frais: 0, montant_total: cost.coins, methode_paiement: "pieces", createdAt: now, updatedAt: now,
        purchaseKind: "carte", purchaseRefId: kind,
      });
      recordAppCommission(tx, "deblocages", cost.coins, now);
    }
    return { ok: true, via: cost.via, paid: cost.coins };
  });
});

/** Pass Studio : captures, publications et styles Pro à volonté pendant [passDays] jours, payé en pièces. */
export const cardPassBuy = onCall({ timeoutSeconds: 20, maxInstances: 5 }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const cfg = await loadCardsConfig();
  if (!cfg.enabled) throw new HttpsError("failed-precondition", "CARDS_OFF");
  const now = Date.now();
  const userRef = db.collection("Users").doc(uid);
  const until = await db.runTransaction(async (tx) => {
    const us = await tx.get(userRef);
    if (!us.exists) throw new HttpsError("not-found", "Compte introuvable.");
    const u = us.data()!;
    if (u["role"] === "ADM") throw new HttpsError("failed-precondition", "Les administrateurs n'ont pas besoin du pass.");
    const balance = Math.floor(num(u["giftCoinsBalance"], 0));
    if (balance < cfg.passPrice) throw new HttpsError("resource-exhausted", "Solde de pièces insuffisant.", { coins: cfg.passPrice, balance });
    const current = num(u["cardPassUntil"], 0);
    // les achats s'ajoutent, mais jamais au-delà de 120 jours devant soi
    const next = Math.min(Math.max(now, current) + cfg.passDays * DAY, now + 120 * DAY);
    tx.update(userRef, {
      giftCoinsBalance: FieldValue.increment(-cfg.passPrice),
      totalGiftCoinsSpent: FieldValue.increment(cfg.passPrice),
      cardPassUntil: next,
      updatedAt: now,
    });
    const t = db.collection("TransactionSoldes").doc();
    tx.set(t, {
      id: t.id, user_id: uid, type: "DEPENSE", statut: "VALIDER",
      description: `Pass Studio ${cfg.passDays} jours — ${cfg.passPrice} pièces`,
      montant: cfg.passPrice, frais: 0, montant_total: cfg.passPrice, methode_paiement: "pieces", createdAt: now, updatedAt: now,
      purchaseKind: "carte_pass", purchaseRefId: "card_pass",
    });
    recordAppCommission(tx, "deblocages", cfg.passPrice, now);
    return next;
  });
  return { ok: true, until, price: cfg.passPrice, days: cfg.passDays };
});
