// Mise en place des clés secrètes du retour serveur Tapjoy (à lancer par le PROPRIÉTAIRE, sur son poste).
//
//  - génère 2 clés aléatoires (Android, iPhone) : elles ne sont JAMAIS affichées ni écrites dans le dépôt ;
//  - les pose dans Secret Manager (projet afrolooki) : TAPJOY_CALLBACK_SECRET_ANDROID / TAPJOY_CALLBACK_SECRET_IOS ;
//  - les règle chez Tapjoy (monnaie « Pièces » de chaque application) avec l'adresse de retour serveur ;
//  - efface les fichiers temporaires.
//
// Utilisation (PowerShell, dans le dossier du projet) :
//   $env:TAPJOY_KEY = "<clé d'API de reporting Tapjoy>"
//   node tool/offerwall/setup_secrets.cjs
//   Remove-Item Env:TAPJOY_KEY
// La clé de reporting n'est lue que dans la variable d'environnement ; elle n'est jamais affichée.
// À lancer UNE SEULE FOIS avant le déploiement des fonctions (relancer remplace les deux clés des deux côtés).
// Voir docs/OFFERWALL_TACHES.md §11.
const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');
const { spawnSync } = require('child_process');

const KEY = process.env.TAPJOY_KEY;
if (!KEY) { console.error('Variable TAPJOY_KEY absente : voir les instructions en tête de ce fichier.'); process.exit(1); }
const PROJECT = 'afrolooki';
const CALLBACK_URL = 'https://us-central1-afrolooki.cloudfunctions.net/tapjoyOfferwallCallback';
const HOST = 'https://api.tapjoy.com';
const APPS = [
  { plat: 'ANDROID', currencyId: 'd40e79bb-1a19-43ca-b323-ee44b795fd8b', secret: 'TAPJOY_CALLBACK_SECRET_ANDROID' },
  { plat: 'IOS', currencyId: '1e3800f6-6662-4dc4-a4d4-4b8300a0dc90', secret: 'TAPJOY_CALLBACK_SECRET_IOS' },
];

(async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'afro-ow-'));
  const values = {};
  try {
    // 1. clés aléatoires + Secret Manager
    for (const a of APPS) {
      values[a.plat] = crypto.randomBytes(32).toString('hex');
      const file = path.join(dir, a.secret);
      fs.writeFileSync(file, values[a.plat], { mode: 0o600 });
      const r = spawnSync('firebase', ['functions:secrets:set', a.secret, '--data-file', file, '--project', PROJECT, '--force'], { shell: true, encoding: 'utf8' });
      if (r.status !== 0) throw new Error(`Secret Manager : échec pour ${a.secret} (code ${r.status}) ${String(r.stderr).slice(0, 200)}`);
      console.log(`✔ ${a.secret} posée dans Secret Manager`);
    }
    // 2. Tapjoy : jeton puis adresse de retour + clé secrète de chaque monnaie
    const t = await (await fetch(HOST + '/v1/oauth2/token', { method: 'POST', headers: { Authorization: 'Basic ' + KEY, Accept: 'application/json' } })).json();
    if (!t.access_token) throw new Error('Tapjoy : authentification refusée');
    for (const a of APPS) {
      const r = await fetch(HOST + '/graphql', {
        method: 'POST',
        headers: { Authorization: 'Bearer ' + t.access_token, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          query: 'mutation($i: UpdateCurrencyInput!){ updateCurrency(input: $i) { currency { id name exchangeRate maturity callbackUrl } } }',
          variables: { i: { id: a.currencyId, callbackUrl: CALLBACK_URL, secretKey: values[a.plat] } },
        }),
      });
      const j = await r.json();
      if (j.errors) throw new Error(`Tapjoy ${a.plat} : ${j.errors.map((e) => e.message).join(' ; ')}`);
      const c = j.data.updateCurrency.currency;
      console.log(`✔ Tapjoy ${a.plat} : monnaie « ${c.name} », taux ${c.exchangeRate}, niveau ${c.maturity}, retour serveur ${c.callbackUrl === CALLBACK_URL ? 'réglé' : 'À VÉRIFIER'}`);
    }
    console.log('\nTerminé. Prévenez l\'agent : il peut déployer les fonctions.');
  } finally {
    for (const f of fs.readdirSync(dir)) fs.rmSync(path.join(dir, f), { force: true });
    fs.rmdirSync(dir);
  }
})().catch((e) => { console.error('ÉCHEC :', String(e.message).split(KEY).join('***')); process.exit(1); });
