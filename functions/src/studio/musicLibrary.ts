import { randomBytes } from "crypto";
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
      id: tb.id, user_id: uid, type: "DEPENSE", statut: "VALIDER", description: `Achat du titre « ${title} » — ${price} pièces`,
      montant: price, frais: 0, montant_total: price, methode_paiement: "pieces", createdAt: now, updatedAt: now,
      purchaseKind: "musique_achat", purchaseRefId: soundId,
    });
    if (artistCoins > 0) {
      tx.update(artistRef, { giftCoinsBalance: FieldValue.increment(artistCoins), totalCoinsEarnedFromSales: FieldValue.increment(artistCoins), updatedAt: now });
      const ta = db.collection("TransactionSoldes").doc();
      tx.set(ta, {
        id: ta.id, user_id: artistId, type: "GAIN_PIECES", statut: "VALIDER", description: `Vente de ton titre « ${title} » — ${artistCoins} pièces reçues`,
        montant: artistCoins, frais: 0, montant_total: artistCoins, methode_paiement: "pieces", createdAt: now, updatedAt: now,
        purchaseKind: "musique_achat", purchaseRefId: soundId, payerId: uid,
      });
    }
    recordAppCommission(tx, "contenus", price - artistCoins, now);
    tx.set(libRef, {
      uid, soundId, artistId, title, coverImageUrl: sound.get("coverImageUrl") ?? null, genre: sound.get("genre") ?? null,
      price, artistCoins, percent: ARTIST_PERCENT, createdAt: now,
    });
    tx.update(soundRef, { saleCount: FieldValue.increment(1), totalEarningsCoins: FieldValue.increment(artistCoins), saleEarnings: FieldValue.increment(artistCoins) });
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
  // Titre payant non acheté : une écoute complète est possible une fois après une pub regardée (musicAdListen)
  let adGrant: FirebaseFirestore.DocumentReference | null = null;
  if (!own && !free && !lib.exists) {
    const g = await db.collection("MusicAdListens").doc(`${uid}_${soundId}`).get();
    if (!g.exists || g.get("used") === true || Date.now() - num(g.get("grantedAt")) > AD_GRANT_MS) throw new HttpsError("permission-denied", "ACHAT_REQUIS");
    adGrant = g.ref;
  }
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
  if (adGrant) await adGrant.update({ used: true, usedAt: Date.now() });
  return { url, expiresInSec: 600, viaAd: adGrant != null };
});

/**
 * Écoute complète d'un titre payant contre une pub récompensée, une seule fois par titre et par jour.
 * La pub vue est comptée par le serveur (réserve `AdRewards`, la même que la page Récompenses et les Contes) ;
 * 5 écoutes de ce type au maximum par jour. Le titre n'est ni acheté, ni téléchargeable : seule l'écoute en ligne est ouverte.
 */
const AD_LISTENS_PER_DAY = 5;
const AD_GRANT_MS = 30 * 60 * 1000;
const dayCompact = () => new Date().toISOString().slice(0, 10).replace(/-/g, "");

export const musicAdListen = onCall({ timeoutSeconds: 20, memory: "256MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const soundId = (request.data as { soundId?: unknown })?.soundId;
  if (!okId(soundId)) throw new HttpsError("invalid-argument", "Titre invalide.");

  const soundRef = db.collection("artist_sounds").doc(soundId);
  const libRef = db.collection("MusicLibrary").doc(`${uid}_${soundId}`);
  const grantRef = db.collection("MusicAdListens").doc(`${uid}_${soundId}`);
  const poolRef = db.collection("AdRewards").doc(`${uid}_${dayCompact()}`);
  const limRef = db.collection("MusicStreamLimits").doc(`${uid}_adlisten_${day()}`);

  return db.runTransaction(async (tx) => {
    const [sound, lib, grant, pool, lim] = await Promise.all([tx.get(soundRef), tx.get(libRef), tx.get(grantRef), tx.get(poolRef), tx.get(limRef)]);
    if (!sound.exists || sound.get("status") !== "validated") throw new HttpsError("failed-precondition", "RETIRE");
    if (sound.get("pricing") === "free" || sound.get("userId") === uid || lib.exists) return { ok: true, already: true };
    const now = Date.now();
    // Une écoute déjà accordée et pas encore utilisée : pas de deuxième pub consommée
    if (grant.exists && grant.get("used") !== true && now - num(grant.get("grantedAt")) <= AD_GRANT_MS) return { ok: true, already: true };
    const n = num(lim.get("n"));
    if (n >= AD_LISTENS_PER_DAY) throw new HttpsError("resource-exhausted", "LIMITE_JOUR");
    const pending = num(pool.get("pending"));
    if (pending < 1) throw new HttpsError("failed-precondition", "NO_ADS");
    tx.set(poolRef, { pending: pending - 1 }, { merge: true });
    tx.set(limRef, { uid, n: n + 1, day: day(), updatedAt: now }, { merge: true });
    tx.set(grantRef, { uid, soundId, grantedAt: now, used: false });
    tx.set(db.collection("AdRewardStats").doc(dayCompact()), { day: dayCompact(), adsSpent: FieldValue.increment(1), musicAdListens: FieldValue.increment(1) }, { merge: true });
    return { ok: true };
  });
});

/**
 * Revenus estimés des pubs de la page Musique (bannière, pub dans les listes) : l'application envoie les événements « paid »
 * d'AdMob, regroupés. Indicatif seulement (un téléphone modifié pourrait tricher) ; le revenu officiel est dans la console AdMob,
 * emplacement par emplacement.
 */
export const musicAdPaid = onCall({ timeoutSeconds: 15, memory: "256MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const events = Array.isArray((request.data as { events?: unknown })?.events) ? ((request.data as { events: unknown[] }).events as Record<string, unknown>[]) : [];
  const clean = events.slice(0, 50).filter((e) => (e.p === "banner" || e.p === "native") && /^[A-Z]{3}$/.test(String(e.c)) && Number.isFinite(Number(e.v)) && Number(e.v) >= 0 && Number(e.v) < 5e7);
  if (!clean.length) return { ok: true, n: 0 };
  const limRef = db.collection("MusicStreamLimits").doc(`${uid}_ads_${day()}`);
  const stat = db.collection("MusicAdStats").doc(dayCompact());
  await db.runTransaction(async (tx) => {
    const l = await tx.get(limRef);
    const n = num(l.get("n"));
    if (n >= 300) return;
    tx.set(limRef, { uid, n: n + clean.length, day: day(), updatedAt: Date.now() }, { merge: true });
    // FieldValue.increment répété sur une même clé : regroupé avant l'écriture
    const sum = new Map<string, number>();
    for (const e of clean) {
      sum.set(`impr_${e.p}`, (sum.get(`impr_${e.p}`) ?? 0) + 1);
      const k = `micros_${e.c}_${e.p}`;
      sum.set(k, (sum.get(k) ?? 0) + Math.round(Number(e.v)));
    }
    const grouped: Record<string, unknown> = { day: dayCompact() };
    for (const [k, v] of sum) grouped[k] = FieldValue.increment(v);
    tx.set(stat, grouped, { merge: true });
  });
  return { ok: true, n: clean.length };
});

/**
 * Licence de lecture hors ligne (« télécharger » façon YouTube) : le fichier n'est jamais remis tel quel à la personne, l'application le chiffre
 * dans son espace privé avec la clé de la licence. La licence est liée à la personne et à l'appareil, dure 30 jours, se renouvelle toute seule
 * quand l'appareil est en ligne, et disparaît si le titre est retiré, suspendu ou si la personne n'y a plus droit.
 * Limites : 3 appareils par personne et par titre, 20 téléchargements par jour, 30 jours de validité.
 */
const LICENSE_DAYS = 30;
const MAX_DEVICES = 3;
const DOWNLOADS_PER_DAY = 20;

export const musicLicense = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const d = (request.data ?? {}) as { soundId?: unknown; deviceId?: unknown; renew?: unknown };
  if (!okId(d.soundId)) throw new HttpsError("invalid-argument", "Titre invalide.");
  if (!okId(d.deviceId)) throw new HttpsError("invalid-argument", "Appareil invalide.");
  const soundId = d.soundId;
  const deviceId = d.deviceId;
  const renew = d.renew === true;

  const [sound, lib] = await Promise.all([db.collection("artist_sounds").doc(soundId).get(), db.collection("MusicLibrary").doc(`${uid}_${soundId}`).get()]);
  if (!sound.exists) throw new HttpsError("not-found", "Titre introuvable.");
  const own = sound.get("userId") === uid;
  if (!own && sound.get("status") !== "validated") throw new HttpsError("failed-precondition", "RETIRE");
  const free = sound.get("pricing") === "free";
  if (!own && !free && !lib.exists) throw new HttpsError("permission-denied", "ACHAT_REQUIS");
  const path = (sound.get("audioPath") as string | undefined) ?? storagePathFromUrl(String(sound.get("audioUrl") ?? ""));
  if (!path) throw new HttpsError("not-found", "Fichier introuvable.");

  const licRef = db.collection("MusicLicenses").doc(`${uid}_${soundId}_${deviceId}`);
  const limRef = db.collection("MusicStreamLimits").doc(`${uid}_dl_${day()}`);
  const now = Date.now();
  const expiresAt = now + LICENSE_DAYS * 24 * 3600 * 1000;

  const out = await db.runTransaction(async (tx) => {
    const lic = await tx.get(licRef);
    // Appareils déjà autorisés pour ce titre
    const others = await tx.get(db.collection("MusicLicenses").where("uid", "==", uid).where("soundId", "==", soundId));
    const active = others.docs.filter((x) => x.id !== licRef.id && x.get("revoked") !== true && num(x.get("expiresAt")) > now);
    if (!lic.exists && active.length >= MAX_DEVICES) throw new HttpsError("resource-exhausted", "APPAREILS", { max: MAX_DEVICES });

    // Un renouvellement ne consomme pas le quota de téléchargements ; un nouveau téléchargement oui
    const fresh = !renew || !lic.exists || lic.get("revoked") === true;
    if (fresh) {
      const l = await tx.get(limRef);
      const n = num(l.get("n"));
      if (n >= DOWNLOADS_PER_DAY) throw new HttpsError("resource-exhausted", "LIMITE_JOUR");
      tx.set(limRef, { uid, n: n + 1, day: day(), updatedAt: now }, { merge: true });
    }
    const key = fresh || !lic.get("key") ? randomBytes(32).toString("base64") : String(lic.get("key"));
    tx.set(licRef, { uid, soundId, deviceId, key, expiresAt, revoked: false, createdAt: lic.exists ? lic.get("createdAt") ?? now : now, renewedAt: now }, { merge: true });
    return { key };
  });

  const title = String(sound.get("title") ?? "Titre").slice(0, 60);
  const base = {
    key: out.key, expiresAt, title, artist: sound.get("userPseudo") ? String(sound.get("userPseudo")).slice(0, 40) : null, coverImageUrl: sound.get("coverImageUrl") ?? null,
  };
  // Un simple renouvellement ne renvoie pas le fichier
  if (renew) return base;
  const url = await tempListenUrl(path);
  return { ...base, url, expiresInSec: 600 };
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
