/**
 * Initialise canalScore = 0 sur tous les Canaux sans ce champ,
 * et creatorScore = 0 sur tous les Users sans ce champ.
 *
 * Pourquoi : Firestore exclut silencieusement les documents qui n'ont pas
 * le champ utilisé dans un orderBy() — ce script garantit que tous les docs
 * apparaissent dans les requêtes ordonnées par score.
 *
 * Lance avec : node functions/scripts/backfill_init_scores.js
 * Nécessite  : firebase login (Application Default Credentials)
 */

const admin = require("firebase-admin");

const PROJECT_ID = "afrolooki";
const BATCH_SIZE = 400;
const DRY_RUN   = false;

async function backfillCollection(db, collectionName, scoreField) {
  console.log(`\n📋 ${collectionName} — initialisation de '${scoreField}'...`);

  const snap = await db.collection(collectionName).get();
  console.log(`   ${snap.size} documents trouvés`);

  let updated = 0;
  let skipped = 0;
  let batch   = db.batch();
  let count   = 0;

  for (const doc of snap.docs) {
    if (doc.data()[scoreField] !== undefined) {
      skipped++;
      continue;
    }

    batch.update(doc.ref, { [scoreField]: 0 });
    count++;
    updated++;

    if (count >= BATCH_SIZE) {
      if (!DRY_RUN) await batch.commit();
      batch = db.batch();
      count = 0;
    }
  }

  if (count > 0 && !DRY_RUN) await batch.commit();

  console.log(`   ✅ ${updated} initialisés à 0, ${skipped} déjà présents`);
}

async function main() {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: PROJECT_ID,
  });

  const db = admin.firestore();

  console.log(`\n🚀 Backfill init scores — DRY_RUN=${DRY_RUN}\n`);

  await backfillCollection(db, "Canaux", "canalScore");
  await backfillCollection(db, "Users",  "creatorScore");

  console.log("\n🎉 Terminé !");
  process.exit(0);
}

main().catch((err) => {
  console.error("❌ Erreur fatale :", err);
  process.exit(1);
});
