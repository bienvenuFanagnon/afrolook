import { onCall, HttpsError, CallableRequest } from "firebase-functions/v2/https";
import { db } from "../shared/firebase";
import { NEWS_AGENTS, agentUserId } from "./agents";
import { cleanNewsInput } from "./model";
import { publishNews, removeNews } from "./publish";

/**
 * Outils d'administration des actualités (réservés aux administrateurs) :
 * - newsSeedAgents    : crée ou met à jour les comptes des agents (Users) et leurs compteurs (NewsAgents) ; sans danger si on le relance ;
 * - newsPublishManual : publie un article saisi à la main (essai de la carte et de la page de détail avant le pipeline automatique) ;
 * - newsAgentStats    : par agent, articles publiés, vues, j'aime, commentaires, et cadeaux reçus (information : les vrais gains vont à l'app) ;
 * - newsDeleteArticle : retire un article ;
 * - newsSetConfig     : interrupteurs (AppConfig/news : enabled, feedEnabled).
 */
const ADMIN_ROLES = ["ADM", "admin", "ADMIN", "super_admin"];
const OPTS = { region: "us-central1" as const, timeoutSeconds: 60, memory: "256MiB" as const };

async function requireAdmin(request: CallableRequest): Promise<string> {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Connexion requise");
  const role = String((await db.collection("Users").doc(uid).get()).data()?.["role"] ?? "");
  if (!ADMIN_ROLES.includes(role)) throw new HttpsError("permission-denied", "Réservé aux administrateurs");
  return uid;
}

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
  await db.collection("AppConfig").doc("news").set(patch, { merge: true });
  return { ok: true, ...patch };
});

export const newsAgentStats = onCall(OPTS, async (request) => {
  await requireAdmin(request);
  const [agents, cfg, posts] = await Promise.all([
    db.getAll(...NEWS_AGENTS.map((a) => db.collection("NewsAgents").doc(a.key))),
    db.collection("AppConfig").doc("news").get(),
    // les 200 derniers articles suffisent à un tableau de bord (200 lectures par ouverture de l'écran)
    db.collection("Posts").where("type", "==", "NEWS").orderBy("created_at", "desc").limit(200).get(),
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
    config: { enabled: cfg.data()?.["enabled"] !== false, feedEnabled: cfg.data()?.["feedEnabled"] === true },
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
