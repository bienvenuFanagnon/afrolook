import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:afrotok/pages/splashChargement.dart';

import '../widgetGlobal.dart';

const Color _kGold = Color(0xFFFFD700);

class _Slide {
  final String image;
  final String line1;
  final String lineGold;
  final String line3;
  final String sub;
  const _Slide(this.image, this.line1, this.lineGold, this.line3, this.sub);
}

const List<_Slide> _kSlides = [
  _Slide(
    'assets/images/intro5.jpg',
    'Monétise',
    'ton talent',
    'africain.',
    "Transforme ta passion en revenus réels dès aujourd'hui.",
  ),
  _Slide(
    'assets/images/intro2.jpg',
    'Rejoins',
    '+500',
    'créateurs',
    "qui monétisent déjà leur talent sur Afrolook.",
  ),
  _Slide(
    'assets/images/intro3.jpg',
    'Partage.',
    'Inspire.',
    'Gagne.',
    "Tes looks, ta culture, ton art — ton business.",
  ),
  _Slide(
    'assets/images/intro6.jpg',
    "L'élite",
    'africaine',
    "t'attend.",
    "Positionne-toi parmi les créateurs premium.",
  ),
  _Slide(
    'assets/images/intro7.jpg',
    'Live.',
    'Vends.',
    'Prospère.',
    "Connecte-toi à une audience premium en direct.",
  ),
];

class IntroductionPage extends StatefulWidget {
  const IntroductionPage({Key? key}) : super(key: key);

  @override
  _IntroductionPageState createState() => _IntroductionPageState();
}

class _IntroductionPageState extends State<IntroductionPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoScrollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final s in _kSlides) {
        precacheImage(AssetImage(s.image), context);
      }
      if (kIsWeb) showInstallModal(context);
    });
    _startTimer();
  }

  void _startTimer() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 4500), (_) {
      if (!mounted) return;
      final next = (_currentPage + 1) % _kSlides.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _onIntroEnd() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SplashChargement()),
    );
  }

  void _next() {
    if (_currentPage < _kSlides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    } else {
      _onIntroEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Photos plein écran swipables ──────────────────────────
            PageView.builder(
              controller: _pageController,
              onPageChanged: (i) {
                setState(() => _currentPage = i);
                _startTimer();
              },
              itemCount: _kSlides.length,
              itemBuilder: (_, i) => Image.asset(
                _kSlides[i].image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1A0800), Color(0xFF3D1500)],
                    ),
                  ),
                ),
              ),
            ),

            // ── Overlay gradient bas sombre ───────────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, 0.28, 1.0],
                  colors: [
                    Color(0x20000000),
                    Color(0x50000000),
                    Color(0xEE000000),
                  ],
                ),
              ),
            ),

            // ── Contenu ───────────────────────────────────────────────
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Wordmark
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AFROLOOK',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _kGold,
                            letterSpacing: 7,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(width: 24, height: 2, color: _kGold),
                      ],
                    ),
                  ),

                  // Hero texte animé
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 500),
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.08),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                parent: anim,
                                curve: Curves.easeOut,
                              )),
                              child: child,
                            ),
                          ),
                          child: _buildHeroText(
                            _kSlides[_currentPage],
                            ValueKey(_currentPage),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Stats
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                    child: _buildStats(),
                  ),

                  // Bannière social proof
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: _buildProof(),
                  ),

                  // Dots
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    child: _buildDots(),
                  ),

                  // Bouton Suivant / Commencer
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kGold,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          _currentPage < _kSlides.length - 1
                              ? 'SUIVANT →'
                              : 'COMMENCER 💎',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Lien ignorer
                  Center(
                    child: TextButton(
                      onPressed: _onIntroEnd,
                      child: const Text(
                        'Ignorer',
                        style: TextStyle(
                          color: Color(0x70FFFFFF),
                          fontSize: 13,
                        ),
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
  }

  Widget _buildHeroText(_Slide slide, Key key) {
    const base = TextStyle(
      fontSize: 44,
      fontWeight: FontWeight.w800,
      height: 1.06,
      letterSpacing: -1.2,
    );
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(slide.line1, style: base.copyWith(color: Colors.white)),
        Text(slide.lineGold, style: base.copyWith(color: _kGold)),
        Text(slide.line3, style: base.copyWith(color: Colors.white)),
        const SizedBox(height: 12),
        Text(
          slide.sub,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xA0FFFFFF),
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildStats() {
    return Row(
      children: [
        _statPill('+500', 'CRÉATEURS'),
        const SizedBox(width: 8),
        _statPill('+2M', 'VUES/MOIS'),
        const SizedBox(width: 8),
        _statPill('~300K', 'FCFA/MOIS'),
      ],
    );
  }

  Widget _statPill(String num, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x12FFFFFF),
        border: Border.all(color: const Color(0x1FFFFFFF)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            num,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _kGold,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: Color(0x80FFFFFF),
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProof() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _kGold.withOpacity(0.09),
        border: Border.all(color: _kGold.withOpacity(0.25)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('⭐', style: TextStyle(fontSize: 15, height: 1.4)),
          SizedBox(width: 9),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Rejoignez +500 créateurs ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kGold,
                    ),
                  ),
                  TextSpan(
                    text: 'qui monétisent déjà leur talent sur Afrolook.',
                    style: TextStyle(fontSize: 12, color: Color(0xDDFFFFFF)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      children: List.generate(_kSlides.length, (i) {
        final active = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(right: 5),
          width: active ? 20.0 : 4.0,
          height: 4.0,
          decoration: BoxDecoration(
            color: active ? _kGold : const Color(0x40FFFFFF),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
