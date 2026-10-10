import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getAuth } from "firebase-admin/auth";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { recordAppCommission } from "../payments/coinShares";
import { canalUnlockCost } from "../posts/canalInactivity";
import { EMAIL_FROM } from "../shared/config";
import { emailTransporter } from "../shared/email_utils";

/**
 * Suppression de compte en deux temps :
 * 1. requestAccountDeletion : l'accès est coupé tout de suite (connexion désactivée, sessions révoquées),
 *    le compte passe en « PENDING_DELETION » et sera effacé définitivement 15 jours plus tard.
 *    Pendant ce délai, le support peut le restaurer (restoreDeletedAccount).
 *    Une restauration est payante : le compte passe en « RESTORE_FEE_DUE » (connexion possible mais toutes les
 *    activités bloquées par l'application) jusqu'au paiement du déblocage en pièces (payRestoreFee). La personne peut
 *    recharger ses pièces pour payer. L'admin peut restaurer sans frais (waiveFee) quand l'erreur vient d'Afrolook.
 *    Prix : le même barème que le déblocage d'un compte inactif depuis 20 jours (selon les abonnés : 500, 1 500,
 *    2 000 ou 3 000 pièces), ou un prix unique fixé dans AppConfig/accountRestore.priceCoins.
 * 2. Effacement définitif des données au bout de 15 jours : traité à part.
 */

const GRACE_DAYS = 15;
const ALERT_EMAILS = ["officiel.afrolook@gmail.com", "jorbienvenu@gmail.com"];

function num(v: unknown): number {
  return typeof v === "number" && Number.isFinite(v) ? v : 0;
}

/** Soldes encore présents sur le compte (à retirer ou dépenser avant la suppression). */
function balancesOf(u: FirebaseFirestore.DocumentData) {
  return {
    coins: Math.floor(num(u["giftCoinsBalance"])),       // Pièces de dépôt + Pièces gagnées
    principal: Math.floor(num(u["votre_solde_principal"])), // Gains à retirer (FCFA)
    depot: Math.floor(num(u["votre_solde_depot"])),         // Dépôt FCFA
    views: Math.floor(num(u["postViewsAvailable"])),        // Revenus des vues à encaisser (FCFA)
  };
}

/** Prix du déblocage après restauration : AppConfig/accountRestore.priceCoins s'il existe, sinon le barème des comptes inactifs. */
async function restoreFeeCoins(u: FirebaseFirestore.DocumentData): Promise<number> {
  const d = (await db.collection("AppConfig").doc("accountRestore").get()).data() ?? {};
  const v = d["priceCoins"];
  if (typeof v === "number" && Number.isFinite(v) && v >= 0) return Math.round(v);
  const followers = Math.max(Array.isArray(u["userAbonnesIds"]) ? (u["userAbonnesIds"] as unknown[]).length : 0, num(u["abonnes"]));
  return canalUnlockCost(followers);
}

export const requestAccountDeletion = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const acceptLoss = (request.data as { acceptLoss?: boolean })?.acceptLoss === true;

  const ref = db.collection("Users").doc(uid);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError("not-found", "Compte introuvable.");
  const user = snap.data()!;

  // Soldes restants : l'utilisateur doit d'abord retirer (ou renoncer explicitement)
  const b = balancesOf(user);
  if ((b.coins > 0 || b.principal > 0 || b.depot > 0 || b.views > 0) && !acceptLoss) {
    throw new HttpsError("failed-precondition", "Il reste des soldes sur ce compte.", b);
  }

  const now = Date.now();
  const scheduledAt = now + GRACE_DAYS * 24 * 3600 * 1000;
  await ref.update({
    accountStatus: "PENDING_DELETION",
    deleted: true,
    deletionRequestedAt: now,
    deletionScheduledAt: scheduledAt,
    deletionBalancesAtRequest: b,
    isConnected: false,
  });

  // Accès coupé immédiatement : connexion refusée et sessions en cours révoquées
  await getAuth().updateUser(uid, { disabled: true });
  await getAuth().revokeRefreshTokens(uid);

  try {
    const date = new Date(scheduledAt).toLocaleDateString("fr-FR");
    await emailTransporter.sendMail({
      from: EMAIL_FROM,
      to: ALERT_EMAILS,
      subject: `Afrolook — Demande de suppression de compte : @${user["pseudo"] ?? uid}`,
      text: [
        `Utilisateur : @${user["pseudo"] ?? "?"} (${user["email"] ?? "sans e-mail"})`,
        `ID : ${uid}`,
        `Suppression définitive prévue le ${date}.`,
        `Soldes au moment de la demande : ${b.coins} pièces, ${b.principal} F gains à retirer, ` +
          `${b.depot} F dépôt, ${b.views} F revenus des vues.`,
        "Pour annuler (erreur signalée au support) : fiche de l'utilisateur dans l'admin → Restaurer le compte.",
      ].join("\n"),
    });
  } catch (e) {
    console.error("E-mail suppression de compte :", e);
  }

  return { scheduledAt };
});

/** Restauration par un admin pendant le délai de 15 jours (erreur signalée au support). */
export const restoreDeletedAccount = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  const adminUid = request.auth?.uid;
  if (!adminUid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const admin = await db.collection("Users").doc(adminUid).get();
  if (admin.data()?.["role"] !== "ADM") throw new HttpsError("permission-denied", "Réservé aux admins.");

  const { userId, waiveFee } = (request.data ?? {}) as { userId?: string; waiveFee?: boolean };
  if (!userId) throw new HttpsError("invalid-argument", "userId requis.");
  const ref = db.collection("Users").doc(userId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError("not-found", "Compte introuvable (déjà effacé ?).");
  const status = snap.data()?.["accountStatus"];
  // Un compte déjà restauré mais pas encore débloqué peut aussi être offert (waiveFee) par le support.
  if (status !== "PENDING_DELETION" && !(status === "RESTORE_FEE_DUE" && waiveFee === true)) {
    throw new HttpsError("failed-precondition", "Ce compte n'est pas en cours de suppression.");
  }

  // Sans frais (erreur d'Afrolook) : compte actif tout de suite. Sinon : bloqué jusqu'au paiement du déblocage.
  const fee = waiveFee === true ? 0 : await restoreFeeCoins(snap.data()!);
  await ref.update({
    accountStatus: fee > 0 ? "RESTORE_FEE_DUE" : "ACTIVE",
    deleted: false,
    deletionRequestedAt: null,
    deletionScheduledAt: null,
    restoreFeeDue: fee > 0 ? fee : null,
    restoredAt: Date.now(),
    restoredBy: adminUid,
    restoredFree: fee === 0,
    // Compte actif ou débloqué : la règle des 20 jours d'inactivité repart de zéro (pas de second paiement)
    ...(fee === 0 ? { lastPostAt: Date.now() } : {}),
  });
  await getAuth().updateUser(userId, { disabled: false });
  return { restored: true, feeCoins: fee };
});

/**
 * Paiement du déblocage d'un compte restauré : les pièces sont retirées du solde de pièces (comme les autres
 * déblocages) et le compte redevient actif. Solde insuffisant : l'application propose de recharger.
 */
export const payRestoreFee = onCall({ timeoutSeconds: 20, maxInstances: 5 }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const ref = db.collection("Users").doc(uid);
  const now = Date.now();
  const fee = await db.runTransaction(async (tx) => {
    const us = await tx.get(ref);
    if (!us.exists) throw new HttpsError("not-found", "Compte introuvable.");
    const u = us.data()!;
    if (u["accountStatus"] !== "RESTORE_FEE_DUE") throw new HttpsError("failed-precondition", "Aucun déblocage à payer.");
    const price = typeof u["restoreFeeDue"] === "number" ? Math.round(u["restoreFeeDue"] as number) : await restoreFeeCoins(u);
    const balance = Math.floor(num(u["giftCoinsBalance"]));
    if (balance < price) throw new HttpsError("resource-exhausted", "Solde de pièces insuffisant.", { coins: price, balance });
    tx.update(ref, {
      giftCoinsBalance: FieldValue.increment(-price),
      totalGiftCoinsSpent: FieldValue.increment(price),
      accountStatus: "ACTIVE",
      restoreFeeDue: null,
      restoreFeePaidAt: now,
      // Déblocage payé : la règle des 20 jours d'inactivité repart de zéro (pas de second paiement)
      lastPostAt: now, accountUnlockedAt: now,
      updatedAt: now,
    });
    const t = db.collection("TransactionSoldes").doc();
    tx.set(t, {
      id: t.id, user_id: uid, type: "DEPENSE", statut: "VALIDER",
      description: `Déblocage du compte après suppression — ${price} pièces`,
      montant: price, frais: 0, montant_total: price, methode_paiement: "pieces", createdAt: now, updatedAt: now,
      purchaseKind: "deblocage_compte", purchaseRefId: "account_restore",
    });
    recordAppCommission(tx, "deblocages", price, now);
    return price;
  });
  return { ok: true, price: fee };
});
