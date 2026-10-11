const { GoogleAuth } = require('/home/user/afrolook/functions/node_modules/google-auth-library');
(async () => {
  const auth = new GoogleAuth({ keyFile: process.env.GOOGLE_APPLICATION_CREDENTIALS, scopes: ['https://www.googleapis.com/auth/cloud-platform'] });
  const t = (await (await auth.getClient()).getAccessToken()).token;
  for (const lang of ['en-US', 'en-GB']) {
    const v = await fetch(`https://texttospeech.googleapis.com/v1/voices?languageCode=${lang}`, { headers: { Authorization: 'Bearer ' + t, 'x-goog-user-project': 'slashatlas-studio' } });
    const j = await v.json();
    console.log(lang, v.status, j.error ? JSON.stringify(j.error).slice(0, 200) : (j.voices || []).filter((x) => /Chirp3-HD/.test(x.name)).map((x) => x.name.replace(/.*Chirp3-HD-/, '') + ':' + x.ssmlGender[0]).join(' '));
  }
})();
