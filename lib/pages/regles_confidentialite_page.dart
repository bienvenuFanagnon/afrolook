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
                  'Chaque semaine (lundi au dimanche), les meilleurs commentateurs de la plateforme sont classés selon leur activité.'),
              _rule('Critères de classement',
                  'Le classement est basé sur le nombre de commentaires uniques laissés sur des posts de type "Post". Les commentaires sur ses propres posts ne sont pas comptabilisés.'),
              _rule('Récompenses en AfroCoins',
                  'Les créateurs du top classement hebdomadaire reçoivent des AfroCoins. Les récompenses sont distribuées automatiquement en fin de semaine.'),
              _rule('Bonne foi requise',
                  'Les commentaires doivent être authentiques. Les comportements de spam ou de contournement des règles entraînent une disqualification.'),
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
              'Cette page regroupe toutes les règles de fonctionnement d\'Afrolook : monétisation, récompenses, abonnements et confidentialité. Elle est mise à jour au fur et à mesure des évolutions de la plateforme.',
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
