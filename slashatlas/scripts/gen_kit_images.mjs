// Génère les images pour les commandes Kit créateur (kind: text, ratio: texte → 1:1)
// Usage : CF_ACCOUNT_ID=… CF_API_TOKEN=… node scripts/gen_kit_images.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { COMMANDS } from '../src/data.mjs';
import sharp from 'sharp';

const ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const ACC = process.env.CF_ACCOUNT_ID, TOKEN = process.env.CF_API_TOKEN;
if (!ACC || !TOKEN) throw new Error('CF_ACCOUNT_ID et CF_API_TOKEN sont nécessaires');

const OUT = path.join(ROOT, 'static', 'img', 'c');
fs.mkdirSync(OUT, { recursive: true });

const kits = COMMANDS.filter(c => c.kind === 'text' && !fs.existsSync(path.join(OUT, `${c.slug}-t.webp`)));
console.log(kits.length + ' commandes Kit à générer');

const KIT_PROMPTS = {
  kithooks:     'Professional flat lay of a smartphone showing social media content, notebook and pen on pastel background, top-down view.',
  kitscript15:  'Professional flat lay of a clapperboard and script pages on light background, cinema concept, clean minimal.',
  kitscript30:  'Professional flat lay of a film script and clapperboard, video production concept, clean minimal background.',
  kitstoryboard:'Professional flat lay of hand-drawn storyboard panels and pencils, video production planning, clean workspace.',
  kitvoiceover: 'Professional studio microphone on a clean desk with script pages, podcast recording concept, minimal background.',
  kitcaptions:  'Professional flat lay of a smartphone with social media content, pen and notebook, creative concept, soft pastel background.',
  kithashtags:  'Professional flat lay of a smartphone showing social media feed, marketing concept, clean minimal background.',
  kitcal7:      'Professional flat lay of a weekly planner calendar open on a desk with pen and coffee cup, content planning, clean minimal.',
  kitcal30:     'Professional flat lay of a monthly editorial calendar spread on a desk, content strategy planning, clean workspace.',
  kitfaceless:  'Professional flat lay of a camera and creative props, content creation concept, soft pastel background.',
  kitbio:       'Professional flat lay of a smartphone showing a profile page, minimal clean background, creative concept.',
  kitpinned:    'Professional flat lay of a smartphone showing social media profile, content strategy concept, clean minimal background.',
  kitthumbs:    'Professional flat lay of a tablet showing thumbnail card designs, video content creation concept, clean workspace.',
  kitshorts:    'Professional vertical smartphone on a clean surface, mobile content creation concept, clean minimal background.',
  kitoffer:     'Professional flat lay of a promotional card and smartphone, sales offer concept, clean minimal background.',
  kitbroadcast: 'Professional flat lay of a megaphone and smartphone with notifications icon, announcement concept, clean minimal.',
  kitreplies:   'Professional flat lay of a smartphone showing a conversation interface, community management concept, clean minimal.',
  kitdm:        'Professional flat lay of a smartphone showing message bubbles, customer conversation concept, clean minimal pastel background.',
  kitcarousel:  'Professional flat lay of several content card layouts on a light background, social media carousel concept, clean minimal.',
  kitseries:    'Professional flat lay of multiple content cards arranged in a series pattern, content strategy concept, clean minimal.',
  kittrend:     'Professional flat lay of a smartphone showing analytics charts, social media trend concept, clean minimal background.',
  kitgiveaway:  'Professional flat lay of a gift box and ribbons with a smartphone, giveaway celebration concept, clean background.',
  kitlaunch:    'Professional flat lay of a megaphone and confetti, product launch announcement concept, clean minimal background.',
  kitshots:     'Professional flat lay of multiple smartphone screens arranged on a surface, multi-platform content concept, clean minimal.',
};

async function cf(prompt) {
  const r = await fetch(`https://api.cloudflare.com/client/v4/accounts/${ACC}/ai/run/@cf/black-forest-labs/flux-1-schnell`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${TOKEN}`, 'content-type': 'application/json' },
    body: JSON.stringify({ prompt: prompt + ' No text, no letters, no logo, no watermark. Sharp, high quality.', steps: 4 })
  });
  const j = await r.json().catch(() => ({}));
  if (!r.ok || !j.success || !j.result?.image) {
    const e = (j.errors && j.errors[0]) || {};
    const err = new Error(`${r.status} ${e.code || ''} ${e.message || ''}`);
    err.status = r.status;
    throw err;
  }
  return Buffer.from(j.result.image, 'base64');
}

async function cropAndSave(imgBuf, outPath, thumbPath) {
  const meta = await sharp(imgBuf).metadata();
  const size = Math.min(meta.width, meta.height);
  const left = Math.round((meta.width - size) / 2);
  const top = Math.round((meta.height - size) / 2);
  const base = sharp(imgBuf).extract({ left, top, width: size, height: size });
  await base.clone().resize(1000, 1000).webp({ quality: 82 }).toFile(outPath);
  await base.clone().resize(480, 480).webp({ quality: 80 }).toFile(thumbPath);
}

const engFile = path.join(OUT, 'engines.json');
let engines = {}; try { engines = JSON.parse(fs.readFileSync(engFile, 'utf8')); } catch (e) {}

let done = 0;
for (const c of kits) {
  try {
    const p = KIT_PROMPTS[c.slug] || 'Professional flat lay of creative content tools for social media, clean minimal background.';
    const img = await cf(p);
    await cropAndSave(img, path.join(OUT, `${c.slug}-apres.webp`), path.join(OUT, `${c.slug}-t.webp`));
    engines[c.slug] = 'FLUX';
    fs.writeFileSync(engFile, JSON.stringify(engines, null, 1));
    done++;
    console.log('ok', c.slug);
  } catch (e) {
    console.error('échec', c.slug, e.message);
    if (e.status === 429 || /4006|neurons|allocation|limit/i.test(e.message)) {
      console.error('Quota atteint, reprise demain.');
      break;
    }
  }
}
console.log(`${done} image(s) créée(s)`);
