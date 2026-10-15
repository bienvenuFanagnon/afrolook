'use strict';
// Moteur de calcul : buts attendus + matrice de scores (Poisson corrigée Dixon-Coles).
// Tous les marchés de buts (1N2, handicap, totaux, score…) sortent de cette matrice.

const MAX_GOALS = 10;

function factorialTable(n) {
  const f = [1];
  for (let i = 1; i <= n; i++) f.push(f[i - 1] * i);
  return f;
}
const FACT = factorialTable(40);

/** P(X = k) pour une loi de Poisson de moyenne lam. */
function poissonPmf(k, lam) {
  if (lam <= 0) return k === 0 ? 1 : 0;
  return Math.exp(-lam + k * Math.log(lam)) / FACT[k];
}

/** Matrice P(buts dom = i, buts ext = j), i et j de 0 à max, somme = 1. */
function scoreMatrix(lamHome, lamAway, opts = {}) {
  const rho = opts.rho == null ? -0.08 : opts.rho;
  const max = opts.max || MAX_GOALS;
  const m = [];
  let sum = 0;
  for (let i = 0; i <= max; i++) {
    const row = [];
    for (let j = 0; j <= max; j++) {
      let p = poissonPmf(i, lamHome) * poissonPmf(j, lamAway);
      // Correction Dixon-Coles : les petits scores sont mal décrits par deux Poisson indépendantes.
      if (i === 0 && j === 0) p *= 1 - lamHome * lamAway * rho;
      else if (i === 0 && j === 1) p *= 1 + lamHome * rho;
      else if (i === 1 && j === 0) p *= 1 + lamAway * rho;
      else if (i === 1 && j === 1) p *= 1 - rho;
      if (p < 0) p = 0;
      row.push(p);
      sum += p;
    }
    m.push(row);
  }
  for (let i = 0; i <= max; i++) for (let j = 0; j <= max; j++) m[i][j] /= sum;
  return m;
}

/** Somme des cases de la matrice qui vérifient pred(i, j). */
function sumWhere(m, pred) {
  let s = 0;
  for (let i = 0; i < m.length; i++) {
    for (let j = 0; j < m[i].length; j++) if (pred(i, j)) s += m[i][j];
  }
  return s;
}

/** Probabilités 1 / N / 2 d'une matrice. */
function result1x2(m) {
  return {
    p1: sumWhere(m, (i, j) => i > j),
    pN: sumWhere(m, (i, j) => i === j),
    p2: sumWhere(m, (i, j) => i < j),
  };
}

/** Retire la marge du bookmaker : probabilités implicites normalisées à partir de cotes décimales. */
function impliedFromOdds(odds) {
  const inv = odds.map((o) => (o > 1 ? 1 / o : 0));
  const s = inv.reduce((a, b) => a + b, 0);
  return s > 0 ? inv.map((x) => x / s) : null;
}

/**
 * Cherche les buts attendus (lamH, lamA) dont la matrice reproduit au mieux des probabilités 1N2
 * (et, si fourni, la probabilité de +2,5 buts). Recherche locale à pas décroissant.
 */
function fitToMarket(target, start, opts = {}) {
  let lh = Math.max(0.2, start.lamHome);
  let la = Math.max(0.2, start.lamAway);
  const loss = (a, b) => {
    const m = scoreMatrix(a, b, opts);
    const r = result1x2(m);
    let e = (r.p1 - target.p1) ** 2 + (r.pN - target.pN) ** 2 + (r.p2 - target.p2) ** 2;
    if (target.over25 != null) e += (sumWhere(m, (i, j) => i + j > 2) - target.over25) ** 2;
    return e;
  };
  let best = loss(lh, la);
  let step = 0.4;
  for (let it = 0; it < 80 && step > 0.002; it++) {
    let improved = false;
    for (const [dh, da] of [[step, 0], [-step, 0], [0, step], [0, -step], [step, step], [-step, -step]]) {
      const a = Math.min(5, Math.max(0.15, lh + dh));
      const b = Math.min(5, Math.max(0.15, la + da));
      const e = loss(a, b);
      if (e < best - 1e-12) { best = e; lh = a; la = b; improved = true; }
    }
    if (!improved) step /= 2;
  }
  return { lamHome: lh, lamAway: la, error: best };
}

/** Lisse une moyenne observée vers la moyenne de référence quand l'échantillon est petit. */
function shrink(observed, reference, n, k = 6) {
  if (!(n > 0) || observed == null || Number.isNaN(observed)) return reference;
  const w = n / (n + k);
  return w * observed + (1 - w) * reference;
}

/**
 * Buts attendus d'un match à partir des statistiques des deux équipes.
 * team = { home: {games, gf, ga}, away: {games, gf, ga}, all: {games, gf, ga} } (totaux sur la période)
 * league = { avgHome, avgAway } moyenne de buts par match, à domicile et à l'extérieur.
 */
function expectedGoals(home, away, league, opts = {}) {
  const venueW = opts.venueWeight == null ? 0.6 : opts.venueWeight;
  const lgH = league.avgHome || 1.45;
  const lgA = league.avgAway || 1.15;
  const rate = (t, venue, field) => {
    const v = t[venue] || {};
    const a = t.all || {};
    const rv = v.games > 0 ? v[field] / v.games : null;
    const ra = a.games > 0 ? a[field] / a.games : null;
    const n = (v.games || 0) * venueW + (a.games || 0) * (1 - venueW);
    if (rv == null && ra == null) return { r: null, n: 0 };
    const r = rv == null ? ra : ra == null ? rv : venueW * rv + (1 - venueW) * ra;
    return { r, n };
  };
  // force d'attaque / de défense relative à la moyenne de la ligue, lissée
  const hAtt = rate(home, 'home', 'gf');
  const hDef = rate(home, 'home', 'ga');
  const aAtt = rate(away, 'away', 'gf');
  const aDef = rate(away, 'away', 'ga');
  const attH = shrink(hAtt.r, lgH, hAtt.n) / lgH;
  const defA = shrink(aDef.r, lgH, aDef.n) / lgH;
  const attA = shrink(aAtt.r, lgA, aAtt.n) / lgA;
  const defH = shrink(hDef.r, lgA, hDef.n) / lgA;
  const clamp = (x) => Math.min(4.5, Math.max(0.2, x));
  return { lamHome: clamp(lgH * attH * defA), lamAway: clamp(lgA * attA * defH) };
}

module.exports = {
  MAX_GOALS, poissonPmf, scoreMatrix, sumWhere, result1x2, impliedFromOdds, fitToMarket, shrink, expectedGoals,
};
