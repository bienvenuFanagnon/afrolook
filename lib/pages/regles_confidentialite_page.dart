import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ReglesConfidentialitePage extends StatelessWidget {
  const ReglesConfidentialitePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        elevation: 0,
        title: Text(
          'Règles & Confidentialité',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _intro(colors),
          _section(
            colors,
            icon: Icons.visibility,
            title: 'Vues monétisées',
            items: [
              _rule('Vues des abonnés uniquement',
                  'Seules les vues provenant de tes abonnés comptent pour la monétisation. Une vue d\'un utilisateur non-abonné est enregistrée sur le post mais ne génère pas de revenu.'),
              _rule('Plus d\'abonnés = plus de revenus',
                  'Plus tu as d\'abonnés actifs, plus tes vues monétisées peuvent être élevées. Encourage tes spectateurs à s\'abonner pour augmenter tes gains.'),
              _rule('Vues propres exclues',
                  'Tes propres vues sur tes posts ne sont jamais comptabilisées, qu\'elles soient monétisées ou non.'),
              _rule('Types de posts éligibles',
                  'Seuls les posts de type "Post" standard sont éligibles aux vues monétisées. Les publicités, challenges et services sont exclus.'),
            ],
          ),
          _section(
            colors,
            icon: Icons.monetization_on_outlined,
            title: 'Rémunération des vues (RPM)',
            items: [
              _rule('Principe du RPM',
                  'Le RPM (Revenue Per Mille) est le montant que tu gagnes pour 1 000 vues. Ton RPM dépend de ton score créateur : plus ton score est élevé, plus ton palier est haut et plus ton RPM est grand.'),
              _rule('RPM maximum (modifiable à tout moment)',
                  'Le RPM maximum actuel est de 1 000 FCFA pour 1 000 vues. Ce montant est le plafond pour les créateurs Élite. Il peut être ajusté par Afrolook selon l\'économie de la plateforme. Ton RPM réel est toujours calculé à partir du taux en vigueur au moment de l\'encaissement.'),
              _rule('Paliers selon le score',
                  'Débutant (score < 10) → 200 FCFA RPM. Standard (10–24) → 400 FCFA RPM. Avancé (25–49) → 600 FCFA RPM. Expert (50–79) → 800 FCFA RPM. Élite (80+) → 1 000 FCFA RPM. Ton palier actuel est visible dans ta page de monétisation.'),
              _rule('Encaissement manuel',
                  'Tes gains s\'accumulent au fil du temps en fonction de tes vues et de ton palier. Tu choisis toi-même quand les encaisser depuis la page "Gains par vues". Un minimum d\'encaissement s\'applique.'),
              _rule('Augmente ton score pour gagner plus',
                  'Publie du contenu de qualité, régulièrement apprécié par ta communauté (likes, loves, commentaires). Plus tes posts génèrent d\'engagement, plus ton score créateur monte — et plus ton RPM augmente.'),
              _rule('Impact des signalements sur tes revenus',
                  'Si tes posts sont signalés ou jugés inappropriés, leur score chute. Ce déclin du score post entraîne une baisse du score créateur, ce qui peut faire descendre ton palier et donc ton RPM. Maintenir un contenu de qualité protège directement tes revenus.'),
            ],
          ),
          _section(
            colors,
            icon: Icons.chat_bubble_outline,
            title: 'Récompenses commentaires',
            items: [
              _rule('Classement hebdomadaire',
                  'Chaque semaine (lundi au dimanche), les meilleurs commentateurs sont classés et récompensés. Le classement est calculé chaque lundi matin.'),
              _rule('Poids des commentaires',
                  'Tous les commentaires n\'ont pas le même poids. Un commentaire court vaut moins qu\'un commentaire long et instructif. Plus votre commentaire est développé, pertinent et varié, plus il contribue fortement à votre score.'),
              _rule('Qualité avant quantité',
                  'Le système valorise la qualité du contenu : un commentaire détaillé sur un seul post peut valoir plus que dix commentaires minimalistes. Les commentaires trop courts ou répétitifs sont peu ou pas comptabilisés.'),
              _rule('Règles d\'éligibilité',
                  'Un commentaire doit contenir au minimum 10 caractères et au moins 2 mots pour être pris en compte. La répétition du même commentaire n\'est pas éligible.'),
              _rule('Anti-spam',
                  'Commenter plusieurs fois le même post ne rapporte rien de plus. Seul le premier commentaire éligible par post est pris en compte. Les comportements de spam entraînent une disqualification.'),
              _rule('Ancienneté du compte',
                  'Le compte doit avoir au moins 7 jours d\'ancienneté pour participer au classement.'),
              _rule('Récompenses en AfroCoins',
                  'Le top 5 hebdomadaire reçoit des AfroCoins automatiquement : 🥇 500 • 🥈 300 • 🥉 200 • 4e 100 • 5e 50. Les récompenses sont distribuées en fin de semaine.'),
            ],
          ),
          _section(
            colors,
            icon: Icons.star_outline,
            title: 'Niveaux d\'abonnement',
            items: [
              _rule('Gratuit',
                  'Accès aux fonctionnalités de base : feed, posts, canaux publics, groupes publics, commentaires. Publicités affichées dans l\'application.'),
              _rule('Premium',
                  'Toutes les fonctionnalités gratuites + suppression des publicités dans le feed, accès aux fonctionnalités exclusives premium, badge Premium visible sur le profil.'),
              _rule('Gold',
                  'Toutes les fonctionnalités Premium + avantages Gold exclusifs, badge Gold visible sur le profil, priorité dans les algorithmes de mise en avant.'),
              _rule('Changement de niveau',
                  'Le changement de niveau prend effet immédiatement après validation du paiement. Le niveau est lié au compte Afrolook et non à l\'appareil.'),
            ],
          ),
          _section(
            colors,
            icon: Icons.monetization_on_outlined,
            title: 'Monétisation',
            items: [
              _rule('Abonnement canal',
                  'Les propriétaires de canaux peuvent activer l\'abonnement payant. Les abonnés paient un montant mensuel défini par le propriétaire pour accéder au contenu exclusif du canal.'),
              _rule('Vente de contenu',
                  'Les créateurs peuvent mettre en vente des contenus numériques (vidéos, photos, documents). L\'acheteur obtient un accès permanent au contenu acheté.'),
              _rule('Live privé',
                  'Un live privé est accessible uniquement aux spectateurs qui ont payé le ticket d\'entrée défini par le créateur. Le montant est fixé avant le démarrage du live.'),
              _rule('Canal privé',
                  'Un canal privé est visible uniquement par ses membres. L\'accès peut être gratuit (sur invitation) ou payant (abonnement mensuel défini par le propriétaire).'),
              _rule('Groupe privé',
                  'Un groupe privé fonctionne comme un espace de discussion fermé. L\'accès peut être limité par invitation ou conditionné à un abonnement défini par l\'administrateur.'),
              _rule('Versement des gains',
                  'Les gains sont accumulés en AfroCoins dans ton espace de rémunération. La conversion en monnaie locale et le versement s\'effectuent selon les conditions en vigueur dans ton espace Rémunération.'),
            ],
          ),
          _section(
            colors,
            icon: Icons.repeat,
            title: 'Republication',
            items: [
              _rule('Comment ça fonctionne',
                  'La republication te permet de partager sur ton profil un post d\'un autre créateur que tu as apprécié. Le post apparaît sur ton profil avec le nom, l\'avatar et un lien vers le profil de l\'auteur original. Seul le créateur original reçoit les vues monétisées générées sur ce post.'),
              _rule('Une seule fois par post',
                  'Tu ne peux republier un même post qu\'une seule fois. Si tu as déjà republié un post, l\'option ne s\'affiche plus pour ce post.'),
              _rule('Ce qui ne peut pas être republié',
                  'Ton propre post ne peut pas être republié. Les publicités (posts sponsorisés) ne sont pas non plus republiables.'),
            ],
          ),
          _section(
            colors,
            icon: Icons.schedule_outlined,
            title: 'Inactivité créateur & canal',
            items: [
              _rule('Score et décroissance',
                  'Le score créateur et le score canal décroissent progressivement si aucune publication n\'est faite. Cette décroissance est lente mais constante : un créateur qui ne publie plus finira par sortir des sections de recommandation, quelle que soit sa popularité passée.'),
              _rule('Impact sur le RPM',
                  'Le RPM (revenu par vue) est directement lié au palier de score. Si l\'inactivité fait descendre ton score sous le seuil d\'un palier, ton RPM baisse en conséquence — par exemple, passer du palier Expert (800 FCFA) au palier Standard (400 FCFA). Les vues accumulées avant la baisse de palier restent calculées au tarif du moment où elles ont été générées.'),
              _rule('Reprendre de l\'activité',
                  'La reprise des publications remet le score en croissance. Il n\'y a pas de pénalité permanente liée à l\'inactivité — le score se reconstruit naturellement avec le nouvel engagement, et le palier de RPM remonte au fur et à mesure.'),
              _rule('Canaux abandonnés',
                  'Un canal avec zéro membre actif et aucune publication depuis plus de 6 mois peut être marqué comme inactif par l\'équipe Afrolook. Il reste accessible mais n\'est plus mis en avant sur la plateforme.'),
              _rule('Canaux sans membres',
                  'Les canaux sans aucun abonné n\'apparaissent pas dans les suggestions de découverte, même s\'ils ont publié du contenu récemment.'),
            ],
          ),
          _section(
            colors,
            icon: Icons.campaign_outlined,
            title: 'Publicité & Boosts',
            items: [
              _rule('Boost post',
                  'Tu peux booster un post pour le mettre en avant dans le feed des utilisateurs. Le post apparaît sous forme de bannière horizontale avec un badge "Sponsorisé".'),
              _rule('Boost entité',
                  'Les profils, canaux et groupes peuvent être boostés pour apparaître dans le feed sous forme de carte verticale avec un aperçu de l\'entité et un bouton d\'action.'),
              _rule('Validation requise',
                  'Tout boost doit être validé par l\'équipe Afrolook avant d\'être affiché. Un boost en attente de validation n\'est pas visible dans le feed.'),
              _rule('Ne plus voir les pubs',
                  'Les utilisateurs Premium et Gold peuvent désactiver l\'affichage des publicités dans leur feed.'),
            ],
          ),
          _section(
            colors,
            icon: Icons.trending_up_rounded,
            title: 'Système de score & Recommandations',
            items: [
              _rule('Score du post',
                  'Chaque publication reçoit un score calculé automatiquement et régulièrement. Ce score prend en compte les réactions de ta communauté (likes, loves, commentaires) et l\'ancienneté du post. Plus un post est récent et apprécié, plus son score est élevé.'),
              _rule('Décroissance dans le temps',
                  'Les anciens posts perdent progressivement du score, même si leur engagement reste constant. Cela garantit qu\'un contenu frais et de qualité est régulièrement mis en avant, plutôt que de favoriser toujours les mêmes publications.'),
              _rule('Score créateur',
                  'Chaque créateur dispose d\'un score qui reflète la qualité et la régularité de son contenu. Ce score est calculé à partir des performances de ses publications récentes. Il est visible sur son profil.'),
              _rule('Score canal',
                  'Les canaux disposent également d\'un score reflétant leur vitalité et la qualité du contenu publié. Visible dans les détails du canal.'),
              _rule('Impact sur les recommandations',
                  'Les créateurs et canaux ayant les meilleurs scores apparaissent en priorité dans les sections de découverte du feed. Un bon score augmente ta visibilité sur toute la plateforme.'),
              _rule('Impact du signalement',
                  'Signaler un post a un impact négatif sur son score. Si plusieurs utilisateurs signalent le même post, il est progressivement retiré des recommandations. Un post modéré par l\'équipe Afrolook voit son score fortement réduit. Maintenir un contenu de qualité est la meilleure façon de protéger ton score.'),
              _rule('Découverte froide (nouveau créateur)',
                  'Les nouveaux créateurs bénéficient d\'un bonus temporaire pour être mis en avant dans la découverte, même sans historique d\'engagement. Cela leur donne une chance d\'être vus dès leurs premières publications.'),
              _rule('Canaux dans la recherche',
                  'Seuls les canaux ayant au moins un membre sont suggérés dans la page de recherche. Un canal sans abonné n\'apparaît pas dans les suggestions Top, même s\'il est actif en contenu.'),
              _rule('Transparence',
                  'Le score de tes posts, de ton profil créateur et de tes canaux est visible par tous. Il n\'est pas possible de l\'acheter ou de le manipuler artificiellement — tout comportement frauduleux entraîne une suspension.'),
            ],
          ),
          _section(
            colors,
            icon: Icons.gavel,
            title: 'Règles d\'utilisation',
            items: [
              _rule('Contenu autorisé',
                  'Tu peux publier du contenu personnel, artistique, informatif et divertissant dans le respect des présentes règles. Tout contenu doit être légal dans ton pays de résidence.'),
              _rule('Contenu interdit',
                  'Sont strictement interdits : la nudité explicite, la violence graphique, le discours haineux (racisme, sexisme, homophobie), le harcèlement, les menaces, la promotion de la drogue, les armes illégales, la propagande terroriste et tout contenu pédopornographique.'),
              _rule('Contenu trompeur',
                  'Il est interdit de diffuser des informations délibérément fausses (fake news), d\'usurper l\'identité d\'une autre personne ou d\'une marque, ou de manipuler des médias de manière trompeuse.'),
              _rule('Spam & manipulation',
                  'Tout comportement visant à gonfler artificiellement les statistiques (vues, abonnés, likes) par des moyens automatisés ou des échanges coordonnés est interdit et entraîne la suspension du compte.'),
              _rule('Respect des utilisateurs',
                  'Le harcèlement, la cyberintimidation, les insultes répétées et les comportements hostiles envers d\'autres utilisateurs sont prohibés. Utilise la fonction de signalement pour alerter l\'équipe.'),
            ],
          ),
          _section(
            colors,
            icon: Icons.copyright_outlined,
            title: 'Droits d\'auteur & Propriété intellectuelle',
            items: [
              _rule('Tes propres créations',
                  'Tu conserves tous tes droits sur le contenu que tu publies. En publiant sur Afrolook, tu accordes à la plateforme une licence non exclusive d\'affichage et de distribution dans l\'application.'),
              _rule('Contenu tiers',
                  'Ne publie pas de musique, vidéos, images ou textes protégés par le droit d\'auteur sans autorisation explicite du détenteur des droits. Les contenus en infraction seront supprimés.'),
              _rule('Signalement de violation',
                  'Si tu constatez qu\'un contenu viole tes droits d\'auteur, tu peux le signaler via le bouton de signalement ou en contactant contact@afrolookmedia.com avec les justificatifs nécessaires.'),
              _rule('Licence du contenu',
                  'Afrolook se réserve le droit d\'utiliser ton contenu à des fins de promotion de la plateforme (ex: mise en avant sur les réseaux sociaux officiels) avec mention de l\'auteur. Tu peux t\'y opposer en contactant le support.'),
            ],
          ),
          _section(
            colors,
            icon: Icons.security,
            title: 'Sécurité du compte',
            items: [
              _rule('Responsabilité du compte',
                  'Tu es entièrement responsable de l\'activité sur ton compte. Ne partage jamais ton mot de passe. Afrolook ne te demandera jamais ton mot de passe par message.'),
              _rule('Authentification',
                  'Nous recommandons d\'activer la vérification en deux étapes pour protéger ton compte. En cas de connexion suspecte, change immédiatement ton mot de passe.'),
              _rule('Compte compromis',
                  'Si tu penses que ton compte a été piraté, contacte immédiatement le support à contact@afrolookmedia.com. Afrolook peut temporairement restreindre l\'accès à un compte compromis pour le protéger.'),
              _rule('Un compte par personne',
                  'Chaque utilisateur ne peut posséder qu\'un seul compte actif. Les comptes multiples créés pour contourner une suspension seront définitivement bannis.'),
            ],
          ),
          _section(
            colors,
            icon: Icons.report_problem_outlined,
            title: 'Sanctions & Modération',
            items: [
              _rule('Avertissement',
                  'Un premier manquement mineur aux règles peut faire l\'objet d\'un avertissement. Le contenu en infraction est supprimé et l\'utilisateur est informé de la violation.'),
              _rule('Suspension temporaire',
                  'Les violations répétées ou plus graves entraînent une suspension temporaire du compte (1 à 30 jours). Durant cette période, l\'utilisateur ne peut pas accéder à l\'application.'),
              _rule('Suspension définitive',
                  'Les violations graves (contenu pédopornographique, terrorisme, harcèlement grave, fraude avérée) entraînent une suspension permanente et irréversible du compte.'),
              _rule('Appel & recours',
                  'Si tu penses que la sanction est injustifiée, tu peux contester la décision en écrivant à contact@afrolookmedia.com dans les 14 jours suivant la sanction. L\'équipe de modération examinera ton cas.'),
              _rule('Contenu signalé',
                  'Tout utilisateur peut signaler un contenu ou un compte. Les signalements sont examinés par l\'équipe de modération. Les signalements abusifs répétés peuvent eux-mêmes faire l\'objet de sanctions.'),
            ],
          ),
          _section(
            colors,
            icon: Icons.lock_outline,
            title: 'Confidentialité & Données',
            items: [
              _rule('Données collectées',
                  'Afrolook collecte les données nécessaires au fonctionnement de l\'application : profil, publications, interactions, transactions. Aucune donnée n\'est vendue à des tiers.'),
              _rule('Utilisation des données',
                  'Tes données sont utilisées pour personnaliser ton expérience, calculer tes récompenses, et assurer la sécurité de la plateforme.'),
              _rule('Suppression du compte',
                  'Tu peux demander la suppression de ton compte et de tes données depuis les paramètres du profil. La suppression est définitive et irréversible.'),
              _rule('Sécurité des paiements',
                  'Toutes les transactions financières sont traitées de manière sécurisée. Afrolook ne stocke jamais tes informations bancaires ou de carte sur ses serveurs.'),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Dernière mise à jour : septembre 2026\nCes règles peuvent évoluer. Consulte cette page régulièrement.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 11,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _intro(AppColors colors) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: colors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Cette page regroupe toutes les règles de fonctionnement d\'Afrolook : conditions d\'utilisation, modération, droits, monétisation, récompenses, abonnements et confidentialité. En utilisant Afrolook tu acceptes ces règles.',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    AppColors colors, {
    required IconData icon,
    required String title,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 10),
          child: Row(
            children: [
              Icon(icon, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        ...items,
        const Divider(height: 28),
      ],
    );
  }

  Widget _rule(String titre, String description) {
    return Builder(
      builder: (context) {
        final colors = AppColors.of(context);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 5, right: 8),
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      titre,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 13),
                child: Text(
                  description,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12.5,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
