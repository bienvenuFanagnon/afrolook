'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createClient, normalizeRow, totals } = require('../src/data/adsterra');
const { createAdmin } = require('../src/http/admin');
const { FakeDb } = require('./helpers/fakeDb');

const reply = (body, status = 200) => ({ ok: status < 400, status, text: async () => JSON.stringify(body) });

test('Adsterra : jeton en en-tête, dates et regroupement', async () => {
  const calls = [];
  const api = createClient({ token: 'T', fetchImpl: async (url, o) => { calls.push({ url, h: o.headers }); return reply({ items: [{ date: '2026-10-15', impression: 1200, clicks: 12, revenue: 0.84 }] }); } });
  const rows = await api.stats({ start: '2026-10-09', finish: '2026-10-16', groupBy: 'date' });
  assert.equal(calls[0].h['X-API-Key'], 'T');
  assert.match(calls[0].url, /\/publisher\/stats\.json\?start_date=2026-10-09&finish_date=2026-10-16&group_by=date$/);
  assert.equal(rows.length, 1);
  assert.deepEqual(normalizeRow(rows[0], 'date'), { cle: '2026-10-15', impressions: 1200, clics: 12, revenu: 0.84 });
  assert.deepEqual(totals([{ impressions: 1000, clics: 10, revenu: 0.5 }, { impressions: 1000, clics: 5, revenu: 0.7 }]), { impressions: 2000, clics: 15, revenu: 1.2, cpm: 0.6 });
  assert.deepEqual(totals([]), { impressions: 0, clics: 0, revenu: 0, cpm: 0 });
  await assert.rejects(() => createClient({ token: 'x', fetchImpl: async () => reply({ message: 'Unauthorized' }, 401) }).stats({}), /Adsterra : Unauthorized/);
});

test('admin « revenus » : non connecté sans jeton, sinon jours, emplacements nommés et totaux', async () => {
  const db = new FakeDb();
  const NOW = new Date('2026-10-16T12:00:00Z');
  const mk = (factory) => createAdmin({ db, verifyToken: async () => ({ email: 'boss@example.com', email_verified: true }), bootstrap: ['boss@example.com'], now: () => NOW, clearCache() {}, adsterraFactory: factory });
  const call = async (admin, action) => admin.handle({ action, body: {}, authorization: 'Bearer t' });
  const none = await call(mk(() => null), 'revenus');
  assert.equal(none.status, 200); assert.equal(none.json.connecte, false);
  const fake = { stats: async ({ groupBy }) => (groupBy === 'date'
    ? [{ date: '2026-10-15', impression: 2000, clicks: 20, revenue: 1.5 }, { date: '2026-10-14', impression: 1000, clicks: 5, revenue: 0.5 }]
    : [{ placement: 31764506, impression: 1500, clicks: 10, revenue: 1.2 }, { placement: 31764504, impression: 1500, clicks: 15, revenue: 0.8 }]),
    placements: async () => [{ id: 31764506, title: '300x250_1' }, { id: 31764504, title: 'NativeBanner_1' }] };
  const r = await call(mk(() => fake), 'revenus');
  assert.equal(r.status, 200, JSON.stringify(r.json));
  assert.equal(r.json.connecte, true);
  assert.deepEqual(r.json.jours.map((j) => j.cle), ['2026-10-14', '2026-10-15']);
  assert.equal(r.json.emplacements[0].nom, '300x250_1');
  assert.deepEqual(r.json.totaux, { impressions: 3000, clics: 25, revenu: 2, cpm: 0.667 });
  assert.equal(r.json.periode.debut, '2026-10-03');
  const bad = await call(mk(() => ({ stats: async () => { throw new Error('Adsterra : 500'); }, placements: async () => [] })), 'revenus');
  assert.equal(bad.status, 502);
});
