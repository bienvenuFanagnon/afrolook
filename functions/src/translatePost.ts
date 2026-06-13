import {onCall, HttpsError} from "firebase-functions/v2/https";
import {getFirestore} from "firebase-admin/firestore";
import {v2 as translate} from "@google-cloud/translate";

const translateClient = new translate.Translate();

interface TranslatePostDescriptionData {
  postId: string;
  text: string;
  targetLang: string;
}

/**
 * Traduit la description d'un post vers `targetLang` via Google Cloud
 * Translation API, avec mise en cache du résultat dans
 * `Posts/{postId}.translations.{targetLang}` (Firestore).
 *
 * - Si une traduction existe déjà en cache pour cette langue, elle est
 *   retournée directement (aucun appel à l'API de traduction).
 * - Sinon, le texte est traduit (détection automatique de la langue
 *   source) puis le résultat est enregistré pour les prochaines lectures.
 */
export const translatePostDescription = onCall(
  {timeoutSeconds: 30, region: "us-central1"},
  async (request) => {
    const data = request.data as TranslatePostDescriptionData;
    const {postId, text, targetLang} = data;

    if (!postId || !text || !targetLang) {
      throw new HttpsError(
        "invalid-argument",
        "postId, text et targetLang sont requis"
      );
    }

    const postRef = getFirestore().collection("Posts").doc(postId);

    try {
      const postDoc = await postRef.get();
      const postData = postDoc.exists ? postDoc.data() : undefined;

      // 1. Vérifier le cache Firestore
      const cached = postData?.translations?.[targetLang];
      if (cached) {
        return {translatedText: cached as string, cached: true};
      }

      // 2. Appel à l'API Google Cloud Translation (détection auto de la langue source)
      let translatedText: string;
      try {
        const [result] = await translateClient.translate(text, targetLang);
        translatedText = result;
      } catch (apiError) {
        console.error("Erreur Google Cloud Translation API:", apiError);
        throw new HttpsError(
          "internal",
          "Le service de traduction est momentanément indisponible"
        );
      }

      // 3. Mise en cache (merge-safe, ne touche que ce champ)
      try {
        await postRef.update({
          [`translations.${targetLang}`]: translatedText,
        });
      } catch (writeError) {
        // Ne bloque pas la réponse si l'écriture du cache échoue
        console.error("Erreur écriture cache traduction:", writeError);
      }

      return {translatedText, cached: false};
    } catch (error) {
      if (error instanceof HttpsError) throw error;
      console.error("Erreur translatePostDescription:", error);
      throw new HttpsError("internal", "Erreur lors de la traduction");
    }
  }
);
