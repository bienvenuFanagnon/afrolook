import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/model_data.dart';
import '../../pages/chronique/chroniqueform.dart';
import '../postService/feed_scoring_service.dart';

/// Types de feed disponibles dans l'application.
enum FeedType { home, looks, sport, events, video, vibes, challenges }

/// Paramètres d'une requête de feed.
class FeedQuery {
  final FeedType type;
  final String userId;
  final String countryCode;
  final List<String> subscriptionPostIds; // newPostsFromSubscriptions de l'utilisateur
  final Set<String> excludeIds;
  final int targetCount;

  const FeedQuery({
    required this.type,
    required this.userId,
    this.countryCode = '',
    this.subscriptionPostIds = const [],
    this.excludeIds = const {},
    this.targetCount = 40,
  });
}

/// Couche Firestore centralisée — aucune page ne doit requêter Firestore directement.
///
/// Toutes les méthodes sont fault-tolerant (try/catch) et retournent [] en cas d'erreur,
/// pour que le feed dégrade gracieusement plutôt que de crasher.
class FeedRepository {
  static final FeedRepository _instance = FeedRepository._();
  factory FeedRepository() => _instance;
  FeedRepository._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── POINT D'ENTRÉE PRINCIPAL ─────────────────────────────────────────────────

  /// Charge un batch de posts selon la composition algorithmique approuvée :
  /// 30% abonnements · 25% pays · 20% score · 15% découverte · 10% résurgence
  Future<List<Post>> fetchFeed(FeedQuery query) async {
    final target = query.targetCount;
    final excluded = Set<String>.from(query.excludeIds);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final results = <Post>[];

    switch (query.type) {
      case FeedType.home:
        // 1. Abonnements (30%)
        final aboIds = _take(query.subscriptionPostIds, excluded, (target * 0.30).round());
        excluded.addAll(aboIds);
        results.addAll(await loadPostsByIds(aboIds));

        // 2. Pays (25%)
        final countryPosts = await fetchCountryPosts(
          query.countryCode, excluded,
          limit: (target * 0.25).round(),
        );
        _addAll(results, excluded, countryPosts);

        // 3. Score élevé (20%)
        final scorePosts = await fetchScorePosts(excluded, limit: (target * 0.20).round());
        _addAll(results, excluded, scorePosts);

        // 4. Découverte (15%) — posts récents hors abonnements
        final discoPosts = await fetchDiscoveryPosts(
          query.subscriptionPostIds.toSet(), excluded,
          limit: (target * 0.15).round(),
        );
        _addAll(results, excluded, discoPosts);

        // 5. Résurgence (10%) — anciens posts de qualité
        final resurge = await fetchResurgencePosts(excluded, limit: (target * 0.10).round());
        _addAll(results, excluded, resurge);
        break;

      case FeedType.video:
        results.addAll(await fetchByMediaType('VIDEO', query.countryCode, excluded, limit: target));
        break;

      case FeedType.vibes:
        results.addAll(await fetchByMediaType('AUDIO', query.countryCode, excluded, limit: target));
        break;

      default:
        final tabbarType = _feedTypeToTabbar(query.type);
        if (tabbarType != null) {
          results.addAll(await fetchByTabbarType(tabbarType, query.countryCode, excluded, limit: target));
        }
    }

    // Score final et tri
    for (final post in results) {
      post.feedScore = _computeScore(post, nowMs, query.countryCode);
    }
    results.sort((a, b) => (b.feedScore ?? 0).compareTo(a.feedScore ?? 0));
    return results;
  }

  // ── REQUÊTES SPÉCIALISÉES ────────────────────────────────────────────────────

  /// Posts filtrés par pays (optionnellement filtrés par type média ou tabbar).
  Future<List<Post>> fetchCountryPosts(
    String countryCode,
    Set<String> excluded, {
    int limit = 10,
    String? mediaType,
    String? tabbarType,
  }) async {
    if (countryCode.isEmpty) return [];
    try {
      Query<Map<String, dynamic>> q1 = _db
          .collection('Posts')
          .where('available_countries', arrayContains: countryCode)
          .orderBy('created_at', descending: true);
      Query<Map<String, dynamic>> q2 = _db
          .collection('Posts')
          .where('available_countries', arrayContains: 'ALL')
          .orderBy('created_at', descending: true);
      if (mediaType != null) {
        q1 = q1.where('dataType', isEqualTo: mediaType);
        q2 = q2.where('dataType', isEqualTo: mediaType);
      }
      if (tabbarType != null) {
        q1 = q1.where('typeTabbar', isEqualTo: tabbarType);
        q2 = q2.where('typeTabbar', isEqualTo: tabbarType);
      }
      final byCountry = await q1.limit(limit * 2).get();
      final byAll = await q2.limit(limit).get();
      final allDocs = {...byCountry.docs, ...byAll.docs}.toList();
      return _parsePosts(allDocs, excluded, limit);
    } catch (e) {
      print('⚠️ [FeedRepository] fetchCountryPosts: $e');
      return [];
    }
  }

  /// Posts avec feedScore élevé (posts populaires).
  Future<List<Post>> fetchScorePosts(Set<String> excluded, {int limit = 8}) async {
    try {
      final snap = await _db
          .collection('Posts')
          .where('feedScore', isGreaterThanOrEqualTo: 0.3)
          .orderBy('feedScore', descending: true)
          .limit(limit * 3)
          .get();
      return _parsePosts(snap.docs, excluded, limit);
    } catch (e) {
      print('⚠️ [FeedRepository] fetchScorePosts: $e');
      return [];
    }
  }

  /// Posts récents de créateurs non suivis (découverte).
  Future<List<Post>> fetchDiscoveryPosts(
    Set<String> followedPostIds,
    Set<String> excluded, {
    int limit = 6,
  }) async {
    try {
      final snap = await _db
          .collection('Posts')
          .orderBy('created_at', descending: true)
          .limit(limit * 5)
          .get();
      return _parsePosts(
        snap.docs.where((d) => !followedPostIds.contains(d.id)).toList(),
        excluded,
        limit,
      );
    } catch (e) {
      print('⚠️ [FeedRepository] fetchDiscoveryPosts: $e');
      return [];
    }
  }

  /// Anciens posts de qualité (2–6 mois) pour la résurgence.
  Future<List<Post>> fetchResurgencePosts(Set<String> excluded, {int limit = 4}) async {
    try {
      final now = DateTime.now();
      final twoMonthsAgo = now.subtract(const Duration(days: 60)).millisecondsSinceEpoch;
      final sixMonthsAgo = now.subtract(const Duration(days: 180)).millisecondsSinceEpoch;
      final snap = await _db
          .collection('Posts')
          .where('feedScore', isGreaterThanOrEqualTo: 0.5)
          .where('created_at', isGreaterThanOrEqualTo: sixMonthsAgo)
          .where('created_at', isLessThanOrEqualTo: twoMonthsAgo)
          .orderBy('feedScore', descending: true)
          .limit(limit * 3)
          .get();
      return _parsePosts(snap.docs, excluded, limit);
    } catch (e) {
      print('⚠️ [FeedRepository] fetchResurgencePosts: $e');
      return [];
    }
  }

  /// Posts filtrés par typeTabbar (LOOKS, SPORT, EVENEMENT…).
  Future<List<Post>> fetchByTabbarType(
    String tabbarType,
    String countryCode,
    Set<String> excluded, {
    int limit = 40,
  }) async {
    try {
      final snap = await _db
          .collection('Posts')
          .where('typeTabbar', isEqualTo: tabbarType)
          .orderBy('created_at', descending: true)
          .limit(limit * 2)
          .get();
      final posts = _parsePosts(snap.docs, excluded, limit);
      // Priorité aux posts du pays de l'utilisateur
      if (countryCode.isNotEmpty) {
        posts.sort((a, b) {
          final aMatch = a.isAvailableForCountry(countryCode) ? 1 : 0;
          final bMatch = b.isAvailableForCountry(countryCode) ? 1 : 0;
          return bMatch.compareTo(aMatch);
        });
      }
      return posts;
    } catch (e) {
      print('⚠️ [FeedRepository] fetchByTabbarType($tabbarType): $e');
      return [];
    }
  }

  /// Posts filtrés par type média (VIDEO, AUDIO, IMAGE…).
  Future<List<Post>> fetchByMediaType(
    String mediaType,
    String countryCode,
    Set<String> excluded, {
    int limit = 40,
  }) async {
    try {
      final snap = await _db
          .collection('Posts')
          .where('dataType', isEqualTo: mediaType)
          .orderBy('created_at', descending: true)
          .limit(limit * 2)
          .get();
      return _parsePosts(snap.docs, excluded, limit);
    } catch (e) {
      print('⚠️ [FeedRepository] fetchByMediaType($mediaType): $e');
      return [];
    }
  }

  /// Posts récents sans filtre pays (optionnellement filtrés par type média ou tabbar).
  Future<List<Post>> fetchRecentPosts(
    Set<String> excluded, {
    int limit = 20,
    String? mediaType,
    String? tabbarType,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _db
          .collection('Posts')
          .orderBy('created_at', descending: true);
      if (mediaType != null) q = q.where('dataType', isEqualTo: mediaType);
      if (tabbarType != null) q = q.where('typeTabbar', isEqualTo: tabbarType);
      final snap = await q.limit(limit * 2).get();
      return _parsePosts(snap.docs, excluded, limit);
    } catch (e) {
      print('⚠️ [FeedRepository] fetchRecentPosts: $e');
      return [];
    }
  }

  /// Posts de pays autres que [excludeCountry] (optionnellement filtrés par type).
  Future<List<Post>> fetchOtherCountriesPosts(
    String excludeCountry,
    Set<String> excluded, {
    int limit = 10,
    String? mediaType,
    String? tabbarType,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _db
          .collection('Posts')
          .orderBy('created_at', descending: true);
      if (mediaType != null) q = q.where('dataType', isEqualTo: mediaType);
      if (tabbarType != null) q = q.where('typeTabbar', isEqualTo: tabbarType);
      final snap = await q.limit(limit * 4).get();
      final posts = <Post>[];
      for (final doc in snap.docs) {
        if (excluded.contains(doc.id)) continue;
        if (posts.length >= limit) break;
        try {
          final post = Post.fromJson({'id': doc.id, ...doc.data()});
          if (post.status == 'SUPPRIMER') continue;
          if (post.isAdvertisement == true) continue;
          if (post.availableCountries.contains(excludeCountry)) continue;
          posts.add(post);
        } catch (_) {}
      }
      return posts;
    } catch (e) {
      print('⚠️ [FeedRepository] fetchOtherCountriesPosts: $e');
      return [];
    }
  }

  /// Charge des posts par leurs IDs (par batches de 10, limite Firestore).
  Future<List<Post>> loadPostsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final posts = <Post>[];
    for (int i = 0; i < ids.length; i += 10) {
      final batch = ids.sublist(i, min(i + 10, ids.length));
      try {
        final snap = await _db
            .collection('Posts')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        for (final doc in snap.docs) {
          try {
            posts.add(Post.fromJson({'id': doc.id, ...doc.data()}));
          } catch (_) {}
        }
      } catch (e) {
        print('⚠️ [FeedRepository] loadPostsByIds batch[$i]: $e');
      }
    }
    return posts;
  }

  // ── CONTENU GLOBAL (partagé par tous les feeds) ──────────────────────────────

  Future<List<Chronique>> fetchChroniques({int limit = 8}) async {
    try {
      final snap = await _db
          .collection('chroniques')
          .orderBy('createdAt', descending: true)
          .limit(limit * 2)
          .get();
      final valid = <Chronique>[];
      for (final doc in snap.docs) {
        try {
          final c = Chronique.fromMap(doc.data(), doc.id);
          if (!c.isExpired) valid.add(c);
          if (valid.length >= limit) break;
        } catch (_) {}
      }
      return valid;
    } catch (e) {
      print('⚠️ [FeedRepository] fetchChroniques: $e');
      return [];
    }
  }

  Future<List<Canal>> fetchCanaux({int limit = 6}) async {
    try {
      final snap = await _db
          .collection('Canal')
          .orderBy('followers', descending: true)
          .limit(limit)
          .get();
      final result = <Canal>[];
      for (final doc in snap.docs) {
        try {
          result.add(Canal.fromJson({'id': doc.id, ...doc.data()}));
        } catch (_) {}
      }
      return result;
    } catch (e) {
      print('⚠️ [FeedRepository] fetchCanaux: $e');
      return [];
    }
  }

  Future<List<ArticleData>> fetchArticles({int limit = 3}) async {
    try {
      final snap = await _db
          .collection('Articles')
          .orderBy('created_at', descending: true)
          .limit(limit)
          .get();
      final result = <ArticleData>[];
      for (final doc in snap.docs) {
        try {
          result.add(ArticleData.fromJson({'id': doc.id, ...doc.data()}));
        } catch (_) {}
      }
      return result;
    } catch (e) {
      print('⚠️ [FeedRepository] fetchArticles: $e');
      return [];
    }
  }

  // ── HELPERS ──────────────────────────────────────────────────────────────────

  List<String> _take(List<String> ids, Set<String> excluded, int limit) =>
      ids.where((id) => !excluded.contains(id)).take(limit).toList();

  void _addAll(List<Post> target, Set<String> excluded, List<Post> source) {
    for (final post in source) {
      if (post.id != null && post.id!.isNotEmpty) {
        excluded.add(post.id!);
      }
      target.add(post);
    }
  }

  List<Post> _parsePosts(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    Set<String> excluded,
    int limit,
  ) {
    final result = <Post>[];
    for (final doc in docs) {
      if (excluded.contains(doc.id)) continue;
      if (result.length >= limit) break;
      try {
        final post = Post.fromJson({'id': doc.id, ...doc.data()});
        if (post.status == 'SUPPRIMER') continue;
        result.add(post);
      } catch (_) {}
    }
    return result;
  }

  /// Score composite : engagement×0.35 + fraîcheur×0.25 + pays×0.20 + nouveau_créateur×0.15 + viralité×0.05
  double _computeScore(Post post, int nowMs, String countryCode) {
    // Engagement (base FeedScoringService)
    final engagement = FeedScoringService.calculateFeedScore(post, 0).clamp(0.0, 1.0);

    // Fraîcheur : demi-vie 7 jours
    final ageHours = (nowMs - (post.createdAt ?? nowMs)) / 3600000.0;
    final freshness = exp(-ageHours / 168.0);

    // Match pays
    final paysMatch = countryCode.isNotEmpty && post.isAvailableForCountry(countryCode) ? 1.0 : 0.0;

    // Boost nouveau créateur (<200 abonnés ET post <30 jours)
    final isNewCreator = (post.user?.abonnes ?? 999) < 200 && ageHours < 720;
    final newBoost = isNewCreator ? 1.0 : 0.0;

    // Viralité (interactions / vues)
    final vues = (post.vues ?? 0).toDouble();
    final interactions = ((post.likes ?? 0) + (post.comments ?? 0) + (post.partage ?? 0)).toDouble();
    final virality = vues > 10 ? (interactions / vues).clamp(0.0, 1.0) : 0.0;

    return (engagement * 0.35 +
        freshness * 0.25 +
        paysMatch * 0.20 +
        newBoost * 0.15 +
        virality * 0.05);
  }

  String? _feedTypeToTabbar(FeedType type) {
    switch (type) {
      case FeedType.looks: return TabBarType.LOOKS.name;
      case FeedType.sport: return TabBarType.SPORT.name;
      case FeedType.events: return TabBarType.EVENEMENT.name;
      default: return null;
    }
  }
}
