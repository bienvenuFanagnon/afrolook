'use strict';
// Traductions de l'interface et correspondance des adresses entre le français (/) et l'anglais (/en/).

const LEGAL_SLUGS = {
  'a-propos': 'about', contact: 'contact', confidentialite: 'privacy', conditions: 'terms',
  cookies: 'cookies', 'mentions-legales': 'legal-notice', 'jeu-responsable': 'responsible-gambling',
};
const LEGAL_FR = Object.fromEntries(Object.entries(LEGAL_SLUGS).map(([fr, en]) => [en, fr]));

/** Adresse d'une page dans une langue. name : home | day | league | match | analysis | bilan | coupon | legal. */
function pathFor(lang, name, arg) {
  const en = lang === 'en';
  const pre = en ? '/en' : '';
  switch (name) {
    case 'home': return en ? '/en' : '/';
    case 'day': return `${pre}/football/${en ? ({ aujourdhui: 'today', demain: 'tomorrow' }[arg] || arg) : arg}`;
    case 'league': return `${pre}/football/${arg}`;
    case 'match': return `${pre}/football/${arg.leagueSlug}/${arg.slug}`;
    case 'analysis': return `${pre}/football/${arg.leagueSlug}/${arg.slug}/${en ? 'analysis' : 'analyse'}`;
    case 'bilan': return en ? '/en/track-record' : '/bilan';
    case 'coupon': return `${pre}/coupon`;
    case 'legal': return en ? `/en/${LEGAL_SLUGS[arg]}` : `/${arg}`;
    case '404': return `${pre}/404`;
    default: return pre || '/';
  }
}

/**
 * Lit une adresse : { lang, name, arg }. Les segments anglais sont ramenés aux noms internes
 * (today → aujourdhui, analysis → analyse, privacy → confidentialite…).
 */
function parsePath(path) {
  let p = path;
  let lang = 'fr';
  if (p === '/en' || p.startsWith('/en/')) { lang = 'en'; p = p.slice(3) || '/'; }
  const seg = p.split('/').filter(Boolean);
  if (!seg.length) return { lang, name: 'home' };
  if (lang === 'en' && seg.length === 1) {
    if (seg[0] === 'track-record') return { lang, name: 'bilan' };
    if (seg[0] === 'coupon') return { lang, name: 'coupon' };
    if (LEGAL_FR[seg[0]]) return { lang, name: 'legal', arg: LEGAL_FR[seg[0]] };
    if (seg[0] === 'football') return { lang, name: 'football' };
    return { lang, name: 'unknown' };
  }
  if (lang === 'fr' && seg.length === 1) {
    if (seg[0] === 'bilan') return { lang, name: 'bilan' };
    if (seg[0] === 'coupon') return { lang, name: 'coupon' };
    if (LEGAL_SLUGS[seg[0]]) return { lang, name: 'legal', arg: seg[0] };
    if (seg[0] === 'football') return { lang, name: 'football' };
    return { lang, name: 'unknown' };
  }
  if (seg[0] !== 'football') return { lang, name: 'unknown' };
  if (seg.length === 1) return { lang, name: 'football' };
  if (seg.length === 2) {
    const d = lang === 'en' ? ({ today: 'aujourdhui', tomorrow: 'demain' }[seg[1]] || seg[1]) : seg[1];
    if (d === 'aujourdhui' || d === 'demain' || /^\d{4}-\d{2}-\d{2}$/.test(d)) return { lang, name: 'day', arg: d };
    return { lang, name: 'league', arg: seg[1] };
  }
  if (seg.length === 3) return { lang, name: 'match', arg: { leagueSlug: seg[1], slug: seg[2] } };
  if (seg.length === 4 && seg[3] === (lang === 'en' ? 'analysis' : 'analyse')) return { lang, name: 'analysis', arg: { leagueSlug: seg[1], slug: seg[2] } };
  return { lang, name: 'unknown' };
}

const T = {
  fr: {
    htmlLang: 'fr', ogLocale: 'fr_FR', skip: 'Aller au contenu', homeAria: 'PronoFlash IA, accueil', navMain: 'Navigation principale',
    navFootball: 'Football', navCoupon: 'Coupon', navBilan: 'Bilan', navAbout: 'À propos', myCoupon: 'Mon coupon', langSwitch: '<b>FR</b> · EN', langSwitchAria: 'English version',
    sports: 'Sports', basketball: 'Basketball', tennis: 'Tennis', soon: 'bientôt', days: 'Jours', today: "Aujourd'hui", tomorrow: 'Demain',
    leagues: 'Championnats', all: 'Tous', tzNote: 'Heures affichées dans ton fuseau horaire (UTC par défaut).', utcTitle: 'Heure UTC',
    footer18: 'Jouez de façon responsable', footerInfo: "Pronostics fournis à titre d'information. Aucun gain n'est garanti. Les pronostics sont calculés par un modèle statistique et l'analyse est rédigée par une IA. PronoFlash IA ne prend aucun pari et ne vend aucun pronostic.",
    footerNav: 'Informations', adPrefs: 'Préférences publicitaires', adLabel: 'Publicité', sponsored: 'Sponsorisé', aflCta: 'Télécharger gratuitement', closeBanner: 'Fermer la bannière', close: 'Fermer',
    prediction: 'Pronostic', confidence: 'confiance', finalScore: 'Score final', ourPrediction: 'Notre pronostic', inPrep: 'En préparation', probsAria: 'Probabilités 1 N 2', recentForm: 'Forme récente', draw: 'N',
    homeTitle: 'Pronostics foot gratuits du jour · PronoFlash IA',
    homeDesc: 'Pronostics football gratuits, sans inscription : victoire, buts, corners, cartons, handicap. Calcul statistique et analyse IA, mis à jour chaque jour.',
    heroH1: 'Les pronos foot du jour, <b>gratuits</b>', heroP: "Un calcul statistique, une analyse rédigée par l'IA. Pas de compte, pas de clic pour voir le pronostic. Football africain et grands championnats.",
    flash: 'Flash du jour · les 3 plus confiants', theMatches: 'Les matchs', emptyDayB: 'Aucun match suivi ce jour-là.', emptyDayP: 'Les pronostics sont publiés dès que les matchs sont connus. Essaie un autre jour dans la barre ci-dessus.',
    bilanBox: (t, n) => `de réussite sur les 30 derniers jours, ${n} pronostics.`, bilanSide: (n) => `de réussite sur 30 jours, ${n} pronostics.`, seeBilan: 'Voir le bilan complet →',
    dayLabelToday: "d'aujourd'hui", dayLabelTomorrow: 'de demain', dayLabelOther: 'du jour',
    dayH1: (label) => `Pronos foot <b>${label}</b>`, dayP: (date, n) => `${date} : ${n} match${n > 1 ? 's' : ''} suivi${n > 1 ? 's' : ''}, pronostic visible sur chaque carte.`,
    dayTitle: (label, date) => `Pronostics foot ${label} · ${date} · PronoFlash IA`, dayDesc: (date, n) => `Pronostics football du ${date} : ${n} matchs analysés avec probabilités, buts, corners et handicap. Gratuit, sans inscription.`,
    leagueH1: (n) => `Pronostics <b>${n}</b>`, leagueP: (pays) => `${pays} · matchs à venir de la semaine, avec le bilan de nos pronostics sur ce championnat.`,
    leagueBilan: (n, c) => `de réussite sur ${n} (${c} pronostics, 30 jours).`, upcoming: 'Matchs à venir', lastResults: 'Derniers résultats',
    leagueTitle: (n) => `Pronostics ${n} · matchs de la semaine · PronoFlash IA`, leagueDesc: (n) => `Pronostics ${n} gratuits : probabilités, buts, corners, handicap et analyse de chaque match à venir.`,
    crumb: "Fil d'Ariane", vs: 'contre', matchday: (j) => `${j}e journée`, success: '✅ Réussi', failed: '❌ Raté', lowConf: ' (match très ouvert)', confLevel: 'Niveau de confiance',
    aiBadge: "✦ Rédigée par l'IA à partir des chiffres ci-dessus", aiFallback: 'Analyse automatique à partir des chiffres calculés', analysis: 'Analyse',
    seeAnalysis: "Voir l'analyse complète", seeAnalysisSub: (n) => `${n} paris calculés · forme · comparatif · face-à-face · coupons prêts à l'emploi`,
    probsTitle: 'Probabilités calculées', pHome: 'Victoire dom. (1)', pDraw: 'Match nul (N)', pAway: 'Victoire ext. (2)', pOver: '+2,5 buts', pBtts: 'Les 2 marquent', likelyScore: 'Score le plus probable',
    h2h: 'Face-à-face', date: 'Date', fixture: 'Rencontre', score: 'Score', addToCoupon: 'Ajouter à mon coupon', addAria: (l) => `Ajouter « ${l} » au coupon`,
    otherMatches: 'Autres matchs', shareWa: 'Partager sur WhatsApp', copyLink: 'Copier le lien',
    matchDisclaimer: "Pronostic d'aide à la décision : on n'engage rien, aucun gain n'est garanti. PronoFlash IA ne prend aucun pari. 18+ · Jouez de façon responsable.",
    matchTitle: (t, l, d) => `${t} : pronostic ${l} · ${d} · PronoFlash IA`, matchDescIa: (r, t) => `${r} Probabilités, analyse et paris sûrs pour ${t}.`, matchDesc: (t, l, d) => `Pronostic ${t}, ${l}, ${d}.`,
    waMatch: (t, p) => `${t} : ${p}`,
    fullAnalysis: 'Analyse complète', detH1: (t) => `${t} : <b>l'analyse complète</b>`, kickoff: "Coup d'envoi", likely: 'Score probable',
    detIntro: "Tout ce qu'il faut pour préparer ton coupon avec ce match. Les chiffres sont recalculés régulièrement jusqu'au coup d'envoi.",
    moreDetails: 'Voir plus de détails', moreDetailsDone: 'Voir le détail du match',
    morePronos: 'Plus de pronostics sur ce match', morePronosP: 'Nos meilleurs paris par catégorie, avec leur probabilité. Touchez ＋ pour les ajouter à votre coupon.',
    gMain: 'Résultat et buts', gHalf: 'Mi-temps, handicap et score', gOther: 'Corners, tirs, cartons et spéciaux', moreAnalysisBtn: "Voir plus de détails : l'analyse complète",
    ptnLabel: 'Offre partenaire', ptnTitle: "Découvrez l'offre de notre partenaire", ptnBtn: "Voir l'offre",
    advSummary: 'Voir les paris avancés',
    advHint: 'Mi-temps, handicap, score exact, corners, tirs, cartons, spéciaux',
    allBets: 'Tous les paris du match', allBetsP: 'Les paris que proposent les plateformes, pas seulement le résultat et les buts. Chaque ligne indique notre probabilité et la fiabilité de la donnée.',
    reliabilityNote: 'Fiabilité : Haute = beaucoup de données et un modèle éprouvé. Faible = événement rare ou peu de données, donné à titre indicatif et jamais utilisé dans les coupons proposés.',
    fiab: { haute: 'Haute', moyenne: 'Moyenne', faible: 'Faible' }, realOn: (r, n) => `(réel ${r} % sur ${n})`,
    compare: 'Comparatif des deux équipes', compareP: (h, a) => `Moyennes récentes. <b style="color:var(--flash)">${h}</b> à gauche, <b style="color:var(--cy)">${a}</b> à droite.`,
    cmp: { buts_marques: 'Buts marqués', buts_encaisses: 'Buts encaissés', corners: 'Corners', shotsOnTarget: 'Tirs cadrés', shots: 'Tirs', cards: 'Cartons', fouls: 'Fautes', offsides: 'Hors-jeux', points5: 'Points sur les 5 derniers' },
    form: 'Forme et séries', last5: '5 derniers', homeShort: 'Dom.', awayShort: 'Ext.', noHistory: 'Historique indisponible.',
    ourResults: 'Nos résultats sur ce type de pari', ourResultsP: "Ce que nos pronostics ont donné sur les matchs terminés des 90 derniers jours. L'écart entre « annoncé » et « réel » montre si le modèle est fiable.",
    bet: 'Pari', announced: 'Annoncé', real: 'Réel', matches: 'Matchs', notEnough: 'Pas encore assez de matchs terminés pour comparer ces paris. Le bilan se remplit automatiquement au fil des résultats : voir la page',
    readyCoupons: 'Coupons prêts avec ce match', readyCouponsP: "Un clic ouvre le coupon, où tu peux le modifier.", selections: 'sélections', prudent: 'Prudent', balanced: 'Équilibré', bold: 'Audacieux',
    beforeValidate: 'Avant de valider ton coupon',
    checklist: ["Vérifie les compositions 1 h avant le coup d'envoi : une absence change les chiffres.", 'Garde les paris au-dessus de 60 % : un seul maillon faible tire tout le coupon vers le bas.', 'Varie les types de pari (buts, corners, handicap…) pour ne pas dépendre d\'un seul scénario.', 'Reste à 2 ou 3 sélections : au-delà, la probabilité chute vite.'],
    checklistLast: 'Ne joue que ce que tu peux te permettre de perdre. 18+ ·', responsible: 'Jeu responsable', shareAnalysis: "Partager l'analyse sur WhatsApp", waAnalysis: (t) => `Analyse ${t} :`,
    detDisclaimer: "Analyse d'aide à la préparation. On n'engage rien : aucun gain n'est garanti ni promis, et PronoFlash IA ne prend aucun pari.", toc: 'Sommaire',
    tocItems: { resume: 'Résumé', paris: 'Tous les paris', stats: 'Comparatif', forme: 'Forme et séries', h2h: 'Face-à-face', fiab: 'Nos résultats', coupon: 'Coupons prêts', avant: 'Avant de valider' },
    detTitle: (t) => `${t} : analyse complète, tous les paris · PronoFlash IA`, detDesc: (t, l, n) => `Analyse complète de ${t} (${l}) : ${n} paris calculés (résultat, buts, corners, cartons, handicap), forme, comparatif et coupons prêts à l'emploi.`,
    bilanH1: 'Le <b>bilan</b> en toute transparence', bilanP: "Chaque pronostic est enregistré avant le coup d'envoi, puis marqué ✅ ou ❌ automatiquement après le match. Les ratés restent affichés.",
    bilanEmptyB: 'Le bilan se construit.', bilanEmptyP: 'Les premiers résultats apparaissent dès que les premiers matchs suivis sont terminés.',
    kpiRate: 'Réussite 30 jours', kpiN: 'Pronostics', kpiOk: 'Réussis', kpiKo: 'Ratés', weekly: 'Réussite par semaine', weeklyAria: 'Taux de réussite par semaine', weekPrefix: 'S',
    byConf: 'Par niveau de confiance', confRange: (a) => `${a} à ${+a + 9} %`, byConfNote: "Plus la confiance annoncée est haute, plus le taux réel devrait monter : c'est ce qui prouve que le modèle est calibré.",
    byLeague: 'Par championnat', byFamily: 'Par type de pari : annoncé contre réel', famRow: (r, a) => `réel ${r} % · annoncé ${a} %`,
    byFamilyNote: "Tous les paris calculés à fiabilité haute ou moyenne, pas seulement le pronostic principal. « Annoncé » est la probabilité moyenne que nous avions calculée ; « réel » est le taux observé. Plus les deux sont proches, plus le modèle est fiable.",
    ourPick: 'Pronostic', bilanTitle: 'Bilan des pronostics : taux de réussite en toute transparence · PronoFlash IA', bilanDesc: 'Taux de réussite de nos pronostics football calculé automatiquement : par semaine, par championnat, par niveau de confiance et par type de pari.',
    couponH1: 'Compose ton <b>coupon</b>, sans engagement', couponP: 'Combine 2 à 5 matchs et mélange les types de pari : résultat, buts, handicap, corners, tirs, cartons. Le site calcule la probabilité que le coupon passe en entier. Aucune mise, aucune cote, aucun gain promis.',
    proposed: 'Coupons proposés par le calcul', proposedEmpty: 'Les coupons proposés apparaissent dès que plusieurs matchs ont un pronostic.', neverWeak: 'Les paris à fiabilité faible ne sont jamais proposés.',
    noJs: 'Le compositeur de coupon demande JavaScript. Les coupons proposés ci-dessus restent consultables.',
    couponDisclaimer: "PronoFlash IA ne prend aucun pari, n'affiche aucune cote et ne promet aucun gain. Les probabilités sont calculées et ne garantissent rien. 18+ · Jouez de façon responsable.",
    couponTitle: 'Coupon de paris : compose ta combinaison, sans engagement · PronoFlash IA', couponDesc: 'Compose un coupon de 2 à 5 sélections (résultat, buts, handicap, corners, tirs, cartons) et vois la probabilité que tout passe. Sans mise, sans cote, sans compte.',
    nfH1: 'Page <b>introuvable</b>', nfP: "Cette page n'existe pas ou le match n'est plus affiché.", nfToday: 'Pronos du jour', nfTitle: 'Page introuvable · PronoFlash IA',
    footerLegal: { 'a-propos': 'À propos', contact: 'Contact', confidentialite: 'Confidentialité', conditions: 'Conditions', cookies: 'Cookies', 'mentions-legales': 'Mentions légales', 'jeu-responsable': 'Jeu responsable' },
  },
  en: {
    htmlLang: 'en', ogLocale: 'en_GB', skip: 'Skip to content', homeAria: 'PronoFlash IA, home', navMain: 'Main navigation',
    navFootball: 'Football', navCoupon: 'Bet builder', navBilan: 'Track record', navAbout: 'About', myCoupon: 'My slip', langSwitch: 'FR · <b>EN</b>', langSwitchAria: 'Version française',
    sports: 'Sports', basketball: 'Basketball', tennis: 'Tennis', soon: 'soon', days: 'Days', today: 'Today', tomorrow: 'Tomorrow',
    leagues: 'Leagues', all: 'All', tzNote: 'Times shown in your time zone (UTC by default).', utcTitle: 'UTC time',
    footer18: 'Please gamble responsibly', footerInfo: 'Predictions are provided for information only. No winnings are guaranteed. Predictions are calculated by a statistical model and the analysis is written by an AI. PronoFlash IA takes no bets and sells no tips.',
    footerNav: 'Information', adPrefs: 'Ad preferences', adLabel: 'Advertisement', sponsored: 'Sponsored', aflCta: 'Download for free', closeBanner: 'Close the banner', close: 'Close',
    prediction: 'Prediction', confidence: 'confidence', finalScore: 'Final score', ourPrediction: 'Our prediction', inPrep: 'Coming soon', probsAria: '1 X 2 probabilities', recentForm: 'Recent form', draw: 'X',
    homeTitle: "Today's free football predictions · PronoFlash IA",
    homeDesc: 'Free football predictions, no sign-up: match result, goals, corners, cards, handicap. Statistical model and AI analysis, updated every day.',
    heroH1: "Today's football tips, <b>free</b>", heroP: 'A statistical model and an AI-written analysis. No account, no click needed to see the prediction. African football and the top leagues.',
    flash: "Today's flash · the 3 most confident", theMatches: 'Matches', emptyDayB: 'No tracked matches on that day.', emptyDayP: 'Predictions are published as soon as fixtures are known. Try another day in the bar above.',
    bilanBox: (t, n) => `success rate over the last 30 days, ${n} predictions.`, bilanSide: (n) => `success rate over 30 days, ${n} predictions.`, seeBilan: 'See the full track record →',
    dayLabelToday: 'for today', dayLabelTomorrow: 'for tomorrow', dayLabelOther: 'of the day',
    dayH1: (label) => `Football tips <b>${label}</b>`, dayP: (date, n) => `${date}: ${n} tracked match${n > 1 ? 'es' : ''}, prediction shown on every card.`,
    dayTitle: (label, date) => `Football predictions ${label} · ${date} · PronoFlash IA`, dayDesc: (date, n) => `Football predictions for ${date}: ${n} matches analysed with probabilities, goals, corners and handicap. Free, no sign-up.`,
    leagueH1: (n) => `<b>${n}</b> predictions`, leagueP: (pays) => `${pays} · this week's fixtures, with our track record in this competition.`,
    leagueBilan: (n, c) => `success rate in ${n} (${c} predictions, 30 days).`, upcoming: 'Upcoming matches', lastResults: 'Latest results',
    leagueTitle: (n) => `${n} predictions · this week's matches · PronoFlash IA`, leagueDesc: (n) => `Free ${n} predictions: probabilities, goals, corners, handicap and an analysis of every upcoming match.`,
    crumb: 'Breadcrumb', vs: 'vs', matchday: (j) => `Matchday ${j}`, success: '✅ Won', failed: '❌ Lost', lowConf: ' (very open match)', confLevel: 'Confidence level',
    aiBadge: '✦ Written by AI from the figures above', aiFallback: 'Automatic analysis from the calculated figures', analysis: 'Analysis',
    seeAnalysis: 'See the full analysis', seeAnalysisSub: (n) => `${n} bets calculated · form · comparison · head-to-head · ready-made slips`,
    probsTitle: 'Calculated probabilities', pHome: 'Home win (1)', pDraw: 'Draw (X)', pAway: 'Away win (2)', pOver: 'Over 2.5 goals', pBtts: 'Both teams score', likelyScore: 'Most likely score',
    h2h: 'Head-to-head', date: 'Date', fixture: 'Fixture', score: 'Score', addToCoupon: 'Add to my slip', addAria: (l) => `Add "${l}" to the slip`,
    otherMatches: 'Other matches', shareWa: 'Share on WhatsApp', copyLink: 'Copy link',
    matchDisclaimer: 'Decision-support prediction: no commitment, no winnings guaranteed. PronoFlash IA takes no bets. 18+ · Please gamble responsibly.',
    matchTitle: (t, l, d) => `${t}: ${l} prediction · ${d} · PronoFlash IA`, matchDescIa: (r, t) => `${r} Probabilities, analysis and safer bets for ${t}.`, matchDesc: (t, l, d) => `${t} prediction, ${l}, ${d}.`,
    waMatch: (t, p) => `${t}: ${p}`,
    fullAnalysis: 'Full analysis', detH1: (t) => `${t}: <b>the full analysis</b>`, kickoff: 'Kick-off', likely: 'Likely score',
    detIntro: 'Everything you need to build your slip with this match. Figures are recalculated regularly until kick-off.',
    moreDetails: 'See more details', moreDetailsDone: 'See match details',
    morePronos: 'More predictions for this match', morePronosP: 'Our best bets by category, with their probability. Tap ＋ to add them to your slip.',
    gMain: 'Result and goals', gHalf: 'Half-time, handicap and score', gOther: 'Corners, shots, cards and specials', moreAnalysisBtn: 'See more details: the full analysis',
    ptnLabel: 'Partner offer', ptnTitle: "Discover our partner's offer", ptnBtn: 'See the offer',
    advSummary: 'Show advanced bets',
    advHint: 'Half-time, handicap, correct score, corners, shots, cards, specials',
    allBets: 'Every bet for this match', allBetsP: 'The bets bookmakers offer, not just the result and goals. Each line shows our probability and how reliable the data is.',
    reliabilityNote: 'Reliability: High = plenty of data and a proven model. Low = rare event or little data, shown for information only and never used in suggested slips.',
    fiab: { haute: 'High', moyenne: 'Medium', faible: 'Low' }, realOn: (r, n) => `(actual ${r}% over ${n})`,
    compare: 'Head-to-head comparison', compareP: (h, a) => `Recent averages. <b style="color:var(--flash)">${h}</b> on the left, <b style="color:var(--cy)">${a}</b> on the right.`,
    cmp: { buts_marques: 'Goals scored', buts_encaisses: 'Goals conceded', corners: 'Corners', shotsOnTarget: 'Shots on target', shots: 'Shots', cards: 'Cards', fouls: 'Fouls', offsides: 'Offsides', points5: 'Points in the last 5' },
    form: 'Form and streaks', last5: 'last 5', homeShort: 'Home', awayShort: 'Away', noHistory: 'History unavailable.',
    ourResults: 'Our record on these bets', ourResultsP: 'How our predictions did on matches finished in the last 90 days. The gap between "predicted" and "actual" shows how reliable the model is.',
    bet: 'Bet', announced: 'Predicted', real: 'Actual', matches: 'Matches', notEnough: 'Not enough finished matches yet to compare these bets. The track record fills up automatically as results come in: see the',
    readyCoupons: 'Ready-made slips with this match', readyCouponsP: 'One click opens the slip, where you can edit it.', selections: 'selections', prudent: 'Cautious', balanced: 'Balanced', bold: 'Bold',
    beforeValidate: 'Before you confirm your slip',
    checklist: ['Check the line-ups 1 hour before kick-off: one absence changes the numbers.', 'Keep bets above 60%: a single weak link drags the whole slip down.', 'Mix bet types (goals, corners, handicap…) so you do not depend on a single scenario.', 'Stick to 2 or 3 selections: beyond that, the probability drops fast.'],
    checklistLast: 'Only stake what you can afford to lose. 18+ ·', responsible: 'Responsible gambling', shareAnalysis: 'Share the analysis on WhatsApp', waAnalysis: (t) => `${t} analysis:`,
    detDisclaimer: 'Analysis to help you prepare. No commitment: no winnings are guaranteed or promised, and PronoFlash IA takes no bets.', toc: 'Contents',
    tocItems: { resume: 'Summary', paris: 'Every bet', stats: 'Comparison', forme: 'Form', h2h: 'Head-to-head', fiab: 'Our record', coupon: 'Ready slips', avant: 'Before you confirm' },
    detTitle: (t) => `${t}: full analysis, every bet · PronoFlash IA`, detDesc: (t, l, n) => `Full analysis of ${t} (${l}): ${n} bets calculated (result, goals, corners, cards, handicap), form, comparison and ready-made slips.`,
    bilanH1: 'Our <b>track record</b>, in full', bilanP: 'Every prediction is recorded before kick-off, then marked ✅ or ❌ automatically after the match. Losses stay on display.',
    bilanEmptyB: 'The track record is being built.', bilanEmptyP: 'The first results appear as soon as the first tracked matches are over.',
    kpiRate: '30-day success rate', kpiN: 'Predictions', kpiOk: 'Won', kpiKo: 'Lost', weekly: 'Success rate by week', weeklyAria: 'Success rate by week', weekPrefix: 'W',
    byConf: 'By confidence level', confRange: (a) => `${a} to ${+a + 9}%`, byConfNote: 'The higher the stated confidence, the higher the actual rate should be: that is what shows the model is calibrated.',
    byLeague: 'By competition', byFamily: 'By bet type: predicted vs actual', famRow: (r, a) => `actual ${r}% · predicted ${a}%`,
    byFamilyNote: 'Every calculated bet with high or medium reliability, not just the main prediction. "Predicted" is the average probability we calculated; "actual" is the observed rate. The closer they are, the more reliable the model.',
    ourPick: 'Prediction', bilanTitle: 'Prediction track record: our success rate in full · PronoFlash IA', bilanDesc: 'Our football prediction success rate, calculated automatically: by week, by competition, by confidence level and by bet type.',
    couponH1: 'Build your <b>slip</b>, no commitment', couponP: 'Combine 2 to 5 matches and mix bet types: result, goals, handicap, corners, shots, cards. The site calculates the probability that the whole slip comes in. No stake, no odds, no promised winnings.',
    proposed: 'Slips suggested by the model', proposedEmpty: 'Suggested slips appear as soon as several matches have a prediction.', neverWeak: 'Low-reliability bets are never suggested.',
    noJs: 'The slip builder needs JavaScript. The suggested slips above remain available.',
    couponDisclaimer: 'PronoFlash IA takes no bets, shows no odds and promises no winnings. Probabilities are calculated and guarantee nothing. 18+ · Please gamble responsibly.',
    couponTitle: 'Bet builder: build your accumulator, no commitment · PronoFlash IA', couponDesc: 'Build a slip of 2 to 5 selections (result, goals, handicap, corners, shots, cards) and see the probability that it all comes in. No stake, no odds, no account.',
    nfH1: 'Page <b>not found</b>', nfP: 'This page does not exist or the match is no longer listed.', nfToday: "Today's tips", nfTitle: 'Page not found · PronoFlash IA',
    footerLegal: { 'a-propos': 'About', contact: 'Contact', confidentialite: 'Privacy', conditions: 'Terms', cookies: 'Cookies', 'mentions-legales': 'Legal notice', 'jeu-responsable': 'Responsible gambling' },
  },
};

module.exports = { T, pathFor, parsePath, LEGAL_SLUGS };
