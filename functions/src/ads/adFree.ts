import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db } from "../shared/firebase";

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Pub récompensée regardée en entier → 1 jour sans pub (Users.adFreeUntil).
 * Plafond par jour (AppConfig/ads.rewardedMaxPerDay, 2 par défaut) ; la fin ne dépasse jamais 48 h.
 * La vue de la pub ne peut pas être vérifiée côté serveur : le plafond limite l'abus.
 */
export const grantAdFreeDay = onCall({ timeoutSeconds: 15 }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");

  const cfg = (await db.collection("AppConfig").doc("ads").get()).data() ?? {};
  const max = typeof cfg["rewardedMaxPerDay"] === "number" ? cfg["rewardedMaxPerDay"] : 2;
  const day = new Date().toISOString().slice(0, 10).replace(/-/g, "");
  const capRef = db.collection("AdRewards").doc(`${uid}_${day}`);
  const userRef = db.collection("Users").doc(uid);

  const until = await db.runTransaction(async (tx) => {
    const [cap, user] = await Promise.all([tx.get(capRef), tx.get(userRef)]);
    const used = Number(cap.data()?.["count"] ?? 0);
    if (used >= max) throw new HttpsError("resource-exhausted", "Limite du jour atteinte.");
    const now = Date.now();
    const current = Number(user.data()?.["adFreeUntil"] ?? 0);
    const next = Math.min(Math.max(now, current) + DAY_MS, now + 2 * DAY_MS);
    tx.set(capRef, { userId: uid, day, count: used + 1 }, { merge: true });
    tx.set(userRef, { adFreeUntil: next }, { merge: true });
    return next;
  });
  return { ok: true, until };
});
