'use strict';
// Montage promotionnel SlashAtlas — face caméra + motion design
// Structure :
//   0-9s  : vidéo caméra (intro utilisateur)
//   9-16s : motion design — homepage
//  16-24s : motion design — commandes catalog
//  24-33s : motion design — avant/après affiche pub
//  33-42s : motion design — Studio Film
//  42-52s : vidéo caméra (outro + CTA)

const { createCanvas, loadImage } = require('@napi-rs/canvas');
const { spawn, spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const W = 360, H = 640, FPS = 30;
const FFMPEG = 'ffmpeg';
const TMP = 'C:/Users/ANVT/AppData/Local/Temp/claude/D--bienvenu-Projets-otherProjets-afrolook-V2-afrolookofficiel-v2/881e5bd7-c4de-403d-8ba6-7a38f111a58b/scratchpad';
const USER_VIDEO = 'D:/Personnel/Downloads/slashVideo.mp4';
const OUT_VIDEO = path.join(__dirname, '../static/videos/promo-slashatlas.mp4');

const SHOTS = {
  homepage:    path.join(TMP, 'shot_homepage.jpg'),
  beforeAfter: path.join(TMP, 'shot_before_after.jpg'),
  commands:    path.join(TMP, 'shot_commands.jpg'),
  commands2:   path.join(TMP, 'shot_commands2.jpg'),
  studioFilm:  path.join(TMP, 'shot_studio_film.jpg'),
};

// ── Helpers ───────────────────────────────────────────────────────────────
function frameBuffer(canvas) {
  // @napi-rs/canvas : pixels RGBA via getImageData
  return Buffer.from(canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height).data);
}

function roundRect(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y);
  ctx.quadraticCurveTo(x + w, y, x + w, y + r);
  ctx.lineTo(x + w, y + h - r);
  ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  ctx.lineTo(x + r, y + h);
  ctx.quadraticCurveTo(x, y + h, x, y + h - r);
  ctx.lineTo(x, y + r);
  ctx.quadraticCurveTo(x, y, x + r, y);
  ctx.closePath();
}

// ── Dessin d'une image en cover (zoom+pan Ken Burns) ───────────────────────
function drawCover(ctx, img, progress = 0, panDir = 'in') {
  const scaleX = W / img.width;
  const scaleY = H / img.height;
  const baseScale = Math.max(scaleX, scaleY);
  const zoom = panDir === 'in'
    ? baseScale * (1 + progress * 0.08)
    : baseScale * (1.08 - progress * 0.08);
  const dw = img.width * zoom;
  const dh = img.height * zoom;
  const dx = (W - dw) / 2;
  const dy = (H - dh) / 2 - progress * 20 * (panDir === 'down' ? 1 : 0);
  ctx.drawImage(img, dx, dy, dw, dh);
}

// ── Overlay sombre en bas pour le texte ───────────────────────────────────
function drawBottomOverlay(ctx, h = 160) {
  const grad = ctx.createLinearGradient(0, H - h, 0, H);
  grad.addColorStop(0, 'rgba(0,0,0,0)');
  grad.addColorStop(1, 'rgba(0,0,0,0.88)');
  ctx.fillStyle = grad;
  ctx.fillRect(0, H - h, W, h);
}

// ── Texte avec fond arrondi (badge) ───────────────────────────────────────
function drawBadge(ctx, text, x, y, color = '#1E9BFF') {
  ctx.font = 'bold 13px sans-serif';
  const m = ctx.measureText(text);
  const pw = 12, ph = 7, r = 8;
  const bw = m.width + pw * 2, bh = 26;
  ctx.fillStyle = color;
  roundRect(ctx, x - pw, y - ph - 13, bw, bh, r);
  ctx.fill();
  ctx.fillStyle = '#fff';
  ctx.fillText(text, x, y);
}

// ── Texte centré ──────────────────────────────────────────────────────────
function drawCentered(ctx, text, y, size = 22, weight = 'bold', color = '#fff') {
  ctx.font = `${weight} ${size}px sans-serif`;
  ctx.fillStyle = color;
  const m = ctx.measureText(text);
  ctx.fillText(text, (W - m.width) / 2, y);
}

// ── Titre slash style (/ NomPage) ────────────────────────────────────────
function drawSlashTitle(ctx, text, alpha = 1) {
  ctx.globalAlpha = alpha;
  ctx.font = 'bold 15px monospace';
  ctx.fillStyle = '#1E9BFF';
  ctx.fillText('/', 20, 38);
  ctx.fillStyle = '#fff';
  ctx.fillText(' ' + text, 28, 38);
  ctx.globalAlpha = 1;
}

// ── Render une scène motion design → buffer raw RGBA par frame ───────────
async function renderMotionScene({ duration, imagePath, imagePath2, title, subtitle, badge, labelBottom, panDir = 'in' }) {
  const totalFrames = Math.round(duration * FPS);
  const img1 = await loadImage(imagePath);
  const img2 = imagePath2 ? await loadImage(imagePath2) : null;
  const canvas = createCanvas(W, H);
  const ctx = canvas.getContext('2d');
  const frames = [];

  for (let f = 0; f < totalFrames; f++) {
    const t = f / totalFrames;
    const tEase = t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
    ctx.clearRect(0, 0, W, H);

    // Si deux images : transition crossfade à t=0.5
    if (img2 && t > 0.45) {
      const blend = Math.min(1, (t - 0.45) / 0.2);
      drawCover(ctx, img1, tEase, panDir);
      ctx.globalAlpha = blend;
      drawCover(ctx, img2, tEase, panDir);
      ctx.globalAlpha = 1;
    } else {
      drawCover(ctx, img1, tEase, panDir);
    }

    // Overlay bas
    drawBottomOverlay(ctx, 180);

    // Titre slash en haut (apparaît à t>0.1)
    const titleAlpha = Math.min(1, (t - 0.1) / 0.15);
    if (titleAlpha > 0) drawSlashTitle(ctx, title, titleAlpha);

    // Badge
    if (badge) {
      const ba = Math.min(1, (t - 0.15) / 0.15);
      if (ba > 0) {
        ctx.globalAlpha = ba;
        drawBadge(ctx, badge, 20, H - 130);
        ctx.globalAlpha = 1;
      }
    }

    // Sous-titre
    if (subtitle) {
      const sa = Math.min(1, (t - 0.2) / 0.2);
      if (sa > 0) {
        ctx.globalAlpha = sa;
        ctx.font = 'bold 20px sans-serif';
        ctx.fillStyle = '#fff';
        // wrapping simple sur 2 lignes
        const words = subtitle.split(' ');
        let line1 = '', line2 = '';
        for (const w of words) {
          ctx.font = 'bold 20px sans-serif';
          if (ctx.measureText(line1 + w).width < W - 40) line1 += w + ' ';
          else line2 += w + ' ';
        }
        ctx.fillText(line1.trim(), 20, H - 95);
        if (line2.trim()) ctx.fillText(line2.trim(), 20, H - 68);
        ctx.globalAlpha = 1;
      }
    }

    // Label URL bas
    if (labelBottom) {
      const la = Math.min(1, (t - 0.3) / 0.2);
      if (la > 0) {
        ctx.globalAlpha = la;
        ctx.font = '13px monospace';
        ctx.fillStyle = '#1E9BFF';
        const m = ctx.measureText(labelBottom);
        ctx.fillText(labelBottom, (W - m.width) / 2, H - 18);
        ctx.globalAlpha = 1;
      }
    }

    frames.push(frameBuffer(canvas));
  }
  return { frames, totalFrames };
}

// ── Render scène "How it works" (fond noir + étapes animées) ─────────────
async function renderHowItWorks(duration = 8) {
  const totalFrames = Math.round(duration * FPS);
  const canvas = createCanvas(W, H);
  const ctx = canvas.getContext('2d');
  const frames = [];
  const steps = [
    { num: '01', text: 'Choisissez une commande IA', color: '#1E9BFF' },
    { num: '02', text: 'Uploadez votre photo produit', color: '#22C55E' },
    { num: '03', text: 'Recevez votre affiche pub', color: '#F59E0B' },
  ];

  for (let f = 0; f < totalFrames; f++) {
    const t = f / totalFrames;
    ctx.fillStyle = '#050A14';
    ctx.fillRect(0, 0, W, H);

    // Logo
    ctx.font = 'bold 16px monospace';
    ctx.fillStyle = '#1E9BFF';
    ctx.fillText('/', 20, 44);
    ctx.fillStyle = '#fff';
    ctx.fillText(' SlashAtlas', 28, 44);

    // Titre
    const ta = Math.min(1, t / 0.12);
    ctx.globalAlpha = ta;
    ctx.font = 'bold 26px sans-serif';
    ctx.fillStyle = '#fff';
    const title = 'Comment ça marche ?';
    ctx.fillText(title, (W - ctx.measureText(title).width) / 2, 130);
    ctx.globalAlpha = 1;

    // Étapes (chacune apparaît à intervalles)
    steps.forEach((step, i) => {
      const delay = 0.15 + i * 0.2;
      const alpha = Math.min(1, Math.max(0, (t - delay) / 0.18));
      if (alpha <= 0) return;
      ctx.globalAlpha = alpha;
      const y = 220 + i * 120;

      // Cercle numéro
      ctx.beginPath();
      ctx.arc(46, y, 26, 0, Math.PI * 2);
      ctx.fillStyle = step.color + '22';
      ctx.fill();
      ctx.strokeStyle = step.color;
      ctx.lineWidth = 2;
      ctx.stroke();
      ctx.font = 'bold 18px sans-serif';
      ctx.fillStyle = step.color;
      ctx.fillText(step.num, 46 - ctx.measureText(step.num).width / 2, y + 6);

      // Texte
      ctx.font = 'bold 17px sans-serif';
      ctx.fillStyle = '#fff';
      ctx.fillText(step.text, 84, y + 6);

      ctx.globalAlpha = 1;
    });

    // Barre de progression en bas
    const barW = (t * W * 0.85);
    ctx.fillStyle = '#1E9BFF33';
    ctx.fillRect(W * 0.075, H - 40, W * 0.85, 3);
    ctx.fillStyle = '#1E9BFF';
    ctx.fillRect(W * 0.075, H - 40, barW, 3);

    frames.push(frameBuffer(canvas));
  }
  return { frames, totalFrames };
}

// ── Render scène CTA final ────────────────────────────────────────────────
async function renderCTA(duration = 4) {
  const totalFrames = Math.round(duration * FPS);
  const canvas = createCanvas(W, H);
  const ctx = canvas.getContext('2d');
  const frames = [];

  for (let f = 0; f < totalFrames; f++) {
    const t = f / totalFrames;
    ctx.fillStyle = '#050A14';
    ctx.fillRect(0, 0, W, H);

    // Dégradé de fond
    const grad = ctx.createRadialGradient(W / 2, H / 2, 0, W / 2, H / 2, H * 0.7);
    grad.addColorStop(0, '#0A1628');
    grad.addColorStop(1, '#050A14');
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, W, H);

    const pulse = 0.97 + Math.sin(t * Math.PI * 4) * 0.03;

    ctx.globalAlpha = Math.min(1, t / 0.2);
    ctx.font = 'bold 14px monospace';
    ctx.fillStyle = '#1E9BFF';
    const logo = '/ SlashAtlas';
    ctx.fillText(logo, (W - ctx.measureText(logo).width) / 2, H * 0.3);

    ctx.globalAlpha = Math.min(1, (t - 0.1) / 0.2);
    ctx.font = `bold ${Math.round(28 * pulse)}px sans-serif`;
    ctx.fillStyle = '#fff';
    const cta1 = 'Essayez gratuitement';
    ctx.fillText(cta1, (W - ctx.measureText(cta1).width) / 2, H * 0.44);

    ctx.globalAlpha = Math.min(1, (t - 0.2) / 0.2);
    ctx.font = 'bold 22px monospace';
    ctx.fillStyle = '#1E9BFF';
    const url = 'slashatlas.com';
    ctx.fillText(url, (W - ctx.measureText(url).width) / 2, H * 0.55);

    ctx.globalAlpha = Math.min(1, (t - 0.35) / 0.2);
    ctx.font = '16px sans-serif';
    ctx.fillStyle = '#aaa';
    const sub = '👆 Lien en bio • Abonnez-vous 🔔';
    ctx.fillText(sub, (W - ctx.measureText(sub).width) / 2, H * 0.65);

    ctx.globalAlpha = 1;
    frames.push(frameBuffer(canvas));
  }
  return { frames, totalFrames };
}

// ── Encoder un tableau de frames RGBA → fichier MP4 (sans audio) ─────────
function encodeFrames(frames, outputPath, fps = FPS) {
  return new Promise((resolve, reject) => {
    const ff = spawn(FFMPEG, [
      '-y', '-f', 'rawvideo', '-pixel_format', 'rgba',
      '-video_size', `${W}x${H}`, '-framerate', String(fps),
      '-i', 'pipe:0',
      '-c:v', 'libx264', '-preset', 'fast', '-crf', '20',
      '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
      outputPath,
    ], { stdio: ['pipe', 'pipe', 'pipe'] });
    for (const buf of frames) ff.stdin.write(buf);
    ff.stdin.end();
    ff.on('close', code => code === 0 ? resolve() : reject(new Error(`ffmpeg exit ${code}`)));
  });
}

// ── Encode en temps réel (streaming, économise la mémoire) ───────────────
async function encodeStream(renderFn, duration, outputPath) {
  const totalFrames = Math.round(duration * FPS);
  return new Promise((resolve, reject) => {
    const ff = spawn(FFMPEG, [
      '-y', '-f', 'rawvideo', '-pixel_format', 'rgba',
      '-video_size', `${W}x${H}`, '-framerate', String(FPS),
      '-i', 'pipe:0',
      '-c:v', 'libx264', '-preset', 'fast', '-crf', '20',
      '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
      outputPath,
    ], { stdio: ['pipe', 'pipe', 'pipe'] });

    (async () => {
      for (let f = 0; f < totalFrames; f++) {
        const buf = await renderFn(f, totalFrames);
        await new Promise((ok, ko) => {
          if (!ff.stdin.write(buf)) ff.stdin.once('drain', ok);
          else ok();
        });
      }
      ff.stdin.end();
    })().catch(reject);

    ff.on('close', code => code === 0 ? resolve() : reject(new Error(`ffmpeg ${code}`)));
  });
}

// ── Main ──────────────────────────────────────────────────────────────────
(async () => {
  console.log('\n🎬 Montage promotionnel SlashAtlas\n');

  const seg = n => path.join(TMP, `seg_${n}.mp4`);

  // --- Segment 1 : extrait vidéo caméra 0-9s ---
  process.stdout.write('  [1/6] Intro caméra (0-9s)… ');
  spawnSync(FFMPEG, [
    '-y', '-ss', '0', '-t', '9', '-i', USER_VIDEO,
    '-c:v', 'libx264', '-preset', 'fast', '-crf', '20',
    '-c:a', 'aac', '-b:a', '128k', seg(1),
  ], { stdio: 'pipe' });
  console.log('✓');

  // --- Segment 2 : motion design Homepage (7s) ---
  process.stdout.write('  [2/6] Homepage motion (7s)… ');
  const { frames: f2 } = await renderMotionScene({
    duration: 7,
    imagePath: SHOTS.homepage,
    title: 'slashatlas.com',
    badge: '✦ Gratuit',
    subtitle: 'Créez vos affiches publicitaires avec l\'IA',
    labelBottom: 'slashatlas.com',
    panDir: 'in',
  });
  await encodeFrames(f2, seg(2));
  console.log('✓');

  // --- Segment 3 : motion design Commandes (8s) ---
  process.stdout.write('  [3/6] Commandes motion (8s)… ');
  const { frames: f3 } = await renderMotionScene({
    duration: 8,
    imagePath: SHOTS.commands,
    imagePath2: SHOTS.commands2,
    title: 'Commandes IA',
    badge: '749 commandes gratuites',
    subtitle: 'Mode · Restauration · Beauté · Musique…',
    labelBottom: 'slashatlas.com/commandes',
    panDir: 'down',
  });
  await encodeFrames(f3, seg(3));
  console.log('✓');

  // --- Segment 4 : How it works (8s) ---
  process.stdout.write('  [4/6] Comment ça marche (8s)… ');
  const { frames: f4 } = await renderHowItWorks(8);
  await encodeFrames(f4, seg(4));
  console.log('✓');

  // --- Segment 5 : Avant/Après (9s) ---
  process.stdout.write('  [5/6] Avant/Après (9s)… ');
  const { frames: f5 } = await renderMotionScene({
    duration: 9,
    imagePath: SHOTS.beforeAfter,
    title: 'Résultat IA',
    badge: '⚡ 30 secondes',
    subtitle: 'Votre photo → Affiche professionnelle',
    labelBottom: 'slashatlas.com/generer',
    panDir: 'in',
  });
  await encodeFrames(f5, seg(5));
  console.log('✓');

  // --- Segment 6 : Studio Film (9s) ---
  process.stdout.write('  [6/7] Studio Film (9s)… ');
  const { frames: f6 } = await renderMotionScene({
    duration: 9,
    imagePath: SHOTS.studioFilm,
    title: 'Studio Film',
    badge: '🎬 Voix IA incluse',
    subtitle: 'Décrivez votre histoire. L\'IA fait le reste.',
    labelBottom: 'slashatlas.com/studio-film',
    panDir: 'in',
  });
  await encodeFrames(f6, seg(6));
  console.log('✓');

  // --- Segment 7 : extrait vidéo caméra 42-52s ---
  process.stdout.write('  [7/7] Outro caméra (42-52s)… ');
  spawnSync(FFMPEG, [
    '-y', '-ss', '42', '-t', '10.5', '-i', USER_VIDEO,
    '-c:v', 'libx264', '-preset', 'fast', '-crf', '20',
    '-c:a', 'aac', '-b:a', '128k', seg(7),
  ], { stdio: 'pipe' });
  console.log('✓');

  // --- Concaténation de tous les segments ---
  process.stdout.write('\n  🔗 Concaténation vidéo… ');

  // Extraire l'audio complet de la vidéo utilisateur
  const audioFull = path.join(TMP, 'audio_full.aac');
  spawnSync(FFMPEG, ['-y', '-i', USER_VIDEO, '-vn', '-c:a', 'aac', '-b:a', '128k', audioFull], { stdio: 'pipe' });

  // Concat vidéo via filter_complex (video only, pas d'audio dans les segments motion)
  // Segments caméra : on extrait seulement la piste vidéo pour uniformité
  const segV = n => path.join(TMP, `segv_${n}.mp4`);
  for (const n of [1, 7]) {
    spawnSync(FFMPEG, [
      '-y', '-i', seg(n), '-an',
      '-c:v', 'libx264', '-preset', 'fast', '-crf', '20', '-pix_fmt', 'yuv420p', segV(n),
    ], { stdio: 'pipe' });
  }
  // Segments motion : déjà sans audio, juste copier
  for (const n of [2, 3, 4, 5, 6]) {
    spawnSync(FFMPEG, ['-y', '-i', seg(n), '-c:v', 'copy', segV(n)], { stdio: 'pipe' });
  }

  // Construire filter_complex concat video
  const N = 7;
  const inputs2 = [];
  for (let n = 1; n <= N; n++) inputs2.push('-i', segV(n));
  const concatInputs = Array.from({ length: N }, (_, i) => `[${i}:v]`).join('');
  const filterConcat = `${concatInputs}concat=n=${N}:v=1:a=0[vout]`;

  await new Promise((resolve, reject) => {
    // IMPORTANT : tous les -i avant les -map/-filter_complex
    const args = [
      '-y',
      ...inputs2,          // inputs 0..N-1 (segments vidéo)
      '-i', audioFull,     // input N (audio utilisateur)
      '-filter_complex', filterConcat,
      '-map', '[vout]',
      '-map', `${N}:a`,
      '-c:v', 'libx264', '-preset', 'fast', '-crf', '20', '-pix_fmt', 'yuv420p',
      '-c:a', 'aac', '-b:a', '128k', '-shortest',
      '-movflags', '+faststart', OUT_VIDEO,
    ];
    const ff = spawn(FFMPEG, args, { stdio: ['pipe', 'pipe', 'pipe'] });
    let errOut = '';
    ff.stderr.on('data', d => { errOut += d.toString(); });
    ff.on('close', code => {
      if (code === 0) resolve();
      else reject(new Error(`ffmpeg concat exit ${code}\n${errOut.slice(-600)}`));
    });
  });

  console.log('✓');
  console.log(`\n✅ Vidéo prête : ${OUT_VIDEO}\n`);
})().catch(err => { console.error('\n❌', err.message); process.exit(1); });
