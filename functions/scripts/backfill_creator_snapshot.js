/**
 * Migration : met à jour creatorSnapshot.abonnes dans chaque Post
 * avec userAbonnesIds.length du créateur (source de vérité),
 * et canalSnapshot.suivi avec usersSuiviId.length du canal.
 *
 * Règle : mise à jour si creatorSnapshot.abonnes est absent OU inférieur
 *          au vrai nombre d'abonnés. Ne diminue jamais.
 *
 * Lance avec : node functions/scripts/backfill_creator_snapshot.js
 * Nécessite  : firebase login (Application Default Credentials)
 */

const admin = require("firebase-admin");

const PROJECT_ID       = "afrolooki";
const READ_PAGE_SIZE   = 200;
const WRITE_BATCH_SIZE = 400;
const DRY_RUN          = false;

async function main() {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: PROJECT_ID,
  });

  const db = admin.firestore();
  console.log(`🔄 Migration creatorSnapshot.abonnes — DRY_RUN=${DRY_RUN}`);

  let totalProcessed = 0;
  let totalSkipped   = 0;
  let totalUpdated   = 0;
  let totalErrors    = 0;

  // Cache en mémoire pour éviter de relire le même créateur plusieurs fois
  const userCache  = new Map(); // userId → realAbonnes (number)
  const canalCache = new Map(); // canalId → realSuivi (number)

  let lastDocId = null;
  let page      = 0;

  while (true) {
    page++;
    let query = db.collection("Posts")
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(READ_PAGE_SIZE);

    if (lastDocId) {
      query = query.startAfter(lastDocId);
    }

    const snap = await query.get();
    if (snap.empty) break;

    lastDocId = snap.docs[snap.docs.length - 1].id;
    console.log(`\n📄 Page ${page} — ${snap.docs.length} posts`);

    let writeBatch = db.batch();
    let batchCount = 0;

    for (const doc of snap.docs) {
      totalProcessed++;
      const data = doc.data();

      const canalId   = data.canal_id;
      const userId    = data.user_id;
      const isCanalPost = typeof canalId === "string" && canalId.length > 0;

      try {
        if (isCanalPost) {
          // ── Canal post : mise à jour de canalSnapshot.suivi ──────────────
          const currentSuivi = data.canalSnapshot?.suivi;

          let realSuivi;
          if (canalCache.has(canalId)) {
            realSuivi = canalCache.get(canalId);
          } else {
            const canalDoc = await db.collection("Canaux").doc(canalId).get();
            const canalData = canalDoc.exists ? canalDoc.data() : null;
            realSuivi = Array.isArray(canalData?.usersSuiviId)
              ? canalData.usersSuiviId.length
              : (typeof canalData?.suivi === "number" ? canalData.suivi : 0);
            canalCache.set(canalId, realSuivi);
          }

          const stored = typeof currentSuivi === "number" ? currentSuivi : null;
          const needsUpdate = stored === null || stored < realSuivi;

          if (!needsUpdate) { totalSkipped++; continue; }

          console.log(
            `  📺 [CANAL] post=${doc.id.slice(0, 8)} canal=${canalId.slice(0, 8)} — suivi ${stored ?? "null"} → ${realSuivi}`
          );

          if (!DRY_RUN) {
            writeBatch.update(doc.ref, { "canalSnapshot.suivi": realSuivi });
          }

        } else {
          // ── User post : mise à jour de creatorSnapshot.abonnes ───────────
          if (!userId) { totalSkipped++; continue; }

          const currentAbonnes = data.creatorSnapshot?.abonnes;

          let realAbonnes;
          if (userCache.has(userId)) {
            realAbonnes = userCache.get(userId);
          } else {
            const userDoc = await db.collection("Users").doc(userId).get();
            const userData = userDoc.exists ? userDoc.data() : null;
            realAbonnes = Array.isArray(userData?.userAbonnesIds)
              ? userData.userAbonnesIds.length
              : (typeof userData?.abonnes === "number" ? userData.abonnes : 0);
            userCache.set(userId, realAbonnes);
          }

          const stored = typeof currentAbonnes === "number" ? currentAbonnes : null;
          const needsUpdate = stored === null || stored < realAbonnes;

          if (!needsUpdate) { totalSkipped++; continue; }

          console.log(
            `  👤 post=${doc.id.slice(0, 8)} user=${userId.slice(0, 8)} — abonnes ${stored ?? "null"} → ${realAbonnes}`
          );

          if (!DRY_RUN) {
            writeBatch.update(doc.ref, { "creatorSnapshot.abonnes": realAbonnes });
          }
        }

        totalUpdated++;
        batchCount++;

        if (batchCount >= WRITE_BATCH_SIZE) {
          if (!DRY_RUN) await writeBatch.commit();
          console.log(`  ✅ Batch commité (${batchCount} writes)`);
          writeBatch = db.batch();
          batchCount = 0;
        }

      } catch (e) {
        totalErrors++;
        console.error(`  ⚠️ Erreur post=${doc.id}: ${e.message}`);
      }
    }

    if (batchCount > 0) {
      if (!DRY_RUN) await writeBatch.commit();
      if (!DRY_RUN) console.log(`  ✅ Batch final commité (${batchCount} writes)`);
      else           console.log(`  [DRY] ${batchCount} mises à jour simulées`);
    }

    if (snap.docs.length < READ_PAGE_SIZE) break;
  }

  console.log(`\n🏁 Migration terminée`);
  console.log(`   Traités   : ${totalProcessed}`);
  console.log(`   Skippés   : ${totalSkipped}`);
  console.log(`   Mis à jour: ${totalUpdated}`);
  console.log(`   Erreurs   : ${totalErrors}`);
  if (DRY_RUN) console.log(`\n⚠️  DRY_RUN=true — aucune écriture effectuée. Passer DRY_RUN=false pour appliquer.`);
}

main().catch(err => {
  console.error("💥 Erreur fatale:", err);
  process.exit(1);
});
