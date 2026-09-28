import 'package:intl/intl.dart';

import '../models/model_data.dart';
import '../services/coin_checkout.dart';
import 'platform_guard.dart';
import '../services/currency_service.dart';

/// Montant d'une transaction (TransactionSoldes) : unité réelle du champ `montant`
/// et affichage « tout en pièces » sur iPhone, avec l'équivalent FCFA à côté.
class TxAmount {
  static final NumberFormat _n = NumberFormat.decimalPattern('fr');

  /// Types dont le montant est toujours en pièces.
  static const _coinTypes = {'GAIN_PIECES', 'LIKE_PIECES', 'CADEAU_PIECES', 'CADEAU_PIECES_RECU'};

  /// Argent réel (retraits, conversions) : toujours affiché en FCFA.
  static const _moneyTypes = {'RETRAIT', 'RETRAITADMIN', 'CONVERSION_PIECES'};

  /// Vrai si `montant` est exprimé en pièces.
  static bool storedInCoins(TransactionSolde t) {
    if (t.coins != null) return true; // nouveau modèle d'achat : montant = pièces
    final type = t.type?.toUpperCase() ?? '';
    if (_coinTypes.contains(type)) return true;
    if (type == 'ACHAT_PIECES') return t.methode_paiement == 'apple_iap';
    if (type == 'DEPENSE') return t.methode_paiement == 'pieces';
    return false;
  }

  static bool _showInCoins(TransactionSolde t) =>
      storedInCoins(t) || (kIsAppleStore && !_moneyTypes.contains(t.type?.toUpperCase()));

  static int coins(TransactionSolde t) {
    final m = t.montant ?? 0;
    return storedInCoins(t) ? m.round() : CoinCheckout.coinsFor(m);
  }

  static double fcfa(TransactionSolde t) {
    final m = t.montant ?? 0;
    return storedInCoins(t) ? m / 2.5 : m;
  }

  static String fmt(num v) => _n.format(v.round());

  /// Montant principal : « 1 250 pièces » ou « 500 FCFA ».
  static String main(TransactionSolde t) =>
      _showInCoins(t) ? '${fmt(coins(t))} pièces' : Money.fmt(fcfa(t));

  /// Pour un achat de pièces : « payé 480 FCFA · Dépôt FCFA » ou « payé 0,99 USD · App Store ».
  static String? paidLabel(TransactionSolde t) {
    if (t.amountPaid == null) return null;
    final cur = (t.currency ?? '').toUpperCase();
    final amount = cur == 'XOF' || cur.isEmpty
        ? '${fmt(t.amountPaid!)} FCFA'
        : '${NumberFormat('#,##0.00', 'fr').format(t.amountPaid)} $cur';
    return t.paymentMethod != null ? 'payé $amount · ${t.paymentMethod}' : 'payé $amount';
  }

  /// Équivalent FCFA (sur iPhone uniquement, pour les montants affichés en pièces).
  static String? equivalent(TransactionSolde t) {
    if (!kIsAppleStore || !_showInCoins(t)) return null;
    final v = fcfa(t);
    return v > 0 ? '≈ ${Money.fmt(v)}' : null;
  }
}
