'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { FakeDb } = require('./helpers/fakeDb');
const { runJob, isoWeek, mondayOf } = require('../src/jobs/helpers');
const { syncFixtures } = require('../src/jobs/syncFixtures');
const { buildPredictions } = require('../src/jobs/buildPredictions');
const { syncResults } = require('../src/jobs/syncResults');
const { aiHealthCheck } = require('../src/jobs/aiHealth');
const { weeklyReport, buildWeekReport } = require('../src/jobs/weeklyReport');
const { summarize } = require('../src/engine/bilan');

const TEAMS = { 85: 'Paris Saint Germain', 81: 'Olympique De Marseille', 80: 'Olympique Lyonnais', 91: 'AS Monaco' };
const raw = (id, h, a, date, short, goals, ht) => ({
  fixture: { id, referee: null, date, status: { short } },
  league: { id: 61, season: 2026, round: 'Regular Season - 10' },
  teams: { home: { id: h, name: TEAMS[h] }, away: { id: a, name: TEAMS[a] } },
  goals: goals ? { home: goals[0], away: goals[1] } : { home: null, away: null },
  score: { halftime: ht ? { home: ht[0], away: ht[1] } : { home: null, away: null } },
});

/** Historique de saison : chaque équipe joue 10 matchs terminés, Paris domine. */
function seasonFixtures() {
  const ids = [85, 81, 80, 91];
  const out = [];
  let n = 5000;
  for (let r = 0; r < 10; r++) {
    for (let i = 0; i < 4; i++) {
      const h = ids[i], a = ids[(i + 1 + (r % 3)) % 4];
      if (h === a) continue;
      const gh = h === 85 ? 2 + (r % 2) : (r + i) % 3;
      const ga = a === 85 ? 1 : (r + i + 1) % 2;
      out.push(raw(n++, h, a, `2026-09-${String(1 + r * 2).padStart(2, '0')}T18:00:00+00:00`, 'FT', [gh, ga], [Math.min(gh, 1), 0]));
    }
  }
  return out;
}

function mockApi({ upcoming, result, statsOk = true } = {}) {
  const calls = [];
  return {
    calls, quota: { dayRemaining: 7000 },
    async fixtures(p) { calls.push(['fixtures', p]); return p.from ? upcoming : seasonFixtures(); },
    async fixturesByIds(ids) { calls.push(['byIds', ids]); return [result]; },
    async fixtureStatistics(id) {
      calls.push(['stats', id]);
      if (!statsOk) throw new Error('stats indisponibles');
      return [
        { team: { id: 85 }, statistics: [{ type: 'Corner Kicks', value: 7 }, { type: 'Shots on Goal', value: 6 }, { type: 'Total Shots', value: 15 }, { type: 'Fouls', value: 10 }, { type: 'Yellow Cards', value: 1 }, { type: 'Offsides', value: 2 }] },
        { team: { id: 81 }, statistics: [{ type: 'Corner Kicks', value: 3 }, { type: 'Shots on Goal', value: 2 }, { type: 'Total Shots', value: 8 }, { type: 'Fouls', value: 12 }, { type: 'Yellow Cards', value: 3 }, { type: 'Offsides', value: 1 }] },
      ];
    },
    async odds(id) { calls.push(['odds', id]); return [{ bookmakers: [{ bets: [{ id: 1, values: [{ value: 'Home', odd: '1.55' }, { value: 'Draw', odd: '4.40' }, { value: 'Away', odd: '5.60' }] }] }] }]; },
    async headToHead() { calls.push(['h2h']); return [raw(4001, 85, 81, '2026-03-10T20:00:00+00:00', 'FT', [2, 1], [1, 0]), raw(4002, 81, 85, '2025-10-10T20:00:00+00:00', 'FT', [0, 0], [0, 0])]; },
  };
}

/** Fournisseur qui renvoie un JSON valide fabriqué à partir des faits du prompt (donc sans chiffre inventé). */
const echoProvider = (name = 'workers-ai') => ({
  name,
  async call(messages) {
    const lines = messages[1].content.split('\n').filter((l) => l.startsWith('- ')).map((l) => l.slice(2));
    const pick = (re) => lines.find((l) => re.test(l));
    const en = /^You are an English/.test(messages[0].content);
    const probs = pick(en ? /^Calculated probabilities/ : /^Probabilités/);
    const goals = pick(en ? /^Over 2\.5/ : /^Plus de 2,5/);
    const sel = pick(en ? /^Selected prediction/ : /^Pronostic retenu/);
    return JSON.stringify({
      analyse: [probs, ...lines.filter((l) => /par match|per game|confrontations|meetings/.test(l)), sel].filter(Boolean).slice(0, 5).join(' '),
      pointsCles: [probs, goals, sel],
      resume: sel,
    });
  },
});

const UPCOMING = [raw(1001, 85, 81, '2026-10-18T18:45:00+00:00', 'NS')];
const LEAGUE = { apiId: 61, nom: 'Ligue 1', slug: 'ligue-1', pays: 'France', saison: 2026, suivi: true, sport: 'football', ordre: 1 };
const NOW = new Date('2026-10-15T08:00:00Z');

async function setup() {
  const db = new FakeDb();
  await db.seed('leagues', '61', LEAGUE);
  const api = mockApi({ upcoming: UPCOMING });
  await runJob(db, 'syncFixtures', (rep) => syncFixtures({ db, api, now: NOW }, rep), () => NOW);
  return { db, api };
}

test('syncFixtures : matchs, équipes, historique de saison, compte-rendu', async () => {
  const { db, api } = await setup();
  const m = db.read('matches', '61_1001');
  assert.equal(m.statut, 'prevu');
  assert.equal(m.slug, 'paris-sg-marseille-2026-10-18');
  assert.equal(m.leagueNom, 'Ligue 1');
  assert.equal(m.domicile.nomCourt, 'Paris SG');
  assert.equal(m.domicile.couleurs.length, 2);
  assert.equal(m.journee, 10);
  assert.ok(db.read('teams', '85'));
  const form = db.read('team_form', '85');
  assert.ok(form.recent.length >= 8);
  assert.ok(db.read('leagues', '61').avg.avgHome > 0);
  const job = db.read('jobs', '_dernier_syncFixtures');
  assert.equal(job.ok, true); assert.equal(job.traites, 1);
  assert.equal(api.calls.filter((c) => c[0] === 'fixtures').length, 2); // matchs à venir + saison
  // deuxième passage dans la journée : l'historique n'est pas redemandé
  await runJob(db, 'syncFixtures', (rep) => syncFixtures({ db, api, now: new Date(NOW.getTime() + 3600e3) }, rep));
  assert.equal(api.calls.filter((c) => c[0] === 'fixtures').length, 3);
});

test('syncFixtures : un changement d\'horaire force le recalcul du pronostic', async () => {
  const { db } = await setup();
  await db.seed('matches', '61_1001', Object.assign(db.read('matches', '61_1001'), { prono: { calculeLe: '2026-10-15T08:00:00Z', aRecalculer: false } }));
  const moved = mockApi({ upcoming: [raw(1001, 85, 81, '2026-10-18T20:00:00+00:00', 'NS')] });
  await runJob(db, 'syncFixtures', (rep) => syncFixtures({ db, api: moved, now: NOW }, rep));
  assert.equal(db.read('matches', '61_1001').prono.aRecalculer, true);
});

test('syncFixtures : quota épuisé → erreur enregistrée, rien d\'écrit', async () => {
  const db = new FakeDb();
  await db.seed('leagues', '61', LEAGUE);
  const api = mockApi({ upcoming: UPCOMING }); api.quota.dayRemaining = 10;
  const rep = await runJob(db, 'syncFixtures', (r) => syncFixtures({ db, api, now: NOW }, r));
  assert.ok(rep.erreurs[0].includes('Quota'));
  assert.equal(db.read('matches', '61_1001'), null);
  assert.equal(db.read('jobs', '_dernier_syncFixtures').ok, false);
});

test('buildPredictions : pronostic complet, texte de l\'IA, état de l\'IA, pas de recalcul inutile', async () => {
  const { db, api } = await setup();
  const rep = await runJob(db, 'buildPredictions', (r) => buildPredictions({ db, api, providers: [echoProvider()], now: NOW }, r));
  assert.equal(rep.traites, 1, rep.erreurs.join());
  const p = db.read('matches', '61_1001').prono;
  assert.ok(p.principal.confiance >= 1 && p.principal.libelle);
  assert.equal(p.probas['1'] + p.probas.N + p.probas['2'], 100);
  assert.ok(p.marches.length > 40);
  assert.equal(p.matrice.length, 7);
  assert.equal(p.sourceTexte, 'workers-ai');
  assert.ok(p.texte.analyse.length > 100 && p.texte.pointsCles.length === 3);
  assert.equal(p.visible, true);
  assert.equal(p.source, 'stats', 'match à plus de 48 h : pas de cotes demandées');
  assert.match(p.formeDom, /^[VND]{1,5}$/);
  assert.ok(p.comparatif.some((c) => c.cle === 'buts_marques'));
  assert.ok(db.read('matches', '61_1001').h2h.length === 2);
  assert.equal(p.sourceTexteEn, 'workers-ai');
  assert.ok(/per game|probabilities/.test(p.texteEn.analyse), 'analyse anglaise');
  const ai = db.read('ai_status', 'current');
  assert.equal(ai.generesAujourdhui, 2, 'un texte français + un texte anglais'); assert.equal(ai.fournisseur, 'workers-ai'); assert.equal(ai.secoursAujourdhui, 0);
  const calls = api.calls.length;
  const rep2 = await runJob(db, 'buildPredictions', (r) => buildPredictions({ db, api, providers: [echoProvider()], now: new Date(NOW.getTime() + 600e3) }, r));
  assert.equal(rep2.traites, 0);
  assert.equal(api.calls.length, calls);
});

test('buildPredictions : IA en panne → texte de secours, le match a quand même son pronostic', async () => {
  const { db, api } = await setup();
  const down = (n) => ({ name: n, call: async () => { throw new Error('indisponible'); } });
  const rep = await runJob(db, 'buildPredictions', (r) => buildPredictions({ db, api, providers: [down('workers-ai'), down('gemini')], now: NOW }, r));
  assert.equal(rep.traites, 1);
  const p = db.read('matches', '61_1001').prono;
  assert.equal(p.sourceTexte, 'secours');
  assert.ok(p.texte.analyse.length > 100);
  const ai = db.read('ai_status', 'current');
  assert.equal(ai.secoursAujourdhui, 2);
  assert.equal(p.sourceTexteEn, 'secours');
  assert.match(p.texteEn.analyse, /The model gives/);
  assert.match(ai.derniereErreur, /indisponible/);
});

test('buildPredictions : un pronostic masqué par l\'admin le reste après recalcul', async () => {
  const { db, api } = await setup();
  await runJob(db, 'buildPredictions', (r) => buildPredictions({ db, api, providers: [echoProvider()], now: NOW }, r));
  await db.seed('matches', '61_1001', Object.assign(db.read('matches', '61_1001'), {}));
  const cur = db.read('matches', '61_1001');
  cur.prono.masque = true; cur.prono.visible = false; cur.prono.aRecalculer = true;
  await db.seed('matches', '61_1001', cur);
  await runJob(db, 'buildPredictions', (r) => buildPredictions({ db, api, providers: [echoProvider()], now: new Date(NOW.getTime() + 3600e3) }, r));
  assert.equal(db.read('matches', '61_1001').prono.visible, false);
});

test('syncResults : score, réussi / raté, historique des équipes, bilan, idempotence', async () => {
  const { db, api } = await setup();
  await runJob(db, 'buildPredictions', (r) => buildPredictions({ db, api, providers: [echoProvider()], now: NOW }, r));
  const after = new Date('2026-10-18T21:00:00Z');
  const apiR = mockApi({ result: raw(1001, 85, 81, '2026-10-18T18:45:00+00:00', 'FT', [2, 1], [1, 0]) });
  const rep = await runJob(db, 'syncResults', (r) => syncResults({ db, api: apiR, now: after }, r), () => after);
  assert.equal(rep.traites, 1, rep.erreurs.join());
  const m = db.read('matches', '61_1001');
  assert.equal(m.statut, 'termine');
  assert.equal(m.resultat.scoreDom, 2);
  assert.equal(typeof m.resultat.reussi, 'boolean');
  assert.equal(m.resultat.compte, true);
  assert.equal(m.resultat.marches['buts:over:2.5'], true);
  assert.equal(m.resultat.marches['res:1'], true);
  assert.equal(m.resultat.marches['corners:total:9.5'], undefined, 'pas de pari corners calculé sans historique de comptage');
  assert.equal(m.resultat.stats.home.corners, 7);
  const day = db.read('bilan_days', '2026-10-18');
  assert.equal(day.delta.principal.n, 1);
  assert.equal(summarize([day.delta]).n, 1);
  const form = db.read('team_form', '85').recent.find((e) => e.id === 1001);
  assert.deepEqual(form.stats.corners, { f: 7, a: 3 });
  const form81 = db.read('team_form', '81').recent.find((e) => e.id === 1001);
  assert.deepEqual(form81.stats.corners, { f: 3, a: 7 });
  // deuxième passage : pas de double comptage
  await runJob(db, 'syncResults', (r) => syncResults({ db, api: apiR, now: new Date(after.getTime() + 1800e3) }, r));
  assert.equal(db.read('bilan_days', '2026-10-18').delta.principal.n, 1);
});

test('syncResults : statistiques indisponibles → on réessaie, bilan figé après 3 tentatives', async () => {
  const { db, api } = await setup();
  await runJob(db, 'buildPredictions', (r) => buildPredictions({ db, api, providers: [echoProvider()], now: NOW }, r));
  const t = (min) => new Date(new Date('2026-10-18T21:00:00Z').getTime() + min * 60e3);
  const apiR = mockApi({ result: raw(1001, 85, 81, '2026-10-18T18:45:00+00:00', 'FT', [2, 1], [1, 0]), statsOk: false });
  await runJob(db, 'syncResults', (r) => syncResults({ db, api: apiR, now: t(0) }, r));
  assert.equal(db.read('matches', '61_1001').resultat.compte, false);
  assert.equal(db.read('bilan_days', '2026-10-18'), null);
  await runJob(db, 'syncResults', (r) => syncResults({ db, api: apiR, now: t(30) }, r));
  await runJob(db, 'syncResults', (r) => syncResults({ db, api: apiR, now: t(60) }, r));
  const m = db.read('matches', '61_1001');
  assert.equal(m.resultat.compte, true);
  assert.equal(db.read('bilan_days', '2026-10-18').delta.principal.n, 1);
  assert.equal(m.resultat.marches['corners:total:9.5'], undefined, 'pari de comptage non évalué sans statistiques');
});

test('aiHealthCheck : ok, lent, panne', async () => {
  const db = new FakeDb();
  const good = { name: 'workers-ai', call: async () => '{"ok":true}' };
  const bad = { name: 'gemini', call: async () => { throw new Error('403'); } };
  let r = { traites: 0, erreurs: [], infos: {} };
  assert.equal(await aiHealthCheck({ db, providers: [good, bad], now: NOW }, r), 'ok');
  assert.equal(db.read('ai_status', 'current').fournisseur, 'workers-ai');
  assert.equal(db.read('ai_status', 'current').providers.gemini.ok, false);
  r = { traites: 0, erreurs: [], infos: {} };
  assert.equal(await aiHealthCheck({ db, providers: [bad, good], now: new Date(NOW.getTime() + 1000) }, r), 'ok');
  assert.equal(db.read('ai_status', 'current').fournisseur, 'workers-ai', 'bascule sur le secours');
  r = { traites: 0, erreurs: [], infos: {} };
  assert.equal(await aiHealthCheck({ db, providers: [bad], now: new Date(NOW.getTime() + 2000) }, r), 'panne');
  assert.equal(r.erreurs.length, 1);
  assert.equal(db.all('ai_status_log').length, 3);
});

test('semaines ISO et rapport hebdomadaire', async () => {
  assert.equal(isoWeek(new Date('2026-10-15T00:00:00Z')), '2026-W42');
  assert.equal(isoWeek(new Date('2026-01-01T00:00:00Z')), '2026-W01');
  assert.equal(mondayOf(new Date('2026-10-15T10:00:00Z')).toISOString().slice(0, 10), '2026-10-12');
  const rep = buildWeekReport({
    week: '2026-W41', from: '2026-10-05',
    statsDays: [{ visites: 100, hllEst: { 0: 50.2, 1: 29.9 }, pv: 300, pays: { CI: 60, FR: 30 }, matchs: { a: 40, b: 10 }, clicsAfrolook: 5 }, { visites: 50, visiteurs: 40, pv: 120, pays: { CI: 20, SN: 10 }, matchs: { a: 5 } }, null],
    bilanDays: [{ delta: { matches: 1, principal: { n: 1, ok: 1 }, parLigue: {}, parConfiance: {}, parFamille: {}, parBin: {}, parCle: {} } }],
    aiLog: [{ etat: 'ok' }, { etat: 'panne' }],
  });
  assert.equal(rep.visites, 150); assert.equal(rep.visiteurs, 120); assert.equal(rep.pagesVues, 420); assert.equal(rep.au, '2026-10-11');
  assert.deepEqual(rep.pays[0], { k: 'CI', v: 80 });
  assert.equal(rep.matchsTop[0].k, 'a');
  assert.equal(rep.tauxReussite, 100); assert.equal(rep.ia.pannes, 1);
  const db = new FakeDb();
  await db.seed('stats_days', '2026-10-06', { visites: 10, visiteurs: 8, pv: 20 });
  const r2 = { traites: 0, erreurs: [], infos: {} };
  await weeklyReport({ db, now: new Date('2026-10-12T03:00:00Z') }, r2);
  assert.equal(r2.infos.semaine, '2026-W41');
  assert.equal(db.read('stats_weeks', '2026-W41').visites, 10);
});

test('buildPredictions : à moins de 48 h, les cotes sont demandées et recalent le modèle', async () => {
  const { db, api } = await setup();
  const near = new Date('2026-10-17T10:00:00Z');
  const rep = await runJob(db, 'buildPredictions', (r) => buildPredictions({ db, api, providers: [echoProvider()], now: near }, r));
  assert.equal(rep.traites, 1, rep.erreurs.join());
  const m = db.read('matches', '61_1001');
  assert.equal(m.prono.source, 'stats+cotes');
  assert.equal(m.cotes.home, 1.55);
  assert.ok(api.calls.some((c) => c[0] === 'odds'));
});

test('buildPredictions : quota presque épuisé → pas de requêtes facultatives, le calcul continue', async () => {
  const { db, api } = await setup();
  api.quota.dayRemaining = 20;
  const near = new Date('2026-10-17T10:00:00Z');
  const rep = await runJob(db, 'buildPredictions', (r) => buildPredictions({ db, api, providers: [echoProvider()], now: near }, r));
  assert.equal(rep.traites, 1);
  assert.ok(!api.calls.some((c) => c[0] === 'odds' || c[0] === 'h2h'));
  assert.equal(db.read('matches', '61_1001').prono.source, 'stats');
});

test('buildPredictions : recalcul sans changement notable → textes réutilisés, aucun appel à l\'IA', async () => {
  const { db, api } = await setup();
  let calls = 0;
  const prov = { name: 'workers-ai', call: async (m) => { calls++; return echoProvider().call(m); } };
  await runJob(db, 'buildPredictions', (r) => buildPredictions({ db, api, providers: [prov], now: NOW }, r));
  assert.equal(calls, 2);
  const cur = db.read('matches', '61_1001'); cur.prono.aRecalculer = true; await db.seed('matches', '61_1001', cur);
  const rep = await runJob(db, 'buildPredictions', (r) => buildPredictions({ db, api, providers: [prov], now: new Date(NOW.getTime() + 3600e3) }, r));
  assert.equal(rep.traites, 1);
  assert.equal(calls, 2, 'aucun nouvel appel');
  assert.equal(db.read('matches', '61_1001').prono.texteEn.analyse, cur.prono.texteEn.analyse);
  // un texte de secours est toujours retenté
  const c2 = db.read('matches', '61_1001'); c2.prono.sourceTexteEn = 'secours'; c2.prono.aRecalculer = true; await db.seed('matches', '61_1001', c2);
  await runJob(db, 'buildPredictions', (r) => buildPredictions({ db, api, providers: [prov], now: new Date(NOW.getTime() + 7200e3) }, r));
  assert.equal(calls, 3, 'seul le texte anglais est redemandé');
});

test('buildPredictions : langues réglables (français seul)', async () => {
  const { db, api } = await setup();
  await runJob(db, 'buildPredictions', (r) => buildPredictions({ db, api, providers: [echoProvider()], now: NOW, langs: ['fr'] }, r));
  const p = db.read('matches', '61_1001').prono;
  assert.ok(p.texte && p.texteEn === null);
});
