import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getStorage } from "firebase-admin/storage";
import { execFile } from "child_process";
import { promisify } from "util";
import { randomUUID } from "crypto";
import { tmpdir } from "os";
import { join } from "path";
import { promises as fs } from "fs";
import ffmpegPath from "ffmpeg-static";
import sharp from "sharp";
import { db } from "../shared/firebase";
import { MAX_ANIM_BYTES, tierOf } from "./stickers";

/**
 * Conversion d'une vidéo courte (≤ 3 s, ≤ 3 Mo) en sticker animé personnel (WebP animé en boucle, sans son, ≤ 600 Ko).
 * Le client envoie la vidéo dans sticker_video_uploads/{uid}/… puis appelle ce callable ; le serveur crée le doc
 * UserStickers (quota Premium 10 / Gold 50) et supprime la vidéo d'origine.
 */
const run = promisify(execFile);
const MAX_VIDEO_BYTES = 3 * 1024 * 1024;
const QUOTA: Record<string, number> = { premium: 10, gold: 50 };
const bucket = () => getStorage().bucket();

export const convertStickerVideo = onCall({ timeoutSeconds: 180, memory: "1GiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const path = String((request.data as { path?: string })?.path ?? "");
  if (!path.startsWith(`sticker_video_uploads/${uid}/`)) throw new HttpsError("invalid-argument", "Chemin refusé.");
  if (!ffmpegPath) throw new HttpsError("unavailable", "Conversion indisponible.");

  const user = (await db.collection("Users").doc(uid).get()).data();
  const tier = tierOf(user);
  if (tier === "free") throw new HttpsError("permission-denied", "Réservé aux abonnés Premium et Gold.");
  const mine = await db.collection("UserStickers").where("ownerId", "==", uid).limit(60).get();
  if (mine.docs.filter((d) => d.get("status") !== "removed").length >= (QUOTA[tier] ?? 0)) {
    throw new HttpsError("resource-exhausted", "Tu as atteint le nombre maximum de stickers personnels.");
  }

  const src = bucket().file(path);
  const [meta] = await src.getMetadata().catch(() => { throw new HttpsError("not-found", "Vidéo introuvable."); });
  if (!Number(meta.size) || Number(meta.size) > MAX_VIDEO_BYTES) {
    await src.delete({ ignoreNotFound: true });
    throw new HttpsError("invalid-argument", "Vidéo trop lourde (3 Mo maximum).");
  }

  const id = randomUUID().replace(/-/g, "").slice(0, 20);
  const dir = join(tmpdir(), `stk_${id}`);
  await fs.mkdir(dir, { recursive: true });
  const input = join(dir, "in.mp4");
  const output = join(dir, "out.webp");
  try {
    await src.download({ destination: input });
    // Qualité décroissante jusqu'à passer sous 600 Ko
    let size = Infinity;
    for (const q of [65, 50, 38, 28]) {
      await run(ffmpegPath as string, [
        "-y", "-t", "3", "-i", input,
        "-vf", "fps=12,scale=360:360:force_original_aspect_ratio=increase,crop=360:360",
        "-an", "-loop", "0", "-c:v", "libwebp_anim", "-quality", String(q), "-compression_level", "6", output,
      ], { timeout: 120_000 });
      size = (await fs.stat(output)).size;
      if (size <= MAX_ANIM_BYTES) break;
    }
    if (size > MAX_ANIM_BYTES) throw new HttpsError("invalid-argument", "Impossible d'alléger cette vidéo sous 600 Ko : choisis une scène plus simple ou plus courte.");

    const buf = await fs.readFile(output);
    const thumb = await sharp(buf, { page: 0 }).resize(256, 256, { fit: "inside" }).webp({ quality: 70 }).toBuffer();
    const finalPath = `user_stickers/${uid}/${id}.webp`;
    const thumbPath = `user_stickers/${uid}/${id}_thumb.webp`;
    const token = randomUUID();
    const thumbToken = randomUUID();
    await bucket().file(finalPath).save(buf, { contentType: "image/webp", metadata: { metadata: { firebaseStorageDownloadTokens: token } } });
    await bucket().file(thumbPath).save(thumb, { contentType: "image/webp", metadata: { metadata: { firebaseStorageDownloadTokens: thumbToken } } });
    const url = (p: string, t: string) => `https://firebasestorage.googleapis.com/v0/b/${bucket().name}/o/${encodeURIComponent(p)}?alt=media&token=${t}`;
    // Le doc est créé directement actif : la conversion a déjà validé poids et quota
    await db.collection("UserStickers").doc(id).set({
      ownerId: uid, storagePath: finalPath, url: url(finalPath, token), thumbUrl: url(thumbPath, thumbToken),
      sizeBytes: size, animated: true, durationMs: 3000, source: "video", status: "active", createdAt: Date.now(),
    });
    return { stickerId: id, sizeBytes: size };
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    console.error("[convertStickerVideo]", e);
    throw new HttpsError("internal", "La conversion a échoué. Réessaie avec une autre vidéo.");
  } finally {
    await src.delete({ ignoreNotFound: true }).catch(() => undefined);
    await fs.rm(dir, { recursive: true, force: true }).catch(() => undefined);
  }
});
