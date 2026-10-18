import { onSchedule } from "firebase-functions/v2/scheduler";
import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { db } from "../shared/firebase";
import { storagePathFromUrl } from "../studio/artistSounds";

const BATCH = 100;

/**
 * Nettoyage des chroniques expirées (24 h) : média, aperçu, commentaires, document, compteur de l'auteur.
 * Une seule exécution par heure sur le serveur, au lieu d'un nettoyage lancé par chaque téléphone qui ouvre la liste
 * (chaque téléphone relisait toutes les chroniques expirées). Les listes ignorent déjà les chroniques expirées : ce nettoyage ne sert qu'à libérer l'espace.
 */
export const chroniqueExpiryCleanup = onSchedule({ schedule: "every 60 minutes", timeoutSeconds: 300, memory: "256MiB" }, async () => {
  const bucket = getStorage().bucket();
  const snap = await db.collection("chroniques").where("expiresAt", "<", Timestamp.now()).limit(BATCH).get();
  let done = 0;
  for (const doc of snap.docs) {
    const c = doc.data();
    try {
      for (const field of ["mediaUrl", "posterUrl", "coverImageUrl", "musicUrl"]) {
        const path = storagePathFromUrl(String(c[field] ?? ""));
        if (path && /^(chroniques|chronique_posters|chronique_covers|chronique_voices)\//.test(path)) await bucket.file(path).delete({ ignoreNotFound: true }).catch(() => undefined);
      }
      const msgs = await db.collection("chronique_messages").where("chroniqueId", "==", doc.id).limit(400).get();
      if (!msgs.empty) {
        const b = db.batch();
        msgs.docs.forEach((m) => b.delete(m.ref));
        await b.commit();
      }
      await doc.ref.delete();
      const uid = String(c["userId"] ?? "");
      if (uid) {
        const u = db.collection("Users").doc(uid);
        const n = Number((await u.get()).get("activeChroniquesCount") ?? 0);
        if (n > 0) await u.update({ activeChroniquesCount: FieldValue.increment(-1) }).catch(() => undefined);
      }
      done++;
    } catch (e) {
      console.error("[chroniqueExpiryCleanup]", doc.id, e);
    }
  }
  console.log(`[chroniqueExpiryCleanup] ${done}/${snap.size} chroniques expirées supprimées`);
});
