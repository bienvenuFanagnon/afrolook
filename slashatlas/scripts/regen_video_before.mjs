// Régénère les images "before" des exemples vidéo avec des visuels IA très classe.
// Objectif : femmes africaines fashion pour les vêtements, produits luxueux en studio pour les produits.
// Usage : CF_ACCOUNT_ID=… CF_API_TOKEN=… node scripts/regen_video_before.mjs [--slugs lotion,parfum]
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const OUT = path.join(ROOT, 'static', 'img', 'video');
const ACC = process.env.CF_ACCOUNT_ID, TOKEN = process.env.CF_API_TOKEN;
if (!ACC || !TOKEN) throw new Error('CF_ACCOUNT_ID et CF_API_TOKEN sont nécessaires');

const arg = (k, d) => { const i = process.argv.indexOf('--' + k); return i < 0 ? d : process.argv[i + 1]; };
const SLUGS_FILTER = arg('slugs', '');

// Prompts pour des images très classe et afrocentrées
const PROMPTS = {
  robe: 'Beautiful Black African woman model wearing a vibrant traditional African wax print dress with bold geometric patterns, full body fashion editorial, luxury fashion studio with clean white background, dramatic studio lighting from above, high fashion runway pose, hands on hips, confident pose, professional fashion photography, sharp, no text, 4:5 vertical format',
  tenue: 'Stylish Black African woman wearing a chic modern outfit, tailored blazer and matching trousers in earth tones, full body portrait in a luxury fashion studio, clean gradient background in light grey, confident professional pose, editorial fashion lighting, high-end magazine style photography, sharp, no text',
  parfum: 'Luxury perfume bottle with elegant minimalist design, dark amber glass with gold metallic cap, floating on pure black background, dramatic spotlight from above creating a halo glow effect, smoke wisps around the base, premium luxury fragrance advertisement photography, sharp details, studio quality, no text',
  lotion: 'Premium skincare product, elegant white and gold cream jar with minimalist label, on a polished white marble surface with golden light reflections, soft bokeh background in cream and gold tones, luxury beauty advertising photography, professional studio lighting, sharp, clean, no text',
  eau: 'Fresh mineral water bottle with clean modern design, crystal clear glass bottle with water droplets, on pure white background with soft blue gradient, bubbles rising, studio product photography with professional lighting, premium refreshing drink advertisement, sharp, no text',
  plat: 'Beautifully plated African grilled chicken with aromatic rice, fried plantains and spicy tomato sauce, on elegant dark slate plate, fine dining restaurant styling, warm dramatic lighting from above, appetizing food photography with shallow depth of field, restaurant quality presentation, sharp, no text',
};

async function cf(p) {
  const r = await fetch(`https://api.cloudflare.com/client/v4/accounts/${ACC}/ai/run/@cf/black-forest-labs/flux-1-schnell`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${TOKEN}`, 'content-type': 'application/json' },
    body: JSON.stringify({ prompt: p, steps: 8 }),
  });
  const j = await r.json().catch(() => ({}));
  if (!r.ok || !j.success || !j.result?.image) {
    const e = j.errors?.[0] || {};
    const err = new Error(`${r.status} ${e.code || ''} ${e.message || ''}`);
    err.status = r.status;
    throw err;
  }
  return Buffer.from(j.result.image, 'base64');
}

async function save(imgBuf, outPath) {
  const meta = await sharp(imgBuf).metadata();
  const W = meta.width, H = meta.height;
  // Format carré 1:1, recadré centré, 800px max
  const size = Math.min(W, H, 800);
  const left = Math.round((W - size) / 2);
  const top = Math.round((H - size) / 2);
  await sharp(imgBuf)
    .extract({ left, top, width: size, height: size })
    .resize(600, 600, { kernel: 'lanczos3' })
    .webp({ quality: 88 })
    .toFile(outPath);
}

const slugs = Object.keys(PROMPTS).filter(s => !SLUGS_FILTER || SLUGS_FILTER.split(',').includes(s));
console.log(`Génération de ${slugs.length} image(s) "before" pour les vidéos : ${slugs.join(', ')}`);

let done = 0;
for (const slug of slugs) {
  try {
    console.log(`  → ${slug} …`);
    const img = await cf(PROMPTS[slug]);
    const outPath = path.join(OUT, `before-${slug}.webp`);
    await save(img, outPath);
    console.log(`  ✓ ${slug} → ${outPath}`);
    done++;
  } catch (e) {
    console.error(`  ✗ ${slug} : ${e.message}`);
    if (e.status === 429 || /neurons|allocation|limit/i.test(e.message)) {
      console.error('Quota atteint — arrêt.');
      break;
    }
  }
}
console.log(`\n${done}/${slugs.length} image(s) régénérée(s).`);
console.log('\nRelancez node build.mjs puis firebase deploy pour mettre en ligne.');
