import { AGENT_OF_CATEGORY } from "./agents";
import { runAi, AiResult, DEFAULT_MODELS } from "./ai";

type Msg = { role: "system" | "user" | "assistant"; content: string };
import { Topic } from "./cluster";
import { validateSummary } from "./validate";

/**
 * Résumé d'un sujet par l'IA : on lui donne les titres et extraits de 1 à 4 sources, elle écrit un résumé en français avec nos propres mots
 * (titre, chapô, 2 à 4 sections, « À retenir », texte de notification). Le résultat n'est gardé que s'il passe les garde-fous (validate.ts).
 * Les sources sont toujours citées dans l'article (nom et lien) ; le texte des sources n'est jamais conservé.
 */
const CATEGORY_LABEL: Record<string, string> = { sport: "sport", politique: "politique", culture: "culture", musique: "musique", tech: "technologie", voyage: "voyage", mode: "mode et beauté", evenement: "événements importants et actualité générale" };
const CONTINENT_LABEL = "Afrique";
/** Nom usuel des pays suivis, donné à l'IA comme périmètre d'un article « pays ». */
export const COUNTRY_NAME: Record<string, string> = {
  TG: "le Togo", BJ: "le Bénin", CI: "la Côte d'Ivoire", SN: "le Sénégal", CM: "le Cameroun", BF: "le Burkina Faso", MG: "Madagascar", CG: "le Congo", CD: "la RD Congo",
  ML: "le Mali", NE: "le Niger", GN: "la Guinée", GA: "le Gabon", GH: "le Ghana", NG: "le Nigeria", TD: "le Tchad", ZM: "la Zambie", KE: "le Kenya", ZA: "l'Afrique du Sud",
  FR: "la France", BE: "la Belgique", CH: "la Suisse", GB: "le Royaume-Uni", DE: "l'Allemagne", ES: "l'Espagne", US: "les États-Unis", CA: "le Canada", BR: "le Brésil", HT: "Haïti", MX: "le Mexique",
};

export const SYSTEM_PROMPT =
  "Tu es le rédacteur d'Afrolook, un journal pour l'Afrique et le monde. Tu écris un RÉSUMÉ de plusieurs sources, en français, clair, vivant et factuel. " +
  "Tu utilises UNIQUEMENT les faits fournis : n'invente jamais une personne, un lieu, un chiffre, une date ni une citation. " +
  "Reformule avec tes propres mots : ne recopie jamais un titre ni une phrase des sources ; change la construction des phrases et les mots (synonymes), et n'enchaîne jamais 6 mots identiques à une source. " +
  "Reste neutre : aucun avis personnel, aucune rumeur présentée comme un fait ; si les sources se contredisent, dis-le. " +
  "Pas de formule racoleuse. Réponds uniquement avec un JSON strict.";

export function buildMessages(topic: Topic, countryName: string | null, dateText: string): Msg[] {
  const items = distinctOutlets(topic).slice(0, 4);
  const where = topic.level === "country" ? (countryName ?? "le pays") : topic.level === "continent" ? CONTINENT_LABEL : "le monde";
  const sources = items.map((it, i) => `[S${i + 1}] ${it.sourceName} — ${it.titre}\n${(it.corps || it.resume).slice(0, 2800)}`).join("\n\n");
  const english = items.some((it) => it.lang === "en");
  const hint = english
    ? "Les sources sont en anglais : écris en français, garde les noms de personnes, d'équipes et d'organisations tels qu'ils sont écrits dans les sources, et utilise le nom français usuel des pays.\n\n"
    : "";
  const user =
    `Date : ${dateText}\nDomaine : ${CATEGORY_LABEL[topic.category] ?? topic.category}\nPérimètre : ${where}\n\nSources :\n${sources}\n\n` +
    `${hint}Écris le résumé en JSON :\n{"titre": titre clair de 40 à 100 caractères, fidèle aux faits,\n` +
    ` "chapo": 2 phrases qui donnent l'essentiel, 100 à 300 caractères,\n` +
    ` "sections": 3 à 4 objets {"titre": intertitre court, "texte": 250 à 550 caractères de prose claire : le contexte, les faits, les chiffres, les réactions, la suite attendue, seulement ce que disent les sources. Si les sources sont brèves, écris moins plutôt que d'inventer},\n` +
    ` "retenir": 4 puces courtes (140 caractères au plus chacune),\n` +
    ` "notif": {"titre": titre de notification de 55 caractères au plus, accrocheur mais honnête, "corps": 110 caractères au plus, donne envie de lire, sans promesse ni majuscules criardes}}`;
  return [{ role: "system", content: SYSTEM_PROMPT }, { role: "user", content: user }];
}

/** Un article par média (le premier, donc le plus récent), pour citer chaque source une seule fois. */
export function distinctOutlets(topic: Topic) {
  const seen = new Set<string>();
  return topic.items.filter((it) => (seen.has(it.sourceName) ? false : (seen.add(it.sourceName), true)));
}

export interface SummaryResult {
  ok: boolean;
  errors?: string[];
  /** Entrée prête pour cleanNewsInput(), si ok. */
  input?: Record<string, unknown>;
  ai?: AiResult;
  error?: string;
  /** Neurons de tous les appels de ce sujet (le second essai compte). */
  neurons?: number;
  retried?: boolean;
}

/** Consigne de correction pour le second essai, d'après les erreurs de validation. */
export function fixHint(errors: string[]): string {
  const parts = errors.map((e) => {
    if (e === "json_invalide") return "Réponds avec UNIQUEMENT l'objet JSON complet et valide, sans texte autour.";
    if (e === "titre_longueur") return "Le titre doit faire entre 40 et 100 caractères.";
    if (e === "chapo_longueur") return "Le chapô doit faire entre 80 et 280 caractères.";
    if (e.startsWith("section")) return "Donne 3 ou 4 sections, chacune avec un intertitre court et un texte de 250 à 550 caractères.";
    if (e.startsWith("texte_recopie")) return "Reformule entièrement avec tes propres mots : ne reprends aucune suite de 8 mots des sources.";
    if (e.startsWith("nom_invente")) return `Retire les noms qui ne figurent pas dans les sources (${e.split(":")[1] ?? ""}).`;
    if (e.startsWith("chiffre_invente")) return `Retire les chiffres qui ne figurent pas dans les sources (${e.split(":")[1] ?? ""}).`;
    if (e.startsWith("retenir")) return "Donne 3 puces « retenir » de 140 caractères au plus.";
    if (e.startsWith("notif")) return "Le titre de notification fait 55 caractères au plus, son corps de 20 à 110 caractères.";
    if (e === "pas_en_francais") return "Écris en français.";
    return "";
  }).filter(Boolean);
  return `Ta réponse a été refusée (${errors.join(", ")}). ${[...new Set(parts)].join(" ")} Réécris le JSON complet.`;
}

type Runner = typeof runAi;

/** Résume un sujet. `run` est injectable pour les tests. Ne lève jamais : les erreurs de l'IA sont renvoyées dans `error` (et `quota` stoppe le passage). */
export async function summarizeTopic(topic: Topic, opts: { countryName?: string | null; model?: string; retryModel?: string; nowMs?: number; run?: Runner; quotaFlag?: { hit: boolean } } = {}): Promise<SummaryResult> {
  const now = opts.nowMs ?? Date.now();
  const dateText = new Date(now).toLocaleDateString("fr-FR", { weekday: "long", day: "numeric", month: "long", year: "numeric", timeZone: "UTC" });
  const messages = buildMessages(topic, opts.countryName ?? (topic.country ? COUNTRY_NAME[topic.country] ?? null : null), dateText);
  const run = opts.run ?? runAi;
  const model = opts.model ?? DEFAULT_MODELS.quality;
  const outlets = distinctOutlets(topic).slice(0, 4);
  const sourcesText = outlets.map((it) => `${it.titre}. ${it.corps || it.resume}`).join("\n");
  const refs = topic.items.flatMap((it) => [it.titre, it.resume, it.corps]); // ni titre, ni extrait, ni texte de page recopié

  const call = async (msgs: Msg[], useModel: string = model): Promise<AiResult | SummaryResult> => {
    try {
      return await run(msgs, { model: useModel, maxTokens: 1900, temperature: 0.3 });
    } catch (e) {
      const code = (e as { code?: string }).code;
      if (code === "quota" && opts.quotaFlag) opts.quotaFlag.hit = true;
      return { ok: false, error: e instanceof Error ? e.message : String(e) };
    }
  };
  const first = await call(messages);
  if (!("text" in first)) return first;
  let ai = first;
  let neurons = first.neurons;
  let v = validateSummary(ai.text, { sourcesText, refs });
  let retried = false;
  if (!v.ok) {
    // un seul second essai, guidé par ce qui a été refusé (coût d'un appel de plus, seulement quand le premier est refusé)
    retried = true;
    // le second essai peut passer au modèle de qualité (le modèle léger recopie plus volontiers les sources)
    const second = await call([...messages, { role: "assistant", content: ai.text.slice(0, 3500) }, { role: "user", content: fixHint(v.errors) }], opts.retryModel ?? model);
    if (!("text" in second)) return { ok: false, error: second.error, errors: v.errors, ai, neurons, retried };
    ai = second;
    neurons += second.neurons;
    v = validateSummary(ai.text, { sourcesText, refs });
  }
  if (!v.ok) return { ok: false, errors: v.errors, ai, neurons, retried };
  const agentKey = AGENT_OF_CATEGORY[topic.category];
  const image = topic.items.find((i) => i.image)?.image ?? "";
  return {
    ok: true,
    ai,
    neurons,
    retried,
    input: {
      agentKey, level: topic.level, country: topic.country, continent: topic.level === "continent" ? "AF" : undefined, lang: "fr",
      title: v.value.titre, chapo: v.value.chapo, sections: v.value.sections, retenir: v.value.retenir,
      sources: outlets.map((it) => ({ name: it.sourceName, url: it.lien })), image,
      score: Math.round(topic.score), notif: { title: v.value.notif.titre, body: v.value.notif.corps },
    },
  };
}
