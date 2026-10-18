import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Un pack de pièces vendu par carte bancaire (prix en dollars, frais compris).
class CardPack {
  const CardPack({required this.coins, required this.total, required this.xof});
  final int coins;
  final double total;
  final double xof;
}

class CardQuote {
  const CardQuote({required this.enabled, required this.termsVersion, required this.feePct, required this.xofPerUsd, required this.packs});
  final bool enabled;
  final String termsVersion;
  final double feePct;
  final double xofPerUsd;
  final List<CardPack> packs;
}

/// Achat de pièces par carte bancaire (FeexPay) : disponible uniquement sur le site web.
/// Les applications Android et iPhone n'affichent ni ne contactent rien de tout ça (le serveur refuse aussi toute demande sans origine web).
class CardCoins {
  CardCoins._();

  static const _pendingKey = 'card_coin_pending';

  static bool get available => kIsWeb;

  static final HttpsCallable _quote = FirebaseFunctions.instance.httpsCallable('cardCoinQuote');
  static final HttpsCallable _start = FirebaseFunctions.instance.httpsCallable('cardCoinStart');
  static final HttpsCallable _status = FirebaseFunctions.instance.httpsCallable('cardCoinStatus');

  /// Remplace l'appel serveur dans les tests.
  @visibleForTesting
  static Future<CardQuote?> Function()? quoteOverride;

  static Future<CardQuote?> quote() async {
    if (quoteOverride != null) return quoteOverride!();
    if (!available) return null;
    try {
      final r = (await _quote.call()).data as Map;
      return CardQuote(
        enabled: r['enabled'] == true,
        termsVersion: '${r['termsVersion']}',
        feePct: (r['feePct'] as num).toDouble(),
        xofPerUsd: (r['xofPerUsd'] as num).toDouble(),
        packs: [
          for (final p in (r['packs'] as List))
            CardPack(coins: (p['coins'] as num).toInt(), total: (p['total'] as num).toDouble(), xof: (p['xof'] as num).toDouble()),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  /// Crée la commande, mémorise son identifiant puis ouvre la page de paiement sécurisée FeexPay dans le même onglet.
  /// Lance une [FirebaseFunctionsException] dont le message est affichable à la personne.
  static Future<void> pay({
    required int coins,
    required String firstName,
    required String lastName,
    required String phone,
    required String city,
    required String zip,
    required String country,
  }) async {
    final r = (await _start.call({
      'coins': coins, 'firstName': firstName, 'lastName': lastName, 'phone': phone,
      'city': city, 'zip': zip, 'country': country, 'terms': true,
    }))
        .data as Map;
    try {
      (await SharedPreferences.getInstance()).setString(_pendingKey, '${r['orderId']}|${DateTime.now().millisecondsSinceEpoch}');
    } catch (_) {}
    await launchUrl(Uri.parse('${r['paymentUrl']}'), webOnlyWindowName: '_self');
  }

  /// Statut de la commande : `paid`, `failed`, `pending`… (le serveur vérifie auprès de FeexPay avant de créditer).
  static Future<({String status, int coins})> status(String orderId) async {
    final r = (await _status.call({'orderId': orderId})).data as Map;
    return (status: '${r['status']}', coins: (r['coins'] as num?)?.toInt() ?? 0);
  }

  /// Au retour de la page de paiement : attend la confirmation de la commande en cours.
  /// Renvoie le nombre de pièces créditées, 0 si le paiement a échoué, ou null s'il n'y a rien à vérifier.
  static Future<int?> resumePending() async {
    if (!available) return null;
    String? id;
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      final raw = (prefs.getString(_pendingKey) ?? '').split('|');
      id = raw.first;
      // Paiement abandonné depuis plus d'une heure : on arrête de le suivre (le serveur crédite quand même si FeexPay confirme)
      if (raw.length > 1 && DateTime.now().millisecondsSinceEpoch - (int.tryParse(raw[1]) ?? 0) > 3600 * 1000) {
        await prefs.remove(_pendingKey);
        return null;
      }
    } catch (_) {}
    if (id == null || id.isEmpty) return null;
    for (var i = 0; i < 15; i++) {
      try {
        final s = await status(id);
        if (s.status == 'paid') {
          await prefs?.remove(_pendingKey);
          return s.coins;
        }
        if (s.status == 'failed' || s.status == 'expired' || s.status == 'not_found') {
          await prefs?.remove(_pendingKey);
          return 0;
        }
      } on FirebaseFunctionsException catch (e) {
        if (e.code == 'not-found' || e.code == 'permission-denied') {
          await prefs?.remove(_pendingKey);
          return null;
        }
      } catch (_) {}
      await Future.delayed(const Duration(seconds: 4));
    }
    return null; // toujours en attente : le serveur créditera dès que FeexPay confirme
  }
}
