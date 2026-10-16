'use strict';
// Prompt envoyé à l'IA. Elle reçoit des FAITS et des CHIFFRES déjà calculés ; elle rédige seulement le texte.

const SYSTEM = [
  'Tu es un analyste football francophone. Tu écris pour un site gratuit de pronostics, en français clair et direct.',
  'RÈGLES ABSOLUES :',
  '1. N\'utilise QUE les chiffres et les faits fournis dans la section FAITS. N\'invente aucun chiffre, aucun joueur, aucune statistique.',
  '2. Ne change jamais un pourcentage, un score ou un pronostic fourni.',
  '3. N\'écris jamais « gain garanti », « sûr à 100 % », « assuré », « pari gagnant » ni aucune promesse de gain.',
  '4. Ton neutre et informatif : explique pourquoi le calcul donne ce pronostic et ce qui peut le contredire.',
  '5. Réponds UNIQUEMENT avec un objet JSON valide, sans texte avant ni après, de cette forme exacte :',
  '{"analyse":"3 à 5 phrases","pointsCles":["point 1","point 2","point 3"],"resume":"une seule phrase"}',
].join('\n');

const SYSTEM_EN = [
  'You are an English-speaking football analyst writing for a free predictions website, in clear and direct English.',
  'ABSOLUTE RULES:',
  '1. Use ONLY the figures and facts given in the FACTS section. Never invent a figure, a player or a statistic.',
  '2. Never change a percentage, a score or a prediction you are given.',
  '3. Never write "guaranteed", "sure win", "100% certain", "lock", "can\'t lose" or any promise of winnings.',
  '4. Neutral, informative tone: explain why the model gives this prediction and what could go against it.',
  '5. Reply ONLY with a valid JSON object, with no text before or after, in exactly this shape (keep these keys):',
  '{"analyse":"3 to 5 sentences","pointsCles":["point 1","point 2","point 3"],"resume":"one sentence"}',
].join('\n');

/**
 * ctx : { competition, dateTexte, domicile, exterieur, formeDom, formeExt, probas:{'1','N','2'}, principal:{libelle,confiance},
 *         plus25, bttsOui, scoreProbable, extras: [lignes de faits], h2h: [lignes] }
 * Renvoie { messages, faits } ; faits est la liste des lignes (sert aussi à vérifier qu'aucun chiffre n'est inventé).
 */
function buildPrompt(ctx, lang) {
  if (lang === 'en') return buildPromptEn(ctx);
  const faits = [];
  faits.push(`Match : ${ctx.domicile} contre ${ctx.exterieur}, ${ctx.competition}, ${ctx.dateTexte}.`);
  if (ctx.formeDom) faits.push(`Forme récente de ${ctx.domicile} (V = victoire, N = nul, D = défaite, du plus ancien au plus récent) : ${ctx.formeDom}.`);
  if (ctx.formeExt) faits.push(`Forme récente de ${ctx.exterieur} : ${ctx.formeExt}.`);
  for (const l of ctx.extras || []) faits.push(l);
  for (const l of ctx.h2h || []) faits.push(l);
  faits.push(`Probabilités calculées : victoire de ${ctx.domicile} ${ctx.probas['1']} %, match nul ${ctx.probas.N} %, victoire de ${ctx.exterieur} ${ctx.probas['2']} %.`);
  faits.push(`Plus de 2,5 buts : ${ctx.plus25} %. Les deux équipes marquent : ${ctx.bttsOui} %. Score le plus probable : ${ctx.scoreProbable}.`);
  faits.push(`Pronostic retenu : ${ctx.principal.libelle}, confiance ${ctx.principal.confiance} %.`);
  const user = `FAITS\n${faits.map((f) => '- ' + f).join('\n')}\n\nRédige l'analyse en JSON selon les règles.`;
  return { messages: [{ role: 'system', content: SYSTEM }, { role: 'user', content: user }], faits };
}

/** Même chose en anglais : les faits sont rédigés en anglais (ctx.extras et ctx.h2h aussi). */
function buildPromptEn(ctx) {
  const faits = [];
  faits.push(`Match: ${ctx.domicile} vs ${ctx.exterieur}, ${ctx.competition}, ${ctx.dateTexte}.`);
  if (ctx.formeDom) faits.push(`Recent form of ${ctx.domicile} (W = win, D = draw, L = loss, oldest to latest): ${toEnForm(ctx.formeDom)}.`);
  if (ctx.formeExt) faits.push(`Recent form of ${ctx.exterieur}: ${toEnForm(ctx.formeExt)}.`);
  for (const l of ctx.extras || []) faits.push(l);
  for (const l of ctx.h2h || []) faits.push(l);
  faits.push(`Calculated probabilities: ${ctx.domicile} win ${ctx.probas['1']}%, draw ${ctx.probas.N}%, ${ctx.exterieur} win ${ctx.probas['2']}%.`);
  faits.push(`Over 2.5 goals: ${ctx.plus25}%. Both teams to score: ${ctx.bttsOui}%. Most likely score: ${ctx.scoreProbable}.`);
  faits.push(`Selected prediction: ${ctx.principal.libelle}, confidence ${ctx.principal.confiance}%.`);
  const user = `FACTS\n${faits.map((f) => '- ' + f).join('\n')}\n\nWrite the analysis in JSON following the rules.`;
  return { messages: [{ role: 'system', content: SYSTEM_EN }, { role: 'user', content: user }], faits };
}

/** Forme « VNDVV » (V victoire, N nul, D défaite) → « WDLWW ». */
const toEnForm = (f) => String(f || '').split('').map((c) => ({ V: 'W', N: 'D', D: 'L' }[c] || c)).join('');

module.exports = { SYSTEM, SYSTEM_EN, buildPrompt, toEnForm };
