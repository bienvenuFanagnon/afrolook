/**
 * Recalcule creatorScore et canalScore pour TOUS les créateurs/canaux actifs.
 *
 * Étapes :
 *  1. Lit les posts des 90 derniers jours (fenêtre large pour couvrir les inactifs récents).
 *  2. Pour les posts dont postScore est NaN / nul, recalcule postScore avec la formule
 *     (loves*2 + comments*3 + totalInteractions*0.5) / (ageDays + 2)^1.5
 *  3. Regroupe par créateur et par canal → moyenne des top-30 scores.
 *  4. Met à jour Users.creatorScore et Canaux.canalScore.
 *
 * Lance avec : node functions/scripts/backfill_creator_canal_scores.js
 * Nécessite  : firebase login (Application Default Credentials)
 */

const admin = require("firebase-admin");

const PROJECT_ID    = "afrolooki";
const DAYS_BACK     = 90;
const SNAPSHOT_SIZE = 30;
const BATCH_SIZE    = 400;
const DRY_RUN       = false;

async function main() {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: PROJECT_ID,
  });

  const db = admin.firestore();

  // Flutter stocke created_at en microsecondes
  const cutoffMs     = Date.now() - DAYS_BACK * 86_400_000;
  const cutoffMicros = cutoffMs * 1000;
  const nowMs        = Date.now();

  console.log(`\n🔄 Backfill creatorScore/canalScore — ${DAYS_BACK} derniers jours`);
  console.log(`   DRY_RUN=${DRY_RUN}\n`);

  // ─── 1. Lire tous les posts récents ────────────────────────────────────────
  const postSnap = await db
    .collection("Posts")
    .where("created_at", ">=", cutoffMicros)
    .select("loves", "comments", "totalInteractions", "created_at",
            "postScore", "user_id", "canal_id")
    .get();

  console.log(`📦 ${postSnap.size} posts trouvés\n`);

  const creatorAccum = {}; // uid → { [postId]: score }
  const canalAccum   = {}; // cid → { [postId]: score }

  let fixedPostScores = 0;
  let postBatch       = db.batch();
  let postBatchCount  = 0;

  for (const doc of postSnap.docs) {
    const data = doc.data();

    const loves             = data.loves             ?? 0;
    const comments          = data.comments          ?? 0;
    const totalInteractions = data.totalInteractions ?? 0;
    const createdAtRaw      = data.created_at        ?? (nowMs * 1000);

    // Conversion microsecondes → millisecondes
    const createdMs = createdAtRaw > 1e13 ? createdAtRaw / 1000 : createdAtRaw;
    const diffMs    = nowMs - createdMs;
    const ageDays   = Number.isFinite(diffMs) ? Math.max(0, diffMs / 86_400_000) : 0;

    const raw   = loves * 2 + comments * 3 + totalInteractions * 0.5;
    const score = Math.round((raw / Math.pow(ageDays + 2, 1.5)) * 100) / 100;

    const existingScore = data.postScore;
    const needsFix = existingScore === null
      || existingScore === undefined
      || typeof existingScore !== "number"
      || isNaN(existingScore)
      || !isFinite(existingScore);

    if (needsFix) {
      if (!DRY_RUN) {
        postBatch.update(doc.ref, { postScore: score, rawScore: raw });
        postBatchCount++;
        if (postBatchCount >= BATCH_SIZE) {
          await postBatch.commit();
          postBatch      = db.batch();
          postBatchCount = 0;
        }
      }
      fixedPostScores++;
    }

    const finalScore = needsFix ? score : existingScore;

    // Accumuler
    const uid = data.user_id ?? null;
    if (uid) {
      creatorAccum[uid] = creatorAccum[uid] ?? {};
      creatorAccum[uid][doc.id] = finalScore;
    }

    const cid = (data.canal_id ?? "").trim();
    if (cid) {
      canalAccum[cid] = canalAccum[cid] ?? {};
      canalAccum[cid][doc.id] = finalScore;
    }
  }

  if (postBatchCount > 0 && !DRY_RUN) await postBatch.commit();
  console.log(`🛠️  ${fixedPostScores} postScores NaN/nuls corrigés\n`);

  // ─── 2. Agréger creatorScore ───────────────────────────────────────────────
  console.log(`👤 ${Object.keys(creatorAccum).length} créateurs à mettre à jour...`);

  let cBatch = db.batch();
  let cCount = 0;

  for (const [uid, scoreMap] of Object.entries(creatorAccum)) {
    const scores    = Object.values(scoreMap).filter(s => Number.isFinite(s));
    const top       = scores.sort((a, b) => b - a).slice(0, SNAPSHOT_SIZE);
    const avg       = top.length > 0 ? top.reduce((s, v) => s + v, 0) / top.length : 0;
    const creatorScore = Math.round(avg * 100) / 100;

    cBatch.update(db.collection("Users").doc(uid), { creatorScore });
    cCount++;

    if (cCount >= BATCH_SIZE) {
      if (!DRY_RUN) await cBatch.commit();
      cBatch = db.batch();
      cCount = 0;
    }
  }
  if (cCount > 0 && !DRY_RUN) await cBatch.commit();
  console.log(`   ✅ ${Object.keys(creatorAccum).length} créateurs mis à jour\n`);

  // ─── 3. Agréger canalScore ────────────────────────────────────────────────
  console.log(`📡 ${Object.keys(canalAccum).length} canaux à mettre à jour...`);

  let kBatch = db.batch();
  let kCount = 0;

  for (const [cid, scoreMap] of Object.entries(canalAccum)) {
    const scores    = Object.values(scoreMap).filter(s => Number.isFinite(s));
    const top       = scores.sort((a, b) => b - a).slice(0, SNAPSHOT_SIZE);
    const avg       = top.length > 0 ? top.reduce((s, v) => s + v, 0) / top.length : 0;
    const canalScore = Math.round(avg * 100) / 100;

    kBatch.update(db.collection("Canaux").doc(cid), { canalScore });
    kCount++;

    if (kCount >= BATCH_SIZE) {
      if (!DRY_RUN) await kBatch.commit();
      kBatch = db.batch();
      kCount = 0;
    }
  }
  if (kCount > 0 && !DRY_RUN) await kBatch.commit();
  console.log(`   ✅ ${Object.keys(canalAccum).length} canaux mis à jour\n`);

  console.log("🎉 Backfill creatorScore/canalScore terminé !");
}

main().catch((err) => {
  console.error("❌ Erreur fatale :", err);
  process.exit(1);
});
