'use strict';
// Détourage du produit par un modèle de segmentation (IS-Net « general use », licence Apache 2.0, exécuté avec onnxruntime, MIT).
// Gratuit, rapide (3 à 6 s), et les pixels du produit restent ceux de la photo : rien n'est regénéré ni déformé.
// Le modèle (178 Mo) est téléchargé une fois par instance depuis le stockage du projet (models/isnet-general-use.onnx), puis gardé dans /tmp.
const fs = require('fs');
const os = require('os');
const path = require('path');
const { createCanvas, loadImage } = require('@napi-rs/canvas');

const MODEL_NAME = 'isnet-general-use.onnx';
const SIZE = 1024;
let sessionPromise = null;

async function modelFile() {
  if (process.env.MATTING_MODEL_PATH && fs.existsSync(process.env.MATTING_MODEL_PATH)) return process.env.MATTING_MODEL_PATH;
  const local = path.join(os.tmpdir(), MODEL_NAME);
  if (fs.existsSync(local) && fs.statSync(local).size > 100e6) return local;
  const { getStorage } = require('firebase-admin/storage');
  const tmp = local + '.part';
  await getStorage().bucket().file('models/' + MODEL_NAME).download({ destination: tmp });
  fs.renameSync(tmp, local);
  return local;
}
function session() {
  if (!sessionPromise) {
    sessionPromise = (async () => {
      const ort = require('onnxruntime-node');
      return ort.InferenceSession.create(await modelFile(), { executionProviders: ['cpu'], graphOptimizationLevel: 'all' });
    })().catch((e) => { sessionPromise = null; throw e; });
  }
  return sessionPromise;
}

/** Composantes connexes de l'alpha : garde la plus grande et les zones proches et de taille comparable (plusieurs produits côte à côte). */
function keepProducts(alpha, w, h) {
  const lab = new Int32Array(w * h).fill(-1); const comps = []; const stack = new Int32Array(w * h);
  for (let s = 0; s < w * h; s++) {
    if (alpha[s] < 128 || lab[s] >= 0) continue;
    const id = comps.length; let n = 0, sp = 0, x0 = w, y0 = h, x1 = 0, y1 = 0; stack[sp++] = s; lab[s] = id;
    while (sp) {
      const p = stack[--sp]; n++; const x = p % w, y = (p / w) | 0; if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y;
      if (x > 0 && alpha[p - 1] >= 128 && lab[p - 1] < 0) { lab[p - 1] = id; stack[sp++] = p - 1; }
      if (x < w - 1 && alpha[p + 1] >= 128 && lab[p + 1] < 0) { lab[p + 1] = id; stack[sp++] = p + 1; }
      if (y > 0 && alpha[p - w] >= 128 && lab[p - w] < 0) { lab[p - w] = id; stack[sp++] = p - w; }
      if (y < h - 1 && alpha[p + w] >= 128 && lab[p + w] < 0) { lab[p + w] = id; stack[sp++] = p + w; }
    }
    comps.push({ n, x0, y0, x1, y1 });
  }
  if (!comps.length) return { keep: new Uint8Array(0), count: 0 };
  // composante principale : grande et plutôt centrée
  let main = 0, best = -1;
  comps.forEach((c, i) => { const cx = (c.x0 + c.x1) / 2 / w, cy = (c.y0 + c.y1) / 2 / h; const score = c.n * (1 - 0.6 * Math.hypot(cx - 0.5, cy - 0.5)); if (score > best) { best = score; main = i; } });
  const m = comps[main]; const keepId = new Set([main]);
  comps.forEach((c, i) => {
    // plusieurs produits identiques côte à côte (rouges à lèvres, bouteilles) : même taille, même hauteur, proches. Un objet de décor (robinet, plante) est plus petit : écarté.
    if (i === main || c.n < m.n * 0.5) return;
    const hr = (c.y1 - c.y0) / Math.max(1, m.y1 - m.y0), wr = (c.x1 - c.x0) / Math.max(1, m.x1 - m.x0);
    const gx = Math.max(0, Math.max(c.x0 - m.x1, m.x0 - c.x1)), gy = Math.max(0, Math.max(c.y0 - m.y1, m.y0 - c.y1));
    if (hr >= 0.75 && hr <= 1.33 && wr >= 0.5 && wr <= 2 && Math.max(gx, gy) <= Math.max(m.x1 - m.x0, m.y1 - m.y0) * 1.2) keepId.add(i);
  });
  const keep = new Uint8Array(w * h); for (let i = 0; i < w * h; i++) if (lab[i] >= 0 && keepId.has(lab[i])) keep[i] = 1;
  return { keep, count: keepId.size };
}

const smooth = (a, b, x) => { const t = Math.min(1, Math.max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t); };

/** Photo (Buffer) → { ok, sprite: { canvas, w, h } } : le produit sur fond transparent, recadré (900 px au plus). */
async function matte(buf) {
  const ort = require('onnxruntime-node');
  const sess = await session();
  const img = await loadImage(buf);
  const k = Math.min(1, 1600 / Math.max(img.width, img.height)); const W = Math.round(img.width * k), H = Math.round(img.height * k);
  const photo = createCanvas(W, H); const px = photo.getContext('2d'); px.drawImage(img, 0, 0, W, H);
  // entrée du modèle : 1024 × 1024, valeurs normalisées
  const inp = createCanvas(SIZE, SIZE); const ix = inp.getContext('2d'); ix.drawImage(photo, 0, 0, SIZE, SIZE);
  const d = ix.getImageData(0, 0, SIZE, SIZE).data; const data = new Float32Array(3 * SIZE * SIZE); const N = SIZE * SIZE;
  const mean = [0.485, 0.456, 0.406];
  for (let i = 0; i < N; i++) { data[i] = d[i * 4] / 255 - mean[0]; data[N + i] = d[i * 4 + 1] / 255 - mean[1]; data[2 * N + i] = d[i * 4 + 2] / 255 - mean[2]; }
  const out = await sess.run({ [sess.inputNames[0]]: new ort.Tensor('float32', data, [1, 3, SIZE, SIZE]) });
  const pred = out[sess.outputNames[0]].data; let mn = Infinity, mx = -Infinity; for (let i = 0; i < N; i++) { const v = pred[i]; if (v < mn) mn = v; if (v > mx) mx = v; }
  const rng = mx - mn || 1;
  const mk = createCanvas(SIZE, SIZE); const mx2 = mk.getContext('2d'); const md = mx2.createImageData(SIZE, SIZE);
  for (let i = 0; i < N; i++) { const a = Math.round(255 * ((pred[i] - mn) / rng)); md.data[i * 4] = md.data[i * 4 + 1] = md.data[i * 4 + 2] = 255; md.data[i * 4 + 3] = a; }
  mx2.putImageData(md, 0, 0);
  // masque ramené à la taille de la photo
  const big = createCanvas(W, H); const bx = big.getContext('2d'); bx.imageSmoothingQuality = 'high'; bx.drawImage(mk, 0, 0, W, H);
  const alpha = new Uint8Array(W * H); const bd = bx.getImageData(0, 0, W, H).data; for (let i = 0; i < W * H; i++) alpha[i] = bd[i * 4 + 3];
  const { keep, count } = keepProducts(alpha, W, H);
  if (!count) return { ok: false, sprite: null, reason: 'empty' };
  const pd = px.getImageData(0, 0, W, H); const P = pd.data; let x0 = W, y0 = H, x1 = 0, y1 = 0, area = 0;
  for (let i = 0; i < W * H; i++) {
    // alpha net mais doux sur le bord : retire le halo du fond, sans manger le produit
    const a = keep[i] ? smooth(0.18, 0.82, alpha[i] / 255) : 0; P[i * 4 + 3] = Math.round(a * 255);
    if (a > 0.5) { area++; const x = i % W, y = (i / W) | 0; if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
  }
  const fraction = area / (W * H);
  if (fraction < 0.01 || fraction > 0.92) return { ok: false, sprite: null, reason: 'unreliable', fraction };
  px.putImageData(pd, 0, 0);
  const pad = Math.round(Math.max(W, H) * 0.012); x0 = Math.max(0, x0 - pad); y0 = Math.max(0, y0 - pad); x1 = Math.min(W - 1, x1 + pad); y1 = Math.min(H - 1, y1 + pad);
  const bw = x1 - x0 + 1, bh = y1 - y0 + 1; const sc = Math.min(1, 1400 / Math.max(bw, bh)); const o = createCanvas(Math.max(8, Math.round(bw * sc)), Math.max(8, Math.round(bh * sc)));
  o.getContext('2d').drawImage(photo, x0, y0, bw, bh, 0, 0, o.width, o.height);
  return { ok: true, sprite: { canvas: o, w: o.width, h: o.height, fraction }, products: count };
}

module.exports = { matte };
