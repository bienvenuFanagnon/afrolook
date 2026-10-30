import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db } from "../shared/firebase";
import { dayOf, readOfferwallConfig } from "./offerwall_logic";
import { adTaskHundredths, readAdTaskConfig } from "./adTask_logic";

/**
 * Historique des tâches de l'utilisateur connecté (page « Tâches » de l'application). Lecture seule : il ne voit QUE ses propres événements
 * (la collection OfferwallEvents est fermée aux clients), sans identifiant de régie ni détail de répartition.
 * Retourne aussi les réglages utiles à l'écran (interrupteurs par plateforme, délai d'attente, plafond du jour).
 */
export const offerwallMyHistory = onCall({ region: "us-central1", timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Connexion requise.");
  const [cfgSnap, adCfgSnap, adStSnap, evSnap, userSnap] = await Promise.all([
    db.collection("AppConfig").doc("offerwall").get(),
    db.collection("AppConfig").doc("adTask").get(),
    db.collection("AdTaskState").doc(uid).get(),
    db.collection("OfferwallEvents").where("userId", "==", uid).limit(100).get(),
    db.collection("Users").doc(uid).get(),
  ]);
  const cfg = readOfferwallConfig(cfgSnap.data());
  const num = (v: unknown): number => (typeof v === "number" && Number.isFinite(v) ? v : Number(v) || 0);
  const events = evSnap.docs
    .map((d) => {
      const e = d.data();
      return { id: d.id, provider: String(e["provider"] ?? ""), platform: String(e["platform"] ?? ""), status: String(e["status"] ?? ""), coins: Math.floor(num(e["coins"])), createdAt: num(e["createdAt"]), releaseAt: num(e["releaseAt"]), validatedAt: num(e["validatedAt"]) };
    })
    .filter((e) => e.coins > 0)
    .sort((a, b) => b.createdAt - a.createdAt)
    .slice(0, 50);
  const u = userSnap.data() ?? {};
  const adCfg = readAdTaskConfig(adCfgSnap.data());
  const adSt = adStSnap.data() ?? {};
  return {
    // tâche « Regarder une pub » : réglages et nombre de pubs déjà regardées aujourd'hui
    adTask: { enabled: adCfg.enabled, maxPerDay: adCfg.maxPerDay, doneToday: adSt["day"] === dayOf(Date.now()) ? Math.max(0, Math.floor(Number(adSt["count"]) || 0)) : 0, hundredths: adTaskHundredths(adCfg.ecpmEur), gapSec: adCfg.gapSec },
    events,
    earned: Math.max(0, Math.floor(num(u["totalOfferwallCoinsEarned"]))),
    pending: Math.max(0, Math.floor(num(u["offerwallPendingCoins"]))),
    blocked: u["offerwallBlocked"] === true,
    config: { enabled: cfg.enabled, androidEnabled: cfg.androidEnabled, iosEnabled: cfg.iosEnabled, holdHours: cfg.holdHours, dailyCapCoins: cfg.dailyCapCoins, sponsorPct: cfg.sponsorPct },
  };
});
