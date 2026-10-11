'use strict';
// Moteur de vidéos publicitaires : photos du client + textes → vidéo MP4 (animations, musique, voix off facultative).
// Tout est dessiné image par image (canvas) puis encodé par ffmpeg : le produit reste identique, aucune IA vidéo, coût quasi nul.
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');
const { createCanvas, loadImage, GlobalFonts } = require('@napi-rs/canvas');
const FFMPEG = require('ffmpeg-static');
const qrcode = require('./vendor/qrcode.js');
const { localCutout } = require('./cutout');
const { music, sfxTrack, mix: mixAudio } = require('./sfx');

const FPS = 24;
const SR = 24000; // fréquence audio (identique à la voix Chirp 3 HD)
const SIZES = { '9:16': [720, 1280], '1:1': [720, 720], '16:9': [1280, 720] };
const MAX_SECONDS = 45;

let fontsOk = false;
function fonts() {
  if (fontsOk) return;
  const d = path.join(__dirname, 'fonts');
  [['manrope-latin-800-normal.woff2', 'VMan800'], ['manrope-latin-500-normal.woff2', 'VMan500'], ['playfair-display-latin-700-normal.woff2', 'VPlayB'],
    ['playfair-display-latin-400-italic.woff2', 'VPlayI'], ['bebas-neue-latin-400-normal.woff2', 'VBebas']].forEach(([f, n]) => GlobalFonts.registerFromPath(path.join(d, f), n));
  fontsOk = true;
}

// ───────── outils ─────────
const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
const prog = (t, s, d) => clamp((t - s) / d);
const ease = {
  out: (t) => 1 - Math.pow(1 - t, 3),
  in: (t) => t * t * t,
  io: (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2),
  back: (t) => { const c = 1.70158; return 1 + (c + 1) * Math.pow(t - 1, 3) + c * Math.pow(t - 1, 2); },
};
const hsl = (h, s, l, a = 1) => `hsla(${Math.round(h)},${Math.round(s * 100)}%,${Math.round(l * 100)}%,${a})`;
/** Même couleur avec une autre opacité (hexa, hsl, hsla ou rgba). */
function withAlpha(c, a) {
  c = String(c).trim(); let m;
  if ((m = /^#([0-9a-f]{6})$/i.exec(c))) { const n = parseInt(m[1], 16); return `rgba(${n >> 16},${(n >> 8) & 255},${n & 255},${a})`; }
  if ((m = /^hsla?\(([^,]+),([^,]+),([^,)]+)/.exec(c))) return `hsla(${m[1]},${m[2]},${m[3]},${a})`;
  if ((m = /^rgba?\(([^,]+),([^,]+),([^,)]+)/.exec(c))) return `rgba(${m[1]},${m[2]},${m[3]},${a})`;
  return c;
}
function rng(seed) { let s = seed >>> 0; return () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; }; }

/** Teinte dominante de la photo (pour accorder les couleurs de la vidéo au produit). */
function palette(img, fallbackH) {
  const c = createCanvas(24, 24); const x = c.getContext('2d'); x.drawImage(img, 0, 0, 24, 24);
  const d = x.getImageData(0, 0, 24, 24).data; const buckets = new Array(12).fill(0);
  for (let i = 0; i < d.length; i += 4) {
    const r = d[i] / 255, g = d[i + 1] / 255, b = d[i + 2] / 255; const mx = Math.max(r, g, b), mn = Math.min(r, g, b); const v = mx, s = mx ? (mx - mn) / mx : 0;
    if (s < 0.25 || v < 0.2) continue;
    let h = 0; const df = mx - mn;
    if (mx === r) h = ((g - b) / df) % 6; else if (mx === g) h = (b - r) / df + 2; else h = (r - g) / df + 4;
    h = (h * 60 + 360) % 360; buckets[Math.floor(h / 30) % 12] += s * v;
  }
  let best = 0; buckets.forEach((v, i) => { if (v > buckets[best]) best = i; });
  const total = buckets.reduce((a, b) => a + b, 0);
  return { h: total > 4 ? best * 30 + 15 : fallbackH, strong: total > 4 };
}

function words(s) { return String(s || '').trim().split(/\s+/).filter(Boolean); }
function wrap(ctx, text, maxW) {
  const out = []; let line = '';
  for (const w of words(text)) { const t = line ? line + ' ' + w : w; if (ctx.measureText(t).width <= maxW || !line) line = t; else { out.push(line); line = w; } }
  if (line) out.push(line);
  return out;
}
/** Plus grande taille de police qui tient dans la boîte (largeur × lignes). */
function fit(ctx, text, family, maxW, maxPx, minPx, maxLines) {
  for (let px = maxPx; px >= minPx; px -= 2) {
    ctx.font = `${px}px ${family}`;
    const lines = wrap(ctx, text, maxW);
    if (lines.length <= maxLines && lines.every((l) => ctx.measureText(l).width <= maxW)) return { px, lines };
  }
  ctx.font = `${minPx}px ${family}`;
  return { px: minPx, lines: wrap(ctx, text, maxW).slice(0, maxLines) };
}
function rrect(ctx, x, y, w, h, r) { ctx.beginPath(); ctx.roundRect(x, y, w, h, r); }
function cardPath(ctx, c, style) { // forme de la carte, centrée sur (0,0)
  ctx.beginPath();
  if (style === 'beaute') { const r = c.w / 2; ctx.moveTo(-c.w / 2, c.h / 2 - 26); ctx.lineTo(-c.w / 2, -c.h / 2 + r); ctx.arc(0, -c.h / 2 + r, r, Math.PI, 0); ctx.lineTo(c.w / 2, c.h / 2 - 26); ctx.quadraticCurveTo(c.w / 2, c.h / 2, c.w / 2 - 26, c.h / 2); ctx.lineTo(-c.w / 2 + 26, c.h / 2); ctx.quadraticCurveTo(-c.w / 2, c.h / 2, -c.w / 2, c.h / 2 - 26); ctx.closePath(); } else ctx.roundRect(-c.w / 2, -c.h / 2, c.w, c.h, 26);
}
function drawCover(ctx, img, x, y, w, h, zoom = 1, px = 0.5, py = 0.5) {
  const s = Math.max(w / img.width, h / img.height) * zoom; const iw = img.width * s, ih = img.height * s;
  ctx.drawImage(img, x + (w - iw) * px, y + (h - ih) * py, iw, ih);
}

// ───────── styles ─────────
const STYLES = {
  mode: { head: 'VMan800', body: 'VMan500', upper: true, fallbackH: 340, spacing: 1 },
  beaute: { head: 'VPlayB', body: 'VMan500', upper: false, fallbackH: 335, spacing: 0 },
  promo: { head: 'VBebas', body: 'VMan800', upper: true, fallbackH: 14, spacing: 2 },
};

function theme(style, pal) {
  const h = pal.h;
  if (style === 'beaute') return { bg1: hsl(h, 0.55, 0.95), bg2: hsl(h, 0.5, 0.86), text: hsl(h, 0.4, 0.16), sub: hsl(h, 0.25, 0.32), accent: hsl(h, 0.7, 0.46), accent2: hsl(h, 0.8, 0.62), onAccent: '#fff', card: '#fff', tint: hsl(h, 0.5, 0.95, 0.78) };
  if (style === 'promo') return { bg1: hsl(h, 0.9, 0.5), bg2: hsl(h, 0.95, 0.3), text: '#fff', sub: 'rgba(255,255,255,.88)', accent: '#ffe14d', accent2: '#fff', onAccent: '#1b1200', card: '#fff', tint: hsl(h, 0.9, 0.38, 0.8) };
  return { bg1: hsl(h, 0.35, 0.13), bg2: hsl(h, 0.3, 0.05), text: '#fff', sub: 'rgba(255,255,255,.78)', accent: hsl(h, 0.85, 0.58), accent2: hsl(h, 0.9, 0.72), onAccent: '#0b0b0b', card: '#fff', tint: hsl(h, 0.35, 0.08, 0.82) };
}

function layout(W, H) {
  if (W > H) { // paysage : image à gauche, texte à droite
    const ch = H * 0.8, cw = ch * 0.86;
    return { mode: 'land', card: { x: W * 0.07, y: (H - ch) / 2, w: cw, h: ch }, text: { x: W * 0.07 + cw + W * 0.05, y: H * 0.14, w: W - (W * 0.07 + cw + W * 0.05) - W * 0.06, h: H * 0.72 }, u: 1 };
  }
  if (H > W * 1.5) { // vertical 9:16
    const cw = W * 0.82, ch = cw * 1.2;
    return { mode: 'tall', card: { x: (W - cw) / 2, y: H * 0.12, w: cw, h: ch }, text: { x: W * 0.08, y: H * 0.12 + ch + H * 0.045, w: W * 0.84, h: H * 0.3 }, u: 1 };
  }
  const ch = H * 0.5, cw = ch * 0.9; // carré
  return { mode: 'sq', card: { x: (W - cw) / 2, y: H * 0.07, w: cw, h: ch }, text: { x: W * 0.08, y: H * 0.07 + ch + H * 0.04, w: W * 0.84, h: H * 0.3 }, u: 1 };
}

// ───────── préparation d'une vidéo ─────────
async function toCanvas(b) {
  const raw = await loadImage(b); const k = Math.min(1, 1280 / Math.max(raw.width, raw.height));
  if (k >= 1) return raw; const c = createCanvas(Math.round(raw.width * k), Math.round(raw.height * k)); c.getContext('2d').drawImage(raw, 0, 0, c.width, c.height); return c;
}
/** Produit détouré : sprite RGBA. Dans l'ordre : image déjà détourée fournie (IA), puis détourage local si le fond est simple. */
async function makeSprite(P, i, buf) {
  try {
    if (P.sprites && P.sprites[i]) { const c = await toCanvas(P.sprites[i]); return { c, w: c.width, h: c.height }; }
    if (P.cutout === 'off') return null;
    const r = await localCutout(buf); if (r.ok && r.sprite) return { c: r.sprite.canvas, w: r.sprite.w, h: r.sprite.h };
  } catch (e) { console.error('cutout', e.message); }
  return null;
}
function reflection(sp) { // reflet du produit sur le sol : image retournée qui s'estompe
  const h = Math.round(sp.h * 0.5); const c = createCanvas(sp.w, h); const x = c.getContext('2d');
  x.translate(0, sp.h); x.scale(1, -1); x.drawImage(sp.c, 0, 0); x.setTransform(1, 0, 0, 1, 0, 0);
  x.globalCompositeOperation = 'destination-in'; const g = x.createLinearGradient(0, 0, 0, h); g.addColorStop(0, 'rgba(0,0,0,.38)'); g.addColorStop(1, 'rgba(0,0,0,0)'); x.fillStyle = g; x.fillRect(0, 0, sp.w, h);
  return c;
}

async function prepare(P) {
  fonts();
  const [W, H] = SIZES[P.ratio] || SIZES['9:16'];
  const style = STYLES[P.style] ? P.style : 'mode'; const S = STYLES[style];
  const imgs = []; const sprites = [];
  for (let i = 0; i < P.photos.length; i++) { imgs.push(await toCanvas(P.photos[i])); sprites.push(await makeSprite(P, i, P.photos[i])); }
  const first = sprites.find(Boolean);
  const pal = palette(first ? first.c : imgs[0], S.fallbackH);
  const th = theme(style, pal);
  const L = layout(W, H);
  // fond : la photo très floue (ou dégradé seul quand le produit est détouré), teinté
  const bg = createCanvas(W, H); const bx = bg.getContext('2d');
  const g = bx.createLinearGradient(0, 0, W * 0.3, H); g.addColorStop(0, th.bg1); g.addColorStop(1, th.bg2); bx.fillStyle = g; bx.fillRect(0, 0, W, H);
  if (!first) { bx.save(); bx.globalAlpha = style === 'promo' ? 0.28 : 0.4; bx.filter = 'blur(38px)'; drawCover(bx, imgs[0], -60, -60, W + 120, H + 120, 1.15); bx.restore(); bx.fillStyle = th.tint; bx.globalAlpha = 0.55; bx.fillRect(0, 0, W, H); bx.globalAlpha = 1; }
  // vignette (bords assombris) et grain de pellicule : finition « cinéma »
  const vg = createCanvas(W, H); const vx = vg.getContext('2d'); const rg = vx.createRadialGradient(W / 2, H / 2, Math.min(W, H) * 0.35, W / 2, H / 2, Math.max(W, H) * 0.78); rg.addColorStop(0, 'rgba(0,0,0,0)'); rg.addColorStop(1, style === 'beaute' ? 'rgba(90,30,60,.22)' : 'rgba(0,0,0,.5)'); vx.fillStyle = rg; vx.fillRect(0, 0, W, H);
  const gr = createCanvas(W + 160, H + 160); const gx = gr.getContext('2d'); const gd = gx.createImageData(gr.width, gr.height); const R = rng(77); for (let i = 0; i < gd.data.length; i += 4) { const v = R() * 255; gd.data[i] = gd.data[i + 1] = gd.data[i + 2] = v; gd.data[i + 3] = 9; } gx.putImageData(gd, 0, 0);
  // ombre de carte (repli quand le produit n'est pas détourable)
  const sh = createCanvas(Math.round(L.card.w + 160), Math.round(L.card.h + 160)); const sx = sh.getContext('2d');
  sx.translate(sh.width / 2, sh.height / 2 - 10); sx.shadowColor = 'rgba(0,0,0,.45)'; sx.shadowBlur = 46; sx.shadowOffsetY = 18; sx.fillStyle = '#000'; cardPath(sx, L.card, style); sx.fill();
  sx.shadowColor = 'transparent'; sx.globalCompositeOperation = 'destination-out'; cardPath(sx, L.card, style); sx.fill();
  const glow = (col) => { const c = createCanvas(512, 512); const x = c.getContext('2d'); const r = x.createRadialGradient(256, 256, 0, 256, 256, 256); r.addColorStop(0, withAlpha(col, 0.6)); r.addColorStop(1, withAlpha(col, 0)); x.fillStyle = r; x.fillRect(0, 0, 512, 512); return c; };
  const music = P.music || { mode: 'beat', beaute: 'ambient', promo: 'beat' }[style];
  return { W, H, L, style, S, th, pal, imgs, sprites, bg, vg, gr, sh, glowA: glow(th.accent), glowW: glow('rgba(255,255,255,1)'), T: P.texts, lang: P.lang === 'en' ? 'en' : 'fr', qr: P.qrUrl ? makeQr(P.qrUrl) : null, seed: 7, music, sfx: P.sfx !== false, hasSprite: !!first };
}
function makeQr(url) { try { const q = qrcode(0, 'M'); q.addData(String(url).slice(0, 200)); q.make(); return q; } catch (e) { return null; } }

const up = (V, s) => (V.S.upper ? String(s || '').toUpperCase() : String(s || ''));

// ───────── décor animé ─────────
function decor(ctx, V, t) {
  const { W, H, style, th } = V; const r = rng(V.seed);
  // grosses taches de lumière qui dérivent (profondeur)
  ctx.save(); ctx.globalCompositeOperation = style === 'mode' ? 'lighter' : 'source-over';
  for (let i = 0; i < 3; i++) { const s = Math.max(W, H) * (0.55 + r() * 0.35); const x = W * (0.2 + 0.6 * r()) + Math.sin(t * 0.25 + i * 2) * W * 0.08, y = H * (0.2 + 0.6 * r()) + Math.cos(t * 0.2 + i) * H * 0.05; ctx.globalAlpha = style === 'mode' ? 0.16 : style === 'beaute' ? 0.38 : 0.2; ctx.drawImage(i % 2 ? V.glowW : V.glowA, x - s / 2, y - s / 2, s, s); }
  ctx.restore();
  if (style === 'beaute') {
    for (let i = 0; i < 12; i++) { const x = r() * W, y0 = r() * H, s = 22 + r() * 70, sp = 14 + r() * 26, a = 0.1 + r() * 0.2; const y = ((y0 - t * sp) % (H + 200) + (H + 200)) % (H + 200) - 100; ctx.beginPath(); ctx.arc(x + Math.sin(t * 0.6 + i) * 14, y, s, 0, 7); ctx.fillStyle = i % 3 ? `rgba(255,255,255,${a})` : withAlpha(th.accent2, a); ctx.fill(); }
    for (let i = 0; i < 7; i++) { const x = ((r() * W + Math.sin(t * 0.7 + i) * 40 + t * 18) % (W + 80)) - 40, y = ((r() * H + t * (30 + r() * 30)) % (H + 80)) - 40, rot = t * (0.6 + r()) + i; ctx.save(); ctx.translate(x, y); ctx.rotate(rot); ctx.fillStyle = withAlpha(th.accent2, 0.35); ctx.beginPath(); ctx.ellipse(0, 0, 14, 6, 0, 0, 7); ctx.fill(); ctx.restore(); }
  } else if (style === 'promo') {
    ctx.save(); ctx.translate(W / 2, H * 0.45); ctx.rotate(t * 0.12); ctx.fillStyle = 'rgba(255,255,255,.09)'; const R = Math.max(W, H) * 1.1;
    for (let i = 0; i < 14; i++) { const a0 = (i / 14) * Math.PI * 2, a1 = a0 + Math.PI / 14; ctx.beginPath(); ctx.moveTo(0, 0); ctx.arc(0, 0, R, a0, a1); ctx.closePath(); ctx.fill(); }
    ctx.restore();
    for (let i = 0; i < 18; i++) { const x = r() * W, y = ((r() * H + t * (40 + r() * 70)) % (H + 40)) - 20, s = 5 + r() * 9, rot = t * (1 + r() * 3) + i; ctx.save(); ctx.translate(x, y); ctx.rotate(rot); ctx.fillStyle = i % 2 ? '#ffe14d' : 'rgba(255,255,255,.85)'; ctx.fillRect(-s / 2, -s, s, s * 2); ctx.restore(); }
  } else {
    ctx.save(); ctx.globalAlpha = 0.06; ctx.fillStyle = th.accent;
    for (let i = 0; i < 9; i++) { const w = 6 + r() * 36, x = ((r() * W + t * (10 + r() * 20) * (i % 2 ? 1 : -1)) % (W + 100) + (W + 100)) % (W + 100) - 50; ctx.fillRect(x, 0, w, H); }
    ctx.restore();
  }
}

// ───────── produit sur scène ─────────
function stageBox(V) {
  const { W, H, L } = V;
  if (L.mode === 'land') return { cx: W * 0.3, mw: W * 0.4, mh: H * 0.7, floor: H * 0.86 };
  if (L.mode === 'sq') return { cx: W / 2, mw: W * 0.58, mh: H * 0.46, floor: H * 0.6 };
  return { cx: W / 2, mw: W * 0.74, mh: H * 0.4, floor: H * 0.6 };
}
const FALL = 0.55;
/** Dessine le produit (détouré, ou photo en cadre) avec chute, rebond, ombre, reflet, éclat de lumière. Retourne sa boîte. */
function drawProduct(ctx, V, idx, t, o = {}) {
  const b = o.box || stageBox(V); const n = V.sprites.length; const sp = V.sprites[idx % n]; const th = V.th;
  const t0 = o.t0 == null ? 0.15 : o.t0; const lt = t - t0; if (lt < -0.001 && o.entrance !== 'none') return null;
  let dy = 0, sx = 1, sy = 1, alpha = 1, landed = true;
  if (o.entrance === 'drop') {
    const p = lt / FALL;
    if (p < 1) { landed = false; dy = -(V.H * 0.8) * (1 - p * p * p); sy = 1 + 0.05 * (1 - p); sx = 1 - 0.03 * (1 - p); } else { const tt = lt - FALL; dy = -Math.abs(Math.sin(tt * 10)) * Math.exp(-tt * 5.5) * 22; const sq = Math.exp(-tt * 13); sy = 1 - 0.1 * sq; sx = 1 + 0.06 * sq; }
  } else if (o.entrance === 'pop') { const p = ease.back(prog(lt, 0, 0.55)); sx = sy = Math.max(0.001, 0.4 + 0.6 * p); alpha = clamp(p * 1.6); }
  else if (o.entrance === 'spin') { const p = ease.back(prog(lt, 0, 0.7)); sx = sy = Math.max(0.001, 0.3 + 0.7 * p); alpha = clamp(p * 1.6); }
  const bob = landed ? Math.sin(lt * 2.1) * (o.bob == null ? 6 : o.bob) : 0; const tilt = (o.tilt || 0) * (landed ? 1 : 0.4) + (landed ? Math.sin(lt * 1.3) * 0.012 : 0);
  let w, h;
  if (sp) { const k = Math.min(b.mw / sp.w, b.mh / sp.h) * (o.scale || 1); w = sp.w * k; h = sp.h * k; }
  else { const card = V.L.card; const k = Math.min(b.mw / card.w, b.mh / card.h) * (o.scale || 1); w = card.w * k; h = card.h * k; }
  const x = b.cx - w / 2, floor = b.floor; const top = floor - h;
  // ombre au sol (plus large et plus pâle quand le produit est en l'air)
  const air = clamp(-dy / (V.H * 0.5)); ctx.save(); ctx.globalAlpha = (0.55 - 0.35 * air) * clamp(lt / 0.2 + 0.0001 > 0 ? 1 : 0);
  const sw = w * (0.62 + 0.3 * air), shh = Math.max(10, h * 0.07); const gr = ctx.createRadialGradient(b.cx, floor + 6, 2, b.cx, floor + 6, sw / 2); gr.addColorStop(0, 'rgba(0,0,0,.65)'); gr.addColorStop(1, 'rgba(0,0,0,0)');
  ctx.translate(b.cx, floor + 6); ctx.scale(1, shh / (sw / 2)); ctx.translate(-b.cx, -(floor + 6)); ctx.fillStyle = gr; ctx.beginPath(); ctx.arc(b.cx, floor + 6, sw / 2, 0, 7); ctx.fill(); ctx.restore();
  // podium (beauté) : disques empilés sous le produit
  if (V.style === 'beaute' && o.podium !== false && sp) { const a = clamp(lt * 4 + 0.2); ctx.save(); ctx.globalAlpha = a; ctx.fillStyle = withAlpha(th.accent2, 0.55); ctx.beginPath(); ctx.ellipse(b.cx, floor + 10, w * 0.62, h * 0.065 + 8, 0, 0, 7); ctx.fill(); ctx.fillStyle = 'rgba(255,255,255,.75)'; ctx.beginPath(); ctx.ellipse(b.cx, floor + 2, w * 0.5, h * 0.05 + 6, 0, 0, 7); ctx.fill(); ctx.restore(); }
  // reflet sur le sol
  if (sp && o.refl !== false && V.style !== 'promo' && landed) { if (!sp.refl) sp.refl = reflection(sp); ctx.save(); ctx.globalAlpha = clamp((lt - FALL) * 3) * (V.style === 'beaute' ? 0.5 : 1); ctx.drawImage(sp.refl, x, floor + 4, w, w * (sp.refl.height / sp.refl.width)); ctx.restore(); }
  ctx.save(); ctx.globalAlpha = alpha; ctx.translate(b.cx, floor + dy + bob); ctx.rotate(tilt); ctx.scale(sx, sy);
  if (sp) {
    ctx.shadowColor = V.style === 'promo' ? 'rgba(0,0,0,.45)' : 'rgba(0,0,0,.35)'; ctx.shadowBlur = 28; ctx.shadowOffsetY = 12;
    let src = sp.c;
    if (o.shine && lt > o.shine[0] && lt < o.shine[1]) { // éclat de lumière qui balaie le produit
      if (!sp.tmp) sp.tmp = createCanvas(sp.w, sp.h); const tx = sp.tmp.getContext('2d'); tx.clearRect(0, 0, sp.w, sp.h); tx.drawImage(sp.c, 0, 0);
      const p = (lt - o.shine[0]) / (o.shine[1] - o.shine[0]); const cx0 = -sp.w * 0.4 + p * sp.w * 1.8; tx.globalCompositeOperation = 'source-atop'; const gg = tx.createLinearGradient(cx0 - sp.w * 0.18, 0, cx0 + sp.w * 0.18, sp.h * 0.4); gg.addColorStop(0, 'rgba(255,255,255,0)'); gg.addColorStop(0.5, 'rgba(255,255,255,.55)'); gg.addColorStop(1, 'rgba(255,255,255,0)'); tx.fillStyle = gg; tx.fillRect(0, 0, sp.w, sp.h); tx.globalCompositeOperation = 'source-over'; src = sp.tmp;
    }
    ctx.drawImage(src, -w / 2, -h, w, h);
  } else {
    // repli : la photo entière dans un cadre arrondi (le produit reste identique)
    const card = V.L.card; ctx.translate(0, -h / 2); ctx.save(); const k = w / card.w; ctx.scale(k, k);
    const cdx = -card.w / 2, cdy = -card.h / 2; const c0 = { x: cdx, y: cdy, w: card.w, h: card.h };
    ctx.drawImage(V.sh, (-V.sh.width / 2), (-V.sh.height / 2 + 10), V.sh.width, V.sh.height);
    if (V.style === 'mode') { ctx.fillStyle = th.accent; rrect(ctx, cdx + 16, cdy + 16, card.w, card.h, 26); ctx.fill(); }
    if (V.style === 'promo') { ctx.fillStyle = '#ffe14d'; rrect(ctx, cdx - 10, cdy - 10, card.w + 20, card.h + 20, 30); ctx.fill(); }
    cardPath(ctx, c0, V.style); ctx.clip(); ctx.fillStyle = '#fff'; ctx.fillRect(cdx, cdy, card.w, card.h);
    drawCover(ctx, V.imgs[idx % n], cdx, cdy, card.w, card.h, (o.zoom || 1) * (1 + 0.09 * clamp(lt / 6)), 0.5, 0.45); ctx.restore();
  }
  ctx.restore();
  return { x, y: top + dy + bob, w, h, cx: b.cx, floor, landed };
}

/** Poussière et onde de choc à l'atterrissage. */
function impactFx(ctx, V, box, t, at) {
  const lt = t - at; if (lt < 0 || lt > 0.9) return; const r = rng(31); const fl = box.floor;
  ctx.save();
  const ring = ease.out(clamp(lt / 0.55)); ctx.globalAlpha = (1 - ring) * 0.55; ctx.strokeStyle = V.th.accent2 || '#fff'; ctx.lineWidth = 5 * (1 - ring) + 1; ctx.beginPath(); ctx.ellipse(box.cx, fl + 8, box.w * (0.35 + 0.9 * ring), (box.w * (0.35 + 0.9 * ring)) * 0.14, 0, 0, 7); ctx.stroke();
  for (let i = 0; i < 16; i++) { const dir = i < 8 ? -1 : 1; const sp = 90 + r() * 200; const p = ease.out(clamp(lt / 0.8)); const x = box.cx + dir * (box.w * 0.25 + sp * p * (0.5 + r())); const y = fl + 6 - Math.sin(p * Math.PI) * (20 + r() * 50) * (0.4 + r()); const s = (6 + r() * 12) * (1 - p * 0.4); ctx.globalAlpha = (1 - p) * 0.5; ctx.fillStyle = V.style === 'beaute' ? 'rgba(255,255,255,.9)' : 'rgba(230,230,230,.8)'; ctx.beginPath(); ctx.arc(x, y, s, 0, 7); ctx.fill(); }
  ctx.restore();
}
function starPath(ctx, x, y, r, rot) { ctx.beginPath(); for (let i = 0; i < 8; i++) { const a = rot + (i * Math.PI) / 4; const rr = i % 2 ? r * 0.28 : r; ctx.lineTo(x + Math.cos(a) * rr, y + Math.sin(a) * rr); } ctx.closePath(); }
function sparkles(ctx, V, cx, cy, t, at, count = 18, spread = 260) {
  const lt = t - at; if (lt < 0 || lt > 1.1) return; const r = rng(53); ctx.save();
  for (let i = 0; i < count; i++) { const a = r() * Math.PI * 2, d = (40 + r() * spread) * ease.out(clamp(lt / 0.7)); const s = (8 + r() * 16) * (1 - clamp(lt / 1.1)); ctx.globalAlpha = clamp(1 - lt / 1.1) * 0.95; ctx.fillStyle = i % 3 ? '#ffe14d' : '#fff'; starPath(ctx, cx + Math.cos(a) * d, cy + Math.sin(a) * d, s, lt * 3 + i); ctx.fill(); }
  ctx.restore();
}

// ───────── scènes ─────────
function textBlock(ctx, V, text, box, family, maxPx, minPx, maxLines, color, align = 'center', t = 0, delay = 0) {
  const f = fit(ctx, up(V, text), family, box.w, maxPx, minPx, maxLines);
  const a = ease.out(prog(t, delay, 0.45)); const lh = f.px * 1.12;
  ctx.save(); ctx.globalAlpha = a; ctx.textAlign = align; ctx.textBaseline = 'top'; ctx.fillStyle = color; ctx.font = `${f.px}px ${family}`;
  const x = align === 'center' ? box.x + box.w / 2 : align === 'right' ? box.x + box.w : box.x;
  f.lines.forEach((l, i) => ctx.fillText(l, x, box.y + (1 - a) * 24 + i * lh));
  ctx.restore();
  return f.lines.length * lh;
}
function brandTag(ctx, V, t) {
  if (!V.T.brand) return;
  const { W, th, S } = V; const a = ease.out(prog(t, 0.1, 0.5));
  ctx.save(); ctx.globalAlpha = a; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillStyle = th.sub; ctx.font = `26px ${S.body}`;
  const txt = V.T.brand.toUpperCase().split('').join(S.spacing ? ' ' : ''); ctx.fillText(txt.length > 30 ? V.T.brand.toUpperCase() : txt, V.L.mode === 'land' ? V.L.text.x + V.L.text.w / 2 : W / 2, V.L.mode === 'land' ? V.H * 0.08 : V.H * 0.06);
  ctx.restore();
}
/** Mot géant derrière le produit (effet de profondeur). */
function bigWord(ctx, V, t, word, box, delay = 0.2) {
  if (V.style === 'beaute' || !word) return; const a = ease.out(prog(t, delay, 0.8)); if (a <= 0) return;
  const { W } = V; const txt = up(V, word).slice(0, 18); ctx.save(); ctx.globalAlpha = a; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  let px = 260; ctx.font = `${px}px ${V.S.head}`; const mw = ctx.measureText(txt).width; px = Math.min(px, px * (W * 1.12 / mw)); ctx.font = `${px}px ${V.S.head}`;
  ctx.translate(W / 2 + Math.sin(t * 0.5) * 26 + (1 - a) * 80, box.floor - (box.mh || V.H * 0.4) * 0.55);
  if (V.style === 'promo') { ctx.fillStyle = 'rgba(255,255,255,.14)'; ctx.fillText(txt, 0, 0); } else { ctx.strokeStyle = withAlpha(V.th.accent, 0.55); ctx.lineWidth = 3; ctx.strokeText(txt, 0, 0); }
  ctx.restore();
}

function sceneHook(ctx, V, t, dur) {
  const { W, H, th, S, L } = V;
  brandTag(ctx, V, t);
  const box = { x: W * 0.08, y: H * 0.22, w: W * 0.84, h: H * 0.5 };
  const f = fit(ctx, up(V, V.T.hook), S.head, box.w, L.mode === 'land' ? 120 : 130, 44, 4); const lh = f.px * 1.1; const total = f.lines.length * lh;
  const ws = words(up(V, V.T.hook)); const longest = ws.reduce((b, w, i) => (w.length > ws[b].length ? i : b), 0);
  let wi = 0; ctx.textBaseline = 'top'; ctx.font = `${f.px}px ${S.head}`;
  f.lines.forEach((line, li) => {
    const lw = ctx.measureText(line).width; let x = box.x + (box.w - lw) / 2; const y = box.y + (box.h - total) / 2 + li * lh;
    words(line).forEach((w) => {
      const p = ease.back(prog(t, 0.25 + wi * 0.2, 0.35)); const ww = ctx.measureText(w).width;
      if (p > 0) {
        ctx.save(); ctx.translate(x + ww / 2, y + f.px / 2 + (1 - clamp(p)) * 40); ctx.scale(p, p); ctx.globalAlpha = clamp(p * 1.5); ctx.textAlign = 'center'; ctx.fillStyle = wi === longest ? th.accent : th.text;
        if (V.style === 'promo') { ctx.shadowColor = 'rgba(0,0,0,.35)'; ctx.shadowOffsetY = 6; }
        ctx.fillText(w, 0, -f.px / 2); ctx.restore();
      }
      x += ww + ctx.measureText(' ').width; wi++;
    });
  });
  const endAt = 0.25 + wi * 0.2; const bw = W * 0.28 * ease.out(prog(t, endAt, 0.4)); ctx.fillStyle = th.accent; ctx.fillRect(W / 2 - bw / 2, box.y + (box.h + total) / 2 + 28, bw, 8);
}
function evHook(V, dur) { const n = words(V.T.hook).length; const e = []; for (let i = 0; i < n; i++) e.push({ t: 0.25 + i * 0.2, k: 'pop', a: 460 + i * 70 }); if (dur > 1.8) e.push({ t: dur - 0.95, k: 'riser', a: 0.9, g: 0.8 }); return e; }

function sceneProduct(ctx, V, t, dur) {
  const { th, S, L, W, H } = V; const b = stageBox(V);
  bigWord(ctx, V, t, V.T.brand || (V.T.hook || '').split(/\s+/).sort((a, c) => c.length - a.length)[0], { ...b, mh: b.mh }, 0.3);
  // projecteur : cône de lumière qui s'allume pendant la chute
  if (V.hasSprite) { const a = ease.out(prog(t, 0.2, 0.7)) * (V.style === 'beaute' ? 0.0 : 0.22); ctx.save(); ctx.globalAlpha = a; const gr = ctx.createLinearGradient(0, 0, 0, b.floor); gr.addColorStop(0, 'rgba(255,255,255,.9)'); gr.addColorStop(1, 'rgba(255,255,255,0)'); ctx.fillStyle = gr; ctx.beginPath(); ctx.moveTo(b.cx - 30, -10); ctx.lineTo(b.cx + 30, -10); ctx.lineTo(b.cx + b.mw * 0.7, b.floor + 20); ctx.lineTo(b.cx - b.mw * 0.7, b.floor + 20); ctx.fill(); ctx.restore(); }
  const bx = drawProduct(ctx, V, 0, t, { entrance: 'drop', t0: 0.15, shine: [1.5, 2.3], tilt: V.style === 'promo' ? -0.05 : 0, bob: 7 });
  if (bx) impactFx(ctx, V, bx, t, 0.15 + FALL);
  const box = L.text; let y = L.mode === 'land' ? box.y : b.floor + H * 0.05;
  if (L.mode === 'tall') y = b.floor + H * 0.075;
  const tw = L.mode === 'land' ? { x: box.x, w: box.w } : { x: W * 0.08, w: W * 0.84 }; const al = L.mode === 'land' ? 'left' : 'center';
  if (V.T.brand) y += textBlock(ctx, V, V.T.brand, { ...tw, y }, S.head, 74, 36, 2, th.text, al, t, 0.95) + 10;
  const bar = ease.out(prog(t, 1.1, 0.5)) * 120; ctx.fillStyle = th.accent; ctx.fillRect(L.mode === 'land' ? tw.x : tw.x + tw.w / 2 - bar / 2, y, bar, 6); y += 22;
  const l1 = (V.T.lines && V.T.lines[0]) || V.T.hook;
  textBlock(ctx, V, l1, { ...tw, y }, V.style === 'mode' ? 'VMan800' : S.body === 'VMan500' ? S.body : 'VMan800', 40, 24, 3, th.sub, al, t, 1.3);
}
function evProduct(V, dur) { const e = [{ t: 0.12, k: 'whoosh', a: -1, g: 0.8 }, { t: 0.15 + FALL, k: 'thud' }, { t: 0.95, k: 'swish' }, { t: 1.3, k: 'pop', a: 620, g: 0.7 }]; e.push(V.style === 'beaute' ? { t: 1.5, k: 'sparkle' } : { t: 1.5, k: 'chime', a: 988, g: 0.5 }); return e; }

function check(ctx, x, y, s, color) { ctx.save(); ctx.strokeStyle = color; ctx.lineWidth = s * 0.16; ctx.lineCap = 'round'; ctx.lineJoin = 'round'; ctx.beginPath(); ctx.moveTo(x - s * 0.3, y); ctx.lineTo(x - s * 0.08, y + s * 0.24); ctx.lineTo(x + s * 0.34, y - s * 0.26); ctx.stroke(); ctx.restore(); }
function sceneBenefits(ctx, V, t, dur) {
  const { th, S, L, W, H } = V; const items = (V.T.lines || []).slice(0, 3); const land = L.mode === 'land';
  const b0 = stageBox(V); const b = { ...b0, mh: b0.mh * 0.92, mw: b0.mw * (land ? 0.95 : 0.8) };
  const bx = drawProduct(ctx, V, 1, t, { entrance: 'pop', t0: 0, box: b, shine: [1.2, 2.0], tilt: 0.0, bob: 6 }) || { x: b.cx - 50, y: b.floor - 100, w: 100, h: 100, cx: b.cx, floor: b.floor };
  items.forEach((it, i) => {
    const t1 = 0.55 + i * 0.7; const p = prog(t, t1, 0.5); if (p <= 0) return; const pe = ease.out(p);
    const fam = 'VMan800'; const f = fit(ctx, up(V, it), fam, (land ? W * 0.34 : W * 0.5) - 70, 38, 22, 2); ctx.font = `${f.px}px ${fam}`; const tw = Math.max(...f.lines.map((l) => ctx.measureText(l).width)); const pw = Math.min(land ? W * 0.38 : L.mode === 'sq' ? W * 0.5 : W * 0.54, tw + 84), ph = Math.max(66, f.lines.length * f.px * 1.12 + 26);
    const left = !land && i % 2 === 0; let px, py; const dotX = bx.x + bx.w * (left ? 0.3 : 0.72), dotY = bx.y + bx.h * (0.22 + i * 0.28);
    if (land) { px = W * 0.56; py = H * (0.22 + i * 0.22); } else { px = left ? W * 0.04 : W * 0.96 - pw; py = Math.min(H * 0.92 - ph, bx.y + bx.h * 0.04 + i * (Math.max(ph, 70) + 18)); }
    const ax = land ? px : left ? px + pw : px, ay = py + ph / 2; // point d'attache du trait sur l'étiquette
    ctx.save(); ctx.strokeStyle = th.accent; ctx.lineWidth = 3; ctx.globalAlpha = 0.9; ctx.beginPath(); ctx.moveTo(dotX, dotY); ctx.lineTo(dotX + (ax - dotX) * pe, dotY + (ay - dotY) * pe); ctx.stroke();
    ctx.fillStyle = th.accent; ctx.beginPath(); ctx.arc(dotX, dotY, 8 + Math.sin(t * 6 + i) * 1.5, 0, 7); ctx.fill(); ctx.globalAlpha = 0.3; ctx.beginPath(); ctx.arc(dotX, dotY, 8 + 14 * ((t * 1.5 + i * 0.3) % 1), 0, 7); ctx.fill(); ctx.restore();
    const pp = ease.back(prog(t, t1 + 0.3, 0.35)); if (pp <= 0) return;
    ctx.save(); ctx.translate(px + pw / 2, py + ph / 2); ctx.scale(pp, pp); ctx.globalAlpha = clamp(pp * 1.4);
    ctx.fillStyle = V.style === 'beaute' ? 'rgba(255,255,255,.92)' : 'rgba(20,20,24,.62)'; ctx.strokeStyle = th.accent; ctx.lineWidth = 2.5; rrect(ctx, -pw / 2, -ph / 2, pw, ph, ph / 2); ctx.fill(); ctx.stroke();
    ctx.fillStyle = th.accent; ctx.beginPath(); ctx.arc(-pw / 2 + 34, 0, 20, 0, 7); ctx.fill(); check(ctx, -pw / 2 + 34, 0, 30, th.onAccent);
    ctx.font = `${f.px}px ${fam}`; ctx.fillStyle = V.style === 'beaute' ? th.text : '#fff'; ctx.textAlign = 'left'; ctx.textBaseline = 'middle'; f.lines.forEach((l, k) => ctx.fillText(l, -pw / 2 + 66, (k - (f.lines.length - 1) / 2) * f.px * 1.12)); ctx.restore();
  });
}
function evBenefits(V, dur) { const n = (V.T.lines || []).slice(0, 3).length; const e = []; for (let i = 0; i < n; i++) { e.push({ t: 0.55 + i * 0.7, k: 'tick', g: 0.8 }); e.push({ t: 0.85 + i * 0.7, k: 'pop', a: 560 + i * 90 }); } return e; }

const SLAM = { at: 0.8, dur: 0.3 };
function sceneOffer(ctx, V, t, dur) {
  const { th, S, L, W, H } = V; const T = V.T; const land = L.mode === 'land'; const b0 = stageBox(V);
  const b = land ? { ...b0, mh: b0.mh * 0.9 } : { cx: W / 2, mw: W * 0.58, mh: H * (L.mode === 'tall' ? 0.33 : 0.3), floor: H * (L.mode === 'tall' ? 0.5 : 0.42) };
  const bx = drawProduct(ctx, V, 2, t, { entrance: 'spin', t0: 0, box: b, tilt: -0.06, shine: [2.0, 2.8], refl: false, podium: false }) || { x: b.cx - 40, y: b.floor - 80, w: 80, h: 80, cx: b.cx, floor: b.floor };
  const cx = land ? W * 0.74 : W / 2; let y = land ? H * 0.22 : b.floor + H * 0.06;
  if (T.offer) { // pastille étoilée
    const p = ease.back(prog(t, 0.25, 0.5)); const r = (land ? 86 : 100) * p; const px = bx.x + bx.w - 6, py = bx.y + 14;
    ctx.save(); ctx.translate(px, py); ctx.rotate(-0.2 + t * 0.35); ctx.fillStyle = th.accent; ctx.beginPath(); for (let i = 0; i < 24; i++) { const a = (i / 24) * Math.PI * 2, rr = i % 2 ? r * 0.88 : r; ctx.lineTo(Math.cos(a) * rr, Math.sin(a) * rr); } ctx.closePath(); ctx.fill(); ctx.restore();
    ctx.save(); ctx.translate(px, py); ctx.rotate(-0.2 + Math.sin(t * 3) * 0.03); const f = fit(ctx, up(V, T.offer), 'VMan800', r * 1.5, 54, 20, 2); ctx.font = `${f.px}px VMan800`; ctx.fillStyle = th.onAccent; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; f.lines.forEach((l, k) => ctx.fillText(l, 0, (k - (f.lines.length - 1) / 2) * f.px * 1.05)); ctx.restore();
  }
  if (T.oldPrice) {
    const a = ease.out(prog(t, 0.4, 0.4)); ctx.save(); ctx.globalAlpha = a; ctx.font = '44px VMan800'; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillStyle = th.sub; const w = ctx.measureText(T.oldPrice).width;
    ctx.fillText(T.oldPrice, cx, y + 26); ctx.strokeStyle = th.accent; ctx.lineWidth = 6; ctx.beginPath(); ctx.moveTo(cx - w / 2 - 6, y + 40); ctx.lineTo(cx - w / 2 - 6 + (w + 12) * ease.out(prog(t, 0.7, 0.25)), y + 12); ctx.stroke(); ctx.restore(); y += 70;
  }
  if (T.price) {
    const f = fit(ctx, up(V, T.price), S.head, (land ? W * 0.44 : W * 0.86), L.mode === 'sq' ? 120 : 150, 40, 1); const p = prog(t, SLAM.at, SLAM.dur);
    let sc = 1; if (t < SLAM.at) sc = 0.0001; else if (p < 1) sc = 2.8 - 1.8 * ease.out(p); else { const tt = t - SLAM.at - SLAM.dur; sc = 1 + Math.sin(tt * 6) * 0.018 + 0.1 * Math.exp(-tt * 9) * Math.cos(tt * 28); }
    const cy = y + f.px * 0.55;
    if (p >= 1) { const tt = t - SLAM.at - SLAM.dur; if (tt < 0.7) { ctx.save(); const k = ease.out(tt / 0.7); ctx.globalAlpha = (1 - k) * 0.7; ctx.strokeStyle = th.accent; ctx.lineWidth = 6 * (1 - k) + 1; ctx.beginPath(); ctx.arc(cx, cy, 60 + 380 * k, 0, 7); ctx.stroke(); ctx.restore(); } sparkles(ctx, V, cx, cy, t, SLAM.at + SLAM.dur, 20, Math.min(W, 520) * 0.5); }
    ctx.save(); ctx.translate(cx, cy); ctx.scale(sc, sc); ctx.globalAlpha = t < SLAM.at ? 0 : clamp(p * 3); ctx.font = `${f.px}px ${S.head}`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillStyle = th.accent;
    if (V.style === 'promo') { ctx.shadowColor = 'rgba(0,0,0,.4)'; ctx.shadowOffsetY = 8; }
    ctx.fillText(f.lines[0], 0, 0); ctx.restore(); y += f.px * 1.15 + 14;
  }
  if (T.cta2) textBlock(ctx, V, T.cta2, { x: cx - W * 0.4, y, w: W * 0.8, h: 120 }, 'VMan800', 34, 22, 2, th.text, 'center', t, 1.6);
  if (T.cta && !land) { // bouton d'action qui rebondit sous le prix
    const a = ease.back(prog(t, 1.7, 0.5)); if (a > 0) { const f = fit(ctx, up(V, T.cta), 'VMan800', W * 0.7, 40, 22, 1); ctx.font = `${f.px}px VMan800`; const bw = ctx.measureText(f.lines[0]).width + 84, bh = f.px + 40; const by = Math.min(H - bh - 60, y + 40);
      ctx.save(); ctx.translate(cx, by + bh / 2); const pu = a * (1 + Math.sin(t * 6) * 0.025); ctx.scale(pu, pu); ctx.fillStyle = th.accent; rrect(ctx, -bw / 2, -bh / 2, bw, bh, bh / 2); ctx.fill(); ctx.fillStyle = th.onAccent; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText(f.lines[0], 0, 2); ctx.restore(); }
  }
}
function evOffer(V, dur) { const e = [{ t: 0.25, k: 'pop', a: 700 }]; if (V.T.oldPrice) e.push({ t: 0.7, k: 'tick' }); if (V.T.cta) e.push({ t: 1.7, k: 'pop', a: 640, g: 0.7 }); if (V.T.price) { e.push({ t: SLAM.at - 0.5, k: 'riser', a: 0.6, g: 0.9 }); e.push({ t: SLAM.at + SLAM.dur, k: 'impact', g: 0.9 }); e.push({ t: SLAM.at + SLAM.dur + 0.02, k: 'cash' }); } return e; }

function sceneCta(ctx, V, t, dur) {
  const { th, S, L, W, H } = V; const T = V.T; const land = L.mode !== 'tall'; const wide = L.mode === 'land';
  const cx = land ? W * 0.3 : W / 2; let y = wide ? H * 0.2 : land ? H * 0.1 : H * 0.17;
  const r = wide ? 120 : land ? 96 : 150; const sp0 = V.sprites[0]; const p = ease.back(prog(t, 0.05, 0.6));
  // médaillon : produit détouré sur un disque lumineux, ou photo ronde
  ctx.save(); ctx.translate(cx, y + r); ctx.scale(p, p);
  if (sp0) { const gg = ctx.createRadialGradient(0, 0, r * 0.2, 0, 0, r * 1.25); gg.addColorStop(0, withAlpha(th.accent, 0.55)); gg.addColorStop(1, withAlpha(th.accent, 0)); ctx.fillStyle = gg; ctx.beginPath(); ctx.arc(0, 0, r * 1.25, 0, 7); ctx.fill(); const k = Math.min((r * 1.7) / sp0.w, (r * 1.7) / sp0.h); ctx.drawImage(sp0.c, -sp0.w * k / 2, -sp0.h * k / 2 + Math.sin(t * 2) * 4, sp0.w * k, sp0.h * k); }
  else { ctx.beginPath(); ctx.arc(0, 0, r, 0, 7); ctx.save(); ctx.clip(); drawCover(ctx, V.imgs[0], -r, -r, 2 * r, 2 * r, 1.05 + 0.05 * t / 4); ctx.restore(); ctx.lineWidth = 9; ctx.strokeStyle = th.accent; ctx.beginPath(); ctx.arc(0, 0, r + 8, 0, 7); ctx.stroke(); }
  ctx.restore();
  y += 2 * r + (land ? 24 : 46);
  const col = { x: land ? W * 0.04 : W * 0.08, y, w: land ? W * 0.52 : W * 0.84 };
  if (T.brand) y += textBlock(ctx, V, T.brand, { ...col, y }, S.head, 80, 36, 2, th.text, 'center', t, 0.35) + 14;
  if (T.cta) {
    const a = ease.back(prog(t, 0.8, 0.5)); const f = fit(ctx, up(V, T.cta), 'VMan800', col.w - 90, 42, 22, land ? 2 : 1); ctx.font = `${f.px}px VMan800`; const lw = Math.max(...f.lines.map((l) => ctx.measureText(l).width)); const bw = Math.min(col.w, lw + 90), bh = f.lines.length * f.px * 1.1 + 34;
    ctx.save(); ctx.translate(col.x + col.w / 2, y + bh / 2); const pu = a * (1 + Math.sin(t * 6) * 0.025); ctx.scale(pu, pu); ctx.fillStyle = th.accent; rrect(ctx, -bw / 2, -bh / 2, bw, bh, Math.min(bh / 2, 44)); ctx.fill(); ctx.fillStyle = th.onAccent; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; f.lines.forEach((l, k) => ctx.fillText(l, 0, 2 + (k - (f.lines.length - 1) / 2) * f.px * 1.1)); ctx.restore(); y += bh + 26;
  }
  if (T.contact) y += textBlock(ctx, V, T.contact, { ...col, y }, 'VMan800', 44, 20, 1, th.text, 'center', t, 1.1) + 8;
  if (V.qr) {
    const q = V.qr, n = q.getModuleCount(); const size = land ? (wide ? H * 0.5 : H * 0.3) : Math.min(W * 0.4, H - y - 90); const a = ease.out(prog(t, 1.3, 0.5));
    if (size > 90) {
      const qx = land ? (wide ? W * 0.79 : W * 0.78) - size / 2 : W / 2 - size / 2, qy = land ? H / 2 - size / 2 : Math.min(y + 10, H - size - 40); const pad = 18;
      ctx.save(); ctx.globalAlpha = a; ctx.fillStyle = '#fff'; rrect(ctx, qx - pad, qy - pad, size + pad * 2, size + pad * 2, 20); ctx.fill(); ctx.fillStyle = '#000'; const m = size / n;
      for (let rr = 0; rr < n; rr++) for (let cc = 0; cc < n; cc++) if (q.isDark(rr, cc)) ctx.fillRect(qx + cc * m, qy + rr * m, Math.ceil(m), Math.ceil(m));
      ctx.restore();
    }
  }
}
function evCta(V, dur) { const e = [{ t: 0.4, k: 'pop', a: 560 }]; if (V.T.cta) e.push({ t: 0.85, k: 'ding' }); if (V.T.contact) e.push({ t: 1.15, k: 'pop', a: 700, g: 0.6 }); e.push({ t: Math.max(1.6, dur - 1.5), k: 'chime', a: 1175, g: 0.7 }); return e; }

// ───────── transitions ─────────
function transition(ctx, V, p) { // p : 0 → 1 de part et d'autre de la coupure
  const { W, H, th } = V;
  if (V.style === 'mode') {
    const n = 6; const cover = p < 0.45 ? ease.io(p / 0.45) : 1 - ease.io((p - 0.45) / 0.55);
    for (let i = 0; i < n; i++) { const st = (p < 0.45 ? i : n - 1 - i) / (n * 2.2); const c = clamp(cover * 1.25 - st); ctx.fillStyle = i % 2 ? th.accent : th.bg2; const w = W / n + 1; const h = H * c; if (p < 0.45) ctx.fillRect(i * (W / n), 0, w, h); else ctx.fillRect(i * (W / n), H - h, w, h); }
  } else if (V.style === 'beaute') {
    const a = Math.sin(p * Math.PI); ctx.save(); ctx.globalAlpha = a * 0.92; ctx.fillStyle = th.bg1; ctx.fillRect(0, 0, W, H); ctx.globalAlpha = a; ctx.fillStyle = 'rgba(255,255,255,.55)'; ctx.beginPath(); ctx.arc(W / 2, H / 2, Math.max(W, H) * 0.6 * a, 0, 7); ctx.fill(); ctx.restore();
  } else {
    const a = Math.pow(1 - Math.abs(2 * p - 1), 2); ctx.save(); ctx.globalAlpha = a * 0.95; ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, W, H); ctx.restore();
  }
}

const SCENES = { hook: sceneHook, product: sceneProduct, benefits: sceneBenefits, offer: sceneOffer, cta: sceneCta };
const EVENTS = { hook: evHook, product: evProduct, benefits: evBenefits, offer: evOffer, cta: evCta };

// ───────── plan (scènes et durées) ─────────
function plan(P, voiceDur) {
  const T = P.texts; const sc = [];
  sc.push({ k: 'hook', min: 2.8 });
  sc.push({ k: 'product', min: 4.0 });
  if ((T.lines || []).length >= 2) sc.push({ k: 'benefits', min: 1.8 + 0.75 * Math.min(3, (T.lines || []).length) });
  if (T.price || T.offer) sc.push({ k: 'offer', min: 3.8 });
  sc.push({ k: 'cta', min: 4.2 });
  let t0 = 0;
  sc.forEach((s, i) => { const vd = voiceDur && voiceDur[s.k] ? voiceDur[s.k] + 0.7 + (i === sc.length - 1 ? 0.9 : 0) : 0; s.dur = Math.max(s.min, vd); s.start = t0; t0 += s.dur; });
  return { scenes: sc, total: t0 };
}

// ───────── voix off (Google Cloud Text-to-Speech, voix Chirp 3 HD) ─────────
const VOICES = { fr: { f: 'fr-FR-Chirp3-HD-Aoede', m: 'fr-FR-Chirp3-HD-Puck' }, en: { f: 'en-US-Chirp3-HD-Aoede', m: 'en-US-Chirp3-HD-Puck' } };
let ttsAuth = null;
async function ttsToken() {
  const { GoogleAuth } = require('google-auth-library');
  ttsAuth = ttsAuth || new GoogleAuth({ scopes: ['https://www.googleapis.com/auth/cloud-platform'] });
  return (await (await ttsAuth.getClient()).getAccessToken()).token;
}
function trimPcm(pcm) { let a = 0, b = pcm.length - 1; const th = 400; while (a < b && Math.abs(pcm[a]) < th) a++; while (b > a && Math.abs(pcm[b]) < th) b--; return pcm.slice(Math.max(0, a - 1200), Math.min(pcm.length, b + 2400)); }
async function tts(text, lang, gender, maxSec) {
  const token = await ttsToken(); const code = lang === 'en' ? 'en-US' : 'fr-FR'; const name = VOICES[lang === 'en' ? 'en' : 'fr'][gender === 'm' ? 'm' : 'f'];
  const clean = String(text).replace(/[\[\]<>]/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 420);
  let rate = 1.0, out = null;
  for (let i = 0; i < 3; i++) {
    const r = await fetch('https://texttospeech.googleapis.com/v1/text:synthesize', { method: 'POST', headers: { Authorization: 'Bearer ' + token, 'x-goog-user-project': process.env.GCLOUD_PROJECT || 'slashatlas-studio', 'Content-Type': 'application/json' },
      body: JSON.stringify({ input: { text: clean }, voice: { languageCode: code, name }, audioConfig: { audioEncoding: 'LINEAR16', sampleRateHertz: SR, speakingRate: rate } }) });
    const j = await r.json();
    if (!j.audioContent) { const e = new Error('tts ' + r.status + ' ' + JSON.stringify(j).slice(0, 200)); e.code = 'tts'; throw e; }
    const buf = Buffer.from(j.audioContent, 'base64'); const pcm = trimPcm(new Int16Array(buf.buffer.slice(buf.byteOffset + 44, buf.byteOffset + buf.length)));
    out = pcm; const d = pcm.length / SR; if (d <= maxSec) break; rate = Math.min(1.3, rate * (d / maxSec) * 1.03);
  }
  return { pcm: out, chars: clean.length };
}

// ───────── rendu complet ─────────
/**
 * P : { style, ratio, lang, photos:[Buffer], sprites?:[Buffer PNG détouré | null], cutout?:'auto'|'off', texts:{brand,hook,lines[],price,oldPrice,offer,cta,contact}, qrUrl,
 *       music?:'none'|'ambient'|'beat', sfx?:boolean, voice:{ gender:'f'|'m', segments:{hook,product,benefits,offer,cta} } | null }
 * Retourne { file, dir, seconds, ttsChars, scenes, cutouts }. Le fichier est écrit dans le dossier temporaire : à supprimer par l'appelant.
 */
async function render(P, hooks = {}) {
  const V = await prepare(P);
  const voice = P.voice && P.voice.segments ? P.voice : null;
  let ttsChars = 0; const clips = {}; const vd = {};
  if (voice) {
    const kinds = plan(P, null).scenes.map((x) => x.k);
    for (const k of kinds) {
      const text = voice.segments[k]; if (!text || !String(text).trim()) continue;
      const r = await tts(text, V.lang, voice.gender, k === 'hook' ? 5 : 9); clips[k] = r.pcm; vd[k] = r.pcm.length / SR; ttsChars += r.chars;
    }
  }
  const pl = plan(P, voice ? vd : null);
  if (pl.total > MAX_SECONDS) { const e = new Error('too_long'); e.code = 'too_long'; throw e; }
  const total = pl.total; const bounds = pl.scenes.slice(1).map((s) => s.start);
  // sons : effets calés sur les mouvements + transitions, puis musique choisie
  const ev = [];
  pl.scenes.forEach((s) => (EVENTS[s.k](V, s.dur) || []).forEach((e) => ev.push({ ...e, t: s.start + e.t })));
  bounds.forEach((b) => { ev.push({ t: b - 0.3, k: 'whoosh', a: 1, g: 0.75 }); if (V.style === 'promo') ev.push({ t: b + 0.04, k: 'impact', g: 0.55 }); if (V.style === 'beaute') ev.push({ t: b, k: 'chime', a: 784, g: 0.6 }); });
  const fxTrack = V.sfx ? sfxTrack(ev, total + 1) : new Float32Array(Math.ceil((total + 1) * SR));
  const mu = music(V.music, V.style, total + 0.5, bounds);
  const voices = pl.scenes.filter((s) => clips[s.k]).map((s) => ({ at: s.start + 0.3, pcm: clips[s.k] }));
  const wav = mixAudio({ music: mu, sfx: fxTrack, voices, seconds: total, hasVoice: voices.length > 0, musicLevel: V.music === 'ambient' ? 0.8 : 0.6 });
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sav-')); const wavFile = path.join(dir, 'a.wav'); const out = path.join(dir, 'v.mp4'); fs.writeFileSync(wavFile, wav);
  const ff = spawn(FFMPEG, ['-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s', `${V.W}x${V.H}`, '-framerate', String(FPS), '-i', 'pipe:0', '-i', wavFile, '-map', '0:v', '-map', '1:a',
    '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '22', '-pix_fmt', 'yuv420p', '-profile:v', 'high', '-movflags', '+faststart', '-c:a', 'aac', '-b:a', '128k', '-t', total.toFixed(2), out], { stdio: ['pipe', 'ignore', 'pipe'] });
  let err = ''; ff.stderr.on('data', (d) => { err += d; });
  const done = new Promise((res, rej) => { ff.on('close', (c) => (c === 0 ? res() : rej(new Error('ffmpeg ' + err.slice(-300))))); ff.on('error', rej); });
  ff.stdin.on('error', () => {});
  const cv = createCanvas(V.W, V.H); const ctx = cv.getContext('2d'); const N = Math.round(total * FPS);
  for (let f = 0; f < N; f++) {
    const t = f / FPS; let si = pl.scenes.length - 1; for (let i = 0; i < pl.scenes.length; i++) if (t < pl.scenes[i].start + pl.scenes[i].dur) { si = i; break; }
    const sc = pl.scenes[si]; const lt = t - sc.start;
    ctx.globalAlpha = 1; ctx.drawImage(V.bg, 0, 0); decor(ctx, V, t);
    ctx.save();
    const z = sc.k === 'hook' ? 1 : 1 + 0.035 * clamp(lt / sc.dur); // la caméra avance doucement
    let dx = 0, dy = 0; if (sc.k === 'offer' && lt > SLAM.at + SLAM.dur) { const k = Math.exp(-(lt - SLAM.at - SLAM.dur) * 10); dx = Math.sin(lt * 70) * 9 * k; dy = Math.cos(lt * 63) * 7 * k; }
    if (V.style === 'promo' && lt < 0.3) { const k = 1 + 0.06 * (1 - lt / 0.3); ctx.translate(V.W / 2, V.H / 2); ctx.scale(k, k); ctx.translate(-V.W / 2, -V.H / 2); }
    ctx.translate(V.W / 2 + dx, V.H / 2 + dy); ctx.rotate(Math.sin(t * 0.4) * 0.004); ctx.scale(z, z); ctx.translate(-V.W / 2, -V.H / 2);
    SCENES[sc.k](ctx, V, lt, sc.dur); ctx.restore();
    ctx.drawImage(V.vg, 0, 0); ctx.drawImage(V.gr, -((Math.floor(f / 4) * 53) % 160), -((Math.floor(f / 4) * 97) % 160));
    for (const b of bounds) { const p = (t - (b - 0.22)) / 0.5; if (p > 0 && p < 1) transition(ctx, V, p); }
    if (hooks.frame) hooks.frame(f, t, cv);
    const buf = cv.data(); if (!ff.stdin.write(buf)) await new Promise((r) => ff.stdin.once('drain', r));
    if (hooks.progress && f % 24 === 0) hooks.progress(f / N);
  }
  ff.stdin.end(); await done;
  return { file: out, dir, seconds: total, ttsChars, scenes: pl.scenes.map((s) => ({ k: s.k, start: s.start, dur: s.dur })), cutouts: V.sprites.map((s) => !!s) };
}

module.exports = { render, plan, tts, SIZES, STYLES, MAX_SECONDS, FPS, _h: { fonts, clamp, prog, ease, withAlpha, rng, fit, words, rrect, drawCover, SR } };
