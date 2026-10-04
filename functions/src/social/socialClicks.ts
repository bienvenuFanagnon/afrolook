import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";

const NETWORKS = ["facebook", "tiktok"];
/** Un même utilisateur est compté au plus une fois par réseau et par heure. */
const MIN_GAP_MS = 60 * 60 * 1000;

/**
 * Widget « Rejoins-nous » : compte les clics sur Facebook / TikTok.
 * Le total est dans AppConfig/socialClicks ({facebook, tiktok}), écrit uniquement ici.
 */
export const recordSocialClick = onCall({ timeoutSeconds: 15 }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Auth requise");
  const network = String(request.data?.network ?? "");
  if (!NETWORKS.includes(network)) throw new HttpsError("invalid-argument", "network invalide");

  const uid = request.auth.uid;
  const totalRef = db.collection("AppConfig").doc("socialClicks");
  const userRef = db.collection("SocialClicks").doc(`${uid}_${network}`);
  const counted = await db.runTransaction(async (txn) => {
    const u = await txn.get(userRef);
    const last = (u.data()?.lastAt as number | undefined) ?? 0;
    if (Date.now() - last < MIN_GAP_MS) return false;
    txn.set(userRef, { userId: uid, network, lastAt: Date.now() }, { merge: true });
    txn.set(totalRef, { [network]: FieldValue.increment(1) }, { merge: true });
    return true;
  });
  return { ok: true, counted };
});
