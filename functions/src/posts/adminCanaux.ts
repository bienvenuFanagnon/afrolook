import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";
import { deleteFileByUrl, deletePostWithMedia, deleteQuery } from "../users/accountPurge";
import { notifyOwner } from "./canalInactivity";

/**
 * Gestion des canaux par un administrateur (page admin « Canaux »).
 * Actions : block, unblock, verify, unverify, popular (days), unpopular, reset_inactivity, notify (message),
 * fill_followers (count : ajoute des abonnés parmi les comptes les plus suivis), delete.
 * Chaque action est journalisée dans AdminActions.
 *
 * Champs écrits sur Canaux/{id} : isBlocked, blockedAt, blockReason ("admin"), isVerify,
 * isPopular, popularUntil (ms, 0 = sans limite), lastPostAt, unlockedAt.
 */
async function requireAdmin(uid: string | undefined) {
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const admin = await db.collection("Users").doc(uid).get();
  if (admin.data()?.["role"] !== "ADM") throw new HttpsError("permission-denied", "Réservé aux admins.");
}

export const adminCanalAction = onCall({ timeoutSeconds: 300, memory: "512MiB" }, async (request) => {
  await requireAdmin(request.auth?.uid);
  const { canalId, action, days, message, count } = request.data as {
    canalId?: string; action?: string; days?: number; message?: string; count?: number;
  };
  if (!canalId || !action) throw new HttpsError("invalid-argument", "canalId et action requis.");
  const ref = db.collection("Canaux").doc(canalId);
  const doc = await ref.get();
  if (!doc.exists) throw new HttpsError("not-found", "Canal introuvable.");
  const c = doc.data()!;
  const ownerId = c["userId"] as string | undefined;
  const titre = String(c["titre"] ?? "ton canal");
  const now = Date.now();
  const clear = {
    blockReason: FieldValue.delete(), blockedAt: FieldValue.delete(), inactivityWarnedAt: FieldValue.delete(),
  };

  switch (action) {
    case "block":
      await ref.update({ isBlocked: true, blockedAt: now, blockReason: "admin" });
      if (ownerId) await notifyOwner(ownerId, canalId, "🔒 Canal bloqué", `#${titre} a été bloqué par l'équipe Afrolook. Contacte le support pour plus d'informations.`);
      break;
    case "unblock":
      await ref.update({ isBlocked: false, lastPostAt: now, unlockedAt: now, ...clear });
      if (ownerId) await notifyOwner(ownerId, canalId, "🔓 Canal débloqué", `#${titre} a été débloqué par l'équipe Afrolook.`);
      break;
    case "verify":
      await ref.update({ isVerify: true });
      break;
    case "unverify":
      await ref.update({ isVerify: false });
      break;
    case "popular": {
      const d = Math.max(0, Math.floor(Number(days) || 0));
      await ref.update({ isPopular: true, popularAt: now, popularUntil: d > 0 ? now + d * 24 * 60 * 60 * 1000 : 0 });
      if (ownerId) await notifyOwner(ownerId, canalId, "⭐ Canal mis en avant", `#${titre} est mis en avant sur Afrolook${d > 0 ? ` pendant ${d} jours` : ""}.`);
      break;
    }
    case "unpopular":
      await ref.update({ isPopular: false, popularUntil: FieldValue.delete(), popularAt: FieldValue.delete() });
      break;
    case "reset_inactivity":
      await ref.update({ lastPostAt: now, ...clear });
      break;
    case "notify": {
      const text = String(message ?? "").trim();
      if (!text) throw new HttpsError("invalid-argument", "Message vide.");
      if (!ownerId) throw new HttpsError("failed-precondition", "Ce canal n'a pas de propriétaire.");
      await notifyOwner(ownerId, canalId, "📣 Message de l'équipe Afrolook", text.slice(0, 500));
      break;
    }
    case "fill_followers": {
      // Ajoute des abonnés parmi les comptes les plus suivis qui ne suivent pas encore le canal
      const wanted = Math.min(5000, Math.max(1, Math.floor(Number(count) || 0)));
      const existing = new Set<string>(Array.isArray(c["usersSuiviId"]) ? (c["usersSuiviId"] as string[]) : []);
      if (ownerId) existing.add(ownerId);
      const toAdd: string[] = [];
      let last: FirebaseFirestore.QueryDocumentSnapshot | undefined;
      while (toAdd.length < wanted) {
        let q = db.collection("Users").orderBy("abonnes", "desc").limit(500);
        if (last) q = q.startAfter(last);
        const page = await q.select("abonnes").get();
        if (page.empty) break;
        for (const u of page.docs) {
          if (!existing.has(u.id)) { toAdd.push(u.id); if (toAdd.length >= wanted) break; }
        }
        last = page.docs[page.docs.length - 1];
        if (page.size < 500) break;
      }
      for (let i = 0; i < toAdd.length; i += 500) {
        const chunk = toAdd.slice(i, i + 500);
        await ref.update({ usersSuiviId: FieldValue.arrayUnion(...chunk), suivi: FieldValue.increment(chunk.length) });
      }
      await db.collection("AdminActions").add({
        adminId: request.auth!.uid, targetType: "canal", targetId: canalId, action, at: now, added: toAdd.length,
      });
      return { ok: true, added: toAdd.length };
    }
    case "delete": {
      await deleteQuery(db.collection("Posts").where("canal_id", "==", canalId), deletePostWithMedia);
      await deleteFileByUrl(c["urlImage"]);
      await deleteFileByUrl(c["urlCouverture"]);
      const names = await db.collection("CanalNames").where("name", "==", c["titre"] ?? "").get();
      await Promise.all(names.docs.map((n) => n.ref.delete()));
      await db.recursiveDelete(ref);
      if (ownerId) await notifyOwner(ownerId, canalId, "🗑️ Canal supprimé", `#${titre} a été supprimé par l'équipe Afrolook.`);
      break;
    }
    default:
      throw new HttpsError("invalid-argument", "Action inconnue.");
  }

  await db.collection("AdminActions").add({
    adminId: request.auth!.uid, targetType: "canal", targetId: canalId, action, at: now,
    ...(days ? { days } : {}), ...(message ? { message: String(message).slice(0, 500) } : {}),
  });
  return { ok: true };
});
