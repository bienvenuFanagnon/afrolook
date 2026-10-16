'use strict';
// weeklyReport : fige le bilan de la semaine passée dans stats_weeks/{AAAA-Wss}.

const { addDays, dayStr, isoWeek, mondayOf } = require('./helpers');
const { summarize } = require('../engine/bilan');
const { visitorsFromEstimates } = require('../http/hll');

const sumMaps = (list, field) => {
  const out = {};
  for (const d of list) for (const [k, v] of Object.entries((d && d[field]) || {})) out[k] = (out[k] || 0) + v;
  return out;
};
const top = (map, n) => Object.entries(map).sort((a, b) => b[1] - a[1]).slice(0, n).map(([k, v]) => ({ k, v }));

/** Rapport d'une semaine à partir des compteurs journaliers et du bilan. Fonction pure. */
function buildWeekReport({ week, from, statsDays, bilanDays, aiLog }) {
  const jours = statsDays.filter(Boolean);
  const bilan = summarize(bilanDays.map((d) => d && d.delta).filter(Boolean));
  const sum = (f) => jours.reduce((s, d) => s + (d[f] || 0), 0);
  const pannes = (aiLog || []).filter((l) => l.etat === 'panne').length;
  return {
    semaine: week, du: from, au: dayStr(addDays(new Date(from), 6)),
    visites: sum('visites'), visiteurs: jours.reduce((n, d) => n + (d.hllEst ? visitorsFromEstimates(d.hllEst) : d.visiteurs || 0), 0), pagesVues: sum('pv'), clicsAfrolook: sum('clicsAfrolook'),
    pays: top(sumMaps(jours, 'pays'), 10),
    matchsTop: top(sumMaps(jours, 'matchs'), 5),
    appareils: sumMaps(jours, 'appareils'),
    sources: sumMaps(jours, 'sources'),
    pronostics: bilan.n, reussis: bilan.ok, rates: bilan.ko || 0, tauxReussite: bilan.taux,
    parLigue: bilan.parLigue,
    ia: { pannes, controles: (aiLog || []).length },
    figeLe: new Date().toISOString(),
  };
}

/** opts : { db, now } — fige la semaine précédente (lundi → dimanche). */
async function weeklyReport({ db, now }, report) {
  const t = now || new Date();
  const lundi = addDays(mondayOf(t), -7);
  const week = isoWeek(lundi);
  const jours = Array.from({ length: 7 }, (_, i) => dayStr(addDays(lundi, i)));
  const statsDays = [], bilanDays = [];
  for (const j of jours) {
    statsDays.push((await db.collection('stats_days').doc(j).get()).data() || null);
    bilanDays.push((await db.collection('bilan_days').doc(j).get()).data() || null);
  }
  const logSnap = await db.collection('ai_status_log').where('le', '>=', `${jours[0]}T00:00:00`).where('le', '<=', `${jours[6]}T23:59:59`).get();
  const doc = buildWeekReport({ week, from: jours[0], statsDays, bilanDays, aiLog: logSnap.docs.map((d) => d.data()) });
  await db.collection('stats_weeks').doc(week).set(doc);
  report.traites = 1;
  report.infos.semaine = week;
}

module.exports = { weeklyReport, buildWeekReport };
