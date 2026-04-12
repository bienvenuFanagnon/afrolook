import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:stack_appodeal_flutter/stack_appodeal_flutter.dart';
import 'package:provider/provider.dart';
import '../../../providers/authProvider.dart';
import '../../../services/utils/abonnement_utils.dart';
import '../user/userAbonnementPage.dart';

class MrecAdWidget extends StatefulWidget {
  final double? height;
  final double? width;
  final void Function()? onAdLoaded;
  final bool showLessAdsButton;
  final bool useBanner; // true = BANNER, false = MEDIUM_RECTANGLE

  const MrecAdWidget({
    Key? key,
    this.height,
    this.width,
    this.onAdLoaded,
    this.showLessAdsButton = true,
    this.useBanner = true, // par défaut : BANNUER
  }) : super(key: key);

  @override
  _MrecAdWidgetState createState() => _MrecAdWidgetState();
}

class _MrecAdWidgetState extends State<MrecAdWidget> {
  bool _adIsLoaded = false;
  bool _isPremium = false;
  bool _isCheckingPremium = true;
  bool _checkedAd = false;

  // Type d'annonce en fonction du paramètre
  AppodealAdType get _adType =>  AppodealAdType.MREC;

  // Taille du widget AppodealBanner
  AppodealBannerSize get _bannerSize =>
      widget.useBanner ? AppodealBannerSize.BANNER : AppodealBannerSize.MEDIUM_RECTANGLE;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
    _setupAdCallbacks();

  }

  // Callbacks adaptés selon le type
  void _setupAdCallbacks() {
    Appodeal.setMrecCallbacks(
      onMrecLoaded: (isPrecache) {
        print('✅ [MRECWidget] MREC loaded (isPrecache: $isPrecache)');
        if (mounted) {
          setState(() {
            _adIsLoaded = true;
          });
          widget.onAdLoaded?.call();
        }
      },
      onMrecFailedToLoad: () {
        print('❌ [MRECWidget] MREC failed to load');
        // if (mounted) setState(() => _adIsLoaded = false);
      },
      onMrecShown: () => print('📢 [MRECWidget] MREC shown'),
      onMrecClicked: () => print('🖱️ [MRECWidget] MREC clicked'),
      onMrecExpired: () => print('⏰ [MRECWidget] MREC expired'),
    );

  }

  Future<void> _checkPremiumStatus() async {

      if (!mounted) return;
      // Vérifier si une bannière est déjà chargée (selon le type)
      // Vérifier si une bannière est déjà chargée (selon le type)
      bool isLoaded = await Appodeal.isLoaded(_adType) ?? false;
      print('🔍 [MRECWidget] Appodeal.isLoaded(${_adType}) = $isLoaded');
      setState(() {
        _isCheckingPremium = false;
        _adIsLoaded = isLoaded;
      });
  }


  Future<void> _checkPremiumStatusOld() async {
    try {
      if (!mounted) return;
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final user = authProvider.loginUserData;
      if (user != null) {
        _isPremium = AbonnementUtils.isPremiumActive(user.abonnement);
        print('👤 [MRECWidget] Premium status: $_isPremium (abonnement: ${user.abonnement!.type!})');
      }
    } catch (e) {
      print('⚠️ [MRECWidget] Error checking premium: $e');
      _isPremium = false;
    } finally {
      if (mounted) {
        // Vérifier si une bannière est déjà chargée (selon le type)
        bool isLoaded = await Appodeal.isLoaded(_adType) ?? false;
        print('🔍 [MRECWidget] Appodeal.isLoaded(${_adType}) = $isLoaded');
        setState(() {
          _isCheckingPremium = false;
          _adIsLoaded = isLoaded;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // print('🔍 [MRECWidget] _isCheckingPremium = $_isCheckingPremium');
    // print('🔍 [MRECWidget] _isPremium = $_isPremium');
    print('🔍 [MRECWidget] _checkedAd = $_checkedAd');
    print('🔍 [MRECWidget] _adIsLoaded = $_adIsLoaded');

    // if (_isPremium) {
    //   return const SizedBox.shrink();
    // }
    // if (!_checkedAd) {
    //   return const SizedBox.shrink(); // évite clignotement
    // }
    // ✅ PAS DE PUB → PAS D’ESPACE
    if (!_adIsLoaded) {
      return const SizedBox.shrink();
    }
    if (kIsWeb) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // if (widget.showLessAdsButton) _buildLessAdsButton(),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          // constraints: BoxConstraints(minHeight: 50), // Force une hauteur mini pour la bannière
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AppodealBanner(
              adSize: _bannerSize,
            ),
          ),
        ),
      ],
    );
  }

  // --- Tes méthodes UI (Modale, Boutons) restent strictement identiques ---

  Widget _buildLessAdsButton() {
    return Container(
      margin: const EdgeInsets.only(right: 12, bottom: 4),
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
              SizedBox(width: 6),
              Text(
                  'NE PLUS VOIR DE PUBS',
                  style: TextStyle(color: Color(0xFFFFD600), fontSize: 7, fontWeight: FontWeight.bold)),
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