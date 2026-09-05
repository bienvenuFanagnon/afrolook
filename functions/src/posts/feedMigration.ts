import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db } from "../shared/firebase";

const ALLOWED_TYPES = ["POST", "CHRONIQUE", "CHALLENGE", "CHALLENGEPARTICIPATION"];
const BATCH_FAN_OUT = 400;

/**
 * Callable admin-only : backfille unreadPosts sur les 3 derniers mois.
 *
 * Appel : { cursor?: string } — retourne { nextCursor, processed, done }
 * Appeler en boucle depuis l'admin panel jusqu'à done === true.
 *
 * Protection : seul le compte admin (claim 'admin': true) peut appeler.
 */
export const migrateUnreadPostsFanOut = onCall(
  { timeoutSeconds: 540, memory: "512MiB" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Auth requise");

    // Vérifier le claim admin
    const isAdmin = request.auth.token?.admin === true;
    if (!isAdmin) throw new HttpsError("permission-denied", "Réservé aux admins");

    const cursor: string | undefined = request.data?.cursor;
    const batchSize: number = Math.min(request.data?.batchSize ?? 30, 50);

    // 3 mois en arrière — created_at en microsecondes côté Flutter
    const threeMonthsAgoMs = Date.now() - 90 * 24 * 60 * 60 * 1000;
    const threeMonthsAgoMicros = threeMonthsAgoMs * 1000;

    // Construction de la requête paginée
    // Simple query sur created_at uniquement — filtrage du type côté serveur
    // pour éviter index composite `type (in) + created_at (range + orderBy)`.
    let query = db.collection("Posts")
      .where("created_at", ">=", threeMonthsAgoMicros)
      .orderBy("created_at", "asc")
      .limit(batchSize * 3); // marge pour compenser le filtre type côté serveur

    if (cursor) {
      const cursorDoc = await db.collection("Posts").doc(cursor).get();
      if (cursorDoc.exists) query = query.startAfter(cursorDoc);
    }

    const snap = await query.get();
    if (snap.empty) {
      console.log("[feedMigration] Terminé — aucun post supplémentaire");
      return { done: true, processed: 0, nextCursor: null };
    }

    let processed = 0;
    let lastPostId = cursor ?? null;
    let batchProcessed = 0;

    for (const postDoc of snap.docs) {
      const post = postDoc.data();
      const postId = postDoc.id;
      // Filtrage du type côté serveur
      if (!ALLOWED_TYPES.includes(post.type)) { lastPostId = postId; continue; }
      if (batchProcessed >= batchSize) break;
      const creatorId: string | undefined = post.user_id;
      if (!creatorId) { lastPostId = postId; continue; }

      const createdAtMs = post.created_at
        ? Math.floor(post.created_at / 1000)
        : Date.now();

      // Récupérer les abonnés du créateur
      const creatorDoc = await db.collection("Users").doc(creatorId).get();
      if (!creatorDoc.exists) { lastPostId = postId; continue; }

      const followerIds: string[] = creatorDoc.data()?.userAbonnesIds ?? [];
      if (followerIds.length === 0) { lastPostId = postId; continue; }

      // Fan-out en batches
      for (let i = 0; i < followerIds.length; i += BATCH_FAN_OUT) {
        const chunk = followerIds.slice(i, i + BATCH_FAN_OUT);
        const batch = db.batch();
        for (const followerId of chunk) {
          const ref = db.collection("Users").doc(followerId);
          batch.set(ref, {
            unreadPosts: { [postId]: createdAtMs },
          }, { merge: true });
        }
        try {
          await batch.commit();
        } catch (err) {
          console.error(`[feedMigration] Fan-out post ${postId} lot ${i} échoué:`, err);
        }
      }

      processed++;
      batchProcessed++;
      lastPostId = postId;
      console.log(`[feedMigration] Post ${postId} → ${followerIds.length} abonnés mis à jour`);
    }

    const done = snap.docs.length < batchSize * 3 && batchProcessed < batchSize;
    console.log(`[feedMigration] Batch terminé: ${processed} posts, done=${done}, nextCursor=${lastPostId}`);

    return { done, processed, nextCursor: lastPostId };
  }
);
