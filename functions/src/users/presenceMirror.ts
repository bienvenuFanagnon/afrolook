import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { db } from "../shared/firebase";

/**
 * Miroir léger de présence : `UserPresence/{uid}` ne contient que ce qu'il faut pour le point vert
 * « en ligne » (dernière activité, connecté, confidentialité). L'application l'écoute à la place du
 * profil complet (plusieurs Ko, retéléchargé à chaque modification) → moins de données lues.
 * Les anciennes versions de l'application continuent d'écouter le profil : rien ne casse.
 */
function presenceOf(data: FirebaseFirestore.DocumentData | undefined) {
  const privacy = (data?.privacySettings ?? {}) as Record<string, unknown>;
  return {
    isConnected: data?.isConnected === true,
    last_time_active: typeof data?.last_time_active === "number" ? data.last_time_active : 0,
    // Même structure que le profil : le widget lit `privacySettings.ghostMode / hideLastSeen`.
    privacySettings: { ghostMode: privacy.ghostMode === true, hideLastSeen: privacy.hideLastSeen === true },
  };
}

export const mirrorUserPresence = onDocumentWritten(
  { document: "Users/{userId}", memory: "256MiB", cpu: 1, maxInstances: 10 },
  async (event) => {
    const after = event.data?.after;
    if (!after?.exists) return; // profil supprimé : on laisse le miroir (purgé avec le compte)
    const next = presenceOf(after.data());
    const prev = event.data?.before?.exists ? presenceOf(event.data.before.data()) : null;
    if (
      prev &&
      prev.isConnected === next.isConnected &&
      prev.last_time_active === next.last_time_active &&
      prev.privacySettings.ghostMode === next.privacySettings.ghostMode &&
      prev.privacySettings.hideLastSeen === next.privacySettings.hideLastSeen
    ) {
      return; // rien de changé côté présence (la plupart des écritures du profil)
    }
    await db.collection("UserPresence").doc(event.params.userId).set(next);
  }
);
