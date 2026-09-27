import { onSchedule } from "firebase-functions/v2/scheduler";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { getFirestore, Timestamp } from "firebase-admin/firestore";

/** Sans signal de l'hôte (envoyé toutes les 2 min) depuis ce délai, le live est considéré abandonné. */
const INACTIVITY_MINUTES = 6;
/** Marge après la durée maximale, le temps que l'app de l'hôte termine elle-même le live. */
const DURATION_GRACE_MINUTES = 2;
const DEFAULT_DURATION_MINUTES = 30;

function millis(v: unknown): number | null {
  if (v instanceof Timestamp) return v.toMillis();
  if (typeof v === "number" && Number.isFinite(v)) return v;
  return null;
}

/**
 * Vérifie toutes les 2 minutes les lives actifs et termine :
 * - les lives abandonnés : aucun signal de l'hôte depuis 6 min ;
 * - les lives qui dépassent leur durée maximale (30 min, 60 min pour les admins), ce qui ferme aussi
 *   les lives fantômes qui n'ont jamais envoyé de signal.
 */
export const autoTerminateInactiveLives = onSchedule(
  { schedule: "every 2 minutes", timeoutSeconds: 60 },
  async () => {
    const db = getFirestore();
    const now = Date.now();
    const snap = await db.collection("lives").where("isLive", "==", true).get();
    if (snap.empty) return;

    const batch = db.batch();
    let count = 0;
    for (const doc of snap.docs) {
      const d = doc.data();
      const start = millis(d["startTime"]) ?? now;
      // Les anciennes versions de l'app n'envoient aucun signal : pour elles, seule la durée maximale s'applique
      const lastSignal = millis(d["lastHeartbeatAt"]);
      const duration = typeof d["liveDurationMinutes"] === "number" ? d["liveDurationMinutes"] : DEFAULT_DURATION_MINUTES;

      let reason: string | null = null;
      if (lastSignal !== null && now - lastSignal > INACTIVITY_MINUTES * 60_000) reason = "inactivite";
      else if (now - start > (duration + DURATION_GRACE_MINUTES) * 60_000) reason = "duree_max";
      if (!reason) continue;

      batch.update(doc.ref, {
        isLive: false,
        endTime: Timestamp.fromMillis(now),
        autoTerminated: true,
        autoTerminatedReason: reason,
      });
      count++;
    }
    if (count === 0) return;
    await batch.commit();
    console.log(`autoTerminateInactiveLives: ${count} live(s) terminé(s).`);
  }
);

/**
 * Un seul live actif par hôte : à la création d'un live, les autres lives encore actifs
 * du même hôte sont terminés (filet de sécurité si deux téléphones ou une ancienne version).
 */
export const onLiveCreatedSingleActive = onDocumentCreated("lives/{liveId}", async (event) => {
  const data = event.data?.data();
  const hostId = data?.["hostId"] as string | undefined;
  if (!hostId || data?.["isLive"] !== true) return;

  const db = getFirestore();
  const others = await db.collection("lives")
    .where("hostId", "==", hostId)
    .where("isLive", "==", true)
    .get();
  const stale = others.docs.filter((d) => d.id !== event.params.liveId);
  if (stale.length === 0) return;

  const batch = db.batch();
  const now = Timestamp.now();
  for (const d of stale) {
    batch.update(d.ref, { isLive: false, endTime: now, autoTerminated: true, autoTerminatedReason: "nouveau_live" });
  }
  await batch.commit();
  console.log(`onLiveCreatedSingleActive: ${stale.length} ancien(s) live(s) de ${hostId} terminé(s).`);
});
