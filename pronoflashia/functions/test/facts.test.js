'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeDb } = require('./helpers/fakeDb');
const F = require('../src/news/facts');
const { syncNews } = require('../src/jobs/syncNews');
const { actuOf } = require('../src/jobs/buildPredictions');
const { matchDelta, mergeDelta, summarize } = require('../src/engine/bilan');
const { buildSample } = require('../dev/sample');
const { route } = require('../src/render/router');
const D = require('../src/render/data');

const C1 = [{ id: '81', nom: 'Marseille' }];
const C2 = [{ id: '81', nom: 'Marseille' }, { id: '85', nom: 'PSG' }];
const art = (titre, resume = '') => ({ titre, resume, lang: 'fr' });
const prov = (reply, calls = []) => ({ name: 'workers-ai', call: async (m) => { calls.push(m); return typeof reply === 'function' ? reply(m) : reply; } });

test('détection : blessure, suspension, retour, entraîneur, en français et en anglais ; hésitation → rumeur', () => {
  assert.deepEqual(F.detectTypes('Marseille : Mbappé blessé à la cuisse, forfait pour dimanche'), ['absence']);
  assert.deepEqual(F.detectTypes('Lens : Danso suspendu pour deux matchs'), ['suspension']);
  assert.deepEqual(F.detectTypes('Lyon : Lacazette de retour à l\'entraînement'), ['retour']);
  assert.deepEqual(F.detectTypes('Nice : l\'entraîneur limogé'), ['entraineur']);
  assert.deepEqual(F.detectTypes('Flick encense le prochain adversaire'), [], 'le mot « entraîneur » seul n\'est pas un changement d\'entraîneur');
  assert.deepEqual(F.detectTypes('Une victoire au retour des vacances'), [], '« retour » seul n\'est pas un retour de joueur');
  assert.deepEqual(F.detectTypes('Gasperini confirme la tuile pour Koné'), ['absence']);
  assert.deepEqual(F.detectTypes('Arsenal: Saka ruled out for a month'), ['absence']);
  assert.deepEqual(F.detectTypes('Marseille : un match nul contre Lyon'), []);
  assert.equal(F.hedges('Mbappé blessé ?'), true);
  assert.equal(F.hedges('Selon L\'Équipe, Mbappé forfait'), true);
  assert.equal(F.hedges('Mbappé forfait pour dimanche'), false);
});

test('validation de la réponse de l\'IA : JSON strict, équipe de la liste, type appuyé par le texte, joueur présent dans le texte', () => {
  const input = { titre: 'Marseille : Mbappé blessé, forfait contre le PSG', resume: '', candidates: C2 };
  const ok = F.validate('Voici : {"equipe":"Marseille","type":"absence","joueur":"Mbappé"}', input);
  assert.deepEqual(ok, { equipeId: '81', equipe: 'Marseille', type: 'absence', joueur: 'Mbappé', certitude: 'confirme', methode: 'ia' });
  // joueur inventé : ignoré, le fait reste
  assert.equal(F.validate('{"equipe":"Marseille","type":"absence","joueur":"Neymar"}', input).joueur, null);
  // équipe qui n'est pas dans la liste, type sans appui dans le texte, type inconnu, JSON cassé : rejet
  assert.equal(F.validate('{"equipe":"Barcelone","type":"absence","joueur":null}', input), null);
  assert.equal(F.validate('{"equipe":"Marseille","type":"suspension","joueur":null}', input), null);
  assert.equal(F.validate('{"equipe":"Marseille","type":"transfert","joueur":null}', input), null);
  assert.equal(F.validate('{"equipe":"Marseille","type":"aucun","joueur":null}', input), null);
  assert.equal(F.validate('pas du json', input), null);
  assert.equal(F.validate(null, input), null);
  // un texte rassurant n'est jamais présenté comme une absence, même si l'IA le classe ainsi
  assert.equal(F.validate('{"equipe":"Marseille","type":"absence","joueur":null}', { titre: 'Marseille : Mbappé, des nouvelles rassurantes après sa blessure', resume: '', candidates: C2 }), null);
  assert.equal((F.fallback({ titre: 'Marseille : Mbappé touché mais sans gravité', resume: '', candidates: C1 })), null);
  // l'hésitation du texte l'emporte sur la réponse de l'IA
  const hedge = { titre: 'Marseille : Mbappé forfait contre le PSG ?', resume: '', candidates: C2 };
  assert.equal(F.validate('{"equipe":"Marseille","type":"absence","joueur":"Mbappé"}', hedge).certitude, 'rumeur');
});

test('lecture d\'un article : pas de mot-clé → aucun appel à l\'IA ; IA en panne → repli par règles (équipe unique, type unique, sans joueur)', async () => {
  const calls = [];
  const p = prov('{"equipe":"Marseille","type":"absence","joueur":"Mbappé"}', calls);
  const none = await F.extractFact(art('Marseille : le calendrier de la saison'), C1, [p]);
  assert.deepEqual(none, { fait: null, appel: false });
  assert.equal(calls.length, 0, 'aucun appel inutile');
  const r = await F.extractFact(art('Marseille : Mbappé blessé'), C1, [p]);
  assert.equal(r.appel, true);
  assert.equal(r.fait.joueur, 'Mbappé');
  const down = { name: 'workers-ai', call: async () => { throw Object.assign(new Error('quota'), { retryable: true }); } };
  const fb = await F.extractFact(art('Marseille : Mbappé blessé'), C1, [down]);
  assert.equal(fb.fait.methode, 'regles');
  assert.equal(fb.fait.joueur, null);
  assert.equal(fb.fait.type, 'absence');
  // deux équipes dans le titre et IA en panne : on ne devine pas
  assert.equal((await F.extractFact(art('Marseille - PSG : un joueur blessé'), C2, [down])).fait, null);
  // l'IA répond « aucun » : on la croit, pas de repli
  assert.equal((await F.extractFact(art('Marseille : blessure imaginaire du chat'), C1, [prov('{"equipe":null,"type":"aucun","joueur":null}')])).fait, null);
});

const RSS = (items) => `<rss><channel>${items.map((i, n) => `<item><title>${i}</title><link>https://exemple.fr/a${n}</link><pubDate>Fri, 16 Oct 2026 10:00:00 GMT</pubDate><description>Résumé ${n}</description></item>`).join('')}</channel></rss>`;
const feed = (xml) => async () => ({ ok: true, status: 200, text: async () => xml });
const NOW = new Date('2026-10-16T12:00:00Z');

test('syncNews : un fait par article utile, stocké avec l\'article ; plafond d\'appels à l\'IA par passage ; sans IA, repli par règles', async () => {
  const db = new FakeDb();
  await db.seed('matches', 'm1', { id: 'm1', coupDEnvoi: '2026-10-16T19:00:00.000Z', domicile: { teamId: 81, nom: 'Olympique De Marseille', nomCourt: 'Marseille' }, exterieur: { teamId: 85, nom: 'Paris Saint Germain', nomCourt: 'PSG' } });
  const xml = RSS(['Marseille : Mbappé blessé, forfait', 'PSG : Dembélé suspendu', 'Marseille : conférence de presse', 'PSG : Vitinha blessé à la cheville']);
  const calls = [];
  const provider = prov((m) => (/Mbappé/.test(m[1].content) ? '{"equipe":"Marseille","type":"absence","joueur":"Mbappé"}' : '{"equipe":"PSG","type":"suspension","joueur":"Dembélé"}'), calls);
  const SRC = [{ id: 'a', nom: 'Site A', url: 'https://a/feed', lang: 'fr', filtre: null, actif: true }];
  const rep = { traites: 0, erreurs: [], infos: {} };
  await syncNews({ db, now: NOW, fetchImpl: feed(xml), sources: SRC, providers: [provider], maxAiCalls: 2 }, rep);
  const all = db.all('news');
  assert.equal(all.length, 4);
  assert.equal(calls.length, 2, 'plafond de 2 appels');
  assert.equal(rep.infos.appelsIA, 2);
  const withFact = all.filter((n) => n.fait);
  assert.equal(withFact.length, 3, '2 lus par l\'IA + 1 repli par règles (équipe et type uniques)');
  assert.ok(withFact.some((n) => n.fait.methode === 'ia' && n.fait.joueur === 'Mbappé'));
  assert.ok(withFact.some((n) => n.fait.methode === 'regles' && n.fait.equipe === 'PSG'));
  assert.ok(!all.find((n) => /conférence/.test(n.titre)).fait);
  assert.ok(!JSON.stringify(all).includes('Résumé'), 'le résumé de l\'article n\'est pas conservé');
});

test('actualité d\'un match : faits des deux équipes, sans doublon, du plus récent au plus ancien, 4 au plus', () => {
  const match = { domicile: { teamId: 81 }, exterieur: { teamId: 85 } };
  const n = (i, equipeId, type, joueur, date) => ({ source: `S${i}`, lien: `https://x/${i}`, date, fait: { equipeId, equipe: equipeId === '81' ? 'Marseille' : 'PSG', type, joueur, certitude: 'confirme' } });
  const articles = [n(1, '81', 'absence', 'Mbappé', '2026-10-16T08:00:00Z'), n(2, '81', 'absence', 'Mbappé', '2026-10-16T09:00:00Z'), n(3, '85', 'suspension', 'Dembélé', '2026-10-16T07:00:00Z'), n(4, '99', 'absence', 'X', '2026-10-16T10:00:00Z'),
    n(5, '81', 'retour', 'A', '2026-10-15T10:00:00Z'), n(6, '81', 'retour', 'B', '2026-10-15T09:00:00Z'), n(7, '85', 'entraineur', null, '2026-10-14T09:00:00Z')];
  const a = actuOf(articles, match);
  assert.equal(a.faits.length, 4);
  assert.equal(a.faits[0].source, 'S2', 'le plus récent des doublons');
  assert.ok(!a.faits.some((f) => f.equipeId === '99'));
  assert.equal(actuOf([], match), null);
});

test('bilan par signal : actualité, données limitées, aucun signal — mesurés sans rien modifier aux probabilités', () => {
  const mk = (reussi, extra) => ({ leagueId: '1', prono: Object.assign({ principal: { cle: 'res:1', confiance: 60 }, marches: [] }, extra), resultat: { reussi, marches: {} } });
  const d = [
    matchDelta(mk(true, {})), matchDelta(mk(false, { actu: { faits: [{ type: 'absence' }] } })), matchDelta(mk(false, { fragile: { raisons: ['echantillon'] } })),
    matchDelta(mk(true, { fragile: { raisons: ['echantillon'] }, actu: { faits: [{ type: 'retour' }] } })),
  ].reduce((a, b) => mergeDelta(a, b));
  assert.deepEqual(Object.keys(d.parSignal).sort(), ['actu', 'aucun', 'limite']);
  const s = summarize([d]);
  assert.equal(s.parSignal.aucun.n, 1);
  assert.equal(s.parSignal.actu.n, 2);
  assert.equal(s.parSignal.limite.n, 2);
  assert.equal(s.parSignal.actu.taux, 50);
  assert.equal(summarize([]).parSignal && Object.keys(summarize([]).parSignal).length, 0);
});

test('affichage : infos lues par l\'IA avec leur source sur la fiche du match ; tableau des signaux sur le bilan', async () => {
  const NOWR = new Date('2026-10-16T08:00:00Z');
  const db = await buildSample(NOWR);
  const m = db.all('matches').find((x) => x.prono && x.statut === 'prevu');
  const faits = [{ equipeId: String(m.domicile.teamId), equipe: m.domicile.nomCourt, type: 'absence', joueur: 'Jean Dupont', certitude: 'confirme', source: 'Foot Mercato', lien: 'https://exemple.invalid/a', date: '2026-10-16T06:00:00Z' },
    { equipeId: String(m.exterieur.teamId), equipe: m.exterieur.nomCourt, type: 'entraineur', joueur: null, certitude: 'rumeur', source: 'Afrik-Foot', lien: 'https://exemple.invalid/b', date: '2026-10-16T05:00:00Z' }];
  await db.seed('matches', m.id, Object.assign({}, m, { _id: undefined, prono: Object.assign({}, m.prono, { actu: { faits } }) }));
  // signaux : assez de pronostics concernés pour afficher le tableau
  const day = db.all('bilan_days')[0];
  const delta = JSON.parse(JSON.stringify(day.delta));
  delta.parSignal = { aucun: { n: 30, ok: 17, sum: 1800 }, actu: { n: 12, ok: 6, sum: 720 }, limite: { n: 11, ok: 5, sum: 660 } };
  await db.seed('bilan_days', day._id, { jour: day.jour, delta });
  D.clearCache();
  const page = (await route(db, `/football/${m.leagueSlug}/${m.slug}`, NOWR)).body;
  assert.match(page, /Infos récentes sur les équipes/);
  assert.ok(page.includes('🩹 Absence de Jean Dupont signalée côté'));
  assert.ok(page.includes('(à confirmer)'));
  assert.match(page, /href="https:\/\/exemple\.invalid\/a"[^>]*>Foot Mercato<\/a>/);
  assert.match(page, /aucune probabilité n'est modifiée/);
  const en = (await route(db, `/en/football/${m.leagueSlug}/${m.slug}`, NOWR)).body;
  assert.ok(en.includes('Absence of Jean Dupont reported for'));
  const bilan = (await route(db, '/bilan', NOWR)).body;
  assert.match(bilan, /Nos pronostics selon les signaux affichés/);
  assert.match(bilan, /Infos récentes signalées/);
  assert.match(bilan, /Données limitées/);
});
