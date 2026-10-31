import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import 'api/api_gateway.dart';
import 'api/wallet_api.dart';
import 'coin_checkout.dart';

/// Création de canaux et de groupes : le premier est gratuit, chaque suivant coûte 500 pièces (ticket de création).
/// L'API recalcule le prix et refuse (402 `creation_credit_required`) toute création supplémentaire non payée.
class CreationFee {
  /// true si l'utilisateur peut créer (gratuit ou payé à l'instant), false s'il annule ou n'a pas assez de pièces.
  /// [type] : 'canal' ou 'group'.
  static Future<bool> ensurePaid(BuildContext context, String type) async {
    int cost;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      // Le premier canal / groupe est gratuit : on compte ceux que la personne a déjà créés.
      final path = type == 'canal' ? '/channels' : '/groups';
      final r = await ApiGateway.instance.client.get(path, query: type == 'canal' ? {'mine': true, 'limit': 50} : null);
      final owned = WalletApi.list(r).where((c) => c['owner_id'] == uid).length;
      if (owned == 0) return true;
      cost = await WalletApi.instance.quote(type == 'canal' ? 'canal_create' : 'group_create');
    } catch (_) {
      return true; // réseau indisponible : l'API refusera de toute façon une création non payée
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
