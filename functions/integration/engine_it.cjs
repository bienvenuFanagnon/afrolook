// Test d'intégration du moteur Afrolook Ads contre l'émulateur Firestore (vraies requêtes HTTP sur un serveur Express local).
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
process.env.GCLOUD_PROJECT = 'afrolooki-it';
const F = 'D:/bienvenu/Projets/otherProjets/afrolook/V2/afrolookofficiel_v2/functions/';
const express = require(F + 'node_modules/express');
const admin = require(F + 'node_modules/firebase-admin');
const eng = require(F + 'lib/ads/adsEngine.js');
const pubs = require(F + 'lib/ads/adsPublishers.js');
const db = require(F + 'lib/shared/firebase.js').db;

const UA = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Mobile Safari/537.36';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let pass = 0, fail = 0;
const ok = (c, m, extra) => { if (c) { pass++; console.log('  ✓', m); } else { fail++; console.log('  ✗', m, extra !== undefined ? JSON.stringify(extra) : ''); } };

(async () => {
  const app = express();
  app.use(express.json()); app.use(express.text({ type: '*/*' }));
  app.all('/adsServe', eng.adsServe); app.all('/adsEvent', eng.adsEvent); app.all('/adsGo', eng.adsGo); app.all('/adsAudience', pubs.adsAudience);
  const server = await new Promise((r) => { const s = app.listen(0, () => r(s)); });
  const base = `http://127.0.0.1:${server.address().port}`;
  const get = (p, h = {}) => fetch(base + p, { headers: { 'user-agent': UA, ...h }, redirect: 'manual' });
  const post = (p, body, h = {}) => fetch(base + p, { method: 'POST', body: JSON.stringify(body), headers: { 'content-type': 'text/plain', 'user-agent': UA, ...h } });

  // ── données de départ : une annonce active (image), une annonce « réseau » (payante), un site diffuseur externe ──
  const micros = Date.now() * 1000, future = micros + 14 * 86400e6;
  await db.collection('Posts').doc('P1').set({ dataType: 'IMAGE', images: ['https://firebasestorage.googleapis.com/v0/b/afrolooki.appspot.com/o/ad_images%2Fa.jpg?alt=media&token=aaaaaaaaaa'], description: 'Boutique Test\nLivraison à Lomé', available_countries: ['ALL'] });
  await db.collection('Advertisements').doc('AD1AD1AD1AD1').set({ status: 'active', endDate: future, postId: 'P1', actionType: 'url', actionUrl: 'https://exemple.com/promo', actionButtonText: 'Visiter', adTitle: 'Boutique Test', description: 'Livraison', views: 0, clicks: 0 });
  await db.collection('Posts').doc('P2').set({ dataType: 'IMAGE', images: ['https://firebasestorage.googleapis.com/v0/b/afrolooki.appspot.com/o/ad_images%2Fb.jpg?alt=media&token=bbbbbbbbbb'], description: 'Annonce Réseau\nPayante', available_countries: ['ALL'] });
  await db.collection('Advertisements').doc('AD2AD2AD2AD2').set({ status: 'active', network: true, endDate: future, postId: 'P2', actionType: 'url', actionUrl: 'https://reseau.example/x', actionButtonText: 'Voir', adTitle: 'Annonce Réseau', adCategory: 'commerce', views: 0, clicks: 0 });
  await db.collection('AdProperties').doc('ap_aaaaaaaaaa').set({ status: 'active', kind: 'site', name: 'Kofi Sport', origins: ['https://kofisport.com', 'https://www.kofisport.com'], formats: [], audienceCounted: 120000, audienceDeclared: 120000 });
  await db.collection('AdProperties').doc('ap_bbbbbbbbbb').set({ status: 'pending', kind: 'site', name: 'En attente', origins: ['https://x.com'], audienceCounted: 0 });

  console.log('— Servir une annonce');
  const vid = 'visiteur-test-0001';
  let r = await get(`/adsServe?pub=slashatlas&fmt=native&slot=main&vid=${vid}`);
  let j = await r.json();
  ok(r.status === 200 && j.ok && j.ad && j.ad.token && j.ad.click.includes('/adsGo?t='), 'annonce servie avec jeton et lien de clic', j);
  ok(j.ad && /^(AD1AD1AD1AD1|AD2AD2AD2AD2)$/.test(j.ad.id), 'nos plateformes reçoivent toutes les annonces');
  const tok = j.ad.token, adId = j.ad.id, clickUrl = j.ad.click;

  console.log('— Contrôles de sécurité sur la demande');
  r = await get(`/adsServe?pub=slashatlas&fmt=native&vid=court`); ok(r.status === 400, 'identifiant visiteur trop court refusé');
  r = await get(`/adsServe?pub=inconnu&fmt=native&vid=${vid}`); ok(r.status === 403, 'diffuseur inconnu refusé');
  r = await get(`/adsServe?pub=slashatlas&fmt=banane&vid=${vid}`); ok(r.status === 400, 'format inconnu refusé');
  r = await get(`/adsServe?pub=slashatlas&fmt=native&vid=${vid}`, { 'user-agent': 'curl/8.4.0' }); j = await r.json(); ok(j.ok && j.ad === null, 'robot : aucune annonce');
  r = await get(`/adsServe?pub=ap_bbbbbbbbbb&fmt=native&vid=${vid}`); ok(r.status === 403, 'site en attente de validation : refusé');
  r = await get(`/adsServe?pub=ap_aaaaaaaaaa&fmt=native&vid=${vid}`, { origin: 'https://pirate.com' }); ok(r.status === 403, 'site validé appelé depuis un autre domaine : refusé');
  r = await get(`/adsServe?pub=ap_aaaaaaaaaa&fmt=native&vid=${vid}`, { origin: 'https://kofisport.com' }); j = await r.json();
  ok(j.ok && j.ad && j.ad.id === 'AD2AD2AD2AD2', 'diffuseur externe : seulement les annonces payantes du Réseau', j.ad && j.ad.id);
  r = await get(`/adsServe?pub=slashatlas&fmt=rewarded&vid=${vid}`); j = await r.json(); ok(j.ok && j.ad === null, 'récompensée : pas d\'annonce vidéo disponible');

  console.log('— Vue');
  r = await post('/adsEvent', { t: tok, e: 'view', ms: 200, vid }); j = await r.json(); ok(j.counted === false && j.reason === 'not_visible', 'pas assez visible : invalide', j);
  r = await post('/adsEvent', { t: tok, e: 'view', ms: 99999, vid }); j = await r.json(); ok(j.counted === false && j.reason === 'too_fast', 'visible plus longtemps que le jeton n\'existe : fraude', j);
  r = await post('/adsEvent', { t: tok, e: 'view', ms: 1200, vid }); j = await r.json(); ok(j.counted === true, 'vue valide comptée', j);
  r = await post('/adsEvent', { t: tok, e: 'view', ms: 1200, vid }); j = await r.json(); ok(j.counted === false && j.reason === 'replay', 'rejeu du même jeton refusé', j);
  r = await post('/adsEvent', { t: tok.slice(0, -3) + 'abc', e: 'view', ms: 1200, vid }); ok(r.status === 400, 'jeton falsifié refusé');
  r = await post('/adsEvent', { t: tok, e: 'view', ms: 1200, vid }, { 'user-agent': 'python-requests/2.31' }); j = await r.json(); ok(j.counted === false && j.reason === 'bot', 'robot refusé');

  console.log('— Intervalle minimum et plafond');
  r = await get(`/adsServe?pub=slashatlas&fmt=native&slot=main&vid=${vid}`); j = await r.json();
  const tok2 = j.ad && j.ad.token;
  r = await post('/adsEvent', { t: tok2, e: 'view', ms: 1200, vid }); j = await r.json(); ok(j.counted === false && j.reason === 'interval', 'deux affichages trop rapprochés sur le même emplacement : invalide', j);
  r = await get(`/adsServe?pub=slashatlas&fmt=native&slot=autre&vid=${vid}`); j = await r.json();
  r = await post('/adsEvent', { t: j.ad.token, e: 'view', ms: 1200, vid }); j = await r.json(); ok(j.counted === true, 'un autre emplacement n\'est pas limité', j);

  console.log('— Clic par redirection');
  r = await get(clickUrl.replace(/^https?:\/\/[^/]+\/adsGo/, '/adsGo')); // clic immédiat
  ok(r.status === 302 && /exemple\.com|reseau\.example/.test(r.headers.get('location') || ''), 'redirige vers le lien validé de l\'annonce', r.headers.get('location'));
  await sleep(1300);
  r = await get(clickUrl.replace(/^https?:\/\/[^/]+\/adsGo/, '/adsGo')); ok(r.status === 302, 'clic après 1 s : redirection');
  r = await get(clickUrl.replace(/^https?:\/\/[^/]+\/adsGo/, '/adsGo')); ok(r.status === 302, 'second clic : redirection quand même');
  r = await get('/adsGo?t=faux.jeton'); ok(r.status === 302 && r.headers.get('location') === 'https://afrolookmedia.com/ads/', 'jeton faux : retour vers la page Afrolook Ads');
  r = await get(clickUrl.replace(/^https?:\/\/[^/]+\/adsGo/, '/adsGo'), { 'user-agent': 'curl/8' }); ok(r.status === 302, 'robot : redirigé sans être compté');

  console.log('— Cumul des compteurs');
  const shardsBefore = (await db.collection('AdsShards').where('dirty', '==', true).get()).size;
  ok(shardsBefore >= 1, 'compteurs répartis écrits', shardsBefore);
  await eng.adsRollup.run ? await eng.adsRollup.run({}) : await eng.adsRollup({});
  const ad = (await db.collection('Advertisements').doc(adId).get()).data();
  const both = (await db.collection('Advertisements').get()).docs.reduce((n, d) => n + (d.data().views || 0), 0);
  ok(both === 2 && ad.views === 1, 'vues cumulées : 2 valides au total, sur deux annonces différentes (jamais la même annonce deux fois à un appareil)', [both, ad.views]);
  ok(ad.clicks === 1, 'un seul clic compté (les doublons, le robot et le jeton faux sont exclus)', ad.clicks);
  const day = new Date().toISOString().slice(0, 10);
  ok(ad.dailyStats && ad.dailyStats[day] && ad.dailyStats[day].views === 1, 'statistiques du jour', ad.dailyStats);
  ok(ad.placements && ad.placements.slashatlas && ad.placements.slashatlas.views === 1, 'vues par plateforme', ad.placements);
  const daily = (await db.collection('AdsDaily').doc(`${day}_${adId}_slashatlas`).get()).data();
  ok(daily && daily.views === 1 && daily.clicks === 1, 'registre quotidien de l\'annonce', daily);
  const ph = (await db.collection('AdsPubDaily').doc(`slashatlas_${day}`).get()).data();
  ok(ph && ph.valid === 2 && ph.invalid >= 3 && ph.inv.interval >= 1 && ph.inv.replay === undefined && ph.inv.not_visible >= 1, 'trafic invalide par motif', ph);
  const dirty = (await db.collection('AdsShards').where('dirty', '==', true).get()).size;
  ok(dirty === 0, 'compteurs répartis remis à zéro', dirty);
  await eng.adsRollup.run ? await eng.adsRollup.run({}) : await eng.adsRollup({});
  const ad2 = (await db.collection('Advertisements').doc(adId).get()).data();
  ok(ad2.views === 1 && ad2.clicks === 1, 'un second cumul ne double rien', [ad2.views, ad2.clicks]);

  console.log('— Audience du réseau');
  r = await get('/adsAudience'); j = await r.json(); ok(j.base === 50000 && j.partners === 120000 && j.total === 170000, '50 000 + audience retenue des diffuseurs validés (le site en attente est exclu)', j);

  console.log('— Ciblage défini par l\'annonceur (pays, 40 % hors cible, langue, appareil)');
  const NG_IP = '105.112.0.1', US_IP = '8.8.8.8';
  const DESK = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Safari/537.36';
  const fresh = () => { delete require.cache[require.resolve(F + 'lib/ads/adsEngine.js')]; return require(F + 'lib/ads/adsEngine.js'); };
  let routeN = 0; const route = (e) => { const p = '/adsServeX' + (++routeN); app.all(p, e.adsServe); return p; };
  for (const id of ['AD1AD1AD1AD1', 'AD2AD2AD2AD2']) await db.collection('Advertisements').doc(id).update({ status: 'ended' }); // on isole l'annonce testée
  await db.collection('Posts').doc('P3').set({ dataType: 'IMAGE', images: ['https://firebasestorage.googleapis.com/v0/b/afrolooki.appspot.com/o/ad_images%2Fc.jpg?alt=media&token=cccccccccc'], description: 'Annonce Nigeria\nVisible au Nigeria', available_countries: ['NG'] });
  await db.collection('Advertisements').doc('AD3AD3AD3AD3').set({ status: 'active', endDate: future, postId: 'P3', actionType: 'url', actionUrl: 'https://ng.example/x', actionButtonText: 'Voir', adTitle: 'Annonce Nigeria', adCategory: 'commerce', views: 0, clicks: 0 });
  const vidN = (i) => 'geo-visiteur-' + String(i).padStart(4, '0');
  const gget = (path, ip, i, extra = {}) => get(`${path}?pub=pronoflash&fmt=native&slot=s${i}&vid=${vidN(i)}`, { 'x-forwarded-for': ip, ...extra });
  let ep = route(fresh());
  // 1) annonce neuve : un visiteur d'un autre pays ne la reçoit jamais
  r = await gget(ep, US_IP, 1); j = await r.json(); ok(j.ok && j.ad === null, 'annonce visant le Nigeria : un visiteur américain ne la reçoit pas (annonce neuve)', j.ad && j.ad.id);
  // 2) visiteur nigérian : servi, avec pays et conformité dans le jeton signé
  r = await gget(ep, NG_IP, 2); j = await r.json(); ok(j.ad && j.ad.id === 'AD3AD3AD3AD3', 'un visiteur nigérian reçoit l\'annonce', j.ad && j.ad.id);
  const payload = JSON.parse(Buffer.from(j.ad.token.split('.')[0], 'base64url').toString()); ok(payload.g === 'i' && payload.c === 'NG', 'le jeton signé porte le pays du visiteur (NG) et « dans la cible »', payload);
  const caps = (await db.collection('AdsCaps').get()).docs.map((d) => d.data()).filter((d) => d.cc); ok(caps.some((c) => c.cc === 'NG' && c.pub === 'pronoflash'), 'le pays du visiteur est noté pour contrôler la cohérence du diffuseur', caps.map((c) => c.cc));
  // 3) 25 vues valides de visiteurs nigérians
  for (let i = 10; i < 35; i++) { const s = await (await gget(ep, NG_IP, i)).json(); await post('/adsEvent', { t: s.ad.token, e: 'view', ms: 1100, vid: vidN(i) }); }
  if (eng.adsRollup.run) await eng.adsRollup.run({}); else await eng.adsRollup({});
  const dly = (await db.collection('AdsDaily').where('adId', '==', 'AD3AD3AD3AD3').get()).docs.map((d) => d.data())[0]; ok(dly && dly.geoIn === 25 && !dly.geoOut, 'cumul : 25 vues dans la cible', dly && [dly.geoIn, dly.geoOut]);
  const pd = (await db.collection('AdsPubDaily').doc('pronoflash_' + new Date().toISOString().slice(0, 10)).get()).data(); ok(pd && pd.cc && pd.cc.NG >= 25, 'répartition des vues par pays enregistrée pour le diffuseur', pd && pd.cc);
  // 4) nouvelle instance du moteur (cache de ciblage vide) : hors cible accepté tant que la part reste sous 35 %, jamais au-delà
  ep = route(fresh());
  let served = 0, denied = 0;
  for (let i = 100; i < 140; i++) { const jj = await (await gget(ep, US_IP, i)).json(); if (jj.ad && jj.ad.id === 'AD3AD3AD3AD3') served++; else denied++; }
  const share = served / (25 + served);
  ok(served >= 8 && served <= 14 && denied >= 20, 'hors cible : quelques vues acceptées (marge) puis refus', { served, denied });
  ok(share <= 0.4 && share > 0.2, 'la part de vues hors cible reste sous 40 % (' + Math.round(share * 100) + ' %)', share);
  const jp = await (await gget(ep, '10.1.2.3', 9999)).json(); ok(jp.ad === null, 'pays introuvable (adresse privée) : traité comme hors cible');
  // 5) annonce sans contrainte de pays : servie partout
  await db.collection('Advertisements').doc('AD1AD1AD1AD1').update({ status: 'active' }); await db.collection('Advertisements').doc('AD3AD3AD3AD3').update({ status: 'ended' });
  ep = route(fresh());
  const jw = await (await gget(ep, US_IP, 8888)).json(); ok(jw.ad && jw.ad.id === 'AD1AD1AD1AD1', 'annonce « monde entier » : servie à un visiteur américain', jw.ad && jw.ad.id);
  // 6) langue et appareil
  await db.collection('Advertisements').doc('AD1AD1AD1AD1').update({ targetLanguages: ['en'], targetDevices: ['desktop'] });
  ep = route(fresh());
  const t1 = await (await gget(ep, US_IP, 7001, { 'user-agent': DESK }).then((x) => x)).json(); ok(t1.ad && t1.ad.id === 'AD1AD1AD1AD1', 'annonce en anglais pour ordinateur : servie sur ordinateur (langue lue dans l\'en-tête)', t1.ad && t1.ad.id);
  const t2 = await (await get(`${ep}?pub=pronoflash&fmt=native&slot=l1&vid=${vidN(7002)}&lang=fr`, { 'user-agent': DESK })).json(); ok(t2.ad === null, 'annonce en anglais : refusée à un visiteur francophone');
  const t3 = await (await get(`${ep}?pub=pronoflash&fmt=native&slot=l2&vid=${vidN(7003)}&lang=en`)).json(); ok(t3.ad === null, 'annonce pour ordinateur : refusée sur téléphone');
  await db.collection('Advertisements').doc('AD1AD1AD1AD1').update({ targetLanguages: [], targetDevices: [] });

  console.log('— Catégories : le diffuseur n\'affiche que ce qu\'il accepte');
  for (const id of ['AD1AD1AD1AD1', 'AD2AD2AD2AD2', 'AD3AD3AD3AD3']) await db.collection('Advertisements').doc(id).update({ status: 'ended' });
  const mk = async (n, cat, network) => { await db.collection('Posts').doc('PC' + n).set({ dataType: 'IMAGE', images: ['https://firebasestorage.googleapis.com/v0/b/afrolooki.appspot.com/o/ad_images%2Fk' + n + '.jpg?alt=media&token=kkkkkkkkkk'], description: 'Annonce ' + cat + '\nTexte', available_countries: ['ALL'] }); await db.collection('Advertisements').doc('ADC' + n + 'ADC' + n + 'AA').set({ status: 'active', network, endDate: future, postId: 'PC' + n, actionType: 'url', actionUrl: 'https://c' + n + '.example/', actionButtonText: 'Voir', adTitle: 'Annonce ' + cat, adCategory: cat, views: 0, clicks: 0 }); };
  await mk(1, 'commerce', true); await mk(2, 'sensuel', true); await mk(3, 'finance', true); await mk(4, 'paris_jeux', true);
  const ids = async (path, pubId, base2, extra = {}) => { const out = new Set(); for (let i = 0; i < 24; i++) { const x = await (await get(`${path}?pub=${pubId}&fmt=native&slot=c${i}&vid=cat-visiteur-${base2}-${String(i).padStart(3, '0')}`, extra)).json(); if (x.ad) out.add(x.ad.category || x.ad.id); } return out; };
  const idsOf = async (path, pubId, base2, extra = {}) => { const out = new Set(); for (let i = 0; i < 24; i++) { const x = await (await get(`${path}?pub=${pubId}&fmt=native&slot=c${i}&vid=cat-visiteur-${base2}-${String(i).padStart(3, '0')}`, extra)).json(); if (x.ad) out.add(x.ad.id); } return out; };
  ep = route(fresh());
  let seen = await idsOf(ep, 'slashatlas', 'sa'); ok([...seen].every((x) => x === 'ADC1ADC1AA') && seen.size === 1, 'SlashAtlas : seulement la catégorie commerce (ni sensuel, ni finance, ni paris)', [...seen]);
  seen = await idsOf(ep, 'pronoflash', 'pf'); ok(seen.has('ADC1ADC1AA') && seen.has('ADC4ADC4AA') && !seen.has('ADC2ADC2AA') && !seen.has('ADC3ADC3AA'), 'PronoFlash : commerce et paris acceptés, pas le sensuel ni la finance', [...seen]);
  seen = await idsOf(ep, 'ap_aaaaaaaaaa', 'ex', { origin: 'https://kofisport.com' }); ok([...seen].every((x) => x === 'ADC1ADC1AA' || x === 'ADC1ADC1AA') && !seen.has('ADC2ADC2AA'), 'site externe sans choix particulier : catégories standard seulement', [...seen]);
  await db.collection('AdProperties').doc('ap_aaaaaaaaaa').update({ acceptedCategories: ['sensuel'] });
  ep = route(fresh());
  seen = await idsOf(ep, 'ap_aaaaaaaaaa', 'ey', { origin: 'https://kofisport.com' }); ok(seen.size === 1 && seen.has('ADC2ADC2AA'), 'le diffuseur accepte « sensuel » seulement : il ne reçoit que cela', [...seen]);
  await db.collection('AdProperties').doc('ap_aaaaaaaaaa').update({ acceptedCategories: ['commerce', 'finance'] });
  ep = route(fresh());
  seen = await idsOf(ep, 'ap_aaaaaaaaaa', 'ez', { origin: 'https://kofisport.com' }); ok(seen.has('ADC1ADC1AA') && seen.has('ADC3ADC3AA') && !seen.has('ADC2ADC2AA') && !seen.has('ADC4ADC4AA'), 'commerce et finance acceptés : pas de sensuel ni de paris', [...seen]);
  // anciennes annonces sans catégorie : nos plateformes seulement
  await db.collection('Advertisements').doc('ADC1ADC1AA').update({ adCategory: admin.firestore.FieldValue.delete(), network: true });
  ep = route(fresh());
  seen = await idsOf(ep, 'slashatlas', 'old'); ok(seen.has('ADC1ADC1AA'), 'ancienne annonce sans catégorie : diffusée chez nos plateformes');
  seen = await idsOf(ep, 'ap_aaaaaaaaaa', 'old2', { origin: 'https://kofisport.com' }); ok(!seen.has('ADC1ADC1AA'), 'ancienne annonce sans catégorie : jamais chez un diffuseur externe');
  // la galerie publique n'affiche jamais de catégorie sensible
  const web = require(F + 'lib/ads/adsWeb.js'); app.all('/pub', web.adsWebPublic);
  const gal = await (await fetch(`${base}/pub`)).json(); ok(gal.items.length >= 1 && !gal.items.some((x) => ['ADC2ADC2AA', 'ADC3ADC3AA', 'ADC4ADC4AA'].includes(x.id)), 'galerie publique du site : aucune annonce de catégorie sensible', gal.items.map((x) => x.id));
  ok(gal.items.every((x) => x.clicks === undefined), 'galerie publique : le nombre de clics n\'est jamais envoyé');

  console.log('— Nettoyage');
  await eng.adsCleanup.run ? await eng.adsCleanup.run({}) : await eng.adsCleanup({});
  ok(true, 'nettoyage exécuté sans erreur');

  server.close();
  console.log(`\n${pass} réussis, ${fail} échoués`);
  process.exit(fail ? 1 : 0);
})().catch((e) => { console.error('ERREUR', e); process.exit(2); });
