import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { FieldValue } from "firebase-admin/firestore";
import { AppStoreServerAPIClient, Environment, APIException } from "@apple/app-store-server-library";
import { db } from "../shared/firebase";
import { appAccountTokenFor, lockFieldsAfterChange } from "../shared/coin_locks";
import { recordCoinSale } from "./coinPurchase";

/** Part conservée par Apple (pas d'inscription au Small Business Program). */
const APPLE_COMMISSION = 0.3;

// Clé "In-App Purchase" générée dans App Store Connect (Utilisateurs et accès → Intégrations).
const APPLE_IAP_PRIVATE_KEY = defineSecret("APPLE_IAP_PRIVATE_KEY"); // contenu du fichier .p8
const APPLE_IAP_KEY_ID = defineSecret("APPLE_IAP_KEY_ID");
const APPLE_IAP_ISSUER_ID = defineSecret("APPLE_IAP_ISSUER_ID");

const BUNDLE_ID = "com.afrotok.afrotok";

// Produits consommables App Store Connect → pièces créditées. Source de vérité côté serveur :
// le nombre de pièces ne vient jamais de l'app. Doit correspondre à CoinPack.appleProducts (Flutter).
export const APPLE_COIN_PRODUCTS: Record<string, number> = {
  // Grille 2026-09-27 (prix Mobile Money + 30 % Apple) — nouveaux produits App Store Connect
  "com.afrotok.afrotok.coins1000": 1000, // 0,99 $
  "com.afrotok.afrotok.coins4000": 4000, // 3,99 $
  "com.afrotok.afrotok.coins10000": 10000, // 9,99 $
  // Anciens produits (jamais approuvés) : conservés pour créditer d'éventuels achats de test en attente
  "com.afrotok.afrotok.coins1200": 1200,
  "com.afrotok.afrotok.coins5500": 5500,
  "com.afrotok.afrotok.coins14500": 14500,
};

type AppleTransaction = {
  transactionId?: string;
  originalTransactionId?: string;
  bundleId?: string;
  productId?: string;
  type?: string;
  quantity?: number;
  appAccountToken?: string;
  purchaseDate?: number;
  revocationDate?: number;
  environment?: string;
  price?: number;     // prix payé, en millièmes de la devise (ex. 990 = 0,99)
  currency?: string;  // devise ISO 4217 (USD, EUR, XOF…)
  storefront?: string;
};

function decodeJws<T>(jws: string): T {
  const part = jws.split(".")[1];
  if (!part) throw new Error("JWS invalide");
  return JSON.parse(Buffer.from(part, "base64url").toString("utf8")) as T;
}

function apiClient(env: Environment): AppStoreServerAPIClient {
  return new AppStoreServerAPIClient(
    APPLE_IAP_PRIVATE_KEY.value().replace(/\\n/g, "\n"),
    APPLE_IAP_KEY_ID.value(),
    APPLE_IAP_ISSUER_ID.value(),
    BUNDLE_ID,
    env,
  );
}

/**
 * Lit la transaction directement chez Apple (serveur authentifié par notre clé) : les données
 * ne viennent pas du téléphone, donc pas besoin de vérifier la signature du JWS.
 * Production d'abord, puis Sandbox (TestFlight et review Apple achètent en Sandbox).
 */
async function fetchAppleTransaction(transactionId: string): Promise<AppleTransaction | null> {
  for (const env of [Environment.PRODUCTION, Environment.SANDBOX]) {
    try {
      const res = await apiClient(env).getTransactionInfo(transactionId);
      if (res.signedTransactionInfo) return decodeJws<AppleTransaction>(res.signedTransactionInfo);
    } catch (err) {
      const status = err instanceof APIException ? err.httpStatusCode : 0;
      if (status === 404 || status === 400) continue;
      // La production renvoie 401 tant qu'aucun achat intégré n'est approuvé : on tente la sandbox
      // (TestFlight et review Apple), sinon les achats de la review ne seraient jamais crédités.
      if (status === 401 && env === Environment.PRODUCTION) continue;
      throw err;
    }
  }
  return null;
}

/**
 * verifyApplePurchase — appelée par l'app après un achat StoreKit. Vérifie la transaction
 * auprès d'Apple puis crédite les pièces (une seule fois par transaction). Les pièces achetées
 * sont verrouillées : dépensables mais pas convertibles en argent.
 */
export const verifyApplePurchase = onCall(
  { secrets: [APPLE_IAP_PRIVATE_KEY, APPLE_IAP_KEY_ID, APPLE_IAP_ISSUER_ID], timeoutSeconds: 30, memory: "256MiB" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Authentification requise.");
    const uid = request.auth.uid;
    const transactionId = String((request.data as { transactionId?: unknown })?.transactionId ?? "");
    if (!/^\d{1,30}$/.test(transactionId)) {
      throw new HttpsError("invalid-argument", "Transaction invalide.");
    }

    const purchaseRef = db.collection("ApplePurchases").doc(transactionId);
    const existing = await purchaseRef.get();
    if (existing.exists) {
      const data = existing.data()!;
      if (data["userId"] !== uid) throw new HttpsError("permission-denied", "Achat lié à un autre compte.");
      return { success: true, alreadyCredited: true, coins: data["coins"] };
    }

    let tx: AppleTransaction | null;
    try {
      tx = await fetchAppleTransaction(transactionId);
    } catch (err) {
      console.error("[verifyApplePurchase] API Apple indisponible :", err);
      throw new HttpsError("unavailable", "Vérification Apple indisponible, réessaie plus tard.");
    }
    if (!tx) throw new HttpsError("not-found", "Transaction introuvable chez Apple.");

    const coinsPerUnit = APPLE_COIN_PRODUCTS[tx.productId ?? ""];
    if (tx.bundleId !== BUNDLE_ID || !coinsPerUnit || tx.type !== "Consumable") {
      throw new HttpsError("invalid-argument", "Produit non reconnu.");
    }
    if (tx.revocationDate) throw new HttpsError("failed-precondition", "Achat remboursé par Apple.");
    if (tx.appAccountToken && tx.appAccountToken.toLowerCase() !== appAccountTokenFor(uid)) {
      throw new HttpsError("permission-denied", "Achat lié à un autre compte.");
    }

    const coins = coinsPerUnit * Math.max(1, tx.quantity ?? 1);
    const userRef = db.collection("Users").doc(uid);
    // Prix réellement payé (Apple : millièmes de la devise) et net estimé après la part d'Apple
    const amountPaid = typeof tx.price === "number" ? Math.round(tx.price) / 1000 : null;
    const currency = tx.currency ?? null;
    const netEstimate = amountPaid !== null ? Math.round(amountPaid * (1 - APPLE_COMMISSION) * 100) / 100 : null;

    return db.runTransaction(async (t) => {
      const [purchaseDoc, userDoc] = await Promise.all([t.get(purchaseRef), t.get(userRef)]);
      if (purchaseDoc.exists) {
        if (purchaseDoc.data()!["userId"] !== uid) throw new HttpsError("permission-denied", "Achat lié à un autre compte.");
        return { success: true, alreadyCredited: true, coins: purchaseDoc.data()!["coins"] };
      }
      if (!userDoc.exists) throw new HttpsError("not-found", "Compte introuvable.");

      const now = Date.now();
      t.set(purchaseRef, {
        transactionId,
        originalTransactionId: tx!.originalTransactionId ?? null,
        userId: uid,
        productId: tx!.productId,
        coins,
        environment: tx!.environment ?? null,
        purchaseDate: tx!.purchaseDate ?? null,
        status: "credited",
        createdAt: now,
      });
      t.update(userRef, {
        giftCoinsBalance: FieldValue.increment(coins),
        totalGiftCoinsPurchased: FieldValue.increment(coins),
        ...lockFieldsAfterChange(userDoc.data(), coins),
        updatedAt: now,
      });
      const txRef = db.collection("TransactionSoldes").doc();
      t.set(txRef, {
        id: txRef.id,
        user_id: uid,
        type: "ACHAT_PIECES",
        statut: "VALIDER",
        description: `Achat de ${coins} pièces via l'App Store`,
        // Nouveau modèle d'achat : montant = pièces, + prix payé, devise et net estimé
        montant: coins,
        coins,
        amountPaid,
        currency,
        netEstimate,
        paymentMethod: "App Store",
        frais: 0,
        montant_total: coins,
        methode_paiement: "apple_iap",
        beneficiaryId: uid,
        createdAt: now,
        updatedAt: now,
        appleTransactionId: transactionId,
      });
      if (amountPaid !== null && currency) recordCoinSale(t, now, coins, amountPaid, currency, netEstimate ?? undefined);
      return { success: true, coins };
    });
  }
);

/**
 * appleServerNotifications — URL à renseigner dans App Store Connect
 * (App → Informations sur l'app → Notifications du serveur App Store, version 2).
 * Remboursement ou révocation : les pièces sont reprises. Le contenu reçu n'est pas cru
 * sur parole : la transaction est relue chez Apple avant toute action.
 */
export const appleServerNotifications = onRequest(
  { secrets: [APPLE_IAP_PRIVATE_KEY, APPLE_IAP_KEY_ID, APPLE_IAP_ISSUER_ID], timeoutSeconds: 60, memory: "256MiB" },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }
    try {
      const signedPayload = (req.body as { signedPayload?: string })?.signedPayload;
      if (!signedPayload) {
        res.status(400).send("signedPayload manquant");
        return;
      }
      const notif = decodeJws<{ notificationType?: string; data?: { signedTransactionInfo?: string } }>(signedPayload);
      if ((notif.notificationType === "REFUND" || notif.notificationType === "REVOKE")
          && notif.data?.signedTransactionInfo) {
        const claimed = decodeJws<AppleTransaction>(notif.data.signedTransactionInfo);
        if (claimed.transactionId) await handleRefund(claimed.transactionId);
      }
      res.status(200).send("OK");
    } catch (err) {
      console.error("[appleServerNotifications]", err);
      // 500 : Apple renverra la notification plus tard.
      res.status(500).send("Erreur");
    }
  }
);

async function handleRefund(transactionId: string): Promise<void> {
  const tx = await fetchAppleTransaction(transactionId);
  if (!tx?.revocationDate) return;

  const purchaseRef = db.collection("ApplePurchases").doc(transactionId);
  await db.runTransaction(async (t) => {
    const purchaseDoc = await t.get(purchaseRef);
    if (!purchaseDoc.exists || purchaseDoc.data()!["status"] !== "credited") return;
    const purchase = purchaseDoc.data()!;
    const userRef = db.collection("Users").doc(purchase["userId"]);
    const userDoc = await t.get(userRef);
    const coins = purchase["coins"] as number;
    const now = Date.now();

    t.update(purchaseRef, { status: "refunded", refundedAt: now, revocationDate: tx.revocationDate });
    if (!userDoc.exists) return;
    // Le solde peut devenir négatif si les pièces ont déjà été dépensées : il faudra recharger.
    t.update(userRef, {
      giftCoinsBalance: FieldValue.increment(-coins),
      ...lockFieldsAfterChange(userDoc.data(), -coins),
      updatedAt: now,
    });
    const txRef = db.collection("TransactionSoldes").doc();
    t.set(txRef, {
      id: txRef.id,
      user_id: purchase["userId"],
      type: "DEPENSE",
      statut: "VALIDER",
      description: `Remboursement App Store : ${coins} pièces reprises`,
      montant: coins,
      frais: 0,
      montant_total: coins,
      methode_paiement: "apple_iap",
      createdAt: now,
      updatedAt: now,
      appleTransactionId: transactionId,
    });
  });
}
