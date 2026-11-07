import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'api/studio_watermark_api.dart';

/// Signature visible « Afrolook » : une pastille (logo + @pseudo) posée sur tout ce qui est créé dans le Studio, filmé ou choisi.
/// Les vidéos reçoivent la pastille MOBILE (elle change de coin, comme sur TikTok : le serveur l'incruste) ; les images, une pastille fixe en bas à droite.
/// Ainsi, une vidéo ou une image téléchargée depuis Afrolook porte toujours le nom de son créateur et ne peut pas être republiée comme la sienne.
class Watermark {
  Watermark._();

  static const _logo = 'assets/logo/afrolook_logo.png';

  /// Pastille transparente (PNG) : logo dans un rond blanc, « Afrolook » et le @pseudo de l'auteur sur fond sombre.
  static Future<Uint8List> pillPng(String pseudo, {int width = 420}) async {
    final k = width / 420.0;
    final h = 104 * k;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, width.toDouble(), h), Radius.circular(h / 2)), Paint()..color = const Color(0xC8000000));
    // logo dans un rond blanc
    final d = 80 * k;
    final off = Offset(12 * k, (h - d) / 2);
    c.drawCircle(off + Offset(d / 2, d / 2), d / 2, Paint()..color = Colors.white);
    try {
      final data = await rootBundle.load(_logo);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: (d * 0.78).round());
      final frame = (await codec.getNextFrame()).image;
      c.drawImage(frame, off + Offset((d - frame.width) / 2, (d - frame.height) / 2), Paint());
      frame.dispose();
    } catch (_) {}
    final textLeft = off.dx + d + 14 * k;
    final maxW = width - textLeft - 18 * k;
    TextPainter tp(String t, double size, FontWeight w, Color color) =>
        TextPainter(text: TextSpan(text: t, style: TextStyle(color: color, fontSize: size * k, fontWeight: w, height: 1.1)), textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '…')..layout(maxWidth: maxW);
    final brand = tp('Afrolook', 24, FontWeight.w900, const Color(0xFFFFD21F));
    final p = pseudo.trim().isEmpty ? null : tp('@${pseudo.trim()}', 30, FontWeight.w800, Colors.white);
    final total = brand.height + (p?.height ?? 0) + (p == null ? 0 : 3 * k);
    var y = (h - total) / 2;
    brand.paint(c, Offset(textLeft, y));
    y += brand.height + 3 * k;
    p?.paint(c, Offset(textLeft, y));
    final image = await rec.endRecording().toImage(width, h.round());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  static Uint8List _toJpg(Uint8List png) {
    final d = img.decodeImage(png);
    return d == null ? png : Uint8List.fromList(img.encodeJpg(d, quality: 90));
  }

  /// Image signée : la pastille fixe en bas à droite (30 % de la largeur). Rend les octets JPEG ; en cas d'échec, l'image d'origine (jamais de blocage).
  static Future<Uint8List> signImageBytes(Uint8List bytes, String pseudo) async {
    if (kIsWeb) return bytes;
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: null);
      final src = (await codec.getNextFrame()).image;
      var w = src.width.toDouble();
      var h = src.height.toDouble();
      const maxSide = 2048.0;
      final s = (w > h ? w : h) > maxSide ? maxSide / (w > h ? w : h) : 1.0;
      w *= s;
      h *= s;
      final pillW = (w * 0.30).clamp(160.0, 900.0).round();
      final pill = await ui.instantiateImageCodec(await pillPng(pseudo, width: pillW));
      final pf = (await pill.getNextFrame()).image;
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawImageRect(src, Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()), Rect.fromLTWH(0, 0, w, h), Paint()..filterQuality = FilterQuality.high);
      final m = w * 0.04;
      c.drawImage(pf, Offset(w - pf.width - m, h - pf.height - m), Paint());
      final out = await rec.endRecording().toImage(w.round(), h.round());
      final png = (await out.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      src.dispose();
      pf.dispose();
      out.dispose();
      return await compute(_toJpg, png);
    } catch (_) {
      return bytes;
    }
  }

  static Future<File> signImage(File file, String pseudo) async {
    final signed = await signImageBytes(await file.readAsBytes(), pseudo);
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/signe_${DateTime.now().microsecondsSinceEpoch}.jpg').writeAsBytes(signed, flush: true);
  }

  /// Vidéo signée par le serveur (pastille mobile). En cas d'échec, la vidéo d'origine est rendue (jamais de blocage).
  static Future<File> signVideo(File file, String pseudo, {void Function(double)? onProgress}) async {
    if (kIsWeb) return file;
    try {
      return await StudioWatermarkApi.sign(file, await pillPng(pseudo), onProgress: onProgress);
    } catch (e) {
      debugPrint('Signature de la vidéo impossible : $e');
      return file;
    }
  }
}
