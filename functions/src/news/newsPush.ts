import { db } from "../shared/firebase";
import { NEWS_WEEK_TITLE, Lang } from "../notifications/tips_library";
import { agentUserId } from "./agents";
import { DigestItem, digestId, weekKeyOf } from "./digest";
import { continentOf } from "./geo";
import { DAY_MS, NewsFeedItem } from "./model";

/**
 * Notifications programmées d'actualités, branchées sur les rappels du planificateur (reengagement.ts) : aucune lecture de plus que celles que le
 * planificateur fait déjà pour chaque personne ; seulement quelques documents partagés (l'index du fil de chaque périmètre, le résumé de la semaine),
 * lus une fois par passage et gardés en mémoire.
 *
 *  - créneau du matin (8 h 30 locale) : le lundi « La semaine en N infos » (résumé de la semaine passée) ; le mercredi, le vendredi et le samedi,
 *    l'article le plus important du moment pour la personne (son pays d'abord, puis son continent, puis le monde) ;
 *  - créneau du soir (19 h 30) : alerte « À la une », seulement si une info forte est sortie dans les 8 dernières heures (au moins 3 sources) ;
 *  - une seule notification d'actualité par personne et par jour, jamais deux fois le même article (Users.newsAt et Users.newsLastId) ;
 *  - push seulement : rien n'est enregistré dans la liste des notifications ; un clic ouvre l'article, ou « Mon journal » pour la semaine.
 * Les règles communes des rappels s'appliquent (heures calmes, budget quotidien, paliers pour les inactifs). L'interrupteur « Actualités » des
 * préférences est indépendant de « Rappels et idées ». Désactivé tant que `AppConfig/push.newsPushEnabled` n'est pas à true.
 */
export type NewsKind = "news" | "newsflash" | "newsweek";

export const FLASH_MIN_SCORE = 16;
export const FLASH_MIN_SOURCES = 3;
const FLASH_WINDOW_H = 8;
const JOURNAL_WINDOW_H = 30;
const USER_GAP_H = 20;
const H = 3_600_000;

const cut = (s: unknown, n: number): string => {
  const t = Array.from(String(s ?? "").replace(/\s+/g, " ").trim());
  return t.length <= n ? t.join("") : t.slice(0, n - 1).join("") + "…";
};

/** Jour de la semaine à l'heure locale de la personne (0 = dimanche). */
export const weekdayOf = (nowMs: number, tzMin: number): number => new Date(nowMs + tzMin * 60_000).getUTCDay();

/** Quel type d'actualité un créneau peut-il porter ? (créneaux : 0 matin, 1 midi, 2 soir) */
export function newsKindFor(slot: number, weekday: number): NewsKind | null {
  if (slot === 0) return weekday === 1 ? "newsweek" : [3, 5, 6].includes(weekday) ? "news" : null;
  if (slot === 2) return "newsflash";
  return null;
}

/** L'article à envoyer : le plus important (score, puis le plus récent), jamais celui déjà envoyé ; pour l'alerte, seulement une info forte et très récente. */
export function pickStory(items: NewsFeedItem[], o: { nowMs: number; kind: "news" | "newsflash"; lastId?: string; minScore?: number }): NewsFeedItem | null {
  const window = (o.kind === "news" ? JOURNAL_WINDOW_H : FLASH_WINDOW_H) * H;
  const ok = items.filter((i) =>
    i.id !== o.lastId && o.nowMs - i.at <= window && (!i.exp || i.exp > o.nowMs) &&
    (o.kind === "news" || ((i.score ?? 0) >= (o.minScore ?? FLASH_MIN_SCORE) && (i.sourceCount ?? 1) >= FLASH_MIN_SOURCES)));
  return ok.sort((a, b) => (b.score ?? 0) - (a.score ?? 0) || b.at - a.at)[0] ?? null;
}

export interface NewsPlan {
  kind: NewsKind;
  /** Identifiant de ce qui est envoyé (article, ou `week:<clé>`), pour ne jamais le renvoyer à la même personne. */
  storyId: string;
  title: string;
  body: string;
  image?: string;
  data: Record<string, string>;
}

/** Texte d'un article : celui que l'IA a écrit pour la notification avec le résumé, sinon le titre et le chapô. */
export function storyPlan(kind: "news" | "newsflash", item: NewsFeedItem): NewsPlan {
  const title = cut(item.notif?.title || item.title, 58);
  return {
    kind, storyId: item.id,
    title: kind === "newsflash" ? `🔴 ${title}` : title,
    body: cut(item.notif?.body || item.chapo, 110),
    image: item.image || undefined,
    data: { type_notif: "NEWS", post_id: item.id, post_type: "NEWS", send_user_id: agentUserId(item.agentKey) },
  };
}

/** « La semaine en N infos » : un clic ouvre Mon journal ; le texte donne l'info la plus importante. */
export function weekPlan(weekKey: string, items: Array<Pick<DigestItem, "title" | "image">>, lang: Lang): NewsPlan {
  const n = Math.min(5, items.length);
  return {
    kind: "newsweek", storyId: `week:${weekKey}`,
    title: NEWS_WEEK_TITLE[lang].replace("{n}", String(n)),
    body: cut(items[0]?.title, 110),
    image: items[0]?.image || undefined,
    data: { type_notif: "RAPPEL_JOURNAL" },
  };
}

interface WeekDigest { key: string; items: DigestItem[] }

export class NewsPushSource {
  private feeds = new Map<string, NewsFeedItem[]>();
  private weeks = new Map<string, WeekDigest | null>();

  constructor(private readonly nowMs: number, private readonly countries: string[], private readonly flashMinScore = FLASH_MIN_SCORE) {}

  /** Périmètres d'une personne, du plus proche au plus large : son pays (s'il est suivi), son continent, le monde. */
  scopesFor(country: string): string[] {
    const code = country.trim().toUpperCase();
    const out: string[] = [];
    if (/^[A-Z]{2}$/.test(code) && this.countries.includes(code)) out.push(`country_${code}`);
    const cont = continentOf(code);
    if (cont) out.push(`continent_${cont}`);
    out.push("world");
    return out;
  }

  private async items(scope: string): Promise<NewsFeedItem[]> {
    if (!this.feeds.has(scope)) {
      const d = (await db.collection("NewsFeed").doc(scope).get().catch(() => undefined))?.data();
      this.feeds.set(scope, ((d?.["items"] as NewsFeedItem[] | undefined) ?? []));
    }
    return this.feeds.get(scope) as NewsFeedItem[];
  }

  /** Résumé de la semaine passée (construit le dimanche soir) : à envoyer le lundi matin. */
  private async week(scope: string): Promise<WeekDigest | null> {
    if (!this.weeks.has(scope)) {
      const key = weekKeyOf(this.nowMs - 7 * DAY_MS);
      const d = (await db.collection("NewsDigests").doc(digestId(scope, "week", key)).get().catch(() => undefined))?.data();
      const items = (d?.["items"] as DigestItem[] | undefined) ?? [];
      this.weeks.set(scope, items.length >= 3 ? { key, items } : null);
    }
    return this.weeks.get(scope) ?? null;
  }

  /** Ce qu'il faut envoyer à cette personne à ce créneau, ou rien. `u` : son profil ; `flashOn` : alertes « À la une » autorisées. */
  async plan(u: Record<string, unknown>, slot: number, tzMin: number, lang: Lang, flashOn = true): Promise<NewsPlan | undefined> {
    const kind = newsKindFor(slot, weekdayOf(this.nowMs, tzMin));
    if (!kind || (kind === "newsflash" && !flashOn)) return undefined;
    if (this.nowMs - (Number(u["newsAt"]) || 0) < USER_GAP_H * H) return undefined; // une seule actualité par personne et par jour
    const country = String((u["countryData"] as Record<string, unknown> | undefined)?.["countryCode"] ?? "");
    const lastId = String(u["newsLastId"] ?? "");
    for (const scope of this.scopesFor(country)) {
      if (kind === "newsweek") {
        const w = await this.week(scope);
        if (w && lastId !== `week:${w.key}`) return weekPlan(w.key, w.items, lang);
      } else {
        const story = pickStory(await this.items(scope), { nowMs: this.nowMs, kind, lastId, minScore: this.flashMinScore });
        if (story) return storyPlan(kind, story);
      }
    }
    return undefined;
  }
}
