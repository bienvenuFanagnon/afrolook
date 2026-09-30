import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldPath, FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { num, recordAppCommission } from "../payments/coinShares";

/**
 * Canaux inactifs : un canal sans aucune publication depuis 20 jours est BLOQUÉ.
 * Son propriétaire le débloque en pièces, selon le nombre d'abonnés :
 *   moins de 100 → 500 · moins de 2 000 → 1 500 · moins de 3 000 → 2 000 · au-delà → 3 000.
 * Un rappel est envoyé à partir de 15 jours d'inactivité.
 *
 * Champs écrits sur Canaux/{id} (jamais par l'app) :
 *   lastPostAt (ms), isBlocked, blockedAt (ms), blockReason, inactivityWarnedAt (ms), unlockedAt (ms).
 */

const DAY_MS = 24 * 60 * 60 * 1000;
export const CANAL_INACTIVE_DAYS = 20;
const WARN_DAYS = 15;
const GRACE_DAYS = 5; // délai de grâce des canaux découverts déjà inactifs

export function canalUnlockCost(followers: number): number {
  if (followers < 100) return 500;
  if (followers < 2000) return 1500;
  if (followers < 3000) return 2000;
  return 3000;
}

function followersOf(canal: FirebaseFirestore.DocumentData): number {
  const list = Array.isArray(canal["usersSuiviId"]) ? (canal["usersSuiviId"] as unknown[]).length : 0;
  return Math.max(list, num(canal["suivi"]));
}

/** created_at / createdAt sont en microsecondes côté Flutter. */
function toMs(v: unknown): number {
  const n = num(v);
  if (n <= 0) return 0;
  return n > 1e14 ? Math.floor(n / 1000) : n;
}

export async function notifyOwner(ownerId: string, canalId: string, titre: string, description: string) {
  const ref = db.collection("Notifications").doc();
  const nowMicros = Date.now() * 1000;
  await ref.set({
    id: ref.id, titre, description, type: "POST",
    user_id: "afrolook_system", receiver_id: ownerId, post_id: "", post_data_type: "",
    is_open: false, users_id_view: [],
    created_at: nowMicros, updated_at: nowMicros, createdAt: nowMicros, updatedAt: nowMicros,
    status: "VALIDE", canal_id: canalId,
  });
}

/**
 * Date de la dernière publication d'un canal ou d'un compte, sans index supplémentaire :
 * 1. requêtes triées (les index canal_id/user_id + created_at/createdAt existent déjà dans firestore.indexes.json) ;
 * 2. si un index manque (erreur), lecture par pages triées par identifiant (plafond de sécurité).
 * `complete = false` : résultat incertain (plafond atteint) → l'appelant ne doit JAMAIS bloquer sur cette base.
 */
async function latestPostMs(
  ownerField: "canal_id" | "user_id", id: string, opts: { excludePostId?: string; skipAds?: boolean } = {},
): Promise<{ ms: number; complete: boolean }> {
  let best = 0;
  let sorted = true;
  for (const tsField of ["created_at", "createdAt"]) {
    try {
      const snap = await db.collection("Posts").where(ownerField, "==", id).orderBy(tsField, "desc").limit(20).get();
      for (const p of snap.docs) {
        if (p.id === opts.excludePostId) continue;
        if (opts.skipAds && p.get("isAdvertisement") === true) continue;
        const ms = toMs(p.get(tsField));
        if (ms) { best = Math.max(best, ms); break; } // triés du plus récent au plus ancien : le premier valide suffit
      }
    } catch { sorted = false; }
  }
  if (sorted) return { ms: best, complete: true };

  // Repli : parcours par pages (sans index), plafonné
  const CAP = 4000;
  let scanned = 0;
  let cursor: string | null = null;
  best = 0;
  for (;;) {
    let q = db.collection("Posts").where(ownerField, "==", id).orderBy(FieldPath.documentId()).limit(500)
      .select("created_at", "createdAt", "isAdvertisement");
    if (cursor) q = q.startAfter(cursor);
    const page = await q.get();
    for (const p of page.docs) {
      cursor = p.id;
      if (p.id === opts.excludePostId) continue;
      if (opts.skipAds && p.get("isAdvertisement") === true) continue;
      best = Math.max(best, toMs(p.get("created_at")), toMs(p.get("createdAt")));
    }
    scanned += page.size;
    if (page.size < 500) return { ms: best, complete: true };
    if (scanned >= CAP) return { ms: best, complete: false };
  }
}

// ── Comptes : même règle que les canaux ───────────────────────────────────────────────────────
//
// Un compte qui a déjà publié puis reste 20 jours sans rien publier ne peut plus publier (profil ou canal),
// ni créer de canal, de groupe ou de live, tant qu'il n'est pas débloqué en pièces. L'état se déduit de
// Users.lastPostAt (aucun drapeau à maintenir) ; un déblocage remet lastPostAt à « maintenant ».
// Les comptes qui n'ont jamais publié et les administrateurs ne sont pas concernés.

export interface AccountStatus { blocked: boolean; daysInactive: number; followers: number; cost: number }

/** Dernière publication d'un compte : champ lastPostAt, sinon retrouvée une seule fois dans ses posts. */
async function lastPostOf(userId: string, userData: FirebaseFirestore.DocumentData, excludePostId?: string): Promise<number> {
  const known = toMs(userData["lastPostAt"]);
  if (known) return known;
  const found = await latestPostMs("user_id", userId, { excludePostId, skipAds: true });
  // Résultat incertain (compte avec énormément de posts) : on ne bloque jamais sur une base incomplète
  if (!found.complete) return Date.now();
  const last = found.ms;
  if (last) await db.collection("Users").doc(userId).update({ lastPostAt: last });
  return last;
}

export async function accountStatus(userId: string, excludePostId?: string): Promise<AccountStatus> {
  const doc = await db.collection("Users").doc(userId).get();
  const u = doc.data();
  if (!u || u["role"] === "ADM") return { blocked: false, daysInactive: 0, followers: 0, cost: 0 };
  const followers = Math.max(Array.isArray(u["userAbonnesIds"]) ? (u["userAbonnesIds"] as unknown[]).length : 0, num(u["abonnes"]));
  const last = await lastPostOf(userId, u, excludePostId);
  if (!last) return { blocked: false, daysInactive: 0, followers, cost: canalUnlockCost(followers) }; // n'a jamais publié
  const days = (Date.now() - last) / DAY_MS;
  return { blocked: days >= CANAL_INACTIVE_DAYS, daysInactive: Math.floor(days), followers, cost: canalUnlockCost(followers) };
}

/** Statut du compte connecté (affichage du blocage et du prix de déblocage). */
export const accountPublishStatus = onCall({ timeoutSeconds: 20, memory: "256MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  return accountStatus(uid);
});

/** Déblocage du compte connecté, payé en pièces (même barème que les canaux, selon ses abonnés). */
export const unlockAccount = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const st = await accountStatus(uid);
  if (!st.blocked) return { unlocked: false, reason: "not_blocked", coins: 0 };
  const userRef = db.collection("Users").doc(uid);
  return db.runTransaction(async (tx) => {
    const d = await tx.get(userRef);
    const balance = num(d.data()?.["giftCoinsBalance"]);
    if (balance < st.cost) throw new HttpsError("resource-exhausted", "Solde insuffisant", { balance, coins: st.cost });
    const now = Date.now();
    tx.update(userRef, {
      giftCoinsBalance: FieldValue.increment(-st.cost),
      totalGiftCoinsSpent: FieldValue.increment(st.cost),
      lastPostAt: now, accountUnlockedAt: now, updatedAt: now,
    });
    const t = db.collection("TransactionSoldes").doc();
    tx.set(t, {
      id: t.id, user_id: uid, type: "DEPENSE", statut: "VALIDER",
      description: `Déblocage du compte — ${st.cost} pièces`,
      montant: st.cost, frais: 0, montant_total: st.cost, methode_paiement: "pieces",
      createdAt: now, updatedAt: now, purchaseKind: "account_unlock",
    });
    recordAppCommission(tx, "deblocages", st.cost, now);
    return { unlocked: true, coins: st.cost };
  });
});

/**
 * Chaque publication : refusée (supprimée) si le compte est bloqué ou si le canal est bloqué ;
 * sinon remet à zéro le compteur d'inactivité du compte et du canal.
 */
export const onPostCreatedInactivity = onDocumentCreated("Posts/{postId}", async (event) => {
  const post = event.data?.data();
  if (!post) return;
  const userId = post["user_id"] as string | undefined;
  const canalId = post["canal_id"] as string | undefined;
  const isAd = post["isAdvertisement"] === true;

  if (userId && !isAd) {
    const st = await accountStatus(userId, event.params.postId);
    if (st.blocked) { await event.data!.ref.delete(); return; }
  }
  if (canalId) {
    const canalRef = db.collection("Canaux").doc(canalId);
    const canal = await canalRef.get();
    if (canal.exists) {
      if (canal.get("isBlocked") === true) { await event.data!.ref.delete(); return; }
      await canalRef.update({ lastPostAt: Date.now(), inactivityWarnedAt: FieldValue.delete() });
    }
  }
  if (userId && !isAd) await db.collection("Users").doc(userId).update({ lastPostAt: Date.now() });
});

/** Création d'un canal, d'un groupe ou d'un live par un compte bloqué : refusée côté serveur. */
async function refuseIfBlocked(ownerId: string | undefined, ref: FirebaseFirestore.DocumentReference) {
  if (!ownerId) return;
  const st = await accountStatus(ownerId);
  if (st.blocked) await ref.delete();
}
export const onCanalCreatedCheckAccount = onDocumentCreated("Canaux/{id}", async (event) => {
  await refuseIfBlocked(event.data?.get("userId") as string | undefined, event.data!.ref);
});
export const onGroupCreatedCheckAccount = onDocumentCreated("GroupChats/{id}", async (event) => {
  await refuseIfBlocked(event.data?.get("owner_id") as string | undefined, event.data!.ref);
});
export const onLiveCreatedCheckAccount = onDocumentCreated("lives/{id}", async (event) => {
  await refuseIfBlocked(event.data?.get("hostId") as string | undefined, event.data!.ref);
});

/** Chaque jour : rappel à 15 jours, blocage à 20 jours d'inactivité. */
export const checkInactiveCanals = onSchedule(
  { schedule: "every day 03:00", timeZone: "UTC", memory: "512MiB", timeoutSeconds: 540 },
  async () => {
    const now = Date.now();
    let cursor: string | null = null;
    let backfills = 0;
    let blocked = 0;
    for (;;) {
      let q = db.collection("Canaux").orderBy(FieldPath.documentId()).limit(300);
      if (cursor) q = q.startAfter(cursor);
      const page = await q.get();
      if (page.empty) break;
      for (const doc of page.docs) {
        cursor = doc.id;
        const c = doc.data();
        if (c["isBlocked"] === true) continue;

        let last = toMs(c["lastPostAt"]);
        if (!last) {
          // Canal créé avant ce suivi : dernière publication retrouvée une seule fois (max 200 canaux par jour)
          if (backfills >= 200) continue;
          backfills++;
          const found = await latestPostMs("canal_id", doc.id);
          if (!found.complete) { await doc.ref.update({ lastPostAt: now }); continue; } // incertain : jamais de blocage
          last = found.ms || toMs(c["createdAt"]) || now;
          // Délai de grâce : un canal découvert déjà inactif reçoit un rappel et dispose de 5 jours avant le blocage
          if ((now - last) / DAY_MS >= CANAL_INACTIVE_DAYS - GRACE_DAYS) last = now - (CANAL_INACTIVE_DAYS - GRACE_DAYS) * DAY_MS;
          await doc.ref.update({ lastPostAt: last });
        }

        const days = (now - last) / DAY_MS;
        const ownerId = c["userId"] as string | undefined;
        const titre = String(c["titre"] ?? "ton canal");
        if (days >= CANAL_INACTIVE_DAYS) {
          await doc.ref.update({ isBlocked: true, blockedAt: now, blockReason: "inactive" });
          blocked++;
          if (ownerId) {
            const cost = canalUnlockCost(followersOf(c));
            await notifyOwner(ownerId, doc.id, "🔒 Canal bloqué",
              `#${titre} est bloqué après ${CANAL_INACTIVE_DAYS} jours sans publication. Débloque-le avec ${cost} pièces depuis la page du canal.`);
          }
        } else if (days >= WARN_DAYS && !toMs(c["inactivityWarnedAt"]) && ownerId) {
          await doc.ref.update({ inactivityWarnedAt: now });
          await notifyOwner(ownerId, doc.id, "⚠️ Ton canal devient inactif",
            `#${titre} n'a rien publié depuis ${Math.floor(days)} jours. Publie avant ${CANAL_INACTIVE_DAYS} jours pour éviter le blocage.`);
        }
      }
      if (page.size < 300) break;
    }
    console.log(`[checkInactiveCanals] bloqués: ${blocked}, retrouvés: ${backfills}`);
  }
);

/** Déblocage d'un canal par son propriétaire, payé en pièces (montant selon les abonnés, calculé ici). */
export const unlockCanal = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const canalId = (request.data as { canalId?: string })?.canalId;
  if (!canalId) throw new HttpsError("invalid-argument", "canalId requis.");

  const canalRef = db.collection("Canaux").doc(canalId);
  const userRef = db.collection("Users").doc(uid);
  return db.runTransaction(async (tx) => {
    const [canalDoc, userDoc] = await Promise.all([tx.get(canalRef), tx.get(userRef)]);
    if (!canalDoc.exists) throw new HttpsError("not-found", "Canal introuvable.");
    const c = canalDoc.data()!;
    if (c["userId"] !== uid) throw new HttpsError("permission-denied", "Seul le propriétaire peut débloquer ce canal.");
    if (c["isBlocked"] !== true) return { unlocked: false, reason: "not_blocked", coins: 0 };
    if (!userDoc.exists) throw new HttpsError("not-found", "Compte introuvable.");

    const cost = canalUnlockCost(followersOf(c));
    const balance = num(userDoc.data()!["giftCoinsBalance"]);
    if (balance < cost) {
      throw new HttpsError("resource-exhausted", "Solde insuffisant", { balance, coins: cost });
    }
    const now = Date.now();
    tx.update(userRef, {
      giftCoinsBalance: FieldValue.increment(-cost),
      totalGiftCoinsSpent: FieldValue.increment(cost),
      updatedAt: now,
    });
    // Le compteur d'inactivité repart de zéro
    tx.update(canalRef, {
      isBlocked: false, unlockedAt: now, lastPostAt: now,
      inactivityWarnedAt: FieldValue.delete(), blockReason: FieldValue.delete(), blockedAt: FieldValue.delete(),
    });
    const t = db.collection("TransactionSoldes").doc();
    tx.set(t, {
      id: t.id, user_id: uid, type: "DEPENSE", statut: "VALIDER",
      description: `Déblocage du canal #${c["titre"] ?? ""} — ${cost} pièces`,
      montant: cost, frais: 0, montant_total: cost, methode_paiement: "pieces",
      createdAt: now, updatedAt: now, purchaseKind: "canal_unlock", purchaseRefId: canalId,
    });
    recordAppCommission(tx, "deblocages", cost, now);
    return { unlocked: true, coins: cost };
  });
});

/** Coût de déblocage courant d'un canal (pour l'affichage), sans rien modifier. */
export const canalUnlockQuote = onCall({ timeoutSeconds: 15, memory: "256MiB" }, async (request) => {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const canalId = (request.data as { canalId?: string })?.canalId;
  if (!canalId) throw new HttpsError("invalid-argument", "canalId requis.");
  const d = await db.collection("Canaux").doc(canalId).get();
  if (!d.exists) throw new HttpsError("not-found", "Canal introuvable.");
  const c = d.data()!;
  return { isBlocked: c["isBlocked"] === true, coins: canalUnlockCost(followersOf(c)), followers: followersOf(c) };
});

/** Chaque jour : rappel aux comptes créateurs qui approchent des 20 jours sans publication (à partir de 15 jours). */
export const warnInactiveAccounts = onSchedule(
  { schedule: "every day 03:30", timeZone: "UTC", memory: "512MiB", timeoutSeconds: 540 },
  async () => {
    const now = Date.now();
    const snap = await db.collection("Users")
      .where("lastPostAt", ">", now - CANAL_INACTIVE_DAYS * DAY_MS)
      .where("lastPostAt", "<=", now - WARN_DAYS * DAY_MS)
      .limit(1000).get();
    let warned = 0;
    for (const doc of snap.docs) {
      const u = doc.data();
      if (u["role"] === "ADM") continue;
      const last = toMs(u["lastPostAt"]);
      if (!last || toMs(u["inactivityWarnedFor"]) === last) continue; // déjà prévenu pour cette période d'inactivité
      const daysLeft = Math.max(1, Math.ceil(CANAL_INACTIVE_DAYS - (now - last) / DAY_MS));
      await doc.ref.update({ inactivityWarnedFor: last });
      await notifyOwner(doc.id, "", "⚠️ Ton compte devient inactif",
        `Tu n'as rien publié depuis ${Math.floor((now - last) / DAY_MS)} jours. Publie dans les ${daysLeft} prochains jours pour éviter le blocage de ton compte.`);
      warned++;
    }
    console.log(`[warnInactiveAccounts] rappels envoyés: ${warned}`);
  }
);

/**
 * Admin : revérifie les canaux bloqués pour inactivité avec la vraie date de dernière publication,
 * débloque (gratuitement) ceux qui ont publié dans les 20 derniers jours, et redonne 5 jours de grâce aux autres.
 * À lancer une seule fois par un administrateur (paramètre { dryRun: true } pour compter sans modifier).
 */
export const recheckBlockedCanals = onCall({ timeoutSeconds: 540, memory: "512MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const admin = await db.collection("Users").doc(uid).get();
  if (admin.data()?.["role"] !== "ADM") throw new HttpsError("permission-denied", "Réservé aux admins.");
  const dryRun = (request.data as { dryRun?: boolean })?.dryRun === true;
  const now = Date.now();
  let checked = 0, unblocked = 0, regrace = 0, uncertain = 0;
  const snap = await db.collection("Canaux").where("isBlocked", "==", true).get();
  for (const doc of snap.docs) {
    if (doc.get("blockReason") !== "inactive" || toMs(doc.get("unlockedAt")) > toMs(doc.get("blockedAt"))) continue;
    checked++;
    const found = await latestPostMs("canal_id", doc.id);
    const last = found.ms || toMs(doc.get("createdAt"));
    const recent = last && (now - last) / DAY_MS < CANAL_INACTIVE_DAYS;
    if (!found.complete || recent) {
      if (!found.complete) uncertain++; else unblocked++;
      if (!dryRun) await doc.ref.update({
        isBlocked: false, lastPostAt: found.complete ? last : now, inactivityWarnedAt: FieldValue.delete(),
        blockReason: FieldValue.delete(), blockedAt: FieldValue.delete(),
      });
    } else {
      // Réellement inactif : 5 jours de grâce à partir d'aujourd'hui au lieu d'un blocage sec
      regrace++;
      if (!dryRun) await doc.ref.update({
        isBlocked: false, lastPostAt: now - (CANAL_INACTIVE_DAYS - GRACE_DAYS) * DAY_MS,
        inactivityWarnedAt: FieldValue.delete(), blockReason: FieldValue.delete(), blockedAt: FieldValue.delete(),
      });
    }
  }
  return { dryRun, checked, unblocked, regrace, uncertain };
});
