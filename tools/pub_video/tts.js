const { GoogleAuth } = require('/home/user/afrolook/functions/node_modules/google-auth-library');
const fs = require('fs');
const LINES = {
  l1: "Tes vues. Tes likes. Ça vaut de l'argent.",
  l2: "Ailleurs, tu postes... et ce sont eux qui encaissent.",
  l3: "Sur Afrolook, c'est toi qui es payé.",
  l4: "Chaque palier de vues. Chaque like. Chaque cadeau en direct.",
  l5: "Tes gains s'affichent. Tu les retires.",
  l6: "Afrolook. Le réseau qui te paie.",
  l7: "Télécharge-le maintenant. Gratuit sur Google Play et sur l'App Store.",
};
(async () => {
  const auth = new GoogleAuth({ keyFile: process.env.GOOGLE_APPLICATION_CREDENTIALS, scopes: ['https://www.googleapis.com/auth/cloud-platform'] });
  const t = (await (await auth.getClient()).getAccessToken()).token;
  const voice = process.argv[2] || 'fr-FR-Chirp3-HD-Puck';
  for (const [k, text] of Object.entries(LINES)) {
    const r = await fetch('https://texttospeech.googleapis.com/v1/text:synthesize', {
      method: 'POST', headers: { Authorization: 'Bearer ' + t, 'x-goog-user-project': 'afrolooki', 'Content-Type': 'application/json' },
      body: JSON.stringify({ input: { text }, voice: { languageCode: 'fr-FR', name: voice }, audioConfig: { audioEncoding: 'LINEAR16', sampleRateHertz: 24000, speakingRate: 1.05 } }),
    });
    const j = await r.json();
    if (!j.audioContent) { console.log(k, r.status, JSON.stringify(j).slice(0, 300)); continue; }
    fs.writeFileSync(`vo/${k}.wav`, Buffer.from(j.audioContent, 'base64'));
    console.log(k, 'ok');
  }
})();
