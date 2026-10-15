'use strict';
// Animation 2D : canvas characterEngine + décors africains + TTS + FFmpeg → MP4
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');
const { createCanvas } = require('@napi-rs/canvas');
const FFMPEG = require('ffmpeg-static');
const { getStorage } = require('firebase-admin/storage');
const { FieldValue } = require('firebase-admin/firestore');
const { db, bump, addCredits } = require('./studio');
const { tts, FPS } = require('./video');
const { music, mix: mixAudio } = require('./sfx');
const { drawChar } = require('./characterEngine');

const W = 1280, H = 720;
const SR = 24000;
const ANIM_FPS = 12; // FPS réduit pour le rendu canvas (moins de frames → plus rapide)

// Map position → X pixel
const POS_X = {
  'left': W * 0.14,
  'center-left': W * 0.32,
  'center': W * 0.5,
  'center-right': W * 0.68,
  'right': W * 0.86,
};

// Ground Y par décor
const GROUND_Y = {
  savane: H * 0.79, village: H * 0.77, ville: H * 0.74,
  cuisine: H * 0.74, marche: H * 0.77, foret: H * 0.79, mer: H * 0.78,
};

// ── Helpers ───────────────────────────────────────────────────────────────────

function rr(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y); ctx.lineTo(x + w - r, y); ctx.arcTo(x + w, y, x + w, y + r, r);
  ctx.lineTo(x + w, y + h - r); ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
  ctx.lineTo(x + r, y + h); ctx.arcTo(x, y + h, x, y + h - r, r);
  ctx.lineTo(x, y + r); ctx.arcTo(x, y, x + r, y, r);
  ctx.closePath();
}

// ── Décors ────────────────────────────────────────────────────────────────────

function drawBaobab(ctx, bx, by, sc) {
  const tw = 36 * sc, th = 110 * sc;
  const gT = ctx.createLinearGradient(bx - tw, by - th, bx + tw, by);
  gT.addColorStop(0, '#5a3820'); gT.addColorStop(1, '#3a2010');
  ctx.fillStyle = gT;
  ctx.beginPath();
  ctx.moveTo(bx - tw * 0.6, by); ctx.quadraticCurveTo(bx - tw * 0.8, by - th * 0.5, bx - tw * 0.4, by - th);
  ctx.lineTo(bx + tw * 0.4, by - th); ctx.quadraticCurveTo(bx + tw * 0.8, by - th * 0.5, bx + tw * 0.6, by);
  ctx.closePath(); ctx.fill();
  ctx.strokeStyle = '#3a2010'; ctx.lineWidth = 6 * sc;
  [[-40 * sc, -th, -80 * sc, -th - 55 * sc], [0, -th, 0, -th - 65 * sc],
   [30 * sc, -th, 70 * sc, -th - 50 * sc], [-20 * sc, -th * 0.8, -60 * sc, -th * 0.8 - 40 * sc],
   [20 * sc, -th * 0.85, 55 * sc, -th * 0.85 - 38 * sc]].forEach(([sx, sy, ex, ey]) => {
    ctx.beginPath(); ctx.moveTo(bx + sx, by + sy); ctx.lineTo(bx + ex, by + ey); ctx.stroke();
    ctx.fillStyle = 'rgba(40,70,20,.72)';
    ctx.beginPath(); ctx.arc(bx + ex, by + ey, 20 * sc, 0, Math.PI * 2); ctx.fill();
  });
  ctx.fillStyle = 'rgba(50,85,25,.6)';
  ctx.beginPath(); ctx.arc(bx, by - th - 35 * sc, 42 * sc, 0, Math.PI * 2); ctx.fill();
}

function drawCase(ctx, cx, cy, sc) {
  const r = 48 * sc;
  ctx.fillStyle = '#b07848'; ctx.strokeStyle = '#7a5030'; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.ellipse(cx, cy + r * 0.15, r, r * 0.9, 0, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
  ctx.fillStyle = '#5a3018';
  ctx.beginPath(); rr(ctx, cx - r * 0.18, cy, r * 0.36, r * 0.5, 3); ctx.fill();
  const gToit = ctx.createRadialGradient(cx, cy - r * 0.3, 0, cx, cy - r * 0.3, r * 0.9);
  gToit.addColorStop(0, '#d4a040'); gToit.addColorStop(0.7, '#a07828'); gToit.addColorStop(1, '#7a5818');
  ctx.fillStyle = gToit; ctx.beginPath(); ctx.arc(cx, cy - r * 0.3, r * 0.9, 0, Math.PI * 2); ctx.fill();
}

function drawFire(ctx, fx, fy, t) {
  const flick = t ? Math.sin(t * 8) * 4 : 0;
  const gLueur = ctx.createRadialGradient(fx, fy, 0, fx, fy, 120);
  gLueur.addColorStop(0, 'rgba(255,140,20,.35)'); gLueur.addColorStop(1, 'transparent');
  ctx.fillStyle = gLueur; ctx.beginPath(); ctx.arc(fx, fy, 120, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = '#2a1000';
  for (let b = 0; b < 7; b++) { ctx.beginPath(); ctx.ellipse(fx + (b - 3) * 10, fy - 2, 7, 4, 0, 0, Math.PI * 2); ctx.fill(); }
  [[flick, 40, '#ff8c00'], [-12 + flick * 0.5, 28, '#ff6000'], [12 - flick * 0.5, 28, '#ff6000'], [flick * 0.3, 18, '#ff3000'], [0, 10, '#fff080']].forEach(([ox, ht, col]) => {
    ctx.fillStyle = col;
    ctx.beginPath(); ctx.moveTo(fx + ox - 8, fy); ctx.quadraticCurveTo(fx + ox - 14, fy - ht * 0.5, fx + ox, fy - ht); ctx.quadraticCurveTo(fx + ox + 14, fy - ht * 0.5, fx + ox + 8, fy); ctx.closePath(); ctx.fill();
  });
}

function bgSavane(ctx, t) {
  const gSky = ctx.createLinearGradient(0, 0, 0, H * 0.55);
  gSky.addColorStop(0, '#87CEEB'); gSky.addColorStop(0.65, '#f0c060'); gSky.addColorStop(1, '#c9e8f5');
  ctx.fillStyle = gSky; ctx.fillRect(0, 0, W, H * 0.58);
  const sx = W * 0.75, sy = H * 0.16;
  const gSun = ctx.createRadialGradient(sx, sy, 0, sx, sy, 60);
  gSun.addColorStop(0, '#fff8c0'); gSun.addColorStop(0.4, '#f0b020'); gSun.addColorStop(1, 'transparent');
  ctx.fillStyle = gSun; ctx.beginPath(); ctx.arc(sx, sy, 60, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = '#f0b020'; ctx.beginPath(); ctx.arc(sx, sy, 32, 0, Math.PI * 2); ctx.fill();
  const gSol = ctx.createLinearGradient(0, H * 0.56, 0, H);
  gSol.addColorStop(0, '#a0722a'); gSol.addColorStop(1, '#6b4a18');
  ctx.fillStyle = gSol; ctx.fillRect(0, H * 0.56, W, H * 0.44);
  ctx.fillStyle = '#8a6838';
  ctx.beginPath();
  ctx.moveTo(W * 0.44, H * 0.58); ctx.lineTo(W * 0.56, H * 0.58);
  ctx.lineTo(W * 0.82, H); ctx.lineTo(W * 0.18, H);
  ctx.closePath(); ctx.fill();
  ctx.strokeStyle = '#8a6020'; ctx.lineWidth = 2;
  for (let hx = 40; hx < W; hx += 22) {
    const hh = 28 + (hx % 18);
    ctx.beginPath(); ctx.moveTo(hx, H * 0.58); ctx.quadraticCurveTo(hx + 6, H * 0.58 - hh * 0.6, hx + 4, H * 0.58 - hh); ctx.stroke();
  }
  drawBaobab(ctx, W * 0.18, H * 0.56, 0.65);
  drawBaobab(ctx, W * 0.86, H * 0.56, 0.48);
  drawBaobab(ctx, W * 0.5, H * 0.57, 0.28);
}

function bgVillage(ctx, t) {
  const gSky = ctx.createLinearGradient(0, 0, 0, H * 0.55);
  gSky.addColorStop(0, '#050418'); gSky.addColorStop(1, '#1a0e3a');
  ctx.fillStyle = gSky; ctx.fillRect(0, 0, W, H * 0.58);
  for (let s = 0; s < 60; s++) {
    ctx.fillStyle = `rgba(255,255,220,${0.3 + (s % 7) * 0.1})`;
    ctx.beginPath(); ctx.arc((s * 277) % W, (s * 163) % (H * 0.48), 1 + (s % 3) * 0.4, 0, Math.PI * 2); ctx.fill();
  }
  const gSol = ctx.createLinearGradient(0, H * 0.56, 0, H);
  gSol.addColorStop(0, '#2a1808'); gSol.addColorStop(1, '#0a0802');
  ctx.fillStyle = gSol; ctx.fillRect(0, H * 0.56, W, H * 0.44);
  [[W * 0.12, H * 0.48], [W * 0.78, H * 0.46]].forEach(([cx, cy], i) => drawCase(ctx, cx, cy, i === 0 ? 0.9 : 0.7));
  drawFire(ctx, W * 0.5, H * 0.58, t);
}

function bgCuisine(ctx) {
  ctx.fillStyle = '#c27a40'; ctx.fillRect(0, 0, W, H * 0.62);
  ctx.fillStyle = '#a86030'; ctx.fillRect(0, H * 0.62, W, H * 0.38);
  ctx.strokeStyle = 'rgba(255,255,255,.1)'; ctx.lineWidth = 1;
  for (let my = 60; my < H * 0.62; my += 60) { ctx.beginPath(); ctx.moveTo(0, my); ctx.lineTo(W, my); ctx.stroke(); }
  ctx.fillStyle = '#87CEEB'; ctx.beginPath(); ctx.roundRect(W * 0.72, H * 0.08, 180, 140, 6); ctx.fill();
  ctx.strokeStyle = '#8B5E3C'; ctx.lineWidth = 6; ctx.beginPath(); ctx.roundRect(W * 0.72, H * 0.08, 180, 140, 6); ctx.stroke();
  ctx.fillStyle = '#7a4820'; ctx.fillRect(W * 0.06, H * 0.28, 200, 14);
  [[W * 0.09, H * 0.28 - 22], [W * 0.13, H * 0.28 - 18], [W * 0.17, H * 0.28 - 24]].forEach(([mx, my]) => {
    ctx.fillStyle = '#3a2820'; ctx.beginPath(); ctx.ellipse(mx, my, 22, 20, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#606060'; ctx.beginPath(); ctx.ellipse(mx, my - 14, 20, 6, 0, 0, Math.PI * 2); ctx.fill();
  });
  ctx.fillStyle = '#2a1808'; ctx.beginPath(); ctx.ellipse(W * 0.42, H * 0.62 - 4, 44, 14, 0, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = '#3a2820';
  ctx.beginPath(); ctx.moveTo(W * 0.42 - 44, H * 0.62); ctx.quadraticCurveTo(W * 0.42, H * 0.62 - 60, W * 0.42 + 44, H * 0.62); ctx.closePath(); ctx.fill();
  ctx.fillStyle = '#606060'; ctx.beginPath(); ctx.ellipse(W * 0.42, H * 0.62 - 60, 42, 12, 0, 0, Math.PI * 2); ctx.fill();
}

function bgVille(ctx) {
  const gSky = ctx.createLinearGradient(0, 0, 0, H * 0.52);
  gSky.addColorStop(0, '#1a6bbf'); gSky.addColorStop(1, '#82c8e8');
  ctx.fillStyle = gSky; ctx.fillRect(0, 0, W, H * 0.52);
  [[W * 0.2, H * 0.08], [W * 0.62, H * 0.12], [W * 0.85, H * 0.06]].forEach(([cx, cy]) => {
    ctx.fillStyle = 'rgba(255,255,255,.82)';
    [[0, 0, 32], [-28, 8, 24], [28, 8, 24], [-14, 14, 20], [14, 14, 20]].forEach(([ox, oy, r]) => {
      ctx.beginPath(); ctx.arc(cx + ox, cy + oy, r, 0, Math.PI * 2); ctx.fill();
    });
  });
  const gSol = ctx.createLinearGradient(0, H * 0.52, 0, H);
  gSol.addColorStop(0, '#6a6a6a'); gSol.addColorStop(1, '#4a4a4a');
  ctx.fillStyle = gSol; ctx.fillRect(0, H * 0.52, W, H * 0.48);
  ctx.strokeStyle = 'rgba(255,255,100,.5)'; ctx.lineWidth = 4; ctx.setLineDash([40, 30]);
  ctx.beginPath(); ctx.moveTo(0, H * 0.7); ctx.lineTo(W, H * 0.7); ctx.stroke(); ctx.setLineDash([]);
  ctx.fillStyle = '#c0b090'; ctx.fillRect(0, H * 0.56, W, H * 0.06);
  const bats = [
    [W * 0.04, H * 0.52, 120, 180, '#e07830'], [W * 0.14, H * 0.52, 90, 140, '#2a7a3a'],
    [W * 0.26, H * 0.52, 160, 220, '#c04818'], [W * 0.46, H * 0.52, 100, 160, '#1840a0'],
    [W * 0.6, H * 0.52, 130, 190, '#d0a030'],  [W * 0.76, H * 0.52, 110, 170, '#2a6a90'],
    [W * 0.88, H * 0.52, 150, 200, '#8a2090'],
  ];
  bats.forEach(([bx, by, bw, bh, col]) => {
    ctx.fillStyle = col; ctx.beginPath(); ctx.roundRect(bx, by - bh, bw, bh, 4); ctx.fill();
    ctx.fillStyle = 'rgba(255,255,200,.7)';
    for (let fy2 = 18; fy2 < bh - 20; fy2 += 32) {
      for (let fx2 = 12; fx2 < bw - 16; fx2 += 26) { ctx.beginPath(); ctx.roundRect(bx + fx2, by - bh + fy2, 14, 20, 2); ctx.fill(); }
    }
  });
}

function bgMarche(ctx, t) {
  const gSky = ctx.createLinearGradient(0, 0, 0, H * 0.52);
  gSky.addColorStop(0, '#5ca8e0'); gSky.addColorStop(1, '#aee0f8');
  ctx.fillStyle = gSky; ctx.fillRect(0, 0, W, H * 0.52);
  const gSol = ctx.createLinearGradient(0, H * 0.52, 0, H);
  gSol.addColorStop(0, '#c8a458'); gSol.addColorStop(1, '#a07838');
  ctx.fillStyle = gSol; ctx.fillRect(0, H * 0.52, W, H * 0.48);
  // Étals colorés
  const etals = [
    [W * 0.08, H * 0.48, '#e07020'], [W * 0.3, H * 0.46, '#2a8a30'],
    [W * 0.55, H * 0.47, '#d02020'], [W * 0.78, H * 0.48, '#8020b0'],
  ];
  etals.forEach(([ex, ey, col]) => {
    ctx.fillStyle = col;
    ctx.beginPath(); ctx.moveTo(ex - 55, ey + 30); ctx.lineTo(ex + 55, ey + 30);
    ctx.lineTo(ex + 65, ey - 10); ctx.lineTo(ex - 65, ey - 10); ctx.closePath(); ctx.fill();
    ctx.fillStyle = 'rgba(0,0,0,.2)'; ctx.fillRect(ex - 55, ey + 28, 110, 4);
    ctx.fillStyle = '#8a6020'; ctx.fillRect(ex - 4, ey + 28, 8, 40);
  });
}

function bgForet(ctx, t) {
  const gSky = ctx.createLinearGradient(0, 0, 0, H * 0.45);
  gSky.addColorStop(0, '#184018'); gSky.addColorStop(1, '#2a6028');
  ctx.fillStyle = gSky; ctx.fillRect(0, 0, W, H * 0.45);
  // Troncs d'arbres
  ctx.fillStyle = '#3a2010';
  [W * 0.06, W * 0.22, W * 0.42, W * 0.62, W * 0.78, W * 0.94].forEach((tx) => {
    const tw = 28 + (tx % 14); const th = H * 0.65;
    ctx.fillRect(tx - tw / 2, H * 0.35, tw, th);
    ctx.fillStyle = 'rgba(20,60,10,.7)';
    ctx.beginPath(); ctx.arc(tx, H * 0.35, 70, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#3a2010';
  });
  const gSol = ctx.createLinearGradient(0, H * 0.6, 0, H);
  gSol.addColorStop(0, '#1a3010'); gSol.addColorStop(1, '#0a1808');
  ctx.fillStyle = gSol; ctx.fillRect(0, H * 0.6, W, H * 0.4);
  // Rayons de lumière
  ctx.fillStyle = 'rgba(200,240,150,.06)';
  for (let rx = 0.1; rx < 1; rx += 0.2) {
    ctx.beginPath(); ctx.moveTo(W * rx - 20, 0); ctx.lineTo(W * rx + 20, 0);
    ctx.lineTo(W * rx + 60, H * 0.8); ctx.lineTo(W * rx - 60, H * 0.8); ctx.closePath(); ctx.fill();
  }
}

function bgMer(ctx, t) {
  const gSky = ctx.createLinearGradient(0, 0, 0, H * 0.5);
  gSky.addColorStop(0, '#1a60c0'); gSky.addColorStop(1, '#5ab0f0');
  ctx.fillStyle = gSky; ctx.fillRect(0, 0, W, H * 0.5);
  // Soleil
  const gSun = ctx.createRadialGradient(W * 0.7, H * 0.18, 0, W * 0.7, H * 0.18, 50);
  gSun.addColorStop(0, '#ffffc0'); gSun.addColorStop(0.5, '#f0d020'); gSun.addColorStop(1, 'transparent');
  ctx.fillStyle = gSun; ctx.beginPath(); ctx.arc(W * 0.7, H * 0.18, 50, 0, Math.PI * 2); ctx.fill();
  // Mer avec vagues animées
  const gMer = ctx.createLinearGradient(0, H * 0.5, 0, H);
  gMer.addColorStop(0, '#1878d8'); gMer.addColorStop(1, '#0a3a7a');
  ctx.fillStyle = gMer; ctx.fillRect(0, H * 0.5, W, H * 0.5);
  ctx.strokeStyle = 'rgba(255,255,255,.3)'; ctx.lineWidth = 3;
  for (let wy = H * 0.52; wy < H * 0.72; wy += 22) {
    ctx.beginPath();
    for (let wx = 0; wx < W; wx += 8) {
      const oy = Math.sin((wx / W * 4 + t * 1.2) * Math.PI * 2) * 5;
      wx === 0 ? ctx.moveTo(wx, wy + oy) : ctx.lineTo(wx, wy + oy);
    }
    ctx.stroke();
  }
  // Plage
  const gPlage = ctx.createLinearGradient(0, H * 0.72, 0, H);
  gPlage.addColorStop(0, '#e8d070'); gPlage.addColorStop(1, '#c0a840');
  ctx.fillStyle = gPlage;
  ctx.beginPath(); ctx.moveTo(0, H * 0.76); ctx.quadraticCurveTo(W * 0.5, H * 0.68, W, H * 0.72);
  ctx.lineTo(W, H); ctx.lineTo(0, H); ctx.closePath(); ctx.fill();
  // Palmier
  ctx.strokeStyle = '#5a3820'; ctx.lineWidth = 12;
  ctx.beginPath(); ctx.moveTo(W * 0.15, H * 0.82); ctx.quadraticCurveTo(W * 0.16, H * 0.55, W * 0.22, H * 0.45); ctx.stroke();
  ctx.fillStyle = 'rgba(30,90,20,.8)';
  ctx.beginPath(); ctx.arc(W * 0.22, H * 0.45, 50, 0, Math.PI * 2); ctx.fill();
}

const BG_FNS = { savane: bgSavane, village: bgVillage, ville: bgVille, cuisine: bgCuisine, marche: bgMarche, foret: bgForet, mer: bgMer };

// ── Sous-titres ───────────────────────────────────────────────────────────────

function drawSubtitle(ctx, text, alpha) {
  if (!text || alpha < 0.05) return;
  const maxW = W * 0.88;
  ctx.font = '26px sans-serif';
  const words = String(text).trim().split(/\s+/);
  const lines = []; let line = '';
  for (const word of words) {
    const t = line ? line + ' ' + word : word;
    if (ctx.measureText(t).width <= maxW || !line) line = t;
    else { lines.push(line); line = word; }
  }
  if (line) lines.push(line);
  const lh = 34, pv = 12, bh = lines.length * lh + pv * 2, y0 = H - bh - 36;
  ctx.save();
  ctx.globalAlpha = alpha;
  ctx.fillStyle = 'rgba(0,0,0,0.56)';
  ctx.beginPath(); ctx.roundRect(W * 0.04, y0 - pv, W * 0.92, bh, 6); ctx.fill();
  ctx.fillStyle = '#fff'; ctx.textAlign = 'center'; ctx.textBaseline = 'top';
  lines.forEach((l, i) => ctx.fillText(l, W / 2, y0 + i * lh));
  ctx.textAlign = 'start';
  ctx.restore();
}

function drawWatermark(ctx) {
  ctx.save(); ctx.globalAlpha = 0.55;
  ctx.font = 'bold 14px sans-serif'; ctx.fillStyle = 'rgba(255,255,255,0.85)';
  ctx.textAlign = 'right'; ctx.textBaseline = 'bottom';
  ctx.fillText('slashatlas.com', W - 14, H - 12);
  ctx.restore();
}

// ── Rendu d'une scène animation 2D ───────────────────────────────────────────

async function renderAnimScene(sc, groundY, sceneDur, outFile, opts = {}) {
  const nFrames = Math.round(sceneDur * ANIM_FPS);
  const bgFn = BG_FNS[sc.bg] || bgSavane;

  const args = [
    '-y', '-loglevel', 'error',
    '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s', `${W}x${H}`, '-framerate', String(ANIM_FPS), '-i', 'pipe:0',
    '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '22',
    '-pix_fmt', 'yuv420p', '-g', '48', '-an', outFile,
  ];
  const ff = spawn(FFMPEG, args, { stdio: ['pipe', 'ignore', 'pipe'] });
  let ffErr = ''; ff.stderr.on('data', (d) => { ffErr += d; });
  const done = new Promise((res, rej) => {
    ff.on('close', (c) => (c === 0 ? res() : rej(new Error('ffmpeg_anim ' + ffErr.slice(-200)))));
    ff.on('error', rej);
  });
  ff.stdin.on('error', () => {});

  const cv = createCanvas(W, H);
  const ctx = cv.getContext('2d');
  ctx.imageSmoothingQuality = 'high';

  const chars = sc.chars || [];

  for (let f = 0; f < nFrames; f++) {
    const t = f / ANIM_FPS;
    const p = f / Math.max(1, nFrames - 1);
    ctx.clearRect(0, 0, W, H);
    bgFn(ctx, t, p);

    // Trier les personnages par groundY pour la profondeur
    const sorted = [...chars].sort((a, b) => {
      const ya = typeof a._gy === 'number' ? a._gy : groundY;
      const yb = typeof b._gy === 'number' ? b._gy : groundY;
      return ya - yb;
    });

    for (const ch of sorted) {
      const phase = (t * (ch.speed || 1.0)) % 1;
      const mouthAmt = ch.state === 'talk' ? (0.5 + 0.5 * Math.sin(t * Math.PI * 5)) : 0;

      let posX = POS_X[ch.pos] || W * 0.5;
      if (ch.state === 'walk' || ch.state === 'run') {
        const drift = (ch.dir === 'W' ? -1 : 1) * (p - 0.5) * W * 0.28;
        posX = Math.max(40, Math.min(W - 40, posX + drift));
      }

      drawChar(ctx, posX, groundY, {
        type: ch.type || 'adulte-femme',
        dir: ch.dir || 'S',
        state: ch.state || 'idle',
        phase,
        scale: ch.scale || 1.0,
        mouthAmt,
      });
    }

    const subAlpha = Math.min(1, t / 0.25) * Math.min(1, (sceneDur - t) / 0.4);
    drawSubtitle(ctx, sc.voice, subAlpha);
    if (opts.watermark) drawWatermark(ctx);

    const buf = cv.data();
    if (!ff.stdin.write(buf)) await new Promise((r) => ff.stdin.once('drain', r));
  }

  ff.stdin.end();
  await done;
}

// ── Concaténation / muxage ────────────────────────────────────────────────────

async function concatVideos(files, outFile) {
  const listFile = outFile + '.list.txt';
  fs.writeFileSync(listFile, files.map((f) => `file '${f.replace(/\\/g, '/').replace(/'/g, "\\'")}'`).join('\n'));
  await new Promise((res, rej) => {
    const ff = spawn(FFMPEG, ['-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', listFile, '-c', 'copy', outFile]);
    let err = ''; ff.stderr && ff.stderr.on('data', (d) => { err += d; });
    ff.on('close', (c) => (c === 0 ? res() : rej(new Error('ffmpeg_concat ' + err.slice(-200)))));
    ff.on('error', rej);
  });
  try { fs.unlinkSync(listFile); } catch {}
}

async function muxVideoAudio(videoFile, audioFile, outFile, totalSec) {
  await new Promise((res, rej) => {
    const ff = spawn(FFMPEG, [
      '-y', '-loglevel', 'error',
      '-i', videoFile, '-i', audioFile,
      '-map', '0:v', '-map', '1:a',
      '-c:v', 'copy', '-c:a', 'aac', '-b:a', '128k', '-movflags', '+faststart',
      '-t', totalSec.toFixed(2), outFile,
    ]);
    let err = ''; ff.stderr && ff.stderr.on('data', (d) => { err += d; });
    ff.on('close', (c) => (c === 0 ? res() : rej(new Error('ffmpeg_mux ' + err.slice(-200)))));
    ff.on('error', rej);
  });
}

// ── Pipeline principal ────────────────────────────────────────────────────────

async function renderAnimation(jobId, cfAccountId, cfApiToken) {
  const jobRef = db().collection('FilmJobs').doc(jobId);
  const snap = await jobRef.get();
  if (!snap.exists) throw new Error('job_not_found');
  const { uid, cost, script, lang, duration, watermark, customAudioPath } = snap.data();

  const scenes = script && script.scenes;
  if (!scenes || !scenes.length) throw new Error('no_script_anim');

  const workDir = fs.mkdtempSync(path.join(os.tmpdir(), 'san-'));

  try {
    await jobRef.update({ status: 'rendering', updatedAt: FieldValue.serverTimestamp() });

    // TTS parallèle — toutes les scènes en même temps (max 25s pour éviter l'accélération)
    const ttsResults = await Promise.all(
      scenes.map(async (sc) => {
        try {
          return await tts(sc.voice, lang, 'f', 25);
        } catch (e) {
          console.error('tts anim scene', sc.id, e.message);
          return { pcm: new Int16Array(0), chars: 0 };
        }
      })
    );

    // Durée par scène = durée TTS réelle + 2.5s (respiration) — min 5s, max 25s
    const sceneDurs = ttsResults.map((r) => {
      const ttsSec = r.pcm && r.pcm.length > 0 ? r.pcm.length / SR : 4;
      return Math.min(25, Math.max(5, ttsSec + 2.5));
    });
    const totalSec = sceneDurs.reduce((s, d) => s + d, 0);

    await jobRef.update({ status: 'assembling', updatedAt: FieldValue.serverTimestamp() });

    // Rendu canvas par scène avec durée adaptée
    const sceneFiles = [];
    for (let i = 0; i < scenes.length; i++) {
      const sc = scenes[i];
      const gy = GROUND_Y[sc.bg] || H * 0.77;
      const outFile = path.join(workDir, `s${String(i).padStart(2, '0')}.mp4`);
      await renderAnimScene(sc, gy, sceneDurs[i], outFile, { watermark: !!watermark });
      sceneFiles.push(outFile);
    }

    // Concaténation vidéo
    const noAudioFile = path.join(workDir, 'noaudio.mp4');
    await concatVideos(sceneFiles, noAudioFile);

    // Audio : voix TTS + musique d'ambiance OU audio importé
    let wavFile;
    if (customAudioPath) {
      wavFile = path.join(workDir, 'custom-audio.wav');
      const [customBuf] = await getStorage().bucket().file(customAudioPath).download();
      fs.writeFileSync(wavFile, customBuf);
    } else {
      // Bornes de scène pour la musique et décalages TTS réels
      const bounds = [];
      let cursor = 0;
      for (let i = 0; i < scenes.length - 1; i++) { cursor += sceneDurs[i]; bounds.push(cursor); }

      const voiceClips = ttsResults
        .map(({ pcm }, i) => {
          if (!pcm || !pcm.length) return null;
          const at = (i === 0 ? 0 : bounds[i - 1] || 0) + 0.3;
          return { at, pcm };
        })
        .filter(Boolean);
      const mu = music('ambient', 'mode', totalSec + 0.5, bounds);
      const sfxSilence = new Float32Array(Math.ceil((totalSec + 1) * SR));
      const wavBuf = mixAudio({
        music: mu, sfx: sfxSilence, voices: voiceClips,
        seconds: totalSec, hasVoice: voiceClips.length > 0, musicLevel: 0.65,
      });
      wavFile = path.join(workDir, 'audio.wav');
      fs.writeFileSync(wavFile, wavBuf);
    }

    // Muxage final
    const filmFile = path.join(workDir, 'film.mp4');
    await muxVideoAudio(noAudioFile, wavFile, filmFile, totalSec);

    // Upload Firebase Storage
    const storagePath = `films/${uid}/${jobId}.mp4`;
    const downloadToken = require('crypto').randomUUID();
    const bucket = 'slashatlas-studio.firebasestorage.app';
    await getStorage().bucket().file(storagePath).save(fs.readFileSync(filmFile), {
      contentType: 'video/mp4',
      resumable: false,
      metadata: { metadata: { firebaseStorageDownloadTokens: downloadToken } },
    });
    const videoUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket}/o/${encodeURIComponent(storagePath)}?alt=media&token=${downloadToken}`;

    const ttsTotal = ttsResults.reduce((s, r) => s + (r.chars || 0), 0);
    await jobRef.update({
      status: 'done', storagePath, videoUrl,
      doneAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      ttsChars: ttsTotal,
    });
    await bump({ film_done: 1, film_secs: Math.round(totalSec) });

  } catch (e) {
    console.error('renderAnimation error', jobId, e.message);
    await jobRef.update({ status: 'error', error: e.message, updatedAt: FieldValue.serverTimestamp() });
    if (uid && cost) await addCredits(uid, cost, 'anim_refund_' + jobId).catch(() => {});
    throw e;
  } finally {
    try { fs.rmSync(workDir, { recursive: true, force: true }); } catch {}
  }
}

module.exports = { renderAnimation };
