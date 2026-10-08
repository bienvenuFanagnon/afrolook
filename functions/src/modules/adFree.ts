import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { recordAppCommission } from "../payments/coinShares";

/**
 * Pass « sans pub » des modules Quiz, Étude et Contes : le lecteur paie en pièces et ne voit plus aucune pub passive
 * (bannières, pubs dans les listes, pubs plein écran de fin) dans ces modules pendant 30 jours.
 * Restent au choix du lecteur : les pubs avec récompense pour débloquer un contenu ou gagner un cœur.
 *
 * Réglages (AppConfig/modules, relus toutes les 60 s) : adFreePrice (pièces), adFreeDays, adFreeEnabled.
 * Prix par défaut : 500 pièces (≈ 300 FCFA si les pièces sont achetées). Calcul : un lecteur très actif rapporte au plus
 * ~300 pubs passives par mois (interstitiel ~2 $, native ~0,5 $, bannière ~0,15 $ pour 1000 affichages) ≈ 0,25 $ à 0,5 $,
 * soit 150 à 300 FCFA ; le pass doit coûter au moins autant pour rester gagnant même avec le lecteur le plus rentable.
 * À recaler avec le revenu réel par utilisateur (AdMob).
 *
 * Fin du pass : Users.modulesAdFreeUntil (ms), écrit par le serveur seulement (règles Firestore).
 */
const DAY = 86400000;
const num = (v: unknown, def: number) => (typeof v === "number" && Number.isFinite(v) ? v : def);

let cache: { at: number; price: number; days: number; enabled: boolean } | null = null;
async function loadCfg() {
  if (cache && Date.now() - cache.at < 60000) return cache;
  const d = (await db.collection("AppConfig").doc("modules").get()).data() ?? {};
  cache = {
    at: Date.now(),
    price: Math.max(1, Math.round(num(d["adFreePrice"], 500))),
    days: Math.max(1, Math.min(90, Math.round(num(d["adFreeDays"], 30)))),
    enabled: d["adFreeEnabled"] === undefined ? true : !!d["adFreeEnabled"],
  };
  return cache;
}

export const moduleAdFreeBuy = onCall({ timeoutSeconds: 20, maxInstances: 5 }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const cfg = await loadCfg();
  if (!cfg.enabled) throw new HttpsError("failed-precondition", "ADFREE_OFF");
  const now = Date.now();
  const userRef = db.collection("Users").doc(uid);
  const until = await db.runTransaction(async (tx) => {
    const us = await tx.get(userRef);
    if (!us.exists) throw new HttpsError("not-found", "Compte introuvable.");
    const balance = num(us.data()?.["giftCoinsBalance"], 0);
    if (balance < cfg.price) throw new HttpsError("resource-exhausted", "Solde de pièces insuffisant.", { coins: cfg.price, balance });
    const current = num(us.data()?.["modulesAdFreeUntil"], 0);
    // les achats s'ajoutent, mais jamais au-delà de 120 jours devant soi
    const next = Math.min(Math.max(now, current) + cfg.days * DAY, now + 120 * DAY);
    tx.update(userRef, {
      giftCoinsBalance: FieldValue.increment(-cfg.price),
      totalGiftCoinsSpent: FieldValue.increment(cfg.price),
      modulesAdFreeUntil: next,
      updatedAt: now,
    });
    const t = db.collection("TransactionSoldes").doc();
    tx.set(t, {
      id: t.id, user_id: uid, type: "DEPENSE", statut: "VALIDER",
      description: `Sans pub ${cfg.days} jours (Quiz, Étude, Contes) — ${cfg.price} pièces`,
      montant: cfg.price, frais: 0, montant_total: cfg.price, methode_paiement: "pieces", createdAt: now, updatedAt: now,
      purchaseKind: "modules_sans_pub", purchaseRefId: "modules_adfree",
    });
    recordAppCommission(tx, "deblocages", cfg.price, now);
    return next;
  });
  return { ok: true, until, price: cfg.price, days: cfg.days };
});
