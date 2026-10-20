import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:stack_appodeal_flutter/stack_appodeal_flutter.dart';

import 'ad_config.dart';

/// Appodeal : médiation des bannières (AdMob est l'un des réseaux médiés ; le plein écran, la récompensée et les natives restent AdMob en direct).
///
/// - Un seul point d'initialisation, lancé APRÈS le consentement de [AdmobService] (message Google UMP, autorisation de suivi iPhone) :
///   Appodeal s'appuie sur le même consentement, la personne n'est pas interrogée deux fois.
/// - Pubs de test seulement en développement (`!kReleaseMode`) : jamais de drapeau « test » écrit en dur à true.
/// - Ne bloque jamais le lancement, ne plante jamais l'application : tout échec est gardé dans [lastError] (écran admin).
/// - Les bannières passent par Appodeal quand `AppConfig/ads.bannerProvider` vaut `appodeal` (par défaut) ; `admob` rend les bannières à
///   AdMob en direct, sans publier de mise à jour (repli). Jamais les deux sur le même emplacement.
class AppodealService {
  AppodealService._();

  /// Clés d'application Appodeal (publiques côté client). Modifiables sans mise à jour via `AppConfig/ads.appodealKeys.{android,ios}`.
  static const _defaultAndroidKey = 'b03ae4750807969d5c5527055739a6237c9c90795a05d492';
  static const _defaultIosKey = '47013088991ce1f20343b13078a4c981027aff2aa7ca05c6';

  /// Pubs de test en développement, vraies pubs en production.
  static const bool useTestAds = !kReleaseMode;

  /// Vrai quand le SDK est initialisé et prêt à servir des bannières.
  static final ValueNotifier<bool> ready = ValueNotifier(false);

  /// Compteurs d'événements des bannières (utilisés par [AppodealBannerWidget] et l'écran admin).
  static final ValueNotifier<int> bannerLoaded = ValueNotifier(0);
  static final ValueNotifier<int> bannerFailed = ValueNotifier(0);
  static final ValueNotifier<int> mrecLoaded = ValueNotifier(0);
  static final ValueNotifier<int> mrecFailed = ValueNotifier(0);

  /// Dernière erreur d'initialisation ou de chargement (écran admin).
  static String? lastError;

  static bool _started = false;

  /// Appodeal est-il utilisable sur cette plateforme ? Android : oui. iPhone : seulement une fois activé (`appodealIos`) : voir ios/APPODEAL_IOS.md.
  static bool get supported => AdConfig.isMobile && (AdConfig.platform == 'android' || AdConfig.current.appodealIos);

  /// Les bannières sont-elles confiées à Appodeal (réglage + plateforme) ?
  static bool get bannersViaAppodeal => supported && AdConfig.current.bannerProvider == 'appodeal';

  /// Les bannières sont-elles confiées à Appodeal ET le SDK est-il prêt ?
  static bool get bannersEnabled => bannersViaAppodeal && ready.value;

  static String get appKey {
    final keys = AdConfig.current.appodealKeys;
    final fromConfig = keys[AdConfig.platform];
    if (fromConfig != null && fromConfig.length >= 20) return fromConfig;
    return AdConfig.platform == 'ios' ? _defaultIosKey : _defaultAndroidKey;
  }

  /// Initialise Appodeal (sans effet si : pas mobile, bannières confiées à AdMob, déjà lancé). Appelée après le consentement.
  static Future<void> init() async {
    if (_started || !bannersViaAppodeal) return;
    final key = appKey;
    if (key.isEmpty) return;
    _started = true;
    try {
      Appodeal.setTesting(useTestAds);
      Appodeal.setLogLevel(useTestAds ? Appodeal.LogLevelVerbose : Appodeal.LogLevelNone);
      _wireCallbacks();
      Appodeal.initialize(
        appKey: key,
        // Si l'application utilisait déjà Appodeal pour d'autres formats, ils seraient ajoutés ici (une seule initialisation).
        adTypes: [AppodealAdType.Banner, AppodealAdType.MREC],
        onInitializationFinished: (errors) {
          if (errors != null && errors.isNotEmpty) {
            lastError = errors.map((e) => e.description).join(' | ');
            debugPrint('[Appodeal] initialisation : $lastError');
          }
          ready.value = true; // le SDK sert des bannières même si un réseau a signalé une erreur
        },
      );
    } catch (e) {
      lastError = '$e';
      debugPrint('[Appodeal] init : $e');
      _started = false;
    }
  }

  /// Rappels : journaux et compteurs seulement. Une erreur de pub ne bloque jamais l'écran ; le SDK gère lui-même le rafraîchissement.
  static void _wireCallbacks() {
    Appodeal.setBannerCallbacks(
      onBannerLoaded: (isPrecache) => bannerLoaded.value++,
      onBannerFailedToLoad: () {
        lastError = 'bannière : aucun réseau n’a rempli la demande';
        bannerFailed.value++;
      },
      onBannerShown: () {},
      onBannerShowFailed: () {},
      onBannerClicked: () {},
      onBannerExpired: () {},
    );
    Appodeal.setMrecCallbacks(
      onMrecLoaded: (isPrecache) => mrecLoaded.value++,
      onMrecFailedToLoad: () {
        lastError = 'grand format : aucun réseau n’a rempli la demande';
        mrecFailed.value++;
      },
      onMrecShown: () {},
      onMrecShowFailed: () {},
      onMrecClicked: () {},
      onMrecExpired: () {},
    );
  }
}
