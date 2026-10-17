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
