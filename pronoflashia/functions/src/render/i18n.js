'use strict';
// Traductions de l'interface et correspondance des adresses entre le français (/) et l'anglais (/en/).

const LEGAL_SLUGS = {
  'a-propos': 'about', contact: 'contact', confidentialite: 'privacy', conditions: 'terms',
  cookies: 'cookies', 'mentions-legales': 'legal-notice', 'jeu-responsable': 'responsible-gambling', annoncer: 'advertise',
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
    case 'news': return en ? '/en/news' : '/actus';
    case 'newsall': return `${en ? '/en/football-news' : '/actualites'}${arg && arg > 1 ? `/${arg}` : ''}`;
    case 'notifs': return en ? '/en/notifications' : '/notifications';
    case 'article': return `${en ? '/en/news' : '/actus'}/${arg.slug}`;
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
    if (seg[0] === 'news') return { lang, name: 'news' };
    if (seg[0] === 'notifications') return { lang, name: 'notifs' };
    if (seg[0] === 'football-news') return { lang, name: 'newsall', arg: 1 };
    if (LEGAL_FR[seg[0]]) return { lang, name: 'legal', arg: LEGAL_FR[seg[0]] };
    if (seg[0] === 'football') return { lang, name: 'football' };
    return { lang, name: 'unknown' };
  }
  if (lang === 'fr' && seg.length === 1) {
    if (seg[0] === 'bilan') return { lang, name: 'bilan' };
    if (seg[0] === 'coupon') return { lang, name: 'coupon' };
    if (seg[0] === 'actus') return { lang, name: 'news' };
    if (seg[0] === 'notifications') return { lang, name: 'notifs' };
    if (seg[0] === 'actualites') return { lang, name: 'newsall', arg: 1 };
    if (LEGAL_SLUGS[seg[0]]) return { lang, name: 'legal', arg: seg[0] };
    if (seg[0] === 'football') return { lang, name: 'football' };
    return { lang, name: 'unknown' };
  }
  if (seg[0] === (lang === 'en' ? 'news' : 'actus') && seg.length === 2 && /^[a-z0-9-]{3,80}$/.test(seg[1])) return { lang, name: 'article', arg: seg[1] };
  if (seg[0] === (lang === 'en' ? 'football-news' : 'actualites') && seg.length === 2 && /^\d{1,3}$/.test(seg[1])) return { lang, name: 'newsall', arg: Math.max(1, Number(seg[1])) };
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
    navFootball: 'Pronostics', navCoupon: 'Coupon', navBilan: 'Bilan', navAbout: 'À propos', myCoupon: 'Mon coupon', langSwitch: '<b>FR</b> · EN', langSwitchAria: 'English version',
    sports: 'Sports', basketball: 'Basketball', tennis: 'Tennis', soon: 'bientôt', days: 'Jours', today: "Aujourd'hui", tomorrow: 'Demain',
    leagues: 'Championnats', all: 'Tous', tzNote: 'Heures affichées dans ton fuseau horaire (UTC par défaut).', utcTitle: 'Heure UTC',
    footer18: 'Jouez de façon responsable', footerInfo: "Pronostics fournis à titre d'information. Aucun gain n'est garanti. Les pronostics sont calculés par un modèle statistique et l'analyse est rédigée par une IA. PronoFlash IA ne prend aucun pari et ne vend aucun pronostic.",
    footerNav: 'Informations', adPrefs: 'Préférences publicitaires', adLabel: 'Publicité', sponsored: 'Sponsorisé', aflCta: 'Télécharger gratuitement', closeBanner: 'Fermer la bannière', close: 'Fermer',
    prediction: 'Pronostic', confidence: 'confiance', finalScore: 'Score final', ourPrediction: 'Notre pronostic', inPrep: 'En préparation', probsAria: 'Probabilités 1 N 2', recentForm: 'Forme récente', draw: 'N',
    homeTitle: 'Pronostics foot gratuits du jour · PronoFlash IA',
    homeDesc: "Pronostics football gratuits, sans inscription : une IA qui apprend de chaque équipe, suit l'actualité et corrige ses erreurs grâce à un bilan public. Coupons du jour, football africain et grands championnats.",
    heroH1: 'Les pronos foot du jour, <b>gratuits</b>', heroP: "Notre IA apprend de chaque équipe, suit l'actualité et corrige ses erreurs grâce à son bilan public. Gratuit, sans compte. Football africain et grands championnats.", heroMore: "Comment notre IA apprend",
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
    flashCoupons: 'Coupons flash', flashCouponsP: "Des coupons prêts à l'emploi, de 2 à 5 sélections, avec la vraie probabilité que tout passe. Touchez-en un pour le modifier dans le constructeur de coupon.", flashCouponsBtn: 'Voir plus de coupons',
    navIcons: { football: '⚽', coupon: '🎯', bilan: '📊', about: 'ℹ️' },
    chanTitle: 'Suis notre canal WhatsApp', chanText: 'Les nouveautés et les pronos du jour, directement sur ton téléphone. Gratuit.', chanBtn: 'Suivre le canal',
    exploitTitle: 'Nos derniers coupons gagnants', exploitBtn: "Voir tout l'historique",
    exploitP: (g, n, taux, j) => `Sur les ${j} derniers jours : ${g} coupon${g > 1 ? 's' : ''} gagné${g > 1 ? 's' : ''} sur ${n} réglé${n > 1 ? 's' : ''} (${taux}\u00a0%).${n < 20 ? ' Échantillon encore petit : à prendre avec prudence.' : ''} Les coupons perdus sont publiés aussi : tout l'historique est sur la page Bilan.`,
    couponHistTitle: 'Historique des coupons flash', couponHistP: "Chaque jour, trois coupons (2, 3 et 5 sélections) sont enregistrés automatiquement avant les matchs, puis réglés après. Rien n'est trié après coup : les gagnants et les perdus sont tous ici.",
    couponTierRow: (g, n, taux, annonce) => `${g} gagné${g > 1 ? 's' : ''} sur ${n} · réel ${taux}\u00a0% · annoncé ${annonce}\u00a0%`, couponNoSettled: 'Pas encore de coupon réglé.',
    couponWon: 'Gagné', couponLost: 'Perdu', couponOpen: 'En cours', couponVoid: 'Annulé', couponProb: (p) => `Probabilité annoncée : ${p}\u00a0%`, couponOf: (d) => `Coupon du ${d}`,
    bilanHeroT: 'Notre bilan en toute transparence',
    newsMore: 'Toutes les actus foot', newsTitle: 'Actus foot', newsTeams: 'Actus des deux équipes', newsNote: "Titres et liens des sites d'origine : un clic ouvre l'article sur leur site.", newsNow: "à l'instant", newsHours: (h) => `il y a ${h} h`, newsDays: (d) => `il y a ${d} j`,
    shTitle: 'Merci, et fais connaître PronoFlash IA', shP: "PronoFlash IA est gratuit. Chaque visite, et chaque publicité que tu regardes par choix, finance déjà nos serveurs et nos données de football : un grand merci à toi, et merci de nous faire connaître. Plus on est nombreux, plus on peut suivre de championnats, publier de pronostics et de coupons et améliorer l'IA. Partage le site à tes amis, à ta famille et dans tes groupes !", shMsg: 'PronoFlash IA : pronostics de foot gratuits, coupons du jour et actus, sans inscription.', shWa: 'Partager sur WhatsApp', shNat: 'Partager', shCopy: 'Copier le lien', shCopied: 'Lien copié ✓',
    mlTitle: 'Coupons VIP par e-mail, toujours gratuits', mlP: "Bientôt : chaque matin, un récapitulatif complet dans ta boîte mail (les coupons du jour, les matchs à suivre et le point foot). Aucun paiement, aucun abonnement payant. Laisse ton adresse pour être prévenu(e) dès l'ouverture des envois.", mlEmail: 'Ton adresse e-mail', mlConsent: "J'accepte de recevoir par e-mail les coupons, pronostics et actus de PronoFlash IA. Je peux me désinscrire à tout moment. Mes données sont traitées selon la", mlPriv: 'politique de confidentialité', mlBtn: "Je m'inscris", mlOk: "Merci ! Ton adresse est enregistrée : on te prévient dès que les envois démarrent.", mlBad: 'Vérifie ton adresse e-mail et coche la case d\'accord.', mlErr: 'Inscription impossible pour le moment. Réessaie plus tard.',
    stCredit: (src) => `Image : ${src}`, stPlay: 'Lire la vidéo', stEssential: "L'essentiel", stPublished: 'Publié', stTopics: 'Sujets', stTopicNames: { star: 'Star du foot', club: 'Grand club', enfant: 'Relève des légendes', talent: 'Jeune talent', classico: 'Classico / derby', transfert: 'Mercato', record: 'Record', vie: 'Vie de star', scandale: 'Polémique' }, stEvery: 'Tout ce qui est publié ici vient du site cité : nous ne reprenons que le titre, un extrait, l\'image d\'aperçu et la vidéo qu\'il propose, avec le lien pour tout lire.', stMore: 'Plus d\'actus',
    abShareTitle: 'Partager cette page', abShareP: "Envoie la présentation de PronoFlash IA dans tes groupes et sur ton canal WhatsApp : le message contient l'essentiel du site et le lien affiche un aperçu avec le titre, la description et l'image.", abShareMsg: "⚡ PronoFlash IA : pronostics de foot gratuits, faits par une IA qui apprend chaque équipe.\n✅ Coupons du jour et analyse de chaque match\n📊 Bilan public : nos réussites ET nos ratés\n🔔 Alertes sur tes équipes et actus foot\n🚫 Aucun pari pris, aucun gain promis · 18+\n👉 Découvre le site :",
    stReads: (n) => `${n} ${n > 1 ? 'lectures' : 'lecture'}`,
    naTitle: 'Toutes les actus foot', naH1: 'Toutes les actus foot', naP: "Les dernières actualités du football relevées chez nos sources, des plus récentes aux plus anciennes : un clic ouvre notre page de l'actu, avec l'image, l'extrait et le lien vers l'article complet.", naDesc: "Toutes les actualités football du moment (mercato, stars, matchs, Afrique), avec la source et le lien de chaque article.", newsAllBtn: 'Voir toutes les actus foot', naPrev: '← Plus récentes', naNext: 'Plus anciennes →', naPage: (a, b) => `Page ${a} sur ${b}`, naEmpty: "Aucune actualité pour le moment : elles arrivent toutes les 2 heures.", naRecap: "Le point foot du soir",
    cLearnTitle: "Ce que l'IA apprend de ses coupons", cLearnIntro: "Chaque sélection de nos coupons est suivie, réussie ou ratée. L'IA compare ce taux de réussite à la probabilité qu'elle avait annoncée, type de pari par type de pari, et corrige les coupons suivants (de 10 points au plus, et seulement quand assez de sélections sont terminées).", cLearnWait: (n, m) => `Pas encore assez de sélections terminées (${n} sur ${m}) : aucune correction pour l'instant.`, cLearnRow: (fam, reel, annonce, n, pts) => `${fam} : ${reel} % de réussite pour ${annonce} % annoncés (${n} sélections) → ${pts === 0 ? 'conforme, aucune correction' : pts < 0 ? `annoncé ${-pts} point${-pts > 1 ? 's' : ''} plus bas dans les coupons` : `annoncé ${pts} point${pts > 1 ? 's' : ''} plus haut dans les coupons`}`, cLearnGlobal: (n, pts) => `Sur ${n} sélections terminées, l'écart moyen entre le réel et l'annoncé est de ${pts > 0 ? '+' : ''}${pts} point${Math.abs(pts) > 1 ? 's' : ''}. Les paris qui déçoivent sont moins choisis ; ceux qui tiennent leurs promesses le sont davantage.`,
    advBoxTitle: 'Une marque, une entreprise, un commerce ?', advBoxP: "Vous voulez faire connaître votre produit, votre service ou votre application auprès des amateurs de football ? Nous vendons des espaces publicitaires sur PronoFlash IA : écrivez-nous.", advBoxBtn: 'Annoncer sur PronoFlash IA', advContactTitle: 'Nous contacter', advWa: 'Nous écrire sur WhatsApp', advMail: 'Écrire par e-mail', advMailSubject: 'Publicité sur PronoFlash IA', advChannel: 'Suivre notre canal WhatsApp', advTodo: "coordonnées de contact à renseigner dans l'administration", advToContact: 'Page de contact',
    ibxTitle: 'Mes notifications', ibxH1: 'Mes notifications', ibxP: "Retrouve ici les notifications reçues sur cet appareil, lues ou non. Pas de compte à créer : la liste est liée à ce navigateur.", ibxLoading: 'Chargement…',
    bellOff: 'Recevoir les coupons du jour en notification', bellOn: 'Notifications activées : toucher pour voir tes notifications', followLbl: 'Alertes avant leurs matchs :', followOn: (n) => `🔔 ${n} suivi`, followOff: (n) => `🔔 Suivre ${n}`,
    notesTitle: "Ce que l'IA sait de ces équipes", notesP: "Notes calculées sur tous les matchs connus (saison précédente comprise), en comptant davantage les matchs récents et en tenant compte du niveau des adversaires. Elles sont jugées sur des matchs passés avant d'être utilisées dans le calcul.",
    notesAtk: (v) => (Math.abs(v) < 5 ? 'Attaque : dans la moyenne du championnat' : `Attaque : ${Math.abs(v)}\u00a0% ${v > 0 ? 'au-dessus' : 'en dessous'} de la moyenne du championnat`),
    notesDef: (v) => (Math.abs(v) < 5 ? 'Défense : dans la moyenne du championnat' : `Défense : encaisse ${Math.abs(v)}\u00a0% de buts ${v > 0 ? 'en plus' : 'en moins'} que la moyenne`),
    notesEvol: (a, d) => { const bits = []; if (a != null && Math.abs(a) >= 5) bits.push(`attaque ${a > 0 ? 'en hausse' : 'en baisse'} (${a > 0 ? '+' : '−'}${Math.abs(a)}\u00a0%)`); if (d != null && Math.abs(d) >= 5) bits.push(`défense ${d < 0 ? 'en progrès' : 'en recul'} (${d > 0 ? '+' : '−'}${Math.abs(d)}\u00a0% de buts encaissés)`); return bits.length ? `Sur 60 jours : ${bits.join(', ')}` : ''; },
    fragileLbl: 'Données limitées', fragileNote: "Données limitées : une équipe a joué peu de matchs cette saison, ou elle est peu connue de notre modèle. Pronostic à prendre avec plus de prudence ; il n'est pas utilisé dans les coupons proposés.",
    newsFacts: 'Infos récentes sur les équipes', newsFactsNote: "Lues par l'IA dans les titres de presse, toujours avec leur source. Elles informent : aucune probabilité n'est modifiée à cause d'elles.",
    fact: (f) => { const who = f.joueur ? ` de ${f.joueur}` : ''; const base = { absence: `🩹 Absence${who} signalée côté ${f.equipe}`, suspension: `🟥 Suspension${who} signalée côté ${f.equipe}`, retour: `✅ Retour${who} signalé côté ${f.equipe}`, entraineur: `🧢 Changement d'entraîneur signalé chez ${f.equipe}` }[f.type]; return base ? base + (f.certitude === 'rumeur' ? ' (à confirmer)' : '') + ' · ' : ''; },
    sigTitle: 'Nos pronostics selon les signaux affichés', sigP: "Les mentions « Données limitées » et « Infos récentes » informent mais ne changent aucune probabilité. Ce tableau mesure, avec nos propres résultats, si les pronostics concernés réussissent vraiment moins souvent.",
    sigLabel: { aucun: 'Aucun signal', actu: 'Infos récentes signalées', limite: 'Données limitées' },
    pfTitle: 'Le point foot', pfNav: 'Le point foot', pfIndexTitle: 'Le point foot : l\'actualité du football résumée chaque jour · PronoFlash IA',
    pfIndexDesc: "Chaque soir, le point sur le football : résultats, nos pronostics, matchs à suivre et infos de la presse, avec les sources citées. Rédigé par l'IA de PronoFlash.",
    pfIndexH1: 'Le point foot', pfIndexP: "Chaque soir, notre IA résume la journée de football : résultats, nos pronostics réussis ou ratés, matchs à suivre et infos de la presse, toujours avec les sources.",
    pfEmpty: "Le premier « point foot » sera publié ce soir.", pfSeeAll: 'Tous les « points foot »', pfRead: 'Lire',
    pfBy: "Rédigé par l'IA de PronoFlash à partir de nos données et de sources citées.", pfRetain: "Ce qu'il faut retenir", pfWatch: 'Matchs à surveiller', pfWatchP: "Notre pronostic reste une probabilité : les infos de la presse sont signalées sur la fiche du match mais ne modifient aucune probabilité.",
    pfResults: 'Les résultats et nos pronostics', pfSources: 'Sources', pfSourcesP: "Informations de presse reprises avec leur source ; seules les informations factuelles sont résumées, avec nos propres mots. Un clic ouvre l'article d'origine sur le site de la source.",
    pfDetails: 'Voir le détail', pfOk: 'pronostic réussi', pfKo: 'pronostic raté', pfDisclaimer: "Contenu informatif. PronoFlash IA ne prend aucun pari et ne promet aucun gain : un pronostic est une probabilité, pas une certitude. 18+ · Jouez de façon responsable.",
    pfShare: 'Partager sur WhatsApp', pfCoverKicker: 'LE POINT FOOT',
    pfDesc: (d) => `Le point foot du ${d} : résultats, nos pronostics, matchs à suivre et infos de la presse, sources citées.`,
    stKicker: 'ACTU FOOT', stSource: 'Source :', stRead: (src) => `Lire l'article complet sur ${src}`, stNote: (src) => `Titre et extrait appartiennent à ${src} : nous les citons avec la source et un lien pour lire l'article complet. L'éclairage ci-dessous est le nôtre, calculé avec nos données.`,
    stOurs: 'Ce que ça change pour nos pronostics', stOursP: "Cette information est signalée sur la fiche du match mais ne modifie aucune probabilité : voici nos pronostics et ce que l'IA sait de ces équipes.",
    stRelated: 'Dans la même actualité', stFlash: 'Nos pronostics les plus confiants du jour', stDesc: (src) => `Une actu du football relevée chez ${src}, avec le lien vers l'article complet et nos pronostics.`,
    learnTitle: "Ce que l'IA a appris", learnIntro: "L'IA compare chacun de ses pronostics au résultat réel et corrige ses calculs quand elle se trompe de façon régulière. Voici ses corrections actuelles.",
    learnWait: (n, seuil) => `L'IA commence à se corriger dès ${seuil} pronostics terminés (${n} pour l'instant).`,
    learnNone: 'Pour le moment, nos probabilités sont proches des résultats réels : aucune correction n\'est nécessaire.',
    learnFam: (f, e) => `${f} : nos probabilités étaient ${e < 0 ? 'trop élevées' : 'trop basses'} d'environ ${Math.abs(e)} point${Math.abs(e) > 1 ? 's' : ''}. Elles sont maintenant corrigées.`,
    learnGoals: (d, e) => `Niveau de buts : estimation corrigée de ${d > 0 ? '+' : ''}${d} % à domicile et de ${e > 0 ? '+' : ''}${e} % à l'extérieur d'après les résultats réels.`,
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
    footerLegal: { 'a-propos': 'À propos', annoncer: 'Annoncer', contact: 'Contact', confidentialite: 'Confidentialité', conditions: 'Conditions', cookies: 'Cookies', 'mentions-legales': 'Mentions légales', 'jeu-responsable': 'Jeu responsable' },
  },
  en: {
    htmlLang: 'en', ogLocale: 'en_GB', skip: 'Skip to content', homeAria: 'PronoFlash IA, home', navMain: 'Main navigation',
    navFootball: 'Predictions', navCoupon: 'Bet builder', navBilan: 'Track record', navAbout: 'About', myCoupon: 'My slip', langSwitch: 'FR · <b>EN</b>', langSwitchAria: 'Version française',
    sports: 'Sports', basketball: 'Basketball', tennis: 'Tennis', soon: 'soon', days: 'Days', today: 'Today', tomorrow: 'Tomorrow',
    leagues: 'Leagues', all: 'All', tzNote: 'Times shown in your time zone (UTC by default).', utcTitle: 'UTC time',
    footer18: 'Please gamble responsibly', footerInfo: 'Predictions are provided for information only. No winnings are guaranteed. Predictions are calculated by a statistical model and the analysis is written by an AI. PronoFlash IA takes no bets and sells no tips.',
    footerNav: 'Information', adPrefs: 'Ad preferences', adLabel: 'Advertisement', sponsored: 'Sponsored', aflCta: 'Download for free', closeBanner: 'Close the banner', close: 'Close',
    prediction: 'Prediction', confidence: 'confidence', finalScore: 'Final score', ourPrediction: 'Our prediction', inPrep: 'Coming soon', probsAria: '1 X 2 probabilities', recentForm: 'Recent form', draw: 'X',
    homeTitle: "Today's free football predictions · PronoFlash IA",
    homeDesc: 'Free football predictions, no sign-up: an AI that learns from every team, follows the news and corrects its mistakes thanks to a public track record. Slips of the day, African football and the top leagues.',
    heroH1: "Today's football tips, <b>free</b>", heroP: 'Our AI learns from every team, follows the news and corrects its mistakes thanks to its public track record. Free, no account. African football and the top leagues.', heroMore: 'How our AI learns',
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
    flashCoupons: 'Flash slips', flashCouponsP: 'Ready-made slips of 2 to 5 selections, with the real probability that everything wins. Tap one to edit it in the slip builder.', flashCouponsBtn: 'See more slips',
    navIcons: { football: '⚽', coupon: '🎯', bilan: '📊', about: 'ℹ️' },
    chanTitle: 'Follow our WhatsApp channel', chanText: 'News and the day\'s predictions, straight to your phone. Free.', chanBtn: 'Follow the channel',
    exploitTitle: 'Our latest winning slips', exploitBtn: 'See the full history',
    exploitP: (g, n, taux, j) => `Over the last ${j} days: ${g} slip${g > 1 ? 's' : ''} won out of ${n} settled (${taux}%).${n < 20 ? ' Small sample so far: take it with caution.' : ''} Lost slips are published too: the full history is on the Track record page.`,
    couponHistTitle: 'Flash slip history', couponHistP: 'Every day, three slips (2, 3 and 5 selections) are saved automatically before the matches, then settled afterwards. Nothing is picked after the fact: the winners and the losers are all here.',
    couponTierRow: (g, n, taux, annonce) => `${g} won out of ${n} · actual ${taux}% · announced ${annonce}%`, couponNoSettled: 'No settled slip yet.',
    couponWon: 'Won', couponLost: 'Lost', couponOpen: 'Open', couponVoid: 'Void', couponProb: (p) => `Announced probability: ${p}%`, couponOf: (d) => `Slip of ${d}`,
    bilanHeroT: 'Our track record, in full transparency',
    newsMore: 'More football news', newsTitle: 'Football news', newsTeams: 'News on both teams', newsNote: 'Headlines and links from the original sites: a click opens the article on their site.', newsNow: 'just now', newsHours: (h) => `${h}h ago`, newsDays: (d) => `${d}d ago`,
    shTitle: 'Thank you, and spread the word about PronoFlash IA', shP: 'PronoFlash IA is free. Every visit, and every ad you choose to watch, already pays for our servers and football data: a big thank you, and thanks for helping us get known. The more of us there are, the more leagues we can follow, the more predictions and slips we can publish, and the better the AI gets. Share the site with your friends, your family and your groups!', shMsg: 'PronoFlash IA: free football predictions, slips of the day and news, no sign-up.', shWa: 'Share on WhatsApp', shNat: 'Share', shCopy: 'Copy the link', shCopied: 'Link copied ✓',
    mlTitle: 'VIP slips by e-mail, always free', mlP: 'Coming soon: every morning, a full roundup in your inbox (the slips of the day, the matches to watch and the football roundup). No payment, no paid subscription. Leave your address to be told as soon as sending starts.', mlEmail: 'Your e-mail address', mlConsent: 'I agree to receive PronoFlash IA slips, predictions and news by e-mail. I can unsubscribe at any time. My data is handled according to the', mlPriv: 'privacy policy', mlBtn: 'Sign me up', mlOk: 'Thank you! Your address is saved: we will tell you as soon as sending starts.', mlBad: 'Check your e-mail address and tick the consent box.', mlErr: 'Sign-up is not possible right now. Try again later.',
    stCredit: (src) => `Image: ${src}`, stPlay: 'Play the video', stEssential: 'At a glance', stPublished: 'Published', stTopics: 'Topics', stTopicNames: { star: 'Football star', club: 'Big club', enfant: 'Next generation', talent: 'Young talent', classico: 'Classico / derby', transfert: 'Transfers', record: 'Record', vie: 'Star life', scandale: 'Controversy' }, stEvery: 'Everything shown here comes from the site quoted: we only reuse the headline, an excerpt, the preview image and the video it offers, with the link to read it all.', stMore: 'More news',
    abShareTitle: 'Share this page', abShareP: 'Send the PronoFlash IA presentation to your groups and WhatsApp channel: the message holds the essentials of the site and the link shows a preview with the title, the description and the image.', abShareMsg: "⚡ PronoFlash IA: free football predictions, made by an AI that learns every team.\n✅ Slips of the day and analysis of every match\n📊 Public track record: our hits AND our misses\n🔔 Alerts for your teams and football news\n🚫 No bets taken, no winnings promised · 18+\n👉 Discover the site:",
    stReads: (n) => `${n} ${n > 1 ? 'views' : 'view'}`,
    naTitle: 'All football news', naH1: 'All football news', naP: 'The latest football news spotted at our sources, newest first: a click opens our page for the story, with the image, the excerpt and the link to the full article.', naDesc: 'All the football news of the moment (transfers, stars, matches, Africa), with the source and the link of every article.', newsAllBtn: 'See all football news', naPrev: '← Newer', naNext: 'Older →', naPage: (a, b) => `Page ${a} of ${b}`, naEmpty: 'No news for now: new stories arrive every 2 hours.', naRecap: 'The evening roundup',
    cLearnTitle: 'What the AI learns from its slips', cLearnIntro: 'Every selection in our slips is tracked, hit or missed. The AI compares that hit rate with the probability it announced, bet type by bet type, and corrects the next slips (by 10 points at most, and only when enough selections are finished).', cLearnWait: (n, m) => `Not enough finished selections yet (${n} of ${m}): no correction for now.`, cLearnRow: (fam, reel, annonce, n, pts) => `${fam}: ${reel}% hit rate for ${annonce}% announced (${n} selections) → ${pts === 0 ? 'in line, no correction' : pts < 0 ? `announced ${-pts} point${-pts > 1 ? 's' : ''} lower in slips` : `announced ${pts} point${pts > 1 ? 's' : ''} higher in slips`}`, cLearnGlobal: (n, pts) => `Over ${n} finished selections, the average gap between real and announced is ${pts > 0 ? '+' : ''}${pts} point${Math.abs(pts) > 1 ? 's' : ''}. Bets that disappoint are picked less; bets that keep their promises are picked more.`,
    advBoxTitle: 'A brand, a company, a business?', advBoxP: 'Want to promote your product, service or app to football fans? We sell advertising space on PronoFlash IA: write to us.', advBoxBtn: 'Advertise on PronoFlash IA', advContactTitle: 'Contact us', advWa: 'Write to us on WhatsApp', advMail: 'Send an e-mail', advMailSubject: 'Advertising on PronoFlash IA', advChannel: 'Follow our WhatsApp channel', advTodo: 'contact details to fill in from the admin', advToContact: 'Contact page',
    ibxTitle: 'My notifications', ibxH1: 'My notifications', ibxP: 'Find here the notifications received on this device, read or not. No account needed: the list is tied to this browser.', ibxLoading: 'Loading…',
    bellOff: "Get today's slips as notifications", bellOn: 'Notifications on: tap to see your notifications', followLbl: 'Alerts before their matches:', followOn: (n) => `🔔 ${n} followed`, followOff: (n) => `🔔 Follow ${n}`,
    notesTitle: 'What the AI knows about these teams', notesP: 'Ratings computed on every known match (previous season included), giving more weight to recent matches and accounting for the strength of opponents. They are tested on past matches before being used in the calculation.',
    notesAtk: (v) => (Math.abs(v) < 5 ? 'Attack: around the league average' : `Attack: ${Math.abs(v)}% ${v > 0 ? 'above' : 'below'} the league average`),
    notesDef: (v) => (Math.abs(v) < 5 ? 'Defence: around the league average' : `Defence: concedes ${Math.abs(v)}% ${v > 0 ? 'more' : 'fewer'} goals than average`),
    notesEvol: (a, d) => { const bits = []; if (a != null && Math.abs(a) >= 5) bits.push(`attack ${a > 0 ? 'improving' : 'declining'} (${a > 0 ? '+' : '−'}${Math.abs(a)}%)`); if (d != null && Math.abs(d) >= 5) bits.push(`defence ${d < 0 ? 'improving' : 'weakening'} (${d > 0 ? '+' : '−'}${Math.abs(d)}% goals conceded)`); return bits.length ? `Over 60 days: ${bits.join(', ')}` : ''; },
    fragileLbl: 'Limited data', fragileNote: 'Limited data: one team has played few matches this season, or our model knows it little. Take this pick with extra caution; it is not used in the suggested slips.',
    newsFacts: 'Recent news on the teams', newsFactsNote: 'Read by the AI from press headlines, always with their source. They inform: no probability is changed because of them.',
    fact: (f) => { const who = f.joueur ? ` of ${f.joueur}` : ''; const base = { absence: `🩹 Absence${who} reported for ${f.equipe}`, suspension: `🟥 Suspension${who} reported for ${f.equipe}`, retour: `✅ Return${who} reported for ${f.equipe}`, entraineur: `🧢 Coaching change reported at ${f.equipe}` }[f.type]; return base ? base + (f.certitude === 'rumeur' ? ' (to be confirmed)' : '') + ' · ' : ''; },
    sigTitle: 'Our predictions by displayed signal', sigP: '"Limited data" and "Recent news" inform but never change a probability. This table measures, with our own results, whether the predictions concerned really succeed less often.',
    sigLabel: { aucun: 'No signal', actu: 'Recent news flagged', limite: 'Limited data' },
    pfTitle: 'Football roundup', pfNav: 'Roundup', pfIndexTitle: 'Football roundup: the day in football, every evening · PronoFlash IA',
    pfIndexDesc: "Every evening, the football day in a nutshell: results, our predictions, matches to watch and press news, with sources cited. Written by PronoFlash's AI.",
    pfIndexH1: 'Football roundup', pfIndexP: 'Every evening, our AI sums up the football day: results, our predictions that succeeded or missed, matches to watch and press news, always with sources.',
    pfEmpty: 'The first roundup will be published this evening.', pfSeeAll: 'All roundups', pfRead: 'Read',
    pfBy: "Written by PronoFlash's AI from our data and cited sources.", pfRetain: 'Key takeaways', pfWatch: 'Matches to watch', pfWatchP: 'Our prediction remains a probability: press news is flagged on the match page but changes no probability.',
    pfResults: 'Results and our predictions', pfSources: 'Sources', pfSourcesP: 'Press information is credited to its source; only factual information is summarised, in our own words. A click opens the original article on the source site.',
    pfDetails: 'See details', pfOk: 'prediction succeeded', pfKo: 'prediction missed', pfDisclaimer: 'Informational content. PronoFlash IA takes no bets and promises no winnings: a prediction is a probability, not a certainty. 18+ · Play responsibly.',
    pfShare: 'Share on WhatsApp', pfCoverKicker: 'FOOTBALL ROUNDUP',
    pfDesc: (d) => `Football roundup, ${d}: results, our predictions, matches to watch and press news, sources cited.`,
    stKicker: 'FOOTBALL NEWS', stSource: 'Source:', stRead: (src) => `Read the full article on ${src}`, stNote: (src) => `Headline and excerpt belong to ${src}: we quote them with the source and a link to read the full article. The insight below is ours, computed from our own data.`,
    stOurs: 'What it means for our predictions', stOursP: 'This information is flagged on the match page but changes no probability: here are our predictions and what the AI knows about these teams.',
    stRelated: 'More on the same story', stFlash: 'Our most confident picks today', stDesc: (src) => `A football story spotted at ${src}, with the link to the full article and our predictions.`,
    learnTitle: 'What the AI has learned', learnIntro: 'The AI compares each of its predictions with the real result and corrects its calculations when it is wrong in a consistent way. Here are its current corrections.',
    learnWait: (n, seuil) => `The AI starts correcting itself after ${seuil} finished predictions (${n} so far).`,
    learnNone: 'For now our probabilities are close to the real results: no correction is needed.',
    learnFam: (f, e) => `${f}: our probabilities were about ${Math.abs(e)} point${Math.abs(e) > 1 ? 's' : ''} too ${e < 0 ? 'high' : 'low'}. They are now corrected.`,
    learnGoals: (d, e) => `Goal level: estimate adjusted by ${d > 0 ? '+' : ''}${d}% at home and ${e > 0 ? '+' : ''}${e}% away based on real results.`,
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
    footerLegal: { 'a-propos': 'About', annoncer: 'Advertise', contact: 'Contact', confidentialite: 'Privacy', conditions: 'Terms', cookies: 'Cookies', 'mentions-legales': 'Legal notice', 'jeu-responsable': 'Responsible gambling' },
  },
};

module.exports = { T, pathFor, parsePath, LEGAL_SLUGS };
