'use strict';
// Texte de secours construit à partir des chiffres seulement : un match ne reste jamais sans analyse.

const formWords = (f) => {
  if (!f) return null;
  const v = (f.match(/V/g) || []).length;
  const d = (f.match(/D/g) || []).length;
  const n = f.length - v - d;
  return { v, n, d, len: f.length };
};
const plur = (n, s, p) => `${n} ${n > 1 ? p : s}`;

/**
 * ctx : même structure que pour buildPrompt. Renvoie { analyse, pointsCles, resume } valides (français, sans promesse).
 */
function fallbackText(ctx) {
  const D = ctx.domicile;
  const E = ctx.exterieur;
  const p = ctx.probas;
  const fav = p['1'] >= p['2'] ? D : E;
  const favP = Math.max(p['1'], p['2']);
  const fd = formWords(ctx.formeDom);
  const fe = formWords(ctx.formeExt);
  const s = [];
  s.push(`Le calcul donne ${favP} % de chances de victoire à ${fav}, contre ${p.N} % pour le match nul et ${p['1'] >= p['2'] ? p['2'] : p['1']} % pour l'autre équipe.`);
  if (fd && fe) {
    s.push(`${D} compte ${plur(fd.v, 'victoire', 'victoires')} sur ses ${fd.len} derniers matchs, ${E} en compte ${fe.v} sur les ${fe.len} siens.`);
  }
  s.push(`Le modèle voit ${ctx.plus25} % de chances de plus de 2,5 buts et ${ctx.bttsOui} % que les deux équipes marquent.`);
  s.push(`Le score le plus probable est ${ctx.scoreProbable}.`);
  s.push(`Le pronostic retenu est ${ctx.principal.libelle}, avec une confiance de ${ctx.principal.confiance} %. Un pronostic reste une probabilité et ne garantit aucun résultat.`);
  const pts = [
    `Pronostic : ${ctx.principal.libelle} (confiance ${ctx.principal.confiance} %)`,
    `Probabilités : ${D} ${p['1']} %, nul ${p.N} %, ${E} ${p['2']} %`,
    `Buts : plus de 2,5 buts à ${ctx.plus25} %, les deux équipes marquent à ${ctx.bttsOui} %`,
  ];
  return {
    analyse: s.join(' '),
    pointsCles: pts,
    resume: `${ctx.principal.libelle} : ${D} – ${E}, confiance ${ctx.principal.confiance} %.`,
  };
}

/** Version anglaise du texte de secours. */
function fallbackTextEn(ctx) {
  const D = ctx.domicile;
  const E = ctx.exterieur;
  const p = ctx.probas;
  const homeFav = p['1'] >= p['2'];
  const fav = homeFav ? D : E;
  const fd = formWords(ctx.formeDom);
  const fe = formWords(ctx.formeExt);
  const s = [];
  s.push(`The model gives ${fav} a ${Math.max(p['1'], p['2'])}% chance of winning, against ${p.N}% for a draw and ${homeFav ? p['2'] : p['1']}% for the other side.`);
  if (fd && fe) s.push(`${D} have won ${fd.v} of their last ${fd.len} matches, while ${E} have won ${fe.v} of their last ${fe.len}.`);
  s.push(`The model sees a ${ctx.plus25}% chance of over 2.5 goals and a ${ctx.bttsOui}% chance that both teams score.`);
  s.push(`The most likely score is ${ctx.scoreProbable}.`);
  s.push(`The selected prediction is ${ctx.principal.libelle}, with a confidence of ${ctx.principal.confiance}%. A prediction is a probability and no result is guaranteed.`);
  return {
    analyse: s.join(' '),
    pointsCles: [
      `Prediction: ${ctx.principal.libelle} (confidence ${ctx.principal.confiance}%)`,
      `Probabilities: ${D} ${p['1']}%, draw ${p.N}%, ${E} ${p['2']}%`,
      `Goals: over 2.5 goals at ${ctx.plus25}%, both teams to score at ${ctx.bttsOui}%`,
    ],
    resume: `${ctx.principal.libelle}: ${D} vs ${E}, confidence ${ctx.principal.confiance}%.`,
  };
}

module.exports = { fallbackText, fallbackTextEn };
