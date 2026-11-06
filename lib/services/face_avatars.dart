import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Icons, IconData;

/// Un avatar : un personnage dessiné par l'application dont les yeux et la bouche font comme les vôtres (le moteur règle leur ouverture en direct).
/// Trois images : la tête (sans yeux ni bouche), un œil, une bouche. Tout est dessiné ici, sans fichier ni emoji.
class FaceAvatar {
  const FaceAvatar({required this.key, required this.label, required this.icon, required this.head, required this.eye, required this.mouth, this.headSize = 1.55, this.eyeScale = 1.0, this.mouthScale = 1.0});

  final String key;
  final String label;
  final IconData icon;
  final int head; // couleur de la tête
  final int eye; // couleur de l'œil (iris ou voyant)
  final int mouth; // couleur de l'intérieur de la bouche
  final double headSize; // taille de la tête, en largeur de visage
  final double eyeScale;
  final double mouthScale;

  static const all = [
    FaceAvatar(key: 'cat', label: 'Chat', icon: Icons.pets_rounded, head: 0xFF4A4A4F, eye: 0xFFFFD43B, mouth: 0xFF7A1F2B, headSize: 1.6),
    FaceAvatar(key: 'robot', label: 'Robot', icon: Icons.smart_toy_rounded, head: 0xFF9FB1C0, eye: 0xFF19D3F0, mouth: 0xFF16202A, headSize: 1.5, eyeScale: 1.15),
    FaceAvatar(key: 'bunny', label: 'Lapin', icon: Icons.cruelty_free_rounded, head: 0xFFF2EEE8, eye: 0xFF3B2A22, mouth: 0xFFD6546E, headSize: 1.65),
    FaceAvatar(key: 'alien', label: 'Alien', icon: Icons.rocket_launch_rounded, head: 0xFF6DDB6D, eye: 0xFF10131A, mouth: 0xFF1B4D2B, headSize: 1.5, eyeScale: 1.35),
  ];

  /// Les trois images PNG : [tête, œil, bouche].
  Future<List<Uint8List>> render() async => [await _head(), await _eye(), await _mouth()];

  Future<Uint8List> _png(int w, int h, void Function(ui.Canvas, ui.Size) draw) async {
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    draw(canvas, ui.Size(w.toDouble(), h.toDouble()));
    final img = await rec.endRecording().toImage(w, h);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  ui.Paint _fill(int color) => ui.Paint()..color = ui.Color(color)..isAntiAlias = true;

  ui.Paint _line(int color, double w) => ui.Paint()
    ..color = ui.Color(color)
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = ui.StrokeCap.round
    ..isAntiAlias = true;

  Future<Uint8List> _head() => _png(512, 512, (c, s) {
        const mid = ui.Offset(256, 270);
        final base = _fill(head);
        final dark = _fill(0x33000000);
        switch (key) {
          case 'cat':
            _ear(c, base, const ui.Offset(120, 150), const ui.Offset(190, 70), const ui.Offset(230, 110));
            _ear(c, base, const ui.Offset(392, 150), const ui.Offset(322, 70), const ui.Offset(282, 110));
            _ear(c, _fill(0xFFE59AA8), const ui.Offset(150, 140), const ui.Offset(190, 100), const ui.Offset(212, 122));
            _ear(c, _fill(0xFFE59AA8), const ui.Offset(362, 140), const ui.Offset(322, 100), const ui.Offset(300, 122));
            c.drawCircle(mid, 190, base);
            c.drawOval(ui.Rect.fromCenter(center: const ui.Offset(256, 340), width: 220, height: 150), _fill(0xFFF4F1EC));
            c.drawPath(ui.Path()..moveTo(236, 318)..lineTo(276, 318)..lineTo(256, 342)..close(), _fill(0xFFE59AA8));
            for (final y in [330.0, 352.0, 374.0]) {
              c.drawLine(const ui.Offset(80, 330) + ui.Offset(0, y - 330), ui.Offset(160, y - 6), _line(0xFFFFFFFF, 5));
              c.drawLine(ui.Offset(432, y), ui.Offset(352, y - 6), _line(0xFFFFFFFF, 5));
            }
          case 'robot':
            c.drawLine(const ui.Offset(256, 90), const ui.Offset(256, 40), _line(0xFF6B7C8A, 10));
            c.drawCircle(const ui.Offset(256, 36), 18, _fill(0xFFE5383B));
            c.drawRRect(ui.RRect.fromRectAndRadius(ui.Rect.fromCenter(center: mid, width: 380, height: 340), const ui.Radius.circular(70)), base);
            c.drawRRect(ui.RRect.fromRectAndRadius(ui.Rect.fromCenter(center: mid, width: 380, height: 340), const ui.Radius.circular(70)), _line(0xFF6B7C8A, 10));
            c.drawRect(ui.Rect.fromCenter(center: const ui.Offset(60, 270), width: 28, height: 90), _fill(0xFF6B7C8A));
            c.drawRect(ui.Rect.fromCenter(center: const ui.Offset(452, 270), width: 28, height: 90), _fill(0xFF6B7C8A));
            for (final x in [180.0, 256.0, 332.0]) {
              c.drawCircle(ui.Offset(x, 400), 6, dark);
            }
          case 'bunny':
            c.drawOval(ui.Rect.fromCenter(center: const ui.Offset(190, 90), width: 80, height: 190), base);
            c.drawOval(ui.Rect.fromCenter(center: const ui.Offset(322, 90), width: 80, height: 190), base);
            c.drawOval(ui.Rect.fromCenter(center: const ui.Offset(190, 96), width: 36, height: 140), _fill(0xFFF2B6C4));
            c.drawOval(ui.Rect.fromCenter(center: const ui.Offset(322, 96), width: 36, height: 140), _fill(0xFFF2B6C4));
            c.drawCircle(const ui.Offset(256, 290), 190, base);
            c.drawCircle(const ui.Offset(170, 340), 34, _fill(0x33F28CA8));
            c.drawCircle(const ui.Offset(342, 340), 34, _fill(0x33F28CA8));
            c.drawOval(ui.Rect.fromCenter(center: const ui.Offset(256, 322), width: 36, height: 24), _fill(0xFFE59AA8));
          default: // alien
            c.drawOval(ui.Rect.fromCenter(center: const ui.Offset(256, 255), width: 360, height: 460), base);
            c.drawOval(ui.Rect.fromCenter(center: const ui.Offset(256, 255), width: 360, height: 460), _line(0x33000000, 6));
            c.drawCircle(const ui.Offset(256, 400), 6, dark);
        }
      });

  void _ear(ui.Canvas c, ui.Paint p, ui.Offset a, ui.Offset b, ui.Offset d) {
    c.drawPath(ui.Path()..moveTo(a.dx, a.dy)..lineTo(b.dx, b.dy)..lineTo(d.dx, d.dy)..close(), p);
  }

  /// Œil ouvert : le moteur l'aplatit pour faire cligner.
  Future<Uint8List> _eye() => _png(128, 128, (c, s) {
        if (key == 'robot') {
          c.drawRRect(ui.RRect.fromRectAndRadius(ui.Rect.fromLTWH(10, 24, 108, 80), const ui.Radius.circular(18)), _fill(0xFF0E1A22));
          c.drawRRect(ui.RRect.fromRectAndRadius(ui.Rect.fromLTWH(22, 36, 84, 56), const ui.Radius.circular(12)), _fill(eye));
          return;
        }
        c.drawOval(ui.Rect.fromLTWH(6, 14, 116, 100), _fill(key == 'alien' ? 0xFF10131A : 0xFFFFFFFF));
        if (key == 'alien') {
          c.drawOval(ui.Rect.fromLTWH(34, 34, 28, 22), _fill(0x66FFFFFF));
          return;
        }
        c.drawOval(ui.Rect.fromLTWH(34, 18, 60, 92), _fill(eye));
        c.drawOval(ui.Rect.fromLTWH(50, 30, 28, 68), _fill(0xFF000000));
        c.drawCircle(const ui.Offset(54, 44), 8, _fill(0xFFFFFFFF));
      });

  /// Bouche ouverte : le moteur l'aplatit pour la fermer (un trait).
  Future<Uint8List> _mouth() => _png(192, 128, (c, s) {
        final rect = ui.Rect.fromLTWH(6, 6, 180, 116);
        c.drawOval(rect, _fill(0xFF1A0E10));
        c.save();
        c.clipPath(ui.Path()..addOval(rect.deflate(8)));
        c.drawRect(rect, _fill(mouth));
        c.drawOval(ui.Rect.fromLTWH(52, 70, 88, 70), _fill(0xFFE5707F));
        c.restore();
        if (key == 'bunny') {
          c.drawRRect(ui.RRect.fromRectAndRadius(ui.Rect.fromLTWH(78, 8, 36, 40), const ui.Radius.circular(8)), _fill(0xFFFFFFFF));
        }
        if (key == 'robot') {
          c.drawRect(ui.Rect.fromLTWH(30, 40, 132, 44), _fill(0xFFB8C4CE));
          for (var i = 1; i < 6; i++) {
            c.drawLine(ui.Offset(30 + i * 22.0, 40), ui.Offset(30 + i * 22.0, 84), _line(0xFF16202A, 3));
          }
        }
      });
}
