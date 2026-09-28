import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../l10n/tr.dart';

/// Affichage de l'argent dans la devise du pays de l'utilisateur.
///
/// Tous les montants restent enregistrés en FCFA (XOF) sur le serveur ; seul
/// l'affichage est converti. Les taux (1 XOF = x devise) sont lus dans
/// `AppConfig/exchangeRates`, mis à jour chaque jour par la Cloud Function
/// `updateExchangeRates`. En attendant (ou hors ligne), des taux de repli
/// approximatifs sont utilisés. XOF et XAF valent tous deux 1/655,957 €.
class CurrencyService extends ChangeNotifier {
  CurrencyService._();
  static final CurrencyService instance = CurrencyService._();

  /// Taux de repli (1 XOF = x devise), à peu près à jour de septembre 2026.
  static const Map<String, double> _fallback = {
    'XOF': 1, 'XAF': 1, 'EUR': 0.0015245, 'USD': 0.00178, 'GBP': 0.00131, 'CHF': 0.00142,
    'CAD': 0.00245, 'MXN': 0.0331, 'BRL': 0.0098, 'ARS': 2.35, 'COP': 7.1, 'PEN': 0.0066, 'CLP': 1.68,
    'NGN': 2.7, 'GHS': 0.021, 'KES': 0.23, 'ZAR': 0.032, 'MAD': 0.0163, 'DZD': 0.237, 'TND': 0.0053,
    'EGP': 0.086, 'GNF': 15.4, 'CDF': 5.1, 'RWF': 2.5, 'UGX': 6.5, 'TZS': 4.6, 'ETB': 0.25, 'MGA': 8.0,
    'MRU': 0.071, 'CVE': 0.168, 'GMD': 0.13, 'SLE': 0.041, 'LRD': 0.35, 'AOA': 1.64, 'MZN': 0.114,
    'ZMW': 0.047, 'BWP': 0.024, 'NAD': 0.032, 'MUR': 0.082, 'SCR': 0.025, 'BIF': 5.3, 'DJF': 0.316,
    'KMF': 0.75, 'SDG': 1.07, 'SOS': 1.02, 'ERN': 0.0267, 'LSL': 0.032, 'SZL': 0.032, 'MWK': 3.1,
    'LYD': 0.0097, 'SSP': 2.3, 'STN': 0.0374, 'ZWL': 0.57,
    'SEK': 0.0167, 'NOK': 0.0178, 'DKK': 0.01137, 'PLN': 0.0065, 'CZK': 0.0383, 'HUF': 0.61,
    'RON': 0.0077, 'UAH': 0.074, 'RUB': 0.145, 'TRY': 0.072, 'HTG': 0.233, 'DOP': 0.108, 'JMD': 0.28,
    'CUP': 0.043, 'VES': 0.09, 'INR': 0.153, 'IDR': 29.0, 'PHP': 0.102, 'VND': 46.0, 'THB': 0.058,
    'MYR': 0.0076, 'SGD': 0.00229, 'JPY': 0.265, 'KRW': 2.45, 'CNY': 0.0127, 'PKR': 0.5, 'BDT': 0.215,
    'SAR': 0.00668, 'AED': 0.00654, 'QAR': 0.00648, 'KWD': 0.000545, 'LBP': 159.0, 'JOD': 0.00126,
    'AUD': 0.00268, 'NZD': 0.00298,
  };

  /// Devise de chaque pays (code ISO du pays → code ISO de la devise).
  static const Map<String, String> currencyByCountry = {
    // Zone franc CFA (XOF / XAF)
    'BJ': 'XOF', 'BF': 'XOF', 'CI': 'XOF', 'GW': 'XOF', 'ML': 'XOF', 'NE': 'XOF', 'SN': 'XOF', 'TG': 'XOF',
    'CM': 'XAF', 'CF': 'XAF', 'CG': 'XAF', 'GA': 'XAF', 'GQ': 'XAF', 'TD': 'XAF',
    // Reste de l'Afrique
    'NG': 'NGN', 'GH': 'GHS', 'KE': 'KES', 'ZA': 'ZAR', 'MA': 'MAD', 'DZ': 'DZD', 'TN': 'TND', 'EG': 'EGP',
    'GN': 'GNF', 'CD': 'CDF', 'RW': 'RWF', 'UG': 'UGX', 'TZ': 'TZS', 'ET': 'ETB', 'MG': 'MGA', 'MR': 'MRU',
    'CV': 'CVE', 'GM': 'GMD', 'SL': 'SLE', 'LR': 'LRD', 'AO': 'AOA', 'MZ': 'MZN', 'ZM': 'ZMW', 'BW': 'BWP',
    'NA': 'NAD', 'MU': 'MUR', 'SC': 'SCR', 'BI': 'BIF', 'DJ': 'DJF', 'KM': 'KMF', 'SD': 'SDG', 'SO': 'SOS',
    'ER': 'ERN', 'LS': 'LSL', 'SZ': 'SZL', 'MW': 'MWK', 'LY': 'LYD', 'SS': 'SSP', 'ST': 'STN', 'ZW': 'USD',
    // Europe
    'FR': 'EUR', 'BE': 'EUR', 'LU': 'EUR', 'DE': 'EUR', 'IE': 'EUR', 'IT': 'EUR', 'ES': 'EUR', 'PT': 'EUR',
    'NL': 'EUR', 'AT': 'EUR', 'FI': 'EUR', 'GR': 'EUR', 'GP': 'EUR', 'MQ': 'EUR', 'GF': 'EUR', 'RE': 'EUR',
    'YT': 'EUR', 'CH': 'CHF', 'GB': 'GBP', 'SE': 'SEK', 'NO': 'NOK', 'DK': 'DKK', 'PL': 'PLN', 'CZ': 'CZK',
    'HU': 'HUF', 'RO': 'RON', 'UA': 'UAH', 'RU': 'RUB', 'TR': 'TRY',
    // Amériques
    'US': 'USD', 'CA': 'CAD', 'MX': 'MXN', 'HT': 'HTG', 'DO': 'DOP', 'JM': 'JMD', 'CU': 'CUP', 'BR': 'BRL',
    'AR': 'ARS', 'CO': 'COP', 'PE': 'PEN', 'CL': 'CLP', 'VE': 'VES', 'EC': 'USD',
    // Asie, Moyen-Orient, Océanie
    'IN': 'INR', 'ID': 'IDR', 'PH': 'PHP', 'VN': 'VND', 'TH': 'THB', 'MY': 'MYR', 'SG': 'SGD', 'JP': 'JPY',
    'KR': 'KRW', 'CN': 'CNY', 'PK': 'PKR', 'BD': 'BDT', 'SA': 'SAR', 'AE': 'AED', 'QA': 'QAR', 'KW': 'KWD',
    'LB': 'LBP', 'JO': 'JOD', 'AU': 'AUD', 'NZ': 'NZD',
  };

  /// Devises sans décimales à l'affichage (montants élevés).
  static const _noDecimals = {
    'XOF', 'XAF', 'JPY', 'KRW', 'VND', 'IDR', 'CLP', 'COP', 'UGX', 'RWF', 'GNF', 'MGA', 'BIF', 'KMF',
    'DJF', 'CDF', 'TZS', 'NGN', 'LBP', 'HUF', 'ARS', 'SOS', 'SLE', 'LRD', 'MWK', 'PKR', 'INR', 'BDT',
  };

  static const _symbols = {
    'XOF': 'FCFA', 'XAF': 'FCFA', 'EUR': '€', 'USD': r'$', 'GBP': '£', 'CHF': 'CHF', 'CAD': r'$ CA',
    'JPY': '¥', 'CNY': '¥', 'INR': '₹', 'NGN': '₦', 'GHS': '₵', 'BRL': r'R$', 'KRW': '₩', 'TRY': '₺',
    'RUB': '₽', 'UAH': '₴', 'PHP': '₱', 'VND': '₫', 'THB': '฿', 'AUD': r'$ AU', 'NZD': r'$ NZ',
    'MXN': r'$ MX', 'ZAR': 'R', 'KES': 'KSh', 'MAD': 'DH', 'PLN': 'zł', 'ILS': '₪',
  };

  Map<String, double> _rates = Map.of(_fallback);
  String _currency = 'XOF';
  StreamSubscription? _sub;
  bool _live = false;

  /// Devise affichée (ex. XOF, EUR, USD).
  String get currency => _currency;

  /// Vrai si l'utilisateur est dans la zone FCFA.
  bool get isFcfa => _currency == 'XOF' || _currency == 'XAF';

  /// Vrai quand les taux du jour ont été chargés depuis le serveur.
  bool get hasLiveRates => _live;

  static String currencyFor(String? countryCode) =>
      currencyByCountry[(countryCode ?? '').toUpperCase()] ?? 'USD';

  /// Pays du téléphone (utilisé avant la connexion).
  static String? deviceCountry() => PlatformDispatcher.instance.locale.countryCode;

  /// Choisit la devise à partir du pays (profil, sinon téléphone).
  void setCountry(String? countryCode) {
    final cc = (countryCode == null || countryCode.isEmpty) ? deviceCountry() : countryCode;
    final next = cc == null ? 'XOF' : currencyFor(cc);
    if (next != _currency) {
      _currency = next;
      notifyListeners();
    }
  }

  /// Écoute les taux du jour (à appeler une fois au démarrage).
  void listenRates() {
    _sub ??= FirebaseFirestore.instance.collection('AppConfig').doc('exchangeRates').snapshots().listen((doc) {
      final data = doc.data();
      final rates = data?['rates'];
      if (rates is Map) {
        final next = Map.of(_fallback);
        rates.forEach((k, v) {
          if (v is num && v > 0) next[k.toString().toUpperCase()] = v.toDouble();
        });
        next['XOF'] = 1;
        next['XAF'] = 1;
        _rates = next;
        _live = true;
        notifyListeners();
      }
    }, onError: (_) {});
  }

  double _rate(String cur) => _rates[cur] ?? _fallback[cur] ?? _fallback['USD']!;

  /// FCFA → devise de l'utilisateur.
  double fromFcfa(num fcfa, [String? cur]) => fcfa * _rate(cur ?? _currency);

  /// Devise de l'utilisateur → FCFA.
  double toFcfa(num amount, [String? cur]) => amount / _rate(cur ?? _currency);

  /// Taux appliqué (1 FCFA = x devise), à enregistrer avec une demande de retrait.
  double get rate => _rate(_currency);

  String symbol([String? cur]) => _symbols[cur ?? _currency] ?? (cur ?? _currency);

  int decimals([String? cur]) => _noDecimals.contains(cur ?? _currency) ? 0 : 2;

  /// Montant déjà exprimé dans la devise [cur] (par défaut celle de l'utilisateur).
  String fmtLocal(num amount, {String? cur}) {
    final c = cur ?? _currency;
    final d = decimals(c);
    final n = NumberFormat.decimalPatternDigits(locale: _numberLocale(), decimalDigits: d).format(amount);
    final s = symbol(c);
    // Symbole avant le montant pour $, £, ¥… ; après pour €, FCFA et les codes
    const before = {r'$', '£', '¥', '₹', '₦', r'R$', '₩', '₱', '₵'};
    return before.contains(s) ? '$s$n' : '$n $s';
  }

  /// Montant en FCFA affiché dans la devise de l'utilisateur : « 1 000 FCFA », « 1,78 $ », « 1,52 € ».
  String fmt(num fcfa) => fmtLocal(fromFcfa(fcfa));

  /// Même chose avec « ≈ » devant hors zone FCFA (montant converti, indicatif).
  String approx(num fcfa) => isFcfa ? fmt(fcfa) : '≈ ${fmt(fcfa)}';

  String _numberLocale() {
    const map = {'fr': 'fr', 'en': 'en', 'es': 'es', 'de': 'de', 'ar': 'ar', 'pt': 'pt', 'zh': 'zh', 'sw': 'sw'};
    return map[trCurrentLanguage] ?? 'fr';
  }
}

/// Raccourci : `Money.fmt(1000)` → « 1 000 FCFA » ou « 1,78 $ » selon le pays.
class Money {
  static String fmt(num fcfa) => CurrencyService.instance.fmt(fcfa);
  static String approx(num fcfa) => CurrencyService.instance.approx(fcfa);
}
