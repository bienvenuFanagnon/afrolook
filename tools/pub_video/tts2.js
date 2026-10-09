const { GoogleAuth } = require('/home/user/afrolook/functions/node_modules/google-auth-library');
const fs = require('fs');
const LINES = {
  l1: ["Tes vues. Tes likes. [pause short] Ça vaut de l'argent !", 4.4],
  l2: ["Ailleurs, tu postes, tu crées... [pause short] et ce sont eux qui encaissent.", 4.1],
  l3: ["Sur Afrolook, [pause short] c'est toi qui es payé !", 3.5],
  l4: ["Chaque palier de vues. Chaque like. [pause short] Chaque cadeau en direct.", 5.2],
  l5: ["Tes gains s'affichent. Tu les retires.", 2.8],
  l6: ["Afrolook. Le réseau qui te paie.", 2.4],
  l7: ["Télécharge-le maintenant. [pause short] C'est gratuit, sur Google Play et sur l'App Store.", 7.0],
};
function wavInfo(buf){ // LINEAR16 mono 24k avec en-tête
  const pcm = new Int16Array(buf.buffer, buf.byteOffset + 44, (buf.length - 44) >> 1);
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
  const auth = new GoogleAuth({ keyFile: process.env.GOOGLE_APPLICATION_CREDENTIALS, scopes: ['https://www.googleapis.com/auth/cloud-platform'] });
  const t = (await (await auth.getClient()).getAccessToken()).token;
  let chars = 0;
  for (const voice of process.argv.slice(2)) {
    const dir = `vo_${voice}`; fs.mkdirSync(dir, { recursive: true });
    for (const [k, [text, win]] of Object.entries(LINES)) {
      let rate = 1.0, dur = 99, pcmOut = null;
      for (let tries = 0; tries < 3 && dur > win; tries++) {
        const r = await fetch('https://texttospeech.googleapis.com/v1/text:synthesize', {
          method: 'POST', headers: { Authorization: 'Bearer ' + t, 'x-goog-user-project': 'afrolooki', 'Content-Type': 'application/json' },
          body: JSON.stringify({ input: { markup: text }, voice: { languageCode: 'fr-FR', name: `fr-FR-Chirp3-HD-${voice}` }, audioConfig: { audioEncoding: 'LINEAR16', sampleRateHertz: 24000, speakingRate: rate } }) });
        const j = await r.json(); chars += text.length;
        if (!j.audioContent) { console.log(voice, k, r.status, JSON.stringify(j).slice(0, 300)); break; }
        const buf = Buffer.from(j.audioContent, 'base64'); const { pcm, a, b } = wavInfo(buf);
        pcmOut = pcm.slice(a, b + 1); dur = pcmOut.length / 24000;
        if (dur > win) rate = Math.min(1.35, rate * (dur / win) * 1.04);
      }
      if (pcmOut) { writeWav(`${dir}/${k}.wav`, pcmOut); console.log(voice, k, dur.toFixed(2) + 's', 'rate', rate.toFixed(2)); }
    }
  }
  console.log('caractères facturés ≈', chars);
})();
