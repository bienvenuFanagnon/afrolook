'use strict';
// Données d'exemple pour l'aperçu local : une fausse API-Football déterministe alimente la vraie chaîne
// (syncFixtures → buildPredictions → syncResults), donc les pages montrent ce que le site produira vraiment.

const { FakeDb } = require('../test/helpers/fakeDb');
const { runJob, dayStr, addDays } = require('../src/jobs/helpers');
const { syncFixtures } = require('../src/jobs/syncFixtures');
const { buildPredictions } = require('../src/jobs/buildPredictions');
const { syncResults } = require('../src/jobs/syncResults');
const { buildDailyRecap } = require('../src/recap/build');

const LEAGUES = [
  { apiId: 61, nom: 'Ligue 1', slug: 'ligue-1', pays: 'France', ordre: 3, teams: [[85, 'Paris Saint Germain', 2.1], [81, 'Olympique De Marseille', 1.5], [80, 'Olympique Lyonnais', 1.4], [91, 'AS Monaco', 1.45], [79, 'Lille', 1.3], [84, 'Nice', 1.2]] },
  { apiId: 39, nom: 'Premier League', slug: 'premier-league', pays: 'Angleterre', ordre: 4, teams: [[40, 'Liverpool', 1.9], [42, 'Arsenal', 1.85], [50, 'Manchester City', 2.1], [49, 'Chelsea', 1.5]] },
  { apiId: 140, nom: 'LaLiga', slug: 'laliga', pays: 'Espagne', ordre: 5, teams: [[541, 'Real Madrid', 2.05], [529, 'Barcelona', 2.0], [530, 'Atletico Madrid', 1.6], [536, 'Sevilla', 1.2]] },
  { apiId: 135, nom: 'Serie A', slug: 'serie-a', pays: 'Italie', ordre: 6, teams: [[505, 'Inter', 1.8], [496, 'Juventus', 1.5], [489, 'AC Milan', 1.5], [492, 'Napoli', 1.6]] },
  { apiId: 12, nom: 'Ligue des champions CAF', en: 'CAF Champions League', slug: 'ligue-des-champions-caf', pays: 'Afrique', ordre: 1, teams: [[1066, 'Al Ahly', 1.8], [1070, 'Wydad Casablanca', 1.5], [1071, 'TP Mazembe', 1.3], [1072, 'Mamelodi Sundowns', 1.6], [1073, 'Esperance Sportive De Tunis', 1.45], [1074, 'RS Berkane', 1.35]] },
  { apiId: 20, nom: 'Coupe de la CAF', en: 'CAF Confederation Cup', slug: 'coupe-de-la-caf', pays: 'Afrique', ordre: 2, teams: [[1080, 'Zamalek SC', 1.4], [1081, 'USM Alger', 1.3], [1082, 'Enyimba', 1.1], [1083, 'Raja Casablanca', 1.5]] },
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
    for (let r = 0; r < 22; r++) {
      for (let i = 0; i < ids.length; i += 2) {
        const h = ids[(i + r) % ids.length], a = ids[(i + 1 + r * 2) % ids.length];
        if (h === a) continue;
        const d = new Date(state.now.getTime() - (70 - r * 3) * 864e5 + i * 3600e3);
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
    if (/^You are an English/.test(messages[0].content)) {
      const sel = get(/^Selected prediction/);
      const analyse = [get(/^Calculated probabilities/), ...lines.filter((l) => /per game|meetings/.test(l)), 'A prediction is only a probability: a single goal can change everything.'].filter(Boolean).slice(0, 6).join(' ');
      return JSON.stringify({ analyse, pointsCles: [sel, get(/^Calculated probabilities/), get(/^Over 2\.5/)], resume: sel });
    }
    const forme = lines.filter((l) => /^Forme récente/.test(l));
    void forme;
    const analyse = [get(/^Probabilités calculées/), ...lines.filter((l) => /par match à domicile|par match à l'extérieur|confrontations/.test(l)), 'Un pronostic reste une probabilité : un seul but peut tout changer.'].filter(Boolean).slice(0, 6).join(' ');
    return JSON.stringify({ analyse, pointsCles: [get(/^Pronostic retenu/), get(/^Probabilités calculées/), get(/^Plus de 2,5/)], resume: get(/^Pronostic retenu/) });
  },
};

/** Construit la base d'exemple à l'instant `now`. */
async function buildSample(now = new Date()) {
  const db = new FakeDb();
  for (const lg of LEAGUES) await db.seed('leagues', String(lg.apiId), { apiId: lg.apiId, nom: lg.nom, noms: { fr: lg.nom, en: lg.en || lg.nom }, slug: lg.slug, pays: lg.pays, saison: 2026, suivi: true, sport: 'football', ordre: lg.ordre });
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
    // chaque matin, les coupons du jour sont enregistrés (puis réglés au passage suivant) : l'historique des coupons se construit comme en vrai
    const matin = new Date(Date.UTC(t.getUTCFullYear(), t.getUTCMonth(), t.getUTCDate(), 7, 0));
    await runJob(db, 'buildPredictions', (r) => buildPredictions({ db, api, providers: prov, now: matin, maxMatches: 200, maxExternal: 4 }, r), () => matin);
  }
  api.state.now = now;
  await runJob(db, 'syncResults', (r) => syncResults({ db, api, now, maxStats: 80 }, r), () => now);
  await runJob(db, 'syncFixtures', (r) => syncFixtures({ db, api, now, days: 7, forceSeason: true }, r), () => now);
  await runJob(db, 'buildPredictions', (r) => buildPredictions({ db, api, providers: prov, now, maxMatches: 200, maxExternal: 6 }, r), () => now);
  await seedNews(db, now);
  // « Le point foot » du jour : sans IA dans l'aperçu (article de secours construit avec nos données)
  await buildDailyRecap({ db, providers: [], now });
  await db.seed('config', 'site', { email: 'contact@pronoflashia.com', editeur: 'À renseigner', statutJuridique: 'À renseigner', adresse: 'À renseigner' });
  return db;
}

/** Actualités fictives : titres d'exemple rattachés aux équipes des prochains matchs (aperçu seulement). */
async function seedNews(db, now) {
  const up = db.all('matches').filter((m) => m.statut === 'prevu').sort((a, b) => (a.coupDEnvoi < b.coupDEnvoi ? -1 : 1)).slice(0, 9);
  const T = (m, i) => (i ? m.exterieur : m.domicile);
  const src = [['Africa Top Sports', 'fr'], ['Afrik-Foot', 'fr'], ['Foot Mercato', 'fr'], ['Africanews', 'en']];
  const titres = [
    (m) => `${T(m, 0).nomCourt} : le groupe retenu pour recevoir ${T(m, 1).nomCourt}`,
    (m) => `${T(m, 1).nomCourt} : le point sur l'infirmerie avant le déplacement`,
    (m) => `Avant ${T(m, 0).nomCourt} - ${T(m, 1).nomCourt} : chaîne et heure du match`,
    (m) => `${T(m, 1).nomCourt} reaches the next round after a tense night`,
  ];
  // une info lue par l'IA sur le premier match (aperçu seulement)
  if (up[0]) {
    const m = up[0];
    await db.seed('matches', m.id, Object.assign({}, m, { _id: undefined, prono: Object.assign({}, m.prono, { actu: { faits: [
      { equipeId: String(m.domicile.teamId), equipe: m.domicile.nomCourt, type: 'absence', joueur: 'Jean Dupont', certitude: 'confirme', source: 'Foot Mercato', lien: 'https://exemple.invalid/fait1', date: now.toISOString() },
      { equipeId: String(m.exterieur.teamId), equipe: m.exterieur.nomCourt, type: 'entraineur', joueur: null, certitude: 'rumeur', source: 'Afrik-Foot', lien: 'https://exemple.invalid/fait2', date: now.toISOString() },
    ] } }) }));
  }
  let n = 0;
  for (const m of up) {
    for (let k = 0; k < 2; k++) {
      const [source, lang] = src[(n + k) % 4];
      const id = `n${n}`;
      await db.seed('news', id, { id, titre: lang === 'en' ? titres[3](m) : titres[(n + k) % 3](m), lien: `https://exemple.invalid/${id}`, resume: lang === 'en' ? 'A longer excerpt of the story, as published in the source feed. It gives the main facts of the news and the context around them, so that the reader knows what it is about before opening the original article on the source site.' : "Un extrait plus long de l'actualité, tel que publié dans le flux de la source. Il donne les faits principaux de l'information et le contexte autour, pour que le lecteur sache de quoi il s'agit avant d'ouvrir l'article d'origine sur le site de la source.", source, sourceId: 'x', lang, image: n % 3 === 2 ? null : (n % 2 ? '/img/afl4.jpg' : '/img/afl1.jpg'), video: n % 4 === 1, videoId: n % 4 === 1 ? 'dQw4w9WgXcQ' : null, date: new Date(now.getTime() - (n * 45 + 20) * 60e3).toISOString(), teamIds: [String(T(m, k).teamId)] });
      n++;
    }
  }
}

/** Statistiques de visite fictives (aperçu de l'administration) : 14 jours, 4 semaines, état de l'IA. */
async function seedStats(db, now) {
  const r = rng(42);
  for (let i = 13; i >= 0; i--) {
    const jour = new Date(now.getTime() - i * 864e5).toISOString().slice(0, 10);
    const k = 0.6 + r() * 0.8 + (13 - i) * 0.05;
    const n = (x) => Math.round(x * k);
    await db.seed('stats_days', jour, {
      jour, visites: n(420), pv: n(1350), hllEst: { 0: n(24), 1: n(26), 2: n(22), 3: n(25), 4: n(23), 5: n(27), 6: n(21), 7: n(24), 8: n(25), 9: n(22), 10: n(26), 11: n(23), 12: n(24), 13: n(22), 14: n(25), 15: n(23) },
      pages: { accueil: n(380), match: n(520), analyse: n(240), jour: n(110), ligue: n(40), coupon: n(45), bilan: n(15) },
      pays: { CI: n(150), FR: n(70), SN: n(55), CM: n(48), BE: n(20), MA: n(18), '??': n(6) }, paysSource: { fuseau: n(360), inconnu: n(6) },
      appareils: { m: n(330), d: n(70), t: n(10) }, sources: { moteur: n(190), direct: n(110), social: n(80), afrolook: n(25), interne: n(15) },
      heures: { 8: n(30), 12: n(60), 15: n(70), 18: n(90), 19: n(110), 20: n(120), 21: n(80) }, pub: { 'haut_adsterra': n(400), 'native_adsterra': n(250), collante_adsterra: n(300) },
      afl: { liste: n(90), fiche: n(60), colonne: n(40) }, aflClics: { liste: n(4), fiche: n(3) }, aflImps: n(190), clicsAfrolook: n(7), pubVues: n(950), couponAjouts: n(60), partagesWa: n(35), matchs: { '61_100005': n(120), '12_100020': n(90) },
    });
  }
  await db.seed('stats_weeks', '2026-W41', { semaine: '2026-W41', du: '2026-10-05', au: '2026-10-11', visites: 2400, visiteurs: 2050, pagesVues: 7600, clicsAfrolook: 38, pays: [{ k: 'CI', v: 900 }, { k: 'FR', v: 400 }, { k: 'SN', v: 300 }], matchsTop: [{ k: 'Paris SG – Marseille', v: 540 }], pronostics: 68, reussis: 44, rates: 24, tauxReussite: 65, ia: { pannes: 0, controles: 336 } });
  await db.seed('stats_weeks', '2026-W40', { semaine: '2026-W40', du: '2026-09-28', au: '2026-10-04', visites: 2000, visiteurs: 1700, pagesVues: 6700, clicsAfrolook: 30, pays: [{ k: 'CI', v: 760 }], matchsTop: [], pronostics: 61, reussis: 40, rates: 21, tauxReussite: 66, ia: { pannes: 2, controles: 336 } });
  await db.seed('ai_status', 'current', { etat: 'ok', fournisseur: 'workers-ai', dernierTestOk: now.toISOString(), dernierTestLe: now.toISOString(), latenceMs: 1840, generesAujourdhui: 70, secoursAujourdhui: 2, quotaUtilise: 68, derniereErreur: 'gemini : 429', derniereErreurLe: now.toISOString() });
  const hist = {};
  for (let i = 13; i >= 0; i--) { const j = new Date(now.getTime() - i * 864e5).toISOString().slice(0, 10); hist[j] = { appels: 60 + Math.round(r() * 80), erreurs: Math.round(r() * 3), neurons: Math.round(4000 + r() * 6000) }; }
  const j0 = now.toISOString().slice(0, 10);
  await db.seed('connexions', 'workersAi', { jour: j0, appelsJour: hist[j0].appels, erreursJour: hist[j0].erreurs, neuronsJour: 8350, dernierSucces: now.toISOString(), latenceMs: 6100, historique: hist });
  await db.seed('connexions', 'apiFootball', { jour: j0, appelsJour: 46, erreursJour: 0, quotaRestant: 7454, quotaLimite: 7500, dernierSucces: now.toISOString(), historique: Object.fromEntries(Object.keys(hist).map((k) => [k, { appels: 30 + Math.round(r() * 30), erreurs: 0, neurons: 0 }])) });
  for (let i = 0; i < 6; i++) await db.seed('ai_status_log', `l${i}`, { le: new Date(now.getTime() - i * 1800e3).toISOString(), etat: 'ok', fournisseur: 'workers-ai', latenceMs: 1500 + i * 90 });
}

module.exports = { buildSample, seedStats, LEAGUES, demoProvider };
