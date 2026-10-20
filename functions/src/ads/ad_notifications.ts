import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { db } from "../shared/firebase";
import { emailTransporter } from "../shared/email_utils";
import { APP_DOMAIN, APP_WEB_URL_AFRO } from "../shared/config";
import { notifyAdminsAll, notifyUser, esc } from "../shared/user_notify";

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

    // Notification dans l'application + push (en plus de l'e-mail ci-dessous)
    await notifyAdminsAll({
      title: "📢 Nouvelle demande de publicité",
      message: `${ad.ownerName || ad.userName || "Un utilisateur"} demande une publicité (${ad.pricePaid ?? ad.price ?? ad.amount ?? "—"} FCFA). Ouvre la validation des publicités.`,
      target: "ADMIN_ADS",
      refId: event.params.adId,
    });

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

/**
 * Demande de publicité traitée : l'annonceur (champ `createdBy`) reçoit une notification (application + push) et un e-mail.
 * - en attente → active : acceptée (la diffusion commence) ;
 * - en attente → rejetée : refusée, avec le motif, et remboursée (le remboursement est fait par l'écran d'administration) ;
 * - active → annulée : arrêtée par l'équipe.
 * Les changements automatiques (expiration) et les statistiques n'envoient rien.
 */
export const notifyAdvertiserOnAdDecision = onDocumentUpdated(
  { document: "Advertisements/{adId}", timeoutSeconds: 60, memory: "256MiB", maxInstances: 5 },
  async (event) => {
    const before = event.data?.before.data() as Record<string, any> | undefined;
    const after = event.data?.after.data() as Record<string, any> | undefined;
    if (!before || !after) return;
    const from = String(before.status ?? ""), to = String(after.status ?? "");
    if (from === to) return;
    const accepted = from === "pending" && to === "active";
    const rejected = from === "pending" && to === "rejected";
    const stopped = from === "active" && to === "cancelled";
    if (!accepted && !rejected && !stopped) return;
    const userId = String(after.createdBy ?? "");
    if (!userId) return;
    const name = String(after.ownerName ?? "").trim().slice(0, 60) || "ta publicité";
    const days = Number(after.durationDays) || 0;
    const paid = Number(after.pricePaid) || 0;
    const reason = String(after.rejectionReason ?? "").trim().slice(0, 300);
    const app = { label: "Voir mes publicités", url: APP_WEB_URL_AFRO };

    if (accepted) {
      await notifyUser({
        userId, target: "MY_AD", refId: event.params.adId,
        title: "📢 Ta publicité est acceptée !",
        message: `Ta publicité « ${name} » est en ligne${days ? ` pour ${days} jour${days > 1 ? "s" : ""}` : ""}. Suis ses vues et ses clics dans « Mes publicités ».`,
        email: {
          subject: "📢 Ta publicité est acceptée sur Afrolook", heading: "Ta publicité est acceptée !", icon: "📢", tone: "ok",
          intro: `Bonne nouvelle : ta publicité <b>« ${esc(name)} »</b> a été validée et sa diffusion a commencé.`,
          rows: [["Publicité", name], ["Durée", days ? `${days} jour${days > 1 ? "s" : ""}` : ""], ["Montant payé", paid ? `${paid} FCFA` : ""]],
          outro: "Tu peux suivre les vues et les clics depuis « Mes publicités » dans l'application.", button: app,
        },
      });
    } else if (rejected) {
      await notifyUser({
        userId, target: "MY_AD", refId: event.params.adId,
        title: "Ta publicité n'a pas été acceptée",
        message: `« ${name} » a été refusée${reason ? ` : ${reason}` : "."}${paid ? " Tu es remboursé(e) sur ton solde." : ""}`,
        email: {
          subject: "Ta publicité n'a pas été acceptée", heading: "Ta publicité n'a pas été acceptée", icon: "🚫", tone: "no",
          intro: `Après examen, ta publicité <b>« ${esc(name)} »</b> n'a pas pu être diffusée.`,
          rows: [["Publicité", name], ["Motif", reason || "Non conforme aux règles de diffusion"], ["Remboursement", paid ? `${paid} FCFA remis sur ton solde` : ""]],
          outro: "Tu peux corriger ta demande et en soumettre une nouvelle à tout moment.", button: app,
        },
      });
    } else {
      await notifyUser({
        userId, target: "MY_AD", refId: event.params.adId,
        title: "⏹️ Ta publicité a été arrêtée",
        message: `Ta publicité « ${name} » a été arrêtée par l'équipe${reason ? ` : ${reason}` : "."}`,
        email: {
          subject: "Ta publicité a été arrêtée", heading: "Ta publicité a été arrêtée", icon: "⏹️", tone: "info",
          intro: `Ta publicité <b>« ${esc(name)} »</b> n'est plus diffusée.`,
          rows: [["Publicité", name], ["Motif", reason]],
          outro: "Si tu as une question, réponds simplement à cet e-mail.", button: app,
        },
      });
    }
  },
);
