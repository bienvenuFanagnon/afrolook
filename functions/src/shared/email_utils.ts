import * as nodemailer from "nodemailer";
import { db } from "./firebase";
import { APP_DOMAIN, PLAY_STORE_URL } from "./config";

// Configuration SMTP LWS
export const emailTransporter = nodemailer.createTransport({
  host: "mail96.lwspanel.com",
  port: 587,
  secure: false,
  auth: {
    user: process.env.SMTP_USER!,
    pass: process.env.SMTP_PASS!,
  },
  tls: {
    servername: "mail96.lwspanel.com",
    rejectUnauthorized: true,
  },
});

/**
 * Rate limiter pour éviter le spam (max 10 emails par heure par utilisateur)
 */
export async function checkEmailRateLimit(userId: string): Promise<boolean> {
  const oneHourAgo = Date.now() - 60 * 60 * 1000;

  const recentEmails = await db.collection("mail")
    .where("userId", "==", userId)
    .where("createdAt", ">", new Date(oneHourAgo))
    .count()
    .get();

  return recentEmails.data().count < 10;
}

/**
 * Vérifie si l'utilisateur a accepté les emails marketing
 */
export async function canSendMarketingEmail(userData: any): Promise<boolean> {
  if (!userData.emailNotifications) {
    return true;
  }
  return userData.emailNotifications.marketing !== false;
}

// ============================================
// TEMPLATE D'EMAIL PRÉDÉFINI AFROLOOK
// ============================================

export const INACTIVE_USER_EMAIL_TEMPLATE = `
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

/**
 * Génère le HTML de l'email en masse
 */
export function generateEmailHTML({ subject, message, imageUrl, userName, priority }: any): string {
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
              ` : ""}

              <!-- Contenu principal -->
              <tr>
                <td style="padding: 40px 30px;">
                  <p style="color: #666666; font-size: 16px; line-height: 1.6; margin-bottom: 20px;">
                    Bonjour <strong style="color: #000000;">${userName}</strong>,
                  </p>
                  <div style="color: #333333; font-size: 16px; line-height: 1.8; margin: 20px 0;">
                    ${message.replace(/\n/g, "<br>")}
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
export function generateInteractionEmailHTML({ subject, message, interactorName, interactorImage, postImage, postId, type }: any): string {
  const getIcon = () => {
    switch (type) {
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
                        <img src="${interactorImage || "https://play-lh.googleusercontent.com/g5_LdDrb8s5Kvw0-dFc8o8RgFLHUxLlsG0yd-DXXzceX9qPrYwZvfHQ2M2jTFqxnEBUo=w240-h480-rw"}"
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
                  ` : ""}

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
