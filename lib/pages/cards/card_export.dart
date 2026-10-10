import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'card_models.dart';

/// Sorties d'une carte : image PNG (1080 px de large), enregistrement dans la galerie, partage.
class CardExport {
  CardExport._();

  /// Largeur de l'image exportée.
  static const exportWidth = 1080.0;

  /// Attend que les images de la carte (avatar et médias retenus) soient chargées, pour qu'elles apparaissent dans le PNG.
  static Future<void> precache(BuildContext context, CardSource source, CardSpec spec) async {
    final imgs = <ImageProvider>[
      if (source.avatar != null) source.avatar!,
      for (final i in (spec.imageOrder.isEmpty ? List<int>.generate(source.images.length.clamp(0, 3), (i) => i) : spec.imageOrder))
        if (i >= 0 && i < source.images.length) source.images[i],
    ];
    await Future.wait(imgs.map((p) => precacheImage(p, context).catchError((_) {})));
  }

  /// Capture la carte dessinée sous [boundaryKey] (un [RepaintBoundary]) en PNG.
  static Future<Uint8List> toPng(GlobalKey boundaryKey, {CardFormat format = CardFormat.portrait}) async {
    final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) throw StateError('Carte introuvable');
    // laisse une image au moteur pour finir de peindre
    if (boundary.debugNeedsPaint) await Future<void>.delayed(const Duration(milliseconds: 40));
    final ratio = exportWidth / format.size.width;
    final ui.Image image = await boundary.toImage(pixelRatio: ratio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) throw StateError('Export impossible');
    return data.buffer.asUint8List();
  }

  static Future<File> toTempFile(Uint8List png, {String prefix = 'carte_afrolook'}) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/${prefix}_${DateTime.now().millisecondsSinceEpoch}.png');
    return f.writeAsBytes(png, flush: true);
  }

  /// Enregistre dans la galerie du téléphone. Retourne false si l'autorisation est refusée.
  static Future<bool> saveToGallery(Uint8List png) async {
    try {
      if (!await Gal.hasAccess()) {
        if (!await Gal.requestAccess()) return false;
      }
      await Gal.putImageBytes(png, name: 'afrolook_carte_${DateTime.now().millisecondsSinceEpoch}');
      return true;
    } on GalException {
      return false;
    }
  }

  /// Ouvre la feuille de partage du téléphone avec l'image.
  static Future<void> share(Uint8List png, {String? text}) async {
    final file = await toTempFile(png);
    await Share.shareXFiles([XFile(file.path, mimeType: 'image/png')], text: text);
  }
}
