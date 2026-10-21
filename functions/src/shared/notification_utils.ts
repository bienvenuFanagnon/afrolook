import { db } from "./firebase";
import { deliverPush, PushResult } from "./push";

/**
 * Envoie une notification push à des personnes désignées par leur identifiant OneSignal.
 *
 * Nom et signature conservés pour les fonctions existantes, mais l'envoi passe maintenant par `deliverPush` (shared/push.ts) :
 * FCM pour les personnes qui ont un jeton Firebase, OneSignal (avec coupe-circuit) pour les autres.
 * `appId` / `apiKey` : identifiants OneSignal, utilisés seulement pour le repli OneSignal.
 * Ne lève plus d'erreur : un échec d'envoi ne fait pas échouer l'appelant.
 */
export async function sendToOneSignal(
  userIds: string[],
  message: string,
  appName: string,
  smallImage: string,
  appId: string,
  apiKey: string,
  data: any
): Promise<PushResult> {
  const oneSignal = appId && apiKey ? { appId, apiKey } : undefined;
  return deliverPush(
    userIds.filter((id) => id && id.length > 5).map((oneSignalId) => ({ oneSignalId })),
    { title: appName, message, image: smallImage, data },
    oneSignal
  );
}

/**
 * Récupère l'image d'un canal depuis Firestore
 */
export async function getCanalImage(canalId?: string): Promise<string | null> {
  if (!canalId) return null;

  try {
    const canalDoc = await db.collection("Canaux").doc(canalId).get();
    return canalDoc.data()?.urlImage || null;
  } catch {
    return null;
  }
}
