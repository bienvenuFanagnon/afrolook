import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../services/ad_service.dart';
import 'base_ad_widget.dart';

// rewarded_ad_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../services/ad_service.dart';
import 'base_ad_widget.dart';

class RewardedAdWidget extends BaseAdWidget {
  final void Function(RewardItem reward) onUserEarnedReward;
  final void Function()? onAdDismissed;
  final Widget? child;

  const RewardedAdWidget({
    Key? key,
    required this.onUserEarnedReward,
    this.onAdDismissed,
    this.child,
    bool forceShow = false,
  }) : super(key: key, forceShow: forceShow);

  @override
  RewardedAdWidgetState createState() => RewardedAdWidgetState();

  static void showAd(GlobalKey<RewardedAdWidgetState> key) {
    key.currentState?.showAd();
  }
}

class RewardedAdWidgetState extends BaseAdWidgetState<RewardedAdWidget> {
  RewardedAd? _rewardedAd;
  bool _isAdReady = false;
  Completer<void>? _adReadyCompleter;
  Future<bool> isAdReady() async {
    return _isAdReady;
  }
  @override
  void loadAd() {
    _adReadyCompleter = Completer<void>();
    print('📢 [REWARDED] Chargement...');
    RewardedAd.load(
      adUnitId: AdService.rewardedAdId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          print('✅ [REWARDED] Chargé');
          _rewardedAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              widget.onAdDismissed?.call();
              _loadNextAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              _loadNextAd();
            },
          );
          setState(() {
            _isAdReady = true;
            setLoaded();
          });
          _adReadyCompleter?.complete();
        },
        onAdFailedToLoad: (error) {
          setError(error.message);
          _adReadyCompleter?.completeError(error);
        },
      ),
    );
  }

  void _loadNextAd() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    setState(() => _isAdReady = false);
    loadAd();
  }

  Future<bool> waitForAdReady({Duration timeout = const Duration(seconds: 10)}) async {
    if (_isAdReady) return true;
    try {
      await _adReadyCompleter?.future.timeout(timeout);
      return _isAdReady;
    } catch (e) {
      return false;
    }
  }

  void showAd() async {
    if (_isAdReady && _rewardedAd != null) {
      _rewardedAd!.setImmersiveMode(true);
      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          widget.onUserEarnedReward(reward);
        },
      );
    } else {
      bool ready = await waitForAdReady();
      if (ready && _rewardedAd != null) {
        _rewardedAd!.setImmersiveMode(true);
        _rewardedAd!.show(
          onUserEarnedReward: (ad, reward) {
            widget.onUserEarnedReward(reward);
          },
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Publicité non disponible, réessayez')),
          );
        }
      }
    }
  }

  @override
  void disposeAd() {
    _rewardedAd?.dispose();
  }

  @override
  Widget buildAdWidget() {
    if (widget.child != null) {
      return GestureDetector(
        onTap: showAd,
        child: widget.child,
      );
    }
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
