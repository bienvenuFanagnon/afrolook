import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../pages/coins/coin_recharge_screen.dart';
import '../providers/authProvider.dart';
import '../providers/coin_gift_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/coin_balances_row.dart';
import '../models/model_data.dart';
import '../l10n/tr.dart';
import 'currency_service.dart';
import '../utils/platform_guard.dart';

/// Paiement en pièces de tous les achats de l'app (Android et iPhone), sauf contenus payants.
/// Le prix est recalculé par la Cloud Function payWithCoins ; ici on n'affiche qu'une estimation.
class CoinCheckout {
  /// Taux de la recharge : 25 pièces pour 10 FCFA.
  static const double coinsPerFcfa = 2.5;
  static final NumberFormat _n = NumberFormat.decimalPattern('fr');

  static int coinsFor(double fcfa) => (fcfa * coinsPerFcfa).ceil();
  static double fcfaFor(int coins) => coins / coinsPerFcfa;
  static String fmt(num v) => _n.format(v.round());

  /// « X pièces (≈ Y FCFA) » à partir d'un prix FCFA (prix de l'app).
  static String priceLabel(num fcfa) => coinsLabel(coinsFor(fcfa.toDouble()));

  /// « X pièces (≈ Y FCFA) » à partir d'un prix en pièces ; l'équivalent FCFA est indicatif.
  /// Sur iPhone/iPad : prix en pièces seulement, sans équivalent en argent (règle App Store 3.1.1).
  static String coinsLabel(int coins) => kIsAppleStore
      ? tr('{a} pièces', {'a': fmt(coins)})
      : tr('{a} pièces ({b})', {'a': fmt(coins), 'b': Money.approx(fcfaFor(coins))});

  /// Prix en pièces d'un élément créé par un utilisateur : champ en pièces, sinon ancien prix FCFA × 2,5.
  static int creatorCoins(num? coinsField, num? fcfaField) =>
      (coinsField ?? 0) > 0 ? coinsField!.ceil() : coinsFor((fcfaField ?? 0).toDouble());

  /// Demande confirmation, débite les pièces côté serveur, et retourne true si le paiement est fait.
  /// [coins] : prix en pièces (sinon calculé depuis [priceFcfa]).
  /// [kind] : premium, gold, official, group, canal, live_entry, live_participant, content,
  /// ad (publicité, [weeks] + [combined]), ad_renew et profile_boost ([weeks]), product_boost ([days]).
  static Future<bool> pay(
    BuildContext context, {
    required String kind,
    required String label,
    int? coins,
    double? priceFcfa,
    String? refId,
    int? dureeMois,
    int? weeks,
    bool? combined,
    int? days,
  }) async {
    final price = coins ?? coinsFor(priceFcfa ?? 0);
    final user = Provider.of<UserAuthProvider>(context, listen: false).loginUserData;
    final balance = user.giftCoinsBalance ?? 0;
    if (balance < price) {
      await insufficient(context, price);
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
          Text(context.tr('{a} pièces', {'a': fmt(price)}),
              style: TextStyle(color: c.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
          if (!kIsAppleStore) Text(Money.approx(fcfaFor(price)), style: TextStyle(color: c.textSecondary, fontSize: 13)),
          const SizedBox(height: 12),
          CoinBalancesInline(user: user),
          const SizedBox(height: 8),
          Text(_debitLabel(user, price), style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.35)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Annuler'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary),
            child: Text(context.tr('Payer')),
          ),
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
        if (days != null) 'days': days,
      });
      if (context.mounted) await refreshBalance(context);
      return true;
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return false;
      if (e.code == 'resource-exhausted') {
        await refreshBalance(context);
        if (context.mounted) await insufficient(context, price);
      } else if (e.code == 'already-exists') {
        // Achat déjà fait (ex. pack de stickers déjà possédé) : rien n'est débité.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Tu possèdes déjà cet achat. Tu n\'as pas été débité.'))),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Le paiement n\'a pas pu être effectué. Tu n\'as pas été débité.'))),
        );
      }
      return false;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Le paiement n\'a pas pu être effectué. Vérifie ta connexion.'))),
        );
      }
      return false;
    }
  }

  /// Rafraîchit le solde de pièces (fournisseur des pièces + utilisateur connecté).
  static Future<void> refreshBalance(BuildContext context) async {
    try {
      final auth = Provider.of<UserAuthProvider>(context, listen: false);
      final uid = auth.loginUserData.id;
      if (uid != null) {
        await Provider.of<CoinGiftUserProvider>(context, listen: false).refreshBalance(uid);
        await auth.refreshUserData();
      }
    } catch (_) {}
  }

  /// Fenêtre « pas assez de pièces » : solde, prix, ce qui manque, bouton d'achat.
  /// « Débité : 300 pièces de dépôt + 200 pièces gagnées » (le dépôt part en premier, comme sur le serveur).
  static String _debitLabel(UserData user, int price) {
    final s = CoinSplit.of(user);
    final fromDepot = price < s.depot ? price : s.depot;
    final fromGagnees = price - fromDepot;
    if (fromGagnees <= 0) return tr('Débité de tes pièces de dépôt.');
    if (fromDepot <= 0) return tr('Débité de tes pièces gagnées (ton dépôt est vide).');
    return tr('Débité : {a} pièces de dépôt + {b} pièces gagnées.', {'a': fmt(fromDepot), 'b': fmt(fromGagnees)});
  }

  static Future<void> insufficient(BuildContext context, int coins) {
    final c = AppColors.of(context);
    final user = Provider.of<UserAuthProvider>(context, listen: false).loginUserData;
    final balance = user.giftCoinsBalance ?? 0;
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
        title: Text(context.tr('Pas assez de pièces'),
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 17)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          row(context.tr('Prix'), context.tr('{a} pièces', {'a': fmt(coins)})),
          row(context.tr('Ton solde'), context.tr('{a} pièces', {'a': fmt(balance)})),
          const SizedBox(height: 6),
          CoinBalancesInline(user: user),
          Divider(color: c.border),
          row(context.tr('Il te manque'), context.tr('{a} pièces', {'a': fmt(missing)}), color: c.danger),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('Fermer'))),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => CoinRechargeScreen()));
            },
            style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary),
            child: Text(context.tr('Acheter des pièces')),
          ),
        ],
      ),
    );
  }
}
