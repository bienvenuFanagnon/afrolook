import { onSchedule } from "firebase-functions/v2/scheduler";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db } from "../shared/firebase";
import { CF_NEWS_ACCOUNTS } from "./ai";
import { requireAdmin } from "./adminAuth";
import { logNews } from "./log";
import { readPipelineConfig, readSource, runNewsPipeline, SourceStatus } from "./pipeline";
import { DEFAULT_SOURCES, NewsSourceDef, activeSources } from "./sources";

/**
 * Déclenchement du pipeline des actualités :
 * - newsPipelineTick : toutes les heures (à :20, heure UTC). Ne fait rien tant que `AppConfig/news.pipelineEnabled` n'est pas actif ;
 * - newsRunPipeline  : lancement à la main depuis l'administration (3 articles au plus par défaut) ou essai sans IA (`dryRun`) qui montre ce qui serait publié ;
 * - newsSourcesTest  : lit chaque source depuis le serveur (sans IA, sans rien publier) pour savoir lesquelles répondent.
 */
const RUN = { region: "us-central1" as const, timeoutSeconds: 540, memory: "512MiB" as const, secrets: [CF_NEWS_ACCOUNTS] };

export const newsPipelineTick = onSchedule({ ...RUN, schedule: "20 * * * *", timeZone: "UTC" }, async () => {
  const cfg = readPipelineConfig((await db.collection("AppConfig").doc("news").get()).data());
  if (!cfg.enabled || !cfg.pipelineEnabled) return;
  try {
    await runNewsPipeline();
  } catch (e) {
    console.error("[actualités] passage en erreur", e);
    await logNews({ kind: "error", ok: false, message: `Passage interrompu : ${e instanceof Error ? e.message : String(e)}` });
  }
});

export const newsRunPipeline = onCall(RUN, async (request) => {
  await requireAdmin(request);
  const d = (request.data ?? {}) as Record<string, unknown>;
  const maxPublish = Math.max(1, Math.min(8, Math.trunc(Number(d["maxPublish"] ?? 3)) || 3));
  return runNewsPipeline({ maxPublish, dryRun: d["dryRun"] === true });
});

export const newsSourcesTest = onCall({ region: "us-central1", timeoutSeconds: 180, memory: "256MiB" }, async (request) => {
  await requireAdmin(request);
  const cfg = (await db.collection("AppConfig").doc("news").get()).data();
  const on = activeSources({ sourcesOn: cfg?.["sourcesOn"] as Record<string, boolean> | undefined, customSources: cfg?.["customSources"] });
  const all: NewsSourceDef[] = [...DEFAULT_SOURCES, ...on.filter((s) => !DEFAULT_SOURCES.some((d) => d.id === s.id))];
  const out: SourceStatus[] = [];
  let next = 0;
  await Promise.all(Array.from({ length: 6 }, async () => {
    while (next < all.length) {
      const s = all[next++];
      const r = await readSource(s);
      out.push({ ...r.status, active: on.some((x) => x.id === s.id) });
    }
  }));
  const now = Date.now();
  const batch = db.batch();
  for (const s of out) batch.set(db.collection("NewsSources").doc(s.id), { ...s, at: now }, { merge: true });
  await batch.commit().catch(() => undefined);
  if (!out.length) throw new HttpsError("failed-precondition", "Aucune source");
  return { sources: out.sort((a, b) => Number(b.ok) - Number(a.ok) || a.id.localeCompare(b.id)) };
});
