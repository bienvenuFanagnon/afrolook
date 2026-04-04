import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../../../providers/authProvider.dart';
import '../../../services/ad_service.dart';
import '../../../services/utils/abonnement_utils.dart';
import '../user/userAbonnementPage.dart';
import 'base_ad_widget.dart';

class NativeAdWidget extends BaseAdWidget {
  final double? height;
  final double? width;
  final void Function()? onAdLoaded;
  final TemplateType templateType; // medium, small, etc.
  final bool showLessAdsButton; // Afficher le bouton "Moins de pubs"

  const NativeAdWidget({
    Key? key,
    this.height,
    this.width,
    this.onAdLoaded,
    this.templateType = TemplateType.small,
    this.showLessAdsButton = true,
    bool forceShow = false,
  }) : super(key: key, forceShow: forceShow);

  @override
  _NativeAdWidgetState createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends BaseAdWidgetState<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _nativeAdIsLoaded = false;
  bool _isPremium = false;
  bool _isCheckingPremium = true;

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

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
  }

  Future<void> _checkPremiumStatus() async {
    try {
      await Future.delayed(Duration(milliseconds: 100));

      if (mounted && context.mounted) {
        final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
        final user = authProvider.loginUserData;

        if (user != null) {
          _isPremium = AbonnementUtils.isPremiumActive(user.abonnement);
        }
      }
    } catch (e) {
      print('Erreur vérification premium: $e');
      _isPremium = false;
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingPremium = false;
        });
      }
    }
  }

  void _showPremiumModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            decoration: BoxDecoration(
              color: Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Color(0xFFFFD600), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // En-tête
                Container(
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFE21221), Color(0xFFFF5252)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(22),
                      topRight: Radius.circular(22),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.workspace_premium,
                          color: Color(0xFFFFD600),
                          size: 36,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'AFROLOOK PREMIUM',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Sans publicité • Illimité',
                        style: TextStyle(
                          color: Color(0xFFFFD600),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Liste des avantages (scrollable)
                Flexible(
                  child: SingleChildScrollView(
                    physics: BouncingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPremiumAdvantage(
                            icon: Icons.remove_circle_outline,
                            title: 'Sans publicité',
                            description: 'Naviguez sans interruption',
                            color: Color(0xFF4CAF50),
                          ),
                          SizedBox(height: 12),
                          _buildPremiumAdvantage(
                            icon: Icons.public,
                            title: 'Visibilité Afrique entière',
                            description: 'Posts visibles partout',
                            color: Color(0xFF2196F3),
                          ),
                          SizedBox(height: 12),
                          _buildPremiumAdvantage(
                            icon: Icons.photo_library,
                            title: 'Jusqu\'à 3 images',
                            description: 'Publiez plus de contenu',
                            color: Color(0xFFFF9800),
                          ),
                          SizedBox(height: 12),
                          _buildPremiumAdvantage(
                            icon: Icons.access_time,
                            title: '0 restriction',
                            description: 'Pas de cooldown entre posts',
                            color: Color(0xFF9C27B0),
                          ),
                          SizedBox(height: 12),
                          _buildPremiumAdvantage(
                            icon: Icons.verified,
                            title: 'Badge exclusif',
                            description: 'Profil vérifié Premium',
                            color: Color(0xFFFFD600),
                          ),
                          SizedBox(height: 12),
                          _buildPremiumAdvantage(
                            icon: Icons.emoji_events,
                            title: 'Challenges illimités',
                            description: 'Participez sans limite',
                            color: Color(0xFFE91E63),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ========== SECTION PRIX BIEN VISIBLE ==========
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFD600), Color(0xFFFF9800)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFFFFD600).withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.monetization_on, color: Colors.black, size: 28),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'À partir de',
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '200 FCFA',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  height: 1,
                                ),
                              ),
                              Text(
                                '/mois',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(width: 12),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'PROMO',
                          style: TextStyle(
                            color: Color(0xFFFFD600),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bouton d'action
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => AbonnementScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFE21221),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.workspace_premium, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'DEVENIR PREMIUM',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 16),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'PAS MAINTENANT',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  Widget _buildPremiumAdvantage({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void loadAd() {
    // Si l'utilisateur est premium, ne pas charger la pub
    if (_isPremium) {
      print('📢 [NATIVE AD] Utilisateur Premium - Pas de publicité affichée');
      setLoaded();
      return;
    }

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
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: widget.templateType,
        mainBackgroundColor: Colors.grey[900],
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: Colors.green,
          style: NativeTemplateFontStyle.bold,
          size: 14.0,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: Colors.grey[300],
          style: NativeTemplateFontStyle.normal,
          size: 14.0,
        ),
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
    // Si l'utilisateur est premium, ne rien afficher
    if (_isPremium) {
      return const SizedBox.shrink();
    }

    // Pendant la vérification, ne rien afficher
    if (_isCheckingPremium) {
      return const SizedBox.shrink();
    }

    if (!_nativeAdIsLoaded || _nativeAd == null) {
      return const SizedBox.shrink();
    }

    double adHeight = widget.height ??
        (MediaQuery.of(context).size.width * _aspectRatio);

    // Afficher la pub avec le bouton "Moins de pubs" si demandé
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (widget.showLessAdsButton)
          Container(
            margin: EdgeInsets.only(right: 8, bottom: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showPremiumModal,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Color(0xFFFFD600).withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.workspace_premium,
                        color: Color(0xFFFFD600),
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'NE PLUS VOIR DE PUBS',
                        style: TextStyle(
                          color: Color(0xFFFFD600),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Color(0xFFFFD600),
                        size: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Container(
          margin: EdgeInsets.symmetric(vertical: 4),
          height: adHeight,
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
        ),
      ],
    );
  }
}


// // widgets/ads/native_ad_widget.dart
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:google_mobile_ads/google_mobile_ads.dart';
// import '../../services/ad_service.dart';
// import 'base_ad_widget.dart';
//
// class NativeAdWidget extends BaseAdWidget {
//   final double? height;
//   final double? width;
//   final void Function()? onAdLoaded;
//   final TemplateType templateType; // medium, small, etc.
//
//   const NativeAdWidget({
//     Key? key,
//     this.height,
//     this.width,
//     this.onAdLoaded,
//     this.templateType = TemplateType.small,
//     bool forceShow = false,
//   }) : super(key: key, forceShow: forceShow);
//
//   @override
//   _NativeAdWidgetState createState() => _NativeAdWidgetState();
// }
//
// class _NativeAdWidgetState extends BaseAdWidgetState<NativeAdWidget> {
//   // Aucune publicité chargée
//   @override
//   void loadAd() {
//     // Désactivé : aucune requête AdMob n'est effectuée
//     print('🛑 [NATIVE AD] Chargement désactivé');
//     // On simule un chargement réussi pour ne pas bloquer l'UI
//     if (mounted) {
//       setLoaded();
//     }
//     widget.onAdLoaded?.call();
//   }
//
//   @override
//   void disposeAd() {
//     // Rien à disposer
//   }
//
//   @override
//   Widget buildAdWidget() {
//     // Retourne un widget vide (aucune publicité affichée)
//     return const SizedBox.shrink();
//   }
// }