'use strict';
// Outils communs aux tâches planifiées : compte-rendu dans jobs/{id}, dates, semaines ISO.

const dayStr = (d) => new Date(d).toISOString().slice(0, 10);
const addDays = (d, n) => new Date(new Date(d).getTime() + n * 864e5);

/** Semaine ISO « 2026-W42 » d'une date UTC. */
function isoWeek(date) {
  const d = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  const dayNum = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const week = Math.ceil(((d - yearStart) / 864e5 + 1) / 7);
  return `${d.getUTCFullYear()}-W${String(week).padStart(2, '0')}`;
}

/** Lundi (UTC) de la semaine d'une date. */
function mondayOf(date) {
  const d = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  const dayNum = d.getUTCDay() || 7;
  d.setUTCDate(d.getUTCDate() - (dayNum - 1));
  return d;
}

/**
 * Exécute une tâche et écrit son compte-rendu : début, fin, durée, nombre traité, erreurs.
 * fn(report) reçoit un objet { traites, erreurs[], infos } à remplir ; une exception est enregistrée puis relancée.
 */
async function runJob(db, name, fn, now = () => new Date()) {
  const start = now();
  const report = { traites: 0, erreurs: [], infos: {} };
  let failure = null;
  try { await fn(report); } catch (e) { failure = e; report.erreurs.push(String(e && e.message ? e.message : e)); }
  const end = now();
  const id = `${name}_${start.toISOString().replace(/[:.]/g, '-')}`;
  const doc = {
    job: name, debut: start.toISOString(), fin: end.toISOString(), dureeMs: end - start,
    traites: report.traites, erreurs: report.erreurs.slice(0, 20), infos: report.infos, ok: !failure && report.erreurs.length === 0,
  };
  try { await db.collection('jobs').doc(id).set(doc); await db.collection('jobs').doc(`_dernier_${name}`).set(doc); } catch (e) { console.error('journal', e.message); }
  if (failure) throw failure;
  return report;
}

module.exports = { dayStr, addDays, isoWeek, mondayOf, runJob };
