import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../ads/ad_config.dart';
import '../../ads/admob_service.dart';

/// Pub plein écran AdMob déclenchée explicitement par une page ([showAd] via GlobalKey).
/// Les pubs plein écran « entre deux vidéos » passent par AdmobService.onVideoClosed.
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
  @override
  void initState() {
    super.initState();
    if (!kIsWeb && AdConfig.current.enabled) AdmobService.preloadInterstitial();
  }

  Future<void> showAd() async {
    if (kIsWeb) {
      widget.onAdFailedToShow?.call();
      return;
    }
    await AdmobService.showInterstitialNow(
      onDismissed: widget.onAdDismissed,
      onFailed: widget.onAdFailedToShow,
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
