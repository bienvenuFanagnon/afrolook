import { onRequest } from "firebase-functions/v2/https";
import { createHash } from "crypto";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { emailTransporter } from "../shared/email_utils";

/**
 * Formulaire de contact du site (afrolookmedia.com). Le message est enregistré (ContactMessages, lisible seulement par
 * l'équipe) puis transmis par e-mail ; si l'e-mail échoue, le message reste enregistré.
 */

const SUBJECTS_FR = ["Aide sur mon compte", "Mes gains ou un retrait", "Une carte ou une publication", "Partenariat ou publicité", "Presse", "Signaler un contenu", "Autre"];
const SUBJECTS_EN = ["Help with my account", "My earnings or a withdrawal", "A card or a post", "Partnership or advertising", "Press", "Report content", "Other"];
// Boîte officielle du site + Gmail de secours : le message part aux deux, pour qu'il ne se perde jamais.
const TEAM_EMAILS = ["contact@afrolookmedia.com", "officiel.afrolook@gmail.com"];
// Le serveur d'envoi (LWS) n'accepte que l'adresse du compte SMTP comme expéditeur ; la réponse part vers la personne (replyTo).
const FROM = `"Afrolook (site)" <${process.env.SMTP_USER ?? "contact@afrolookmedia.com"}>`;
const MAX_PER_HOUR = 5;

export interface ContactInput { name: string; email: string; subject: string; message: string; lang: "fr" | "en" }

/** Vérifie et nettoie le contenu du formulaire ; retourne null si invalide. */
export function cleanContact(body: unknown): ContactInput | null {
  const b = (body ?? {}) as Record<string, unknown>;
  const str = (v: unknown, max: number) => String(v ?? "").replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, "").trim().slice(0, max);
  const name = str(b["name"], 80);
  const email = str(b["email"], 120).toLowerCase();
  const message = str(b["message"], 3000);
  const lang = b["lang"] === "en" ? "en" : "fr";
  const wanted = str(b["subject"], 80);
  const subject = [...SUBJECTS_FR, ...SUBJECTS_EN].includes(wanted) ? wanted : "Autre";
  if (name.length < 2 || message.length < 10) return null;
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) return null;
  return { name, email, subject, message, lang };
}

const escapeHtml = (s: string) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

export const contactMessage = onRequest(
  {
    region: "us-central1",
    timeoutSeconds: 20,
    maxInstances: 5,
    cors: [/^https:\/\/([a-z0-9-]+\.)?afrolookmedia\.com$/, /^https:\/\/afrolooki(--[a-z0-9-]+)?\.web\.app$/, /^https:\/\/afrolook-[a-z0-9-]+\.web\.app$/],
  },
  async (req, res) => {
    if (req.method !== "POST") { res.status(405).json({ ok: false }); return; }
    const body = typeof req.body === "string" ? safeJson(req.body) : req.body;
    // champ piège : un robot le remplit, une personne ne le voit pas. On répond « ok » sans rien enregistrer.
    if (body && typeof body === "object" && String((body as Record<string, unknown>)["website"] ?? "").trim() !== "") { res.json({ ok: true }); return; }
    const input = cleanContact(body);
    if (!input) { res.status(400).json({ ok: false, error: "invalid" }); return; }

    let saved: FirebaseFirestore.DocumentReference | null = null;
    const ip = String(req.headers["x-forwarded-for"] ?? req.ip ?? "").split(",")[0].trim();
    const ipHash = createHash("sha256").update(`afrolook-contact:${ip}`).digest("hex").slice(0, 32);
    try {
      const ref = db.collection("ContactRateLimits").doc(ipHash);
      const ok = await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        const now = Date.now();
        const d = snap.data() as { start?: number; n?: number } | undefined;
        const fresh = !d || !d.start || now - d.start > 3600_000;
        const n = fresh ? 0 : d?.n ?? 0;
        if (n >= MAX_PER_HOUR) return false;
        tx.set(ref, { start: fresh ? now : d!.start, n: n + 1 });
        return true;
      });
      if (!ok) { res.status(429).json({ ok: false, error: "rate" }); return; }

      saved = await db.collection("ContactMessages").add({ ...input, ipHash, userAgent: String(req.headers["user-agent"] ?? "").slice(0, 200), status: "new", createdAt: FieldValue.serverTimestamp() });
    } catch (e) {
      console.error("[contact] enregistrement impossible", e);
      res.status(500).json({ ok: false });
      return;
    }

    const mail = {
      replyTo: `"${input.name.replace(/"/g, "")}" <${input.email}>`,
      subject: `[Site] ${input.subject} — ${input.name}`,
      html: `<div style="font-family:Arial,sans-serif;max-width:560px"><h3 style="margin:0 0 12px">${escapeHtml(input.subject)}</h3>
<p style="margin:0 0 4px"><b>${escapeHtml(input.name)}</b> &lt;${escapeHtml(input.email)}&gt; · ${input.lang.toUpperCase()}</p>
<p style="white-space:pre-wrap;border-left:4px solid #2ecc71;padding-left:12px;margin:16px 0">${escapeHtml(input.message)}</p>
<p style="color:#888;font-size:12px">Message envoyé depuis afrolookmedia.com. Répondre à cet e-mail répond à la personne.</p></div>`,
    };
    // 1) boîte officielle + secours en un seul envoi ; 2) si le serveur d'envoi refuse tout, nouvel essai vers le seul Gmail.
    let mailStatus = "failed";
    let mailDetail = "";
    try {
      const r = await emailTransporter.sendMail({ from: FROM, to: TEAM_EMAILS, ...mail });
      mailStatus = (r.rejected?.length ?? 0) === 0 ? "sent" : "partial";
      mailDetail = `accepté: ${(r.accepted ?? []).join(", ")} · refusé: ${(r.rejected ?? []).join(", ")}`;
    } catch (e) {
      mailDetail = String((e as Error)?.message ?? e).slice(0, 300);
      console.error("[contact] envoi aux deux boîtes impossible, essai Gmail seul", e);
      try {
        await emailTransporter.sendMail({ from: FROM, to: TEAM_EMAILS[1], ...mail });
        mailStatus = "backup_only";
      } catch (e2) {
        console.error("[contact] e-mail non envoyé (le message reste enregistré)", e2);
      }
    }
    try { await saved?.update({ mailStatus, mailDetail }); } catch { /* sans gravité */ }
    res.json({ ok: true });
  }
);

function safeJson(s: string): unknown { try { return JSON.parse(s); } catch { return null; } }
