'use strict';
// Lecture des données pour le rendu des pages (Firestore ou base factice). Petit cache mémoire par instance.

const { mergeSite, mergeAds } = require('./config');
const { summarize } = require('../engine/bilan');
const { dayStr, addDays } = require('../jobs/helpers');

const cache = new Map();
async function cached(key, ttlMs, fn) {
  const hit = cache.get(key);
  if (hit && Date.now() - hit.at < ttlMs) return hit.v;
  const v = await fn();
  cache.set(key, { at: Date.now(), v });
  if (cache.size > 300) cache.clear();
  return v;
}
const clearCache = () => cache.clear();

const visible = (m) => !m.prono || m.prono.visible !== false;

async function loadConfig(db) {
  return cached('config', 60e3, async () => {
    const [site, ads] = await Promise.all([db.collection('config').doc('site').get(), db.collection('config').doc('ads').get()]);
    return { site: mergeSite(site.exists ? site.data() : {}), ads: mergeAds(ads.exists ? ads.data() : {}) };
  });
}

async function loadLeagues(db) {
  return cached('leagues', 300e3, async () => {
    const snap = await db.collection('leagues').where('suivi', '==', true).get();
    return snap.docs.map((d) => d.data()).sort((a, b) => (a.ordre || 99) - (b.ordre || 99));
  });
}

async function matchesByDay(db, jour) {
  return cached(`day:${jour}`, 60e3, async () => {
    const snap = await db.collection('matches').where('jour', '==', jour).get();
    return snap.docs.map((d) => d.data()).filter((m) => m.statut !== 'reporte' && visible(m)).sort((a, b) => (a.coupDEnvoi < b.coupDEnvoi ? -1 : 1));
  });
}

/** Matchs entre deux instants (ISO). */
async function matchesBetween(db, fromIso, toIso) {
  return cached(`between:${fromIso.slice(0, 13)}:${toIso.slice(0, 13)}`, 60e3, async () => {
    const snap = await db.collection('matches').where('coupDEnvoi', '>=', fromIso).where('coupDEnvoi', '<=', toIso).get();
    return snap.docs.map((d) => d.data()).filter((m) => m.statut !== 'reporte' && visible(m)).sort((a, b) => (a.coupDEnvoi < b.coupDEnvoi ? -1 : 1));
  });
}

async function matchBySlug(db, leagueSlug, slug) {
  const snap = await db.collection('matches').where('slug', '==', slug).where('leagueSlug', '==', leagueSlug).get();
  const m = snap.docs[0] && snap.docs[0].data();
  return m && visible(m) ? m : null;
}

async function recentResults(db, now, n = 10, leagueId) {
  return cached(`results:${leagueId || 'all'}:${n}:${now.toISOString().slice(0, 13)}`, 120e3, async () => {
    let q = db.collection('matches').where('statut', '==', 'termine');
    if (leagueId) q = q.where('leagueId', '==', String(leagueId));
    const snap = await q.orderBy('coupDEnvoi', 'desc').limit(n * 3).get();
    return snap.docs.map((d) => d.data()).filter((m) => m.resultat && m.resultat.reussi != null).slice(0, n);
  });
}

async function bilanDays(db, now, days) {
  return cached(`bilan:${days}:${dayStr(now)}`, 300e3, async () => {
    const since = dayStr(addDays(now, -days));
    const snap = await db.collection('bilan_days').where('jour', '>=', since).get();
    return snap.docs.map((d) => d.data());
  });
}

async function bilan30(db, now) {
  const days = await bilanDays(db, now, 30);
  return summarize(days.map((d) => d.delta).filter(Boolean));
}

async function teamRecent(db, teamId) {
  const d = await db.collection('team_form').doc(String(teamId)).get();
  return (d.exists && d.data().recent) || [];
}

/** Tous les matchs à venir avec pronostic (pour le compositeur de coupon et les coupons proposés). */
async function pool(db, now, hours = 96) {
  const list = await matchesBetween(db, now.toISOString(), new Date(now.getTime() + hours * 3600e3).toISOString());
  return list.filter((m) => m.statut === 'prevu' && m.prono && m.prono.visible !== false && m.prono.marches);
}

module.exports = { clearCache, loadConfig, loadLeagues, matchesByDay, matchesBetween, matchBySlug, recentResults, bilanDays, bilan30, teamRecent, pool };
