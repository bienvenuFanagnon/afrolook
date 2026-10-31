// Signale un paiement qui échoue côté application (achat Google Play / App Store refusé avant d'atteindre l'API, réseau coupé pendant la vérification…).
// Le signalement part vers le suivi des paiements de l'équipe (POST /payments/report : 20 par compte et par jour au plus, côté serveur).
// Ne bloque jamais le paiement : tout est silencieux.

import 'package:afrotok/services/api/admin_complements_api.dart';
import 'package:flutter/foundation.dart';

class PaymentReport {
  PaymentReport._();

  /// [provider] : google_play, apple, feexpay. [expected] : annulation par la personne (consignée sans alerte).
  static void send({required String provider, required String step, String? code, Object? message, double? amount, String? currency, bool expected = false}) {
    if (kDebugMode && !expected) debugPrint('PaymentReport [$provider/$step/$code] $message');
    // Envoi sans attente, sans jamais gêner l'achat
    AdminComplementsApi.reportPayment(provider: provider, step: step, code: code, message: message, amount: amount, currency: currency, expected: expected);
  }
}
