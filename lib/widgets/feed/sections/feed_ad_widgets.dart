import 'package:flutter/material.dart';
import '../../../pages/admin/AfrolookPub/advertisementCarouselWidget.dart';
import '../../../pages/pub/banner_ad_widget.dart';
import '../../../pages/pub/native_ad_widget.dart';

/// Bannière publicitaire (petit format).
class FeedAdBanner extends StatelessWidget {
  final String adKey;
  const FeedAdBanner({Key? key, required this.adKey}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(adKey),
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: BannerAdWidget(
        onAdLoaded: () {},
      ),
    );
  }
}

/// Publicité format rectangle moyen (MREC).
class FeedAdMrec extends StatelessWidget {
  final String adKey;
  const FeedAdMrec({Key? key, required this.adKey}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(adKey),
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: MrecAdWidget(
        key: ValueKey(adKey),
        onAdLoaded: () {},
      ),
    );
  }
}

/// Carrousel de publicités Afrolook (pleine largeur).
class FeedAdCarousel extends StatelessWidget {
  final String adKey;
  const FeedAdCarousel({Key? key, required this.adKey}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return AdvertisementCarouselWidget(
      key: ValueKey(adKey),
      height: size.height,
      width: size.width,
      showIndicators: true,
    );
  }
}
