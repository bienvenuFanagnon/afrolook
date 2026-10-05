import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Humeur de la mascotte : elle réagit aux réponses du joueur.
enum HawkMood { idle, cheer, sad, wave, think }

/// Épervier, mascotte du quiz, dessiné en code (aucune image à charger) et animé :
/// il respire, cligne des yeux, saute de joie, baisse la tête quand on se trompe, salue de l'aile.
/// [accessory] : `acc_glasses`, `acc_cap` ou `acc_crown` (objets de la boutique).
class HawkMascot extends StatefulWidget {
  const HawkMascot({super.key, this.mood = HawkMood.idle, this.size = 120, this.accessory, this.flip = false});

  final HawkMood mood;
  final double size;
  final String? accessory;
  final bool flip;

  @override
  State<HawkMascot> createState() => _HawkMascotState();
}

class _HawkMascotState extends State<HawkMascot> with TickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  late final AnimationController _react = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void initState() {
    super.initState();
    if (widget.mood != HawkMood.idle) _react.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant HawkMascot old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) {
      if (widget.mood == HawkMood.idle) {
        _react.value = 0;
      } else {
        _react.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    _react.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: Listenable.merge([_idle, _react]),
          builder: (_, __) => Transform(
            alignment: Alignment.center,
            transform: widget.flip ? (Matrix4.identity()..scale(-1.0, 1.0)) : Matrix4.identity(),
            child: CustomPaint(
              painter: _HawkPainter(_idle.value, _react.value, widget.mood, widget.accessory),
            ),
          ),
        ),
      ),
    );
  }
}

class _HawkPainter extends CustomPainter {
  _HawkPainter(this.idle, this.react, this.mood, this.accessory);

  final double idle, react;
  final HawkMood mood;
  final String? accessory;

  static const slate = Color(0xFF6F86A8);
  static const slateDark = Color(0xFF4C6086);
  static const slateLight = Color(0xFF93A8C7);
  static const cream = Color(0xFFF6EAD7);
  static const bar = Color(0xFFD9904F);
  static const beakColor = Color(0xFF2E3138);
  static const cere = Color(0xFFF2C94C);
  static const iris = Color(0xFFFFD43B);
  static const ink = Color(0xFF1F2638);

  Paint _fill(Color c) => Paint()..color = c..style = PaintingStyle.fill;
  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 200, size.height / 200);

    final bob = math.sin(idle * 2 * math.pi) * 2.5;
    double jump = 0;
    double tilt = 0;
    double flapL = 0;
    double flapR = 0;
    final settle = Curves.easeOut.transform(react.clamp(0.0, 1.0));

    switch (mood) {
      case HawkMood.cheer:
        jump = react < 0.9 ? -(math.sin(react * 2 * math.pi * 1.1)).abs() * 26 * (1 - react * 0.5) : 0;
        flapL = react < 0.85 ? math.sin(react * 14 * math.pi) * 0.55 + 0.5 : 0;
        flapR = flapL;
        break;
      case HawkMood.sad:
        tilt = -0.12 * settle;
        break;
      case HawkMood.wave:
        flapR = 0.9 + math.sin(react * 10 * math.pi) * 0.35;
        break;
      case HawkMood.think:
        tilt = 0.08 * settle;
        break;
      case HawkMood.idle:
        break;
    }

    // Ombre au sol (ne bouge pas avec le saut)
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(100, 192), width: 90 - jump.abs() * 0.8, height: 10),
      _fill(Colors.black.withOpacity(0.18)),
    );

    canvas.save();
    canvas.translate(0, bob * 0.6 + jump);
    canvas.translate(100, 170);
    canvas.rotate(tilt);
    canvas.translate(-100, -170);

    _tail(canvas);
    _wing(canvas, left: true, lift: flapL);
    _wing(canvas, left: false, lift: flapR);
    _body(canvas);
    _feet(canvas);
    _head(canvas, bob);
    canvas.restore();

    if (mood == HawkMood.cheer && react < 0.95) _sparkles(canvas);
  }

  void _tail(Canvas canvas) {
    final p = Path()
      ..moveTo(78, 160)
      ..lineTo(122, 160)
      ..lineTo(128, 198)
      ..lineTo(72, 198)
      ..close();
    canvas.drawPath(p, _fill(slateDark));
    for (var i = 0; i < 3; i++) {
      final y = 170.0 + i * 9;
      canvas.drawLine(Offset(76 - i * 0.5, y), Offset(124 + i * 0.5, y), _stroke(slateLight.withOpacity(0.65), 3));
    }
  }

  void _wing(Canvas canvas, {required bool left, required double lift}) {
    final sx = left ? 1.0 : -1.0;
    Offset m(double x, double y) => Offset(100 + (x - 100) * sx, y);
    canvas.save();
    final pivot = m(60, 104);
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(left ? lift : -lift);
    canvas.translate(-pivot.dx, -pivot.dy);
    final p = Path()
      ..moveTo(m(64, 96).dx, m(64, 96).dy)
      ..cubicTo(m(34, 104).dx, m(34, 104).dy, m(24, 150).dx, m(24, 150).dy, m(40, 184).dx, m(40, 184).dy)
      ..cubicTo(m(52, 176).dx, m(52, 176).dy, m(62, 150).dx, m(62, 150).dy, m(72, 130).dx, m(72, 130).dy)
      ..close();
    canvas.drawPath(p, _fill(slateDark));
    canvas.drawPath(p, _stroke(ink.withOpacity(0.35), 1.5));
    for (var i = 0; i < 3; i++) {
      final a = m(40 + i * 5.0, 128 + i * 14.0);
      final b = m(56 + i * 3.0, 124 + i * 12.0);
      canvas.drawLine(a, b, _stroke(slateLight.withOpacity(0.7), 2.5));
    }
    canvas.restore();
  }

  void _body(Canvas canvas) {
    final body = Rect.fromCenter(center: const Offset(100, 128), width: 108, height: 112);
    canvas.drawOval(body, _fill(slate));
    // Poitrine crème rayée de roux, comme l'épervier d'Europe
    final belly = Rect.fromCenter(center: const Offset(100, 140), width: 72, height: 84);
    canvas.save();
    canvas.clipPath(Path()..addOval(belly));
    canvas.drawRect(belly, _fill(cream));
    for (var y = 108.0; y < 186; y += 11) {
      final p = Path()
        ..moveTo(64, y)
        ..quadraticBezierTo(100, y + 7, 136, y);
      canvas.drawPath(p, _stroke(bar, 3.2));
    }
    canvas.restore();
    canvas.drawOval(body, _stroke(ink.withOpacity(0.25), 1.5));
  }

  void _feet(Canvas canvas) {
    for (final x in [86.0, 114.0]) {
      final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x, 188), width: 20, height: 9), const Radius.circular(4));
      canvas.drawRRect(r, _fill(cere));
      for (final dx in [-6.0, 0.0, 6.0]) {
        canvas.drawLine(Offset(x + dx, 190), Offset(x + dx + (dx == 0 ? 0 : dx * 0.3), 197), _stroke(cere, 3.2));
      }
    }
  }

  void _head(Canvas canvas, double bob) {
    final headRect = Rect.fromCircle(center: const Offset(100, 74), radius: 40);
    canvas.drawOval(headRect, _fill(slate));
    // Calotte plus sombre
    canvas.save();
    canvas.clipPath(Path()..addOval(headRect));
    canvas.drawOval(Rect.fromCenter(center: const Offset(100, 50), width: 96, height: 52), _fill(slateDark));
    canvas.drawOval(Rect.fromCenter(center: const Offset(66, 88), width: 26, height: 20), _fill(slateLight.withOpacity(0.55)));
    canvas.drawOval(Rect.fromCenter(center: const Offset(134, 88), width: 26, height: 20), _fill(slateLight.withOpacity(0.55)));
    canvas.restore();
    canvas.drawOval(headRect, _stroke(ink.withOpacity(0.25), 1.5));

    _eyes(canvas);
    _beak(canvas);
    _accessory(canvas);
  }

  double get _blink {
    final t = idle;
    double w(double a, double b) => (t >= a && t <= b) ? 1 - ((t - (a + b) / 2).abs() / ((b - a) / 2)) : 0.0;
    return math.max(w(0.40, 0.46), w(0.86, 0.91));
  }

  void _eyes(Canvas canvas) {
    final happy = mood == HawkMood.cheer || (mood == HawkMood.wave);
    final sad = mood == HawkMood.sad;
    final blink = _blink;
    for (final left in [true, false]) {
      final c = Offset(left ? 83 : 117, 76);
      if (happy && mood == HawkMood.cheer) {
        // Yeux « ^ ^ » de joie
        final p = Path()
          ..moveTo(c.dx - 9, c.dy + 3)
          ..quadraticBezierTo(c.dx, c.dy - 10, c.dx + 9, c.dy + 3);
        canvas.drawPath(p, _stroke(ink, 3.6));
      } else {
        final h = 24.0 * (1 - blink * 0.9);
        final eye = Rect.fromCenter(center: c, width: 24, height: h);
        canvas.drawOval(eye, _fill(iris));
        canvas.drawOval(eye, _stroke(ink.withOpacity(0.55), 1.6));
        if (blink < 0.5) {
          var look = Offset.zero;
          if (sad) look = const Offset(0, 3);
          if (mood == HawkMood.think) look = Offset(left ? -3 : -3, -3);
          canvas.drawCircle(c + look, 5.6, _fill(ink));
          canvas.drawCircle(c + look + const Offset(-1.8, -2.2), 1.9, _fill(Colors.white));
        }
      }
    }
    // Sourcils : regard décidé de l'épervier ; baissés vers l'intérieur quand il est triste
    final browPaint = _stroke(ink, 4.5);
    for (final left in [true, false]) {
      final s = left ? 1.0 : -1.0;
      final cx = left ? 83.0 : 117.0;
      late Offset a;
      late Offset b;
      if (sad) {
        a = Offset(cx - 11 * s, 66);
        b = Offset(cx + 10 * s, 58);
      } else if (mood == HawkMood.cheer) {
        a = Offset(cx - 10 * s, 62);
        b = Offset(cx + 10 * s, 60);
      } else {
        a = Offset(cx - 11 * s, 62);
        b = Offset(cx + 11 * s, 67);
      }
      canvas.drawLine(a, b, browPaint);
    }
  }

  void _beak(Canvas canvas) {
    // Langue qui dépasse quand il est content
    if (mood == HawkMood.cheer) {
      canvas.drawOval(Rect.fromCenter(center: const Offset(100, 105), width: 12, height: 7), _fill(const Color(0xFFE4572E)));
    }
    final beak = Path()
      ..moveTo(87, 88)
      ..quadraticBezierTo(100, 79, 113, 88)
      ..quadraticBezierTo(112, 107, 100, 113)
      ..quadraticBezierTo(98, 100, 87, 88)
      ..close();
    canvas.drawPath(beak, _fill(beakColor));
    canvas.drawOval(Rect.fromCenter(center: const Offset(100, 88), width: 26, height: 8), _fill(cere));
    canvas.drawCircle(const Offset(96, 90), 1.2, _fill(beakColor));
    canvas.drawCircle(const Offset(104, 90), 1.2, _fill(beakColor));
  }

  void _accessory(Canvas canvas) {
    switch (accessory) {
      case 'acc_glasses':
        for (final x in [83.0, 117.0]) {
          canvas.drawCircle(Offset(x, 76), 15, _fill(Colors.white.withOpacity(0.18)));
          canvas.drawCircle(Offset(x, 76), 15, _stroke(ink, 3));
        }
        canvas.drawLine(const Offset(97, 76), const Offset(103, 76), _stroke(ink, 3));
        break;
      case 'acc_cap':
        final dome = Path()
          ..moveTo(62, 58)
          ..cubicTo(62, 18, 138, 18, 138, 58)
          ..close();
        canvas.drawPath(dome, _fill(const Color(0xFF2ECC71)));
        canvas.drawPath(dome, _stroke(ink.withOpacity(0.35), 1.5));
        final brim = RRect.fromRectAndRadius(const Rect.fromLTWH(90, 52, 62, 10), const Radius.circular(5));
        canvas.drawRRect(brim, _fill(const Color(0xFF1FAA59)));
        canvas.drawCircle(const Offset(100, 28), 4, _fill(const Color(0xFFFFE14D)));
        break;
      case 'acc_crown':
        final crown = Path()
          ..moveTo(68, 46)
          ..lineTo(72, 16)
          ..lineTo(87, 33)
          ..lineTo(100, 8)
          ..lineTo(113, 33)
          ..lineTo(128, 16)
          ..lineTo(132, 46)
          ..close();
        canvas.drawPath(crown, _fill(const Color(0xFFFFD43B)));
        canvas.drawPath(crown, _stroke(const Color(0xFFB8860B), 2.4));
        for (final x in [86.0, 100.0, 114.0]) {
          canvas.drawCircle(Offset(x, 38), 3, _fill(const Color(0xFFE5484D)));
        }
        break;
    }
  }

  void _sparkles(Canvas canvas) {
    final s = math.sin(react.clamp(0.0, 1.0) * math.pi);
    void star(Offset c, double r) {
      final p = Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r);
      canvas.drawPath(p, _fill(const Color(0xFFFFE14D).withOpacity(s.clamp(0.0, 1.0))));
    }

    star(Offset(34, 44 - s * 6), 10 * s);
    star(Offset(168, 54 - s * 8), 12 * s);
    star(Offset(150, 18 - s * 4), 8 * s);
    star(Offset(48, 118 - s * 5), 7 * s);
  }

  @override
  bool shouldRepaint(covariant _HawkPainter old) =>
      old.idle != idle || old.react != react || old.mood != mood || old.accessory != accessory;
}
