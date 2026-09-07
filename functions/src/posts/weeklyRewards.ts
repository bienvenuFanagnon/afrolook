import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { sendToOneSignal } from "../shared/notification_utils";

// ─── Constantes ──────────────────────────────────────────────────────────────

const COMMENTATOR_REWARDS = [500, 300, 200, 100, 50]; // rangs 1-5
const POST_REWARDS = [1000, 500, 300]; // rangs 1-3
const MIN_COMMENT_LENGTH = 10;  // minimum absolu pour être analysé
const MIN_WORD_COUNT = 2;
const MIN_ACCOUNT_AGE_DAYS = 7;
const MIN_POST_SCORE = 10;
const TOP_POSTS_STORED = 20; // stocke top 20, récompense top 3

// ─── Helpers ─────────────────────────────────────────────────────────────────

/** Normalise un message pour comparer les copie-collés : minuscules + espaces unifiés. */
function normalizeMessage(msg: string): string {
  return msg.trim().toLowerCase().replace(/\s+/g, " ");
}

/**
 * Calcule le score de qualité d'un commentaire (0 = inéligible).
 *
 * Score = poids_longueur × multiplicateur_diversité × bonus_instructif
 *
 * Poids longueur :
 *   10-19 car → 0.5   (pris en compte mais peu valorisé)
 *   20-49 car → 1.0
 *   50-99 car → 1.5
 *   100+  car → 2.0
 *
 * Multiplicateur diversité (mots uniques / total mots) :
 *   ratio ≥ 0.8 ET ≥ 4 mots uniques → ×1.3  (très varié)
 *   ratio ≥ 0.6                      → ×1.0
 *   ratio < 0.6                      → ×0.7  (mots répétés)
 *
 * Bonus instructif (heuristiques NLP légères) :
 *   +0.15 si contient ? ou ! (commentaire engagé)
 *   +0.15 si au moins 1 mot ≥ 6 lettres (vocabulaire riche)
 *   ×0.5  si >50% emojis (commentaire quasi-uniquement emoji)
 */
function scoreComment(message: string): number {
  const trimmed = message.trim();
  const len = trimmed.length;

  // Exclusion absolue
  if (len < MIN_COMMENT_LENGTH) return 0;

  const words = trimmed.split(/\s+/).filter((w) => w.length > 0);
  if (words.length < MIN_WORD_COUNT) return 0;

  // ── Poids longueur ──
  let weight: number;
  if (len < 20) weight = 0.5;
  else if (len < 50) weight = 1.0;
  else if (len < 100) weight = 1.5;
  else weight = 2.0;

  // ── Multiplicateur diversité de mots ──
  const uniqueWords = new Set(words.map((w) => w.toLowerCase()));
  const diversityRatio = uniqueWords.size / words.length;
  let diversityMult: number;
  if (diversityRatio >= 0.8 && uniqueWords.size >= 4) diversityMult = 1.3;
  else if (diversityRatio >= 0.6) diversityMult = 1.0;
  else diversityMult = 0.7;

  // ── Bonus instructif ──
  let bonus = 0;
  if (/[?!]/.test(trimmed)) bonus += 0.15;
  if (words.some((w) => w.replace(/[^a-zA-ZÀ-ÿ]/g, "").length >= 6)) bonus += 0.15;

  // ── Pénalité emoji dominant ──
  // Compter les caractères emoji (codepoints > U+1F000 ou blocs emoji standard)
  const emojiCount = [...trimmed].filter((c) => {
    const cp = c.codePointAt(0) ?? 0;
    return cp > 0x1F000 || (cp >= 0x2600 && cp <= 0x27BF);
  }).length;
  const emojiRatio = emojiCount / [...trimmed].length;
  const emojiPenalty = emojiRatio > 0.5 ? 0.5 : 1.0;

  return weight * diversityMult * (1 + bonus) * emojiPenalty;
}

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
  const txSoldeRef = db.collection("TransactionSoldes").doc();
  const now = Date.now();

  const rankLabel = rank === 1 ? "🥇 1er" : rank === 2 ? "🥈 2e" : rank === 3 ? "🥉 3e" : `${rank}e`;
  const subLabel = subType === "top_commentator" ? "commentateur" : "créateur";
  const description = `Récompense ${rankLabel} meilleur ${subLabel} — semaine ${weekId}`;

  await db.runTransaction(async (tx) => {
    tx.update(userRef, { giftCoinsBalance: FieldValue.increment(coins) });
    tx.set(txSoldeRef, {
      id: txSoldeRef.id,
      user_id: userId,
      type: "GAIN_PIECES",
      statut: "VALIDER",
      description,
      montant: coins,
      frais: 0,
      montant_total: coins,
      methode_paiement: "classement_semaine",
      createdAt: now,
      updatedAt: now,
      weekId,
      rank,
      subType,
      ...(postId ? { postId } : {}),
    });
  });
}

/** Envoie une notification push + in-app au gagnant d'une récompense hebdo. */
async function sendWeeklyRewardNotification(params: {
  userId: string;
  coins: number;
  rank: number;
  weekId: string;
  subType: "top_commentator" | "top_post";
}): Promise<void> {
  const { userId, coins, rank, weekId, subType } = params;

  try {
    const appConfigDoc = await db.collection("AppData").doc("XgkSxKc10vWsJJ2uBraT").get();
    const appConfig = appConfigDoc.data();
    if (!appConfig?.one_signal_app_id || !appConfig?.one_signal_api_key) {
      console.warn("[weeklyReward] Clés OneSignal manquantes — push ignoré");
      return;
    }

    const userDoc = await db.collection("Users").doc(userId).get();
    const userData = userDoc.data();
    if (!userData) return;

    const rankEmoji = rank === 1 ? "🥇" : rank === 2 ? "🥈" : rank === 3 ? "🥉" : `${rank}e`;
    const subLabel = subType === "top_commentator" ? "commentateur" : "créateur";
    const nowMicros = Date.now() * 1000;
    const pushMessage = `${rankEmoji} Tu es ${rank}${rank === 1 ? "er" : "e"} meilleur ${subLabel} de la semaine ${weekId} ! Tu remportes +${coins} 🪙`;

    // Notification in-app (Firestore)
    const notifRef = db.collection("Notifications").doc();
    await notifRef.set({
      id: notifRef.id,
      titre: `${rankEmoji} Récompense hebdomadaire`,
      description: pushMessage,
      type: "WEEKLY_REWARD",
      user_id: "afrolook_system",
      receiver_id: userId,
      post_id: "",
      post_data_type: "",
      is_open: false,
      users_id_view: [],
      created_at: nowMicros,
      updated_at: nowMicros,
      createdAt: nowMicros,
      updatedAt: nowMicros,
      status: "VALIDE",
      canal_id: null,
      weekId,
      rank,
      coins,
      subType,
    });

    // Notification push OneSignal
    const oneSignalId: string = userData.oneIgnalUserid ?? "";
    if (oneSignalId && oneSignalId.length > 5) {
      await sendToOneSignal(
        [oneSignalId],
        pushMessage,
        "Afrolook",
        appConfig.app_logo ?? "",
        appConfig.one_signal_app_id,
        appConfig.one_signal_api_key,
        {
          type_notif: "WEEKLY_REWARD",
          rank,
          coins,
          weekId,
          subType,
        }
      );
    }
  } catch (err) {
    console.error(`[weeklyReward] Erreur notification user ${userId}:`, err);
  }
}

// ─── 1. TOP COMMENTATEURS ────────────────────────────────────────────────────

/**
 * Logique principale : calcule les 5 meilleurs commentateurs de la semaine
 * identifiée par weekId et leur envoie des pièces + notifications.
 * Si force=true, supprime le verrou avant d'acquérir un nouveau (utile pour admin).
 */
/**
 * @param rankingOnly — si true : recalcule et stocke tous les scores SANS créditer de pièces ni notifier.
 *                      Utilisé pour mettre à jour le classement complet après coup.
 */
async function runCommentatorsReward(
  weekId: string,
  force = false,
  rankingOnly = false,
): Promise<{ rankings: object[]; note?: string }> {
  if (force) {
    const lockId = `${weekId}_commentators`;
    try { await db.collection("WeeklyRewardLocks").doc(lockId).delete(); } catch (_) {}
  }

  const locked = await acquireLock(weekId, "commentators");
  if (!locked) {
    console.log(`[weeklyCommentators] Déjà traité pour ${weekId}.`);
    return { rankings: [], note: "already_processed" };
  }

  const lastWeekStartMicros = getLastWeekStartMicros();
  const thisWeekStartMicros = getWeekStartMicros();
  const minAccountDate = new Date(Date.now() - MIN_ACCOUNT_AGE_DAYS * 86400000);

  // scoreMap : userId → score pondéré total (float)
  // usedMessagesMap : userId → Set<message normalisé> (anti copie-collé global)
  // postCommentsMap : userId → Set<postId> (anti spam même post)
  const scoreMap = new Map<string, number>();
  const usedMessagesMap = new Map<string, Set<string>>();
  const postCommentsMap = new Map<string, Set<string>>(); // userId → Set<postId déjà commenté avec ce texte>
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
      const userId: string = data.user_id ?? "";
      const postId: string = data.post_id ?? "";
      const message: string = data.message ?? "";
      if (!userId || !postId) continue;

      // ── Score de qualité (0 = inéligible) ──
      const quality = scoreComment(message);
      if (quality === 0) continue;

      // ── Anti copie-collé global : même texte déjà utilisé cette semaine par cet user ──
      const normalized = normalizeMessage(message);
      if (!usedMessagesMap.has(userId)) usedMessagesMap.set(userId, new Set());
      const userMessages = usedMessagesMap.get(userId)!;
      if (userMessages.has(normalized)) continue;
      userMessages.add(normalized);

      // ── Anti spam même post : ne compter qu'une fois par post ──
      if (!postCommentsMap.has(userId)) postCommentsMap.set(userId, new Set());
      const userPosts = postCommentsMap.get(userId)!;
      if (userPosts.has(postId)) continue;
      userPosts.add(postId);

      // ── Accumuler le score ──
      scoreMap.set(userId, (scoreMap.get(userId) ?? 0) + quality);
    }

    fetched += snap.size;
    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.size < 500) break;
  }

  console.log(`[weeklyCommentators] ${fetched} commentaires analysés, ${scoreMap.size} utilisateurs avec score > 0.`);

  if (scoreMap.size === 0) {
    await db.collection("WeeklyTopCommentators").doc(weekId).set({
      weekId, computedAt: FieldValue.serverTimestamp(), rankings: [], note: "no_eligible_comments",
    });
    return { rankings: [], note: "no_eligible_comments" };
  }

  const userIds = Array.from(scoreMap.keys());
  const eligibleScores: Array<{ userId: string; score: number; commentCount: number }> = [];

  for (let i = 0; i < userIds.length; i += 30) {
    const chunk = userIds.slice(i, i + 30);
    const usersSnap = await db.collection("Users").where("__name__", "in", chunk).select("createdAt", "id").get();
    for (const userDoc of usersSnap.docs) {
      const createdAt: number = userDoc.data().createdAt ?? 0;
      const accountDate = new Date(createdAt / 1000);
      if (accountDate > minAccountDate) continue;
      const score = scoreMap.get(userDoc.id) ?? 0;
      if (score > 0) {
        const commentCount = postCommentsMap.get(userDoc.id)?.size ?? 0;
        eligibleScores.push({ userId: userDoc.id, score, commentCount });
      }
    }
  }

  // Tri par nombre de posts distincts commentés (critère principal), score qualité (départage)
  eligibleScores.sort((a, b) => b.commentCount - a.commentCount || b.score - a.score);
  const top5 = eligibleScores.slice(0, 5);

  if (top5.length === 0) {
    await db.collection("WeeklyTopCommentators").doc(weekId).set({
      weekId, computedAt: FieldValue.serverTimestamp(), rankings: [], note: "no_eligible_users",
    });
    return { rankings: [], note: "no_eligible_users" };
  }

  const rankings: object[] = [];

  if (rankingOnly) {
    // Mode "classement uniquement" : récupérer qui a déjà été payé depuis le doc existant
    const existingDoc = await db.collection("WeeklyTopCommentators").doc(weekId).get();
    const existingRankings: Array<{ userId: string; paid: boolean; rewardedCoins: number }> =
      (existingDoc.data()?.rankings ?? []) as Array<{ userId: string; paid: boolean; rewardedCoins: number }>;
    const paidMap = new Map(existingRankings.map((r) => [r.userId, { paid: r.paid, coins: r.rewardedCoins }]));

    for (let i = 0; i < eligibleScores.length; i++) {
      const { userId, score, commentCount } = eligibleScores[i];
      const rank = i + 1;
      const existing = paidMap.get(userId);
      const coins = rank <= 5 ? (COMMENTATOR_REWARDS[rank - 1] ?? 0) : 0;
      rankings.push({
        rank,
        userId,
        commentCount,
        qualityScore: Math.round(score * 100) / 100,
        rewardedCoins: existing?.coins ?? coins,
        paid: existing?.paid ?? false,
      });
    }
    console.log(`[weeklyCommentators] Mode classement uniquement — ${rankings.length} entrées.`);
  } else {
    // Mode normal : récompenser le top 5
    for (let i = 0; i < top5.length; i++) {
      const { userId, score, commentCount } = top5[i];
      const coins = COMMENTATOR_REWARDS[i] ?? 0;
      const rank = i + 1;
      try {
        await rewardUser({ userId, coins, rank, weekId, subType: "top_commentator" });
        await sendWeeklyRewardNotification({ userId, coins, rank, weekId, subType: "top_commentator" });
        rankings.push({ rank, userId, commentCount, qualityScore: Math.round(score * 100) / 100, rewardedCoins: coins, paid: true });
        console.log(`[weeklyCommentators] Rang ${rank} — user ${userId} — ${commentCount} posts — score ${score.toFixed(2)} — ${coins} pièces`);
      } catch (err) {
        console.error(`[weeklyCommentators] Erreur rang ${rank}:`, err);
        rankings.push({ rank, userId, commentCount, qualityScore: Math.round(score * 100) / 100, rewardedCoins: coins, paid: false, error: String(err) });
      }
    }

    // Ajouter les autres utilisateurs éligibles (sans récompense)
    for (let i = 5; i < eligibleScores.length; i++) {
      const { userId, score, commentCount } = eligibleScores[i];
      rankings.push({ rank: i + 1, userId, commentCount, qualityScore: Math.round(score * 100) / 100, rewardedCoins: 0, paid: false });
    }
  }

  await db.collection("WeeklyTopCommentators").doc(weekId).set({
    weekId, computedAt: FieldValue.serverTimestamp(), rankings, totalEligible: eligibleScores.length,
  });

  console.log(`[weeklyCommentators] Terminé. ${rankings.length} gagnant(s).`);
  return { rankings };
}

/**
 * Chaque lundi à 00:05 UTC : calcule les 5 meilleurs commentateurs de la
 * semaine écoulée et leur envoie des pièces.
 */
export const weeklyTopCommentatorsReward = onSchedule(
  { schedule: "5 0 * * MON", timeZone: "UTC", memory: "512MiB", cpu: 1, timeoutSeconds: 300 },
  async () => {
    const weekId = getLastWeekId();
    console.log(`[weeklyCommentators] Semaine récompensée : ${weekId}`);
    await runCommentatorsReward(weekId, false);
  }
);

/**
 * Callable admin : force le recalcul du classement commentateurs pour la semaine précédente.
 * - Si "confirm: true" n'est pas dans les données → vérifie juste le statut (déjà fait ou non).
 * - Si "confirm: true" → supprime le verrou et relance.
 */
export const forceWeeklyCommentatorsReward = onCall(
  { memory: "512MiB", cpu: 1, timeoutSeconds: 300, region: "us-central1" },
  async (request) => {
    if (!request.auth) throw new HttpsError("unauthenticated", "Non authentifié");

    const callerDoc = await db.collection("Users").doc(request.auth.uid).get();
    const role = callerDoc.data()?.role ?? "";
    if (role !== "ADM" && role !== "admin") throw new HttpsError("permission-denied", "Accès réservé aux admins");

    const weekId = getLastWeekId();
    const confirmed: boolean = request.data?.confirm === true;

    // Vérifier si le classement a déjà été calculé
    const lockId = `${weekId}_commentators`;
    const lockSnap = await db.collection("WeeklyRewardLocks").doc(lockId).get();
    const alreadyDone = lockSnap.exists;

    if (alreadyDone && !confirmed) {
      // Retourner le statut existant sans relancer
      const existingDoc = await db.collection("WeeklyTopCommentators").doc(weekId).get();
      const existingData = existingDoc.data() ?? {};
      const existingRankings = existingData.rankings ?? [];
      const processedAt = lockSnap.data()?.processedAt?.toMillis?.() ?? null;
      return {
        weekId,
        alreadyProcessed: true,
        rankings: existingRankings,
        rankingsCount: existingRankings.length,
        processedAt,
        note: "already_processed",
      };
    }

    // rankingOnly = true → recalcule sans re-créditer les pièces
    const rankingOnly: boolean = request.data?.rankingOnly === true;
    console.log(`[forceCommentators] Déclenchement admin — semaine ${weekId} — rankingOnly=${rankingOnly}`);
    const result = await runCommentatorsReward(weekId, true, rankingOnly);
    return {
      weekId,
      alreadyProcessed: false,
      rankings: result.rankings,
      rankingsCount: (result.rankings as object[]).length,
      note: result.note,
    };
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
        await sendWeeklyRewardNotification({
          userId: p.authorId,
          coins,
          rank: i + 1,
          weekId,
          subType: "top_post",
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
