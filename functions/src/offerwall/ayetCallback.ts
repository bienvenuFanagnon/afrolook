import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { reverseAppCommission, sponsorOf } from "../payments/coinShares";
import { MAX_LEN, loadConfig, str } from "./offerwall_shared";
import { ayetAmountsCoherent, ayetVerify, capDecision, dayOf, eventId, lastSevenDays, parseCoins, splitCoins, takeBack } from "./offerwall_logic";

/**
 * Retour serveur ayeT-Studios (voir docs/OFFERWALL_TACHES.md §13 et §17) : GET dont l'en-tête X-Ayetstudios-Security-Hash contient
 * le HMAC-SHA256 des paramètres (triés) calculé avec la clé d'API éditeur. Fichier à part : seul à déclarer ce secret (Secret Manager).
 * Les conversions créent un événement « en attente » (même circuit que Tapjoy, libéré par offerwallRelease) ;
 * les annulations (callback_type=chargeback, identifiant préfixé « r- », montants négatifs) retirent les pièces.
 * ayeT exige une réponse 200 : sinon il renvoie 12 fois en une heure. On répond donc 200 pour tout ce qui est « sans suite » (déjà traité,
 * type d'événement ignoré, mode test) et 403 seulement pour ce qui n'est pas un vrai appel d'ayeT.
 */
const AYET_API_KEY = defineSecret("AYET_API_KEY");

/** Adresses sources d'ayeT (dernière mise à jour de leur liste : 30/01/2025) : utilisées seulement si `enforceIp` est activé. */
const AYET_IPS = new Set(["51.79.101.241", "158.69.185.134", "158.69.185.154", "35.165.166.40", "35.166.159.131", "52.40.3.140"]);

export const ayetOfferwallCallback = onRequest(
  { region: "us-central1", timeoutSeconds: 15, memory: "256MiB", maxInstances: 10, secrets: [AYET_API_KEY] },
  async (req, res) => {
    res.set("Content-Type", "text/plain; charset=utf-8");
    if (req.method !== "GET") { res.status(405).send("Method Not Allowed"); return; }

    const params: Record<string, string> = {};
    for (const k of Object.keys(req.query)) params[k] = str(req.query[k]);

    // 1. signature (sans elle, rien n'est lu)
    const matched = ayetVerify(params, str(req.headers["x-ayetstudios-security-hash"]), AYET_API_KEY.value());
    if (matched < 0) { console.warn("[offerwall] ayeT : signature absente ou invalide", Object.keys(params).sort().join(",")); res.status(403).send("bad hash"); return; }
    console.log(`[offerwall] ayeT : signature reconnue (écriture n°${matched})`);

    const txId = (params["transaction_id"] ?? "").trim();
    const uid = (params["external_identifier"] ?? "").trim();
    const isChargeback = params["is_chargeback"] === "1" || params["callback_type"] === "chargeback";
    const type = params["callback_type"] || (isChargeback ? "chargeback" : "conversion");
    if (!txId || txId.length > MAX_LEN || !uid || uid.length > MAX_LEN || uid.includes("/")) { res.status(403).send("invalid"); return; }

    try {
      const cfg = await loadConfig();
      const ip = String(req.headers["x-forwarded-for"] ?? req.ip ?? "").split(",")[0].trim();
      if (cfg.enforceIp && !AYET_IPS.has(ip)) { console.warn("[offerwall] ayeT : adresse inattendue", ip); res.status(403).send("forbidden"); return; }

      // événements sans pièces (installation, conversion optionnelle, achat intégré, publicité) : rien à créditer, réponse 200 pour éviter les relances
      if (type !== "conversion" && type !== "chargeback") { res.status(200).send("OK"); return; }
      // conversion de test (identifiant « bac à sable » d'ayeT, faux montants) : jamais créditée, SAUF pour les comptes de test listés dans la variable
      // OFFERWALL_SANDBOX_UIDS (functions/.env, identifiants Firebase séparés par des virgules ; vide par défaut) : sert à tester le circuit complet
      // (en attente → validée) avec de fausses pièces sur un compte de test, à retirer ensuite.
      const sandbox = params["is_sandbox"] === "1";
      const sandboxTesters = new Set((process.env.OFFERWALL_SANDBOX_UIDS ?? "").split(",").map((x) => x.trim()).filter(Boolean));
      if (sandbox && !sandboxTesters.has(uid)) { console.log("[offerwall] ayeT : conversion de test ignorée"); res.status(200).send("OK"); return; }
      if (sandbox) console.log("[offerwall] ayeT : conversion de test acceptée pour un compte de test");

      const now = Date.now();

      // ─── Annulation (reversal) ───
      if (isChargeback) {
        const origId = txId.startsWith("r-") ? txId.slice(2) : txId;
        const origRef = db.collection("OfferwallEvents").doc(eventId("ayet", origId));
        const userRef = db.collection("Users").doc(uid);
        const outcome = await db.runTransaction(async (tx) => {
          // toutes les lectures AVANT les écritures (transaction Firestore)
          const o = await tx.get(origRef);
          if (!o.exists) return "inconnue";
          const e = o.data() ?? {};
          const sponsorId = (e["sponsorId"] as string | null) ?? null;
          const u = await tx.get(userRef);
          const sponsorRef = sponsorId ? db.collection("Users").doc(sponsorId) : null;
          const sp = sponsorRef ? await tx.get(sponsorRef) : null;
          const st = String(e["status"] ?? "");
          const coins = Math.floor(Number(e["coins"]) || 0);
          const reason = String(params["chargeback_reason"] ?? "").slice(0, 80);
          if (st === "annulee") return "deja";
          if (st === "pending" || st === "en_revue") {
            // pièces encore en attente : on les retire, rien n'a été versé (ni parrain, ni commission)
            tx.update(origRef, { status: "annulee", cancelledAt: now, cancelReason: reason, updatedAt: now });
            if (u.exists) tx.update(userRef, { offerwallPendingCoins: FieldValue.increment(-coins) });
            return "retiree";
          }
          if (st === "validee") {
            // Tâche déjà validée puis annulée par le partenaire : on défait TOUT ce qu'elle a payé, avec une transaction pour chaque personne.
            // Ce qui ne peut pas être repris (pièces déjà retirées ou dépensées) devient une dette, remboursée par les prochains gains de tâches
            // (offerwallRelease) ; tant qu'elle existe, la conversion en argent est bloquée (convertGiftCoins).
            const sponsorCoins = Math.floor(Number(e["sponsorCoins"]) || 0);
            const studioCoins = Math.floor(Number(e["studioCoins"]) || 0);
            const label = "Tâche annulée par le partenaire";
            const uTake = takeBack(Number(u.data()?.["giftCoinsBalance"]), coins);
            if (u.exists) {
              tx.update(userRef, {
                giftCoinsBalance: FieldValue.increment(-uTake.taken),
                totalOfferwallCoinsEarned: FieldValue.increment(-coins),
                ...(uTake.debt > 0 ? { offerwallDebtCoins: FieldValue.increment(uTake.debt) } : {}),
                updatedAt: now,
              });
              const tRef = db.collection("TransactionSoldes").doc();
              tx.set(tRef, {
                id: tRef.id, user_id: uid, type: "DEPENSE", statut: "VALIDER",
                description: `${label} : -${coins} pièces${uTake.debt > 0 ? ` (dont ${uTake.debt} en dette, remboursée par tes prochains gains de tâches)` : ""}`,
                montant: coins, frais: 0, montant_total: coins, methode_paiement: "annulation_offres", offerwallEventId: o.id, createdAt: now, updatedAt: now,
              });
            }
            let sTake = { taken: 0, debt: 0 };
            if (sponsorRef && sp?.exists && sponsorCoins > 0) {
              sTake = takeBack(Number(sp.data()?.["giftCoinsBalance"]), sponsorCoins);
              tx.update(sponsorRef, {
                giftCoinsBalance: FieldValue.increment(-sTake.taken),
                totalCoinsEarnedFromSponsorship: FieldValue.increment(-sponsorCoins),
                ...(sTake.debt > 0 ? { offerwallDebtCoins: FieldValue.increment(sTake.debt) } : {}),
                updatedAt: now,
              });
              const sRef = db.collection("TransactionSoldes").doc();
              tx.set(sRef, {
                id: sRef.id, user_id: sponsorId, type: "DEPENSE", statut: "VALIDER",
                description: `Commission de parrainage annulée (tâche d'un filleul annulée par le partenaire) : -${sponsorCoins} pièces${sTake.debt > 0 ? ` (dont ${sTake.debt} en dette)` : ""}`,
                montant: sponsorCoins, frais: 0, montant_total: sponsorCoins, methode_paiement: "annulation_offres", offerwallEventId: o.id, createdAt: now, updatedAt: now,
              });
            }
            // part de l'application : écriture inverse dans les commissions du jour (même source que celle de la validation)
            reverseAppCommission(tx, "offres_ayet", studioCoins, now);
            tx.update(origRef, {
              status: "annulee", cancelledAt: now, cancelledAfterValidation: true, cancelReason: reason, updatedAt: now,
              takenBack: uTake.taken, debtCoins: uTake.debt, sponsorTakenBack: sTake.taken, sponsorDebtCoins: sTake.debt, appReversedCoins: studioCoins,
            });
            return "reprise";
          }
          return "sans_suite"; // refusée, expirée…
        });
        console.log(`[offerwall] ayeT annulation : ${outcome}`);
        res.status(200).send("OK");
        return;
      }

      // ─── Conversion ───
      const evRef = db.collection("OfferwallEvents").doc(eventId("ayet", txId));
      if ((await evRef.get()).exists) { res.status(200).send("OK"); return; } // relance d'ayeT : déjà traité

      const userRef = db.collection("Users").doc(uid);
      if (!(await userRef.get()).exists) { console.warn("[offerwall] ayeT : utilisateur inconnu"); res.status(403).send("unknown user"); return; }

      const parsed = parseCoins(params["currency_amount"], cfg.maxCoinsPerEvent);
      const base = { provider: "ayet", platform: "inconnue", requestId: txId, userId: uid, adslotId: (params["adslot_id"] ?? "").slice(0, 20), offerId: (params["offer_id"] ?? "").slice(0, 20), payoutUsd: (params["payout_usd"] ?? "").slice(0, 16), ...(sandbox ? { sandbox: true } : {}) };
      if (!parsed.ok) {
        await evRef.set({ ...base, status: "refusee", reason: parsed.reason, rawCurrency: String(params["currency_amount"] ?? "").slice(0, 32), createdAt: now, updatedAt: now }).catch(() => undefined);
        res.status(200).send("OK"); // ayeT ne doit pas relancer un montant inutilisable
        return;
      }

      const sponsorId = await sponsorOf(uid);
      const split = splitCoins(parsed.coins, cfg.sponsorPct, !!sponsorId);

      const days = lastSevenDays(now);
      const dailySnaps = await db.getAll(...days.map((d) => db.collection("OfferwallDaily").doc(`${uid}_${d}`)));
      const coinsOf = (i: number): number => Number(dailySnaps[i].data()?.["coins"] ?? 0) || 0;
      const today = coinsOf(0);
      const week = dailySnaps.reduce((s, _x, i) => s + coinsOf(i), 0);
      const capped = capDecision(today, week, parsed.coins, cfg) !== "ok";
      const incoherent = !ayetAmountsCoherent(parsed.coins, params["payout_usd"]);
      const reviewReason = incoherent ? "écart entre pièces et paiement" : capped ? "plafond dépassé" : null;

      await db.runTransaction(async (tx) => {
        if ((await tx.get(evRef)).exists) return; // deux relances en même temps : une seule passe
        tx.create(evRef, {
          ...base, coins: split.user, sponsorId: sponsorId ?? null, sponsorCoins: split.sponsor, studioCoins: split.studio,
          status: reviewReason ? "en_revue" : "pending", reviewReason,
          // conversion de test acceptée pour un compte de test : délai d'attente réduit à 2 minutes (validée au prochain passage de offerwallRelease, toutes les 15 min)
          releaseAt: now + (sandbox ? 120_000 : cfg.holdHours * 3_600_000), createdAt: now, updatedAt: now, day: dayOf(now),
        });
        tx.set(db.collection("OfferwallDaily").doc(`${uid}_${dayOf(now)}`), { userId: uid, day: dayOf(now), coins: FieldValue.increment(split.user), updatedAt: now }, { merge: true });
        tx.update(userRef, { offerwallPendingCoins: FieldValue.increment(split.user) });
      });
      console.log(`[offerwall] ayeT : ${split.user} pièces en attente (${reviewReason ?? "ok"})`);
      res.status(200).send("OK");
    } catch (e) {
      // erreur temporaire : 500 → ayeT réessaie (12 fois en une heure) ; l'identifiant d'événement empêche tout doublon
      console.error("[offerwall] ayeT : erreur de traitement", e);
      res.status(500).send("retry");
    }
  },
);
