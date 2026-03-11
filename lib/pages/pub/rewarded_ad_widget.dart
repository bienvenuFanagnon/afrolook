import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../services/ad_service.dart';
import 'base_ad_widget.dart';

class RewardedAdWidget extends BaseAdWidget {
  final void Function(RewardItem reward) onUserEarnedReward;
  final void Function()? onAdDismissed;
  final Widget? child; // Widget déclencheur (bouton)

  const RewardedAdWidget({
    Key? key,
    required this.onUserEarnedReward,
    this.onAdDismissed,
    this.child,
    bool forceShow = false,
  }) : super(key: key, forceShow: forceShow);

  @override
  RewardedAdWidgetState createState() => RewardedAdWidgetState();


  // ✅ AJOUTEZ CETTE MÉTHODE STATIQUE
  static void showAd(GlobalKey<RewardedAdWidgetState> key) {
    key.currentState?.showAd();
  }
}

class RewardedAdWidgetState extends BaseAdWidgetState<RewardedAdWidget> {
  RewardedAd? _rewardedAd;
  bool _isAdReady = false;

  @override
  void loadAd() {
    print('📢 [REWARDED] Chargement avec ID: ${AdService.rewardedAdId} (${AdService.currentMode})');

    RewardedAd.load(
      adUnitId: AdService.rewardedAdId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          print('✅ [REWARDED] Chargé avec succès');
          _rewardedAd = ad;

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              print('🔄 [REWARDED] Fermé');
              widget.onAdDismissed?.call();
              _loadNextAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              print('❌ [REWARDED] Échec affichage: $error');
              _loadNextAd();
            },
          );

          setState(() {
            _isAdReady = true;
            setLoaded();
          });
        },
        onAdFailedToLoad: (error) {
          print('❌ [REWARDED] Erreur chargement: $error');
          setError(error.message);
        },
      ),
    );
  }

  void _loadNextAd() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    setState(() => _isAdReady = false);
    loadAd(); // Recharger
  }

  void showAd() {
    if (_isAdReady && _rewardedAd != null) {
      _rewardedAd!.setImmersiveMode(true);
      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          print('🎁 [REWARDED] Récompense gagnée: ${reward.amount} ${reward.type}');
          widget.onUserEarnedReward(reward);
        },
      );
    } else {
      // Si pas prête, on peut afficher un message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publicité pas encore prête')),
      );
    }
  }

  @override
  void disposeAd() {
    _rewardedAd?.dispose();
  }

  @override
  Widget buildAdWidget() {
    // Retourner le bouton déclencheur ou un bouton par défaut
    if (widget.child != null) {
      return GestureDetector(
        onTap: showAd,
        child: widget.child,
      );
    }

    // Bouton par défaut
    return ElevatedButton(
      onPressed: showAd,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      child: const Text('🎁 Gagner une récompense'),
    );
  }
}