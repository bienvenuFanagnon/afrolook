import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/tr.dart';

/// Écran de démarrage : photo de créateur plein écran (différente à chaque
/// ouverture), logo, accroche sur la monétisation et barre de chargement dorée.
class CreatorSplash extends StatefulWidget {
  /// Étape en cours (« Connexion… », « Chargement des données… »…).
  final String loadingText;

  /// Bloc optionnel sous la barre (ex. aperçu du post ou du chat à ouvrir).
  final Widget? footer;

  const CreatorSplash({super.key, required this.loadingText, this.footer});

  @override
  State<CreatorSplash> createState() => _CreatorSplashState();
}

class _CreatorSplashState extends State<CreatorSplash> with TickerProviderStateMixin {
  static const _gold = Color(0xFFF5C542);
  static const _green = Color(0xFF2ECC71);

  static const _images = [
    'assets/images/intro1.jpg',
    'assets/images/intro2.jpg',
    'assets/images/intro3.jpg',
    'assets/images/intro4.jpg',
    'assets/images/intro5.jpg',
    'assets/images/intro6.jpg',
    'assets/images/intro7.jpg',
  ];

  static const _creators = [
    ('@amina.style', '18,2k'),
    ('@kofi.drip', '8,1k'),
    ('@nadia.vibes', '12,4k'),
    ('@zuri.look', '9,6k'),
    ('@awa.studio', '31,5k'),
    ('@nia.daily', '24,1k'),
    ('@lina.vibes', '14,7k'),
  ];

  // (surtitre, début du titre, fin du titre en or, sous-titre)
  static const _lines = [
    ('Le réseau social qui paie', 'Tes likes valent ', 'de l\'argent.', 'Chaque like, chaque vue, chaque cadeau rapporte au créateur.'),
    ('Publie. Encaisse.', 'Ton talent mérite ', 'd\'être payé.', 'Tes posts travaillent pour toi, jour et nuit.'),
    ('Chaque vue compte', 'Tes vues deviennent ', 'des revenus.', 'Deviens créateur et retire tes gains quand tu veux.'),
    ('Pour tous les créateurs', 'Montre ce que tu sais faire, ', 'on te paie.', 'Photos, vidéos, lives : tout ce que tu partages peut te rapporter.'),
  ];

  late final AnimationController _zoom = AnimationController(vsync: this, duration: const Duration(seconds: 7))..forward();
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..forward();
  // Barre de chargement : avance vite puis ralentit (sans jamais s'arrêter tant que l'app charge)
  late final AnimationController _progress = AnimationController(vsync: this, duration: const Duration(seconds: 9))..forward();

  int _img = 0;
  late final int _line;
  late final int _coins;

  @override
  void initState() {
    super.initState();
    final r = math.Random();
    _img = r.nextInt(_images.length);
    _line = r.nextInt(_lines.length);
    _coins = 800 + r.nextInt(4200);
    _pickDifferentFromLast();
  }

  /// Évite de montrer deux fois de suite la même photo.
  Future<void> _pickDifferentFromLast() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt('splash_last_image') ?? -1;
      if (_img == last && mounted) setState(() => _img = (_img + 1) % _images.length);
      await prefs.setInt('splash_last_image', _img);
    } catch (_) {}
  }

  @override
  void dispose() {
    _zoom.dispose();
    _intro.dispose();
    _progress.dispose();
    super.dispose();
  }

  /// Apparition décalée d'un élément (0 → 1 entre [from] et [to] de l'intro).
  Widget _reveal(double from, double to, Widget child, {double dy = 14}) {
    return AnimatedBuilder(
      animation: _intro,
      builder: (_, c) {
        final t = Curves.easeOutCubic.transform(((_intro.value - from) / (to - from)).clamp(0.0, 1.0));
        return Opacity(opacity: t, child: Transform.translate(offset: Offset(0, dy * (1 - t)), child: c));
      },
      child: child,
    );
  }

  String _n(int v) {
    final s = v.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }

  @override
  Widget build(BuildContext context) {
    final line = _lines[_line];
    final creator = _creators[_img % _creators.length];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Photo qui avance doucement vers l'écran
            AnimatedBuilder(
              animation: _zoom,
              builder: (_, c) => Transform.scale(
                scale: 1.12 - 0.12 * Curves.easeOutCubic.transform(_zoom.value),
                child: c,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 700),
                child: Image.asset(_images[_img], key: ValueKey(_img), fit: BoxFit.cover,
                    width: double.infinity, height: double.infinity),
              ),
            ),
            // Dégradés pour la lisibilité
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0, 0.22, 0.45, 0.72, 1],
                  colors: [Color(0x8C000000), Color(0x00000000), Color(0x00030A07), Color(0xBF030A07), Color(0xF5030A07)],
                ),
              ),
            ),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _reveal(0.05, 0.4, Row(children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: _green),
                            padding: const EdgeInsets.all(3),
                            child: ClipOval(child: Image.asset('assets/logo/afrolook_logo.png', fit: BoxFit.cover)),
                          ),
                          const SizedBox(width: 9),
                          const Text('Afrolook',
                              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.2)),
                        ]), dy: -8),
                        const SizedBox(height: 14),
                        _reveal(0.2, 0.55, Container(
                          padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.38),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white.withOpacity(0.14)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            CircleAvatar(radius: 12, backgroundImage: AssetImage(_images[_img])),
                            const SizedBox(width: 7),
                            Text(creator.$1,
                                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                            const SizedBox(width: 6),
                            Text(context.tr('{a} abonnés', {'a': creator.$2}),
                                style: const TextStyle(color: Color(0xFF9DB0A6), fontSize: 11, fontWeight: FontWeight.w700)),
                          ]),
                        )),
                        const Spacer(),
                        _reveal(0.3, 0.65, Text(context.tr(line.$1).toUpperCase(),
                            style: const TextStyle(color: _gold, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: 1.6))),
                        const SizedBox(height: 8),
                        _reveal(0.38, 0.75, Text.rich(
                          TextSpan(children: [
                            TextSpan(text: context.tr(line.$2)),
                            TextSpan(text: context.tr(line.$3), style: const TextStyle(color: _gold)),
                          ]),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 33, height: 1.08, fontWeight: FontWeight.w900, letterSpacing: -0.6),
                        )),
                        const SizedBox(height: 10),
                        _reveal(0.46, 0.85, Text(context.tr(line.$4),
                            style: const TextStyle(color: Color(0xFFCFD9D4), fontSize: 14.5, height: 1.45, fontWeight: FontWeight.w600))),
                        const SizedBox(height: 16),
                        _reveal(0.55, 0.92, Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _gold.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _gold.withOpacity(0.45)),
                          ),
                          child: Text(context.tr('🪙 +{a} pièces aujourd\'hui', {'a': _n(_coins)}),
                              style: const TextStyle(color: _gold, fontSize: 13, fontWeight: FontWeight.w800)),
                        )),
                        const SizedBox(height: 22),
                        _reveal(0.6, 1.0, Column(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: SizedBox(
                              height: 3,
                              child: AnimatedBuilder(
                                animation: _progress,
                                builder: (_, __) {
                                  // 0 → 0,95 en ralentissant
                                  final v = 0.95 * (1 - math.pow(1 - _progress.value, 2.4));
                                  return Stack(children: [
                                    Container(color: Colors.white.withOpacity(0.14)),
                                    FractionallySizedBox(
                                      widthFactor: v.toDouble(),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(colors: [_green, _gold]),
                                          boxShadow: [BoxShadow(color: Color(0xB3F5C542), blurRadius: 10)],
                                        ),
                                      ),
                                    ),
                                  ]);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 9),
                          Row(children: [
                            Expanded(
                              child: Text(context.tr(widget.loadingText),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Color(0xFF9DB0A6), fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                            const _Dots(),
                          ]),
                          if (widget.footer != null) ...[const SizedBox(height: 14), widget.footer!],
                        ])),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trois points dorés qui pulsent.
class _Dots extends StatefulWidget {
  const _Dots();

  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = (math.sin((_c.value - i * 0.15) * 2 * math.pi) + 1) / 2;
          return Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF5C542).withOpacity(0.25 + 0.75 * t),
            ),
          );
        }),
      ),
    );
  }
}
