'use strict';
// Firestore refuse les tableaux dans des tableaux : la matrice de scores (7 × 7) est enregistrée en 7 chaînes « p00,p01,… » et reconstruite à la lecture.

/** Matrice (tableau de lignes) → 7 chaînes. */
const pack = (m) => (Array.isArray(m) ? m.map((row) => (Array.isArray(row) ? row.join(',') : String(row))) : null);

/** Chaînes → matrice de nombres. Accepte aussi une matrice déjà reconstruite (jeux de test, anciens documents). */
function unpack(v) {
  if (!Array.isArray(v)) return null;
  return v.map((row) => (Array.isArray(row) ? row : String(row).split(',').map(Number)));
}

module.exports = { pack, unpack };
