// Surveillance des plateformes : alertes, blocage des paiements, gestion par l'administration (émulateur Firestore).
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
process.env.GCLOUD_PROJECT = 'afrolooki-it';
const F = 'D:/bienvenu/Projets/otherProjets/afrolook/V2/afrolookofficiel_v2/functions/';
const watch = require(F + 'lib/ads/adsWatch.js');
const pubs = require(F + 'lib/ads/adsPublishers.js');
const db = require(F + 'lib/shared/firebase.js').db;
let pass = 0, fail = 0;
const ok = (c, m, e) => { if (c) { pass++; console.log('  ✓', m); } else { fail++; console.log('  ✗', m, e !== undefined ? JSON.stringify(e) : ''); } };
const google = (uid, email) => ({ uid, token: { firebase: { sign_in_provider: 'google.com' }, email, name: 'T', picture: '' } });
const call = (fn, auth, data) => fn.run({ auth, data, rawRequest: {} });
const fails = async (p) => { try { await p; return null; } catch (e) { return e.message || String(e); } };
const dayOf = (t) => new Date(t).toISOString().slice(0, 10);

(async () => {
  const now = Date.now(), DAY = 86400000, today = dayOf(now), yest = dayOf(now - DAY);
  const PUB = 'ap_aaaaaaaaaa';
  await db.collection('Users').doc('u_admin').set({ role: 'ADM', email: 'jorbienvenu@gmail.com' });
  await db.collection('Users').doc('u_autre').set({ role: 'ADM', email: 'autre@example.com' });
  await db.collection('AdProperties').doc(PUB).set({ status: 'active', name: 'Kofi Sport', kind: 'site', audienceDeclared: 1000, ownerUid: 'u9', payable: true, createdAt: Date.now() });
  for (let i = 1; i <= 7; i++) {
    await db.collection('AdsPubDaily').doc(`${PUB}_${dayOf(now - i * DAY)}`).set({ day: dayOf(now - i * DAY), pub: PUB, valid: 500, clicks: 5, invalid: 10 });
    await db.collection('AdsPubDaily').doc(`slashatlas_${dayOf(now - i * DAY)}`).set({ day: dayOf(now - i * DAY), pub: 'slashatlas', valid: 400, clicks: 4, invalid: 5 });
  }
  await db.collection('AdsPubDaily').doc(`${PUB}_${today}`).set({ day: today, pub: PUB, valid: 6000, clicks: 5, invalid: 10, foreign: 700 });
  await db.collection('AdsPubDaily').doc(`slashatlas_${today}`).set({ day: today, pub: 'slashatlas', valid: 450, clicks: 5, invalid: 5 });
  await db.collection('AdsHll').doc(`${PUB}_${yest}`).set({ pub: PUB, day: yest, n: 1500 });
  await db.collection('AdsDaily').doc(`${today}_AD1_slashatlas`).set({ day: today, adId: 'AD1', pub: 'slashatlas', views: 10, clicks: 50 });
  await db.collection('AdsDaily').doc(`${today}_AD2_slashatlas`).set({ day: today, adId: 'AD2', pub: 'slashatlas', views: 1000, clicks: 12 });

  console.log('— Détection');
  const r = await watch.runWatch(now); ok(r.raised >= 4, 'des alertes sont créées', r);
  const all = (await db.collection('AdsAlerts').get()).docs.map((d) => d.data());
  const has = (pub, type, adId = '') => all.find((a) => a.pub === pub && a.type === type && a.adId === adId);
  ok(has(PUB, 'spike')?.severity === 'high', 'pic de vues (6 000 contre 500 par jour) : gravité haute');
  ok(has(PUB, 'foreign_calls')?.severity === 'high', 'identifiant utilisé depuis un autre domaine : haute');
  ok(has(PUB, 'audience_over')?.severity === 'high', 'plus de personnes différentes en un jour que l\'audience mensuelle déclarée : haute');
  ok(has('slashatlas', 'ad_clicks_no_views', 'AD1')?.severity === 'high', 'annonce avec plus de clics que de vues : haute');
  ok(!all.some((a) => a.adId === 'AD2'), 'annonce normale : aucune alerte');
  ok(!all.some((a) => a.pub === 'slashatlas' && a.adId === ''), 'plateforme interne normale : aucune alerte');
  const prop = (await db.collection('AdProperties').doc(PUB).get()).data();
  ok(prop.reviewHold === true && /./.test(prop.holdReason), 'blocage des paiements posé sur le site à risque', prop);
  ok(prop.status === 'active', 'la diffusion continue (seul le paiement est bloqué)');
  ok(await watch.hasOpenAlert(PUB), 'hasOpenAlert : vrai (aucun versement possible)');
  ok(!(await db.collection('AdProperties').doc('slashatlas').get()).exists, 'rien posé sur une plateforme interne');

  console.log('— Idempotence');
  const n1 = (await db.collection('AdsAlerts').get()).size; await watch.runWatch(now); const n2 = (await db.collection('AdsAlerts').get()).size;
  ok(n1 === n2, 'relancer la surveillance ne crée pas de doublons', [n1, n2]);

  console.log('— Administration');
  const admin = google('u_admin', 'jorbienvenu@gmail.com');
  let m = await fails(call(pubs.adsPubAdminList, google('u_autre', 'autre@example.com'), { alerts: true })); ok(/Réservé/.test(m || ''), 'un autre compte, même avec le rôle administrateur, est refusé', m);
  m = await fails(call(pubs.adsPubAdminList, google('u_x', 'x@example.com'), { alerts: true })); ok(m !== null, 'un compte sans rôle est refusé');
  const list = await call(pubs.adsPubAdminList, admin, { alerts: true }); ok(Array.isArray(list.alerts) && list.alerts.length >= 4 && list.alerts[0].severity === 'high', 'liste des alertes : graves d\'abord', list.alerts && list.alerts.length);
  const al = list.alerts.find((a) => a.pub === PUB && a.type === 'foreign_calls');
  await call(pubs.adsPubAdminReview, admin, { target: 'alert', id: al.id, decision: 'ack', reason: 'vérifié' });
  ok((await db.collection('AdsAlerts').doc(al.id).get()).data().status === 'reviewed', 'alerte vérifiée (RAS)');
  ok((await db.collection('AdProperties').doc(PUB).get()).data().reviewHold === true, 'vérifier une alerte ne lève pas le blocage tout seul');
  await call(pubs.adsPubAdminReview, admin, { target: 'alert', id: al.id, decision: 'release', reason: 'RAS' });
  ok((await db.collection('AdProperties').doc(PUB).get()).data().reviewHold === false, 'blocage levé explicitement par l\'administration');
  m = await fails(call(pubs.adsPubAdminReview, admin, { target: 'alert', id: al.id, decision: 'nimporte', reason: '' })); ok(m !== null, 'décision inconnue refusée', m);
  m = await fails(call(pubs.adsPubAdminReview, admin, { target: 'alert', id: 'inconnue', decision: 'ack' })); ok(m !== null, 'alerte inconnue refusée', m);
  const held = await call(pubs.adsPubAdminList, admin, { alerts: true, status: 'reviewed' }); ok(held.alerts.some((a) => a.id === al.id), 'filtre « vérifiées »');
  const props = await call(pubs.adsPubAdminList, admin, { status: 'all' }); ok(props.properties.some((p) => p.id === PUB && p.reviewHold === false), 'la liste des sites expose l\'état du blocage');

  console.log('— Une alerte vérifiée ne revient pas tant que la situation ne s\'aggrave pas');
  await db.collection('AdsAlerts').doc(al.id).update({ status: 'reviewed' }); await watch.runWatch(now);
  ok((await db.collection('AdsAlerts').doc(al.id).get()).data().status === 'reviewed', 'reste « vérifiée »');

  console.log(`\n${pass} réussis, ${fail} échoués`);
  process.exit(fail ? 1 : 0);
})().catch((e) => { console.error('ERREUR', e); process.exit(2); });
