'use strict';
// Firestore refuse : tableaux dans des tableaux, champs « undefined », objets qui ne sont pas de simples dictionnaires.
// La base factice des tests, elle, accepte tout : ce test parcourt donc TOUS les documents produits par la chaîne complète
// (matchs, pronostics, bilan, coupons, actualités, notes, abonnements…) avec les règles de Firestore.
// (Vérifié aussi une fois contre l'émulateur Firestore : voir le compte-rendu de la correction « invalid nested entity ».)
const test = require('node:test');
const assert = require('node:assert/strict');
const { buildSample } = require('../dev/sample');
const { pack, unpack } = require('../src/engine/matrixStore');
const { matchDelta, mergeDelta } = require('../src/engine/bilan');
const { FakeDb } = require('./helpers/fakeDb');
const subs = require('../src/push/subs');
const { sendPush } = require('../src/jobs/sendPush');

const isPlain = (o) => o && Object.getPrototypeOf(o) === Object.prototype;
function problems(v, path, out, inArray) {
  if (v === undefined) { out.push(`${path} : undefined`); return; }
  if (v === null || typeof v !== 'object') return;
  if (Array.isArray(v)) { if (inArray) out.push(`${path} : tableau dans un tableau`); v.forEach((x, i) => problems(x, `${path}[${i}]`, out, true)); return; }
  if (!isPlain(v)) { out.push(`${path} : objet non simple`); return; }
  for (const [k, x] of Object.entries(v)) { if (k === '' || /\//.test(k) || /^__.*__$/.test(k)) out.push(`${path}.${k} : nom de champ interdit`); problems(x, `${path}.${k}`, out, false); }
}
const scanDb = (db) => {
  const out = [];
  for (const col of db.data.keys()) for (const [id, d] of db.data.get(col)) problems(d, `${col}/${id}`, out, false);
  return [...new Set(out.map((o) => o.replace(/\/[^.\[ ]+/, '/*').replace(/\[\d+\]/g, '[]')))];
};

test('Firestore : aucun document de la chaîne complète (pronostics, notes, bilan, coupons, actualités…) ne contient de tableau imbriqué ni de champ undefined', async () => {
  const db = await buildSample(new Date('2026-10-16T08:00:00Z'));
  assert.deepEqual(scanDb(db), []);
  assert.ok(db.all('league_ratings').length > 0 && db.all('league_history').length > 0 && db.all('coupons_flash').length > 0 && db.all('news').length > 0);
});

test('Firestore : abonnements et journaux d\'envoi des notifications', async () => {
  const db = new FakeDb();
  const KEYS = { p256dh: 'BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTpQtUbVlUls0VJXg7A8u-Ts1XbjhazAkj7I99e8QcYP7DkM', auth: 'tBHItJI5svbpez7KI4CCXg' };
  await subs.subscribe(db, { subscription: { endpoint: 'https://fcm.googleapis.com/fcm/send/abc', keys: KEYS }, lang: 'fr', equipes: ['81'] }, new Date('2026-10-16T07:40:00Z'));
  await db.seed('coupons_flash', 'c', { id: 'c', jour: '2026-10-16', n: 2, nom: 'prudent', prob: 0.7, statut: 'ouvert' });
  await sendPush({ db, send: async () => {}, now: new Date('2026-10-16T07:40:00Z') }, { traites: 0, erreurs: [], infos: {} });
  assert.deepEqual(scanDb(db), []);
});

test('matrice de scores : rangée en 7 chaînes (jamais de tableau imbriqué), reconstruite à l\'identique', () => {
  const m = [[0.1, 0.2, 0.3], [0.4, 0.5, 0.6]];
  const p = pack(m);
  assert.deepEqual(p, ['0.1,0.2,0.3', '0.4,0.5,0.6']);
  assert.ok(p.every((x) => typeof x === 'string'));
  assert.deepEqual(unpack(p), m);
  assert.deepEqual(unpack(m), m, 'une matrice déjà reconstruite passe telle quelle');
  assert.equal(unpack(null), null);
  assert.equal(pack(undefined), null);
});

test('bilan : fusion de deux jours dont aucun n\'a de buts prévus → aucun champ « buts » (et donc aucun undefined)', () => {
  const mk = (extra) => ({ leagueId: '1', prono: Object.assign({ principal: { cle: 'res:1', confiance: 60 }, marches: [] }, extra), resultat: { reussi: true, marches: {} } });
  const a = matchDelta(mk({})), b = matchDelta(mk({}));
  assert.ok(!('buts' in a));
  const merged = mergeDelta(a, b);
  assert.ok(!('buts' in merged), 'pas de clé buts du tout');
  const out = []; problems(merged, 'delta', out, false);
  assert.deepEqual(out, []);
  const withButs = matchDelta(mk({ lamBrutHome: 1.4, lamBrutAway: 1.1 }));
  withButs.buts = { n: 1, pd: 1.4, pe: 1.1, rd: 2, re: 0 };
  assert.equal(mergeDelta(merged, withButs).buts.n, 1);
});
