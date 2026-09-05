import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { FieldValue } from "firebase-admin/firestore";
import { db } from "../shared/firebase";

// ─── Helpers exportés pour les tests unitaires ────────────────────────────────

/** Extrait les hashtags du texte (sans le #), en minuscule, dédupliqués. */
export function extractHashtags(text: string): string[] {
  const raw = (text.match(/#(\w+)/g) ?? []).map((h) => h.slice(1).toLowerCase());
  return [...new Set(raw)].slice(0, 20);
}

// ─── Catégories d'intérêt (synchronisées avec user_interests.dart) ───────────

export const CATEGORY_IDS = [
  "music",     // Musique
  "sport",     // Sport
  "dance",     // Danse & Spectacle
  "fashion",   // Mode & Beauté
  "food",      // Gastronomie
  "cinema",    // Cinéma & Créativité
  "culture",   // Culture & Savoir
  "business",  // Business & Finance
  "lifestyle", // Lifestyle & Société
  "gaming",    // Gaming & Tech
];

// ─── Système manuel : hashtag → catégorie ────────────────────────────────────

export const HASHTAG_TO_CATEGORY: Record<string, string> = {
  // ── Music ─────────────────────────────────────────────────────────────────
  musique: "music", music: "music", son: "music", chant: "music", chanson: "music",
  afrobeat: "music", afropop: "music", hiphop: "music", rap: "music", rnb: "music",
  gospel: "music", ndombolo: "music", reggae: "music", zouk: "music",
  coupedecale: "music", dj: "music", djing: "music", beatmaker: "music",
  artiste: "music", concert: "music", studio: "music", cover: "music",
  prod: "music", freestyle: "music", clip: "music", amapiano: "music",
  azonto: "music", afrojam: "music", instrumental: "music",

  // ── Sport ─────────────────────────────────────────────────────────────────
  sport: "sport", football: "sport", foot: "sport", basket: "sport", basketball: "sport",
  fitness: "sport", gym: "sport", musculation: "sport", athletisme: "sport",
  natation: "sport", tennis: "sport", boxe: "sport", mma: "sport", combat: "sport",
  cyclisme: "sport", velo: "sport", esport: "sport", running: "sport",
  entrainement: "sport", training: "sport", coach: "sport", stade: "sport",
  rugby: "sport", handball: "sport", volleyball: "sport", crossfit: "sport",
  karate: "sport", judo: "sport", taekwondo: "sport", yoga: "sport",

  // ── Dance ─────────────────────────────────────────────────────────────────
  danse: "dance", dance: "dance", afrodance: "dance",
  sketch: "dance", theatre: "dance", spectacle: "dance",
  standup: "dance", zumba: "dance", choreo: "dance", choreographie: "dance",

  // ── Fashion / Mode ────────────────────────────────────────────────────────
  mode: "fashion", fashion: "fashion", beaute: "fashion", beauty: "fashion",
  look: "fashion", looks: "fashion", style: "fashion", wax: "fashion",
  pagne: "fashion", tissage: "fashion", ootd: "fashion", outfit: "fashion",
  maquillage: "fashion", makeup: "fashion", skincare: "fashion",
  coiffure: "fashion", tresses: "fashion", cheveux: "fashion", hair: "fashion",
  streetwear: "fashion", couture: "fashion", robe: "fashion", tenue: "fashion",
  bazin: "fashion", ankara: "fashion", kente: "fashion", dashiki: "fashion",

  // ── Food ──────────────────────────────────────────────────────────────────
  food: "food", nourriture: "food", cuisine: "food", gastronomie: "food",
  recette: "food", restaurant: "food", streetfood: "food", vegan: "food",
  patisserie: "food", dessert: "food", boisson: "food", cocktail: "food",
  chef: "food", grillade: "food", braai: "food",
  attieke: "food", jollof: "food", fufu: "food", plantain: "food",
  mafe: "food", yassa: "food",

  // ── Cinema / Art ──────────────────────────────────────────────────────────
  cinema: "cinema", film: "cinema", serie: "cinema", nollywood: "cinema",
  photo: "cinema", photographie: "cinema", video: "cinema", art: "cinema",
  dessin: "cinema", peinture: "cinema", illustration: "cinema", animation: "cinema",
  manga: "cinema", graphisme: "cinema", portrait: "cinema", shooting: "cinema",
  sculpture: "cinema", artisanat: "cinema", artwork: "cinema",

  // ── Culture ───────────────────────────────────────────────────────────────
  culture: "culture", histoire: "culture", heritage: "culture",
  education: "culture", science: "culture", technologie: "culture", tech: "culture",
  innovation: "culture", sante: "culture", health: "culture", medecine: "culture",
  programmation: "culture", dev: "culture", code: "culture", ia: "culture",
  langues: "culture", tradition: "culture", livre: "culture", afrique: "culture",
  panafricanisme: "culture",

  // ── Business ──────────────────────────────────────────────────────────────
  business: "business", entrepreneuriat: "business", startup: "business",
  investissement: "business", crypto: "business", finance: "business",
  commerce: "business", marketing: "business", ecommerce: "business",
  vente: "business", freelance: "business", emploi: "business", travail: "business",
  immobilier: "business", bourse: "business", entrepreneur: "business",

  // ── Lifestyle ─────────────────────────────────────────────────────────────
  lifestyle: "lifestyle", voyage: "lifestyle", travel: "lifestyle", tourisme: "lifestyle",
  nature: "lifestyle", environnement: "lifestyle", animaux: "lifestyle",
  famille: "lifestyle", enfant: "lifestyle", religion: "lifestyle", foi: "lifestyle",
  politique: "lifestyle", societe: "lifestyle", voiture: "lifestyle", auto: "lifestyle",
  moto: "lifestyle", amour: "lifestyle", couple: "lifestyle", mariage: "lifestyle",
  bienetre: "lifestyle", motivation: "lifestyle", inspiration: "lifestyle",
  humour: "lifestyle", comedie: "lifestyle", comedy: "lifestyle",

  // ── Gaming ────────────────────────────────────────────────────────────────
  gaming: "gaming", jeux: "gaming", game: "gaming", gamer: "gaming",
  smartphone: "gaming", mobile: "gaming", console: "gaming",
  robot: "gaming", gadget: "gaming", geek: "gaming",
  playstation: "gaming", xbox: "gaming", nintendo: "gaming",
};

/** typeTabbar → catégorie (signal fort si aucun hashtag ne matche) */
const TABBAR_TO_CATEGORY: Record<string, string> = {
  LOOKS:      "fashion",
  SPORT:      "sport",
  GAMER:      "gaming",
  ACTUALITES: "culture",
  EVENEMENT:  "lifestyle",
  OFFRES:     "business",
};

/**
 * Déduit postInterests à partir des hashtags et du typeTabbar.
 * Retourne toujours au moins ["lifestyle"] si rien ne matche.
 */
export function extractInterestsManually(
  hashtags: string[],
  typeTabbar?: string
): string[] {
  const matched = new Set<string>();

  for (const tag of hashtags) {
    const cat = HASHTAG_TO_CATEGORY[tag];
    if (cat) matched.add(cat);
  }

  if (typeTabbar) {
    const tabCat = TABBAR_TO_CATEGORY[typeTabbar.toUpperCase()];
    if (tabCat) matched.add(tabCat);
  }

  if (matched.size === 0) matched.add("lifestyle");

  return [...matched].slice(0, 3);
}

// ─── Cloud Function ───────────────────────────────────────────────────────────

const ALLOWED_TYPES = ["POST", "CHRONIQUE", "CHALLENGE", "CHALLENGEPARTICIPATION"];

export const generateCommentSuggestions = onDocumentCreated(
  {
    document: "Posts/{postId}",
    timeoutSeconds: 30,
    memory: "128MiB",
  },
  async (event) => {
    // ISOLATION TOTALE : toute erreur est absorbée — la création du post n'est jamais bloquée
    try {
      const post = event.data?.data();
      if (!post) return;

      if (!ALLOWED_TYPES.includes(post.type as string)) return;

      const description: string = (post.description as string) ?? "";
      const typeTabbar: string = (post.typeTabbar as string) ?? "";
      const postId = event.params.postId;

      // ── 1. Extraire les hashtags de la description ──────────────────────────
      const hashtags = extractHashtags(description);

      // ── 2. postInterests : système manuel (hashtags + typeTabbar) ───────────
      const interests = extractInterestsManually(hashtags, typeTabbar);
      console.log(`[postInterests] ${postId} → [${interests.join(", ")}] (hashtags: ${hashtags.join(", ") || "aucun"}, tab: ${typeTabbar || "?"})`);

      const update: Record<string, unknown> = {
        postInterests: interests,
        hashtags: hashtags,
      };

      // ── 3. Incrémenter le compteur de chaque hashtag dans la collection ─────
      if (hashtags.length > 0) {
        const batch = db.batch();
        for (const tag of hashtags) {
          batch.set(db.collection("Hashtags").doc(tag), {
            name: tag,
            count: FieldValue.increment(1),
            lastUsed: Date.now(),
          }, { merge: true });
        }
        try {
          await batch.commit();
        } catch (batchErr) {
          console.warn(`[hashtags] Batch échoué (ignoré):`, batchErr);
        }
      }

      await event.data!.ref.update(update);
    } catch (err) {
      console.error("[generateCommentSuggestions] Erreur non bloquante:", err);
    }
  }
);
