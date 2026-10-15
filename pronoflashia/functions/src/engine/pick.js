'use strict';
// Choix du pronostic principal et des paris secondaires.
// Règle : le pari le plus utile, pas toujours le plus probable. Une double chance à 85 % est banale ;
// on la propose seulement si aucun marché plus informatif n'atteint le seuil de confiance.

const MIN_PCT = 55;

/** Poids d'utilité par marché : 1 = pari informatif, moins de 1 = pari banal qui gonfle la probabilité sans apporter d'information. */
const WEIGHTS = {
  'res:1': 1.15, 'res:2': 1.15, 'res:N': 0.9,
  'res:1N': 0.8, 'res:N2': 0.8, 'res:12': 0.85,
  'buts:over:2.5': 0.95, 'buts:under:2.5': 0.95, 'buts:over:3.5': 1, 'buts:under:3.5': 0.8, 'buts:over:1.5': 0.75,
  'buts:btts:oui': 0.95, 'buts:btts:non': 0.9,
  'hand:home:-1.5': 1, 'hand:away:-1.5': 1,
};

/** Libellé d'affichage du pronostic principal. */
function principalLabel(m, home, away) {
  const H = home.nomCourt || home.nom;
  const A = away.nomCourt || away.nom;
  switch (m.cle) {
    case 'res:1': return `1 · ${H}`;
    case 'res:2': return `2 · ${A}`;
    case 'res:N': return 'N · Match nul';
    case 'res:1N': return `1N · ${H} ou nul`;
    case 'res:N2': return `N2 · ${A} ou nul`;
    case 'res:12': return '12 · Pas de nul';
    default: return m.libelle;
  }
}

/**
 * marches : liste issue de buildMarkets. Renvoie { principal, secondaires }.
 * calibrate(pct) : fonction facultative qui corrige la probabilité avec le bilan réel.
 */
function pickMarkets(marches, home, away, calibrate) {
  const cal = calibrate || ((x) => x);
  const cands = marches.filter((m) => WEIGHTS[m.cle] != null && m.pct >= MIN_PCT);
  let best = null;
  for (const m of cands) {
    const score = m.pct * WEIGHTS[m.cle];
    if (!best || score > best.score || (score === best.score && m.pct > best.m.pct)) best = { m, score };
  }
  let basse = false;
  if (!best) {
    // Aucun pari assez probable : on prend le résultat simple le plus probable et on le signale.
    const simples = marches.filter((m) => ['res:1', 'res:N', 'res:2'].includes(m.cle));
    const m = simples.sort((a, b) => b.pct - a.pct)[0];
    best = { m, score: m.pct };
    basse = true;
  }
  const principal = {
    marche: best.m.cle.startsWith('res:') ? best.m.cle.slice(4) : best.m.cle,
    cle: best.m.cle,
    libelle: principalLabel(best.m, home, away),
    confiance: Math.max(1, Math.min(99, Math.round(cal(best.m.pct)))),
    basseConfiance: basse,
  };
  // Secondaires : deux autres paris informatifs, de familles différentes du pronostic principal.
  const sec = [];
  const taken = new Set([best.m.cle]);
  const others = marches
    .filter((m) => WEIGHTS[m.cle] != null && m.pct >= 50 && !taken.has(m.cle))
    .sort((a, b) => b.pct * WEIGHTS[b.cle] - a.pct * WEIGHTS[a.cle]);
  for (const m of others) {
    const kind = m.cle.split(':')[0] + ':' + (m.cle.split(':')[1] || '');
    if (sec.some((s) => s.kind === kind) || kind === best.m.cle.split(':')[0] + ':' + (best.m.cle.split(':')[1] || '')) continue;
    sec.push({ kind, cle: m.cle, libelle: m.libelle, pct: m.pct });
    if (sec.length === 2) break;
  }
  return { principal, secondaires: sec.map(({ cle, libelle, pct }) => ({ cle, libelle, pct })) };
}

/**
 * Calibration : corrige une probabilité annoncée avec le taux réellement observé dans la même tranche.
 * bins : [{ from, to, annonce, reel, n }] issus du bilan. Mélange progressif selon la taille de l'échantillon.
 */
function makeCalibrator(bins) {
  if (!bins || !bins.length) return (x) => x;
  return (pct) => {
    const b = bins.find((x) => pct >= x.from && pct < x.to);
    if (!b || !(b.n > 0)) return pct;
    const w = b.n / (b.n + 40);
    return (1 - w) * pct + w * b.reel;
  };
}

module.exports = { MIN_PCT, WEIGHTS, pickMarkets, principalLabel, makeCalibrator };
