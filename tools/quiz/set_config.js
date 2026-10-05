// Réglages du quiz (Firestore AppConfig/quiz) sans publier de mise à jour de l'app.
// Usage : GOOGLE_APPLICATION_CREDENTIALS=... node set_config.js '{"dailyPointsCap":300}'
//         (fusionne avec la configuration existante ; sans argument : affiche la configuration)
// Clés : enabled, heartsMax, heartRegenMinutes, pointsPerCorrect, perfectBonus, passMin, dailyPointsCap,
//        dailyCorrect, dailyBonus, doubleMaxPerDay, refillMaxPerDay, minAnswerMs, shieldMax,
//        shop: { <objet>: { price, enabled } },
//        interstitialEveryLevels (pub plein écran après N niveaux), interstitialMaxPerDay,
//        adsEnabled (pubs dans le quiz), feedCardEnabled (carte dans le fil)
const admin = require('../../functions/node_modules/firebase-admin');
admin.initializeApp({ credential: admin.credential.cert(require(process.env.GOOGLE_APPLICATION_CREDENTIALS)), projectId: 'afrolooki' });
(async () => {
  const ref = admin.firestore().collection('AppConfig').doc('quiz');
  if (process.argv[2]) await ref.set(JSON.parse(process.argv[2]), { merge: true });
  console.log(JSON.stringify((await ref.get()).data() ?? null, null, 2));
})().catch((e) => { console.error(e); process.exit(1); });
