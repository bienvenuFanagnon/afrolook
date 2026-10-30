// Pose les clés secrètes Pubscale dans Secret Manager (à lancer par le PROPRIÉTAIRE, ou avec son accord).
//
// Pubscale signe chaque retour serveur (conversion et annulation) avec une « Secret Key » propre à chaque application (MD5 de
// clé.user_id.valeur.token). Il y a une clé par plateforme : PUBSCALE_SECRET_ANDROID et PUBSCALE_SECRET_IOS. Chaque clé est lue dans une
// variable d'environnement, écrite dans un fichier temporaire (effacé ensuite) puis envoyée à Secret Manager. Elle n'est jamais affichée ni
// écrite dans le dépôt. Une variable absente = cette plateforme est ignorée (utile tant qu'une seule application est approuvée) ;
// Secret Manager exige pourtant une valeur : une plateforme non configurée reçoit une valeur factice qui ne valide aucune signature.
//
// Utilisation (PowerShell, dans le dossier du projet) :
//   $env:PUBSCALE_SECRET_ANDROID = "<Secret Key de l'application Android>"
//   $env:PUBSCALE_SECRET_IOS = "<Secret Key de l'application iPhone>"      (ou laisser vide)
//   node tool/offerwall/setup_pubscale_secrets.cjs
//   Remove-Item Env:PUBSCALE_SECRET_ANDROID, Env:PUBSCALE_SECRET_IOS
// Voir docs/OFFERWALL_TACHES.md §19.5.
const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const targets = [['PUBSCALE_SECRET_ANDROID', (process.env.PUBSCALE_SECRET_ANDROID || '').trim()], ['PUBSCALE_SECRET_IOS', (process.env.PUBSCALE_SECRET_IOS || '').trim()]];
if (!targets.some(([, v]) => v)) { console.error('Aucune variable PUBSCALE_SECRET_ANDROID / PUBSCALE_SECRET_IOS : voir les instructions en tête de ce fichier.'); process.exit(1); }

const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'afro-pubscale-'));
let failed = false;
try {
  for (const [name, value] of targets) {
    const real = !!value;
    if (!real) {
      // plateforme sans clé : on ne touche jamais à un secret déjà posé (« secrets:get » ne montre que les métadonnées, pas la valeur)
      const exists = spawnSync('firebase', ['functions:secrets:get', name, '--project', 'afrolooki'], { shell: true, encoding: 'utf8' }).status === 0;
      if (exists) { console.log('• ' + name + ' : déjà posée, inchangée.'); continue; }
    }
    const data = real ? value : 'non-configuree-' + crypto.randomBytes(16).toString('hex');
    const file = path.join(dir, name);
    fs.writeFileSync(file, data, { mode: 0o600 });
    const r = spawnSync('firebase', ['functions:secrets:set', name, '--data-file', file, '--project', 'afrolooki', '--force'], { shell: true, encoding: 'utf8' });
    fs.rmSync(file, { force: true });
    if (r.status !== 0) { failed = true; console.error(name + ' : échec (code ' + r.status + ') ' + String(r.stderr).split(data).join('***').slice(0, 300)); continue; }
    console.log('✔ ' + name + (real ? ' posée dans Secret Manager.' : ' : plateforme non configurée (valeur factice).'));
  }
} finally {
  fs.rmdirSync(dir, { recursive: true });
}
if (failed) process.exit(1);
console.log('Prévenez l\'agent : il peut déployer pubscaleOfferwallCallback et pubscaleChargebackCallback.');
