import 'dart:async';
import 'dart:math';
import 'package:video_player/video_player.dart';

import '../models/model_data.dart';
import 'media_cache_service.dart';

/// Service singleton qui pré-initialise les contrôleurs vidéo des pubs actives.
/// Appeler [preload()] au démarrage ou avant d'afficher une page qui injecte des pubs.
class AdPreloadService {
  static final AdPreloadService _instance = AdPreloadService._();
  static AdPreloadService get instance => _instance;
  AdPreloadService._();

  /// Vidéos de pub prêtes à jouer en mémoire (au-delà, simple mise en cache sur le disque).
  static const int maxControllers = 4;

  final Map<String, VideoPlayerController> _controllers = {};
  final Map<String, Advertisement> _ads = {};
  bool _isLoaded = false;
  final _random = Random();

  bool get isLoaded => _isLoaded;
  List<Advertisement> get activeAds => _ads.values.toList();

  /// Les annonces ne sont plus lues dans une base du téléphone : le serveur choisit l'annonce à chaque emplacement (`/ads/app/serve`).
  /// Ce service ne garde donc que les contrôleurs vidéo déjà préparés ; il n'y a plus rien à précharger au démarrage.
  Future<void> preload() async {
    _isLoaded = true;
  }

  /// Télécharge sur le téléphone les vidéos des pubs déjà connues (liste du fournisseur d'authentification : chargée avant même que l'on ouvre
  /// les chroniques ou le fil). Appelée à chaque (re)chargement des pubs ; sans effet pour les images.
  static void prefetchFromAds(List<Map<String, dynamic>> ads) {
    final urls = <String>[];
    for (final e in ads) {
      final post = e['post'];
      if (post is! Map) continue;
      final url = (post['url_media'] ?? '').toString();
      final isVideo = post['type'] == 'VIDEO' || url.contains('.mp4') || url.contains('.mov');
      if (isVideo && url.isNotEmpty) urls.add(url);
    }
    if (urls.isNotEmpty) unawaited(MediaCacheService.prefetchAdVideos(urls));
  }

  /// Retourne le contrôleur vidéo pré-initialisé pour une pub donnée (ou null).
  VideoPlayerController? getController(String adId) => _controllers[adId];

  /// Transfère la propriété du contrôleur au widget demandeur.
  /// Le widget devient responsable du dispose. Un rechargement en arrière-plan peut suivre.
  VideoPlayerController? claimController(String adId) => _controllers.remove(adId);

  /// Retourne une pub active aléatoire parmi celles chargées.
  Advertisement? getRandomActiveAd() {
    if (_ads.isEmpty) return null;
    final keys = _ads.keys.toList();
    return _ads[keys[_random.nextInt(keys.length)]];
  }

  /// Réinitialise le cache (à appeler si les pubs changent).
  void invalidate() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    _ads.clear();
    _isLoaded = false;
  }
}
