// Libellés des paris en français et en anglais, déduits de la clé du marché et des noms d'équipes.
// Module partagé : serveur (rendu) et navigateur (coupon).
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.PF = Object.assign(root.PF || {}, factory());
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  const FAMILIES = {
    'Résultat': 'Result', 'Buts': 'Goals', 'Mi-temps': 'Half-time', 'Handicap': 'Handicap', 'Score': 'Score',
    'Corners': 'Corners', 'Tirs': 'Shots', 'Cartons & fautes': 'Cards & fouls', 'Joueurs': 'Players', 'Spéciaux': 'Specials',
  };
  const UNITS = {
    fr: { corners: 'corners', shotsOnTarget: 'tirs cadrés', shots: 'tirs au total', cards: 'cartons', fouls: 'fautes', offsides: 'hors-jeux' },
    en: { corners: 'corners', shotsOnTarget: 'shots on target', shots: 'total shots', cards: 'cards', fouls: 'fouls', offsides: 'offsides' },
  };
  const COUNT_KINDS = Object.keys(UNITS.fr);

  /** Nombre affiché : 2.5 → « 2,5 » en français, « 2.5 » en anglais. */
  const num = (x, lang) => (lang === 'en' ? String(x) : String(x).replace('.', ','));

  /** Nom de famille de paris dans la langue voulue (les familles sont stockées en français). */
  const familyLabel = (f, lang) => (lang === 'en' ? FAMILIES[f] || f : f);

  /**
   * Libellé d'un marché. H et A : noms courts des équipes. Renvoie null pour une clé inconnue.
   */
  function marketLabel(key, H, A, lang) {
    const en = lang === 'en';
    const p = String(key).split(':');
    const n = (x) => num(x, lang);
    const team = (side) => (side === 'home' ? H : A);
    const goals = (l) => (en ? (l > 1 ? 'goals' : 'goal') : l > 1 ? 'buts' : 'but');
    switch (p[0]) {
      case 'res':
        return ({
          '1': en ? `${H} to win` : `${H} gagne`, N: en ? 'Draw' : 'Match nul', '2': en ? `${A} to win` : `${A} gagne`,
          '1N': en ? `${H} or draw` : `${H} ou nul`, '12': en ? 'No draw' : 'Pas de match nul', N2: en ? `${A} or draw` : `${A} ou nul`,
          dnb1: en ? `${H}, draw no bet` : `${H}, remboursé si nul`, dnb2: en ? `${A}, draw no bet` : `${A}, remboursé si nul`,
        })[p[1]] || null;
      case 'buts':
        if (p[1] === 'over') return en ? `Over ${n(p[2])} goals` : `+${n(p[2])} buts`;
        if (p[1] === 'under') return en ? `Under ${n(p[2])} goals` : `−${n(p[2])} buts`;
        if (p[1] === 'btts') return p[2] === 'oui' ? (en ? 'Both teams to score' : 'Les 2 équipes marquent') : (en ? 'Both teams to score: no' : 'Une équipe ne marque pas');
        if ((p[1] === 'home' || p[1] === 'away') && p[2] === 'over') { const l = parseFloat(p[3]); return en ? `${team(p[1])} over ${n(p[3])} ${goals(l)}` : `${team(p[1])} +${n(p[3])} ${goals(l)}`; }
        if ((p[1] === 'home' || p[1] === 'away') && p[2] === 'under') { const l = parseFloat(p[3]); return en ? `${team(p[1])} under ${n(p[3])} ${goals(l)}` : `${team(p[1])} −${n(p[3])} ${goals(l)}`; }
        if (p[1] === 'cs') return en ? `${team(p[2])} clean sheet` : `${team(p[2])} garde sa cage inviolée`;
        return null;
      case 'hand': {
        const v = p[2];
        const sign = v[0] === '-' ? '−' : '+';
        return `${team(p[1])} ${sign}${n(v.replace(/^[+-]/, ''))}`;
      }
      case 'score':
        if (p[1] === 'wtn') return en ? `${team(p[2])} to win to nil` : `${team(p[2])} gagne sans encaisser`;
        if (p[1] === 'margin2') return en ? `${team(p[2])} to win by 2+ goals` : `${team(p[2])} gagne de 2 buts ou plus`;
        if (p[1] === 'exact') return en ? `Correct score ${p[2]}` : `Score exact ${p[2]}`;
        return null;
      case 'mt':
        if (p[1] === '1h') {
          if (p[2] === 'over') return en ? `Over ${n(p[3])} first-half goals` : `+${n(p[3])} ${goals(parseFloat(p[3]))} en 1re mi-temps`;
          if (p[2] === 'under') return en ? `Under ${n(p[3])} first-half goals` : `−${n(p[3])} ${goals(parseFloat(p[3]))} en 1re mi-temps`;
          if (p[2] === 'lead') return en ? `${team(p[3])} leading at half-time` : `${team(p[3])} mène à la mi-temps`;
          if (p[2] === 'draw') return en ? 'Draw at half-time' : 'Nul à la mi-temps';
        }
        if (p[1] === '2h' && p[2] === 'more') return en ? 'More goals in the second half' : 'Plus de buts en 2e mi-temps';
        if (p[1] === 'htft') return en ? `${team(p[2])} leading at half-time and wins` : `${team(p[2])} mène à la mi-temps et gagne`;
        return null;
      case 'spec':
        if (p[1] === 'first') return en ? `${team(p[2])} to score first` : `${team(p[2])} marque en premier`;
        return ({
          goal30: en ? 'A goal before the 30th minute' : 'Un but avant la 30e minute',
          goal75: en ? 'A goal after the 75th minute' : 'Un but après la 75e minute',
          penalty: en ? 'Penalty in the match' : 'Penalty dans le match',
          red: en ? 'A red card' : 'Un carton rouge',
        })[p[1]] || null;
      default:
        if (COUNT_KINDS.includes(p[0])) {
          const u = UNITS[en ? 'en' : 'fr'][p[0]];
          if (p[1] === 'total') return en ? `Over ${n(p[2])} ${u}` : `+${n(p[2])} ${u}`;
          if (p[1] === 'home' || p[1] === 'away') return en ? `${team(p[1])} over ${n(p[2])} ${u}` : `${team(p[1])} +${n(p[2])} ${u}`;
          if (p[1] === 'more') { const a = team(p[2]), b = team(p[2] === 'home' ? 'away' : 'home'); return en ? `${a} more ${u} than ${b}` : `${a} plus de ${u} que ${b}`; }
        }
        return null;
    }
  }

  /** Libellé du pronostic principal (« 1 · Paris SG », « 12 · Pas de nul »…). */
  function principalLabel(key, H, A, lang) {
    const en = lang === 'en';
    switch (key) {
      case 'res:1': return `1 · ${H}`;
      case 'res:2': return `2 · ${A}`;
      case 'res:N': return en ? 'X · Draw' : 'N · Match nul';
      case 'res:1N': return en ? `1X · ${H} or draw` : `1N · ${H} ou nul`;
      case 'res:N2': return en ? `X2 · ${A} or draw` : `N2 · ${A} ou nul`;
      case 'res:12': return en ? '12 · No draw' : '12 · Pas de nul';
      default: return marketLabel(key, H, A, lang);
    }
  }

  return { FAMILIES, familyLabel, marketLabel, principalLabel };
});
