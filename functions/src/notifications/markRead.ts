import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";

/**
 * « Tout marquer comme vu » : l'application met l'écran à jour tout de suite (la personne n'attend rien), puis appelle cette fonction qui fait le
 * travail sur le serveur par lots de 400, sans que la personne ait besoin de rester sur la page. Retourne le nombre de notifications marquées.
 */
const BATCH = 400;
const MAX_ROUNDS = 50; // 20 000 notifications au plus par appel

export const markAllNotificationsRead = onCall({ region: "us-central1", timeoutSeconds: 120, memory: "256MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Connexion requise");

  let marked = 0;
  for (let round = 0; round < MAX_ROUNDS; round++) {
    // deux filtres d'égalité : aucun index composite à créer ; les documents mis à jour sortent de la requête, donc pas de curseur
    const snap = await db.collection("Notifications").where("receiver_id", "==", uid).where("is_open", "==", false).limit(BATCH).get();
    if (snap.empty) break;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.update(d.ref, { is_open: true, users_id_view: FieldValue.arrayUnion(uid) }));
    await batch.commit();
    marked += snap.size;
    if (snap.size < BATCH) break;
  }
  return { marked };
});
