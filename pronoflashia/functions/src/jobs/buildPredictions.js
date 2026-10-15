'use strict';
// buildPredictions : calcule le pronostic de chaque match à venir, puis demande le texte à l'IA.

const N = require('../data/normalize');
const { predictMatch, MODEL_VERSION } = require('../engine/model');
const { generateText } = require('../ai/generate');
const { summarize } = require('../engine/bilan');
const { dayStr, addDays } = require('./helpers');
const { assertQuota, COUNT_KINDS } = require('./syncFixtures');
const { dateLongue, heure, fr } = require('../util/format');

const COUNT_LABELS = { corners: 'Corners', shotsOnTarget: 'Tirs cadrés', shots: 'Tirs', cards: 'Cartons', fouls: 'Fautes', offsides: 'Hors-jeux' };

/** Calibration : tranches du bilan sur 90 jours, utilisées seulement quand l'échantillon est assez grand. */
async function loadCalibration(db, now) {
  const since = dayStr(addDays(now, -90));
  const snap = await db.collection('bilan_days').where('jour', '>=', since).get();
  const days = snap.docs.map((d) => d.data().delta).filter(Boolean);
  const s = summarize(days);
  return s.n >= 60 ? s.bins : null;
}

/** Tableau comparatif affiché sur la page « analyse complète ». */
function buildComparatif(recentH, recentA, gsH, gsA) {
  const avg = (b, f) => (b.games ? Math.round((b[f] / b.games) * 100) / 100 : null);
  const rows = [
    { cle: 'buts_marques', label: 'Buts marqués', dom: avg(gsH.home, 'gf'), ext: avg(gsA.away, 'gf') },
    { cle: 'buts_encaisses', label: 'Buts encaissés', dom: avg(gsH.home, 'ga'), ext: avg(gsA.away, 'ga'), inverse: true },
  ];
  for (const kind of COUNT_KINDS) {
    const h = N.countAverages(recentH, kind), a = N.countAverages(recentA, kind);
    if (h && a) rows.push({ cle: kind, label: COUNT_LABELS[kind], dom: Math.round(h.for.avg * 10) / 10, ext: Math.round(a.for.avg * 10) / 10, inverse: kind === 'cards' || kind === 'fouls' });
  }
  const pts = (arr) => arr.slice().sort((x, y) => (x.date < y.date ? 1 : -1)).slice(0, 5).reduce((s, e) => s + (e.gf > e.ga ? 3 : e.gf === e.ga ? 1 : 0), 0);
  if (recentH.length >= 5 && recentA.length >= 5) rows.push({ cle: 'points5', label: 'Points sur les 5 derniers', dom: pts(recentH), ext: pts(recentA) });
  return rows.filter((r) => r.dom != null && r.ext != null);
}

/** Lignes de faits envoyées à l'IA (tous les chiffres qu'elle a le droit de citer). */
function buildFacts(match, gsH, gsA, h2h) {
  const D = match.domicile.nomCourt, E = match.exterieur.nomCourt;
  const extras = [];
  if (gsH.home.games) extras.push(`${D} marque ${fr(gsH.home.gf / gsH.home.games, 1)} buts par match à domicile et en encaisse ${fr(gsH.home.ga / gsH.home.games, 1)}.`);
  if (gsA.away.games) extras.push(`${E} marque ${fr(gsA.away.gf / gsA.away.games, 1)} buts par match à l'extérieur et en encaisse ${fr(gsA.away.ga / gsA.away.games, 1)}.`);
  const lines = [];
  if (h2h && h2h.length) {
    const dw = h2h.filter((x) => (x.domId === match.domicile.apiId ? x.sd > x.se : x.se > x.sd)).length;
    const ew = h2h.filter((x) => (x.domId === match.exterieur.apiId ? x.sd > x.se : x.se > x.sd)).length;
    const nul = h2h.length - dw - ew;
    lines.push(`Sur les ${h2h.length} dernières confrontations : ${dw} victoire${dw > 1 ? 's' : ''} de ${D}, ${nul} nul${nul > 1 ? 's' : ''}, ${ew} victoire${ew > 1 ? 's' : ''} de ${E}.`);
  }
  return { extras, h2h: lines };
}

async function fetchOdds(api, match) {
  try { return N.normalizeOdds(await api.odds(match.apiId)); } catch { return null; }
}

async function fetchH2h(api, match) {
  try {
    const rows = await api.headToHead(`${match.domicile.apiId}-${match.exterieur.apiId}`, 5);
    return rows.map(N.normalizeFixture).filter((f) => f.statut === 'termine' && f.score)
      .map((f) => ({ date: f.coupDEnvoi.slice(0, 10), domId: f.domicile.apiId, dom: f.domicile.nom, ext: f.exterieur.nom, sd: f.score.dom, se: f.score.ext }));
  } catch { return null; }
}

/** Compteurs de l'état de l'IA pour la journée. */
async function bumpAiStatus(db, now, { fournisseur, secours, erreurs, latencyMs }) {
  const ref = db.collection('ai_status').doc('current');
  const cur = (await ref.get()).data() || {};
  const jour = dayStr(now);
  const base = cur.jour === jour ? cur : { generesAujourdhui: 0, secoursAujourdhui: 0, quotaUtilise: 0 };
  const upd = {
    jour,
    generesAujourdhui: (base.generesAujourdhui || 0) + 1,
    secoursAujourdhui: (base.secoursAujourdhui || 0) + (secours ? 1 : 0),
    quotaUtilise: (base.quotaUtilise || 0) + (fournisseur === 'workers-ai' ? 1 : 0),
  };
  if (!secours) { upd.fournisseur = fournisseur; upd.dernierSucces = now.toISOString(); if (latencyMs) upd.latenceMs = latencyMs; }
  if (erreurs.length) { upd.derniereErreur = `${erreurs[erreurs.length - 1].provider} : ${erreurs[erreurs.length - 1].detail}`.slice(0, 300); upd.derniereErreurLe = now.toISOString(); }
  await ref.set(upd, { merge: true });
}

async function buildOne({ db, api, providers, now, match, league, formCache, calibration, quotaReserve, maxExternal }) {
  const form = async (teamId) => {
    if (!formCache.has(teamId)) { const d = await db.collection('team_form').doc(String(teamId)).get(); formCache.set(teamId, (d.exists && d.data().recent) || []); }
    return formCache.get(teamId);
  };
  const recentH = await form(match.domicile.teamId);
  const recentA = await form(match.exterieur.teamId);
  const gsH = N.goalStats(recentH), gsA = N.goalStats(recentA);
  const lgAvg = (league && league.avg) || {};
  const counts = {};
  for (const kind of COUNT_KINDS) {
    const h = N.countAverages(recentH, kind), a = N.countAverages(recentA, kind);
    if (h && a && lgAvg.counts && lgAvg.counts[kind]) counts[kind] = { home: h, away: a };
  }
  // requêtes externes facultatives (cotes, confrontations directes) : seulement si le quota le permet
  const hoursTo = (new Date(match.coupDEnvoi) - now) / 3600e3;
  let used = 0;
  const canCall = () => used < maxExternal && !(api.quota.dayRemaining != null && api.quota.dayRemaining < quotaReserve);
  let cotes = match.cotes || null;
  if (!cotes && hoursTo <= 48 && canCall()) { used++; cotes = await fetchOdds(api, match); }
  let h2h = match.h2h || null;
  if (!h2h && canCall()) { used++; h2h = await fetchH2h(api, match); }

  const pred = predictMatch({
    home: match.domicile, away: match.exterieur,
    stats: { home: { home: gsH.home, all: gsH.all }, away: { away: gsA.away, all: gsA.all } },
    league: { avgHome: lgAvg.avgHome || 1.45, avgAway: lgAvg.avgAway || 1.15, counts: lgAvg.counts || {} },
    counts, odds: cotes || undefined, calibration,
  });

  const facts = buildFacts(match, gsH, gsA, h2h);
  const ctx = {
    competition: match.leagueNom, dateTexte: `${dateLongue(match.coupDEnvoi)} à ${heure(match.coupDEnvoi)} (heure UTC)`,
    domicile: match.domicile.nomCourt, exterieur: match.exterieur.nomCourt,
    formeDom: N.formString(recentH), formeExt: N.formString(recentA),
    probas: pred.probas, plus25: pred.plus25, bttsOui: pred.bttsOui, scoreProbable: pred.scoreProbable, principal: pred.principal,
    extras: facts.extras, h2h: facts.h2h,
  };
  const gen = await generateText(ctx, providers);
  await bumpAiStatus(db, now, { fournisseur: gen.sourceTexte, secours: gen.sourceTexte === 'secours', erreurs: gen.erreurs, latencyMs: gen.latencyMs });

  const masque = !!(match.prono && match.prono.masque);
  const prono = {
    principal: pred.principal, secondaires: pred.secondaires, probas: pred.probas, plus25: pred.plus25, bttsOui: pred.bttsOui,
    scoreProbable: pred.scoreProbable, marches: pred.marches, matrice: pred.matrice, lamHome: pred.lamHome, lamAway: pred.lamAway,
    source: pred.source, texte: gen.texte, sourceTexte: gen.sourceTexte, calculeLe: now.toISOString(), version: MODEL_VERSION,
    formeDom: ctx.formeDom, formeExt: ctx.formeExt, comparatif: buildComparatif(recentH, recentA, gsH, gsA),
    echantillon: Math.min(gsH.all.games, gsA.all.games), visible: !masque, masque, aRecalculer: false,
  };
  await db.collection('matches').doc(match.id).set({ prono, cotes: cotes || null, h2h: h2h || null }, { merge: true });
  return gen;
}

/**
 * opts : { db, api, providers, now, maxMatches, refreshHours, quotaReserve, maxExternal }
 */
async function buildPredictions(opts, report) {
  const { db, api, providers } = opts;
  const now = opts.now || new Date();
  const maxMatches = opts.maxMatches || 40;
  const refreshHours = opts.refreshHours || 3;
  const quotaReserve = opts.quotaReserve == null ? 40 : opts.quotaReserve;
  const maxExternal = opts.maxExternal == null ? 2 : opts.maxExternal;

  const snap = await db.collection('matches').where('coupDEnvoi', '>=', now.toISOString()).where('coupDEnvoi', '<=', addDays(now, 7).toISOString()).get();
  const rows = snap.docs.map((d) => d.data()).filter((m) => m.statut === 'prevu');
  const todo = rows.filter((m) => {
    const p = m.prono;
    if (!p || !p.calculeLe || p.aRecalculer) return true;
    const sameDay = (new Date(m.coupDEnvoi) - now) / 3600e3 <= 24;
    const age = (now - new Date(p.calculeLe)) / 3600e3;
    return age > (sameDay ? refreshHours : 24);
  }).sort((a, b) => (a.coupDEnvoi < b.coupDEnvoi ? -1 : 1)).slice(0, maxMatches);
  report.infos.aCalculer = todo.length;
  if (!todo.length) return;

  const calibration = await loadCalibration(db, now);
  const leagues = new Map();
  const formCache = new Map();
  for (const m of todo) {
    try {
      if (!leagues.has(m.leagueId)) { const d = await db.collection('leagues').doc(m.leagueId).get(); leagues.set(m.leagueId, d.exists ? d.data() : null); }
      const gen = await buildOne({ db, api, providers, now, match: m, league: leagues.get(m.leagueId), formCache, calibration, quotaReserve, maxExternal });
      report.traites++;
      report.infos[gen.sourceTexte] = (report.infos[gen.sourceTexte] || 0) + 1;
    } catch (e) {
      report.erreurs.push(`${m.slug} : ${e.message}`);
    }
  }
}

module.exports = { buildPredictions, buildComparatif, buildFacts, loadCalibration, bumpAiStatus };
