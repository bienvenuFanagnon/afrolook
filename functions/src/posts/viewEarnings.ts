import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

const db = admin.firestore();

// Taux par défaut si le document /config/monetization n'existe pas encore
const DEFAULT_BASE_RATE = 1.0; // 1 FCFA max par vue

interface ScoreTier {
  minScore: number;
  multiplier: number; // fraction du taux de base (0.0–1.0)
  label: string;
}

const DEFAULT_TIERS: ScoreTier[] = [
  { minScore: 80, multiplier: 1.00, label: "Élite" },
  { minScore: 50, multiplier: 0.80, label: "Expert" },
  { minScore: 25, multiplier: 0.60, label: "Avancé" },
  { minScore: 10, multiplier: 0.40, label: "Standard" },
  { minScore: 0,  multiplier: 0.20, label: "Débutant" },
];

function getMultiplierForScore(
  score: number,
  tiers: ScoreTier[]
): { multiplier: number; label: string } {
  const sorted = [...tiers].sort((a, b) => b.minScore - a.minScore);
  for (const tier of sorted) {
    if (score >= tier.minScore) return tier;
  }
  return { multiplier: 0.20, label: "Débutant" };
}

/**
 * CRON quotidien — crédite les gains de vues dans votre_solde_principal.
 *
 * Pour chaque créateur :
 *   pendingViews = totalPostUniqueViews − totalViewsEarningsCredited
 *   rate         = baseViewRate × multiplier(creatorScore)
 *   earnings     = pendingViews × rate
 *
 * Config Firestore : /config/monetization
 *   { baseViewRate: 1.0, scoreTiers: [...] }
 */
export const computeViewEarnings = onSchedule(
  { schedule: "every 24 hours", region: "europe-west1" },
  async () => {
    // 1. Lire la config de monétisation
    const configSnap = await db.collection("config").doc("monetization").get();
    const configData = configSnap.data() ?? {};
    const baseViewRate: number = configData.baseViewRate ?? DEFAULT_BASE_RATE;
    const scoreTiers: ScoreTier[] =
      (configData.scoreTiers as ScoreTier[] | undefined) ?? DEFAULT_TIERS;

    // 2. Récupérer tous les créateurs qui ont des vues non créditées
    const usersSnap = await db
      .collection("Users")
      .where("totalPostUniqueViews", ">", 0)
      .get();

    let credited = 0;
    const BATCH_SIZE = 400;
    let batch = db.batch();
    let opsInBatch = 0;

    const flushBatch = async () => {
      if (opsInBatch > 0) {
        await batch.commit();
        batch = db.batch();
        opsInBatch = 0;
      }
    };

    for (const doc of usersSnap.docs) {
      const data = doc.data();
      const totalViews: number = data.totalPostUniqueViews ?? 0;
      const alreadyCredited: number = data.totalViewsEarningsCredited ?? 0;
      const pendingViews = totalViews - alreadyCredited;

      if (pendingViews <= 0) continue;

      const creatorScore: number = data.creatorScore ?? 0;
      const { multiplier, label } = getMultiplierForScore(creatorScore, scoreTiers);
      const ratePerView = baseViewRate * multiplier;
      const earnings = Math.round(pendingViews * ratePerView * 100) / 100;

      if (earnings <= 0) continue;

      // Mise à jour du solde et du compteur de vues créditées
      batch.update(doc.ref, {
        votre_solde_principal: admin.firestore.FieldValue.increment(earnings),
        totalViewsEarningsCredited: totalViews,
      });

      // Transaction dans le sous-collection de l'utilisateur
      const txRef = db
        .collection("Users")
        .doc(doc.id)
        .collection("transactionsSolde")
        .doc();
      batch.set(txRef, {
        type: "GAIN",
        montant: earnings,
        description: `Vues posts · ${pendingViews} vue${pendingViews > 1 ? "s" : ""} × ${ratePerView.toFixed(2)} FCFA (tier ${label})`,
        statut: "VALIDER",
        createdAt: Date.now(),
      });

      opsInBatch += 2;
      credited++;

      if (opsInBatch >= BATCH_SIZE) {
        await flushBatch();
      }
    }

    await flushBatch();
    console.log(`[computeViewEarnings] ${credited} créateurs crédités`);
  }
);
