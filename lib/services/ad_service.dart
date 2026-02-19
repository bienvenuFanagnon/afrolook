import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AdService {
  // Singleton
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // Configuration
  static bool get isWeb => kIsWeb;
  static bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  // Mode TEST/PROD
  static bool _useTestAds = true; // Mettre à false pour la production
// ✅ NATIVE AD
  static String get _testNativeId => Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/2247696110'   // Native Ad TEST Android
      : 'ca-app-pub-3940256099942544/3986624511';  // Native Ad TEST iOS
  // IDs de TEST (officiels Google)
  static String get _testBannerId => Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/6300978111'
      : 'ca-app-pub-3940256099942544/2934735716';

  static String get _testInterstitialId => Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/1033173712'
      : 'ca-app-pub-3940256099942544/4411468910';

  static String get _testRewardedId => Platform.isAndroid
      ? 'ca-app-pub-3940256099942544/5224354917'
      : 'ca-app-pub-3940256099942544/1712485313';

  // VOS IDs DE PRODUCTION (à remplacer par les vôtres)
  static const String _prodBannerId = 'ca-app-pub-4937249920200692/7937737015';
  static const String _prodNativeAdId = 'ca-app-pub-4937249920200692/6034871678';
  static const String _prodInterstitialId = 'ca-app-pub-4937249920200692/XXXXXXXXXX'; // À créer
  static const String _prodRewardedId = 'ca-app-pub-4937249920200692/8962511249'; // À créer

  // Getters publics
  static String get bannerAdId => _useTestAds ? _testBannerId : _prodBannerId;
  static String get nativeAdId => _useTestAds ? _testNativeId : _prodNativeAdId;
  static String get interstitialAdId => _useTestAds ? _testInterstitialId : _prodInterstitialId;
  static String get rewardedAdId => _useTestAds ? _testRewardedId : _prodRewardedId;

  // Vérifier si les pubs sont supportées sur cette plateforme
  static bool get adsSupported => isMobile;

  // Pour le débogage
  static String get currentMode => _useTestAds ? 'TEST' : 'PRODUCTION';

  // Permettre de changer le mode (utile pour les tests)
  static void setMode(bool useTest) {
    _useTestAds = useTest;
    print('📢 Mode publicitaire: ${useTest ? 'TEST' : 'PRODUCTION'}');
  }
}