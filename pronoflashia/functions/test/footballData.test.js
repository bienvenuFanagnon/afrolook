'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const { createClient, toFixture } = require('../src/data/footballData');
const N = require('../src/data/normalize');
const { makeApi, sourceOf } = require('../src/deps');

const MATCH = {
  id: 559669, utcDate: '2026-10-09T18:45:00Z', status: 'FINISHED', matchday: 6, stage: 'REGULAR_SEASON',
  competition: { id: 2015, name: 'Ligue 1' }, season: { startDate: '2026-08-22' },
  homeTeam: { id: 546, name: 'Racing Club de Lens', shortName: 'RC Lens', crest: 'x.png' }, awayTeam: { id: 523, name: 'Olympique Lyonnais', shortName: 'Olympique Lyonnais' },
  score: { winner: 'HOME_TEAM', duration: 'REGULAR', fullTime: { home: 2, away: 1 }, halfTime: { home: 1, away: 0 } },
  referees: [{ name: 'Jeremy Stinat', type: 'REFEREE' }],
};

const reply = (body, status = 200, headers = {}) => ({ ok: status < 400, status, headers: { get: (k) => headers[k.toLowerCase()] ?? null }, text: async () => JSON.stringify(body) });

test('football-data : un match passe par normalizeFixture comme un match API-Football', () => {
  const fx = N.normalizeFixture(toFixture(MATCH));
  assert.equal(fx.apiId, 559669); assert.equal(fx.leagueApiId, 2015); assert.equal(fx.saison, 2026);
  assert.equal(fx.statut, 'termine'); assert.equal(fx.journee, 6); assert.equal(fx.arbitre, 'Jeremy Stinat');
  assert.deepEqual(fx.score, { dom: 2, ext: 1 }); assert.deepEqual(fx.miTemps, { dom: 1, ext: 0 });
  assert.equal(fx.domicile.apiId, 546); assert.equal(fx.domicile.nom, 'RC Lens');
});

test('football-data : statuts, score en direct et temps réglementaire', () => {
  const st = (status, extra) => N.normalizeFixture(toFixture(Object.assign({}, MATCH, { status }, extra)));
  assert.equal(st('TIMED', { score: { fullTime: { home: null, away: null }, halfTime: { home: null, away: null } } }).statut, 'prevu');
  assert.equal(st('TIMED', { score: { fullTime: { home: null, away: null }, halfTime: {} } }).score, null);
  assert.equal(st('IN_PLAY').statut, 'en_cours'); assert.equal(st('PAUSED').statut, 'en_cours');
  assert.equal(st('POSTPONED').statut, 'reporte'); assert.equal(st('CANCELLED').statut, 'reporte');
  // prolongations : on garde le score du temps réglementaire
  const et = st('FINISHED', { score: { duration: 'EXTRA_TIME', regularTime: { home: 1, away: 1 }, fullTime: { home: 2, away: 1 }, halfTime: { home: 0, away: 0 } } });
  assert.deepEqual(et.score, { dom: 1, ext: 1 });
  // phase à élimination : pas de numéro de journée
  const ko = st('TIMED', { matchday: null, stage: 'QUARTER_FINALS' });
  assert.equal(ko.journee, null); assert.equal(ko.round, 'quarter finals');
});

test('football-data : appels, jeton en en-tête, dates, et quota par minute', async () => {
  const calls = [];
  const fetchImpl = async (url, o) => { calls.push({ url, token: o.headers['X-Auth-Token'] }); return reply({ matches: [MATCH] }, 200, { 'x-requests-available-minute': '8', 'x-requestcounter-reset': '42' }); };
  const api = createClient({ key: 'T0K', fetchImpl });
  const up = await api.fixtures({ league: 2015, season: 2026, from: '2026-10-16', to: '2026-10-23' });
  assert.equal(up.length, 1);
  assert.match(calls[0].url, /\/competitions\/2015\/matches\?dateFrom=2026-10-16&dateTo=2026-10-23$/);
  assert.equal(calls[0].token, 'T0K');
  await api.fixtures({ league: 2015, season: 2026 });
  assert.match(calls[1].url, /season=2026$/);
  await api.fixturesByIds([1, 2, 3]);
  assert.match(calls[2].url, /\/matches\?ids=1%2C2%2C3$/);
  assert.equal(api.quota.minuteRemaining, 8); assert.equal(api.quota.dayRemaining, null); assert.equal(api.quota.calls, 3);
  // sans statistiques, cotes ni confrontations : aucune requête
  assert.deepEqual(await api.fixtureStatistics(1), []); assert.deepEqual(await api.odds(1), []); assert.deepEqual(await api.headToHead('1-2'), []);
  assert.equal(calls.length, 3); assert.equal(api.sansStats, true);
});

test('football-data : attend la remise à zéro quand la minute est épuisée, et réessaie après un 429', async () => {
  const waits = [];
  let n = 0;
  const fetchImpl = async () => {
    n++;
    if (n === 1) return reply({ matches: [] }, 200, { 'x-requests-available-minute': '0', 'x-requestcounter-reset': '30' });
    if (n === 2) return reply({ message: 'rate' }, 429, { 'x-requestcounter-reset': '10' });
    return reply({ matches: [MATCH] }, 200, { 'x-requests-available-minute': '9' });
  };
  const api = createClient({ key: 'k', fetchImpl, sleep: async (ms) => { waits.push(ms); } });
  await api.fixtures({ league: 1, season: 2026 });         // épuise la minute
  const r = await api.fixtures({ league: 1, season: 2026 }); // attend 30 s, reçoit 429, attend 10 s, réussit
  assert.equal(r.length, 1); assert.deepEqual(waits, [30500, 10500]);
});

test('football-data : erreurs claires et championnat par identifiant', async () => {
  const bad = createClient({ key: 'k', fetchImpl: async () => reply({ message: 'Your API token is invalid.' }, 400) });
  await assert.rejects(() => bad.fixtures({ league: 1, season: 2026 }), /football-data\.org : Your API token is invalid/);
  const ok = createClient({ key: 'k', fetchImpl: async () => reply({ id: 2015, name: 'Ligue 1', area: { name: 'France' }, currentSeason: { id: 7 }, seasons: [{ id: 6, startDate: '2025-08-15' }, { id: 7, startDate: '2026-08-22' }] }) });
  const [l] = await ok.leagues({ id: 2015 });
  assert.equal(l.league.name, 'Ligue 1'); assert.equal(l.country.name, 'France');
  assert.deepEqual(l.seasons, [{ year: 2025, current: false }, { year: 2026, current: true }]);
});

test('choix de la source de données', () => {
  assert.equal(sourceOf({ footballData: 'a', apiFootball: 'b' }), 'football-data');
  assert.equal(sourceOf({ apiFootball: 'b' }), 'api-football');
  assert.equal(sourceOf({ source: 'api-football', footballData: 'a', apiFootball: 'b' }), 'api-football');
  assert.equal(makeApi({ footballData: 'a' }).sansStats, true);
  assert.notEqual(makeApi({ apiFootball: 'b' }).sansStats, true);
  assert.throws(() => makeApi({}), /manquant/);
  assert.throws(() => makeApi({ source: 'football-data', apiFootball: 'b' }), /FOOTBALL_DATA_TOKEN/);
});

test('premier passage : les championnats par défaut sont ajoutés une seule fois, avec la saison en cours', async () => {
  const { FakeDb } = require('./helpers/fakeDb');
  const { seedDefaultLeagues } = require('../src/jobs/syncFixtures');
  const { DEFAULT_LEAGUES } = require('../src/data/footballData');
  const db = new FakeDb();
  const api = { defaultLeagues: DEFAULT_LEAGUES, leagues: async ({ id }) => [{ league: { id }, seasons: [{ year: 2025, current: false }, { year: 2026, current: true }] }] };
  const report = { erreurs: [], infos: {} };
  assert.equal(await seedDefaultLeagues({ db, api, now: new Date('2026-10-16T05:00:00Z') }, report), 6);
  const l = db.read('leagues', '2015');
  assert.equal(l.saison, 2026); assert.equal(l.suivi, true); assert.equal(l.slug, 'ligue-1'); assert.equal(l.noms.en, 'Ligue 1');
  assert.equal(db.read('leagues', '2014').noms.en, 'La Liga');
  assert.equal(report.infos.championnatsInitialises, 6);
  // une fois les championnats en place (ou retirés par l'admin), rien n'est rajouté
  db.read('leagues', '2015').suivi = false;
  assert.equal(await seedDefaultLeagues({ db, api, now: new Date() }, { erreurs: [], infos: {} }), 0);
  // source sans championnats par défaut (API-Football) : rien
  assert.equal(await seedDefaultLeagues({ db: new FakeDb(), api: {}, now: new Date() }, { erreurs: [], infos: {} }), 0);
});

test('premier passage : les championnats par défaut sont ajoutés une seule fois, avec la saison en cours', async () => {
  const { FakeDb } = require('./helpers/fakeDb');
  const { seedDefaultLeagues } = require('../src/jobs/syncFixtures');
  const { DEFAULT_LEAGUES } = require('../src/data/footballData');
  const db = new FakeDb();
  const api = { defaultLeagues: DEFAULT_LEAGUES, leagues: async ({ id }) => [{ league: { id }, seasons: [{ year: 2025, current: false }, { year: 2026, current: true }] }] };
  const report = { erreurs: [], infos: {} };
  assert.equal(await seedDefaultLeagues({ db, api, now: new Date('2026-10-16T05:00:00Z') }, report), 6);
  const l = db.read('leagues', '2015');
  assert.equal(l.saison, 2026); assert.equal(l.suivi, true); assert.equal(l.slug, 'ligue-1'); assert.equal(l.noms.en, 'Ligue 1');
  assert.equal(db.read('leagues', '2014').noms.en, 'La Liga');
  assert.equal(report.infos.championnatsInitialises, 6);
  // une fois les championnats en place (ou retirés par l'admin), rien n'est rajouté
  assert.equal(await seedDefaultLeagues({ db, api, now: new Date() }, { erreurs: [], infos: {} }), 0);
  // source sans championnats par défaut (API-Football) : rien
  assert.equal(await seedDefaultLeagues({ db: new FakeDb(), api: {}, now: new Date() }, { erreurs: [], infos: {} }), 0);
});
