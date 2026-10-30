/**
 * Campagnes « Partage et gagne » : tarif, budget, contrôle de l'audience, règles et profil du partageur (logique pure, testée).
 * Les campagnes WhatsApp sont des MISSIONS réservées à notre application : elles ne sont jamais servies par les sites ou applications partenaires
 * (collection à part : ShareCampaigns, jamais lue par le moteur de diffusion).
 */

/** Part du prix du clic reversée au partageur (le reste est la marge d'Afrolook Ads, jamais affichée). */
export const DEFAULT_USER_PCT = 60;
/** Part des personnes atteintes qui cliquent, pour estimer combien de clics une audience peut apporter (réglable : AppConfig/share.expectedCtr). */
export const DEFAULT_EXPECTED_CTR = 0.02;
export const MIN_CPC_FCFA = 8;          // prix minimum du clic payé par l'annonceur (≈ 5 F pour le partageur à 60 %)
export const MIN_BUDGET_FCFA = 5000;
export const MAX_BUDGET_FCFA = 5_000_000;

export interface CampaignPricing { cpcFcfa: number; userFcfa: number; budgetFcfa: number }
/** Prix d'une campagne : le partageur reçoit [userPct] % du prix du clic ; le budget est dépensé au prix du clic payé par l'annonceur. */
export function pricingOf(c: { cpcFcfa?: unknown; budgetFcfa?: unknown; userFcfa?: unknown }, userPct = DEFAULT_USER_PCT): CampaignPricing {
  const cpc = Math.max(0, Number(c.cpcFcfa) || 0), budget = Math.max(0, Number(c.budgetFcfa) || 0);
  const explicit = Number(c.userFcfa);
  return { cpcFcfa: cpc, budgetFcfa: budget, userFcfa: Number.isFinite(explicit) && explicit > 0 ? explicit : Math.floor(cpc * userPct) / 100 };
}
/** Clics valides encore finançables. */
export const remainingClicks = (budgetFcfa: number, spentFcfa: number, cpcFcfa: number): number => (cpcFcfa > 0 ? Math.max(0, Math.floor((budgetFcfa - spentFcfa + 1e-9) / cpcFcfa)) : 0);

/**
 * La campagne peut-elle accueillir de nouveaux partageurs ? Chaque partageur apporte une audience (validée par l'équipe) ; avec un taux de clic attendu,
 * quand l'audience déjà engagée suffit à épuiser le budget (avec une marge de 50 %), on ferme les nouvelles participations : personne ne partage pour rien.
 * Les liens déjà créés continuent de compter jusqu'à l'épuisement du budget.
 */
export function campaignOpenForNewSharers(allocatedReach: number, remaining: number, expectedCtr = DEFAULT_EXPECTED_CTR): boolean {
  if (remaining <= 0) return false;
  return Math.max(0, allocatedReach) * expectedCtr < remaining * 1.5;
}

// ─── Profil du partageur (diffuseur WhatsApp) ────────────────────────────────────────────────────────────────────────────

export const SHARE_RULES_VERSION = "2026-10-30";
export const SHARE_RULES: Array<{ title: string; items: string[] }> = [
  { title: "1. Ton profil et ton audience", items: [
    "Tu déclares honnêtement ton audience : le nombre de personnes qui voient ton statut WhatsApp, la taille de tes groupes et canaux (WhatsApp, Telegram…) et tes autres réseaux. Notre équipe valide ton profil avant ta première mission.",
    "L'audience retenue est fixée par l'équipe et ne dépasse jamais la déclarée. Une audience gonflée ou fausse entraîne le refus ou la suspension du profil.",
  ] },
  { title: "2. Les missions", items: [
    "Une mission = partager une annonce avec ton lien personnel, où tu veux : statut WhatsApp, groupes ou canaux WhatsApp et Telegram, Facebook, TikTok… Le lien est suivi partout où il est partagé et cliqué. Tu publies toi-même : rien n'est envoyé automatiquement.",
    "La mention « Pub » reste dans la légende. Tu ne partages que dans les groupes où les annonces sont permises et tu respectes leurs règles.",
    "Pas de spam : tu n'envoies jamais en masse à des personnes qui ne t'ont rien demandé.",
  ] },
  { title: "3. Gains et contrôles", items: [
    "SEULS LES CLICS VALIDES SONT PAYÉS : une vraie personne sur un vrai navigateur, un seul clic compté par personne et par campagne (aucun doublon, même si elle clique plusieurs fois ou passe par les liens d'autres partageurs), jamais toi-même, dans les pays visés.",
    "Les gains restent « en attente » pendant la retenue (72 h par défaut) puis deviennent des pièces. Un plafond par jour s'applique.",
    "Chaque fraude est détectée automatiquement et n'est pas comptabilisée : clics répétés, robots, clics sur tes propres liens, navigateurs truqués, liens détournés. Un compte suspect voit ses gains bloqués.",
    "UN GAIN PEUT ÊTRE RETIRÉ : si nos robots détectent une fraude venant de ton compte, les gains en attente sont annulés, les pièces déjà versées sont reprises (ainsi que la commission de parrainage associée) et ton profil peut être suspendu. Tu es prévenu avec le motif.",
  ] },
  { title: "4. Données", items: [
    "Le lien est suivi pour compter les clics, sans cookie ni suivi d'un site à l'autre. Nous gardons tes déclarations d'audience pour valider ton profil.",
  ] },
];

export interface SharerProfileInput { whatsapp: string; country: string; city: string; statusAudience: number; telegramAudience: number; otherAudience: number; groups: Array<{ name: string; members: number }>; about: string }
export function validateSharerProfile(raw: unknown): { ok: true; value: SharerProfileInput } | { ok: false; error: string } {
  const d = (raw ?? {}) as Record<string, unknown>;
  const clean = (v: unknown, n: number): string => String(v ?? "").replace(/<[^>]*>/g, "").replace(/[\u0000-\u001f<>]/g, " ").replace(/\s+/g, " ").trim().slice(0, n);
  const whatsapp = String(d["whatsapp"] ?? "").replace(/[\s().-]/g, "");
  if (!/^\+\d{8,15}$/.test(whatsapp)) return { ok: false, error: "numéro WhatsApp invalide (format +22890123456)" };
  const country = String(d["country"] ?? "").toUpperCase();
  if (!/^[A-Z]{2}$/.test(country)) return { ok: false, error: "pays invalide" };
  const statusAudience = Math.trunc(Number(d["statusAudience"]));
  if (!Number.isFinite(statusAudience) || statusAudience < 0 || statusAudience > 50_000) return { ok: false, error: "audience du statut invalide (0 à 50 000)" };
  const groupsRaw = Array.isArray(d["groups"]) ? (d["groups"] as unknown[]).slice(0, 15) : [];
  const groups: Array<{ name: string; members: number }> = [];
  for (const g of groupsRaw) {
    const o = (g ?? {}) as Record<string, unknown>, members = Math.trunc(Number(o["members"])), name = clean(o["name"], 40);
    if (!name || !Number.isFinite(members) || members < 1 || members > 1024) return { ok: false, error: "chaque groupe a un nom et entre 1 et 1 024 membres" };
    groups.push({ name, members });
  }
  const intIn = (v: unknown, max: number): number => { const x = Math.trunc(Number(v ?? 0)); return Number.isFinite(x) && x >= 0 ? Math.min(x, max) : 0; };
  const telegramAudience = intIn(d["telegramAudience"], 500_000), otherAudience = intIn(d["otherAudience"], 500_000);
  if (statusAudience + telegramAudience + otherAudience + groups.reduce((n, g) => n + g.members, 0) < 20) return { ok: false, error: "audience trop faible : au moins 20 personnes (statut et groupes)" };
  const about = clean(d["about"], 400);
  if (about.length < 20) return { ok: false, error: "présente ton audience en 20 caractères au moins (qui sont-ils, que partages-tu d'habitude ?)" };
  if (d["acceptTerms"] !== true) return { ok: false, error: "règles à accepter" };
  if (d["rulesVersion"] !== SHARE_RULES_VERSION) return { ok: false, error: "regles_a_accepter" };
  return { ok: true, value: { whatsapp, country, city: clean(d["city"], 60), statusAudience, telegramAudience, otherAudience, groups, about } };
}
/** Audience déclarée totale (statut + membres des groupes). */
export const declaredReach = (p: { statusAudience?: unknown; telegramAudience?: unknown; otherAudience?: unknown; groups?: unknown }): number =>
  (Number(p.statusAudience) || 0) + (Number(p.telegramAudience) || 0) + (Number(p.otherAudience) || 0) + (Array.isArray(p.groups) ? (p.groups as Array<{ members?: unknown }>).reduce((n, g) => n + (Number(g?.members) || 0), 0) : 0);

// ─── Vente à l'AUDIENCE : l'annonceur paie le nombre de personnes à atteindre ───────────────────────────────────────────────

/** Prix pour 1 000 personnes d'audience engagée (réglable : AppConfig/share.audiencePricePer1000Fcfa ; à valider par le propriétaire). */
export const DEFAULT_AUDIENCE_PRICE_PER_1000 = 500;
export const MIN_TARGET_AUDIENCE = 1000;
export const MAX_TARGET_AUDIENCE = 5_000_000;

export interface AudiencePricing { priceFcfa: number; payoutBudgetFcfa: number; maxClicks: number }
/**
 * Prix d'une campagne et plafonds. L'annonceur paie `targetAudience` personnes à atteindre ; les gains versés aux partageurs sont plafonnés à `userPct` % de ce
 * prix (la campagne s'arrête quand ce plafond est atteint) et la campagne se ferme aux nouveaux partageurs quand l'audience engagée atteint l'audience achetée.
 */
export function audiencePricing(targetAudience: number, per1000: number, userPct: number, userFcfaPerClick: number): AudiencePricing {
  const priceFcfa = Math.round((Math.max(0, targetAudience) / 1000) * Math.max(0, per1000));
  const payoutBudgetFcfa = Math.floor((priceFcfa * Math.max(0, Math.min(100, userPct))) / 100);
  return { priceFcfa, payoutBudgetFcfa, maxClicks: userFcfaPerClick > 0 ? Math.floor(payoutBudgetFcfa / userFcfaPerClick) : 0 };
}
/** La campagne accepte-t-elle de nouveaux partageurs ? Seulement tant que l'audience engagée n'a pas atteint l'audience achetée et que le plafond de gains n'est pas épuisé. */
export const campaignOpen = (allocatedReach: number, targetAudience: number, remainingClicksLeft: number): boolean => remainingClicksLeft > 0 && Math.max(0, allocatedReach) < Math.max(0, targetAudience);
