'use strict';
// Routeur : chemin → page HTML (ou sitemap, robots, ads.txt). Utilisé par la fonction Firebase et par l'aperçu local.

const fs = require('fs');
const nodePath = require('path');
const D = require('./data');
const P = require('./pages');
const { PAGES } = require('./legal');
const C = require('./components');
const { rateByKey, summarize } = require('../engine/bilan');
const { dayStr, addDays } = require('../jobs/helpers');
const { esc } = require('../util/format');

const CSS = fs.readFileSync(nodePath.join(__dirname, 'style.css'), 'utf8').replace(/\s*\n\s*/g, '\n');
const VERSION = (() => { try { return require('crypto').createHash('md5').update(CSS).digest('hex').slice(0, 8); } catch { return '1'; } })();

const HTML = 'text/html; charset=utf-8';
const cc = (s, swr) => `public, max-age=60, s-maxage=${s}, stale-while-revalidate=${swr || s * 2}`;
const reply = (status, body, type, cache, extra) => ({ status, body, headers: Object.assign({ 'Content-Type': type || HTML, 'Cache-Control': cache || 'public, max-age=0, s-maxage=60' }, extra || {}) });

/** Contexte de rendu partagé par toutes les pages. */
async function context(db, now) {
  const [cfg, leagues] = await Promise.all([D.loadConfig(db), D.loadLeagues(db)]);
  const today = dayStr(now);
  const tomorrow = dayStr(addDays(now, 1));
  return { now, site: cfg.site, ads: cfg.ads, leagues, css: CSS, version: VERSION, today, tomorrow, dayAliases: { [today]: 'aujourdhui', [tomorrow]: 'demain' } };
}

const page = (rc, p, cache) => reply(p.status || 200, C.html(rc, p), HTML, cache);

async function route(db, urlPath, now = new Date()) {
  let path = String(urlPath || '/').split('?')[0].replace(/\/{2,}/g, '/');
  if (path.length > 1 && path.endsWith('/')) path = path.slice(0, -1);
  path = path.toLowerCase();
  const rc = await context(db, now);

  if (path === '/robots.txt') {
    const body = rc.site.indexable ? `User-agent: *\nAllow: /\nDisallow: /admin\nDisallow: /api/\nSitemap: ${rc.site.origine}/sitemap.xml\n` : 'User-agent: *\nDisallow: /\n';
    return reply(200, body, 'text/plain; charset=utf-8', cc(3600));
  }
  if (path === '/ads.txt') return reply(200, (rc.ads.adsTxt || '').trim() + '\n', 'text/plain; charset=utf-8', cc(600));
  if (path === '/sitemap.xml') return sitemap(db, rc);

  if (path === '/') {
    const matches = await homeMatches(db, rc);
    const bilan = await D.bilan30(db, now);
    return page(rc, P.home(rc, { matches, bilan }), cc(300, 600));
  }

  if (path === '/bilan') return bilanPage(db, rc);
  if (path === '/coupon') {
    const pool = await D.pool(db, now);
    return page(rc, P.couponPage(rc, { pool }), cc(300, 600));
  }
  const legal = PAGES[path.slice(1)];
  if (legal) return page(rc, Object.assign({ path, active: path === '/a-propos' ? 'apropos' : '' }, legal(rc)), cc(3600, 86400));

  const seg = path.split('/').filter(Boolean);
  if (seg[0] === 'football') {
    if (seg.length === 1) return redirect('/football/aujourdhui');
    if (seg.length === 2) {
      const dayKey = seg[1] === 'aujourdhui' ? rc.today : seg[1] === 'demain' ? rc.tomorrow : /^\d{4}-\d{2}-\d{2}$/.test(seg[1]) ? seg[1] : null;
      if (dayKey) {
        const matches = await D.matchesByDay(db, dayKey);
        const bilan = await D.bilan30(db, now);
        const label = dayKey === rc.today ? "d'aujourd'hui" : dayKey === rc.tomorrow ? 'de demain' : 'du jour';
        const stale = dayKey < rc.today ? 3600 : 300;
        return page(rc, P.day(rc, { jour: dayKey, label, matches, bilan }), cc(stale, stale * 2));
      }
      const lg = rc.leagues.find((l) => l.slug === seg[1]);
      if (lg) {
        const [matches, results, b] = await Promise.all([
          D.matchesBetween(db, now.toISOString(), new Date(now.getTime() + 7 * 864e5).toISOString()),
          D.recentResults(db, now, 5, lg.apiId),
          D.bilanDays(db, now, 30),
        ]);
        const bl = summarize(b.map((d) => d.delta).filter(Boolean)).parLigue[String(lg.apiId)];
        return page(rc, P.league(rc, { league: lg, matches: matches.filter((m) => m.leagueId === String(lg.apiId)), results, bilanLigue: bl ? { taux: bl.taux, n: bl.n } : null }), cc(300, 600));
      }
    }
    if (seg.length === 3 || (seg.length === 4 && seg[3] === 'analyse')) {
      const m = await D.matchBySlug(db, seg[1], seg[2]);
      if (!m) return notFound(rc);
      const finished = m.statut === 'termine';
      const cache = finished ? cc(3600, 86400) : cc(300, 900);
      if (seg.length === 3) {
        const same = await D.matchesByDay(db, m.jour);
        return page(rc, P.match(rc, { m, same, h2h: m.h2h }), cache);
      }
      if (!m.prono || !m.prono.marches) return redirect(`/football/${m.leagueSlug}/${m.slug}`);
      const [formH, formA, days, pool] = await Promise.all([D.teamRecent(db, m.domicile.teamId), D.teamRecent(db, m.exterieur.teamId), D.bilanDays(db, now, 90), D.pool(db, now)]);
      const rates = rateByKey(days.map((d) => d.delta).filter(Boolean), 15);
      const withThis = pool.some((x) => x.id === m.id) ? pool : [m].concat(pool);
      return page(rc, P.details(rc, { m, formH, formA, h2h: m.h2h, rates, pool: withThis }), cache);
    }
  }
  return notFound(rc);
}

const redirect = (to) => ({ status: 301, headers: { Location: to, 'Cache-Control': 'public, max-age=3600' }, body: '' });
async function notFound(rc) { return reply(404, C.html(rc, P.notFound(rc)), HTML, 'public, max-age=0, s-maxage=60'); }

/** Accueil : les matchs d'aujourd'hui ; sinon les prochains jours où il y en a. */
async function homeMatches(db, rc) {
  const upcoming = await D.matchesBetween(db, rc.now.toISOString(), new Date(rc.now.getTime() + 4 * 864e5).toISOString());
  const todayList = (await D.matchesByDay(db, rc.today)).filter((m) => m.statut !== 'termine' || true);
  if (todayList.length) return todayList;
  const next = upcoming.find((m) => m.statut === 'prevu');
  return next ? upcoming.filter((m) => m.jour === next.jour) : [];
}

async function bilanPage(db, rc) {
  const days = await D.bilanDays(db, rc.now, 56);
  const deltas30 = (await D.bilanDays(db, rc.now, 30)).map((d) => d.delta).filter(Boolean);
  const s30 = summarize(deltas30);
  const weeks = P.weeklyRates(days).slice(-8);
  const recent = await D.recentResults(db, rc.now, 10);
  const leagues = Object.entries(s30.parLigue).map(([id, v]) => ({ nom: (rc.leagues.find((l) => String(l.apiId) === id) || { nom: id }).nom, taux: v.taux, n: v.n })).sort((a, b) => b.n - a.n);
  const familles = Object.values(s30.parFamille).filter((f) => f.n >= 10).sort((a, b) => b.n - a.n);
  return page(rc, P.bilan(rc, { s30, weeks, recent, leagues, familles }), cc(600, 1800));
}

async function sitemap(db, rc) {
  const urls = [['/', 'daily', '1.0'], ['/football/aujourdhui', 'hourly', '0.9'], ['/football/demain', 'hourly', '0.8'], ['/coupon', 'daily', '0.8'], ['/bilan', 'daily', '0.7'],
    ['/a-propos', 'monthly', '0.4'], ['/contact', 'monthly', '0.3'], ['/jeu-responsable', 'monthly', '0.3'], ['/confidentialite', 'yearly', '0.2'], ['/conditions', 'yearly', '0.2'], ['/cookies', 'yearly', '0.2'], ['/mentions-legales', 'yearly', '0.2']];
  for (const l of rc.leagues) urls.push([`/football/${l.slug}`, 'daily', '0.8']);
  const from = addDays(rc.now, -30).toISOString();
  const snap = await db.collection('matches').where('coupDEnvoi', '>=', from).get();
  const ms = snap.docs.map((d) => d.data()).filter((m) => m.prono && m.prono.visible !== false && m.statut !== 'reporte');
  for (const m of ms) { urls.push([C.matchPath(m), m.statut === 'termine' ? 'monthly' : 'hourly', '0.7', m.majLe]); if (m.prono.marches) urls.push([C.matchPath(m) + '/analyse', 'daily', '0.6', m.majLe]); }
  const xml = `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${urls.map(([u, f, p, lm]) => `<url><loc>${esc(rc.site.origine + u)}</loc>${lm ? `<lastmod>${esc(String(lm).slice(0, 10))}</lastmod>` : ''}<changefreq>${f}</changefreq><priority>${p}</priority></url>`).join('\n')}\n</urlset>\n`;
  return reply(200, xml, 'application/xml; charset=utf-8', cc(3600));
}

module.exports = { route, context, CSS, VERSION };
