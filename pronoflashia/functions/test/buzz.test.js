'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeDb } = require('./helpers/fakeDb');
const subs = require('../src/push/subs');
const card = require('../src/push/card');
const buzz = require('../src/push/buzz');
const M = require('../src/push/messages');
const { handleImg } = require('../src/http/img');
const { sendPush, isQuiet } = require('../src/jobs/sendPush');
const { createAdmin } = require('../src/http/admin');

const NOW = new Date('2026-10-17T12:00:00Z');
const KEYS = { p256dh: 'BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTpQtUbVlUls0VJXg7A8u-Ts1XbjhazAkj7I99e8QcYP7DkM', auth: 'tBHItJI5svbpez7KI4CCXg' };
const EP = (n) => `https://fcm.googleapis.com/fcm/send/zz${n}`;
const reg = (db, n, extra = {}) => subs.subscribe(db, Object.assign({ subscription: { endpoint: EP(n), keys: KEYS }, lang: 'fr' }, extra), NOW);
const news = (id, titre, extra = {}) => Object.assign({ id, titre, resume: '', lien: `https://s.fr/${id}`, source: 'Foot Mercato', sourceId: 'fm', lang: 'fr', date: '2026-10-17T10:30:00.000Z', image: 'https://i.fr/x.jpg', teamIds: [] }, extra);
const PNG = Buffer.from([0x89, 0x50, 0x4e, 0x47]);

test('cartes : PNG valide, emoji retirés de l\'image, identifiant stable, texte borné', () => {
  const c = { badge: '⚡ Coupons du jour', titre: 'Arsenal – Chelsea', lignes: [{ l: 'Prudent · 2 matchs', v: '76 %' }], pied: 'PronoFlash IA' };
  const png = card.renderPng(c);
  assert.deepEqual(Buffer.from(png).subarray(0, 4), PNG);
  assert.equal(card.cleanCard(c).badge, 'Coupons du jour');
  assert.equal(card.cardId(c), card.cardId(Object.assign({}, c)));
  assert.notEqual(card.cardId(c), card.cardId(Object.assign({}, c, { titre: 'Autre' })));
  assert.equal(card.cleanCard({ titre: 'x'.repeat(500), lignes: Array(9).fill({ l: 'a', v: 'b' }) }).titre.length, 120);
  assert.equal(card.cleanCard({ titre: 'x'.repeat(500), lignes: Array(9).fill({ l: 'a', v: 'b' }) }).lignes.length, 4);
  assert.match(card.svgOf({ titre: '<script>alert(1)</script>' }), /&lt;script&gt;/, 'le texte est échappé');
});

test('image : adresse /api/img/{id}.png dessinée à la demande, image envoyée par l\'admin servie telle quelle, inconnu en 404', async () => {
  const db = new FakeDb();
  const url = await card.saveCard(db, { badge: 'Test', titre: 'Real Madrid – Barça' }, NOW);
  assert.match(url, /^\/api\/img\/[a-f0-9]{16}\.png$/);
  const r = await handleImg({ path: url }, { db });
  assert.equal(r.status, 200);
  assert.equal(r.type, 'image/png');
  assert.deepEqual(r.body.subarray(0, 4), PNG);
  assert.match(r.cache, /s-maxage/);
  await db.seed('push_cards', 'uabcdef123456', { id: 'uabcdef123456', img: Buffer.from([0xff, 0xd8, 0xff, 1]).toString('base64'), type: 'image/jpeg' });
  const j = await handleImg({ path: '/api/img/uabcdef123456.jpg' }, { db });
  assert.equal(j.type, 'image/jpeg');
  assert.equal((await handleImg({ path: '/api/img/inconnu0000.png' }, { db })).status, 404);
  assert.equal((await handleImg({ path: '/api/img/../../etc.png' }, { db })).status, 404);
});

test('actus qui font parler : stars, pépites, enfants de légendes, classicos, vie des vedettes, mercato ; sujets sensibles écartés', () => {
  const a = (titre, resume, extra) => buzz.assess(news('x', titre, Object.assign({ resume: resume || '' }, extra)), NOW);
  const mb = a('Mbappé : le Real prépare une offre record pour prolonger');
  assert.ok(mb.score >= buzz.SEUIL && mb.themes.includes('star') && mb.star === 'Mbappé' && !mb.sensible);
  assert.ok(a('Un jeune de 16 ans, futur Messi, signe à Lille').themes.includes('talent'));
  assert.ok(a('Le fils de Cristiano Ronaldo marque 4 buts avec son académie').themes.includes('enfant'));
  assert.ok(a('Classico : Real Madrid – Barça, le choc de la semaine').themes.includes('classico'));
  assert.ok(a('Lamine Yamal en vacances avec sa compagne', '').themes.includes('vie'));
  assert.ok(a('Haaland : polémique après sa sortie', '').themes.includes('scandale'));
  assert.ok(a('Ligue 2 : Rodez prolonge son entraîneur').score < buzz.SEUIL, 'une actu sans vedette reste sous le seuil');
  assert.equal(a('Décès de l\'ancien joueur du Real Madrid').sensible, true);
  assert.equal(a('Mbappé : le fils de 5 ans au centre d\'un scandale').sensible, true, 'jamais de polémique qui touche un mineur');
  assert.equal(a('Messi arrêté par la police', '').sensible, true);
  assert.equal(a('Mbappé signe', '', { date: '2026-10-15T01:00:00.000Z' }).sensible, true, 'plus de 30 heures : trop vieux');
  assert.ok(buzz.assess(news('y', 'Messi : record', { date: '2026-10-17T11:30:00.000Z' }), NOW).score > buzz.assess(news('y', 'Messi : record', { date: '2026-10-17T00:30:00.000Z' }), NOW).score, 'plus c\'est frais, plus ça compte');
  assert.ok(buzz.assess(news('z', 'Un jeune attaquant fait le buzz'), NOW, ['attaquant']).star === 'attaquant', 'noms ajoutés depuis l\'admin');
});

test('texte accrocheur : accepté s\'il reformule et cite la source ; refusé s\'il invente un nom, un chiffre, recopie le titre, oublie la source ou promet', () => {
  const n = news('1', 'Mbappé et le Real Madrid : une prolongation évoquée', { resume: 'Le club madrilène réfléchit à la suite du contrat.' });
  const ok = JSON.stringify({ titre: '🔥 Mbappé au Real : la suite se précise ?', corps: 'Selon Foot Mercato, le club réfléchit au futur du contrat. Notre résumé est à lire.' });
  assert.ok(buzz.validateHook(ok, n, 'fr'));
  const bad = (o) => buzz.validateHook(JSON.stringify(Object.assign(JSON.parse(ok), o)), n, 'fr');
  assert.equal(bad({ corps: 'Selon Foot Mercato, Vinicius arrive aussi. À lire maintenant.' }), null, 'nom inventé');
  assert.equal(bad({ corps: 'Selon Foot Mercato, 85 millions sont sur la table. À lire vite.' }), null, 'chiffre inventé');
  assert.equal(bad({ corps: 'Le club réfléchit à la suite du contrat, à lire absolument ici.' }), null, 'source non citée');
  assert.equal(bad({ titre: '🔥 Mbappé et le Real Madrid : une prolongation évoquée' }), null, 'titre de presse recopié');
  assert.equal(bad({ corps: 'Selon Foot Mercato, c\'est un gain garanti pour les parieurs, foncez.' }), null, 'promesse');
  assert.equal(bad({ titre: 'x' }), null);
  assert.equal(buzz.validateHook('pas du json', n, 'fr'), null);
  const fb = buzz.hookFallback(n, buzz.assess(n, NOW), 'fr');
  assert.match(fb.corps, /Foot Mercato en parle/);
  assert.ok(fb.titre.length <= 62);
  const rumeur = buzz.hookFallback(news('2', 'Mbappé pourrait quitter le Real ?'), buzz.assess(news('2', 'Mbappé pourrait quitter le Real ?'), NOW), 'fr');
  assert.match(rumeur.corps, /^À confirmer/);
});

test('buildHook : IA valide → texte de l\'IA ; IA en panne ou refusée → texte modèle ; carte sans emoji, source en pied', async () => {
  const n = news('1', 'Mbappé et le Real Madrid : une prolongation évoquée', { resume: 'Le club réfléchit à la suite du contrat.' });
  const a = buzz.assess(n, NOW);
  const good = { call: async () => JSON.stringify({ titre: '🔥 Mbappé au Real : la suite se précise ?', corps: 'Selon Foot Mercato, le club réfléchit au futur du contrat. Notre résumé est à lire.' }) };
  const h1 = await buzz.buildHook(n, a, 'fr', [good]);
  assert.equal(h1.methode, 'ia');
  assert.doesNotMatch(h1.carte.titre, /🔥/);
  assert.equal(h1.carte.pied, 'Foot Mercato');
  const h2 = await buzz.buildHook(n, a, 'fr', [{ call: async () => { throw new Error('quota'); } }, { call: async () => 'n importe quoi' }]);
  assert.equal(h2.methode, 'modele');
  assert.equal((await buzz.buildHook(n, a, 'fr', [])).methode, 'modele');
});

async function world() {
  const db = new FakeDb();
  const sent = [];
  const send = async (s, p) => { sent.push({ id: s.id, lang: s.lang, p }); };
  const run = (now, extra = {}) => { const rep = { traites: 0, erreurs: [], infos: {} }; return sendPush(Object.assign({ db, send, now }, extra), rep).then(() => rep); };
  return { db, sent, run };
}

test('actu à heure variable : une seule, la plus forte, avec image et lien vers notre page ; 3 h d\'écart ; jamais la même histoire deux fois', async () => {
  const { db, sent, run } = await world();
  await reg(db, 1); await reg(db, 2);
  await db.seed('news', 'n1', news('n1', 'Mbappé : le Real prépare une offre record pour prolonger'));
  await db.seed('news', 'n2', news('n2', 'Mbappé : une offre record pour prolonger, selon la presse', { source: 'Afrik-Foot', sourceId: 'af' }));
  await db.seed('news', 'n3', news('n3', 'Ligue 2 : Rodez prolonge son entraîneur'));
  const r = await run(NOW);
  assert.equal(r.infos.actu.envoyes, 2);
  assert.equal(sent.length, 2);
  const p = sent[0].p;
  assert.match(p.url, /^\/actus\/info-n[12]\?source=push&slot=actu$/);
  assert.match(p.image, /^\/api\/img\/[a-f0-9]{16}\.png$/);
  assert.ok(p.titre.length <= 62 && p.corps);
  assert.ok(db.read('push_cards', p.image.split('/').pop().replace('.png', '')), 'la carte est enregistrée');
  await run(new Date(NOW.getTime() + 20 * 60e3));
  assert.equal(sent.length, 2, 'pas deux actus en moins de 3 heures');
  const later = new Date(NOW.getTime() + 3.5 * 3600e3);
  await run(later);
  assert.equal(sent.length, 2, 'même histoire (Mbappé, mercato) reprise par un autre site : déjà annoncée aujourd\'hui, et Rodez est sous le seuil');
  assert.equal(db.read('subs', 'x'), null);
  const s1 = db.read('push_subs', subs.idOf(EP(1)));
  assert.equal(s1.actuN, 1);
  assert.equal(s1.n, 1);
});

test('actu : plafonds par abonné (2 actus et 4 notifications par jour), nuit locale respectée, interrupteur, sujets sensibles jamais envoyés', async () => {
  const { db, sent, run } = await world();
  await reg(db, 1); await reg(db, 2, { tzo: -720 }); // UTC+12 : il est minuit à 12:00 UTC → nuit
  assert.equal(isQuiet(db.read('push_subs', subs.idOf(EP(2))), NOW), true);
  assert.equal(isQuiet(db.read('push_subs', subs.idOf(EP(1))), NOW), false);
  await db.seed('news', 'n1', news('n1', 'Haaland : record historique'));
  await run(NOW);
  assert.deepEqual(sent.map((x) => x.id), [subs.idOf(EP(1))], 'l\'abonné qui dort ne reçoit rien');
  await db.seed('news', 'n2', news('n2', 'Messi : transfert surprise confirmé'));
  await run(new Date(NOW.getTime() + 3.1 * 3600e3));
  await db.seed('news', 'n3', news('n3', 'Salah : un record de plus', { date: '2026-10-17T17:00:00.000Z' }));
  await run(new Date('2026-10-17T18:30:00Z'));
  assert.equal(sent.length, 2, '2 actus par jour au plus pour un abonné');
  const sens = await world();
  await reg(sens.db, 1);
  await sens.db.seed('news', 'n9', news('n9', 'Décès de Cristiano Ronaldo senior : hommage de Messi'));
  await sens.run(NOW);
  assert.equal(sens.sent.length, 0);
  const off = await world();
  await reg(off.db, 1);
  await off.db.seed('config', 'push', { actif: false });
  await off.db.seed('news', 'n1', news('n1', 'Haaland : record historique'));
  await off.run(NOW);
  assert.equal(off.sent.length, 0);
});

test('actu : ceux qui suivent l\'équipe citée reçoivent aussi les actus plus modestes ; la langue de l\'article décide de l\'audience', async () => {
  const { db, sent, run } = await world();
  await reg(db, 1, { equipes: ['77'] }); await reg(db, 2); await reg(db, 3, { lang: 'en', equipes: ['77'] });
  await db.seed('news', 'n1', news('n1', 'Le club de Rodez prolonge son gardien', { teamIds: ['77'], date: '2026-10-17T05:00:00.000Z', image: null }));
  const r = await run(NOW);
  assert.ok(r.infos.actu, 'score entre 3 et le seuil : envoyé aux abonnés de l\'équipe');
  assert.deepEqual(sent.map((x) => x.id), [subs.idOf(EP(1))], 'abonné français qui suit l\'équipe seulement (l\'article est en français)');
});

test('choc du jour : classico ou duel de grands clubs annoncé avec notre pronostic, en français et en anglais, une fois', async () => {
  const { db, sent, run } = await world();
  await reg(db, 1); await reg(db, 2, { lang: 'en' });
  const m = { id: 'c1', jour: '2026-10-17', statut: 'prevu', coupDEnvoi: '2026-10-17T18:00:00.000Z', slug: 'real-madrid-barcelone', leagueSlug: 'liga', domicile: { teamId: 86, nom: 'Real Madrid CF', nomCourt: 'Real Madrid' }, exterieur: { teamId: 81, nom: 'FC Barcelona', nomCourt: 'Barça' }, prono: { visible: true, principal: { cle: 'res:1', libelle: 'Victoire du Real', confiance: 54, basseConfiance: false } } };
  await db.seed('matches', 'c1', m);
  const r = await run(NOW);
  assert.equal(r.infos.actu.sujet, 'choc');
  assert.equal(sent.length, 2);
  assert.match(sent.find((x) => x.lang === 'fr').p.titre, /Classico : Real Madrid – Barça/);
  assert.match(sent.find((x) => x.lang === 'en').p.titre, /Classico: Real Madrid – Barça/);
  assert.match(sent[0].p.url, /source=push&slot=choc/);
  assert.ok(sent[0].p.image);
  await run(new Date(NOW.getTime() + 4 * 3600e3));
  assert.equal(sent.length, 2, 'une seule fois');
});

test('images dans les notifications automatiques : coupons du matin, pronostic de midi, alertes d\'équipe portent une carte', () => {
  const coupons = [{ n: 2, nom: 'prudent', prob: 0.71, statut: 'ouvert', selections: [{ titre: 'Arsenal – Chelsea', pct: 80 }] }, { n: 3, nom: 'equilibre', prob: 0.5, statut: 'ouvert', selections: [] }];
  const m = M.matin(coupons, 'fr');
  assert.equal(m.carte.titre, 'Arsenal – Chelsea');
  assert.equal(m.carte.lignes.length, 2);
  assert.match(m.titre, /Arsenal – Chelsea/);
  assert.equal(M.actu({ titre: 't', corps: 'c' }, { id: 'abc' }, 'en').url, '/en/news/info-abc?source=push&slot=actu');
});

test('admin : annonce — validation, essai sur un appareil, confirmation obligatoire, envoi une seule fois, image envoyée contrôlée', async () => {
  const db = new FakeDb();
  const sent = [];
  const sender = async () => async (s, p) => { sent.push({ id: s.id, p }); };
  const admin = createAdmin({ db, verifyToken: async () => ({ email: 'a@x.fr', email_verified: true }), bootstrap: ['a@x.fr'], tasks: {}, now: () => NOW, pushSender: sender });
  const call = (action, body) => admin.handle({ action, body, authorization: 'Bearer t' });
  await reg(db, 1); await reg(db, 2, { lang: 'en' });
  assert.equal((await call('push-annonce', { titre: 'a', corps: 'b' })).status, 400);
  assert.equal((await call('push-annonce', { titre: 'Titre', corps: 'Texte', url: '//evil.com' })).status, 400, 'seules les pages du site');
  assert.equal((await call('push-annonce', { titre: 'Titre', corps: 'Texte', url: 'https://evil.com' })).status, 400);
  assert.equal((await call('push-annonce', { titre: 'Titre', corps: 'Texte', essai: true, endpoint: EP(99) })).status, 404);
  const essai = await call('push-annonce', { titre: 'Titre', corps: 'Texte', url: '/coupon', essai: true, endpoint: EP(1), image: { mode: 'carte', titre: 'Titre' } });
  assert.equal(essai.json.envoyes, 1);
  assert.equal(sent.length, 1);
  assert.equal(sent[0].p.url, '/coupon?source=push&slot=annonce');
  assert.match(sent[0].p.image, /^\/api\/img\//);
  assert.equal((await call('push-annonce', { titre: 'Titre', corps: 'Texte', id: 'abcdefgh1' })).status, 400, 'sans confirmation : rien ne part');
  assert.equal(sent.length, 1);
  assert.equal((await call('push-annonce', { titre: 'Titre', corps: 'Texte', confirmer: true, id: 'abcdefgh1', image: { mode: 'fichier', data: Buffer.from('pas une image').toString('base64') } })).status, 400);
  const jpeg = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(200)]).toString('base64');
  const ok = await call('push-annonce', { titre: 'Nouveauté', corps: 'Un texte', titreEn: 'News', corpsEn: 'A text', confirmer: true, id: 'abcdefgh1', image: { mode: 'fichier', data: 'data:image/jpeg;base64,' + jpeg } });
  assert.equal(ok.status, 200);
  assert.equal(ok.json.envoyes, 2);
  assert.equal(sent.filter((x) => x.p.titre === 'News').length, 1, 'version anglaise pour l\'abonné anglais');
  assert.match(sent[sent.length - 1].p.image, /\.jpg$/);
  assert.equal((await call('push-annonce', { titre: 'Nouveauté', corps: 'Un texte', confirmer: true, id: 'abcdefgh1' })).status, 409, 'double clic : une seule annonce');
  assert.equal(db.read('push_log', 'annonce_abcdefgh1').titre, 'Nouveauté');
  const cible = (await call('push-cible', {})).json;
  assert.deepEqual(cible, { abonnes: 2, fr: 1, en: 1 });
  const carte = (await call('push-carte', { carte: { titre: 'Aperçu' } })).json;
  assert.deepEqual(Buffer.from(carte.png, 'base64').subarray(0, 4), PNG);
  await call('push-save', { actif: true, maxJour: 99, seuil: 1, vedettes: 'Kenan Yildiz\n\nab\nLamine Camara' });
  const st = (await call('push')).json;
  assert.equal(st.maxJour, 8); assert.equal(st.seuil, 3); assert.deepEqual(st.vedettes, ['Kenan Yildiz', 'Lamine Camara']);
});
