'use strict';
// Copie les modules partagés (calcul de coupon) dans site/js pour le navigateur. À lancer avant tout déploiement de l'hébergement.
const fs = require('fs');
const path = require('path');
const root = path.join(__dirname, '..');
for (const f of ['goalmarkets.js', 'coupon.js']) {
  fs.copyFileSync(path.join(root, 'functions/src/shared', f), path.join(root, 'site/js', f));
  console.log('copié', f);
}
