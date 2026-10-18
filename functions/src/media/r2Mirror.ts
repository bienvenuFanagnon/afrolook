import { onSchedule } from "firebase-functions/v2/scheduler";
import { S3Client, PutObjectCommand, HeadObjectCommand, DeleteObjectCommand, ListObjectsV2Command } from "@aws-sdk/client-s3";
import { getStorage } from "firebase-admin/storage";
import type { GetFilesOptions } from "@google-cloud/storage";
import { db } from "../shared/firebase";

/**
 * Miroir des médias vers Cloudflare R2 (stockage sans frais de sortie).
 *
 * Chaque fichier envoyé à Firebase Storage est recopié à l'identique (même chemin) dans le compartiment R2 `afrolook-media`,
 * avec son jeton de téléchargement en métadonnée : le Worker du CDN (cdn.afrolookmedia.com) lit R2 en priorité, vérifie le jeton
 * du lien, et retombe sur Firebase Storage si le fichier n'est pas (encore) dans R2. Un fichier supprimé de Storage est supprimé de R2.
 * L'application continue d'envoyer vers Firebase Storage : aucune version à publier.
 * Un balayage toutes les 10 minutes recopie les fichiers nouveaux ou modifiés ; chaque nuit, il retire de R2 ce qui n'existe plus dans Storage.
 */
const R2_ENDPOINT = "https://1ca805dd06ac6fce94a31002da9c672f.r2.cloudflarestorage.com";
const R2_BUCKET = "afrolook-media";
const BUCKET = "afrolooki.appspot.com";
const MAX_BYTES = 250 * 1024 * 1024;

/** Dossiers jamais copiés : versions de test, liens temporaires et titres complets payants. */
const SKIP_PREFIXES = ["test-builds/", "test_builds/", "artist_sound_tmp/", "artist_sounds/"];

export function shouldMirror(name: string): boolean {
  return !!name && !name.endsWith("/") && !SKIP_PREFIXES.some((p) => name.startsWith(p));
}

function client(): S3Client {
  return new S3Client({
    region: "auto", endpoint: R2_ENDPOINT, maxAttempts: 5,
    credentials: { accessKeyId: process.env.R2_ACCESS_KEY_ID ?? "", secretAccessKey: process.env.R2_SECRET_ACCESS_KEY ?? "" },
  });
}

async function mirror(name: string): Promise<void> {
  if (!shouldMirror(name)) return;
  const file = getStorage().bucket(BUCKET).file(name);
  let meta;
  try {
    [meta] = await file.getMetadata();
  } catch (e) {
    if ((e as { code?: number }).code === 404) return; // supprimé entre-temps
    throw e;
  }
  const size = Number(meta.size ?? 0);
  if (size > MAX_BYTES) {
    console.warn(`[r2Mirror] trop gros, non copié : ${name} (${size} octets)`);
    return;
  }
  const tokens = String((meta.metadata as Record<string, unknown> | undefined)?.["firebaseStorageDownloadTokens"] ?? "").slice(0, 1500);
  const s3 = client();
  try {
    const head = await s3.send(new HeadObjectCommand({ Bucket: R2_BUCKET, Key: name }));
    if (head.ContentLength === size && (head.Metadata?.["tokens"] ?? "") === tokens) return; // déjà à jour
  } catch (e) {
    if ((e as { $metadata?: { httpStatusCode?: number } }).$metadata?.httpStatusCode !== 404) throw e;
  }
  const [body] = await file.download();
  await s3.send(new PutObjectCommand({
    Bucket: R2_BUCKET, Key: name, Body: body,
    ContentType: meta.contentType ?? "application/octet-stream",
    CacheControl: "public, max-age=2592000",
    Metadata: { tokens, src: "gcs" },
  }));
}

/** Date de dernière modification d'un fichier de la liste. Avec la liste allégée (`fields`), la bibliothèque pose les dates sur le fichier
 *  lui-même et non dans `metadata` : on lit les deux. */
export function updatedMs(f: unknown): number {
  const o = f as { metadata?: { updated?: string; timeCreated?: string }; updated?: string; timeCreated?: string };
  const iso = o.metadata?.updated ?? o.metadata?.timeCreated ?? o.updated ?? o.timeCreated;
  if (!iso) return 0;
  const ms = Date.parse(String(iso));
  return Number.isNaN(ms) ? 0 : ms;
}

const CURSOR_DOC = "AppConfig/r2Mirror";

/** Balayage : copie les fichiers créés ou modifiés depuis le dernier passage (jamais plus de 2 h en arrière sans reprise manuelle). */
export const r2MirrorSweep = onSchedule(
  { schedule: "every 10 minutes", memory: "1GiB", timeoutSeconds: 540, maxInstances: 1 },
  async () => {
    const now = Date.now();
    const ref = db.doc(CURSOR_DOC);
    const last = Number((await ref.get()).data()?.["lastRunMs"] ?? now - 30 * 60 * 1000);
    const since = Math.max(last - 2 * 60 * 1000, now - 2 * 3600 * 1000); // marge de recouvrement
    const bucket = getStorage().bucket(BUCKET);
    // On ne demande que le nom et les dates : la liste complète avec toutes les métadonnées (jetons, URL…) pesait ~1,2 Mo par page de 1 000
    // fichiers, relue 144 fois par jour (≈ 3 Go/jour sortant de Cloud Storage). Le détail d'un fichier est lu seulement s'il faut le copier.
    const [files] = await bucket.getFiles({
      autoPaginate: true,
      fields: "items(name,updated,timeCreated),nextPageToken",
    } as unknown as GetFilesOptions);
    const todo = files.filter((f) => shouldMirror(f.name) && updatedMs(f) >= since);
    let done = 0, failed = 0;
    for (const f of todo) {
      try {
        await mirror(f.name);
        done++;
      } catch (e) {
        failed++;
        console.error(`[r2MirrorSweep] ${f.name} :`, e);
      }
    }
    await ref.set({ lastRunMs: failed ? last : now, lastDone: done, lastFailed: failed, updatedAt: now }, { merge: true });
    console.log(`[r2MirrorSweep] ${done} copiés, ${failed} échecs, ${files.length} fichiers dans Storage`);

    // Nettoyage nocturne : ce qui a été supprimé de Storage disparaît aussi de R2
    const nowDate = new Date(now);
    if (nowDate.getUTCHours() === 3 && nowDate.getUTCMinutes() < 10) {
      const present = new Set(files.map((f) => f.name));
      const s3 = client();
      let token: string | undefined;
      let removed = 0;
      do {
        const page = await s3.send(new ListObjectsV2Command({ Bucket: R2_BUCKET, ContinuationToken: token }));
        for (const o of page.Contents ?? []) {
          if (o.Key && shouldMirror(o.Key) && !present.has(o.Key)) {
            await s3.send(new DeleteObjectCommand({ Bucket: R2_BUCKET, Key: o.Key }));
            removed++;
          }
        }
        token = page.IsTruncated ? page.NextContinuationToken : undefined;
      } while (token);
      console.log(`[r2MirrorSweep] nettoyage : ${removed} fichiers retirés de R2`);
    }
  },
);
