import 'package:flutter/material.dart';

import '../../layout/centered_content.dart';
import '../../theme/app_colors.dart';

/// Aide-mémoire de l'administrateur : que vérifier pour repérer la fraude sur les tâches (Tapjoy, ayeT) avant d'approuver ou de refuser.
/// Réservé à l'administration (texte en français uniquement). Voir docs/OFFERWALL_TACHES.md §12 et §19.
class OfferwallFraudGuidePage extends StatelessWidget {
  const OfferwallFraudGuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    Widget section(IconData icon, String title, Color color, List<String> lines) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15))),
            ]),
            const SizedBox(height: 8),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('•  ', style: TextStyle(color: color, fontWeight: FontWeight.w900)),
                  Expanded(child: Text(l, style: TextStyle(color: c.textPrimary, fontSize: 13, height: 1.4))),
                ]),
              ),
          ]),
        );

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(backgroundColor: c.surface, foregroundColor: c.textPrimary, title: const Text('Fraude sur les tâches : aide-mémoire')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          CenteredContent(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                'À relire avant d\'approuver ou de refuser une tâche « en revue » (page Tâches et offres > onglet de revue).',
                style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              section(Icons.looks_one_rounded, '1. Lire la raison de la mise en revue', c.primary, const [
                '« plafond dépassé » : l\'utilisateur a dépassé 2 000 pièces par jour ou 10 000 par semaine. Pas forcément de la fraude : vérifier son profil.',
                '« écart entre pièces et paiement » : les pièces envoyées par le partenaire ne correspondent pas au paiement en dollars annoncé. Cas le plus suspect : refuser au moindre doute.',
              ]),
              section(Icons.looks_two_rounded, '2. Ouvrir le profil (« Voir l\'utilisateur »)', c.primary, const [
                'Ancienneté du compte (moins de 7 jours avec plus de 500 pièces = alerte) et e-mail vérifié.',
                'Rafale : 10 tâches ou plus en 24 h.',
                'Le même montant répété 5 fois ou plus (signe d\'un script).',
                '2 tâches déjà mises en revue ou plus, ou plusieurs montants refusés.',
                'Plafond du jour presque atteint en permanence.',
                'Historique : tâches validées, en attente, refusées, annulées par le partenaire.',
              ]),
              section(Icons.looks_3_rounded, '3. Vérifier chez le partenaire', c.primary, const [
                'ayeT : tableau de bord ayeT > Placements > le placement > onglet « Conversions » : la transaction doit y figurer avec le statut « completed » et un montant cohérent. Absente = refuser.',
                'Tapjoy : tableau de bord Tapjoy > Reports : la conversion et son montant doivent y figurer.',
                'Ne pas se fier au seul montant affiché dans l\'application.',
              ]),
              section(Icons.rule_rounded, 'Décider', c.warning, const [
                'APPROUVER : compte ancien ou normal, aucun signal d\'alerte, transaction retrouvée chez le partenaire.',
                'REFUSER : compte récent aux gains élevés, rafale, même montant répété, écart de montant, transaction introuvable.',
                'DANS LE DOUTE : refuser. Une tâche honnête refusée peut être refaite ; une tâche frauduleuse payée est de l\'argent perdu.',
                'ABUS CLAIR ou répété : « Suspendre des tâches » sur le profil de l\'utilisateur.',
              ]),
              section(Icons.event_repeat_rounded, 'Contrôles réguliers (chaque jour ou chaque semaine)', c.info, const [
                'Page Tâches et offres > Aperçu > « Comptes à surveiller » (niveau moyen ou élevé).',
                '« Par partenaire de tâches » : comparer les totaux d\'ayeT et de Tapjoy avec les revenus affichés dans leurs tableaux de bord. Un gros écart = alerte.',
                'Tâches « Annulées (régie) » : un même compte qui en accumule est suspect.',
                'Page Commissions : lignes « Tâches : Tapjoy » et « Tâches : ayeT » cohérentes avec l\'activité.',
              ]),
              section(Icons.info_outline_rounded, 'À savoir', c.textSecondary, const [
                'Les pièces d\'une tâche sont « en attente » 48 h, puis deviennent des Pièces gagnées si le partenaire n\'a pas annulé et si le compte remplit encore les conditions (3 jours d\'ancienneté, e-mail vérifié, non suspendu).',
                'Une tâche « en revue » n\'est jamais validée toute seule : approuvée, elle repasse « en attente » et est validée dans les 15 minutes ; refusée, personne ne reçoit rien.',
                'Les conversions de test d\'ayeT (« bac à sable ») sont ignorées, sauf pour les comptes de test déclarés par le développeur.',
                'Réglages actuels (AppConfig/offerwall) : attente 48 h, plafond 2 000 pièces par jour et 10 000 par semaine, parrain 20 % des pièces de l\'utilisateur.',
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}
