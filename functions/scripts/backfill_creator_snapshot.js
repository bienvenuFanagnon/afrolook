/**
 * Migration : backfill creatorSnapshot / canalSnapshot sur tous les posts.
 * Lance avec : node functions/scripts/backfill_creator_snapshot.js
 * Nécessite : firebase login (Application Default Credentials)
 *
 * Stratégie :
 *  - Skip les posts déjà migrés (creatorSnapshot présent)
 *  - Cache user/canal en mémoire (1 fetch par créateur, pas 1 par post)
 *  - Batches Firestore de 400 writes max
 */

const admin = require("firebase-admin");

const PROJECT_ID = "afrolooki";
const WRITE_BATCH_SIZE = 400;   // max Firestore batch = 500, on garde une marge
const READ_PAGE_SIZE  = 400;    // posts lus par page (cursor pagination)
const DRY_RUN = false;          // true = log seulement, false = écrit en base

async function main() {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: PROJECT_ID,
  });

  const db = admin.firestore();
  console.log(`🔄 Migration creatorSnapshot — DRY_RUN=${DRY_RUN}`);

  let totalProcessed = 0;
  let totalSkipped   = 0;  // déjà migrés
  let totalUpdated   = 0;
  let totalErrors    = 0;

  // Cache userId → snapshot et canalId → canalSnapshot
  const userCache  = {};   // userId → { pseudo, imageUrl, abonnes }
  const canalCache = {};   // canalId → { titre, urlImage, suivi }

  // ── Pagination sur tous les posts ───────────────────────────────────────────
  let lastDoc = null;
  let page = 0;

  while (true) {
    page++;
    let query = db.collection("Posts").orderBy("created_at", "desc").limit(READ_PAGE_SIZE);
    if (lastDoc) query = query.startAfter(lastDoc);

    const snap = await query.get();
    if (snap.empty) break;

    lastDoc = snap.docs[snap.docs.length - 1];
    console.log(`\n📄 Page ${page} — ${snap.docs.length} posts`);

    // ── Collecte des IDs à résoudre ────────────────────────────────────────
    const postsToUpdate = [];
    const unknownUserIds  = new Set();
    const unknownCanalIds = new Set();

    for (const doc of snap.docs) {
      const data = doc.data();

      // Skip si déjà migré
      if (data.creatorSnapshot || data.canalSnapshot) {
        totalSkipped++;
        continue;
      }

      const isCanalPost = data.canal_id && data.canal_id !== "";
      postsToUpdate.push({ doc, data, isCanalPost });

      if (isCanalPost) {
        if (!canalCache[data.canal_id]) unknownCanalIds.add(data.canal_id);
      } else {
        if (data.user_id && !userCache[data.user_id]) unknownUserIds.add(data.user_id);
      }
    }

    // ── Résolution par batch (whereIn max 30 en Admin SDK) ──────────────────
    await resolveUsers(db, [...unknownUserIds], userCache);
    await resolveCanaux(db, [...unknownCanalIds], canalCache);

    // ── Écriture Firestore ──────────────────────────────────────────────────
    let writeBatch = db.batch();
    let batchCount = 0;

    for (const { doc, data, isCanalPost } of postsToUpdate) {
      totalProcessed++;
      let snapshot = null;

      if (isCanalPost) {
        snapshot = canalCache[data.canal_id];
        if (!snapshot) {
          console.warn(`  ⚠️  Canal introuvable: ${data.canal_id} (post ${doc.id})`);
          totalErrors++;
          continue;
        }
        if (!DRY_RUN) {
          writeBatch.update(doc.ref, { canalSnapshot: snapshot });
        }
      } else {
        if (!data.user_id) { totalErrors++; continue; }
        snapshot = userCache[data.user_id];
        if (!snapshot) {
          console.warn(`  ⚠️  User introuvable: ${data.user_id} (post ${doc.id})`);
          totalErrors++;
          continue;
        }
        if (!DRY_RUN) {
          writeBatch.update(doc.ref, { creatorSnapshot: snapshot });
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
    }

    if (batchCount > 0 && !DRY_RUN) {
      await writeBatch.commit();
      console.log(`  ✅ Batch final commité (${batchCount} writes)`);
    }

    // Stop si on a lu moins que la page complète (dernière page)
    if (snap.docs.length < READ_PAGE_SIZE) break;
  }

  console.log(`\n🏁 Migration terminée`);
  console.log(`   Traités  : ${totalProcessed}`);
  console.log(`   Skippés  : ${totalSkipped} (déjà migrés)`);
  console.log(`   Mis à jour: ${totalUpdated}`);
  console.log(`   Erreurs  : ${totalErrors}`);
}

/** Charge les Users par batch de 30 et remplit userCache. */
async function resolveUsers(db, userIds, cache) {
  for (let i = 0; i < userIds.length; i += 30) {
    const chunk = userIds.slice(i, i + 30);
    try {
      const snap = await db.collection("Users").where(admin.firestore.FieldPath.documentId(), "in", chunk).get();
      for (const doc of snap.docs) {
        const d = doc.data();
        cache[doc.id] = {
          pseudo   : d.pseudo      ?? null,
          imageUrl : d.imageUrl    ?? null,
          abonnes  : d.abonnes     ?? 0,
        };
      }
    } catch (e) {
      console.error(`  ⚠️  Erreur fetch users: ${e.message}`);
    }
  }
}

/** Charge les Canaux par batch de 30 et remplit canalCache. */
async function resolveCanaux(db, canalIds, cache) {
  for (let i = 0; i < canalIds.length; i += 30) {
    const chunk = canalIds.slice(i, i + 30);
    try {
      const snap = await db.collection("Canaux").where(admin.firestore.FieldPath.documentId(), "in", chunk).get();
      for (const doc of snap.docs) {
        const d = doc.data();
        cache[doc.id] = {
          titre    : d.titre    ?? null,
          urlImage : d.urlImage ?? null,
          suivi    : d.suivi    ?? 0,
        };
      }
    } catch (e) {
      console.error(`  ⚠️  Erreur fetch canaux: ${e.message}`);
    }
  }
}

main().catch(err => {
  console.error("💥 Erreur fatale:", err);
  process.exit(1);
});
