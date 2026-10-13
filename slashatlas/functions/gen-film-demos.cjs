'use strict';
// Génère 4 vidéos de démonstration pour le Studio Film & Série.
// Chaque vidéo : 4 scènes × 6s = 24s — graphismes canvas + musique d'ambiance.
// node gen-film-demos.cjs

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');
const { createCanvas } = require('@napi-rs/canvas');
const FFMPEG = require('ffmpeg-static');
const { music, mix: mixAudio } = require('./sfx');

const FPS = 24;
const SR = 24000;
const W = 1280, H = 720;
const SCENE_DUR = 6; // secondes par scène
const OUT_DIR = path.join(__dirname, '..', 'static', 'videos');

// Palettes africaines pour chaque film
const PALETTES = {
  baobab: [
    ['#8B1A1A', '#D4520A', '#F4A243'], // coucher de soleil
    ['#1A4A1A', '#2D7A2D', '#8BC34A'], // forêt verte
    ['#2A1A0A', '#7B4A1A', '#D4A043'], // terre ocre
    ['#0A1A2A', '#1A3A5A', '#4A7AAA'], // nuit étoilée
  ],
  abidjan: [
    ['#0A0A2A', '#1A1A5A', '#4A4ACA'], // nuit bleue futuriste
    ['#0A2A2A', '#0A5A5A', '#0AAAAA'], // cyan tech
    ['#1A0A2A', '#4A0A7A', '#AA4ACA'], // violet néon
    ['#2A1A0A', '#6A4A0A', '#CAA40A'], // or doré
  ],
  cuisiniere: [
    ['#3A0A0A', '#8A2A0A', '#D46A20'], // piment rouge
    ['#1A2A0A', '#3A5A0A', '#7A9A20'], // herbes vertes
    ['#3A2A0A', '#7A5A1A', '#C49A3A'], // épices
    ['#0A1A3A', '#1A3A6A', '#3A6AAA'], // bleu indigo
  ],
  sahel: [
    ['#3A2A0A', '#8A6A2A', '#C4A050'], // sable doré
    ['#1A3A1A', '#3A6A3A', '#6A9A6A'], // savane verte
    ['#3A1A0A', '#8A3A1A', '#C46A3A'], // terre rouge
    ['#0A2A3A', '#1A4A5A', '#3A7A8A'], // eau bleue
  ],
};

// Textes sous-titres pour chaque film
const DEMOS = [
  {
    id: 'baobab',
    title: 'La Légende du Baobab',
    genre: 'Conte africain',
    scenes: [
      { sub: 'Il était une fois, au cœur de l\'Afrique...', accent: '#F4A243' },
      { sub: 'Un jeune enfant rêvait de toucher les étoiles.', accent: '#8BC34A' },
      { sub: '"Sois patient comme le baobab millénaire."', accent: '#D4A043' },
      { sub: 'Il devint le gardien de la forêt sacrée.', accent: '#4A7AAA' },
    ],
  },
  {
    id: 'abidjan',
    title: 'Abidjan 2040',
    genre: 'Fiction africaine',
    scenes: [
      { sub: 'En 2040, Abidjan est la Silicon Valley de l\'Afrique.', accent: '#4A4ACA' },
      { sub: 'Aminata pilote une startup d\'intelligence artificielle.', accent: '#0AAAAA' },
      { sub: 'Son IA prédit les récoltes avec 95% de précision.', accent: '#AA4ACA' },
      { sub: 'Le futur de l\'Afrique s\'écrit ici, maintenant.', accent: '#CAA40A' },
    ],
  },
  {
    id: 'cuisiniere',
    title: 'La Cuisinière de Lomé',
    genre: 'Film culinaire',
    scenes: [
      { sub: 'Dans le marché animé de Lomé, les saveurs s\'éveillent.', accent: '#D46A20' },
      { sub: 'Mama Afi prépare son attiéké aux crevettes depuis 40 ans.', accent: '#7A9A20' },
      { sub: 'Chaque plat raconte l\'histoire d\'un peuple.', accent: '#C49A3A' },
      { sub: 'La cuisine africaine, patrimoine d\'une génération.', accent: '#3A7A8A' },
    ],
  },
  {
    id: 'sahel',
    title: 'Les Enfants du Sahel',
    genre: 'Documentaire',
    scenes: [
      { sub: 'Dans le Sahel, la terre rouge garde des secrets.', accent: '#C4A050' },
      { sub: 'Des enfants plantent des arbres chaque matin.', accent: '#6A9A6A' },
      { sub: 'En 10 ans, ils ont reverdi 500 hectares de désert.', accent: '#C46A3A' },
      { sub: 'L\'espoir renaît, une pousse à la fois.', accent: '#3A7A8A' },
    ],
  },
];

// Dessine un fond avec dégradé et motifs géométriques africains
function drawBackground(ctx, colors, sceneIdx, p) {
  const [c1, c2, c3] = colors;
  // Dégradé de fond
  const grad = ctx.createLinearGradient(0, 0, W, H);
  grad.addColorStop(0, c1);
  grad.addColorStop(0.5, c2);
  grad.addColorStop(1, c3);
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, W, H);

  // Motifs géométriques subtils (cercles concentriques + losanges)
  ctx.globalAlpha = 0.06 + 0.02 * Math.sin(p * Math.PI);
  const cx = W * 0.7, cy = H * 0.35;
  for (let r = 40; r < 300; r += 55) {
    ctx.beginPath();
    ctx.arc(cx, cy, r + p * 30, 0, Math.PI * 2);
    ctx.strokeStyle = c3;
    ctx.lineWidth = 1.5;
    ctx.stroke();
  }
  // Triangles décoratifs
  ctx.globalAlpha = 0.08;
  ctx.fillStyle = c3;
  for (let i = 0; i < 5; i++) {
    const tx = (W * 0.05) + i * (W * 0.22) + p * 10;
    const ty = H * 0.75 + Math.sin(i + p * 2) * 20;
    ctx.beginPath();
    ctx.moveTo(tx, ty - 40);
    ctx.lineTo(tx - 25, ty + 20);
    ctx.lineTo(tx + 25, ty + 20);
    ctx.closePath();
    ctx.fill();
  }
  ctx.globalAlpha = 1;
}

// Dessine le titre du film en haut
function drawTitle(ctx, title, genre, alpha) {
  ctx.globalAlpha = Math.min(1, alpha);
  // Genre (petit texte en haut)
  ctx.font = '500 18px sans-serif';
  ctx.fillStyle = 'rgba(255,255,255,0.6)';
  ctx.textAlign = 'center';
  ctx.fillText(genre.toUpperCase(), W / 2, 42);
  // Titre
  ctx.font = 'bold 44px sans-serif';
  ctx.fillStyle = '#fff';
  ctx.shadowColor = 'rgba(0,0,0,0.6)';
  ctx.shadowBlur = 12;
  ctx.fillText(title, W / 2, 92);
  ctx.shadowBlur = 0;
  ctx.textAlign = 'start';
  ctx.globalAlpha = 1;
}

// Dessine le sous-titre en bas
function drawSubtitle(ctx, text, accent, alpha) {
  if (!text || alpha < 0.05) return;
  ctx.globalAlpha = alpha;
  const maxW = W * 0.82;
  ctx.font = '26px sans-serif';
  const wordList = String(text).trim().split(/\s+/);
  const lines = [];
  let line = '';
  for (const word of wordList) {
    const t = line ? line + ' ' + word : word;
    if (ctx.measureText(t).width <= maxW || !line) { line = t; } else { lines.push(line); line = word; }
  }
  if (line) lines.push(line);
  const lh = 36;
  const padV = 14;
  const boxH = lines.length * lh + padV * 2;
  const y0 = H - boxH - 32;
  ctx.fillStyle = 'rgba(0,0,0,0.55)';
  ctx.beginPath();
  ctx.roundRect(W * 0.06, y0 - padV, W * 0.88, boxH, 7);
  ctx.fill();
  // Barre colorée à gauche
  ctx.fillStyle = accent;
  ctx.fillRect(W * 0.06, y0 - padV, 4, boxH);
  ctx.fillStyle = '#fff';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'top';
  lines.forEach((l, i) => ctx.fillText(l, W / 2, y0 + i * lh));
  ctx.textAlign = 'start';
  ctx.textBaseline = 'alphabetic';
  ctx.globalAlpha = 1;
}

// Encode une scène en H.264 sans audio
async function encodeScene(frames, outFile) {
  const args = [
    '-y', '-loglevel', 'error',
    '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s', `${W}x${H}`, '-framerate', String(FPS), '-i', 'pipe:0',
    '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '22', '-pix_fmt', 'yuv420p', '-g', '48', '-an',
    outFile,
  ];
  const ff = spawn(FFMPEG, args, { stdio: ['pipe', 'ignore', 'pipe'] });
  let err = ''; ff.stderr.on('data', (d) => { err += d; });
  const done = new Promise((res, rej) => {
    ff.on('close', (c) => (c === 0 ? res() : rej(new Error('ffmpeg ' + err.slice(-200)))));
    ff.on('error', rej);
  });
  ff.stdin.on('error', () => {});
  for (const buf of frames) {
    if (!ff.stdin.write(buf)) await new Promise((r) => ff.stdin.once('drain', r));
  }
  ff.stdin.end();
  await done;
}

async function concatAndMux(sceneFiles, wavFile, outFile, totalSec) {
  const listFile = outFile + '.list.txt';
  fs.writeFileSync(listFile, sceneFiles.map((f) => `file '${f.replace(/\\/g, '/').replace(/'/g, "\\'")}'`).join('\n'));
  const tmpVideo = outFile + '.noaudio.mp4';
  // Concat
  await new Promise((res, rej) => {
    const ff = spawn(FFMPEG, ['-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', listFile, '-c', 'copy', tmpVideo]);
    let err = ''; ff.stderr && ff.stderr.on('data', (d) => { err += d; });
    ff.on('close', (c) => (c === 0 ? res() : rej(new Error('concat ' + err.slice(-200)))));
    ff.on('error', rej);
  });
  // Mux avec audio
  await new Promise((res, rej) => {
    const ff = spawn(FFMPEG, [
      '-y', '-loglevel', 'error', '-i', tmpVideo, '-i', wavFile,
      '-map', '0:v', '-map', '1:a', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '128k',
      '-movflags', '+faststart', '-t', totalSec.toFixed(2), outFile,
    ]);
    let err = ''; ff.stderr && ff.stderr.on('data', (d) => { err += d; });
    ff.on('close', (c) => (c === 0 ? res() : rej(new Error('mux ' + err.slice(-200)))));
    ff.on('error', rej);
  });
  try { fs.unlinkSync(listFile); fs.unlinkSync(tmpVideo); } catch {}
}

async function generateDemo(demo) {
  const totalSec = demo.scenes.length * SCENE_DUR;
  const pal = PALETTES[demo.id];
  const workDir = fs.mkdtempSync(path.join(os.tmpdir(), 'fdemo-'));
  console.log(`  Génération : ${demo.title}`);
  try {
    const sceneFiles = [];
    for (let si = 0; si < demo.scenes.length; si++) {
      const sc = demo.scenes[si];
      const colors = pal[si % pal.length];
      const nFrames = Math.round(SCENE_DUR * FPS);
      const cv = createCanvas(W, H);
      const ctx = cv.getContext('2d');
      ctx.imageSmoothingQuality = 'high';
      const frames = [];

      for (let f = 0; f < nFrames; f++) {
        const p = f / Math.max(1, nFrames - 1);
        const t = f / FPS;

        // Ken Burns : zoom + panoramique
        ctx.setTransform(1, 0, 0, 1, 0, 0);
        ctx.clearRect(0, 0, W, H);
        const scale = 1.0 + 0.08 * p;
        const ox = (W * (scale - 1)) / 2;
        const oy = (H * (scale - 1)) / 2;
        ctx.setTransform(scale, 0, 0, scale, -ox + p * 15, -oy);
        drawBackground(ctx, colors, si, p);
        ctx.setTransform(1, 0, 0, 1, 0, 0);

        // Titre : fade in lors de la première scène
        const titleAlpha = si === 0 ? Math.min(1, t / 0.5) : Math.min(1, t / 0.3) * Math.min(1, (SCENE_DUR - t) / 0.5);
        drawTitle(ctx, demo.title, demo.genre, si === 0 ? titleAlpha : 0.7);

        // Sous-titre : fade in/out
        const subAlpha = Math.min(1, t / 0.3) * Math.min(1, (SCENE_DUR - t) / 0.5);
        drawSubtitle(ctx, sc.sub, sc.accent, subAlpha);

        // Transition en noir : last 12 frames
        const fadeOut = Math.max(0, (f - (nFrames - 12)) / 12);
        if (fadeOut > 0) {
          ctx.fillStyle = `rgba(0,0,0,${fadeOut})`;
          ctx.fillRect(0, 0, W, H);
        }
        frames.push(cv.data());
      }

      const scFile = path.join(workDir, `s${si}.mp4`);
      await encodeScene(frames, scFile);
      sceneFiles.push(scFile);
    }

    // Audio : musique d'ambiance uniquement
    const bounds = demo.scenes.slice(1).map((_, i) => (i + 1) * SCENE_DUR);
    const mu = music('ambient', 'mode', totalSec + 0.5, bounds);
    const sfxSilence = new Float32Array(Math.ceil((totalSec + 1) * SR));
    const wavBuf = mixAudio({ music: mu, sfx: sfxSilence, voices: [], seconds: totalSec, hasVoice: false, musicLevel: 0.75 });
    const wavFile = path.join(workDir, 'audio.wav');
    fs.writeFileSync(wavFile, wavBuf);

    const outFile = path.join(OUT_DIR, `demo-${demo.id}.mp4`);
    await concatAndMux(sceneFiles, wavFile, outFile, totalSec);
    console.log(`  ✓ ${path.basename(outFile)} (${totalSec}s)`);
  } finally {
    try { fs.rmSync(workDir, { recursive: true, force: true }); } catch {}
  }
}

async function main() {
  console.log('Génération des vidéos de démonstration Studio Film...');
  for (const demo of DEMOS) {
    await generateDemo(demo);
  }
  console.log('Terminé.');
}

main().catch((e) => { console.error(e); process.exit(1); });
