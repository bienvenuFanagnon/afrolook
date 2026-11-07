import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'api/studio_watermark_api.dart';

/// Signature visible « Afrolook » posée sur ce qui est téléchargé depuis l'application (jamais dans la vidéo qu'on regarde).
/// Version sobre (maquette validée le 07/11) : pas de fond coloré, la silhouette blanche du logo (le A et ses bulles, comme le fantôme de Snapchat),
/// « Afrolook », puis le nom du canal précédé de # si la publication vient d'un canal, sinon le pseudo précédé de @. Les vidéos reçoivent cette pastille en MOBILE
/// (le serveur l'incruste, la fait changer de place trois fois et fait battre le logo) ; les images, une fine bande sombre en bas avec un petit QR vers la publication.
class Watermark {
  Watermark._();

  static const _logo = 'assets/logo/afrolook_logo.png';

  // Mesures de la pastille, en pixels du dessin (le serveur la réduit à la taille de la vidéo : 720 px de large = ces valeurs telles quelles).
  // Doivent rester identiques à `Watermark::LOGO_UNITS` / `LOGO_CENTER_Y` du serveur (app/Studio/Watermark.php).
  static const double _pad = 18;
  static const double logoUnits = 140;
  static const double _brandSize = 52;
  static const double _nameSize = 42;
  static const double _maxNameWidth = 360;

  /// « @pseudo » (vide si la personne n'a pas de pseudo).
  static String userLabel(String? pseudo) {
    final p = (pseudo ?? '').trim().replaceFirst(RegExp(r'^@+'), '');
    return p.isEmpty ? '' : '@$p';
  }

  /// « #canal » (vide si le canal n'a pas de nom).
  static String channelLabel(String? name) {
    final n = (name ?? '').trim().replaceFirst(RegExp(r'^#+'), '');
    return n.isEmpty ? '' : '#$n';
  }

  /// Silhouette blanche du logo : on garde seulement le dessin sombre (le A et les bulles), en blanc, sur fond transparent. Carré de [size] pixels.
  static Future<ui.Image?> silhouette(int size) async {
    try {
      final data = await rootBundle.load(_logo);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: size, targetHeight: size);
      final src = (await codec.getNextFrame()).image;
      final bytes = (await src.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final px = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
      final out = Uint8List(px.length);
      for (var i = 0; i < px.length; i += 4) {
        final lum = (px[i] + px[i + 1] + px[i + 2]) / 3;
        final dark = px[i + 3] > 100 && lum < 70;
        out[i] = 255;
        out[i + 1] = 255;
        out[i + 2] = 255;
        out[i + 3] = dark ? 255 : 0;
      }
      src.dispose();
      final done = Completer<ui.Image>();
      ui.decodeImageFromPixels(out, size, size, ui.PixelFormat.rgba8888, done.complete);
      return await done.future;
    } catch (_) {
      return null;
    }
  }

  /// Silhouette du logo en PNG (carré [logoUnits] px) : le serveur la fait battre doucement au centre de la pastille.
  static Future<Uint8List> logoPng() async {
    final sil = await silhouette(logoUnits.round());
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    if (sil != null) c.drawImage(sil, Offset.zero, Paint());
    final image = await rec.endRecording().toImage(logoUnits.round(), logoUnits.round());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    sil?.dispose();
    return data!.buffer.asUint8List();
  }

  static TextPainter _tp(String t, double size, FontWeight w, Color color, {double maxWidth = double.infinity, double shadow = 0}) => TextPainter(
        text: TextSpan(text: t, style: TextStyle(color: color, fontSize: size, fontWeight: w, height: 1.0, shadows: shadow > 0 ? [Shadow(color: const Color(0x8C000000), blurRadius: shadow, offset: const Offset(0, 1))] : null)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: maxWidth);

  /// Pastille SANS fond (PNG transparent), ajustée à son contenu : un espace réservé en haut pour le logo (posé et animé par le serveur), « Afrolook », puis [label]
  /// (« #canal » ou « @pseudo »). Un nom trop long est coupé avec « … » à une largeur maximale, la même pour tous.
  static Future<Uint8List> pillPng(String label) async {
    final brand = _tp('Afrolook', _brandSize, FontWeight.w900, const Color(0xF2FFFFFF), shadow: 6);
    final name = label.trim().isEmpty ? null : _tp(label.trim(), _nameSize, FontWeight.w700, const Color(0xCCFFFFFF), maxWidth: _maxNameWidth, shadow: 6);
    final w = math.max(brand.width, math.max(name?.width ?? 0, logoUnits)) + _pad * 2;
    final h = _pad + logoUnits + 10 + brand.height + (name == null ? 0 : 8 + name.height) + _pad;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    var y = _pad + logoUnits + 10;
    brand.paint(c, Offset((w - brand.width) / 2, y));
    y += brand.height + 8;
    name?.paint(c, Offset((w - name.width) / 2, y));
    final image = await rec.endRecording().toImage(w.ceil(), h.ceil());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  /// Petite tuile claire avec le QR de [data] (adresse de la publication), PNG carré. Fond blanc presque opaque et modules sombres : lisible sur toute vidéo.
  static Future<Uint8List> qrPng(String data, {int size = 240}) async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    final s = size.toDouble();
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, s, s), Radius.circular(s * .1)), Paint()..color = const Color(0xE6FFFFFF));
    final pad = s * .09;
    final painter = QrPainter(
      data: data,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.M,
      gapless: true,
      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF111111)),
      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF111111)),
    );
    c.save();
    c.translate(pad, pad);
    painter.paint(c, Size(s - pad * 2, s - pad * 2));
    c.restore();
    final image = await rec.endRecording().toImage(size, size);
    final out = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return out!.buffer.asUint8List();
  }

  static Uint8List _toJpg(Uint8List png) {
    final d = img.decodeImage(png);
    return d == null ? png : Uint8List.fromList(img.encodeJpg(d, quality: 90));
  }

  /// Image signée : une FINE bande sombre en bas (silhouette du logo, « Créé sur Afrolook · » et [label] : « #canal » ou « @pseudo »), sur toute la largeur, et, si [qrData] est donné,
  /// une petite tuile QR (vers la publication) dans le coin bas droit, juste au-dessus de la bande. Rend les octets JPEG.
  /// [strict] : en cas d'échec, lève une erreur au lieu de rendre l'image sans signature (téléchargements : tout ce qui sort d'Afrolook est signé).
  static Future<Uint8List> signImageBytes(Uint8List bytes, String label, {bool strict = false, String? qrData}) async {
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
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      c.drawImageRect(src, Rect.fromLTWH(0, 0, src.width.toDouble(), src.height.toDouble()), Rect.fromLTWH(0, 0, w, h), Paint()..filterQuality = FilterQuality.high);
      // bande fine : 5,5 % de la largeur (entre 30 et 96 px), fond sombre translucide, contenu centré
      final bh = (w * 0.055).clamp(30.0, 96.0);
      final top = h - bh;
      c.drawRect(Rect.fromLTWH(0, top, w, bh), Paint()..color = const Color(0x59000000));
      final fs = bh * 0.42;
      TextPainter tp(String t, FontWeight fw, Color col, double maxW) => TextPainter(text: TextSpan(text: t, style: TextStyle(color: col, fontSize: fs, fontWeight: fw, height: 1.0)), textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '…')..layout(maxWidth: maxW);
      final a1 = tp('Créé sur Afrolook', FontWeight.w700, Colors.white, w * 0.5);
      final p = label.trim().isEmpty ? null : tp('  ·  ${label.trim()}', FontWeight.w600, const Color(0xCCFFFFFF), w * 0.34);
      final logoD = bh * 0.78;
      final total = logoD + bh * 0.22 + a1.width + (p?.width ?? 0);
      var x = (w - total) / 2;
      final cy = top + bh / 2;
      final sil = await silhouette((logoD * 2).round());
      if (sil != null) {
        c.drawImageRect(sil, Rect.fromLTWH(0, 0, sil.width.toDouble(), sil.height.toDouble()), Rect.fromLTWH(x, cy - logoD / 2, logoD, logoD), Paint()..filterQuality = FilterQuality.high);
        sil.dispose();
      }
      x += logoD + bh * 0.22;
      a1.paint(c, Offset(x, cy - a1.height / 2));
      p?.paint(c, Offset(x + a1.width, cy - p.height / 2));
      // QR de la publication : coin bas droit, juste au-dessus de la bande
      if (qrData != null && qrData.isNotEmpty) {
        final qs = bh * 1.5;
        final qrPngBytes = await qrPng(qrData);
        final qc = await ui.instantiateImageCodec(qrPngBytes);
        final qi = (await qc.getNextFrame()).image;
        c.drawImageRect(qi, Rect.fromLTWH(0, 0, qi.width.toDouble(), qi.height.toDouble()), Rect.fromLTWH(w - qs - 6, top - qs - 6, qs, qs), Paint()..filterQuality = FilterQuality.high);
        qi.dispose();
      }
      final out = await rec.endRecording().toImage(w.round(), h.round());
      final png = (await out.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      src.dispose();
      out.dispose();
      return await compute(_toJpg, png);
    } catch (e) {
      if (strict) rethrow;
      return bytes;
    }
  }

  static Future<File> signImage(File file, String label) async {
    final signed = await signImageBytes(await file.readAsBytes(), label);
    final dir = await getTemporaryDirectory();
    return File('${dir.path}/signe_${DateTime.now().microsecondsSinceEpoch}.jpg').writeAsBytes(signed, flush: true);
  }

  /// Vidéo signée par le serveur (pastille mobile). En cas d'échec, la vidéo d'origine est rendue (jamais de blocage).
  static Future<File> signVideo(File file, String label, {void Function(double)? onProgress}) async {
    if (kIsWeb) return file;
    try {
      return await StudioWatermarkApi.sign(file, await pillPng(label), onProgress: onProgress);
    } catch (e) {
      debugPrint('Signature de la vidéo impossible : $e');
      return file;
    }
  }
}
