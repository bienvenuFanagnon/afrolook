import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { num, recordAppCommission } from "../payments/coinShares";
import { artistShare } from "./artistSounds";

/**
 * Playlists de la bibliothèque musicale.
 *
 * - `playlistSave` : crée ou modifie une playlist (nom, accès gratuit ou payant, prix 20 à 500 pièces, jusqu'à 100 titres).
 *   Tout le monde voit la playlist et son contenu ; l'accès (ajout à la bibliothèque) est gratuit ou payant selon le créateur.
 *   Les titres payants d'artistes sont permis mais signalés (paidCount) : acheter la playlist ne donne PAS accès au titre complet
 *   des titres payants, il faut les acheter un par un, sinon seul l'extrait est lu.
 * - `playlistAdd` : ajoute la playlist à la bibliothèque ; si elle est payante, le créateur reçoit 60 % en pièces gagnées.
 * - `playlistDelete` : le créateur retire sa playlist (celles déjà achetées restent lisibles pour les acheteurs).
 * - `musicStream` : compte une écoute (30 s) sur un titre d'artiste, comme les « streams » d'une plateforme de musique.
 */
export const PLAYLIST_MIN = 20;
export const PLAYLIST_MAX = 500;
export const PLAYLIST_MAX_TRACKS = 100;
const MAX_PER_USER = 30;
const STREAM_GAP_MS = 10 * 60 * 1000;
const STREAM_PER_DAY = 600;

/** Musiques gratuites d'Afrolook (Storage studio_music/{id}.m4a) : identifiants valides dans une playlist. */
export const STUDIO_TRACK_IDS = new Set(["love_afro", "piano_triste", "afrobeat", "amapiano", "coupe_decale", "highlife", "afro_trap", "workout", "fanfare", "noel", "zen_kalimba", "kora_calme", "plage", "nuit", "berceuse", "oud", "tension"]);

const okId = (id: unknown): id is string => typeof id === "string" && /^[A-Za-z0-9_-]{4,64}$/.test(id);
const day = () => new Date().toISOString().slice(0, 10);
const clean = (v: unknown, max: number) => String(v ?? "").replace(/\s+/g, " ").trim().slice(0, max);

/** « a:{idSon} » pour un son d'artiste, « f:{id} » pour une musique gratuite d'Afrolook. */
export function parseTrackRef(ref: unknown): { k: "a" | "f"; id: string } | null {
  if (typeof ref !== "string") return null;
  const m = /^([af]):([A-Za-z0-9_-]{2,64})$/.exec(ref);
  if (!m) return null;
  const k = m[1] as "a" | "f";
  if (k === "f" && !STUDIO_TRACK_IDS.has(m[2])) return null;
  if (k === "a" && !okId(m[2])) return null;
  return { k, id: m[2] };
}

export const playlistSave = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const d = (request.data ?? {}) as Record<string, unknown>;

  const title = clean(d.title, 60);
  if (title.length < 2) throw new HttpsError("invalid-argument", "Donne un nom à ta playlist (2 caractères au moins).");
  const description = clean(d.description, 300);
  const access = d.access === "paid" ? "paid" : "free";
  let price = 0;
  if (access === "paid") {
    price = Math.round(num(d.priceCoins));
    if (price < PLAYLIST_MIN || price > PLAYLIST_MAX) throw new HttpsError("invalid-argument", `Le prix d'une playlist va de ${PLAYLIST_MIN} à ${PLAYLIST_MAX} pièces.`);
  }

  const refs = Array.isArray(d.trackIds) ? (d.trackIds as unknown[]) : [];
  const seen = new Set<string>();
  const tracks: { k: "a" | "f"; id: string }[] = [];
  for (const r of refs) {
    const p = parseTrackRef(r);
    if (!p) throw new HttpsError("invalid-argument", "Un titre de la playlist n'est pas valide.");
    const key = `${p.k}:${p.id}`;
    if (seen.has(key)) continue;
    seen.add(key);
    tracks.push(p);
  }
  if (tracks.length < 1) throw new HttpsError("invalid-argument", "Ajoute au moins un titre à ta playlist.");
  if (tracks.length > PLAYLIST_MAX_TRACKS) throw new HttpsError("invalid-argument", `Une playlist contient ${PLAYLIST_MAX_TRACKS} titres au plus.`);

  // Les titres d'artistes doivent exister et être validés ; on compte ceux qui sont payants
  const soundIds = tracks.filter((t) => t.k === "a").map((t) => t.id);
  const docs = await Promise.all(soundIds.map((id) => db.collection("artist_sounds").doc(id).get()));
  let paidCount = 0;
  let coverUrl: string | null = null;
  for (const s of docs) {
    if (!s.exists || s.get("status") !== "validated") throw new HttpsError("failed-precondition", "Un des titres n'est plus disponible : retire-le de la playlist.");
    if (s.get("pricing") !== "free") paidCount++;
    if (!coverUrl && typeof s.get("coverImageUrl") === "string") coverUrl = s.get("coverImageUrl") as string;
  }

  const now = Date.now();
  const user = await db.collection("Users").doc(uid).get();
  if (!user.exists) throw new HttpsError("not-found", "Compte introuvable.");
  const ownerPseudo = clean(user.get("pseudo"), 40);

  const playlistId = d.playlistId;
  const body = {
    title, description, access, priceCoins: price, trackIds: tracks.map((t) => `${t.k}:${t.id}`), trackCount: tracks.length,
    paidCount, coverUrl, ownerPseudo, updatedAt: now,
  };
  if (playlistId !== undefined && playlistId !== null && playlistId !== "") {
    if (!okId(playlistId)) throw new HttpsError("invalid-argument", "Playlist invalide.");
    const ref = db.collection("MusicPlaylists").doc(playlistId);
    const snap = await ref.get();
    if (!snap.exists || snap.get("ownerId") !== uid || snap.get("status") === "deleted") throw new HttpsError("permission-denied", "Cette playlist n'est pas la tienne.");
    await ref.update(body);
    return { ok: true, id: playlistId, paidCount };
  }
  const mine = await db.collection("MusicPlaylists").where("ownerId", "==", uid).where("status", "==", "active").count().get();
  if (mine.data().count >= MAX_PER_USER) throw new HttpsError("resource-exhausted", `Tu peux créer ${MAX_PER_USER} playlists au plus.`);
  const ref = db.collection("MusicPlaylists").doc();
  await ref.set({ id: ref.id, ownerId: uid, status: "active", addCount: 0, earnedCoins: 0, streamCount: 0, createdAt: now, ...body });
  return { ok: true, id: ref.id, paidCount };
});

export const playlistDelete = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const id = (request.data as { playlistId?: unknown })?.playlistId;
  if (!okId(id)) throw new HttpsError("invalid-argument", "Playlist invalide.");
  const ref = db.collection("MusicPlaylists").doc(id);
  const snap = await ref.get();
  if (!snap.exists || snap.get("ownerId") !== uid) throw new HttpsError("permission-denied", "Cette playlist n'est pas la tienne.");
  // Retirée du catalogue ; les personnes qui l'ont déjà dans leur bibliothèque (payée ou non) la gardent.
  await ref.update({ status: "deleted", updatedAt: Date.now() });
  return { ok: true };
});

export const playlistAdd = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const id = (request.data as { playlistId?: unknown })?.playlistId;
  if (!okId(id)) throw new HttpsError("invalid-argument", "Playlist invalide.");

  const plRef = db.collection("MusicPlaylists").doc(id);
  const libRef = db.collection("MusicPlaylistLibrary").doc(`${uid}_${id}`);
  const buyerRef = db.collection("Users").doc(uid);

  return db.runTransaction(async (tx) => {
    const [pl, lib] = await Promise.all([tx.get(plRef), tx.get(libRef)]);
    if (!pl.exists || pl.get("status") !== "active") throw new HttpsError("failed-precondition", "Cette playlist n'est plus disponible.");
    const ownerId = String(pl.get("ownerId") ?? "");
    const title = clean(pl.get("title"), 60);
    const paidCount = num(pl.get("paidCount"));
    if (ownerId === uid) throw new HttpsError("failed-precondition", "C'est ta propre playlist.");
    if (lib.exists) return { ok: true, already: true, price: 0, paidCount };

    const price = pl.get("access") === "paid" ? Math.round(num(pl.get("priceCoins"))) : 0;
    const now = Date.now();
    let ownerCoins = 0;
    if (price > 0) {
      if (price < PLAYLIST_MIN || price > PLAYLIST_MAX) throw new HttpsError("failed-precondition", "Le prix de cette playlist n'est pas valide.");
      const [buyer, owner] = await Promise.all([tx.get(buyerRef), tx.get(db.collection("Users").doc(ownerId))]);
      if (!buyer.exists) throw new HttpsError("not-found", "Compte introuvable.");
      const balance = num(buyer.get("giftCoinsBalance"));
      if (balance < price) throw new HttpsError("resource-exhausted", "Solde de pièces insuffisant.", { coins: price, balance });
      ownerCoins = owner.exists ? artistShare(price) : 0;
      tx.update(buyerRef, { giftCoinsBalance: FieldValue.increment(-price), totalGiftCoinsSpent: FieldValue.increment(price), updatedAt: now });
      const tb = db.collection("TransactionSoldes").doc();
      tx.set(tb, {
        id: tb.id, user_id: uid, type: "DEPENSE", statut: "VALIDER", description: `Achat de la playlist « ${title} » — ${price} pièces`,
        montant: price, frais: 0, montant_total: price, methode_paiement: "pieces", createdAt: now, updatedAt: now,
        purchaseKind: "playlist_achat", purchaseRefId: id,
      });
      if (ownerCoins > 0) {
        tx.update(db.collection("Users").doc(ownerId), { giftCoinsBalance: FieldValue.increment(ownerCoins), totalCoinsEarnedFromSales: FieldValue.increment(ownerCoins), updatedAt: now });
        const ta = db.collection("TransactionSoldes").doc();
        tx.set(ta, {
          id: ta.id, user_id: ownerId, type: "GAIN_PIECES", statut: "VALIDER", description: `Vente de ta playlist « ${title} » — ${ownerCoins} pièces reçues`,
          montant: ownerCoins, frais: 0, montant_total: ownerCoins, methode_paiement: "pieces", createdAt: now, updatedAt: now,
          purchaseKind: "playlist_achat", purchaseRefId: id, payerId: uid,
        });
      }
      recordAppCommission(tx, "contenus", price - ownerCoins, now);
    }
    tx.set(libRef, { uid, playlistId: id, ownerId, title, price, ownerCoins, createdAt: now });
    tx.update(plRef, { addCount: FieldValue.increment(1), ...(ownerCoins > 0 ? { earnedCoins: FieldValue.increment(ownerCoins) } : {}) });
    return { ok: true, price, ownerCoins, paidCount };
  });
});

export const musicStream = onCall({ timeoutSeconds: 15, memory: "256MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const d = (request.data ?? {}) as { soundId?: unknown; playlistId?: unknown };
  if (!okId(d.soundId)) throw new HttpsError("invalid-argument", "Titre invalide.");
  const playlistId = okId(d.playlistId) ? d.playlistId : null;

  const soundRef = db.collection("artist_sounds").doc(d.soundId);
  const lastRef = db.collection("MusicStreamCounts").doc(`${uid}_${d.soundId}`);
  const dayRef = db.collection("MusicStreamDaily").doc(`${uid}_${day()}`);
  return db.runTransaction(async (tx) => {
    const plRef = playlistId ? db.collection("MusicPlaylists").doc(playlistId) : null;
    // Toutes les lectures avant les écritures (règle des transactions Firestore)
    const [sound, last, daily, pl] = await Promise.all([tx.get(soundRef), tx.get(lastRef), tx.get(dayRef), plRef ? tx.get(plRef) : Promise.resolve(null)]);
    if (!sound.exists || sound.get("status") !== "validated") return { ok: true, counted: false };
    if (sound.get("userId") === uid) return { ok: true, counted: false }; // pas d'écoute comptée sur son propre titre
    const now = Date.now();
    if (now - num(last.get("lastAt")) < STREAM_GAP_MS) return { ok: true, counted: false };
    if (num(daily.get("n")) >= STREAM_PER_DAY) return { ok: true, counted: false };
    tx.set(lastRef, { uid, soundId: d.soundId, lastAt: now });
    tx.set(dayRef, { uid, day: day(), n: FieldValue.increment(1) }, { merge: true });
    tx.update(soundRef, { streamCount: FieldValue.increment(1) });
    if (plRef && pl?.exists) tx.update(plRef, { streamCount: FieldValue.increment(1) });
    return { ok: true, counted: true };
  });
});
