'use strict';
// Catalogue des marchés d'un match : chaque pari proposé par les plateformes, avec sa probabilité calculée
// et un niveau de fiabilité. Voir pronoflashia/MARCHES_DE_PARIS.md.

const { scoreMatrix, sumWhere } = require('./poisson');
const goal = require('../shared/goalmarkets');
const counts = require('./counts');

const FAMILLES = ['Résultat', 'Buts', 'Mi-temps', 'Handicap', 'Score', 'Corners', 'Tirs', 'Cartons & fautes', 'Joueurs', 'Spéciaux'];
const NIVEAUX = ['faible', 'moyenne', 'haute'];

/** Nombre à la française : 2.5 → « 2,5 ». */
const fr = (x) => String(x).replace('.', ',');

/** Probabilité (0 à 1) → pourcentage entier borné à 1..99. */
function pctOf(p) {
  return Math.max(1, Math.min(99, Math.round(p * 100)));
}

/** Baisse la fiabilité d'un cran quand l'échantillon est petit. */
function degrade(niveau, sampleGames) {
  if (sampleGames != null && sampleGames < 6) return NIVEAUX[Math.max(0, NIVEAUX.indexOf(niveau) - 1)];
  return niveau;
}

const COUNT_DEFS = {
  corners: { famille: 'Corners', unit: 'corners', fiab: 'haute', lines: [6.5, 7.5, 8.5, 9.5, 10.5, 11.5], team: [3.5, 4.5, 5.5], cmp: true },
  shotsOnTarget: { famille: 'Tirs', unit: 'tirs cadrés', fiab: 'haute', lines: [6.5, 7.5, 8.5, 9.5, 10.5], team: [2.5, 3.5, 4.5, 5.5], cmp: false },
  shots: { famille: 'Tirs', unit: 'tirs au total', fiab: 'moyenne', lines: [20.5, 22.5, 24.5, 26.5], team: [], cmp: false },
  cards: { famille: 'Cartons & fautes', unit: 'cartons', fiab: 'moyenne', lines: [2.5, 3.5, 4.5, 5.5], team: [1.5, 2.5], cmp: true },
  fouls: { famille: 'Cartons & fautes', unit: 'fautes', fiab: 'moyenne', lines: [20.5, 22.5, 24.5, 26.5], team: [], cmp: false },
  offsides: { famille: 'Cartons & fautes', unit: 'hors-jeux', fiab: 'moyenne', lines: [2.5, 3.5, 4.5], team: [], cmp: false },
};

/** Résultat d'une rencontre pour un score (i, j). */
const rsl = (i, j) => (i > j ? 1 : i === j ? 0 : -1);

/** Loi du nombre total de buts d'une matrice. */
function totalsOf(m) {
  const out = new Array(m.length * 2).fill(0);
  for (let i = 0; i < m.length; i++) for (let j = 0; j < m[i].length; j++) out[i + j] += m[i][j];
  return out;
}

/**
 * input : { home:{nom,nomCourt}, away:{nom,nomCourt}, lamHome, lamAway, rho?, halfShare?, sampleGames?,
 *           counts?: { corners:{muHome,muAway}, ... }, baseRates?: { penalty, red } }
 * Renvoie { matrix, marches[] }.
 */
function buildMarkets(input) {
  const { home, away, lamHome, lamAway } = input;
  const rho = input.rho == null ? -0.08 : input.rho;
  const share = input.halfShare || 0.45; // part des buts marqués en 1re mi-temps
  const sample = input.sampleGames;
  const H = home.nomCourt || home.nom;
  const A = away.nomCourt || away.nom;
  const matrix = scoreMatrix(lamHome, lamAway, { rho });
  const marches = [];
  const add = (famille, cle, libelle, p, fiab, extra) => {
    const pct = pctOf(p);
    if (pct < 3 || pct > 97) return; // trop rare ou trop banal pour être utile
    marches.push(Object.assign({ famille, cle, libelle, pct, fiabilite: degrade(fiab, sample) }, extra || {}));
  };
  const P = (key) => goal.probOf(matrix, key);

  // ---- Résultat
  add('Résultat', 'res:1', `${H} gagne`, P('res:1'), 'haute');
  add('Résultat', 'res:N', 'Match nul', P('res:N'), 'haute');
  add('Résultat', 'res:2', `${A} gagne`, P('res:2'), 'haute');
  add('Résultat', 'res:1N', `${H} ou nul`, P('res:1N'), 'haute');
  add('Résultat', 'res:12', 'Pas de match nul', P('res:12'), 'haute');
  add('Résultat', 'res:N2', `${A} ou nul`, P('res:N2'), 'haute');
  const p1 = P('res:1'), p2 = P('res:2');
  if (p1 + p2 > 0) {
    add('Résultat', 'res:dnb1', `${H}, remboursé si nul`, p1 / (p1 + p2), 'haute', { joint: false });
    add('Résultat', 'res:dnb2', `${A}, remboursé si nul`, p2 / (p1 + p2), 'haute', { joint: false });
  }

  // ---- Buts
  for (const l of [0.5, 1.5, 2.5, 3.5, 4.5]) add('Buts', `buts:over:${l}`, `+${fr(l)} buts`, P(`buts:over:${l}`), 'haute');
  for (const l of [1.5, 2.5, 3.5, 4.5]) add('Buts', `buts:under:${l}`, `−${fr(l)} buts`, P(`buts:under:${l}`), 'haute');
  add('Buts', 'buts:btts:oui', 'Les 2 équipes marquent', P('buts:btts:oui'), 'haute');
  add('Buts', 'buts:btts:non', 'Une équipe ne marque pas', P('buts:btts:non'), 'haute');
  for (const l of [0.5, 1.5, 2.5]) {
    add('Buts', `buts:home:over:${l}`, `${H} +${fr(l)} but${l > 1 ? 's' : ''}`, P(`buts:home:over:${l}`), 'haute');
    add('Buts', `buts:away:over:${l}`, `${A} +${fr(l)} but${l > 1 ? 's' : ''}`, P(`buts:away:over:${l}`), 'haute');
  }
  add('Buts', 'buts:cs:home', `${H} garde sa cage inviolée`, P('buts:cs:home'), 'haute');
  add('Buts', 'buts:cs:away', `${A} garde sa cage inviolée`, P('buts:cs:away'), 'haute');

  // ---- Handicap (lignes en .5 : le résultat du match avec un avantage ou un retard de buts)
  for (const l of [1.5, 2.5]) {
    add('Handicap', `hand:home:-${l}`, `${H} −${fr(l)}`, P(`hand:home:-${l}`), 'haute');
    add('Handicap', `hand:away:+${l}`, `${A} +${fr(l)}`, P(`hand:away:+${l}`), 'haute');
    add('Handicap', `hand:away:-${l}`, `${A} −${fr(l)}`, P(`hand:away:-${l}`), 'haute');
    add('Handicap', `hand:home:+${l}`, `${H} +${fr(l)}`, P(`hand:home:+${l}`), 'haute');
  }

  // ---- Score
  add('Score', 'score:wtn:home', `${H} gagne sans encaisser`, P('score:wtn:home'), 'moyenne');
  add('Score', 'score:wtn:away', `${A} gagne sans encaisser`, P('score:wtn:away'), 'moyenne');
  add('Score', 'score:margin2:home', `${H} gagne de 2 buts ou plus`, P('hand:home:-1.5'), 'moyenne');
  add('Score', 'score:margin2:away', `${A} gagne de 2 buts ou plus`, P('hand:away:-1.5'), 'moyenne');
  let scores = [];
  for (let i = 0; i < 6; i++) for (let j = 0; j < 6; j++) scores.push({ i, j, p: matrix[i][j] });
  scores.sort((a, b) => b.p - a.p);
  for (const s of scores.slice(0, 3)) add('Score', `score:exact:${s.i}-${s.j}`, `Score exact ${s.i}-${s.j}`, s.p, 'faible');

  // ---- Mi-temps : modèle par période (1re et 2e mi-temps indépendantes)
  const m1 = scoreMatrix(lamHome * share, lamAway * share, { rho });
  const m2 = scoreMatrix(lamHome * (1 - share), lamAway * (1 - share), { rho });
  const mtFiab = 'moyenne';
  add('Mi-temps', 'mt:1h:over:0.5', '+0,5 but en 1re mi-temps', sumWhere(m1, (i, j) => i + j > 0.5), mtFiab);
  add('Mi-temps', 'mt:1h:over:1.5', '+1,5 buts en 1re mi-temps', sumWhere(m1, (i, j) => i + j > 1.5), mtFiab);
  add('Mi-temps', 'mt:1h:under:1.5', '−1,5 buts en 1re mi-temps', sumWhere(m1, (i, j) => i + j < 1.5), mtFiab);
  add('Mi-temps', 'mt:1h:lead:home', `${H} mène à la mi-temps`, sumWhere(m1, (i, j) => i > j), mtFiab);
  add('Mi-temps', 'mt:1h:draw', 'Nul à la mi-temps', sumWhere(m1, (i, j) => i === j), mtFiab);
  add('Mi-temps', 'mt:1h:lead:away', `${A} mène à la mi-temps`, sumWhere(m1, (i, j) => i < j), mtFiab);
  const t1 = totalsOf(m1), t2 = totalsOf(m2);
  let more2 = 0;
  for (let a = 0; a < t1.length; a++) for (let b = 0; b < t2.length; b++) if (b > a) more2 += t1[a] * t2[b];
  add('Mi-temps', 'mt:2h:more', 'Plus de buts en 2e mi-temps', more2, mtFiab);
  // mi-temps / fin de match : « X mène à la mi-temps et gagne »
  let htftHome = 0, htftAway = 0;
  for (let a1 = 0; a1 < m1.length; a1++) for (let b1 = 0; b1 < m1[a1].length; b1++) {
    const r1 = rsl(a1, b1);
    if (r1 === 0) continue;
    for (let a2 = 0; a2 < m2.length; a2++) for (let b2 = 0; b2 < m2[a2].length; b2++) {
      const r2 = rsl(a1 + a2, b1 + b2);
      const p = m1[a1][b1] * m2[a2][b2];
      if (r1 === 1 && r2 === 1) htftHome += p;
      if (r1 === -1 && r2 === -1) htftAway += p;
    }
  }
  add('Mi-temps', 'mt:htft:home', `${H} mène à la mi-temps et gagne`, htftHome, mtFiab);
  add('Mi-temps', 'mt:htft:away', `${A} mène à la mi-temps et gagne`, htftAway, mtFiab);

  // ---- Corners, tirs, cartons, fautes, hors-jeux
  for (const [kind, def] of Object.entries(COUNT_DEFS)) {
    const c = input.counts && input.counts[kind];
    if (!c || !(c.muHome > 0) || !(c.muAway > 0)) continue;
    const cm = counts.countMarkets(kind, c.muHome, c.muAway, def.lines, def.team);
    for (const l of def.lines) add(def.famille, `${kind}:total:${l}`, `+${fr(l)} ${def.unit}`, cm.total[l], def.fiab);
    for (const l of def.team) {
      add(def.famille, `${kind}:home:${l}`, `${H} +${fr(l)} ${def.unit}`, cm.home[l], def.fiab);
      add(def.famille, `${kind}:away:${l}`, `${A} +${fr(l)} ${def.unit}`, cm.away[l], def.fiab);
    }
    if (def.cmp) {
      add(def.famille, `${kind}:more:home`, `${H} plus de ${def.unit} que ${A}`, cm.cmp.gt, def.fiab);
      add(def.famille, `${kind}:more:away`, `${A} plus de ${def.unit} que ${H}`, cm.cmp.lt, def.fiab);
    }
  }

  // ---- Spéciaux : premier but, minute du but, penalty, carton rouge
  const lam = lamHome + lamAway;
  const p00 = matrix[0][0];
  add('Spéciaux', 'spec:first:home', `${H} marque en premier`, (lamHome / lam) * (1 - p00), 'moyenne');
  add('Spéciaux', 'spec:first:away', `${A} marque en premier`, (lamAway / lam) * (1 - p00), 'moyenne');
  add('Spéciaux', 'spec:goal30', 'Un but avant la 30e minute', 1 - Math.exp(-lam * (30 / 90)), 'moyenne');
  add('Spéciaux', 'spec:goal75', 'Un but après la 75e minute', 1 - Math.exp(-lam * (15 / 90)), 'moyenne');
  const br = input.baseRates || {};
  add('Spéciaux', 'spec:penalty', 'Penalty dans le match', br.penalty == null ? 0.26 : br.penalty, 'faible');
  add('Spéciaux', 'spec:red', 'Un carton rouge', br.red == null ? 0.09 : br.red, 'faible');

  marches.sort((a, b) => FAMILLES.indexOf(a.famille) - FAMILLES.indexOf(b.famille));
  return { matrix, marches };
}

module.exports = { FAMILLES, buildMarkets, fr, pctOf };
