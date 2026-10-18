import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../utils/fnv.dart';
import '../utils/media_cdn.dart';

/// Aperçu (image) d'une vidéo.
///
/// - À la création : [fromFile] tire l'image de la vidéo qui est encore sur le téléphone de l'auteur (instantané), pour qu'on l'envoie
///   avec la vidéo et que tout le monde l'affiche tout de suite sans rien télécharger de la vidéo.
/// - Pour les vidéos qui n'ont pas d'aperçu enregistré : [fromUrl] le tire une fois de l'adresse de la vidéo (file d'attente de 2 à la fois,
///   cache mémoire puis disque), ce qui évite de saturer le réseau quand le fil affiche plusieurs vidéos d'un coup.
class VideoPoster {
  VideoPoster._();

  static const int maxWidth = 480;
  static const int quality = 70;
  static const int _maxMemory = 80;
  static const int _parallel = 2;

  static final LinkedHashMap<String, Uint8List> _memory = LinkedHashMap();
  static final Map<String, Future<Uint8List?>> _inflight = {};
  static final Queue<Completer<void>> _waiting = Queue();
  static int _running = 0;
  static Directory? _dir;

  /// Aperçu d'une vidéo locale, enregistré dans un fichier JPEG temporaire (null si impossible : web, vidéo illisible…).
  static Future<File?> fromFile(File video) async {
    if (kIsWeb) return null;
    try {
      final path = await VideoThumbnail.thumbnailFile(
        video: video.path,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: maxWidth,
        quality: quality,
        timeMs: 500,
      );
      if (path == null) return null;
      final f = File(path);
      return await f.exists() ? f : null;
    } catch (_) {
      return null;
    }
  }

  /// Déjà en mémoire (affichage sans attente), sinon null.
  static Uint8List? peek(String key) {
    final b = _memory.remove(key);
    if (b != null) _memory[key] = b;
    return b;
  }

  /// Aperçu d'une vidéo distante : mémoire, puis disque, puis une seule génération à la fois (2 en parallèle au plus).
  static Future<Uint8List?> fromUrl(String key, String videoUrl) {
    if (kIsWeb || videoUrl.isEmpty) return Future.value(null);
    final hit = peek(key);
    if (hit != null) return Future.value(hit);
    return _inflight[key] ??= _load(key, videoUrl).whenComplete(() => _inflight.remove(key));
  }

  static Future<Uint8List?> _load(String key, String videoUrl) async {
    File? cached;
    try {
      cached = File('${(await _cacheDir()).path}/${fnv63(key)}.jpg');
      if (await cached.exists()) {
        final b = await cached.readAsBytes();
        if (b.isNotEmpty) {
          _remember(key, b);
          return b;
        }
      }
    } catch (_) {}

    await _acquire();
    try {
      final b = await VideoThumbnail.thumbnailData(
        video: MediaCdn.url(videoUrl),
        imageFormat: ImageFormat.JPEG,
        maxWidth: maxWidth,
        quality: quality,
        timeMs: 500,
      );
      if (b == null || b.isEmpty) return null;
      _remember(key, b);
      try {
        await cached?.writeAsBytes(b, flush: true);
      } catch (_) {}
      return b;
    } catch (_) {
      return null;
    } finally {
      _release();
    }
  }

  static void _remember(String key, Uint8List b) {
    _memory.remove(key);
    _memory[key] = b;
    while (_memory.length > _maxMemory) {
      _memory.remove(_memory.keys.first);
    }
  }

  static Future<Directory> _cacheDir() async {
    final d = _dir ??= Directory('${(await getTemporaryDirectory()).path}/video_posters');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  static Future<void> _acquire() async {
    if (_running < _parallel) {
      _running++;
      return;
    }
    final c = Completer<void>();
    _waiting.add(c);
    await c.future;
  }

  static void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
    } else {
      _running--;
    }
  }
}
