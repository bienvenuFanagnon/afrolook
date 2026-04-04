import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../../../providers/authProvider.dart';
import '../../../services/ad_service.dart';
import '../../../services/utils/abonnement_utils.dart';
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
  InterstitialAd? _interstitialAd;
  bool _isAdReady = false;
  bool _isPremium = false;
  bool _isCheckingPremium = true;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
  }

  Future<void> _checkPremiumStatus() async {
    try {
      await Future.delayed(Duration(milliseconds: 100));

      if (mounted && context.mounted) {
        final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
        final user = authProvider.loginUserData;

        if (user != null) {
          _isPremium = AbonnementUtils.isPremiumActive(user.abonnement);
        }
      }
    } catch (e) {
      print('Erreur vérification premium: $e');
      _isPremium = false;
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingPremium = false;
        });
      }
    }
  }

  @override
  void loadAd() {
    // Si l'utilisateur est premium, ne pas charger la pub
    if (_isPremium) {
      print('📢 [INTERSTITIAL] Utilisateur Premium - Pas de publicité chargée');
      setLoaded();
      return;
    }

    print('📢 [INTERSTITIAL] Chargement ID: ${AdService.interstitialAdId}');

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
    // Si l'utilisateur est premium, ne pas afficher la pub
    if (_isPremium) {
      print('📢 [INTERSTITIAL] Utilisateur Premium - Pas de publicité affichée');
      widget.onAdDismissed?.call();
      return;
    }

    // Pendant la vérification, ne pas afficher la pub
    if (_isCheckingPremium) {
      print('📢 [INTERSTITIAL] Vérification premium en cours, pas de publicité');
      widget.onAdDismissed?.call();
      return;
    }

    if (_isAdReady && _interstitialAd != null) {
      _interstitialAd!.show();
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