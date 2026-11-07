import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// Empreinte visuelle d'une image ou d'une vidéo, calculée sur le téléphone (rien du contenu ne part : seulement 1 à 3 nombres de 64 bits).
/// Le serveur s'en sert pour refuser qu'un contenu déjà publié sur Afrolook le soit à nouveau par un autre compte.
///
/// dHash : l'image est réduite à 9 x 8 points gris ; chaque point est comparé à celui de droite (plus clair ou non) : 64 bits. Deux images qui se ressemblent
/// (même recompressées, réduites ou légèrement recadrées) ont des empreintes presque identiques.
class MediaFingerprint {
  MediaFingerprint._();

  /// Hachage de 64 bits en hexadécimal (16 caractères) d'une image (octets JPEG, PNG…), ou null si elle ne se lit pas.
  static Future<String?> hashBytes(Uint8List bytes) => compute(_dhash, bytes);

  /// Empreinte d'une image : un hachage.
  static Future<List<String>> ofImageBytes(Uint8List bytes) async {
    final h = await hashBytes(bytes);
    return h == null ? const [] : [h];
  }

  /// Empreinte d'une vidéo : trois hachages (à 20 %, 50 % et 80 % de la durée). Liste vide si la vidéo ne se lit pas (aucun contrôle dans ce cas).
  static Future<List<String>> ofVideo(File file) async {
    if (kIsWeb) return const [];
    try {
      final vc = VideoPlayerController.file(file);
      var ms = 0;
      try {
        await vc.initialize().timeout(const Duration(seconds: 8));
        ms = vc.value.duration.inMilliseconds;
      } finally {
        await vc.dispose();
      }
      if (ms <= 0) return const [];
      final out = <String>[];
      for (final p in const [0.2, 0.5, 0.8]) {
        final data = await VideoThumbnail.thumbnailData(video: file.path, imageFormat: ImageFormat.JPEG, timeMs: (ms * p).round(), maxWidth: 160, quality: 60);
        final h = data == null ? null : await hashBytes(data);
        if (h != null) out.add(h);
      }
      return out.length == 3 ? out : const [];   // trois images ou rien : une comparaison partielle serait trop fragile
    } catch (_) {
      return const [];
    }
  }
}

/// dHash 64 bits : voir [MediaFingerprint]. Fonction de premier niveau pour tourner dans un autre fil.
String? _dhash(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final small = img.grayscale(img.copyResize(decoded, width: 9, height: 8, interpolation: img.Interpolation.average));
  var high = 0;
  var low = 0;
  var bit = 0;
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      final left = small.getPixel(x, y).luminance;
      final right = small.getPixel(x + 1, y).luminance;
      final v = left > right ? 1 : 0;
      if (bit < 32) {
        high = (high << 1) | v;
      } else {
        low = (low << 1) | v;
      }
      bit++;
    }
  }
  String hex(int n) => (n & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
  return hex(high) + hex(low);
}

/// Empreinte calculée au moment de préparer la publication, consommée une seule fois par la création du post (même principe que [PostSourceLink]).
class PostFingerprintLink {
  PostFingerprintLink._();

  static List<String>? _hashes;

  static void set(List<String> hashes) => _hashes = hashes.isEmpty ? null : hashes;

  /// Lue et effacée par [PostsApi.create].
  static List<String>? take() {
    final h = _hashes;
    _hashes = null;
    return h;
  }

  static void clear() => _hashes = null;
}
