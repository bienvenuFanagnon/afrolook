// Effets animés des templates. Tout est une fonction de t ∈ [0, 1) : une boucle de 3 s qui se raccorde
// parfaitement (chaque mouvement fait un nombre entier de cycles), pour l'aperçu comme pour la vidéo exportée.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'montage_catalog.dart';

const kMontageLoop = Duration(seconds: 3);

class _Rng {
  _Rng(int seed) : _s = seed & 0x7fffffff;
  int _s;
  double next() {
    _s = (_s * 1103515245 + 12345) & 0x7fffffff;
    return _s / 0x7fffffff;
  }

  int pick(List<int> v) => v[(next() * v.length).floor().clamp(0, v.length - 1)];
}

double _frac(double x) => x - x.floorToDouble();
const _tau = math.pi * 2;

class MontageFxPainter extends CustomPainter {
  /// [anim] : redessin à chaque image sans reconstruire l'écran ; sinon instant fixe [fixedT] (export).
  MontageFxPainter(this.fx, {this.anim, this.fixedT = 0}) : super(repaint: anim);
  final MontageFx fx;
  final Animation<double>? anim;
  final double fixedT;

  late double t;

  static final Map<String, TextPainter> _emoji = {};

  late double _w, _h, _cq;
  late Canvas _c;

  @override
  void paint(Canvas canvas, Size size) {
    t = anim?.value ?? fixedT;
    _c = canvas;
    _w = size.width;
    _h = size.height;
    _cq = _w / 100;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final r = _Rng(97 + fx.index * 31);
    switch (fx) {
      case MontageFx.none:
        break;
      case MontageFx.money:
        _rise(r, 8, ['💸'], 6, 4, drift: true);
      case MontageFx.hearts:
        _rise(r, 10, ['❤️', '💕', '💗', '💖'], 4, 5, sway: true);
      case MontageFx.coins:
        _fall(r, 10, ['🪙'], 5, 4, spin: true);
      case MontageFx.rain:
        _rain(r, 40, 0, 1);
      case MontageFx.storm:
        _vignette(const Color.fromRGBO(120, 0, 0, .8));
        _flash();
        _emojiAt('⛈️', Offset(_w / 2, 15 * _cq + 8.5 * _cq), 17 * _cq, 1);
        _rain(r, 26, 0, 1);
      case MontageFx.cloud:
        _emojiAt('🌧️', Offset(_w / 2, 15 * _cq + 8.5 * _cq), 17 * _cq, 1);
        _rain(r, 16, .28, .72);
      case MontageFx.sparkle:
        _sparkle(r, 10);
      case MontageFx.fire:
        _fire(r);
      case MontageFx.rays:
        _rays();
        _sparkle(r, 6);
      case MontageFx.speed:
        _speed();
      case MontageFx.bokeh:
        _bokeh(r);
        _rise(r, 3, ['😊', '😁', '🌞'], 5, 3);
      case MontageFx.zzz:
        _rise(r, 6, ['💤'], 5, 5, sway: true);
      case MontageFx.leaves:
        _halo(Offset(_w / 2, _h * .40), 41 * _cq, const Color.fromRGBO(160, 255, 200, .4));
        _fall(r, 7, ['🍃', '🌿'], 4, 4, sway: true);
      case MontageFx.crown:
        final bob = math.sin(_tau * t * 2) * .8 * _cq;
        _emojiAt('👑', Offset(_w / 2, 14 * _cq + 7.5 * _cq + bob), 15 * _cq, 1);
        _sparkle(r, 8);
      case MontageFx.waves:
        _waves();
        _sparkle(r, 4);
      case MontageFx.disco:
        _disco();
        _rise(r, 4, ['🎶', '🎵'], 5, 3);
      case MontageFx.sunset:
        _sunset();
      case MontageFx.fireworks:
        _fireworks(r);
        _sparkle(r, 4);
      case MontageFx.moon:
        _moon(r);
      case MontageFx.snow:
        _snow(r);
      case MontageFx.confetti:
        _confetti(r);
      case MontageFx.ring:
        _ringGlow();
        _emojiAt('💍', Offset(_w / 2, _h * .38), 12 * _cq, 1);
        _sparkle(r, 8);
        _rise(r, 8, ['❤️', '💕', '💗', '💖'], 4, 5, sway: true);
      case MontageFx.baby:
        _rise(r, 5, ['🍼', '🧸', '💛'], 4, 3, sway: true);
    }
    canvas.restore();
  }

  // ── Briques ──

  void _emojiAt(String e, Offset center, double size, double opacity, {double angle = 0}) {
    if (opacity <= 0.01 || size < 1) return;
    final key = '$e@${size.round()}';
    final tp = _emoji.putIfAbsent(key, () {
      if (_emoji.length > 400) _emoji.clear();
      return TextPainter(text: TextSpan(text: e, style: TextStyle(fontSize: size.roundToDouble(), height: 1)), textDirection: TextDirection.ltr)..layout();
    });
    _c.save();
    _c.translate(center.dx, center.dy);
    if (angle != 0) _c.rotate(angle);
    final rect = Rect.fromCenter(center: Offset.zero, width: tp.width + 4, height: tp.height + 4);
    if (opacity < .98) _c.saveLayer(rect, Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
    tp.paint(_c, Offset(-tp.width / 2, -tp.height / 2));
    if (opacity < .98) _c.restore();
    _c.restore();
  }

  double _edgeFade(double ph) => ph < .12 ? ph / .12 : (ph > .85 ? (1 - ph) / .15 : 1);

  void _rise(_Rng r, int n, List<String> list, double base, double spread, {bool sway = false, bool drift = false}) {
    for (var i = 0; i < n; i++) {
      final k = r.pick([1, 1, 2]);
      final off = r.next(), x0 = r.next() * .88 * _w + 4 * _cq, size = (base + r.next() * spread) * _cq;
      final m = r.pick([2, 3]), sp = r.next();
      final ph = _frac(t * k + off);
      var x = x0;
      var angle = 0.0;
      if (sway) {
        x += math.sin(_tau * (t * m + sp)) * 2.5 * _cq;
        angle = math.sin(_tau * (t * m + sp)) * .14;
      }
      if (drift) {
        final d = .5 - .5 * math.cos(_tau * (t * m + sp));
        x += d * 14 * _cq;
        angle = (-10 + 32 * d) * math.pi / 180;
      }
      _emojiAt(list[i % list.length], Offset(x, _h * (1.05 - ph * 1.17)), size, _edgeFade(ph), angle: angle);
    }
  }

  void _fall(_Rng r, int n, List<String> list, double base, double spread, {bool sway = false, bool spin = false}) {
    for (var i = 0; i < n; i++) {
      final k = r.pick([1, 2]);
      final off = r.next(), x0 = r.next() * .9 * _w + 3 * _cq, size = (base + r.next() * spread) * _cq;
      final m = r.pick([1, 2, 3]), sp = r.next();
      final ph = _frac(t * k + off);
      var x = x0;
      var angle = 0.0;
      if (sway) {
        x += math.sin(_tau * (t * m + sp)) * 2.5 * _cq;
        angle = math.sin(_tau * (t * m + sp)) * .14;
      }
      if (spin) angle = _tau * _frac(t * m + sp);
      _emojiAt(list[i % list.length], Offset(x, _h * (-.12 + ph * 1.18)), size, 1, angle: angle);
    }
  }

  void _rain(_Rng r, int n, double a, double b) {
    final p = Paint()
      ..strokeWidth = math.max(1, .35 * _cq)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < n; i++) {
      final k = r.pick([4, 5, 6]);
      final off = r.next(), x = (a + r.next() * (b - a)) * _w, op = .4 + r.next() * .6;
      final y = _h * (-.12 + _frac(t * k + off) * 1.18);
      p.shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0x00D2E6FF), Color.fromRGBO(210, 230, 255, .85 * op)])
          .createShader(Rect.fromLTWH(x, y, 1, 7 * _cq));
      _c.drawLine(Offset(x, y), Offset(x, y + 7 * _cq), p);
    }
  }

  void _sparkle(_Rng r, int n) {
    for (var i = 0; i < n; i++) {
      final x = r.next() * .9 * _w, y = r.next() * .75 * _h, size = (3 + r.next() * 4) * _cq;
      final m = r.pick([1, 2]), off = r.next();
      final v = .5 - .5 * math.cos(_tau * (t * m + off));
      _emojiAt('✨', Offset(x + size / 2, y + size / 2), size * (.5 + .6 * v), .1 + .9 * v);
    }
  }

  void _vignette(Color edge) {
    final rect = Offset.zero & Size(_w, _h);
    _c.drawRect(
      rect,
      Paint()..shader = RadialGradient(radius: .9, colors: [edge.withValues(alpha: 0), edge], stops: const [.45, 1]).createShader(rect),
    );
  }

  void _flash() {
    final ph = t;
    final on = (ph > .86 && ph < .88) || (ph > .91 && ph < .93);
    if (on) _c.drawRect(Offset.zero & Size(_w, _h), Paint()..color = const Color.fromRGBO(255, 255, 255, .45));
  }

  void _fire(_Rng r) {
    final s = 1 + .08 * math.sin(_tau * t * 4);
    final hh = _h * .58 * s;
    final rect = Rect.fromLTWH(-.1 * _w, _h - hh + .08 * _h, 1.2 * _w, hh);
    _c.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = const RadialGradient(
          center: Alignment.bottomCenter,
          radius: 1.0,
          colors: [Color.fromRGBO(255, 205, 40, .9), Color.fromRGBO(255, 90, 20, .6), Color.fromRGBO(200, 20, 20, .25), Color(0x00C81414)],
          stops: [0, .35, .62, .76],
        ).createShader(rect),
    );
    final ember = Paint()
      ..color = const Color(0xFFFFB13B)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, _cq * .6);
    for (var i = 0; i < 14; i++) {
      final k = r.pick([1, 2]), off = r.next(), x0 = (.1 + r.next() * .8) * _w, m = r.pick([2, 3]), sp = r.next();
      final ph = _frac(t * k + off);
      final x = x0 + math.sin(_tau * (t * m + sp)) * 2 * _cq;
      ember.color = Color.fromRGBO(255, 177, 59, _edgeFade(ph));
      _c.drawCircle(Offset(x, _h * (1.05 - ph * 1.17)), .55 * _cq, ember);
    }
    _rise(r, 4, ['🔥'], 5, 4);
  }

  void _rays() {
    final center = Offset(_w / 2, _h * .28);
    final radius = 1.3 * math.max(_w, _h);
    final p = Paint()
      ..color = const Color.fromRGBO(255, 226, 120, .22)
      ..blendMode = BlendMode.screen;
    const n = 20;
    final rot = t * _tau / n;
    for (var i = 0; i < n; i++) {
      final a = rot + i * _tau / n;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(Rect.fromCircle(center: center, radius: radius), a, _tau / n / 2, false)
        ..close();
      _c.drawPath(path, p);
    }
  }

  void _speed() {
    final p = Paint()
      ..color = const Color.fromRGBO(255, 255, 255, .17)
      ..strokeWidth = math.max(1, .5 * _cq)
      ..blendMode = BlendMode.screen;
    final gap = 7 * _cq;
    final shift = _frac(t * 2) * gap;
    final dx = _h / math.tan(115 * math.pi / 180);
    for (var x = -_h; x < _w + _h; x += gap) {
      final x0 = x - shift;
      _c.drawLine(Offset(x0, 0), Offset(x0 + dx, _h), p);
    }
  }

  void _bokeh(_Rng r) {
    for (var i = 0; i < 10; i++) {
      final rad = (4 + r.next() * 7) * _cq, x = r.next() * .85 * _w + rad, off = r.next();
      final ph = _frac(t + off);
      final c = Offset(x, _h * (1.05 - ph * 1.17));
      _c.drawCircle(
        c,
        rad,
        Paint()
          ..shader = RadialGradient(colors: [Color.fromRGBO(255, 222, 90, .8 * _edgeFade(ph)), const Color(0x00FFB400)], stops: const [0, .7])
              .createShader(Rect.fromCircle(center: c, radius: rad)),
      );
    }
  }

  void _halo(Offset c, double radius, Color glow) {
    final s = 1 + .06 * math.sin(_tau * t);
    _c.drawCircle(c, radius * s, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * _cq
      ..color = glow
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * _cq));
    _c.drawCircle(c, radius * s, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .5 * _cq
      ..color = Color.fromRGBO(255, 255, 255, .5 + .3 * math.sin(_tau * t)));
  }

  void _waves() {
    void wave(double height, double amp, int cycles, Color color, double yOff) {
      final wl = _w / 2;
      final shift = _frac(t * cycles) * wl;
      final top = _h - height + yOff;
      final path = Path()..moveTo(-wl, _h);
      for (var x = -wl; x <= _w + wl; x += 4) {
        path.lineTo(x, top + amp * math.sin(_tau * (x + shift) / wl));
      }
      path
        ..lineTo(_w + wl, _h)
        ..close();
      _c.drawPath(path, Paint()..color = color);
    }

    wave(24 * _cq, 3 * _cq, 1, const Color.fromRGBO(78, 205, 196, .45), -3 * _cq);
    wave(18 * _cq, 2.5 * _cq, 2, const Color.fromRGBO(255, 255, 255, .35), 0);
  }

  void _disco() {
    const colors = [Color(0xFFFF3CAC), Color(0xFF2ECC71), Color(0xFFFFD400)];
    const xs = [.08, .38, .66];
    for (var i = 0; i < 3; i++) {
      final top = Offset((xs[i] + .17) * _w, -.12 * _h);
      final angle = math.sin(_tau * (t + i / 3)) * 30 * math.pi / 180;
      _c.save();
      _c.translate(top.dx, top.dy);
      _c.rotate(angle);
      final len = 1.4 * _h, half = 17 * _cq;
      final path = Path()
        ..moveTo(-.12 * half, 0)
        ..lineTo(.12 * half, 0)
        ..lineTo(half, len)
        ..lineTo(-half, len)
        ..close();
      _c.drawPath(
        path,
        Paint()
          ..blendMode = BlendMode.screen
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.4 * _cq)
          ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [colors[i].withValues(alpha: .85), colors[i].withValues(alpha: 0)], stops: const [0, .85])
              .createShader(Rect.fromLTWH(-half, 0, 2 * half, len)),
      );
      _c.restore();
    }
  }

  void _sunset() {
    final rad = 23 * _cq;
    final center = Offset(.08 * _w + rad, _h * .91 - rad);
    _c.drawCircle(
      center,
      rad,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = const RadialGradient(colors: [Color.fromRGBO(255, 226, 138, .9), Color.fromRGBO(255, 154, 60, .55), Color(0x00FF7828)], stops: [0, .5, .7])
            .createShader(Rect.fromCircle(center: center, radius: rad)),
    );
    // Acacia et sol (dessin 100 × 42, posé en bas)
    final sc = _w / 100;
    _c.save();
    _c.translate(0, _h - 42 * sc);
    _c.scale(sc);
    final p = Paint()..color = const Color(0xFF1A0D06);
    final ground = Path()
      ..moveTo(0, 34)
      ..quadraticBezierTo(25, 30, 50, 33)
      ..quadraticBezierTo(75, 36, 100, 32)
      ..lineTo(100, 42)
      ..lineTo(0, 42)
      ..close();
    _c.drawPath(ground, p);
    _c.drawOval(Rect.fromCenter(center: const Offset(70, 14), width: 40, height: 8.4), p);
    _c.drawOval(Rect.fromCenter(center: const Offset(61, 12.5), width: 18, height: 6), p);
    _c.drawPath(Path()..addPolygon(const [Offset(69, 17), Offset(68, 33), Offset(71.5, 33), Offset(71, 17)], true), p);
    _c.drawPath(Path()..addPolygon(const [Offset(69.5, 21), Offset(60, 15), Offset(61, 14.3), Offset(70, 19.5)], true), p);
    _c.drawPath(Path()..addPolygon(const [Offset(70.5, 20), Offset(80, 14), Offset(80.8, 14.8), Offset(71, 21)], true), p);
    _c.drawPath(Path()..addPolygon(const [Offset(18, 33), Offset(18.6, 24), Offset(19.4, 24), Offset(20, 33)], true), p);
    _c.drawOval(Rect.fromCenter(center: const Offset(19, 23.5), width: 14, height: 3.6), p);
    _c.restore();
  }

  void _fireworks(_Rng r) {
    const pal = [Color(0xFFFFD400), Color(0xFFFF4FD8), Color(0xFF4ECDC4), Color(0xFFFF6B5B), Colors.white, Color(0xFF2ECC71)];
    for (var b = 0; b < 5; b++) {
      final cx = (.15 + r.next() * .7) * _w, cy = (.08 + r.next() * .36) * _h;
      final color = pal[(r.next() * pal.length).floor().clamp(0, pal.length - 1)];
      final off = r.next(), d = (12 + r.next() * 9) * _cq;
      final ph = _frac(t * 2 + off);
      final dist = d * (1 - math.pow(1 - ph, 2));
      final op = ph < .08 ? ph / .08 : (ph > .75 ? (1 - ph) / .25 : 1.0);
      final p = Paint()
        ..color = color.withValues(alpha: op)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, .5 * _cq);
      for (var i = 0; i < 16; i++) {
        final a = i * _tau / 16;
        _c.drawCircle(Offset(cx + math.cos(a) * dist, cy + math.sin(a) * dist), .75 * _cq * (1 - .6 * ph), p);
      }
    }
  }

  void _moon(_Rng r) {
    final rad = 8.5 * _cq;
    final c = Offset(_w - 11 * _cq - rad, 13 * _cq + rad);
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: c, radius: rad)),
      Path()..addOval(Rect.fromCircle(center: c + Offset(-3.5 * _cq, -1.5 * _cq), radius: rad * .92)),
    );
    _c.drawPath(moon, Paint()
      ..color = const Color.fromRGBO(255, 231, 163, .6)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 * _cq));
    _c.drawPath(moon, Paint()..color = const Color(0xFFFFE7A3));
    final star = Paint()..maskFilter = MaskFilter.blur(BlurStyle.normal, .4 * _cq);
    for (var i = 0; i < 14; i++) {
      final x = r.next() * .92 * _w, y = r.next() * .45 * _h, m = r.pick([1, 2]), off = r.next();
      final v = .5 - .5 * math.cos(_tau * (t * m + off));
      star.color = Color.fromRGBO(255, 255, 255, .1 + .9 * v);
      _c.drawCircle(Offset(x, y), .6 * _cq * (.5 + .6 * v), star);
    }
    const lanterns = [(.10, 16.0), (.30, 26.0), (.82, 12.0)];
    for (var i = 0; i < lanterns.length; i++) {
      final (lx, len) = lanterns[i];
      _c.save();
      _c.translate(lx * _w, 0);
      _c.rotate(math.sin(_tau * (t + i * .3)) * 7 * math.pi / 180);
      _c.drawLine(Offset.zero, Offset(0, len * _cq), Paint()
        ..color = const Color.fromRGBO(255, 231, 163, .75)
        ..strokeWidth = math.max(1, .3 * _cq));
      _emojiAt('🏮', Offset(0, len * _cq + 4 * _cq), 8 * _cq, 1);
      _c.restore();
    }
  }

  void _snow(_Rng r) {
    final p = Paint()..color = const Color.fromRGBO(255, 255, 255, .9);
    for (var i = 0; i < 34; i++) {
      final rad = (.4 + r.next() * .7) * _cq, x0 = r.next() * .98 * _w, off = r.next(), m = r.pick([2, 3]), sp = r.next();
      final ph = _frac(t + off);
      _c.drawCircle(Offset(x0 + math.sin(_tau * (t * m + sp)) * 2.5 * _cq, _h * (-.12 + ph * 1.18)), rad, p);
    }
  }

  void _confetti(_Rng r) {
    const pal = [Color(0xFFFFD400), Color(0xFFFF4FD8), Color(0xFF4ECDC4), Color(0xFFFF6B5B), Color(0xFF2ECC71), Color(0xFF9B59B6)];
    for (var i = 0; i < 36; i++) {
      final k = r.pick([1, 2]), off = r.next(), x = r.next() * .98 * _w, m = r.pick([1, 2, 3]), sp = r.next();
      final ph = _frac(t * k + off);
      _c.save();
      _c.translate(x, _h * (-.12 + ph * 1.18));
      _c.rotate(_tau * _frac(t * m + sp));
      _c.drawRRect(
        RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 1.6 * _cq, height: 2.8 * _cq), Radius.circular(.3 * _cq)),
        Paint()..color = pal[i % pal.length],
      );
      _c.restore();
    }
  }

  void _ringGlow() {
    final s = 1 + .06 * math.sin(_tau * t * 2);
    final c = Offset(_w / 2, _h * .38);
    final rad = 12 * _cq * s;
    _c.drawCircle(
      c,
      rad,
      Paint()
        ..shader = const RadialGradient(colors: [Color.fromRGBO(255, 255, 255, .95), Color.fromRGBO(255, 255, 255, .25), Color(0x00FFFFFF)], stops: [0, .55, .7])
            .createShader(Rect.fromCircle(center: c, radius: rad)),
    );
  }

  @override
  bool shouldRepaint(MontageFxPainter old) => old.fixedT != fixedT || old.fx != fx || old.anim != anim;
}
