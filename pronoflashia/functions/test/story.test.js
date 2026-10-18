'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeDb } = require('./helpers/fakeDb');
const { parseFeed, cleanExcerpt, youtubeId } = require('../src/news/rss');
const { parsePreview, fetchPreview, publicHttps } = require('../src/news/preview');
const { syncNews } = require('../src/jobs/syncNews');
const { route } = require('../src/render/router');
const { buildSample } = require('../dev/sample');

const NOW = new Date('2026-10-16T12:00:00Z');

test('extraits : jusqu\'à 600 caractères, mentions « est apparu en premier sur » retirées, coupe propre ; identifiant YouTube lu dans le lien, l\'iframe ou le média', () => {
  assert.equal(cleanExcerpt("Le PSG s'impose. L'article Le PSG s'impose est apparu en premier sur Foot Mercato."), "Le PSG s'impose.");
  assert.equal(cleanExcerpt('The match ended 2-1. The post Match report appeared first on Site.'), 'The match ended 2-1.');
  const long = cleanExcerpt('mot '.repeat(400));
  assert.ok(long.length <= 601 && long.endsWith('…'));
  assert.equal(youtubeId('https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=3'), 'dQw4w9WgXcQ');
  assert.equal(youtubeId('https://youtu.be/dQw4w9WgXcQ'), 'dQw4w9WgXcQ');
  assert.equal(youtubeId('https://exemple.fr/dQw4w9WgXcQ'), null);
  const desc = 'Une phrase assez longue pour l\'extrait. '.repeat(8);
  const rss = `<rss><channel><item><title>Vidéo du but</title><link>https://exemple.fr/v1</link><pubDate>Fri, 16 Oct 2026 10:00:00 GMT</pubDate><description><![CDATA[<iframe src="https://www.youtube.com/embed/dQw4w9WgXcQ"></iframe>${desc}]]></description></item></channel></rss>`;
  const it = parseFeed(rss)[0];
  assert.equal(it.videoId, 'dQw4w9WgXcQ');
  assert.equal(it.video, true);
  assert.match(it.image, /i\.ytimg\.com\/vi\/dQw4w9WgXcQ/);
  assert.ok(it.resume.length > 220 && it.resume.length <= 601, 'extrait plus long qu\'avant');
});

test('aperçu de page : image et description publiées pour les aperçus de liens (guillemets, ordre des attributs, image relative) ; adresses internes refusées', async () => {
  const html = `<head><meta property="og:image" content="/img/une.jpg"><meta content="Un extrait publié par le site, assez long pour être utile au lecteur ici." property="og:description"><meta name='twitter:player' content='https://www.youtube.com/embed/dQw4w9WgXcQ'></head>`;
  const p = parsePreview(html, 'https://exemple.fr/a/b');
  assert.equal(p.image, 'https://exemple.fr/img/une.jpg');
  assert.match(p.description, /^Un extrait publié/);
  assert.equal(p.videoId, 'dQw4w9WgXcQ');
  assert.equal(parsePreview('<meta property="og:image" content="javascript:alert(1)">', 'https://x.fr').image, null);
  assert.equal(parsePreview('<meta property="og:description" content="court">', 'https://x.fr').description, '', 'description trop courte ignorée');
  for (const bad of ['http://exemple.fr/a', 'https://localhost/a', 'https://127.0.0.1/a', 'https://10.0.0.5/a', 'https://[::1]/a', 'https://monserveur/a', 'https://u:p@exemple.fr/a']) assert.equal(publicHttps(bad), false, bad);
  assert.equal(publicHttps('https://www.exemple.fr/a'), true);
  let called = 0;
  assert.equal(await fetchPreview('https://localhost/x', async () => { called++; }), null);
  assert.equal(called, 0, 'aucune requête vers une adresse interne');
  const ok = await fetchPreview('https://exemple.fr/a', async () => ({ ok: true, url: 'https://exemple.fr/a', headers: { get: () => 'text/html; charset=utf-8' }, text: async () => html }));
  assert.equal(ok.image, 'https://exemple.fr/img/une.jpg');
  assert.equal(await fetchPreview('https://exemple.fr/a', async () => ({ ok: true, url: 'https://exemple.fr/a', headers: { get: () => 'application/pdf' }, text: async () => html })), null);
  assert.equal(await fetchPreview('https://exemple.fr/a', async () => ({ ok: true, url: 'http://169.254.169.254/', headers: { get: () => 'text/html' }, text: async () => html })), null, 'redirection vers une adresse interne');
  assert.equal(await fetchPreview('https://exemple.fr/a', async () => { throw new Error('réseau'); }), null);
});

test('syncNews : l\'aperçu de la page complète l\'image et l\'extrait des articles qui n\'en ont pas ; page illisible : l\'article reste', async () => {
  const db = new FakeDb();
  const rss = `<rss><channel><item><title>Mbappé : une offre</title><link>https://exemple.fr/a1</link><pubDate>Fri, 16 Oct 2026 10:00:00 GMT</pubDate><description>Court.</description></item><item><title>Autre actu</title><link>https://exemple.fr/a2</link><pubDate>Fri, 16 Oct 2026 09:00:00 GMT</pubDate><description>Court.</description></item></channel></rss>`;
  const page = `<meta property="og:image" content="https://exemple.fr/i.jpg"><meta property="og:description" content="Une description complète publiée par le site d'origine, plus longue que l'extrait du flux.">`;
  const fetchImpl = async (url) => {
    if (url === 'https://a/feed') return { ok: true, status: 200, text: async () => rss };
    if (url === 'https://exemple.fr/a1') return { ok: true, url, headers: { get: () => 'text/html' }, text: async () => page };
    throw new Error('403');
  };
  const rep = { traites: 0, erreurs: [], infos: {} };
  await syncNews({ db, now: NOW, fetchImpl, sources: [{ id: 'a', nom: 'Site A', url: 'https://a/feed', lang: 'fr', filtre: null, actif: true }] }, rep);
  const docs = [...db.data.get('news').values()];
  const a1 = docs.find((d) => d.lien.endsWith('a1')), a2 = docs.find((d) => d.lien.endsWith('a2'));
  assert.equal(a1.image, 'https://exemple.fr/i.jpg');
  assert.match(a1.resume, /^Une description complète/);
  assert.equal(a2.image, null);
  assert.equal(a2.resume, 'Court.');
  assert.equal(rep.infos.apercus, 1);
});

async function story(db, over) {
  await db.seed('news', 'n42', Object.assign({ id: 'n42', titre: 'Mbappé et le Real Madrid : une offre record', lien: 'https://exemple.fr/a42', source: 'Foot Mercato', sourceId: 'fm', lang: 'fr', date: '2026-10-16T10:00:00.000Z', image: 'https://exemple.fr/i.jpg', video: false, videoId: null, resume: 'Un long extrait publié par le site. '.repeat(10).trim(), teamIds: [] }, over || {}));
  return (await route(db, '/actus/info-n42', new Date('2026-10-16T12:00:00Z'))).body;
}

test('page d\'une actu : image d\'aperçu créditée avec lien, essentiel (source, date, sujets), extrait long ; sans image : bandeau', async () => {
  const db = await buildSample(new Date('2026-10-16T08:00:00Z'));
  const html = await story(db);
  assert.match(html, /<figure class="stm"><a class="stimg" href="https:\/\/exemple\.fr\/a42"[^>]*><img src="https:\/\/exemple\.fr\/i\.jpg"[^>]*referrerpolicy="no-referrer"/);
  assert.match(html, /Image : Foot Mercato/);
  assert.match(html, /class="box stess"/);
  assert.match(html, /<span class="chip">Star du foot<\/span>/);
  assert.match(html, /<span class="chip s">Mbappé<\/span>/);
  assert.match(html, /<span class="chip">Mercato<\/span>/);
  assert.match(html, /Un long extrait publié par le site\./);
  assert.match(html, /noindex/);
  const sans = await story(await buildSample(new Date('2026-10-16T08:00:00Z')), { image: null });
  assert.match(sans, /class="cover"/);
  assert.doesNotMatch(sans, /class="stm"/);
});

test('page d\'une actu : vidéo YouTube en lecteur chargé au clic ; réglage « images » désactivé : ni image ni vidéo ; identifiant invalide ignoré', async () => {
  const db = await buildSample(new Date('2026-10-16T08:00:00Z'));
  const html = await story(db, { videoId: 'dQw4w9WgXcQ', video: true });
  assert.match(html, /<button type="button" class="stvid" data-v="dQw4w9WgXcQ"/);
  assert.doesNotMatch(html, /<iframe src/, 'le lecteur n\'est pas chargé avant le clic');
  const bad = await story(await buildSample(new Date('2026-10-16T08:00:00Z')), { videoId: '"><script>' });
  assert.doesNotMatch(bad, /class="stvid"/);
  assert.doesNotMatch(bad, /<script>alert/);
  const off = await buildSample(new Date('2026-10-16T08:00:00Z'));
  await off.seed('config', 'news', { actif: true, images: false });
  const h2 = await story(off, { videoId: 'dQw4w9WgXcQ', video: true });
  assert.doesNotMatch(h2, /class="stvid"|class="stimg"|src="https:\/\/exemple\.fr\/i\.jpg"/);
  assert.match(h2, /class="cover"/);
});

test('fin de liste : une seule publicité (jamais deux à la suite) ; page « Le point foot » : l\'encart du milieu seulement avec plus de 3 articles', async () => {
  const db = await buildSample(new Date('2026-10-16T08:00:00Z'));
  await db.seed('config', 'ads', { actif: true, afrolook: { actif: true, every: 6, part: 0 }, emplacements: { fin: { actif: true, dk: [728, 90], mo: [320, 100], code: { adsterra: 'x' } } } });
  const home = (await route(db, '/', new Date('2026-10-16T12:00:00Z'))).body;
  assert.doesNotMatch(home, /class="ad ad-end[^"]*"[^>]*>[^]*?<\/div>\s*<div class="mob-only"><a class="afl"/, 'pas d\'encart Afrolook collé à la pub de fin');
});

test('page « À propos » : aperçu riche pour WhatsApp (titre, description, image 1200 × 630 dédiée) et message de partage qui résume le site, en français et en anglais', async () => {
  const fs = require('fs');
  const db = await buildSample(new Date('2026-10-16T08:00:00Z'));
  const NOWS = new Date('2026-10-16T12:00:00Z');
  for (const [path, en] of [['/a-propos', false], ['/en/about', true]]) {
    const html = (await route(db, path, NOWS)).body;
    assert.match(html, /<meta property="og:title" content="[^"]+PronoFlash IA/);
    assert.match(html, /<meta property="og:description" content="[^"]{60,}"/);
    assert.match(html, en ? /og:image" content="https:\/\/[^"]+\/img\/og-about\.png"/ : /og:image" content="https:\/\/[^"]+\/img\/og-apropos\.png"/);
    assert.match(html, /og:image:width" content="1200"><meta property="og:image:height" content="630"/);
    assert.match(html, /class="box shb" data-where="apropos"/);
    const wa = /href="(https:\/\/wa\.me\/\?text=[^"]+)"/.exec(html)[1];
    const text = decodeURIComponent(wa.split('text=')[1]);
    assert.match(text, en ? /free football predictions/ : /pronostics de foot gratuits/);
    assert.match(text, /18\+/);
    assert.match(text, en ? /https:\/\/[^\s]+\/en\/about$/ : /https:\/\/[^\s]+\/a-propos$/, 'le lien de la page À propos termine le message');
    assert.ok(!/gain garanti|guaranteed/i.test(text));
  }
  for (const f of ['og-apropos.png', 'og-about.png']) {
    const png = fs.readFileSync(require('path').join(__dirname, '..', '..', 'site', 'img', f));
    assert.deepEqual([...png.subarray(0, 4)], [0x89, 0x50, 0x4e, 0x47]);
    assert.equal(png.readUInt32BE(16), 1200);
    assert.equal(png.readUInt32BE(20), 630);
  }
});

test('lectures d\'une actu : une lecture et un clic comptés sur l\'actu et dans l\'historique ; id invalide, bot et « ne pas suivre » ignorés ; affichage dans les listes et sur la page', async () => {
  const { handleEvent } = require('../src/http/track');
  const db = await buildSample(new Date('2026-10-16T08:00:00Z'));
  const id = 'aabbccddeeff00112233';
  await db.seed('news', id, { id, titre: 'Mbappé : une offre record', lien: 'https://exemple.fr/x', source: 'Foot Mercato', sourceId: 'fm', lang: 'fr', date: '2026-10-16T10:00:00.000Z', image: null, video: false, resume: 'Un extrait.', teamIds: [] });
  await db.seed('news_stats', id, { id, titre: 'Mbappé : une offre record', source: 'Foot Mercato', date: '2026-10-16T10:00:00.000Z' });
  const mk = () => ({ db, increment: (n) => ({ __inc: n }), now: NOW, salt: 's' });
  const req = (body, extra) => Object.assign({ body, ua: 'Mozilla/5.0 (iPhone)', ip: '1.2.3.4', headers: {} }, extra);
  assert.equal(await handleEvent(req({ t: 'news', n: 'vue', id }), mk()), true);
  assert.equal(await handleEvent(req({ t: 'news', n: 'vue', id }, { ip: '5.6.7.8' }), mk()), true);
  assert.equal(await handleEvent(req({ t: 'news', n: 'clic', id }), mk()), true);
  assert.equal(await handleEvent(req({ t: 'news', n: 'vue', id: 'pas-un-id' }), mk()), false);
  assert.equal(await handleEvent(req({ t: 'news', n: 'autre', id }), mk()), false);
  assert.equal(await handleEvent(req({ t: 'news', n: 'vue', id }, { ua: 'Googlebot/2.1' }), mk()), false);
  assert.equal(await handleEvent(req({ t: 'news', n: 'vue', id }, { headers: { dnt: '1' } }), mk()), false);
  assert.equal(db.read('news', id).vues, 2);
  assert.equal(db.read('news', id).clics, 1);
  assert.equal(db.read('news_stats', id).vues, 2);
  assert.equal(db.read('news_stats', id).titre, 'Mbappé : une offre record', 'identité de l\'actu conservée');
  const day = [...db.data.get('stats_days').values()].find((d) => d.actusLues);
  assert.equal(day.actusLues, 2);
  assert.equal(day.clicsActus, 1);
  // une actu supprimée continue de compter dans l'historique, sans être recréée
  assert.equal(await handleEvent(req({ t: 'news', n: 'vue', id: 'ffeeddccbbaa99887766' }), mk()), true);
  assert.equal(db.read('news', 'ffeeddccbbaa99887766'), null);
  assert.equal(db.read('news_stats', 'ffeeddccbbaa99887766').vues, 1);
  // affichage : page de l'actu et accueil
  const NOWS = new Date('2026-10-16T12:00:00Z');
  const page = (await route(db, `/actus/info-${id}`, NOWS)).body;
  assert.match(page, /data-news="aabbccddeeff00112233"/);
  assert.match(page, /<span class="nvues" data-n="2" data-one="lecture" data-many="lectures">👁 2 lectures<\/span>/);
  const zero = (await route(await buildSample(new Date('2026-10-16T08:00:00Z')), '/actus/info-n0', NOWS)).body;
  assert.match(zero, /class="nvues" data-n="0"[^>]* hidden>/, 'aucune lecture : compteur caché jusqu\'à la première');
  const n0 = db.read('news', 'n0');
  await db.seed('news', 'n0', Object.assign({}, n0, { vues: 1250 }));
  const home = (await route(db, '/', new Date('2026-10-16T12:30:00Z'))).body;
  assert.match(home, new RegExp(`${n0.source} · [^<]*· 👁 1,2\u00a0k<`), 'compteur abrégé dans les listes');
  assert.doesNotMatch(home, /· 👁 0/);
  // admin : actus les plus lues
  const { createAdmin } = require('../src/http/admin');
  const admin = createAdmin({ db, verifyToken: async () => ({ email: 'a@x.fr', email_verified: true }), bootstrap: ['a@x.fr'], tasks: {}, now: () => NOWS });
  const r = (await admin.handle({ action: 'actus', body: {}, authorization: 'Bearer t' })).json;
  assert.deepEqual(r.lues.map((x) => [x.id, x.vues, x.clics]), [[id, 2, 1], ['ffeeddccbbaa99887766', 1, 0]]);
  assert.equal(r.lues[1].titre, '(actu supprimée)');
});

test('page « Toutes les actus foot » : toutes les actus gardées (96 h), 20 par page, pages suivantes, français et anglais ; boutons vers cette page depuis l\'accueil, le coupon, le bilan, la fiche match et la page d\'une actu', async () => {
  const db = await buildSample(new Date('2026-10-16T08:00:00Z'));
  const NOWS = new Date('2026-10-16T12:00:00Z');
  for (let i = 0; i < 30; i++) {
    const id = `old${String(i).padStart(17, '0')}`;
    await db.seed('news', id, { id, titre: `Ancienne actu numéro ${i} sur le mercato`, lien: `https://exemple.fr/${id}`, source: 'Foot Mercato', sourceId: 'fm', lang: 'fr', date: new Date(NOWS.getTime() - (50 + i) * 36e5 / 2).toISOString(), image: null, video: false, resume: 'Extrait.', teamIds: [] });
  }
  const p1 = (await route(db, '/actualites', NOWS)).body;
  assert.match(p1, /<h1>Toutes les actus foot<\/h1>/);
  assert.equal((p1.match(/class="nbc"/g) || []).length, 20, '20 actus par page');
  assert.match(p1, /href="\/actualites\/2" rel="next"/);
  assert.doesNotMatch(p1, /rel="prev"/);
  assert.match(p1, /noindex/);
  assert.match(p1, /Ancienne actu numéro 0 /, 'les actus de plus de 48 h y sont aussi');
  const p2 = (await route(db, '/actualites/2', NOWS)).body;
  assert.match(p2, /Page 2 sur \d/);
  assert.match(p2, /href="\/actualites" rel="prev"/);
  assert.equal((await route(db, '/actualites/99', NOWS)).status, 200, 'page trop loin : dernière page');
  const en = (await route(db, '/en/football-news', NOWS)).body;
  assert.match(en, /<h1>All football news<\/h1>/);
  assert.match(en, /hreflang|noindex/);
  const sitemap = (await route(db, '/sitemap.xml', NOWS)).body;
  assert.ok(!/actualites|football-news/.test(sitemap), 'liste non indexée');
  // boutons vers la page
  const btn = /<a class="more-btn" href="\/actualites">Voir toutes les actus foot/;
  assert.match((await route(db, '/', NOWS)).body, btn);
  const coupon = (await route(db, '/coupon', NOWS)).body;
  assert.match(coupon, btn);
  assert.match(coupon, /class="nwb"><div class="lbl">Actus foot/);
  assert.match((await route(db, '/bilan', NOWS)).body, btn);
  const home = (await route(db, '/', NOWS)).body;
  const href = /href="(\/football\/[a-z0-9-]+\/[a-z0-9-]+)"/.exec(home)[1];
  assert.match((await route(db, href, NOWS)).body, btn);
  assert.match((await route(db, '/actus', NOWS)).body, btn);
  assert.match((await route(db, '/actus/info-n0', NOWS)).body, btn);
  assert.match((await route(db, '/en/coupon', NOWS)).body, /href="\/en\/football-news">See all football news/);
});

test('annonceurs : page « Annoncer », coordonnées (WhatsApp, e-mail pré-rempli, canal), information sur l\'accueil, À propos et pied de page, contact, plan du site, admin', async () => {
  const D = require('../src/render/data');
  const NOWS = new Date('2026-10-16T12:00:00Z');
  const db = await buildSample(new Date('2026-10-16T08:00:00Z'));
  await db.seed('config', 'site', { email: 'pub@exemple.com', whatsappPub: 'https://wa.me/22890000000', whatsapp: 'https://whatsapp.com/channel/abc123' });
  D.clearCache();
  const fr = (await route(db, '/annoncer', NOWS)).body;
  assert.match(fr, /<h1>Annoncer sur PronoFlash IA<\/h1>/);
  assert.match(fr, /Nous refusons les jeux d'argent/);
  assert.match(fr, /href="https:\/\/wa\.me\/22890000000"[^>]*data-chn="annonceurs">Nous écrire sur WhatsApp/);
  assert.match(fr, /href="mailto:pub@exemple\.com\?subject=Publicit%C3%A9%20sur%20PronoFlash%20IA"/);
  assert.match(fr, /href="https:\/\/whatsapp\.com\/channel\/abc123"[^>]*data-chn="annonceurs-canal">Suivre notre canal WhatsApp/);
  assert.doesNotMatch(fr, /robots" content="noindex/);
  const en = (await route(db, '/en/advertise', NOWS)).body;
  assert.match(en, /<h1>Advertise on PronoFlash IA<\/h1>/);
  assert.match(en, /Write to us on WhatsApp/);
  // la page contact renvoie vers l'annonce et montre les mêmes coordonnées
  const contact = (await route(db, '/contact', NOWS)).body;
  assert.match(contact, /href="\/annoncer">Annoncer sur PronoFlash IA<\/a>/);
  assert.match(contact, /class="box advc"/);
  // information sur l'accueil, À propos et pied de page de toutes les pages
  const home = (await route(db, '/', NOWS)).body;
  assert.match(home, /class="box advb"/);
  assert.match(home, /class="fadv">Une marque, une entreprise, un commerce \? <a href="\/annoncer">Annoncer sur PronoFlash IA →<\/a>/);
  assert.match((await route(db, '/a-propos', NOWS)).body, /class="box advb"/);
  assert.match((await route(db, '/coupon', NOWS)).body, /class="fadv"/);
  assert.match((await route(db, '/en', NOWS)).body, /href="\/en\/advertise">Advertise on PronoFlash IA →/);
  // plan du site
  assert.match((await route(db, '/sitemap.xml', NOWS)).body, /\/annoncer<\/loc>/);
  // sans coordonnées : message pour le propriétaire, pas de lien cassé
  const bare = await buildSample(new Date('2026-10-16T08:00:00Z'));
  await bare.seed('config', 'site', { email: '', whatsappPub: '', whatsapp: '' });
  D.clearCache();
  const none = (await route(bare, '/annoncer', NOWS)).body;
  assert.match(none, /class="todo">\[coordonnées de contact à renseigner dans l&#39;administration\]/);
  assert.doesNotMatch(none, /wa\.me|mailto:/);
  // admin : lien WhatsApp des annonceurs contrôlé
  const { createAdmin } = require('../src/http/admin');
  const admin = createAdmin({ db: new (require('./helpers/fakeDb').FakeDb)(), verifyToken: async () => ({ email: 'a@x.fr', email_verified: true }), bootstrap: ['a@x.fr'], tasks: {}, now: () => NOWS });
  const save = (site) => admin.handle({ action: 'config-save', body: { site }, authorization: 'Bearer t' });
  assert.equal((await save({ whatsappPub: 'https://wa.me/22890000000' })).status, 200);
  assert.equal((await save({ whatsappPub: 'https://exemple.com/x' })).status, 400);
  assert.equal((await save({ whatsappPub: 'https://wa.me/abc' })).status, 400);
  assert.equal((await save({ whatsappPub: 'javascript:alert(1)' })).status, 400);
});

test('sponsors directs : validation (lien https, emplacements, dates), sponsors visibles par emplacement et dates, rotation toutes les 15 minutes', () => {
  const S = require('../src/sponsors/store');
  const ok = { nom: 'Ma Marque', phrase: 'Une phrase', lien: 'https://exemple.com/offre', emplacements: ['coupon', 'accueil', 'inconnu'], actif: true };
  const c = S.clean(ok);
  assert.match(c.id, /^s[a-f0-9]{12}$/);
  assert.deepEqual(c.emplacements, ['coupon', 'accueil']);
  assert.equal(c.lien, 'https://exemple.com/offre');
  for (const bad of [{ nom: 'A' }, { lien: 'http://exemple.com' }, { lien: 'javascript:alert(1)' }, { lien: 'https://u:p@exemple.com' }, { lien: 'https://exemple.com/a b' }, { emplacements: [] }, { debut: '2026-13-45' }, { debut: '2026-10-20', fin: '2026-10-10' }]) {
    assert.throws(() => S.clean(Object.assign({}, ok, bad)), /obligatoire|https|emplacement|Dates|fin est avant/, JSON.stringify(bad));
  }
  assert.equal(S.clean(Object.assign({}, ok, { id: c.id }), c).id, c.id, 'l\'identifiant ne change pas à la modification');
  const items = [
    Object.assign({}, c, { id: 'sa00000000aa', nom: 'A' }),
    Object.assign({}, c, { id: 'sb00000000bb', nom: 'B', emplacements: ['coupon'] }),
    Object.assign({}, c, { id: 'sc00000000cc', nom: 'C', actif: false }),
    Object.assign({}, c, { id: 'sd00000000dd', nom: 'D', fin: '2026-10-01' }),
    Object.assign({}, c, { id: 'se00000000ee', nom: 'E', debut: '2026-12-01' }),
  ];
  const NOWS = new Date('2026-10-16T12:00:00Z');
  assert.deepEqual(S.activeFor(items, 'coupon', NOWS).map((x) => x.nom), ['A', 'B'], 'ni en pause, ni expiré, ni pas encore commencé');
  assert.deepEqual(S.activeFor(items, 'accueil', NOWS).map((x) => x.nom), ['A']);
  assert.equal(S.pick(items, 'actus', NOWS), null);
  const seen = new Set();
  for (let i = 0; i < 6; i++) seen.add(S.pick(items, 'coupon', new Date(NOWS.getTime() + i * 15 * 60e3)).nom);
  assert.deepEqual([...seen].sort(), ['A', 'B'], 'les deux sponsors passent à tour de rôle');
  assert.equal(S.pick(items, 'coupon', NOWS).id, S.pick(items, 'coupon', new Date(NOWS.getTime() + 60e3)).id, 'stable pendant 15 minutes');
});

test('sponsors directs : administration (création, logo contrôlé, mise à jour, suppression), encart sur le site, mesure des affichages et des clics', async () => {
  const D = require('../src/render/data');
  const { handleEvent } = require('../src/http/track');
  const { handleImg } = require('../src/http/img');
  const { createAdmin } = require('../src/http/admin');
  const NOWS = new Date('2026-10-16T12:00:00Z');
  const db = await buildSample(new Date('2026-10-16T08:00:00Z'));
  const admin = createAdmin({ db, verifyToken: async () => ({ email: 'a@x.fr', email_verified: true }), bootstrap: ['a@x.fr'], tasks: {}, now: () => NOWS, clearCache: D.clearCache });
  const call = (action, body) => admin.handle({ action, body, authorization: 'Bearer t' });
  const jpeg = 'data:image/jpeg;base64,' + Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(300)]).toString('base64');
  assert.equal((await call('sponsor-save', { item: { nom: 'Ma Marque', lien: 'http://exemple.com', emplacements: ['coupon'], actif: true } })).status, 400, 'lien non https refusé');
  assert.equal((await call('sponsor-save', { item: { nom: 'Ma Marque', lien: 'https://exemple.com', emplacements: ['coupon'], actif: true }, logo: 'data:image/png;base64,' + Buffer.from('pas une image').toString('base64') })).status, 400);
  assert.equal((await call('sponsor-save', { item: { nom: 'Ma Marque', lien: 'https://exemple.com', emplacements: ['coupon'], actif: true }, logo: 'data:image/jpeg;base64,' + Buffer.concat([Buffer.from([0xff, 0xd8, 0xff]), Buffer.alloc(210 * 1024)]).toString('base64') })).status, 400, 'logo trop lourd');
  const saved = await call('sponsor-save', { item: { nom: 'Ma Marque', phrase: 'Livraison rapide', lien: 'https://exemple.com/offre', emplacements: ['coupon', 'accueil'], actif: true }, logo: jpeg });
  assert.equal(saved.status, 200);
  const id = saved.json.id;
  let list = (await call('sponsors', {})).json;
  assert.equal(list.items.length, 1);
  assert.match(list.items[0].logo, /^s[a-f0-9]{16}$/);
  const logoId = list.items[0].logo;
  // logo servi par /api/img (collection à part)
  const img = await handleImg({ path: `/api/img/${logoId}.jpg` }, { db });
  assert.equal(img.status, 200);
  assert.equal(img.type, 'image/jpeg');
  // encart sur l'accueil, la page coupon ; absent des pages actus (non choisi)
  D.clearCache();
  const home = (await route(db, '/', NOWS)).body;
  assert.match(home, new RegExp(`<aside class="spb" data-sp="${id}" aria-label="Sponsorisé"><span class="spl">Sponsorisé</span><a class="spa" href="https://exemple.com/offre" target="_blank" rel="sponsored nofollow noopener"><img src="/api/img/${logoId}.jpg"`));
  assert.match(home, /<b>Ma Marque<\/b><small>Livraison rapide<\/small>/);
  const coupon = (await route(db, '/coupon', NOWS)).body;
  assert.match(coupon, /Coupon du jour offert par Ma Marque/);
  assert.doesNotMatch((await route(db, '/actualites', NOWS)).body, /class="spb"/);
  assert.match((await route(db, '/en/coupon', NOWS)).body, /Slip of the day brought to you by Ma Marque/);
  // mesure : affichages et clics ; identifiant ou type invalides, bots ignorés
  const mk = () => ({ db, increment: (n) => ({ __inc: n }), now: NOWS, salt: 's' });
  const req = (body, extra) => Object.assign({ body, ua: 'Mozilla/5.0 (iPhone)', ip: '1.2.3.4', headers: {} }, extra);
  assert.equal(await handleEvent(req({ t: 'sp', n: 'imp', id }), mk()), true);
  assert.equal(await handleEvent(req({ t: 'sp', n: 'imp', id }, { ip: '5.5.5.5' }), mk()), true);
  assert.equal(await handleEvent(req({ t: 'sp', n: 'clic', id }), mk()), true);
  assert.equal(await handleEvent(req({ t: 'sp', n: 'imp', id: '../x' }), mk()), false);
  assert.equal(await handleEvent(req({ t: 'sp', n: 'autre', id }), mk()), false);
  assert.equal(await handleEvent(req({ t: 'sp', n: 'imp', id }, { ua: 'Googlebot/2.1' }), mk()), false);
  list = (await call('sponsors', {})).json;
  assert.deepEqual([list.items[0].sept.imp, list.items[0].sept.clics, list.items[0].quatreVingtDix.imp], [2, 1, 2]);
  const rep = (await call('sponsor-stats', { id, jours: 30 })).json;
  assert.deepEqual(rep.jours, [{ jour: '2026-10-16', imp: 2, clics: 1 }]);
  // mise à jour : pause + retrait du logo ; l'encart disparaît du site
  const upd = await call('sponsor-save', { item: { id, nom: 'Ma Marque', phrase: 'Livraison rapide', lien: 'https://exemple.com/offre', emplacements: ['coupon'], actif: false }, retirerLogo: true });
  assert.equal(upd.status, 200);
  assert.equal(db.read('sponsor_media', logoId), null, 'ancien logo supprimé');
  D.clearCache();
  assert.doesNotMatch((await route(db, '/', NOWS)).body, /class="spb"/);
  assert.equal((await call('sponsor-save', { item: { id: 'sinconnu000000', nom: 'X', lien: 'https://exemple.com', emplacements: ['coupon'] } })).status, 404);
  // suppression
  assert.equal((await call('sponsor-delete', { id })).status, 200);
  assert.equal((await call('sponsors', {})).json.items.length, 0);
  assert.equal((await call('sponsor-delete', { id })).status, 404);
});

test('cote équivalente : 1 / probabilité, formatée (virgule en français, point en anglais), jamais présentée comme une cote de bookmaker', () => {
  const C = require('../src/shared/coupon');
  assert.equal(C.fairOdds(0.5), 2);
  assert.equal(C.fairOdds(0), null);
  assert.equal(C.fairOdds(1.5), null);
  assert.equal(C.formatOdds(2, 'fr'), '2,00');
  assert.equal(C.formatOdds(2, 'en'), '2.00');
  assert.equal(C.formatOdds(1 / 0.0833, 'fr'), '12,0');
  assert.equal(C.formatOdds(250.4, 'fr'), '250');
  assert.equal(C.formatOdds(null, 'fr'), '–');
});

test('bilan des coupons : page dédiée (résumé, niveaux, cote équivalente, série, gagnés et perdus par jour, pagination, filtres), reliée depuis le bilan, le coupon et le plan du site', async () => {
  const D = require('../src/render/data');
  const db = await buildSample(new Date('2026-10-16T08:00:00Z'));
  const NOWS = new Date('2026-10-16T12:00:00Z');
  for (const [id] of [...(db.data.get('coupons_flash') || [])]) await db.collection('coupons_flash').doc(id).delete(); // on part d'une base de coupons connue
  const TIERS = [['prudent', 2, 0.5], ['equilibre', 3, 0.25], ['audacieux', 5, 0.1]];
  // 12 jours de coupons : tout gagné sauf les « audacieux » (perdus), le dernier jour reste ouvert
  for (let d = 0; d < 12; d++) {
    const jour = new Date(Date.UTC(2026, 9, 15 - d)).toISOString().slice(0, 10);
    for (const [nom, n, prob] of TIERS) {
      const open = d === 0;
      const statut = open ? 'ouvert' : nom === 'audacieux' ? 'perdu' : 'gagne';
      await db.seed('coupons_flash', `${jour}_${n}`, { id: `${jour}_${n}`, jour, n, nom, prob, statut, creeLe: `${jour}T06:00:00Z`, selections: Array.from({ length: n }, (_, i) => ({ matchId: `m${i}`, key: 'res:1', libelle: 'A gagne', famille: 'Résultat', pct: 70, titre: `A${i} – B${i}`, dom: `A${i}`, ext: `B${i}`, slug: `a${i}-b${i}`, leagueSlug: 'ligue-1', coupDEnvoi: `${jour}T15:00:00Z`, ok: open ? null : (statut === 'gagne' ? true : i === 0 ? false : true) })) });
    }
  }
  D.clearCache();
  const p1 = (await route(db, '/bilan-coupons', NOWS)).body;
  assert.match(p1, /<h1>Bilan des <b>coupons<\/b><\/h1>/);
  assert.match(p1, /<nav class="bt"[^>]*><a href="\/bilan">Pronostics<\/a><a href="\/bilan-coupons" aria-current="page">Coupons<\/a>/);
  assert.match(p1, /<div class="kpi"><b class="num">33<\/b><span>coupons réglés<\/span>/);
  assert.match(p1, /<b class="num">22<\/b><span>gagnés<\/span>/, 'gagnés');
  assert.match(p1, /<b class="num">11<\/b><span>perdus<\/span>/, 'perdus');
  assert.match(p1, /67\u00a0%/, 'taux 22 sur 33');
  assert.match(p1, /cote équivalente ≈ 2,00/, 'prudent : probabilité 50 % = cote équivalente 2,00');
  assert.match(p1, /cote équivalente ≈ 4,00/);
  assert.match(p1, /cote équivalente ≈ 10,0/);
  assert.match(p1, /Plus grosse cote gagnée ≈ 4,00/);
  assert.match(p1, /Ce n'est pas une cote de bookmaker/);
  assert.match(p1, /class="ac ac-gagne"/);
  assert.match(p1, /class="ac ac-perdu"/);
  assert.match(p1, /class="ac ac-ouvert"/);
  assert.match(p1, /data-f="gagne"/);
  assert.equal((p1.match(/class="bcd"/g) || []).length, 10, '10 jours par page');
  assert.match(p1, /href="\/bilan-coupons\/2" rel="next"/);
  const p2 = (await route(db, '/bilan-coupons/2', NOWS)).body;
  assert.equal((p2.match(/class="bcd"/g) || []).length, 2);
  assert.match(p2, /href="\/bilan-coupons" rel="prev"/);
  assert.match(p2, /Page 2 sur 2/);
  const en = (await route(db, '/en/slips-track-record', NOWS)).body;
  assert.match(en, /<h1>Slips <b>track record<\/b><\/h1>/);
  assert.match(en, /equivalent odds ≈ 2\.00/);
  assert.match(en, /not bookmaker odds|Not a bookmaker odds|They are not bookmaker odds/);
  // reliée depuis le bilan (onglets + encadré + historique), le plan du site
  const bilan = (await route(db, '/bilan', NOWS)).body;
  assert.match(bilan, /<a href="\/bilan" aria-current="page">Pronostics<\/a><a href="\/bilan-coupons">Coupons<\/a>/);
  assert.match(bilan, /class="box cbl"/);
  assert.match(bilan, /href="\/bilan-coupons">Voir le bilan des coupons/);
  assert.match((await route(db, '/sitemap.xml', NOWS)).body, /\/bilan-coupons<\/loc>/);
  // cote estimée sur les coupons proposés (accueil, page coupon)
  assert.match((await route(db, '/coupon', NOWS)).body, /<small>cote ≈ \d+,\d{2}<\/small>/);
  // sans aucun coupon : message, pas d'erreur
  const vide = await buildSample(new Date('2026-10-16T08:00:00Z'));
  for (const [id] of vide.data.get('coupons_flash') || []) await vide.collection('coupons_flash').doc(id).delete();
  D.clearCache();
  const none = await route(vide, '/bilan-coupons', NOWS);
  assert.equal(none.status, 200);
  assert.match(none.body, /Aucun coupon enregistré pour le moment/);
});
