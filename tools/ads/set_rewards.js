// Réglages de la page Récompenses (Firestore AppConfig/rewards), sans mise à jour de l'app.
// Usage : GOOGLE_APPLICATION_CREDENTIALS=... node set_rewards.js '{"coinsMaxPerWeek":10}'
//         (fusionne avec l'existant ; sans argument : affiche la configuration)
// Clés : enabled (interrupteur général), maxAdsPerDay, premiumMaxHoursPerWeek (24 par défaut),
//        coinsMaxPerWeek (20 par défaut), offers: { <id>: { enabled, ads, cap, hours, coins, count } }
// Offres : premium_5h, premium_10h, premium_24h, adfree_24h, coins_2, flame_shield, stickers_3, photos_3
// Exemples : désactiver les pièces      '{"offers":{"coins_2":{"enabled":false}}}'
//            Premium 24 h = 8 pubs      '{"offers":{"premium_24h":{"ads":8}}}'
const admin = require('../../functions/node_modules/firebase-admin');
admin.initializeApp({ credential: admin.credential.cert(require(process.env.GOOGLE_APPLICATION_CREDENTIALS)), projectId: 'afrolooki' });
(async () => {
  const ref = admin.firestore().collection('AppConfig').doc('rewards');
  if (process.argv[2]) await ref.set(JSON.parse(process.argv[2]), { merge: true });
  console.log(JSON.stringify((await ref.get()).data() ?? { note: 'aucun réglage : valeurs par défaut du serveur' }, null, 2));
})().catch((e) => { console.error(e); process.exit(1); });
