'use strict';
// Pages obligatoires pour les réseaux publicitaires et le RGPD. Les champs à remplir par l'éditeur viennent de config/site.
// À faire relire par un juriste avant la mise en ligne.

const { esc } = require('../util/format');

/** Champ à compléter : affiché en évidence tant que l'éditeur ne l'a pas renseigné dans l'admin. */
const field = (v, label) => (v ? esc(v) : `<span class="todo">[${esc(label)} à renseigner dans l'administration]</span>`);

const prose = (inner) => `<div class="wrap"><div class="layout"><div class="col prose">${inner}</div></div></div>`;

const PAGES = {
  'a-propos': (rc) => ({
    title: 'À propos de PronoFlash IA',
    description: 'Qui édite PronoFlash IA et comment sont faits les pronostics : un calcul statistique, une analyse rédigée par une IA, un bilan public.',
    body: prose(`<h1>À propos de PronoFlash IA</h1>
<p>PronoFlash IA est un site gratuit de pronostics sportifs, sans inscription. Il commence par le football, avec une place particulière pour le football africain, et s'ouvrira à d'autres sports.</p>
<h2>Qui édite le site ?</h2>
<p>Le site est édité par ${field(rc.site.editeur, 'nom de l\'éditeur')}. Il est financé par la publicité et par la promotion d'Afrolook, l'application sociale du même éditeur. Les pronostics ne sont jamais vendus et le site n'accepte aucune rémunération de la part des bookmakers pour orienter un pronostic.</p>
<h2>Comment sont faits les pronostics ?</h2>
<ul><li><b>Le calcul vient d'abord.</b> Pour chaque match, un modèle statistique estime les buts attendus de chaque équipe à partir de ses résultats récents, à domicile et à l'extérieur, et des moyennes du championnat. Il en déduit la probabilité de chaque issue : résultat, buts, handicap, mi-temps, corners, tirs, cartons.</li>
<li><b>L'IA rédige ensuite.</b> Une intelligence artificielle reçoit les chiffres calculés et rédige l'analyse. Elle n'a pas le droit de modifier un chiffre ni d'en inventer : toute analyse qui s'écarte des chiffres fournis est refusée automatiquement.</li>
<li><b>Les résultats sont publics.</b> Chaque pronostic est enregistré avant le match puis marqué réussi ou raté. Le <a href="/bilan">bilan</a> montre le taux réel, ratés compris.</li></ul>
<h2>Ce que le site ne fait pas</h2>
<p>PronoFlash IA ne prend aucun pari, n'affiche aucune cote, ne vend aucun pronostic et ne promet aucun gain. Un pronostic est une probabilité, pas une certitude. Voir la page <a href="/jeu-responsable">jeu responsable</a>.</p>
<h2>Données</h2>
<p>Les calendriers, résultats et statistiques de matchs proviennent d'API-Football (api-sports.io). Les noms des équipes sont affichés en texte, avec leur logo fourni par le fournisseur de données (à défaut, un écusson généré). Les logos et noms des clubs appartiennent à leurs propriétaires respectifs et ne sont utilisés qu'à titre d'illustration ; aucun partenariat ni parrainage n'est suggéré.</p>`),
  }),

  contact: (rc) => ({
    title: 'Contact · PronoFlash IA',
    description: 'Contacter l\'équipe de PronoFlash IA : question, erreur sur un pronostic, demande sur les données personnelles.',
    body: prose(`<h1>Contact</h1>
<p>Pour une question, signaler une erreur dans un pronostic ou exercer tes droits sur tes données personnelles, écris à : <b>${field(rc.site.email, 'adresse e-mail de contact')}</b>.</p>
<p>Nous ne répondons pas aux demandes de pronostics personnalisés ni de « tuyaux » : le site publie les mêmes pronostics pour tout le monde, gratuitement.</p>
<p>Éditeur : ${field(rc.site.editeur, 'nom de l\'éditeur')}.</p>`),
  }),

  confidentialite: (rc) => ({
    title: 'Politique de confidentialité · PronoFlash IA',
    description: 'Données collectées par PronoFlash IA : mesure d\'audience sans cookie, publicité, droits RGPD.',
    body: prose(`<h1>Politique de confidentialité</h1>
<p>PronoFlash IA ne demande ni inscription ni compte. Cette page explique les données qui transitent quand tu visites le site.</p>
<h2>Mesure d'audience sans cookie</h2>
<p>Nous comptons les visites avec un outil maison, sans cookie et sans identifiant stocké sur ton appareil. Seuls des <b>compteurs agrégés</b> sont enregistrés : nombre de visites et de pages vues, pays estimé, type d'appareil (téléphone, ordinateur), source de la visite (direct, moteur de recherche, réseau social), page consultée. Ton adresse IP n'est jamais enregistrée. Pour estimer le nombre de visiteurs uniques, une empreinte hachée avec un sel qui change chaque jour est calculée en mémoire puis jetée : elle ne peut pas être reliée à toi. Si ton navigateur envoie le signal « Do Not Track », aucune mesure n'est faite.</p>
<h2>Ce qui reste sur ton appareil</h2>
<p>Le site utilise le stockage local de ton navigateur (et non des cookies) pour retenir ton coupon en cours, ton choix sur les publicités et la fermeture des bannières. Rien de cela n'est envoyé à nos serveurs.</p>
<h2>Publicité</h2>
<p>Le site affiche des publicités de réseaux tiers (notamment Adsterra et Monetag) et des encarts pour Afrolook. Ces réseaux peuvent déposer des cookies ou utiliser des identifiants pour choisir et mesurer les annonces. Pour les visiteurs de l'Union européenne et du Royaume-Uni, <b>aucune publicité tierce n'est chargée avant ton accord</b> ; tu peux changer d'avis à tout moment avec le bouton « Préférences publicitaires » en bas de page. Les politiques de ces réseaux s'appliquent à leurs traitements.</p>
<h2>Liens vers Afrolook</h2>
<p>Un clic sur un encart Afrolook ouvre la boutique d'applications (Google Play ou App Store) avec un paramètre qui indique l'emplacement du clic, sans donnée personnelle.</p>
<h2>Base légale et durée</h2>
<p>La mesure d'audience agrégée repose sur notre intérêt légitime à connaître la fréquentation du site. Les publicités personnalisées reposent sur ton consentement. Les compteurs agrégés, qui ne permettent d'identifier personne, sont conservés sans limite de durée.</p>
<h2>Hébergement</h2>
<p>Le site est hébergé par ${field(rc.site.hebergeur, 'hébergeur')}. Les données agrégées sont stockées dans la même infrastructure.</p>
<h2>Tes droits</h2>
<p>Tu disposes des droits d'accès, de rectification, d'effacement, d'opposition et de limitation prévus par le RGPD. Comme nous ne conservons aucune donnée qui te soit propre, il n'y a en général rien à effacer ; pour toute demande, écris à ${field(rc.site.email, 'adresse e-mail de contact')}. Tu peux aussi saisir l'autorité de protection des données de ton pays (en France, la CNIL).</p>`),
  }),

  conditions: (rc) => ({
    title: 'Conditions d\'utilisation · PronoFlash IA',
    description: 'Conditions d\'utilisation de PronoFlash IA : pronostics à titre d\'information, aucun gain garanti, 18+.',
    body: prose(`<h1>Conditions d'utilisation</h1>
<h2>Objet du site</h2>
<p>PronoFlash IA publie des pronostics sportifs à titre d'information et de divertissement. Ils ne constituent ni un conseil financier, ni une incitation à parier.</p>
<h2>Aucun gain garanti</h2>
<p>Un pronostic est une probabilité calculée. Il peut se révéler faux. L'éditeur ne garantit aucun résultat et ne peut être tenu responsable des pertes liées à l'usage des informations publiées. Ne joue que l'argent que tu peux te permettre de perdre.</p>
<h2>Réservé aux adultes</h2>
<p>Les contenus liés aux paris sont destinés aux personnes majeures (18 ans et plus, ou l'âge légal de ton pays). Les paris sportifs ne sont pas autorisés partout : il t'appartient de respecter la loi de ton pays.</p>
<h2>Propriété intellectuelle</h2>
<p>Les textes, analyses et le design du site sont protégés. Tu peux partager un lien ou un extrait court en citant la source. Les noms d'équipes et de championnats appartiennent à leurs propriétaires et ne sont utilisés qu'à titre d'information.</p>
<h2>Disponibilité</h2>
<p>Le site est fourni « en l'état ». Il peut être interrompu ou modifié sans préavis. Les données proviennent de sources externes et peuvent contenir des erreurs ou des retards.</p>
<h2>Loi applicable</h2>
<p>Ces conditions sont soumises au droit de ${field(rc.site.loi, 'pays dont le droit s\'applique')}. L'éditeur peut les mettre à jour ; la version en ligne fait foi.</p>`),
  }),

  cookies: (rc) => ({
    title: 'Cookies et stockage local · PronoFlash IA',
    description: 'Cookies et stockage local utilisés par PronoFlash IA et par les réseaux publicitaires, et comment les gérer.',
    body: prose(`<h1>Cookies et stockage local</h1>
<h2>Ce que le site dépose lui-même</h2>
<p><b>Aucun cookie.</b> Le site écrit seulement dans le stockage local de ton navigateur : <code>pf_coupon</code> (ton coupon en cours), <code>pf_consent</code> (ton choix sur les publicités) et l'état de fermeture des bannières. Ces données restent sur ton appareil.</p>
<h2>Ce que les publicités peuvent déposer</h2>
<p>Les réseaux publicitaires tiers (Adsterra, Monetag) peuvent déposer des cookies pour choisir, limiter la répétition et mesurer les annonces. Dans l'Union européenne et au Royaume-Uni, ces publicités ne se chargent qu'après ton accord.</p>
<h2>Gérer ton choix</h2>
<p>Utilise le bouton <b>Préférences publicitaires</b> en bas de chaque page pour accepter ou refuser. Tu peux aussi supprimer les cookies depuis les réglages de ton navigateur.</p>`),
  }),

  'mentions-legales': (rc) => ({
    title: 'Mentions légales · PronoFlash IA',
    description: 'Mentions légales de PronoFlash IA : éditeur, directeur de publication, hébergeur.',
    body: prose(`<h1>Mentions légales</h1>
<h2>Éditeur du site</h2>
<p>${field(rc.site.editeur, 'nom de l\'éditeur')}<br>Statut : ${field(rc.site.statutJuridique, 'statut juridique')}<br>Adresse : ${field(rc.site.adresse, 'adresse')}<br>E-mail : ${field(rc.site.email, 'adresse e-mail de contact')}</p>
<h2>Directeur de la publication</h2>
<p>${field(rc.site.editeur, 'nom du directeur de la publication')}</p>
<h2>Hébergement</h2>
<p>${field(rc.site.hebergeur, 'hébergeur')}</p>
<h2>Nom de domaine</h2>
<p>${esc(rc.site.domaine)}</p>`),
  }),

  'jeu-responsable': () => ({
    title: 'Jeu responsable · PronoFlash IA',
    description: 'Conseils de jeu responsable et liens d\'aide pour les personnes qui parient.',
    body: prose(`<h1>Jeu responsable</h1>
<p>Les pronostics de ce site sont des probabilités : même un pronostic à 80 % se trompe une fois sur cinq. Parier peut faire perdre de l'argent et, pour certaines personnes, créer une dépendance.</p>
<h2>Quelques règles simples</h2>
<ul><li>Réservé aux personnes majeures.</li><li>Ne parie que l'argent que tu peux te permettre de perdre, jamais celui du loyer, de la nourriture ou d'un emprunt.</li><li>Fixe-toi une limite avant de jouer et tiens-la.</li><li>Ne cherche jamais à te « refaire » après une perte.</li><li>Un coupon à plusieurs sélections gagne beaucoup plus rarement qu'un pari simple : c'est ce que montre le calcul de probabilité du site.</li><li>Fais des pauses. Si le jeu t'inquiète, parles-en.</li></ul>
<h2>Besoin d'aide ?</h2>
<ul><li>France : Joueurs Info Service, 09 74 75 13 13 (appel non surtaxé), <a href="https://www.joueurs-info-service.fr" rel="noopener nofollow" target="_blank">joueurs-info-service.fr</a>.</li><li>International : <a href="https://www.gamblersanonymous.org" rel="noopener nofollow" target="_blank">Gamblers Anonymous</a>.</li><li>Dans ton pays : rapproche-toi d'un professionnel de santé ou d'une association locale d'aide aux joueurs.</li></ul>
<p class="note" style="margin-top:14px">PronoFlash IA ne prend aucun pari et ne reçoit aucune commission des opérateurs de paris.</p>`),
  }),
};

/** Champ à compléter, version anglaise. */
const fieldEn = (v, label) => (v ? esc(v) : `<span class="todo">[${esc(label)} to be filled in from the admin]</span>`);

const PAGES_EN = {
  'a-propos': (rc) => ({
    title: 'About PronoFlash IA',
    description: 'Who runs PronoFlash IA and how predictions are made: a statistical model, an AI-written analysis, a public track record.',
    body: prose(`<h1>About PronoFlash IA</h1>
<p>PronoFlash IA is a free sports predictions website with no sign-up. It starts with football, with a special focus on African football, and will expand to other sports.</p>
<h2>Who runs the site?</h2>
<p>The site is published by ${fieldEn(rc.site.editeur, 'publisher name')}. It is funded by advertising and by promoting Afrolook, the publisher's social app. Predictions are never sold, and the site accepts no payment from bookmakers to influence a prediction.</p>
<h2>How are predictions made?</h2>
<ul><li><b>The model comes first.</b> For each match, a statistical model estimates each team's expected goals from its recent results, home and away, and the league averages. From these it derives the probability of every outcome: result, goals, handicap, half-time, corners, shots, cards.</li>
<li><b>The AI writes second.</b> An artificial intelligence receives the calculated figures and writes the analysis. It is not allowed to change or invent a figure: any analysis that strays from the figures provided is rejected automatically.</li>
<li><b>Results are public.</b> Every prediction is recorded before the match, then marked won or lost. The <a href="/en/track-record">track record</a> shows the real rate, losses included.</li></ul>
<h2>What the site does not do</h2>
<p>PronoFlash IA takes no bets, shows no odds, sells no tips and promises no winnings. A prediction is a probability, not a certainty. See <a href="/en/responsible-gambling">responsible gambling</a>.</p>
<h2>Data</h2>
<p>Fixtures, results and match statistics come from API-Football (api-sports.io). Team names are shown as text, with the logo supplied by the data provider (a generated crest otherwise). Club logos and names belong to their respective owners and are used for illustration only; no partnership or sponsorship is implied.</p>`),
  }),
  contact: (rc) => ({
    title: 'Contact · PronoFlash IA',
    description: 'Contact the PronoFlash IA team: question, error in a prediction, personal data request.',
    body: prose(`<h1>Contact</h1>
<p>For a question, to report an error in a prediction or to exercise your rights over your personal data, write to: <b>${fieldEn(rc.site.email, 'contact e-mail address')}</b>.</p>
<p>We do not answer requests for personal tips: the site publishes the same predictions for everyone, for free.</p>
<p>Publisher: ${fieldEn(rc.site.editeur, 'publisher name')}.</p>`),
  }),
  confidentialite: (rc) => ({
    title: 'Privacy policy · PronoFlash IA',
    description: 'Data collected by PronoFlash IA: cookie-free audience measurement, advertising, GDPR rights.',
    body: prose(`<h1>Privacy policy</h1>
<p>PronoFlash IA requires no sign-up and no account. This page explains what data flows when you visit the site.</p>
<h2>Cookie-free audience measurement</h2>
<p>We count visits with our own tool, without cookies and without storing any identifier on your device. Only <b>aggregated counters</b> are recorded: number of visits and page views, estimated country, device type (phone, computer), visit source (direct, search engine, social network), page viewed. Your IP address is never stored. To estimate unique visitors, a fingerprint hashed with a salt that changes every day is computed in memory and then discarded: it cannot be linked to you. If your browser sends the "Do Not Track" signal, nothing is measured.</p>
<h2>What stays on your device</h2>
<p>The site uses your browser's local storage (not cookies) to remember your current slip, your advertising choice and closed banners. None of this is sent to our servers.</p>
<h2>Advertising</h2>
<p>The site shows ads from third-party networks (including Adsterra and Monetag) and promotions for Afrolook. These networks may set cookies or use identifiers to choose and measure ads. For visitors in the European Union and the United Kingdom, <b>no third-party ad loads before you agree</b>; you can change your mind at any time with the "Ad preferences" button at the bottom of the page. These networks' own policies apply to their processing.</p>
<h2>Links to Afrolook</h2>
<p>Clicking an Afrolook promotion opens the app store (Google Play or App Store) with a parameter showing where the click came from, with no personal data.</p>
<h2>Legal basis and retention</h2>
<p>Aggregated audience measurement relies on our legitimate interest in knowing how the site is used. Personalised advertising relies on your consent. Aggregated counters, which identify no one, are kept indefinitely.</p>
<h2>Hosting</h2>
<p>The site is hosted by ${fieldEn(rc.site.hebergeur, 'hosting provider')}. Aggregated data is stored on the same infrastructure.</p>
<h2>Your rights</h2>
<p>You have the rights of access, rectification, erasure, objection and restriction provided by the GDPR. As we keep no data specific to you, there is usually nothing to erase; for any request, write to ${fieldEn(rc.site.email, 'contact e-mail address')}. You may also contact the data protection authority in your country.</p>`),
  }),
  conditions: (rc) => ({
    title: 'Terms of use · PronoFlash IA',
    description: 'PronoFlash IA terms of use: predictions for information only, no winnings guaranteed, 18+.',
    body: prose(`<h1>Terms of use</h1>
<h2>Purpose of the site</h2>
<p>PronoFlash IA publishes sports predictions for information and entertainment. They are neither financial advice nor an incentive to bet.</p>
<h2>No winnings guaranteed</h2>
<p>A prediction is a calculated probability and may turn out wrong. The publisher guarantees no result and cannot be held liable for losses arising from the use of the information published. Only stake money you can afford to lose.</p>
<h2>Adults only</h2>
<p>Betting-related content is intended for adults (18 or over, or the legal age in your country). Sports betting is not legal everywhere: it is up to you to comply with the law of your country.</p>
<h2>Intellectual property</h2>
<p>The site's texts, analyses and design are protected. You may share a link or a short extract citing the source. Team and competition names belong to their owners and are used for information only.</p>
<h2>Availability</h2>
<p>The site is provided "as is". It may be interrupted or changed without notice. Data comes from external sources and may contain errors or delays.</p>
<h2>Governing law</h2>
<p>These terms are governed by the law of ${fieldEn(rc.site.loi, 'governing country')}. The publisher may update them; the online version prevails.</p>`),
  }),
  cookies: () => ({
    title: 'Cookies and local storage · PronoFlash IA',
    description: 'Cookies and local storage used by PronoFlash IA and by ad networks, and how to manage them.',
    body: prose(`<h1>Cookies and local storage</h1>
<h2>What the site sets itself</h2>
<p><b>No cookies.</b> The site only writes to your browser's local storage: <code>pf_coupon</code> (your current slip), <code>pf_consent</code> (your advertising choice) and the closed state of banners. This data stays on your device.</p>
<h2>What ads may set</h2>
<p>Third-party ad networks (Adsterra, Monetag) may set cookies to choose ads, limit repetition and measure them. In the European Union and the United Kingdom, these ads only load after you agree.</p>
<h2>Managing your choice</h2>
<p>Use the <b>Ad preferences</b> button at the bottom of every page to accept or refuse. You can also delete cookies from your browser settings.</p>`),
  }),
  'mentions-legales': (rc) => ({
    title: 'Legal notice · PronoFlash IA',
    description: 'PronoFlash IA legal notice: publisher, publication director, hosting provider.',
    body: prose(`<h1>Legal notice</h1>
<h2>Publisher</h2>
<p>${fieldEn(rc.site.editeur, 'publisher name')}<br>Legal status: ${fieldEn(rc.site.statutJuridique, 'legal status')}<br>Address: ${fieldEn(rc.site.adresse, 'address')}<br>E-mail: ${fieldEn(rc.site.email, 'contact e-mail address')}</p>
<h2>Publication director</h2>
<p>${fieldEn(rc.site.editeur, 'publication director')}</p>
<h2>Hosting</h2>
<p>${fieldEn(rc.site.hebergeur, 'hosting provider')}</p>
<h2>Domain name</h2>
<p>${esc(rc.site.domaine)}</p>`),
  }),
  'jeu-responsable': () => ({
    title: 'Responsible gambling · PronoFlash IA',
    description: 'Responsible gambling advice and help links for people who bet.',
    body: prose(`<h1>Responsible gambling</h1>
<p>The predictions on this site are probabilities: even an 80% prediction is wrong one time in five. Betting can lose you money and, for some people, become an addiction.</p>
<h2>A few simple rules</h2>
<ul><li>Adults only.</li><li>Only stake money you can afford to lose, never rent, food or borrowed money.</li><li>Set a limit before you play and stick to it.</li><li>Never chase your losses.</li><li>A slip with several selections wins far less often than a single bet: that is what the site's probability calculation shows.</li><li>Take breaks. If gambling worries you, talk about it.</li></ul>
<h2>Need help?</h2>
<ul><li>United Kingdom: <a href="https://www.begambleaware.org" rel="noopener nofollow" target="_blank">BeGambleAware</a>.</li><li>France: Joueurs Info Service, 09 74 75 13 13, <a href="https://www.joueurs-info-service.fr" rel="noopener nofollow" target="_blank">joueurs-info-service.fr</a>.</li><li>International: <a href="https://www.gamblersanonymous.org" rel="noopener nofollow" target="_blank">Gamblers Anonymous</a>.</li><li>In your country: contact a health professional or a local support organisation for gamblers.</li></ul>
<p class="note" style="margin-top:14px">PronoFlash IA takes no bets and receives no commission from betting operators.</p>`),
  }),
};

/** Page légale dans la langue du contexte, avec son adresse et ses alternatives. */
function legalPage(rc, slug) {
  const fn = (rc.lang === 'en' ? PAGES_EN : PAGES)[slug];
  const p = fn(rc);
  return Object.assign(p, { path: rc.u('legal', slug), alternates: { fr: rc.pathIn('fr', 'legal', slug), en: rc.pathIn('en', 'legal', slug) } });
}

module.exports = { PAGES, PAGES_EN, legalPage, field };
