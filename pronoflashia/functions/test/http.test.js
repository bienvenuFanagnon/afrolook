'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const crypto = require('crypto');
const { FakeDb } = require('./helpers/fakeDb');
const hll = require('../src/http/hll');
const { handleEvent, countryOf, key } = require('../src/http/track');

const inc = (n) => ({ __inc: n });
const NOW = new Date('2026-10-16T09:30:00Z');
const mk = (db, over = {}) => ({ db, increment: inc, now: NOW, salt: 'sel-de-test', ...over });
const req = (body, over = {}) => ({ body, ua: 'Mozilla/5.0 (Linux; Android 13) Chrome/120', ip: '1.2.3.4', headers: {}, ...over });

test('HyperLogLog : estimation à quelques % près, doublons ignorés', () => {
  const shards = Array.from({ length: hll.SHARDS }, () => hll.emptyRegisters());
  const N = 6000;
  for (let i = 0; i < N * 2; i++) {
    const id = i % N; // chaque visiteur apparaît deux fois
    const fp = hll.fingerprint('s', '2026-10-16', `10.0.${id >> 8}.${id & 255}`, 'ua');
    shards[fp.shard] = hll.addToRegisters(shards[fp.shard], fp.idx, fp.rank);
  }
  const est = shards.reduce((s, r) => s + hll.estimate(r), 0);
  assert.ok(Math.abs(est - N) / N < 0.1, `estimation ${est} pour ${N}`);
  // petits nombres : estimation fine
  const small = Array.from({ length: hll.SHARDS }, () => hll.emptyRegisters());
  for (let i = 0; i < 40; i++) { const fp = hll.fingerprint('s', 'd', 'ip' + i, 'ua'); small[fp.shard] = hll.addToRegisters(small[fp.shard], fp.idx, fp.rank); }
  const e2 = small.reduce((s, r) => s + hll.estimate(r), 0);
  assert.ok(Math.abs(e2 - 40) <= 8, `petit nombre ${e2}`);
  // le sel change l'empreinte : impossible de relier deux jours
  assert.notDeepEqual(hll.fingerprint('s1', 'd', 'ip', 'ua'), hll.fingerprint('s2', 'd', 'ip', 'ua'));
  assert.equal(hll.visitorsFromEstimates({ 0: 10.4, 1: 20.2 }), 31);
  void crypto;
});

test('pays : en-tête de l\'infrastructure d\'abord, sinon fuseau horaire', () => {
  assert.deepEqual(countryOf({ 'x-appengine-country': 'ci' }, 'Europe/Paris'), { cc: 'CI', source: 'entete' });
  assert.deepEqual(countryOf({}, 'Africa/Abidjan'), { cc: 'CI', source: 'fuseau' });
  assert.deepEqual(countryOf({}, 'Europe/Paris'), { cc: 'FR', source: 'fuseau' });
  assert.deepEqual(countryOf({}, ''), { cc: '??', source: 'inconnu' });
  assert.equal(key('61_1001'), '61_1001');
  assert.equal(key('a.b:c d'), 'a_b_c_d');
});

test('page vue : compteurs du jour (pages, pays, appareil, source, heure, match)', async () => {
  const db = new FakeDb();
  const ok = await handleEvent(req({ t: 'pv', p: 'match', m: '61_1001', d: 'm', r: 'moteur', s: 1, l: 'en', tz: 'Africa/Abidjan' }), mk(db));
  assert.equal(ok, true);
  const d = db.read('stats_days', '2026-10-16');
  assert.equal(d.pv, 1); assert.equal(d.visites, 1);
  assert.equal(d.langues.en, 1); assert.equal(d.pages.match, 1); assert.equal(d.pays.CI, 1); assert.equal(d.paysSource.fuseau, 1);
  assert.equal(d.appareils.m, 1); assert.equal(d.sources.moteur, 1); assert.equal(d.heures['9'], 1); assert.equal(d.matchs['61_1001'], 1);
  assert.ok(d.hllEst && Object.keys(d.hllEst).length === 1);
  // deuxième page de la même visite : pas de nouvelle visite
  await handleEvent(req({ t: 'pv', p: 'analyse', m: '61_1001', d: 'm', r: 'interne', s: 0, tz: 'Africa/Abidjan' }), mk(db));
  const d2 = db.read('stats_days', '2026-10-16');
  assert.equal(d2.pv, 2); assert.equal(d2.visites, 1); assert.equal(d2.matchs['61_1001'], 2);
  // aucun identifiant dans les données : ni IP ni user-agent
  const dump = JSON.stringify([db.all('stats_days'), db.all('stats_hll')]);
  assert.ok(!dump.includes('1.2.3.4') && !dump.includes('Mozilla'));
});

test('visiteurs uniques : le même appareil compte une fois, deux appareils comptent deux fois', async () => {
  const db = new FakeDb();
  for (const ip of ['1.1.1.1', '1.1.1.1', '2.2.2.2', '3.3.3.3', '3.3.3.3']) await handleEvent(req({ t: 'pv', p: 'accueil', s: 1, tz: 'Europe/Paris' }, { ip }), mk(db));
  const est = hll.visitorsFromEstimates(db.read('stats_days', '2026-10-16').hllEst);
  assert.ok(est >= 2 && est <= 4, `estimation ${est}`);
  assert.equal(db.read('stats_days', '2026-10-16').visites, 5);
});

test('robots, Do Not Track, types inconnus et excès de requêtes sont ignorés', async () => {
  const db = new FakeDb();
  assert.equal(await handleEvent(req({ t: 'pv', p: 'accueil' }, { ua: 'Googlebot/2.1' }), mk(db)), false);
  assert.equal(await handleEvent(req({ t: 'pv', p: 'accueil' }, { headers: { dnt: '1' } }), mk(db)), false);
  assert.equal(await handleEvent(req({ t: 'inconnu' }), mk(db)), false);
  assert.equal(db.read('stats_days', '2026-10-16'), null);
  let counted = 0;
  for (let i = 0; i < 70; i++) if (await handleEvent(req({ t: 'wa', n: 'match' }, { ip: '9.9.9.9' }), mk(db))) counted++;
  assert.equal(counted, 60);
});

test('événements publicitaires et Afrolook', async () => {
  const db = new FakeDb();
  await handleEvent(req({ t: 'afl_imp', fmt: 'liste' }, { ip: 'a' }), mk(db));
  await handleEvent(req({ t: 'afl_click', fmt: 'liste' }, { ip: 'a' }), mk(db));
  await handleEvent(req({ t: 'adview', n: 'haut:adsterra' }, { ip: 'a' }), mk(db));
  await handleEvent(req({ t: 'coupon_add', n: 'match' }, { ip: 'a' }), mk(db));
  const d = db.read('stats_days', '2026-10-16');
  assert.equal(d.aflImps, 1); assert.equal(d.clicsAfrolook, 1); assert.equal(d.aflClics.liste, 1);
  assert.equal(d.pubVues, 1); assert.equal(d.pub['haut_adsterra'], 1); assert.equal(d.couponAjouts, 1);
});
