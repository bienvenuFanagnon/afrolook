'use strict';
// Suivi des outils connectés (API-Football, Workers AI, Gemini) : appels, erreurs, consommation et quota du jour,
// avec un historique court de 30 jours. Lu par l'écran « Connexions » de l'administration.

const { dayStr } = require('./helpers');

const TOOLS = ['apiFootball', 'workersAi', 'gemini'];
const PROVIDER_TOOL = { 'workers-ai': 'workersAi', gemini: 'gemini' };

/**
 * Enregistre l'activité d'un outil. delta : { appels, erreurs, neurons, ok, erreur, quotaRestant, quotaLimite, latenceMs }.
 * Lecture puis écriture dans une transaction : plusieurs tâches peuvent écrire en même temps.
 */
async function recordUse(db, tool, now, delta) {
  if (!TOOLS.includes(tool)) return;
  const jour = dayStr(now);
  const ref = db.collection('connexions').doc(tool);
  await db.runTransaction(async (tx) => {
    const d = await tx.get(ref);
    const cur = d.exists ? d.data() : {};
    const sameDay = cur.jour === jour;
    const hist = Object.assign({}, cur.historique || {});
    const h = Object.assign({ appels: 0, erreurs: 0, neurons: 0 }, hist[jour] || {});
    h.appels += delta.appels || 0;
    h.erreurs += delta.erreurs || 0;
    h.neurons = Math.round((h.neurons + (delta.neurons || 0)) * 100) / 100;
    hist[jour] = h;
    for (const k of Object.keys(hist).sort().slice(0, -30)) delete hist[k];
    const upd = {
      outil: tool, jour, majLe: now.toISOString(), historique: hist,
      appelsJour: h.appels, erreursJour: h.erreurs, neuronsJour: h.neurons,
    };
    if (delta.ok) { upd.dernierSucces = now.toISOString(); if (delta.latenceMs != null) upd.latenceMs = delta.latenceMs; }
    if (delta.erreur) { upd.derniereErreur = String(delta.erreur).slice(0, 300); upd.derniereErreurLe = now.toISOString(); }
    if (delta.quotaRestant != null) upd.quotaRestant = delta.quotaRestant;
    if (delta.quotaLimite != null) upd.quotaLimite = delta.quotaLimite;
    if (!sameDay && delta.quotaRestant == null && cur.quotaRestant != null) upd.quotaRestant = null; // nouveau jour : quota inconnu jusqu'au prochain appel
    tx.set(ref, Object.assign({}, cur, upd));
  });
}

/** Enregistre les appels d'IA renvoyés par generateText (un enregistrement par outil). */
async function recordAiCalls(db, now, appels) {
  const by = {};
  for (const a of appels || []) {
    const tool = PROVIDER_TOOL[a.provider];
    if (!tool) continue;
    const b = (by[tool] = by[tool] || { appels: 0, erreurs: 0, neurons: 0, ok: false, erreur: null, latenceMs: null });
    b.appels++;
    b.neurons += a.neurons || 0;
    if (a.ok) { b.ok = true; b.latenceMs = a.ms; } else { b.erreurs++; b.erreur = a.erreur; }
  }
  for (const [tool, d] of Object.entries(by)) await recordUse(db, tool, now, d);
}

/** Quota d'API-Football relevé dans les en-têtes des réponses, à la fin d'une tâche. */
async function recordApiQuota(db, api, now, report) {
  if (!api || !api.quota) return;
  const q = api.quota;
  const err = report && report.erreurs && report.erreurs.find((e) => /API-Football|Quota/i.test(e));
  await recordUse(db, 'apiFootball', now, { appels: q.calls || 0, erreurs: err ? 1 : 0, ok: (q.calls || 0) > 0 && !err, erreur: err || null, quotaRestant: q.dayRemaining, quotaLimite: q.dayLimit });
}

module.exports = { TOOLS, recordUse, recordAiCalls, recordApiQuota };
