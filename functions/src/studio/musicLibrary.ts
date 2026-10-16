import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { db } from "../shared/firebase";
import { num, recordAppCommission } from "../payments/coinShares";
import { ARTIST_PERCENT, MAX_SALE, MIN_SALE, artistShare, storagePathFromUrl, tempListenUrl } from "./artistSounds";

/**
 * Bibliothèque musicale : achat d'un titre en pièces et écoute complète.
 *
 * - `musicBuy` : la personne paie le prix de vente (50 à 500 pièces, fixé par l'artiste) ; l'artiste reçoit 60 % en pièces
 *   gagnées (convertibles), Afrolook le reste. Une seule transaction, une seule fois par titre (MusicLibrary/{uid}_{soundId}).
 * - `musicStreamUrl` : lien d'écoute de l'original valable ~10 minutes (copie temporaire supprimée ensuite), délivré seulement si le titre est gratuit, acheté,
 *   ou à soi. Limité par jour pour éviter l'aspiration du catalogue. L'original n'est jamais lisible autrement.
 */
const STREAM_PER_DAY = 300;
const day = () => new Date().toISOString().slice(0, 10);
const okId = (id: unknown): id is string => typeof id === "string" && /^[A-Za-z0-9_-]{4,64}$/.test(id);

export const musicBuy = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const soundId = (request.data as { soundId?: unknown })?.soundId;
  if (!okId(soundId)) throw new HttpsError("invalid-argument", "Titre invalide.");

  const soundRef = db.collection("artist_sounds").doc(soundId);
  const libRef = db.collection("MusicLibrary").doc(`${uid}_${soundId}`);
  const buyerRef = db.collection("Users").doc(uid);

  return db.runTransaction(async (tx) => {
    const [sound, lib, buyer] = await Promise.all([tx.get(soundRef), tx.get(libRef), tx.get(buyerRef)]);
    if (!sound.exists || sound.get("status") !== "validated") throw new HttpsError("failed-precondition", "Ce titre n'est plus disponible.");
    const artistId = String(sound.get("userId") ?? "");
    if (artistId === uid) throw new HttpsError("failed-precondition", "C'est ton propre titre.");
    const price = Math.round(num(sound.get("saleCoins")));
    if (price < MIN_SALE || price > MAX_SALE) throw new HttpsError("failed-precondition", "Ce titre n'est pas en vente.");
    if (lib.exists) return { ok: true, already: true, price: 0 };
    if (!buyer.exists) throw new HttpsError("not-found", "Compte introuvable.");
    const balance = num(buyer.get("giftCoinsBalance"));
    if (balance < price) throw new HttpsError("resource-exhausted", "Solde de pièces insuffisant.", { coins: price, balance });

    const artistRef = db.collection("Users").doc(artistId);
    const artist = await tx.get(artistRef);
    const now = Date.now();
    const artistCoins = artist.exists ? artistShare(price) : 0;
    const title = String(sound.get("title") ?? "Titre").slice(0, 60);

    tx.update(buyerRef, { giftCoinsBalance: FieldValue.increment(-price), totalGiftCoinsSpent: FieldValue.increment(price), updatedAt: now });
    const tb = db.collection("TransactionSoldes").doc();
    tx.set(tb, {
      id: tb.id, user_id: uid, type: "DEPENSE", statut: "VALIDER", description: `Titre « ${title} » ajouté à ta bibliothèque — ${price} pièces`,
      montant: price, frais: 0, montant_total: price, methode_paiement: "pieces", createdAt: now, updatedAt: now,
      purchaseKind: "musique_achat", purchaseRefId: soundId,
    });
    if (artistCoins > 0) {
      tx.update(artistRef, { giftCoinsBalance: FieldValue.increment(artistCoins), totalCoinsEarnedFromSales: FieldValue.increment(artistCoins), updatedAt: now });
      const ta = db.collection("TransactionSoldes").doc();
      tx.set(ta, {
        id: ta.id, user_id: artistId, type: "GAIN_PIECES", statut: "VALIDER", description: `Ton titre « ${title} » a été acheté — ${artistCoins} pièces reçues`,
        montant: artistCoins, frais: 0, montant_total: artistCoins, methode_paiement: "pieces", createdAt: now, updatedAt: now,
        purchaseKind: "musique_achat", purchaseRefId: soundId, payerId: uid,
      });
    }
    recordAppCommission(tx, "contenus", price - artistCoins, now);
    tx.set(libRef, {
      uid, soundId, artistId, title, coverImageUrl: sound.get("coverImageUrl") ?? null, genre: sound.get("genre") ?? null,
      price, artistCoins, percent: ARTIST_PERCENT, createdAt: now,
    });
    tx.update(soundRef, { saleCount: FieldValue.increment(1), totalEarningsCoins: FieldValue.increment(artistCoins) });
    return { ok: true, price, artistCoins };
  });
});

export const musicStreamUrl = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const soundId = (request.data as { soundId?: unknown })?.soundId;
  if (!okId(soundId)) throw new HttpsError("invalid-argument", "Titre invalide.");

  const [sound, lib] = await Promise.all([db.collection("artist_sounds").doc(soundId).get(), db.collection("MusicLibrary").doc(`${uid}_${soundId}`).get()]);
  if (!sound.exists) throw new HttpsError("not-found", "Titre introuvable.");
  const own = sound.get("userId") === uid;
  if (!own && sound.get("status") !== "validated") throw new HttpsError("failed-precondition", "Ce titre n'est plus disponible.");
  const free = sound.get("pricing") === "free";
  if (!own && !free && !lib.exists) throw new HttpsError("permission-denied", "ACHAT_REQUIS");
  const path = (sound.get("audioPath") as string | undefined) ?? storagePathFromUrl(String(sound.get("audioUrl") ?? ""));
  if (!path) throw new HttpsError("not-found", "Fichier introuvable.");

  // Limite d'écoutes complètes par jour et par personne
  const limRef = db.collection("MusicStreamLimits").doc(`${uid}_${day()}`);
  await db.runTransaction(async (tx) => {
    const l = await tx.get(limRef);
    const n = num(l.get("n"));
    if (n >= STREAM_PER_DAY) throw new HttpsError("resource-exhausted", "Limite d'écoute du jour atteinte.");
    tx.set(limRef, { uid, n: n + 1, day: day(), updatedAt: Date.now() }, { merge: true });
  });

  const url = await tempListenUrl(path);
  return { url, expiresInSec: 600 };
});

/** Supprime les copies d'écoute de plus de 10 minutes (le nom du fichier commence par l'heure de création). */
export const cleanupTempListen = onSchedule(
  { schedule: "every 10 minutes", region: "us-central1", timeZone: "UTC", timeoutSeconds: 120, memory: "256MiB" },
  async () => {
    const limit = Date.now() - 10 * 60 * 1000;
    const [files] = await getStorage().bucket().getFiles({ prefix: "artist_sound_tmp/", maxResults: 1000 });
    for (const f of files) {
      const t = Number(f.name.split("/")[1]?.split("_")[0]);
      if (!Number.isFinite(t) || t < limit) await f.delete({ ignoreNotFound: true }).catch(() => undefined);
    }
  },
);
