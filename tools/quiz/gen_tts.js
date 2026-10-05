// Fabrique les voix du quiz : un petit fichier mp3 par question et par réponse, en voix féminine (f) et masculine (m),
// envoyés dans Storage (quiz_tts/{f|m}/{empreinte}.mp3). L'app les retrouve grâce à l'empreinte du texte (voir quiz_voice.dart).
// Nécessite l'API Cloud Text-to-Speech et un compte de service (GOOGLE_APPLICATION_CREDENTIALS).
// Usage : node tools/quiz/gen_tts.js            (génère ce qui manque)
//         node tools/quiz/gen_tts.js --check     (compte seulement)
const path = require('path');
const { GoogleAuth } = require(path.join(__dirname, '../../functions/node_modules/google-auth-library'));
const { Storage } = require(path.join(__dirname, '../../functions/node_modules/@google-cloud/storage'));

const BUCKET = 'afrolooki.appspot.com';
const VOICES = { f: 'fr-FR-Chirp3-HD-Kore', m: 'fr-FR-Chirp3-HD-Orus' };
const SAMPLE = 'Bonjour ! Je suis ton guide Afrolook. Écoute bien la question.';

/** Empreinte FNV-1a 64 bits du texte (UTF-8), en 16 caractères hexadécimaux : identique dans l'app (Dart). */
function hash(text) {
  let h = 0xcbf29ce484222325n;
  for (const b of Buffer.from(text.trim(), 'utf8')) {
    h ^= BigInt(b);
    h = BigInt.asUintN(64, h * 0x100000001b3n);
  }
  return h.toString(16).padStart(16, '0');
}
module.exports = { hash };
if (require.main !== module) return;

(async () => {
  const levels = require('./levels.json');
  const texts = new Set(['A.', 'B.', 'C.', 'D.', SAMPLE]);
  for (const l of levels) for (const q of l.questions) { texts.add(q.q.trim()); q.o.forEach((o) => texts.add(o.trim())); }
  const storage = new Storage({ keyFilename: process.env.GOOGLE_APPLICATION_CREDENTIALS, projectId: 'afrolooki' });
  const bucket = storage.bucket(BUCKET);
  const have = new Set();
  for (const v of Object.keys(VOICES)) {
    const [files] = await bucket.getFiles({ prefix: `quiz_tts/${v}/` });
    files.forEach((f) => have.add(f.name));
  }
  const todo = [];
  for (const v of Object.keys(VOICES)) for (const t of texts) if (!have.has(`quiz_tts/${v}/${hash(t)}.mp3`)) todo.push([v, t]);
  console.log(`${texts.size} textes, ${have.size} fichiers déjà là, ${todo.length} à fabriquer`);
  if (process.argv.includes('--check')) return;

  const auth = new GoogleAuth({ keyFile: process.env.GOOGLE_APPLICATION_CREDENTIALS, scopes: ['https://www.googleapis.com/auth/cloud-platform'] });
  const client = await auth.getClient();
  const synth = async (voice, text) => {
    for (let attempt = 0; attempt < 6; attempt++) {
      const token = (await client.getAccessToken()).token;
      const r = await fetch('https://texttospeech.googleapis.com/v1/text:synthesize', {
        method: 'POST',
        headers: { Authorization: 'Bearer ' + token, 'x-goog-user-project': 'afrolooki', 'Content-Type': 'application/json' },
        body: JSON.stringify({
          input: { text },
          voice: { languageCode: 'fr-FR', name: VOICES[voice] },
          audioConfig: { audioEncoding: 'MP3', sampleRateHertz: 24000, speakingRate: 1.05 },
        }),
      });
      if (r.ok) return Buffer.from((await r.json()).audioContent, 'base64');
      if (r.status === 429 || r.status >= 500) { await new Promise((s) => setTimeout(s, 4000 * (attempt + 1))); continue; }
      throw new Error(`${r.status} ${(await r.text()).slice(0, 200)}`);
    }
    throw new Error('trop d\'essais');
  };
  let done = 0, fail = 0;
  const queue = todo.slice();
  const worker = async () => {
    while (queue.length) {
      const [v, t] = queue.shift();
      try {
        const mp3 = await synth(v, t);
        await bucket.file(`quiz_tts/${v}/${hash(t)}.mp3`).save(mp3, { resumable: false, contentType: 'audio/mpeg', metadata: { cacheControl: 'public, max-age=31536000' } });
        done++;
      } catch (e) { fail++; console.log('échec', v, JSON.stringify(t.slice(0, 40)), e.message); }
      if ((done + fail) % 200 === 0) console.log(`${done + fail}/${todo.length} (échecs : ${fail})`);
    }
  };
  await Promise.all(Array.from({ length: 12 }, worker));
  console.log(`terminé : ${done} fabriqués, ${fail} échecs`);
})();
