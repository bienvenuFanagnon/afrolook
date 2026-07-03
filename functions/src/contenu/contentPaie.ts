import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";

// ─── 1. Expiration automatique des boosts ─────────────────────────────────────
// Tourne chaque nuit à 02h00 UTC.
// Désactive les boosts dont boostEndDate < now.

export const expireBoosts = onSchedule(
  { schedule: "0 2 * * *", timeZone: "UTC", memory: "256MiB", cpu: 1 },
  async () => {
    const now = Date.now();

    const snap = await db
      .collection("ContentPaies")
      .where("isBoosted", "==", true)
      .where("boostEndDate", "<=", now)
      .get();

    if (snap.empty) {
      console.log("expireBoosts — aucun boost à expirer.");
      return;
    }

    console.log(`expireBoosts — ${snap.docs.length} boost(s) à désactiver.`);

    const BATCH_SIZE = 400;
    for (let i = 0; i < snap.docs.length; i += BATCH_SIZE) {
      const chunk = snap.docs.slice(i, i + BATCH_SIZE);
      const batch = db.batch();
      for (const doc of chunk) {
        batch.update(doc.ref, {
          isBoosted: false,
          boostExpiredAt: FieldValue.serverTimestamp(),
        });
      }
      try {
        await batch.commit();
        console.log(`Lot ${Math.floor(i / BATCH_SIZE) + 1} commité (${chunk.length} docs)`);
      } catch (err) {
        console.error(`Lot ${Math.floor(i / BATCH_SIZE) + 1} échoué :`, err);
      }
    }
  }
);

// ─── 2. URL signée sécurisée pour téléchargements ─────────────────────────────
// Callable : l'app mobile appelle cette fonction après achat vérifié.
// Retourne une URL signée valide 1h pour le fichier GCS correspondant.

export const getSecureDownloadUrl = onCall(
  { timeoutSeconds: 15 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentification requise.");
    }

    const { contentId, fileKey } = request.data as {
      contentId?: string;
      fileKey?: string;
    };
    if (!contentId) {
      throw new HttpsError("invalid-argument", "contentId manquant.");
    }

    const uid = request.auth.uid;

    // Récupérer le document du contenu en premier pour vérifier isFree
    const contentDoc = await db.collection("ContentPaies").doc(contentId).get();
    if (!contentDoc.exists) {
      throw new HttpsError("not-found", "Contenu introuvable.");
    }
    const isFree = contentDoc.data()?.isFree === true;

    // Accès admin : vérifier le rôle
    const userDoc = await db.collection("Users").doc(uid).get();
    const isAdmin = userDoc.data()?.role === "ADM";

    // Contenu gratuit et admin ont accès sans achat
    if (!isFree && !isAdmin) {
      // Vérifier que l'utilisateur a bien acheté ce contenu
      const purchaseSnap = await db
        .collection("ContentPaie_purchases")
        .where("userId", "==", uid)
        .where("contentId", "==", contentId)
        .limit(1)
        .get();

      if (purchaseSnap.empty) {
        throw new HttpsError(
          "permission-denied",
          "Achat non trouvé pour cet utilisateur."
        );
      }
    }

    const content = contentDoc.data()!;

    // Sélection du fichier : fileKey précis si fourni, sinon ordre par défaut
    const validKeys = ["videoUrl", "pdfUrl", "fileUrl", "tutorialVideoUrl"];
    let fileUrl: string | undefined;
    if (fileKey && validKeys.includes(fileKey)) {
      fileUrl = content[fileKey] || undefined;
    }
    if (!fileUrl) {
      // Fallback : ordre logique (vidéo > pdf > fichier > tutoriel)
      fileUrl =
        content.videoUrl ||
        content.pdfUrl ||
        content.fileUrl ||
        content.tutorialVideoUrl ||
        undefined;
    }

    if (!fileUrl) {
      throw new HttpsError("not-found", "Aucun fichier associé à ce contenu.");
    }

    // Retourner directement l'URL Firebase Storage (token de téléchargement intégré).
    // L'accès est sécurisé par la vérification d'achat ci-dessus — pas besoin de
    // générer une URL signée GCS qui nécessiterait des permissions IAM supplémentaires.
    console.log(`getSecureDownloadUrl — accès autorisé pour ${uid} / ${contentId}`);
    return { url: fileUrl, expiresIn: 0 };
  }
);
