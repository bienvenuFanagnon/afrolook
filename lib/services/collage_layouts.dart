import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'image_framing.dart';

/// Mises en page du collage (2 à 5 images dans UNE image) : cases en fractions du cadre (0 à 1), avec un espace réglable entre les images (0 = collées).
class CollageLayouts {
  CollageLayouts._();

  /// Nombre d'images au minimum et au maximum d'un collage.
  static const int minImages = 2;
  static const int maxImages = 5;

  /// Rapport largeur / hauteur de l'image du collage (format d'un post 4:5).
  static const double aspect = 4 / 5;

  static const Map<int, List<String>> idsByCount = {
    2: ['tb', 'sbs'],
    3: ['left1', 'top1', 'rows3'],
    4: ['grid', 'left1_3'],
    5: ['top2_3', 'top1_4'],
  };

  static const Map<String, String> labels = {
    'tb': 'Haut / bas',
    'sbs': 'Côte à côte',
    'left1': '1 grande à gauche',
    'top1': '1 grande en haut',
    'rows3': '3 bandes',
    'grid': 'Grille',
    'left1_3': '1 grande + 3',
    'top2_3': '2 + 3',
    'top1_4': '1 grande + 4',
  };

  /// Les mises en page possibles pour [n] images (la première est celle par défaut).
  static List<String> forCount(int n) => idsByCount[n.clamp(minImages, maxImages)] ?? const ['tb'];

  /// Cases sans espace, en fractions du cadre. Vide si l'identifiant ne correspond pas à [n].
  static List<Rect> cells(String id, int n) {
    const t = 1 / 3;
    const q = 1 / 4;
    final List<Rect> r = switch (id) {
      'tb' => const [Rect.fromLTWH(0, 0, 1, .5), Rect.fromLTWH(0, .5, 1, .5)],
      'sbs' => const [Rect.fromLTWH(0, 0, .5, 1), Rect.fromLTWH(.5, 0, .5, 1)],
      'left1' => const [Rect.fromLTWH(0, 0, .5, 1), Rect.fromLTWH(.5, 0, .5, .5), Rect.fromLTWH(.5, .5, .5, .5)],
      'top1' => const [Rect.fromLTWH(0, 0, 1, .5), Rect.fromLTWH(0, .5, .5, .5), Rect.fromLTWH(.5, .5, .5, .5)],
      'rows3' => const [Rect.fromLTWH(0, 0, 1, t), Rect.fromLTWH(0, t, 1, t), Rect.fromLTWH(0, 2 * t, 1, t)],
      'grid' => const [Rect.fromLTWH(0, 0, .5, .5), Rect.fromLTWH(.5, 0, .5, .5), Rect.fromLTWH(0, .5, .5, .5), Rect.fromLTWH(.5, .5, .5, .5)],
      'left1_3' => const [Rect.fromLTWH(0, 0, .5, 1), Rect.fromLTWH(.5, 0, .5, t), Rect.fromLTWH(.5, t, .5, t), Rect.fromLTWH(.5, 2 * t, .5, t)],
      'top2_3' => const [Rect.fromLTWH(0, 0, .5, .5), Rect.fromLTWH(.5, 0, .5, .5), Rect.fromLTWH(0, .5, t, .5), Rect.fromLTWH(t, .5, t, .5), Rect.fromLTWH(2 * t, .5, t, .5)],
      'top1_4' => const [Rect.fromLTWH(0, 0, 1, .5), Rect.fromLTWH(0, .5, q, .5), Rect.fromLTWH(q, .5, q, .5), Rect.fromLTWH(2 * q, .5, q, .5), Rect.fromLTWH(3 * q, .5, q, .5)],
      _ => const [],
    };
    return r.length == n ? r : const [];
  }

  /// Cases avec l'espace [gap] (fraction de la largeur du cadre, 0 = collées) : chaque case est rétrécie de la moitié de l'espace de chaque côté.
  static List<Rect> withGap(List<Rect> cells, double gap) {
    final g = gap.clamp(0.0, 0.1) / 2;
    return [for (final c in cells) Rect.fromLTRB(c.left + g, c.top + g * aspect, c.right - g, c.bottom - g * aspect)];
  }

  /// Zone de l'image [imgW] x [imgH] qui remplit une case de [cellW] x [cellH] (recadrée au centre, jamais déformée).
  static Rect coverSource(double imgW, double imgH, double cellW, double cellH) {
    if (imgW <= 0 || imgH <= 0 || cellW <= 0 || cellH <= 0) return Rect.fromLTWH(0, 0, imgW, imgH);
    final cellAspect = cellW / cellH;
    final imgAspect = imgW / imgH;
    if (imgAspect > cellAspect) {
      final w = imgH * cellAspect;
      return Rect.fromLTWH((imgW - w) / 2, 0, w, imgH);
    }
    final h = imgW / cellAspect;
    return Rect.fromLTWH(0, (imgH - h) / 2, imgW, h);
  }

  /// Dessine le collage en une image PNG (largeur [width], format 4:5) et rend le fichier. Fond sombre dans les espaces.
  static Future<File> render(List<String> paths, String layout, {double gap = 0, int width = 1080, Map<String, ImageFraming>? framings, Directory? into}) async {
    final n = paths.length;
    final cells = withGap(cells0(layout, n), gap);
    final height = (width / aspect).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), Paint()..color = const Color(0xFF111111));
    for (var i = 0; i < n; i++) {
      final cell = cells[i];
      final dst = Rect.fromLTWH(cell.left * width, cell.top * height, cell.width * width, cell.height * height);
      final bytes = await File(paths[i]).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1600);
      final img = (await codec.getNextFrame()).image;
      // le cadrage choisi par la personne (zoom, déplacement) ; sans cadrage, l'image est recadrée au centre comme avant
      final src = FramingMath.sourceRect(img.width.toDouble(), img.height.toDouble(), dst.width / dst.height, framings?[paths[i]] ?? const ImageFraming());
      canvas.drawImageRect(img, src, dst, Paint()..filterQuality = FilterQuality.high);
      img.dispose();
    }
    final out = await recorder.endRecording().toImage(width, height);
    final data = await out.toByteData(format: ui.ImageByteFormat.png);
    out.dispose();
    final dir = into ?? await getTemporaryDirectory();
    final f = File('${dir.path}/collage_${DateTime.now().microsecondsSinceEpoch}.png');
    await f.writeAsBytes(data!.buffer.asUint8List());
    return f;
  }

  /// Cases d'une mise en page ; si elle ne convient pas à [n] images, la première mise en page possible.
  static List<Rect> cells0(String id, int n) {
    final c = cells(id, n);
    return c.isNotEmpty ? c : cells(forCount(n).first, n);
  }
}
