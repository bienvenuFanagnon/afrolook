import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { sendToOneSignal } from "../shared/notification_utils";
import { cleanReply, dayKey, decideReply, REPLY_PER_DAY } from "./replyGate";

/**
 * Réponse privée à une chronique.
 * - déjà amis : l'application ouvre la discussion (rien n'est créé ici) ;
 * - sinon : une invitation est créée avec le message de la personne et la chronique concernée ; la discussion n'existe qu'après acceptation.
 */
async function sendPush(receiverId: string, senderId: string, senderPseudo: string, senderImage: string, message: string, chatId = "") {
  try {
    const [cfg, user] = await Promise.all([db.collection("config").doc("app").get(), db.collection("Users").doc(receiverId).get()]);
    const c = cfg.data() ?? {};
    const playerId = user.data()?.["oneIgnalUserid"];
    if (!c["one_signal_app_id"] || !c["one_signal_api_key"] || !playerId) return;
    await sendToOneSignal([String(playerId)], message, `@${senderPseudo}`, senderImage, String(c["one_signal_app_id"]), String(c["one_signal_api_key"]), {
      send_user_id: senderId, recever_user_id: receiverId, type_notif: "INVITATION", post_id: "", post_type: "", chat_id: chatId,
    });
  } catch (e) {
    console.error("[chroniqueReply] push", e);
  }
}

export const chroniqueReplyInvite = onCall({ timeoutSeconds: 30, memory: "256MiB", maxInstances: 20 }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Connecte-toi pour répondre.");
  const data = (request.data ?? {}) as { chroniqueId?: string; message?: string };
  const chroniqueId = String(data.chroniqueId ?? "");
  const text = cleanReply(data.message);
  if (!/^[A-Za-z0-9_-]{6,40}$/.test(chroniqueId)) throw new HttpsError("invalid-argument", "Chronique invalide.");
  if (!text) throw new HttpsError("invalid-argument", "Écris un message de 1 à 200 caractères.");

  const chSnap = await db.collection("chroniques").doc(chroniqueId).get();
  if (!chSnap.exists) throw new HttpsError("not-found", "Cette chronique n'existe plus.");
  const ch = chSnap.data()!;
  const receiverId = String(ch["userId"] ?? "");
  if (!receiverId || receiverId === uid) throw new HttpsError("failed-precondition", "Tu ne peux pas te répondre à toi-même.");
  const now = Date.now();
  const expires = ch["expiresAt"]?.toMillis?.() ?? 0;
  if (expires && expires < now) throw new HttpsError("failed-precondition", "Cette chronique a expiré.");

  const inv = db.collection("Invitations");
  const [b1, b2, f1, f2, out, inc, refused, limit] = await Promise.all([
    db.collection("BlockedUsers").doc(`${receiverId}_${uid}`).get(),
    db.collection("BlockedUsers").doc(`${uid}_${receiverId}`).get(),
    db.collection("Friends").where("currentUserId", "==", uid).where("friendId", "==", receiverId).limit(1).get(),
    db.collection("Friends").where("currentUserId", "==", receiverId).where("friendId", "==", uid).limit(1).get(),
    inv.where("sender_id", "==", uid).where("receiver_id", "==", receiverId).where("status", "==", "ENCOURS").limit(1).get(),
    inv.where("sender_id", "==", receiverId).where("receiver_id", "==", uid).where("status", "==", "ENCOURS").limit(1).get(),
    inv.where("sender_id", "==", uid).where("receiver_id", "==", receiverId).where("status", "==", "REFUSER").get(),
    db.collection("ChroniqueInviteLimits").doc(`${uid}_${dayKey(now)}`).get(),
  ]);
  const lastRefusedAt = refused.docs.reduce((m, d) => Math.max(m, Number(d.get("updated_at") ?? 0)), 0);
  const decision = decideReply({
    isFriend: !f1.empty || !f2.empty,
    pendingOut: !out.empty,
    pendingIn: !inc.empty,
    lastRefusedAt,
    sentToday: Number(limit.get("n") ?? 0),
    blocked: b1.exists || b2.exists,
    now,
  });
  switch (decision.kind) {
    case "friends": return { status: "friends" };
    case "pending": return { status: "pending" };
    case "incoming": return { status: "incoming" };
    case "blocked": throw new HttpsError("permission-denied", "Cette personne n'accepte pas les messages.");
    case "cooldown": throw new HttpsError("resource-exhausted", `Invitation refusée récemment. Réessaie dans ${decision.daysLeft} jour${decision.daysLeft > 1 ? "s" : ""}.`, { daysLeft: decision.daysLeft });
    case "limit": throw new HttpsError("resource-exhausted", `Limite de ${REPLY_PER_DAY} invitations par jour atteinte. Reviens demain.`);
    case "send": break;
  }

  // Quota du jour (transaction : deux envois simultanés ne dépassent pas la limite)
  const limRef = db.collection("ChroniqueInviteLimits").doc(`${uid}_${dayKey(now)}`);
  await db.runTransaction(async (tx) => {
    const l = await tx.get(limRef);
    const n = Number(l.get("n") ?? 0);
    if (n >= REPLY_PER_DAY) throw new HttpsError("resource-exhausted", `Limite de ${REPLY_PER_DAY} invitations par jour atteinte. Reviens demain.`);
    tx.set(limRef, { uid, n: n + 1, day: dayKey(now), updatedAt: now }, { merge: true });
  });

  const me = (await db.collection("Users").doc(uid).get()).data() ?? {};
  const type = String(ch["type"] ?? "");
  const thumb = String(ch["posterUrl"] ?? "") || (type.endsWith("IMAGE") ? String(ch["mediaUrl"] ?? "") : String(ch["coverImageUrl"] ?? ""));
  const ref = inv.doc();
  const chat = await openRequestChat(uid, receiverId, ref.id, text, chroniqueId, thumb, now);
  await ref.set({
    id: ref.id, sender_id: uid, receiver_id: receiverId, status: "ENCOURS", message: text, created_at: now, updated_at: now,
    chronique_id: chroniqueId, chronique_thumb: thumb, chronique_type: type, chat_id: chat.chatId,
  });
  await sendPush(receiverId, uid, String(me["pseudo"] ?? "Quelqu'un"), String(me["imageUrl"] ?? ""), `@${me["pseudo"] ?? "Quelqu'un"} vous écrit depuis votre chronique`, chat.chatId);
  return { status: "sent", invitationId: ref.id, chatId: chat.chatId };
});

/**
 * Discussion temporaire (comme les demandes de message de TikTok) : elle existe dès l'envoi avec la chronique citée et le premier message,
 * visibles par le destinataire, mais seule la personne qui a écrit peut parler tant que l'autre n'a pas accepté (request_status = pending).
 * Une discussion déjà existante entre les deux personnes est réutilisée.
 */
async function openRequestChat(senderId: string, receiverId: string, invitationId: string, text: string, chroniqueId: string, thumb: string, now: number) {
  const docIds = [`${receiverId}${senderId}`, `${senderId}${receiverId}`];
  const existing = await db.collection("Chats").where("docId", "in", docIds).limit(1).get();
  const request = { request_status: "pending", request_from: senderId, request_invitation_id: invitationId };
  let chatId: string;
  let chatDocId: string;
  let chatSenderId = senderId;
  if (existing.empty) {
    chatId = db.collection("Chats").doc().id;
    chatDocId = docIds[0];
    await db.collection("Chats").doc(chatId).set({
      id: chatId, sender_id: senderId, receiver_id: receiverId, docId: chatDocId, type: "USER", last_message: text, created_at: now, updated_at: now,
      my_msg_not_read: 0, your_msg_not_read: 0, lastMessageIsRead: false, send_sending: "", receiver_sending: "", post_id: null, entreprise_id: "", ...request,
    });
  } else {
    chatId = existing.docs[0].id;
    chatDocId = String(existing.docs[0].get("docId") ?? chatId);
    chatSenderId = String(existing.docs[0].get("sender_id") ?? senderId);
  }
  const base = {
    send_by: senderId, receiverBy: receiverId, chat_id: chatDocId, is_valide: true, is_deleted: false, is_encrypted: false, message_state: "NONLU",
    reply_message: { message: "", message_type: "text", id: "", replyTo: "", replyBy: "" }, reaction: { reactions: [], reactedUserIds: [] },
    status: "delivered", send_sending: false, receiver_sending: false,
  };
  const cardRef = db.collection("Messages").doc();
  const textRef = db.collection("Messages").doc();
  const batch = db.batch();
  batch.set(cardRef, {
    ...base, id: cardRef.id, message_type: "link_share", message: "Sa réponse à votre chronique", imageText: thumb, item_id: chroniqueId, item_type: "chronique",
    item_title: "Chronique", item_subtitle: "Réponse à votre chronique", item_thumbnail: thumb, create_at_time_spam: now, createdAt: FieldValue.serverTimestamp(),
  });
  batch.set(textRef, { ...base, id: textRef.id, message_type: "text", message: text, create_at_time_spam: now + 1, createdAt: FieldValue.serverTimestamp() });
  // Messages non lus pour le destinataire : selon le côté de la discussion (voir myChat._updateChatCounters)
  batch.update(db.collection("Chats").doc(chatId), {
    last_message: text, updated_at: now, ...request, [chatSenderId === senderId ? "your_msg_not_read" : "my_msg_not_read"]: FieldValue.increment(2),
  });
  await batch.commit();
  return { chatId, chatDocId };
}

/** Réponse à l'invitation (depuis la page Invitations, la discussion ou ailleurs) : l'état est recopié dans la discussion temporaire. */
export const onInvitationAnswered = onDocumentUpdated({ document: "Invitations/{id}", memory: "256MiB", maxInstances: 10 }, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after || before["status"] === after["status"]) return;
  const chatId = String(after["chat_id"] ?? "");
  const status = after["status"] === "ACCEPTER" ? "accepted" : after["status"] === "REFUSER" ? "refused" : "";
  if (!chatId || !status) return;
  const ref = db.collection("Chats").doc(chatId);
  const chat = await ref.get();
  // Seulement si la discussion attend bien CETTE invitation (une réponse ancienne ne doit rien défaire)
  if (!chat.exists || chat.get("request_invitation_id") !== event.params.id || chat.get("request_status") === status) return;
  await ref.update({ request_status: status, updated_at: Date.now() });
});
