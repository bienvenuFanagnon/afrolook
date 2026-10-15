'use strict';
// Bilan public : compteurs par jour, agrégés à la demande. Un match n'est compté qu'une fois.

/** Clé sûre pour un nom de champ Firestore (pas de point ni deux-points). */
const safeKey = (k) => String(k).replace(/[.:\/\s]+/g, '_');

const binOf = (pct) => Math.floor(pct / 5) * 5;

/**
 * match : { leagueId, prono:{ principal:{cle,confiance}, marches:[{cle,famille,pct,fiabilite}] }, resultat:{ marches:{cle:bool}, reussi } }
 * Renvoie le delta à ajouter aux compteurs du jour : n, ok pour le pronostic principal ; ensemble des marchés fiables pour la calibration.
 */
function matchDelta(match) {
  const pr = match.prono && match.prono.principal;
  const res = match.resultat || {};
  if (!pr || res.reussi == null) return null;
  const ok = res.reussi ? 1 : 0;
  const d = {
    matches: 1,
    principal: { n: 1, ok },
    parLigue: { [safeKey(match.leagueId)]: { n: 1, ok } },
    parConfiance: { [binOf(pr.confiance)]: { n: 1, ok, sum: pr.confiance } },
    parFamille: {},
    parBin: {},
    parCle: {},
  };
  for (const m of match.prono.marches || []) {
    if (m.fiabilite === 'faible') continue;
    const r = res.marches && res.marches[m.cle];
    if (r === undefined) continue;
    const o = r ? 1 : 0;
    const f = safeKey(m.famille);
    d.parFamille[f] = add(d.parFamille[f], 1, o, m.pct);
    const b = binOf(m.pct);
    d.parBin[b] = add(d.parBin[b], 1, o, m.pct);
    const k = safeKey(m.cle);
    d.parCle[k] = add(d.parCle[k], 1, o, m.pct);
  }
  // le pronostic principal compte aussi dans « par pari » : on le retrouve dans parCle s'il fait partie des marchés
  return d;
}

function add(prev, n, ok, pct) {
  const p = prev || { n: 0, ok: 0, sum: 0 };
  return { n: p.n + n, ok: p.ok + ok, sum: p.sum + pct };
}

/** Additionne deux sous-objets {clé: {n, ok, sum}}. */
function mergeMap(a, b) {
  const out = Object.assign({}, a);
  for (const [k, v] of Object.entries(b || {})) out[k] = add(out[k], v.n, v.ok, v.sum || 0);
  return out;
}

/** Additionne deux deltas (ou un jour stocké et un delta). */
function mergeDelta(a, b) {
  if (!a) return b;
  if (!b) return a;
  return {
    matches: (a.matches || 0) + (b.matches || 0),
    principal: { n: (a.principal.n || 0) + (b.principal.n || 0), ok: (a.principal.ok || 0) + (b.principal.ok || 0) },
    parLigue: mergeMap(a.parLigue, b.parLigue),
    parConfiance: mergeMap(a.parConfiance, b.parConfiance),
    parFamille: mergeMap(a.parFamille, b.parFamille),
    parBin: mergeMap(a.parBin, b.parBin),
    parCle: mergeMap(a.parCle, b.parCle),
  };
}

const pct = (ok, n) => (n > 0 ? Math.round((ok / n) * 100) : null);

/** Résumé pour la page Bilan et pour la calibration, à partir d'une liste de jours. */
function summarize(days) {
  const t = days.reduce((acc, d) => mergeDelta(acc, d), null);
  if (!t) return { matches: 0, n: 0, ok: 0, taux: null, parLigue: {}, parConfiance: [], parFamille: {}, bins: [] };
  const rows = (map) => Object.entries(map).map(([k, v]) => ({ k, n: v.n, ok: v.ok, taux: pct(v.ok, v.n), annonce: v.n ? Math.round(v.sum / v.n) : null }));
  return {
    matches: t.matches,
    n: t.principal.n,
    ok: t.principal.ok,
    ko: t.principal.n - t.principal.ok,
    taux: pct(t.principal.ok, t.principal.n),
    parLigue: Object.fromEntries(Object.entries(t.parLigue).map(([k, v]) => [k, { n: v.n, ok: v.ok, taux: pct(v.ok, v.n) }])),
    parConfiance: rows(t.parConfiance).sort((a, b) => a.k - b.k),
    parFamille: Object.fromEntries(rows(t.parFamille).map((r) => [r.k, r])),
    // tranches de 5 points : probabilité annoncée contre taux réel, sert à calibrer
    bins: rows(t.parBin).map((r) => ({ from: +r.k, to: +r.k + 5, annonce: r.annonce, reel: r.taux, n: r.n })).sort((a, b) => a.from - b.from),
  };
}

/** Taux par pari sur les n derniers jours, pour la page « Nos résultats » d'un match. */
function rateByKey(days, minN = 15) {
  const t = days.reduce((acc, d) => mergeDelta(acc, d), null);
  const out = {};
  if (!t) return out;
  for (const [k, v] of Object.entries(t.parCle)) if (v.n >= minN) out[k] = { n: v.n, annonce: Math.round(v.sum / v.n), reel: pct(v.ok, v.n) };
  return out;
}

module.exports = { safeKey, binOf, matchDelta, mergeDelta, summarize, rateByKey };
