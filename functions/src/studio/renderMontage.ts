import { onCall, HttpsError } from "firebase-functions/v2/https";
import { getStorage } from "firebase-admin/storage";
import { execFile } from "child_process";
import { promisify } from "util";
import { randomUUID } from "crypto";
import { tmpdir } from "os";
import { join } from "path";
import { promises as fs } from "fs";
import ffmpegPath from "ffmpeg-static";
import { ArtistSoundInfo, chargeArtistSound, downloadArtistSound, prepareArtistSound } from "./artistSounds";

/**
 * Montage animé du Studio : assemble une vidéo MP4 prête à publier.
 * Le client envoie dans studio_uploads/{uid}/{jobId}/ :
 *   base.jpg (photo + teintes) ou base.mp4 (vidéo de l'utilisateur),
 *   under.png (teintes, vidéo seulement), fx_000.png… (effet animé en boucle), top.png (textes, cadre, logo, filigrane).
 * Ordre des calques : base → under → fx → top.
 * Musique (facultative) : piste gratuite du Studio (Storage studio_music/{id}.m4a) ou son d'artiste validé (payant,
 * débité seulement si le montage réussit). Avec une photo, la musique transforme le montage en vidéo de [seconds] s.
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
  music?: { type?: "free" | "artist"; id?: string; startMs?: number; volume?: number } | null;
  keepAudio?: boolean;
  seconds?: number;
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
  /** Musique : fichier, début (s), volume 0..1. */
  music?: string | null;
  musicStart?: number;
  musicVolume?: number;
  /** Vidéo de base : garder son propre son sous la musique. */
  keepAudio?: boolean;
  baseHasAudio?: boolean;
  /** Durée de la vidéo de base (s), si connue. */
  baseDuration?: number | null;
  /** Durée voulue quand la base est une photo (sinon calculée d'après l'effet). */
  seconds?: number | null;
};

/** Durée finale du montage (s). */
export function montageDuration(o: MontageArgs): number {
  const loopSec = o.fxFrames > 0 ? o.fxFrames / o.fxFps : 3;
  if (o.baseType === "video") return o.baseDuration && o.baseDuration > 0 ? Math.min(o.baseDuration, o.maxSeconds) : o.maxSeconds;
  if (o.seconds && o.seconds > 0) return Math.min(o.maxSeconds, o.seconds);
  return Math.min(8, Math.max(5, loopSec * 2));
}

/** Arguments ffmpeg du montage (calques : base → under → fx en boucle → top). */
export function buildMontageArgs(o: MontageArgs): string[] {
  const D = Math.round(montageDuration(o) * 100) / 100;
  const imageSeconds = D;
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
  let musicIdx = -1;
  if (o.music) { args.push("-stream_loop", "-1", "-ss", String(Math.max(0, o.musicStart ?? 0)), "-i", o.music); musicIdx = idx++; }
  if (o.baseType === "image" && musicIdx < 0) { args.push("-f", "lavfi", "-i", "anullsrc=r=44100:cl=stereo"); silentIdx = idx++; }

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

  let audioMap: string | null = null;
  if (musicIdx >= 0) {
    const vol = Math.max(0, Math.min(1, o.musicVolume ?? 1));
    const fadeOut = Math.min(1.5, D / 4);
    chain.push(
      `[${musicIdx}:a]aformat=sample_rates=44100:channel_layouts=stereo,atrim=0:${D},asetpts=PTS-STARTPTS,` +
        `afade=t=in:st=0:d=0.3,afade=t=out:st=${Math.max(0, D - fadeOut).toFixed(2)}:d=${fadeOut.toFixed(2)},volume=${vol}[mus]`,
    );
    if (o.baseType === "video" && o.keepAudio && o.baseHasAudio) {
      chain.push(`[0:a]aformat=sample_rates=44100:channel_layouts=stereo,volume=0.9[va]`, `[va][mus]amix=inputs=2:duration=longest:normalize=0,alimiter=limit=0.95[a]`);
    } else {
      chain.push(`[mus]anull[a]`);
    }
    audioMap = "[a]";
  }

  args.push("-filter_complex", chain.join(";"), "-map", "[v]");
  if (audioMap) args.push("-map", audioMap);
  else if (o.baseType === "video") args.push("-map", "0:a?");
  else args.push("-map", `${silentIdx}:a`, "-shortest");
  args.push(
    "-t", String(o.baseType === "video" && !o.baseDuration ? o.maxSeconds : imageSeconds),
    "-r", "30", "-c:v", "libx264", "-preset", "veryfast", "-crf", "23", "-pix_fmt", "yuv420p",
    "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart", o.out,
  );
  return args;
}

/** Durée et présence d'une piste son (lecture de l'en-tête par ffmpeg, sans ffprobe). */
async function probeMedia(file: string): Promise<{ duration: number | null; hasAudio: boolean }> {
  let text = "";
  try {
    await run(ffmpegPath as string, ["-hide_banner", "-i", file], { timeout: 20_000 });
  } catch (e) {
    text = String((e as { stderr?: string }).stderr ?? "");
  }
  const m = /Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)/.exec(text);
  const duration = m ? Number(m[1]) * 3600 + Number(m[2]) * 60 + Number(m[3]) : null;
  return { duration: duration && Number.isFinite(duration) ? duration : null, hasAudio: /Stream #\d+:\d+.*Audio:/.test(text) };
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
    const seconds = d.seconds == null ? null : clamp(d.seconds, 3, 60, 15);
    const mReq = d.music && typeof d.music === "object" ? d.music : null;
    const musicType = mReq?.type === "artist" ? "artist" : mReq?.type === "free" ? "free" : null;
    const musicId = String(mReq?.id ?? "");
    if (musicType === "free" && !/^[a-z0-9_]{2,40}$/.test(musicId)) throw new HttpsError("invalid-argument", "Musique invalide.");
    // son d'artiste : vérifié (validé, solde suffisant) avant tout travail
    const artist: ArtistSoundInfo | null = musicType === "artist" ? await prepareArtistSound(uid, musicId) : null;

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

      let music: string | null = null;
      if (musicType === "free") {
        music = join(dir, "music.m4a");
        const f = bucket().file(`studio_music/${musicId}.m4a`);
        const [exists] = await f.exists();
        if (!exists) throw new HttpsError("not-found", "Musique introuvable.");
        await f.download({ destination: music });
      } else if (artist) {
        music = join(dir, "music_artist");
        await downloadArtistSound(artist, music, MAX_INPUT_BYTES);
      }
      const probe = baseType === "video" ? await probeMedia(base!) : { duration: null, hasAudio: false };

      const out = join(dir, "out.mp4");
      const args = buildMontageArgs({
        baseType, base: base!, top: top!, under,
        fxPattern: fxFrames > 0 ? join(dir, "fx_%03d.png") : null, fxFrames, fxFps,
        W, H, maxSeconds, sat, bri, out,
        music, musicStart: clamp(mReq?.startMs, 0, 600000, 0) / 1000, musicVolume: clamp(mReq?.volume, 0, 1, 1),
        keepAudio: d.keepAudio === true, baseHasAudio: probe.hasAudio, baseDuration: probe.duration,
        seconds: music ? (seconds ?? 15) : seconds,
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
      const paid = artist ? await chargeArtistSound(uid, artist, jobId) : 0;
      return { url, path: finalPath, sizeBytes: buf.length, paidCoins: paid };
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
