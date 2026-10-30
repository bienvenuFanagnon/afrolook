// Fabrique les affiches et les images d'aperçu de lien d'Afrolook Ads (PNG) : node affiches/make.mjs
// Rendu par Microsoft Edge (ou Chrome) en mode sans fenêtre, avec les polices du site. Sortie : static/img/ads/*.png
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(here, '..');
const OUT = path.join(root, 'static', 'img', 'ads');
const BROWSERS = ['C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', 'C:/Program Files/Microsoft/Edge/Application/msedge.exe', 'C:/Program Files/Google/Chrome/Application/chrome.exe'];
const browser = BROWSERS.find((b) => fs.existsSync(b));
if (!browser) throw new Error('Edge ou Chrome introuvable');

const fontsUrl = pathToFileURL(path.join(root, 'static', 'fonts')).href;
const fontCss = fs.readFileSync(path.join(root, 'src', 'fonts.css'), 'utf8').replaceAll('url(/fonts/', `url(${fontsUrl}/`);
const logo = pathToFileURL(path.join(root, 'static', 'img', 'logo.webp')).href;

const CSS = `${fontCss}
*{box-sizing:border-box;margin:0}
:root{--bg:#0B110D;--soft:#17221A;--ink:#F1F6F0;--muted:#9DAAA0;--g:#2ECC71;--y:#FFD21F;--r:#E5484D;--on:#06210F}
html,body{background:var(--bg);color:var(--ink);font-family:'Figtree',system-ui,sans-serif;-webkit-font-smoothing:antialiased}
h1,h2,b.d{font-family:'Bricolage Grotesque',system-ui,sans-serif;letter-spacing:-.02em}
.p{position:relative;overflow:hidden;background:radial-gradient(900px 600px at 85% -10%,rgba(46,204,113,.28),transparent 60%),radial-gradient(700px 500px at -10% 105%,rgba(255,210,31,.16),transparent 60%),var(--bg)}
.tri{position:absolute;left:0;right:0;top:0;height:14px;background:linear-gradient(90deg,var(--g) 0 60%,var(--y) 60% 85%,var(--r) 85%)}
.brand{display:flex;align-items:center;gap:14px;font:800 34px 'Bricolage Grotesque',sans-serif}.brand img{width:52px;height:52px;border-radius:14px}.brand i{font-style:normal;color:var(--g)}
.brand span{font:800 20px 'Figtree';letter-spacing:.12em;color:var(--on);background:var(--y);padding:5px 12px;border-radius:99px}
.kick{display:inline-block;font:800 24px 'Figtree';letter-spacing:.14em;text-transform:uppercase;color:var(--on);background:var(--g);padding:9px 20px;border-radius:99px}
h1 em{font-style:normal;color:var(--y)}
.pill{display:inline-block;font:800 36px 'Bricolage Grotesque';background:var(--g);color:var(--on);padding:18px 38px;border-radius:99px}
.fine{color:var(--muted);font-size:22px;line-height:1.4}
.pts{list-style:none;padding:0;display:grid;gap:14px}.pts li{display:flex;gap:16px;align-items:flex-start;font:600 30px/1.25 'Figtree'}.pts i{flex:0 0 40px;height:40px;border-radius:12px;background:rgba(46,204,113,.18);color:var(--g);display:grid;place-items:center;font:800 24px 'Figtree';font-style:normal}
.ad{background:linear-gradient(135deg,#0f9d58,#f5b800);color:#fff;border-radius:34px;display:grid;place-items:center;align-content:center;text-align:center;gap:6px;box-shadow:0 30px 70px rgba(0,0,0,.45);position:relative}
.ad b{font:900 120px/1 'Bricolage Grotesque'}.ad span{font:700 36px 'Figtree'}.ad u{text-decoration:none;background:#fff;color:#0b6b3a;font:800 30px 'Figtree';padding:10px 30px;border-radius:99px;margin-top:10px}
.chip{position:absolute;background:var(--ink);color:#0B110D;font:800 26px 'Figtree';padding:12px 22px;border-radius:99px;box-shadow:0 14px 34px rgba(0,0,0,.4)}
.big{font:900 150px/.95 'Bricolage Grotesque';color:var(--y)}
.steps{display:grid;gap:14px}.steps div{display:flex;gap:18px;align-items:center;background:var(--soft);border:1px solid #233028;border-radius:22px;padding:18px 22px;font:700 30px 'Figtree'}.steps b{flex:0 0 52px;height:52px;border-radius:16px;background:var(--g);color:var(--on);display:grid;place-items:center;font:900 30px 'Bricolage Grotesque'}
`;

const brandOf = (ads = true) => `<div class="brand"><img src="${logo}" alt=""><div>afro<i>look</i></div>${ads ? '<span>ADS</span>' : ''}</div>`;
const brand = brandOf(true), brandJobs = brandOf(false);
const html = (w, h, body) => `<!doctype html><html lang="fr"><head><meta charset="utf-8"><style>${CSS}html,body{width:${w}px;height:${h}px;overflow:hidden}.p{width:${w}px;height:${h}px}</style></head><body><div class="p"><div class="tri"></div>${body}</div></body></html>`;

// ───────── affiche 1080 × 1350 : annonceurs, Campagne Partage ─────────
const posterAnnonceurs = html(1080, 1350, `
 <div style="position:absolute;left:70px;top:70px">${brand}</div>
 <div style="position:absolute;left:70px;top:190px;width:940px">
  <span class="kick">Campagne Partage</span>
  <h1 style="font-size:100px;line-height:1.02;margin-top:26px">Fais <em>partager</em> ton annonce par de vraies personnes.</h1>
  <p style="font:600 34px/1.3 'Figtree';color:var(--muted);margin-top:22px">Statuts et groupes WhatsApp, Telegram, Facebook, TikTok.</p>
 </div>
 <div class="ad" style="position:absolute;right:60px;top:720px;width:350px;height:350px;transform:rotate(4deg)"><b>-30 %</b><span>Boutique Kofi</span><u>Commande</u><div class="chip" style="left:-70px;top:34px;transform:rotate(-6deg)">+1 clic valide</div></div>
 <ul class="pts" style="position:absolute;left:70px;top:740px;width:540px">
  <li><i>1</i>Tu paies l'audience que tu veux atteindre</li>
  <li><i>2</i>Des partageurs validés par notre équipe</li>
  <li><i>3</i>Seuls les clics valides sont comptés</li>
 </ul>
 <div style="position:absolute;left:70px;right:70px;bottom:70px;display:grid;gap:18px;justify-items:start">
  <span class="pill">afrolookmedia.com/ads/</span>
  <p class="fine">Annonces gratuites aussi sur Afrolook, SlashAtlas, Pronoflash et Épargne+.</p>
 </div>`);

// ───────── affiche 1080 × 1350 : partageurs, jobs et tâches Afrolook ─────────
const posterJobs = html(1080, 1350, `
 <div style="position:absolute;left:70px;top:70px">${brandJobs}</div>
 <div style="position:absolute;left:70px;top:190px;width:940px">
  <span class="kick">Jobs et tâches Afrolook</span>
  <h1 style="font-size:100px;line-height:1.02;margin-top:26px">Gagne de l'argent en <em>partageant</em> des annonces.</h1>
 </div>
 <div style="position:absolute;left:70px;top:610px;width:940px">
  <div class="big">5 F</div>
  <p style="font:700 38px/1.25 'Figtree';margin-top:10px">par clic valide, jusqu'à 500 F par jour</p>
 </div>
 <div class="steps" style="position:absolute;left:70px;top:860px;width:940px">
  <div><b>1</b>Crée ton profil, notre équipe le valide</div>
  <div><b>2</b>Partage une annonce où tu veux</div>
  <div><b>3</b>Gagne au clic valide, retire en argent réel</div>
 </div>
 <div style="position:absolute;left:70px;right:70px;bottom:62px;display:flex;justify-content:space-between;align-items:center;gap:20px">
  <span class="pill" style="font-size:34px">afrolookmedia.com/gagner/</span>
  <p class="fine" style="text-align:right;max-width:330px">Parraine tes amis : +10 %. Montants indicatifs.</p>
 </div>`);

// ───────── aperçu de lien 1200 × 630 ─────────
const ogAnnonceurs = html(1200, 630, `
 <div style="position:absolute;left:60px;top:48px">${brand}</div>
 <div style="position:absolute;left:60px;top:150px;width:700px">
  <span class="kick" style="font-size:20px;padding:7px 16px">Campagne Partage</span>
  <h1 style="font-size:70px;line-height:1.03;margin-top:18px">Fais <em>partager</em> ton annonce par de vraies personnes.</h1>
  <p style="font:600 26px/1.3 'Figtree';color:var(--muted);margin-top:16px">WhatsApp · Telegram · Facebook · TikTok</p>
 </div>
 <div class="ad" style="position:absolute;right:70px;top:150px;width:300px;height:300px;transform:rotate(4deg)"><b style="font-size:104px">-30 %</b><span style="font-size:30px">Boutique Kofi</span><u style="font-size:26px">Commande</u><div class="chip" style="left:-60px;top:28px;font-size:22px;transform:rotate(-6deg)">+1 clic valide</div></div>
 <span class="pill" style="position:absolute;left:60px;bottom:48px;font-size:28px;padding:14px 30px">afrolookmedia.com/ads/</span>`);

const ogJobs = html(1200, 630, `
 <div style="position:absolute;left:60px;top:48px">${brandJobs}</div>
 <div style="position:absolute;left:60px;top:150px;width:700px">
  <span class="kick" style="font-size:20px;padding:7px 16px">Jobs et tâches Afrolook</span>
  <h1 style="font-size:70px;line-height:1.03;margin-top:18px">Gagne de l'argent en <em>partageant</em> des annonces.</h1>
  <p style="font:600 26px/1.3 'Figtree';color:var(--muted);margin-top:16px">Profil validé · clic valide payé · retrait en argent réel</p>
 </div>
 <div style="position:absolute;right:70px;top:150px;text-align:center;width:300px"><div class="big" style="font-size:150px">5 F</div><p style="font:700 28px/1.2 'Figtree'">par clic valide</p><p class="fine" style="margin-top:8px">jusqu'à 500 F par jour</p></div>
 <span class="pill" style="position:absolute;left:60px;bottom:48px;font-size:28px;padding:14px 30px">afrolookmedia.com/gagner/</span>`);

const JOBS = [
  ['affiche-annonceurs', posterAnnonceurs, 1080, 1350],
  ['affiche-jobs', posterJobs, 1080, 1350],
  ['og-annonceurs', ogAnnonceurs, 1200, 630],
  ['og-jobs', ogJobs, 1200, 630],
];
fs.mkdirSync(OUT, { recursive: true });
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'afl-affiches-'));
for (const [name, doc, w, h] of JOBS) {
  const src = path.join(tmp, name + '.html'), out = path.join(OUT, name + '.png');
  fs.writeFileSync(src, doc);
  fs.rmSync(out, { force: true }); // l'ancienne image ne doit pas faire croire que le rendu est terminé
  execFileSync(browser, ['--headless=new', '--disable-gpu', `--user-data-dir=${path.join(tmp, 'profil')}`, '--no-first-run', '--hide-scrollbars', '--force-device-scale-factor=1', `--window-size=${w},${h}`, '--virtual-time-budget=4000', `--screenshot=${out}`, pathToFileURL(src).href], { stdio: 'ignore' });
  // Edge rend la main avant d'avoir écrit l'image : on attend qu'elle apparaisse et se stabilise
  for (let i = 0; i < 80 && !fs.existsSync(out); i++) await new Promise((r) => setTimeout(r, 250));
  await new Promise((r) => setTimeout(r, 600));
  console.log(name, fs.existsSync(out) ? fs.statSync(out).size + ' o' : 'ÉCHEC');
}
try { fs.rmSync(tmp, { recursive: true, force: true }); } catch { /* profil encore verrouillé : sans importance */ }
