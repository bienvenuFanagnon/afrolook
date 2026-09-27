import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { EMAIL_FROM } from "../shared/config";
import { emailTransporter } from "../shared/email_utils";
import { lockFieldsAfterChange } from "../shared/coin_locks";
import { dayKey, num } from "./coinShares";

/**
 * Achat de pièces avec un solde FCFA (Dépôt FCFA ou Gains à retirer) — calculé côté serveur.
 * Grille 2026-09-27 (lib/models/coin_pack.dart → rechargePacks) : de 0,50 F à 0,40 F par pièce.
 * Les pièces achetées sont des Pièces de dépôt : dépensables, non convertibles en argent.
 */
export const RECHARGE_PACKS: Record<number, number> = {
  500: 250, 1000: 480, 2500: 1150, 5000: 2200, 12000: 5000,
  25000: 10000, 50000: 20000, 125000: 50000, 250000: 100000,
};
const BALANCE_KEYS: Record<string, string> = {
  votre_solde_depot: "Dépôt FCFA",
  votre_solde_principal: "Gains à retirer",
};

/** Ventes de pièces du jour (page admin « Commissions » → section Ventes de pièces). */
export function recordCoinSale(
  tx: FirebaseFirestore.Transaction, now: number, coins: number, amount: number, currency: string, netEstimate?: number,
) {
  const cur = currency.toUpperCase();
  tx.set(db.collection("CommissionsDaily").doc(dayKey(now)), {
    date: dayKey(now),
    ventes_pieces: FieldValue.increment(coins),
    ventes_nombre: FieldValue.increment(1),
    ventes_montants: { [cur]: FieldValue.increment(amount) },
    ...(netEstimate !== undefined ? { ventes_net_estime: { [cur]: FieldValue.increment(netEstimate) } } : {}),
    updatedAt: now,
  }, { merge: true });
}

export const buyCoinsWithBalance = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Authentification requise.");
  const uid = request.auth.uid;
  const { coins: rawCoins, balanceKey, beneficiaryId } = request.data as {
    coins?: number; balanceKey?: string; beneficiaryId?: string;
  };
  const coins = Math.floor(num(rawCoins));
  const price = RECHARGE_PACKS[coins];
  if (!price) throw new HttpsError("invalid-argument", "Pack inconnu.");
  if (!balanceKey || !(balanceKey in BALANCE_KEYS)) throw new HttpsError("invalid-argument", "Solde inconnu.");
  const receiverId = beneficiaryId && beneficiaryId !== uid ? beneficiaryId : uid;
  const isForSelf = receiverId === uid;

  const payerRef = db.collection("Users").doc(uid);
  const receiverRef = db.collection("Users").doc(receiverId);

  return db.runTransaction(async (tx) => {
    const payerDoc = await tx.get(payerRef);
    if (!payerDoc.exists) throw new HttpsError("not-found", "Compte introuvable.");
    const receiverDoc = isForSelf ? payerDoc : await tx.get(receiverRef);
    if (!receiverDoc.exists) throw new HttpsError("not-found", "Destinataire introuvable.");

    const balance = num(payerDoc.data()![balanceKey]);
    if (balance < price) {
      throw new HttpsError("resource-exhausted", "Solde insuffisant.", { price, balance });
    }
    const now = Date.now();
    const payerPseudo = payerDoc.data()!["pseudo"] ?? "";
    const receiverPseudo = receiverDoc.data()!["pseudo"] ?? "";

    tx.update(payerRef, { [balanceKey]: FieldValue.increment(-price), updatedAt: now });
    tx.update(receiverRef, {
      giftCoinsBalance: FieldValue.increment(coins),
      totalGiftCoinsPurchased: FieldValue.increment(coins),
      ...lockFieldsAfterChange(receiverDoc.data(), coins),
      updatedAt: now,
    });

    const payerTx = db.collection("TransactionSoldes").doc();
    tx.set(payerTx, {
      id: payerTx.id,
      user_id: uid,
      type: "ACHAT_PIECES",
      statut: "VALIDER",
      description: isForSelf ? `Achat de ${coins} pièces` : `Achat de ${coins} pièces pour @${receiverPseudo}`,
      // Nouveau modèle d'achat : montant = pièces, + montant payé, devise et moyen de paiement
      montant: coins,
      coins,
      amountPaid: price,
      currency: "XOF",
      paymentMethod: BALANCE_KEYS[balanceKey],
      methode_paiement: balanceKey === "votre_solde_depot" ? "solde_depot" : "solde_gains",
      beneficiaryId: receiverId,
      beneficiaryPseudo: receiverPseudo,
      balanceAfter: balance - price,
      createdAt: now,
      updatedAt: now,
    });
    if (!isForSelf) {
      const recvTx = db.collection("TransactionSoldes").doc();
      tx.set(recvTx, {
        id: recvTx.id,
        user_id: receiverId,
        type: "CADEAU_PIECES_RECU",
        statut: "VALIDER",
        description: `Réception de ${coins} pièces de la part de @${payerPseudo}`,
        montant: coins,
        methode_paiement: "cadeau",
        createdAt: now,
        updatedAt: now,
      });
    }
    recordCoinSale(tx, now, coins, price, "XOF");
    return { success: true, coins, price };
  });
});

// ── E-mail à chaque achat de pièces et à chaque dépôt Mobile Money ─────────────

const PURCHASE_ALERT_EMAILS = ["officiel.afrolook@gmail.com", "jorbienvenu@gmail.com"];

function fmt(n: number): string {
  return new Intl.NumberFormat("fr-FR", { maximumFractionDigits: 2 }).format(n);
}

export const onPurchaseOrDepositNotify = onDocumentWritten(
  { document: "TransactionSoldes/{txId}", timeoutSeconds: 60 },
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return;
    const t = after.data()!;
    const type = t.type as string | undefined;
    if (type !== "ACHAT_PIECES" && type !== "DEPOT") return;
    if (t.statut !== "VALIDER" || t.emailNotifiedAt) return;

    // Verrou : un seul e-mail par transaction, même si le document est réécrit
    const claimed = await db.runTransaction(async (tx) => {
      const snap = await tx.get(after.ref);
      if (snap.data()?.emailNotifiedAt) return false;
      tx.update(after.ref, { emailNotifiedAt: Date.now() });
      return true;
    });
    if (!claimed) return;

    const user = (await db.collection("Users").doc(t.user_id).get()).data() ?? {};
    const date = new Date(num(t.createdAt) || Date.now()).toLocaleString("fr-FR", { timeZone: "Africa/Lome" });
    const lines: string[] = [];
    let subject: string;

    if (type === "ACHAT_PIECES") {
      const coins = num(t.coins) || num(t.montant);
      const amount = t.amountPaid !== undefined ? `${fmt(num(t.amountPaid))} ${t.currency ?? ""}`.trim() : "non renseigné";
      subject = `🪙 Achat de ${fmt(coins)} pièces — @${user.pseudo ?? "?"}`;
      lines.push(
        "Nouvel achat de pièces sur Afrolook", "",
        `Acheteur : @${user.pseudo ?? "?"} (${user.email ?? "e-mail inconnu"})`,
        `Pièces achetées : ${fmt(coins)}`,
        `Montant payé : ${amount}`,
        ...(t.netEstimate !== undefined ? [`Net estimé après Apple (70 %) : ${fmt(num(t.netEstimate))} ${t.currency ?? ""}`] : []),
        `Moyen de paiement : ${t.paymentMethod ?? t.methode_paiement ?? "?"}`,
        ...(t.beneficiaryId && t.beneficiaryId !== t.user_id ? [`Bénéficiaire : @${t.beneficiaryPseudo ?? t.beneficiaryId}`] : []),
        `Date : ${date}`,
        `Transaction : ${after.id}`,
      );
    } else {
      subject = `💰 Dépôt de ${fmt(num(t.montant))} FCFA — @${user.pseudo ?? "?"}`;
      lines.push(
        "Nouveau dépôt Mobile Money sur Afrolook", "",
        `Utilisateur : @${user.pseudo ?? "?"} (${user.email ?? "e-mail inconnu"})`,
        `Montant crédité : ${fmt(num(t.montant))} FCFA`,
        `Frais : ${fmt(num(t.frais))} FCFA — total payé : ${fmt(num(t.montant_total) || num(t.montant) + num(t.frais))} FCFA`,
        `Moyen : ${t.methode_paiement ?? "?"}${t.numero_depot ? ` — n° ${t.numero_depot}` : ""}`,
        `Date : ${date}`,
        `Transaction : ${after.id}`,
      );
    }

    try {
      await emailTransporter.sendMail({ from: EMAIL_FROM, to: PURCHASE_ALERT_EMAILS, subject, text: lines.join("\n") });
    } catch (err) {
      console.error("[onPurchaseOrDepositNotify] e-mail non envoyé :", err);
      // Pas de nouvelle tentative automatique (éviterait une boucle si le SMTP est en panne)
      await after.ref.update({ emailError: String(err) });
    }
  }
);
