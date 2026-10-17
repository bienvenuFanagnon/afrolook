// Signale au serveur un paiement qui échoue côté application (achat Google Play / App Store refusé avant d'atteindre le serveur,
// réseau coupé pendant la vérification…). L'administration le voit dans « Suivi des paiements » et reçoit un e-mail d'alerte.
// Ne bloque jamais le paiement : tout est silencieux.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class PaymentReport {
  PaymentReport._();

  /// [provider] : google_play, apple, feexpay, cinetpay, paygate. [expected] : annulation par la personne (consignée sans alerte).
  static void send({required String provider, required String step, String? code, Object? message, double? amount, String? currency, bool expected = false}) {
    () async {
      try {
        await FirebaseFunctions.instance.httpsCallable('paymentReport').call({
          'provider': provider,
          'step': step,
          'code': code,
          'message': '${message ?? ''}'.length > 400 ? '${message ?? ''}'.substring(0, 400) : '${message ?? ''}',
          'amount': amount,
          'currency': currency,
          'expected': expected,
        });
      } catch (e) {
        if (kDebugMode) debugPrint('PaymentReport : $e');
      }
    }();
  }
}
