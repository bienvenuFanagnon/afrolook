import 'package:flutter/material.dart';

import '../../ads/ad_banner.dart';

/// Bannière (Appodeal ou AdMob selon la configuration ; même API qu'avant). Aucune place réservée tant qu'elle n'est pas chargée.
class BannerAdWidget extends StatelessWidget {
  final void Function()? onAdLoaded;
  final bool showLessAdsButton;

  const BannerAdWidget({Key? key, this.onAdLoaded, this.showLessAdsButton = true}) : super(key: key);

  @override
  Widget build(BuildContext context) => const AdBanner();
}
