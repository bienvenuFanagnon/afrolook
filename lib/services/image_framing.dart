import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Offset, Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

/// Cadrage d'UNE image dans son cadre (08/11/2026) : zoom (1 = l'image remplit le cadre, 4 au plus) et centre de la partie visible (fractions 0 à 1 de l'image).
/// Sert aux trois modes de plusieurs images (carrousel, collage, diaporama) : le cadrage est fait sur le téléphone, et ce sont les images DÉJÀ CADRÉES qui sont envoyées,
/// donc l'aperçu est exactement ce qui sera publié, sans rien changer côté serveur.
@immutable
class ImageFraming {
  const ImageFraming({this.zoom = 1, this.cx = .5, this.cy = .5});

  static const double maxZoom = 4;

  final double zoom;
  final double cx;
  final double cy;

  /// Image non recadrée à la main (le serveur et le collage la centrent déjà).
  bool get isDefault => zoom <= 1.0001 && (cx - .5).abs() < .0005 && (cy - .5).abs() < .0005;

  ImageFraming copyWith({double? zoom, double? cx, double? cy}) => ImageFraming(zoom: (zoom ?? this.zoom).clamp(1.0, maxZoom).toDouble(), cx: (cx ?? this.cx).clamp(0.0, 1.0).toDouble(), cy: (cy ?? this.cy).clamp(0.0, 1.0).toDouble());

  @override
  bool operator ==(Object other) => other is ImageFraming && other.zoom == zoom && other.cx == cx && other.cy == cy;

  @override
  int get hashCode => Object.hash(zoom, cx, cy);
}

class FramingMath {
  FramingMath._();

  /// Partie de l'image [imgW] x [imgH] qui remplit un cadre de rapport [frameAspect] (largeur / hauteur), avec le zoom et le centre de [f].
  /// Jamais déformée, toujours entièrement DANS l'image (le centre est ramené si besoin).
  static Rect sourceRect(double imgW, double imgH, double frameAspect, ImageFraming f) {
    if (imgW <= 0 || imgH <= 0 || frameAspect <= 0) return Rect.fromLTWH(0, 0, math.max(imgW, 0), math.max(imgH, 0));
    final imgAspect = imgW / imgH;
    // plus grand rectangle de ce rapport contenu dans l'image
    final baseW = imgAspect > frameAspect ? imgH * frameAspect : imgW;
    final baseH = imgAspect > frameAspect ? imgH : imgW / frameAspect;
    final z = f.zoom.clamp(1.0, ImageFraming.maxZoom).toDouble();
    final w = baseW / z;
    final h = baseH / z;
    final cx = (f.cx * imgW).clamp(w / 2, imgW - w / 2).toDouble();
    final cy = (f.cy * imgH).clamp(h / 2, imgH - h / 2).toDouble();
    return Rect.fromLTWH(cx - w / 2, cy - h / 2, w, h);
  }

  /// Nouveau cadrage après un glissement de [delta] pixels dans un cadre affiché de [frameW] pixels de large (l'image suit le doigt).
  static ImageFraming pan(ImageFraming f, Offset delta, double imgW, double imgH, double frameAspect, double frameW) {
    final r = sourceRect(imgW, imgH, frameAspect, f);
    final k = r.width / frameW;   // pixels de l'image par pixel de l'écran
    final cx = (r.center.dx - delta.dx * k) / imgW;
    final cy = (r.center.dy - delta.dy * k) / imgH;
    return f.copyWith(cx: cx, cy: cy);
  }

  /// Image cadrée dans un fichier : la partie visible, à la taille [outW] de large (rapport [frameAspect]). JPEG (PNG si la compression n'est pas disponible).
  static Future<File?> renderCrop(String path, ImageFraming f, double frameAspect, {int outW = 1080, int quality = 90, Directory? into}) async {
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: math.max(outW * 2, 1600));
      final img = (await codec.getNextFrame()).image;
      final src = sourceRect(img.width.toDouble(), img.height.toDouble(), frameAspect, f);
      final outH = (outW / frameAspect).round();
      final rec = ui.PictureRecorder();
      final canvas = ui.Canvas(rec);
      canvas.drawImageRect(img, src, ui.Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()), ui.Paint()..filterQuality = ui.FilterQuality.high);
      img.dispose();
      final out = await rec.endRecording().toImage(outW, outH);
      final data = await out.toByteData(format: ui.ImageByteFormat.png);
      out.dispose();
      if (data == null) return null;
      var png = data.buffer.asUint8List();
      var ext = 'png';
      if (!kIsWeb) {
        try {
          final jpg = await FlutterImageCompress.compressWithList(png, minWidth: outW, minHeight: outH, quality: quality, format: CompressFormat.jpeg);
          if (jpg.isNotEmpty) {
            png = Uint8List.fromList(jpg);
            ext = 'jpg';
          }
        } catch (_) {}   // sans compression : le PNG est gardé (plus lourd, mais juste)
      }
      final dir = into ?? await getTemporaryDirectory();
      return await File('${dir.path}/cadre_${DateTime.now().microsecondsSinceEpoch}.$ext').writeAsBytes(png, flush: true);
    } catch (_) {
      return null;
    }
  }
}
