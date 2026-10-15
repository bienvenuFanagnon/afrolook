'use strict';
// syncResults : enregistre les scores finaux, marque chaque pari réussi ou raté, alimente l'historique des équipes et le bilan.

const N = require('../data/normalize');
const { evaluateMarket, evaluateAll } = require('../engine/evaluate');
const { matchDelta, mergeDelta } = require('../engine/bilan');
const { addDays } = require('./helpers');

const STAT_KINDS = ['corners', 'shots', 'shotsOnTarget', 'fouls', 'cards', 'offsides'];

/** Ajoute (ou complète) l'entrée du match dans l'historique d'une équipe, avec les statistiques de comptage. */
async function appendTeamForm(db, teamId, fx, venue, statsMine, statsOpp, now) {
  const ref = db.collection('team_form').doc(String(teamId));
  const cur = await ref.get();
  const recent = (cur.exists && cur.data().recent) || [];
  let entry = recent.find((e) => e.id === fx.apiId);
  if (!entry) { entry = N.recentEntry(fx, venue); recent.push(entry); }
  if (statsMine && statsOpp) {
    entry.stats = {};
    for (const k of STAT_KINDS) if (statsMine[k] != null && statsOpp[k] != null) entry.stats[k] = { f: statsMine[k], a: statsOpp[k] };
  }
  recent.sort((a, b) => (a.date < b.date ? 1 : -1));
  await ref.set({ teamId: String(teamId), recent: recent.slice(0, 40), majLe: now.toISOString() });
}

/** Un match vient de se terminer : évaluation, historique, bilan. */
async function finalize({ db, api, match, fx, now, statsBudget }) {
  let stats = null;
  let statsTentee = false;
  if (statsBudget.left > 0) {
    statsBudget.left--;
    statsTentee = true;
    try {
      const byTeam = N.normalizeStatistics(await api.fixtureStatistics(match.apiId));
      const h = byTeam[match.domicile.apiId], a = byTeam[match.exterieur.apiId];
      if (h && a) stats = { home: h, away: a };
    } catch { /* on réessaiera au prochain passage */ }
  }
  const prev = match.resultat || {};
  const tentatives = (prev.tentativesStats || 0) + (statsTentee ? 1 : 0);
  const ctx = { score: fx.score, miTemps: fx.miTemps, stats };
  const pr = match.prono && match.prono.principal;
  const marches = match.prono ? evaluateAll(match.prono.marches, ctx) : {};
  const reussi = pr ? evaluateMarket(pr.cle, ctx) : null;
  // on attend les statistiques (3 tentatives au plus) avant de figer le bilan, pour ne pas fausser les marchés de comptage
  const pret = !!stats || tentatives >= 3 || !match.prono;
  const resultat = {
    scoreDom: fx.score.dom, scoreExt: fx.score.ext, miTemps: fx.miTemps, reussi, marches, stats,
    tentativesStats: tentatives, compte: !!prev.compte, termineLe: prev.termineLe || now.toISOString(),
  };
  const upd = { statut: 'termine', resultat };
  if (pret && !prev.compte && match.prono && reussi !== null) {
    const full = Object.assign({}, match, { resultat });
    const delta = matchDelta(full);
    if (delta) {
      const ref = db.collection('bilan_days').doc(match.jour);
      await db.runTransaction(async (tx) => {
        const d = await tx.get(ref);
        const cur = d.exists ? d.data().delta : null;
        tx.set(ref, { jour: match.jour, delta: mergeDelta(cur, delta) });
      });
      resultat.compte = true;
    }
  }
  await db.collection('matches').doc(match.id).set(upd, { merge: true });
  if (stats || !prev.termineLe) {
    await appendTeamForm(db, match.domicile.teamId, fx, 'home', stats && stats.home, stats && stats.away, now);
    await appendTeamForm(db, match.exterieur.teamId, fx, 'away', stats && stats.away, stats && stats.home, now);
  }
  return { reussi, stats: !!stats };
}

/**
 * opts : { db, api, now, maxStats }
 */
async function syncResults(opts, report) {
  const { db, api } = opts;
  const now = opts.now || new Date();
  const statsBudget = { left: opts.maxStats == null ? 15 : opts.maxStats };
  const from = addDays(now, -3).toISOString();
  const to = new Date(now.getTime() - 100 * 60e3).toISOString(); // un match dure environ 100 min
  const snap = await db.collection('matches').where('coupDEnvoi', '>=', from).where('coupDEnvoi', '<=', to).get();
  const rows = snap.docs.map((d) => d.data());
  const open = rows.filter((m) => m.statut === 'prevu' || m.statut === 'en_cours');
  // matchs terminés dont les statistiques ou le bilan n'ont pas encore été enregistrés
  const pending = rows.filter((m) => m.statut === 'termine' && m.resultat && !m.resultat.compte && m.prono);
  report.infos.ouverts = open.length;
  report.infos.enAttente = pending.length;

  for (let i = 0; i < open.length; i += 20) {
    const batch = open.slice(i, i + 20);
    let fixtures;
    try { fixtures = (await api.fixturesByIds(batch.map((m) => m.apiId))).map(N.normalizeFixture); } catch (e) { report.erreurs.push(e.message); continue; }
    const byId = new Map(fixtures.map((f) => [f.apiId, f]));
    for (const m of batch) {
      const fx = byId.get(m.apiId);
      if (!fx) continue;
      try {
        if (fx.statut === 'termine' && fx.score) {
          await finalize({ db, api, match: m, fx, now, statsBudget });
          report.traites++;
        } else if (fx.statut !== m.statut || (fx.score && fx.statut === 'en_cours')) {
          await db.collection('matches').doc(m.id).set({ statut: fx.statut, scoreLive: fx.score }, { merge: true });
        }
      } catch (e) { report.erreurs.push(`${m.slug} : ${e.message}`); }
    }
  }
  for (const m of pending) {
    if (statsBudget.left <= 0) break;
    const fx = { apiId: m.apiId, score: { dom: m.resultat.scoreDom, ext: m.resultat.scoreExt }, miTemps: m.resultat.miTemps, coupDEnvoi: m.coupDEnvoi, domicile: m.domicile, exterieur: m.exterieur };
    try { await finalize({ db, api, match: m, fx, now, statsBudget }); report.traites++; } catch (e) { report.erreurs.push(`${m.slug} : ${e.message}`); }
  }
  report.infos.quotaRestant = api.quota.dayRemaining;
}

module.exports = { syncResults, finalize };
