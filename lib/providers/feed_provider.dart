import 'package:flutter/foundation.dart';
import '../models/model_data.dart';
import '../pages/chronique/chroniqueform.dart';
import '../pages/home/feed_cache_service.dart';
import '../services/feed/feed_repository.dart';
import '../services/postService/mixed_feed_service.dart';

/// État immuable pour un type de feed donné.
class FeedState {
  final List<Post> posts;
  final List<dynamic> mixedContent; // posts + chroniques + canaux + articles intercalés
  final bool isLoading;
  final bool hasMore;
  final bool isFromCache;
  final String? error;
  final DateTime? lastRefresh;

  const FeedState({
    this.posts = const [],
    this.mixedContent = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.isFromCache = false,
    this.error,
    this.lastRefresh,
  });

  FeedState copyWith({
    List<Post>? posts,
    List<dynamic>? mixedContent,
    bool? isLoading,
    bool? hasMore,
    bool? isFromCache,
    String? error,
    DateTime? lastRefresh,
  }) =>
      FeedState(
        posts: posts ?? this.posts,
        mixedContent: mixedContent ?? this.mixedContent,
        isLoading: isLoading ?? this.isLoading,
        hasMore: hasMore ?? this.hasMore,
        isFromCache: isFromCache ?? this.isFromCache,
        error: error,
        lastRefresh: lastRefresh ?? this.lastRefresh,
      );

  bool get isEmpty => posts.isEmpty && !isLoading;
  bool get hasContent => posts.isNotEmpty;
}

/// Provider central pour tous les feeds.
///
/// Chaque [FeedType] a son propre [FeedState]. Un Set global évite les doublons
/// entre types (même post ne s'affiche qu'une fois par session).
class FeedProvider extends ChangeNotifier {
  final FeedRepository _repo = FeedRepository();

  final Map<FeedType, FeedState> _states = {};
  final Set<String> _globalSeenIds = {};

  // Contenu global partagé (chargé une fois, utilisé par tous les feeds)
  List<Chronique> _chroniques = [];
  List<Canal> _canaux = [];
  List<ArticleData> _articles = [];
  bool _globalContentLoaded = false;

  // ── ACCESSEURS ───────────────────────────────────────────────────────────────

  FeedState stateFor(FeedType type) => _states[type] ?? const FeedState();
  List<Post> postsFor(FeedType type) => _states[type]?.posts ?? const [];
  List<dynamic> mixedFor(FeedType type) => _states[type]?.mixedContent ?? const [];
  bool isLoadingFor(FeedType type) => _states[type]?.isLoading ?? false;
  bool hasMoreFor(FeedType type) => _states[type]?.hasMore ?? true;
  bool isFromCacheFor(FeedType type) => _states[type]?.isFromCache ?? false;

  List<Chronique> get chroniques => _chroniques;
  List<Canal> get canaux => _canaux;
  List<ArticleData> get articles => _articles;

  // ── CHARGEMENT ───────────────────────────────────────────────────────────────

  Future<void> loadFeed(
    FeedType type, {
    required String userId,
    required String countryCode,
    List<String> subscriptionPostIds = const [],
  }) async {
    if (isLoadingFor(type)) return;
    _setLoading(type, true);

    // 1. Tentative cache (TTL 30 min)
    final cacheKey = _cacheKey(type, countryCode);
    final cached = await FeedCacheService.loadFeedData(
      cacheKey,
      maxAge: const Duration(minutes: 30),
    );
    if (cached != null) {
      final posts = _postsFromCache(cached);
      if (posts.isNotEmpty) {
        _applyState(
          type,
          FeedState(
            posts: posts,
            mixedContent: _buildMixed(posts, type),
            isLoading: false,
            isFromCache: true,
            hasMore: true,
          ),
        );
        // Rafraîchissement silencieux en arrière-plan
        _refreshBackground(type,
            userId: userId,
            countryCode: countryCode,
            subscriptionPostIds: subscriptionPostIds);
        return;
      }
    }

    // 2. Chargement Firestore
    await _fetchAndApply(
      type,
      userId: userId,
      countryCode: countryCode,
      subscriptionPostIds: subscriptionPostIds,
    );
  }

  /// Charge plus de posts (pagination).
  Future<void> loadMore(
    FeedType type, {
    required String userId,
    required String countryCode,
    List<String> subscriptionPostIds = const [],
  }) async {
    final state = stateFor(type);
    if (state.isLoading || !state.hasMore) return;
    _setLoading(type, true);
    await _fetchAndApply(
      type,
      userId: userId,
      countryCode: countryCode,
      subscriptionPostIds: subscriptionPostIds,
      append: true,
    );
  }

  /// Réinitialise et recharge un feed depuis zéro.
  Future<void> refresh(
    FeedType type, {
    required String userId,
    required String countryCode,
    List<String> subscriptionPostIds = const [],
  }) async {
    _states[type] = const FeedState();
    // On ne vide pas _globalSeenIds pour éviter des doublons inter-feeds
    notifyListeners();
    await loadFeed(type,
        userId: userId,
        countryCode: countryCode,
        subscriptionPostIds: subscriptionPostIds);
  }

  /// Précharge un feed en arrière-plan (sans bloquer l'UI).
  void preload(
    FeedType type, {
    required String userId,
    required String countryCode,
    List<String> subscriptionPostIds = const [],
  }) {
    if (stateFor(type).hasContent || isLoadingFor(type)) return;
    Future.microtask(() => loadFeed(
          type,
          userId: userId,
          countryCode: countryCode,
          subscriptionPostIds: subscriptionPostIds,
        ));
  }

  // ── CONTENU GLOBAL ───────────────────────────────────────────────────────────

  Future<void> loadGlobalContent() async {
    if (_globalContentLoaded) return;
    try {
      final results = await Future.wait([
        _repo.fetchChroniques(),
        _repo.fetchCanaux(),
        _repo.fetchArticles(),
      ]);
      _chroniques = results[0] as List<Chronique>;
      _canaux = results[1] as List<Canal>;
      _articles = results[2] as List<ArticleData>;
      _globalContentLoaded = true;

      // Reconstruire le contenu mixé pour les feeds déjà chargés
      for (final type in _states.keys) {
        final state = _states[type]!;
        if (state.posts.isNotEmpty) {
          _states[type] = state.copyWith(mixedContent: _buildMixed(state.posts, type));
        }
      }
      notifyListeners();
    } catch (e) {
      print('⚠️ [FeedProvider] loadGlobalContent: $e');
    }
  }

  void markSeen(String postId) {
    _globalSeenIds.add(postId);
  }

  // ── PRIVÉ ────────────────────────────────────────────────────────────────────

  Future<void> _fetchAndApply(
    FeedType type, {
    required String userId,
    required String countryCode,
    List<String> subscriptionPostIds = const [],
    bool append = false,
  }) async {
    try {
      final currentPosts = append ? List<Post>.from(postsFor(type)) : <Post>[];
      final excluded = Set<String>.from(_globalSeenIds)
        ..addAll(currentPosts.map((p) => p.id ?? '').where((id) => id.isNotEmpty));

      final query = FeedQuery(
        type: type,
        userId: userId,
        countryCode: countryCode,
        subscriptionPostIds: subscriptionPostIds,
        excludeIds: excluded,
        targetCount: 40,
      );

      final newPosts = await _repo.fetchFeed(query);
      _globalSeenIds.addAll(newPosts.map((p) => p.id ?? '').where((id) => id.isNotEmpty));

      final allPosts = [...currentPosts, ...newPosts];

      // Sauvegarder en cache (chargement initial uniquement)
      if (!append && newPosts.isNotEmpty) {
        _saveToCache(type, countryCode, allPosts);
      }

      _applyState(
        type,
        FeedState(
          posts: allPosts,
          mixedContent: _buildMixed(allPosts, type),
          isLoading: false,
          hasMore: newPosts.isNotEmpty,
          isFromCache: false,
          lastRefresh: DateTime.now(),
        ),
      );
    } catch (e) {
      _applyState(
        type,
        stateFor(type).copyWith(isLoading: false, error: e.toString()),
      );
    }
  }

  void _refreshBackground(
    FeedType type, {
    required String userId,
    required String countryCode,
    List<String> subscriptionPostIds = const [],
  }) {
    Future.microtask(() => _fetchAndApply(
          type,
          userId: userId,
          countryCode: countryCode,
          subscriptionPostIds: subscriptionPostIds,
        ));
  }

  /// Construit le contenu mixé (chroniques → posts → canaux → articles → posts restants)
  /// uniquement pour le feed home. Les autres feeds n'affichent que des posts.
  List<dynamic> _buildMixed(List<Post> posts, FeedType type) {
    if (type != FeedType.home) {
      return posts.map((p) => ContentSection(type: ContentMixtType.POST, data: p)).toList();
    }

    final mixed = <dynamic>[];

    if (_chroniques.isNotEmpty) {
      mixed.add(ContentSection(type: ContentMixtType.CHRONIQUES, data: _chroniques));
    }
    for (final post in posts.take(3)) {
      mixed.add(ContentSection(type: ContentMixtType.POST, data: post));
    }
    if (_canaux.isNotEmpty) {
      mixed.add(ContentSection(type: ContentMixtType.CANAUX, data: _canaux));
    }
    if (_articles.isNotEmpty) {
      mixed.add(ContentSection(type: ContentMixtType.ARTICLES, data: _articles));
    }
    for (final post in posts.skip(3)) {
      mixed.add(ContentSection(type: ContentMixtType.POST, data: post));
    }

    return mixed;
  }

  void _setLoading(FeedType type, bool loading) {
    _states[type] = stateFor(type).copyWith(isLoading: loading);
    notifyListeners();
  }

  void _applyState(FeedType type, FeedState state) {
    _states[type] = state;
    notifyListeners();
  }

  String _cacheKey(FeedType type, String country) =>
      FeedCacheService.buildKey(
        type.name.toUpperCase(),
        'recent_${country.isNotEmpty ? country : "global"}',
      );

  void _saveToCache(FeedType type, String country, List<Post> posts) {
    final key = _cacheKey(type, country);
    final data = {'posts': posts.map((p) => p.toJson()).toList()};
    FeedCacheService.saveFeedData(key, data);
  }

  List<Post> _postsFromCache(Map<String, dynamic> cached) {
    try {
      final list = cached['data']?['posts'] as List? ?? [];
      return list
          .map((e) {
            try {
              return Post.fromJson(e as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<Post>()
          .toList();
    } catch (e) {
      return [];
    }
  }
}
