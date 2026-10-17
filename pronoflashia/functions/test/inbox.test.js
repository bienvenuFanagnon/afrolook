'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeDb } = require('./helpers/fakeDb');
const subs = require('../src/push/subs');
const inbox = require('../src/push/inbox');
const { deliver, sendPush } = require('../src/jobs/sendPush');
const { handlePush } = require('../src/http/push');
const { parsePath, pathFor } = require('../src/render/i18n');

const NOW = new Date('2026-10-17T12:00:00Z');
const KEYS = { p256dh: 'BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTpQtUbVlUls0VJXg7A8u-Ts1XbjhazAkj7I99e8QcYP7DkM', auth: 'tBHItJI5svbpez7KI4CCXg' };
const EP = (n) => `https://fcm.googleapis.com/fcm/send/ib${n}`;
const reg = (db, n) => subs.subscribe(db, { subscription: { endpoint: EP(n), keys: KEYS }, lang: 'fr' }, NOW);

async function sendN(db, count, startMs) {
  const list = [(await db.collection('push_subs').doc(subs.idOf(EP(1))).get()).data()];
  for (let i = 0; i < count; i++) {
    await deliver(db, async () => {}, list, () => ({ titre: `Titre ${i}`, corps: `Corps ${i}`, url: '/coupon?source=push', tag: 't', image: i === 0 ? '/api/img/abcdef0123456789.png' : undefined }), null, null);
  }
  return list[0];
}

test('boîte : chaque envoi est gardé, le lien porte l\'identifiant, le compteur de non lues suit', async () => {
  const db = new FakeDb();
  await reg(db, 1); await reg(db, 2);
  const seen = [];
  const list = [(await db.collection('push_subs').doc(subs.idOf(EP(1))).get()).data(), (await db.collection('push_subs').doc(subs.idOf(EP(2))).get()).data()];
  const payload = { titre: '⚡ Coupons', corps: 'Texte', url: '/coupon?source=push&slot=matin', tag: 'x', image: '/api/img/abcdef0123456789.png' };
  await deliver(db, async (s, p) => { seen.push(p.url); }, list, () => payload, null, { jour: '2026-10-17', kind: 'matin' });
  assert.match(seen[0], /^\/coupon\?source=push&slot=matin&n=[a-f0-9]{12}$/);
  assert.equal(seen[0], seen[1], 'même lien pour tous les abonnés');
  const c = await inbox.count(db, EP(1));
  assert.equal(c.nonLus, 1);
  const l = await inbox.list(db, EP(1), 0, NOW);
  assert.equal(l.items.length, 1);
  assert.equal(l.items[0].lu, false);
  assert.equal(l.items[0].image, '/api/img/abcdef0123456789.png');
  assert.equal(l.items[0].url, seen[0]);
  const r = await inbox.markRead(db, EP(1), l.items[0].id, false);
  assert.equal(r.nonLus, 0);
  assert.equal((await inbox.list(db, EP(1), 0, NOW)).items[0].lu, true);
  assert.equal((await inbox.count(db, EP(2))).nonLus, 1, 'la boîte de l\'autre abonné est intacte');
  await assert.rejects(inbox.markRead(db, EP(1), 'pas-un-id', false), /invalide/);
  await assert.rejects(inbox.count(db, 'https://exemple.com/x'), /invalide/);
  await assert.rejects(inbox.count(db, EP(9)), /inconnu/);
});

test('boîte : liste par pages de 10 (la plus récente d\'abord), 50 au plus, 30 jours au plus, « tout marquer lu », tests et envois sans boîte exclus', async () => {
  const db = new FakeDb();
  await reg(db, 1);
  await sendN(db, 23);
  const p1 = await inbox.list(db, EP(1), 0, NOW);
  assert.equal(p1.items.length, 10);
  assert.equal(p1.suite, true);
  assert.equal(p1.nonLus, 23);
  assert.equal((await inbox.count(db, EP(1))).nonLus, 23);
  const p3 = await inbox.list(db, EP(1), 20, NOW);
  assert.equal(p3.items.length, 3);
  assert.equal(p3.suite, false);
  const titles = (await inbox.list(db, EP(1), 0, NOW)).items.map((x) => x.titre);
  assert.equal(new Set(titles).size, 10);
  assert.equal((await inbox.markRead(db, EP(1), null, true)).nonLus, 0);
  assert.equal((await inbox.list(db, EP(1), 0, NOW)).nonLus, 0);
  // au-delà de 50 : les plus anciennes sont supprimées à l'ouverture de la liste
  await sendN(db, 40);
  const big = await inbox.list(db, EP(1), 0, NOW);
  assert.equal(big.total, 50);
  // plus de 30 jours : supprimées
  const later = new Date(NOW.getTime() + 31 * 864e5);
  assert.equal((await inbox.list(db, EP(1), 0, later)).total, 0);
  // un message marqué inbox:false (test, essai) n'entre pas dans la boîte
  const db2 = new FakeDb();
  await reg(db2, 1);
  const sub = [(await db2.collection('push_subs').doc(subs.idOf(EP(1))).get()).data()];
  await deliver(db2, async () => {}, sub, () => ({ titre: 'Test', corps: 'x', url: '/', tag: 't', inbox: false }), null, null);
  assert.equal((await inbox.list(db2, EP(1), 0, NOW)).total, 0);
});

test('API : compteur, liste, lecture ; adresse inconnue refusée ; limites de débit', async () => {
  const db = new FakeDb();
  await reg(db, 1);
  await sendN(db, 12);
  const deps = { db, now: NOW, publicKey: async () => 'K' };
  const call = (path, body, ip = '7.7.7.7') => handlePush({ method: 'POST', path: `/api/push/${path}`, body, ip }, deps);
  assert.deepEqual((await call('compte', { endpoint: EP(1) })).json, { nonLus: 12 });
  const l = (await call('inbox', { endpoint: EP(1), offset: 0 })).json;
  assert.equal(l.items.length, 10);
  assert.equal(l.suite, true);
  assert.equal((await call('lu', { endpoint: EP(1), id: l.items[0].id })).json.nonLus, 11);
  assert.equal((await call('lu', { endpoint: EP(1), tous: true })).json.nonLus, 0);
  assert.equal((await call('compte', { endpoint: EP(5) })).status, 404);
  assert.equal((await call('compte', { endpoint: 'https://exemple.com' })).status, 400);
  assert.equal((await handlePush({ method: 'GET', path: '/api/push/compte', body: {}, ip: '1.1.1.1' }, deps)).status, 405);
  let last;
  for (let i = 0; i < 130; i++) last = await call('compte', { endpoint: EP(1) }, '9.9.9.9');
  assert.equal(last.status, 429);
});

test('envoi automatique : la notification arrive dans la boîte et se réabonner ne perd pas le compteur ; page /notifications routée en français et en anglais', async () => {
  const db = new FakeDb();
  await reg(db, 1);
  await db.seed('coupons_flash', '2026-10-17_2', { id: '2026-10-17_2', jour: '2026-10-17', n: 2, nom: 'prudent', prob: 0.7, statut: 'ouvert', selections: [{ titre: 'Arsenal – Chelsea', pct: 80 }] });
  await sendPush({ db, send: async () => {}, now: new Date('2026-10-17T07:40:00Z') }, { traites: 0, erreurs: [], infos: {} });
  assert.equal((await inbox.count(db, EP(1))).nonLus, 1);
  await reg(db, 1);
  assert.equal((await inbox.count(db, EP(1))).nonLus, 1, 'le réabonnement garde le compteur');
  const item = (await inbox.list(db, EP(1), 0, NOW)).items[0];
  assert.match(item.titre, /Coupons du jour : Arsenal – Chelsea/);
  assert.match(item.image, /^\/api\/img\//);
  assert.deepEqual(parsePath('/notifications'), { lang: 'fr', name: 'notifs' });
  assert.deepEqual(parsePath('/en/notifications'), { lang: 'en', name: 'notifs' });
  assert.equal(pathFor('en', 'notifs'), '/en/notifications');
});
