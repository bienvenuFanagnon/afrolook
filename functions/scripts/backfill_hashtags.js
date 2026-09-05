/**
 * Backfill : ajoute hashtags[] et postInterests sur les posts existants.
 * Lance depuis functions/ :
 *   node scripts/backfill_hashtags.js
 *
 * Idempotent : ne re-traite pas les posts qui ont déjà postInterests.
 * Passer --force pour re-traiter tous les posts.
 */

const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

initializeApp({ projectId: 'afrolooki' });
const db = getFirestore();

const FORCE = process.argv.includes('--force');
const DRY_RUN = process.argv.includes('--dry');

// ─── Tables de correspondance (copiées de commentSuggestions.ts) ─────────────

const HASHTAG_TO_CATEGORY = {
  musique: 'music', music: 'music', son: 'music', chant: 'music', chanson: 'music',
  afrobeat: 'music', afropop: 'music', hiphop: 'music', rap: 'music', rnb: 'music',
  gospel: 'music', ndombolo: 'music', reggae: 'music', zouk: 'music',
  coupedecale: 'music', dj: 'music', djing: 'music', beatmaker: 'music',
  artiste: 'music', concert: 'music', studio: 'music', cover: 'music',
  prod: 'music', freestyle: 'music', clip: 'music', amapiano: 'music',

  sport: 'sport', football: 'sport', foot: 'sport', basket: 'sport', basketball: 'sport',
  fitness: 'sport', gym: 'sport', musculation: 'sport', athletisme: 'sport',
  natation: 'sport', tennis: 'sport', boxe: 'sport', mma: 'sport', combat: 'sport',
  cyclisme: 'sport', velo: 'sport', esport: 'sport', running: 'sport',
  entrainement: 'sport', training: 'sport', coach: 'sport', stade: 'sport',
  rugby: 'sport', handball: 'sport', volleyball: 'sport', crossfit: 'sport',

  danse: 'dance', dance: 'dance', afrodance: 'dance', comedie: 'dance',
  humour: 'dance', sketch: 'dance', theatre: 'dance', spectacle: 'dance',
  comedy: 'dance', standup: 'dance', zumba: 'dance', choreo: 'dance',

  mode: 'fashion', fashion: 'fashion', beaute: 'fashion', beauty: 'fashion',
  look: 'fashion', looks: 'fashion', style: 'fashion', wax: 'fashion',
  pagne: 'fashion', tissage: 'fashion', ootd: 'fashion', outfit: 'fashion',
  maquillage: 'fashion', makeup: 'fashion', skincare: 'fashion',
  coiffure: 'fashion', tresses: 'fashion', cheveux: 'fashion', hair: 'fashion',
  streetwear: 'fashion', couture: 'fashion', robe: 'fashion', tenue: 'fashion',
  bazin: 'fashion', ankara: 'fashion', kente: 'fashion',

  food: 'food', nourriture: 'food', cuisine: 'food', gastronomie: 'food',
  recette: 'food', restaurant: 'food', streetfood: 'food', vegan: 'food',
  patisserie: 'food', dessert: 'food', boisson: 'food', chef: 'food',
  grillade: 'food', attieke: 'food', jollof: 'food', fufu: 'food', plantain: 'food',

  cinema: 'cinema', film: 'cinema', serie: 'cinema', nollywood: 'cinema',
  photo: 'cinema', photographie: 'cinema', video: 'cinema', art: 'cinema',
  dessin: 'cinema', peinture: 'cinema', illustration: 'cinema', animation: 'cinema',
  manga: 'cinema', graphisme: 'cinema', portrait: 'cinema', shooting: 'cinema',
  sculpture: 'cinema', artisanat: 'cinema',

  culture: 'culture', histoire: 'culture', heritage: 'culture', identite: 'culture',
  education: 'culture', science: 'culture', technologie: 'culture', tech: 'culture',
  innovation: 'culture', sante: 'culture', health: 'culture', medecine: 'culture',
  programmation: 'culture', dev: 'culture', code: 'culture', ia: 'culture',
  langues: 'culture', tradition: 'culture', livre: 'culture', afrique: 'culture',

  business: 'business', entrepreneuriat: 'business', startup: 'business',
  investissement: 'business', crypto: 'business', finance: 'business',
  commerce: 'business', marketing: 'business', ecommerce: 'business',
  vente: 'business', freelance: 'business', emploi: 'business', travail: 'business',
  immobilier: 'business', bourse: 'business',

  lifestyle: 'lifestyle', voyage: 'lifestyle', travel: 'lifestyle', tourisme: 'lifestyle',
  nature: 'lifestyle', environnement: 'lifestyle', animaux: 'lifestyle',
  famille: 'lifestyle', enfant: 'lifestyle', religion: 'lifestyle', foi: 'lifestyle',
  politique: 'lifestyle', societe: 'lifestyle', voiture: 'lifestyle', auto: 'lifestyle',
  moto: 'lifestyle', amour: 'lifestyle', couple: 'lifestyle', mariage: 'lifestyle',
  bienetre: 'lifestyle', motivation: 'lifestyle', inspiration: 'lifestyle',

  gaming: 'gaming', jeux: 'gaming', game: 'gaming', gamer: 'gaming',
  smartphone: 'gaming', mobile: 'gaming', console: 'gaming',
  robot: 'gaming', gadget: 'gaming', geek: 'gaming',
};

const TABBAR_TO_CATEGORY = {
  LOOKS: 'fashion',
  SPORT: 'sport',
  GAMER: 'gaming',
  ACTUALITES: 'culture',
  EVENEMENT: 'lifestyle',
  OFFRES: 'business',
};

function extractHashtags(text) {
  if (!text) return [];
  const raw = (text.match(/#(\w+)/g) ?? []).map(h => h.slice(1).toLowerCase());
  return [...new Set(raw)].slice(0, 20);
}

function extractInterests(hashtags, typeTabbar) {
  const matched = new Set();
  for (const tag of hashtags) {
    const cat = HASHTAG_TO_CATEGORY[tag];
    if (cat) matched.add(cat);
  }
  if (typeTabbar) {
    const tabCat = TABBAR_TO_CATEGORY[typeTabbar.toUpperCase()];
    if (tabCat) matched.add(tabCat);
  }
  if (matched.size === 0) matched.add('lifestyle');
  return [...matched].slice(0, 3);
}

async function run() {
  console.log(`=== BACKFILL HASHTAGS ${DRY_RUN ? '(DRY RUN)' : ''} ${FORCE ? '(FORCE)' : ''} ===\n`);

  const ALLOWED_TYPES = ['POST', 'CHRONIQUE', 'CHALLENGE', 'CHALLENGEPARTICIPATION'];
  const BATCH_SIZE = 400;

  let snap;
  if (FORCE) {
    snap = await db.collection('Posts').get();
  } else {
    // Ne traiter que les posts sans postInterests
    snap = await db.collection('Posts').where('postInterests', '==', null).get();
    // Note: Firestore ne supporte pas "field does not exist" directement.
    // On utilise aussi une requête avec postInterests = [] pour couvrir les deux cas.
  }

  // Compléter avec les posts où postInterests est vide []
  const snapEmpty = await db.collection('Posts')
    .where('postInterests', '==', [])
    .get();

  const docsMap = new Map();
  for (const doc of [...snap.docs, ...snapEmpty.docs]) {
    if (!docsMap.has(doc.id)) docsMap.set(doc.id, doc);
  }

  const docs = [...docsMap.values()].filter(d => {
    const t = d.data().type;
    return ALLOWED_TYPES.includes(t);
  });

  console.log(`${docs.length} posts à traiter\n`);

  const hashtagCounts = {};
  let processed = 0;
  let errors = 0;
  let writes = 0;

  for (let i = 0; i < docs.length; i += BATCH_SIZE) {
    const chunk = docs.slice(i, i + BATCH_SIZE);
    const batch = db.batch();

    for (const doc of chunk) {
      const d = doc.data();
      const description = d.description ?? '';
      const typeTabbar = d.typeTabbar ?? '';

      const hashtags = extractHashtags(description);
      const interests = extractInterests(hashtags, typeTabbar);

      if (!DRY_RUN) {
        batch.update(doc.ref, {
          hashtags: hashtags,
          postInterests: interests,
        });
      }

      // Compter les hashtags pour la collection Hashtags
      for (const tag of hashtags) {
        hashtagCounts[tag] = (hashtagCounts[tag] ?? 0) + 1;
      }

      if (i < 10) {
        console.log(`  ${doc.id}: type=${d.type}, typeTabbar=${typeTabbar}, hashtags=[${hashtags.join(',')}], interests=[${interests.join(',')}]`);
      }
    }

    if (!DRY_RUN) {
      try {
        await batch.commit();
        writes += chunk.length;
        console.log(`  Lot ${Math.floor(i / BATCH_SIZE) + 1} commité (${chunk.length} posts)`);
      } catch (err) {
        console.error(`  ❌ Lot ${Math.floor(i / BATCH_SIZE) + 1} échoué:`, err.message);
        errors++;
      }
    }

    processed += chunk.length;
  }

  // Mettre à jour les compteurs de hashtags
  console.log(`\n[Hashtags] ${Object.keys(hashtagCounts).length} hashtags distincts détectés`);
  if (!DRY_RUN && Object.keys(hashtagCounts).length > 0) {
    const tags = Object.entries(hashtagCounts);
    for (let i = 0; i < tags.length; i += 400) {
      const chunk = tags.slice(i, i + 400);
      const batch = db.batch();
      for (const [tag, count] of chunk) {
        batch.set(db.collection('Hashtags').doc(tag), {
          name: tag,
          count: FieldValue.increment(count),
          lastUsed: Date.now(),
        }, { merge: true });
      }
      try {
        await batch.commit();
        console.log(`  Hashtags lot ${Math.floor(i / 400) + 1} commité`);
      } catch (err) {
        console.warn(`  ❌ Hashtags lot échoué:`, err.message);
      }
    }

    // Afficher le top 10
    const sorted = Object.entries(hashtagCounts).sort((a, b) => b[1] - a[1]).slice(0, 10);
    console.log('\nTop 10 hashtags:');
    sorted.forEach(([tag, count]) => console.log(`  #${tag}: ${count} posts`));
  }

  console.log(`\n=== RÉSUMÉ ===`);
  console.log(`Posts traités : ${processed}`);
  console.log(`Écriture Firestore : ${writes}`);
  console.log(`Erreurs : ${errors}`);
  console.log(DRY_RUN ? '\n⚠️  Mode DRY RUN — aucune écriture effectuée' : '\n✅ Backfill terminé');
}

run().then(() => process.exit(0)).catch(err => {
  console.error('❌ Fatal:', err);
  process.exit(1);
});
