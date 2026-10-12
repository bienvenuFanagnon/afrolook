'use strict';
// Vidéos publicitaires : validation, crédits, plafonds, stockage. Le rendu lui-même est dans video.js.
const crypto = require('crypto');
const fs = require('fs');
const { FieldValue } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const studio = require('./studio');
const video = require('./video');
const { chromaKey, localCutout } = require('./cutout');
const { matte } = require('./matting');
const { enhance } = require('./enhance');
const { loadImage, createCanvas } = require('@napi-rs/canvas');

const { fail, clean, db, day, spendCredits, addCredits, bump } = studio;
const STYLES = Object.keys(video.STYLES);
const RATIOS = Object.keys(video.SIZES);
const MODEL_IDS = Object.keys(video.MODELS);
const SUBJECTS = ['product', 'food', 'person'];
const SCRIPT_MODELS = ['gemini-flash-latest', 'gemini-2.5-flash'];
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

/** Un téléphone ou un lien dans le champ « contact » devient le QR code de fin, sans rien demander de plus. */
function qrFromContact(c) { try { return normUrl(c); } catch (e) { return ''; } }

/** Texte de la vidéo écrit par l'IA à partir de la PHOTO (et de ce que la personne a donné) : l'utilisateur n'a rien à écrire. */
async function autoCopy(photo, mime, ctx) {
  const lang = ctx.lang; const info = [ctx.about && (lang === 'fr' ? 'Description donnée : ' : 'Description given: ') + ctx.about, ctx.brand && (lang === 'fr' ? 'Marque : ' : 'Brand: ') + ctx.brand, ctx.price && (lang === 'fr' ? 'Prix : ' : 'Price: ') + ctx.price].filter(Boolean).join('\n');
  const prompt = lang === 'fr'
    ? `Regarde la photo : c'est le produit d'un petit commerçant. Écris le texte d'une courte publicité vidéo (15 à 25 secondes).\n${info}\nChoisis aussi le style : "beaute" (cosmétiques, soins, parfums, coiffure), "mode" (vêtements, chaussures, sacs, bijoux, accessoires), "promo" (nourriture, boissons, électronique, maison, tout le reste).\nIndique aussi ce que la photo montre : "subject" = "product" (objet, cosmétique, vêtement seul, sac, chaussure…), "food" (plat, boisson, pâtisserie) ou "person" (une personne porte ou présente l'article). Et le modèle de vidéo qui met le mieux l'article en valeur : "tour360" (flacon, bouteille, boîte, sac, chaussure, objet qui est beau quand il tourne), "zoom" (vêtement, tissu, bijou, plat : gros plans sur les détails), "lancement" (nouveauté, cosmétique, parfum), "classique" (le reste).\nRéponds uniquement en JSON : {"subject": "product|food|person", "model": "tour360|zoom|lancement|classique", "style": "beaute|mode|promo", "hook": accroche de 3 à 6 mots, "lines": [3 atouts de 2 à 5 mots, visibles sur la photo ou évidents pour ce type de produit], "cta": appel à l'action de 2 à 4 mots, "voice": {"hook": phrase parlée de 8 mots au plus, "product": 1 ou 2 phrases de 22 mots au plus, "benefits": 1 phrase de 20 mots au plus, "offer": "" , "cta": 1 phrase de 12 mots au plus}}.\nRègles : français simple et chaleureux ; n'invente ni marque, ni chiffre, ni prix, ni certification, ni promesse de résultat ou de santé ; ne lis aucun texte de l'emballage sauf s'il est donné ; pas d'émoji ; pas de guillemets dans les textes.`
    : `Look at the photo: it is a small business owner's product. Write the text of a short video ad (15 to 25 seconds).\n${info}\nAlso pick the style: "beaute" (cosmetics, skincare, perfume, hair), "mode" (clothes, shoes, bags, jewelry, accessories), "promo" (food, drinks, electronics, home, everything else).\nAlso say what the photo shows: "subject" = "product" (object, cosmetic, a garment alone, bag, shoe…), "food" (dish, drink, pastry) or "person" (a person wears or presents the item). And the video model that shows the item best: "tour360" (bottle, jar, box, bag, shoe, anything that looks great turning), "zoom" (clothes, fabric, jewelry, food: close-ups on details), "lancement" (new product, cosmetics, perfume), "classique" (the rest).\nReply with JSON only: {"subject": "product|food|person", "model": "tour360|zoom|lancement|classique", "style": "beaute|mode|promo", "hook": a 3 to 6 word hook, "lines": [3 benefits of 2 to 5 words, visible in the photo or obvious for this kind of product], "cta": a 2 to 4 word call to action, "voice": {"hook": spoken hook of 8 words max, "product": 1 or 2 sentences of 22 words max, "benefits": 1 sentence of 20 words max, "offer": "", "cta": 1 sentence of 12 words max}}.\nRules: simple, warm English; invent no brand, number, price, certification, health or result claim; do not read any packaging text unless given; no emoji; no quotation marks inside the texts.`;
  for (const model of SCRIPT_MODELS) {
    try {
      const r = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, { method: 'POST', headers: { 'content-type': 'application/json', 'x-goog-api-key': studio.GEMINI_API_KEY.value() },
        body: JSON.stringify({ contents: [{ parts: [{ inlineData: { mimeType: mime || 'image/jpeg', data: photo.toString('base64') } }, { text: prompt }] }], generationConfig: { responseMimeType: 'application/json', temperature: 0.7 } }) });
      const x = await r.json(); const txt = x.candidates && x.candidates[0] && x.candidates[0].content && x.candidates[0].content.parts && x.candidates[0].content.parts[0] && x.candidates[0].content.parts[0].text;
      if (!txt) { console.error('autoCopy', model, JSON.stringify(x.error || x.promptFeedback || '').slice(0, 200)); continue; }
      const j = JSON.parse(txt); const v = j.voice && typeof j.voice === 'object' ? j.voice : {};
      const out = { subject: SUBJECTS.includes(j.subject) ? j.subject : 'product', model: MODEL_IDS.includes(j.model) ? j.model : null, style: STYLES.includes(j.style) ? j.style : null, hook: oneLine(j.hook, 60), lines: (Array.isArray(j.lines) ? j.lines : []).map((q) => oneLine(q, 48)).filter(Boolean).slice(0, 3), cta: oneLine(j.cta, 30),
        voice: { hook: oneLine(v.hook, 120), product: oneLine(v.product, 240), benefits: oneLine(v.benefits, 240), offer: '', cta: oneLine(v.cta, 160) } };
      if (out.hook.length >= 3) return out;
    } catch (e) { console.error('autoCopy', model, e.message); }
  }
  return null;
}
const FALLBACK = { fr: { hook: 'Découvrez-le', cta: 'Commandez maintenant' }, en: { hook: 'Discover it', cta: 'Order now' } };

/** Crée la vidéo : débit, plafonds, rendu, stockage, remboursement si échec. Appelée par la fonction longue durée.
 *  L'utilisateur n'a presque rien à fournir : une photo suffit. Détourage, texte, style, musique, voix et QR code sont choisis ici. */
async function render(u, b) {
  const lang = b.lang === 'en' ? 'en' : 'fr';
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
  let texts = cleanTexts(b.texts); const about = oneLine(b.about, 240);
  const auto = texts.hook.length < 3; // pas d'accroche fournie : l'IA l'écrit
  const withVoice = !(b.voice === false || (b.voice && b.voice.on === false));
  const gender = b.voice && b.voice.gender === 'm' ? 'm' : 'f';
  const music = ['none', 'ambient', 'beat'].includes(b.music) ? b.music : undefined; // sans choix : celle du style
  const sfx = b.sfx !== false;
  const cutoutMode = ['smart', 'auto', 'ai', 'off'].includes(b.cutout) ? b.cutout : 'smart';
  const cost = studio.VIDEO_COST.base; // prix unique
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
  await vref.set({ uid: u.uid, ratio, lang, cost, photos: photos.length, brand: texts.brand, status: 'pending', createdAt: FieldValue.serverTimestamp() });
  let out = null;
  try {
    // 0. retouche automatique de la photo : lumière, couleurs, netteté, taille (photos sombres, ternes ou petites)
    for (let i = 0; i < photos.length; i++) {
      try { const im = await loadImage(photos[i]); const cv = createCanvas(im.width, im.height); cv.getContext('2d').drawImage(im, 0, 0); photos[i] = enhance(cv, { minSide: 1100, maxSide: 1600 }).toBuffer('image/jpeg', 93); photosIn[i] = { ...photosIn[i], mime: 'image/jpeg' }; }
      catch (e) { console.error('enhance', e && e.message); }
    }
    // 1. l'IA regarde la photo : ce qu'elle montre, le meilleur modèle de vidéo, et le texte si la personne n'a rien écrit
    const c = await autoCopy(photos[0], photosIn[0].mime, { lang, about, brand: texts.brand, price: texts.price });
    const subject = (c && c.subject) || 'product'; let styleChoice = STYLES.includes(b.style) ? b.style : null; let aiVoice = null;
    if (auto) {
      const fb = FALLBACK[lang];
      texts = { ...texts, hook: (c && c.hook) || (about && about.length >= 3 ? about.slice(0, 60) : texts.brand || fb.hook), lines: texts.lines.length ? texts.lines : (c ? c.lines : []), cta: texts.cta || (c ? c.cta : fb.cta) };
      if (c) aiVoice = c.voice;
      await bump({ videoAutoCopy: c ? 1 : 0, videoAutoCopyFail: c ? 0 : 1 });
    }
    if (c) styleChoice = styleChoice || c.style;
    // modèle de vidéo : celui demandé, sinon celui que l'IA conseille (avec un peu de hasard pour que deux vidéos ne se ressemblent pas)
    let model = MODEL_IDS.includes(b.model) ? b.model : null;
    if (!model) {
      const base = (c && c.model) || 'zoom'; const pool = [base, base, 'lancement', 'tour360', 'zoom'];
      model = photos.length >= 2 ? 'catalogue' : pool[crypto.randomInt(pool.length)];
      if (subject === 'person' && model === 'tour360') model = 'zoom'; // une personne ne tourne pas sur un plateau
    }
    const style = styleChoice || (model === 'promo' || texts.price || texts.offer ? 'promo' : 'mode');
    const qrUrl = normUrl(b.qr) || qrFromContact(texts.contact);
    const voiceSrc = b.voice && b.voice.segments ? b.voice.segments : aiVoice;
    const voice = withVoice ? { gender, segments: cleanVoice(voiceSrc, texts, lang) } : null;
    // 2. le produit : photo « refaite en studio » par l'IA (même produit, plus beau, entier), détourée ; sinon détourage de la photo retouchée
    let sprites = null; let shots = 0;
    if (cutoutMode === 'ai' || cutoutMode === 'smart') {
      const wantShot = b.studio !== false && subject !== 'person'; // une personne n'est jamais régénérée : son visage et sa silhouette restent les siens
      const shotP = photos.map((buf, i) => (wantShot ? withTimeout(studioShot(buf, photosIn[i].mime, subject), 85000).catch((e) => { console.error('studioShot', e && (e.code || e.message)); return null; }) : Promise.resolve(null)));
      sprites = [];
      for (let i = 0; i < photos.length; i++) { const buf = photos[i]; sprites.push(await (async () => {
        if (cutoutMode === 'smart') {
          // modèle de détourage (pixels du produit intacts, marche sur n'importe quel fond) ; sinon remplissage simple pour les fonds unis ; sinon IA sur fond vert
          try { const mr = await matte(buf); if (mr.ok && mr.sprite) return mr.sprite.canvas.toBuffer('image/png'); } catch (e) { console.error('matte', e && e.message); }
          try { const lc = await localCutout(buf); if (lc.ok && lc.sprite) return lc.sprite.canvas.toBuffer('image/png'); } catch (e) { /* on essaie l'IA */ }
        }
        return aiCutout(buf, photosIn[i].mime, lang);
      })()); }
      const shot = await Promise.all(shotP); shot.forEach((x, i) => { if (x) { sprites[i] = x; shots++; } else if (subject === 'food') sprites[i] = null; }); // un plat mal détouré perd son assiette : sans la version studio, on garde la photo entière
      const ai = sprites.filter(Boolean).length; await bump({ videoCutoutKept: ai, videoCutoutMiss: sprites.length - ai, videoStudioShot: shots, videoStudioShotMiss: wantShot ? photos.length - shots : 0 });
    }
    await vref.update({ style, model, subject, studio: shots, hook: texts.hook, voice: !!voice, qr: !!qrUrl });
    out = await video.render({ threads: 3, style, model, ratio, lang, photos, sprites, cutout: cutoutMode === 'off' ? 'off' : 'auto', music, sfx, texts, qrUrl, voice });
    const path = `videos/${u.uid}/${id}.mp4`;
    await getStorage().bucket().file(path).save(fs.readFileSync(out.file), { contentType: 'video/mp4', resumable: false });
    await vref.update({ status: 'done', path, cutout: cutoutMode, music: music || 'default', sfx, cutouts: out.cutouts, seconds: Math.round(out.seconds * 10) / 10, ttsChars: out.ttsChars, doneAt: FieldValue.serverTimestamp() });
    await bump({ videos: 1, videoSecs: Math.round(out.seconds), videoTts: out.ttsChars, [`videoStyle_${style}`]: 1, [`videoModel_${model}`]: 1 });
    const left = (await db().collection('StudioUsers').doc(u.uid).get()).data().credits || 0;
    // ce qui a été choisi pour la personne : l'écran « Modifier » le reprend
    return { id, seconds: out.seconds, cost, credits: left, used: { style, model, subject, studio: shots, texts, voice: voice ? { gender, segments: voice.segments } : null, qr: qrUrl ? 1 : 0, cutouts: out.cutouts } };
  } catch (e) {
    console.error('video render', e && e.stack || e);
    await addCredits(u.uid, cost, 'refund', 'v' + id, { reason: (e && e.code) || 'error' });
    await vref.update({ status: 'failed', error: (e && e.code) || 'error' });
    await bump({ videofails: 1 });
    throw e && e.status ? e : fail(500, e && e.code === 'too_long' ? 'too_long' : e && e.code === 'tts' ? 'voice_error' : 'render_failed');
  } finally { if (out) { try { fs.rmSync(out.dir, { recursive: true, force: true }); } catch (e) { /* temporaire */ } } }
}

function withTimeout(p, ms) { let t; return Promise.race([p, new Promise((_, rej) => { t = setTimeout(() => rej(Object.assign(new Error('timeout'), { code: 'timeout' })), ms); })]).finally(() => clearTimeout(t)); }

/** La photo « refaite en studio » : même produit (forme, couleurs, logo), mais bien éclairé, net, entier et bien présenté, sur un fond uni facile à détourer. Retourne un PNG détouré ou null. */
async function studioShot(buf, mime, subject) {
  const food = subject === 'food';
  const text = `Professional commercial photograph of the ${food ? 'dish' : 'product'} shown in the attached photo, as a premium advertising hero shot. Keep it STRICTLY identical: same shape, proportions, colors, materials, logo and every printed or embroidered detail, same number of items. Improve only the presentation: perfect studio lighting with soft highlights and gentle realistic reflections, crisp sharp details, rich natural colors${food ? ', appetizing, fresh and glossy' : ''}, a clean polished premium look. The ENTIRE ${food ? 'dish including the whole plate and its rim' : 'product'} must be fully visible and never cropped, centered, with a generous margin all around. Place it on a plain seamless neutral medium-gray studio background. No shadow on the background, no props, no added text, no hands, no people, no watermark.`;
  const img = await studio.callGemini([{ inlineData: { mimeType: mime || 'image/jpeg', data: buf.toString('base64') } }, { text }], food ? '1:1' : '4:5');
  const mr = await matte(Buffer.from(img.data, 'base64'));
  return mr.ok && mr.sprite ? mr.sprite.canvas.toBuffer('image/png') : null;
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

module.exports = { studioShot, render, file, list, script, autoVoice, cleanTexts, normUrl };
