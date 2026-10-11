import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { collectFollowerIds } from "../follows/followersRead";
import { sendToOneSignal } from "../shared/notification_utils";
import { APP_DATA_DOC, defiLabel } from "./defiShared";

// Annonce élargie d'un DÉFI qui vient d'être lancé (création ou transformation d'un post).
// Public visé : les abonnés du créateur + les comptes actifs ces 60 derniers jours (dans les pays du post).
// Garde-fous : une seule annonce par DÉFI, annonce large au plus toutes les 6 h par créateur,
// 5 000 destinataires au plus (coût Firestore), jamais l'auteur lui-même.
export const DEFI_ACTIVE_WINDOW_MS = 60 * 24 * 3600 * 1000;
export const DEFI_WIDE_COOLDOWN_MS = 6 * 3600 * 1000;
export const DEFI_MAX_AUDIENCE = 5000;
const PUSH_BATCH = 2000;
const SAVE_BATCH = 400;

export type DefiAnnounceStats = {
  skipped?: string;
  audience?: number;
  followers?: number;
  wide?: boolean;
  notifications?: number;
  push?: number;
};

type Recipient = { id: string; oneSignalId: string };

/** Pays visés par le post : liste vide = tous les pays. */
export function targetCountries(post: FirebaseFirestore.DocumentData): string[] {
  const list = Array.isArray(post["availableCountries"]) ? (post["availableCountries"] as unknown[]).map(String) : [];
  if (list.length === 0 || list.includes("ALL")) return [];
  return list.map((c) => c.toUpperCase());
}

/** Un compte actif dans un pays visé (ou n'importe quel pays si le post n'en cible pas). */
export function inTargetCountry(user: FirebaseFirestore.DocumentData, countries: string[]): boolean {
  if (countries.length === 0) return true;
  const code = String((user["countryData"] as Record<string, unknown> | undefined)?.["countryCode"] ?? "").toUpperCase();
  return code !== "" && countries.includes(code);
}

export async function broadcastDefiLaunch(postId: string): Promise<DefiAnnounceStats> {
  const postRef = db.collection("Posts").doc(postId);
  const now = Date.now();

  // Réserve l'annonce : un DÉFI n'est annoncé qu'une fois, même si l'appelant réessaie.
  const claimed = await db.runTransaction(async (tx) => {
    const snap = await tx.get(postRef);
    const post = snap.data();
    if (!post || post["type"] !== "DEFI") return null;
    if ((post["defi_config"] as Record<string, unknown> | undefined)?.["status"] !== "en_cours") return null;
    if (post["defi_broadcast_at"]) return null;
    tx.update(postRef, { defi_broadcast_at: now });
    return post;
  });
  if (!claimed) return { skipped: "déjà annoncé ou non éligible" };

  const creatorId = String(claimed["user_id"] ?? "");
  const creatorSnap = await db.collection("Users").doc(creatorId).get();
  const creator = creatorSnap.data() ?? {};
  const wide = now - Number(creator["lastDefiBroadcastAt"] ?? 0) >= DEFI_WIDE_COOLDOWN_MS;

  const recipients = new Map<string, Recipient>();
  const add = (id: string, data: FirebaseFirestore.DocumentData) => {
    const oneSignalId = String(data["oneIgnalUserid"] ?? "");
    if (id !== creatorId && !recipients.has(id)) recipients.set(id, { id, oneSignalId: oneSignalId.length > 5 ? oneSignalId : "" });
  };

  // 1) abonnés du créateur (toujours prévenus)
  const followerIds = await collectFollowerIds(creatorId, (creator["userAbonnesIds"] as string[] | undefined) ?? []);
  for (let i = 0; i < followerIds.length && recipients.size < DEFI_MAX_AUDIENCE; i += 300) {
    const refs = followerIds.slice(i, i + 300).map((id) => db.collection("Users").doc(id));
    const docs = await db.getAll(...refs, { fieldMask: ["oneIgnalUserid"] });
    for (const d of docs) if (d.exists) add(d.id, d.data()!);
  }
  const followers = recipients.size;

  // 2) comptes actifs récemment, dans les pays visés (annonce « large »)
  if (wide) {
    const countries = targetCountries(claimed);
    const snap = await db.collection("Users")
      .where("last_time_active", ">=", now - DEFI_ACTIVE_WINDOW_MS)
      .select("oneIgnalUserid", "countryData")
      .limit(DEFI_MAX_AUDIENCE)
      .get();
    for (const d of snap.docs) {
      if (recipients.size >= DEFI_MAX_AUDIENCE) break;
      if (inTargetCountry(d.data(), countries)) add(d.id, d.data());
    }
  }

  const list = [...recipients.values()];
  if (list.length === 0) return { skipped: "aucun destinataire", audience: 0, followers, wide };

  const cfg = (claimed["defi_config"] as Record<string, unknown>) ?? {};
  const cagnotte = Number(cfg["cagnotte_pieces"] ?? 0);
  const pseudo = String(creator["pseudo"] ?? "Afrolook");
  const title = "🏆 Nouveau défi sur Afrolook";
  const message = `@${pseudo} lance un défi${cagnotte > 0 ? ` : ${cagnotte} pièces à gagner` : ""}${defiLabel(String(claimed["description"] ?? ""))}`;
  const image = String(creator["imageUrl"] ?? "");
  const nowMicros = now * 1000;

  // Notifications dans l'application
  let notifications = 0;
  for (let i = 0; i < list.length; i += SAVE_BATCH) {
    const batch = db.batch();
    for (const r of list.slice(i, i + SAVE_BATCH)) {
      const ref = db.collection("Notifications").doc();
      batch.set(ref, {
        id: ref.id, titre: title, description: message, type: "POST", user_id: creatorId, receiver_id: r.id,
        post_id: postId, post_data_type: String(claimed["dataType"] ?? ""), media_url: image, is_open: false, users_id_view: [],
        status: "VALIDE", created_at: nowMicros, updated_at: nowMicros, createdAt: nowMicros, updatedAt: nowMicros, defiPostId: postId,
      });
      notifications++;
    }
    await batch.commit();
  }

  // Notifications push
  let push = 0;
  const appConfig = (await db.collection("AppData").doc(APP_DATA_DOC).get()).data() ?? {};
  const ids = list.map((r) => r.oneSignalId).filter(Boolean);
  if (appConfig["one_signal_app_id"] && appConfig["one_signal_api_key"] && ids.length > 0) {
    for (let i = 0; i < ids.length; i += PUSH_BATCH) {
      const chunk = ids.slice(i, i + PUSH_BATCH);
      await sendToOneSignal(chunk, message, title, image || String(appConfig["app_logo"] ?? ""), String(appConfig["one_signal_app_id"]), String(appConfig["one_signal_api_key"]), {
        type_notif: "POST", post_id: postId, post_type: String(claimed["dataType"] ?? ""), send_user_id: creatorId, chat_id: "",
      });
      push += chunk.length;
    }
  }

  if (wide) await db.collection("Users").doc(creatorId).set({ lastDefiBroadcastAt: now }, { merge: true });
  await postRef.update({ defi_broadcast_count: FieldValue.increment(list.length) });
  return { audience: list.length, followers, wide, notifications, push };
}
