'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeDb } = require('./helpers/fakeDb');
const CL = require('../src/engine/couponLearn');
const { archiveCoupons, settleCoupons, relearn, loadLearning } = require('../src/jobs/coupons');
const M = require('../src/push/messages');
const { route } = require('../src/render/router');
const { buildSample } = require('../dev/sample');

const NOW = new Date('2026-10-16T08:00:00Z');
// jeu de coupons réglés : 30 paris « Buts » annoncés à 80 % qui passent 18 fois sur 30 (60 %), 20 paris « Résultat » annoncés à 70 % qui passent 15 fois sur 20 (75 %)
function settled() {
  const sels = [];
  for (let i = 0; i < 30; i++) sels.push({ famille: 'Buts', pct: 80, ok: i < 18 });
  for (let i = 0; i < 20; i++) sels.push({ famille: 'Résultat', pct: 70, ok: i < 15 });
  return [{ id: 'c1', jour: '2026-10-10', statut: 'perdu', selections: sels }];
}

test('apprentissage des coupons : biais par type de pari rapproché du biais global, plafonné, inactif sous 40 sélections, appris sur la valeur brute', () => {
  const L = CL.build(settled(), NOW);
  assert.equal(L.actif, true);
  assert.equal(L.n, 50);
  assert.equal(L.familles['Buts'].reel, 60);
  assert.equal(L.familles['Buts'].annonce, 80);
  assert.ok(L.familles['Buts'].bias < 0 && L.familles['Buts'].bias >= -CL.MAX_SHIFT, 'les paris Buts sont surestimés : correction vers le bas, plafonnée');
  assert.ok(L.familles['Résultat'].bias > L.familles['Buts'].bias, 'les paris Résultat tiennent leurs promesses : moins corrigés que les paris Buts');
  assert.ok(Math.abs(L.global) <= CL.MAX_SHIFT);
  assert.equal(CL.adjustPct(80, 'Buts', L) < 80, true);
  assert.ok(CL.adjustPct(70, 'Résultat', L) > CL.adjustPct(80, 'Buts', L) - 10, 'Résultat moins pénalisé que Buts');
  assert.equal(CL.adjustPct(70, 'Inconnue', L), Math.round(70 + L.global * 100), 'famille sans assez de données : biais global');
  const few = CL.build([{ selections: settled()[0].selections.slice(0, 39) }], NOW);
  assert.equal(few.actif, false);
  assert.equal(few.n, 39);
  assert.equal(CL.adjustPct(80, 'Buts', few), 80, 'aucune correction sous le seuil');
  // les sélections sans résultat ne comptent pas ; apprentissage sur pctBrut quand il existe (jamais sur la valeur déjà corrigée)
  const brut = CL.build([{ selections: Array.from({ length: 40 }, (_, i) => ({ famille: 'Buts', pct: 60, pctBrut: 80, ok: i < 32 })).concat([{ famille: 'Buts', pct: 90, ok: null }]) }], NOW);
  assert.equal(brut.n, 40);
  assert.equal(brut.familles['Buts'].annonce, 80);
  const pool = CL.applyToPool({ m1: [{ key: 'k', famille: 'Buts', pct: 80 }] }, L);
  assert.equal(pool.m1[0].pctBrut, 80);
  assert.ok(pool.m1[0].pct < 80);
});

async function seedDay(db) {
  for (let i = 1; i <= 5; i++) {
    await db.seed('matches', `m${i}`, {
      id: `m${i}`, apiId: i, jour: '2026-10-16', statut: 'prevu', coupDEnvoi: `2026-10-16T${14 + i}:00:00.000Z`, slug: `a${i}-b${i}`, leagueSlug: 'ligue-1',
      domicile: { nomCourt: `A${i}` }, exterieur: { nomCourt: `B${i}` },
      prono: { visible: true, marches: [{ cle: 'buts:over:1.5', libelle: '+1,5 buts', famille: 'Buts', pct: 80 - i, fiabilite: 'haute' }, { cle: 'res:1', libelle: 'A gagne', famille: 'Résultat', pct: 74 - i, fiabilite: 'haute' }] },
    });
  }
}

test('coupons flash : sans apprentissage actif rien ne change ; avec apprentissage, la probabilité annoncée et le choix des paris en tiennent compte, la valeur du moteur est gardée', async () => {
  const base = new FakeDb();
  await seedDay(base);
  await archiveCoupons(base, NOW);
  const c0 = base.read('coupons_flash', '2026-10-16_3');
  assert.equal(c0.appris, false);
  assert.ok(c0.selections.every((s) => s.pct === s.pctBrut));
  const db = new FakeDb();
  await seedDay(db);
  await db.seed('config', 'coupon_learning', CL.build(settled(), NOW));
  await archiveCoupons(db, NOW);
  const c1 = db.read('coupons_flash', '2026-10-16_3');
  assert.equal(c1.appris, true);
  assert.ok(c1.selections.every((s) => typeof s.pctBrut === 'number'));
  assert.ok(c1.selections.some((s) => s.pct !== s.pctBrut), 'au moins une probabilité corrigée');
  assert.ok(c1.prob !== c0.prob, 'la probabilité annoncée du coupon change');
  // le coupon du soir (notification) utilise la même correction
  const matches = [...db.data.get('matches').values()];
  const L = db.read('config', 'coupon_learning');
  assert.ok(M.soir(matches, 'fr', L), 'coupon du soir construit avec les probabilités corrigées');
});

test('règlement des coupons : l\'apprentissage est recalculé et enregistré à chaque passage (inactif tant qu\'il manque des sélections)', async () => {
  const db = new FakeDb();
  await seedDay(db);
  await archiveCoupons(db, NOW);
  await settleCoupons(db, new Date('2026-10-16T09:00:00Z'));
  const st = await loadLearning(db);
  assert.equal(st.actif, false);
  assert.equal(st.n, 0);
  await db.seed('coupons_flash', 'old', { id: 'old', jour: '2026-10-10', n: 5, nom: 'audacieux', prob: 0.1, statut: 'perdu', selections: settled()[0].selections });
  const L = await relearn(db, NOW);
  assert.equal(L.actif, true);
  assert.equal((await loadLearning(db)).n, 50);
  await db.seed('coupons_flash', 'trop-vieux', { id: 'trop-vieux', jour: '2026-06-01', statut: 'perdu', selections: settled()[0].selections });
  assert.equal((await relearn(db, NOW)).n, 50, 'plus de 60 jours : ignoré');
});

test('bilan : encadré « Ce que l\'IA apprend de ses coupons » (attente, puis types de pari corrigés), français et anglais', async () => {
  const NOWS = new Date('2026-10-16T12:00:00Z');
  const db = await buildSample(new Date('2026-10-16T08:00:00Z'));
  await db.seed('config', 'coupon_learning', { actif: false, n: 12, global: 0, familles: {}, majLe: NOW.toISOString() });
  const wait = (await route(db, '/bilan', NOWS)).body;
  assert.match(wait, /Ce que l'IA apprend de ses coupons/);
  assert.match(wait, /Pas encore assez de sélections terminées \(12 sur 40\)/);
  require('../src/render/data').clearCache();
  const db2 = await buildSample(new Date('2026-10-16T08:00:00Z'));
  await db2.seed('config', 'coupon_learning', CL.build(settled(), NOW));
  const fr = (await route(db2, '/bilan', NOWS)).body;
  assert.match(fr, /Buts : 60 % de réussite pour 80 % annoncés \(30 sélections\) → annoncé \d+ points? plus bas dans les coupons/);
  assert.match(fr, /Résultat : 75 % de réussite pour 70 % annoncés/);
  assert.match(fr, /Sur 50 sélections terminées/);
  const en = (await route(db2, '/en/track-record', NOWS)).body;
  assert.match(en, /What the AI learns from its slips/);
  assert.match(en, /60% hit rate for 80% announced \(30 selections\) → announced \d+ points? lower in slips/);
  // base d'exemple : les coupons ont été réglés par la chaîne complète, donc l'état « pas encore assez de sélections » est enregistré
  require('../src/render/data').clearCache();
  const sample = (await route(await buildSample(new Date('2026-10-16T08:00:00Z')), '/bilan', NOWS)).body;
  assert.match(sample, /Pas encore assez de sélections terminées \(\d+ sur 40\)/);
});
