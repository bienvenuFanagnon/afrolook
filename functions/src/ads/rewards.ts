import { onCall, onRequest, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import * as crypto from "crypto";
import { db } from "../shared/firebase";

/**
 * Page « Récompenses » : on regarde des pubs récompensées, le serveur compte les pubs (« en réserve »)
 * puis échange N pubs contre une récompense. Le serveur décide de tout (catalogue, plafonds, rôles).
 *
 * Deux façons de compter une pub regardée :
 * - `recordAdView` (l'app déclare la pub vue) tant que AppConfig/ads.ssvEnabled est faux ;
 * - `adSsvCallback` (AdMob confirme au serveur, vérification de signature) quand ssvEnabled est vrai.
 */
export const MAX_ADS_PER_DAY = 10;
const MIN_GAP_MS = 5000;
const HOUR = 3600 * 1000;
const MAX_PREMIUM_AHEAD = 48 * HOUR;

type Offer =
  | { ads: number; cap: number; kind: "premium"; hours: number }
  | { ads: number; cap: number; kind: "adfree" }
  | { ads: number; cap: number; kind: "coins"; coins: number }
  | { ads: number; cap: number; kind: "shield" }
  | { ads: number; cap: number; kind: "stickers"; count: number }
  | { ads: number; cap: number; kind: "photos" };

export const OFFERS: Record<string, Offer> = {
  premium_5h: { ads: 2, cap: 3, kind: "premium", hours: 5 },
  premium_10h: { ads: 3, cap: 3, kind: "premium", hours: 10 },
  premium_24h: { ads: 5, cap: 2, kind: "premium", hours: 24 },
  adfree_24h: { ads: 1, cap: 2, kind: "adfree" },
  coins_2: { ads: 1, cap: 5, kind: "coins", coins: 2 },
  flame_shield: { ads: 1, cap: 1, kind: "shield" },
  stickers_3: { ads: 1, cap: 2, kind: "stickers", count: 3 },
  photos_3: { ads: 2, cap: 3, kind: "photos" },
};

const dayKey = () => new Date().toISOString().slice(0, 10).replace(/-/g, "");
const rewardsRef = (uid: string) => db.collection("AdRewards").doc(`${uid}_${dayKey()}`);
const isAdmin = (u: FirebaseFirestore.DocumentData | undefined) => u?.["role"] === "ADM";

async function ssvEnabled(): Promise<boolean> {
  const cfg = (await db.collection("AppConfig").doc("ads").get()).data() ?? {};
  return cfg["ssvEnabled"] === true;
}

/** Ajoute une pub regardée à la réserve du jour (plafond quotidien, sauf admin). */
async function addView(uid: string, gapMs: number): Promise<{ pending: number; watched: number }> {
  return db.runTransaction(async (tx) => {
    const [r, u] = await Promise.all([tx.get(rewardsRef(uid)), tx.get(db.collection("Users").doc(uid))]);
    const d = r.data() ?? {};
    const watched = Number(d["adsWatched"] ?? 0);
    if (!isAdmin(u.data()) && watched >= MAX_ADS_PER_DAY) throw new HttpsError("resource-exhausted", "Limite de pubs du jour atteinte.");
    if (gapMs > 0 && Date.now() - Number(d["lastViewAt"] ?? 0) < gapMs) throw new HttpsError("resource-exhausted", "Trop rapide.");
    const pending = Number(d["pending"] ?? 0) + 1;
    tx.set(rewardsRef(uid), { userId: uid, day: dayKey(), adsWatched: watched + 1, pending, lastViewAt: Date.now() }, { merge: true });
    return { pending, watched: watched + 1 };
  });
}

/** L'app déclare une pub vue (mode sans vérification AdMob). */
export const recordAdView = onCall({ timeoutSeconds: 15 }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  if (await ssvEnabled()) throw new HttpsError("failed-precondition", "La vérification AdMob est active.");
  return { ok: true, ...(await addView(uid, MIN_GAP_MS)) };
});

/** Échange des pubs en réserve contre une récompense. */
export const claimReward = onCall({ timeoutSeconds: 20 }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const offerId = String(request.data?.offerId ?? "");
  const offer = OFFERS[offerId];
  if (!offer) throw new HttpsError("invalid-argument", "Offre inconnue.");
  const userRef = db.collection("Users").doc(uid);

  const result = await db.runTransaction(async (tx) => {
    const [r, userSnap] = await Promise.all([tx.get(rewardsRef(uid)), tx.get(userRef)]);
    const u = userSnap.data() ?? {};
    const admin = isAdmin(u);
    const ab = (u["abonnement"] ?? {}) as { type?: string; dateFin?: string; estActif?: boolean; methodePaiement?: string };
    const now = Date.now();
    const end = ab.dateFin ? Date.parse(ab.dateFin) : NaN;
    const paidActive = (ab.type === "premium" || ab.type === "gold") && ab.estActif !== false && Number.isFinite(end) && end > now && ab.methodePaiement !== "pubs";
    if (!admin && ab.type === "gold" && paidActive) throw new HttpsError("failed-precondition", "Compte Gold : déjà tout débloqué.");

    const d = r.data() ?? {};
    const pending = Number(d["pending"] ?? 0);
    if (pending < offer.ads) throw new HttpsError("failed-precondition", "Pas assez de pubs regardées.");
    const claims = (d["claims"] ?? {}) as Record<string, number>;
    if (!admin && Number(claims[offerId] ?? 0) >= offer.cap) throw new HttpsError("resource-exhausted", "Limite du jour atteinte pour cette offre.");

    const anyPremium = (ab.type === "premium" || ab.type === "gold") && ab.estActif !== false && Number.isFinite(end) && end > now;
    const out: Record<string, unknown> = { ok: true, offerId };
    if (offer.kind === "premium") {
      if (paidActive && !admin) throw new HttpsError("failed-precondition", "Tu es déjà Premium.");
      const current = ab.methodePaiement === "pubs" && Number.isFinite(end) ? Math.max(end, now) : now;
      const until = Math.min(current + offer.hours * HOUR, now + MAX_PREMIUM_AHEAD);
      if (until <= current) throw new HttpsError("resource-exhausted", "Maximum de Premium cumulé atteint (48 h).");
      const iso = new Date(until).toISOString();
      tx.set(userRef, {
        abonnement: {
          type: "premium", prix: 0, dateDebut: new Date(now).toISOString(), dateFin: iso, estActif: true,
          dureeMois: 0, montantPaye: 0, methodePaiement: "pubs", transactionId: null,
          createdAt: new Date(now).toISOString(), updatedAt: new Date(now).toISOString(), avantagesActives: [],
        },
      }, { merge: true });
      out["until"] = until;
    } else if (offer.kind === "adfree") {
      const cur = Number(u["adFreeUntil"] ?? 0);
      const next = Math.min(Math.max(now, cur) + 24 * HOUR, now + 2 * 24 * HOUR);
      tx.set(userRef, { adFreeUntil: next }, { merge: true });
      out["until"] = next;
    } else if (offer.kind === "coins") {
      tx.set(userRef, { giftCoinsBalance: FieldValue.increment(offer.coins) }, { merge: true });
      out["coins"] = offer.coins;
    } else if (offer.kind === "stickers") {
      if (anyPremium && !admin) throw new HttpsError("failed-precondition", "Les stickers sont déjà inclus dans ton abonnement.");
      const b = (u["stickerBonus"] ?? {}) as { day?: string; remaining?: number };
      const base = b.day === dayKey() ? Number(b.remaining ?? 0) : 0;
      tx.set(userRef, { stickerBonus: { day: dayKey(), remaining: base + offer.count } }, { merge: true });
      out["stickers"] = base + offer.count;
    } else if (offer.kind === "photos") {
      if (anyPremium && !admin) throw new HttpsError("failed-precondition", "Les photos multiples sont déjà incluses dans ton abonnement.");
      tx.set(userRef, { multiPhotoCredits: FieldValue.increment(1) }, { merge: true });
      out["photoCredits"] = Number(u["multiPhotoCredits"] ?? 0) + 1;
    } else {
      const shields = Number(u["streakShields"] ?? 0);
      if (shields >= 3) throw new HttpsError("failed-precondition", "Boucliers déjà au maximum.");
      tx.set(userRef, { streakShields: shields + 1 }, { merge: true });
      out["shields"] = shields + 1;
    }
    tx.set(rewardsRef(uid), { pending: pending - offer.ads, claims: { ...claims, [offerId]: Number(claims[offerId] ?? 0) + 1 } }, { merge: true });
    return out;
  });
  return result;
});

// ── Vérification côté serveur d'AdMob (SSV) ───────────────────────────────

let keysCache: { at: number; keys: Record<string, string> } | null = null;

async function googleKeys(): Promise<Record<string, string>> {
  if (keysCache && Date.now() - keysCache.at < 6 * HOUR) return keysCache.keys;
  const res = await fetch("https://www.gstatic.com/admob/reward/verifier-keys.json");
  const json = (await res.json()) as { keys: Array<{ keyId: number | string; pem: string }> };
  const keys: Record<string, string> = {};
  for (const k of json.keys) keys[String(k.keyId)] = k.pem;
  keysCache = { at: Date.now(), keys };
  return keys;
}

/** Vérifie la signature d'un rappel AdMob : contenu = requête avant « &signature= », ECDSA SHA-256. */
export function verifySsv(rawQuery: string, keys: Record<string, string>): boolean {
  const i = rawQuery.indexOf("&signature=");
  if (i < 0) return false;
  const content = rawQuery.substring(0, i);
  const tail = new URLSearchParams(rawQuery.substring(i + 1));
  const signature = tail.get("signature");
  const keyId = tail.get("key_id");
  if (!signature || !keyId || !keys[keyId]) return false;
  try {
    const v = crypto.createVerify("SHA256");
    v.update(content);
    return v.verify(keys[keyId], Buffer.from(signature.replace(/-/g, "+").replace(/_/g, "/"), "base64"));
  } catch {
    return false;
  }
}

/** URL à saisir dans AdMob (bloc « Avec récompense » → Vérification côté serveur). */
export const adSsvCallback = onRequest({ invoker: "public", timeoutSeconds: 20 }, async (req, res) => {
  try {
    const raw = (req.originalUrl.split("?")[1] ?? "");
    if (!verifySsv(raw, await googleKeys())) {
      res.status(403).send("signature invalide");
      return;
    }
    const q = new URLSearchParams(raw);
    const uid = q.get("user_id") ?? "";
    const tx = q.get("transaction_id") ?? "";
    if (!uid || !tx) {
      res.status(200).send("ignoré");
      return;
    }
    const txRef = db.collection("AdSsvTx").doc(tx);
    try {
      await txRef.create({ userId: uid, at: Date.now() });
    } catch {
      res.status(200).send("déjà traité");
      return;
    }
    try {
      await addView(uid, 0);
    } catch (e) {
      console.log("[adSsv] refusé :", (e as Error).message);
    }
    res.status(200).send("ok");
  } catch (e) {
    console.error("[adSsv]", e);
    res.status(500).send("erreur");
  }
});
