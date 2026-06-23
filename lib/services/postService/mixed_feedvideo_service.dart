import 'dart:math';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afrotok/models/model_data.dart';

import 'package:provider/provider.dart';

import '../../pages/socialVideos/thread/afrolookVideoOriginal.dart';

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
    printVm('🎯 Service TikTok initialisé - ${_seenVideoIds.length} vidéos vues');
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
      printVm('❌ Erreur chargement mémoire vidéos: $e');
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
      printVm('❌ Erreur sauvegarde mémoire vidéos: $e');
    }
  }

  // 🔥 ALGORITHME PRINCIPAL POUR VIDÉOS AVEC FILTRES
  Future<List<dynamic>> loadMixedVideoContent({
    bool loadMore = false,
    VideoFilter? filter,
  }) async {
    if (_isLoading) return _mixedVideoContent;

    _isLoading = true;

    try {
      printVm('🎬 Chargement contenu vidéo mixte - LoadMore: $loadMore - Filtre: ${filter?.label}');

      if (!loadMore) {
        _mixedVideoContent.clear();
        _currentIndex = 0;
        _alreadyLoadedVideoIds.clear();
      }

      // 🔥 PRÉPARER LES IDs SI NÉCESSAIRE
      if (!loadMore || _preparedVideoIds.isEmpty || _currentIndex >= _preparedVideoIds.length - 10) {
        final currentUserId = authProvider.loginUserData.id;
        if (currentUserId != null) {
          await _prepareInitialVideoIds(currentUserId, filter: filter);
        }
      }

      if (_preparedVideoIds.isEmpty) {
        printVm('📭 Aucune vidéo à charger');
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

      _hasMore = _currentIndex < _preparedVideoIds.length;

      printVm('✅ Contenu vidéo mixte chargé: ${_mixedVideoContent.length} éléments (hasMore: $_hasMore)');
      return _mixedVideoContent;

    } catch (e) {
      printVm('❌ Erreur chargement contenu vidéo mixte: $e');
      _hasMore = false;
      return _mixedVideoContent;
    } finally {
      _isLoading = false;
    }
  }

  // 🔥 PRÉPARATION DES IDs DE VIDÉOS AVEC FILTRES
  Future<void> _prepareInitialVideoIds(String currentUserId, {VideoFilter? filter}) async {
    if (_isPreparingVideos) return;

    _isPreparingVideos = true;

    try {
      printVm('🎯 Préparation des IDs de vidéos avec filtre: ${filter?.label}');

      final userDoc = await firestore.collection('Users').doc(currentUserId).get();
      if (!userDoc.exists) return;

      final userData = userDoc.data()!;
      final userLastVisitTime = userData['lastFeedVisitTime'] ??
          (DateTime.now().microsecondsSinceEpoch - Duration(hours: 1).inMicroseconds);

      // 🔥 ALGORITHME POUR VIDÉOS UNIQUES AVEC FILTRES
      final Set<String> allVideoIds = Set();

      // 🔥 APPLIQUER LE FILTRE CORRESPONDANT
      switch (filter) {
        case VideoFilter.CHALLENGE:
          final challengeVideos = await _getVideosByType(PostType.CHALLENGEPARTICIPATION.name, 30);
          allVideoIds.addAll(challengeVideos);
          break;

        case VideoFilter.VIRAL:
          final viralVideos = await _getVideosByScore(25, 0.7, 1.0);
          allVideoIds.addAll(viralVideos);
          break;

        case VideoFilter.RECENT:
          final recentVideos = await _getRecentVideoIds(30);
          allVideoIds.addAll(recentVideos);
          break;

        case VideoFilter.LOW_SCORE:
          final lowScoreVideos = await _getVideosByScore(25, 0.0, 0.4);
          allVideoIds.addAll(lowScoreVideos);
          break;

        case VideoFilter.ALL:
        default:
        // 🔥 MÉLANGE INTELLIGENT POUR "TOUT"
          final recentVideos = await _getRecentVideoIds(20);
          final highScoreVideos = await _getVideosByScore(15, 0.7, 1.0);
          final mediumScoreVideos = await _getVideosByScore(15, 0.4, 0.7);
          final lowScoreVideos = await _getVideosByScore(10, 0.0, 0.4);

          allVideoIds.addAll(recentVideos);
          allVideoIds.addAll(highScoreVideos);
          allVideoIds.addAll(mediumScoreVideos);
          allVideoIds.addAll(lowScoreVideos);
          break;
      }

      // 🔥 FILTRAGE FINAL POUR EXCLURE LES VIDÉOS VUES
      final filteredVideos = allVideoIds.where((id) => !_seenVideoIds.contains(id)).toList();

      printVm('''
🧹 FILTRAGE VIDÉOS:
   - Total trouvé: ${allVideoIds.length}
   - Après filtrage (déjà vues): ${filteredVideos.length}
   - Filtre appliqué: ${filter?.label ?? 'Tout'}
''');

      // 🔥 ORDRE CYCLIQUE POUR VIDÉOS
      final orderedVideos = _createVideoCyclicOrder(filteredVideos);
      _preparedVideoIds = orderedVideos.take(_preloadBatchSize).toList();
      _currentIndex = 0;
      _alreadyLoadedVideoIds.clear();
      _hasMore = _preparedVideoIds.isNotEmpty;

      printVm('📦 Préparation terminée: ${_preparedVideoIds.length} vidéos');

    } catch (e) {
      printVm('❌ Erreur préparation IDs vidéos: $e');
      _preparedVideoIds = [];
      _hasMore = false;
    } finally {
      _isPreparingVideos = false;
    }
  }

  // 🔥 ORDRE CYCLIQUE SIMPLIFIÉ POUR VIDÉOS
  List<String> _createVideoCyclicOrder(List<String> videos) {
    if (videos.isEmpty) return [];

    // Mélanger pour la variété
    final shuffled = List<String>.from(videos)..shuffle();
    return shuffled.take(_preloadBatchSize).toList();
  }

  // 🔥 CHARGEMENT DU LOT ACTUEL DE VIDÉOS
  Future<List<Post>> _loadCurrentVideoBatch() async {
    final batchSize = _displayBatchSize;
    final endIndex = min(_currentIndex + batchSize, _preparedVideoIds.length);

    if (_currentIndex >= _preparedVideoIds.length) {
      return [];
    }

    final availableIds = _preparedVideoIds.sublist(_currentIndex, endIndex)
        .where((id) => !_alreadyLoadedVideoIds.contains(id))
        .toList();

    if (availableIds.isEmpty) {
      printVm('⚠️ Toutes les vidéos de ce lot sont déjà chargées');
      _currentIndex = endIndex;
      return await _loadCurrentVideoBatch();
    }

    final videos = await _loadVideosByIds(availableIds);

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
      mixedContent.add(VideoContentSection(
        type: VideoContentType.VIDEO,
        data: video,
      ));
      videoCount++;

      // 🔥 INSÉRER UNE PUBLICITÉ APRÈS 3 VIDÉOS
      if (videoCount >= 3) {
        final adType = (mixedContent.length % 2 == 0) ? AdType.PRODUCT : AdType.CHANNEL;
        mixedContent.add(VideoContentSection(
          type: VideoContentType.AD,
          data: adType,
        ));
        videoCount = 0;
      }
    }

    printVm('🎬 Contenu vidéo mixte: ${mixedContent.length} éléments (${videos.length} vidéos)');
    return mixedContent;
  }

  // 🔥 MÉTHODES DE CHARGEMENT SPÉCIFIQUES AUX VIDÉOS
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
      printVm('❌ Erreur vidéos récentes: $e');
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
      printVm('❌ Erreur vidéos par score: $e');
      return [];
    }
  }

  Future<List<String>> _getVideosByType(String type, int limit) async {
    try {
      final snapshot = await firestore
          .collection('Posts')
          .where('dataType', isEqualTo: 'VIDEO')
          .where('type', isEqualTo: type)
          .orderBy('created_at', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      printVm('❌ Erreur vidéos par type: $e');
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

            if (post.createdAt == null) return null;
            final postDate = DateTime.fromMicrosecondsSinceEpoch(post.createdAt!);
            if (postDate.year < 2020 || postDate.year > 2030) return null;

            return post;
          } catch (e) {
            printVm('❌ Erreur parsing vidéo ${doc.id}: $e');
            return null;
          }
        }).where((video) => video != null).cast<Post>().toList();

        videos.addAll(batchVideos);
      }
    } catch (e) {
      printVm('❌ Erreur chargement vidéos par IDs: $e');
    }

    return videos;
  }

  // 🔥 MARQUER UNE VIDÉO COMME VUE
  Future<void> markVideoAsSeen(String videoId) async {
    try {
      _seenVideoIds.add(videoId);

      if (_seenVideoIds.length > _maxSeenMemory) {
        final idsToRemove = _seenVideoIds.take(_seenVideoIds.length - _maxSeenMemory).toList();
        for (final id in idsToRemove) {
          _seenVideoIds.remove(id);
        }
      }

      await _saveSeenVideosToStorage();

      final currentUserId = authProvider.loginUserData.id;
      if (currentUserId != null) {
        await firestore.collection('Users').doc(currentUserId).update({
          'viewedVideoIds': FieldValue.arrayUnion([videoId]),
        });
      }

      printVm('👁️ Vidéo $videoId marquée comme vue');

    } catch (e) {
      printVm('❌ Erreur marquage vidéo vue: $e');
    }
  }

  // 🔥 VIDER LA MÉMOIRE DES VIDÉOS VUES
  Future<void> clearSeenVideos() async {
    try {
      _seenVideoIds.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKeySeen);
      printVm('🧹 Mémoire vidéos vidée');
    } catch (e) {
      printVm('❌ Erreur vidage mémoire vidéos: $e');
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

    printVm('🔄 Service vidéo réinitialisé');
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

// 🔥 CLASSE POUR REPRÉSENTER UNE SECTION DE CONTENU VIDÉO
class VideoContentSection {
  final VideoContentType type;
  final dynamic data;

  VideoContentSection({required this.type, required this.data});
}