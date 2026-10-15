'use strict';
// Après le match : un pari est-il réussi (true), raté (false) ou non évaluable / remboursé (null) ?

const goal = require('../shared/goalmarkets');

/**
 * ctx = { score:{dom,ext}, miTemps:{dom,ext}|null, stats:{ home:{corners,...}, away:{...} }|null }
 */
function evaluateMarket(cle, ctx) {
  const { score, miTemps, stats } = ctx;
  if (!score) return null;
  const p = cle.split(':');

  if (cle === 'res:dnb1') return score.dom === score.ext ? null : score.dom > score.ext;
  if (cle === 'res:dnb2') return score.dom === score.ext ? null : score.ext > score.dom;

  const pred = goal.predicateFor(cle);
  if (pred) return pred(score.dom, score.ext);
  if (p[0] === 'score' && p[1] === 'margin2') return p[2] === 'home' ? score.dom - score.ext >= 2 : score.ext - score.dom >= 2;

  if (p[0] === 'mt') {
    if (!miTemps) return null;
    const h1 = miTemps.dom, a1 = miTemps.ext;
    const t1 = h1 + a1;
    if (p[1] === '1h') {
      if (p[2] === 'over') return t1 > parseFloat(p[3]);
      if (p[2] === 'under') return t1 < parseFloat(p[3]);
      if (p[2] === 'lead') return p[3] === 'home' ? h1 > a1 : a1 > h1;
      if (p[2] === 'draw') return h1 === a1;
    }
    if (p[1] === '2h' && p[2] === 'more') return score.dom + score.ext - t1 > t1;
    if (p[1] === 'htft') return p[2] === 'home' ? h1 > a1 && score.dom > score.ext : a1 > h1 && score.ext > score.dom;
    return null;
  }

  // comptages : corners, tirs, cartons, fautes, hors-jeux
  if (['corners', 'shotsOnTarget', 'shots', 'cards', 'fouls', 'offsides'].includes(p[0])) {
    if (!stats || !stats.home || !stats.away) return null;
    const h = stats.home[p[0]], a = stats.away[p[0]];
    if (h == null || a == null) return null;
    if (p[1] === 'total') return h + a > parseFloat(p[2]);
    if (p[1] === 'home') return h > parseFloat(p[2]);
    if (p[1] === 'away') return a > parseFloat(p[2]);
    if (p[1] === 'more') return p[2] === 'home' ? h > a : a > h;
    return null;
  }

  // spéciaux : nécessitent le détail des événements du match, non récupéré pour l'instant
  return null;
}

/** Évalue la liste complète des marchés d'un match → { cle: true | false } (les non évaluables sont omis). */
function evaluateAll(marches, ctx) {
  const out = {};
  for (const m of marches || []) {
    const r = evaluateMarket(m.cle, ctx);
    if (r !== null) out[m.cle] = r;
  }
  return out;
}

module.exports = { evaluateMarket, evaluateAll };
