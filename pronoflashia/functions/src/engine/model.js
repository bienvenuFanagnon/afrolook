'use strict';
// Orchestration : des statistiques d'équipes (et des cotes si on en a) vers un pronostic complet.
// Les chiffres viennent d'ici, jamais de l'IA.

const { expectedGoals, fitToMarket, impliedFromOdds, result1x2, sumWhere } = require('./poisson');
const { expectedCount, refereeFactor } = require('./counts');
const { buildMarkets } = require('./markets');
const { pickMarkets } = require('./pick');
const { makeCalibration } = require('./learn');

// pf-2 : probabilités corrigées par le bilan réel (engine/learn.js), valeurs brutes conservées
const MODEL_VERSION = 'pf-2';

/** Arrondit trois pourcentages pour que leur somme fasse 100 (plus grand reste). */
function round100(values) {
  const raw = values.map((v) => v * 100);
  const fl = raw.map(Math.floor);
  let rest = 100 - fl.reduce((a, b) => a + b, 0);
  const order = raw.map((v, i) => [v - Math.floor(v), i]).sort((a, b) => b[0] - a[0]);
  for (let k = 0; rest > 0 && k < order.length; k++, rest--) fl[order[k][1]]++;
  return fl;
}

/**
 * input = {
 *   home, away: { nom, nomCourt },
 *   stats: { home: { home:{games,gf,ga}, all:{...} }, away: { away:{...}, all:{...} } },
 *   league: { avgHome, avgAway, counts?: { corners:{avgHome,avgAway}, ... } },
 *   counts?: { corners: { home:{for:{avg,n}, against:{avg,n}}, away:{...} }, ... },   // moyennes par équipe
 *   referee?: { cards:{avg,games} , fouls:{avg,games} },
 *   odds?: { home, draw, away, over25? },     // cotes décimales (sert seulement à recaler les chiffres)
 *   calibration?: objet de learn.buildCalibration (bilan réel), baseRates?
 *   ratings?: { lamHome, lamAway }   // buts attendus par les notes d'équipes (engine/ratings.js) ; remplacent le calcul de base quand ils existent
 * }
 */
function predictMatch(input) {
  const { home, away } = input;
  const league = input.league || {};
  // Notes d'équipes (moteur principal, validé sur des matchs passés) ; à défaut, ancien calcul sur les buts récents.
  const model = input.ratings || expectedGoals(input.stats.home, input.stats.away, league);
  const moteur = input.ratings ? 'notes' : 'base';
  let lamHome = model.lamHome;
  let lamAway = model.lamAway;
  let source = 'stats';

  // Mélange avec les probabilités déduites des cotes, quand l'API en fournit.
  if (input.odds && input.odds.home > 1 && input.odds.draw > 1 && input.odds.away > 1) {
    const imp = impliedFromOdds([input.odds.home, input.odds.draw, input.odds.away]);
    if (imp) {
      const target = { p1: imp[0], pN: imp[1], p2: imp[2] };
      if (input.odds.over25 > 1) {
        // sans la cote « moins de 2,5 », on ne peut pas retirer la marge : on ne s'en sert pas
        if (input.odds.under25 > 1) target.over25 = impliedFromOdds([input.odds.over25, input.odds.under25])[0];
      }
      const fit = fitToMarket(target, { lamHome, lamAway });
      const w = 0.5;
      lamHome = (1 - w) * lamHome + w * fit.lamHome;
      lamAway = (1 - w) * lamAway + w * fit.lamAway;
      source = 'stats+cotes';
    }
  }

  // Apprentissage : le niveau de buts (domicile / extérieur) est corrigé par l'écart constaté entre buts prévus et buts réels.
  // Les estimations brutes sont conservées : c'est contre elles que le bilan mesure l'écart, jamais contre les valeurs corrigées.
  const cal = makeCalibration(input.calibration);
  const lamBrutHome = lamHome;
  const lamBrutAway = lamAway;
  if (cal && cal.goalScale) { lamHome *= cal.goalScale.home; lamAway *= cal.goalScale.away; }

  // Moyennes attendues pour les marchés de comptage
  const counts = {};
  for (const [kind, c] of Object.entries(input.counts || {})) {
    const lg = (league.counts && league.counts[kind]) || null;
    if (!lg) continue;
    const ref = input.referee && input.referee[kind];
    const rf = ref ? refereeFactor(ref.avg, ref.games, (lg.avgHome + lg.avgAway)) : 1;
    counts[kind] = {
      muHome: expectedCount(c.home.for, c.away.against, lg.avgHome, kind === 'cards' || kind === 'fouls' ? rf : 1),
      muAway: expectedCount(c.away.for, c.home.against, lg.avgAway, kind === 'cards' || kind === 'fouls' ? rf : 1),
    };
  }

  const games = Math.min(
    (input.stats.home.all && input.stats.home.all.games) || 0,
    (input.stats.away.all && input.stats.away.all.games) || 0
  );
  const built = buildMarkets({ home, away, lamHome, lamAway, sampleGames: games || null, counts, baseRates: input.baseRates });
  const { matrix, marches } = built;
  const r = result1x2(matrix);
  // probabilité brute gardée sur chaque pari (pctBrut) ; pct devient la probabilité corrigée par le bilan, affichée partout
  for (const m of marches) m.pctBrut = m.pct;
  if (cal) for (const m of marches) m.pct = cal.market(m.cle, m.famille, m.pctBrut);
  const byKey = (k) => marches.find((m) => m.cle === k);
  let [p1, pN, p2] = round100([r.p1, r.pN, r.p2]);
  const c1 = byKey('res:1'), cN = byKey('res:N'), c2 = byKey('res:2');
  if (cal && c1 && cN && c2) {
    const tot = c1.pct + cN.pct + c2.pct;
    [p1, pN, p2] = round100([c1.pct / tot, cN.pct / tot, c2.pct / tot]);
  }

  let best = { p: -1, i: 0, j: 0 };
  for (let i = 0; i < 7; i++) for (let j = 0; j < 7; j++) if (matrix[i][j] > best.p) best = { p: matrix[i][j], i, j };

  const { principal, secondaires } = pickMarkets(marches, home, away);

  return {
    version: MODEL_VERSION,
    source,
    lamHome: Math.round(lamHome * 100) / 100,
    lamAway: Math.round(lamAway * 100) / 100,
    lamBrutHome: Math.round(lamBrutHome * 1000) / 1000,
    lamBrutAway: Math.round(lamBrutAway * 1000) / 1000,
    calibre: !!cal,
    moteur,
    probas: { '1': p1, N: pN, '2': p2 },
    plus25: cal && byKey('buts:over:2.5') ? byKey('buts:over:2.5').pct : Math.round(sumWhere(matrix, (i, j) => i + j > 2.5) * 100),
    bttsOui: cal && byKey('buts:btts:oui') ? byKey('buts:btts:oui').pct : Math.round(sumWhere(matrix, (i, j) => i > 0 && j > 0) * 100),
    scoreProbable: `${best.i}-${best.j}`,
    principal,
    secondaires,
    marches,
    // matrice tronquée à 0..6 buts (suffit pour recalculer les combinaisons dans un même match)
    matrice: matrix.slice(0, 7).map((row) => row.slice(0, 7).map((x) => Math.round(x * 1e5) / 1e5)),
    counts: Object.fromEntries(Object.entries(counts).map(([k, v]) => [k, { muHome: round2(v.muHome), muAway: round2(v.muAway) }])),
  };
}

const round2 = (x) => Math.round(x * 100) / 100;

module.exports = { MODEL_VERSION, predictMatch, round100 };
