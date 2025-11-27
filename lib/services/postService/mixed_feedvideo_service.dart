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

class TikTokVideoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final UserAuthProvider authProvider;
  final CategorieProduitProvider categorieProvider;
  final PostProvider postProvider;
  final ChroniqueProvider chroniqueProvider;
  final ContentProvider contentProvider;

  // 🔥 MÉMOIRE DES VIDÉOS VUES
  static const String _prefsKeySeen = 'seen_tiktok_videos';
  Set<String> _seenVideoIds = Set();
  final int _maxSeenMemory = 300;

  // 🔥 CURSEURS POUR VIDÉOS
  Map<String, DocumentSnapshot?> _cursors = {
    'lowScore': null,
    'mediumScore': null,
    'highScore': null,
    'recent': null,
  };

  // 🔥 GESTION DES TENTATIVES
  int _consecutiveEmptyLoads = 0;
  static const int _maxConsecutiveEmptyLoads = 3;

  // CONTENU GLOBAL POUR PUBLICITÉS
  List<ArticleData> _globalArticles = [];
  List<Canal> _globalCanaux = [];
  bool _hasLoadedGlobalContent = false;

  TikTokVideoService({
    required this.authProvider,
    required this.categorieProvider,
    required this.postProvider,
    required this.chroniqueProvider,
    required this.contentProvider,
  });

  Future<void> initialize() async {
    await _loadSeenVideosFromStorage();
    print('🎯 Service TikTok initialisé - ${_seenVideoIds.length} vidéos vues');
  }

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
  Future<List<Post>> loadTikTokVideos({
    required int userLastVisitTime,
    bool isInitialLoad = true,
    bool loadMore = false,
  }) async {
    print('🚀 Chargement vidéos TikTok - Initial: $isInitialLoad, LoadMore: $loadMore');

    try {
      if (_consecutiveEmptyLoads >= _maxConsecutiveEmptyLoads) {
        print('🔄 Réinitialisation après charges vides successives');
        await _softReset();
      }

      List<Post> results;

      if (isInitialLoad) {
        results = await _loadInitialTikTokVideos(userLastVisitTime);
      } else if (loadMore) {
        results = await _loadMoreTikTokVideos(userLastVisitTime);
      } else {
        results = await _loadNewVideosOnly(userLastVisitTime);
      }

      // Gestion des charges vides
      if (results.isEmpty) {
        _consecutiveEmptyLoads++;
        print('⚠️ Charge vidéos vide ($_consecutiveEmptyLoads/$_maxConsecutiveEmptyLoads)');
      } else {
        _consecutiveEmptyLoads = 0;
      }

      return results;

    } catch (e) {
      print('❌ Erreur chargement vidéos TikTok: $e');
      _consecutiveEmptyLoads++;
      return [];
    }
  }

  // 🔥 CHARGEMENT INITIAL VIDÉOS
  Future<List<Post>> _loadInitialTikTokVideos(int userLastVisitTime) async {
    print('🎯 Chargement initial vidéos TikTok...');

    _resetCursors();

    final results = await Future.wait([
      _loadRecentVideos(userLastVisitTime, limit: 8),
      _loadLowScoreVideos(userLastVisitTime, limit: 10),
      _loadMediumScoreVideos(userLastVisitTime, limit: 6),
      _loadHighScoreVideos(userLastVisitTime, limit: 4),
    ], eagerError: true);

    final allVideos = [...results[0], ...results[1], ...results[2], ...results[3]];

    // Mélange et filtrage
    final shuffledVideos = _shuffleVideos(allVideos);
    final uniqueVideos = _filterSeenVideos(shuffledVideos);

    print('📊 Mix vidéos: ${allVideos.length} bruts → ${uniqueVideos.length} uniques');

    // GARDE-FOU
    if (uniqueVideos.isEmpty && allVideos.isNotEmpty) {
      return _handleAllVideosFiltered(allVideos);
    }

    return uniqueVideos;
  }

  // 🔥 CHARGEMENT SUPPLÉMENTAIRE VIDÉOS
  Future<List<Post>> _loadMoreTikTokVideos(int userLastVisitTime) async {
    print('📥 Chargement supplémentaire vidéos...');

    final List<Post> newVideos = [];

    // Priorité aux vidéos faible score pour la découverte
    if (newVideos.length < 6) {
      final lowScoreVideos = await _loadLowScoreVideos(userLastVisitTime, limit: 8);
      newVideos.addAll(lowScoreVideos);
    }

    // Puis moyen score
    if (newVideos.length < 4) {
      final mediumScoreVideos = await _loadMediumScoreVideos(userLastVisitTime, limit: 6);
      newVideos.addAll(mediumScoreVideos);
    }

    // Enfin haut score
    if (newVideos.length < 2) {
      final highScoreVideos = await _loadHighScoreVideos(userLastVisitTime, limit: 4);
      newVideos.addAll(highScoreVideos);
    }

    if (newVideos.isEmpty) {
      print('🏁 Fin des vidéos disponibles');
      return [];
    }

    final uniqueVideos = _filterSeenVideos(newVideos);
    print('📥 Vidéos supplémentaires: ${uniqueVideos.length}');

    return uniqueVideos;
  }

  // 🔥 VIDÉOS RÉCENTES
  Future<List<Post>> _loadRecentVideos(int userLastVisitTime, {required int limit}) async {
    try {
      final userLastVisitMicros = _millisToMicro(userLastVisitTime);

      final snapshot = await _firestore
          .collection('Posts')
          .where('dataType', isEqualTo: 'VIDEO')
          .where('type', whereIn: [PostType.POST.name, PostType.CHALLENGEPARTICIPATION.name])
          .where('created_at', isGreaterThan: userLastVisitMicros - Duration(days: 2).inMicroseconds)
          .orderBy('created_at', descending: true)
          .limit(limit)
          .get();

      final videos = _processVideosSnapshot(snapshot);
      _calculateScores(videos, userLastVisitTime);

      print('🆕 Vidéos récentes: ${videos.length}');
      return videos;

    } catch (e) {
      print('❌ Erreur vidéos récentes: $e');
      return [];
    }
  }

  // 🔥 VIDÉOS FAIBLE SCORE
  Future<List<Post>> _loadLowScoreVideos(int userLastVisitTime, {required int limit}) async {
    try {
      Query query = _firestore
          .collection('Posts')
          .where('dataType', isEqualTo: 'VIDEO')
          .where('type', whereIn: [PostType.POST.name, PostType.CHALLENGEPARTICIPATION.name])
          .where('feedScore', isGreaterThanOrEqualTo: 0.0)
          .where('feedScore', isLessThan: 0.4)
          .orderBy('feedScore', descending: false)
          .orderBy('created_at', descending: true)
          .limit(limit);

      if (_cursors['lowScore'] != null) {
        query = query.startAfterDocument(_cursors['lowScore']!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _cursors['lowScore'] = snapshot.docs.last;
      }

      final videos = _processVideosSnapshot(snapshot);
      _calculateScores(videos, userLastVisitTime);

      print('📉 Vidéos faible score: ${videos.length}');
      return videos;

    } catch (e) {
      print('❌ Erreur vidéos faible score: $e');
      return [];
    }
  }

  // 🔥 VIDÉOS MOYEN SCORE
  Future<List<Post>> _loadMediumScoreVideos(int userLastVisitTime, {required int limit}) async {
    try {
      Query query = _firestore
          .collection('Posts')
          .where('dataType', isEqualTo: 'VIDEO')
          .where('type', whereIn: [PostType.POST.name, PostType.CHALLENGEPARTICIPATION.name])
          .where('feedScore', isGreaterThanOrEqualTo: 0.4)
          .where('feedScore', isLessThan: 0.7)
          .orderBy('feedScore', descending: true)
          .orderBy('created_at', descending: true)
          .limit(limit);

      if (_cursors['mediumScore'] != null) {
        query = query.startAfterDocument(_cursors['mediumScore']!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _cursors['mediumScore'] = snapshot.docs.last;
      }

      final videos = _processVideosSnapshot(snapshot);
      _calculateScores(videos, userLastVisitTime);

      return videos;

    } catch (e) {
      print('❌ Erreur vidéos moyen score: $e');
      return [];
    }
  }

  // 🔥 VIDÉOS FORT SCORE
  Future<List<Post>> _loadHighScoreVideos(int userLastVisitTime, {required int limit}) async {
    try {
      Query query = _firestore
          .collection('Posts')
          .where('dataType', isEqualTo: 'VIDEO')
          .where('type', whereIn: [PostType.POST.name, PostType.CHALLENGEPARTICIPATION.name])
          .where('feedScore', isGreaterThanOrEqualTo: 0.7)
          .orderBy('feedScore', descending: true)
          .orderBy('created_at', descending: true)
          .limit(limit);

      if (_cursors['highScore'] != null) {
        query = query.startAfterDocument(_cursors['highScore']!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _cursors['highScore'] = snapshot.docs.last;
      }

      final videos = _processVideosSnapshot(snapshot);
      _calculateScores(videos, userLastVisitTime);

      return videos;

    } catch (e) {
      print('❌ Erreur vidéos fort score: $e');
      return [];
    }
  }

  // 🔥 FILTRAGE VIDÉOS VUES
  List<Post> _filterSeenVideos(List<Post> videos) {
    final uniqueVideos = <Post>[];
    int filteredCount = 0;

    for (final video in videos) {
      if (video.id != null && !_seenVideoIds.contains(video.id!)) {
        uniqueVideos.add(video);
        _markVideoAsSeen(video.id!);
      } else {
        filteredCount++;
      }
    }

    print('🔍 Filtrage vidéos: ${videos.length} → ${uniqueVideos.length} uniques ($filteredCount filtrés)');
    return uniqueVideos;
  }

  // 🔥 NOUVELLES VIDÉOS SEULEMENT
  Future<List<Post>> _loadNewVideosOnly(int userLastVisitTime) async {
    print('🔄 Chargement nouvelles vidéos...');

    final userLastVisitMicros = _millisToMicro(userLastVisitTime);

    try {
      final snapshot = await _firestore
          .collection('Posts')
          .where('dataType', isEqualTo: 'VIDEO')
          .where('type', whereIn: [PostType.POST.name, PostType.CHALLENGEPARTICIPATION.name])
          .where('created_at', isGreaterThan: userLastVisitMicros)
          .orderBy('created_at', descending: true)
          .limit(15)
          .get();

      final newVideos = _processVideosSnapshot(snapshot);
      _calculateScores(newVideos, userLastVisitTime);

      final uniqueVideos = _filterSeenVideos(newVideos);
      print('🆕 Nouvelles vidéos: ${uniqueVideos.length}');

      return uniqueVideos;

    } catch (e) {
      print('❌ Erreur nouvelles vidéos: $e');
      return [];
    }
  }

  // 🔥 MÉTHODES UTILITAIRES
  List<Post> _shuffleVideos(List<Post> videos) {
    final random = Random();
    final shuffled = List<Post>.from(videos);
    shuffled.shuffle(random);
    return shuffled;
  }

  List<Post> _handleAllVideosFiltered(List<Post> allVideos) {
    print('⚠️ GARDE-FOU: Toutes les vidéos filtrées');

    _cleanSeenMemory(50);

    final emergencyVideos = allVideos.take(3).toList();
    for (final video in emergencyVideos) {
      _markVideoAsSeen(video.id!);
    }

    print('🆘 Vidéos d\'urgence: ${emergencyVideos.length}');
    return emergencyVideos;
  }

  void _cleanSeenMemory(int keepCount) {
    if (_seenVideoIds.length > keepCount) {
      final idsToKeep = _seenVideoIds.take(keepCount).toSet();
      _seenVideoIds = idsToKeep;
      _saveSeenVideosToStorage();
      print('🧹 Mémoire vidéos nettoyée: $keepCount conservés');
    }
  }

  Future<void> _softReset() async {
    _cursors.forEach((key, value) {
      _cursors[key] = null;
    });
    _consecutiveEmptyLoads = 0;
    _cleanSeenMemory(100);
    print('🔄 Réinitialisation douce vidéos effectuée');
  }

  void _markVideoAsSeen(String videoId) {
    _seenVideoIds.add(videoId);

    if (_seenVideoIds.length > _maxSeenMemory) {
      final idsToRemove = _seenVideoIds.take(_seenVideoIds.length - _maxSeenMemory).toList();
      for (final id in idsToRemove) {
        _seenVideoIds.remove(id);
      }
    }

    _saveSeenVideosToStorage();
  }

  void _resetCursors() {
    _cursors.forEach((key, value) {
      _cursors[key] = null;
    });
  }

  List<Post> _processVideosSnapshot(QuerySnapshot snapshot) {
    return snapshot.docs.map((doc) {
      try {
        final post = Post.fromJson(doc.data() as Map<String, dynamic>);
        post.id = doc.id;

        if (post.createdAt == null) return null;
        final postDate = DateTime.fromMicrosecondsSinceEpoch(post.createdAt!);
        if (postDate.year < 2020 || postDate.year > 2030) return null;

        return post;
      } catch (e) {
        return null;
      }
    }).where((post) => post != null).cast<Post>().toList();
  }

  void _calculateScores(List<Post> posts, int userLastVisitTime) {
    for (final post in posts) {
      final score = FeedScoringService.calculateFeedScore(post, userLastVisitTime);
      post.feedScore = score;
    }
  }

  int _millisToMicro(int millis) => millis * 1000;

  // 🔥 CHARGEMENT CONTENU PUBLICITAIRE
  Future<void> loadAdsContent() async {
    if (_hasLoadedGlobalContent) return;

    try {
      final results = await Future.wait([
        _loadGlobalArticles(),
        _loadGlobalCanaux(),
      ], eagerError: true);

      _globalArticles = results[0] as List<ArticleData>;
      _globalCanaux = results[1] as List<Canal>;
      _hasLoadedGlobalContent = true;

      print('🛍️ Contenu publicitaire chargé: ${_globalArticles.length} articles, ${_globalCanaux.length} canaux');

    } catch (e) {
      print('❌ Erreur chargement contenu publicitaire: $e');
    }
  }

  Future<List<ArticleData>> _loadGlobalArticles() async {
    try {
      final countryCode = authProvider.loginUserData.countryData?['countryCode'] ?? 'TG';
      return await categorieProvider.getArticleBooster(countryCode);
    } catch (e) {
      print('❌ Erreur articles: $e');
      return [];
    }
  }

  Future<List<Canal>> _loadGlobalCanaux() async {
    try {
      return await postProvider.getCanauxHome();
    } catch (e) {
      print('❌ Erreur canaux: $e');
      return [];
    }
  }

  Future<void> reset() async {
    _seenVideoIds.clear();
    _resetCursors();
    _consecutiveEmptyLoads = 0;
    _hasLoadedGlobalContent = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeySeen);

    print('🔄 Service TikTok COMPLÈTEMENT réinitialisé');
  }

  // GETTERS
  List<ArticleData> get articles => _globalArticles;
  List<Canal> get canaux => _globalCanaux;
  int get seenVideosCount => _seenVideoIds.length;
}