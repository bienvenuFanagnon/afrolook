// SlashAtlas Studio : comptes, crédits, génération d'images avec Gemini, paiement mobile money FeexPay.
// Règles : aucune création gratuite ; un crédit est débité avant l'appel à Gemini et rendu si la génération échoue ;
// une commande n'est créditée qu'après vérification du paiement auprès de FeexPay (jamais sur la seule foi du webhook).
const crypto = require('crypto');
const { defineSecret } = require('firebase-functions/params');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const COMMANDS = require('./commands.json');

const GEMINI_API_KEY = defineSecret('GEMINI_API_KEY');
const FEEXPAY_API_KEY = defineSecret('FEEXPAY_API_KEY');
const SECRETS = [GEMINI_API_KEY, FEEXPAY_API_KEY];

const db = () => getFirestore();
const FEEXPAY_SHOP = 'crZfM9il1xK9uJ6';
const FEEXPAY_API = 'https://api-v2.feexpay.me/api/transactions/public';
const IMAGE_MODEL = 'gemini-3.1-flash-image';

// Un crédit = une génération. Les prix sont en FCFA et comprennent les frais de FeexPay.
const GEN_COST = 1;
const PACKS = [
  { id: 'p10', credits: 10, xof: 1500 },
  { id: 'p30', credits: 30, xof: 3900, tag: 'popular' },
  { id: 'p100', credits: 100, xof: 11000 },
];
// Plafonds de sécurité (par jour, UTC)
const LIMITS = { userPerDay: 40, globalPerDay: 400 };

// Opérateurs FeexPay : code, libellé, indicatif du pays, frais de collecte (%)
const OPERATORS = [
  { code: 'mtn', label: 'MTN', country: 'Bénin', dial: '229', fee: 1.7 },
  { code: 'moov', label: 'Moov', country: 'Bénin', dial: '229', fee: 1.7 },
  { code: 'celtiis_bj', label: 'Celtiis', country: 'Bénin', dial: '229', fee: 1.7 },
  { code: 'coris', label: 'Coris', country: 'Bénin', dial: '229', fee: 1.7 },
  { code: 'togocom_tg', label: 'Togocom', country: 'Togo', dial: '228', fee: 3.0 },
  { code: 'moov_tg', label: 'Moov', country: 'Togo', dial: '228', fee: 3.0 },
  { code: 'mtn_ci', label: 'MTN', country: 'Côte d’Ivoire', dial: '225', fee: 2.0 },
  { code: 'moov_ci', label: 'Moov', country: 'Côte d’Ivoire', dial: '225', fee: 2.0 },
  { code: 'wave_ci', label: 'Wave', country: 'Côte d’Ivoire', dial: '225', fee: 2.0, redirect: true },
  { code: 'orange_ci', label: 'Orange', country: 'Côte d’Ivoire', dial: '225', fee: 2.0 },
  { code: 'orange_sn', label: 'Orange', country: 'Sénégal', dial: '221', fee: 2.0 },
  { code: 'wave_sn', label: 'Wave', country: 'Sénégal', dial: '221', fee: 2.0, redirect: true },
  { code: 'free_sn', label: 'Free', country: 'Sénégal', dial: '221', fee: 2.0, redirect: true },
  { code: 'mtn_cg', label: 'MTN', country: 'Congo-Brazzaville', dial: '242', fee: 3.0 },
  { code: 'moov_bf', label: 'Moov', country: 'Burkina Faso', dial: '226', fee: 3.2 },
  { code: 'orange_bf', label: 'Orange', country: 'Burkina Faso', dial: '226', fee: 3.2, otp: true },
  { code: 'wave_bf', label: 'Wave', country: 'Burkina Faso', dial: '226', fee: 3.2, redirect: true },
  { code: 'orange_ml', label: 'Orange', country: 'Mali', dial: '223', fee: 3.2 },
  { code: 'mobicash_ml', label: 'Mobicash', country: 'Mali', dial: '223', fee: 3.2 },
];
const opByCode = Object.fromEntries(OPERATORS.map((o) => [o.code, o]));

const day = () => new Date().toISOString().slice(0, 10);
const clean = (v, n) => String(v == null ? '' : v).replace(/[\u0000-\u001f<>]/g, ' ').trim().slice(0, n);
const fail = (status, code) => Object.assign(new Error(code), { status, code });

// ───────── comptes ─────────
/** Retrouve le compte ou le crée à la première connexion Google (jamais deux fois). */
async function me(u) {
  const ref = db().collection('StudioUsers').doc(u.uid);
  let created = false;
  let data;
  await db().runTransaction(async (tx) => {
    const s = await tx.get(ref);
    if (s.exists) {
      data = s.data();
      tx.update(ref, { lastSeenAt: FieldValue.serverTimestamp(), name: u.name || data.name || '', email: u.email });
    } else {
      created = true;
      data = { email: u.email, name: u.name || '', credits: 0 };
      tx.set(ref, { ...data, createdAt: FieldValue.serverTimestamp(), lastSeenAt: FieldValue.serverTimestamp() });
    }
  });
  if (created) {
    const stat = db().collection('SlashAtlasStats').doc(day());
    await stat.set({ day: day() }, { merge: true });
    await stat.update({ accounts: FieldValue.increment(1) });
  }
  return { uid: u.uid, email: u.email, name: u.name || data.name || '', credits: data.credits || 0, created };
}

// ───────── crédits ─────────
async function addCredits(uid, n, type, ref, meta = {}) {
  const user = db().collection('StudioUsers').doc(uid);
  const ledger = db().collection('StudioLedger').doc(`${type}_${ref}`); // identifiant fixe : jamais deux fois la même opération
  return db().runTransaction(async (tx) => {
    const l = await tx.get(ledger);
    if (l.exists) return { applied: false };
    const s = await tx.get(user);
    if (!s.exists) throw fail(404, 'no_user');
    tx.update(user, { credits: FieldValue.increment(n) });
    tx.set(ledger, { uid, delta: n, type, ref, ...meta, at: FieldValue.serverTimestamp() });
    return { applied: true };
  });
}
async function spendCredits(uid, n, ref) {
  const user = db().collection('StudioUsers').doc(uid);
  const ledger = db().collection('StudioLedger').doc(`generation_${ref}`);
  await db().runTransaction(async (tx) => {
    const s = await tx.get(user);
    if (!s.exists || (s.data().credits || 0) < n) throw fail(402, 'insufficient_credits');
    tx.update(user, { credits: FieldValue.increment(-n) });
    tx.set(ledger, { uid, delta: -n, type: 'generation', ref, at: FieldValue.serverTimestamp() });
  });
}

// ───────── génération ─────────
function composePrompt(slug, lang, product, multi, nPhotos) {
  const c = COMMANDS.commands[slug];
  if (!c) throw fail(400, 'unknown_command');
  const L = lang === 'en' ? 'en' : 'fr';
  const clause = COMMANDS.clauses[L][c.kind][multi ? 1 : 0].replace('{T}', product ? ` (${product})` : '');
  const intro = nPhotos > 1
    ? (L === 'fr' ? 'Les photos jointes montrent les éléments à réunir dans une même création. ' : 'The attached photos show the elements to bring together in a single creation. ')
    : '';
  return { text: `${intro}${c.code} : ${c[L]} ${clause}`.trim(), ratio: c.ratio };
}

async function callGemini(parts, ratio) {
  const body = { contents: [{ parts }], generationConfig: { responseModalities: ['IMAGE'], imageConfig: { aspectRatio: ratio } } };
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), 100000);
  try {
    const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${IMAGE_MODEL}:generateContent`, {
      method: 'POST', signal: ctl.signal,
      headers: { 'content-type': 'application/json', 'x-goog-api-key': GEMINI_API_KEY.value() },
      body: JSON.stringify(body),
    });
    const j = await r.json();
    if (j.error) { console.error('gemini', j.error.code, String(j.error.message).slice(0, 200)); throw fail(502, j.error.code === 402 || j.error.code === 429 ? 'busy' : 'gemini_error'); }
    const part = (j.candidates?.[0]?.content?.parts || []).find((p) => p.inlineData || p.inline_data);
    const d = part && (part.inlineData || part.inline_data);
    if (!d) { console.error('gemini sans image', JSON.stringify(j.promptFeedback || j.candidates?.[0]?.finishReason || '')); throw fail(422, 'refused'); }
    return { data: d.data, mime: d.mimeType || d.mime_type || 'image/png' };
  } finally { clearTimeout(timer); }
}

async function generate(u, b) {
  const slug = clean(b.slug, 40);
  const lang = b.lang === 'en' ? 'en' : 'fr';
  const product = clean(b.product, 60).replace(/[()]/g, '');
  const multi = b.multi === true || b.multi === 'n';
  const photos = Array.isArray(b.photos) ? b.photos.slice(0, 3) : [];
  if (!photos.length) throw fail(400, 'no_photo');
  let total = 0;
  const parts = [];
  for (const p of photos) {
    const mime = String(p && p.mime || '');
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(mime)) throw fail(400, 'bad_photo');
    const data = String(p.data || '');
    const bytes = Math.floor((data.length * 3) / 4);
    if (!data || bytes > 3 * 1024 * 1024) throw fail(413, 'photo_too_big');
    total += bytes;
    parts.push({ inlineData: { mimeType: mime, data } });
  }
  if (total > 6 * 1024 * 1024) throw fail(413, 'photo_too_big');
  const { text, ratio } = composePrompt(slug, lang, product, multi, photos.length);
  parts.push({ text });

  const id = crypto.randomBytes(10).toString('hex');
  await spendCredits(u.uid, GEN_COST, id); // lève 402 s'il n'y a pas assez de crédits (avant tout compteur : un compte sans crédit ne peut pas saturer les plafonds)
  // plafonds du jour (utilisateur et global)
  const d = day();
  const cUser = db().collection('StudioCounters').doc(`${d}_${u.uid}`);
  const cAll = db().collection('StudioCounters').doc(`${d}_all`);
  try {
    await db().runTransaction(async (tx) => {
      const [a, g] = await Promise.all([tx.get(cUser), tx.get(cAll)]);
      if ((a.exists ? a.data().n : 0) >= LIMITS.userPerDay) throw fail(429, 'daily_limit');
      if ((g.exists ? g.data().n : 0) >= LIMITS.globalPerDay) throw fail(503, 'busy');
      tx.set(cUser, { n: FieldValue.increment(1), day: d }, { merge: true });
      tx.set(cAll, { n: FieldValue.increment(1), day: d }, { merge: true });
    });
  } catch (e) { await addCredits(u.uid, GEN_COST, 'refund', id, { reason: e.code || 'limit' }); throw e; }
  const gref = db().collection('StudioGenerations').doc(id);
  await gref.set({ uid: u.uid, slug, lang, product, multi, photos: photos.length, cost: GEN_COST, status: 'pending', createdAt: FieldValue.serverTimestamp() });
  try {
    const img = await callGemini(parts, ratio);
    const ext = img.mime.includes('jpeg') ? 'jpg' : 'png';
    const path = `generations/${u.uid}/${id}.${ext}`;
    try { await getStorage().bucket().file(path).save(Buffer.from(img.data, 'base64'), { contentType: img.mime, resumable: false }); } catch (e) { console.error('storage', e.message); }
    await gref.update({ status: 'done', path, doneAt: FieldValue.serverTimestamp() });
    const stat = db().collection('SlashAtlasStats').doc(d);
    await stat.set({ day: d }, { merge: true });
    await stat.update({ generations: FieldValue.increment(1), [`gen.${slug}`]: FieldValue.increment(1) });
    const left = (await db().collection('StudioUsers').doc(u.uid).get()).data().credits || 0;
    return { id, image: img.data, mime: img.mime, credits: left };
  } catch (e) {
    await addCredits(u.uid, GEN_COST, 'refund', id, { reason: e.code || 'error' });
    await gref.update({ status: 'failed', error: e.code || 'error' });
    throw e;
  }
}

// ───────── paiement mobile money (FeexPay) ─────────
async function feexRequest(url, method, body) {
  const r = await fetch(url, { method, headers: { Authorization: `Bearer ${FEEXPAY_API_KEY.value()}`, 'Content-Type': 'application/json' }, body: body ? JSON.stringify(body) : undefined });
  let j = {}; try { j = await r.json(); } catch (e) {}
  return { ok: r.ok, status: r.status, data: j };
}

async function payStart(u, b) {
  const pack = PACKS.find((p) => p.id === b.packId);
  const op = opByCode[b.operator];
  if (!pack || !op) throw fail(400, 'bad_request');
  let phone = String(b.phone || '').replace(/[^0-9]/g, '');
  if (!phone.startsWith(op.dial)) phone = op.dial + phone;
  if (phone.length < 10 || phone.length > 15) throw fail(400, 'bad_phone');
  const otp = clean(b.otp, 12);
  if (op.otp && !otp) throw fail(400, 'otp_required');
  // L'utilisateur paie le prix affiché ; les frais FeexPay sont inclus (le montant envoyé est le net, FeexPay y ajoute ses frais).
  const amount = Math.ceil(pack.xof / (1 + op.fee / 100));
  const orderId = crypto.randomBytes(8).toString('hex');
  const oref = db().collection('StudioOrders').doc(orderId);
  await oref.set({ uid: u.uid, packId: pack.id, credits: pack.credits, price: pack.xof, amount, currency: 'XOF', provider: 'feexpay', operator: op.code, phone: `${phone.slice(0, 5)}***${phone.slice(-2)}`, status: 'created', createdAt: FieldValue.serverTimestamp() });
  const name = clean(u.name, 60).split(/\s+/);
  const payload = { shop: FEEXPAY_SHOP, amount, phoneNumber: phone, firstName: name[0] || 'Client', lastName: name.slice(1).join(' ') || 'SlashAtlas', description: `SlashAtlas ${pack.credits} credits`, callback_info: JSON.stringify({ orderId, uid: u.uid }) };
  if (otp) payload.otp = otp;
  const r = await feexRequest(`${FEEXPAY_API}/requesttopay/${op.code}`, 'POST', payload);
  const reference = r.data && r.data.reference;
  if (!r.ok || !reference) {
    console.error('feexpay start', r.status, JSON.stringify(r.data).slice(0, 300));
    await oref.update({ status: 'failed', failure: String((r.data && r.data.message) || r.status).slice(0, 200) });
    throw fail(502, 'payment_refused');
  }
  await oref.update({ status: 'processing', reference, processingAt: FieldValue.serverTimestamp() });
  return { orderId, reference, paymentUrl: r.data.payment_url || null, message: r.data.message || '' };
}

/** Vérifie la commande auprès de FeexPay et crédite le compte, une seule fois. */
async function settle(orderId) {
  const oref = db().collection('StudioOrders').doc(orderId);
  const s = await oref.get();
  if (!s.exists) throw fail(404, 'no_order');
  const o = s.data();
  if (o.status === 'paid') return { status: 'paid', credits: o.credits };
  if (o.status === 'failed') return { status: 'failed' };
  if (!o.reference) return { status: 'pending' };
  const r = await feexRequest(`${FEEXPAY_API}/single/status/${encodeURIComponent(o.reference)}`, 'GET');
  const st = String((r.data && r.data.status) || '').toUpperCase();
  if (st === 'SUCCESSFUL' || st === 'SUCCESS') {
    await addCredits(o.uid, o.credits, 'purchase', orderId, { price: o.price, currency: o.currency, operator: o.operator });
    await oref.update({ status: 'paid', paidAt: FieldValue.serverTimestamp() });
    const stat = db().collection('SlashAtlasStats').doc(day());
    await stat.set({ day: day() }, { merge: true });
    await stat.update({ orders: FieldValue.increment(1), revenueXof: FieldValue.increment(o.price) });
    return { status: 'paid', credits: o.credits };
  }
  if (st === 'FAILED') { await oref.update({ status: 'failed', failure: String(r.data.reason || '').slice(0, 200) }); return { status: 'failed' }; }
  return { status: 'pending' };
}

async function payStatus(u, b) {
  const orderId = clean(b.orderId, 40);
  const s = await db().collection('StudioOrders').doc(orderId).get();
  if (!s.exists || s.data().uid !== u.uid) throw fail(404, 'no_order');
  const r = await settle(orderId);
  const cr = (await db().collection('StudioUsers').doc(u.uid).get()).data().credits || 0;
  return { ...r, balance: cr };
}

/** Webhook FeexPay : on ne lui fait pas confiance, on ne s'en sert que pour savoir quelle commande revérifier. */
async function payWebhook(b) {
  const reference = clean(b && b.reference, 80);
  if (!reference) return;
  const q = await db().collection('StudioOrders').where('reference', '==', reference).limit(1).get();
  if (q.empty) return;
  await settle(q.docs[0].id);
}

function publicConfig() {
  return {
    genCost: GEN_COST,
    packs: PACKS,
    currency: 'XOF',
    operators: OPERATORS.map(({ code, label, country, dial, fee, redirect, otp }) => ({ code, label, country, dial, redirect: !!redirect, otp: !!otp })),
  };
}

module.exports = { SECRETS, me, generate, payStart, payStatus, payWebhook, publicConfig, fail, PACKS, OPERATORS, composePrompt, GEN_COST };
