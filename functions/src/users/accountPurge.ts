import { onSchedule } from "firebase-functions/v2/scheduler";
import { getAuth } from "firebase-admin/auth";
import { getStorage } from "firebase-admin/storage";
import { FieldValue, Query } from "firebase-admin/firestore";
import { db } from "../shared/firebase";

/**
 * Effacement définitif des comptes supprimés, 15 jours après la demande (requestAccountDeletion),
 * et une fois pour les anciens comptes marqués « deleted » avant ce système.
 *
 * Règles retenues :
 * - supprimés : fiche, posts (et leurs médias), commentaires, lives, chroniques, pubs, contenus payants,
 *   articles Afroshop, entreprise, profil Afrolove, notifications, invitations, blocages, pseudo réservé,
 *   clés de chiffrement, fichiers du profil, connexion ;
 * - canaux et groupes : transmis au premier autre admin (ou membre pour un groupe), sinon supprimés ;
 * - l'utilisateur est retiré des listes d'abonnés, d'abonnements et d'amis des autres comptes ;
 * - conservés : historique financier (transactions, retraits, achats) et messages privés reçus par
 *   les autres — la fiche étant supprimée, l'expéditeur n'est plus identifiable.
 */

const MAX_ACCOUNTS_PER_RUN = 5;
const bucket = () => getStorage().bucket();

/** Chemin Storage à partir d'une URL de téléchargement Firebase (…/o/<chemin encodé>?…). */
function storagePathFromUrl(url: unknown): string | null {
  if (typeof url !== "string") return null;
  const m = url.match(/\/o\/([^?]+)/);
  return m ? decodeURIComponent(m[1]) : null;
}

async function deleteFileByUrl(url: unknown) {
  const p = storagePathFromUrl(url);
  if (!p) return;
  try {
    await bucket().file(p).delete({ ignoreNotFound: true });
  } catch (e) {
    console.warn("Fichier non supprimé :", p, e);
  }
}

/** Supprime tous les documents d'une requête, par lots. */
async function deleteQuery(q: Query, onDoc?: (d: FirebaseFirestore.QueryDocumentSnapshot) => Promise<void>) {
  for (;;) {
    const snap = await q.limit(300).get();
    if (snap.empty) return;
    if (onDoc) await Promise.all(snap.docs.map(onDoc));
    const batch = db.batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    if (snap.size < 300) return;
  }
}

/** Retire uid d'un champ tableau sur tous les documents qui le contiennent. */
async function arrayRemoveEverywhere(collection: string, field: string, uid: string) {
  for (;;) {
    const snap = await db.collection(collection).where(field, "array-contains", uid).limit(300).get();
    if (snap.empty) return;
    const batch = db.batch();
    snap.docs.forEach((d) => batch.update(d.ref, { [field]: FieldValue.arrayRemove(uid) }));
    await batch.commit();
    if (snap.size < 300) return;
  }
}

async function deletePostWithMedia(d: FirebaseFirestore.QueryDocumentSnapshot) {
  const p = d.data();
  const urls: unknown[] = [...((p["images"] as unknown[]) ?? []), p["url_media"], p["thumbnail"]];
  await Promise.all(urls.map(deleteFileByUrl));
}

async function purgeAccount(uid: string, user: FirebaseFirestore.DocumentData) {
  // Canaux créés : transmis au premier autre admin, sinon supprimés avec leurs posts
  const canaux = await db.collection("Canaux").where("userId", "==", uid).get();
  for (const c of canaux.docs) {
    const others = ((c.data()["adminIds"] as string[]) ?? []).filter((id) => id && id !== uid);
    if (others.length > 0) {
      await c.ref.update({ userId: others[0], adminIds: FieldValue.arrayRemove(uid) });
    } else {
      await deleteQuery(db.collection("Posts").where("canal_id", "==", c.id), deletePostWithMedia);
      await deleteFileByUrl(c.data()["urlImage"]);
      await deleteFileByUrl(c.data()["urlCouverture"]);
      await db.recursiveDelete(c.ref);
    }
  }
  await arrayRemoveEverywhere("Canaux", "adminIds", uid);
  await arrayRemoveEverywhere("Canaux", "usersSuiviId", uid);

  // Groupes créés : transmis au premier autre membre, sinon supprimés
  const groups = await db.collection("GroupChats").where("owner_id", "==", uid).get();
  for (const g of groups.docs) {
    const others = ((g.data()["member_ids"] as string[]) ?? []).filter((id) => id && id !== uid);
    if (others.length > 0) {
      await g.ref.update({ owner_id: others[0], member_ids: FieldValue.arrayRemove(uid) });
    } else {
      await db.recursiveDelete(g.ref);
    }
  }
  await arrayRemoveEverywhere("GroupChats", "member_ids", uid);

  // Contenus de l'utilisateur
  await deleteQuery(db.collection("Posts").where("user_id", "==", uid), deletePostWithMedia);
  await deleteQuery(db.collection("PostComments").where("user_id", "==", uid));
  await deleteQuery(db.collection("lives").where("hostId", "==", uid));
  await deleteQuery(db.collection("chroniques").where("userId", "==", uid));
  await deleteQuery(db.collection("Advertisements").where("createdBy", "==", uid));
  await deleteQuery(db.collection("ContentPaies").where("ownerId", "==", uid));
  await deleteQuery(db.collection("Articles").where("user_id", "==", uid));
  await deleteQuery(db.collection("Entreprises").where("userId", "==", uid));
  await deleteQuery(db.collection("creator_profiles").where("userId", "==", uid));
  await deleteQuery(db.collection("creator_contents").where("creatorUserId", "==", uid));

  // Afrolove
  await deleteQuery(db.collection("dating_profiles").where("userId", "==", uid));
  await deleteQuery(db.collection("dating_likes").where("fromUserId", "==", uid));
  await deleteQuery(db.collection("dating_likes").where("toUserId", "==", uid));
  await deleteQuery(db.collection("dating_connections").where("userId", "==", uid));
  await deleteQuery(db.collection("dating_connections").where("fromUserId", "==", uid));
  await deleteQuery(db.collection("profile_likes").where("likedUserId", "==", uid));

  // Relations et données personnelles
  await deleteQuery(db.collection("Notifications").where("receiver_id", "==", uid));
  await deleteQuery(db.collection("Invitations").where("receiver_id", "==", uid));
  await deleteQuery(db.collection("Invitations").where("sender_id", "==", uid));
  await deleteQuery(db.collection("BlockedUsers").where("blockedBy", "==", uid));
  if (typeof user["pseudo"] === "string" && user["pseudo"]) {
    await deleteQuery(db.collection("Pseudo").where("name", "==", user["pseudo"]));
  }
  await db.collection("UserKeys").doc(uid).delete().catch(() => undefined);

  // Retrait des listes des autres comptes
  await arrayRemoveEverywhere("Users", "userAbonnesIds", uid);
  await arrayRemoveEverywhere("Users", "followingIds", uid);
  await arrayRemoveEverywhere("Users", "friendsIds", uid);

  // Fichiers du profil
  await deleteFileByUrl(user["imageUrl"]);
  await deleteFileByUrl(user["urlCouverture"]);
  try {
    await bucket().deleteFiles({ prefix: `user_profile/${uid}` });
  } catch (e) {
    console.warn("Fichiers de profil :", e);
  }

  // Fiche et connexion
  await db.recursiveDelete(db.collection("Users").doc(uid));
  await getAuth().deleteUser(uid).catch(() => undefined); // déjà supprimée pour les anciens comptes
}

export const purgeDeletedAccounts = onSchedule(
  { schedule: "every day 03:00", timeZone: "Africa/Abidjan", timeoutSeconds: 540, memory: "1GiB" },
  async () => {
    const now = Date.now();
    const snap = await db.collection("Users").where("deleted", "==", true).limit(50).get();
    const due = snap.docs.filter((d) => {
      const u = d.data();
      if (u["accountStatus"] === "PENDING_DELETION") return typeof u["deletionScheduledAt"] === "number" && u["deletionScheduledAt"] <= now;
      return u["accountStatus"] == null; // anciens comptes supprimés avant ce système
    }).slice(0, MAX_ACCOUNTS_PER_RUN);

    for (const d of due) {
      try {
        await purgeAccount(d.id, d.data());
        console.log(`purgeDeletedAccounts : compte ${d.id} effacé.`);
      } catch (e) {
        console.error(`purgeDeletedAccounts : échec pour ${d.id}`, e);
      }
    }
  }
);
