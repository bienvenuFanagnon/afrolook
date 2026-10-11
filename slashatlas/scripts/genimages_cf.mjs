// Génère des images d'exemple GRATUITEMENT avec Cloudflare Workers AI (FLUX.1 schnell, texte vers image) pour les commandes qui n'ont pas encore d'illustration.
// Ce sont des exemples de l'ambiance de la commande avec un sujet générique, pas le résultat sur une vraie photo : le site les étiquette « Exemple » et « FLUX ».
// Usage : CF_ACCOUNT_ID=… CF_API_TOKEN=… node scripts/genimages_cf.mjs [--limit 150] [--slugs a,b] [--cats mode,produit,beaute] [--dry]
// Essai sans compte : FAKE=1 node scripts/genimages_cf.mjs --limit 2 (images de test, écrites dans un dossier temporaire avec --out)
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { COMMANDS } from '../src/data.mjs';

const arg = (k, d) => { const i = process.argv.indexOf('--' + k); return i < 0 ? d : (process.argv[i + 1] && !process.argv[i + 1].startsWith('--') ? process.argv[i + 1] : true); };
const LIMIT = +arg('limit', 150), SLUGS = arg('slugs', ''), CATS = arg('cats', ''), DRY = !!arg('dry', false), FAKE = !!process.env.FAKE;
const OUT = arg('out', path.join(path.dirname(new URL(import.meta.url).pathname), '..', 'static', 'img', 'c'));
const ACC = process.env.CF_ACCOUNT_ID, TOKEN = process.env.CF_API_TOKEN;
if (!FAKE && !DRY && (!ACC || !TOKEN)) throw new Error('CF_ACCOUNT_ID et CF_API_TOKEN sont nécessaires');
fs.mkdirSync(OUT, { recursive: true });

const PRIORITY = ['mode', 'produit', 'beaute', 'food', 'immobilier', 'effets', 'bijoux', 'tech', 'auto', 'maison', 'diorama', 'mascotte', 'editorial'];
const INTRO = {
  product: 'Professional advertising photograph of a generic unbranded product (a plain bottle or box with a blank label). ',
  dish: 'Professional food photograph of a generic plated dish. ',
  person: 'Professional editorial photograph of a person. ',
  place: 'Professional architectural photograph of a property. ',
  free: '',
  video: 'Cinematic still frame from an advertising video: ',
};
function prompt(c) {
  let s = (c.scene && c.scene.en) || c.en.prompt;
  s = s.replace(/(?:with )?the (?:product|products|dish|dishes|person|people|property)?\(?s?\)?\s*(?:in|from) the attached photo(?: of the [a-z ]+)?/gi, 'a generic subject')
    .replace(/the attached photo/gi, 'a generic subject').replace(/attached/gi, '')
    .replace(/\[[^\]]*?(?:for example|e\.g\.)[:\s]*([^\]]*)\]/gi, '$1').replace(/\[([^\]]*)\]/g, '$1')
    .replace(/[“"][^”"]*[”"]/g, '').replace(/\s+/g, ' ').trim();
  return `${INTRO[c.kind] ?? ''}${s} No text, no letters, no logo, no watermark. Sharp, high quality.`.slice(0, 1800);
}
const NOGEN = new Set('saleposter forrent newarrivals bundleoffer sidebyside menulineup openday shopfront beautypromo blueprint cyberpunk barbershop vintagerack inauguration conference djnight mascotsticker2 jewelgold jewelpearl'.split(' ')); // texte parasite ou refus du filtre du modèle
const skip = (c) => NOGEN.has(c.slug) || ['poster', 'logo'].includes(c.kind) || fs.existsSync(path.join(OUT, `${c.slug}-apres.webp`));
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
// recadrage au format de la commande, puis WebP : image principale (1000 px) et vignette (480 px)
const PY = "import sys,io\nfrom PIL import Image\nsrc,out,thumb,ratio=sys.argv[1:5]\nw,h=map(float,ratio.split(':'))\nim=Image.open(src).convert('RGB')\nW,H=im.size;t=w/h\nif W/H>t:\n nw=int(H*t);im=im.crop(((W-nw)//2,0,(W-nw)//2+nw,H))\nelse:\n nh=int(W/t);im=im.crop((0,(H-nh)//2,W,(H-nh)//2+nh))\ndef sz(im,m):\n W,H=im.size;k=m/max(W,H);return im.resize((max(1,int(W*k)),max(1,int(H*k))),Image.LANCZOS) if k<1 else im\nsz(im,1000).save(out,'WEBP',quality=82)\nsz(im,480).save(thumb,'WEBP',quality=80)\n";
const engFile = path.join(OUT, 'engines.json');
let engines = {}; try { engines = JSON.parse(fs.readFileSync(engFile, 'utf8')); } catch (e) {}
let done = 0;
for (const c of list) {
  try {
    const img = await cf(prompt(c));
    const tmp = path.join(OUT, `.${c.slug}.tmp`); fs.writeFileSync(tmp, img);
    execFileSync('python3', ['-c', PY, tmp, path.join(OUT, `${c.slug}-apres.webp`), path.join(OUT, `${c.slug}-t.webp`), c.ratio]); fs.unlinkSync(tmp);
    engines[c.slug] = FAKE ? 'test' : 'FLUX'; fs.writeFileSync(engFile, JSON.stringify(engines, null, 1));
    done++; console.log('ok', c.slug);
  } catch (e) {
    console.error('échec', c.slug, e.message);
    if (e.status === 429 || /4006|neurons|allocation|limit/i.test(e.message)) { console.error('Quota du jour atteint : on s\'arrête, reprise demain.'); break; }
  }
}
console.log(`${done} image(s) créée(s)`);
