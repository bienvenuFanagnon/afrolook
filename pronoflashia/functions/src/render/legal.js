'use strict';
// Pages obligatoires pour les réseaux publicitaires et le RGPD. Les champs à remplir par l'éditeur viennent de config/site.
// À faire relire par un juriste avant la mise en ligne.

const { esc } = require('../util/format');
const C = require('./components');

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
<p>PronoFlash IA ne prend aucun pari, n'affiche aucune cote de bookmaker, ne vend aucun pronostic et <b>ne promet aucun gain</b>. Un pronostic est une probabilité, pas une certitude : le football garde une part d'imprévu que personne ne sait prévoir, et nos propres tests le confirment. Voir la page <a href="/jeu-responsable">jeu responsable</a>.</p>
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
<h2>Publicité et partenariats</h2>
<p>Vous êtes une marque, une entreprise, un commerçant, un créateur ou un particulier et vous voulez faire connaître votre produit ? Consultez la page <a href="${rc.u('legal', 'annoncer')}">Annoncer sur PronoFlash IA</a>, puis écrivez-nous ici.</p>
${C.contactBox(rc)}
<p>Éditeur : ${field(rc.site.editeur, 'nom de l\'éditeur')}.</p>`),
  }),

  annoncer: (rc) => ({
    title: 'Annoncer sur PronoFlash IA : votre marque devant les fans de football',
    description: "Marques, entreprises, commerçants, créateurs : faites connaître votre produit sur PronoFlash IA, site gratuit de pronostics football. Espaces publicitaires, partenariats et contenus sponsorisés.",
    body: prose(`<h1>Annoncer sur PronoFlash IA</h1>
<p>Vous êtes une <b>marque</b>, une <b>entreprise</b>, un <b>commerçant</b>, un <b>créateur</b> ou un <b>particulier</b> et vous voulez faire connaître un produit, un service ou une application ? PronoFlash IA met des espaces publicitaires à votre disposition, directement, sans intermédiaire.</p>
<h2>Qui nous lit</h2>
<p>PronoFlash IA est un site gratuit de pronostics de football, avec une place particulière pour le football africain. Nos visiteurs viennent chercher les pronostics du jour, des coupons, le bilan de l'IA et les actualités du football. Demandez-nous les chiffres de fréquentation du moment : nous vous les communiquons tels qu'ils sont, sans les arrondir en notre faveur.</p>
<h2>Ce que nous proposons</h2>
<ul>
<li><b>Encart sponsor près du coupon du jour</b> : « offert par votre marque », avec votre logo, une phrase et un lien.</li>
<li><b>Bannières</b> dans les pages les plus vues : accueil, matchs, coupon, bilan, actualités.</li>
<li><b>Actualité ou article sponsorisé</b>, toujours clairement étiqueté « Sponsorisé ».</li>
<li><b>Mention dans nos notifications</b> (sur demande, en nombre limité pour ne pas lasser nos visiteurs).</li>
<li><b>Rapport de résultats</b> : le nombre d'affichages et de clics de votre encart, jour par jour, remis sur demande.</li>
<li><b>Partenariat dans la durée</b> : plusieurs emplacements, sur plusieurs semaines.</li>
</ul>
<p>Les tarifs dépendent de l'emplacement et de la durée : écrivez-nous et nous vous répondons avec une proposition.</p>
<h2>Nos règles</h2>
<ul>
<li>Toute publicité est identifiable comme telle (« Sponsorisé »).</li>
<li>Nous refusons les jeux d'argent, paris et casinos (le site est réservé aux plus de 18 ans et ne fait la promotion d'aucun pari), les contenus pour adultes, les produits illégaux ou dangereux, les arnaques, les promesses de gains faciles et toute publicité qui cible des mineurs.</li>
<li>Nos pronostics ne sont jamais influencés par un annonceur : ils sont calculés de la même façon pour tous et leur bilan est public.</li>
<li>Nous nous réservons le droit de refuser ou de retirer une publicité.</li>
</ul>
<h2>Comment faire</h2>
<p>Écrivez-nous avec : le nom de votre marque ou entreprise, le produit à présenter, les pays visés, la durée souhaitée, un budget approximatif et un lien ou un visuel.</p>
${C.contactBox(rc)}`),
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
<h2>Historique des notifications</h2>
<p>Pour afficher la page « Mes notifications », nous gardons pendant 30 jours (50 notifications au plus) les notifications envoyées à ton adresse d'envoi anonyme, et savoir si tu les as ouvertes. Cette liste n'est liée à aucun nom ni compte : elle disparaît si tu désactives les notifications ou après 30 jours.</p>
<h2>Inscription par e-mail (facultative)</h2>
<p>Si tu laisses ton adresse e-mail pour recevoir nos coupons et actus, nous enregistrons cette adresse, ta langue, la date et la page de ton inscription ainsi que le texte que tu as accepté (preuve de ton consentement). Nous ne la vendons ni ne la cédons à personne et nous l'utilisons seulement pour t'envoyer les e-mails de PronoFlash IA. Un message de confirmation te sera d'abord envoyé ; chaque e-mail contiendra un lien de désinscription, et tu peux aussi demander la suppression de ton adresse en écrivant à l'adresse de contact. Base légale : ton consentement ; conservation : jusqu'à ta désinscription.</p>
<h2>Liens vers des sites d'actualité</h2>
<p>Le site affiche des titres d'actualité avec un lien vers le site d'origine ; les miniatures sont chargées depuis ces sites. En cliquant, tu quittes PronoFlash IA et tu dépends de la politique de confidentialité du site visité.</p>
<h2>Publicité</h2>
<p>Le site affiche uniquement des annonces d'<b>Afrolook Ads</b>, la régie publicitaire d'Afrolook : aucun réseau publicitaire tiers n'est chargé. Afrolook Ads n'utilise aucun cookie, ne suit pas les visiteurs d'un site à l'autre et ne fait aucun ciblage comportemental. Un identifiant propre au site, stocké dans ton navigateur, sert seulement à limiter la répétition d'une annonce et à compter les affichages ; le réglage « Ne pas suivre » de ton navigateur est respecté.</p>
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
<p>Les annonces sont celles d'Afrolook Ads, sans cookie publicitaire : un identifiant propre au site, stocké dans ton navigateur, sert à limiter la répétition et à compter les affichages.</p>
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
<p>PronoFlash IA takes no bets, shows no bookmaker odds, sells no tips and <b>promises no winnings</b>. A prediction is a probability, not a certainty: football keeps an element of the unexpected that nobody can predict, and our own tests confirm it. See <a href="/en/responsible-gambling">responsible gambling</a>.</p>
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
<h2>Advertising and partnerships</h2>
<p>Are you a brand, a company, a shop owner, a creator or an individual who wants to promote a product? Read the <a href="${rc.u('legal', 'annoncer')}">Advertise on PronoFlash IA</a> page, then write to us here.</p>
${C.contactBox(rc)}
<p>Publisher: ${fieldEn(rc.site.editeur, 'publisher name')}.</p>`),
  }),
  annoncer: (rc) => ({
    title: 'Advertise on PronoFlash IA: your brand in front of football fans',
    description: 'Brands, companies, shop owners, creators: promote your product on PronoFlash IA, a free football predictions site. Ad space, partnerships and sponsored content.',
    body: prose(`<h1>Advertise on PronoFlash IA</h1>
<p>Are you a <b>brand</b>, a <b>company</b>, a <b>shop owner</b>, a <b>creator</b> or an <b>individual</b> who wants to promote a product, a service or an app? PronoFlash IA offers advertising space directly, with no middleman.</p>
<h2>Who reads us</h2>
<p>PronoFlash IA is a free football predictions site with a special focus on African football. Our visitors come for the predictions of the day, slips, the AI's public track record and football news. Ask us for the current traffic figures: we give them to you as they are, never rounded in our favour.</p>
<h2>What we offer</h2>
<ul>
<li><b>Sponsor box next to the slip of the day</b>: “brought to you by your brand”, with your logo, a sentence and a link.</li>
<li><b>Banners</b> on the most visited pages: home, matches, slips, track record, news.</li>
<li><b>Sponsored news or article</b>, always clearly labelled “Sponsored”.</li>
<li><b>A mention in our notifications</b> (on request, in limited numbers so as not to tire our visitors).</li>
<li><b>Results report</b>: the number of displays and clicks of your box, day by day, provided on request.</li>
<li><b>Long-term partnership</b>: several placements over several weeks.</li>
</ul>
<p>Prices depend on the placement and the duration: write to us and we will answer with a proposal.</p>
<h2>Our rules</h2>
<ul>
<li>Every ad is identifiable as such (“Sponsored”).</li>
<li>We refuse gambling, betting and casinos (the site is 18+ and promotes no betting), adult content, illegal or dangerous products, scams, promises of easy winnings and any ad that targets minors.</li>
<li>Our predictions are never influenced by an advertiser: they are calculated the same way for everyone and their track record is public.</li>
<li>We reserve the right to refuse or remove an ad.</li>
</ul>
<h2>How to proceed</h2>
<p>Write to us with: your brand or company name, the product to present, the countries you target, the duration you want, an approximate budget and a link or a visual.</p>
${C.contactBox(rc)}`),
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
<h2>Notification history</h2>
<p>To show the “My notifications” page, we keep for 30 days (50 notifications at most) the notifications sent to your anonymous delivery address, and whether you opened them. This list is linked to no name and no account: it disappears when you turn notifications off or after 30 days.</p>
<h2>E-mail sign-up (optional)</h2>
<p>If you leave your e-mail address to receive our slips and news, we record that address, your language, the date and page of your sign-up and the text you accepted (proof of your consent). We never sell or share it and use it only to send you PronoFlash IA e-mails. A confirmation message will be sent first; every e-mail will contain an unsubscribe link, and you can also ask for your address to be deleted by writing to the contact address. Legal basis: your consent; retention: until you unsubscribe.</p>
<h2>Links to news sites</h2>
<p>The site shows news headlines with a link to the original site; thumbnails are loaded from those sites. By clicking, you leave PronoFlash IA and are subject to the privacy policy of the site you visit.</p>
<h2>Advertising</h2>
<p>The site only shows ads from <b>Afrolook Ads</b>, Afrolook's ad network: no third-party ad network is loaded. Afrolook Ads sets no cookies, does not track visitors from one site to another and does no behavioural targeting. An identifier specific to this site, stored in your browser, is only used to limit how often an ad repeats and to count impressions; your browser's "Do Not Track" setting is respected.</p>
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
<p>Ads come from Afrolook Ads and use no advertising cookie: an identifier specific to this site, stored in your browser, limits repetition and counts impressions.</p>
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
