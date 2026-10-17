'use strict';
// Serveur local d'aperçu : pages rendues par le vrai routeur, sur des données d'exemple produites par la vraie chaîne.
// Usage : node scripts/dev.js [port]   (aucune clé ni compte nécessaire)
const http = require('http');
const fs = require('fs');
const path = require('path');
require('./build-site');
const { buildSample, seedStats } = require('../functions/dev/sample');
const { createAdmin } = require('../functions/src/http/admin');
const { runJob } = require('../functions/src/jobs/helpers');
const { aiHealthCheck } = require('../functions/src/jobs/aiHealth');
const { route } = require('../functions/src/render/router');
const { publicAds } = require('../functions/src/render/config');
const D = require('../functions/src/render/data');
const { handlePush } = require('../functions/src/http/push');

const SITE = path.join(__dirname, '../site');
const TYPES = { '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml', '.woff2': 'font/woff2', '.webmanifest': 'application/manifest+json', '.json': 'application/json', '.html': 'text/html; charset=utf-8' };
const port = parseInt(process.argv[2] || process.env.PORT || '5173', 10);

(async () => {
  const now = new Date();
  const db = await buildSample(now);
  if (process.env.PF_ADS_DEMO) await db.seed('config', 'ads', JSON.parse(fs.readFileSync(process.env.PF_ADS_DEMO, 'utf8')));
  await seedStats(db, now);
  // abonné de démonstration (adresse https://fcm.googleapis.com/fcm/send/devdemo) avec 23 notifications dont 12 non lues : page /notifications
  {
    const subs = require('../functions/src/push/subs'), inbox = require('../functions/src/push/inbox');
    const KEYS = { p256dh: 'BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTpQtUbVlUls0VJXg7A8u-Ts1XbjhazAkj7I99e8QcYP7DkM', auth: 'tBHItJI5svbpez7KI4CCXg' };
    const { id } = await subs.subscribe(db, { subscription: { endpoint: 'https://fcm.googleapis.com/fcm/send/devdemo', keys: KEYS }, lang: 'fr' }, now);
    const titles = ['⚡ Coupons du jour : Arsenal – Chelsea', '⚔️ Classico : Real Madrid – Barça', '🌟 Une pépite fait parler', '🔥 Mbappé fait l\'actu', '🔔 Match de vos équipes'];
    for (let i = 0; i < 23; i++) {
      const p = { titre: titles[i % 5], corps: 'Notre pronostic et les dernières infos sont à l\'intérieur.', url: '/coupon?source=push', image: i % 2 ? null : null, _nid: `d${String(i).padStart(11, '0')}` };
      await inbox.add(db, { id }, p, new Date(now.getTime() - i * 5400e3));
      if (i >= 12) await db.collection('push_inbox').doc(`${id}_${p._nid}`).set({ lu: true }, { merge: true });
    }
    await db.collection('push_subs').doc(id).set(Object.assign({}, (await db.collection('push_subs').doc(id).get()).data(), { nl: 12 }));
  }
  const okProvider = { name: 'workers-ai', call: async () => '{"ok":true}' };
  const noop = (name) => () => runJob(db, name, async (r) => { r.traites = 0; });
  const admin = createAdmin({ db, verifyToken: async (t) => { if (t !== 'dev') throw new Error('non'); return { email: 'dev@local', email_verified: true }; }, bootstrap: ['dev@local'], clearCache: D.clearCache, secretsStatus: () => ({ apiFootball: true, cfToken: true, cfAccount: true, gemini: false, statsSalt: true }),
    tasks: { aiHealthCheck: () => runJob(db, 'aiHealthCheck', (r) => aiHealthCheck({ db, providers: [okProvider] }, r)), syncFixtures: noop('syncFixtures'), buildPredictions: noop('buildPredictions'), syncResults: noop('syncResults'), weeklyReport: noop('weeklyReport') } });
  const events = [];
  http.createServer(async (req, res) => {
    const url = new URL(req.url, 'http://x');
    try {
      if (url.pathname === '/api/event') { let b = ''; req.on('data', (c) => (b += c)); req.on('end', () => { events.push(b); res.writeHead(204); res.end(); }); return; }
      if (url.pathname.startsWith('/api/push/')) { let b = ''; req.on('data', (c) => (b += c)); req.on('end', async () => { let body = {}; try { body = JSON.parse(b || '{}'); } catch (e) { /* vide */ } const r = await handlePush({ method: req.method, path: url.pathname, body, ip: 'dev' }, { db, publicKey: async () => 'BEl62iUYgUivxIkv69yViEuiBIa-Ib9-SkvMeAtA3LFgDzkrxZJjSgSnfckjBJuBkr3qBUYIHBQFLXYp5Nksh8U' }); res.writeHead(r.status, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(r.json)); }); return; }
      if (url.pathname === '/api/events') { res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(events)); return; }
      if (url.pathname.startsWith('/api/admin/')) { let b = ''; req.on('data', (c) => (b += c)); req.on('end', async () => { let body = {}; try { body = JSON.parse(b || '{}'); } catch (e) { /* vide */ } const r = await admin.handle({ action: url.pathname.slice(11), body, authorization: req.headers.authorization }); res.writeHead(r.status, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(r.json)); }); return; }
      if (url.pathname === '/admin') { res.writeHead(200, { 'Content-Type': 'text/html' }); fs.createReadStream(path.join(SITE, 'admin/index.html')).pipe(res); return; }
      if (url.pathname === '/api/config') { const cfg = await D.loadConfig(db); res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({ ads: publicAds(cfg.ads), ...publicAds(cfg.ads) })); return; }
      let file = path.join(SITE, url.pathname);
      if (!path.extname(file) && fs.existsSync(file + '.html')) file += '.html'; // URL propres, comme l'hébergement
      if (file.startsWith(SITE) && fs.existsSync(file) && fs.statSync(file).isFile()) { res.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream' }); fs.createReadStream(file).pipe(res); return; }
      const r = await route(db, url.pathname, now);
      res.writeHead(r.status, r.headers); res.end(r.body);
    } catch (e) { console.error(e); res.writeHead(500); res.end('Erreur : ' + e.message); }
  }).listen(port, () => console.log(`Aperçu : http://localhost:${port}/`));
})();
