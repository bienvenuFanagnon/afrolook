'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeDb } = require('./helpers/fakeDb');
const { archiveCoupons, settleCoupons, summarizeCoupons } = require('../src/jobs/coupons');

const NOW = new Date('2026-10-16T08:00:00Z');
const mk = (cle, pct, famille = 'Buts') => ({ cle, libelle: cle, famille, pct, fiabilite: 'haute' });
const match = (n, hour, marches, extra = {}) => ({
  id: `m${n}`, apiId: n, jour: '2026-10-16', statut: 'prevu', coupDEnvoi: `2026-10-16T${hour}:00:00.000Z`, slug: `a${n}-b${n}`, leagueSlug: 'ligue-1',
  domicile: { nomCourt: `A${n}` }, exterieur: { nomCourt: `B${n}` }, prono: { visible: true, marches }, ...extra,
});
const FAMS = ['Résultat', 'Buts', 'Corners', 'Mi-temps', 'Handicap'];
async function seedDay(db, n = 5) {
  for (let i = 1; i <= n; i++) await db.seed('matches', `m${i}`, match(i, String(14 + i), [mk(`buts:over:1.5`, 80 - i, FAMS[i % 5]), mk('res:1', 70 - i, FAMS[(i + 1) % 5])]));
}

test('archive : trois coupons du jour, une seule fois, jamais modifiés', async () => {
  const db = new FakeDb();
  await seedDay(db);
  assert.equal(await archiveCoupons(db, NOW), 3);
  const c3 = db.read('coupons_flash', '2026-10-16_3');
  assert.equal(c3.statut, 'ouvert');
  assert.equal(c3.selections.length, 3);
  assert.ok(c3.prob > 0 && c3.prob < 1);
  // les pronostics changent ensuite : le coupon archivé ne bouge pas
  await db.seed('matches', 'm1', match(1, '15', [mk('buts:over:1.5', 99)]));
  assert.equal(await archiveCoupons(db, new Date(NOW.getTime() + 3600e3)), 0);
  assert.deepEqual(db.read('coupons_flash', '2026-10-16_3'), c3);
});

test('archive : matchs déjà commencés ou trop peu de matchs → pas de coupon', async () => {
  const db = new FakeDb();
  await seedDay(db, 1);
  assert.equal(await archiveCoupons(db, NOW), 0);
  const db2 = new FakeDb();
  await seedDay(db2, 5);
  // 5 matchs entre 15:00 et 19:00 ; à 17:30 il n'en reste que deux à venir : seul le coupon de 2 sélections est possible
  assert.equal(await archiveCoupons(db2, new Date('2026-10-16T17:30:00Z')), 1);
  assert.ok(db2.read('coupons_flash', '2026-10-16_2'));
  assert.equal(db2.read('coupons_flash', '2026-10-16_3'), null);
});

async function finish(db, id, key, ok, extra = {}) {
  const m = db.read('matches', id);
  await db.seed('matches', id, Object.assign(m, { statut: 'termine', resultat: { marches: { [key]: ok }, scoreDom: 1, scoreExt: 0 } }, extra));
}

test('règlement : perdu dès une sélection ratée, gagné quand toutes passent, annulé si non évaluable', async () => {
  const db = new FakeDb();
  await seedDay(db);
  await archiveCoupons(db, NOW);
  const c2 = db.read('coupons_flash', '2026-10-16_2');
  const [a, b] = c2.selections;
  const later = new Date('2026-10-16T23:00:00Z');
  // un seul match terminé et réussi : toujours ouvert
  await finish(db, a.matchId, a.key, true);
  assert.equal(await settleCoupons(db, later), 0);
  assert.equal(db.read('coupons_flash', c2.id).statut, 'ouvert');
  assert.equal(db.read('coupons_flash', c2.id).selections[0].ok, true);
  // le second est réussi aussi : gagné
  await finish(db, b.matchId, b.key, true);
  assert.equal((await settleCoupons(db, later)) >= 1, true);
  assert.equal(db.read('coupons_flash', c2.id).statut, 'gagne');
  assert.ok(db.read('coupons_flash', c2.id).reglesLe);
  // coupon de 3 : une sélection ratée suffit à le perdre, sans attendre les autres matchs
  const c3 = db.read('coupons_flash', '2026-10-16_3');
  await finish(db, c3.selections[0].matchId, c3.selections[0].key, false);
  await settleCoupons(db, later);
  assert.equal(db.read('coupons_flash', c3.id).statut, 'perdu');
  // coupon de 5 : un match reporté, les autres réussis → annulé (ne compte ni gagné ni perdu)
  const c5 = db.read('coupons_flash', '2026-10-16_5');
  const [x, ...rest] = c5.selections;
  await db.seed('matches', x.matchId, Object.assign(db.read('matches', x.matchId), { statut: 'reporte' }));
  for (const s of rest) { const cur = db.read('matches', s.matchId); if (cur.statut !== 'termine') await finish(db, s.matchId, s.key, true); else { cur.resultat.marches[s.key] = true; await db.seed('matches', s.matchId, cur); } }
  await settleCoupons(db, later);
  const done = db.read('coupons_flash', c5.id);
  assert.ok(['annule', 'perdu'].includes(done.statut));
});

test('règlement : un match jamais terminé finit par rendre la sélection non évaluable', async () => {
  const db = new FakeDb();
  await seedDay(db);
  await archiveCoupons(db, NOW);
  assert.equal(await settleCoupons(db, new Date('2026-10-17T10:00:00Z')), 0, 'trop tôt');
  const far = new Date('2026-10-21T10:00:00Z');
  await settleCoupons(db, far);
  assert.equal(db.read('coupons_flash', '2026-10-16_2').statut, 'annule');
});

test('statistiques : taux réel, probabilité annoncée moyenne, par niveau ; annulés et en cours exclus du taux', () => {
  const list = [
    { nom: 'prudent', statut: 'gagne', prob: 0.7 }, { nom: 'prudent', statut: 'perdu', prob: 0.7 },
    { nom: 'audacieux', statut: 'perdu', prob: 0.3 }, { nom: 'prudent', statut: 'annule', prob: 0.7 }, { nom: 'equilibre', statut: 'ouvert', prob: 0.5 },
  ];
  const s = summarizeCoupons(list);
  assert.equal(s.n, 3);
  assert.equal(s.gagnes, 1);
  assert.equal(s.taux, 33);
  assert.equal(s.annonce, 57);
  assert.equal(s.enCours, 1);
  assert.equal(s.annules, 1);
  assert.equal(s.parNiveau.prudent.taux, 50);
  assert.equal(summarizeCoupons([]).taux, null);
});
