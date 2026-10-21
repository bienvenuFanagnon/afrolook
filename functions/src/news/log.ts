import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";

/**
 * Journal des actualités, visible dans l'administration : chaque appel à l'IA (réussi ou en erreur, compte masqué, modèle, neurons, durée),
 * chaque article publié et chaque incident du pipeline. L'état de chaque compte Cloudflare (dernier succès, dernière erreur) est tenu à part
 * (NewsHealth/ai) pour voir d'un coup d'œil si un compte pose problème. Un échec d'écriture du journal ne bloque jamais le travail.
 * Collections écrites par le serveur seulement (règles Firestore) ; l'administration les lit par la fonction newsLogs.
 */
export interface NewsLogEntry {
  kind: "ai" | "publish" | "collect" | "error";
  ok: boolean;
  message: string;
  account?: string;
  model?: string;
  neurons?: number;
  ms?: number;
  ref?: string;
}

export async function logNews(e: NewsLogEntry, nowMs = Date.now()): Promise<void> {
  try {
    const doc: Record<string, unknown> = { kind: e.kind, ok: e.ok, message: e.message.slice(0, 240), at: nowMs };
    for (const k of ["account", "model", "ref"] as const) if (e[k]) doc[k] = e[k];
    if (typeof e.neurons === "number") doc["neurons"] = Math.round(e.neurons * 100) / 100;
    if (typeof e.ms === "number") doc["ms"] = e.ms;
    await db.collection("NewsLog").add(doc);
  } catch (err) {
    console.error("[actualités] journal non écrit", err);
  }
}

/** État d'un compte Cloudflare : dernier succès, dernière erreur et compteurs. */
export async function recordAiHealth(account: string, ok: boolean, error: string | undefined, nowMs = Date.now()): Promise<void> {
  try {
    const patch = ok
      ? { lastOkAt: nowMs, okCount: FieldValue.increment(1) }
      : { lastErrorAt: nowMs, lastError: String(error ?? "").slice(0, 160), errCount: FieldValue.increment(1) };
    await db.collection("NewsHealth").doc("ai").set({ accounts: { [account]: patch }, updatedAt: nowMs }, { merge: true });
  } catch (err) {
    console.error("[actualités] état de l'IA non écrit", err);
  }
}

export interface NewsLogRow { id: string; kind: string; ok: boolean; message: string; at: number; account?: string; model?: string; neurons?: number; ms?: number; ref?: string }

/** Dernières lignes du journal (les plus récentes d'abord) et état des comptes. */
export async function readNewsLogs(limit = 60): Promise<{ logs: NewsLogRow[]; health: Record<string, unknown> }> {
  const [snap, health] = await Promise.all([
    db.collection("NewsLog").orderBy("at", "desc").limit(Math.max(1, Math.min(200, limit))).get(),
    db.collection("NewsHealth").doc("ai").get(),
  ]);
  return {
    logs: snap.docs.map((d) => ({ id: d.id, ...(d.data() as Omit<NewsLogRow, "id">) })),
    health: ((health.data()?.["accounts"] as Record<string, unknown> | undefined) ?? {}),
  };
}
