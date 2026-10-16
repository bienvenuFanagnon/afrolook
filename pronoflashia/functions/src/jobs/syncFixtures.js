'use strict';
// syncFixtures : matchs des 7 prochains jours des championnats suivis + historique de saison (buts) une fois par jour.

const N = require('../data/normalize');
const { dayStr, addDays } = require('./helpers');
const { recordApiQuota } = require('./connexions');

const COUNT_KINDS = ['corners', 'shotsOnTarget', 'shots', 'cards', 'fouls', 'offsides'];

function assertQuota(api, reserve) {
  if (api.quota.dayRemaining != null && api.quota.dayRemaining < reserve) {
    throw new Error(`Quota API-Football presque épuisé (${api.quota.dayRemaining} requêtes restantes)`);
  }
}

async function upsertTeam(db, t) {
  if (!t || !t.apiId) return null;
  const short = N.shortName(t.nom);
  const doc = { apiId: t.apiId, nom: t.nom, nomCourt: short, couleurs: N.teamColors(t.nom), initiales: N.initials(short) };
  await db.collection('teams').doc(String(t.apiId)).set(doc, { merge: true });
  return doc;
}

/** Matchs à venir d'un championnat. Renvoie le nombre de matchs écrits. */
async function syncLeagueFixtures({ db, api, league, now, days }) {
  const fixtures = await api.fixtures({ league: league.apiId, season: league.saison, from: dayStr(now), to: dayStr(addDays(now, days)) });
  let n = 0;
  for (const raw of fixtures) {
    const fx = N.normalizeFixture(raw);
    if (!fx.apiId || !fx.domicile.apiId || !fx.exterieur.apiId || !fx.coupDEnvoi || fx.coupDEnvoi === 'Invalid Date') continue;
    const home = await upsertTeam(db, fx.domicile);
    const away = await upsertTeam(db, fx.exterieur);
    const id = `${league.apiId}_${fx.apiId}`;
    const ref = db.collection('matches').doc(id);
    const prev = await ref.get();
    const p = prev.exists ? prev.data() : null;
    const jour = fx.coupDEnvoi.slice(0, 10);
    const doc = {
      id, apiId: fx.apiId, sport: league.sport || 'football', leagueId: String(league.apiId), leagueSlug: league.slug, leagueNom: league.nom, pays: league.pays || null,
      saison: fx.saison, journee: fx.journee, round: fx.round, coupDEnvoi: fx.coupDEnvoi, jour, statut: fx.statut, arbitre: fx.arbitre, lieu: fx.lieu,
      domicile: { teamId: String(fx.domicile.apiId), apiId: fx.domicile.apiId, nom: fx.domicile.nom, nomCourt: home.nomCourt, couleurs: home.couleurs, initiales: home.initiales },
      exterieur: { teamId: String(fx.exterieur.apiId), apiId: fx.exterieur.apiId, nom: fx.exterieur.nom, nomCourt: away.nomCourt, couleurs: away.couleurs, initiales: away.initiales },
      slug: `${N.slugify(home.nomCourt)}-${N.slugify(away.nomCourt)}-${jour}`,
      majLe: now.toISOString(),
    };
    // un changement d'horaire ou de statut oblige à recalculer le pronostic
    if (p && p.prono && (p.coupDEnvoi !== fx.coupDEnvoi || p.statut !== fx.statut)) doc.prono = { aRecalculer: true };
    await ref.set(doc, { merge: true });
    n++;
  }
  return n;
}

/**
 * Historique de la saison d'un championnat : buts (tous les matchs terminés) → team_form/{équipe} et moyennes de la ligue.
 * Une seule requête par championnat. Les statistiques de comptage déjà enregistrées sont conservées.
 */
async function syncLeagueSeason({ db, api, league, now }) {
  const fixtures = (await api.fixtures({ league: league.apiId, season: league.saison })).map(N.normalizeFixture);
  const done = fixtures.filter((f) => f.statut === 'termine' && f.score && f.domicile.apiId && f.exterieur.apiId);
  const byTeam = new Map();
  const push = (teamId, entry) => { if (!byTeam.has(teamId)) byTeam.set(teamId, []); byTeam.get(teamId).push(entry); };
  for (const f of done) {
    push(f.domicile.apiId, N.recentEntry(f, 'home'));
    push(f.exterieur.apiId, N.recentEntry(f, 'away'));
  }
  const allRecent = [];
  for (const [teamId, entries] of byTeam) {
    const ref = db.collection('team_form').doc(String(teamId));
    const prev = await ref.get();
    const old = new Map(((prev.exists && prev.data().recent) || []).map((e) => [e.id, e]));
    const merged = entries.map((e) => (old.has(e.id) && old.get(e.id).stats ? Object.assign({}, e, { stats: old.get(e.id).stats }) : e));
    // on garde aussi les entrées plus anciennes avec statistiques (saison précédente) pour les comptages
    for (const [id, e] of old) if (!merged.some((m) => m.id === id) && e.stats) merged.push(e);
    merged.sort((a, b) => (a.date < b.date ? 1 : -1));
    const recent = merged.slice(0, 40);
    await ref.set({ teamId: String(teamId), recent, majLe: now.toISOString() });
    allRecent.push(...recent);
  }
  const avg = N.leagueGoalAverages(fixtures);
  const counts = {};
  for (const kind of COUNT_KINDS) {
    const withStats = allRecent.filter((e) => e.stats && e.stats[kind] && e.stats[kind].f != null);
    const home = withStats.filter((e) => e.venue === 'home');
    const away = withStats.filter((e) => e.venue === 'away');
    if (home.length >= 10 && away.length >= 10) {
      const m = (a) => Math.round((a.reduce((s, e) => s + e.stats[kind].f, 0) / a.length) * 100) / 100;
      counts[kind] = { avgHome: m(home), avgAway: m(away) };
    }
  }
  await db.collection('leagues').doc(String(league.apiId)).set({ avg: Object.assign({}, avg || {}, { counts }), formMajLe: now.toISOString() }, { merge: true });
  return { equipes: byTeam.size, matchsTermines: done.length };
}

/**
 * Première utilisation : si aucun championnat n'est enregistré et que la source en propose par défaut (offre gratuite),
 * on les ajoute avec la saison en cours. L'admin peut ensuite les modifier, en retirer ou en ajouter.
 */
async function seedDefaultLeagues({ db, api, now }, report) {
  if (!api.defaultLeagues || !api.defaultLeagues.length) return 0;
  const existing = await db.collection('leagues').get();
  if (existing.docs.length) return 0;
  let n = 0;
  for (const l of api.defaultLeagues) {
    let saison = now.getUTCMonth() >= 6 ? now.getUTCFullYear() : now.getUTCFullYear() - 1;
    try {
      const r = await api.leagues({ id: l.apiId });
      const seasons = (r[0] && r[0].seasons) || [];
      const cur = seasons.find((x) => x.current);
      if (cur) saison = cur.year;
    } catch (e) { report.erreurs.push(`${l.nom} : saison par défaut utilisée (${e.message})`); }
    await db.collection('leagues').doc(String(l.apiId)).set(Object.assign({}, l, { saison, suivi: true, sport: 'football' }));
    n++;
  }
  report.infos.championnatsInitialises = n;
  return n;
}

/**
 * Tâche complète. opts : { db, api, now, days, reserve, forceSeason }.
 * report : objet du compte-rendu (traites, erreurs, infos).
 */
async function syncFixtures(opts, report) {
  const { db, api } = opts;
  const now = opts.now || new Date();
  const days = opts.days || 7;
  const reserve = opts.reserve == null ? 40 : opts.reserve;
  await seedDefaultLeagues({ db, api, now }, report);
  const leagues = (await db.collection('leagues').where('suivi', '==', true).get()).docs.map((d) => d.data());
  report.infos.championnats = leagues.length;
  for (const league of leagues) {
    try {
      assertQuota(api, reserve);
      report.traites += await syncLeagueFixtures({ db, api, league, now, days });
      const last = league.formMajLe ? new Date(league.formMajLe) : null;
      if (opts.forceSeason || !last || now - last > 20 * 3600e3) {
        assertQuota(api, reserve);
        const r = await syncLeagueSeason({ db, api, league, now });
        report.infos[`saison_${league.slug}`] = r;
      }
    } catch (e) {
      report.erreurs.push(`${league.nom} : ${e.message}`);
    }
  }
  report.infos.quotaRestant = api.quota.dayRemaining;
  await recordApiQuota(db, api, now, report);
}

module.exports = { seedDefaultLeagues, syncFixtures, syncLeagueFixtures, syncLeagueSeason, upsertTeam, assertQuota, COUNT_KINDS };
