// Signale un paiement qui échoue côté application (achat Google Play / App Store refusé avant d'atteindre l'API, réseau coupé pendant la vérification…).
// L'API n'a pas encore de point d'accès pour ces signalements (voir lacunes_api_argent_creations.md) : pour l'instant la trace reste dans le journal local.
// Ne bloque jamais le paiement : tout est silencieux.

import 'package:flutter/foundation.dart';

class PaymentReport {
  PaymentReport._();

  /// [provider] : google_play, apple, feexpay. [expected] : annulation par la personne (consignée sans alerte).
  static void send({required String provider, required String step, String? code, Object? message, double? amount, String? currency, bool expected = false}) {
    if (kDebugMode && !expected) debugPrint('PaymentReport [$provider/$step/$code] $message');
  }
}
