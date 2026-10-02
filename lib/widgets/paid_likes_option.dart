import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../theme/app_colors.dart';

/// Option de publication : les likes de ce post rapportent-ils des pièces au créateur ?
/// Désactivée par défaut (likes gratuits). Les commentaires sont gratuits dans tous les cas.
class PaidLikesOption extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const PaidLikesOption({super.key, required this.value, required this.onChanged});

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
                child: Text(context.tr('Likes payants'),
                    style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14.5)),
              ),
              Switch(value: value, onChanged: onChanged, activeColor: c.primary),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 2),
            child: Text(
              value
                  ? context.tr('Activé : chaque like coûte 2 pièces à celui qui like — 1 pièce pour toi, 1 pour Afrolook. Un petit « +1 » s\'affiche sur le cœur.')
                  : context.tr('Désactivé : les likes de ce post sont gratuits pour tout le monde, tu ne gagnes pas de pièces avec les likes. Active-le pour être payé à chaque like.'),
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
