import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { FieldValue } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { db } from "../shared/firebase";
import { num } from "../payments/coinShares";

/**
 * Stickers et médias dans les commentaires (voir docs/STICKERS_SPEC.md).
 *
 * Le serveur décide de tout : abonnement, limites par post et par jour, poids, droit d'usage d'un pack,
 * solde pour un sticker-cadeau. L'application ne fait que pré-vérifier (callable `stickerAccess`) et afficher.
 * Un commentaire qui ne respecte pas les règles est supprimé par `onCommentMediaCreated`.
 */

export type Tier = "free" | "premium" | "gold";
const LIMITS: Record<Tier, { perPost: number; perDay: number }> = {
  free: { perPost: 0, perDay: 0 },
  premium: { perPost: 1, perDay: 10 },
  gold: { perPost: 3, perDay: 50 },
};
export const MAX_IMAGE_BYTES = 300 * 1024;
export const MAX_ANIM_BYTES = 600 * 1024;
const MAX_RECENTS = 12;

/** Niveau d'abonnement d'un compte (admin = gold, abonnement expiré = gratuit). */
export function tierOf(u: FirebaseFirestore.DocumentData | undefined): Tier {
  if (!u) return "free";
  if (u["role"] === "ADM") return "gold";
  const a = u["abonnement"] as { type?: string; dateFin?: string; estActif?: boolean } | undefined;
  if (!a || (a.type !== "premium" && a.type !== "gold")) return "free";
  if (a.estActif === false) return "free";
  const end = a.dateFin ? Date.parse(a.dateFin) : NaN;
  if (Number.isFinite(end) && end < Date.now()) return "free";
  return a.type === "gold" ? "gold" : "premium";
}

/** Limites du compte : l'admin (role ADM) est illimité, les autres suivent leur abonnement. */
function limitsOf(u: FirebaseFirestore.DocumentData | undefined, tier: Tier): { perPost: number; perDay: number; unlimited: boolean } {
  if (u?.["role"] === "ADM") return { perPost: Number.MAX_SAFE_INTEGER, perDay: Number.MAX_SAFE_INTEGER, unlimited: true };
  return { ...LIMITS[tier], unlimited: false };
}

function isSuspended(u: FirebaseFirestore.DocumentData | undefined): boolean {
  if (!u) return false;
  if (u["suspendedPermanently"] === true) return true;
  const until = num(u["suspendedUntil"]);
  return until > 0 && until > Date.now();
}

/** Stickers offerts du jour (récompense « pubs ») : Users.stickerBonus = {day, remaining}. */
function bonusRemaining(u: FirebaseFirestore.DocumentData | undefined): number {
  const b = u?.["stickerBonus"] as { day?: string; remaining?: number } | undefined;
  return b && b.day === dayKey() ? Math.max(0, num(b.remaining)) : 0;
}

/** Consomme un sticker offert (transaction) ; faux s'il n'en reste plus. */
async function takeBonus(uid: string): Promise<boolean> {
  const ref = db.collection("Users").doc(uid);
  return db.runTransaction(async (tx) => {
    const left = bonusRemaining((await tx.get(ref)).data());
    if (left <= 0) return false;
    tx.update(ref, { "stickerBonus.remaining": left - 1 });
    return true;
  });
}

function dayKey(): string {
  return new Date().toISOString().slice(0, 10).replace(/-/g, "");
}

async function dayUsed(uid: string): Promise<number> {
  const d = await db.collection("StickerUsage").doc(`${uid}_${dayKey()}`).get();
  return num(d.data()?.["count"]);
}

/** Nombre de commentaires avec média déjà postés par cet utilisateur sur ce post (hors commentaire donné). */
async function postUsed(uid: string, postId: string, excludeId?: string): Promise<number> {
  const snap = await db.collection("PostComments").where("post_id", "==", postId).where("user_id", "==", uid).limit(60).get();
  return snap.docs.filter((d) => d.id !== excludeId && d.get("media") != null).length;
}

type Reason = null | "not_subscribed" | "suspended" | "day_limit" | "post_limit" | "not_owned" | "inactive" | "removed" | "no_coins";

/** Le sticker est-il utilisable par cet utilisateur ? (existence, statut, pack acheté, solde du sticker-cadeau) */
async function stickerUsable(uid: string, source: string, stickerId: string, balance: number): Promise<{ ok: boolean; reason: Reason; data?: FirebaseFirestore.DocumentData }> {
  if (source === "mine") {
    const d = await db.collection("UserStickers").doc(stickerId).get();
    if (!d.exists) return { ok: false, reason: "removed" };
    if (d.get("ownerId") !== uid) return { ok: false, reason: "not_owned" };
    if (d.get("status") && d.get("status") !== "active") return { ok: false, reason: "inactive" };
    return { ok: true, reason: null, data: d.data() };
  }
  const d = await db.collection("Stickers").doc(stickerId).get();
  if (!d.exists) return { ok: false, reason: "removed" };
  const s = d.data()!;
  if (s["status"] !== "active") return { ok: false, reason: "inactive" };
  const pack = await db.collection("StickerPacks").doc(String(s["packId"] ?? "")).get();
  if (!pack.exists || pack.get("status") !== "active") return { ok: false, reason: "inactive" };
  const price = num(pack.get("priceCoins"));
  if (price > 0 && s["creatorId"] !== uid && pack.get("creatorId") !== uid) {
    const own = await db.collection("StickerOwnership").doc(`${uid}_${pack.id}`).get();
    if (!own.exists) return { ok: false, reason: "not_owned" };
  }
  const gift = num(s["giftPriceCoins"]);
  if (gift > 0 && balance < gift) return { ok: false, reason: "no_coins", data: s };
  return { ok: true, reason: null, data: s };
}

/** Pré-vérification pour l'application : limites du jour et du post, et état de chaque sticker récent. */
export const stickerAccess = onCall({ timeoutSeconds: 20, memory: "256MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const postId = (request.data as { postId?: string })?.postId;
  const userDoc = await db.collection("Users").doc(uid).get();
  const u = userDoc.data();
  const tier = tierOf(u);
  const lim = limitsOf(u, tier);
  const [used, onPost] = await Promise.all([dayUsed(uid), postId ? postUsed(uid, postId) : Promise.resolve(0)]);

  const bonus = bonusRemaining(u);
  let reason: Reason = null;
  if (tier === "free" && bonus <= 0) reason = "not_subscribed";
  else if (isSuspended(u)) reason = "suspended";
  else if (tier !== "free" && used >= lim.perDay) reason = "day_limit";
  else if (postId && onPost >= (tier === "free" ? 1 : lim.perPost)) reason = "post_limit";
  const canSend = reason === null;

  const balance = num(u?.["giftCoinsBalance"]);
  const recSnap = await db.collection("Users").doc(uid).collection("StickerRecents").orderBy("lastUsedAt", "desc").limit(MAX_RECENTS).get();
  const recents = await Promise.all(recSnap.docs.map(async (r) => {
    const source = String(r.get("source") ?? "pack");
    const st = await stickerUsable(uid, source, r.id, balance);
    const why: Reason = canSend ? st.reason : (reason ?? st.reason);
    return { stickerId: r.id, source, usable: canSend && st.ok, reason: why, lastUsedAt: num(r.get("lastUsedAt")) };
  }));

  return { tier, canSend, reason, bonusRemaining: bonus, perPostMax: lim.unlimited ? 0 : lim.perPost, perDayMax: lim.unlimited ? 0 : lim.perDay, unlimited: lim.unlimited, dayUsed: used, postUsed: onPost, recents };
});

async function rejectComment(ref: FirebaseFirestore.DocumentReference, why: string, uid: string | undefined) {
  console.log(`[stickers] commentaire ${ref.id} refusé (${why}) pour ${uid}`);
  await ref.delete();
  if (uid) {
    await db.collection("StickerRejections").add({ commentId: ref.id, userId: uid, reason: why, at: Date.now() });
  }
}

/** Vérifie chaque commentaire qui porte un média ; supprime celui qui ne respecte pas les règles. */
export const onCommentMediaCreated = onDocumentCreated("PostComments/{id}", async (event) => {
  const snap = event.data;
  if (!snap) return;
  const media = snap.get("media") as Record<string, unknown> | undefined;
  if (!media) return;
  const uid = snap.get("user_id") as string | undefined;
  const postId = snap.get("post_id") as string | undefined;
  if (!uid || !postId) return rejectComment(snap.ref, "données manquantes", uid);

  const userDoc = await db.collection("Users").doc(uid).get();
  const u = userDoc.data();
  const tier = tierOf(u);
  const freeWithBonus = tier === "free" && bonusRemaining(u) > 0;
  if (tier === "free" && !freeWithBonus) return rejectComment(snap.ref, "abonnement", uid);
  if (isSuspended(u)) return rejectComment(snap.ref, "compte suspendu", uid);
  const lim = freeWithBonus ? { perPost: 1, perDay: Number.MAX_SAFE_INTEGER, unlimited: false } : limitsOf(u, tier);

  const type = String(media["type"] ?? "");
  const balance = num(u?.["giftCoinsBalance"]);
  let recentId: string | null = null;
  let recentSource = "pack";
  let trusted: Record<string, unknown> | null = null;

  if (type === "sticker" || type === "user_sticker") {
    const stickerId = String(media["stickerId"] ?? "");
    if (!stickerId) return rejectComment(snap.ref, "sticker manquant", uid);
    const st = await stickerUsable(uid, type === "user_sticker" ? "mine" : "pack", stickerId, balance);
    if (!st.ok || !st.data) return rejectComment(snap.ref, st.reason ?? "sticker", uid);
    // Un sticker-cadeau (prix > 0) ne passe pas par ce chemin : il est envoyé et débité par stickerGiftSend
    if (num(st.data["giftPriceCoins"]) > 0) return rejectComment(snap.ref, "sticker-cadeau", uid);
    const size = num(st.data["sizeBytes"]);
    if (size > MAX_ANIM_BYTES) return rejectComment(snap.ref, "poids", uid);
    // Les champs du média sont recopiés depuis le sticker : l'app ne peut pas les falsifier
    trusted = {
      type, stickerId, url: st.data["url"], thumbUrl: st.data["thumbUrl"] ?? null,
      w: num(media["w"]) || 512, h: num(media["h"]) || 512, sizeBytes: size, animated: st.data["animated"] === true,
    };
    recentId = stickerId;
    recentSource = type === "user_sticker" ? "mine" : "pack";
  } else if (type === "image") {
    const path = String(media["storagePath"] ?? "");
    if (!path.startsWith(`comment_media/${uid}/`)) return rejectComment(snap.ref, "chemin", uid);
    try {
      const file = getStorage().bucket().file(path);
      const [meta] = await file.getMetadata();
      const size = Number(meta.size ?? 0);
      const limit = media["animated"] === true ? MAX_ANIM_BYTES : MAX_IMAGE_BYTES;
      if (!size || size > limit) {
        await file.delete({ ignoreNotFound: true });
        return rejectComment(snap.ref, "poids", uid);
      }
      trusted = { ...media, sizeBytes: size };
    } catch {
      return rejectComment(snap.ref, "fichier introuvable", uid);
    }
  } else {
    return rejectComment(snap.ref, "type inconnu", uid);
  }

  // Limites : par post, puis par jour (incrément dans une transaction)
  if ((await postUsed(uid, postId, snap.id)) >= lim.perPost) return rejectComment(snap.ref, "limite par post", uid);
  const usageRef = db.collection("StickerUsage").doc(`${uid}_${dayKey()}`);
  const allowed = await db.runTransaction(async (tx) => {
    const d = await tx.get(usageRef);
    const count = num(d.data()?.["count"]);
    if (count >= lim.perDay) return false;
    tx.set(usageRef, { userId: uid, day: dayKey(), count: count + 1 }, { merge: true });
    return true;
  });
  if (!allowed) return rejectComment(snap.ref, "limite par jour", uid);
  if (freeWithBonus && !(await takeBonus(uid))) return rejectComment(snap.ref, "plus de stickers offerts", uid);

  if (trusted) await snap.ref.update({ media: trusted });

  // Récents : les 12 derniers stickers utilisés (les images de commentaire n'y figurent pas)
  if (recentId) {
    const col = db.collection("Users").doc(uid).collection("StickerRecents");
    await col.doc(recentId).set({ lastUsedAt: Date.now(), source: recentSource });
    const all = await col.orderBy("lastUsedAt", "desc").get();
    await Promise.all(all.docs.slice(MAX_RECENTS).map((d) => d.ref.delete()));
    await db.collection("Stickers").doc(recentId).update({ usageCount: FieldValue.increment(1) }).catch(() => undefined);
  }
});

type Reply = Record<string, unknown>;
const replyKey = (r: Reply) => String(r["id"] || `${r["user_id"]}_${r["created_at"]}`);

/** Retire une réponse refusée du commentaire (transaction : ne touche pas aux autres réponses). */
async function rejectReply(ref: FirebaseFirestore.DocumentReference, key: string, why: string, uid: string | undefined) {
  console.log(`[stickers] réponse ${key} du commentaire ${ref.id} refusée (${why}) pour ${uid}`);
  await db.runTransaction(async (tx) => {
    const d = await tx.get(ref);
    const list = (d.get("responseComments") ?? []) as Reply[];
    tx.update(ref, { responseComments: list.filter((r) => replyKey(r) !== key) });
  });
  if (uid) await db.collection("StickerRejections").add({ commentId: ref.id, replyId: key, userId: uid, reason: why, at: Date.now() });
}

/**
 * Stickers dans les RÉPONSES à un commentaire : les réponses sont stockées dans `responseComments`.
 * Mêmes règles que les commentaires (abonnement, suspension, droit sur le pack, poids, limite du jour),
 * sans limite « par post » (une réponse n'est pas retrouvable par auteur). Réponse refusée = retirée.
 */
export const onReplyMediaUpdated = onDocumentUpdated("PostComments/{id}", async (event) => {
  const before = ((event.data?.before.get("responseComments") ?? []) as Reply[]);
  const after = ((event.data?.after.get("responseComments") ?? []) as Reply[]);
  if (after.length <= before.length) return;
  const known = new Set(before.map(replyKey));
  const fresh = after.filter((r) => r["media"] && !known.has(replyKey(r)));
  if (fresh.length === 0) return;
  const ref = event.data!.after.ref;

  for (const reply of fresh) {
    const key = replyKey(reply);
    const media = reply["media"] as Record<string, unknown>;
    const uid = String(reply["user_id"] ?? "");
    if (!uid) { await rejectReply(ref, key, "données manquantes", undefined); continue; }
    const userDoc = await db.collection("Users").doc(uid).get();
    const u = userDoc.data();
    const tier = tierOf(u);
    const freeWithBonus = tier === "free" && bonusRemaining(u) > 0;
    if (tier === "free" && !freeWithBonus) { await rejectReply(ref, key, "abonnement", uid); continue; }
    if (isSuspended(u)) { await rejectReply(ref, key, "compte suspendu", uid); continue; }
    const lim = freeWithBonus ? { perPost: 1, perDay: Number.MAX_SAFE_INTEGER, unlimited: false } : limitsOf(u, tier);

    const type = String(media["type"] ?? "");
    const stickerId = String(media["stickerId"] ?? "");
    if ((type !== "sticker" && type !== "user_sticker") || !stickerId) { await rejectReply(ref, key, "type", uid); continue; }
    const st = await stickerUsable(uid, type === "user_sticker" ? "mine" : "pack", stickerId, num(u?.["giftCoinsBalance"]));
    if (!st.ok || !st.data) { await rejectReply(ref, key, st.reason ?? "sticker", uid); continue; }
    if (num(st.data["giftPriceCoins"]) > 0) { await rejectReply(ref, key, "sticker-cadeau", uid); continue; }
    const size = num(st.data["sizeBytes"]);
    if (size > MAX_ANIM_BYTES) { await rejectReply(ref, key, "poids", uid); continue; }
    const trusted = {
      type, stickerId, url: st.data["url"], thumbUrl: st.data["thumbUrl"] ?? null,
      w: num(media["w"]) || 512, h: num(media["h"]) || 512, sizeBytes: size, animated: st.data["animated"] === true,
    };

    const usageRef = db.collection("StickerUsage").doc(`${uid}_${dayKey()}`);
    const allowed = await db.runTransaction(async (tx) => {
      const d = await tx.get(usageRef);
      const count = num(d.data()?.["count"]);
      if (count >= lim.perDay) return false;
      tx.set(usageRef, { userId: uid, day: dayKey(), count: count + 1 }, { merge: true });
      return true;
    });
    if (!allowed) { await rejectReply(ref, key, "limite par jour", uid); continue; }
    if (freeWithBonus && !(await takeBonus(uid))) { await rejectReply(ref, key, "plus de stickers offerts", uid); continue; }

    // Média recopié depuis le sticker (l'app ne peut pas le falsifier)
    await db.runTransaction(async (tx) => {
      const d = await tx.get(ref);
      const list = (d.get("responseComments") ?? []) as Reply[];
      tx.update(ref, { responseComments: list.map((r) => (replyKey(r) === key ? { ...r, media: trusted } : r)) });
    });

    const col = db.collection("Users").doc(uid).collection("StickerRecents");
    await col.doc(stickerId).set({ lastUsedAt: Date.now(), source: type === "user_sticker" ? "mine" : "pack" });
    const all = await col.orderBy("lastUsedAt", "desc").get();
    await Promise.all(all.docs.slice(MAX_RECENTS).map((d) => d.ref.delete()));
    await db.collection("Stickers").doc(stickerId).update({ usageCount: FieldValue.increment(1) }).catch(() => undefined);
  }
});
