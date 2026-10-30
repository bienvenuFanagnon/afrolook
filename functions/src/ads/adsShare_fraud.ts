/**
 * Détection de fraude des partageurs (logique pure, testée). Les clics sont jugés un par un (adsShareGo) ; ici on juge le COMPORTEMENT d'un compte sur les
 * derniers jours : trop de clics refusés, auto-clics, navigateurs trop rapides, doublons répétés.
 *  - « hold »   : soupçon fort → les gains en attente sont bloqués, une alerte part à l'administration ;
 *  - « severe » : fraude évidente → les gains des 30 derniers jours sont RETIRÉS (en attente annulés, pièces déjà versées reprises), le profil est suspendu.
 */
export interface SharerMetrics { total: number; valid: number; invalid: number; self: number; dup: number; tooFast: number }
export const EMPTY_METRICS: SharerMetrics = { total: 0, valid: 0, invalid: 0, self: 0, dup: 0, tooFast: 0 };

export type FraudLevel = "none" | "hold" | "severe";
export const FRAUD = {
  holdMinTotal: 30, holdInvalidRatio: 0.6, holdSelf: 5, holdDup: 30,
  severeMinTotal: 50, severeInvalidRatio: 0.8, severeSelf: 15, severeTooFast: 40,
} as const;

export function detectSharerFraud(m: SharerMetrics): { level: FraudLevel; reasons: string[] } {
  const ratio = m.total > 0 ? m.invalid / m.total : 0, pct = Math.round(ratio * 100);
  const severe: string[] = [], hold: string[] = [];
  if (m.total >= FRAUD.severeMinTotal && ratio >= FRAUD.severeInvalidRatio) severe.push(`${pct} % des clics refusés (${m.invalid} sur ${m.total})`);
  if (m.self >= FRAUD.severeSelf) severe.push(`${m.self} clics sur ses propres liens`);
  if (m.tooFast >= FRAUD.severeTooFast) severe.push(`${m.tooFast} clics de navigateurs sans exécution réelle`);
  if (m.total >= FRAUD.holdMinTotal && ratio >= FRAUD.holdInvalidRatio) hold.push(`${pct} % des clics refusés (${m.invalid} sur ${m.total})`);
  if (m.self >= FRAUD.holdSelf) hold.push(`${m.self} clics sur ses propres liens`);
  if (m.dup >= FRAUD.holdDup) hold.push(`${m.dup} clics en doublon`);
  if (severe.length) return { level: "severe", reasons: severe };
  if (hold.length) return { level: "hold", reasons: hold };
  return { level: "none", reasons: [] };
}

export const addMetrics = (a: SharerMetrics, b: Partial<SharerMetrics>): SharerMetrics => ({
  total: a.total + (Number(b.total) || 0), valid: a.valid + (Number(b.valid) || 0), invalid: a.invalid + (Number(b.invalid) || 0),
  self: a.self + (Number(b.self) || 0), dup: a.dup + (Number(b.dup) || 0), tooFast: a.tooFast + (Number(b.tooFast) || 0),
});

/**
 * Reprise des gains : combien de pièces peut-on reprendre sur le solde, et combien devient une dette remboursée par les prochains gains.
 * Les pièces déjà dépensées ou retirées ne peuvent pas être reprises : le reste est une dette (jamais un solde négatif).
 */
export function clawback(coinsToTake: number, balance: number): { take: number; debt: number } {
  const c = Math.max(0, Math.floor(Number(coinsToTake) || 0)), b = Math.max(0, Math.floor(Number(balance) || 0));
  const take = Math.min(c, b);
  return { take, debt: c - take };
}
