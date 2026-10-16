'use strict';
// Apprentissage par le bilan : le moteur compare ses probabilités brutes aux issues réelles et corrige ses calculs.
//
// Principes (pour que l'IA s'améliore sans se tromper elle-même) :
//  - on apprend sur la probabilité BRUTE du modèle (jamais sur la valeur déjà corrigée) : pas d'auto-renforcement ;
//  - la correction est un biais (réel moins annoncé), estimé à trois niveaux emboîtés — tranche de probabilité, famille de paris,
//    pari précis — chacun « rétréci » vers le niveau du dessus selon la taille de l'échantillon (peu de données = presque pas de correction) ;
//  - la correction est plafonnée (±15 points sur une probabilité, ±10 % sur le niveau de buts) ;
//  - sous 60 pronostics terminés, aucune correction.

const MIN_TOTAL = 60;
const K_BIN = 50, K_FAMILY = 60, K_KEY = 40;
const MAX_SHIFT = 15;
const MIN_KEY = 10;
const safeKey = (k) => String(k).replace(/[.:\/\s]+/g, '_');
const clamp = (x, a, b) => Math.min(b, Math.max(a, x));
const shrink = (obs, prior, n, K) => (n * obs + K * prior) / (n + K);
const r3 = (x) => Math.round(x * 1000) / 1000;

/**
 * summary : résultat de bilan.summarize() (champ cal). Renvoie un objet petit et sérialisable, ou null si l'échantillon est trop faible :
 * { n, global, bins:[{from,to,n,bias}], familles:{f:{n,bias}}, cles:{k:{n,bias,reel,brut}}, goalScale:{n,home,away}|null }
 * Les biais sont en probabilité (0,05 = le réel dépasse l'annoncé de 5 points).
 */
function buildCalibration(summary) {
  if (!summary || !summary.cal || !summary.n || summary.n < MIN_TOTAL) return null;
  const c = summary.cal;
  const biasOf = (v) => v.ok / v.n - v.brut / 100;
  let tn = 0, tb = 0;
  for (const b of c.bins) { tn += b.n; tb += b.n * biasOf(b); }
  const global = tn ? tb / tn : 0;
  const out = {
    n: summary.n, global: r3(global),
    bins: c.bins.map((b) => ({ from: b.from, to: b.to, n: b.n, bias: r3(biasOf(b)) })),
    familles: {}, cles: {}, goalScale: null,
  };
  for (const [k, v] of Object.entries(c.familles || {})) if (v.n >= 10) out.familles[k] = { n: v.n, bias: r3(biasOf(v)) };
  for (const [k, v] of Object.entries(c.cles || {})) if (v.n >= MIN_KEY) out.cles[k] = { n: v.n, bias: r3(biasOf(v)), reel: Math.round((v.ok / v.n) * 100), brut: Math.round(v.brut) };
  const b = c.buts;
  if (b && b.n >= 40 && b.pd > 0 && b.pe > 0) {
    const w = b.n / (b.n + 100);
    out.goalScale = { n: b.n, home: r3(clamp(1 + w * (b.rd / b.pd - 1), 0.9, 1.1)), away: r3(clamp(1 + w * (b.re / b.pe - 1), 0.9, 1.1)) };
  }
  return out;
}

/** Prépare les fonctions de correction à partir de l'objet de buildCalibration. */
function makeCalibration(cal) {
  if (!cal) return null;
  const binBias = (pct) => {
    const b = (cal.bins || []).find((x) => pct >= x.from && pct < x.to);
    return b ? shrink(b.bias, cal.global, b.n, K_BIN) : cal.global;
  };
  return {
    goalScale: cal.goalScale ? { home: cal.goalScale.home, away: cal.goalScale.away } : null,
    /** Probabilité corrigée (en %) d'un pari à partir de sa probabilité brute. */
    market(cle, famille, pct) {
      let bias = binBias(pct);
      const f = cal.familles && cal.familles[safeKey(famille)];
      if (f) bias = shrink(f.bias, bias, f.n, K_FAMILY);
      const k = cal.cles && cal.cles[safeKey(cle)];
      if (k) bias = shrink(k.bias, bias, k.n, K_KEY);
      const shift = clamp(bias * 100, -MAX_SHIFT, MAX_SHIFT);
      return clamp(Math.round(pct + shift), 1, 99);
    },
  };
}

/** Taux de réussite récent d'un pari (ou, à défaut, de sa famille), pour le citer dans l'analyse. null si l'échantillon est faible. */
function trackRecord(cal, cle, famille) {
  if (!cal) return null;
  const k = cal.cles && cal.cles[safeKey(cle)];
  if (k && k.n >= 15) return { niveau: 'pari', n: k.n, reel: k.reel };
  return null;
}

/**
 * Ce que l'IA a corrigé, en clair : familles et paris dont le modèle se trompait d'au moins 3 points (échantillon suffisant).
 * ecart > 0 : le modèle sous-estimait ; ecart < 0 : il surestimait.
 */
function describe(cal) {
  if (!cal) return { actif: false, familles: [], paris: [], buts: null, global: 0, n: 0 };
  const pts = (b) => Math.round(b * 100);
  const familles = Object.entries(cal.familles || {}).filter(([, v]) => v.n >= 30 && Math.abs(pts(v.bias)) >= 3)
    .map(([nom, v]) => ({ nom, n: v.n, ecart: pts(v.bias) })).sort((a, b) => Math.abs(b.ecart) - Math.abs(a.ecart));
  const paris = Object.entries(cal.cles || {}).filter(([, v]) => v.n >= 25 && Math.abs(pts(v.bias)) >= 5)
    .map(([cle, v]) => ({ cle, n: v.n, ecart: pts(v.bias), reel: v.reel, brut: v.brut })).sort((a, b) => Math.abs(b.ecart) - Math.abs(a.ecart)).slice(0, 10);
  const g = cal.goalScale;
  const buts = g && (Math.abs(g.home - 1) >= 0.02 || Math.abs(g.away - 1) >= 0.02) ? { n: g.n, domicile: Math.round((g.home - 1) * 100), exterieur: Math.round((g.away - 1) * 100) } : null;
  return { actif: true, n: cal.n, global: pts(cal.global), familles, paris, buts };
}

module.exports = { MIN_TOTAL, buildCalibration, makeCalibration, trackRecord, describe, safeKey };
