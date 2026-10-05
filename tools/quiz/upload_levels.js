// Importe les 200 niveaux (levels.json, produit par build_levels.js) dans Firestore QuizLevels/{001..200}.
// Collection illisible par l'app (règles) : seules les Cloud Functions la lisent.
// Usage : GOOGLE_APPLICATION_CREDENTIALS=... node upload_levels.js
const fs = require('fs');
const path = require('path');
const admin = require('../../functions/node_modules/firebase-admin');
admin.initializeApp({ credential: admin.credential.cert(require(process.env.GOOGLE_APPLICATION_CREDENTIALS)), projectId: 'afrolooki' });
(async () => {
  const levels = JSON.parse(fs.readFileSync(path.join(__dirname, 'levels.json'), 'utf8'));
  const db = admin.firestore();
  for (let i = 0; i < levels.length; i += 100) {
    const batch = db.batch();
    levels.slice(i, i + 100).forEach((lv) => batch.set(db.collection('QuizLevels').doc(String(lv.n).padStart(3, '0')), lv));
    await batch.commit();
  }
  console.log(`${levels.length} niveaux importés.`);
})().catch((e) => { console.error(e); process.exit(1); });
