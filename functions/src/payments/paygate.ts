import { onRequest } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { generateDepositNumber } from "../shared/deposit_utils";

export const processAfrolookPaygatePayment = onRequest(
  { timeoutSeconds: 30, cors: true },
  async (req, res) => {
    try {
      res.set("Access-Control-Allow-Origin", "*");
      if (req.method === "OPTIONS") {
        res.set("Access-Control-Allow-Methods", "POST");
        res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
        res.status(204).send("");
        return;
      }

      const authHeader = req.headers.authorization;
      const expectedSecret = process.env.PAYGATE_WEBHOOK_SECRET;
      if (!expectedSecret || authHeader !== `Bearer ${expectedSecret}`) {
        console.error("PayGate webhook: secret invalide");
        res.status(401).json({ success: false, error: "Non autorisé" });
        return;
      }

      const payload = req.body;
      console.log("Callback PayGate AfroLook reçu:", JSON.stringify(payload));

      const {
        paygateReference,
        amount,
        userId,
        phoneNumber,
        paymentMethod,
      } = payload;

      const existingTransaction = await db.collection("transactions")
        .where("idTransactionPayGate", "==", paygateReference)
        .limit(1)
        .get();

      if (!existingTransaction.empty) {
        console.log("Transaction déjà traitée dans AfroLook");
        res.status(200).json({ success: true, data: { alreadyProcessed: true } });
        return;
      }

      const calculateFees = (paymentMethod: string, totalAmount: number) => {
        const feesConfig: { [key: string]: number } = {
          "T-Money": 0.03,
          "T-MONEY": 0.03,
          "TMONEY": 0.03,
          "TOGOCEL": 0.03,
          "FLOOZ": 0.025,
          "MOOV": 0.025,
        };

        const providerFeeRate = feesConfig[paymentMethod] || 0.02;
        const ourFeeRate = 0.056;

        const realAmount = totalAmount / (1 + ourFeeRate);
        const providerFees = realAmount * providerFeeRate;
        const gainFees = realAmount * (ourFeeRate - providerFeeRate);
        const totalFees = providerFees + gainFees;

        return {
          providerFees,
          gainFees,
          totalFees,
          amountWithoutFees: realAmount,
          realAmount,
          providerFeeRate,
          ourFeeRate,
        };
      };

      const paymentMethodKey = paymentMethod || "UNKNOWN";
      const feesCalculation = calculateFees(paymentMethodKey, amount);

      const amountWithoutFees = feesCalculation.amountWithoutFees;
      const providerFees = feesCalculation.providerFees;
      const gainFees = feesCalculation.gainFees;
      const totalFees = feesCalculation.totalFees;

      console.log(`Frais calculés AfroLook pour "${paymentMethodKey}":`, {
        montantTotalReçu: amount,
        montantRéelCredité: amountWithoutFees,
        fraisOpérateur: providerFees,
        fraisGainApp: gainFees,
        fraisTotaux: totalFees,
        répartition: `Opérateur: ${(feesCalculation.providerFeeRate * 100).toFixed(1)}%, App: ${((feesCalculation.ourFeeRate - feesCalculation.providerFeeRate) * 100).toFixed(1)}%`,
      });

      const depositNumber = generateDepositNumber();
      const currentTimestamp = Date.now();

      await db.runTransaction(async (transaction) => {
        const userRef = db.collection("Users").doc(userId);
        const userDoc = await transaction.get(userRef);

        if (!userDoc.exists) {
          throw new Error("Utilisateur AfroLook non trouvé");
        }

        const userData = userDoc.data();
        const currentSolde = userData?.votre_solde || 0;
        const currentSoldeDepot = userData?.votre_solde_depot || 0;

        const appConfigRef = db.collection("AppData").doc("XgkSxKc10vWsJJ2uBraT");
        const appConfigDoc = await transaction.get(appConfigRef);
        const appData = appConfigDoc.exists ? appConfigDoc.data() : {};

        const currentAppSoldePrincipal = appData?.solde_principal || 0;
        const currentAppSoldeGain = appData?.solde_gain || 0;

        // Les dépôts créditent uniquement votre_solde_depot
        transaction.update(userRef, {
          votre_solde: currentSolde + amountWithoutFees,
          votre_solde_depot: currentSoldeDepot + amountWithoutFees,
          updatedAt: currentTimestamp,
        });

        transaction.set(appConfigRef, {
          solde_principal: currentAppSoldePrincipal + amountWithoutFees,
          solde_gain: currentAppSoldeGain + gainFees,
        }, { merge: true });

        const newTransactionRef = db.collection("transactions").doc();
        transaction.create(newTransactionRef, {
          id: newTransactionRef.id,
          idUser: userId,
          amount: amountWithoutFees,
          date: FieldValue.serverTimestamp(),
          transactionType: "dépôt",
          status: "réussi",
          paymentMethod: paymentMethod,
          isChallenge: false,
          userType: "user",
          challengeId: null,
          adminId: "",
          notes: `Recharge portefeuille Afrolook via PayGate (${paymentMethod})`,
          idTransactionPayGate: paygateReference,
          fees: totalFees,
          providerFees: providerFees,
          gainFees: gainFees,
          phoneNumber: phoneNumber,
          source: "paygate_callback",
          amountReceived: amount,
          amountWithoutFees: amountWithoutFees,
          feesBreakdown: {
            totalRate: 0.056,
            providerRate: feesCalculation.providerFeeRate,
            appRate: feesCalculation.ourFeeRate - feesCalculation.providerFeeRate,
          },
        });

        const transactionSoldeRef = db.collection("TransactionSoldes").doc();
        transaction.create(transactionSoldeRef, {
          id: transactionSoldeRef.id,
          user_id: userId,
          type: "DEPOT",
          statut: "VALIDER",
          description: `Recharge portefeuille Afrolook via PayGate (${paymentMethod})`,
          montant: amountWithoutFees,
          numero_depot: depositNumber,
          createdAt: currentTimestamp,
          updatedAt: currentTimestamp,
          frais: totalFees,
          frais_operateur: providerFees,
          frais_gain: gainFees,
          montant_total: amount,
          methode_paiement: paymentMethod || "PAYGATE",
          id_transaction_paygate: paygateReference,
        });

        const feesLogRef = db.collection("fees_audit_logs").doc();
        transaction.create(feesLogRef, {
          transactionId: paygateReference,
          userId: userId,
          amountTotal: amount,
          amountWithoutFees: amountWithoutFees,
          providerFees: providerFees,
          gainFees: gainFees,
          totalFees: totalFees,
          paymentMethod: paymentMethod,
          providerFeeRate: feesCalculation.providerFeeRate,
          appFeeRate: feesCalculation.ourFeeRate - feesCalculation.providerFeeRate,
          timestamp: FieldValue.serverTimestamp(),
        });
      });

      console.log("Transaction AfroLook traitée avec succès - Frais appliqués");
      res.status(200).json({
        success: true,
        data: {
          message: "Paiement traité avec succès",
          amountCredited: amountWithoutFees,
          feesApplied: {
            total: totalFees,
            provider: providerFees,
            app: gainFees,
          },
          userId: userId,
        },
      });

    } catch (error) {
      console.error("Erreur traitement callback AfroLook:", error);
      res.status(500).json({
        success: false,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }
);
