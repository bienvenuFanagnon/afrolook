'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const P = require('../src/engine/poisson');
const C = require('../src/engine/counts');
const { buildMarkets } = require('../src/engine/markets');
const { pickMarkets, makeCalibrator } = require('../src/engine/pick');
const { predictMatch, round100 } = require('../src/engine/model');
const goal = require('../src/shared/goalmarkets');

const sum = (a) => a.reduce((x, y) => x + y, 0);
const near = (a, b, eps = 1e-6) => assert.ok(Math.abs(a - b) < eps, `${a} ≉ ${b}`);

test('la matrice de scores somme à 1 et reproduit les moyennes', () => {
  const m = P.scoreMatrix(1.8, 1.1);
  near(sum(m.map(sum)), 1);
  const eh = m.reduce((s, row, i) => s + i * sum(row), 0);
  const ea = m.reduce((s, row) => s + row.reduce((t, p, j) => t + j * p, 0), 0);
  assert.ok(Math.abs(eh - 1.8) < 0.08, `moyenne dom. ${eh}`);
  assert.ok(Math.abs(ea - 1.1) < 0.08, `moyenne ext. ${ea}`);
});

test('1N2 : somme égale à 1 et favori logique', () => {
  const r = P.result1x2(P.scoreMatrix(2.1, 0.8));
  near(r.p1 + r.pN + r.p2, 1);
  assert.ok(r.p1 > r.p2 && r.p1 > r.pN);
  const sym = P.result1x2(P.scoreMatrix(1.3, 1.3));
  near(sym.p1, sym.p2);
});

test('les cotes sans marge sont normalisées, le recalage retrouve les probabilités', () => {
  const imp = P.impliedFromOdds([1.8, 3.6, 4.5]);
  near(sum(imp), 1);
  const fit = P.fitToMarket({ p1: imp[0], pN: imp[1], p2: imp[2] }, { lamHome: 1.2, lamAway: 1.2 });
  const r = P.result1x2(P.scoreMatrix(fit.lamHome, fit.lamAway));
  assert.ok(Math.abs(r.p1 - imp[0]) < 0.02, `p1 ${r.p1} vs ${imp[0]}`);
  assert.ok(Math.abs(r.p2 - imp[2]) < 0.02);
});

test('buts attendus : une équipe forte à domicile contre une défense faible', () => {
  const league = { avgHome: 1.45, avgAway: 1.15 };
  const strong = { home: { games: 10, gf: 26, ga: 6 }, all: { games: 20, gf: 48, ga: 14 } };
  const weak = { away: { games: 10, gf: 8, ga: 19 }, all: { games: 20, gf: 18, ga: 40 } };
  const e = P.expectedGoals(strong, weak, league);
  assert.ok(e.lamHome > 2.2 && e.lamHome < 4.5, `lamHome ${e.lamHome}`);
  assert.ok(e.lamAway < 0.9, `lamAway ${e.lamAway}`);
  // échantillon vide : retombe sur la moyenne de la ligue
  const z = P.expectedGoals({}, {}, league);
  near(z.lamHome, 1.45, 0.01); near(z.lamAway, 1.15, 0.01);
});

test('binomiale négative : somme à 1, moyenne respectée, plus/moins complémentaires', () => {
  const pmf = C.nbPmf(10, 14);
  near(sum(pmf), 1);
  const mean = pmf.reduce((s, p, k) => s + p * k, 0);
  assert.ok(Math.abs(mean - 10) < 0.05, `moyenne ${mean}`);
  assert.ok(C.overProb(pmf, 7.5) > C.overProb(pmf, 9.5));
  const cm = C.countMarkets('corners', 6, 4.5, [8.5], [4.5]);
  near(cm.cmp.gt + cm.cmp.eq + cm.cmp.lt, 1, 1e-4);
  assert.ok(cm.cmp.gt > cm.cmp.lt);
});

test('marchés : cohérence entre familles', () => {
  const home = { nom: 'Paris SG', nomCourt: 'Paris' }, away = { nom: 'Marseille', nomCourt: 'Marseille' };
  const { marches, matrix } = buildMarkets({ home, away, lamHome: 2.1, lamAway: 1.0, counts: { corners: { muHome: 6.2, muAway: 4.4 }, cards: { muHome: 1.9, muAway: 2.6 } } });
  const by = Object.fromEntries(marches.map((m) => [m.cle, m]));
  assert.ok(by['res:1'].pct > by['res:2'].pct);
  assert.ok(by['res:1N'].pct >= by['res:1'].pct);
  assert.ok(Math.abs(by['buts:over:2.5'].pct + by['buts:under:2.5'].pct - 100) <= 1);
  assert.ok(by['buts:over:1.5'].pct > by['buts:over:2.5'].pct);
  assert.ok(by['res:dnb1'].pct > by['res:1'].pct);
  assert.ok(by['hand:away:+1.5'].pct > by['res:N2'].pct - 1);
  assert.ok(by['corners:total:7.5'].pct > by['corners:total:9.5'].pct);
  assert.ok(by['mt:1h:over:0.5'].pct < by['buts:over:0.5'].pct);
  assert.equal(by['spec:penalty'].fiabilite, 'faible');
  assert.equal(by['corners:total:7.5'].fiabilite, 'haute');
  assert.ok(marches.filter((m) => m.cle.startsWith('score:exact')).every((m) => m.fiabilite === 'faible'));
  // chaque marché de buts est identique à sa probabilité de matrice
  near(goal.probOf(matrix, 'res:1') * 100, by['res:1'].pct, 0.6);
  assert.ok(marches.every((m) => m.pct >= 1 && m.pct <= 99));
});

test('échantillon petit : la fiabilité baisse d\'un cran', () => {
  const home = { nom: 'A' }, away = { nom: 'B' };
  const { marches } = buildMarkets({ home, away, lamHome: 1.4, lamAway: 1.2, sampleGames: 3, counts: { corners: { muHome: 5, muAway: 5 } } });
  const c = marches.find((m) => m.cle === 'corners:total:7.5');
  assert.equal(c.fiabilite, 'moyenne');
  const r = marches.find((m) => m.cle === 'res:1');
  assert.equal(r.fiabilite, 'moyenne');
});

test('pronostic principal : varie selon le match et reste au-dessus du seuil', () => {
  const home = { nom: 'Dom', nomCourt: 'Dom' }, away = { nom: 'Ext', nomCourt: 'Ext' };
  const picks = new Set();
  for (const [a, b] of [[2.4, 0.7], [1.2, 1.1], [1.0, 0.9], [1.9, 1.7], [0.9, 1.9], [1.6, 0.6]]) {
    const { marches } = buildMarkets({ home, away, lamHome: a, lamAway: b });
    const { principal } = pickMarkets(marches, home, away);
    picks.add(principal.cle);
    if (!principal.basseConfiance) assert.ok(principal.confiance >= 55, `${a}-${b} ${principal.cle} ${principal.confiance}`);
  }
  assert.ok(picks.size >= 3, `trop peu de variété : ${[...picks]}`);
});

test('calibration : ramène la probabilité vers le taux réel selon l\'échantillon', () => {
  const cal = makeCalibrator([{ from: 60, to: 70, annonce: 65, reel: 55, n: 160 }]);
  const v = cal(66);
  assert.ok(v < 66 && v > 55, `${v}`);
  assert.equal(makeCalibrator([])(66), 66);
  assert.equal(makeCalibrator([{ from: 60, to: 70, reel: 50, n: 0 }])(66), 66);
});

test('round100 : somme exactement 100', () => {
  for (const v of [[0.333, 0.333, 0.334], [0.625, 0.215, 0.16], [0.5, 0.25, 0.25], [0.499, 0.2505, 0.2505]]) {
    assert.equal(sum(round100(v)), 100);
  }
});

test('predictMatch : pronostic complet et cohérent', () => {
  const stats = {
    home: { home: { games: 8, gf: 21, ga: 6 }, all: { games: 16, gf: 38, ga: 14 } },
    away: { away: { games: 8, gf: 10, ga: 12 }, all: { games: 16, gf: 25, ga: 24 } },
  };
  const out = predictMatch({
    home: { nom: 'Paris SG', nomCourt: 'Paris' }, away: { nom: 'Marseille' },
    stats, league: { avgHome: 1.5, avgAway: 1.2, counts: { corners: { avgHome: 5.4, avgAway: 4.5 } } },
    counts: { corners: { home: { for: { avg: 6.2, n: 10 }, against: { avg: 3.9, n: 10 } }, away: { for: { avg: 4.4, n: 10 }, against: { avg: 5.6, n: 10 } } } },
    odds: { home: 1.55, draw: 4.4, away: 5.6 },
  });
  assert.equal(out.probas['1'] + out.probas.N + out.probas['2'], 100);
  assert.ok(out.probas['1'] > out.probas['2']);
  assert.equal(out.source, 'stats+cotes');
  assert.ok(out.matrice.length === 7 && out.matrice[0].length === 7);
  assert.ok(out.marches.length > 40, `${out.marches.length} marchés`);
  assert.match(out.scoreProbable, /^\d-\d$/);
  assert.ok(out.counts.corners.muHome > out.counts.corners.muAway);
});

test('favori net : le pronostic principal est sa victoire, pas une double chance banale', () => {
  const home = { nom: 'Paris SG', nomCourt: 'Paris' }, away = { nom: 'Marseille' };
  const { marches } = buildMarkets({ home, away, lamHome: 2.15, lamAway: 1.04 });
  const { principal, secondaires } = pickMarkets(marches, home, away);
  assert.equal(principal.cle, 'res:1');
  assert.equal(principal.libelle, '1 · Paris');
  assert.equal(secondaires.length, 2);
  assert.ok(secondaires.every((s) => s.cle !== principal.cle));
});
