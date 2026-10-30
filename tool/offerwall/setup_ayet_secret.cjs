// Pose la clé d'API ayeT-Studios dans Secret Manager (à lancer par le PROPRIÉTAIRE, ou avec son accord).
//
// ayeT signe chaque retour serveur avec cette clé (HMAC-SHA256, en-tête X-Ayetstudios-Security-Hash) : le serveur en a besoin pour
// vérifier que l'appel vient bien d'ayeT. La clé est lue dans la variable d'environnement AYET_KEY, écrite dans un fichier temporaire
// (effacé ensuite) puis envoyée à Secret Manager sous le nom AYET_API_KEY. Elle n'est jamais affichée ni écrite dans le dépôt.
//
// Utilisation (PowerShell, dans le dossier du projet) :
//   $env:AYET_KEY = "<clé d'API ayeT : tableau de bord ayeT > Account Settings > API Key>"
//   node tool/offerwall/setup_ayet_secret.cjs
//   Remove-Item Env:AYET_KEY
// Voir docs/OFFERWALL_TACHES.md §11 et §17.
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const KEY = (process.env.AYET_KEY || '').trim();
if (!KEY) { console.error('Variable AYET_KEY absente : voir les instructions en tête de ce fichier.'); process.exit(1); }
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'afro-ayet-'));
const file = path.join(dir, 'AYET_API_KEY');
try {
  fs.writeFileSync(file, KEY, { mode: 0o600 });
  const r = spawnSync('firebase', ['functions:secrets:set', 'AYET_API_KEY', '--data-file', file, '--project', 'afrolooki', '--force'], { shell: true, encoding: 'utf8' });
  if (r.status !== 0) { console.error('Secret Manager : échec (code ' + r.status + ') ' + String(r.stderr).split(KEY).join('***').slice(0, 300)); process.exit(1); }
  console.log('✔ AYET_API_KEY posée dans Secret Manager. Prévenez l\'agent : il peut déployer la fonction ayetOfferwallCallback.');
} finally {
  fs.rmSync(file, { force: true });
  fs.rmdirSync(dir);
}
