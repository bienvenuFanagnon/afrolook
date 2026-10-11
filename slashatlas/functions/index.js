// SlashAtlas : mesure d'audience sans cookie + liste d'attente / newsletter.
// Aucune donnée personnelle hors e-mail volontairement saisi ; aucune IP stockée.
const { onRequest } = require('firebase-functions/v2/https');
const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getAuth } = require('firebase-admin/auth');
const crypto = require('crypto');

if (!getApps().length) initializeApp();
const db = getFirestore();

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
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
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

async function statsWrite(b, req) {
  // Les clés pointées doivent passer par update() pour créer des maps imbriquées.
  if (BOT.test(req.get('user-agent') || '')) return;
  const t = clean(b.t, 8);
  const inc = FieldValue.increment(1);
  const u = {};
  if (t === 'pv') {
    u.pv = inc;
    u[`pages.${key(b.p)}`] = inc;
    u[`lang.${LANGS.includes(b.l) ? b.l : 'x'}`] = inc;
    u[`dev.${['m', 'd', 't'].includes(b.d) ? b.d : 'x'}`] = inc;
    if (b.r) u[`ref.${key(b.r)}`] = inc;
    if (b.s) u.sessions = inc;
    if (b.ret) u.returning = inc;
  } else if (t === 'copy') {
    u.copies = inc;
    u[`cmd.${key(b.n)}`] = inc;
  } else if (t === 'test') {
    u.tests = inc;
    u[`tool.${key(b.tool)}`] = inc;
  } else if (t === 'try') {
    u.tries = inc;
    u[`try.${key(b.n)}`] = inc;
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
async function adminData(daysIn) {
  const days = Math.min(Math.max(parseInt(daysIn, 10) || 14, 1), 90);
  const since = new Date(Date.now() - (days - 1) * 864e5).toISOString().slice(0, 10);
  const [st, subs] = await Promise.all([
    db.collection('SlashAtlasStats').where('day', '>=', since).get(),
    db.collection('SlashAtlasSubscribers').orderBy('updatedAt', 'desc').limit(300).get(),
  ]);
  const subCount = await db.collection('SlashAtlasSubscribers').count().get();
  return {
    days,
    stats: st.docs.map((d) => ({ id: d.id, ...d.data() })).sort((a, b) => a.id.localeCompare(b.id)),
    subscribers: { total: subCount.data().count, items: subs.docs.map((d) => { const x = d.data(); return { email: x.email, kinds: x.kinds || [], lang: x.lang, page: x.page, note: x.note || '', at: ts(x.updatedAt) }; }) },
  };
}

exports.slashatlasApi = onRequest(
  { region: 'europe-west1', invoker: 'public', memory: '256MiB', maxInstances: 5, timeoutSeconds: 15 },
  async (req, res) => {
    cors(req, res);
    if (req.method === 'OPTIONS') return res.status(204).send('');
    if (req.method !== 'POST') return res.status(405).json({ error: 'method' });
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
      if (path.endsWith('/admin')) {
        if (limited('a' + ipKey, 40, 600000)) return res.status(429).json({ error: 'rate' });
        const u = await whoIs(req);
        if (!u) return res.status(401).json({ error: 'auth' });
        if (!isAdmin(u)) return res.status(403).json({ error: 'forbidden' });
        return res.status(200).json(await adminData(body(req).days));
      }
      return res.status(404).json({ error: 'not_found' });
    } catch (e) {
      console.error('slashatlasApi', e);
      return res.status(500).json({ error: 'server' });
    }
  },
);
