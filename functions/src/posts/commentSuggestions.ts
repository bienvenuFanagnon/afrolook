import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { GoogleGenerativeAI } from "@google/generative-ai";

// ─── helpers exportés pour les tests unitaires ────────────────────────────────

export function extractHashtags(text: string): string[] {
  return (text.match(/#\w+/g) ?? []).slice(0, 10);
}

// Catégories d'intérêt (synchronisées avec user_interests.dart)
const CATEGORY_IDS = [
  "music",    // Musique
  "sport",    // Sport
  "dance",    // Danse & Spectacle
  "fashion",  // Mode & Beauté
  "food",     // Gastronomie
  "cinema",   // Cinéma & Créativité
  "culture",  // Culture & Savoir
  "business", // Business & Finance
  "lifestyle",// Lifestyle & Société
  "gaming",   // Gaming & Tech
];

export function buildPrompt(description: string, hashtags: string[]): string {
  const lines: string[] = [];
  if (description) lines.push(`Description : "${description.slice(0, 500)}"`);
  if (hashtags.length > 0) lines.push(`Hashtags : ${hashtags.join(" ")}`);

  return [
    "Tu es un assistant pour une application de réseau social afro-centrique.",
    ...lines,
    "",
    "=== PARTIE 1 : SUGGESTIONS DE COMMENTAIRES ===",
    "Génère exactement 5 suggestions de commentaires courts et naturels en français pour ce post.",
    "",
    "Règles commentaires :",
    "- Chaque suggestion fait entre 3 et 10 mots (emojis non comptés)",
    "- Elles sont variées : admiratif, humoristique, encourageant, curieux, taquin, émouvant…",
    "- Elles correspondent exactement au sujet et à l'émotion du post",
    "- Pas de numérotation, pas de guillemets, une suggestion par ligne",
    "- Ton proche des jeunes africains francophones",
    "",
    "Emojis dans les commentaires :",
    "- Tu PEUX inclure 1 emoji dans certaines suggestions (pas toutes) quand c'est naturel",
    "- Adapte l'emoji à l'émotion détectée :",
    "  · Post drôle / humour → 😂 🤣 💀",
    "  · Post joyeux / bonne nouvelle → 🎉 😊 🙌",
    "  · Post triste / émouvant → 😢 ❤️ 🙏",
    "  · Post impressionnant / talent → 🔥 👏 🏆",
    "  · Post surprenant → 😮 🤯",
    "  · Post amour / couple → ❤️ 😍",
    "  · Post sport → 💪 ⚽",
    "  · Post musique → 🎵 🎤",
    "- Si l'émotion n'est pas claire, n'ajoute pas d'emoji",
    "- Ne mets jamais d'emoji sur 2 suggestions consécutives",
    "",
    "=== PARTIE 2 : CENTRES D'INTÉRÊT DU POST ===",
    "Choisis 1 à 3 catégories de cette liste qui correspondent le mieux à ce post :",
    CATEGORY_IDS.join(", "),
    "",
    "Règles intérêts :",
    "- Choisis seulement les catégories qui correspondent VRAIMENT au contenu du post",
    "- Maximum 3 catégories, minimum 1",
    "- Retourne uniquement les IDs séparés par des virgules, sans espace superflu",
    "- Si le post ne correspond à aucune catégorie, retourne : lifestyle",
    "",
    "=== FORMAT DE RÉPONSE (OBLIGATOIRE — respecte exactement cette structure) ===",
    "SUGGESTIONS:",
    "<suggestion 1>",
    "<suggestion 2>",
    "<suggestion 3>",
    "<suggestion 4>",
    "<suggestion 5>",
    "INTERETS:",
    "<code1,code2,code3>",
  ].join("\n");
}

export function parseSuggestions(raw: string): string[] {
  const suggestionsSection = raw.split("INTERETS:")[0];
  const lines = suggestionsSection
    .replace(/^SUGGESTIONS:\s*/i, "")
    .split("\n")
    .map((l) => l.replace(/^[\d\-\.\*\s]+/, "").trim())
    .filter((l) => l.length >= 5 && l.length <= 120);
  return lines.slice(0, 5);
}

export function parseInterests(raw: string): string[] {
  const interetsMatch = raw.match(/INTERETS:\s*\n?([\w,\s]+)/i);
  if (!interetsMatch) return [];
  return interetsMatch[1]
    .split(",")
    .map((c) => c.trim())
    .filter((c) => CATEGORY_IDS.includes(c))
    .slice(0, 3);
}

// ─── Cloud Function ───────────────────────────────────────────────────────────

const ALLOWED_TYPES = ["POST", "CHRONIQUE", "CHALLENGE", "CHALLENGEPARTICIPATION"];

export const generateCommentSuggestions = onDocumentCreated(
  {
    document: "Posts/{postId}",
    timeoutSeconds: 60,
    memory: "256MiB",
  },
  async (event) => {
    // ISOLATION TOTALE : toute erreur est absorbée — la création du post n'est jamais bloquée
    try {
      const post = event.data?.data();
      if (!post) return;

      if (!ALLOWED_TYPES.includes(post.type as string)) return;

      const description: string = (post.description as string) ?? "";
      const hashtags = extractHashtags(description);

      if (!description.trim() && hashtags.length === 0) return;

      const apiKey = process.env.GEMINI_API_KEY;
      if (!apiKey) {
        console.warn("[commentSuggestions] GEMINI_API_KEY absente — ignoré");
        return;
      }

      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({ model: "gemini-flash-latest" });

      const result = await model.generateContent(buildPrompt(description, hashtags));
      const raw = result.response.text();

      const suggestions = parseSuggestions(raw);
      const interests = parseInterests(raw);

      const update: Record<string, unknown> = {};

      if (suggestions.length > 0) {
        update.commentSuggestions = suggestions;
        console.log(`[commentSuggestions] Post ${event.params.postId} — ${suggestions.length} suggestions`);
      } else {
        console.warn(`[commentSuggestions] Post ${event.params.postId} — suggestions vides`);
      }

      if (interests.length > 0) {
        update.postInterests = interests;
        console.log(`[commentSuggestions] Post ${event.params.postId} — intérêts: ${interests.join(", ")}`);
      }

      if (Object.keys(update).length > 0) {
        await event.data!.ref.update(update);
      }
    } catch (err) {
      // Echec silencieux : ne jamais relancer/propager
      console.error("[commentSuggestions] Erreur non bloquante :", err);
    }
  }
);
