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

test('carte de match : bouton « Voir plus de détails » (français et anglais), version discrète pour un match terminé', async () => {
  const db = await withAds({ actif: false, afrolook: { actif: false }, emplacements: {} });
  const fr = (await route(db, '/', NOW)).body;
  assert.match(fr, /<span class="more">Voir plus de détails <i aria-hidden="true">›<\/i><\/span><\/a>/);
  const en = (await route(db, '/en', NOW)).body;
  assert.match(en, /<span class="more">See more details /);
  const past = (await route(db, '/football/2026-10-12', NOW)).body;
  if (/class="mc"/.test(past)) assert.match(past, /<span class="more off">Voir le détail du match/);
});

test('fiche du match : plus de pronostics par groupe, annonces entre les groupes, bouton vers l\'analyse complète', async () => {
  const db = await withAds({ actif: true, afrolook: { actif: true, every: 6, part: 0 }, emplacements: { native: slot({ every: 4 }), fin: slot({ dk: [728, 90], mo: [320, 100] }) } });
  const href = /href="(\/football\/[a-z0-9-]+\/[a-z0-9-]+)"/.exec((await route(db, '/', NOW)).body)[1];
  const html = (await route(db, href, NOW)).body;
  const block = /<div class="box moreb">([\s\S]*?)<a class="more-btn"/.exec(html);
  assert.ok(block, 'bloc « Plus de pronostics »');
  assert.match(block[1], /<h3 class="gh">Résultat et buts<\/h3>/);
  assert.ok((block[1].match(/class="op /g) || []).length >= 6, 'au moins 6 pronostics supplémentaires');
  assert.match(block[1], /data-ad="native"/); assert.match(block[1], /data-ad="fin"/);
  assert.match(html, /class="more-btn" href="[^"]+\/analyse">Voir plus de détails : l'analyse complète/);
  // le pronostic principal n'est pas répété, aucun pari trop évident ni peu fiable
  const { moreMarkets } = require('../src/render/pages');
  const prono = { principal: { cle: 'a' }, marches: [
    { cle: 'a', famille: 'Résultat', pct: 70, fiabilite: 'haute' }, { cle: 'b', famille: 'Résultat', pct: 66, fiabilite: 'haute' },
    { cle: 'c', famille: 'Buts', pct: 95, fiabilite: 'haute' }, { cle: 'd', famille: 'Buts', pct: 54, fiabilite: 'haute' },
    { cle: 'e', famille: 'Corners', pct: 60, fiabilite: 'faible' }, { cle: 'f', famille: 'Corners', pct: 61, fiabilite: 'moyenne' } ] };
  const g = moreMarkets(prono);
  assert.deepEqual(g.map((x) => [x.key, x.items.map((i) => i.cle)]), [['gMain', ['b']], ['gOther', ['f']]]);
});

test('offre partenaire (Smartlink) : carte étiquetée « Sponsorisé », lien sponsorisé, éteinte par défaut, sans adresse rien n\'est affiché', async () => {
  const url = 'https://partner.example/4/abc123';
  const db = await withAds({ actif: true, afrolook: { actif: false }, emplacements: { smartlink: { actif: true, every: 8, url, titre: '', bouton: '' } } });
  const html = (await route(db, '/', NOW)).body;
  const m = /<a class="ptn" href="([^"]+)" target="_blank" rel="([^"]+)" data-ptn="liste"><span class="sp2">Sponsorisé<\/span><div class="bd"><span class="bg">Offre partenaire<\/span><p>Découvrez l&#39;offre de notre partenaire<\/p><span class="cta">Voir l&#39;offre/.exec(html);
  assert.ok(m, 'carte partenaire dans la liste');
  assert.equal(m[1], url); assert.match(m[2], /sponsored/); assert.match(m[2], /nofollow/); assert.match(m[2], /noopener/);
  // 5e position : après 4 cartes et la native éventuelle, jamais collée à une autre pub
  const idx = html.indexOf('class="ptn"');
  assert.ok((html.slice(0, idx).match(/class="mc"/g) || []).length >= 4);
  // anglais, titre et bouton personnalisés
  await db.seed('config', 'ads', { actif: true, afrolook: { actif: false }, emplacements: { smartlink: { actif: true, every: 8, url, titre: 'Bonus de bienvenue', bouton: 'Découvrir' } } }); D.clearCache();
  assert.match((await route(db, '/', NOW)).body, /<p>Bonus de bienvenue<\/p><span class="cta">Découvrir/);
  await db.seed('config', 'ads', { actif: true, afrolook: { actif: false }, emplacements: { smartlink: { actif: true, every: 8, url } } }); D.clearCache();
  assert.match((await route(db, '/en', NOW)).body, /<span class="bg">Partner offer<\/span><p>Discover our partner&#39;s offer<\/p>/);
  // fiche du match
  const href = /href="(\/football\/[a-z0-9-]+\/[a-z0-9-]+)"/.exec((await route(db, '/', NOW)).body)[1];
  assert.match((await route(db, href, NOW)).body, /data-ptn="fiche"/);
  // éteinte, ou sans adresse, ou interrupteur général coupé : rien
  for (const ads of [{ actif: true, emplacements: { smartlink: { actif: false, url } } }, { actif: true, emplacements: { smartlink: { actif: true, url: '' } } }, { actif: false, emplacements: { smartlink: { actif: true, url } } }]) {
    await db.seed('config', 'ads', Object.assign({ afrolook: { actif: false } }, ads)); D.clearCache();
    assert.doesNotMatch((await route(db, '/', NOW)).body, /class="ptn"/);
  }
});

test('offre partenaire : l\'admin n\'accepte qu\'une adresse https, titre et bouton plafonnés', () => {
  const { sanitizeAds } = require('../src/http/admin');
  const ok = sanitizeAds({ emplacements: { smartlink: { actif: true, every: 8, url: ' https://partner.example/4/abc ', titre: 'x'.repeat(200), bouton: 'y'.repeat(80) } } }).emplacements.smartlink;
  assert.equal(ok.url, 'https://partner.example/4/abc'); assert.equal(ok.titre.length, 90); assert.equal(ok.bouton.length, 30);
  for (const bad of ['http://partner.example/x', 'javascript:alert(1)', 'https://a b.example', 'https://x.example/"><script>']) {
    assert.throws(() => sanitizeAds({ emplacements: { smartlink: { actif: true, url: bad } } }), /invalide/, bad);
  }
  assert.equal(sanitizeAds({ emplacements: { smartlink: { actif: false, url: '' } } }).emplacements.smartlink.url, '');
});

test('mesure de l\'offre partenaire : affichages et clics comptés', async () => {
  const { handleEvent } = require('../src/http/track');
  const { FakeDb } = require('./helpers/fakeDb');
  const db = new FakeDb();
  const mk = () => ({ db, increment: (n) => ({ __inc: n }), now: NOW, salt: 's' });
  const req = (body) => ({ body, ua: 'Mozilla/5.0 (iPhone)', ip: '1.2.3.4', headers: {} });
  assert.equal(await handleEvent(req({ t: 'ptn_imp', fmt: 'liste' }), mk()), true);
  assert.equal(await handleEvent(req({ t: 'ptn_click', fmt: 'liste' }), mk()), true);
  const d = db.read('stats_days', '2026-10-16');
  assert.equal(d.ptnImps, 1); assert.equal(d.clicsPartenaire, 1); assert.equal(d.ptn.liste, 1); assert.equal(d.ptnClics.liste, 1);
});

test('Flash du jour : chaque carte a son bouton « Voir plus de détails »', async () => {
  const db = await withAds({ actif: false, afrolook: { actif: false }, emplacements: {} });
  const html = (await route(db, '/', NOW)).body;
  const cards = html.match(/<a class="t3"[\s\S]*?<\/a>/g) || [];
  assert.ok(cards.length >= 1 && cards.length <= 3, `${cards.length} cartes flash`);
  for (const c of cards) assert.match(c, /<span class="more">Voir plus de détails <i aria-hidden="true">›<\/i><\/span>/);
  assert.match((await route(db, '/en', NOW)).body, /<a class="t3"[\s\S]*?<span class="more">See more details/);
});

test('partout où un pronostic est affiché, on peut ouvrir le détail du match', async () => {
  const db = await withAds({ actif: false, afrolook: { actif: false }, emplacements: {} });
  const home = (await route(db, '/', NOW)).body;
  const href = /href="(\/football\/[a-z0-9-]+\/[a-z0-9-]+)"/.exec(home)[1];
  // fiche : « Autres matchs » = cartes cliquables avec bouton
  const fiche = (await route(db, href, NOW)).body;
  const om = fiche.match(/<a class="om" href="\/football\/[^"]+"><b>[^<]+<\/b><span class="pk">[^<]*<\/span><span class="more sm">Voir plus de détails <i aria-hidden="true">›<\/i><\/span><\/a>/g) || [];
  assert.ok(om.length >= 1, 'autres matchs cliquables');
  // coupons proposés : un lien vers l'analyse de chaque match
  const coupon = (await route(db, '/coupon', NOW)).body;
  const sgi = coupon.match(/<div class="sgi">[\s\S]*?<\/div><\/div>/g) || [];
  assert.ok(sgi.length >= 1);
  for (const c of sgi) assert.match(c, /<div class="sgd"><small>Voir plus de détails\s?:<\/small><a href="\/football\/[^"]+\/analyse">/);
  // bilan : résultats récents liés, avec chevron
  const bilan = (await route(db, '/bilan', NOW)).body;
  if (/class="rl"/.test(bilan)) assert.match(bilan, /<a href="\/football\/[^"]+"><span>[^<]*<\/span>[\s\S]*?<i class="chev"/);
  // données de la fiche pour le compositeur de coupon : chemin de l'analyse
  assert.match(fiche, /"u":"\/football\/[^"]+\/analyse"/);
  // anglais
  const en = (await route(db, '/en' + href.replace('/football/', '/football/'), NOW)).body;
  assert.match(en, /<span class="more sm">See more details /);
});

test('page coupon : bannières fixes (haut, après les coupons proposés, avant l\'avertissement) et emplacement « liste du coupon » éteint par défaut', async () => {
  const db = await withAds({ actif: true, afrolook: { actif: false }, emplacements: { haut: slot({ dk: [728, 90], mo: [320, 50] }), fin: slot({ dk: [728, 90], mo: [320, 100] }), fiche_native: slot({}) } });
  const html = (await route(db, '/coupon', NOW)).body;
  assert.match(html, /data-ad="haut"/); assert.match(html, /data-ad="fin"/); assert.match(html, /data-ad="fiche_native"/);
  assert.ok(html.indexOf('data-ad="haut"') < html.indexOf('data-ad="fin"') && html.indexOf('data-ad="fin"') < html.indexOf('id="pf-coupon"'), 'ordre : haut, puis coupons proposés, puis bannière, puis liste');
  assert.ok(html.indexOf('id="pf-coupon"') < html.indexOf('data-ad="fiche_native"'), 'une annonce après la liste');
  const { mergeAds } = require('../src/render/config');
  const a = mergeAds({}).emplacements.coupon_liste;
  assert.equal(a.actif, false); assert.equal(a.every, 3);
  const { sanitizeAds } = require('../src/http/admin');
  assert.equal(sanitizeAds({ emplacements: { coupon_liste: { actif: true, every: 4 } } }).emplacements.coupon_liste.every, 4);
});

test('menu pour téléphone (Football, Coupon, Bilan, À propos) sur toutes les pages, page courante marquée, anglais compris', async () => {
  const db = await withAds({ actif: false, afrolook: { actif: false }, emplacements: {} });
  for (const [path, current, label] of [['/', 'football', 'Football'], ['/coupon', 'coupon', 'Coupon'], ['/bilan', 'bilan', 'Bilan']]) {
    const html = (await route(db, path, NOW)).body;
    const nav = /<nav class="mnav"[^>]*>([\s\S]*?)<\/nav>/.exec(html);
    assert.ok(nav, `menu téléphone sur ${path}`);
    const links = nav[1].match(/<a href="[^"]+"[^>]*>/g) || [];
    assert.equal(links.length, 4);
    assert.match(nav[1], new RegExp(`<a href="[^"]+" aria-current="page"><i aria-hidden="true">[^<]+</i>${label}</a>`), `page courante ${label}`);
    assert.equal((nav[1].match(/aria-current/g) || []).length, 1);
  }
  const en = (await route(db, '/en/coupon', NOW)).body;
  assert.match(en, /<nav class="mnav"[^>]*>[\s\S]*?Bet builder[\s\S]*?Track record[\s\S]*?About/);
});

test('accueil : bloc « Coupons flash » avec liens vers le détail de chaque match et vers le constructeur', async () => {
  const db = await withAds({ actif: false, afrolook: { actif: false }, emplacements: {} });
  const html = (await route(db, '/', NOW)).body;
  assert.match(html, /<div class="lbl"[^>]*>Coupons flash<\/div>/);
  assert.ok((html.match(/<div class="sgi">/g) || []).length >= 1, 'au moins un coupon');
  assert.match(html, /<a class="more-btn" href="\/coupon">Créer mon coupon /);
  assert.ok(html.indexOf('Coupons flash') < html.indexOf('class="mc"'), 'avant la liste des matchs');
  const en = (await route(db, '/en', NOW)).body;
  assert.match(en, /Flash slips/); assert.match(en, /<a class="more-btn" href="\/en\/coupon">Build my slip /);
});
