// Régénère les copies JSON lues par le site : règles des diffuseurs et catégories d'annonces. À lancer après « npm run build » (dans functions/).
const fs = require('fs'), path = require('path');
const r = require('../lib/ads/adsRules.js'), c = require('../lib/ads/adsCategories.js');
const out = path.resolve(__dirname, '../../site/src/');
fs.writeFileSync(path.join(out, 'ads_rules.json'), JSON.stringify({ version: r.PUBLISHER_RULES_VERSION, blocks: r.PUBLISHER_RULES }, null, 1) + '\n');
fs.writeFileSync(path.join(out, 'ads_categories.json'), JSON.stringify({ categories: c.AD_CATEGORIES, forbidden: c.FORBIDDEN_CONTENT }, null, 1) + '\n');
console.log('site/src/ads_rules.json et ads_categories.json mis à jour (règles ' + r.PUBLISHER_RULES_VERSION + ')');
