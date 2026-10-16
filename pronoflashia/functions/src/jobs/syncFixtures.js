'use strict';
// syncFixtures : matchs des 7 prochains jours des championnats suivis + historique de saison (buts) une fois par jour.

const N = require('../data/normalize');
const { ratingsWithTrend, backtest, isActive } = require('../engine/ratings');
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
  const doc = { apiId: t.apiId, nom: t.nom, nomCourt: short, couleurs: N.teamColors(t.nom), initiales: N.initials(short), logo: N.safeLogo(t.logo) };
  await db.collection('teams').doc(String(t.apiId)).set(doc, { merge: true });
  return doc;
}

/** Matchs à venir d'un championnat. Renvoie le nombre de matchs écrits. */
async function syncLeagueFixtures({ db, api, league, now, days, preloaded }) {
  const fixtures = preloaded || await api.fixtures({ league: league.apiId, season: league.saison, from: dayStr(now), to: dayStr(addDays(now, days)) });
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
      domicile: { teamId: String(fx.domicile.apiId), apiId: fx.domicile.apiId, nom: fx.domicile.nom, nomCourt: home.nomCourt, couleurs: home.couleurs, initiales: home.initiales, logo: home.logo },
      exterieur: { teamId: String(fx.exterieur.apiId), apiId: fx.exterieur.apiId, nom: fx.exterieur.nom, nomCourt: away.nomCourt, couleurs: away.couleurs, initiales: away.initiales, logo: away.logo },
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

/** Match terminé normalisé → { t, h, a, gh, ga } (format des notes d'équipes). */
const toRating = (f) => ({ t: Date.parse(f.coupDEnvoi), h: String(f.domicile.apiId), a: String(f.exterieur.apiId), gh: f.score.dom, ga: f.score.ext });

/**
 * Saison précédente du championnat, gardée en mémoire compacte (league_history/{id}) : elle sert d'historique aux notes d'équipes
 * en début de saison. Une seule requête par saison ; en cas d'échec (offre qui n'y donne pas accès), nouvel essai au bout d'une semaine.
 */
async function previousSeason({ db, api, league, now, budget }) {
  const ref = db.collection('league_history').doc(String(league.apiId));
  const d = await ref.get();
  const cur = d.exists ? d.data() : null;
  // Firestore refuse les tableaux dans des tableaux : un match = une chaîne « t|domicile|extérieur|buts dom|buts ext »
  const parse = (rows) => (rows || []).map((r) => { const [t, h, a, gh, ga] = String(r).split('|'); return [Number(t), h, a, Number(gh), Number(ga)]; });
  if (cur && cur.saison === league.saison - 1 && (cur.matches.length || (cur.essaiLe && now - new Date(cur.essaiLe) < 7 * 864e5))) return parse(cur.matches);
  // la limite de débit du fournisseur (10 appels par minute) ne doit jamais empêcher le calendrier du jour : au plus quelques saisons précédentes par passage, le reste aux passages suivants
  if (budget && budget.left <= 0) return parse(cur && cur.saison === league.saison - 1 ? cur.matches : []);
  if (budget) budget.left--;
  let rows = [], erreur = null;
  try {
    const fx = (await api.fixtures({ league: league.apiId, season: league.saison - 1 })).map(N.normalizeFixture);
    rows = fx.filter((f) => f.statut === 'termine' && f.score && f.domicile.apiId && f.exterieur.apiId).map(toRating).map((m) => `${m.t}|${m.h}|${m.a}|${m.gh}|${m.ga}`);
  } catch (e) { erreur = String(e.message || e).slice(0, 120); }
  await ref.set({ ligue: String(league.apiId), saison: league.saison - 1, matches: rows, essaiLe: now.toISOString(), erreur });
  return parse(rows);
}

/**
 * Notes d'équipes du championnat : calculées sur la saison précédente et la saison en cours, jugées sur des matchs passés,
 * enregistrées dans league_ratings/{id} ; le résultat du jugement est inscrit sur le championnat (ratings.actif).
 */
async function updateRatings({ db, api, league, now, done, budget }) {
  const prev = (await previousSeason({ db, api, league, now, budget })).map(([t, h, a, gh, ga]) => ({ t, h, a, gh, ga }));
  const cur = done.map(toRating);
  const R = ratingsWithTrend(prev.concat(cur), now.getTime());
  if (!R) return { notes: false };
  const bt = cur.length >= 30 ? backtest(prev, cur) : { n: 0, gain: 0, rps: 0 };
  const actif = isActive(bt);
  await db.collection('league_ratings').doc(String(league.apiId)).set(Object.assign({}, R, { ligue: String(league.apiId), majLe: now.toISOString(), jugement: bt }));
  await db.collection('leagues').doc(String(league.apiId)).set({ ratings: Object.assign({}, bt, { actif, historique: prev.length }) }, { merge: true });
  return { notes: true, equipes: Object.keys(R.A).length, jugement: bt, actif };
}

/**
 * Historique de la saison d'un championnat : buts (tous les matchs terminés) → team_form/{équipe} et moyennes de la ligue.
 * Une seule requête par championnat. Les statistiques de comptage déjà enregistrées sont conservées.
 */
async function syncLeagueSeason({ db, api, league, now, preloaded, budget }) {
  const fixtures = (preloaded || await api.fixtures({ league: league.apiId, season: league.saison })).map(N.normalizeFixture);
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
  let notes = { notes: false };
  try { notes = await updateRatings({ db, api, league, now, done, budget }); } catch (e) { notes = { notes: false, erreur: e.message }; }
  return { equipes: byTeam.size, matchsTermines: done.length, ratings: notes };
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
    // saison européenne : elle commence l'été (juillet ou après) ; aucun appel à l'API pour rester dans la limite de débit
    const saison = now.getUTCMonth() >= 6 ? now.getUTCFullYear() : now.getUTCFullYear() - 1;
    await db.collection('leagues').doc(String(l.apiId)).set(Object.assign({}, l, { saison, suivi: true, sport: 'football' }));
    n++;
  }
  report.infos.championnatsInitialises = n;
  return n;
}

/**
 * Changement de saison automatique : une fois par semaine, la saison en cours du championnat est relue chez le fournisseur
 * (les championnats européens changent de saison chaque été). Une erreur ici n'empêche jamais la synchronisation.
 */
async function refreshSeason({ db, api, league, now }) {
  if (typeof api.leagues !== 'function') return false;
  const last = league.saisonVerifieLe ? new Date(league.saisonVerifieLe) : null;
  if (last && now - last < 7 * 864e5) return false;
  try {
    const r = await api.leagues({ id: league.apiId });
    const seasons = (r[0] && r[0].seasons) || [];
    const cur = seasons.find((x) => x.current);
    const upd = { saisonVerifieLe: now.toISOString() };
    let changed = false;
    if (cur && cur.year && cur.year !== league.saison) { upd.saison = cur.year; changed = true; league.saison = cur.year; }
    await db.collection('leagues').doc(String(league.apiId)).set(upd, { merge: true });
    return changed;
  } catch { return false; }
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
  // saisons précédentes (une seule fois par championnat) : 2 par passage au plus, pour ne jamais épuiser les 10 appels par minute de football-data.org
  const budget = { left: opts.maxHistory == null ? 2 : opts.maxHistory };
  const leagues = (await db.collection('leagues').where('suivi', '==', true).get()).docs.map((d) => d.data());
  report.infos.championnats = leagues.length;
  for (const league of leagues) {
    if (await refreshSeason({ db, api, league, now })) report.infos[`nouvelleSaison_${league.slug}`] = league.saison;
    try {
      assertQuota(api, reserve);
      if (api.singleCall) {
        // une seule requête : la saison entière (matchs terminés pour l'historique, matchs à venir pour le calendrier)
        const all = await api.fixtures({ league: league.apiId, season: league.saison });
        const from = `${dayStr(now)}T00:00:00.000Z`, to = `${dayStr(addDays(now, days))}T23:59:59.999Z`;
        const upcoming = all.filter((raw) => { const d = N.normalizeFixture(raw).coupDEnvoi; return d >= from && d <= to; });
        report.traites += await syncLeagueFixtures({ db, api, league, now, days, preloaded: upcoming });
        report.infos[`saison_${league.slug}`] = await syncLeagueSeason({ db, api, league, now, preloaded: all, budget });
        continue;
      }
      report.traites += await syncLeagueFixtures({ db, api, league, now, days });
      const last = league.formMajLe ? new Date(league.formMajLe) : null;
      if (opts.forceSeason || !last || now - last > 20 * 3600e3) {
        assertQuota(api, reserve);
        const r = await syncLeagueSeason({ db, api, league, now, budget });
        report.infos[`saison_${league.slug}`] = r;
      }
    } catch (e) {
      report.erreurs.push(`${league.nom} : ${e.message}`);
    }
  }
  report.infos.quotaRestant = api.quota.dayRemaining;
  await recordApiQuota(db, api, now, report);
}

module.exports = { refreshSeason, seedDefaultLeagues, syncFixtures, syncLeagueFixtures, syncLeagueSeason, upsertTeam, assertQuota, COUNT_KINDS };
