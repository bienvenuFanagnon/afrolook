// Profil annonceur : parcours complet contre l'émulateur Firestore.
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
process.env.GCLOUD_PROJECT = 'afrolooki-it';
const F = 'D:/bienvenu/Projets/otherProjets/afrolook/V2/afrolookofficiel_v2/functions/';
const adv = require(F + 'lib/ads/adsAdvertisers.js');
const web = require(F + 'lib/ads/adsWeb.js');
const db = require(F + 'lib/shared/firebase.js').db;
const express = require(F + 'node_modules/express');
let pass = 0, fail = 0;
const ok = (c, m, e) => { if (c) { pass++; console.log('  ✓', m); } else { fail++; console.log('  ✗', m, e !== undefined ? JSON.stringify(e) : ''); } };
const google = (uid, email, name) => ({ uid, token: { firebase: { sign_in_provider: 'google.com' }, email, name, picture: '' } });
const call = (fn, auth, data) => fn.run({ auth, data, rawRequest: {} });
const fails = async (p) => { try { await p; return null; } catch (e) { return e.message || String(e); } };
const logoOf = (uid, name) => `https://firebasestorage.googleapis.com/v0/b/afrolooki.appspot.com/o/ad_logos%2F${uid}%2F${name}.png?alt=media&token=abcdef12-3456-7890-abcd-ef1234567890`;
const imgOf = 'https://firebasestorage.googleapis.com/v0/b/afrolooki.appspot.com/o/ad_images%2Fimg1.jpg?alt=media&token=abcdef12-3456-7890-abcd-ef1234567890';

(async () => {
  const kofi = google('u_kofi', 'kofi@example.com', 'Kofi'), admin = google('u_admin', 'jorbienvenu@gmail.com', 'Admin');
  await db.collection('Users').doc('u_admin').set({ role: 'ADM', email: 'jorbienvenu@gmail.com' });
  const ad = { category: 'mode_beaute', kind: 'entreprise', title: 'Boutique Kofi : mode africaine', text: 'Vêtements modernes et accessoires, livraison à Lomé et Cotonou.', mediaType: 'image', images: [imgOf], action: 'visit', link: 'https://kofi.com', countries: ['ALL'] };
  const profile = { brandName: 'Boutique Kofi', sector: 'mode', country: 'TG', city: 'Lomé', website: 'https://kofi.com', whatsapp: '+22890123456', about: 'Mode africaine moderne.', logoUrl: logoOf('u_kofi', 'logo1'), partnerConsent: true };

  console.log('— Publier exige un profil avec logo');
  let m = await fails(call(web.adsWebCreate, kofi, ad)); ok(/profil_manquant/.test(m || ''), 'création d\'annonce refusée sans profil de marque', m);
  m = await fails(call(adv.adsAdvSaveProfile, kofi, { ...profile, logoUrl: logoOf('u_autre', 'x') })); ok(/logo non reconnu/.test(m || ''), 'logo d\'un autre compte refusé', m);
  m = await fails(call(adv.adsAdvSaveProfile, kofi, { ...profile, partnerConsent: false })); ok(/accord/.test(m || ''), 'accord d\'affichage obligatoire', m);

  console.log('— Profil et logo');
  let r = await call(adv.adsAdvSaveProfile, kofi, profile); ok(r.ok && r.logoStatus === 'pending', 'profil enregistré, logo en validation', r);
  let me = await call(adv.adsAdvMe, kofi, {}); ok(me.profile.brandName === 'Boutique Kofi' && me.profile.logoStatus === 'pending', 'profil relu');
  m = await fails(call(web.adsWebCreate, kofi, ad)); ok(/profil_en_validation/.test(m || ''), 'profil en validation : première annonce refusée tant qu\'il n\'est pas validé', m);

  console.log('— Partenaires (affichage public)');
  const app = express(); app.all('/p', adv.adsPartners); const srv = await new Promise((rr) => { const s = app.listen(0, () => rr(s)); });
  const port = srv.address().port;
  let j = await (await fetch(`http://127.0.0.1:${port}/p`)).json(); ok(j.items.length === 0, 'logo non validé : pas affiché', j);

  console.log('— Administration');
  m = await fails(call(adv.adsAdvAdminList, kofi, {})); ok(/administrateurs/.test(m || ''), 'réservé aux administrateurs');
  let l = await call(adv.adsAdvAdminList, admin, { status: 'pending' }); ok(l.items.length === 1 && l.items[0].brandName === 'Boutique Kofi', 'logo en attente visible par l\'administrateur');
  m = await fails(call(adv.adsAdvAdminReview, admin, { uid: 'u_kofi', decision: 'reject' })); ok(/motif/.test(m || ''), 'refus : motif obligatoire', m);
  await call(adv.adsAdvAdminReview, admin, { uid: 'u_kofi', decision: 'reject', reason: 'Logo flou, merci d\'en envoyer un plus net' });
  m = await fails(call(web.adsWebCreate, kofi, ad)); ok(/logo_refuse/.test(m || ''), 'logo refusé : publication bloquée jusqu\'à un nouveau logo', m);
  r = await call(adv.adsAdvSaveProfile, kofi, { ...profile, logoUrl: logoOf('u_kofi', 'logo2') }); ok(r.logoStatus === 'pending', 'nouveau logo : retour en validation');
  await call(adv.adsAdvAdminReview, admin, { uid: 'u_kofi', decision: 'approve' });
  me = await call(adv.adsAdvMe, kofi, {}); ok(me.profile.logoStatus === 'approved', 'logo validé');
  r = await call(web.adsWebCreate, kofi, ad); ok(!!r.id, 'profil validé : l\'annonce peut être publiée', r);
  const created = (await db.collection('Advertisements').doc(r.id).get()).data();
  ok(created.advertiserName === 'Boutique Kofi' && created.advertiserLogo === logoOf('u_kofi', 'logo2'), 'le nom de marque et le logo sont portés par l\'annonce', [created.advertiserName]);

  console.log('— Affiché comme partenaire seulement avec une annonce en ligne');
  j = await (await fetch(`http://127.0.0.1:${port}/p`)).json(); ok(j.items.length === 0, 'logo validé mais annonce pas encore en ligne : pas affiché', j);
  await db.collection('Advertisements').doc(created.id).update({ status: 'active', endDate: Date.now() * 1000 + 86400e6 });
  // le cache public dure 5 minutes : on relance le serveur de test pour relire
  srv.close();
  delete require.cache[require.resolve(F + 'lib/ads/adsAdvertisers.js')];
  const adv2 = require(F + 'lib/ads/adsAdvertisers.js'); const app2 = express(); app2.all('/p', adv2.adsPartners); const srv2 = await new Promise((rr) => { const s = app2.listen(0, () => rr(s)); });
  j = await (await fetch(`http://127.0.0.1:${srv2.address().port}/p`)).json();
  ok(j.items.length === 1 && j.items[0].name === 'Boutique Kofi' && j.items[0].logo.includes('logo2') && j.items[0].url === 'https://kofi.com/', 'logo validé + annonce en ligne : affiché comme partenaire', j);
  srv2.close();

  console.log('— Administration : tous les annonceurs');
  const all = await call(adv.adsAdvAdminList, admin, { status: 'all' });
  ok(all.items.length === 1 && all.items[0].brandName === 'Boutique Kofi' && all.items[0].stats.ads === 1 && all.items[0].stats.active === 1, 'liste de tous les annonceurs avec leurs chiffres (annonces, en ligne)', all.items.map((i) => i.stats));
  m = await fails(call(adv.adsAdvSaveProfile, kofi, { ...profile, logoUrl: logoOf('u_kofi', 'logo2'), whatsapp: '' })); ok(/WhatsApp/.test(m || ''), 'contact obligatoire', m);
  m = await fails(call(adv.adsAdvSaveProfile, kofi, { ...profile, logoUrl: logoOf('u_kofi', 'logo2'), about: '' })); ok(/activité/.test(m || ''), 'ce que fait la marque : obligatoire', m);
  r = await call(adv.adsAdvSaveProfile, kofi, { ...profile, logoUrl: logoOf('u_kofi', 'logo2'), city: '', sector: '' }); ok(r.ok, 'ville et secteur facultatifs');

  console.log(`\n${pass} réussis, ${fail} échoués`);
  process.exit(fail ? 1 : 0);
})().catch((e) => { console.error('ERREUR', e); process.exit(2); });
