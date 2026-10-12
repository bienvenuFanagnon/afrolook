// Refait GRATUITEMENT (Cloudflare Workers AI, FLUX.1 schnell) les images d'exemple des commandes de VENTE, avec une composition qui laisse
// de la place aux éléments de l'affiche (prix, À VENDRE, marque, contact, QR) ; ces éléments sont ajoutés ensuite par scripts/salemark.mjs.
// Les images de base sont rangées dans assets/c-base (hors du site) : une base n'est remplacée que si la nouvelle image est réussie.
// Usage : CF_ACCOUNT_ID=… CF_API_TOKEN=… node scripts/regen_sale_cf.mjs [--mod 2 --rem 0] [--limit 120] [--slugs a,b]
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { COMMANDS } from '../src/data.mjs';
import { isSale } from '../src/sale.mjs';

const arg = (k, d) => { const i = process.argv.indexOf('--' + k); return i < 0 ? d : process.argv[i + 1]; };
const MOD = +arg('mod', 1), REM = +arg('rem', 0), LIMIT = +arg('limit', 400), SLUGS = arg('slugs', '');
const ROOT = path.join(path.dirname(new URL(import.meta.url).pathname), '..');
const BASE = path.join(ROOT, 'assets', 'c-base'), CUR = path.join(ROOT, 'static', 'img', 'c');
const ACC = process.env.CF_ACCOUNT_ID, TOKEN = process.env.CF_API_TOKEN;
if (!ACC || !TOKEN) throw new Error('CF_ACCOUNT_ID et CF_API_TOKEN sont nécessaires');
fs.mkdirSync(BASE, { recursive: true });

const INTRO = {
  product: 'Professional advertising photograph of a generic unbranded product (a plain bottle, box or object with a blank label). ',
  dish: 'Professional food photograph of a generic plated dish. ',
  person: 'Professional fashion photograph of a person wearing the outfit, full outfit visible. ',
  place: 'Professional architectural photograph of a property for sale. ',
};
const COMPOSE = ' Composition for a sales advertisement: the subject is large, sharp and centered slightly above the middle, with a clean, calm, uncluttered background area along the bottom quarter of the image.';
function prompt(c) {
  let s = (c.scene && c.scene.en) || c.en.prompt;
  s = s.replace(/(?:with )?the (?:product|products|dish|dishes|person|people|property)?\(?s?\)?\s*(?:in|from) the attached photo(?: of the [a-z ]+)?/gi, 'a generic subject')
    .replace(/the attached photo/gi, 'a generic subject').replace(/attached/gi, '')
    .replace(/\[[^\]]*?(?:for example|e\.g\.)[:\s]*([^\]]*)\]/gi, '$1').replace(/\[([^\]]*)\]/g, '$1')
    .replace(/[“"][^”"]*[”"]/g, '').replace(/\s+/g, ' ').trim();
  return `${INTRO[c.kind || 'product'] ?? ''}${s}${COMPOSE} No text, no letters, no logo, no watermark. Sharp, high quality.`.slice(0, 1800);
}
const engFile = path.join(CUR, 'engines.json'); let engines = {}; try { engines = JSON.parse(fs.readFileSync(engFile, 'utf8')); } catch (e) {}
const stateFile = path.join(BASE, 'regen.json'); let state = {}; try { state = JSON.parse(fs.readFileSync(stateFile, 'utf8')); } catch (e) {}
let comp = {}; try { comp = JSON.parse(fs.readFileSync(path.join(BASE, 'composited.json'), 'utf8')); } catch (e) {} // commandes dont l'image du site porte déjà l'affiche (ne jamais en faire une base)

// 1. les bases : l'image actuelle de chaque commande de vente (une seule fois), pour que la composition reparte toujours d'une image sans affiche
let all = COMMANDS.filter(isSale);
for (const c of all) { const cur = path.join(CUR, `${c.slug}-apres.webp`), b = path.join(BASE, `${c.slug}-apres.webp`); if (!fs.existsSync(b) && fs.existsSync(cur) && !comp[c.slug]) fs.copyFileSync(cur, b); }

// 2. régénération : seulement les images FLUX (les résultats faits à partir d'une vraie photo, Gemini, restent) et les commandes sans image
let list = all.filter((c) => !state[c.slug] && (!engines[c.slug] || engines[c.slug] === 'FLUX' || engines[c.slug] === 'test'));
if (SLUGS) list = list.filter((c) => SLUGS.split(',').includes(c.slug));
list = list.filter((_, i) => i % MOD === REM).slice(0, LIMIT);
console.log(`${list.length} image(s) à refaire (part ${REM}/${MOD})`);

async function cf(p) {
  const r = await fetch(`https://api.cloudflare.com/client/v4/accounts/${ACC}/ai/run/@cf/black-forest-labs/flux-1-schnell`, { method: 'POST', headers: { Authorization: `Bearer ${TOKEN}`, 'content-type': 'application/json' }, body: JSON.stringify({ prompt: p, steps: 6 }) });
  const j = await r.json().catch(() => ({}));
  if (!r.ok || !j.success || !j.result || !j.result.image) { const e = (j.errors && j.errors[0]) || {}; const err = new Error(`${r.status} ${e.code || ''} ${e.message || ''}`); err.status = r.status; throw err; }
  return Buffer.from(j.result.image, 'base64');
}
const PY = "import sys\nfrom PIL import Image\nsrc,out,ratio=sys.argv[1:4]\nw,h=map(float,ratio.split(':'))\nim=Image.open(src).convert('RGB')\nW,H=im.size;t=w/h\nif W/H>t:\n nw=int(H*t);im=im.crop(((W-nw)//2,0,(W-nw)//2+nw,H))\nelse:\n nh=int(W/t);im=im.crop((0,(H-nh)//2,W,(H-nh)//2+nh))\nk=1000/max(im.size)\nim=im.resize((max(1,int(im.size[0]*k)),max(1,int(im.size[1]*k))),Image.LANCZOS) if k<1 else im\nim.save(out,'WEBP',quality=84)\n";
let done = 0;
for (const c of list) {
  try {
    const img = await cf(prompt(c));
    const tmp = path.join(BASE, `.${c.slug}.tmp`); fs.writeFileSync(tmp, img);
    execFileSync('python3', ['-c', PY, tmp, path.join(BASE, `${c.slug}-apres.webp`), c.ratio]); fs.unlinkSync(tmp);
    state[c.slug] = 1; fs.writeFileSync(stateFile, JSON.stringify(state)); engines[c.slug] = 'FLUX'; done++; console.log('ok', c.slug);
  } catch (e) {
    console.error('échec', c.slug, e.message);
    if (e.status === 429 || /4006|neurons|allocation|limit/i.test(e.message)) { console.error('Quota du jour atteint : on s\'arrête, reprise demain.'); break; }
  }
}
fs.writeFileSync(engFile, JSON.stringify(engines, null, 1));
console.log(`${done} image(s) refaite(s)`);
