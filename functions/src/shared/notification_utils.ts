import { db } from "./firebase";
import { deliverPush, PushResult } from "./push";
import { categoryOfData } from "../notifications/policy_logic";
import { previewForContent } from "./preview";

/**
 * Envoie une notification push à des personnes désignées par leur identifiant OneSignal.
 *
 * Nom et signature conservés pour les fonctions existantes, mais l'envoi passe maintenant par `deliverPush` (shared/push.ts) :
 * FCM pour les personnes qui ont un jeton Firebase, OneSignal (avec coupe-circuit) pour les autres.
 * `appId` / `apiKey` : identifiants OneSignal, utilisés seulement pour le repli OneSignal.
 * `smallImage` : photo de l'expéditeur (icône, OneSignal seulement). L'IMAGE D'APERÇU du contenu est déterminée ici : `previewImage` si l'appelant la
 * fournit, sinon l'aperçu du post / de la chronique désigné par `data.post_id` ; un contenu sans aperçu (texte) part sans image.
 * La catégorie (direct, social, rappel) vient de `data.type_notif` : les règles de budget et d'heures calmes s'appliquent aux deux dernières.
 * Ne lève plus d'erreur : un échec d'envoi ne fait pas échouer l'appelant.
 */
export async function sendToOneSignal(
  userIds: string[],
  message: string,
  appName: string,
  smallImage: string,
  appId: string,
  apiKey: string,
  data: any,
  previewImage?: string
): Promise<PushResult> {
  const oneSignal = appId && apiKey ? { appId, apiKey } : undefined;
  const preview = previewImage ?? (data?.post_id ? await previewForContent(data.post_id, data.post_type) : "");
  return deliverPush(
    userIds.filter((id) => id && id.length > 5).map((oneSignalId) => ({ oneSignalId })),
    { title: appName, message, image: preview, avatar: smallImage, data },
    oneSignal,
    false,
    categoryOfData(data)
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
