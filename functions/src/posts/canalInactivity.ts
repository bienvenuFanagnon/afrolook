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

async function notifyOwner(ownerId: string, canalId: string, titre: string, description: string) {
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

/** Chaque publication d'un canal remet le compteur d'inactivité à zéro (et refuse une publication sur un canal bloqué). */
export const onCanalPostCreated = onDocumentCreated("Posts/{postId}", async (event) => {
  const post = event.data?.data();
  const canalId = post?.["canal_id"] as string | undefined;
  if (!post || !canalId) return;
  const canalRef = db.collection("Canaux").doc(canalId);
  const canal = await canalRef.get();
  if (!canal.exists) return;
  if (canal.get("isBlocked") === true) {
    // Canal bloqué : la publication est refusée côté serveur (l'app le masque déjà)
    await event.data!.ref.delete();
    return;
  }
  await canalRef.update({ lastPostAt: Date.now(), inactivityWarnedAt: FieldValue.delete() });
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
          const posts = await db.collection("Posts").where("canal_id", "==", doc.id).limit(500).get();
          for (const p of posts.docs) last = Math.max(last, toMs(p.get("created_at")), toMs(p.get("createdAt")));
          if (!last) last = toMs(c["createdAt"]) || now;
          // Jamais de blocage immédiat pour un canal découvert aujourd'hui : 20 jours pleins à partir de la dernière activité connue
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
    recordAppCommission(tx, "canaux", cost, now);
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
