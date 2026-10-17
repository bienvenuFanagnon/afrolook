'use strict';
// Images d'aperçu (Open Graph 1200 × 630) pour le partage de la page « À propos » sur WhatsApp, Facebook, X, Telegram.
// Usage : node scripts/make-og.js   (écrit site/img/og-apropos.png et site/img/og-about.png)
const fs = require('fs');
const path = require('path');
const { renderPng } = require('../functions/src/push/card');

const out = (f) => path.join(__dirname, '..', 'site', 'img', f);
const cards = {
  'og-apropos.png': { badge: 'À propos', titre: 'PronoFlash IA : pronostics foot gratuits', lignes: [{ l: 'Une IA qui apprend chaque équipe' }, { l: 'Coupons du jour et alertes' }, { l: 'Bilan public : réussites et ratés' }], pied: 'Sans inscription · aucun gain promis · 18+' },
  'og-about.png': { badge: 'About', titre: 'PronoFlash IA: free football predictions', lignes: [{ l: 'An AI that learns every team' }, { l: 'Slips of the day and alerts' }, { l: 'Public track record: hits and misses' }], pied: 'No sign-up · no promised winnings · 18+' },
};
for (const [f, c] of Object.entries(cards)) { fs.writeFileSync(out(f), renderPng(c, 630)); console.log(f); }
