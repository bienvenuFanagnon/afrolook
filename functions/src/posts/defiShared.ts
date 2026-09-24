import { db } from "../shared/firebase";
import { sendToOneSignal } from "../shared/notification_utils";

export const APP_DATA_DOC = "XgkSxKc10vWsJJ2uBraT";
export const POST_ID_PATTERN = /^[A-Za-z0-9_-]{10,64}$/;

// Répartition imposée côté serveur selon le nombre de gagnants (identique au formulaire de l'app).
export function defaultRewardSplit(winnersCount: number): number[] {
  switch (winnersCount) {
    case 2: return [70, 30];
    case 3: return [60, 30, 10];
    default: return [100];
  }
}

// Post envoyé par l'app : on impose l'identité et on remet à zéro tout ce qui ne doit pas
// pouvoir être fixé à la création (compteurs, votes, champs DÉFI serveur, pub, gains…).
export function sanitizeClientPost(
  raw: Record<string, unknown>,
  postId: string,
  userId: string,
): Record<string, unknown> {
  const data: Record<string, unknown> = { ...raw };
  for (const key of [
    "defi_config", "defi_response_to_post_id", "defi_participant_ids", "defi_participant_count",
    "defi_winners", "defi_settled_at", "rawScore", "postScore", "reporterIds",
    "wrongCategoryReporterIds", "reportCount", "commentSuggestions", "isRepost", "reposterUserId",
    "reposterPseudo", "reposterImageUrl", "originalPostId",
  ]) {
    delete data[key];
  }
  return {
    ...data,
    id: postId,
    user_id: userId,
    status: "VALIDE",
    defi_votes: 0,
    defi_voter_ids: [],
    likes: 0,
    loves: 0,
    comments: 0,
    partage: 0,
    vues: 0,
    popularity: 0,
    giftCount: 0,
    feedScore: 0,
    uniqueViewsCount: 0,
    favorites_count: 0,
    adSupportCount: 0,
    seen_by_users_count: 0,
    seen_by_users_map: {},
    votes_challenge: 0,
    users_like_id: [],
    users_love_id: [],
    users_vue_id: [],
    users_republier_id: [],
    users_favorite_id: [],
    users_votes_ids: [],
    isBoosted: false,
    isAdvertisement: false,
    advertisementId: null,
    rang_gagnant: null,
    prix_gagnant: null,
    prix_deja_encaisser: null,
    date_encaissement: null,
  };
}

export function defiLabel(description: string | undefined): string {
  const d = (description ?? "").trim();
  if (!d) return "";
  return ` « ${d.slice(0, 40)}${d.length > 40 ? "…" : ""} »`;
}

// Notification in-app (collection Notifications) + push OneSignal. Ouvre le post au clic.
export async function sendDefiNotification(p: {
  receiverId: string;
  receiverData?: FirebaseFirestore.DocumentData;
  senderId: string;
  titre: string;
  message: string;
  postId: string;
  postDataType?: string;
  image?: string;
  thumbnail?: string;
  defiPostId: string;
  appConfig?: FirebaseFirestore.DocumentData;
}): Promise<void> {
  const nowMicros = Date.now() * 1000;
  const notifRef = db.collection("Notifications").doc();
  await notifRef.set({
    id: notifRef.id,
    titre: p.titre,
    description: p.message,
    type: "POST",
    user_id: p.senderId,
    receiver_id: p.receiverId,
    post_id: p.postId,
    post_data_type: p.postDataType ?? "",
    media_url: p.image ?? "",
    post_thumbnail: p.thumbnail ?? "",
    is_open: false,
    users_id_view: [],
    status: "VALIDE",
    created_at: nowMicros,
    updated_at: nowMicros,
    createdAt: nowMicros,
    updatedAt: nowMicros,
    defiPostId: p.defiPostId,
  });

  const receiverData = p.receiverData ?? (await db.collection("Users").doc(p.receiverId).get()).data();
  const appConfig = p.appConfig ?? (await db.collection("AppData").doc(APP_DATA_DOC).get()).data() ?? {};
  const oneSignalId = (receiverData?.["oneIgnalUserid"] as string | undefined) ?? "";
  if (!oneSignalId || !appConfig["one_signal_app_id"] || !appConfig["one_signal_api_key"]) return;

  await sendToOneSignal(
    [oneSignalId],
    p.message,
    "Afrolook",
    p.image || appConfig["app_logo"] || "",
    appConfig["one_signal_app_id"],
    appConfig["one_signal_api_key"],
    {
      type_notif: "POST",
      post_id: p.postId,
      post_type: p.postDataType ?? "",
      send_user_id: p.senderId,
      recever_user_id: p.receiverId,
      chat_id: "",
    },
  );
}
