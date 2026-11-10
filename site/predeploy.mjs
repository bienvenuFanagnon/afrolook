// Garde-fou lancé par Firebase avant TOUT déploiement du site (firebase.json, cible « vitrine », clé « predeploy »).
// Un seul site sert trois choses sur afrolookmedia.com : la vitrine, Afrolook Ads (/ads/) et l'application web (/app/).
// Elles partent toujours ensemble : si l'une manque dans dist/, le déploiement est refusé (sinon elle disparaît du site en ligne).
// Usage manuel : node predeploy.mjs            (vérifie site/dist)
//                node predeploy.mjs <dossier>  (vérifie un autre dossier, pour les essais)
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const dist = path.resolve(process.argv[2] || path.join(here, 'dist'));
const has = (f) => fs.existsSync(path.join(dist, f));
const size = (f) => (has(f) ? fs.statSync(path.join(dist, f)).size : 0);

const parts = [
  { name: 'la vitrine', need: ['index.html', 'en/index.html', 'telecharger/index.html', 'aide/index.html', 'css/site.css', 'css/v2.css', 'sitemap.xml'] },
  { name: 'Afrolook Ads (/ads/)', need: ['ads/index.html', 'ads/espace/index.html', 'ads/diffuseur/index.html', 'ads/tag.js'] },
  { name: 'l\'application web (/app/)', need: ['app/index.html', 'app/main.dart.js', 'app/flutter_bootstrap.js'] },
];

const problems = [];
for (const p of parts) {
  const missing = p.need.filter((f) => !has(f));
  if (missing.length) problems.push(`${p.name} : il manque ${missing.join(', ')}`);
}
if (has('app/index.html') && !fs.readFileSync(path.join(dist, 'app/index.html'), 'utf8').includes('<base href="/app/">')) {
  problems.push('l\'application web n\'a pas été compilée avec --base-href /app/');
}
if (has('app/main.dart.js') && size('app/main.dart.js') < 1_000_000) {
  problems.push('app/main.dart.js est anormalement petit : la compilation de l\'application web est incomplète');
}

if (problems.length) {
  console.error('\nDÉPLOIEMENT REFUSÉ : le site doit contenir la vitrine, /ads/ et /app/ en même temps.');
  for (const p of problems) console.error('  - ' + p);
  console.error('\nPour tout fabriquer (depuis la racine du projet, dans PowerShell) :');
  console.error('  flutter build web --release --base-href "/app/" --no-tree-shake-icons --no-wasm-dry-run --no-web-resources-cdn');
  console.error('  cd site; node build.mjs; node check.mjs\n');
  process.exit(1);
}
console.log(`site complet : vitrine, /ads/ et /app/ présents dans ${path.relative(process.cwd(), dist) || dist}`);
