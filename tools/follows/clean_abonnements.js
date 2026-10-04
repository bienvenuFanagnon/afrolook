// Nettoie la collection Abonnements : relations sans équivalent dans Follows (désabonnements
// jamais supprimés) et doublons. Sauvegarde JSON avant suppression.
// Usage : GOOGLE_APPLICATION_CREDENTIALS=... node clean_abonnements.js backup.json [--apply]
const fs = require('fs');
const admin = require('../../functions/node_modules/firebase-admin');
admin.initializeApp({ credential: admin.credential.cert(require(process.env.GOOGLE_APPLICATION_CREDENTIALS)), projectId: 'afrolooki' });
const APPLY = process.argv.includes('--apply');
(async () => {
  const db = admin.firestore();
  const snap = await db.collection('Abonnements').get();
  const docs = snap.docs;
  const refs = docs.map((d) => { const x = d.data(); return db.collection('Follows').doc(`${x.abonne_user_id}_${x.compte_user_id}`); });
  const exists = [];
  for (let i = 0; i < refs.length; i += 300) (await db.getAll(...refs.slice(i, i + 300))).forEach((s) => exists.push(s.exists));
  const seen = new Set(); const del = [];
  docs.forEach((d, i) => {
    const x = d.data(); const k = `${x.compte_user_id}>${x.abonne_user_id}`;
    if (!exists[i] || seen.has(k)) del.push(d); else seen.add(k);
  });
  console.log({ total: docs.length, aSupprimer: del.length, restant: docs.length - del.length, mode: APPLY ? 'APPLY' : 'SIMULATION' });
  if (!APPLY) return;
  fs.writeFileSync(process.argv[2], JSON.stringify(del.map((d) => ({ id: d.id, ...d.data() }))));
  for (let i = 0; i < del.length; i += 400) { const b = db.batch(); del.slice(i, i + 400).forEach((d) => b.delete(d.ref)); await b.commit(); }
  console.log('supprimés', del.length);
})().catch((e) => { console.error(e); process.exit(1); });
