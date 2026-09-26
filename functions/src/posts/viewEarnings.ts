import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
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

/** Barème unique (CRON + encaissement manuel) : /config/monetization, sinon valeurs par défaut. */
async function loadMonetizationConfig(): Promise<{ baseViewRate: number; scoreTiers: ScoreTier[] }> {
  const configSnap = await db.collection("config").doc("monetization").get();
  const configData = configSnap.data() ?? {};
  return {
    baseViewRate: configData.baseViewRate ?? DEFAULT_BASE_RATE,
    scoreTiers: (configData.scoreTiers as ScoreTier[] | undefined) ?? DEFAULT_TIERS,
  };
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
    const { baseViewRate, scoreTiers } = await loadMonetizationConfig();

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

      // Transaction visible dans l'historique de l'utilisateur (TransactionSoldes)
      const txRef = db.collection("TransactionSoldes").doc();
      batch.set(txRef, {
        id: txRef.id,
        user_id: doc.id,
        methode_paiement: "vues_posts",
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

const MIN_CASH_FCFA = 1000;
const CASH_COOLDOWN_MS = 60 * 1000;

/**
 * cashViewEarnings — encaissement manuel des gains de vues (page « Mes gains »).
 *
 * Utilise le MÊME compteur que le CRON (totalViewsEarningsCredited) : une vue payée par
 * l'un ne peut plus être payée par l'autre. Avant ce correctif, l'encaissement manuel
 * calculait totalPostUniqueViews × taux − postViewsTotalCashed et ignorait les vues déjà
 * créditées par le CRON (double paiement).
 */
export const cashViewEarnings = onCall(
  { region: "europe-west1", timeoutSeconds: 30, memory: "256MiB" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Authentification requise.");
    const uid = request.auth.uid;
    const amount = Number((request.data as { amount?: unknown })?.amount);
    if (!Number.isFinite(amount) || amount < MIN_CASH_FCFA) {
      throw new HttpsError("invalid-argument", `Montant minimum : ${MIN_CASH_FCFA} FCFA.`);
    }

    const { baseViewRate, scoreTiers } = await loadMonetizationConfig();
    const userRef = db.collection("Users").doc(uid);

    return db.runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      if (!snap.exists) throw new HttpsError("not-found", "Compte introuvable.");
      const data = snap.data()!;
      const now = Date.now();
      if (now - (data.lastViewCashAt ?? 0) < CASH_COOLDOWN_MS) {
        throw new HttpsError("resource-exhausted", "Encaissement déjà en cours, réessaie dans une minute.");
      }

      const totalViews: number = data.totalPostUniqueViews ?? 0;
      const credited: number = data.totalViewsEarningsCredited ?? 0;
      const pendingViews = Math.max(0, totalViews - credited);
      const { multiplier } = getMultiplierForScore(data.creatorScore ?? 0, scoreTiers);
      const rate = baseViewRate * multiplier;
      const available = Math.floor(pendingViews * rate * 100) / 100;
      if (rate <= 0 || amount > available) {
        throw new HttpsError("failed-precondition", "Montant supérieur aux gains disponibles.", { available });
      }

      const viewsUsed = Math.min(pendingViews, Math.ceil(amount / rate));
      tx.update(userRef, {
        votre_solde_principal: admin.firestore.FieldValue.increment(amount),
        votre_solde: admin.firestore.FieldValue.increment(amount),
        postViewsTotalCashed: admin.firestore.FieldValue.increment(amount),
        totalViewsEarningsCredited: admin.firestore.FieldValue.increment(viewsUsed),
        lastViewCashAt: now,
      });
      const txRef = db.collection("TransactionSoldes").doc();
      tx.set(txRef, {
        id: txRef.id,
        user_id: uid,
        type: "ENCAISSEMENT_VUES_POST",
        statut: "VALIDER",
        montant: amount,
        description: `Encaissement ${Math.round(amount)} FCFA — ${viewsUsed} vues posts`,
        methode_paiement: "solde_principal",
        createdAt: now,
        updatedAt: now,
      });
      return { success: true, amount, viewsUsed };
    });
  }
);
