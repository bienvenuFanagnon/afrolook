import 'dart:async';
import 'package:flutter/material.dart';
import 'package:stack_appodeal_flutter/stack_appodeal_flutter.dart'; // ✅ SDK Appodeal

class RewardedAdWidget extends StatefulWidget {
  final void Function(double amount, String name) onUserEarnedReward;
  final void Function()? onAdDismissed;
  final Widget? child;

  const RewardedAdWidget({
    Key? key,
    required this.onUserEarnedReward,
    this.onAdDismissed,
    this.child,
  }) : super(key: key);

  @override
  RewardedAdWidgetState createState() => RewardedAdWidgetState();

  // Méthode statique pour déclencher l'affichage via une GlobalKey
  static void showAd(GlobalKey<RewardedAdWidgetState> key) {
    key.currentState?.showAd();
  }
}

class RewardedAdWidgetState extends State<RewardedAdWidget> {
  bool _isAdReady = false;

  @override
  void initState() {
    super.initState();
    _initCallbacks();
    _checkInitialAvailability();
  }

  // ✅ Configuration des Callbacks (Remplace FullScreenContentCallback d'AdMob)
  void _initCallbacks() {
    Appodeal.setRewardedVideoCallbacks(
      onRewardedVideoLoaded: (isPrecache) {
        if (mounted) setState(() => _isAdReady = true);
        print('✅ [APPODEAL REWARDED] Pub prête');
      },
      onRewardedVideoFailedToLoad: () {
        if (mounted) setState(() => _isAdReady = false);
        print('❌ [APPODEAL REWARDED] Échec chargement');
      },
      onRewardedVideoFinished: (double amount, String name) {
        // L'utilisateur a terminé la vidéo
        widget.onUserEarnedReward(amount, name);
      },
      onRewardedVideoClosed: (isFinished) {
        // La pub est fermée
        widget.onAdDismissed?.call();
        // Optionnel : On vérifie si la suivante est déjà prête
        _checkInitialAvailability();
      },
    );
  }

  Future<void> _checkInitialAvailability() async {
    bool isLoaded = await Appodeal.isLoaded(AppodealAdType.RewardedVideo);
    if (mounted) {
      setState(() => _isAdReady = isLoaded);
    }
  }

  // ✅ Méthode pour afficher la publicité
  Future<void> showAd() async {
    bool isLoaded = await Appodeal.isLoaded(AppodealAdType.RewardedVideo);

    if (isLoaded) {
      await Appodeal.show(AppodealAdType.RewardedVideo);
    } else {
      // Si pas encore prêt, on peut tenter d'attendre ou prévenir l'utilisateur
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vidéo en cours de chargement, réessayez dans un instant...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si un enfant est fourni (ex: un bouton custom), on l'entoure d'un GestureDetector
    if (widget.child != null) {
      return GestureDetector(
        onTap: showAd,
        child: Opacity(
          opacity: _isAdReady ? 1.0 : 0.5, // Optionnel : griser si pas prêt
          child: widget.child,
        ),
      );
    }

    // Sinon, bouton par défaut
    return ElevatedButton.icon(
      onPressed: _isAdReady ? showAd : null,
      icon: const Icon(Icons.card_giftcard),
      label: Text(_isAdReady ? '🎁 Gagner une récompense' : 'Chargement...'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey,
      ),
    );
  }
}


// import 'package:flutter/material.dart';
//
// import '../../services/ad_service.dart';
// import 'base_ad_widget.dart';
//
// // rewarded_ad_widget.dart
// import 'dart:async';
// import 'package:flutter/material.dart';
//
// import '../../services/ad_service.dart';
// import 'base_ad_widget.dart';
//
// class RewardedAdWidget extends BaseAdWidget {
//   final void Function(RewardItem reward) onUserEarnedReward;
//   final void Function()? onAdDismissed;
//   final Widget? child;
//
//   const RewardedAdWidget({
//     Key? key,
//     required this.onUserEarnedReward,
//     this.onAdDismissed,
//     this.child,
//     bool forceShow = false,
//   }) : super(key: key, forceShow: forceShow);
//
//   @override
//   RewardedAdWidgetState createState() => RewardedAdWidgetState();
//
//   static void showAd(GlobalKey<RewardedAdWidgetState> key) {
//     key.currentState?.showAd();
//   }
// }
//
// class RewardedAdWidgetState extends BaseAdWidgetState<RewardedAdWidget> {
//   RewardedAd? _rewardedAd;
//   bool _isAdReady = false;
//   Completer<void>? _adReadyCompleter;
//   Future<bool> isAdReady() async {
//     return _isAdReady;
//   }
//   @override
//   void loadAd() {
//     _adReadyCompleter = Completer<void>();
//     print('📢 [REWARDED] Chargement...');
//     RewardedAd.load(
//       adUnitId: AdService.rewardedAdId,
//       request: const AdRequest(),
//       rewardedAdLoadCallback: RewardedAdLoadCallback(
//         onAdLoaded: (ad) {
//           print('✅ [REWARDED] Chargé');
//           _rewardedAd = ad;
//           ad.fullScreenContentCallback = FullScreenContentCallback(
//             onAdDismissedFullScreenContent: (ad) {
//               widget.onAdDismissed?.call();
//               _loadNextAd();
//             },
//             onAdFailedToShowFullScreenContent: (ad, error) {
//               _loadNextAd();
//             },
//           );
//           setState(() {
//             _isAdReady = true;
//             setLoaded();
//           });
//           _adReadyCompleter?.complete();
//         },
//         onAdFailedToLoad: (error) {
//           setError(error.message);
//           _adReadyCompleter?.completeError(error);
//         },
//       ),
//     );
//   }
//
//   void _loadNextAd() {
//     _rewardedAd?.dispose();
//     _rewardedAd = null;
//     setState(() => _isAdReady = false);
//     loadAd();
//   }
//
//   Future<bool> waitForAdReady({Duration timeout = const Duration(seconds: 10)}) async {
//     if (_isAdReady) return true;
//     try {
//       await _adReadyCompleter?.future.timeout(timeout);
//       return _isAdReady;
//     } catch (e) {
//       return false;
//     }
//   }
//
//   void showAd() async {
//     if (_isAdReady && _rewardedAd != null) {
//       _rewardedAd!.setImmersiveMode(true);
//       _rewardedAd!.show(
//         onUserEarnedReward: (ad, reward) {
//           widget.onUserEarnedReward(reward);
//         },
//       );
//     } else {
//       bool ready = await waitForAdReady();
//       if (ready && _rewardedAd != null) {
//         _rewardedAd!.setImmersiveMode(true);
//         _rewardedAd!.show(
//           onUserEarnedReward: (ad, reward) {
//             widget.onUserEarnedReward(reward);
//           },
//         );
//       } else {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('Publicité non disponible, réessayez')),
//           );
//         }
//       }
//     }
//   }
//
//   @override
//   void disposeAd() {
//     _rewardedAd?.dispose();
//   }
//
//   @override
//   Widget buildAdWidget() {
//     if (widget.child != null) {
//       return GestureDetector(
//         onTap: showAd,
//         child: widget.child,
//       );
//     }
//     return ElevatedButton(
//       onPressed: showAd,
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Colors.green,
//         foregroundColor: Colors.white,
//       ),
//       child: const Text('🎁 Gagner une récompense'),
//     );
//   }
// }
