import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";

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
