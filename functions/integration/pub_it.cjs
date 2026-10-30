// Parcours des diffuseurs contre l'émulateur Firestore : profil, règles, sites et applications, preuve de propriété, catégories, audience mesurée, décisions.
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
process.env.GCLOUD_PROJECT = 'afrolooki-it';
const F = 'D:/bienvenu/Projets/otherProjets/afrolook/V2/afrolookofficiel_v2/functions/';
const pubs = require(F + 'lib/ads/adsPublishers.js');
const db = require(F + 'lib/shared/firebase.js').db;
const { PUBLISHER_RULES_VERSION: RV } = require(F + 'lib/ads/adsRules.js');
const { randomBytes } = require('crypto');
let pass = 0, fail = 0;
const ok = (c, m, e) => { if (c) { pass++; console.log('  ✓', m); } else { fail++; console.log('  ✗', m, e !== undefined ? JSON.stringify(e) : ''); } };
const google = (uid, email, name) => ({ uid, token: { firebase: { sign_in_provider: 'google.com' }, email, name, picture: '' } });
const call = (fn, auth, data) => fn.run({ auth, data, rawRequest: {} });
const fails = async (p) => { try { await p; return null; } catch (e) { return e.message || String(e); } };

(async () => {
  const kofi = google('u_kofi', 'kofi@example.com', 'Kofi');
  const autre = google('u_autre', 'autre@example.com', 'Autre');
  const admin = google('u_admin', 'jorbienvenu@gmail.com', 'Admin');
  await db.collection('Users').doc('u_admin').set({ role: 'ADM', email: 'jorbienvenu@gmail.com' });
  await db.collection('Users').doc('u_kofi').set({ role: 'USER' });

  const profile = { type: 'company', name: 'Kofi Média', country: 'TG', city: 'Lomé', phone: '+22890123456', about: 'Un éditeur de sites d\'actualités pour l\'Afrique de l\'Ouest.', acceptTerms: true, rulesVersion: RV };
  const site = { kind: 'site', name: 'Afrolook Média', url: 'https://afrolookmedia.com', category: 'actualites', countries: ['TG', 'BJ'], languages: ['fr'], audienceMonthly: 80000, sessionsMonthly: 200000, description: 'Site vitrine et média de la plateforme Afrolook pour les créateurs africains.' };

  console.log('— Sans profil');
  let m = await fails(call(pubs.adsPubAddProperty, kofi, site)); ok(/profil_manquant/.test(m || ''), 'ajout refusé sans profil', m);
  m = await fails(call(pubs.adsPubMe, { uid: 'x', token: { firebase: { sign_in_provider: 'password' } } }, {})); ok(/Google/.test(m || ''), 'connexion Google obligatoire', m);

  console.log('— Profil et règles');
  m = await fails(call(pubs.adsPubSaveProfile, kofi, { ...profile, acceptTerms: false })); ok(/conditions/.test(m || ''), 'conditions obligatoires', m);
  m = await fails(call(pubs.adsPubSaveProfile, kofi, { ...profile, rulesVersion: '2020-01-01' })); ok(/regles_a_accepter/.test(m || ''), 'la version courante des règles doit être acceptée', m);
  let r = await call(pubs.adsPubSaveProfile, kofi, profile); ok(r.ok && r.status === 'pending', 'profil créé, en attente de validation', r);
  let me = await call(pubs.adsPubMe, kofi, {});
  ok(me.rules.accepted === true && me.rules.version === RV && me.rules.text.length >= 6 && me.rules.acceptedAt > 0, 'le diffuseur voit les règles complètes et la version acceptée', [me.rules.version, me.rules.text.length]);
  ok(me.profile.status === 'pending' && me.audience.total === 50000, 'profil en attente, audience du réseau 50 000');

  console.log('— Sites et applications (en ligne obligatoirement)');
  m = await fails(call(pubs.adsPubAddProperty, kofi, { ...site, url: 'http://afrolookmedia.com' })); ok(/https/.test(m || ''), 'site en http refusé', m);
  m = await fails(call(pubs.adsPubAddProperty, kofi, { ...site, url: 'https://ce-site-nexiste-pas-du-tout-zz9.com' })); ok(/hors_ligne/.test(m || ''), 'site hors ligne refusé', m);
  m = await fails(call(pubs.adsPubAddProperty, kofi, { ...site, kind: 'app', androidUrl: '', iosUrl: '' })); ok(/lien/.test(m || ''), 'application sans lien de magasin refusée', m);
  r = await call(pubs.adsPubAddProperty, kofi, { ...site, acceptedCategories: ['commerce', 'finance', 'sensuel', 'nimporte'] });
  ok(r.ok && /^ap_[a-z0-9]{10}$/.test(r.id) && /^afl-/.test(r.verifyToken) && r.status === 'pending', 'site en ligne accepté : identifiant publicitaire et code de vérification', r);
  const id = r.id;
  const prop = (await db.collection('AdProperties').doc(id).get()).data();
  ok(JSON.stringify(prop.acceptedCategories) === JSON.stringify(['commerce', 'finance', 'sensuel']), 'catégories d\'annonces choisies par le diffuseur (valeurs inconnues ignorées)', prop.acceptedCategories);
  r = await call(pubs.adsPubUpdateProperty, kofi, { id, acceptedCategories: ['commerce', 'sport'] });
  ok((await db.collection('AdProperties').doc(id).get()).data().acceptedCategories.join() === 'commerce,sport', 'le diffuseur peut changer ses catégories acceptées');
  m = await fails(call(pubs.adsPubAddProperty, autre, site)); ok(/profil_manquant/.test(m || ''), 'un compte sans profil ne peut pas déclarer');
  await call(pubs.adsPubSaveProfile, autre, { ...profile, name: 'Autre Média' });
  await db.collection('AdPublisherProfiles').doc('u_autre').update({ rulesVersion: '2020-01-01' });
  m = await fails(call(pubs.adsPubAddProperty, autre, { ...site, url: 'https://exemple-autre-site.com' })); ok(/regles_a_accepter/.test(m || ''), 'règles changées : ajout refusé tant qu\'elles ne sont pas acceptées de nouveau', m);
  r = await call(pubs.adsPubAcceptRules, autre, { version: RV }); ok(r.ok, 'nouvelle acceptation des règles');
  m = await fails(call(pubs.adsPubAcceptRules, autre, { version: '2020-01-01' })); ok(/version_obsolete/.test(m || ''), 'une ancienne version ne peut pas être acceptée');
  m = await fails(call(pubs.adsPubAddProperty, autre, site)); ok(/deja_enregistre/.test(m || ''), 'même site déclaré par deux diffuseurs : refusé', m);
  const v = await call(pubs.adsPubVerifyProperty, kofi, { id }); ok(v.ok === false && v.verified === false, 'preuve de propriété : le code n\'est pas sur le site, non vérifié', v);

  console.log('— Administration');
  m = await fails(call(pubs.adsPubAdminList, kofi, {})); ok(/administrateurs/.test(m || ''), 'liste réservée aux administrateurs', m);
  let l = await call(pubs.adsPubAdminList, admin, { status: 'pending' }); ok(l.profiles.length === 2 && l.properties.length === 1, 'demandes en attente visibles par l\'administrateur', [l.profiles.length, l.properties.length]);
  ok(Array.isArray(l.properties[0].acceptedCategories) && l.properties[0].acceptedCategories.length === 2, 'l\'administrateur voit les catégories acceptées');
  m = await fails(call(pubs.adsPubAdminReview, admin, { target: 'property', id, decision: 'approve' })); ok(/profil_non_valide/.test(m || ''), 'site non validable tant que le profil ne l\'est pas', m);
  m = await fails(call(pubs.adsPubAdminReview, admin, { target: 'profile', id: 'u_kofi', decision: 'refuse' })); ok(/motif/.test(m || ''), 'un refus exige un motif', m);
  r = await call(pubs.adsPubAdminReview, admin, { target: 'profile', id: 'u_kofi', decision: 'approve' }); ok(r.status === 'active', 'profil validé');
  r = await call(pubs.adsPubAdminReview, admin, { target: 'profile', id: 'u_autre', decision: 'refuse', reason: 'Informations insuffisantes' }); ok(r.status === 'refused', 'autre profil refusé avec motif');
  m = await fails(call(pubs.adsPubAdminReview, admin, { target: 'property', id, decision: 'approve', audienceCounted: 60000 })); ok(/verification_requise/.test(m || ''), 'site non validable sans preuve de propriété', m);
  await db.collection('AdProperties').doc(id).update({ verified: true, verifyFails: 0 });
  await db.collection('AdPublisherProfiles').doc('u_kofi').update({ rulesVersion: '2020-01-01' });
  m = await fails(call(pubs.adsPubAdminReview, admin, { target: 'property', id, decision: 'approve', audienceCounted: 60000 })); ok(/regles_a_accepter/.test(m || ''), 'site non validable si le diffuseur n\'a pas accepté la version courante des règles', m);
  await call(pubs.adsPubAcceptRules, kofi, { version: RV });
  r = await call(pubs.adsPubAdminReview, admin, { target: 'property', id, decision: 'approve', audienceCounted: 60000 }); ok(r.status === 'active', 'site validé (preuve de propriété et règles acceptées)');
  const p = (await db.collection('AdProperties').doc(id).get()).data();
  ok(p.audienceCounted === 60000 && p.audienceDeclared === 80000 && p.formats.length >= 5 && p.origins.includes('https://afrolookmedia.com') && p.payable === true, 'audience retenue 60 000 sur 80 000 déclarés, formats, origines, payable', [p.audienceCounted, p.payable]);
  await call(pubs.adsPubAdminReview, admin, { target: 'property', id, decision: 'approve', audienceCounted: 999999 });
  ok((await db.collection('AdProperties').doc(id).get()).data().audienceCounted === 80000, 'l\'audience retenue ne dépasse jamais l\'audience déclarée');
  await call(pubs.adsPubAdminReview, admin, { target: 'property', id, decision: 'approve', audienceCounted: 60000 });

  console.log('— Audience du réseau');
  const express = require(F + 'node_modules/express'); const app = express(); app.all('/a', pubs.adsAudience); const srv = await new Promise((rr) => { const s = app.listen(0, () => rr(s)); });
  const j = await (await fetch(`http://127.0.0.1:${srv.address().port}/a`)).json(); srv.close();
  ok(j.base === 50000 && j.partners === 60000 && j.total === 110000 && j.sites === 1, '50 000 + 60 000 retenus = 110 000', j);

  console.log('— Audience mesurée sur 60 jours, comparée à la déclarée');
  const eng = require(F + 'lib/ads/adsEngine.js'); const hl = require(F + 'lib/ads/adsHll.js'); const meas = require(F + 'lib/ads/adsMeasure.js');
  const dayOf = (n) => meas.dayStr(Date.now() - n * 86400000);
  const stay = Array.from({ length: 200 }, () => randomBytes(12).toString('hex'));
  for (let k = 2; k <= 10; k++) {
    const regs = hl.hllNew(); [...stay, ...Array.from({ length: 200 }, () => randomBytes(12).toString('hex'))].forEach((x) => hl.hllAdd(regs, x));
    await db.collection('AdsHll').doc(id + '_' + dayOf(k)).set({ pub: id, day: dayOf(k), regs: hl.hllToB64(regs), n: hl.hllCount(regs), geo: { TG: 250, BJ: 90, IN: 60 } });
    await db.collection('AdsPubDaily').doc(id + '_' + dayOf(k)).set({ pub: id, day: dayOf(k), valid: 500, invalid: 20, clicks: 10, foreign: k === 3 ? 7 : 0 });
  }
  const yb = db.batch(); for (let i = 0; i < 250; i++) yb.set(db.collection('AdsCaps').doc(randomBytes(12).toString('hex') + '_' + dayOf(1)), { pub: id, day: dayOf(1), srv: 1, cc: i % 5 === 0 ? 'IN' : 'TG' }); await yb.commit();
  if (eng.adsUniques.run) await eng.adsUniques.run({}); else await eng.adsUniques({});
  const hyd = (await db.collection('AdsHll').doc(id + '_' + dayOf(1)).get()).data(); ok(hyd && Math.abs(hyd.n - 250) <= 12 && hyd.geo.TG === 200 && hyd.geo.IN === 50, 'résumé de la veille : ≈ 250 visiteurs différents, 200 du Togo et 50 d\'Inde', hyd && [hyd.n, hyd.geo]);
  m = await fails(call(pubs.adsPubStats, google('u_intrus', 'x@x.com', 'X'), { id })); ok(/propriétaire/.test(m || ''), 'seuls le propriétaire et l\'administration voient les mesures', m);
  const stt = await call(pubs.adsPubStats, kofi, { id });
  ok(stt.series.length === 60 && stt.report.declared === 80000 && stt.report.daysWithData === 10, 'série de 60 jours, audience déclarée 80 000, 10 jours de mesure', [stt.series.length, stt.report.daysWithData]);
  ok(stt.report.u60 > 1800 && stt.report.u60 < 2600, 'visiteurs différents sur 60 jours : les 200 fidèles ne sont comptés qu\'une fois', stt.report.u60);
  ok(stt.report.status === 'far_below' && stt.report.ratio < 0.3, 'audience mesurée très en dessous de la déclarée : signalé', [stt.report.status, stt.report.ratio]);
  ok(stt.totals.impressions60 === 4500 && stt.totals.invalid60 === 180 && stt.totals.foreign60 === 7, 'affichages valides, trafic invalide et appels d\'un autre domaine', stt.totals);
  ok(stt.geo[0].cc === 'TG' && stt.declaredGeo && stt.declaredGeo.share > 0.8, 'd\'où viennent les visiteurs : majorité du Togo, 80 % et plus dans les pays annoncés', [stt.geo[0], stt.declaredGeo]);
  const adm = await call(pubs.adsPubAdminList, admin, { status: 'active' }); const mp = adm.properties.find((x) => x.id === id);
  ok(mp && mp.measured && mp.measured.status === 'far_below' && mp.payable === true && mp.measured.geoFlag === false, 'la liste d\'administration porte le résumé mesuré et l\'état payable', mp && mp.measured);

  console.log('— Suspension');
  r = await call(pubs.adsPubAdminReview, admin, { target: 'profile', id: 'u_kofi', decision: 'suspend', reason: 'Trafic suspect confirmé' });
  ok((await db.collection('AdProperties').doc(id).get()).data().status === 'suspended', 'profil suspendu : ses sites sont suspendus aussi');
  m = await fails(call(pubs.adsPubAddProperty, kofi, { ...site, url: 'https://exemple-autre.com' })); ok(/profil_non_valide/.test(m || ''), 'un profil suspendu ne peut plus rien ajouter', m);
  console.log('— Administration : tous les diffuseurs');
  const la = await call(pubs.adsPubAdminList, admin, { status: 'all' }); ok(la.profiles.length === 2 && la.properties.length === 1, 'tous les profils et tous les sites, quel que soit le statut', [la.profiles.length, la.properties.length]);
  console.log('— Historique');
  const aud2 = (await db.collection('AdsAudit').get()).size; ok(aud2 >= 7, 'toutes les décisions et acceptations de règles sont journalisées', aud2);

  console.log(`\n${pass} réussis, ${fail} échoués`);
  process.exit(fail ? 1 : 0);
})().catch((e) => { console.error('ERREUR', e); process.exit(2); });
