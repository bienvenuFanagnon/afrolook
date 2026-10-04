import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Réglages publicitaires lus dans Firestore (`AppConfig/ads`) : interrupteur général,
/// pourcentage d'utilisateurs, fréquences et identifiants d'emplacements AdMob.
/// Modifiables sans publier de mise à jour (voir tools/ads/set_config.js).
class AdConfig {
  AdConfig._(this._d);
  final Map<String, dynamic> _d;

  static AdConfig current = AdConfig._({});
  static DateTime? _loadedAt;

  /// Identifiants de test officiels de Google (jamais de vraie pub pendant le développement).
  static const _testIds = {
    'android': {
      'banner': 'ca-app-pub-3940256099942544/6300978111',
      'native': 'ca-app-pub-3940256099942544/2247696110',
      'interstitial': 'ca-app-pub-3940256099942544/1033173712',
      'rewarded': 'ca-app-pub-3940256099942544/5224354917',
    },
    'ios': {
      'banner': 'ca-app-pub-3940256099942544/2934735716',
      'native': 'ca-app-pub-3940256099942544/3986624511',
      'interstitial': 'ca-app-pub-3940256099942544/4411468910',
      'rewarded': 'ca-app-pub-3940256099942544/1712485313',
    },
  };

  /// Emplacements de production Android déjà créés dans AdMob (utilisés avant la période Appodeal).
  /// iPhone : à renseigner dans Firestore (`units.ios`) ; sans eux, aucune pub n'y est affichée.
  static const _defaultAndroidUnits = {
    'banner': 'ca-app-pub-4937249920200692/8649891687',
    'native': 'ca-app-pub-4937249920200692/3785411966',
    'interstitial': 'ca-app-pub-4937249920200692/4672884589',
    'rewarded': 'ca-app-pub-4937249920200692/8962511249',
  };

  static bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  static String get platform => (!kIsWeb && Platform.isIOS) ? 'ios' : 'android';

  /// Charge la configuration (au plus une fois toutes les 10 minutes).
  static Future<void> load({bool force = false}) async {
    final at = _loadedAt;
    if (!force && at != null && DateTime.now().difference(at) < const Duration(minutes: 10)) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('AppConfig').doc('ads').get();
      current = AdConfig._(doc.data() ?? {});
      _loadedAt = DateTime.now();
    } catch (_) {/* garde la configuration précédente (par défaut : pubs coupées) */}
  }

  bool _b(String k, bool def) => _d[k] is bool ? _d[k] as bool : def;
  int _i(String k, int def) => (_d[k] as num?)?.toInt() ?? def;

  /// Interrupteur général (coupé tant que la configuration n'existe pas).
  /// En mode debug : toujours activé (pubs de TEST de Google) pour vérifier que tout fonctionne.
  bool get enabled => kDebugMode || (_b('enabled', false) && _b(platform == 'ios' ? 'enabledIos' : 'enabledAndroid', true));

  /// Part des utilisateurs concernés (0–100) ; les admins sont toujours inclus.
  int get rolloutPercent => kDebugMode ? 100 : _i('rolloutPercent', 0).clamp(0, 100);

  bool get testMode => kDebugMode || _b('testMode', false);

  // Feed
  int get nativeEvery => _i('nativeEvery', 8).clamp(4, 40);
  int get nativeStartAfter => _i('nativeStartAfter', 3).clamp(1, 20);
  /// Un emplacement sur N est confié à AdMob quand une pub Afrolook existe aussi (2 = alternance 1 sur 2).
  int get admobEvery => _i('admobEvery', 2).clamp(1, 10);
  /// Sessions sans aucune pub pour un nouveau compte.
  int get freeSessions => kDebugMode ? 0 : _i('freeSessions', 3).clamp(0, 20);

  // Emplacements
  bool get detailBanner => _b('detailBanner', true);
  bool get detailMrec => _b('detailMrec', true);
  bool get commentsNative => _b('commentsNative', true);
  bool get listsNative => _b('listsNative', true);

  // Plein écran entre les vidéos
  bool get interstitialEnabled => _b('interstitialEnabled', true);
  int get interstitialEveryVideos => kDebugMode ? 2 : _i('interstitialEveryVideos', 4).clamp(2, 20);
  int get interstitialMinGapMinutes => kDebugMode ? 0 : _i('interstitialMinGapMinutes', 5).clamp(1, 60);
  int get interstitialMaxPerDay => kDebugMode ? 99 : _i('interstitialMaxPerDay', 3).clamp(0, 20);
  int get interstitialWarmupMinutes => kDebugMode ? 0 : _i('interstitialWarmupMinutes', 5).clamp(0, 30);

  // Récompensée (page Récompenses)
  bool get rewardsEnabled => _b('rewardsEnabled', true);
  /// Vérification côté serveur d'AdMob (SSV) : à activer quand l'URL de rappel est saisie dans AdMob.
  bool get ssvEnabled => _b('ssvEnabled', false);
  bool get rewardedEnabled => _b('rewardedEnabled', true);
  int get rewardedMaxPerDay => _i('rewardedMaxPerDay', 2).clamp(0, 10);

  /// Identifiant d'emplacement : test en développement, sinon Firestore (`units.<plateforme>.<type>`),
  /// sinon (Android) ceux déjà créés. Vide = type indisponible.
  String unit(String type) {
    if (testMode) return _testIds[platform]![type] ?? '';
    final units = _d['units'];
    if (units is Map && units[platform] is Map) {
      final v = (units[platform] as Map)[type];
      if (v is String && v.isNotEmpty) return v;
    }
    return platform == 'android' ? (_defaultAndroidUnits[type] ?? '') : '';
  }
}
