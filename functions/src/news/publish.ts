import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { buildFeedItem, buildNewsPostDoc, mergeFeedItems, NewsClean } from "./model";

/**
 * Publie un article : écrit le post (Posts/{id}, type NEWS), l'ajoute à l'index du périmètre (NewsFeed/{périmètre}, 30 éléments au plus,
 * lu par l'application à raison de 3 documents par session) et compte l'article pour son agent (NewsAgents/{clé}).
 * Le post est écrit en premier : l'index ne cite jamais un article qui n'existe pas encore.
 */
export async function publishNews(n: NewsClean, opts: { id?: string; nowMs?: number } = {}): Promise<{ id: string; scope: string }> {
  const now = opts.nowMs ?? Date.now();
  const ref = opts.id ? db.collection("Posts").doc(opts.id) : db.collection("Posts").doc();
  await ref.set(buildNewsPostDoc(n, ref.id, now));

  const feedRef = db.collection("NewsFeed").doc(n.scope);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(feedRef);
    tx.set(feedRef, { scope: n.scope, items: mergeFeedItems(snap.data()?.["items"], buildFeedItem(n, ref.id, now)), updatedAt: now });
  });

  await db.collection("NewsAgents").doc(n.agentKey).set(
    { key: n.agentKey, articles: FieldValue.increment(1), lastPublishedAt: now },
    { merge: true },
  );
  return { id: ref.id, scope: n.scope };
}

/** Retire un article du fil et de l'index (le post est supprimé ; ses commentaires restent sans effet). */
export async function removeNews(postId: string): Promise<{ removed: boolean }> {
  const ref = db.collection("Posts").doc(postId);
  const snap = await ref.get();
  if (!snap.exists || snap.data()?.["type"] !== "NEWS") return { removed: false };
  const scope = String((snap.data()?.["news"] as Record<string, unknown> | undefined)?.["scope"] ?? "");
  await ref.delete();
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
