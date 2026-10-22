import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db } from "../shared/firebase";
import { STUDIO_TRACK_IDS } from "./musicPlaylists";

/**
 * J'aime sur les musiques (sons d'artistes et musiques gratuites d'Afrolook).
 *
 * - `musicToggleLike` : {kind: "artist" | "free", id, like?: boolean}. Une seule marque par personne et par titre (MusicLikes/{uid}_{kind}_{id}) ;
 *   le compteur `likeCount` du titre (artist_sounds/{id} ou MusicStudioStats/{id}) est mis à jour dans la même transaction, jamais par le téléphone.
 *   `like` fixe l'état voulu (idempotent : un double appui ne compte pas deux fois) ; sans `like`, l'état est inversé.
 *   Retourne {liked, count}.
 */
const okId = (id: unknown): id is string => typeof id === "string" && /^[A-Za-z0-9_-]{4,64}$/.test(id);

/** Nouvel état et nouveau compteur : ne descend jamais sous 0, ne compte pas deux fois la même personne. */
export function nextLikeState(exists: boolean, current: number, want: boolean | undefined): { liked: boolean; count: number; change: "add" | "remove" | "none" } {
  const base = Math.max(0, Math.trunc(Number.isFinite(current) ? current : 0));
  const target = want === undefined ? !exists : want;
  if (target && !exists) return { liked: true, count: base + 1, change: "add" };
  if (!target && exists) return { liked: false, count: Math.max(0, base - 1), change: "remove" };
  return { liked: exists, count: base, change: "none" };
}

export const musicToggleLike = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const d = (request.data ?? {}) as { kind?: unknown; id?: unknown; like?: unknown };
  const kind = d.kind === "free" || d.kind === "artist" ? d.kind : null;
  if (!kind || !okId(d.id)) throw new HttpsError("invalid-argument", "Titre invalide.");
  if (kind === "free" && !STUDIO_TRACK_IDS.has(d.id)) throw new HttpsError("invalid-argument", "Titre invalide.");
  const want = typeof d.like === "boolean" ? d.like : undefined;

  const targetRef = kind === "artist" ? db.collection("artist_sounds").doc(d.id) : db.collection("MusicStudioStats").doc(d.id);
  const likeRef = db.collection("MusicLikes").doc(`${uid}_${kind}_${d.id}`);

  return db.runTransaction(async (tx) => {
    const [target, like] = await Promise.all([tx.get(targetRef), tx.get(likeRef)]);
    if (kind === "artist" && (!target.exists || target.get("status") !== "validated")) throw new HttpsError("failed-precondition", "Ce titre n'est plus disponible.");
    const r = nextLikeState(like.exists, Number(target.get("likeCount") ?? 0), want);
    if (r.change === "add") {
      tx.set(likeRef, { uid, kind, id: d.id, createdAt: Date.now() });
      tx.set(targetRef, { likeCount: r.count }, { merge: true });
    } else if (r.change === "remove") {
      tx.delete(likeRef);
      tx.set(targetRef, { likeCount: r.count }, { merge: true });
    }
    return { ok: true, liked: r.liked, count: r.count };
  });
});
