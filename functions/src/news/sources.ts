/**
 * Sources d'actualités : flux RSS publics. `category` fixe le domaine quand le flux est thématique ; `null` = flux général, classé par mots-clés.
 * `region` : « africa » pour une source africaine (un article sans pays reconnu part au niveau continent), « world » pour le reste.
 * `active` : état de départ, modifiable dans l'administration (AppConfig/news.sourcesOn : { id: true|false }).
 * Les flux marqués actifs ont été lus avec succès depuis le serveur (Africanews, Le Monde) ou viennent de PronoFlash (sport) ; RFI refuse nos serveurs (403). Les autres sont
 * proposés désactivés : le bouton « Tester les sources » de l'administration les essaie depuis le serveur, on active ceux qui répondent.
 */
/** « mode » : mode, beauté, défilés ; « evenement » : événements importants (sommets, économie, catastrophes, cérémonies) et actualité générale d'un pays. */
export type NewsCategory = "sport" | "politique" | "culture" | "musique" | "tech" | "voyage" | "mode" | "evenement";

export interface NewsSourceDef {
  id: string;
  name: string;
  url: string;
  lang: "fr" | "en";
  category: NewsCategory | null;
  region: "africa" | "world";
  active: boolean;
  /** Média national : pays (code à 2 lettres) dont il parle, utilisé quand le texte ne désigne aucun pays. */
  country?: string;
}

const S = (id: string, name: string, url: string, lang: "fr" | "en", category: NewsCategory | null, region: "africa" | "world", active: boolean, country?: string): NewsSourceDef =>
  ({ id, name, url, lang, category, region, active, ...(country ? { country } : {}) });

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
  // Culturebene ne répond plus depuis nos serveurs : désactivé
  S("culturebene", "Culturebene", "https://www.culturebene.com/feed", "fr", "culture", "africa", false),
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
  S("bbc_africa", "BBC News Africa", "https://feeds.bbci.co.uk/news/world/africa/rss.xml", "en", null, "africa", true),
  // ── mode et événements importants ──
  S("bellanaija_style", "BellaNaija Style", "https://www.bellanaija.com/category/style/feed/", "en", "mode", "africa", true),
  S("harpersbazaar_mode", "Harper's Bazaar", "https://www.harpersbazaar.com/rss/fashion.xml/", "en", "mode", "world", true),
  S("africanews_business", "Africanews", "https://www.africanews.com/feed/rss?themes=business", "en", "evenement", "africa", true),
  S("aljazeera", "Al Jazeera", "https://www.aljazeera.com/xml/rss/all.xml", "en", null, "world", true),
  // ── médias nationaux (lus avec succès depuis le serveur) : un article sans pays reconnu est rattaché au pays du média ──
  S("tg_togotopnews", "Togo Top News", "https://togotopnews.com/feed", "fr", null, "africa", true, "TG"),
  S("tg_24heureinfo", "24 Heures Info", "https://24heureinfo.com/feed", "fr", null, "africa", true, "TG"),
  S("tg_togoweb", "Togoweb", "https://www.togoweb.net/feed", "fr", null, "africa", true, "TG"),
  S("bj_lanouvelletribune", "La Nouvelle Tribune", "https://lanouvelletribune.info/feed", "fr", null, "africa", true, "BJ"),
  S("bj_beninwebtv", "Bénin Web TV", "https://beninwebtv.com/feed", "fr", null, "africa", true, "BJ"),
  S("bj_matinlibre", "Matin Libre", "https://matinlibre.com/feed", "fr", null, "africa", true, "BJ"),
  S("bj_fraternite", "Fraternité", "https://www.fraternitebj.info/feed", "fr", null, "africa", true, "BJ"),
  S("ci_ivoirematin", "Ivoirematin", "https://www.ivoirematin.com/feed", "fr", null, "africa", true, "CI"),
  S("ci_lebanco", "Le Banco", "https://www.lebanco.net/feed", "fr", null, "africa", true, "CI"),
  S("sn_senego", "Senego", "https://senego.com/feed", "fr", null, "africa", true, "SN"),
  S("sn_dakaractu", "Dakaractu", "https://www.dakaractu.com/xml/syndication.rss", "fr", null, "africa", true, "SN"),
  S("sn_senenews", "Senenews", "https://senenews.com/feed", "fr", null, "africa", true, "SN"),
  S("bf_lefaso", "Lefaso.net", "https://lefaso.net/spip.php?page=backend", "fr", null, "africa", true, "BF"),
  S("bf_burkina24", "Burkina24", "https://www.burkina24.com/feed", "fr", null, "africa", true, "BF"),
  S("bf_netafrique", "Netafrique", "https://netafrique.net/feed", "fr", null, "africa", true, "BF"),
  S("cm_investir", "Investir au Cameroun", "https://www.investiraucameroun.com/feed", "fr", null, "africa", true, "CM"),
  S("cm_237online", "237online", "https://www.237online.com/feed", "fr", null, "africa", true, "CM"),
  S("cm_datacameroon", "Datacameroon", "https://www.datacameroon.com/feed", "fr", null, "africa", true, "CM"),
  S("ml_bamada", "Bamada.net", "https://www.bamada.net/feed", "fr", null, "africa", true, "ML"),
  S("ml_malijet", "Malijet", "https://malijet.com/feed", "fr", null, "africa", true, "ML"),
  S("ml_journaldumali", "Journal du Mali", "https://www.journaldumali.com/feed", "fr", null, "africa", true, "ML"),
  S("gn_guineenews", "Guinéenews", "https://guineenews.org/feed", "fr", null, "africa", true, "GN"),
  S("gn_guinee360", "Guinée360", "https://www.guinee360.com/feed", "fr", null, "africa", true, "GN"),
  S("gn_mediaguinee", "Média Guinée", "https://www.mediaguinee.com/feed", "fr", null, "africa", true, "GN"),
  S("cd_radiookapi", "Radio Okapi", "https://www.radiookapi.net/feed", "fr", null, "africa", true, "CD"),
  S("cd_actualite", "Actualite.cd", "https://actualite.cd/feed", "fr", null, "africa", true, "CD"),
  S("ga_gabonactu", "Gabonactu", "https://www.gabonactu.com/feed", "fr", null, "africa", true, "GA"),
  S("ga_gabonreview", "Gabonreview", "https://gabonreview.com/feed", "fr", null, "africa", true, "GA"),
  S("gh_graphic", "Graphic Online", "https://www.graphic.com.gh/news.feed", "en", null, "africa", true, "GH"),
  S("gh_myjoyonline", "MyJoyOnline", "https://www.myjoyonline.com/feed", "en", null, "africa", true, "GH"),
  S("ng_premiumtimes", "Premium Times", "https://www.premiumtimesng.com/feed", "en", null, "africa", true, "NG"),
  S("ng_punch", "Punch", "https://punchng.com/feed", "en", null, "africa", true, "NG"),
  S("ng_dailypost", "Daily Post", "https://dailypost.ng/feed", "en", null, "africa", true, "NG"),
  S("ke_standard", "The Standard", "https://www.standardmedia.co.ke/rss/headlines.php", "en", null, "africa", true, "KE"),
  S("ke_kenyans", "Kenyans.co.ke", "https://www.kenyans.co.ke/feeds/news", "en", null, "africa", true, "KE"),
  S("ke_capitalfm", "Capital FM Kenya", "https://www.capitalfm.co.ke/news/feed", "en", null, "africa", true, "KE"),
  S("mg_midi", "Midi Madagasikara", "https://www.midi-madagasikara.mg/feed", "fr", null, "africa", true, "MG"),
  S("mg_newsmada", "Newsmada", "https://www.newsmada.com/feed", "fr", null, "africa", true, "MG"),
  S("za_dailymaverick", "Daily Maverick", "https://www.dailymaverick.co.za/dmrss/", "en", null, "africa", true, "ZA"),
  S("za_iol", "IOL", "https://www.iol.co.za/rss", "en", null, "africa", true, "ZA"),
  S("zm_diggers", "Zambian Diggers", "https://diggers.news/feed", "en", null, "africa", true, "ZM"),
  S("zm_monitor", "Zambia Monitor", "https://www.zambiamonitor.com/feed", "en", null, "africa", true, "ZM"),
  S("td_tchadinfos", "Tchadinfos", "https://tchadinfos.com/feed", "fr", null, "africa", true, "TD"),
  S("fr_lemonde", "Le Monde", "https://www.lemonde.fr/rss/une.xml", "fr", null, "world", true, "FR"),
  S("be_lalibre", "La Libre", "https://www.lalibre.be/arc/outboundfeeds/rss/?outputType=xml", "fr", null, "world", true, "BE"),
  S("ch_rts", "RTS", "https://www.rts.ch/info/?format=rss/news", "fr", null, "world", true, "CH"),
  S("gb_bbc", "BBC News", "https://feeds.bbci.co.uk/news/rss.xml", "en", null, "world", true, "GB"),
  S("us_nytimes", "The New York Times", "https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml", "en", null, "world", true, "US"),
  S("de_dw", "DW", "https://rss.dw.com/xml/rss-en-all", "en", null, "world", true, "DE"),
  S("ca_radiocanada", "Radio-Canada", "https://ici.radio-canada.ca/rss/4159", "fr", null, "world", true, "CA"),
  S("ht_lenouvelliste", "Le Nouvelliste", "https://lenouvelliste.com/rss", "fr", null, "world", true, "HT"),
];

/** Sources actives, selon les réglages (AppConfig/news.sourcesOn) et les sources ajoutées par l'administrateur (AppConfig/news.customSources). */
export function activeSources(cfg: { sourcesOn?: Record<string, boolean>; customSources?: unknown } = {}): NewsSourceDef[] {
  const custom: NewsSourceDef[] = [];
  const cats: Array<NewsCategory | null> = ["sport", "politique", "culture", "musique", "tech", "voyage", "mode", "evenement", null];
  if (Array.isArray(cfg.customSources)) {
    for (const raw of cfg.customSources.slice(0, 60)) {
      const o = (raw ?? {}) as Record<string, unknown>;
      const id = String(o["id"] ?? "").trim();
      const url = String(o["url"] ?? "").trim();
      if (!/^[a-z0-9_]{3,40}$/.test(id) || !/^https:\/\/\S{6,300}$/.test(url)) continue;
      const cat = (cats.includes(o["category"] as NewsCategory) ? o["category"] : null) as NewsCategory | null;
      custom.push(S(id, String(o["name"] ?? id).slice(0, 60), url, o["lang"] === "en" ? "en" : "fr", cat, o["region"] === "world" ? "world" : "africa", true, /^[A-Za-z]{2}$/.test(String(o["country"] ?? "")) ? String(o["country"]).toUpperCase() : undefined));
    }
  }
  const on = cfg.sourcesOn ?? {};
  return [...DEFAULT_SOURCES, ...custom.filter((c) => !DEFAULT_SOURCES.some((d) => d.id === c.id))].filter((s) => (on[s.id] === undefined ? s.active : !!on[s.id]));
}
