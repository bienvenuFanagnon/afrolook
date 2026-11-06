import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Un visage trouvé dans la photo (pixels de la photo redressée).
class FaceBox {
  const FaceBox({required this.rect, this.leftEye, this.rightEye, this.nose});
  final Rect rect;
  final Offset? leftEye;
  final Offset? rightEye;
  final Offset? nose;

  factory FaceBox.fromMap(Map m) {
    Offset? o(String k) => m[k] is Map ? Offset((m[k]['x'] as num).toDouble(), (m[k]['y'] as num).toDouble()) : null;
    return FaceBox(
      rect: Rect.fromLTWH((m['left'] as num).toDouble(), (m['top'] as num).toDouble(), (m['width'] as num).toDouble(), (m['height'] as num).toDouble()),
      leftEye: o('leftEye'),
      rightEye: o('rightEye'),
      nose: o('nose'),
    );
  }
}

/// Filtres posés sur les visages d'une photo prise avec la caméra de l'application.
/// Disponibles sur Android seulement (détection ML Kit non groupée, sur le téléphone, sans envoi à un serveur) : ailleurs [available] est faux et l'écran cache les filtres.
enum FaceFilter { none, glasses, crown, nose, hearts }

class FaceFilters {
  FaceFilters._();

  static const _channel = MethodChannel('afrolook/faces');

  static bool get available => !kIsWeb && Platform.isAndroid;

  static String emoji(FaceFilter f) => switch (f) {
        FaceFilter.none => '',
        FaceFilter.glasses => '😎',
        FaceFilter.crown => '👑',
        FaceFilter.nose => '🤡',
        FaceFilter.hearts => '😍',
      };

  /// Pose [filter] sur chaque visage de la photo [path] et rend le nouveau fichier. Rend [path] tel quel si aucun visage n'est trouvé ou si la détection échoue
  /// (la photo n'est jamais perdue). [found] dit combien de visages ont reçu le filtre.
  static Future<({String path, int found})> apply(String path, FaceFilter filter) async {
    if (!available || filter == FaceFilter.none) return (path: path, found: 0);
    try {
      final r = Map<String, dynamic>.from(await _channel.invokeMethod('detect', {'path': path}) as Map);
      final faces = [for (final f in (r['faces'] as List)) FaceBox.fromMap(f as Map)];
      final upright = r['path'] as String;
      if (faces.isEmpty) return (path: upright, found: 0);
      final bytes = await File(upright).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final img = (await codec.getNextFrame()).image;
      final rec = ui.PictureRecorder();
      final canvas = ui.Canvas(rec);
      canvas.drawImage(img, Offset.zero, ui.Paint());
      for (final f in faces) {
        drawOn(canvas, f, filter);
      }
      final out = await rec.endRecording().toImage(img.width, img.height);
      final png = await out.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/filtre_${DateTime.now().microsecondsSinceEpoch}.png');
      await file.writeAsBytes(png!.buffer.asUint8List(), flush: true);
      return (path: file.path, found: faces.length);
    } catch (_) {
      return (path: path, found: 0);
    }
  }

  /// Dessine le filtre sur un visage (séparé pour pouvoir être testé sans téléphone).
  static void drawOn(ui.Canvas canvas, FaceBox f, FaceFilter filter) {
    final face = f.rect;
    switch (filter) {
      case FaceFilter.none:
        return;
      case FaceFilter.glasses:
        final a = f.leftEye, b = f.rightEye;
        final center = (a != null && b != null) ? Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2) : Offset(face.center.dx, face.top + face.height * 0.4);
        final span = (a != null && b != null) ? (a - b).distance : face.width * 0.5;
        _emoji(canvas, '😎', center, math.max(span * 2.3, face.width * 0.7));
      case FaceFilter.crown:
        _emoji(canvas, '👑', Offset(face.center.dx, face.top - face.height * 0.02), face.width * 0.8);
      case FaceFilter.nose:
        final n = f.nose ?? Offset(face.center.dx, face.top + face.height * 0.62);
        _emoji(canvas, '🔴', n, face.width * 0.26);
      case FaceFilter.hearts:
        _emoji(canvas, '💖', Offset(face.left, face.top + face.height * 0.1), face.width * 0.35);
        _emoji(canvas, '💖', Offset(face.right, face.top + face.height * 0.1), face.width * 0.35);
    }
  }

  static void _emoji(ui.Canvas canvas, String e, Offset center, double size) {
    final p = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center))
      ..pushStyle(ui.TextStyle(fontSize: size));
    p.addText(e);
    final para = p.build()..layout(ui.ParagraphConstraints(width: size * 1.6));
    canvas.drawParagraph(para, Offset(center.dx - para.width / 2, center.dy - para.height / 2));
  }
}
