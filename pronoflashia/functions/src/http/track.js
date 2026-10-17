'use strict';
// Mesure d'audience sans cookie : compteurs agrégés par jour dans stats_days/{AAAA-MM-JJ}. Aucune IP, aucun identifiant conservé.

const hll = require('./hll');
const tzc = require('../data/tzc.json');

const BOT = /bot|crawl|spider|slurp|preview|headless|lighthouse|facebookexternalhit|curl|wget|python|monitor|uptime|pingdom|gtmetrix/i;
const PAGES = ['accueil', 'jour', 'ligue', 'match', 'analyse', 'bilan', 'coupon', 'autre'];
const SOURCES = ['direct', 'moteur', 'social', 'afrolook', 'interne', 'autre'];
const COUNTRY_HEADERS = ['x-appengine-country', 'x-country-code', 'cf-ipcountry', 'x-vercel-ip-country', 'client-geo-region'];

const clean = (v, n) => String(v == null ? '' : v).replace(/[\u0000-\u001f<>]/g, ' ').trim().slice(0, n);
const key = (v) => clean(v, 60).replace(/[.\/#$\[\]\s:]+/g, '_') || '_';

/** Pays : d'abord l'en-tête fourni par l'infrastructure (s'il existe), sinon déduit du fuseau horaire du navigateur. */
function countryOf(headers, tz) {
  for (const h of COUNTRY_HEADERS) {
    const v = headers[h];
    if (v && /^[A-Za-z]{2}$/.test(String(v))) return { cc: String(v).toUpperCase(), source: 'entete' };
  }
  const cc = tz && tzc[String(tz).replace(/\//g, '_')];
  return cc ? { cc, source: 'fuseau' } : { cc: '??', source: 'inconnu' };
}

/** Limiteur mémoire par instance (freine les abus simples). */
const hits = new Map();
function limited(k, max, windowMs, now = Date.now()) {
  const arr = (hits.get(k) || []).filter((t) => now - t < windowMs);
  arr.push(now);
  hits.set(k, arr);
  if (hits.size > 5000) hits.clear();
  return arr.length > max;
}

/**
 * req : { body, ua, ip, headers }, deps : { db, increment(n), now, salt }.
 * Renvoie true si l'événement a été compté.
 */
async function handleEvent(req, deps) {
  const b = req.body || {};
  const ua = req.ua || '';
  const h = req.headers || {};
  if (BOT.test(ua) || h.dnt === '1') return false;
  if (limited(`ev:${req.ip}`, 60, 60000, deps.now ? deps.now.getTime() : undefined)) return false;
  const now = deps.now || new Date();
  const day = now.toISOString().slice(0, 10);
  const inc = deps.increment(1);
  const u = {};
  const t = clean(b.t, 14);
  let newsId = null, newsKind = null, sponsorId = null, sponsorKind = null;

  if (t === 'pv') {
    const page = PAGES.includes(b.p) ? b.p : 'autre';
    const country = countryOf(h, clean(b.tz, 60));
    u.pv = inc;
    u[`pages.${page}`] = inc;
    u[`pays.${country.cc}`] = inc;
    u[`paysSource.${country.source}`] = inc;
    u[`appareils.${['m', 'd', 't'].includes(b.d) ? b.d : 'x'}`] = inc;
    u[`sources.${SOURCES.includes(b.r) ? b.r : 'autre'}`] = inc;
    u[`langues.${b.l === 'en' ? 'en' : 'fr'}`] = inc;
    u[`heures.${now.getUTCHours()}`] = inc;
    if (b.m) u[`matchs.${key(b.m)}`] = inc;
    if (b.s) u.visites = inc;
  } else if (t === 'afl_imp') { u.aflImps = inc; u[`afl.${key(b.fmt || 'x')}`] = inc; }
  else if (t === 'chan_click') { u.clicsCanal = inc; u[`canal.${key(b.n || 'x')}`] = inc; }
  else if (t === 'ptn_imp') { u.ptnImps = inc; u[`ptn.${key(b.fmt || 'x')}`] = inc; }
  else if (t === 'ptn_click') { u.clicsPartenaire = inc; u[`ptnClics.${key(b.fmt || 'x')}`] = inc; }
  else if (t === 'pwa') { const n = { vu: 'pwaVus', clic: 'pwaClics', ok: 'pwaInstalles', ios: 'pwaIos' }[b.n]; if (!n) return false; u[n] = inc; }
  else if (t === 'push') { const n = { vu: 'pushVus', on: 'pushOn', off: 'pushOff', equipe: 'pushEquipes', mvu: 'pushModalVus', mno: 'pushModalNon' }[b.n]; if (!n) return false; u[n] = inc; }
  else if (t === 'mail') { if (b.n !== 'ok') return false; u.mailInscrits = inc; }
  else if (t === 'news') {
    // lecture (page de l'actu ouverte) ou clic vers l'article d'origine ; un compteur par actu, gardé 60 jours
    const nid = String(b.id || '');
    if (!/^[a-f0-9]{20}$/.test(nid) || !['vue', 'clic'].includes(b.n)) return false;
    newsId = nid; newsKind = b.n;
    if (b.n === 'vue') u.actusLues = inc; else u.clicsActus = inc;
  }
  else if (t === 'sp') {
    // sponsor direct : affichage (encart vu) ou clic ; un compteur par sponsor et par jour
    const sid = String(b.id || '');
    if (!/^s[a-f0-9]{10,16}$/.test(sid) || !['imp', 'clic'].includes(b.n)) return false;
    sponsorId = sid; sponsorKind = b.n;
    if (b.n === 'imp') u.spImps = inc; else u.spClics = inc;
  }
  else if (t === 'afl_click') { u.clicsAfrolook = inc; u[`aflClics.${key(b.fmt || 'x')}`] = inc; }
  else if (t === 'adview') { u.pubVues = inc; u[`pub.${key(b.n || 'x')}`] = inc; }
  else if (t === 'wa') { u.partagesWa = inc; u[`wa.${key(b.n || 'x')}`] = inc; }
  else if (t === 'coupon_add') { u.couponAjouts = inc; }
  else return false;

  const ref = deps.db.collection('stats_days').doc(day);
  try { await ref.update(u); } catch (e) {
    if (e.code === 5 || /NOT_FOUND/.test(String(e))) { await ref.set({ jour: day }, { merge: true }); await ref.update(u); } else throw e;
  }

  if (sponsorId) {
    await deps.db.collection('sponsor_stats').doc(`${sponsorId}_${day}`).set({ sponsor: sponsorId, jour: day, [sponsorKind === 'imp' ? 'imp' : 'clics']: deps.increment(1) }, { merge: true });
  }
  if (newsId) {
    const field = newsKind === 'vue' ? 'vues' : 'clics';
    try { await deps.db.collection('news').doc(newsId).update({ [field]: deps.increment(1) }); } catch (e) { /* l'actu n'existe plus : seul l'historique compte */ }
    await deps.db.collection('news_stats').doc(newsId).set({ id: newsId, [field]: deps.increment(1), majLe: now.toISOString() }, { merge: true });
  }

  // Visiteurs uniques : une fois par visite, empreinte salée → registre HyperLogLog (nombres seulement)
  if (t === 'pv' && b.s && deps.salt) {
    const fp = hll.fingerprint(deps.salt, day, req.ip || '', ua);
    const sref = deps.db.collection('stats_hll').doc(`${day}_${fp.shard}`);
    let est = 0;
    await deps.db.runTransaction(async (tx) => {
      const cur = await tx.get(sref);
      const reg = hll.addToRegisters(cur.exists ? cur.data().reg : null, fp.idx, fp.rank);
      est = hll.estimate(reg);
      tx.set(sref, { jour: day, shard: fp.shard, reg });
    });
    await ref.update({ [`hllEst.${fp.shard}`]: Math.round(est * 100) / 100 });
  }
  return true;
}

module.exports = { handleEvent, countryOf, key, BOT, limited };
