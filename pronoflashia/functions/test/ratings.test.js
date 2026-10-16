'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const R = require('../src/engine/ratings');

function rng(seed) { let s = seed >>> 0; return () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; }; }
function pois(r, lam) { const L = Math.exp(-lam); let k = 0, p = 1; do { k++; p *= r(); } while (p > L); return k - 1; }

/** Championnat simulé : 20 équipes aux forces cachées, matchs aller-retour, un match toutes les 6 heures à partir de `start`. */
function league(seed, start = Date.UTC(2026, 0, 1), teams = 20) {
  const r = rng(seed);
  const gauss = () => Math.sqrt(-2 * Math.log(r() + 1e-9)) * Math.cos(2 * Math.PI * r());
  const att = [], def = [];
  for (let i = 0; i < teams; i++) { att.push(Math.exp(0.35 * gauss())); def.push(Math.exp(0.35 * gauss())); }
  const out = []; let k = 0;
  for (let round = 0; round < 2; round++) for (let i = 0; i < teams; i++) for (let j = 0; j < teams; j++) {
    if (i === j || (i + j + round) % 2) continue;
    out.push({ t: start + (k++) * 6 * 3600e3, h: String(i), a: String(j), gh: pois(r, 1.45 * att[i] * def[j]), ga: pois(r, 1.15 * att[j] * def[i]) });
  }
  return { matches: out, att, def };
}
const corr = (x, y) => { const n = x.length, mx = x.reduce((a, b) => a + b, 0) / n, my = y.reduce((a, b) => a + b, 0) / n; let sxy = 0, sx = 0, sy = 0; for (let i = 0; i < n; i++) { sxy += (x[i] - mx) * (y[i] - my); sx += (x[i] - mx) ** 2; sy += (y[i] - my) ** 2; } return sxy / Math.sqrt(sx * sy); };

test('notes : retrouvent les forces cachées des équipes (attaque et défense), avantage du domicile plausible', () => {
  const L = league(11);
  const end = L.matches[L.matches.length - 1].t + 1;
  const fit = R.fitRatings(L.matches, end);
  const ids = Object.keys(fit.A);
  assert.equal(ids.length, 20);
  assert.ok(corr(ids.map((i) => fit.A[i]), ids.map((i) => L.att[+i])) > 0.7, 'attaque');
  assert.ok(corr(ids.map((i) => fit.B[i]), ids.map((i) => L.def[+i])) > 0.7, 'défense');
  assert.ok(fit.H > 1.1 && fit.H < 1.5, `avantage domicile ${fit.H}`);
  assert.ok(fit.c > 0.9 && fit.c < 1.5);
});

test('notes : aucun accès au futur — les matchs postérieurs à la date n\'ont aucun effet', () => {
  const L = league(3);
  const mid = L.matches[200].t;
  const a = R.fitRatings(L.matches, mid);
  const altered = L.matches.map((m) => (m.t >= mid ? Object.assign({}, m, { gh: 9, ga: 0 }) : m));
  assert.deepEqual(R.fitRatings(altered, mid), a);
  assert.equal(R.fitRatings(L.matches.slice(0, 5), mid), null, 'moins de 10 matchs : pas de notes');
});

test('notes : les matchs récents pèsent plus (décroissance) et un adversaire fort relativise un résultat', () => {
  // l'équipe 0 marquait peu, puis beaucoup depuis 30 jours : sa note d'attaque doit monter avec la décroissance
  const now = Date.UTC(2026, 6, 1), day = 864e5;
  const ms = [];
  let k = 0;
  for (let d = 200; d > 0; d -= 2) {
    const recent = d <= 30;
    for (const [h, a] of [['0', '1'], ['2', '3'], ['1', '2'], ['3', '0'], ['0', '2'], ['1', '3']]) {
      ms.push({ t: now - d * day + (k++) * 1000, h, a, gh: h === '0' ? (recent ? 3 : 1) : 1, ga: a === '0' ? (recent ? 3 : 1) : 1 });
    }
  }
  const slow = R.fitRatings(ms, now, { halfLife: 100000 });
  const fast = R.fitRatings(ms, now, { halfLife: 30 });
  assert.ok(fast.A['0'] > slow.A['0'] + 0.1, `A rapide ${fast.A['0']} vs lent ${slow.A['0']}`);
});

test('prévision : buts attendus bornés, null si une équipe est inconnue', () => {
  const fit = { A: { x: 1.2, y: 0.8 }, B: { x: 0.9, y: 1.3 }, c: 1.2, H: 1.3 };
  const p = R.predictLambdas(fit, 'x', 'y');
  assert.ok(Math.abs(p.lamHome - 1.2 * 1.3 * 1.2 * 1.3) < 1e-9);
  assert.ok(Math.abs(p.lamAway - 1.2 * 0.8 * 0.9) < 1e-9);
  assert.equal(R.predictLambdas(fit, 'x', 'zzz'), null);
  assert.equal(R.predictLambdas(null, 'x', 'y'), null);
  assert.equal(R.predictLambdas({ A: { x: 50, y: 0.001 }, B: { x: 50, y: 50 }, c: 3, H: 2 }, 'x', 'y').lamHome, 4.5);
});

test('jugement walk-forward : sur un championnat simulé, les notes battent l\'ancien calcul ; résultat identique à chaque exécution', () => {
  const L = league(5);
  const prev = league(6, Date.UTC(2025, 0, 1)).matches; // autre saison (forces différentes) : historique « bruité »
  const a = R.backtest([], L.matches);
  assert.ok(a.n > 200, `matchs jugés ${a.n}`);
  assert.ok(a.gain > 0, `gain ${a.gain}`);
  assert.deepEqual(R.backtest([], L.matches), a);
  assert.ok(R.backtest(prev, L.matches).n === a.n);
});

test('activation : peu de matchs jugés → on garde les notes ; assez de matchs → il faut un gain', () => {
  assert.equal(R.isActive({ n: 0, gain: 0 }), true);
  assert.equal(R.isActive({ n: 60, gain: -0.5 }), true);
  assert.equal(R.isActive({ n: 150, gain: 0.01 }), true);
  assert.equal(R.isActive({ n: 150, gain: -0.01 }), false);
  assert.equal(R.isActive(null), true);
});

test('lecture d\'une équipe : écarts à la moyenne et évolution sur 60 jours', () => {
  const L = league(9);
  const end = L.matches[L.matches.length - 1].t + 1;
  const fit = R.ratingsWithTrend(L.matches, end);
  assert.ok(fit.evol && Object.keys(fit.evol).length > 10);
  const d = R.describeTeam(fit, '0');
  assert.equal(typeof d.attaque, 'number');
  assert.equal(typeof d.defense, 'number');
  assert.equal(d.attaque, Math.round((fit.A['0'] - 1) * 100));
  assert.equal(R.describeTeam(fit, 'inconnue'), null);
});
