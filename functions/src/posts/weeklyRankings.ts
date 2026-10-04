import { onSchedule } from "firebase-functions/v2/scheduler";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";

/**
 * Classements hebdomadaires SANS récompense : Top Posts et Top Créateurs.
 * Stockés dans WeeklyTopPosts/{weekId} et WeeklyTopCreators/{weekId} (rankings triés, 20 max),
 * comme WeeklyTopCommentators. Semaine ISO, lundi 00:00 UTC → lundi suivant.
 */
const STORED = 20;
const MIN_POST_SCORE = 3;

export function isoWeekId(d: Date): string {
  const date = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  const dayNum = date.getUTCDay() || 7;
  date.setUTCDate(date.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1));
  const weekNo = Math.ceil(((date.getTime() - yearStart.getTime()) / 86400000 + 1) / 7);
  return `${date.getUTCFullYear()}-W${String(weekNo).padStart(2, "0")}`;
}

/** Bornes [début, fin[ en microsecondes (created_at) d'une semaine ISO « 2026-W39 ». */
export function weekRangeMicros(weekId: string): { start: number; end: number } {
  const [y, w] = weekId.split("-W").map(Number);
  const jan4 = new Date(Date.UTC(y, 0, 4));
  const day1 = new Date(jan4.getTime() - ((jan4.getUTCDay() || 7) - 1) * 86400000);
  const start = day1.getTime() + (w - 1) * 7 * 86400000;
  return { start: start * 1000, end: (start + 7 * 86400000) * 1000 };
}

export function lastWeekId(): string {
  return isoWeekId(new Date(Date.now() - 7 * 86400000));
}

const arr = (v: unknown): unknown[] => (Array.isArray(v) ? v : []);
const n = (v: unknown): number => (typeof v === "number" && Number.isFinite(v) ? v : 0);

async function postsOfWeek(weekId: string) {
  const { start, end } = weekRangeMicros(weekId);
  const out: FirebaseFirestore.QueryDocumentSnapshot[] = [];
  let last: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  for (;;) {
    let q = db.collection("Posts").where("created_at", ">=", start).where("created_at", "<", end)
      .orderBy("created_at").limit(500);
    if (last) q = q.startAfter(last);
    const snap = await q.get();
    out.push(...snap.docs);
    if (snap.size < 500) break;
    last = snap.docs[snap.docs.length - 1];
  }
  return out;
}

/** Top 20 des posts de la semaine : vues uniques + commentateurs uniques + personnes ayant aimé. */
export async function computeTopPosts(weekId: string): Promise<number> {
  const docs = await postsOfWeek(weekId);
  const scored = docs.map((d) => {
    const x = d.data();
    const uniqueViews = Math.max(arr(x["users_vue_id"]).length, n(x["uniqueViewsCount"]));
    const uniqueComments = arr(x["users_comments_id"]).length;
    const uniqueLikes = new Set([...arr(x["users_love_id"]), ...arr(x["users_like_id"])]).size;
    return {
      postId: d.id, authorId: String(x["user_id"] ?? ""),
      score: uniqueViews + uniqueComments + uniqueLikes, uniqueViews, uniqueComments, uniqueLikes,
    };
  }).filter((p) => p.score >= MIN_POST_SCORE && p.authorId).sort((a, b) => b.score - a.score).slice(0, STORED);

  await db.collection("WeeklyTopPosts").doc(weekId).set({
    weekId, computedAt: FieldValue.serverTimestamp(), totalPosts: docs.length,
    rankings: scored.map((p, i) => ({ rank: i + 1, ...p, rewardedCoins: 0, paid: false })),
    ...(scored.length === 0 ? { note: "no_eligible_posts" } : {}),
  });
  return scored.length;
}

/** Top 20 des créateurs (canal si le post appartient à un canal, sinon l'utilisateur) de la semaine. */
export async function computeTopCreators(weekId: string): Promise<number> {
  const docs = await postsOfWeek(weekId);
  type Agg = { isCanal: boolean; score: number; postCount: number; uniqueLovers: number; uniqueCommenters: number; totalViews: number };
  const by = new Map<string, Agg>();
  for (const d of docs) {
    const x = d.data();
    const canalId = String(x["canal_id"] ?? "").trim();
    const userId = String(x["user_id"] ?? "").trim();
    const id = canalId || userId;
    if (!id) continue;
    const uniqueLovers = arr(x["users_love_id"]).length;
    const uniqueCommenters = arr(x["users_comments_id"]).length;
    const uniqueViewers = arr(x["users_vue_id"]).length;
    const score = 5 + uniqueLovers * 3 + n(x["loves"]) * 0.3 + uniqueCommenters * 4 + n(x["comments"]) * 0.3 +
      uniqueViewers + n(x["vues"]) * 0.05 + n(x["giftCount"]) * 2 + n(x["partage"]) * 1.5 + n(x["totalInteractions"]) * 0.2;
    const a = by.get(id) ?? { isCanal: !!canalId, score: 0, postCount: 0, uniqueLovers: 0, uniqueCommenters: 0, totalViews: 0 };
    a.score += score; a.postCount++; a.uniqueLovers += uniqueLovers; a.uniqueCommenters += uniqueCommenters; a.totalViews += uniqueViewers;
    by.set(id, a);
  }
  const top = [...by.entries()].sort((a, b) => b[1].score - a[1].score).slice(0, STORED);
  await db.collection("WeeklyTopCreators").doc(weekId).set({
    weekId, computedAt: FieldValue.serverTimestamp(), totalPosts: docs.length,
    rankings: top.map(([entityId, a], i) => ({ rank: i + 1, entityId, ...a, score: Math.round(a.score * 10) / 10 })),
    ...(top.length === 0 ? { note: "no_posts" } : {}),
  });
  return top.length;
}

/** Chaque lundi : classement des créateurs de la semaine écoulée (sans récompense). */
export const weeklyTopCreatorsRanking = onSchedule(
  { schedule: "15 0 * * MON", timeZone: "UTC", memory: "512MiB", timeoutSeconds: 300 },
  async () => {
    const weekId = lastWeekId();
    const count = await computeTopCreators(weekId);
    console.log(`[weeklyCreators] ${weekId} : ${count} créateurs classés`);
  }
);
