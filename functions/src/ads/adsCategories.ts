/**
 * Catégories d'annonces (comme dans les régies publicitaires). L'ANNONCEUR choisit la catégorie de son annonce (vérifiée par l'équipe à la validation) ;
 * le DIFFUSEUR choisit celles qu'il accepte d'afficher chez lui, et seules celles-là sont diffusées sur son site ou son application.
 *  - « standard » : acceptées par défaut ;
 *  - « sensitive » : jamais diffusées sans accord explicite du diffuseur (finance, paris, alcool, médicaments, rencontres, contenu sensuel…) ;
 *  - interdites : contenu adulte explicite, armes, drogues, arnaques, contenus illégaux : refusées pour tous.
 */
export type CategoryLevel = "standard" | "sensitive";
export interface AdCategory { label: string; level: CategoryLevel; hint?: string }

export const AD_CATEGORIES: Record<string, AdCategory> = {
  // ── standard ──
  commerce: { label: "Commerce et boutiques", level: "standard" },
  restauration: { label: "Restauration et alimentation", level: "standard" },
  mode_beaute: { label: "Mode, beauté, cosmétiques", level: "standard" },
  technologie: { label: "Technologie, applications, sites web", level: "standard" },
  immobilier: { label: "Immobilier et construction", level: "standard" },
  education: { label: "Éducation et formation", level: "standard" },
  emploi: { label: "Emploi et recrutement", level: "standard" },
  evenements: { label: "Événements, musique, spectacles", level: "standard" },
  medias: { label: "Médias et créateurs de contenu", level: "standard" },
  voyage: { label: "Voyage, transport, hôtellerie", level: "standard" },
  auto: { label: "Automobile et moto", level: "standard" },
  telecom: { label: "Télécoms et internet", level: "standard" },
  services: { label: "Services aux particuliers et aux entreprises", level: "standard" },
  sante_bienetre: { label: "Santé et bien-être (sans médicaments)", level: "standard" },
  sport: { label: "Sport et loisirs", level: "standard" },
  association: { label: "Associations, ONG, institutions", level: "standard" },
  // ── sensibles : seulement si le diffuseur les a acceptées ──
  finance: { label: "Finance, crédit, assurance, épargne", level: "sensitive" },
  crypto: { label: "Cryptomonnaies et investissement", level: "sensitive" },
  paris_jeux: { label: "Paris sportifs et jeux d'argent", level: "sensitive" },
  alcool_tabac: { label: "Alcool et tabac", level: "sensitive" },
  medicaments: { label: "Médicaments et produits de santé", level: "sensitive" },
  rencontres: { label: "Rencontres", level: "sensitive" },
  sensuel: { label: "Contenu sensuel (corps dénudé ou suggestif)", level: "sensitive", hint: "Une image qui expose le corps de façon suggestive. Le contenu sexuellement explicite est interdit." },
  politique: { label: "Politique et élections", level: "sensitive" },
  religion: { label: "Religion et spiritualité", level: "sensitive" },
  loterie: { label: "Concours, loteries et tirages", level: "sensitive" },
};

/** Contenus refusés pour tous (jamais proposés dans les formulaires ; rappelés dans les règles). */
export const FORBIDDEN_CONTENT = ["contenu sexuellement explicite", "armes", "drogues", "arnaques et fausses promesses de gains", "contenus illégaux ou haineux"];

export const isCategory = (v: unknown): v is string => typeof v === "string" && Object.prototype.hasOwnProperty.call(AD_CATEGORIES, v);
export const STANDARD_KEYS: string[] = Object.entries(AD_CATEGORIES).filter(([, c]) => c.level === "standard").map(([k]) => k);
export const SENSITIVE_KEYS: string[] = Object.entries(AD_CATEGORIES).filter(([, c]) => c.level === "sensitive").map(([k]) => k);
export const isSensitive = (k: string): boolean => AD_CATEGORIES[k]?.level === "sensitive";

/** Catégories qu'un diffuseur accepte : sa liste (nettoyée), sinon toutes les catégories standard. */
export function cleanAccepted(v: unknown): string[] {
  const list = [...new Set((Array.isArray(v) ? (v as unknown[]) : []).map((x) => String(x ?? "")).filter(isCategory))];
  return list.length ? list : [...STANDARD_KEYS];
}

/**
 * Nos propres plateformes : ce qu'elles acceptent par défaut (modifiable ici, ou plus tard dans l'administration).
 * Les autres catégories sensibles ne s'affichent jamais chez elles.
 */
export const INTERNAL_ACCEPT: Record<string, string[]> = {
  afrolook: [...STANDARD_KEYS, "finance"],
  site: [...STANDARD_KEYS],
  slashatlas: [...STANDARD_KEYS],
  pronoflash: [...STANDARD_KEYS, "paris_jeux"],
  epargneplus: [...STANDARD_KEYS, "finance"],
};

/**
 * Une annonce peut-elle s'afficher chez ce diffuseur ? Annonce sans catégorie (anciennes annonces de l'application) : seulement chez nos plateformes ;
 * chez un diffuseur externe, une annonce sans catégorie n'est jamais diffusée.
 */
export function categoryAllowed(adCategory: string, accepted: ReadonlySet<string>, internal: boolean): boolean {
  if (!adCategory) return internal;
  return accepted.has(adCategory);
}
