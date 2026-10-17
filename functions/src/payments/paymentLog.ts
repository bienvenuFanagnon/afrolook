import { onCall, HttpsError, type CallableRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { EMAIL_FROM } from "../shared/config";
import { emailTransporter } from "../shared/email_utils";

/**
 * Suivi des paiements : chaque étape d'un paiement (démarrage, confirmation par l'opérateur, crédit des pièces, vérification
 * Google Play / App Store) laisse une trace dans `PaymentLogs`, lisible par l'administration (écran « Suivi des paiements »).
 * Chaque erreur envoie aussi un e-mail d'alerte (au plus un par fournisseur toutes les 10 minutes, avec le nombre d'erreurs ignorées).
 * `PaymentStats/{jour}` tient les compteurs réussis / en erreur par fournisseur.
 */

export type PayProvider = "feexpay" | "cinetpay" | "paygate" | "google_play" | "apple" | "balance" | "app";
export type PayLogInput = {
  provider: PayProvider;
  /** Étape : initiate, execute, webhook, check, verify, credit, pending_timeout, app… */
  step: string;
  ok: boolean;
  uid?: string | null;
  amount?: number | null;
  currency?: string | null;
  reference?: string | null;
  code?: string | null;
  message?: unknown;
  /** Erreur attendue (annulation par la personne…) : consignée, mais sans e-mail d'alerte. */
  expected?: boolean;
};

const ALERT_EMAILS = ["officiel.afrolook@gmail.com", "jorbienvenu@gmail.com"];
const ALERT_GAP_MS = 10 * 60 * 1000;

const PROVIDER_NAMES: Record<PayProvider, string> = {
  feexpay: "FeexPay (Mobile Money / carte)",
  cinetpay: "CinetPay",
  paygate: "PayGate",
  google_play: "Google Play",
  apple: "App Store",
  balance: "Solde (achat de pièces)",
  app: "Application",
};

const cut = (v: unknown, n: number) => {
  let s: string;
  if (v instanceof Error) s = v.message;
  else if (typeof v === "string") s = v;
  else {
    try {
      s = JSON.stringify(v) ?? "";
    } catch {
      s = String(v);
    }
  }
  return s.replace(/\s+/g, " ").slice(0, n);
};

/** Enregistre une étape de paiement. Ne lève jamais d'erreur : le suivi ne doit pas faire échouer un paiement. */
export async function logPayment(e: PayLogInput): Promise<void> {
  try {
    const now = Date.now();
    const day = new Date(now).toISOString().slice(0, 10);
    await db.collection("PaymentLogs").add({
      at: now, day, provider: e.provider, step: e.step, ok: e.ok, expected: e.expected === true,
      uid: e.uid ?? null, amount: e.amount ?? null, currency: e.currency ?? null, reference: e.reference ?? null,
      code: e.code ? cut(e.code, 60) : null, message: cut(e.message ?? "", 500),
    });
    await db.collection("PaymentStats").doc(day).set({ day, [`${e.provider}_${e.ok ? "ok" : e.expected ? "expected" : "error"}`]: FieldValue.increment(1) }, { merge: true });
    if (!e.ok && !e.expected) await alertAdmins(e, now);
  } catch (err) {
    console.error("[logPayment]", err);
  }
}

/**
 * Enveloppe un appel de paiement (Google Play, App Store) : toute erreur est consignée et alerte l'administration, tout crédit réussi est
 * compté. Le résultat et l'erreur d'origine sont renvoyés tels quels à l'application.
 */
export function withPaymentLog<R>(provider: PayProvider, handler: (request: CallableRequest) => Promise<R>) {
  return async (request: CallableRequest): Promise<R> => {
    const uid = request.auth?.uid ?? null;
    const d = (request.data ?? {}) as Record<string, unknown>;
    const reference = String(d["transactionId"] ?? d["productId"] ?? "").slice(0, 60) || null;
    try {
      const res = await handler(request);
      const r = res as unknown as { success?: boolean; alreadyCredited?: boolean; coins?: number } | null;
      if (r?.success && !r.alreadyCredited) await logPayment({ provider, step: "credit", ok: true, uid, amount: r.coins ?? null, currency: "pièces", reference });
      return res;
    } catch (e) {
      if (e instanceof HttpsError) {
        if (e.code !== "unauthenticated") await logPayment({ provider, step: "verify", ok: false, uid, code: e.code, message: e.message, reference });
      } else {
        await logPayment({ provider, step: "verify", ok: false, uid, code: "internal", message: e, reference });
      }
      throw e;
    }
  };
}

async function alertAdmins(e: PayLogInput, now: number): Promise<void> {
  const ref = db.collection("PaymentAlertState").doc(e.provider);
  const send = await db.runTransaction(async (tx) => {
    const s = await tx.get(ref);
    const last = Number(s.data()?.["lastMailAt"] ?? 0);
    const skipped = Number(s.data()?.["skipped"] ?? 0);
    if (now - last < ALERT_GAP_MS) {
      tx.set(ref, { skipped: skipped + 1 }, { merge: true });
      return null;
    }
    tx.set(ref, { lastMailAt: now, skipped: 0 }, { merge: true });
    return skipped;
  });
  if (send === null) return;
  const name = PROVIDER_NAMES[e.provider];
  const when = new Date(now).toLocaleString("fr-FR", { timeZone: "Africa/Lome" });
  const lines = [
    `Un paiement a échoué sur Afrolook : ${name}`, "",
    `Étape : ${e.step}`,
    `Raison : ${cut(e.message ?? "inconnue", 300)}`,
    ...(e.code ? [`Code : ${cut(e.code, 60)}`] : []),
    ...(e.amount != null ? [`Montant : ${e.amount} ${e.currency ?? ""}`.trim()] : []),
    ...(e.reference ? [`Référence : ${e.reference}`] : []),
    ...(e.uid ? [`Utilisateur : ${e.uid}`] : []),
    `Date : ${when}`, "",
    ...(send > 0 ? [`${send} autre(s) erreur(s) de ce fournisseur depuis le dernier e-mail (non envoyées pour ne pas vous inonder).`, ""] : []),
    "Détails : application Afrolook, profil administrateur, « Suivi des paiements ».",
  ];
  try {
    await emailTransporter.sendMail({ from: EMAIL_FROM, to: ALERT_EMAILS, subject: `⚠️ Paiement en échec — ${name}`, text: lines.join("\n") });
  } catch (err) {
    console.error("[paymentLog] e-mail d'alerte non envoyé :", err);
  }
}

/**
 * Erreurs de paiement vues par l'application (achat Google Play / App Store refusé avant d'arriver au serveur, écran de paiement qui
 * échoue…). 20 par compte et par jour au plus. Les annulations par la personne sont consignées sans alerte.
 */
export const paymentReport = onCall({ timeoutSeconds: 15, maxInstances: 5 }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) return { ok: false };
  const d = (request.data ?? {}) as Record<string, unknown>;
  const day = new Date().toISOString().slice(0, 10);
  const cRef = db.collection("PaymentReportCounts").doc(`${uid}_${day}`);
  const allowed = await db.runTransaction(async (tx) => {
    const s = await tx.get(cRef);
    const n = Number(s.data()?.["n"] ?? 0);
    if (n >= 20) return false;
    tx.set(cRef, { n: n + 1, day }, { merge: true });
    return true;
  });
  if (!allowed) return { ok: false };
  const provider = ["google_play", "apple", "feexpay", "cinetpay", "paygate", "balance"].includes(String(d["provider"])) ? (String(d["provider"]) as PayProvider) : "app";
  const code = cut(d["code"], 60);
  const expected = d["expected"] === true || /cancel|annul|user_cancel/i.test(code);
  await logPayment({ provider, step: `app:${cut(d["step"], 30) || "achat"}`, ok: false, uid, amount: typeof d["amount"] === "number" ? d["amount"] : null, currency: cut(d["currency"], 6) || null, code, message: cut(d["message"], 400), expected });
  return { ok: true };
});

/**
 * Surveillance toutes les 15 minutes : un paiement Mobile Money / carte démarré il y a plus de 30 minutes et jamais confirmé est
 * signalé une fois (la personne a peut-être payé sans être créditée : à vérifier chez FeexPay).
 */
export const paymentWatchdog = onSchedule({ schedule: "every 15 minutes", timeoutSeconds: 120, memory: "256MiB" }, async () => {
  const limit = Date.now() - 30 * 60 * 1000;
  const snap = await db.collection("pending_afrolook_feexpay_deposits").where("status", "in", ["pending", "processing"]).limit(200).get();
  for (const doc of snap.docs) {
    const x = doc.data();
    const created = x["createdAt"]?.toMillis?.() ?? 0;
    if (!created || created > limit || x["stuckAlertedAt"]) continue;
    await doc.ref.update({ stuckAlertedAt: Date.now() });
    await logPayment({
      provider: "feexpay", step: "pending_timeout", ok: false, uid: x["userId"], amount: Number(x["amount"] ?? 0), currency: "XOF", reference: x["reference"] ?? doc.id,
      code: String(x["status"]), message: "Paiement démarré il y a plus de 30 minutes et jamais confirmé : à vérifier chez FeexPay.",
    });
  }
});
