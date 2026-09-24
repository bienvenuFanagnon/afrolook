import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { convertibleCoins } from "../shared/coin_locks";

// Même barème que CoinGiftService.coinsToFcfa (Flutter) : 25 pièces = 10 FCFA, arrondi favorable.
function coinsToFcfa(coins: number): number {
  return Math.ceil((coins / 25) * 10);
}

/**
 * convertGiftCoins — conversion pièces → FCFA (solde principal, retirable).
 * Seules les pièces gagnées sont convertibles ; les pièces achetées restent dépensables.
 */
export const convertGiftCoins = onCall(
  { timeoutSeconds: 30, memory: "256MiB" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Authentification requise.");
    const uid = request.auth.uid;
    const coins = Number((request.data as { coinsAmount?: unknown })?.coinsAmount);
    if (!Number.isInteger(coins) || coins <= 0) {
      throw new HttpsError("invalid-argument", "Montant invalide.");
    }

    const userRef = db.collection("Users").doc(uid);
    return db.runTransaction(async (t) => {
      const userDoc = await t.get(userRef);
      if (!userDoc.exists) throw new HttpsError("not-found", "Compte introuvable.");
      const convertible = convertibleCoins(userDoc.data());
      if (coins > convertible) {
        throw new HttpsError("failed-precondition", "Pièces non convertibles.", { convertible });
      }

      const fcfa = coinsToFcfa(coins);
      const now = Date.now();
      t.update(userRef, {
        giftCoinsBalance: FieldValue.increment(-coins),
        votre_solde_principal: FieldValue.increment(fcfa),
        totalGiftCoinsConverted: FieldValue.increment(coins),
        updatedAt: now,
      });
      const txRef = db.collection("TransactionSoldes").doc();
      t.set(txRef, {
        id: txRef.id,
        user_id: uid,
        type: "CONVERSION_PIECES",
        statut: "VALIDER",
        description: `Conversion de ${coins} pièces en FCFA`,
        montant: fcfa,
        frais: 0,
        montant_total: fcfa,
        methode_paiement: "pieces",
        createdAt: now,
        updatedAt: now,
      });
      return { success: true, coins, fcfa };
    });
  }
);
