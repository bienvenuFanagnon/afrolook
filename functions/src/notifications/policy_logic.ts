/**
 * Règles du système de notifications unifié d'Afrolook (fonctions pures : aucun accès à Firebase, testables telles quelles).
 *
 * Trois catégories :
 *  - direct   : messages, invitations, cadeaux, paiements… toujours envoyées tout de suite.
 *  - social   : j'aime, commentaires, abonnés, nouveaux posts… soumises aux heures calmes, aux préférences et au budget (SOCIAL_MAX par jour).
 *  - reminder : rappels programmés pour faire revenir (quiz, étude, contes, série, nouveaux posts) : mêmes règles + pas si la personne est
 *               déjà dans l'application + paliers de relance pour les inactifs.
 * Le budget quotidien (DAILY_BUDGET) compte social + rappels ; les messages directs n'y entrent pas.
 */

export type PushCategory = "direct" | "social" | "reminder";

/** Notifications « non directes » au plus par jour et par personne. */
export const DAILY_BUDGET = 3;
/** Part du budget que l'activité sociale peut consommer : il reste toujours de la place pour un rappel. */
export const SOCIAL_MAX = 2;
/** Heures calmes (heure locale) : de 22 h 00 à 7 h 30. */
export const QUIET_START_MIN = 22 * 60;
export const QUIET_END_MIN = 7 * 60 + 30;
/** Fuseau supposé quand il est inconnu : Togo (UTC+0). */
export const DEFAULT_TZ_MIN = 0;
/** Pas de rappel si la personne a utilisé l'application depuis moins de ce délai. */
export const ACTIVE_RECENTLY_MS = 2 * 3600 * 1000;
/** Écart minimal entre deux rappels programmés (hors paliers d'inactivité). */
export const MIN_REMINDER_GAP_MS = 3 * 3600 * 1000;
/** Créneaux des rappels programmés, en minutes depuis minuit (heure locale) : 8 h 30, 13 h 00, 19 h 30. */
export const SLOTS_MIN = [8 * 60 + 30, 13 * 60, 19 * 60 + 30];

/** `type_notif` considérés comme directs ; tout le reste est de l'activité sociale. */
const DIRECT_TYPES = new Set([
  "MESSAGE", "INVITATION", "ACCEPTINVITATION", "PARRAINAGE", "COMPTE_OFFICIEL", "GAIN", "CERTIFICATION", "SUPPORT", "TEST", "WEEKLY_REWARD",
]);

export function categoryOf(typeNotif?: unknown): PushCategory {
  const t = String(typeNotif ?? "").toUpperCase();
  if (!t || DIRECT_TYPES.has(t)) return "direct";
  if (t === "REMINDER" || t.startsWith("RAPPEL_")) return "reminder";
  return "social";
}

/**
 * Faut-il ENREGISTRER la notification dans la liste de l'application (collection Notifications) ? Seulement si la personne peut avoir besoin de s'en
 * souvenir : messages, invitations, cadeaux, gains, récompenses, activité sur son propre contenu (j'aime, commentaires, abonnés, republications).
 * Pas pour ce qui se retrouve ailleurs ou n'a aucune valeur après coup : un nouveau post ou une nouvelle chronique d'un créateur suivi (c'est dans
 * le fil), une nouvelle musique, un live qui démarre, un nouveau produit, et tous les rappels programmés. Le push part dans tous les cas.
 */
const NOT_STORED = new Set(["POST", "NEWPOST", "CHRONIQUE", "MUSIC", "LIVE", "ARTICLE", "MARKETING", "NEWS"]);
export function shouldStoreInApp(typeNotif?: unknown): boolean {
  const t = String(typeNotif ?? "").toUpperCase();
  if (t.startsWith("RAPPEL_") || t === "REMINDER") return false;
  return !NOT_STORED.has(t);
}

/** Catégorie d'après les données d'une notification (`type_notif`, ou `type` pour les anciens rappels de série). */
/** Abonnement Gold payant encore actif : aucune pub (règle de l'application). */
export function isGoldActive(user: Record<string, unknown> | undefined, nowMs: number): boolean {
  const ab = (user?.["abonnement"] ?? {}) as { type?: string; dateFin?: string; estActif?: boolean };
  const end = ab.dateFin ? Date.parse(ab.dateFin) : NaN;
  return ab.type === "gold" && ab.estActif !== false && Number.isFinite(end) && end > nowMs;
}

export function categoryOfData(data?: Record<string, unknown>): PushCategory {
  if (String(data?.["type"] ?? "") === "streak_reminder") return "reminder";
  return categoryOf(data?.["type_notif"]);
}

export interface PushPrefs {
  reminders?: boolean;
  activity?: boolean;
  /** Actualités (journal du matin, semaine, À la une) : indépendant de « Rappels et idées ». */
  news?: boolean;
}

export interface Budget {
  day: string;
  count: number;
  social: number;
  lastReminderAt: number;
}

export function emptyBudget(day: string): Budget {
  return { day, count: 0, social: 0, lastReminderAt: 0 };
}

const clampTz = (tz: unknown): number => {
  const n = Number(tz);
  return Number.isFinite(n) && Math.abs(n) <= 840 ? Math.trunc(n) : DEFAULT_TZ_MIN;
};

/** Minutes écoulées depuis minuit, heure locale. */
export function localMinutes(nowMs: number, tzMin?: unknown): number {
  const m = Math.floor((nowMs + clampTz(tzMin) * 60000) / 60000);
  return ((m % 1440) + 1440) % 1440;
}

/** Jour local au format AAAA-MM-JJ. */
export function localDay(nowMs: number, tzMin?: unknown): string {
  return new Date(nowMs + clampTz(tzMin) * 60000).toISOString().slice(0, 10);
}

export function inQuietHours(nowMs: number, tzMin?: unknown): boolean {
  const m = localMinutes(nowMs, tzMin);
  return m >= QUIET_START_MIN || m < QUIET_END_MIN;
}

/** Budget du jour courant (remis à zéro si le dernier enregistrement date d'un autre jour). */
export function budgetForToday(b: Partial<Budget> | undefined, day: string): Budget {
  if (!b || b.day !== day) return { ...emptyBudget(day), lastReminderAt: Number(b?.lastReminderAt) || 0 };
  return { day, count: Number(b.count) || 0, social: Number(b.social) || 0, lastReminderAt: Number(b.lastReminderAt) || 0 };
}

export interface DecideInput {
  nowMs: number;
  tzMin?: unknown;
  prefs?: PushPrefs;
  budget?: Partial<Budget>;
  /** Dernière activité dans l'application (ms) : sert aux rappels. */
  lastActiveMs?: number;
}

export interface Decision {
  allow: boolean;
  reason?: "prefs" | "quiet" | "budget" | "active" | "gap";
}

/** Faut-il envoyer cette notification à cette personne maintenant ? (les messages directs passent toujours) */
export function decide(category: PushCategory, i: DecideInput): Decision {
  if (category === "direct") return { allow: true };
  const prefOff = category === "reminder" ? i.prefs?.reminders === false : i.prefs?.activity === false;
  if (prefOff) return { allow: false, reason: "prefs" };
  if (inQuietHours(i.nowMs, i.tzMin)) return { allow: false, reason: "quiet" };
  const b = budgetForToday(i.budget, localDay(i.nowMs, i.tzMin));
  if (b.count >= DAILY_BUDGET) return { allow: false, reason: "budget" };
  if (category === "social" && b.social >= SOCIAL_MAX) return { allow: false, reason: "budget" };
  if (category === "reminder") {
    if (i.lastActiveMs && i.nowMs - i.lastActiveMs < ACTIVE_RECENTLY_MS) return { allow: false, reason: "active" };
    if (b.lastReminderAt && i.nowMs - b.lastReminderAt < MIN_REMINDER_GAP_MS) return { allow: false, reason: "gap" };
  }
  return { allow: true };
}

/** Budget après l'envoi d'une notification de cette catégorie. */
export function consume(category: PushCategory, b: Partial<Budget> | undefined, nowMs: number, tzMin?: unknown): Budget {
  const cur = budgetForToday(b, localDay(nowMs, tzMin));
  if (category === "direct") return cur;
  return {
    ...cur,
    count: cur.count + 1,
    social: cur.social + (category === "social" ? 1 : 0),
    lastReminderAt: category === "reminder" ? nowMs : cur.lastReminderAt,
  };
}

// ─── Paliers de relance des personnes inactives ───────────────────────────────────────────────────

/** Écart minimal entre deux rappels selon le nombre de jours d'inactivité (Infinity = on ne relance plus). */
export function reminderGapMs(daysInactive: number): number {
  const H = 3600 * 1000;
  if (daysInactive < 3) return 0; // personne encore active : seuls le budget et les créneaux limitent
  if (daysInactive < 14) return 20 * H; // une relance par jour
  if (daysInactive < 30) return 44 * H; // un jour sur deux
  if (daysInactive < 90) return 164 * H; // une par semaine
  return Infinity; // 90 jours sans retour : on arrête, pour ne pas saturer (et pour garder une bonne réputation d'envoi)
}

export function daysInactive(nowMs: number, lastActiveMs?: number): number {
  if (!lastActiveMs) return 0;
  return Math.max(0, Math.floor((nowMs - lastActiveMs) / 86400000));
}

// ─── Choix du contenu d'un rappel ─────────────────────────────────────────────────────────────────

export type ReminderKind = "quiz" | "etude" | "conte" | "feed" | "streak" | "comeback" | "tip" | "sponsor" | "creator" | "news" | "newsflash" | "newsweek";

export interface ReminderContext {
  /** Créneau du jour : 0 (matin), 1 (midi), 2 (soir). */
  slot: number;
  /** Numéro du jour (pour alterner quiz / étude / conte d'un jour à l'autre). */
  dayIndex: number;
  streak: number;
  streakDoneToday: boolean;
  /** Nouveaux posts non vus des créateurs suivis. */
  unseenPosts: number;
  daysInactive: number;
  /** Les notifications pédagogiques (monétisation, parrainage, lives…) sont-elles activées ? (AppConfig/push.tipsEnabled) */
  tipsEnabled?: boolean;
  /** Une pub Afrolook autorisée en notification existe et la personne peut en recevoir (pas de Gold). */
  sponsorAvailable?: boolean;
  /** Un nouveau créateur à faire découvrir existe pour cette personne (voir reengagement.ts : critères identiques à ceux du fil). */
  creatorPromoAvailable?: boolean;
  /** Une actualité à envoyer existe pour cette personne à ce créneau (voir news/newsPush.ts). */
  newsKind?: "news" | "newsflash" | "newsweek";
}

const LEARNING: ReminderKind[] = ["quiz", "etude", "conte"];

/** Un seul contenu par créneau, du plus utile au moins utile. Le quiz / l'étude / le conte tournent pour que chaque créneau soit différent. */
export function chooseReminder(c: ReminderContext): ReminderKind {
  const learning = LEARNING[(((c.dayIndex + c.slot) % 3) + 3) % 3]; // (jour + créneau) : un créneau donné change de sujet chaque jour, donc le quiz passe aussi à midi
  if (c.daysInactive >= 7 && c.slot === 1) return "comeback";
  if (c.slot === 2 && c.streak >= 3 && !c.streakDoneToday) return "streak";
  // actualités : le matin, la semaine du lundi ou l'article du jour (avant la promotion d'un créateur) ; le soir, l'alerte « À la une » (avant la pub)
  if (c.slot === 0 && (c.newsKind === "newsweek" || c.newsKind === "news")) return c.newsKind;
  if (c.slot === 2 && c.newsKind === "newsflash") return "newsflash";
  // matin : un nouveau créateur à découvrir un jour sur deux (à la place des nouveautés des abonnements, qui passent les autres jours)
  if (c.slot === 0 && c.creatorPromoAvailable && ((c.dayIndex % 2) + 2) % 2 === 0) return "creator";
  // soir : une pub Afrolook (sponsor) un jour sur quatre, après la série en danger
  if (c.slot === 2 && c.sponsorAvailable && ((c.dayIndex % 4) + 4) % 4 === 1) return "sponsor";
  // créneau de midi : un sujet pédagogique 4 jours sur 7 (monétisation, commentaire, musique, parrainage, lives…)
  if (c.slot === 1 && c.tipsEnabled && [0, 2, 4, 5].includes(((c.dayIndex % 7) + 7) % 7)) return "tip";
  if (c.slot !== 1 && c.unseenPosts > 0) return "feed";
  return learning;
}

/** Données transmises à l'application pour ouvrir directement la bonne page. */
export function typeNotifFor(kind: ReminderKind): string {
  return { quiz: "RAPPEL_QUIZ", etude: "RAPPEL_ETUDE", conte: "RAPPEL_CONTE", feed: "RAPPEL_FEED", streak: "RAPPEL_STREAK", comeback: "RAPPEL_RETOUR", tip: "RAPPEL_ABOUT", sponsor: "RAPPEL_PUB", creator: "RAPPEL_CREATEUR", news: "NEWS", newsflash: "NEWS", newsweek: "RAPPEL_JOURNAL" }[kind];
}

export interface Copy {
  title: string;
  body: string;
}

const COPY: Record<ReminderKind, Copy[]> = {
  quiz: [
    { title: "🎯 Le quiz du jour t’attend", body: "3 questions, des pièces à gagner. Prêt à jouer ?" },
    { title: "🧠 Teste-toi en 2 minutes", body: "Un nouveau quiz est disponible. Bats ton meilleur score !" },
    { title: "🏆 Monte dans le classement", body: "Réponds aux questions du jour et gagne des points." },
  ],
  etude: [
    { title: "📚 5 minutes pour avancer", body: "Un chapitre court t’attend pour progresser vers ton diplôme." },
    { title: "✏️ Reprends tes révisions", body: "Quelques questions suffisent pour garder le rythme." },
    { title: "🎓 Ton parcours continue", body: "Ouvre ta leçon du jour et valide un nouveau chapitre." },
  ],
  conte: [
    { title: "🌙 Un conte africain pour toi", body: "Une histoire à découvrir, avec un quiz pour gagner des pièces." },
    { title: "📖 L’histoire du jour", body: "Installe-toi : un nouveau conte t’attend sur Afrolook." },
    { title: "✨ Il était une fois…", body: "Découvre un conte, puis teste ce que tu as retenu." },
  ],
  feed: [
    { title: "🔥 Tes créateurs ont posté", body: "Des nouveautés t’attendent dans ton fil." },
    { title: "👀 Ça bouge sur Afrolook", body: "Découvre les derniers posts des créateurs que tu suis." },
    { title: "💬 Tu as des nouveautés", body: "Ton fil est à jour : viens voir ce que tu as manqué." },
  ],
  tip: [{ title: "", body: "" }], // les sujets pédagogiques viennent de tips_library.ts
  sponsor: [{ title: "", body: "" }], // le texte d'une pub vient de la pub elle-même
  creator: [{ title: "", body: "" }], // le texte vient du créateur promu
  news: [{ title: "", body: "" }], // le texte vient de l'article (écrit par l'IA avec son résumé)
  newsflash: [{ title: "", body: "" }],
  newsweek: [{ title: "", body: "" }], // le texte vient du résumé de la semaine (tips_library : NEWS_WEEK_TITLE)
  streak: [
    { title: "🔥 Ta série est en danger", body: "Commente quelques posts aujourd’hui pour la garder." },
    { title: "⏳ Ne casse pas ta série", body: "Il te reste peu de temps pour valider ta journée." },
    { title: "🔥 Garde ta série vivante", body: "Un petit commentaire suffit pour continuer." },
  ],
  comeback: [
    { title: "👋 Tu nous as manqué", body: "Des nouveautés, des quiz et des conteurs t’attendent." },
    { title: "🎁 Reviens faire un tour", body: "Ça fait un moment : viens voir ce qui a changé sur Afrolook." },
    { title: "🌍 La communauté t’attend", body: "De nouveaux posts et des défis sont disponibles pour toi." },
  ],
};

/** Texte du rappel : une variante parmi trois, choisie selon le jour pour ne pas répéter le même message. */
export function copyFor(kind: ReminderKind, variantSeed: number, streak = 0, unseen = 0): Copy {
  const list = COPY[kind];
  const base = list[((variantSeed % list.length) + list.length) % list.length];
  if (kind === "streak" && streak > 0) return { title: `🔥 Ta série de ${streak} jours est en danger`, body: base.body };
  if (kind === "feed" && unseen > 0) return { title: base.title, body: `${unseen > 9 ? "9+" : unseen} nouveau${unseen > 1 ? "x" : ""} post${unseen > 1 ? "s" : ""} de tes créateurs t’attend${unseen > 1 ? "ent" : ""}.` };
  return base;
}

/**
 * Fuseau habituel (minutes par rapport à UTC) des pays suivis. Sert à joindre, par l'ancien système de notifications (OneSignal), les comptes dont l'application
 * n'a pas encore été mise à jour : ils n'ont pas de fuseau enregistré, on le déduit de leur pays. Pays sans heure d'été, donc stable toute l'année.
 */
export const COUNTRY_TZ: Record<string, number> = {
  TG: 0, GH: 0, CI: 0, SN: 0, BF: 0, ML: 0, GN: 0, GM: 0, SL: 0, LR: 0, MR: 0,
  BJ: 60, NG: 60, NE: 60, CM: 60, TD: 60, GA: 60, CG: 60, CD: 60, GQ: 60, CF: 60, AO: 60, DZ: 60, TN: 60,
  ZA: 120, ZM: 120, ZW: 120, RW: 120, BI: 120, MW: 120, MZ: 120, BW: 120, NA: 120, EG: 120, LY: 120,
  KE: 180, TZ: 180, UG: 180, ET: 180, MG: 180, SO: 180, DJ: 180, ER: 180, KM: 180,
};
/** Pays dont l'heure habituelle correspond à ce fuseau. */
export const countriesForTz = (tzMin: number): string[] => Object.keys(COUNTRY_TZ).filter((c) => COUNTRY_TZ[c] === tzMin);

/**
 * Fuseaux (en minutes) dont l'heure locale tombe sur ce créneau à cet instant UTC. Le déclencheur passe aux heures pleines et aux demies ; s'il passe un peu
 * avant ou après (le planificateur « toutes les 30 minutes » est décalé de son heure de création, par exemple :24 et :54), on se cale sur la demi-heure la plus proche :
 * sans cet arrondi, aucun fuseau ne correspondait et aucun rappel ne partait.
 */
export function tzForSlot(nowMs: number, slotMin: number): number {
  const utcMin = (Math.round(nowMs / 60000 / 30) * 30) % 1440;
  let x = (slotMin - utcMin) % 1440;
  if (x > 720) x -= 1440;
  if (x < -720) x += 1440;
  return x;
}
