'use strict';
// PronoFlash IA : tâches planifiées, pages (rendu côté serveur avec cache), mesure d'audience et administration.
// Région europe-west1. maxInstances limité : le quota CPU d'un projet est borné.

const { onRequest } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineString } = require('firebase-functions/params');
const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');

const { makeApi, makeProviders, sourceOf } = require('./src/deps');
const { runJob } = require('./src/jobs/helpers');
const { syncFixtures } = require('./src/jobs/syncFixtures');
const { buildPredictions } = require('./src/jobs/buildPredictions');
const { submitNewUrls } = require('./src/jobs/indexNow');
const { createClient: createAdsterra } = require('./src/data/adsterra');
const { syncResults } = require('./src/jobs/syncResults');
const { weeklyReport } = require('./src/jobs/weeklyReport');
const { aiHealthCheck } = require('./src/jobs/aiHealth');
const { route } = require('./src/render/router');
const D = require('./src/render/data');
const { publicAds } = require('./src/render/config');
const { handleEvent } = require('./src/http/track');
const { createAdmin } = require('./src/http/admin');
const { SCHEDULE } = require('./src/jobs/schedule');

if (!getApps().length) initializeApp();
const db = getFirestore();

const API_FOOTBALL_KEY = defineString('API_FOOTBALL_KEY', { default: '' });
const FOOTBALL_DATA_TOKEN = defineString('FOOTBALL_DATA_TOKEN', { default: '' });
const ADSTERRA_API_TOKEN = defineString('ADSTERRA_API_TOKEN', { default: '' });
const CF_API_TOKEN = defineString('CF_API_TOKEN', { default: '' });
const CF_ACCOUNT_ID = defineString('CF_ACCOUNT_ID', { default: '' });
const GEMINI_API_KEY = defineString('GEMINI_API_KEY', { default: '' });
const STATS_SALT = defineString('STATS_SALT', { default: '' });
// Adresses Google autorisées dès le départ (le premier administrateur) ; les autres sont gérées dans l'admin.
const ADMIN_EMAILS = defineString('ADMIN_EMAILS', { default: '' });
// Source des données de football : « football-data » (gratuit) ou « api-football » (payant). Vide : football-data si son jeton existe.
const FOOTBALL_SOURCE = defineString('FOOTBALL_SOURCE', { default: '' });

const REGION = 'europe-west1';
const val = (p) => { try { return p.value(); } catch { return ''; } };
const secrets = () => ({ adsterra: val(ADSTERRA_API_TOKEN), source: val(FOOTBALL_SOURCE), footballData: val(FOOTBALL_DATA_TOKEN), apiFootball: val(API_FOOTBALL_KEY), cfToken: val(CF_API_TOKEN), cfAccount: val(CF_ACCOUNT_ID), gemini: val(GEMINI_API_KEY) });
const cron = (nom) => SCHEDULE.find((x) => x.nom === nom).cron;
const sched = (schedule, extra = {}) => Object.assign({ schedule, timeZone: 'UTC', region: REGION, memory: '512MiB', timeoutSeconds: 540, maxInstances: 1, retryCount: 0 }, extra);

/** Les tâches, réutilisées par le planificateur et par le bouton « Relancer » de l'admin. */
const TASKS = {
  syncFixtures: (o = {}) => runJob(db, 'syncFixtures', (r) => syncFixtures({ db, api: makeApi(secrets(), o.manuel ? { maxWaitMs: 20000 } : {}) }, r)),
  buildPredictions: (o = {}) => runJob(db, 'buildPredictions', async (r) => {
    const s = secrets();
    await buildPredictions({ db, api: makeApi(s, o.manuel ? { maxWaitMs: 5000 } : {}), providers: makeProviders(s), budgetMs: o.manuel ? 40000 : null }, r);
    // référencement automatique : les pages nouvelles sont signalées une fois (IndexNow) ; une erreur ici ne fait pas échouer la tâche
    try {
      const { site } = await D.loadConfig(db);
      const ix = await submitNewUrls({ db, site, now: new Date() });
      r.infos.indexNow = ix;
      if (ix.erreur) r.erreurs.push(ix.erreur);
    } catch (e) { r.erreurs.push(`IndexNow : ${e.message}`); }
  }),
  syncResults: (o = {}) => runJob(db, 'syncResults', (r) => syncResults({ db, api: makeApi(secrets(), o.manuel ? { maxWaitMs: 20000 } : {}) }, r)),
  weeklyReport: () => runJob(db, 'weeklyReport', (r) => weeklyReport({ db }, r)),
  aiHealthCheck: () => runJob(db, 'aiHealthCheck', (r) => aiHealthCheck({ db, providers: makeProviders(secrets()) }, r)),
};

// Matchs et statistiques : chaque jour à 05:00 UTC, avec l'historique de saison une fois par jour.
exports.syncFixtures = onSchedule(sched(cron('syncFixtures')), async () => { await TASKS.syncFixtures(); await TASKS.buildPredictions(); });
// Pronostics : à 20 minutes après chaque heure (les cotes et compositions évoluent), de 05:20 à 02:20 UTC.
exports.buildPredictions = onSchedule(sched(cron('buildPredictions')), async () => { await TASKS.buildPredictions(); });
// Résultats : toutes les 30 minutes pendant les heures de match.
exports.syncResults = onSchedule(sched(cron('syncResults')), async () => { await TASKS.syncResults(); });
// Bilan hebdomadaire figé chaque lundi.
exports.weeklyReport = onSchedule(sched(cron('weeklyReport'), { memory: '256MiB' }), async () => { await TASKS.weeklyReport(); });
// Test de l'IA toutes les 30 minutes.
exports.aiHealthCheck = onSchedule(sched(cron('aiHealthCheck'), { memory: '256MiB', timeoutSeconds: 120 }), async () => { await TASKS.aiHealthCheck(); });

const admin = createAdmin({
  db,
  verifyToken: (t) => getAuth().verifyIdToken(t),
  get bootstrap() { return ADMIN_EMAILS.value().split(',').map((x) => x.trim()).filter(Boolean); },
  tasks: TASKS,
  apiFactory: () => makeApi(secrets()),
  adsterraFactory: () => { const t = secrets().adsterra; return t ? createAdsterra({ token: t }) : null; },
  // présence des secrets (jamais leur valeur) pour l'écran « Connexions »
  secretsStatus: () => { const s = secrets(); let salt = ''; try { salt = STATS_SALT.value(); } catch { /* non défini */ } return { adsterraApi: !!s.adsterra, source: sourceOf(s), footballData: !!s.footballData, apiFootball: !!s.apiFootball, cfToken: !!s.cfToken, cfAccount: !!s.cfAccount, gemini: !!s.gemini, statsSalt: !!salt }; },
  clearCache: D.clearCache,
});

const bodyOf = (req) => {
  let b = req.body;
  if (Buffer.isBuffer(b)) b = b.toString('utf8');
  if (typeof b === 'string') { try { b = JSON.parse(b); } catch { b = {}; } }
  return b && typeof b === 'object' ? b : {};
};
const clientIp = (req) => String(req.get('x-forwarded-for') || req.ip || '').split(',')[0].trim();

/**
 * Point d'entrée web : Hosting y envoie /api/** et toutes les pages qui ne sont pas des fichiers statiques.
 * Les pages sont mises en cache par le CDN (Cache-Control s-maxage) : la fonction ne tourne qu'à la première demande.
 */
exports.pfWeb = onRequest({ region: REGION, invoker: 'public', memory: '512MiB', timeoutSeconds: 300, maxInstances: 10, concurrency: 40 }, async (req, res) => {
  const path = req.path || '/';
  try {
    if (path === '/api/event') {
      if (req.method !== 'POST') return void res.status(405).end();
      await handleEvent({ body: bodyOf(req), ua: req.get('user-agent') || '', ip: clientIp(req), headers: req.headers }, { db, increment: (n) => FieldValue.increment(n), salt: STATS_SALT.value() });
      return void res.status(204).end();
    }
    if (path === '/api/config') {
      const cfg = await D.loadConfig(db);
      res.set('Cache-Control', 'public, max-age=30, s-maxage=60');
      return void res.status(200).json(publicAds(cfg.ads));
    }
    if (path.startsWith('/api/admin/')) {
      if (req.method !== 'POST') return void res.status(405).end();
      res.set('Cache-Control', 'no-store');
      const r = await admin.handle({ action: path.slice('/api/admin/'.length), body: bodyOf(req), authorization: req.get('authorization') });
      return void res.status(r.status).json(r.json);
    }
    if (path.startsWith('/api/')) return void res.status(404).json({ erreur: 'Inconnu' });
    if (req.method !== 'GET' && req.method !== 'HEAD') return void res.status(405).end();
    const r = await route(db, path);
    for (const [k, v] of Object.entries(r.headers)) res.set(k, v);
    res.status(r.status).send(req.method === 'HEAD' ? '' : r.body);
  } catch (e) {
    console.error('pfWeb', path, e);
    res.set('Cache-Control', 'no-store');
    res.status(500).send('Erreur temporaire. Réessaie dans un instant.');
  }
});
