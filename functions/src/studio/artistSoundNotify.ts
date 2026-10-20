import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { notifyAdminsAll, notifyUser, esc } from "../shared/user_notify";
import { APP_WEB_URL_AFRO } from "../shared/config";

/**
 * Sons d'artistes (musiques proposées par les utilisateurs) : messages automatiques.
 * - Un son est soumis → les administrateurs reçoivent une notification (application + push) et un e-mail.
 * - Le statut du son change (accepté, refusé, suspendu, rétabli) → l'artiste reçoit une notification (application + push) et un e-mail.
 * Statuts : pending_review → validated | refused ; validated → suspended (signalements ou administrateur) → validated.
 * Un refus automatique (fichier déjà existant, fichier illisible) prévient aussi l'artiste : le motif est dans `refusalReason`.
 */
const cut = (s: unknown, n: number) => String(s ?? "").trim().slice(0, n);

export const notifyAdminsOnNewSound = onDocumentCreated(
  { document: "artist_sounds/{id}", timeoutSeconds: 60, memory: "256MiB", maxInstances: 5 },
  async (event) => {
    const s = event.data?.data();
    if (!s) return;
    const title = cut(s["title"], 80) || "Sans titre";
    const artist = cut(s["userPseudo"], 60) || "Un utilisateur";
    await notifyAdminsAll({
      title: "🎵 Nouvelle musique à valider",
      message: `@${artist} propose « ${title} ». Ouvre « Sons artistes » dans le tableau de bord admin pour l'écouter et la traiter.`,
      target: "ADMIN_SOUNDS",
      refId: event.params.id,
      email: {
        subject: `🎵 Nouvelle musique à valider : « ${title} »`,
        heading: "Nouvelle musique à valider",
        icon: "🎵",
        tone: "info",
        intro: `<b>@${esc(artist)}</b> vient de proposer une musique sur Afrolook. Elle attend votre décision : accepter, refuser (avec un motif) ou la laisser en attente.`,
        rows: [
          ["Titre", title],
          ["Artiste", `@${artist}`],
          ["Genre", cut(s["genre"], 40)],
          ["Prix de vente", s["saleCoins"] ? `${s["saleCoins"]} pièces` : "Gratuit"],
          ["Reçue le", new Date().toLocaleString("fr-FR", { timeZone: "Africa/Porto-Novo" })],
        ],
        outro: "Dans l'application : tableau de bord administrateur › Sons artistes. L'analyse automatique (doublons, extrait public) se termine en quelques instants.",
        button: { label: "Ouvrir Afrolook", url: APP_WEB_URL_AFRO },
      },
    });
  },
);

export const notifyArtistOnSoundStatus = onDocumentUpdated(
  { document: "artist_sounds/{id}", timeoutSeconds: 60, memory: "256MiB", maxInstances: 5 },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    const from = String(before["status"] ?? ""), to = String(after["status"] ?? "");
    if (from === to || !["validated", "refused", "suspended"].includes(to)) return;
    const userId = String(after["userId"] ?? "");
    if (!userId) return;
    const title = cut(after["title"], 80) || "ta musique";
    const reason = cut(after["refusalReason"], 300);
    const app = { label: "Ouvrir Afrolook", url: APP_WEB_URL_AFRO };

    if (to === "validated") {
      const back = from === "suspended";
      await notifyUser({
        userId, target: "MY_SOUND", refId: event.params.id,
        title: back ? "✅ Ta musique est de nouveau en ligne" : "🎉 Ta musique est acceptée !",
        message: back ? `« ${title} » est de nouveau disponible dans Afrolook.` : `« ${title} » est validée : elle est maintenant disponible dans Afrolook (écoute, achat et utilisation dans des posts).`,
        email: {
          subject: back ? `✅ « ${title} » est de nouveau en ligne` : `🎉 Ta musique « ${title} » est acceptée`,
          heading: back ? "Ta musique est de nouveau en ligne" : "Ta musique est acceptée !",
          icon: back ? "✅" : "🎉", tone: "ok",
          intro: back
            ? `Après vérification, <b>« ${esc(title)} »</b> est de nouveau disponible dans Afrolook.`
            : `Bonne nouvelle : <b>« ${esc(title)} »</b> a été validée par l'équipe Afrolook. Elle est maintenant disponible : les utilisateurs peuvent l'écouter, l'acheter et l'utiliser dans leurs posts.`,
          rows: [["Titre", title], ["Statut", "En ligne"]],
          outro: "Tu retrouves tes écoutes, tes ventes et tes gains dans ton Espace artiste (page Musique). Merci de faire vivre la musique sur Afrolook !",
          button: app,
        },
      });
    } else if (to === "refused") {
      await notifyUser({
        userId, target: "MY_SOUND", refId: event.params.id,
        title: "Ta musique n'a pas été acceptée",
        message: `« ${title} » a été refusée${reason ? ` : ${reason}` : "."}`,
        email: {
          subject: `Ta musique « ${title} » n'a pas été acceptée`,
          heading: "Ta musique n'a pas été acceptée", icon: "🚫", tone: "no",
          intro: `Après examen, <b>« ${esc(title)} »</b> n'a pas pu être mise en ligne sur Afrolook.`,
          rows: [["Titre", title], ["Motif", reason || "Non conforme"]],
          outro: "Tu peux corriger et proposer une nouvelle version, ou une autre musique, à tout moment depuis ton Espace artiste (page Musique). Si tu penses à une erreur, réponds simplement à cet e-mail.",
          button: app,
        },
      });
    } else {
      await notifyUser({
        userId, target: "MY_SOUND", refId: event.params.id,
        title: "⏸️ Ta musique est suspendue",
        message: `« ${title} » est retirée le temps d'une vérification par l'équipe.`,
        email: {
          subject: `⏸️ Ta musique « ${title} » est suspendue`,
          heading: "Ta musique est suspendue", icon: "⏸️", tone: "info",
          intro: `<b>« ${esc(title)} »</b> est temporairement retirée d'Afrolook : elle a été signalée ou est en cours de vérification par l'équipe.`,
          rows: [["Titre", title], ["Statut", "Suspendue"]],
          outro: "Tu seras prévenu(e) dès que la vérification sera terminée. Tes ventes et tes gains déjà enregistrés ne sont pas touchés.",
          button: app,
        },
      });
    }
  },
);
