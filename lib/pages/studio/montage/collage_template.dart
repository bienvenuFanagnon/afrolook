// Modèles « collage » (09/11/2026) : 2 à 5 photos de la personne posées dans une mise en page, avec une étiquette par case (« AVANT » / « APRÈS », un mois…) et un titre.
// Le résultat est UNE image que l'éditeur habituel reprend (texte, musique, effets, widgets).

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

import '../../../services/collage_layouts.dart';

class CollageScript {
  const CollageScript({required this.layout, required this.labels, this.caption = ''});

  /// Mise en page (identifiant de `CollageLayouts`) ; le nombre de cases est `labels.length`.
  final String layout;

  /// Étiquette de chaque case (vide = aucune).
  final List<String> labels;

  /// Titre posé en bas de l'image.
  final String caption;

  int get slots => labels.length;
}

/// Scripts des modèles collage, par identifiant de modèle du catalogue.
CollageScript? collageScriptFor(String templateId) {
  final next = DateTime.now().month >= 9 ? DateTime.now().year + 1 : DateTime.now().year;
  final end = next - 1;
  switch (templateId) {
    case 'multi_avant_apres':
      return const CollageScript(layout: 'sbs', labels: ['AVANT', 'APRÈS'], caption: 'Ma transformation');
    case 'multi_duo':
      return const CollageScript(layout: 'tb', labels: ['', ''], caption: 'Nous deux 💞');
    case 'multi_cinq_moments':
      return CollageScript(layout: 'top1_4', labels: const ['', '', '', '', ''], caption: 'Mes 5 moments de $end');
    case 'multi_quatre_saisons':
      return CollageScript(layout: 'grid', labels: const ['MARS', 'JUIN', 'SEPTEMBRE', 'DÉCEMBRE'], caption: 'Mon année $end en 4 photos');
  }
  return null;
}

/// Identifiants des modèles du catalogue qui sont des collages.
const kCollageTemplateIds = {'multi_avant_apres', 'multi_duo', 'multi_cinq_moments', 'multi_quatre_saisons'};

class CollageTemplateRender {
  CollageTemplateRender._();

  /// Dessine le collage (format 4:5) : photos recadrées au centre, étiquettes en haut de chaque case, titre en bas. Rend les octets PNG.
  static Future<Uint8List> png(List<Uint8List> photos, CollageScript s, {List<String>? labels, String? caption, int width = 1080}) async {
    final n = photos.length;
    final cells = CollageLayouts.withGap(CollageLayouts.cells0(s.layout, n), .012);
    final height = (width / CollageLayouts.aspect).round();
    final w = width.toDouble();
    final h = height.toDouble();
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFF111111));
    for (var i = 0; i < n; i++) {
      final cell = cells[i];
      final dst = Rect.fromLTWH(cell.left * w, cell.top * h, cell.width * w, cell.height * h);
      try {
        final codec = await ui.instantiateImageCodec(photos[i], targetWidth: 1600);
        final img = (await codec.getNextFrame()).image;
        c.drawImageRect(img, CollageLayouts.coverSource(img.width.toDouble(), img.height.toDouble(), dst.width, dst.height), dst, Paint()..filterQuality = FilterQuality.high);
        img.dispose();
      } catch (_) {
        // photo illisible : la case reste sombre
      }
      final label = ((labels != null && i < labels.length) ? labels[i] : (i < s.labels.length ? s.labels[i] : '')).trim();
      if (label.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(text: label, style: TextStyle(color: const Color(0xFF000000), fontSize: width * .04, fontWeight: FontWeight.w900, letterSpacing: width * .004)),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: dst.width - 24);
        final pad = width * .016;
        final r = RRect.fromRectAndRadius(Rect.fromLTWH(dst.left + 14, dst.top + 14, tp.width + pad * 2, tp.height + pad), Radius.circular(width * .014));
        c.drawRRect(r, Paint()..color = const Color(0xFFFFD400));
        tp.paint(c, Offset(r.left + pad, r.top + pad / 2));
      }
    }
    final cap = (caption ?? s.caption).trim();
    if (cap.isNotEmpty) {
      c.drawRect(Rect.fromLTWH(0, h * .86, w, h * .14), Paint()..shader = ui.Gradient.linear(Offset(0, h * .86), Offset(0, h), const [Color(0x00000000), Color(0xCC000000)]));
      final tp = TextPainter(
        text: TextSpan(
          text: cap,
          style: TextStyle(color: const Color(0xFFFFFFFF), fontSize: width * .06, fontWeight: FontWeight.w900, shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 10)]),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: w - 80);
      tp.paint(c, Offset((w - tp.width) / 2, h - tp.height - h * .03));
    }
    final pic = rec.endRecording();
    final out = await pic.toImage(width, height);
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    out.dispose();
    pic.dispose();
    return data!.buffer.asUint8List();
  }

  static Future<File> toFile(Uint8List png) async {
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/collage_modele_${DateTime.now().microsecondsSinceEpoch}.png').writeAsBytes(png, flush: true);
  }
}
