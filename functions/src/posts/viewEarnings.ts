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

/** Barème (encaissement manuel + affichage app) : /config/monetization, sinon valeurs par défaut. */
async function loadMonetizationConfig(): Promise<{ baseViewRate: number; scoreTiers: ScoreTier[] }> {
  const configSnap = await db.collection("config").doc("monetization").get();
  const configData = configSnap.data() ?? {};
  return {
    baseViewRate: configData.baseViewRate ?? DEFAULT_BASE_RATE,
    scoreTiers: (configData.scoreTiers as ScoreTier[] | undefined) ?? DEFAULT_TIERS,
  };
}

const MIN_CASH_FCFA = 1000;
const CASH_COOLDOWN_MS = 60 * 1000;

/**
 * cashViewEarnings — encaissement manuel des gains de vues (page « Mes gains »).
 *
 * Seul mode de paiement des vues : l'utilisateur décide quand et combien il encaisse.
 * totalViewsEarningsCredited = vues déjà payées (y compris par l'ancien paiement automatique
 * computeViewEarnings, supprimé le 2026-09-27) ; seules les vues au-delà sont encaissables.
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
    // Posts NON monétisés du créateur : leurs vues ne rapportent rien (champ monetized == false ;
    // absent = ancien post = monétisé). Contrôle côté serveur : les anciennes versions de l'app, qui ne
    // connaissent pas cette règle, incrémentent quand même le compteur de vues.
    const nonMonetized = await db.collection("Posts").where("user_id", "==", uid).where("monetized", "==", false).select().get();
    const nonMonetizedIds = nonMonetized.docs.map((d) => d.id);

    return db.runTransaction(async (tx) => {
      const snap = await tx.get(userRef);
      if (!snap.exists) throw new HttpsError("not-found", "Compte introuvable.");
      const data = snap.data()!;
      const now = Date.now();
      if (now - (data.lastViewCashAt ?? 0) < CASH_COOLDOWN_MS) {
        throw new HttpsError("resource-exhausted", "Encaissement déjà en cours, réessaie dans une minute.");
      }

      const perPost = (data.postViewsPerPost ?? {}) as Record<string, number>;
      const nonMonetizedViews = nonMonetizedIds.reduce((n, id) => n + (Number(perPost[id]) || 0), 0);
      const totalViews: number = Math.max(0, (data.totalPostUniqueViews ?? 0) - nonMonetizedViews);
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
