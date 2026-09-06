import { onSchedule } from "firebase-functions/v2/scheduler";
import { getFirestore, Timestamp } from "firebase-admin/firestore";

const INACTIVITY_MINUTES = 20;

/**
 * Vérifie toutes les 5 minutes les lives actifs.
 * Termine automatiquement ceux dont le lastHeartbeatAt date de plus de 20 minutes
 * (l'hôte a quitté l'app sans terminer le live proprement).
 */
export const autoTerminateInactiveLives = onSchedule(
  { schedule: "every 5 minutes", timeoutSeconds: 60 },
  async () => {
    const db = getFirestore();
    const cutoff = Timestamp.fromMillis(
      Date.now() - INACTIVITY_MINUTES * 60 * 1000
    );

    const snap = await db
      .collection("lives")
      .where("isLive", "==", true)
      .where("lastHeartbeatAt", "<", cutoff)
      .get();

    if (snap.empty) return;

    const batch = db.batch();
    const now = Timestamp.now();

    snap.docs.forEach((doc) => {
      batch.update(doc.ref, {
        isLive: false,
        endTime: now,
        autoTerminated: true,
      });
    });

    await batch.commit();
    console.log(`autoTerminateInactiveLives: ${snap.size} live(s) terminé(s).`);
  }
);
