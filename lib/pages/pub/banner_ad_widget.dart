import 'dart:io';
import 'package:flutter/material.dart';
import 'package:stack_appodeal_flutter/stack_appodeal_flutter.dart'; // ✅ Nouveau SDK
import 'package:provider/provider.dart';
import '../../../providers/authProvider.dart';
import '../../../services/utils/abonnement_utils.dart';
import '../user/userAbonnementPage.dart';

class BannerAdWidget extends StatefulWidget {
  final void Function()? onAdLoaded;
  final bool showLessAdsButton;

  const BannerAdWidget({
    Key? key,
    this.onAdLoaded,
    this.showLessAdsButton = true,
  }) : super(key: key);

  @override
  _BannerAdWidgetState createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  bool _isAdLoaded = false;
  bool _isPremium = false;
  bool _isCheckingPremium = true;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
    _initBannerCallbacks();
  }

  void _initBannerCallbacks() {
    Appodeal.setBannerCallbacks(
      onBannerLoaded: (isPrecache) {
        print('✅ [APPODEAL BANNER] Chargée');
        if (mounted) {
          setState(() => _isAdLoaded = true);
          widget.onAdLoaded?.call();
        }
      },
      onBannerFailedToLoad: () {
        print('❌ [APPODEAL BANNER] Échec du chargement');
        if (mounted) {
          setState(() => _isAdLoaded = false);
        }
      },
      onBannerClicked: () => print('🖱️ [APPODEAL BANNER] Clic'),
      onBannerShown: () => print('👁️ [APPODEAL BANNER] Impression'),
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
        // ✅ Vérifie si une bannière est déjà chargée (cache)
        final bool alreadyLoaded = await Appodeal.isLoaded(AppodealAdType.Banner);
        if (alreadyLoaded && mounted) {
          setState(() => _isAdLoaded = true);
          widget.onAdLoaded?.call();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pas de pub pour les premium ou pendant la vérification
    if (_isPremium) return const SizedBox.shrink();

    // ✅ N'affiche la bannière que si elle est chargée
    if (!_isAdLoaded) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (widget.showLessAdsButton) _buildLessAdsButton(),
        Center(
          child: Container(
            constraints: const BoxConstraints(minHeight: 50),
            child: const AppodealBanner(
              adSize: AppodealBannerSize.BANNER,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLessAdsButton() {
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 4),
      child: InkWell(
        onTap: _showPremiumModal,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD600).withOpacity(0.5)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.workspace_premium, color: Color(0xFFFFD600), size: 14),
              SizedBox(width: 4),
              Text(
                'NE PLUS VOIR DE PUBS',
                style: TextStyle(color: Color(0xFFFFD600), fontSize: 7, fontWeight: FontWeight.bold),
              ),
              Icon(Icons.arrow_forward_ios, color: Color(0xFFFFD600), size: 10),
            ],
          ),
        ),
      ),
    );
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
}


// import 'package:flutter/material.dart';
//
// import 'package:provider/provider.dart';
// import '../../../providers/authProvider.dart';
// import '../../../services/ad_service.dart';
// import '../../../services/utils/abonnement_utils.dart';
// import '../user/userAbonnementPage.dart';
// import 'base_ad_widget.dart';
//
// class BannerAdWidget extends BaseAdWidget {
//   final AdSize? customSize;
//   final void Function()? onAdLoaded;
//   final bool showLessAdsButton; // Afficher le bouton "Moins de pubs"
//
//   const BannerAdWidget({
//     Key? key,
//     this.customSize,
//     this.onAdLoaded,
//     this.showLessAdsButton = true,
//     bool forceShow = false,
//   }) : super(key: key, forceShow: forceShow);
//
//   @override
//   _BannerAdWidgetState createState() => _BannerAdWidgetState();
// }
//
// class _BannerAdWidgetState extends BaseAdWidgetState<BannerAdWidget> {
//   BannerAd? _bannerAd;
//   bool _isAdLoaded = false;
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
//   void _showPremiumModal() {
//     showDialog(
//       context: context,
//       barrierDismissible: true,
//       builder: (BuildContext context) {
//         return Dialog(
//           backgroundColor: Colors.transparent,
//           elevation: 0,
//           insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
//           child: Container(
//             width: MediaQuery.of(context).size.width * 0.9,
//             constraints: BoxConstraints(
//               maxHeight: MediaQuery.of(context).size.height * 0.8,
//             ),
//             decoration: BoxDecoration(
//               color: Color(0xFF1E1E1E),
//               borderRadius: BorderRadius.circular(24),
//               border: Border.all(color: Color(0xFFFFD600), width: 2),
//             ),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 // En-tête
//                 Container(
//                   padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       colors: [Color(0xFFE21221), Color(0xFFFF5252)],
//                       begin: Alignment.topLeft,
//                       end: Alignment.bottomRight,
//                     ),
//                     borderRadius: BorderRadius.only(
//                       topLeft: Radius.circular(22),
//                       topRight: Radius.circular(22),
//                     ),
//                   ),
//                   child: Column(
//                     children: [
//                       Container(
//                         padding: EdgeInsets.all(10),
//                         decoration: BoxDecoration(
//                           color: Colors.white.withOpacity(0.2),
//                           shape: BoxShape.circle,
//                         ),
//                         child: Icon(
//                           Icons.workspace_premium,
//                           color: Color(0xFFFFD600),
//                           size: 36,
//                         ),
//                       ),
//                       SizedBox(height: 8),
//                       Text(
//                         'AFROLOOK PREMIUM',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                           letterSpacing: 1,
//                         ),
//                       ),
//                       SizedBox(height: 2),
//                       Text(
//                         'Sans publicité • Illimité',
//                         style: TextStyle(
//                           color: Color(0xFFFFD600),
//                           fontSize: 12,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 // Liste des avantages (scrollable)
//                 Flexible(
//                   child: SingleChildScrollView(
//                     physics: BouncingScrollPhysics(),
//                     child: Padding(
//                       padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           _buildPremiumAdvantage(
//                             icon: Icons.remove_circle_outline,
//                             title: 'Sans publicité',
//                             description: 'Naviguez sans interruption',
//                             color: Color(0xFF4CAF50),
//                           ),
//                           SizedBox(height: 12),
//                           _buildPremiumAdvantage(
//                             icon: Icons.public,
//                             title: 'Visibilité Afrique entière',
//                             description: 'Posts visibles partout',
//                             color: Color(0xFF2196F3),
//                           ),
//                           SizedBox(height: 12),
//                           _buildPremiumAdvantage(
//                             icon: Icons.photo_library,
//                             title: 'Jusqu\'à 3 images',
//                             description: 'Publiez plus de contenu',
//                             color: Color(0xFFFF9800),
//                           ),
//                           SizedBox(height: 12),
//                           _buildPremiumAdvantage(
//                             icon: Icons.access_time,
//                             title: '0 restriction',
//                             description: 'Pas de cooldown entre posts',
//                             color: Color(0xFF9C27B0),
//                           ),
//                           SizedBox(height: 12),
//                           _buildPremiumAdvantage(
//                             icon: Icons.verified,
//                             title: 'Badge exclusif',
//                             description: 'Profil vérifié Premium',
//                             color: Color(0xFFFFD600),
//                           ),
//                           SizedBox(height: 12),
//                           _buildPremiumAdvantage(
//                             icon: Icons.emoji_events,
//                             title: 'Challenges illimités',
//                             description: 'Participez sans limite',
//                             color: Color(0xFFE91E63),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//
//                 // ========== SECTION PRIX BIEN VISIBLE ==========
//                 Container(
//                   margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                   padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       colors: [Color(0xFFFFD600), Color(0xFFFF9800)],
//                       begin: Alignment.topLeft,
//                       end: Alignment.bottomRight,
//                     ),
//                     borderRadius: BorderRadius.circular(16),
//                     boxShadow: [
//                       BoxShadow(
//                         color: Color(0xFFFFD600).withOpacity(0.3),
//                         blurRadius: 8,
//                         offset: Offset(0, 2),
//                       ),
//                     ],
//                   ),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Icon(Icons.monetization_on, color: Colors.black, size: 28),
//                       SizedBox(width: 12),
//                       Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             'À partir de',
//                             style: TextStyle(
//                               color: Colors.black87,
//                               fontSize: 12,
//                               fontWeight: FontWeight.w500,
//                             ),
//                           ),
//                           Row(
//                             crossAxisAlignment: CrossAxisAlignment.end,
//                             children: [
//                               Text(
//                                 '200 FCFA',
//                                 style: TextStyle(
//                                   color: Colors.black,
//                                   fontSize: 24,
//                                   fontWeight: FontWeight.bold,
//                                   height: 1,
//                                 ),
//                               ),
//                               Text(
//                                 '/mois',
//                                 style: TextStyle(
//                                   color: Colors.black87,
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.w500,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                       SizedBox(width: 12),
//                       Container(
//                         padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                         decoration: BoxDecoration(
//                           color: Colors.black,
//                           borderRadius: BorderRadius.circular(20),
//                         ),
//                         child: Text(
//                           'PROMO',
//                           style: TextStyle(
//                             color: Color(0xFFFFD600),
//                             fontSize: 10,
//                             fontWeight: FontWeight.bold,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//
//                 // Bouton d'action
//                 Padding(
//                   padding: EdgeInsets.all(16),
//                   child: Column(
//                     children: [
//                       SizedBox(
//                         width: double.infinity,
//                         child: ElevatedButton(
//                           onPressed: () {
//                             Navigator.pop(context);
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(builder: (context) => AbonnementScreen()),
//                             );
//                           },
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Color(0xFFE21221),
//                             foregroundColor: Colors.white,
//                             padding: EdgeInsets.symmetric(vertical: 12),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(30),
//                             ),
//                             elevation: 0,
//                           ),
//                           child: Row(
//                             mainAxisAlignment: MainAxisAlignment.center,
//                             children: [
//                               Icon(Icons.workspace_premium, size: 18),
//                               SizedBox(width: 8),
//                               Text(
//                                 'DEVENIR PREMIUM',
//                                 style: TextStyle(
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               SizedBox(width: 8),
//                               Icon(Icons.arrow_forward, size: 16),
//                             ],
//                           ),
//                         ),
//                       ),
//                       SizedBox(height: 8),
//                       TextButton(
//                         onPressed: () => Navigator.pop(context),
//                         child: Text(
//                           'PAS MAINTENANT',
//                           style: TextStyle(
//                             color: Colors.grey[500],
//                             fontSize: 12,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
//   Widget _buildPremiumAdvantage({
//     required IconData icon,
//     required String title,
//     required String description,
//     required Color color,
//   }) {
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.center,
//       children: [
//         Container(
//           padding: EdgeInsets.all(5),
//           decoration: BoxDecoration(
//             color: color.withOpacity(0.2),
//             borderRadius: BorderRadius.circular(8),
//           ),
//           child: Icon(icon, color: color, size: 18),
//         ),
//         SizedBox(width: 10),
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 title,
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 13,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               SizedBox(height: 2),
//               Text(
//                 description,
//                 style: TextStyle(
//                   color: Colors.grey[400],
//                   fontSize: 11,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
//
//   @override
//   void loadAd() {
//     // Si l'utilisateur est premium, ne pas charger la pub
//     if (_isPremium) {
//       print('📢 [BANNER] Utilisateur Premium - Pas de publicité affichée');
//       setLoaded();
//       return;
//     }
//
//     print('📢 [BANNER] Chargement avec ID: ${AdService.bannerAdId} (${AdService.currentMode})');
//
//     _bannerAd = BannerAd(
//       adUnitId: AdService.bannerAdId,
//       size: widget.customSize ?? AdSize.banner,
//       request: const AdRequest(),
//       listener: BannerAdListener(
//         onAdLoaded: (ad) {
//           print('✅ [BANNER] Chargé avec succès');
//           if (mounted) {
//             setState(() {
//               _isAdLoaded = true;
//               setLoaded();
//             });
//             widget.onAdLoaded?.call();
//           }
//         },
//         onAdFailedToLoad: (ad, error) {
//           print('❌ [BANNER] Erreur: $error');
//           ad.dispose();
//           if (mounted) {
//             setError(error.message);
//           }
//         },
//       ),
//     )..load();
//   }
//
//   @override
//   void disposeAd() {
//     _bannerAd?.dispose();
//   }
//
//   @override
//   Widget buildAdWidget() {
//     // Si l'utilisateur est premium, ne rien afficher
//     if (_isPremium) {
//       return const SizedBox.shrink();
//     }
//
//     // Pendant la vérification, ne rien afficher
//     if (_isCheckingPremium) {
//       return const SizedBox.shrink();
//     }
//
//     if (!_isAdLoaded || _bannerAd == null) {
//       return const SizedBox.shrink();
//     }
//
//     final bannerWidth = _bannerAd!.size.width.toDouble();
//     final bannerHeight = _bannerAd!.size.height.toDouble();
//
//     // Afficher la bannière avec le bouton "Moins de pubs" si demandé
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       crossAxisAlignment: CrossAxisAlignment.end,
//       children: [
//         if (widget.showLessAdsButton)
//           Container(
//             margin: EdgeInsets.only(right: 8, bottom: 4),
//             child: Material(
//               color: Colors.transparent,
//               child: InkWell(
//                 onTap: _showPremiumModal,
//                 borderRadius: BorderRadius.circular(16),
//                 child: Container(
//                   padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//                   decoration: BoxDecoration(
//                     color: Color(0xFF1E1E1E),
//                     borderRadius: BorderRadius.circular(16),
//                     border: Border.all(color: Color(0xFFFFD600).withOpacity(0.5)),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(
//                         Icons.workspace_premium,
//                         color: Color(0xFFFFD600),
//                         size: 14,
//                       ),
//                       SizedBox(width: 3),
//                       Text(
//                         'NE PLUS VOIR DE PUBS',
//                         style: TextStyle(
//                           color: Color(0xFFFFD600),
//                           fontSize: 10,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       SizedBox(width: 4),
//                       Icon(
//                         Icons.arrow_forward_ios,
//                         color: Color(0xFFFFD600),
//                         size: 10,
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         Center(
//           child: Container(
//             width: bannerWidth,
//             height: bannerHeight,
//             child: AdWidget(ad: _bannerAd!),
//           ),
//         ),
//       ],
//     );
//   }
// }
