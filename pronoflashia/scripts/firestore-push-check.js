'use strict';
// Notifications sur le vrai Firestore (émulateur) : abonnements, envoi automatique avec actu et classico, images, annonce de l'admin.
// Détecte ce que la base factice des tests accepte et que Firestore refuse (tableaux imbriqués, champs undefined…).
// Usage (Java requis) : firebase emulators:exec --only firestore --project demo-pf "node scripts/firestore-push-check.js"
const path = require('path');
const fn = path.join(__dirname, '../functions');
const need = (m) => require(require.resolve(m, { paths: [fn] }));
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
const { initializeApp } = need('firebase-admin/app');
const { getFirestore } = need('firebase-admin/firestore');
const subs = require('../functions/src/push/subs');
const { sendPush } = require('../functions/src/jobs/sendPush');
const { createAdmin } = require('../functions/src/http/admin');
const { handleImg } = require('../functions/src/http/img');
const inbox = require('../functions/src/push/inbox');
const mail = require('../functions/src/mail/subs');

const KEYS = { p256dh: 'BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTpQtUbVlUls0VJXg7A8u-Ts1XbjhazAkj7I99e8QcYP7DkM', auth: 'tBHItJI5svbpez7KI4CCXg' };
const NOW = new Date('2026-10-17T12:00:00Z');

(async () => {
  initializeApp({ projectId: 'demo-pf' });
  const db = getFirestore();
  db.settings({ ignoreUndefinedProperties: false });
  for (let i = 1; i <= 2; i++) await subs.subscribe(db, { subscription: { endpoint: `https://fcm.googleapis.com/fcm/send/zz${i}`, keys: KEYS }, lang: i === 2 ? 'en' : 'fr', equipes: ['77'], tzo: 0 }, NOW);
  await db.collection('news').doc('n1').set({ id: 'n1', titre: 'Mbappé : le Real prépare une offre record pour prolonger', resume: '', lien: 'https://s.fr/1', source: 'Foot Mercato', sourceId: 'fm', lang: 'fr', date: '2026-10-17T10:30:00.000Z', image: null, video: false, teamIds: ['77'] });
  await db.collection('matches').doc('c1').set({ id: 'c1', jour: '2026-10-17', statut: 'prevu', coupDEnvoi: '2026-10-17T18:00:00.000Z', slug: 'real-barca', leagueSlug: 'liga', domicile: { teamId: 86, nom: 'Real Madrid CF', nomCourt: 'Real Madrid' }, exterieur: { teamId: 81, nom: 'FC Barcelona', nomCourt: 'Barça' }, prono: { visible: true, principal: { cle: 'res:1', libelle: 'Victoire du Real', confiance: 54, basseConfiance: false } } });
  const sent = [];
  const send = async (s, p) => { sent.push(p); };
  for (const [h, label] of [['12:00', 'choc'], ['15:10', 'actu']]) {
    const rep = { traites: 0, erreurs: [], infos: {} };
    await sendPush({ db, send, now: new Date(`2026-10-17T${h}:00Z`), providers: [] }, rep);
    console.log(label, JSON.stringify(rep.infos.actu || rep.infos));
  }
  const img = sent[0].image;
  const r = await handleImg({ path: img }, { db });
  console.log('image', img, r.status, r.type, r.body.length);
  const admin = createAdmin({ db, verifyToken: async () => ({ email: 'a@x.fr', email_verified: true }), bootstrap: ['a@x.fr'], tasks: {}, now: () => NOW, pushSender: async () => send });
  const call = (action, body) => admin.handle({ action, body, authorization: 'Bearer t' });
  const jpeg = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(300)]).toString('base64');
  const outs = [
    await call('push-annonce', { titre: 'Annonce', corps: 'Un texte', confirmer: true, id: 'idunique1', image: { mode: 'fichier', data: jpeg } }),
    await call('push-annonce', { titre: 'Annonce', corps: 'Un texte', essai: true, endpoint: 'https://fcm.googleapis.com/fcm/send/zz1', image: { mode: 'carte', titre: 'Annonce' } }),
    await call('push-save', { actif: true, maxJour: 4, seuil: 7, vedettes: 'Kenan Yildiz' }), await call('push', {}),
  ];
  console.log(outs.map((o) => o.status).join(' '), (await db.collection('push_log').get()).size, 'journaux', (await db.collection('push_cards').get()).size, 'cartes');
  const ep = 'https://fcm.googleapis.com/fcm/send/zz1';
  const box = await inbox.list(db, ep, 0, NOW);
  console.log('boîte', box.total, 'notifications,', box.nonLus, 'non lues,', (await inbox.count(db, ep)).nonLus, 'au compteur');
  await inbox.markRead(db, ep, box.items[0].id, false); await inbox.markRead(db, ep, null, true);
  await mail.subscribe(db, { email: 'Fan@Exemple.com', consent: true, lang: 'fr', source: 'coupon' }, NOW);
  const m = (await db.collection('email_subs').get()).docs[0].data();
  await mail.unsubscribe(db, m.id, m.jeton, NOW);
  console.log('e-mail', (await db.collection('email_subs').doc(m.id).get()).data().statut, (await call('emails', {})).json.total);
  process.exit(outs.every((o) => o.status === 200) ? 0 : 1);
})().catch((e) => { console.error('ÉCHEC', e.message); process.exit(1); });
