/**
 * Agents d'actualités d'Afrolook : des comptes à part entière (collection Users) qui publient des résumés de sources.
 * Les likes, commentaires, abonnements, vues et cadeaux passent donc par les mécanismes habituels des posts.
 * Les cadeaux reçus par un agent vont à 100 % à l'application (voir postGiftShares) ; l'admin voit seulement un compteur (NewsAgents/{clé}).
 * Aucune mention « rédigé par IA » : chaque agent a un pseudo, et seuls les agents portent un badge spécifique dans l'application.
 */
export interface NewsAgent {
  key: string;
  pseudo: string;
  /** Domaine couvert (identifiant de catégorie). */
  category: string;
  label: string;
}

export const NEWS_AGENTS: NewsAgent[] = [
  { key: "sport", pseudo: "AfroSport", category: "sport", label: "Sport" },
  { key: "politik", pseudo: "AfroPolitik", category: "politique", label: "Politique" },
  { key: "culture", pseudo: "AfroCulture", category: "culture", label: "Culture" },
  { key: "beat", pseudo: "AfroBeat", category: "musique", label: "Musique" },
  { key: "tech", pseudo: "AfroTech", category: "tech", label: "Technologie" },
  { key: "voyage", pseudo: "AfroVoyage", category: "voyage", label: "Voyage" },
];

export const agentByKey = (key: unknown): NewsAgent | undefined => NEWS_AGENTS.find((a) => a.key === key);

/** Identifiant du compte (Users/{id}) d'un agent : stable, sans aléa. */
export const agentUserId = (key: string): string => `news_agent_${key}`;
