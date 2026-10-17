'use strict';
// API d'administration : toutes les actions vérifient côté serveur que la personne connectée figure dans la liste des administrateurs.
// L'interface (site/admin) n'est qu'un client : elle ne décide jamais de l'accès.

const { summarize } = require('../engine/bilan');
const { visitorsFromEstimates } = require('./hll');
const { slugify } = require('../data/normalize');
const { mergeSite, mergeAds, SLOTS } = require('../render/config');
const { dayStr, addDays } = require('../jobs/helpers');
const { SCHEDULE, nextRun } = require('../jobs/schedule');
const adsterra = require('../data/adsterra');
const learn = require('../engine/learn');
const { SOURCES } = require('../news/sources');
const { loadNewsConfig, isOn } = require('../jobs/syncNews');

const TASKS = ['syncFixtures', 'buildPredictions', 'syncResults', 'syncNews', 'buildRecaps', 'sendPush', 'weeklyReport', 'aiHealthCheck'];
const SITE_KEYS = ['nom', 'domaine', 'origine', 'email', 'editeur', 'adresse', 'statutJuridique', 'loi', 'hebergeur', 'indexable', 'whatsapp', 'telegram', 'googleVerification'];
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
  if (out.googleVerification !== undefined) {
    // on accepte la balise entière collée depuis Search Console ou seulement la valeur de content="…"
    const m = /content\s*=\s*["']([^"']+)["']/i.exec(out.googleVerification);
    const v = (m ? m[1] : out.googleVerification).trim();
    if (v && !/^[A-Za-z0-9_-]{10,100}$/.test(v)) throw new HttpError(400, 'Code de vérification Google invalide.');
    out.googleVerification = v;
  }
  for (const k of ['whatsapp', 'telegram']) {
    if (out[k] && !/^https:\/\/[^\s"'<>]{4,300}$/i.test(out[k])) throw new HttpError(400, `Adresse du canal ${k === 'whatsapp' ? 'WhatsApp' : 'Telegram'} invalide (https://…).`);
  }
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
      if (e.url !== undefined) {
        const u = String(e.url || '').trim();
        if (u && !/^https:\/\/[^\s"'<>]{4,480}$/i.test(u)) throw new HttpError(400, 'Adresse du lien partenaire invalide (https://… sans espace).');
        o.url = u;
      }
      if (e.titre !== undefined) o.titre = str(e.titre, 90);
      if (e.bouton !== undefined) o.bouton = str(e.bouton, 30);
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
      jours: rows, aujourdhui: at(1), sept: at(7), periode: { visites: sum('visites'), visiteurs: rows.reduce((s, r) => s + r.visiteurs, 0), pv: sum('pv'), clicsAfrolook: sum('clicsAfrolook'), aflImps: sum('aflImps'), pubVues: sum('pubVues'), couponAjouts: sum('couponAjouts'), partagesWa: sum('partagesWa'), pwaVus: sum('pwaVus'), pwaClics: sum('pwaClics'), pwaInstalles: sum('pwaInstalles'), pushOn: sum('pushOn'), pushOff: sum('pushOff') },
      pays: topList(sumMap(docs, 'pays'), 15), paysSource: sumMap(docs, 'paysSource'), pages: topList(sumMap(docs, 'pages'), 10), sources: topList(sumMap(docs, 'sources'), 10), langues: sumMap(docs, 'langues'),
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
    const rapport = await deps.tasks[b.nom]({ manuel: true });
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
    // l'apprentissage se fait toujours sur 90 jours, quelle que soit la période affichée
    const snap = await db.collection('bilan_days').where('jour', '>=', dayStr(addDays(nowD(), -90))).get();
    const all = snap.docs.map((d) => d.data()).filter((x) => x.delta);
    const sum90 = summarize(all.map((x) => x.delta));
    const diagnostic = Object.assign(learn.describe(learn.buildCalibration(sum90)), { suivis: sum90.n, seuil: learn.MIN_TOTAL });
    const from = dayStr(addDays(nowD(), -days));
    const out = summarize(all.filter((x) => x.jour >= from).map((x) => x.delta));
    delete out.cal;
    return Object.assign({ jours: days, diagnostic }, out);
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

  /** Actualités : interrupteur général, sources et leur dernier état. */
  A.actus = async () => {
    const cfg = await loadNewsConfig(db);
    const rows = await Promise.all(SOURCES.map(async (s) => {
      const st = (await db.collection('news_sources').doc(s.id).get()).data() || {};
      return { id: s.id, nom: s.nom, lang: s.lang, url: s.url, actif: isOn(cfg, s), ok: st.ok == null ? null : st.ok, erreur: st.erreur || null, essaiLe: st.essaiLe || null, reussiLe: st.reussiLe || null, articles: st.articles == null ? null : st.articles };
    }));
    return { actif: cfg.actif, images: cfg.images, recaps: cfg.recaps, sources: rows };
  };

  A['actus-save'] = async (b, by) => {
    const sources = {};
    for (const s of SOURCES) if (b.sources && b.sources[s.id] !== undefined) sources[s.id] = !!b.sources[s.id];
    await db.collection('config').doc('news').set({ actif: b.actif !== false, images: b.images !== false, recaps: b.recaps !== false, sources }, { merge: true });
    await log(by, 'actus-save', { actif: b.actif !== false, images: b.images !== false, recaps: b.recaps !== false, sources });
    if (deps.clearCache) deps.clearCache();
    return { ok: true };
  };

  /** Notifications : interrupteur, nombre d'abonnés, derniers envois. */
  A.push = async () => {
    const cfg = (await db.collection('config').doc('push').get()).data() || {};
    const col = db.collection('push_subs');
    let abonnes;
    try { abonnes = col.count ? (await col.count().get()).data().count : (await col.get()).size; } catch { abonnes = (await col.get()).size; }
    const logs = (await db.collection('push_log').orderBy('au', 'desc').limit(12).get()).docs.map((d) => d.data());
    return { actif: cfg.actif !== false, abonnes, envois: logs };
  };

  A['push-save'] = async (b, by) => {
    await db.collection('config').doc('push').set({ actif: b.actif !== false }, { merge: true });
    await log(by, 'push-save', { actif: b.actif !== false });
    return { ok: true };
  };

  A.ligues = async () => {
    const snap = await db.collection('leagues').get();
    return { ligues: snap.docs.map((d) => d.data()).sort((a, b2) => (a.ordre || 99) - (b2.ordre || 99)) };
  };

  A['ligue-ajouter'] = async (b, by) => {
    const apiId = parseInt(b.apiId, 10);
    if (!apiId) throw new HttpError(400, 'Identifiant du championnat manquant.');
    if (!deps.apiFactory) throw new HttpError(501, 'API sportive non configurée.');
    const r = await deps.apiFactory().leagues({ id: apiId });
    if (!r.length) throw new HttpError(404, 'Championnat introuvable chez le fournisseur de données (ou non inclus dans l\'offre).');
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
    if (b.noms && typeof b.noms === 'object') {
      const noms = {};
      for (const l of ['fr', 'en']) { const v = str(b.noms[l], 80); if (v) noms[l] = v; }
      upd.noms = noms;
    }
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

  /** État de chaque outil connecté : configuré, dernière réussite, dernière erreur, consommation du jour face au quota. */
  A.connexions = async () => {
    const now = nowD();
    const jour = dayStr(now);
    const get = async (col, id) => { const d = await db.collection(col).doc(id).get(); return d.exists ? d.data() : null; };
    const [api, wai, gem, siteDoc, adsDoc, today] = await Promise.all([get('connexions', 'apiFootball'), get('connexions', 'workersAi'), get('connexions', 'gemini'), get('config', 'site'), get('config', 'ads'), get('stats_days', jour)]);
    const site = mergeSite(siteDoc || {});
    const ads = mergeAds(adsDoc || {});
    const sec = deps.secretsStatus ? deps.secretsStatus() : {};
    const fresh = (d) => (d && d.jour === jour ? d : d ? Object.assign({}, d, { appelsJour: 0, erreursJour: 0, neuronsJour: 0 }) : null);
    const etat = (t) => {
      if (!t.configure) return 'non_configure';
      if (t.actif === false) return 'inactif';
      if (t.derniereErreurLe && (!t.dernierSucces || t.derniereErreurLe > t.dernierSucces)) return 'panne';
      if (t.quota && t.quota.limite && t.quota.utilise / t.quota.limite >= 0.8) return 'attention';
      if (!t.dernierSucces && t.suivi) return 'jamais';
      return 'ok';
    };
    const netCodes = (net) => Object.values(ads.emplacements).some((e) => (e.reseaux || []).some((r) => r.reseau === net && r.code));
    const pubVues = (net) => Object.entries((today && today.pub) || {}).filter(([k]) => k.includes(net)).reduce((n, [, v]) => n + v, 0);
    const A1 = fresh(api), W = fresh(wai), G = fresh(gem);
    const hist = (d) => Object.entries((d && d.historique) || {}).sort().slice(-14).map(([j, v]) => ({ jour: j, ...v }));
    const tools = [
      Object.assign(sec.source === 'football-data' ? { id: 'apiFootball', nom: 'football-data.org (offre gratuite)', role: 'Calendriers, scores et mi-temps (ni statistiques, ni cotes, ni championnats africains)', configure: !!sec.footballData, suivi: true, secret: 'FOOTBALL_DATA_TOKEN' } : { id: 'apiFootball', nom: 'API-Football', role: 'Matchs, résultats, statistiques et cotes', configure: !!sec.apiFootball, suivi: true, secret: 'API_FOOTBALL_KEY' }, A1 && { dernierSucces: A1.dernierSucces, derniereErreur: A1.derniereErreur, derniereErreurLe: A1.derniereErreurLe, appelsJour: A1.appelsJour, erreursJour: A1.erreursJour,
        quota: A1.quotaLimite ? { utilise: A1.quotaLimite - (A1.quotaRestant == null ? A1.quotaLimite : A1.quotaRestant), limite: A1.quotaLimite, unite: 'requêtes' } : null, historique: hist(A1) }),
      Object.assign({ id: 'workersAi', nom: 'Cloudflare Workers AI', role: 'Rédaction des analyses (français et anglais)', configure: !!(sec.cfToken && sec.cfAccount), suivi: true, secret: 'CF_API_TOKEN + CF_ACCOUNT_ID',
        quota: { utilise: Math.round((W && W.neuronsJour) || 0), limite: site.quotaNeurons || 10000, unite: 'neurons gratuits' } }, W && { dernierSucces: W.dernierSucces, derniereErreur: W.derniereErreur, derniereErreurLe: W.derniereErreurLe, appelsJour: W.appelsJour, erreursJour: W.erreursJour, latenceMs: W.latenceMs, historique: hist(W) }),
      Object.assign({ id: 'gemini', nom: 'Google Gemini', role: 'IA de secours si Workers AI échoue', configure: !!sec.gemini, suivi: true, secret: 'GEMINI_API_KEY' }, G && { dernierSucces: G.dernierSucces, derniereErreur: G.derniereErreur, derniereErreurLe: G.derniereErreurLe, appelsJour: G.appelsJour, erreursJour: G.erreursJour, historique: hist(G) }),
      { id: 'firebaseAuth', nom: 'Connexion Google (Firebase Authentication)', role: 'Accès à cette administration', configure: true, dernierSucces: now.toISOString() },
      { id: 'stats', nom: 'Mesure d\'audience', role: 'Compteurs sans cookie, visiteurs uniques', configure: !!sec.statsSalt, secret: 'STATS_SALT', dernierSucces: today ? now.toISOString() : null, appelsJour: (today && today.pv) || 0, unite: 'pages vues aujourd\'hui' },
      { id: 'adsterra', nom: 'Adsterra', role: 'Publicités (réseau principal) ; statistiques de revenus ' + (sec.adsterraApi ? 'connectées' : 'non connectées (ADSTERRA_API_TOKEN)'), configure: netCodes('adsterra'), actif: !!ads.actif, appelsJour: pubVues('adsterra'), unite: 'pubs affichées aujourd\'hui' },
      { id: 'monetag', nom: 'Monetag', role: 'Publicités (réseau de secours)', configure: netCodes('monetag'), actif: !!ads.actif, appelsJour: pubVues('monetag'), unite: 'pubs affichées aujourd\'hui' },
      { id: 'afrolook', nom: 'Encarts Afrolook', role: 'Promotion de l\'application', configure: true, actif: !!ads.afrolook.actif, appelsJour: (today && today.aflImps) || 0, clicsJour: (today && today.clicsAfrolook) || 0, unite: 'affichages aujourd\'hui' },
    ];
    for (const t of tools) t.etat = etat(t);
    return { outils: tools, jour };
  };

  /** Revenus Adsterra des 14 derniers jours : par jour et par emplacement (lecture seule via l'API éditeur). */
  A.revenus = async () => {
    const api = deps.adsterraFactory ? deps.adsterraFactory() : null;
    if (!api) return { connecte: false };
    const fin = dayStr(nowD()), debut = dayStr(addDays(nowD(), -13));
    let byDate, byPlacement, placements;
    try {
      [byDate, byPlacement, placements] = await Promise.all([api.stats({ start: debut, finish: fin, groupBy: 'date' }), api.stats({ start: debut, finish: fin, groupBy: 'placement' }), api.placements()]);
    } catch (e) { throw new HttpError(502, e.message); }
    const names = new Map(placements.map((p) => [String(p.id), p.title || p.alias || String(p.id)]));
    const jours = byDate.map((r) => adsterra.normalizeRow(r, 'date')).sort((a, b) => (a.cle < b.cle ? -1 : 1));
    const emplacements = byPlacement.map((r) => adsterra.normalizeRow(r, 'placement')).map((r) => Object.assign(r, { nom: names.get(r.cle) || r.cle })).sort((a, b) => b.revenu - a.revenu);
    return { connecte: true, periode: { debut, fin }, jours, emplacements, totaux: adsterra.totals(jours) };
  };

  /** Fonctionnement : chaque tâche automatique, sa cadence, son dernier passage et le prochain. */
  A.planning = async () => {
    const now = nowD();
    const out = [];
    for (const s of SCHEDULE) {
      const d = await db.collection('jobs').doc(`_dernier_${s.nom}`).get();
      const n = nextRun(s.cron, now);
      out.push({ nom: s.nom, cron: s.cron, frequence: s.frequence, role: s.role, prochain: n ? n.toISOString() : null, dernier: d.exists ? d.data() : null });
    }
    return { taches: out, maintenant: now.toISOString() };
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
