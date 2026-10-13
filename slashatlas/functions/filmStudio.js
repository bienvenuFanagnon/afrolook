'use strict';
// Studio Film & Série : scénario IA → images FLUX → voix Google TTS → vidéo FFmpeg
const crypto = require('crypto');
const { FieldValue } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const studio = require('./studio');
const { db, bump, clean, spendCredits } = studio;

const FILM_COST = { 2: 10, 3: 15 };
const WATERMARK_DISCOUNT = 1;  // -1 crédit si mention "afrolook.com" dans la vidéo
const CUSTOM_AUDIO_DISCOUNT = 2; // -2 crédits si l'utilisateur importe son propre audio
const FILM_LIMITS = { userPerDay: 3, globalPerDay: 30 };

function calcCost(duration, watermark, customAudio) {
  const base = FILM_COST[[2, 3].includes(+duration) ? +duration : 2];
  return Math.max(1, base
    - (watermark ? WATERMARK_DISCOUNT : 0)
    - (customAudio ? CUSTOM_AUDIO_DISCOUNT : 0));
}
const SCRIPT_MODEL = 'gemini-2.5-flash';
const GEMINI_API_KEY = studio.GEMINI_API_KEY;

function clamp(s, n) { return clean(s, n); }

// ── Prompt film simple ──────────────────────────────────────────────────────
function buildPrompt(params, lang) {
  const { title, synopsis, genre, duration } = params;
  const nScenes = duration === 3 ? 8 : 6;
  const sceneDur = duration === 3 ? 22 : 20;
  const isFr = lang === 'fr';

  if (isFr) {
    return `Tu es un scénariste professionnel. Écris le scénario d'un ${genre} intitulé "${title}".

Synopsis : ${synopsis}

Le scénario doit avoir exactement ${nScenes} scènes de ${sceneDur} secondes chacune (durée totale : ${duration} minutes).

Pour chaque scène, fournis :
- setting : description du décor en anglais (30 mots max, pour la génération d'image FLUX : style illustratif, lumière douce, couleurs vives)
- action : ce que font les personnages (en français, 1-2 phrases)
- voice : texte de la voix off en français (lu en ${Math.round(sceneDur * 0.4)} mots max, naturel, narratif)

Réponds UNIQUEMENT en JSON valide :
{
  "title": "${title}",
  "genre": "${genre}",
  "lang": "fr",
  "scenes": [
    { "id": 1, "setting": "...", "action": "...", "voice": "..." },
    ...
  ]
}
Règles : voix narrative naturelle, pas d'émoji, pas de guillemets dans les textes, décors visuellement descriptifs.`;
  }

  return `You are a professional screenwriter. Write the script for a ${genre} titled "${title}".

Synopsis: ${synopsis}

The script must have exactly ${nScenes} scenes of ${sceneDur} seconds each (total duration: ${duration} minutes).

For each scene, provide:
- setting: scene description in English (30 words max, for FLUX image generation: illustrative style, soft light, vivid colors)
- action: what the characters do (1-2 sentences)
- voice: voice-over text in English (read in ${Math.round(sceneDur * 0.4)} words max, natural, narrative)

Reply ONLY with valid JSON:
{
  "title": "${title}",
  "genre": "${genre}",
  "lang": "en",
  "scenes": [
    { "id": 1, "setting": "...", "action": "...", "voice": "..." },
    ...
  ]
}
Rules: natural narrative voice, no emoji, no quotation marks inside texts, visually descriptive settings.`;
}

// ── Prompt épisode de série (avec contexte des épisodes précédents) ─────────
function buildEpisodePrompt(params, seriesData, prevEpisodes, lang) {
  const { title, duration } = params;
  const nScenes = duration === 3 ? 8 : 6;
  const sceneDur = duration === 3 ? 22 : 20;
  const epNum = (seriesData.episodeCount || 0) + 1;
  const isFr = lang === 'fr';

  const prevContext = prevEpisodes.length
    ? prevEpisodes.map((e, i) => isFr
        ? `  - Épisode ${e.episodeNumber} : "${e.title}" — ${e.summary || e.synopsis || ''}`
        : `  - Episode ${e.episodeNumber}: "${e.title}" — ${e.summary || e.synopsis || ''}`)
      .join('\n')
    : (isFr ? '  (premier épisode)' : '  (first episode)');

  const charContext = (seriesData.characters || []).length
    ? (isFr ? '\nPersonnages récurrents :\n' : '\nRecurring characters:\n') +
      seriesData.characters.map((c) => `  - ${c}`).join('\n')
    : '';

  if (isFr) {
    return `Tu es un scénariste professionnel qui travaille sur une série.

Série : "${seriesData.title}"
Synopsis général : ${seriesData.synopsis}
${charContext}

Épisodes déjà générés :
${prevContext}

Écris le scénario de l'épisode ${epNum} intitulé "${title}".

L'épisode doit s'inscrire dans la continuité de la série, en respectant les personnages et l'univers établis.
Le scénario doit avoir exactement ${nScenes} scènes de ${sceneDur} secondes chacune (durée totale : ${duration} minutes).

Pour chaque scène, fournis :
- setting : description du décor en anglais (30 mots max, style illustratif, lumière douce, couleurs vives)
- action : ce que font les personnages (en français, 1-2 phrases)
- voice : texte de la voix off en français (lu en ${Math.round(sceneDur * 0.4)} mots max, naturel, narratif)
- summary_fr : résumé de la scène en 1 phrase (pour le contexte des futurs épisodes)

Réponds UNIQUEMENT en JSON valide :
{
  "title": "${title}",
  "episode": ${epNum},
  "genre": "serie",
  "lang": "fr",
  "characters": ["liste des personnages présents dans cet épisode"],
  "episode_summary": "résumé de l'épisode entier en 2-3 phrases",
  "scenes": [
    { "id": 1, "setting": "...", "action": "...", "voice": "...", "summary_fr": "..." },
    ...
  ]
}`;
  }

  return `You are a professional screenwriter working on a series.

Series: "${seriesData.title}"
Overall synopsis: ${seriesData.synopsis}
${charContext}

Episodes already generated:
${prevContext}

Write the script for episode ${epNum} titled "${title}".

The episode must fit into the series continuity, respecting established characters and the series world.
The script must have exactly ${nScenes} scenes of ${sceneDur} seconds each (total duration: ${duration} minutes).

For each scene, provide:
- setting: scene description in English (30 words max, illustrative style, soft light, vivid colors)
- action: what the characters do (1-2 sentences)
- voice: voice-over text in English (read in ${Math.round(sceneDur * 0.4)} words max, natural, narrative)
- summary_fr: one-sentence scene summary (for future episode context)

Reply ONLY with valid JSON:
{
  "title": "${title}",
  "episode": ${epNum},
  "genre": "serie",
  "lang": "en",
  "characters": ["list of characters in this episode"],
  "episode_summary": "2-3 sentence episode summary",
  "scenes": [
    { "id": 1, "setting": "...", "action": "...", "voice": "...", "summary_fr": "..." },
    ...
  ]
}`;
}

async function generateScript(params, seriesData, prevEpisodes) {
  const lang = params.lang || 'fr';
  const isSerie = params.genre === 'serie' && seriesData;
  const prompt = isSerie
    ? buildEpisodePrompt(params, seriesData, prevEpisodes || [], lang)
    : buildPrompt(params, lang);
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${SCRIPT_MODEL}:generateContent`;
  const body = {
    contents: [{ role: 'user', parts: [{ text: prompt }] }],
    generationConfig: { temperature: 0.8, maxOutputTokens: 4096 },
  };
  const r = await fetch(url, {
    method: 'POST', signal: AbortSignal.timeout(45000),
    headers: { 'content-type': 'application/json', 'x-goog-api-key': GEMINI_API_KEY.value() },
    body: JSON.stringify(body),
  });
  if (!r.ok) throw new Error('gemini_' + r.status);
  const d = await r.json();
  const text = d.candidates?.[0]?.content?.parts?.[0]?.text || '';
  const match = text.match(/\{[\s\S]*\}/);
  if (!match) throw new Error('no_json');
  return JSON.parse(match[0]);
}

async function dailyCount(col, key) {
  const today = new Date().toISOString().slice(0, 10);
  const ref = db().collection(col).doc(today);
  const snap = await ref.get();
  return snap.exists ? (snap.data()[key] || 0) : 0;
}

async function bumpDaily(col, key) {
  const today = new Date().toISOString().slice(0, 10);
  await db().collection(col).doc(today).set({ [key]: FieldValue.increment(1) }, { merge: true });
}

// ── Créer ou rejoindre une série ────────────────────────────────────────────
async function getOrCreateSeries(uid, params) {
  if (params.seriesId) {
    const snap = await db().collection('FilmSeries').doc(params.seriesId).get();
    if (!snap.exists || snap.data().uid !== uid) return null;
    return { id: params.seriesId, ...snap.data() };
  }
  if (params.genre !== 'serie') return null;
  // Créer une nouvelle série
  const ref = db().collection('FilmSeries').doc();
  const data = {
    uid,
    title: clamp(params.title || '', 80),
    synopsis: clamp(params.synopsis || '', 3000),
    genre: 'serie',
    lang: params.lang || 'fr',
    duration: [2, 3].includes(+params.duration) ? +params.duration : 2,
    episodeCount: 0,
    characters: [],
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };
  await ref.set(data);
  return { id: ref.id, ...data };
}

// Charger les N derniers épisodes d'une série (pour le contexte)
async function loadPrevEpisodes(seriesId, limit = 3) {
  const snap = await db().collection('FilmJobs')
    .where('seriesId', '==', seriesId)
    .where('status', '==', 'done')
    .orderBy('episodeNumber', 'desc')
    .limit(limit)
    .get();
  return snap.docs
    .map((d) => ({ episodeNumber: d.data().episodeNumber, title: d.data().title, summary: d.data().episodeSummary || d.data().synopsis }))
    .reverse();
}

// ── createFilm principal ────────────────────────────────────────────────────
async function createFilm(u, params) {
  const duration = [2, 3].includes(+params.duration) ? +params.duration : 2;
  const title = clamp(params.title || '', 80);
  const synopsis = clamp(params.synopsis || '', 3000); // jusqu'à 3000 chars (~500 mots)
  const genre = ['film', 'serie', 'animation', 'conte'].includes(params.genre) ? params.genre : 'film';
  const lang = ['fr', 'en'].includes(params.lang) ? params.lang : 'fr';
  const watermark = params.watermark !== false; // true par défaut → -1 crédit
  const customAudioPath = clamp(params.customAudioPath || '', 500) || null;
  const cost = calcCost(duration, watermark, !!customAudioPath);

  if (!title || !synopsis) return { status: 400, error: 'missing_fields' };

  // Vérification des quotas
  const userCount = await dailyCount('FilmUserStats', u.uid);
  if (userCount >= FILM_LIMITS.userPerDay) return { status: 429, error: 'rate_user' };
  const globalCount = await dailyCount('FilmGlobalStats', 'count');
  if (globalCount >= FILM_LIMITS.globalPerDay) return { status: 429, error: 'rate_global' };

  // Vérification et débit des crédits
  const ok = await spendCredits(u.uid, cost, 'film_' + duration + 'min');
  if (!ok) return { status: 402, error: 'no_credits' };

  // Série : créer ou récupérer
  let seriesData = null;
  let episodeNumber = null;
  if (genre === 'serie') {
    seriesData = await getOrCreateSeries(u.uid, { ...params, title, synopsis, lang, duration });
    if (params.seriesId && !seriesData) return { status: 404, error: 'series_not_found' };
    episodeNumber = (seriesData.episodeCount || 0) + 1;
  }

  // Création du job Firestore
  const jobRef = db().collection('FilmJobs').doc();
  const jobData = {
    uid: u.uid,
    email: u.email,
    title,
    synopsis,
    genre,
    lang,
    duration,
    cost,
    watermark,
    status: 'creating',
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };
  if (customAudioPath) jobData.customAudioPath = customAudioPath;
  if (seriesData) {
    jobData.seriesId = seriesData.id;
    jobData.episodeNumber = episodeNumber;
  }
  await jobRef.set(jobData);

  // Compteurs
  await bumpDaily('FilmUserStats', u.uid);
  await bumpDaily('FilmGlobalStats', 'count');
  await bump({ film_jobs: 1, [`film_dur.${duration}min`]: 1 });

  // Génération du scénario en arrière-plan (non bloquant)
  processFilm(jobRef.id, { title, synopsis, genre, lang, duration }, seriesData).catch((e) => {
    console.error('processFilm error', jobRef.id, e.message);
  });

  return { status: 200, jobId: jobRef.id, seriesId: seriesData ? seriesData.id : null, cost };
}

function getRenderUrl() {
  const project = process.env.GCLOUD_PROJECT || 'slashatlas-studio';
  return `https://europe-west1-${project}.cloudfunctions.net/slashatlasFilm`;
}

async function processFilm(jobId, params, seriesData) {
  const jobRef = db().collection('FilmJobs').doc(jobId);

  try {
    // Charger les épisodes précédents si c'est une série
    let prevEpisodes = [];
    if (seriesData) {
      prevEpisodes = await loadPrevEpisodes(seriesData.id, 3);
    }

    // Étape 1 : Scénario (Gemini ~10-15s)
    const script = await generateScript(params, seriesData, prevEpisodes);

    // Mettre à jour les métadonnées de la série avec les personnages extraits
    if (seriesData && script.characters && script.characters.length) {
      const allChars = Array.from(new Set([
        ...(seriesData.characters || []),
        ...script.characters,
      ])).slice(0, 20);
      await db().collection('FilmSeries').doc(seriesData.id).update({
        characters: allChars,
        episodeCount: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      });
    } else if (seriesData) {
      await db().collection('FilmSeries').doc(seriesData.id).update({
        episodeCount: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    // Stocker le résumé de l'épisode dans le job
    const episodeSummary = script.episode_summary || null;
    if (episodeSummary) {
      await jobRef.update({ episodeSummary });
    }

    // Préparer le token de rendu interne (protège slashatlasFilm contre les appels non autorisés)
    const renderToken = crypto.randomBytes(16).toString('hex');
    await jobRef.update({ status: 'pending_render', script, renderToken, updatedAt: FieldValue.serverTimestamp() });

    // Étape 2 : Déclencher le rendu (fire-and-forget vers slashatlasFilm)
    const renderUrl = getRenderUrl();
    fetch(renderUrl, {
      method: 'POST',
      signal: AbortSignal.timeout(8000),
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ jobId, token: renderToken }),
    }).catch((e) => console.log('trigger film render', e.message));

  } catch (e) {
    console.error('processFilm step error', jobId, e.message);
    await jobRef.update({ status: 'error', error: e.message, updatedAt: FieldValue.serverTimestamp() });
    const snap = await jobRef.get();
    if (snap.exists) {
      const { uid, cost } = snap.data();
      if (uid && cost) {
        const { addCredits } = require('./studio');
        await addCredits(uid, cost, 'film_refund_' + jobId).catch(() => {});
      }
    }
  }
}

async function getFilmStatus(u, jobId) {
  if (!jobId) return { status: 400, error: 'missing_jobId' };
  const ref = db().collection('FilmJobs').doc(jobId);
  const snap = await ref.get();
  if (!snap.exists) return { status: 404, error: 'not_found' };
  const d = snap.data();
  if (d.uid !== u.uid) return { status: 403, error: 'forbidden' };
  let videoUrl = d.videoUrl || null;
  if (d.status === 'done' && d.storagePath && !videoUrl) {
    try {
      const [url] = await getStorage().bucket().file(d.storagePath).getSignedUrl({
        action: 'read',
        expires: Date.now() + 7 * 24 * 60 * 60 * 1000, // 7 jours
      });
      videoUrl = url;
      await ref.update({ videoUrl });
    } catch (e) {
      console.error('getSignedUrl film', e.message);
    }
  }
  return {
    status: 200,
    jobStatus: d.status,
    videoUrl,
    title: d.title,
    duration: d.duration,
    message: d.error || null,
    seriesId: d.seriesId || null,
    episodeNumber: d.episodeNumber || null,
  };
}

// ── Lister les séries de l'utilisateur ─────────────────────────────────────
async function listUserSeries(u) {
  const snap = await db().collection('FilmSeries')
    .where('uid', '==', u.uid)
    .orderBy('updatedAt', 'desc')
    .limit(20)
    .get();
  const series = snap.docs.map((d) => {
    const data = d.data();
    return {
      id: d.id,
      title: data.title,
      synopsis: data.synopsis,
      genre: data.genre,
      lang: data.lang,
      duration: data.duration,
      episodeCount: data.episodeCount || 0,
      characters: data.characters || [],
      updatedAt: data.updatedAt ? data.updatedAt.toDate().toISOString() : null,
    };
  });
  return { status: 200, series };
}

// Télécharge le fichier MP4 d'un film terminé
async function getFilmFile(u, jobId) {
  if (!jobId) return null;
  const snap = await db().collection('FilmJobs').doc(jobId).get();
  if (!snap.exists) return null;
  const d = snap.data();
  if (d.uid !== u.uid || d.status !== 'done' || !d.storagePath) return null;
  const [buf] = await getStorage().bucket().file(d.storagePath).download().catch(() => [null]);
  return buf ? { buf, title: d.title || 'film' } : null;
}

module.exports = { createFilm, getFilmStatus, getFilmFile, listUserSeries, FILM_COST, calcCost, WATERMARK_DISCOUNT, CUSTOM_AUDIO_DISCOUNT, SECRETS: [GEMINI_API_KEY] };
