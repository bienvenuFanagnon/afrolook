'use strict';
// Notes d'équipes : c'est la « mémoire » de l'IA sur chaque club.
// Pour chaque équipe, une note d'attaque (A) et une note de faiblesse défensive (B, plus elle est basse, meilleure est la défense),
// estimées sur TOUS les matchs connus (saison précédente comprise), en comptant plus les matchs récents (décroissance exponentielle)
// et en tenant compte du niveau des adversaires affrontés. Buts attendus : domicile = c × H × A(dom) × B(ext) ; extérieur = c × A(ext) × B(dom).
// Avant d'être utilisées, les notes sont jugées sur des matchs passés (walk-forward : à chaque match, seul le passé est connu).
// Mesuré sur 1 510 matchs réels (5 championnats, saison 2023-24, avec 2022-23 comme historique) : vraisemblance des buts
// −2,9643 → −2,9254 par match et score de probabilité (RPS) 0,2014 → 0,1962 par rapport à l'ancien calcul (voir scripts/backtest.js).

const { expectedGoals, poissonPmf, scoreMatrix, result1x2 } = require('./poisson');
const { goalStats } = require('../data/normalize');

const HALF_LIFE = 240;   // jours : un match vieux de 240 jours compte moitié moins
const PSEUDO = 6;        // pseudo-buts « dans la moyenne » : retient les notes d'une équipe qui a peu joué
const ITERS = 25;
const MIN_PRIOR = 5;     // matchs de la saison déjà joués par chaque équipe avant de la juger
const MIN_LEAGUE = 20;
const MIN_N_JUDGE = 100; // en dessous, on ne peut pas juger : on garde les notes (elles ont fait leurs preuves ailleurs)
const DAY = 864e5;
const BUCKET = 3 * DAY;  // les notes sont recalculées au plus tous les 3 jours pendant le jugement

const round = (x, d = 4) => Math.round(x * 10 ** d) / 10 ** d;
const logPmf = (k, lam) => Math.log(Math.max(1e-12, poissonPmf(k, lam)));
const clampLam = (x) => Math.min(4.5, Math.max(0.2, x));

/**
 * matches : [{ t (ms), h, a, gh, ga }] (identifiants d'équipes en texte). Seuls les matchs avant `now` comptent.
 * Renvoie { A, B, c, H, n } ou null s'il y a moins de 10 matchs.
 */
function fitRatings(matches, now, opts = {}) {
  const halfLife = opts.halfLife || HALF_LIFE, k = opts.k == null ? PSEUDO : opts.k;
  const xi = Math.log(2) / halfLife;
  const ms = [];
  for (const m of matches) if (m.t < now) ms.push({ h: m.h, a: m.a, gh: m.gh, ga: m.ga, w: Math.exp((-xi * (now - m.t)) / DAY) });
  if (ms.length < 10) return null;
  const teams = new Set();
  for (const m of ms) { teams.add(m.h); teams.add(m.a); }
  const A = new Map(), B = new Map();
  for (const t of teams) { A.set(t, 1); B.set(t, 1); }
  let c = 1.2, H = 1.25;
  const sumGa = ms.reduce((s, m) => s + m.w * m.ga, 0), sumGh = ms.reduce((s, m) => s + m.w * m.gh, 0);
  for (let it = 0; it < ITERS; it++) {
    // niveau moyen (buts à l'extérieur), puis avantage du domicile (buts à domicile)
    let dc = 0;
    for (const m of ms) dc += m.w * A.get(m.a) * B.get(m.h);
    c = dc > 0 ? sumGa / dc : 1.1;
    let dh = 0;
    for (const m of ms) dh += m.w * c * A.get(m.h) * B.get(m.a);
    H = dh > 0 ? sumGh / dh : 1.25;
    const sA = new Map(), eA = new Map(), sB = new Map(), eB = new Map();
    const add = (mp, t, v) => mp.set(t, (mp.get(t) || 0) + v);
    for (const m of ms) {
      add(sA, m.h, m.w * m.gh); add(eA, m.h, m.w * c * H * B.get(m.a));   // buts marqués par le club à domicile
      add(sB, m.a, m.w * m.gh); add(eB, m.a, m.w * c * H * A.get(m.h));   // buts encaissés par le club à l'extérieur
      add(sA, m.a, m.w * m.ga); add(eA, m.a, m.w * c * B.get(m.h));       // buts marqués par le club à l'extérieur
      add(sB, m.h, m.w * m.ga); add(eB, m.h, m.w * c * A.get(m.a));       // buts encaissés par le club à domicile
    }
    for (const t of teams) {
      A.set(t, ((sA.get(t) || 0) + k) / ((eA.get(t) || 0) + k));
      B.set(t, ((sB.get(t) || 0) + k) / ((eB.get(t) || 0) + k));
    }
    // les notes sont relatives : moyenne géométrique ramenée à 1 (le niveau général est porté par c)
    const geo = (mp) => Math.exp([...mp.values()].reduce((s, v) => s + Math.log(v), 0) / mp.size);
    const ga = geo(A), gb = geo(B);
    for (const t of teams) { A.set(t, A.get(t) / ga); B.set(t, B.get(t) / gb); }
  }
  const out = { A: {}, B: {}, c: round(c), H: round(H), n: ms.length };
  for (const t of teams) { out.A[t] = round(A.get(t)); out.B[t] = round(B.get(t)); }
  return out;
}

/** Buts attendus d'un match d'après les notes ; null si l'une des équipes n'a pas de note. */
function predictLambdas(R, home, away) {
  if (!R || R.A[home] == null || R.A[away] == null) return null;
  return { lamHome: clampLam(R.c * R.H * R.A[home] * R.B[away]), lamAway: clampLam(R.c * R.A[away] * R.B[home]) };
}

/**
 * Juge les notes sur la saison en cours, match après match, face à l'ancien calcul (buts des 20 derniers matchs de la saison).
 * prev : matchs de la saison précédente (peut être vide), cur : matchs de la saison en cours, tous au format { t, h, a, gh, ga }.
 * Renvoie { n, gain, rps } : gain > 0 si les notes expliquent mieux les buts réels (moyenne par match du logarithme de la vraisemblance),
 * rps = écart moyen du score de probabilité (négatif = notes meilleures). Chaque match est jugé avec le seul passé.
 * opts.collect : tableau optionnel qui reçoit, pour chaque match jugé, { pmax, hit, nmin } (calibration du pronostic 1N2).
 */
function backtest(prev, cur, opts = {}) {
  const all = prev.concat(cur).sort((a, b) => a.t - b.t);
  const season = cur.slice().sort((a, b) => a.t - b.t);
  const done = new Map(); // équipe → matchs déjà joués cette saison {date, venue, gf, ga}
  const cache = new Map();
  let lgH = 0, lgA = 0, lgN = 0;
  let n = 0, gain = 0, rps = 0;
  const rpsOf = (lh, la, gh, ga) => {
    const r = result1x2(scoreMatrix(lh, la));
    const o = gh > ga ? 0 : gh === ga ? 1 : 2;
    const c0 = r.p1, c1 = r.p1 + r.pN;
    return (((c0 - (o === 0 ? 1 : 0)) ** 2) + ((c1 - (o <= 1 ? 1 : 0)) ** 2)) / 2;
  };
  for (const m of season) {
    const rh = done.get(m.h) || [], ra = done.get(m.a) || [];
    if (rh.length >= MIN_PRIOR && ra.length >= MIN_PRIOR && lgN >= MIN_LEAGUE) {
      const bucket = Math.floor(m.t / BUCKET);
      if (!cache.has(bucket)) cache.set(bucket, fitRatings(all, bucket * BUCKET, opts));
      const R = cache.get(bucket);
      const rat = predictLambdas(R, m.h, m.a);
      if (rat) {
        const g1 = goalStats(rh), g2 = goalStats(ra);
        const old = expectedGoals({ home: g1.home, all: g1.all }, { away: g2.away, all: g2.all }, { avgHome: lgH / lgN, avgAway: lgA / lgN });
        if (opts.collect) { const r = result1x2(scoreMatrix(rat.lamHome, rat.lamAway)); const pr = [r.p1, r.pN, r.p2]; const top = pr.indexOf(Math.max(...pr)); opts.collect.push({ pmax: pr[top], hit: top === (m.gh > m.ga ? 0 : m.gh === m.ga ? 1 : 2) ? 1 : 0, nmin: Math.min(rh.length, ra.length) }); }
        gain += logPmf(m.gh, rat.lamHome) + logPmf(m.ga, rat.lamAway) - logPmf(m.gh, old.lamHome) - logPmf(m.ga, old.lamAway);
        rps += rpsOf(rat.lamHome, rat.lamAway, m.gh, m.ga) - rpsOf(old.lamHome, old.lamAway, m.gh, m.ga);
        n++;
      }
    }
    const iso = new Date(m.t).toISOString();
    done.set(m.h, rh.concat([{ date: iso, venue: 'home', gf: m.gh, ga: m.ga }]));
    done.set(m.a, ra.concat([{ date: iso, venue: 'away', gf: m.ga, ga: m.gh }]));
    lgH += m.gh; lgA += m.ga; lgN++;
  }
  return { n, gain: n ? round(gain / n) : 0, rps: n ? round(rps / n) : 0 };
}

/** Les notes ne sont utilisées que si le jugement ne les contredit pas : peu de matchs jugés → on les garde, assez de matchs → il faut un gain. */
const isActive = (bt) => !bt || bt.n < MIN_N_JUDGE || bt.gain > 0;

/**
 * Notes à l'instant `now` et il y a 60 jours : « évolution » de chaque équipe (attaque et défense, en %).
 * Renvoie { ...notes, evol: { équipe: { atk, def } } } ou null.
 */
function ratingsWithTrend(matches, now, opts = {}) {
  const R = fitRatings(matches, now, opts);
  if (!R) return null;
  const old = fitRatings(matches, now - 60 * DAY, opts);
  R.evol = {};
  if (old) for (const t of Object.keys(R.A)) if (old.A[t] != null) R.evol[t] = { atk: Math.round((R.A[t] / old.A[t] - 1) * 100), def: Math.round((R.B[t] / old.B[t] - 1) * 100) };
  return R;
}

/**
 * Lecture d'une équipe pour l'affichage et les textes : écarts à la moyenne de la ligue en % (attaque : positif = marque plus ;
 * défense : positif = encaisse plus, donc défense moins bonne) et évolution sur 60 jours. null si l'équipe n'a pas de note.
 */
function describeTeam(R, teamId) {
  if (!R || R.A[teamId] == null) return null;
  const e = (R.evol && R.evol[teamId]) || null;
  return { attaque: Math.round((R.A[teamId] - 1) * 100), defense: Math.round((R.B[teamId] - 1) * 100), evolAttaque: e ? e.atk : null, evolDefense: e ? e.def : null };
}

module.exports = { fitRatings, predictLambdas, backtest, isActive, ratingsWithTrend, describeTeam, HALF_LIFE, PSEUDO, MIN_N_JUDGE, MIN_PRIOR };
