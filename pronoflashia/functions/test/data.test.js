'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const N = require('../src/data/normalize');
const { createClient, ApiError } = require('../src/data/apiFootball');
const { evaluateMarket, evaluateAll } = require('../src/engine/evaluate');
const B = require('../src/engine/bilan');

const API_FIX = {
  fixture: { id: 1001, referee: 'C. Turpin', date: '2026-10-18T18:45:00+00:00', status: { short: 'NS' } },
  league: { id: 61, season: 2026, round: 'Regular Season - 10' },
  teams: { home: { id: 85, name: 'Paris Saint Germain', logo: 'x' }, away: { id: 81, name: 'Olympique De Marseille', logo: 'y' } },
  goals: { home: null, away: null }, score: { halftime: { home: null, away: null } },
};

test('fixture : statut, journée, noms, date UTC', () => {
  const f = N.normalizeFixture(API_FIX);
  assert.equal(f.apiId, 1001);
  assert.equal(f.statut, 'prevu');
  assert.equal(f.journee, 10);
  assert.equal(f.coupDEnvoi, '2026-10-18T18:45:00.000Z');
  assert.equal(f.score, null);
  assert.equal(f.arbitre, 'C. Turpin');
  const fin = N.normalizeFixture({ ...API_FIX, fixture: { ...API_FIX.fixture, status: { short: 'FT' } }, goals: { home: 2, away: 1 }, score: { halftime: { home: 1, away: 0 } } });
  assert.equal(fin.statut, 'termine');
  assert.deepEqual(fin.score, { dom: 2, ext: 1 });
  assert.deepEqual(fin.miTemps, { dom: 1, ext: 0 });
  for (const [s, k] of [['PST', 'reporte'], ['2H', 'en_cours'], ['AET', 'termine'], ['??', 'prevu']]) assert.equal(N.statutOf(s), k);
});

test('noms : slug sans accent, nom court, journée', () => {
  assert.equal(N.slugify('Ligue des champions CAF'), 'ligue-des-champions-caf');
  assert.equal(N.slugify('Espérance de Tunis'), 'esperance-de-tunis');
  assert.equal(N.shortName('Paris Saint Germain'), 'Paris SG');
  assert.equal(N.shortName('FC Nantes'), 'Nantes');
  assert.equal(N.roundNumber('Quarter-finals'), null);
});

test('statistiques de match : corners, tirs, cartons', () => {
  const out = N.normalizeStatistics([
    { team: { id: 85 }, statistics: [{ type: 'Corner Kicks', value: 7 }, { type: 'Shots on Goal', value: 6 }, { type: 'Total Shots', value: 18 }, { type: 'Fouls', value: 10 }, { type: 'Yellow Cards', value: 2 }, { type: 'Red Cards', value: null }, { type: 'Offsides', value: 3 }, { type: 'Ball Possession', value: '61%' }] },
    { team: { id: 81 }, statistics: [{ type: 'Corner Kicks', value: null }, { type: 'Yellow Cards', value: null }] },
  ]);
  assert.deepEqual(out[85], { corners: 7, shots: 18, shotsOnTarget: 6, fouls: 10, offsides: 3, cards: 2, possession: 61 });
  assert.equal(out[81].corners, null);
  assert.equal(out[81].cards, null);
});

test('cotes : moyenne des bookmakers', () => {
  const resp = [{ bookmakers: [
    { bets: [{ id: 1, values: [{ value: 'Home', odd: '1.50' }, { value: 'Draw', odd: '4.40' }, { value: 'Away', odd: '6.00' }] }, { id: 5, values: [{ value: 'Over 2.5', odd: '1.70' }, { value: 'Under 2.5', odd: '2.10' }] }] },
    { bets: [{ id: 1, values: [{ value: 'Home', odd: '1.60' }, { value: 'Draw', odd: '4.20' }, { value: 'Away', odd: '5.60' }] }] },
  ] }];
  const o = N.normalizeOdds(resp);
  assert.equal(o.home, 1.55); assert.equal(o.draw, 4.3); assert.equal(o.away, 5.8); assert.equal(o.over25, 1.7);
  assert.equal(N.normalizeOdds([]), null);
});

test('historique : forme, buts par lieu, moyennes de comptage', () => {
  const mk = (id, date, venue, gf, ga, stats) => ({ id, date, venue, gf, ga, stats });
  const recent = [
    mk(1, '2026-09-01', 'home', 2, 0, { corners: { f: 7, a: 3 } }),
    mk(2, '2026-09-08', 'away', 1, 1, { corners: { f: 4, a: 6 } }),
    mk(3, '2026-09-15', 'home', 3, 1, null),
    mk(4, '2026-09-22', 'away', 0, 2, { corners: { f: 5, a: 5 } }),
    mk(5, '2026-09-29', 'home', 1, 0, { corners: { f: 9, a: 2 } }),
  ];
  assert.equal(N.formString(recent), 'VNVDV');
  const g = N.goalStats(recent);
  assert.deepEqual(g.home, { games: 3, gf: 6, ga: 1 });
  assert.deepEqual(g.away, { games: 2, gf: 1, ga: 3 });
  assert.equal(g.all.games, 5);
  const c = N.countAverages(recent, 'corners');
  assert.equal(c.for.n, 4);
  assert.equal(c.for.avg, 6.25);
  assert.equal(N.countAverages(recent, 'cards'), null);
  const lg = N.leagueGoalAverages([{ statut: 'termine', score: { dom: 2, ext: 1 } }, { statut: 'termine', score: { dom: 0, ext: 1 } }, { statut: 'prevu', score: null }]);
  assert.deepEqual(lg, { games: 2, avgHome: 1, avgAway: 1 });
});

test('client API : en-tête de clé, quota suivi, erreurs de l\'API traduites', async () => {
  let seen;
  const mkRes = (body, status = 200, headers = {}) => ({ status, ok: status < 400, headers: { get: (k) => headers[k.toLowerCase()] ?? null }, text: async () => JSON.stringify(body) });
  const api = createClient({ key: 'KEY', fetchImpl: async (url, init) => { seen = { url, init }; return mkRes({ errors: [], response: [{ a: 1 }] }, 200, { 'x-ratelimit-requests-remaining': '7421', 'x-ratelimit-requests-limit': '7500' }); } });
  const r = await api.fixtures({ league: 61, season: 2026, from: '2026-10-15', to: '2026-10-22' });
  assert.deepEqual(r, [{ a: 1 }]);
  assert.match(seen.url, /\/fixtures\?league=61&season=2026&from=2026-10-15&to=2026-10-22$/);
  assert.equal(seen.init.headers['x-apisports-key'], 'KEY');
  assert.equal(api.quota.dayRemaining, 7421);
  const bad = createClient({ key: 'K', fetchImpl: async () => mkRes({ errors: { requests: 'You have reached the request limit for the day.' }, response: [] }) });
  await assert.rejects(() => bad.fixtures({}), (e) => e instanceof ApiError && /request limit/.test(e.message));
  const ids = createClient({ key: 'K', fetchImpl: async (u) => { seen = u; return mkRes({ errors: [], response: [] }); } });
  await ids.fixturesByIds([1, 2, 3]);
  assert.match(seen, /ids=1-2-3/);
});

test('évaluation : buts, handicap, remboursé si nul, mi-temps, comptages', () => {
  const ctx = { score: { dom: 2, ext: 1 }, miTemps: { dom: 1, ext: 0 }, stats: { home: { corners: 7, cards: 2, shotsOnTarget: 6 }, away: { corners: 3, cards: 3, shotsOnTarget: 2 } } };
  const t = (k) => evaluateMarket(k, ctx);
  assert.equal(t('res:1'), true);
  assert.equal(t('res:N2'), false);
  assert.equal(t('buts:over:2.5'), true);
  assert.equal(t('buts:btts:oui'), true);
  assert.equal(t('hand:home:-1.5'), false);
  assert.equal(t('hand:away:+1.5'), true);
  assert.equal(t('res:dnb1'), true);
  assert.equal(evaluateMarket('res:dnb1', { score: { dom: 1, ext: 1 } }), null);
  assert.equal(t('mt:1h:lead:home'), true);
  assert.equal(t('mt:1h:over:0.5'), true);
  assert.equal(t('mt:2h:more'), true); // 2 buts en 2e mi-temps contre 1 en 1re
  assert.equal(t('mt:htft:home'), true);
  assert.equal(t('corners:total:9.5'), true);
  assert.equal(t('corners:more:home'), true);
  assert.equal(t('cards:total:4.5'), true);
  assert.equal(t('shotsOnTarget:away:2.5'), false);
  assert.equal(t('score:margin2:home'), false);
  assert.equal(t('score:wtn:home'), false);
  assert.equal(t('spec:penalty'), null);
  assert.equal(evaluateMarket('corners:total:9.5', { score: { dom: 1, ext: 0 } }), null); // pas de statistiques
  const all = evaluateAll([{ cle: 'res:1' }, { cle: 'spec:red' }, { cle: 'corners:total:6.5' }], ctx);
  assert.deepEqual(all, { 'res:1': true, 'corners:total:6.5': true });
});

test('bilan : delta d\'un match, cumul, taux, calibration', () => {
  const mk = (ok, conf, leagueId = '61') => ({
    leagueId,
    prono: { principal: { cle: 'res:1', confiance: conf }, marches: [
      { cle: 'res:1', famille: 'Résultat', pct: conf, fiabilite: 'haute' },
      { cle: 'buts:over:2.5', famille: 'Buts', pct: 62, fiabilite: 'haute' },
      { cle: 'spec:penalty', famille: 'Spéciaux', pct: 26, fiabilite: 'faible' },
    ] },
    resultat: { reussi: ok, marches: { 'res:1': ok, 'buts:over:2.5': true, 'spec:penalty': false } },
  });
  const d1 = B.matchDelta(mk(true, 68));
  assert.equal(d1.principal.ok, 1);
  assert.equal(d1.parFamille.Résultat.n, 1);
  assert.equal(d1.parFamille['Spéciaux'], undefined, 'les paris à fiabilité faible ne comptent pas');
  assert.equal(B.matchDelta({ prono: { principal: {} }, resultat: {} }), null);
  const days = [d1, B.matchDelta(mk(false, 66)), B.matchDelta(mk(true, 72, '39'))];
  const s = B.summarize(days);
  assert.equal(s.n, 3); assert.equal(s.ok, 2); assert.equal(s.ko, 1); assert.equal(s.taux, 67);
  assert.equal(s.parLigue['61'].taux, 50);
  assert.equal(s.parLigue['39'].taux, 100);
  const bin65 = s.bins.find((b) => b.from === 65);
  assert.equal(bin65.n, 2); assert.equal(bin65.reel, 50);
  assert.equal(s.parConfiance.length, 2);
  assert.deepEqual(B.summarize([]).taux, null);
  const r = B.rateByKey(days, 3);
  assert.equal(r['buts-over-2_5'], undefined, 'clé sûre sans point ni deux-points');
  assert.equal(r.buts_over_2_5.reel, 100);
  assert.equal(B.safeKey('buts:over:2.5'), 'buts_over_2_5');
});
