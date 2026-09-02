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
              'Dernière mise à jour : août 2026\nCes règles peuvent évoluer. Consulte cette page régulièrement.',
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
