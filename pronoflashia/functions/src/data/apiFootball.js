'use strict';
// Client API-Football (api-sports.io). La clé vient de Firebase Secrets ; le quota restant est suivi à chaque appel.

const BASE = 'https://v3.football.api-sports.io';

class ApiError extends Error {
  constructor(message, status, errors) { super(message); this.status = status; this.errors = errors || null; }
}

function createClient({ key, fetchImpl, base, onQuota }) {
  const f = fetchImpl || fetch;
  const quota = { dayRemaining: null, dayLimit: null, minuteRemaining: null, calls: 0 };

  async function get(path, params) {
    const qs = new URLSearchParams();
    for (const [k, v] of Object.entries(params || {})) if (v != null) qs.set(k, String(v));
    const url = `${base || BASE}${path}${qs.toString() ? '?' + qs : ''}`;
    const res = await f(url, { headers: { 'x-apisports-key': key } });
    quota.calls++;
    const h = (n) => (res.headers && res.headers.get ? res.headers.get(n) : null);
    if (h('x-ratelimit-requests-remaining') != null) quota.dayRemaining = parseInt(h('x-ratelimit-requests-remaining'), 10);
    if (h('x-ratelimit-requests-limit') != null) quota.dayLimit = parseInt(h('x-ratelimit-requests-limit'), 10);
    if (h('x-ratelimit-remaining') != null) quota.minuteRemaining = parseInt(h('x-ratelimit-remaining'), 10);
    if (onQuota) onQuota(Object.assign({}, quota));
    const text = await res.text();
    let json;
    try { json = JSON.parse(text); } catch { throw new ApiError(`Réponse non JSON (${res.status})`, res.status); }
    // L'API renvoie 200 avec un objet « errors » rempli en cas de problème (clé, quota, paramètre).
    const errs = json.errors && (Array.isArray(json.errors) ? json.errors : Object.values(json.errors));
    if (!res.ok || (errs && errs.length)) throw new ApiError(`API-Football : ${(errs && errs.join(' ')) || res.status}`, res.status, errs);
    return json.response || [];
  }

  return {
    quota,
    get,
    /** Matchs d'un championnat entre deux dates (AAAA-MM-JJ). */
    fixtures: (p) => get('/fixtures', p),
    /** Plusieurs matchs par identifiant (20 au maximum par appel). */
    fixturesByIds: (ids) => get('/fixtures', { ids: ids.slice(0, 20).join('-') }),
    fixtureStatistics: (fixture) => get('/fixtures/statistics', { fixture }),
    odds: (fixture) => get('/odds', { fixture }),
    headToHead: (h2h, last) => get('/fixtures/headtohead', { h2h, last: last || 5 }),
    standings: (league, season) => get('/standings', { league, season }),
    injuries: (fixture) => get('/injuries', { fixture }),
    lineups: (fixture) => get('/fixtures/lineups', { fixture }),
    leagues: (p) => get('/leagues', p),
    status: () => get('/status'),
  };
}

module.exports = { BASE, ApiError, createClient };
