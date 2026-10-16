'use strict';
// Clés VAPID de l'envoi de notifications : créées automatiquement au premier besoin, gardées côté serveur (push_keys/vapid, inaccessible au navigateur).

let memo = null;

async function ensureVapid(db, webpush) {
  if (memo) return memo;
  const ref = db.collection('push_keys').doc('vapid');
  const d = await ref.get();
  if (d.exists && d.data().publicKey && d.data().privateKey) { memo = d.data(); return memo; }
  const k = webpush.generateVAPIDKeys();
  const doc = { publicKey: k.publicKey, privateKey: k.privateKey, creeLe: new Date().toISOString() };
  // deux instances qui démarrent ensemble : la première écriture gagne, l'autre relit
  await db.runTransaction(async (tx) => {
    const cur = await tx.get(ref);
    if (cur.exists && cur.data().publicKey) { memo = cur.data(); return; }
    tx.set(ref, doc);
    memo = doc;
  });
  return memo;
}

const resetMemo = () => { memo = null; };

module.exports = { ensureVapid, resetMemo };
