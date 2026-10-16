'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { buildSample } = require('../dev/sample');
const { route } = require('../src/render/router');
const D = require('../src/render/data');

const NOW = new Date('2026-10-16T08:00:00Z');
const code = '<a href="#"><img width="300" height="250" alt="" src="x.png"></a>';
const slot = (extra) => Object.assign({ actif: true, reseaux: [{ reseau: 'adsterra', code }] }, extra);

async function withAds(ads) {
  const db = await buildSample(NOW);
  await db.seed('config', 'ads', ads); D.clearCache();
  return db;
}
// ordre des blocs dans la colonne principale : carte, afrolook, pub native…
const sequence = (html) => [...html.matchAll(/<(a class="mc"|a class="afl"|div class="ad ad-nat|div class="ad ad-end|div class="mob-only"><a class="afl")/g)].map((m) => (m[1].startsWith('a class="mc"') ? 'carte' : m[1].includes('afl') ? 'afl' : m[1].includes('ad-end') ? 'fin' : 'native'));

test('liste : Afrolook après la 2e carte, native après la 3e puis toutes les N, jamais deux pubs d\'affilée ni après la dernière carte', async () => {
  const db = await withAds({ actif: true, afrolook: { actif: true, every: 6, part: 0 }, emplacements: { native: slot({ every: 4 }), fin: slot({ dk: [728, 90], mo: [320, 100] }) } });
  const full = sequence((await route(db, '/', NOW)).body);
  const seq = full.slice(0, full.indexOf('fin')); // la liste elle-même, avant la bannière et l'encart de fin
  assert.equal(seq.slice(0, 5).join(','), 'carte,carte,afl,carte,native');
  for (let i = 1; i < seq.length; i++) assert.ok(seq[i] === 'carte' || seq[i - 1] === 'carte', `deux pubs d'affilée : ${seq.join(',')}`);
  const cards = seq.filter((x) => x === 'carte').length;
  assert.ok(cards >= 8, 'assez de matchs pour le test');
  assert.notEqual(full.indexOf('fin'), -1, 'bannière de fin de liste');
  assert.equal(seq[seq.length - 1], 'carte', 'pas de pub insérée après la dernière carte');
});

test('accueil sur plusieurs jours : les pubs s\'insèrent aussi, sans séparer un titre de jour de son match', async () => {
  const db = await withAds({ actif: true, afrolook: { actif: true, every: 6, part: 0 }, emplacements: { native: slot({ every: 4 }) } });
  const html = (await route(db, '/', NOW)).body;
  assert.doesNotMatch(html, /<h2 class="dayh"[^>]*>[^<]*<\/h2><(a class="afl"|div class="ad )/, 'un titre de jour est toujours suivi de sa carte');
  assert.match(html, /<a class="afl"/);
});

test('mobile : un encart Afrolook en fin de liste (la colonne de droite n\'existe que sur ordinateur)', async () => {
  const db = await withAds({ actif: false, afrolook: { actif: true, every: 6, part: 0 }, emplacements: {} });
  const html = (await route(db, '/', NOW)).body;
  assert.match(html, /<div class="mob-only"><a class="afl"[^>]*data-afl="accueil-fin"/);
  const off = await withAds({ actif: false, afrolook: { actif: false }, emplacements: {} });
  assert.doesNotMatch((await route(off, '/', NOW)).body, /class="afl"/);
});

test('fiche d\'analyse : résultat et buts visibles, le reste derrière « Voir les paris avancés » avec l\'annonce en tête', async () => {
  const db = await withAds({ actif: true, afrolook: { actif: true, every: 6, part: 0 }, emplacements: { avance: slot({ dk: [300, 250], mo: [300, 250] }) } });
  const home = (await route(db, '/', NOW)).body;
  const href = /href="(\/football\/[a-z0-9-]+\/[a-z0-9-]+)"/.exec(home)[1];
  const r = (await route(db, href + '/analyse', NOW)).body;
  const adv = /<details class="adv" id="pf-adv">([\s\S]*?)<\/details>/.exec(r);
  assert.ok(adv, 'bloc des paris avancés');
  assert.match(adv[1], /<summary><b>Voir les paris avancés<\/b>/);
  assert.match(adv[1], /data-ad="avance"/, 'annonce en tête du bloc');
  assert.match(adv[1], /data-fam="Handicap"/); assert.match(adv[1], /data-fam="Mi-temps"/);
  assert.doesNotMatch(adv[1], /data-fam="Résultat"|data-fam="Buts"/);
  const outside = r.replace(adv[0], '');
  assert.match(outside, /data-fam="Résultat"/); assert.match(outside, /data-fam="Buts"/);
  // le contenu avancé est bien dans la page (lisible sans JavaScript)
  assert.match(adv[1], /class="fr"/);
  // anglais
  const en = (await route(db, '/en' + href.replace('/football/', '/football/') + '/analysis', NOW)).body;
  assert.match(en, /<summary><b>Show advanced bets<\/b>/);
});

test('emplacements : « avance » et « fin » existent dans la configuration, éteints par défaut', () => {
  const { mergeAds } = require('../src/render/config');
  const a = mergeAds({});
  assert.equal(a.emplacements.avance.actif, false); assert.equal(a.emplacements.fin.actif, false);
  assert.equal(a.afrolook.every, 6);
});
