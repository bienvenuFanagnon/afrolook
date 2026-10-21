import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { deliverPush } from "../shared/push";
import { previewForContent, safeChatImage } from "../shared/preview";

/**
 * Déclenché à chaque nouveau message dans GroupMessages (message, photo, vidéo, post ou lien partagé).
 * Envoie une notification aux membres du groupe par le système commun (FCM, sinon OneSignal), au format des messageries :
 * titre = nom du groupe, texte = « @pseudo : début du message » (un administrateur ou le propriétaire s'exprime au nom du groupe : texte seul).
 * Un message est toujours notifié (catégorie « direct »), sauf si la personne a mis le groupe en sourdine.
 * Limite côté récepteur : 3 notifications au plus par 10 minutes (messages de groupe et posts confondus).
 * Stockage de la limite : collection NotifRateLimit/{userId} { window_start, count }
 */

const RATE_LIMIT_COUNT = 3;
const RATE_LIMIT_WINDOW_MS = 10 * 60 * 1000; // 10 minutes
const APP_CONFIG_DOC = "XgkSxKc10vWsJJ2uBraT";

const cut = (s: unknown, n: number): string => Array.from(String(s ?? "").replace(/\s+/g, " ").trim()).slice(0, n).join("");

/** Texte et aperçu d'un message de groupe pour la notification. */
export function groupPushContent(msg: Record<string, unknown>): { preview: string; image: string } {
  const type = String(msg["message_type"] ?? "text");
  switch (type) {
    case "image": return { preview: "📷 Photo", image: safeChatImage(msg["message"]) };
    case "multi_image": {
      const urls = Array.isArray(msg["image_urls"]) ? (msg["image_urls"] as unknown[]) : [];
      return { preview: "📷 Photos", image: safeChatImage(urls[0] ?? msg["message"]) };
    }
    case "video": return { preview: "🎥 Vidéo", image: "" };
    case "post": return { preview: msg["message"] ? `📎 ${cut(msg["message"], 90)}` : "📎 Post partagé", image: "" }; // l'aperçu du post vient de post_id
    case "link_share": return { preview: `📎 ${cut(msg["item_title"] ?? msg["message"], 90) || "Lien partagé"}`, image: safeChatImage(msg["item_thumbnail"]) };
    default: return { preview: cut(msg["message"], 100), image: "" };
  }
}

/** Titre et texte affichés : l'identité du groupe pour un administrateur ou le propriétaire, « @pseudo : … » pour un membre. */
export function groupPushText(groupName: string, senderPseudo: string, isAdminOrOwner: boolean, preview: string): { title: string; message: string } {
  return { title: groupName || "Afrolook", message: isAdminOrOwner ? preview : `@${senderPseudo} : ${preview}` };
}

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

    const appLogo = (appConfigDoc.data()?.app_logo as string) ?? "";
    const senderData = senderDoc.data();
    const senderPseudo = (senderData?.pseudo as string) ?? "";
    const groupName = (groupData.name as string) ?? "";
    const groupImageUrl = (groupData.image_url as string) ?? "";

    // Vérifier si l'expéditeur est owner ou admin → afficher l'identité du groupe
    let memberRole = "member";
    try {
      const memberDoc = await db.collection("GroupChats").doc(groupId).collection("members").doc(senderId).get();
      if (memberDoc.exists) memberRole = (memberDoc.data()?.role as string) ?? "member";
    } catch (_) {}
    const isAdminOrOwner = memberRole === "owner" || memberRole === "admin";

    const msgType = (msg.message_type as string) ?? "text";
    const content = groupPushContent(msg);
    const text = groupPushText(groupName, senderPseudo, isAdminOrOwner, content.preview);
    // Un post partagé montre l'aperçu du post ; sinon la photo envoyée, le cas échéant
    const postId = (msg.post_id as string) ?? "";
    const image = msgType === "post" && postId ? await previewForContent(postId, "post") : content.image;
    const avatar = isAdminOrOwner ? groupImageUrl : ((senderData?.imageUrl as string) || appLogo);

    // Membres à notifier (hors expéditeur, IDs valides uniquement)
    const memberIds = ((groupData.member_ids as string[]) ?? []).filter((id) => id && id.trim() !== "" && id !== senderId);
    if (memberIds.length === 0) return;

    const now = Date.now();
    const recipients: string[] = [];
    const rateLimitUpdates: Array<{ userId: string; reset: boolean }> = [];

    // Traitement par lots de 30
    const USERS_BATCH_SIZE = 30;

    for (let i = 0; i < memberIds.length; i += USERS_BATCH_SIZE) {
      const batchIds = memberIds.slice(i, i + USERS_BATCH_SIZE);

      // Groupes mis en sourdine et limites de ces personnes, en parallèle
      const [usersSnap, rateLimitDocs] = await Promise.all([
        db.getAll(...batchIds.map((id) => db.collection("Users").doc(id)), { fieldMask: ["muted_groups"] }),
        Promise.all(batchIds.map((id) => db.collection("NotifRateLimit").doc(id).get())),
      ]);

      const rateLimitMap = new Map<string, { window_start: number; count: number }>();
      for (const doc of rateLimitDocs) if (doc.exists) rateLimitMap.set(doc.id, doc.data() as { window_start: number; count: number });

      for (const userDoc of usersSnap) {
        if (!userDoc.exists) continue;
        const userId = userDoc.id;

        // Groupe mis en sourdine par cette personne
        const mutedGroups = (userDoc.data()?.muted_groups as string[]) ?? [];
        if (mutedGroups.includes(groupId)) continue;

        // Limite de notifications
        const rateData = rateLimitMap.get(userId);
        const windowStart = rateData?.window_start ?? 0;
        const count = rateData?.count ?? 0;
        const windowExpired = now - windowStart >= RATE_LIMIT_WINDOW_MS;
        if (!windowExpired && count >= RATE_LIMIT_COUNT) continue;

        recipients.push(userId);
        rateLimitUpdates.push({ userId, reset: windowExpired });
      }

      // Pause légère entre lots pour les grands groupes
      if (i + USERS_BATCH_SIZE < memberIds.length) await new Promise((resolve) => setTimeout(resolve, 50));
    }

    if (recipients.length === 0) {
      console.log(`[onGroupMessageCreated] groupId=${groupId} — aucun push (tous mutés ou limite atteinte)`);
      return;
    }

    // Envoi par le système commun : FCM pour les appareils à jour, OneSignal en repli
    const PUSH_BATCH_SIZE = 500;
    for (let i = 0; i < recipients.length; i += PUSH_BATCH_SIZE) {
      const batch = recipients.slice(i, i + PUSH_BATCH_SIZE);
      try {
        const r = await deliverPush(
          batch.map((userId) => ({ userId })),
          {
            title: text.title, message: text.message, image: image || undefined, avatar,
            data: { send_user_id: senderId, type_notif: "MESSAGE", post_id: postId, post_type: msgType === "post" ? "post" : "", chat_id: groupId },
          },
          undefined, false, "direct",
        );
        console.log(`[onGroupMessageCreated] lot ${Math.floor(i / PUSH_BATCH_SIZE) + 1} : ${r.fcm} FCM, ${r.oneSignal} OneSignal, ${r.unreachable} injoignable(s)`);
      } catch (e) {
        console.error(`[onGroupMessageCreated] erreur d'envoi, lot ${Math.floor(i / PUSH_BATCH_SIZE) + 1}`, e);
      }
    }

    // Mettre à jour les limites (500 écritures au plus par lot Firestore)
    const WRITE_BATCH_SIZE = 500;
    for (let i = 0; i < rateLimitUpdates.length; i += WRITE_BATCH_SIZE) {
      const writeBatch = db.batch();
      for (const { userId, reset } of rateLimitUpdates.slice(i, i + WRITE_BATCH_SIZE)) {
        const ref = db.collection("NotifRateLimit").doc(userId);
        if (reset) writeBatch.set(ref, { window_start: now, count: 1 });
        else writeBatch.update(ref, { count: FieldValue.increment(1) });
      }
      await writeBatch.commit();
    }

    console.log(`[onGroupMessageCreated] groupId=${groupId} type=${msgType} — ${recipients.length} destinataire(s)`);
  }
);
