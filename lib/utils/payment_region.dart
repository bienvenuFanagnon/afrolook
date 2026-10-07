import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/model_data.dart';
import 'platform_guard.dart';

/// Moyens de paiement selon le pays de l'utilisateur.
/// - Google Play (Android) : tout le monde.
/// - Mobile Money : uniquement les utilisateurs d'un pays africain ; pays inconnu = Google Play seul.
/// - iPhone : App Store seul (règle Apple), jamais de Mobile Money.
class PaymentRegion {
  PaymentRegion._();

  /// Codes ISO 3166-1 alpha-2 des 54 pays africains.
  static const Set<String> africanCountries = {
    'DZ', 'AO', 'BJ', 'BW', 'BF', 'BI', 'CV', 'CM', 'CF', 'TD', 'KM', 'CG', 'CD', 'CI', 'DJ', 'EG', 'GQ', 'ER',
    'SZ', 'ET', 'GA', 'GM', 'GH', 'GN', 'GW', 'KE', 'LS', 'LR', 'LY', 'MG', 'MW', 'ML', 'MR', 'MU', 'MA', 'MZ',
    'NA', 'NE', 'NG', 'RW', 'ST', 'SN', 'SC', 'SL', 'SO', 'ZA', 'SS', 'SD', 'TZ', 'TG', 'TN', 'UG', 'ZM', 'ZW',
  };

  /// Pays du profil (code à 2 lettres, en majuscules), ou null s'il est inconnu.
  static String? countryOf(UserData? user) {
    final raw = user?.countryData?['countryCode'] ?? user?.userPays?.id;
    final code = raw?.trim().toUpperCase();
    return (code != null && code.length == 2) ? code : null;
  }

  static bool isAfrican(UserData? user) {
    final code = countryOf(user);
    return code != null && africanCountries.contains(code);
  }

  /// Sur Android : Mobile Money proposé seulement aux utilisateurs d'un pays africain.
  static bool canUseMobileMoney(UserData? user) => !kIsAppleStore && isAfrican(user);

  /// Google Play Billing : Android uniquement (le web et iOS n'en ont pas).
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
}
