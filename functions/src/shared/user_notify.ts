import { db } from "./firebase";
import { sendToOneSignal } from "./notification_utils";
import { emailTransporter } from "./email_utils";
import { EMAIL_FROM, EMAIL_REPLY_TO, APP_DOMAIN } from "./config";
import { adminDocs } from "./admin_notify";

/**
 * Prévenir une personne (ou les administrateurs) d'un événement qui les concerne : un message dans la liste des notifications de
 * l'application, une notification push (OneSignal) et un e-mail. Messages « de service » : envoyés même si les e-mails marketing sont coupés.
 * Ne lève jamais d'erreur : un échec d'envoi ne doit pas faire échouer le traitement qui l'a déclenché.
 *
 * `target` : écran à ouvrir quand on touche la notification dans l'application (géré dans mes_notifications.dart) :
 *   MY_SOUND (Mes sons), MY_AD (Mes publicités), ADMIN_SOUNDS (modération des sons), ADMIN_ADS (validation des publicités).
 */
const APP_DATA_DOC = "XgkSxKc10vWsJJ2uBraT";

export type NotifyTarget = "MY_SOUND" | "MY_AD" | "ADMIN_SOUNDS" | "ADMIN_ADS";

export interface EmailContent {
  subject: string;
  /** Titre affiché en haut de l'e-mail. */
  heading: string;
  /** Pictogramme (emoji) du bandeau. */
  icon: string;
  /** Texte d'introduction (HTML simple autorisé : déjà échappé par l'appelant). */
  intro: string;
  /** Lignes « libellé : valeur » (valeurs échappées ici). */
  rows?: Array<[string, string]>;
  /** Bouton d'action facultatif. */
  button?: { label: string; url: string };
  /** Texte de bas de message (conseil, suite…). */
  outro?: string;
  /** Couleur du bandeau : accord (vert), refus (rouge), neutre (doré). */
  tone?: "ok" | "no" | "info";
}

export const esc = (s: unknown): string =>
  String(s ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

const TONES = { ok: "#1FA45B", no: "#E21221", info: "#C9A227" };

/** Corps d'e-mail aux couleurs d'Afrolook (même style que les autres e-mails de l'application). */
export function buildEmailHtml(c: EmailContent): string {
  const tone = TONES[c.tone ?? "info"];
  const rows = (c.rows ?? []).filter(([, v]) => v !== "" && v != null).map(([k, v]) => `
          <div style="display:flex;justify-content:space-between;gap:12px;padding:8px 0;border-bottom:1px solid #333333;">
            <span style="color:#AAAAAA;font-size:13px;">${esc(k)}</span>
            <span style="color:#FFFFFF;font-size:13px;font-weight:600;text-align:right;">${esc(v)}</span>
          </div>`).join("");
  return `<!DOCTYPE html>
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>${esc(c.subject)}</title></head>
<body style="margin:0;padding:0;font-family:'Segoe UI',Helvetica,Arial,sans-serif;background:#0a0a0a;">
  <table width="100%" cellpadding="0" cellspacing="0" style="padding:20px;background:#0a0a0a;"><tr><td align="center">
    <table width="560" cellpadding="0" cellspacing="0" style="max-width:100%;background:#1a1a1a;border-radius:18px;overflow:hidden;border:1px solid #2a2a2a;">
      <tr><td style="background:${tone};padding:28px 24px;text-align:center;">
        <div style="font-size:38px;margin-bottom:6px;">${c.icon}</div>
        <h1 style="color:#FFFFFF;margin:0;font-size:21px;font-weight:800;">${esc(c.heading)}</h1>
      </td></tr>
      <tr><td style="padding:26px 24px;">
        <p style="color:#DDDDDD;font-size:15px;line-height:1.55;margin:0 0 18px;">${c.intro}</p>
        ${rows ? `<div style="background:#252525;border-radius:12px;border:1px solid #333;padding:6px 18px;margin-bottom:18px;">${rows}</div>` : ""}
        ${c.outro ? `<p style="color:#BBBBBB;font-size:13.5px;line-height:1.55;margin:0 0 18px;">${c.outro}</p>` : ""}
        ${c.button ? `<div style="text-align:center;margin:24px 0 6px;"><a href="${esc(c.button.url)}" style="background:#FFD700;color:#1a1a1a;padding:13px 34px;text-decoration:none;border-radius:50px;font-weight:700;font-size:15px;display:inline-block;">${esc(c.button.label)}</a></div>` : ""}
      </td></tr>
      <tr><td style="background:#111111;padding:16px 24px;text-align:center;border-top:1px solid #2a2a2a;">
        <p style="color:#666666;font-size:11px;margin:0;">© ${new Date().getFullYear()} Afrolook — message automatique<br>Pour nous écrire : contact@${APP_DOMAIN}</p>
      </td></tr>
    </table>
  </td></tr></table>
</body></html>`;
}

async function pushTo(oneSignalIds: string[], title: string, message: string): Promise<void> {
  const ids = oneSignalIds.filter(Boolean);
  if (!ids.length) return;
  try {
    const cfg = (await db.collection("AppData").doc(APP_DATA_DOC).get()).data() ?? {};
    if (!cfg["one_signal_app_id"] || !cfg["one_signal_api_key"]) return;
    await sendToOneSignal(ids, message, title, cfg["app_logo"] ?? "", cfg["one_signal_app_id"], cfg["one_signal_api_key"],
      { type_notif: "COMPTE_OFFICIEL", post_id: "", post_type: "", chat_id: "" });
  } catch (e) {
    console.error("[user_notify] push non envoyé", e);
  }
}

async function inApp(receiverId: string, title: string, message: string, target?: NotifyTarget, refId?: string): Promise<void> {
  const now = Date.now() * 1000;
  const ref = db.collection("Notifications").doc();
  await ref.set({
    id: ref.id, titre: title, description: message,
    type: "COMPTE_OFFICIEL", post_data_type: target ?? "",
    user_id: receiverId, receiver_id: receiverId, post_id: refId ?? "",
    is_open: false, users_id_view: [], status: "VALIDE",
    created_at: now, updated_at: now, createdAt: now, updatedAt: now,
  });
}

async function mail(to: string | string[], c: EmailContent): Promise<void> {
  const list = (Array.isArray(to) ? to : [to]).filter((e) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e));
  if (!list.length) return;
  try {
    await emailTransporter.sendMail({ from: EMAIL_FROM, replyTo: EMAIL_REPLY_TO, to: list, subject: c.subject, html: buildEmailHtml(c) });
  } catch (e) {
    console.error("[user_notify] e-mail non envoyé", list.join(","), e);
  }
}

/** Prévient une personne : notification dans l'application + push + e-mail. */
export async function notifyUser(opts: { userId: string; title: string; message: string; target?: NotifyTarget; refId?: string; email?: EmailContent }): Promise<void> {
  try {
    const snap = await db.collection("Users").doc(opts.userId).get();
    if (!snap.exists) return;
    const u = snap.data() ?? {};
    await Promise.all([
      inApp(opts.userId, opts.title, opts.message, opts.target, opts.refId).catch((e) => console.error("[user_notify] notif", e)),
      pushTo([String(u["oneIgnalUserid"] ?? "")], opts.title, opts.message),
      opts.email && u["email"] ? mail(String(u["email"]), opts.email) : Promise.resolve(),
    ]);
  } catch (e) {
    console.error("[user_notify] notifyUser", e);
  }
}

/** Prévient tous les administrateurs : notification dans l'application + push + e-mail. */
export async function notifyAdminsAll(opts: { title: string; message: string; target?: NotifyTarget; refId?: string; email?: EmailContent }): Promise<void> {
  try {
    const admins = await adminDocs();
    if (!admins.length) return;
    await Promise.all([
      ...admins.map((a) => inApp(a.id, opts.title, opts.message, opts.target, opts.refId).catch((e) => console.error("[user_notify] notif admin", e))),
      pushTo(admins.map((a) => String(a.data()["oneIgnalUserid"] ?? "")), opts.title, opts.message),
      opts.email ? mail(admins.map((a) => String(a.data()["email"] ?? "")), opts.email) : Promise.resolve(),
    ]);
  } catch (e) {
    console.error("[user_notify] notifyAdminsAll", e);
  }
}
