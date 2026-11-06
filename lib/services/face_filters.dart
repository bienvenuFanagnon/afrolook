import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
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

  /// Même visage vu dans un miroir (aperçu de la caméra avant) pour une image de largeur [w].
  FaceBox mirrored(double w) => FaceBox(
        rect: Rect.fromLTWH(w - rect.right, rect.top, rect.width, rect.height),
        leftEye: leftEye == null ? null : Offset(w - leftEye!.dx, leftEye!.dy),
        rightEye: rightEye == null ? null : Offset(w - rightEye!.dx, rightEye!.dy),
        nose: nose == null ? null : Offset(w - nose!.dx, nose!.dy),
      );

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

  /// Dernière erreur de détection (texte du téléphone), pour dire à la personne pourquoi le filtre ne s'affiche pas.
  static String? lastError;

  /// Fait télécharger le module de visage de Google Play si besoin (première utilisation) ; rend faux si impossible (pas de connexion, Play indisponible).
  static Future<bool> ensureReady() async {
    if (!available) return false;
    try {
      await _channel.invokeMethod('ensureModule').timeout(const Duration(seconds: 60));
      lastError = null;
      return true;
    } catch (e) {
      lastError = e is PlatformException ? (e.message ?? e.code) : e.toString();
      return false;
    }
  }

  static String emoji(FaceFilter f) => switch (f) {
        FaceFilter.none => '',
        FaceFilter.glasses => '😎',
        FaceFilter.crown => '👑',
        FaceFilter.nose => '🤡',
        FaceFilter.hearts => '😍',
      };

  /// Cherche les visages de la photo [path]. Rend la photo redressée (à utiliser ensuite à la place de [path]), sa taille et les visages ; null si la détection échoue
  /// (la photo n'est alors jamais perdue : l'appelant garde l'original).
  static Future<({String path, Size size, List<FaceBox> faces})?> detect(String path) async {
    if (!available) return null;
    try {
      final r = Map<String, dynamic>.from(await _channel.invokeMethod('detect', {'path': path}) as Map);
      return (
        path: r['path'] as String,
        size: Size((r['width'] as num).toDouble(), (r['height'] as num).toDouble()),
        faces: [for (final f in (r['faces'] as List)) FaceBox.fromMap(f as Map)],
      );
    } catch (_) {
      return null;
    }
  }

  /// Pose [filter] sur chaque visage de la photo déjà redressée [upright] et rend le nouveau fichier ; [path] tel quel si rien à faire ou en cas d'échec.
  static Future<({String path, int found})> apply(String upright, List<FaceBox> faces, FaceFilter filter) async {
    if (filter == FaceFilter.none || faces.isEmpty) return (path: upright, found: 0);
    try {
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
      return (path: upright, found: 0);
    }
  }

  /// Où poser le filtre sur un visage : centre et taille (en pixels de l'image). Un seul emoji par filtre, pour que photo, aperçu en direct et vidéo donnent le même résultat.
  static ({Offset center, double size})? anchor(FaceBox f, FaceFilter filter) {
    final face = f.rect;
    switch (filter) {
      case FaceFilter.none:
        return null;
      case FaceFilter.glasses:
        final a = f.leftEye, b = f.rightEye;
        final center = (a != null && b != null) ? Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2) : Offset(face.center.dx, face.top + face.height * 0.4);
        final span = (a != null && b != null) ? (a - b).distance : face.width * 0.5;
        return (center: center, size: math.max(span * 2.3, face.width * 0.7));
      case FaceFilter.crown:
        return (center: Offset(face.center.dx, face.top - face.height * 0.02), size: face.width * 0.8);
      case FaceFilter.nose:
        return (center: f.nose ?? Offset(face.center.dx, face.top + face.height * 0.62), size: face.width * 0.26);
      case FaceFilter.hearts:
        return (center: Offset(face.right, face.top), size: face.width * 0.4);
    }
  }

  /// Dessine le filtre sur un visage (séparé pour pouvoir être testé sans téléphone).
  static void drawOn(ui.Canvas canvas, FaceBox f, FaceFilter filter) {
    final a = anchor(f, filter);
    if (a != null) _emoji(canvas, filter == FaceFilter.hearts ? '💖' : _glyph(filter), a.center, a.size);
  }

  static String _glyph(FaceFilter f) => switch (f) {
        FaceFilter.glasses => '😎',
        FaceFilter.crown => '👑',
        FaceFilter.nose => '🔴',
        _ => '💖',
      };

  /// Image du filtre (PNG carré transparent) à la taille en pixels voulue : le serveur la pose sur la vidéo.
  static Future<List<int>> filterPng(FaceFilter filter, int sizePx) async {
    final px = sizePx.clamp(24, 900);
    final rec = ui.PictureRecorder();
    final canvas = ui.Canvas(rec);
    _emoji(canvas, _glyph(filter), Offset(px / 2, px / 2), px * 0.85);
    final img = await rec.endRecording().toImage(px, px);
    return (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  }

  /// Visages d'une image de la caméra (aperçu en direct) : positions dans l'image redressée et sa taille, sans miroir. null si la détection échoue.
  static Future<({Size size, List<FaceBox> faces})?> detectFrame(CameraImage img, int rotation) async {
    if (!available) return null;
    try {
      final bytes = img.planes.length == 1 ? img.planes.first.bytes : _nv21(img);
      final r = Map<String, dynamic>.from(await _channel.invokeMethod('detectFrame', {'bytes': bytes, 'width': img.width, 'height': img.height, 'rotation': rotation}) as Map);
      return (size: Size((r['width'] as num).toDouble(), (r['height'] as num).toDouble()), faces: [for (final f in (r['faces'] as List)) FaceBox.fromMap(f as Map)]);
    } catch (e) {
      lastError = e is PlatformException ? (e.message ?? e.code) : e.toString();
      return null;
    }
  }

  /// Image à trois plans (Y, U, V) → NV21 (Y puis V/U entrelacés), si la caméra ne rend pas déjà du NV21.
  static Uint8List _nv21(CameraImage img) {
    final w = img.width, h = img.height;
    final out = Uint8List(w * h * 3 ~/ 2);
    final y = img.planes[0], u = img.planes[1], v = img.planes[2];
    var o = 0;
    for (var r = 0; r < h; r++) {
      out.setRange(o, o + w, y.bytes, r * y.bytesPerRow);
      o += w;
    }
    final pix = u.bytesPerPixel ?? 1;
    for (var r = 0; r < h ~/ 2; r++) {
      for (var c = 0; c < w ~/ 2; c++) {
        out[o++] = v.bytes[r * v.bytesPerRow + c * pix];
        out[o++] = u.bytes[r * u.bytesPerRow + c * pix];
      }
    }
    return out;
  }

  static void _emoji(ui.Canvas canvas, String e, Offset center, double size) {
    final p = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center))
      ..pushStyle(ui.TextStyle(fontSize: size));
    p.addText(e);
    final para = p.build()..layout(ui.ParagraphConstraints(width: size * 1.6));
    canvas.drawParagraph(para, Offset(center.dx - para.width / 2, center.dy - para.height / 2));
  }
}
