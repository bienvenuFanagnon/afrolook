// Refait GRATUITEMENT (Cloudflare Workers AI, FLUX.1 schnell) les images d'exemple des commandes de VENTE, avec une composition qui laisse
// de la place aux éléments de l'affiche (prix, À VENDRE, marque, contact, QR) ; ces éléments sont ajoutés ensuite par scripts/salemark.mjs.
// Les images de base sont rangées dans assets/c-base (hors du site) : une base n'est remplacée que si la nouvelle image est réussie.
// Usage : CF_ACCOUNT_ID=… CF_API_TOKEN=… node scripts/regen_sale_cf.mjs [--mod 2 --rem 0] [--limit 120] [--slugs a,b]
// Pour les slugs de la démo homepage (IMGPAIRS), si une photo avant existe, on utilise SD 1.5 img2img pour
// conserver la tenue exacte tout en recontextualisant l'image en affiche pro.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { COMMANDS } from '../src/data.mjs';
import { isSale } from '../src/sale.mjs';
import sharp from 'sharp';

const arg = (k, d) => { const i = process.argv.indexOf('--' + k); return i < 0 ? d : process.argv[i + 1]; };
const MOD = +arg('mod', 1), REM = +arg('rem', 0), LIMIT = +arg('limit', 400), SLUGS = arg('slugs', '');
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
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
// Slugs de la démo homepage avec photo "avant" → img2img SD 1.5 pour conserver la tenue
const IMGPAIRS_PROMPTS = {
  fashionposter: 'Professional fashion advertising poster, beautiful Black African woman wearing a traditional wax print dress with bold geometric patterns in orange blue and white colors, full body shot, fashion studio with clean neutral background, editorial lighting, magazine style, high end fashion photography, vertical 4:5 format, sharp, no text',
  lookbook: 'fashion lookbook page, outfit on neutral textured background, editorial lighting, magazine style, generous margins',
  hairshowcase: 'Beautiful Black African woman with long braided hair, professional hair salon poster, studio lighting, shiny healthy hair, neutral grey background, fashion portrait, close-up shot',
  splashshot: 'product advertising, splash effect, clean gradient background, studio lighting, premium feel',
  productglow: 'product floating on dark background, glowing halo, studio light, premium luxury advertisement',
  menuhero: 'African grilled chicken with rice and tomato salad on a white plate, professional food photography close-up, warm lighting, dark blurred restaurant background, menu poster style, appetizing',
  coverdrop: 'album cover art, centered portrait, strong contrast, clean background, music release single cover',
  skincareglow: 'skincare product advertisement, clean white background, soft diffused light, premium cosmetics packaging',
};
// Commandes avec personne : prompts forcés pour des personnes africaines et afro-américaines
const PERSON_PROMPTS = {
  lookbook: 'Beautiful Black African woman wearing a stylish modern fashion outfit, full body lookbook editorial, neutral textured studio background, editorial magazine lighting, high fashion pose, professional photography, sharp, no text',
  streetfit: 'Stylish young Black African man wearing trendy streetwear outfit, colorful bold clothing, urban fashion editorial, clean studio background, confident pose, professional advertising photography, sharp, no text',
  makeuplook: 'Beautiful Black African woman with stunning professional makeup, close-up beauty portrait, flawless dark skin glowing, editorial beauty lighting, luxury cosmetics advertisement, sharp, no text',
  barbershop: 'Handsome Black African man with a fresh professional haircut, barbershop portrait, clean short fade hairstyle, confident expression, dark studio background with dramatic lighting, professional barbershop advertisement, sharp, no text',
  mannequinstudio: 'Beautiful Black African woman wearing elegant fashion outfit, fashion model pose in luxury studio, clean white background, dramatic professional lighting, full body fashion editorial, sharp, no text',
  summerstyle: 'Beautiful Black African woman in stylish summer outfit, vibrant colorful African wax print clothing, outdoor summer editorial, warm natural lighting, joyful confident pose, fashion advertising, sharp, no text',
  modestfashion: 'Elegant Black African woman wearing beautiful modest fashion outfit, long flowing dress with African print patterns, graceful pose, luxury studio background, editorial fashion photography, professional lighting, sharp, no text',
  tailoratelier: 'Skilled Black African tailor working in a professional atelier, measuring fabric with tape, elegant workshop setting with fabrics and sewing tools, fashion craftsmanship advertisement, warm studio lighting, sharp, no text',
  coupleoutfits: 'Stylish Black African couple wearing matching elegant outfits, man in tailored suit and woman in beautiful dress with African prints, professional fashion editorial, clean studio background, sharp, no text',
  mensuit: 'Handsome Black African man wearing a sharp well-fitted tailored suit, professional business portrait, confident pose, clean neutral studio background, luxury fashion advertising, sharp, no text',
  braidstyle: 'Beautiful Black African woman with stunning long braided hairstyle, salon professional portrait, shiny healthy braids, elegant makeup, grey studio background, hair salon advertising poster, sharp, no text',
  naturalhair: 'Beautiful Black African woman with gorgeous natural afro hair, large voluminous afro crown, radiant smile, clean light studio background, natural hair salon advertising, professional portrait, sharp, no text',
  massagetime: 'Relaxed Black African woman receiving a professional luxury spa massage, clean elegant spa setting, warm candles and flowers, premium wellness advertising, professional photography, sharp, no text',
  lashextension: 'Beautiful Black African woman showing perfect eyelash extensions, close-up beauty portrait, dark glowing skin, dramatic eye makeup, professional beauty studio lighting, luxury lash salon advertisement, sharp, no text',
  facialcare: 'Beautiful Black African woman with glowing healthy dark skin applying luxury facial cream, clean bathroom setting with premium skincare products, beauty advertising, soft studio lighting, sharp, no text',
  bridalmakeup: 'Beautiful Black African bride with stunning traditional bridal makeup, elaborate headpiece, elegant bridal gown, professional bridal beauty portrait, warm romantic lighting, sharp, no text',
  hennahands: 'Beautiful dark-skinned Black African woman hands with intricate traditional henna design, elegant jewelry, close-up detail shot, clean light background, cultural fashion advertisement, sharp, no text',
};
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
// img2img SD 1.5 : part de la vraie photo pour conserver le sujet (tenue, produit) tout en recontextualisant
async function cfImg2Img(avantPath, promptText, ratio) {
  const [rw, rh] = ratio.split(':').map(Number);
  // SD 1.5 travaille en 512x512 ; on crop au bon ratio puis on redimensionne
  const size = 512;
  const raw = await sharp(avantPath)
    .resize(rw >= rh ? size : Math.round(size * rw / rh), rh >= rw ? size : Math.round(size * rh / rw), { fit: 'cover', position: 'centre' })
    .resize(size, size, { fit: 'fill' }).removeAlpha().raw().toBuffer({ resolveWithObject: true });
  const floats = Array.from(raw.data).map(v => v / 255);
  const r = await fetch(`https://api.cloudflare.com/client/v4/accounts/${ACC}/ai/run/@cf/runwayml/stable-diffusion-v1-5-img2img`,
    { method: 'POST', headers: { Authorization: `Bearer ${TOKEN}`, 'content-type': 'application/json' },
      body: JSON.stringify({ prompt: promptText, image: floats, strength: 0.62, num_steps: 20, guidance: 7.5 }) });
  const j = await r.json().catch(() => ({}));
  if (!r.ok || !j.success || !j.result || !j.result.image) { const e = (j.errors && j.errors[0]) || {}; const err = new Error(`SD15i2i ${r.status} ${e.code || ''} ${e.message || ''}`); err.status = r.status; throw err; }
  const out = j.result.image; // tableau de floats RGB 512×512×3
  const uint8 = Buffer.from(out.map(v => Math.round(Math.max(0, Math.min(1, v)) * 255)));
  return await sharp(uint8, { raw: { width: size, height: size, channels: 3 } }).png().toBuffer();
}
async function cropAndSave(imgBuf, outPath, ratio) {
  const [rw, rh] = ratio.split(':').map(Number);
  const meta = await sharp(imgBuf).metadata();
  const W = meta.width, H = meta.height, target = rw / rh;
  let left = 0, top = 0, cw = W, ch = H;
  if (W / H > target) { cw = Math.round(H * target); left = Math.round((W - cw) / 2); }
  else { ch = Math.round(W / target); top = Math.round((H - ch) / 2); }
  const k = 1000 / Math.max(cw, ch);
  const w2 = k < 1 ? Math.round(cw * k) : cw, h2 = k < 1 ? Math.round(ch * k) : ch;
  await sharp(imgBuf).extract({ left, top, width: cw, height: ch }).resize(w2, h2, { kernel: 'lanczos3' }).webp({ quality: 84 }).toFile(outPath);
}
let done = 0;
for (const c of list) {
  try {
    const avantPath = path.join(CUR, `${c.slug}-avant.webp`);
    const useI2I = IMGPAIRS_PROMPTS[c.slug] && fs.existsSync(avantPath);
    let img, engine;
    if (useI2I) {
      try {
        img = await cfImg2Img(avantPath, IMGPAIRS_PROMPTS[c.slug], c.ratio);
        engine = 'SD15i2i';
      } catch (e2) {
        if (e2.status === 403 || /5018|not allowed/i.test(e2.message)) {
          console.log(`img2img non disponible pour ${c.slug}, bascule sur FLUX`);
          img = await cf(PERSON_PROMPTS[c.slug] || prompt(c)); engine = 'FLUX';
        } else throw e2;
      }
    } else if (PERSON_PROMPTS[c.slug]) {
      // Commande avec personne : utiliser le prompt africain forcé
      img = await cf(PERSON_PROMPTS[c.slug]); engine = 'FLUX';
    } else {
      img = await cf(prompt(c)); engine = 'FLUX';
    }
    await cropAndSave(img, path.join(BASE, `${c.slug}-apres.webp`), c.ratio);
    state[c.slug] = 1; fs.writeFileSync(stateFile, JSON.stringify(state));
    engines[c.slug] = engine; done++;
    console.log('ok', c.slug, `(${engine})`);
  } catch (e) {
    console.error('échec', c.slug, e.message);
    if (e.status === 429 || /4006|neurons|allocation|limit/i.test(e.message)) { console.error('Quota du jour atteint : on s\'arrête, reprise demain.'); break; }
  }
}
fs.writeFileSync(engFile, JSON.stringify(engines, null, 1));
console.log(`${done} image(s) refaite(s)`);
