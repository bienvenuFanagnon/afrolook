/**
 * Script admin : backfill unreadPosts pour les 40 derniers jours.
 * Lance avec : node functions/scripts/backfill_unread.js
 * Nécessite d'être connecté via : firebase login
 */

const admin = require("firebase-admin");
const { GoogleAuth } = require("google-auth-library");

const PROJECT_ID = "afrolooki";
const DAYS_BACK = 40;
const BATCH_SIZE = 400;
const ALLOWED_TYPES = ["POST", "CHRONIQUE", "CHALLENGE", "CHALLENGEPARTICIPATION"];

async function main() {
  // Initialiser avec Application Default Credentials (firebase login)
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: PROJECT_ID,
  });

  const db = admin.firestore();

  const cutoffMs = Date.now() - DAYS_BACK * 24 * 60 * 60 * 1000;
  const cutoffMicros = cutoffMs * 1000;

  console.log(`🔄 Backfill unreadPosts — ${DAYS_BACK} derniers jours`);
  console.log(`   Cutoff : ${new Date(cutoffMs).toISOString()}`);

  // Charger tous les posts récents
  const postsSnap = await db.collection("Posts")
    .where("created_at", ">=", cutoffMicros)
    .orderBy("created_at", "desc")
    .get();

  const posts = postsSnap.docs.filter(d => {
    const data = d.data();
    return ALLOWED_TYPES.includes(data.type) || ALLOWED_TYPES.includes(data.dataType);
  });

  console.log(`📦 ${posts.length} posts éligibles trouvés`);

  let totalWrites = 0;
  let errors = 0;
  const creatorCache = {};

  for (let idx = 0; idx < posts.length; idx++) {
    const postDoc = posts[idx];
    const post = postDoc.data();
    const postId = postDoc.id;
    const creatorId = post.user_id ?? "";
    if (!creatorId) continue;

    const createdAtMs = post.created_at
      ? Math.floor(post.created_at / 1000)
      : cutoffMs;

    // Cache des abonnés
    if (!(creatorId in creatorCache)) {
      try {
        const creatorDoc = await db.collection("Users").doc(creatorId).get();
        creatorCache[creatorId] = creatorDoc.data()?.userAbonnesIds ?? [];
      } catch {
        creatorCache[creatorId] = [];
      }
    }

    const followerIds = creatorCache[creatorId];
    if (followerIds.length === 0) continue;

    // Fan-out en batches
    for (let i = 0; i < followerIds.length; i += BATCH_SIZE) {
      const chunk = followerIds.slice(i, i + BATCH_SIZE);
      const batch = db.batch();
      for (const followerId of chunk) {
        batch.set(
          db.collection("Users").doc(followerId),
          { unreadPosts: { [postId]: createdAtMs } },
          { merge: true }
        );
      }
      try {
        await batch.commit();
        totalWrites += chunk.length;
      } catch (err) {
        console.error(`❌ Lot échoué (post ${postId}) :`, err.message);
        errors++;
      }
    }

    if ((idx + 1) % 20 === 0) {
      console.log(`   ⏳ ${idx + 1}/${posts.length} posts traités, ${totalWrites} écritures...`);
    }
  }

  console.log(`\n✅ Terminé !`);
  console.log(`   Posts traités : ${posts.length}`);
  console.log(`   Écritures Firestore : ${totalWrites}`);
  console.log(`   Erreurs : ${errors}`);

  process.exit(0);
}

main().catch(err => {
  console.error("💥 Erreur fatale :", err);
  process.exit(1);
});
