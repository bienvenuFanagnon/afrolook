import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db } from "../shared/firebase";
import { sendToOneSignal } from "../shared/notification_utils";

const PUSH_BATCH_SIZE = 2000;

/**
 * Callable : A reposte le post de B.
 * - Ajoute l'ID du post original dans unreadPosts de chaque abonné de A
 *   → les abonnés de A voient le post de B dans leur feed T1
 * - Envoie notifications Firestore + push OneSignal
 * - NE crée PAS de nouveau document Post
 *
 * Params : { postId: string }
 * Auth : A (le reposter)
 */
export const repostFanOut = onCall(
  { timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Auth requise");

    const reposterId = request.auth.uid;
    const { postId } = request.data ?? {};
    if (!postId) throw new HttpsError("invalid-argument", "postId requis");

    // Charger le post original (pour le contenu de la notif)
    const postSnap = await db.collection("Posts").doc(postId).get();
    if (!postSnap.exists) throw new HttpsError("not-found", "Post introuvable");

    // Charger le reposter
    const reposterSnap = await db.collection("Users").doc(reposterId).get();
    if (!reposterSnap.exists) return { ok: true, added: 0 };

    const reposterData = reposterSnap.data()!;
    const reposterPseudo: string = reposterData.pseudo ?? "Un créateur";
    const reposterImageUrl: string = reposterData.imageUrl ?? "";
    const followerIds: string[] = reposterData.userAbonnesIds ?? [];

    if (followerIds.length === 0) return { ok: true, added: 0 };

    // Config OneSignal
    let appConfig: { one_signal_app_id?: string; one_signal_api_key?: string; app_logo?: string } = {};
    try {
      const cfgDoc = await db.collection("config").doc("app").get();
      appConfig = cfgDoc.data() ?? {};
    } catch (_) {}

    const hasOneSignal = appConfig.one_signal_app_id && appConfig.one_signal_api_key;
    const nowMs = Date.now();
    const postDesc: string = (postSnap.data()?.description ?? "").substring(0, 100);
    const pushMessage = `@${reposterPseudo} a partagé un post`;

    const allOneSignalIds: string[] = [];
    const CHUNK = 30;

    for (let i = 0; i < followerIds.length; i += CHUNK) {
      const chunk = followerIds.slice(i, i + CHUNK);
      const usersSnap = await db.collection("Users").where("id", "in", chunk).get();

      const batch = db.batch();
      let count = 0;

      for (const userDoc of usersSnap.docs) {
        const userData = userDoc.data();

        // Déduplication : ne pas ajouter si le post est déjà dans unreadPosts
        const existingUnread: Record<string, unknown> = userData.unreadPosts ?? {};
        if (existingUnread[postId] !== undefined) continue;

        // Stocker un objet avec les métadonnées reposter au lieu d'un simple timestamp
        // → Flutter les lit pour injecter le bandeau "@pseudo a republié" dans T1
        batch.update(userDoc.ref, {
          [`unreadPosts.${postId}`]: {
            ts: nowMs,
            reposterUserId: reposterId,
            reposterPseudo,
            reposterImageUrl,
          },
        });
        count++;

        // Notification Firestore
        const notifRef = db.collection("Notifications").doc();
        batch.set(notifRef, {
          id: notifRef.id,
          titre: `@${reposterPseudo} a partagé`,
          description: postDesc || "A partagé un post",
          type: "REPOST",
          user_id: reposterId,
          receiver_id: userDoc.id,
          post_id: postId,
          post_data_type: postSnap.data()?.dataType ?? "",
          media_url: reposterImageUrl,
          post_thumbnail: postSnap.data()?.thumbnail ?? postSnap.data()?.url_media ?? "",
          is_open: false,
          users_id_view: [],
          status: "VALIDE",
          created_at: nowMs,
          updated_at: nowMs,
        });
        count++;

        if (userData.oneIgnalUserid && userData.oneIgnalUserid.length > 5) {
          allOneSignalIds.push(userData.oneIgnalUserid);
        }

        // Firestore batch max 500 ops
        if (count >= 480) {
          await batch.commit();
          count = 0;
        }
      }

      if (count > 0) await batch.commit();
    }

    // Push OneSignal
    if (hasOneSignal && allOneSignalIds.length > 0) {
      for (let i = 0; i < allOneSignalIds.length; i += PUSH_BATCH_SIZE) {
        const slice = allOneSignalIds.slice(i, i + PUSH_BATCH_SIZE);
        try {
          await sendToOneSignal(
            slice,
            pushMessage,
            `@${reposterPseudo}`,
            reposterImageUrl || appConfig.app_logo || "",
            appConfig.one_signal_app_id!,
            appConfig.one_signal_api_key!,
            {
              type_notif: "REPOST",
              post_id: postId,
              send_user_id: reposterId,
            }
          );
        } catch (e) {
          console.error("repostFanOut — OneSignal error:", e);
        }
      }
    }

    console.log(`repostFanOut — postId=${postId} distribué à ${followerIds.length} abonnés de ${reposterId}`);
    return { ok: true, added: followerIds.length };
  }
);

/**
 * Callable : quand un utilisateur s'abonne à un créateur ou un canal,
 * ajoute les 50 derniers posts dans unreadPosts du nouvel abonné.
 *
 * Params : { followedUserId?: string, followedCanalId?: string }
 */
export const backfillPostsOnFollow = onCall(
  { timeoutSeconds: 30 },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Auth requise");

    const followerId = request.auth.uid;
    const { followedUserId, followedCanalId } = request.data ?? {};

    if (!followedUserId && !followedCanalId) {
      throw new HttpsError("invalid-argument", "followedUserId ou followedCanalId requis");
    }

    const POSTS_LIMIT = 50;
    const nowMs = Date.now();
    const cutoffMicros = (nowMs - 90 * 86_400_000) * 1000;

    let query: FirebaseFirestore.Query;

    if (followedUserId) {
      query = db
        .collection("Posts")
        .where("user_id", "==", followedUserId)
        .where("created_at", ">=", cutoffMicros)
        .orderBy("created_at", "desc")
        .limit(POSTS_LIMIT);
    } else {
      query = db
        .collection("Posts")
        .where("canal_id", "==", followedCanalId)
        .where("created_at", ">=", cutoffMicros)
        .orderBy("created_at", "desc")
        .limit(POSTS_LIMIT);
    }

    const snap = await query.get();
    if (snap.empty) return { ok: true, added: 0 };

    const updates: Record<string, number> = {};
    for (const doc of snap.docs) {
      const createdAt = doc.data().created_at as number ?? (nowMs * 1000);
      const createdAtMs = createdAt > 1e12 ? Math.floor(createdAt / 1000) : createdAt;
      updates[`unreadPosts.${doc.id}`] = createdAtMs;
    }

    await db.collection("Users").doc(followerId).set(updates, { merge: true });

    console.log(`backfillPostsOnFollow — ${snap.size} posts ajoutés à ${followerId}`);
    return { ok: true, added: snap.size };
  }
);
