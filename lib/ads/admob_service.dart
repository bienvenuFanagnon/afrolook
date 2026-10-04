import 'dart:async';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/model_data.dart';
import 'ad_config.dart';
import 'ad_gate.dart';

/// AdMob : consentement, initialisation, pub plein écran et pub récompensée.
/// Les bannières et pubs natives sont dans admob_widgets.dart.
class AdmobService {
  AdmobService._();

  /// Vrai quand le SDK est initialisé ET que le consentement permet de demander des pubs.
  static final ValueNotifier<bool> ready = ValueNotifier(false);
  static bool _started = false;

  static Future<void> init() async {
    if (_started || !AdConfig.isMobile) return;
    _started = true;
    try {
      await AdConfig.load(force: true);
      await AdGate.init();
      if (!AdConfig.current.enabled) {
        // Pubs coupées : on n'initialise rien (aucun suivi, aucune demande de consentement).
        _started = false;
        return;
      }
      await _requestConsent();
      await MobileAds.instance.updateRequestConfiguration(RequestConfiguration(
        maxAdContentRating: MaxAdContentRating.t,
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
      ));
      await MobileAds.instance.initialize();
      ready.value = await ConsentInformation.instance.canRequestAds();
    } catch (e) {
      debugPrint('[Ads] init : $e');
      _started = false;
    }
  }

  /// Message de consentement Google (Europe) puis autorisation de suivi iPhone.
  static Future<void> _requestConsent() async {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        } catch (_) {}
        if (!done.isCompleted) done.complete();
      },
      (_) {
        if (!done.isCompleted) done.complete();
      },
    );
    await done.future.timeout(const Duration(seconds: 15), onTimeout: () {});
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          await AppTrackingTransparency.trackingAuthorizationStatus == TrackingStatus.notDetermined) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (_) {}
  }

  static AdRequest request() => const AdRequest();

  // ── Pub plein écran (entre les vidéos) ────────────────────────────────────
  static InterstitialAd? _interstitial;
  static bool _loadingInterstitial = false;
  static int _videosClosed = 0;
  static DateTime? _lastInterstitial;

  static void _loadInterstitial() {
    if (_interstitial != null || _loadingInterstitial) return;
    final unit = AdConfig.current.unit('interstitial');
    if (unit.isEmpty) return;
    _loadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: unit,
      request: request(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _loadingInterstitial = false;
        },
        onAdFailedToLoad: (_) => _loadingInterstitial = false,
      ),
    );
  }

  /// À appeler quand l'utilisateur ferme la page d'une vidéo : pub plein écran toutes les N vidéos,
  /// jamais pendant les premières minutes de la session, 1 toutes les X minutes et un maximum par jour.
  static Future<void> onVideoClosed(UserData? user) async {
    final c = AdConfig.current;
    if (!c.interstitialEnabled || !AdGate.canShowType(user, 'interstitial')) return;
    _videosClosed++;
    if (_videosClosed % c.interstitialEveryVideos != 0) return;
    if (DateTime.now().difference(AdGate.sessionStart).inMinutes < c.interstitialWarmupMinutes) return;
    final last = _lastInterstitial;
    if (last != null && DateTime.now().difference(last).inMinutes < c.interstitialMinGapMinutes) return;
    if (!await _underDailyCap('ad_inter', c.interstitialMaxPerDay)) return;
    final ad = _interstitial;
    if (ad == null) {
      _loadInterstitial();
      return;
    }
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _loadInterstitial();
      },
    );
    _lastInterstitial = DateTime.now();
    await _countToday('ad_inter');
    await ad.show();
  }

  /// Affiche tout de suite une pub plein écran (appel explicite d'une page), sans les plafonds du fil.
  static Future<bool> showInterstitialNow({VoidCallback? onDismissed, VoidCallback? onFailed}) async {
    final ad = _interstitial;
    if (ad == null || !ready.value) {
      _loadInterstitial();
      onFailed?.call();
      return false;
    }
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadInterstitial();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _loadInterstitial();
        onFailed?.call();
      },
    );
    await ad.show();
    return true;
  }

  static void preloadInterstitial() => _loadInterstitial();

  /// Précharge la pub plein écran (après l'ouverture d'une vidéo, pour qu'elle soit prête à la fermeture).
  static void warmUpInterstitial(UserData? user) {
    if (AdConfig.current.interstitialEnabled && AdGate.canShowType(user, 'interstitial')) _loadInterstitial();
  }

  // ── Pub récompensée : 1 jour sans pub ────────────────────────────────────
  static RewardedAd? _rewarded;
  static bool _loadingRewarded = false;
  static final ValueNotifier<bool> rewardedReadyNotifier = ValueNotifier(false);

  static void loadRewarded() {
    if (_rewarded != null || _loadingRewarded) return;
    final unit = AdConfig.current.unit('rewarded');
    if (unit.isEmpty) return;
    _loadingRewarded = true;
    RewardedAd.load(
      adUnitId: unit,
      request: request(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _loadingRewarded = false;
          rewardedReadyNotifier.value = true;
        },
        onAdFailedToLoad: (_) => _loadingRewarded = false,
      ),
    );
  }

  static bool get rewardedReady => _rewarded != null;

  /// Affiche la pub récompensée. [onEarned] est appelé quand l'utilisateur l'a regardée en entier.
  static bool showRewarded({required VoidCallback onEarned, VoidCallback? onDismissed}) {
    final ad = _rewarded;
    if (ad == null) {
      loadRewarded();
      return false;
    }
    _rewarded = null;
    rewardedReadyNotifier.value = false;
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        loadRewarded();
        if (earned) onEarned();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        loadRewarded();
        onDismissed?.call();
      },
    );
    ad.show(onUserEarnedReward: (_, __) => earned = true);
    return true;
  }

  /// Demande au serveur d'accorder 1 jour sans pub (plafonné par jour). Retourne la fin (ms) ou null.
  static Future<int?> claimAdFreeDay() async {
    try {
      final res = await FirebaseFunctions.instance.httpsCallable('grantAdFreeDay').call();
      return (res.data is Map ? (res.data['until'] as num?)?.toInt() : null);
    } catch (_) {
      return null;
    }
  }

  // ── Compteurs journaliers ─────────────────────────────────────────────────
  static String _day() {
    final n = DateTime.now();
    return '${n.year}${n.month}${n.day}';
  }

  static Future<bool> _underDailyCap(String key, int max) async {
    try {
      final sp = await SharedPreferences.getInstance();
      if (sp.getString('${key}_day') != _day()) return max > 0;
      return (sp.getInt('${key}_n') ?? 0) < max;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _countToday(String key) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final same = sp.getString('${key}_day') == _day();
      await sp.setString('${key}_day', _day());
      await sp.setInt('${key}_n', same ? (sp.getInt('${key}_n') ?? 0) + 1 : 1);
    } catch (_) {}
  }

  /// Outil de diagnostic pour l'admin (liste des demandes et réponses AdMob).
  static void openInspector() {
    if (AdConfig.isMobile) MobileAds.instance.openAdInspector((_) {});
  }
}
