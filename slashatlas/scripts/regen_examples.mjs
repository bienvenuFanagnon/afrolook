/**
 * Régénère les vidéos d'exemples du site à partir des nouvelles images before-*.webp.
 *
 * Pipeline pour chaque slug :
 *   1. Lire before-{slug}.webp  →  détourer (localCutout)  →  cut-{slug}.webp
 *   2. Rendre ex-{slug}-fr.mp4  (video.render, canvas+ffmpeg, sans IA externe)
 *   3. Rendre ex-{slug}-en.mp4
 *   4. Extraire le poster ex-{slug}.webp depuis la frame 0 de la vidéo FR
 *
 * Usage :
 *   node scripts/regen_examples.mjs
 *   node scripts/regen_examples.mjs --slugs robe,tenue   (sous-ensemble)
 *   node scripts/regen_examples.mjs --voice               (avec voix TTS Google — nécessite gcloud auth)
 *   node scripts/regen_examples.mjs --no-cutout           (réutilise les cut-*.webp existants)
 */
import { createRequire } from 'node:module';
import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';

const require = createRequire(import.meta.url);
const __dir = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dir, '..');              // slashatlas/
const FN = path.join(ROOT, 'functions');             // slashatlas/functions
const STATIC = path.join(ROOT, 'static');            // slashatlas/static
const IMG_VIDEO = path.join(STATIC, 'img', 'video');
const VID_EX = path.join(STATIC, 'video', 'exemples');

// sharp est dans slashatlas/node_modules, les autres dans functions/node_modules
const sharp = require(path.join(ROOT, 'node_modules', 'sharp'));
const { createCanvas, loadImage } = require(path.join(FN, 'node_modules', '@napi-rs', 'canvas'));
const FFMPEG = require(path.join(FN, 'node_modules', 'ffmpeg-static'));
const video = require(path.join(FN, 'video.js'));
const { localCutout } = require(path.join(FN, 'cutout.js'));

// Initialiser Firebase Admin pour que matting.js puisse accéder au modèle ONNX dans Storage
let mattingFn = null;
try {
  const admin = require(path.join(FN, 'node_modules', 'firebase-admin'));
  if (!admin.apps.length) {
    admin.initializeApp({ storageBucket: 'slashatlas-studio.firebasestorage.app' });
  }
  mattingFn = require(path.join(FN, 'matting.js')).matte;
  console.log('Détourage IS-Net (IA) disponible — sera utilisé en priorité.');
} catch (e) {
  console.warn('Détourage IS-Net non disponible (' + e.message.slice(0, 80) + ') — fallback localCutout.')
}

// --- args ---
const argv = process.argv.slice(2);
const arg = (k) => { const i = argv.indexOf('--' + k); return i >= 0 ? (argv[i + 1] || true) : null; };
const SLUGS_FILTER = arg('slugs') || '';
const WITH_VOICE   = argv.includes('--voice');
const NO_CUTOUT    = argv.includes('--no-cutout');

// Correspondance slug → modèle vidéo (depuis build.mjs VEX_MODEL)
const VEX_MODEL = {
  lotion: 'zoom',
  parfum: 'tour360',
  robe:   'lancement',
  tenue:  'zoom',
  eau:    'tour360',
  plat:   'lancement',
};

// Textes pour chaque produit (FR + EN)
const TEXTS = {
  lotion: {
    fr: { brand: 'SOIN AFRIQUE', hook: 'Rayonnez chaque jour', lines: ['Hydratation intense', 'Éclat naturel'], cta: 'Découvrir' },
    en: { brand: 'AFRO GLOW',   hook: 'Glow every day',       lines: ['Deep hydration', 'Natural radiance'],  cta: 'Discover' },
  },
  parfum: {
    fr: { brand: 'MAISON SOLEIL', hook: 'Votre signature',          lines: ['Parfum de luxe', 'Notes florales'],  cta: 'Sentez la différence' },
    en: { brand: 'MAISON SOLEIL', hook: 'Your signature',           lines: ['Luxury fragrance', 'Floral notes'],  cta: 'Feel the difference' },
  },
  robe: {
    fr: { brand: 'KENZO MODE', hook: 'La mode africaine',   lines: ['Wax premium', 'Coupe élégante'],   cta: 'Voir la collection' },
    en: { brand: 'KENZO MODE', hook: 'African fashion',     lines: ['Premium wax', 'Elegant cut'],      cta: 'See the collection' },
  },
  tenue: {
    fr: { brand: 'MAISON LÉA', hook: 'Le look de la semaine', lines: ['Tenue complète', 'Style urbain'],   cta: 'Commander' },
    en: { brand: 'MAISON LÉA', hook: 'Look of the week',      lines: ['Full outfit', 'Urban style'],       cta: 'Order now' },
  },
  eau: {
    fr: { brand: 'SOURCE PURE', hook: 'Fraîcheur naturelle', lines: ['Eau minérale', '100 % naturelle'],  cta: 'Commander' },
    en: { brand: 'SOURCE PURE', hook: 'Pure freshness',       lines: ['Mineral water', '100% natural'],    cta: 'Order now' },
  },
  plat: {
    fr: { brand: 'CHEZ MAMA', hook: 'Goûts d\'Afrique', lines: ['Cuisine authentique', 'Recettes familiales'], cta: 'Commander' },
    en: { brand: 'CHEZ MAMA', hook: 'Taste of Africa', lines: ['Authentic cuisine', 'Family recipes'],          cta: 'Order now' },
  },
};

// Style visuel par catégorie
const STYLE_MAP = { lotion: 'beaute', parfum: 'beaute', robe: 'mode', tenue: 'mode', eau: 'promo', plat: 'promo' };
const MUSIC_MAP = { lotion: 'ambient', parfum: 'ambient', robe: 'beat', tenue: 'beat', eau: 'beat', plat: 'beat' };

// Voix off (si --voice)
function voiceSegments(texts, slug) {
  const t = texts;
  return {
    hook:    t.hook,
    product: (t.lines || []).join(', '),
    benefits: t.brand,
    cta:     t.cta,
  };
}

// Exécute ffmpeg et extrait une frame pour le poster
function extractPoster(mp4Path, outPath) {
  return new Promise((resolve, reject) => {
    const ff = spawn(FFMPEG, ['-y', '-ss', '1', '-i', mp4Path, '-vframes', '1', '-q:v', '2', outPath]);
    ff.on('close', (code) => code === 0 ? resolve() : reject(new Error('ffmpeg poster exit ' + code)));
  });
}

// Sauvegarde un canvas en webp via sharp
async function canvasToWebp(canvas, outPath) {
  const buf = canvas.toBuffer('image/png');
  await sharp(buf).webp({ quality: 88 }).toFile(outPath);
}

async function main() {
  const slugs = Object.keys(VEX_MODEL).filter((s) => !SLUGS_FILTER || SLUGS_FILTER.split(',').map((x) => x.trim()).includes(s));
  console.log(`Régénération de ${slugs.length} exemple(s) : ${slugs.join(', ')}`);
  if (WITH_VOICE) console.log('Voix TTS activée (Chirp 3 HD)');
  if (NO_CUTOUT) console.log('--no-cutout : réutilisation des cut-*.webp existants');

  let done = 0;
  for (const slug of slugs) {
    console.log(`\n━━ ${slug} ━━`);
    const beforePath = path.join(IMG_VIDEO, `before-${slug}.webp`);
    const cutPath    = path.join(IMG_VIDEO, `cut-${slug}.webp`);
    const posterPath = path.join(IMG_VIDEO, `ex-${slug}.webp`);

    if (!fs.existsSync(beforePath)) { console.error(`  ✗ before-${slug}.webp introuvable — ignoré`); continue; }

    // 1. Détourage — IS-Net (IA) en priorité, localCutout en fallback
    let spriteBuf = null;
    if (!NO_CUTOUT) {
      const imgBuf = fs.readFileSync(beforePath);
      let done = false;

      // Essai 1 : IS-Net (modèle IA, fonctionne sur tous types de fond)
      if (mattingFn) {
        try {
          console.log('  → Détourage IS-Net (IA)…');
          const result = await mattingFn(imgBuf);
          if (result && result.ok && result.sprite && result.sprite.canvas) {
            const pngBuf = result.sprite.canvas.toBuffer('image/png');
            spriteBuf = pngBuf;
            await sharp(pngBuf).webp({ quality: 88 }).toFile(cutPath);
            console.log(`  ✓ cut-${slug}.webp (IS-Net, fraction=${(result.sprite.fraction * 100).toFixed(1)}%)`);
            done = true;
          } else {
            console.warn(`  ⚠ IS-Net échoué (${result && result.reason || 'inconnu'}) — tentative localCutout`);
          }
        } catch (e) {
          console.warn('  ⚠ IS-Net erreur :', e.message.slice(0, 120), '— tentative localCutout');
        }
      }

      // Essai 2 : localCutout (flood-fill, fonds unis uniquement)
      if (!done) {
        try {
          console.log('  → Détourage localCutout…');
          const result = await localCutout(imgBuf);
          if (result && result.ok && result.sprite && result.sprite.canvas) {
            const pngBuf = result.sprite.canvas.toBuffer('image/png');
            spriteBuf = pngBuf;
            await sharp(pngBuf).webp({ quality: 88 }).toFile(cutPath);
            console.log(`  ✓ cut-${slug}.webp (localCutout, fraction=${(result.fraction * 100).toFixed(1)}%)`);
          } else {
            console.warn(`  ⚠ Détourage échoué (${result && result.reason || 'inconnu'}) — la vidéo utilisera la photo encadrée`);
          }
        } catch (e) {
          console.warn('  ⚠ Détourage erreur :', e.message, '— la vidéo utilisera la photo encadrée');
        }
      }
    } else if (fs.existsSync(cutPath)) {
      // réutiliser l'existant
      spriteBuf = fs.readFileSync(cutPath);
      console.log('  → cut-*.webp existant réutilisé');
    }

    // 2. Rendu pour chaque langue
    const photoBuf = fs.readFileSync(beforePath);
    let posterDone = false;

    for (const lang of ['fr', 'en']) {
      const outMp4 = path.join(VID_EX, `ex-${slug}-${lang}.mp4`);
      const texts  = TEXTS[slug][lang];
      console.log(`  → Rendu ${lang}…`);

      const P = {
        style:   STYLE_MAP[slug],
        model:   VEX_MODEL[slug],
        ratio:   '9:16',
        lang,
        photos:  [photoBuf],
        sprites: spriteBuf ? [spriteBuf] : [null],
        cutout:  spriteBuf ? 'auto' : 'off',
        texts,
        music:   MUSIC_MAP[slug],
        sfx:     true,
        threads: 2,
        voice:   WITH_VOICE
          ? { gender: 'f', segments: voiceSegments(texts, slug) }
          : null,
      };

      try {
        const result = await video.render(P);
        fs.copyFileSync(result.file, outMp4);
        // nettoyage du fichier temporaire
        try { fs.rmSync(result.dir || path.dirname(result.file), { recursive: true, force: true }); } catch (_) {}
        console.log(`  ✓ ex-${slug}-${lang}.mp4  (${result.seconds.toFixed(1)} s)`);

        // 3. Poster depuis la vidéo FR
        if (!posterDone && lang === 'fr') {
          const tmpPoster = posterPath.replace('.webp', '_tmp.jpg');
          try {
            await extractPoster(outMp4, tmpPoster);
            await sharp(tmpPoster).resize(600, null).webp({ quality: 88 }).toFile(posterPath);
            fs.unlinkSync(tmpPoster);
            console.log(`  ✓ ex-${slug}.webp (poster)`);
            posterDone = true;
          } catch (e) {
            console.warn('  ⚠ Poster non extrait :', e.message);
          }
        }
      } catch (e) {
        console.error(`  ✗ Rendu ${lang} échoué :`, e.message);
      }
    }

    done++;
  }

  console.log(`\n${done}/${slugs.length} exemple(s) régénéré(s).`);
  console.log('\nRelancez :  node build.mjs && firebase deploy --only hosting:slashatlas-studio');
}

main().catch((e) => { console.error(e); process.exit(1); });
