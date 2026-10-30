/**
 * Indicateurs de fraude du mur de tâches : fonctions pures (testables), utilisées par la page d'administration.
 * Ce sont des INDICES pour aider une personne à décider, jamais une sanction automatique.
 */
export interface EventLite { coins: number; createdAt: number; status: string }

export interface UserActivity {
  events: number;
  coins: number;
  eventsLast24h: number;
  coinsLast24h: number;
  reviewCount: number;
  refusedCount: number;
  /** Âge du compte à la date de l'observation, en jours (null si inconnu). */
  accountAgeDays: number | null;
  /** Nombre de fois où le montant le plus fréquent revient (comportement de « ferme » : mêmes gains répétés). */
  topSameAmountCount: number;
}

export type RiskLevel = "faible" | "moyen" | "élevé";
export interface Risk { score: number; level: RiskLevel; flags: string[] }

const DAY = 86_400_000;
const COUNTED = new Set(["pending", "validee", "en_revue"]);

/** Résumé de l'activité d'un utilisateur à partir de ses événements. */
export function activityFromEvents(events: EventLite[], nowMs: number, userCreatedAt: number | null): UserActivity {
  const since24 = nowMs - DAY;
  let coins = 0, n24 = 0, c24 = 0, review = 0, refused = 0;
  const amounts = new Map<number, number>();
  for (const e of events) {
    const status = String(e.status);
    if (status === "en_revue") review++;
    if (status === "refusee" || status === "refusee_admin") { refused++; continue; }
    if (!COUNTED.has(status)) continue;
    coins += e.coins;
    if (e.createdAt >= since24) { n24++; c24 += e.coins; }
    amounts.set(e.coins, (amounts.get(e.coins) ?? 0) + 1);
  }
  const counted = events.filter((e) => COUNTED.has(String(e.status))).length;
  return {
    events: counted, coins, eventsLast24h: n24, coinsLast24h: c24, reviewCount: review, refusedCount: refused,
    accountAgeDays: userCreatedAt && userCreatedAt > 0 ? Math.max(0, Math.floor((nowMs - userCreatedAt) / DAY)) : null,
    topSameAmountCount: Math.max(0, ...amounts.values()),
  };
}

/** Score de risque (somme de signaux) et explications lisibles. */
export function riskOf(a: UserActivity, cfg: { dailyCapCoins: number }): Risk {
  let score = 0;
  const flags: string[] = [];
  if (a.coinsLast24h >= cfg.dailyCapCoins * 0.9) { score += 2; flags.push("Plafond du jour presque atteint"); }
  if (a.eventsLast24h >= 10) { score += 3; flags.push(`Rafale : ${a.eventsLast24h} tâches en 24 h`); }
  if (a.accountAgeDays !== null && a.accountAgeDays < 7 && a.coins >= 500) { score += 2; flags.push("Compte récent avec des gains élevés"); }
  if (a.reviewCount >= 2) { score += 2; flags.push(`${a.reviewCount} tâches mises en revue`); }
  if (a.refusedCount >= 2) { score += 1; flags.push(`${a.refusedCount} montants refusés`); }
  if (a.topSameAmountCount >= 5) { score += 2; flags.push(`Même gain répété ${a.topSameAmountCount} fois`); }
  return { score, level: score >= 5 ? "élevé" : score >= 2 ? "moyen" : "faible", flags };
}
