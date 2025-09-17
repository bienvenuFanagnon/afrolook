import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:afrotok/pages/auth/authTest/Screens/Login/loginPageUser.dart';

// Couleurs de base Afrolook
const Color primaryGreen = Color(0xFF25D366);
const Color accentYellow = Color(0xFFFFD700);
const Color accentRed = Color(0xFFFF4757);
const Color darkBackground = Color(0xFF121212);
const Color lightBackground = Color(0xFF1E1E1E);
const Color textColor = Colors.white;

class IntroductionPage extends StatefulWidget {
  const IntroductionPage({Key? key}) : super(key: key);

  @override
  _IntroductionPageState createState() => _IntroductionPageState();
}

class _IntroductionPageState extends State<IntroductionPage> with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();

    // Auto-scroll toutes les 5 secondes
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentPage < 3) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } else {
        _pageController.jumpToPage(0);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _onIntroEnd(context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LoginPageUser()),
    );
  }

  Widget _buildIcon(IconData icon, {Color color = primaryGreen, double size = 40}) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.3), color.withOpacity(0.1)],
          ),
          border: Border.all(color: color.withOpacity(0.5), width: 2),
        ),
        child: Icon(icon, size: size, color: color),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackground,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: Column(
            children: [
              // Header avec logo Afrolook
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      "assets/logo/afrolook_logo.png",
                      height: 40,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "AFROLOOK",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: primaryGreen,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (int page) {
                    setState(() {
                      _currentPage = page;
                      _animationController.reset();
                      _animationController.forward();
                    });
                  },
                  children: [
                    // Page 1
                    _buildPage(
                      icon: Icons.people_alt_rounded,
                      title: "Bienvenue sur Afrolook 🌍",
                      subtitle: "Le réseau social africain qui valorise vos talents",
                      color: primaryGreen,
                      content: Column(
                        children: [
                          _buildFeatureItem(Icons.photo_camera_rounded, "Partagez photos et vidéos", primaryGreen),
                          const SizedBox(height: 12),
                          _buildFeatureItem(Icons.groups_rounded, "Connectez-vous à la communauté", accentYellow),
                          const SizedBox(height: 12),
                          // _buildFeatureItem(Icons.favorite_rounded, "Créez du lien avec vos abonnés", accentRed),
                          _buildFeatureItem(Icons.leaderboard_rounded, "Les plus performants gagneront +500 000 FCFA/mois", accentRed),

                        ],
                      ),
                    ),

                    // Page 2
                    _buildPage(
                      icon: Icons.monetization_on_rounded,
                      title: "Monétisez vos contenus 💰",
                      subtitle: "Transformez vos vidéos en revenus réels",
                      color: accentYellow,
                      content: Column(
                        children: [
                          _buildFeatureItem(Icons.videocam_rounded, "Vendez vos vidéos exclusives", accentYellow),
                          const SizedBox(height: 12),
                          _buildFeatureItem(Icons.handshake_rounded, "Collaborez avec des marques", primaryGreen),
                          const SizedBox(height: 12),
                          _buildFeatureItem(Icons.leaderboard_rounded, "Les plus performants gagnent +500 000 FCFA/mois", accentRed),
                        ],
                      ),
                    ),

                    // Page 3
                    _buildPage(
                      icon: Icons.star_rounded,
                      title: "Développez votre communauté 🚀",
                      subtitle: "Plus d’abonnés = plus de revenus",
                      color: accentRed,
                      content: Column(
                        children: [
                          _buildFeatureItem(Icons.person_add_alt_1_rounded, "Invitez vos amis à s’abonner", accentRed),
                          const SizedBox(height: 12),
                          _buildFeatureItem(Icons.notifications_active_rounded, "Engagez vos abonnés avec vos posts", accentYellow),
                          const SizedBox(height: 12),
                          _buildFeatureItem(Icons.rocket_launch_rounded, "Devenez une référence en Afrique", primaryGreen),
                        ],
                      ),
                    ),

                    // Page 4
                    _buildPage(
                      icon: Icons.card_giftcard_rounded,
                      title: "Gagnez encore plus 🎁",
                      subtitle: "Profitez du parrainage et des bonus Afrolook",
                      color: primaryGreen,
                      content: Column(
                        children: [
                          _buildFeatureItem(Icons.favorite_rounded, "Créez du lien avec vos abonnés", accentRed),
                          const SizedBox(height: 12),
                          _buildFeatureItem(Icons.share_rounded, "Partagez votre code unique", primaryGreen),
                          const SizedBox(height: 12),
                          _buildFeatureItem(Icons.savings_rounded, "Cumulez vos récompenses", accentRed),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Indicateurs de page
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _currentPage == index ? 18 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: _currentPage == index ? primaryGreen : Colors.grey[600],
                      ),
                    );
                  }),
                ),
              ),

              // Bouton principal
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () => _onIntroEnd(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 5,
                      shadowColor: primaryGreen.withOpacity(0.4),
                    ),
                    child: const Text(
                      "Commencer l’aventure",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

              // Skip
              TextButton(
                onPressed: () => _onIntroEnd(context),
                child: Text(
                  "Passer l’introduction",
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Widget content,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildIcon(icon, color: color),
          const SizedBox(height: 30),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: textColor,
              )),
          const SizedBox(height: 10),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[400],
                fontStyle: FontStyle.italic,
              )),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: lightBackground.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: content,
          ),
        ],
      ),
    );
  }
}
