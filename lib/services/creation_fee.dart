import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import 'coin_checkout.dart';

/// Création de canaux et de groupes : le premier est gratuit, chaque suivant coûte 500 pièces.
/// Le serveur recalcule le prix et refuse (supprime) toute création supplémentaire non payée.
class CreationFee {
  /// true si l'utilisateur peut créer (gratuit ou payé à l'instant), false s'il annule ou n'a pas assez de pièces.
  /// [type] : 'canal' ou 'group'.
  static Future<bool> ensurePaid(BuildContext context, String type) async {
    int cost;
    try {
      final r = await FirebaseFunctions.instance.httpsCallable('creationQuote').call({'type': type});
      cost = ((r.data as Map)['cost'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return true; // réseau indisponible : le serveur refusera de toute façon une création non payée
    }
    if (cost <= 0) return true;
    if (!context.mounted) return false;
    return CoinCheckout.pay(
      context,
      kind: type == 'canal' ? 'canal_create' : 'group_create',
      label: type == 'canal'
          ? tr('Créer un canal supplémentaire')
          : tr('Créer un groupe supplémentaire'),
      coins: cost,
    );
  }
}
