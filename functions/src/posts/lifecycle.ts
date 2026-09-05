import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";

/**
 * Firestore trigger : quand un post est créé,
 * - incrémente newPostsByCreator {creatorId: count} sur chaque abonné
 * - ajoute {postId: createdAtMs} dans unreadPosts sur chaque abonné
 *   (map timestampé pour le Tier 1 du feed algorithmique)
 */
export const updateFollowersNewPostCount = onDocumentCreated(
  "Posts/{postId}",
  async (event) => {
    const post = event.data?.data();
    if (!post) return;

    const creatorId = post.user_id as string | undefined;
    if (!creatorId) return;

    const allowedTypes = ["POST", "CHRONIQUE", "CHALLENGE", "CHALLENGEPARTICIPATION"];
    if (!allowedTypes.includes(post.type)) return;

    const postId = event.params.postId;
    // created_at est en microsecondes côté Flutter → convertir en ms
    const createdAtMs: number = post.created_at
      ? Math.floor(post.created_at / 1000)
      : Date.now();

    const creatorDoc = await db.collection("Users").doc(creatorId).get();
    if (!creatorDoc.exists) return;

    const followerIds: string[] = creatorDoc.data()?.userAbonnesIds ?? [];
    if (followerIds.length === 0) return;

    console.log(`Post ${postId} de ${creatorId} — fan-out vers ${followerIds.length} abonnés`);

    const BATCH_SIZE = 400;
    for (let i = 0; i < followerIds.length; i += BATCH_SIZE) {
      const chunk = followerIds.slice(i, i + BATCH_SIZE);
      const batch = db.batch();
      for (const followerId of chunk) {
        const ref = db.collection("Users").doc(followerId);
        batch.set(ref, {
          newPostsByCreator: { [creatorId]: FieldValue.increment(1) },
          unreadPosts: { [postId]: createdAtMs },
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
 * Callable admin : supprime les postIds vus du map unreadPosts de l'utilisateur.
 * Appelé par l'app quand l'utilisateur a scrollé sur des posts Tier 1.
 */
export const markPostsSeen = onCall(
  { timeoutSeconds: 10 },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Auth requise");

    const uid = request.auth.uid;
    const seenIds: string[] = request.data?.seenIds ?? [];
    if (seenIds.length === 0) return { ok: true };

    const updates: Record<string, unknown> = {};
    for (const id of seenIds.slice(0, 200)) {
      updates[`unreadPosts.${id}`] = FieldValue.delete();
    }

    await db.collection("Users").doc(uid).update(updates);
    return { ok: true, removed: Math.min(seenIds.length, 200) };
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
