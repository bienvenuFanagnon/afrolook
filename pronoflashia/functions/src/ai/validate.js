'use strict';
// Vérification stricte de la sortie de l'IA : JSON conforme, français, aucune promesse, aucun chiffre inventé.

// Promesses toujours interdites, même niées.
const FORBIDDEN = [
  /gain[s]?\s+garanti/i, /sûr\s+à\s+100/i, /100\s?%\s+(?:sûr|certain|garanti)/i,
  /pari\s+(?:gagnant|sûr|en or)/i, /certain\s+de\s+gagner/i, /ne\s+peut\s+pas\s+perdre/i, /argent\s+facile/i, /mise\s+sur/i, /pariez/i, /parie\s/i,
];
// Mots interdits sauf quand la phrase les nie (« rien n'est garanti », « aucun résultat assuré »).
const NEGATABLE = /(?<!\p{L})(?:garanti[es]?|assuré[es]?)(?!\p{L})/giu;
const NEGATION = /(?<!\p{L})(?:pas|aucun|aucune|rien|jamais|ne)(?!\p{L})|n'/iu;

/** Vrai si le texte contient un « garanti » / « guaranteed »… non précédé d'une négation dans la même phrase. */
function hasUnnegatedPromise(text, lang) {
  const words = lang === 'en' ? NEGATABLE_EN : NEGATABLE;
  const neg = lang === 'en' ? NEGATION_EN : NEGATION;
  for (const m of text.matchAll(words)) {
    const start = Math.max(text.lastIndexOf('.', m.index), text.lastIndexOf('!', m.index), 0);
    const before = text.slice(start, m.index);
    if (!neg.test(before)) return true;
  }
  return false;
}
// Anglais : promesses interdites, mots niables, négations.
const FORBIDDEN_EN = [
  /sure\s+(?:win|thing|bet)/i, /100\s?%\s+(?:sure|certain|guaranteed)/i, /can'?t\s+lose/i, /cannot\s+lose/i, /easy\s+money/i, /\block\s+of\s+the/i,
  /guaranteed\s+(?:win|profit|winnings|money)/i, /\b(?:place|make)\s+(?:a|your)\s+bet\b/i, /\bbet\s+(?:now|big)\b/i,
];
const NEGATABLE_EN = /(?<!\p{L})(?:guarantee[sd]?|certain(?:ty)?|assured)(?!\p{L})/giu;
const NEGATION_EN = /(?<!\p{L})(?:not|no|nothing|never|nor|without|isn'?t|aren'?t|cannot|can'?t)(?!\p{L})|n't/iu;

const FR_WORDS = /(?<!\p{L})(?:le|la|les|un|une|des|de|du|et|en|à|au|aux|est|sont|avec|pour|sur|dans|qui|que|ne|pas|plus|se|son|sa|ses|ont|a|match|équipe|buts?)(?!\p{L})/giu;
const EN_WORDS = /(?<!\p{L})(?:the|and|with|their|have|has|are|is|will|this|that|from|against|goals?|team|of|to|in|a|an|at|for|by|win|draw|match)(?!\p{L})/giu;

/** Extrait le premier objet JSON d'un texte (tolère les balises ```json). */
function extractJson(raw) {
  if (raw && typeof raw === 'object') return raw;
  let s = String(raw || '').trim();
  s = s.replace(/^```(?:json)?\s*/i, '').replace(/```\s*$/i, '').trim();
  const a = s.indexOf('{');
  const b = s.lastIndexOf('}');
  if (a < 0 || b <= a) return null;
  try { return JSON.parse(s.slice(a, b + 1)); } catch { return null; }
}

/** Nombres présents dans un texte, normalisés (« 2,5 » → 2.5). */
function numbersIn(text) {
  return [...String(text).matchAll(/\d+(?:[.,]\d+)?/g)].map((m) => ({ raw: m[0], v: parseFloat(m[0].replace(',', '.')), idx: m.index }));
}

/** Tous les nombres autorisés = ceux qui figurent dans les faits fournis à l'IA. */
function allowedNumbers(faits) {
  return new Set(numbersIn((faits || []).join(' ')).map((n) => n.v));
}

/**
 * Un nombre du texte est accepté s'il figure dans les faits, ou s'il s'agit d'un petit entier (« trois », « 2 buts », jusqu'à 20)
 * sans pourcentage ni décimale. Un pourcentage ou une décimale inventés sont refusés.
 */
function checkNumbers(text, allowed) {
  const bad = [];
  for (const n of numbersIn(text)) {
    if (allowed.has(n.v)) continue;
    const after = text.slice(n.idx + n.raw.length, n.idx + n.raw.length + 3);
    const isPct = /^\s*%/.test(after);
    const isDecimal = /[.,]/.test(n.raw);
    const isYear = n.v >= 1990 && n.v <= 2100;
    if (isYear) continue;
    if (!isPct && !isDecimal && n.v <= 20) continue;
    bad.push(n.raw);
  }
  return bad;
}

const sentences = (t) => String(t).split(/(?<=[.!?…])\s+/).filter((x) => x.trim().length > 2);

/**
 * Renvoie { ok, value?, errors[] }. value = { analyse, pointsCles[3], resume }.
 * faits : lignes de faits envoyées à l'IA (pour contrôler les chiffres).
 */
function validateOutput(raw, faits, lang) {
  const en = lang === 'en';
  const errors = [];
  const j = extractJson(raw);
  if (!j || typeof j !== 'object') return { ok: false, errors: ['json_invalide'] };
  const analyse = typeof j.analyse === 'string' ? j.analyse.trim() : '';
  const resume = typeof j.resume === 'string' ? j.resume.trim() : '';
  const pts = Array.isArray(j.pointsCles) ? j.pointsCles.filter((x) => typeof x === 'string').map((x) => x.trim()).filter(Boolean) : [];
  if (analyse.length < 150 || analyse.length > 1200) errors.push('analyse_longueur');
  const ns = sentences(analyse).length;
  if (ns < 3 || ns > 6) errors.push('analyse_phrases');
  if (resume.length < 15 || resume.length > 220) errors.push('resume_longueur');
  if (pts.length < 3) errors.push('points_cles');
  if (pts.some((p) => p.length > 180)) errors.push('point_trop_long');
  const all = [analyse, resume, ...pts].join(' ');
  const fr = (all.match(FR_WORDS) || []).length;
  const nEn = (all.match(EN_WORDS) || []).length;
  if (en ? nEn < 8 || fr > nEn / 2 : fr < 8 || nEn > fr / 2) errors.push(en ? 'not_english' : 'pas_en_francais');
  if ((en ? FORBIDDEN_EN : FORBIDDEN).some((re) => re.test(all)) || hasUnnegatedPromise(all, lang)) errors.push('promesse_interdite');
  const badNums = checkNumbers(all, allowedNumbers(faits));
  if (badNums.length) errors.push('chiffre_invente:' + badNums.slice(0, 3).join(','));
  if (errors.length) return { ok: false, errors };
  return { ok: true, errors: [], value: { analyse, pointsCles: pts.slice(0, 3), resume } };
}

module.exports = { hasUnnegatedPromise, extractJson, numbersIn, allowedNumbers, checkNumbers, validateOutput, FORBIDDEN };
