import 'package:flutter/material.dart';

import '../l10n/tr.dart';

/// Genre d'une fenêtre d'information.
enum StatusDialogType { success, error, warning }

/// Fenêtre d'information simple (réussite, erreur ou avertissement) avec un bouton « Fermer » (09/11/2026) : elle remplace `awesome_dialog` dans les écrans
/// de vérification du code reçu par SMS. Ce paquet tirait `rive` (une bibliothèque d'animation de 3 Mo sur iPhone) pour une simple fenêtre de confirmation.
Future<void> showStatusDialog(
  BuildContext context, {
  required StatusDialogType type,
  required String title,
  required String desc,
  VoidCallback? onClose,
}) {
  final (icon, color) = switch (type) {
    StatusDialogType.success => (Icons.check_circle_rounded, const Color(0xFF2E9E5B)),
    StatusDialogType.error => (Icons.error_rounded, const Color(0xFFD64545)),
    StatusDialogType.warning => (Icons.warning_rounded, const Color(0xFFE59A00)),
  };
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: ValueKey('status_dialog_${type.name}'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      icon: Icon(icon, color: color, size: 44),
      title: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Text(desc, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          key: const ValueKey('status_dialog_close'),
          style: FilledButton.styleFrom(backgroundColor: color),
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(ctx.tr('Fermer')),
        ),
      ],
    ),
  ).then((_) => onClose?.call());
}
