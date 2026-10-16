'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { FakeDb } = require('./helpers/fakeDb');
const { handleEvent } = require('../src/http/track');

const SITE = path.join(__dirname, '..', '..', 'site');
const NOW = new Date('2026-10-16T09:30:00Z');
const mk = (db) => ({ db, increment: (n) => ({ __inc: n }), now: NOW, salt: 'sel' });
const req = (body) => ({ body, ua: 'Mozilla/5.0 (Linux; Android 13) Chrome/120', ip: '1.2.3.4', headers: {} });

test('manifeste : installable (nom, démarrage, affichage autonome, icônes 192 et 512 dont une maskable) et fichiers présents', () => {
  const m = JSON.parse(fs.readFileSync(path.join(SITE, 'manifest.webmanifest'), 'utf8'));
  assert.equal(m.display, 'standalone');
  assert.ok(m.start_url && m.name && m.short_name);
  const sizes = m.icons.map((i) => i.sizes);
  assert.ok(sizes.includes('192x192') && sizes.includes('512x512'));
  assert.ok(m.icons.some((i) => i.purpose === 'maskable'));
  for (const i of m.icons) assert.ok(fs.existsSync(path.join(SITE, i.src)), i.src);
  for (const s of m.shortcuts) assert.ok(s.url.startsWith('/'));
  assert.ok(fs.existsSync(path.join(SITE, 'img', 'apple-touch-icon.png')));
});

test('service worker : page hors connexion seulement, les pages de pronostics ne sont jamais gardées', () => {
  const sw = fs.readFileSync(path.join(SITE, 'sw.js'), 'utf8');
  assert.match(sw, /OFFLINE = '\/offline'/);
  assert.match(sw, /mode !== 'navigate'/);
  assert.ok(!/cache\.put|addAll/.test(sw), 'aucune mise en cache de pages');
  assert.ok(fs.existsSync(path.join(SITE, 'offline.html')));
  const fb = JSON.parse(fs.readFileSync(path.join(SITE, '..', 'firebase.json'), 'utf8'));
  assert.ok(fb.hosting.headers.some((h) => h.source === '/sw.js' && h.headers.some((x) => /no-cache/.test(x.value))));
});

test('mesure de l\'installation : invitations, clics, installations ; valeur inconnue refusée', async () => {
  const db = new FakeDb();
  for (const n of ['vu', 'clic', 'ok']) assert.ok(await handleEvent(req({ t: 'pwa', n }), mk(db)));
  assert.equal(await handleEvent(req({ t: 'pwa', n: 'nimporte' }), mk(db)), false);
  const d = db.read('stats_days', '2026-10-16');
  assert.equal(d.pwaVus, 1);
  assert.equal(d.pwaClics, 1);
  assert.equal(d.pwaInstalles, 1);
});
