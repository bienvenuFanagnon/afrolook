/**
 * Initialise le document /config/monetization dans Firestore.
 * Lance avec : node functions/scripts/init_monetization_config.js
 * Nécessite : firebase login (Application Default Credentials)
 */

const admin = require("firebase-admin");

const PROJECT_ID = "afrolooki";

admin.initializeApp({ projectId: PROJECT_ID });
const db = admin.firestore();

const config = {
  // Taux de base max par vue (en FCFA). Modifiable à tout moment sans redéployer.
  baseViewRate: 1.0,

  // Paliers de score créateur → fraction du taux de base
  scoreTiers: [
    { minScore: 80, multiplier: 1.00, label: "Élite" },
    { minScore: 50, multiplier: 0.80, label: "Expert" },
    { minScore: 25, multiplier: 0.60, label: "Avancé" },
    { minScore: 10, multiplier: 0.40, label: "Standard" },
    { minScore:  0, multiplier: 0.20, label: "Débutant" },
  ],

  updatedAt: Date.now(),
};

async function run() {
  const ref = db.collection("config").doc("monetization");
  const snap = await ref.get();

  if (snap.exists) {
    console.log("⚠️  Document /config/monetization existe déjà :");
    console.log(JSON.stringify(snap.data(), null, 2));
    console.log("\nAucune modification. Supprime le document manuellement si tu veux le réinitialiser.");
    process.exit(0);
  }

  await ref.set(config);
  console.log("✅ Document /config/monetization créé avec succès :");
  console.log(JSON.stringify(config, null, 2));
  process.exit(0);
}

run().catch((err) => {
  console.error("❌ Erreur :", err);
  process.exit(1);
});
