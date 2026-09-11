/**
 * Migration : peuple Canal.categories depuis les Posts existants.
 * Pour chaque Post avec canal_id + typeTabbar, fait arrayUnion([typeTabbar])
 * sur le document Canaux/{canal_id}.
 *
 * Lance avec : node functions/scripts/backfill_canal_categories.js
 * Nécessite  : firebase login (Application Default Credentials)
 */

const admin = require("firebase-admin");

const PROJECT_ID     = "afrolooki";
const READ_PAGE_SIZE = 200;
const DRY_RUN        = false;

async function main() {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: PROJECT_ID,
  });

  const db = admin.firestore();
  console.log(`🔄 Backfill Canal.categories — DRY_RUN=${DRY_RUN}`);

  // Accumule les catégories par canal_id avant d'écrire
  // canal_id → Set<typeTabbar>
  const canalCategories = new Map();

  let totalPosts   = 0;
  let skipped      = 0;
  let lastDocId    = null;
  let page         = 0;

  // ── Lecture de tous les Posts ───────────────────────────────────────────
  while (true) {
    page++;
    let query = db.collection("Posts")
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(READ_PAGE_SIZE);
    if (lastDocId) query = query.startAfter(lastDocId);

    const snap = await query.get();
    if (snap.empty) break;

    lastDocId = snap.docs[snap.docs.length - 1].id;
    console.log(`📄 Page ${page} — ${snap.docs.length} posts`);

    for (const doc of snap.docs) {
      totalPosts++;
      const data = doc.data();
      const canalId   = data.canal_id;
      const typeTabbar = data.typeTabbar;

      if (typeof canalId !== "string" || canalId.length === 0) { skipped++; continue; }
      if (typeof typeTabbar !== "string" || typeTabbar.length === 0) { skipped++; continue; }

      if (!canalCategories.has(canalId)) canalCategories.set(canalId, new Set());
      canalCategories.get(canalId).add(typeTabbar);
    }

    if (snap.docs.length < READ_PAGE_SIZE) break;
  }

  console.log(`\n📊 ${totalPosts} posts lus, ${skipped} ignorés (sans canal_id ou typeTabbar)`);
  console.log(`📺 ${canalCategories.size} canaux à mettre à jour`);

  // ── Écriture par batch de 500 ops max ──────────────────────────────────
  let totalUpdated = 0;
  let totalErrors  = 0;
  let batch        = db.batch();
  let batchCount   = 0;

  for (const [canalId, categories] of canalCategories.entries()) {
    const cats = Array.from(categories);
    console.log(`  🔧 canal=${canalId.slice(0, 8)} → categories=[${cats.join(", ")}]`);

    if (!DRY_RUN) {
      batch.update(db.collection("Canaux").doc(canalId), {
        categories: admin.firestore.FieldValue.arrayUnion(...cats),
      });
      batchCount++;
      totalUpdated++;

      if (batchCount >= 450) {
        try {
          await batch.commit();
          console.log(`  ✅ Batch commité (${batchCount} canaux)`);
        } catch (e) {
          totalErrors++;
          console.error(`  ⚠️ Erreur batch: ${e.message}`);
        }
        batch = db.batch();
        batchCount = 0;
      }
    } else {
      totalUpdated++;
    }
  }

  if (!DRY_RUN && batchCount > 0) {
    try {
      await batch.commit();
      console.log(`  ✅ Batch final commité (${batchCount} canaux)`);
    } catch (e) {
      totalErrors++;
      console.error(`  ⚠️ Erreur batch final: ${e.message}`);
    }
  }

  console.log(`\n🏁 Migration terminée`);
  console.log(`   Posts traités  : ${totalPosts}`);
  console.log(`   Canaux mis à jour: ${totalUpdated}`);
  console.log(`   Erreurs        : ${totalErrors}`);
  if (DRY_RUN) {
    console.log(`\n⚠️  DRY_RUN=true — aucune écriture. Passer DRY_RUN=false pour appliquer.`);
  }
}

main().catch(err => {
  console.error("💥 Erreur fatale:", err);
  process.exit(1);
});
