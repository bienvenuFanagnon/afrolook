/**
 * scoreEngine.ts
 * – CRON toutes les 6h : calcule postScore pour les posts récents,
 *   puis agrège creatorScore et canalScore.
 * – reportPost (callable) : applique la pénalité de signalement sur postScore.
 *   Utilisateur normal → -5 pts ; Admin → × 0.10 (−90 %).
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";

const POSTS_COLLECTION = "Posts";
const USERS_COLLECTION = "Users";
const CANAUX_COLLECTION = "Canaux";
const MAX_AGE_DAYS = 30; // ne recalcule que les posts < 30 jours
const SNAPSHOT_SIZE = 30; // top N posts pour l'agrégation créateur/canal

// ─── Helpers ────────────────────────────────────────────────────────────────

function ageDays(createdAtMs: number): number {
  return (Date.now() - createdAtMs) / 86_400_000;
}

function decayedScore(rawScore: number, createdAtMs: number): number {
  const age = ageDays(createdAtMs);
  return rawScore / Math.pow(age + 2, 1.5);
}

// ─── CRON toutes les 6h ─────────────────────────────────────────────────────

export const computePostScores = onSchedule(
  { schedule: "every 6 hours", region: "europe-west1" },
  async () => {
    const cutoff = Date.now() - MAX_AGE_DAYS * 86_400_000;

    // 1. Recalculer postScore pour les posts récents
    // rawScore est calculé ici depuis les compteurs existants (likes, loves, comments)
    const postSnap = await db
      .collection(POSTS_COLLECTION)
      .where("created_at", ">=", cutoff)
      .select("likes", "loves", "comments", "created_at", "user_id", "canal_id")
      .get();

    const batch = db.batch();
    const creatorAccum: Record<string, number[]> = {};
    const canalAccum: Record<string, number[]> = {};

    for (const doc of postSnap.docs) {
      const data = doc.data();
      // rawScore = likes*1 + loves*2 + comments*3
      const raw: number =
        (data.likes ?? 0) * 1 +
        (data.loves ?? 0) * 2 +
        (data.comments ?? 0) * 3;
      const createdAt: number = data.created_at ?? Date.now();
      const score = decayedScore(raw, createdAt);

      batch.update(doc.ref, { rawScore: raw, postScore: score });

      const uid: string | null = data.user_id ?? null;
      if (uid) {
        creatorAccum[uid] = creatorAccum[uid] ?? [];
        creatorAccum[uid].push(score);
      }

      const cid: string | null = data.canal_id ?? null;
      if (cid && cid !== "") {
        canalAccum[cid] = canalAccum[cid] ?? [];
        canalAccum[cid].push(score);
      }
    }

    await batch.commit();

    // 2. Agréger creatorScore
    const creatorBatch = db.batch();
    for (const [uid, scores] of Object.entries(creatorAccum)) {
      const top = scores
        .sort((a, b) => b - a)
        .slice(0, SNAPSHOT_SIZE);
      const avg = top.reduce((s, v) => s + v, 0) / (top.length || 1);
      creatorBatch.update(db.collection(USERS_COLLECTION).doc(uid), {
        creatorScore: Math.round(avg * 100) / 100,
      });
    }
    await creatorBatch.commit();

    // 3. Agréger canalScore
    const canalBatch = db.batch();
    for (const [cid, scores] of Object.entries(canalAccum)) {
      const top = scores
        .sort((a, b) => b - a)
        .slice(0, SNAPSHOT_SIZE);
      const avg = top.reduce((s, v) => s + v, 0) / (top.length || 1);
      canalBatch.update(db.collection(CANAUX_COLLECTION).doc(cid), {
        canalScore: Math.round(avg * 100) / 100,
      });
    }
    await canalBatch.commit();

    console.log(
      `[scoreEngine] Posts mis à jour : ${postSnap.size} | ` +
      `Créateurs : ${Object.keys(creatorAccum).length} | ` +
      `Canaux : ${Object.keys(canalAccum).length}`
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

    const currentScore: number = (data.postScore as number) ?? 0;
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
