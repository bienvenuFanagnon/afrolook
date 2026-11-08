import 'package:afrotok/services/api/posts_api.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Visionnage ANONYME d'une vidéo (décision du propriétaire, 08/11/2026).
///
/// Quand une vidéo quitte l'écran, le téléphone envoie UNE tranche atteinte à `POST /posts/{id}/watch` : `q` (moins de la moitié), `h` (au moins la moitié),
/// `f` (presque la fin), `l` (revue en boucle). Le serveur ajoute 1 à un compteur de la publication : il ne garde pas qui a regardé, et cette information
/// n'alimente JAMAIS les goûts de la personne. Elle sert seulement à savoir si une vidéo plaît (vagues de diffusion).
///
/// Mesure : temps réellement regardé = somme des avancées de lecture entre deux battements (un saut dans la barre ne compte pas), divisé par la durée.
/// Un seul suivi à la fois ; [start] envoie d'abord ce qui était en cours.
class WatchTracker {
  WatchTracker();

  /// Suivi partagé des pages plein écran (une seule vidéo à la fois). Une carte du fil crée son propre [WatchTracker].
  static final WatchTracker instance = WatchTracker();

  String? _postId;
  VideoPlayerController? _c;
  VoidCallback? _listener;
  Duration _last = Duration.zero;
  int _watchedMs = 0;
  int _durationMs = 0;

  /// Tranche selon la part regardée (voir plus haut). `null` : vue trop courte pour compter.
  @visibleForTesting
  static String? bucketFor(int watchedMs, int durationMs) {
    if (durationMs <= 0 || watchedMs < 500) return null;
    final r = watchedMs / durationMs;
    if (r >= 1.5) return 'l';
    if (r >= 0.9) return 'f';
    if (r >= 0.5) return 'h';
    return 'q';
  }

  /// Commence à suivre la vidéo de [postId] jouée par [controller]. Envoie d'abord le suivi précédent.
  void start(String? postId, VideoPlayerController? controller) {
    flush();
    if (postId == null || postId.isEmpty || controller == null || kIsWeb) return;
    _postId = postId;
    _c = controller;
    _last = controller.value.position;
    _watchedMs = 0;
    _durationMs = 0;
    _listener = _onTick;
    controller.addListener(_listener!);
  }

  void _onTick() {
    final c = _c;
    if (c == null) return;
    final v = c.value;
    if (!v.isInitialized) return;
    _durationMs = v.duration.inMilliseconds;
    final delta = (v.position - _last).inMilliseconds;
    _last = v.position;
    // seul le temps de lecture réel compte : un saut en avant ou un retour au début (boucle) ne compte pas
    if (v.isPlaying && delta > 0 && delta < 1500) _watchedMs += delta;
  }

  /// Termine le suivi en cours et envoie la tranche (une seule fois). À appeler quand la vidéo quitte l'écran.
  void flush() {
    final c = _c;
    final id = _postId;
    if (c != null && _listener != null) {
      try {
        c.removeListener(_listener!);
      } catch (_) {}
    }
    final bucket = bucketFor(_watchedMs, _durationMs);
    final dur = (_durationMs / 1000).round();
    _c = null;
    _postId = null;
    _listener = null;
    _watchedMs = 0;
    _durationMs = 0;
    if (id != null && bucket != null) PostsApi.watch(id, bucket, durationSec: dur > 0 ? dur : null);
  }
}
