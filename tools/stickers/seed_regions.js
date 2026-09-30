#!/usr/bin/env node
/* Envoie les 6 packs régionaux officiels (kind 'world') dans Storage + Firestore.
 * Usage : GOOGLE_APPLICATION_CREDENTIALS=cle.json node tools/stickers/seed_regions.js [--dry-run] [--dir DOSSIER]
 * Lit regions_index.json (produit par gen_regions.py). Relançable (set merge, jetons Storage réutilisés).
 */
'use strict';
const fs = require('fs');
const path = require('path');
const {
  PROJECT_ID, BUCKET, MAX_BYTES, MAX_THUMB_BYTES, LANGS, loadAdmin, fingerprintOf, downloadUrl, pool, uploadOne,
} = require('./seed_pack.js');

const args = { dryRun: false, dir: path.join(__dirname, 'regions_out'), index: path.join(__dirname, 'regions_index.json') };
for (let i = 2; i < process.argv.length; i++) {
  const v = process.argv[i];
  if (v === '--dry-run') args.dryRun = true;
  else if (v === '--dir') args.dir = path.resolve(process.argv[++i]);
  else { console.error(`Argument inconnu : ${v}`); process.exit(2); }
}

async function main() {
  const packs = JSON.parse(fs.readFileSync(args.index, 'utf8'));
  const errors = [];
  for (const p of packs) {
    for (const s of p.stickers) {
      for (const l of LANGS) if (!s.captions[l]) errors.push(`${s.id} : légende ${l} manquante`);
      for (const [k, max] of [['file', MAX_BYTES], ['thumbFile', MAX_THUMB_BYTES]]) {
        const f = path.join(args.dir, s[k]);
        if (!fs.existsSync(f)) errors.push(`fichier absent ${f}`);
        else if (fs.statSync(f).size > max) errors.push(`${s[k]} trop lourd`);
      }
    }
  }
  if (errors.length) { console.error(errors.join('\n')); process.exit(1); }
  const total = packs.reduce((n, p) => n + p.stickers.length, 0);
  console.log(`${packs.length} packs, ${total} stickers valides`);
  if (args.dryRun) { console.log('[dry-run] OK'); return; }
  if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) { console.error('GOOGLE_APPLICATION_CREDENTIALS manquant'); process.exit(1); }
  const admin = loadAdmin();
  admin.initializeApp({ credential: admin.credential.applicationDefault(), projectId: PROJECT_ID, storageBucket: BUCKET });
  const bucket = admin.storage().bucket();
  const db = admin.firestore();
  const now = Date.now();

  for (const p of packs) {
    const dirSt = `stickers/${p.packId}`;
    const urls = {};
    await pool(p.stickers, 4, async (s) => {
      const p1 = `${dirSt}/${s.file}`, p2 = `${dirSt}/${s.thumbFile}`;
      const [t1, t2] = await Promise.all([
        uploadOne(bucket, path.join(args.dir, s.file), p1),
        uploadOne(bucket, path.join(args.dir, s.thumbFile), p2),
      ]);
      urls[s.id] = { url: downloadUrl(p1, t1), thumbUrl: downloadUrl(p2, t2) };
    });
    const packRef = db.collection('StickerPacks').doc(p.packId);
    const snap = await packRef.get();
    await packRef.set({
      name: p.names.fr, names: p.names, kind: 'world', region: p.region, creatorId: 'afrolook', priceCoins: 0,
      status: 'active', stickerCount: p.stickers.length, order: p.order, coverUrl: urls[p.stickers[0].id].thumbUrl,
      createdAt: snap.exists && snap.get('createdAt') ? snap.get('createdAt') : now, updatedAt: now,
    }, { merge: true });
    const refs = p.stickers.map((s) => db.collection('Stickers').doc(s.id));
    const snaps = await db.getAll(...refs);
    const batch = db.batch();
    for (let i = 0; i < p.stickers.length; i++) {
      const s = p.stickers[i];
      const fp = await fingerprintOf(path.join(args.dir, s.file));
      batch.set(refs[i], {
        packId: p.packId, order: s.order, category: s.category, captions: s.captions, keywords: s.keywords,
        url: urls[s.id].url, thumbUrl: urls[s.id].thumbUrl, storagePath: `${dirSt}/${s.file}`,
        sizeBytes: s.sizeBytes, durationMs: s.durationMs, animated: true, giftPriceCoins: 0, status: 'active',
        creatorId: 'afrolook', createdAt: snaps[i].exists && snaps[i].get('createdAt') ? snaps[i].get('createdAt') : now,
        sha256: fp.sha256, dhash: fp.dhash, w: fp.w, h: fp.h,
      }, { merge: true });
    }
    await batch.commit();
    console.log(`${p.packId} : ${p.stickers.length} stickers`);
  }
  console.log('Terminé.');
}
main().catch((e) => { console.error(e); process.exit(1); });
