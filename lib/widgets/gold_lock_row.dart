import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../pages/user/userAbonnementPage.dart';
import '../theme/app_colors.dart';

/// Ligne « réservé au plan Gold » : cadenas, pastille GOLD, ce que la personne a et ce que Gold change, et un bouton pour agir (passer Gold, ou débloquer autrement).
/// Elle rend visibles les règles de plan qui sont aussi vérifiées par le serveur : la personne comprend tout de suite pourquoi un réglage n'est pas à sa disposition.
class GoldLockRow extends StatelessWidget {
  const GoldLockRow({super.key, required this.title, required this.subtitle, this.actionLabel, this.onAction, this.icon = Icons.lock_outline_rounded});

  final String title;
  final String subtitle;

  /// Texte du bouton ; par défaut « Passer Gold » (ouvre l'écran des abonnements). Avec [onAction], le bouton fait autre chose (par exemple regarder des pubs).
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(color: c.surfaceVariant, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, color: c.textSecondary, size: 22)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 13.5))),
              const SizedBox(width: 8),
              Container(
                key: const ValueKey('gold_chip'),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(99)),
                child: Text('GOLD', style: TextStyle(color: c.onAccent, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .6)),
              ),
            ]),
            const SizedBox(height: 3),
            Text(subtitle, style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.35)),
          ]),
        ),
        const SizedBox(width: 4),
        TextButton(
          key: const ValueKey('gold_lock_action'),
          onPressed: onAction ?? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AbonnementScreen())),
          style: TextButton.styleFrom(foregroundColor: c.accentText, padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: const Size(0, 36), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          child: Text(actionLabel ?? context.tr('Passer Gold'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
        ),
      ]),
    );
  }
}
