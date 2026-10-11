// Voix off (Google Cloud Text-to-Speech, voix Chirp 3 HD). Usage : node tts.cjs <fr|en> <Voix>
const { GoogleAuth } = require('/home/user/afrolook/functions/node_modules/google-auth-library');
const fs = require('fs');
const LINES_AD1 = {
  en: { code: 'en-US', l: {
    l1: ['Plain product photo? [pause short] Watch this.', 3.0],
    l2: ['Turn it into a pro ad poster... [pause short] in seconds.', 3.6],
    l3: ['Copy a free command. Paste it with your photo in ChatGPT or Gemini. [pause short] Done.', 5.4],
    l4: ['Two hundred twenty-five free commands. Fashion, food, real estate, beauty, events, and more.', 6.0],
    l5: ['Try it free at Slash Atlas dot com. [pause short] No sign-up needed.', 5.2] } },
  fr: { code: 'fr-FR', l: {
    l1: ['Une photo de produit toute plate ? [pause short] Regardez ça.', 3.0],
    l2: ['Transformez-la en affiche pro... [pause short] en quelques secondes.', 3.6],
    l3: ['Copiez une commande gratuite. Collez-la avec votre photo dans ChatGPT ou Gemini. [pause short] C’est fait.', 5.4],
    l4: ['Deux cent vingt-cinq commandes gratuites. Mode, food, immobilier, beauté, événements, et plus encore.', 6.3],
    l5: ['Essayez gratuitement sur Slash Atlas point com. [pause short] Sans inscription.', 5.2] } },
};
const LINES_AD2 = {
  en: { code: 'en-US', l: {
    l1: ['This is how most people make AI posters.', 2.3],
    l2: ['Pick a photo. Write a prompt. [pause short] Not good. Write a longer one. [pause short] Still not right. Write an even longer one... [pause short] and the result is just average.', 8.7],
    l3: ['There is a faster way.', 2.0],
    l4: ['On Slash Atlas, the prompts are ready. Copy a free command. Paste it with your photo. [pause short] Your poster is done, in seconds.', 7.0],
    l5: ['Test it on our platform, or in ChatGPT, Gemini, or Midjourney. Two hundred twenty-five free commands.', 5.6],
    l6: ['Slash Atlas dot com. [pause short] Free, no sign-up.', 4.6] } },
  fr: { code: 'fr-FR', l: {
    l1: ['Voilà comment la plupart des gens font leurs affiches IA.', 2.4],
    l2: ['On choisit une photo. On écrit un prompt. [pause short] Bof. On en écrit un plus long. [pause short] Toujours pas ça. Encore plus long... [pause short] et le résultat reste moyen.', 8.7],
    l3: ['Il y a plus rapide.', 2.0],
    l4: ['Sur Slash Atlas, les prompts sont déjà prêts. Copiez une commande gratuite. Collez-la avec votre photo. [pause short] Votre affiche est prête, en quelques secondes.', 7.0],
    l5: ['Testez-la sur notre plateforme, ou dans ChatGPT, Gemini ou Midjourney. Deux cent vingt-cinq commandes gratuites.', 5.6],
    l6: ['Slash Atlas point com. [pause short] Gratuit, sans inscription.', 4.6] } },
};
const LINES_AD3 = {
  fr: { code: 'fr-FR', l: {
    l1: ['Vous vendez de la mode, des cosmétiques, ou vous créez des looks ? [pause short] Voilà comment la plupart des gens font leurs visuels avec l’IA.', 6.2],
    l2: ['On choisit une photo. On écrit un prompt : fais une belle affiche pour ma robe. [pause short] Bof. Alors on en écrit un plus long. [pause short] Toujours pas ça. On ajoute la lumière, le fond, le style, le format... [pause short] et un quart d’heure plus tard, le résultat reste moyen.', 17.0],
    l3: ['Il y a bien plus rapide.', 3.2],
    l4: ['Sur Slash Atlas, les prompts sont déjà prêts. [pause short] Une robe ? Copiez la commande, collez-la avec votre photo : l’affiche est prête. [pause short] Un soin de peau ? Même geste, un visuel premium en quelques secondes. [pause short] Un look complet ? Une page de lookbook élégante, sans photographe.', 19.4],
    l5: ['Plus de six cent cinquante commandes gratuites, en trente-deux catégories. Mode, beauté, produits, food, immobilier, événements, marque, vidéo publicitaire. [pause short] Des logos en verre, des planches de poses, des couvertures de magazine, des pubs prêtes à publier. En français et en anglais.', 19.4],
    l5b: ['Pour la mode : affiche de collection, lookbook, tenue de rue, robe de mariée. [pause short] Pour la beauté : soin du visage, maquillage, coiffure, ongles, parfum. [pause short] Et de nouveaux visuels s’ajoutent au fil des jours.', 12.2],
    l6: ['Pas envie de coller ? Cliquez sur Générer ici : envoyez votre photo, et obtenez votre visuel directement sur le site. Des crédits payables par mobile money, dès cinq cents francs CFA.', 11.4],
    l7: ['Slash Atlas point com. Gratuit, sans inscription pour copier. [pause short] Essayez, puis dites-nous ce que vous en pensez. Et si vous voulez collaborer, écrivez-nous.', 8.4] } },
};
const LINES = process.env.AD === '3' ? LINES_AD3 : (process.env.AD === '2' ? LINES_AD2 : LINES_AD1);
function wavInfo(buf) {
  const pcm = new Int16Array(buf.buffer.slice(buf.byteOffset + 44, buf.byteOffset + buf.length));
  let a = 0, b = pcm.length - 1; const th = 400;
  while (a < b && Math.abs(pcm[a]) < th) a++; while (b > a && Math.abs(pcm[b]) < th) b--;
  return { pcm, a: Math.max(0, a - 1200), b: Math.min(pcm.length - 1, b + 2400) };
}
function writeWav(path, pcm) {
  const h = Buffer.alloc(44); h.write('RIFF', 0); h.writeUInt32LE(36 + pcm.length * 2, 4); h.write('WAVEfmt ', 8); h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(1, 22);
  h.writeUInt32LE(24000, 24); h.writeUInt32LE(48000, 28); h.writeUInt16LE(2, 32); h.writeUInt16LE(16, 34); h.write('data', 36); h.writeUInt32LE(pcm.length * 2, 40);
  fs.writeFileSync(path, Buffer.concat([h, Buffer.from(pcm.buffer, pcm.byteOffset, pcm.length * 2)]));
}
(async () => {
  const [lang, voice] = process.argv.slice(2); const L = LINES[lang];
  const auth = new GoogleAuth({ keyFile: process.env.GOOGLE_APPLICATION_CREDENTIALS, scopes: ['https://www.googleapis.com/auth/cloud-platform'] });
  const t = (await (await auth.getClient()).getAccessToken()).token;
  const dir = `vo${process.env.AD === '3' ? '3' : (process.env.AD === '2' ? '2' : '')}_${lang}_${voice}`; fs.mkdirSync(dir, { recursive: true });
  let chars = 0;
  for (const [k, [text, win]] of Object.entries(L.l)) {
    let rate = 1.0, dur = 99, out = null;
    for (let tries = 0; tries < 4 && dur > win; tries++) {
      const r = await fetch('https://texttospeech.googleapis.com/v1/text:synthesize', { method: 'POST', headers: { Authorization: 'Bearer ' + t, 'x-goog-user-project': 'slashatlas-studio', 'Content-Type': 'application/json' },
        body: JSON.stringify({ input: { markup: text }, voice: { languageCode: L.code, name: `${L.code}-Chirp3-HD-${voice}` }, audioConfig: { audioEncoding: 'LINEAR16', sampleRateHertz: 24000, speakingRate: rate } }) });
      const j = await r.json(); chars += text.length;
      if (!j.audioContent) { console.log(k, r.status, JSON.stringify(j).slice(0, 300)); break; }
      const { pcm, a, b } = wavInfo(Buffer.from(j.audioContent, 'base64')); out = pcm.slice(a, b + 1); dur = out.length / 24000;
      if (dur > win) rate = Math.min(1.3, rate * (dur / win) * 1.03);
    }
    if (out) { writeWav(`${dir}/${k}.wav`, out); console.log(lang, voice, k, dur.toFixed(2) + 's / ' + win + 's', 'rate', rate.toFixed(2)); }
  }
  console.log('caractères ≈', chars);
})();
