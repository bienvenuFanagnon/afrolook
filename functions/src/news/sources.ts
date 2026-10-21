/**
 * Sources d'actualités : flux RSS publics. `category` fixe le domaine quand le flux est thématique ; `null` = flux général, classé par mots-clés.
 * `region` : « africa » pour une source africaine (un article sans pays reconnu part au niveau continent), « world » pour le reste.
 * `active` : état de départ, modifiable dans l'administration (AppConfig/news.sourcesOn : { id: true|false }).
 * Les flux marqués actifs ont été lus avec succès depuis le serveur (Africanews, Le Monde) ou viennent de PronoFlash (sport) ; RFI refuse nos serveurs (403). Les autres sont
 * proposés désactivés : le bouton « Tester les sources » de l'administration les essaie depuis le serveur, on active ceux qui répondent.
 */
export type NewsCategory = "sport" | "politique" | "culture" | "musique" | "tech" | "voyage";

export interface NewsSourceDef {
  id: string;
  name: string;
  url: string;
  lang: "fr" | "en";
  category: NewsCategory | null;
  region: "africa" | "world";
  active: boolean;
}

const S = (id: string, name: string, url: string, lang: "fr" | "en", category: NewsCategory | null, region: "africa" | "world", active: boolean): NewsSourceDef =>
  ({ id, name, url, lang, category, region, active });

export const DEFAULT_SOURCES: NewsSourceDef[] = [
  // ── lus avec succès ──
  // RFI répond depuis un ordinateur mais refuse (403) les serveurs d'Afrolook : désactivé par défaut, à réactiver si le test des sources passe
  S("rfi_afrique", "RFI", "https://www.rfi.fr/fr/afrique/rss", "fr", null, "africa", false),
  S("rfi_monde", "RFI", "https://www.rfi.fr/fr/rss", "fr", null, "world", false),
  S("rfi_sport", "RFI Sport", "https://www.rfi.fr/fr/sport/rss", "fr", "sport", "world", false),
  S("rfi_culture", "RFI Culture", "https://www.rfi.fr/fr/culture/rss", "fr", "culture", "world", false),
  S("africanews_fr", "Africanews", "https://fr.africanews.com/feed/rss", "fr", null, "africa", true),
  S("africanews_politics", "Africanews", "https://www.africanews.com/feed/rss?themes=politics", "en", "politique", "africa", true),
  S("africanews_sport", "Africanews", "https://www.africanews.com/feed/rss?themes=sport", "en", "sport", "africa", true),
  S("africanews_culture", "Africanews", "https://www.africanews.com/feed/rss?themes=culture", "en", "culture", "africa", true),
  S("africanews_travel", "Africanews", "https://www.africanews.com/feed/rss?themes=travel", "en", "voyage", "africa", true),
  S("lemonde_afrique", "Le Monde Afrique", "https://www.lemonde.fr/afrique/rss_full.xml", "fr", null, "africa", true),
  S("lemonde_culture", "Le Monde Culture", "https://www.lemonde.fr/culture/rss_full.xml", "fr", "culture", "world", true),
  S("lemonde_pixels", "Le Monde Pixels", "https://www.lemonde.fr/pixels/rss_full.xml", "fr", "tech", "world", true),
  S("lemonde_voyage", "Le Monde Voyage", "https://www.lemonde.fr/voyage/rss_full.xml", "fr", "voyage", "world", true),
  S("culturebene", "Culturebene", "https://www.culturebene.com/feed", "fr", "culture", "africa", true),
  // ── sport : sources de PronoFlash ──
  S("africatopsports", "Africa Top Sports", "https://www.africatopsports.com/feed/", "fr", "sport", "africa", true),
  S("afrikfoot", "Afrik-Foot", "https://www.afrik-foot.com/feed", "fr", "sport", "africa", true),
  S("footmercato", "Foot Mercato", "https://www.footmercato.net/flux-rss", "fr", "sport", "world", true),
  // ── à tester depuis le serveur (désactivées au départ) ──
  S("apanews", "APA news", "https://apanews.net/feed/", "fr", null, "africa", false),
  S("jeuneafrique", "Jeune Afrique", "https://www.jeuneafrique.com/feed/", "fr", null, "africa", false),
  S("bbc_afrique", "BBC Afrique", "https://feeds.bbci.co.uk/afrique/rss.xml", "fr", null, "africa", false),
  S("france24_afrique", "France 24", "https://www.france24.com/fr/afrique/rss", "fr", null, "africa", false),
  S("afrik_com", "Afrik.com", "https://www.afrik.com/feed", "fr", "culture", "africa", false),
  S("musicinafrica", "Music In Africa", "https://www.musicinafrica.net/rss.xml", "en", "musique", "africa", false),
  S("numerama", "Numerama", "https://www.numerama.com/feed/", "fr", "tech", "world", false),
  S("digitalbusiness", "Digital Business Africa", "https://www.digitalbusiness.africa/feed/", "fr", "tech", "africa", false),
  S("techcabal", "TechCabal", "https://techcabal.com/feed/", "en", "tech", "africa", false),
  S("techpoint", "Techpoint Africa", "https://techpoint.africa/feed/", "en", "tech", "africa", false),
  S("bbc_africa", "BBC News Africa", "https://feeds.bbci.co.uk/news/world/africa/rss.xml", "en", null, "africa", false),
];

/** Sources actives, selon les réglages (AppConfig/news.sourcesOn) et les sources ajoutées par l'administrateur (AppConfig/news.customSources). */
export function activeSources(cfg: { sourcesOn?: Record<string, boolean>; customSources?: unknown } = {}): NewsSourceDef[] {
  const custom: NewsSourceDef[] = [];
  const cats: Array<NewsCategory | null> = ["sport", "politique", "culture", "musique", "tech", "voyage", null];
  if (Array.isArray(cfg.customSources)) {
    for (const raw of cfg.customSources.slice(0, 40)) {
      const o = (raw ?? {}) as Record<string, unknown>;
      const id = String(o["id"] ?? "").trim();
      const url = String(o["url"] ?? "").trim();
      if (!/^[a-z0-9_]{3,40}$/.test(id) || !/^https:\/\/\S{6,300}$/.test(url)) continue;
      const cat = (cats.includes(o["category"] as NewsCategory) ? o["category"] : null) as NewsCategory | null;
      custom.push(S(id, String(o["name"] ?? id).slice(0, 60), url, o["lang"] === "en" ? "en" : "fr", cat, o["region"] === "world" ? "world" : "africa", true));
    }
  }
  const on = cfg.sourcesOn ?? {};
  return [...DEFAULT_SOURCES, ...custom.filter((c) => !DEFAULT_SOURCES.some((d) => d.id === c.id))].filter((s) => (on[s.id] === undefined ? s.active : !!on[s.id]));
}
