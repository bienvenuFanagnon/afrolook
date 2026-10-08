import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/contes/contes_service.dart';

/// Gravure d'un conte : un décor, une lumière et jusqu'à trois silhouettes, dessinés en code (vectoriel, aucun fichier).
/// Le même conte donne toujours la même image (la « graine » du conte fixe les positions).
class ConteScene extends StatelessWidget {
  const ConteScene({super.key, required this.spec, this.aspectRatio});
  final SceneSpec spec;

  /// Si renseigné, la gravure garde ce rapport largeur/hauteur ; sinon elle remplit l'espace donné.
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    final paint = RepaintBoundary(child: CustomPaint(painter: ConteScenePainter(spec), size: Size.infinite));
    final r = aspectRatio;
    return r == null ? paint : AspectRatio(aspectRatio: r, child: paint);
  }
}

class _Light {
  const _Light({required this.sky, required this.stops, required this.ink, required this.ground, required this.far, required this.sun, required this.sunPos, required this.sunR, this.moon = false, this.stars = false, this.storm = false, required this.glow});
  final List<Color> sky;
  final List<double> stops;
  final Color ink, ground, far, sun, glow;
  final Offset sunPos;
  final double sunR;
  final bool moon, stars, storm;
}

const Map<String, _Light> _lights = {
  'aube': _Light(
    sky: [Color(0xFF3B4A86), Color(0xFFD97F8F), Color(0xFFFFCF8F)], stops: [0, .55, 1],
    ink: Color(0xFF170F1D), ground: Color(0xFF261C2C), far: Color(0xFF7A4A6A), sun: Color(0xFFFFF1C1), sunPos: Offset(215, 138), sunR: 24, glow: Color(0xFFFFD27A),
  ),
  'midi': _Light(
    sky: [Color(0xFF4F9BD4), Color(0xFF9FD0E6), Color(0xFFF7E7B0)], stops: [0, .6, 1],
    ink: Color(0xFF20150C), ground: Color(0xFF4A321A), far: Color(0xFFC9A468), sun: Color(0xFFFFF6C9), sunPos: Offset(225, 42), sunR: 20, glow: Color(0xFFFFE9A8),
  ),
  'crepuscule': _Light(
    sky: [Color(0xFFF6B24A), Color(0xFFD9602F), Color(0xFF5B2A4A), Color(0xFF1D1A3A)], stops: [0, .42, .78, 1],
    ink: Color(0xFF120D1C), ground: Color(0xFF150F22), far: Color(0xFF6A2F3F), sun: Color(0xFFFFD98A), sunPos: Offset(150, 114), sunR: 30, glow: Color(0xFFFFB347),
  ),
  'nuit': _Light(
    sky: [Color(0xFF0E1636), Color(0xFF34306A)], stops: [0, 1],
    ink: Color(0xFF0A0818), ground: Color(0xFF14122E), far: Color(0xFF1B1A40), sun: Color(0xFFF7EFD2), sunPos: Offset(222, 50), sunR: 21, moon: true, stars: true, glow: Color(0xFFFFB347),
  ),
  'orage': _Light(
    sky: [Color(0xFF1A202C), Color(0xFF4A5568), Color(0xFF8A7C74)], stops: [0, .6, 1],
    ink: Color(0xFF0B0C10), ground: Color(0xFF12141A), far: Color(0xFF2B3140), sun: Color(0xFFB8B2A8), sunPos: Offset(80, 50), sunR: 16, storm: true, glow: Color(0xFFFFC857),
  ),
};

class ConteScenePainter extends CustomPainter {
  ConteScenePainter(this.spec);
  final SceneSpec spec;

  static const double w = 300, h = 190;

  @override
  bool shouldRepaint(ConteScenePainter old) => old.spec.decor != spec.decor || old.spec.light != spec.light || old.spec.seed != spec.seed || old.spec.figures.join() != spec.figures.join();

  @override
  void paint(Canvas canvas, Size size) {
    final L = _lights[spec.light] ?? _lights['crepuscule']!;
    final scale = math.max(size.width / w, size.height / h);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate((size.width - w * scale) / 2, (size.height - h * scale) / 2);
    canvas.scale(scale);
    final rnd = math.Random(spec.seed);
    final ink = Paint()..color = L.ink;
    final gy = spec.decor == 'fleuve' ? 152.0 : spec.decor == 'montagne' ? 160.0 : 158.0;

    _sky(canvas, L, rnd);
    final far = Paint()..color = L.far;
    _farLayer(canvas, far, L, gy, rnd);
    _midground(canvas, L, ink, gy, rnd);
    _ground(canvas, L, gy);
    _figures(canvas, L, ink, gy, rnd);
    _foreground(canvas, ink, gy, rnd);
    // vignette douce : donne l'aspect d'une estampe
    final vignette = Paint()
      ..shader = const RadialGradient(colors: [Color(0x00000000), Color(0x59000000)], stops: [.62, 1]).createShader(const Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(const Rect.fromLTWH(0, 0, w, h), vignette);
    canvas.restore();
  }

  // ── Ciel ──────────────────────────────────────────────────────────────────
  void _sky(Canvas c, _Light L, math.Random r) {
    final p = Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: L.sky, stops: L.stops).createShader(const Rect.fromLTWH(0, 0, w, h));
    c.drawRect(const Rect.fromLTWH(0, 0, w, h), p);
    if (L.stars) {
      final s = Paint()..color = const Color(0xFFF7EFD2);
      for (var i = 0; i < 38; i++) {
        c.drawCircle(Offset(r.nextDouble() * w, r.nextDouble() * 105), 0.5 + r.nextDouble() * 1.0, s);
      }
    }
    final glow = Paint()..shader = RadialGradient(colors: [L.sun.withOpacity(L.moon ? .55 : .85), L.sun.withOpacity(0)]).createShader(Rect.fromCircle(center: L.sunPos, radius: L.sunR * 2.4));
    c.drawCircle(L.sunPos, L.sunR * 2.4, glow);
    if (L.storm) {
      final cloud = Paint()..color = const Color(0xFF0E1118).withOpacity(.75);
      for (var i = 0; i < 9; i++) {
        final x = 20.0 + i * 34 + r.nextDouble() * 12;
        c.drawOval(Rect.fromCenter(center: Offset(x, 24 + r.nextDouble() * 22), width: 70 + r.nextDouble() * 30, height: 26 + r.nextDouble() * 10), cloud);
      }
      final bolt = Path()
        ..moveTo(206, 36)..lineTo(194, 78)..lineTo(204, 78)..lineTo(190, 118)..lineTo(216, 70)..lineTo(205, 70)..lineTo(218, 36)..close();
      c.drawPath(bolt, Paint()..color = const Color(0xFFFFF3B0));
    } else {
      c.drawCircle(L.sunPos, L.sunR, Paint()..color = L.sun);
      if (L.moon) {
        c.drawCircle(L.sunPos.translate(-5, -3), L.sunR * .22, Paint()..color = const Color(0x22000000));
        c.drawCircle(L.sunPos.translate(6, 5), L.sunR * .16, Paint()..color = const Color(0x1F000000));
      }
    }
  }

  // ── Plans lointains ───────────────────────────────────────────────────────
  void _farLayer(Canvas c, Paint far, _Light L, double gy, math.Random r) {
    switch (spec.decor) {
      case 'montagne':
        final p = Path()..moveTo(0, gy)..lineTo(0, 110)..lineTo(34, 70)..lineTo(58, 98)..lineTo(92, 52)..lineTo(130, 104)..lineTo(168, 66)..lineTo(204, 108)..lineTo(244, 60)..lineTo(300, 112)..lineTo(300, gy)..close();
        c.drawPath(p, far);
        break;
      case 'desert':
        final p = Path()..moveTo(0, gy)..lineTo(0, 132)..quadraticBezierTo(70, 108, 140, 130)..quadraticBezierTo(220, 150, 300, 118)..lineTo(300, gy)..close();
        c.drawPath(p, far);
        break;
      default:
        final p = Path()..moveTo(0, gy)..lineTo(0, 136)..quadraticBezierTo(60, 114, 120, 134)..quadraticBezierTo(180, 150, 240, 128)..quadraticBezierTo(275, 118, 300, 132)..lineTo(300, gy)..close();
        c.drawPath(p, far);
    }
  }

  // ── Décor du milieu ───────────────────────────────────────────────────────
  void _midground(Canvas c, _Light L, Paint ink, double gy, math.Random r) {
    switch (spec.decor) {
      case 'baobab':
        _baobab(c, ink, 104 + r.nextInt(30).toDouble(), gy, 1.0);
        _acacia(c, ink, 250, gy + 2, .75);
        break;
      case 'village':
        _hut(c, ink, L, 70, gy, 1.0);
        _hut(c, ink, L, 150, gy + 1, .85);
        _hut(c, ink, L, 232, gy - 1, 1.1);
        _acacia(c, ink, 28, gy + 2, .55);
        break;
      case 'foret':
        final far = Paint()..color = Color.lerp(L.ink, L.far, .55)!;
        for (var i = 0; i < 9; i++) {
          _tree(c, far, 14.0 + i * 34 + r.nextDouble() * 10, gy - 4, .7 + r.nextDouble() * .25);
        }
        for (var i = 0; i < 7; i++) {
          _tree(c, ink, 6.0 + i * 46 + r.nextDouble() * 16, gy + 3, .95 + r.nextDouble() * .5);
        }
        break;
      case 'fleuve':
        _acacia(c, ink, 36, gy + 1, .8);
        _palm(c, ink, 270, gy + 1, .9);
        break;
      case 'desert':
        _palm(c, ink, 52 + r.nextInt(30).toDouble(), gy - 2, 1.0);
        _palm(c, ink, 248, gy, .75);
        break;
      case 'montagne':
        final mid = Path()..moveTo(0, gy)..lineTo(0, 128)..lineTo(40, 100)..lineTo(78, 132)..lineTo(120, 108)..lineTo(168, 140)..lineTo(214, 112)..lineTo(262, 138)..lineTo(300, 120)..lineTo(300, gy)..close();
        c.drawPath(mid, Paint()..color = Color.lerp(L.ink, L.far, .35)!);
        break;
      default: // savane
        _acacia(c, ink, 62 + r.nextInt(20).toDouble(), gy + 1, 1.0);
        _acacia(c, ink, 236 + r.nextInt(18).toDouble(), gy, .8);
    }
  }

  void _ground(Canvas c, _Light L, double gy) {
    if (spec.decor == 'fleuve') {
      final bank = Path()..moveTo(0, gy)..quadraticBezierTo(60, gy - 6, 110, gy)..lineTo(110, h)..lineTo(0, h)..close();
      final water = Paint()
        ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [L.sky.last.withOpacity(.85), Color.lerp(L.sky.first, L.ink, .5)!]).createShader(Rect.fromLTWH(0, gy, w, h - gy));
      c.drawRect(Rect.fromLTWH(0, gy + 1, w, h - gy), water);
      final ripple = Paint()..color = Colors.white.withOpacity(.18)..style = PaintingStyle.stroke..strokeWidth = 1;
      for (var i = 0; i < 9; i++) {
        final y = gy + 10 + i * 4.2;
        c.drawLine(Offset(120 + (i * 37) % 140, y), Offset(150 + (i * 37) % 140, y), ripple);
      }
      c.drawPath(bank, Paint()..color = L.ground);
      final bank2 = Path()..moveTo(300, gy + 4)..quadraticBezierTo(250, gy - 2, 226, gy + 6)..lineTo(226, h)..lineTo(300, h)..close();
      c.drawPath(bank2, Paint()..color = L.ground);
      return;
    }
    final g = Path()..moveTo(0, gy)..quadraticBezierTo(75, gy - 8, 150, gy)..quadraticBezierTo(225, gy + 8, 300, gy - 2)..lineTo(300, h)..lineTo(0, h)..close();
    c.drawPath(g, Paint()..color = L.ground);
  }

  void _foreground(Canvas c, Paint ink, double gy, math.Random r) {
    final p = Paint()..color = ink.color..style = PaintingStyle.stroke..strokeWidth = 1.6..strokeCap = StrokeCap.round;
    for (var i = 0; i < 18; i++) {
      final x = r.nextDouble() * w;
      final y = gy + 12 + r.nextDouble() * (h - gy - 10);
      final hgt = 5 + r.nextDouble() * 8;
      c.drawLine(Offset(x, y), Offset(x - 2, y - hgt), p);
      c.drawLine(Offset(x, y), Offset(x + 2.4, y - hgt * .8), p);
      c.drawLine(Offset(x, y), Offset(x + .4, y - hgt * 1.15), p);
    }
    c.drawRect(Rect.fromLTWH(0, h - 8, w, 8), Paint()..color = ink.color);
  }

  // ── Éléments de décor ─────────────────────────────────────────────────────
  void _baobab(Canvas c, Paint ink, double cx, double gy, double s) {
    final trunk = Path()
      ..moveTo(cx - 16 * s, gy)
      ..cubicTo(cx - 11 * s, gy - 28 * s, cx - 18 * s, gy - 46 * s, cx - 10 * s, gy - 64 * s)
      ..lineTo(cx + 10 * s, gy - 64 * s)
      ..cubicTo(cx + 18 * s, gy - 46 * s, cx + 11 * s, gy - 28 * s, cx + 16 * s, gy)
      ..close();
    c.drawPath(trunk, ink);
    final br = Paint()..color = ink.color..style = PaintingStyle.stroke..strokeWidth = 5 * s..strokeCap = StrokeCap.round;
    final top = Offset(cx, gy - 64 * s);
    final ends = [Offset(-58, -90), Offset(60, -92), Offset(-20, -112), Offset(24, -118), Offset(-40, -100), Offset(42, -104)];
    for (final e in ends) {
      c.drawLine(top, Offset(cx + e.dx * s, gy + e.dy * s), br);
    }
    const blobs = [Offset(-60, -92), Offset(-42, -104), Offset(-22, -113), Offset(0, -120), Offset(22, -118), Offset(44, -106), Offset(62, -94), Offset(-30, -88), Offset(30, -90), Offset(0, -98)];
    for (var i = 0; i < blobs.length; i++) {
      c.drawCircle(Offset(cx + blobs[i].dx * s, gy + blobs[i].dy * s), (11 + (i % 3) * 2) * s, ink);
    }
  }

  void _acacia(Canvas c, Paint ink, double cx, double gy, double s) {
    final t = Paint()..color = ink.color..style = PaintingStyle.stroke..strokeWidth = 3.4 * s..strokeCap = StrokeCap.round;
    final trunk = Path()..moveTo(cx, gy)..cubicTo(cx - 3 * s, gy - 22 * s, cx + 3 * s, gy - 34 * s, cx, gy - 46 * s);
    c.drawPath(trunk, t);
    c.drawLine(Offset(cx, gy - 36 * s), Offset(cx - 18 * s, gy - 52 * s), t);
    c.drawLine(Offset(cx, gy - 38 * s), Offset(cx + 20 * s, gy - 54 * s), t);
    c.drawOval(Rect.fromCenter(center: Offset(cx, gy - 52 * s), width: 74 * s, height: 13 * s), ink);
    c.drawOval(Rect.fromCenter(center: Offset(cx - 22 * s, gy - 58 * s), width: 36 * s, height: 10 * s), ink);
    c.drawOval(Rect.fromCenter(center: Offset(cx + 24 * s, gy - 60 * s), width: 34 * s, height: 10 * s), ink);
  }

  void _tree(Canvas c, Paint ink, double cx, double gy, double s) {
    c.drawRect(Rect.fromLTWH(cx - 2.5 * s, gy - 30 * s, 5 * s, 30 * s), ink);
    c.drawCircle(Offset(cx, gy - 38 * s), 13 * s, ink);
    c.drawCircle(Offset(cx - 10 * s, gy - 32 * s), 10 * s, ink);
    c.drawCircle(Offset(cx + 10 * s, gy - 33 * s), 10 * s, ink);
    c.drawCircle(Offset(cx, gy - 48 * s), 9 * s, ink);
  }

  void _palm(Canvas c, Paint ink, double cx, double gy, double s) {
    final t = Paint()..color = ink.color..style = PaintingStyle.stroke..strokeWidth = 3 * s..strokeCap = StrokeCap.round;
    final trunk = Path()..moveTo(cx, gy)..quadraticBezierTo(cx + 8 * s, gy - 34 * s, cx + 3 * s, gy - 62 * s);
    c.drawPath(trunk, t);
    final top = Offset(cx + 3 * s, gy - 62 * s);
    final f = Paint()..color = ink.color..style = PaintingStyle.stroke..strokeWidth = 2.2 * s..strokeCap = StrokeCap.round;
    for (final a in [-2.5, -2.0, -1.45, -.95, -.5, -.1]) {
      final end = top + Offset(math.cos(a) * 26 * s, math.sin(a) * 15 * s + 11 * s);
      final path = Path()..moveTo(top.dx, top.dy)..quadraticBezierTo(top.dx + math.cos(a) * 14 * s, top.dy - 10 * s, end.dx, end.dy);
      c.drawPath(path, f);
    }
  }

  void _hut(Canvas c, Paint ink, _Light L, double cx, double gy, double s) {
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(cx - 20 * s, gy - 22 * s, 40 * s, 22 * s), Radius.circular(2 * s)), ink);
    final roof = Path()..moveTo(cx - 28 * s, gy - 20 * s)..quadraticBezierTo(cx - 8 * s, gy - 38 * s, cx, gy - 52 * s)..quadraticBezierTo(cx + 8 * s, gy - 38 * s, cx + 28 * s, gy - 20 * s)..close();
    c.drawPath(roof, ink);
    if (spec.light != 'midi') {
      c.drawRRect(RRect.fromRectAndCorners(Rect.fromLTWH(cx - 4 * s, gy - 13 * s, 8 * s, 13 * s), topLeft: Radius.circular(4 * s), topRight: Radius.circular(4 * s)), Paint()..color = L.glow.withOpacity(.9));
    }
  }

  // ── Silhouettes ───────────────────────────────────────────────────────────
  void _figures(Canvas c, _Light L, Paint ink, double gy, math.Random r) {
    final figs = spec.figures.take(3).toList();
    final slots = figs.length == 1 ? [150.0] : figs.length == 2 ? [100.0, 205.0] : [62.0, 150.0, 238.0];
    if (figs.length == 2 && r.nextBool()) slots.setAll(0, slots.reversed.toList());
    // le feu d'abord (il est derrière les autres) ; l'oiseau et l'araignée vivent dans l'air
    final order = [...figs]..sort((a, b) => (a == 'feu' ? 0 : 1).compareTo(b == 'feu' ? 0 : 1));
    for (final f in order) {
      final i = figs.indexOf(f);
      final x = slots[i] + (r.nextDouble() * 14 - 7);
      final flip = (spec.seed + i) % 3 == 0;
      c.save();
      c.translate(x, gy + 12 + (f == 'oiseau' || f == 'araignee' ? 0 : r.nextDouble() * 8));
      final sc = _sizeOf(f);
      c.scale(flip ? -sc : sc, sc);
      _figure(c, f, ink, L);
      c.restore();
    }
  }

  double _sizeOf(String f) {
    switch (f) {
      case 'elephant':
        return 1.45;
      case 'lion':
      case 'crocodile':
      case 'hyene':
        return 1.25;
      case 'lievre':
      case 'tortue':
      case 'calebasse':
      case 'serpent':
        return 1.3;
      case 'reine':
      case 'guerrier':
      case 'ancien':
        return 1.15;
      default:
        return 1.2;
    }
  }

  void _figure(Canvas c, String f, Paint ink, _Light L) {
    switch (f) {
      case 'lievre':
        c.drawOval(Rect.fromCenter(center: const Offset(0, -12), width: 26, height: 16), ink);
        c.drawOval(Rect.fromCenter(center: const Offset(-6, -10), width: 16, height: 16), ink);
        c.drawCircle(const Offset(14, -18), 6, ink);
        _rotOval(c, ink, const Offset(13, -31), 4.4, 18, -.2);
        _rotOval(c, ink, const Offset(19, -30), 4.4, 17, .28);
        c.drawCircle(const Offset(-14, -13), 3.6, ink);
        c.drawRect(const Rect.fromLTWH(8, -8, 3, 8), ink);
        c.drawOval(Rect.fromCenter(center: const Offset(-9, -2), width: 14, height: 5), ink);
        c.drawCircle(const Offset(16, -19), 1.2, Paint()..color = L.sun);
        break;
      case 'hyene':
        final body = Path()
          ..moveTo(10, -34)..cubicTo(2, -37, -8, -32, -16, -22)..cubicTo(-19, -17, -14, -12, -9, -12)..lineTo(9, -13)..cubicTo(15, -14, 17, -21, 15, -28)..close();
        c.drawPath(body, ink);
        c.drawCircle(const Offset(19, -25), 7, ink);
        c.drawOval(Rect.fromCenter(center: const Offset(26, -22), width: 14, height: 7), ink);
        _rotOval(c, ink, const Offset(16, -32), 5, 8, -.4);
        c.drawRect(const Rect.fromLTWH(7, -14, 4, 14), ink);
        c.drawRect(const Rect.fromLTWH(1, -14, 4, 14), ink);
        c.drawRect(const Rect.fromLTWH(-13, -14, 4, 14), ink);
        c.drawRect(const Rect.fromLTWH(-8, -14, 4, 14), ink);
        c.drawLine(const Offset(-16, -22), const Offset(-21, -10), Paint()..color = ink.color..strokeWidth = 3..strokeCap = StrokeCap.round);
        c.drawCircle(const Offset(21, -26), 1.1, Paint()..color = L.sun);
        break;
      case 'araignee':
        final line = Paint()..color = ink.color..style = PaintingStyle.stroke..strokeWidth = 1;
        c.drawLine(const Offset(0, -240), const Offset(0, -72), line);
        c.drawOval(Rect.fromCenter(center: const Offset(0, -64), width: 12, height: 15), ink);
        c.drawCircle(const Offset(0, -75), 4.5, ink);
        final leg = Paint()..color = ink.color..style = PaintingStyle.stroke..strokeWidth = 1.8..strokeCap = StrokeCap.round;
        for (final s in [-1.0, 1.0]) {
          c.drawPath(Path()..moveTo(0, -68)..lineTo(s * 12, -84)..lineTo(s * 20, -78), leg);
          c.drawPath(Path()..moveTo(0, -65)..lineTo(s * 15, -70)..lineTo(s * 24, -62), leg);
          c.drawPath(Path()..moveTo(0, -62)..lineTo(s * 14, -56)..lineTo(s * 22, -46), leg);
          c.drawPath(Path()..moveTo(0, -59)..lineTo(s * 10, -46)..lineTo(s * 15, -36), leg);
        }
        break;
      case 'lion':
        for (var k = 0; k < 14; k++) {
          final a = k * math.pi * 2 / 14;
          c.drawCircle(Offset(6 + math.cos(a) * 14, -30 + math.sin(a) * 14), 5, ink);
        }
        c.drawCircle(const Offset(6, -30), 14, ink);
        c.drawOval(Rect.fromCenter(center: const Offset(-14, -17), width: 40, height: 20), ink);
        c.drawRect(const Rect.fromLTWH(-30, -14, 5, 14), ink);
        c.drawRect(const Rect.fromLTWH(-20, -14, 5, 14), ink);
        c.drawRect(const Rect.fromLTWH(-3, -14, 5, 14), ink);
        c.drawRect(const Rect.fromLTWH(5, -14, 5, 14), ink);
        final tail = Paint()..color = ink.color..style = PaintingStyle.stroke..strokeWidth = 2.4..strokeCap = StrokeCap.round;
        c.drawPath(Path()..moveTo(-33, -20)..cubicTo(-42, -22, -42, -34, -38, -38), tail);
        c.drawCircle(const Offset(-38, -39), 3.6, ink);
        c.drawCircle(const Offset(12, -32), 1.2, Paint()..color = L.sun);
        break;
      case 'tortue':
        c.drawArc(Rect.fromCenter(center: const Offset(0, -6), width: 36, height: 28), math.pi, math.pi, true, ink);
        c.drawCircle(const Offset(20, -9), 4.2, ink);
        c.drawRect(const Rect.fromLTWH(13, -10, 8, 4), ink);
        c.drawRect(const Rect.fromLTWH(-12, -6, 6, 6), ink);
        c.drawRect(const Rect.fromLTWH(6, -6, 6, 6), ink);
        c.drawLine(const Offset(-16, -5), const Offset(-22, -3), Paint()..color = ink.color..strokeWidth = 2.4..strokeCap = StrokeCap.round);
        final seam = Paint()..color = L.far.withOpacity(.6)..style = PaintingStyle.stroke..strokeWidth = 1;
        c.drawArc(Rect.fromCenter(center: const Offset(0, -6), width: 22, height: 17), math.pi, math.pi, false, seam);
        c.drawLine(const Offset(0, -20), const Offset(0, -6), seam);
        break;
      case 'elephant':
        c.drawOval(Rect.fromCenter(center: const Offset(-2, -26), width: 50, height: 32), ink);
        c.drawCircle(const Offset(23, -33), 11, ink);
        final trunk = Paint()..color = ink.color..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round;
        c.drawPath(Path()..moveTo(31, -32)..cubicTo(38, -22, 36, -10, 30, -4)..cubicTo(28, -1, 33, 2, 36, -2), trunk);
        _rotOval(c, ink, const Offset(15, -32), 8, 12, .1);
        for (final x in [-20.0, -10.0, 4.0, 14.0]) {
          c.drawRect(Rect.fromLTWH(x - 3, -16, 6.5, 16), ink);
        }
        c.drawLine(const Offset(-26, -30), const Offset(-30, -14), Paint()..color = ink.color..strokeWidth = 2..strokeCap = StrokeCap.round);
        c.drawPath(Path()..moveTo(30, -26)..quadraticBezierTo(38, -22, 40, -28), Paint()..color = const Color(0xFFE8DBB4)..style = PaintingStyle.stroke..strokeWidth = 1.8);
        break;
      case 'oiseau':
        final p = Path()
          ..moveTo(-4, -78)..quadraticBezierTo(-16, -92, -34, -88)..quadraticBezierTo(-22, -84, -18, -76)..quadraticBezierTo(-10, -72, 0, -74)
          ..quadraticBezierTo(10, -72, 18, -76)..quadraticBezierTo(22, -84, 34, -88)..quadraticBezierTo(16, -92, 4, -78)..close();
        c.drawPath(p, ink);
        c.drawOval(Rect.fromCenter(center: const Offset(0, -75), width: 14, height: 6), ink);
        c.drawCircle(const Offset(8, -76), 3, ink);
        c.drawPath(Path()..moveTo(11, -76)..lineTo(16, -75)..lineTo(11, -74)..close(), ink);
        break;
      case 'singe':
        c.drawOval(Rect.fromCenter(center: const Offset(0, -14), width: 18, height: 24), ink);
        c.drawCircle(const Offset(2, -31), 7, ink);
        c.drawCircle(const Offset(-5, -33), 3, ink);
        c.drawCircle(const Offset(9, -33), 3, ink);
        final arm = Paint()..color = ink.color..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round;
        c.drawLine(const Offset(6, -22), const Offset(14, -10), arm);
        c.drawLine(const Offset(-6, -22), const Offset(-13, -9), arm);
        c.drawPath(Path()..moveTo(-8, -6)..cubicTo(-22, -4, -26, -20, -16, -26)..cubicTo(-12, -28, -14, -20, -18, -18), arm);
        c.drawOval(Rect.fromCenter(center: const Offset(0, -2), width: 22, height: 6), ink);
        break;
      case 'crocodile':
        final body = Path()..moveTo(32, -8)..lineTo(10, -10)..lineTo(6, -13)..lineTo(0, -10)..lineTo(-6, -14)..lineTo(-12, -10)..lineTo(-18, -13)..lineTo(-24, -9)..lineTo(-40, -3)..lineTo(-24, -2)..lineTo(-12, -2)..lineTo(10, -2)..lineTo(34, -3)..close();
        c.drawPath(body, ink);
        c.drawRect(const Rect.fromLTWH(-12, -4, 5, 5), ink);
        c.drawRect(const Rect.fromLTWH(10, -4, 5, 5), ink);
        c.drawCircle(const Offset(22, -9), 1.4, Paint()..color = L.sun);
        break;
      case 'serpent':
        final s = Paint()..color = ink.color..style = PaintingStyle.stroke..strokeWidth = 5..strokeCap = StrokeCap.round;
        c.drawPath(Path()..moveTo(-26, -2)..cubicTo(-16, -18, -6, 4, 6, -8)..cubicTo(14, -16, 20, -26, 16, -36), s);
        c.drawCircle(const Offset(16, -37), 3.8, ink);
        c.drawLine(const Offset(18, -40), const Offset(22, -43), Paint()..color = ink.color..strokeWidth = 1);
        break;
      case 'enfant':
        c.drawCircle(const Offset(0, -29), 5.4, ink);
        c.drawPath(Path()..moveTo(-5, -23)..lineTo(5, -23)..lineTo(7, -8)..lineTo(-7, -8)..close(), ink);
        c.drawRect(const Rect.fromLTWH(-5, -9, 3.6, 9), ink);
        c.drawRect(const Rect.fromLTWH(1.4, -9, 3.6, 9), ink);
        final arm = Paint()..color = ink.color..style = PaintingStyle.stroke..strokeWidth = 2.6..strokeCap = StrokeCap.round;
        c.drawLine(const Offset(-5, -21), const Offset(-11, -29), arm);
        c.drawLine(const Offset(5, -21), const Offset(11, -27), arm);
        break;
      case 'ancien':
        c.drawCircle(const Offset(3, -35), 5.4, ink);
        c.drawPath(Path()..moveTo(-3, -30)..cubicTo(-8, -22, -9, -10, -9, 0)..lineTo(10, 0)..cubicTo(9, -12, 10, -24, 8, -30)..close(), ink);
        c.drawPath(Path()..moveTo(-1, -31)..cubicTo(-9, -30, -10, -26, -9, -22)..lineTo(-5, -23)..close(), ink);
        c.drawLine(const Offset(15, -30), const Offset(16, 0), Paint()..color = ink.color..strokeWidth = 2.2..strokeCap = StrokeCap.round);
        c.drawLine(const Offset(9, -24), const Offset(15, -26), Paint()..color = ink.color..strokeWidth = 2.4..strokeCap = StrokeCap.round);
        c.drawPath(Path()..moveTo(5, -31)..lineTo(10, -28)..lineTo(6, -26)..close(), Paint()..color = const Color(0xFFE8DBB4).withOpacity(.55));
        break;
      case 'reine':
        c.drawCircle(const Offset(0, -45), 5.2, ink);
        // haute coiffe enroulée (gélé) et plume
        c.drawOval(Rect.fromCenter(center: const Offset(1, -55), width: 17, height: 17), ink);
        c.drawPath(Path()..moveTo(4, -62)..quadraticBezierTo(8, -70, 15, -69)..quadraticBezierTo(10, -66, 8, -60)..close(), ink);
        c.drawPath(Path()..moveTo(-6, -39)..lineTo(6, -39)..lineTo(15, 0)..lineTo(-15, 0)..close(), ink);
        final arm = Paint()..color = ink.color..style = PaintingStyle.stroke..strokeWidth = 2.6..strokeCap = StrokeCap.round;
        c.drawLine(const Offset(-6, -37), const Offset(-12, -20), arm);
        c.drawLine(const Offset(6, -37), const Offset(12, -20), arm);
        final gem = Paint()..color = const Color(0xFFE6B758);
        c.drawCircle(const Offset(0, -35), 1.4, gem);
        c.drawLine(const Offset(-12, -10), const Offset(12, -10), Paint()..color = const Color(0xFFE6B758).withOpacity(.7)..strokeWidth = 1);
        break;
      case 'guerrier':
        c.drawCircle(const Offset(0, -42), 5.2, ink);
        c.drawPath(Path()..moveTo(0, -47)..quadraticBezierTo(3, -56, -3, -58)..quadraticBezierTo(-1, -52, -3, -47)..close(), ink);
        c.drawPath(Path()..moveTo(-6, -37)..lineTo(6, -37)..lineTo(5, -15)..lineTo(-5, -15)..close(), ink);
        c.drawRect(const Rect.fromLTWH(-5, -16, 4, 16), ink);
        c.drawRect(const Rect.fromLTWH(1, -16, 4, 16), ink);
        c.drawLine(const Offset(13, -62), const Offset(13, 0), Paint()..color = ink.color..strokeWidth = 1.8);
        c.drawPath(Path()..moveTo(13, -68)..lineTo(10.5, -60)..lineTo(15.5, -60)..close(), ink);
        c.drawLine(const Offset(6, -34), const Offset(13, -30), Paint()..color = ink.color..strokeWidth = 2.4..strokeCap = StrokeCap.round);
        c.drawOval(Rect.fromCenter(center: const Offset(-11, -27), width: 9, height: 24), ink);
        break;
      case 'griot':
        c.drawCircle(const Offset(0, -26), 5.2, ink);
        c.drawPath(Path()..moveTo(-5, -21)..lineTo(5, -21)..lineTo(6, -8)..lineTo(-6, -8)..close(), ink);
        c.drawOval(Rect.fromCenter(center: const Offset(0, -5), width: 26, height: 9), ink);
        c.drawArc(Rect.fromCenter(center: const Offset(10, -11), width: 16, height: 16), 0, math.pi, true, ink);
        final neck = Paint()..color = ink.color..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round;
        c.drawLine(const Offset(10, -12), const Offset(22, -34), neck);
        final strings = Paint()..color = L.glow.withOpacity(.8)..strokeWidth = .7;
        for (var k = 0; k < 3; k++) {
          c.drawLine(Offset(8 + k * 2.4, -12), Offset(20 + k * 1.2, -33), strings);
        }
        c.drawLine(const Offset(5, -17), const Offset(11, -13), neck);
        break;
      case 'tambour':
        final p = Path()..moveTo(-10, -28)..quadraticBezierTo(-12, -16, -5, -11)..quadraticBezierTo(-12, -6, -9, 0)..lineTo(9, 0)..quadraticBezierTo(12, -6, 5, -11)..quadraticBezierTo(12, -16, 10, -28)..close();
        c.drawPath(p, ink);
        c.drawOval(Rect.fromCenter(center: const Offset(0, -28), width: 20, height: 6), Paint()..color = L.far.withOpacity(.95));
        final rope = Paint()..color = const Color(0xFFE6B758).withOpacity(.75)..strokeWidth = 1;
        c.drawLine(const Offset(-8, -26), const Offset(-4, -10), rope);
        c.drawLine(const Offset(8, -26), const Offset(4, -10), rope);
        c.drawLine(const Offset(-5, -22), const Offset(5, -14), rope);
        c.drawLine(const Offset(5, -22), const Offset(-5, -14), rope);
        break;
      case 'masque':
        c.drawLine(const Offset(0, 0), const Offset(0, -30), Paint()..color = ink.color..strokeWidth = 2.6);
        c.drawPath(Path()..moveTo(0, -62)..cubicTo(-12, -62, -14, -46, -10, -36)..cubicTo(-6, -28, -2, -26, 0, -26)..cubicTo(2, -26, 6, -28, 10, -36)..cubicTo(14, -46, 12, -62, 0, -62)..close(), ink);
        c.drawPath(Path()..moveTo(0, -62)..lineTo(-4, -70)..lineTo(4, -70)..close(), ink);
        final eye = Paint()..color = L.glow;
        c.drawPath(Path()..moveTo(-8, -52)..quadraticBezierTo(-4, -56, -1, -52)..quadraticBezierTo(-4, -50, -8, -52)..close(), eye);
        c.drawPath(Path()..moveTo(8, -52)..quadraticBezierTo(4, -56, 1, -52)..quadraticBezierTo(4, -50, 8, -52)..close(), eye);
        c.drawRect(const Rect.fromLTWH(-1.2, -48, 2.4, 12), eye);
        break;
      case 'calebasse':
        c.drawCircle(const Offset(0, -9), 9, ink);
        c.drawCircle(const Offset(0, -21), 5.2, ink);
        c.drawRect(const Rect.fromLTWH(-2.2, -30, 4.4, 8), ink);
        c.drawArc(Rect.fromCenter(center: const Offset(0, -9), width: 12, height: 12), .3, 2.2, false, Paint()..color = L.far.withOpacity(.7)..style = PaintingStyle.stroke..strokeWidth = 1);
        break;
      case 'pirogue':
        c.drawPath(Path()..moveTo(-34, -8)..quadraticBezierTo(-26, 0, 0, 0)..quadraticBezierTo(26, 0, 34, -8)..quadraticBezierTo(24, -4, 0, -4)..quadraticBezierTo(-24, -4, -34, -8)..close(), ink);
        c.drawCircle(const Offset(-6, -19), 4.4, ink);
        c.drawPath(Path()..moveTo(-10, -14)..lineTo(-2, -14)..lineTo(-1, -5)..lineTo(-11, -5)..close(), ink);
        c.drawLine(const Offset(2, -16), const Offset(14, 2), Paint()..color = ink.color..strokeWidth = 1.8..strokeCap = StrokeCap.round);
        break;
      case 'feu':
        final glow = Paint()..shader = RadialGradient(colors: [L.glow.withOpacity(.65), L.glow.withOpacity(0)]).createShader(Rect.fromCircle(center: const Offset(0, -12), radius: 34));
        c.drawCircle(const Offset(0, -12), 34, glow);
        c.drawLine(const Offset(-14, -1), const Offset(12, -6), Paint()..color = ink.color..strokeWidth = 3.4..strokeCap = StrokeCap.round);
        c.drawLine(const Offset(14, -1), const Offset(-12, -6), Paint()..color = ink.color..strokeWidth = 3.4..strokeCap = StrokeCap.round);
        c.drawPath(Path()..moveTo(-8, -5)..quadraticBezierTo(-12, -16, -3, -22)..quadraticBezierTo(-5, -14, 0, -12)..quadraticBezierTo(-1, -26, 6, -32)..quadraticBezierTo(5, -20, 11, -14)..quadraticBezierTo(14, -8, 8, -5)..close(), Paint()..color = const Color(0xFFFF9A3C));
        c.drawPath(Path()..moveTo(-3, -5)..quadraticBezierTo(-5, -11, 0, -15)..quadraticBezierTo(4, -11, 3, -5)..close(), Paint()..color = const Color(0xFFFFE08A));
        break;
      default:
        c.drawCircle(const Offset(0, -10), 6, ink);
    }
  }

  void _rotOval(Canvas c, Paint p, Offset center, double rx, double ry, double angle) {
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(angle);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: rx * 2, height: ry * 2), p);
    c.restore();
  }
}
