'use strict';
// buildRecaps : publie « Le point foot » du jour (article rédigé par l'IA à partir de nos données et des infos de presse, sources citées).

const { buildDailyRecap } = require('../recap/build');
const { loadNewsConfig } = require('./syncNews');

/** opts : { db, providers, now, force } */
async function buildRecaps(opts, report) {
  const cfg = await loadNewsConfig(opts.db);
  if (!cfg.actif || cfg.recaps === false) { report.infos.actif = false; return; }
  const r = await buildDailyRecap(opts);
  report.infos.resultat = r.publie ? 'publié' : r.raison;
  if (r.publie) {
    report.traites = 1;
    report.infos.redaction = r.source;
    report.infos.sources = r.sources;
    if (r.erreurs && r.erreurs.length) report.infos.refus = r.erreurs.slice(0, 4);
  }
}

module.exports = { buildRecaps };
