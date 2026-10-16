'use strict';
// Client de l'API éditeur d'Adsterra (lecture seule) : statistiques de revenus par jour et par emplacement.
// Le jeton (ADSTERRA_API_TOKEN) vient de functions/.env ; il ne permet pas de lire les codes publicitaires, seulement les chiffres.

const BASE = 'https://api3.adsterratools.com/publisher';

class AdsterraError extends Error {
  constructor(message, status) { super(message); this.status = status; }
}

function createClient({ token, fetchImpl, base }) {
  const f = fetchImpl || fetch;
  async function get(path, params) {
    const qs = new URLSearchParams();
    for (const [k, v] of Object.entries(params || {})) if (v != null) qs.set(k, String(v));
    const res = await f(`${base || BASE}${path}${qs.toString() ? '?' + qs : ''}`, { headers: { 'X-API-Key': token, Accept: 'application/json' } });
    const text = await res.text();
    let json;
    try { json = JSON.parse(text); } catch { throw new AdsterraError(`Réponse non JSON d'Adsterra (${res.status})`, res.status); }
    if (!res.ok) throw new AdsterraError(`Adsterra : ${json.message || json.error || res.status}`, res.status);
    return json;
  }
  return {
    get,
    /** groupBy : « date » ou « placement ». Dates AAAA-MM-JJ. */
    stats: async ({ start, finish, groupBy }) => (await get('/stats.json', { start_date: start, finish_date: finish, group_by: groupBy })).items || [],
    placements: async () => (await get('/placements.json')).items || [],
  };
}

const num = (v) => { const n = parseFloat(v); return Number.isFinite(n) ? n : 0; };

/** Une ligne de statistiques → { cle, impressions, clics, revenu }. Les noms de champs sont lus avec tolérance. */
function normalizeRow(it, groupBy) {
  const cle = it[groupBy] != null ? it[groupBy] : it.date != null ? it.date : it.placement != null ? it.placement : it.id != null ? it.id : '?';
  return { cle: String(cle), impressions: num(it.impression != null ? it.impression : it.impressions), clics: num(it.clicks != null ? it.clicks : it.click), revenu: num(it.revenue != null ? it.revenue : it.profit) };
}

/** Totaux et CPM moyen (revenu pour 1000 affichages). */
function totals(rows) {
  const t = rows.reduce((a, r) => ({ impressions: a.impressions + r.impressions, clics: a.clics + r.clics, revenu: a.revenu + r.revenu }), { impressions: 0, clics: 0, revenu: 0 });
  return { impressions: t.impressions, clics: t.clics, revenu: Math.round(t.revenu * 1000) / 1000, cpm: t.impressions ? Math.round((t.revenu / t.impressions) * 1000 * 1000) / 1000 : 0 };
}

module.exports = { BASE, AdsterraError, createClient, normalizeRow, totals };
