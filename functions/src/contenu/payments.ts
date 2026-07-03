import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";

const BOOST_PRICES: Record<number, number> = {
  7: 1000,
  14: 1800,
  30: 3500,
  90: 9000,
  180: 16000,
  365: 28000,
};

// ── secureBoost ───────────────────────────────────────────────────────────────
// Callable sécurisé : vérifie le solde, déduit, active le boost.
export const secureBoost = onCall(
  { timeoutSeconds: 30, memory: "256MiB", cpu: 1 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentification requise.");
    }

    const { contentId, durationDays } = request.data as {
      contentId?: string;
      durationDays?: number;
    };
    if (!contentId || !durationDays) {
      throw new HttpsError("invalid-argument", "contentId et durationDays requis.");
    }

    const uid = request.auth.uid;
    const price = BOOST_PRICES[durationDays];
    if (price === undefined) {
      throw new HttpsError("invalid-argument", "Durée de boost invalide.");
    }

    const contentRef = db.collection("ContentPaies").doc(contentId);
    const userRef = db.collection("Users").doc(uid);

    await db.runTransaction(async (tx) => {
      const [contentDoc, userDoc] = await Promise.all([
        tx.get(contentRef),
        tx.get(userRef),
      ]);

      if (!contentDoc.exists) {
        throw new HttpsError("not-found", "Contenu introuvable.");
      }

      const isOwner = contentDoc.data()?.ownerId === uid;
      const isAdmin = userDoc.data()?.role === "ADM";

      if (!isOwner && !isAdmin) {
        throw new HttpsError(
          "permission-denied",
          "Vous n'êtes pas propriétaire de ce contenu."
        );
      }

      const now = Date.now();
      const endDate = now + durationDays * 24 * 60 * 60 * 1000;

      if (!isAdmin && price > 0) {
        const balance = ((userDoc.data()?.votre_solde_principal ?? 0) as number);
        if (balance < price) {
          throw new HttpsError(
            "resource-exhausted",
            `Solde insuffisant — ${balance} FCFA disponibles, ${price} FCFA requis.`
          );
        }
        tx.update(userRef, {
          votre_solde_principal: FieldValue.increment(-price),
        });
      }

      tx.update(contentRef, {
        isBoosted: true,
        boostStartDate: now,
        boostEndDate: endDate,
        boostDurationDays: durationDays,
        boostAmountPaid: isAdmin ? 0 : price,
        boostedByAdmin: isAdmin,
      });
    });

    return { success: true };
  }
);

// ── securePurchase ────────────────────────────────────────────────────────────
// Callable sécurisé : vérifie le solde, déduit, crédite créateur + affilié.
export const securePurchase = onCall(
  { timeoutSeconds: 30, memory: "256MiB", cpu: 1 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentification requise.");
    }

    const { contentId, promoCodeId, affiliateId } = request.data as {
      contentId?: string;
      promoCodeId?: string;
      affiliateId?: string;
    };
    if (!contentId) {
      throw new HttpsError("invalid-argument", "contentId requis.");
    }

    const uid = request.auth.uid;

    // Pré-vérification : déjà acheté ?
    const existingPurchase = await db
      .collection("ContentPaie_purchases")
      .where("userId", "==", uid)
      .where("contentId", "==", contentId)
      .limit(1)
      .get();

    if (!existingPurchase.empty) {
      throw new HttpsError("already-exists", "Vous avez déjà acheté ce contenu.");
    }

    // Pré-requête affilié (les requêtes ne sont pas permises dans une transaction)
    let affiliateLinkRef: FirebaseFirestore.DocumentReference | null = null;
    if (affiliateId) {
      const q = await db
        .collection("AffiliateLinks")
        .where("affiliateId", "==", affiliateId)
        .where("contentId", "==", contentId)
        .limit(1)
        .get();
      if (!q.empty) affiliateLinkRef = q.docs[0].ref;
    }

    // Charger le code promo si fourni
    let promoData: FirebaseFirestore.DocumentData | null = null;
    if (promoCodeId) {
      const promoDoc = await db.collection("PromoCodes").doc(promoCodeId).get();
      if (promoDoc.exists) promoData = promoDoc.data() ?? null;
    }

    let purchaseId = "";

    await db.runTransaction(async (tx) => {
      const contentRef = db.collection("ContentPaies").doc(contentId);
      const buyerRef = db.collection("Users").doc(uid);

      const [contentDoc, buyerDoc] = await Promise.all([
        tx.get(contentRef),
        tx.get(buyerRef),
      ]);

      if (!contentDoc.exists) {
        throw new HttpsError("not-found", "Contenu introuvable.");
      }

      const content = contentDoc.data()!;
      const isFree = content.isFree === true;
      const isAdmin = buyerDoc.data()?.role === "ADM";

      if (isFree || isAdmin) {
        throw new HttpsError("already-exists", "Ce contenu est déjà accessible gratuitement.");
      }

      // Calcul prix effectif côté serveur (flash sale vérifiée ici)
      const now = Date.now();
      const isFlashSale =
        content.flashSalePrice != null &&
        content.flashSaleEndDate != null &&
        content.flashSaleEndDate > now;
      let paid: number = isFlashSale ? content.flashSalePrice : content.price;

      // Appliquer le code promo
      if (promoData) {
        const codeValid =
          promoData.isActive === true &&
          promoData.creatorId === content.ownerId &&
          promoData.contentId === contentId &&          // doit être lié exactement à CE contenu
          (promoData.expiresAt == null || promoData.expiresAt > now) &&
          (promoData.maxUses == null || promoData.usedCount < promoData.maxUses);

        if (codeValid) {
          if (promoData.type === "percent") {
            paid = paid * (1 - promoData.value / 100);
          } else {
            paid = Math.max(0, paid - promoData.value);
          }
        }
      }

      // Vérification et déduction du solde acheteur
      const balance = ((buyerDoc.data()?.votre_solde_principal ?? 0) as number);
      if (balance < paid) {
        throw new HttpsError(
          "resource-exhausted",
          `Solde insuffisant — ${balance} FCFA disponibles, ${Math.ceil(paid)} FCFA requis.`
        );
      }
      tx.update(buyerRef, {
        votre_solde_principal: FieldValue.increment(-paid),
      });

      // Calcul splits (12% app, jamais affiché côté client)
      const creatorBaseRate = 0.88;
      let affilieurAmount = 0;
      let creatorAmount: number;

      if (affiliateId && content.affiliationEnabled) {
        const affiliRate = Math.min(
          Math.max(content.affiliationRate ?? 0, 0.05),
          0.40
        );
        affilieurAmount = paid * affiliRate;
        creatorAmount = paid * (creatorBaseRate - affiliRate);
      } else {
        creatorAmount = paid * creatorBaseRate;
      }

      // Créer le doc d'achat
      const purchaseRef = db.collection("ContentPaie_purchases").doc();
      purchaseId = purchaseRef.id;
      tx.set(purchaseRef, {
        userId: uid,
        contentId,
        ownerId: content.ownerId,
        amountPaid: paid,
        ownerEarnings: creatorAmount,
        type: affiliateId ? "affiliate" : "direct",
        ...(affiliateId ? { affiliateId, affilieurAmount } : {}),
        promoCodeId: promoCodeId ?? null,
        purchaseDate: FieldValue.serverTimestamp(),
      });

      // Incrémenter les ventes du contenu
      tx.update(contentRef, { sales: FieldValue.increment(1) });

      // Créditer le créateur
      const creatorUpdate: { [key: string]: FieldValue } = {
        solde_ventes: FieldValue.increment(creatorAmount),
        votre_solde_principal: FieldValue.increment(creatorAmount),
      };
      if (promoCodeId) {
        creatorUpdate.solde_promo = FieldValue.increment(creatorAmount);
      }
      tx.update(db.collection("Users").doc(content.ownerId), creatorUpdate);

      // Créditer l'affilié
      if (affiliateId && affilieurAmount > 0) {
        tx.update(db.collection("Users").doc(affiliateId), {
          solde_affiliation: FieldValue.increment(affilieurAmount),
          votre_solde_principal: FieldValue.increment(affilieurAmount),
        });
        if (affiliateLinkRef) {
          tx.update(affiliateLinkRef, {
            sales: FieldValue.increment(1),
            totalEarned: FieldValue.increment(affilieurAmount),
          });
        }
      }

      // Marquer le code promo comme utilisé
      if (promoCodeId) {
        tx.update(db.collection("PromoCodes").doc(promoCodeId), {
          usedCount: FieldValue.increment(1),
        });
      }

      // Enregistrement des transactions dans l'historique
      const tsNow = Date.now();
      const contentTitle = (content.title as string | undefined) ?? "Contenu payant";

      // Transaction acheteur (débit)
      tx.set(db.collection("TransactionSoldes").doc(), {
        user_id: uid,
        type: "DEPENSE",
        statut: "VALIDER",
        description: `Achat : ${contentTitle}`,
        montant: paid,
        frais: 0,
        montant_total: paid,
        methode_paiement: "COMMISSION",
        id_transaction_cinetpay: purchaseId,
        createdAt: tsNow,
        updatedAt: tsNow,
      });

      // Transaction créateur (crédit)
      tx.set(db.collection("TransactionSoldes").doc(), {
        user_id: content.ownerId,
        type: "GAIN",
        statut: "VALIDER",
        description: `Vente : ${contentTitle}`,
        montant: creatorAmount,
        frais: 0,
        montant_total: creatorAmount,
        methode_paiement: "COMMISSION",
        id_transaction_cinetpay: purchaseId,
        createdAt: tsNow,
        updatedAt: tsNow,
      });

      // Transaction affilié (crédit) si applicable
      if (affiliateId && affilieurAmount > 0) {
        tx.set(db.collection("TransactionSoldes").doc(), {
          user_id: affiliateId,
          type: "GAIN",
          statut: "VALIDER",
          description: `Commission affiliation : ${contentTitle}`,
          montant: affilieurAmount,
          frais: 0,
          montant_total: affilieurAmount,
          methode_paiement: "COMMISSION",
          id_transaction_cinetpay: purchaseId,
          createdAt: tsNow,
          updatedAt: tsNow,
        });
      }
    });

    return { success: true, purchaseId };
  }
);
