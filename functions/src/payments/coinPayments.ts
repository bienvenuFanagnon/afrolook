import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";

/**
 * payWithCoins — paiement en pièces des achats numériques sur iPhone (règle App Store 3.1.1) :
 * les pièces sont achetées via l'App Store, donc tout contenu débloqué avec elles l'est via
 * un achat intégré. Le prix est TOUJOURS recalculé ici depuis la base (jamais celui du
 * téléphone), converti au taux de la recharge : pièces = prix FCFA × 2,5.
 * Le débit est fait ici ; l'app active ensuite l'accès comme pour un paiement FCFA.
 */
const COINS_PER_FCFA = 2.5; // 25 pièces pour 10 FCFA (CoinGiftService.coinsPerFcfa / fcfaBase)

// Grille Premium / Gold : identique à AfrolookAbonnement (lib/models/model_data.dart).
const PREMIUM_BASE = 200;
const GOLD_BASE = 500;
const PREMIUM_REDUCTIONS: Record<number, number> = { 3: 100, 4: 100, 6: 200, 12: 500 };
const GOLD_REDUCTIONS: Record<number, number> = { 2: 50, 3: 150, 6: 500, 12: 1500 };
const OFFICIAL_ACCOUNT_PRICE = 5000; // _kSubscriptionAmount (official_account_service.dart)
const LIVE_PARTICIPANT_PRICE = 100;  // rejoindre un live comme participant (livePage.dart)

type Kind = "premium" | "gold" | "official" | "group" | "content" | "pronostic" | "canal"
  | "live_entry" | "live_participant" | "ad" | "ad_renew" | "profile_boost";

// Tarifs publicité / boost de profil : AdConfig/pricing.durations (AdConfigService), sinon défauts.
const AD_DEFAULT_PRICES: Record<number, number> = { 1: 1500, 2: 2500, 4: 4500, 12: 10000, 24: 18000, 52: 30000 };
const AD_COMBINED_FACTOR = 1.5; // publicité + boost de profil (user_create_advertisement_page)

async function adPrice(weeks: number): Promise<number> {
  let prices = AD_DEFAULT_PRICES;
  const doc = await db.collection("AdConfig").doc("pricing").get();
  const durations = doc.data()?.durations;
  if (Array.isArray(durations) && durations.length) {
    prices = {};
    for (const d of durations) prices[num(d?.weeks)] = num(d?.price);
  }
  const price = prices[weeks];
  if (!price) throw new HttpsError("invalid-argument", "Durée invalide.");
  return price;
}

const LABELS: Record<Kind, string> = {
  premium: "Abonnement Premium",
  gold: "Abonnement Gold",
  official: "Compte officiel",
  group: "Abonnement à un groupe",
  content: "Contenu payant",
  pronostic: "Participation à un pronostic",
  canal: "Abonnement à un canal",
  live_entry: "Accès à un live",
  live_participant: "Participation à un live",
  ad: "Publicité",
  ad_renew: "Renouvellement de publicité",
  profile_boost: "Boost de profil",
};

function num(v: unknown): number {
  return typeof v === "number" && Number.isFinite(v) ? v : 0;
}

async function docField(collection: string, id: string | undefined, field: string): Promise<number> {
  if (!id) throw new HttpsError("invalid-argument", "Référence manquante.");
  const doc = await db.collection(collection).doc(id).get();
  if (!doc.exists) throw new HttpsError("not-found", "Contenu introuvable.");
  return num(doc.data()![field]);
}

async function priceFcfa(kind: Kind, refId: string | undefined, dureeMois: number,
  weeks: number, combined: boolean): Promise<number> {
  switch (kind) {
    case "premium":
    case "gold": {
      if (![1, 2, 3, 4, 6, 12].includes(dureeMois)) throw new HttpsError("invalid-argument", "Durée invalide.");
      const base = kind === "premium" ? PREMIUM_BASE : GOLD_BASE;
      const reductions = kind === "premium" ? PREMIUM_REDUCTIONS : GOLD_REDUCTIONS;
      return dureeMois * base - (reductions[dureeMois] ?? 0);
    }
    case "official": return OFFICIAL_ACCOUNT_PRICE;
    case "group": return docField("GroupChats", refId, "subscription_price");
    case "content": return docField("ContentPaies", refId, "price");
    case "pronostic": return docField("Pronostics", refId, "prixParticipation");
    case "canal": return docField("Canaux", refId, "subscriptionPrice");
    case "live_entry": return docField("lives", refId, "participationFee");
    case "live_participant": return LIVE_PARTICIPANT_PRICE;
    case "ad": {
      const base = await adPrice(weeks);
      return combined ? Math.round(base * AD_COMBINED_FACTOR) : base;
    }
    case "ad_renew":
    case "profile_boost": return adPrice(weeks);
  }
}

export const payWithCoins = onCall(
  { timeoutSeconds: 30, memory: "256MiB" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Authentification requise.");
    const uid = request.auth.uid;
    const { kind, refId, dureeMois, weeks, combined } = request.data as {
      kind?: string; refId?: string; dureeMois?: number; weeks?: number; combined?: boolean;
    };
    if (!kind || !(kind in LABELS)) throw new HttpsError("invalid-argument", "Achat inconnu.");

    const price = await priceFcfa(kind as Kind, refId, Math.floor(num(dureeMois)) || 1,
      Math.floor(num(weeks)), combined === true);
    if (price <= 0) throw new HttpsError("failed-precondition", "Ce contenu est gratuit.");
    const coins = Math.ceil(price * COINS_PER_FCFA);
    const userRef = db.collection("Users").doc(uid);

    return db.runTransaction(async (tx) => {
      const userDoc = await tx.get(userRef);
      if (!userDoc.exists) throw new HttpsError("not-found", "Compte introuvable.");
      const balance = num(userDoc.data()!["giftCoinsBalance"]);
      if (balance < coins) {
        throw new HttpsError("resource-exhausted", "Solde de pièces insuffisant.", { coins, balance });
      }
      const now = Date.now();
      tx.update(userRef, {
        giftCoinsBalance: FieldValue.increment(-coins),
        totalGiftCoinsSpent: FieldValue.increment(coins),
        updatedAt: now,
      });
      const txRef = db.collection("TransactionSoldes").doc();
      tx.set(txRef, {
        id: txRef.id,
        user_id: uid,
        type: "DEPENSE",
        statut: "VALIDER",
        description: `${LABELS[kind as Kind]} — ${coins} pièces`,
        montant: coins,
        frais: 0,
        montant_total: coins,
        methode_paiement: "pieces",
        createdAt: now,
        updatedAt: now,
        purchaseKind: kind,
        purchaseRefId: refId ?? null,
        priceFcfa: price,
      });
      return { success: true, coins, priceFcfa: price };
    });
  }
);
