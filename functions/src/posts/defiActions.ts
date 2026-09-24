import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue, Transaction, DocumentReference } from "firebase-admin/firestore";
import { db } from "../shared/firebase";

// Mêmes champs et même répartition que l'envoi de cadeau (lib/services/coin_gift_service.dart) :
// créateur = floor(70 %) sur giftCoinsBalance, reste → AppData.solde_gain_pieces.
const APP_DATA_DOC = "XgkSxKc10vWsJJ2uBraT";

function computeShares(prix: number): { appShare: number; creatorShare: number } {
  const creatorShare = Math.floor(prix * 0.7);
  const appShare = prix - creatorShare;
  return { appShare, creatorShare };
}

/**
 * handleDefiAction — callable sécurisée pour les interactions DÉFI.
 *
 * actions:
 *   "vote"        — voter pour une réponse (postId = réponse)
 *   "participate" — payer la participation ET créer le post-réponse dans la même
 *                   transaction (postId = défi, post = post-réponse sérialisé) ;
 *                   une seule participation par utilisateur et par DÉFI
 */
export const handleDefiAction = onCall(
  { timeoutSeconds: 30, memory: "256MiB", cpu: 1 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentification requise.");
    }

    const { action, postId, post } = request.data as {
      action?: string;
      postId?: string;
      post?: Record<string, unknown>;
    };

    if (!action || !postId) {
      throw new HttpsError("invalid-argument", "action et postId sont requis.");
    }

    // Toujours l'utilisateur authentifié : un id envoyé par le client permettrait de débiter un autre compte.
    const uid = request.auth.uid;

    if (action === "vote") {
      return handleVote(uid, postId);
    }
    if (action === "participate") {
      if (!post || typeof post !== "object") {
        throw new HttpsError("invalid-argument", "Le post de participation est requis.");
      }
      return handleParticipation(uid, postId, post);
    }

    throw new HttpsError("invalid-argument", `Action inconnue : ${action}`);
  }
);

// Débit payeur + crédit créateur + part app + historique, dans la transaction appelante.
// Toutes les lectures doivent avoir été faites avant l'appel.
function chargeFee(tx: Transaction, params: {
  payerRef: DocumentReference;
  payerId: string;
  creatorRef: DocumentReference;
  creatorId: string;
  fee: number;
  defiPostId: string;
  kind: "vote" | "participation";
}) {
  const { payerRef, payerId, creatorRef, creatorId, fee, defiPostId, kind } = params;
  const { appShare, creatorShare } = computeShares(fee);
  const now = Date.now();
  const label = kind === "vote" ? "Vote DÉFI" : "Participation DÉFI";

  tx.update(payerRef, {
    giftCoinsBalance: FieldValue.increment(-fee),
    totalGiftCoinsSpent: FieldValue.increment(fee),
    updatedAt: now,
  });

  tx.update(creatorRef, {
    giftCoinsBalance: FieldValue.increment(creatorShare),
    totalCoinsEarnedFromDefi: FieldValue.increment(creatorShare),
    updatedAt: now,
  });

  if (appShare > 0) {
    tx.update(db.collection("AppData").doc(APP_DATA_DOC), {
      solde_gain_pieces: FieldValue.increment(appShare),
    });
  }

  const payerTxRef = db.collection("TransactionSoldes").doc();
  tx.set(payerTxRef, {
    id: payerTxRef.id,
    user_id: payerId,
    type: "DEPENSE",
    statut: "VALIDER",
    description: `${label} — ${fee} pièces`,
    montant: fee,
    frais: 0,
    montant_total: fee,
    methode_paiement: "pieces",
    createdAt: now,
    updatedAt: now,
    defiPostId,
  });

  const creatorTxRef = db.collection("TransactionSoldes").doc();
  tx.set(creatorTxRef, {
    id: creatorTxRef.id,
    user_id: creatorId,
    type: "GAIN_PIECES",
    statut: "VALIDER",
    description: `${label} reçu(e) — ${creatorShare} pièces`,
    montant: creatorShare,
    frais: 0,
    montant_total: creatorShare,
    methode_paiement: "pieces",
    createdAt: now,
    updatedAt: now,
    defiPostId,
  });
}

// ── Vote ──────────────────────────────────────────────────────────────────────
async function handleVote(voterId: string, responsePostId: string) {
  const responseRef = db.collection("Posts").doc(responsePostId);
  const voterRef = db.collection("Users").doc(voterId);

  return db.runTransaction(async (tx) => {
    const [responseDoc, voterDoc] = await Promise.all([
      tx.get(responseRef),
      tx.get(voterRef),
    ]);

    if (!responseDoc.exists) {
      throw new HttpsError("not-found", "Post réponse introuvable.");
    }
    if (!voterDoc.exists) {
      throw new HttpsError("not-found", "Compte votant introuvable.");
    }

    const responseData = responseDoc.data()!;
    const defiPostId: string | undefined = responseData["defi_response_to_post_id"];
    if (!defiPostId) {
      throw new HttpsError("invalid-argument", "Ce post n'est pas une réponse à un défi.");
    }

    const voterIds: string[] = responseData["defi_voter_ids"] ?? [];
    if (voterIds.includes(voterId)) {
      throw new HttpsError("already-exists", "Vous avez déjà voté pour cette réponse.");
    }

    const defiRef = db.collection("Posts").doc(defiPostId);
    const defiDoc = await tx.get(defiRef);
    if (!defiDoc.exists) {
      throw new HttpsError("not-found", "Post DÉFI parent introuvable.");
    }

    const defiData = defiDoc.data()!;
    const defiConfig = defiData["defi_config"] as Record<string, unknown> | undefined;
    const defiCreatorId: string | undefined = defiData["user_id"];
    const voteFee: number = (defiConfig?.["vote_fee"] as number) ?? 0;

    if (voteFee > 0) {
      if (!defiCreatorId) {
        throw new HttpsError("not-found", "Créateur du DÉFI introuvable.");
      }
      const creatorRef = db.collection("Users").doc(defiCreatorId);
      const creatorDoc = await tx.get(creatorRef);
      if (!creatorDoc.exists) {
        throw new HttpsError("not-found", "Créateur du DÉFI introuvable.");
      }

      const balance: number = (voterDoc.data()!["giftCoinsBalance"] as number) ?? 0;
      if (balance < voteFee) {
        throw new HttpsError(
          "resource-exhausted",
          `Solde insuffisant — ${balance} pièces disponibles, ${voteFee} requises.`
        );
      }

      chargeFee(tx, {
        payerRef: voterRef,
        payerId: voterId,
        creatorRef,
        creatorId: defiCreatorId,
        fee: voteFee,
        defiPostId,
        kind: "vote",
      });
    }

    tx.update(responseRef, {
      defi_votes: FieldValue.increment(1),
      defi_voter_ids: FieldValue.arrayUnion(voterId),
    });

    return { success: true };
  });
}

// ── Participation ─────────────────────────────────────────────────────────────
const POST_ID_PATTERN = /^[A-Za-z0-9_-]{10,64}$/;

// Le post vient du client : on impose l'identité, le lien au DÉFI et on remet
// à zéro tout ce qui ne doit pas pouvoir être fixé à la création.
function sanitizeParticipationPost(
  raw: Record<string, unknown>,
  postId: string,
  userId: string,
  defiPostId: string,
): Record<string, unknown> {
  const data: Record<string, unknown> = { ...raw };
  for (const key of [
    "defi_config", "rawScore", "postScore", "reporterIds", "wrongCategoryReporterIds",
    "reportCount", "commentSuggestions", "isRepost", "reposterUserId", "reposterPseudo",
    "reposterImageUrl", "originalPostId",
  ]) {
    delete data[key];
  }
  return {
    ...data,
    id: postId,
    user_id: userId,
    type: "POST",
    status: "VALIDE",
    defi_response_to_post_id: defiPostId,
    defi_votes: 0,
    defi_voter_ids: [],
    likes: 0,
    loves: 0,
    comments: 0,
    partage: 0,
    vues: 0,
    popularity: 0,
    giftCount: 0,
    feedScore: 0,
    uniqueViewsCount: 0,
    favorites_count: 0,
    adSupportCount: 0,
    seen_by_users_count: 0,
    seen_by_users_map: {},
    votes_challenge: 0,
    users_like_id: [],
    users_love_id: [],
    users_vue_id: [],
    users_republier_id: [],
    users_favorite_id: [],
    users_votes_ids: [],
    isBoosted: false,
    isAdvertisement: false,
    advertisementId: null,
    rang_gagnant: null,
    prix_gagnant: null,
    prix_deja_encaisser: null,
    date_encaissement: null,
  };
}

async function handleParticipation(
  participantId: string,
  defiPostId: string,
  rawPost: Record<string, unknown>,
) {
  const newPostId = rawPost["id"];
  if (typeof newPostId !== "string" || !POST_ID_PATTERN.test(newPostId)) {
    throw new HttpsError("invalid-argument", "Identifiant de post invalide.");
  }

  const defiRef = db.collection("Posts").doc(defiPostId);
  const participantRef = db.collection("Users").doc(participantId);
  const newPostRef = db.collection("Posts").doc(newPostId);

  return db.runTransaction(async (tx) => {
    const [defiDoc, participantDoc, existingPostDoc] = await Promise.all([
      tx.get(defiRef),
      tx.get(participantRef),
      tx.get(newPostRef),
    ]);

    // Relance après une réponse perdue (coupure réseau) : le post a déjà été créé et payé.
    if (existingPostDoc.exists) {
      const existing = existingPostDoc.data()!;
      if (existing["user_id"] === participantId && existing["defi_response_to_post_id"] === defiPostId) {
        return { success: true, postId: newPostId, alreadyCreated: true };
      }
      throw new HttpsError("already-exists", "Identifiant de post déjà utilisé.");
    }

    if (!defiDoc.exists) {
      throw new HttpsError("not-found", "Post DÉFI introuvable.");
    }
    if (!participantDoc.exists) {
      throw new HttpsError("not-found", "Compte participant introuvable.");
    }

    const defiData = defiDoc.data()!;
    if (defiData["type"] !== "DEFI") {
      throw new HttpsError("invalid-argument", "Ce post n'est pas un DÉFI.");
    }

    const defiConfig = defiData["defi_config"] as Record<string, unknown> | undefined;
    const endDate = (defiConfig?.["end_date"] as number) ?? 0;
    if (defiConfig?.["status"] === "termine" || (endDate > 0 && endDate < Date.now())) {
      throw new HttpsError("failed-precondition", "Ce DÉFI est terminé.");
    }

    const participantIds: string[] = defiData["defi_participant_ids"] ?? [];
    if (participantIds.includes(participantId)) {
      throw new HttpsError("already-exists", "Vous participez déjà à ce DÉFI.");
    }

    const defiCreatorId: string | undefined = defiData["user_id"];
    const participationFee: number = (defiConfig?.["participation_fee"] as number) ?? 0;

    if (participationFee > 0) {
      if (!defiCreatorId) {
        throw new HttpsError("not-found", "Créateur du DÉFI introuvable.");
      }
      const creatorRef = db.collection("Users").doc(defiCreatorId);
      const creatorDoc = await tx.get(creatorRef);
      if (!creatorDoc.exists) {
        throw new HttpsError("not-found", "Créateur du DÉFI introuvable.");
      }

      const balance: number = (participantDoc.data()!["giftCoinsBalance"] as number) ?? 0;
      if (balance < participationFee) {
        throw new HttpsError(
          "resource-exhausted",
          `Solde insuffisant — ${balance} pièces disponibles, ${participationFee} requises.`
        );
      }

      chargeFee(tx, {
        payerRef: participantRef,
        payerId: participantId,
        creatorRef,
        creatorId: defiCreatorId,
        fee: participationFee,
        defiPostId,
        kind: "participation",
      });
    }

    tx.set(newPostRef, sanitizeParticipationPost(rawPost, newPostId, participantId, defiPostId));

    tx.update(defiRef, {
      defi_participant_ids: FieldValue.arrayUnion(participantId),
      defi_participant_count: FieldValue.increment(1),
    });

    return { success: true, postId: newPostId };
  });
}
