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
async function prepare(P) {
  fonts();
  const [W, H] = SIZES[P.ratio] || SIZES['9:16'];
  const style = STYLES[P.style] ? P.style : 'mode';
  const S = STYLES[style];
  const imgs = [];
  for (const b of P.photos) {
    const raw = await loadImage(b);
    const k = Math.min(1, 1280 / Math.max(raw.width, raw.height));
    if (k < 1) { const c = createCanvas(Math.round(raw.width * k), Math.round(raw.height * k)); c.getContext('2d').drawImage(raw, 0, 0, c.width, c.height); imgs.push(c); } else imgs.push(raw);
  }
  const pal = palette(imgs[0], S.fallbackH);
  const th = theme(style, pal);
  // fond : la photo très floue, teintée, + dégradé
  const bg = createCanvas(W, H); const bx = bg.getContext('2d');
  const g = bx.createLinearGradient(0, 0, W * 0.3, H); g.addColorStop(0, th.bg1); g.addColorStop(1, th.bg2); bx.fillStyle = g; bx.fillRect(0, 0, W, H);
  bx.save(); bx.globalAlpha = style === 'promo' ? 0.28 : 0.4; bx.filter = 'blur(38px)'; drawCover(bx, imgs[0], -60, -60, W + 120, H + 120, 1.15); bx.restore();
  bx.fillStyle = th.tint; bx.globalAlpha = 0.55; bx.fillRect(0, 0, W, H); bx.globalAlpha = 1;
  // ombre de carte
  const L = layout(W, H);
  const sh = createCanvas(Math.round(L.card.w + 160), Math.round(L.card.h + 160)); const sx = sh.getContext('2d');
  sx.translate(sh.width / 2, sh.height / 2 - 10); sx.shadowColor = 'rgba(0,0,0,.45)'; sx.shadowBlur = 46; sx.shadowOffsetY = 18; sx.fillStyle = '#000'; cardPath(sx, L.card, style); sx.fill();
  sx.shadowColor = 'transparent'; sx.globalCompositeOperation = 'destination-out'; cardPath(sx, L.card, style); sx.fill();
  return { W, H, L, style, S, th, pal, imgs, bg, sh, T: P.texts, lang: P.lang === 'en' ? 'en' : 'fr', qr: P.qrUrl ? makeQr(P.qrUrl) : null, seed: 7 };
}
function makeQr(url) { try { const q = qrcode(0, 'M'); q.addData(String(url).slice(0, 200)); q.make(); return q; } catch (e) { return null; } }

const up = (V, s) => (V.S.upper ? String(s || '').toUpperCase() : String(s || ''));

// ───────── décor animé ─────────
function decor(ctx, V, t) {
  const { W, H, style, th } = V; const r = rng(V.seed);
  if (style === 'beaute') {
    for (let i = 0; i < 12; i++) {
      const x = r() * W, y0 = r() * H, s = 30 + r() * 90, sp = 14 + r() * 26, a = 0.12 + r() * 0.22;
      const y = ((y0 - t * sp) % (H + 200) + (H + 200)) % (H + 200) - 100;
      ctx.beginPath(); ctx.arc(x + Math.sin(t * 0.6 + i) * 14, y, s, 0, 7); ctx.fillStyle = i % 3 ? `rgba(255,255,255,${a})` : th.accent2.replace(/[\d.]+\)$/, a + ')'); ctx.fill();
    }
  } else if (style === 'promo') {
    ctx.save(); ctx.globalAlpha = 0.1; ctx.fillStyle = '#fff';
    for (let i = -4; i < 14; i++) { const x = ((i * 120 + t * 90) % (W + 600)) - 300; ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x + 50, 0); ctx.lineTo(x + 50 - H * 0.5, H); ctx.lineTo(x - H * 0.5, H); ctx.fill(); }
    ctx.restore();
    for (let i = 0; i < 16; i++) {
      const x = r() * W, y = ((r() * H + t * (40 + r() * 70)) % (H + 40)) - 20, s = 5 + r() * 9, rot = t * (1 + r() * 3) + i;
      ctx.save(); ctx.translate(x, y); ctx.rotate(rot); ctx.fillStyle = i % 2 ? '#ffe14d' : 'rgba(255,255,255,.85)'; ctx.fillRect(-s / 2, -s, s, s * 2); ctx.restore();
    }
  } else {
    ctx.save(); ctx.globalAlpha = 0.07; ctx.fillStyle = th.accent;
    for (let i = 0; i < 9; i++) { const w = 6 + r() * 36, x = ((r() * W + t * (10 + r() * 20) * (i % 2 ? 1 : -1)) % (W + 100) + (W + 100)) % (W + 100) - 50; ctx.fillRect(x, 0, w, H); }
    ctx.restore();
  }
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

function drawCard(ctx, V, img, t, delay, opt = {}) {
  const c = opt.box || V.L.card; const p = ease.back(prog(t, delay, 0.6)); if (p <= 0) return;
  const kb = 1 + 0.09 * clamp(t / 6);
  ctx.save(); ctx.translate(c.x + c.w / 2, c.y + c.h / 2); const rot = (opt.tilt || 0) * p; ctx.rotate(rot); ctx.scale(0.88 + 0.12 * p, 0.88 + 0.12 * p); ctx.globalAlpha = clamp(p * 1.4);
  { const k = c.w / V.L.card.w; ctx.drawImage(V.sh, (-V.sh.width / 2) * k, (-V.sh.height / 2 + 10) * k, V.sh.width * k, V.sh.height * k); }
  if (V.style === 'mode') { ctx.fillStyle = V.th.accent; rrect(ctx, -c.w / 2 + 16, -c.h / 2 + 16, c.w, c.h, 26); ctx.fill(); }
  if (V.style === 'promo') { ctx.fillStyle = '#ffe14d'; rrect(ctx, -c.w / 2 - 10, -c.h / 2 - 10, c.w + 20, c.h + 20, 30); ctx.fill(); }
  cardPath(ctx, c, V.style);
  ctx.clip(); ctx.fillStyle = '#fff'; ctx.fillRect(-c.w / 2, -c.h / 2, c.w, c.h);
  drawCover(ctx, img, -c.w / 2, -c.h / 2, c.w, c.h, (opt.zoom || 1) * kb, opt.px ?? 0.5, opt.py ?? 0.5);
  if (V.style === 'beaute') { ctx.globalCompositeOperation = 'lighter'; const sw = ((t * 0.5) % 2.2) - 0.6; const gg = ctx.createLinearGradient(c.w * (sw - 0.3) - c.w / 2, -c.h / 2, c.w * sw - c.w / 2, c.h / 2); gg.addColorStop(0, 'rgba(255,255,255,0)'); gg.addColorStop(0.5, 'rgba(255,255,255,.22)'); gg.addColorStop(1, 'rgba(255,255,255,0)'); ctx.fillStyle = gg; ctx.fillRect(-c.w / 2, -c.h / 2, c.w, c.h); }
  ctx.restore();
}

function brandTag(ctx, V, t) {
  if (!V.T.brand) return;
  const { W, th, S } = V; const a = ease.out(prog(t, 0.1, 0.5));
  ctx.save(); ctx.globalAlpha = a; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillStyle = th.sub; ctx.font = `26px ${S.body}`;
  const txt = V.T.brand.toUpperCase().split('').join(S.spacing ? ' ' : ''); ctx.fillText(txt.length > 30 ? V.T.brand.toUpperCase() : txt, V.L.mode === 'land' ? V.L.text.x + V.L.text.w / 2 : W / 2, V.L.mode === 'land' ? V.H * 0.08 : V.H * 0.06);
  ctx.restore();
}

function sceneHook(ctx, V, t, dur) {
  const { W, H, th, S } = V; const L = V.L;
  brandTag(ctx, V, t);
  const box = L.mode === 'land' ? { x: W * 0.08, y: H * 0.22, w: W * 0.84, h: H * 0.5 } : { x: W * 0.08, y: H * 0.22, w: W * 0.84, h: H * 0.5 };
  const f = fit(ctx, up(V, V.T.hook), S.head, box.w, L.mode === 'land' ? 120 : 130, 44, 4); const lh = f.px * 1.1; const total = f.lines.length * lh;
  const ws = words(up(V, V.T.hook)); const longest = ws.reduce((b, w, i) => (w.length > ws[b].length ? i : b), 0);
  let wi = 0; ctx.textBaseline = 'top'; ctx.font = `${f.px}px ${S.head}`;
  f.lines.forEach((line, li) => {
    const lw = ctx.measureText(line).width; let x = box.x + (box.w - lw) / 2; const y = box.y + (box.h - total) / 2 + li * lh;
    words(line).forEach((w) => {
      const p = ease.back(prog(t, 0.25 + wi * 0.2, 0.35)); const ww = ctx.measureText(w).width;
      if (p > 0) {
        ctx.save(); ctx.translate(x + ww / 2, y + f.px / 2); ctx.scale(p, p); ctx.globalAlpha = clamp(p * 1.5); ctx.textAlign = 'center'; ctx.fillStyle = wi === longest ? th.accent : th.text;
        if (V.style === 'promo') { ctx.shadowColor = 'rgba(0,0,0,.35)'; ctx.shadowBlur = 0; ctx.shadowOffsetY = 6; }
        ctx.fillText(w, 0, -f.px / 2); ctx.restore();
      }
      x += ww + ctx.measureText(' ').width; wi++;
    });
  });
  const bw = W * 0.28 * ease.out(prog(t, 0.25 + wi * 0.2, 0.4)); ctx.fillStyle = th.accent; ctx.fillRect(W / 2 - bw / 2, box.y + (box.h + total) / 2 + 28, bw, 8);
}

function sceneProduct(ctx, V, t) {
  const { th, S, L } = V;
  drawCard(ctx, V, V.imgs[0], t, 0.05, { tilt: V.style === 'promo' ? -0.05 : 0 });
  const box = L.text; let y = box.y;
  if (V.T.brand) y += textBlock(ctx, V, V.T.brand, { ...box, y }, S.head, 74, 36, 2, th.text, L.mode === 'land' ? 'left' : 'center', t, 0.5) + 10;
  const bar = ease.out(prog(t, 0.65, 0.5)) * 120; ctx.fillStyle = th.accent; ctx.fillRect(L.mode === 'land' ? box.x : box.x + box.w / 2 - bar / 2, y, bar, 6); y += 22;
  const l1 = (V.T.lines && V.T.lines[0]) || V.T.hook;
  textBlock(ctx, V, l1, { ...box, y }, S.body === 'VMan500' && V.style !== 'mode' ? S.body : 'VMan800', 40, 24, 3, th.sub, L.mode === 'land' ? 'left' : 'center', t, 0.9);
}

function check(ctx, x, y, s, color) { ctx.save(); ctx.strokeStyle = color; ctx.lineWidth = s * 0.16; ctx.lineCap = 'round'; ctx.lineJoin = 'round'; ctx.beginPath(); ctx.moveTo(x - s * 0.3, y); ctx.lineTo(x - s * 0.08, y + s * 0.24); ctx.lineTo(x + s * 0.34, y - s * 0.26); ctx.stroke(); ctx.restore(); }
function sceneBenefits(ctx, V, t) {
  const { th, S, L, W, H } = V; const items = (V.T.lines || []).slice(0, 3);
  const small = { x: L.card.x + (L.mode === 'land' ? 0 : L.card.w * 0.13), y: L.card.y + (L.mode === 'land' ? H * 0.04 : 0), w: L.mode === 'land' ? L.card.w : L.card.w * 0.74, h: L.mode === 'land' ? L.card.h * 0.92 : L.card.h * 0.66 };
  drawCard(ctx, V, V.imgs[1 % V.imgs.length], t, 0.0, { box: small, zoom: V.imgs.length > 1 ? 1 : 1.35, px: 0.5, py: 0.35, tilt: V.style === 'promo' ? 0.04 : 0 });
  const bx = L.mode === 'land' ? L.text.x : W * 0.08; let y = L.mode === 'land' ? H * 0.2 : small.y + small.h + H * 0.05; const bw = L.mode === 'land' ? L.text.w : W * 0.84;
  items.forEach((it, i) => {
    const p = ease.out(prog(t, 0.45 + i * 0.6, 0.45)); const rh = L.mode === 'land' ? 100 : 104;
    ctx.save(); ctx.globalAlpha = p; ctx.translate((1 - p) * -60, 0);
    ctx.fillStyle = V.style === 'beaute' ? 'rgba(255,255,255,.85)' : 'rgba(255,255,255,.12)'; rrect(ctx, bx, y, bw, rh - 14, 22); ctx.fill();
    ctx.fillStyle = th.accent; ctx.beginPath(); ctx.arc(bx + 44, y + (rh - 14) / 2, 28, 0, 7); ctx.fill(); check(ctx, bx + 44, y + (rh - 14) / 2, 40, th.onAccent);
    const f = fit(ctx, up(V, it), V.style === 'beaute' ? 'VMan800' : S.body === 'VMan500' ? 'VMan800' : S.body, bw - 110, 38, 22, 2); ctx.font = `${f.px}px ${V.style === 'beaute' ? 'VMan800' : 'VMan800'}`; ctx.fillStyle = V.style === 'beaute' ? th.text : '#fff'; ctx.textAlign = 'left'; ctx.textBaseline = 'middle';
    f.lines.forEach((l, k) => ctx.fillText(l, bx + 92, y + (rh - 14) / 2 + (k - (f.lines.length - 1) / 2) * f.px * 1.1));
    ctx.restore(); y += rh;
  });
}

function sceneOffer(ctx, V, t) {
  const { th, S, L, W, H } = V; const T = V.T;
  const tall = L.mode === 'tall'; const sw = L.mode === 'land' ? 1 : tall ? 0.7 : 0.6; const small = { x: L.card.x + (L.card.w * (1 - sw)) / 2, y: L.card.y + (tall ? H * 0.03 : 0), w: L.card.w * sw, h: L.mode === 'land' ? L.card.h * 0.92 : L.card.h * (tall ? 0.62 : 0.5) };
  drawCard(ctx, V, V.imgs[2 % V.imgs.length], t, 0.0, { box: small, zoom: V.imgs.length > 2 ? 1 : 1.2, py: 0.5, tilt: -0.03 });
  const cx = L.mode === 'land' ? L.text.x + L.text.w / 2 : W / 2; let y = L.mode === 'land' ? H * 0.2 : small.y + small.h + H * 0.075;
  if (T.offer) { // pastille
    const p = ease.back(prog(t, 0.2, 0.5)); const r = (L.mode === 'land' ? 86 : 100) * p; const px = small.x + small.w - 10, py = small.y + 20;
    ctx.save(); ctx.translate(px, py); ctx.rotate(-0.2 + Math.sin(t * 3) * 0.03); ctx.fillStyle = th.accent; ctx.beginPath();
    for (let i = 0; i < 24; i++) { const a = (i / 24) * Math.PI * 2, rr = i % 2 ? r * 0.88 : r; ctx.lineTo(Math.cos(a) * rr, Math.sin(a) * rr); } ctx.closePath(); ctx.fill();
    const f = fit(ctx, up(V, T.offer), 'VMan800', r * 1.5, 54, 20, 2); ctx.font = `${f.px}px VMan800`; ctx.fillStyle = th.onAccent; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    f.lines.forEach((l, k) => ctx.fillText(l, 0, (k - (f.lines.length - 1) / 2) * f.px * 1.05)); ctx.restore();
  }
  if (T.oldPrice) {
    const a = ease.out(prog(t, 0.5, 0.4)); ctx.save(); ctx.globalAlpha = a; ctx.font = `44px VMan800`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillStyle = th.sub; const w = ctx.measureText(T.oldPrice).width;
    ctx.fillText(T.oldPrice, cx, y + 26); ctx.strokeStyle = th.accent; ctx.lineWidth = 6; ctx.beginPath(); ctx.moveTo(cx - w / 2 - 6, y + 28); ctx.lineTo(cx - w / 2 - 6 + (w + 12) * ease.out(prog(t, 0.8, 0.35)), y + 18); ctx.stroke(); ctx.restore(); y += 66;
  }
  if (T.price) {
    const p = ease.back(prog(t, 0.7, 0.55)); const pulse = 1 + Math.sin(t * 5) * 0.015; const f = fit(ctx, up(V, T.price), S.head, (L.mode === 'land' ? L.text.w : W * 0.86), L.mode === 'sq' ? 120 : 150, 40, 1);
    ctx.save(); ctx.translate(cx, y + (f.lines.length * f.px * 1.05) / 2); ctx.scale(p * pulse, p * pulse); ctx.font = `${f.px}px ${S.head}`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillStyle = th.accent;
    if (V.style === 'promo') { ctx.shadowColor = 'rgba(0,0,0,.35)'; ctx.shadowOffsetY = 8; }
    f.lines.forEach((l, k) => ctx.fillText(l, 0, (k - (f.lines.length - 1) / 2) * f.px * 1.05)); ctx.restore(); y += f.lines.length * f.px * 1.1 + 18;
  }
  if (T.cta2) textBlock(ctx, V, T.cta2, { x: cx - (W * 0.4), y, w: W * 0.8, h: 120 }, 'VMan800', 34, 22, 2, th.text, 'center', t, 1.1);
}

function sceneCta(ctx, V, t) {
  const { th, S, L, W, H } = V; const T = V.T; const land = L.mode !== 'tall'; const wide = L.mode === 'land';
  const cx = land ? (wide ? W * 0.3 : W * 0.3) : W / 2; let y = wide ? H * 0.2 : land ? H * 0.1 : H * 0.17;
  // médaillon photo
  const r = wide ? 120 : land ? 96 : 150, p = ease.back(prog(t, 0.05, 0.6));
  ctx.save(); ctx.translate(cx, y + r); ctx.scale(p, p); ctx.beginPath(); ctx.arc(0, 0, r, 0, 7); ctx.clip(); drawCover(ctx, V.imgs[0], -r, -r, 2 * r, 2 * r, 1.05 + 0.05 * t / 4); ctx.restore();
  ctx.save(); ctx.translate(cx, y + r); ctx.scale(p, p); ctx.lineWidth = 9; ctx.strokeStyle = th.accent; ctx.beginPath(); ctx.arc(0, 0, r + 8, 0, 7); ctx.stroke(); ctx.restore();
  y += 2 * r + (land ? 24 : 46);
  const col = { x: land ? W * 0.04 : W * 0.08, y, w: land ? W * 0.52 : W * 0.84 };
  if (T.brand) y += textBlock(ctx, V, T.brand, { ...col, y }, S.head, 80, 36, 2, th.text, 'center', t, 0.35) + 14;
  if (T.cta) { // bouton
    const a = ease.back(prog(t, 0.6, 0.5)); const f = fit(ctx, up(V, T.cta), 'VMan800', col.w - 90, 42, 22, 1); ctx.font = `${f.px}px VMan800`; const bw = Math.min(col.w, ctx.measureText(f.lines[0]).width + 90), bh = f.px + 44;
    ctx.save(); ctx.translate(col.x + col.w / 2, y + bh / 2); const pu = a * (1 + Math.sin(t * 6) * 0.025); ctx.scale(pu, pu); ctx.fillStyle = th.accent; rrect(ctx, -bw / 2, -bh / 2, bw, bh, bh / 2); ctx.fill(); ctx.fillStyle = th.onAccent; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText(f.lines[0], 0, 2); ctx.restore(); y += bh + 26;
  }
  if (T.contact) y += textBlock(ctx, V, T.contact, { ...col, y }, 'VMan800', 44, 24, 2, th.text, 'center', t, 0.9) + 8;
  if (V.qr) {
    const q = V.qr, n = q.getModuleCount(); const size = land ? (wide ? H * 0.5 : H * 0.3) : Math.min(W * 0.4, H - y - 90); const a = ease.out(prog(t, 1.0, 0.5));
    if (size > 90) {
      const qx = land ? (wide ? W * 0.79 : W * 0.78) - size / 2 : W / 2 - size / 2, qy = land ? H / 2 - size / 2 : Math.min(y + 10, H - size - 40); const pad = 18;
      ctx.save(); ctx.globalAlpha = a; ctx.fillStyle = '#fff'; rrect(ctx, qx - pad, qy - pad, size + pad * 2, size + pad * 2, 20); ctx.fill(); ctx.fillStyle = '#000'; const m = size / n;
      for (let rr = 0; rr < n; rr++) for (let cc = 0; cc < n; cc++) if (q.isDark(rr, cc)) ctx.fillRect(qx + cc * m, qy + rr * m, Math.ceil(m), Math.ceil(m));
      ctx.restore();
    }
  }
}

// ───────── transitions ─────────
function transition(ctx, V, p) { // p : 0 → 1 de part et d'autre de la coupure
  const { W, H, th } = V;
  if (V.style === 'mode') {
    const n = 6; const cover = p < 0.45 ? ease.io(p / 0.45) : 1 - ease.io((p - 0.45) / 0.55);
    for (let i = 0; i < n; i++) { const st = (p < 0.45 ? i : n - 1 - i) / (n * 2.2); const c = clamp(cover * 1.25 - st); ctx.fillStyle = i % 2 ? th.accent : (th.bg2); const w = W / n + 1; const h = H * c; if (p < 0.45) ctx.fillRect(i * (W / n), 0, w, h); else ctx.fillRect(i * (W / n), H - h, w, h); }
  } else if (V.style === 'beaute') {
    const a = Math.sin(p * Math.PI); ctx.save(); ctx.globalAlpha = a * 0.92; ctx.fillStyle = th.bg1; ctx.fillRect(0, 0, W, H); ctx.globalAlpha = a; ctx.fillStyle = 'rgba(255,255,255,.55)'; ctx.beginPath(); ctx.arc(W / 2, H / 2, Math.max(W, H) * 0.6 * a, 0, 7); ctx.fill(); ctx.restore();
  } else {
    const a = Math.pow(1 - Math.abs(2 * p - 1), 2); ctx.save(); ctx.globalAlpha = a * 0.95; ctx.fillStyle = '#fff'; ctx.fillRect(0, 0, W, H); ctx.restore();
  }
}

const SCENES = { hook: sceneHook, product: sceneProduct, benefits: sceneBenefits, offer: sceneOffer, cta: sceneCta };

// ───────── plan (scènes et durées) ─────────
function plan(P, voiceDur) {
  const T = P.texts; const sc = [];
  sc.push({ k: 'hook', min: 2.8 });
  sc.push({ k: 'product', min: 3.8 });
  if ((T.lines || []).length > 1 || (T.lines || []).length === 1 && P.voice) sc.push({ k: 'benefits', min: 1.5 + 1.1 * Math.min(3, (T.lines || []).length) });
  if (T.price || T.offer) sc.push({ k: 'offer', min: 3.6 });
  sc.push({ k: 'cta', min: 4 });
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

// ───────── musique synthétisée ─────────
function music(style, seconds, bounds) {
  const n = Math.ceil(seconds * SR); const o = new Float32Array(n); const bpm = { mode: 118, beaute: 84, promo: 128 }[style] || 110; const beat = 60 / bpm; const R = rng(11);
  const add = (t0, arr, g = 1) => { const i0 = Math.floor(t0 * SR); for (let i = 0; i < arr.length && i0 + i < n; i++) o[i0 + i] += arr[i] * g; };
  const env = (len, a, d) => { const e = new Float32Array(len); for (let i = 0; i < len; i++) { const t = i / SR; e[i] = Math.min(1, t / a) * Math.exp(-t / d); } return e; };
  const kick = (() => { const len = Math.floor(0.32 * SR); const e = new Float32Array(len); let ph = 0; for (let i = 0; i < len; i++) { const t = i / SR; const f = 48 + 110 * Math.exp(-t * 28); ph += (2 * Math.PI * f) / SR; e[i] = Math.sin(ph) * Math.exp(-t * 11); } return e; })();
  const noise = (len, dec, hp) => { const e = new Float32Array(len); let last = 0; for (let i = 0; i < len; i++) { const w = R() * 2 - 1; const hpv = w - last * hp; last = w; e[i] = hpv * Math.exp(-(i / SR) / dec); } return e; };
  const hat = noise(Math.floor(0.06 * SR), 0.018, 0.95), ohat = noise(Math.floor(0.2 * SR), 0.07, 0.95), clap = noise(Math.floor(0.22 * SR), 0.05, 0.6), shaker = noise(Math.floor(0.09 * SR), 0.03, 0.9);
  const tone = (f, len, a, d, harm = [1]) => { const e = env(len, a, d); const x = new Float32Array(len); for (let i = 0; i < len; i++) { let v = 0; harm.forEach((h, k) => { v += Math.sin((2 * Math.PI * f * (k + 1) * i) / SR) * h; }); x[i] = v * e[i]; } return x; };
  const hz = (m) => 440 * Math.pow(2, (m - 69) / 12);
  const prog4 = style === 'beaute' ? [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]] : [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]];
  const bars = Math.ceil(seconds / (beat * 4));
  for (let b = 0; b < bars; b++) {
    const ch = prog4[b % 4]; const t0 = b * beat * 4; const root = ch[0] - 24;
    if (style === 'beaute') {
      add(t0, tone(hz(ch[0]), Math.floor(beat * 4 * SR), 0.25, 3.0, [1, 0.3]), 0.1); add(t0, tone(hz(ch[1]), Math.floor(beat * 4 * SR), 0.25, 3.0, [1, 0.3]), 0.08); add(t0, tone(hz(ch[2]), Math.floor(beat * 4 * SR), 0.25, 3.0, [1, 0.3]), 0.08);
      for (let s = 0; s < 8; s++) add(t0 + s * beat * 0.5, tone(hz(ch[s % 3] + 12), Math.floor(0.7 * SR), 0.004, 0.22, [1, 0.35, 0.12]), 0.07);
      add(t0, tone(hz(root), Math.floor(beat * 1.9 * SR), 0.01, 0.6), 0.2); add(t0 + beat * 2, tone(hz(root), Math.floor(beat * 1.9 * SR), 0.01, 0.6), 0.16);
      add(t0, kick, 0.5); add(t0 + beat * 2.5, kick, 0.35); for (let s = 0; s < 8; s++) add(t0 + s * beat * 0.5 + (s % 2 ? beat * 0.06 : 0), shaker, 0.09); add(t0 + beat, clap, 0.1); add(t0 + beat * 3, clap, 0.1);
    } else {
      const four = style === 'promo';
      for (let s = 0; s < 4; s++) { if (four || s % 2 === 0) add(t0 + s * beat, kick, 0.8); }
      if (!four) add(t0 + beat * 2.5, kick, 0.6);
      add(t0 + beat, clap, 0.28); add(t0 + beat * 3, clap, 0.28);
      for (let s = 0; s < 8; s++) add(t0 + s * beat * 0.5, hat, s % 2 ? 0.2 : 0.1); if (four) for (let s = 0; s < 4; s++) add(t0 + s * beat + beat * 0.5, ohat, 0.16);
      for (let s = 0; s < 8; s++) { const note = s % 4 === 3 ? root + 12 : root; add(t0 + s * beat * 0.5, tone(hz(note), Math.floor(0.2 * SR), 0.004, four ? 0.09 : 0.12, [1, 0.4, 0.2]), four ? 0.32 : 0.26); }
      [0.5, 1.5, 2.5, 3.5].forEach((off) => ch.forEach((m) => add(t0 + off * beat, tone(hz(m), Math.floor(0.22 * SR), 0.003, 0.09, [1, 0.5, 0.3]), 0.07)));
      if (four) for (let s = 0; s < 8; s++) add(t0 + s * beat * 0.5, tone(hz(ch[s % 3] + 24), Math.floor(0.14 * SR), 0.002, 0.05, [1, 0.3]), 0.045);
    }
  }
  (bounds || []).forEach((b) => { const len = Math.floor(0.55 * SR); const w = new Float32Array(len); let lp = 0; for (let i = 0; i < len; i++) { const t = i / len; lp += (R() * 2 - 1 - lp) * (0.02 + 0.3 * t); w[i] = lp * Math.sin(Math.PI * t) * 1.6; } add(Math.max(0, b - 0.38), w, 0.5); });
  let pk = 0; for (let i = 0; i < n; i++) pk = Math.max(pk, Math.abs(o[i])); const k = pk ? 0.85 / pk : 1; for (let i = 0; i < n; i++) o[i] *= k;
  return o;
}

function mixAudio(musicArr, voices, total, hasVoice) {
  const n = Math.ceil(total * SR); const out = new Float32Array(n); const duck = new Float32Array(n).fill(1);
  voices.forEach(({ at, pcm }) => { const i0 = Math.floor(at * SR); for (let i = 0; i < pcm.length && i0 + i < n; i++) { out[i0 + i] += pcm[i] / 32768; } for (let i = Math.max(0, i0 - 2400); i < Math.min(n, i0 + pcm.length + 7200); i++) duck[i] = 0.3; });
  let sm = 1; const base = hasVoice ? 0.55 : 0.9;
  for (let i = 0; i < n; i++) { sm += (duck[i] - sm) * (duck[i] < sm ? 0.0025 : 0.00045); const fade = Math.min(1, i / (0.15 * SR), (n - i) / (1.4 * SR)); out[i] = out[i] * 1.0 + (musicArr[i] || 0) * base * sm * Math.max(0, fade); }
  let pk = 0; for (let i = 0; i < n; i++) pk = Math.max(pk, Math.abs(out[i])); const k = pk > 0.95 ? 0.95 / pk : 1; const pcm = Buffer.alloc(n * 2); for (let i = 0; i < n; i++) pcm.writeInt16LE(Math.round(clamp(out[i] * k, -1, 1) * 32767), i * 2);
  const h = Buffer.alloc(44); h.write('RIFF', 0); h.writeUInt32LE(36 + pcm.length, 4); h.write('WAVEfmt ', 8); h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(1, 22); h.writeUInt32LE(SR, 24); h.writeUInt32LE(SR * 2, 28); h.writeUInt16LE(2, 32); h.writeUInt16LE(16, 34); h.write('data', 36); h.writeUInt32LE(pcm.length, 40);
  return Buffer.concat([h, pcm]);
}

// ───────── rendu complet ─────────
/**
 * P : { style, ratio, lang, photos:[Buffer], texts:{brand,hook,lines[],price,oldPrice,offer,cta,contact}, qrUrl,
 *       voice:{ gender:'f'|'m', segments:{hook,product,benefits,offer,cta} } | null }
 * Retourne { file, seconds, ttsChars }. Le fichier est écrit dans le dossier temporaire : à supprimer par l'appelant.
 */
async function render(P, hooks = {}) {
  const V = await prepare(P);
  const voice = P.voice && P.voice.segments ? P.voice : null;
  let ttsChars = 0; const clips = {}; const vd = {};
  if (voice) {
    for (const k of ['hook', 'product', 'benefits', 'offer', 'cta']) {
      const text = voice.segments[k]; if (!text || !String(text).trim()) continue;
      const r = await tts(text, V.lang, voice.gender, k === 'hook' ? 5 : 9); clips[k] = r.pcm; vd[k] = r.pcm.length / SR; ttsChars += r.chars;
    }
  }
  const pl = plan(P, voice ? vd : null);
  if (pl.total > MAX_SECONDS) { const e = new Error('too_long'); e.code = 'too_long'; throw e; }
  const total = pl.total;
  const bounds = pl.scenes.slice(1).map((s) => s.start);
  const mu = music(V.style, total + 0.5, bounds);
  const voices = pl.scenes.filter((s) => clips[s.k]).map((s) => ({ at: s.start + 0.3, pcm: clips[s.k] }));
  const wav = mixAudio(mu, voices, total, voices.length > 0);
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'sav-')); const wavFile = path.join(dir, 'a.wav'); const out = path.join(dir, 'v.mp4'); fs.writeFileSync(wavFile, wav);
  const ff = spawn(FFMPEG, ['-y', '-loglevel', 'error', '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s', `${V.W}x${V.H}`, '-framerate', String(FPS), '-i', 'pipe:0', '-i', wavFile, '-map', '0:v', '-map', '1:a',
    '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '23', '-pix_fmt', 'yuv420p', '-profile:v', 'high', '-movflags', '+faststart', '-c:a', 'aac', '-b:a', '128k', '-t', total.toFixed(2), out], { stdio: ['pipe', 'ignore', 'pipe'] });
  let err = ''; ff.stderr.on('data', (d) => { err += d; });
  const done = new Promise((res, rej) => { ff.on('close', (c) => (c === 0 ? res() : rej(new Error('ffmpeg ' + err.slice(-300))))); ff.on('error', rej); });
  ff.stdin.on('error', () => {});
  const cv = createCanvas(V.W, V.H); const ctx = cv.getContext('2d'); const N = Math.round(total * FPS);
  for (let f = 0; f < N; f++) {
    const t = f / FPS; let si = pl.scenes.length - 1; for (let i = 0; i < pl.scenes.length; i++) if (t < pl.scenes[i].start + pl.scenes[i].dur) { si = i; break; }
    const sc = pl.scenes[si]; const lt = t - sc.start;
    ctx.globalAlpha = 1; ctx.drawImage(V.bg, 0, 0); decor(ctx, V, t);
    ctx.save();
    if (V.style === 'promo' && lt < 0.3) { const k = 1 + 0.06 * (1 - lt / 0.3); ctx.translate(V.W / 2, V.H / 2); ctx.scale(k, k); ctx.translate(-V.W / 2, -V.H / 2); }
    SCENES[sc.k](ctx, V, lt, sc.dur); ctx.restore();
    for (const b of bounds) { const p = (t - (b - 0.22)) / 0.5; if (p > 0 && p < 1) transition(ctx, V, p); }
    if (hooks.frame && hooks.frame(f, t, cv)) { /* aperçu : image demandée */ }
    const buf = cv.data(); if (!ff.stdin.write(buf)) await new Promise((r) => ff.stdin.once('drain', r));
    if (hooks.progress && f % 24 === 0) hooks.progress(f / N);
  }
  ff.stdin.end(); await done;
  return { file: out, dir, seconds: total, ttsChars, scenes: pl.scenes.map((s) => ({ k: s.k, start: s.start, dur: s.dur })) };
}

module.exports = { render, plan, tts, SIZES, STYLES, MAX_SECONDS, FPS };
