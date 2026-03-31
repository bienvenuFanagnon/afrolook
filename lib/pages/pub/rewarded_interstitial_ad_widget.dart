import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../services/ad_service.dart';
import 'base_ad_widget.dart';

class InterstitialAdWidget extends BaseAdWidget {
  final void Function()? onAdDismissed;
  final void Function(AdError error)? onAdFailedToShow;

  const InterstitialAdWidget({
    Key? key,
    this.onAdDismissed,
    this.onAdFailedToShow,
    bool forceShow = false,
  }) : super(key: key, forceShow: forceShow);

  @override
  InterstitialAdWidgetState createState() => InterstitialAdWidgetState();
}

class InterstitialAdWidgetState extends BaseAdWidgetState<InterstitialAdWidget> {
  InterstitialAd? _interstitialAd; // CHANGEMENT ICI : InterstitialAd au lieu de Rewarded
  bool _isAdReady = false;

  @override
  void loadAd() {
    print('📢 [INTERSTITIAL] Chargement ID: ${AdService.interstitialAdId}');

    // CHANGEMENT : Utilisation de InterstitialAd.load
    InterstitialAd.load(
      adUnitId: AdService.interstitialAdId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          print('✅ [INTERSTITIAL] Ad Loaded');
          _interstitialAd = ad;
          _isAdReady = true;
          setLoaded();

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              print('🚪 [INTERSTITIAL] Ad Dismissed');
              ad.dispose();
              widget.onAdDismissed?.call();
              loadAd(); // Recharger pour la prochaine fois
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              print('❌ [INTERSTITIAL] Failed to show: $error');
              ad.dispose();
              widget.onAdFailedToShow?.call(error);
              loadAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          print('❌ [INTERSTITIAL] Failed to load: $error');
          setError(error.message);
        },
      ),
    );
  }

  void showAd() {
    if (_isAdReady && _interstitialAd != null) {
      _interstitialAd!.show(); // Pas de récompense à gérer ici
      _isAdReady = false;
    } else {
      print('⏳ [INTERSTITIAL] Pas encore prêt, on continue sans pub.');
      widget.onAdDismissed?.call();
    }
  }

  @override
  void disposeAd() {
    _interstitialAd?.dispose();
  }

  @override
  Widget buildAdWidget() {
    return const SizedBox.shrink();
  }
}