// Ajoute l'application web Flutter dans dist/app/ (même domaine que le site) : node with-app.mjs
// Préalable : flutter build web --release --base-href /app/
import fs from 'node:fs';
import path from 'node:path';

const here = path.dirname(new URL(import.meta.url).pathname);
const src = path.join(here, '..', 'build', 'web');
const out = path.join(here, 'dist', 'app');
const index = path.join(src, 'index.html');
if (!fs.existsSync(index)) { console.error('build/web introuvable : lance d\'abord flutter build web --release --base-href /app/'); process.exit(1); }
if (!fs.readFileSync(index, 'utf8').includes('<base href="/app/">')) { console.error('build/web n\'a pas été compilé avec --base-href /app/'); process.exit(1); }
if (!fs.existsSync(path.join(here, 'dist', 'index.html'))) { console.error('dist/ vide : lance d\'abord node build.mjs'); process.exit(1); }
fs.rmSync(out, { recursive: true, force: true });
fs.cpSync(src, out, { recursive: true });
// fichiers qui n'ont de sens qu'à la racine du domaine
for (const f of ['app-ads.txt', 'app-ads-old.txt']) fs.rmSync(path.join(out, f), { force: true });
console.log('application web copiée dans dist/app/');
