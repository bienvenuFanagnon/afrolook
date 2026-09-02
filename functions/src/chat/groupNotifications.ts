import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { sendToOneSignal } from "../shared/notification_utils";

/**
 * Déclenché à chaque nouveau message dans GroupMessages.
 * Envoie des push notifications aux membres du groupe avec rate limiting côté récepteur.
 * Rate limit : max 3 pushs reçus par utilisateur toutes les 10 minutes (posts + messages confondus).
 * Stockage du rate limit : collection NotifRateLimit/{userId} { window_start, count }
 */

const RATE_LIMIT_COUNT = 3;
const RATE_LIMIT_WINDOW_MS = 10 * 60 * 1000; // 10 minutes
const APP_CONFIG_DOC = "XgkSxKc10vWsJJ2uBraT";

export const onGroupMessageCreated = onDocumentCreated(
  {
    document: "GroupMessages/{msgId}",
    timeoutSeconds: 300,
    memory: "512MiB",
    region: "us-central1",
  },
  async (event) => {
    const msg = event.data?.data();
    if (!msg) return;

    // Ne traiter que les messages valides non supprimés
    if (!msg.is_valide || msg.is_deleted) return;

    const groupId = msg.group_id as string | undefined;
    const senderId = msg.send_by as string | undefined;
    if (!groupId || !senderId) return;

    // Lire groupe, expéditeur et config app en parallèle
    const [groupDoc, senderDoc, appConfigDoc] = await Promise.all([
      db.collection("GroupChats").doc(groupId).get(),
      db.collection("Users").doc(senderId).get(),
      db.collection("AppData").doc(APP_CONFIG_DOC).get(),
    ]);

    if (!groupDoc.exists) return;
    const groupData = groupDoc.data()!;

    if (groupData.is_frozen) return;

    const appConfig = appConfigDoc.data();
    if (!appConfig?.one_signal_app_id || !appConfig?.one_signal_api_key) {
      console.warn("[onGroupMessageCreated] Config OneSignal manquante");
      return;
    }

    const senderData = senderDoc.data();
    const senderPseudo = (senderData?.pseudo as string) ?? "";
    const groupName = (groupData.name as string) ?? "";
    const groupImageUrl = (groupData.image_url as string) ?? "";

    // Vérifier si l'expéditeur est owner ou admin → afficher l'identité du groupe
    let memberRole = "member";
    try {
      const memberDoc = await db
        .collection("GroupChats")
        .doc(groupId)
        .collection("members")
        .doc(senderId)
        .get();
      if (memberDoc.exists) {
        memberRole = (memberDoc.data()?.role as string) ?? "member";
      }
    } catch (_) {}
    const isAdminOrOwner = memberRole === "owner" || memberRole === "admin";

    // Expéditeur affiché : groupe si admin/owner, personne sinon
    const displayName = isAdminOrOwner ? groupName : `@${senderPseudo}`;
    const displayImage = isAdminOrOwner
      ? groupImageUrl
      : ((senderData?.imageUrl as string) || (appConfig.app_logo as string) || "");

    // Construire le résumé du message pour la notification
    const msgType = (msg.message_type as string) ?? "text";
    let msgPreview: string;
    switch (msgType) {
      case "image":
        msgPreview = "📷 Photo";
        break;
      case "multi_image":
        msgPreview = "📷 Photos";
        break;
      case "video":
        msgPreview = "🎥 Vidéo";
        break;
      case "post":
        msgPreview = "📎 Partage";
        break;
      default:
        msgPreview = ((msg.message as string) ?? "").substring(0, 100);
    }
    const notifMessage = isAdminOrOwner
      ? `${displayName}: ${msgPreview}`
      : `${displayName} dans ${groupName}: ${msgPreview}`;

    // Membres à notifier (hors expéditeur, IDs valides uniquement)
    const memberIds = ((groupData.member_ids as string[]) ?? []).filter(
      (id) => id && id.trim() !== "" && id !== senderId
    );
    if (memberIds.length === 0) return;

    const now = Date.now();
    const allOneSignalIds: string[] = [];
    const rateLimitUpdates: Array<{ userId: string; reset: boolean }> = [];

    // Traitement par batches de 30 (limite whereIn Firestore)
    const USERS_BATCH_SIZE = 30;

    for (let i = 0; i < memberIds.length; i += USERS_BATCH_SIZE) {
      const batchIds = memberIds.slice(i, i + USERS_BATCH_SIZE);

      // Récupérer données utilisateurs et rate limits en parallèle
      const [usersSnap, rateLimitDocs] = await Promise.all([
        db.collection("Users").where("id", "in", batchIds).get(),
        Promise.all(
          batchIds.map((id) => db.collection("NotifRateLimit").doc(id).get())
        ),
      ]);

      // Construire map rate limit pour ce batch
      const rateLimitMap = new Map<string, { window_start: number; count: number }>();
      for (const doc of rateLimitDocs) {
        if (doc.exists) {
          rateLimitMap.set(doc.id, doc.data() as { window_start: number; count: number });
        }
      }

      for (const userDoc of usersSnap.docs) {
        const userData = userDoc.data();
        const userId = userDoc.id;

        // Vérifier si le groupe est muté par cet utilisateur
        const mutedGroups = (userData.muted_groups as string[]) ?? [];
        if (mutedGroups.includes(groupId)) continue;

        // Vérifier le rate limit
        const rateData = rateLimitMap.get(userId);
        const windowStart = rateData?.window_start ?? 0;
        const count = rateData?.count ?? 0;
        const windowExpired = now - windowStart >= RATE_LIMIT_WINDOW_MS;

        if (!windowExpired && count >= RATE_LIMIT_COUNT) {
          // Fenêtre active et limite atteinte — pas de push
          continue;
        }

        const oneSignalId = (userData.oneIgnalUserid as string) ?? "";
        if (oneSignalId.length > 5) {
          allOneSignalIds.push(oneSignalId);
          rateLimitUpdates.push({ userId, reset: windowExpired });
        }
      }

      // Pause légère entre batches pour les grands groupes
      if (i + USERS_BATCH_SIZE < memberIds.length) {
        await new Promise((resolve) => setTimeout(resolve, 50));
      }
    }

    if (allOneSignalIds.length === 0) {
      console.log(
        `[onGroupMessageCreated] groupId=${groupId} — aucun push (tous mutés ou rate limit atteint)`
      );
      return;
    }

    // Envoyer les pushs en batches de 2000 (limite OneSignal)
    const PUSH_BATCH_SIZE = 2000;
    for (let i = 0; i < allOneSignalIds.length; i += PUSH_BATCH_SIZE) {
      const pushBatch = allOneSignalIds.slice(i, i + PUSH_BATCH_SIZE);
      try {
        await sendToOneSignal(
          pushBatch,
          notifMessage,
          displayName,
          displayImage || (appConfig.app_logo as string) || "",
          appConfig.one_signal_app_id as string,
          appConfig.one_signal_api_key as string,
          {
            send_user_id: senderId,
            type_notif: "MESSAGE",
            post_id: (msg.post_id as string) ?? "",
            post_type: msgType === "post" ? "post" : "",
            chat_id: groupId,
          }
        );
        console.log(
          `[onGroupMessageCreated] Batch ${Math.floor(i / PUSH_BATCH_SIZE) + 1}: ${pushBatch.length} pushs envoyés`
        );
      } catch (e) {
        console.error(
          `[onGroupMessageCreated] Erreur OneSignal batch ${Math.floor(i / PUSH_BATCH_SIZE) + 1}:`,
          e
        );
      }
    }

    // Mettre à jour les rate limits (max 500 writes par batch Firestore)
    const WRITE_BATCH_SIZE = 500;
    for (let i = 0; i < rateLimitUpdates.length; i += WRITE_BATCH_SIZE) {
      const slice = rateLimitUpdates.slice(i, i + WRITE_BATCH_SIZE);
      const writeBatch = db.batch();
      for (const { userId, reset } of slice) {
        const ref = db.collection("NotifRateLimit").doc(userId);
        if (reset) {
          // Nouvelle fenêtre — reset le compteur
          writeBatch.set(ref, { window_start: now, count: 1 });
        } else {
          // Fenêtre active — incrémenter
          writeBatch.update(ref, { count: FieldValue.increment(1) });
        }
      }
      await writeBatch.commit();
    }

    console.log(
      `[onGroupMessageCreated] groupId=${groupId} type=${msgType} — ${allOneSignalIds.length} pushs envoyés, ${rateLimitUpdates.length} rate limits mis à jour`
    );
  }
);
