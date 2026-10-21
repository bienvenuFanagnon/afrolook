import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db } from "../shared/firebase";
import { AiError, CF_NEWS_ACCOUNTS, DAILY_TOTAL_CAP, DEFAULT_MODELS, PER_ACCOUNT_CAP, loadUsage, maskId, parseAccounts, runAi } from "./ai";
import { requireAdmin } from "./adminAuth";
import { COUNTRY_KEYWORDS } from "./cluster";
import { DEFAULT_SOURCES } from "./sources";
import { readPipelineConfig } from "./pipeline";
import { NEWS_AGENTS, agentUserId } from "./agents";
import { readNewsLogs } from "./log";
import { DAY_MS, cleanNewsInput } from "./model";
import { publishNews, removeNews } from "./publish";

/**
 * Outils d'administration des actualités (réservés aux administrateurs) :
 * - newsSeedAgents    : crée ou met à jour les comptes des agents (Users) et leurs compteurs (NewsAgents) ; sans danger si on le relance ;
 * - newsPublishManual : publie un article saisi à la main (essai de la carte et de la page de détail avant le pipeline automatique) ;
 * - newsAgentStats    : par agent, articles publiés, vues, j'aime, commentaires, et cadeaux reçus (information : les vrais gains vont à l'app) ;
 * - newsDeleteArticle : retire un article ;
 * - newsListArticles  : les 40 derniers articles avec leur fin de vie et leur engagement ;
 * - newsExtendArticle : prolonge la vie d'un article (1 à 30 jours) ;
 * - newsSetConfig     : interrupteurs (AppConfig/news : enabled, feedEnabled) ;
 * - newsLogs          : journal (appels à l'IA, articles publiés, incidents) et état de chaque compte Cloudflare ;
 * - newsCheckAi       : teste chaque compte Cloudflare (une toute petite question) et montre la consommation du jour ; ne renvoie jamais de clé.
 */
const OPTS = { region: "us-central1" as const, timeoutSeconds: 60, memory: "256MiB" as const };

export const newsSeedAgents = onCall(OPTS, async (request) => {
  await requireAdmin(request);
  const now = Date.now();
  const batch = db.batch();
  for (const a of NEWS_AGENTS) {
    // `merge` : un compte déjà créé (abonnés, photo choisie plus tard) n'est jamais écrasé
    batch.set(db.collection("Users").doc(agentUserId(a.key)), {
      id: agentUserId(a.key), pseudo: a.pseudo, role: "USER", isNewsAgent: true, newsAgentKey: a.key, newsAgentCategory: a.category,
      createdAt: now, updatedAt: now,
    }, { merge: true });
    batch.set(db.collection("NewsAgents").doc(a.key), { key: a.key, pseudo: a.pseudo, category: a.category, label: a.label, userId: agentUserId(a.key) }, { merge: true });
  }
  await batch.commit();
  return { agents: NEWS_AGENTS.map((a) => ({ key: a.key, pseudo: a.pseudo, userId: agentUserId(a.key) })) };
});

export const newsPublishManual = onCall(OPTS, async (request) => {
  await requireAdmin(request);
  const r = cleanNewsInput(request.data);
  if (!r.ok) throw new HttpsError("invalid-argument", r.error);
  const published = await publishNews(r.value);
  return { ...published, title: r.value.title };
});

export const newsDeleteArticle = onCall(OPTS, async (request) => {
  await requireAdmin(request);
  const id = String((request.data as Record<string, unknown> | undefined)?.["id"] ?? "");
  if (!/^[A-Za-z0-9_-]{4,64}$/.test(id)) throw new HttpsError("invalid-argument", "Identifiant invalide");
  return removeNews(id);
});

export const newsSetConfig = onCall(OPTS, async (request) => {
  await requireAdmin(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const patch: Record<string, unknown> = { updatedAt: Date.now() };
  if (typeof d["enabled"] === "boolean") patch["enabled"] = d["enabled"];
  if (typeof d["feedEnabled"] === "boolean") patch["feedEnabled"] = d["feedEnabled"];
  if (typeof d["pipelineEnabled"] === "boolean") patch["pipelineEnabled"] = d["pipelineEnabled"];
  if (Array.isArray(d["countries"])) patch["countries"] = (d["countries"] as unknown[]).map((c) => String(c).trim().toUpperCase()).filter((c) => c in COUNTRY_KEYWORDS).slice(0, 30);
  for (const [k, min, max] of [["dailyCap", 1, 300], ["perRun", 1, 12], ["perKeyDaily", 1, 6]] as const) {
    const n = Math.trunc(Number(d[k]));
    if (d[k] !== undefined && Number.isFinite(n) && n >= min && n <= max) patch[k] = n;
  }
  if (d["sourcesOn"] && typeof d["sourcesOn"] === "object") {
    const known = new Set(DEFAULT_SOURCES.map((x) => x.id));
    const on: Record<string, boolean> = {};
    for (const [id, v] of Object.entries(d["sourcesOn"] as Record<string, unknown>)) if (known.has(id) && typeof v === "boolean") on[id] = v;
    patch["sourcesOn"] = on;
  }
  await db.collection("AppConfig").doc("news").set(patch, { merge: true });
  return { ok: true, ...patch };
});

export const newsAgentStats = onCall(OPTS, async (request) => {
  await requireAdmin(request);
  const [agents, cfg, posts] = await Promise.all([
    db.getAll(...NEWS_AGENTS.map((a) => db.collection("NewsAgents").doc(a.key))),
    db.collection("AppConfig").doc("news").get(),
    // les 120 derniers articles suffisent à un tableau de bord (120 lectures par ouverture de l'écran)
    db.collection("Posts").where("type", "==", "NEWS").orderBy("created_at", "desc").limit(120).get(),
  ]);
  const per: Record<string, { views: number; loves: number; comments: number; recent: number }> = {};
  for (const d of posts.docs) {
    const p = d.data();
    const key = String((p["news"] as Record<string, unknown> | undefined)?.["agentKey"] ?? "");
    const s = (per[key] ??= { views: 0, loves: 0, comments: 0, recent: 0 });
    s.views += Number(p["vues"] ?? 0);
    s.loves += Number(p["loves"] ?? 0);
    s.comments += Number(p["comments"] ?? 0);
    s.recent += 1;
  }
  return {
    config: { ...readPipelineConfig(cfg.data()), feedEnabled: cfg.data()?.["feedEnabled"] === true, sourcesOn: (cfg.data()?.["sourcesOn"] as Record<string, boolean> | undefined) ?? {} },
    agents: NEWS_AGENTS.map((a, i) => {
      const d = agents[i].data() ?? {};
      return {
        key: a.key, pseudo: a.pseudo, seeded: agents[i].exists,
        articles: Number(d["articles"] ?? 0), giftCoins: Number(d["giftCoins"] ?? 0), giftCount: Number(d["giftCount"] ?? 0),
        lastPublishedAt: Number(d["lastPublishedAt"] ?? 0),
        recent: per[a.key] ?? { views: 0, loves: 0, comments: 0, recent: 0 },
      };
    }),
  };
});

export const newsCheckAi = onCall({ ...OPTS, secrets: [CF_NEWS_ACCOUNTS] }, async (request) => {
  await requireAdmin(request);
  const accounts = parseAccounts(CF_NEWS_ACCOUNTS.value());
  const results: Array<{ account: string; ok: boolean; model?: string; neurons?: number; ms?: number; error?: string }> = [];
  for (const a of accounts) {
    let last = "";
    let done = false;
    // modèle léger d'abord (quelques neurons) ; s'il n'existe plus, on essaie le modèle de qualité
    for (const model of [DEFAULT_MODELS.light, DEFAULT_MODELS.quality]) {
      try {
        const r = await runAi([{ role: "user", content: "Réponds uniquement par le mot OK." }], { model, maxTokens: 5, accounts, accountId: a.id });
        results.push({ account: maskId(a.id), ok: true, model, neurons: Math.round(r.neurons * 100) / 100, ms: r.ms });
        done = true;
        break;
      } catch (e) {
        last = e instanceof AiError ? e.message : String(e).slice(0, 160);
      }
    }
    if (!done) results.push({ account: maskId(a.id), ok: false, error: last });
  }
  const used = await loadUsage();
  return {
    configured: accounts.length,
    results,
    today: accounts.map((a) => ({ account: maskId(a.id), neurons: Math.round((used[a.id] ?? 0) * 10) / 10, cap: PER_ACCOUNT_CAP })),
    dailyCap: DAILY_TOTAL_CAP,
  };
});

export const newsLogs = onCall(OPTS, async (request) => {
  await requireAdmin(request);
  const limit = Number((request.data as Record<string, unknown> | undefined)?.["limit"] ?? 60) || 60;
  return readNewsLogs(limit);
});

export const newsListArticles = onCall(OPTS, async (request) => {
  await requireAdmin(request);
  const snap = await db.collection("Posts").where("type", "==", "NEWS").orderBy("created_at", "desc").limit(40).get();
  return {
    articles: snap.docs.map((d) => {
      const p = d.data();
      const n = (p["news"] ?? {}) as Record<string, unknown>;
      const created = Number(p["created_at"]) || 0;
      return {
        id: d.id, title: String(n["title"] ?? ""), agentKey: String(n["agentKey"] ?? ""), scope: String(n["scope"] ?? ""),
        createdAt: created > 1e14 ? Math.floor(created / 1000) : created, expiresAt: Number(p["expiresAt"]) || 0, extendedTier: Number(p["extendedTier"]) || 1,
        views: Number(p["vues"] ?? 0), loves: Number(p["loves"] ?? 0), comments: Number(p["comments"] ?? 0), gifts: Number(p["giftCount"] ?? 0),
      };
    }),
  };
});

export const newsExtendArticle = onCall(OPTS, async (request) => {
  await requireAdmin(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const id = String(d["id"] ?? "");
  const days = Math.max(1, Math.min(30, Math.trunc(Number(d["days"] ?? 7)) || 7));
  if (!/^[A-Za-z0-9_-]{4,64}$/.test(id)) throw new HttpsError("invalid-argument", "Identifiant invalide");
  const ref = db.collection("Posts").doc(id);
  const snap = await ref.get();
  if (!snap.exists || snap.data()?.["type"] !== "NEWS") throw new HttpsError("not-found", "Article introuvable");
  const now = Date.now();
  const expiresAt = Math.max(Number(snap.data()?.["expiresAt"]) || 0, now) + days * DAY_MS;
  await ref.update({ expiresAt });
  // l'index du fil porte la fin de vie de chaque article : on la met à jour pour que l'article reste affiché
  const scope = String((snap.data()?.["news"] as Record<string, unknown> | undefined)?.["scope"] ?? "");
  if (scope) {
    const feedRef = db.collection("NewsFeed").doc(scope);
    await db.runTransaction(async (tx) => {
      const f = await tx.get(feedRef);
      if (!f.exists) return;
      const items = ((f.data()?.["items"] as Array<{ id?: string }> | undefined) ?? []).map((i) => (i.id === id ? { ...i, exp: expiresAt } : i));
      tx.set(feedRef, { items, updatedAt: now }, { merge: true });
    });
  }
  return { id, expiresAt };
});
