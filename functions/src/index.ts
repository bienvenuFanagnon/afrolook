import {onCall, HttpsError, onRequest} from "firebase-functions/v2/https";
export {translatePostDescription} from "./translatePost";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import axios from "axios";
import * as crypto from "crypto";
import { RtcRole, RtcTokenBuilder } from "agora-access-token";
import * as dotenv from "dotenv";
import * as nodemailer from 'nodemailer'

// Chargement des variables d'environnement (local dev)
dotenv.config();

// Initialisation Firebase
initializeApp();
const db = getFirestore();

/**
 * Fonction d'aide pour formater un objet Date en une chaîne 'YYYY-MM-DD HH:MM:SS'.
 */
function formatCinetpayDate(date: Date): string {
  const pad = (num: number) => num.toString().padStart(2, "0");
  const year = date.getFullYear();
  const month = pad(date.getMonth() + 1);
  const day = pad(date.getDate());
  const hours = pad(date.getHours());
  const minutes = pad(date.getMinutes());
  const seconds = pad(date.getSeconds());
  return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
}

/**
 * Génère un numéro de dépôt unique
 */
function generateDepositNumber(): string {
  const timestamp = Date.now().toString();
  const random = Math.floor(Math.random() * 1000).toString().padStart(3, "0");
  return `DEP${timestamp}${random}`;
}

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
    [key: string]: any; // Pour les autres propriétés éventuelles
  };
  [key: string]: any; // Pour les autres propriétés éventuelles
}

export const initiateAfrolookDeposit = onCall(
  { timeoutSeconds: 60 },
  async (request) => {
    console.log('🔐 Auth context received:', request.auth);

    // Vérification PLUS PRECISE de l'authentification
    if (!request.auth) {
      console.error('❌ NO AUTHENTICATION - Request headers:', request.rawRequest.headers);
      throw new HttpsError("unauthenticated", "L'utilisateur doit être authentifié");
    }

    const authUserId = request.auth.uid;
    const data = request.data as InitiateAfrolookDepositData;
    const { amount, userId } = data;

    console.log('📋 Request details:', {
      authUid: authUserId,
      requestedUid: userId,
      amount: amount
    });

    // Vérification CRITIQUE de la correspondance des UID
    if (userId !== authUserId) {
      console.error('🚫 UID MISMATCH DETECTED:', {
        authenticatedUid: authUserId,
        requestedUid: userId
      });
      throw new HttpsError("permission-denied", "Accès non autorisé: UID mismatch");
    }



    // Vérifier que l'utilisateur existe
    const userRef = db.collection("Users").doc(userId);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      throw new HttpsError("not-found", "Utilisateur non trouvé");
    }

    // Convertir le montant en entier
    const amountInt = Math.round(Number(amount));
    if (isNaN(amountInt) || amountInt <= 0) {
      throw new HttpsError("invalid-argument", "Le montant doit être un nombre positif");
    }

    // Calcul des frais selon le canal : 7% carte bancaire, 5.6% mobile money
    const feeRate = data.paymentType === "CARD" ? 0.07 : 0.056;
    const fees = Math.round(amountInt * feeRate);
    const amountWithoutFees = amountInt - fees;

    // Créer une transaction en attente
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

    // Configuration CinetPay depuis les variables d'environnement
    const apiKey = process.env.CINETPAY_API_KEY!;
    const siteid = process.env.CINETPAY_SITE_ID!;
    const notifyUrl = process.env.CINETPAY_NOTIFY_URL!;
    const returnUrl = process.env.CINETPAY_RETURN_URL!;

    try {
      const currentPaymentDate = new Date();
      const formattedPaymentDate = formatCinetpayDate(currentPaymentDate);

      // Signature HMAC-SHA256 : doit correspondre exactement aux champs envoyés
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
        customer_name:    data.customerName    || "Client",
        customer_surname: data.customerSurname || "Afrolook",
        customer_email:   data.customerEmail   || "",
        customer_phone_number: data.customerPhone || "",
        customer_address: data.customerAddress || "N/A",
        customer_city:    data.customerCity    || "N/A",
        customer_country: data.customerCountry || "CI",
        customer_zip_code: data.customerZipCode || "00000",
        return_url: returnUrl,
        notify_url: notifyUrl,
        channels: data.paymentType === "CARD" ? "CREDIT_CARD" : "MOBILE_MONEY",
        metadata: userId,
        payment_date: formattedPaymentDate,
        signature: signature,
      };

      console.log("📤 Requête CinetPay:", JSON.stringify({
        ...requestBody,
        apikey: "***",
        signature: signature.substring(0, 8) + "...",
      }));

      const response = await axios.post<CinetPayResponse>(
        "https://api-checkout.cinetpay.com/v2/payment",
        requestBody,
        { headers: { "Content-Type": "application/json" } }
      );

      console.log("✅ Réponse CinetPay:", JSON.stringify(response.data));

      if (response.data && response.data.data && response.data.data.payment_url) {
        return {
          payment_url: response.data.data.payment_url,
          transaction_id: transactionId,
          deposit_number: depositNumber,
        };
      } else {
        throw new Error(
          `Réponse CinetPay invalide: ${JSON.stringify(response.data)}`
        );
      }
    } catch (error: unknown) {
      let errorMessage = "Erreur inconnue";
      let cinetpayResponseData: unknown = null;

      if (axios.isAxiosError(error)) {
        cinetpayResponseData = error.response?.data;
        errorMessage = `HTTP ${error.response?.status}: ${JSON.stringify(cinetpayResponseData)}`;
        console.error("❌ Erreur axios CinetPay:", {
          status: error.response?.status,
          data: cinetpayResponseData,
          requestUrl: error.config?.url,
        });
      } else {
        const err = error as Error;
        errorMessage = err.message;
        console.error("❌ Erreur CinetPay (non-axios):", err);
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
  {timeoutSeconds: 30, cors: true},
  async (req, res) => {
    try {
      // Configuration CORS
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

      // Vérification de la transaction auprès de CinetPay (sécurité webhook)
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
        // Fallback sur les données du webhook
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

      // Vérification des doublons
      const existingTransaction = await db.collection("transactions")
        .where("idTransactionCinetPay", "==", transactionId)
        .limit(1)
        .get();

      if (!existingTransaction.empty) {
        console.log("Transaction déjà traitée");
        res.status(200).send("OK");
        return;
      }

      // Récupération des données de la transaction en attente
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

      // Transaction Firestore
      await db.runTransaction(async (transaction) => {
        // Lecture des données utilisateur
        const userRef = db.collection("Users").doc(userId);
        const userDoc = await transaction.get(userRef);

        if (!userDoc.exists) {
          throw new HttpsError("not-found", "Utilisateur non trouvé");
        }

        const userData = userDoc.data();
        const currentSolde = userData?.votre_solde || 0;
        const currentSoldePrincipal = userData?.votre_solde_principal || 0;

        // Lecture des données de l'application
        const appConfigRef = db.collection("AppData").doc("XgkSxKc10vWsJJ2uBraT");
        const appConfigDoc = await transaction.get(appConfigRef);
        const appData = appConfigDoc.exists ? appConfigDoc.data() : {};

        // Mise à jour des soldes utilisateur
        transaction.update(userRef, {
          votre_solde: currentSolde + amountWithoutFees,
          votre_solde_principal: currentSoldePrincipal + amountWithoutFees,
          updatedAt: currentTimestamp,
        });

        // Mise à jour du solde principal de l'application (pour les frais)
        transaction.set(appConfigRef, {
          solde_principal: (appData?.solde_principal || 0) + amountWithoutFees,
        }, {merge: true});

        // Création de la transaction standard
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

        // Création de la TransactionSolde
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

        // Mise à jour de la transaction en attente
        transaction.update(pendingTransactionRef, {
          status: "completed",
          processedAt: FieldValue.serverTimestamp(),
          cinetpayResponse: payload,
        });
      });

      res.status(200).send("OK");
    } catch (error) {
      console.error("Erreur de traitement afrolookDepositCallback:", error);
      res.status(500).json({error: "Erreur interne"});
    }
  }
);




// Variables Agora
const appId = process.env.AGORA_APP_ID!;
const appCertificate = process.env.AGORA_APP_CERTIFICATE!;

if (!appId || !appCertificate) {
  console.error("❌ AGORA_APP_ID et AGORA_APP_CERTIFICATE doivent être configurés.");
}

export const generateAgoraToken = onCall(
  { timeoutSeconds: 30 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Utilisateur non authentifié");
    }

    try {
      const { channelName, uid, role } = request.data as {
        channelName: string;
        uid: string;
        role: "host" | "audience";
      };

      if (!channelName || !uid || !role) {
        throw new HttpsError("invalid-argument", "Paramètres manquants");
      }

      // 👉 Mapping du rôle
      const agoraRole =
        role === "host" ? RtcRole.PUBLISHER : RtcRole.SUBSCRIBER;

      // Expiration 1h
  const expirationTimeInSeconds = 3600; // 1h
  const currentTimestamp = Math.floor(Date.now() / 1000);
  const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

  const token = RtcTokenBuilder.buildTokenWithUid(
    appId!,
    appCertificate!,
    channelName,
    Number(uid),
    agoraRole,
    privilegeExpiredTs
  );

      return { token };
    } catch (error: any) {
      console.error("Erreur génération token Agora:", error);
      throw new HttpsError("internal", "Impossible de générer un token Agora");
    }
  }
);



export const processAfrolookPaygatePayment = onRequest(
  { timeoutSeconds: 30, cors: true },
  async (req, res) => {
    try {
      // Configuration CORS
      res.set("Access-Control-Allow-Origin", "*");
      if (req.method === "OPTIONS") {
        res.set("Access-Control-Allow-Methods", "POST");
        res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
        res.status(204).send("");
        return;
      }

      // Vérification du secret PayGate
      const authHeader = req.headers.authorization;
      const expectedSecret = process.env.PAYGATE_WEBHOOK_SECRET;
      if (!expectedSecret || authHeader !== `Bearer ${expectedSecret}`) {
        console.error("PayGate webhook: secret invalide");
        res.status(401).json({ success: false, error: "Non autorisé" });
        return;
      }

      const payload = req.body;
      console.log("🎯 Callback PayGate AfroLook reçu:", JSON.stringify(payload));

      const {
        // ✅ SUPPRIMER les variables non utilisées
        // transactionId, // ← Supprimé car non utilisé
        paygateReference,
        amount,
        userId,
        phoneNumber,
        paymentMethod,
        // transactionData // ← Supprimé car non utilisé
      } = payload;

      // ✅ VÉRIFIER SI DÉJÀ TRAITÉ DANS AFROLOOK
      const existingTransaction = await db.collection("transactions")
        .where("idTransactionPayGate", "==", paygateReference)
        .limit(1)
        .get();

      if (!existingTransaction.empty) {
        console.log("⚠️ Transaction déjà traitée dans AfroLook");
        res.status(200).json({ success: true, data: { alreadyProcessed: true } });
        return;
      }

      // ✅ CALCUL DES FRAIS IDENTIQUE À EPARGNEPLUS
      const calculateFees = (paymentMethod: string, totalAmount: number) => {
        const feesConfig: { [key: string]: number } = {
          'T-Money': 0.03,
          'T-MONEY': 0.03,
          'TMONEY': 0.03,
          'TOGOCEL': 0.03,
          'FLOOZ': 0.025,
          'MOOV': 0.025,
        };

        const providerFeeRate = feesConfig[paymentMethod] || 0.02;
        const ourFeeRate = 0.056; // 5.6% de frais totaux

        // Montant réel sans les frais de 5.6%
        const realAmount = totalAmount / (1 + ourFeeRate);

        // Frais opérateur (FLOOZ: 2.5%, T-Money: 3%, etc.)
        const providerFees = realAmount * providerFeeRate;

        // Frais de gain pour l'application (reste après frais opérateur)
        const gainFees = realAmount * (ourFeeRate - providerFeeRate);

        // Frais totaux (opérateur + gain app)
        const totalFees = providerFees + gainFees;

        return {
          providerFees,
          gainFees,
          totalFees,
          amountWithoutFees: realAmount,
          realAmount,
          providerFeeRate,
          ourFeeRate
        };
      };

      // ✅ APPLICATION DES FRAIS
      const paymentMethodKey = paymentMethod || 'UNKNOWN';
      const feesCalculation = calculateFees(paymentMethodKey, amount);

      const amountWithoutFees = feesCalculation.amountWithoutFees;
      const providerFees = feesCalculation.providerFees;
      const gainFees = feesCalculation.gainFees;
      const totalFees = feesCalculation.totalFees;

      console.log(`💰 Frais calculés AfroLook pour "${paymentMethodKey}":`, {
        montantTotalReçu: amount,
        montantRéelCredité: amountWithoutFees,
        fraisOpérateur: providerFees,
        fraisGainApp: gainFees,
        fraisTotaux: totalFees,
        répartition: `Opérateur: ${(feesCalculation.providerFeeRate * 100).toFixed(1)}%, App: ${((feesCalculation.ourFeeRate - feesCalculation.providerFeeRate) * 100).toFixed(1)}%`
      });

      const depositNumber = generateDepositNumber();
      const currentTimestamp = Date.now();

      await db.runTransaction(async (transaction) => {
        // Lecture utilisateur AfroLook
        const userRef = db.collection("Users").doc(userId);
        const userDoc = await transaction.get(userRef);

        if (!userDoc.exists) {
          throw new Error("Utilisateur AfroLook non trouvé");
        }

        const userData = userDoc.data();
        const currentSolde = userData?.votre_solde || 0;
        const currentSoldePrincipal = userData?.votre_solde_principal || 0;

        // Lecture données application AfroLook
        const appConfigRef = db.collection("AppData").doc("XgkSxKc10vWsJJ2uBraT");
        const appConfigDoc = await transaction.get(appConfigRef);
        const appData = appConfigDoc.exists ? appConfigDoc.data() : {};

        const currentAppSoldePrincipal = appData?.solde_principal || 0;
        const currentAppSoldeGain = appData?.solde_gain || 0;

        // ✅ Mise à jour soldes utilisateur (montant réel sans frais)
        transaction.update(userRef, {
          votre_solde: currentSolde + amountWithoutFees,
          votre_solde_principal: currentSoldePrincipal + amountWithoutFees,
          updatedAt: currentTimestamp,
        });

        // ✅ Mise à jour soldes application
        transaction.set(appConfigRef, {
          solde_principal: currentAppSoldePrincipal + amountWithoutFees,
          solde_gain: currentAppSoldeGain + gainFees, // Seulement les frais de gain
        }, { merge: true });

        // Création transaction
        const newTransactionRef = db.collection("transactions").doc();
        transaction.create(newTransactionRef, {
          id: newTransactionRef.id,
          idUser: userId,
          amount: amountWithoutFees, // Montant crédité à l'utilisateur
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
          // Détails du calcul
          amountReceived: amount, // Montant total reçu
          amountWithoutFees: amountWithoutFees, // Montant après déduction frais 5.6%
          feesBreakdown: {
            totalRate: 0.056, // 5.6%
            providerRate: feesCalculation.providerFeeRate,
            appRate: feesCalculation.ourFeeRate - feesCalculation.providerFeeRate
          }
        });

        // Création TransactionSolde
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

        // ✅ Log des frais pour audit
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
          timestamp: FieldValue.serverTimestamp()
        });
      });

      console.log("✅ Transaction AfroLook traitée avec succès - Frais appliqués");
      res.status(200).json({
        success: true,
        data: {
          message: "Paiement traité avec succès",
          amountCredited: amountWithoutFees,
          feesApplied: {
            total: totalFees,
            provider: providerFees,
            app: gainFees
          },
          userId: userId
        }
      });

    } catch (error) {
      console.error("❌ Erreur traitement callback AfroLook:", error);
      res.status(500).json({
        success: false,
        error: error instanceof Error ? error.message : String(error)
      });
    }
  }
);

export const sharePostLink = onRequest(
  { timeoutSeconds: 15, cors: true, region: "us-central1" },
  async (req, res) => {
    try {
      // --- LOG 1: RÉCEPTION DE LA REQUÊTE ---
      console.log("--- [DEBUG] NOUVELLE REQUÊTE DE PARTAGE ---");
      console.log("URL Complète reçue:", req.originalUrl);
      console.log("Path reçu:", req.path);

      // On nettoie l'URL pour ne pas être perturbé par les '/' en trop
      const fullPath = req.originalUrl.split('?')[0];
      const segments = fullPath.split('/').filter(s => s.length > 0);

      // --- LOG 2: ANALYSE DES SEGMENTS ---
      console.log("Segments extraits:", segments);

      if (segments.length < 3) {
        console.warn("!!! [ALERTE] URL malformée : Pas assez de segments");
        res.redirect("https://afrolooki.web.app");
        return;
      }

      const type = segments[1];
      const id = segments[2];

      // --- LOG 3: PARAMÈTRES DE RECHERCHE ---
      console.log(`TYPE DÉTECTÉ: ${type}`);
      console.log(`ID DÉTECTÉ: ${id}`);

      let title = "Afrolook";
      let description = "Regardez ce contenu sur Afrolook";
      let previewImage = "https://play-lh.googleusercontent.com/g5_LdDrb8s5Kvw0-dFc8o8RgFLHUxLlsG0yd-DXXzceX9qPrYwZvfHQ2M2jTFqxnEBUo=w240-h480-rw";
      let collectionName = "";
      let isVideo = false;
      const deepLink = `afrolook://${type}/${id}`;

      switch (type) {
        case 'article': collectionName = "Articles"; break;
        case 'contentpaie': collectionName = "ContentPaies"; break;
        case 'profil': collectionName = "Users"; break;
        case 'post': collectionName = "Posts"; break;
        default: collectionName = "Posts";
      }

      console.log(`COLLECTION CIBLE: ${collectionName}`);

      const doc = await db.collection(collectionName).doc(id).get();
      const data = doc.data();

      if (!doc.exists || !data) {
        console.error(`!!! [ERREUR] Document introuvable dans ${collectionName} avec ID: ${id}`);
      } else {
        console.log("+++ [SUCCÈS] Données récupérées avec succès");

        if (type === 'article') {
          title = data.titre || "Article";
          const prix = data.prix || 0;
          description = prix > 0 ? `Prix : ${prix} XOF` : "Prix : Gratuit";
          previewImage = (data.images && data.images.length > 0) ? data.images[0] : previewImage;
        }
        else if (type === 'contentpaie') {
          title = data.title || "Contenu";
          const isFree = data.isFree ?? false;
          const price = data.price || 0;
          description = isFree ? "Gratuit" : `Prix : ${price} XOF`;
          previewImage = data.thumbnailUrl || previewImage;
        }
        else if (type === 'post') {
          title = data.description ? (data.description.substring(0, 100) + "...") : "Nouveau post";
          if (data.dataType === "VIDEO") {
            description = "▶️ Regardez cette vidéo 🎬 sur Afrolook";
            isVideo = true;
            previewImage = data.thumbnail || (data.images && data.images[0]) || previewImage;
          } else {
               if (data.type === "PRONOSTIC") {
                   description = "⚽Gagnez plus de 💰 50 000 FCFA avec les pronostics sur AfroLook ⚽";
                   }else{
                                   description = "Regardez ce post sur Afrolook";

                       }

            previewImage = (data.images && data.images[0]) || previewImage;
          }
        }
        else if (type === 'profil') {
          const pseudo = data.pseudo || "Utilisateur";
          title = `@${pseudo}`;
          description = `Rejoignez-moi sur AfroLook 🌍 ! Abonnez-vous à mon profil pour découvrir mes contenus exclusifs. ✨`;
          previewImage = data.imageUrl || previewImage;
        }
      }

      // --- LOG 4: RÉSULTAT FINAL DU MAPPING ---
      console.log("IMAGE FINALE:", previewImage);
      console.log("TITRE FINAL:", title);
      console.log("DEEP LINK:", deepLink);
      console.log("EST UNE VIDÉO:", isVideo);

      // Sécurité HTTPS
      if (previewImage && previewImage.startsWith('http:')) {
        previewImage = previewImage.replace('http:', 'https:');
      }

      res.set('Cache-Control', 'public, max-age=3600, s-maxage=3600');

      // Dimensions standard pour les aperçus vidéo
      const videoWidth = 1280;
      const videoHeight = 720;

      const html = `<!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>${title}</title>

        <!-- Balises Open Graph de base -->
        <meta property="og:title" content="${title}">
        <meta property="og:description" content="${description}">
        <meta property="og:url" content="https://afrolooki.web.app/share/${type}/${id}">
        <meta property="og:site_name" content="Afrolook">
        <meta property="og:image" content="${previewImage}">

        ${isVideo ? `
        <!-- Balises spécifiques pour les vidéos - Open Graph -->
        <meta property="og:type" content="video.other">
        <meta property="og:video" content="${previewImage}">
        <meta property="og:video:type" content="video/mp4">
        <meta property="og:video:width" content="${videoWidth}">
        <meta property="og:video:height" content="${videoHeight}">
        <meta property="og:image:width" content="${videoWidth}">
        <meta property="og:image:height" content="${videoHeight}">

        <!-- Balises Twitter Cards pour les vidéos -->
        <meta name="twitter:card" content="player">
        <meta name="twitter:site" content="@afrolook">
        <meta name="twitter:title" content="${title}">
        <meta name="twitter:description" content="${description}">
        <meta name="twitter:image" content="${previewImage}">
        <meta name="twitter:player" content="https://afrolooki.web.app/share/${type}/${id}">
        <meta name="twitter:player:width" content="${videoWidth}">
        <meta name="twitter:player:height" content="${videoHeight}">

        <!-- Balises supplémentaires pour Facebook -->
        <meta property="al:ios:url" content="${deepLink}">
        <meta property="al:ios:app_store_id" content="com.afrotok.afrotok">
        <meta property="al:ios:app_name" content="Afrolook">
        <meta property="al:android:url" content="${deepLink}">
        <meta property="al:android:package" content="com.afrotok.afrotok">
        <meta property="al:android:app_name" content="Afrolook">
        ` : `
        <!-- Balises pour les contenus non-vidéo -->
        <meta property="og:type" content="article">
        <meta name="twitter:card" content="summary_large_image">
        <meta name="twitter:image" content="${previewImage}">
        `}

        <!-- Script de redirection -->
        <script>
          window.location.href = "${deepLink}";
          setTimeout(function() {
             window.location.href = "https://play.google.com/store/apps/details?id=com.afrotok.afrotok";
          }, 2500);
        </script>

        <style>
          * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
          }

          body {
            background: linear-gradient(135deg, #1a1a1a 0%, #000000 100%);
            color: #fff;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
          }

          .container {
            max-width: 500px;
            width: 100%;
            text-align: center;
          }

          .image-container {
            position: relative;
            width: 100%;
            margin-bottom: 30px;
            border-radius: 20px;
            overflow: hidden;
            box-shadow: 0 20px 40px rgba(0,0,0,0.5);
          }

          .preview-image {
            width: 100%;
            height: auto;
            display: block;
            transition: transform 0.3s ease;
          }

          .image-container:hover .preview-image {
            transform: scale(1.05);
          }

          .video-overlay {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background-color: rgba(0, 0, 0, 0.2);
            display: flex;
            align-items: center;
            justify-content: center;
            pointer-events: none;
          }

          .play-button {
            width: 80px;
            height: 80px;
            border-radius: 50%;
            background: rgba(255, 215, 0, 0.7);
            backdrop-filter: blur(2px);
            display: flex;
            align-items: center;
            justify-content: center;
            box-shadow: 0 4px 15px rgba(0,0,0,0.3);
            animation: pulse 2s infinite;
          }

          .play-button::after {
            content: '';
            display: block;
            width: 0;
            height: 0;
            border-style: solid;
            border-width: 15px 0 15px 25px;
            border-color: transparent transparent transparent #ffffff;
            margin-left: 5px;
          }

          .video-badge {
            position: absolute;
            bottom: 15px;
            right: 15px;
            background: rgba(0, 0, 0, 0.6);
            backdrop-filter: blur(5px);
            padding: 8px 15px;
            border-radius: 20px;
            font-size: 14px;
            font-weight: bold;
            color: #FFD700;
            border: 1px solid rgba(255, 215, 0, 0.3);
            pointer-events: none;
            z-index: 2;
          }

          .content-info {
            background: rgba(255, 255, 255, 0.05);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 25px;
            border: 1px solid rgba(255, 255, 255, 0.1);
          }

          h2 {
            margin-bottom: 15px;
            font-size: 24px;
            font-weight: 600;
            color: #fff;
          }

          .description {
            color: #FFD700;
            font-size: 16px;
            line-height: 1.6;
            margin-bottom: 20px;
            opacity: 0.9;
          }

          .loading-text {
            color: rgba(255, 255, 255, 0.7);
            font-size: 14px;
            letter-spacing: 1px;
          }

          @keyframes pulse {
            0% {
              transform: scale(1);
              box-shadow: 0 4px 15px rgba(255, 215, 0, 0.3);
            }
            50% {
              transform: scale(1.1);
              box-shadow: 0 4px 25px rgba(255, 215, 0, 0.5);
            }
            100% {
              transform: scale(1);
              box-shadow: 0 4px 15px rgba(255, 215, 0, 0.3);
            }
          }

          @media (max-width: 480px) {
            .play-button {
              width: 60px;
              height: 60px;
            }

            .play-button::after {
              border-width: 12px 0 12px 20px;
            }

            h2 {
              font-size: 20px;
            }
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="image-container">
            <img src="${previewImage}" alt="${title}" class="preview-image">
            ${isVideo ? `
            <div class="video-overlay">
              <div class="play-button"></div>
            </div>
            <div class="video-badge">
              📽️ Voir la vidéo sur Afrolook
            </div>
            ` : ''}
          </div>

          <div class="content-info">
            <h2>${title}</h2>
            <p class="description">${description}</p>
            <p class="loading-text">Ouverture de Afrolook Media...</p>
          </div>
        </div>
      </body>
      </html>`;

      res.status(200).send(html);
    } catch (error) {
      console.error("!!! [CRASH] Erreur fatale dans sharePostLink:", error);
      res.status(500).send("Erreur interne");
    }
  }
);


// Interface pour les données
interface SendBulkNotificationData {
  senderId: string;
  message: string;
  typeNotif: string;
  postId?: string;
  postType?: string;
  chatId?: string;
  smallImage?: string;
  isChannel?: boolean;
  channelTitle?: string;
  canalId?: string;
  targetType: "all" | "subscribers" | "channel" | "specific"; // Type de cible
  specificUserIds?: string[]; // Pour les cas spéciaux
}

export const sendBulkNotification = onCall(
  {
    timeoutSeconds: 540, // 9 minutes max (Firebase limit)
    memory: "1GiB",
    region: "us-central1"
  },
  async (request) => {
    // Vérification de l'authentification
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Utilisateur non authentifié");
    }

    try {
      const data = request.data as SendBulkNotificationData;
      const {
        senderId,
        message,
        typeNotif,
        postId,
        postType,
        chatId,
        smallImage,
        isChannel,
        channelTitle,
        canalId,
        targetType,
        specificUserIds
      } = data;

      // Récupérer les informations de l'expéditeur
      const senderDoc = await db.collection("Users").doc(senderId).get();
      if (!senderDoc.exists) {
        throw new HttpsError("not-found", "Expéditeur non trouvé");
      }
      const senderData = senderDoc.data();

      // Récupérer la configuration OneSignal
      const appConfigDoc = await db.collection("AppData").doc("XgkSxKc10vWsJJ2uBraT").get();
      const appConfig = appConfigDoc.data();

      if (!appConfig?.one_signal_app_id || !appConfig?.one_signal_api_key) {
        throw new HttpsError("failed-precondition", "Configuration OneSignal manquante");
      }

      // Déterminer les utilisateurs cibles
      let targetUserIds: string[] = [];

      if (targetType === "all") {
        // Tous les utilisateurs (pour les admins)
        const usersSnapshot = await db.collection("Users").get();
        targetUserIds = usersSnapshot.docs.map(doc => doc.id);
      }
      else if (targetType === "subscribers") {
        // Abonnés de l'utilisateur
        targetUserIds = senderData?.userAbonnesIds || [];
      }
      else if (targetType === "channel" && canalId) {
        // Membres d'un canal
        const canalDoc = await db.collection("Canals").doc(canalId).get();
        if (canalDoc.exists) {
          const canalData = canalDoc.data();
          targetUserIds = [
            ...(canalData?.usersSuiviId || []),
            ...(canalData?.subscribersId || [])
          ];
        }
      }
      else if (targetType === "specific" && specificUserIds) {
        // Liste spécifique fournie
        targetUserIds = specificUserIds;
      }

      // Éliminer les doublons et l'expéditeur
      targetUserIds = [...new Set(targetUserIds)].filter(id => id !== senderId);

      if (targetUserIds.length === 0) {
        return {
          success: true,
          message: "Aucun utilisateur cible",
          processedCount: 0
        };
      }

      console.log(`📊 Traitement de ${targetUserIds.length} utilisateurs`);

      // Préparer le titre de la notification
      const appName = isChannel && channelTitle
        ? `#${channelTitle}`
        : `@${senderData?.pseudo}`;

      // IMPORTANT: Utiliser microsecondsSinceEpoch pour correspondre au format de l'app
      const currentTimeMicroseconds = Date.now() * 1000; // Convertir en microsecondes

      // ✅ CORRECTION: Firestore 'in' supporte max 30 valeurs
      // On utilise un Set pour éviter les doublons
      const allOneSignalIds: string[] = [];
      const notificationsToSave: any[] = [];

      // Traiter par lots de 30 (limite Firestore)
      const FIRESTORE_BATCH_SIZE = 30;

      for (let i = 0; i < targetUserIds.length; i += FIRESTORE_BATCH_SIZE) {
        const batchIds = targetUserIds.slice(i, i + FIRESTORE_BATCH_SIZE);

        console.log(`📦 Traitement lot ${i / FIRESTORE_BATCH_SIZE + 1}: ${batchIds.length} utilisateurs`);

        // Récupérer les utilisateurs du lot (max 30)
        const usersBatch = await db.collection("Users")
          .where("id", "in", batchIds)
          .get();

        for (const userDoc of usersBatch.docs) {
          const userData = userDoc.data();

          // 1. TOUJOURS sauvegarder la notification dans Firestore (pas de limite)
          const notifId = db.collection("Notifications").doc().id;

          // Récupérer l'image du canal si nécessaire
          let mediaUrl = smallImage || senderData?.imageUrl;
          if (isChannel && canalId) {
            const canalImage = await getCanalImage(canalId);
            if (canalImage) mediaUrl = canalImage;
          }

          notificationsToSave.push({
            id: notifId,
            titre: `${appName} a posté`,
            media_url: mediaUrl,
            type: typeNotif,
            description: isChannel
              ? `a posté: ${message.substring(0, 200)}`
              : `${appName} a posté: ${message.substring(0, 200)}`,
            user_id: senderId,
            receiver_id: userDoc.id,
            post_id: postId || "",
            post_data_type: postType || "",
            // ✅ microsecondsSinceEpoch
            createdAt: currentTimeMicroseconds,
            updatedAt: currentTimeMicroseconds,
            status: "VALIDE",
            canal_id: isChannel ? canalId : null,
          });

          // 2. Collecter les OneSignal IDs
          //    La limitation 1h est commentée pour l'instant
          if (userData.oneIgnalUserid && userData.oneIgnalUserid.length > 5) {

            // 🔒 LIMITATION 1h COMMENTÉE - À DÉCOMMENTER PLUS TARD
            // const lastPushTime = userData.lastPushNotificationTime || 0;
            // const oneHourMicroseconds = 60 * 60 * 1000 * 1000; // 1h en microsecondes
            // const timeSinceLastPush = currentTimeMicroseconds - lastPushTime;

            // if (timeSinceLastPush >= oneHourMicroseconds) {
            //   allOneSignalIds.push(userData.oneIgnalUserid);
            //
            //   // Mettre à jour lastPushNotificationTime
            //   await db.collection("Users").doc(userDoc.id).update({
            //     lastPushNotificationTime: currentTimeMicroseconds
            //   });
            // } else {
            //   console.log(`⏱️ Push limité pour ${userDoc.id}`);
            // }

            // ✅ VERSION SANS LIMITATION (actuelle)
            allOneSignalIds.push(userData.oneIgnalUserid);
          }
        }

        // Petite pause pour ne pas surcharger Firestore
        if (i + FIRESTORE_BATCH_SIZE < targetUserIds.length) {
          await new Promise(resolve => setTimeout(resolve, 100));
        }
      }

      // ✅ Étape 1: Sauvegarder TOUTES les notifications (sans limite)
      console.log(`💾 Sauvegarde de ${notificationsToSave.length} notifications dans Firebase`);

      // Sauvegarder par lots pour éviter de surcharger
      const SAVE_BATCH_SIZE = 100;
      for (let i = 0; i < notificationsToSave.length; i += SAVE_BATCH_SIZE) {
        const batch = notificationsToSave.slice(i, i + SAVE_BATCH_SIZE);
        const savePromises = batch.map(notif =>
          db.collection("Notifications").doc(notif.id).set(notif)
        );
        await Promise.all(savePromises);
        console.log(`✅ ${Math.min(i + SAVE_BATCH_SIZE, notificationsToSave.length)}/${notificationsToSave.length} notifications sauvegardées`);
      }

      console.log(`✅ ${notificationsToSave.length} notifications enregistrées avec succès`);

      // ✅ Étape 2: Envoyer les push notifications
      if (allOneSignalIds.length > 0) {
        console.log(`📱 Envoi de push à ${allOneSignalIds.length} utilisateurs`);

        const PUSH_BATCH_SIZE = 2000; // Limite OneSignal
        for (let i = 0; i < allOneSignalIds.length; i += PUSH_BATCH_SIZE) {
          const batchIds = allOneSignalIds.slice(i, i + PUSH_BATCH_SIZE);

          await sendToOneSignal(
            batchIds,
            message,
            appName,
            smallImage || senderData?.imageUrl || appConfig.app_logo,
            appConfig.one_signal_app_id,
            appConfig.one_signal_api_key,
            {
              send_user_id: senderId,
              type_notif: typeNotif,
              post_id: postId || "",
              post_type: postType || "",
              chat_id: chatId || ""
            }
          );

          console.log(`📨 Lot ${i / PUSH_BATCH_SIZE + 1}: ${batchIds.length} push envoyées`);

          // Petite pause entre les lots
          if (i + PUSH_BATCH_SIZE < allOneSignalIds.length) {
            await new Promise(resolve => setTimeout(resolve, 500));
          }
        }

        console.log(`✅ Push notifications envoyées à ${allOneSignalIds.length} utilisateurs`);
      } else {
        console.log(`📱 Aucune push notification envoyée (aucun ID OneSignal valide)`);
      }

      return {
        success: true,
        processedCount: targetUserIds.length,
        notificationsSaved: notificationsToSave.length,
        pushSent: allOneSignalIds.length,
        // pushLimited: targetUserIds.length - allOneSignalIds.length // À utiliser quand la limitation sera activée
      };

    } catch (error) {
      console.error("❌ Erreur dans sendBulkNotification:", error);
      throw new HttpsError("internal", "Erreur lors de l'envoi des notifications", error);
    }
  }
);

// Fonction helper pour envoyer à OneSignal
async function sendToOneSignal(
  userIds: string[],
  message: string,
  appName: string,
  smallImage: string,
  appId: string,
  apiKey: string,
  data: any
) {
  const body = {
    app_id: appId,
    contents: { en: message },
    include_player_ids: userIds,
    headings: { en: appName },
    small_icon: smallImage,
    large_icon: smallImage,
    android_accent_color: "FFD700",
    data: data
  };

  try {
    const response = await axios.post(
      "https://onesignal.com/api/v1/notifications",
      body,
      {
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Basic ${apiKey}`
        },
        timeout: 30000 // 30 secondes timeout
      }
    );

    console.log(`✅ Push envoyé à ${userIds.length} utilisateurs - Status: ${response.status}`);
    return response.data;
  } catch (error) {
    console.error("❌ Erreur OneSignal:", error);
    throw error;
  }
}

// Helper pour récupérer l'image du canal
async function getCanalImage(canalId?: string): Promise<string | null> {
  if (!canalId) return null;

  try {
    const canalDoc = await db.collection("Canals").doc(canalId).get();
    return canalDoc.data()?.urlImage || null;
  } catch {
    return null;
  }
}


/// EMAIL NOTIFICATION

// ============================================
// CONFIGURATION EMAIL AFROLOOK
// ============================================

// Configuration SMTP LWS
const emailTransporter = nodemailer.createTransport({
  host: 'mail96.lwspanel.com',
  port: 587,
  secure: false,
  auth: {
    user: process.env.SMTP_USER!,
    pass: process.env.SMTP_PASS!,
  },
  tls: {
    servername: 'mail96.lwspanel.com',
    rejectUnauthorized: true,
  },
});


// URLs Afrolook
const APP_PLAY_STORE_URL_AFRO = "https://play.google.com/store/apps/details?id=com.afrotok.afrotok&pcampaignid=web_share";
const APP_WEB_URL_AFRO = "https://afrolookmedia.com/";
// const APP_DOMAIN_AFRO = "afrolookmedia.com";

// Limite d'emails par mois
// const MAX_EMAILS_PER_MONTH_AFRO = 2;

// ============================================
// TEMPLATE D'EMAIL PRÉDÉFINI AFROLOOK
// ============================================

const INACTIVE_USER_EMAIL_TEMPLATE = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Afrolook - Votre argent vous attend !</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      background: #0a0a0a;
      padding: 20px;
      line-height: 1.6;
    }
    .container {
      max-width: 600px;
      margin: 0 auto;
      background: #1a1a1a;
      border-radius: 24px;
      overflow: hidden;
      box-shadow: 0 25px 50px -12px rgba(0,0,0,0.5);
      border: 1px solid #2a2a2a;
    }
    .header {
      background: linear-gradient(135deg, #E21221 0%, #FF4444 100%);
      padding: 40px 30px;
      text-align: center;
    }
    .header h1 {
      color: #FFD700;
      margin: 0;
      font-size: 32px;
    }
    .header p {
      color: rgba(255,255,255,0.9);
      margin: 12px 0 0;
      font-size: 16px;
    }
    .header .emoji {
      font-size: 48px;
      margin-bottom: 10px;
    }
    .content {
      padding: 35px 30px;
    }
    .greeting {
      font-size: 18px;
      margin-bottom: 20px;
      color: #FFFFFF;
    }
    .greeting strong {
      color: #FFD700;
      font-size: 22px;
    }
    .alert-badge {
      background: #E21221;
      color: white;
      padding: 10px 20px;
      border-radius: 30px;
      display: inline-block;
      font-size: 14px;
      font-weight: bold;
      margin: 15px 0;
    }
    .money-box {
      background: linear-gradient(135deg, #FFD70020 0%, #E2122120 100%);
      border-radius: 20px;
      padding: 25px;
      margin: 25px 0;
      text-align: center;
      border: 1px solid #FFD70040;
    }
    .money-amount {
      font-size: 48px;
      font-weight: bold;
      color: #FFD700;
      display: block;
      margin: 10px 0;
    }
    .money-label {
      font-size: 14px;
      color: #CCCCCC;
    }
    .stats-grid {
      display: flex;
      flex-wrap: wrap;
      gap: 15px;
      margin: 25px 0;
    }
    .stat-card {
      flex: 1;
      min-width: 120px;
      background: #252525;
      padding: 20px;
      border-radius: 16px;
      text-align: center;
      border: 1px solid #333333;
    }
    .stat-number {
      font-size: 28px;
      font-weight: bold;
      color: #FFD700;
      display: block;
    }
    .stat-label {
      font-size: 11px;
      color: #AAAAAA;
      margin-top: 8px;
    }
    .warning-box {
      background: #E2122120;
      border-left: 4px solid #E21221;
      padding: 15px;
      border-radius: 12px;
      margin: 20px 0;
    }
    .warning-box p {
      color: #FF8888;
      font-size: 13px;
      margin: 0;
    }
    .feature-list {
      margin: 25px 0;
    }
    .feature-item {
      display: flex;
      align-items: center;
      padding: 12px 0;
      border-bottom: 1px solid #333333;
    }
    .feature-icon {
      font-size: 24px;
      width: 45px;
    }
    .feature-text {
      flex: 1;
      color: #DDDDDD;
      font-size: 14px;
    }
    .feature-text strong {
      color: #FFD700;
    }
    .btn-group {
      text-align: center;
      margin: 30px 0;
    }
    .btn {
      display: inline-block;
      padding: 16px 32px;
      margin: 8px;
      border-radius: 50px;
      text-decoration: none;
      font-weight: bold;
      transition: all 0.3s;
      font-size: 16px;
    }
    .btn-primary {
      background: #FFD700;
      color: #1a1a1a;
      box-shadow: 0 4px 15px rgba(255,215,0,0.3);
    }
    .btn-secondary {
      background: #E21221;
      color: white;
      box-shadow: 0 4px 15px rgba(226,18,33,0.3);
    }
    .btn-primary:hover, .btn-secondary:hover {
      transform: translateY(-2px);
      opacity: 0.95;
    }
    .footer {
      background: #111111;
      padding: 25px;
      text-align: center;
      font-size: 11px;
      color: #666666;
    }
    hr {
      margin: 20px 0;
      border: none;
      border-top: 1px solid #333333;
    }
    .highlight {
      color: #FFD700;
      font-weight: bold;
    }
    @media (max-width: 600px) {
      .content { padding: 25px 20px; }
      .stats-grid { flex-direction: column; }
      .btn { display: block; margin: 10px; }
      .money-amount { font-size: 36px; }
    }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <div class="emoji">💰💎🔥</div>
      <h1>AFROLOOK</h1>
      <p>Votre argent vous attend !</p>
    </div>

    <div class="content">
      <div class="greeting">
        <p>Bonjour <strong>{{userName}}</strong> (<strong style="color:#E21221">@{{pseudo}}</strong>),</p>
        <p style="margin-top: 12px; font-size: 16px;">
          Votre compte Afrolook n'a pas été connecté depuis <strong style="color:#FFD700">{{daysInactive}} jours</strong>.
          <strong style="color:#E21221">De l'argent vous attend !</strong>
        </p>
      </div>

      <div style="text-align: center;">
        <span class="alert-badge">⚠️ {{hasMoneyToClaim}} ⚠️</span>
      </div>

      <div class="money-box">
        <div style="font-size: 14px; color: #FFD700;">💰 CE QUE VOUS AVEZ DÉJÀ SUR VOTRE COMPTE</div>
        <div class="money-amount">{{giftCoinsBalance}} 🪙</div>
        <div class="money-label">Pièces cadeaux disponibles</div>
        <div style="font-size: 36px; font-weight: bold; color: #FFD700; margin-top: 15px;">{{soldePrincipal}} FCFA</div>
        <div class="money-label">Solde principal (argent réel)</div>
        <div style="margin-top: 15px; font-size: 13px; color: #CCCCCC;">
          🎉 Total gagné depuis votre inscription : <strong class="highlight">{{totalCoinsEarned}} 🪙</strong>
        </div>
      </div>

      <div class="stats-grid">
        <div class="stat-card">
          <span class="stat-number">{{totalFollowers}}</span>
          <span class="stat-label">👥 Abonnés</span>
        </div>
        <div class="stat-card">
          <span class="stat-number">{{totalLikesReceived}}</span>
          <span class="stat-label">❤️ Likes reçus</span>
        </div>
        <div class="stat-card" style="background: #E2122120;">
          <span class="stat-number" style="color: #FFD700;">+{{newLikesOnMyPosts}}</span>
          <span class="stat-label">❤️ Nouveaux likes</span>
        </div>
      </div>

      <div class="warning-box">
        <p>⚠️ <strong>CE QUE VOUS AVEZ RATÉ PENDANT VOTRE ABSENCE :</strong></p>
        <ul style="margin-top: 10px; margin-left: 20px; color: #FF8888;">
          <li>❤️ Des personnes ont aimé vos posts</li>
          <li>💰 Des pièces virtuelles que vous auriez pu gagner</li>
          <li>🏆 Les challenges du mois avec des lots jusqu'à 250 000 FCFA</li>
        </ul>
      </div>

      <div class="feature-list">
        <div class="feature-item">
          <div class="feature-icon">💰</div>
          <div class="feature-text"><strong>Gagnez de l'argent réel</strong> — Chaque vue sur vos vidéos vous rapporte des pièces convertibles en FCFA</div>
        </div>
        <div class="feature-item">
          <div class="feature-icon">🎁</div>
          <div class="feature-text"><strong>Cadeaux virtuels</strong> — Recevez des pièces de vos fans, convertissez-les en argent réel</div>
        </div>
        <div class="feature-item">
          <div class="feature-icon">🔒</div>
          <div class="feature-text"><strong>Canaux privés payants</strong> — Créez du contenu exclusif et facturez vos abonnés</div>
        </div>
        <div class="feature-item">
          <div class="feature-icon">🎥</div>
          <div class="feature-text"><strong>Lives privés</strong> — Organisez des directs payants et gardez 70% des revenus</div>
        </div>
        <div class="feature-item">
          <div class="feature-icon">🏆</div>
          <div class="feature-text"><strong>Challenge du mois</strong> — Le meilleur post gagne jusqu'à 250 000 FCFA</div>
        </div>
        <div class="feature-item">
          <div class="feature-icon">👑</div>
          <div class="feature-text"><strong>Abonnement Premium</strong> — Plus de visibilité et fonctionnalités exclusives (200 FCFA/mois)</div>
        </div>
      </div>

      <div class="btn-group">
        <a href="{{playStoreUrl}}" class="btn btn-primary">
          📱 RÉCUPÉRER MES GAINS
        </a>
        <a href="{{webUrl}}" class="btn btn-secondary">
          🌐 Version Web
        </a>
      </div>

      <hr>

      <div style="text-align: center; font-size: 12px; color: #888888; margin-top: 20px;">
        <p>💡 <strong>Saviez-vous ?</strong><br>
        Les créateurs les plus actifs sur Afrolook gagnent entre <strong>50 000 et 500 000 FCFA par mois</strong>.<br>
        Votre compte est déjà monétisé, il ne vous reste plus qu'à vous connecter pour commencer à gagner !</p>
      </div>
    </div>

    <div class="footer">
      <p>© 2026 Afrolook - Le réseau social qui vous récompense</p>
      <p>
        <a href="{{webUrl}}/unsubscribe?email={{userEmail}}" style="color: #E21221;">Se désinscrire des emails</a> |
        <a href="{{webUrl}}/legal" style="color: #E21221;">Mentions légales</a>
      </p>
      <p style="font-size: 10px;">Cet email vous a été envoyé car vous êtes inscrit sur Afrolook.</p>
    </div>
  </div>
</body>
</html>
`;

// ============================================
// CLOUD FUNCTION SANS RESTRICTION POUR TESTS
// ============================================

/**
 * Envoie un email personnalisé à un utilisateur inactif
 * Version SANS AUCUNE RESTRICTION pour les tests
 */
export const sendInactiveUserReminder = onCall(
  { timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentification requise");
    }

    const { userId, userData } = request.data;

    if (!userId || !userData) {
      console.error("❌ Paramètres manquants:", { userId, userData });
      throw new HttpsError("invalid-argument", "userId et userData requis");
    }

    if (!userData.userEmail) {
      console.error("❌ Email manquant pour l'utilisateur:", userId);
      throw new HttpsError("invalid-argument", "Email utilisateur requis");
    }

    console.log("📧 Envoi d'email à:", {
      userId: userId,
      email: userData.userEmail,
      userName: userData.userName,
      daysInactive: userData.daysInactive
    });

    try {
      const playStoreUrl = APP_PLAY_STORE_URL_AFRO;
      const webUrl = APP_WEB_URL_AFRO;
      
      const hasMoneyToClaim = (userData.giftCoinsBalance > 0 || userData.soldePrincipal > 0) 
        ? "ARGENT EN ATTENTE" 
        : "VOTRE COMPTE VOUS ATTEND";
      
      let emailHtml = INACTIVE_USER_EMAIL_TEMPLATE
        .replace(/{{userName}}/g, userData.userName || 'Utilisateur')
        .replace(/{{pseudo}}/g, userData.pseudo || 'user')
        .replace(/{{userEmail}}/g, userData.userEmail)
        .replace(/{{daysInactive}}/g, (userData.daysInactive ?? 3).toString())
        .replace(/{{giftCoinsBalance}}/g, (userData.giftCoinsBalance ?? 0).toString())
        .replace(/{{soldePrincipal}}/g, (userData.soldePrincipal ?? 0).toString())
        .replace(/{{totalCoinsEarned}}/g, (userData.totalCoinsEarned ?? 0).toString())
        .replace(/{{totalLikesReceived}}/g, (userData.totalLikesReceived ?? 0).toString())
        .replace(/{{totalFollowers}}/g, (userData.totalFollowers ?? 0).toString())
        .replace(/{{newLikesOnMyPosts}}/g, (userData.newLikesOnMyPosts ?? 0).toString())
        .replace(/{{newCommentsOnMyPosts}}/g, (userData.newCommentsOnMyPosts ?? 0).toString())
        .replace(/{{hasMoneyToClaim}}/g, hasMoneyToClaim)
        .replace(/{{playStoreUrl}}/g, playStoreUrl)
        .replace(/{{webUrl}}/g, webUrl);

      const subjectText = (userData.giftCoinsBalance ?? 0) > 0 
        ? `💰 ${userData.userName}, ${userData.giftCoinsBalance} pièces vous attendent sur Afrolook !`
        : `💰 ${userData.userName}, votre argent dort sur Afrolook !`;

      const mailOptions = {
        from: '"Afrolook" <epargneplus@epargneplusfinance.com>',
        to: userData.userEmail,
        subject: subjectText,
        html: emailHtml,
      };

      await emailTransporter.sendMail(mailOptions);
      
      console.log(`✅ Email envoyé avec succès à ${userData.userEmail}`);

      // Enregistrement optionnel pour le suivi
      await db.collection("user_email_reminders").add({
        userId: userId,
        userEmail: userData.userEmail,
        userName: userData.userName,
        daysInactive: userData.daysInactive,
        giftCoinsBalance: userData.giftCoinsBalance,
        soldePrincipal: userData.soldePrincipal,
        sentAt: Date.now(),
        createdAt: FieldValue.serverTimestamp(),
        testMode: true
      });

      return {
        success: true,
        message: `Email envoyé à ${userData.userEmail}`,
        testMode: true
      };

    } catch (error: any) {
      console.error("❌ Erreur sendInactiveUserReminder:", error);
      throw new HttpsError("internal", error.message);
    }
  }
);

// ============================================
// FONCTION DE TEST RAPIDE
// ============================================

/**
 * Fonction de test rapide pour vérifier la configuration email
 */
export const testAfrolookEmail = onCall(
  { timeoutSeconds: 30 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentification requise");
    }

    const testUserData = {
      userId: "test_user_123",
      userName: "Jean Test",
      pseudo: "jean_test",
      userEmail: request.data?.testEmail || "epargneplus@epargneplusfinance.com",
      giftCoinsBalance: 2450,
      soldePrincipal: 12500,
      totalCoinsEarned: 8750,
      totalLikesReceived: 342,
      totalFollowers: 128,
      daysInactive: 7,
      newLikesOnMyPosts: 24,
      newCommentsOnMyPosts: 8,
    };

    try {
      const playStoreUrl = APP_PLAY_STORE_URL_AFRO;
      const webUrl = APP_WEB_URL_AFRO;
      
      let emailHtml = INACTIVE_USER_EMAIL_TEMPLATE
        .replace(/{{userName}}/g, testUserData.userName)
        .replace(/{{pseudo}}/g, testUserData.pseudo)
        .replace(/{{userEmail}}/g, testUserData.userEmail)
        .replace(/{{daysInactive}}/g, testUserData.daysInactive.toString())
        .replace(/{{giftCoinsBalance}}/g, testUserData.giftCoinsBalance.toString())
        .replace(/{{soldePrincipal}}/g, testUserData.soldePrincipal.toString())
        .replace(/{{totalCoinsEarned}}/g, testUserData.totalCoinsEarned.toString())
        .replace(/{{totalLikesReceived}}/g, testUserData.totalLikesReceived.toString())
        .replace(/{{totalFollowers}}/g, testUserData.totalFollowers.toString())
        .replace(/{{newLikesOnMyPosts}}/g, testUserData.newLikesOnMyPosts.toString())
        .replace(/{{newCommentsOnMyPosts}}/g, testUserData.newCommentsOnMyPosts.toString())
        .replace(/{{hasMoneyToClaim}}/g, "TEST MODE")
        .replace(/{{playStoreUrl}}/g, playStoreUrl)
        .replace(/{{webUrl}}/g, webUrl);

      const mailOptions = {
        from: '"Afrolook Test" <epargneplus@epargneplusfinance.com>',
        to: testUserData.userEmail,
        subject: `🧪 TEST - ${testUserData.userName}, votre argent vous attend sur Afrolook !`,
        html: emailHtml,
      };

      await emailTransporter.sendMail(mailOptions);
      
      console.log(`✅ Email de test envoyé à ${testUserData.userEmail}`);

      return {
        success: true,
        message: `Email de test envoyé à ${testUserData.userEmail}`,
      };

    } catch (error: any) {
      console.error("❌ Erreur testAfrolookEmail:", error);
      throw new HttpsError("internal", error.message);
    }
  }
);


/**
 * Récupère les utilisateurs inactifs depuis 5 jours qui n'ont pas reçu d'email ce mois-ci
 * Limite à 10 utilisateurs par appel
 */
async function getInactiveUsersToNotify(limit: number = 10): Promise<any[]> {
  const now = Date.now();
  const fiveDaysAgo = now - (5 * 24 * 60 * 60 * 1000); // 5 jours en millisecondes
  const startOfMonth = new Date(now);
  startOfMonth.setDate(1);
  startOfMonth.setHours(0, 0, 0, 0);
  const startOfMonthTimestamp = startOfMonth.getTime();

  // Récupérer les utilisateurs qui ont été actifs il y a plus de 5 jours
  const usersSnapshot = await db.collection("Users")
    .where("last_time_active", "<", fiveDaysAgo)
    .where("last_time_active", ">", 0)
    .limit(limit * 2) // On prend plus pour filtrer
    .get();

  const usersToNotify = [];

  for (const doc of usersSnapshot.docs) {
    const userData = doc.data();
    const userId = doc.id;
    
    // Vérifier si l'utilisateur a déjà reçu un email ce mois-ci
    const remindersSnapshot = await db.collection("user_email_reminders")
      .where("userId", "==", userId)
      .where("sentAt", ">=", startOfMonthTimestamp)
      .count()
      .get();

    const emailCountThisMonth = remindersSnapshot.data().count || 0;

    // Ne notifier que si moins de 2 emails ce mois-ci
    if (emailCountThisMonth < 2) {
      // Compter les nouvelles interactions
      const sevenDaysAgo = now - (7 * 24 * 60 * 60 * 1000);
      
      const postsSnapshot = await db.collection("Posts")
        .where("user_id", "==", userId)
        .get();

      let newLikesCount = 0;
      for (const postDoc of postsSnapshot.docs) {
        const post = postDoc.data();
        const postCreatedAt = post['created_at'] || 0;
        let postCreatedAtMillis = postCreatedAt;
        
        if (postCreatedAt > 1000000000000) {
          postCreatedAtMillis = postCreatedAt / 1000;
        }
        
        if (postCreatedAtMillis > sevenDaysAgo) {
          newLikesCount += (post['loves'] as number || 0);
        }
      }

      usersToNotify.push({
        userId: userId,
        userData: {
          userId: userId,
          userEmail: userData['email'] || '',
          userName: userData['pseudo'] || userData['fullName'] || 'Utilisateur',
          pseudo: userData['pseudo'] || 'user',
          giftCoinsBalance: userData['giftCoinsBalance'] || 0,
          soldePrincipal: userData['votre_solde_principal'] || 0,
          totalCoinsEarned: userData['totalCoinsEarnedFromLikes'] || 0,
          totalLikesReceived: userData['totalLikesReceived'] || 0,
          totalFollowers: (userData['userAbonnesIds'] as any[])?.length || 0,
          daysInactive: Math.floor((now - (userData['last_time_active'] || now)) / (24 * 60 * 60 * 1000)),
          newLikesOnMyPosts: newLikesCount,
          newCommentsOnMyPosts: 0,
        }
      });
    }

    if (usersToNotify.length >= limit) break;
  }

  return usersToNotify.slice(0, limit);
}

/**
 * Cloud Function à appeler lors de la connexion utilisateur
 * Récupère 10 utilisateurs inactifs et leur envoie un email (sans bloquer l'utilisateur)
 */
export const processInactiveUsersReminder = onCall(
  { timeoutSeconds: 120, memory: "512MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentification requise");
    }

    console.log("🚀 Début du traitement des utilisateurs inactifs");
    
    try {
      // Récupérer les utilisateurs inactifs à notifier
      const usersToNotify = await getInactiveUsersToNotify(10);
      
      console.log(`📊 ${usersToNotify.length} utilisateurs inactifs à notifier`);

      if (usersToNotify.length === 0) {
        return { success: true, message: "Aucun utilisateur à notifier", processed: 0 };
      }

      // Envoyer les emails en arrière-plan (Promise.allSettled pour ne pas échouer si un email rate)
      const emailPromises = usersToNotify.map(async (user) => {
        try {
          // Appeler la fonction sendInactiveUserReminder existante
      

          // Appel direct à la fonction d'envoi d'email
          const playStoreUrl = APP_PLAY_STORE_URL_AFRO;
          const webUrl = APP_WEB_URL_AFRO;
          
          const hasMoneyToClaim = (user.userData.giftCoinsBalance > 0 || user.userData.soldePrincipal > 0) 
            ? "ARGENT EN ATTENTE" 
            : "VOTRE COMPTE VOUS ATTEND";
          
          let emailHtml = INACTIVE_USER_EMAIL_TEMPLATE
            .replace(/{{userName}}/g, user.userData.userName || 'Utilisateur')
            .replace(/{{pseudo}}/g, user.userData.pseudo || 'user')
            .replace(/{{userEmail}}/g, user.userData.userEmail)
            .replace(/{{daysInactive}}/g, (user.userData.daysInactive ?? 5).toString())
            .replace(/{{giftCoinsBalance}}/g, (user.userData.giftCoinsBalance ?? 0).toString())
            .replace(/{{soldePrincipal}}/g, (user.userData.soldePrincipal ?? 0).toString())
            .replace(/{{totalCoinsEarned}}/g, (user.userData.totalCoinsEarned ?? 0).toString())
            .replace(/{{totalLikesReceived}}/g, (user.userData.totalLikesReceived ?? 0).toString())
            .replace(/{{totalFollowers}}/g, (user.userData.totalFollowers ?? 0).toString())
            .replace(/{{newLikesOnMyPosts}}/g, (user.userData.newLikesOnMyPosts ?? 0).toString())
            .replace(/{{newCommentsOnMyPosts}}/g, (user.userData.newCommentsOnMyPosts ?? 0).toString())
            .replace(/{{hasMoneyToClaim}}/g, hasMoneyToClaim)
            .replace(/{{playStoreUrl}}/g, playStoreUrl)
            .replace(/{{webUrl}}/g, webUrl);

          const subjectText = (user.userData.giftCoinsBalance ?? 0) > 0 
            ? `💰 ${user.userData.userName}, ${user.userData.giftCoinsBalance} pièces vous attendent sur Afrolook !`
            : `💰 ${user.userData.userName}, votre argent dort sur Afrolook !`;

          const mailOptions = {
            from: '"Afrolook" <epargneplus@epargneplusfinance.com>',
            to: user.userData.userEmail,
            subject: subjectText,
            html: emailHtml,
          };

          await emailTransporter.sendMail(mailOptions);
          
          // Enregistrer dans l'historique
          await db.collection("user_email_reminders").add({
            userId: user.userId,
            userEmail: user.userData.userEmail,
            userName: user.userData.userName,
            daysInactive: user.userData.daysInactive,
            giftCoinsBalance: user.userData.giftCoinsBalance,
            soldePrincipal: user.userData.soldePrincipal,
            sentAt: Date.now(),
            createdAt: FieldValue.serverTimestamp(),
            source: "auto_reminder"
          });

          console.log(`✅ Email envoyé à ${user.userData.userEmail}`);
          return { userId: user.userId, success: true };
        } catch (error) {
          console.error(`❌ Erreur pour ${user.userId}:`, error);
          return { userId: user.userId, success: false, error: String(error) };
        }
      });

      const results = await Promise.allSettled(emailPromises);
      const successCount = results.filter(r => r.status === 'fulfilled' && r.value.success).length;
      
      console.log(`📊 Résultat: ${successCount}/${usersToNotify.length} emails envoyés`);

      return {
        success: true,
        message: `${successCount} emails envoyés sur ${usersToNotify.length}`,
        processed: successCount,
        total: usersToNotify.length
      };
      
    } catch (error: any) {
      console.error("❌ Erreur processInactiveUsersReminder:", error);
      // On ne throw pas d'erreur pour ne pas bloquer l'utilisateur
      return { success: false, message: error.message, processed: 0 };
    }
  }
);



// ============================================
// CONFIGURATION EMAIL - À METTRE APRÈS LES IMPORTS
// ============================================

// Configuration email avec votre domaine
const EMAIL_FROM = "Afrolook Media <contact@afrolookmedia.com>";
const APP_DOMAIN = "afrolookmedia.com";
const PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=com.afrotok.afrotok";

// Interface pour les emails
interface EmailData {
  subject: string;
  message: string;
  imageUrl?: string;
  targetType: "all" | "specific" | "subscribers";
  specificUserIds?: string[];
  senderId: string;
  priority?: "normal" | "high";
}

/**
 * Rate limiter pour éviter le spam
 */
async function checkEmailRateLimit(userId: string): Promise<boolean> {
  const oneHourAgo = Date.now() - 60 * 60 * 1000;

  const recentEmails = await db.collection("mail")
    .where("userId", "==", userId)
    .where("createdAt", ">", new Date(oneHourAgo))
    .count()
    .get();

  return recentEmails.data().count < 10; // Max 10 emails par heure par utilisateur
}

/**
 * Vérifie si l'utilisateur a accepté les emails marketing
 */
async function canSendMarketingEmail(userData: any): Promise<boolean> {
  // Si le champ n'existe pas encore, on envoie quand même (par défaut true)
  if (!userData.emailNotifications) {
    return true;
  }
  return userData.emailNotifications.marketing !== false;
}

// ============================================
// FONCTION PRINCIPALE D'ENVOI D'EMAILS EN MASSE
// ============================================

/**
 * Fonction pour envoyer un email à tous les utilisateurs
 */
export const sendBulkEmail = onCall(
  {
    timeoutSeconds: 540,
    memory: "1GiB",
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Utilisateur non authentifié");
    }

    try {
      const data = request.data as EmailData;
      const { subject, message, imageUrl, targetType, specificUserIds, senderId, priority = "normal" } = data;

      // Vérifier que l'expéditeur est admin
      const senderDoc = await db.collection("Users").doc(senderId).get();
      const senderData = senderDoc.data();

      const adminRoles = ["ADM", "admin", "ADMIN", "super_admin"];
      if (!adminRoles.includes(senderData?.role?.toUpperCase() || "")) {
        throw new HttpsError("permission-denied", "Seuls les admins peuvent envoyer des emails en masse");
      }

      // Récupérer les utilisateurs cibles
      let targetUsers: any[] = [];

      if (targetType === "all") {
        const usersSnapshot = await db.collection("Users")
          .where("email", "!=", null)
          .where("email", "!=", "")
          .get();

        // Filtrer ceux qui acceptent les emails marketing
        targetUsers = usersSnapshot.docs.filter(doc =>
          canSendMarketingEmail(doc.data())
        );
      } else if (targetType === "specific" && specificUserIds) {
        // Traiter par lots de 30
        for (let i = 0; i < specificUserIds.length; i += 30) {
          const batchIds = specificUserIds.slice(i, i + 30);
          const usersBatch = await db.collection("Users")
            .where("id", "in", batchIds)
            .where("email", "!=", null)
            .where("email", "!=", "")
            .get();
          targetUsers.push(...usersBatch.docs);
        }
      }

      if (targetUsers.length === 0) {
        return { success: true, message: "Aucun utilisateur avec email trouvé" };
      }

      console.log(`📧 Préparation de ${targetUsers.length} emails`);

      // Créer les entrées dans la collection mail
      const emailBatch = db.batch();
      const emailCollection = db.collection("mail");
      const emailId = `bulk_${Date.now()}_${Math.random().toString(36).substring(7)}`;

      for (const userDoc of targetUsers) {
        const userData = userDoc.data();
        const userEmail = userData.email;

        if (!userEmail) continue;

        // Vérifier le rate limit
        const canSend = await checkEmailRateLimit(userDoc.id);
        if (!canSend) continue;

        // Personnaliser le message
        const personalizedMessage = message
          .replace(/{{pseudo}}/g, userData.pseudo || "Cher utilisateur")
          .replace(/{{nom}}/g, `${userData.prenom || ""} ${userData.nom || ""}`.trim() || "Utilisateur");

        const emailDocRef = emailCollection.doc();
        emailBatch.set(emailDocRef, {
          to: [userEmail],
          message: {
            subject: subject,
            html: generateEmailHTML({
              subject,
              message: personalizedMessage,
              imageUrl,
              userName: userData.pseudo || userData.prenom || "Utilisateur",
              priority
            }),
            from: EMAIL_FROM,
            replyTo: EMAIL_FROM,
          },
          headers: {
            "X-Priority": priority === "high" ? "1" : "3",
            "X-Mailer": "Afrolook Media Email System",
            "List-Unsubscribe": `<https://${APP_DOMAIN}/unsubscribe?email=${encodeURIComponent(userEmail)}>`,
            "List-Unsubscribe-Post": "List-Unsubscribe=One-Click"
          },
          createdAt: FieldValue.serverTimestamp(),
          bulkId: emailId,
          userId: userDoc.id,
          status: "pending",
        });
      }

      await emailBatch.commit();

      // Log de l'envoi
      await db.collection("email_logs").add({
        emailId,
        subject,
        targetCount: targetUsers.length,
        senderId,
        targetType,
        createdAt: FieldValue.serverTimestamp(),
        status: "processing",
      });

      return {
        success: true,
        message: `${targetUsers.length} emails en cours d'envoi`,
        emailId,
      };

    } catch (error) {
      console.error("❌ Erreur sendBulkEmail:", error);
      throw new HttpsError("internal", "Erreur lors de l'envoi des emails", error);
    }
  }
);

// ============================================
// FONCTION POUR LES INTERACTIONS (LIKES, COMMENTAIRES)
// ============================================

/**
 * Fonction déclenchée lors d'une interaction sur un post
 */
export const onPostInteraction = onDocumentCreated(
  {
    document: "interactions/{interactionId}",
    timeoutSeconds: 60,
  },
  async (event) => {
    const interaction = event.data?.data();
    if (!interaction) return;

    try {
      const { postId, userId, type, comment } = interaction;

      // Récupérer le post
      const postDoc = await db.collection("Posts").doc(postId).get();
      if (!postDoc.exists) return;

      const postData = postDoc.data();
      const postOwnerId = postData?.userId;

      // Récupérer les utilisateurs
      const [interactorDoc, postOwnerDoc] = await Promise.all([
        db.collection("Users").doc(userId).get(),
        db.collection("Users").doc(postOwnerId).get()
      ]);

      const interactorData = interactorDoc.data();
      const postOwnerData = postOwnerDoc.data();

      // Vérifier si l'utilisateur veut des notifications
      // Si le champ n'existe pas, on envoie quand même (par défaut true)
      const emailNotifications = postOwnerData?.emailNotifications;
      if (emailNotifications && emailNotifications.interactions === false) return;
      if (!postOwnerData?.email) return;

      // Vérifier rate limit
      const canSend = await checkEmailRateLimit(postOwnerId);
      if (!canSend) return;

      // Créer l'email selon le type
      let subject = "";
      let message = "";
      const interactorName = interactorData?.pseudo || "Un utilisateur";

      switch (type) {
        case "like":
          subject = `${interactorName} a aimé votre publication`;
          message = `${interactorName} a aimé votre publication "${postData?.description?.substring(0, 50)}..." sur Afrolook Media.`;
          break;
        case "comment":
          subject = `${interactorName} a commenté votre publication`;
          message = `${interactorName} a commenté votre publication :<br><br>
                    <em style="background-color: #f0f0f0; padding: 10px; border-radius: 5px; display: block;">${comment || "Voir le commentaire"}</em>`;
          break;
        case "share":
          subject = `${interactorName} a partagé votre publication`;
          message = `${interactorName} a partagé votre publication "${postData?.description?.substring(0, 50)}..."`;
          break;
        default:
          return;
      }

      // Ajouter à la collection mail
      await db.collection("mail").add({
        to: [postOwnerData.email],
        message: {
          subject: subject,
          html: generateInteractionEmailHTML({
            subject,
            message,
            interactorName,
            interactorImage: interactorData?.imageUrl,
            postImage: postData?.images?.[0],
            postId,
            type,
          }),
          from: EMAIL_FROM,
          replyTo: EMAIL_FROM,
        },
        headers: {
          "X-Mailer": "Afrolook Media",
          "List-Unsubscribe": `<https://${APP_DOMAIN}/unsubscribe?email=${encodeURIComponent(postOwnerData.email)}>`
        },
        createdAt: FieldValue.serverTimestamp(),
        userId: postOwnerId,
        type: "interaction",
      });

      console.log(`📧 Email d'interaction envoyé à ${postOwnerData.email}`);

    } catch (error) {
      console.error("❌ Erreur onPostInteraction:", error);
    }
  }
);

// ============================================
// FONCTION POUR LES NOUVEAUX POSTS DES ABONNEMENTS
// ============================================

/**
 * Notifier par email lors d'un nouveau post d'un abonnement
 */
export const onNewPostFromSubscription = onDocumentCreated(
  {
    document: "Posts/{postId}",
    timeoutSeconds: 60,
  },
  async (event) => {
    const post = event.data?.data();
    if (!post) return;

    try {
      const postOwnerId = post.userId;

      // Récupérer les abonnés
      const subscribersSnapshot = await db.collection("Users")
        .where("userAbonnesIds", "array-contains", postOwnerId)
        .get();

      if (subscribersSnapshot.empty) return;

      // Récupérer les infos du posteur
      const postOwnerDoc = await db.collection("Users").doc(postOwnerId).get();
      const postOwnerData = postOwnerDoc.data();
      const posterName = postOwnerData?.pseudo || "Un créateur";

      // Filtrer ceux qui veulent des notifications
      const subscribers = subscribersSnapshot.docs.filter(doc => {
        const notifs = doc.data().emailNotifications;
        // Si le champ n'existe pas, on envoie (par défaut true)
        return !notifs || notifs.newPosts !== false;
      });

      if (subscribers.length === 0) return;

      // Préparer les emails (batch)
      const emailBatch = db.batch();
      const emailCollection = db.collection("mail");
      let emailCount = 0;

      for (const subscriberDoc of subscribers) {
        const subscriberData = subscriberDoc.data();
        if (!subscriberData.email) continue;

        // Vérifier rate limit
        const canSend = await checkEmailRateLimit(subscriberDoc.id);
        if (!canSend) continue;

        const emailDocRef = emailCollection.doc();
        emailBatch.set(emailDocRef, {
          to: [subscriberData.email],
          message: {
            subject: `${posterName} a publié un nouveau contenu sur Afrolook Media`,
            html: generateNewPostEmailHTML({
              posterName,
              posterImage: postOwnerData?.imageUrl,
              postDescription: post.description || "Nouveau contenu",
              postImage: post.images?.[0],
              postId: event.params.postId,
            }),
            from: EMAIL_FROM,
            replyTo: EMAIL_FROM,
          },
          headers: {
            "X-Mailer": "Afrolook Media",
            "List-Unsubscribe": `<https://${APP_DOMAIN}/unsubscribe?email=${encodeURIComponent(subscriberData.email)}>`
          },
          createdAt: FieldValue.serverTimestamp(),
          userId: subscriberDoc.id,
          type: "new_post",
        });
        emailCount++;
      }

      if (emailCount > 0) {
        await emailBatch.commit();
        console.log(`📧 ${emailCount} emails de nouveau post envoyés`);
      }

    } catch (error) {
      console.error("❌ Erreur onNewPostFromSubscription:", error);
    }
  }
);

// ============================================
// FONCTIONS DE GÉNÉRATION HTML
// ============================================

/**
 * Génère le HTML de l'email
 */
function generateEmailHTML({ subject, message, imageUrl, userName, priority }: any): string {
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>${subject} - Afrolook Media</title>
    </head>
    <body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f5f5;">
      <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color: #f5f5f5; padding: 20px;">
        <tr>
          <td align="center">
            <table width="600" cellpadding="0" cellspacing="0" border="0" style="background-color: #ffffff; border-radius: 10px; overflow: hidden; box-shadow: 0 4px 10px rgba(0,0,0,0.1);">

              <!-- Header avec votre logo -->
              <tr>
                <td style="background: linear-gradient(135deg, #000000 0%, #1a1a1a 100%); padding: 30px 20px; text-align: center;">
                  <img src="https://play-lh.googleusercontent.com/g5_LdDrb8s5Kvw0-dFc8o8RgFLHUxLlsG0yd-DXXzceX9qPrYwZvfHQ2M2jTFqxnEBUo=w240-h480-rw" alt="Afrolook Media" style="width: 120px; height: auto; border-radius: 20px;">
                  <h1 style="color: #FFD700; margin: 15px 0 0 0; font-size: 24px; font-weight: bold;">${subject}</h1>
                </td>
              </tr>

              ${imageUrl ? `
              <!-- Image à la une -->
              <tr>
                <td style="padding: 0;">
                  <img src="${imageUrl}" alt="Afrolook Media" style="width: 100%; height: auto; max-height: 300px; object-fit: cover;">
                </td>
              </tr>
              ` : ''}

              <!-- Contenu principal -->
              <tr>
                <td style="padding: 40px 30px;">
                  <p style="color: #666666; font-size: 16px; line-height: 1.6; margin-bottom: 20px;">
                    Bonjour <strong style="color: #000000;">${userName}</strong>,
                  </p>
                  <div style="color: #333333; font-size: 16px; line-height: 1.8; margin: 20px 0;">
                    ${message.replace(/\n/g, '<br>')}
                  </div>

                  <div style="text-align: center; margin: 30px 0;">
                    <a href="${PLAY_STORE_URL}"
                       style="background-color: #FFD700; color: #000000; padding: 12px 30px;
                              text-decoration: none; border-radius: 25px; font-weight: bold;
                              display: inline-block;">
                      Ouvrir l'application
                    </a>
                  </div>
                </td>
              </tr>

              <!-- Footer avec vos coordonnées -->
              <tr>
                <td style="background-color: #f8f8f8; padding: 30px 20px; text-align: center; border-top: 1px solid #eeeeee;">
                  <table width="100%" cellpadding="0" cellspacing="0">
                    <tr>
                      <td align="center" style="padding-bottom: 20px;">
                        <a href="${PLAY_STORE_URL}" style="color: #FFD700; text-decoration: none; font-weight: bold; margin: 0 10px;">Télécharger l'app</a>
                        <span style="color: #cccccc;">|</span>
                        <a href="https://${APP_DOMAIN}/contact" style="color: #FFD700; text-decoration: none; font-weight: bold; margin: 0 10px;">Contact</a>
                        <span style="color: #cccccc;">|</span>
                        <a href="https://${APP_DOMAIN}/unsubscribe" style="color: #FFD700; text-decoration: none; font-weight: bold; margin: 0 10px;">Se désabonner</a>
                      </td>
                    </tr>
                    <tr>
                      <td style="color: #999999; font-size: 13px; line-height: 1.5;">
                        <p style="margin: 5px 0;">© ${new Date().getFullYear()} Afrolook Media. Tous droits réservés.</p>
                        <p style="margin: 5px 0;">contact@afrolookmedia.com</p>
                        <p style="margin: 5px 0; font-size: 11px;">
                          Cet email a été envoyé à l'adresse que vous avez fournie à Afrolook Media.<br>
                          Conformément à la loi, vous pouvez vous désabonner à tout moment.
                        </p>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </body>
    </html>
  `;
}

/**
 * Génère le HTML pour les emails d'interaction
 */
function generateInteractionEmailHTML({ subject, message, interactorName, interactorImage, postImage, postId, type }: any): string {
  const getIcon = () => {
    switch(type) {
      case "like": return "❤️";
      case "comment": return "💬";
      case "share": return "🔄";
      default: return "📱";
    }
  };

  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
    </head>
    <body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f5f5;">
      <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color: #f5f5f5; padding: 20px;">
        <tr>
          <td align="center">
            <table width="500" cellpadding="0" cellspacing="0" border="0" style="background-color: #ffffff; border-radius: 10px; overflow: hidden; box-shadow: 0 4px 10px rgba(0,0,0,0.1);">

              <!-- Header -->
              <tr>
                <td style="background-color: #000000; padding: 25px; text-align: center;">
                  <span style="font-size: 48px; margin-bottom: 10px; display: block;">${getIcon()}</span>
                  <h2 style="color: #FFD700; margin: 0; font-size: 22px;">${subject}</h2>
                </td>
              </tr>

              <!-- Content -->
              <tr>
                <td style="padding: 30px;">
                  <table width="100%" cellpadding="0" cellspacing="0">
                    <tr>
                      <td width="70" valign="top">
                        <img src="${interactorImage || 'https://play-lh.googleusercontent.com/g5_LdDrb8s5Kvw0-dFc8o8RgFLHUxLlsG0yd-DXXzceX9qPrYwZvfHQ2M2jTFqxnEBUo=w240-h480-rw'}"
                             style="width: 60px; height: 60px; border-radius: 50%; object-fit: cover; border: 2px solid #FFD700;">
                      </td>
                      <td valign="top">
                        <p style="color: #333333; font-size: 16px; line-height: 1.6; margin: 0;">
                          <strong style="color: #000000; font-size: 18px;">${interactorName}</strong>
                        </p>
                        <div style="color: #666666; font-size: 15px; line-height: 1.6; margin: 10px 0 0 0;">
                          ${message}
                        </div>
                      </td>
                    </tr>
                  </table>

                  ${postImage ? `
                  <div style="margin-top: 25px; text-align: center; background-color: #f9f9f9; padding: 15px; border-radius: 10px;">
                    <img src="${postImage}" style="max-width: 100%; max-height: 200px; border-radius: 8px; box-shadow: 0 2px 5px rgba(0,0,0,0.1);">
                  </div>
                  ` : ''}

                  <div style="text-align: center; margin-top: 30px;">
                    <a href="https://afrolooki.web.app/post/${postId}"
                       style="background-color: #FFD700; color: #000000; padding: 14px 35px;
                              text-decoration: none; border-radius: 30px; font-weight: bold;
                              display: inline-block; font-size: 16px; border: none;
                              box-shadow: 0 2px 5px rgba(255,215,0,0.3);">
                      Voir la publication →
                    </a>
                  </div>
                </td>
              </tr>

              <!-- Footer -->
              <tr>
                <td style="background-color: #f8f8f8; padding: 20px; text-align: center; border-top: 1px solid #eeeeee;">
                  <p style="color: #999999; font-size: 12px; margin: 0;">
                    <img src="https://play-lh.googleusercontent.com/g5_LdDrb8s5Kvw0-dFc8o8RgFLHUxLlsG0yd-DXXzceX9qPrYwZvfHQ2M2jTFqxnEBUo=w240-h480-rw" alt="Afrolook Media" style="width: 20px; border-radius: 5px; vertical-align: middle; margin-right: 5px;">
                    Afrolook Media - contact@afrolookmedia.com<br>
                    <a href="https://${APP_DOMAIN}/unsubscribe" style="color: #FFD700; text-decoration: none;">Se désabonner</a>
                  </p>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </body>
    </html>
  `;
}

/**
 * Génère le HTML pour les nouveaux posts
 */
function generateNewPostEmailHTML({ posterName, posterImage, postDescription, postImage, postId }: any): string {
  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
    </head>
    <body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f5f5;">
      <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color: #f5f5f5; padding: 20px;">
        <tr>
          <td align="center">
            <table width="500" cellpadding="0" cellspacing="0" border="0" style="background-color: #ffffff; border-radius: 10px; overflow: hidden; box-shadow: 0 4px 10px rgba(0,0,0,0.1);">

              <tr>
                <td style="background: linear-gradient(135deg, #000000 0%, #1a1a1a 100%); padding: 30px 20px; text-align: center;">
                  <img src="https://play-lh.googleusercontent.com/g5_LdDrb8s5Kvw0-dFc8o8RgFLHUxLlsG0yd-DXXzceX9qPrYwZvfHQ2M2jTFqxnEBUo=w240-h480-rw" alt="Afrolook Media" style="width: 100px; border-radius: 15px;">
                  <h2 style="color: #FFD700; margin: 20px 0 0 0; font-size: 24px;">📢 Nouveau contenu !</h2>
                </td>
              </tr>

              <tr>
                <td style="padding: 30px;">
                  <table width="100%" cellpadding="0" cellspacing="0">
                    <tr>
                      <td width="70" valign="top">
                        <img src="${posterImage || 'https://play-lh.googleusercontent.com/g5_LdDrb8s5Kvw0-dFc8o8RgFLHUxLlsG0yd-DXXzceX9qPrYwZvfHQ2M2jTFqxnEBUo=w240-h480-rw'}"
                             style="width: 60px; height: 60px; border-radius: 50%; object-fit: cover; border: 2px solid #FFD700;">
                      </td>
                      <td valign="top">
                        <p style="color: #333333; font-size: 18px; margin: 0;">
                          <strong>${posterName}</strong>
                        </p>
                        <p style="color: #666666; font-size: 15px; margin: 5px 0 0 0;">
                          vient de publier :
                        </p>
                      </td>
                    </tr>
                  </table>

                  <div style="margin-top: 20px; padding: 15px; background-color: #f9f9f9; border-radius: 10px;">
                    <p style="color: #444444; font-size: 16px; font-style: italic; margin: 0;">
                      "${postDescription}"
                    </p>
                  </div>

                  ${postImage ? `
                  <div style="margin-top: 20px; text-align: center;">
                    <img src="${postImage}" style="max-width: 100%; max-height: 250px; border-radius: 10px; box-shadow: 0 3px 10px rgba(0,0,0,0.1);">
                  </div>
                  ` : ''}

                  <div style="text-align: center; margin-top: 30px;">
                    <a href="https://afrolooki.web.app/post/${postId}"
                       style="background-color: #FFD700; color: #000000; padding: 14px 35px;
                              text-decoration: none; border-radius: 30px; font-weight: bold;
                              display: inline-block; font-size: 16px;">
                      Voir la publication →
                    </a>
                  </div>

                  <p style="color: #999999; font-size: 13px; text-align: center; margin-top: 20px;">
                    <a href="${PLAY_STORE_URL}" style="color: #FFD700;">Téléchargez l'application</a> pour ne rien manquer
                  </p>
                </td>
              </tr>

              <tr>
                <td style="background-color: #f8f8f8; padding: 20px; text-align: center; border-top: 1px solid #eeeeee;">
                  <p style="color: #999999; font-size: 12px; margin: 0;">
                    Afrolook Media - contact@afrolookmedia.com<br>
                    <a href="https://${APP_DOMAIN}/unsubscribe" style="color: #FFD700; text-decoration: none;">Gérer mes notifications</a>
                  </p>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </body>
    </html>
  `;
}

// ============================================
// FONCTION DE TEST (À SUPPRIMER APRÈS TEST)
// ============================================

export const testEmail = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Non authentifié");
  }

  await db.collection("mail").add({
    to: ["contact@afrolookmedia.com"], // Votre email de test
    message: {
      subject: "Test système email Afrolook Media",
      html: "<h1>Test réussi !</h1><p>Votre système d'email fonctionne parfaitement.</p>",
      from: EMAIL_FROM,
      replyTo: EMAIL_FROM,
    },
    createdAt: FieldValue.serverTimestamp(),
  });

  return { success: true, message: "Email de test envoyé" };
});



//////////// FEEXPAY


// ============================================================
// FEEXPAY FUNCTIONS FOR AFROLOOK
// ============================================================

// Configuration FeexPay (clés depuis les variables d'environnement)
const FEEXPAY_API_KEY_AFROLOOK = process.env.FEEXPAY_API_KEY!;
const FEEXPAY_SHOP_ID_AFROLOOK = process.env.FEEXPAY_SHOP_ID!;

// Configuration des frais FeexPay par opérateur
const FEEXPAY_FEES_CONFIG_AFROLOOK: Record<string, { payin: number; payout: number; total: number }> = {
  // Bénin
  'mtn': { payin: 1.7, payout: 1.7, total: 3.4 },
  'moov': { payin: 1.7, payout: 1.7, total: 3.4 },
  'celtiis_bj': { payin: 1.7, payout: 1.7, total: 3.4 },
  'coris': { payin: 1.7, payout: 1.7, total: 3.4 },
  // Togo
  'togocom_tg': { payin: 3.0, payout: 2.4, total: 5.4 },
  'moov_tg': { payin: 3.0, payout: 2.4, total: 5.4 },
  // Côte d'Ivoire
  'mtn_ci': { payin: 2.0, payout: 2.0, total: 4.0 },
  'moov_ci': { payin: 2.0, payout: 2.0, total: 4.0 },
  'wave_ci': { payin: 2.0, payout: 2.0, total: 4.0 },
  'orange_ci': { payin: 2.0, payout: 2.0, total: 4.0 },
  // Sénégal
  'orange_sn': { payin: 2.0, payout: 2.0, total: 4.0 },
  'free_sn': { payin: 2.0, payout: 2.0, total: 4.0 },
  'wave_sn': { payin: 2.0, payout: 2.0, total: 4.0 },
  // Congo
  'mtn_cg': { payin: 3.0, payout: 2.0, total: 5.0 },
};

const APP_FEE_RATE_AFROLOOK = 5.6;

function generateFeexpayTransKeyAfrolook(): string {
  return Math.random().toString(36).substring(2, 17);
}

function generateDepositNumberAfrolook(): string {
  const timestamp = Date.now().toString();
  const random = Math.floor(Math.random() * 1000).toString().padStart(3, "0");
  return `DEP${timestamp}${random}`;
}

function calculateAppGainAfrolook(amount: number, operatorCode: string): number {
  const feexpayTotal = FEEXPAY_FEES_CONFIG_AFROLOOK[operatorCode]?.total || 0;
  const appFee = amount * (APP_FEE_RATE_AFROLOOK / 100);
  const feexpayFee = amount * (feexpayTotal / 100);
  return Math.max(0, appFee - feexpayFee);
}

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

      // Vérifier que l'utilisateur existe
      const userRef = db.collection("Users").doc(userId);
      const userDoc = await userRef.get();
      if (!userDoc.exists) {
        throw new HttpsError("not-found", "Utilisateur non trouvé");
      }

      // ============================================================
      // CALCUL CORRECT DU MONTANT À CRÉDITER À L'UTILISATEUR
      // ============================================================
      const totalAmountToPay = Math.round(Number(amount));

      if (isNaN(totalAmountToPay) || totalAmountToPay < 100 || totalAmountToPay > 2000000) {
        throw new HttpsError("invalid-argument", "Le montant doit être entre 100 et 2.000.000 FCFA");
      }

      // Montant net à créditer après frais de 5.6%
      const amountWithoutFees = Math.floor(totalAmountToPay / (1 + APP_FEE_RATE_AFROLOOK / 100));
      const fees = totalAmountToPay - amountWithoutFees;
      const depositNumber = generateDepositNumberAfrolook();

      console.log("=== CALCUL DES MONTANTS ===");
      console.log(`Montant total payé: ${totalAmountToPay} FCFA`);
      console.log(`Frais Afrolook (5.6%): ${fees} FCFA`);
      console.log(`Montant net à créditer: ${amountWithoutFees} FCFA`);
      console.log(`Numéro de dépôt: ${depositNumber}`);

      // Générer les identifiants
      const transactionId = `${Date.now()}_${userId.substring(0, 5)}`;
      const transKey = generateFeexpayTransKeyAfrolook();

      // Créer la transaction en attente
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

      // Préparer callback_info
      const callbackInfo = JSON.stringify({
        userId,
        transactionId,
        type: "afrolook_deposit",
        transKey,
        depositNumber,
      });

      // URL de redirection après paiement
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
      // Clés depuis l'environnement sécurisé uniquement
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
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
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
          updatedAt: FieldValue.serverTimestamp()
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
 * 3. Webhook FeexPay pour Afrolook
 */
export const afrolookFeexpayWebhook = onRequest(
  { timeoutSeconds: 30, cors: true },
  async (req, res) => {
    try {
      res.set('Access-Control-Allow-Origin', '*');
      if (req.method === 'OPTIONS') {
        res.set('Access-Control-Allow-Methods', 'POST');
        res.set('Access-Control-Allow-Headers', 'Content-Type');
        res.status(204).send('');
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

      // Vérifier si déjà traitée
      const existingTx = await db.collection("transactions")
        .where("idTransactionFeexPay", "==", reference)
        .limit(1)
        .get();

      if (!existingTx.empty) {
        console.log(`✅ Transaction ${reference} déjà traitée`);
        res.status(200).send("OK");
        return;
      }

      const isSuccess = status === "SUCCESSFUL" || status === "SUCCESS" || status === "ACCEPTED";
      const isFailed = status === "FAILED";

      if (isFailed) {
        console.log(`❌ Paiement échoué: ${reference}`);

        const pendingQuery = await db.collection("pending_afrolook_feexpay_deposits")
          .where("reference", "==", reference)
          .limit(1)
          .get();

        if (!pendingQuery.empty) {
          await pendingQuery.docs[0].ref.update({
            status: "failed",
            processedAt: FieldValue.serverTimestamp(),
            webhookResponse: payload,
            failureReason: payload.reason
          });
        }

        res.status(200).send("OK");
        return;
      }

      if (!isSuccess) {
        console.log(`⏳ Paiement en attente: ${reference}`);
        res.status(200).send("OK");
        return;
      }

      console.log(`✅ Paiement réussi via webhook: ${reference}`);

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

      const userId = pendingData.userId;
      const totalAmount = pendingData.amount;
      const amountWithoutFees = pendingData.amountWithoutFees;
      const fees = pendingData.fees;
      const depositNumber = pendingData.depositNumber;
      const operatorCode = pendingData.operatorCode || 'unknown';
      const currentTimestamp = Date.now();

      const feexpayConfig = FEEXPAY_FEES_CONFIG_AFROLOOK[operatorCode] || { payin: 0, payout: 0, total: 0 };
      const feexpayFee = totalAmount * (feexpayConfig.total / 100);
      const appGain = calculateAppGainAfrolook(totalAmount, operatorCode);

      console.log(`=== RÉPARTITION DES FRAIS ===`);
      console.log(`Montant crédité à l'utilisateur: ${amountWithoutFees} FCFA`);
      console.log(`Frais FeexPay (${feexpayConfig.total}%): ${feexpayFee.toFixed(2)} FCFA`);
      console.log(`Gain Afrolook: ${appGain.toFixed(2)} FCFA`);

      await db.runTransaction(async (transaction) => {
        // Lecture utilisateur
        const userRef = db.collection("Users").doc(userId);
        const userDoc = await transaction.get(userRef);

        if (!userDoc.exists) {
          throw new Error(`Utilisateur non trouvé: ${userId}`);
        }

        const userData = userDoc.data();
        const currentSolde = userData?.votre_solde || 0;
        const currentSoldePrincipal = userData?.votre_solde_principal || 0;

        // Lecture configuration application
        const appConfigRef = db.collection("AppData").doc("XgkSxKc10vWsJJ2uBraT");
        const appConfigDoc = await transaction.get(appConfigRef);
        const appData = appConfigDoc.exists ? appConfigDoc.data() : {};

        // Mise à jour du solde utilisateur
        transaction.update(userRef, {
          votre_solde: currentSolde + amountWithoutFees,
          votre_solde_principal: currentSoldePrincipal + amountWithoutFees,
          updatedAt: currentTimestamp,
        });

        // Mise à jour des gains de l'application
        transaction.set(appConfigRef, {
          solde_principal: (appData?.solde_principal || 0) + amountWithoutFees,
          solde_gain: (appData?.solde_gain || 0) + (appGain > 0 ? appGain : 0),
          feexpay_fees_collected: (appData?.feexpay_fees_collected || 0) + feexpayFee,
          lastUpdated: FieldValue.serverTimestamp()
        }, { merge: true });

        // Création de la transaction standard
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

        // Création de la TransactionSolde
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

        // Mise à jour de la transaction en attente
        transaction.update(pendingDocRef, {
          status: "completed",
          processedAt: FieldValue.serverTimestamp(),
          webhookResponse: payload,
          appGain: appGain,
          feexpayFees: feexpayFee,
        });
      });

      console.log(`✅ Transaction ${reference} traitée avec succès`);
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

      // 1. Vérifier si déjà traitée
      const existingTx = await db.collection("transactions")
        .where("idTransactionFeexPay", "==", reference)
        .limit(1)
        .get();

      if (!existingTx.empty) {
        console.log(`✅ Transaction ${reference} déjà traitée`);
        return { status: "completed", success: true, message: "Déjà traité" };
      }

      // 2. Chercher la transaction en attente
      const pendingQuery = await db.collection("pending_afrolook_feexpay_deposits")
        .where("reference", "==", reference)
        .limit(1)
        .get();

      if (pendingQuery.empty) {
        console.error(`❌ Transaction pending non trouvée pour référence: ${reference}`);
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

      // 3. Vérifier auprès de l'API FeexPay
      try {
        const apiUrl = `https://api-v2.feexpay.me/api/transactions/public/single/status/${reference}`;
        const response = await axios.get(apiUrl, {
          headers: {
            'Authorization': `Bearer ${FEEXPAY_API_KEY_AFROLOOK}`,
            'Content-Type': 'application/json',
          },
        });

        const apiStatus = response.data.status;
        console.log(`Statut API FeexPay: ${apiStatus}`);

        if (apiStatus === "SUCCESSFUL") {
          // ============================================================
          // TRAITEMENT DIRECT DU PAIEMENT (comme le webhook)
          // ============================================================
          console.log(`✅ Paiement réussi, traitement en cours pour ${reference}`);

          const userId = pendingData.userId;
          const totalAmount = pendingData.amount;
          const amountWithoutFees = pendingData.amountWithoutFees;
          const fees = pendingData.fees;
          const depositNumber = pendingData.depositNumber;
          const operatorCode = pendingData.operatorCode || 'unknown';
          const currentTimestamp = Date.now();

          const feexpayConfig = FEEXPAY_FEES_CONFIG_AFROLOOK[operatorCode] || { payin: 0, payout: 0, total: 0 };
          const feexpayFee = totalAmount * (feexpayConfig.total / 100);
          const appGain = calculateAppGainAfrolook(totalAmount, operatorCode);

          console.log(`=== RÉPARTITION DES FRAIS ===`);
          console.log(`Montant crédité à l'utilisateur: ${amountWithoutFees} FCFA`);
          console.log(`Frais FeexPay (${feexpayConfig.total}%): ${feexpayFee.toFixed(2)} FCFA`);
          console.log(`Gain Afrolook: ${appGain.toFixed(2)} FCFA`);

          await db.runTransaction(async (transaction) => {
            // Lecture utilisateur
            const userRef = db.collection("Users").doc(userId);
            const userDoc = await transaction.get(userRef);

            if (!userDoc.exists) {
              throw new Error(`Utilisateur non trouvé: ${userId}`);
            }

            const userData = userDoc.data();
            const currentSolde = userData?.votre_solde || 0;
            const currentSoldePrincipal = userData?.votre_solde_principal || 0;

            // Lecture configuration application
            const appConfigRef = db.collection("AppData").doc("XgkSxKc10vWsJJ2uBraT");
            const appConfigDoc = await transaction.get(appConfigRef);
            const appData = appConfigDoc.exists ? appConfigDoc.data() : {};

            // Mise à jour du solde utilisateur
            transaction.update(userRef, {
              votre_solde: currentSolde + amountWithoutFees,
              votre_solde_principal: currentSoldePrincipal + amountWithoutFees,
              updatedAt: currentTimestamp,
            });

            // Mise à jour des gains de l'application
            transaction.set(appConfigRef, {
              solde_principal: (appData?.solde_principal || 0) + amountWithoutFees,
              solde_gain: (appData?.solde_gain || 0) + (appGain > 0 ? appGain : 0),
              feexpay_fees_collected: (appData?.feexpay_fees_collected || 0) + feexpayFee,
              lastUpdated: FieldValue.serverTimestamp()
            }, { merge: true });

            // Création de la transaction standard
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

            // Création de la TransactionSolde
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

            // Mise à jour de la transaction en attente
            transaction.update(pendingDocRef, {
              status: "completed",
              processedAt: FieldValue.serverTimestamp(),
              apiResponse: response.data,
              appGain: appGain,
              feexpayFees: feexpayFee,
            });
          });

          console.log(`✅ Transaction ${reference} traitée avec succès via checkStatus`);
          return {
            status: "completed",
            success: true,
            message: "Paiement confirmé et compte crédité",
            amount: amountWithoutFees
          };

        } else if (apiStatus === "FAILED") {
          console.log(`❌ Paiement échoué: ${reference}`);
          await pendingDocRef.update({
            status: "failed",
            processedAt: FieldValue.serverTimestamp(),
            failureReason: response.data.reason || "Paiement échoué"
          });
          return { status: "failed", success: false, message: response.data.reason || "Paiement échoué" };
        } else {
          console.log(`⏳ Paiement en attente: ${apiStatus}`);
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
