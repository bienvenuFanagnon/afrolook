import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";

/**
 * Abonnements : un document par relation dans `Follows`, identifiant `{créateur}_{abonné}`.
 *
 * - Les clients n'écrivent jamais dans `Follows` (règles) : tout passe par followUser / unfollowUser.
 * - Pendant la transition, l'ancienne liste `Users.userAbonnesIds` est tenue à jour en parallèle
 *   (anciennes versions de l'app) et `syncFollowsFromLegacy` recopie ses changements dans `Follows`.
 * - `Users.abonnes` est le compteur affiché partout.
 */
import { MAX_FOLLOWING, followDocId } from "./followersRead";

export const followUser = onCall({ timeoutSeconds: 30 }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Auth requise");
  const me = request.auth.uid;
  const target = String(request.data?.targetId ?? "");
  if (!target) throw new HttpsError("invalid-argument", "targetId requis");
  if (target === me) throw new HttpsError("failed-precondition", "Impossible de s'abonner à soi-même");

  const followRef = db.collection("Follows").doc(followDocId(target, me));
  const targetRef = db.collection("Users").doc(target);
  const meRef = db.collection("Users").doc(me);

  const result = await db.runTransaction(async (txn) => {
    const [follow, targetSnap, meSnap] = await Promise.all([txn.get(followRef), txn.get(targetRef), txn.get(meRef)]);
    if (!targetSnap.exists) throw new HttpsError("not-found", "Compte introuvable");
    if (follow.exists) return { already: true };
    const following: string[] = meSnap.data()?.followingIds ?? [];
    if (!following.includes(target) && following.length >= MAX_FOLLOWING) {
      throw new HttpsError("resource-exhausted", "Limite d'abonnements atteinte");
    }
    txn.create(followRef, { creatorId: target, followerId: me, createdAt: Date.now() });
    txn.update(targetRef, {
      userAbonnesIds: FieldValue.arrayUnion(me), // transition (anciennes versions)
      abonnes: FieldValue.increment(1),
    });
    txn.set(meRef, { followingIds: FieldValue.arrayUnion(target) }, { merge: true });
    return { already: false };
  });
  return { ok: true, ...result };
});

export const unfollowUser = onCall({ timeoutSeconds: 30 }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Auth requise");
  const me = request.auth.uid;
  const target = String(request.data?.targetId ?? "");
  if (!target) throw new HttpsError("invalid-argument", "targetId requis");

  const followRef = db.collection("Follows").doc(followDocId(target, me));
  const targetRef = db.collection("Users").doc(target);
  const meRef = db.collection("Users").doc(me);

  const result = await db.runTransaction(async (txn) => {
    const follow = await txn.get(followRef);
    if (!follow.exists) {
      // Relation absente de Follows : on nettoie quand même les anciennes listes.
      txn.set(meRef, { followingIds: FieldValue.arrayRemove(target) }, { merge: true });
      txn.set(targetRef, { userAbonnesIds: FieldValue.arrayRemove(me) }, { merge: true });
      return { already: true };
    }
    txn.delete(followRef);
    txn.update(targetRef, {
      userAbonnesIds: FieldValue.arrayRemove(me),
      abonnes: FieldValue.increment(-1),
    });
    txn.set(meRef, { followingIds: FieldValue.arrayRemove(target) }, { merge: true });
    return { already: false };
  });
  // Anciennes relations de la collection `Abonnements` (lues par certains écrans)
  try {
    const old = await db.collection("Abonnements")
      .where("compte_user_id", "==", me).where("abonne_user_id", "==", target).get();
    await Promise.all(old.docs.map((d) => d.ref.delete()));
  } catch (e) {
    console.error("unfollowUser — nettoyage Abonnements :", e);
  }
  return { ok: true, ...result };
});

/**
 * Compatibilité : les anciennes versions de l'app écrivent encore `userAbonnesIds` directement.
 * On recopie ces changements dans `Follows`. À supprimer quand elles auront disparu.
 */
export const syncFollowsFromLegacy = onDocumentUpdated("Users/{userId}", async (event) => {
  const before: string[] = event.data?.before.data()?.userAbonnesIds ?? [];
  const after: string[] = event.data?.after.data()?.userAbonnesIds ?? [];
  if (before.length === after.length && before.every((v, i) => v === after[i])) return;
  const creatorId = event.params.userId;
  const b = new Set(before);
  const a = new Set(after);
  const added = after.filter((id) => !b.has(id));
  const removed = before.filter((id) => !a.has(id));
  if (added.length === 0 && removed.length === 0) return;
  const batch = db.batch();
  for (const id of added) {
    batch.set(db.collection("Follows").doc(followDocId(creatorId, id)),
      { creatorId, followerId: id, createdAt: Date.now() }, { merge: true });
  }
  for (const id of removed) batch.delete(db.collection("Follows").doc(followDocId(creatorId, id)));
  await batch.commit();
});
