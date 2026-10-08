import { onSchedule } from "firebase-functions/v2/scheduler";
import { FieldPath, FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";

/** Entrées « non vues » gardées au maximum 30 jours et 200 par utilisateur (poids du profil lu à chaque ouverture). */
const MAX_AGE_MS = 30 * 86_400_000;
const MAX_ENTRIES = 200;
/** Publications déjà vues : au-delà de VIEWED_TRIGGER entrées, on garde les VIEWED_KEEP plus récentes. */
const VIEWED_TRIGGER = 500;
const VIEWED_KEEP = 300;

/**
 * Nettoyage quotidien de `Users.unreadPosts` : le champ grossit tant que les posts ne sont pas
 * vus (le profil est limité à 1 Mo). On retire les entrées trop anciennes puis les plus vieilles
 * au-delà du plafond. Même passage pour `Users.viewedPostIds` (liste d'IDs, les plus récents en fin).
 * But : un profil léger = moins de données téléchargées à chaque lecture (coût Firestore).
 */
export const cleanupUnreadPosts = onSchedule(
  { schedule: "30 3 * * *", timeZone: "UTC", timeoutSeconds: 540, memory: "512MiB" },
  async () => {
    const cutoff = Date.now() - MAX_AGE_MS;
    let last: string | undefined;
    let usersTouched = 0;
    let removed = 0;
    for (;;) {
      let q = db.collection("Users").orderBy(FieldPath.documentId()).limit(300).select("unreadPosts", "viewedPostIds");
      if (last) q = q.startAfter(last);
      const snap = await q.get();
      if (snap.empty) break;
      let batch = db.batch();
      let ops = 0;
      for (const d of snap.docs) {
        const unread = (d.data().unreadPosts ?? {}) as Record<string, unknown>;
        const entries = Object.entries(unread).map(([id, v]) => {
          const ts = typeof v === "number" ? v : Number((v as { ts?: number } | null)?.ts ?? 0);
          return { id, ts };
        });
        const toDelete = new Set(entries.filter((e) => e.ts < cutoff).map((e) => e.id));
        const kept = entries.filter((e) => !toDelete.has(e.id)).sort((a, b) => b.ts - a.ts);
        kept.slice(MAX_ENTRIES).forEach((e) => toDelete.add(e.id));
        const viewed = d.data().viewedPostIds;
        const trimViewed = Array.isArray(viewed) && viewed.length > VIEWED_TRIGGER;
        if (toDelete.size === 0 && !trimViewed) continue;
        const upd: Record<string, FieldValue | string[]> = {};
        for (const id of toDelete) upd[`unreadPosts.${id}`] = FieldValue.delete();
        if (trimViewed) {
          upd["viewedPostIds"] = (viewed as string[]).slice(-VIEWED_KEEP);
          removed += (viewed as string[]).length - VIEWED_KEEP;
        }
        batch.update(d.ref, upd);
        removed += toDelete.size;
        usersTouched++;
        if (++ops >= 200) {
          await batch.commit();
          batch = db.batch();
          ops = 0;
        }
      }
      if (ops > 0) await batch.commit();
      last = snap.docs[snap.docs.length - 1].id;
    }
    console.log(`cleanupUnreadPosts — ${removed} entrées retirées sur ${usersTouched} profils`);
  }
);
