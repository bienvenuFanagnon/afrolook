import 'package:flutter/material.dart';

import '../../ads/ad_config.dart';
import '../../ads/admob_widgets.dart';

/// Emplacement pub des listes et pages (profils, classements, défis, services…) : AdMob uniquement
/// (les pubs Afrolook ont leurs propres emplacements). [useBanner] : bannière ; sinon grand format.
/// Aucune place n'est réservée tant que la pub n'est pas chargée.
class MrecAdWidget extends StatelessWidget {
  final double? height;
  final double? width;
  final void Function()? onAdLoaded;
  final bool showLessAdsButton;
  final bool useBanner; // true = bannière, false = grand format 300×250

  const MrecAdWidget({
    Key? key,
    this.height,
    this.width,
    this.onAdLoaded,
    this.showLessAdsButton = true,
    this.useBanner = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!AdConfig.current.listsNative) return const SizedBox.shrink();
    return AdmobBannerWidget(mrec: !useBanner);
  }
}
