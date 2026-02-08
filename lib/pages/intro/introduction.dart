import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:afrotok/pages/auth/authTest/Screens/Login/loginPageUser.dart';

import '../widgetGlobal.dart';

// Couleurs de luxe Afrolook
const Color primaryGreen = Color(0xFF25D366);
const Color luxuryGold = Color(0xFFFFD700);
const Color premiumRed = Color(0xFFFF4757);
const Color elitePurple = Color(0xFF8A2BE2);
const Color darkBackground = Color(0xFF000000);

class IntroductionPage extends StatefulWidget {
  const IntroductionPage({Key? key}) : super(key: key);

  @override
  _IntroductionPageState createState() => _IntroductionPageState();
}

class _IntroductionPageState extends State<IntroductionPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoScrollTimer;

  final List<String> _luxuryImages = [
    "assets/images/intro5.jpg",
    "assets/images/intro2.jpg",
    "assets/images/intro3.jpg",
    "assets/images/intro6.jpg",
    "assets/images/intro7.jpg",
  ];

  // Contrôleurs pour précharger les images
  final List<Image> _preloadedImages = [];

  @override
  void initState() {
    super.initState();

    // Préchargement des images
    // Lancer après le premier build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadImages();
      if (kIsWeb) {
          showInstallModal(context);
      }
    });
    // Auto-scroll toutes les 5 secondes
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_currentPage < 4 && mounted) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 1500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _preloadImages() {
    for (String path in _luxuryImages) {
      final imageProvider = AssetImage(path);

      precacheImage(imageProvider, context).then((_) {
        debugPrint("✅ Image préchargée : $path");
      }).catchError((e) {
        debugPrint("❌ Erreur de préchargement : $e");
      });

      _preloadedImages.add(Image(
        image: imageProvider,
        fit: BoxFit.cover,
      ));
    }
  }
  @override
  void dispose() {
    _pageController.dispose();
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _onIntroEnd(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LoginPageUser()),
    );
  }

  void _nextPage() {
    if (_currentPage < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _onIntroEnd(context);
    }
  }

  Widget _buildLuxuryFeature(String emoji, String text, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Text(
              emoji,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
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
              // Header luxueux
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Image.asset(
                    //   "assets/logo/afrolook_logo.png",
                    //   height: 45,
                    // ),
                    // const SizedBox(width: 12),
                    Text(
                      "Afrolook",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: luxuryGold,
                        letterSpacing: 2.0,
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
                    });
                  },
                  children: [
                    _buildLuxuryPage(
                      imageIndex: 0,
                      title: "🌟 L'Excellence Africaine",
                      subtitle: "Le réseau social de luxe où la beauté rencontre la monétisation",
                      color: luxuryGold,
                      features: [
                        "💎 Postez des looks premium dignes des magazines de mode",
                        "📸 Contenu exclusif réservé à l'élite africaine",
                        "💰 Monétisation immédiate dès vos premières publications",
                        "🔥 Nous rejoindre maintenant est un investissement",
                      ],
                    ),

                    _buildLuxuryPage(
                      imageIndex: 1,
                      title: "💰 Monétisation Prestige",
                      subtitle: "Transformez votre élégance en revenus mensuels substantiels",
                      color: primaryGreen,
                      features: [
                        "🏆 Jusqu'à 500 000 FCFA/mois pour les créateurs d'exception",
                        "🤝 Collaborations exclusives avec marques de luxe",
                        "🎓 Formations premium pour perfectionner votre art",
                        "⭐ Votre talent mérite une rémunération à sa hauteur",
                      ],
                    ),

                    _buildLuxuryPage(
                      imageIndex: 2,
                      title: "👑 Communauté d'Élite",
                      subtitle: "Rejoignez le cercle très fermé des influenceurs premium",
                      color: elitePurple,
                      features: [
                        "🔒 Accès réservé aux créateurs au contenu exceptionnel",
                        "📈 Parrainage qui vous propulse auprès de l'élite",
                        "💫 Networking avec les personnalités les plus influentes",
                        "🚀 Votre carrière mérite cette plateforme d'exception",
                      ],
                    ),

                    _buildLuxuryPage(
                      imageIndex: 3,
                      title: "⚡ Opportunité Unique",
                      subtitle: "Ne soyez pas spectateur, soyez acteur de votre réussite",
                      color: premiumRed,
                      features: [
                        "⏳ Rejoignez-nous avant la saturation du marché premium",
                        "💎 Positionnez-vous comme référence du luxe africain",
                        "🚨 Cette opportunité ne se représentera pas",
                        "🎯 Votre avenir luxueux commence ici et maintenant",
                      ],
                    ),
                    _buildLuxuryPage(
                      imageIndex: 4,
                      title: "🎥 Live de Prestige",
                      subtitle: "Faites rayonner vos produits et collaborations en direct",
                      color: luxuryGold,
                      features: [
                        "🌍 Organisez des lives exclusifs pour présenter vos produits",
                        "🤝 Collaborez avec des célébrités et marques de luxe",
                        "💬 Interagissez directement avec une audience premium",
                        "📈 Boostez instantanément votre visibilité et vos revenus",
                      ],
                    ),

                  ],
                ),
              ),

              // Indicateurs de page
              Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _currentPage == index ? 24 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: _currentPage == index ? luxuryGold : Colors.grey[700],
                      ),
                    );
                  }),
                ),
              ),

              // Bouton d'action premium
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: luxuryGold,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 5,
                    ),
                    child: Text(
                      _currentPage < 4 ? "SUIVANT →" : "ACCÉDER AU LUXE 💎",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ),

              // Lien skip
              Padding(
                padding: const EdgeInsets.only(bottom: 25),
                child: TextButton(
                  onPressed: () => _onIntroEnd(context),
                  child: RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: "Ignorer ? ",
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        TextSpan(
                          text: "Votre rival vous attend...",
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLuxuryPage({
    required int imageIndex,
    required String title,
    required String subtitle,
    required Color color,
    required List<String> features,
  }) {
    return Stack(
      children: [
        // Image de fond optimisée
        Image.asset(
          _luxuryImages[imageIndex],
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),

        // Overlay sombre pour la lisibilité
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.6),
                Colors.black.withOpacity(0.8),
              ],
            ),
          ),
        ),

        // Contenu
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 40),
          child: Column(
            children: [
              // Titre principal
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1.2,
                  shadows: const [
                    Shadow(
                      blurRadius: 10,
                      color: Colors.black,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 15),

              // Sous-titre
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                  shadows: [
                    Shadow(
                      blurRadius: 5,
                      color: Colors.black,
                      offset: Offset(1, 1),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Features
              Column(
                children: features.map((feature) {
                  final emoji = feature.split(' ')[0];
                  final text = feature.substring(emoji.length + 1);
                  Color featureColor = color;

                  // Alternance des couleurs
                  if (features.indexOf(feature) % 4 == 1) featureColor = primaryGreen;
                  if (features.indexOf(feature) % 4 == 2) featureColor = elitePurple;
                  if (features.indexOf(feature) % 4 == 3) featureColor = premiumRed;

                  return _buildLuxuryFeature(emoji, text, featureColor);
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}