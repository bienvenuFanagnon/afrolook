import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { NEWS_AGENTS, agentUserId } from "./agents";
import { logNews } from "./log";
import { buildFeedItem, buildNewsPostDoc, mergeFeedItems, NewsClean } from "./model";

/**
 * Publie un article : écrit le post (Posts/{id}, type NEWS), l'ajoute à l'index du périmètre (NewsFeed/{périmètre}, 30 éléments au plus,
 * lu par l'application à raison de 3 documents par session) et compte l'article pour son agent (NewsAgents/{clé}).
 * Le post est écrit en premier : l'index ne cite jamais un article qui n'existe pas encore.
 */
export const NEWS_ID_PREFIX = "news_";

const ensured = new Set<string>();

/** Crée le compte d'un agent s'il n'existe pas encore (une lecture par agent et par instance) : plus besoin de passer par l'administration. */
export async function ensureAgent(key: string): Promise<void> {
  if (ensured.has(key)) return;
  const agent = NEWS_AGENTS.find((a) => a.key === key);
  if (!agent) return;
  const ref = db.collection("Users").doc(agentUserId(key));
  if (!(await ref.get()).exists) {
    const now = Date.now();
    await ref.set({ id: agentUserId(key), pseudo: agent.pseudo, role: "USER", isNewsAgent: true, newsAgentKey: key, newsAgentCategory: agent.category, createdAt: now, updatedAt: now }, { merge: true });
    await db.collection("NewsAgents").doc(key).set({ key, pseudo: agent.pseudo, category: agent.category, label: agent.label, userId: agentUserId(key) }, { merge: true });
  }
  ensured.add(key);
}

export async function publishNews(n: NewsClean, opts: { id?: string; nowMs?: number } = {}): Promise<{ id: string; scope: string }> {
  const now = opts.nowMs ?? Date.now();
  await ensureAgent(n.agentKey);
  // Identifiant préfixé « news_ » : le déclencheur des commentaires reconnaît un article sans aucune lecture (les commentaires des autres posts ne coûtent rien)
  const ref = opts.id ? db.collection("Posts").doc(opts.id) : db.collection("Posts").doc(`${NEWS_ID_PREFIX}${db.collection("Posts").doc().id}`);
  await ref.set(buildNewsPostDoc(n, ref.id, now));

  const feedRef = db.collection("NewsFeed").doc(n.scope);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(feedRef);
    tx.set(feedRef, { scope: n.scope, items: mergeFeedItems(snap.data()?.["items"], buildFeedItem(n, ref.id, now), now), updatedAt: now });
  });

  await db.collection("NewsAgents").doc(n.agentKey).set(
    { key: n.agentKey, articles: FieldValue.increment(1), lastPublishedAt: now },
    { merge: true },
  );
  await logNews({ kind: "publish", ok: true, message: `${n.agentKey} · ${n.scope} : ${n.title.slice(0, 90)}`, ref: ref.id }, now);
  return { id: ref.id, scope: n.scope };
}

/** Retire un article du fil et de l'index : le post, son état de notifications et ses commentaires (300 au plus par appel) sont supprimés. */
export async function removeNews(postId: string): Promise<{ removed: boolean }> {
  const ref = db.collection("Posts").doc(postId);
  const snap = await ref.get();
  if (!snap.exists || snap.data()?.["type"] !== "NEWS") return { removed: false };
  const scope = String((snap.data()?.["news"] as Record<string, unknown> | undefined)?.["scope"] ?? "");
  await ref.delete();
  await db.collection("NewsPushState").doc(postId).delete().catch(() => undefined);
  await purgeComments(postId);
  if (scope) {
    const feedRef = db.collection("NewsFeed").doc(scope);
    await db.runTransaction(async (tx) => {
      const f = await tx.get(feedRef);
      if (!f.exists) return;
      const items = ((f.data()?.["items"] as Array<{ id?: string }> | undefined) ?? []).filter((x) => x.id !== postId);
      tx.set(feedRef, { scope, items, updatedAt: Date.now() }, { merge: true });
    });
  }
  return { removed: true };
}

/** Supprime les commentaires d'un article disparu (ils n'ont plus de page où s'afficher). */
export async function purgeComments(postId: string, limit = 300): Promise<number> {
  try {
    const snap = await db.collection("PostComments").where("post_id", "==", postId).limit(limit).get();
    if (snap.empty) return 0;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    return snap.size;
  } catch (e) {
    console.error("[actualités] commentaires non supprimés", e);
    return 0;
  }
}
