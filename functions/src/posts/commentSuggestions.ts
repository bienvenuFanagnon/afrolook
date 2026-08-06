import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { GoogleGenerativeAI } from "@google/generative-ai";

// ─── helpers exportés pour les tests unitaires ────────────────────────────────

export function extractHashtags(text: string): string[] {
  return (text.match(/#\w+/g) ?? []).slice(0, 10);
}

export function buildPrompt(description: string, hashtags: string[]): string {
  const lines: string[] = [];
  if (description) lines.push(`Description : "${description.slice(0, 500)}"`);
  if (hashtags.length > 0) lines.push(`Hashtags : ${hashtags.join(" ")}`);

  return [
    "Tu es un assistant pour une application de réseau social afro-centrique.",
    "Génère exactement 5 suggestions de commentaires courts et naturels en français pour ce post.",
    ...lines,
    "",
    "Règles :",
    "- Chaque suggestion fait entre 3 et 8 mots",
    "- Elles sont variées : admiratif, humoristique, encourageant, curieux, taquin…",
    "- Elles correspondent au sujet du post",
    "- Pas de numérotation, pas de guillemets, une suggestion par ligne",
    "- Ton proche des jeunes africains francophones",
    "",
    "Réponds uniquement avec les 5 suggestions, une par ligne.",
  ].join("\n");
}

export function parseSuggestions(raw: string): string[] {
  return raw
    .split("\n")
    .map((l) => l.replace(/^[\d\-\.\*\s]+/, "").trim())
    .filter((l) => l.length >= 5 && l.length <= 120)
    .slice(0, 5);
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
        console.warn("[commentSuggestions] GEMINI_API_KEY absente — suggestions IA ignorées");
        return;
      }

      const genAI = new GoogleGenerativeAI(apiKey);
      const model = genAI.getGenerativeModel({ model: "gemini-flash-latest" });

      const result = await model.generateContent(buildPrompt(description, hashtags));
      const suggestions = parseSuggestions(result.response.text());

      if (suggestions.length === 0) {
        console.warn(`[commentSuggestions] Post ${event.params.postId} — réponse Gemini vide ou non parseable`);
        return;
      }

      await event.data!.ref.update({ commentSuggestions: suggestions });
      console.log(`[commentSuggestions] Post ${event.params.postId} — ${suggestions.length} suggestions générées`);
    } catch (err) {
      // Echec silencieux : ne jamais relancer/propager
      console.error("[commentSuggestions] Erreur non bloquante :", err);
    }
  }
);
