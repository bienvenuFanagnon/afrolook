import axios from "axios";
import { db } from "./firebase";

/**
 * Envoie une notification push via OneSignal
 */
export async function sendToOneSignal(
  userIds: string[],
  message: string,
  appName: string,
  smallImage: string,
  appId: string,
  apiKey: string,
  data: any
): Promise<any> {
  const body = {
    app_id: appId,
    contents: { en: message },
    include_player_ids: userIds,
    headings: { en: appName },
    small_icon: smallImage,
    large_icon: smallImage,
    android_accent_color: "FFD700",
    data: data,
  };

  try {
    const response = await axios.post(
      "https://onesignal.com/api/v1/notifications",
      body,
      {
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Basic ${apiKey}`,
        },
        timeout: 30000,
      }
    );

    console.log(`Push envoyé à ${userIds.length} utilisateurs - Status: ${response.status}`);
    return response.data;
  } catch (error) {
    console.error("Erreur OneSignal:", error);
    throw error;
  }
}

/**
 * Récupère l'image d'un canal depuis Firestore
 */
export async function getCanalImage(canalId?: string): Promise<string | null> {
  if (!canalId) return null;

  try {
    const canalDoc = await db.collection("Canals").doc(canalId).get();
    return canalDoc.data()?.urlImage || null;
  } catch {
    return null;
  }
}
