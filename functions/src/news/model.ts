import { NEWS_AGENTS, agentByKey, agentUserId } from "./agents";
import { Continent, CONTINENTS, NewsLevel, NEWS_LEVELS, continentOf, scopeKey } from "./geo";

/**
 * Article d'actualité = résumé de plusieurs sources (jamais une copie) : titre, chapô, quelques sections, « À retenir » et la liste des sources
 * (nom + lien, au moins une). Ce fichier ne contient que des fonctions pures : validation de l'entrée et construction des documents Firestore.
 */
/**
 * Durée de vie d'un article : il disparaît de l'application quand elle est écoulée (l'actualité vieillit vite). Le sport se périme en quelques jours,
 * les sujets de fond (voyage, culture, tech) durent plus longtemps. Un article très commenté ou très aimé est prolongé une fois (×1,5 ou ×2), dans la
 * limite de 45 jours. L'administrateur peut le supprimer ou le prolonger à tout moment.
 */
export const DAY_MS = 86_400_000;
export const LIFESPAN_DAYS: Record<string, number> = { sport: 4, politique: 7, culture: 14, musique: 10, tech: 14, voyage: 21 };
export const MAX_LIFE_DAYS = 45;
export const lifespanDays = (category: string): number => LIFESPAN_DAYS[category] ?? 7;

/** Prolongation selon l'engagement : j'aime + 2 × commentaires + 3 × cadeaux. */
export function popularityBonus(p: { loves?: unknown; comments?: unknown; giftCount?: unknown }): number {
  const score = (Number(p.loves) || 0) + 2 * (Number(p.comments) || 0) + 3 * (Number(p.giftCount) || 0);
  return score >= 200 ? 2 : score >= 50 ? 1.5 : 1;
}

export type ExpiryDecision = { action: "keep" } | { action: "extend"; expiresAt: number; tier: number } | { action: "delete" };

/** Que faire d'un article à cet instant : le garder, le prolonger (une fois par palier de popularité) ou le supprimer. */
export function decideExpiry(post: Record<string, unknown>, nowMs: number): ExpiryDecision {
  const rawCreated = Number(post["created_at"]) || 0;
  const createdMs = rawCreated > 1e14 ? Math.floor(rawCreated / 1000) : rawCreated; // created_at est en microsecondes
  const news = (post["news"] ?? {}) as Record<string, unknown>;
  const base = Number(news["lifeDays"]) > 0 ? Number(news["lifeDays"]) : lifespanDays(String(news["category"] ?? ""));
  if (createdMs && nowMs - createdMs > MAX_LIFE_DAYS * DAY_MS) return { action: "delete" };
  const exp = Number(post["expiresAt"]) || (createdMs ? createdMs + base * DAY_MS : 0);
  if (exp > nowMs) return { action: "keep" };
  const bonus = popularityBonus(post);
  const tier = Number(post["extendedTier"]) || 1;
  if (bonus > tier && createdMs) {
    const next = Math.min(createdMs + base * bonus * DAY_MS, createdMs + MAX_LIFE_DAYS * DAY_MS);
    if (next > nowMs) return { action: "extend", expiresAt: next, tier: bonus };
  }
  return { action: "delete" };
}

export const expiresAtFor = (n: { category: string; lifeDays: number | null }, nowMs: number): number => nowMs + (n.lifeDays ?? lifespanDays(n.category)) * DAY_MS;

export const LANGS = ["fr", "en", "es", "de", "ar", "pt", "zh", "sw"] as const;
export type NewsLang = (typeof LANGS)[number];

export interface NewsSource { name: string; url: string }
export interface NewsSection { titre: string; texte: string }

/** Article validé et normalisé, prêt à être publié. */
export interface NewsClean {
  agentKey: string;
  category: string;
  level: NewsLevel;
  country: string | null;
  continent: Continent | null;
  scope: string;
  lang: NewsLang;
  title: string;
  chapo: string;
  sections: NewsSection[];
  retenir: string[];
  sources: NewsSource[];
  image: string;
  score: number;
  /** Texte de la notification de cet article (écrit par l'IA avec le résumé) ; utilisé par les notifications d'actualités. */
  notif: { title: string; body: string } | null;
  /** Durée de vie imposée (jours) ; sinon celle du domaine. */
  lifeDays: number | null;
}

/** Entrée d'un élément de l'index du fil (NewsFeed/{périmètre}) : de quoi afficher une carte sans lire le post. */
export interface NewsFeedItem {
  id: string;
  agentKey: string;
  category: string;
  level: NewsLevel;
  country: string | null;
  continent: Continent | null;
  title: string;
  chapo: string;
  image: string;
  sourceCount: number;
  sourceNames: string[];
  at: number;
  /** Importance au départ (sert à choisir « À la une »). */
  score: number;
  /** Texte de notification écrit par l'IA avec le résumé (pour les notifications d'actualités). */
  notif: { title: string; body: string } | null;
  /** Fin de vie de l'article (ms) : l'application ne montre plus l'article passé cette date. */
  exp: number;
}

export const MAX_FEED_ITEMS = 30;

const clip = (v: unknown): string => String(v ?? "").replace(/[ \t]+/g, " ").trim();
const clipBlock = (v: unknown): string => String(v ?? "").replace(/[ \t]+/g, " ").replace(/\n{3,}/g, "\n\n").trim();

/** Adresse https sans identifiants, de 500 caractères au plus ; sinon chaîne vide. */
export function cleanUrl(v: unknown): string {
  const s = String(v ?? "").trim();
  if (s.length > 500 || !/^https:\/\//i.test(s)) return "";
  try {
    const u = new URL(s);
    if (u.username || u.password || !u.hostname.includes(".")) return "";
    return u.toString();
  } catch {
    return "";
  }
}

type Result = { ok: true; value: NewsClean } | { ok: false; error: string };

export function cleanNewsInput(raw: unknown): Result {
  const r = (raw ?? {}) as Record<string, unknown>;
  const agent = agentByKey(r["agentKey"]);
  if (!agent) return { ok: false, error: `Agent inconnu (${NEWS_AGENTS.map((a) => a.key).join(", ")})` };

  const level = String(r["level"] ?? "") as NewsLevel;
  if (!NEWS_LEVELS.includes(level)) return { ok: false, error: "Niveau invalide (country, continent ou world)" };

  const countryRaw = String(r["country"] ?? "").trim().toUpperCase();
  const country = /^[A-Z]{2}$/.test(countryRaw) ? countryRaw : null;
  let continent: Continent | null = null;
  const contRaw = String(r["continent"] ?? "").trim().toUpperCase();
  if ((CONTINENTS as readonly string[]).includes(contRaw)) continent = contRaw as Continent;
  if (!continent && country) continent = continentOf(country);
  if (level === "country" && !country) return { ok: false, error: "Un article « pays » demande un code pays à 2 lettres" };
  if (level === "continent" && !continent) return { ok: false, error: "Un article « continent » demande un continent (AF, EU, AS, NA, SA, OC)" };
  const scope = scopeKey(level, country, continent);
  if (!scope) return { ok: false, error: "Périmètre invalide" };

  const title = clip(r["title"]);
  if (title.length < 10 || title.length > 140) return { ok: false, error: "Titre : 10 à 140 caractères" };
  const chapo = clip(r["chapo"]);
  if (chapo.length < 40 || chapo.length > 320) return { ok: false, error: "Chapô : 40 à 320 caractères" };

  const rawSections = Array.isArray(r["sections"]) ? (r["sections"] as unknown[]) : [];
  const sections: NewsSection[] = [];
  for (const s of rawSections.slice(0, 6)) {
    const o = (s ?? {}) as Record<string, unknown>;
    const texte = clipBlock(o["texte"]);
    if (texte.length < 40) continue;
    sections.push({ titre: clip(o["titre"]).slice(0, 80), texte: texte.slice(0, 1500) });
  }
  if (!sections.length) return { ok: false, error: "Au moins une section de 40 caractères ou plus" };

  const retenir = (Array.isArray(r["retenir"]) ? (r["retenir"] as unknown[]) : []).map((x) => clip(x).slice(0, 160)).filter((x) => x.length >= 5).slice(0, 5);

  const seen = new Set<string>();
  const sources: NewsSource[] = [];
  for (const s of (Array.isArray(r["sources"]) ? (r["sources"] as unknown[]) : []).slice(0, 8)) {
    const o = (s ?? {}) as Record<string, unknown>;
    const url = cleanUrl(o["url"]);
    const name = clip(o["name"]).slice(0, 60);
    if (!url || name.length < 2 || seen.has(url)) continue;
    seen.add(url);
    sources.push({ name, url });
  }
  if (!sources.length) return { ok: false, error: "Au moins une source avec son nom et un lien https" };

  const nr = (r["notif"] ?? {}) as Record<string, unknown>;
  const notifTitle = clip(nr["title"]).slice(0, 60);
  const notifBody = clip(nr["body"]).slice(0, 120);
  const notif = notifTitle.length >= 8 && notifBody.length >= 20 ? { title: notifTitle, body: notifBody } : null;

  const life = Math.trunc(Number(r["lifeDays"]));
  const lifeDays = Number.isFinite(life) && life >= 1 && life <= MAX_LIFE_DAYS ? life : null;

  const lang = (LANGS as readonly string[]).includes(String(r["lang"])) ? (String(r["lang"]) as NewsLang) : "fr";
  const score = Math.max(0, Math.min(100, Number(r["score"]) || 0));

  return {
    ok: true,
    value: { agentKey: agent.key, category: agent.category, level, country, continent, scope, lang, title, chapo, sections, retenir, sources, image: cleanUrl(r["image"]), score, notif, lifeDays },
  };
}

/** Document Posts/{id} d'un article. Compatible avec le modèle Post de l'application : likes, commentaires, vues et cadeaux fonctionnent tels quels. */
export function buildNewsPostDoc(n: NewsClean, id: string, nowMs: number): Record<string, unknown> {
  const micros = nowMs * 1000; // l'application range created_at en microsecondes
  return {
    id,
    user_id: agentUserId(n.agentKey),
    type: "NEWS",
    categorie: "NEWS",
    dataType: n.image ? "IMAGE" : "TEXT",
    status: "VALIDE",
    description: n.chapo,
    images: n.image ? [n.image] : [],
    url_media: n.image,
    thumbnail: n.image,
    created_at: micros,
    updated_at: micros,
    comments: 0, loves: 0, likes: 0, vues: 0, partage: 0, popularity: 0, giftCount: 0, totalGiftCoinsSentOnThisPost: 0,
    users_like_id: [], users_love_id: [], users_comments_id: [], users_partage_id: [], users_cadeau_id: [], users_vue_id: [],
    // jamais monétisé : likes gratuits, aucune vue payée (voir sendLike et PostViewService)
    monetized: false,
    isAdvertisement: false,
    expiresAt: expiresAtFor(n, nowMs),
    availableCountries: n.level === "country" && n.country ? [n.country] : ["ALL"],
    news: {
      agentKey: n.agentKey, category: n.category, level: n.level, country: n.country, continent: n.continent, scope: n.scope, lang: n.lang,
      title: n.title, chapo: n.chapo, sections: n.sections, retenir: n.retenir, sources: n.sources, sourceCount: n.sources.length, score: n.score, notif: n.notif, lifeDays: n.lifeDays,
    },
  };
}

export function buildFeedItem(n: NewsClean, id: string, nowMs: number): NewsFeedItem {
  return {
    id, agentKey: n.agentKey, category: n.category, level: n.level, country: n.country, continent: n.continent,
    title: n.title, chapo: n.chapo.slice(0, 160), image: n.image,
    sourceCount: n.sources.length, sourceNames: n.sources.slice(0, 3).map((s) => s.name), at: nowMs, score: Math.round(n.score), notif: n.notif, exp: expiresAtFor(n, nowMs),
  };
}

/** Ajoute un élément en tête de l'index, sans doublon ni article périmé, et garde les plus récents. */
export function mergeFeedItems(current: unknown, item: NewsFeedItem, nowMs = Date.now()): NewsFeedItem[] {
  const list = Array.isArray(current) ? (current as NewsFeedItem[]) : [];
  return [item, ...list.filter((x) => x && x.id !== item.id && (!x.exp || x.exp > nowMs))].slice(0, MAX_FEED_ITEMS);
}
