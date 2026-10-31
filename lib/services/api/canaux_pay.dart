import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/pages/coins/coin_recharge_screen.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/canaux_api.dart';
import 'package:afrotok/services/coin_checkout.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:afrotok/l10n/tr.dart';
import 'package:flutter/material.dart';

/// Paiement en pièces des achats de canaux (abonnement, déblocage, ticket de création) par le point d'achat unique de l'API.
/// Le solde est TOUJOURS lu sur l'API ; la clé d'idempotence est conservée tant que l'achat n'a pas abouti.
class CanauxPay {
  CanauxPay._();

  /// Solde total de pièces (dépôt + gagnées) lu sur l'API ; null si illisible.
  static Future<int?> balance() async {
    try {
      final r = await ApiGateway.instance.client.get('/wallet');
      final d = ApiClient.data(r);
      return d is Map ? (d['total_coins'] as num?)?.toInt() : null;
    } catch (_) {
      return null;
    }
  }

  /// Demande confirmation puis paie. true = payé. [coins] : prix affiché (le serveur recalcule et fait foi).
  static Future<bool> buy(
    BuildContext context, {
    required String kind,
    required String label,
    required int coins,
    String? refId,
  }) async {
    final bal = await balance();
    if (!context.mounted) return false;
    if (bal != null && bal < coins) {
      await _insufficient(context, coins, bal);
      return false;
    }
    final c = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(label, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 17)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ctx.tr('{a} pièces', {'a': CoinCheckout.fmt(coins)}), style: TextStyle(color: c.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
          if (bal != null) ...[
            const SizedBox(height: 8),
            Text(ctx.tr('Ton solde : {a} pièces', {'a': CoinCheckout.fmt(bal)}), style: TextStyle(color: c.textSecondary, fontSize: 13)),
          ],
        ]),
        actions: [
          TextButton(
            onPressed: () {
              CanauxApi.forgetKey(kind, refId: refId);
              Navigator.pop(ctx, false);
            },
            child: Text(ctx.tr('Annuler')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary),
            child: Text(ctx.tr('Payer')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return false;
    try {
      await CanauxApi.buy(kind, refId: refId);
      return true;
    } on ApiException catch (e) {
      if (!context.mounted) return false;
      if (e.isInsufficientCoins) {
        CanauxApi.forgetKey(kind, refId: refId);
        await _insufficient(context, coins, await balance() ?? 0);
      } else if (e.status == 409) {
        CanauxApi.forgetKey(kind, refId: refId);
        _snack(context, context.tr('Tu possèdes déjà cet achat. Tu n\'as pas été débité.'));
      } else if (e.isNetwork) {
        // La clé est conservée : « Payer » de nouveau ne débitera jamais deux fois.
        _snack(context, context.tr('Le paiement n\'a pas pu être confirmé. Vérifie ta connexion puis réessaie : tu ne seras pas débité deux fois.'));
      } else {
        CanauxApi.forgetKey(kind, refId: refId);
        _snack(context, e.message);
      }
      return false;
    } catch (_) {
      if (context.mounted) _snack(context, context.tr('Le paiement n\'a pas pu être effectué. Tu n\'as pas été débité.'));
      return false;
    }
  }

  static void _snack(BuildContext context, String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  static Future<void> _insufficient(BuildContext context, int coins, int balance) {
    final c = AppColors.of(context);
    final missing = (coins - balance).clamp(0, coins);
    Widget row(String k, String v, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(k, style: TextStyle(color: c.textSecondary, fontSize: 13.5))),
            Text(v, style: TextStyle(color: color ?? c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
        );
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(ctx.tr('Pas assez de pièces'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 17)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          row(ctx.tr('Prix'), ctx.tr('{a} pièces', {'a': CoinCheckout.fmt(coins)})),
          row(ctx.tr('Ton solde'), ctx.tr('{a} pièces', {'a': CoinCheckout.fmt(balance)})),
          Divider(color: c.border),
          row(ctx.tr('Il te manque'), ctx.tr('{a} pièces', {'a': CoinCheckout.fmt(missing)}), color: c.danger),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.tr('Fermer'))),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => CoinRechargeScreen()));
            },
            style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary),
            child: Text(ctx.tr('Acheter des pièces')),
          ),
        ],
      ),
    );
  }
}
