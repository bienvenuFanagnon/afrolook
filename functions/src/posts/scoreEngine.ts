/**
 * scoreEngine.ts
 * – Trigger temps réel (onDocumentUpdated Posts) : recalcule postScore, creatorScore, canalScore
 *   à chaque changement de loves, comments ou totalInteractions sur un post.
 * – reportPost (callable) : applique la pénalité de signalement sur postScore.
 *   Utilisateur normal → -5 pts ; Admin → × 0.10 (−90 %).
 *
 * Formule postScore : raw = loves*2 + comments*3 + totalInteractions*0.5 ; score = raw / (ageDays+2)^1.5
 * Note : "likes" n'est jamais incrémenté côté Flutter — "loves" est utilisé pour les réactions.
 * totalInteractions : compteur global incrémenté à chaque vue/like/commentaire/favori/partage.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";

// ─── Recalcul en temps réel à chaque love ou commentaire ────────────────────

export const recalculateScoresOnInteraction = onDocumentUpdated(
  { document: "Posts/{postId}", region: "europe-west1" },
  async (event) => {
    if (!event.data) return;
    const before = event.data.before.data();
    const after  = event.data.after.data();

    // Déclencher si loves, comments ou totalInteractions ont changé
    const lovesChanged        = (before.loves             ?? 0) !== (after.loves             ?? 0);
    const commentsChanged     = (before.comments          ?? 0) !== (after.comments          ?? 0);
    const interactionsChanged = (before.totalInteractions ?? 0) !== (after.totalInteractions ?? 0);
    if (!lovesChanged && !commentsChanged && !interactionsChanged) return;

    const loves             = (after.loves             ?? 0) as number;
    const comments          = (after.comments          ?? 0) as number;
    const totalInteractions = (after.totalInteractions ?? 0) as number;
    // Flutter stocke created_at en microsecondes — convertir en ms pour le calcul
    const createdAtRaw = (after.created_at ?? Date.now()) as number;
    const createdAtMs  = createdAtRaw > 1e13 ? createdAtRaw / 1000 : createdAtRaw;
    const diffMs       = Date.now() - createdAtMs;
    const ageDays      = Number.isFinite(diffMs) ? Math.max(0, diffMs / 86_400_000) : 0;
    // loves*2 : réaction forte ; comments*3 : engagement le plus fort ;
    // totalInteractions*0.5 : vues, partages, favoris (poids léger pour éviter le double comptage)
    const raw   = loves * 2 + comments * 3 + totalInteractions * 0.5;
    const score = Math.round((raw / Math.pow(ageDays + 2, 1.5)) * 100) / 100;

    // Éviter une boucle infinie : ne pas mettre à jour si les valeurs sont déjà correctes
    if ((after.postScore ?? 0) === score && (after.rawScore ?? 0) === raw) return;

    await event.data!.after.ref.update({ rawScore: raw, postScore: score });

    // Propager vers creatorScore
    const uid = after.user_id as string | undefined;
    if (uid) {
      try {
        const creatorPosts = await db.collection(POSTS_COLLECTION)
          .where("user_id", "==", uid)
          .orderBy("created_at", "desc")
          .limit(SNAPSHOT_SIZE)
          .select("postScore")
          .get();
        const scores = creatorPosts.docs.map(d => (d.data().postScore ?? 0) as number);
        // Remplacer le score du post courant par la valeur fraîche
        const postId = event.params.postId;
        const idx = creatorPosts.docs.findIndex(d => d.id === postId);
        if (idx >= 0) scores[idx] = score;
        const avg = scores.reduce((a, b) => a + b, 0) / (scores.length || 1);
        await db.collection(USERS_COLLECTION).doc(uid).update({
          creatorScore: Math.round(avg * 100) / 100,
        });
      } catch (e) {
        console.error("[scoreEngine] creatorScore update failed:", e);
      }
    }

    // Propager vers canalScore
    const cid = after.canal_id as string | undefined;
    if (cid && cid.trim() !== "") {
      try {
        const canalPosts = await db.collection(POSTS_COLLECTION)
          .where("canal_id", "==", cid)
          .orderBy("created_at", "desc")
          .limit(SNAPSHOT_SIZE)
          .select("postScore")
          .get();
        const scores = canalPosts.docs.map(d => (d.data().postScore ?? 0) as number);
        const postId = event.params.postId;
        const idx = canalPosts.docs.findIndex(d => d.id === postId);
        if (idx >= 0) scores[idx] = score;
        const avg = scores.reduce((a, b) => a + b, 0) / (scores.length || 1);
        await db.collection(CANAUX_COLLECTION).doc(cid).update({
          canalScore: Math.round(avg * 100) / 100,
        });
      } catch (e) {
        console.error("[scoreEngine] canalScore update failed:", e);
      }
    }

    console.log(`[scoreEngine] Post ${event.params.postId} → postScore=${score} rawScore=${raw}`);
  }
);

const POSTS_COLLECTION  = "Posts";
const USERS_COLLECTION  = "Users";
const CANAUX_COLLECTION = "Canaux";
const SNAPSHOT_SIZE     = 30;   // top N posts pour l'agrégation créateur/canal
const DECAY_DAYS        = 90;   // inactivité totale après 90 jours → score plancher
const ACTIVITY_FLOOR    = 0.30; // score minimum (30%) même sans activité

// ─── CRON hebdomadaire : multiplicateur d'activité ──────────────────────────
// Lit les posts des 90 derniers jours, recalcule creatorScore avec le
// multiplicateur d'inactivité. ~5 000 lectures + ~200 écritures par semaine.

export const applyActivityDecay = onSchedule(
  { schedule: "every monday 04:00", region: "europe-west1", timeZone: "UTC" },
  async () => {
    const nowMs        = Date.now();
    const cutoffMicros = (nowMs - DECAY_DAYS * 86_400_000) * 1000;

    // 1. Lire les posts récents (90 jours) — select minimal pour limiter les coûts
    const postSnap = await db
      .collection(POSTS_COLLECTION)
      .where("created_at", ">=", cutoffMicros)
      .select("postScore", "user_id", "created_at")
      .get();

    // 2. Grouper par créateur : scores + date du post le plus récent
    const creatorData: Record<string, { scores: number[]; lastPostMs: number }> = {};

    for (const doc of postSnap.docs) {
      const data       = doc.data();
      const uid        = data.user_id as string | undefined;
      if (!uid) continue;

      const ps: number = data.postScore ?? 0;
      if (!Number.isFinite(ps)) continue;

      const createdRaw: number = data.created_at ?? 0;
      const createdMs          = createdRaw > 1e13 ? createdRaw / 1000 : createdRaw;

      if (!creatorData[uid]) creatorData[uid] = { scores: [], lastPostMs: 0 };
      creatorData[uid].scores.push(ps);
      if (createdMs > creatorData[uid].lastPostMs) creatorData[uid].lastPostMs = createdMs;
    }

    // 3. Calculer creatorScore pondéré et écrire en batch
    let batch    = db.batch();
    let count    = 0;
    let updated  = 0;

    for (const [uid, { scores, lastPostMs }] of Object.entries(creatorData)) {
      const top  = scores.sort((a, b) => b - a).slice(0, SNAPSHOT_SIZE);
      const base = top.reduce((s, v) => s + v, 0) / (top.length || 1);

      const daysSincePost  = Math.max(0, (nowMs - lastPostMs) / 86_400_000);
      const multiplier     = Math.max(ACTIVITY_FLOOR, 1 - daysSincePost / DECAY_DAYS);
      const creatorScore   = Math.round(base * multiplier * 100) / 100;

      batch.update(db.collection(USERS_COLLECTION).doc(uid), { creatorScore });
      count++;
      updated++;

      if (count >= 400) {
        await batch.commit();
        batch = db.batch();
        count = 0;
      }
    }
    if (count > 0) await batch.commit();

    console.log(
      `[activityDecay] ${updated} créateurs mis à jour sur ${postSnap.size} posts lus`
    );
  }
);

// ─── reportPost (callable) ──────────────────────────────────────────────────
// reportType: 'standard' | 'wrong_category'
// isAdminReport: true → pénalité admin (× 0.10 standard, × 0.05 wrong_category)
// Un utilisateur ne peut signaler qu'une seule fois par post (reporterIds guard).

export const reportPost = onCall(
  { region: "europe-west1" },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Connexion requise.");

    const {
      postId,
      isAdminReport = false,
      reportType = "standard",
    } = request.data as {
      postId: string;
      isAdminReport?: boolean;
      reportType?: "standard" | "wrong_category";
    };

    if (!postId) throw new HttpsError("invalid-argument", "postId manquant.");

    const postRef = db.collection(POSTS_COLLECTION).doc(postId);
    const postDoc = await postRef.get();
    if (!postDoc.exists) throw new HttpsError("not-found", "Post introuvable.");

    const data = postDoc.data()!;

    // Anti-abus : un seul signalement par utilisateur
    const reporterIds: string[] = data.reporterIds ?? [];
    if (!isAdminReport && reporterIds.includes(uid)) {
      throw new HttpsError("already-exists", "Tu as déjà signalé ce post.");
    }

    const rawScore = data.postScore as number;
    const currentScore: number = Number.isFinite(rawScore) ? rawScore : 0;
    const userId: string | null = data.user_id ?? null;
    const canalId: string | null = data.canal_id ?? null;

    let newPostScore: number;
    const updates: Record<string, unknown> = {
      status: "SIGNALER",
    };

    if (isAdminReport) {
      // Admin standard → −90 % ; admin wrong_category → −95 %
      const factor = reportType === "wrong_category" ? 0.05 : 0.10;
      newPostScore = Math.round(currentScore * factor * 100) / 100;
      updates.postScore = newPostScore;
      updates.adminSignaledAt = FieldValue.serverTimestamp();
      updates.adminSignaledBy = uid;
      if (reportType === "wrong_category") {
        updates.wrongCategoryFlaggedByAdmin = true;
      }
    } else {
      // Utilisateur standard → −5 pts ; wrong_category → −8 pts
      const penalty = reportType === "wrong_category" ? 8 : 5;
      newPostScore = Math.max(0, currentScore - penalty);
      updates.postScore = newPostScore;
      updates.reportCount = FieldValue.increment(1);
      updates.reporterIds = FieldValue.arrayUnion([uid]);
      if (reportType === "wrong_category") {
        updates.wrongCategoryCount = FieldValue.increment(1);
        updates.wrongCategoryReporterIds = FieldValue.arrayUnion([uid]);
      }
    }

    await postRef.update(updates);

    // Propager la pénalité vers creatorScore et canalScore
    const scoreDelta = newPostScore - currentScore; // toujours négatif
    if (scoreDelta < 0 && userId) {
      const creatorRef = db.collection(USERS_COLLECTION).doc(userId);
      const creatorDoc = await creatorRef.get();
      if (creatorDoc.exists) {
        const cs: number = (creatorDoc.data()!.creatorScore as number) ?? 0;
        await creatorRef.update({
          creatorScore: Math.max(0, Math.round((cs + scoreDelta * 0.3) * 100) / 100),
        });
      }
    }
    if (scoreDelta < 0 && canalId && canalId !== "") {
      const canalRef = db.collection(CANAUX_COLLECTION).doc(canalId);
      const canalDoc = await canalRef.get();
      if (canalDoc.exists) {
        const cs2: number = (canalDoc.data()!.canalScore as number) ?? 0;
        await canalRef.update({
          canalScore: Math.max(0, Math.round((cs2 + scoreDelta * 0.3) * 100) / 100),
        });
      }
    }

    return { success: true };
  }
);
