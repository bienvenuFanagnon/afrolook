import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { db } from "../shared/firebase";
import { emailTransporter } from "../shared/email_utils";
import { sendToOneSignal } from "../shared/notification_utils";

// Règle App Store 1.2 : chaque signalement et chaque blocage arrive dans une file de modération
// (collection ModerationReports) et prévient les admins, qui doivent agir sous 24 h
// (suppression du contenu, suspension de l'auteur) depuis la page admin "Modération".
const APP_DATA_DOC = "XgkSxKc10vWsJJ2uBraT";
const EMAIL_FROM = '"Afrolook" <epargneplus@epargneplusfinance.com>';

type ModerationEntry = {
  type: "post_report" | "user_block";
  reporterId: string;
  targetUserId?: string | null;
  postId?: string | null;
  reason?: string | null;
};

async function adminDocs(): Promise<FirebaseFirestore.QueryDocumentSnapshot[]> {
  const snaps = await Promise.all(["ADM", "admin", "ADMIN", "super_admin"].map((role) =>
    db.collection("Users").where("role", "==", role).get()));
  const byId = new Map<string, FirebaseFirestore.QueryDocumentSnapshot>();
  snaps.forEach((s) => s.docs.forEach((d) => byId.set(d.id, d)));
  return [...byId.values()];
}

export async function queueModerationReport(entry: ModerationEntry): Promise<void> {
  const now = Date.now();
  const [reporterDoc, targetDoc] = await Promise.all([
    db.collection("Users").doc(entry.reporterId).get(),
    entry.targetUserId ? db.collection("Users").doc(entry.targetUserId).get() : Promise.resolve(null),
  ]);
  const reporterPseudo = (reporterDoc.data()?.["pseudo"] as string | undefined) ?? "";
  const targetPseudo = (targetDoc?.data()?.["pseudo"] as string | undefined) ?? "";

  const reportRef = db.collection("ModerationReports").doc();
  await reportRef.set({
    id: reportRef.id,
    type: entry.type,
    status: "pending",
    reporterId: entry.reporterId,
    reporterPseudo,
    targetUserId: entry.targetUserId ?? null,
    targetPseudo,
    postId: entry.postId ?? null,
    reason: entry.reason ?? null,
    createdAt: now,
    // Délai de traitement annoncé dans les conditions d'utilisation
    dueAt: now + 24 * 3600 * 1000,
  });

  const what = entry.type === "user_block"
    ? `🚫 @${reporterPseudo || "un utilisateur"} a bloqué @${targetPseudo || "un utilisateur"}`
    : `🚩 @${reporterPseudo || "un utilisateur"} a signalé une publication de @${targetPseudo || "un utilisateur"}`;
  const message = `${what}. À traiter sous 24 h dans Admin → Modération.`;

  try {
    const [admins, appDoc] = await Promise.all([adminDocs(), db.collection("AppData").doc(APP_DATA_DOC).get()]);
    const appConfig = appDoc.data() ?? {};
    const nowMicros = now * 1000;

    await Promise.all(admins.map(async (admin) => {
      const notifRef = db.collection("Notifications").doc();
      await notifRef.set({
        id: notifRef.id,
        titre: "Modération requise",
        description: message,
        type: "POST",
        user_id: entry.reporterId,
        receiver_id: admin.id,
        post_id: entry.postId ?? "",
        post_data_type: "",
        is_open: false,
        users_id_view: [],
        status: "VALIDE",
        created_at: nowMicros,
        updated_at: nowMicros,
        createdAt: nowMicros,
        updatedAt: nowMicros,
        moderationReportId: reportRef.id,
      });
      const oneSignalId = (admin.data()["oneIgnalUserid"] as string | undefined) ?? "";
      if (oneSignalId && appConfig["one_signal_app_id"] && appConfig["one_signal_api_key"]) {
        await sendToOneSignal([oneSignalId], message, "Afrolook — Modération", appConfig["app_logo"] ?? "",
          appConfig["one_signal_app_id"], appConfig["one_signal_api_key"],
          { type_notif: "POST", post_id: entry.postId ?? "", post_type: "", chat_id: "" });
      }
    }));

    const emails = admins.map((a) => a.data()["email"] as string | undefined).filter((e): e is string => !!e);
    if (emails.length) {
      await emailTransporter.sendMail({
        from: EMAIL_FROM,
        to: emails,
        subject: entry.type === "user_block" ? "🚫 Blocage d'utilisateur sur Afrolook" : "🚩 Signalement sur Afrolook",
        text: `${message}\n\nSignalement ${reportRef.id}${entry.postId ? ` — publication ${entry.postId}` : ""}.`,
      });
    }
  } catch (err) {
    // Le signalement reste enregistré dans ModerationReports même si l'alerte échoue.
    console.error("[moderation] Alerte admins échouée :", err);
  }
}

/** Blocage d'un utilisateur (fil, profil ou chat) : entre dans la file de modération. */
export const onUserBlocked = onDocumentCreated(
  { document: "BlockedUsers/{blockId}", timeoutSeconds: 60 },
  async (event) => {
    const data = event.data?.data();
    if (!data?.["blockedBy"] || !data?.["blockedUser"]) return;
    await queueModerationReport({
      type: "user_block",
      reporterId: data["blockedBy"],
      targetUserId: data["blockedUser"],
      postId: data["postId"] ?? null,
      reason: data["source"] ?? (data["chatId"] ? "chat" : null),
    });
  }
);
