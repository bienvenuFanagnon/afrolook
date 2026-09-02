import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

// ─── Cache vidéo : 300 fichiers max, expiration 7 jours ───────────────────────
class _VideoCacheManager extends CacheManager {
  static const _key = 'afrolook_video_cache';
  static final _VideoCacheManager _instance = _VideoCacheManager._();
  factory _VideoCacheManager() => _instance;
  _VideoCacheManager._()
      : super(Config(_key,
            stalePeriod: const Duration(days: 7),
            maxNrOfCacheObjects: 30));
}

// ─── Cache audio : 500 fichiers max, expiration 14 jours ─────────────────────
class _AudioCacheManager extends CacheManager {
  static const _key = 'afrolook_audio_cache';
  static final _AudioCacheManager _instance = _AudioCacheManager._();
  factory _AudioCacheManager() => _instance;
  _AudioCacheManager._()
      : super(Config(_key,
            stalePeriod: const Duration(days: 14),
            maxNrOfCacheObjects: 500));
}

/// Service singleton pour le cache disque des médias (vidéo + audio).
///
/// Stratégie vidéo :
///   - Si le fichier est déjà en cache → [VideoPlayerController.file] (instantané)
///   - Sinon → [VideoPlayerController.networkUrl] + téléchargement silencieux en arrière-plan
///     pour que la prochaine lecture soit instantanée.
class MediaCacheService {
  MediaCacheService._();

  static final _videoMgr = _VideoCacheManager();
  static final _audioMgr = _AudioCacheManager();

  // ── Vidéo ──────────────────────────────────────────────────────────────────

  /// Retourne un [VideoPlayerController] prêt à être initialisé.
  /// Appeler [initialize()] ensuite comme d'habitude.
  static Future<VideoPlayerController> videoController(String url) async {
    if (url.isEmpty) {
      return VideoPlayerController.networkUrl(Uri.parse(''));
    }
    try {
      // Vérification non-bloquante : fichier déjà en cache ?
      final cached = await _videoMgr.getFileFromCache(url);
      if (cached != null) {
        return VideoPlayerController.file(cached.file);
      }
    } catch (_) {}

    // Pas en cache → réseau immédiat + mise en cache silencieuse en arrière-plan
    _videoMgr.downloadFile(url).catchError((_) {});
    return VideoPlayerController.networkUrl(Uri.parse(url));
  }

  /// Pré-charge un fichier vidéo en cache sans bloquer (fire-and-forget).
  static void prefetchVideo(String url) {
    if (url.isEmpty) return;
    _videoMgr.downloadFile(url).catchError((_) {});
  }

  // ── Audio ──────────────────────────────────────────────────────────────────

  /// Retourne le fichier audio local s'il est en cache, sinon null.
  /// Le téléchargement en arrière-plan est lancé automatiquement si absent.
  static Future<File?> getAudioFile(String url) async {
    if (url.isEmpty) return null;
    try {
      final cached = await _audioMgr.getFileFromCache(url);
      if (cached != null) return cached.file;
    } catch (_) {}
    // Télécharge en arrière-plan pour la prochaine fois
    _audioMgr.downloadFile(url).catchError((_) {});
    return null;
  }

  /// Télécharge et retourne le fichier audio local (attend la fin du téléchargement).
  /// À utiliser quand on veut absolument jouer depuis le disque.
  static Future<File?> fetchAudioFile(String url) async {
    if (url.isEmpty) return null;
    try {
      return await _audioMgr.getSingleFile(url);
    } catch (_) {
      return null;
    }
  }

  // ── Utilitaires ────────────────────────────────────────────────────────────

  /// Vide le cache vidéo (à appeler si l'espace disque est critique).
  static Future<void> clearVideoCache() => _videoMgr.emptyCache();

  /// Vide le cache audio.
  static Future<void> clearAudioCache() => _audioMgr.emptyCache();
}
