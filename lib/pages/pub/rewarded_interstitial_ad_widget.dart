import 'dart:async';
import 'package:flutter/material.dart';
import 'package:stack_appodeal_flutter/stack_appodeal_flutter.dart'; // ✅ SDK Appodeal
import 'package:provider/provider.dart';
import '../../../providers/authProvider.dart';
import '../../../services/ad_service.dart';
import '../../../services/utils/abonnement_utils.dart';

class InterstitialAdWidget extends StatefulWidget {
  final void Function()? onAdDismissed;
  final void Function()? onAdFailedToShow;

  const InterstitialAdWidget({
    Key? key,
    this.onAdDismissed,
    this.onAdFailedToShow,
  }) : super(key: key);

  @override
  InterstitialAdWidgetState createState() => InterstitialAdWidgetState();

  // Méthode statique pour appeler l'affichage depuis l'extérieur via une GlobalKey
  static void showAd(GlobalKey<InterstitialAdWidgetState> key) {
    key.currentState?.showAd();
  }
}

class InterstitialAdWidgetState extends State<InterstitialAdWidget> {
  bool _isPremium = false;
  bool _isCheckingPremium = true;

  @override
  void initState() {
    super.initState();
    _initCallbacks();
    _checkPremiumStatus();
  }

  // ✅ Configuration des Callbacks Appodeal (Remplace FullScreenContentCallback)
  void _initCallbacks() {
    Appodeal.setInterstitialCallbacks(
      onInterstitialLoaded: (isPrecache) => print('✅ [APPODEAL INTERSTITIAL] Prêt'),
      onInterstitialFailedToLoad: () => print('❌ [APPODEAL INTERSTITIAL] Échec chargement'),
      onInterstitialShown: () => print('👁️ [APPODEAL INTERSTITIAL] Affiché'),
      onInterstitialShowFailed: () {
        print('❌ [APPODEAL INTERSTITIAL] Échec affichage');
        widget.onAdFailedToShow?.call();
      },
      onInterstitialClosed: () {
        print('🚪 [APPODEAL INTERSTITIAL] Fermé');
        widget.onAdDismissed?.call();
      },
      onInterstitialClicked: () => print('🖱️ [APPODEAL INTERSTITIAL] Clic'),
    );
  }

  Future<void> _checkPremiumStatus() async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted && context.mounted) {
        final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
        final user = authProvider.loginUserData;
        if (user != null) {
          _isPremium = AbonnementUtils.isPremiumActive(user.abonnement);
        }
      }
    } catch (e) {
      _isPremium = false;
    } finally {
      if (mounted) {
        setState(() => _isCheckingPremium = false);
      }
    }
  }

  // ✅ Méthode pour afficher l'interstitiel
  Future<void> showAd() async {
    // 1. Sécurité Premium
    if (_isPremium || _isCheckingPremium) {
      print('📢 [INTERSTITIAL] Bypass (Premium ou Vérification)');
      widget.onAdDismissed?.call();
      return;
    }

    // 2. Vérification de disponibilité
    bool isLoaded = await Appodeal.isLoaded(AppodealAdType.Interstitial);

    if (isLoaded) {
      await Appodeal.show(AppodealAdType.Interstitial);
    } else {
      print('⏳ [INTERSTITIAL] Pas encore prêt, on ignore pour ne pas bloquer l\'utilisateur');
      widget.onAdDismissed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Un interstitiel ne prend pas de place dans l'UI
    return const SizedBox.shrink();
  }
}

// import 'dart:async';
// import 'package:flutter/material.dart';
//
// import 'package:provider/provider.dart';
// import '../../../providers/authProvider.dart';
// import '../../../services/ad_service.dart';
// import '../../../services/utils/abonnement_utils.dart';
// import 'base_ad_widget.dart';
//
// class InterstitialAdWidget extends BaseAdWidget {
//   final void Function()? onAdDismissed;
//   final void Function(AdError error)? onAdFailedToShow;
//
//   const InterstitialAdWidget({
//     Key? key,
//     this.onAdDismissed,
//     this.onAdFailedToShow,
//     bool forceShow = false,
//   }) : super(key: key, forceShow: forceShow);
//
//   @override
//   InterstitialAdWidgetState createState() => InterstitialAdWidgetState();
// }
//
// class InterstitialAdWidgetState extends BaseAdWidgetState<InterstitialAdWidget> {
//   InterstitialAd? _interstitialAd;
//   bool _isAdReady = false;
//   bool _isPremium = false;
//   bool _isCheckingPremium = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _checkPremiumStatus();
//   }
//
//   Future<void> _checkPremiumStatus() async {
//     try {
//       await Future.delayed(Duration(milliseconds: 100));
//
//       if (mounted && context.mounted) {
//         final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//         final user = authProvider.loginUserData;
//
//         if (user != null) {
//           _isPremium = AbonnementUtils.isPremiumActive(user.abonnement);
//         }
//       }
//     } catch (e) {
//       print('Erreur vérification premium: $e');
//       _isPremium = false;
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isCheckingPremium = false;
//         });
//       }
//     }
//   }
//
//   @override
//   void loadAd() {
//     // Si l'utilisateur est premium, ne pas charger la pub
//     if (_isPremium) {
//       print('📢 [INTERSTITIAL] Utilisateur Premium - Pas de publicité chargée');
//       setLoaded();
//       return;
//     }
//
//     print('📢 [INTERSTITIAL] Chargement ID: ${AdService.interstitialAdId}');
//
//     InterstitialAd.load(
//       adUnitId: AdService.interstitialAdId,
//       request: const AdRequest(),
//       adLoadCallback: InterstitialAdLoadCallback(
//         onAdLoaded: (ad) {
//           print('✅ [INTERSTITIAL] Ad Loaded');
//           _interstitialAd = ad;
//           _isAdReady = true;
//           setLoaded();
//
//           ad.fullScreenContentCallback = FullScreenContentCallback(
//             onAdDismissedFullScreenContent: (ad) {
//               print('🚪 [INTERSTITIAL] Ad Dismissed');
//               ad.dispose();
//               widget.onAdDismissed?.call();
//               loadAd(); // Recharger pour la prochaine fois
//             },
//             onAdFailedToShowFullScreenContent: (ad, error) {
//               print('❌ [INTERSTITIAL] Failed to show: $error');
//               ad.dispose();
//               widget.onAdFailedToShow?.call(error);
//               loadAd();
//             },
//           );
//         },
//         onAdFailedToLoad: (error) {
//           print('❌ [INTERSTITIAL] Failed to load: $error');
//           setError(error.message);
//         },
//       ),
//     );
//   }
//
//   void showAd() {
//     // Si l'utilisateur est premium, ne pas afficher la pub
//     if (_isPremium) {
//       print('📢 [INTERSTITIAL] Utilisateur Premium - Pas de publicité affichée');
//       widget.onAdDismissed?.call();
//       return;
//     }
//
//     // Pendant la vérification, ne pas afficher la pub
//     if (_isCheckingPremium) {
//       print('📢 [INTERSTITIAL] Vérification premium en cours, pas de publicité');
//       widget.onAdDismissed?.call();
//       return;
//     }
//
//     if (_isAdReady && _interstitialAd != null) {
//       _interstitialAd!.show();
//       _isAdReady = false;
//     } else {
//       print('⏳ [INTERSTITIAL] Pas encore prêt, on continue sans pub.');
//       widget.onAdDismissed?.call();
//     }
//   }
//
//   @override
//   void disposeAd() {
//     _interstitialAd?.dispose();
//   }
//
//   @override
//   Widget buildAdWidget() {
//     return const SizedBox.shrink();
//   }
// }