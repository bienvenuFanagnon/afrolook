/**
 * Quand recalculer le score du créateur et du canal après un changement sur un post ?
 *
 * Le score du créateur (et du canal) est la moyenne des 30 derniers posts : la recalculer coûte 30 lectures (60 pour un post de canal).
 * Or le score d'un post bouge à chaque vue (+0,5 point d'interaction) : un post populaire a été recalculé 185 fois en 24 h.
 * On ne propage donc que si le score du post a changé de façon visible depuis la dernière propagation (champ `propagatedScore` du post) :
 * au moins 0,25 point et au moins 10 % ; l'écart s'accumule, donc plusieurs petites variations finissent toujours par se propager.
 * Le calcul hebdomadaire (`applyActivityDecay`) remet de toute façon tous les scores créateurs à jour.
 */
export const PROPAGATE_MIN_DELTA = 0.25;
export const PROPAGATE_MIN_RATIO = 0.1;

export function shouldPropagate(lastPropagated: unknown, score: number): boolean {
  if (typeof lastPropagated !== "number" || !Number.isFinite(lastPropagated)) return true; // première fois
  return Math.abs(score - lastPropagated) >= Math.max(PROPAGATE_MIN_DELTA, Math.abs(lastPropagated) * PROPAGATE_MIN_RATIO);
}
