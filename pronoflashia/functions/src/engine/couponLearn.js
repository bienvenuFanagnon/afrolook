'use strict';
// Ce que l'IA apprend de SES coupons.
// Chaque sélection d'un coupon archivé finit réussie ou ratée. On compare le taux de réussite des sélections choisies pour les coupons à la
// probabilité BRUTE annoncée par le moteur (jamais à la valeur déjà ajustée : pas d'auto-renforcement), par type de pari (famille) :
// choisir « le pari le plus probable du match » favorise les paris que le modèle surestime, et les coupons le font payer.
// Correction : biais (réel moins annoncé) par famille, rapproché du biais global selon la taille de l'échantillon, plafonné à ±10 points,
// et aucune correction tant que moins de 40 sélections ont un résultat. Appliquée aux coupons flash (choix des paris et probabilité annoncée).

const MIN_N = 40;       // sélections avec résultat avant toute correction
const K = 30;           // poids du biais global face au biais de la famille
const MAX_SHIFT = 0.10; // ±10 points de probabilité
const DAYS = 60;
const MIN_FAMILY = 8;
const r3 = (x) => Math.round(x * 1000) / 1000;
const clamp = (x, a, b) => Math.min(b, Math.max(a, x));
const rawPct = (s) => (typeof s.pctBrut === 'number' ? s.pctBrut : s.pct);

/** coupons : documents coupons_flash (statut quelconque). Renvoie { actif, n, global, familles, majLe } ; actif = faux sous MIN_N sélections. */
function build(coupons, now) {
  const fam = {};
  let n = 0, ok = 0, sum = 0;
  for (const c of coupons || []) {
    for (const s of c.selections || []) {
      if (s.ok !== true && s.ok !== false) continue;
      const p = rawPct(s);
      if (typeof p !== 'number' || !s.famille) continue;
      const f = fam[s.famille] || (fam[s.famille] = { n: 0, ok: 0, sum: 0 });
      f.n++; f.ok += s.ok ? 1 : 0; f.sum += p;
      n++; ok += s.ok ? 1 : 0; sum += p;
    }
  }
  const out = { actif: n >= MIN_N, n, majLe: (now || new Date()).toISOString(), global: 0, familles: {} };
  if (!out.actif) return out;
  const global = clamp(ok / n - sum / n / 100, -MAX_SHIFT, MAX_SHIFT);
  out.global = r3(global);
  for (const [name, f] of Object.entries(fam)) {
    if (f.n < MIN_FAMILY) continue;
    const bias = f.ok / f.n - f.sum / f.n / 100;
    const shrunk = (f.n * bias + K * global) / (f.n + K);
    out.familles[name] = { n: f.n, reel: Math.round((f.ok / f.n) * 100), annonce: Math.round(f.sum / f.n), bias: r3(clamp(shrunk, -MAX_SHIFT, MAX_SHIFT)) };
  }
  return out;
}

/** Biais appliqué à un pari d'une famille (en probabilité, 0,05 = +5 points) ; 0 si aucun apprentissage actif. */
const biasFor = (L, famille) => (L && L.actif ? (L.familles && L.familles[famille] ? L.familles[famille].bias : L.global || 0) : 0);

/** Probabilité (en %) corrigée d'un pari. */
const adjustPct = (pct, famille, L) => Math.round(clamp(pct + biasFor(L, famille) * 100, 1, 99));

/** Copie de la réserve de paris { matchId: [options] } avec probabilités corrigées (pctBrut garde la valeur du moteur). */
function applyToPool(poolMap, L) {
  if (!L || !L.actif) return poolMap;
  const out = {};
  for (const [id, opts] of Object.entries(poolMap)) out[id] = opts.map((o) => Object.assign({}, o, { pctBrut: o.pct, pct: adjustPct(o.pct, o.famille, L) }));
  return out;
}

module.exports = { MIN_N, MAX_SHIFT, DAYS, build, biasFor, adjustPct, applyToPool };
