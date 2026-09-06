/**
 * Migration : recalcule abonnes = userAbonnesIds.length pour tous les Users.
 * Lance avec : node functions/scripts/backfill_abonnes.js
 * Nécessite : firebase login (Application Default Credentials)
 *
 * Règle : met à jour abonnes si abonnes est absent (null) OU inférieur à userAbonnesIds.length.
 *          Ne diminue jamais abonnes (si le champ est déjà supérieur, on laisse).
 */

const admin = require("firebase-admin");

const PROJECT_ID       = "afrolooki";
const READ_PAGE_SIZE   = 400;
const WRITE_BATCH_SIZE = 400;
const DRY_RUN = false;

async function main() {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: PROJECT_ID,
  });

  const db = admin.firestore();
  console.log(`🔄 Migration abonnes — DRY_RUN=${DRY_RUN}`);

  let totalProcessed = 0;
  let totalSkipped   = 0;
  let totalUpdated   = 0;

  // Pagination par documentId (ne dépend d'aucun autre champ)
  let lastDocId = null;
  let page      = 0;

  while (true) {
    page++;
    let query = db.collection("Users")
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(READ_PAGE_SIZE);

    if (lastDocId) {
      query = query.startAfter(lastDocId);
    }

    const snap = await query.get();
    if (snap.empty) break;

    lastDocId = snap.docs[snap.docs.length - 1].id;
    console.log(`\n📄 Page ${page} — ${snap.docs.length} users`);

    let writeBatch = db.batch();
    let batchCount = 0;

    for (const doc of snap.docs) {
      totalProcessed++;
      const data = doc.data();

      const realCount = Array.isArray(data.userAbonnesIds) ? data.userAbonnesIds.length : 0;
      const stored    = typeof data.abonnes === "number" ? data.abonnes : null;

      // On met à jour seulement si abonnes est absent OU inférieur au vrai nombre d'abonnés
      const needsUpdate = stored === null || stored < realCount;

      if (!needsUpdate) {
        totalSkipped++;
        continue;
      }

      console.log(`  👤 ${doc.id} — abonnes ${stored ?? "null"} → ${realCount} (userAbonnesIds.length=${realCount})`);

      if (!DRY_RUN) {
        writeBatch.update(doc.ref, { abonnes: realCount });
      }

      totalUpdated++;
      batchCount++;

      if (batchCount >= WRITE_BATCH_SIZE) {
        if (!DRY_RUN) await writeBatch.commit();
        console.log(`  ✅ Batch commité (${batchCount} writes)`);
        writeBatch = db.batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      if (!DRY_RUN) await writeBatch.commit();
      if (!DRY_RUN) console.log(`  ✅ Batch final commité (${batchCount} writes)`);
      else console.log(`  [DRY] ${batchCount} mises à jour simulées`);
    }

    if (snap.docs.length < READ_PAGE_SIZE) break;
  }

  console.log(`\n🏁 Migration terminée`);
  console.log(`   Traités   : ${totalProcessed}`);
  console.log(`   Skippés   : ${totalSkipped} (abonnes déjà correct ou supérieur)`);
  console.log(`   Mis à jour: ${totalUpdated}`);
  if (DRY_RUN) console.log(`\n⚠️  DRY_RUN=true — aucune écriture effectuée. Passer DRY_RUN=false pour appliquer.`);
}

main().catch(err => {
  console.error("💥 Erreur fatale:", err);
  process.exit(1);
});
