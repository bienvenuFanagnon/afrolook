'use strict';
// Montage promo SlashAtlas v2 — UI redessinée en canvas (motion design pur)

const { createCanvas, loadImage } = require('@napi-rs/canvas');
const { spawn, spawnSync } = require('child_process');
const path = require('path');
const fs = require('fs');

const W = 360, H = 640, FPS = 30;
const SR = 44100;
const FADE = 0.3; // secondes de fondu entre segments
const FFMPEG = 'ffmpeg';
const USER_VIDEO = 'D:/Personnel/Downloads/slashVideo.mp4';
const OUT_VIDEO = path.join(__dirname, '../static/videos/promo-slashatlas.mp4');
const TMP = 'C:/Users/ANVT/AppData/Local/Temp/claude/D--bienvenu-Projets-otherProjets-afrolook-V2-afrolookofficiel-v2/881e5bd7-c4de-403d-8ba6-7a38f111a58b/scratchpad';
const IMG_DIR = path.join(__dirname, '../static/img/c');

const C = {
  bg: '#060D1A', bgCard: '#0E1C2E', bgCard2: '#111E30',
  blue: '#1E9BFF', green: '#22C55E',
  amber: '#F59E0B', white: '#FFFFFF', gray: '#8899AA', grayLight: '#B0BEC5',
};

// Timecodes après ajout du showcase 5s en intro
// Seg 0: showcase 0-5s | Seg 1: face cam 5-12s | Seg 2: cards 12-19s
// Seg 3: face cam 19-26s | Seg 4: hero 26-36s | Seg 5: workflow 36-45s
// Seg 6: face cam 45-48s | Seg 7: CTA 48-57.5s
const SUBS = [
  { s: 0,    e: 5,    t: "Bonjour ! Vous voulez des affiches pub professionnelles ?" },
  { s: 5,    e: 12,   t: "Bonjour ! Vous voulez des affiches pub professionnelles ?" },
  { s: 12,   e: 19,   t: "Mais vous avez du mal a ecrire les bons prompts IA ?" },
  { s: 19,   e: 26,   t: "Nous avons la solution : slashatlas.com !" },
  { s: 26,   e: 36,   t: "Plus de 700 prompts prets a emploi pour vos reseaux" },
  { s: 36,   e: 45,   t: "Copiez-collez ou generez directement sur le site" },
  { s: 45,   e: 48,   t: "Visitez slashatlas.com et testez gratuitement" },
  { s: 48,   e: 57.5, t: "Abonnez-vous ! Visitez slashatlas.com" },
];

function getSub(timeSec) {
  return SUBS.find(s => timeSec >= s.s && timeSec < s.e) || null;
}

function rr(ctx, x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x+r, y); ctx.lineTo(x+w-r, y);
  ctx.quadraticCurveTo(x+w, y, x+w, y+r);
  ctx.lineTo(x+w, y+h-r);
  ctx.quadraticCurveTo(x+w, y+h, x+w-r, y+h);
  ctx.lineTo(x+r, y+h);
  ctx.quadraticCurveTo(x, y+h, x, y+h-r);
  ctx.lineTo(x, y+r);
  ctx.quadraticCurveTo(x, y, x+r, y);
  ctx.closePath();
}

function ease(t) { return t < 0.5 ? 2*t*t : 1-Math.pow(-2*t+2,2)/2; }
function clamp(v, mn=0, mx=1) { return Math.max(mn, Math.min(mx, v)); }
function slideAlpha(t, delay, dur=0.18) { return clamp((t-delay)/dur); }

function drawSubtitle(ctx, text) {
  if (!text) return;
  ctx.save();
  ctx.font = 'bold 13px sans-serif';
  const pad = 10, maxW = W - 40;
  const words = text.split(' ');
  const lines = [];
  let cur = '';
  for (const w of words) {
    const test = cur ? cur+' '+w : w;
    if (ctx.measureText(test).width > maxW && cur) { lines.push(cur); cur = w; }
    else cur = test;
  }
  if (cur) lines.push(cur);
  const lineH = 18, totalH = lines.length * lineH + pad * 2;
  const y = H - totalH - 14;
  ctx.fillStyle = 'rgba(0,0,0,0.75)';
  rr(ctx, 14, y, W-28, totalH, 8); ctx.fill();
  ctx.fillStyle = '#fff';
  lines.forEach((line, i) => {
    const lw = ctx.measureText(line).width;
    ctx.fillText(line, (W-lw)/2, y+pad+14+i*lineH);
  });
  ctx.restore();
}

function drawNavbar(ctx, alpha=1) {
  ctx.save(); ctx.globalAlpha = alpha;
  ctx.fillStyle = 'rgba(6,13,26,0.92)'; ctx.fillRect(0, 0, W, 56);
  ctx.font = 'bold 15px monospace'; ctx.fillStyle = C.blue; ctx.fillText('/', 18, 35);
  ctx.fillStyle = C.white; ctx.fillText(' SlashAtlas', 26, 35);
  rr(ctx, W-110, 14, 94, 30, 15); ctx.fillStyle = C.blue; ctx.fill();
  ctx.font = 'bold 12px sans-serif'; ctx.fillStyle = '#fff';
  ctx.fillText('Se connecter', W-103, 34);
  ctx.restore();
}

function frameBuffer(canvas) {
  return Buffer.from(canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height).data);
}

function genSwoosh(ms=350) {
  const n = Math.floor(SR*ms/1000);
  const buf = new Int16Array(n*2);
  for (let i = 0; i < n; i++) {
    const t = i/SR, prog = i/n;
    const env = Math.exp(-prog*6)*Math.min(1, prog*30);
    const freq = 700*Math.exp(-prog*8)+80;
    const wave = Math.sin(2*Math.PI*freq*t)*0.6+(Math.random()-0.5)*0.25;
    const s = Math.round(clamp(wave*env,-1,1)*14000);
    buf[i*2]=s; buf[i*2+1]=s;
  }
  return buf;
}

function genAmbient(durationSec) {
  const n = Math.floor(SR * durationSec);
  const buf = new Int16Array(n * 2);
  // Accords pentatoniques doux mode majeur (do mi sol la)
  const notes = [130.81, 164.81, 196.00, 220.00, 261.63];
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    const lfo = 0.85 + 0.15 * Math.sin(2 * Math.PI * 0.07 * t);
    let s = 0;
    notes.forEach((f, fi) => {
      const ph = fi * 1.1;
      s += Math.sin(2 * Math.PI * f * t + ph) * 0.05;
      s += Math.sin(2 * Math.PI * f * 2 * t + ph) * 0.02;
    });
    s *= lfo;
    const fadeIn  = Math.min(1, t / 3);
    const fadeOut = Math.min(1, (durationSec - t) / 3);
    s *= fadeIn * fadeOut;
    const val = Math.round(clamp(s, -1, 1) * 4500);
    buf[i*2] = val; buf[i*2+1] = val;
  }
  return buf;
}

function pcmToWav(pcm) {
  const dataLen = pcm.byteLength;
  const h = Buffer.alloc(44);
  h.write('RIFF',0); h.writeUInt32LE(36+dataLen,4); h.write('WAVE',8); h.write('fmt ',12);
  h.writeUInt32LE(16,16); h.writeUInt16LE(1,20); h.writeUInt16LE(2,22);
  h.writeUInt32LE(SR,24); h.writeUInt32LE(SR*4,28); h.writeUInt16LE(4,32);
  h.writeUInt16LE(16,34); h.write('data',36); h.writeUInt32LE(dataLen,40);
  return Buffer.concat([h, Buffer.from(pcm.buffer)]);
}

function trimFaceCam(outputPath, startSec, durSec, fadeIn=true, fadeOut=true) {
  const vfParts = [
    `fps=${FPS},scale=${W}:${H}:force_original_aspect_ratio=decrease,pad=${W}:${H}:(ow-iw)/2:(oh-ih)/2`,
  ];
  if (fadeIn)  vfParts.push(`fade=t=in:st=0:d=${FADE}`);
  if (fadeOut) vfParts.push(`fade=t=out:st=${durSec-FADE}:d=${FADE}`);
  const r = spawnSync(FFMPEG, [
    '-y', '-ss', String(startSec), '-t', String(durSec), '-i', USER_VIDEO,
    '-vf', vfParts.join(','),
    '-c:v', 'libx264', '-preset', 'fast', '-crf', '20', '-pix_fmt', 'yuv420p',
    '-an', outputPath,
  ], { stdio: 'pipe' });
  if (r.status !== 0) throw new Error(r.stderr.toString().slice(-400));
}

function encodeFrames(frames, out) {
  return new Promise((resolve, reject) => {
    const ff = spawn(FFMPEG, [
      '-y', '-f', 'rawvideo', '-pixel_format', 'rgba',
      '-video_size', `${W}x${H}`, '-framerate', String(FPS),
      '-i', 'pipe:0',
      '-c:v', 'libx264', '-preset', 'fast', '-crf', '20', '-pix_fmt', 'yuv420p',
      '-movflags', '+faststart', out,
    ], { stdio: ['pipe','pipe','pipe'] });
    for (const b of frames) ff.stdin.write(b);
    ff.stdin.end();
    let e='';
    ff.stderr.on('data', d => e+=d);
    ff.on('close', c => c===0 ? resolve() : reject(new Error(e.slice(-400))));
  });
}

// ── SCÈNE 0 : Showcase affiches beauté/produits (5s) ──────────────
async function renderShowcase(duration=5, imgs=[]) {
  const N = Math.round(duration*FPS);
  const canvas = createCanvas(W, H);
  const ctx = canvas.getContext('2d');
  const frames = [];

  const IW = Math.floor((W - 36) / 2); // ~162px
  const IH = Math.round(IW * 1.3);      // ~211px
  const GAP = 10;
  const STRIP = 3 * IH + 2 * GAP; // hauteur d'une bande de 3 images

  const left  = imgs.slice(0, 3);
  const right = imgs.slice(3, 6);

  for (let f=0; f<N; f++) {
    const t = f/N;
    ctx.fillStyle = C.bg; ctx.fillRect(0,0,W,H);

    // Défilement : colonne gauche vers le haut, droite un peu en retard
    const maxScroll = Math.max(0, STRIP - H + 100);
    const scrollL = -ease(t) * maxScroll;
    const scrollR = -ease(clamp(t * 0.85 + 0.08)) * maxScroll;

    // Colonne gauche
    const xL = 12;
    left.forEach((img, i) => {
      const y = scrollL + i * (IH + GAP);
      if (y + IH < -10 || y > H + 10) return;
      rr(ctx, xL, y, IW, IH, 12);
      if (img) {
        ctx.save(); ctx.clip();
        ctx.drawImage(img, xL, y, IW, IH);
        ctx.restore();
        // overlay gradient bas pour le nom
        const og = ctx.createLinearGradient(0, y+IH-40, 0, y+IH);
        og.addColorStop(0, 'rgba(0,0,0,0)'); og.addColorStop(1, 'rgba(0,0,0,0.6)');
        rr(ctx, xL, y, IW, IH, 12); ctx.fillStyle = og; ctx.fill();
      } else {
        ctx.fillStyle = '#1A1A2E'; ctx.fill();
      }
    });

    // Colonne droite (décalage en y au départ)
    const xR = 12 + IW + 12;
    right.forEach((img, i) => {
      const y = scrollR + i * (IH + GAP) + 70;
      if (y + IH < -10 || y > H + 10) return;
      rr(ctx, xR, y, IW, IH, 12);
      if (img) {
        ctx.save(); ctx.clip();
        ctx.drawImage(img, xR, y, IW, IH);
        ctx.restore();
        const og = ctx.createLinearGradient(0, y+IH-40, 0, y+IH);
        og.addColorStop(0, 'rgba(0,0,0,0)'); og.addColorStop(1, 'rgba(0,0,0,0.6)');
        rr(ctx, xR, y, IW, IH, 12); ctx.fillStyle = og; ctx.fill();
      } else {
        ctx.fillStyle = '#1A1A2E'; ctx.fill();
      }
    });

    // Gradient fond en haut et en bas
    const gTop = ctx.createLinearGradient(0, 0, 0, 90);
    gTop.addColorStop(0, C.bg); gTop.addColorStop(1, 'rgba(6,13,26,0)');
    ctx.fillStyle = gTop; ctx.fillRect(0, 0, W, 90);

    const gBot = ctx.createLinearGradient(0, H-120, 0, H);
    gBot.addColorStop(0, 'rgba(6,13,26,0)'); gBot.addColorStop(1, C.bg);
    ctx.fillStyle = gBot; ctx.fillRect(0, H-120, W, 120);

    // Texte overlay en haut
    const ta = ease(slideAlpha(t, 0.05, 0.18));
    if (ta > 0) {
      ctx.save(); ctx.globalAlpha = ta;
      ctx.font = 'bold 18px sans-serif'; ctx.fillStyle = C.white;
      const title = 'Affiches pub pro';
      ctx.fillText(title, (W - ctx.measureText(title).width) / 2, 38);
      ctx.font = '12px sans-serif'; ctx.fillStyle = C.blue;
      const sub = 'Mode · Beaute · Produits · et plus';
      ctx.fillText(sub, (W - ctx.measureText(sub).width) / 2, 58);
      ctx.restore();
    }

    // Nombre de commandes en bas
    const ca = ease(slideAlpha(t, 0.30, 0.18));
    if (ca > 0) {
      ctx.save(); ctx.globalAlpha = ca;
      rr(ctx, (W-180)/2, H-70, 180, 36, 18);
      ctx.fillStyle = C.blue + '22'; ctx.fill();
      rr(ctx, (W-180)/2, H-70, 180, 36, 18);
      ctx.strokeStyle = C.blue; ctx.lineWidth = 1.5; ctx.stroke();
      ctx.font = 'bold 13px monospace'; ctx.fillStyle = C.blue;
      const badge = '749+ commandes IA';
      ctx.fillText(badge, (W - ctx.measureText(badge).width) / 2, H - 47);
      ctx.restore();
    }

    // Fondu entrée/sortie global
    const fadeIn  = clamp(t / 0.12);
    const fadeOut = clamp((1 - t) / 0.12);
    if (fadeIn < 1) {
      ctx.fillStyle = C.bg;
      ctx.globalAlpha = 1 - fadeIn; ctx.fillRect(0,0,W,H); ctx.globalAlpha = 1;
    }
    if (fadeOut < 1) {
      ctx.fillStyle = C.bg;
      ctx.globalAlpha = 1 - fadeOut; ctx.fillRect(0,0,W,H); ctx.globalAlpha = 1;
    }

    drawSubtitle(ctx, getSub(t * duration)?.t);
    frames.push(frameBuffer(canvas));
  }
  return frames;
}

// ── SCÈNE A : Cards commandes animées (7s) ─────────────────────────
async function renderCommandCards(duration=7, thumbs={}) {
  const N = Math.round(duration*FPS);
  const canvas = createCanvas(W, H);
  const ctx = canvas.getContext('2d');
  const frames = [];
  const cards = [
    { slug:'fashionposter', cmd:'/fashionposter', title:'Affiche de collection', accent:'#A855F7', bg:'#1A0E2E', cat:'MODE' },
    { slug:'menuhero',      cmd:'/menuhero',      title:'Plat vedette du menu',  accent:'#22C55E', bg:'#0A1A0A', cat:'FOOD' },
    { slug:'productglow',   cmd:'/productglow',   title:'Produit en levitation', accent:'#1E9BFF', bg:'#0A1020', cat:'PRODUIT' },
  ];
  for (let f=0; f<N; f++) {
    const t = f/N;
    ctx.fillStyle=C.bg; ctx.fillRect(0,0,W,H);
    ctx.strokeStyle='#FFFFFF06'; ctx.lineWidth=1;
    for (let x=0;x<W;x+=30){ ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,H);ctx.stroke(); }
    for (let y=0;y<H;y+=30){ ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(W,y);ctx.stroke(); }
    drawNavbar(ctx, Math.min(1,t/0.08));
    // Header — plus rapide
    const ta=ease(slideAlpha(t,0.03,0.15));
    ctx.save(); ctx.globalAlpha=ta;
    ctx.font='bold 20px sans-serif'; ctx.fillStyle=C.white;
    const title='Commandes disponibles';
    ctx.fillText(title,(W-ctx.measureText(title).width)/2,90);
    ctx.font='12px sans-serif'; ctx.fillStyle=C.blue;
    const sub='749 prompts IA';
    ctx.fillText(sub,(W-ctx.measureText(sub).width)/2,110);
    ctx.restore();
    // Cards — délais réduits de moitié
    cards.forEach((card,i)=>{
      const ca=ease(slideAlpha(t,0.05+i*0.10,0.18));
      if(ca<=0) return;
      const cH=108, cY0=130+i*(cH+12);
      const cY=cY0+(1-ca)*40, cX=16, cW=W-32;
      ctx.save(); ctx.globalAlpha=ca;
      rr(ctx,cX,cY,cW,cH,14); ctx.fillStyle=card.bg; ctx.fill();
      rr(ctx,cX,cY,4,cH,3); ctx.fillStyle=card.accent; ctx.fill();
      const iX=cX+12, iY=cY+14, iW=78, iH=80;
      rr(ctx,iX,iY,iW,iH,10);
      if (thumbs[card.slug]) {
        ctx.save(); ctx.clip();
        ctx.drawImage(thumbs[card.slug], iX, iY, iW, iH);
        ctx.restore();
      } else {
        ctx.fillStyle=card.accent+'33'; ctx.fill();
        ctx.font='bold 11px monospace'; ctx.fillStyle=card.accent;
        ctx.fillText(card.cmd.slice(1,3).toUpperCase(), iX+22, iY+44);
      }
      ctx.font='9px sans-serif'; ctx.fillStyle=card.accent+'CC';
      ctx.fillText(card.cat, cX+104, cY+28);
      ctx.font='bold 12px monospace'; ctx.fillStyle=card.accent;
      ctx.fillText(card.cmd, cX+104, cY+48);
      ctx.font='11px sans-serif'; ctx.fillStyle=C.grayLight;
      ctx.fillText(card.title, cX+104, cY+65);
      // Bouton copier animé
      const btnPhase = clamp((t - (0.05 + i * 0.10 + 0.25)) / 0.18);
      const btnPulse = 1 + Math.sin(t * Math.PI * 4 + i) * 0.04 * btnPhase;
      const copied = t > (0.05 + i * 0.10 + 0.45);
      rr(ctx,cX+104,cY+76,copied?82:80,21,10);
      ctx.fillStyle = copied ? C.green : C.blue; ctx.fill();
      ctx.font='bold 10px sans-serif'; ctx.fillStyle='#fff';
      const btnLabel = copied ? 'Copie ✓' : 'Copier';
      ctx.fillText(btnLabel, cX+104+(copied?14:18), cY+91);
      ctx.restore();
    });
    drawSubtitle(ctx, getSub(12 + t*duration)?.t);
    frames.push(frameBuffer(canvas));
  }
  return frames;
}

// ── SCÈNE B : Homepage hero + compteur 0→749 (10s) ────────────────
async function renderHomepageHero(duration=10) {
  const N = Math.round(duration*FPS);
  const canvas = createCanvas(W, H);
  const ctx = canvas.getContext('2d');
  const frames = [];
  for (let f=0; f<N; f++) {
    const t = f/N;
    ctx.fillStyle=C.bg; ctx.fillRect(0,0,W,H);
    const grad=ctx.createLinearGradient(0,0,W,H);
    grad.addColorStop(0,'#060D1A'); grad.addColorStop(0.5,'#0A1628'); grad.addColorStop(1,'#060D1A');
    ctx.fillStyle=grad; ctx.fillRect(0,0,W,H);
    const pulse=0.8+Math.sin(t*Math.PI*2)*0.2;
    ctx.save(); ctx.globalAlpha=0.07*pulse;
    ctx.beginPath(); ctx.arc(W*0.7,H*0.28,120,0,Math.PI*2);
    ctx.fillStyle=C.blue; ctx.fill();
    ctx.beginPath(); ctx.arc(W*0.2,H*0.55,80,0,Math.PI*2);
    ctx.fillStyle='#A855F7'; ctx.fill();
    ctx.restore();
    drawNavbar(ctx,1);
    // Textes hero — délais réduits
    const heroLines=[
      {text:'Copiez.', delay:0.04, color:C.white},
      {text:'Creez.',  delay:0.10, color:C.blue},
    ];
    let yH=150;
    heroLines.forEach(({text,delay,color})=>{
      const la=ease(slideAlpha(t,delay,0.16));
      if(la<=0){yH+=56;return;}
      ctx.save(); ctx.globalAlpha=la;
      ctx.font='bold 48px sans-serif'; ctx.fillStyle=color;
      ctx.fillText(text, 22+(1-la)*-30, yH);
      ctx.restore(); yH+=56;
    });
    const sta=ease(slideAlpha(t,0.18,0.16));
    if(sta>0){
      ctx.save(); ctx.globalAlpha=sta;
      ctx.font='13px sans-serif'; ctx.fillStyle=C.grayLight;
      ctx.fillText('749 prompts IA prets a copier-coller', 22, yH+10);
      ctx.restore();
    }
    // Compteur — démarre plus tôt
    if(t>0.24){
      const ct=ease(clamp((t-0.24)/0.4));
      const count=Math.round(ct*749);
      ctx.save();
      rr(ctx,22,H*0.55,W-44,100,16); ctx.fillStyle=C.bgCard; ctx.fill();
      rr(ctx,22,H*0.55,W-44,100,16);
      ctx.strokeStyle=C.blue+'44'; ctx.lineWidth=1; ctx.stroke();
      ctx.font='bold 50px sans-serif'; ctx.fillStyle=C.blue;
      const ns=String(count); ctx.fillText(ns,(W-ctx.measureText(ns).width)/2,H*0.55+64);
      ctx.font='12px sans-serif'; ctx.fillStyle=C.gray;
      const label='commandes IA disponibles';
      ctx.fillText(label,(W-ctx.measureText(label).width)/2,H*0.55+85);
      ctx.restore();
    }
    const uba=ease(slideAlpha(t,0.68,0.18));
    if(uba>0){
      ctx.save(); ctx.globalAlpha=uba;
      rr(ctx,(W-200)/2,H-100,200,36,18); ctx.fillStyle=C.blue+'22'; ctx.fill();
      rr(ctx,(W-200)/2,H-100,200,36,18); ctx.strokeStyle=C.blue; ctx.lineWidth=1.5; ctx.stroke();
      ctx.font='bold 15px monospace'; ctx.fillStyle=C.blue;
      const url='slashatlas.com';
      ctx.fillText(url,(W-ctx.measureText(url).width)/2,H-76);
      ctx.restore();
    }
    drawSubtitle(ctx, getSub(26 + t*duration)?.t);
    frames.push(frameBuffer(canvas));
  }
  return frames;
}

// ── SCÈNE C : Workflow prompt→résultat (9s) ───────────────────────
async function renderWorkflow(duration=9, afterImg=null) {
  const N = Math.round(duration*FPS);
  const canvas = createCanvas(W, H);
  const ctx = canvas.getContext('2d');
  const frames = [];
  for (let f=0; f<N; f++) {
    const t = f/N;
    ctx.fillStyle=C.bg; ctx.fillRect(0,0,W,H);
    drawNavbar(ctx,1);
    // Titre — plus rapide
    ctx.save(); ctx.globalAlpha=ease(slideAlpha(t,0.03,0.12));
    ctx.font='bold 18px sans-serif'; ctx.fillStyle=C.white;
    const title='Comment utiliser les prompts ?';
    ctx.fillText(title,(W-ctx.measureText(title).width)/2,90);
    ctx.restore();
    // Étape 1 : commande à copier
    const s1=ease(slideAlpha(t,0.06,0.15));
    if(s1>0){
      ctx.save(); ctx.globalAlpha=s1;
      rr(ctx,22,112,W-44,76,14); ctx.fillStyle=C.bgCard; ctx.fill();
      rr(ctx,22,112,W-44,76,14); ctx.strokeStyle=C.blue+'88'; ctx.lineWidth=1.5; ctx.stroke();
      ctx.font='bold 13px monospace'; ctx.fillStyle=C.blue; ctx.fillText('/fashionposter',38,142);
      ctx.font='11px sans-serif'; ctx.fillStyle=C.grayLight; ctx.fillText('Affiche de collection mode',38,160);
      // Bouton copier avec animation clic
      const clickPhase = clamp((t - 0.22) / 0.15);
      const wasCopied = t > 0.36;
      const btnW = wasCopied ? 78 : 66;
      rr(ctx,W-102,126,btnW,22,11);
      ctx.fillStyle = wasCopied ? C.green : C.blue+'CC'; ctx.fill();
      ctx.font='bold 10px sans-serif'; ctx.fillStyle='#fff';
      ctx.fillText(wasCopied ? 'Copie ✓' : 'Copier', W-88, 141);
      // Curseur animé qui va vers le bouton
      if (t > 0.14 && t < 0.38) {
        const cp = ease(clamp((t - 0.14) / 0.20));
        const cx = 22 + (W - 22 - 90) * cp;
        const cy = 130 + (137 - 130) * cp;
        ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(cx+10, cy+14); ctx.lineTo(cx+4, cy+14);
        ctx.lineTo(cx+4, cy+20); ctx.lineTo(cx+2, cy+20); ctx.lineTo(cx+2, cy+14);
        ctx.lineTo(cx-2, cy+14); ctx.closePath();
        ctx.fillStyle = '#fff'; ctx.fill();
      }
      ctx.restore();
    }
    // Flèche
    const arrow=ease(slideAlpha(t,0.26,0.14));
    if(arrow>0){
      ctx.save(); ctx.globalAlpha=arrow;
      ctx.strokeStyle=C.blue; ctx.lineWidth=2; ctx.setLineDash([5,4]);
      ctx.beginPath(); ctx.moveTo(W/2,198); ctx.lineTo(W/2,234); ctx.stroke();
      ctx.setLineDash([]);
      ctx.beginPath(); ctx.moveTo(W/2-8,234); ctx.lineTo(W/2,246); ctx.lineTo(W/2+8,234);
      ctx.fillStyle=C.blue; ctx.fill();
      ctx.font='10px sans-serif'; ctx.fillStyle=C.blue;
      const pt='Collez dans Midjourney, DALL-E...';
      ctx.fillText(pt,(W-ctx.measureText(pt).width)/2,220);
      ctx.restore();
    }
    // Étape 2 : terminal IA
    const s2=ease(slideAlpha(t,0.32,0.15));
    if(s2>0){
      ctx.save(); ctx.globalAlpha=s2;
      rr(ctx,22,256,W-44,98,14); ctx.fillStyle=C.bgCard2; ctx.fill();
      ctx.font='bold 12px sans-serif'; ctx.fillStyle=C.white; ctx.fillText('Midjourney / DALL-E / Stable D.',36,278);
      rr(ctx,32,286,W-64,42,8); ctx.fillStyle='#0A1628'; ctx.fill();
      ctx.font='9px monospace'; ctx.fillStyle='#22C55E88';
      ctx.fillText('/fashionposter woman in kente cloth...',40,302);
      ctx.fillText('style afro, professional lighting...',40,315);
      // Bouton générer avec barre de progression
      rr(ctx,32,332,86,24,12); ctx.fillStyle='#22C55E'; ctx.fill();
      ctx.font='bold 10px sans-serif'; ctx.fillStyle='#fff'; ctx.fillText('Generer ->',46,348);
      // Barre de progression si assez avancé
      if (t > 0.52) {
        const prog = ease(clamp((t - 0.52) / 0.30));
        rr(ctx,32,360,W-64,6,3); ctx.fillStyle='#22C55E22'; ctx.fill();
        rr(ctx,32,360,Math.max(6,(W-64)*prog),6,3); ctx.fillStyle='#22C55E'; ctx.fill();
      }
      ctx.restore();
    }
    // Résultat image
    const s3=ease(slideAlpha(t,0.47,0.18));
    if(s3>0){
      ctx.save(); ctx.globalAlpha=s3;
      const px=(W-110)/2, py=380, pw=110, ph=130;
      rr(ctx,px-4,py-4,pw+8,ph+8,14); ctx.fillStyle='#1A1A2E'; ctx.fill();
      rr(ctx,px,py,pw,ph,10);
      if (afterImg) {
        ctx.save(); ctx.clip();
        ctx.drawImage(afterImg, px, py, pw, ph);
        ctx.restore();
      } else {
        const pg=ctx.createLinearGradient(px,py,px+pw,py+ph);
        pg.addColorStop(0,'#2D1A4E'); pg.addColorStop(0.5,'#1A2D4E'); pg.addColorStop(1,'#4E1A2D');
        ctx.fillStyle=pg; ctx.fill();
        ctx.font='bold 9px sans-serif'; ctx.fillStyle=C.amber; ctx.fillText('NEW COLLECTION',px+8,py+20);
        ctx.font='bold 11px sans-serif'; ctx.fillStyle='#fff'; ctx.fillText('KENZO AFRO',px+28,py+36);
      }
      rr(ctx,px,py+ph-22,pw,22,0); ctx.fillStyle='rgba(0,0,0,0.55)'; ctx.fill();
      ctx.font='bold 9px sans-serif'; ctx.fillStyle=C.amber;
      const rl='Resultat IA'; ctx.fillText(rl, px+(pw-ctx.measureText(rl).width)/2, py+ph-8);
      ctx.restore();
    }
    drawSubtitle(ctx, getSub(36 + t*duration)?.t);
    frames.push(frameBuffer(canvas));
  }
  return frames;
}

// ── SCÈNE D : CTA finale animée (9.5s) ───────────────────────────
async function renderCTA(duration=9.5) {
  const N = Math.round(duration*FPS);
  const canvas = createCanvas(W, H);
  const ctx = canvas.getContext('2d');
  const frames = [];
  for (let f=0; f<N; f++) {
    const t = f/N;
    const pulse=1+Math.sin(t*Math.PI*6)*0.012;
    ctx.fillStyle=C.bg; ctx.fillRect(0,0,W,H);
    const g=ctx.createRadialGradient(W/2,H*0.45,0,W/2,H*0.45,240);
    g.addColorStop(0,'#0A1628'); g.addColorStop(1,C.bg);
    ctx.fillStyle=g; ctx.fillRect(0,0,W,H);
    [150,205,260].forEach((r,i)=>{
      const alpha=(0.04+Math.sin(t*Math.PI*2+i)*0.02)*Math.min(1,t/0.3);
      ctx.save(); ctx.globalAlpha=alpha;
      ctx.beginPath(); ctx.arc(W/2,H*0.42,r*pulse,0,Math.PI*2);
      ctx.strokeStyle=C.blue; ctx.lineWidth=1; ctx.stroke();
      ctx.restore();
    });
    const la=ease(slideAlpha(t,0.04,0.16));
    ctx.save(); ctx.globalAlpha=la;
    ctx.font='bold 18px monospace'; ctx.fillStyle=C.blue;
    const logo='/ SlashAtlas';
    ctx.fillText(logo,(W-ctx.measureText(logo).width)/2,H*0.32);
    ctx.restore();
    const ea=ease(slideAlpha(t,0.12,0.16));
    ctx.save(); ctx.globalAlpha=ea;
    ctx.font=`bold ${Math.round(24*pulse)}px sans-serif`; ctx.fillStyle=C.white;
    const et='Copiez. Creez.';
    ctx.fillText(et,(W-ctx.measureText(et).width)/2,H*0.41);
    ctx.font='13px sans-serif'; ctx.fillStyle=C.grayLight;
    const et2='749 prompts IA disponibles';
    ctx.fillText(et2,(W-ctx.measureText(et2).width)/2,H*0.41+22);
    ctx.restore();
    const urlA=ease(slideAlpha(t,0.24,0.14));
    if(urlA>0){
      ctx.save(); ctx.globalAlpha=urlA;
      const fullUrl='slashatlas.com';
      const chars=Math.ceil(fullUrl.length*Math.min(1,(t-0.24)/0.25));
      const dispUrl=fullUrl.slice(0,chars);
      rr(ctx,(W-220)/2,H*0.48-8,220,44,22); ctx.fillStyle=C.blue+'18'; ctx.fill();
      rr(ctx,(W-220)/2,H*0.48-8,220,44,22); ctx.strokeStyle=C.blue; ctx.lineWidth=1.5; ctx.stroke();
      ctx.font='bold 22px monospace'; ctx.fillStyle=C.blue;
      const uw=ctx.measureText(dispUrl).width;
      ctx.fillText(dispUrl,(W-uw)/2,H*0.48+20);
      if(chars<fullUrl.length){ ctx.fillStyle=C.white; ctx.fillText('|',(W+uw)/2+2,H*0.48+20); }
      ctx.restore();
    }
    const ba=ease(slideAlpha(t,0.44,0.18));
    if(ba>0){
      ctx.save(); ctx.globalAlpha=ba;
      rr(ctx,50,H*0.63,108,34,17); ctx.fillStyle=C.green+'22'; ctx.fill();
      rr(ctx,50,H*0.63,108,34,17); ctx.strokeStyle=C.green+'88'; ctx.lineWidth=1; ctx.stroke();
      ctx.font='bold 11px sans-serif'; ctx.fillStyle=C.green;
      const fw=ctx.measureText('Gratuit').width;
      ctx.fillText('Gratuit',50+(108-fw)/2,H*0.63+22);
      rr(ctx,W-168,H*0.63,128,34,17); ctx.fillStyle='#A855F7'+'22'; ctx.fill();
      rr(ctx,W-168,H*0.63,128,34,17); ctx.strokeStyle='#A855F7'+'88'; ctx.lineWidth=1; ctx.stroke();
      ctx.font='bold 11px sans-serif'; ctx.fillStyle='#A855F7';
      const bw=ctx.measureText('Abonnez-vous').width;
      ctx.fillText('Abonnez-vous',W-168+(128-bw)/2,H*0.63+22);
      ctx.restore();
    }
    const suba=ease(slideAlpha(t,0.60,0.18));
    if(suba>0){
      ctx.save(); ctx.globalAlpha=suba;
      rr(ctx,(W-220)/2,H*0.76,220,38,19); ctx.fillStyle=C.blue; ctx.fill();
      ctx.font='bold 14px sans-serif'; ctx.fillStyle='#fff';
      const vt='Visiter slashatlas.com';
      ctx.fillText(vt,(W-ctx.measureText(vt).width)/2,H*0.76+24);
      ctx.restore();
    }
    const suba2=ease(slideAlpha(t,0.74,0.14));
    if(suba2>0){
      ctx.save(); ctx.globalAlpha=suba2*0.7;
      ctx.font='12px sans-serif'; ctx.fillStyle=C.grayLight;
      const st='Lien en bio · Abonnez-vous';
      ctx.fillText(st,(W-ctx.measureText(st).width)/2,H*0.88);
      ctx.restore();
    }
    drawSubtitle(ctx, getSub(48 + t*duration)?.t);
    frames.push(frameBuffer(canvas));
  }
  return frames;
}

// ═══════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════
(async () => {
  console.log('\n🎬 Montage promo SlashAtlas v2 — Motion Design\n');
  const seg = n => path.join(TMP, `v2seg_${n}.mp4`);

  fs.writeFileSync(path.join(TMP,'v2swoosh.wav'), pcmToWav(genSwoosh(350)));

  // ── Préchargement images ──────────────────────────────────────────
  process.stdout.write('  Chargement images catalogue…           ');
  const thumbs = {};
  for (const slug of ['fashionposter','menuhero','productglow']) {
    try { thumbs[slug] = await loadImage(path.join(IMG_DIR, slug+'-t.webp')); } catch(e) { console.warn('  img manquante:', slug); }
  }
  let afterImg = null;
  try { afterImg = await loadImage(path.join(IMG_DIR, 'fashionposter-apres.webp')); } catch(e) {}
  // Images showcase beauté/produits
  const showcaseSlugs = [
    'fashionposter-apres', 'editdress-apres', 'salonambiance-apres',
    'jewelmodel-apres', 'luxury-apres', 'productshot-apres',
  ];
  const showcaseImgs = [];
  for (const slug of showcaseSlugs) {
    try { showcaseImgs.push(await loadImage(path.join(IMG_DIR, slug+'.webp'))); }
    catch(e) { showcaseImgs.push(null); }
  }
  console.log('✓ (' + Object.keys(thumbs).length + ' thumbs, ' + showcaseImgs.filter(Boolean).length + ' showcase)');

  // ── Segments vidéo ────────────────────────────────────────────────
  process.stdout.write('  [0/8] Showcase beaute/produits (5s)…   ');
  await encodeFrames(await renderShowcase(5, showcaseImgs), seg(0));
  console.log('✓');

  // Seg 1 : face cam intro — pas de fadeIn (début), fadeOut oui
  process.stdout.write('  [1/8] Face cam intro (0-7s)…           ');
  trimFaceCam(seg(1), 0, 7, false, true);
  console.log('✓');

  process.stdout.write('  [2/8] Cards commandes (7s)…            ');
  await encodeFrames(await renderCommandCards(7, thumbs), seg(2));
  console.log('✓');

  process.stdout.write('  [3/8] Face cam solution (14-21s)…      ');
  trimFaceCam(seg(3), 14, 7, true, true);
  console.log('✓');

  process.stdout.write('  [4/8] Homepage + compteur (10s)…       ');
  await encodeFrames(await renderHomepageHero(10), seg(4));
  console.log('✓');

  process.stdout.write('  [5/8] Workflow prompt->affiche (9s)…   ');
  await encodeFrames(await renderWorkflow(9, afterImg), seg(5));
  console.log('✓');

  // Seg 6 : face cam outro — fadeIn oui, fadeOut oui
  process.stdout.write('  [6/8] Face cam outro (40-43s)…         ');
  trimFaceCam(seg(6), 40, 3, true, true);
  console.log('✓');

  process.stdout.write('  [7/8] CTA finale (9.5s)…               ');
  await encodeFrames(await renderCTA(9.5), seg(7));
  console.log('✓');

  // ── Audio continu — voix extraite en une seule passe ─────────────
  // Structure : silence(5) + voix(7) + silence(7) + voix(7) + silence(19) + voix(3) + silence(9.5)
  // = 57.5s total, synchronisé avec les 8 segments

  process.stdout.write('\n  Audio: extraction voix 0-43s…         ');
  const voiceFull = path.join(TMP, 'v2voice_full.aac');
  const rVoice = spawnSync(FFMPEG, [
    '-y', '-ss', '0', '-t', '43', '-i', USER_VIDEO,
    '-vn', '-c:a', 'aac', '-b:a', '128k', voiceFull,
  ], {stdio:'pipe'});
  if (rVoice.status !== 0) throw new Error(rVoice.stderr.toString().slice(-400));
  console.log('✓');

  // Silence 14.5s pour couvrir cards+hero+workflow+CTA (canvas sans voix après la face cam)
  process.stdout.write('  Audio: silence fin (14.5s)…            ');
  const silEnd = path.join(TMP, 'v2sil_end.aac');
  const rS1 = spawnSync(FFMPEG, [
    '-y','-f','lavfi','-i',`anullsrc=channel_layout=stereo:sample_rate=${SR}`,
    '-t','14.5','-c:a','aac','-b:a','128k', silEnd,
  ], {stdio:'pipe'});
  if (rS1.status !== 0) throw new Error(rS1.stderr.toString().slice(-400));
  console.log('✓');

  // Concat : voix43s + silence14.5s = 57.5s — la voix démarre dès le showcase
  process.stdout.write('  Audio: assemblage 57.5s…               ');
  const voice575 = path.join(TMP, 'v2voice_575.aac');
  const rConcat = spawnSync(FFMPEG, [
    '-y', '-i', voiceFull, '-i', silEnd,
    '-filter_complex', '[0:a][1:a]concat=n=2:v=0:a=1[aout]',
    '-map', '[aout]', '-c:a', 'aac', '-b:a', '128k', voice575,
  ], {stdio:'pipe'});
  if (rConcat.status !== 0) throw new Error(rConcat.stderr.toString().slice(-400));
  console.log('✓');

  // Ambiance musicale
  process.stdout.write('  Audio: generation ambiance…            ');
  const ambientWav = path.join(TMP, 'v2ambient.wav');
  fs.writeFileSync(ambientWav, pcmToWav(genAmbient(58)));
  console.log('✓');

  // Mixage voix + ambiance (voix dominant, ambiance douce)
  process.stdout.write('  Audio: mixage voix + ambiance…         ');
  const audioFinal = path.join(TMP, 'v2audio_final.aac');
  const rMix = spawnSync(FFMPEG, [
    '-y', '-i', voice575, '-i', ambientWav,
    '-filter_complex', 'amix=inputs=2:duration=first:weights=1 0.18',
    '-c:a', 'aac', '-b:a', '128k', audioFinal,
  ], {stdio:'pipe'});
  if (rMix.status !== 0) throw new Error(rMix.stderr.toString().slice(-400));
  console.log('✓');

  // ── Concat vidéo finale (8 segments) ─────────────────────────────
  process.stdout.write('  Assemblage video final (8 segs)…       ');
  const N_segs = 8;
  const videoInputs = Array.from({length:N_segs},(_,i)=>['-i',seg(i)]).flat();
  const vConcatFilter = Array.from({length:N_segs},(_,i)=>`[${i}:v]`).join('')+
    `concat=n=${N_segs}:v=1:a=0[vout]`;

  await new Promise((resolve,reject) => {
    const ff = spawn(FFMPEG, [
      '-y',
      ...videoInputs,
      '-i', audioFinal,
      '-filter_complex', vConcatFilter,
      '-map','[vout]',
      '-map',`${N_segs}:a`,
      '-c:v','libx264','-preset','fast','-crf','20','-pix_fmt','yuv420p',
      '-c:a','aac','-b:a','128k',
      '-shortest','-movflags','+faststart',
      OUT_VIDEO,
    ], {stdio:['pipe','pipe','pipe']});
    let e='';
    ff.stderr.on('data', d=>e+=d);
    ff.on('close', c=>c===0 ? resolve() : reject(new Error(e.slice(-600))));
  });
  console.log('✓');
  console.log(`\n  Video prete -> ${OUT_VIDEO}\n`);
})().catch(err => { console.error('\n  Erreur:', err.message); process.exit(1); });
