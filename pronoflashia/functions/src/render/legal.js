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
<p>Les calendriers, résultats et statistiques de matchs proviennent d'API-Football (api-sports.io). Les noms des équipes sont affichés en texte ; les écussons sont générés et ne reproduisent aucun logo officiel.</p>`),
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

module.exports = { PAGES, field };
