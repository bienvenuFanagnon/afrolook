// Importe les jeux de niveaux (levels_{af,eu,as,am,mx}.json, produits par build_levels.js) dans Firestore QuizLevels/{région}_{001..200}.
// Collection illisible par l'app (règles) : seules les Cloud Functions la lisent.
// Usage : GOOGLE_APPLICATION_CREDENTIALS=... node upload_levels.js [af eu as am mx]
const fs = require('fs');
const path = require('path');
const admin = require('../../functions/node_modules/firebase-admin');
admin.initializeApp({ credential: admin.credential.cert(require(process.env.GOOGLE_APPLICATION_CREDENTIALS)), projectId: 'afrolooki' });
(async () => {
  const wanted = process.argv.slice(2);
  const sets = (wanted.length ? wanted : ['af', 'eu', 'as', 'am', 'mx']);
  const db = admin.firestore();
  const poolFile = path.join(__dirname, 'pool.json');
  if (fs.existsSync(poolFile)) {
    const pools = JSON.parse(fs.readFileSync(poolFile, 'utf8'));
    for (const [k, list] of Object.entries(pools)) await db.collection('QuizPool').doc(k).set({ list });
    console.log(`${Object.keys(pools).length} réservoirs de rejeu importés.`);
  }
  for (const set of sets) {
    const file = path.join(__dirname, `levels_${set}.json`);
    if (!fs.existsSync(file)) { console.log(`levels_${set}.json absent, ignoré`); continue; }
    const levels = JSON.parse(fs.readFileSync(file, 'utf8'));
    for (let i = 0; i < levels.length; i += 100) {
      const batch = db.batch();
      levels.slice(i, i + 100).forEach((lv) => batch.set(db.collection('QuizLevels').doc(`${set}_${String(lv.n).padStart(3, '0')}`), lv));
      await batch.commit();
    }
    console.log(`${set} : ${levels.length} niveaux importés.`);
  }
})().catch((e) => { console.error(e); process.exit(1); });
