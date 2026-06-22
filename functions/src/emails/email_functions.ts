import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import {
  emailTransporter,
  checkEmailRateLimit,
  canSendMarketingEmail,
  INACTIVE_USER_EMAIL_TEMPLATE,
  generateEmailHTML,
} from "../shared/email_utils";
import {
  EMAIL_FROM,
  APP_DOMAIN,
  APP_PLAY_STORE_URL_AFRO,
  APP_WEB_URL_AFRO,
} from "../shared/config";

// Interface pour les emails en masse
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
 * Récupère les utilisateurs inactifs depuis 5 jours qui n'ont pas reçu d'email ce mois-ci
 */
async function getInactiveUsersToNotify(limit: number = 10): Promise<any[]> {
  const now = Date.now();
  const fiveDaysAgo = now - (5 * 24 * 60 * 60 * 1000);
  const startOfMonth = new Date(now);
  startOfMonth.setDate(1);
  startOfMonth.setHours(0, 0, 0, 0);
  const startOfMonthTimestamp = startOfMonth.getTime();

  const usersSnapshot = await db.collection("Users")
    .where("last_time_active", "<", fiveDaysAgo)
    .where("last_time_active", ">", 0)
    .limit(limit * 2)
    .get();

  const usersToNotify = [];

  for (const doc of usersSnapshot.docs) {
    const userData = doc.data();
    const userId = doc.id;

    const remindersSnapshot = await db.collection("user_email_reminders")
      .where("userId", "==", userId)
      .where("sentAt", ">=", startOfMonthTimestamp)
      .count()
      .get();

    const emailCountThisMonth = remindersSnapshot.data().count || 0;

    if (emailCountThisMonth < 2) {
      const sevenDaysAgo = now - (7 * 24 * 60 * 60 * 1000);

      const postsSnapshot = await db.collection("Posts")
        .where("user_id", "==", userId)
        .get();

      let newLikesCount = 0;
      for (const postDoc of postsSnapshot.docs) {
        const post = postDoc.data();
        const postCreatedAt = post["created_at"] || 0;
        let postCreatedAtMillis = postCreatedAt;

        if (postCreatedAt > 1000000000000) {
          postCreatedAtMillis = postCreatedAt / 1000;
        }

        if (postCreatedAtMillis > sevenDaysAgo) {
          newLikesCount += (post["loves"] as number || 0);
        }
      }

      usersToNotify.push({
        userId: userId,
        userData: {
          userId: userId,
          userEmail: userData["email"] || "",
          userName: userData["pseudo"] || userData["fullName"] || "Utilisateur",
          pseudo: userData["pseudo"] || "user",
          giftCoinsBalance: userData["giftCoinsBalance"] || 0,
          soldePrincipal: userData["votre_solde_principal"] || 0,
          totalCoinsEarned: userData["totalCoinsEarnedFromLikes"] || 0,
          totalLikesReceived: userData["totalLikesReceived"] || 0,
          totalFollowers: (userData["userAbonnesIds"] as any[])?.length || 0,
          daysInactive: Math.floor((now - (userData["last_time_active"] || now)) / (24 * 60 * 60 * 1000)),
          newLikesOnMyPosts: newLikesCount,
          newCommentsOnMyPosts: 0,
        },
      });
    }

    if (usersToNotify.length >= limit) break;
  }

  return usersToNotify.slice(0, limit);
}

/**
 * Envoie un email personnalisé à un utilisateur inactif
 */
export const sendInactiveUserReminder = onCall(
  { timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentification requise");
    }

    const { userId, userData } = request.data;

    if (!userId || !userData) {
      console.error("Paramètres manquants:", { userId, userData });
      throw new HttpsError("invalid-argument", "userId et userData requis");
    }

    if (!userData.userEmail) {
      console.error("Email manquant pour l'utilisateur:", userId);
      throw new HttpsError("invalid-argument", "Email utilisateur requis");
    }

    console.log("Envoi d'email à:", {
      userId: userId,
      email: userData.userEmail,
      userName: userData.userName,
      daysInactive: userData.daysInactive,
    });

    try {
      const playStoreUrl = APP_PLAY_STORE_URL_AFRO;
      const webUrl = APP_WEB_URL_AFRO;

      const hasMoneyToClaim = (userData.giftCoinsBalance > 0 || userData.soldePrincipal > 0)
        ? "ARGENT EN ATTENTE"
        : "VOTRE COMPTE VOUS ATTEND";

      let emailHtml = INACTIVE_USER_EMAIL_TEMPLATE
        .replace(/{{userName}}/g, userData.userName || "Utilisateur")
        .replace(/{{pseudo}}/g, userData.pseudo || "user")
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

      console.log(`Email envoyé avec succès à ${userData.userEmail}`);

      await db.collection("user_email_reminders").add({
        userId: userId,
        userEmail: userData.userEmail,
        userName: userData.userName,
        daysInactive: userData.daysInactive,
        giftCoinsBalance: userData.giftCoinsBalance,
        soldePrincipal: userData.soldePrincipal,
        sentAt: Date.now(),
        createdAt: FieldValue.serverTimestamp(),
        testMode: true,
      });

      return {
        success: true,
        message: `Email envoyé à ${userData.userEmail}`,
        testMode: true,
      };

    } catch (error: any) {
      console.error("Erreur sendInactiveUserReminder:", error);
      throw new HttpsError("internal", error.message);
    }
  }
);

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

      console.log(`Email de test envoyé à ${testUserData.userEmail}`);

      return {
        success: true,
        message: `Email de test envoyé à ${testUserData.userEmail}`,
      };

    } catch (error: any) {
      console.error("Erreur testAfrolookEmail:", error);
      throw new HttpsError("internal", error.message);
    }
  }
);

/**
 * Récupère les utilisateurs inactifs et leur envoie un email
 */
export const processInactiveUsersReminder = onCall(
  { timeoutSeconds: 120, memory: "512MiB" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentification requise");
    }

    console.log("Début du traitement des utilisateurs inactifs");

    try {
      const usersToNotify = await getInactiveUsersToNotify(10);

      console.log(`${usersToNotify.length} utilisateurs inactifs à notifier`);

      if (usersToNotify.length === 0) {
        return { success: true, message: "Aucun utilisateur à notifier", processed: 0 };
      }

      const emailPromises = usersToNotify.map(async (user) => {
        try {
          const playStoreUrl = APP_PLAY_STORE_URL_AFRO;
          const webUrl = APP_WEB_URL_AFRO;

          const hasMoneyToClaim = (user.userData.giftCoinsBalance > 0 || user.userData.soldePrincipal > 0)
            ? "ARGENT EN ATTENTE"
            : "VOTRE COMPTE VOUS ATTEND";

          let emailHtml = INACTIVE_USER_EMAIL_TEMPLATE
            .replace(/{{userName}}/g, user.userData.userName || "Utilisateur")
            .replace(/{{pseudo}}/g, user.userData.pseudo || "user")
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

          await db.collection("user_email_reminders").add({
            userId: user.userId,
            userEmail: user.userData.userEmail,
            userName: user.userData.userName,
            daysInactive: user.userData.daysInactive,
            giftCoinsBalance: user.userData.giftCoinsBalance,
            soldePrincipal: user.userData.soldePrincipal,
            sentAt: Date.now(),
            createdAt: FieldValue.serverTimestamp(),
            source: "auto_reminder",
          });

          console.log(`Email envoyé à ${user.userData.userEmail}`);
          return { userId: user.userId, success: true };
        } catch (error) {
          console.error(`Erreur pour ${user.userId}:`, error);
          return { userId: user.userId, success: false, error: String(error) };
        }
      });

      const results = await Promise.allSettled(emailPromises);
      const successCount = results.filter(r => r.status === "fulfilled" && (r as any).value.success).length;

      console.log(`Résultat: ${successCount}/${usersToNotify.length} emails envoyés`);

      return {
        success: true,
        message: `${successCount} emails envoyés sur ${usersToNotify.length}`,
        processed: successCount,
        total: usersToNotify.length,
      };

    } catch (error: any) {
      console.error("Erreur processInactiveUsersReminder:", error);
      return { success: false, message: error.message, processed: 0 };
    }
  }
);

/**
 * Envoi d'emails en masse
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

      const senderDoc = await db.collection("Users").doc(senderId).get();
      const senderData = senderDoc.data();

      const adminRoles = ["ADM", "admin", "ADMIN", "super_admin"];
      if (!adminRoles.includes(senderData?.role?.toUpperCase() || "")) {
        throw new HttpsError("permission-denied", "Seuls les admins peuvent envoyer des emails en masse");
      }

      let targetUsers: any[] = [];

      if (targetType === "all") {
        const usersSnapshot = await db.collection("Users")
          .where("email", "!=", null)
          .where("email", "!=", "")
          .get();

        targetUsers = usersSnapshot.docs.filter(doc =>
          canSendMarketingEmail(doc.data())
        );
      } else if (targetType === "specific" && specificUserIds) {
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

      console.log(`Préparation de ${targetUsers.length} emails`);

      const emailBatch = db.batch();
      const emailCollection = db.collection("mail");
      const emailId = `bulk_${Date.now()}_${Math.random().toString(36).substring(7)}`;

      for (const userDoc of targetUsers) {
        const userData = userDoc.data();
        const userEmail = userData.email;

        if (!userEmail) continue;

        const canSend = await checkEmailRateLimit(userDoc.id);
        if (!canSend) continue;

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
              priority,
            }),
            from: EMAIL_FROM,
            replyTo: EMAIL_FROM,
          },
          headers: {
            "X-Priority": priority === "high" ? "1" : "3",
            "X-Mailer": "Afrolook Media Email System",
            "List-Unsubscribe": `<https://${APP_DOMAIN}/unsubscribe?email=${encodeURIComponent(userEmail)}>`,
            "List-Unsubscribe-Post": "List-Unsubscribe=One-Click",
          },
          createdAt: FieldValue.serverTimestamp(),
          bulkId: emailId,
          userId: userDoc.id,
          status: "pending",
        });
      }

      await emailBatch.commit();

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
      console.error("Erreur sendBulkEmail:", error);
      throw new HttpsError("internal", "Erreur lors de l'envoi des emails", error);
    }
  }
);

/**
 * Fonction de test simple
 */
export const testEmail = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Non authentifié");
  }

  await db.collection("mail").add({
    to: ["contact@afrolookmedia.com"],
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
