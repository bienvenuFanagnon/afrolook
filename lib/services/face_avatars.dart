import 'dart:math' as math;
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
    FaceAvatar(key: 'alien', label: 'Alien vert', icon: Icons.rocket_launch_rounded, head: 0xFF6DDB6D, eye: 0xFF10131A, mouth: 0xFF1B4D2B, headSize: 1.5, eyeScale: 1.35),
    FaceAvatar(key: 'alien_purple', label: 'Alien violet', icon: Icons.blur_circular_rounded, head: 0xFF9B6BDB, eye: 0xFFFFE066, mouth: 0xFF3A1B5C, headSize: 1.55, eyeScale: 1.5),
    FaceAvatar(key: 'alien_blue', label: 'Alien bleu', icon: Icons.stars_rounded, head: 0xFF5BB6E8, eye: 0xFF0B1A33, mouth: 0xFF0B3A5C, headSize: 1.6, eyeScale: 1.25),
    FaceAvatar(key: 'dog', label: 'Chien', icon: Icons.pets_rounded, head: 0xFFC98A55, eye: 0xFF2A1A10, mouth: 0xFF8A2B3A, headSize: 1.6),
    FaceAvatar(key: 'mouse', label: 'Souris', icon: Icons.cruelty_free_rounded, head: 0xFFB9B9C4, eye: 0xFF1B1B25, mouth: 0xFFD6546E, headSize: 1.55),
    FaceAvatar(key: 'panda', label: 'Panda', icon: Icons.emoji_nature_rounded, head: 0xFFF4F4F4, eye: 0xFFFFFFFF, mouth: 0xFF7A1F2B, headSize: 1.6),
    FaceAvatar(key: 'lion', label: 'Lion', icon: Icons.sentiment_very_satisfied_rounded, head: 0xFFE0A33A, eye: 0xFF3B2A12, mouth: 0xFF7A1F2B, headSize: 1.75),
    FaceAvatar(key: 'monkey', label: 'Singe', icon: Icons.mood_rounded, head: 0xFF7A4B2A, eye: 0xFF1B1B1B, mouth: 0xFF5C1B22, headSize: 1.6),
    FaceAvatar(key: 'dragon', label: 'Dragon', icon: Icons.whatshot_rounded, head: 0xFF3FA34D, eye: 0xFFFFB300, mouth: 0xFF8A1B12, headSize: 1.7, eyeScale: 1.15),
  ];

  /// Agrandissement de toutes les têtes d'avatars (demande du 09/11/2026 : « agrandis encore plus les avatars sur les visages »). Multiplie [headSize] au moment de l'envoi au moteur.
  static const double sizeBoost = 1.3;

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
          case 'dog':
            // oreilles tombantes, museau clair, truffe
            c.drawOval(ui.Rect.fromCenter(center: const ui.Offset(96, 230), width: 110, height: 220), _fill(0xFF8A5530));
            c.drawOval(ui.Rect.fromCenter(center: const ui.Offset(416, 230), width: 110, height: 220), _fill(0xFF8A5530));
            c.drawCircle(mid, 185, base);
            c.drawOval(ui.Rect.fromCenter(center: const ui.Offset(256, 345), width: 200, height: 140), _fill(0xFFF1D9B8));
            c.drawOval(ui.Rect.fromCenter(center: const ui.Offset(256, 318), width: 56, height: 38), _fill(0xFF1B1B1B));
          case 'mouse':
            // grandes oreilles rondes roses, museau
            c.drawCircle(const ui.Offset(120, 110), 82, base);
            c.drawCircle(const ui.Offset(392, 110), 82, base);
            c.drawCircle(const ui.Offset(120, 110), 52, _fill(0xFFF2B6C4));
            c.drawCircle(const ui.Offset(392, 110), 52, _fill(0xFFF2B6C4));
            c.drawCircle(mid, 185, base);
            c.drawOval(ui.Rect.fromCenter(center: const ui.Offset(256, 330), width: 40, height: 30), _fill(0xFFE59AA8));
            for (final y in [330.0, 356.0]) {
              c.drawLine(ui.Offset(150, y), ui.Offset(70, y - 10), _line(0xFF888894, 4));
              c.drawLine(ui.Offset(362, y), ui.Offset(442, y - 10), _line(0xFF888894, 4));
            }
          case 'panda':
            c.drawCircle(const ui.Offset(120, 110), 70, _fill(0xFF1B1B1B));
            c.drawCircle(const ui.Offset(392, 110), 70, _fill(0xFF1B1B1B));
            c.drawCircle(mid, 190, base);
            c.drawOval(ui.Rect.fromCenter(center: const ui.Offset(184, 245), width: 96, height: 120), _fill(0xFF1B1B1B));
            c.drawOval(ui.Rect.fromCenter(center: const ui.Offset(328, 245), width: 96, height: 120), _fill(0xFF1B1B1B));
            c.drawOval(ui.Rect.fromCenter(center: const ui.Offset(256, 330), width: 54, height: 38), _fill(0xFF1B1B1B));
          case 'lion':
            // crinière
            c.drawCircle(mid, 240, _fill(0xFF9A5B1E));
            for (var i = 0; i < 14; i++) {
              final a = i * math.pi * 2 / 14;
              c.drawCircle(ui.Offset(256 + 215 * math.cos(a), 270 + 215 * math.sin(a)), 46, _fill(0xFFB5712A));
            }
            c.drawCircle(const ui.Offset(150, 120), 40, base);
            c.drawCircle(const ui.Offset(362, 120), 40, base);
            c.drawCircle(mid, 170, base);
            c.drawOval(ui.Rect.fromCenter(center: const ui.Offset(256, 345), width: 150, height: 110), _fill(0xFFF3DDB0));
            c.drawPath(ui.Path()..moveTo(236, 318)..lineTo(276, 318)..lineTo(256, 340)..close(), _fill(0xFF5C2B1B));
          case 'monkey':
            c.drawCircle(const ui.Offset(78, 270), 62, base);
            c.drawCircle(const ui.Offset(434, 270), 62, base);
            c.drawCircle(const ui.Offset(78, 270), 36, _fill(0xFFE6B890));
            c.drawCircle(const ui.Offset(434, 270), 36, _fill(0xFFE6B890));
            c.drawCircle(mid, 185, base);
            c.drawOval(ui.Rect.fromCenter(center: const ui.Offset(256, 300), width: 260, height: 210), _fill(0xFFE6B890));
            c.drawOval(ui.Rect.fromCenter(center: const ui.Offset(256, 270), width: 280, height: 90), _fill(0xFFE6B890));
          case 'dragon':
            // cornes ivoire, ailerons pointus sur les côtés, crête dorsale, museau clair avec narines, arcades sourcilières
            _ear(c, _fill(0xFFE8D9A8), const ui.Offset(150, 125), const ui.Offset(100, 12), const ui.Offset(212, 92));
            _ear(c, _fill(0xFFE8D9A8), const ui.Offset(362, 125), const ui.Offset(412, 12), const ui.Offset(300, 92));
            _ear(c, _fill(0xFF2D7A39), const ui.Offset(78, 235), const ui.Offset(0, 150), const ui.Offset(100, 190));
            _ear(c, _fill(0xFF2D7A39), const ui.Offset(434, 235), const ui.Offset(512, 150), const ui.Offset(412, 190));
            for (final x in [226.0, 256.0, 286.0]) {
              _ear(c, _fill(0xFFE5383B), ui.Offset(x - 16, 98), ui.Offset(x, 30 + (x - 256).abs() * .9), ui.Offset(x + 16, 98));
            }
            c.drawOval(ui.Rect.fromCenter(center: mid, width: 380, height: 380), base);
            for (final p in const [ui.Offset(190, 130), ui.Offset(256, 112), ui.Offset(322, 130), ui.Offset(150, 190), ui.Offset(362, 190)]) {
              c.drawCircle(p, 12, _fill(0x332D7A39));
            }
            c.drawOval(ui.Rect.fromCenter(center: const ui.Offset(256, 350), width: 250, height: 160), _fill(0xFF8FD39A));
            c.drawOval(ui.Rect.fromCenter(center: const ui.Offset(222, 318), width: 22, height: 30), _fill(0xFF1D5A28));
            c.drawOval(ui.Rect.fromCenter(center: const ui.Offset(290, 318), width: 22, height: 30), _fill(0xFF1D5A28));
            c.drawLine(const ui.Offset(118, 178), const ui.Offset(204, 206), _line(0xFF2D7A39, 16));
            c.drawLine(const ui.Offset(394, 178), const ui.Offset(308, 206), _line(0xFF2D7A39, 16));
          case 'alien_purple':
            // trois antennes
            for (final x in [176.0, 256.0, 336.0]) {
              c.drawLine(ui.Offset(x, 110), ui.Offset(x + (x - 256) * .6, 28), _line(0xFF7A4FB5, 8));
              c.drawCircle(ui.Offset(x + (x - 256) * .6, 28), 14, _fill(0xFFFFE066));
            }
            c.drawOval(ui.Rect.fromCenter(center: const ui.Offset(256, 270), width: 400, height: 420), base);
          case 'alien_blue':
            // grandes oreilles pointues
            _ear(c, base, const ui.Offset(70, 250), const ui.Offset(10, 120), const ui.Offset(120, 190));
            _ear(c, base, const ui.Offset(442, 250), const ui.Offset(502, 120), const ui.Offset(392, 190));
            c.drawOval(ui.Rect.fromCenter(center: const ui.Offset(256, 265), width: 360, height: 430), base);
            c.drawCircle(const ui.Offset(256, 120), 10, _fill(0xFFFFFFFF));
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
        final dark = key == 'alien' || key == 'alien_purple' || key == 'alien_blue';
        c.drawOval(ui.Rect.fromLTWH(6, 14, 116, 100), _fill(dark ? 0xFF10131A : (key == 'panda' ? 0xFF1B1B1B : 0xFFFFFFFF)));
        if (key == 'panda') {
          c.drawCircle(const ui.Offset(64, 64), 26, _fill(0xFFFFFFFF));
          c.drawCircle(const ui.Offset(64, 64), 12, _fill(0xFF000000));
          return;
        }
        if (dark) {
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
        if (key == 'dragon') {
          // crocs en haut et en bas
          for (final x in [44.0, 134.0]) {
            c.drawPath(ui.Path()..moveTo(x, 22)..lineTo(x + 18, 22)..lineTo(x + 9, 60)..close(), _fill(0xFFFFFFFF));
            c.drawPath(ui.Path()..moveTo(x + 6, 112)..lineTo(x + 24, 112)..lineTo(x + 15, 76)..close(), _fill(0xFFFFFFFF));
          }
        }
        if (key == 'robot') {
          c.drawRect(ui.Rect.fromLTWH(30, 40, 132, 44), _fill(0xFFB8C4CE));
          for (var i = 1; i < 6; i++) {
            c.drawLine(ui.Offset(30 + i * 22.0, 40), ui.Offset(30 + i * 22.0, 84), _line(0xFF16202A, 3));
          }
        }
      });
}
