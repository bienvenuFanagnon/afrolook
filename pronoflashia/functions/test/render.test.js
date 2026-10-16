'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { buildSample } = require('../dev/sample');
const { route, VERSION } = require('../src/render/router');
const D = require('../src/render/data');

const NOW = new Date('2026-10-16T08:00:00Z');
let db;
test.before(async () => { db = await buildSample(NOW); });
test.beforeEach(() => D.clearCache());

const get = (p) => route(db, p, NOW);
const firstMatchPath = async () => {
  const r = await get('/football/aujourdhui');
  return /href="(\/football\/[a-z0-9-]+\/[a-z0-9-]+)"/.exec(r.body)[1];
};

test('accueil : 200, pronostics visibles sans clic, titre et description, un seul h1', async () => {
  const r = await get('/');
  assert.equal(r.status, 200);
  assert.match(r.headers['Content-Type'], /text\/html/);
  assert.match(r.body, /<title>[^<]{20,}<\/title>/);
  assert.match(r.body, /<meta name="description" content="[^"]{60,}/);
  assert.equal((r.body.match(/<h1/g) || []).length, 1);
  assert.match(r.body, /class="pk1">Pronostic/);
  assert.match(r.body, /class="cf num/);
  assert.match(r.body, /<link rel="canonical" href="https:\/\/pronoflashia\.web\.app\/">/);
  assert.match(r.headers['Cache-Control'], /s-maxage=300/);
  assert.ok(r.body.includes('18+'), 'mention 18+ sur toutes les pages');
  assert.ok(r.body.includes('aucun gain') || r.body.includes("Aucun gain"), 'aucun gain garanti');
});

test('publicité : aucun emplacement tiers tant que l\'admin ne l\'a pas activé, encarts Afrolook présents', async () => {
  const r = await get('/');
  assert.ok(!r.body.includes('data-ad='), 'aucun emplacement réseau par défaut');
  assert.ok(!r.body.includes('pf-stk'), 'pas de bannière collante');
  assert.match(r.body, /class="afl"/);
  assert.match(r.body, /utm_source=pronoflashia&amp;utm_campaign=/);
});

test('publicité activée par l\'admin : emplacements réservés, un seul format visible par appareil', async () => {
  await db.seed('config', 'ads', { actif: true, emplacements: { haut: { actif: true }, native: { actif: true, every: 4 }, collante: { actif: true } } });
  D.clearCache();
  const r = await get('/');
  assert.match(r.body, /data-ad="haut" data-v="dk" data-w="728" data-h="90"/);
  assert.match(r.body, /data-ad="haut" data-v="mo" data-w="320" data-h="50"/);
  assert.match(r.body, /data-ad="native"/);
  assert.match(r.body, /id="pf-stk"/);
  assert.ok(!r.body.includes('data-ad="colonne_rect"'), 'emplacement non activé = absent');
  // interrupteur général coupé : tout disparaît même si les emplacements sont actifs
  await db.seed('config', 'ads', { actif: false, emplacements: { haut: { actif: true } } });
  D.clearCache();
  assert.ok(!(await get('/')).body.includes('data-ad='));
  await db.seed('config', 'ads', {}); D.clearCache();
});

test('fiche match : verdict, balisage SportsEvent, texte IA, bouton vers l\'analyse', async () => {
  const p = await firstMatchPath();
  const r = await get(p);
  assert.equal(r.status, 200);
  const ld = JSON.parse(/<script type="application\/ld\+json">(.*?)<\/script>/s.exec(r.body)[1]);
  assert.equal(ld['@type'], 'SportsEvent');
  assert.ok(ld.name && ld.startDate && ld.location && ld.homeTeam.name);
  assert.match(r.body, /Notre pronostic/);
  assert.match(r.body, new RegExp(`href="${p}/analyse"`));
  assert.match(r.body, /Rédigée par l'IA/);
  assert.match(r.body, /id="pf-match"/);
  assert.match(r.headers['Cache-Control'], /s-maxage=300/);
});

test('analyse complète : tous les paris par famille, comparatif, coupons prêts, ratés comme réussis dans les résultats', async () => {
  const r = await get(`${await firstMatchPath()}/analyse`);
  assert.equal(r.status, 200);
  for (const f of ['Résultat', 'Buts', 'Mi-temps', 'Handicap', 'Score', 'Spéciaux']) assert.ok(r.body.includes(`data-fam="${f}"`), f);
  assert.match(r.body, /data-add="/);
  assert.match(r.body, /id="d-coupon"/);
  assert.match(r.body, /Faible/);
  assert.match(r.body, /Comparatif des deux équipes/);
});

test('bilan : taux calculé, ratés affichés', async () => {
  const r = await get('/bilan');
  assert.equal(r.status, 200);
  assert.match(r.body, /Réussite 30 jours/);
  assert.match(r.body, /Ratés/);
  assert.match(r.body, /annoncé contre réel/);
});

test('coupon : coupons proposés rendus côté serveur et données du compositeur', async () => {
  const r = await get('/coupon');
  assert.match(r.body, /Prudent · 2 sélections/);
  assert.match(r.body, /id="pf-pool"/);
  const pool = JSON.parse(/<script type="application\/json" id="pf-pool">(.*?)<\/script>/s.exec(r.body)[1]);
  assert.ok(pool.length >= 3);
  assert.ok(pool[0].matrice.length === 7);
  assert.ok(pool[0].marches.every((m) => m.r !== 'f' && m.p >= 50));
  assert.ok(!/cote|mise de/i.test(r.body.replace(/Aucune mise, aucune cote/g, '').replace(/Sans mise, sans cote/g, '').replace(/n'affiche aucune cote/g, '')), 'aucune cote ni mise');
});

test('jours, championnat, pages légales, 404 et redirection', async () => {
  assert.equal((await get('/football/demain')).status, 200);
  assert.equal((await get('/football/2026-10-17')).status, 200);
  assert.equal((await get('/football/ligue-1')).status, 200);
  assert.equal((await get('/football')).status, 301);
  for (const p of ['/a-propos', '/contact', '/confidentialite', '/conditions', '/cookies', '/mentions-legales', '/jeu-responsable']) {
    const r = await get(p); assert.equal(r.status, 200, p); assert.match(r.body, /<h1>/);
  }
  assert.equal((await get('/football/ligue-1/inexistant-2026-01-01')).status, 404);
  assert.equal((await get('/nimporte-quoi')).status, 404);
  assert.match((await get('/nimporte-quoi')).body, /noindex/);
  assert.equal((await get('/FOOTBALL/Ligue-1/')).status, 200, 'insensible à la casse et au / final');
});

test('pages légales : champs à renseigner signalés tant que l\'admin n\'a pas rempli ; ensuite affichés et échappés', async () => {
  await db.seed('config', 'site', {}); D.clearCache();
  assert.match((await get('/mentions-legales')).body, /à renseigner dans l'administration/);
  await db.seed('config', 'site', { editeur: 'Acme <b>SA</b>', email: 'c@x.com', adresse: '1 rue X', statutJuridique: 'SARL', loi: 'France' }); D.clearCache();
  const r = (await get('/mentions-legales')).body;
  assert.ok(!r.includes('à renseigner dans l\'administration'));
  assert.ok(r.includes('Acme &lt;b&gt;SA&lt;/b&gt;'), 'échappement HTML');
  await db.seed('config', 'site', { email: 'contact@pronoflashia.com', editeur: 'À renseigner', statutJuridique: 'À renseigner', adresse: 'À renseigner' }); D.clearCache();
});

test('robots, sitemap et ads.txt', async () => {
  const rb = await get('/robots.txt');
  assert.match(rb.body, /Disallow: \/admin/); assert.match(rb.body, /Sitemap: https:\/\/pronoflashia\.web\.app\/sitemap\.xml/);
  const sm = await get('/sitemap.xml');
  assert.match(sm.headers['Content-Type'], /xml/);
  assert.ok((sm.body.match(/<loc>/g) || []).length > 30);
  assert.match(sm.body, /\/analyse<\/loc>/);
  await db.seed('config', 'ads', { adsTxt: 'adsterra.com, 123, DIRECT, abcdef1234567890' }); D.clearCache();
  assert.match((await get('/ads.txt')).body, /^adsterra\.com, 123, DIRECT/);
  await db.seed('config', 'ads', {}); D.clearCache();
  await db.seed('config', 'site', { indexable: false }); D.clearCache();
  assert.match((await get('/robots.txt')).body, /Disallow: \/\n/);
  assert.match((await get('/')).body, /noindex/);
  await db.seed('config', 'site', {}); D.clearCache();
});

test('un pronostic masqué par l\'admin disparaît des pages et du sitemap', async () => {
  const p = await firstMatchPath();
  const slug = p.split('/')[3];
  const id = db.all('matches').find((m) => m.slug === slug)._id;
  const cur = db.read('matches', id); cur.prono.visible = false; await db.seed('matches', id, cur); D.clearCache();
  assert.equal((await get(p)).status, 404);
  assert.ok(!(await get('/football/aujourdhui')).body.includes(p));
  assert.ok(!(await get('/sitemap.xml')).body.includes(p));
  cur.prono.visible = true; await db.seed('matches', id, cur); D.clearCache();
});

test('CSS en ligne et script versionné ; aucune ressource externe', async () => {
  const r = (await get('/')).body;
  assert.ok(r.includes('<style>') && r.includes('--flash:#FFD60A'));
  assert.match(r, new RegExp(`/js/pf\\.js\\?v=${VERSION}`));
  assert.ok(!/(src|href)="https?:\/\/(?!pronoflashia)/.test(r.replace(/https:\/\/(play\.google\.com|apps\.apple\.com|wa\.me|crests\.football-data\.org)[^"]*/g, '')), 'aucune ressource externe chargée');
  assert.ok(r.length < 120000, `HTML léger (${r.length} octets)`);
});

/* ---------- version anglaise ---------- */
const enMatchPath = async () => {
  const r = await get('/en/football/today');
  return /href="(\/en\/football\/[a-z0-9-]+\/[a-z0-9-]+)"/.exec(r.body)[1];
};

test('anglais : accueil en anglais, hreflang croisés, bouton de langue', async () => {
  const r = await get('/en');
  assert.equal(r.status, 200);
  assert.match(r.body, /<html lang="en">/);
  assert.match(r.body, /Today's football tips/);
  assert.match(r.body, /<link rel="canonical" href="https:\/\/pronoflashia\.web\.app\/en">/);
  assert.match(r.body, /hreflang="fr" href="https:\/\/pronoflashia\.web\.app\/"/);
  assert.match(r.body, /hreflang="en" href="https:\/\/pronoflashia\.web\.app\/en"/);
  assert.match(r.body, /hreflang="x-default"/);
  assert.match(r.body, /class="lang" href="\/" hreflang="fr"/);
  assert.ok(!/Pronostic|Aujourd'hui|réussite|Jouez de façon/.test(r.body.replace(/<style>[\s\S]*?<\/style>/, '')), 'aucun texte français d\'interface');
  assert.match(r.body, /CAF Champions League/, 'nom de championnat traduit');
  assert.match(r.body, /og:locale" content="en_GB"/);
  const fr = await get('/');
  assert.match(fr.body, /class="lang" href="\/en" hreflang="en"/);
});

test('anglais : fiche match, pronostic, paris et analyse en anglais', async () => {
  const p = await enMatchPath();
  const r = await get(p);
  assert.equal(r.status, 200);
  assert.match(r.body, /Our prediction/);
  assert.match(r.body, /The model|Calculated probabilities/, 'analyse anglaise');
  assert.ok(!/ gagne|Victoire|Match nul|buts</.test(r.body.replace(/<script[\s\S]*?<\/script>/g, '').replace(/<style>[\s\S]*?<\/style>/, '')), 'aucun libellé français');
  assert.match(r.body, new RegExp(`href="${p}/analysis"`));
  const frPath = p.replace(/^\/en/, '');
  assert.match(r.body, new RegExp(`hreflang="fr" href="https://pronoflashia\\.web\\.app${frPath}"`));
  const ld = JSON.parse(/<script type="application\/ld\+json">(.*?)<\/script>/s.exec(r.body)[1]);
  assert.equal(ld.inLanguage, 'en');
  const data = JSON.parse(/<script type="application\/json" id="pf-match">(.*?)<\/script>/s.exec(r.body)[1]);
  assert.ok(data.marches.some((x) => / to win$/.test(x.l)), 'libellés anglais pour le coupon');
  assert.ok(data.marches.every((x) => !/é/.test(x.f)), 'familles en anglais');
});

test('anglais : analyse complète, bilan, coupon, pages légales et 404', async () => {
  const p = await enMatchPath();
  const d = await get(p + '/analysis');
  assert.equal(d.status, 200);
  assert.match(d.body, /data-fam="Goals"/);
  assert.match(d.body, /Every bet for this match/);
  assert.equal((await get(p + '/analyse')).status, 404, 'segment français refusé sous /en');
  const b = await get('/en/track-record');
  assert.equal(b.status, 200); assert.match(b.body, /30-day success rate/);
  const c = await get('/en/coupon');
  assert.match(c.body, /Cautious · 2 selections/);
  assert.match(c.body, /href="\/en\/coupon#/);
  for (const s of ['about', 'contact', 'privacy', 'terms', 'cookies', 'legal-notice', 'responsible-gambling']) {
    const r = await get('/en/' + s); assert.equal(r.status, 200, s); assert.match(r.body, /<html lang="en">/);
  }
  assert.match((await get('/en/privacy')).body, /hreflang="fr" href="https:\/\/pronoflashia\.web\.app\/confidentialite"/);
  assert.equal((await get('/en/bilan')).status, 404);
  assert.equal((await get('/en/football')).status, 301);
  assert.equal((await get('/en/football')).headers.Location, '/en/football/today');
  const nf = await get('/en/nothing');
  assert.equal(nf.status, 404); assert.match(nf.body, /Page <b>not found<\/b>/);
});

test('anglais : jours et championnats', async () => {
  const r = await get('/en/football/tomorrow');
  assert.equal(r.status, 200); assert.match(r.body, /Football tips <b>for tomorrow<\/b>/);
  assert.match(r.body, /hreflang="fr" href="https:\/\/pronoflashia\.web\.app\/football\/demain"/);
  const l = await get('/en/football/ligue-des-champions-caf');
  assert.equal(l.status, 200); assert.match(l.body, /<b>CAF Champions League<\/b> predictions/);
});

test('sitemap bilingue avec alternatives', async () => {
  const sm = (await get('/sitemap.xml')).body;
  assert.match(sm, /xmlns:xhtml/);
  assert.match(sm, /<loc>https:\/\/pronoflashia\.web\.app\/en\/track-record<\/loc>/);
  assert.match(sm, /<loc>https:\/\/pronoflashia\.web\.app\/bilan<\/loc><xhtml:link rel="alternate" hreflang="fr" href="https:\/\/pronoflashia\.web\.app\/bilan"\/><xhtml:link rel="alternate" hreflang="en" href="https:\/\/pronoflashia\.web\.app\/en\/track-record"\/>/);
  assert.match(sm, /\/analysis<\/loc>/);
});
