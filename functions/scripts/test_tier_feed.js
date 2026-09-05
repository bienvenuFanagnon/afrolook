/**
 * Script de test : vérifie les données Tier 1/2 pour un utilisateur donné.
 * Lancer depuis le répertoire functions/ :
 *   GOOGLE_APPLICATION_CREDENTIALS=path/to/key.json node scripts/test_tier_feed.js
 * ou via : firebase emulators:exec "node scripts/test_tier_feed.js"
 * ou simplement : node scripts/test_tier_feed.js  (si déjà authentifié via firebase CLI)
 */

const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

initializeApp({ credential: applicationDefault(), projectId: 'afrolooki' });
const db = getFirestore();

const USER_ID = 'ioGRgDCEJYOKpNwBLzQWFLB1njY2';

async function run() {
  console.log('=== TEST TIER FEED ===\n');

  // 1. Charger le document utilisateur
  console.log(`[1] Chargement user ${USER_ID}...`);
  const userDoc = await db.collection('Users').doc(USER_ID).get();
  if (!userDoc.exists) {
    console.error('❌ User not found!');
    process.exit(1);
  }
  const userData = userDoc.data();

  // 2. Vérifier unreadPosts (Tier 1)
  const unreadPosts = userData.unreadPosts || {};
  const unreadCount = Object.keys(unreadPosts).length;
  console.log(`[Tier 1] unreadPosts: ${unreadCount} entrées`);

  if (unreadCount > 0) {
    // Trier par timestamp desc et prendre les 15 plus récents
    const sorted = Object.entries(unreadPosts)
      .sort(([,a], [,b]) => b - a)
      .slice(0, 15);

    console.log(`[Tier 1] 15 plus récents par timestamp:`);
    sorted.forEach(([id, ts], i) => {
      console.log(`  [${i}] ${id} → ts=${ts} (${new Date(ts).toISOString()})`);
    });

    // Essayer de charger ces posts depuis Firestore
    const ids = sorted.map(([id]) => id);
    console.log(`\n[Tier 1] Chargement de ${ids.length} posts depuis Firestore...`);

    for (let i = 0; i < ids.length; i += 10) {
      const batch = ids.slice(i, i + 10);
      const snap = await db.collection('Posts').where('__name__', 'in', batch).get();
      console.log(`  Batch [${i}-${i+batch.length}]: ${snap.docs.length}/${batch.length} posts trouvés`);

      snap.docs.forEach(doc => {
        const d = doc.data();
        console.log(`    ✅ ${doc.id}: type=${d.type}, statut=${d.statut || d.status || '?'}, postInterests=${JSON.stringify(d.postInterests || [])}, typeTabbar=${d.typeTabbar || '?'}`);
      });

      // Posts manquants
      const foundIds = snap.docs.map(d => d.id);
      const missing = batch.filter(id => !foundIds.includes(id));
      if (missing.length > 0) {
        console.log(`    ❌ Posts manquants (${missing.length}): ${missing.join(', ')}`);
      }
    }
  }

  // 3. Vérifier interests (Tier 2)
  const interests = userData.interests || [];
  console.log(`\n[Tier 2] interests: ${JSON.stringify(interests)}`);

  if (interests.length > 0) {
    // Requête Tier 2
    console.log(`[Tier 2] Requête postInterests arrayContainsAny ${JSON.stringify(interests.slice(0,10))}...`);
    try {
      const snap = await db.collection('Posts')
        .where('postInterests', 'array-contains-any', interests.slice(0, 10))
        .orderBy('created_at', 'desc')
        .limit(20)
        .get();

      console.log(`[Tier 2] ${snap.docs.length} posts trouvés`);
      snap.docs.slice(0, 5).forEach(doc => {
        const d = doc.data();
        console.log(`  ✅ ${doc.id}: postInterests=${JSON.stringify(d.postInterests)}, typeTabbar=${d.typeTabbar}`);
      });
    } catch (err) {
      console.error(`[Tier 2] ❌ Erreur requête:`, err.message);
    }
  }

  // 4. Vérifier quelques posts récents avec postInterests
  console.log(`\n[Diagnostic] Quelques posts récents avec postInterests...`);
  try {
    const snap = await db.collection('Posts')
      .orderBy('created_at', 'desc')
      .limit(20)
      .get();

    const withInterests = snap.docs.filter(d => d.data().postInterests && d.data().postInterests.length > 0);
    console.log(`  ${withInterests.length}/${snap.docs.length} des 20 derniers posts ont postInterests`);
    withInterests.forEach(doc => {
      const d = doc.data();
      console.log(`  - ${doc.id}: postInterests=${JSON.stringify(d.postInterests)}, typeTabbar=${d.typeTabbar}`);
    });
  } catch (err) {
    console.error(`[Diagnostic] ❌ Erreur:`, err.message);
  }

  // 5. Vérifier les intérêts stockés dans le user
  console.log(`\n[User] countryData: ${JSON.stringify(userData.countryData)}`);
  console.log(`[User] interests: ${JSON.stringify(userData.interests)}`);
  console.log(`[User] newPostsByCreator count: ${Object.keys(userData.newPostsByCreator || {}).length}`);
  console.log(`[User] newPostsByCanal count: ${Object.keys(userData.newPostsByCanal || {}).length}`);

  console.log('\n=== FIN DU TEST ===');
}

run().then(() => process.exit(0)).catch(err => {
  console.error('❌ Fatal:', err);
  process.exit(1);
});
