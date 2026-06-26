import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";

/**
 * Firestore trigger : quand un post est créé, incrémente newPostsByCreator
 * sur le document de chaque abonné du créateur.
 * Traitement identique à l'envoi des notifications — continue même si
 * l'utilisateur quitte l'app.
 */
export const updateFollowersNewPostCount = onDocumentCreated(
  "Posts/{postId}",
  async (event) => {
    const post = event.data?.data();
    if (!post) return;

    const creatorId = post.user_id as string | undefined;
    if (!creatorId) return;

    // Seuls les posts "normaux" incrémentent le compteur
    const allowedTypes = ["POST", "CHRONIQUE", "CHALLENGE", "CHALLENGEPARTICIPATION"];
    if (!allowedTypes.includes(post.type)) return;

    // Récupère la liste des abonnés du créateur
    const creatorDoc = await db.collection("Users").doc(creatorId).get();
    if (!creatorDoc.exists) return;

    const followerIds: string[] = creatorDoc.data()?.userAbonnesIds ?? [];
    if (followerIds.length === 0) return;

    console.log(`Post ${event.params.postId} de ${creatorId} — mise à jour de ${followerIds.length} abonnés`);

    // Firestore batch : max 500 opérations par batch.
    // On utilise set+merge au lieu de update pour éviter un plantage si un
    // document abonné n'existe plus (compte supprimé, ID orphelin, etc.).
    // Chaque lot est dans son propre try-catch : un lot raté ne relance pas
    // la fonction entière (ce qui causerait du double-comptage).
    const BATCH_SIZE = 400;
    for (let i = 0; i < followerIds.length; i += BATCH_SIZE) {
      const chunk = followerIds.slice(i, i + BATCH_SIZE);
      const batch = db.batch();
      for (const followerId of chunk) {
        const ref = db.collection("Users").doc(followerId);
        batch.set(ref, {
          newPostsByCreator: { [creatorId]: FieldValue.increment(1) },
        }, { merge: true });
      }
      try {
        await batch.commit();
        console.log(`Lot ${Math.floor(i / BATCH_SIZE) + 1} commité (${chunk.length} abonnés)`);
      } catch (err) {
        console.error(`Lot ${Math.floor(i / BATCH_SIZE) + 1} échoué :`, err);
      }
    }
  }
);

/**
 * Firestore trigger : détecte les nouveaux posts en statut PENDING
 * et les valide ou invalide selon une validation basique.
 */
export const moderatePostLifecycle = onDocumentCreated(
  "Posts/{postId}",
  async (event) => {
    const post = event.data?.data();
    if (!post || post.statut !== "PENDING") return;

    const isValid = post.dataType && ["IMAGE", "VIDEO", "AUDIO", "TEXT"].includes(post.dataType);

    await event.data!.ref.update({
      statut: isValid ? "VALIDE" : "NONVALIDE",
      moderatedAt: FieldValue.serverTimestamp(),
    });
  }
);

/**
 * Callable Firebase : vérifie côté serveur si l'utilisateur peut poster (cooldown 5 minutes).
 */
export const checkPostCooldownServer = onCall(
  { timeoutSeconds: 10 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentification requise");
    }

    const uid = request.auth.uid;

    const lastPostQuery = await db.collection("Posts")
      .where("user_id", "==", uid)
      .orderBy("created_at", "desc")
      .limit(1)
      .get();

    if (lastPostQuery.empty) return { canPost: true, remainingSeconds: 0 };

    const lastPost = lastPostQuery.docs[0].data();
    // Flutter stores timestamps in microseconds — convert to milliseconds
    const lastPostMicros: number = lastPost.created_at ?? 0;
    const lastPostMs = Math.floor(lastPostMicros / 1000);
    const nowMs = Date.now();
    const elapsed = nowMs - lastPostMs;
    const cooldownMs = 5 * 60 * 1000; // 5 minutes

    if (elapsed < cooldownMs) {
      const remaining = Math.ceil((cooldownMs - elapsed) / 1000);
      return { canPost: false, remainingSeconds: remaining };
    }

    return { canPost: true, remainingSeconds: 0 };
  }
);
