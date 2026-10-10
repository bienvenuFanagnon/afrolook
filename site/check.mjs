// Vérifie le site généré : liens internes, images, ancres, titres et descriptions uniques. node check.mjs (après node build.mjs)
import fs from 'node:fs';
import path from 'node:path';

const dist = path.join(path.dirname(new URL(import.meta.url).pathname), 'dist');
const walk = (d) => fs.readdirSync(d, { withFileTypes: true }).flatMap((e) => (e.isDirectory() ? walk(path.join(d, e.name)) : [path.join(d, e.name)]));
const files = walk(dist);
const htmls = files.filter((f) => f.endsWith('.html'));
const exists = (u) => {
  const clean = decodeURIComponent(u.split('#')[0].split('?')[0]);
  if (!clean) return true;
  const p = path.join(dist, clean);
  return fs.existsSync(p) && (fs.statSync(p).isFile() || fs.existsSync(path.join(p, 'index.html')));
};
let errors = 0;
const titles = new Map(), descs = new Map();
for (const f of htmls) {
  const html = fs.readFileSync(f, 'utf8');
  const rel = '/' + path.relative(dist, f);
  const ids = new Set([...html.matchAll(/\sid="([^"]+)"/g)].map((m) => m[1]));
  for (const m of html.matchAll(/(?:href|src)="([^"]+)"/g)) {
    const u = m[1];
    if (/^(https?:|mailto:|tel:|data:|javascript:)/.test(u)) continue;
    if (u.startsWith('#')) { if (u.length > 1 && !ids.has(u.slice(1))) { console.log(`ancre manquante ${u} dans ${rel}`); errors++; } continue; }
    if (u.startsWith('/')) { if (!exists(u)) { console.log(`lien cassé ${u} dans ${rel}`); errors++; } continue; }
  }
  for (const m of html.matchAll(/href="(\/[^"#?]*)#([^"]+)"/g)) {
    const target = path.join(dist, m[1], m[1].endsWith('/') ? 'index.html' : '');
    if (fs.existsSync(target) && !fs.readFileSync(target, 'utf8').includes(`id="${m[2]}"`)) { console.log(`ancre ${m[1]}#${m[2]} introuvable (depuis ${rel})`); errors++; }
  }
  if (rel === '/404.html') continue;
  const t = html.match(/<title>([^<]*)<\/title>/)?.[1], d = html.match(/<meta name="description" content="([^"]*)"/)?.[1];
  if (!t || t.length > 90) { console.log(`titre absent ou trop long : ${rel}`); errors++; }
  if (!d || d.length < 50 || d.length > 200) { console.log(`description absente ou hors 50-200 car. (${d?.length}) : ${rel}`); errors++; }
  if (titles.has(t)) { console.log(`titre en double : ${rel} = ${titles.get(t)}`); errors++; } else titles.set(t, rel);
  if (descs.has(d)) { console.log(`description en double : ${rel} = ${descs.get(d)}`); errors++; } else descs.set(d, rel);
  if (!/<link rel="canonical" href="https:\/\/afrolookmedia\.com/.test(html)) { console.log(`canonical manquant : ${rel}`); errors++; }
  if ((html.match(/<h1[ >]/g) || []).length !== 1) { console.log(`un seul h1 attendu : ${rel}`); errors++; }
}
for (const need of ['.well-known/assetlinks.json', '.well-known/apple-app-site-association', 'app-ads.txt', 'robots.txt', 'sitemap.xml', 'img/qr-telecharger.svg']) {
  if (!fs.existsSync(path.join(dist, need))) { console.log(`fichier manquant : ${need}`); errors++; }
}
const sm = fs.readFileSync(path.join(dist, 'sitemap.xml'), 'utf8');
for (const m of sm.matchAll(/<loc>https:\/\/afrolookmedia\.com([^<]*)<\/loc>/g)) if (!exists(m[1])) { console.log(`sitemap : ${m[1]} n'existe pas`); errors++; }
console.log(errors ? `${errors} problème(s)` : `OK : ${htmls.length} pages, liens et métadonnées vérifiés`);
process.exit(errors ? 1 : 0);
