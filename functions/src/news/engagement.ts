import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { deliverPush } from "../shared/push";
import { chunk } from "../shared/push_logic";
import { previewFromPost } from "../shared/preview";
import { followerIdPages } from "../follows/followersRead";
import { agentUserId } from "./agents";

/**
 * Notifications d'engagement des articles d'actualité : elles donnent envie d'aller lire un article dont on parle.
 * Destinataires : les abonnés de l'agent et les personnes qui ont déjà aimé ou commenté l'article (jamais l'auteur du geste).
 * Jamais systématiques :
 *  - palier de vues, de j'aime ou de commentaires (une seule fois par palier) ;
 *  - un commentaire (écrit en clair) : au plus 1 toutes les 30 minutes et 2 par jour et par article, seulement s'il est assez long ;
 *  - un j'aime : seulement d'une personne qui a au moins 20 abonnés, au plus 1 par heure et 2 par jour et par article ;
 *  - au plus 4 notifications d'engagement par jour et par agent, toutes sortes confondues.
 * Envoi en catégorie « sociale » : heures calmes, préférences et budget quotidien de chaque personne s'appliquent. Push seulement :
 * rien n'est enregistré dans la liste des notifications. L'état des plafonds est dans NewsPushState/{article}, jamais dans le post.
 */
export const VIEW_MILESTONES = [100, 500, 1000, 5000, 10000, 50000, 100000];
export const LOVE_MILESTONES = [10, 50, 100, 500, 1000, 5000];
export const COMMENT_MILESTONES = [5, 10, 50, 100, 500];
export type MilestoneKind = "views" | "loves" | "comments";
const TABLE: Record<MilestoneKind, number[]> = { views: VIEW_MILESTONES, loves: LOVE_MILESTONES, comments: COMMENT_MILESTONES };

const MIN_COMMENT_CHARS = 20;
const MIN_LIKER_FOLLOWERS = 20;
const COMMENT_GAP_MS = 30 * 60 * 1000;
const LIKE_GAP_MS = 60 * 60 * 1000;
const PER_ARTICLE_DAILY = 2;
const PER_AGENT_DAILY = 4;
const MAX_FOLLOWERS_READ = 1500; // lectures plafonnées : chaque destinataire coûte une lecture de profil
const MAX_RECIPIENTS = 2000;

const cut = (s: unknown, n: number): string => {
  const t = Array.from(String(s ?? "").replace(/\s+/g, " ").trim());
  return t.length <= n ? t.join("") : t.slice(0, n - 1).join("") + "…";
};
const fmt = (n: number): string => n.toLocaleString("fr-FR").replace(/ | /g, " ");

/** Plus haut palier franchi entre deux valeurs et pas encore annoncé, sinon null. */
export function newMilestone(kind: MilestoneKind, before: number, after: number, done: string[]): number | null {
  let hit: number | null = null;
  for (const t of TABLE[kind]) if (before < t && after >= t && !done.includes(`${kind}_${t}`)) hit = t;
  return hit;
}

export function milestoneMessage(kind: MilestoneKind, threshold: number, title: string): { title: string; body: string } {
  const t = cut(title, 48);
  if (kind === "views") return { title: `🔥 ${fmt(threshold)} vues pour « ${t} »`, body: "Tout le monde en parle : ouvre le résumé et donne ton avis." };
  if (kind === "loves") return { title: `❤️ ${fmt(threshold)} personnes ont aimé « ${t} »`, body: "Viens voir ce qui plaît et réagis." };
  return { title: `💬 ${fmt(threshold)} commentaires sur « ${t} »`, body: "La discussion est lancée : lis le résumé et rejoins-la." };
}

export const commentMessage = (pseudo: string, articleTitle: string, comment: string) =>
  ({ title: `💬 @${cut(pseudo, 24)} sur « ${cut(articleTitle, 36)} »`, body: cut(comment, 110) });
export const likeMessage = (pseudo: string, articleTitle: string) =>
  ({ title: `❤️ @${cut(pseudo, 24)} a aimé`, body: `« ${cut(articleTitle, 90)} »` });

export interface PushState { milestones?: string[]; commentAt?: number; commentDay?: string; commentN?: number; likeAt?: number; likeDay?: string; likeN?: number }

const dayOf = (ms: number) => new Date(ms).toISOString().slice(0, 10);

/** Un commentaire mérite-t-il une notification (assez long, hors cadeau automatique, hors plafonds de l'article) ? */
export function shouldPushComment(text: string, auto: boolean, s: PushState | undefined, nowMs: number): boolean {
  if (auto || Array.from(text.trim()).length < MIN_COMMENT_CHARS) return false;
  if (nowMs - (s?.commentAt ?? 0) < COMMENT_GAP_MS) return false;
  return !(s?.commentDay === dayOf(nowMs) && (s?.commentN ?? 0) >= PER_ARTICLE_DAILY);
}

/** Un j'aime mérite-t-il une notification (personne suivie par au moins 20 abonnés, hors plafonds de l'article) ? */
export function shouldPushLike(likerFollowers: number, s: PushState | undefined, nowMs: number): boolean {
  if (likerFollowers < MIN_LIKER_FOLLOWERS) return false;
  if (nowMs - (s?.likeAt ?? 0) < LIKE_GAP_MS) return false;
  return !(s?.likeDay === dayOf(nowMs) && (s?.likeN ?? 0) >= PER_ARTICLE_DAILY);
}

/** Réserve une place dans le plafond du jour de l'agent (4 notifications d'engagement). */
async function takeAgentSlot(agentKey: string, nowMs: number): Promise<boolean> {
  const ref = db.collection("NewsPushDaily").doc(dayOf(nowMs));
  return db.runTransaction(async (tx) => {
    const cur = Number(((await tx.get(ref)).data()?.["counts"] as Record<string, number> | undefined)?.[agentKey] ?? 0);
    if (cur >= PER_AGENT_DAILY) return false;
    tx.set(ref, { counts: { [agentKey]: FieldValue.increment(1) }, updatedAt: nowMs }, { merge: true });
    return true;
  });
}

async function recipientsFor(agentId: string, post: Record<string, unknown>, actorId?: string): Promise<string[]> {
  const set = new Set<string>();
  for (const k of ["users_comments_id", "users_love_id"]) for (const id of (post[k] as string[] | undefined) ?? []) set.add(id);
  let read = 0;
  for await (const page of followerIdPages(agentId, 500)) {
    for (const id of page) set.add(id);
    read += page.length;
    if (read >= MAX_FOLLOWERS_READ) break;
  }
  set.delete(agentId);
  if (actorId) set.delete(actorId);
  return [...set].filter(Boolean).slice(0, MAX_RECIPIENTS);
}

async function send(postId: string, post: Record<string, unknown>, agentId: string, msg: { title: string; body: string }, actorId?: string): Promise<number> {
  const ids = await recipientsFor(agentId, post, actorId);
  if (!ids.length) return 0;
  const payload = {
    title: msg.title, message: msg.body, image: previewFromPost(post) || undefined,
    data: { type_notif: "NEWS", post_id: postId, post_type: "NEWS", send_user_id: agentId, chat_id: "" },
  };
  for (const group of chunk(ids, 500)) await deliverPush(group.map((userId) => ({ userId })), payload, undefined, false, "social");
  return ids.length;
}

/**
 * Appelé à chaque modification d'un article (depuis le déclencheur de score des posts) : annonce un palier de vues, de j'aime ou de
 * commentaires, et signale un j'aime d'une personne suivie. Sans changement utile, ne lit ni n'écrit rien.
 */
export async function onNewsPostChanged(postId: string, before: Record<string, unknown>, after: Record<string, unknown>): Promise<void> {
  const num = (o: Record<string, unknown>, k: string) => Number(o[k] ?? 0) || 0;
  const all: Array<{ kind: MilestoneKind; from: number; to: number }> = [
    { kind: "views", from: num(before, "vues"), to: num(after, "vues") },
    { kind: "loves", from: num(before, "loves"), to: num(after, "loves") },
    { kind: "comments", from: num(before, "comments"), to: num(after, "comments") },
  ];
  const hits = all.filter((h) => h.to > h.from);
  const newLikers = ((after["users_love_id"] as string[] | undefined) ?? []).filter((u) => !((before["users_love_id"] as string[] | undefined) ?? []).includes(u));
  // les compteurs de vues bougent très souvent : on ne lit l'état que si un palier est franchi ou si quelqu'un vient d'aimer
  const crossed = hits.filter((h) => TABLE[h.kind].some((t) => h.from < t && h.to >= t));
  if (!crossed.length && !newLikers.length) return;

  const now = Date.now();
  const agentKey = String((after["news"] as Record<string, unknown> | undefined)?.["agentKey"] ?? "");
  if (!agentKey) return;
  const agentId = agentUserId(agentKey);
  const title = String((after["news"] as Record<string, unknown> | undefined)?.["title"] ?? "");
  const stateRef = db.collection("NewsPushState").doc(postId);
  const state = ((await stateRef.get()).data() ?? {}) as PushState;
  const patch: Record<string, unknown> = {};

  for (const h of crossed) {
    const m = newMilestone(h.kind, h.from, h.to, state.milestones ?? []);
    if (m == null) continue;
    // le palier est consommé même si le plafond du jour empêche l'envoi : on n'annonce pas un vieux palier le lendemain
    patch["milestones"] = FieldValue.arrayUnion(`${h.kind}_${m}`);
    if (await takeAgentSlot(agentKey, now)) await send(postId, after, agentId, milestoneMessage(h.kind, m, title));
    break; // un seul message de palier à la fois
  }

  if (newLikers.length) {
    const liker = (await db.collection("Users").doc(newLikers[0]).get()).data();
    if (liker && shouldPushLike(Number(liker["abonnes"] ?? 0), state, now) && (await takeAgentSlot(agentKey, now))) {
      await send(postId, after, agentId, likeMessage(String(liker["pseudo"] ?? "Quelqu'un"), title), newLikers[0]);
      patch["likeAt"] = now;
      patch["likeDay"] = dayOf(now);
      patch["likeN"] = state.likeDay === dayOf(now) ? (state.likeN ?? 0) + 1 : 1;
    }
  }
  if (Object.keys(patch).length) await stateRef.set(patch, { merge: true });
}

/** Nouveau commentaire sur un article : notification avec le commentaire en clair, selon les plafonds. */
export const onNewsCommentCreated = onDocumentCreated(
  { document: "PostComments/{commentId}", timeoutSeconds: 120, memory: "256MiB", maxInstances: 5 },
  async (event) => {
    const c = event.data?.data();
    const postId = String(c?.["post_id"] ?? "");
    // un article a un identifiant « news_… » : tous les autres commentaires de l'application sortent ici, sans lecture
    if (!c || !postId.startsWith("news_")) return;
    try {
      const post = (await db.collection("Posts").doc(postId).get()).data();
      if (!post || post["type"] !== "NEWS") return;
      const agentKey = String((post["news"] as Record<string, unknown> | undefined)?.["agentKey"] ?? "");
      if (!agentKey) return;
      const now = Date.now();
      const stateRef = db.collection("NewsPushState").doc(postId);
      const state = ((await stateRef.get()).data() ?? {}) as PushState;
      const text = String(c["message"] ?? "");
      if (!shouldPushComment(text, c["isAutoGiftComment"] === true, state, now)) return;
      if (!(await takeAgentSlot(agentKey, now))) return;
      const author = (await db.collection("Users").doc(String(c["user_id"] ?? "")).get()).data();
      const title = String((post["news"] as Record<string, unknown>)["title"] ?? "");
      await send(postId, post, agentUserId(agentKey), commentMessage(String(author?.["pseudo"] ?? "Quelqu'un"), title, text), String(c["user_id"] ?? ""));
      await stateRef.set({
        commentAt: now, commentDay: dayOf(now), commentN: state.commentDay === dayOf(now) ? (state.commentN ?? 0) + 1 : 1,
      }, { merge: true });
    } catch (e) {
      console.error("[actualités] notification de commentaire non envoyée", e);
    }
  },
);
