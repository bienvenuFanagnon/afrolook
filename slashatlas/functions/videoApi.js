'use strict';
// Vidéos publicitaires : validation, crédits, plafonds, stockage. Le rendu lui-même est dans video.js.
const crypto = require('crypto');
const fs = require('fs');
const { FieldValue } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const studio = require('./studio');
const video = require('./video');
const { chromaKey } = require('./cutout');

const { fail, clean, db, day, spendCredits, addCredits, bump } = studio;
const STYLES = Object.keys(video.STYLES);
const RATIOS = Object.keys(video.SIZES);
const oneLine = (v, n) => clean(v, n).replace(/\s+/g, ' ');

function cleanTexts(t) {
  t = t && typeof t === 'object' ? t : {};
  const lines = (Array.isArray(t.lines) ? t.lines : []).map((x) => oneLine(x, 48)).filter(Boolean).slice(0, 3);
  return { brand: oneLine(t.brand, 40), hook: oneLine(t.hook, 60), lines, price: oneLine(t.price, 24), oldPrice: oneLine(t.oldPrice, 24), offer: oneLine(t.offer, 16), cta: oneLine(t.cta, 30), contact: oneLine(t.contact, 40) };
}
function normUrl(v) {
  v = oneLine(v, 200); if (!v) return '';
  if (/^[+\d][\d\s().-]{6,}$/.test(v)) return 'https://wa.me/' + v.replace(/\D/g, '');
  if (!/^https?:\/\//i.test(v)) v = 'https://' + v;
  try { const u = new URL(v); return /^https?:$/.test(u.protocol) && u.hostname.includes('.') ? u.toString() : ''; } catch { return ''; }
}
/** Texte lu par la voix, déduit des textes de la vidéo (utilisé si le client n'envoie pas le sien). */
function autoVoice(T, lang) {
  const en = lang === 'en'; const lines = T.lines || [];
  return {
    hook: T.hook,
    product: [T.brand ? (en ? `Discover ${T.brand}.` : `Découvrez ${T.brand}.`) : '', lines[0] || ''].filter(Boolean).join(' '),
    benefits: lines.join('. '),
    offer: [T.offer, T.price ? (en ? `Only ${T.price}.` : `Seulement ${T.price}.`) : ''].filter(Boolean).join('. '),
    cta: [T.cta, T.contact].filter(Boolean).join('. '),
  };
}
function cleanVoice(v, T, lang) {
  const auto = autoVoice(T, lang); const src = v && typeof v === 'object' ? v : {}; const out = {};
  for (const k of ['hook', 'product', 'benefits', 'offer', 'cta']) out[k] = oneLine(src[k] != null ? src[k] : auto[k], 240).replace(/[\[\]]/g, '');
  return out;
}

/** Crée la vidéo : débit, plafonds, rendu, stockage, remboursement si échec. Appelée par la fonction longue durée. */
async function render(u, b) {
  const lang = b.lang === 'en' ? 'en' : 'fr';
  const style = STYLES.includes(b.style) ? b.style : 'mode';
  const ratio = RATIOS.includes(b.ratio) ? b.ratio : '9:16';
  const photosIn = Array.isArray(b.photos) ? b.photos.slice(0, 3) : [];
  if (!photosIn.length) throw fail(400, 'no_photo');
  let total = 0; const photos = [];
  for (const p of photosIn) {
    const mime = String(p && p.mime || '');
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(mime)) throw fail(400, 'bad_photo');
    const data = String(p.data || ''); const bytes = Math.floor((data.length * 3) / 4);
    if (!data || bytes > 2.5 * 1024 * 1024) throw fail(413, 'photo_too_big');
    total += bytes; photos.push(Buffer.from(data, 'base64'));
  }
  if (total > 6 * 1024 * 1024) throw fail(413, 'photo_too_big');
  const texts = cleanTexts(b.texts);
  if (texts.hook.length < 3) throw fail(400, 'no_hook');
  const withVoice = b.voice === true || (b.voice && b.voice.on === true);
  const gender = b.voice && b.voice.gender === 'm' ? 'm' : 'f';
  const voice = withVoice ? { gender, segments: cleanVoice(b.voice && b.voice.segments, texts, lang) } : null;
  const qrUrl = normUrl(b.qr);
  const music = ['none', 'ambient', 'beat'].includes(b.music) ? b.music : undefined; // sans choix : celle du style
  const sfx = b.sfx !== false;
  const cutoutMode = ['auto', 'ai', 'off'].includes(b.cutout) ? b.cutout : 'auto';
  const cost = studio.VIDEO_COST.base + (withVoice ? studio.VIDEO_COST.voice : 0) + (cutoutMode === 'ai' ? studio.VIDEO_COST.cutout * photos.length : 0);
  const id = crypto.randomBytes(10).toString('hex');
  await spendCredits(u.uid, cost, 'v' + id);
  const d = day(); const cUser = db().collection('StudioCounters').doc(`v_${d}_${u.uid}`); const cAll = db().collection('StudioCounters').doc(`v_${d}_all`);
  try {
    await db().runTransaction(async (tx) => {
      const [a, g] = await Promise.all([tx.get(cUser), tx.get(cAll)]);
      if ((a.exists ? a.data().n : 0) >= studio.VIDEO_LIMITS.userPerDay) throw fail(429, 'daily_limit');
      if ((g.exists ? g.data().n : 0) >= studio.VIDEO_LIMITS.globalPerDay) throw fail(503, 'busy');
      tx.set(cUser, { n: FieldValue.increment(1), day: d }, { merge: true });
      tx.set(cAll, { n: FieldValue.increment(1), day: d }, { merge: true });
    });
  } catch (e) { await addCredits(u.uid, cost, 'refund', 'v' + id, { reason: e.code || 'limit' }); throw e; }
  const vref = db().collection('StudioVideos').doc(id);
  await vref.set({ uid: u.uid, style, ratio, lang, cost, voice: withVoice, qr: !!qrUrl, photos: photos.length, brand: texts.brand, hook: texts.hook, status: 'pending', createdAt: FieldValue.serverTimestamp() });
  let out = null; let paid = cost;
  try {
    // détourage IA : le produit est isolé sur fond vert par l'IA, puis le vert est retiré ; en cas d'échec sur une photo, détourage local et crédit rendu
    let sprites = null;
    if (cutoutMode === 'ai') {
      sprites = await Promise.all(photos.map((buf, i) => aiCutout(buf, photosIn[i].mime, lang)));
      const failed = sprites.filter((x) => !x).length;
      if (failed) { await addCredits(u.uid, failed * studio.VIDEO_COST.cutout, 'refund', 'vc' + id, { reason: 'cutout_failed' }); paid -= failed * studio.VIDEO_COST.cutout; }
      await bump({ videoCutoutAi: sprites.length - failed, videoCutoutAiFail: failed });
    }
    out = await video.render({ style, ratio, lang, photos, sprites, cutout: cutoutMode === 'off' ? 'off' : 'auto', music, sfx, texts, qrUrl, voice });
    const path = `videos/${u.uid}/${id}.mp4`;
    await getStorage().bucket().file(path).save(fs.readFileSync(out.file), { contentType: 'video/mp4', resumable: false });
    await vref.update({ status: 'done', path, cost: paid, cutout: cutoutMode, music: music || 'default', sfx, cutouts: out.cutouts, seconds: Math.round(out.seconds * 10) / 10, ttsChars: out.ttsChars, doneAt: FieldValue.serverTimestamp() });
    await bump({ videos: 1, videoSecs: Math.round(out.seconds), videoTts: out.ttsChars, [`videoStyle_${style}`]: 1 });
    const left = (await db().collection('StudioUsers').doc(u.uid).get()).data().credits || 0;
    return { id, seconds: out.seconds, cost: paid, credits: left };
  } catch (e) {
    console.error('video render', e && e.stack || e);
    await addCredits(u.uid, paid, 'refund', 'v' + id, { reason: (e && e.code) || 'error' });
    await vref.update({ status: 'failed', error: (e && e.code) || 'error' });
    await bump({ videofails: 1 });
    throw e && e.status ? e : fail(500, e && e.code === 'too_long' ? 'too_long' : e && e.code === 'tts' ? 'voice_error' : 'render_failed');
  } finally { if (out) { try { fs.rmSync(out.dir, { recursive: true, force: true }); } catch (e) { /* temporaire */ } } }
}

/** Produit isolé par l'IA sur fond vert, puis détouré. Retourne un PNG transparent, ou null si ça n'a pas marché (la vidéo se rabat sur le détourage local). */
async function aiCutout(buf, mime, lang) {
  try {
    const text = 'Isolate the product(s) shown in the attached photo on a perfectly flat, uniform chroma-key green background (pure #00FF00). The product must stay strictly identical: same shape, colors, logo, label, proportions and every detail, fully visible, centered, with a small margin around it. No shadow, no reflection, no gradient, no floor, no hand, no other object, no added text. If the photo shows several products, keep them all.';
    const img = await studio.callGemini([{ inlineData: { mimeType: mime || 'image/jpeg', data: buf.toString('base64') } }, { text }], '1:1');
    const r = await chromaKey(Buffer.from(img.data, 'base64'));
    return r.ok && r.sprite ? r.sprite.canvas.toBuffer('image/png') : null;
  } catch (e) { console.error('aiCutout', e && (e.code || e.message)); return null; }
}

/** Fichier MP4 d'une vidéo du client (jamais celle d'un autre compte). */
async function file(u, b) {
  const s = await db().collection('StudioVideos').doc(clean(b.id, 40)).get(); const v = s.exists ? s.data() : null;
  if (!v || v.uid !== u.uid || v.status !== 'done' || !v.path) throw fail(404, 'no_video');
  const [buf] = await getStorage().bucket().file(v.path).download().catch(() => { throw fail(404, 'no_video'); });
  return buf;
}
async function list(u) {
  const q = await db().collection('StudioVideos').where('uid', '==', u.uid).limit(60).get().catch(() => ({ docs: [] })); // pas d'orderBy : évite un index composite, le tri se fait ici
  const rows = q.docs.map((x) => { const v = x.data(); return { id: x.id, status: v.status, style: v.style, ratio: v.ratio, seconds: v.seconds || 0, brand: v.brand || '', hook: v.hook || '', at: v.createdAt && v.createdAt.toDate ? v.createdAt.toDate().toISOString() : '' }; });
  return { videos: rows.filter((v) => v.status === 'done').sort((a, c) => (a.at < c.at ? 1 : -1)).slice(0, 12) };
}

// ───────── texte proposé par l'IA (gratuit, plafonné) ─────────
const SCRIPT_MODELS = ['gemini-flash-latest', 'gemini-2.5-flash'];
async function script(u, b) {
  const lang = b.lang === 'en' ? 'en' : 'fr'; const about = oneLine(b.about, 240); if (about.length < 4) throw fail(400, 'no_about');
  const d = day(); const c = db().collection('StudioCounters').doc(`s_${d}_${u.uid}`);
  await db().runTransaction(async (tx) => { const s = await tx.get(c); if ((s.exists ? s.data().n : 0) >= 25) throw fail(429, 'daily_limit'); tx.set(c, { n: FieldValue.increment(1), day: d }, { merge: true }); });
  const T = cleanTexts(b.texts); const style = STYLES.includes(b.style) ? b.style : 'mode';
  const ctx = [`Produit ou activité : ${about}`, T.brand && `Marque : ${T.brand}`, T.price && `Prix : ${T.price}`, T.offer && `Offre : ${T.offer}`, `Style : ${style}`].filter(Boolean).join('\n');
  const prompt = lang === 'fr'
    ? `Tu écris le texte d’une courte publicité vidéo (15 à 25 secondes) pour un petit commerçant. ${ctx}\nRéponds uniquement en JSON : {"hook": accroche de 3 à 6 mots, "lines": [3 atouts de 2 à 5 mots chacun], "cta": appel à l’action de 2 à 4 mots, "voice": {"hook": phrase d’accroche parlée de 8 mots au plus, "product": 1 ou 2 phrases courtes de 22 mots au plus, "benefits": 1 phrase de 20 mots au plus, "offer": 1 phrase de 18 mots au plus (vide s’il n’y a ni prix ni offre), "cta": 1 phrase de 12 mots au plus}}.\nRègles : français simple et chaleureux ; n’invente ni chiffre, ni prix, ni certification, ni promesse médicale ou de résultat garanti ; rien d’exagéré ; pas d’émoji ; pas de guillemets dans les textes.`
    : `You write the text of a short video ad (15 to 25 seconds) for a small business owner. ${ctx}\nReply with JSON only: {"hook": a 3 to 6 word hook, "lines": [3 benefits of 2 to 5 words each], "cta": a 2 to 4 word call to action, "voice": {"hook": spoken hook of 8 words max, "product": 1 or 2 short sentences of 22 words max, "benefits": 1 sentence of 20 words max, "offer": 1 sentence of 18 words max (empty if no price or offer), "cta": 1 sentence of 12 words max}}.\nRules: simple, warm English; invent no number, price, certification, medical claim or guaranteed result; nothing exaggerated; no emoji; no quotation marks inside the texts.`;
  let j = null;
  for (const model of SCRIPT_MODELS) {
    try {
      const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, { method: 'POST', headers: { 'content-type': 'application/json', 'x-goog-api-key': studio.GEMINI_API_KEY.value() },
        body: JSON.stringify({ contents: [{ parts: [{ text: prompt }] }], generationConfig: { responseMimeType: 'application/json', temperature: 0.8 } }) });
      const x = await r.json(); const txt = x.candidates && x.candidates[0] && x.candidates[0].content && x.candidates[0].content.parts && x.candidates[0].content.parts[0] && x.candidates[0].content.parts[0].text;
      if (txt) { j = JSON.parse(txt); break; }
      console.error('script model', model, JSON.stringify(x.error || x.promptFeedback || '').slice(0, 200));
    } catch (e) { console.error('script', model, e.message); }
  }
  if (!j || typeof j !== 'object') throw fail(502, 'script_failed');
  const v = j.voice && typeof j.voice === 'object' ? j.voice : {};
  return { hook: oneLine(j.hook, 60), lines: (Array.isArray(j.lines) ? j.lines : []).map((x) => oneLine(x, 48)).filter(Boolean).slice(0, 3), cta: oneLine(j.cta, 30),
    voice: { hook: oneLine(v.hook, 120), product: oneLine(v.product, 240), benefits: oneLine(v.benefits, 240), offer: oneLine(v.offer, 240), cta: oneLine(v.cta, 160) } };
}

module.exports = { render, file, list, script, autoVoice, cleanTexts, normUrl };
