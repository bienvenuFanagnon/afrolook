// Réglages publicitaires (Firestore AppConfig/ads) sans publier de mise à jour de l'app.
// Usage : GOOGLE_APPLICATION_CREDENTIALS=... node set_config.js '{"enabled":true,"rolloutPercent":10}'
//         (fusionne avec la configuration existante ; sans argument : affiche la configuration)
// Clés : enabled, enabledAndroid, enabledIos, rolloutPercent (0-100), testMode, nativeEvery, nativeStartAfter,
//        admobEvery (2 = 1 emplacement sur 2 à AdMob), freeSessions, detailBanner, detailMrec, commentsNative,
//        listsNative, interstitialEnabled, interstitialEveryVideos, interstitialMinGapMinutes,
//        interstitialMaxPerDay, interstitialWarmupMinutes, rewardedEnabled, rewardedMaxPerDay,
//        units: {android:{banner,native,interstitial,rewarded}, ios:{...}}
const admin = require('../../functions/node_modules/firebase-admin');
admin.initializeApp({ credential: admin.credential.cert(require(process.env.GOOGLE_APPLICATION_CREDENTIALS)), projectId: 'afrolooki' });
(async () => {
  const ref = admin.firestore().collection('AppConfig').doc('ads');
  if (process.argv[2]) await ref.set(JSON.parse(process.argv[2]), { merge: true });
  console.log(JSON.stringify((await ref.get()).data() ?? null, null, 2));
})().catch((e) => { console.error(e); process.exit(1); });
