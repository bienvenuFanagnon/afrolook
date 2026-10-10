// Vérifie le site généré : liens internes, titres et descriptions uniques, fichiers indispensables.
import fs from 'node:fs';
import path from 'node:path';
const dist = path.join(path.dirname(new URL(import.meta.url).pathname), 'dist');
const walk = (d) => fs.readdirSync(d, { withFileTypes: true }).flatMap((e) => (e.isDirectory() ? walk(path.join(d, e.name)) : [path.join(d, e.name)]));
const files = walk(dist), htmls = files.filter((f) => f.endsWith('.html'));
const exists = (u) => { const c = decodeURIComponent(u.split('#')[0].split('?')[0]); if (!c) return true; if (c.startsWith('/api/')) return true; const p = path.join(dist, c); return fs.existsSync(p) && (fs.statSync(p).isFile() || fs.existsSync(path.join(p, 'index.html'))); };
let errors = 0; const titles = new Map(), descs = new Map();
for (const f of htmls) {
  const html = fs.readFileSync(f, 'utf8'), rel = '/' + path.relative(dist, f);
  for (const m of html.matchAll(/(?:href|src)="([^"]+)"/g)) { const u = m[1]; if (/^(https?:|mailto:|tel:|data:|#|javascript:)/.test(u)) continue; if (u.startsWith('/') && !exists(u)) { console.log(`lien cassé ${u} dans ${rel}`); errors++; } }
  if (rel === '/404.html') continue;
  const t = html.match(/<title>([^<]*)<\/title>/)?.[1], d = html.match(/<meta name="description" content="([^"]*)"/)?.[1];
  if (!t || t.length > 75) { console.log(`titre absent ou trop long : ${rel} (${t?.length})`); errors++; }
  if (!d || d.length < 40 || d.length > 220) { console.log(`description absente ou hors limites : ${rel} (${d?.length})`); errors++; }
  if (titles.has(t)) { console.log(`titre en double ${rel} / ${titles.get(t)}`); errors++; } else titles.set(t, rel);
  if (descs.has(d)) { console.log(`description en double ${rel} / ${descs.get(d)}`); errors++; } else descs.set(d, rel);
  if ((html.match(/<h1[ >]/g) || []).length !== 1) { console.log(`H1 : ${rel} en a ${(html.match(/<h1[ >]/g) || []).length}`); errors++; }
}
for (const need of ['index.html', 'en/index.html', 'sitemap.xml', 'robots.txt', '404.html', 'favicon.svg', 'css/site.css', 'js/site.js', 'fonts/manrope-latin.woff2']) if (!fs.existsSync(path.join(dist, need))) { console.log(`fichier manquant : ${need}`); errors++; }
console.log(errors ? `${errors} problème(s)` : `OK : ${htmls.length} pages vérifiées`);
process.exit(errors ? 1 : 0);
