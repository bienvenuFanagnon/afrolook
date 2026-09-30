import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { creditSponsors, num, recordAppCommission, resolveSponsors } from "../payments/coinShares";

/**
 * Stickers-cadeaux : un sticker payant envoyé sous un commentaire.
 * Répartition (voir la page des règles) : 40 % à l'auteur du commentaire, 30 % au créateur du sticker,
 * 30 % à Afrolook (parrainages 2,5 % + 2,5 % pris sur la part d'Afrolook). Un sticker officiel n'a pas de créateur :
 * sa part de 30 % revient aussi à Afrolook. Tout est en pièces gagnées côté bénéficiaires.
 * Ouvert à tous les comptes (comme les autres cadeaux) : pas de limite d'abonnement, le prix suffit.
 */
const RECEIVER_SHARE = 0.4;
const CREATOR_STICKER_SHARE = 0.3;

export const stickerGiftSend = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const { commentId, replyId, stickerId } = request.data as { commentId?: string; replyId?: string; stickerId?: string };
  if (!commentId || !stickerId) throw new HttpsError("invalid-argument", "commentId et stickerId requis.");

  const stickerSnap = await db.collection("Stickers").doc(stickerId).get();
  if (!stickerSnap.exists || stickerSnap.get("status") !== "active") throw new HttpsError("failed-precondition", "Sticker indisponible.");
  const sticker = stickerSnap.data()!;
  const coins = Math.floor(num(sticker["giftPriceCoins"]));
  if (coins <= 0) throw new HttpsError("failed-precondition", "Ce sticker n'est pas un sticker-cadeau.");
  const pack = await db.collection("StickerPacks").doc(String(sticker["packId"] ?? "")).get();
  if (!pack.exists || pack.get("status") !== "active") throw new HttpsError("failed-precondition", "Pack indisponible.");

  const commentRef = db.collection("PostComments").doc(commentId);
  const commentSnap = await commentRef.get();
  if (!commentSnap.exists) throw new HttpsError("not-found", "Commentaire introuvable.");
  const cdata = commentSnap.data()!;
  let receiverId = cdata["user_id"] as string | undefined;
  if (replyId) {
    const reply = ((cdata["responseComments"] as Array<Record<string, unknown>> | undefined) ?? []).find((r) => r["id"] === replyId);
    receiverId = reply?.["user_id"] as string | undefined;
  }
  if (!receiverId) throw new HttpsError("not-found", "Auteur introuvable.");
  if (receiverId === uid) throw new HttpsError("invalid-argument", "Impossible de s'offrir un cadeau.");
  const postId = (cdata["post_id"] as string | undefined) ?? null;

  const creatorRaw = sticker["creatorId"] as string | undefined;
  const creatorId = creatorRaw && creatorRaw !== "afrolook" ? creatorRaw : undefined;

  const sponsors = await resolveSponsors(uid, receiverId, coins);
  const receiverCoins = Math.floor(coins * RECEIVER_SHARE);
  const creatorCoins = creatorId ? Math.floor(coins * CREATOR_STICKER_SHARE) : 0;
  const appCoins = coins - receiverCoins - creatorCoins - sponsors.reduce((s, p) => s + p.coins, 0);
  const label = String((sticker["captions"] as Record<string, string> | undefined)?.["fr"] ?? "Sticker").slice(0, 40);

  const senderRef = db.collection("Users").doc(uid);
  const receiverRef = db.collection("Users").doc(receiverId);
  const creatorRef = creatorId ? db.collection("Users").doc(creatorId) : null;

  return db.runTransaction(async (tx) => {
    const [senderDoc, receiverDoc] = await Promise.all([tx.get(senderRef), tx.get(receiverRef)]);
    if (!senderDoc.exists || !receiverDoc.exists) throw new HttpsError("not-found", "Utilisateur introuvable.");
    const creatorDoc = creatorRef ? await tx.get(creatorRef) : null;
    const balance = num(senderDoc.data()!["giftCoinsBalance"]);
    if (balance < coins) throw new HttpsError("resource-exhausted", "Solde de pièces insuffisant.", { coins, balance });
    const now = Date.now();
    const senderPseudo = senderDoc.data()!["pseudo"] ?? "";
    const receiverPseudo = receiverDoc.data()!["pseudo"] ?? "";

    tx.update(senderRef, {
      giftCoinsBalance: FieldValue.increment(-coins), totalGiftCoinsSpent: FieldValue.increment(coins), updatedAt: now,
    });
    tx.update(receiverRef, {
      giftCoinsBalance: FieldValue.increment(receiverCoins), totalCoinsEarnedFromGifts: FieldValue.increment(receiverCoins), updatedAt: now,
    });
    if (creatorRef && creatorDoc?.exists && creatorCoins > 0) {
      tx.update(creatorRef, {
        giftCoinsBalance: FieldValue.increment(creatorCoins), totalCoinsEarnedFromSales: FieldValue.increment(creatorCoins), updatedAt: now,
      });
      const t = db.collection("TransactionSoldes").doc();
      tx.set(t, {
        id: t.id, user_id: creatorId, type: "GAIN_PIECES", statut: "VALIDER",
        description: `Sticker-cadeau « ${label} » utilisé — ${creatorCoins} pièces reçues`,
        montant: creatorCoins, frais: 0, montant_total: creatorCoins, methode_paiement: "pieces", createdAt: now, updatedAt: now,
        purchaseKind: "sticker_gift", purchaseRefId: stickerId, payerId: uid,
      });
    }
    tx.update(commentRef, replyId ? { [`replyCoins.${replyId}`]: FieldValue.increment(receiverCoins) }
      : { coinsEarned: FieldValue.increment(receiverCoins) });
    const giftRef = db.collection("CommentGifts").doc();
    tx.set(giftRef, {
      id: giftRef.id, commentId, replyId: replyId ?? null, postId, senderId: uid, receiverId,
      giftIcon: "🎁", giftLabel: label, coinsAmount: coins, createdAt: now,
      stickerId, stickerUrl: sticker["url"] ?? null, stickerThumbUrl: sticker["thumbUrl"] ?? null, stickerCreatorId: creatorId ?? null,
    });
    const txSender = db.collection("TransactionSoldes").doc();
    tx.set(txSender, {
      id: txSender.id, user_id: uid, type: "CADEAU_PIECES", statut: "VALIDER",
      description: `Sticker-cadeau « ${label} » à @${receiverPseudo} — ${coins} pièces`,
      montant: coins, methode_paiement: "pieces", createdAt: now, updatedAt: now, postId,
    });
    const txReceiver = db.collection("TransactionSoldes").doc();
    tx.set(txReceiver, {
      id: txReceiver.id, user_id: receiverId, type: "CADEAU_PIECES_RECU", statut: "VALIDER",
      description: `Sticker-cadeau « ${label} » de @${senderPseudo} — ${receiverCoins} pièces reçues`,
      montant: receiverCoins, methode_paiement: "pieces", createdAt: now, updatedAt: now, postId,
    });
    creditSponsors(tx, sponsors, `sticker-cadeau de ${coins} pièces`, now, { postId });
    recordAppCommission(tx, "stickers", appCoins, now);
    tx.update(db.collection("Stickers").doc(stickerId), { giftCount: FieldValue.increment(1), usageCount: FieldValue.increment(1) });
    return { success: true, coins, receiverCoins, creatorCoins, receiverId };
  });
});
