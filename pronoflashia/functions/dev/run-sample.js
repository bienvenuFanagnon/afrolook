'use strict';
const { buildSample } = require('./sample');
(async () => {
  const now = new Date();
  const db = await buildSample(now);
  const ms = db.all('matches');
  console.log('matchs', ms.length, 'avec pronostic', ms.filter((m) => m.prono && m.prono.principal).length, 'terminés', ms.filter((m) => m.statut === 'termine').length);
  console.log('bilan_days', db.all('bilan_days').map((d) => `${d.jour}:${d.delta.principal.n}`).join(' '));
  console.log('jobs en erreur', db.all('jobs').filter((j) => !j.ok).map((j) => j.job + ' ' + j.erreurs.join('|')).slice(0, 5));
  const ex = ms.find((m) => m.prono && m.statut === 'prevu');
  console.log(ex.slug, ex.prono.principal, ex.prono.sourceTexte, ex.prono.marches.length);
})();
