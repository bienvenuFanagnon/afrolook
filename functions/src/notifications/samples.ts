import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db } from "../shared/firebase";
import { adminDocs } from "../shared/admin_notify";
import { deliverPush } from "../shared/push";
import { previewFromChronique, previewFromPost, previewFromSound } from "../shared/preview";
import { ReminderKind, typeNotifFor } from "./policy_logic";
import { AD_LABEL, NEW_CREATOR_BODY, NEW_CREATOR_LABEL, TIPS, Lang, fmt, langOf, reminderText, tipText } from "./tips_library";

/**
 * Exemples de notifications pour les administrateurs : un envoi par cas, avec le vrai format (titre, texte, image d'aperçu, `type_notif`), afin de
 * VOIR ce que les utilisateurs reçoivent et de vérifier que chaque clic ouvre la bonne page. Les titres commencent par « 🧪 TEST ».
 * Réservé aux administrateurs ; contourne le budget et les heures calmes (c'est un essai), n'écrit rien dans la liste des notifications.
 */
const ADMIN_ROLES = ["ADM", "admin", "ADMIN", "super_admin"];
const PAUSE_MS = 1200;

interface Sample { id: string; group: "rappels" | "pedagogiques" | "activite"; label: string; title: string; message: string; image?: string; data: Record<string, string> }

interface Ctx { post?: { id: string; type: string; image: string; text: string }; chronique?: { id: string; image: string }; sound?: { id: string; image: string }; lang: Lang; adminId: string; rate: number }

async function loadContext(adminId: string): Promise<Ctx> {
  const ctx: Ctx = { lang: "fr", adminId, rate: 1 };
  try {
    ctx.lang = langOf((await db.collection("Users").doc(adminId).get()).data()?.["appLang"]);
    const rate = (await db.collection("config").doc("monetization").get()).data()?.["baseViewRate"];
    if (typeof rate === "number" && rate > 0) ctx.rate = rate;
    // un post récent avec un aperçu d'image : sert aux exemples « j'aime », « commentaire », « nouveau post », « nouveau créateur », « pub »
    const posts = await db.collection("Posts").orderBy("created_at", "desc").limit(30).get();
    for (const d of posts.docs) {
      const x = d.data();
      const image = previewFromPost(x);
      if (image && String(x["type"] ?? "") === "POST") {
        ctx.post = { id: d.id, type: String(x["dataType"] ?? ""), image, text: String(x["description"] ?? "").replace(/\s+/g, " ").trim() };
        break;
      }
    }
    const chroniques = await db.collection("chroniques").orderBy("expiresAt", "desc").limit(15).get();
    for (const d of chroniques.docs) {
      const image = previewFromChronique(d.data());
      if (image) { ctx.chronique = { id: d.id, image }; break; }
    }
    const sounds = await db.collection("artist_sounds").where("status", "==", "validated").limit(15).get();
    for (const d of sounds.docs) {
      const image = previewFromSound(d.data());
      if (image) { ctx.sound = { id: d.id, image }; break; }
    }
  } catch (e) {
    console.warn("[samples] contexte incomplet", e);
  }
  return ctx;
}

export function buildSamples(c: Ctx): Sample[] {
  const out: Sample[] = [];
  const T = "🧪 TEST · ";
  const noData = { post_id: "", post_type: "", chat_id: "", send_user_id: "" };
  const post = c.post;

  // 1. Rappels programmés (déclencheur toutes les 30 minutes, créneaux 8 h 30 / 13 h / 19 h 30)
  const kinds: Array<[ReminderKind, string]> = [["quiz", "Rappel : quiz"], ["etude", "Rappel : étude"], ["conte", "Rappel : conte"], ["feed", "Rappel : nouveaux posts des abonnements"], ["comeback", "Rappel : retour (inactif depuis 7 jours)"]];
  for (const [kind, label] of kinds) {
    const t = reminderText(kind, c.lang, 0, 4);
    out.push({ id: "rappel_" + kind, group: "rappels", label, title: T + t.title, message: t.body, data: { type_notif: typeNotifFor(kind), ...noData } });
  }
  out.push({
    id: "rappel_createur", group: "rappels", label: "Promotion d'un nouveau créateur (moins de 60 jours)",
    title: `${T}🌟 ${NEW_CREATOR_LABEL[c.lang]} · @exemple`, message: post?.text ? post.text.slice(0, 100) : NEW_CREATOR_BODY[c.lang], image: post?.image,
    data: { type_notif: typeNotifFor("creator"), post_id: post?.id ?? "", post_type: post?.type ?? "", chat_id: "", send_user_id: "" },
  });
  out.push({
    id: "rappel_pub", group: "rappels", label: "Pub Afrolook sponsorisée",
    title: `${T}📢 ${AD_LABEL[c.lang]} · Offre exemple`, message: post?.text ? post.text.slice(0, 110) : "Texte de la pub Afrolook", image: post?.image,
    data: { type_notif: typeNotifFor("sponsor"), post_id: post?.id ?? "", post_type: post?.type ?? "", chat_id: "", send_user_id: "", ad_id: "exemple" },
  });

  // 2. Notifications pédagogiques (monétisation, parrainage, lives, réseaux, nouveautés…), dans la langue de l'administrateur
  const vars = { views: fmt(1000), amount: fmt(c.rate * 1000), min: fmt(1000) };
  for (const tip of TIPS) {
    const t = tipText(tip, c.lang, vars);
    out.push({ id: "tip_" + tip.topic, group: "pedagogiques", label: "Pédagogique : " + tip.topic, title: T + t.title, message: t.body, data: { type_notif: tip.target, ...noData } });
  }

  // 3. Activité et événements (format réel envoyé par l'application et le serveur)
  const withPost = { post_id: post?.id ?? "", post_type: post?.type ?? "", chat_id: "", send_user_id: c.adminId };
  out.push({ id: "act_like", group: "activite", label: "Quelqu'un a aimé votre post (aperçu du post)", title: T + "@Aïcha", message: "a aimé votre post", image: post?.image, data: { type_notif: "POST", ...withPost } });
  out.push({ id: "act_commentaire", group: "activite", label: "Commentaire sur votre post (aperçu du post)", title: T + "@Koffi", message: "a commenté : « Bravo, magnifique ! »", image: post?.image, data: { type_notif: "POST", ...withPost } });
  out.push({ id: "act_post_abonne", group: "activite", label: "Nouveau post d'un créateur suivi (aperçu du post)", title: T + "@Mariam", message: post?.text ? `a posté : ${post.text.slice(0, 100)}` : "a posté un nouveau contenu", image: post?.image, data: { type_notif: "POST", ...withPost } });
  out.push({ id: "act_chronique", group: "activite", label: "Nouvelle chronique (aperçu de la chronique)", title: T + "@Yao", message: "a publié une chronique", image: c.chronique?.image, data: { type_notif: "CHRONIQUE", post_id: c.chronique?.id ?? "", post_type: "CHRONIQUE", chat_id: "", send_user_id: c.adminId } });
  out.push({ id: "act_message", group: "activite", label: "Message (texte seul, toujours envoyé)", title: T + "@Fatou", message: "Salut, tu es disponible ?", data: { type_notif: "MESSAGE", post_id: "", post_type: "", chat_id: "exemple", send_user_id: c.adminId } });
  out.push({ id: "act_invitation", group: "activite", label: "Invitation (ouvre la page des invitations)", title: T + "@Ibrahim", message: "vous a envoyé une invitation", data: { type_notif: "INVITATION", ...noData } });
  out.push({ id: "act_abonne", group: "activite", label: "Nouvel abonné (ouvre son profil)", title: T + "@Nadia", message: "s'est abonné(e) à vous", data: { type_notif: "ABONNER", post_id: "", post_type: "", chat_id: "", send_user_id: c.adminId } });
  out.push({ id: "act_musique", group: "activite", label: "Nouvelle musique d'un artiste suivi (pochette)", title: T + "🎵 @Artiste a sorti un nouveau titre", message: "« Titre exemple » est disponible : écoute-le maintenant.", image: c.sound?.image, data: { type_notif: "MUSIC", sound_id: c.sound?.id ?? "", ...noData } });
  out.push({ id: "act_gain", group: "activite", label: "Gain reçu (ouvre la page Monétisation)", title: T + "Vous avez reçu un cadeau", message: "@Aïcha vous a offert 10 pièces", data: { type_notif: "GAIN", ...noData } });
  out.push({ id: "act_hebdo", group: "activite", label: "Récompense hebdomadaire (ouvre la page Monétisation)", title: T + "🏆 Récompense de la semaine", message: "Vous êtes dans le top des commentateurs : 300 pièces !", data: { type_notif: "WEEKLY_REWARD", ...noData } });
  out.push({ id: "act_live", group: "activite", label: "Un live démarre (ouvre la liste des lives)", title: T + "🔴 @Studio est en direct", message: "Rejoins le live maintenant", data: { type_notif: "LIVE", ...noData } });
  out.push({ id: "act_officiel", group: "activite", label: "Message du compte officiel (ouvre les notifications)", title: T + "Afrolook", message: "Votre musique a été acceptée", data: { type_notif: "COMPTE_OFFICIEL", ...noData } });
  return out;
}

export const sendNotificationSamples = onCall({ region: "us-central1", timeoutSeconds: 300, memory: "512MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Connexion requise");
  const role = String((await db.collection("Users").doc(uid).get()).data()?.["role"] ?? "");
  if (!ADMIN_ROLES.includes(role)) throw new HttpsError("permission-denied", "Réservé aux administrateurs");

  const d = (request.data ?? {}) as Record<string, unknown>;
  const samples = buildSamples(await loadContext(uid));
  if (d["list"] === true) return { cases: samples.map((s) => ({ id: s.id, group: s.group, label: s.label, hasImage: !!s.image })) };

  // cas demandés : « all », un groupe (rappels / pedagogiques / activite) ou une liste d'identifiants
  const wanted = Array.isArray(d["cases"]) ? (d["cases"] as unknown[]).map(String) : [String(d["cases"] ?? "all")];
  const chosen = samples.filter((s) => wanted.includes("all") || wanted.includes(s.id) || wanted.includes(s.group));
  if (!chosen.length) throw new HttpsError("invalid-argument", "Aucun cas à envoyer");
  const toMe = d["target"] === "me";
  const targets = toMe ? [{ userId: uid }] : (await adminDocs()).map((a) => ({ userId: a.id }));
  if (!targets.length) throw new HttpsError("failed-precondition", "Aucun administrateur trouvé");

  const results: Array<{ id: string; fcm: number; oneSignal: number }> = [];
  for (const s of chosen) {
    const r = await deliverPush(targets, { title: s.title, message: s.message, image: s.image, data: s.data }, undefined, false, "direct");
    results.push({ id: s.id, fcm: r.fcm, oneSignal: r.oneSignal });
    if (chosen.length > 1) await new Promise((resolve) => setTimeout(resolve, PAUSE_MS));
  }
  return { sent: results.length, recipients: targets.length, results };
});
