#!/usr/bin/env node
/* Envoie le pack officiel « Universel » (64 stickers) dans Storage + Firestore.
 *
 * Usage :
 *   GOOGLE_APPLICATION_CREDENTIALS=/chemin/cle.json node tools/stickers/seed_pack.js [--dry-run] [--dir DOSSIER] [--index FICHIER]
 *
 * - Lit tools/stickers/pack_index.json et les .webp du dossier (par défaut $PACK_OUT
 *   ou tools/stickers/pack_out ; celui produit par gen_pack.py --out ...).
 * - Storage : stickers/official_universel/{id}.webp et {id}_thumb.webp, avec un jeton
 *   firebaseStorageDownloadTokens (réutilisé s'il existe déjà : les URL restent stables).
 * - Firestore : StickerPacks/official_universel + Stickers/{id} (set merge : relançable).
 * - --dry-run : valide les fichiers et affiche ce qui serait écrit, sans aucun accès réseau.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const PROJECT_ID = 'afrolooki';
const BUCKET = 'afrolooki.appspot.com';
const PACK_ID = 'official_universel';
const STORAGE_DIR = `stickers/${PACK_ID}`;
const MAX_BYTES = 600 * 1024;
const MAX_THUMB_BYTES = 40 * 1024;
const MAX_DURATION_MS = 3000;
const LANGS = ['fr', 'en', 'es', 'de', 'ar', 'pt', 'zh', 'sw'];

const PACK_NAMES = {
  fr: 'Afrolook — Universel',
  en: 'Afrolook — Universal',
  es: 'Afrolook — Universal',
  de: 'Afrolook — Universell',
  ar: 'Afrolook — عالمي',
  pt: 'Afrolook — Universal',
  zh: 'Afrolook — 通用',
  sw: 'Afrolook — Kwa Wote',
};

function parseArgs(argv) {
  const a = {
    dryRun: false,
    dir: process.env.PACK_OUT || path.join(__dirname, 'pack_out'),
    index: path.join(__dirname, 'pack_index.json'),
  };
  for (let i = 2; i < argv.length; i++) {
    const v = argv[i];
    if (v === '--dry-run') a.dryRun = true;
    else if (v === '--dir') a.dir = path.resolve(argv[++i]);
    else if (v === '--index') a.index = path.resolve(argv[++i]);
    else if (v === '-h' || v === '--help') {
      console.log('Usage: node seed_pack.js [--dry-run] [--dir DOSSIER] [--index FICHIER]');
      process.exit(0);
    } else {
      console.error(`Argument inconnu : ${v}`);
      process.exit(2);
    }
  }
  return a;
}

function loadAdmin() {
  const abs = path.resolve(__dirname, '../../functions/node_modules/firebase-admin');
  try {
    return require(abs);
  } catch (e) {
    return require('firebase-admin');
  }
}


// Empreintes exacte (SHA-256) et visuelle (dHash 64 bits sur 1 ou 2 images), identiques à celles du serveur :
// elles servent à repérer les copies de stickers officiels lors du dépôt d'un pack par un créateur.
const sharp = require('/home/user/afrolook/functions/node_modules/sharp');
async function dHashOf(buf, page) {
  const { data } = await sharp(buf, { page, animated: false }).grayscale().resize(9, 8, { fit: 'fill' }).raw().toBuffer({ resolveWithObject: true });
  let bits = '';
  for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) bits += data[y * 9 + x] > data[y * 9 + x + 1] ? '1' : '0';
  let hex = '';
  for (let i = 0; i < 64; i += 4) hex += parseInt(bits.slice(i, i + 4), 2).toString(16);
  return hex;
}
async function fingerprintOf(filePath) {
  const buf = fs.readFileSync(filePath);
  const meta = await sharp(buf, { animated: true }).metadata();
  const frames = meta.pages || 1;
  const dh = [await dHashOf(buf, 0)];
  if (frames > 2) dh.push(await dHashOf(buf, Math.floor(frames / 2)));
  return { sha256: crypto.createHash('sha256').update(buf).digest('hex'), dhash: dh, w: meta.width || 0, h: (meta.pageHeight || meta.height) || 0 };
}

function downloadUrl(storagePath, token) {
  return `https://firebasestorage.googleapis.com/v0/b/${BUCKET}/o/${encodeURIComponent(storagePath)}?alt=media&token=${token}`;
}

/** Valide l'index et les fichiers ; renvoie la liste des entrées prêtes à envoyer. */
function validate(index, dir) {
  const errors = [];
  if (!Array.isArray(index) || index.length !== 64) {
    errors.push(`pack_index.json doit contenir 64 stickers (trouvé ${Array.isArray(index) ? index.length : 'non-tableau'})`);
  }
  const ids = new Set();
  for (const s of index) {
    if (ids.has(s.id)) errors.push(`id en double : ${s.id}`);
    ids.add(s.id);
    for (const l of LANGS) {
      if (!s.captions || !s.captions[l]) errors.push(`${s.id} : légende ${l} manquante`);
    }
    if (!Array.isArray(s.keywords) || s.keywords.length === 0) errors.push(`${s.id} : mots-clés manquants`);
    if (s.durationMs > MAX_DURATION_MS) errors.push(`${s.id} : durée ${s.durationMs} ms > 3 s`);
    for (const [key, max] of [['file', MAX_BYTES], ['thumbFile', MAX_THUMB_BYTES]]) {
      const p = path.join(dir, s[key]);
      if (!fs.existsSync(p)) {
        errors.push(`${s.id} : fichier absent ${p}`);
        continue;
      }
      const size = fs.statSync(p).size;
      if (size > max) errors.push(`${s.id} : ${s[key]} pèse ${size} octets (max ${max})`);
      if (key === 'file' && size !== s.sizeBytes) {
        errors.push(`${s.id} : sizeBytes de l'index (${s.sizeBytes}) != fichier (${size}) ; relancez gen_pack.py`);
      }
    }
  }
  return errors;
}

async function pool(items, limit, fn) {
  let i = 0;
  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (i < items.length) {
      const item = items[i++];
      await fn(item);
    }
  });
  await Promise.all(workers);
}

async function uploadOne(bucket, localPath, destination) {
  const file = bucket.file(destination);
  let token = null;
  try {
    const [meta] = await file.getMetadata();
    const t = meta.metadata && meta.metadata.firebaseStorageDownloadTokens;
    if (t) token = String(t).split(',')[0];
  } catch (e) {
    if (e.code !== 404) throw e;
  }
  if (!token) token = crypto.randomUUID();
  await bucket.upload(localPath, {
    destination,
    resumable: false,
    metadata: {
      contentType: 'image/webp',
      cacheControl: 'public, max-age=31536000',
      metadata: { firebaseStorageDownloadTokens: token },
    },
  });
  return token;
}

async function main() {
  const args = parseArgs(process.argv);
  const index = JSON.parse(fs.readFileSync(args.index, 'utf8'));
  const errors = validate(index, args.dir);
  if (errors.length) {
    console.error('Validation échouée :\n - ' + errors.join('\n - '));
    process.exit(1);
  }
  const totalBytes = index.reduce((n, s) => n + s.sizeBytes, 0);
  console.log(`${index.length} stickers valides (${(totalBytes / 1024).toFixed(0)} Ko d'animations) dans ${args.dir}`);

  const now = Date.now();
  const packDoc = (coverUrl, createdAt) => ({
    name: PACK_NAMES.fr,
    names: PACK_NAMES,
    kind: 'official',
    region: 'universal',
    creatorId: 'afrolook',
    priceCoins: 0,
    status: 'active',
    stickerCount: index.length,
    order: 0,
    coverUrl,
    createdAt,
    updatedAt: now,
  });
  const FP = {};
  for (const s of index) FP[s.id] = await fingerprintOf(path.join(args.dir, s.file));
  const stickerDoc = (s, url, thumbUrl, createdAt) => ({
    packId: PACK_ID,
    order: s.order,
    category: s.category,
    captions: s.captions,
    keywords: s.keywords,
    url,
    thumbUrl,
    storagePath: `${STORAGE_DIR}/${s.file}`,
    sizeBytes: s.sizeBytes,
    durationMs: s.durationMs,
    animated: true,
    giftPriceCoins: 0,
    status: 'active',
    creatorId: 'afrolook',
    createdAt,
    sha256: FP[s.id].sha256,
    dhash: FP[s.id].dhash,
    w: FP[s.id].w,
    h: FP[s.id].h,
  });

  if (args.dryRun) {
    console.log('[dry-run] aucune écriture, aucun accès réseau.');
    for (const s of index) {
      console.log(`[dry-run] Storage ${STORAGE_DIR}/${s.file} (${s.sizeBytes} o) + ${s.thumbFile} -> Stickers/${s.id}`);
    }
    const sample = stickerDoc(index[0], downloadUrl(`${STORAGE_DIR}/${index[0].file}`, '<jeton>'),
      downloadUrl(`${STORAGE_DIR}/${index[0].thumbFile}`, '<jeton>'), now);
    console.log(`[dry-run] StickerPacks/${PACK_ID} =`, JSON.stringify(packDoc(sample.thumbUrl, now), null, 2));
    console.log(`[dry-run] exemple Stickers/${index[0].id} =`, JSON.stringify(sample, null, 2));
    console.log(`[dry-run] OK : ${index.length} fichiers, ${index.length * 2} objets Storage, ${index.length + 1} documents.`);
    return;
  }

  if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    console.error('GOOGLE_APPLICATION_CREDENTIALS non défini (chemin de la clé de service du projet afrolooki).');
    process.exit(1);
  }
  const admin = loadAdmin();
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: PROJECT_ID,
    storageBucket: BUCKET,
  });
  const bucket = admin.storage().bucket();
  const db = admin.firestore();

  // 1) Storage
  const urls = {};
  let done = 0;
  await pool(index, 4, async (s) => {
    const p1 = `${STORAGE_DIR}/${s.file}`;
    const p2 = `${STORAGE_DIR}/${s.thumbFile}`;
    const [t1, t2] = await Promise.all([
      uploadOne(bucket, path.join(args.dir, s.file), p1),
      uploadOne(bucket, path.join(args.dir, s.thumbFile), p2),
    ]);
    urls[s.id] = { url: downloadUrl(p1, t1), thumbUrl: downloadUrl(p2, t2) };
    done++;
    if (done % 8 === 0 || done === index.length) console.log(`Storage : ${done}/${index.length}`);
  });

  // 2) Firestore (createdAt conservé si le document existe déjà)
  const packRef = db.collection('StickerPacks').doc(PACK_ID);
  const packSnap = await packRef.get();
  const packCreated = packSnap.exists && packSnap.get('createdAt') ? packSnap.get('createdAt') : now;
  const first = index[0];
  await packRef.set(packDoc(urls[first.id].thumbUrl, packCreated), { merge: true });
  console.log(`StickerPacks/${PACK_ID} : ${packSnap.exists ? 'mis à jour' : 'créé'}`);

  const refs = index.map((s) => db.collection('Stickers').doc(s.id));
  const snaps = await db.getAll(...refs);
  let batch = db.batch();
  let n = 0;
  let created = 0;
  let updated = 0;
  for (let i = 0; i < index.length; i++) {
    const s = index[i];
    const exists = snaps[i].exists;
    const createdAt = exists && snaps[i].get('createdAt') ? snaps[i].get('createdAt') : now;
    batch.set(refs[i], stickerDoc(s, urls[s.id].url, urls[s.id].thumbUrl, createdAt), { merge: true });
    exists ? updated++ : created++;
    if (++n % 400 === 0) {
      await batch.commit();
      batch = db.batch();
    }
  }
  await batch.commit();
  console.log(`Stickers : ${created} créés, ${updated} mis à jour.`);
  console.log('Terminé.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
