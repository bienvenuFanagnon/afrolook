'use strict';
// Écrit dans l'émulateur Firestore (vraies règles de validation) tous les documents produits par la chaîne complète d'exemple.
// Détecte ce que la base factice des tests accepte et que Firestore refuse (tableaux imbriqués, champs undefined…).
// Usage (Java requis) : firebase emulators:exec --only firestore --project demo-pf "node scripts/firestore-emulator-check.js"
const path = require('path');
const fn = path.join(__dirname, '../functions');
const need = (m) => require(require.resolve(m, { paths: [fn] }));
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const { initializeApp } = need('firebase-admin/app');
const { getFirestore } = need('firebase-admin/firestore');
const { buildSample } = require('../functions/dev/sample');

(async () => {
  initializeApp({ projectId: 'demo-pf' });
  const real = getFirestore();
  const db = await buildSample(new Date('2026-10-16T08:00:00Z'));
  const failures = new Map();
  let ok = 0;
  for (const col of db.data.keys()) for (const [id, d] of db.data.get(col)) {
    try { await real.collection(col).doc(id).set(d); ok++; } catch (e) { const k = `${col} : ${e.message.slice(0, 140)}`; failures.set(k, (failures.get(k) || 0) + 1); }
  }
  console.log(`${ok} documents écrits`);
  for (const [k, n] of failures) console.log(`REFUSÉ ${n} × ${k}`);
  process.exit(failures.size ? 1 : 0);
})();
