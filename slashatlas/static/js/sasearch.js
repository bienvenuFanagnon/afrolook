/* Recherche des commandes : tolérante, pour que chacun retrouve vite ce qu'il cherche, quels que soient les mots tapés.
 *  - sans accents ni majuscules, ponctuation ignorée, pluriel ignoré, début de mot suffisant (« tap » trouve « tapis ») ;
 *  - synonymes et mots du quotidien en français et en anglais (« habit » trouve les robes, « bouffe » les plats, « perruque » les cheveux…) ;
 *  - fautes de frappe (« serviete », « cuilère ») ;
 *  - classement par pertinence : le titre compte plus que les mots-clés, qui comptent plus que la description ;
 *  - si rien ne correspond à tous les mots, on montre les commandes qui correspondent à certains d'entre eux (jamais une page vide quand une idée proche existe).
 * Les éléments à chercher : { t: titres (FR + EN), k: mots-clés et catégories, c: code, a: tout le texte } (déjà sans accents, voir build.mjs).
 */
(function (g) {
  'use strict';
  var nq = function (s) { return String(s == null ? '' : s).toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9]+/g, ' ').trim(); };
  var sing = function (w) { return w.length > 3 ? w.replace(/[sx]$/, '') : w; };

  // Groupes de mots proches (déjà sans accents, au singulier). Un mot tapé dans un groupe trouve les commandes qui parlent d'un autre mot du groupe.
  var GROUPS = [
    'robe dress tenue habit vetement clothes clothing pagne boubou kaba tailleur jupe pantalon chemise',
    'sac bag handbag cabas pochette besace',
    'chaussure shoe sandale basket sneaker talon escarpin mocassin soulier',
    'bijou jewelry jewellery collier bracelet bague boucle montre watch perle gourmette',
    'cheveu coiffure hair tresse meche perruque wig braid tissage coiffeur frisure bonnet',
    'maquillage makeup beaute beauty gloss rouge vernis ongle nail cosmetique soin creme cream pommade lotion huile beurre cils lashes',
    'parfum perfume fragrance odeur senteur deodorant',
    'nourriture food plat repas cuisine resto restaurant manger bouffe burger pizza poulet riz menu snack boisson jus drink grillade attieke',
    'gateau cake patisserie boulangerie pain bakery dessert bonbon chocolat sweet biscuit',
    'maison home deco decoration interieur meuble house',
    'immobilier realestate immo appartement villa terrain loyer location rent logement parcelle',
    'voiture auto car moto vehicule garage taxi automobile',
    'telephone phone smartphone iphone mobile tech gadget ordinateur laptop',
    'musique music concert chanteur artiste album clip dj soiree party spectacle',
    'mariage wedding fiancaille ceremonie noce fete anniversaire birthday invitation faire part bapteme',
    'sport foot football match gym fitness musculation running course entrainement',
    'voyage travel hotel tourisme vacance plage beach avion flight sejour',
    'sante health pharmacie clinique medecin docteur bienetre wellness yoga hopital',
    'ecole education formation cours etudiant school universite diplome apprendre',
    'logo marque brand branding identite packaging emballage etiquette',
    'video pub publicite reel tiktok animation motion film',
    'reseaux social instagram facebook whatsapp post publication miniature thumbnail youtube story statut',
    'prix promo promotion solde reduction discount offre vente flash price',
    'cadeau gift present offrir surprise coffret',
    'bebe baby enfant kid child naissance',
    'homme man men costume suit barbe garcon',
    'femme woman women dame fille girl lady madame',
    'mariee bride bridal',
    'tapis rug carpet moquette',
    'rideau curtain voilage',
    'lit bed literie drap matelas oreiller couverture pillow blanket sheet',
    'vaisselle assiette plate dishes couvert cutlery tasse cup verre glass bol bowl ustensile louche cuillere fourchette couteau',
    'nettoyage menage cleaning lessive savon soap javel balai serpilliere eponge detergent',
    'rangement storage organisation organiser panier basket boite box etagere',
    'bougie candle',
    'fleur flower bouquet floral',
    'miroir mirror glace',
    'ecommerce boutique shop store catalogue banniere banner commerce',
    'entreprise business recrutement emploi job hiring societe bureau',
    'affiche poster flyer visuel image photo',
    'drone aerien ciel aerial',
    'bain bathroom douche toilette serviette towel',
    'cuisine kitchen casserole poele marmite fourneau',
    'style decor theme',
    'africain african afro africa afrique ethnique',
    'luxe luxury luxueux premium chic elegant',
    'jus juice smoothie boisson drink cocktail bar',
    'cafe coffee the tea petit dejeuner breakfast',
    'ordinateur computer pc informatique',
    'argent money paiement payment finance banque mobile money transfert',
    'livraison delivery colis courrier transport',
    'spa massage esthetique institut',
    'tissu fabric textile pagne wax couture couturier tailor',
  ].map(function (s) { return s.split(' '); });
  var SYN = {};
  GROUPS.forEach(function (gr, i) { gr.forEach(function (w) { var k = sing(w); (SYN[k] = SYN[k] || []).push(i); }); });

  var fuzzyMax = function (w) { return w.length >= 9 ? 2 : w.length >= 5 ? 1 : 0; }; // mots courts : pas de faute admise (trop de faux résultats)

  // Variantes d'un mot tapé : lui-même (poids 1) et les mots de ses groupes (poids 0,6)
  function expand(w, fuzzy) {
    var out = [{ w: w, wt: 1 }], seen = {}; seen[w] = 1;
    var gi = {};
    (SYN[w] || []).forEach(function (i) { gi[i] = 1; });
    var fm = fuzzy ? fuzzyMax(w) : 0; // faute de frappe dans un mot connu (« pomade » → « pommade »)
    if (fm) Object.keys(SYN).forEach(function (k) { if (k.length > 2 && lev(w, k, fm) <= fm) { if (!seen[k]) { seen[k] = 1; out.push({ w: k, wt: 0.95, ex: true }); } SYN[k].forEach(function (i) { gi[i] = 1; }); } }); // le mot probablement voulu passe en premier
    if (w.length >= 4) Object.keys(SYN).forEach(function (k) { if (k.indexOf(w) === 0) SYN[k].forEach(function (i) { gi[i] = 1; }); }); // « vetem » → vetement
    Object.keys(gi).forEach(function (i) { GROUPS[i].forEach(function (m) { var s = sing(m); if (!seen[s]) { seen[s] = 1; out.push({ w: s, wt: 0.6, ex: true }); } }); });
    return out;
  }

  // distance d'édition bornée (insertion, suppression, remplacement, deux lettres inversées)
  function lev(a, b, max) {
    var la = a.length, lb = b.length;
    if (Math.abs(la - lb) > max) return max + 1;
    var p2 = [], prev = [], cur = [], i, j;
    for (j = 0; j <= lb; j++) prev[j] = j;
    for (i = 1; i <= la; i++) {
      cur[0] = i; var rowMin = i;
      for (j = 1; j <= lb; j++) {
        var c = a.charCodeAt(i - 1) === b.charCodeAt(j - 1) ? 0 : 1, v = Math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + c);
        if (i > 1 && j > 1 && a.charCodeAt(i - 1) === b.charCodeAt(j - 2) && a.charCodeAt(i - 2) === b.charCodeAt(j - 1)) v = Math.min(v, p2[j - 2] + 1);
        cur[j] = v; if (v < rowMin) rowMin = v;
      }
      if (rowMin > max) return max + 1;
      var t = p2; p2 = prev; prev = cur; cur = t;
    }
    return prev[lb];
  }

  function prep(it) {
    if (it._p) return it;
    it._tt = (it.t || '').split(' ');
    it._kt = (it.k || '').split(' ');
    it._p = 1;
    return it;
  }
  // le mot entier (au pluriel près) est dans la liste de mots
  function hasWord(tokens, w) { for (var i = 0; i < tokens.length; i++) { var t = tokens[i]; if (t === w || (t.length === w.length + 1 && t.indexOf(w) === 0 && (t.charAt(w.length) === 's' || t.charAt(w.length) === 'x'))) return true; } return false; }
  function startsAny(tokens, w) { for (var i = 0; i < tokens.length; i++) if (tokens[i].indexOf(w) === 0) return true; return false; }

  // score d'un mot (ou d'une de ses variantes) pour un élément ; 0 = aucune correspondance
  function wordScore(it, w, fuzzy, raw, exact) {
    if (exact) return hasWord(it._tt, w) ? 10 : hasWord(it._kt, w) ? 7 : hasWord((it._at = it._at || it.a.split(' ')), w) ? 2 : 0;
    if (startsAny(it._tt, w)) return 10;
    if (startsAny(it._kt, w)) return 7;
    if (w.length >= 4 && it.t.indexOf(w) > -1) return 6;
    if ((' ' + (it.c || '')).indexOf(' ' + w) > -1) return 5;
    if (w.length >= 4 && it.k.indexOf(w) > -1) return 4;
    if ((' ' + it.a).indexOf(' ' + w) > -1) return 2;
    if (w.length >= 5 && it.a.indexOf(w) > -1) return 1;
    if (fuzzy) {
      var fw = raw || w, m = fuzzyMax(fw);
      if (m) {
        var best = 0, d;
        for (var i = 0; i < it._tt.length; i++) if (it._tt[i].length > 2 && (d = lev(fw, it._tt[i].slice(0, fw.length + m), m)) <= m) best = Math.max(best, 3.5 - d);
        for (var j = 0; j < it._kt.length; j++) if (it._kt[j].length > 2 && (d = lev(fw, it._kt[j].slice(0, fw.length + m), m)) <= m) best = Math.max(best, 2.5 - d);
        return best;
      }
    }
    return 0;
  }

  function scoreItem(it, groups, phrase, fuzzy, needAll) {
    prep(it);
    var total = 0, matched = 0;
    for (var gi = 0; gi < groups.length; gi++) {
      var best = 0, vars = groups[gi];
      for (var vi = 0; vi < vars.length; vi++) {
        var s = wordScore(it, vars[vi].w, fuzzy && vi === 0, vars[vi].raw, vars[vi].ex) * vars[vi].wt;
        if (s > best) best = s;
      }
      if (best > 0) { total += best; matched++; } else if (needAll) return 0;
    }
    if (!matched) return 0;
    if (phrase && phrase.indexOf(' ') > -1 && it.t.indexOf(phrase) > -1) total += 12; // toute l'expression dans le titre
    return total;
  }

  // Retourne { list: [{ it, s }], mode } trié par pertinence ; mode : 'and' (tous les mots), 'fuzzy' (fautes admises), 'or' (certains mots), 'all' (rien tapé)
  function search(items, raw) {
    var phrase = nq(raw), toks = phrase.split(' ').filter(Boolean), big = toks.filter(function (w) { return w.length > 2; });
    if (!toks.length) return { list: items.map(function (it, i) { return { it: it, s: 0, i: i }; }), mode: 'all' };
    toks = big.length ? big : toks;
    var build = function (fuzzy) { return toks.map(function (t) { var v = expand(sing(t), fuzzy); v[0].raw = t; return v; }); };
    var groups = build(false);
    var run = function (fuzzy, needAll) {
      var out = [];
      for (var i = 0; i < items.length; i++) { var s = scoreItem(items[i], groups, phrase, fuzzy, needAll); if (s > 0) out.push({ it: items[i], s: s, i: i }); }
      out.sort(function (a, b) { return b.s - a.s || a.i - b.i; });
      // assez de bons résultats : on écarte ceux qui ne correspondent que par un mot de la description
      var strong = out.filter(function (x) { return x.s >= 3; });
      return strong.length >= 5 ? strong : out;
    };
    var r = run(false, true);
    if (r.length) return { list: r, mode: 'and' };
    groups = build(true);
    r = run(true, true);
    if (r.length) return { list: r, mode: 'fuzzy' };
    r = run(true, false);
    return { list: r, mode: r.length ? 'or' : 'none' };
  }

  g.SASearch = { nq: nq, search: search, expand: expand, lev: lev };
})(typeof window !== 'undefined' ? window : this);
