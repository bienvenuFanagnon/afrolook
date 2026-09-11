import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { checkEmailRateLimit, generateInteractionEmailHTML } from "../shared/email_utils";
import { EMAIL_FROM, APP_DOMAIN, PLAY_STORE_URL } from "../shared/config";

/**
 * Génère le HTML pour les nouveaux posts (abonnements)
 */
function generateNewPostEmailHTML({ posterName, posterImage, postDescription, postImage, postId }: any): string {
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
    </head>
    <body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f5f5;">
      <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color: #f5f5f5; padding: 20px;">
        <tr>
          <td align="center">
            <table width="500" cellpadding="0" cellspacing="0" border="0" style="background-color: #ffffff; border-radius: 10px; overflow: hidden; box-shadow: 0 4px 10px rgba(0,0,0,0.1);">

              <tr>
                <td style="background: linear-gradient(135deg, #000000 0%, #1a1a1a 100%); padding: 30px 20px; text-align: center;">
                  <img src="https://play-lh.googleusercontent.com/g5_LdDrb8s5Kvw0-dFc8o8RgFLHUxLlsG0yd-DXXzceX9qPrYwZvfHQ2M2jTFqxnEBUo=w240-h480-rw" alt="Afrolook Media" style="width: 100px; border-radius: 15px;">
                  <h2 style="color: #FFD700; margin: 20px 0 0 0; font-size: 24px;">📢 Nouveau contenu !</h2>
                </td>
              </tr>

              <tr>
                <td style="padding: 30px;">
                  <table width="100%" cellpadding="0" cellspacing="0">
                    <tr>
                      <td width="70" valign="top">
                        <img src="${posterImage || "https://play-lh.googleusercontent.com/g5_LdDrb8s5Kvw0-dFc8o8RgFLHUxLlsG0yd-DXXzceX9qPrYwZvfHQ2M2jTFqxnEBUo=w240-h480-rw"}"
                             style="width: 60px; height: 60px; border-radius: 50%; object-fit: cover; border: 2px solid #FFD700;">
                      </td>
                      <td valign="top">
                        <p style="color: #333333; font-size: 18px; margin: 0;">
                          <strong>${posterName}</strong>
                        </p>
                        <p style="color: #666666; font-size: 15px; margin: 5px 0 0 0;">
                          vient de publier :
                        </p>
                      </td>
                    </tr>
                  </table>

                  <div style="margin-top: 20px; padding: 15px; background-color: #f9f9f9; border-radius: 10px;">
                    <p style="color: #444444; font-size: 16px; font-style: italic; margin: 0;">
                      "${postDescription}"
                    </p>
                  </div>

                  ${postImage ? `
                  <div style="margin-top: 20px; text-align: center;">
                    <img src="${postImage}" style="max-width: 100%; max-height: 250px; border-radius: 10px; box-shadow: 0 3px 10px rgba(0,0,0,0.1);">
                  </div>
                  ` : ""}

                  <div style="text-align: center; margin-top: 30px;">
                    <a href="https://afrolooki.web.app/post/${postId}"
                       style="background-color: #FFD700; color: #000000; padding: 14px 35px;
                              text-decoration: none; border-radius: 30px; font-weight: bold;
                              display: inline-block; font-size: 16px;">
                      Voir la publication →
                    </a>
                  </div>

                  <p style="color: #999999; font-size: 13px; text-align: center; margin-top: 20px;">
                    <a href="${PLAY_STORE_URL}" style="color: #FFD700;">Téléchargez l'application</a> pour ne rien manquer
                  </p>
                </td>
              </tr>

              <tr>
                <td style="background-color: #f8f8f8; padding: 20px; text-align: center; border-top: 1px solid #eeeeee;">
                  <p style="color: #999999; font-size: 12px; margin: 0;">
                    Afrolook Media - contact@afrolookmedia.com<br>
                    <a href="https://${APP_DOMAIN}/unsubscribe" style="color: #FFD700; text-decoration: none;">Gérer mes notifications</a>
                  </p>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </body>
    </html>
  `;
}

/**
 * Fonction déclenchée lors d'une interaction sur un post
 */
export const onPostInteraction = onDocumentCreated(
  {
    document: "interactions/{interactionId}",
    timeoutSeconds: 60,
  },
  async (event) => {
    const interaction = event.data?.data();
    if (!interaction) return;

    try {
      const { postId, userId, type, comment } = interaction;

      // Ne pas notifier une auto-interaction
      if (!postId || !userId || !type) return;

      const postDoc = await db.collection("Posts").doc(postId).get();
      if (!postDoc.exists) return;

      const postData = postDoc.data();
      const postOwnerId = postData?.user_id;

      // Pas de notif si l'utilisateur interagit avec son propre post
      if (postOwnerId === userId) return;

      const [interactorDoc, postOwnerDoc] = await Promise.all([
        db.collection("Users").doc(userId).get(),
        db.collection("Users").doc(postOwnerId).get(),
      ]);

      const interactorData = interactorDoc.data();
      const postOwnerData = postOwnerDoc.data();
      const interactorName = interactorData?.pseudo || "Un utilisateur";

      // ── Sauvegarde NotificationData dans Firestore (pour WorkManager + onglet notifs) ──
      let notifType = "";
      let notifTitre = "";
      let notifDescription = "";

      switch (type) {
        case "like":
          notifType = "LIKE";
          notifTitre = `${interactorName} a aimé votre publication`;
          notifDescription = `${interactorName} a aimé votre publication`;
          break;
        case "love":
          notifType = "LIKE";
          notifTitre = `${interactorName} adore votre publication`;
          notifDescription = `${interactorName} adore votre publication`;
          break;
        case "comment":
          notifType = "COMMENT";
          notifTitre = `${interactorName} a commenté`;
          notifDescription = comment?.substring(0, 200) || "A commenté votre publication";
          break;
        case "share":
          notifType = "SHARE";
          notifTitre = `${interactorName} a partagé`;
          notifDescription = `${interactorName} a partagé votre publication`;
          break;
        default:
          return;
      }

      const nowMs = Date.now();
      const notifId = db.collection("Notifications").doc().id;
      await db.collection("Notifications").doc(notifId).set({
        id: notifId,
        titre: notifTitre,
        description: notifDescription,
        type: notifType,
        user_id: userId,
        receiver_id: postOwnerId,
        post_id: postId,
        post_data_type: postData?.dataType || "",
        media_url: interactorData?.imageUrl || "",
        post_thumbnail: postData?.thumbnail || postData?.url_media || "",
        is_open: false,
        users_id_view: [],
        status: "VALIDE",
        created_at: nowMs,
        updated_at: nowMs,
        createdAt: nowMs,
        updatedAt: nowMs,
      });

      // ── Recalcul postScore en temps réel ─────────────────────────────────
      // On utilise les compteurs actuels du post + la correction pour l'action courante.
      // Les compteurs côté client sont parfois mis à jour avant/après le trigger,
      // donc on ajoute +1 manuellement pour l'action qui vient de se produire.
      try {
        const likes   = ((postData?.likes   ?? 0) as number) + (type === "like"    ? 1 : 0);
        const loves   = ((postData?.loves   ?? 0) as number);
        const comments = ((postData?.comments ?? 0) as number) + (type === "comment" ? 1 : 0);
        const createdAt = (postData?.created_at ?? Date.now()) as number;
        const ageDays = (Date.now() - createdAt) / 86_400_000;
        const raw = likes * 1 + loves * 2 + comments * 3;
        const score = Math.round((raw / Math.pow(ageDays + 2, 1.5)) * 100) / 100;
        await db.collection("Posts").doc(postId).update({
          rawScore: raw,
          postScore: score,
        });
      } catch (scoreErr) {
        console.error("[scoreEngine] Recalcul postScore échoué:", scoreErr);
      }

      // ── Email (uniquement si l'utilisateur n'a pas désactivé les emails) ──
      const emailNotifications = postOwnerData?.emailNotifications;
      if (!emailNotifications || emailNotifications.interactions === false) {
        // Pas d'email, mais la notif Firestore est déjà sauvegardée
        return;
      }
      if (!postOwnerData?.email) return;

      const canSend = await checkEmailRateLimit(postOwnerId);
      if (!canSend) return;

      let subject = "";
      let message = "";

      switch (type) {
        case "like":
          subject = `${interactorName} a aimé votre publication`;
          message = `${interactorName} a aimé votre publication "${postData?.description?.substring(0, 50)}..." sur Afrolook Media.`;
          break;
        case "comment":
          subject = `${interactorName} a commenté votre publication`;
          message = `${interactorName} a commenté votre publication :<br><br>
                    <em style="background-color: #f0f0f0; padding: 10px; border-radius: 5px; display: block;">${comment || "Voir le commentaire"}</em>`;
          break;
        case "share":
          subject = `${interactorName} a partagé votre publication`;
          message = `${interactorName} a partagé votre publication "${postData?.description?.substring(0, 50)}..."`;
          break;
        default:
          return;
      }

      await db.collection("mail").add({
        to: [postOwnerData.email],
        message: {
          subject: subject,
          html: generateInteractionEmailHTML({
            subject,
            message,
            interactorName,
            interactorImage: interactorData?.imageUrl,
            postImage: postData?.images?.[0],
            postId,
            type,
          }),
          from: EMAIL_FROM,
          replyTo: EMAIL_FROM,
        },
        headers: {
          "X-Mailer": "Afrolook Media",
          "List-Unsubscribe": `<https://${APP_DOMAIN}/unsubscribe?email=${encodeURIComponent(postOwnerData.email)}>`,
        },
        createdAt: FieldValue.serverTimestamp(),
        userId: postOwnerId,
        type: "interaction",
      });

      console.log(`Email d'interaction envoyé à ${postOwnerData.email}`);

    } catch (error) {
      console.error("Erreur onPostInteraction:", error);
    }
  }
);

/**
 * Notifier par email lors d'un nouveau post d'un abonnement
 */
export const onNewPostFromSubscription = onDocumentCreated(
  {
    document: "Posts/{postId}",
    timeoutSeconds: 60,
  },
  async (event) => {
    const post = event.data?.data();
    if (!post) return;

    try {
      const postOwnerId = post.userId;

      const subscribersSnapshot = await db.collection("Users")
        .where("userAbonnesIds", "array-contains", postOwnerId)
        .get();

      if (subscribersSnapshot.empty) return;

      const postOwnerDoc = await db.collection("Users").doc(postOwnerId).get();
      const postOwnerData = postOwnerDoc.data();
      const posterName = postOwnerData?.pseudo || "Un créateur";

      const subscribers = subscribersSnapshot.docs.filter(doc => {
        const notifs = doc.data().emailNotifications;
        return !notifs || notifs.newPosts !== false;
      });

      if (subscribers.length === 0) return;

      const emailBatch = db.batch();
      const emailCollection = db.collection("mail");
      let emailCount = 0;

      for (const subscriberDoc of subscribers) {
        const subscriberData = subscriberDoc.data();
        if (!subscriberData.email) continue;

        const canSend = await checkEmailRateLimit(subscriberDoc.id);
        if (!canSend) continue;

        const emailDocRef = emailCollection.doc();
        emailBatch.set(emailDocRef, {
          to: [subscriberData.email],
          message: {
            subject: `${posterName} a publié un nouveau contenu sur Afrolook Media`,
            html: generateNewPostEmailHTML({
              posterName,
              posterImage: postOwnerData?.imageUrl,
              postDescription: post.description || "Nouveau contenu",
              postImage: post.images?.[0],
              postId: event.params.postId,
            }),
            from: EMAIL_FROM,
            replyTo: EMAIL_FROM,
          },
          headers: {
            "X-Mailer": "Afrolook Media",
            "List-Unsubscribe": `<https://${APP_DOMAIN}/unsubscribe?email=${encodeURIComponent(subscriberData.email)}>`,
          },
          createdAt: FieldValue.serverTimestamp(),
          userId: subscriberDoc.id,
          type: "new_post",
        });
        emailCount++;
      }

      if (emailCount > 0) {
        await emailBatch.commit();
        console.log(`${emailCount} emails de nouveau post envoyés`);
      }

    } catch (error) {
      console.error("Erreur onNewPostFromSubscription:", error);
    }
  }
);
