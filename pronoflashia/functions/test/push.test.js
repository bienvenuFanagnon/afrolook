'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeDb } = require('./helpers/fakeDb');
const subs = require('../src/push/subs');
const { handlePush } = require('../src/http/push');
const M = require('../src/push/messages');
const { sendPush } = require('../src/jobs/sendPush');
const { ensureVapid, resetMemo } = require('../src/push/keys');
const { createAdmin } = require('../src/http/admin');

const T0 = new Date('2026-10-16T07:40:00Z');
const EP = (n) => `https://fcm.googleapis.com/fcm/send/abc${n}`;
const KEYS = { p256dh: 'BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTpQtUbVlUls0VJXg7A8u-Ts1XbjhazAkj7I99e8QcYP7DkM', auth: 'tBHItJI5svbpez7KI4CCXg' };
const sub = (n, extra = {}) => ({ subscription: { endpoint: EP(n), keys: KEYS }, lang: 'fr', ...extra });

const mk = (id, h, teams, extra = {}) => ({
  id, jour: '2026-10-16', statut: 'prevu', coupDEnvoi: `2026-10-16T${h}:00:00.000Z`, slug: `a${id}-b${id}`, leagueSlug: 'ligue-1',
  domicile: { teamId: teams[0], nomCourt: `A${id}` }, exterieur: { teamId: teams[1], nomCourt: `B${id}` },
  prono: { visible: true, principal: { cle: 'res:1', libelle: `1N · A${id} ou nul`, confiance: 70 + Number(id), basseConfiance: false }, marches: [{ cle: 'buts:over:1.5', libelle: '+1,5 buts', famille: 'Buts', pct: 78, fiabilite: 'haute' }, { cle: 'res:1', libelle: 'A gagne', famille: 'Résultat', pct: 66, fiabilite: 'haute' }] },
  ...extra,
});

test('abonnement : adresse d\'envoi limitée aux services de notification connus (pas de requête vers une adresse quelconque)', async () => {
  assert.equal(subs.validEndpoint('https://fcm.googleapis.com/fcm/send/x'), true);
  assert.equal(subs.validEndpoint('https://updates.push.services.mozilla.com/wpush/v2/x'), true);
  assert.equal(subs.validEndpoint('https://web.push.apple.com/x'), true);
  assert.equal(subs.validEndpoint('https://exemple.com/x'), false);
  assert.equal(subs.validEndpoint('http://fcm.googleapis.com/x'), false);
  assert.equal(subs.validEndpoint('https://fcm.googleapis.com.evil.com/x'), false);
  assert.equal(subs.validEndpoint('https://user@fcm.googleapis.com/x'), false);
  assert.equal(subs.validEndpoint('https://169.254.169.254/'), false);
  const db = new FakeDb();
  await assert.rejects(subs.subscribe(db, { subscription: { endpoint: 'https://exemple.com/x', keys: KEYS } }, T0), /invalide/);
  await assert.rejects(subs.subscribe(db, { subscription: { endpoint: EP(1), keys: { p256dh: '<x>', auth: 'y' } } }, T0), /invalide/);
});

test('abonnement : création, mise à jour sans perdre les équipes, équipes (ajout, retrait, plafond), désabonnement', async () => {
  const db = new FakeDb();
  const r = await subs.subscribe(db, sub(1, { equipes: ['81', 'x', '85'] }), T0);
  assert.equal(r.nouveau, true);
  assert.deepEqual(db.read('push_subs', r.id).equipes, ['81', '85']);
  await subs.subscribe(db, sub(1, { lang: 'en' }), T0);
  assert.deepEqual(db.read('push_subs', r.id).equipes, ['81', '85'], 'équipes gardées si non transmises');
  assert.equal(db.read('push_subs', r.id).lang, 'en');
  assert.deepEqual((await subs.setTeam(db, EP(1), '90', 'add')).equipes, ['81', '85', '90']);
  assert.deepEqual((await subs.setTeam(db, EP(1), '81', 'remove')).equipes, ['85', '90']);
  for (let i = 100; i < 120; i++) await subs.setTeam(db, EP(1), String(i), 'add');
  assert.equal(db.read('push_subs', r.id).equipes.length, subs.MAX_TEAMS);
  await assert.rejects(subs.setTeam(db, EP(9), '1', 'add'), /inconnu/);
  await subs.unsubscribe(db, EP(1));
  assert.equal(db.read('push_subs', r.id), null);
});

test('API : clé publique, abonnement, désabonnement, mauvaise méthode, limite de débit', async () => {
  const db = new FakeDb();
  const deps = { db, now: T0, publicKey: async () => 'CLE_PUBLIQUE' };
  const call = (method, path, body, ip = '5.5.5.5') => handlePush({ method, path: `/api/push/${path}`, body, ip }, deps);
  assert.deepEqual((await call('GET', 'key')).json, { publicKey: 'CLE_PUBLIQUE' });
  assert.equal((await call('GET', 'subscribe')).status, 405);
  assert.equal((await call('POST', 'subscribe', sub(1))).status, 200);
  assert.equal((await call('POST', 'subscribe', { subscription: { endpoint: 'https://exemple.com' } })).status, 400);
  assert.equal((await call('POST', 'unsubscribe', { endpoint: EP(1) })).status, 200);
  assert.equal((await call('POST', 'nimporte', {})).status, 404);
  let last;
  for (let i = 0; i < 25; i++) last = await call('POST', 'subscribe', sub(2), '6.6.6.6');
  assert.equal(last.status, 429);
});

test('clés VAPID : créées une fois, gardées côté serveur, jamais régénérées', async () => {
  const db = new FakeDb();
  let n = 0;
  const webpush = { generateVAPIDKeys: () => { n++; return { publicKey: 'PUB' + n, privateKey: 'PRIV' + n }; } };
  resetMemo();
  const a = await ensureVapid(db, webpush);
  resetMemo();
  const b = await ensureVapid(db, webpush);
  assert.equal(a.publicKey, 'PUB1');
  assert.equal(b.publicKey, 'PUB1');
  assert.equal(n, 1);
  assert.ok(db.read('push_keys', 'vapid').privateKey);
});

test('messages : coupons du jour, pronostic le plus confiant, coupon du soir, alerte équipe ; français et anglais, sans promesse de gain', () => {
  const coupons = [{ n: 3, nom: 'equilibre', prob: 0.585, statut: 'ouvert' }, { n: 2, nom: 'prudent', prob: 0.71, statut: 'ouvert' }, { n: 5, nom: 'audacieux', prob: 0.364, statut: 'perdu' }];
  const m1 = M.matin(coupons, 'fr');
  assert.match(m1.corps, /Prudent 71 % · Équilibré 59 % de chances que tout passe/);
  assert.ok(!/Audacieux/.test(m1.corps), 'les coupons déjà réglés ne sont pas annoncés');
  assert.equal(m1.url, '/coupon?source=push&slot=matin');
  assert.match(M.matin(coupons, 'en').corps, /Cautious 71% · Balanced 59% chance that everything wins/);
  assert.equal(M.matin([], 'fr'), null);
  const ms = [mk('1', '15', [1, 2]), mk('3', '17', [3, 4]), mk('2', '18', [5, 6])];
  const mid = M.midi(ms, 'fr');
  assert.match(mid.corps, /A3 – B3/);
  assert.match(mid.url, /^\/football\/ligue-1\/a3-b3\?source=push/);
  assert.match(M.midi(ms, 'en').url, /^\/en\/football\//);
  const so = M.soir(ms, 'fr');
  assert.match(so.corps, /3 paris sur les matchs de ce soir : \d+ % de chances que tout passe/);
  assert.equal(M.soir([mk('1', '15', [1, 2])], 'fr'), null);
  const eq = M.equipe(ms[0], 'fr');
  assert.match(eq.corps, /A1 – B1 commence bientôt\. Notre pronostic/);
  for (const t of [m1, mid, so, eq]) assert.ok(!/garanti|gagner de l'argent|gain/i.test(t.titre + t.corps));
});

async function world(n = 3) {
  const db = new FakeDb();
  for (let i = 1; i <= n; i++) await subs.subscribe(db, sub(i, { lang: i === 3 ? 'en' : 'fr' }), T0);
  const sent = [];
  const send = async (s, p) => { sent.push({ id: s.id, lang: s.lang, p }); };
  return { db, sent, send };
}

test('envoi : un créneau n\'est envoyé qu\'une fois par jour, dans la langue de chaque abonné, et seulement dans sa fenêtre', async () => {
  const { db, sent, send } = await world();
  await db.seed('coupons_flash', '2026-10-16_2', { id: '2026-10-16_2', jour: '2026-10-16', n: 2, nom: 'prudent', prob: 0.7, statut: 'ouvert' });
  await db.seed('matches', 'm1', mk('1', '15', [1, 2]));
  await db.seed('matches', 'm2', mk('2', '18', [3, 4]));
  const run = (now) => { const rep = { traites: 0, erreurs: [], infos: {} }; return sendPush({ db, send, now }, rep).then(() => rep); };
  const r1 = await run(T0); // 07:40 : matin
  assert.equal(r1.infos.matin.envoyes, 3);
  assert.equal(sent.filter((x) => x.lang === 'en').length, 1);
  assert.match(sent.find((x) => x.lang === 'en').p.titre, /Today's slips/);
  await run(new Date('2026-10-16T07:55:00Z'));
  assert.equal(sent.length, 3, 'pas de second envoi du même créneau');
  await run(new Date('2026-10-16T11:00:00Z'));
  assert.equal(sent.length, 3, 'hors fenêtre : rien');
  await run(new Date('2026-10-16T12:35:00Z')); // midi
  assert.equal(sent.length, 6);
  assert.equal(db.read('push_log', '2026-10-16_midi').envoyes, 3);
  await run(new Date('2026-10-16T16:35:00Z')); // soir : un seul match reste (A2 – B2 à 18:00) → rien à annoncer
  assert.equal(db.read('push_log', '2026-10-16_soir').ignore, 'rien à annoncer');
  await run(new Date('2026-10-17T07:40:00Z'));
  assert.equal(sent.length, 6, 'le lendemain : aucun coupon archivé pour ce jour, donc rien');
});

test('envoi : interrupteur général, aucun abonné, abonnement expiré (410) supprimé, échecs répétés supprimés', async () => {
  const { db, sent, send } = await world(2);
  await db.seed('coupons_flash', '2026-10-16_2', { id: '2026-10-16_2', jour: '2026-10-16', n: 2, nom: 'prudent', prob: 0.7, statut: 'ouvert' });
  await db.seed('config', 'push', { actif: false });
  const rep0 = { traites: 0, erreurs: [], infos: {} };
  await sendPush({ db, send, now: T0 }, rep0);
  assert.equal(sent.length, 0);
  await db.seed('config', 'push', { actif: true });
  const gone = subs.idOf(EP(1)), flaky = subs.idOf(EP(2));
  const send2 = async (s) => { if (s.id === gone) throw Object.assign(new Error('Gone'), { statusCode: 410 }); throw Object.assign(new Error('boum'), { statusCode: 500 }); };
  const rep = { traites: 0, erreurs: [], infos: {} };
  await sendPush({ db, send: send2, now: T0 }, rep);
  assert.equal(db.read('push_subs', gone), null, 'expiré : retiré');
  assert.equal(db.read('push_subs', flaky).echecs, 1);
  assert.equal(rep.infos.matin.retires, 1);
  assert.equal((await (async () => { const d2 = new FakeDb(); const r = { traites: 0, erreurs: [], infos: {} }; await sendPush({ db: d2, send, now: T0 }, r); return r.infos.abonnes; })()), 0);
});

test('alertes d\'équipe : une heure avant le match, abonnés qui suivent l\'équipe seulement, une fois par match, 2 par jour au plus', async () => {
  const { db, sent, send } = await world(3);
  await subs.setTeam(db, EP(1), '10', 'add');
  await subs.setTeam(db, EP(3), '20', 'add');
  await db.seed('matches', 'a', mk('1', '19', [10, 11])); // 19:00
  await db.seed('matches', 'b', mk('2', '19', [10, 12]));
  await db.seed('matches', 'c', mk('3', '19', [10, 13]));
  const run = (now) => sendPush({ db, send, now }, { traites: 0, erreurs: [], infos: {} });
  await run(new Date('2026-10-16T17:45:00Z')); // match à 19:00 : dans 75 min, donc dans la fenêtre de 45 à 105 min
  const alerts = sent.filter((x) => /Match de vos équipes|Match of your teams/.test(x.p.titre));
  assert.equal(alerts.length, 2, 'les 2 premiers matchs (plafond de 2 par jour) pour l\'abonné 1 ; l\'abonné 2 ne suit personne');
  assert.ok(alerts.every((x) => x.id === subs.idOf(EP(1))));
  assert.equal(db.read('push_subs', subs.idOf(EP(1))).equipesN, 2);
  await run(new Date('2026-10-16T17:55:00Z'));
  assert.equal(sent.filter((x) => /équipes/.test(x.p.titre)).length, 2, 'pas de doublon, ni troisième alerte');
  assert.ok(db.read('push_log', 'eq_1') && db.read('push_log', 'eq_2'));
  assert.equal(db.read('push_log', 'eq_3'), null, 'plus de cible pour le troisième match');
});

test('admin : état des notifications et interrupteur', async () => {
  const { db } = await world(2);
  await db.seed('push_log', 'x', { id: 'x', slot: 'matin', jour: '2026-10-16', au: T0.toISOString(), abonnes: 2, envoyes: 2, echecs: 0, retires: 0 });
  const admin = createAdmin({ db, verifyToken: async () => ({ email: 'a@x.fr', email_verified: true }), bootstrap: ['a@x.fr'], tasks: {}, now: () => T0 });
  const call = (action, body) => admin.handle({ action, body: body || {}, authorization: 'Bearer t' });
  const r = (await call('push')).json;
  assert.equal(r.abonnes, 2);
  assert.equal(r.actif, true);
  assert.equal(r.envois[0].slot, 'matin');
  await call('push-save', { actif: false });
  assert.equal((await call('push')).json.actif, false);
});

test('web-push réel : message chiffré et signé VAPID pour un abonnement navigateur (sans réseau)', async () => {
  const crypto = require('crypto');
  const webpush = require('web-push');
  const db = new FakeDb();
  resetMemo();
  const k = await ensureVapid(db, webpush);
  webpush.setVapidDetails('https://pronoflashia.web.app', k.publicKey, k.privateKey);
  // clés d'un navigateur fictif
  const ecdh = crypto.createECDH('prime256v1'); ecdh.generateKeys();
  const subscription = { endpoint: EP(7), keys: { p256dh: ecdh.getPublicKey().toString('base64url'), auth: crypto.randomBytes(16).toString('base64url') } };
  const d = webpush.generateRequestDetails(subscription, JSON.stringify({ t: 'Test', b: 'Corps', u: '/coupon', g: 'x' }), { TTL: 3600, urgency: 'normal' });
  assert.equal(d.method, 'POST');
  assert.equal(d.endpoint, EP(7));
  assert.match(d.headers.Authorization, /^vapid t=.+, k=/);
  assert.equal(d.headers['Content-Encoding'], 'aes128gcm');
  assert.ok(Buffer.isBuffer(d.body) && d.body.length > 100);
  assert.ok(!d.body.toString('utf8').includes('Corps'), 'le contenu est chiffré');
  resetMemo();
});

test('admin : notification de test — compte-rendu (abonnés, envoyées, refusées avec la cause, expirées supprimées) et conseil quand personne n\'est abonné', async () => {
  const db = new FakeDb();
  const mkAdmin = (sender) => createAdmin({ db, verifyToken: async () => ({ email: 'a@x.fr', email_verified: true }), bootstrap: ['a@x.fr'], tasks: {}, now: () => T0, pushSender: sender });
  const call = (admin, action) => admin.handle({ action, body: {}, authorization: 'Bearer t' });
  const vide = (await call(mkAdmin(async () => async () => {}), 'push-test')).json;
  assert.equal(vide.abonnes, 0);
  assert.match(vide.conseil, /Aucun abonné enregistré/);
  await subs.subscribe(db, sub(1), T0);
  await subs.subscribe(db, sub(2, { lang: 'en' }), T0);
  await subs.subscribe(db, sub(3), T0);
  const seen = [];
  const send = async (s, p) => {
    seen.push(p.titre);
    if (s.id === subs.idOf(EP(2))) throw Object.assign(new Error('Gone'), { statusCode: 410 });
    if (s.id === subs.idOf(EP(3))) throw Object.assign(new Error('Unauthorized'), { statusCode: 401, body: 'invalid vapid' });
  };
  const r = (await call(mkAdmin(async () => send), 'push-test')).json;
  assert.equal(r.abonnes, 3);
  assert.equal(r.envoyes, 1);
  assert.equal(r.retires, 1, 'abonnement expiré supprimé');
  assert.equal(r.echecs, 1);
  assert.ok(r.erreurs.some((e) => /^401/.test(e)), 'la cause est renvoyée');
  assert.ok(seen.includes('🔔 PronoFlash IA test') && seen.includes('🔔 Test PronoFlash IA'), 'langue de chaque abonné');
  assert.equal(db.read('push_subs', subs.idOf(EP(2))), null);
  const sans = createAdmin({ db, verifyToken: async () => ({ email: 'a@x.fr', email_verified: true }), bootstrap: ['a@x.fr'], tasks: {}, now: () => T0 });
  assert.equal((await call(sans, 'push-test')).status, 501);
});
