'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { buildSample } = require('../dev/sample');
const { route } = require('../src/render/router');
const D = require('../src/render/data');
const { submitNewUrls, getKey, ENDPOINT } = require('../src/jobs/indexNow');
const { mergeSite } = require('../src/render/config');
const { sanitizeSite } = require('../src/http/admin');

const NOW = new Date('2026-10-16T08:00:00Z');
const okFetch = (calls) => async (url, o) => { calls.push({ url, body: JSON.parse(o.body) }); return { status: 200 }; };

test('IndexNow : pages nouvelles signalées une seule fois, FR et EN, avec la clé du site', async () => {
  const db = await buildSample(NOW);
  const site = mergeSite({});
  const calls = [];
  const r1 = await submitNewUrls({ db, site, now: NOW, fetchImpl: okFetch(calls) });
  assert.ok(r1.matchs > 0 && r1.envoyees >= r1.matchs * 2, JSON.stringify(r1));
  const b = calls[0].body;
  assert.equal(calls[0].url, ENDPOINT); assert.equal(b.host, 'pronoflashia.web.app');
  assert.match(b.key, /^[a-f0-9]{32}$/); assert.equal(b.keyLocation, `https://pronoflashia.web.app/${b.key}.txt`);
  assert.ok(b.urlList.every((u) => u.startsWith('https://pronoflashia.web.app/')));
  assert.ok(b.urlList.some((u) => /\/en\/football\//.test(u)) && b.urlList.some((u) => /\/analyse$/.test(u)) && b.urlList.some((u) => /\/analysis$/.test(u)));
  assert.ok(b.urlList.includes('https://pronoflashia.web.app/') && b.urlList.includes('https://pronoflashia.web.app/en'), 'pages fixes envoyées la première fois');
  // deuxième passage : plus rien de nouveau
  const calls2 = [];
  const r2 = await submitNewUrls({ db, site, now: NOW, fetchImpl: okFetch(calls2) });
  assert.equal(r2.envoyees, 0); assert.equal(calls2.length, 0);
  // la clé est stable
  assert.equal(await getKey(db), b.key);
});

test('IndexNow : site non indexable → rien ; erreur du service → rien de marqué, signalée', async () => {
  const db = await buildSample(NOW);
  assert.deepEqual(await submitNewUrls({ db, site: mergeSite({ indexable: false }), now: NOW, fetchImpl: async () => { throw new Error('ne doit pas être appelé'); } }), { ignore: 'site non indexable' });
  const bad = await submitNewUrls({ db, site: mergeSite({}), now: NOW, fetchImpl: async () => ({ status: 403 }) });
  assert.match(bad.erreur, /403/);
  const down = await submitNewUrls({ db, site: mergeSite({}), now: NOW, fetchImpl: async () => { throw new Error('réseau'); } });
  assert.match(down.erreur, /injoignable/);
  const ok = await submitNewUrls({ db, site: mergeSite({}), now: NOW, fetchImpl: okFetch([]) });
  assert.ok(ok.matchs > 0, 'après les erreurs, les pages sont toujours à envoyer');
});

test('fichier-clé IndexNow : /{clé}.txt répond avec la clé, une autre clé donne 404', async () => {
  const db = await buildSample(NOW);
  const key = await getKey(db);
  D.clearCache();
  const ok = await route(db, `/${key}.txt`, NOW);
  assert.equal(ok.status, 200); assert.equal(ok.body, key); assert.match(ok.headers['Content-Type'], /text\/plain/);
  const other = await route(db, `/${'0'.repeat(32)}.txt`, NOW);
  assert.equal(other.status, 404);
});

test('Search Console : balise de vérification dans l\'en-tête, balise collée ou valeur seule', async () => {
  const db = await buildSample(NOW);
  assert.equal(sanitizeSite({ googleVerification: '<meta name="google-site-verification" content="abcDEF_123-xyz9876" />' }).googleVerification, 'abcDEF_123-xyz9876');
  assert.equal(sanitizeSite({ googleVerification: ' abcDEF_123-xyz9876 ' }).googleVerification, 'abcDEF_123-xyz9876');
  assert.equal(sanitizeSite({ googleVerification: '' }).googleVerification, '');
  assert.throws(() => sanitizeSite({ googleVerification: '"><script>alert(1)</script>' }), /invalide/);
  assert.doesNotMatch((await route(db, '/', NOW)).body, /google-site-verification/);
  await db.seed('config', 'site', { googleVerification: 'abcDEF_123-xyz9876' }); D.clearCache();
  assert.match((await route(db, '/', NOW)).body, /<meta name="google-site-verification" content="abcDEF_123-xyz9876">/);
  assert.match((await route(db, '/en', NOW)).body, /google-site-verification/);
});

test('adresse provisoire : le sitemap, robots et pages pointent vers pronoflashia.web.app', async () => {
  const db = await buildSample(NOW);
  const robots = await route(db, '/robots.txt', NOW);
  assert.match(robots.body, /Sitemap: https:\/\/pronoflashia\.web\.app\/sitemap\.xml/); assert.match(robots.body, /Allow: \//);
  const sm = (await route(db, '/sitemap.xml', NOW)).body;
  assert.doesNotMatch(sm, /pronoflashia\.com/);
});
