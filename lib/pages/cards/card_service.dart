import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../../l10n/tr.dart';

enum CardKind { capture, publish }

/// Ce que coûte une carte : gratuite (pass, quota du mois, carte d'essai, crédit gagné avec une pub) ou en pièces.
class CardCost {
  const CardCost(this.via, this.coins);
  final String via; // admin | pass | quota | trial | ad | coins
  final int coins;

  bool get free => coins == 0;

  factory CardCost.fromMap(Map m) => CardCost((m['via'] as String?) ?? 'coins', (m['coins'] as num?)?.toInt() ?? 0);

  /// Libellé court pour un bouton : « Gratuit », « 25 🪙 »…
  String get label => free ? tr('Gratuit') : '$coins 🪙';

  /// Pourquoi c'est gratuit (ou non), en une phrase.
  String get reason => switch (via) {
        'admin' => tr('Administrateur'),
        'pass' => tr('Pass Studio'),
        'quota' => tr('Inclus dans ton plan'),
        'trial' => tr('Carte d\'essai offerte'),
        'ad' => tr('Gagnée avec une pub'),
        _ => tr('Payée en pièces'),
      };
}

/// État du mois et prix, calculés par le serveur (`cardQuote`).
class CardQuote {
  const CardQuote({
    required this.enabled,
    required this.plan,
    required this.passUntil,
    required this.trialLeft,
    required this.adCredits,
    required this.balance,
    required this.captures,
    required this.publishes,
    required this.capturesMax,
    required this.publishesMax,
    required this.priceCapture,
    required this.pricePublish,
    required this.priceProStyle,
    required this.passPrice,
    required this.passDays,
    required this.proStyles,
    required this.options,
  });

  final bool enabled;
  final String plan; // free | premium | gold
  final int passUntil;
  final int trialLeft;
  final int adCredits;
  final int balance;
  final int captures, publishes, capturesMax, publishesMax;
  final int priceCapture, pricePublish, priceProStyle, passPrice, passDays;
  final List<String> proStyles;

  /// Coût de chaque sortie : `options[kind][pro]`.
  final Map<CardKind, Map<bool, CardCost>> options;

  bool get passActive => passUntil > DateTime.now().millisecondsSinceEpoch;

  CardCost cost(CardKind kind, {required bool pro}) => options[kind]![pro]!;

  factory CardQuote.fromMap(Map m) {
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    final month = (m['month'] as Map?) ?? const {};
    final prices = (m['prices'] as Map?) ?? const {};
    final opt = (m['options'] as Map?) ?? const {};
    Map<bool, CardCost> pair(String k) {
      final o = (opt[k] as Map?) ?? const {};
      return {
        false: CardCost.fromMap((o['base'] as Map?) ?? const {}),
        true: CardCost.fromMap((o['pro'] as Map?) ?? const {}),
      };
    }

    return CardQuote(
      enabled: m['enabled'] != false,
      plan: (m['plan'] as String?) ?? 'free',
      passUntil: n(m['passUntil']),
      trialLeft: n(m['trialLeft']),
      adCredits: n(m['adCredits']),
      balance: n(m['balance']),
      captures: n(month['captures']),
      publishes: n(month['publishes']),
      capturesMax: n(month['capturesMax']),
      publishesMax: n(month['publishesMax']),
      priceCapture: n(prices['capture']),
      pricePublish: n(prices['publish']),
      priceProStyle: n(prices['proStyle']),
      passPrice: n(prices['pass']),
      passDays: n(prices['passDays']),
      proStyles: ((m['proStyles'] as List?) ?? const ['bogolan']).map((e) => '$e').toList(),
      options: {CardKind.capture: pair('capture'), CardKind.publish: pair('publish')},
    );
  }

  /// Devis utilisé tant que le serveur n'a pas répondu (ou hors connexion) : tout est présenté « payant », le serveur tranche.
  static CardQuote fallback() => CardQuote.fromMap({
        'enabled': true,
        'plan': 'free',
        'prices': {'capture': 25, 'publish': 10, 'proStyle': 20, 'pass': 400, 'passDays': 30},
        'options': {
          'capture': {'base': {'via': 'coins', 'coins': 25}, 'pro': {'via': 'coins', 'coins': 45}},
          'publish': {'base': {'via': 'coins', 'coins': 10}, 'pro': {'via': 'coins', 'coins': 30}},
        },
      });
}

/// Solde de pièces insuffisant : [coins] demandées, [balance] disponibles.
class CardInsufficient implements Exception {
  CardInsufficient(this.coins, this.balance);
  final int coins;
  final int balance;
}

class CardsDisabled implements Exception {}

/// Appels au serveur du Studio Cartes. Le serveur décide de tout (quotas, prix, pass) ; l'app affiche et fabrique l'image.
class CardService {
  CardService._();

  static final _fn = FirebaseFunctions.instance;

  static Future<CardQuote> quote() async {
    try {
      final r = await _fn.httpsCallable('cardQuote').call();
      return CardQuote.fromMap(Map<String, dynamic>.from(r.data as Map));
    } catch (e) {
      debugPrint('[Cartes] devis : $e');
      return CardQuote.fallback();
    }
  }

  /// Enregistre l'usage et débite si besoin. À appeler AVANT de sortir l'image ; lève [CardInsufficient] si le solde ne suffit pas.
  static Future<CardCost> commit(CardKind kind, {required bool pro}) async {
    try {
      final r = await _fn.httpsCallable('cardCommit').call({'kind': kind.name, 'pro': pro});
      final m = Map<String, dynamic>.from(r.data as Map);
      return CardCost((m['via'] as String?) ?? 'coins', (m['paid'] as num?)?.toInt() ?? 0);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        final d = e.details is Map ? e.details as Map : const {};
        throw CardInsufficient((d['coins'] as num?)?.toInt() ?? 0, (d['balance'] as num?)?.toInt() ?? 0);
      }
      if (e.message == 'CARDS_OFF') throw CardsDisabled();
      rethrow;
    }
  }

  /// Pass Studio : retourne la date de fin (ms).
  static Future<int> buyPass() async {
    try {
      final r = await _fn.httpsCallable('cardPassBuy').call();
      return ((r.data as Map)['until'] as num?)?.toInt() ?? 0;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        final d = e.details is Map ? e.details as Map : const {};
        throw CardInsufficient((d['coins'] as num?)?.toInt() ?? 0, (d['balance'] as num?)?.toInt() ?? 0);
      }
      rethrow;
    }
  }
}
