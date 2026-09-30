import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { getStorage } from "firebase-admin/storage";
import { FieldValue } from "firebase-admin/firestore";
import { createHash, randomUUID } from "crypto";
import sharp from "sharp";
import { db } from "../shared/firebase";
import { num } from "../payments/coinShares";
import { MAX_ANIM_BYTES, tierOf } from "./stickers";
import { notifyOwner } from "../posts/canalInactivity";

/**
 * Stickers personnels (« Mes stickers ») et packs de créateurs, avec protection contre les copies.
 * Voir docs/STICKERS_SPEC.md et la page des règles de l'app.
 *
 * - UserStickers : quota Premium 10 / Gold 50, poids ≤ 600 Ko, fichiers dans user_stickers/{uid}/.
 * - submitStickerPack : un créateur éligible dépose 4 à 24 stickers ; chaque fichier est contrôlé (poids, image
 *   valide), reçoit une empreinte exacte (SHA-256) et une empreinte visuelle (dHash de 2 images) comparées à tous
 *   les stickers publiés. Une copie exacte est refusée ; une copie proche part en vérification manuelle.
 * - adminStickerAction : validation / refus / retrait d'un pack ou d'un sticker par un admin (journalisé).
 * - reportStickerCopy : signalement d'une copie par n'importe quel utilisateur.
 */
const MAX_PERSONAL: Record<string, number> = { premium: 10, gold: 50 };
const MIN_STICKERS = 4;
const MAX_STICKERS = 24;
const MAX_PRICE = 1000;
const HAMMING_NEAR = 8; // sur 64 bits : en dessous, le dessin est considéré comme très proche
const REGIONS = ["universal", "africa", "caribbean", "europe", "asia", "latam", "mena"];
const CATEGORIES = ["joie", "reussite", "compliments", "amour", "surprise", "taquinerie", "soutien", "colere", "reponses", "contenus", "fetes", "sport", "musique", "afrolook", "humeur"];
const LANGS = ["fr", "en", "es", "de", "ar", "pt", "zh", "sw"];

const bucket = () => getStorage().bucket();

function tokenUrl(path: string, token: string): string {
  return `https://firebasestorage.googleapis.com/v0/b/${bucket().name}/o/${encodeURIComponent(path)}?alt=media&token=${token}`;
}

async function requireAdmin(uid: string | undefined) {
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const a = await db.collection("Users").doc(uid).get();
  if (a.data()?.["role"] !== "ADM") throw new HttpsError("permission-denied", "Réservé aux admins.");
}

// ── Empreintes ───────────────────────────────────────────────────────────────

/** dHash 64 bits (différences de luminosité sur une grille 9×8) d'une image, en hexadécimal. */
async function dHash(input: Buffer, page: number): Promise<string> {
  const { data } = await sharp(input, { page, animated: false }).grayscale().resize(9, 8, { fit: "fill" }).raw().toBuffer({ resolveWithObject: true });
  let bits = "";
  for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) bits += data[y * 9 + x] > data[y * 9 + x + 1] ? "1" : "0";
  let hex = "";
  for (let i = 0; i < 64; i += 4) hex += parseInt(bits.slice(i, i + 4), 2).toString(16);
  return hex;
}

function hamming(a: string, b: string): number {
  let d = 0;
  for (let i = 0; i < Math.min(a.length, b.length); i++) {
    let x = parseInt(a[i], 16) ^ parseInt(b[i], 16);
    while (x) { d += x & 1; x >>= 1; }
  }
  return d;
}

interface Fingerprint { sha256: string; dh: string[]; width: number; height: number; frames: number }

async function fingerprint(buf: Buffer): Promise<Fingerprint> {
  const meta = await sharp(buf, { animated: true }).metadata();
  const frames = meta.pages ?? 1;
  const dh = [await dHash(buf, 0)];
  if (frames > 2) dh.push(await dHash(buf, Math.floor(frames / 2)));
  return { sha256: createHash("sha256").update(buf).digest("hex"), dh, width: meta.width ?? 0, height: (meta.pageHeight ?? meta.height) ?? 0, frames };
}

/** Compare à tous les stickers publiés : copie exacte, copie proche ou rien. */
async function findCopy(fp: Fingerprint, ownerId: string, excludePackId?: string):
  Promise<{ kind: "exact" | "near"; stickerId: string; creatorId?: string } | null> {
  const exact = await db.collection("Stickers").where("sha256", "==", fp.sha256).limit(3).get();
  for (const d of exact.docs) {
    if (d.get("packId") === excludePackId) continue;
    if (d.get("status") === "removed") continue;
    return { kind: "exact", stickerId: d.id, creatorId: d.get("creatorId") };
  }
  // Parcours des empreintes visuelles (catalogue de taille raisonnable ; plafond de sécurité)
  const snap = await db.collection("Stickers").select("dhash", "creatorId", "packId", "status").limit(20000).get();
  for (const d of snap.docs) {
    if (d.get("packId") === excludePackId || d.get("status") === "removed") continue;
    const other = d.get("dhash") as string[] | undefined;
    if (!other?.length) continue;
    const dist = Math.min(...fp.dh.flatMap((a) => other.map((b) => hamming(a, b))));
    if (dist <= HAMMING_NEAR && d.get("creatorId") !== ownerId) return { kind: "near", stickerId: d.id, creatorId: d.get("creatorId") };
  }
  return null;
}

// ── Mes stickers (phase 3) ──────────────────────────────────────────────────

export const onUserStickerCreated = onDocumentCreated("UserStickers/{id}", async (event) => {
  const snap = event.data;
  if (!snap) return;
  const ownerId = snap.get("ownerId") as string | undefined;
  const path = String(snap.get("storagePath") ?? "");
  const drop = async (why: string) => {
    console.log(`[userSticker] ${snap.id} refusé (${why})`);
    if (path.startsWith(`user_stickers/${ownerId}/`)) await bucket().file(path).delete({ ignoreNotFound: true }).catch(() => undefined);
    await snap.ref.delete();
  };
  if (!ownerId || !path.startsWith(`user_stickers/${ownerId}/`)) return drop("chemin");
  const user = (await db.collection("Users").doc(ownerId).get()).data();
  const tier = tierOf(user);
  if (tier === "free") return drop("abonnement");
  try {
    const [meta] = await bucket().file(path).getMetadata();
    const size = Number(meta.size ?? 0);
    if (!size || size > MAX_ANIM_BYTES) return drop("poids");
    const [buf] = await bucket().file(path).download();
    const fp = await fingerprint(buf);
    const mine = await db.collection("UserStickers").where("ownerId", "==", ownerId).limit(60).get();
    if (mine.docs.filter((d) => d.id !== snap.id && d.get("status") !== "removed").length >= (MAX_PERSONAL[tier] ?? 0)) return drop("quota");
    await snap.ref.update({ status: "active", sizeBytes: size, sha256: fp.sha256, dhash: fp.dh, w: fp.width, h: fp.height });
  } catch (e) {
    console.error("[userSticker] erreur", e);
    return drop("fichier");
  }
});

// ── Dépôt d'un pack par un créateur (phase 4) ────────────────────────────────

interface SubmittedSticker { path: string; category?: string; captions?: Record<string, string>; keywords?: string[]; giftPriceCoins?: number }

export const submitStickerPack = onCall({ timeoutSeconds: 300, memory: "1GiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const d = request.data as { name?: string; region?: string; priceCoins?: number; stickers?: SubmittedSticker[] };
  const name = String(d.name ?? "").trim().slice(0, 40);
  const region = REGIONS.includes(String(d.region)) ? String(d.region) : "universal";
  const price = Math.max(0, Math.min(MAX_PRICE, Math.floor(num(d.priceCoins))));
  const items = Array.isArray(d.stickers) ? d.stickers : [];
  if (name.length < 2) throw new HttpsError("invalid-argument", "Donne un nom au pack.");
  if (items.length < MIN_STICKERS || items.length > MAX_STICKERS) {
    throw new HttpsError("invalid-argument", `Un pack contient entre ${MIN_STICKERS} et ${MAX_STICKERS} stickers.`);
  }

  const userDoc = await db.collection("Users").doc(uid).get();
  const u = userDoc.data();
  if (!u) throw new HttpsError("not-found", "Compte introuvable.");
  const tier = tierOf(u);
  const ageMs = Date.now() - (num(u["createdAt"]) > 1e14 ? num(u["createdAt"]) / 1000 : num(u["createdAt"]));
  const eligible = u["role"] === "ADM" || (tier !== "free" && (u["isVerify"] === true || ageMs > 30 * 24 * 3600 * 1000));
  if (!eligible) throw new HttpsError("permission-denied", "Il faut un abonnement Premium ou Gold et un compte de plus de 30 jours (ou vérifié) pour déposer un pack.");

  const pending = await db.collection("StickerPacks").where("creatorId", "==", uid).where("status", "==", "pending").limit(5).get();
  if (pending.size >= 3) throw new HttpsError("resource-exhausted", "Tu as déjà 3 packs en attente de validation.");

  const packRef = db.collection("StickerPacks").doc();
  const stickerDocs: Array<{ ref: FirebaseFirestore.DocumentReference; data: Record<string, unknown> }> = [];
  let needsReview = false;
  const seen = new Set<string>();

  for (let i = 0; i < items.length; i++) {
    const it = items[i];
    const path = String(it.path ?? "");
    if (!path.startsWith(`sticker_submissions/${uid}/`)) throw new HttpsError("invalid-argument", `Fichier ${i + 1} : chemin refusé.`);
    const file = bucket().file(path);
    const [meta] = await file.getMetadata().catch(() => { throw new HttpsError("not-found", `Fichier ${i + 1} introuvable.`); });
    const size = Number(meta.size ?? 0);
    if (!size || size > MAX_ANIM_BYTES) throw new HttpsError("invalid-argument", `Fichier ${i + 1} : ${Math.round(size / 1024)} Ko, maximum 600 Ko.`);
    const [buf] = await file.download();
    let fp: Fingerprint;
    try { fp = await fingerprint(buf); } catch { throw new HttpsError("invalid-argument", `Fichier ${i + 1} : image non reconnue.`); }
    if (fp.width < 128 || fp.height < 128 || fp.width > 1024 || fp.height > 1024) throw new HttpsError("invalid-argument", `Fichier ${i + 1} : taille d'image refusée (entre 128 et 1024 px).`);
    if (seen.has(fp.sha256)) throw new HttpsError("invalid-argument", `Fichier ${i + 1} : identique à un autre de ton pack.`);
    seen.add(fp.sha256);

    const copy = await findCopy(fp, uid);
    if (copy?.kind === "exact") throw new HttpsError("already-exists", `Fichier ${i + 1} : ce sticker existe déjà dans Afrolook.`);
    if (copy) needsReview = true;

    // Miniature fixe et lien de lecture (jeton propre à chaque fichier)
    const stickerId = randomUUID().replace(/-/g, "").slice(0, 20);
    const finalPath = `stickers/${packRef.id}/${stickerId}.webp`;
    const thumbPath = `stickers/${packRef.id}/${stickerId}_thumb.webp`;
    const token = randomUUID();
    const thumbToken = randomUUID();
    const thumb = await sharp(buf, { page: 0 }).resize(256, 256, { fit: "inside" }).webp({ quality: 70 }).toBuffer();
    await file.copy(bucket().file(finalPath));
    await bucket().file(finalPath).setMetadata({ contentType: "image/webp", metadata: { firebaseStorageDownloadTokens: token } });
    await bucket().file(thumbPath).save(thumb, { contentType: "image/webp", metadata: { metadata: { firebaseStorageDownloadTokens: thumbToken } } });
    await file.delete({ ignoreNotFound: true });

    const captions: Record<string, string> = {};
    for (const l of LANGS) {
      const c = String(it.captions?.[l] ?? "").trim().slice(0, 40);
      if (c) captions[l] = c;
    }
    const gift = Math.max(0, Math.min(500, Math.floor(num(it.giftPriceCoins))));
    stickerDocs.push({
      ref: db.collection("Stickers").doc(stickerId),
      data: {
        packId: packRef.id, order: i, category: CATEGORIES.includes(String(it.category)) ? it.category : "reponses",
        captions, keywords: (it.keywords ?? []).map((k) => String(k).toLowerCase().slice(0, 30)).slice(0, 20),
        url: tokenUrl(finalPath, token), thumbUrl: tokenUrl(thumbPath, thumbToken), storagePath: finalPath,
        sizeBytes: size, durationMs: 0, animated: fp.frames > 1, giftPriceCoins: gift,
        status: "pending", creatorId: uid, createdAt: Date.now(), sha256: fp.sha256, dhash: fp.dh, w: fp.width, h: fp.height,
        ...(copy ? { copyOf: copy.stickerId, copyOfCreator: copy.creatorId ?? null } : {}),
      },
    });
  }

  const now = Date.now();
  const batch = db.batch();
  batch.set(packRef, {
    name, names: { fr: name }, kind: region === "universal" ? "creator" : "world", region, creatorId: uid,
    priceCoins: price, status: "pending", needsReview, stickerCount: stickerDocs.length, order: 1000,
    coverUrl: stickerDocs[0].data["thumbUrl"], createdAt: now, updatedAt: now, salesCount: 0,
  });
  for (const s of stickerDocs) batch.set(s.ref, s.data);
  await batch.commit();
  return { packId: packRef.id, status: "pending", needsReview };
});

// ── Modération par un administrateur ─────────────────────────────────────────

export const adminStickerAction = onCall({ timeoutSeconds: 60, memory: "256MiB" }, async (request) => {
  await requireAdmin(request.auth?.uid);
  const { packId, stickerId, action, reason } = request.data as { packId?: string; stickerId?: string; action?: string; reason?: string };
  const now = Date.now();
  const why = String(reason ?? "").slice(0, 200);
  const log = () => db.collection("AdminActions").add({
    adminId: request.auth!.uid, targetType: packId ? "sticker_pack" : "sticker", targetId: packId ?? stickerId, action, at: now, ...(why ? { reason: why } : {}),
  });

  if (packId) {
    const ref = db.collection("StickerPacks").doc(packId);
    const pack = await ref.get();
    if (!pack.exists) throw new HttpsError("not-found", "Pack introuvable.");
    const stickers = await db.collection("Stickers").where("packId", "==", packId).get();
    const setAll = async (status: string) => {
      for (let i = 0; i < stickers.docs.length; i += 400) {
        const b = db.batch();
        stickers.docs.slice(i, i + 400).forEach((s) => b.update(s.ref, { status, updatedAt: now }));
        await b.commit();
      }
    };
    const creatorId = pack.get("creatorId") as string | undefined;
    const title = String(pack.get("name") ?? "ton pack");
    switch (action) {
      case "approve":
        await setAll("active");
        await ref.update({ status: "active", needsReview: false, updatedAt: now, rejectReason: FieldValue.delete() });
        if (creatorId && creatorId !== "afrolook") await notifyOwner(creatorId, "", "✅ Pack de stickers validé", `« ${title} » est publié dans Afrolook.`);
        break;
      case "reject":
        await setAll("rejected");
        await ref.update({ status: "rejected", updatedAt: now, rejectReason: why });
        if (creatorId && creatorId !== "afrolook") await notifyOwner(creatorId, "", "Pack de stickers refusé", `« ${title} » a été refusé${why ? ` : ${why}` : "."}`);
        break;
      case "remove":
        await setAll("removed");
        await ref.update({ status: "removed", updatedAt: now, rejectReason: why });
        if (creatorId && creatorId !== "afrolook") await notifyOwner(creatorId, "", "Pack de stickers retiré", `« ${title} » a été retiré${why ? ` : ${why}` : "."}`);
        break;
      case "restore":
        await setAll("active");
        await ref.update({ status: "active", updatedAt: now });
        break;
      default:
        throw new HttpsError("invalid-argument", "Action inconnue.");
    }
    await log();
    return { ok: true };
  }

  if (stickerId) {
    const ref = db.collection("Stickers").doc(stickerId);
    const s = await ref.get();
    if (!s.exists) throw new HttpsError("not-found", "Sticker introuvable.");
    if (action === "remove") await ref.update({ status: "removed", updatedAt: now, rejectReason: why });
    else if (action === "restore") await ref.update({ status: "active", updatedAt: now });
    else throw new HttpsError("invalid-argument", "Action inconnue.");
    await log();
    return { ok: true };
  }
  throw new HttpsError("invalid-argument", "packId ou stickerId requis.");
});

// ── Signalement d'une copie ──────────────────────────────────────────────────

export const reportStickerCopy = onCall({ timeoutSeconds: 20, memory: "256MiB" }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Authentification requise.");
  const { stickerId, note } = request.data as { stickerId?: string; note?: string };
  if (!stickerId) throw new HttpsError("invalid-argument", "stickerId requis.");
  const s = await db.collection("Stickers").doc(stickerId).get();
  if (!s.exists) throw new HttpsError("not-found", "Sticker introuvable.");
  const dup = await db.collection("StickerReports").where("stickerId", "==", stickerId).where("reporterId", "==", uid).limit(1).get();
  if (!dup.empty) return { ok: true, already: true };
  await db.collection("StickerReports").add({
    stickerId, packId: s.get("packId"), creatorId: s.get("creatorId") ?? null, reporterId: uid,
    note: String(note ?? "").slice(0, 300), status: "open", createdAt: Date.now(),
  });
  return { ok: true };
});
