/**
 * Afrolook Ads : protections de la régie (logique pure, sans base de données, entièrement testée).
 *  1. Détection d'anomalies sur les plateformes (vues, clics, trafic invalide, appels depuis un autre site, audience) et sur les annonces :
 *     chaque anomalie devient une ALERTE à vérifier par l'administration (gravité « moyenne » ou « haute »).
 *  2. Livraison maîtrisée d'une annonce à budget : arrêt au budget total, lissage dans la journée (une annonce de 1 000 vues ne part pas en
 *     quelques minutes quand 1 000 personnes sont connectées en même temps).
 *  3. Règles du paiement protégé des diffuseurs : seulement sur de l'argent déjà encaissé, retenue avant versement, seuil minimum, jamais
 *     pendant une alerte ouverte ou un blocage (les montants sont calculés ici ; le versement lui-même viendra avec l'offre Réseau).
 */

export type Severity = "medium" | "high";
export type AlertType = "spike" | "ctr_high" | "clicks_no_views" | "invalid_rate" | "foreign_calls" | "audience_over" | "ad_ctr_high" | "ad_clicks_no_views";

export interface Alert { type: AlertType; severity: Severity; message: string; metrics: Record<string, number> }

// ─── Seuils (un seul endroit pour les régler) ───────────────────────────────────────────────────────────────────────

export const GUARD = {
  spikeMinViews: 200, spikeFactor: 4, spikeFactorHigh: 10, spikeNewMinViews: 1000, // pic de vues par rapport à la moyenne des 7 jours précédents
  ctrMinViews: 300, ctrMedium: 0.08, ctrHigh: 0.15,                                 // part de clics anormalement élevée (le normal est autour de 1 %)
  clicksMin: 20,                                                                    // plus de clics que de vues valides (impossible pour un vrai public)
  invalidMinTotal: 200, invalidMedium: 0.1, invalidHigh: 0.25,                      // trafic invalide (mêmes seuils que la santé quotidienne)
  foreignMedium: 50, foreignHigh: 500,                                              // appels avec l'identifiant du site depuis un autre domaine
  adCtrMinViews: 200, adCtrHigh: 0.15, adClicksMin: 30,                             // même contrôle, annonce par annonce
} as const;

const pct = (x: number): string => `${Math.round(x * 1000) / 10} %`;

// ─── 1. Anomalies ───────────────────────────────────────────────────────────────────────────────────────────────────

export interface PubDay {
  valid: number; invalid: number; clicks: number; foreign: number;
  /** moyenne quotidienne des vues valides sur les 7 jours précédents (0 si pas d'historique) */
  baselineValid: number;
  /** audience déclarée par mois et personnes différentes mesurées hier (diffuseurs externes seulement) */
  declaredMonthly?: number; uniquesYesterday?: number;
}

export function detectPubAnomalies(m: PubDay): Alert[] {
  const out: Alert[] = [];
  const total = m.valid + m.invalid;

  if (m.valid >= GUARD.spikeMinViews) {
    const high = m.baselineValid > 0 ? m.valid >= m.baselineValid * GUARD.spikeFactorHigh : m.valid >= GUARD.spikeNewMinViews * 5;
    const med = m.baselineValid > 0 ? m.valid >= m.baselineValid * GUARD.spikeFactor : m.valid >= GUARD.spikeNewMinViews;
    if (high || med) out.push({ type: "spike", severity: high ? "high" : "medium", message: `Pic de vues : ${m.valid} aujourd'hui contre ${Math.round(m.baselineValid)} en moyenne les 7 jours précédents.`, metrics: { valid: m.valid, baseline: Math.round(m.baselineValid) } });
  }
  if (m.valid >= GUARD.ctrMinViews && m.clicks / m.valid > GUARD.ctrMedium) {
    const r = m.clicks / m.valid;
    out.push({ type: "ctr_high", severity: r > GUARD.ctrHigh ? "high" : "medium", message: `Part de clics anormale : ${pct(r)} (${m.clicks} clics pour ${m.valid} vues ; le normal est autour de 1 %).`, metrics: { valid: m.valid, clicks: m.clicks } });
  }
  if (m.clicks >= GUARD.clicksMin && m.valid < m.clicks) {
    out.push({ type: "clicks_no_views", severity: "high", message: `Plus de clics (${m.clicks}) que de vues valides (${m.valid}) : clics fabriqués ou vues non comptées.`, metrics: { valid: m.valid, clicks: m.clicks } });
  }
  if (total >= GUARD.invalidMinTotal && m.invalid / total >= GUARD.invalidMedium) {
    const r = m.invalid / total;
    out.push({ type: "invalid_rate", severity: r >= GUARD.invalidHigh ? "high" : "medium", message: `Trafic invalide : ${pct(r)} des affichages refusés (${m.invalid} sur ${total}).`, metrics: { invalid: m.invalid, total } });
  }
  if (m.foreign >= GUARD.foreignMedium) {
    out.push({ type: "foreign_calls", severity: m.foreign >= GUARD.foreignHigh ? "high" : "medium", message: `${m.foreign} appels avec l'identifiant de cette plateforme depuis un autre domaine (identifiant copié ou détourné).`, metrics: { foreign: m.foreign } });
  }
  if (m.declaredMonthly && m.uniquesYesterday && m.uniquesYesterday > m.declaredMonthly) {
    out.push({ type: "audience_over", severity: "high", message: `${m.uniquesYesterday} personnes différentes en une seule journée, plus que l'audience mensuelle déclarée (${m.declaredMonthly}).`, metrics: { uniques: m.uniquesYesterday, declared: m.declaredMonthly } });
  }
  return out;
}

export interface AdDay { views: number; clicks: number }
export function detectAdAnomalies(m: AdDay): Alert[] {
  const out: Alert[] = [];
  if (m.clicks >= GUARD.adClicksMin && m.views < m.clicks) out.push({ type: "ad_clicks_no_views", severity: "high", message: `Cette annonce a plus de clics (${m.clicks}) que de vues (${m.views}) sur cette plateforme.`, metrics: { views: m.views, clicks: m.clicks } });
  else if (m.views >= GUARD.adCtrMinViews && m.clicks >= GUARD.adClicksMin && m.clicks / m.views > GUARD.adCtrHigh) out.push({ type: "ad_ctr_high", severity: "medium", message: `Part de clics anormale sur cette annonce : ${pct(m.clicks / m.views)} (${m.clicks} clics pour ${m.views} vues).`, metrics: { views: m.views, clicks: m.clicks } });
  return out;
}

/** Une gravité plus forte remplace une plus faible pour une même alerte du jour. */
export const worse = (a: Severity, b: Severity): Severity => (a === "high" || b === "high" ? "high" : "medium");

// ─── 2. Livraison maîtrisée ─────────────────────────────────────────────────────────────────────────────────────────

export interface Delivery { budgetViews?: number; startMs?: number; endMs?: number; viewsTotal: number; viewsToday: number }
const DAY_MS = 86_400_000;
/** Marge du lissage : une journée peut dépasser de 25 % sa part pour absorber les pics normaux. */
export const PACING_MARGIN = 1.25;

/**
 * Une annonce SANS budget (offre gratuite) est toujours livrable. Une annonce avec budget total (en vues payées) s'arrête quand il est atteint,
 * et ne livre pas plus que sa part du jour (budget ÷ nombre de jours × 1,25) : le budget dure toute la campagne au lieu de partir en une heure.
 */
export function deliveryAllowed(d: Delivery): boolean {
  if (!d.budgetViews || d.budgetViews <= 0) return true;
  if (d.viewsTotal >= d.budgetViews) return false;
  if (d.startMs && d.endMs && d.endMs > d.startMs) {
    const days = Math.max(1, Math.ceil((d.endMs - d.startMs) / DAY_MS));
    const dailyCap = Math.ceil((d.budgetViews / days) * PACING_MARGIN);
    if (d.viewsToday >= dailyCap) return false;
  }
  return true;
}

// ─── 3. Paiement protégé des diffuseurs (calculs ; le versement viendra avec l'offre Réseau) ────────────────────────

export const PUBLISHER_SHARE = 0.65;   // part du diffuseur sur les affichages valides de l'offre Réseau
export const PAYOUT_HOLD_DAYS = 30;     // retenue avant versement : laisse le temps aux contrôles et aux rétrofacturations de carte
export const MIN_PAYOUT_FCFA = 5000;    // seuil minimum de versement

/** Remise de lancement de l'offre Réseau (décision du propriétaire, 30/10) : -30 % sur le prix payé par l'annonceur pendant 1 mois à partir de l'ouverture. La part du diffuseur (65 %) se calcule sur le prix réellement payé. */
export const LAUNCH_DISCOUNT = { pct: 30, days: 30 } as const;
/** Prix pour 1 000 vues après la remise de lancement : `openedAtMs` = jour d'ouverture de l'offre Réseau (null = pas encore ouverte : prix normal). */
export function priceAfterDiscount(cpm: number, openedAtMs: number | null, nowMs: number): number {
  if (openedAtMs === null || nowMs < openedAtMs || nowMs >= openedAtMs + LAUNCH_DISCOUNT.days * DAY_MS) return cpm;
  return Math.round(cpm * (100 - LAUNCH_DISCOUNT.pct)) / 100;
}

/** Gain du diffuseur en FCFA pour des vues valides d'un format payant (arrondi à l'unité inférieure, jamais au-dessus). */
export const earningFcfa = (validViews: number, cpm: number, share = PUBLISHER_SHARE): number => Math.floor((Math.max(0, validViews) / 1000) * cpm * share);

/** Jour (AAAA-MM-JJ) à partir duquel un gain d'un jour donné devient versable. */
export function releaseDay(day: string, holdDays = PAYOUT_HOLD_DAYS): string {
  const t = Date.parse(`${day}T00:00:00Z`);
  return new Date(t + holdDays * DAY_MS).toISOString().slice(0, 10);
}

export interface PayoutInput {
  earnings: Array<{ day: string; fcfa: number }>;   // gains cumulés par jour
  today: string;
  advertiserFundsFcfa: number;                       // argent réellement encaissé et non dépensé qui couvre ces gains
  openAlert: boolean;                                // alerte ouverte ou blocage sur cette plateforme
  verified: boolean;                                 // site vérifié ou application attestée
  alreadyPaidFcfa?: number;
}
/** Montant versable aujourd'hui : gains arrivés à échéance, bornés par l'argent encaissé, 0 en cas d'alerte, de plateforme non vérifiée ou sous le seuil. */
export function payable(i: PayoutInput): number {
  if (i.openAlert || !i.verified) return 0;
  const due = i.earnings.filter((e) => releaseDay(e.day) <= i.today).reduce((n, e) => n + Math.max(0, e.fcfa), 0) - (i.alreadyPaidFcfa ?? 0);
  const amount = Math.min(due, Math.max(0, i.advertiserFundsFcfa));
  return amount >= MIN_PAYOUT_FCFA ? amount : 0;
}
