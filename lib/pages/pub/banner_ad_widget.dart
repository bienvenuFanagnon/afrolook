import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../services/ad_service.dart';
import 'base_ad_widget.dart';

class BannerAdWidget extends BaseAdWidget {
  final AdSize? customSize;
  final void Function()? onAdLoaded;

  const BannerAdWidget({
    Key? key,
    this.customSize,
    this.onAdLoaded,
    bool forceShow = false,
  }) : super(key: key, forceShow: forceShow);

  @override
  _BannerAdWidgetState createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends BaseAdWidgetState<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void loadAd() {
    print('📢 [BANNER] Chargement avec ID: ${AdService.bannerAdId} (${AdService.currentMode})');

    _bannerAd = BannerAd(
      adUnitId: AdService.bannerAdId,
      size: widget.customSize ?? AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print('✅ [BANNER] Chargé avec succès');
          setState(() {
            _isAdLoaded = true;
            setLoaded();
          });
          widget.onAdLoaded?.call();
        },
        onAdFailedToLoad: (ad, error) {
          print('❌ [BANNER] Erreur: $error');
          ad.dispose();
          setError(error.message);
        },
      ),
    )..load();
  }

  @override
  void disposeAd() {
    _bannerAd?.dispose();
  }

  @override
  Widget buildAdWidget() {
    if (!_isAdLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    // Centrer la bannière
    return Center(
      child: Container(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}