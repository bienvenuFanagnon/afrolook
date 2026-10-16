'use strict';
// Pronostic « à données limitées » : un drapeau honnête, pas un détecteur de surprises.
// Mesuré sur 3 090 matchs réels (5 championnats, 2 saisons, walk-forward) : le calcul est bien calibré (52,1 % de réussite du pronostic
// pour 51,8 % annoncés) et aucun signal statistique n'annonce les surprises (désaccord entre modèles, probabilité de nul, niveau des équipes :
// rien de significatif). Seul un début de saison (moins de 8 matchs joués par une équipe) montre un recul net : −3,9 points de réussite
// (292 matchs). Ces matchs sont signalés et écartés des coupons proposés ; les autres limites (blessés, changement d'entraîneur) viendront de l'actualité.

const MIN_SAMPLE = 8;

/**
 * echantillon : plus petit nombre de matchs de la saison joués par l'une des deux équipes.
 * equipeInconnue : le moteur de notes est actif mais l'une des équipes n'a pas de note (promue, nouvelle).
 * Renvoie { raisons: [...] } ou null.
 */
function assess({ echantillon, equipeInconnue }) {
  const raisons = [];
  if (echantillon != null && echantillon < MIN_SAMPLE) raisons.push('echantillon');
  if (equipeInconnue) raisons.push('equipe_inconnue');
  return raisons.length ? { raisons } : null;
}

const isFragile = (m) => !!(m && m.prono && m.prono.fragile);

module.exports = { assess, isFragile, MIN_SAMPLE };
