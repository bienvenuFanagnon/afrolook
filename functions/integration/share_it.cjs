// Partage et gagne : parcours complet contre l'émulateur Firestore (campagne, validation, profil, lien suivi, clics, parrainage, fraude, retrait des gains).
process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
process.env.GCLOUD_PROJECT = 'afrolooki-it';
const F = 'D:/bienvenu/Projets/otherProjets/afrolook/V2/afrolookofficiel_v2/functions/';
const express = require(F + 'node_modules/express');
const share = require(F + 'lib/ads/adsShare.js');
const pubs = require(F + 'lib/ads/adsPublishers.js');
const db = require(F + 'lib/shared/firebase.js').db;
const UA = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120 Mobile Safari/537.36';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let pass = 0, fail = 0;
const ok = (c, m, e) => { if (c) { pass++; console.log('  ✓', m); } else { fail++; console.log('  ✗', m, e !== undefined ? JSON.stringify(e) : ''); } };
const google = (uid, email) => ({ uid, token: { firebase: { sign_in_provider: 'google.com' }, email, name: 'T', picture: '' } });
const user = (uid) => ({ uid, token: { firebase: { sign_in_provider: 'password' }, email: uid + '@example.com' } });
const call = (fn, auth, data, ip) => fn.run({ auth, data, rawRequest: { headers: ip ? { 'x-forwarded-for': ip } : {} } });
const fails = async (p) => { try { await p; return null; } catch (e) { return e.message || String(e); } };
const day = new Date().toISOString().slice(0, 10);
const img = 'https://firebasestorage.googleapis.com/v0/b/afrolooki.appspot.com/o/ad_images%2Fimg1.jpg?alt=media&token=abcdef12-3456-7890-abcd-ef1234567890';
const logo = 'https://firebasestorage.googleapis.com/v0/b/afrolooki.appspot.com/o/ad_logos%2Fu_adv%2Flogo.png?alt=media&token=abcdef12-3456-7890-abcd-ef1234567890';

(async () => {
  const OLD = Date.now() - 30 * 86400000;
  await db.collection('AppConfig').doc('offerwall').set({ requireVerifiedEmail: false, minAccountAgeDays: 0 });
  await db.collection('AppConfig').doc('share').set({ enabled: true });
  await db.collection('Users').doc('u_admin').set({ role: 'ADM', email: 'jorbienvenu@gmail.com', createdAt: OLD });
  await db.collection('Users').doc('u_spon').set({ code_parrainage: 'SPONS1', email: 'spon@example.com', giftCoinsBalance: 0, createdAt: OLD });
  await db.collection('Users').doc('u_sh').set({ code_parrain: 'SPONS1', email: 'sh@example.com', pseudo: 'Kofi', giftCoinsBalance: 0, createdAt: OLD });
  await db.collection('AdAdvertiserProfiles').doc('u_adv').set({ brandName: 'Boutique Kofi', logoUrl: logo, logoStatus: 'approved', email: 'adv@example.com' });
  const admin = google('u_admin', 'jorbienvenu@gmail.com'), adv = google('u_adv', 'adv@example.com'), sh = user('u_sh');
  const ad = { category: 'mode_beaute', title: 'Boutique Kofi : mode africaine', text: 'Vêtements modernes et accessoires, livraison à Lomé et Cotonou.', mediaType: 'image', images: [img], action: 'visit', link: 'https://kofi.example.com/offre', countries: ['ALL'], targetAudience: 5000 };

  console.log('— Annonceur : campagne');
  let m = await fails(call(share.adsShareCampaignCreate, adv, { ...ad, targetAudience: 100 })); ok(/audience/.test(m || ''), 'audience trop petite refusée', m);
  m = await fails(call(share.adsShareCampaignCreate, adv, { ...ad, targetAudience: undefined })); ok(/audience/.test(m || ''), 'audience à atteindre obligatoire', m);
  m = await fails(call(share.adsShareCampaignCreate, google('u_x', 'x@example.com'), ad)); ok(/profil_manquant/.test(m || ''), 'sans profil annonceur : refusé', m);
  const created = await call(share.adsShareCampaignCreate, adv, ad); ok(created.id && created.status === 'pending', 'campagne créée, en attente de validation', created);
  const cid = created.id;
  let cdoc = (await db.collection('ShareCampaigns').doc(cid).get()).data();
  ok(cdoc.cpcFcfa === 5.5 && cdoc.userFcfa === 5 && cdoc.funded === false && cdoc.priceFcfa === 2500 && cdoc.budgetFcfa === 1500 && cdoc.targetAudience === 5000 && cdoc.free === false, '5 000 personnes = 2 500 F à payer, 1 500 F (60 %) de gains possibles, 5 F par clic (5,5 F du plafond avec la part du parrain), pas encore financée', cdoc);
  ok((await db.collection('Advertisements').get()).size === 0, 'aucune annonce créée dans Advertisements : la mission reste dans notre application');
  m = await fails(call(pubs.adsPubAdminReview, adv, { target: 'campaign', id: cid, decision: 'approve' })); ok(m !== null, 'un annonceur ne peut pas valider sa campagne');
  await call(pubs.adsPubAdminReview, admin, { target: 'campaign', id: cid, decision: 'approve' });
  cdoc = (await db.collection('ShareCampaigns').doc(cid).get()).data(); ok(cdoc.status === 'active' && cdoc.funded === true, 'campagne validée par l\'administration');
  // l'administrateur lance une campagne : offerte, aucun paiement, active tout de suite (campagne retirée aussitôt après pour ne pas fausser la suite)
  const adm = await call(share.adsShareCampaignCreate, admin, { ...ad, brand: 'Afrolook Ads', targetAudience: 2000 });
  const admDoc = (await db.collection('ShareCampaigns').doc(adm.id).get()).data();
  ok(adm.free === true && adm.priceFcfa === 0 && admDoc.status === 'active' && admDoc.funded === true && admDoc.free === true && admDoc.priceFcfa === 0, 'campagne de l\'administrateur : offerte, aucun paiement demandé, active tout de suite', admDoc);
  await db.collection('ShareCampaigns').doc(adm.id).delete();
  const lst = await call(pubs.adsPubAdminList, admin, { campaigns: true, status: 'active' }); ok(lst.campaigns.length === 1 && lst.campaigns[0].brand === 'Boutique Kofi', 'liste admin des campagnes');
  const mine = await call(share.adsShareCampaignMine, adv, {}); ok(mine.items.length === 1 && mine.items[0].valid === 0 && mine.items[0].targetAudience === 5000 && mine.items[0].engagedAudience === 0, 'espace annonceur : audience achetée 5 000, aucune engagée', mine.items[0]);

  console.log('— Partageur : profil validé avant les missions');
  let l = await call(share.adsShareList, sh, {}); ok(l.enabled && l.profileStatus === 'none' && l.items.length === 0, 'sans profil : aucune mission proposée', l.profileStatus);
  m = await fails(call(share.adsShareCreate, sh, { campaignId: cid, channel: 'whatsapp_status' })); ok(/profil_a_valider/.test(m || ''), 'sans profil validé : pas de lien', m);
  const rules = await call(share.adsShareProfileMe, sh, {}); ok(rules.rules.version && rules.rules.text.length >= 4, 'règles renvoyées avec leur version');
  const allRules = JSON.stringify(rules.rules.text);
  ok(/SEULS LES CLICS VALIDES/.test(allRules) && /aucun doublon/.test(allRules) && /détectée automatiquement/.test(allRules) && /UN GAIN PEUT ÊTRE RETIRÉ/.test(allRules), 'les consignes disent : clics valides seulement, pas de doublon, fraude non comptée, gain retirable');
  const prof = { whatsapp: '+228 90 12 34 56', country: 'TG', city: 'Lomé', statusAudience: 300, telegramAudience: 150, groups: [{ name: 'Quartier Bè', members: 200 }], about: 'Contacts de mon quartier et groupes de ventes en ligne.', acceptTerms: true, rulesVersion: rules.rules.version };
  m = await fails(call(share.adsShareProfileSave, sh, { ...prof, acceptTerms: false })); ok(/règles/.test(m || ''), 'règles à accepter', m);
  const saved = await call(share.adsShareProfileSave, sh, prof); ok(saved.status === 'pending', 'profil envoyé : en validation');
  l = await call(share.adsShareList, sh, {}); ok(l.profileStatus === 'pending' && l.items.length === 0, 'profil en validation : toujours aucune mission');
  m = await fails(call(share.adsShareCreate, sh, { campaignId: cid, channel: 'whatsapp_status' })); ok(/profil_a_valider/.test(m || ''), 'profil en validation : pas de lien', m);
  const pl = await call(pubs.adsPubAdminList, admin, { sharers: true, status: 'pending' }); ok(pl.sharers.length === 1 && pl.sharers[0].declared === 650, 'admin : profil à valider, audience déclarée 650 (statut 300 + Telegram 150 + groupe 200)', pl.sharers[0] && pl.sharers[0].declared);
  await call(pubs.adsPubAdminReview, admin, { target: 'sharer', id: 'u_sh', decision: 'approve', audienceRetained: 500 });
  l = await call(share.adsShareList, sh, {}); ok(l.profileStatus === 'active' && l.items.length === 1 && l.items[0].coinsPerClick === 12.5, 'profil validé : 1 mission, 12,5 pièces par clic (5 F)', [l.profileStatus, l.items[0] && l.items[0].coinsPerClick]);
  m = await fails(call(share.adsShareCreate, sh, { campaignId: cid, channel: 'sms' })); ok(m !== null, 'canal inconnu refusé');

  console.log('— Lien personnel, partout où il est partagé');
  const lw = await call(share.adsShareCreate, sh, { campaignId: cid, channel: 'whatsapp_status' }, '41.9.9.9');
  ok(/^https:\/\/afrolookmedia\.com\/p\/[A-Za-z0-9_-]{8}\/$/.test(lw.url) && /\(Pub\)$/.test(lw.caption), 'lien personnel et légende avec la mention Pub', lw.url);
  const lw2 = await call(share.adsShareCreate, sh, { campaignId: cid, channel: 'whatsapp_status' }); ok(lw2.code === lw.code, 'même canal : même lien (pas de multiplication des liens)');
  const lt = await call(share.adsShareCreate, sh, { campaignId: cid, channel: 'telegram_channel' }); ok(lt.code !== lw.code, 'Telegram : un autre lien, suivi à part');
  const lf = await call(share.adsShareCreate, sh, { campaignId: cid, channel: 'facebook' }); ok(!!lf.code, 'Facebook accepté aussi');
  const stats = (await db.collection('AdShareStats').doc(cid).get()).data(); ok(stats.sharers === 1 && stats.allocatedReach === 500, 'audience engagée : 500 (retenue par l\'équipe), un seul partageur compté', stats);
  for (const c of [lw.code, lt.code, lf.code]) await db.collection('AdShareLinks').doc(c).update({ createdAt: Date.now() - 3600000 });

  const app = express(); app.use(express.text({ type: '*/*' })); app.all('/p/*', share.adsShareGo);
  const srv = await new Promise((r) => { const s = app.listen(0, () => r(s)); }); const port = srv.address().port;
  const get = (code, ip, ua = UA) => fetch(`http://127.0.0.1:${port}/p/${code}/`, { headers: { 'x-forwarded-for': ip, 'user-agent': ua }, redirect: 'manual' });
  const tokenOf = async (r) => { const h = await r.text(); const mm = h.match(/,t=("[^"]+")/); return mm ? JSON.parse(mm[1]) : null; };
  const hit = (code, ip, t, v, ua = UA) => fetch(`http://127.0.0.1:${port}/p/${code}/`, { method: 'POST', headers: { 'x-forwarded-for': ip, 'user-agent': ua, 'content-type': 'text/plain' }, body: JSON.stringify({ t, v }) });
  const earn = async () => { const d = await db.collection('AdShareEarnings').doc(`u_sh_${day}_whatsapp`).get(); return d.data(); };

  console.log('— Aperçu WhatsApp et robots : jamais un clic');
  const gw = await get(lw.code, '66.220.1.1', 'WhatsApp/2.23.20.0 A'); const hw = await gw.text();
  ok(gw.status === 200 && /og:title/.test(hw) && !/localStorage/.test(hw), 'aperçu du lien pour WhatsApp : image et titre, aucun suivi');
  const bad = await hit(lw.code, '41.1.1.1', 'jeton.falsifie', 'visiteur-aaaaaaaaaaaa'); ok(bad.status === 204 && !(await earn()), 'jeton falsifié : rien n\'est compté');

  console.log('— Clic valide, puis les doublons et les fraudes');
  let r = await get(lw.code, '41.1.1.1'); let tok = await tokenOf(r); ok(r.status === 200 && !!tok, 'un navigateur reçoit la page intermédiaire avec son jeton');
  await sleep(1000); await hit(lw.code, '41.1.1.1', tok, 'visiteur-aaaaaaaaaaaa');
  let e = await earn(); ok(e && e.fcfa === 5 && e.validClicks === 1 && e.platform === 'whatsapp', 'clic valide : 5 F en attente, plateforme WhatsApp', e);
  // même navigateur (identifiant local), autre adresse, autre lien, autre canal : un seul clic payé par personne et par campagne
  r = await get(lt.code, '41.2.2.2'); tok = await tokenOf(r); await sleep(1000); await hit(lt.code, '41.2.2.2', tok, 'visiteur-aaaaaaaaaaaa');
  e = await earn(); const eT = (await db.collection('AdShareEarnings').doc(`u_sh_${day}_telegram`).get()).data(); ok(e.validClicks === 1 && !eT, 'même navigateur sur un autre lien (Telegram) : doublon, pas payé', [e.validClicks, !!eT]);
  // même adresse et même appareil le même jour, nouvel identifiant : doublon
  r = await get(lw.code, '41.1.1.1'); tok = await tokenOf(r); await sleep(1000); await hit(lw.code, '41.1.1.1', tok, 'autre-visiteur-bbbbbbbb');
  e = await earn(); ok(e.validClicks === 1, 'même adresse et même appareil dans la journée : doublon, pas payé');
  // navigateur trop rapide (le JavaScript n'a pas vraiment attendu)
  r = await get(lw.code, '41.3.3.3'); tok = await tokenOf(r); await hit(lw.code, '41.3.3.3', tok, 'visiteur-cccccccccccc');
  e = await earn(); ok(e.validClicks === 1, 'navigateur trop rapide (robot) : refusé');
  // auto-clic : même adresse que le créateur du lien
  r = await get(lw.code, '41.9.9.9'); tok = await tokenOf(r); await sleep(1000); await hit(lw.code, '41.9.9.9', tok, 'visiteur-dddddddddddd');
  e = await earn(); ok(e.validClicks === 1, 'le partageur sur son propre lien (même adresse) : refusé');
  // un autre vrai visiteur : valide
  r = await get(lf.code, '41.4.4.4'); tok = await tokenOf(r); await sleep(1000); await hit(lf.code, '41.4.4.4', tok, 'visiteur-eeeeeeeeeeee');
  const eF = (await db.collection('AdShareEarnings').doc(`u_sh_${day}_facebook`).get()).data(); ok(eF && eF.fcfa === 5, 'un autre visiteur par le lien Facebook : valide, plateforme Facebook');
  const day2 = (await db.collection('AdShareSharerDay').doc(`u_sh_${day}`).get()).data(); ok(day2.total === 6 && day2.valid === 2 && day2.invalid === 4 && day2.self === 1 && day2.dup >= 2 && day2.tooFast === 1, 'comportement du partageur enregistré (clics, refus, auto-clics)', day2);
  const st2 = (await db.collection('AdShareStats').doc(cid).get()).data(); ok(st2.valid === 2 && st2.spentFcfa === 11, 'plafond de gains : 11 F consommés (2 clics à 5,5 F, parrain compris)', st2);
  const mine2 = await call(share.adsShareCampaignMine, adv, {}); ok(mine2.items[0].valid === 2 && mine2.items[0].engagedAudience === 500 && mine2.items[0].usedPct === 1, 'espace annonceur : chiffres visibles chez lui', mine2.items[0]);

  console.log('— Audience touchée : aperçus, ouvertures, publication prouvée, vues déclarées');
  const st3 = (await db.collection('AdShareStats').doc(cid).get()).data();
  ok(st3.previews === 1 && st3.opens >= 6 && st3.uniqueOpens >= 5, 'aperçu WhatsApp compté à part (1), ouvertures de vraies personnes comptées', [st3.previews, st3.opens, st3.uniqueOpens]);
  const lk = (await db.collection('AdShareLinks').doc(lw.code).get()).data(); ok(lk.previews === 1 && lk.proven === true && lk.uniqueOpens >= 3, 'lien WhatsApp : aperçu, ouvertures uniques, publication prouvée', [lk.previews, lk.uniqueOpens, lk.proven]);
  ok(st3.provenReach === 500 && st3.sharersPublished === 1, 'audience touchée : 500 (audience validée du partageur dont la publication est prouvée), comptée UNE seule fois', [st3.provenReach, st3.sharersPublished]);
  const lself = (await db.collection('AdShareLinks').doc(lt.code).get()).data(); ok(lself.opens >= 1, 'le lien Telegram a aussi été ouvert');
  const mine3 = await call(share.adsShareCampaignMine, adv, {}); ok(mine3.items[0].provenReach === 500 && mine3.items[0].uniqueOpens >= 5 && mine3.items[0].previews === 1 && mine3.items[0].declaredViews === 0, 'espace annonceur : audience touchée 500, ouvertures, aperçus, aucune vue déclarée', mine3.items[0]);
  let rp = await call(share.adsShareReport, sh, { campaignId: cid, views: 420 }); ok(rp.counted === true && rp.proven === true && rp.plausible === true, 'vues déclarées (420) : comptées, publication prouvée et chiffre plausible', rp);
  rp = await call(share.adsShareReport, sh, { campaignId: cid, views: 100000 }); ok(rp.counted === false && rp.plausible === false, 'vues déclarées démesurées (100 000 pour 500 personnes) : gardées à part, non comptées', rp);
  rp = await call(share.adsShareReport, sh, { campaignId: cid, views: 380 });
  const mine4 = await call(share.adsShareCampaignMine, adv, {}); ok(mine4.items[0].declaredViews === 380, 'une nouvelle déclaration remplace la précédente (pas de cumul)', mine4.items[0].declaredViews);
  m = await fails(call(share.adsShareReport, user('u_autre'), { campaignId: cid, views: 10 })); ok(m !== null, 'un compte qui n\'a pas partagé la mission ne peut rien déclarer', m);
  m = await fails(call(share.adsShareReport, sh, { campaignId: cid, views: -5 })); ok(m !== null, 'nombre de vues négatif refusé');
  const l5 = await call(share.adsShareList, sh, {}); ok(l5.items[0].results && l5.items[0].results.published === 1 && l5.items[0].results.views === 380 && l5.items[0].results.valid === 2, 'application : résultats de la mission (publication prouvée, 380 vues déclarées, 2 clics valides)', l5.items[0].results);
  await db.collection('AdShareReports').doc('u_sh_' + cid).update({ counted: 0 }); await db.collection('AdShareStats').doc(cid).update({ declaredViews: 0 });
  console.log('— Gains : retenue, pièces, parrain, plateforme dans l\'historique');
  let beforeRoll = (await db.collection('Users').doc('u_sh').get()).data().giftCoinsBalance; ok(beforeRoll === 0, 'avant la retenue : aucune pièce versée');
  await share.adsShareRollup.run({}); ok((await db.collection('Users').doc('u_sh').get()).data().giftCoinsBalance === 0, 'gains encore dans leur retenue de 72 h : rien de versé');
  for (const p of ['whatsapp', 'facebook']) await db.collection('AdShareEarnings').doc(`u_sh_${day}_${p}`).update({ releaseAt: Date.now() - 1000 });
  await share.adsShareRollup.run({});
  const u1 = (await db.collection('Users').doc('u_sh').get()).data(), s1 = (await db.collection('Users').doc('u_spon').get()).data();
  ok(u1.giftCoinsBalance === 25, 'après la retenue : 2 clics = 10 F = 25 pièces (12,5 + 12,5, la fraction est reportée)', u1.giftCoinsBalance);
  ok(s1.giftCoinsBalance === 2 && s1.totalCoinsEarnedFromSponsorship === 2, 'le parrain reçoit 10 % en plus (1 pièce par jour-plateforme, 2 au total)', s1.giftCoinsBalance);
  const evs = (await db.collection('OfferwallEvents').where('userId', '==', 'u_sh').get()).docs.map((d) => d.data());
  ok(evs.length === 2 && evs.every((x) => x.provider === 'whatsapp_partage' && x.status === 'validee') && evs.map((x) => x.platform).sort().join() === 'facebook,whatsapp', 'historique des tâches : une ligne par plateforme (WhatsApp, Facebook)', evs.map((x) => x.platform));
  await share.adsShareRollup.run({}); ok((await db.collection('Users').doc('u_sh').get()).data().giftCoinsBalance === 25, 'relancer ne paie jamais deux fois');

  console.log('— Fraude : blocage, retrait des gains, suspension');
  // une série de clics frauduleux (auto-clics, doublons, robots) sur le compte
  await db.collection('AdShareSharerDay').doc(`u_sh_${day}`).set({ uid: 'u_sh', day, total: 80, valid: 5, invalid: 75, self: 20, dup: 40, tooFast: 10 });
  await db.collection('AdShareEarnings').doc(`u_sh_${day}_tiktok`).set({ uid: 'u_sh', day, platform: 'tiktok', status: 'pending', validClicks: 3, fcfa: 18, hundredths: 4500, releaseAt: Date.now() + 86400000 });
  await share.adsShareFraudScan.run({});
  const al = (await db.collection('AdsAlerts').doc(`${day}_share_u_sh_fraud`).get()).data(); ok(al && al.type === 'share_fraud' && al.severity === 'high', 'alerte de gravité haute envoyée à l\'administration', al && al.severity);
  const pf = (await db.collection('AdShareProfiles').doc('u_sh').get()).data(); ok(pf.status === 'suspended' && /Fraude/.test(pf.reason), 'profil suspendu automatiquement avec le motif');
  const tk = (await db.collection('AdShareEarnings').doc(`u_sh_${day}_tiktok`).get()).data(); ok(tk.status === 'reversed', 'gains en attente annulés');
  const wa = (await db.collection('AdShareEarnings').doc(`u_sh_${day}_whatsapp`).get()).data(); ok(wa.status === 'reversed', 'gains déjà versés marqués retirés');
  const u2 = (await db.collection('Users').doc('u_sh').get()).data(), s2 = (await db.collection('Users').doc('u_spon').get()).data();
  ok(u2.giftCoinsBalance === 0 && (u2.offerwallDebtCoins || 0) === 0, 'pièces déjà versées reprises sur le solde (25 → 0)', [u2.giftCoinsBalance, u2.offerwallDebtCoins]);
  ok(s2.giftCoinsBalance === 0, 'commission de parrainage reprise aussi', s2.giftCoinsBalance);
  const evs2 = (await db.collection('OfferwallEvents').where('userId', '==', 'u_sh').get()).docs.map((d) => d.data().status); ok(evs2.every((x) => x === 'refusee_admin'), 'historique : gains marqués refusés');
  m = await fails(call(share.adsShareCreate, sh, { campaignId: cid, channel: 'whatsapp_status' })); ok(m !== null, 'profil suspendu : plus de mission');
  const sl = await call(pubs.adsPubAdminList, admin, { sharers: true, status: 'suspended' }); ok(sl.sharers.length === 1, 'admin : le partageur suspendu est listé');

  console.log('— Dette si les pièces sont déjà dépensées');
  await db.collection('Users').doc('u_sh').update({ giftCoinsBalance: 4 });
  await db.collection('AdShareEarnings').doc(`u_sh_${day}_other`).set({ uid: 'u_sh', day, platform: 'other', status: 'paid', coins: 10, sponsorId: null, sponsorCoins: 0, validClicks: 1, fcfa: 4 });
  const rv = await share.reverseSharerEarnings('u_sh', 'u_admin', 'test'); const u3 = (await db.collection('Users').doc('u_sh').get()).data();
  ok(rv.takenBack === 4 && rv.debt === 6 && u3.giftCoinsBalance === 0 && u3.offerwallDebtCoins === 6, 'solde de 4 pièces : 4 reprises, 6 en dette (jamais de solde négatif)', [rv, u3.giftCoinsBalance, u3.offerwallDebtCoins]);

  console.log('— Fraude modérée : blocage seulement, levé par l\'administration');
  await db.collection('AdShareProfiles').doc('u_sh').update({ status: 'active', fraudHold: false });
  await db.collection('AdShareSharerDay').doc(`u_sh_${day}`).set({ uid: 'u_sh', day, total: 40, valid: 12, invalid: 28, self: 6, dup: 5, tooFast: 0 });
  await db.collection('AdShareEarnings').doc(`u_sh_${day}_telegram`).set({ uid: 'u_sh', day, platform: 'telegram', status: 'pending', validClicks: 2, fcfa: 12, hundredths: 3000, releaseAt: Date.now() - 1000 });
  await share.adsShareFraudScan.run({});
  const held = (await db.collection('AdShareEarnings').doc(`u_sh_${day}_telegram`).get()).data(); ok(held.status === 'held', 'soupçon : gains bloqués (non versés), profil non suspendu', held.status);
  await share.adsShareRollup.run({}); ok((await db.collection('AdShareEarnings').doc(`u_sh_${day}_telegram`).get()).data().status === 'held', 'un gain bloqué n\'est jamais versé');
  await call(pubs.adsPubAdminReview, admin, { target: 'sharer', id: 'u_sh', decision: 'clear' });
  ok((await db.collection('AdShareEarnings').doc(`u_sh_${day}_telegram`).get()).data().status === 'pending', 'après vérification : blocage levé, le gain redevient versable');

  srv.close();
  console.log(`\n${pass} réussis, ${fail} échoués`);
  process.exit(fail ? 1 : 0);
})().catch((e) => { console.error('ERREUR', e); process.exit(2); });
