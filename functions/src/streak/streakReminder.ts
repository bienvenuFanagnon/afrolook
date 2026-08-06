import { onSchedule } from "firebase-functions/v2/scheduler";
import { db } from "../shared/firebase";
import { sendToOneSignal } from "../shared/notification_utils";

const APP_DATA_DOC = "XgkSxKc10vWsJJ2uBraT";
const BATCH_SIZE = 200; // OneSignal limite à 2000, on batch par sécurité

/** Retourne la date du jour au format "YYYY-MM-DD" en UTC+1 (WAT). */
function getTodayWAT(): string {
  const now = new Date(Date.now() + 60 * 60 * 1000); // UTC+1
  return now.toISOString().slice(0, 10);
}

/**
 * Récupère les IDs OneSignal des utilisateurs dont la série est en danger :
 * - commentStreak >= minStreak
 * - todayCommentCount < 3 (quota non atteint)
 * - todayCommentDate != aujourd'hui OU todayCommentCount < 3
 */
async function getDangerousStreakUsers(minStreak: number): Promise<string[]> {
  const today = getTodayWAT();

  // Utilisateurs avec une série active
  const snap = await db
    .collection("Users")
    .where("commentStreak", ">=", minStreak)
    .get();

  const oneSignalIds: string[] = [];

  for (const doc of snap.docs) {
    const data = doc.data();
    const todayCount: number = data.todayCommentCount ?? 0;
    const todayDate: string | null = data.todayCommentDate ?? null;
    const oneSignalId: string = data.oneIgnalUserid ?? "";

    // Quota non atteint aujourd'hui
    const quotaMissed = todayDate !== today || todayCount < 3;
    if (quotaMissed && oneSignalId) {
      oneSignalIds.push(oneSignalId);
    }
  }

  return oneSignalIds;
}

/**
 * Envoie les notifications en lots de BATCH_SIZE.
 */
async function sendStreakPush(
  oneSignalIds: string[],
  title: string,
  message: string,
  appId: string,
  apiKey: string
): Promise<void> {
  for (let i = 0; i < oneSignalIds.length; i += BATCH_SIZE) {
    const batch = oneSignalIds.slice(i, i + BATCH_SIZE);
    await sendToOneSignal(
      batch,
      message,
      title,
      "ic_stat_onesignal_default",
      appId,
      apiKey,
      { type: "streak_reminder", screen: "home" }
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rappel 18h WAT (17h00 UTC) — pour les séries ≥ 1 jour
// ─────────────────────────────────────────────────────────────────────────────
export const streakReminderEvening = onSchedule(
  {
    schedule: "0 17 * * *", // 17h UTC = 18h WAT
    timeZone: "UTC",
    region: "us-central1",
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  async () => {
    console.log("[streakReminderEvening] Démarrage");

    const appDoc = await db.collection("AppData").doc(APP_DATA_DOC).get();
    const appData = appDoc.data();
    if (!appData?.one_signal_app_id || !appData?.one_signal_api_key) {
      console.error("[streakReminderEvening] Clés OneSignal manquantes");
      return;
    }

    const ids = await getDangerousStreakUsers(1);
    if (ids.length === 0) {
      console.log("[streakReminderEvening] Aucun utilisateur à notifier");
      return;
    }

    console.log(`[streakReminderEvening] ${ids.length} utilisateurs à notifier`);

    await sendStreakPush(
      ids,
      "🔥 Afrolook",
      "Ta flamme attend ! Commente 3 posts aujourd'hui pour garder ta série.",
      appData.one_signal_app_id,
      appData.one_signal_api_key
    );

    console.log("[streakReminderEvening] Terminé");
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// Rappel urgent 21h30 WAT (20h30 UTC) — pour les séries ≥ 2 jours
// ─────────────────────────────────────────────────────────────────────────────
export const streakReminderUrgent = onSchedule(
  {
    schedule: "30 20 * * *", // 20h30 UTC = 21h30 WAT
    timeZone: "UTC",
    region: "us-central1",
    timeoutSeconds: 300,
    memory: "512MiB",
  },
  async () => {
    console.log("[streakReminderUrgent] Démarrage");

    const appDoc = await db.collection("AppData").doc(APP_DATA_DOC).get();
    const appData = appDoc.data();
    if (!appData?.one_signal_app_id || !appData?.one_signal_api_key) {
      console.error("[streakReminderUrgent] Clés OneSignal manquantes");
      return;
    }

    // Seulement les séries ≥ 2 jours pour le rappel urgent (éviter le spam des nouveaux)
    const ids = await getDangerousStreakUsers(2);
    if (ids.length === 0) {
      console.log("[streakReminderUrgent] Aucun utilisateur à notifier");
      return;
    }

    // Récupérer les streaks pour personnaliser le message
    const today = getTodayWAT();
    const snap = await db
      .collection("Users")
      .where("commentStreak", ">=", 2)
      .get();

    // Regrouper par durée de série pour message personnalisé
    const shortStreak: string[] = []; // 2-6 jours
    const longStreak: string[] = [];  // 7+ jours

    for (const doc of snap.docs) {
      const data = doc.data();
      const todayCount: number = data.todayCommentCount ?? 0;
      const todayDate: string | null = data.todayCommentDate ?? null;
      const oneSignalId: string = data.oneIgnalUserid ?? "";
      const streak: number = data.commentStreak ?? 0;

      if (!oneSignalId) continue;
      if (todayDate === today && todayCount >= 3) continue; // quota déjà atteint

      if (streak >= 7) {
        longStreak.push(oneSignalId);
      } else {
        shortStreak.push(oneSignalId);
      }
    }

    console.log(
      `[streakReminderUrgent] ${shortStreak.length} courtes séries, ${longStreak.length} longues séries`
    );

    if (shortStreak.length > 0) {
      await sendStreakPush(
        shortStreak,
        "⚠️ Ta flamme s'éteint !",
        "Il te reste peu de temps pour commenter 3 posts et garder ta série !",
        appData.one_signal_app_id,
        appData.one_signal_api_key
      );
    }

    if (longStreak.length > 0) {
      await sendStreakPush(
        longStreak,
        "🚨 Ne brise pas ta série !",
        "Ta grande flamme est en danger. Commente maintenant pour ne pas tout perdre !",
        appData.one_signal_app_id,
        appData.one_signal_api_key
      );
    }

    console.log("[streakReminderUrgent] Terminé");
  }
);
