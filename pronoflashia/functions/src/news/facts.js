'use strict';
// Lecture de l'actualité par l'IA : un titre (et son court résumé) devient, au mieux, UN fait structuré sur une équipe
// (absence, suspension, retour, changement d'entraîneur). Garde-fous, parce qu'un modèle de langage peut se tromper :
//  - rien n'est demandé à l'IA s'il n'y a aucun mot-clé de blessure, suspension, retour ou entraîneur dans le texte (aucun coût, aucune invention) ;
//  - la réponse doit être un JSON strict ; l'équipe doit être l'une de celles citées ; le type doit être cohérent avec les mots du texte ;
//    le nom du joueur doit figurer tel quel dans le texte, sinon il est ignoré ;
//  - « rumeur » dès que le texte hésite (point d'interrogation, « selon », « pourrait »…), quelle que soit la réponse de l'IA ;
//  - si l'IA est indisponible (quota, panne), un repli par règles donne le type et l'équipe sans nom de joueur.
// Le fait est affiché avec sa source ; il ne modifie aucune probabilité (aucun historique ne permet de mesurer son effet : voir le bilan par signal).

const { strip } = require('./match');

const TYPES = ['absence', 'suspension', 'retour', 'entraineur'];
// Mots entiers, accents compris (le \b de JavaScript ne reconnaît pas « blessé » comme un mot entier) : bornes Unicode
const words = (src) => new RegExp(`(?<![\\p{L}\\p{N}])(?:${src})(?![\\p{L}\\p{N}])`, 'iu');
const KEYWORDS = {
  absence: words("bless[ée]e?s?|blessure|forfait|indisponible|absent|absence|tuile|touch[ée]e? (?:à|au|aux)|infirmerie|injur\\p{L}*|ruled out|sidelined|out for|doubtful|fitness doubt"),
  suspension: words("suspendu\\p{L}*|suspension|suspended|carton rouge|red card|disqualifi[ée]\\p{L}*"),
  // seulement les retours de joueurs (pas « retour » tout court)
  retour: words("de retour (?:de blessure|à l'entra[iî]nement|dans le groupe|dans l'effectif|à la comp[ée]tition)|retour (?:de blessure|à l'entra[iî]nement|dans le groupe|à la comp[ée]tition)|reprise (?:de l'entra[iî]nement|collective)|retrouve le groupe|back in training|returns? to training|back from injury|returns? from injury"),
  // seulement les changements d'entraîneur (pas « entraîneur » tout court)
  entraineur: words("limog[ée]\\p{L}*|licenci[ée]\\p{L}* (?:l'|son )?(?:entra[iî]neur|coach)|(?:entra[iî]neur|coach)[^.]{0,30}(?:limog[ée]|licenci[ée]|d[ée]mission\\p{L}*)|d[ée]mission de l'entra[iî]neur|nouvel entra[iî]neur|nouveau coach|prend la t[êe]te de|sacked|appointed (?:as )?(?:new )?(?:head )?(?:coach|manager)|new (?:head )?(?:coach|manager)|(?:coach|manager) resigns?"),
};
// formules rassurantes ou négatives : le texte dit l'inverse d'une absence (pas de fait, ou « à confirmer »)
const NEGATION = new RegExp(words("rassur\\p{L}*|sans gravit[ée]|pas de blessure|aucune blessure|pas bless[ée]|pas inqui[ée]t\\p{L}*|not injured|no injury|fit again|ruled out of (?:no|nothing)").source, 'iu');
const HEDGING = new RegExp(`\\?|${words("selon|pourrait|pourraient|rumeur\\p{L}*|rumou?rs?|incertain\\p{L}*|doute|doubt\\p{L}*|may|could|might|reportedly|piste|pist[ée]e?s?|serait|seraient|possible|probable|unclear").source}`, 'iu');

/** Types évoqués par le texte d'après les mots-clés. */
function detectTypes(text) {
  return TYPES.filter((t) => KEYWORDS[t].test(text));
}

const hedges = (text) => HEDGING.test(text);

function buildMessages({ titre, resume, candidates, lang }) {
  const en = lang === 'en';
  const system = en
    ? 'You extract one fact from a football headline. Answer with strict JSON only, nothing else. Never add information that is not written in the text.'
    : "Tu extrais un fait d'un titre d'article de football. Réponds uniquement avec un JSON strict, rien d'autre. N'ajoute jamais une information qui n'est pas écrite dans le texte.";
  const user = en
    ? `Headline: ${titre}\nSummary: ${resume || '(none)'}\nPossible teams: ${candidates.join(' | ')}\n\nReturn {"equipe": exact team name from the list or null, "type": "absence" (injury or unavailable player) | "suspension" | "retour" (player back) | "entraineur" (coach change) | "aucun", "joueur": exact player name as written in the text or null}.`
    : `Titre : ${titre}\nRésumé : ${resume || '(aucun)'}\nÉquipes possibles : ${candidates.join(' | ')}\n\nRéponds {"equipe": nom exact pris dans la liste ou null, "type": "absence" (joueur blessé ou indisponible) | "suspension" | "retour" (joueur de retour) | "entraineur" (changement d'entraîneur) | "aucun", "joueur": nom exact du joueur tel qu'écrit dans le texte ou null}.`;
  return [{ role: 'system', content: system }, { role: 'user', content: user }];
}

/** Première structure JSON d'une réponse (le modèle peut entourer le JSON de texte ou de balises). */
function parseJson(raw) {
  const m = /\{[\s\S]*\}/.exec(String(raw || ''));
  if (!m) return null;
  try { return JSON.parse(m[0]); } catch { return null; }
}

/**
 * Valide la réponse de l'IA. candidates : [{ id, nom }]. Renvoie un fait { equipeId, equipe, type, joueur, certitude, methode: 'ia' } ou null.
 */
function validate(raw, { titre, resume, candidates }) {
  const j = parseJson(raw);
  if (!j || typeof j !== 'object') return null;
  if (!TYPES.includes(j.type)) return null;
  const text = `${titre} ${resume || ''}`;
  if (!detectTypes(text).includes(j.type) || NEGATION.test(text)) return null; // le type doit s'appuyer sur des mots du texte, et le texte ne doit pas dire le contraire (« rassurant », « sans gravité »)
  const team = candidates.find((c) => strip(c.nom) === strip(j.equipe));
  if (!team) return null;
  let joueur = null;
  if (typeof j.joueur === 'string') {
    const name = j.joueur.trim();
    if (name.length >= 3 && name.length <= 40 && ` ${strip(text)} `.includes(` ${strip(name)} `)) joueur = name;
  }
  return { equipeId: team.id, equipe: team.nom, type: j.type, joueur, certitude: hedges(text) ? 'rumeur' : 'confirme', methode: 'ia' };
}

/** Repli sans IA : seulement quand une seule équipe est citée et qu'un seul type est évoqué. Sans nom de joueur. */
function fallback({ titre, resume, candidates }) {
  const text = `${titre} ${resume || ''}`;
  const types = detectTypes(text);
  if (candidates.length !== 1 || types.length !== 1 || NEGATION.test(text)) return null;
  return { equipeId: candidates[0].id, equipe: candidates[0].nom, type: types[0], joueur: null, certitude: hedges(text) ? 'rumeur' : 'confirme', methode: 'regles' };
}

/** Appelle les fournisseurs dans l'ordre jusqu'à une réponse exploitable ; erreurs et quotas → fournisseur suivant. */
async function askProviders(providers, messages) {
  for (const p of providers || []) {
    try { return await p.call(messages); } catch { /* fournisseur suivant */ }
  }
  return null;
}

/**
 * Fait d'un article. article : { titre, resume, lang }, candidates : [{ id, nom }] (équipes reconnues dans le titre).
 * Renvoie { fait, appel } : fait peut être null ; appel = vrai si l'IA a été sollicitée.
 */
async function extractFact(article, candidates, providers) {
  const text = `${article.titre} ${article.resume || ''}`;
  if (!candidates.length || !detectTypes(text).length) return { fait: null, appel: false };
  const input = { titre: article.titre, resume: article.resume || '', candidates };
  if (providers && providers.length) {
    const raw = await askProviders(providers, buildMessages(Object.assign({}, input, { candidates: candidates.map((c) => c.nom), lang: article.lang })));
    if (raw != null) return { fait: validate(raw, input), appel: true };
  }
  return { fait: fallback(input), appel: !!(providers && providers.length) };
}

module.exports = { detectTypes, hedges, buildMessages, validate, fallback, extractFact, TYPES };
