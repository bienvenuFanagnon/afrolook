import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { reverseAppCommission, sponsorOf } from "../payments/coinShares";
import { MAX_LEN, loadConfig, str } from "./offerwall_shared";
import { capDecision, dayOf, eventId, lastSevenDays, parseCoins, pubscaleSignature, safeEqualHex, splitCoins, takeBack } from "./offerwall_logic";

/**
 * Retours serveur Pubscale (voir docs/OFFERWALL_TACHES.md §19.5) : GET avec user_id, value, token, signature.
 * La signature est le MD5 de « clé_secrète.user_id.valeur_entière.token ».
 *  - pubscaleOfferwallCallback : une conversion (pièces en attente, même circuit que Tapjoy et ayeT, libéré par offerwallRelease) ;
 *  - pubscaleChargebackCallback : une annulation (reprise complète si la tâche était déjà validée).
 * Pubscale demande une application par plateforme : deux clés secrètes (Android, iPhone), celle qui valide la signature indique la plateforme.
 * Réponse 2xx = livré ; sinon Pubscale réessaie 6 fois : on répond donc 200 pour tout ce qui est « sans suite » et 403 seulement
 * pour ce qui n'est pas un vrai appel de Pubscale. Fichier à part : seul à déclarer ces secrets (Secret Manager).
 */
const PS_ANDROID = defineSecret("PUBSCALE_SECRET_ANDROID");
const PS_IOS = defineSecret("PUBSCALE_SECRET_IOS");

/** Adresses sources de Pubscale (documentation) : utilisées seulement si `enforceIp` est activé. */
const PUBSCALE_IPS = new Set(["34.100.236.68", "34.100.128.195", "34.14.172.7"]);

type Plat = "android" | "ios";

function readParams(req: { query: Record<string, unknown> }): Record<string, string> {
  const o: Record<string, string> = {};
  for (const k of Object.keys(req.query)) o[k] = str(req.query[k]);
  return o;
}

/** Plateforme dont la clé secrète valide la signature (null si aucune : ce n'est pas un appel de Pubscale). */
function platformOf(p: Record<string, string>): Plat | null {
  const sig = (p["signature"] ?? "").trim().toLowerCase();
  const candidates: Array<[Plat, string]> = [["android", PS_ANDROID.value()], ["ios", PS_IOS.value()]];
  for (const [plat, secret] of candidates) {
    if (secret && safeEqualHex(sig, pubscaleSignature(secret, p["user_id"] ?? "", p["value"] ?? "", p["token"] ?? ""))) return plat;
  }
  return null;
}

const wellFormed = (p: Record<string, string>): boolean => {
  const token = (p["token"] ?? "").trim();
  const uid = (p["user_id"] ?? "").trim();
  return !!token && token.length <= MAX_LEN && !!uid && uid.length <= MAX_LEN && !uid.includes("/") && !!p["value"] && !!p["signature"];
};

// ─── Conversion ───
export const pubscaleOfferwallCallback = onRequest(
  { region: "us-central1", timeoutSeconds: 15, memory: "256MiB", maxInstances: 10, secrets: [PS_ANDROID, PS_IOS] },
  async (req, res) => {
    res.set("Content-Type", "text/plain; charset=utf-8");
    if (req.method !== "GET") { res.status(405).send("Method Not Allowed"); return; }
    const p = readParams(req);
    if (!wellFormed(p)) { res.status(403).send("invalid"); return; }
    const platform = platformOf(p);
    if (!platform) { console.warn("[offerwall] Pubscale : signature invalide"); res.status(403).send("bad signature"); return; }
    const token = p["token"].trim();
    const uid = p["user_id"].trim();

    try {
      const cfg = await loadConfig();
      const ip = String(req.headers["x-forwarded-for"] ?? req.ip ?? "").split(",")[0].trim();
      if (cfg.enforceIp && !PUBSCALE_IPS.has(ip)) { console.warn("[offerwall] Pubscale : adresse inattendue", ip); res.status(403).send("forbidden"); return; }

      // adresse de test du tableau de bord : on y ajoute « sandbox=1 » ; ces conversions ne sont créditées que pour les comptes de test déclarés
      // dans OFFERWALL_SANDBOX_UIDS (functions/.env), comme pour ayeT
      const sandbox = p["sandbox"] === "1";
      const testers = new Set((process.env.OFFERWALL_SANDBOX_UIDS ?? "").split(",").map((x) => x.trim()).filter(Boolean));
      if (sandbox && !testers.has(uid)) { console.log("[offerwall] Pubscale : conversion de test ignorée"); res.status(200).send("OK"); return; }

      const now = Date.now();
      const evRef = db.collection("OfferwallEvents").doc(eventId("pubscale", token));
      if ((await evRef.get()).exists) { res.status(200).send("OK"); return; } // relance : déjà traité

      const userRef = db.collection("Users").doc(uid);
      if (!(await userRef.get()).exists) { console.warn("[offerwall] Pubscale : utilisateur inconnu"); res.status(403).send("unknown user"); return; }

      const parsed = parseCoins(p["value"], cfg.maxCoinsPerEvent);
      const base = { provider: "pubscale", platform, requestId: token, userId: uid, ...(sandbox ? { sandbox: true } : {}) };
      if (!parsed.ok) {
        await evRef.set({ ...base, status: "refusee", reason: parsed.reason, rawCurrency: p["value"].slice(0, 32), createdAt: now, updatedAt: now }).catch(() => undefined);
        res.status(200).send("OK"); // un montant inutilisable ne doit pas être relancé
        return;
      }

      const sponsorId = await sponsorOf(uid);
      const split = splitCoins(parsed.coins, cfg.sponsorPct, !!sponsorId);
      const days = lastSevenDays(now);
      const dailySnaps = await db.getAll(...days.map((d) => db.collection("OfferwallDaily").doc(`${uid}_${d}`)));
      const coinsOf = (i: number): number => Number(dailySnaps[i].data()?.["coins"] ?? 0) || 0;
      const today = coinsOf(0);
      const week = dailySnaps.reduce((s, _x, i) => s + coinsOf(i), 0);
      const reviewReason = capDecision(today, week, parsed.coins, cfg) !== "ok" ? "plafond dépassé" : null;

      await db.runTransaction(async (tx) => {
        if ((await tx.get(evRef)).exists) return; // deux relances en même temps : une seule passe
        tx.create(evRef, {
          ...base, coins: split.user, sponsorId: sponsorId ?? null, sponsorCoins: split.sponsor, studioCoins: split.studio,
          status: reviewReason ? "en_revue" : "pending", reviewReason,
          releaseAt: now + (sandbox ? 120_000 : cfg.holdHours * 3_600_000), createdAt: now, updatedAt: now, day: dayOf(now),
        });
        tx.set(db.collection("OfferwallDaily").doc(`${uid}_${dayOf(now)}`), { userId: uid, day: dayOf(now), coins: FieldValue.increment(split.user), updatedAt: now }, { merge: true });
        tx.update(userRef, { offerwallPendingCoins: FieldValue.increment(split.user) });
      });
      console.log(`[offerwall] Pubscale ${platform} : ${split.user} pièces en attente (${reviewReason ?? "ok"})`);
      res.status(200).send("OK");
    } catch (e) {
      console.error("[offerwall] Pubscale : erreur de traitement", e);
      res.status(500).send("retry"); // Pubscale réessaie 6 fois ; l'identifiant d'événement empêche tout doublon
    }
  },
);

// ─── Annulation ───
export const pubscaleChargebackCallback = onRequest(
  { region: "us-central1", timeoutSeconds: 15, memory: "256MiB", maxInstances: 10, secrets: [PS_ANDROID, PS_IOS] },
  async (req, res) => {
    res.set("Content-Type", "text/plain; charset=utf-8");
    if (req.method !== "GET") { res.status(405).send("Method Not Allowed"); return; }
    const p = readParams(req);
    if (!wellFormed(p)) { res.status(403).send("invalid"); return; }
    if (!platformOf(p)) { console.warn("[offerwall] Pubscale (annulation) : signature invalide"); res.status(403).send("bad signature"); return; }
    const token = p["token"].trim();
    const uid = p["user_id"].trim();

    try {
      const cfg = await loadConfig();
      const ip = String(req.headers["x-forwarded-for"] ?? req.ip ?? "").split(",")[0].trim();
      if (cfg.enforceIp && !PUBSCALE_IPS.has(ip)) { console.warn("[offerwall] Pubscale (annulation) : adresse inattendue", ip); res.status(403).send("forbidden"); return; }

      const now = Date.now();
      const origRef = db.collection("OfferwallEvents").doc(eventId("pubscale", token));
      const userRef = db.collection("Users").doc(uid);
      const outcome = await db.runTransaction(async (tx) => {
        // toutes les lectures AVANT les écritures (transaction Firestore)
        const o = await tx.get(origRef);
        if (!o.exists) return "inconnue"; // le jeton d'une annulation est supposé identique à celui de la conversion : à confirmer au premier cas réel
        const e = o.data() ?? {};
        const sponsorId = (e["sponsorId"] as string | null) ?? null;
        const u = await tx.get(userRef);
        const sponsorRef = sponsorId ? db.collection("Users").doc(sponsorId) : null;
        const sp = sponsorRef ? await tx.get(sponsorRef) : null;
        const st = String(e["status"] ?? "");
        const coins = Math.floor(Number(e["coins"]) || 0);
        if (st === "annulee") return "deja";
        if (st === "pending" || st === "en_revue") {
          // pièces encore en attente : on les retire, rien n'a été versé (ni parrain, ni commission)
          tx.update(origRef, { status: "annulee", cancelledAt: now, updatedAt: now });
          if (u.exists) tx.update(userRef, { offerwallPendingCoins: FieldValue.increment(-coins) });
          return "retiree";
        }
        if (st === "validee") {
          // même principe que pour ayeT : on défait tout ce que la tâche a payé, une transaction par personne ; le manque devient une dette
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
          reverseAppCommission(tx, "offres_pubscale", studioCoins, now);
          tx.update(origRef, {
            status: "annulee", cancelledAt: now, cancelledAfterValidation: true, updatedAt: now,
            takenBack: uTake.taken, debtCoins: uTake.debt, sponsorTakenBack: sTake.taken, sponsorDebtCoins: sTake.debt, appReversedCoins: studioCoins,
          });
          return "reprise";
        }
        return "sans_suite"; // refusée, expirée…
      });
      console.log(`[offerwall] Pubscale annulation : ${outcome}`);
      res.status(200).send("OK");
    } catch (e) {
      console.error("[offerwall] Pubscale (annulation) : erreur de traitement", e);
      res.status(500).send("retry");
    }
  },
);
