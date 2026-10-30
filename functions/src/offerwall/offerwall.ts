import { onSchedule } from "firebase-functions/v2/scheduler";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { recordAppCommission } from "../payments/coinShares";
import { blockReason, repayDebt } from "./offerwall_logic";
import { loadConfig, userFacts } from "./offerwall_shared";

/**
 * Libération des pièces du mur de tâches : toutes les 15 minutes, les pièces arrivées à échéance (48 h par défaut) deviennent des Pièces gagnées
 * convertibles si le compte remplit encore les conditions (ancienneté, e-mail vérifié, pas en suppression, pas suspendu) ; le parrain reçoit sa commission.
 * Le retour des régies (qui crée les événements) est dans tapjoyCallback.ts. Voir docs/OFFERWALL_TACHES.md.
 */
/** Convertit les pièces arrivées à échéance. Les événements « en_revue » ne sont jamais libérés automatiquement. */
export const offerwallRelease = onSchedule(
  { region: "us-central1", schedule: "every 15 minutes", timeoutSeconds: 180, memory: "256MiB" },
  async () => {
    const now = Date.now();
    const cfg = await loadConfig();
    const snap = await db.collection("OfferwallEvents").where("status", "==", "pending").limit(300).get();
    let released = 0; let expired = 0; let waiting = 0;
    for (const doc of snap.docs) {
      const e = doc.data();
      if ((Number(e["releaseAt"]) || 0) > now) continue;
      const uid = String(e["userId"] ?? "");
      try {
        const userSnap = await db.collection("Users").doc(uid).get();
        const facts = await userFacts(uid, userSnap.data());
        const reason = blockReason(facts, cfg, now);
        const coins = Math.floor(Number(e["coins"]) || 0);
        if (reason) {
          // conditions pas (encore) remplies : on réessaie au prochain passage ; au-delà du délai d'expiration, l'événement expire
          if (now - (Number(e["createdAt"]) || now) > cfg.expireDays * 86_400_000 || reason === "compte en cours de suppression" || reason === "compte inconnu") {
            await db.runTransaction(async (tx) => {
              const cur = await tx.get(doc.ref);
              if (cur.data()?.["status"] !== "pending") return;
              tx.update(doc.ref, { status: "expiree", reason, updatedAt: now });
              if (userSnap.exists) tx.update(userSnap.ref, { offerwallPendingCoins: FieldValue.increment(-coins) });
            });
            expired++;
          } else {
            await doc.ref.update({ lastCheckAt: now, lastBlock: reason });
            waiting++;
          }
          continue;
        }
        await db.runTransaction(async (tx) => {
          // lectures d'abord (transaction Firestore)
          const cur = await tx.get(doc.ref);
          if (cur.data()?.["status"] !== "pending") return; // déjà libéré par un autre passage
          const sponsorId = (cur.data()?.["sponsorId"] as string | null) ?? null;
          const sponsorCoins = Math.floor(Number(cur.data()?.["sponsorCoins"]) || 0);
          const studioCoins = Math.floor(Number(cur.data()?.["studioCoins"]) || 0);
          const uDoc = await tx.get(userSnap.ref);
          const sponsorRef = sponsorId && sponsorCoins > 0 ? db.collection("Users").doc(sponsorId) : null;
          const sDoc = sponsorRef ? await tx.get(sponsorRef) : null;
          // une dette (tâche annulée par un partenaire) est remboursée d'abord par ce gain
          const uPay = repayDebt(Number(uDoc.data()?.["offerwallDebtCoins"]), coins);
          tx.update(userSnap.ref, {
            giftCoinsBalance: FieldValue.increment(uPay.credited),
            offerwallPendingCoins: FieldValue.increment(-coins),
            totalOfferwallCoinsEarned: FieldValue.increment(coins),
            ...(uPay.repaid > 0 ? { offerwallDebtCoins: FieldValue.increment(-uPay.repaid) } : {}),
          });
          const tRef = db.collection("TransactionSoldes").doc();
          tx.set(tRef, {
            id: tRef.id, user_id: uid, type: "GAIN_PIECES", statut: "VALIDER",
            description: `Tâche terminée (mur de tâches) — ${coins} pièces${uPay.repaid > 0 ? ` (dont ${uPay.repaid} remboursées pour une tâche annulée)` : ""}`, montant: coins, frais: 0, montant_total: coins,
            methode_paiement: "offres", offerwallEventId: doc.id, offerwallProvider: String(e["provider"] ?? ""), createdAt: now, updatedAt: now,
          });
          if (sponsorRef && sponsorId) {
            const sPay = repayDebt(Number(sDoc?.data()?.["offerwallDebtCoins"]), sponsorCoins);
            tx.update(sponsorRef, {
              giftCoinsBalance: FieldValue.increment(sPay.credited),
              totalCoinsEarnedFromSponsorship: FieldValue.increment(sponsorCoins),
              ...(sPay.repaid > 0 ? { offerwallDebtCoins: FieldValue.increment(-sPay.repaid) } : {}),
            });
            const sRef = db.collection("TransactionSoldes").doc();
            tx.set(sRef, {
              id: sRef.id, user_id: sponsorId, type: "GAIN_PIECES", statut: "VALIDER",
              description: `Commission de parrainage (tâche d'un filleul) — ${sponsorCoins} pièces${sPay.repaid > 0 ? ` (dont ${sPay.repaid} remboursées pour une tâche annulée)` : ""}`, montant: sponsorCoins, frais: 0, montant_total: sponsorCoins,
              methode_paiement: "commission_parrainage", offerwallEventId: doc.id, createdAt: now, updatedAt: now,
            });
          }
          // part de l'application, enregistrée par partenaire (Tapjoy / ayeT) pour la page « Commissions » ; « offres » = partenaire inconnu
          const src = cur.data()?.["provider"] === "tapjoy" ? "offres_tapjoy" : cur.data()?.["provider"] === "ayet" ? "offres_ayet" : cur.data()?.["provider"] === "pubscale" ? "offres_pubscale" : "offres";
          recordAppCommission(tx, src, studioCoins, now);
          tx.update(doc.ref, { status: "validee", validatedAt: now, updatedAt: now });
        });
        released++;
      } catch (err) {
        console.error("[offerwall] libération en échec", doc.id, err);
      }
    }
    console.log(`[offerwall] libération : ${released} validée(s), ${waiting} en attente de conditions, ${expired} expirée(s), ${snap.size} examinée(s)`);
  },
);
