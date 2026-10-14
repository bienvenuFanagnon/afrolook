// SlashAtlas : mesure d'audience sans cookie + liste d'attente / newsletter.
// Aucune donnée personnelle hors e-mail volontairement saisi ; aucune IP stockée.
// v2026-10-13
const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const { getStorage } = require('firebase-admin/storage');
const crypto = require('crypto');
const studio = require('./studio');
const videoApi = require('./videoApi');
const filmStudio = require('./filmStudio');
const filmRenderer = require('./filmRenderer');
const fs = require('fs');
const nodePath = require('path');
const OG_DIR = nodePath.join(__dirname, 'og');
let OG_FILES = null;

if (!getApps().length) initializeApp();
const db = getFirestore();

const CF_API_TOKEN = defineSecret('CF_API_TOKEN');
const CF_ACCOUNT_ID = defineSecret('CF_ACCOUNT_ID');

const ORIGINS = [
  /^https:\/\/slashatlas(-studio)?(--[a-z0-9-]+)?\.(web\.app|firebaseapp\.com)$/,
  /^https:\/\/(www\.)?slashatlas\.(com|app|io)$/,
  /^http:\/\/localhost(:\d+)?$/,
];
// Seule cette adresse (compte Afrolook existant, e-mail vérifié) ouvre l'administration. Aucune inscription publique.
const ADMINS = ['jorbienvenu@gmail.com'];
const LANGS = ['fr', 'en'];
const KINDS = ['newsletter', 'waitlist', 'request', 'studio'];
const BOT = /bot|crawl|spider|slurp|preview|headless|lighthouse|facebookexternalhit|curl|wget|python|monitor/i;

// Limiteur mémoire (par instance) : suffisant pour freiner les abus simples.
const hits = new Map();
function limited(key, max, windowMs) {
  const now = Date.now();
  const arr = (hits.get(key) || []).filter((t) => now - t < windowMs);
  arr.push(now);
  hits.set(key, arr);
  if (hits.size > 5000) hits.clear();
  return arr.length > max;
}

const clean = (v, n) => String(v == null ? '' : v).replace(/[\u0000-\u001f<>]/g, ' ').trim().slice(0, n);
const key = (v) => clean(v, 60).replace(/[.\/#$\[\]\s]+/g, '_') || '_';
const day = () => new Date().toISOString().slice(0, 10);

function cors(req, res) {
  const o = req.get('origin');
  if (o && ORIGINS.some((r) => r.test(o))) {
    res.set('Access-Control-Allow-Origin', o);
    res.set('Vary', 'Origin');
  }
  res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.set('Cache-Control', 'no-store');
}

function body(req) {
  let b = req.body;
  if ((!b || (typeof b === 'object' && !Object.keys(b).length)) && req.rawBody) b = req.rawBody;
  if (Buffer.isBuffer(b)) b = b.toString('utf8');
  if (typeof b === 'string') { try { b = JSON.parse(b); } catch { b = {}; } }
  return b && typeof b === 'object' ? b : {};
}

const CMDS = require('./commands.json');
let popCache = { at: 0, rows: [], totalCopies: 0 };
let pvCache = { at: 0, pv: 0 };
/** Vues totales des 90 derniers jours — cache 1 h. */
async function cachedTotalPv() {
  if (Date.now() - pvCache.at > 3600000) {
    const since = new Date(Date.now() - 90 * 864e5).toISOString().slice(0, 10);
    const q = await getFirestore().collection('SlashAtlasStats').where('day', '>=', since).get();
    pvCache = { at: Date.now(), pv: q.docs.reduce((s, d) => s + (d.data().pv || 0), 0) };
  }
  return pvCache.pv;
}
/** Commandes les plus copiées (compteur public) : lecture mise en cache 15 min côté fonction et 15 min côté CDN. */
async function popular(l) {
  if (Date.now() - popCache.at > 900000) {
    const q = await getFirestore().collection('SlashAtlasCounts').orderBy('score', 'desc').limit(150).get();
    const rows = q.docs.map((d) => ({ slug: d.id, copies: d.data().copies || 0, tries: d.data().tries || 0, views: d.data().views || 0 })).filter((r) => CMDS.commands[r.slug]);
    const totDoc = await getFirestore().collection('SlashAtlasGlobals').doc('totals').get().catch(() => null);
    const totalCopies = totDoc && totDoc.exists ? (totDoc.data().totalCopies || 0) : rows.reduce((s, r) => s + r.copies, 0);
    popCache = { at: Date.now(), rows, totalCopies };
  }
  const counts = {};
  popCache.rows.forEach((r) => { counts[r.slug] = [r.copies, r.tries, r.views]; });
  const top = popCache.rows.slice(0, 30).map((r) => {
    const c = CMDS.commands[r.slug];
    return { slug: r.slug, copies: r.copies, tries: r.tries, views: r.views, catId: c.cat, code: c.code, title: l === 'en' ? c.titleEn : c.titleFr, cat: (CMDS.cats[c.cat] || {})[l] || '', full: c.full[l], img: c.img, can: c.can, x: c.x, y: c.y, r: c.r, poster: l === 'en' ? c.posterEn : c.posterFr, ratio: c.ratio };
  });
  const globalCopies = popCache.totalCopies;
  const globalPv = await cachedTotalPv().catch(() => 0);
  return { counts, top, globalCopies, globalPv };
}
/** Compteur public par commande (copies, clics « Générer ici » et pages de détails visitées) : chaque événement compte, commandes connues seulement ; « score » sert au classement : un essai « Générer ici » vaut 10 copies, une visite de la page de détails 0,2 copie (5 visites = 1 copie). */
async function publicCount(slug, field) {
  if (!CMDS.commands[slug]) return;
  try { await getFirestore().collection('SlashAtlasCounts').doc(slug).set({ [field]: FieldValue.increment(1), score: FieldValue.increment(field === 'tries' ? 10 : field === 'views' ? 0.2 : 1), at: FieldValue.serverTimestamp() }, { merge: true }); } catch (e) { console.error('count', e.message); }
  if (field === 'copies') {
    getFirestore().collection('SlashAtlasGlobals').doc('totals').set({ totalCopies: FieldValue.increment(1) }, { merge: true }).catch((e) => console.error('gtotal', e.message));
  }
}
async function statsWrite(b, req) {
  // Les clés pointées doivent passer par update() pour créer des maps imbriquées.
  if (BOT.test(req.get('user-agent') || '')) return;
  const t = clean(b.t, 12);
  const inc = FieldValue.increment(1);
  const u = {};
  if (t === 'pv') {
    u.pv = inc;
    u[`pages.${key(b.p)}`] = inc;
    u[`lang.${LANGS.includes(b.l) ? b.l : 'x'}`] = inc;
    u[`dev.${['m', 'd', 't'].includes(b.d) ? b.d : 'x'}`] = inc;
    if (b.r) u[`ref.${key(b.r)}`] = inc;
    if (b.s) u.sessions = inc;
    if (b.tz) u[`tz.${key(b.tz)}`] = inc;
    if (b.ret) u.returning = inc;
    // Visiteur unique : première page de la session + UID anonyme fourni
    // On stocke l'UID comme clé d'un sous-map (présence = 1 visiteur distinct) dans le doc journalier
    if (b.uid && /^u[a-z0-9]{14,18}$/.test(String(b.uid))) {
      u[`uids.${String(b.uid).slice(0, 20)}`] = 1;
    }
  } else if (t === 'copy') {
    u.copies = inc;
    const slug = key(b.s || b.n);
    u[`cmd.${slug}`] = inc;
    await publicCount(slug, 'copies');
  } else if (t === 'view') { // page de détails d'une commande ouverte (une fois par visite et par commande)
    const slug = key(b.s || b.n);
    if (CMDS.commands[slug]) {
      u.views = inc;
      u[`view.${slug}`] = inc;
      await publicCount(slug, 'views');
    }
  } else if (t === 'test') {
    u.tests = inc;
    u[`tool.${key(b.tool)}`] = inc;
  } else if (t === 'try') {
    u.tries = inc;
    u[`try.${key(b.n)}`] = inc;
    await publicCount(key(b.n), 'tries');
  } else if (t === 'pwa') { // installation de l'app : affichée, acceptée, refusée, installée
    u[`pwa.${key(b.n)}`] = inc;
  } else if (t === 'video') { // lecture de la vidéo de présentation
    u.videoplays = inc;
  } else if (t === 'nopub') { // clic vers l'offre « sans pub »
    u.nopub = inc;
    u[`nopub_from.${key(b.p)}`] = inc;
  } else if (t === 'buyopen') { // fenêtre d'achat de crédits ouverte
    u.buyopen = inc;
    u[`buyopen_from.${key(b.n)}`] = inc;
  } else if (t === 'paytry') { // clic sur le bouton final « Payer » (v = 1 si le formulaire était complet)
    u.paytry = inc;
    if (b.v) u.paytry_valid = inc;
    u[`paytry_m.${key(b.m)}`] = inc;
    u[`paytry_pack.${key(b.n)}`] = inc;
    if (b.o) u[`paytry_op.${key(b.o)}`] = inc;
  } else if (t === 'cardwish') { // intérêt pour le paiement par carte (bouton « bientôt »)
    u.cardwish = inc;
    u[`cardwish_pack.${key(b.n)}`] = inc;
  } else if (t === 'share') { // partage du visuel généré (feuille native, réseau choisi, copie)
    u.shares = inc;
    u[`share_via.${key(b.n)}`] = inc;
  } else if (t === 'qr') { // QR code du client ajouté sur l'affiche (coin choisi)
    u.qrs = inc;
    u[`qr_pos.${key(b.n)}`] = inc;
  } else if (t === 'wa') { // clic vers le canal WhatsApp (emplacement : home, after, footer, toast, studio)
    u.wa = inc;
    u[`wa_from.${key(b.n)}`] = inc;
  } else if (t === 'adview') { // bloc publicitaire affiché à l'écran
    u.adviews = inc;
    u[`ad.${key(b.n)}`] = inc;
  } else if (t === 'afl_imp') { // bannière Afrolook affichée
    u.afl_imps = inc;
    u[`afl.${key(b.fmt || 'x')}`] = inc;
  } else if (t === 'afl_click') { // clic sur bannière Afrolook
    u.afl_clicks = inc;
    u[`afl_c.${key(b.fmt || 'x')}`] = inc;
  } else return;
  const ref = db.collection('SlashAtlasStats').doc(day());
  try {
    await ref.update(u);
  } catch (e) {
    if (e.code === 5 || /NOT_FOUND/.test(String(e))) {
      await ref.set({ day: day() }, { merge: true });
      await ref.update(u);
    } else throw e;
  }
}

async function subscribe(b) {
  if (b.website) return { ok: true }; // honeypot : on fait semblant
  const email = clean(b.email, 160).toLowerCase();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email)) return { error: 'email' };
  const kind = KINDS.includes(b.kind) ? b.kind : 'newsletter';
  const id = crypto.createHash('sha256').update(email).digest('hex').slice(0, 24);
  const ref = db.collection('SlashAtlasSubscribers').doc(id);
  await ref.set({
    email,
    kinds: FieldValue.arrayUnion(kind),
    lang: LANGS.includes(b.lang) ? b.lang : 'fr',
    page: clean(b.page, 80),
    ...(b.note ? { note: clean(b.note, 500) } : {}),
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  const stat = db.collection('SlashAtlasStats').doc(day());
  await stat.set({ day: day() }, { merge: true });
  await stat.update({ signups: FieldValue.increment(1), [`signupKind.${kind}`]: FieldValue.increment(1) });
  return { ok: true };
}


// ───────── comptes Google et administration ─────────
async function whoIs(req) {
  const m = /^Bearer (.+)$/.exec(req.get('authorization') || '');
  if (!m) return null;
  try {
    const t = await getAuth().verifyIdToken(m[1]);
    if (!t.email || t.email_verified !== true) return null;
    return { uid: t.uid, email: t.email.toLowerCase(), name: clean(t.name, 80), picture: clean(t.picture, 300), provider: t.firebase && t.firebase.sign_in_provider };
  } catch { return null; }
}
const isAdmin = (u) => !!u && ['password', 'google.com'].includes(u.provider) && ADMINS.includes(u.email);

const ts = (v) => (v && v.toDate ? v.toDate().toISOString() : null);
// Réglages de publicité modifiables depuis l'administration (aucun redéploiement nécessaire).
let adsCache = { at: 0, v: { enabled: false } };
async function getAds(force) {
  if (!force && Date.now() - adsCache.at < 60000) return adsCache.v;
  const s = await db.collection('SlashAtlasSettings').doc('ads').get();
  const d = s.exists ? s.data() : {};
  const slots = {};
  for (const k of ['lb', 'rect']) if (/^\d{6,20}$/.test(String((d.slots || {})[k] || ''))) slots[k] = String(d.slots[k]);
  const ok = !!d.enabled && /^ca-pub-\d{10,20}$/.test(String(d.client || '')) && Object.keys(slots).length > 0;
  const afrolook = !!d.afrolook;
  adsCache = { at: Date.now(), v: ok ? { enabled: true, client: d.client, slots, afrolook } : { enabled: false, afrolook } };
  return adsCache.v;
}
async function adminAds() {
  const s = await db.collection('SlashAtlasSettings').doc('ads').get();
  const d = s.exists ? s.data() : {};
  return { enabled: !!d.enabled, client: d.client || '', slots: { lb: (d.slots || {}).lb || '', rect: (d.slots || {}).rect || '' }, afrolook: !!d.afrolook };
}
async function saveAds(b, admin) {
  const client = clean(b.client, 40), slots = { lb: clean((b.slots || {}).lb, 20), rect: clean((b.slots || {}).rect, 20) };
  if (client && !/^ca-pub-\d{10,20}$/.test(client)) return { error: 'bad_client' };
  for (const k of Object.keys(slots)) if (slots[k] && !/^\d{6,20}$/.test(slots[k])) return { error: 'bad_slot' };
  await db.collection('SlashAtlasSettings').doc('ads').set({ enabled: !!b.enabled, client, slots, afrolook: !!b.afrolook, updatedAt: FieldValue.serverTimestamp(), by: admin.email });
  await db.collection('SlashAtlasAdminLog').add({ at: FieldValue.serverTimestamp(), by: admin.email, action: 'ads', enabled: !!b.enabled, client });
  adsCache.at = 0;
  return { ok: true };
}

async function adminData(daysIn) {
  const days = Math.min(Math.max(parseInt(daysIn, 10) || 14, 1), 90);
  const since = new Date(Date.now() - (days - 1) * 864e5).toISOString().slice(0, 10);
  const [st, subs] = await Promise.all([
    db.collection('SlashAtlasStats').where('day', '>=', since).get(),
    db.collection('SlashAtlasSubscribers').orderBy('updatedAt', 'desc').limit(300).get(),
  ]);
  const subCount = await db.collection('SlashAtlasSubscribers').count().get();
  const accCount = await db.collection('StudioUsers').count().get();
  const us = await db.collection('StudioUsers').orderBy('createdAt', 'desc').limit(50).get();
  const os = await db.collection('StudioOrders').orderBy('createdAt', 'desc').limit(50).get();
  return {
    days,
    users: us.docs.map((d) => { const x = d.data(); return { email: x.email, name: x.name || '', credits: x.credits || 0, at: ts(x.createdAt), seen: ts(x.lastSeenAt) }; }),
    ads: await adminAds(),
    orders: os.docs.map((d) => { const x = d.data(); return { id: d.id, email: x.email || '', packId: x.packId, credits: x.credits, total: x.total, provider: x.provider, operator: x.operator, status: x.status, terms: x.terms ? x.terms.version : '', at: ts(x.createdAt) }; }),
    stats: st.docs.map((d) => { const x = d.data(); return { id: d.id, ...x, visitors: Object.keys(x.uids || {}).length }; }).sort((a, b) => a.id.localeCompare(b.id)),
    studioUsers: accCount.data().count,
    subscribers: { total: subCount.data().count, items: subs.docs.map((d) => { const x = d.data(); return { email: x.email, kinds: x.kinds || [], lang: x.lang, page: x.page, note: x.note || '', at: ts(x.updatedAt) }; }) },
  };
}

async function adminUsageStats() {
  const results = {};

  // ElevenLabs — quota de caractères du compte
  const elKey = process.env.ELEVENLABS_API_KEY;
  if (elKey) {
    try {
      const r = await fetch('https://api.elevenlabs.io/v1/user/subscription', { headers: { 'xi-api-key': elKey } });
      const d = await r.json();
      results.elevenlabs = {
        character_count: d.character_count || 0,
        character_limit: d.character_limit || 0,
        tier: d.tier || null,
        next_reset: d.next_character_count_reset_unix ? new Date(d.next_character_count_reset_unix * 1000).toISOString().slice(0, 10) : null,
      };
    } catch (e) { results.elevenlabs = { error: e.message }; }
  } else { results.elevenlabs = { error: 'no_config' }; }

  // Cloudflare Workers AI — vérification du compte (ping API)
  const cfToken = String(process.env.CF_API_TOKEN || '').replace(/^﻿/, '').trim();
  const cfAccount = String(process.env.CF_ACCOUNT_ID || '').replace(/^﻿/, '').trim();
  if (cfToken && cfAccount) {
    try {
      const r = await fetch(`https://api.cloudflare.com/client/v4/accounts/${cfAccount}/ai/models/search?per_page=1`, { headers: { Authorization: `Bearer ${cfToken}` } });
      const d = await r.json();
      results.cloudflare = d.success ? { ok: true } : { error: 'api_error', msg: (d.errors || [])[0] };
    } catch (e) { results.cloudflare = { error: e.message }; }
  } else { results.cloudflare = { error: 'no_config' }; }

  // Claude API — compteur dans Firestore (mis à jour par le Studio)
  try {
    const doc = await db.collection('SlashAtlasSettings').doc('claude-usage').get();
    results.claude = doc.exists ? doc.data() : { tokens_this_month: 0, cost_usd: 0 };
  } catch (e) { results.claude = { error: e.message }; }

  return results;
}

exports.slashatlasApi = onRequest(
  { region: 'europe-west1', invoker: 'public', memory: '512MiB', maxInstances: 10, timeoutSeconds: 120, secrets: [...studio.SECRETS, CF_API_TOKEN, CF_ACCOUNT_ID] },
  async (req, res) => {
    // Aperçu de lien (WhatsApp, Facebook…) : une image tirée au hasard à chaque lecture, jamais mise en cache.
    if (req.method === 'GET' && /\/og\.jpg$/.test(req.path)) {
      try {
        if (!OG_FILES) OG_FILES = fs.readdirSync(OG_DIR).filter((f) => f.endsWith('.jpg'));
        const f = OG_FILES[Math.floor(Math.random() * OG_FILES.length)];
        res.set('Content-Type', 'image/jpeg');
        res.set('Cache-Control', 'no-store, max-age=0');
        return res.status(200).send(fs.readFileSync(nodePath.join(OG_DIR, f)));
      } catch (e) { console.error('og', e.message); return res.status(404).send(''); }
    }
    if (req.method === 'GET' && /\/ads\.txt$/.test(req.path)) {
      const a = await adminAds(); // l'identifiant éditeur est publié dès qu'il est enregistré (vérification du site), même si les blocs ne sont pas encore activés
      res.set('Content-Type', 'text/plain; charset=utf-8').set('Cache-Control', 'public, max-age=300');
      const pubs = [...new Set([a.client, 'ca-pub-4937249920200692'].filter((c) => /^ca-pub-\d{10,20}$/.test(c)))]; // compte principal de l'éditeur (application Afrolook) + compte du site
      return res.status(200).send(pubs.map((c) => `google.com, ${c.replace('ca-', '')}, DIRECT, f08c47fec0942fa0\n`).join(''));
    }
    cors(req, res);
    if (req.method === 'OPTIONS') return res.status(204).send('');
    if (req.method !== 'POST' && !(req.method === 'GET' && /\/(config|popular)$/.test(req.path))) return res.status(405).json({ error: 'method' });
    const o = req.get('origin');
    if (o && !ORIGINS.some((r) => r.test(o))) return res.status(403).json({ error: 'origin' });
    const ip = (req.get('x-forwarded-for') || req.ip || '').split(',')[0].trim();
    const ipKey = crypto.createHash('sha256').update(ip).digest('hex').slice(0, 12);
    const path = req.path.replace(/\/+$/, '');
    try {
      if (path.endsWith('/event')) {
        if (limited('e' + ipKey, 120, 60000)) return res.status(429).json({ error: 'rate' });
        await statsWrite(body(req), req);
        return res.status(204).send('');
      }
      if (path.endsWith('/subscribe')) {
        if (limited('s' + ipKey, 6, 600000)) return res.status(429).json({ error: 'rate' });
        const r = await subscribe(body(req));
        return res.status(r.error ? 400 : 200).json(r);
      }
      if (path.endsWith('/popular')) {
        res.set('Cache-Control', 'public, max-age=300, s-maxage=900');
        return res.status(200).json(await popular(req.query.l === 'en' ? 'en' : 'fr'));
      }
      if (path.endsWith('/config')) {
        res.set('Cache-Control', 'public, max-age=60');
        return res.status(200).json({ ...studio.publicConfig(), ads: await getAds() });
      }
      if (/\/video\/(script|file|list)$/.test(path)) {
        if (limited('v' + ipKey, 60, 600000)) return res.status(429).json({ error: 'rate' });
        const u = await whoIs(req);
        if (!u || u.provider !== 'google.com') return res.status(401).json({ error: 'auth' });
        if (path.endsWith('/video/script')) return res.status(200).json(await videoApi.script(u, body(req)));
        if (path.endsWith('/video/list')) return res.status(200).json(await videoApi.list(u));
        const buf = await videoApi.file(u, body(req));
        res.set('Content-Type', 'video/mp4').set('Content-Length', String(buf.length));
        return res.status(200).send(buf);
      }
      if (path.endsWith('/pay/webhook')) {
        if (limited('w' + ipKey, 120, 60000)) return res.status(429).json({ error: 'rate' });
        await studio.payWebhook(body(req));
        return res.status(200).send('OK');
      }
      if (/\/(me|referrals|generate|edit|history|regen|brand-profile|pay\/start|pay\/card|pay\/status)$/.test(path)) {
        if (limited('g' + ipKey, (path.endsWith('/generate') || path.endsWith('/edit')) ? 30 : 60, 600000)) return res.status(429).json({ error: 'rate' });
        const u = await whoIs(req);
        if (!u || u.provider !== 'google.com') return res.status(401).json({ error: 'auth' });
        if (path.endsWith('/me')) return res.status(200).json(await studio.me(u, body(req)));
        if (path.endsWith('/referrals')) return res.status(200).json(await studio.referrals(u));
        if (path.endsWith('/generate')) return res.status(200).json(await studio.generate(u, body(req)));
        if (path.endsWith('/edit')) return res.status(200).json(await studio.edit(u, body(req)));
        if (path.endsWith('/history')) return res.status(200).json(await studio.history(u));
        if (path.endsWith('/regen')) return res.status(200).json(await studio.regen(u, body(req)));
        if (path.endsWith('/brand-profile')) {
          const bp = body(req);
          if (bp.brand !== undefined || bp.contact !== undefined) return res.status(200).json(await studio.saveBrandProfile(u, bp));
          return res.status(200).json(await studio.getBrandProfile(u));
        }
        if (path.endsWith('/pay/start')) return res.status(200).json(await studio.payStart(u, body(req), { ip, ua: req.get('user-agent') }));
        if (path.endsWith('/pay/card')) return res.status(200).json(await studio.payCard(u, body(req), { ip, ua: req.get('user-agent') }));
        return res.status(200).json(await studio.payStatus(u, body(req)));
      }
      if (/\/admin\/(grant|ads)$/.test(path)) {
        if (limited('a' + ipKey, 40, 600000)) return res.status(429).json({ error: 'rate' });
        const u = await whoIs(req);
        if (!u) return res.status(401).json({ error: 'auth' });
        if (!isAdmin(u)) return res.status(403).json({ error: 'forbidden' });
        const b = body(req);
        if (path.endsWith('/ads')) { const r = await saveAds(b, u); return res.status(r.error ? 400 : 200).json(r); }
        const r = await studio.grant(b.email, b.credits, b.note);
        await db.collection('SlashAtlasAdminLog').add({ at: FieldValue.serverTimestamp(), by: u.email, action: 'grant', to: clean(b.email, 160), credits: Math.trunc(Number(b.credits)) || 0, note: clean(b.note, 120) });
        return res.status(200).json(r);
      }
      if (path.endsWith('/admin/evidence')) {
        if (limited('a' + ipKey, 40, 600000)) return res.status(429).json({ error: 'rate' });
        const u = await whoIs(req);
        if (!u) return res.status(401).json({ error: 'auth' });
        if (!isAdmin(u)) return res.status(403).json({ error: 'forbidden' });
        return res.status(200).json(await studio.evidence(body(req).orderId));
      }
      if (path.endsWith('/admin')) {
        if (limited('a' + ipKey, 40, 600000)) return res.status(429).json({ error: 'rate' });
        const u = await whoIs(req);
        if (!u) return res.status(401).json({ error: 'auth' });
        if (!isAdmin(u)) return res.status(403).json({ error: 'forbidden' });
        return res.status(200).json(await adminData(body(req).days));
      }
      if (path.endsWith('/admin/usage-stats')) {
        if (limited('a' + ipKey, 20, 600000)) return res.status(429).json({ error: 'rate' });
        const u = await whoIs(req);
        if (!u) return res.status(401).json({ error: 'auth' });
        if (!isAdmin(u)) return res.status(403).json({ error: 'forbidden' });
        return res.status(200).json(await adminUsageStats());
      }
      if (path.endsWith('/studio-film/upload-url')) {
        // Génère une URL signée pour que le frontend uploade un audio directement vers Firebase Storage
        if (limited('sfau' + ipKey, 10, 300000)) return res.status(429).json({ error: 'rate' });
        const u = await whoIs(req);
        if (!u) return res.status(401).json({ error: 'auth' });
        const b = body(req);
        const ext = /^audio\/(mpeg|wav|ogg|mp4|webm|x-m4a)$/.test(b.contentType) ? b.contentType.split('/')[1].replace('mpeg', 'mp3').replace('x-m4a', 'm4a') : null;
        if (!ext) return res.status(400).json({ error: 'bad_type' });
        const storagePath = `films-audio/${u.uid}/${Date.now()}.${ext}`;
        const [url] = await getStorage().bucket().file(storagePath).getSignedUrl({
          action: 'write',
          expires: Date.now() + 10 * 60 * 1000, // 10 minutes
          contentType: b.contentType,
        });
        return res.status(200).json({ uploadUrl: url, storagePath });
      }
      if (path.endsWith('/studio-film/create')) {
        if (limited('sf' + ipKey, 5, 300000)) return res.status(429).json({ error: 'rate' });
        const u = await whoIs(req);
        if (!u) return res.status(401).json({ error: 'auth' });
        const r = await filmStudio.createFilm(u, body(req));
        return res.status(r.status).json(r.status === 200 ? { jobId: r.jobId, seriesId: r.seriesId || null, cost: r.cost } : { error: r.error });
      }
      if (path.endsWith('/studio-film/status')) {
        if (limited('sfs' + ipKey, 30, 60000)) return res.status(429).json({ error: 'rate' });
        const u = await whoIs(req);
        if (!u) return res.status(401).json({ error: 'auth' });
        const r = await filmStudio.getFilmStatus(u, body(req).jobId);
        return res.status(r.status).json(r.status === 200 ? { status: r.jobStatus, videoUrl: r.videoUrl, title: r.title, duration: r.duration, message: r.message, seriesId: r.seriesId || null, episodeNumber: r.episodeNumber || null } : { error: r.error });
      }
      if (path.endsWith('/studio-film/series')) {
        if (limited('sfser' + ipKey, 10, 60000)) return res.status(429).json({ error: 'rate' });
        const u = await whoIs(req);
        if (!u) return res.status(401).json({ error: 'auth' });
        const r = await filmStudio.listUserSeries(u);
        return res.status(r.status).json(r.status === 200 ? { series: r.series } : { error: r.error });
      }
      if (path.endsWith('/studio-film/file')) {
        if (limited('sff' + ipKey, 10, 600000)) return res.status(429).json({ error: 'rate' });
        const u = await whoIs(req);
        if (!u) return res.status(401).json({ error: 'auth' });
        const r = await filmStudio.getFilmFile(u, body(req).jobId);
        if (!r) return res.status(404).json({ error: 'not_found' });
        res.set('Content-Type', 'video/mp4').set('Content-Length', String(r.buf.length));
        res.set('Content-Disposition', `attachment; filename="${encodeURIComponent(r.title)}.mp4"`);
        return res.status(200).send(r.buf);
      }
      return res.status(404).json({ error: 'not_found' });
    } catch (e) {
      if (e && e.status && e.code) return res.status(e.status).json({ error: e.code });
      console.error('slashatlasApi', e);
      return res.status(500).json({ error: 'server' });
    }
  },
);

// Rendu des vidéos publicitaires : fonction à part (4 Go, 2 processeurs, 9 minutes : le dessin est réparti sur les processeurs), appelée directement par le navigateur (le délai de 60 s de Hosting serait trop court).
exports.slashatlasVideo = onRequest(
  { region: 'europe-west1', invoker: 'public', memory: '4GiB', cpu: 2, concurrency: 1, maxInstances: 6, timeoutSeconds: 540, secrets: [studio.GEMINI_API_KEY] },
  async (req, res) => {
    cors(req, res);
    if (req.method === 'OPTIONS') return res.status(204).send('');
    if (req.method !== 'POST') return res.status(405).json({ error: 'method' });
    const o = req.get('origin');
    if (!o || !ORIGINS.some((r) => r.test(o))) return res.status(403).json({ error: 'origin' });
    const ip = (req.get('x-forwarded-for') || req.ip || '').split(',')[0].trim();
    const ipKey = crypto.createHash('sha256').update(ip).digest('hex').slice(0, 12);
    try {
      if (limited('r' + ipKey, 12, 600000)) return res.status(429).json({ error: 'rate' });
      const u = await whoIs(req);
      if (!u || u.provider !== 'google.com') return res.status(401).json({ error: 'auth' });
      return res.status(200).json(await videoApi.render(u, body(req)));
    } catch (e) {
      if (e && e.status && e.code) return res.status(e.status).json({ error: e.code });
      console.error('slashatlasVideo', e);
      return res.status(500).json({ error: 'server' });
    }
  },
);

// Rendu des films & séries : function dédiée (4 Go, 2 CPU, 9 minutes).
// Appelée en fire-and-forget par filmStudio.processFilm() via HTTP.
exports.slashatlasFilm = onRequest(
  { region: 'europe-west1', invoker: 'public', memory: '4GiB', cpu: 2, concurrency: 1, maxInstances: 4, timeoutSeconds: 540, secrets: [CF_API_TOKEN, CF_ACCOUNT_ID] },
  async (req, res) => {
    cors(req, res);
    if (req.method === 'OPTIONS') return res.status(204).send('');
    if (req.method !== 'POST') return res.status(405).json({ error: 'method' });
    const { jobId, token } = body(req);
    if (!jobId || !token) return res.status(400).json({ error: 'missing' });
    // Vérification du token interne (évite les appels non autorisés)
    const snap = await db.collection('FilmJobs').doc(String(jobId)).get();
    if (!snap.exists || snap.data().renderToken !== token) return res.status(403).json({ error: 'forbidden' });
    try {
      await filmRenderer.renderFilm(String(jobId), process.env.CF_ACCOUNT_ID, process.env.CF_API_TOKEN);
      return res.status(200).json({ ok: true });
    } catch (e) {
      console.error('slashatlasFilm', jobId, e);
      return res.status(500).json({ error: 'render_failed' });
    }
  },
);
