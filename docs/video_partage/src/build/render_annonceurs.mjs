// Montage de la vidéo « Partage et gagne » : chaque animation part d'un MOT précis de la voix (instants relevés par reconnaissance vocale, voir align.py),
// scènes dessinées dans Chrome image par image, assemblage par ffmpeg.
// Usage : node render.mjs <sans|avec> [instants de test séparés par des virgules]   (avec instants : images PNG de contrôle seulement)
import puppeteer from 'puppeteer-core';
import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..', '..', '..', 'video_annonceurs');
const tests = process.argv[2] ? process.argv[2].split(',').map(Number) : null;
const version = 'annonceurs';
const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const FPS = 30, LEAD = 0.35, TAIL = 0.9;
const run = (cmd, args) => { const r = spawnSync(cmd, args, { encoding: 'utf8' }); if (r.status !== 0) throw new Error(`${cmd} a échoué :
${r.stderr}`); return r.stdout; };

// ── mots de la voix ──
const norm = s => s.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-z0-9]/g, '');
const lev = (a, b) => { const d = Array.from({ length: a.length + 1 }, (_, i) => [i, ...Array(b.length).fill(0)]); for (let j = 1; j <= b.length; j++) d[0][j] = j; for (let i = 1; i <= a.length; i++) for (let j = 1; j <= b.length; j++) d[i][j] = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + (a[i - 1] === b[j - 1] ? 0 : 1)); return d[a.length][b.length]; };
const { duree, mots } = JSON.parse(fs.readFileSync(path.join(root, 'sortie', `mots_${version}.json`), 'utf8'));
const script = norm(fs.readFileSync(path.join(root, 'src', 'script.txt'), 'utf8'));

const ANCRES = [
  ['etudiants', ['etudiants', 'etudiant']], ['moteur', ['moteur']], ['garage', ['garage']], ['google', ['google']], ['publicite', ['publicite']], ['idee', ['idee', 'idees']], ['montrer', ['montrer']],
  ['startup', ['startup', 'startups', 'startap']], ['entreprise', ['entreprise']], ['boutique', ['boutique']], ['site', ['site']], ['application', ['application']], ['afrique', ['afrique']],
  ['ads', ['ads', 'lucades', 'ad']], ['partagee', ['partagee', 'partage']], ['whatsapp', ['whatsapp']], ['facebook', ['facebook']], ['instagram', ['instagram']], ['telegram', ['telegram']],
  ['audience', ['audience']], ['budget', ['budget']], ['cinq', ['5000', 'cinq', '5']], ['dix', ['10', 'dix']], ['pas', ['pas']], ['gratuite', ['gratuite']], ['quatorze', ['14', 'quatorze']],
  ['rends', ['rends', 'rente', 'rend']], ['ads2', ['ads', 'ad']], ['lance', ['lance', 'lancer']],
];
const cues = {}, trace = [];
let cur = 0, scriptPos = 0;
for (const [nom, variantes] of ANCRES) {
  let found = -1;
  for (let i = cur; i < mots.length && found < 0; i++) {
    const w = norm(mots[i].w);
    if (variantes.includes(w) || (variantes[0].length >= 5 && lev(w, variantes[0]) <= 1)) found = i;
  }
  const sp = script.indexOf(variantes[0], scriptPos);
  if (found >= 0) { cues[nom] = mots[found].s + LEAD; cur = found + 1; trace.push(`${nom}=${cues[nom].toFixed(2)} (« ${mots[found].w} »)`); }
  else { cues[nom] = LEAD + duree * (Math.max(sp, 0) / script.length); trace.push(`${nom}=${cues[nom].toFixed(2)} (ESTIMÉ)`); }
  if (sp >= 0) scriptPos = sp + 1;
}
console.log(trace.join('  '));

// ── scènes ──
const total = LEAD + duree + TAIL;
const C = cues;
const defs = [['histoire', 0], ['cibles', C.startup - 0.5], ['diffusion', C.ads - 0.55], ['controle', C.audience - 0.5], ['prix', C.cinq - 0.65], ['gratuit', C.pas - 0.3], ['final', C.rends - 0.55]];
const scenes = defs.map(([id, start], i) => ({ id, start: Math.max(0, start), end: i + 1 < defs.length ? Math.max(0, defs[i + 1][1]) : total }));
for (let i = 1; i < scenes.length; i++) if (scenes[i].end - scenes[i].start < 1.0) console.log(`ATTENTION : scène « ${scenes[i].id} » très courte (${(scenes[i].end - scenes[i].start).toFixed(2)} s)`);
const TL = { version, total, lead: LEAD, cues, scenes };
console.log(`Vidéo annonceurs : ${total.toFixed(1)} s. Scènes : ` + scenes.map(s => `${s.id} ${s.start.toFixed(1)}→${s.end.toFixed(1)}`).join(' | '));

// ── bande son : la voix d'une seule traite, décalée de LEAD ──
const voice = path.join(root, 'sortie', `voix_montage_${version}.wav`);
if (!tests) run('ffmpeg', ['-y', '-i', path.join(root, 'sortie', `voix_complete_${version}.wav`), '-af', `adelay=${Math.round(LEAD * 1000)}|${Math.round(LEAD * 1000)},apad=whole_dur=${total.toFixed(3)},loudnorm=I=-16:TP=-1.5:LRA=11`, '-ar', '44100', '-ac', '1', '-c:a', 'pcm_s16le', voice]);

// ── images ──
const browser = await puppeteer.launch({ executablePath: CHROME, headless: 'new', args: ['--no-sandbox', '--hide-scrollbars', '--allow-file-access-from-files', '--font-render-hinting=none'], defaultViewport: { width: 720, height: 1280, deviceScaleFactor: 1 } });
const page = await browser.newPage();
await page.evaluateOnNewDocument(tl => { window.TL = tl; }, TL);
page.on('pageerror', e => console.log('Erreur page :', e.message));
page.on('console', m => { if (m.type() === 'error') console.log('Console :', m.text()); });
await page.goto(pathToFileURL(path.join(root, 'src', 'index.html')).href, { waitUntil: 'load' });
await page.evaluate(() => window.render(0));
await page.evaluate(() => Promise.all([...document.images].map(i => (i.decode ? i.decode().catch(() => {}) : Promise.resolve()))));
await page.evaluate(() => document.fonts.ready);

if (tests) {
  for (const x of tests) {
    await page.evaluate(v => window.render(v), x);
    await page.screenshot({ path: path.join(root, 'sortie', `test_${version}_${x.toFixed(1)}.png`), type: 'png' });
  }
  console.log('Images de contrôle écrites :', tests.join(', '));
  await browser.close();
  process.exit(0);
}

const frames = path.join(root, 'sortie', `_images_${version}`);
fs.rmSync(frames, { recursive: true, force: true }); fs.mkdirSync(frames, { recursive: true });
const n = Math.ceil(total * FPS);
for (let i = 0; i < n; i++) {
  await page.evaluate(v => window.render(v), i / FPS);
  await page.screenshot({ path: path.join(frames, String(i).padStart(5, '0') + '.jpg'), type: 'jpeg', quality: 92 });
  if (i % 200 === 0) console.log(`  image ${i}/${n}`);
}
await browser.close();

// ── assemblage : H.264 léger, son AAC ──
const out = path.join(root, 'sortie', 'afrolook_ads_appel_annonceurs.mp4');
run('ffmpeg', ['-y', '-framerate', String(FPS), '-i', path.join(frames, '%05d.jpg'), '-i', voice, '-c:v', 'libx264', '-preset', 'slow', '-crf', '26', '-pix_fmt', 'yuv420p', '-profile:v', 'high', '-r', String(FPS),
  '-c:a', 'aac', '-b:a', '112k', '-movflags', '+faststart', '-shortest', out]);
fs.rmSync(frames, { recursive: true, force: true });
console.log(`Vidéo : ${out} (${(fs.statSync(out).size / 1048576).toFixed(1)} Mo)`);
