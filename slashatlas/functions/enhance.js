'use strict';
// Retouche automatique d'une photo avant la création de la vidéo : lumière, couleurs, netteté et taille.
// Les photos envoyées par les clients sont souvent sombres, ternes, floues ou petites : on les améliore sans rien inventer
// (les pixels du produit restent les siens, aucune IA générative). Fonctionne sur un canvas, avec ou sans transparence.
const { createCanvas } = require('@napi-rs/canvas');

const clamp255 = (v) => (v < 0 ? 0 : v > 255 ? 255 : v);

/** Flou rapide (trois passes de moyenne glissante) sur les canaux RGB, rayon en pixels. */
function blurRGB(src, w, h, r) {
  const out = new Uint8ClampedArray(src.length); const tmp = new Float32Array(w * h * 3);
  const win = 2 * r + 1;
  // horizontal
  for (let y = 0; y < h; y++) {
    for (let c = 0; c < 3; c++) {
      let sum = 0; const row = y * w;
      for (let x = -r; x <= r; x++) sum += src[(row + Math.min(w - 1, Math.max(0, x))) * 4 + c];
      for (let x = 0; x < w; x++) {
        tmp[(row + x) * 3 + c] = sum / win;
        sum += src[(row + Math.min(w - 1, x + r + 1)) * 4 + c] - src[(row + Math.max(0, x - r)) * 4 + c];
      }
    }
  }
  // vertical
  for (let x = 0; x < w; x++) {
    for (let c = 0; c < 3; c++) {
      let sum = 0;
      for (let y = -r; y <= r; y++) sum += tmp[(Math.min(h - 1, Math.max(0, y)) * w + x) * 3 + c];
      for (let y = 0; y < h; y++) {
        out[(y * w + x) * 4 + c] = sum / win;
        sum += tmp[(Math.min(h - 1, y + r + 1) * w + x) * 3 + c] - tmp[(Math.max(0, y - r) * w + x) * 3 + c];
      }
    }
  }
  return out;
}

/**
 * canvas → nouveau canvas retouché.
 * opts.minSide : agrandit (lissage haute qualité) si le plus grand côté est plus petit ; opts.maxSide : réduit si plus grand.
 * opts.strength : 0..1 (1 par défaut).
 */
function enhance(cv, opts = {}) {
  const strength = opts.strength == null ? 1 : opts.strength;
  const long = Math.max(cv.width, cv.height);
  let k = 1; if (opts.minSide && long < opts.minSide) k = opts.minSide / long; if (opts.maxSide && long * k > opts.maxSide) k = opts.maxSide / long;
  const W = Math.max(8, Math.round(cv.width * k)), H = Math.max(8, Math.round(cv.height * k));
  const out = createCanvas(W, H); const x = out.getContext('2d'); x.imageSmoothingEnabled = true; x.imageSmoothingQuality = 'high';
  if (k > 1.02) { // agrandissement en deux temps : plus doux qu'un seul grand saut
    const mid = Math.min(k, 1.5); const m = createCanvas(Math.round(cv.width * mid), Math.round(cv.height * mid)); const mx = m.getContext('2d'); mx.imageSmoothingQuality = 'high'; mx.drawImage(cv, 0, 0, m.width, m.height);
    x.drawImage(m, 0, 0, W, H);
  } else x.drawImage(cv, 0, 0, W, H);
  const img = x.getImageData(0, 0, W, H); const d = img.data; const N = W * H;

  // 1. histogramme de la luminance (pixels visibles seulement)
  const hist = new Uint32Array(256); let cnt = 0, sr = 0, sg = 0, sb = 0;
  for (let i = 0; i < N; i++) {
    if (d[i * 4 + 3] < 200) continue; const r = d[i * 4], g = d[i * 4 + 1], b = d[i * 4 + 2];
    hist[(0.299 * r + 0.587 * g + 0.114 * b) | 0]++; cnt++; sr += r; sg += g; sb += b;
  }
  if (cnt < 200) return out;
  const pct = (p) => { let a = 0; const t = cnt * p; for (let v = 0; v < 256; v++) { a += hist[v]; if (a >= t) return v; } return 255; };
  const lo = pct(0.01), hi = Math.max(lo + 40, pct(0.99));
  // étirement des niveaux, limité pour ne pas abîmer une photo déjà bonne
  const span = Math.min(255, Math.max(180, hi - lo)); const stretchLo = lo * 0.85 * strength; const scale = 1 + ((255 / Math.max(60, hi - stretchLo)) - 1) * strength;
  let mean = 0; for (let v = 0; v < 256; v++) mean += v * hist[v]; mean /= cnt;
  // gamma : éclaircit les photos sombres (moyenne cible ≈ 118), assombrit un peu les photos brûlées
  const afterMean = clamp255((mean - stretchLo) * scale);
  const gamma = Math.min(1.45, Math.max(0.8, Math.log(118 / 255) / Math.log(Math.max(20, afterMean) / 255)));
  const g1 = 1 + (gamma - 1) * strength;
  // équilibre des blancs (moyenne grise), limité à ±10 %
  const avg = (sr + sg + sb) / (3 * cnt); const wb = [avg / (sr / cnt || 1), avg / (sg / cnt || 1), avg / (sb / cnt || 1)].map((v) => 1 + (Math.min(1.1, Math.max(0.9, v)) - 1) * 0.5 * strength);
  const lut = new Uint8Array(256); for (let v = 0; v < 256; v++) lut[v] = Math.round(clamp255(255 * Math.pow(clamp255((v - stretchLo) * scale) / 255, 1 / g1)));
  void span;
  const sat = 1 + 0.16 * strength;
  for (let i = 0; i < N; i++) {
    const o = i * 4; let r = lut[clamp255(d[o] * wb[0]) | 0], g = lut[clamp255(d[o + 1] * wb[1]) | 0], b = lut[clamp255(d[o + 2] * wb[2]) | 0];
    // vibrance : les couleurs ternes gagnent plus que les couleurs déjà vives
    const l = 0.299 * r + 0.587 * g + 0.114 * b; const mx = Math.max(r, g, b), mn = Math.min(r, g, b); const s = mx ? (mx - mn) / mx : 0; const boost = sat + 0.12 * strength * (1 - s);
    d[o] = clamp255(l + (r - l) * boost); d[o + 1] = clamp255(l + (g - l) * boost); d[o + 2] = clamp255(l + (b - l) * boost);
  }
  // 2. netteté : masque flou fin (détails) + masque large (relief, « clarté »)
  const fine = blurRGB(d, W, H, Math.max(1, Math.round(Math.max(W, H) / 700)));
  const wide = blurRGB(d, W, H, Math.max(6, Math.round(Math.max(W, H) / 90)));
  const a1 = 0.85 * strength, a2 = 0.28 * strength;
  for (let i = 0; i < N; i++) {
    const o = i * 4;
    for (let c = 0; c < 3; c++) { const v = d[o + c]; d[o + c] = clamp255(v + (v - fine[o + c]) * a1 + (v - wide[o + c]) * a2); }
  }
  x.putImageData(img, 0, 0);
  return out;
}

module.exports = { enhance };
