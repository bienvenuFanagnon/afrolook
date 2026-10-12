import sharp from 'sharp';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const avant = path.join(ROOT, 'static/img/c/fashionposter-avant.webp');
const base  = path.join(ROOT, 'assets/c-base/fashionposter-apres.webp');

const meta = await sharp(avant).metadata();
const W = meta.width, H = meta.height;
const target = 4/5;
let left = 0, top = 0, cw = W, ch = H;
if (W/H > target) { cw = Math.round(H * target); left = Math.round((W - cw) / 2); }
else              { ch = Math.round(W / target); top  = Math.round((H - ch) / 2); }

await sharp(avant)
  .extract({ left, top, width: cw, height: ch })
  .resize(800, 1000, { kernel: 'lanczos3' })
  .webp({ quality: 88 })
  .toFile(base);
console.log('Base fashionposter corrigée :', base);
