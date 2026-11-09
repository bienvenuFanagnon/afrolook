import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../pages/studio/montage/montage_export.dart';
import 'api/studio_watermark_api.dart';
import 'watermark.dart';

/// Marque Afrolook sur ce qu'on ENREGISTRE dans sa galerie après un montage ou une carte (09/11/2026), comme pour les téléchargements de publications : tout ce qui sort
/// d'Afrolook est signé. Vidéo : la pastille qui change de coin, le logo animé et la fin Afrolook, posés par le serveur sur la copie (la vidéo publiée, elle, reste sans signature).
/// Image : la bande « Créé sur Afrolook · @pseudo » posée sur le téléphone. En cas d'échec la copie n'est PAS rendue : sans signature, pas de fichier (comme au téléchargement).
class BrandedSave {
  BrandedSave._();

  /// La copie signée de [file] (vidéo ou image) à enregistrer ; null si la signature n'a pas pu être posée. [pseudo] : le @pseudo de la personne.
  static Future<File?> prepare(File file, {required bool video, required String? pseudo, void Function(double)? onProgress}) async {
    if (kIsWeb) return file;
    final label = Watermark.userLabel(pseudo);
    try {
      if (video) {
        final story = await MontageExport.outroLayers(label: label, W: 720, H: 1280);
        final fourFive = await MontageExport.outroLayers(label: label, W: 720, H: 900);
        final wide = await MontageExport.outroLayers(label: label, W: 1280, H: 720);
        return await StudioWatermarkApi.sign(
          file,
          await Watermark.pillPng(label),
          logo: await Watermark.logoPng(),
          outro: {'story_pill': story.$1, 'story_tag': story.$2, 'post_pill': fourFive.$1, 'post_tag': fourFive.$2, 'land_pill': wide.$1, 'land_tag': wide.$2},
          onProgress: onProgress,
        );
      }
      final signed = await Watermark.signImageBytes(await file.readAsBytes(), label, strict: true);
      final dir = await getTemporaryDirectory();
      return await File('${dir.path}/afrolook_signe_${DateTime.now().microsecondsSinceEpoch}.jpg').writeAsBytes(signed, flush: true);
    } catch (e) {
      debugPrint('Signature de la copie enregistrée impossible : $e');
      return null;
    }
  }

  /// Image (octets) signée, pour enregistrer une carte ; null en cas d'échec (rien n'est enregistré sans signature).
  static Future<Uint8List?> imageBytes(Uint8List bytes, {required String? pseudo}) async {
    if (kIsWeb) return bytes;
    try {
      return await Watermark.signImageBytes(bytes, Watermark.userLabel(pseudo), strict: true);
    } catch (e) {
      debugPrint('Signature de la carte impossible : $e');
      return null;
    }
  }
}
