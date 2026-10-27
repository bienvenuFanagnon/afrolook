import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db } from "../shared/firebase";
import { CF_NEWS_ACCOUNTS, DEFAULT_MODELS, runAi } from "./ai";
import { requireAdmin } from "./adminAuth";
import { strip } from "./cluster";
import { logNews } from "./log";
import { DAY_MS } from "./model";
import { inventedNumbers, unknownNames } from "./validate";

/**
 * Résumés du jour, de la semaine et du mois (« Mon journal ») : pour chaque périmètre (pays, continent, monde), les infos les plus importantes de la période.
 * Chaque résumé garde SA PROPRE COPIE des articles (titre, chapô, image, sources) : il reste lisible même quand l'article d'origine a disparu.
 * Construits sans IA à partir de l'engagement réel (le jour : les articles du jour ; la semaine et le mois : les résumés du jour), avec une
 * introduction écrite par l'IA légère pour la semaine et le mois (quelques neurons ; modèle de secours : une phrase type).
 * Documents NewsDigests/{périmètre}_{période}_{clé} : clé = AAAA-MM-JJ (jour), AAAA-Www (semaine ISO, lundi à dimanche), AAAA-MM (mois), en UTC.
 */
export type Period = "day" | "week" | "month";
export const TOP_N: Record<Period, number> = { day: 5, week: 7, month: 10 };
/** Durée de conservation d'un résumé : les résumés du jour nourrissent ceux du mois (40 j) ; semaines 100 j ; mois 400 j. */
export const KEEP_DAYS: Record<Period, number> = { day: 40, week: 100, month: 400 };

export interface DigestItem {
  id: string;
  agentKey: string;
  category: string;
  title: string;
  chapo: string;
  image: string;
  sources: Array<{ name: string; url: string }>;
  sourceCount: number;
  at: number;
  rank: number;
}

// ── clés de période (UTC) ──────────────────────────────────────────────────────────────────────
const pad = (n: number) => String(n).padStart(2, "0");
export const dayKeyOf = (ms: number): string => new Date(ms).toISOString().slice(0, 10);
export const monthKeyOf = (ms: number): string => new Date(ms).toISOString().slice(0, 7);
const dayStart = (key: string): number => Date.parse(`${key}T00:00:00Z`);

/** Semaine ISO (lundi à dimanche) : « 2026-W43 ». */
export function weekKeyOf(ms: number): string {
  const d = new Date(ms);
  const t = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  const dayNum = t.getUTCDay() || 7;
  t.setUTCDate(t.getUTCDate() + 4 - dayNum); // le jeudi de la semaine donne l'année ISO
  const yearStart = Date.UTC(t.getUTCFullYear(), 0, 1);
  const week = Math.ceil(((t.getTime() - yearStart) / DAY_MS + 1) / 7);
  return `${t.getUTCFullYear()}-W${pad(week)}`;
}

/** Les 7 jours (lundi à dimanche) de la semaine qui contient `ms`. */
export function weekDayKeys(ms: number): string[] {
  const d = new Date(ms);
  const monday = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()) - ((d.getUTCDay() || 7) - 1) * DAY_MS;
  return Array.from({ length: 7 }, (_, i) => dayKeyOf(monday + i * DAY_MS));
}

/** Tous les jours d'un mois (« 2026-10 »). */
export function monthDayKeys(monthKey: string): string[] {
  const [y, m] = monthKey.split("-").map(Number);
  const n = new Date(Date.UTC(y, m, 0)).getUTCDate();
  return Array.from({ length: n }, (_, i) => `${monthKey}-${pad(i + 1)}`);
}

export const digestId = (scope: string, period: Period, key: string): string => `${scope}_${period}_${key}`;

// ── contenu ────────────────────────────────────────────────────────────────────────────────────
/** Importance d'un article : son score de départ et ce que les lecteurs en ont fait. */
export function rankOf(p: Record<string, unknown>): number {
  const n = (p["news"] ?? {}) as Record<string, unknown>;
  return Math.round(((Number(n["score"]) || 0) + 2 * (Number(p["loves"]) || 0) + 3 * (Number(p["comments"]) || 0) + 5 * (Number(p["giftCount"]) || 0) + (Number(p["vues"]) || 0) / 20) * 10) / 10;
}

/** Copie d'un article pour un résumé. */
export function snapshotItem(id: string, p: Record<string, unknown>): DigestItem {
  const n = (p["news"] ?? {}) as Record<string, unknown>;
  const created = Number(p["created_at"]) || 0;
  return {
    id, agentKey: String(n["agentKey"] ?? ""), category: String(n["category"] ?? ""),
    title: String(n["title"] ?? "").slice(0, 140), chapo: String(n["chapo"] ?? "").slice(0, 200), image: String(p["url_media"] ?? ""),
    sources: ((n["sources"] as Array<{ name?: string; url?: string }> | undefined) ?? []).slice(0, 3).map((s) => ({ name: String(s.name ?? "").slice(0, 60), url: String(s.url ?? "") })),
    sourceCount: Number(n["sourceCount"]) || 1, at: created > 1e14 ? Math.floor(created / 1000) : created, rank: rankOf(p),
  };
}

/** Les meilleurs éléments, sans doublon d'article (le meilleur rang est gardé), un seul article par agent d'abord pour varier les domaines. */
export function topItems(items: DigestItem[], n: number): DigestItem[] {
  const best = new Map<string, DigestItem>();
  for (const it of items) { const cur = best.get(it.id); if (!cur || it.rank > cur.rank) best.set(it.id, it); }
  const sorted = [...best.values()].sort((a, b) => b.rank - a.rank || b.at - a.at);
  const first: DigestItem[] = [];
  const rest: DigestItem[] = [];
  const seenAgent = new Set<string>();
  for (const it of sorted) (seenAgent.has(it.agentKey) ? rest : first).push(it), seenAgent.add(it.agentKey);
  return [...first, ...rest].slice(0, n).sort((a, b) => b.rank - a.rank || b.at - a.at);
}

const CATEGORY_FR: Record<string, string> = { sport: "le sport", politique: "la politique", culture: "la culture", musique: "la musique", tech: "la technologie", voyage: "le voyage", mode: "la mode", evenement: "les événements" };

/** Introduction sans IA : les domaines qui dominent la période. */
export function templateIntro(period: Period, items: DigestItem[]): string {
  const label = period === "day" ? "la journée" : period === "week" ? "la semaine" : "le mois";
  const counts = new Map<string, number>();
  for (const it of items) counts.set(it.category, (counts.get(it.category) ?? 0) + 1);
  const cats = [...counts.entries()].sort((a, b) => b[1] - a[1]).slice(0, 3).map(([c]) => CATEGORY_FR[c]).filter(Boolean);
  const list = cats.length > 1 ? `${cats.slice(0, -1).join(", ")} et ${cats[cats.length - 1]}` : cats[0] ?? "l'actualité";
  return `Les ${items.length} infos qui ont marqué ${label}, avec ${list} en tête.`;
}

export interface DigestDoc {
  scope: string; period: Period; key: string; from: number; to: number;
  items: DigestItem[]; intro: string; createdAt: number; expireAt: number;
}

export function buildDigestDoc(scope: string, period: Period, key: string, items: DigestItem[], intro: string, nowMs: number): DigestDoc {
  const from = period === "month" ? dayStart(`${key}-01`) : period === "week" ? dayStart(weekDayKeys(dayStart(`${key.slice(0, 4)}-01-04`) + (Number(key.slice(6)) - 1) * 7 * DAY_MS)[0]) : dayStart(key);
  const to = period === "month" ? dayStart(`${key}-01`) + monthDayKeys(key).length * DAY_MS : period === "week" ? from + 7 * DAY_MS : from + DAY_MS;
  return { scope, period, key, from, to, items, intro, createdAt: nowMs, expireAt: nowMs + KEEP_DAYS[period] * DAY_MS };
}

// ── introduction par l'IA légère (semaine et mois) ─────────────────────────────────────────────
/** Introduction acceptée : courte, en français, sans chiffre ni nom propre absent des titres. */
export function validateIntro(text: string, titles: string[]): string | null {
  const t = text.replace(/^["«\s]+|["»\s]+$/g, "").replace(/\s+/g, " ").trim();
  if (t.length < 40 || t.length > 320) return null;
  if (inventedNumbers(t, titles.join(" ")).length) return null;
  if (unknownNames(t, ` ${strip(titles.join(" "))} `).length) return null;
  return t;
}

async function aiIntro(period: Period, items: DigestItem[], run: typeof runAi = runAi): Promise<string | null> {
  try {
    const titles = items.map((i) => i.title);
    const res = await run([
      { role: "system", content: "Tu rédiges l'introduction d'un résumé de la période d'un journal africain. Deux phrases au plus, en français, factuelles et sans formule racoleuse. N'utilise que les titres fournis : n'invente aucune personne, aucun lieu, aucun chiffre. Réponds uniquement par le texte de l'introduction." },
      { role: "user", content: `Période : ${period === "week" ? "la semaine" : "le mois"}\nTitres des infos les plus importantes :\n${titles.map((t, i) => `${i + 1}. ${t}`).join("\n")}` },
    ], { model: DEFAULT_MODELS.light, maxTokens: 160, temperature: 0.4 });
    return validateIntro(res.text, titles);
  } catch {
    return null; // quota, réseau, réponse refusée : l'introduction type prend le relais
  }
}

// ── construction ───────────────────────────────────────────────────────────────────────────────
/** Résumés du jour : un par périmètre ayant des articles ce jour-là. Un seul parcours de la collection (les articles du jour). */
export async function buildDayDigests(key: string, nowMs = Date.now()): Promise<number> {
  const start = dayStart(key);
  const snap = await db.collection("Posts").where("type", "==", "NEWS").where("created_at", ">=", start * 1000).where("created_at", "<", (start + DAY_MS) * 1000).limit(400).get();
  const byScope = new Map<string, DigestItem[]>();
  for (const d of snap.docs) {
    const scope = String(((d.data()["news"] ?? {}) as Record<string, unknown>)["scope"] ?? "");
    if (scope) byScope.set(scope, [...(byScope.get(scope) ?? []), snapshotItem(d.id, d.data())]);
  }
  let n = 0;
  for (const [scope, items] of byScope) {
    const top = topItems(items, TOP_N.day);
    await db.collection("NewsDigests").doc(digestId(scope, "day", key)).set(buildDigestDoc(scope, "day", key, top, templateIntro("day", top), nowMs));
    n++;
  }
  return n;
}

/** Résumés de la semaine ou du mois, à partir des résumés du jour (donc sans relire les articles, même disparus). */
export async function buildPeriodDigests(period: "week" | "month", key: string, dayKeys: string[], nowMs = Date.now(), run: typeof runAi = runAi): Promise<number> {
  const scopes = (await db.collection("NewsFeed").get()).docs.map((d) => d.id);
  let n = 0;
  for (const scope of scopes) {
    const snaps = await db.getAll(...dayKeys.map((k) => db.collection("NewsDigests").doc(digestId(scope, "day", k))));
    const all = snaps.flatMap((s) => ((s.data()?.["items"] as DigestItem[] | undefined) ?? []));
    if (!all.length) continue;
    const top = topItems(all, TOP_N[period]);
    const intro = (await aiIntro(period, top, run)) ?? templateIntro(period, top);
    await db.collection("NewsDigests").doc(digestId(scope, period, key)).set(buildDigestDoc(scope, period, key, top, intro, nowMs));
    n++;
  }
  return n;
}

/** Passage du soir : résumés du jour ; le dimanche, de la semaine ; le dernier jour du mois, du mois. */
export async function runDigestTick(nowMs = Date.now()): Promise<{ day: number; week: number; month: number }> {
  const out = { day: await buildDayDigests(dayKeyOf(nowMs), nowMs), week: 0, month: 0 };
  const d = new Date(nowMs);
  if (d.getUTCDay() === 0) out.week = await buildPeriodDigests("week", weekKeyOf(nowMs), weekDayKeys(nowMs), nowMs);
  if (new Date(nowMs + DAY_MS).getUTCDate() === 1) out.month = await buildPeriodDigests("month", monthKeyOf(nowMs), monthDayKeys(monthKeyOf(nowMs)), nowMs);
  return out;
}

const RUN = { region: "us-central1" as const, timeoutSeconds: 300, memory: "256MiB" as const, secrets: [CF_NEWS_ACCOUNTS] };

export const newsDigestTick = onSchedule({ ...RUN, schedule: "10 21 * * *", timeZone: "UTC" }, async () => {
  const cfg = (await db.collection("AppConfig").doc("news").get()).data();
  if (cfg?.["enabled"] === false) return;
  try {
    const r = await runDigestTick();
    await logNews({ kind: "collect", ok: true, message: `Résumés construits : ${r.day} du jour, ${r.week} de la semaine, ${r.month} du mois` });
  } catch (e) {
    console.error("[actualités] résumés en erreur", e);
    await logNews({ kind: "error", ok: false, message: `Résumés interrompus : ${e instanceof Error ? e.message : String(e)}` });
  }
});

/** Construction à la main (administration) : { period: "day" | "week" | "month", key?: clé de la période ; sinon la période en cours }. */
export const newsBuildDigests = onCall(RUN, async (request) => {
  await requireAdmin(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const period = String(d["period"] ?? "day") as Period;
  const now = Date.now();
  if (period === "day") {
    const key = /^\d{4}-\d{2}-\d{2}$/.test(String(d["key"])) ? String(d["key"]) : dayKeyOf(now);
    return { period, key, built: await buildDayDigests(key, now) };
  }
  if (period === "week") {
    const ref = /^\d{4}-\d{2}-\d{2}$/.test(String(d["key"])) ? dayStart(String(d["key"])) : now; // une date de la semaine voulue
    return { period, key: weekKeyOf(ref), built: await buildPeriodDigests("week", weekKeyOf(ref), weekDayKeys(ref), now) };
  }
  if (period === "month") {
    const key = /^\d{4}-\d{2}$/.test(String(d["key"])) ? String(d["key"]) : monthKeyOf(now);
    return { period, key, built: await buildPeriodDigests("month", key, monthDayKeys(key), now) };
  }
  throw new HttpsError("invalid-argument", "Période invalide (day, week ou month)");
});
