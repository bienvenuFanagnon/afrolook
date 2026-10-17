'use strict';
// Garde-fous du « Point foot » : un article de l'IA n'est publié que s'il passe TOUTES ces vérifications, sinon l'article de secours (construit sans IA) prend le relais.
//  - JSON conforme, tailles raisonnables, langue correcte ;
//  - aucune promesse, aucun conseil de pari ;
//  - aucun chiffre qui ne figure pas dans les faits ;
//  - aucun nom propre (joueur, équipe, site) qui ne figure pas dans les faits ;
//  - aucune reprise mot pour mot d'un titre de presse (7 mots d'affilée) : on reformule, on ne recopie pas.

const V = require('../ai/validate');
const { strip } = require('../news/match');

const MONTHS_DAYS = /^(?:lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche|janvier|février|mars|avril|mai|juin|juillet|août|septembre|octobre|novembre|décembre|monday|tuesday|wednesday|thursday|friday|saturday|sunday|january|february|march|april|may|june|july|august|september|october|november|december|pronoflash|utc|ia)$/i;
const BETTING = /(?<!\p{L})(?:pariez|parie|misez|mise|jouez ce coup|bet now|place your bet|bet on)(?!\p{L})/iu;
const WORD = /\p{Lu}[\p{L}'’-]{3,}/gu;

/** Noms propres du texte (mots en majuscule qui ne commencent pas une phrase) absents des faits. */
function unknownNames(text, corpusNorm) {
  const bad = [];
  for (const m of text.matchAll(WORD)) {
    const before = text.slice(0, m.index).replace(/[\s«“"(\[]+$/u, '');
    if (!before.length || /[.!?…:;—–-]$/.test(before)) continue; // début de phrase : la majuscule est normale
    const w = m[0].replace(/['’-]+$/, '');
    if (MONTHS_DAYS.test(w)) continue;
    const parts = w.split(/['’-]/).filter((x) => x.length >= 3);
    if (parts.every((p) => corpusNorm.includes(strip(p)))) continue;
    bad.push(w);
  }
  return bad;
}

/** Plus longue suite de mots identique entre le texte et l'un des titres de presse. */
function copiedRun(text, titles, n = 7) {
  const words = (s) => strip(s).split(' ').filter(Boolean);
  const tw = words(text);
  const grams = new Set();
  for (const t of titles) { const w = words(t); for (let i = 0; i + n <= w.length; i++) grams.add(w.slice(i, i + n).join(' ')); }
  for (let i = 0; i + n <= tw.length; i++) if (grams.has(tw.slice(i, i + n).join(' '))) return tw.slice(i, i + n).join(' ');
  return null;
}

const str = (v, min, max) => typeof v === 'string' && v.trim().length >= min && v.trim().length <= max;

/**
 * raw : réponse brute de l'IA. ctx : { lines, corpus, titles, lang }.
 * Renvoie { ok, value?, errors[] } ; value = { titre, chapo, sections[], retenir[], notif:{titre, corps} }.
 */
function validateRecap(raw, ctx) {
  const lang = ctx.lang === 'en' ? 'en' : 'fr';
  const errors = [];
  const j = V.extractJson(raw);
  if (!j || typeof j !== 'object') return { ok: false, errors: ['json_invalide'] };
  const titre = typeof j.titre === 'string' ? j.titre.trim() : '';
  const chapo = typeof j.chapo === 'string' ? j.chapo.trim() : '';
  const sections = Array.isArray(j.sections) ? j.sections.filter((s) => s && typeof s === 'object').map((s) => ({ titre: String(s.titre || '').trim(), texte: String(s.texte || '').trim() })) : [];
  const retenir = Array.isArray(j.retenir) ? j.retenir.filter((x) => typeof x === 'string').map((x) => x.trim()).filter(Boolean) : [];
  const notif = j.notif && typeof j.notif === 'object' ? { titre: String(j.notif.titre || '').trim(), corps: String(j.notif.corps || '').trim() } : null;
  if (!str(titre, 25, 95)) errors.push('titre_longueur');
  if (!str(chapo, 40, 300)) errors.push('chapo_longueur');
  if (sections.length < 2 || sections.length > 4) errors.push('sections_nombre');
  if (sections.some((s) => !str(s.titre, 3, 70) || !str(s.texte, 60, 750))) errors.push('section_longueur');
  if (retenir.length < 3) errors.push('retenir_nombre');
  if (retenir.some((x) => x.length > 160)) errors.push('retenir_longueur');
  if (!notif || !str(notif.titre, 8, 60) || !str(notif.corps, 20, 120)) errors.push('notif_longueur');
  if (errors.length) return { ok: false, errors };

  const all = [titre, chapo, ...sections.flatMap((s) => [s.titre, s.texte]), ...retenir, notif.titre, notif.corps].join(' . ');
  const fr = (all.match(V.FR_WORDS) || []).length, en = (all.match(V.EN_WORDS) || []).length;
  if (lang === 'en' ? en < 20 || fr > en / 2 : fr < 20 || en > fr / 2) errors.push(lang === 'en' ? 'not_english' : 'pas_en_francais');
  if ((lang === 'en' ? V.FORBIDDEN_EN : V.FORBIDDEN).some((re) => re.test(all)) || V.hasUnnegatedPromise(all, lang)) errors.push('promesse_interdite');
  if (BETTING.test(all)) errors.push('conseil_de_pari');
  const badNums = V.checkNumbers(all, V.allowedNumbers(ctx.lines));
  if (badNums.length) errors.push('chiffre_invente:' + badNums.slice(0, 3).join(','));
  const corpusNorm = ` ${strip(ctx.corpus)} `;
  const badNames = unknownNames(all, corpusNorm);
  if (badNames.length) errors.push('nom_invente:' + badNames.slice(0, 3).join(','));
  const copy = copiedRun(all, ctx.titles || []);
  if (copy) errors.push('titre_recopie:' + copy);
  if (errors.length) return { ok: false, errors };
  return { ok: true, errors: [], value: { titre, chapo, sections, retenir: retenir.slice(0, 4), notif } };
}

module.exports = { validateRecap, unknownNames, copiedRun };
