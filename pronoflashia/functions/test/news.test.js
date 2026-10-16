'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeDb } = require('./helpers/fakeDb');
const { parseFeed, safeUrl } = require('../src/news/rss');
const { teamsInTitle } = require('../src/news/match');
const { syncNews } = require('../src/jobs/syncNews');
const { createAdmin } = require('../src/http/admin');

const NOW = new Date('2026-10-16T12:00:00Z');
const RSS = `<?xml version="1.0"?><rss version="2.0"><channel><title>Site</title>
<item><title><![CDATA[Marseille : Mbappé &amp; Cie en conf’]]></title><link>https://exemple.fr/a1?x=1&amp;y=2</link><pubDate>Fri, 16 Oct 2026 10:00:00 GMT</pubDate><description><![CDATA[<p>Un <b>résumé</b> court.</p>]]></description></item>
<item><title>Titre sans date</title><link>https://exemple.fr/a2</link></item>
<item><title>Lien dangereux</title><link>javascript:alert(1)</link><pubDate>Fri, 16 Oct 2026 10:00:00 GMT</pubDate></item>
<item><title>Nice temps pour le foot ?</title><link>https://exemple.fr/a3</link><pubDate>Fri, 16 Oct 2026 09:00:00 GMT</pubDate></item>
<item><title>Vieille info Marseille</title><link>https://exemple.fr/a4</link><pubDate>Mon, 01 Jun 2026 09:00:00 GMT</pubDate></item>
</channel></rss>`;
const ATOM = `<feed xmlns="http://www.w3.org/2005/Atom"><entry><title>Al Ahly gagne</title><link rel="alternate" href="https://exemple.eg/x"/><updated>2026-10-16T08:00:00Z</updated><summary>Résumé</summary></entry></feed>`;

test('lecture RSS et Atom : entités, CDATA, balises retirées, liens dangereux et éléments incomplets ignorés', () => {
  const it = parseFeed(RSS);
  assert.equal(it.length, 3);
  assert.equal(it[0].titre, 'Marseille : Mbappé & Cie en conf’');
  assert.equal(it[0].lien, 'https://exemple.fr/a1?x=1&y=2');
  assert.equal(it[0].resume, 'Un résumé court.');
  assert.equal(it[0].date, '2026-10-16T10:00:00.000Z');
  const at = parseFeed(ATOM);
  assert.equal(at[0].lien, 'https://exemple.eg/x');
  assert.equal(safeUrl('javascript:alert(1)'), null);
  assert.deepEqual(parseFeed('pas du xml'), []);
});

test('reconnaissance des équipes : accents et casse ignorés, noms courts avec majuscule', () => {
  const teams = [{ id: '1', noms: ['Marseille', 'Olympique De Marseille'] }, { id: '2', noms: ['Nice'] }, { id: '3', noms: ['Espérance de Tunis'] }, { id: '4', noms: ['Lens'] }];
  assert.deepEqual(teamsInTitle('OM : marseille prépare le match', teams), ['1']);
  assert.deepEqual(teamsInTitle('Nice temps pour le foot', teams), ['2'], 'majuscule d\'origine : « Nice » en début de phrase compte');
  assert.deepEqual(teamsInTitle('un nice temps pour le foot', teams), [], 'mot courant en minuscule : non');
  assert.deepEqual(teamsInTitle('Esperance de TUNIS se déplace', teams), ['3']);
  assert.deepEqual(teamsInTitle('Les lenses de contact', teams), []);
});

const feeds = (map) => async (url) => { const b = map[url]; if (b instanceof Error) throw b; return { ok: true, status: 200, text: async () => b }; };
const SRC = [
  { id: 'a', nom: 'Site A', url: 'https://a/feed', lang: 'fr', filtre: null, actif: true },
  { id: 'b', nom: 'Site B', url: 'https://b/feed', lang: 'en', filtre: /league/i, actif: true },
  { id: 'c', nom: 'Site C', url: 'https://c/feed', lang: 'fr', filtre: null, actif: false },
];

async function seedMatch(db) {
  await db.seed('matches', 'm1', { id: 'm1', coupDEnvoi: '2026-10-16T19:00:00.000Z', domicile: { teamId: 81, nom: 'Olympique De Marseille', nomCourt: 'Marseille' }, exterieur: { teamId: 85, nom: 'Paris Saint Germain', nomCourt: 'PSG' } });
}

test('syncNews : nouveaux articles enregistrés une fois, équipes repérées, vieux articles ignorés, source en panne isolée', async () => {
  const db = new FakeDb();
  await seedMatch(db);
  const fetchImpl = feeds({ 'https://a/feed': RSS, 'https://b/feed': new Error('HTTP 403') });
  const rep = { traites: 0, erreurs: [], infos: {} };
  await syncNews({ db, now: NOW, fetchImpl, sources: SRC }, rep);
  const all = db.all('news');
  assert.equal(all.length, 2, 'le vieil article et le lien dangereux sont ignorés');
  const marseille = all.find((n) => n.titre.startsWith('Marseille'));
  assert.deepEqual(marseille.teamIds, ['81']);
  assert.equal(marseille.source, 'Site A');
  assert.equal(rep.erreurs.length, 0, 'une source en panne n\'est pas une erreur de la tâche');
  assert.equal(rep.infos.pannes.length, 1);
  assert.equal(db.read('news_sources', 'b').ok, false);
  assert.equal(db.read('news_sources', 'a').ok, true);
  assert.equal(db.read('news_sources', 'c'), null, 'source désactivée : jamais appelée');
  // deuxième passage : pas de doublon
  await syncNews({ db, now: NOW, fetchImpl, sources: SRC }, { traites: 0, erreurs: [], infos: {} });
  assert.equal(db.all('news').length, 2);
  // toutes les sources en panne : la tâche est en erreur
  const r2 = { traites: 0, erreurs: [], infos: {} };
  await syncNews({ db: new FakeDb(), now: NOW, fetchImpl: feeds({ 'https://a/feed': new Error('HTTP 500'), 'https://b/feed': new Error('HTTP 500') }), sources: SRC }, r2);
  assert.equal(r2.erreurs.length, 1);
});

test('syncNews : interrupteur général et réglage par source ; nettoyage des articles trop anciens', async () => {
  const db = new FakeDb();
  await db.seed('config', 'news', { actif: false });
  const fetchImpl = feeds({ 'https://a/feed': RSS });
  const rep = { traites: 0, erreurs: [], infos: {} };
  await syncNews({ db, now: NOW, fetchImpl, sources: SRC }, rep);
  assert.equal(db.all('news').length, 0);
  await db.seed('config', 'news', { actif: true, sources: { a: false, c: true } });
  await db.seed('news', 'vieux', { id: 'vieux', titre: 'x', lien: 'https://x', date: '2026-10-01T00:00:00.000Z', teamIds: [] });
  await syncNews({ db, now: NOW, fetchImpl: feeds({ 'https://c/feed': RSS }), sources: SRC }, { traites: 0, erreurs: [], infos: {} });
  assert.equal(db.read('news_sources', 'a'), null, 'source coupée dans l\'admin');
  assert.ok(db.read('news_sources', 'c'));
  assert.equal(db.read('news', 'vieux'), null);
});

test('admin : état des sources et réglages enregistrés', async () => {
  const db = new FakeDb();
  const admin = createAdmin({ db, verifyToken: async () => ({ email: 'a@x.fr', email_verified: true }), bootstrap: ['a@x.fr'], tasks: {}, now: () => NOW });
  const call = (action, body) => admin.handle({ action, body: body || {}, authorization: 'Bearer t' });
  const r = await call('actus');
  assert.equal(r.json.actif, true);
  assert.ok(r.json.sources.find((s) => s.id === 'africatopsports').actif);
  assert.equal(r.json.sources.find((s) => s.id === 'rmcsport').actif, false);
  await call('actus-save', { actif: true, sources: { rmcsport: true, afrikfoot: false, inconnue: true } });
  const r2 = (await call('actus')).json;
  assert.equal(r2.sources.find((s) => s.id === 'rmcsport').actif, true);
  assert.equal(r2.sources.find((s) => s.id === 'afrikfoot').actif, false);
  assert.ok(!db.read('config', 'news').sources.inconnue);
});
