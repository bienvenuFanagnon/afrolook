import 'package:flutter/material.dart';

import '../ads/rewards_service.dart';
import '../theme/app_colors.dart';

/// Petite pastille « GOLD » avec un cadenas : posée sur une option du Studio qui dépend du plan. Elle ne s'affiche que si l'option est encore FERMÉE pour la personne
/// (ni plan Gold, ni passe, ni déblocage du jour) : un toucher sur l'option ouvre alors le choix « Passer Gold » ou « Regarder des pubs » ([GoldGate.feature]).
class GoldBadge extends StatelessWidget {
  const GoldBadge({super.key, this.compact = false});

  /// Version plus petite pour les boutons ronds de la caméra et du Studio.
  final bool compact;

  /// Vrai si la fonction [featureKey] (catalogue de [RewardsService.featureCatalog]) est fermée pour la personne.
  static bool locked(String? featureKey) => featureKey != null && !RewardsService.featureUnlocked(featureKey);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final h = compact ? 13.0 : 16.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 6, vertical: 1),
      decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(99), boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 3)]),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.lock_rounded, size: h - 4, color: c.onAccent),
        const SizedBox(width: 2),
        Text('GOLD', style: TextStyle(color: c.onAccent, fontSize: compact ? 8 : 9.5, fontWeight: FontWeight.w900, letterSpacing: .4, height: 1.1)),
      ]),
    );
  }
}
