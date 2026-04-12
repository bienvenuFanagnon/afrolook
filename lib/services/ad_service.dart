import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:stack_appodeal_flutter/stack_appodeal_flutter.dart';


class AdService {
  // Singleton
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  // --- CONFIGURATION ---
  // Remplace ces clés par celles de ton tableau de bord Appodeal
  static String get _appKey => Platform.isAndroid
      ? "b03ae4750807969d5c5527055739a6237c9c90795a05d492"
      : "b03ae4750807969d5c5527055739a6237c9c90795a05d492";    // Clé iOS Afrolook

  static bool _useTestAds = false; // Mettre à false pour la production

  // Getters pour le statut
  static bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  static String get currentMode => _useTestAds ? 'TEST' : 'PRODUCTION';

  /// ✅ INITIALISATION DU SDK
  /// À appeler dans le main.dart : await AdService.init();
  static Future<void> init() async {
    if (!isMobile) return;

    print('📢 [ADSERVICE] Initialisation en mode: $currentMode');

    // 1. Configuration globale avant initialisation
    await Appodeal.setTesting(_useTestAds);

    // Niveau de log : Verbose en test, None en prod pour les perfs
    await Appodeal.setLogLevel(_useTestAds
        ? Appodeal.LogLevelVerbose
        : Appodeal.LogLevelNone);

    // Mute les vidéos si le téléphone est en silencieux (Android uniquement)
    if (Platform.isAndroid) {
      await Appodeal.muteVideosIfCallsMuted(true);
    }

    // 2. Définition des types de publicités à supporter
    List<AppodealAdType> adTypes = [
      AppodealAdType.Banner,
      AppodealAdType.Interstitial,
      AppodealAdType.RewardedVideo,
      AppodealAdType.MREC, // Important pour Afrolook
    ];
    // Appodeal.setCustomFilter("consent_zone", true);
    // 3. Lancement de l'initialisation


    Appodeal.initialize(
      appKey: _appKey,
      adTypes: adTypes,
      onInitializationFinished: (errors) async {
        if (errors == null || errors.isEmpty) {
          print("✅ [ADSERVICE] Initialisation réussie");
          // ✅ Cache APRÈS init
          await Appodeal.cache(AppodealAdType.MREC);
          // await Appodeal.cache(AppodealAdType.Banner);
        } else {
          print("⚠️ [ADSERVICE] Nombre d'erreurs: ${errors.length}");
          for (var error in errors) {
            // 1. Affiche le nom de l'erreur (ex: SdkConfigurationError)
            // print("❌ Type: ${error.name}");

            // 2. Affiche la description détaillée fournie par le SDK
            print("📝 [ADSERVICE] Description: ${error.description}");

            // 3. Tente de voir le message natif complet
            print("🔍 [ADSERVICE] Détails complets: ${error.toString()}");
          }
        }
      },
    );
    // await Appodeal.initialize(
    //   appKey: _appKey,
    //   adTypes: adTypes,
    //   onInitializationFinished: (errors) {
    //     if (errors == null || errors.isEmpty) {
    //       print("✅ [ADSERVICE] Initialisation terminée avec succès");
    //     } else {
    //       for (var error in errors) {
    //         print("⚠️ [ADSERVICE] Erreur de hashCode: ${error.hashCode}");
    //         print("⚠️ [ADSERVICE] Message: ${error.description}");
    //         print("⚠️ [ADSERVICE] Erreur initialisation: ${error.description}");
    //       }
    //     }
    //   },
    // );
  }

  /// ✅ CHANGER LE MODE (TEST/PROD)
  static void setMode(bool useTest) {
    _useTestAds = useTest;
    Appodeal.setTesting(useTest);
    print('📢 [ADSERVICE] Mode publicitaire changé: $currentMode');
  }

  /// ✅ OUTILS DE DIAGNOSTIC
  static void showTestScreen() {
    if (isMobile) {
      Appodeal.setTesting(true); // Assure-toi d'être en mode test
// Dans les versions 3.x, le diagnostic est souvent lié à l'initialisation verbose
// Pour forcer l'affichage des outils de debug Appodeal :
      Appodeal.show(AppodealAdType.MREC);
    }
  }
}


// class AdService {
//   // Singleton
//   static final AdService _instance = AdService._internal();
//   factory AdService() => _instance;
//   AdService._internal();
//
//   // Configuration
//   static bool get isWeb => kIsWeb;
//   static bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
//
//   // Mode TEST/PROD
//   static bool _useTestAds = true; // Mettre à false pour la production
// // ✅ NATIVE AD
//   static String get _testNativeId => Platform.isAndroid
//       ? 'ca-app-pub-3940256099942544/2247696110'   // Native Ad TEST Android
//       : 'ca-app-pub-3940256099942544/3986624511';  // Native Ad TEST iOS
//   // IDs de TEST (officiels Google)
//   static String get _testBannerId => Platform.isAndroid
//       ? 'ca-app-pub-3940256099942544/6300978111'
//       : 'ca-app-pub-3940256099942544/2934735716';
//
//   static String get _testInterstitialId => Platform.isAndroid
//       ? 'ca-app-pub-3940256099942544/1033173712'
//       : 'ca-app-pub-3940256099942544/4411468910';
//
//   static String get _testRewardedId => Platform.isAndroid
//       ? 'ca-app-pub-3940256099942544/5224354917'
//       : 'ca-app-pub-3940256099942544/1712485313';
//
//   // VOS IDs DE PRODUCTION (à remplacer par les vôtres)
//   // static const String _prodBannerId = 'ca-app-pub-4937249920200692/7937737015';enchere
//   static const String _prodBannerId = 'ca-app-pub-4937249920200692/8649891687'; //standardd
//   // static const String _prodNativeAdId = 'ca-app-pub-4937249920200692/6034871678';//enchere
//   static const String _prodNativeAdId = 'ca-app-pub-4937249920200692/3785411966';
//   // static const String _prodInterstitialId = 'ca-app-pub-4937249920200692/8828573827'; // À créer enchere
//   static const String _prodInterstitialId = 'ca-app-pub-4937249920200692/4672884589'; // À créer
//   static const String _prodRewardedId = 'ca-app-pub-4937249920200692/8962511249'; // À créer
//
//   // Getters publics
//   static String get bannerAdId => _useTestAds ? _testBannerId : _prodBannerId;
//   static String get nativeAdId => _useTestAds ? _testNativeId : _prodNativeAdId;
//   static String get interstitialAdId => _useTestAds ? _testInterstitialId : _prodInterstitialId;
//   static String get rewardedAdId => _useTestAds ? _testRewardedId : _prodRewardedId;
//
//   // Vérifier si les pubs sont supportées sur cette plateforme
//   static bool get adsSupported => isMobile;
//
//   // Pour le débogage
//   static String get currentMode => _useTestAds ? 'TEST' : 'PRODUCTION';
//
//   // Permettre de changer le mode (utile pour les tests)
//   static void setMode(bool useTest) {
//     _useTestAds = useTest;
//     print('📢 Mode publicitaire: ${useTest ? 'TEST' : 'PRODUCTION'}');
//   }
// }