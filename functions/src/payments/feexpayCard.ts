import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { FieldValue } from "firebase-admin/firestore";
import { createHash, randomBytes } from "crypto";
import axios from "axios";
import { db } from "../shared/firebase";
import { FEEXPAY_API_KEY_AFROLOOK, FEEXPAY_SHOP_ID_AFROLOOK } from "../shared/config";
import { lockFieldsAfterChange } from "../shared/coin_locks";
import { notifyAdmins } from "../shared/admin_notify";
import { logPayment } from "./paymentLog";
import { RECHARGE_PACKS, recordCoinSale } from "./coinPurchase";
import { num } from "./coinShares";

/**
 * Achat de pièces par carte bancaire (FeexPay), réservé à Afrolook Web.
 *
 * - Le prix en dollars = prix du pack en FCFA ÷ taux fixe ÷ (1 − frais FeexPay − marge) : l'acheteur supporte les frais,
 *   Afrolook encaisse au moins le prix du pack.
 * - Les pièces ne sont créditées qu'après vérification du statut chez FeexPay (le webhook ne sert qu'à relancer cette vérification),
 *   une seule fois par commande. Ce sont des pièces achetées : dépensables, non convertibles en argent.
 * - Réglages modifiables sans redéployer : AppConfig/cardPayments (voir cardCoinAdminConfig).
 */

const FEEXPAY_API = "https://api-v2.feexpay.me/api/transactions/public";
const TERMS_VERSION = "2026-10-card-1";

export type CardConfig = {
  enabled: boolean;
  /** Frais FeexPay carte internationale (3,9 % + 3 % de conversion), en %. */
  feePct: number;
  /** Marge de sécurité en % (change, remboursements). */
  marginPct: number;
  /** Taux fixe : FCFA pour 1 USD. */
  xofPerUsd: number;
  /** Packs de pièces vendus par carte. */
  packs: number[];
  userPerDay: number;
  ipPerDay: number;
  /** Plafond mensuel par compte, en USD. 0 = illimité. */
  userMonthUsd: number;
  /** Alerte admin quand le nombre de paiements carte du jour atteint ce seuil. 0 = pas d'alerte. */
  alertPerDay: number;
};

export const CARD_DEFAULTS: CardConfig = {
  enabled: true, feePct: 6.9, marginPct: 3, xofPerUsd: 600,
  packs: [1000, 2500, 5000, 12000, 25000, 50000],
  userPerDay: 10, ipPerDay: 20, userMonthUsd: 1000, alertPerDay: 50,
};

/** Origines autorisées : la carte n'existe que sur le site web (jamais depuis les applications Android / iPhone, qui n'envoient pas d'Origin). */
const WEB_ORIGINS = new Set([
  "https://afrolookmedia.com", "https://www.afrolookmedia.com", "https://afrolooki.web.app", "https://afrolooki.firebaseapp.com",
]);

export async function cardConfig(): Promise<CardConfig> {
  const snap = await db.collection("AppConfig").doc("cardPayments").get();
  const d = (snap.data() ?? {}) as Partial<CardConfig>;
  const cfg: CardConfig = { ...CARD_DEFAULTS };
  for (const k of Object.keys(CARD_DEFAULTS) as (keyof CardConfig)[]) {
    if (d[k] === undefined || d[k] === null) continue;
    if (k === "packs") {
      if (Array.isArray(d.packs)) cfg.packs = d.packs.map(Number).filter((c) => RECHARGE_PACKS[c]);
    } else if (k === "enabled") {
      cfg.enabled = d.enabled !== false;
    } else {
      const v = Number(d[k]);
      if (Number.isFinite(v) && v >= 0) (cfg[k] as number) = v;
    }
  }
  if (cfg.xofPerUsd < 100) cfg.xofPerUsd = CARD_DEFAULTS.xofPerUsd;
  if (cfg.feePct + cfg.marginPct > 40) { cfg.feePct = CARD_DEFAULTS.feePct; cfg.marginPct = CARD_DEFAULTS.marginPct; }
  return cfg;
}

/** Prix carte d'un pack, en USD (arrondi au centime supérieur). */
export function cardQuote(coins: number, cfg: CardConfig) {
  const xof = RECHARGE_PACKS[coins];
  if (!xof) return null;
  const base = xof / cfg.xofPerUsd;
  const total = Math.ceil((base / (1 - (cfg.feePct + cfg.marginPct) / 100)) * 100) / 100;
  const net = Math.round(total * (1 - cfg.feePct / 100) * 100) / 100;
  return { coins, xof, base: Math.round(base * 100) / 100, total, net };
}

function requireWeb(request: { rawRequest: { headers: Record<string, unknown> } }) {
  const origin = String(request.rawRequest.headers["origin"] ?? "");
  if (!WEB_ORIGINS.has(origin)) throw new HttpsError("permission-denied", "Le paiement par carte est disponible uniquement sur le site Afrolook.");
}

function clientIp(request: { rawRequest: { headers: Record<string, unknown>; ip?: string } }): string {
  const xff = String(request.rawRequest.headers["x-forwarded-for"] ?? "").split(",")[0].trim();
  return xff || request.rawRequest.ip || "";
}

const ipHash = (ip: string) => createHash("sha256").update(`afrolook-card:${ip}`).digest("hex").slice(0, 16);
const clean = (v: unknown, n: number) => String(v ?? "").replace(/[\u0000-\u001f<>]/g, " ").replace(/\s+/g, " ").trim().slice(0, n);

async function feex(url: string, method: "GET" | "POST", body?: unknown) {
  try {
    const r = await axios.request({
      url, method, data: body, timeout: 25000, validateStatus: () => true,
      headers: { Authorization: `Bearer ${FEEXPAY_API_KEY_AFROLOOK}`, "Content-Type": "application/json" },
    });
    return { ok: r.status >= 200 && r.status < 300, status: r.status, data: (r.data ?? {}) as Record<string, unknown> };
  } catch (e) {
    return { ok: false, status: 0, data: { message: (e as Error).message } as Record<string, unknown> };
  }
}

/** Prix et réglages publics (affichés avant le paiement). */
export const cardCoinQuote = onCall({ timeoutSeconds: 15, cors: true }, async (request) => {
  requireWeb(request);
  const cfg = await cardConfig();
  return {
    enabled: cfg.enabled,
    termsVersion: TERMS_VERSION,
    feePct: cfg.feePct + cfg.marginPct,
    xofPerUsd: cfg.xofPerUsd,
    packs: cfg.packs.map((c) => cardQuote(c, cfg)).filter(Boolean),
  };
});

export const cardCoinStart = onCall({ timeoutSeconds: 60, memory: "256MiB", cors: true, maxInstances: 5 }, async (request) => {
  requireWeb(request);
  if (!request.auth) throw new HttpsError("unauthenticated", "Connecte-toi pour acheter des pièces.");
  const uid = request.auth.uid;
  const d = (request.data ?? {}) as Record<string, unknown>;
  const cfg = await cardConfig();
  if (!cfg.enabled) throw new HttpsError("unavailable", "Le paiement par carte est momentanément indisponible. Utilise le Mobile Money.");

  const coins = Math.floor(num(d["coins"]));
  const q = cfg.packs.includes(coins) ? cardQuote(coins, cfg) : null;
  if (!q) throw new HttpsError("invalid-argument", "Ce pack n'est pas disponible par carte.");
  if (d["terms"] !== true) throw new HttpsError("failed-precondition", "Accepte les conditions pour continuer.");

  const first = clean(d["firstName"], 40), last = clean(d["lastName"], 40), city = clean(d["city"], 60), zip = clean(d["zip"], 12);
  const country = String(d["country"] ?? "").toUpperCase();
  const phone = String(d["phone"] ?? "").replace(/[^0-9]/g, "");
  if (!first || !last || !city || !zip || !/^[A-Z]{2}$/.test(country) || phone.length < 8 || phone.length > 15) {
    throw new HttpsError("invalid-argument", "Renseigne ton nom, ta ville, ton code postal, ton pays et ton téléphone.");
  }

  const userDoc = await db.collection("Users").doc(uid).get();
  if (!userDoc.exists) throw new HttpsError("not-found", "Compte introuvable.");
  const user = userDoc.data()!;
  if (user["cardBlocked"] === true) throw new HttpsError("permission-denied", "La carte est désactivée sur ton compte. Utilise le Mobile Money.");
  const email = String(request.auth.token.email ?? user["email"] ?? "");
  if (!email) throw new HttpsError("failed-precondition", "Ton compte n'a pas d'adresse e-mail.");

  // Limites (anti-fraude) : un seul champ filtré côté serveur, le reste en mémoire (pas d'index composite)
  const ip = ipHash(clientIp(request));
  const dayAgo = Date.now() - 86400000, monthAgo = Date.now() - 30 * 86400000;
  const byUser = (await db.collection("CardCoinOrders").where("uid", "==", uid).get()).docs.map((x) => x.data());
  const valid = (o: FirebaseFirestore.DocumentData) => o["status"] !== "failed" && o["status"] !== "expired";
  if (byUser.filter((o) => valid(o) && o["createdAt"] >= dayAgo).length >= cfg.userPerDay) {
    throw new HttpsError("resource-exhausted", "Limite de paiements par carte atteinte pour aujourd'hui. Réessaie demain.");
  }
  if (cfg.userMonthUsd > 0) {
    const spent = byUser.filter((o) => o["status"] === "paid" && o["createdAt"] >= monthAgo).reduce((a, o) => a + num(o["total"]), 0);
    if (spent + q.total > cfg.userMonthUsd) throw new HttpsError("resource-exhausted", "Plafond mensuel par carte atteint.");
  }
  const byIp = (await db.collection("CardCoinOrders").where("ipHash", "==", ip).get()).docs.map((x) => x.data());
  if (byIp.filter((o) => valid(o) && o["createdAt"] >= dayAgo).length >= cfg.ipPerDay) {
    throw new HttpsError("resource-exhausted", "Trop de paiements par carte depuis cette connexion aujourd'hui.");
  }

  const orderId = randomBytes(8).toString("hex");
  const ref = db.collection("CardCoinOrders").doc(orderId);
  const now = Date.now();
  await ref.set({
    uid, coins, xof: q.xof, total: q.total, net: q.net, currency: "USD", feePct: cfg.feePct, marginPct: cfg.marginPct, xofPerUsd: cfg.xofPerUsd,
    email, ipHash: ip, country, status: "created", createdAt: now,
    terms: { version: TERMS_VERSION, acceptedAt: now, ipHash: ip, userAgent: clean(request.rawRequest.headers["user-agent"], 160) },
  });

  const payload = {
    shop: FEEXPAY_SHOP_ID_AFROLOOK, amount: String(q.total), currency: "USD",
    first_name: first, last_name: last, email, phoneNumber: phone, city, zip, country,
    description: `Afrolook ${coins} pieces`, callback_info: JSON.stringify({ orderId, uid, type: "afrolook_card_coins" }),
  };
  const r = await feex(`${FEEXPAY_API}/requesttopay/init`, "POST", payload);
  const reference = r.data["reference"] as string | undefined;
  const url = (r.data["payment_url"] ?? r.data["paymentUrl"]) as string | undefined;
  if (!r.ok || !reference || !url) {
    const why = String(r.data["message"] ?? r.status).slice(0, 200);
    await ref.update({ status: "failed", failure: why });
    await logPayment({ provider: "feexpay", step: "card_start", ok: false, uid, amount: q.total, currency: "USD", code: String(r.status), message: why });
    throw new HttpsError("unavailable", "Le paiement par carte n'a pas pu démarrer. Réessaie dans un instant ou utilise le Mobile Money.");
  }
  await ref.update({ status: "processing", reference, processingAt: now });

  // Alerte de volume : une seule fois, au passage du seuil
  if (cfg.alertPerDay > 0) {
    const today = (await db.collection("CardCoinOrders").where("createdAt", ">=", dayAgo).get()).size;
    if (today === cfg.alertPerDay) {
      await notifyAdmins({ title: "Paiements carte : volume élevé", message: `${today} paiements par carte démarrés en 24 h. À vérifier (fraude possible).`, refId: orderId });
    }
  }
  return { orderId, paymentUrl: url, total: q.total, coins };
});

const SUCCESS = new Set(["SUCCESSFUL", "SUCCESS", "ACCEPTED"]);
const FAILURE = new Set(["FAILED", "CANCELLED", "CANCELED", "EXPIRED", "DECLINED", "REFUSED"]);

/** Vérifie la commande chez FeexPay et crédite les pièces, une seule fois. */
export async function settleCardOrder(orderId: string): Promise<{ status: string; coins?: number }> {
  const ref = db.collection("CardCoinOrders").doc(orderId);
  const snap = await ref.get();
  if (!snap.exists) return { status: "not_found" };
  const o = snap.data()!;
  if (o["status"] === "paid") return { status: "paid", coins: num(o["coins"]) };
  if (o["status"] === "failed" || o["status"] === "expired" || o["status"] === "chargeback") return { status: String(o["status"]) };
  if (!o["reference"]) return { status: "pending" };

  const r = await feex(`${FEEXPAY_API}/single/status/${encodeURIComponent(String(o["reference"]))}`, "GET");
  const st = String(r.data["status"] ?? "").toUpperCase();
  await ref.update({ lastStatus: st || null, lastCheckAt: Date.now(), checks: FieldValue.increment(1) }).catch(() => undefined);
  if (!r.ok) {
    await logPayment({ provider: "feexpay", step: "card_check", ok: false, uid: o["uid"], reference: String(o["reference"]), code: String(r.status), message: r.data["message"] ?? "Statut FeexPay indisponible" });
    return { status: "pending" };
  }

  if (FAILURE.has(st)) {
    await ref.update({ status: "failed", failure: String(r.data["reason"] ?? r.data["message"] ?? st).slice(0, 200) });
    await logPayment({ provider: "feexpay", step: "card_settle", ok: false, expected: true, uid: o["uid"], amount: num(o["total"]), currency: "USD", reference: String(o["reference"]), code: st, message: r.data["reason"] ?? r.data["message"] ?? st });
    return { status: "failed" };
  }
  if (!SUCCESS.has(st)) return { status: "pending" };

  // Le montant confirmé par FeexPay doit être celui de la commande (quand il est donné en dollars)
  const paidAmount = Number(r.data["amount"]);
  const paidCur = String(r.data["currency"] ?? "").toUpperCase();
  if (paidCur === "USD" && Number.isFinite(paidAmount) && Math.abs(paidAmount - num(o["total"])) > 0.02) {
    await ref.update({ status: "amount_mismatch", mismatch: { expected: o["total"], got: paidAmount } });
    await logPayment({ provider: "feexpay", step: "card_settle", ok: false, uid: o["uid"], amount: paidAmount, currency: "USD", reference: String(o["reference"]), code: "amount_mismatch", message: `Montant attendu ${o["total"]} USD, reçu ${paidAmount} USD : pièces NON créditées.` });
    return { status: "pending" };
  }

  const uid = String(o["uid"]);
  const coins = num(o["coins"]);
  const userRef = db.collection("Users").doc(uid);
  const result = await db.runTransaction(async (t) => {
    const [orderDoc, userDoc] = await Promise.all([t.get(ref), t.get(userRef)]);
    if (orderDoc.data()?.["status"] === "paid") return { already: true };
    if (!userDoc.exists) throw new Error("Compte introuvable");
    const now = Date.now();
    t.update(userRef, {
      giftCoinsBalance: FieldValue.increment(coins),
      totalGiftCoinsPurchased: FieldValue.increment(coins),
      ...lockFieldsAfterChange(userDoc.data(), coins),
      updatedAt: now,
    });
    const txRef = db.collection("TransactionSoldes").doc();
    t.set(txRef, {
      id: txRef.id, user_id: uid, type: "ACHAT_PIECES", statut: "VALIDER",
      description: `Achat de ${coins} pièces par carte bancaire`,
      montant: coins, coins,
      amountPaid: num(o["total"]), currency: "USD", netEstimate: num(o["net"]),
      paymentMethod: "Carte bancaire", frais: 0, montant_total: coins,
      methode_paiement: "carte_feexpay", beneficiaryId: uid,
      cardOrderId: orderId, feexpayReference: o["reference"] ?? null,
      createdAt: now, updatedAt: now,
    });
    recordCoinSale(t, now, coins, num(o["total"]), "USD", num(o["net"]));
    t.update(ref, { status: "paid", paidAt: now, transactionId: txRef.id, fx: pickFx(r.data) });
    return { already: false };
  });
  if (!result.already) {
    await logPayment({ provider: "feexpay", step: "card_credit", ok: true, uid, amount: num(o["total"]), currency: "USD", reference: String(o["reference"]) });
  }
  return { status: "paid", coins };
}

/** Garde les champs financiers utiles du statut FeexPay, jamais de donnée personnelle ni de carte. */
function pickFx(data: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(data)) {
    if (Object.keys(out).length >= 14) break;
    if (!/amount|fee|charge|commission|net|total|currency|method|type|network|brand|country|status|reason|code/i.test(k)) continue;
    if (/number|pan|cvv|cvc|holder|name|email|phone|address/i.test(k)) continue;
    if (typeof v === "number" || typeof v === "boolean") out[k] = v;
    else if (typeof v === "string") out[k] = v.slice(0, 80);
  }
  return out;
}

/** Retour de la page de paiement : l'application interroge la commande jusqu'à ce qu'elle soit créditée. */
export const cardCoinStatus = onCall({ timeoutSeconds: 40, memory: "256MiB", cors: true, maxInstances: 10 }, async (request) => {
  requireWeb(request);
  if (!request.auth) throw new HttpsError("unauthenticated", "Authentification requise.");
  const orderId = clean((request.data ?? {}).orderId, 40);
  const snap = await db.collection("CardCoinOrders").doc(orderId).get();
  if (!snap.exists || snap.data()!["uid"] !== request.auth.uid) throw new HttpsError("not-found", "Commande introuvable.");
  return settleCardOrder(orderId);
});

/** Appelé par le webhook FeexPay : relance la vérification de la commande portant cette référence. Renvoie vrai si c'était une commande carte. */
export async function cardWebhookReference(reference: string): Promise<boolean> {
  const q = await db.collection("CardCoinOrders").where("reference", "==", reference).limit(1).get();
  if (q.empty) return false;
  await settleCardOrder(q.docs[0].id);
  return true;
}

/**
 * Rattrapage toutes les 10 minutes : commandes carte démarrées mais jamais vérifiées (webhook manqué, onglet fermé).
 * Au-delà de 24 h sans confirmation, la commande est marquée expirée (le paiement ne peut plus aboutir).
 */
export const cardCoinReconcile = onSchedule({ schedule: "every 10 minutes", timeoutSeconds: 120, memory: "256MiB" }, async () => {
  const snap = await db.collection("CardCoinOrders").where("status", "==", "processing").limit(100).get();
  const now = Date.now();
  for (const doc of snap.docs) {
    const o = doc.data();
    if (now - num(o["createdAt"]) < 2 * 60 * 1000) continue;
    try {
      const r = await settleCardOrder(doc.id);
      if (r.status === "pending" && now - num(o["createdAt"]) > 24 * 3600 * 1000) await doc.ref.update({ status: "expired" });
    } catch (e) {
      await logPayment({ provider: "feexpay", step: "card_reconcile", ok: false, uid: o["uid"], reference: o["reference"], message: (e as Error).message });
    }
  }
});

async function requireAdmin(uid: string | undefined) {
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const role = (await db.collection("Users").doc(uid).get()).data()?.["role"];
  if (!["ADM", "admin", "ADMIN", "super_admin"].includes(role)) throw new HttpsError("permission-denied", "Réservé aux administrateurs.");
}

/** Administration : lire / modifier les réglages carte (AppConfig/cardPayments). Sans `set`, renvoie les réglages actuels. */
export const cardCoinAdminConfig = onCall({ timeoutSeconds: 20, cors: true }, async (request) => {
  await requireAdmin(request.auth?.uid);
  const set = (request.data ?? {}).set as Record<string, unknown> | undefined;
  if (set) {
    const upd: Record<string, unknown> = {};
    for (const k of Object.keys(CARD_DEFAULTS) as (keyof CardConfig)[]) {
      if (set[k] === undefined) continue;
      if (k === "enabled") upd[k] = set[k] === true;
      else if (k === "packs") upd[k] = (Array.isArray(set[k]) ? (set[k] as unknown[]) : []).map(Number).filter((c) => RECHARGE_PACKS[c]);
      else {
        const v = Number(set[k]);
        if (Number.isFinite(v) && v >= 0) upd[k] = v;
      }
    }
    await db.collection("AppConfig").doc("cardPayments").set(upd, { merge: true });
  }
  return { config: await cardConfig() };
});

/**
 * Administration : contestation de paiement (rétrofacturation) signalée par FeexPay. Les pièces de la commande sont retirées (le solde
 * peut devenir négatif), la commande passe en « chargeback » et le compte ne peut plus payer par carte.
 */
export const cardCoinAdminChargeback = onCall({ timeoutSeconds: 30, cors: true }, async (request) => {
  await requireAdmin(request.auth?.uid);
  const orderId = clean((request.data ?? {}).orderId, 40);
  const note = clean((request.data ?? {}).note, 200);
  const ref = db.collection("CardCoinOrders").doc(orderId);
  return db.runTransaction(async (t) => {
    const snap = await t.get(ref);
    if (!snap.exists) throw new HttpsError("not-found", "Commande introuvable.");
    const o = snap.data()!;
    if (o["status"] === "chargeback") return { ok: true, already: true };
    if (o["status"] !== "paid") throw new HttpsError("failed-precondition", "Seule une commande payée peut être contestée.");
    const userRef = db.collection("Users").doc(String(o["uid"]));
    const userDoc = await t.get(userRef);
    const coins = num(o["coins"]);
    const now = Date.now();
    t.update(userRef, {
      giftCoinsBalance: FieldValue.increment(-coins),
      ...lockFieldsAfterChange(userDoc.data(), -coins),
      cardBlocked: true, cardBlockedAt: now, updatedAt: now,
    });
    t.update(ref, { status: "chargeback", chargebackAt: now, chargebackNote: note, chargebackBy: request.auth!.uid });
    return { ok: true };
  });
});
