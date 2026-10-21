import { onSchedule } from "firebase-functions/v2/scheduler";
import { db } from "../shared/firebase";
import { logNews } from "./log";
import { DAY_MS, MAX_LIFE_DAYS, NewsFeedItem, decideExpiry } from "./model";
import { purgeComments } from "./publish";

/**
 * Nettoyage quotidien des actualités : les articles disparaissent à la fin de leur vie, et rien ne grossit sans fin (donc pas de stockage inutile).
 *  - articles arrivés à échéance : supprimés avec leurs commentaires et leur état de notifications, sauf ceux très aimés ou très commentés,
 *    prolongés une fois (voir decideExpiry) ; garde-fou : plus de 45 jours, supprimé quoi qu'il arrive ;
 *  - index du fil : les articles disparus ou périmés en sont retirés, la fin de vie des articles prolongés est mise à jour ;
 *  - journal : 14 jours ; sujets déjà vus : 7 jours ; compteurs et consommation par jour : 30 jours.
 * Chaque passage traite au plus quelques centaines de documents ; le reste part le lendemain.
 */
const BATCH = 400;
const MAX_ARTICLES = 200;

async function purge(collection: string, field: string, cutoff: number | string, limit = BATCH): Promise<number> {
  const snap = await db.collection(collection).where(field, "<", cutoff).limit(limit).get();
  if (snap.empty) return 0;
  const batch = db.batch();
  snap.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
  return snap.size;
}

/** Retire des index du fil les articles supprimés ou périmés et met à jour la fin de vie de ceux qui ont été prolongés. */
export async function syncFeedIndexes(removed: Set<string>, extended: Map<string, number>, nowMs: number): Promise<number> {
  const snap = await db.collection("NewsFeed").get();
  let changed = 0;
  for (const d of snap.docs) {
    const items = ((d.data()["items"] as NewsFeedItem[] | undefined) ?? []);
    const next = items
      .filter((i) => !removed.has(i.id))
      .map((i) => (extended.has(i.id) ? { ...i, exp: extended.get(i.id) as number } : i))
      .filter((i) => !i.exp || i.exp > nowMs);
    const prolonged = [...extended.keys()].some((id) => items.some((i) => i.id === id));
    if (next.length !== items.length || prolonged) {
      await d.ref.set({ items: next, updatedAt: nowMs }, { merge: true });
      changed++;
    }
  }
  return changed;
}

export async function runNewsCleanup(nowMs = Date.now()): Promise<Record<string, number>> {
  const compact = (ms: number) => new Date(ms).toISOString().slice(0, 10).replace(/-/g, "");
  const iso = (ms: number) => new Date(ms).toISOString().slice(0, 10);
  const out: Record<string, number> = {};
  out["Journal"] = await purge("NewsLog", "at", nowMs - 14 * DAY_MS);
  out["Sujets vus"] = await purge("NewsSeen", "at", nowMs - 7 * DAY_MS);
  out["Compteurs"] = await purge("NewsRuns", "day", iso(nowMs - 30 * DAY_MS));
  out["Consommation IA"] = await purge("NewsBudget", "day", compact(nowMs - 30 * DAY_MS));
  out["Plafonds de notifications"] = await purge("NewsPushDaily", "updatedAt", nowMs - 30 * DAY_MS);
  out["Résumés périmés"] = await purge("NewsDigests", "expireAt", nowMs);

  // articles arrivés à échéance, puis garde-fou sur les plus de 45 jours (y compris sans date de fin)
  const [due, old] = await Promise.all([
    db.collection("Posts").where("type", "==", "NEWS").where("expiresAt", "<=", nowMs).limit(MAX_ARTICLES).get(),
    db.collection("Posts").where("type", "==", "NEWS").where("created_at", "<", (nowMs - MAX_LIFE_DAYS * DAY_MS) * 1000).limit(MAX_ARTICLES).get(),
  ]);
  const removed = new Set<string>();
  const extended = new Map<string, number>();
  const batch = db.batch();
  for (const d of due.docs) {
    const decision = decideExpiry(d.data(), nowMs);
    if (decision.action === "extend") {
      batch.update(d.ref, { expiresAt: decision.expiresAt, extendedTier: decision.tier });
      extended.set(d.id, decision.expiresAt);
    } else if (decision.action === "delete") {
      removed.add(d.id);
    }
  }
  for (const d of old.docs) removed.add(d.id);
  for (const id of removed) {
    batch.delete(db.collection("Posts").doc(id));
    batch.delete(db.collection("NewsPushState").doc(id));
  }
  if (removed.size || extended.size) await batch.commit();
  let comments = 0;
  for (const id of removed) comments += await purgeComments(id);
  out["Articles supprimés"] = removed.size;
  out["Articles prolongés"] = extended.size;
  out["Commentaires supprimés"] = comments;
  out["Index mis à jour"] = await syncFeedIndexes(removed, extended, nowMs);
  return out;
}

export const newsCleanup = onSchedule({ region: "us-central1", schedule: "30 3 * * *", timeZone: "UTC", timeoutSeconds: 300, memory: "256MiB" }, async () => {
  try {
    const r = await runNewsCleanup();
    const done = Object.entries(r).filter(([, n]) => n > 0);
    if (done.length) await logNews({ kind: "collect", ok: true, message: `Nettoyage : ${done.map(([k, n]) => `${k} ${n}`).join(", ")}` });
  } catch (e) {
    console.error("[actualités] nettoyage en erreur", e);
    await logNews({ kind: "error", ok: false, message: `Nettoyage interrompu : ${e instanceof Error ? e.message : String(e)}` });
  }
});
