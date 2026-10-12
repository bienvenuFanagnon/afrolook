import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getAuth } from "firebase-admin/auth";
import { FieldValue } from "firebase-admin/firestore";
import { createHash } from "crypto";
import { db } from "../shared/firebase";
import { emailTransporter } from "../shared/email_utils";

/**
 * E-mails de validation d'adresse et de réinitialisation du mot de passe, envoyés par notre serveur d'envoi (SMTP LWS)
 * au lieu de l'expéditeur par défaut de Firebase, dont les messages n'arrivent pas toujours (spams, blocages).
 *
 * Le lien est généré par Firebase (Admin SDK) : il fonctionne comme celui de Firebase (même page de confirmation).
 * Si l'envoi échoue ici, la fonction répond « unavailable » et l'application se rabat sur l'envoi natif de Firebase :
 * on ne perd jamais l'e-mail. Chaque tentative est consignée dans AuthEmailLog (adresse masquée) pour suivre la réussite.
 *
 * Le serveur d'envoi n'accepte que l'adresse du compte SMTP comme expéditeur (voir site/contact.ts).
 */

const FROM = `"Afrolook" <${process.env.SMTP_USER ?? "contact@afrolookmedia.com"}>`;
const GOLD = "#FFD700";

const mask = (e: string) => { const [a, d] = e.split("@"); return `${a.slice(0, 2)}***@${(d ?? "").slice(0, 1)}***`; };
const hash = (s: string) => createHash("sha256").update(s).digest("hex").slice(0, 24);
const isEmail = (e: string) => /^[^\s@]{1,64}@[^\s@]{1,255}\.[^\s@]{2,}$/.test(e) && e.length <= 254;

/** Limite de demandes par clé et par heure (transaction : pas de dépassement en cas de clics rapprochés). */
async function allow(key: string, max: number): Promise<boolean> {
  const ref = db.collection("AuthEmailLimits").doc(key);
  const now = Date.now();
  return db.runTransaction(async (tx) => {
    const s = await tx.get(ref);
    const d = s.data() as { start?: number; count?: number } | undefined;
    if (!d || !d.start || now - d.start > 3600_000) { tx.set(ref, { start: now, count: 1 }); return true; }
    if ((d.count ?? 0) >= max) return false;
    tx.update(ref, { count: FieldValue.increment(1) });
    return true;
  });
}

function layout(title: string, intro: string, button: string, link: string, outro: string): string {
  return `<!DOCTYPE html><html lang="fr"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f5f5f5;font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#f5f5f5;padding:20px"><tr><td align="center">
<table width="520" cellpadding="0" cellspacing="0" style="max-width:100%;background:#ffffff;border-radius:14px;overflow:hidden">
<tr><td style="background:#000000;padding:22px;text-align:center"><span style="color:${GOLD};font-size:26px;font-weight:bold;letter-spacing:1px">AFROLOOK</span></td></tr>
<tr><td style="padding:30px 28px;color:#222222;font-size:16px;line-height:1.6">
<h2 style="margin:0 0 14px;font-size:20px;color:#000000">${title}</h2>
<p style="margin:0 0 22px">${intro}</p>
<p style="text-align:center;margin:0 0 24px"><a href="${link}" style="background:${GOLD};color:#000000;padding:14px 30px;border-radius:30px;text-decoration:none;font-weight:bold;display:inline-block">${button}</a></p>
<p style="margin:0 0 8px;font-size:13px;color:#666666">Si le bouton ne marche pas, copiez ce lien dans votre navigateur :</p>
<p style="margin:0 0 20px;font-size:12px;color:#666666;word-break:break-all">${link}</p>
<p style="margin:0;font-size:13px;color:#666666">${outro}</p>
</td></tr>
<tr><td style="background:#f8f8f8;padding:14px;text-align:center;font-size:12px;color:#999999">Afrolook Media · contact@afrolookmedia.com</td></tr>
</table></td></tr></table></body></html>`;
}

async function deliver(kind: "verify" | "reset", to: string, subject: string, html: string, text: string): Promise<void> {
  try {
    const info = await emailTransporter.sendMail({ from: FROM, to, subject, html, text });
    const accepted = (info.accepted ?? []).length > 0;
    await db.collection("AuthEmailLog").add({ kind, to: mask(to), ok: accepted, response: String(info.response ?? "").slice(0, 120), at: FieldValue.serverTimestamp() });
    if (!accepted) throw new Error("rejected");
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error(`E-mail ${kind} non envoyé`, msg);
    await db.collection("AuthEmailLog").add({ kind, to: mask(to), ok: false, error: msg.slice(0, 200), at: FieldValue.serverTimestamp() }).catch(() => undefined);
    throw new HttpsError("unavailable", "Envoi impossible pour le moment.");
  }
}

/** Renvoie le lien de validation de l'adresse e-mail du compte connecté. */
export const authSendVerificationEmail = onCall({ timeoutSeconds: 40, memory: "256MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Connexion requise.");
  const user = await getAuth().getUser(uid);
  if (!user.email) throw new HttpsError("failed-precondition", "Aucune adresse e-mail sur ce compte.");
  if (user.emailVerified) return { ok: true, already: true };
  if (!(await allow(`v_${uid}`, 6))) throw new HttpsError("resource-exhausted", "Trop de demandes. Réessayez dans une heure.");
  const link = await getAuth().generateEmailVerificationLink(user.email);
  await deliver(
    "verify", user.email, "Confirmez votre adresse e-mail pour Afrolook",
    layout("Confirmez votre adresse e-mail", "Bienvenue sur Afrolook ! Appuyez sur le bouton pour confirmer votre adresse e-mail et activer votre compte.", "Confirmer mon adresse", link, "Si vous n'avez pas créé de compte Afrolook, ignorez simplement ce message."),
    `Bienvenue sur Afrolook !\n\nConfirmez votre adresse e-mail en ouvrant ce lien :\n${link}\n\nSi vous n'avez pas créé de compte Afrolook, ignorez ce message.`,
  );
  return { ok: true };
});

/** Envoie le lien de réinitialisation du mot de passe. Même réponse que le compte existe ou non (pas de fuite d'information). */
export const authSendPasswordReset = onCall({ timeoutSeconds: 40, memory: "256MiB" }, async (request) => {
  const email = String((request.data as { email?: unknown } | undefined)?.email ?? "").trim().toLowerCase();
  if (!isEmail(email)) throw new HttpsError("invalid-argument", "Adresse e-mail invalide.");
  const ip = request.rawRequest?.ip ?? "";
  if (!(await allow(`rp_${hash(email)}`, 4)) || !(await allow(`ri_${hash(ip)}`, 30))) {
    throw new HttpsError("resource-exhausted", "Trop de demandes. Réessayez dans une heure.");
  }
  let link: string;
  try {
    const u = await getAuth().getUserByEmail(email);
    if (u.disabled) return { ok: true };
    link = await getAuth().generatePasswordResetLink(email);
  } catch (e) {
    const code = (e as { code?: string }).code ?? "";
    if (code === "auth/user-not-found") return { ok: true };
    console.error("Lien de réinitialisation", code);
    throw new HttpsError("unavailable", "Envoi impossible pour le moment.");
  }
  await deliver(
    "reset", email, "Réinitialisez votre mot de passe Afrolook",
    layout("Nouveau mot de passe", "Vous avez demandé à changer votre mot de passe Afrolook. Appuyez sur le bouton pour en choisir un nouveau.", "Changer mon mot de passe", link, "Si vous n'êtes pas à l'origine de cette demande, ignorez ce message : votre mot de passe ne change pas."),
    `Vous avez demandé à changer votre mot de passe Afrolook.\n\nOuvrez ce lien pour en choisir un nouveau :\n${link}\n\nSi vous n'êtes pas à l'origine de cette demande, ignorez ce message.`,
  );
  return { ok: true };
});
