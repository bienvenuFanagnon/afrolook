import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../theme/app_colors.dart';

/// Fenêtre affichée quand le mur de tâches n'a aucune offre (au lieu d'un message qui disparaît) : explique quoi faire (revenir plus tard).
Future<void> showOfferwallNoTasksDialog(BuildContext context) => _show(
      context,
      icon: Icons.schedule_rounded,
      title: context.tr('Pas de tâche pour le moment'),
      message: context.tr('Il n\'y a pas de tâche disponible pour le moment. De nouvelles tâches arrivent régulièrement : reviens dans 30 minutes à 1 heure.'),
    );

/// Fenêtre affichée quand le mur de tâches n'a pas pu s'ouvrir (connexion, service indisponible).
Future<void> showOfferwallErrorDialog(BuildContext context) => _show(
      context,
      icon: Icons.wifi_off_rounded,
      title: context.tr('Ouverture impossible'),
      message: context.tr('Les tâches ne se sont pas ouvertes. Vérifie ta connexion et réessaie dans quelques minutes.'),
    );

Future<void> _show(BuildContext context, {required IconData icon, required String title, required String message}) {
  final c = AppColors.of(context);
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: c.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: c.primary.withOpacity(0.14), shape: BoxShape.circle),
            child: Icon(icon, color: c.primary, size: 36),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 14, height: 1.45)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(context.tr('D\'accord'))),
          ),
        ]),
      ),
    ),
  );
}
