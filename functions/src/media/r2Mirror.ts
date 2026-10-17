import { onObjectFinalized, onObjectDeleted, onObjectMetadataUpdated } from "firebase-functions/v2/storage";
import { defineSecret } from "firebase-functions/params";
import { S3Client, PutObjectCommand, HeadObjectCommand, DeleteObjectCommand } from "@aws-sdk/client-s3";
import { getStorage } from "firebase-admin/storage";
import "../shared/firebase";

/**
 * Miroir des médias vers Cloudflare R2 (stockage sans frais de sortie).
 *
 * Chaque fichier envoyé à Firebase Storage est recopié à l'identique (même chemin) dans le compartiment R2 `afrolook-media`,
 * avec son jeton de téléchargement en métadonnée : le Worker du CDN (cdn.afrolookmedia.com) lit R2 en priorité, vérifie le jeton
 * du lien, et retombe sur Firebase Storage si le fichier n'est pas (encore) dans R2. Un fichier supprimé de Storage est supprimé de R2.
 * L'application continue d'envoyer vers Firebase Storage : aucune version à publier.
 */
const R2_ACCESS_KEY_ID = defineSecret("R2_ACCESS_KEY_ID");
const R2_SECRET_ACCESS_KEY = defineSecret("R2_SECRET_ACCESS_KEY");
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
    credentials: { accessKeyId: R2_ACCESS_KEY_ID.value(), secretAccessKey: R2_SECRET_ACCESS_KEY.value() },
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

const opts = { bucket: BUCKET, secrets: [R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY], memory: "512MiB" as const, timeoutSeconds: 300, maxInstances: 10 };

export const r2MirrorOnUpload = onObjectFinalized(opts, async (event) => {
  await mirror(event.data.name);
});

/** Le jeton de téléchargement peut être posé ou renouvelé après l'envoi : on remet R2 à jour. */
export const r2MirrorOnMetadata = onObjectMetadataUpdated({ ...opts, memory: "512MiB" }, async (event) => {
  await mirror(event.data.name);
});

export const r2MirrorOnDelete = onObjectDeleted({ bucket: BUCKET, secrets: [R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY], memory: "256MiB", maxInstances: 10 }, async (event) => {
  const name = event.data.name;
  if (!shouldMirror(name)) return;
  await client().send(new DeleteObjectCommand({ Bucket: R2_BUCKET, Key: name }));
});
