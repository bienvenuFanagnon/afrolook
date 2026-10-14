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
// Modèles image en ordre de priorité : si le premier retourne 404/503, on passe au suivant
const IMAGE_MODELS = ['gemini-3.1-flash-image', 'gemini-2.5-flash-image', 'gemini-2.0-flash-preview-image-generation'];

// Un crédit = une génération (ou une correction). Prix en FCFA, hors frais de paiement (ajoutés au client).
// Coût de revient d'une génération ≈ 0,067 $ (Gemini, qualité standard) ≈ 40 FCFA à 600 FCFA le dollar : cible de marge brute d'environ 40 à 47 %.
const GEN_COST = 1;
// Vidéo pub (montage maison : photos + animations + musique + voix Google). Coût de revient réel ≈ 0,02 $ (calcul + voix + stockage), soit moins de 15 FCFA : la marge est très large.
const VIDEO_COST = { base: 4, voice: 0, cutout: 0 }; // prix unique : détourage IA, texte écrit par l'IA, voix off et musique sont compris (coût réel ≈ 0,02 à 0,25 $ selon le nombre de photos détourées par l'IA)
const VIDEO_LIMITS = { userPerDay: 8, globalPerDay: 150 };
const PACKS = [
  { id: 'p6', credits: 6, xof: 500, usd: 0.85 }, // petit pack d'entrée : mobile money seulement (frais fixes de carte trop lourds, voir CARD_LIMITS.packs)
  { id: 'p20', credits: 20, xof: 1500, usd: 2.5 },
  { id: 'p55', credits: 55, xof: 3900, usd: 6.5, tag: 'popular' },
  { id: 'p160', credits: 160, xof: 11000, usd: 18.5 },
];
// Pass « sans pub » : 30 jours sans publicité sur tout le site. Prix affiché en dollars (usd), payé en FCFA par mobile money (xof) ou en dollars par carte ; frais de paiement en plus, comme pour les crédits.
const PASS = { id: 'nopub', days: 30, xof: 1000, usd: 1.7, pass: true };
const findPack = (id) => PACKS.find((p) => p.id === id) || (id === PASS.id ? PASS : null);
// Parrainage : le parrain gagne des CRÉDITS (jamais d'argent) quand un filleul achète des crédits par mobile money.
// Calcul de rentabilité : un crédit nous coûte ≈ 40 FCFA (Gemini) et se vend 69 à 83 FCFA ; les frais de paiement sont payés par le client.
// Commission ≈ 15 % en crédits (p6 : 1, p20 : 3, p55 : 8, p160 : 24) → marge brute après commission, si tous les crédits sont utilisés :
// p6 ≈ 49 %, p20 ≈ 39 %, p55 ≈ 35 %, p160 ≈ 33 %. Aucune récompense à l'inscription (pas de faux comptes rentables), commission à chaque rechargement du filleul, sans limite de durée (chaque achat reste rentable, voir marges ci-dessus).
const REF = { credits: { p6: 1, p20: 3, p55: 8, p160: 24 }, months: 0, listMax: 50 }; // months: 0 = pas de limite de durée
const REF_ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const newRefCode = () => Array.from(crypto.randomBytes(7), (b) => REF_ALPHABET[b % REF_ALPHABET.length]).join('');
// Plafonds de sécurité (par jour, UTC)
const LIMITS = { userPerDay: 40, globalPerDay: 400 };

// Opérateurs FeexPay : frais de dépôt (payin, ajoutés par FeexPay au montant payé par le client) et de retrait (payout, que nous ajoutons
// pour que le retrait des fonds ne réduise pas le prix du pack). Mêmes taux que dans Afrolook (functions/src/shared/config.ts).
const OPERATORS = [
  { code: 'mtn', label: 'MTN', country: 'Bénin', dial: '229', payin: 1.7, payout: 1.7 },
  { code: 'moov', label: 'Moov', country: 'Bénin', dial: '229', payin: 1.7, payout: 1.7 },
  { code: 'celtiis_bj', label: 'Celtiis', country: 'Bénin', dial: '229', payin: 1.7, payout: 1.7 },
  { code: 'coris', label: 'Coris', country: 'Bénin', dial: '229', payin: 1.7, payout: 1.7 },
  { code: 'togocom_tg', label: 'Togocom', country: 'Togo', dial: '228', payin: 3.0, payout: 2.4 },
  { code: 'moov_tg', label: 'Moov', country: 'Togo', dial: '228', payin: 3.0, payout: 2.4 },
  { code: 'mtn_ci', label: 'MTN', country: 'Côte d’Ivoire', dial: '225', payin: 2.0, payout: 2.0 },
  { code: 'moov_ci', label: 'Moov', country: 'Côte d’Ivoire', dial: '225', payin: 2.0, payout: 2.0 },
  { code: 'wave_ci', label: 'Wave', country: 'Côte d’Ivoire', dial: '225', payin: 2.0, payout: 2.0, redirect: true },
  { code: 'orange_ci', label: 'Orange', country: 'Côte d’Ivoire', dial: '225', payin: 2.0, payout: 2.0 },
  { code: 'orange_sn', label: 'Orange', country: 'Sénégal', dial: '221', payin: 2.0, payout: 2.0 },
  { code: 'wave_sn', label: 'Wave', country: 'Sénégal', dial: '221', payin: 2.0, payout: 2.0, redirect: true },
  { code: 'free_sn', label: 'Free', country: 'Sénégal', dial: '221', payin: 2.0, payout: 2.0, redirect: true },
  { code: 'mtn_cg', label: 'MTN', country: 'Congo-Brazzaville', dial: '242', payin: 3.0, payout: 2.0 },
  { code: 'moov_bf', label: 'Moov', country: 'Burkina Faso', dial: '226', payin: 3.2, payout: 3.2 },
  { code: 'orange_bf', label: 'Orange', country: 'Burkina Faso', dial: '226', payin: 3.2, payout: 3.2, otp: true },
  { code: 'wave_bf', label: 'Wave', country: 'Burkina Faso', dial: '226', payin: 3.2, payout: 3.2, redirect: true },
  { code: 'orange_ml', label: 'Orange', country: 'Mali', dial: '223', payin: 3.2, payout: 3.2 },
  { code: 'mobicash_ml', label: 'Mobicash', country: 'Mali', dial: '223', payin: 3.2, payout: 3.2 },
];
// Carte bancaire (FeexPay) : désactivée tant que le KYB carte de la boutique n'est pas validé. Frais à renseigner (en %) après confirmation de FeexPay.
const CARD = { enabled: false, currency: 'USD', payin: 0, payout: 0 }; // la carte se paie en dollars (pack.usd) ; à confirmer avec FeexPay lors de l'activation du KYC carte
// Limites de sécurité carte (risque de rétrofacturation) : petits paquets seulement, quelques achats par compte, par IP, par mois et par jour.
const CARD_LIMITS = { packs: ['p20', 'p55', 'nopub'], userPerDay: 2, ipPerDay: 3, userMonthXof: 20000, globalPerDay: 30 };
const TERMS_VERSION = COMMANDS.termsVersion;
const ipHash = (ip) => crypto.createHash('sha256').update(String(ip || '')).digest('hex').slice(0, 16);
/** Preuve d'acceptation des conditions, stockée sur la commande (version, date, IP, navigateur). */
function acceptance(b, ctx) {
  if (!b || b.terms !== TERMS_VERSION) throw fail(400, 'terms_required');
  return { version: TERMS_VERSION, at: new Date().toISOString(), ip: String((ctx && ctx.ip) || '').slice(0, 64), ua: clean(ctx && ctx.ua, 200) };
}
/** Montant à envoyer à FeexPay (prix + frais de retrait) et total payé par le client (FeexPay y ajoute ses frais de dépôt). */
function quote(price, payin, payout) {
  const send = Math.ceil(price * (1 + payout / 100));
  const total = Math.ceil(send * (1 + payin / 100));
  return { send, total, fee: total - price };
}
/** Même calcul en dollars (au cent près) pour la carte. */
function quoteUsd(price, payin, payout) {
  const r2 = (n) => Math.round(n * 100) / 100;
  const send = r2(price * (1 + payout / 100));
  const total = r2(send * (1 + payin / 100));
  return { send, total, fee: r2(total - price) };
}
const opByCode = Object.fromEntries(OPERATORS.map((o) => [o.code, o]));

const day = () => new Date().toISOString().slice(0, 10);
const clean = (v, n) => String(v == null ? '' : v).replace(/[\u0000-\u001f<>]/g, ' ').trim().slice(0, n);
const fail = (status, code) => Object.assign(new Error(code), { status, code });

// ───────── comptes ─────────
/** Retrouve le compte ou le crée à la première connexion Google (jamais deux fois). */
async function me(u, opts = {}) {
  const ref = db().collection('StudioUsers').doc(u.uid);
  let created = false;
  let data;
  const wanted = /^[A-Z0-9]{7}$/.test(String(opts.ref || '').toUpperCase()) ? String(opts.ref).toUpperCase() : '';
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
    if (wanted) await attachReferrer(u, wanted).catch((e) => console.error('referral attach', e && e.message));
  }
  const code = await ensureRefCode(u.uid);
  return { uid: u.uid, email: u.email, name: u.name || data.name || '', credits: data.credits || 0, adFreeUntil: data.adFreeUntil || 0, created, refCode: code };
}

// ───────── parrainage ─────────
/** Code de parrainage du compte (créé une seule fois) et table de correspondance code → compte. */
async function ensureRefCode(uid) {
  const user = db().collection('StudioUsers').doc(uid);
  const cur = (await user.get()).data() || {};
  if (cur.refCode) return cur.refCode;
  for (let i = 0; i < 6; i++) {
    const code = newRefCode();
    const cref = db().collection('StudioRefCodes').doc(code);
    const ok = await db().runTransaction(async (tx) => {
      const [c, u2] = await Promise.all([tx.get(cref), tx.get(user)]);
      if (u2.data() && u2.data().refCode) return u2.data().refCode;
      if (c.exists) return null;
      tx.set(cref, { uid, at: FieldValue.serverTimestamp() });
      tx.update(user, { refCode: code });
      return code;
    });
    if (ok) return ok;
  }
  return '';
}
/** Rattache un compte qui vient d'être créé à son parrain (une seule fois, jamais à soi-même). */
async function attachReferrer(u, code) {
  const c = await db().collection('StudioRefCodes').doc(code).get();
  if (!c.exists || c.data().uid === u.uid) return false;
  const parrain = (await db().collection('StudioUsers').doc(c.data().uid).get()).data();
  if (!parrain || (parrain.email || '').toLowerCase() === String(u.email || '').toLowerCase()) return false;
  const rref = db().collection('StudioReferrals').doc(u.uid);
  const made = await db().runTransaction(async (tx) => {
    if ((await tx.get(rref)).exists) return false;
    tx.set(rref, { referrer: c.data().uid, referee: u.uid, name: String(u.name || u.email || '').split(' ')[0].slice(0, 20), emailMask: maskEmail(u.email), code, createdAt: FieldValue.serverTimestamp(), bought: false, earned: 0, orders: 0 });
    tx.update(db().collection('StudioUsers').doc(u.uid), { referredBy: c.data().uid });
    tx.update(db().collection('StudioUsers').doc(c.data().uid), { refCount: FieldValue.increment(1) });
    return true;
  });
  if (made) await bump({ referrals: 1 });
  return made;
}
const maskEmail = (e) => { const [a, d] = String(e || '').split('@'); return a ? `${a.slice(0, 2)}***@${(d || '').slice(0, 1)}***` : ''; };
/** Commission en crédits pour le parrain d'un acheteur, une seule fois par commande (journal à identifiant fixe). */
async function referralReward(o, orderId) {
  if (!o || o.days || !o.credits || o.provider === 'feexpay_card') return; // pass sans pub et cartes (risque de rétrofacturation) : pas de commission
  const n = REF.credits[o.packId] || 0; if (!n) return;
  const rref = db().collection('StudioReferrals').doc(o.uid);
  const rs = await rref.get(); if (!rs.exists) return;
  const r = rs.data();
  const created = r.createdAt && r.createdAt.toMillis ? r.createdAt.toMillis() : Date.now();
  if (REF.months && Date.now() > created + REF.months * 30.5 * 86400000) return;
  const res = await addCredits(r.referrer, n, 'referral', orderId, { from: o.uid, packId: o.packId });
  if (!res.applied) return;
  await db().runTransaction(async (tx) => {
    const x = (await tx.get(rref)).data();
    tx.update(rref, { earned: FieldValue.increment(n), orders: FieldValue.increment(1), bought: true, lastAt: FieldValue.serverTimestamp() });
    tx.update(db().collection('StudioUsers').doc(r.referrer), { refCredits: FieldValue.increment(n), ...(x.bought ? {} : { refBuyers: FieldValue.increment(1) }) });
  });
  await bump({ referral_credits: n });
}
/** Tableau de bord du parrain : lien, nombre de filleuls, acheteurs, crédits gagnés, derniers filleuls. */
async function referrals(u) {
  const code = await ensureRefCode(u.uid);
  const d = (await db().collection('StudioUsers').doc(u.uid).get()).data() || {};
  const q = await db().collection('StudioReferrals').where('referrer', '==', u.uid).limit(REF.listMax).get();
  const items = q.docs.map((x) => { const r = x.data(); return { name: r.name || r.emailMask || '—', at: r.createdAt && r.createdAt.toMillis ? r.createdAt.toMillis() : 0, bought: !!r.bought, earned: r.earned || 0 }; }).sort((a, b) => b.at - a.at);
  return { code, count: d.refCount || 0, buyers: d.refBuyers || 0, credits: d.refCredits || 0, items, rule: { credits: REF.credits, months: REF.months } };
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
/** Prolonge le pass « sans pub » (à partir de la fin du pass en cours s'il court encore) ; une même commande ne compte qu'une fois. */
async function addAdFree(uid, days, ref, meta = {}) {
  const user = db().collection('StudioUsers').doc(uid);
  const ledger = db().collection('StudioLedger').doc(`adfree_${ref}`);
  return db().runTransaction(async (tx) => {
    const l = await tx.get(ledger);
    const s = await tx.get(user);
    if (!s.exists) throw fail(404, 'no_user');
    if (l.exists) return { applied: false, until: s.data().adFreeUntil || 0 };
    const until = Math.max(Date.now(), s.data().adFreeUntil || 0) + days * 86400000;
    tx.update(user, { adFreeUntil: until });
    tx.set(ledger, { uid, delta: 0, days, type: 'adfree', ref, until, ...meta, at: FieldValue.serverTimestamp() });
    return { applied: true, until };
  });
}
async function spendCredits(uid, n, ref, ledgerId) {
  const user = db().collection('StudioUsers').doc(uid);
  const docId = ledgerId ? `generation_${ledgerId}` : `generation_${ref}`;
  const ledger = db().collection('StudioLedger').doc(docId);
  await db().runTransaction(async (tx) => {
    const s = await tx.get(user);
    if (!s.exists || (s.data().credits || 0) < n) throw fail(402, 'insufficient_credits');
    tx.update(user, { credits: FieldValue.increment(-n) });
    tx.set(ledger, { uid, delta: -n, type: 'generation', ref, at: FieldValue.serverTimestamp() });
  });
  return true;
}

// ───────── génération ─────────
/** Marque et contacts à inscrire sur le visuel : trois champs fixes (marque, contact, autre), assainis ici ; les modèles viennent de commands.json, partagés avec le site. */
const BRAND_MAX = { brand: 60, contact: 60, other: 80 };
function cleanTexts(t) {
  const o = [];
  for (const role of ['brand', 'contact', 'other']) {
    const v = String((t && t[role]) || '').replace(/[«»"“”\u0000-\u001f]/g, ' ').replace(/\s+/g, ' ').trim().slice(0, BRAND_MAX[role]);
    if (v) o.push({ role, text: v });
  }
  return o;
}
function brandClause(kind, lang, texts) {
  const B = COMMANDS.brand && COMMANDS.brand[lang];
  if (!B || !texts.length || !B.kind[kind]) return '';
  const names = texts.map((r) => `${B.names[r.role]} « ${r.text} »`).join(' ; ');
  const lay = `${B.lay}${texts.map((r) => B.place[r.role]).join(' ; ')}. ${B.kind[kind]}`;
  return `${B.intro.replace('{L}', names)} ${lay} ${B.outro}`;
}
const QR_CORNER = { auto: ['inférieur droit', 'bottom-right'], br: ['inférieur droit', 'bottom-right'], bl: ['inférieur gauche', 'bottom-left'], tr: ['supérieur droit', 'top-right'], tl: ['supérieur gauche', 'top-left'] };
function qrClause(lang, pos) {
  const c = QR_CORNER[pos];
  if (!c) return '';
  const pref = pos === 'auto';
  return lang === 'en'
    ? `Leave the ${pref ? 'bottom-right corner (or, if the composition requires it, another calm corner)' : c[1] + ' corner'} of the visual completely free, a small area of about 15% of the width and 20% of the height, with no text, no important element and no detail of the subject: a small QR code will be added there afterwards. Keep any contact text away from that corner. Do not write or draw any QR code yourself.`
    : `Laisse entièrement libre ${pref ? 'le coin inférieur droit du visuel (ou, si la composition l’exige, un autre coin calme)' : 'le coin ' + c[0] + ' du visuel'}, une petite zone d’environ 15 % de la largeur et 20 % de la hauteur, sans texte, sans élément important ni détail du sujet : un petit code QR y sera ajouté après coup. Éloigne de ce coin les textes de contact éventuels. N’écris et ne dessine aucun code QR toi-même.`;
}
/** Retouche automatique d'une photo (base64) : niveaux, lumière, couleurs, netteté, agrandissement doux des petites photos. Retourne du JPEG en base64, ou null si impossible. */
async function polishPhoto(b64) {
  const { loadImage, createCanvas } = require('@napi-rs/canvas');
  const { enhance } = require('./enhance');
  const im = await loadImage(Buffer.from(b64, 'base64'));
  if (!im.width || !im.height || Math.max(im.width, im.height) > 4000) return null;
  const cv = createCanvas(im.width, im.height); cv.getContext('2d').drawImage(im, 0, 0);
  return enhance(cv, { minSide: 1024, maxSide: 1600, strength: 0.85 }).toBuffer('image/jpeg', 92).toString('base64');
}

function composePrompt(slug, lang, product, multi, nPhotos, texts = [], qrpos = '', sale = false, stagingInstruction = '') {
  const c = COMMANDS.commands[slug];
  if (!c) throw fail(400, 'unknown_command');
  if (['video', 'motion', 'text', 'poster', 'free'].includes(c.kind) || /[\[«]/.test(c.fr + c.en)) throw fail(400, 'not_image'); // vidéo, affiches à texte et commandes sans photo ne passent pas par le Studio d'images
  const L = lang === 'en' ? 'en' : 'fr';
  const clause = COMMANDS.clauses[L][c.kind][multi ? 1 : 0].replace('{T}', product ? ` (${product})` : '');
  const intro = nPhotos > 1
    ? (L === 'fr' ? 'Les photos jointes montrent les éléments à réunir dans une même création. ' : 'The attached photos show the elements to bring together in a single creation. ')
    : '';
  const brand = brandClause(c.kind, L, texts);
  const qr = qrClause(L, qrpos);
  // affiche de vente : le prix, le contact, le QR et l’étiquette sont ajoutés par le site après la génération ; l’IA garde le bas dégagé et n’écrit rien
  const saleClause = sale ? (L === 'en' ? 'Composition for a sales advertisement: keep the subject large and centered slightly above the middle, and keep the bottom quarter of the image calm and uncluttered. The price, contact details, label and a small QR code will be added afterwards: write no text on the image.' : "Composition pour une annonce de vente : garde le sujet grand et centré légèrement au-dessus du milieu, et garde le quart inférieur de l'image calme et dégagé. Le prix, les contacts, l'étiquette et un petit QR code seront ajoutés ensuite : n'écris aucun texte sur l'image.") : '';
  // instruction de mise en scène libre (fond, ambiance, personnage, etc.)
  const stagingClause = stagingInstruction ? (L === 'fr' ? `Instruction de mise en scène : ${stagingInstruction}` : `Scene instruction: ${stagingInstruction}`) : '';
  // qualité studio, propre au Studio : rendu photo premium, fidélité au produit, aucun ajout non demandé
  const quality = L === 'en'
    ? 'Studio quality: premium commercial photographic rendering, careful lighting, sharp details, colors faithful to the photo. The product stays strictly identical (shape, colors, logo, details); add no object, text or watermark that was not requested.'
    : "Qualité studio : rendu photographique commercial premium, lumière soignée, détails nets, couleurs fidèles à la photo. Le produit reste strictement identique (forme, couleurs, logo, détails) ; n'ajoute aucun objet, texte ou filigrane qui n'a pas été demandé.";
  return { text: `${intro}${c.code} : ${c[L]} ${clause}${brand ? ' ' + brand : ''}${qr ? ' ' + qr : ''}${stagingClause ? ' ' + stagingClause : ''}${saleClause ? ' ' + saleClause : ''} ${quality}`.trim(), ratio: c.ratio };
}

async function callGemini(parts, ratio) {
  const body = { contents: [{ parts }], generationConfig: { responseModalities: ['IMAGE'], imageConfig: { aspectRatio: ratio } } };
  let lastErr = null;
  for (const model of IMAGE_MODELS) {
    const ctl = new AbortController();
    const timer = setTimeout(() => ctl.abort(), 100000);
    try {
      const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
        method: 'POST', signal: ctl.signal,
        headers: { 'content-type': 'application/json', 'x-goog-api-key': GEMINI_API_KEY.value() },
        body: JSON.stringify(body),
      });
      const j = await r.json();
      if (j.error) {
        const code = j.error.code;
        console.error('gemini', model, code, String(j.error.message).slice(0, 200));
        // 404 = modèle introuvable → essayer le suivant
        if (code === 404) { lastErr = fail(502, 'gemini_unavailable'); continue; }
        throw fail(502, code === 402 || code === 429 ? 'busy' : 'gemini_error');
      }
      const part = (j.candidates?.[0]?.content?.parts || []).find((p) => p.inlineData || p.inline_data);
      const d = part && (part.inlineData || part.inline_data);
      if (!d) { console.error('gemini sans image', model, JSON.stringify(j.promptFeedback || j.candidates?.[0]?.finishReason || '')); throw fail(422, 'refused'); }
      return { data: d.data, mime: d.mimeType || d.mime_type || 'image/png' };
    } finally { clearTimeout(timer); }
  }
  throw lastErr || fail(502, 'gemini_unavailable');
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
  // Rendu optimisé SlashAtlas : la photo est retouchée avant d'être donnée à l'IA (lumière, couleurs, netteté, taille). Une photo sombre ou terne donne un résultat terne.
  let polished = 0;
  for (const part of parts) { try { const r = await polishPhoto(part.inlineData.data); if (r) { part.inlineData = { mimeType: 'image/jpeg', data: r }; polished++; } } catch (e) { console.error('polish', e && e.message); } }
  const texts = cleanTexts(b.texts);
  const qrpos = QR_CORNER[b.qrpos] ? b.qrpos : '';
  const sale = b.sale === true;
  const stagingInstruction = clean(b.stagingInstruction || '', 200);
  const { text, ratio } = composePrompt(slug, lang, product, multi, photos.length, texts, qrpos, sale, stagingInstruction);
  parts.push({ text });

  // Paramètres de l'affiche de vente pour l'historique (jamais dans le prompt IA)
  let saleOpts = null;
  if (sale && b.saleOpts && typeof b.saleOpts === 'object') {
    const so = b.saleOpts;
    saleOpts = {
      model: clean(String(so.model || ''), 20) || null,
      tag: clean(String(so.tag || ''), 20),
      price: clean(String(so.price || ''), 20),
      cur: clean(String(so.cur || ''), 10),
      old: clean(String(so.old || ''), 20),
      disc: clean(String(so.disc || ''), 12),
      brand: clean(String(so.brand || ''), 60),
      contact: clean(String(so.contact || ''), 60),
      qr: clean(String(so.qr || ''), 200),
      qrSize: so.qrSize === 'm' ? 'm' : 's',
    };
  }

  return runJob(u, parts, ratio, { slug, lang, product, multi, photos: photos.length, brand: texts.length, qr: qrpos, sale, polished, ...(saleOpts ? { saleOpts } : {}) });
}

/** Débit, plafonds, appel Gemini, stockage, remboursement en cas d'échec : commun à « générer » et « modifier ». */
async function runJob(u, parts, ratio, meta) {
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
  await gref.set({ uid: u.uid, ratio, cost: GEN_COST, status: 'pending', createdAt: FieldValue.serverTimestamp(), ...meta });
  try {
    const img = await callGemini(parts, ratio);
    const ext = img.mime.includes('jpeg') ? 'jpg' : 'png';
    const path = `generations/${u.uid}/${id}.${ext}`;
    try { await getStorage().bucket().file(path).save(Buffer.from(img.data, 'base64'), { contentType: img.mime, resumable: false }); } catch (e) { console.error('storage', e.message); }
    await gref.update({ status: 'done', path, mime: img.mime, doneAt: FieldValue.serverTimestamp() });
    const stat = db().collection('SlashAtlasStats').doc(d);
    await stat.set({ day: d }, { merge: true });
    await stat.update(meta.parent ? { edits: FieldValue.increment(1) } : { generations: FieldValue.increment(1), [`gen.${meta.slug}`]: FieldValue.increment(1) });
    const left = (await db().collection('StudioUsers').doc(u.uid).get()).data().credits || 0;
    return { id, image: img.data, mime: img.mime, credits: left };
  } catch (e) {
    await addCredits(u.uid, GEN_COST, 'refund', id, { reason: e.code || 'error' });
    await gref.update({ status: 'failed', error: e.code || 'error' });
    await bump({ genfails: 1 });
    throw e;
  }
}

/** Corriger ou modifier une image déjà générée : un crédit, comme une génération. L'image de départ est relue côté serveur (jamais envoyée par le client). */
async function edit(u, b) {
  const parentId = clean(b.id, 40);
  const instruction = clean(b.instruction, 300);
  const lang = b.lang === 'en' ? 'en' : 'fr';
  if (instruction.length < 3) throw fail(400, 'no_instruction');
  const ps = await db().collection('StudioGenerations').doc(parentId).get();
  const p = ps.exists ? ps.data() : null;
  if (!p || p.uid !== u.uid || p.status !== 'done' || !p.path) throw fail(404, 'no_image');
  let buf;
  try { [buf] = await getStorage().bucket().file(p.path).download(); } catch (e) { console.error('storage read', e.message); throw fail(404, 'no_image'); }
  const text = lang === 'fr'
    ? `Modifie l’image jointe selon cette demande : « ${instruction} ». Garde tout le reste identique (produit ou personnes, composition, cadrage, format). N’ajoute aucun texte sauf si la demande le précise.`
    : `Edit the attached image according to this request: “${instruction}”. Keep everything else identical (product or people, composition, framing, format). Add no text unless the request says so.`;
  const parts = [{ inlineData: { mimeType: p.mime || 'image/png', data: buf.toString('base64') } }, { text }];
  return runJob(u, parts, p.ratio || '1:1', { slug: p.slug, lang, parent: parentId, instruction });
}

// ───────── paiement mobile money (FeexPay) ─────────
async function feexRequest(url, method, body) {
  const r = await fetch(url, { method, headers: { Authorization: `Bearer ${FEEXPAY_API_KEY.value()}`, 'Content-Type': 'application/json' }, body: body ? JSON.stringify(body) : undefined });
  let j = {}; try { j = await r.json(); } catch (e) {}
  return { ok: r.ok, status: r.status, data: j };
}

/** Compteur du jour (tableau de bord) : n'interrompt jamais un achat si l'écriture échoue. */
async function bump(fields) {
  try {
    const stat = db().collection('SlashAtlasStats').doc(day());
    await stat.set({ day: day() }, { merge: true });
    await stat.update(Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, FieldValue.increment(v)])));
  } catch (e) { console.error('bump', e.message); }
}

async function payStart(u, b, ctx) {
  const terms = acceptance(b, ctx);
  const pack = findPack(b.packId);
  const op = opByCode[b.operator];
  if (!pack || !op) throw fail(400, 'bad_request');
  let phone = String(b.phone || '').replace(/[^0-9]/g, '');
  if (!phone.startsWith(op.dial)) phone = op.dial + phone;
  if (phone.length < 10 || phone.length > 15) throw fail(400, 'bad_phone');
  const otp = clean(b.otp, 12);
  if (op.otp && !otp) throw fail(400, 'otp_required');
  // Le client paie les frais : nous envoyons prix + frais de retrait, FeexPay ajoute ses frais de dépôt.
  const q = quote(pack.xof, op.payin, op.payout);
  const amount = q.send;
  const orderId = crypto.randomBytes(8).toString('hex');
  const oref = db().collection('StudioOrders').doc(orderId);
  await oref.set({ uid: u.uid, packId: pack.id, credits: pack.credits || 0, days: pack.days || 0, price: pack.xof, amount, total: q.total, currency: 'XOF', provider: 'feexpay', operator: op.code, phone: `${phone.slice(0, 5)}***${phone.slice(-2)}`, email: u.email || '', terms, status: 'created', createdAt: FieldValue.serverTimestamp() });
  await bump({ orders_created: 1, [`orders_created_op.${op.code}`]: 1 });
  const name = clean(u.name, 60).split(/\s+/);
  const payload = { shop: FEEXPAY_SHOP, amount, phoneNumber: phone, firstName: name[0] || 'Client', lastName: name.slice(1).join(' ') || 'SlashAtlas', description: pack.days ? `SlashAtlas no ads ${pack.days} days` : `SlashAtlas ${pack.credits} credits`, callback_info: JSON.stringify({ orderId, uid: u.uid }) };
  if (otp) payload.otp = otp;
  const r = await feexRequest(`${FEEXPAY_API}/requesttopay/${op.code}`, 'POST', payload);
  const reference = r.data && r.data.reference;
  if (!r.ok || !reference) {
    console.error('feexpay start', r.status, JSON.stringify(r.data).slice(0, 300));
    await oref.update({ status: 'failed', failure: String((r.data && r.data.message) || r.status).slice(0, 200) });
    await bump({ orders_failed: 1 });
    throw fail(502, 'payment_refused');
  }
  await oref.update({ status: 'processing', reference, processingAt: FieldValue.serverTimestamp() });
  return { orderId, reference, total: q.total, paymentUrl: r.data.payment_url || null, message: r.data.message || '' };
}


async function cardGuard(u, pack, ctx) {
  if (!CARD_LIMITS.packs.includes(pack.id)) throw fail(400, 'card_pack_limited');
  const since = (ms) => new Date(Date.now() - ms);
  const col = db().collection('StudioOrders');
  const day = await col.where('createdAt', '>=', since(86400000)).get(); // un seul champ : pas d'index composite à créer
  const valid = day.docs.map((d) => d.data()).filter((o) => o.provider === 'feexpay_card' && o.status !== 'failed');
  if (valid.length >= CARD_LIMITS.globalPerDay) throw fail(429, 'card_limit');
  if (valid.filter((o) => o.uid === u.uid).length >= CARD_LIMITS.userPerDay) throw fail(429, 'card_limit');
  const h = ipHash(ctx && ctx.ip);
  if (valid.filter((o) => o.ipHash === h).length >= CARD_LIMITS.ipPerDay) throw fail(429, 'card_limit');
  const month = await col.where('uid', '==', u.uid).get();
  const from = since(30 * 86400000).getTime();
  const spent = month.docs.map((d) => d.data()).filter((o) => o.provider === 'feexpay_card' && o.status === 'paid' && o.createdAt && o.createdAt.toMillis() >= from).reduce((a, o) => a + (o.price || 0), 0);
  if (spent + pack.xof > CARD_LIMITS.userMonthXof) throw fail(429, 'card_limit');
  return h;
}

async function payCard(u, b, ctx) {
  if (!CARD.enabled) throw fail(503, 'card_unavailable');
  const terms = acceptance(b, ctx);
  const pack = findPack(b.packId);
  if (!pack) throw fail(400, 'bad_request');
  const ipH = await cardGuard(u, pack, ctx);
  const first = clean(b.firstName, 40), last = clean(b.lastName, 40), city = clean(b.city, 60), zip = clean(b.zip, 12);
  const country = String(b.country || '').toUpperCase();
  let phone = String(b.phone || '').replace(/[^0-9]/g, '');
  if (!first || !last || !city || !zip || !/^[A-Z]{2}$/.test(country) || phone.length < 8 || phone.length > 15) throw fail(400, 'bad_card_info');
  const q = quoteUsd(pack.usd, CARD.payin, CARD.payout);
  const orderId = crypto.randomBytes(8).toString('hex');
  const oref = db().collection('StudioOrders').doc(orderId);
  await oref.set({ uid: u.uid, packId: pack.id, credits: pack.credits || 0, days: pack.days || 0, price: pack.xof, priceUsd: pack.usd, amount: q.send, total: q.total, currency: CARD.currency, provider: 'feexpay_card', operator: 'card', email: u.email || '', ipHash: ipH, terms, status: 'created', createdAt: FieldValue.serverTimestamp() });
  await bump({ orders_created: 1, 'orders_created_op.card': 1 });
  const payload = { shop: FEEXPAY_SHOP, amount: String(q.send), currency: CARD.currency, first_name: first, last_name: last, email: u.email, phoneNumber: phone, city, zip, country, description: pack.days ? `SlashAtlas no ads ${pack.days} days` : `SlashAtlas ${pack.credits} credits`, callback_info: JSON.stringify({ orderId, uid: u.uid }) };
  // Collecte par carte (API v2) : même famille que le mobile money, point d'entrée « init » ; exige le KYC carte validé (sinon CARD_PAYMENT_NOT_AUTHORIZED).
  const r = await feexRequest(`${FEEXPAY_API}/requesttopay/init`, 'POST', payload);
  const reference = r.data && r.data.reference;
  const url = r.data && (r.data.payment_url || r.data.paymentUrl);
  if (!r.ok || !reference || !url) {
    console.error('feexpay card', r.status, JSON.stringify(r.data).slice(0, 300));
    await oref.update({ status: 'failed', failure: String((r.data && r.data.message) || r.status).slice(0, 200) });
    await bump({ orders_failed: 1 });
    throw fail(502, 'payment_refused');
  }
  await oref.update({ status: 'processing', reference, processingAt: FieldValue.serverTimestamp() });
  return { orderId, reference, total: q.total, paymentUrl: url };
}

/** Vérifie la commande auprès de FeexPay et crédite le compte, une seule fois. */
async function settle(orderId) {
  const oref = db().collection('StudioOrders').doc(orderId);
  const s = await oref.get();
  if (!s.exists) throw fail(404, 'no_order');
  const o = s.data();
  if (o.status === 'paid') return { status: 'paid', credits: o.credits || 0, adFreeUntil: o.days ? ((await db().collection('StudioUsers').doc(o.uid).get()).data() || {}).adFreeUntil || 0 : 0 };
  if (o.status === 'failed') return { status: 'failed' };
  if (!o.reference) return { status: 'pending' };
  const r = await feexRequest(`${FEEXPAY_API}/single/status/${encodeURIComponent(o.reference)}`, 'GET');
  const st = String((r.data && r.data.status) || '').toUpperCase();
  if (st === 'SUCCESSFUL' || st === 'SUCCESS') {
    let adFreeUntil = 0;
    if (o.days) adFreeUntil = (await addAdFree(o.uid, o.days, orderId, { price: o.price, currency: o.currency, operator: o.operator })).until;
    else await addCredits(o.uid, o.credits, 'purchase', orderId, { price: o.price, currency: o.currency, operator: o.operator });
    await oref.update({ status: 'paid', paidAt: FieldValue.serverTimestamp() });
    await referralReward(o, orderId).catch((e) => console.error('referral reward', e && e.message));
    const stat = db().collection('SlashAtlasStats').doc(day());
    await stat.set({ day: day() }, { merge: true });
    await stat.update({ orders: FieldValue.increment(1), revenueXof: FieldValue.increment(o.price), [`orders_paid_op.${o.operator}`]: FieldValue.increment(1), ...(o.days ? { adfree_orders: FieldValue.increment(1) } : {}) });
    return { status: 'paid', credits: o.credits || 0, adFreeUntil };
  }
  if (st === 'FAILED') { await oref.update({ status: 'failed', failure: String(r.data.reason || '').slice(0, 200) }); await bump({ orders_failed: 1 }); return { status: 'failed' }; }
  return { status: 'pending' };
}

async function payStatus(u, b) {
  const orderId = clean(b.orderId, 40);
  const s = await db().collection('StudioOrders').doc(orderId).get();
  if (!s.exists || s.data().uid !== u.uid) throw fail(404, 'no_order');
  const r = await settle(orderId);
  const ud = (await db().collection('StudioUsers').doc(u.uid).get()).data();
  return { ...r, balance: ud.credits || 0, adFreeUntil: ud.adFreeUntil || 0 };
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
    video: { base: VIDEO_COST.base, voice: VIDEO_COST.voice, cutout: VIDEO_COST.cutout, userPerDay: VIDEO_LIMITS.userPerDay },
    packs: [...PACKS, PASS],
    currency: 'XOF',
    card: { enabled: CARD.enabled, payin: CARD.payin, payout: CARD.payout, packs: CARD_LIMITS.packs },
    referral: { credits: REF.credits, months: REF.months },
    termsVersion: TERMS_VERSION,
    operators: OPERATORS.map(({ code, label, country, dial, payin, payout, redirect, otp }) => ({ code, label, country, dial, payin, payout, redirect: !!redirect, otp: !!otp })),
  };
}

/** Dossier de preuves d'une commande (litige, rétrofacturation) : commande, acceptation des conditions, crédits, images générées. */
async function evidence(orderId) {
  const s = await db().collection('StudioOrders').doc(clean(orderId, 40)).get();
  if (!s.exists) throw fail(404, 'no_order');
  const o = s.data();
  const out = { order: o, ledger: [], generations: [], user: null };
  const iso = (v) => (v && v.toDate ? v.toDate().toISOString() : v);
  for (const k of Object.keys(o)) o[k] = iso(o[k]);
  const ls = await db().collection('StudioLedger').where('uid', '==', o.uid).get();
  out.ledger = ls.docs.map((d) => ({ id: d.id, ...d.data() })).map((x) => ({ ...x, at: iso(x.at || x.createdAt) })).slice(0, 200);
  const gs = await db().collection('StudioGenerations').where('uid', '==', o.uid).get();
  out.generations = gs.docs.map((d) => { const x = d.data(); return { id: d.id, slug: x.slug, at: iso(x.createdAt), status: x.status, path: x.path, instruction: x.instruction }; }).slice(0, 200);
  const us = await db().collection('StudioUsers').doc(o.uid).get();
  if (us.exists) { const x = us.data(); out.user = { uid: o.uid, email: x.email, name: x.name, createdAt: iso(x.createdAt), credits: x.credits }; }
  return out;
}

/** Historique des générations d'un utilisateur (30 dernières, status=done, hors modifications). */
async function history(u) {
  const snap = await db().collection('StudioGenerations')
    .where('uid', '==', u.uid)
    .orderBy('createdAt', 'desc')
    .limit(30)
    .get();
  return snap.docs
    .filter((d) => { const x = d.data(); return x.status === 'done' && x.slug; })
    .slice(0, 20)
    .map((d) => {
      const x = d.data();
      return {
        id: d.id,
        slug: x.slug || '',
        lang: x.lang || 'fr',
        product: x.product || '',
        sale: !!x.sale,
        saleOpts: x.saleOpts || null,
        ts: x.createdAt ? x.createdAt.toMillis() : 0,
      };
    });
}

/** Récupère une image déjà générée depuis Firebase Storage (gratuit, sans crédit). */
async function regen(u, b) {
  const id = clean(b.id, 40);
  if (!id) throw fail(400, 'bad_id');
  const snap = await db().collection('StudioGenerations').doc(id).get();
  if (!snap.exists) throw fail(404, 'not_found');
  const data = snap.data();
  if (data.uid !== u.uid) throw fail(403, 'forbidden');
  if (data.status !== 'done' || !data.path) throw fail(404, 'not_found');
  const [buf] = await getStorage().bucket().file(data.path).download();
  return { id, image: buf.toString('base64'), mime: data.mime || 'image/jpeg' };
}

/** Don de crédits par l'administrateur (journal : type « grant », référence unique). */
async function grant(email, n, note) {
  const q = await db().collection('StudioUsers').where('email', '==', clean(email, 160).toLowerCase()).limit(1).get();
  if (q.empty) throw fail(404, 'no_user');
  n = Math.trunc(Number(n));
  if (!n || Math.abs(n) > 500) throw fail(400, 'bad_amount');
  const ref = crypto.randomBytes(6).toString('hex');
  await addCredits(q.docs[0].id, n, 'grant', ref, { note: clean(note, 120) });
  return { uid: q.docs[0].id, credits: ((await q.docs[0].ref.get()).data().credits) || 0 };
}

async function myOrders(u, b) {
  const PAGE = 20;
  let q = db().collection('StudioOrders').where('uid', '==', u.uid).orderBy('createdAt', 'desc').limit(PAGE + 1);
  if (b && b.cursor) {
    const cur = await db().collection('StudioOrders').doc(clean(b.cursor, 40)).get();
    if (cur.exists) q = q.startAfter(cur);
  }
  const snap = await q.get();
  const hasMore = snap.docs.length > PAGE;
  const docs = snap.docs.slice(0, PAGE);
  return {
    orders: docs.map((d) => {
      const o = d.data();
      return { id: d.id, credits: o.credits || 0, days: o.days || 0, amount: o.total || o.price || 0, currency: o.currency || 'XOF', operator: o.operator || '', status: o.status || 'pending', createdAt: o.createdAt ? o.createdAt.toMillis() : null };
    }),
    nextCursor: hasMore ? docs[docs.length - 1].id : null,
  };
}

async function adminOrders(b) {
  const PAGE = 20;
  let q = db().collection('StudioOrders').orderBy('createdAt', 'desc').limit(PAGE + 1);
  if (b && b.cursor) {
    const cur = await db().collection('StudioOrders').doc(clean(b.cursor, 40)).get();
    if (cur.exists) q = q.startAfter(cur);
  }
  const snap = await q.get();
  const hasMore = snap.docs.length > PAGE;
  const docs = snap.docs.slice(0, PAGE);
  return {
    orders: docs.map((d) => {
      const o = d.data();
      return { id: d.id, email: o.email || '', credits: o.credits || 0, days: o.days || 0, amount: o.total || o.price || 0, currency: o.currency || 'XOF', operator: o.operator || '', status: o.status || 'pending', createdAt: o.createdAt ? o.createdAt.toMillis() : null, phone: o.phone || '' };
    }),
    nextCursor: hasMore ? docs[docs.length - 1].id : null,
  };
}

/** Profil complet d'un utilisateur pour l'admin : solde, ledger, commandes, générations, films. */
async function adminUserDetail(emailOrUid) {
  const iso = (v) => (v && v.toDate ? v.toDate().toISOString() : v);
  let uid = null;
  let userDoc = null;

  // Chercher par email ou uid
  const q = await db().collection('StudioUsers').where('email', '==', clean(emailOrUid, 160).toLowerCase()).limit(1).get();
  if (!q.empty) {
    uid = q.docs[0].id;
    userDoc = q.docs[0];
  } else {
    // Essayer comme uid direct
    const d = await db().collection('StudioUsers').doc(clean(emailOrUid, 128)).get();
    if (d.exists) { uid = d.id; userDoc = d; }
  }
  if (!uid) throw fail(404, 'no_user');

  const u = userDoc.data();
  const result = {
    uid,
    email: u.email || '',
    credits: u.credits || 0,
    adFreeUntil: iso(u.adFreeUntil) || null,
    createdAt: iso(u.createdAt) || null,
    ledger: [],
    orders: [],
    generations: [],
    films: [],
    videos: [],
  };

  // Ledger complet (toutes opérations : débits, crédits, remboursements)
  const ledgerSnap = await db().collection('StudioLedger').where('uid', '==', uid).get();
  result.ledger = ledgerSnap.docs.map((d) => {
    const x = d.data();
    return { id: d.id, type: x.type, delta: x.delta || 0, ref: x.ref || '', note: x.note || x.reason || '', at: iso(x.at) };
  }).sort((a, b) => (b.at || '') > (a.at || '') ? 1 : -1);

  // Commandes (achats Mobile Money)
  const ordersSnap = await db().collection('StudioOrders').where('uid', '==', uid).limit(50).get();
  result.orders = ordersSnap.docs.map((d) => {
    const o = d.data();
    return { id: d.id, credits: o.credits || 0, days: o.days || 0, amount: o.total || o.price || 0, currency: o.currency || 'XOF', operator: o.operator || '', status: o.status, phone: o.phone || '', createdAt: iso(o.createdAt) };
  }).sort((a, b) => (b.createdAt || '') > (a.createdAt || '') ? 1 : -1);

  // Générations (images/visuels)
  const genSnap = await db().collection('StudioGenerations').where('uid', '==', uid).orderBy('createdAt', 'desc').limit(50).get();
  result.generations = genSnap.docs.map((d) => {
    const g = d.data();
    return { id: d.id, type: g.type || 'image', status: g.status, instruction: (g.instruction || '').slice(0, 80), at: iso(g.createdAt) };
  });

  // Vidéos
  const vidSnap = await db().collection('StudioVideos').where('uid', '==', uid).limit(20).get();
  result.videos = vidSnap.docs.map((d) => {
    const v = d.data();
    return { id: d.id, status: v.status, at: iso(v.createdAt), error: v.error || '' };
  });

  // Films (si collection existe)
  try {
    const filmSnap = await db().collection('FilmJobs').where('uid', '==', uid).limit(30).get();
    result.films = filmSnap.docs.map((d) => {
      const f = d.data();
      return { id: d.id, title: f.title || '', duration: f.duration, lang: f.lang, cost: f.cost, status: f.status, error: f.error || '', videoUrl: f.videoUrl || null, at: iso(f.createdAt) };
    }).sort((a, b) => (b.at || '') > (a.at || '') ? 1 : -1);
  } catch (_) { /* collection inexistante */ }

  return result;
}

async function getBrandProfile(u) {
  const doc = await db().collection('StudioUsers').doc(u.uid).get();
  const d = doc.exists ? doc.data() : {};
  return { brand: d.brandName || '', contact: d.brandContact || '', other: d.brandOther || '' };
}

async function saveBrandProfile(u, b) {
  const profile = { brandName: clean(b.brand || '', 60), brandContact: clean(b.contact || '', 60), brandOther: clean(b.other || '', 80) };
  await db().collection('StudioUsers').doc(u.uid).set(profile, { merge: true });
  return profile;
}

module.exports = { referrals, attachReferrer, referralReward, ensureRefCode, grant, evidence, TERMS_VERSION, CARD_LIMITS, SECRETS, me, generate, edit, history, regen, payCard, quote, CARD, payStart, payStatus, payWebhook, publicConfig, fail, PACKS, OPERATORS, composePrompt, GEN_COST, spendCredits, addCredits, bump, day, db, clean, GEMINI_API_KEY, VIDEO_COST, VIDEO_LIMITS, callGemini, getBrandProfile, saveBrandProfile, myOrders, adminOrders, adminUserDetail };
