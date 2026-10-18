import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { FieldValue } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { execFile } from "child_process";
import { promisify } from "util";
import { createHash, randomUUID } from "crypto";
import { tmpdir } from "os";
import { join } from "path";
import { promises as fs } from "fs";
import ffmpegPath from "ffmpeg-static";
import { db } from "../shared/firebase";
import { BER_SAME, BER_SIMILAR, bestMatch, fingerprint, fromBase64, toBase64 } from "./audioFingerprint";
import { normalizedCountries, storagePathFromUrl, tempListenUrl } from "./artistSounds";

/**
 * Protection des sons d'artistes.
 *
 * - L'original n'est jamais exposé : il est déposé dans `artist_sound_uploads/{uid}/…` (lisible par personne côté téléphone,
 *   règles Storage), et seul un extrait public de 30 s (`artist_sound_previews/{id}.m4a`, mono 80 kb/s) est visible.
 *   Le Studio lit l'original côté serveur ; l'administrateur l'écoute par un lien signé de 15 minutes.
 * - À chaque dépôt : empreinte SHA-256 (même fichier) + empreinte audio (même morceau ré-encodé ou recadré) comparées
 *   à tous les sons déjà en ligne. Même fichier = refus automatique ; morceau très proche = alerte pour l'administrateur.
 * - Suppression par l'artiste : confirmation stricte (retaper le titre exact), tout est effacé (fichiers, empreintes).
 * - Signalements : un par personne et par son ; à 3 signalements, le son est suspendu (retiré du Studio) en attendant l'admin.
 */
const run = promisify(execFile);
const bucket = () => getStorage().bucket();
const MAX_BYTES = 50 * 1024 * 1024;
const MIN_SEC = 8;
const MAX_SEC = 15 * 60;
const SUSPEND_AT = 3;

async function probe(file: string): Promise<{ duration: number | null; hasAudio: boolean }> {
  let text = "";
  try {
    await run(ffmpegPath as string, ["-hide_banner", "-i", file], { timeout: 30_000 });
  } catch (e) {
    text = String((e as { stderr?: string }).stderr ?? "");
  }
  const m = /Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)/.exec(text);
  const duration = m ? Number(m[1]) * 3600 + Number(m[2]) * 60 + Number(m[3]) : null;
  return { duration: duration != null && Number.isFinite(duration) ? duration : null, hasAudio: /Stream #\d+:\d+.*Audio:/.test(text) };
}

async function pcm8k(file: string): Promise<Int16Array> {
  const { stdout } = (await run(ffmpegPath as string, ["-v", "error", "-i", file, "-t", String(MAX_SEC), "-vn", "-ac", "1", "-ar", "8000", "-f", "s16le", "-"], {
    encoding: "buffer",
    maxBuffer: 64 * 1024 * 1024,
    timeout: 120_000,
  })) as unknown as { stdout: Buffer };
  const copy = stdout.buffer.slice(stdout.byteOffset, stdout.byteOffset + stdout.byteLength - (stdout.byteLength % 2));
  return new Int16Array(copy);
}

/** Durée de l'extrait gratuit selon la durée du titre : un quart du titre, entre 8 et 30 secondes (30 s pour un titre de 2 minutes ou plus). */
export function previewPlan(duration: number): { start: number; sec: number } {
  const sec = Math.min(30, Math.max(8, Math.round(duration * 0.25)));
  const start = duration > sec + 15 ? Math.min(duration * 0.25, duration - sec - 2) : 0;
  return { start, sec };
}

export type SoundDup = { id: string; title: string; artist: string; kind: "same_file" | "same_track" | "similar"; ber?: number };

/** Compare une empreinte à celles de tous les sons déjà enregistrés. */
export async function findDuplicates(selfId: string, sha: string, fp: Uint16Array): Promise<SoundDup[]> {
  const out: SoundDup[] = [];
  const snap = await db.collection("ArtistSoundPrints").limit(3000).get();
  for (const d of snap.docs) {
    if (d.id === selfId) continue;
    const p = d.data();
    const base = { id: d.id, title: String(p["title"] ?? ""), artist: String(p["artist"] ?? "") };
    if (p["sha256"] === sha) {
      out.push({ ...base, kind: "same_file" });
      continue;
    }
    if (!p["fp"] || fp.length < 120) continue;
    const m = bestMatch(fp, fromBase64(String(p["fp"])));
    if (m.ber < BER_SAME) out.push({ ...base, kind: "same_track", ber: Math.round(m.ber * 1000) / 1000 });
    else if (m.ber < BER_SIMILAR) out.push({ ...base, kind: "similar", ber: Math.round(m.ber * 1000) / 1000 });
  }
  return out.sort((a, b) => (a.ber ?? 0) - (b.ber ?? 0)).slice(0, 5);
}

/** Traite un son déposé : contrôle du fichier, doublons, extrait public de 30 s. */
export async function processArtistSound(id: string, data: FirebaseFirestore.DocumentData): Promise<void> {
  const ref = db.collection("artist_sounds").doc(id);
  if (data["processed"] === true) return;
  const uid = String(data["userId"] ?? "");
  let path = (data["audioPath"] as string | undefined) ?? storagePathFromUrl(String(data["audioUrl"] ?? ""));
  const legacy = !data["audioPath"];
  const dir = join(tmpdir(), `snd_${id}`);
  await fs.mkdir(dir, { recursive: true });
  const refuse = (reason: string, extra: Record<string, unknown> = {}) =>
    ref.update({ status: "refused", refusalReason: reason, processed: true, processedAt: Date.now(), ...extra });
  try {
    if (!path || (!legacy && !String(path).startsWith(`artist_sound_uploads/${uid}/`))) {
      await refuse("Fichier audio introuvable.");
      return;
    }
    let f = bucket().file(path);
    const [exists] = await f.exists();
    if (!exists) {
      await refuse("Fichier audio introuvable.");
      return;
    }
    const [meta] = await f.getMetadata();
    if (Number(meta.size) > MAX_BYTES) {
      await refuse("Fichier trop lourd (50 Mo maximum).");
      return;
    }
    const local = join(dir, "original");
    await f.download({ destination: local });
    const info = await probe(local);
    if (!info.hasAudio || info.duration == null) {
      await refuse("Ce fichier n'est pas un son lisible.");
      return;
    }
    if (info.duration < MIN_SEC || info.duration > MAX_SEC) {
      await refuse(`Durée non acceptée (entre ${MIN_SEC} secondes et ${MAX_SEC / 60} minutes).`);
      return;
    }
    const buf = await fs.readFile(local);
    const sha = createHash("sha256").update(buf).digest("hex");
    const fp = fingerprint(await pcm8k(local));
    const dups = await findDuplicates(id, sha, fp);

    // Ancien dépôt (lien public) : l'original passe dans le dossier privé et l'ancien fichier est effacé
    if (legacy) {
      const ext = String(path).includes(".") ? String(path).split(".").pop() : "mp3";
      const priv = `artist_sound_uploads/${uid}/legacy_${id}.${ext}`;
      await f.copy(bucket().file(priv));
      await f.delete({ ignoreNotFound: true });
      path = priv;
      f = bucket().file(priv);
    }

    // Extrait public (jamais l'original) : sa durée dépend de celle du titre (un son de 30 s n'est pas offert en entier)
    const { start, sec: previewSec } = previewPlan(info.duration);
    const prev = join(dir, "preview.m4a");
    await run(ffmpegPath as string, [
      "-y", "-loglevel", "error", "-ss", start.toFixed(2), "-t", String(previewSec), "-i", local, "-vn", "-ac", "1", "-ar", "44100",
      "-af", `afade=t=in:st=0:d=0.5,afade=t=out:st=${Math.max(0, previewSec - 1.5).toFixed(1)}:d=1.5`, "-c:a", "aac", "-b:a", "80k", "-movflags", "+faststart", prev,
    ], { timeout: 120_000 });
    const previewPath = `artist_sound_previews/${id}.m4a`;
    const token = randomUUID();
    await bucket().file(previewPath).save(await fs.readFile(prev), {
      contentType: "audio/mp4",
      metadata: { metadata: { firebaseStorageDownloadTokens: token }, cacheControl: "public, max-age=31536000" },
    });
    const previewUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket().name}/o/${encodeURIComponent(previewPath)}?alt=media&token=${token}`;

    await db.collection("ArtistSoundPrints").doc(id).set({
      sha256: sha, fp: toBase64(fp), frames: fp.length, owner: uid, title: String(data["title"] ?? ""), artist: String(data["userPseudo"] ?? ""), createdAt: Date.now(),
    });

    const same = dups.find((d) => d.kind === "same_file");
    const update: Record<string, unknown> = {
      audioPath: path, previewUrl, previewStart: start, previewSec, durationMs: Math.round(info.duration * 1000), audioSha256: sha,
      duplicates: dups, processed: true, processedAt: Date.now(),
      audioUrl: FieldValue.delete(), // l'ancien lien public n'existe plus
      availableCountries: await normalizedCountries(uid, data["availableCountries"]), // grille des posts (1 / 20 / tous)
    };
    if (same) {
      update["status"] = "refused";
      update["refusalReason"] = `Ce fichier existe déjà sur Afrolook (« ${same.title} » de @${same.artist}).`;
    }
    await ref.update(update);
  } catch (e) {
    console.error("[processArtistSound]", id, e);
    await ref.update({ processed: "error", processedAt: Date.now() }).catch(() => undefined);
  } finally {
    await fs.rm(dir, { recursive: true, force: true }).catch(() => undefined);
  }
}

/** Refait l'extrait public d'un son déjà validé avec la durée calculée d'après celle du titre (anciens sons : extrait fixe de 30 s). */
export async function rebuildPreview(id: string): Promise<{ ok: boolean; sec?: number; reason?: string }> {
  const ref = db.collection("artist_sounds").doc(id);
  const snap = await ref.get();
  const data = snap.data();
  if (!data || !data["audioPath"]) return { ok: false, reason: "pas de fichier original" };
  const dir = join(tmpdir(), `prev_${id}`);
  await fs.mkdir(dir, { recursive: true });
  try {
    const local = join(dir, "original");
    await bucket().file(String(data["audioPath"])).download({ destination: local });
    const info = await probe(local);
    if (!info.hasAudio || info.duration == null) return { ok: false, reason: "fichier illisible" };
    const { start, sec } = previewPlan(info.duration);
    const prev = join(dir, "preview.m4a");
    await run(ffmpegPath as string, [
      "-y", "-loglevel", "error", "-ss", start.toFixed(2), "-t", String(sec), "-i", local, "-vn", "-ac", "1", "-ar", "44100",
      "-af", `afade=t=in:st=0:d=0.5,afade=t=out:st=${Math.max(0, sec - 1.5).toFixed(1)}:d=1.5`, "-c:a", "aac", "-b:a", "80k", "-movflags", "+faststart", prev,
    ], { timeout: 120_000 });
    const previewPath = `artist_sound_previews/${id}.m4a`;
    const token = randomUUID();
    await bucket().file(previewPath).save(await fs.readFile(prev), {
      contentType: "audio/mp4",
      metadata: { metadata: { firebaseStorageDownloadTokens: token }, cacheControl: "public, max-age=31536000" },
    });
    const previewUrl = `https://firebasestorage.googleapis.com/v0/b/${bucket().name}/o/${encodeURIComponent(previewPath)}?alt=media&token=${token}`;
    await ref.update({ previewUrl, previewStart: start, previewSec: sec, durationMs: Math.round(info.duration * 1000) });
    return { ok: true, sec };
  } catch (e) {
    return { ok: false, reason: String(e) };
  } finally {
    await fs.rm(dir, { recursive: true, force: true }).catch(() => undefined);
  }
}

/** Dès qu'un son est déposé : analyse automatique. */
export const onArtistSoundCreated = onDocumentCreated(
  { document: "artist_sounds/{id}", memory: "1GiB", timeoutSeconds: 300, cpu: 1, maxInstances: 3 },
  async (event) => {
    const data = event.data?.data();
    if (data) await processArtistSound(event.params.id, data);
  },
);

/** Suppression par l'artiste (ou un admin) : l'artiste doit retaper le titre exact. */
export const artistSoundDelete = onCall({ timeoutSeconds: 60, memory: "256MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const { soundId, confirm } = (request.data ?? {}) as { soundId?: string; confirm?: string };
  if (!soundId || !/^[A-Za-z0-9_-]{4,64}$/.test(soundId)) throw new HttpsError("invalid-argument", "Son invalide.");
  const ref = db.collection("artist_sounds").doc(soundId);
  const snap = await ref.get();
  if (!snap.exists) throw new HttpsError("not-found", "Son introuvable.");
  const s = snap.data()!;
  const isAdmin = (await db.collection("Users").doc(uid).get()).get("role") === "ADM";
  if (s["userId"] !== uid && !isAdmin) throw new HttpsError("permission-denied", "Ce son n'est pas à toi.");
  if (s["userId"] === uid && String(confirm ?? "") !== String(s["title"] ?? "")) {
    throw new HttpsError("failed-precondition", "CONFIRMATION_INVALIDE");
  }
  const paths = [s["audioPath"], storagePathFromUrl(String(s["audioUrl"] ?? "")), `artist_sound_previews/${soundId}.m4a`, storagePathFromUrl(String(s["coverImageUrl"] ?? ""))];
  for (const p of paths) if (p) await bucket().file(String(p)).delete({ ignoreNotFound: true }).catch(() => undefined);
  await db.collection("ArtistSoundPrints").doc(soundId).delete().catch(() => undefined);
  await db.collection("ArtistSoundDeletions").add({
    soundId, title: s["title"] ?? "", userId: s["userId"] ?? "", usageCount: s["usageCount"] ?? 0, by: uid, at: Date.now(),
  });
  await ref.delete();
  return { ok: true };
});

/** Lien signé de 15 minutes vers l'original, pour l'écoute de l'administrateur avant validation. */
export const artistSoundAdminUrl = onCall({ timeoutSeconds: 120, memory: "512MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  if ((await db.collection("Users").doc(uid).get()).get("role") !== "ADM") throw new HttpsError("permission-denied", "Réservé aux administrateurs.");
  const soundId = String((request.data as { soundId?: string })?.soundId ?? "");
  const snap = await db.collection("artist_sounds").doc(soundId).get();
  if (!snap.exists) throw new HttpsError("not-found", "Son introuvable.");
  const path = (snap.get("audioPath") as string | undefined) ?? storagePathFromUrl(String(snap.get("audioUrl") ?? ""));
  if (!path) throw new HttpsError("not-found", "Fichier introuvable.");
  const url = await tempListenUrl(path);
  return { url };
});

const REASONS = new Set(["copyright", "stolen", "offensive", "spam", "other"]);

/** Signalement d'un son (Studio, page des musiques) : un par personne ; à 3, le son est suspendu en attendant l'admin. */
export const artistSoundReport = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const { soundId, reason, note } = (request.data ?? {}) as { soundId?: string; reason?: string; note?: string };
  if (!soundId || !/^[A-Za-z0-9_-]{4,64}$/.test(soundId) || !REASONS.has(String(reason))) throw new HttpsError("invalid-argument", "Signalement invalide.");
  const soundRef = db.collection("artist_sounds").doc(soundId);
  const repRef = db.collection("ArtistSoundReports").doc(`${uid}_${soundId}`);
  return db.runTransaction(async (tx) => {
    const [s, r] = await Promise.all([tx.get(soundRef), tx.get(repRef)]);
    if (!s.exists) throw new HttpsError("not-found", "Son introuvable.");
    if (s.get("userId") === uid) throw new HttpsError("failed-precondition", "C'est ton propre son.");
    if (r.exists) return { ok: true, already: true };
    const count = Number(s.get("reportCount") ?? 0) + 1;
    tx.set(repRef, { uid, soundId, artistId: s.get("userId") ?? "", reason, note: String(note ?? "").slice(0, 300), at: Date.now() });
    const upd: Record<string, FirebaseFirestore.FieldValue | string | number> = { reportCount: count, lastReportAt: Date.now() };
    if (count >= SUSPEND_AT && s.get("status") === "validated") {
      upd["status"] = "suspended";
      upd["suspendedAt"] = Date.now();
    }
    tx.update(soundRef, upd);
    return { ok: true, suspended: upd["status"] === "suspended" };
  });
});

/**
 * Relie un post à un son d'artiste utilisé dans son montage : le serveur vérifie que la personne a bien fait ce montage
 * (ArtistSoundUses/{uid}_{jobId} écrit par renderStudioMontage) et que le post est le sien. Un téléphone ne peut pas
 * écrire `artistSoundId` lui-même (règles Firestore), donc la liste « posts faits avec ce son » ne se falsifie pas.
 */
export const artistSoundLinkPost = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const { postId, jobId } = (request.data ?? {}) as { postId?: string; jobId?: string };
  if (!postId || !jobId || !/^[A-Za-z0-9_-]{8,40}$/.test(jobId) || postId.includes("/")) throw new HttpsError("invalid-argument", "Données invalides.");
  const useRef = db.collection("ArtistSoundUses").doc(`${uid}_${jobId}`);
  const postRef = db.collection("Posts").doc(postId);
  return db.runTransaction(async (tx) => {
    const [use, post] = await Promise.all([tx.get(useRef), tx.get(postRef)]);
    if (!use.exists) throw new HttpsError("failed-precondition", "Montage introuvable.");
    if (!post.exists || post.get("user_id") !== uid) throw new HttpsError("permission-denied", "Ce post n'est pas à toi.");
    if (use.get("postId")) return { ok: true, already: true };
    const soundId = String(use.get("soundId") ?? "");
    const soundRef = db.collection("artist_sounds").doc(soundId);
    const sound = await tx.get(soundRef);
    if (!sound.exists) throw new HttpsError("not-found", "Son introuvable.");
    tx.update(postRef, { artistSoundId: soundId, artistSoundTitle: String(sound.get("title") ?? "") });
    tx.update(useRef, { postId });
    tx.update(soundRef, { postCount: FieldValue.increment(1) });
    return { ok: true, soundId };
  });
});

/** Change les pays d'un titre (l'artiste, selon son abonnement : 1 pays, 20 pour Premium, tous pour Gold). */
export const artistSoundCountries = onCall({ timeoutSeconds: 30, memory: "256MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const { soundId, countries } = (request.data ?? {}) as { soundId?: string; countries?: unknown };
  if (!soundId || !/^[A-Za-z0-9_-]{4,64}$/.test(soundId)) throw new HttpsError("invalid-argument", "Son invalide.");
  const ref = db.collection("artist_sounds").doc(soundId);
  const snap = await ref.get();
  if (!snap.exists || snap.get("userId") !== uid) throw new HttpsError("permission-denied", "Ce n'est pas ton son.");
  const list = await normalizedCountries(uid, countries);
  await ref.update({ availableCountries: list });
  return { ok: true, countries: list };
});
