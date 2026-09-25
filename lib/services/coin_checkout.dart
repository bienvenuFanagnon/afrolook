import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../pages/coins/apple_coin_store_view.dart';
import '../providers/authProvider.dart';
import '../providers/coin_gift_provider.dart';

/// Paiement en pièces des achats numériques sur iPhone (règle App Store 3.1.1).
/// Le prix est recalculé par la Cloud Function payWithCoins ; ici on n'affiche qu'une estimation.
class CoinCheckout {
  /// Même taux que la recharge : 25 pièces pour 10 FCFA.
  static int coinsFor(double fcfa) => (fcfa * 2.5).ceil();

  /// Prix affiché sur iPhone : « X pièces (≈ Y FCFA) ».
  static String priceLabel(num fcfa) => '${coinsFor(fcfa.toDouble())} pièces (≈ ${fcfa.round()} FCFA)';

  /// Demande confirmation, débite les pièces côté serveur, et retourne true si le paiement est fait.
  /// [kind] : premium, gold, official, group, content, pronostic, canal, live_entry, live_participant,
  /// ad (publicité, [weeks] + [combined]), ad_renew et profile_boost ([weeks]).
  static Future<bool> pay(
    BuildContext context, {
    required String kind,
    required double priceFcfa,
    required String label,
    String? refId,
    int? dureeMois,
    int? weeks,
    bool? combined,
  }) async {
    final coins = coinsFor(priceFcfa);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: Text('Payer $coins pièces (≈ ${priceFcfa.round()} FCFA) ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Payer $coins 🪙')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return false;

    try {
      await FirebaseFunctions.instance.httpsCallable('payWithCoins').call({
        'kind': kind,
        if (refId != null) 'refId': refId,
        if (dureeMois != null) 'dureeMois': dureeMois,
        if (weeks != null) 'weeks': weeks,
        if (combined != null) 'combined': combined,
      });
      if (context.mounted) await refreshBalance(context);
      return true;
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return false;
      if (e.code == 'resource-exhausted') {
        await insufficient(context, coins);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Le paiement n'a pas pu être effectué. Tu n'as pas été débité.")),
        );
      }
      return false;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Le paiement n'a pas pu être effectué. Vérifie ta connexion.")),
        );
      }
      return false;
    }
  }

  static Future<void> refreshBalance(BuildContext context) async {
    try {
      final uid = Provider.of<UserAuthProvider>(context, listen: false).loginUserData.id;
      if (uid != null) await Provider.of<CoinGiftUserProvider>(context, listen: false).refreshBalance(uid);
    } catch (_) {}
  }

  static Future<void> insufficient(BuildContext context, int coins) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Solde de pièces insuffisant'),
        content: Text('Il te faut $coins pièces pour cet achat. Achète des pièces pour continuer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AppleCoinStoreView()));
            },
            child: const Text('Acheter des pièces'),
          ),
        ],
      ),
    );
  }
}
