import { onCall, HttpsError, onRequest } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import axios from "axios";
import * as crypto from "crypto";
import { db } from "../shared/firebase";
import { formatCinetpayDate, generateDepositNumber } from "../shared/deposit_utils";

// Interface pour les données d'appel
interface InitiateAfrolookDepositData {
  amount: number;
  userId: string;
  paymentType?: "MOBILE_MONEY" | "CARD";
  customerName?: string;
  customerSurname?: string;
  customerEmail?: string;
  customerPhone?: string;
  customerAddress?: string;
  customerCity?: string;
  customerCountry?: string;
  customerZipCode?: string;
}

// Interface pour la réponse de l'API CinetPay
interface CinetPayResponse {
  data: {
    payment_url: string;
    [key: string]: any;
  };
  [key: string]: any;
}

export const initiateAfrolookDeposit = onCall(
  { timeoutSeconds: 60 },
  async (request) => {
    console.log("Auth context received:", request.auth);

    if (!request.auth) {
      console.error("NO AUTHENTICATION - Request headers:", request.rawRequest.headers);
      throw new HttpsError("unauthenticated", "L'utilisateur doit être authentifié");
    }

    const authUserId = request.auth.uid;
    const data = request.data as InitiateAfrolookDepositData;
    const { amount, userId } = data;

    console.log("Request details:", {
      authUid: authUserId,
      requestedUid: userId,
      amount: amount,
    });

    if (userId !== authUserId) {
      console.error("UID MISMATCH DETECTED:", {
        authenticatedUid: authUserId,
        requestedUid: userId,
      });
      throw new HttpsError("permission-denied", "Accès non autorisé: UID mismatch");
    }

    const userRef = db.collection("Users").doc(userId);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      throw new HttpsError("not-found", "Utilisateur non trouvé");
    }

    const amountInt = Math.round(Number(amount));
    if (isNaN(amountInt) || amountInt <= 0) {
      throw new HttpsError("invalid-argument", "Le montant doit être un nombre positif");
    }

    const feeRate = data.paymentType === "CARD" ? 0.07 : 0.056;
    const fees = Math.round(amountInt * feeRate);
    const amountWithoutFees = amountInt - fees;

    const transactionId = `${Date.now()}`;
    const depositNumber = generateDepositNumber();
    const pendingTransactionRef = db.collection("pending_afrolook_deposits").doc(transactionId);

    await pendingTransactionRef.set({
      userId,
      amount: amountInt,
      amountWithoutFees,
      fees,
      feeRate,
      paymentType: data.paymentType || "MOBILE_MONEY",
      status: "pending",
      depositNumber: depositNumber,
      createdAt: FieldValue.serverTimestamp(),
      type: "afrolook_deposit",
    });

    const apiKey = process.env.CINETPAY_API_KEY!;
    const siteid = process.env.CINETPAY_SITE_ID!;
    const notifyUrl = process.env.CINETPAY_NOTIFY_URL!;
    const returnUrl = process.env.CINETPAY_RETURN_URL!;

    try {
      const currentPaymentDate = new Date();
      const formattedPaymentDate = formatCinetpayDate(currentPaymentDate);

      const signatureString = [
        apiKey,
        siteid,
        transactionId,
        formattedPaymentDate,
        amountInt.toString(),
        "XOF",
      ].join("");

      const signature = crypto
        .createHmac("sha256", apiKey)
        .update(signatureString)
        .digest("hex");

      const requestBody = {
        apikey: apiKey,
        site_id: siteid,
        transaction_id: transactionId,
        amount: amountInt,
        currency: "XOF",
        description: "Recharge portefeuille Afrolook",
        customer_id: userId,
        customer_name: data.customerName || "Client",
        customer_surname: data.customerSurname || "Afrolook",
        customer_email: data.customerEmail || "",
        customer_phone_number: data.customerPhone || "",
        customer_address: data.customerAddress || "N/A",
        customer_city: data.customerCity || "N/A",
        customer_country: data.customerCountry || "CI",
        customer_zip_code: data.customerZipCode || "00000",
        return_url: returnUrl,
        notify_url: notifyUrl,
        channels: data.paymentType === "CARD" ? "CREDIT_CARD" : "MOBILE_MONEY",
        metadata: userId,
        payment_date: formattedPaymentDate,
        signature: signature,
      };

      console.log("Requête CinetPay:", JSON.stringify({
        ...requestBody,
        apikey: "***",
        signature: signature.substring(0, 8) + "...",
      }));

      const response = await axios.post<CinetPayResponse>(
        "https://api-checkout.cinetpay.com/v2/payment",
        requestBody,
        { headers: { "Content-Type": "application/json" } }
      );

      console.log("Réponse CinetPay:", JSON.stringify(response.data));

      if (response.data && response.data.data && response.data.data.payment_url) {
        return {
          payment_url: response.data.data.payment_url,
          transaction_id: transactionId,
          deposit_number: depositNumber,
        };
      } else {
        throw new Error(`Réponse CinetPay invalide: ${JSON.stringify(response.data)}`);
      }
    } catch (error: unknown) {
      let errorMessage = "Erreur inconnue";
      let cinetpayResponseData: unknown = null;

      if (axios.isAxiosError(error)) {
        cinetpayResponseData = error.response?.data;
        errorMessage = `HTTP ${error.response?.status}: ${JSON.stringify(cinetpayResponseData)}`;
        console.error("Erreur axios CinetPay:", {
          status: error.response?.status,
          data: cinetpayResponseData,
          requestUrl: error.config?.url,
        });
      } else {
        const err = error as Error;
        errorMessage = err.message;
        console.error("Erreur CinetPay (non-axios):", err);
      }

      await pendingTransactionRef.update({
        status: "failed",
        error: errorMessage,
        cinetpayResponse: cinetpayResponseData ?? null,
      });

      throw new HttpsError(
        "internal",
        "Erreur lors de la création du paiement",
        { message: errorMessage }
      );
    }
  }
);

export const afrolookDepositCallback = onRequest(
  { timeoutSeconds: 30, cors: true, memory: "256MiB", cpu: 1 },
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
      console.log("Afrolook Deposit Callback reçu:", JSON.stringify(payload));

      const transactionId = payload.cpm_trans_id;
      const userId = payload.cpm_custom || payload.metadata;

      if (!transactionId) {
        res.status(400).send("Missing transaction id");
        return;
      }

      let isSuccess = false;
      try {
        const verifyResponse = await axios.post(
          "https://api-checkout.cinetpay.com/v2/payment/check",
          {
            apikey: process.env.CINETPAY_API_KEY!,
            site_id: process.env.CINETPAY_SITE_ID!,
            transaction_id: transactionId,
          },
          { headers: { "Content-Type": "application/json" } }
        );
        const verifyData = verifyResponse.data?.data;
        isSuccess = verifyData?.status === "ACCEPTED" && verifyData?.payment_status === "ACCEPTED";
        console.log("CinetPay verify:", JSON.stringify(verifyData));
      } catch (verifyError) {
        console.error("Erreur vérification CinetPay:", verifyError);
        isSuccess = payload.cpm_error_message === "SUCCES" || payload.cpm_result === "00";
      }

      if (!isSuccess) {
        console.log("Paiement échoué - mise à jour du statut seulement");
        await db.collection("pending_afrolook_deposits").doc(transactionId).update({
          status: "failed",
          processedAt: FieldValue.serverTimestamp(),
          cinetpayResponse: payload,
        });
        res.status(200).send("OK");
        return;
      }

      const existingTransaction = await db.collection("transactions")
        .where("idTransactionCinetPay", "==", transactionId)
        .limit(1)
        .get();

      if (!existingTransaction.empty) {
        console.log("Transaction déjà traitée");
        res.status(200).send("OK");
        return;
      }

      const pendingTransactionRef = db.collection("pending_afrolook_deposits").doc(transactionId);
      const pendingTransaction = await pendingTransactionRef.get();

      if (!pendingTransaction.exists) {
        console.error("Transaction en attente non trouvée");
        res.status(404).send("Transaction non trouvée");
        return;
      }

      const transactionData = pendingTransaction.data();
      const amount = parseFloat(payload.cpm_amount);
      const fees = transactionData?.fees || 0;
      const amountWithoutFees = amount - fees;
      const depositNumber = transactionData?.depositNumber || generateDepositNumber();
      const currentTimestamp = Date.now();

      await db.runTransaction(async (transaction) => {
        const userRef = db.collection("Users").doc(userId);
        const userDoc = await transaction.get(userRef);

        if (!userDoc.exists) {
          throw new HttpsError("not-found", "Utilisateur non trouvé");
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
        }, { merge: true });

        const newTransactionRef = db.collection("transactions").doc();
        transaction.create(newTransactionRef, {
          id: newTransactionRef.id,
          idUser: userId,
          amount: amountWithoutFees,
          date: FieldValue.serverTimestamp(),
          transactionType: "dépôt",
          status: "réussi",
          paymentMethod: payload.payment_method || "MOBILEMONEY",
          isChallenge: false,
          userType: "user",
          challengeId: null,
          adminId: "",
          notes: "Recharge portefeuille Afrolook",
          idTransactionCinetPay: transactionId,
          fees: fees,
        });

        const transactionSoldeRef = db.collection("TransactionSoldes").doc();
        transaction.create(transactionSoldeRef, {
          id: transactionSoldeRef.id,
          user_id: userId,
          type: "DEPOT",
          statut: "VALIDER",
          description: "Recharge portefeuille Afrolook via CinetPay",
          montant: amountWithoutFees,
          numero_depot: depositNumber,
          createdAt: currentTimestamp,
          updatedAt: currentTimestamp,
          frais: fees,
          montant_total: amount,
          methode_paiement: payload.payment_method || "MOBILEMONEY",
          id_transaction_cinetpay: transactionId,
        });

        transaction.update(pendingTransactionRef, {
          status: "completed",
          processedAt: FieldValue.serverTimestamp(),
          cinetpayResponse: payload,
        });
      });

      res.status(200).send("OK");
    } catch (error) {
      console.error("Erreur de traitement afrolookDepositCallback:", error);
      res.status(500).json({ error: "Erreur interne" });
    }
  }
);
