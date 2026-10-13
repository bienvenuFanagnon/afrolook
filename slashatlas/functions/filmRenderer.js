'use strict';
// Film & Série : images FLUX Cloudflare + voix Google TTS Chirp 3 HD
// + Ken Burns + sous-titres + musique d'ambiance + FFmpeg → MP4
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');
const { createCanvas, loadImage } = require('@napi-rs/canvas');
const FFMPEG = require('ffmpeg-static');
const { getStorage } = require('firebase-admin/storage');
const { FieldValue } = require('firebase-admin/firestore');
const { db, bump, addCredits } = require('./studio');
const { tts, FPS, _h: vidH } = require('./video');
const { music, mix: mixAudio } = require('./sfx');

const SR = vidH.SR; // 24000 Hz (identique au TTS Chirp 3 HD)
const W = 1280, H = 720; // 16:9 cinéma

// Génère une image via FLUX Cloudflare AI → Buffer JPEG
async function generateFluxImage(setting, cfAccountId, cfApiToken) {
  // Supprimer BOM (U+FEFF) éventuel ajouté lors de la saisie du secret
  const token = String(cfApiToken || '').replace(/^﻿/, '').trim();
  const account = String(cfAccountId || '').replace(/^﻿/, '').trim();
  const prompt = setting + ', cinematic still, high quality, detailed, vivid colors, film photography style';
  const url = `https://api.cloudflare.com/client/v4/accounts/${account}/ai/run/@cf/black-forest-labs/flux-1-schnell`;
  const r = await fetch(url, {
    method: 'POST',
    signal: AbortSignal.timeout(30000),
    headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ prompt }),
  });
  if (!r.ok) throw new Error('flux_' + r.status);
  // L'API retourne soit du JSON {result:{image:base64}} soit des bytes bruts
  const raw = Buffer.from(await r.arrayBuffer());
  if (raw[0] === 0x7B) { // '{' = JSON
    const json = JSON.parse(raw.toString('utf8'));
    const b64 = json.result?.image || json.image || '';
    if (!b64) throw new Error('flux_no_image');
    return Buffer.from(b64, 'base64');
  }
  return raw;
}

// Image de fallback : dégradé sombre + texte du décor
function fallbackImage(setting) {
  const cv = createCanvas(W, H);
  const ctx = cv.getContext('2d');
  const grad = ctx.createLinearGradient(0, 0, W, H);
  grad.addColorStop(0, '#1a1a2e');
  grad.addColorStop(1, '#16213e');
  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, W, H);
  ctx.fillStyle = 'rgba(255,255,255,0.12)';
  ctx.font = '22px sans-serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  const preview = String(setting || '').split(/\s+/).slice(0, 10).join(' ');
  ctx.fillText(preview, W / 2, H / 2);
  return cv.toBuffer('image/jpeg');
}

// Dessine la mention "slashatlas.com" en bas à droite (watermark optionnel)
function drawWatermark(ctx) {
  ctx.save();
  ctx.globalAlpha = 0.55;
  ctx.font = 'bold 14px sans-serif';
  ctx.fillStyle = 'rgba(255,255,255,0.85)';
  ctx.textAlign = 'right';
  ctx.textBaseline = 'bottom';
  ctx.fillText('slashatlas.com', W - 14, H - 12);
  ctx.restore();
}

// Dessine le sous-titre en bas du frame avec fond semi-transparent
function drawSubtitle(ctx, text) {
  if (!text) return;
  const maxW = W * 0.88;
  ctx.font = '26px sans-serif';
  const wordList = String(text).trim().split(/\s+/);
  const lines = [];
  let line = '';
  for (const word of wordList) {
    const t = line ? line + ' ' + word : word;
    if (ctx.measureText(t).width <= maxW || !line) { line = t; } else { lines.push(line); line = word; }
  }
  if (line) lines.push(line);
  const lh = 34;
  const padV = 12;
  const boxH = lines.length * lh + padV * 2;
  const y0 = H - boxH - 36;
  ctx.fillStyle = 'rgba(0,0,0,0.56)';
  ctx.beginPath();
  ctx.roundRect(W * 0.04, y0 - padV, W * 0.92, boxH, 6);
  ctx.fill();
  ctx.fillStyle = '#fff';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'top';
  lines.forEach((l, i) => ctx.fillText(l, W / 2, y0 + i * lh));
  ctx.textAlign = 'start';
}

// Encode les frames d'une scène (sans audio) → fichier MP4 H.264
async function renderSceneVideo(imgBuf, voiceText, sceneDur, outFile, opts = {}) {
  const img = await loadImage(imgBuf);
  const nFrames = Math.round(sceneDur * FPS);

  const args = [
    '-y', '-loglevel', 'error',
    '-f', 'rawvideo', '-pix_fmt', 'rgba', '-s', `${W}x${H}`, '-framerate', String(FPS), '-i', 'pipe:0',
    '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '22',
    '-pix_fmt', 'yuv420p', '-g', '48', '-an',
    outFile,
  ];

  const ff = spawn(FFMPEG, args, { stdio: ['pipe', 'ignore', 'pipe'] });
  let ffErr = ''; ff.stderr.on('data', (d) => { ffErr += d; });
  const done = new Promise((res, rej) => {
    ff.on('close', (c) => (c === 0 ? res() : rej(new Error('ffmpeg_scene ' + ffErr.slice(-200)))));
    ff.on('error', rej);
  });
  ff.stdin.on('error', () => {});

  const cv = createCanvas(W, H);
  const ctx = cv.getContext('2d');
  ctx.imageSmoothingQuality = 'high';

  for (let f = 0; f < nFrames; f++) {
    const p = f / Math.max(1, nFrames - 1); // 0.0 → 1.0
    const t = f / FPS;

    // Ken Burns : zoom progressif + léger panoramique gauche→droite
    const scale = 1.0 + 0.10 * p;
    const srcW = img.width / scale;
    const srcH = img.height / scale;
    const srcX = (img.width - srcW) * 0.5 * p;
    const srcY = (img.height - srcH) / 2;
    ctx.drawImage(img, srcX, srcY, srcW, srcH, 0, 0, W, H);

    // Sous-titre : fade in 0.25s, fade out 0.4s avant la fin
    const alpha = Math.min(1, t / 0.25) * Math.min(1, (sceneDur - t) / 0.4);
    if (alpha > 0.05 && voiceText) {
      ctx.globalAlpha = alpha;
      drawSubtitle(ctx, voiceText);
      ctx.globalAlpha = 1;
    }

    // Watermark
    if (opts.watermark) drawWatermark(ctx);

    const buf = cv.data();
    if (!ff.stdin.write(buf)) await new Promise((r) => ff.stdin.once('drain', r));
  }

  ff.stdin.end();
  await done;
}

// Concatène des fichiers MP4 avec FFmpeg concat demuxer
async function concatVideos(sceneFiles, outFile) {
  const listFile = outFile + '.list.txt';
  fs.writeFileSync(listFile, sceneFiles.map((f) => `file '${f.replace(/\\/g, '/').replace(/'/g, "\\'")}'`).join('\n'));
  await new Promise((res, rej) => {
    const ff = spawn(FFMPEG, ['-y', '-loglevel', 'error', '-f', 'concat', '-safe', '0', '-i', listFile, '-c', 'copy', outFile]);
    let err = ''; ff.stderr && ff.stderr.on('data', (d) => { err += d; });
    ff.on('close', (c) => (c === 0 ? res() : rej(new Error('ffmpeg_concat ' + err.slice(-200)))));
    ff.on('error', rej);
  });
  try { fs.unlinkSync(listFile); } catch {}
}

// Mélange la piste vidéo et la piste audio dans un MP4 final
async function muxVideoAudio(videoFile, audioFile, outFile, totalSec) {
  await new Promise((res, rej) => {
    const ff = spawn(FFMPEG, [
      '-y', '-loglevel', 'error',
      '-i', videoFile, '-i', audioFile,
      '-map', '0:v', '-map', '1:a',
      '-c:v', 'copy', '-c:a', 'aac', '-b:a', '128k', '-movflags', '+faststart',
      '-t', totalSec.toFixed(2),
      outFile,
    ]);
    let err = ''; ff.stderr && ff.stderr.on('data', (d) => { err += d; });
    ff.on('close', (c) => (c === 0 ? res() : rej(new Error('ffmpeg_mux ' + err.slice(-200)))));
    ff.on('error', rej);
  });
}

// Pipeline complet : Firestore job → images FLUX + TTS → frames + audio → MP4 → Storage
async function renderFilm(jobId, cfAccountId, cfApiToken) {
  const jobRef = db().collection('FilmJobs').doc(jobId);
  const snap = await jobRef.get();
  if (!snap.exists) throw new Error('job_not_found');
  const { uid, cost, script, lang, duration, watermark, customAudioPath } = snap.data();
  const scenes = script && script.scenes;
  if (!scenes || !scenes.length) throw new Error('no_script');

  const sceneDur = duration === 3 ? 22 : 20;
  const totalSec = scenes.length * sceneDur;
  const workDir = fs.mkdtempSync(path.join(os.tmpdir(), 'sfr-'));

  try {
    await jobRef.update({ status: 'rendering', updatedAt: FieldValue.serverTimestamp() });

    // Étape 1 : images FLUX (parallèle, erreur non fatale)
    const imgBufs = await Promise.all(
      scenes.map((sc) =>
        generateFluxImage(sc.setting, cfAccountId, cfApiToken)
          .catch((e) => { console.error('flux scene', sc.id, e.message); return null; })
      )
    );

    // Étape 2 : TTS séquentielle (éviter les erreurs de quota Google TTS)
    const ttsResults = [];
    for (const sc of scenes) {
      try {
        const r = await tts(sc.voice, lang, 'f', sceneDur * 0.88);
        ttsResults.push(r);
      } catch (e) {
        console.error('tts scene', sc.id, e.message);
        ttsResults.push({ pcm: new Int16Array(0), chars: 0 });
      }
    }

    await jobRef.update({ status: 'assembling', updatedAt: FieldValue.serverTimestamp() });

    // Étape 3 : rendu vidéo scène par scène (sans audio)
    const sceneFiles = [];
    for (let i = 0; i < scenes.length; i++) {
      const sc = scenes[i];
      const imgBuf = imgBufs[i] || fallbackImage(sc.setting);
      const outFile = path.join(workDir, `s${String(i).padStart(2, '0')}.mp4`);
      await renderSceneVideo(imgBuf, sc.voice, sceneDur, outFile, { watermark: !!watermark });
      sceneFiles.push(outFile);
    }

    // Étape 4 : concaténation vidéo (sans audio)
    const noAudioFile = path.join(workDir, 'noaudio.mp4');
    await concatVideos(sceneFiles, noAudioFile);

    // Étape 5 : mixage audio global (voix TTS + musique d'ambiance) OU audio importé
    let wavFile;
    if (customAudioPath) {
      // Audio importé par l'utilisateur : télécharger depuis Firebase Storage
      wavFile = path.join(workDir, 'custom-audio.wav');
      const [customBuf] = await getStorage().bucket().file(customAudioPath).download();
      fs.writeFileSync(wavFile, customBuf);
    } else {
      const bounds = scenes.slice(1).map((_, i) => (i + 1) * sceneDur);
      const voiceClips = ttsResults
        .map(({ pcm }, i) => (pcm.length ? { at: i * sceneDur + 0.3, pcm } : null))
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

    // Étape 6 : muxage vidéo + audio → film.mp4
    const filmFile = path.join(workDir, 'film.mp4');
    await muxVideoAudio(noAudioFile, wavFile, filmFile, totalSec);

    // Étape 7 : upload Firebase Storage
    const storagePath = `films/${uid}/${jobId}.mp4`;
    await getStorage().bucket().file(storagePath).save(fs.readFileSync(filmFile), { contentType: 'video/mp4', resumable: false });

    const ttsTotal = ttsResults.reduce((s, r) => s + (r.chars || 0), 0);
    await jobRef.update({
      status: 'done',
      storagePath,
      doneAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      ttsChars: ttsTotal,
    });
    await bump({ film_done: 1, film_secs: Math.round(totalSec) });

  } catch (e) {
    console.error('renderFilm error', jobId, e.message);
    await jobRef.update({ status: 'error', error: e.message, updatedAt: FieldValue.serverTimestamp() });
    if (uid && cost) await addCredits(uid, cost, 'film_refund_' + jobId).catch(() => {});
    throw e;
  } finally {
    try { fs.rmSync(workDir, { recursive: true, force: true }); } catch {}
  }
}

module.exports = { renderFilm };
