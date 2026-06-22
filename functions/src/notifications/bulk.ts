import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db } from "../shared/firebase";
import { sendToOneSignal, getCanalImage } from "../shared/notification_utils";

// Interface pour les données
interface SendBulkNotificationData {
  senderId: string;
  message: string;
  typeNotif: string;
  postId?: string;
  postType?: string;
  chatId?: string;
  smallImage?: string;
  isChannel?: boolean;
  channelTitle?: string;
  canalId?: string;
  targetType: "all" | "subscribers" | "channel" | "specific";
  specificUserIds?: string[];
}

export const sendBulkNotification = onCall(
  {
    timeoutSeconds: 540,
    memory: "1GiB",
    region: "us-central1",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Utilisateur non authentifié");
    }

    try {
      const data = request.data as SendBulkNotificationData;
      const {
        senderId,
        message,
        typeNotif,
        postId,
        postType,
        chatId,
        smallImage,
        isChannel,
        channelTitle,
        canalId,
        targetType,
        specificUserIds,
      } = data;

      const senderDoc = await db.collection("Users").doc(senderId).get();
      if (!senderDoc.exists) {
        throw new HttpsError("not-found", "Expéditeur non trouvé");
      }
      const senderData = senderDoc.data();

      const appConfigDoc = await db.collection("AppData").doc("XgkSxKc10vWsJJ2uBraT").get();
      const appConfig = appConfigDoc.data();

      if (!appConfig?.one_signal_app_id || !appConfig?.one_signal_api_key) {
        throw new HttpsError("failed-precondition", "Configuration OneSignal manquante");
      }

      let targetUserIds: string[] = [];

      if (targetType === "all") {
        const usersSnapshot = await db.collection("Users").get();
        targetUserIds = usersSnapshot.docs.map(doc => doc.id);
      } else if (targetType === "subscribers") {
        targetUserIds = senderData?.userAbonnesIds || [];
      } else if (targetType === "channel" && canalId) {
        const canalDoc = await db.collection("Canals").doc(canalId).get();
        if (canalDoc.exists) {
          const canalData = canalDoc.data();
          targetUserIds = [
            ...(canalData?.usersSuiviId || []),
            ...(canalData?.subscribersId || []),
          ];
        }
      } else if (targetType === "specific" && specificUserIds) {
        targetUserIds = specificUserIds;
      }

      targetUserIds = [...new Set(targetUserIds)].filter(id => id !== senderId);

      if (targetUserIds.length === 0) {
        return {
          success: true,
          message: "Aucun utilisateur cible",
          processedCount: 0,
        };
      }

      console.log(`Traitement de ${targetUserIds.length} utilisateurs`);

      const appName = isChannel && channelTitle
        ? `#${channelTitle}`
        : `@${senderData?.pseudo}`;

      const currentTimeMicroseconds = Date.now() * 1000;

      const allOneSignalIds: string[] = [];
      const notificationsToSave: any[] = [];

      const FIRESTORE_BATCH_SIZE = 30;

      for (let i = 0; i < targetUserIds.length; i += FIRESTORE_BATCH_SIZE) {
        const batchIds = targetUserIds.slice(i, i + FIRESTORE_BATCH_SIZE);

        console.log(`Traitement lot ${i / FIRESTORE_BATCH_SIZE + 1}: ${batchIds.length} utilisateurs`);

        const usersBatch = await db.collection("Users")
          .where("id", "in", batchIds)
          .get();

        for (const userDoc of usersBatch.docs) {
          const userData = userDoc.data();

          const notifId = db.collection("Notifications").doc().id;

          let mediaUrl = smallImage || senderData?.imageUrl;
          if (isChannel && canalId) {
            const canalImage = await getCanalImage(canalId);
            if (canalImage) mediaUrl = canalImage;
          }

          notificationsToSave.push({
            id: notifId,
            titre: `${appName} a posté`,
            media_url: mediaUrl,
            type: typeNotif,
            description: isChannel
              ? `a posté: ${message.substring(0, 200)}`
              : `${appName} a posté: ${message.substring(0, 200)}`,
            user_id: senderId,
            receiver_id: userDoc.id,
            post_id: postId || "",
            post_data_type: postType || "",
            createdAt: currentTimeMicroseconds,
            updatedAt: currentTimeMicroseconds,
            status: "VALIDE",
            canal_id: isChannel ? canalId : null,
          });

          if (userData.oneIgnalUserid && userData.oneIgnalUserid.length > 5) {
            allOneSignalIds.push(userData.oneIgnalUserid);
          }
        }

        if (i + FIRESTORE_BATCH_SIZE < targetUserIds.length) {
          await new Promise(resolve => setTimeout(resolve, 100));
        }
      }

      console.log(`Sauvegarde de ${notificationsToSave.length} notifications dans Firebase`);

      const SAVE_BATCH_SIZE = 100;
      for (let i = 0; i < notificationsToSave.length; i += SAVE_BATCH_SIZE) {
        const batch = notificationsToSave.slice(i, i + SAVE_BATCH_SIZE);
        const savePromises = batch.map(notif =>
          db.collection("Notifications").doc(notif.id).set(notif)
        );
        await Promise.all(savePromises);
        console.log(`${Math.min(i + SAVE_BATCH_SIZE, notificationsToSave.length)}/${notificationsToSave.length} notifications sauvegardées`);
      }

      console.log(`${notificationsToSave.length} notifications enregistrées avec succès`);

      if (allOneSignalIds.length > 0) {
        console.log(`Envoi de push à ${allOneSignalIds.length} utilisateurs`);

        const PUSH_BATCH_SIZE = 2000;
        for (let i = 0; i < allOneSignalIds.length; i += PUSH_BATCH_SIZE) {
          const batchIds = allOneSignalIds.slice(i, i + PUSH_BATCH_SIZE);

          await sendToOneSignal(
            batchIds,
            message,
            appName,
            smallImage || senderData?.imageUrl || appConfig.app_logo,
            appConfig.one_signal_app_id,
            appConfig.one_signal_api_key,
            {
              send_user_id: senderId,
              type_notif: typeNotif,
              post_id: postId || "",
              post_type: postType || "",
              chat_id: chatId || "",
            }
          );

          console.log(`Lot ${i / PUSH_BATCH_SIZE + 1}: ${batchIds.length} push envoyées`);

          if (i + PUSH_BATCH_SIZE < allOneSignalIds.length) {
            await new Promise(resolve => setTimeout(resolve, 500));
          }
        }

        console.log(`Push notifications envoyées à ${allOneSignalIds.length} utilisateurs`);
      } else {
        console.log(`Aucune push notification envoyée (aucun ID OneSignal valide)`);
      }

      return {
        success: true,
        processedCount: targetUserIds.length,
        notificationsSaved: notificationsToSave.length,
        pushSent: allOneSignalIds.length,
      };

    } catch (error) {
      console.error("Erreur dans sendBulkNotification:", error);
      throw new HttpsError("internal", "Erreur lors de l'envoi des notifications", error);
    }
  }
);
