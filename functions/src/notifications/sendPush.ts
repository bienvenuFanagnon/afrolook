import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db } from "../shared/firebase";
import { deliverPush, PushTarget } from "../shared/push";
import { adminDocs } from "../shared/admin_notify";
import { previewForContent } from "../shared/preview";
import { categoryOfData } from "./policy_logic";

/**
 * Envoi d'une notification push depuis l'application (like, commentaire, message, cadeau…).
 * Remplace l'appel direct à l'API OneSignal depuis le téléphone (qui obligeait à distribuer la clé OneSignal dans l'application) :
 * le serveur choisit le canal (FCM, sinon OneSignal) et garde les clés.
 *
 * Entrée : { oneSignalIds?: string[], userIds?: string[], title, message, smallImage?, data?, toAdmins?, details? }
 * `toAdmins` (administrateurs seulement) : écrit à tous les administrateurs. `details` : renvoie aussi le canal utilisé par personne
 * (page de test des notifications).
 */
const ADMIN_ROLES = ["ADM", "admin", "ADMIN", "super_admin"];
const MAX_TARGETS = 200;
const MAX_TARGETS_ADMIN = 5000;
/** Seules ces clés sont transmises à l'application ; `send_user_id` est imposé (voir plus bas). */
const DATA_KEYS = ["send_user_id", "recever_user_id", "type_notif", "post_id", "post_type", "chat_id"];

const clip = (v: unknown, n: number): string => String(v ?? "").slice(0, n);

export const sendPushToUsers = onCall({ region: "us-central1", timeoutSeconds: 60, memory: "256MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Connexion requise");

  const d = (request.data ?? {}) as Record<string, unknown>;
  const message = clip(d["message"], 300).trim();
  if (!message) throw new HttpsError("invalid-argument", "Message vide");
  const title = clip(d["title"], 80).trim() || "AfroLook";

  const me = (await db.collection("Users").doc(uid).get()).data();
  const isAdmin = ADMIN_ROLES.includes(String(me?.["role"] ?? ""));

  const oneSignalIds = (Array.isArray(d["oneSignalIds"]) ? d["oneSignalIds"] : []).map((x) => clip(x, 64)).filter((x) => x.length > 5);
  const userIds = (Array.isArray(d["userIds"]) ? d["userIds"] : []).map((x) => clip(x, 128)).filter(Boolean);
  if (d["toAdmins"] === true) {
    if (!isAdmin) throw new HttpsError("permission-denied", "Réservé aux administrateurs");
    userIds.push(...(await adminDocs()).map((a) => a.id));
  }
  const targets: PushTarget[] = [
    ...[...new Set(oneSignalIds)].map((oneSignalId) => ({ oneSignalId })),
    ...[...new Set(userIds)].map((userId) => ({ userId })),
  ];
  if (!targets.length) return { fcm: 0, oneSignal: 0, unreachable: 0 };
  if (targets.length > (isAdmin ? MAX_TARGETS_ADMIN : MAX_TARGETS)) {
    throw new HttpsError("invalid-argument", "Trop de destinataires pour un seul envoi");
  }

  const raw = (d["data"] && typeof d["data"] === "object" ? d["data"] : {}) as Record<string, unknown>;
  const data: Record<string, string> = {};
  for (const k of DATA_KEYS) if (raw[k] !== undefined && raw[k] !== null) data[k] = clip(raw[k], 200);
  // L'expéditeur affiché ne peut pas être usurpé (sauf par un administrateur qui écrit au nom d'un compte officiel)
  if (!isAdmin || !data["send_user_id"]) data["send_user_id"] = uid;

  // Image d'aperçu : celle du post / de la chronique concerné (photo, miniature de vidéo) ; rien pour un contenu texte ou un message.
  // La photo envoyée par l'application (expéditeur) ne sert que d'icône pour OneSignal.
  const image = data["post_id"] ? await previewForContent(data["post_id"], data["post_type"]) : "";
  return deliverPush(targets, { title, message, image, avatar: clip(d["smallImage"], 500), data }, undefined, d["details"] === true, categoryOfData(data));
});
