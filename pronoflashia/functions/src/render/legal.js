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
    description: "PronoFlash IA : une IA d'analyse construite par nos soins, qui apprend de chaque équipe, suit l'actualité et corrige ses erreurs grâce à un bilan public. Gratuit, sans inscription.",
    body: prose(`<h1>À propos de PronoFlash IA</h1>
<p>PronoFlash IA est un site <b>gratuit</b> de pronostics sportifs, <b>sans inscription</b>. Il commence par le football, avec une place particulière pour le football africain, et s'ouvrira à d'autres sports.</p>
<h2>Notre propre outil d'analyse</h2>
<p>Nous développons notre propre moteur d'analyse. Il ne se contente pas de recopier des statistiques : il <b>apprend de chaque équipe</b>, <b>suit l'actualité</b> et <b>corrige ses calculs d'après ses propres résultats</b>. Voici, concrètement, ce qu'il fait.</p>
<ul><li><b>Il apprend de chaque équipe.</b> Pour chaque club, l'IA tient une note d'attaque et une note de défense, recalculées chaque jour sur tous les matchs connus (saison précédente comprise). Les matchs récents comptent davantage et le niveau des adversaires affrontés est pris en compte. L'évolution de chaque équipe sur 60 jours est visible dans l'analyse complète d'un match.</li>
<li><b>Il suit l'actualité.</b> Toutes les 2 heures, l'IA lit les titres de la presse sportive et repère les blessures, suspensions, retours de joueurs et changements d'entraîneur. Ces informations sont affichées sur la fiche du match avec leur source. Pour l'instant elles informent : aucune probabilité n'est modifiée à cause d'elles, car nous mesurons d'abord leur effet réel.</li>
<li><b>Il apprend de ses erreurs.</b> Chaque pronostic est enregistré avant le match puis marqué réussi ou raté. Quand ses probabilités se révèlent trop optimistes ou trop prudentes sur un type de pari, elles sont corrigées automatiquement, et l'IA tient compte de ce bilan dans ses analyses.</li>
<li><b>Il est testé avant d'être utilisé.</b> Chaque amélioration est jugée sur des matchs passés, sans jamais utiliser le futur. Notre moteur de notes d'équipes explique mieux les buts que notre ancien calcul sur plus de 1 500 matchs réels de cinq grands championnats ; s'il se révélait moins bon sur un championnat, l'ancien calcul serait rétabli automatiquement.</li>
<li><b>Il propose des coupons.</b> Chaque jour, trois coupons (2, 3 et 5 sélections) sont enregistrés avant les matchs, jamais modifiés, puis réglés : les gagnants comme les perdants sont publiés sur la page <a href="/bilan">Bilan</a>. Tu peux aussi composer ton propre coupon et voir la vraie probabilité que tout passe.</li>
<li><b>Il dit quand il est moins sûr.</b> Un pronostic fondé sur peu de matchs porte la mention « Données limitées » et n'entre pas dans les coupons proposés.</li></ul>
<h2>Des résultats publics, bons ou mauvais</h2>
<p>Nous publions tout, réussites <i>et</i> échecs, sur la page <a href="/bilan">Bilan</a> : taux de réussite, résultats par championnat et par type de pari, historique complet des coupons. C'est ce bilan qui fait progresser l'IA, et c'est à lui, pas à des promesses, que tu peux juger notre travail.</p>
<h2>Ce que le site ne fait pas</h2>
<p>PronoFlash IA ne prend aucun pari, n'affiche aucune cote, ne vend aucun pronostic et <b>ne promet aucun gain</b>. Un pronostic est une probabilité, pas une certitude : le football garde une part d'imprévu que personne ne sait prévoir, et nos propres tests le confirment. Voir la page <a href="/jeu-responsable">jeu responsable</a>.</p>
<h2>Qui édite le site ? Comment est-il financé ?</h2>
<p>Le site est édité par ${field(rc.site.editeur, 'nom de l\'éditeur')}. <b>Tout est gratuit</b> : les publicités et la promotion d'Afrolook, l'application sociale du même éditeur, servent à couvrir les frais des serveurs et du développement. Les pronostics ne sont jamais vendus et le site n'accepte aucune rémunération de la part des bookmakers pour orienter un pronostic.</p>
<h2>Données</h2>
<p>Les calendriers et résultats proviennent de fournisseurs de données sportives (football-data.org, API-Football selon les championnats). Les actualités viennent de flux publics de sites de presse sportive : seuls le titre, un court extrait (une ou deux phrases), le nom du site et le lien vers l'article sont repris, avec renvoi vers l'article complet chez la source. Les noms des équipes sont affichés en texte, avec leur logo fourni par le fournisseur de données (à défaut, un écusson généré). Les logos et noms des clubs appartiennent à leurs propriétaires respectifs et ne sont utilisés qu'à titre d'illustration ; aucun partenariat ni parrainage n'est suggéré.</p>`),
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
<p>Le site utilise le stockage local de ton navigateur (et non des cookies) pour retenir ton coupon en cours, ton choix sur les publicités, tes équipes suivies et la fermeture des bannières. Rien de cela n'est envoyé à nos serveurs, sauf si tu actives les notifications (voir ci-dessous).</p>
<h2>Notifications (facultatives)</h2>
<p>Si tu actives les notifications (cloche en haut de page), ton navigateur nous transmet une <b>adresse d'envoi anonyme</b> (fournie par Google, Apple ou Mozilla selon ton navigateur), les équipes que tu choisis de suivre et ta langue. Nous n'y associons ni nom, ni adresse e-mail, ni numéro de téléphone. Elle sert uniquement à t'envoyer les coupons du jour (jusqu'à trois par jour) et les alertes avant les matchs de tes équipes (deux par jour au plus). Tu peux tout couper en un clic avec la cloche, ou dans les réglages de ton navigateur ; l'adresse est alors supprimée de nos serveurs. Base légale : ton consentement.</p>
<h2>Liens vers des sites d'actualité</h2>
<p>Le site affiche des titres d'actualité avec un lien vers le site d'origine ; les miniatures sont chargées depuis ces sites. En cliquant, tu quittes PronoFlash IA et tu dépends de la politique de confidentialité du site visité.</p>
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
    description: 'PronoFlash IA: an analysis AI we build ourselves, which learns from every team, follows the news and corrects its mistakes thanks to a public track record. Free, no sign-up.',
    body: prose(`<h1>About PronoFlash IA</h1>
<p>PronoFlash IA is a <b>free</b> sports predictions website with <b>no sign-up</b>. It starts with football, with a special focus on African football, and will expand to other sports.</p>
<h2>Our own analysis tool</h2>
<p>We are building our own analysis engine. It does not simply copy statistics: it <b>learns from every team</b>, <b>follows the news</b> and <b>corrects its calculations from its own results</b>. Here is what it does, concretely.</p>
<ul><li><b>It learns from every team.</b> For each club, the AI keeps an attack rating and a defence rating, recomputed every day on every known match (previous season included). Recent matches count more and the strength of the opponents faced is taken into account. Each team's 60-day trend is shown in a match's full analysis.</li>
<li><b>It follows the news.</b> Every 2 hours, the AI reads sports press headlines and spots injuries, suspensions, returning players and coaching changes. This information is shown on the match page with its source. For now it informs: no probability is changed because of it, as we first measure its real effect.</li>
<li><b>It learns from its mistakes.</b> Every prediction is recorded before the match, then marked won or lost. When its probabilities prove too optimistic or too cautious for a type of bet, they are corrected automatically, and the AI takes this track record into account in its analyses.</li>
<li><b>It is tested before being used.</b> Every improvement is judged on past matches, never using the future. Our team-rating engine explains goals better than our previous calculation on more than 1,500 real matches from five top leagues; if it turned out worse in a league, the previous calculation would be restored automatically.</li>
<li><b>It builds slips.</b> Every day, three slips (2, 3 and 5 selections) are recorded before the matches, never changed, then settled: winners and losers are both published on the <a href="/en/track-record">Track record</a> page. You can also build your own slip and see the real probability that everything wins.</li>
<li><b>It says when it is less sure.</b> A prediction based on few matches carries a "Limited data" label and is not used in the suggested slips.</li></ul>
<h2>Public results, good or bad</h2>
<p>We publish everything, successes <i>and</i> failures, on the <a href="/en/track-record">Track record</a> page: success rate, results by league and by type of bet, the full history of slips. This track record is what makes the AI improve, and it, not promises, is how you can judge our work.</p>
<h2>What the site does not do</h2>
<p>PronoFlash IA takes no bets, shows no odds, sells no tips and <b>promises no winnings</b>. A prediction is a probability, not a certainty: football keeps an element of the unexpected that nobody can predict, and our own tests confirm it. See <a href="/en/responsible-gambling">responsible gambling</a>.</p>
<h2>Who runs the site? How is it funded?</h2>
<p>The site is published by ${fieldEn(rc.site.editeur, 'publisher name')}. <b>Everything is free</b>: advertising and the promotion of Afrolook, the publisher's social app, cover the cost of servers and development. Predictions are never sold, and the site accepts no payment from bookmakers to influence a prediction.</p>
<h2>Data</h2>
<p>Fixtures and results come from sports data providers (football-data.org, API-Football depending on the league). News comes from public feeds of sports press sites: only the headline, a short excerpt (one or two sentences), the site name and the link to the article are reused, with a link to the full article at the source. Team names are shown as text, with the logo supplied by the data provider (a generated crest otherwise). Club logos and names belong to their respective owners and are used for illustration only; no partnership or sponsorship is implied.</p>`),
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
<p>The site uses your browser's local storage (not cookies) to remember your current slip, your advertising choice, the teams you follow and the banners you closed. None of this is sent to our servers, unless you turn on notifications (see below).</p>
<h2>Notifications (optional)</h2>
<p>If you turn on notifications (bell at the top of the page), your browser sends us an <b>anonymous delivery address</b> (provided by Google, Apple or Mozilla depending on your browser), the teams you choose to follow and your language. We link no name, e-mail address or phone number to it. It is used only to send you the slips of the day (up to three a day) and alerts before your teams' matches (two a day at most). You can turn everything off in one click with the bell, or in your browser settings; the address is then deleted from our servers. Legal basis: your consent.</p>
<h2>Links to news sites</h2>
<p>The site shows news headlines with a link to the original site; thumbnails are loaded from those sites. By clicking, you leave PronoFlash IA and are subject to the privacy policy of the site you visit.</p>
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
