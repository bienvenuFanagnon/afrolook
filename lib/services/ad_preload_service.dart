import 'dart:math';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:video_player/video_player.dart';

import '../models/model_data.dart';

/// Service singleton qui pré-initialise les contrôleurs vidéo des pubs actives.
/// Appeler [preload()] au démarrage ou avant d'afficher une page qui injecte des pubs.
class AdPreloadService {
  static final AdPreloadService _instance = AdPreloadService._();
  static AdPreloadService get instance => _instance;
  AdPreloadService._();

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
          .get();

      for (final doc in snap.docs) {
        final ad = Advertisement.fromJson(doc.data());
        ad.id = doc.id;
        if (ad.postId == null) continue;
        if (ad.endDate != null && ad.endDate! < now) continue;

        final postDoc = await FirebaseFirestore.instance
            .collection('Posts')
            .doc(ad.postId)
            .get();
        if (!postDoc.exists) continue;

        final postData = postDoc.data()!;
        final mediaUrl = postData['url_media'] as String?;
        if (mediaUrl == null || mediaUrl.isEmpty) continue;

        final type = postData['type'] as String?;
        _ads[doc.id] = ad;

        if (type == 'VIDEO') {
          try {
            final ctrl = VideoPlayerController.networkUrl(Uri.parse(mediaUrl));
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
