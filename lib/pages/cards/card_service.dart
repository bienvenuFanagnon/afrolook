import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:flutter/foundation.dart';

import '../../l10n/tr.dart';
import '../../services/api/api_gateway.dart';
import '../../services/api/wallet_api.dart';
import 'card_models.dart';

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
    this.promoFlagCountry,
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

  /// Fête nationale du pays de la personne : ses styles « drapeau » sont offerts aujourd'hui (code du pays), sinon null.
  final String? promoFlagCountry;

  /// Coût de chaque sortie : `options[kind][pro]`.
  final Map<CardKind, Map<bool, CardCost>> options;

  /// Ce style est-il payant (Pro) pour cette personne, aujourd'hui ?
  bool isPro(CardStyleId s) => proStyles.contains(s.name) && !(promoFlagCountry != null && s.usesFlag);

  bool get passActive => passUntil > DateTime.now().millisecondsSinceEpoch;

  CardCost cost(CardKind kind, {required bool pro}) => options[kind]![pro]!;

  factory CardQuote.fromMap(Map m) {
    int n(Object? v) => (v as num?)?.toInt() ?? 0;
    // La date de fin du pass arrive en texte (ISO) ou en millisecondes
    int _ms(Object? v) => v is num ? v.toInt() : (DateTime.tryParse('${v ?? ''}')?.millisecondsSinceEpoch ?? 0);
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
      passUntil: _ms(m['pass_until'] ?? m['passUntil']),
      trialLeft: n(m['trial_left'] ?? m['trialLeft']),
      adCredits: n(m['ad_credits'] ?? m['adCredits']),
      balance: n(m['balance']),
      captures: n(month['captures']),
      publishes: n(month['publishes']),
      capturesMax: n(month['captures_max'] ?? month['capturesMax']),
      publishesMax: n(month['publishes_max'] ?? month['publishesMax']),
      priceCapture: n(prices['capture']),
      pricePublish: n(prices['publish']),
      priceProStyle: n(prices['pro_style'] ?? prices['proStyle']),
      passPrice: n(prices['pass']),
      passDays: n(prices['pass_days'] ?? prices['passDays']),
      proStyles: (m['pro_styles'] ?? m['proStyles']) is List ? ((m['pro_styles'] ?? m['proStyles']) as List).map((e) => '$e').toList() : CardStyleIdX.defaultPro,
      options: {CardKind.capture: pair('capture'), CardKind.publish: pair('publish')},
      promoFlagCountry: (m['promo'] is Map && ((m['promo'] as Map)['flag_free'] == true || (m['promo'] as Map)['flagFree'] == true)) ? '${(m['promo'] as Map)['country'] ?? ''}' : null,
    );
  }

  /// Même devis avec le solde de pièces lu sur l'API.
  static CardQuote withBalance(CardQuote q, int balance) => CardQuote(
        enabled: q.enabled, plan: q.plan, passUntil: q.passUntil, trialLeft: q.trialLeft, adCredits: q.adCredits, balance: balance,
        captures: q.captures, publishes: q.publishes, capturesMax: q.capturesMax, publishesMax: q.publishesMax, priceCapture: q.priceCapture,
        pricePublish: q.pricePublish, priceProStyle: q.priceProStyle, passPrice: q.passPrice, passDays: q.passDays, proStyles: q.proStyles,
        options: q.options, promoFlagCountry: q.promoFlagCountry);

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

  /// Styles Pro connus (dernier devis) : l'API décide elle-même si un style est Pro d'après son nom.
  static List<String> _proStyles = CardStyleIdX.defaultPro;

  static Future<CardQuote> quote() async {
    try {
      final r = WalletApi.map(await ApiGateway.instance.client.get('/cards/quote'));
      final q = CardQuote.fromMap(r);
      _proStyles = q.proStyles;
      // Solde de pièces lu sur l'API (jamais calculé ici)
      int balance = 0;
      try {
        balance = (await WalletApi.instance.wallet()).totalCoins;
      } catch (_) {}
      return CardQuote.withBalance(q, balance);
    } catch (e) {
      debugPrint('[Cartes] devis : $e');
      return CardQuote.fallback();
    }
  }

  /// Enregistre l'usage et débite si besoin. À appeler AVANT de sortir l'image ; lève [CardInsufficient] si le solde ne suffit pas.
  /// [style] : nom du style de carte (l'API en déduit seule s'il est Pro) ; à défaut, un style Pro connu si [pro].
  static Future<CardCost> commit(CardKind kind, {required bool pro, String? style}) async {
    final st = style ?? (pro && _proStyles.isNotEmpty ? _proStyles.first : 'classic');
    try {
      final m = await WalletApi.instance.pay('card:${kind.name}:$st:${DateTime.now().millisecondsSinceEpoch ~/ 60000}', '/cards/commit', body: {'kind': kind.name, 'style': st});
      return CardCost((m['via'] as String?) ?? 'coins', ((m['paid'] ?? m['coins']) as num?)?.toInt() ?? 0);
    } on ApiException catch (e) {
      if (e.isInsufficientCoins) {
        int balance = 0;
        try {
          balance = (await WalletApi.instance.wallet()).totalCoins;
        } catch (_) {}
        throw CardInsufficient(e.coins ?? 0, balance);
      }
      if (e.code == 'cards_off') throw CardsDisabled();
      rethrow;
    }
  }

  /// Pass Studio : retourne la date de fin (ms).
  static Future<int> buyPass() async {
    try {
      await WalletApi.instance.buy('card_pass');
      final q = await quote();
      return q.passUntil;
    } on ApiException catch (e) {
      if (e.isInsufficientCoins) {
        int balance = 0;
        try {
          balance = (await WalletApi.instance.wallet()).totalCoins;
        } catch (_) {}
        throw CardInsufficient(e.coins ?? 0, balance);
      }
      rethrow;
    }
  }

  /// Envoie à l'administration la vraie cause d'une erreur de création de carte (sans bloquer ni échouer).
  static Future<void> report(String where, Object error, StackTrace? stack, {String? style, String? format, bool hasMedia = false, bool vote = false}) async {
    try {
      await ApiGateway.instance.client.post('/cards/errors', body: {
        'where': where,
        'type': error.runtimeType.toString(),
        'msg': error.toString(),
        'stack': stack?.toString().split('\n').take(5).join(' | ') ?? '',
        'os': '${defaultTargetPlatform.name}${kIsWeb ? ' web' : ''}',
        'style': style ?? '',
        'format': format ?? '',
      });
    } catch (_) {/* le rapport ne doit jamais gêner */}
  }
}
