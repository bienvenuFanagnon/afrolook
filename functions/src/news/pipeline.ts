import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { AGENT_OF_CATEGORY } from "./agents";
import { DAILY_TOTAL_CAP, DEFAULT_MODELS, loadUsage } from "./ai";
import { COUNTRY_KEYWORDS, Fingerprint, RawItem, Topic, buildTopics, fingerprint, linkHash, sameFingerprint, toRaw } from "./cluster";
import { logNews } from "./log";
import { cleanNewsInput } from "./model";
import { fetchPreview } from "./pagePreview";
import { publishNews } from "./publish";
import { fetchFeed } from "./rss";
import { NewsSourceDef, activeSources } from "./sources";
import { summarizeTopic } from "./summarize";

/**
 * Pipeline des actualités : sources RSS → sujets (regroupement des articles qui parlent de la même chose) → choix des plus importants selon des
 * plafonds → résumé par l'IA (sources citées) → publication. Prudent et économe par construction :
 *  - le plafond du jour est vérifié AVANT de lire les sources : plafond atteint = presque aucune lecture ni écriture ;
 *  - un verrou empêche deux passages simultanés (planification + lancement manuel), donc pas de doublon ;
 *  - jamais deux fois le même sujet : une source déjà utilisée n'est pas republiée (NewsSeen), un sujet proche d'un article des 2 derniers jours est
 *    écarté même s'il vient d'autres sources ou d'une autre langue, et un seul sujet par agent et périmètre est traité par passage ;
 *  - plafonds par jour (total) et par agent et périmètre (2 au plus) ; un échec bloque le sujet 12 heures pour ne pas gaspiller de neurons ;
 *  - quota Cloudflare atteint : le passage s'arrête ; chaque passage est écrit dans le journal de l'administration.
 */
export const DEFAULT_COUNTRIES = ["TG", "BJ", "CI", "SN", "CM"];
const LOCK_MS = 9 * 60 * 1000;
const PER_KEY_RUN = 1;
const MAX_RECENT_TITLES = 300;

export interface PipelineConfig {
  enabled: boolean;
  pipelineEnabled: boolean;
  countries: string[];
  dailyCap: number;
  perRun: number;
  perKeyDaily: number;
}

/** Réglages (AppConfig/news) avec valeurs de départ prudentes. La génération automatique est coupée tant que l'administrateur ne l'active pas. */
export function readPipelineConfig(d: Record<string, unknown> | undefined): PipelineConfig {
  const o = d ?? {};
  const n = (v: unknown, def: number, min: number, max: number) => { const x = Math.trunc(Number(v)); return Number.isFinite(x) && x >= min && x <= max ? x : def; };
  const countries = (Array.isArray(o["countries"]) ? (o["countries"] as unknown[]) : DEFAULT_COUNTRIES)
    .map((c) => String(c).trim().toUpperCase()).filter((c) => c in COUNTRY_KEYWORDS).slice(0, 30);
  return {
    enabled: o["enabled"] !== false,
    pipelineEnabled: o["pipelineEnabled"] === true,
    countries: countries.length ? countries : DEFAULT_COUNTRIES,
    dailyCap: n(o["dailyCap"], 60, 1, 300),
    perRun: n(o["perRun"], 5, 1, 12),
    perKeyDaily: n(o["perKeyDaily"], 2, 1, 6),
  };
}

export interface Counters { published: number; byKey: Record<string, number> }
export const dayKey = (ms: number): string => new Date(ms).toISOString().slice(0, 10);

/** Clé de plafond d'un sujet : agent et périmètre (`sport|country_TG`). */
export function topicKey(t: Topic): string {
  const scope = t.level === "country" ? `country_${t.country}` : t.level === "continent" ? "continent_AF" : "world";
  return `${AGENT_OF_CATEGORY[t.category]}|${scope}`;
}

export interface SeenInfo { status: "published" | "failed"; retryAfter?: number }

/**
 * Sujets à traiter pendant ce passage : ni déjà publiés, ni en échec récent, ni proches d'un article récent (`recent` = titres des sources des
 * 2 derniers jours), dans les plafonds, un agent après l'autre pour varier les domaines, un seul sujet par agent et périmètre.
 */
export function planSelection(topics: Topic[], counters: Counters, cfg: Pick<PipelineConfig, "dailyCap" | "perRun" | "perKeyDaily">, seen: Map<string, SeenInfo>, nowMs: number, recent: string[] = []): Topic[] {
  const room = Math.min(cfg.perRun, cfg.dailyCap - counters.published);
  if (room <= 0) return [];
  const recentPrints: Fingerprint[] = recent.slice(-MAX_RECENT_TITLES).map(fingerprint);
  const blocked = (t: Topic) => t.items.some((it) => {
    const s = seen.get(linkHash(it.lien));
    return !!s && (s.status === "published" || (s.retryAfter ?? 0) > nowMs);
  });
  const printsOf = (t: Topic) => t.items.map((i) => fingerprint(i.titre));
  const byAgent = new Map<string, Array<{ t: Topic; prints: Fingerprint[] }>>();
  for (const t of topics) {
    if (blocked(t)) continue;
    const key = topicKey(t);
    if ((counters.byKey[key] ?? 0) >= cfg.perKeyDaily) continue;
    const prints = printsOf(t);
    if (recentPrints.length && prints.some((p) => recentPrints.some((r) => sameFingerprint(p, r)))) continue; // déjà raconté récemment
    const agent = AGENT_OF_CATEGORY[t.category];
    byAgent.set(agent, [...(byAgent.get(agent) ?? []), { t, prints }]);
  }
  const out: Topic[] = [];
  const taken: Record<string, number> = {};
  const chosenPrints: Fingerprint[] = [];
  const queues = [...byAgent.values()];
  // tour de table : le meilleur sujet de chaque agent, puis le suivant…
  while (out.length < room && queues.some((q) => q.length)) {
    for (const q of queues) {
      if (out.length >= room) break;
      while (q.length) {
        const { t, prints } = q.shift()!;
        const key = topicKey(t);
        if ((taken[key] ?? 0) >= PER_KEY_RUN || (counters.byKey[key] ?? 0) + (taken[key] ?? 0) >= cfg.perKeyDaily) continue;
        if (prints.some((p) => chosenPrints.some((c) => sameFingerprint(p, c)))) continue; // même événement qu'un sujet déjà choisi (autre langue, autre domaine)
        taken[key] = (taken[key] ?? 0) + 1;
        chosenPrints.push(...prints);
        out.push(t);
        break;
      }
    }
  }
  return out;
}

/** Modèle de qualité tant que la consommation du jour reste sous 60 % du plafond, puis le modèle léger. */
export function chooseModel(usedTotal: number, models: { quality: string; light: string } = DEFAULT_MODELS): string {
  return usedTotal < DAILY_TOTAL_CAP * 0.6 ? models.quality : models.light;
}

async function pool<T, R>(list: T[], size: number, fn: (x: T) => Promise<R>): Promise<R[]> {
  const out: R[] = new Array(list.length);
  let next = 0;
  await Promise.all(Array.from({ length: Math.min(size, list.length) }, async () => {
    while (next < list.length) { const i = next++; out[i] = await fn(list[i]); }
  }));
  return out;
}

export interface SourceStatus { id: string; name: string; url: string; active: boolean; ok: boolean; items: number; newest: string | null; error: string | null; ms: number }

/** Lit une source ; ne lève jamais (l'erreur est dans le statut). */
export async function readSource(s: NewsSourceDef, fetchImpl?: typeof fetch): Promise<{ status: SourceStatus; items: RawItem[] }> {
  const t0 = Date.now();
  try {
    const feed = await fetchFeed(s.url, fetchImpl);
    const newest = feed.reduce<string | null>((m, it) => (!m || it.date > m ? it.date : m), null);
    return { status: { id: s.id, name: s.name, url: s.url, active: s.active, ok: true, items: feed.length, newest, error: null, ms: Date.now() - t0 }, items: feed.slice(0, 40).map((it) => toRaw(s, it)) };
  } catch (e) {
    return { status: { id: s.id, name: s.name, url: s.url, active: s.active, ok: false, items: 0, newest: null, error: (e instanceof Error ? e.message : String(e)).slice(0, 120), ms: Date.now() - t0 }, items: [] };
  }
}

/** Écrit l'état des sources : toujours les erreurs, et les succès seulement un passage sur trois (économie d'écritures). */
async function saveStatuses(list: SourceStatus[], nowMs: number): Promise<void> {
  const writeOk = new Date(nowMs).getUTCHours() % 6 < 2;
  const todo = list.filter((s) => !s.ok || writeOk);
  if (!todo.length) return;
  try {
    const batch = db.batch();
    for (const s of todo) batch.set(db.collection("NewsSources").doc(s.id), { ...s, at: nowMs }, { merge: true });
    await batch.commit();
  } catch (e) {
    console.error("[actualités] état des sources non écrit", e);
  }
}

async function loadSeen(hashes: string[]): Promise<Map<string, SeenInfo>> {
  const out = new Map<string, SeenInfo>();
  for (let i = 0; i < hashes.length; i += 300) {
    const snaps = await db.getAll(...hashes.slice(i, i + 300).map((h) => db.collection("NewsSeen").doc(h)));
    for (const s of snaps) if (s.exists) out.set(s.id, s.data() as SeenInfo);
  }
  return out;
}

/** Verrou : un seul passage à la fois (9 minutes au plus). Retourne false si un autre passage est en cours. */
export async function acquireRunLock(nowMs: number): Promise<boolean> {
  const ref = db.collection("NewsRuns").doc("_lock");
  return db.runTransaction(async (tx) => {
    const cur = Number((await tx.get(ref)).data()?.["lockedUntil"] ?? 0);
    if (cur > nowMs) return false;
    tx.set(ref, { lockedUntil: nowMs + LOCK_MS });
    return true;
  });
}
export async function releaseRunLock(): Promise<void> {
  await db.collection("NewsRuns").doc("_lock").set({ lockedUntil: 0 }).catch(() => undefined);
}

export interface PipelineReport {
  skipped?: string;
  sources: { ok: number; failed: Array<{ id: string; error: string }> };
  fetched: number;
  topics: number;
  planned: Array<{ title: string; agent: string; key: string; sources: number; score: number }>;
  published: Array<{ id: string; title: string; scope: string }>;
  failed: Array<{ title: string; reason: string }>;
  quotaHit: boolean;
  neurons: number;
  ms: number;
}

export interface RunOpts { nowMs?: number; maxPublish?: number; dryRun?: boolean; fetchImpl?: typeof fetch }

export async function runNewsPipeline(opts: RunOpts = {}): Promise<PipelineReport> {
  const t0 = Date.now();
  const now = opts.nowMs ?? t0;
  const report: PipelineReport = { sources: { ok: 0, failed: [] }, fetched: 0, topics: 0, planned: [], published: [], failed: [], quotaHit: false, neurons: 0, ms: 0 };
  const cfgDoc = (await db.collection("AppConfig").doc("news").get()).data();
  const cfg = readPipelineConfig(cfgDoc);
  if (!cfg.enabled) { report.skipped = "Actualités désactivées"; return report; }
  if (opts.maxPublish) cfg.perRun = Math.max(1, Math.min(cfg.perRun, opts.maxPublish));

  // plafond du jour et titres récents lus AVANT toute collecte : plafond atteint, on s'arrête là
  const day = dayKey(now);
  const [today, yesterday] = await db.getAll(db.collection("NewsRuns").doc(day), db.collection("NewsRuns").doc(dayKey(now - 86_400_000)));
  const cnt: Counters = { published: Number(today.data()?.["published"] ?? 0), byKey: (today.data()?.["byKey"] ?? {}) as Record<string, number> };
  const recent = [...((yesterday.data()?.["titles"] as string[] | undefined) ?? []), ...((today.data()?.["titles"] as string[] | undefined) ?? [])];
  if (cnt.published >= cfg.dailyCap) { report.skipped = `Plafond du jour atteint (${cnt.published} articles)`; return report; }

  if (!opts.dryRun && !(await acquireRunLock(now))) { report.skipped = "Un autre passage est déjà en cours"; return report; }
  try {
    // 1. collecte
    const sources = activeSources({ sourcesOn: cfgDoc?.["sourcesOn"] as Record<string, boolean> | undefined, customSources: cfgDoc?.["customSources"] });
    const results = await pool(sources, 6, (s) => readSource(s, opts.fetchImpl));
    const items = results.flatMap((r) => r.items);
    report.fetched = items.length;
    for (const r of results) { if (r.status.ok) report.sources.ok++; else report.sources.failed.push({ id: r.status.id, error: r.status.error ?? "" }); }
    await saveStatuses(results.map((r) => r.status), now);

    // 2. sujets, déjà vus, plafonds
    const topics = buildTopics(items, cfg.countries, now);
    report.topics = topics.length;
    const candidates = topics.slice(0, 80);
    const seen = await loadSeen([...new Set(candidates.flatMap((t) => t.items.map((i) => linkHash(i.lien))))]);
    const plan = planSelection(candidates, cnt, cfg, seen, now, recent);
    report.planned = plan.map((t) => ({ title: t.items[0].titre.slice(0, 110), agent: AGENT_OF_CATEGORY[t.category], key: topicKey(t), sources: t.distinctSources, score: Math.round(t.score * 10) / 10 }));

    if (!opts.dryRun && plan.length) {
      // 3. image de l'article de la source quand le flux n'en donne pas (quelques pages seulement)
      let previews = 0;
      for (const t of plan) {
        if (t.items.some((i) => i.image) || previews >= 8) continue;
        previews++;
        const pv = await fetchPreview(t.items[0].lien, opts.fetchImpl);
        if (pv?.image) t.items[0].image = pv.image;
      }

      // 4. résumé et publication, un sujet après l'autre
      const usageBefore = Object.values(await loadUsage(now)).reduce((s, n) => s + n, 0);
      let used = usageBefore;
      const quotaFlag = { hit: false };
      for (const t of plan) {
        if (quotaFlag.hit) break;
        const res = await summarizeTopic(t, { model: chooseModel(used), nowMs: now, quotaFlag, countryName: null });
        used += res.neurons ?? res.ai?.neurons ?? 0;
        const title = t.items[0].titre.slice(0, 110);
        const hashes = t.items.map((i) => linkHash(i.lien));
        if (!res.ok || !res.input) {
          const reason = res.error ?? (res.errors ?? []).join(", ");
          report.failed.push({ title, reason });
          // texte refusé : 4 h avant de retenter (une autre source peut rejoindre le sujet) ; erreur de l'IA ou du réseau : 1 h
          if (!quotaFlag.hit) await markSeen(hashes, { status: "failed", retryAfter: now + (res.errors?.length ? 4 : 1) * 3600_000 }, now);
          await logNews({ kind: "collect", ok: false, message: `Résumé refusé : ${title} (${reason})`.slice(0, 240) });
          continue;
        }
        const clean = cleanNewsInput(res.input);
        if (!clean.ok) {
          report.failed.push({ title, reason: clean.error });
          await markSeen(hashes, { status: "failed", retryAfter: now + 12 * 3600_000 }, now);
          await logNews({ kind: "collect", ok: false, message: `Article invalide : ${title} (${clean.error})`.slice(0, 240) });
          continue;
        }
        const pub = await publishNews(clean.value, { nowMs: now });
        report.published.push({ id: pub.id, title: clean.value.title, scope: pub.scope });
        await markSeen(hashes, { status: "published", postId: pub.id } as SeenInfo & { postId: string }, now);
        // compteurs du jour et titres des sources (pour écarter le même événement raconté plus tard par d'autres sources)
        await db.collection("NewsRuns").doc(day).set({
          day, published: FieldValue.increment(1), byKey: { [topicKey(t)]: FieldValue.increment(1) },
          titles: FieldValue.arrayUnion(...t.items.slice(0, 3).map((i) => i.titre.slice(0, 120))), updatedAt: now,
        }, { merge: true });
      }
      report.quotaHit = quotaFlag.hit;
      report.neurons = Math.round((used - usageBefore) * 10) / 10;
    }

    report.ms = Date.now() - t0;
    // le journal garde une ligne par passage utile ; un passage sans rien à faire n'écrit rien
    if (opts.dryRun || plan.length || report.sources.failed.length) {
      await logNews({
        kind: "collect", ok: report.failed.length === 0 && !report.quotaHit,
        message: `${opts.dryRun ? "Essai sans IA" : "Passage"} : ${report.sources.ok} sources lues, ${report.sources.failed.length} en erreur, ${report.fetched} articles, ${report.topics} sujets, ${report.published.length} publiés, ${report.failed.length} refusés${report.quotaHit ? ", quota atteint" : ""}`,
        ms: report.ms, neurons: report.neurons,
      });
    }
    return report;
  } finally {
    if (!opts.dryRun) await releaseRunLock();
  }
}

async function markSeen(hashes: string[], info: SeenInfo, nowMs: number): Promise<void> {
  try {
    const batch = db.batch();
    for (const h of hashes) batch.set(db.collection("NewsSeen").doc(h), { ...info, at: nowMs });
    await batch.commit();
  } catch (e) {
    console.error("[actualités] sujets vus non écrits", e);
  }
}
