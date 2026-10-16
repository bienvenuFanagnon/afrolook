'use strict';
// Client football-data.org (v4), offre gratuite. Il renvoie les mêmes structures qu'API-Football (fixture / league / teams / goals / score)
// pour que le reste du site (normalize.js, tâches) fonctionne sans changement.
// Offre gratuite : calendriers, scores et mi-temps, 10 appels par minute ; ni statistiques de match, ni cotes, ni compositions.
// Le débit est piloté par les en-têtes de réponse (X-Requests-Available-Minute, X-RequestCounter-Reset).

const BASE = 'https://api.football-data.org/v4';

class ApiError extends Error {
  constructor(message, status, errors) { super(message); this.status = status; this.errors = errors || null; }
}

const STATUS = {
  SCHEDULED: 'NS', TIMED: 'NS', IN_PLAY: 'LIVE', PAUSED: 'HT', EXTRA_TIME: 'ET', PENALTY_SHOOTOUT: 'P',
  FINISHED: 'FT', AWARDED: 'AWD', POSTPONED: 'PST', CANCELLED: 'CANC', SUSPENDED: 'SUSP',
};

/** Un match football-data.org → forme d'un élément de la réponse /fixtures d'API-Football. */
function toFixture(m) {
  const sc = m.score || {};
  // le score de la rencontre est celui du temps réglementaire (les prolongations et tirs au but ne comptent pas pour les paris classiques)
  const ft = sc.regularTime && sc.regularTime.home != null ? sc.regularTime : sc.fullTime || {};
  const ht = sc.halfTime || {};
  const stage = m.stage && m.stage !== 'REGULAR_SEASON' ? m.stage.replace(/_/g, ' ').toLowerCase() : 'Regular Season';
  const comp = m.competition || {};
  const ref = (m.referees || []).find((r) => r.type === 'REFEREE') || (m.referees || [])[0];
  const team = (t) => ({ id: t && t.id, name: (t && (t.shortName || t.name)) || null, logo: (t && t.crest) || null });
  return {
    fixture: { id: m.id, date: m.utcDate, status: { short: STATUS[m.status] || 'NS' }, referee: ref ? ref.name : null, venue: null },
    league: { id: comp.id, season: m.season && m.season.startDate ? parseInt(m.season.startDate.slice(0, 4), 10) : null, round: m.matchday != null ? `${stage} - ${m.matchday}` : stage },
    teams: { home: team(m.homeTeam), away: team(m.awayTeam) },
    goals: { home: ft.home == null ? null : ft.home, away: ft.away == null ? null : ft.away },
    score: { halftime: { home: ht.home == null ? null : ht.home, away: ht.away == null ? null : ht.away } },
  };
}

/**
 * key : jeton personnel (Firebase Secrets). fetchImpl / sleep : injectables pour les tests.
 * onQuota reçoit l'état du quota après chaque appel.
 */
function createClient({ key, fetchImpl, base, onQuota, sleep }) {
  const f = fetchImpl || fetch;
  const wait = sleep || ((ms) => new Promise((r) => setTimeout(r, ms)));
  // Pas de limite par jour : seulement par minute. dayRemaining/dayLimit restent nuls (l'admin affiche « inconnu » ou rien).
  const quota = { dayRemaining: null, dayLimit: null, minuteRemaining: null, calls: 0, source: 'football-data' };
  let resetSec = 60;

  async function get(path, params, retried) {
    // fenêtre épuisée : on attend la remise à zéro annoncée par le serveur (60 s au plus) plutôt que de provoquer un refus
    if (quota.minuteRemaining != null && quota.minuteRemaining <= 0) { await wait(Math.min(resetSec, 60) * 1000 + 500); quota.minuteRemaining = null; }
    const qs = new URLSearchParams();
    for (const [k, v] of Object.entries(params || {})) if (v != null) qs.set(k, String(v));
    const res = await f(`${base || BASE}${path}${qs.toString() ? '?' + qs : ''}`, { headers: { 'X-Auth-Token': key } });
    quota.calls++;
    const h = (n) => (res.headers && res.headers.get ? res.headers.get(n) : null);
    if (h('x-requests-available-minute') != null) quota.minuteRemaining = parseInt(h('x-requests-available-minute'), 10);
    if (h('x-requestcounter-reset') != null) resetSec = parseInt(h('x-requestcounter-reset'), 10) || 60;
    if (onQuota) onQuota(Object.assign({}, quota));
    const text = await res.text();
    let json;
    try { json = JSON.parse(text); } catch { throw new ApiError(`Réponse non JSON (${res.status})`, res.status); }
    if (res.status === 429 && !retried) { await wait(Math.min(resetSec, 60) * 1000 + 500); quota.minuteRemaining = null; return get(path, params, true); }
    if (!res.ok) throw new ApiError(`football-data.org : ${json.message || res.status}`, res.status, json.message ? [json.message] : null);
    return json;
  }

  return {
    quota,
    sansStats: true, // pas de statistiques de match ni de cotes avec cette offre
    get,
    /** Matchs d'un championnat : entre deux dates (10 jours au plus) ou toute une saison. */
    fixtures: async (p) => {
      const params = p.from || p.to ? { dateFrom: p.from, dateTo: p.to } : { season: p.season };
      const json = await get(`/competitions/${p.league}/matches`, params);
      return (json.matches || []).map(toFixture);
    },
    fixturesByIds: async (ids) => {
      const json = await get('/matches', { ids: ids.slice(0, 20).join(',') });
      return (json.matches || []).map(toFixture);
    },
    // Non fournis par l'offre gratuite : réponses vides, sans appel (économise les 10 appels par minute).
    fixtureStatistics: async () => [],
    odds: async () => [],
    headToHead: async () => [],
    injuries: async () => [],
    lineups: async () => [],
    standings: async () => [],
    /** Un championnat par identifiant (forme d'API-Football : league, country, seasons). */
    leagues: async (p) => {
      const c = await get(`/competitions/${p.id}`);
      if (!c || !c.id) return [];
      const seasons = (c.seasons || []).map((s) => ({ year: parseInt(String(s.startDate).slice(0, 4), 10), current: !!(c.currentSeason && s.id === c.currentSeason.id) }));
      return [{ league: { id: c.id, name: c.name }, country: { name: c.area && c.area.name }, seasons }];
    },
    status: async () => get('/competitions'),
  };
}

module.exports = { BASE, ApiError, createClient, toFixture, STATUS };
