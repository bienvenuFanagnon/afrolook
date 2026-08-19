import { onSchedule } from "firebase-functions/v2/scheduler";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";

// ─── Constantes ──────────────────────────────────────────────────────────────

const COMMENTATOR_REWARDS = [500, 300, 200, 100, 50]; // rangs 1-5
const POST_REWARDS = [1000, 500, 300]; // rangs 1-3
const MIN_COMMENT_LENGTH = 10;
const MIN_ACCOUNT_AGE_DAYS = 7;
const MIN_POST_SCORE = 10;
const TOP_POSTS_STORED = 20; // stocke top 20, récompense top 3

// ─── Helpers ─────────────────────────────────────────────────────────────────

function _isoWeekId(d: Date): string {
  const date = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  const dayNum = date.getUTCDay() || 7;
  date.setUTCDate(date.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1));
  const weekNo = Math.ceil(((date.getTime() - yearStart.getTime()) / 86400000 + 1) / 7);
  return `${date.getUTCFullYear()}-W${String(weekNo).padStart(2, "0")}`;
}

/** Retourne l'identifiant ISO de la semaine précédente, ex. "2026-W33". */
function getLastWeekId(): string {
  return _isoWeekId(new Date(Date.now() - 7 * 86400000));
}

/** Retourne le timestamp microsecondes du lundi 00:00 UTC de la semaine précédente. */
function getLastWeekStartMicros(): number {
  const now = new Date();
  const day = now.getUTCDay() || 7;
  const monday = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - (day - 1) - 7));
  monday.setUTCHours(0, 0, 0, 0);
  return monday.getTime() * 1000;
}

/** Retourne le timestamp microsecondes du lundi 00:00 UTC de la semaine en cours (= fin semaine précédente). */
function getWeekStartMicros(): number {
  const now = new Date();
  const day = now.getUTCDay() || 7;
  const monday = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() - (day - 1)));
  monday.setUTCHours(0, 0, 0, 0);
  return monday.getTime() * 1000;
}

/** Tente de créer le verrou. Retourne false si la semaine est déjà traitée. */
async function acquireLock(weekId: string, type: string): Promise<boolean> {
  const lockId = `${weekId}_${type}`;
  const lockRef = db.collection("WeeklyRewardLocks").doc(lockId);
  try {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(lockRef);
      if (snap.exists) throw new Error("ALREADY_PROCESSED");
      tx.create(lockRef, {
        weekId,
        type,
        processedAt: FieldValue.serverTimestamp(),
      });
    });
    return true;
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    if (msg === "ALREADY_PROCESSED") return false;
    throw err;
  }
}

/** Crédite des pièces (giftCoins) à un utilisateur et enregistre la transaction. */
async function rewardUser(params: {
  userId: string;
  coins: number;
  rank: number;
  weekId: string;
  subType: "top_commentator" | "top_post";
  postId?: string;
}): Promise<void> {
  const { userId, coins, rank, weekId, subType, postId } = params;
  const userRef = db.collection("Users").doc(userId);
  const txRef = db.collection("Transactions").doc();

  await db.runTransaction(async (tx) => {
    tx.update(userRef, { giftCoins: FieldValue.increment(coins) });
    tx.set(txRef, {
      type: "weekly_reward",
      subType,
      weekId,
      receiverId: userId,
      coinsAmount: coins,
      rank,
      ...(postId ? { postId } : {}),
      createdAt: FieldValue.serverTimestamp(),
    });
  });
}

// ─── 1. TOP COMMENTATEURS ────────────────────────────────────────────────────

/**
 * Chaque lundi à 00:05 UTC : calcule les 5 meilleurs commentateurs de la
 * semaine écoulée et leur envoie des pièces.
 *
 * Règles anti-spam :
 * - Collection : PostComments (created_at en microsecondes, champs snake_case)
 * - Message réel : longueur >= MIN_COMMENT_LENGTH
 * - Compte >= MIN_ACCOUNT_AGE_DAYS jours
 * - 1 seul commentaire par post par user (on décompte les posts distincts)
 */
export const weeklyTopCommentatorsReward = onSchedule(
  {
    schedule: "5 0 * * MON",
    timeZone: "UTC",
    memory: "512MiB",
    cpu: 1,
    timeoutSeconds: 300,
  },
  async () => {
    // La fonction tourne le lundi matin → on récompense la semaine qui vient de se terminer
    const weekId = getLastWeekId();
    console.log(`[weeklyCommentators] Semaine récompensée : ${weekId}`);

    const locked = await acquireLock(weekId, "commentators");
    if (!locked) {
      console.log(`[weeklyCommentators] Déjà traité pour ${weekId}. Abandon.`);
      return;
    }

    const lastWeekStartMicros = getLastWeekStartMicros(); // lundi précédent 00:00
    const thisWeekStartMicros = getWeekStartMicros();      // lundi actuel 00:00 (fin de la période)
    const minAccountDate = new Date(Date.now() - MIN_ACCOUNT_AGE_DAYS * 86400000);

    // ── Charger tous les commentaires de la semaine écoulée ──
    // scoreMap : userId -> Set<post_id>  (1 post = 1 point max)
    const scoreMap = new Map<string, Set<string>>();

    let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | null = null;
    let fetched = 0;

    while (true) {
      let query = db
        .collection("PostComments")
        .where("created_at", ">=", lastWeekStartMicros)
        .where("created_at", "<", thisWeekStartMicros)
        .orderBy("created_at", "asc")
        .limit(500);

      if (lastDoc) query = query.startAfter(lastDoc);

      const snap = await query.get();
      if (snap.empty) break;

      for (const doc of snap.docs) {
        const data = doc.data();

        // Filtres de base (champs snake_case, message non vide)
        const userId: string = data.user_id ?? "";
        const postId: string = data.post_id ?? "";
        const message: string = data.message ?? "";

        if (!userId || !postId) continue;
        if (message.trim().length < MIN_COMMENT_LENGTH) continue;

        // 1 commentaire par post max par user
        if (!scoreMap.has(userId)) scoreMap.set(userId, new Set());
        scoreMap.get(userId)!.add(postId);
      }

      fetched += snap.size;
      lastDoc = snap.docs[snap.docs.length - 1];
      if (snap.size < 500) break;
    }

    console.log(`[weeklyCommentators] ${fetched} commentaires analysés, ${scoreMap.size} utilisateurs.`);

    if (scoreMap.size === 0) {
      console.log("[weeklyCommentators] Aucun commentaire éligible. Pas de récompense.");
      await db.collection("WeeklyTopCommentators").doc(weekId).set({
        weekId,
        computedAt: FieldValue.serverTimestamp(),
        rankings: [],
        note: "no_eligible_comments",
      });
      return;
    }

    // ── Vérifier l'ancienneté des comptes ──
    const userIds = Array.from(scoreMap.keys());
    const eligibleScores: Array<{ userId: string; count: number }> = [];

    for (let i = 0; i < userIds.length; i += 30) {
      const chunk = userIds.slice(i, i + 30);
      const usersSnap = await db
        .collection("Users")
        .where("__name__", "in", chunk)
        .select("createdAt", "id")
        .get();

      for (const userDoc of usersSnap.docs) {
        const createdAt: number = userDoc.data().createdAt ?? 0;
        // createdAt Users est en microsecondes aussi → convertir en ms pour comparer
        const accountDate = new Date(createdAt / 1000);
        if (accountDate > minAccountDate) continue; // compte trop récent

        const count = scoreMap.get(userDoc.id)?.size ?? 0;
        if (count > 0) eligibleScores.push({ userId: userDoc.id, count });
      }
    }

    eligibleScores.sort((a, b) => b.count - a.count);
    const top5 = eligibleScores.slice(0, 5);

    if (top5.length === 0) {
      console.log("[weeklyCommentators] Aucun gagnant éligible.");
      await db.collection("WeeklyTopCommentators").doc(weekId).set({
        weekId,
        computedAt: FieldValue.serverTimestamp(),
        rankings: [],
        note: "no_eligible_users",
      });
      return;
    }

    // ── Paiements ──
    const rankings: object[] = [];
    for (let i = 0; i < top5.length; i++) {
      const { userId, count } = top5[i];
      const coins = COMMENTATOR_REWARDS[i] ?? 0;
      const rank = i + 1;

      try {
        await rewardUser({ userId, coins, rank, weekId, subType: "top_commentator" });
        rankings.push({ rank, userId, commentCount: count, rewardedCoins: coins, paid: true });
        console.log(`[weeklyCommentators] Rang ${rank} — user ${userId} — ${coins} pièces`);
      } catch (err) {
        console.error(`[weeklyCommentators] Erreur paiement rang ${rank} :`, err);
        rankings.push({ rank, userId, commentCount: count, rewardedCoins: coins, paid: false, error: String(err) });
      }
    }

    await db.collection("WeeklyTopCommentators").doc(weekId).set({
      weekId,
      computedAt: FieldValue.serverTimestamp(),
      rankings,
    });

    console.log(`[weeklyCommentators] Terminé. ${rankings.length} gagnant(s).`);
  }
);

// ─── 2. TOP POSTS ─────────────────────────────────────────────────────────────

/**
 * Chaque lundi à 00:10 UTC : calcule le top 20 posts de la semaine
 * (score = vues uniques + commentateurs uniques + likeurs uniques)
 * et récompense les 3 premiers.
 *
 * Champs Posts : created_at (microsecondes), user_id, userlikes (array), vue (int),
 *               uniqueViewerIds (array optionnel)
 * Champs PostComments : post_id, user_id, created_at (microsecondes)
 */
export const weeklyTopPostsReward = onSchedule(
  {
    schedule: "10 0 * * MON",
    timeZone: "UTC",
    memory: "512MiB",
    cpu: 1,
    timeoutSeconds: 540,
  },
  async () => {
    const weekId = getLastWeekId();
    console.log(`[weeklyPosts] Semaine récompensée : ${weekId}`);

    const locked = await acquireLock(weekId, "posts");
    if (!locked) {
      console.log(`[weeklyPosts] Déjà traité pour ${weekId}. Abandon.`);
      return;
    }

    const lastWeekStartMicros = getLastWeekStartMicros();
    const thisWeekStartMicros = getWeekStartMicros();

    // ── Récupérer tous les posts publiés la semaine écoulée ──
    const postsSnap = await db
      .collection("Posts")
      .where("created_at", ">=", lastWeekStartMicros)
      .where("created_at", "<", thisWeekStartMicros)
      .select("user_id", "userlikes", "vue", "uniqueViewerIds", "created_at")
      .get();

    console.log(`[weeklyPosts] ${postsSnap.size} posts de la semaine écoulée.`);

    if (postsSnap.empty) {
      console.log("[weeklyPosts] Aucun post cette semaine.");
      await db.collection("WeeklyTopPosts").doc(weekId).set({
        weekId,
        computedAt: FieldValue.serverTimestamp(),
        rankings: [],
        note: "no_posts",
      });
      return;
    }

    type PostScore = {
      postId: string;
      authorId: string;
      score: number;
      uniqueViews: number;
      uniqueComments: number;
      uniqueLikes: number;
    };

    const scores: PostScore[] = [];
    const postDocs = postsSnap.docs;
    const PARALLEL = 10;

    for (let i = 0; i < postDocs.length; i += PARALLEL) {
      const chunk = postDocs.slice(i, i + PARALLEL);

      const results = await Promise.all(
        chunk.map(async (doc) => {
          const data = doc.data();
          const postId = doc.id;
          const authorId: string = data.user_id ?? ""; // champ snake_case

          // Vues uniques
          let uniqueViews = 0;
          if (Array.isArray(data.uniqueViewerIds)) {
            uniqueViews = data.uniqueViewerIds.length;
          } else if (typeof data.vue === "number") {
            uniqueViews = data.vue;
          }

          // Likes uniques (userlikes = tableau d'IDs)
          const uniqueLikes: number = Array.isArray(data.userlikes)
            ? data.userlikes.length
            : (typeof data.userlikes === "number" ? data.userlikes : 0);

          // Commentateurs uniques via PostComments (champs snake_case)
          let uniqueComments = 0;
          try {
            const commentsSnap = await db
              .collection("PostComments")
              .where("post_id", "==", postId)
              .where("created_at", ">=", lastWeekStartMicros)
              .where("created_at", "<", thisWeekStartMicros)
              .select("user_id")
              .get();

            const distinctCommenters = new Set(commentsSnap.docs.map((d) => d.data().user_id));
            uniqueComments = distinctCommenters.size;
          } catch (err) {
            console.warn(`[weeklyPosts] Erreur commentaires post ${postId}:`, err);
            uniqueComments = 0;
          }

          const score = uniqueViews + uniqueComments + uniqueLikes;
          return { postId, authorId, score, uniqueViews, uniqueComments, uniqueLikes };
        })
      );

      for (const r of results) {
        if (r.score >= MIN_POST_SCORE) scores.push(r);
      }
    }

    scores.sort((a, b) => b.score - a.score);
    const top20 = scores.slice(0, TOP_POSTS_STORED);
    const top3 = top20.slice(0, 3);

    if (top20.length === 0) {
      console.log("[weeklyPosts] Aucun post avec score suffisant.");
      await db.collection("WeeklyTopPosts").doc(weekId).set({
        weekId,
        computedAt: FieldValue.serverTimestamp(),
        rankings: [],
        note: "no_eligible_posts",
      });
      return;
    }

    const rankingsAll = top20.map((p, i) => ({
      rank: i + 1,
      postId: p.postId,
      authorId: p.authorId,
      score: p.score,
      uniqueViews: p.uniqueViews,
      uniqueComments: p.uniqueComments,
      uniqueLikes: p.uniqueLikes,
      rewardedCoins: POST_REWARDS[i] ?? 0,
      paid: false,
    }));

    for (let i = 0; i < top3.length; i++) {
      const p = top3[i];
      const coins = POST_REWARDS[i];
      if (!coins || !p.authorId) continue;

      try {
        await rewardUser({
          userId: p.authorId,
          coins,
          rank: i + 1,
          weekId,
          subType: "top_post",
          postId: p.postId,
        });
        rankingsAll[i].paid = true;
        console.log(`[weeklyPosts] Rang ${i + 1} — post ${p.postId} — auteur ${p.authorId} — ${coins} pièces`);
      } catch (err) {
        console.error(`[weeklyPosts] Erreur paiement rang ${i + 1} :`, err);
      }
    }

    await db.collection("WeeklyTopPosts").doc(weekId).set({
      weekId,
      computedAt: FieldValue.serverTimestamp(),
      rankings: rankingsAll,
    });

    console.log(`[weeklyPosts] Terminé. Top ${top20.length} posts stockés, ${top3.length} récompensés.`);
  }
);
