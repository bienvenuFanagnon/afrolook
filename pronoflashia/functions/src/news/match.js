'use strict';
// Reconnaît les équipes citées dans un titre d'actualité.

const strip = (s) => String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
const escRe = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

/**
 * teams : [{ id, noms: ['Marseille', 'Olympique De Marseille'] }]
 * Un nom court (5 lettres ou moins : « Nice », « Lens ») doit apparaître avec sa majuscule d'origine, pour ne pas confondre
 * avec un mot courant. Les noms plus longs sont comparés sans accents ni casse, mot entier.
 */
function teamsInTitle(titre, teams) {
  const norm = ' ' + strip(titre) + ' ';
  const found = [];
  for (const t of teams) {
    const hit = t.noms.some((n) => {
      const name = String(n || '').trim();
      if (name.length < 3) return false;
      if (name.length <= 5) return new RegExp(`(^|[^A-Za-zÀ-ÿ])${escRe(name)}($|[^A-Za-zÀ-ÿ])`).test(titre);
      const s = strip(name);
      return s.length >= 4 && norm.includes(' ' + s + ' ');
    });
    if (hit) found.push(String(t.id));
  }
  return found;
}

module.exports = { teamsInTitle, strip };
