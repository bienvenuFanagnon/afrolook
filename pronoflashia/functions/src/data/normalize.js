'use strict';
// Normalisation des réponses d'API-Football (api-sports.io, v3) vers notre modèle.

const STATUS = {
  prevu: ['TBD', 'NS'],
  en_cours: ['1H', 'HT', '2H', 'ET', 'BT', 'P', 'SUSP', 'INT', 'LIVE'],
  termine: ['FT', 'AET', 'PEN', 'AWD', 'WO'],
  reporte: ['PST', 'CANC', 'ABD'],
};

function statutOf(short) {
  for (const [k, list] of Object.entries(STATUS)) if (list.includes(short)) return k;
  return 'prevu';
}

/** « Paris Saint Germain » → « paris-saint-germain » */
function slugify(s) {
  return String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase()
    .replace(/&/g, ' et ').replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
}

/** Nom court d'affichage : retire les préfixes et suffixes de club courants. */
function shortName(name) {
  const n = String(name || '').trim();
  const map = { 'Paris Saint Germain': 'Paris SG', 'Paris Saint-Germain': 'Paris SG', 'Olympique De Marseille': 'Marseille', 'Olympique Marseille': 'Marseille', 'Olympique Lyonnais': 'Lyon', 'AS Monaco': 'Monaco', 'Manchester City': 'Man City', 'Manchester United': 'Man United' };
  if (map[n]) return map[n];
  if (/^Esperance Sportive De Tunis$/i.test(n)) return 'Espérance de Tunis';
  const cleaned = n.replace(/^(FC|AS|AC|SC|RC|OGC|US|CF|RS|SK|FK|CD|UD)\s+/i, '').replace(/\s+(FC|CF|SC|AFC)$/i, '').trim();
  return cleaned.length >= 3 ? cleaned : n;
}

/** Journée à partir de « Regular Season - 10 » ; null pour les phases à élimination. */
function roundNumber(round) {
  const m = /(\d+)\s*$/.exec(String(round || ''));
  return m ? parseInt(m[1], 10) : null;
}

/** Un élément de la réponse /fixtures. */
function normalizeFixture(it) {
  const f = it.fixture || {};
  const l = it.league || {};
  const t = it.teams || {};
  const g = it.goals || {};
  const sc = it.score || {};
  const date = new Date(f.date);
  return {
    apiId: f.id,
    leagueApiId: l.id,
    saison: l.season,
    round: l.round || null,
    journee: roundNumber(l.round),
    coupDEnvoi: date.toISOString(),
    statut: statutOf(f.status && f.status.short),
    statutApi: f.status && f.status.short,
    arbitre: f.referee || null,
    lieu: f.venue && f.venue.name ? { nom: f.venue.name, ville: f.venue.city || null } : null,
    domicile: { apiId: t.home && t.home.id, nom: t.home && t.home.name, logo: (t.home && t.home.logo) || null },
    exterieur: { apiId: t.away && t.away.id, nom: t.away && t.away.name, logo: (t.away && t.away.logo) || null },
    score: g.home == null || g.away == null ? null : { dom: g.home, ext: g.away },
    miTemps: sc.halftime && sc.halftime.home != null ? { dom: sc.halftime.home, ext: sc.halftime.away } : null,
  };
}

/** Chiffres de comptage d'une équipe à partir de /fixtures/statistics. */
function normalizeStatistics(response) {
  const out = {};
  for (const row of response || []) {
    const id = row.team && row.team.id;
    const by = {};
    for (const s of row.statistics || []) by[s.type] = s.value;
    const num = (k) => (by[k] == null ? null : parseFloat(String(by[k]).replace('%', '')));
    const yellow = num('Yellow Cards') || 0;
    const red = num('Red Cards') || 0;
    out[id] = {
      corners: num('Corner Kicks'),
      shots: num('Total Shots'),
      shotsOnTarget: num('Shots on Goal'),
      fouls: num('Fouls'),
      offsides: num('Offsides'),
      cards: num('Yellow Cards') == null && num('Red Cards') == null ? null : yellow + red,
      possession: num('Ball Possession'),
    };
  }
  return out;
}

/** Cotes moyennes (jusqu'à 5 bookmakers) : 1N2 et plus/moins de 2,5 buts. */
function normalizeOdds(response) {
  const books = ((response && response[0] && response[0].bookmakers) || []).slice(0, 5);
  const acc = { home: [], draw: [], away: [], over25: [], under25: [] };
  for (const b of books) {
    for (const bet of b.bets || []) {
      if (bet.id === 1) {
        for (const v of bet.values || []) {
          const o = parseFloat(v.odd);
          if (v.value === 'Home') acc.home.push(o); else if (v.value === 'Draw') acc.draw.push(o); else if (v.value === 'Away') acc.away.push(o);
        }
      }
      if (bet.id === 5) {
        for (const v of bet.values || []) {
          const o = parseFloat(v.odd);
          if (v.value === 'Over 2.5') acc.over25.push(o); else if (v.value === 'Under 2.5') acc.under25.push(o);
        }
      }
    }
  }
  const avg = (a) => (a.length ? Math.round((a.reduce((x, y) => x + y, 0) / a.length) * 100) / 100 : null);
  const out = { home: avg(acc.home), draw: avg(acc.draw), away: avg(acc.away), over25: avg(acc.over25), under25: avg(acc.under25) };
  return out.home && out.draw && out.away ? out : null;
}

/** Entrée d'historique d'équipe (un match terminé). */
function recentEntry(fix, venue) {
  const dom = venue === 'home';
  return {
    id: fix.apiId,
    date: fix.coupDEnvoi,
    venue,
    opp: dom ? fix.exterieur.nom : fix.domicile.nom,
    gf: dom ? fix.score.dom : fix.score.ext,
    ga: dom ? fix.score.ext : fix.score.dom,
  };
}

const sumField = (arr, f) => arr.reduce((s, x) => s + (x[f] || 0), 0);

/** Blocs {games, gf, ga} par lieu et au total, sur les n derniers matchs. */
function goalStats(recent, n = 20) {
  const list = recent.slice().sort((a, b) => (a.date < b.date ? 1 : -1)).slice(0, n);
  const block = (arr) => ({ games: arr.length, gf: sumField(arr, 'gf'), ga: sumField(arr, 'ga') });
  return { home: block(list.filter((x) => x.venue === 'home')), away: block(list.filter((x) => x.venue === 'away')), all: block(list) };
}

/** Forme « VVNVD » (du plus ancien au plus récent) sur les n derniers matchs. */
function formString(recent, n = 5) {
  const list = recent.slice().sort((a, b) => (a.date < b.date ? 1 : -1)).slice(0, n).reverse();
  return list.map((x) => (x.gf > x.ga ? 'V' : x.gf === x.ga ? 'N' : 'D')).join('');
}

/** Moyenne pour / contre d'un comptage sur les matchs où la statistique est connue. */
function countAverages(recent, kind, n = 10) {
  const list = recent.filter((x) => x.stats && x.stats[kind] && x.stats[kind].f != null && x.stats[kind].a != null)
    .sort((a, b) => (a.date < b.date ? 1 : -1)).slice(0, n);
  if (!list.length) return null;
  const f = list.reduce((s, x) => s + x.stats[kind].f, 0) / list.length;
  const a = list.reduce((s, x) => s + x.stats[kind].a, 0) / list.length;
  return { for: { avg: f, n: list.length }, against: { avg: a, n: list.length } };
}

/** Moyennes de buts de la ligue à partir des matchs terminés. */
function leagueGoalAverages(fixtures) {
  const done = fixtures.filter((f) => f.statut === 'termine' && f.score);
  if (!done.length) return null;
  return {
    games: done.length,
    avgHome: Math.round((done.reduce((s, f) => s + f.score.dom, 0) / done.length) * 100) / 100,
    avgAway: Math.round((done.reduce((s, f) => s + f.score.ext, 0) / done.length) * 100) / 100,
  };
}

module.exports = { safeLogo,
  statutOf, slugify, shortName, roundNumber, normalizeFixture, normalizeStatistics, normalizeOdds,
  recentEntry, goalStats, formString, countAverages, leagueGoalAverages,
};

/** Adresse de logo acceptée : https et hôtes des fournisseurs de données seulement (jamais d'adresse arbitraire dans les pages). */
const LOGO_HOSTS = /^(crests\.football-data\.org|media(-\d)?\.api-sports\.io|upload\.wikimedia\.org)$/;
function safeLogo(u) {
  try { const x = new URL(String(u)); return x.protocol === 'https:' && LOGO_HOSTS.test(x.hostname) ? x.href : null; } catch { return null; }
}

/** Couleurs d'écusson déterministes à partir du nom (pas de logo officiel). */
function teamColors(name) {
  let h = 0;
  for (const c of String(name || '')) h = (h * 31 + c.charCodeAt(0)) >>> 0;
  const hue = h % 360;
  const hsl = (hh, s, l) => {
    const a = (s * Math.min(l, 100 - l)) / 10000;
    const f = (n) => { const k = (n + hh / 30) % 12; const c = l / 100 - a * Math.max(-1, Math.min(k - 3, 9 - k, 1)); return Math.round(255 * c).toString(16).padStart(2, '0'); };
    return `#${f(0)}${f(8)}${f(4)}`;
  };
  return [hsl(hue, 62, 38), hsl((hue + 28) % 360, 70, 26)];
}

/** Initiales d'un écusson : 3 lettres au plus. */
function initials(name) {
  const w = String(name || '').replace(/[^A-Za-zÀ-ÿ0-9 ]/g, ' ').split(/\s+/).filter(Boolean);
  if (!w.length) return '?';
  if (w.length === 1) return w[0].slice(0, 3).toUpperCase();
  return w.slice(0, 3).map((x) => x[0]).join('').toUpperCase();
}

module.exports.teamColors = teamColors;
module.exports.initials = initials;
