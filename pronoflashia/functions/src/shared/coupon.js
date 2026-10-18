// Coupons : probabilité de la combinaison, niveau de risque, avertissements, suggestions.
// Aucune mise, aucune cote : le site calcule seulement la probabilité que toutes les sélections passent.
// Module partagé serveur / navigateur.
(function (root, factory) {
  const goal = (typeof module === 'object' && module.exports) ? require('./goalmarkets') : root.PF;
  if (typeof module === 'object' && module.exports) module.exports = factory(goal);
  else root.PF = Object.assign(root.PF || {}, factory(goal));
})(typeof self !== 'undefined' ? self : this, function (goal) {
  'use strict';

  /** Paris trop faciles pour être utiles dans un coupon proposé : toujours probables, jamais informatifs. */
  const MAX_USEFUL_PCT = 88;
  const TRIVIAL = /^(?:buts:over:0\.5|buts:under:4\.5|hand:(?:home|away):\+2\.5)$/;
  const useful = (o) => o.fiabilite !== 'faible' && o.pct < MAX_USEFUL_PCT && !TRIVIAL.test(o.key);
  const MAX_SELECTIONS = 5;
  const MIN_SELECTIONS = 2;

  /**
   * selections : [{ matchId, key, pct, famille, fiabilite }]
   * matrices   : { [matchId]: matrice de scores } (facultatif)
   * Plusieurs sélections du même match : calcul exact sur la matrice si elles sont toutes des marchés de buts,
   * sinon produit des probabilités (approximation signalée par approx = true).
   */
  function couponProbability(selections, matrices) {
    const groups = new Map();
    for (const s of selections) {
      if (!groups.has(s.matchId)) groups.set(s.matchId, []);
      groups.get(s.matchId).push(s);
    }
    let prob = 1;
    let approx = false;
    for (const [matchId, list] of groups) {
      if (list.length === 1) { prob *= list[0].pct / 100; continue; }
      const preds = list.map((s) => goal.predicateFor(s.key));
      const m = matrices && matrices[matchId];
      if (m && preds.every(Boolean)) {
        prob *= goal.sumWhere(m, (i, j) => preds.every((f) => f(i, j)));
      } else {
        // Corrélation inconnue : on multiplie et on le signale.
        for (const s of list) prob *= s.pct / 100;
        approx = true;
      }
    }
    return { prob, approx };
  }

  const RISK = {
    fr: { prudent: 'Prudent', equilibre: 'Équilibré', risque: 'Risqué', tres_risque: 'Très risqué' },
    en: { prudent: 'Cautious', equilibre: 'Balanced', risque: 'Risky', tres_risque: 'Very risky' },
  };

  /** Niveau de risque d'une probabilité de coupon (0 à 1), libellé en français ou en anglais. */
  function riskLevel(prob, lang) {
    const id = prob >= 0.55 ? 'prudent' : prob >= 0.35 ? 'equilibre' : prob >= 0.2 ? 'risque' : 'tres_risque';
    return { id, label: (RISK[lang] || RISK.fr)[id] };
  }

  const WARN = {
    fr: {
      one: 'Ajoute au moins une deuxième sélection pour former un coupon.',
      many: 'Chaque sélection ajoutée fait baisser la probabilité du coupon. Au-delà de 3, il passe vite sous la barre du « coup sûr ».',
      weak: 'Une sélection sous 60 % tire tout le coupon vers le bas. Remplace-la par une option plus sûre du même match.',
      low: 'Une sélection repose sur des données peu fiables : traite-la avec prudence.',
      mix: 'Astuce : mélanger les types de pari (buts, corners, handicap…) évite qu\'un seul scénario fasse tout perdre.',
      approx: 'Plusieurs paris du même match : la probabilité est une estimation, ces paris peuvent être liés.',
      good: 'Bon équilibre : ce coupon passerait environ une fois sur deux ou plus.',
    },
    en: {
      one: 'Add at least a second selection to build a slip.',
      many: 'Every selection you add lowers the slip\'s probability. Beyond 3, it quickly drops below "safe" territory.',
      weak: 'A selection under 60% drags the whole slip down. Swap it for a safer option from the same match.',
      low: 'One selection relies on low-reliability data: handle it with care.',
      mix: 'Tip: mixing bet types (goals, corners, handicap…) stops a single scenario from sinking everything.',
      approx: 'Several bets from the same match: the probability is an estimate, these bets may be linked.',
      good: 'Good balance: this slip would come in about one time in two or more.',
    },
  };

  /** Niveau d'une sélection seule : sûr, équilibré, risqué. */
  function pickLevel(pct) {
    return pct >= 75 ? 'sur' : pct >= 60 ? 'equilibre' : 'risque';
  }

  /** Avertissements à afficher sous le coupon (texte français prêt à l'emploi). */
  function warnings(selections, result, lang) {
    const W = WARN[lang] || WARN.fr;
    const out = [];
    const n = selections.length;
    if (n === 1) out.push({ type: 'warn', text: W.one });
    if (n >= 4) out.push({ type: 'warn', text: W.many });
    if (selections.some((s) => s.pct < 60)) out.push({ type: 'warn', text: W.weak });
    if (selections.some((s) => s.fiabilite === 'faible')) out.push({ type: 'warn', text: W.low });
    if (n >= 2 && new Set(selections.map((s) => s.famille)).size === 1) out.push({ type: 'info', text: W.mix });
    if (result && result.approx) out.push({ type: 'info', text: W.approx });
    if (n >= 2 && result && result.prob >= 0.5) out.push({ type: 'info', text: W.good });
    return out;
  }

  /**
   * Meilleure alternative pour le maillon faible : l'option du même match la plus probable
   * (sans dépasser 96 %, trop banale) qui améliore le coupon.
   */
  function weakestSwap(selections, pool) {
    if (selections.length < 2) return null;
    const weak = selections.slice().sort((a, b) => a.pct - b.pct)[0];
    const opts = (pool[weak.matchId] || []).filter((o) => o.key !== weak.key && o.pct > weak.pct && useful(o));
    if (!opts.length) return null;
    opts.sort((a, b) => b.pct - a.pct);
    return { weak, better: opts[0] };
  }

  /**
   * Coupons proposés (Prudent 2, Équilibré 3, Audacieux 5) à partir d'un pool { matchId: [marchés] } :
   * le meilleur choix de chaque match, en variant les familles quand c'est possible.
   * Les marchés à fiabilité faible ne sont jamais proposés.
   */
  function suggest(pool, n, opts) {
    const minPct = (opts && opts.minPct) || 60;
    const ranked = Object.keys(pool).map((id) => {
      const ok = pool[id].filter((o) => useful(o) && o.pct >= minPct);
      return { id, best: ok.reduce((a, b) => (a && a.pct >= b.pct ? a : b), null), ok };
    }).filter((x) => x.best).sort((a, b) => b.best.pct - a.best.pct);
    const used = new Set();
    const out = [];
    for (const r of ranked.slice(0, n)) {
      let pick = null;
      for (const o of r.ok) if (!used.has(o.famille) && (!pick || o.pct > pick.pct)) pick = o;
      if (!pick) pick = r.best;
      used.add(pick.famille);
      out.push(Object.assign({ matchId: r.id }, pick));
    }
    return out;
  }

  /**
   * Cote équivalente d'un coupon : 1 divisé par la probabilité que tout passe (0 à 1), sans marge de bookmaker.
   * C'est une estimation à partir de nos probabilités, pas une cote proposée : les cotes réelles sont plus basses (marge du bookmaker).
   */
  function fairOdds(prob) { return prob > 0 && prob <= 1 ? 1 / prob : null; }

  /** Cote formatée : 2 décimales sous 10, 1 décimale sous 100, entier au-delà (virgule en français, point en anglais). */
  function formatOdds(o, lang) {
    if (!o || !isFinite(o)) return '–';
    const s = o < 10 ? o.toFixed(2) : o < 100 ? o.toFixed(1) : String(Math.round(o));
    return lang === 'en' ? s : s.replace('.', ',');
  }

  return { fairOdds, formatOdds, MAX_USEFUL_PCT, MAX_SELECTIONS, MIN_SELECTIONS, couponProbability, riskLevel, pickLevel, warnings, weakestSwap, suggest };
});
