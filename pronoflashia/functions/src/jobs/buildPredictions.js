'use strict';
// buildPredictions : calcule le pronostic de chaque match à venir, puis demande le texte à l'IA.

const N = require('../data/normalize');
const { predictMatch, MODEL_VERSION } = require('../engine/model');
const { buildCalibration, trackRecord } = require('../engine/learn');
const { predictLambdas, describeTeam } = require('../engine/ratings');
const { assess: assessFragility } = require('../engine/fragility');
const { generateText } = require('../ai/generate');
const { summarize } = require('../engine/bilan');
const { dayStr, addDays } = require('./helpers');
const { assertQuota, COUNT_KINDS } = require('./syncFixtures');
const { dateLongue, heure, fr } = require('../util/format');
const labels = require('../shared/labels');
const { recordAiCalls, recordApiQuota } = require('./connexions');
const { archiveCoupons } = require('./coupons');

const COUNT_LABELS = { corners: 'Corners', shotsOnTarget: 'Tirs cadrés', shots: 'Tirs', cards: 'Cartons', fouls: 'Fautes', offsides: 'Hors-jeux' };

/** Calibration : tranches du bilan sur 90 jours, utilisées seulement quand l'échantillon est assez grand. */
async function loadCalibration(db, now) {
  const since = dayStr(addDays(now, -90));
  const snap = await db.collection('bilan_days').where('jour', '>=', since).get();
  const days = snap.docs.map((d) => d.data().delta).filter(Boolean);
  return buildCalibration(summarize(days));
}

/** Tableau comparatif affiché sur la page « analyse complète ». */
function buildComparatif(recentH, recentA, gsH, gsA) {
  const avg = (b, f) => (b.games ? Math.round((b[f] / b.games) * 100) / 100 : null);
  const rows = [
    { cle: 'buts_marques', label: 'Buts marqués', dom: avg(gsH.home, 'gf'), ext: avg(gsA.away, 'gf') },
    { cle: 'buts_encaisses', label: 'Buts encaissés', dom: avg(gsH.home, 'ga'), ext: avg(gsA.away, 'ga'), inverse: true },
  ];
  for (const kind of COUNT_KINDS) {
    const h = N.countAverages(recentH, kind), a = N.countAverages(recentA, kind);
    if (h && a) rows.push({ cle: kind, label: COUNT_LABELS[kind], dom: Math.round(h.for.avg * 10) / 10, ext: Math.round(a.for.avg * 10) / 10, inverse: kind === 'cards' || kind === 'fouls' });
  }
  const pts = (arr) => arr.slice().sort((x, y) => (x.date < y.date ? 1 : -1)).slice(0, 5).reduce((s, e) => s + (e.gf > e.ga ? 3 : e.gf === e.ga ? 1 : 0), 0);
  if (recentH.length >= 5 && recentA.length >= 5) rows.push({ cle: 'points5', label: 'Points sur les 5 derniers', dom: pts(recentH), ext: pts(recentA) });
  return rows.filter((r) => r.dom != null && r.ext != null);
}

/** Lignes de faits envoyées à l'IA (tous les chiffres qu'elle a le droit de citer), en français ou en anglais. */
function buildFacts(match, gsH, gsA, h2h, lang, bilan, notes, actu) {
  const en = lang === 'en';
  const D = match.domicile.nomCourt, E = match.exterieur.nomCourt;
  const f1 = (x) => fr(x, 1, lang);
  const extras = [];
  if (gsH.home.games) extras.push(en ? `${D} score ${f1(gsH.home.gf / gsH.home.games)} goals per game at home and concede ${f1(gsH.home.ga / gsH.home.games)}.` : `${D} marque ${f1(gsH.home.gf / gsH.home.games)} buts par match à domicile et en encaisse ${f1(gsH.home.ga / gsH.home.games)}.`);
  if (gsA.away.games) extras.push(en ? `${E} score ${f1(gsA.away.gf / gsA.away.games)} goals per game away and concede ${f1(gsA.away.ga / gsA.away.games)}.` : `${E} marque ${f1(gsA.away.gf / gsA.away.games)} buts par match à l'extérieur et en encaisse ${f1(gsA.away.ga / gsA.away.games)}.`);
  const lines = [];
  if (h2h && h2h.length) {
    const dw = h2h.filter((x) => (x.domId === match.domicile.apiId ? x.sd > x.se : x.se > x.sd)).length;
    const ew = h2h.filter((x) => (x.domId === match.exterieur.apiId ? x.sd > x.se : x.se > x.sd)).length;
    const nul = h2h.length - dw - ew;
    lines.push(en
      ? `In the last ${h2h.length} meetings: ${dw} win${dw === 1 ? '' : 's'} for ${D}, ${nul} draw${nul === 1 ? '' : 's'}, ${ew} win${ew === 1 ? '' : 's'} for ${E}.`
      : `Sur les ${h2h.length} dernières confrontations : ${dw} victoire${dw > 1 ? 's' : ''} de ${D}, ${nul} nul${nul > 1 ? 's' : ''}, ${ew} victoire${ew > 1 ? 's' : ''} de ${E}.`);
  }
  // bilan réel de ce type de pari : l'IA doit pouvoir le citer (et inviter à la prudence s'il est faible)
  if (bilan && bilan.n >= 15) {
    extras.push(en
      ? `Our recent track record on this type of bet (${bilan.libelle}): ${bilan.reel}% successful over ${bilan.n} predictions.`
      : `Notre bilan récent sur ce type de pari (${bilan.libelle}) : ${bilan.reel} % de réussite sur ${bilan.n} pronostics.`);
  }
  // notes d'équipes : ce que l'IA a appris de chaque club (seulement quand l'écart à la moyenne de la ligue est net)
  for (const [team, d] of [[D, notes && notes.dom], [E, notes && notes.ext]]) {
    if (!d) continue;
    if (Math.abs(d.attaque) >= 15) extras.push(en ? `Our team ratings put ${team}'s attack ${Math.abs(d.attaque)}% ${d.attaque > 0 ? 'above' : 'below'} the league average.` : `Nos notes d'équipes placent l'attaque de ${team} ${Math.abs(d.attaque)} % ${d.attaque > 0 ? 'au-dessus' : 'en dessous'} de la moyenne du championnat.`);
    if (Math.abs(d.defense) >= 15) extras.push(en ? `${team}'s defence concedes ${Math.abs(d.defense)}% ${d.defense > 0 ? 'more' : 'fewer'} goals than the league average, according to our ratings.` : `Selon nos notes, la défense de ${team} encaisse ${Math.abs(d.defense)} % ${d.defense > 0 ? 'de buts en plus' : 'de buts en moins'} que la moyenne du championnat.`);
  }
  // actualité récente lue par l'IA (toujours avec sa source ; « à confirmer » quand le texte source hésite)
  for (const f of (actu && actu.faits) || []) {
    const who = f.joueur ? (en ? ` of ${f.joueur}` : ` de ${f.joueur}`) : '';
    const label = en
      ? { absence: `absence${who} reported for ${f.equipe}`, suspension: `suspension${who} reported for ${f.equipe}`, retour: `return${who} reported for ${f.equipe}`, entraineur: `coaching change reported at ${f.equipe}` }[f.type]
      : { absence: `absence${who} signalée côté ${f.equipe}`, suspension: `suspension${who} signalée côté ${f.equipe}`, retour: `retour${who} signalé côté ${f.equipe}`, entraineur: `changement d'entraîneur signalé chez ${f.equipe}` }[f.type];
    if (label) extras.push(en ? `Recent news (${f.source}): ${label}${f.certitude === 'rumeur' ? ', to be confirmed' : ''}.` : `Actualité récente (${f.source}) : ${label}${f.certitude === 'rumeur' ? ', à confirmer' : ''}.`);
  }
  return { extras, h2h: lines };
}

/** Faits d'actualité des 72 dernières heures qui concernent l'une des deux équipes (sans doublon, 4 au plus, les plus récents d'abord). */
function actuOf(articles, match) {
  const ids = [String(match.domicile.teamId), String(match.exterieur.teamId)];
  const seen = new Set();
  const out = [];
  for (const n of articles.filter((a) => a.fait && ids.includes(a.fait.equipeId)).sort((a, b) => (a.date < b.date ? 1 : -1))) {
    const k = `${n.fait.equipeId}|${n.fait.type}|${n.fait.joueur || ''}`;
    if (seen.has(k)) continue;
    seen.add(k);
    out.push({ equipeId: n.fait.equipeId, equipe: n.fait.equipe, type: n.fait.type, joueur: n.fait.joueur || null, certitude: n.fait.certitude, source: n.source, lien: n.lien, date: n.date });
    if (out.length >= 4) break;
  }
  return out.length ? { faits: out } : null;
}

/**
 * Le texte déjà rédigé peut-il être gardé ? Oui si le pronostic n'a pas vraiment bougé (même pari, écarts de 3 points au plus)
 * et si ce n'était pas un texte de secours. Économise le quota de l'IA lors des recalculs horaires.
 */
function textStillValid(prev, pred, key) {
  if (!prev || !prev[key] || !prev.principal || !prev.probas) return false;
  if ((key === 'texte' ? prev.sourceTexte : prev.sourceTexteEn) === 'secours') return false;
  if (prev.version !== MODEL_VERSION || prev.principal.cle !== pred.principal.cle) return false;
  const near = (a, b) => Math.abs((a || 0) - (b || 0)) <= 3;
  return near(prev.probas['1'], pred.probas['1']) && near(prev.probas.N, pred.probas.N) && near(prev.probas['2'], pred.probas['2'])
    && near(prev.principal.confiance, pred.principal.confiance) && near(prev.plus25, pred.plus25) && near(prev.bttsOui, pred.bttsOui) && prev.scoreProbable === pred.scoreProbable;
}

async function fetchOdds(api, match) {
  try { return N.normalizeOdds(await api.odds(match.apiId)); } catch { return null; }
}

async function fetchH2h(api, match) {
  try {
    const rows = await api.headToHead(`${match.domicile.apiId}-${match.exterieur.apiId}`, 5);
    return rows.map(N.normalizeFixture).filter((f) => f.statut === 'termine' && f.score)
      .map((f) => ({ date: f.coupDEnvoi.slice(0, 10), domId: f.domicile.apiId, dom: f.domicile.nom, ext: f.exterieur.nom, sd: f.score.dom, se: f.score.ext }));
  } catch { return null; }
}

/** Compteurs de l'état de l'IA pour la journée. */
async function bumpAiStatus(db, now, { fournisseur, secours, erreurs, latencyMs, neurons }) {
  const ref = db.collection('ai_status').doc('current');
  const jour = dayStr(now);
  // lecture puis écriture dans une transaction : plusieurs analyses se terminent en même temps
  await db.runTransaction(async (tx) => {
    const cur = (await tx.get(ref)).data() || {};
    const base = cur.jour === jour ? cur : { generesAujourdhui: 0, secoursAujourdhui: 0, quotaUtilise: 0 };
    const upd = {
      jour,
      generesAujourdhui: (base.generesAujourdhui || 0) + 1,
      secoursAujourdhui: (base.secoursAujourdhui || 0) + (secours ? 1 : 0),
      quotaUtilise: (base.quotaUtilise || 0) + (fournisseur === 'workers-ai' ? 1 : 0),
      neuronsAujourdhui: Math.round(((base.neuronsAujourdhui || 0) + (neurons || 0)) * 100) / 100,
    };
    if (!secours) { upd.fournisseur = fournisseur; upd.dernierSucces = now.toISOString(); if (latencyMs) upd.latenceMs = latencyMs; }
    if (erreurs.length) { upd.derniereErreur = `${erreurs[erreurs.length - 1].provider} : ${erreurs[erreurs.length - 1].detail}`.slice(0, 300); upd.derniereErreurLe = now.toISOString(); }
    tx.set(ref, Object.assign({}, cur, upd));
  });
}

async function buildOne({ db, api, providers, now, match, league, formCache, calibration, quotaReserve, maxExternal, langs }) {
  const form = async (teamId) => {
    if (!formCache.has(teamId)) { const d = await db.collection('team_form').doc(String(teamId)).get(); formCache.set(teamId, (d.exists && d.data().recent) || []); }
    return formCache.get(teamId);
  };
  const recentH = await form(match.domicile.teamId);
  const recentA = await form(match.exterieur.teamId);
  const gsH = N.goalStats(recentH), gsA = N.goalStats(recentA);
  // notes d'équipes du championnat (recalculées chaque jour par syncFixtures), utilisées sauf si leur jugement sur matchs passés les contredit
  const rkey = `notes:${match.leagueId}`;
  if (!formCache.has(rkey)) { const d = await db.collection('league_ratings').doc(String(match.leagueId)).get(); formCache.set(rkey, d.exists ? d.data() : null); }
  const R = formCache.get(rkey);
  const ratingsOn = !!(R && !(league && league.ratings && league.ratings.actif === false));
  const lamNotes = ratingsOn ? predictLambdas(R, String(match.domicile.teamId), String(match.exterieur.teamId)) : null;
  // actualité des 72 dernières heures (lue par syncNews) : informe, ne modifie aucune probabilité
  if (!formCache.has('news72')) { const snap = await db.collection('news').where('date', '>=', new Date(now.getTime() - 72 * 3600e3).toISOString()).get(); formCache.set('news72', snap.docs.map((d) => d.data()).filter((n) => n.fait)); }
  const actu = actuOf(formCache.get('news72'), match);
  const notes = ratingsOn ? { dom: describeTeam(R, String(match.domicile.teamId)), ext: describeTeam(R, String(match.exterieur.teamId)) } : null;
  const lgAvg = (league && league.avg) || {};
  const counts = {};
  for (const kind of COUNT_KINDS) {
    const h = N.countAverages(recentH, kind), a = N.countAverages(recentA, kind);
    if (h && a && lgAvg.counts && lgAvg.counts[kind]) counts[kind] = { home: h, away: a };
  }
  // requêtes externes facultatives (cotes, confrontations directes) : seulement si le quota le permet
  const hoursTo = (new Date(match.coupDEnvoi) - now) / 3600e3;
  let used = 0;
  const canCall = () => used < maxExternal && !(api.quota.dayRemaining != null && api.quota.dayRemaining < quotaReserve);
  let cotes = match.cotes || null;
  if (!cotes && hoursTo <= 48 && canCall()) { used++; cotes = await fetchOdds(api, match); }
  let h2h = match.h2h || null;
  if (!h2h && canCall()) { used++; h2h = await fetchH2h(api, match); }

  const pred = predictMatch({
    home: match.domicile, away: match.exterieur,
    stats: { home: { home: gsH.home, all: gsH.all }, away: { away: gsA.away, all: gsA.all } },
    league: { avgHome: lgAvg.avgHome || 1.45, avgAway: lgAvg.avgAway || 1.15, counts: lgAvg.counts || {} },
    counts, odds: cotes || undefined, calibration, ratings: lamNotes || undefined,
  });

  const H = match.domicile.nomCourt, A = match.exterieur.nomCourt;
  const base = {
    competition: match.leagueNom, domicile: H, exterieur: A, formeDom: N.formString(recentH), formeExt: N.formString(recentA),
    probas: pred.probas, plus25: pred.plus25, bttsOui: pred.bttsOui, scoreProbable: pred.scoreProbable,
  };
  const prev = match.prono || null;
  const texts = {};
  await Promise.all(langs.map(async (lang) => {
    const key = lang === 'en' ? 'texteEn' : 'texte';
    if (textStillValid(prev, pred, key)) { texts[lang] = { texte: prev[key], sourceTexte: lang === 'en' ? prev.sourceTexteEn : prev.sourceTexte, reutilise: true }; return; }
    const libelle = lang === 'en' ? labels.principalLabel(pred.principal.cle, H, A, 'en') : pred.principal.libelle;
    const tr = trackRecord(calibration, pred.principal.cle);
    const facts = buildFacts(match, gsH, gsA, h2h, lang, tr && { libelle, n: tr.n, reel: tr.reel }, lamNotes ? notes : null, actu);
    const ctx = Object.assign({}, base, {
      dateTexte: lang === 'en' ? `${dateLongue(match.coupDEnvoi, 'en')} at ${heure(match.coupDEnvoi)} (UTC)` : `${dateLongue(match.coupDEnvoi)} à ${heure(match.coupDEnvoi)} (heure UTC)`,
      principal: { libelle, confiance: pred.principal.confiance },
      extras: facts.extras, h2h: facts.h2h,
    });
    const gen = await generateText(ctx, providers, { lang });
    await bumpAiStatus(db, now, { fournisseur: gen.sourceTexte, secours: gen.sourceTexte === 'secours', erreurs: gen.erreurs, latencyMs: gen.latencyMs, neurons: (gen.appels || []).reduce((n, a) => n + (a.neurons || 0), 0) });
    await recordAiCalls(db, now, gen.appels);
    texts[lang] = gen;
  }));
  const gen = texts.fr || texts.en;

  const masque = !!(match.prono && match.prono.masque);
  const prono = {
    principal: pred.principal, secondaires: pred.secondaires, probas: pred.probas, plus25: pred.plus25, bttsOui: pred.bttsOui,
    scoreProbable: pred.scoreProbable, marches: pred.marches, matrice: pred.matrice, lamHome: pred.lamHome, lamAway: pred.lamAway, lamBrutHome: pred.lamBrutHome, lamBrutAway: pred.lamBrutAway, calibre: pred.calibre, moteur: pred.moteur, notes: lamNotes ? notes : null, actu,
    source: pred.source, texte: texts.fr ? texts.fr.texte : null, sourceTexte: texts.fr ? texts.fr.sourceTexte : null,
    texteEn: texts.en ? texts.en.texte : null, sourceTexteEn: texts.en ? texts.en.sourceTexte : null,
    calculeLe: now.toISOString(), version: MODEL_VERSION, formeDom: base.formeDom, formeExt: base.formeExt, comparatif: buildComparatif(recentH, recentA, gsH, gsA),
    echantillon: Math.min(gsH.all.games, gsA.all.games), fragile: assessFragility({ echantillon: Math.min(gsH.all.games, gsA.all.games), equipeInconnue: ratingsOn && !lamNotes }), visible: !masque, masque, aRecalculer: false,
  };
  await db.collection('matches').doc(match.id).set({ prono, cotes: cotes || null, h2h: h2h || null }, { merge: true });
  return gen;
}

/**
 * opts : { db, api, providers, now, maxMatches, refreshHours, quotaReserve, maxExternal }
 */
async function buildPredictions(opts, report) {
  const { db, api, providers } = opts;
  const now = opts.now || new Date();
  const maxMatches = opts.maxMatches || 80;
  const refreshHours = opts.refreshHours || 3;
  const quotaReserve = opts.quotaReserve == null ? 40 : opts.quotaReserve;
  const maxExternal = opts.maxExternal == null ? 2 : opts.maxExternal;
  // langues des analyses rédigées (l'anglais double les appels à l'IA lors d'un premier calcul)
  const langs = opts.langs || ['fr', 'en'];
  // lancement manuel depuis l'admin : le site coupe les requêtes à 60 s, on s'arrête avant et on garde le reste pour le passage suivant
  const budgetMs = opts.budgetMs || null;
  const concurrency = opts.concurrency || 4;
  const t0 = Date.now();

  const snap = await db.collection('matches').where('coupDEnvoi', '>=', now.toISOString()).where('coupDEnvoi', '<=', addDays(now, 7).toISOString()).get();
  const rows = snap.docs.map((d) => d.data()).filter((m) => m.statut === 'prevu');
  const todo = rows.filter((m) => {
    const p = m.prono;
    if (!p || !p.calculeLe || p.aRecalculer) return true;
    const sameDay = (new Date(m.coupDEnvoi) - now) / 3600e3 <= 24;
    const age = (now - new Date(p.calculeLe)) / 3600e3;
    return age > (sameDay ? refreshHours : 24);
  }).sort((a, b) => (a.coupDEnvoi < b.coupDEnvoi ? -1 : 1)).slice(0, maxMatches);
  report.infos.aCalculer = todo.length;
  // coupons flash du jour : enregistrés une fois, avant les coups d'envoi (jamais modifiés ensuite)
  const archive = async () => {
    try { const n = await archiveCoupons(db, now); if (n) report.infos.couponsArchives = n; } catch (e) { report.erreurs.push(`coupons : ${e.message}`); }
  };
  if (!todo.length) { await archive(); return; }

  const calibration = await loadCalibration(db, now);
  const leagues = new Map();
  const formCache = new Map();
  try {
    // quelques matchs à la fois (chacun attend l'IA surtout) : le budget de temps est contrôlé avant chaque nouveau match
    let next = 0;
    const worker = async () => {
      while (next < todo.length) {
        const i = next++;
        const m = todo[i];
        if (budgetMs && Date.now() - t0 > budgetMs) { report.infos.reste = (report.infos.reste || 0) + 1; continue; }
        try {
          if (!leagues.has(m.leagueId)) { const d = await db.collection('leagues').doc(m.leagueId).get(); leagues.set(m.leagueId, d.exists ? d.data() : null); }
          const gen = await buildOne({ db, api, providers, now, match: m, league: leagues.get(m.leagueId), formCache, calibration, quotaReserve, maxExternal, langs });
          if (gen.reutilise) report.infos.textesReutilises = (report.infos.textesReutilises || 0) + 1;
          report.traites++;
          report.infos[gen.sourceTexte] = (report.infos[gen.sourceTexte] || 0) + 1;
        } catch (e) {
          report.erreurs.push(`${m.slug} : ${e.message}`);
        }
      }
    };
    await Promise.all(Array.from({ length: Math.max(1, Math.min(concurrency, todo.length)) }, worker));
  } finally {
    await recordApiQuota(db, api, now, report);
  }
  await archive();
}

module.exports = { actuOf, buildPredictions, buildComparatif, buildFacts, loadCalibration, bumpAiStatus, textStillValid };
