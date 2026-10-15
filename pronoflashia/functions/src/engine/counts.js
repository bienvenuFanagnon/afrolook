'use strict';
// Marchés « de comptage » : corners, tirs, tirs cadrés, fautes, cartons, hors-jeux.
// Loi binomiale négative (la variance dépasse la moyenne dans les statistiques de match).

const { shrink } = require('./poisson');

/** Paramètres de dispersion r par type de comptage (plus r est grand, plus on se rapproche d'une Poisson). À recalibrer sur l'historique réel. */
const DISPERSION = {
  corners: 14,
  shots: 16,
  shotsOnTarget: 12,
  fouls: 30,
  cards: 9,
  offsides: 10,
};

const MAX_COUNT = 80;

/** P(X = k) pour une binomiale négative de moyenne mu et de dispersion r. */
function nbPmf(mu, r) {
  const out = new Array(MAX_COUNT + 1).fill(0);
  if (mu <= 0) { out[0] = 1; return out; }
  const p = r / (r + mu);
  out[0] = Math.pow(p, r);
  for (let k = 1; k <= MAX_COUNT; k++) out[k] = out[k - 1] * ((k - 1 + r) / k) * (1 - p);
  const s = out.reduce((a, b) => a + b, 0);
  return out.map((x) => x / s);
}

/** P(X > line) pour une ligne de type x,5 (ex. +8,5 corners : au moins 9). */
function overProb(pmf, line) {
  const k = Math.floor(line) + 1;
  let s = 0;
  for (let i = k; i < pmf.length; i++) s += pmf[i];
  return s;
}

/** Loi de la somme de deux variables indépendantes. */
function convolve(a, b) {
  const out = new Array(a.length + b.length - 1).fill(0);
  for (let i = 0; i < a.length; i++) {
    if (a[i] < 1e-12) continue;
    for (let j = 0; j < b.length; j++) out[i + j] += a[i] * b[j];
  }
  return out.slice(0, MAX_COUNT + 1);
}

/** P(A > B), P(A = B), P(A < B) pour deux comptages indépendants. */
function compare(pa, pb) {
  let gt = 0, eq = 0, lt = 0;
  for (let i = 0; i < pa.length; i++) {
    for (let j = 0; j < pb.length; j++) {
      const p = pa[i] * pb[j];
      if (i > j) gt += p; else if (i === j) eq += p; else lt += p;
    }
  }
  return { gt, eq, lt };
}

/**
 * Moyenne attendue pour une équipe : sa production moyenne (for) et ce que concède l'adversaire (against),
 * rapportées à la moyenne de la ligue. Lissé quand l'échantillon est petit.
 */
function expectedCount(teamFor, oppAgainst, leagueAvg, extra = 1) {
  const f = shrink(teamFor.avg, leagueAvg, teamFor.n || 0);
  const a = shrink(oppAgainst.avg, leagueAvg, oppAgainst.n || 0);
  return Math.max(0.05, (f / leagueAvg) * (a / leagueAvg) * leagueAvg * extra);
}

/** Effet de l'arbitre : moyenne de ses matchs rapportée à celle de la ligue, lissée, bornée. */
function refereeFactor(refAvg, refGames, leagueAvg) {
  if (!(refAvg > 0) || !(leagueAvg > 0)) return 1;
  const f = shrink(refAvg, leagueAvg, refGames || 0, 8) / leagueAvg;
  return Math.min(1.35, Math.max(0.75, f));
}

/**
 * Toutes les probabilités d'un type de comptage pour un match.
 * muHome, muAway : moyennes attendues. lines : lignes totales ; teamLines : lignes par équipe.
 */
function countMarkets(kind, muHome, muAway, lines, teamLines) {
  const r = DISPERSION[kind] || 12;
  const ph = nbPmf(muHome, r);
  const pa = nbPmf(muAway, r);
  const pt = convolve(ph, pa);
  const out = { kind, muHome, muAway, muTotal: muHome + muAway, total: {}, home: {}, away: {} };
  for (const l of lines) out.total[l] = overProb(pt, l);
  for (const l of teamLines || []) {
    out.home[l] = overProb(ph, l);
    out.away[l] = overProb(pa, l);
  }
  out.cmp = compare(ph, pa);
  return out;
}

module.exports = { DISPERSION, nbPmf, overProb, convolve, compare, expectedCount, refereeFactor, countMarkets };
