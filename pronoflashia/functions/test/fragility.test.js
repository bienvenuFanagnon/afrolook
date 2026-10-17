'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeDb } = require('./helpers/fakeDb');
const { assess, isFragile, MIN_SAMPLE } = require('../src/engine/fragility');
const { archiveCoupons } = require('../src/jobs/coupons');
const M = require('../src/push/messages');
const { buildSample } = require('../dev/sample');
const { route } = require('../src/render/router');
const D = require('../src/render/data');

test('données limitées : début de saison (moins de 8 matchs) ou équipe inconnue du moteur de notes', () => {
  assert.equal(assess({ echantillon: MIN_SAMPLE, equipeInconnue: false }), null);
  assert.deepEqual(assess({ echantillon: 5 }), { raisons: ['echantillon'] });
  assert.deepEqual(assess({ echantillon: 20, equipeInconnue: true }), { raisons: ['equipe_inconnue'] });
  assert.deepEqual(assess({ echantillon: 3, equipeInconnue: true }).raisons, ['echantillon', 'equipe_inconnue']);
  assert.equal(assess({ echantillon: null }), null, 'sans information : pas de drapeau');
  assert.equal(isFragile({ prono: { fragile: { raisons: ['echantillon'] } } }), true);
  assert.equal(isFragile({ prono: { fragile: null } }), false);
});

const NOW = new Date('2026-10-16T08:00:00Z');
const mk = (n, h, extra = {}) => ({
  id: `m${n}`, jour: '2026-10-16', statut: 'prevu', coupDEnvoi: `2026-10-16T${h}:00:00.000Z`, slug: `a${n}-b${n}`, leagueSlug: 'ligue-1',
  domicile: { teamId: n, nomCourt: `A${n}` }, exterieur: { teamId: n + 100, nomCourt: `B${n}` },
  prono: { visible: true, principal: { cle: 'res:1', libelle: `1N · A${n}`, confiance: 70 + n, basseConfiance: false }, marches: [{ cle: 'buts:over:1.5', libelle: '+1,5 buts', famille: ['Buts', 'Résultat', 'Handicap', 'Mi-temps', 'Score'][n % 5], pct: 80 - n, fiabilite: 'haute' }], ...(extra.prono || {}) },
});

test('les matchs à données limitées sont écartés des coupons du jour archivés et des notifications', async () => {
  const db = new FakeDb();
  for (let i = 1; i <= 5; i++) await db.seed('matches', `m${i}`, mk(i, String(14 + i)));
  const fragile = { raisons: ['echantillon'] };
  await db.seed('matches', 'm1', mk(1, '15', { prono: { fragile } }));
  await db.seed('matches', 'm2', mk(2, '16', { prono: { fragile } }));
  await archiveCoupons(db, NOW);
  const c2 = db.read('coupons_flash', '2026-10-16_2');
  const ids = db.all('coupons_flash').flatMap((c) => c.selections.map((s) => s.matchId));
  assert.ok(c2, 'coupon de 2 sélections possible avec les 3 matchs restants');
  assert.ok(!ids.includes('m1') && !ids.includes('m2'), `jamais de match fragile : ${ids}`);
  assert.equal(db.read('coupons_flash', '2026-10-16_5'), null, 'pas de coupon de 5 avec seulement 3 matchs fiables');
  const all = db.all('matches');
  assert.ok(!M.midi(all, 'fr').corps.includes('A1') && !M.midi(all, 'fr').corps.includes('A2'), 'pronostic le plus confiant : pas un match fragile');
  assert.equal(M.soir(all.slice(0, 2), 'fr'), null);
});

test('affichage : pastille « Données limitées » sur la carte, explication sur la fiche, absent des coupons proposés', async () => {
  const db = await buildSample(NOW);
  const target = db.all('matches').filter((m) => m.prono && m.statut === 'prevu').sort((a, b) => b.prono.principal.confiance - a.prono.principal.confiance)[0];
  await db.seed('matches', target.id, Object.assign({}, target, { _id: undefined, prono: Object.assign({}, target.prono, { fragile: { raisons: ['echantillon'] } }) }));
  D.clearCache();
  const day = (await route(db, `/football/${target.jour}`, NOW)).body;
  assert.match(day, /⚠ Données limitées/);
  const page = (await route(db, `/football/${target.leagueSlug}/${target.slug}`, NOW)).body;
  assert.match(page, /class="note frag"/);
  assert.match(page, /pas utilisé dans les coupons proposés/);
  const home = (await route(db, '/', NOW)).body;
  const flash = home.split('Flash du jour')[1].split('Coupons flash')[0];
  assert.ok(!flash.includes(`/${target.leagueSlug}/${target.slug}"`), 'pas parmi les 3 pronostics les plus confiants (comparé par adresse : le jeu d\'exemple répète les mêmes affiches)');
  const en = (await route(db, `/en/football/${target.jour}`, NOW)).body;
  assert.match(en, /⚠ Limited data/);
});
