import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;
import 'package:video_compress/video_compress.dart';

/// Réduit le poids des médias avant l'envoi : ce que l'on stocke est ce que chaque spectateur télécharge ensuite,
/// donc chaque Mo gagné ici est gagné sur la facture de bande passante, à chaque lecture.
/// Aucune de ces fonctions ne bloque une publication : en cas d'échec ou de gain nul, l'original est renvoyé.
class MediaShrink {
  MediaShrink._();

  /// Les vidéos de moins de 5 Mo ne valent pas la peine d'être recompressées.
  static const videoMinBytes = 5 * 1024 * 1024;

  /// Image → JPEG de 1280 px au plus sur le grand côté, qualité 78. Renvoie l'original si le résultat n'est pas plus léger.
  static Future<Uint8List> imageBytes(Uint8List bytes, {int maxSide = 1280, int quality = 78}) async {
    try {
      final out = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: maxSide,
        minHeight: maxSide,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      return out.length < bytes.length ? out : bytes;
    } catch (e) {
      debugPrint('MediaShrink.imageBytes: $e');
      return bytes;
    }
  }

  /// Vidéo → 720p maximum (mobile uniquement). Renvoie le fichier d'origine pour les petites vidéos, sur le web, en cas d'échec,
  /// ou si le résultat n'est pas au moins 15 % plus léger.
  static Future<File> video(File src) async {
    if (kIsWeb) return src;
    try {
      final size = await src.length();
      if (size < videoMinBytes) return src;
      final info = await VideoCompress.compressVideo(
        src.path,
        quality: VideoQuality.Res1280x720Quality,
        frameRate: 30,
        includeAudio: true,
        deleteOrigin: false,
      );
      final out = info?.file;
      if (out == null) return src;
      final outSize = await out.length();
      return outSize < size * 0.85 ? out : src;
    } catch (e) {
      debugPrint('MediaShrink.video: $e');
      return src;
    }
  }

  static const _imageExt = {'.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif'};
  static const _videoExt = {'.mp4', '.mov', '.m4v', '.avi', '.mkv', '.3gp'};

  /// Les petites images (vignettes, avatars légers) ne sont pas retouchées.
  static const imageMinBytes = 300 * 1024;

  /// Fichier à envoyer : image redimensionnée (1600 px, même format, transparence conservée), vidéo en 720p, tout autre fichier
  /// (audio, PDF, GIF…) inchangé. À utiliser partout où l'on envoie un média vers Firebase Storage.
  static Future<File> file(File f) async {
    if (kIsWeb) return f;
    try {
      final ext = p.extension(f.path).toLowerCase();
      if (_videoExt.contains(ext)) return await video(f);
      if (!_imageExt.contains(ext)) return f;
      final size = await f.length();
      if (size < imageMinBytes) return f;
      final format = switch (ext) {
        '.png' => CompressFormat.png,
        '.webp' => CompressFormat.webp,
        _ => CompressFormat.jpeg,
      };
      final outExt = format == CompressFormat.jpeg ? '.jpg' : ext;
      final target = p.join(Directory.systemTemp.path, 'shrunk_${DateTime.now().microsecondsSinceEpoch}$outExt');
      final out = await FlutterImageCompress.compressAndGetFile(f.path, target, minWidth: 1600, minHeight: 1600, quality: 80, format: format);
      if (out == null) return f;
      final outFile = File(out.path);
      return await outFile.length() < size ? outFile : f;
    } catch (e) {
      debugPrint('MediaShrink.file: $e');
      return f;
    }
  }

  /// Octets à envoyer : une image (JPEG, PNG ou WebP, reconnue à son en-tête) est redimensionnée dans son format ; le reste
  /// (vidéo, audio…) est renvoyé tel quel.
  static Future<Uint8List> bytes(Uint8List b) async {
    if (b.length < imageMinBytes || b.length < 12) return b;
    try {
      final CompressFormat? format;
      if (b[0] == 0xFF && b[1] == 0xD8) {
        format = CompressFormat.jpeg;
      } else if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
        format = CompressFormat.png;
      } else if (b[0] == 0x52 && b[1] == 0x49 && b[8] == 0x57 && b[9] == 0x45) {
        format = CompressFormat.webp;
      } else {
        format = null;
      }
      if (format == null) return b;
      final out = await FlutterImageCompress.compressWithList(b, minWidth: 1600, minHeight: 1600, quality: 80, format: format);
      return out.length < b.length ? out : b;
    } catch (e) {
      debugPrint('MediaShrink.bytes: $e');
      return b;
    }
  }
}
