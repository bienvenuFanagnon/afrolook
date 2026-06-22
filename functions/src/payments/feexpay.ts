import { onCall, HttpsError, onRequest } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import axios from "axios";
import { db } from "../shared/firebase";
import {
  generateFeexpayTransKeyAfrolook,
  generateDepositNumberAfrolook,
  calculateAppGainAfrolook,
} from "../shared/deposit_utils";
import {
  FEEXPAY_API_KEY_AFROLOOK,
  FEEXPAY_SHOP_ID_AFROLOOK,
  FEEXPAY_FEES_CONFIG_AFROLOOK,
  APP_FEE_RATE_AFROLOOK,
} from "../shared/config";

/**
 * 1. Initie un paiement FeexPay pour Afrolook
 */
export const initiateAfrolookFeexpayPayment = onCall(
  { timeoutSeconds: 60, cors: true },
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentification requise");
      }

      const { amount, userId, type } = request.data;

      console.log("=== INITIATE AFROLOOK FEEXPAY PAYMENT ===");
      console.log("Amount:", amount);
      console.log("UserId:", userId);
      console.log("Type:", type);

      const userRef = db.collection("Users").doc(userId);
      const userDoc = await userRef.get();
      if (!userDoc.exists) {
        throw new HttpsError("not-found", "Utilisateur non trouvé");
      }

      const totalAmountToPay = Math.round(Number(amount));

      if (isNaN(totalAmountToPay) || totalAmountToPay < 100 || totalAmountToPay > 2000000) {
        throw new HttpsError("invalid-argument", "Le montant doit être entre 100 et 2.000.000 FCFA");
      }

      const amountWithoutFees = Math.floor(totalAmountToPay / (1 + APP_FEE_RATE_AFROLOOK / 100));
      const fees = totalAmountToPay - amountWithoutFees;
      const depositNumber = generateDepositNumberAfrolook();

      console.log("=== CALCUL DES MONTANTS ===");
      console.log(`Montant total payé: ${totalAmountToPay} FCFA`);
      console.log(`Frais Afrolook (5.6%): ${fees} FCFA`);
      console.log(`Montant net à créditer: ${amountWithoutFees} FCFA`);
      console.log(`Numéro de dépôt: ${depositNumber}`);

      const transactionId = `${Date.now()}_${userId.substring(0, 5)}`;
      const transKey = generateFeexpayTransKeyAfrolook();

      const pendingData: any = {
        userId,
        amount: totalAmountToPay,
        amountWithoutFees,
        fees,
        status: "pending",
        transKey,
        type: "afrolook_deposit",
        depositNumber: depositNumber,
        createdAt: FieldValue.serverTimestamp(),
      };

      await db.collection("pending_afrolook_feexpay_deposits").doc(transactionId).set(pendingData);

      const callbackInfo = JSON.stringify({
        userId,
        transactionId,
        type: "afrolook_deposit",
        transKey,
        depositNumber,
      });

      const redirectUrl = "https://afrolooki.web.app/feexpay-callback";

      return {
        amount: totalAmountToPay,
        amountWithoutFees: amountWithoutFees,
        fees: fees,
        redirecturl: redirectUrl,
        trans_key: transKey,
        callback_info: callbackInfo,
        transactionId: transactionId,
        depositNumber: depositNumber,
      };

    } catch (error: any) {
      console.error("Erreur initiateAfrolookFeexpayPayment:", error);
      throw new HttpsError("internal", error.message);
    }
  }
);

/**
 * 2. Exécute le paiement FeexPay pour Afrolook
 */
export const executeAfrolookFeexpayPayment = onCall(
  { timeoutSeconds: 60, cors: true },
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentification requise");
      }

      const { amount, phoneNumber, operatorCode, operatorName, country, callbackInfo } = request.data;
      const token = FEEXPAY_API_KEY_AFROLOOK;
      const shopId = FEEXPAY_SHOP_ID_AFROLOOK;

      console.log("=== EXECUTE AFROLOOK FEEXPAY PAYMENT ===");
      console.log("Operator:", operatorName, `(${operatorCode})`);
      console.log("Phone:", phoneNumber);
      console.log("Amount:", amount);

      const apiUrl = `https://api-v2.feexpay.me/api/transactions/public/requesttopay/${operatorCode}`;

      const payload = {
        shop: shopId,
        amount: amount,
        phoneNumber: phoneNumber,
        firstName: "Afrolook",
        lastName: "User",
        description: "Recharge portefeuille Afrolook",
        callback_info: callbackInfo,
      };

      const response = await axios.post(apiUrl, payload, {
        headers: {
          "Authorization": `Bearer ${token}`,
          "Content-Type": "application/json",
        },
      });

      console.log("FeexPay Response:", response.data);

      if (response.data && response.data.reference) {
        const transactionId = JSON.parse(callbackInfo).transactionId;

        await db.collection("pending_afrolook_feexpay_deposits").doc(transactionId).update({
          reference: response.data.reference,
          status: "processing",
          operatorCode: operatorCode,
          operatorName: operatorName,
          country: country,
          phoneNumber: phoneNumber,
          updatedAt: FieldValue.serverTimestamp(),
        });

        return {
          success: true,
          reference: response.data.reference,
          status: response.data.status,
          message: response.data.message,
          paymentUrl: response.data.payment_url ?? null,
        };
      } else {
        throw new Error("Pas de référence retournée par FeexPay");
      }

    } catch (error: any) {
      console.error("Erreur executeAfrolookFeexpayPayment:", error.response?.data || error.message);
      throw new HttpsError("internal", error.response?.data?.message || error.message);
    }
  }
);

/**
 * Helper interne pour traiter une transaction FeexPay réussie
 */
async function processSuccessfulFeexpayTransaction(
  pendingDocRef: FirebaseFirestore.DocumentReference,
  pendingData: FirebaseFirestore.DocumentData,
  reference: string,
  extraData: any
): Promise<void> {
  const userId = pendingData.userId;
  const totalAmount = pendingData.amount;
  const amountWithoutFees = pendingData.amountWithoutFees;
  const fees = pendingData.fees;
  const depositNumber = pendingData.depositNumber;
  const operatorCode = pendingData.operatorCode || "unknown";
  const currentTimestamp = Date.now();

  const feexpayConfig = FEEXPAY_FEES_CONFIG_AFROLOOK[operatorCode] || { payin: 0, payout: 0, total: 0 };
  const feexpayFee = totalAmount * (feexpayConfig.total / 100);
  const appGain = calculateAppGainAfrolook(totalAmount, operatorCode);

  console.log(`=== RÉPARTITION DES FRAIS ===`);
  console.log(`Montant crédité à l'utilisateur: ${amountWithoutFees} FCFA`);
  console.log(`Frais FeexPay (${feexpayConfig.total}%): ${feexpayFee.toFixed(2)} FCFA`);
  console.log(`Gain Afrolook: ${appGain.toFixed(2)} FCFA`);

  await db.runTransaction(async (transaction) => {
    const userRef = db.collection("Users").doc(userId);
    const userDoc = await transaction.get(userRef);

    if (!userDoc.exists) {
      throw new Error(`Utilisateur non trouvé: ${userId}`);
    }

    const userData = userDoc.data();
    const currentSolde = userData?.votre_solde || 0;
    const currentSoldePrincipal = userData?.votre_solde_principal || 0;

    const appConfigRef = db.collection("AppData").doc("XgkSxKc10vWsJJ2uBraT");
    const appConfigDoc = await transaction.get(appConfigRef);
    const appData = appConfigDoc.exists ? appConfigDoc.data() : {};

    transaction.update(userRef, {
      votre_solde: currentSolde + amountWithoutFees,
      votre_solde_principal: currentSoldePrincipal + amountWithoutFees,
      updatedAt: currentTimestamp,
    });

    transaction.set(appConfigRef, {
      solde_principal: (appData?.solde_principal || 0) + amountWithoutFees,
      solde_gain: (appData?.solde_gain || 0) + (appGain > 0 ? appGain : 0),
      feexpay_fees_collected: (appData?.feexpay_fees_collected || 0) + feexpayFee,
      lastUpdated: FieldValue.serverTimestamp(),
    }, { merge: true });

    const newTransactionRef = db.collection("transactions").doc();
    transaction.create(newTransactionRef, {
      id: newTransactionRef.id,
      idUser: userId,
      amount: amountWithoutFees,
      date: FieldValue.serverTimestamp(),
      transactionType: "dépôt",
      status: "réussi",
      paymentMethod: "FEEXPAY",
      isChallenge: false,
      userType: "user",
      challengeId: null,
      adminId: "",
      notes: "Recharge portefeuille Afrolook via FeexPay",
      idTransactionFeexPay: reference,
      fees: fees,
      feexpayFees: feexpayFee,
      appGain: appGain,
      operatorCode: operatorCode,
      totalAmount: totalAmount,
    });

    const transactionSoldeRef = db.collection("TransactionSoldes").doc();
    transaction.create(transactionSoldeRef, {
      id: transactionSoldeRef.id,
      user_id: userId,
      type: "DEPOT",
      statut: "VALIDER",
      description: "Recharge portefeuille Afrolook via FeexPay",
      montant: amountWithoutFees,
      numero_depot: depositNumber,
      createdAt: currentTimestamp,
      updatedAt: currentTimestamp,
      frais: fees,
      feexpay_frais: feexpayFee,
      gain_app: appGain,
      montant_total: totalAmount,
      methode_paiement: "FEEXPAY",
      id_transaction_feexpay: reference,
      operateur: operatorCode,
    });

    transaction.update(pendingDocRef, {
      status: "completed",
      processedAt: FieldValue.serverTimestamp(),
      appGain: appGain,
      feexpayFees: feexpayFee,
      ...extraData,
    });
  });
}

/**
 * 3. Webhook FeexPay pour Afrolook
 */
export const afrolookFeexpayWebhook = onRequest(
  { timeoutSeconds: 30, cors: true },
  async (req, res) => {
    try {
      res.set("Access-Control-Allow-Origin", "*");
      if (req.method === "OPTIONS") {
        res.set("Access-Control-Allow-Methods", "POST");
        res.set("Access-Control-Allow-Headers", "Content-Type");
        res.status(204).send("");
        return;
      }

      const payload = req.body;
      console.log("=== AFROLOOK FEEXPAY WEBHOOK REÇU ===");
      console.log(JSON.stringify(payload, null, 2));

      const reference = payload.reference;
      const status = payload.status;
      const amountPaidByUser = payload.amount;

      if (!reference) {
        console.error("Pas de référence dans le webhook");
        res.status(400).send("Missing reference");
        return;
      }

      console.log(`Référence: ${reference}`);
      console.log(`Statut: ${status}`);
      console.log(`Montant payé: ${amountPaidByUser} FCFA`);

      const existingTx = await db.collection("transactions")
        .where("idTransactionFeexPay", "==", reference)
        .limit(1)
        .get();

      if (!existingTx.empty) {
        console.log(`Transaction ${reference} déjà traitée`);
        res.status(200).send("OK");
        return;
      }

      const isSuccess = status === "SUCCESSFUL" || status === "SUCCESS" || status === "ACCEPTED";
      const isFailed = status === "FAILED";

      if (isFailed) {
        console.log(`Paiement échoué: ${reference}`);

        const pendingQuery = await db.collection("pending_afrolook_feexpay_deposits")
          .where("reference", "==", reference)
          .limit(1)
          .get();

        if (!pendingQuery.empty) {
          await pendingQuery.docs[0].ref.update({
            status: "failed",
            processedAt: FieldValue.serverTimestamp(),
            webhookResponse: payload,
            failureReason: payload.reason,
          });
        }

        res.status(200).send("OK");
        return;
      }

      if (!isSuccess) {
        console.log(`Paiement en attente: ${reference}`);
        res.status(200).send("OK");
        return;
      }

      console.log(`Paiement réussi via webhook: ${reference}`);

      const pendingQuery = await db.collection("pending_afrolook_feexpay_deposits")
        .where("reference", "==", reference)
        .limit(1)
        .get();

      if (pendingQuery.empty) {
        console.error(`Transaction pending non trouvée`);
        res.status(200).send("OK");
        return;
      }

      const pendingDocRef = pendingQuery.docs[0].ref;
      const pendingData = pendingQuery.docs[0].data();

      if (pendingData.status === "completed") {
        console.log(`Transaction déjà traitée`);
        res.status(200).send("OK");
        return;
      }

      await processSuccessfulFeexpayTransaction(pendingDocRef, pendingData, reference, {
        webhookResponse: payload,
      });

      console.log(`Transaction ${reference} traitée avec succès`);
      res.status(200).send("OK");

    } catch (error: any) {
      console.error("Erreur webhook Afrolook FeexPay:", error);
      res.status(500).json({ error: "Erreur interne", message: error.message });
    }
  }
);

/**
 * 4. Vérification du statut pour Afrolook
 */
export const checkAfrolookFeexpayTransactionStatus = onCall(
  { timeoutSeconds: 30, cors: true },
  async (request) => {
    try {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Authentification requise");
      }

      const { reference } = request.data;

      if (!reference) {
        throw new HttpsError("invalid-argument", "Référence manquante");
      }

      console.log("=== CHECK AFROLOOK FEEXPAY STATUS ===");
      console.log("Reference:", reference);

      const existingTx = await db.collection("transactions")
        .where("idTransactionFeexPay", "==", reference)
        .limit(1)
        .get();

      if (!existingTx.empty) {
        console.log(`Transaction ${reference} déjà traitée`);
        return { status: "completed", success: true, message: "Déjà traité" };
      }

      const pendingQuery = await db.collection("pending_afrolook_feexpay_deposits")
        .where("reference", "==", reference)
        .limit(1)
        .get();

      if (pendingQuery.empty) {
        console.error(`Transaction pending non trouvée pour référence: ${reference}`);
        return { status: "not_found", success: false, message: "Transaction non trouvée" };
      }

      const pendingDocRef = pendingQuery.docs[0].ref;
      const pendingData = pendingQuery.docs[0].data();

      if (pendingData.status === "completed") {
        return { status: "completed", success: true, message: "Déjà traité" };
      }

      if (pendingData.status === "failed") {
        return { status: "failed", success: false, message: pendingData.failureReason || "Paiement échoué" };
      }

      try {
        const apiUrl = `https://api-v2.feexpay.me/api/transactions/public/single/status/${reference}`;
        const response = await axios.get(apiUrl, {
          headers: {
            "Authorization": `Bearer ${FEEXPAY_API_KEY_AFROLOOK}`,
            "Content-Type": "application/json",
          },
        });

        const apiStatus = response.data.status;
        console.log(`Statut API FeexPay: ${apiStatus}`);

        if (apiStatus === "SUCCESSFUL") {
          console.log(`Paiement réussi, traitement en cours pour ${reference}`);

          await processSuccessfulFeexpayTransaction(pendingDocRef, pendingData, reference, {
            apiResponse: response.data,
          });

          console.log(`Transaction ${reference} traitée avec succès via checkStatus`);
          return {
            status: "completed",
            success: true,
            message: "Paiement confirmé et compte crédité",
            amount: pendingData.amountWithoutFees,
          };

        } else if (apiStatus === "FAILED") {
          console.log(`Paiement échoué: ${reference}`);
          await pendingDocRef.update({
            status: "failed",
            processedAt: FieldValue.serverTimestamp(),
            failureReason: response.data.reason || "Paiement échoué",
          });
          return { status: "failed", success: false, message: response.data.reason || "Paiement échoué" };
        } else {
          console.log(`Paiement en attente: ${apiStatus}`);
          return { status: "pending", success: false, pending: true, message: "Paiement en attente de confirmation" };
        }
      } catch (apiError) {
        console.error("Erreur API FeexPay:", apiError);
        return { status: "pending", success: false, pending: true, message: "Vérification en cours..." };
      }

    } catch (error: any) {
      console.error("Erreur checkAfrolookFeexpayTransactionStatus:", error);
      return { status: "error", success: false, message: error.message };
    }
  }
);
