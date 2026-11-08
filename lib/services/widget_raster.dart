import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/post_widget.dart';
import '../widgets/post_widget_view.dart';

/// Un widget (sondage, question, lien…) dessiné en image PNG transparente, tel qu'il est affiché maintenant : sert à l'incruster dans une vidéo téléchargée.
class WidgetLayer {
  const WidgetLayer({required this.png, required this.x, required this.y, required this.width, this.start, this.end});

  final Uint8List png;

  /// Centre dans le cadre de la vidéo (fractions de 0 à 1).
  final double x;
  final double y;

  /// Largeur à l'écran en fraction de la largeur de la vidéo (0,1 à 1) : la même taille relative que dans l'application.
  final double width;

  /// Plage de temps (secondes) ; null = toute la vidéo.
  final double? start;
  final double? end;
}

class WidgetRaster {
  WidgetRaster._();

  /// Pose les widgets dessinés sur une image téléchargée (même place et même taille relative qu'à l'écran) et rend l'image en PNG. En cas d'échec, l'image d'origine est rendue.
  static Future<Uint8List> compositeOnImage(Uint8List bytes, List<WidgetLayer> layers) async {
    if (layers.isEmpty) return bytes;
    try {
      final base = (await (await ui.instantiateImageCodec(bytes)).getNextFrame()).image;
      final w = base.width.toDouble();
      final h = base.height.toDouble();
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawImage(base, Offset.zero, Paint());
      for (final l in layers) {
        final img = (await (await ui.instantiateImageCodec(l.png)).getNextFrame()).image;
        final dw = (l.width * w).clamp(1.0, w).toDouble();
        final dh = (dw * img.height / img.width).clamp(1.0, h).toDouble();
        final left = (l.x * w - dw / 2).clamp(0.0, w - dw).toDouble();
        final top = (l.y * h - dh / 2).clamp(0.0, h - dh).toDouble();
        c.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), Rect.fromLTWH(left, top, dw, dh), Paint()..filterQuality = FilterQuality.high);
        img.dispose();
      }
      final out = await rec.endRecording().toImage(base.width, base.height);
      final data = await out.toByteData(format: ui.ImageByteFormat.png);
      base.dispose();
      out.dispose();
      return data == null ? bytes : data.buffer.asUint8List();
    } catch (_) {
      return bytes;
    }
  }

  /// Largeur d'écran de référence (en pixels logiques) : un widget de 270 px sur un écran de 360 px occupe les trois quarts de la vidéo.
  static const referenceWidth = 360.0;

  /// Dessine [w] hors écran (dans l'étage de superposition) et en rend l'image et sa place. Null si impossible : le téléchargement continue sans ce widget.
  static Future<WidgetLayer?> render(BuildContext context, PostWidget w, {double pixelRatio = 3}) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return null;
    final key = GlobalKey();
    final entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -4000,
        top: 0,
        child: Material(
          type: MaterialType.transparency,
          child: RepaintBoundary(key: key, child: PostWidgetView(widget: w, preview: true, showResults: true)),
        ),
      ),
    );
    overlay.insert(entry);
    try {
      for (var i = 0; i < 6; i++) {
        await WidgetsBinding.instance.endOfFrame;
        final ro = key.currentContext?.findRenderObject();
        if (ro is! RenderRepaintBoundary || !ro.hasSize || ro.size.isEmpty) continue;
        try {
          final img = await ro.toImage(pixelRatio: pixelRatio);
          final data = await img.toByteData(format: ui.ImageByteFormat.png);
          img.dispose();
          if (data == null) return null;
          return WidgetLayer(
            png: data.buffer.asUint8List(),
            x: w.x.clamp(0.0, 1.0).toDouble(),
            y: w.y.clamp(0.0, 1.0).toDouble(),
            width: (ro.size.width * w.scale / referenceWidth).clamp(0.1, 1.0).toDouble(),
            start: w.start,
            end: w.end,
          );
        } catch (_) {
          // pas encore dessiné : on réessaie à l'image suivante
        }
      }
      return null;
    } finally {
      entry.remove();
    }
  }
}
