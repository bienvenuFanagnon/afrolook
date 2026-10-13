'use strict';
/**
 * Génère les 4 vidéos démo 2.5D pour SlashAtlas Studio Film
 * Montre : idle (respiration), walk, run, talk, wave, sit, lie, sleep, dance, crouch, point
 * Usage : node gen-demo-2d5.cjs
 */
// Pointer les credentials Google vers le fichier local service-account.json
const SA_PATH = require('path').join(__dirname, 'service-account.json');
if (require('fs').existsSync(SA_PATH)) {
  process.env.GOOGLE_APPLICATION_CREDENTIALS = SA_PATH;
}

const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');
const { createCanvas } = require('@napi-rs/canvas');
const FFMPEG = require('ffmpeg-static');
const { drawChar } = require('./characterEngine');

const W = 1280, H = 720, FPS = 24;
const SR_TTS = 24000;
const OUT_DIR = path.join(__dirname, '..', 'static', 'videos');

// ── Musique ambient via sfx.js ────────────────────────────────────────────────
let sfxMusic, sfxMix, sfxSR;
try {
  const sfx = require('./sfx');
  sfxMusic = sfx.music; sfxMix = sfx.mix; sfxSR = sfx.SR;
} catch (e) {}

// ── Google TTS (voix Chirp 3 HD française) ───────────────────────────────────
let ttsAuth = null;
async function ttsToken() {
  const { GoogleAuth } = require('google-auth-library');
  ttsAuth = ttsAuth || new GoogleAuth({ scopes: ['https://www.googleapis.com/auth/cloud-platform'] });
  return (await (await ttsAuth.getClient()).getAccessToken()).token;
}

async function tts(text, gender) {
  try {
    const token = await ttsToken();
    const name = gender === 'm' ? 'fr-FR-Chirp3-HD-Puck' : 'fr-FR-Chirp3-HD-Aoede';
    const r = await fetch('https://texttospeech.googleapis.com/v1/text:synthesize', {
      method: 'POST',
      signal: AbortSignal.timeout(20000),
      headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        input: { text: text.trim() },
        voice: { languageCode: 'fr-FR', name },
        audioConfig: { audioEncoding: 'LINEAR16', sampleRateHertz: SR_TTS, speakingRate: 0.95 },
      }),
    });
    const j = await r.json();
    if (!j.audioContent) throw new Error('tts_no_audio ' + JSON.stringify(j).slice(0, 120));
    const raw = Buffer.from(j.audioContent, 'base64');
    // LINEAR16 = Int16LE, on retire le header WAV de 44 octets
    const pcm = new Int16Array(raw.buffer, raw.byteOffset + 44, (raw.byteLength - 44) / 2);
    return pcm;
  } catch (e) {
    console.warn('    TTS:', e.message.slice(0, 80));
    return null;
  }
}

function float32ToWav(samples, sr) {
  const len = samples.length;
  const buf = Buffer.allocUnsafe(44 + len * 2);
  buf.write('RIFF', 0); buf.writeUInt32LE(36 + len * 2, 4);
  buf.write('WAVE', 8); buf.write('fmt ', 12);
  buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20); buf.writeUInt16LE(1, 22);
  buf.writeUInt32LE(sr, 24); buf.writeUInt32LE(sr * 2, 28);
  buf.writeUInt16LE(2, 32); buf.writeUInt16LE(16, 34);
  buf.write('data', 36); buf.writeUInt32LE(len * 2, 40);
  for (let i = 0; i < len; i++) {
    const v = Math.max(-1, Math.min(1, samples[i]));
    buf.writeInt16LE(Math.round(v * 32767), 44 + i * 2);
  }
  return buf;
}

function rr(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y); ctx.lineTo(x + w - r, y); ctx.arcTo(x + w, y, x + w, y + r, r);
  ctx.lineTo(x + w, y + h - r); ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
  ctx.lineTo(x + r, y + h); ctx.arcTo(x, y + h, x, y + h - r, r);
  ctx.lineTo(x, y + r); ctx.arcTo(x, y, x + r, y, r);
  ctx.closePath();
}
function lerp(a, b, t) { return a + (b - a) * Math.max(0, Math.min(1, t)); }

function drawSubtitle(ctx, text) {
  if (!text) return;
  ctx.font = 'bold 24px sans-serif';
  const words = text.trim().split(/\s+/);
  const lines = []; let line = '';
  for (const w of words) {
    const t2 = line ? line + ' ' + w : w;
    if (ctx.measureText(t2).width <= W * 0.86 || !line) line = t2;
    else { lines.push(line); line = w; }
  }
  if (line) lines.push(line);
  const lh = 34, pv = 10, bh = lines.length * lh + pv * 2, y0 = H - bh - 32;
  ctx.fillStyle = 'rgba(0,0,0,.62)';
  ctx.beginPath(); ctx.roundRect(W * 0.04, y0 - pv, W * 0.92, bh, 6); ctx.fill();
  ctx.fillStyle = '#fff'; ctx.textAlign = 'center'; ctx.textBaseline = 'top';
  lines.forEach((l2, i) => ctx.fillText(l2, W / 2, y0 + i * lh));
  ctx.textAlign = 'start';
}

// ── Décors ────────────────────────────────────────────────────────────────────

function bgSavane(ctx, tod) {
  const skyTop = tod > 0.5 ? '#1a0a2e' : '#87CEEB';
  const skyBot = tod > 0.5 ? '#4a1a0a' : '#c9e8f5';
  const skyMid = tod > 0.5 ? '#c0502a' : '#f0c060';
  const gSky = ctx.createLinearGradient(0, 0, 0, H * 0.55);
  gSky.addColorStop(0, skyTop); gSky.addColorStop(0.65, skyMid); gSky.addColorStop(1, skyBot);
  ctx.fillStyle = gSky; ctx.fillRect(0, 0, W, H * 0.58);

  if (tod > 0.5) {
    ctx.fillStyle = '#f0e8c0'; ctx.beginPath(); ctx.arc(W * 0.82, H * 0.12, 28, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#1a0a2e'; ctx.beginPath(); ctx.arc(W * 0.84, H * 0.1, 22, 0, Math.PI * 2); ctx.fill();
    for (let s = 0; s < 40; s++) {
      ctx.fillStyle = `rgba(255,255,230,${0.4 + (s % 5) * 0.12})`;
      ctx.beginPath(); ctx.arc((s * 317) % W, (s * 193) % (H * 0.42), 1 + (s % 3) * 0.5, 0, Math.PI * 2); ctx.fill();
    }
  } else {
    const sx = W * 0.75, sy = H * 0.16;
    const gSun = ctx.createRadialGradient(sx, sy, 0, sx, sy, 60);
    gSun.addColorStop(0, '#fff8c0'); gSun.addColorStop(0.4, '#f0b020'); gSun.addColorStop(1, 'transparent');
    ctx.fillStyle = gSun; ctx.beginPath(); ctx.arc(sx, sy, 60, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#f0b020'; ctx.beginPath(); ctx.arc(sx, sy, 32, 0, Math.PI * 2); ctx.fill();
  }

  // Sol avec perspective légère
  const gSol = ctx.createLinearGradient(0, H * 0.56, 0, H);
  gSol.addColorStop(0, tod > 0.5 ? '#4a3018' : '#a0722a');
  gSol.addColorStop(1, tod > 0.5 ? '#2a1808' : '#6b4a18');
  ctx.fillStyle = gSol; ctx.fillRect(0, H * 0.56, W, H * 0.44);

  // Chemin de terre central (perspective)
  ctx.fillStyle = tod > 0.5 ? '#3a2810' : '#8a6838';
  ctx.beginPath();
  ctx.moveTo(W * 0.44, H * 0.58); ctx.lineTo(W * 0.56, H * 0.58);
  ctx.lineTo(W * 0.82, H); ctx.lineTo(W * 0.18, H);
  ctx.closePath(); ctx.fill();

  // Herbes
  ctx.strokeStyle = tod > 0.5 ? '#3a2810' : '#8a6020'; ctx.lineWidth = 2;
  for (let hx = 40; hx < W; hx += 22) {
    const hh = 28 + (hx % 18);
    ctx.beginPath(); ctx.moveTo(hx, H * 0.58); ctx.quadraticCurveTo(hx + 6, H * 0.58 - hh * 0.6, hx + 4, H * 0.58 - hh); ctx.stroke();
  }
  drawBaobab(ctx, W * 0.18, H * 0.56, 0.65);
  drawBaobab(ctx, W * 0.86, H * 0.56, 0.48);
  // Arbre au milieu-fond
  drawBaobab(ctx, W * 0.5, H * 0.57, 0.28);
}

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

function bgVillage(ctx) {
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
  drawFire(ctx, W * 0.5, H * 0.58);
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
  for (let a = 0; a < Math.PI * 2; a += Math.PI / 8) {
    ctx.strokeStyle = 'rgba(90,52,14,.35)'; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(cx, cy - r * 0.3); ctx.lineTo(cx + Math.cos(a) * r * 0.9, cy - r * 0.3 + Math.sin(a) * r * 0.9); ctx.stroke();
  }
}

function drawFire(ctx, fx, fy, t) {
  const flick = t ? Math.sin(t * 8) * 4 : 0;
  const gLueur = ctx.createRadialGradient(fx, fy, 0, fx, fy, 120);
  gLueur.addColorStop(0, 'rgba(255,140,20,.35)'); gLueur.addColorStop(1, 'transparent');
  ctx.fillStyle = gLueur; ctx.beginPath(); ctx.arc(fx, fy, 120, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = '#2a1000';
  for (let b = 0; b < 7; b++) { ctx.beginPath(); ctx.ellipse(fx + (b - 3) * 10, fy - 2, 7, 4, 0, 0, Math.PI * 2); ctx.fill(); }
  [[flick, 40, '#ff8c00'], [-12 + flick * 0.5, 28, '#ff6000'], [12 - flick * 0.5, 28, '#ff6000'], [flick * 0.3, 18, '#ff3000'], [0, 10, '#fff080']].forEach(([ox, h, col]) => {
    ctx.fillStyle = col;
    ctx.beginPath(); ctx.moveTo(fx + ox - 8, fy); ctx.quadraticCurveTo(fx + ox - 14, fy - h * 0.5, fx + ox, fy - h); ctx.quadraticCurveTo(fx + ox + 14, fy - h * 0.5, fx + ox + 8, fy); ctx.closePath(); ctx.fill();
  });
}

function bgCuisine(ctx) {
  ctx.fillStyle = '#c27a40'; ctx.fillRect(0, 0, W, H * 0.62);
  ctx.fillStyle = '#a86030'; ctx.fillRect(0, H * 0.62, W, H * 0.38);
  ctx.strokeStyle = 'rgba(255,255,255,.1)'; ctx.lineWidth = 1;
  for (let my = 60; my < H * 0.62; my += 60) { ctx.beginPath(); ctx.moveTo(0, my); ctx.lineTo(W, my); ctx.stroke(); }
  ctx.fillStyle = '#87CEEB'; ctx.beginPath(); ctx.roundRect(W * 0.72, H * 0.08, 180, 140, 6); ctx.fill();
  ctx.strokeStyle = '#8B5E3C'; ctx.lineWidth = 6; ctx.beginPath(); ctx.roundRect(W * 0.72, H * 0.08, 180, 140, 6); ctx.stroke();
  ctx.strokeStyle = '#8B5E3C'; ctx.lineWidth = 3;
  ctx.beginPath(); ctx.moveTo(W * 0.72 + 90, H * 0.08); ctx.lineTo(W * 0.72 + 90, H * 0.08 + 140); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(W * 0.72, H * 0.08 + 70); ctx.lineTo(W * 0.72 + 180, H * 0.08 + 70); ctx.stroke();
  // Étagère + marmites
  ctx.fillStyle = '#7a4820'; ctx.fillRect(W * 0.06, H * 0.28, 200, 14);
  [[W * 0.09, H * 0.28 - 22], [W * 0.13, H * 0.28 - 18], [W * 0.17, H * 0.28 - 24]].forEach(([mx, my]) => {
    ctx.fillStyle = '#3a2820'; ctx.beginPath(); ctx.ellipse(mx, my, 22, 20, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#606060'; ctx.beginPath(); ctx.ellipse(mx, my - 14, 20, 6, 0, 0, Math.PI * 2); ctx.fill();
  });
  // Grande marmite au sol
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
    for (let fy = 18; fy < bh - 20; fy += 32) {
      for (let fx = 12; fx < bw - 16; fx += 26) { ctx.beginPath(); ctx.roundRect(bx + fx, by - bh + fy, 14, 20, 2); ctx.fill(); }
    }
  });
}

// ── Encodage FFmpeg ───────────────────────────────────────────────────────────
async function renderToMp4(scenes, outFile, musicKind) {
  const totalDur = scenes.reduce((s, sc) => s + sc.dur, 0);

  // Générer les voix TTS pour chaque scène (en parallèle)
  process.stdout.write(' [TTS]');
  const voicePcms = await Promise.all(
    scenes.map((sc) => sc.text ? tts(sc.text, 'f') : Promise.resolve(null))
  );

  // Mixer musique + voix off
  let audioFile = null;
  if (sfxMusic && sfxMix && sfxSR) {
    try {
      const bounds = scenes.slice(1).map((_, i) =>
        scenes.slice(0, i + 1).reduce((s, sc) => s + sc.dur, 0)
      );
      const mu = sfxMusic(musicKind || 'ambient', 'major', totalDur + 0.5, bounds);
      // Voix : décalées de 0.4s dans chaque scène
      let cursor = 0;
      const voices = scenes.map((sc, i) => {
        const at = cursor + 0.4;
        cursor += sc.dur;
        return voicePcms[i] ? { at, pcm: voicePcms[i] } : null;
      }).filter(Boolean);
      const hasVoice = voices.length > 0;
      const wavBuf = sfxMix({
        music: mu, sfx: new Float32Array(Math.ceil((totalDur + 1) * sfxSR)),
        voices, seconds: totalDur, hasVoice, musicLevel: hasVoice ? 0.5 : 0.85,
      });
      audioFile = outFile.replace('.mp4', '-aud.wav');
      fs.writeFileSync(audioFile, wavBuf);
    } catch (e) { audioFile = null; }
  }

  const args = [
    '-y', '-loglevel', 'error',
    '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s', `${W}x${H}`, '-framerate', String(FPS), '-i', 'pipe:0',
    ...(audioFile ? ['-i', audioFile, '-shortest', '-c:a', 'aac', '-b:a', '128k'] : ['-an']),
    '-c:v', 'libx264', '-preset', 'medium', '-crf', '20',
    '-pix_fmt', 'yuv420p', '-g', '48', outFile,
  ];
  const ff = spawn(FFMPEG, args, { stdio: ['pipe', 'ignore', 'pipe'] });
  let ffErr = ''; ff.stderr.on('data', (d) => { ffErr += d; });
  const done = new Promise((res, rej) => {
    ff.on('close', (c) => c === 0 ? res() : rej(new Error('ffmpeg ' + ffErr.slice(-300))));
    ff.on('error', rej);
  });
  ff.stdin.on('error', () => {});

  const cv = createCanvas(W, H);
  const ctx = cv.getContext('2d');
  ctx.imageSmoothingQuality = 'high';

  for (const sc of scenes) {
    const nF = Math.round(sc.dur * FPS);
    for (let f = 0; f < nF; f++) {
      const t = f / FPS;
      const p = f / Math.max(1, nF - 1);
      ctx.clearRect(0, 0, W, H);
      sc.bg(ctx, t, p);

      // Trier les personnages par profondeur (y croissant = plus loin en haut)
      const chars = [...sc.chars].sort((a, b) => {
        const ya = typeof a.y === 'function' ? a.y(p) : a.y;
        const yb = typeof b.y === 'function' ? b.y(p) : b.y;
        return ya - yb;
      });

      for (const ch of chars) {
        const phase = (t * ch.speed + (ch.phaseOff || 0)) % 1;
        const mouthAmt = ch.state === 'talk' ? (0.5 + 0.5 * Math.sin(t * Math.PI * 5)) : 0;
        const x = typeof ch.x === 'function' ? ch.x(p) : ch.x;
        const y = typeof ch.y === 'function' ? ch.y(p) : ch.y;
        drawChar(ctx, x, y, { type: ch.type, dir: ch.dir, state: ch.state, phase, scale: ch.scale || 1, mouthAmt });
      }

      const alpha = Math.min(1, t / 0.3) * Math.min(1, (sc.dur - t) / 0.4);
      if (alpha > 0.05 && sc.text) {
        ctx.globalAlpha = alpha; drawSubtitle(ctx, sc.text); ctx.globalAlpha = 1;
      }

      const buf = cv.data();
      if (!ff.stdin.write(buf)) await new Promise((r) => ff.stdin.once('drain', r));
    }
  }
  ff.stdin.end();
  await done;
  if (audioFile && fs.existsSync(audioFile)) fs.unlinkSync(audioFile);
}

// ── Définition des 4 vidéos ───────────────────────────────────────────────────
const DEMOS = [
  {
    out: 'demo-baobab.mp4',
    name: 'La Légende du Baobab',
    music: 'ambient',
    scenes: [
      {
        // Ancien qui parle debout, 2 enfants ASSIS à ses pieds
        dur: 5,
        bg: (ctx, t) => { bgSavane(ctx, 0.85); },
        text: 'Il y a bien longtemps, dans la savane africaine…',
        chars: [
          { type: 'ancien', dir: 'S', state: 'talk', x: W * 0.5, y: H * 0.76, scale: 1.1, speed: 1.0 },
          // Enfants assis : y = niveau de l'assise (plus haut que le sol des pieds)
          { type: 'enfant-fille',  dir: 'E', state: 'sit', x: W * 0.32, y: H * 0.73, scale: 0.88, phaseOff: 0.2, speed: 0.7 },
          { type: 'enfant-garcon', dir: 'W', state: 'sit', x: W * 0.68, y: H * 0.73, scale: 0.88, phaseOff: 0.5, speed: 0.7 },
        ],
      },
      {
        // Femme qui marche, enfant qui COURT à côté
        dur: 5,
        bg: (ctx) => bgSavane(ctx, 0.2),
        text: 'La vieille Amara connaissait tous ses secrets…',
        chars: [
          { type: 'adulte-femme', dir: 'E', state: 'walk', x: (p) => lerp(W * 0.1, W * 0.65, p), y: H * 0.77, scale: 1.05, speed: 1.4 },
          { type: 'enfant-fille',  dir: 'E', state: 'run',  x: (p) => lerp(W * 0.05, W * 0.6, p), y: H * 0.79, scale: 0.88, phaseOff: 0.5, speed: 2.1 },
        ],
      },
      {
        // Enfant COUCHÉ qui se repose, ancien debout qui veille
        dur: 5,
        bg: (ctx) => bgSavane(ctx, 0.85),
        text: 'Aujourd\'hui, la légende du baobab sacré continue.',
        chars: [
          { type: 'ancien',      dir: 'S', state: 'idle', x: W * 0.55, y: H * 0.76, scale: 1.1, speed: 0.5 },
          { type: 'enfant-garcon', dir: 'E', state: 'sleep', x: W * 0.3, y: H * 0.77, scale: 0.88, phaseOff: 0.2, speed: 0.4 },
        ],
      },
    ],
  },
  {
    out: 'demo-abidjan.mp4',
    name: 'Abidjan 2040',
    music: 'beat',
    scenes: [
      {
        // 2 adultes qui marchent en ville
        dur: 5,
        bg: (ctx) => bgVille(ctx),
        text: 'Dans les rues animées d\'Abidjan, la vie suit son rythme.',
        chars: [
          { type: 'adulte-homme', dir: 'E', state: 'walk', x: (p) => lerp(W * 0.1, W * 0.55, p), y: H * 0.73, scale: 1.1, speed: 1.3 },
          { type: 'adulte-femme', dir: 'W', state: 'walk', x: (p) => lerp(W * 0.9, W * 0.62, p), y: H * 0.73, scale: 1.05, phaseOff: 0.5, speed: 1.3 },
        ],
      },
      {
        // Homme ASSIS sur un banc qui PARLE à une femme DEBOUT qui POINTE
        dur: 5,
        bg: (ctx) => bgVille(ctx),
        text: 'Chaque rencontre est une nouvelle histoire.',
        chars: [
          { type: 'adulte-homme', dir: 'E', state: 'sit',   x: W * 0.42, y: H * 0.71, scale: 1.1, speed: 0.9 },
          { type: 'adulte-femme', dir: 'W', state: 'point', x: W * 0.62, y: H * 0.73, scale: 1.05, phaseOff: 0.3, speed: 0.8 },
        ],
      },
      {
        // Enfant qui court, adultes marchent
        dur: 5,
        bg: (ctx) => bgVille(ctx),
        text: 'La ville pulse au rythme de l\'avenir africain.',
        chars: [
          { type: 'adulte-femme', dir: 'E', state: 'walk', x: (p) => lerp(W * 0.22, W * 0.62, p), y: H * 0.73, scale: 1.1, speed: 1.35 },
          { type: 'adulte-homme', dir: 'E', state: 'walk', x: (p) => lerp(W * 0.3,  W * 0.72, p), y: H * 0.72, scale: 1.05, phaseOff: 0.5, speed: 1.35 },
          { type: 'enfant-garcon', dir: 'E', state: 'run', x: (p) => lerp(W * 0.05, W * 0.55, p), y: H * 0.77, scale: 0.88, phaseOff: 0.2, speed: 2.0 },
        ],
      },
    ],
  },
  {
    out: 'demo-cuisiniere.mp4',
    name: 'La Cuisinière de Lomé',
    music: 'ambient',
    scenes: [
      {
        // Femme debout qui cuisine (idle), enfant ACCROUPI qui souffle sur le feu
        dur: 5,
        bg: (ctx) => bgCuisine(ctx),
        text: 'Dans sa cuisine de Lomé, Akosua prépare le repas.',
        chars: [
          { type: 'adulte-femme', dir: 'S', state: 'idle',   x: W * 0.38, y: H * 0.76, scale: 1.1, speed: 0.8 },
          { type: 'enfant-garcon', dir: 'E', state: 'crouch', x: W * 0.55, y: H * 0.76, scale: 0.85, phaseOff: 0.3, speed: 0.6 },
        ],
      },
      {
        // Femme qui POINTE vers la marmite, enfant ASSIS qui regarde
        dur: 5,
        bg: (ctx) => bgCuisine(ctx),
        text: 'Elle enseigne les gestes de sa grand-mère.',
        chars: [
          { type: 'adulte-femme', dir: 'E', state: 'point', x: W * 0.35, y: H * 0.76, scale: 1.1, speed: 0.9 },
          { type: 'enfant-fille',  dir: 'W', state: 'sit',   x: W * 0.62, y: H * 0.73, scale: 0.88, phaseOff: 0.4, speed: 0.6 },
        ],
      },
      {
        // Enfant qui DANSE de joie, femme qui salue (wave)
        dur: 5,
        bg: (ctx) => bgCuisine(ctx),
        text: 'Ensemble, elles transmettent les saveurs d\'une génération à l\'autre.',
        chars: [
          { type: 'adulte-femme', dir: 'S', state: 'wave',  x: W * 0.38, y: H * 0.76, scale: 1.1, speed: 1.2 },
          { type: 'enfant-fille',  dir: 'S', state: 'dance', x: W * 0.6,  y: H * 0.78, scale: 0.88, phaseOff: 0.5, speed: 1.8 },
        ],
      },
    ],
  },
  {
    out: 'demo-sahel.mp4',
    name: 'Les Enfants du Sahel',
    music: 'beat',
    scenes: [
      {
        // Enfants qui courent et jouent
        dur: 5,
        bg: (ctx) => bgSavane(ctx, 0.2),
        text: 'Dans la savane, les enfants jouent sous le soleil.',
        chars: [
          { type: 'enfant-garcon', dir: 'E', state: 'run', x: (p) => lerp(W * 0.12, W * 0.65, p), y: H * 0.77, scale: 0.92, speed: 2.0 },
          { type: 'enfant-fille',  dir: 'W', state: 'run', x: (p) => lerp(W * 0.88, W * 0.38, p), y: H * 0.78, scale: 0.9,  phaseOff: 0.5, speed: 2.0 },
        ],
      },
      {
        // Enfant COUCHÉ qui se repose, autre enfant ASSIS à côté
        dur: 5,
        bg: (ctx) => bgSavane(ctx, 0.3),
        text: 'Ils grandissent libres, héritiers de la terre de leurs ancêtres.',
        chars: [
          { type: 'enfant-garcon', dir: 'E', state: 'lie',  x: W * 0.38, y: H * 0.77, scale: 0.92, speed: 0.4 },
          { type: 'enfant-fille',  dir: 'S', state: 'sit',  x: W * 0.64, y: H * 0.74, scale: 0.9,  phaseOff: 0.3, speed: 0.6 },
        ],
      },
      {
        // DANSE au coucher du soleil — 3 personnages
        dur: 5,
        bg: (ctx, t) => { bgSavane(ctx, 0.65); drawFire(ctx, W * 0.5, H * 0.585, t); },
        text: 'Au coucher du soleil, les rires et la danse résonnent encore.',
        chars: [
          { type: 'enfant-garcon', dir: 'E', state: 'dance', x: W * 0.32, y: H * 0.77, scale: 0.92, speed: 1.9, phaseOff: 0.0 },
          { type: 'adulte-femme',  dir: 'S', state: 'dance', x: W * 0.5,  y: H * 0.74, scale: 1.05, speed: 1.7, phaseOff: 0.3 },
          { type: 'enfant-fille',  dir: 'W', state: 'dance', x: W * 0.68, y: H * 0.77, scale: 0.9,  speed: 2.0, phaseOff: 0.6 },
        ],
      },
    ],
  },
];

// ── Point d'entrée ────────────────────────────────────────────────────────────
async function main() {
  console.log('\n🎬 Génération des 4 vidéos démo 2.5D — SlashAtlas\n');
  fs.mkdirSync(OUT_DIR, { recursive: true });
  for (const demo of DEMOS) {
    const outFile = path.join(OUT_DIR, demo.out);
    process.stdout.write(`  [${DEMOS.indexOf(demo) + 1}/4] ${demo.name}…`);
    const t0 = Date.now();
    try {
      await renderToMp4(demo.scenes, outFile, demo.music);
      const secs = ((Date.now() - t0) / 1000).toFixed(1);
      const kb = (fs.statSync(outFile).size / 1024).toFixed(0);
      console.log(` ✓ ${kb} KB (${secs}s)`);
    } catch (e) {
      console.error(` ✗ ${e.message}`);
    }
  }
  console.log('\n✅ Terminé — fichiers dans ' + OUT_DIR + '\n');
}
main().catch((e) => { console.error('Erreur:', e.message); process.exit(1); });
