/**
 * seed_auth_emulator.js
 * Crée les utilisateurs Auth dans l'émulateur avec les vrais UIDs production.
 *
 * Usage : node scripts/seed_auth_emulator.js
 * Prérequis : émulateur Auth lancé sur localhost:9099
 */

const admin = require('../functions/node_modules/firebase-admin');

const PROJECT_ID = 'afrolooki';

process.env.FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099';

const app = admin.initializeApp({ projectId: PROJECT_ID }, 'auth-seed');
const auth = app.auth();

const USERS = [
  {
    uid: 'gXEe76s0hQZqBhWph3n2jDUqi8f2',
    email: 'jorbienvenu@gmail.com',
    password: 'test1234',
    displayName: 'Jorbi Bienvenu',
    emailVerified: true,
  },
  {
    uid: 'ioGRgDCEJYOKpNwBLzQWFLB1njY2',
    email: 'jorbinbienvenu@gmail.com',
    password: 'test1234',
    displayName: 'Jorbin Bienvenu',
    emailVerified: true,
  },
  {
    uid: '5idPI6n77OeKTiNWXE0W4Cc2GCL2',
    email: 'lafab0504@gmail.com',
    password: 'test1234',
    displayName: 'Lafab',
    emailVerified: true,
  },
];

async function main() {
  console.log('🔐 Création des comptes Auth dans l\'émulateur...\n');

  for (const user of USERS) {
    try {
      await auth.createUser(user);
      console.log(`  ✅ ${user.email} — uid: ${user.uid}`);
    } catch (err) {
      if (err.code === 'auth/uid-already-exists' || err.code === 'auth/email-already-exists') {
        console.log(`  ℹ️  ${user.email} — déjà existant, ignoré`);
      } else {
        console.error(`  ❌ ${user.email} — erreur: ${err.message}`);
      }
    }
  }

  console.log('\n🎉 Auth seed terminé ! Connecte-toi avec password: test1234');
  process.exit(0);
}

main().catch(err => {
  console.error('❌ Erreur fatale :', err.message);
  process.exit(1);
});
