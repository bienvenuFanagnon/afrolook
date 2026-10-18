import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db } from "../shared/firebase";
import { chargeArtistSound, prepareArtistSound } from "../studio/artistSounds";

/**
 * Paiement de la musique d'une chronique, à la publication, une seule fois par chronique (ArtistSoundUses/{uid}_chr_{chroniqueId}).
 * Même barème et même partage que les montages : prix d'utilisation du son, 60 % pour l'artiste, gratuit pour ses propres sons et les sons gratuits.
 * Renvoie l'extrait public (30 s) à lire : jamais le fichier original.
 */
export const chroniqueMusicCharge = onCall({ timeoutSeconds: 30, memory: "256MiB", maxInstances: 20 }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Connecte-toi pour publier.");
  const d = (request.data ?? {}) as { soundId?: string; chroniqueId?: string };
  const chroniqueId = String(d.chroniqueId ?? "");
  if (!/^[A-Za-z0-9_-]{6,40}$/.test(chroniqueId)) throw new HttpsError("invalid-argument", "Chronique invalide.");
  const info = await prepareArtistSound(uid, String(d.soundId ?? ""));
  const sound = (await db.collection("artist_sounds").doc(info.id).get()).data() ?? {};
  const previewUrl = String(sound["previewUrl"] ?? "");
  if (!previewUrl) throw new HttpsError("failed-precondition", "Ce son n'est pas encore prêt.");
  const paid = await chargeArtistSound(uid, info, `chr_${chroniqueId}`);
  return { paid, title: info.title, artistId: info.artistId, artist: String(sound["userPseudo"] ?? ""), previewUrl, previewSec: Number(sound["previewSec"] ?? 30) };
});
