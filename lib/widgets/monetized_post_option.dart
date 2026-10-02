import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../theme/app_colors.dart';

/// Option de publication : ce post est-il monétisé ?
/// Monétisé : likes payants (2 pièces : 1 créateur, 1 Afrolook) et vues des abonnés rémunérées.
/// Non monétisé (par défaut) : likes gratuits, vues non rémunérées. Les commentaires sont gratuits dans tous les cas.
class MonetizedPostOption extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const MonetizedPostOption({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: value ? c.accent.withOpacity(0.12) : c.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: value ? c.accent.withOpacity(0.6) : c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🪙', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(context.tr('Post monétisé'),
                    style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14.5)),
              ),
              Switch(value: value, onChanged: onChanged, activeColor: c.primary),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 2),
            child: Text(
              value
                  ? context.tr('Activé : ce post est monétisé. Chaque like coûte 2 pièces à celui qui like (1 pièce pour toi, 1 pour Afrolook, avec un petit « +1 » sur le cœur) et les vues de tes abonnés sont rémunérées.')
                  : context.tr('Désactivé : ce post n\'est pas monétisé. Les likes sont gratuits et ses vues ne rapportent rien. Active-le pour gagner des pièces et des gains de vues avec ce post.'),
              style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Text(
              context.tr('Les commentaires sont toujours gratuits. Ce choix ne pourra plus être modifié après la publication.'),
              style: TextStyle(color: c.textSecondary, fontSize: 11.5, fontStyle: FontStyle.italic, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
