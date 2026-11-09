import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'story_script.dart';

/// Dessine un acte d'histoire en image (9:16) : la photo de la personne en plein cadre (ou un fond uni si elle n'en a pas mis), un voile selon l'ambiance, une petite ligne, puis la phrase en grand.
/// Fait avec le moteur de dessin seul (pas de widget) : le même résultat sur l'aperçu et sur le fichier envoyé au diaporama.
class StoryRender {
  StoryRender._();

  static const double ratio = 9 / 16;

  static List<ui.Color> _veil(StoryTone t) => switch (t) {
        StoryTone.dark => const [ui.Color(0x59000000), ui.Color(0xDB000000)],
        StoryTone.gold => const [ui.Color(0x2BFFC800), ui.Color(0xB8281800)],
        StoryTone.light => const [ui.Color(0x1FFFFFFF), ui.Color(0x99182030)],
        StoryTone.rose => const [ui.Color(0x2EFF3C78), ui.Color(0xA3780028)],
        StoryTone.night => const [ui.Color(0x80000028), ui.Color(0xE0000014)],
      };

  static ui.Color _kick(StoryTone t) => switch (t) {
        StoryTone.rose => const ui.Color(0xFFFFB3C7),
        StoryTone.light => const ui.Color(0xFFFFFFFF),
        _ => const ui.Color(0xFFFFD400),
      };

  /// Taille de la phrase selon sa longueur (en pixels pour une image de 720 de large).
  static double fontFor(String text) {
    final n = text.runes.length;
    if (n <= 16) return 92;
    if (n <= 34) return 72;
    if (n <= 60) return 58;
    return 48;
  }

  /// PNG de l'acte [act], de largeur [width] (720 pour le fichier envoyé, moins pour l'aperçu). [photo] : octets de l'image de la personne (jpeg, png…), ou null.
  static Future<Uint8List> png(StoryAct act, {Uint8List? photo, int width = 720}) async {
    final w = width.toDouble();
    final h = (width / ratio).roundToDouble();
    final k = w / 720;
    final rec = ui.PictureRecorder();
    final c = ui.Canvas(rec, ui.Rect.fromLTWH(0, 0, w, h));
    final veil = _veil(act.tone);

    // fond : photo en plein cadre (recadrée au centre) ou dégradé uni
    c.drawRect(ui.Rect.fromLTWH(0, 0, w, h), ui.Paint()..color = const ui.Color(0xFF0B0B10));
    if (photo != null) {
      ui.Image? img;
      try {
        final codec = await ui.instantiateImageCodec(photo, targetWidth: width * 2);
        img = (await codec.getNextFrame()).image;
        final iw = img.width.toDouble();
        final ih = img.height.toDouble();
        final scale = (w / iw) > (h / ih) ? w / iw : h / ih;
        final sw = w / scale;
        final sh = h / scale;
        c.drawImageRect(img, ui.Rect.fromLTWH((iw - sw) / 2, (ih - sh) / 2, sw, sh), ui.Rect.fromLTWH(0, 0, w, h), ui.Paint()..filterQuality = ui.FilterQuality.medium);
      } catch (_) {
        // photo illisible : le fond uni reste
      } finally {
        img?.dispose();
      }
    }
    c.drawRect(
      ui.Rect.fromLTWH(0, 0, w, h),
      ui.Paint()..shader = ui.Gradient.linear(ui.Offset.zero, ui.Offset(0, h), veil),
    );

    // petite ligne du haut, puis la phrase centrée dans le tiers bas (un fond uni : au milieu)
    var y = photo == null ? h * .36 : h * .58;
    if (act.kick.trim().isNotEmpty) {
      final kp = TextPainter(
        text: TextSpan(text: act.kick.toUpperCase(), style: TextStyle(color: _kick(act.tone), fontSize: 34 * k, fontWeight: FontWeight.w800, letterSpacing: 4 * k)),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: w - 120 * k);
      kp.paint(c, ui.Offset((w - kp.width) / 2, y));
      y += kp.height + 22 * k;
    }
    final tp = TextPainter(
      text: TextSpan(
        text: act.text,
        style: TextStyle(
          color: const ui.Color(0xFFFFFFFF),
          fontSize: fontFor(act.text) * k,
          fontWeight: FontWeight.w900,
          height: 1.12,
          shadows: [Shadow(color: const ui.Color(0xCC000000), blurRadius: 14 * k, offset: ui.Offset(0, 3 * k))],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: w - 110 * k);
    tp.paint(c, ui.Offset((w - tp.width) / 2, y));

    final pic = rec.endRecording();
    final out = await pic.toImage(width, h.round());
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    out.dispose();
    pic.dispose();
    return data!.buffer.asUint8List();
  }
}
