import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { db } from "../shared/firebase";
import { emailTransporter } from "../shared/email_utils";
import { APP_DOMAIN } from "../shared/config";

const ADMIN_ROLES = ["ADM", "admin", "ADMIN", "super_admin"];
const EMAIL_FROM = '"Afrolook" <epargneplus@epargneplusfinance.com>';

function buildAdminEmailHtml(ad: Record<string, any>): string {
  const ownerName = ad.ownerName || ad.userName || "Inconnu";
  const boostType = ad.boostType || (ad.postId ? "post" : "entité");
  const amount = ad.price ?? ad.amount ?? "—";
  const country = ad.country || "—";
  const duration = ad.duration ? `${ad.duration} jours` : "—";
  const submittedAt = new Date().toLocaleString("fr-FR", { timeZone: "Africa/Porto-Novo" });

  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Nouvelle demande de publicité</title>
</head>
<body style="margin:0;padding:0;font-family:'Segoe UI',Helvetica,Arial,sans-serif;background:#0a0a0a;">
  <table width="100%" cellpadding="0" cellspacing="0" style="padding:20px;background:#0a0a0a;">
    <tr><td align="center">
      <table width="560" cellpadding="0" cellspacing="0" style="background:#1a1a1a;border-radius:18px;overflow:hidden;border:1px solid #2a2a2a;">

        <!-- Header -->
        <tr>
          <td style="background:linear-gradient(135deg,#E21221 0%,#FF4444 100%);padding:30px 24px;text-align:center;">
            <div style="font-size:40px;margin-bottom:8px;">📢</div>
            <h1 style="color:#FFD700;margin:0;font-size:22px;font-weight:800;">Nouvelle demande de publicité</h1>
            <p style="color:rgba(255,255,255,0.85);margin:8px 0 0;font-size:14px;">Afrolook — Panneau d'administration</p>
          </td>
        </tr>

        <!-- Body -->
        <tr>
          <td style="padding:28px 24px;">
            <p style="color:#DDDDDD;font-size:15px;margin:0 0 20px;">
              Une nouvelle demande de publicité vient d'être soumise et attend votre validation.
            </p>

            <!-- Info card -->
            <table width="100%" cellpadding="0" cellspacing="0" style="background:#252525;border-radius:12px;border:1px solid #333;overflow:hidden;">
              <tr>
                <td style="padding:18px 20px;">
                  ${[
                    ["👤 Demandeur", ownerName],
                    ["📦 Type de boost", boostType],
                    ["💰 Montant", `${amount} FCFA`],
                    ["🌍 Pays ciblé", country],
                    ["⏱ Durée", duration],
                    ["🕐 Soumis le", submittedAt],
                  ].map(([label, value]) => `
                  <div style="display:flex;justify-content:space-between;padding:8px 0;border-bottom:1px solid #333333;">
                    <span style="color:#AAAAAA;font-size:13px;">${label}</span>
                    <span style="color:#FFFFFF;font-size:13px;font-weight:600;">${value}</span>
                  </div>`).join("")}
                </td>
              </tr>
            </table>

            <!-- CTA -->
            <div style="text-align:center;margin:28px 0 10px;">
              <a href="https://${APP_DOMAIN}/admin/ads"
                 style="background:#FFD700;color:#1a1a1a;padding:14px 36px;text-decoration:none;
                        border-radius:50px;font-weight:700;font-size:15px;display:inline-block;">
                Voir la demande →
              </a>
            </div>
          </td>
        </tr>

        <!-- Footer -->
        <tr>
          <td style="background:#111111;padding:18px 24px;text-align:center;border-top:1px solid #2a2a2a;">
            <p style="color:#666666;font-size:11px;margin:0;">
              © ${new Date().getFullYear()} Afrolook — Notification automatique interne<br>
              contact@afrolookmedia.com
            </p>
          </td>
        </tr>

      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

export const notifyAdminsOnNewAd = onDocumentCreated(
  { document: "Advertisements/{adId}", timeoutSeconds: 30 },
  async (event) => {
    const ad = event.data?.data() as Record<string, any> | undefined;
    if (!ad) return;

    // Récupère tous les admins avec un email
    const adminsSnap = await db.collection("Users")
      .where("email", "!=", "")
      .get();

    const adminEmails = adminsSnap.docs
      .filter(doc => {
        const role: string = (doc.data().role ?? "").toUpperCase();
        return ADMIN_ROLES.some(r => r.toUpperCase() === role);
      })
      .map(doc => doc.data().email as string)
      .filter(Boolean);

    if (adminEmails.length === 0) {
      console.log("Aucun admin avec email trouvé.");
      return;
    }

    const html = buildAdminEmailHtml(ad);

    await emailTransporter.sendMail({
      from: EMAIL_FROM,
      to: adminEmails,
      subject: "📢 Nouvelle demande de publicité sur Afrolook",
      html,
    });

    console.log(`Email pub envoyé à ${adminEmails.length} admin(s): ${adminEmails.join(", ")}`);
  }
);
