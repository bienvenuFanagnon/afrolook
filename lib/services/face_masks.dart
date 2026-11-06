import 'dart:ui' as ui;

/// Masques dessinés (sans image à télécharger) pour cacher le visage : singe, chat, robot, clown, héros, bandeau noir.
/// Chaque masque se dessine dans un carré de côté [s] centré sur l'origine (coordonnées de −50 à 50, mises à l'échelle).
enum MaskKind { monkey, cat, robot, clown, hero, bar }

class FaceMasks {
  FaceMasks._();

  static void draw(ui.Canvas c, MaskKind kind, double s) {
    c.save();
    final k = s / 100;
    c.scale(k, k);
    switch (kind) {
      case MaskKind.monkey:
        _monkey(c);
      case MaskKind.cat:
        _cat(c);
      case MaskKind.robot:
        _robot(c);
      case MaskKind.clown:
        _clown(c);
      case MaskKind.hero:
        _hero(c);
      case MaskKind.bar:
        _bar(c);
    }
    c.restore();
  }

  static ui.Paint _fill(int argb) => ui.Paint()..color = ui.Color(argb)..isAntiAlias = true;
  static ui.Paint _line(int argb, double w) => ui.Paint()..color = ui.Color(argb)..style = ui.PaintingStyle.stroke..strokeWidth = w..strokeCap = ui.StrokeCap.round..isAntiAlias = true;
  static void _oval(ui.Canvas c, double x, double y, double rx, double ry, ui.Paint p) => c.drawOval(ui.Rect.fromCenter(center: ui.Offset(x, y), width: rx * 2, height: ry * 2), p);

  static void _monkey(ui.Canvas c) {
    _oval(c, -38, -8, 13, 13, _fill(0xFF8A5A33));
    _oval(c, 38, -8, 13, 13, _fill(0xFF8A5A33));
    _oval(c, -38, -8, 7, 7, _fill(0xFFE8C9A0));
    _oval(c, 38, -8, 7, 7, _fill(0xFFE8C9A0));
    _oval(c, 0, 0, 40, 46, _fill(0xFF8A5A33));
    _oval(c, 0, 16, 28, 24, _fill(0xFFE8C9A0));
    _oval(c, -14, -8, 9, 9, _fill(0xFFFFFFFF));
    _oval(c, 14, -8, 9, 9, _fill(0xFFFFFFFF));
    _oval(c, -13, -7, 4.5, 4.5, _fill(0xFF222222));
    _oval(c, 15, -7, 4.5, 4.5, _fill(0xFF222222));
    _oval(c, 0, 8, 6, 4, _fill(0xFF4A2A14));
    c.drawArc(ui.Rect.fromCenter(center: const ui.Offset(0, 20), width: 26, height: 16), 0.2, 2.7, false, _line(0xFF4A2A14, 2.6));
  }

  static void _cat(ui.Canvas c) {
    final ear = ui.Path()..moveTo(-38, -12)..lineTo(-34, -50)..lineTo(-8, -34)..close();
    final ear2 = ui.Path()..moveTo(38, -12)..lineTo(34, -50)..lineTo(8, -34)..close();
    c.drawPath(ear, _fill(0xFF3A3A3A));
    c.drawPath(ear2, _fill(0xFF3A3A3A));
    c.drawPath(ui.Path()..moveTo(-33, -20)..lineTo(-31, -40)..lineTo(-17, -31)..close(), _fill(0xFFF3A6B5));
    c.drawPath(ui.Path()..moveTo(33, -20)..lineTo(31, -40)..lineTo(17, -31)..close(), _fill(0xFFF3A6B5));
    _oval(c, 0, 0, 42, 44, _fill(0xFF4A4A4A));
    _oval(c, 0, 14, 26, 20, _fill(0xFFEDEDED));
    _oval(c, -15, -6, 7, 9, _fill(0xFFFFE066));
    _oval(c, 15, -6, 7, 9, _fill(0xFFFFE066));
    _oval(c, -15, -6, 2.6, 8, _fill(0xFF111111));
    _oval(c, 15, -6, 2.6, 8, _fill(0xFF111111));
    c.drawPath(ui.Path()..moveTo(-5, 6)..lineTo(5, 6)..lineTo(0, 12)..close(), _fill(0xFFF08AA0));
    c.drawArc(ui.Rect.fromCenter(center: const ui.Offset(-5, 15), width: 10, height: 8), 0, 3.0, false, _line(0xFF222222, 1.8));
    c.drawArc(ui.Rect.fromCenter(center: const ui.Offset(5, 15), width: 10, height: 8), 0, 3.0, false, _line(0xFF222222, 1.8));
    for (final y in const [8.0, 13.0, 18.0]) {
      c.drawLine(ui.Offset(-20, y), ui.Offset(-46, y - 3), _line(0xFFFFFFFF, 1.4));
      c.drawLine(ui.Offset(20, y), ui.Offset(46, y - 3), _line(0xFFFFFFFF, 1.4));
    }
  }

  static void _robot(ui.Canvas c) {
    c.drawRect(const ui.Rect.fromLTWH(-2, -50, 4, 12), _fill(0xFF6D7886));
    _oval(c, 0, -50, 5, 5, _fill(0xFFE5383B));
    c.drawRRect(ui.RRect.fromRectAndRadius(const ui.Rect.fromLTRB(-40, -38, 40, 46), const ui.Radius.circular(14)), _fill(0xFF9AA5B1));
    c.drawRRect(ui.RRect.fromRectAndRadius(const ui.Rect.fromLTRB(-32, -20, 32, 4), const ui.Radius.circular(8)), _fill(0xFF17202A));
    _oval(c, -16, -8, 7, 7, _fill(0xFF37E0FF));
    _oval(c, 16, -8, 7, 7, _fill(0xFF37E0FF));
    c.drawRRect(ui.RRect.fromRectAndRadius(const ui.Rect.fromLTRB(-24, 18, 24, 34), const ui.Radius.circular(4)), _fill(0xFF17202A));
    for (var x = -18.0; x <= 18; x += 9) {
      c.drawLine(ui.Offset(x, 20), ui.Offset(x, 32), _line(0xFF9AA5B1, 1.6));
    }
  }

  static void _clown(ui.Canvas c) {
    for (final x in const [-34.0, 34.0]) {
      _oval(c, x, -30, 14, 14, _fill(0xFF2E86DE));
      _oval(c, x * .8, -22, 12, 12, _fill(0xFF2E86DE));
    }
    _oval(c, 0, 0, 40, 46, _fill(0xFFFFFFFF));
    _oval(c, -15, -8, 8, 6, _fill(0xFF222222));
    _oval(c, 15, -8, 8, 6, _fill(0xFF222222));
    c.drawPath(ui.Path()..moveTo(-15, -17)..lineTo(-20, -30)..lineTo(-10, -17)..close(), _fill(0xFFE5383B));
    c.drawPath(ui.Path()..moveTo(15, -17)..lineTo(20, -30)..lineTo(10, -17)..close(), _fill(0xFFE5383B));
    _oval(c, 0, 6, 9, 9, _fill(0xFFE5383B));
    c.drawArc(ui.Rect.fromCenter(center: const ui.Offset(0, 22), width: 34, height: 22), 0.15, 2.85, false, _line(0xFFE5383B, 5));
  }

  static void _hero(ui.Canvas c) {
    final band = ui.Path()
      ..moveTo(-48, -14)
      ..quadraticBezierTo(0, -30, 48, -14)
      ..lineTo(48, 8)
      ..quadraticBezierTo(0, -6, -48, 8)
      ..close();
    // les trous des yeux sont découpés dans la forme (rien n'est effacé sur l'image dessous)
    final holes = ui.Path()
      ..addOval(ui.Rect.fromCenter(center: const ui.Offset(-17, -7), width: 20, height: 11))
      ..addOval(ui.Rect.fromCenter(center: const ui.Offset(17, -7), width: 20, height: 11));
    final mask = ui.Path.combine(ui.PathOperation.difference, band, holes);
    c.drawPath(mask, _fill(0xFF1B1B1B));
    c.drawPath(mask, _line(0xFFFFC400, 1.4));
  }

  static void _bar(ui.Canvas c) {
    c.drawRRect(ui.RRect.fromRectAndRadius(const ui.Rect.fromLTRB(-50, -14, 50, 14), const ui.Radius.circular(3)), _fill(0xFF000000));
  }
}
