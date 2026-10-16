'use strict';
// Données d'exemple pour l'aperçu local : une fausse API-Football déterministe alimente la vraie chaîne
// (syncFixtures → buildPredictions → syncResults), donc les pages montrent ce que le site produira vraiment.

const { FakeDb } = require('../test/helpers/fakeDb');
const { runJob, dayStr, addDays } = require('../src/jobs/helpers');
const { syncFixtures } = require('../src/jobs/syncFixtures');
const { buildPredictions } = require('../src/jobs/buildPredictions');
const { syncResults } = require('../src/jobs/syncResults');

const LEAGUES = [
  { apiId: 61, nom: 'Ligue 1', slug: 'ligue-1', pays: 'France', ordre: 3, teams: [[85, 'Paris Saint Germain', 2.1], [81, 'Olympique De Marseille', 1.5], [80, 'Olympique Lyonnais', 1.4], [91, 'AS Monaco', 1.45], [79, 'Lille', 1.3], [84, 'Nice', 1.2]] },
  { apiId: 39, nom: 'Premier League', slug: 'premier-league', pays: 'Angleterre', ordre: 4, teams: [[40, 'Liverpool', 1.9], [42, 'Arsenal', 1.85], [50, 'Manchester City', 2.1], [49, 'Chelsea', 1.5]] },
  { apiId: 140, nom: 'LaLiga', slug: 'laliga', pays: 'Espagne', ordre: 5, teams: [[541, 'Real Madrid', 2.05], [529, 'Barcelona', 2.0], [530, 'Atletico Madrid', 1.6], [536, 'Sevilla', 1.2]] },
  { apiId: 135, nom: 'Serie A', slug: 'serie-a', pays: 'Italie', ordre: 6, teams: [[505, 'Inter', 1.8], [496, 'Juventus', 1.5], [489, 'AC Milan', 1.5], [492, 'Napoli', 1.6]] },
  { apiId: 12, nom: 'Ligue des champions CAF', slug: 'ligue-des-champions-caf', pays: 'Afrique', ordre: 1, teams: [[1066, 'Al Ahly', 1.8], [1070, 'Wydad Casablanca', 1.5], [1071, 'TP Mazembe', 1.3], [1072, 'Mamelodi Sundowns', 1.6], [1073, 'Esperance Sportive De Tunis', 1.45], [1074, 'RS Berkane', 1.35]] },
  { apiId: 20, nom: 'Coupe de la CAF', slug: 'coupe-de-la-caf', pays: 'Afrique', ordre: 2, teams: [[1080, 'Zamalek SC', 1.4], [1081, 'USM Alger', 1.3], [1082, 'Enyimba', 1.1], [1083, 'Raja Casablanca', 1.5]] },
];

function rng(seed) {
  let a = seed >>> 0;
  return () => { a += 0x6D2B79F5; let t = a; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}
function poisson(r, lam) { const L = Math.exp(-lam); let k = 0, p = 1; do { k++; p *= r(); } while (p > L); return k - 1; }

/** Fausse API : matchs de saison passés et à venir, résultats simulés de façon déterministe. */
function makeApi(mockNow) {
  const state = { now: mockNow, fixtures: new Map(), calls: 0 };
  const strength = new Map(LEAGUES.flatMap((l) => l.teams.map(([id, , s]) => [id, s])));
  const nameOf = new Map(LEAGUES.flatMap((l) => l.teams.map(([id, n]) => [id, n])));
  const mk = (lg, id, h, a, date) => ({ apiId: id, lg, h, a, date });
  let nextId = 100000;
  // historique : 14 matchs terminés par championnat espacés de 3 jours avant le début de la fenêtre
  for (const lg of LEAGUES) {
    const ids = lg.teams.map((t) => t[0]);
    for (let r = 0; r < 12; r++) {
      for (let i = 0; i < ids.length; i += 2) {
        const h = ids[(i + r) % ids.length], a = ids[(i + 1 + r * 2) % ids.length];
        if (h === a) continue;
        const d = new Date(state.now.getTime() - (40 - r * 3) * 864e5 + i * 3600e3);
        state.fixtures.set(nextId, mk(lg, nextId, h, a, d)); nextId++;
      }
    }
    // à venir et récents : une journée par jour de J-2 à J+4
    for (let day = -2; day <= 4; day++) {
      const pairs = [];
      const sh = ids.slice().sort(() => 0);
      for (let i = 0; i + 1 < sh.length; i += 2) pairs.push([sh[(i + day + 6) % sh.length], sh[(i + 1 + day * 3 + 6) % sh.length]]);
      pairs.forEach(([h, a], k) => {
        if (h === a) return;
        const d = new Date(Date.UTC(state.now.getUTCFullYear(), state.now.getUTCMonth(), state.now.getUTCDate() + day, [15, 17, 18, 19, 20, 21][(lg.apiId + k + day + 12) % 6], [0, 30, 45, 0][(k + 2) % 4]));
        state.fixtures.set(nextId, mk(lg, nextId, h, a, d)); nextId++;
      });
    }
  }
  const result = (f) => {
    const r = rng(f.apiId * 7919);
    const sh = strength.get(f.h), sa = strength.get(f.a);
    const gh = poisson(r, 1.25 * (sh / sa) ** 0.7 + 0.1), ga = poisson(r, 1.0 * (sa / sh) ** 0.7);
    const ht = [Math.min(gh, poisson(r, gh * 0.45)), 0]; ht[1] = Math.min(ga, poisson(r, ga * 0.45));
    return { gh, ga, ht };
  };
  const raw = (f) => {
    const finished = f.date.getTime() + 105 * 60e3 <= state.now.getTime();
    const res = finished ? result(f) : null;
    return {
      fixture: { id: f.apiId, referee: finished ? null : ['C. Turpin', 'M. Oliver', 'D. Orsato', 'B. Ndiaye'][f.apiId % 4], venue: { name: `Stade de ${nameOf.get(f.h).split(' ').pop()}`, city: null }, date: f.date.toISOString(), status: { short: finished ? 'FT' : 'NS' } },
      league: { id: f.lg.apiId, season: 2026, round: `Regular Season - ${10 + (f.apiId % 3)}` },
      teams: { home: { id: f.h, name: nameOf.get(f.h) }, away: { id: f.a, name: nameOf.get(f.a) } },
      goals: res ? { home: res.gh, away: res.ga } : { home: null, away: null },
      score: { halftime: res ? { home: res.ht[0], away: res.ht[1] } : { home: null, away: null } },
    };
  };
  const stat = (teamId, fixId, opp) => {
    const r = rng(fixId * 31 + teamId);
    const s = strength.get(teamId) / strength.get(opp);
    return { team: { id: teamId }, statistics: [
      { type: 'Corner Kicks', value: poisson(r, 4.6 * s ** 0.5) }, { type: 'Shots on Goal', value: poisson(r, 4.2 * s ** 0.6) }, { type: 'Total Shots', value: poisson(r, 11.5 * s ** 0.5) },
      { type: 'Fouls', value: poisson(r, 11.5) }, { type: 'Yellow Cards', value: poisson(r, 1.9) }, { type: 'Red Cards', value: r() < 0.04 ? 1 : null }, { type: 'Offsides', value: poisson(r, 2) },
    ] };
  };
  const api = {
    quota: { dayRemaining: 7000 }, state,
    async fixtures(p) {
      const all = [...state.fixtures.values()].filter((f) => f.lg.apiId === Number(p.league));
      const list = p.from ? all.filter((f) => f.date.toISOString().slice(0, 10) >= p.from && f.date.toISOString().slice(0, 10) <= p.to) : all;
      return list.map(raw);
    },
    async fixturesByIds(ids) { return ids.map((i) => state.fixtures.get(i)).filter(Boolean).map(raw); },
    async fixtureStatistics(id) { const f = state.fixtures.get(id); return [stat(f.h, id, f.a), stat(f.a, id, f.h)]; },
    async odds(id) {
      const f = state.fixtures.get(id); const sh = strength.get(f.h), sa = strength.get(f.a);
      const ph = 0.38 + 0.2 * Math.log(sh / sa), pa = 0.3 - 0.15 * Math.log(sh / sa), pd = 1 - ph - pa;
      const o = (p) => (Math.round((1 / Math.max(0.08, p)) * 0.94 * 100) / 100).toFixed(2);
      return [{ bookmakers: [{ bets: [{ id: 1, values: [{ value: 'Home', odd: o(ph) }, { value: 'Draw', odd: o(pd) }, { value: 'Away', odd: o(pa) }] }] }] }];
    },
    async headToHead(pair) {
      const [h, a] = pair.split('-').map(Number);
      return [0, 1, 2, 3].map((k) => { const r = rng(h * 13 + a * 17 + k); const gh = poisson(r, 1.5), ga = poisson(r, 1.1); const sw = k % 2; return { fixture: { id: 90000 + k + h, date: new Date(state.now.getTime() - (120 + k * 150) * 864e5).toISOString(), status: { short: 'FT' } }, league: { id: 0, season: 2025 }, teams: { home: { id: sw ? a : h, name: nameOf.get(sw ? a : h) }, away: { id: sw ? h : a, name: nameOf.get(sw ? h : a) } }, goals: { home: gh, away: ga }, score: { halftime: { home: 0, away: 0 } } }; });
    },
  };
  return api;
}

/** Fournisseur d'IA de démonstration : reformule les faits du prompt (aucun chiffre inventé). */
const demoProvider = {
  name: 'workers-ai',
  async call(messages) {
    const lines = messages[1].content.split('\n').filter((l) => l.startsWith('- ')).map((l) => l.slice(2));
    const get = (re) => lines.find((l) => re.test(l));
    const forme = lines.filter((l) => /^Forme récente/.test(l));
    void forme;
    const analyse = [get(/^Probabilités calculées/), ...lines.filter((l) => /par match à domicile|par match à l'extérieur|confrontations/.test(l)), 'Un pronostic reste une probabilité : un seul but peut tout changer.'].filter(Boolean).slice(0, 6).join(' ');
    return JSON.stringify({ analyse, pointsCles: [get(/^Pronostic retenu/), get(/^Probabilités calculées/), get(/^Plus de 2,5/)], resume: get(/^Pronostic retenu/) });
  },
};

/** Construit la base d'exemple à l'instant `now`. */
async function buildSample(now = new Date()) {
  const db = new FakeDb();
  for (const lg of LEAGUES) await db.seed('leagues', String(lg.apiId), { apiId: lg.apiId, nom: lg.nom, slug: lg.slug, pays: lg.pays, saison: 2026, suivi: true, sport: 'football', ordre: lg.ordre });
  const api = makeApi(now);
  const start = new Date(now.getTime() - 3 * 864e5);
  const prov = [demoProvider];
  // 1) il y a 3 jours : matchs connus et pronostics calculés avant les rencontres
  api.state.now = start;
  await runJob(db, 'syncFixtures', (r) => syncFixtures({ db, api, now: start, forceSeason: true, days: 8 }, r), () => start);
  // l'historique de comptage (corners, tirs…) : syncResults l'alimente match après match ; on le prépare pour les 40 derniers jours
  for (const f of [...api.state.fixtures.values()].filter((x) => x.date < start)) {
    const stats = await api.fixtureStatistics(f.apiId);
    const N = require('../src/data/normalize');
    const by = N.normalizeStatistics(stats);
    for (const [teamId, venue, oppId] of [[f.h, 'home', f.a], [f.a, 'away', f.h]]) {
      const ref = db.collection('team_form').doc(String(teamId));
      const cur = (await ref.get()).data();
      if (!cur) continue;
      const e = cur.recent.find((x) => x.id === f.apiId);
      if (!e) continue;
      e.stats = {};
      for (const k of ['corners', 'shots', 'shotsOnTarget', 'fouls', 'cards', 'offsides']) if (by[teamId][k] != null && by[oppId][k] != null) e.stats[k] = { f: by[teamId][k], a: by[oppId][k] };
      await ref.set(cur);
    }
  }
  await runJob(db, 'syncFixtures', (r) => syncFixtures({ db, api, now: start, forceSeason: true, days: 8 }, r), () => start);
  await runJob(db, 'buildPredictions', (r) => buildPredictions({ db, api, providers: prov, now: start, maxMatches: 200, maxExternal: 4 }, r), () => start);
  // 2) maintenant : résultats des matchs passés, puis nouveaux pronostics
  for (const step of [1, 2, 3]) {
    const t = new Date(start.getTime() + step * 864e5);
    api.state.now = t;
    await runJob(db, 'syncResults', (r) => syncResults({ db, api, now: t, maxStats: 80 }, r), () => t);
  }
  api.state.now = now;
  await runJob(db, 'syncResults', (r) => syncResults({ db, api, now, maxStats: 80 }, r), () => now);
  await runJob(db, 'syncFixtures', (r) => syncFixtures({ db, api, now, days: 7, forceSeason: true }, r), () => now);
  await runJob(db, 'buildPredictions', (r) => buildPredictions({ db, api, providers: prov, now, maxMatches: 200, maxExternal: 6 }, r), () => now);
  await db.seed('config', 'site', { email: 'contact@pronoflashia.com', editeur: 'À renseigner', statutJuridique: 'À renseigner', adresse: 'À renseigner' });
  return db;
}

module.exports = { buildSample, LEAGUES, demoProvider };
