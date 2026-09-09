import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";

/**
 * Firestore trigger : quand un post est créé,
 * - incrémente newPostsByCreator {creatorId: count} sur chaque abonné au créateur
 * - ajoute {postId: createdAtMs} dans unreadPosts sur chaque abonné
 *   (map timestampé pour le Tier 1 du feed algorithmique)
 * - si le post appartient à un canal, incrémente aussi newPostsByCanal {canalId: count}
 *   sur chaque abonné du canal (usersSuiviId)
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

    const canalId = post.canal_id as string | undefined;

    const BATCH_SIZE = 400;

    // ── Fan-out vers les abonnés du créateur ──────────────────────────────
    const creatorDoc = await db.collection("Users").doc(creatorId).get();
    if (creatorDoc.exists) {
      const followerIds: string[] = creatorDoc.data()?.userAbonnesIds ?? [];
      if (followerIds.length > 0) {
        console.log(`Post ${postId} de ${creatorId} — fan-out créateur vers ${followerIds.length} abonnés`);
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
            console.log(`Créateur lot ${Math.floor(i / BATCH_SIZE) + 1} commité (${chunk.length})`);
          } catch (err) {
            console.error(`Créateur lot ${Math.floor(i / BATCH_SIZE) + 1} échoué :`, err);
          }
        }
      }
    }

    // ── Fan-out vers les abonnés du canal (si post dans un canal) ─────────
    if (canalId && canalId.trim() !== "") {
      const canalDoc = await db.collection("Canaux").doc(canalId).get();
      if (canalDoc.exists) {
        const canalFollowerIds: string[] = canalDoc.data()?.usersSuiviId ?? [];
        if (canalFollowerIds.length > 0) {
          console.log(`Post canal ${postId} — fan-out canal ${canalId} vers ${canalFollowerIds.length} abonnés`);
          for (let i = 0; i < canalFollowerIds.length; i += BATCH_SIZE) {
            const chunk = canalFollowerIds.slice(i, i + BATCH_SIZE);
            const batch = db.batch();
            for (const followerId of chunk) {
              const ref = db.collection("Users").doc(followerId);
              batch.set(ref, {
                newPostsByCanal: { [canalId]: FieldValue.increment(1) },
              }, { merge: true });
            }
            try {
              await batch.commit();
              console.log(`Canal lot ${Math.floor(i / BATCH_SIZE) + 1} commité (${chunk.length})`);
            } catch (err) {
              console.error(`Canal lot ${Math.floor(i / BATCH_SIZE) + 1} échoué :`, err);
            }
          }
        }
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
    if (!post) return;

    // Initialiser postScore et rawScore à 0 sur tous les nouveaux posts.
    // Le CRON les recalculera à la prochaine exécution (6h).
    // Sans ça, le champ est absent et l'app affiche rien au lieu de 0.
    const initUpdates: Record<string, unknown> = {
      postScore: FieldValue.increment(0),
      rawScore: FieldValue.increment(0),
    };

    if (post.statut === "PENDING") {
      const isValid = post.dataType && ["IMAGE", "VIDEO", "AUDIO", "TEXT"].includes(post.dataType);
      initUpdates.statut = isValid ? "VALIDE" : "NONVALIDE";
      initUpdates.moderatedAt = FieldValue.serverTimestamp();
    }

    await event.data!.ref.update(initUpdates);

    // Mettre à jour lastPostAt sur le créateur pour le calcul d'activité hebdomadaire
    const uid = post.user_id as string | undefined;
    if (uid) {
      await db.collection("Users").doc(uid).update({
        lastPostAt: FieldValue.serverTimestamp(),
      }).catch(() => {/* utilisateur introuvable — ignorer */});
    }
  }
);

/**
 * Callable admin : backfill unreadPosts pour les N derniers jours.
 * Parcourt tous les posts récents, pour chaque post écrit {postId: timestamp}
 * dans unreadPosts de chaque abonné du créateur.
 * Appelable une seule fois pour réinitialiser le Tier 1.
 */
export const backfillUnreadPosts = onCall(
  { timeoutSeconds: 540, memory: "512MiB" },
  async (request) => {
    const ADMIN_UIDS = ["gXEe76s0hQZqBhWph3n2jDUqi8f2"]; // kfanagnon uid
    if (!request.auth || !ADMIN_UIDS.includes(request.auth.uid)) {
      throw new HttpsError("permission-denied", "Réservé à l'admin");
    }

    const daysBack: number = request.data?.daysBack ?? 40;
    const cutoffMs = Date.now() - daysBack * 24 * 60 * 60 * 1000;
    // Flutter stocke created_at en microsecondes
    const cutoffMicros = cutoffMs * 1000;

    const allowedTypes = ["POST", "CHRONIQUE", "CHALLENGE", "CHALLENGEPARTICIPATION"];
    const BATCH_SIZE = 400;

    console.log(`🔄 Backfill unreadPosts — ${daysBack} derniers jours (cutoff: ${new Date(cutoffMs).toISOString()})`);

    // Charger tous les posts récents
    const postsSnap = await db.collection("Posts")
      .where("created_at", ">=", cutoffMicros)
      .orderBy("created_at", "desc")
      .get();

    const posts = postsSnap.docs.filter(d => allowedTypes.includes(d.data().type ?? d.data().dataType));
    console.log(`📦 ${posts.length} posts à traiter`);

    let totalWrites = 0;
    let errors = 0;

    // Cache créateurs déjà chargés pour éviter les lectures répétées
    const creatorFollowersCache: Record<string, string[]> = {};

    for (const postDoc of posts) {
      const post = postDoc.data();
      const postId = postDoc.id;
      const creatorId: string = post.user_id ?? "";
      if (!creatorId) continue;

      const createdAtMs = post.created_at
        ? Math.floor(post.created_at / 1000)
        : cutoffMs;

      // Charger les abonnés du créateur (avec cache)
      if (!(creatorId in creatorFollowersCache)) {
        try {
          const creatorDoc = await db.collection("Users").doc(creatorId).get();
          creatorFollowersCache[creatorId] = creatorDoc.data()?.userAbonnesIds ?? [];
        } catch {
          creatorFollowersCache[creatorId] = [];
        }
      }
      const followerIds = creatorFollowersCache[creatorId];
      if (followerIds.length === 0) continue;

      // Fan-out en batches de 400
      for (let i = 0; i < followerIds.length; i += BATCH_SIZE) {
        const chunk = followerIds.slice(i, i + BATCH_SIZE);
        const batch = db.batch();
        for (const followerId of chunk) {
          batch.set(
            db.collection("Users").doc(followerId),
            { unreadPosts: { [postId]: createdAtMs } },
            { merge: true }
          );
        }
        try {
          await batch.commit();
          totalWrites += chunk.length;
        } catch (err) {
          console.error(`❌ Lot échoué (post ${postId}) :`, err);
          errors++;
        }
      }
    }

    const result = {
      ok: true,
      postsProcessed: posts.length,
      totalWrites,
      errors,
    };
    console.log(`✅ Backfill terminé :`, result);
    return result;
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
