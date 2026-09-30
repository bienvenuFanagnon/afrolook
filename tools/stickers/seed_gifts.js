#!/usr/bin/env node
/* Envoie le pack officiel « Cadeaux Afrolook » (10 stickers-cadeaux) dans Storage + Firestore.
 *
 * Usage :
 *   GOOGLE_APPLICATION_CREDENTIALS=/chemin/cle.json node tools/stickers/seed_gifts.js [--dry-run] [--dir DOSSIER] [--index FICHIER]
 *
 * - Lit tools/stickers/gift_index.json (produit par gen_gifts.py) et les .webp du dossier
 *   (par défaut $GIFT_OUT ou tools/stickers/gift_out).
 * - Storage : stickers/official_cadeaux/{id}.webp et {id}_thumb.webp (jeton réutilisé s'il existe).
 * - Firestore : StickerPacks/official_cadeaux (gratuit) + Stickers/{id} avec giftPriceCoins > 0
 *   (set merge : relançable, createdAt conservé).
 * - --dry-run : valide et affiche ce qui serait écrit, sans aucune écriture ni accès réseau.
 * Réutilise les fonctions d'empreintes (sha256/dhash) et d'envoi de seed_pack.js.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const {
  PROJECT_ID, BUCKET, MAX_BYTES, MAX_THUMB_BYTES, MAX_DURATION_MS, LANGS,
  loadAdmin, fingerprintOf, downloadUrl, pool, uploadOne,
} = require('./seed_pack.js');

const PACK_ID = 'official_cadeaux';
const STORAGE_DIR = `stickers/${PACK_ID}`;
const EXPECTED = 10;

const PACK_NAMES = {
  fr: 'Cadeaux Afrolook',
  en: 'Afrolook Gifts',
  es: 'Regalos Afrolook',
  de: 'Afrolook-Geschenke',
  ar: 'هدايا أفرولوك',
  pt: 'Presentes Afrolook',
  zh: 'Afrolook 礼物',
  sw: 'Zawadi za Afrolook',
};

function parseArgs(argv) {
  const a = {
    dryRun: false,
    dir: process.env.GIFT_OUT || path.join(__dirname, 'gift_out'),
    index: path.join(__dirname, 'gift_index.json'),
  };
  for (let i = 2; i < argv.length; i++) {
    const v = argv[i];
    if (v === '--dry-run') a.dryRun = true;
    else if (v === '--dir') a.dir = path.resolve(argv[++i]);
    else if (v === '--index') a.index = path.resolve(argv[++i]);
    else if (v === '-h' || v === '--help') {
      console.log('Usage: node seed_gifts.js [--dry-run] [--dir DOSSIER] [--index FICHIER]');
      process.exit(0);
    } else {
      console.error(`Argument inconnu : ${v}`);
      process.exit(2);
    }
  }
  return a;
}

function validate(index, dir) {
  const errors = [];
  if (!Array.isArray(index) || index.length !== EXPECTED) {
    errors.push(`gift_index.json doit contenir ${EXPECTED} stickers (trouvé ${Array.isArray(index) ? index.length : 'non-tableau'})`);
    if (!Array.isArray(index)) return errors;
  }
  const ids = new Set();
  for (const s of index) {
    if (ids.has(s.id)) errors.push(`id en double : ${s.id}`);
    ids.add(s.id);
    if (!/^cadeau_[a-z0-9_]+$/.test(s.id)) errors.push(`${s.id} : id inattendu (préfixe cadeau_)`);
    if (!Number.isInteger(s.giftPriceCoins) || s.giftPriceCoins <= 0) errors.push(`${s.id} : giftPriceCoins doit être > 0`);
    if (s.category !== 'afrolook') errors.push(`${s.id} : category doit être 'afrolook'`);
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
        errors.push(`${s.id} : sizeBytes de l'index (${s.sizeBytes}) != fichier (${size}) ; relancez gen_gifts.py`);
      }
    }
  }
  return errors;
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
  console.log(`${index.length} stickers-cadeaux valides (${(totalBytes / 1024).toFixed(0)} Ko d'animations) dans ${args.dir}`);

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
    order: 1,
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
    giftPriceCoins: s.giftPriceCoins,
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
      console.log(`[dry-run] Storage ${STORAGE_DIR}/${s.file} (${s.sizeBytes} o) + ${s.thumbFile} -> Stickers/${s.id} (${s.giftPriceCoins} pièces, ${FP[s.id].w}x${FP[s.id].h})`);
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
    if (done % 5 === 0 || done === index.length) console.log(`Storage : ${done}/${index.length}`);
  });

  // 2) Firestore (createdAt conservé si le document existe déjà)
  const packRef = db.collection('StickerPacks').doc(PACK_ID);
  const packSnap = await packRef.get();
  const packCreated = packSnap.exists && packSnap.get('createdAt') ? packSnap.get('createdAt') : now;
  await packRef.set(packDoc(urls[index[0].id].thumbUrl, packCreated), { merge: true });
  console.log(`StickerPacks/${PACK_ID} : ${packSnap.exists ? 'mis à jour' : 'créé'}`);

  const refs = index.map((s) => db.collection('Stickers').doc(s.id));
  const snaps = await db.getAll(...refs);
  const batch = db.batch();
  let created = 0;
  let updated = 0;
  for (let i = 0; i < index.length; i++) {
    const s = index[i];
    const exists = snaps[i].exists;
    const createdAt = exists && snaps[i].get('createdAt') ? snaps[i].get('createdAt') : now;
    batch.set(refs[i], stickerDoc(s, urls[s.id].url, urls[s.id].thumbUrl, createdAt), { merge: true });
    exists ? updated++ : created++;
  }
  await batch.commit();
  console.log(`Stickers : ${created} créés, ${updated} mis à jour.`);
  console.log('Terminé.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
