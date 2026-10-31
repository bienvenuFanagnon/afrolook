import 'dart:async';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:afrotok/services/api/canaux_api.dart';
import 'package:afrotok/services/api/home_feed_api.dart';
import 'package:afrotok/services/feed/feed_repository.dart';

import '../../pages/chronique/chroniqueform.dart';
import '../../providers/afroshop/categorie_produits_provider.dart';
import '../../providers/chroniqueProvider.dart';
import '../../providers/contenuPayantProvider.dart';

/// Moteur de contenu mixte de l'accueil, désormais alimenté par l'API (publications de découverte, chroniques, canaux).
/// Plus aucune lecture ni écriture Firestore ; une erreur de l'API laisse simplement les listes vides (journal en clair).

class FeedConfig {
  // ================= POSTS IMMÉDIATS (SPLASH) =================
  static const int immediatePostsCount = 2;

  // ================= PRÉPARATION DES IDs =================
  static const int preloadBatchSize = 25;
  static const int displayBatchSize = 5;

  // ================= ALGORITHMES DE RECHERCHE =================
  static const int maxPreparationAttempts = 3;
  static const int preparationDelayMs = 200;

  // Répartition pour la préparation des posts
  static const double subscriptionPercentage = 0.3;  // 30%
  static const double recentPercentage = 0.4;        // 40%
  static const double scorePercentage = 0.3;         // 30%

  // Limites par catégorie (calculées dynamiquement)
  static int get subscriptionLimit => (preloadBatchSize * subscriptionPercentage).round();
  static int get recentLimit => (preloadBatchSize * recentPercentage).round();
  static int get scoreLimit => (preloadBatchSize * scorePercentage).round();

  // ================= FILTRES =================
  static const int filteredPostsLimit = 5;
  static const int filteredPostsMultiplier = 2; // Pour avoir plus de choix

  // ================= NETTOYAGE =================
  static const int maxViewedPosts = 1000;
  static const int cleanupBatchSize = 500;
  static const int cleanupDelayMs = 100;

  // ================= CHRONIQUES =================
  static const int chroniquesLoadLimit = 20;
  static const int chroniquesDisplayLimit = 8;

  // ================= ARTICLES =================
  static const int articlesLoadLimit = 3;

  // ================= CANAUX =================
  static const int canauxLoadLimit = 6;

  // ================= CHARGEMENT PAR BATCH =================
  static const int postsBatchSize = 10; // Pour _loadPostsByIds

  // ================= FORÇAGE =================
  static const int minPostsForForce = 5;
  static const int forceAttemptThreshold = 2;
  static const int forceMultiplier = 2;

  // ================= VISIBILITÉ =================
  static const double visibilityThreshold = 0.8;
  static const double visibilityCancelThreshold = 0.3;
  static const int visibilityTimerSeconds = 2;

  // ================= DÉLAIS =================
  static const int backgroundLoadDelayMs = 500;
  static const int batchCommitDelayMs = 100;
}

class MixedFeedService {
  final UserAuthProvider authProvider;
  final CategorieProduitProvider categorieProvider;
  final PostProvider postProvider;
  final ChroniqueProvider chroniqueProvider;
  final ContentProvider contentProvider;

  MixedFeedService({
    required this.authProvider,
    required this.categorieProvider,
    required this.postProvider,
    required this.chroniqueProvider,
    required this.contentProvider,
  });

  final List<Post> _prepared = [];
  String? _cursor;
  bool _exhausted = false;

  List<ArticleData> _globalArticles = [];
  List<Canal> _globalCanaux = [];
  List<Chronique> _globalChroniques = [];
  bool _hasLoadedGlobalContent = false;

  final Set<String> _alreadyLoadedPostIds = {};
  bool _isLoading = false;
  bool _hasMore = true;
  List<dynamic> _mixedContent = [];

  List<Post> _immediatePosts = [];
  bool _areImmediatePostsLoaded = false;

  List<String> get preparedPostIds => _prepared.map((p) => p.id!).toList();
  int get preparedPostsCount => _prepared.length;
  bool get isReady => _prepared.isNotEmpty;
  List<dynamic> get mixedContent => _mixedContent;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  bool get isGlobalContentLoaded => _hasLoadedGlobalContent;
  List<ArticleData> get articles => _globalArticles;
  List<Canal> get canaux => _globalCanaux;
  List<Chronique> get chroniques => _globalChroniques;
  List<Post> get immediatePosts => _immediatePosts;
  bool get areImmediatePostsLoaded => _areImmediatePostsLoaded;

  Future<void> _fetchMore(int limit) async {
    if (_exhausted) return;
    try {
      final page = await HomeFeedApi.discover(cursor: _cursor, limit: limit, tier: 1);
      var posts = page.posts;
      var next = page.next;
      if (posts.isEmpty && _cursor == null) {
        // Rien chez les abonnements : découverte
        final d = await HomeFeedApi.discover(limit: limit);
        posts = d.posts;
        next = d.next;
      }
      _prepared.addAll(posts.where((p) => !_prepared.any((q) => q.id == p.id)));
      _cursor = next;
      _exhausted = next == null;
    } catch (e) {
      printVm('❌ API accueil en échec : ');
      _exhausted = true;
    }
  }

  Future<void> loadImmediatePosts() async {
    if (_areImmediatePostsLoaded) return;
    await _fetchMore(FeedConfig.preloadBatchSize);
    _immediatePosts = _prepared.take(FeedConfig.immediatePostsCount).toList();
    _areImmediatePostsLoaded = true;
  }

  Future<void> preparePostsOnly() async {
    if (_prepared.isEmpty) await _fetchMore(FeedConfig.preloadBatchSize);
  }

  Future<void> loadGlobalContentFromPage() async {
    if (_hasLoadedGlobalContent) return;
    _hasLoadedGlobalContent = true;
    try {
      _globalChroniques = await FeedRepository().fetchChroniques(limit: FeedConfig.chroniquesDisplayLimit);
    } catch (e) {
      printVm('❌ API chroniques en échec : ');
    }
    try {
      final page = await CanauxApi.list(limit: FeedConfig.canauxLoadLimit, myId: authProvider.loginUserData.id);
      _globalCanaux = page.items;
    } catch (e) {
      printVm('❌ API canaux en échec : ');
    }
    // Articles : voir lacunes_api_publications.md (le fil d'actualités est servi par /news/feed)
  }

  Future<List<dynamic>> loadMixedContent({bool loadMore = false}) async {
    if (_isLoading) return _mixedContent;
    _isLoading = true;
    try {
      if (!loadMore) {
        _mixedContent = [];
        _alreadyLoadedPostIds.clear();
        _prepared.clear();
        _cursor = null;
        _exhausted = false;
      }
      if (_prepared.where((p) => !_alreadyLoadedPostIds.contains(p.id)).length < FeedConfig.displayBatchSize) {
        await _fetchMore(FeedConfig.preloadBatchSize);
      }
      final batch = _prepared.where((p) => !_alreadyLoadedPostIds.contains(p.id)).take(FeedConfig.displayBatchSize).toList();
      for (final p in batch) {
        _alreadyLoadedPostIds.add(p.id!);
      }
      final content = <dynamic>[];
      if (!loadMore && _globalChroniques.isNotEmpty) {
        content.add(ContentSection(type: ContentMixtType.CHRONIQUES, data: _globalChroniques));
      }
      content.addAll(batch);
      _mixedContent = loadMore ? [..._mixedContent, ...content] : content;
      _hasMore = !_exhausted || _prepared.any((p) => !_alreadyLoadedPostIds.contains(p.id));
      if (batch.isNotEmpty) HomeFeedApi.markSeen(batch.map((p) => p.id!)).catchError((_) {});
      return _mixedContent;
    } finally {
      _isLoading = false;
    }
  }

  /// Marque une publication comme vue (le serveur retient ce qui a été vu).
  Future<void> markPostAsSeen(String postId) async {
    try {
      await HomeFeedApi.markSeen({postId});
    } catch (_) {}
  }

  /// Sans objet : l'historique des vues est tenu par le serveur.
  Future<void> clearUserViewedPosts() async {}
  Future<void> cleanupUserLists() async {}

  Future<void> reset() async {
    _prepared.clear();
    _cursor = null;
    _exhausted = false;
    _hasLoadedGlobalContent = false;
    _alreadyLoadedPostIds.clear();
    _mixedContent.clear();
    _isLoading = false;
    _hasMore = true;
    _immediatePosts.clear();
    _areImmediatePostsLoaded = false;
  }
}

// ENUM POUR LES TYPES DE CONTENU
enum ContentMixtType { POST, CHRONIQUES, ARTICLES, CANAUX }

// CLASSE POUR REPRÉSENTER UNE SECTION DE CONTENU
class ContentSection {
  final ContentMixtType type;
  final dynamic data;

  ContentSection({required this.type, required this.data});
}
