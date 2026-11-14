import 'package:flutter/material.dart';

import '../../l10n/tr.dart';

/// Badge « Vendeur vérifié » : un BOUCLIER VERT (identité contrôlée par l'équipe). À ne jamais confondre avec le badge officiel de l'application
/// (compte officiel / certifié), qui reste la coche habituelle : ici la forme (bouclier) et la couleur (vert) sont propres à la vente.
/// Affiché à côté du pseudo du vendeur : cartes de commande, étals du marché, vitrine.
class SellerVerifiedBadge extends StatelessWidget {
  const SellerVerifiedBadge({super.key, this.compact = false, this.onDark = false});

  /// Seulement l'icône (petits espaces) ; sinon icône et mot « Vendeur vérifié ».
  final bool compact;

  /// Sur fond sombre (écran du live) : texte clair.
  final bool onDark;

  static const Color green = Color(0xFF1E9E63);

  @override
  Widget build(BuildContext context) {
    final label = tr('Vendeur vérifié');
    final icon = Icon(Icons.verified_user_rounded, key: const ValueKey('seller_verified_icon'), size: compact ? 14 : 13, color: green);
    return Tooltip(
      message: label,
      child: compact
          ? icon
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: green.withOpacity(onDark ? 0.22 : 0.12), borderRadius: BorderRadius.circular(99), border: Border.all(color: green.withOpacity(0.55))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                icon,
                const SizedBox(width: 3),
                Text(label, style: TextStyle(color: onDark ? const Color(0xFF8FE3B8) : green, fontSize: 10.5, fontWeight: FontWeight.w800)),
              ]),
            ),
    );
  }
}
