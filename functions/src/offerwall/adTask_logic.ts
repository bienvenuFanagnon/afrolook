/**
 * Tâche « Regarder une pub » (notre propre tâche, en attendant les plateformes de tâches ; voir docs/OFFERWALL_TACHES.md §20).
 * La personne regarde une vidéo récompensée (Appodeal, dont AdMob est un réseau de médiation) jusqu'à la fin ; elle reçoit en pièces
 * l'équivalent de ce qu'un visionnage pourrait rapporter : valeur d'une vue = eCPM ÷ 1 000 (eCPM de 1 € → 0,001 € par vue ≈ 1,64 pièce).
 * Les pièces sont entières : les fractions (centièmes de pièce) s'accumulent pour chaque personne et se créditent dès qu'elles font 1 pièce.
 * Aucune part pour le parrain, aucune attente de 48 h (rien n'est annulable côté partenaire).
 */

/** 1 € = 655,957 FCFA (parité fixe du franc CFA) ; 25 pièces = 10 FCFA, donc 2,5 pièces par FCFA (même table que partout dans l'application). */
export const FCFA_PER_EUR = 655.957;
export const COINS_PER_FCFA = 2.5;

export interface AdTaskConfig {
  /** Interrupteur de la tâche (AppConfig/adTask). */
  enabled: boolean;
  /** eCPM de référence en euros (revenu pour 1 000 vues) ; la valeur d'une vue est eCPM ÷ 1 000. Réglable sans nouvelle version de l'application. */
  ecpmEur: number;
  /** Nombre maximal de pubs par personne et par jour (UTC). */
  maxPerDay: number;
  /** Secondes minimales entre deux pubs. */
  gapSec: number;
  /** Secondes minimales entre le départ de la pub et sa déclaration comme regardée (une vidéo récompensée dure plus que cela). */
  minWatchSec: number;
}

export const DEFAULT_ADTASK_CONFIG: AdTaskConfig = { enabled: false, ecpmEur: 1, maxPerDay: 10, gapSec: 30, minWatchSec: 15 };

export function readAdTaskConfig(d: Record<string, unknown> | undefined): AdTaskConfig {
  const o = d ?? {};
  const D = DEFAULT_ADTASK_CONFIG;
  const num = (v: unknown, def: number, min: number, max: number): number => {
    const x = Number(v);
    return Number.isFinite(x) && x >= min && x <= max ? x : def;
  };
  return {
    enabled: o["enabled"] === true, // coupée par défaut : décision du propriétaire (30/10), les pubs ne rapportent plus de pièces ; elles passent seulement avant l'affichage des tâches
    ecpmEur: num(o["ecpmEur"], D.ecpmEur, 0.01, 50),
    maxPerDay: Math.trunc(num(o["maxPerDay"], D.maxPerDay, 1, 100)),
    gapSec: Math.trunc(num(o["gapSec"], D.gapSec, 0, 3600)),
    minWatchSec: Math.trunc(num(o["minWatchSec"], D.minWatchSec, 5, 120)),
  };
}

/** Valeur d'une vue en centièmes de pièce : eCPM 1 € → 0,001 € → 0,656 FCFA → 1,64 pièce → 164. */
export function adTaskHundredths(ecpmEur: number): number {
  const perViewEur = Math.max(0, Number(ecpmEur) || 0) / 1000;
  return Math.max(0, Math.round(perViewEur * FCFA_PER_EUR * COINS_PER_FCFA * 100));
}

/** Ajoute une valeur aux centièmes déjà accumulés : retourne les pièces entières à créditer et le reste à garder. */
export function addHundredths(carry: number, add: number): { coins: number; carry: number } {
  const total = Math.max(0, Math.floor(Number(carry) || 0)) + Math.max(0, Math.floor(Number(add) || 0));
  return { coins: Math.floor(total / 100), carry: total % 100 };
}

/** Une nouvelle pub peut-elle partir maintenant ? Retourne la raison du refus ou null. `waitSec` : attente restante pour l'écart minimum. */
export function adTaskRefusal(
  st: { day: string; count: number; lastAt: number },
  cfg: Pick<AdTaskConfig, "maxPerDay" | "gapSec">,
  today: string,
  nowMs: number,
): { reason: "limite_du_jour" | "trop_tot"; waitSec: number } | null {
  const count = st.day === today ? st.count : 0;
  if (count >= cfg.maxPerDay) return { reason: "limite_du_jour", waitSec: 0 };
  const wait = st.lastAt + cfg.gapSec * 1000 - nowMs;
  if (st.lastAt > 0 && wait > 0) return { reason: "trop_tot", waitSec: Math.ceil(wait / 1000) };
  return null;
}
