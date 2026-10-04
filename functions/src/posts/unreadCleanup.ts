import { onSchedule } from "firebase-functions/v2/scheduler";
import { FieldPath, FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";

/** Entrées « non vues » gardées au maximum 60 jours et 1000 par utilisateur. */
const MAX_AGE_MS = 60 * 86_400_000;
const MAX_ENTRIES = 1000;

/**
 * Nettoyage quotidien de `Users.unreadPosts` : le champ grossit tant que les posts ne sont pas
 * vus (le profil est limité à 1 Mo). On retire les entrées trop anciennes puis les plus vieilles
 * au-delà du plafond.
 */
export const cleanupUnreadPosts = onSchedule(
  { schedule: "30 3 * * *", timeZone: "UTC", timeoutSeconds: 540, memory: "512MiB" },
  async () => {
    const cutoff = Date.now() - MAX_AGE_MS;
    let last: string | undefined;
    let usersTouched = 0;
    let removed = 0;
    for (;;) {
      let q = db.collection("Users").orderBy(FieldPath.documentId()).limit(300).select("unreadPosts");
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
        if (toDelete.size === 0) continue;
        const upd: Record<string, FieldValue> = {};
        for (const id of toDelete) upd[`unreadPosts.${id}`] = FieldValue.delete();
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
