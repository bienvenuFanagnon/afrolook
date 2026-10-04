// Migration : crée Follows/{créateur}_{abonné} depuis Users.userAbonnesIds et recalcule Users.abonnes.
// Usage : GOOGLE_APPLICATION_CREDENTIALS=... node backfill_follows.js [--apply]
// Sans --apply : simulation (aucune écriture).
const admin = require('../../functions/node_modules/firebase-admin');
admin.initializeApp({ credential: admin.credential.cert(require(process.env.GOOGLE_APPLICATION_CREDENTIALS)), projectId: 'afrolooki' });
const APPLY = process.argv.includes('--apply');
(async () => {
  const db = admin.firestore();
  let users = 0, relations = 0, created = 0, existing = 0, counterFixed = 0, orphan = 0;
  const exists = new Set((await db.collection('Users').select().get()).docs.map((d) => d.id));
  let last = null;
  for (;;) {
    let q = db.collection('Users').orderBy(admin.firestore.FieldPath.documentId()).limit(300).select('userAbonnesIds', 'abonnes');
    if (last) q = q.startAfter(last);
    const s = await q.get(); if (s.empty) break;
    for (const d of s.docs) {
      users++;
      const ids = [...new Set((d.data().userAbonnesIds || []).filter((x) => typeof x === 'string' && x))];
      const valid = ids.filter((id) => exists.has(id) && id !== d.id);
      orphan += ids.length - valid.length;
      relations += valid.length;
      const refs = valid.map((id) => db.collection('Follows').doc(`${d.id}_${id}`));
      const snaps = refs.length ? await db.getAll(...refs) : [];
      const writes = [];
      snaps.forEach((snap, i) => {
        if (snap.exists) { existing++; return; }
        created++;
        if (APPLY) writes.push([refs[i], { creatorId: d.id, followerId: valid[i], createdAt: Date.now() }]);
      });
      for (let i = 0; i < writes.length; i += 400) {
        const batch = db.batch();
        writes.slice(i, i + 400).forEach(([ref, data]) => batch.set(ref, data));
        await batch.commit();
      }
      if ((d.data().abonnes || 0) !== valid.length) {
        counterFixed++;
        if (APPLY) await d.ref.update({ abonnes: valid.length });
      }
    }
    last = s.docs[s.docs.length - 1];
  }
  console.log({ mode: APPLY ? 'APPLY' : 'SIMULATION', users, relations, created, existing, counterFixed, orphan });
})().catch((e) => { console.error(e); process.exit(1); });
