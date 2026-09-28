import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getAuth } from "firebase-admin/auth";
import { db } from "../shared/firebase";
import { EMAIL_FROM } from "../shared/config";
import { emailTransporter } from "../shared/email_utils";

/**
 * Suppression de compte en deux temps :
 * 1. requestAccountDeletion : l'accès est coupé tout de suite (connexion désactivée, sessions révoquées),
 *    le compte passe en « PENDING_DELETION » et sera effacé définitivement 15 jours plus tard.
 *    Pendant ce délai, le support peut le restaurer (restoreDeletedAccount) en cas d'erreur.
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

  const userId = (request.data as { userId?: string })?.userId;
  if (!userId) throw new HttpsError("invalid-argument", "userId requis.");
  const ref = db.collection("Users").doc(userId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError("not-found", "Compte introuvable (déjà effacé ?).");
  if (snap.data()?.["accountStatus"] !== "PENDING_DELETION") {
    throw new HttpsError("failed-precondition", "Ce compte n'est pas en cours de suppression.");
  }

  await ref.update({
    accountStatus: "ACTIVE",
    deleted: false,
    deletionRequestedAt: null,
    deletionScheduledAt: null,
    restoredAt: Date.now(),
    restoredBy: adminUid,
  });
  await getAuth().updateUser(userId, { disabled: false });
  return { restored: true };
});
