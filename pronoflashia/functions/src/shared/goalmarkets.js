// Marchés « de buts » : une clé de marché → un prédicat sur la matrice de scores (i = buts dom., j = buts ext.).
// Module partagé : utilisé par le serveur (calcul) et par le navigateur (coupons dans un même match).
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.PF = Object.assign(root.PF || {}, factory());
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  /**
   * Clés prises en charge :
   *  res:1 res:N res:2 res:1N res:12 res:N2
   *  buts:over:2.5  buts:under:2.5  buts:btts:oui  buts:btts:non
   *  buts:home:over:1.5  buts:away:over:0.5  buts:home:under:1.5  buts:away:under:1.5
   *  buts:cs:home  buts:cs:away          (équipe qui garde sa cage inviolée)
   *  hand:home:-1.5  hand:away:+1.5      (handicap en .5 : résultat du match avec avantage ou retard de buts)
   *  score:wtn:home  score:wtn:away      (victoire sans encaisser)
   *  score:exact:2-1
   * Renvoie null pour les marchés qui ne sont pas de simples sommes de cases (mi-temps, comptages, remboursé si nul).
   */
  function predicateFor(key) {
    const p = String(key).split(':');
    const num = (s) => parseFloat(s);
    if (p[0] === 'res' && p.length === 2) {
      switch (p[1]) {
        case '1': return (i, j) => i > j;
        case 'N': return (i, j) => i === j;
        case '2': return (i, j) => i < j;
        case '1N': return (i, j) => i >= j;
        case '12': return (i, j) => i !== j;
        case 'N2': return (i, j) => i <= j;
        default: return null;
      }
    }
    if (p[0] === 'buts') {
      if (p[1] === 'over') return (i, j) => i + j > num(p[2]);
      if (p[1] === 'under') return (i, j) => i + j < num(p[2]);
      if (p[1] === 'btts') return p[2] === 'oui' ? (i, j) => i > 0 && j > 0 : (i, j) => i === 0 || j === 0;
      if (p[1] === 'home') return p[2] === 'over' ? (i) => i > num(p[3]) : (i) => i < num(p[3]);
      if (p[1] === 'away') return p[2] === 'over' ? (i, j) => j > num(p[3]) : (i, j) => j < num(p[3]);
      if (p[1] === 'cs') return p[2] === 'home' ? (i, j) => j === 0 : (i) => i === 0;
      return null;
    }
    if (p[0] === 'hand') {
      const h = num(p[2]);
      if (!Number.isFinite(h)) return null;
      return p[1] === 'home' ? (i, j) => i + h > j : (i, j) => j + h > i;
    }
    if (p[0] === 'score') {
      if (p[1] === 'margin2') return p[2] === 'home' ? (i, j) => i - j >= 2 : (i, j) => j - i >= 2;
      if (p[1] === 'wtn') return p[2] === 'home' ? (i, j) => i > j && j === 0 : (i, j) => j > i && i === 0;
      if (p[1] === 'exact') {
        const m = /^(\d+)-(\d+)$/.exec(p[2] || '');
        return m ? (i, j) => i === +m[1] && j === +m[2] : null;
      }
    }
    return null;
  }

  /** Somme des cases de la matrice qui vérifient pred. */
  function sumWhere(m, pred) {
    let s = 0;
    for (let i = 0; i < m.length; i++) for (let j = 0; j < m[i].length; j++) if (pred(i, j)) s += m[i][j];
    return s;
  }

  /** Probabilité (0 à 1) d'un marché de buts, ou null si la clé n'est pas un marché de buts. */
  function probOf(matrix, key) {
    const pred = predicateFor(key);
    return pred ? sumWhere(matrix, pred) : null;
  }

  return { predicateFor, sumWhere, probOf };
});
