import { db } from "./firebase";

/**
 * Image d'APERÇU d'un contenu pour les notifications : une notification qui parle d'un contenu visuel montre ce contenu
 * (photo, miniature de vidéo, pochette de musique, média de chronique) pour qu'on sache tout de suite de quoi il s'agit.
 * Un contenu sans aperçu (texte, message, rappel) reste en texte seul : on retourne alors une chaîne vide.
 */

const https = (v: unknown): string => {
  const s = String(v ?? "").trim();
  return /^https:\/\/\S{6,1500}$/.test(s) ? s : "";
};

/** Hébergeurs d'images de l'application (Firebase Storage, CDN Afrolook) : seules leurs adresses peuvent servir d'aperçu à un message de chat. */
const CHAT_IMAGE_HOSTS = ["firebasestorage.googleapis.com", "storage.googleapis.com", "cdn.afrolookmedia.com"];

/** Photo envoyée dans un chat : adresse https d'un de nos hébergeurs, sinon vide (jamais l'adresse d'un site tiers). */
export function safeChatImage(url: unknown): string {
  const s = https(url);
  if (!s) return "";
  try {
    return CHAT_IMAGE_HOSTS.includes(new URL(s).hostname) ? s : "";
  } catch {
    return "";
  }
}

/** Post : photo pour une image, miniature pour une vidéo, sinon aperçu éventuel ; vide pour un post texte. */
export function previewFromPost(p: Record<string, unknown> | undefined): string {
  if (!p) return "";
  const dataType = String(p["dataType"] ?? "").toUpperCase();
  const images = Array.isArray(p["images"]) ? (p["images"] as unknown[]) : [];
  if (dataType === "VIDEO") return https(p["thumbnail"]) || https(images[0]);
  if (dataType === "IMAGE") return https(images[0]) || https(p["url_media"]) || https(p["thumbnail"]);
  return https(images[0]) || https(p["thumbnail"]);
}

/** Chronique : affiche, sinon média d'une chronique image, sinon pochette (vidéo, musique) ; vide pour une chronique texte. */
export function previewFromChronique(c: Record<string, unknown> | undefined): string {
  if (!c) return "";
  const type = String(c["type"] ?? "").toUpperCase();
  return https(c["posterUrl"]) || (type.endsWith("IMAGE") ? https(c["mediaUrl"]) : https(c["coverImageUrl"]));
}

/** Musique : pochette. */
export function previewFromSound(s: Record<string, unknown> | undefined): string {
  return s ? https(s["coverImageUrl"]) : "";
}

/** Aperçu du post (ou de la chronique si `postType` vaut CHRONIQUE) : une lecture. Retourne "" si introuvable ou sans aperçu. */
export async function previewForContent(id: unknown, postType?: unknown): Promise<string> {
  const docId = String(id ?? "").trim();
  if (!/^[A-Za-z0-9_-]{6,64}$/.test(docId)) return "";
  try {
    if (String(postType ?? "").toUpperCase() === "CHRONIQUE") {
      return previewFromChronique((await db.collection("chroniques").doc(docId).get()).data());
    }
    return previewFromPost((await db.collection("Posts").doc(docId).get()).data());
  } catch (e) {
    console.warn("[preview] aperçu illisible", docId, e);
    return "";
  }
}
