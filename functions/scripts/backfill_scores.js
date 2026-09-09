/**
 * Backfill postScore / rawScore pour les posts des N derniers jours.
 * Recalcule aussi creatorScore et canalScore pour les créateurs/canaux affectés.
 *
 * Formule : raw = loves*2 + comments*3 + totalInteractions*0.5
 *           score = raw / (ageDays + 2)^1.5
 *
 * Lance avec : node functions/scripts/backfill_scores.js
 * Nécessite  : firebase login (Application Default Credentials)
 */

const admin = require("firebase-admin");

const PROJECT_ID    = "afrolooki";
const DAYS_BACK     = 14;
const BATCH_SIZE    = 400;
const SNAPSHOT_SIZE = 30; // top N posts pour agréger creatorScore/canalScore
const DRY_RUN       = false; // passer à true pour simuler sans écrire

async function main() {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: PROJECT_ID,
  });

  const db = admin.firestore();

  // Flutter stocke created_at en microsecondes
  const cutoffMs     = Date.now() - DAYS_BACK * 86_400_000;
  const cutoffMicros = cutoffMs * 1000;

  console.log(`\n🔄 Backfill scores — ${DAYS_BACK} derniers jours (cutoff : ${new Date(cutoffMs).toISOString()})`);
  console.log(`   DRY_RUN=${DRY_RUN}\n`);

  // ─── 1. Lire tous les posts récents ───────────────────────────────────────
  const postSnap = await db
    .collection("Posts")
    .where("created_at", ">=", cutoffMicros)
    .select("loves", "comments", "totalInteractions", "created_at",
            "postScore", "rawScore", "user_id", "canal_id")
    .get();

  console.log(`📦 ${postSnap.size} posts trouvés\n`);

  let updated  = 0;
  let skipped  = 0;
  let errors   = 0;

  const nowMs = Date.now();

  // Accumulateurs pour créateur/canal
  const creatorAccum = {}; // uid → { [postId]: score }
  const canalAccum   = {}; // cid → { [postId]: score }

  // ─── 2. Recalculer et écrire par lots ────────────────────────────────────
  let batch      = db.batch();
  let batchCount = 0;

  const commitBatch = async () => {
    if (batchCount === 0) return;
    if (!DRY_RUN) await batch.commit();
    batch      = db.batch();
    batchCount = 0;
  };

  for (const doc of postSnap.docs) {
    const data = doc.data();

    const loves             = data.loves             ?? 0;
    const comments          = data.comments          ?? 0;
    const totalInteractions = data.totalInteractions ?? 0;
    const createdAt         = data.created_at        ?? (nowMs * 1000);

    // created_at est en microsecondes côté Flutter
    const createdMs = createdAt > 1e12 ? createdAt / 1000 : createdAt;
    const ageDays   = (nowMs - createdMs) / 86_400_000;

    const raw   = loves * 2 + comments * 3 + totalInteractions * 0.5;
    const score = Math.round((raw / Math.pow(ageDays + 2, 1.5)) * 100) / 100;

    const uid = data.user_id ?? null;
    const cid = data.canal_id ?? null;

    // Accumuler pour l'agrégation créateur/canal
    if (uid) {
      creatorAccum[uid] = creatorAccum[uid] ?? {};
      creatorAccum[uid][doc.id] = score;
    }
    if (cid && cid.trim() !== "") {
      canalAccum[cid] = canalAccum[cid] ?? {};
      canalAccum[cid][doc.id] = score;
    }

    // Sauter si inchangé
    if ((data.postScore ?? 0) === score && (data.rawScore ?? 0) === raw) {
      skipped++;
      continue;
    }

    batch.update(doc.ref, { rawScore: raw, postScore: score });
    batchCount++;
    updated++;

    if (batchCount >= BATCH_SIZE) await commitBatch();
  }
  await commitBatch();

  console.log(`✅ Posts : ${updated} mis à jour, ${skipped} inchangés, ${errors} erreurs\n`);

  // ─── 3. Agréger creatorScore ──────────────────────────────────────────────
  console.log(`👤 Mise à jour creatorScore pour ${Object.keys(creatorAccum).length} créateurs...`);

  let creatorBatch = db.batch();
  let cBatchCount  = 0;

  for (const [uid, postScores] of Object.entries(creatorAccum)) {
    // Charger les postScores des autres posts du créateur hors fenêtre 14j
    let allScores = Object.values(postScores);

    try {
      const extraSnap = await db
        .collection("Posts")
        .where("user_id", "==", uid)
        .where("created_at", "<", cutoffMicros)
        .orderBy("created_at", "desc")
        .limit(SNAPSHOT_SIZE)
        .select("postScore")
        .get();

      for (const d of extraSnap.docs) {
        allScores.push(d.data().postScore ?? 0);
      }
    } catch (_) {
      // index manquant ou autre — on utilise seulement les posts récents
    }

    const top = allScores.sort((a, b) => b - a).slice(0, SNAPSHOT_SIZE);
    const avg = top.reduce((s, v) => s + v, 0) / (top.length || 1);
    const creatorScore = Math.round(avg * 100) / 100;

    creatorBatch.update(db.collection("Users").doc(uid), { creatorScore });
    cBatchCount++;

    if (cBatchCount >= BATCH_SIZE) {
      if (!DRY_RUN) await creatorBatch.commit();
      creatorBatch = db.batch();
      cBatchCount  = 0;
    }
  }
  if (cBatchCount > 0 && !DRY_RUN) await creatorBatch.commit();

  console.log(`   ✅ ${Object.keys(creatorAccum).length} créateurs mis à jour\n`);

  // ─── 4. Agréger canalScore ────────────────────────────────────────────────
  console.log(`📡 Mise à jour canalScore pour ${Object.keys(canalAccum).length} canaux...`);

  let canalBatch  = db.batch();
  let caBatchCount = 0;

  for (const [cid, postScores] of Object.entries(canalAccum)) {
    let allScores = Object.values(postScores);

    try {
      const extraSnap = await db
        .collection("Posts")
        .where("canal_id", "==", cid)
        .where("created_at", "<", cutoffMicros)
        .orderBy("created_at", "desc")
        .limit(SNAPSHOT_SIZE)
        .select("postScore")
        .get();

      for (const d of extraSnap.docs) {
        allScores.push(d.data().postScore ?? 0);
      }
    } catch (_) {
      // index manquant ou autre — on utilise seulement les posts récents
    }

    const top = allScores.sort((a, b) => b - a).slice(0, SNAPSHOT_SIZE);
    const avg = top.reduce((s, v) => s + v, 0) / (top.length || 1);
    const canalScore = Math.round(avg * 100) / 100;

    canalBatch.update(db.collection("Canaux").doc(cid), { canalScore });
    caBatchCount++;

    if (caBatchCount >= BATCH_SIZE) {
      if (!DRY_RUN) await canalBatch.commit();
      canalBatch   = db.batch();
      caBatchCount = 0;
    }
  }
  if (caBatchCount > 0 && !DRY_RUN) await canalBatch.commit();

  console.log(`   ✅ ${Object.keys(canalAccum).length} canaux mis à jour\n`);
  console.log("🎉 Backfill terminé !");
}

main().catch((err) => {
  console.error("❌ Erreur fatale :", err);
  process.exit(1);
});
