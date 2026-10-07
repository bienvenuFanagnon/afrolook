import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { FieldValue } from "firebase-admin/firestore";
import axios from "axios";
import * as crypto from "crypto";
import { db } from "../shared/firebase";
import { appAccountTokenFor, lockFieldsAfterChange } from "../shared/coin_locks";
import { recordCoinSale } from "./coinPurchase";

/**
 * Achats de pièces via Google Play Billing (Android) — pendant de appleIap.ts.
 * L'app envoie le jeton d'achat ; le serveur le relit chez Google (compte de service Play Console),
 * vérifie produit et compte, crédite les pièces une seule fois puis accuse réception à Google.
 */

// Contenu JSON de la clé du compte de service lié à Google Play Console
// (Utilisateurs et autorisations → rôle « Gérer les commandes et les abonnements »).
const GOOGLE_PLAY_SERVICE_ACCOUNT = defineSecret("GOOGLE_PLAY_SERVICE_ACCOUNT");

const PACKAGE_NAME = "com.afrotok.afrotok";
/** Part conservée par Google (15 % sur la première tranche annuelle, 30 % au-delà : on prend 15 % pour l'estimation). */
const GOOGLE_COMMISSION = 0.15;

// Produits consommables Play Console → pièces créditées. Source de vérité côté serveur :
// le nombre de pièces ne vient jamais de l'app. Doit correspondre à CoinPack.appleProducts (Flutter).
export const PLAY_COIN_PRODUCTS: Record<string, { coins: number; usd: number }> = {
  "com.afrotok.afrotok.coins1000": { coins: 1000, usd: 0.99 },
  "com.afrotok.afrotok.coins4000": { coins: 4000, usd: 3.99 },
  "com.afrotok.afrotok.coins10000": { coins: 10000, usd: 9.99 },
};

type ServiceAccount = { client_email: string; private_key: string; token_uri?: string };

let tokenCache: { token: string; exp: number } | null = null;

/** Jeton OAuth2 du compte de service (JWT RS256 signé localement, valable ~1 h, mis en cache). */
async function accessToken(): Promise<string> {
  if (tokenCache && tokenCache.exp - Date.now() > 60_000) return tokenCache.token;
  const sa = JSON.parse(GOOGLE_PLAY_SERVICE_ACCOUNT.value()) as ServiceAccount;
  const now = Math.floor(Date.now() / 1000);
  const b64 = (o: object) => Buffer.from(JSON.stringify(o)).toString("base64url");
  const unsigned = `${b64({ alg: "RS256", typ: "JWT" })}.${b64({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: sa.token_uri ?? "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  })}`;
  const signature = crypto.createSign("RSA-SHA256").update(unsigned).sign(sa.private_key).toString("base64url");
  const res = await axios.post(
    sa.token_uri ?? "https://oauth2.googleapis.com/token",
    new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: `${unsigned}.${signature}` }).toString(),
    { headers: { "Content-Type": "application/x-www-form-urlencoded" }, timeout: 15000 },
  );
  tokenCache = { token: res.data.access_token as string, exp: Date.now() + Number(res.data.expires_in ?? 3600) * 1000 };
  return tokenCache.token;
}

type PlayPurchase = {
  purchaseState?: number; // 0 achat effectué, 1 annulé, 2 en attente
  consumptionState?: number;
  acknowledgementState?: number; // 0 non, 1 oui
  orderId?: string;
  purchaseTimeMillis?: string;
  purchaseType?: number; // 0 test, 1 promo, 2 récompense ; absent = achat réel
  obfuscatedExternalAccountId?: string;
  quantity?: number;
  regionCode?: string;
};

const BASE = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE_NAME}/purchases/products`;

async function fetchPlayPurchase(productId: string, purchaseToken: string): Promise<PlayPurchase | null> {
  try {
    const res = await axios.get(`${BASE}/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}`, {
      headers: { Authorization: `Bearer ${await accessToken()}` },
      timeout: 15000,
    });
    return res.data as PlayPurchase;
  } catch (err) {
    const status = axios.isAxiosError(err) ? err.response?.status ?? 0 : 0;
    if (status === 400 || status === 404 || status === 410) return null;
    throw err;
  }
}

/** Accuse réception (sinon Google rembourse l'achat au bout de 3 jours). Sans effet si déjà fait. */
async function acknowledge(productId: string, purchaseToken: string): Promise<void> {
  try {
    await axios.post(
      `${BASE}/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}:acknowledge`,
      {},
      { headers: { Authorization: `Bearer ${await accessToken()}` }, timeout: 15000 },
    );
  } catch (err) {
    console.warn("[verifyGooglePlayPurchase] acknowledge :", axios.isAxiosError(err) ? err.response?.data : err);
  }
}

/**
 * verifyGooglePlayPurchase — appelée par l'app après un achat Google Play Billing. Les pièces achetées
 * sont verrouillées : dépensables mais pas convertibles en argent (comme sur l'App Store).
 */
export const verifyGooglePlayPurchase = onCall(
  { secrets: [GOOGLE_PLAY_SERVICE_ACCOUNT], timeoutSeconds: 30, memory: "256MiB" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Authentification requise.");
    const uid = request.auth.uid;
    const data = request.data as { productId?: unknown; purchaseToken?: unknown };
    const productId = String(data?.productId ?? "");
    const purchaseToken = String(data?.purchaseToken ?? "");
    const product = PLAY_COIN_PRODUCTS[productId];
    if (!product || purchaseToken.length < 20 || purchaseToken.length > 2000) {
      throw new HttpsError("invalid-argument", "Achat invalide.");
    }

    // Clé de l'achat : empreinte du jeton (un achat = un jeton unique)
    const key = crypto.createHash("sha256").update(purchaseToken).digest("hex");
    const purchaseRef = db.collection("GooglePlayPurchases").doc(key);
    const existing = await purchaseRef.get();
    if (existing.exists) {
      if (existing.data()!["userId"] !== uid) throw new HttpsError("permission-denied", "Achat lié à un autre compte.");
      return { success: true, alreadyCredited: true, coins: existing.data()!["coins"] };
    }

    let purchase: PlayPurchase | null;
    try {
      purchase = await fetchPlayPurchase(productId, purchaseToken);
    } catch (err) {
      console.error("[verifyGooglePlayPurchase] API Google indisponible :", err);
      throw new HttpsError("unavailable", "Vérification Google Play indisponible, réessaie plus tard.");
    }
    if (!purchase) throw new HttpsError("not-found", "Achat introuvable chez Google Play.");
    if (purchase.purchaseState === 2) throw new HttpsError("unavailable", "Achat en attente de paiement.");
    if (purchase.purchaseState !== 0) throw new HttpsError("failed-precondition", "Achat annulé ou remboursé.");
    if (purchase.obfuscatedExternalAccountId && purchase.obfuscatedExternalAccountId.toLowerCase() !== appAccountTokenFor(uid)) {
      throw new HttpsError("permission-denied", "Achat lié à un autre compte.");
    }

    const coins = product.coins * Math.max(1, Number(purchase.quantity ?? 1));
    const userRef = db.collection("Users").doc(uid);
    const result = await db.runTransaction(async (t) => {
      const [purchaseDoc, userDoc] = await Promise.all([t.get(purchaseRef), t.get(userRef)]);
      if (purchaseDoc.exists) {
        if (purchaseDoc.data()!["userId"] !== uid) throw new HttpsError("permission-denied", "Achat lié à un autre compte.");
        return { success: true, alreadyCredited: true, coins: purchaseDoc.data()!["coins"] as number };
      }
      if (!userDoc.exists) throw new HttpsError("not-found", "Compte introuvable.");

      const now = Date.now();
      const isTest = purchase!.purchaseType === 0;
      t.set(purchaseRef, {
        orderId: purchase!.orderId ?? null,
        userId: uid,
        productId,
        coins,
        regionCode: purchase!.regionCode ?? null,
        purchaseTime: purchase!.purchaseTimeMillis ? Number(purchase!.purchaseTimeMillis) : null,
        test: isTest,
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
      const usd = product.usd * Math.max(1, Number(purchase!.quantity ?? 1));
      t.set(txRef, {
        id: txRef.id,
        user_id: uid,
        type: "ACHAT_PIECES",
        statut: "VALIDER",
        description: `Achat de ${coins} pièces via Google Play`,
        montant: coins,
        coins,
        amountPaid: usd, // prix catalogue en dollars (le prix local réel n'est pas fourni par l'API)
        currency: "USD",
        netEstimate: Math.round(usd * (1 - GOOGLE_COMMISSION) * 100) / 100,
        paymentMethod: "Google Play",
        frais: 0,
        montant_total: coins,
        methode_paiement: "google_play",
        beneficiaryId: uid,
        createdAt: now,
        updatedAt: now,
        googleOrderId: purchase!.orderId ?? null,
      });
      if (!isTest) recordCoinSale(t, now, coins, usd, "USD", Math.round(usd * (1 - GOOGLE_COMMISSION) * 100) / 100);
      return { success: true, coins };
    });

    if (purchase.acknowledgementState !== 1) await acknowledge(productId, purchaseToken);
    return result;
  }
);
