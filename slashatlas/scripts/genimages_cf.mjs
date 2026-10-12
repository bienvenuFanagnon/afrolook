// Génère des images d'exemple GRATUITEMENT avec Cloudflare Workers AI (FLUX.1 schnell, texte vers image) pour les commandes qui n'ont pas encore d'illustration.
// Ce sont des exemples de l'ambiance de la commande avec un sujet générique, pas le résultat sur une vraie photo : le site les étiquette « Exemple » et « FLUX ».
// Usage : CF_ACCOUNT_ID=… CF_API_TOKEN=… node scripts/genimages_cf.mjs [--limit 150] [--slugs a,b] [--cats mode,produit,beaute] [--dry]
// Essai sans compte : FAKE=1 node scripts/genimages_cf.mjs --limit 2 (images de test, écrites dans un dossier temporaire avec --out)
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { COMMANDS } from '../src/data.mjs';
import sharp from 'sharp';

const arg = (k, d) => { const i = process.argv.indexOf('--' + k); return i < 0 ? d : (process.argv[i + 1] && !process.argv[i + 1].startsWith('--') ? process.argv[i + 1] : true); };
const LIMIT = +arg('limit', 150), SLUGS = arg('slugs', ''), CATS = arg('cats', ''), DRY = !!arg('dry', false), FAKE = !!process.env.FAKE;
const OUT = arg('out', path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', 'static', 'img', 'c'));
const ACC = process.env.CF_ACCOUNT_ID, TOKEN = process.env.CF_API_TOKEN;
if (!FAKE && !DRY && (!ACC || !TOKEN)) throw new Error('CF_ACCOUNT_ID et CF_API_TOKEN sont nécessaires');
fs.mkdirSync(OUT, { recursive: true });

const PRIORITY = ['drone', 'afrofashion', 'mode', 'produit', 'beaute', 'food', 'immobilier', 'effets', 'bijoux', 'tech', 'auto', 'maison', 'diorama', 'mascotte', 'editorial'];
const INTRO = {
  product: 'Professional advertising photograph of a generic unbranded product (a plain bottle or box with a blank label). ',
  dish: 'Professional food photograph of a generic plated dish. ',
  person: 'Professional editorial photograph of a person. ',
  place: 'Professional architectural photograph of a property. ',
  free: '',
  video: 'Cinematic still frame from an advertising video: ',
  motion: 'Still frame from a motion design video, graphic and polished, clean modern composition, vivid colors: ',
};
function prompt(c) {
  let s = (c.scene && c.scene.en) || c.en.prompt;
  s = s.replace(/(?:with )?the (?:product|products|dish|dishes|person|people|property)?\(?s?\)?\s*(?:in|from) the attached photo(?: of the [a-z ]+)?/gi, 'a generic subject')
    .replace(/the attached photo/gi, 'a generic subject').replace(/attached/gi, '')
    .replace(/\[[^\]]*?(?:for example|e\.g\.)[:\s]*([^\]]*)\]/gi, '$1').replace(/\[([^\]]*)\]/g, '$1')
    .replace(/[“"][^”"]*[”"]/g, '').replace(/\s+/g, ' ').trim();
  // Catégorie Afro Fashion : les exemples montrent des personnes noires africaines (sans précision, le modèle d'image choisit d'autres profils)
  const intro = c.cat === 'afrofashion' ? 'Professional editorial fashion photograph of a Black African person with dark brown skin and natural African features (two Black African people if the scene describes a couple or duo). ' : (INTRO[c.kind] ?? '');
  return `${intro}${s} No text, no letters, no logo, no watermark. Sharp, high quality.`.slice(0, 1800);
}
const NOGEN = new Set('saleposter forrent newarrivals bundleoffer sidebyside menulineup openday shopfront beautypromo blueprint cyberpunk barbershop vintagerack inauguration conference djnight mascotsticker2 jewelgold jewelpearl'.split(' ')); // texte parasite ou refus du filtre du modèle
const skip = (c) => NOGEN.has(c.slug) || ['poster', 'logo', 'text'].includes(c.kind) || fs.existsSync(path.join(OUT, `${c.slug}-apres.webp`));
let list = COMMANDS.filter((c) => !skip(c));
if (SLUGS) list = list.filter((c) => String(SLUGS).split(',').includes(c.slug));
if (CATS) list = list.filter((c) => String(CATS).split(',').includes(c.cat));
const rank = (c) => { const i = PRIORITY.indexOf(c.cat); return i < 0 ? 99 : i; };
list = list.map((c, i) => [c, i]).sort((a, b) => rank(a[0]) - rank(b[0]) || a[1] - b[1]).map((x) => x[0]).slice(0, LIMIT);
console.log(`${list.length} image(s) à générer`);
if (DRY) { list.slice(0, 5).forEach((c) => console.log('-', c.slug, '\n  ', prompt(c))); process.exit(0); }

async function cf(p) {
  if (FAKE) return Buffer.from(execFileSync('python3', ['-c', "import sys,io,base64\nfrom PIL import Image\nim=Image.new('RGB',(1024,1024),(40,90,200));b=io.BytesIO();im.save(b,'JPEG');sys.stdout.write(base64.b64encode(b.getvalue()).decode())"], { encoding: 'utf8' }), 'base64');
  const r = await fetch(`https://api.cloudflare.com/client/v4/accounts/${ACC}/ai/run/@cf/black-forest-labs/flux-1-schnell`, { method: 'POST', headers: { Authorization: `Bearer ${TOKEN}`, 'content-type': 'application/json' }, body: JSON.stringify({ prompt: p, steps: 4 }) });
  const j = await r.json().catch(() => ({}));
  if (!r.ok || !j.success || !j.result || !j.result.image) { const e = (j.errors && j.errors[0]) || {}; const err = new Error(`${r.status} ${e.code || ''} ${e.message || ''}`); err.status = r.status; throw err; }
  return Buffer.from(j.result.image, 'base64');
}
// recadrage au format de la commande via sharp, puis WebP : image principale (1000 px) et vignette (480 px)
async function cropAndSave(imgBuf, outPath, thumbPath, ratio) {
  const [rw, rh] = ratio.split(':').map(Number);
  const meta = await sharp(imgBuf).metadata();
  const W = meta.width, H = meta.height;
  const target = rw / rh;
  let left = 0, top = 0, cw = W, ch = H;
  if (W / H > target) { cw = Math.round(H * target); left = Math.round((W - cw) / 2); }
  else { ch = Math.round(W / target); top = Math.round((H - ch) / 2); }
  const base = sharp(imgBuf).extract({ left, top, width: cw, height: ch });
  const resize = (m) => base.clone().resize(Math.min(cw, m), Math.min(ch, m), { fit: 'inside', kernel: 'lanczos3' });
  await resize(1000).webp({ quality: 82 }).toFile(outPath);
  await resize(480).webp({ quality: 80 }).toFile(thumbPath);
}
const engFile = path.join(OUT, 'engines.json');
let engines = {}; try { engines = JSON.parse(fs.readFileSync(engFile, 'utf8')); } catch (e) {}
let done = 0;
for (const c of list) {
  try {
    const img = await cf(prompt(c));
    await cropAndSave(img, path.join(OUT, `${c.slug}-apres.webp`), path.join(OUT, `${c.slug}-t.webp`), c.ratio);
    engines[c.slug] = FAKE ? 'test' : 'FLUX'; fs.writeFileSync(engFile, JSON.stringify(engines, null, 1));
    done++; console.log('ok', c.slug);
  } catch (e) {
    console.error('échec', c.slug, e.message);
    if (e.status === 429 || /4006|neurons|allocation|limit/i.test(e.message)) { console.error('Quota du jour atteint : on s\'arrête, reprise demain.'); break; }
  }
}
console.log(`${done} image(s) créée(s)`);
