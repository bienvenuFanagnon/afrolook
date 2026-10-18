import { onCall, HttpsError } from "firebase-functions/v2/https";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";

/**
 * Mesure des lectures Firestore par écran (diagnostic temporaire, tâche #94).
 * Chaque téléphone envoie, toutes les 10 minutes environ, les compteurs de lectures de ses 60 sources les plus actives
 * (`fichier.dart:ligne`). On les additionne par jour dans `ReadStats/{jour}` (lecture réservée à l'administrateur).
 * Interrupteur : `AppConfig/readMeter` → `{ enabled: false }` coupe l'envoi (les téléphones s'arrêtent à la réponse suivante).
 */
export const MAX_TAGS = 80;
export const MAX_TAG_LENGTH = 70;
export const MAX_COUNT = 2_000_000;

/** Clé de champ Firestore sûre : lettres, chiffres et « _ » seulement (le « : » et le « . » d'un nom de fichier ne passent pas). */
export function safeTag(raw: string): string {
  return String(raw).replace(/[^A-Za-z0-9_]/g, "_").slice(0, MAX_TAG_LENGTH);
}

/** Compteurs reçus → compteurs acceptés (au plus 80 sources, valeurs entières entre 1 et 2 millions). */
export function cleanTags(input: unknown): Record<string, number> {
  const out: Record<string, number> = {};
  if (!input || typeof input !== "object") return out;
  for (const [k, v] of Object.entries(input as Record<string, unknown>)) {
    if (Object.keys(out).length >= MAX_TAGS) break;
    const n = Math.floor(Number(v));
    if (!Number.isFinite(n) || n < 1) continue;
    const key = safeTag(k);
    if (!key) continue;
    out[key] = Math.min(MAX_COUNT, (out[key] ?? 0) + n);
  }
  return out;
}

export function dayKey(ms: number): string {
  return new Date(ms).toISOString().slice(0, 10).replace(/-/g, "");
}

export const readStatsReport = onCall({ timeoutSeconds: 30, maxInstances: 5, memory: "256MiB" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Connexion requise");
  const cfg = await db.collection("AppConfig").doc("readMeter").get();
  if (cfg.exists && cfg.data()?.["enabled"] === false) return { enabled: false };

  const tags = cleanTags(request.data?.tags);
  if (Object.keys(tags).length === 0) return { enabled: true, stored: 0 };
  const platform = ["android", "ios", "web"].includes(String(request.data?.platform)) ? String(request.data.platform) : "other";
  const version = safeTag(String(request.data?.version ?? "")).slice(0, 20);

  const inc: Record<string, FieldValue> = {};
  for (const [k, n] of Object.entries(tags)) inc[k] = FieldValue.increment(n);
  const total = Object.values(tags).reduce((a, b) => a + b, 0);
  const day = dayKey(Date.now());
  await db.collection("ReadStats").doc(day).set(
    {
      day,
      reports: FieldValue.increment(1),
      totalReads: FieldValue.increment(total),
      tags: inc,
      platforms: { [platform]: FieldValue.increment(1) },
      ...(version ? { versions: { [version]: FieldValue.increment(1) } } : {}),
      updatedAt: Date.now(),
    },
    { merge: true },
  );
  return { enabled: true, stored: Object.keys(tags).length };
});
