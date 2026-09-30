import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { CREATION_PRICE_COINS, creationCost, creditFieldOf } from "./creationFees";
import { CREATOR_SHARE, CommissionSource, creditSponsors, recordAppCommission, resolveSponsors } from "./coinShares";

/**
 * payWithCoins — paiement en pièces de TOUS les achats de l'app (Android et iPhone),
 * sauf les contenus payants (encore en FCFA, voir securePurchase).
 *
 * - Le prix est TOUJOURS recalculé ici depuis la base (jamais celui du téléphone).
 * - Prix fixés par les créateurs (groupe, canal, live privé, pronostic) : champ en pièces
 *   (`*_coins` / `*Coins`) ; à défaut, ancien prix FCFA × 2,5 (taux de la recharge).
 * - Prix de l'app (Premium, Gold, compte officiel, pubs, boosts) : barème FCFA × 2,5.
 * - Part du créateur (groupe, canal, live privé) : 70 % versés en Pièces gagnées
 *   (convertibles en argent) ; le reste va à l'app (AppData.solde_gain_pieces).
 * - Parrainages (règle unique, prise sur la part de l'app) : 2,5 % au parrain de celui
 *   qui paie, 2,5 % au parrain du créateur, en Pièces gagnées.
 */
const COINS_PER_FCFA = 2.5; // 25 pièces pour 10 FCFA
// Grille Premium / Gold : identique à AfrolookAbonnement (lib/models/model_data.dart).
const PREMIUM_BASE = 200;
const GOLD_BASE = 500;
const PREMIUM_REDUCTIONS: Record<number, number> = { 3: 100, 4: 100, 6: 200, 12: 500 };
const GOLD_REDUCTIONS: Record<number, number> = { 2: 50, 3: 150, 6: 500, 12: 1500 };
const OFFICIAL_ACCOUNT_PRICE = 5000; // _kSubscriptionAmount (official_account_service.dart)
const LIVE_PARTICIPANT_PRICE = 100;  // rejoindre un live comme participant (livePage.dart)

// Tarifs publicité / boost de profil : AdConfig/pricing.durations (AdConfigService), sinon défauts.
const AD_DEFAULT_PRICES: Record<number, number> = { 1: 1500, 2: 2500, 4: 4500, 12: 10000, 24: 18000, 52: 30000 };
const AD_COMBINED_FACTOR = 1.5; // publicité + boost de profil (user_create_advertisement_page)

type Kind = "premium" | "gold" | "official" | "group" | "content" | "canal"
  | "live_entry" | "live_participant" | "ad" | "ad_renew" | "profile_boost" | "product_boost"
  | "entreprise_premium" | "canal_create" | "group_create" | "sticker_pack";

const SOURCES: Record<Kind, CommissionSource> = {
  premium: "premium",
  gold: "gold",
  official: "compte_officiel",
  group: "groupes",
  content: "contenus",
  canal: "canaux",
  live_entry: "lives_prives",
  live_participant: "participation_live",
  ad: "pubs_boosts",
  ad_renew: "pubs_boosts",
  profile_boost: "pubs_boosts",
  product_boost: "pubs_boosts",
  entreprise_premium: "abonnement_entreprise",
  canal_create: "canaux",
  group_create: "groupes",
  sticker_pack: "stickers",
};

const LABELS: Record<Kind, string> = {
  premium: "Abonnement Premium",
  gold: "Abonnement Gold",
  official: "Compte officiel",
  group: "Abonnement à un groupe",
  content: "Contenu payant",
  canal: "Abonnement à un canal",
  live_entry: "Accès à un live privé",
  live_participant: "Participation à un live",
  ad: "Publicité",
  ad_renew: "Renouvellement de publicité",
  profile_boost: "Boost de profil",
  product_boost: "Boost de produit",
  entreprise_premium: "Abonnement entreprise Premium",
  canal_create: "Création d'un canal supplémentaire",
  group_create: "Création d'un groupe supplémentaire",
  sticker_pack: "Pack de stickers",
};

function num(v: unknown): number {
  return typeof v === "number" && Number.isFinite(v) ? v : 0;
}

const toCoins = (fcfa: number) => Math.ceil(fcfa * COINS_PER_FCFA);

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

/** Boost de produit Afroshop : 500 F par tranche de 10 jours, réduction 10/15/20 % (produit_details.dart). */
function productBoostFcfa(days: number): number {
  if (![10, 20, 30, 40].includes(days)) throw new HttpsError("invalid-argument", "Durée invalide.");
  const base = (days / 10) * 500;
  const reduction = ({ 20: 10, 30: 15, 40: 20 } as Record<number, number>)[days] ?? 0;
  return base - (base * reduction) / 100;
}

/** Abonnement entreprise Premium (Afroshop) : 2000 F / 30 j, -4 % jusqu'à 60 j, -10 % au-delà (Subscription.dart). */
function entreprisePremiumFcfa(days: number): number {
  if (days < 30 || days > 365) throw new HttpsError("invalid-argument", "Durée invalide.");
  if (days <= 30) return 2000;
  if (days <= 60) return 2000 * (days / 30) * 0.96;
  return 2000 * (days / 30) * 0.9;
}

interface Priced {
  coins: number;
  ownerId?: string; // bénéficiaire des 70 % (créateur)
}

async function creatorPrice(
  collection: string, id: string | undefined, coinsField: string, fcfaField: string, ownerField?: string,
): Promise<Priced> {
  if (!id) throw new HttpsError("invalid-argument", "Référence manquante.");
  const doc = await db.collection(collection).doc(id).get();
  if (!doc.exists) throw new HttpsError("not-found", "Introuvable.");
  const d = doc.data()!;
  const coins = num(d[coinsField]) > 0 ? Math.ceil(num(d[coinsField])) : toCoins(num(d[fcfaField]));
  return { coins, ownerId: ownerField ? (d[ownerField] as string | undefined) : undefined };
}

async function priceOf(kind: Kind, refId: string | undefined, dureeMois: number,
  weeks: number, combined: boolean, days: number, uid: string): Promise<Priced> {
  switch (kind) {
    case "premium":
    case "gold": {
      if (![1, 2, 3, 4, 6, 12].includes(dureeMois)) throw new HttpsError("invalid-argument", "Durée invalide.");
      const base = kind === "premium" ? PREMIUM_BASE : GOLD_BASE;
      const reductions = kind === "premium" ? PREMIUM_REDUCTIONS : GOLD_REDUCTIONS;
      return { coins: toCoins(dureeMois * base - (reductions[dureeMois] ?? 0)) };
    }
    case "official": return { coins: toCoins(OFFICIAL_ACCOUNT_PRICE) };
    case "group": return creatorPrice("GroupChats", refId, "subscription_price_coins", "subscription_price", "owner_id");
    case "canal": return creatorPrice("Canaux", refId, "subscriptionPriceCoins", "subscriptionPrice", "userId");
    case "live_entry": return creatorPrice("lives", refId, "participationFeeCoins", "participationFee", "hostId");
    case "content": return creatorPrice("ContentPaies", refId, "priceCoins", "price");
    case "live_participant": return { coins: toCoins(LIVE_PARTICIPANT_PRICE) };
    case "ad": {
      const base = await adPrice(weeks);
      return { coins: toCoins(combined ? Math.round(base * AD_COMBINED_FACTOR) : base) };
    }
    case "ad_renew":
    case "profile_boost": return { coins: toCoins(await adPrice(weeks)) };
    case "product_boost": return { coins: toCoins(productBoostFcfa(days)) };
    case "entreprise_premium": return { coins: toCoins(entreprisePremiumFcfa(days)) };
    case "sticker_pack": return creatorPrice("StickerPacks", refId, "priceCoins", "priceCoinsUnused", "creatorId");
    case "canal_create":
    case "group_create": {
      const q = await creationCost(kind === "canal_create" ? "canal" : "group", uid);
      return { coins: q.cost > 0 ? CREATION_PRICE_COINS : 0 };
    }
  }
}

export const payWithCoins = onCall(
  { timeoutSeconds: 30, memory: "256MiB" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Authentification requise.");
    const uid = request.auth.uid;
    const { kind, refId, dureeMois, weeks, combined, days } = request.data as {
      kind?: string; refId?: string; dureeMois?: number; weeks?: number; combined?: boolean; days?: number;
    };
    if (!kind || !(kind in LABELS)) throw new HttpsError("invalid-argument", "Achat inconnu.");

    const { coins, ownerId } = await priceOf(kind as Kind, refId, Math.floor(num(dureeMois)) || 1,
      Math.floor(num(weeks)), combined === true, Math.floor(num(days)), uid);
    if (coins <= 0) throw new HttpsError("failed-precondition", "Ce contenu est gratuit.");
    if (kind === "sticker_pack" && refId) {
      const [pack, own] = await Promise.all([
        db.collection("StickerPacks").doc(refId).get(),
        db.collection("StickerOwnership").doc(`${uid}_${refId}`).get(),
      ]);
      if (!pack.exists || pack.get("status") !== "active") throw new HttpsError("failed-precondition", "Pack indisponible.");
      if (own.exists) throw new HttpsError("already-exists", "Tu possèdes déjà ce pack.");
    }

    // Part du créateur (70 %), sauf s'il paie lui-même
    const creatorId = ownerId && ownerId !== uid ? ownerId : undefined;
    const creatorCoins = creatorId ? Math.floor(coins * CREATOR_SHARE) : 0;

    // Parrainages (hors transaction : requêtes non permises dedans)
    const sponsors = await resolveSponsors(uid, creatorId, coins);
    const sponsorCoins = sponsors.reduce((sum, p) => sum + p.coins, 0);
    const appCoins = coins - creatorCoins - sponsorCoins;

    const userRef = db.collection("Users").doc(uid);
    const label = LABELS[kind as Kind];

    return db.runTransaction(async (tx) => {
      const userDoc = await tx.get(userRef);
      if (!userDoc.exists) throw new HttpsError("not-found", "Compte introuvable.");
      const creatorRef = creatorId ? db.collection("Users").doc(creatorId) : null;
      const creatorDoc = creatorRef ? await tx.get(creatorRef) : null;

      const balance = num(userDoc.data()!["giftCoinsBalance"]);
      if (balance < coins) {
        throw new HttpsError("resource-exhausted", "Solde de pièces insuffisant.", { coins, balance });
      }
      const now = Date.now();

      // 1. Payeur
      tx.update(userRef, {
        giftCoinsBalance: FieldValue.increment(-coins),
        totalGiftCoinsSpent: FieldValue.increment(coins),
        updatedAt: now,
      });
      const payerTx = db.collection("TransactionSoldes").doc();
      tx.set(payerTx, {
        id: payerTx.id,
        user_id: uid,
        type: "DEPENSE",
        statut: "VALIDER",
        description: `${label} — ${coins} pièces`,
        montant: coins,
        frais: 0,
        montant_total: coins,
        methode_paiement: "pieces",
        createdAt: now,
        updatedAt: now,
        purchaseKind: kind,
        purchaseRefId: refId ?? null,
        priceFcfaEquivalent: coins / COINS_PER_FCFA,
      });

      // 2. Créateur : 70 % en Pièces gagnées (convertibles)
      if (creatorRef && creatorDoc?.exists && creatorCoins > 0) {
        tx.update(creatorRef, {
          giftCoinsBalance: FieldValue.increment(creatorCoins),
          totalCoinsEarnedFromSales: FieldValue.increment(creatorCoins),
        });
        const creatorTx = db.collection("TransactionSoldes").doc();
        tx.set(creatorTx, {
          id: creatorTx.id,
          user_id: creatorId,
          type: "GAIN_PIECES",
          statut: "VALIDER",
          description: `${label} — ${creatorCoins} pièces reçues`,
          montant: creatorCoins,
          frais: 0,
          montant_total: creatorCoins,
          methode_paiement: "pieces",
          createdAt: now,
          updatedAt: now,
          purchaseKind: kind,
          purchaseRefId: refId ?? null,
          payerId: uid,
        });
      }

      // 3. Parrains : 2,5 % chacun, en Pièces gagnées
      creditSponsors(tx, sponsors, label, now, { purchaseKind: kind, purchaseRefId: refId ?? null });

      // 4. Live privé : total encaissé par l'hôte (statistique du live, en pièces)
      if (kind === "live_entry" && refId) {
        tx.update(db.collection("lives").doc(refId), {
          paidParticipationTotal: FieldValue.increment(creatorCoins),
        });
      }

      // 4 bis. Création d'un canal / groupe supplémentaire : ticket de création (consommé à la création du document)
      if (kind === "canal_create" || kind === "group_create") {
        tx.update(userRef, { [creditFieldOf(kind === "canal_create" ? "canal" : "group")]: FieldValue.increment(1) });
      }

      // 4 ter. Pack de stickers : droit d'usage enregistré pour l'acheteur
      if (kind === "sticker_pack" && refId) {
        tx.set(db.collection("StickerOwnership").doc(`${uid}_${refId}`), { userId: uid, packId: refId, priceCoins: coins, purchasedAt: now });
        tx.update(db.collection("StickerPacks").doc(refId), { salesCount: FieldValue.increment(1) });
      }

      // 5. App : part restante, enregistrée par source (page admin « Commissions »)
      recordAppCommission(tx, SOURCES[kind as Kind], appCoins, now);

      return { success: true, coins, creatorCoins, priceFcfaEquivalent: coins / COINS_PER_FCFA };
    });
  }
);
