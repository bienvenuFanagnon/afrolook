'use strict';
// Routeur : chemin → page HTML (ou sitemap, robots, ads.txt), en français (/) ou en anglais (/en/).
// Utilisé par la fonction Firebase et par l'aperçu local.

const fs = require('fs');
const nodePath = require('path');
const D = require('./data');
const P = require('./pages');
const { legalPage } = require('./legal');
const C = require('./components');
const { T, pathFor, parsePath } = require('./i18n');
const { rateByKey, summarize } = require('../engine/bilan');
const { dayStr, addDays } = require('../jobs/helpers');
const { esc } = require('../util/format');

const CSS = fs.readFileSync(nodePath.join(__dirname, 'style.css'), 'utf8').replace(/\s*\n\s*/g, '\n');
const VERSION = (() => { try { return require('crypto').createHash('md5').update(CSS).digest('hex').slice(0, 8); } catch { return '1'; } })();

const HTML = 'text/html; charset=utf-8';
const cc = (s, swr) => `public, max-age=60, s-maxage=${s}, stale-while-revalidate=${swr || s * 2}`;
const reply = (status, body, type, cache, extra) => ({ status, body, headers: Object.assign({ 'Content-Type': type || HTML, 'Cache-Control': cache || 'public, max-age=0, s-maxage=60' }, extra || {}) });

/** Contexte de rendu partagé par toutes les pages d'une langue. */
async function context(db, now, lang = 'fr') {
  const [cfg, leagues] = await Promise.all([D.loadConfig(db), D.loadLeagues(db)]);
  const today = dayStr(now);
  const tomorrow = dayStr(addDays(now, 1));
  return {
    now, lang, t: T[lang], site: cfg.site, ads: cfg.ads, leagues, css: CSS, version: VERSION, today, tomorrow,
    dayAliases: { [today]: 'aujourdhui', [tomorrow]: 'demain' },
    u: (name, arg) => pathFor(lang, name, arg),
    pathIn: (l, name, arg) => pathFor(l, name, arg),
  };
}

const page = (rc, p, cache) => reply(p.status || 200, C.html(rc, p), HTML, cache);
const redirect = (to) => ({ status: 301, headers: { Location: to, 'Cache-Control': 'public, max-age=3600' }, body: '' });
const notFound = (rc) => reply(404, C.html(rc, P.notFound(rc)), HTML, 'public, max-age=0, s-maxage=60');

async function route(db, urlPath, now = new Date()) {
  let path = String(urlPath || '/').split('?')[0].replace(/\/{2,}/g, '/');
  if (path.length > 1 && path.endsWith('/')) path = path.slice(0, -1);
  path = path.toLowerCase();

  if (path === '/robots.txt' || path === '/ads.txt' || path === '/sitemap.xml') {
    const rc = await context(db, now);
    if (path === '/robots.txt') {
      const body = rc.site.indexable ? `User-agent: *\nAllow: /\nDisallow: /admin\nDisallow: /api/\nSitemap: ${rc.site.origine}/sitemap.xml\n` : 'User-agent: *\nDisallow: /\n';
      return reply(200, body, 'text/plain; charset=utf-8', cc(3600));
    }
    if (path === '/ads.txt') return reply(200, (rc.ads.adsTxt || '').trim() + '\n', 'text/plain; charset=utf-8', cc(600));
    return sitemap(db, rc);
  }

  const r = parsePath(path);
  const rc = await context(db, now, r.lang);

  switch (r.name) {
    case 'home': {
      const matches = await homeMatches(db, rc);
      return page(rc, P.home(rc, { matches, bilan: await D.bilan30(db, now) }), cc(300, 600));
    }
    case 'football': return redirect(rc.u('day', 'aujourdhui'));
    case 'bilan': return bilanPage(db, rc);
    case 'coupon': return page(rc, P.couponPage(rc, { pool: await D.pool(db, now) }), cc(300, 600));
    case 'legal': return page(rc, Object.assign({ active: r.arg === 'a-propos' ? 'apropos' : '' }, legalPage(rc, r.arg)), cc(3600, 86400));
    case 'day': {
      const jour = r.arg === 'aujourdhui' ? rc.today : r.arg === 'demain' ? rc.tomorrow : r.arg;
      const matches = await D.matchesByDay(db, jour);
      const stale = jour < rc.today ? 3600 : 300;
      return page(rc, P.day(rc, { jour, matches, bilan: await D.bilan30(db, now) }), cc(stale, stale * 2));
    }
    case 'league': {
      const lg = rc.leagues.find((l) => l.slug === r.arg);
      if (!lg) return notFound(rc);
      const [matches, results, b] = await Promise.all([
        D.matchesBetween(db, now.toISOString(), new Date(now.getTime() + 7 * 864e5).toISOString()),
        D.recentResults(db, now, 5, lg.apiId),
        D.bilanDays(db, now, 30),
      ]);
      const bl = summarize(b.map((d) => d.delta).filter(Boolean)).parLigue[String(lg.apiId)];
      return page(rc, P.league(rc, { league: lg, matches: matches.filter((m) => m.leagueId === String(lg.apiId)), results, bilanLigue: bl ? { taux: bl.taux, n: bl.n } : null }), cc(300, 600));
    }
    case 'match':
    case 'analysis': {
      const m = await D.matchBySlug(db, r.arg.leagueSlug, r.arg.slug);
      if (!m) return notFound(rc);
      const cache = m.statut === 'termine' ? cc(3600, 86400) : cc(300, 900);
      if (r.name === 'match') {
        const same = await D.matchesByDay(db, m.jour);
        return page(rc, P.match(rc, { m, same, h2h: m.h2h }), cache);
      }
      if (!m.prono || !m.prono.marches) return redirect(rc.u('match', m));
      const [formH, formA, days, pool] = await Promise.all([D.teamRecent(db, m.domicile.teamId), D.teamRecent(db, m.exterieur.teamId), D.bilanDays(db, now, 90), D.pool(db, now)]);
      const rates = rateByKey(days.map((d) => d.delta).filter(Boolean), 15);
      const withThis = pool.some((x) => x.id === m.id) ? pool : [m].concat(pool);
      return page(rc, P.details(rc, { m, formH, formA, h2h: m.h2h, rates, pool: withThis }), cache);
    }
    default: return notFound(rc);
  }
}

/** Accueil : les matchs d'aujourd'hui ; sinon les prochains jours où il y en a. */
async function homeMatches(db, rc) {
  const todayList = await D.matchesByDay(db, rc.today);
  if (todayList.length) return todayList;
  const upcoming = await D.matchesBetween(db, rc.now.toISOString(), new Date(rc.now.getTime() + 4 * 864e5).toISOString());
  const next = upcoming.find((m) => m.statut === 'prevu');
  return next ? upcoming.filter((m) => m.jour === next.jour) : [];
}

async function bilanPage(db, rc) {
  const days = await D.bilanDays(db, rc.now, 56);
  const s30 = summarize((await D.bilanDays(db, rc.now, 30)).map((d) => d.delta).filter(Boolean));
  const weeks = P.weeklyRates(days).slice(-8);
  const recent = await D.recentResults(db, rc.now, 10);
  const leagues = Object.entries(s30.parLigue).map(([id, v]) => ({ nom: C.leagueName(rc, id), taux: v.taux, n: v.n })).sort((a, b) => b.n - a.n);
  const familles = Object.values(s30.parFamille).filter((f) => f.n >= 10).sort((a, b) => b.n - a.n);
  return page(rc, P.bilan(rc, { s30, weeks, recent, leagues, familles }), cc(600, 1800));
}

/** Sitemap bilingue : chaque adresse française et anglaise, avec ses alternatives hreflang. */
async function sitemap(db, rc) {
  const entries = [];
  const add = (name, arg, freq, prio, lm) => entries.push({ fr: pathFor('fr', name, arg), en: pathFor('en', name, arg), freq, prio, lm });
  add('home', null, 'daily', '1.0'); add('day', 'aujourdhui', 'hourly', '0.9'); add('day', 'demain', 'hourly', '0.8');
  add('coupon', null, 'daily', '0.8'); add('bilan', null, 'daily', '0.7');
  for (const [slug, prio] of [['a-propos', '0.4'], ['contact', '0.3'], ['jeu-responsable', '0.3'], ['confidentialite', '0.2'], ['conditions', '0.2'], ['cookies', '0.2'], ['mentions-legales', '0.2']]) add('legal', slug, 'monthly', prio);
  for (const l of rc.leagues) add('league', l.slug, 'daily', '0.8');
  const snap = await db.collection('matches').where('coupDEnvoi', '>=', addDays(rc.now, -30).toISOString()).get();
  for (const m of snap.docs.map((d) => d.data()).filter((x) => x.prono && x.prono.visible !== false && x.statut !== 'reporte')) {
    add('match', m, m.statut === 'termine' ? 'monthly' : 'hourly', '0.7', m.majLe);
    if (m.prono.marches) add('analysis', m, 'daily', '0.6', m.majLe);
  }
  const o = rc.site.origine;
  const alt = (e) => `<xhtml:link rel="alternate" hreflang="fr" href="${esc(o + e.fr)}"/><xhtml:link rel="alternate" hreflang="en" href="${esc(o + e.en)}"/>`;
  const url = (loc, e) => `<url><loc>${esc(o + loc)}</loc>${alt(e)}${e.lm ? `<lastmod>${esc(String(e.lm).slice(0, 10))}</lastmod>` : ''}<changefreq>${e.freq}</changefreq><priority>${e.prio}</priority></url>`;
  const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n${entries.map((e) => url(e.fr, e) + '\n' + url(e.en, e)).join('\n')}\n</urlset>\n`;
  return reply(200, xml, 'application/xml; charset=utf-8', cc(3600));
}

module.exports = { route, context, CSS, VERSION };
