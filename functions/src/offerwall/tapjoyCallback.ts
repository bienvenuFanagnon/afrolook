import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { sponsorOf } from "../payments/coinShares";
import { MAX_LEN, loadConfig, str } from "./offerwall_shared";
import { capDecision, dayOf, eventId, lastSevenDays, parseCoins, safeEqualHex, splitCoins, tapjoyVerifier } from "./offerwall_logic";

/**
 * Retour serveur Tapjoy (voir docs/OFFERWALL_TACHES.md §0 bis, §8, §10 et §11) : GET signé (MD5 de « id:snuid:currency:clé secrète »).
 * Fichier à part : c'est le seul à déclarer des secrets (Secret Manager), pour que le reste du module se déploie sans eux.
 * Les pièces restent « en attente » 48 h (OfferwallEvents), puis offerwallRelease (offerwall.ts) les libère.
 */
const TJ_SECRET_ANDROID = defineSecret("TAPJOY_CALLBACK_SECRET_ANDROID");
const TJ_SECRET_IOS = defineSecret("TAPJOY_CALLBACK_SECRET_IOS");

/** Adresses sources de Tapjoy (documentation du 8 octobre 2026) : utilisées seulement si `enforceIp` est activé. */
const TAPJOY_IPS = new Set([
  "18.215.207.89", "18.235.142.165", "23.20.255.113", "23.23.134.165", "3.210.188.32", "3.215.42.140", "3.217.209.177", "3.218.95.35",
  "3.219.236.53", "3.231.137.161", "5.60.70.0", "5.60.70.1", "5.60.70.2", "5.60.70.3",
]);

export const tapjoyOfferwallCallback = onRequest(
  { region: "us-central1", timeoutSeconds: 15, memory: "256MiB", maxInstances: 10, secrets: [TJ_SECRET_ANDROID, TJ_SECRET_IOS] },
  async (req, res) => {
    res.set("Content-Type", "text/plain; charset=utf-8");
    if (req.method !== "GET") { res.status(405).send("Method Not Allowed"); return; }

    const id = str(req.query["id"]).trim();
    const snuid = str(req.query["snuid"]).trim();
    const currency = str(req.query["currency"]).trim();
    const verifier = str(req.query["verifier"]).trim().toLowerCase();
    // 403 pour tout ce qui n'est pas un vrai retour de la régie : Tapjoy ne réessaie pas
    if (!id || !snuid || !currency || !verifier || id.length > MAX_LEN || snuid.length > MAX_LEN || currency.length > 32 || snuid.includes("/")) { res.status(403).send("invalid"); return; }

    // 1. signature : l'application d'origine (Android ou iPhone) est reconnue par la clé qui valide la signature
    let platform: "android" | "ios" | null = null;
    for (const [p, secret] of [["android", TJ_SECRET_ANDROID.value()], ["ios", TJ_SECRET_IOS.value()]] as const) {
      if (secret && safeEqualHex(verifier, tapjoyVerifier(id, snuid, currency, secret))) { platform = p; break; }
    }
    if (!platform) { console.warn("[offerwall] signature invalide"); res.status(403).send("bad verifier"); return; }

    try {
      const cfg = await loadConfig();
      const ip = String(req.headers["x-forwarded-for"] ?? req.ip ?? "").split(",")[0].trim();
      if (cfg.enforceIp && !TAPJOY_IPS.has(ip)) { console.warn("[offerwall] adresse inattendue", ip); res.status(403).send("forbidden"); return; }

      const now = Date.now();
      const evRef = db.collection("OfferwallEvents").doc(eventId("tapjoy", id));
      if ((await evRef.get()).exists) { res.status(200).send("OK"); return; } // relance de la régie : déjà traité, rien à créditer

      const userRef = db.collection("Users").doc(snuid);
      const userSnap = await userRef.get();
      if (!userSnap.exists) { console.warn("[offerwall] utilisateur inconnu"); res.status(403).send("unknown user"); return; }

      const parsed = parseCoins(currency, cfg.maxCoinsPerEvent);
      if (!parsed.ok) {
        // montant négatif, nul ou aberrant : on garde une trace (sans rien créditer) et on répond 403 pour qu'il n'y ait pas de relance
        await evRef.set({ provider: "tapjoy", platform, userId: snuid, status: "refusee", reason: parsed.reason, rawCurrency: currency.slice(0, 32), requestId: id, createdAt: now, updatedAt: now }).catch(() => undefined);
        res.status(403).send(parsed.reason);
        return;
      }

      const sponsorId = await sponsorOf(snuid);
      const split = splitCoins(parsed.coins, cfg.sponsorPct, !!sponsorId);

      // plafonds (lecture des 7 derniers jours : les écarts de concurrence sont sans conséquence, la tâche passe « en revue », jamais refusée)
      const days = lastSevenDays(now);
      const dailySnaps = await db.getAll(...days.map((d) => db.collection("OfferwallDaily").doc(`${snuid}_${d}`)));
      const coinsOf = (i: number): number => Number(dailySnaps[i].data()?.["coins"] ?? 0) || 0;
      const today = coinsOf(0);
      const week = dailySnaps.reduce((s, _x, i) => s + coinsOf(i), 0);
      const decision = capDecision(today, week, parsed.coins, cfg);

      await db.runTransaction(async (tx) => {
        if ((await tx.get(evRef)).exists) return; // deux relances en même temps : une seule passe
        tx.create(evRef, {
          provider: "tapjoy", platform, requestId: id, userId: snuid,
          coins: split.user, sponsorId: sponsorId ?? null, sponsorCoins: split.sponsor, studioCoins: split.studio,
          status: decision === "ok" ? "pending" : "en_revue",
          reviewReason: decision === "ok" ? null : "plafond dépassé",
          releaseAt: now + cfg.holdHours * 3_600_000, createdAt: now, updatedAt: now, day: dayOf(now),
        });
        tx.set(db.collection("OfferwallDaily").doc(`${snuid}_${dayOf(now)}`), { userId: snuid, day: dayOf(now), coins: FieldValue.increment(split.user), updatedAt: now }, { merge: true });
        tx.update(userRef, { offerwallPendingCoins: FieldValue.increment(split.user) });
      });
      console.log(`[offerwall] tapjoy ${platform} : ${split.user} pièces en attente (${decision})`);
      res.status(200).send("OK");
    } catch (e) {
      // erreur temporaire : 500 → Tapjoy réessaie toutes les 5 minutes (jusqu'à 4 jours) ; l'identifiant d'événement empêche tout doublon
      console.error("[offerwall] erreur de traitement", e);
      res.status(500).send("retry");
    }
  },
);

