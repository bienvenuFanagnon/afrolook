part of 'card_canvas.dart';

// Fonds, formes et motifs dessinés à la main : aucun fichier image n'est nécessaire.

class _KentePainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    const colors = [Color(0xFFF2B705), Color(0xFF1AA24E), Color(0xFFC8321E), Color(0xFF121212)];
    const w = 26.0;
    var i = 0;
    for (double x = 0; x < s.width; x += w, i++) {
      c.drawRect(Rect.fromLTWH(x, 0, w, s.height), Paint()..color = colors[i % 4]);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _WaxPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFE8590C));
    const cell = 121.0;
    const rings = [
      (60.5, Color(0xFFC2255C)),
      (46.0, Color(0xFFFFF3BF)),
      (32.0, Color(0xFF0B7285)),
      (16.0, Color(0xFFFFD43B)),
    ];
    for (double y = cell / 2 - cell; y < s.height + cell; y += cell) {
      for (double x = cell / 2 - cell; x < s.width + cell; x += cell) {
        for (final r in rings) {
          c.drawCircle(Offset(x, y), r.$1, Paint()..color = r.$2);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _NeonPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF04070A));
    final glow = Paint()
      ..shader = ui.Gradient.radial(Offset(s.width / 2, s.height * 1.08), s.width * 0.9, [_green.withOpacity(0.55), Colors.transparent]);
    c.drawRect(Offset.zero & s, glow);
    final line = Paint()
      ..color = _green.withOpacity(0.14)
      ..strokeWidth = 1;
    for (double x = 0; x < s.width; x += 32) {
      c.drawLine(Offset(x, 0), Offset(x, s.height), line);
    }
    for (double y = 0; y < s.height; y += 32) {
      c.drawLine(Offset(0, y), Offset(s.width, y), line);
    }
    final rr = RRect.fromRectAndRadius(Rect.fromLTWH(12, 12, s.width - 24, s.height - 24), const Radius.circular(20));
    c.drawRRect(rr, Paint()..color = _green.withOpacity(0.5)..style = PaintingStyle.stroke..strokeWidth = 6..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    c.drawRRect(rr, Paint()..color = _green..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _BogolanPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFFC98B4B));
    final p = Paint()
      ..color = const Color(0xFF3A200C)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.square;
    const step = 37.0;
    for (double y = 0; y < s.height + step; y += step) {
      for (double x = 0; x < s.width + step; x += step) {
        c.drawLine(Offset(x, y), Offset(x + step, y + step), p);
        c.drawLine(Offset(x + step, y), Offset(x, y + step), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Points régulièrement espacés (trame, étoiles, pois).
class _DotsPainter extends CustomPainter {
  _DotsPainter({required this.color, this.step = 14, this.radius = 1.6, this.offset = Offset.zero});
  final Color color;
  final double step;
  final double radius;
  final Offset offset;

  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = color;
    for (double y = offset.dy; y < s.height + step; y += step) {
      for (double x = offset.dx; x < s.width + step; x += step) {
        c.drawCircle(Offset(x, y), radius, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Lignes de vitesse du manga : rayons fins noirs autour d'un point.
class _MangaRaysPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = Colors.white);
    final center = Offset(s.width / 2, s.height * 0.4);
    final r = s.longestSide * 1.2;
    final p = Paint()..color = Colors.black;
    const n = 90;
    for (var i = 0; i < n; i++) {
      final a = i / n * math.pi * 2;
      final w = 0.012 + (i % 3) * 0.006;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + r * math.cos(a - w), center.dy + r * math.sin(a - w))
        ..lineTo(center.dx + r * math.cos(a + w), center.dy + r * math.sin(a + w))
        ..close();
      c.drawPath(path, p);
    }
    // trame dans les coins
    final dots = Paint()..color = const Color(0x33000000);
    for (double y = 0; y < s.height; y += 9) {
      for (double x = 0; x < s.width; x += 9) {
        final d = (Offset(x, y) - center).distance / r;
        if (d > 0.55) c.drawCircle(Offset(x, y), 1.4 * d, dots);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Ciel d'anime au crépuscule : dégradé, nuages doux et soleil.
class _SkyPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final rect = Offset.zero & s;
    c.drawRect(
      rect,
      Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, s.height), const [Color(0xFF2B3A8F), Color(0xFF7B5BD6), Color(0xFFFF8FA3), Color(0xFFFFD3A0)], const [0, 0.38, 0.7, 1]),
    );
    final sun = Offset(s.width * 0.88, s.height * 0.04);
    c.drawCircle(sun, s.width * 0.42, Paint()..shader = ui.Gradient.radial(sun, s.width * 0.42, const [Color(0xFFFFFFFF), Color(0x66FFE9A8), Color(0x00FFE9A8)], const [0, 0.35, 1]));
    final cloud = Paint()..color = const Color(0x99FFFFFF)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    c.drawOval(Rect.fromCenter(center: Offset(s.width * 0.2, s.height * 0.4), width: s.width * 0.5, height: 34), cloud);
    c.drawOval(Rect.fromCenter(center: Offset(s.width * 0.8, s.height * 0.55), width: s.width * 0.6, height: 40), cloud);
    c.drawOval(Rect.fromCenter(center: Offset(s.width * 0.45, s.height * 0.28), width: s.width * 0.35, height: 22), Paint()..color = const Color(0x66FFFFFF)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Affiche de match : blocs en diagonale bleu / orange.
class _SportPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF0A1F44));
    final blue = Path()
      ..moveTo(s.width * 0.56, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width, s.height)
      ..lineTo(s.width * 0.30, s.height)
      ..close();
    c.drawPath(blue, Paint()..color = const Color(0xFF1B6BFF));
    final orange = Path()
      ..moveTo(s.width * 0.50, 0)
      ..lineTo(s.width * 0.56, 0)
      ..lineTo(s.width * 0.30, s.height)
      ..lineTo(s.width * 0.24, s.height)
      ..close();
    c.drawPath(orange, Paint()..color = const Color(0xFFFF5A1F));
    final white = Path()
      ..moveTo(s.width * 0.56, 0)
      ..lineTo(s.width * 0.575, 0)
      ..lineTo(s.width * 0.315, s.height)
      ..lineTo(s.width * 0.30, s.height)
      ..close();
    c.drawPath(white, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Lignes de balayage d'un écran de jeu, sur un fond sombre à lueurs.
class _GamerPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.drawRect(Offset.zero & s, Paint()..color = const Color(0xFF070A12));
    c.drawRect(Offset.zero & s, Paint()..shader = ui.Gradient.radial(Offset(s.width, 0), s.width * 0.9, const [Color(0x667C3AED), Color(0x007C3AED)]));
    c.drawRect(Offset.zero & s, Paint()..shader = ui.Gradient.radial(Offset(0, s.height * 0.7), s.width * 0.8, const [Color(0x4400FFC3), Color(0x0000FFC3)]));
    final line = Paint()..color = const Color(0x1A00FFC3)..strokeWidth = 1;
    for (double y = 0; y < s.height; y += 4) {
      c.drawLine(Offset(0, y), Offset(s.width, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Reflets d'un drapeau qui flotte : bandes claires et sombres en travers.
class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final stops = <double>[];
    final cols = <Color>[];
    const n = 7;
    for (var i = 0; i <= n; i++) {
      stops.add(i / n);
      cols.add(i.isEven ? const Color(0x33000000) : const Color(0x26FFFFFF));
    }
    c.drawRect(Offset.zero & s, Paint()..shader = ui.Gradient.linear(Offset(0, s.height * 0.2), Offset(s.width, s.height * 0.8), cols, stops));
    c.drawRect(Offset.zero & s, Paint()..shader = ui.Gradient.linear(Offset(0, s.height * 0.25), Offset(0, s.height), const [Color(0x00000000), Color(0x99000000)]));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Confettis de supporters.
class _ConfettiPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    const colors = [Color(0xFFFFD400), Color(0xFFE5484D), Color(0xFF1FAA59), Color(0xFFFFFFFF)];
    var seed = 11;
    double r() {
      seed = (seed * 9301 + 49297) % 233280;
      return seed / 233280;
    }

    for (var i = 0; i < 70; i++) {
      final p = Paint()..color = colors[i % 4].withOpacity(0.75);
      final o = Offset(r() * s.width, r() * s.height);
      c.save();
      c.translate(o.dx, o.dy);
      c.rotate(r() * math.pi);
      c.drawRect(const Rect.fromLTWH(-3, -1.5, 6, 3), p);
      c.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Timbre-poste : un rectangle dont le bord est découpé en dents rondes.
class _PerforationClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    final paper = Path()..addRect(Offset.zero & s);
    final holes = Path();
    const r = 5.0;
    const step = 14.0;
    for (double x = step / 2; x < s.width; x += step) {
      holes.addOval(Rect.fromCircle(center: Offset(x, 0), radius: r));
      holes.addOval(Rect.fromCircle(center: Offset(x, s.height), radius: r));
    }
    for (double y = step / 2; y < s.height; y += step) {
      holes.addOval(Rect.fromCircle(center: Offset(0, y), radius: r));
      holes.addOval(Rect.fromCircle(center: Offset(s.width, y), radius: r));
    }
    return Path.combine(PathOperation.difference, paper, holes);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

/// Cachet de la poste : deux cercles et des vagues.
class _PostmarkPainter extends CustomPainter {
  _PostmarkPainter(this.color, this.label, this.date);
  final Color color;
  final String label;
  final String date;

  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2;
    final r = s.height / 2 - 2;
    final center = Offset(r + 2, s.height / 2);
    c.drawCircle(center, r, p);
    c.drawCircle(center, r * 0.76, p);
    for (var k = 0; k < 4; k++) {
      final y = s.height * (0.22 + k * 0.18);
      final path = Path()..moveTo(center.dx + r * 0.9, y);
      for (var x = 0.0; x < s.width - center.dx - r * 0.9; x += 14) {
        path.relativeQuadraticBezierTo(3.5, -5, 7, 0);
        path.relativeQuadraticBezierTo(3.5, 5, 7, 0);
      }
      c.drawPath(path, p);
    }
    void txt(String t, double y, double size) {
      final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w800, letterSpacing: 1, fontFamily: 'Roboto')), textDirection: TextDirection.ltr)..layout(maxWidth: r * 1.4);
      tp.paint(c, Offset(center.dx - tp.width / 2, y));
    }

    txt(label, center.dy - 11, 10);
    txt(date, center.dy + 2, 8.5);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Cadre à angles coupés d'une interface de jeu.
Path _chamfer(Size s, double cut) => Path()
  ..moveTo(0, cut)
  ..lineTo(cut, 0)
  ..lineTo(s.width, 0)
  ..lineTo(s.width, s.height - cut)
  ..lineTo(s.width - cut, s.height)
  ..lineTo(0, s.height)
  ..close();

class _ChamferClipper extends CustomClipper<Path> {
  _ChamferClipper(this.cut);
  final double cut;
  @override
  Path getClip(Size s) => _chamfer(s, cut);
  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

class _ChamferBorderPainter extends CustomPainter {
  _ChamferBorderPainter(this.color, this.cut);
  final Color color;
  final double cut;
  @override
  void paint(Canvas c, Size s) {
    final path = _chamfer(s, cut);
    c.drawPath(path, Paint()..color = color.withOpacity(0.6)..style = PaintingStyle.stroke..strokeWidth = 5..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    c.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Écusson de supporter.
class _ShieldClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..moveTo(0, 0)
    ..lineTo(s.width, 0)
    ..lineTo(s.width, s.height * 0.62)
    ..quadraticBezierTo(s.width, s.height * 0.86, s.width / 2, s.height)
    ..quadraticBezierTo(0, s.height * 0.86, 0, s.height * 0.62)
    ..close();
  @override
  bool shouldReclip(covariant CustomClipper<Path> old) => false;
}

/// Ligne en pointillés avec une encoche ronde à chaque bout (perforation d'un billet).
class _PerfPainter extends CustomPainter {
  _PerfPainter(this.notch);
  final Color notch;
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = const Color(0xFF9AA8C6)..strokeWidth = 2;
    for (double x = 14; x < s.width - 14; x += 9) {
      c.drawLine(Offset(x, s.height / 2), Offset(x + 5, s.height / 2), p);
    }
    c.drawCircle(Offset(0, s.height / 2), 9, Paint()..color = notch);
    c.drawCircle(Offset(s.width, s.height / 2), 9, Paint()..color = notch);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Double filet doré d'une carte de tarot.
class _GoldFramePainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    const gold = Color(0xFFF2D58A);
    final outer = RRect.fromRectAndRadius(Rect.fromLTWH(10, 10, s.width - 20, s.height - 20), const Radius.circular(10));
    final inner = RRect.fromRectAndRadius(Rect.fromLTWH(15, 15, s.width - 30, s.height - 30), const Radius.circular(7));
    c.drawRRect(outer, Paint()..color = gold..style = PaintingStyle.stroke..strokeWidth = 2.5);
    c.drawRRect(inner, Paint()..color = gold.withOpacity(0.55)..style = PaintingStyle.stroke..strokeWidth = 1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Fines lignes horizontales d'un papier (timbre, journal).
class _PaperLinesPainter extends CustomPainter {
  _PaperLinesPainter(this.color);
  final Color color;
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = color..strokeWidth = 1;
    for (double y = 0; y < s.height; y += 7) {
      c.drawLine(Offset(0, y), Offset(s.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
