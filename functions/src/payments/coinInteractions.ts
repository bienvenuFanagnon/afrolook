import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { CREATOR_SHARE, creditSponsors, num, recordAppCommission, resolveSponsors } from "./coinShares";

/**
 * Interactions payantes en pièces, calculées côté serveur (auparavant dans l'app, donc contournables).
 * - sendLike      : 2 pièces → 1 au créateur, 1 à l'app (pas de parrainage).
 * - sendComment   : 2 pièces → 1 au créateur, 1 à l'app (gratuit sur son propre post, publié même sans solde).
 * - sendPostGift  : cadeau sur un post → 70 % créateur, 2,5 % + 2,5 % parrains, reste à l'app.
 * - sendLiveGift  : cadeau en live → 70 % hôte, 2,5 % + 2,5 % parrains, reste à l'app.
 * Les notifications, commentaires automatiques et animations restent gérés par l'app.
 */

const LIKE_COST = 2;
const LIKE_CREATOR = 1;

function requireAuth(uid: string | undefined): string {
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  return uid;
}

function requireCoins(v: unknown): number {
  const c = Math.floor(num(v));
  if (c <= 0 || c > 10_000_000) throw new HttpsError("invalid-argument", "Montant invalide.");
  return c;
}

function insufficient(balance: number, coins: number): never {
  throw new HttpsError("resource-exhausted", "Solde de pièces insuffisant.", { coins, balance });
}

// ── Like ─────────────────────────────────────────────────────────────────────

export const sendLike = onCall({ timeoutSeconds: 20, memory: "256MiB" }, async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const postId = (request.data as { postId?: string })?.postId;
  if (!postId) throw new HttpsError("invalid-argument", "postId requis.");

  const postRef = db.collection("Posts").doc(postId);
  const senderRef = db.collection("Users").doc(uid);

  return db.runTransaction(async (tx) => {
    const [postDoc, senderDoc] = await Promise.all([tx.get(postRef), tx.get(senderRef)]);
    if (!postDoc.exists) throw new HttpsError("not-found", "Post introuvable.");
    if (!senderDoc.exists) throw new HttpsError("not-found", "Compte introuvable.");
    const creatorId = postDoc.data()!["user_id"] as string | undefined;
    const balance = num(senderDoc.data()!["giftCoinsBalance"]);
    if (balance < LIKE_COST) insufficient(balance, LIKE_COST);
    const now = Date.now();

    tx.update(senderRef, {
      giftCoinsBalance: FieldValue.increment(-LIKE_COST),
      totalGiftCoinsSpent: FieldValue.increment(LIKE_COST),
      updatedAt: now,
    });
    const creatorCoins = creatorId ? LIKE_CREATOR : 0;
    if (creatorId) {
      tx.update(db.collection("Users").doc(creatorId), {
        giftCoinsBalance: FieldValue.increment(creatorCoins),
        totalCoinsEarnedFromLikes: FieldValue.increment(creatorCoins),
        updatedAt: now,
      });
    }
    tx.update(postRef, {
      loves: FieldValue.increment(1),
      users_love_id: FieldValue.arrayUnion(uid),
      popularity: FieldValue.increment(1),
      totalGiftCoinsSentOnThisPost: FieldValue.increment(creatorCoins),
      totalCoinsFromLikes: FieldValue.increment(creatorCoins),
    });
    recordAppCommission(tx, "likes", LIKE_COST - creatorCoins, now);
    return { success: true, coins: LIKE_COST };
  });
});

// ── Commentaire ──────────────────────────────────────────────────────────────

const COMMENT_COST = 2;
const COMMENT_CREATOR = 1;

/**
 * Paiement d'un commentaire (pas des réponses) : 2 pièces → 1 au créateur, 1 à l'app.
 * Gratuit pour le créateur sur son propre post. Sans solde suffisant, rien n'est débité :
 * le commentaire est publié quand même (réponse { paid: false, reason: "insufficient" }).
 */
export const sendComment = onCall({ timeoutSeconds: 20, memory: "256MiB" }, async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const postId = (request.data as { postId?: string })?.postId;
  if (!postId) throw new HttpsError("invalid-argument", "postId requis.");

  const postRef = db.collection("Posts").doc(postId);
  const senderRef = db.collection("Users").doc(uid);

  return db.runTransaction(async (tx) => {
    const [postDoc, senderDoc] = await Promise.all([tx.get(postRef), tx.get(senderRef)]);
    if (!postDoc.exists) throw new HttpsError("not-found", "Post introuvable.");
    if (!senderDoc.exists) throw new HttpsError("not-found", "Compte introuvable.");
    const creatorId = postDoc.data()!["user_id"] as string | undefined;
    if (!creatorId || creatorId === uid) return { paid: false, reason: "own_post", coins: 0 };

    const balance = num(senderDoc.data()!["giftCoinsBalance"]);
    if (balance < COMMENT_COST) return { paid: false, reason: "insufficient", coins: COMMENT_COST, balance };
    const now = Date.now();

    tx.update(senderRef, {
      giftCoinsBalance: FieldValue.increment(-COMMENT_COST),
      totalGiftCoinsSpent: FieldValue.increment(COMMENT_COST),
      updatedAt: now,
    });
    tx.update(db.collection("Users").doc(creatorId), {
      giftCoinsBalance: FieldValue.increment(COMMENT_CREATOR),
      totalCoinsEarnedFromComments: FieldValue.increment(COMMENT_CREATOR),
      updatedAt: now,
    });
    tx.update(postRef, {
      totalGiftCoinsSentOnThisPost: FieldValue.increment(COMMENT_CREATOR),
      totalCoinsFromComments: FieldValue.increment(COMMENT_CREATOR),
    });
    recordAppCommission(tx, "commentaires", COMMENT_COST - COMMENT_CREATOR, now);
    return { paid: true, coins: COMMENT_COST };
  });
});

// ── Cadeau sur un post ───────────────────────────────────────────────────────

export const sendPostGift = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const { postId, coins: rawCoins, giftIcon, giftLabel } = request.data as {
    postId?: string; coins?: number; giftIcon?: string; giftLabel?: string;
  };
  if (!postId) throw new HttpsError("invalid-argument", "postId requis.");
  const coins = requireCoins(rawCoins);

  const postRef = db.collection("Posts").doc(postId);
  const postSnap = await postRef.get();
  if (!postSnap.exists) throw new HttpsError("not-found", "Post introuvable.");
  const receiverId = postSnap.data()!["user_id"] as string | undefined;
  if (!receiverId) throw new HttpsError("failed-precondition", "Créateur introuvable.");

  const sponsors = await resolveSponsors(uid, receiverId, coins);
  const receiverCoins = Math.floor(coins * CREATOR_SHARE);
  const appCoins = coins - receiverCoins - sponsors.reduce((s, p) => s + p.coins, 0);
  const icon = (giftIcon ?? "🎁").slice(0, 8);
  const label = (giftLabel ?? "Cadeau").slice(0, 40);

  const senderRef = db.collection("Users").doc(uid);
  const receiverRef = db.collection("Users").doc(receiverId);

  return db.runTransaction(async (tx) => {
    const [senderDoc, receiverDoc] = await Promise.all([tx.get(senderRef), tx.get(receiverRef)]);
    if (!senderDoc.exists || !receiverDoc.exists) throw new HttpsError("not-found", "Utilisateur introuvable.");
    const balance = num(senderDoc.data()!["giftCoinsBalance"]);
    if (balance < coins) insufficient(balance, coins);
    const now = Date.now();
    const senderPseudo = senderDoc.data()!["pseudo"] ?? "";
    const receiverPseudo = receiverDoc.data()!["pseudo"] ?? "créateur";

    tx.update(senderRef, {
      giftCoinsBalance: FieldValue.increment(-coins),
      totalGiftCoinsSpent: FieldValue.increment(coins),
      updatedAt: now,
    });
    tx.update(receiverRef, {
      giftCoinsBalance: FieldValue.increment(receiverCoins),
      totalCoinsEarnedFromGifts: FieldValue.increment(receiverCoins),
      updatedAt: now,
    });
    tx.update(postRef, {
      users_cadeau_id: FieldValue.arrayUnion(uid),
      popularity: FieldValue.increment(5),
      giftCount: FieldValue.increment(1),
      totalGiftCoinsSentOnThisPost: FieldValue.increment(coins),
    });
    const giftRef = db.collection("PostGifts").doc();
    tx.set(giftRef, {
      id: giftRef.id, postId, senderId: uid, receiverId,
      giftIcon: icon, giftLabel: label, coinsAmount: coins, quantity: 1, createdAt: now,
    });
    const txSender = db.collection("TransactionSoldes").doc();
    tx.set(txSender, {
      id: txSender.id, user_id: uid, type: "CADEAU_PIECES", statut: "VALIDER",
      description: `Envoi de ${icon} ${coins} pièces à @${receiverPseudo}`,
      montant: coins, methode_paiement: "pieces", createdAt: now, updatedAt: now, postId,
    });
    const txReceiver = db.collection("TransactionSoldes").doc();
    tx.set(txReceiver, {
      id: txReceiver.id, user_id: receiverId, type: "CADEAU_PIECES_RECU", statut: "VALIDER",
      description: `Réception de ${icon} ${receiverCoins} pièces de @${senderPseudo}`,
      montant: receiverCoins, methode_paiement: "pieces", createdAt: now, updatedAt: now, postId,
    });
    creditSponsors(tx, sponsors, `cadeau de ${coins} pièces`, now, { postId });
    recordAppCommission(tx, "cadeaux", appCoins, now);
    return { success: true, coins, receiverCoins };
  });
});

// ── Cadeau en live ───────────────────────────────────────────────────────────

export const sendLiveGift = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  const uid = requireAuth(request.auth?.uid);
  const { liveId, coins: rawCoins, giftIcon, giftName } = request.data as {
    liveId?: string; coins?: number; giftIcon?: string; giftName?: string;
  };
  if (!liveId) throw new HttpsError("invalid-argument", "liveId requis.");
  const coins = requireCoins(rawCoins);

  const liveRef = db.collection("lives").doc(liveId);
  const liveSnap = await liveRef.get();
  if (!liveSnap.exists) throw new HttpsError("not-found", "Live introuvable.");
  const hostId = liveSnap.data()!["hostId"] as string | undefined;
  if (!hostId) throw new HttpsError("failed-precondition", "Hôte introuvable.");

  const sponsors = await resolveSponsors(uid, hostId, coins);
  const hostCoins = Math.floor(coins * CREATOR_SHARE);
  const appCoins = coins - hostCoins - sponsors.reduce((s, p) => s + p.coins, 0);
  const icon = (giftIcon ?? "🎁").slice(0, 8);
  const name = (giftName ?? "Cadeau").slice(0, 40);

  const senderRef = db.collection("Users").doc(uid);
  const hostRef = db.collection("Users").doc(hostId);

  return db.runTransaction(async (tx) => {
    const [senderDoc, hostDoc] = await Promise.all([tx.get(senderRef), tx.get(hostRef)]);
    if (!senderDoc.exists || !hostDoc.exists) throw new HttpsError("not-found", "Utilisateur introuvable.");
    const balance = num(senderDoc.data()!["giftCoinsBalance"]);
    if (balance < coins) insufficient(balance, coins);
    const now = Date.now();
    const me = senderDoc.data()!;
    const hostName = hostDoc.data()!["pseudo"] ?? "";

    tx.update(senderRef, {
      giftCoinsBalance: FieldValue.increment(-coins),
      totalGiftCoinsSpent: FieldValue.increment(coins),
    });
    tx.update(hostRef, {
      giftCoinsBalance: FieldValue.increment(hostCoins),
      totalCoinsEarnedFromGifts: FieldValue.increment(hostCoins),
    });
    tx.update(liveRef, {
      giftCoinsTotal: FieldValue.increment(coins),
      giftCount: FieldValue.increment(1),
      [`giftLeaderboard.${uid}`]: FieldValue.increment(coins),
      [`giftLeaderboardMeta.${uid}`]: { pseudo: me["pseudo"] ?? "", imageUrl: me["imageUrl"] ?? "" },
    });
    const txSender = db.collection("TransactionSoldes").doc();
    tx.set(txSender, {
      id: txSender.id, user_id: uid, type: "CADEAU_PIECES", statut: "VALIDER",
      description: `Cadeau ${icon} ${name} (${coins} pièces) en live à @${hostName}`,
      montant: coins, methode_paiement: "pieces", createdAt: now, updatedAt: now, liveId,
    });
    const txHost = db.collection("TransactionSoldes").doc();
    tx.set(txHost, {
      id: txHost.id, user_id: hostId, type: "CADEAU_PIECES_RECU", statut: "VALIDER",
      description: `Cadeau ${icon} reçu de @${me["pseudo"] ?? ""} en live (${hostCoins} pièces)`,
      montant: hostCoins, methode_paiement: "pieces", createdAt: now, updatedAt: now, liveId,
    });
    creditSponsors(tx, sponsors, `cadeau live de ${coins} pièces`, now, { liveId });
    recordAppCommission(tx, "cadeaux_live", appCoins, now);
    return { success: true, coins, hostCoins };
  });
});
