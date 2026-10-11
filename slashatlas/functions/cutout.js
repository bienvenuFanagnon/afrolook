'use strict';
// Détourage du produit : retire le fond de la photo pour poser le produit « sur scène » dans la vidéo.
// - localCutout : fonds unis ou dégradés doux (photo de studio) : remplissage depuis les bords, sans IA.
// - chromaKey : produit photographié sur fond vert (image préparée par l'IA) : le vert devient transparent.
// Si le résultat n'est pas fiable, ok = false et la vidéo montre la photo entière dans un cadre (le produit reste identique).
const { createCanvas, loadImage } = require('@napi-rs/canvas');

const smooth = (a, b, x) => { const t = Math.min(1, Math.max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t); };

/** Garde la plus grande zone (et les zones presque aussi grandes : plusieurs produits). mask : Uint8Array 0/1. */
function keepMain(mask, w, h) {
  const lab = new Int32Array(w * h).fill(-1); const sizes = []; const stack = new Int32Array(w * h);
  for (let s = 0; s < w * h; s++) {
    if (!mask[s] || lab[s] >= 0) continue;
    const id = sizes.length; let n = 0, sp = 0; stack[sp++] = s; lab[s] = id;
    while (sp) {
      const p = stack[--sp]; n++; const x = p % w, y = (p / w) | 0;
      if (x > 0 && mask[p - 1] && lab[p - 1] < 0) { lab[p - 1] = id; stack[sp++] = p - 1; }
      if (x < w - 1 && mask[p + 1] && lab[p + 1] < 0) { lab[p + 1] = id; stack[sp++] = p + 1; }
      if (y > 0 && mask[p - w] && lab[p - w] < 0) { lab[p - w] = id; stack[sp++] = p - w; }
      if (y < h - 1 && mask[p + w] && lab[p + w] < 0) { lab[p + w] = id; stack[sp++] = p + w; }
    }
    sizes.push(n);
  }
  if (!sizes.length) return mask;
  const big = Math.max(...sizes); const out = new Uint8Array(w * h);
  for (let i = 0; i < w * h; i++) if (lab[i] >= 0 && sizes[lab[i]] >= big * 0.18) out[i] = 1;
  return out;
}

/** Fabrique le sprite (canvas RGBA recadré, 900 px au plus) à partir de l'image et d'un masque à basse résolution. */
function sprite(img, mask, w, h) {
  let x0 = w, y0 = h, x1 = 0, y1 = 0, count = 0;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) if (mask[y * w + x]) { count++; if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
  if (!count) return null;
  const pad = Math.round(Math.max(w, h) * 0.015);
  x0 = Math.max(0, x0 - pad); y0 = Math.max(0, y0 - pad); x1 = Math.min(w - 1, x1 + pad); y1 = Math.min(h - 1, y1 + pad);
  const bw = x1 - x0 + 1, bh = y1 - y0 + 1; const k = Math.min(1, 900 / Math.max(img.width, img.height) * (w / w)); // facteur par rapport à l'image d'origine
  const sx = img.width / w, sy = img.height / h;
  const scale = Math.min(900 / (bw * sx), 900 / (bh * sy), 1);
  const ow = Math.max(8, Math.round(bw * sx * scale)), oh = Math.max(8, Math.round(bh * sy * scale));
  // masque agrandi et adouci
  const m = createCanvas(w, h); const mx = m.getContext('2d'); const md = mx.createImageData(w, h);
  for (let i = 0; i < w * h; i++) { md.data[i * 4 + 3] = mask[i] ? 255 : 0; md.data[i * 4] = md.data[i * 4 + 1] = md.data[i * 4 + 2] = 255; }
  mx.putImageData(md, 0, 0);
  const out = createCanvas(ow, oh); const ox = out.getContext('2d');
  ox.drawImage(img, x0 * sx, y0 * sy, bw * sx, bh * sy, 0, 0, ow, oh);
  const mk = createCanvas(ow, oh); const kx = mk.getContext('2d'); kx.filter = `blur(${Math.max(0.8, ow / 700).toFixed(2)}px)`; kx.drawImage(m, x0, y0, bw, bh, 0, 0, ow, oh);
  const A = kx.getImageData(0, 0, ow, oh).data; const D = ox.getImageData(0, 0, ow, oh); const P = D.data;
  for (let i = 0; i < ow * oh; i++) P[i * 4 + 3] = Math.round(255 * smooth(0.42, 0.66, A[i * 4 + 3] / 255));
  ox.putImageData(D, 0, 0);
  return { canvas: out, w: ow, h: oh, fraction: count / (w * h), box: [x0 / w, y0 / h, x1 / w, y1 / h] };
}

/** Fond uni ou dégradé doux : remplissage depuis les bords. */
async function localCutout(buf, opt = {}) {
  const img = await loadImage(buf);
  const k = Math.min(1, 480 / Math.max(img.width, img.height)); const w = Math.round(img.width * k), h = Math.round(img.height * k);
  const c = createCanvas(w, h); const x = c.getContext('2d'); x.drawImage(img, 0, 0, w, h);
  const d = x.getImageData(0, 0, w, h).data;
  const px = (i) => [d[i * 4], d[i * 4 + 1], d[i * 4 + 2]];
  const border = []; for (let i = 0; i < w; i++) { border.push(i, w + i, (h - 1) * w + i, (h - 2) * w + i); } for (let j = 0; j < h; j++) { border.push(j * w, j * w + 1, j * w + w - 1, j * w + w - 2); }
  const mean = [0, 0, 0]; border.forEach((i) => { const p = px(i); mean[0] += p[0]; mean[1] += p[1]; mean[2] += p[2]; }); for (let q = 0; q < 3; q++) mean[q] /= border.length;
  let dev = 0; border.forEach((i) => { const p = px(i); dev += Math.hypot(p[0] - mean[0], p[1] - mean[1], p[2] - mean[2]); }); dev /= border.length;
  if (dev > 42) return { ok: false, reason: 'busy', sprite: null }; // fond chargé : pas de détourage fiable
  const T2 = opt.T2 || Math.max(54, dev * 2.2 + 30), T1 = opt.T1 || 13;
  const dist = (i) => { const p = px(i); return Math.hypot(p[0] - mean[0], p[1] - mean[1], p[2] - mean[2]); };
  const dd = (i, j) => { const a = px(i), b = px(j); return Math.hypot(a[0] - b[0], a[1] - b[1], a[2] - b[2]); };
  const bg = new Uint8Array(w * h); const stack = new Int32Array(w * h * 2); let sp = 0;
  border.forEach((i) => { if (!bg[i] && dist(i) < T2) { bg[i] = 1; stack[sp++] = i; } });
  while (sp) {
    const p = stack[--sp]; const xx = p % w, yy = (p / w) | 0;
    const nb = [xx > 0 ? p - 1 : -1, xx < w - 1 ? p + 1 : -1, yy > 0 ? p - w : -1, yy < h - 1 ? p + w : -1];
    for (const q of nb) if (q >= 0 && !bg[q] && dist(q) < T2 && dd(p, q) < T1) { bg[q] = 1; stack[sp++] = q; }
  }
  // trous fermés (anse d'un sac, intérieur d'un cadre) : des zones de la couleur du fond entourées par le produit
  const cand = new Uint8Array(w * h); for (let i = 0; i < w * h; i++) cand[i] = !bg[i] && dist(i) < T2 * 0.5 ? 1 : 0;
  const holes = keepMainAll(cand, w, h, w * h * 0.004); for (let i = 0; i < w * h; i++) if (holes[i]) bg[i] = 1;
  let fg = new Uint8Array(w * h); for (let i = 0; i < w * h; i++) fg[i] = bg[i] ? 0 : 1;
  // érosion d'un pixel : retire le liseré clair du bord
  const er = new Uint8Array(w * h); for (let yy = 1; yy < h - 1; yy++) for (let xx = 1; xx < w - 1; xx++) { const p = yy * w + xx; er[p] = fg[p] && fg[p - 1] && fg[p + 1] && fg[p - w] && fg[p + w] ? 1 : 0; }
  fg = keepMain(er, w, h);
  const s = sprite(img, fg, w, h);
  if (!s) return { ok: false, reason: 'empty', sprite: null };
  const [a, b, cx, cy] = s.box; const touches = (a <= 0.012 ? 1 : 0) + (b <= 0.012 ? 1 : 0) + (cx >= 0.988 ? 1 : 0) + (cy >= 0.988 ? 1 : 0);
  const ok = s.fraction > 0.035 && s.fraction < 0.82 && touches <= 1;
  return { ok, reason: ok ? '' : 'unreliable', sprite: ok ? s : null, fraction: s.fraction };
}
/** Comme keepMain mais retourne toutes les zones d'au moins minArea pixels. */
function keepMainAll(mask, w, h, minArea) {
  const lab = new Int32Array(w * h).fill(-1); const stack = new Int32Array(w * h); const out = new Uint8Array(w * h);
  for (let s = 0; s < w * h; s++) {
    if (!mask[s] || lab[s] >= 0) continue;
    const members = []; let sp = 0; stack[sp++] = s; lab[s] = 1;
    while (sp) { const p = stack[--sp]; members.push(p); const x = p % w, y = (p / w) | 0;
      if (x > 0 && mask[p - 1] && lab[p - 1] < 0) { lab[p - 1] = 1; stack[sp++] = p - 1; } if (x < w - 1 && mask[p + 1] && lab[p + 1] < 0) { lab[p + 1] = 1; stack[sp++] = p + 1; }
      if (y > 0 && mask[p - w] && lab[p - w] < 0) { lab[p - w] = 1; stack[sp++] = p - w; } if (y < h - 1 && mask[p + w] && lab[p + w] < 0) { lab[p + w] = 1; stack[sp++] = p + w; } }
    if (members.length >= minArea) members.forEach((p) => { out[p] = 1; });
  }
  return out;
}

/** Produit sur fond vert uni (« chroma key ») : le vert devient transparent, les reflets verts du bord sont neutralisés. */
async function chromaKey(buf) {
  const img = await loadImage(buf);
  const k = Math.min(1, 1100 / Math.max(img.width, img.height)); const w = Math.round(img.width * k), h = Math.round(img.height * k);
  const c = createCanvas(w, h); const x = c.getContext('2d'); x.drawImage(img, 0, 0, w, h);
  const D = x.getImageData(0, 0, w, h); const P = D.data; const mask = new Uint8Array(w * h);
  for (let i = 0; i < w * h; i++) {
    const r = P[i * 4], g = P[i * 4 + 1], b = P[i * 4 + 2]; const gd = g - Math.max(r, b);
    let a = 1 - smooth(18, 70, gd); if (g < 90 && gd < 30) a = Math.max(a, 1); // vert foncé du produit : conservé
    if (a < 1 && a > 0) { P[i * 4 + 1] = Math.min(g, Math.max(r, b) + 6); } // retire la dominante verte du bord
    P[i * 4 + 3] = Math.round(a * 255); mask[i] = a > 0.5 ? 1 : 0;
  }
  x.putImageData(D, 0, 0);
  const frac = mask.reduce((s, v) => s + v, 0) / (w * h);
  const main = keepMain(mask, w, h); for (let i = 0; i < w * h; i++) if (!main[i]) P[i * 4 + 3] = 0;
  x.putImageData(D, 0, 0);
  // recadrage
  let x0 = w, y0 = h, x1 = 0, y1 = 0; for (let i = 0; i < w * h; i++) if (P[i * 4 + 3] > 40) { const xx = i % w, yy = (i / w) | 0; if (xx < x0) x0 = xx; if (xx > x1) x1 = xx; if (yy < y0) y0 = yy; if (yy > y1) y1 = yy; }
  if (x1 <= x0 || y1 <= y0 || frac < 0.03 || frac > 0.85) return { ok: false, sprite: null, reason: 'unreliable' };
  const pad = 6; x0 = Math.max(0, x0 - pad); y0 = Math.max(0, y0 - pad); x1 = Math.min(w - 1, x1 + pad); y1 = Math.min(h - 1, y1 + pad);
  const bw = x1 - x0 + 1, bh = y1 - y0 + 1; const sc = Math.min(1, 900 / Math.max(bw, bh)); const o = createCanvas(Math.round(bw * sc), Math.round(bh * sc));
  o.getContext('2d').drawImage(c, x0, y0, bw, bh, 0, 0, o.width, o.height);
  return { ok: true, sprite: { canvas: o, w: o.width, h: o.height, fraction: frac, box: [x0 / w, y0 / h, x1 / w, y1 / h] } };
}

module.exports = { localCutout, chromaKey };
