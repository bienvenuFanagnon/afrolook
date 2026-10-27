/**
 * Script de test : génère un épisode 1 de série via Firestore + slashatlasFilm
 * Usage : node test-serie-episode.mjs
 */
import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import crypto from 'crypto';
import { readFileSync } from 'fs';

const SA = JSON.parse(readFileSync('./service-account.json', 'utf8'));
initializeApp({ credential: cert(SA), projectId: 'slashatlas-studio' });
const db = getFirestore();

const RENDER_URL = 'https://slashatlasfilm-jpbacdkvra-ew.a.run.app';
const TEST_UID = 'test-script-uid';

// Scénario animé 2.5D hardcodé (évite l'appel Gemini)
const TEST_SCRIPT = {
  title: "Kofi et la forêt magique — Épisode 1",
  episode: 1,
  genre: "serie",
  lang: "fr",
  characters: ["Kofi (enfant-garcon)", "La Vieille Sageye (ancien)"],
  episode_summary: "Kofi découvre une forêt enchantée et rencontre une sage qui lui confie une mission.",
  scenes: [
    {
      id: 1,
      bg: "village",
      voice: "Dans un petit village au bord de la savane, vivait un garçon curieux nommé Kofi.",
      chars: [
        { type: "enfant-garcon", dir: "E", state: "walk", pos: "center-left", scale: 1.0 }
      ]
    },
    {
      id: 2,
      bg: "savane",
      voice: "Un matin, Kofi remarqua une lumière étrange au fond de la forêt.",
      chars: [
        { type: "enfant-garcon", dir: "S", state: "point", pos: "center", scale: 1.0 }
      ]
    },
    {
      id: 3,
      bg: "foret",
      voice: "Mu par la curiosité, il s'avança entre les grands arbres.",
      chars: [
        { type: "enfant-garcon", dir: "E", state: "walk", pos: "left", scale: 1.0 }
      ]
    },
    {
      id: 4,
      bg: "foret",
      voice: "Au cœur de la forêt, une vieille femme l'attendait, assise sur une pierre.",
      chars: [
        { type: "enfant-garcon", dir: "E", state: "idle", pos: "center-left", scale: 1.0 },
        { type: "ancien", dir: "W", state: "sit", pos: "center-right", scale: 1.1 }
      ]
    },
    {
      id: 5,
      bg: "foret",
      voice: "La sage lui dit : Kofi, tu es venu. La forêt t'a choisi pour une grande mission.",
      chars: [
        { type: "ancien", dir: "S", state: "talk", pos: "center", scale: 1.1 },
        { type: "enfant-garcon", dir: "S", state: "idle", pos: "center-left", scale: 1.0 }
      ]
    },
    {
      id: 6,
      bg: "foret",
      voice: "Kofi prit une grande inspiration. Il était prêt pour l'aventure.",
      chars: [
        { type: "enfant-garcon", dir: "E", state: "wave", pos: "center", scale: 1.0 }
      ]
    }
  ]
};

async function run() {
  console.log('▶ Création de la série test...');
  const seriesRef = db.collection('FilmSeries').doc();
  await seriesRef.set({
    uid: TEST_UID,
    title: 'Kofi et la Forêt Magique',
    synopsis: 'Les aventures de Kofi, un jeune garçon courageux qui découvre des secrets cachés dans la forêt africaine.',
    characters: ['Kofi (enfant-garcon)', 'La Vieille Sageye (ancien)'],
    episodeCount: 0,
    lang: 'fr',
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  console.log('  Série créée :', seriesRef.id);

  console.log('▶ Création du job FilmJobs...');
  const renderToken = crypto.randomBytes(16).toString('hex');
  const jobRef = db.collection('FilmJobs').doc();
  await jobRef.set({
    uid: TEST_UID,
    seriesId: seriesRef.id,
    episodeNumber: 1,
    title: TEST_SCRIPT.title,
    genre: 'serie',
    lang: 'fr',
    duration: 2,
    cost: 10,
    watermark: false,
    status: 'pending_render',
    script: TEST_SCRIPT,
    renderToken,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  console.log('  Job créé :', jobRef.id);

  console.log('▶ Déclenchement du rendu via slashatlasFilm...');
  const resp = await fetch(RENDER_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ jobId: jobRef.id, token: renderToken }),
    signal: AbortSignal.timeout(15000),
  });
  if (!resp.ok) {
    const body = await resp.text().catch(() => '');
    throw new Error('Trigger HTTP ' + resp.status + ': ' + body);
  }
  const triggerData = await resp.json();
  console.log('  Trigger réponse :', triggerData);

  // Poll Firestore toutes les 15s jusqu'à done ou error (max 10 min)
  console.log('▶ Attente du rendu (poll toutes les 15s)...');
  const start = Date.now();
  while (Date.now() - start < 15 * 60 * 1000) {
    await new Promise(r => setTimeout(r, 15000));
    const snap = await jobRef.get();
    const { status, videoUrl, error } = snap.data();
    const elapsed = Math.round((Date.now() - start) / 1000);
    console.log(`  [${elapsed}s] status = ${status}`);
    if (status === 'done') {
      console.log('\n✅ Vidéo générée !');
      console.log('URL :', videoUrl);
      return videoUrl;
    }
    if (status === 'error') {
      throw new Error('Rendu échoué : ' + error);
    }
  }
  throw new Error('Timeout dépassé (15 min)');
}

run().catch(e => { console.error('❌', e.message); process.exit(1); });
