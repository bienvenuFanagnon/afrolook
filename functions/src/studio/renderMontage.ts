import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getStorage } from "firebase-admin/storage";
import { execFile } from "child_process";
import { promisify } from "util";
import { randomUUID } from "crypto";
import { tmpdir } from "os";
import { join } from "path";
import { promises as fs } from "fs";
import ffmpegPath from "ffmpeg-static";

/**
 * Montage animé du Studio : assemble une vidéo MP4 prête à publier.
 * Le client envoie dans studio_uploads/{uid}/{jobId}/ :
 *   base.jpg (photo + teintes) ou base.mp4 (vidéo de l'utilisateur),
 *   under.png (teintes, vidéo seulement), fx_000.png… (effet animé en boucle), top.png (textes, cadre, logo, filigrane).
 * Ordre des calques : base → under → fx → top.
 */
const run = promisify(execFile);
const bucket = () => getStorage().bucket();
const MAX_FX_FRAMES = 60;
const MAX_INPUT_BYTES = 60 * 1024 * 1024;

type Req = {
  jobId?: string;
  baseType?: "image" | "video";
  fxFrames?: number;
  fxFps?: number;
  format?: "story" | "post";
  maxSeconds?: number;
  saturation?: number;
  brightness?: number;
  hasUnder?: boolean;
};

const clamp = (v: unknown, lo: number, hi: number, d: number) => {
  const n = Number(v);
  return Number.isFinite(n) ? Math.min(hi, Math.max(lo, n)) : d;
};

export type MontageArgs = {
  baseType: "image" | "video";
  base: string;
  top: string;
  under: string | null;
  fxPattern: string | null;
  fxFrames: number;
  fxFps: number;
  W: number;
  H: number;
  maxSeconds: number;
  sat: number;
  bri: number;
  out: string;
};

/** Arguments ffmpeg du montage (calques : base → under → fx en boucle → top). */
export function buildMontageArgs(o: MontageArgs): string[] {
  const loopSec = o.fxFrames > 0 ? o.fxFrames / o.fxFps : 3;
  const imageSeconds = Math.min(8, Math.max(5, loopSec * 2));
  const args: string[] = ["-y"];
  if (o.baseType === "video") args.push("-i", o.base);
  else args.push("-loop", "1", "-framerate", "30", "-t", String(imageSeconds), "-i", o.base);
  args.push("-loop", "1", "-framerate", "30", "-i", o.top);
  let idx = 2;
  let underIdx = -1;
  let fxIdx = -1;
  let silentIdx = -1;
  if (o.under) { args.push("-loop", "1", "-framerate", "30", "-i", o.under); underIdx = idx++; }
  if (o.fxPattern && o.fxFrames > 0) { args.push("-framerate", String(o.fxFps), "-i", o.fxPattern); fxIdx = idx++; }
  if (o.baseType === "image") { args.push("-f", "lavfi", "-i", "anullsrc=r=44100:cl=stereo"); silentIdx = idx++; }

  const { W, H } = o;
  const color = o.baseType === "video" && (o.sat !== 1 || o.bri !== 0) ? `,eq=saturation=${o.sat}:brightness=${o.bri}` : "";
  const chain: string[] = [
    `[0:v]scale=${W}:${H}:force_original_aspect_ratio=increase,crop=${W}:${H},setsar=1,fps=30${color},format=yuv420p[b0]`,
  ];
  let cur = "b0";
  if (underIdx >= 0) {
    chain.push(`[${underIdx}:v]scale=${W}:${H},format=rgba[u]`, `[${cur}][u]overlay=0:0:shortest=1[b1]`);
    cur = "b1";
  }
  if (fxIdx >= 0) {
    chain.push(
      `[${fxIdx}:v]loop=loop=-1:size=${o.fxFrames}:start=0,setpts=N/(${o.fxFps}*TB),scale=${W}:${H},fps=30,format=rgba[f]`,
      `[${cur}][f]overlay=0:0:shortest=1[b2]`,
    );
    cur = "b2";
  }
  chain.push(`[1:v]scale=${W}:${H},format=rgba[t]`, `[${cur}][t]overlay=0:0:shortest=1,format=yuv420p[v]`);

  args.push("-filter_complex", chain.join(";"), "-map", "[v]");
  if (o.baseType === "video") args.push("-map", "0:a?");
  else args.push("-map", `${silentIdx}:a`, "-shortest");
  args.push(
    "-t", String(o.baseType === "video" ? o.maxSeconds : imageSeconds),
    "-r", "30", "-c:v", "libx264", "-preset", "veryfast", "-crf", "23", "-pix_fmt", "yuv420p",
    "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart", o.out,
  );
  return args;
}

export const renderStudioMontage = onCall(
  { timeoutSeconds: 300, memory: "2GiB", cpu: 2, maxInstances: 5, concurrency: 1, region: "us-central1" },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "auth_required");
    if (!ffmpegPath) throw new HttpsError("unavailable", "Montage indisponible.");

    const d = (request.data ?? {}) as Req;
    const jobId = String(d.jobId ?? "");
    if (!/^[A-Za-z0-9_-]{8,40}$/.test(jobId)) throw new HttpsError("invalid-argument", "jobId invalide.");
    const baseType = d.baseType === "video" ? "video" : "image";
    const fxFrames = Math.round(clamp(d.fxFrames, 0, MAX_FX_FRAMES, 0));
    const fxFps = Math.round(clamp(d.fxFps, 1, 30, 10));
    const post = d.format === "post";
    const W = 720;
    const H = post ? 900 : 1280;
    const maxSeconds = clamp(d.maxSeconds, 3, 60, 30);
    const sat = clamp(d.saturation, 0, 2, 1);
    const bri = clamp(d.brightness, -0.5, 0.5, 0);

    const prefix = `studio_uploads/${uid}/${jobId}/`;
    const dir = join(tmpdir(), `mtg_${jobId}`);
    await fs.mkdir(dir, { recursive: true });

    const get = async (name: string, required: boolean) => {
      const f = bucket().file(prefix + name);
      const [exists] = await f.exists();
      if (!exists) {
        if (required) throw new HttpsError("not-found", `Fichier manquant : ${name}`);
        return null;
      }
      const [meta] = await f.getMetadata();
      if (Number(meta.size) > MAX_INPUT_BYTES) throw new HttpsError("invalid-argument", "Fichier trop lourd.");
      const dest = join(dir, name);
      await f.download({ destination: dest });
      return dest;
    };

    try {
      const base = await get(baseType === "video" ? "base.mp4" : "base.jpg", true);
      const top = await get("top.png", true);
      const under = baseType === "video" && d.hasUnder ? await get("under.png", false) : null;
      const fxNames = Array.from({ length: fxFrames }, (_, i) => `fx_${String(i).padStart(3, "0")}.png`);
      await Promise.all(fxNames.map((n) => get(n, true)));

      const out = join(dir, "out.mp4");
      const args = buildMontageArgs({
        baseType, base: base!, top: top!, under,
        fxPattern: fxFrames > 0 ? join(dir, "fx_%03d.png") : null, fxFrames, fxFps,
        W, H, maxSeconds, sat, bri, out,
      });
      await run(ffmpegPath as string, args, { timeout: 240_000, maxBuffer: 16 * 1024 * 1024 });

      const buf = await fs.readFile(out);
      const finalPath = `studio_renders/${uid}/${jobId}.mp4`;
      const token = randomUUID();
      await bucket().file(finalPath).save(buf, {
        contentType: "video/mp4",
        metadata: { metadata: { firebaseStorageDownloadTokens: token } },
      });
      const url = `https://firebasestorage.googleapis.com/v0/b/${bucket().name}/o/${encodeURIComponent(finalPath)}?alt=media&token=${token}`;
      return { url, path: finalPath, sizeBytes: buf.length };
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      console.error("[renderStudioMontage]", e);
      throw new HttpsError("internal", "Le montage a échoué. Réessaie dans un instant.");
    } finally {
      await bucket().deleteFiles({ prefix }).catch(() => undefined);
      await fs.rm(dir, { recursive: true, force: true }).catch(() => undefined);
    }
  },
);
