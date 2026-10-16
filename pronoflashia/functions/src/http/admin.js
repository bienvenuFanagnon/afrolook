'use strict';
// API d'administration : toutes les actions vérifient côté serveur que la personne connectée figure dans la liste des administrateurs.
// L'interface (site/admin) n'est qu'un client : elle ne décide jamais de l'accès.

const { summarize } = require('../engine/bilan');
const { visitorsFromEstimates } = require('./hll');
const { slugify } = require('../data/normalize');
const { mergeSite, mergeAds, SLOTS } = require('../render/config');
const { dayStr, addDays } = require('../jobs/helpers');

const TASKS = ['syncFixtures', 'buildPredictions', 'syncResults', 'weeklyReport', 'aiHealthCheck'];
const SITE_KEYS = ['nom', 'domaine', 'origine', 'email', 'editeur', 'adresse', 'statutJuridique', 'loi', 'hebergeur', 'indexable', 'whatsapp', 'telegram'];
const NETWORKS = ['adsterra', 'monetag'];

class HttpError extends Error { constructor(status, message) { super(message); this.status = status; } }
const str = (v, n) => String(v == null ? '' : v).trim().slice(0, n);

/** Lignes ads.txt valides : « domaine, identifiant, DIRECT|RESELLER[, identifiant de certification] » ou commentaire. */
function sanitizeAdsTxt(txt) {
  const lines = String(txt || '').split(/\r?\n/).map((l) => l.trim()).filter(Boolean);
  const bad = [];
  const ok = lines.filter((l) => {
    if (l.startsWith('#') || /^[a-z0-9._-]+=[^\s]+$/i.test(l)) return true; // commentaire ou variable (CONTACT=…)
    const good = /^[a-z0-9.-]+\.[a-z]{2,},\s*[A-Za-z0-9_.-]+,\s*(DIRECT|RESELLER)(,\s*[a-f0-9]{8,32})?(\s*#.*)?$/i.test(l);
    if (!good) bad.push(l);
    return good;
  });
  if (bad.length) throw new HttpError(400, `Ligne ads.txt invalide : ${bad[0].slice(0, 80)}`);
  return ok.join('\n').slice(0, 20000);
}

/** Balise meta de vérification de propriété : seulement <meta …>, sans script ni gestionnaire d'événement. */
function sanitizeVerification(v) {
  const s = str(v, 400);
  if (!/^<meta\s[^<>]*>$/i.test(s) || /\son\w+\s*=|javascript:|<script/i.test(s)) throw new HttpError(400, 'Balise de vérification invalide (seule une balise <meta …> est acceptée).');
  return s;
}

/** Code publicitaire collé par l'admin : du HTML de réseau publicitaire, plafonné en taille. Aucune exécution côté serveur. */
const sanitizeCode = (c) => { const s = String(c || '').trim(); if (s.length > 4000) throw new HttpError(400, 'Code publicitaire trop long (4000 caractères au plus).'); return s; };

function sanitizeSite(inp) {
  const out = {};
  for (const k of SITE_KEYS) {
    if (inp[k] === undefined) continue;
    out[k] = k === 'indexable' ? !!inp[k] : str(inp[k], 300);
  }
  if (out.origine && !/^https:\/\/[a-z0-9.-]+$/i.test(out.origine)) throw new HttpError(400, 'Origine invalide (https://domaine).');
  if (out.email && !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(out.email)) throw new HttpError(400, 'Adresse e-mail invalide.');
  return out;
}

function sanitizeAds(inp) {
  const out = {};
  if (inp.actif !== undefined) out.actif = !!inp.actif;
  if (inp.afrolook) out.afrolook = { actif: !!inp.afrolook.actif, every: Math.min(30, Math.max(3, parseInt(inp.afrolook.every, 10) || 8)), part: Math.min(100, Math.max(0, parseInt(inp.afrolook.part, 10) || 0)) };
  if (inp.adsTxt !== undefined) out.adsTxt = sanitizeAdsTxt(inp.adsTxt);
  if (inp.verifications) out.verifications = inp.verifications.map(sanitizeVerification).slice(0, 5);
  if (inp.emplacements) {
    out.emplacements = {};
    for (const [id, e] of Object.entries(inp.emplacements)) {
      if (!SLOTS[id]) continue;
      const o = { actif: !!e.actif };
      if (e.every !== undefined) o.every = Math.min(12, Math.max(2, parseInt(e.every, 10) || 4));
      if (e.delaiSec !== undefined) o.delaiSec = Math.min(120, Math.max(5, parseInt(e.delaiSec, 10) || 20));
      if (e.parJours !== undefined) o.parJours = Math.min(30, Math.max(1, parseInt(e.parJours, 10) || 1));
      if (Array.isArray(e.reseaux)) o.reseaux = e.reseaux.filter((r) => NETWORKS.includes(r.reseau) && String(r.code || '').trim()).slice(0, 3).map((r) => ({ reseau: r.reseau, code: sanitizeCode(r.code), codeMobile: sanitizeCode(r.codeMobile) }));
      out.emplacements[id] = o;
    }
  }
  return out;
}

const sumMap = (docs, field) => { const o = {}; for (const d of docs) for (const [k, v] of Object.entries(d[field] || {})) o[k] = (o[k] || 0) + (+v || 0); return o; };
const topList = (m, n) => Object.entries(m).sort((a, b) => b[1] - a[1]).slice(0, n).map(([k, v]) => ({ k, v }));

/**
 * deps : { db, verifyToken(token) → { email, email_verified }, bootstrap: [emails], tasks: { nom: async () => rapport }, apiFactory(), now, clearCache }
 */
function createAdmin(deps) {
  const { db } = deps;
  const nowD = () => (deps.now ? deps.now() : new Date());

  async function auth(header) {
    const m = /^Bearer (.+)$/.exec(header || '');
    if (!m) throw new HttpError(401, 'Connexion requise.');
    let tok;
    try { tok = await deps.verifyToken(m[1]); } catch { throw new HttpError(401, 'Session expirée : reconnecte-toi.'); }
    const email = String(tok.email || '').toLowerCase();
    if (!email || tok.email_verified === false) throw new HttpError(403, 'Adresse e-mail non vérifiée.');
    const boot = (deps.bootstrap || []).map((x) => x.toLowerCase());
    if (!boot.includes(email)) {
      const d = await db.collection('admins').doc(email).get();
      if (!d.exists) throw new HttpError(403, 'Cette adresse n\'est pas autorisée à administrer le site.');
    }
    return email;
  }

  const log = (by, action, detail) => db.collection('admin_log').doc(`${nowD().toISOString().replace(/[:.]/g, '-')}_${Math.random().toString(36).slice(2, 6)}`).set({ le: nowD().toISOString(), par: by, action, detail: detail || null });

  const A = {};

  A.me = async (b, by) => ({ email: by, bootstrap: (deps.bootstrap || []).map((x) => x.toLowerCase()).includes(by) });

  A.overview = async (b) => {
    const days = Math.min(90, Math.max(1, parseInt(b.days, 10) || 14));
    const since = dayStr(addDays(nowD(), -(days - 1)));
    const snap = await db.collection('stats_days').where('jour', '>=', since).get();
    const docs = snap.docs.map((d) => d.data()).sort((a, b2) => (a.jour < b2.jour ? -1 : 1));
    const rows = docs.map((d) => ({ jour: d.jour, visites: d.visites || 0, visiteurs: visitorsFromEstimates(d.hllEst), pv: d.pv || 0 }));
    const sum = (f) => docs.reduce((s, d) => s + (d[f] || 0), 0);
    const matchsTop = topList(sumMap(docs, 'matchs'), 10);
    const names = {};
    for (const t of matchsTop) { const m = await db.collection('matches').doc(t.k).get(); if (m.exists) { const x = m.data(); names[t.k] = `${x.domicile.nomCourt} – ${x.exterieur.nomCourt}`; } }
    const today = dayStr(nowD());
    const at = (n) => rows.filter((r) => r.jour >= dayStr(addDays(nowD(), -(n - 1)))).reduce((a, r) => ({ visites: a.visites + r.visites, visiteurs: a.visiteurs + r.visiteurs, pv: a.pv + r.pv }), { visites: 0, visiteurs: 0, pv: 0 });
    return {
      jours: rows, aujourdhui: at(1), sept: at(7), periode: { visites: sum('visites'), visiteurs: rows.reduce((s, r) => s + r.visiteurs, 0), pv: sum('pv'), clicsAfrolook: sum('clicsAfrolook'), aflImps: sum('aflImps'), pubVues: sum('pubVues'), couponAjouts: sum('couponAjouts'), partagesWa: sum('partagesWa') },
      pays: topList(sumMap(docs, 'pays'), 15), paysSource: sumMap(docs, 'paysSource'), pages: topList(sumMap(docs, 'pages'), 10), sources: topList(sumMap(docs, 'sources'), 10),
      appareils: sumMap(docs, 'appareils'), heures: sumMap(docs, 'heures'), pub: topList(sumMap(docs, 'pub'), 15), afl: topList(sumMap(docs, 'afl'), 10), aflClics: topList(sumMap(docs, 'aflClics'), 10),
      matchsTop: matchsTop.map((t) => ({ k: t.k, nom: names[t.k] || t.k, v: t.v })), jour: today,
    };
  };

  A.weeks = async () => {
    const snap = await db.collection('stats_weeks').orderBy('semaine', 'desc').limit(26).get();
    const rows = snap.docs.map((d) => d.data());
    return { semaines: rows.map((r, i) => Object.assign({}, r, { vsPrecedente: rows[i + 1] ? { visites: pctChange(r.visites, rows[i + 1].visites), pagesVues: pctChange(r.pagesVues, rows[i + 1].pagesVues), taux: r.tauxReussite != null && rows[i + 1].tauxReussite != null ? r.tauxReussite - rows[i + 1].tauxReussite : null } : null })) };
  };

  A.ia = async () => {
    const cur = await db.collection('ai_status').doc('current').get();
    const log2 = await db.collection('ai_status_log').orderBy('le', 'desc').limit(30).get();
    return { etat: cur.data() || null, historique: log2.docs.map((d) => d.data()) };
  };

  A.taches = async () => {
    const out = [];
    for (const name of TASKS) { const d = await db.collection('jobs').doc(`_dernier_${name}`).get(); out.push({ nom: name, dernier: d.data() || null }); }
    const q = out.find((t) => t.nom === 'syncFixtures' && t.dernier && t.dernier.infos);
    return { taches: out, quotaApi: q ? q.dernier.infos.quotaRestant : null };
  };

  A['tache-lancer'] = async (b, by) => {
    if (!TASKS.includes(b.nom)) throw new HttpError(400, 'Tâche inconnue.');
    if (!deps.tasks || !deps.tasks[b.nom]) throw new HttpError(501, 'Tâche indisponible.');
    await log(by, 'tache-lancer', { nom: b.nom });
    const rapport = await deps.tasks[b.nom]();
    return { ok: true, rapport };
  };

  A.pronos = async (b) => {
    const from = b.jour ? `${b.jour}T00:00:00.000Z` : dayStr(addDays(nowD(), -1)) + 'T00:00:00.000Z';
    const to = b.jour ? `${b.jour}T23:59:59.999Z` : dayStr(addDays(nowD(), 7)) + 'T23:59:59.999Z';
    const snap = await db.collection('matches').where('coupDEnvoi', '>=', from).where('coupDEnvoi', '<=', to).get();
    let rows = snap.docs.map((d) => d.data());
    if (b.ligue) rows = rows.filter((m) => m.leagueId === String(b.ligue));
    if (b.statut) rows = rows.filter((m) => m.statut === b.statut);
    rows = rows.sort((a, c) => (a.coupDEnvoi < c.coupDEnvoi ? -1 : 1)).slice(0, 300);
    return { matchs: rows.map((m) => ({ id: m.id, slug: m.slug, ligue: m.leagueNom, leagueSlug: m.leagueSlug, domicile: m.domicile.nomCourt, exterieur: m.exterieur.nomCourt, coupDEnvoi: m.coupDEnvoi, statut: m.statut, visible: !m.prono || m.prono.visible !== false, principal: m.prono && m.prono.principal ? m.prono.principal.libelle : null, confiance: m.prono && m.prono.principal ? m.prono.principal.confiance : null, source: m.prono ? m.prono.sourceTexte : null, calculeLe: m.prono ? m.prono.calculeLe : null, reussi: m.resultat ? m.resultat.reussi : null, score: m.resultat ? `${m.resultat.scoreDom}-${m.resultat.scoreExt}` : null })).filter((m) => (b.confMin ? (m.confiance || 0) >= +b.confMin : true)) };
  };

  A['prono-action'] = async (b, by) => {
    const ref = db.collection('matches').doc(str(b.id, 60));
    const cur = await ref.get();
    if (!cur.exists) throw new HttpError(404, 'Match introuvable.');
    const act = b.action;
    if (act === 'masquer') await ref.set({ prono: { visible: false, masque: true } }, { merge: true });
    else if (act === 'republier') await ref.set({ prono: { visible: true, masque: false } }, { merge: true });
    else if (act === 'regenerer') await ref.set({ prono: { aRecalculer: true } }, { merge: true });
    else if (act === 'libelle') {
      const lib = str(b.libelle, 80);
      if (!lib) throw new HttpError(400, 'Libellé vide.');
      await ref.set({ prono: { principal: { libelle: lib, manuel: true } } }, { merge: true });
    } else throw new HttpError(400, 'Action inconnue.');
    await log(by, `prono-${act}`, { id: b.id, libelle: b.libelle || null });
    if (deps.clearCache) deps.clearCache();
    return { ok: true };
  };

  A.bilan = async (b) => {
    const days = [7, 30, 90].includes(+b.days) ? +b.days : 30;
    const snap = await db.collection('bilan_days').where('jour', '>=', dayStr(addDays(nowD(), -days))).get();
    return Object.assign({ jours: days }, summarize(snap.docs.map((d) => d.data().delta).filter(Boolean)));
  };

  A.config = async () => {
    const [s, a] = await Promise.all([db.collection('config').doc('site').get(), db.collection('config').doc('ads').get()]);
    const site = mergeSite(s.data() || {});
    const manque = ['editeur', 'email', 'adresse', 'statutJuridique', 'loi'].filter((k) => !site[k]);
    return { site, ads: mergeAds(a.data() || {}), legalIncomplet: manque };
  };

  A['config-save'] = async (b, by) => {
    if (b.site) await db.collection('config').doc('site').set(sanitizeSite(b.site), { merge: true });
    if (b.ads) {
      const clean = sanitizeAds(b.ads);
      await db.collection('config').doc('ads').set(clean, { merge: true });
    }
    await log(by, 'config-save', { site: !!b.site, ads: b.ads ? { actif: b.ads.actif, emplacements: Object.keys(b.ads.emplacements || {}) } : false });
    if (deps.clearCache) deps.clearCache();
    return { ok: true };
  };

  A.ligues = async () => {
    const snap = await db.collection('leagues').get();
    return { ligues: snap.docs.map((d) => d.data()).sort((a, b2) => (a.ordre || 99) - (b2.ordre || 99)) };
  };

  A['ligue-ajouter'] = async (b, by) => {
    const apiId = parseInt(b.apiId, 10);
    if (!apiId) throw new HttpError(400, 'Identifiant API-Football manquant.');
    if (!deps.apiFactory) throw new HttpError(501, 'API sportive non configurée.');
    const r = await deps.apiFactory().leagues({ id: apiId });
    if (!r.length) throw new HttpError(404, 'Championnat introuvable chez API-Football.');
    const it = r[0];
    const seasons = it.seasons || [];
    const cur = seasons.find((s) => s.current) || seasons[seasons.length - 1];
    const doc = { apiId, nom: it.league.name, slug: slugify(it.league.name), pays: it.country && it.country.name, saison: cur ? cur.year : new Date().getUTCFullYear(), suivi: true, sport: 'football', ordre: parseInt(b.ordre, 10) || 50 };
    await db.collection('leagues').doc(String(apiId)).set(doc, { merge: true });
    await log(by, 'ligue-ajouter', { apiId, nom: doc.nom });
    if (deps.clearCache) deps.clearCache();
    return { ok: true, ligue: doc };
  };

  A['ligue-maj'] = async (b, by) => {
    const id = String(parseInt(b.apiId, 10));
    const d = await db.collection('leagues').doc(id).get();
    if (!d.exists) throw new HttpError(404, 'Championnat introuvable.');
    const upd = {};
    if (b.suivi !== undefined) upd.suivi = !!b.suivi;
    if (b.ordre !== undefined) upd.ordre = parseInt(b.ordre, 10) || 50;
    if (b.saison !== undefined) upd.saison = parseInt(b.saison, 10) || d.data().saison;
    await db.collection('leagues').doc(id).set(upd, { merge: true });
    await log(by, 'ligue-maj', { apiId: id, ...upd });
    if (deps.clearCache) deps.clearCache();
    return { ok: true };
  };

  A.admins = async () => {
    const snap = await db.collection('admins').get();
    return { admins: snap.docs.map((d) => ({ email: d.id, ...d.data() })), bootstrap: deps.bootstrap || [] };
  };
  A['admin-ajouter'] = async (b, by) => {
    const email = str(b.email, 200).toLowerCase();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) throw new HttpError(400, 'Adresse e-mail invalide.');
    await db.collection('admins').doc(email).set({ ajouteLe: nowD().toISOString(), par: by });
    await log(by, 'admin-ajouter', { email });
    return { ok: true };
  };
  A['admin-retirer'] = async (b, by) => {
    const email = str(b.email, 200).toLowerCase();
    if (email === by) throw new HttpError(400, 'Tu ne peux pas retirer ton propre accès.');
    await db.collection('admins').doc(email).delete();
    await log(by, 'admin-retirer', { email });
    return { ok: true };
  };

  A.journal = async () => {
    const snap = await db.collection('admin_log').orderBy('le', 'desc').limit(60).get();
    return { journal: snap.docs.map((d) => d.data()) };
  };

  /** Point d'entrée : action = dernier segment de /api/admin/<action>. */
  async function handle({ action, body, authorization }) {
    try {
      const by = await auth(authorization);
      if (!A[action]) throw new HttpError(404, 'Action inconnue.');
      return { status: 200, json: await A[action](body || {}, by) };
    } catch (e) {
      if (e instanceof HttpError) return { status: e.status, json: { erreur: e.message } };
      console.error('admin', action, e);
      return { status: 500, json: { erreur: 'Erreur interne : ' + (e.message || e) } };
    }
  }

  return { handle, auth, actions: Object.keys(A) };
}

const pctChange = (a, b) => (b ? Math.round(((a - b) / b) * 100) : null);

module.exports = { createAdmin, sanitizeAdsTxt, sanitizeVerification, sanitizeSite, sanitizeAds, HttpError, TASKS };
