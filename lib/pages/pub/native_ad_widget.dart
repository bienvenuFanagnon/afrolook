// widgets/ads/native_ad_widget.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../services/ad_service.dart';
import 'base_ad_widget.dart';

class NativeAdWidget extends BaseAdWidget {
  final double? height;
  final double? width;
  final void Function()? onAdLoaded;
  final TemplateType templateType; // medium, small, etc.

  const NativeAdWidget({
    Key? key,
    this.height,
    this.width,
    this.onAdLoaded,
    this.templateType = TemplateType.small,
    bool forceShow = false,
  }) : super(key: key, forceShow: forceShow);

  @override
  _NativeAdWidgetState createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends BaseAdWidgetState<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _nativeAdIsLoaded = false;

  // ✅ Ratios d'aspect officiels Google
  double get _aspectRatio {
    switch (widget.templateType) {
      case TemplateType.small:
        return 91 / 355; // Hauteur: 91px pour largeur 355px
      case TemplateType.medium:
        return 370 / 355; // Hauteur: 370px pour largeur 355px
      default:
        return 370 / 355;
    }
  }

  // ✅ Hauteurs fixes approximatives (alternative plus simple)
  double get _fixedHeight {
    switch (widget.templateType) {
      case TemplateType.small:
        return 100.0; // ~100px pour small
      case TemplateType.medium:
        return 300.0; // ~300px pour medium
      default:
        return 300.0;
    }
  }

  @override
  void loadAd() {
    print('📢 [NATIVE AD] Chargement avec ID: ${AdService.nativeAdId} (${AdService.currentMode})');

    _nativeAd = NativeAd(
      adUnitId: AdService.nativeAdId,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          print('✅ [NATIVE AD] Chargé avec succès');
          if (mounted) {
            setState(() {
              _nativeAdIsLoaded = true;
              setLoaded();
            });
            widget.onAdLoaded?.call();
          }
        },
        onAdFailedToLoad: (ad, error) {
          print('❌ [NATIVE AD] Erreur: $error');
          ad.dispose();
          if (mounted) {
            setError(error.message);
          }
        },
        onAdClicked: (ad) {
          print('🖱️ [NATIVE AD] Clic');
        },
        onAdImpression: (ad) {
          print('👁️ [NATIVE AD] Impression');
        },
      ),
      request: const AdRequest(),

      // Style du template natif (personnalisable)
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: widget.templateType,

        // Couleur de fond
        mainBackgroundColor: Colors.grey[900],

        // Style du bouton d'appel à l'action
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: Colors.green,
          style: NativeTemplateFontStyle.bold,
          size: 14.0,
        ),

        // Style du titre principal
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),

        // Style du texte secondaire
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.grey[300],
          style: NativeTemplateFontStyle.normal,
          size: 14.0,
        ),

        // Style du texte tertiaire
        tertiaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.grey[500],
          style: NativeTemplateFontStyle.italic,
          size: 12.0,
        ),
      ),
    )..load();
  }

  @override
  void disposeAd() {
    _nativeAd?.dispose();
  }

  @override
  Widget buildAdWidget() {
    if (!_nativeAdIsLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    // ✅ OPTION 1: Utiliser le ratio dynamique (recommandé)
    double adHeight = widget.height ??
        (MediaQuery.of(context).size.width * _aspectRatio);

    // ✅ OPTION 2: Utiliser la hauteur fixe (décommentez si vous préférez)
    // double adHeight = widget.height ?? _fixedHeight;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      height: adHeight, // Maintenant la hauteur est correcte
      width: widget.width ?? double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AdWidget(ad: _nativeAd!),
      ),
    );
  }
}