import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:stack_appodeal_flutter/stack_appodeal_flutter.dart';

import 'ad_config.dart';
import 'ad_revenue_tracker.dart';

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

  /// Vraies pubs partout, même en développement (décision du propriétaire, 27/10/2026). Ne jamais cliquer sur ses propres pubs.
  static const bool useTestAds = false;

  /// Vrai quand le SDK est initialisé et prêt à servir des bannières.
  static final ValueNotifier<bool> ready = ValueNotifier(false);

  /// Compteurs d'événements des bannières (utilisés par [AppodealBannerWidget] et l'écran admin).
  static final ValueNotifier<int> bannerLoaded = ValueNotifier(0);
  static final ValueNotifier<int> bannerFailed = ValueNotifier(0);
  static final ValueNotifier<int> mrecLoaded = ValueNotifier(0);
  static final ValueNotifier<int> mrecFailed = ValueNotifier(0);

  /// Dernière erreur d'initialisation ou de chargement (écran admin).
  static String? lastError;

  /// Réseau qui a servi la dernière pub (retour du SDK à chaque impression) : montre qui sert vraiment, AdMob ou un autre réseau.
  static final ValueNotifier<String> lastNetwork = ValueNotifier('aucune pub servie pour l’instant');

  /// Journal des essais manuels de l'écran admin (10 dernières lignes).
  static final ValueNotifier<List<String>> testLog = ValueNotifier(const []);

  // ── Repli des bannières ──
  // Appodeal d'abord, AdMob en direct si Appodeal ne sert rien (jamais les deux en même temps sur un emplacement). Après 3 échecs de suite,
  // les emplacements vont directement à AdMob pendant 10 minutes (pas d'attente inutile), puis Appodeal est retenté.
  static int _bannerFailStreak = 0;
  static DateTime? _skipUntil;

  static bool get skipBanners => _skipUntil != null && DateTime.now().isBefore(_skipUntil!);

  static void noteBannerResult({required bool ok}) {
    if (ok) {
      _bannerFailStreak = 0;
      _skipUntil = null;
      return;
    }
    if (++_bannerFailStreak >= 3) _skipUntil = DateTime.now().add(const Duration(minutes: 10));
  }

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
      // Plein écran et récompensée : initialisés seulement pour les essais de l'écran admin, SANS chargement automatique (aucune requête, aucune
      // pub montrée aux utilisateurs tant que l'écran admin n'a pas demandé un essai).
      Appodeal.setAutoCache(AppodealAdType.Interstitial, false);
      Appodeal.setAutoCache(AppodealAdType.RewardedVideo, false);
      Appodeal.initialize(
        appKey: key,
        adTypes: [AppodealAdType.Banner, AppodealAdType.MREC, AppodealAdType.Interstitial, AppodealAdType.RewardedVideo],
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

  static final Map<AppodealAdType, String> _outcome = {};
  static Completer<bool>? _rewardWaiter;
  static Completer<bool>? _interWaiter;

  /// Pub plein écran Appodeal, en renfort quand AdMob n'a rien de prêt : charge à la demande (3 s au plus), affiche, et appelle [onDismissed] à la fermeture.
  /// Retourne `false` si rien n'a pu être montré.
  static Future<bool> showInterstitial({VoidCallback? onDismissed}) async {
    if (!supported || !ready.value) return false;
    const type = AppodealAdType.Interstitial;
    try {
      if (!await Appodeal.isLoaded(type)) {
        _outcome.remove(type);
        Appodeal.cache(type);
        for (var i = 0; i < 6; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (await Appodeal.isLoaded(type) || _outcome[type] == 'ko') break;
        }
      }
      if (!await Appodeal.isLoaded(type)) return false;
      _interWaiter = Completer<bool>();
      final waiter = _interWaiter!;
      if (!await Appodeal.show(type)) return false;
      waiter.future.then((_) => onDismissed?.call());
      return true;
    } catch (e) {
      lastError = '$e';
      return false;
    }
  }
  static bool _rewardEarned = false;

  /// Pub récompensée Appodeal, en renfort quand AdMob n'a rien à montrer (voir RewardedAds) : charge à la demande, affiche, et retourne `true`
  /// si elle a été regardée en entier. `false` : Appodeal pas prêt, aucune pub disponible, ou abandon.
  static Future<bool> watchRewarded() async {
    if (!supported || !ready.value) return false;
    const type = AppodealAdType.RewardedVideo;
    try {
      if (!await Appodeal.isLoaded(type)) {
        _outcome.remove(type);
        Appodeal.cache(type);
        for (var i = 0; i < 20; i++) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (await Appodeal.isLoaded(type) || _outcome[type] == 'ko') break;
        }
      }
      if (!await Appodeal.isLoaded(type)) return false;
      _rewardEarned = false;
      _rewardWaiter = Completer<bool>();
      if (!await Appodeal.show(type)) return false;
      return await _rewardWaiter!.future.timeout(const Duration(minutes: 3), onTimeout: () => _rewardEarned);
    } catch (e) {
      lastError = '$e';
      return false;
    } finally {
      _rewardWaiter = null;
    }
  }

  static void _log(String line) {
    final d = DateTime.now();
    String t(int v) => v.toString().padLeft(2, '0');
    final all = [...testLog.value, '${t(d.hour)}:${t(d.minute)}:${t(d.second)}  $line'];
    testLog.value = all.length > 10 ? all.sublist(all.length - 10) : all;
  }

  /// Essai manuel (écran admin) : demande une pub plein écran ou récompensée aux réseaux d'Appodeal, l'affiche si elle arrive, et journalise
  /// chaque étape. Ne sert qu'à vérifier que la médiation répond ; aucun utilisateur n'est concerné.
  static Future<void> testFullScreen({required bool rewarded}) async {
    final type = rewarded ? AppodealAdType.RewardedVideo : AppodealAdType.Interstitial;
    final label = rewarded ? 'récompensée' : 'plein écran';
    if (!ready.value) {
      _log('$label : Appodeal n’est pas prêt (SDK non initialisé)');
      return;
    }
    _outcome.remove(type);
    try {
      if (!await Appodeal.isLoaded(type)) {
        _log('$label : demande envoyée aux réseaux…');
        Appodeal.cache(type);
      }
      for (var i = 0; i < 25; i++) {
        if (await Appodeal.isLoaded(type)) {
          final shown = await Appodeal.show(type);
          if (!shown) _log('$label : le SDK refuse l’affichage');
          return;
        }
        if (_outcome[type] == 'ko') return; // l'échec est déjà journalisé par le rappel
        await Future.delayed(const Duration(seconds: 1));
      }
      _log('$label : rien reçu après 25 s');
    } catch (e) {
      _log('$label : erreur $e');
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
    Appodeal.setAdRevenueCallbacks(
      onAdRevenueReceive: (r) {
        AdRevenueTracker.record('appodeal_${r.adType.name.toLowerCase()}', r.revenue * 1000000, r.currency);
        lastNetwork.value = '${r.networkName} (${r.adType.name}, ${r.adUnitName}) · ${r.revenue.toStringAsFixed(5)} ${r.currency}';
      },
    );
    Appodeal.setInterstitialCallbacks(
      onInterstitialLoaded: (isPrecache) => _log('plein écran : pub chargée'),
      onInterstitialFailedToLoad: () {
        _outcome[AppodealAdType.Interstitial] = 'ko';
        _log('plein écran : aucun réseau n’a rempli la demande');
      },
      onInterstitialShown: () => _log('plein écran : affiché'),
      onInterstitialShowFailed: () {
        _log('plein écran : affichage impossible');
        if (_interWaiter != null && !_interWaiter!.isCompleted) _interWaiter!.complete(false);
      },
      onInterstitialClicked: () => _log('plein écran : cliqué'),
      onInterstitialClosed: () {
        _log('plein écran : fermé');
        if (_interWaiter != null && !_interWaiter!.isCompleted) _interWaiter!.complete(true);
      },
      onInterstitialExpired: () => _log('plein écran : expiré'),
    );
    Appodeal.setRewardedVideoCallbacks(
      onRewardedVideoLoaded: (isPrecache) => _log('récompensée : pub chargée'),
      onRewardedVideoFailedToLoad: () {
        _outcome[AppodealAdType.RewardedVideo] = 'ko';
        _log('récompensée : aucun réseau n’a rempli la demande');
      },
      onRewardedVideoShown: () => _log('récompensée : affichée'),
      onRewardedVideoShowFailed: () {
        _log('récompensée : affichage impossible');
        if (_rewardWaiter != null && !_rewardWaiter!.isCompleted) _rewardWaiter!.complete(false);
      },
      onRewardedVideoClicked: () => _log('récompensée : cliquée'),
      onRewardedVideoFinished: (amount, reward) {
        _rewardEarned = true;
        _log('récompensée : terminée ($amount $reward)');
      },
      onRewardedVideoClosed: (isFinished) {
        _log('récompensée : fermée (${isFinished ? 'récompense obtenue' : 'abandonnée'})');
        if (_rewardWaiter != null && !_rewardWaiter!.isCompleted) _rewardWaiter!.complete(_rewardEarned || isFinished);
      },
      onRewardedVideoExpired: () => _log('récompensée : expirée'),
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
