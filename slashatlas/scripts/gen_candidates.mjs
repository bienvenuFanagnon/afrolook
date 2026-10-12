import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const ACC = process.env.CF_ACCOUNT_ID, TOKEN = process.env.CF_API_TOKEN;
const SLUG = process.argv[2] || 'fashionposter';
const N = parseInt(process.argv[3] || '4');

const PROMPTS = {
  fashionposter: 'Black African woman model wearing a colorful traditional African wax print dress with bold geometric patterns in orange blue and white, full body fashion editorial poster, luxury fashion studio, dramatic lighting, runway style, professional high quality photography, vertical format',
  hairshowcase: 'Beautiful Black African woman with long braided hair, professional hair salon poster, studio lighting, shiny healthy hair, neutral grey background, fashion portrait, close-up shot',
  menuhero: 'African grilled chicken with rice and tomato salad on a white plate, professional food photography close-up, warm lighting, dark blurred restaurant background, menu poster style, appetizing',
};

async function cf(p, steps = 8) {
  const r = await fetch(`https://api.cloudflare.com/client/v4/accounts/${ACC}/ai/run/@cf/black-forest-labs/flux-1-schnell`,
    { method: 'POST', headers: { Authorization: `Bearer ${TOKEN}`, 'content-type': 'application/json' },
      body: JSON.stringify({ prompt: p, steps }) });
  const j = await r.json().catch(() => ({}));
  if (!r.ok || !j.success || !j.result?.image) throw new Error(`${r.status} ${(j.errors||[{}])[0]?.message||''}`);
  return Buffer.from(j.result.image, 'base64');
}

const outDir = path.join(ROOT, 'assets', 'candidates', SLUG);
fs.mkdirSync(outDir, { recursive: true });

for (let i = 0; i < N; i++) {
  try {
    const buf = await cf(PROMPTS[SLUG]);
    const outPath = path.join(outDir, `${i+1}.webp`);
    const meta = await sharp(buf).metadata();
    const W = meta.width, H = meta.height, target = 4/5;
    let left = 0, top = 0, cw = W, ch = H;
    if (W/H > target) { cw = Math.round(H * target); left = Math.round((W - cw) / 2); }
    else              { ch = Math.round(W / target); top  = Math.round((H - ch) / 2); }
    await sharp(buf).extract({ left, top, width: cw, height: ch }).resize(800, 1000).webp({ quality: 88 }).toFile(outPath);
    console.log(`candidat ${i+1} → ${outPath}`);
  } catch(e) { console.error(`candidat ${i+1} ECHEC:`, e.message); }
}
console.log('Terminé — candidats dans assets/candidates/' + SLUG);
