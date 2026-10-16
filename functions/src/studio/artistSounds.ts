import { HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { randomUUID } from "crypto";
import { db } from "../shared/firebase";
import { num, recordAppCommission } from "../payments/coinShares";

/**
 * Sons des artistes utilisés dans le Studio (montages « prêts à poster »).
 * La personne qui utilise un son paie [price] pièces ; l'artiste reçoit [share] pièces gagnées (convertibles),
 * le reste va à Afrolook. Réglages : AppConfig/studio { artistSoundPrice, artistSoundShare } (relus toutes les 60 s).
 * Le son est gratuit ou payant, au choix de l'artiste (`pricing`) : gratuit = personne ne paie et l'artiste ne gagne rien ;
 * payant = la personne paie, l'artiste gagne sa part. Un artiste qui utilise son propre son ne paie rien (et ne gagne rien).
 * Le paiement n'a lieu qu'après un montage réussi, une seule fois par montage (ArtistSoundUses/{uid}_{jobId}).
 */
export const MIN_USE = 2;
export const MAX_USE = 20;
export const MIN_SALE = 50;
export const MAX_SALE = 500;
export const ARTIST_PERCENT = 60;

/** Part de l'artiste : 60 % du prix, arrondie vers le bas (5 pièces → 3). */
export const artistShare = (price: number) => Math.floor((price * ARTIST_PERCENT) / 100);

let cache: { at: number; price: number; share: number } | null = null;

export async function artistSoundConfig() {
  if (cache && Date.now() - cache.at < 60000) return cache;
  const d = (await db.collection("AppConfig").doc("studio").get()).data() ?? {};
  const price = Math.max(1, Math.round(num(d["artistSoundPrice"]) || 5));
  const share = Math.min(price, Math.max(0, Math.round(num(d["artistSoundShare"]) || 3)));
  cache = { at: Date.now(), price, share };
  return cache;
}

export type ArtistSoundInfo = {
  id: string;
  artistId: string;
  title: string;
  storagePath: string | null;
  audioUrl: string;
  pricing: "free" | "paid";
  price: number;
  share: number;
};

/** Chemin Storage d'une URL de téléchargement Firebase (…/o/<chemin encodé>?alt=media…). */
export function storagePathFromUrl(url: string): string | null {
  const m = /\/o\/([^?]+)/.exec(url);
  if (!m) return null;
  try {
    return decodeURIComponent(m[1]);
  } catch {
    return null;
  }
}

/** Vérifie qu'un son est validé et que la personne peut le payer (sinon erreur lisible par l'app). */
export async function prepareArtistSound(uid: string, soundId: string): Promise<ArtistSoundInfo> {
  if (!/^[A-Za-z0-9_-]{4,64}$/.test(soundId)) throw new HttpsError("invalid-argument", "Son invalide.");
  const snap = await db.collection("artist_sounds").doc(soundId).get();
  if (!snap.exists || snap.get("status") !== "validated") throw new HttpsError("failed-precondition", "Ce son n'est plus disponible.");
  const d = snap.data()!;
  const audioUrl = String(d["audioUrl"] ?? "");
  const storagePath = (d["audioPath"] as string | undefined) ?? storagePathFromUrl(audioUrl);
  if (!storagePath && !audioUrl) throw new HttpsError("failed-precondition", "Ce son n'est plus disponible.");
  const artistId = String(d["userId"] ?? "");
  const cfg = await artistSoundConfig();
  const own = artistId === uid;
  const pricing: "free" | "paid" = d["pricing"] === "free" ? "free" : "paid";
  // Prix d'utilisation choisi par l'artiste (2 à 20 pièces) ; à défaut, le prix du réglage. L'artiste touche 60 %.
  const useCoins = Math.round(num(d["useCoins"]));
  const unit = useCoins >= MIN_USE && useCoins <= MAX_USE ? useCoins : cfg.price;
  const price = own || pricing === "free" ? 0 : unit;
  if (price > 0) {
    const user = await db.collection("Users").doc(uid).get();
    const balance = num(user.data()?.["giftCoinsBalance"]);
    if (balance < price) throw new HttpsError("resource-exhausted", "Solde de pièces insuffisant.", { coins: price, balance });
  }
  return { id: soundId, artistId, title: String(d["title"] ?? "Son"), storagePath, audioUrl, pricing, price, share: price > 0 ? artistShare(price) : 0 };
}

/** Télécharge le son (Storage du projet si possible, sinon l'URL publique) dans [dest]. */
export async function downloadArtistSound(info: ArtistSoundInfo, dest: string, maxBytes: number) {
  if (info.storagePath) {
    const f = getStorage().bucket().file(info.storagePath);
    const [exists] = await f.exists();
    if (exists) {
      const [meta] = await f.getMetadata();
      if (Number(meta.size) > maxBytes) throw new HttpsError("invalid-argument", "Son trop lourd.");
      await f.download({ destination: dest });
      return;
    }
  }
  if (!info.audioUrl) throw new HttpsError("unavailable", "Son introuvable.");
  const r = await fetch(info.audioUrl);
  if (!r.ok) throw new HttpsError("unavailable", "Son introuvable.");
  const buf = Buffer.from(await r.arrayBuffer());
  if (buf.length > maxBytes) throw new HttpsError("invalid-argument", "Son trop lourd.");
  const { promises: fs } = await import("fs");
  await fs.writeFile(dest, buf);
}

/** Débite la personne et paie l'artiste, une seule fois par montage. Renvoie le nombre de pièces payées. */
export async function chargeArtistSound(uid: string, info: ArtistSoundInfo, jobId: string): Promise<number> {
  const useRef = db.collection("ArtistSoundUses").doc(`${uid}_${jobId}`);
  const userRef = db.collection("Users").doc(uid);
  const artistRef = db.collection("Users").doc(info.artistId);
  const soundRef = db.collection("artist_sounds").doc(info.id);
  return db.runTransaction(async (tx) => {
    const used = await tx.get(useRef);
    if (used.exists) return 0;
    const now = Date.now();
    const price = info.price;
    if (price > 0) {
      const [u, a] = await Promise.all([tx.get(userRef), tx.get(artistRef)]);
      if (!u.exists) throw new HttpsError("not-found", "Compte introuvable.");
      const balance = num(u.data()!["giftCoinsBalance"]);
      if (balance < price) throw new HttpsError("resource-exhausted", "Solde de pièces insuffisant.", { coins: price, balance });
      const artistCoins = a.exists ? info.share : 0;
      tx.update(userRef, { giftCoinsBalance: FieldValue.increment(-price), totalGiftCoinsSpent: FieldValue.increment(price), updatedAt: now });
      const tu = db.collection("TransactionSoldes").doc();
      tx.set(tu, {
        id: tu.id, user_id: uid, type: "DEPENSE", statut: "VALIDER",
        description: `Son « ${info.title.slice(0, 40)} » dans le Studio — ${price} pièces`,
        montant: price, frais: 0, montant_total: price, methode_paiement: "pieces", createdAt: now, updatedAt: now,
        purchaseKind: "studio_son_artiste", purchaseRefId: info.id,
      });
      if (artistCoins > 0) {
        tx.update(artistRef, {
          giftCoinsBalance: FieldValue.increment(artistCoins), totalCoinsEarnedFromSales: FieldValue.increment(artistCoins), updatedAt: now,
        });
        const ta = db.collection("TransactionSoldes").doc();
        tx.set(ta, {
          id: ta.id, user_id: info.artistId, type: "GAIN_PIECES", statut: "VALIDER",
          description: `Ton son « ${info.title.slice(0, 40)} » a été utilisé — ${artistCoins} pièces reçues`,
          montant: artistCoins, frais: 0, montant_total: artistCoins, methode_paiement: "pieces", createdAt: now, updatedAt: now,
          purchaseKind: "studio_son_artiste", purchaseRefId: info.id, payerId: uid,
        });
      }
      recordAppCommission(tx, "contenus", price - artistCoins, now);
      tx.update(soundRef, { usageCount: FieldValue.increment(1), totalEarningsCoins: FieldValue.increment(artistCoins) });
    } else {
      tx.update(soundRef, { usageCount: FieldValue.increment(1) });
    }
    tx.set(useRef, { uid, soundId: info.id, artistId: info.artistId, jobId, price, createdAt: now });
    return price;
  });
}

/**
 * Lien d'écoute temporaire d'un original : copie dans `artist_sound_tmp/` (dossier fermé aux téléphones, règles Storage)
 * avec un jeton aléatoire ; la copie est supprimée par la tâche `cleanupTempListen` au bout de 10 minutes.
 * (Les liens signés par Google exigent un droit de signature que le compte de service du projet n'a pas.)
 */
export async function tempListenUrl(path: string): Promise<string> {
  const bucket = getStorage().bucket();
  const token = randomUUID();
  const dest = `artist_sound_tmp/${Date.now()}_${randomUUID()}.m4a`;
  const copy = bucket.file(dest);
  await bucket.file(path).copy(copy);
  await copy.setMetadata({ contentType: "audio/mp4", metadata: { firebaseStorageDownloadTokens: token } });
  return `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(dest)}?alt=media&token=${token}`;
}

/**
 * Pays où un titre est proposé : même grille que les posts. Gratuit = 1 pays, Premium = 20, Gold et admin = tous (« ALL »).
 * Les pays en plus ne coûtent pas de pièces. Sans choix valide : le pays du profil, sinon tous.
 */
export const COUNTRIES_FREE = 1;
export const COUNTRIES_PREMIUM = 20;

export function countryLimitOf(u: FirebaseFirestore.DocumentData, now = Date.now()): number {
  if (u["role"] === "ADM") return 999;
  const ab = (u["abonnement"] ?? {}) as { type?: string; dateFin?: string; estActif?: boolean };
  const end = ab.dateFin ? Date.parse(ab.dateFin) : NaN;
  const active = ab.estActif !== false && Number.isFinite(end) && end > now;
  if (active && ab.type === "gold") return 999;
  if (active && ab.type === "premium") return COUNTRIES_PREMIUM;
  return COUNTRIES_FREE;
}

export function cleanCountries(input: unknown, limit: number, home: string | null): string[] {
  const raw = Array.isArray(input) ? input : [];
  const list = [...new Set(raw.map((x) => String(x).trim().toUpperCase()).filter((x) => x === "ALL" || /^[A-Z]{2}$/.test(x)))];
  if (list.includes("ALL")) return limit >= 999 ? ["ALL"] : home ? [home] : ["ALL"];
  const out = list.slice(0, Math.max(1, limit));
  return out.length ? out : home ? [home] : ["ALL"];
}

export async function normalizedCountries(uid: string, input: unknown): Promise<string[]> {
  const u = (await db.collection("Users").doc(uid).get()).data() ?? {};
  const c = (u["countryData"] ?? {}) as { countryCode?: unknown };
  const home = typeof c.countryCode === "string" && c.countryCode.length === 2 ? c.countryCode.toUpperCase() : null;
  return cleanCountries(input, countryLimitOf(u), home);
}
