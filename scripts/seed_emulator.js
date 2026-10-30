/**
 * seed_emulator.js
 * Exporte Users + Posts récents depuis la production et les importe dans l'émulateur Firestore.
 *
 * Usage : node scripts/seed_emulator.js
 * Prérequis : émulateur Firestore lancé sur localhost:8080
 */

const admin = require('../functions/node_modules/firebase-admin');
const path = require('path');

// ─── Config ──────────────────────────────────────────────────────────────────
const PROJECT_ID = 'afrolooki';
const EMULATOR_HOST = '127.0.0.1:8080';

// Emails des utilisateurs à récupérer depuis la production
const TARGET_EMAILS = [
  'jorbienvenu@gmail.com',
  'jorbinbienvenu@gmail.com',
  'lafab0504@gmail.com',
];

const POSTS_LIMIT = 30; // Nombre de posts récents à récupérer

// ─── Init Admin SDK (production) ─────────────────────────────────────────────
const serviceAccountPath = path.join(__dirname, '..', 'functions', 'service-account.json');

// Utilise Application Default Credentials (gcloud auth application-default login)
const prodApp = admin.initializeApp(
  { credential: admin.credential.applicationDefault(), projectId: PROJECT_ID },
  'production'
);

const prodDb = prodApp.firestore();

// ─── Init Admin SDK (émulateur) ──────────────────────────────────────────────
process.env.FIRESTORE_EMULATOR_HOST = EMULATOR_HOST;

const emulatorApp = admin.initializeApp(
  { projectId: PROJECT_ID },
  'emulator'
);
const emulatorDb = emulatorApp.firestore();

// ─── Helpers ─────────────────────────────────────────────────────────────────
async function batchWrite(db, collection, docs) {
  const chunks = [];
  for (let i = 0; i < docs.length; i += 400) {
    chunks.push(docs.slice(i, i + 400));
  }
  for (const chunk of chunks) {
    const batch = db.batch();
    for (const { id, data } of chunk) {
      batch.set(db.collection(collection).doc(id), data);
    }
    await batch.commit();
  }
}

// ─── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  console.log('🔄 Connexion à la production...');

  // 1. Récupérer les utilisateurs ciblés
  console.log(`\n👤 Récupération des ${TARGET_EMAILS.length} utilisateurs...`);
  const usersToSeed = [];

  for (const email of TARGET_EMAILS) {
    const snap = await prodDb.collection('Users')
      .where('email', '==', email)
      .limit(1)
      .get();

    if (snap.empty) {
      console.log(`  ⚠️  User non trouvé : ${email}`);
      continue;
    }
    const doc = snap.docs[0];
    usersToSeed.push({ id: doc.id, data: doc.data() });
    console.log(`  ✅ ${email} — uid: ${doc.id}`);
  }

  // 2. Récupérer les posts récents
  console.log(`\n📄 Récupération des ${POSTS_LIMIT} posts récents...`);
  const postsSnap = await prodDb.collection('Posts')
    .orderBy('created_at', 'desc')
    .limit(POSTS_LIMIT)
    .get();

  const postsToSeed = postsSnap.docs.map(doc => ({ id: doc.id, data: doc.data() }));
  console.log(`  ✅ ${postsToSeed.length} posts récupérés`);

  // 3. Écrire dans l'émulateur
  console.log(`\n📥 Import dans l'émulateur (${EMULATOR_HOST})...`);

  if (usersToSeed.length > 0) {
    await batchWrite(emulatorDb, 'Users', usersToSeed);
    console.log(`  ✅ ${usersToSeed.length} utilisateurs importés`);
  }

  if (postsToSeed.length > 0) {
    await batchWrite(emulatorDb, 'Posts', postsToSeed);
    console.log(`  ✅ ${postsToSeed.length} posts importés`);
  }

  console.log('\n🎉 Seed terminé ! Ouvre http://127.0.0.1:4000/firestore pour vérifier.');
  process.exit(0);
}

main().catch(err => {
  console.error('❌ Erreur :', err.message);
  process.exit(1);
});
