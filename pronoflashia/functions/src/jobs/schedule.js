'use strict';
// Planning des tâches automatiques : source unique pour index.js (planificateur) et pour l'écran « Fonctionnement » de l'admin.

const SCHEDULE = [
  { nom: 'syncFixtures', cron: '0 5 * * *', frequence: 'Chaque jour à 05:00 UTC', role: 'Récupère les matchs des 7 prochains jours et l\'historique de la saison (1 requête par championnat), puis lance aussitôt le calcul des pronostics.' },
  { nom: 'buildPredictions', cron: '20 6-23,0-2 * * *', frequence: 'Toutes les heures à :20, de 06:20 à 02:20 UTC', role: 'Calcule les probabilités (modèle statistique), choisit le pronostic, puis fait rédiger l\'analyse par l\'IA en français et en anglais. Matchs à moins de 24 h : toutes les 3 h ; autres : une fois par jour. Texte réutilisé si le pronostic n\'a pas vraiment changé.' },
  { nom: 'syncResults', cron: '*/30 12-23,0-2 * * *', frequence: 'Toutes les 30 min, de 12:00 à 02:30 UTC', role: 'Enregistre les scores finaux et les statistiques de match, marque chaque pari réussi ou raté, alimente le bilan.' },
  { nom: 'aiHealthCheck', cron: '*/30 * * * *', frequence: 'Toutes les 30 min', role: 'Envoie un petit message de test à chaque IA et met à jour le voyant de l\'admin.' },
  { nom: 'syncNews', cron: '40 */2 * * *', frequence: 'Toutes les 2 heures à :40', role: 'Lit les flux des sites de football (titre, site, lien), repère les équipes citées et alimente la bande « Actus foot ». Aucun texte d\'article n\'est conservé.' },
  { nom: 'sendPush', cron: '*/15 6-22 * * *', frequence: 'Toutes les 15 min, de 06:00 à 22:45 UTC', role: 'Notifications : coupons du jour (≈ 07:30 UTC), pronostic le plus confiant (≈ 12:30), coupon du soir (≈ 16:30), chacun une seule fois par jour ; alerte environ une heure avant les matchs des équipes suivies (2 par jour et par abonné au plus).' },
  { nom: 'weeklyReport', cron: '0 3 * * 1', frequence: 'Chaque lundi à 03:00 UTC', role: 'Fige le bilan de la semaine passée : visites, pays, pronostics, taux de réussite.' },
];

/** Valeurs d'un champ cron (« * », « *\/30 », « 6-23,0-2 », « 5 »). */
function fieldValues(expr, min, max) {
  const out = new Set();
  for (const part of String(expr).split(',')) {
    const [range, stepS] = part.split('/');
    const step = stepS ? parseInt(stepS, 10) : 1;
    let a = min, b = max;
    if (range !== '*') { const [x, y] = range.split('-').map((v) => parseInt(v, 10)); a = x; b = y == null ? (stepS ? max : x) : y; }
    for (let v = a; v <= b; v += step) out.add(v);
  }
  return out;
}

/** Prochain passage (UTC) d'une expression cron à 5 champs, après `from`. */
function nextRun(cron, from) {
  const [mi, h, dom, mo, dow] = cron.trim().split(/\s+/);
  const M = fieldValues(mi, 0, 59), H = fieldValues(h, 0, 23), DOM = fieldValues(dom, 1, 31), MO = fieldValues(mo, 1, 12), DOW = fieldValues(dow, 0, 6);
  const t = new Date(Math.floor(from.getTime() / 60000) * 60000 + 60000);
  for (let i = 0; i < 60 * 24 * 8; i++) {
    if (M.has(t.getUTCMinutes()) && H.has(t.getUTCHours()) && DOM.has(t.getUTCDate()) && MO.has(t.getUTCMonth() + 1) && DOW.has(t.getUTCDay())) return t;
    t.setTime(t.getTime() + 60000);
  }
  return null;
}

module.exports = { SCHEDULE, nextRun, fieldValues };
