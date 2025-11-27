import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:provider/provider.dart';
import '../../providers/afroshop/categorie_produits_provider.dart';
import '../../providers/chroniqueProvider.dart';
import '../../providers/contenuPayantProvider.dart';
import 'feed_scoring_service.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/postProvider.dart';


class MixedTikTokVideoService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final UserAuthProvider authProvider;
  final CategorieProduitProvider categorieProvider;
  final PostProvider postProvider;
  final ChroniqueProvider chroniqueProvider;
  final ContentProvider contentProvider;

  // 🔥 CACHE AMÉLIORÉ POUR VIDÉOS
  List<String> _preparedVideoIds = [];
  int _currentIndex = 0;
  static const int _preloadBatchSize = 50;
  static const int _displayBatchSize = 5;

  // 🔥 MÉMOIRE DES VIDÉOS DÉJÀ CHARGÉES
  Set<String> _alreadyLoadedVideoIds = Set();
  Set<String> _seenVideoIds = Set();
  final int _maxSeenMemory = 300;
  static const String _prefsKeySeen = 'seen_tiktok_videos';

  // 🔥 ÉTAT DE CHARGEMENT
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isPreparingVideos = false;

  // 🔥 CONTENU MIXTE ACTUEL POUR VIDÉOS
  List<dynamic> _mixedVideoContent = [];

  MixedTikTokVideoService({
    required this.authProvider,
    required this.categorieProvider,
    required this.postProvider,
    required this.chroniqueProvider,
    required this.contentProvider,
  });

  // 🔥 GETTERS
  List<dynamic> get mixedVideoContent => _mixedVideoContent;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  bool get isReady => _preparedVideoIds.isNotEmpty;
  int get preparedVideosCount => _preparedVideoIds.length;
  int get currentIndex => _currentIndex;

  // 🔥 INITIALISATION
  Future<void> initialize() async {
    await _loadSeenVideosFromStorage();
    print('🎯 Service TikTok initialisé - ${_seenVideoIds.length} vidéos vues');
  }

  // 🔥 CHARGEMENT DE LA MÉMOIRE DES VIDÉOS VUES
  Future<void> _loadSeenVideosFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seenJson = prefs.getString(_prefsKeySeen);

      if (seenJson != null && seenJson.isNotEmpty) {
        _seenVideoIds = seenJson.split(',').where((id) => id.length >= 8).toSet();
        _seenVideoIds = _seenVideoIds.take(_maxSeenMemory).toSet();
      }
    } catch (e) {
      print('❌ Erreur chargement mémoire vidéos: $e');
      _seenVideoIds = Set();
    }
  }

  // 🔥 SAUVEGARDE DE LA MÉMOIRE
  Future<void> _saveSeenVideosToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final seenJson = _seenVideoIds.take(200).join(',');
      await prefs.setString(_prefsKeySeen, seenJson);
    } catch (e) {
      print('❌ Erreur sauvegarde mémoire vidéos: $e');
    }
  }

  // 🔥 ALGORITHME PRINCIPAL POUR VIDÉOS
  Future<List<dynamic>> loadMixedVideoContent({bool loadMore = false}) async {
    if (_isLoading) return _mixedVideoContent;

    _isLoading = true;

    try {
      print('🎬 Chargement contenu vidéo mixte - LoadMore: $loadMore');

      if (!loadMore) {
        // 🔥 RÉINITIALISER POUR LE PREMIER CHARGEMENT
        _mixedVideoContent.clear();
        _currentIndex = 0;
        _alreadyLoadedVideoIds.clear();
      }

      // 🔥 PRÉPARER LES IDs SI NÉCESSAIRE
      if (!loadMore || _preparedVideoIds.isEmpty || _currentIndex >= _preparedVideoIds.length - 10) {
        final currentUserId = authProvider.loginUserData.id;
        if (currentUserId != null) {
          await _prepareInitialVideoIds(currentUserId);
        }
      }

      if (_preparedVideoIds.isEmpty) {
        print('📭 Aucune vidéo à charger');
        _hasMore = false;
        return _mixedVideoContent;
      }

      // 🔥 CHARGER LE LOT DE VIDÉOS ACTUEL
      final videos = await _loadCurrentVideoBatch();

      // 🔥 CONSTRUIRE LE CONTENU MIXTE AVEC PUBLICITÉS
      final newContent = _buildMixedVideoContent(videos, loadMore: loadMore);

      if (loadMore) {
        _mixedVideoContent.addAll(newContent);
      } else {
        _mixedVideoContent = newContent;
      }

      // 🔥 METTRE À JOUR L'ÉTAT "HAS MORE"
      _hasMore = _currentIndex < _preparedVideoIds.length;

      print('✅ Contenu vidéo mixte chargé: ${_mixedVideoContent.length} éléments (hasMore: $_hasMore)');
      return _mixedVideoContent;

    } catch (e) {
      print('❌ Erreur chargement contenu vidéo mixte: $e');
      _hasMore = false;
      return _mixedVideoContent;
    } finally {
      _isLoading = false;
    }
  }

  // 🔥 PRÉPARATION DES IDs DE VIDÉOS (CORRIGÉ)
  Future<void> _prepareInitialVideoIds(String currentUserId) async {
    if (_isPreparingVideos) return;

    _isPreparingVideos = true;

    try {
      print('🎯 Préparation des IDs de vidéos...');

      final userDoc = await firestore.collection('Users').doc(currentUserId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final userLastVisitTime = userData['lastFeedVisitTime'] ??
          (DateTime.now().microsecondsSinceEpoch - Duration(hours: 1).inMicroseconds);

      // 🔥 ALGORITHME POUR VIDÉOS UNIQUES - EXCLURE LES VIDÉOS VUES
      final Set<String> allVideoIds = Set();

      // 1. Vidéos récentes non vues (CORRIGÉ - pas de whereNotIn avec whereIn)
      final recentVideos = await _getRecentVideoIds(20);
      allVideoIds.addAll(recentVideos);

      // 2. Vidéos par score (CORRIGÉ - pas de whereNotIn avec whereIn)
      final highScoreVideos = await _getVideosByScore(15, 0.7, 1.0);
      final mediumScoreVideos = await _getVideosByScore(15, 0.4, 0.7);
      final lowScoreVideos = await _getVideosByScore(10, 0.0, 0.4);

      allVideoIds.addAll(highScoreVideos);
      allVideoIds.addAll(mediumScoreVideos);
      allVideoIds.addAll(lowScoreVideos);

      print('📊 Composition vidéos: ${recentVideos.length} récentes, ${highScoreVideos.length}F ${mediumScoreVideos.length}M ${lowScoreVideos.length}L');

      // 🔥 FILTRAGE FINAL POUR EXCLURE LES VIDÉOS VUES
      final filteredRecentVideos = recentVideos.where((id) => !_seenVideoIds.contains(id)).toList();
      final filteredHighScoreVideos = highScoreVideos.where((id) => !_seenVideoIds.contains(id)).toList();
      final filteredMediumScoreVideos = mediumScoreVideos.where((id) => !_seenVideoIds.contains(id)).toList();
      final filteredLowScoreVideos = lowScoreVideos.where((id) => !_seenVideoIds.contains(id)).toList();

      print('''
🧹 FILTRAGE VIDÉOS:
   - Récents: ${recentVideos.length} → ${filteredRecentVideos.length}
   - Fort: ${highScoreVideos.length} → ${filteredHighScoreVideos.length}
   - Moyen: ${mediumScoreVideos.length} → ${filteredMediumScoreVideos.length}
   - Low: ${lowScoreVideos.length} → ${filteredLowScoreVideos.length}
''');

      // 🔥 ORDRE CYCLIQUE POUR VIDÉOS
      final orderedVideos = _createVideoCyclicOrder(
        recentVideos: filteredRecentVideos,
        highScoreVideos: filteredHighScoreVideos,
        mediumScoreVideos: filteredMediumScoreVideos,
        lowScoreVideos: filteredLowScoreVideos,
      );

      _preparedVideoIds = orderedVideos.take(_preloadBatchSize).toList();
      _currentIndex = 0;
      _alreadyLoadedVideoIds.clear();
      _hasMore = _preparedVideoIds.isNotEmpty;

      print('''
📦 PRÉPARATION VIDÉOS TERMINÉE:
   - IDs préparés: ${_preparedVideoIds.length} vidéos
   - Vidéos exclues (déjà vues): ${_seenVideoIds.length}
   - Premier ID: ${_preparedVideoIds.isNotEmpty ? _preparedVideoIds.first : 'aucun'}
''');

    } catch (e) {
      print('❌ Erreur préparation IDs vidéos: $e');
      _preparedVideoIds = [];
      _hasMore = false;
    } finally {
      _isPreparingVideos = false;
    }
  }

  // 🔥 ORDRE CYCLIQUE POUR VIDÉOS
  List<String> _createVideoCyclicOrder({
    required List<String> recentVideos,
    required List<String> highScoreVideos,
    required List<String> mediumScoreVideos,
    required List<String> lowScoreVideos,
  }) {
    final orderedVideos = <String>[];

    // 🔥 CRÉER DES COPIES MUTABLES
    final recentPool = List<String>.from(recentVideos);
    final highPool = List<String>.from(highScoreVideos);
    final mediumPool = List<String>.from(mediumScoreVideos);
    final lowPool = List<String>.from(lowScoreVideos);

    // 🔥 PATTERN SPÉCIAL POUR VIDÉOS TIKTOK
    const pattern = [
      _VideoType.RECENT, _VideoType.RECENT, _VideoType.RECENT,
      _VideoType.HIGH, _VideoType.HIGH,
      _VideoType.MEDIUM, _VideoType.MEDIUM,
      _VideoType.LOW, _VideoType.LOW,
      _VideoType.RECENT, _VideoType.RECENT,
    ];

    int patternIndex = 0;

    while (orderedVideos.length < _preloadBatchSize) {
      final currentType = pattern[patternIndex % pattern.length];

      String? nextVideo;

      switch (currentType) {
        case _VideoType.RECENT:
          if (recentPool.isNotEmpty) nextVideo = recentPool.removeAt(0);
          break;
        case _VideoType.HIGH:
          if (highPool.isNotEmpty) nextVideo = highPool.removeAt(0);
          break;
        case _VideoType.MEDIUM:
          if (mediumPool.isNotEmpty) nextVideo = mediumPool.removeAt(0);
          break;
        case _VideoType.LOW:
          if (lowPool.isNotEmpty) nextVideo = lowPool.removeAt(0);
          break;
      }

      // 🔥 COMPENSATION SI CATÉGORIE VIDE
      if (nextVideo == null) {
        nextVideo = _getAnyAvailableVideo([recentPool, highPool, mediumPool, lowPool]);
      }

      if (nextVideo != null) {
        orderedVideos.add(nextVideo);
      } else {
        break; // Plus de vidéos disponibles
      }

      patternIndex++;
    }

    print('🎯 Ordre cyclique vidéos: ${orderedVideos.length} vidéos');
    return orderedVideos;
  }

  String? _getAnyAvailableVideo(List<List<String>> pools) {
    for (final pool in pools) {
      if (pool.isNotEmpty) {
        return pool.removeAt(0);
      }
    }
    return null;
  }

  // 🔥 CHARGEMENT DU LOT ACTUEL DE VIDÉOS
  Future<List<Post>> _loadCurrentVideoBatch() async {
    final batchSize = _displayBatchSize;
    final endIndex = min(_currentIndex + batchSize, _preparedVideoIds.length);

    if (_currentIndex >= _preparedVideoIds.length) {
      return [];
    }

    // 🔥 FILTRER LES IDs DÉJÀ CHARGÉS
    final availableIds = _preparedVideoIds.sublist(_currentIndex, endIndex)
        .where((id) => !_alreadyLoadedVideoIds.contains(id))
        .toList();

    if (availableIds.isEmpty) {
      print('⚠️ Toutes les vidéos de ce lot sont déjà chargées');
      _currentIndex = endIndex;
      return await _loadCurrentVideoBatch();
    }

    final videos = await _loadVideosByIds(availableIds);

    // 🔥 METTRE À JOUR LA MÉMOIRE ET L'INDEX
    for (final video in videos) {
      if (video.id != null) {
        _alreadyLoadedVideoIds.add(video.id!);
      }
    }

    _currentIndex = endIndex;
    return videos;
  }

  // 🔥 CONSTRUCTION DU CONTENU MIXTE VIDÉOS + PUBLICITÉS
  List<dynamic> _buildMixedVideoContent(List<Post> videos, {bool loadMore = false}) {
    final mixedContent = <dynamic>[];
    int videoCount = 0;

    for (final video in videos) {
      // Ajouter la vidéo
      mixedContent.add(VideoContentSection(
        type: VideoContentType.VIDEO,
        data: video,
      ));
      videoCount++;

      // 🔥 INSÉRER UNE PUBLICITÉ APRÈS 3 VIDÉOS
      if (videoCount >= 3) {
        // Alterner entre produits et canaux
        final adType = (mixedContent.length % 2 == 0) ? AdType.PRODUCT : AdType.CHANNEL;
        mixedContent.add(VideoContentSection(
          type: VideoContentType.AD,
          data: adType,
        ));
        videoCount = 0;
      }
    }

    print('🎬 Contenu vidéo mixte: ${mixedContent.length} éléments (${videos.length} vidéos)');
    return mixedContent;
  }

  // 🔥 MÉTHODES DE CHARGEMENT SPÉCIFIQUES AUX VIDÉOS (CORRIGÉES)
  Future<List<String>> _getRecentVideoIds(int limit) async {
    try {
      final snapshot = await firestore
          .collection('Posts')
          .where('dataType', isEqualTo: 'VIDEO')
          .where('type', whereIn: [PostType.POST.name, PostType.CHALLENGEPARTICIPATION.name])
          .orderBy('created_at', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('❌ Erreur vidéos récentes: $e');
      return [];
    }
  }

  Future<List<String>> _getVideosByScore(int limit, double minScore, double maxScore) async {
    try {
      final snapshot = await firestore
          .collection('Posts')
          .where('dataType', isEqualTo: 'VIDEO')
          .where('type', whereIn: [PostType.POST.name, PostType.CHALLENGEPARTICIPATION.name])
          .where('feedScore', isGreaterThanOrEqualTo: minScore)
          .where('feedScore', isLessThan: maxScore)
          .orderBy('feedScore', descending: minScore > 0.5)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      print('❌ Erreur vidéos par score: $e');
      return [];
    }
  }

  Future<List<Post>> _loadVideosByIds(List<String> videoIds) async {
    if (videoIds.isEmpty) return [];

    final List<Post> videos = [];

    try {
      for (int i = 0; i < videoIds.length; i += 10) {
        final batchIds = videoIds.sublist(i, min(i + 10, videoIds.length));

        final snapshot = await firestore
            .collection('Posts')
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();

        final batchVideos = snapshot.docs.map((doc) {
          try {
            final post = Post.fromJson({'id': doc.id, ...doc.data()});

            // 🔥 VALIDATION DE LA VIDÉO
            if (post.createdAt == null) return null;
            final postDate = DateTime.fromMicrosecondsSinceEpoch(post.createdAt!);
            if (postDate.year < 2020 || postDate.year > 2030) return null;

            return post;
          } catch (e) {
            print('❌ Erreur parsing vidéo ${doc.id}: $e');
            return null;
          }
        }).where((video) => video != null).cast<Post>().toList();

        videos.addAll(batchVideos);
      }
    } catch (e) {
      print('❌ Erreur chargement vidéos par IDs: $e');
    }

    return videos;
  }

  // 🔥 MARQUER UNE VIDÉO COMME VUE
  Future<void> markVideoAsSeen(String videoId) async {
    try {
      _seenVideoIds.add(videoId);

      // 🔥 LIMITER LA TAILLE DE LA MÉMOIRE
      if (_seenVideoIds.length > _maxSeenMemory) {
        final idsToRemove = _seenVideoIds.take(_seenVideoIds.length - _maxSeenMemory).toList();
        for (final id in idsToRemove) {
          _seenVideoIds.remove(id);
        }
      }

      await _saveSeenVideosToStorage();

      // 🔥 METTRE À JOUR FIRESTORE (optionnel)
      final currentUserId = authProvider.loginUserData.id;
      if (currentUserId != null) {
        await firestore.collection('Users').doc(currentUserId).update({
          'viewedVideoIds': FieldValue.arrayUnion([videoId]),
        });
      }

      print('👁️ Vidéo $videoId marquée comme vue');

    } catch (e) {
      print('❌ Erreur marquage vidéo vue: $e');
    }
  }

  // 🔥 VIDER LA MÉMOIRE DES VIDÉOS VUES
  Future<void> clearSeenVideos() async {
    try {
      _seenVideoIds.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKeySeen);
      print('🧹 Mémoire vidéos vidée');
    } catch (e) {
      print('❌ Erreur vidage mémoire vidéos: $e');
    }
  }

  // 🔥 RÉINITIALISATION COMPLÈTE
  Future<void> reset() async {
    _preparedVideoIds.clear();
    _currentIndex = 0;
    _alreadyLoadedVideoIds.clear();
    _mixedVideoContent.clear();
    _isLoading = false;
    _hasMore = true;

    print('🔄 Service vidéo réinitialisé');
  }
}

// 🔥 ENUMS POUR LES TYPES DE CONTENU VIDÉO
enum VideoContentType {
  VIDEO,
  AD
}

enum AdType {
  PRODUCT,
  CHANNEL
}

enum _VideoType { RECENT, HIGH, MEDIUM, LOW }

// 🔥 CLASSE POUR REPRÉSENTER UNE SECTION DE CONTENU VIDÉO
class VideoContentSection {
  final VideoContentType type;
  final dynamic data;

  VideoContentSection({required this.type, required this.data});
}