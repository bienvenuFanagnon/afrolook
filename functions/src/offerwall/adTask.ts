import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import * as crypto from "crypto";
import { db } from "../shared/firebase";
import { blockReason, dayOf, eventId, readOfferwallConfig, repayDebt } from "./offerwall_logic";
import { addHundredths, adTaskHundredths, adTaskRefusal, readAdTaskConfig } from "./adTask_logic";
import { userFacts } from "./offerwall_shared";

/**
 * Tâche « Regarder une pub » (docs/OFFERWALL_TACHES.md §20). Deux étapes, toutes décidées par le serveur :
 *  - adTaskStart : vérifie le compte, le plafond du jour et l'écart entre deux pubs, puis donne un jeton à usage unique ;
 *  - adTaskClaim : après la pub regardée en entier (côté application), vérifie le jeton et la durée minimale, puis crédite les pièces tout de suite.
 * État par personne dans AdTaskState/{uid} (collection fermée aux clients, voir firestore.rules). Chaque crédit crée un événement « afrolook_pub »
 * dans OfferwallEvents (même historique, mêmes statistiques et même détail par plateforme que les tâches des partenaires), sans part pour le parrain.
 */
const OPTS = { region: "us-central1" as const, timeoutSeconds: 20, memory: "256MiB" as const };
const NONCE_MAX_AGE_MS = 15 * 60 * 1000;

interface State { day: string; count: number; lastAt: number; nonce: string | null; nonceAt: number; carry: number }
const readState = (d: FirebaseFirestore.DocumentData | undefined): State => ({
  day: String(d?.["day"] ?? ""), count: Math.max(0, Math.floor(Number(d?.["count"]) || 0)), lastAt: Number(d?.["lastAt"]) || 0,
  nonce: typeof d?.["nonce"] === "string" ? (d?.["nonce"] as string) : null, nonceAt: Number(d?.["nonceAt"]) || 0, carry: Math.max(0, Math.floor(Number(d?.["carry"]) || 0)),
});

async function loadAll(uid: string) {
  const [adSnap, ofSnap, userSnap, stSnap] = await Promise.all([
    db.collection("AppConfig").doc("adTask").get(),
    db.collection("AppConfig").doc("offerwall").get(),
    db.collection("Users").doc(uid).get(),
    db.collection("AdTaskState").doc(uid).get(),
  ]);
  return { cfg: readAdTaskConfig(adSnap.data()), ofCfg: readOfferwallConfig(ofSnap.data()), userSnap, st: readState(stSnap.data()) };
}

export const adTaskStart = onCall(OPTS, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Connexion requise.");
  const now = Date.now();
  const { cfg, ofCfg, userSnap, st } = await loadAll(uid);
  if (!cfg.enabled || !ofCfg.enabled) throw new HttpsError("failed-precondition", "indisponible");
  const why = blockReason(await userFacts(uid, userSnap.data()), ofCfg, now);
  if (why) throw new HttpsError("failed-precondition", `compte : ${why}`);
  const today = dayOf(now);
  const refusal = adTaskRefusal(st, cfg, today, now);
  if (refusal) throw new HttpsError("resource-exhausted", refusal.reason, { reason: refusal.reason, waitSec: refusal.waitSec });
  const nonce = crypto.randomBytes(16).toString("hex");
  await db.collection("AdTaskState").doc(uid).set({ nonce, nonceAt: now, updatedAt: now }, { merge: true });
  const done = st.day === today ? st.count : 0;
  return { nonce, remaining: cfg.maxPerDay - done, hundredths: adTaskHundredths(cfg.ecpmEur) };
});

export const adTaskClaim = onCall(OPTS, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Connexion requise.");
  const nonce = String((request.data as { nonce?: unknown } | undefined)?.nonce ?? "");
  if (!/^[0-9a-f]{32}$/.test(nonce)) throw new HttpsError("invalid-argument", "jeton invalide");
  const now = Date.now();
  const today = dayOf(now);
  const { cfg, ofCfg, userSnap } = await loadAll(uid);
  if (!cfg.enabled || !ofCfg.enabled) throw new HttpsError("failed-precondition", "indisponible");
  const why = blockReason(await userFacts(uid, userSnap.data()), ofCfg, now);
  if (why) throw new HttpsError("failed-precondition", `compte : ${why}`);
  const add = adTaskHundredths(cfg.ecpmEur);

  const stRef = db.collection("AdTaskState").doc(uid);
  const userRef = db.collection("Users").doc(uid);
  const out = await db.runTransaction(async (tx) => {
    const [stDoc, uDoc] = await Promise.all([tx.get(stRef), tx.get(userRef)]);
    const st = readState(stDoc.data());
    // le jeton est à usage unique, doit venir de adTaskStart, ne doit pas être trop récent (la vidéo dure plus que cela) ni trop ancien
    if (!st.nonce || st.nonce !== nonce) throw new HttpsError("failed-precondition", "jeton déjà utilisé ou inconnu");
    if (now - st.nonceAt < cfg.minWatchSec * 1000) throw new HttpsError("failed-precondition", "pub trop courte");
    if (now - st.nonceAt > NONCE_MAX_AGE_MS) throw new HttpsError("deadline-exceeded", "jeton expiré");
    const refusal = adTaskRefusal({ day: st.day, count: st.count, lastAt: 0 }, cfg, today, now); // l'écart minimum a été contrôlé au départ
    if (refusal) throw new HttpsError("resource-exhausted", refusal.reason, { reason: refusal.reason, waitSec: refusal.waitSec });
    const sum = addHundredths(st.carry, add);
    const pay = repayDebt(Number(uDoc.data()?.["offerwallDebtCoins"]), sum.coins);
    const count = (st.day === today ? st.count : 0) + 1;
    tx.set(stRef, { day: today, count, lastAt: now, nonce: null, nonceAt: 0, carry: sum.carry, updatedAt: now }, { merge: true });
    if (sum.coins > 0) {
      const evRef = db.collection("OfferwallEvents").doc(eventId("afrolook_pub", `${uid}_${nonce}`));
      tx.create(evRef, {
        provider: "afrolook_pub", platform: "app", requestId: nonce, userId: uid, coins: sum.coins, sponsorId: null, sponsorCoins: 0, studioCoins: 0,
        status: "validee", validatedAt: now, createdAt: now, updatedAt: now, day: today, hundredths: add,
      });
      tx.update(userRef, {
        giftCoinsBalance: FieldValue.increment(pay.credited),
        totalOfferwallCoinsEarned: FieldValue.increment(sum.coins),
        ...(pay.repaid > 0 ? { offerwallDebtCoins: FieldValue.increment(-pay.repaid) } : {}),
      });
      const tRef = db.collection("TransactionSoldes").doc();
      tx.set(tRef, {
        id: tRef.id, user_id: uid, type: "GAIN_PIECES", statut: "VALIDER",
        description: `Pub vidéo regardée — ${sum.coins} pièce${sum.coins > 1 ? "s" : ""}${pay.repaid > 0 ? ` (dont ${pay.repaid} remboursées pour une tâche annulée)` : ""}`,
        montant: sum.coins, frais: 0, montant_total: sum.coins, methode_paiement: "pub_afrolook", offerwallEventId: evRef.id, offerwallProvider: "afrolook_pub", createdAt: now, updatedAt: now,
      });
    }
    return { coins: sum.coins, carry: sum.carry, remaining: cfg.maxPerDay - count };
  });
  return { credited: out.coins, carry: out.carry, remaining: out.remaining, hundredths: add };
});
