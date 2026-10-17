'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeDb } = require('./helpers/fakeDb');
const mail = require('../src/mail/subs');
const { handleMail } = require('../src/http/mail');
const { createAdmin } = require('../src/http/admin');
const { route } = require('../src/render/router');
const { buildSample } = require('../dev/sample');

const NOW = new Date('2026-10-17T12:00:00Z');

test('e-mail : inscription avec accord explicite, adresse normalisée, même réponse si déjà inscrit, preuve du consentement gardée', async () => {
  const db = new FakeDb();
  assert.deepEqual(await mail.subscribe(db, { email: ' Fan@Exemple.COM ', consent: true, lang: 'fr', source: 'coupon' }, NOW), { ok: true });
  const id = mail.idOf('fan@exemple.com');
  const d = db.read('email_subs', id);
  assert.equal(d.email, 'fan@exemple.com');
  assert.equal(d.statut, 'en_attente');
  assert.equal(d.confirme, false);
  assert.equal(d.consentement.page, 'coupon');
  assert.equal(d.consentement.version, mail.CONSENT_VERSION);
  assert.equal(d.consentement.au, NOW.toISOString());
  assert.match(d.jeton, /^[a-f0-9]{24}$/);
  assert.deepEqual(await mail.subscribe(db, { email: 'fan@exemple.com', consent: true }, new Date(NOW.getTime() + 1e5)), { ok: true });
  assert.equal(db.read('email_subs', id).creeLe, NOW.toISOString(), 'inchangé');
});

test('e-mail : refus sans accord ou avec une adresse invalide ; champ piège rempli = rien enregistré', async () => {
  const db = new FakeDb();
  await assert.rejects(mail.subscribe(db, { email: 'a@b.fr', consent: false }, NOW), /accord/);
  await assert.rejects(mail.subscribe(db, { email: 'a@b.fr' }, NOW), /accord/);
  for (const bad of ['', 'pas-un-mail', 'a@b', 'a b@c.fr', '<x>@c.fr', 'a@@c.fr', 'a..b@c.fr', 'x'.repeat(130) + '@c.fr', 12345, null]) await assert.rejects(mail.subscribe(db, { email: bad, consent: true }, NOW), /invalide/, String(bad));
  assert.deepEqual(await mail.subscribe(db, { email: 'robot@exemple.com', consent: true, site: 'http://spam' }, NOW), { ok: true });
  assert.equal(db.read('email_subs', mail.idOf('robot@exemple.com')), null);
});

test('e-mail : désinscription avec le jeton de l\'inscrit seulement, réinscription possible ensuite', async () => {
  const db = new FakeDb();
  await mail.subscribe(db, { email: 'a@exemple.com', consent: true }, NOW);
  const id = mail.idOf('a@exemple.com');
  const { jeton } = db.read('email_subs', id);
  await assert.rejects(mail.unsubscribe(db, id, 'f'.repeat(24), NOW), /invalide/);
  await assert.rejects(mail.unsubscribe(db, 'zzz', jeton, NOW), /invalide/);
  await mail.unsubscribe(db, id, jeton, NOW);
  assert.equal(db.read('email_subs', id).statut, 'desinscrit');
  await mail.subscribe(db, { email: 'a@exemple.com', consent: true }, NOW);
  assert.equal(db.read('email_subs', id).statut, 'en_attente');
  assert.notEqual(db.read('email_subs', id).jeton, jeton, 'nouveau jeton après réinscription');
});

test('API e-mail : inscription, mauvaise méthode, route inconnue, limite de débit', async () => {
  const db = new FakeDb();
  const call = (method, path, body, ip = '3.3.3.3') => handleMail({ method, path: `/api/mail/${path}`, body, ip }, { db, now: NOW });
  assert.equal((await call('POST', 'subscribe', { email: 'x@exemple.com', consent: true })).status, 200);
  assert.equal((await call('POST', 'subscribe', { email: 'x@exemple.com', consent: false })).status, 400);
  assert.equal((await call('GET', 'subscribe')).status, 405);
  assert.equal((await call('POST', 'liste', {})).status, 404);
  let last;
  for (let i = 0; i < 10; i++) last = await call('POST', 'subscribe', { email: `y${i}@exemple.com`, consent: true }, '4.4.4.4');
  assert.equal(last.status, 429);
});

test('admin : inscrits par e-mail (totaux, liste, désinscrits exclus)', async () => {
  const db = new FakeDb();
  await mail.subscribe(db, { email: 'a@exemple.com', consent: true, lang: 'en' }, NOW);
  await mail.subscribe(db, { email: 'b@exemple.com', consent: true }, NOW);
  const b = db.read('email_subs', mail.idOf('b@exemple.com'));
  await mail.unsubscribe(db, b.id, b.jeton, NOW);
  const admin = createAdmin({ db, verifyToken: async () => ({ email: 'a@x.fr', email_verified: true }), bootstrap: ['a@x.fr'], tasks: {}, now: () => NOW });
  const r = (await admin.handle({ action: 'emails', body: {}, authorization: 'Bearer t' })).json;
  assert.equal(r.total, 1); assert.equal(r.desinscrits, 1); assert.equal(r.confirmes, 0);
  assert.deepEqual(r.liste.map((x) => x.email), ['a@exemple.com']);
});

test('pages : « Mes notifications » et « Coupon » portent le remerciement, le partage et le formulaire e-mail ; page notifications non indexée', async () => {
  const db = await buildSample(new Date('2026-10-16T08:00:00Z'));
  for (const [path, en] of [['/notifications', false], ['/en/notifications', true], ['/coupon', false]]) {
    const r = await route(db, path, new Date('2026-10-16T08:00:00Z'));
    assert.equal(r.status, 200, path);
    assert.match(r.body, /class="box shb"/);
    assert.match(r.body, /class="box mlb"/);
    assert.match(r.body, en ? /Thank you, and spread the word/ : /Merci, et fais connaître/);
    assert.match(r.body, /name="consent"/);
    assert.match(r.body, /wa\.me\/\?text=/);
    assert.match(r.body, en ? /\/en\/privacy/ : /\/confidentialite/);
  }
  const n = await route(db, '/notifications', new Date('2026-10-16T08:00:00Z'));
  assert.match(n.body, /id="pf-inbox"/);
  assert.match(n.body, /noindex/);
  const sitemap = (await route(db, '/sitemap.xml', new Date('2026-10-16T08:00:00Z'))).body;
  assert.ok(!sitemap.includes('notifications'), 'jamais dans le sitemap');
});
