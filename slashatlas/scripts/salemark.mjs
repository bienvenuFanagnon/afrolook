// Pose le rendu final d'une annonce (FOR SALE, prix, réduction, marque, contact, petit QR code) sur les images d'exemple des commandes de VENTE.
// Part toujours de l'image de base (assets/c-base, sans affiche) et écrit static/img/c/<slug>-apres.webp et -t.webp : relançable sans risque.
// Plusieurs présentations et emplacements (sale.js : bandeau, étiquette, pastille, colonne, ruban, sobre, promo) et des contenus variés (marque, prix, devise, contact).
// Usage : node scripts/salemark.mjs [--slugs a,b] [--sheet fichier.png]   (depuis le dossier slashatlas, NODE_PATH inutile)
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createRequire } from 'node:module';
import sharp from 'sharp';
import { COMMANDS } from '../src/data.mjs';
import { isSale } from '../src/sale.mjs';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const BASE = path.join(ROOT, 'assets', 'c-base'), OUT = path.join(ROOT, 'static', 'img', 'c');
const req = createRequire(path.join(ROOT, 'functions', 'package.json'));
const { createCanvas, loadImage, GlobalFonts } = req('@napi-rs/canvas');
const qrcode = req(path.join(ROOT, 'functions', 'vendor', 'qrcode.js'));
for (const [f, n] of [['manrope-latin-800-normal.woff2', 'Manrope'], ['manrope-latin-500-normal.woff2', 'Manrope']]) GlobalFonts.registerFromPath(path.join(ROOT, 'functions', 'fonts', f), n);
await import(pathToFileURL(path.join(ROOT, 'static', 'js', 'sale.js')).href);
const S = globalThis.saSale;
const arg = (k, d) => { const i = process.argv.indexOf('--' + k); return i < 0 ? d : process.argv[i + 1]; };
const only = arg('slugs', ''); const sheetFile = arg('sheet', '');

const hash = (s) => { let h = 2166136261; for (const ch of String(s)) { h ^= ch.charCodeAt(0); h = Math.imul(h, 16777619); } return h >>> 0; };
const pick = (a, h) => a[h % a.length];
const BRANDS = {
  mode: ['Maison Awa', 'Kenzo Mode', 'Atelier Kadi', 'Lina Couture', 'Wax & Style', 'Ama Fashion'],
  beaute: ['Glow Awa', 'Karité d’Or', 'Belle Peau', 'Nuit d’Afrique', 'Pure Éclat', 'Soin Naturel'],
  bijoux: ['Or d’Abidjan', 'Perle Rare', 'Bijoux Kadi', 'Éclat Royal'],
  food: ['Chez Mama Ama', 'Saveurs d’Afrique', 'Le Bon Goût', 'Délices Express', 'Chez Tantie'],
  tech: ['Tech Plus', 'Abidjan Mobile', 'Digital Shop', 'Smart Afrique'],
  auto: ['Auto Prestige', 'Garage Soleil', 'Auto Confiance', 'Moto Express'],
  maison: ['Déco Maison', 'Bois d’Ébène', 'Maison Douce', 'Intérieur Chic'],
  immobilier: ['Immo Prestige', 'Terre & Toit', 'Villa Plus', 'Cap Immo'],
  produit: ['Maison Soleil', 'Source Pure', 'Boutique Awa', 'Prix Malin', 'Marché Express'],
  sante: ['Douceur Awa', 'Belle Peau', 'Soin Naturel', 'Pure Éclat'],
  packaging: ['Pack & Co', 'Boîte Chic', 'Emballage Pro', 'Maison Kraft'],
};
const PRICE = { // [min, max, pas]
  mode: [6000, 45000, 500], beaute: [3500, 28000, 500], bijoux: [8000, 120000, 1000], food: [1500, 9000, 250], tech: [25000, 450000, 5000],
  auto: [2500000, 9500000, 50000], maison: [15000, 250000, 1000], immobilier: [18000000, 85000000, 500000], produit: [2000, 60000, 500], packaging: [150, 1800, 25], sante: [1000, 12000, 250],
};
const PHONES = ['+225 07 12 34 56 78', '+229 97 12 34 56', '+221 77 123 45 67', '+237 6 77 12 34 56', '+225 05 98 76 54 32', '+228 90 12 34 56', '+234 803 123 4567', '+243 81 234 5678'];
// toujours en FCFA — la cible est l'Afrique francophone
const USD_RATE = 600; // conservé pour la fonction money() mais usd est toujours false
const MODELS = S.MODELS;

function money(fcfa, usd) {
  if (!usd) return String(fcfa);
  const v = fcfa / USD_RATE;
  if (v < 10) return (Math.max(0.5, Math.round(v * 2) / 2)).toFixed(2); // 2,50 $ : centimes pour les petits prix
  return String(v < 100 ? Math.round(v) : Math.round(v / 5) * 5);
}
function content(c, i) {
  const h = hash(c.slug), cat = c.cat, [lo, hi, step] = PRICE[cat] || PRICE.produit;
  const fcfa = Math.round((lo + ((h >>> 3) % 1000) / 1000 * (hi - lo)) / step) * step;
  const usd = false; // toujours FCFA
  const disc = (h >>> 7) % 100 < 45 ? pick(['-10 %', '-15 %', '-20 %', '-25 %', '-30 %', '-40 %', '-50 %'], h >>> 9) : '';
  const pct = disc ? +disc.replace(/\D/g, '') : 0;
  const oldFcfa = pct ? Math.round(fcfa / (1 - pct / 100) / (fcfa > 10000 ? 500 : 25)) * (fcfa > 10000 ? 500 : 25) : 0;
  const rent = cat === 'immobilier' && (h >>> 11) % 3 === 0;
  const rentFcfa = rent ? Math.max(100000, Math.round(fcfa / 120 / 50000) * 50000) : fcfa; // loyer mensuel
  const tagText = rent ? 'FOR RENT' : disc ? 'PROMO' : pick(['FOR SALE', 'FOR SALE', 'NEW', 'FOR SALE'], h >>> 13);
  return {
    model: MODELS[(i * 3 + (h >>> 15)) % MODELS.length], tagText, price: money(rentFcfa, usd), cur: usd ? '$' : (rent ? 'FCFA/mo' : 'FCFA'), old: oldFcfa ? money(rent ? Math.round(oldFcfa / 120 / 50000) * 50000 || rentFcfa : oldFcfa, usd) : '', disc,
    brand: pick(BRANDS[cat] || BRANDS.produit, h >>> 17), contact: pick(PHONES, h >>> 19), qr: 'https://slashatlas.com/generer/', qrSize: 's', lang: 'en',
  };
}
const list = COMMANDS.filter(isSale).filter((c) => !only || only.split(',').includes(c.slug)).filter((c) => fs.existsSync(path.join(BASE, `${c.slug}-apres.webp`)));
console.log(`${list.length} image(s) de vente à composer`);
let compFile = path.join(BASE, 'composited.json'), comp = {}; try { comp = JSON.parse(fs.readFileSync(compFile, 'utf8')); } catch (e) {}
const sheet = sheetFile ? createCanvas(8 * 300, Math.ceil(Math.min(list.length, 32) / 8) * 380) : null; const sx = sheet && sheet.getContext('2d'); if (sx) { sx.fillStyle = '#222'; sx.fillRect(0, 0, sheet.width, sheet.height); }
for (let i = 0; i < list.length; i++) {
  const c = list[i], o = content(c, i);
  const im = await loadImage(path.join(BASE, `${c.slug}-apres.webp`));
  const cv = S.compose({ create: (w, h) => createCanvas(w, h), qrcode }, im, o);
  const pngBuf = cv.toBuffer('image/png');
  const resize = (m) => sharp(pngBuf).resize(Math.min(cv.width, m), Math.min(cv.height, m), { fit: 'inside', kernel: 'lanczos3' });
  await resize(1000).webp({ quality: 84 }).toFile(path.join(OUT, `${c.slug}-apres.webp`));
  await resize(480).webp({ quality: 82 }).toFile(path.join(OUT, `${c.slug}-t.webp`));
  comp[c.slug] = o.model;
  if (sx && i < 32) { const k = Math.min(290 / cv.width, 370 / cv.height); sx.drawImage(cv, (i % 8) * 300 + 5, Math.floor(i / 8) * 380 + 5, cv.width * k, cv.height * k); }
}
fs.writeFileSync(compFile, JSON.stringify(comp, null, 1));
if (sheet) fs.writeFileSync(sheetFile, sheet.toBuffer('image/png'));
console.log('terminé');
