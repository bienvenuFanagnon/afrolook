import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/pages/coins/coin_recharge_screen.dart';
import 'package:afrotok/services/api/audit_errors.dart';
import 'package:afrotok/widgets/email_verification_gate.dart';
import 'package:flutter/material.dart';

/// Messages d'erreur de l'API pour les écrans de publications.

/// Texte lisible pour une erreur (message de l'API en français, sinon texte générique).
String apiErrorText(Object e, {String fallback = 'Une erreur est survenue. Réessayez.'}) {
  // Codes de l'audit (e-mail non confirmé, plafonds, compte trop récent…) : texte traduit dans la langue de la personne.
  if (e is ApiException) return AuditErrors.known(e) ?? e.message;
  return fallback;
}

/// Affiche l'erreur dans une bannière ; propose « Réessayer » si [onRetry] est fourni.
void showApiError(BuildContext context, Object e, {VoidCallback? onRetry, String? fallback}) {
  if (!context.mounted) return;
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(apiErrorText(e, fallback: fallback ?? 'Une erreur est survenue. Réessayez.')),
    backgroundColor: Colors.red,
    // le délai entre deux publications n'a pas de « Réessayer » : tant que l'attente n'est pas finie, un nouvel essai est refusé
    action: onRetry == null || (e is ApiException && e.code == 'post_cooldown') ? null : SnackBarAction(label: 'Réessayer', textColor: Colors.white, onPressed: onRetry),
  ));
}

/// Pièces insuffisantes (erreur 402) : explique et propose de recharger.
Future<void> showRechargeDialog(BuildContext context, {required String message}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Pièces insuffisantes'),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Plus tard')),
        FilledButton(
          onPressed: () {
            Navigator.pop(ctx);
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CoinRechargeScreen()));
          },
          child: const Text('Recharger'),
        ),
      ],
    ),
  );
}

/// Gère une erreur d'API : recharge si 402, sinon bannière avec « Réessayer ».
void handleApiError(BuildContext context, Object e, {VoidCallback? onRetry, String? fallback}) {
  if (e is ApiException && e.isInsufficientCoins) {
    showRechargeDialog(context, message: e.message);
  } else if (EmailVerificationGate.isUnverified(e)) {
    // E-mail non confirmé : fenêtre « Confirme ton e-mail » ; une fois confirmé, l'action est rejouée si l'écran sait la rejouer.
    EmailVerificationGate.confirm(context).then((ok) {
      if (ok && onRetry != null) onRetry();
    });
  } else {
    showApiError(context, e, onRetry: onRetry, fallback: fallback);
  }
}
