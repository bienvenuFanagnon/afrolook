'use strict';
// Vidéo de présentation de SlashAtlas : visuels (images) + vidéos pub, avec voix off, musique et effets sonores.
// Usage (depuis slashatlas/functions, avec NODE_PATH=node_modules et GOOGLE_APPLICATION_CREDENTIALS pour la voix) :
//   node ../marketing/promo_site.cjs <fr|en> <9:16|16:9> <sortie.mp4>
// Les images et vidéos montrées sont les exemples du site (static/img/c, static/video/exemples).
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn, execFileSync } = require('child_process');
const { createCanvas, loadImage } = require('@napi-rs/canvas');
const V = require('../functions/video.js');
const { music, sfxTrack, mix } = require('../functions/sfx.js');
const FFMPEG = require('../functions/node_modules/ffmpeg-static');
const { fonts, clamp, prog, ease, withAlpha, rng, fit, words, rrect, drawCover, SR } = V._h;

const LANG = process.argv[2] === 'en' ? 'en' : 'fr';
const RATIO = process.argv[3] === '16:9' ? '16:9' : '9:16';
const OUT = process.argv[4] || path.join(os.tmpdir(), `promo_${LANG}.mp4`);
const [W, H] = RATIO === '16:9' ? [1280, 720] : [720, 1280]; const LAND = W > H; const FPS = 24;
const STATIC = path.join(__dirname, '..', 'static');
const BLUE = '#2997ff', BLUE2 = '#69b7ff', INK = '#05070a', YEL = '#ffe14d';

const TXT = {
  fr: {
    s1: ['Votre produit mérite mieux', 'qu’une photo toute plate.'], c1: 'Photo prise au téléphone',
    s2c: '1 · VISUELS', s2a: 'Votre photo', s2b: 'Affiche pro', cmd: '/skincareglow', cmdSub: 'commande gratuite', steps: ['Copiez', 'Collez', 'Publiez'], free: 'Plus de 700 commandes gratuites',
    s3c: '2 · VIDÉOS PUB', p1: 'Votre photo', p2: 'Produit détouré', p3: 'Votre vidéo', feats: ['Voix off', 'Musique', 'Effets sonores', 'QR code'],
    s4: ['VISUELS', 'VIDÉOS'], s4t: 'Mode · beauté · food · immobilier…',
    s5a: 'Le studio de création rapide', s5b: 'de contenu IA', pills: ['Commandes gratuites', 'Générer ici', 'Vidéos pub'], url: 'slashatlas.com',
    v: { s1: 'Votre produit mérite mieux qu’une photo toute plate.', s2: 'Sur SlashAtlas, copiez une commande gratuite, ou générez directement sur le site : votre photo devient une affiche professionnelle, prête à publier.',
      s3: 'Et maintenant, des vidéos publicitaires. Importez votre photo : le produit est détouré et mis en scène, avec de la musique, des effets sonores et, si vous voulez, une voix off et un QR code.',
      s4: 'Des visuels. Des vidéos. Pour la mode, la beauté, la restauration, l’immobilier, et tout ce que vous vendez.', s5: 'SlashAtlas point com. Votre studio de création rapide de contenu.' },
  },
  en: {
    s1: ['Your product deserves better', 'than a flat photo.'], c1: 'Photo taken with a phone',
    s2c: '1 · VISUALS', s2a: 'Your photo', s2b: 'Pro poster', cmd: '/skincareglow', cmdSub: 'free command', steps: ['Copy', 'Paste', 'Post'], free: 'Over 700 free commands',
    s3c: '2 · VIDEO ADS', p1: 'Your photo', p2: 'Cut-out product', p3: 'Your video', feats: ['Voice-over', 'Music', 'Sound effects', 'QR code'],
    s4: ['VISUALS', 'VIDEOS'], s4t: 'Fashion · beauty · food · real estate…',
    s5a: 'The fast content creation', s5b: 'studio, powered by AI', pills: ['Free commands', 'Generate here', 'Video ads'], url: 'slashatlas.com',
    v: { s1: 'Your product deserves better than a flat photo.', s2: 'On SlashAtlas, copy a free command, or generate right on the site: your photo becomes a professional poster, ready to post.',
      s3: 'And now, video ads. Upload your photo: the product is cut out and staged, with music, sound effects and, if you like, a voice-over and a QR code.',
      s4: 'Visuals. Videos. For fashion, beauty, food, real estate, and everything you sell.', s5: 'SlashAtlas dot com. Your fast content creation studio.' },
  },
}[LANG];

const cache = new Map();
async function img(file) { if (!cache.has(file)) cache.set(file, await loadImage(file)); return cache.get(file); }
const C = (n) => path.join(STATIC, 'img', 'c', n + '.webp');

// ───────── éléments graphiques ─────────
function background(ctx, t) {
  const g = ctx.createLinearGradient(0, 0, W * 0.4, H); g.addColorStop(0, '#0a1018'); g.addColorStop(1, INK); ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
  ctx.save(); ctx.globalCompositeOperation = 'lighter';
  [[0.25, 0.3, BLUE, 0.16], [0.8, 0.7, '#7a5cff', 0.12], [0.6, 0.15, BLUE2, 0.08]].forEach(([fx, fy, col, a], i) => { const r = Math.max(W, H) * 0.6; const x = W * fx + Math.sin(t * 0.3 + i * 2) * W * 0.06, y = H * fy + Math.cos(t * 0.25 + i) * H * 0.05; const gr = ctx.createRadialGradient(x, y, 0, x, y, r); gr.addColorStop(0, withAlpha(col, a)); gr.addColorStop(1, withAlpha(col, 0)); ctx.fillStyle = gr; ctx.fillRect(0, 0, W, H); });
  ctx.restore();
  ctx.save(); ctx.globalAlpha = 0.05; ctx.strokeStyle = '#fff'; ctx.lineWidth = 1; for (let x = -((t * 14) % 60); x < W; x += 60) { ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, H); ctx.stroke(); } for (let y = -((t * 14) % 60); y < H; y += 60) { ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(W, y); ctx.stroke(); } ctx.restore();
}
function chipW(ctx, text, px, icon) { ctx.save(); ctx.font = `${px}px VMan800`; const w = ctx.measureText(text).width + px * 1.6 + (icon ? px * 1.1 : 0); ctx.restore(); return w; }
function chip(ctx, text, x, y, o = {}) {
  const px = o.px || 30; const icon = !!o.icon; const w = chipW(ctx, text, px, icon), h = px * 1.9; const p = o.p == null ? 1 : o.p; ctx.save(); ctx.font = `${px}px VMan800`; ctx.translate(x, y); ctx.scale(p, p); ctx.globalAlpha = clamp(p * 1.4);
  const x0 = o.center ? -w / 2 : 0; ctx.fillStyle = o.bg || BLUE; rrect(ctx, x0, -h / 2, w, h, h / 2); ctx.fill(); ctx.fillStyle = o.fg || '#fff'; ctx.textBaseline = 'middle'; ctx.textAlign = 'left';
  let tx = x0 + px * 0.8; if (icon) { const r = px * 0.42, cx = x0 + px * 0.8 + r, cy = 0; ctx.fillStyle = o.fg || '#fff'; ctx.globalAlpha *= 0.9; ctx.beginPath(); ctx.arc(cx, cy, r, 0, 7); ctx.fill(); ctx.globalAlpha = clamp(p * 1.4); ctx.strokeStyle = o.bgIcon || '#161026'; ctx.lineWidth = px * 0.12; ctx.lineCap = 'round'; ctx.lineJoin = 'round'; ctx.beginPath(); ctx.moveTo(cx - r * 0.45, cy + r * 0.02); ctx.lineTo(cx - r * 0.1, cy + r * 0.38); ctx.lineTo(cx + r * 0.5, cy - r * 0.35); ctx.stroke(); ctx.fillStyle = o.fg || '#fff'; tx += px * 1.1; }
  ctx.fillText(text, tx, 2); ctx.restore(); return w;
}
function chipFlow(ctx, items, x0, y0, maxX, o = {}) { // étiquettes qui passent à la ligne
  let x = x0, y = y0; const px = o.px || 28; const gap = 14; const rowH = px * 1.9 + 12;
  items.forEach((it, i) => { const w = chipW(ctx, it.text, px, o.icon); if (x + w > maxX && x > x0) { x = x0; y += rowH; } chip(ctx, it.text, x, y, { ...o, px, p: it.p }); x += w + gap; });
}
function chipRow(ctx, items, cx, y, o = {}) { // rangée centrée, sans chevauchement
  const px = o.px || 30; const ws = items.map((it) => chipW(ctx, it.text, px, o.icon)); const total = ws.reduce((a, b) => a + b, 0) + 16 * (items.length - 1); let x = cx - total / 2;
  items.forEach((it, i) => { chip(ctx, it.text, x, y, { ...o, px, p: it.p, bg: it.bg || o.bg }); x += ws[i] + 16; });
}
function phone(ctx, cx, cy, w, h, inner, o = {}) {
  ctx.save(); ctx.translate(cx, cy); ctx.rotate(o.rot || 0); ctx.scale(o.scale || 1, o.scale || 1); ctx.globalAlpha = o.alpha == null ? 1 : o.alpha;
  ctx.shadowColor = 'rgba(0,0,0,.6)'; ctx.shadowBlur = 40; ctx.shadowOffsetY = 18; ctx.fillStyle = '#16191f'; rrect(ctx, -w / 2, -h / 2, w, h, w * 0.12); ctx.fill(); ctx.shadowColor = 'transparent';
  ctx.strokeStyle = '#2b3038'; ctx.lineWidth = 3; ctx.stroke();
  const pad = w * 0.035; ctx.save(); rrect(ctx, -w / 2 + pad, -h / 2 + pad, w - 2 * pad, h - 2 * pad, w * 0.095); ctx.clip(); ctx.fillStyle = '#000'; ctx.fillRect(-w / 2, -h / 2, w, h); inner(-w / 2 + pad, -h / 2 + pad, w - 2 * pad, h - 2 * pad); ctx.restore();
  ctx.fillStyle = '#0a0c10'; rrect(ctx, -w * 0.12, -h / 2 + pad * 1.4, w * 0.24, pad * 0.9, pad * 0.45); ctx.fill(); ctx.restore();
}
function arrow(ctx, x, y, size, p, vertical) {
  ctx.save(); ctx.translate(x, y); if (vertical) ctx.rotate(Math.PI / 2); ctx.globalAlpha = clamp(p * 1.5); ctx.strokeStyle = BLUE2; ctx.lineWidth = size * 0.16; ctx.lineCap = 'round'; ctx.lineJoin = 'round';
  const l = size * ease.out(p); ctx.beginPath(); ctx.moveTo(-size / 2, 0); ctx.lineTo(-size / 2 + l, 0); ctx.stroke(); if (p > 0.7) { ctx.beginPath(); ctx.moveTo(size * 0.1, -size * 0.32); ctx.lineTo(size / 2, 0); ctx.lineTo(size * 0.1, size * 0.32); ctx.stroke(); } ctx.restore();
}
function popWords(ctx, lines, box, t, delay, o = {}) { // texte qui arrive mot à mot
  const fam = o.fam || 'VMan800'; const f = fit(ctx, lines.join('\n').replace(/\n/g, ' '), fam, box.w, o.max || 88, o.min || 40, 4);
  const lineArr = lines.length > 1 ? lines : f.lines; const px = lines.length > 1 ? Math.min(f.px, ...lines.map((l) => { for (let s = o.max || 88; s >= 30; s -= 2) { ctx.font = `${s}px ${fam}`; if (ctx.measureText(l).width <= box.w) return s; } return 30; })) : f.px;
  const lh = px * 1.15; let wi = 0; ctx.textBaseline = 'top'; ctx.font = `${px}px ${fam}`; const total = lineArr.length * lh; let y = box.y + (box.h - total) / 2;
  lineArr.forEach((line, li) => { const lw = ctx.measureText(line).width; let x = o.left ? box.x : box.x + (box.w - lw) / 2; words(line).forEach((w) => { const p = ease.back(prog(t, delay + wi * 0.16, 0.34)); const ww = ctx.measureText(w).width; if (p > 0) { ctx.save(); ctx.translate(x + ww / 2, y + px / 2 + (1 - clamp(p)) * 30); ctx.scale(p, p); ctx.globalAlpha = clamp(p * 1.5); ctx.textAlign = 'center'; ctx.fillStyle = (o.accent && o.accent.includes(wi)) ? BLUE2 : '#fff'; ctx.fillText(w, 0, -px / 2); ctx.restore(); } x += ww + ctx.measureText(' ').width; wi++; }); y += lh; });
  return wi;
}
function card(ctx, im, x, y, w, h, o = {}) {
  ctx.save(); ctx.translate(x + w / 2, y + h / 2); ctx.rotate(o.rot || 0); const sc = o.scale == null ? 1 : o.scale; ctx.scale(sc, sc); ctx.globalAlpha = o.alpha == null ? 1 : o.alpha;
  ctx.shadowColor = 'rgba(0,0,0,.55)'; ctx.shadowBlur = 36; ctx.shadowOffsetY = 14; ctx.fillStyle = '#111'; rrect(ctx, -w / 2, -h / 2, w, h, 26); ctx.fill(); ctx.shadowColor = 'transparent';
  ctx.save(); rrect(ctx, -w / 2, -h / 2, w, h, 26); ctx.clip(); drawCover(ctx, im, -w / 2, -h / 2, w, h, o.zoom || 1, 0.5, o.py == null ? 0.5 : o.py);
  if (o.shine != null && o.shine > 0 && o.shine < 1) { ctx.globalCompositeOperation = 'lighter'; const sx = -w + o.shine * w * 2.4; const g = ctx.createLinearGradient(sx - w * 0.25, -h / 2, sx + w * 0.25, h / 2); g.addColorStop(0, 'rgba(255,255,255,0)'); g.addColorStop(0.5, 'rgba(255,255,255,.4)'); g.addColorStop(1, 'rgba(255,255,255,0)'); ctx.fillStyle = g; ctx.fillRect(-w / 2, -h / 2, w, h); }
  ctx.restore();
  if (o.label) { ctx.font = '26px VMan800'; const lw = ctx.measureText(o.label).width + 36; ctx.fillStyle = o.labelBg || 'rgba(0,0,0,.65)'; rrect(ctx, -w / 2 + 14, h / 2 - 58, lw, 42, 21); ctx.fill(); ctx.fillStyle = '#fff'; ctx.textBaseline = 'middle'; ctx.textAlign = 'left'; ctx.fillText(o.label, -w / 2 + 32, h / 2 - 36); }
  ctx.restore();
}
function sparkleBurst(ctx, cx, cy, t, at, n = 16, spread = 220) {
  const lt = t - at; if (lt < 0 || lt > 1.1) return; const r = rng(53); ctx.save();
  for (let i = 0; i < n; i++) { const a = r() * 6.28, d = (30 + r() * spread) * ease.out(clamp(lt / 0.7)); const s = (8 + r() * 14) * (1 - clamp(lt / 1.1)); ctx.globalAlpha = clamp(1 - lt / 1.1); ctx.fillStyle = i % 3 ? YEL : '#fff'; ctx.beginPath(); for (let k = 0; k < 8; k++) { const ang = lt * 3 + i + (k * Math.PI) / 4; const rr = k % 2 ? s * 0.28 : s; ctx.lineTo(cx + Math.cos(a) * d + Math.cos(ang) * rr, cy + Math.sin(a) * d + Math.sin(ang) * rr); } ctx.closePath(); ctx.fill(); }
  ctx.restore();
}
function tile(ctx, im, x, y, w, h, label, play) {
  ctx.save(); ctx.translate(x, y); ctx.shadowColor = 'rgba(0,0,0,.5)'; ctx.shadowBlur = 24; ctx.shadowOffsetY = 10; ctx.fillStyle = '#111'; rrect(ctx, 0, 0, w, h, 20); ctx.fill(); ctx.shadowColor = 'transparent';
  ctx.save(); rrect(ctx, 0, 0, w, h, 20); ctx.clip(); drawCover(ctx, im, 0, 0, w, h, 1, 0.5, 0.5); ctx.restore();
  if (play) { ctx.fillStyle = 'rgba(0,0,0,.45)'; ctx.beginPath(); ctx.arc(w / 2, h / 2, Math.min(w, h) * 0.14, 0, 7); ctx.fill(); ctx.fillStyle = '#fff'; const r = Math.min(w, h) * 0.07; ctx.beginPath(); ctx.moveTo(w / 2 - r * 0.6, h / 2 - r); ctx.lineTo(w / 2 + r, h / 2); ctx.lineTo(w / 2 - r * 0.6, h / 2 + r); ctx.fill(); }
  ctx.restore();
}

// ───────── scènes ─────────
let EX = null; // frames d'une vidéo d'exemple
let STILLS = {};
const SCN = {
  s1(ctx, t, dur) {
    const before = STILLS.before; const bw = LAND ? W * 0.22 : W * 0.5, bh = bw * 1.9;
    const cx = LAND ? W * 0.76 : W / 2, cy = LAND ? H * 0.52 : H * 0.69;
    phone(ctx, cx, cy, bw, Math.min(bh, LAND ? H * 0.86 : H * 0.5), (x, y, w, h) => { drawCover(ctx, before, x, y, w, h, 1.0 + 0.02 * Math.sin(t * 3), 0.5, 0.5); ctx.fillStyle = 'rgba(0,0,0,.25)'; ctx.fillRect(x, y, w, h); }, { rot: Math.sin(t * 2.2) * 0.025 + (1 - ease.out(prog(t, 0, 0.7))) * 0.4, alpha: ease.out(prog(t, 0.1, 0.5)) });
    chip(ctx, TXT.c1, cx, cy + Math.min(bh, LAND ? H * 0.86 : H * 0.5) / 2 + 40, { center: true, bg: 'rgba(255,255,255,.12)', fg: '#ddd', px: 26, p: ease.back(prog(t, 1.2, 0.4)) });
    const box = LAND ? { x: W * 0.05, y: H * 0.2, w: W * 0.5, h: H * 0.5 } : { x: W * 0.07, y: H * 0.1, w: W * 0.86, h: H * 0.3 };
    popWords(ctx, TXT.s1, box, t, 0.3, { max: LAND ? 70 : 74, left: LAND, accent: LANG === 'fr' ? [3, 4, 5] : [4, 5, 6] });
  },
  s2(ctx, t, dur) {
    const A = STILLS.before, B = STILLS.after;
    chip(ctx, TXT.s2c, LAND ? W * 0.06 : W * 0.07, LAND ? H * 0.1 : H * 0.07, { p: ease.back(prog(t, 0.1, 0.4)), px: 34 });
    const cw = LAND ? W * 0.22 : W * 0.38, ch = cw * 1.15; const ax = LAND ? W * 0.12 : (W - cw) / 2, ay = LAND ? H * 0.17 : H * 0.11;
    card(ctx, A, ax, ay, cw, ch, { label: TXT.s2a, alpha: ease.out(prog(t, 0.2, 0.5)), scale: 0.9 + 0.1 * ease.out(prog(t, 0.2, 0.5)), py: 0.5 });
    const rt = 2.1; const p = ease.out(prog(t, rt, 0.6));
    arrow(ctx, LAND ? W * 0.45 : W / 2, LAND ? ay + ch / 2 : ay + ch + H * 0.035, LAND ? 100 : 80, prog(t, 1.4, 0.6), !LAND);
    const bw = LAND ? W * 0.3 : W * 0.56, bh = bw * (LAND ? 1.0 : 0.92); const bx = LAND ? W * 0.58 : (W - bw) / 2, by = LAND ? H * 0.13 : ay + ch + H * 0.07;
    if (p > 0) card(ctx, B, bx, by, bw, bh, { label: TXT.s2b, labelBg: BLUE, scale: 0.8 + 0.2 * ease.back(prog(t, rt, 0.55)), alpha: clamp(p * 1.5), shine: prog(t, rt + 0.5, 1.0) });
    sparkleBurst(ctx, bx + bw / 2, by + bh / 2, t, rt + 0.15, 18, bw * 0.7);
    const cy = LAND ? H * 0.8 : H * 0.79; const cp = ease.back(prog(t, 0.9, 0.5));
    ctx.save(); ctx.translate(W / 2, cy); ctx.scale(cp, cp); ctx.globalAlpha = clamp(cp * 1.4); ctx.font = `${LAND ? 40 : 44}px VMan800`; const cmdW = ctx.measureText(TXT.cmd).width; ctx.font = '22px VMan800'; const subW = ctx.measureText(TXT.cmdSub).width; ctx.font = `${LAND ? 40 : 44}px VMan800`; const cw2 = cmdW + subW + 120; ctx.fillStyle = '#0e1319'; ctx.strokeStyle = BLUE; ctx.lineWidth = 3; rrect(ctx, -cw2 / 2, -38, cw2, 76, 38); ctx.fill(); ctx.stroke(); ctx.fillStyle = BLUE2; ctx.textAlign = 'left'; ctx.textBaseline = 'middle'; ctx.fillText(TXT.cmd, -cw2 / 2 + 36, 3); ctx.font = '22px VMan800'; ctx.fillStyle = '#9aa'; ctx.textAlign = 'right'; ctx.fillText(TXT.cmdSub, cw2 / 2 - 28, 3); ctx.restore();
    chipRow(ctx, TXT.steps.map((x, i) => ({ text: (i + 1) + ' · ' + x, p: ease.back(prog(t, 3.0 + i * 0.5, 0.35)) })).filter((x) => x.p > 0), W / 2, cy + 78, { bg: 'rgba(41,151,255,.18)', fg: BLUE2, px: LAND ? 26 : 24 });
    const fp = ease.out(prog(t, 5.2, 0.5)); if (fp > 0) { ctx.save(); ctx.globalAlpha = fp; ctx.font = '28px VMan800'; ctx.fillStyle = YEL; ctx.textAlign = LAND ? 'right' : 'center'; ctx.fillText(TXT.free, LAND ? W * 0.94 : W / 2, LAND ? H * 0.1 : cy + 150); ctx.restore(); }
  },
  s3(ctx, t, dur) {
    chip(ctx, TXT.s3c, LAND ? W * 0.06 : W * 0.07, LAND ? H * 0.1 : H * 0.06, { p: ease.back(prog(t, 0.1, 0.4)), px: 34, bg: '#7a5cff' });
    const sw = LAND ? W * 0.17 : W * 0.3, sh = sw * 1.15; const x0 = LAND ? W * 0.06 : W * 0.14, y0 = LAND ? H * 0.22 : H * 0.11;
    const pa = ease.out(prog(t, 0.3, 0.5)); const x1 = LAND ? x0 + sw + W * 0.05 : x0 + sw + W * 0.14, y1 = LAND ? y0 : y0;
    card(ctx, STILLS.before, x0, y0, sw, sh, { label: TXT.p1, alpha: pa, scale: 0.9 + 0.1 * pa });
    arrow(ctx, LAND ? x0 + sw + W * 0.025 : x0 + sw + W * 0.07, y0 + sh / 2, 60, prog(t, 1.0, 0.5), false);
    // détourage : le fond s'efface de gauche à droite et le produit apparaît sur une scène
    const cp = prog(t, 1.4, 1.1); const cardW = sw, cardH = sh;
    ctx.save(); ctx.translate(x1, y1); ctx.globalAlpha = ease.out(prog(t, 1.3, 0.4)); ctx.fillStyle = '#10151c'; rrect(ctx, 0, 0, cardW, cardH, 26); ctx.fill(); ctx.strokeStyle = 'rgba(105,183,255,.4)'; ctx.lineWidth = 2; ctx.stroke(); ctx.save(); rrect(ctx, 0, 0, cardW, cardH, 26); ctx.clip();
    if (cp < 1) { ctx.save(); ctx.beginPath(); ctx.rect(cp * cardW, 0, cardW, cardH); ctx.clip(); drawCover(ctx, STILLS.before, 0, 0, cardW, cardH, 1, 0.5, 0.5); ctx.restore(); }
    const sp = STILLS.sprite; const k = Math.min(cardW * 0.8 / sp.width, cardH * 0.84 / sp.height); ctx.save(); ctx.beginPath(); ctx.rect(0, 0, cp * cardW, cardH); ctx.clip(); ctx.drawImage(sp, (cardW - sp.width * k) / 2, (cardH - sp.height * k) / 2, sp.width * k, sp.height * k); ctx.restore();
    if (cp > 0 && cp < 1) { ctx.fillStyle = withAlpha(BLUE2, 0.9); ctx.fillRect(cp * cardW - 2, 0, 4, cardH); }
    ctx.restore();
    ctx.font = '26px VMan800'; const lw = ctx.measureText(TXT.p2).width + 36; ctx.fillStyle = BLUE; rrect(ctx, 14, cardH - 58, lw, 42, 21); ctx.fill(); ctx.fillStyle = '#fff'; ctx.textBaseline = 'middle'; ctx.fillText(TXT.p2, 32, cardH - 36); ctx.restore();
    // la vidéo
    const pw = LAND ? W * 0.2 : W * 0.38, ph = pw * 1.95; const px = LAND ? W * 0.72 : W / 2, py = LAND ? H * 0.52 : H * 0.575; const pt = ease.back(prog(t, 2.4, 0.6));
    arrow(ctx, LAND ? (x1 + sw + (px - pw / 2)) / 2 : W / 2, LAND ? py : y0 + sh + H * 0.04, LAND ? 90 : 70, prog(t, 2.2, 0.6), !LAND);
    if (pt > 0) {
      const fi = Math.floor(Math.max(0, t - 2.6) * 12) % EX.length; const fr = EX[fi];
      phone(ctx, px, py, pw, Math.min(ph, LAND ? H * 0.9 : H * 0.44), (x, y, w, h) => { if (fr) drawCover(ctx, fr, x, y, w, h, 1, 0.5, 0.5); }, { scale: pt, alpha: clamp(pt * 1.4) });
      ctx.save(); ctx.globalAlpha = clamp(pt); ctx.font = '26px VMan800'; ctx.textAlign = 'center'; ctx.fillStyle = '#fff'; const lbl = TXT.p3; const lw2 = ctx.measureText(lbl).width + 36; ctx.fillStyle = '#7a5cff'; const ly = py + Math.min(ph, LAND ? H * 0.9 : H * 0.44) / 2 + 36; rrect(ctx, px - lw2 / 2, ly - 21, lw2, 42, 21); ctx.fill(); ctx.fillStyle = '#fff'; ctx.textBaseline = 'middle'; ctx.fillText(lbl, px, ly + 1); ctx.restore();
    }
    // atouts
    chipFlow(ctx, TXT.feats.map((f, i) => ({ text: f, p: ease.back(prog(t, 4.2 + i * 0.7, 0.4)) })).filter((x) => x.p > 0), LAND ? W * 0.06 : W * 0.07, LAND ? H * 0.62 : H * 0.9, LAND ? W * 0.5 : W * 0.95, { px: LAND ? 28 : 26, bg: 'rgba(122,92,255,.22)', fg: '#d9d0ff', icon: true });
  },
  s4(ctx, t, dur) {
    const imgsA = STILLS.collA, imgsB = STILLS.collB; const rows = [[imgsA, TXT.s4[0], BLUE, -1], [imgsB, TXT.s4[1], '#7a5cff', 1]];
    const th = LAND ? H * 0.3 : H * 0.25, tw = th * 0.82; const gap = 22;
    rows.forEach(([arr, label, col, dir], r) => {
      const y = LAND ? H * (0.17 + r * 0.38) : H * (0.2 + r * 0.33); const a = ease.out(prog(t, 0.15 + r * 0.3, 0.5)); ctx.save(); ctx.globalAlpha = a;
      chip(ctx, label, LAND ? W * 0.05 : W * 0.06, y - 34, { px: 28, bg: col });
      const total = arr.length * (tw + gap); const off = ((t * 70 * dir) % total + total) % total;
      for (let k = -1; k <= arr.length + 1; k++) { const idx = ((k % arr.length) + arr.length) % arr.length; const x = k * (tw + gap) - (dir > 0 ? off : -off) + (dir > 0 ? 0 : 0); const xx = ((x % total) + total) % total - tw; tile(ctx, arr[idx], xx, y, tw, th, '', r === 1); }
      ctx.restore();
    });
    const tp = ease.out(prog(t, 1.2, 0.6)); ctx.save(); ctx.globalAlpha = tp; ctx.font = `${LAND ? 36 : 34}px VMan800`; ctx.textAlign = 'center'; ctx.fillStyle = '#fff'; ctx.fillText(TXT.s4t, W / 2, LAND ? H * 0.94 : H * 0.9); ctx.restore();
  },
  s5(ctx, t, dur) {
    const lp = ease.back(prog(t, 0.1, 0.6)); ctx.save(); ctx.translate(W / 2, LAND ? H * 0.28 : H * 0.24); ctx.scale(lp, lp); ctx.globalAlpha = clamp(lp * 1.4); ctx.font = `${LAND ? 110 : 96}px VMan800`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; const lw = ctx.measureText('SlashAtlas').width; ctx.fillStyle = BLUE; ctx.fillText('/', -lw / 2 - 30, 0); ctx.fillStyle = '#fff'; ctx.fillText('SlashAtlas', 18, 0); ctx.restore();
    const tp = ease.out(prog(t, 0.6, 0.5)); ctx.save(); ctx.globalAlpha = tp; ctx.textAlign = 'center'; ctx.fillStyle = '#cfe6ff'; ctx.font = `${LAND ? 44 : 42}px VMan800`; ctx.fillText(TXT.s5a, W / 2, LAND ? H * 0.42 : H * 0.36); ctx.fillText(TXT.s5b, W / 2, LAND ? H * 0.42 + 56 : H * 0.36 + 54); ctx.restore();
    if (LAND) chipRow(ctx, TXT.pills.map((x, i) => ({ text: x, bg: i === 0 ? BLUE : i === 1 ? '#1d8f5a' : '#7a5cff', p: ease.back(prog(t, 1.2 + i * 0.35, 0.4)) })).filter((x) => x.p > 0), W / 2, H * 0.64, { px: 32 });
    else TXT.pills.forEach((p, i) => { const pp = ease.back(prog(t, 1.2 + i * 0.35, 0.4)); if (pp > 0) chip(ctx, p, W / 2, H * (0.5 + i * 0.075), { center: true, px: 34, bg: i === 0 ? BLUE : i === 1 ? '#1d8f5a' : '#7a5cff', p: pp }); });
    const bp = ease.back(prog(t, 2.4, 0.5)); if (bp > 0) { ctx.save(); ctx.translate(W / 2, LAND ? H * 0.84 : H * 0.8); const pu = bp * (1 + Math.sin(t * 6) * 0.02); ctx.scale(pu, pu); ctx.font = `${LAND ? 52 : 54}px VMan800`; const bw = ctx.measureText(TXT.url).width + 110; ctx.fillStyle = YEL; rrect(ctx, -bw / 2, -46, bw, 92, 46); ctx.fill(); ctx.fillStyle = '#1b1200'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText(TXT.url, 0, 3); ctx.restore(); }
    sparkleBurst(ctx, W / 2, LAND ? H * 0.28 : H * 0.24, t, 0.3, 14, 260);
  },
};
const EVENTS = {
  s1: (dur) => { const e = []; for (let i = 0; i < 9; i++) e.push({ t: 0.3 + i * 0.16, k: 'pop', a: 420 + i * 40, g: 0.6 }); e.push({ t: 1.2, k: 'pop', a: 700 }); if (dur > 2) e.push({ t: dur - 0.9, k: 'riser', a: 0.9, g: 0.7 }); return e; },
  s2: () => [{ t: 0.2, k: 'swish' }, { t: 0.9, k: 'pop', a: 560 }, { t: 1.4, k: 'whoosh', a: 1, g: 0.5 }, { t: 2.1, k: 'impact', g: 0.8 }, { t: 2.15, k: 'sparkle' }, { t: 3.0, k: 'tick' }, { t: 3.5, k: 'tick' }, { t: 4.0, k: 'tick' }, { t: 5.2, k: 'chime', a: 988, g: 0.6 }],
  s3: () => { const e = [{ t: 0.3, k: 'swish' }, { t: 1.0, k: 'tick' }, { t: 1.4, k: 'whoosh', a: 1, g: 0.8 }, { t: 2.5, k: 'thud', g: 0.8 }, { t: 2.7, k: 'sparkle' }]; for (let i = 0; i < 4; i++) e.push({ t: 4.2 + i * 0.7, k: 'pop', a: 560 + i * 80 }); e.push({ t: 7.2, k: 'chime', a: 1175, g: 0.5 }); return e; },
  s4: () => [{ t: 0.2, k: 'whoosh', a: 1, g: 0.6 }, { t: 0.5, k: 'pop', a: 600 }, { t: 1.2, k: 'chime', a: 880, g: 0.5 }],
  s5: () => [{ t: 0.1, k: 'impact', g: 0.7 }, { t: 0.4, k: 'sparkle' }, { t: 1.2, k: 'pop', a: 560 }, { t: 1.55, k: 'pop', a: 640 }, { t: 1.9, k: 'pop', a: 720 }, { t: 2.4, k: 'cash', g: 0.6 }, { t: 3.2, k: 'chime', a: 1175, g: 0.7 }],
};
const MIN = { s1: 3.8, s2: 9.0, s3: 10.5, s4: 6.0, s5: 5.2 };

(async () => {
  fonts();
  // images fixes
  STILLS = { before: await img(C('skincareglow-avant')), after: await img(C('skincareglow-apres')) };
  const spPath = path.join(STATIC, 'img', 'video', 'cut-lotion.webp'); STILLS.sprite = await img(spPath);
  STILLS.collA = await Promise.all(['fashionposter', 'splashshot', 'skincareglow', 'bagluxury', 'lipstickline', 'menuhero', 'productglow', 'openhouse'].map((n) => img(C(n + '-apres'))));
  // vidéos d'exemple : une image par seconde de chacune pour la ligne « vidéos », et toutes les images (12 par seconde) de l'exemple de beauté
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'promo-'));
  const exDir = path.join(STATIC, 'video', 'exemples'); const stills = [];
  for (const st of ['lotion', 'robe', 'plat']) for (const sec of [4.8, 9.5, 15.0]) { const f = path.join(tmp, `s_${st}_${sec}.png`); execFileSync(FFMPEG, ['-y', '-loglevel', 'error', '-ss', String(sec), '-i', path.join(exDir, `ex-${st}-${LANG}.mp4`), '-frames:v', '1', '-vf', 'scale=300:-2', f]); stills.push(await img(f)); }
  STILLS.collB = stills;
  const fdir = path.join(tmp, 'f'); fs.mkdirSync(fdir);
  execFileSync(FFMPEG, ['-y', '-loglevel', 'error', '-t', '16', '-i', path.join(exDir, `ex-lotion-${LANG}.mp4`), '-vf', 'fps=12,scale=300:-2', path.join(fdir, 'e%04d.jpg')]);
  EX = []; for (const f of fs.readdirSync(fdir).sort()) EX.push(await loadImage(path.join(fdir, f)));
  // voix
  const kinds = ['s1', 's2', 's3', 's4', 's5']; const clips = {}; const vd = {};
  for (const k of kinds) { const r = await V.tts(TXT.v[k], LANG, 'f', k === 's1' ? 4.2 : 11); clips[k] = r.pcm; vd[k] = r.pcm.length / SR; }
  let t0 = 0; const sc = kinds.map((k, i) => { const d = Math.max(MIN[k], vd[k] + 0.6 + (i === kinds.length - 1 ? 0.8 : 0)); const o = { k, start: t0, dur: d }; t0 += d; return o; }); const total = t0;
  const ev = []; sc.forEach((s) => EVENTS[s.k](s.dur).forEach((e) => ev.push({ ...e, t: s.start + e.t }))); sc.slice(1).forEach((s) => ev.push({ t: s.start - 0.3, k: 'whoosh', a: 1, g: 0.7 }));
  const fx = sfxTrack(ev, total + 1); const mu = music('beat', 'mode', total + 0.5); const voices = sc.map((s) => ({ at: s.start + 0.3, pcm: clips[s.k] }));
  const wav = mix({ music: mu, sfx: fx, voices, seconds: total, hasVoice: true, musicLevel: 0.55 });
  const wavFile = path.join(tmp, 'a.wav'); fs.writeFileSync(wavFile, wav);
  const ff = spawn(FFMPEG, ['-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s', `${W}x${H}`, '-framerate', String(FPS), '-i', 'pipe:0', '-i', wavFile, '-map', '0:v', '-map', '1:a', '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '24', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', '-c:a', 'aac', '-b:a', '128k', '-t', total.toFixed(2), OUT], { stdio: ['pipe', 'ignore', 'inherit'] });
  const done = new Promise((res, rej) => { ff.on('close', (c) => (c === 0 ? res() : rej(new Error('ffmpeg ' + c)))); }); ff.stdin.on('error', () => {});
  const cv = createCanvas(W, H); const ctx = cv.getContext('2d'); const N = Math.round(total * FPS);
  for (let f = 0; f < N; f++) {
    const t = f / FPS; let si = sc.length - 1; for (let i = 0; i < sc.length; i++) if (t < sc[i].start + sc[i].dur) { si = i; break; }
    const s = sc[si]; ctx.globalAlpha = 1; background(ctx, t); ctx.save(); const z = 1 + 0.02 * clamp((t - s.start) / s.dur); ctx.translate(W / 2, H / 2); ctx.scale(z, z); ctx.translate(-W / 2, -H / 2); SCN[s.k](ctx, t - s.start, s.dur); ctx.restore();
    for (let i = 1; i < sc.length; i++) { const b = sc[i].start; const p = (t - (b - 0.2)) / 0.45; if (p > 0 && p < 1) { ctx.save(); ctx.globalAlpha = Math.sin(p * Math.PI) * 0.9; ctx.fillStyle = BLUE; ctx.fillRect(0, 0, W * ease.io(clamp(p * 2)), H); ctx.restore(); } }
    const buf = cv.data(); if (!ff.stdin.write(buf)) await new Promise((r) => ff.stdin.once('drain', r));
  }
  ff.stdin.end(); await done; fs.rmSync(tmp, { recursive: true, force: true });
  console.log('ok', OUT, total.toFixed(1) + 's', (fs.statSync(OUT).size / 1e6).toFixed(2) + 'MB', JSON.stringify(sc.map((s) => [s.k, +s.dur.toFixed(1)])));
})().catch((e) => { console.error('ERR', e.stack || e.message); process.exit(1); });
