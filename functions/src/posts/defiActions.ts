import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue, Transaction, DocumentReference } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import {
  APP_DATA_DOC, POST_ID_PATTERN, defaultRewardSplit, defiLabel, sanitizeClientPost, sendDefiNotification,
} from "./defiShared";


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
 *   "create"      — créer un DÉFI en débitant la cagnotte au créateur dans la même
 *                   transaction (postId = id du nouveau post, post = post DÉFI sérialisé)
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
    if (action === "create") {
      if (!post || typeof post !== "object") {
        throw new HttpsError("invalid-argument", "Le post DÉFI est requis.");
      }
      return handleCreateDefi(uid, postId, post);
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
  const vote = await recordVote(voterId, responsePostId);
  try {
    await notifyVote({ ...vote, voterId, responsePostId });
  } catch (err) {
    // Le vote est déjà enregistré : un échec de notification ne doit pas le faire échouer.
    console.error("[handleDefiAction] Notification de vote échouée:", err);
  }
  return { success: true };
}

async function recordVote(voterId: string, responsePostId: string) {
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

    const endDate = (defiConfig?.["end_date"] as number) ?? 0;
    if (defiConfig?.["status"] === "termine" || (endDate > 0 && endDate < Date.now())) {
      throw new HttpsError("failed-precondition", "Ce DÉFI est terminé.");
    }

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

    const voterData = voterDoc.data()!;
    return {
      defiPostId,
      defiCreatorId,
      defiDescription: (defiData["description"] as string | undefined) ?? "",
      responseOwnerId: responseData["user_id"] as string | undefined,
      responseDataType: (responseData["dataType"] as string | undefined) ?? "",
      responseThumbnail: (responseData["thumbnail"] as string | undefined)
        ?? ((responseData["images"] as string[] | undefined)?.[0]) ?? "",
      voterPseudo: (voterData["pseudo"] as string | undefined) ?? "",
      voterImage: (voterData["imageUrl"] as string | undefined) ?? "",
    };
  });
}

// Notifie le participant (son post a reçu un vote) et le créateur du DÉFI.
async function notifyVote(p: {
  voterId: string;
  responsePostId: string;
  defiPostId: string;
  defiCreatorId?: string;
  defiDescription: string;
  responseOwnerId?: string;
  responseDataType: string;
  responseThumbnail: string;
  voterPseudo: string;
  voterImage: string;
}) {
  const ownerId = p.responseOwnerId;
  const creatorId = p.defiCreatorId;
  const notifyOwner = !!ownerId && ownerId !== p.voterId;
  const notifyCreator = !!creatorId && creatorId !== p.voterId && creatorId !== ownerId;
  if (!notifyOwner && !notifyCreator) return;

  const [appDoc, ownerDoc] = await Promise.all([
    db.collection("AppData").doc(APP_DATA_DOC).get(),
    ownerId ? db.collection("Users").doc(ownerId).get() : Promise.resolve(null),
  ]);
  const appConfig = appDoc.data() ?? {};
  const voter = p.voterPseudo ? `@${p.voterPseudo}` : "Quelqu'un";
  const ownerPseudo = (ownerDoc?.data()?.["pseudo"] as string | undefined) ?? "";
  const label = defiLabel(p.defiDescription);
  const common = {
    senderId: p.voterId,
    postId: p.responsePostId,
    postDataType: p.responseDataType,
    image: p.voterImage,
    thumbnail: p.responseThumbnail,
    defiPostId: p.defiPostId,
    appConfig,
  };

  await Promise.all([
    notifyOwner ? sendDefiNotification({
      ...common,
      receiverId: ownerId!,
      receiverData: ownerDoc?.data(),
      titre: "🗳️ Nouveau vote",
      message: `🗳️ ${voter} a voté pour ta participation au DÉFI${label}`,
    }) : Promise.resolve(),
    notifyCreator ? sendDefiNotification({
      ...common,
      receiverId: creatorId!,
      titre: "🗳️ Vote dans ton DÉFI",
      message: `🗳️ ${voter} a voté pour ${ownerPseudo ? `@${ownerPseudo}` : "une participation"} dans ton DÉFI${label}`,
    }) : Promise.resolve(),
  ]);
}

// ── Participation ─────────────────────────────────────────────────────────────

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

    tx.set(newPostRef, {
      ...sanitizeClientPost(rawPost, newPostId, participantId),
      type: "POST",
      defi_response_to_post_id: defiPostId,
    });

    tx.update(defiRef, {
      defi_participant_ids: FieldValue.arrayUnion(participantId),
      defi_participant_count: FieldValue.increment(1),
    });

    return { success: true, postId: newPostId };
  });
}

// ── Création d'un DÉFI ────────────────────────────────────────────────────────
const MAX_CAGNOTTE = 10_000_000;
const MAX_DEFI_DURATION_MS = 90 * 24 * 3600 * 1000;

function toInt(v: unknown): number {
  return typeof v === "number" && Number.isFinite(v) ? Math.floor(v) : NaN;
}

async function handleCreateDefi(creatorId: string, newPostId: string, rawPost: Record<string, unknown>) {
  if (!POST_ID_PATTERN.test(newPostId) || rawPost["id"] !== newPostId) {
    throw new HttpsError("invalid-argument", "Identifiant de post invalide.");
  }

  const cfg = rawPost["defi_config"] as Record<string, unknown> | undefined;
  if (!cfg || typeof cfg !== "object") {
    throw new HttpsError("invalid-argument", "Configuration du DÉFI manquante.");
  }
  const cagnotte = toInt(cfg["cagnotte_pieces"]);
  const participationFee = toInt(cfg["participation_fee"] ?? 0);
  const voteFee = toInt(cfg["vote_fee"] ?? 0);
  const winnersCount = toInt(cfg["winners_count"] ?? 1);
  const endDate = toInt(cfg["end_date"]);
  const now = Date.now();

  if (!(cagnotte >= 0 && cagnotte <= MAX_CAGNOTTE)
      || !(participationFee >= 0)
      || !(voteFee === 0 || voteFee >= 5)
      || !(winnersCount >= 1 && winnersCount <= 3)
      || !(endDate > now && endDate <= now + MAX_DEFI_DURATION_MS)) {
    throw new HttpsError("invalid-argument", "Configuration du DÉFI invalide.");
  }

  const postRef = db.collection("Posts").doc(newPostId);
  const creatorRef = db.collection("Users").doc(creatorId);

  return db.runTransaction(async (tx) => {
    const [existingDoc, creatorDoc] = await Promise.all([tx.get(postRef), tx.get(creatorRef)]);

    // Relance après une réponse perdue : le DÉFI a déjà été créé et la cagnotte débitée.
    if (existingDoc.exists) {
      const existing = existingDoc.data()!;
      if (existing["user_id"] === creatorId && existing["type"] === "DEFI") {
        return { success: true, postId: newPostId, alreadyCreated: true };
      }
      throw new HttpsError("already-exists", "Identifiant de post déjà utilisé.");
    }
    if (!creatorDoc.exists) {
      throw new HttpsError("not-found", "Compte créateur introuvable.");
    }

    if (cagnotte > 0) {
      const balance = (creatorDoc.data()!["giftCoinsBalance"] as number) ?? 0;
      if (balance < cagnotte) {
        throw new HttpsError(
          "resource-exhausted",
          `Solde insuffisant — ${balance} pièces disponibles, ${cagnotte} requises pour la cagnotte.`
        );
      }
      tx.update(creatorRef, {
        giftCoinsBalance: FieldValue.increment(-cagnotte),
        totalGiftCoinsSpent: FieldValue.increment(cagnotte),
        updatedAt: now,
      });
      const txRef = db.collection("TransactionSoldes").doc();
      tx.set(txRef, {
        id: txRef.id,
        user_id: creatorId,
        type: "DEPENSE",
        statut: "VALIDER",
        description: `Cagnotte DÉFI — ${cagnotte} pièces mises en jeu`,
        montant: cagnotte,
        frais: 0,
        montant_total: cagnotte,
        methode_paiement: "pieces",
        createdAt: now,
        updatedAt: now,
        defiPostId: newPostId,
      });
    }

    tx.set(postRef, {
      ...sanitizeClientPost(rawPost, newPostId, creatorId),
      type: "DEFI",
      defi_participant_ids: [],
      defi_participant_count: 0,
      defi_config: {
        cagnotte_pieces: cagnotte,
        participation_fee: participationFee,
        vote_fee: voteFee,
        winners_count: winnersCount,
        reward_split: defaultRewardSplit(winnersCount),
        end_date: endDate,
        status: "en_cours",
        cagnotte_funded: true,
      },
    });

    return { success: true, postId: newPostId };
  });
}
