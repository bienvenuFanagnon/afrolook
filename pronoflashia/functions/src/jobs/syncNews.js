'use strict';
// syncNews : lit les flux RSS des sites de football, garde titre / site / date / lien, repère les équipes citées.
// Aucun texte d'article n'est conservé. Chaque source est suivie à part : une source en panne ne bloque pas les autres.

const crypto = require('crypto');
const { SOURCES } = require('../news/sources');
const { fetchFeed } = require('../news/rss');
const { teamsInTitle } = require('../news/match');
const { extractFact } = require('../news/facts');
const { fetchPreview } = require('../news/preview');
const { cleanExcerpt } = require('../news/rss');

const KEEP_HOURS = 96;
const MAX_PER_SOURCE = 25;
const MAX_PREVIEWS = 10; // pages d'articles lues par passage pour compléter l'image ou l'extrait (aperçu de lien)
const MAX_AI_CALLS = 6; // appels à l'IA par passage (12 passages par jour) : quelques centaines de neurons par jour au plus

const idOf = (lien) => crypto.createHash('sha1').update(lien).digest('hex').slice(0, 20);

/** Réglages : config/news { actif, sources: { id: true|false } } ; par défaut tout ce qui est marqué actif. */
async function loadNewsConfig(db) {
  const d = await db.collection('config').doc('news').get();
  const c = d.exists ? d.data() : {};
  return { actif: c.actif !== false, images: c.images !== false, recaps: c.recaps !== false, sources: c.sources || {} };
}
const isOn = (cfg, s) => (cfg.sources[s.id] === undefined ? s.actif : !!cfg.sources[s.id]);

/** Équipes des matchs d'hier à dans 4 jours : celles dont on cherche les nouvelles. */
async function teamsToWatch(db, now) {
  const from = new Date(now.getTime() - 864e5).toISOString(), to = new Date(now.getTime() + 4 * 864e5).toISOString();
  const snap = await db.collection('matches').where('coupDEnvoi', '>=', from).where('coupDEnvoi', '<=', to).get();
  const map = new Map();
  for (const d of snap.docs) {
    const m = d.data();
    for (const t of [m.domicile, m.exterieur]) {
      if (!t || t.teamId == null) continue;
      const e = map.get(String(t.teamId)) || { id: String(t.teamId), noms: [] };
      for (const n of [t.nomCourt, t.nom]) if (n && !e.noms.includes(n)) e.noms.push(n);
      map.set(String(t.teamId), e);
    }
  }
  return [...map.values()];
}

/**
 * opts : { db, now, fetchImpl, sources, providers, maxAiCalls }
 * Écrit news/{id} pour chaque nouvel article et news_sources/{id} pour l'état de chaque source.
 */
async function syncNews(opts, report) {
  const { db } = opts;
  const now = opts.now || new Date();
  const cfg = await loadNewsConfig(db);
  if (!cfg.actif) { report.infos.actif = false; return; }
  const sources = (opts.sources || SOURCES).filter((s) => isOn(cfg, s));
  const teams = await teamsToWatch(db, now);
  const cutoff = new Date(now.getTime() - KEEP_HOURS * 3600e3).toISOString();
  const known = new Set((await db.collection('news').where('date', '>=', cutoff).get()).docs.map((d) => d.id));
  let nouveaux = 0;
  const pannes = [];
  const toPreview = []; // nouveaux articles sans image ou avec un extrait très court : on lit l'aperçu publié par le site
  const fresh = []; // nouveaux articles qui parlent d'une équipe suivie : candidats à la lecture par l'IA
  const nameOf = new Map(teams.map((t) => [t.id, t.noms[0]]));

  await Promise.all(sources.map(async (s) => {
    const st = { id: s.id, nom: s.nom, essaiLe: now.toISOString() };
    try {
      const items = await fetchFeed(s.url, opts.fetchImpl);
      const recent = items.filter((x) => x.date >= cutoff && x.date <= new Date(now.getTime() + 3600e3).toISOString())
        .filter((x) => !s.filtre || s.filtre.test(x.titre)).slice(0, MAX_PER_SOURCE);
      let n = 0;
      for (const x of recent) {
        const id = idOf(x.lien);
        if (known.has(id)) continue;
        known.add(id);
        const teamIds = teamsInTitle(x.titre, teams);
        await db.collection('news').doc(id).set({ id, titre: x.titre, lien: x.lien, source: s.nom, sourceId: s.id, lang: s.lang, date: x.date, image: x.image || null, video: !!x.video, videoId: x.videoId || null, resume: x.resume ? cleanExcerpt(x.resume) : '', teamIds });
        if (!x.image || (x.resume || '').length < 80) toPreview.push({ id, lien: x.lien, image: x.image || null, resume: x.resume || '' });
        await db.collection('news_stats').doc(id).set({ id, titre: x.titre, source: s.nom, lien: x.lien, date: x.date }, { merge: true });
        if (teamIds.length) fresh.push({ id, titre: x.titre, resume: x.resume, lang: s.lang, teamIds });
        n++;
      }
      nouveaux += n;
      Object.assign(st, { ok: true, articles: recent.length, nouveaux: n, reussiLe: now.toISOString(), erreur: null });
    } catch (e) {
      Object.assign(st, { ok: false, erreur: String(e.message || e).slice(0, 160) });
      pannes.push(`${s.nom} : ${st.erreur}`);
    }
    await db.collection('news_sources').doc(s.id).set(st, { merge: true });
  }));

  // aperçu des pages (image et description publiées par le site d'origine pour les aperçus de liens) : quelques articles par passage
  let apercus = 0;
  const queue = toPreview.slice(0, MAX_PREVIEWS);
  await Promise.all(Array.from({ length: Math.min(4, queue.length) }, async () => {
    while (queue.length) {
      const a = queue.shift();
      const pv = await fetchPreview(a.lien, opts.previewFetch || opts.fetchImpl);
      if (!pv) continue;
      const patch = {};
      if (!a.image && pv.image) patch.image = pv.image;
      if (pv.description && pv.description.length > (a.resume || '').length + 20) patch.resume = pv.description;
      if (pv.videoId) { patch.videoId = pv.videoId; patch.video = true; }
      if (Object.keys(patch).length) { await db.collection('news').doc(a.id).set(patch, { merge: true }); apercus++; }
    }
  }));
  report.infos.apercus = apercus;

  // lecture par l'IA : un fait structuré (absence, suspension, retour, entraîneur) par article qui parle d'une équipe suivie
  let aiLeft = opts.maxAiCalls == null ? MAX_AI_CALLS : opts.maxAiCalls;
  let faits = 0;
  for (const a of fresh) {
    const providers = aiLeft > 0 ? opts.providers : null;
    const candidates = a.teamIds.map((id) => ({ id, nom: nameOf.get(id) }));
    let r;
    try { r = await extractFact(a, candidates, providers); } catch { r = { fait: null, appel: false }; }
    if (r.appel) aiLeft--;
    if (r.fait) { await db.collection('news').doc(a.id).set({ fait: r.fait }, { merge: true }); faits++; }
  }
  report.infos.faits = faits;
  report.infos.appelsIA = (opts.maxAiCalls == null ? MAX_AI_CALLS : opts.maxAiCalls) - aiLeft;

  // l'historique des lectures est gardé 60 jours
  const oldStats = await db.collection('news_stats').where('date', '<', new Date(now.getTime() - 60 * 864e5).toISOString()).limit(200).get();
  for (const d of oldStats.docs) await db.collection('news_stats').doc(d.id).delete();
  // nettoyage : les articles de plus de KEEP_HOURS heures ne servent plus
  const old = await db.collection('news').where('date', '<', cutoff).limit(200).get();
  for (const d of old.docs) await db.collection('news').doc(d.id).delete();
  // une source en panne n'est pas une erreur de la tâche (suivie dans l'admin) ; toutes en panne, si
  if (pannes.length) report.infos.pannes = pannes;
  if (sources.length && pannes.length === sources.length) report.erreurs.push(`Aucune source d'actualités n'a répondu : ${pannes[0]}`);
  report.traites = nouveaux;
  report.infos.sources = sources.length;
  report.infos.supprimes = old.docs.length;
}

module.exports = { syncNews, loadNewsConfig, isOn, idOf, KEEP_HOURS };
