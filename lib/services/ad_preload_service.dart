import 'package:afrotok/services/read_meter.dart';
import 'dart:math';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

import '../models/model_data.dart';
import '../utils/media_cdn.dart';
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

  Future<void> preload() async {
    if (_isLoaded) return;
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final snap = await FirebaseFirestore.instance
          .collection('Advertisements')
          .where('status', isEqualTo: 'active')
          .limit(10)
          .getM('ad_preload_service.dart:38');

      for (final doc in snap.docs) {
        final ad = Advertisement.fromJson(doc.data());
        ad.id = doc.id;
        if (ad.postId == null) continue;
        if (ad.endDate != null && ad.endDate! < now) continue;

        final postDoc = await FirebaseFirestore.instance
            .collection('Posts')
            .doc(ad.postId)
            .getM('ad_preload_service.dart:49');
        if (!postDoc.exists) continue;

        final postData = postDoc.data()!;
        final mediaUrl = postData['url_media'] as String?;
        if (mediaUrl == null || mediaUrl.isEmpty) continue;

        final type = postData['type'] as String?;
        _ads[doc.id] = ad;

        // Image de la pub (ou aperçu de la vidéo) déjà sur le téléphone avant qu'on arrive à l'emplacement
        final images = (postData['images'] is List) ? List<String>.from(postData['images']) : const <String>[];
        final still = type == 'VIDEO' ? (postData['thumbnail'] as String? ?? '') : (images.isNotEmpty ? images.first : mediaUrl);
        if (still.isNotEmpty) DefaultCacheManager().downloadFile(MediaCdn.url(still)).then((_) {}, onError: (_) {});

        // Seules les premières vidéos sont préparées en mémoire (un décodeur par vidéo) ; les autres sont mises en cache disque
        if (type == 'VIDEO' && _controllers.length >= maxControllers) {
          MediaCacheService.prefetchVideo(mediaUrl);
        } else if (type == 'VIDEO') {
          try {
            final ctrl = await MediaCacheService.videoController(mediaUrl);
            await ctrl.initialize();
            await ctrl.setVolume(0);
            await ctrl.setLooping(true);
            _controllers[doc.id] = ctrl;
          } catch (_) {}
        }
      }
      _isLoaded = true;
    } catch (e) {
      printVm('AdPreloadService.preload error: $e');
    }
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
