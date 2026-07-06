import 'dart:async';
import 'package:flutter/material.dart';

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

class BrandingCarouselPanel extends StatefulWidget {
  const BrandingCarouselPanel({Key? key}) : super(key: key);

  @override
  State<BrandingCarouselPanel> createState() => _BrandingCarouselPanelState();
}

class _BrandingCarouselPanelState extends State<BrandingCarouselPanel> {
  int _current = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleNext();
  }

  void _scheduleNext() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 4500), () {
      if (!mounted) return;
      setState(() => _current = (_current + 1) % _kSlides.length);
      _scheduleNext();
    });
  }

  void _goTo(int i) {
    _timer?.cancel();
    setState(() => _current = i);
    _scheduleNext();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Photos en crossfade ────────────────────────────────────────
        ...List.generate(_kSlides.length, (i) => AnimatedOpacity(
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOut,
          opacity: i == _current ? 1.0 : 0.0,
          child: Image.asset(
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
        )),

        // ── Overlay bas sombre ─────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.0, 0.38, 1.0],
              colors: [
                Color(0x28000000),
                Color(0x60000000),
                Color(0xE6000000),
              ],
            ),
          ),
        ),

        // ── Vignette droite légère ─────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0x00000000), Color(0x50000000)],
            ),
          ),
        ),

        // ── Contenu principal ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWordmark(),
              Expanded(child: _buildHero()),
              _buildStats(),
              const SizedBox(height: 12),
              _buildProof(),
              const SizedBox(height: 14),
              _buildDots(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Wordmark ─────────────────────────────────────────────────────────
  Widget _buildWordmark() {
    return Column(
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
        const SizedBox(height: 5),
        Container(width: 24, height: 2, color: _kGold),
      ],
    );
  }

  // ── Titre rotatif ─────────────────────────────────────────────────────
  Widget _buildHero() {
    return Align(
      alignment: Alignment.centerLeft,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 520),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: child,
          ),
        ),
        child: _buildSlideText(_kSlides[_current], ValueKey(_current)),
      ),
    );
  }

  Widget _buildSlideText(_Slide slide, Key key) {
    const ts = TextStyle(
      fontSize: 46,
      fontWeight: FontWeight.w800,
      height: 1.06,
      letterSpacing: -1.2,
    );
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(slide.line1, style: ts.copyWith(color: Colors.white)),
        Text(slide.lineGold, style: ts.copyWith(color: _kGold)),
        Text(slide.line3, style: ts.copyWith(color: Colors.white)),
        const SizedBox(height: 14),
        Text(
          slide.sub,
          style: const TextStyle(
            fontSize: 13.5,
            color: Color(0xA0FFFFFF),
            height: 1.6,
          ),
        ),
      ],
    );
  }

  // ── Stats pills ────────────────────────────────────────────────────────
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

  // ── Bannière social proof ──────────────────────────────────────────────
  Widget _buildProof() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withOpacity(0.09),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.25)),
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

  // ── Dots navigation ────────────────────────────────────────────────────
  Widget _buildDots() {
    return Row(
      children: List.generate(_kSlides.length, (i) {
        final active = i == _current;
        return GestureDetector(
          onTap: () => _goTo(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            margin: const EdgeInsets.only(right: 5),
            width: active ? 20.0 : 4.0,
            height: 4.0,
            decoration: BoxDecoration(
              color: active
                  ? _kGold
                  : const Color(0x40FFFFFF),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
