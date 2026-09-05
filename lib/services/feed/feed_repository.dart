import 'dart:math';
import 'package:afrotok/pages/component/consoleWidget.dart';

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
        // Les 5 seaux tournent en parallèle — chacun ignore les exclusions
        // inter-seaux (dédup géré après collection).
        final aboIds = _take(query.subscriptionPostIds, excluded, (target * 0.30).round());
        final buckets = await Future.wait([
          loadPostsByIds(aboIds),
          fetchCountryPosts(query.countryCode, excluded, limit: (target * 0.25).round()),
          fetchScorePosts(excluded, limit: (target * 0.20).round()),
          fetchDiscoveryPosts(query.subscriptionPostIds.toSet(), excluded, limit: (target * 0.15).round()),
          fetchResurgencePosts(excluded, limit: (target * 0.10).round()),
        ]);
        // Déduplication par ordre de priorité (seau 0 = plus prioritaire)
        final seen = <String>{...excluded};
        for (final bucket in buckets) {
          for (final post in bucket) {
            if (post.id != null && seen.add(post.id!)) {
              results.add(post);
            }
          }
        }
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
      printVm('⚠️ [FeedRepository] fetchCountryPosts: $e');
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
      printVm('⚠️ [FeedRepository] fetchScorePosts: $e');
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
      printVm('⚠️ [FeedRepository] fetchDiscoveryPosts: $e');
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
      printVm('⚠️ [FeedRepository] fetchResurgencePosts: $e');
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
      printVm('⚠️ [FeedRepository] fetchByTabbarType($tabbarType): $e');
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
      printVm('⚠️ [FeedRepository] fetchByMediaType($mediaType): $e');
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
      printVm('⚠️ [FeedRepository] fetchRecentPosts: $e');
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
      printVm('⚠️ [FeedRepository] fetchOtherCountriesPosts: $e');
      return [];
    }
  }

  /// Charge des posts par leurs IDs (par batches de 10, limite Firestore).
  /// [tabbarType] filtre côté Firestore si fourni (ex. 'SPORT').
  Future<List<Post>> loadPostsByIds(List<String> ids, {String? tabbarType}) async {
    if (ids.isEmpty) return [];
    final posts = <Post>[];
    for (int i = 0; i < ids.length; i += 10) {
      final batch = ids.sublist(i, min(i + 10, ids.length));
      try {
        Query<Map<String, dynamic>> q = _db
            .collection('Posts')
            .where(FieldPath.documentId, whereIn: batch);
        if (tabbarType != null) q = q.where('typeTabbar', isEqualTo: tabbarType);
        final snap = await q.get();
        for (final doc in snap.docs) {
          try {
            posts.add(Post.fromJson({'id': doc.id, ...doc.data()}));
          } catch (_) {}
        }
      } catch (e) {
        printVm('⚠️ [FeedRepository] loadPostsByIds batch[$i]: $e');
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
      printVm('⚠️ [FeedRepository] fetchChroniques: $e');
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
      printVm('⚠️ [FeedRepository] fetchCanaux: $e');
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
      printVm('⚠️ [FeedRepository] fetchArticles: $e');
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

  // ── ABONNEMENTS & BOOST NOUVEAUX POSTS ─────────────────────────────────────

  /// Posts récents (≤ [withinDays] jours) des créateurs suivis, triés du plus récent.
  /// Utilisé pour garantir ≥10 posts abonnements dans le feed même si FeedPreloadService
  /// n'est pas encore chargé.
  Future<List<Post>> fetchFollowingRecentPosts(
    List<String> followingIds,
    Set<String> excluded, {
    int limit = 10,
    int withinDays = 7,
  }) async {
    if (followingIds.isEmpty) return [];
    final since = DateTime.now().subtract(Duration(days: withinDays)).millisecondsSinceEpoch;
    final posts = <Post>[];
    final seen = <String>{...excluded};

    // whereIn supporte max 30 ids — on chunk par 10 pour large compatibilité
    for (int i = 0; i < followingIds.length && posts.length < limit; i += 10) {
      final chunk = followingIds.sublist(i, min(i + 10, followingIds.length));
      try {
        final snap = await _db
            .collection('Posts')
            .where('user_id', whereIn: chunk)
            .orderBy('created_at', descending: true)
            .limit(limit * 2)
            .get();
        for (final doc in snap.docs) {
          if (posts.length >= limit) break;
          if (seen.contains(doc.id)) continue;
          try {
            final post = Post.fromJson({'id': doc.id, ...doc.data()});
            if (post.status == 'SUPPRIMER') continue;
            if ((post.createdAt ?? 0) < since) break; // ordonné desc — inutile de continuer
            seen.add(doc.id);
            posts.add(post);
          } catch (_) {}
        }
      } catch (e) {
        printVm('⚠️ [FeedRepository] fetchFollowingRecentPosts chunk[$i]: $e');
      }
    }
    posts.shuffle();
    return posts.take(limit).toList();
  }

  /// Posts très récents (≤ 48h) avec peu de vues — à booster pour donner de l'exposition
  /// aux nouveaux créateurs et aux posts qui se perdent dans l'algo.
  Future<List<Post>> fetchNewPostsToBoost(Set<String> excluded, {int limit = 5}) async {
    final since = DateTime.now()
        .subtract(const Duration(hours: 48))
        .millisecondsSinceEpoch;
    try {
      final snap = await _db
          .collection('Posts')
          .where('created_at', isGreaterThanOrEqualTo: since)
          .orderBy('created_at', descending: true)
          .limit(limit * 4)
          .get();
      final candidates = _parsePosts(snap.docs, excluded, limit * 4);
      // Priorité aux posts les moins vus → ceux qui ont besoin d'exposition
      candidates.sort((a, b) => (a.vues ?? 0).compareTo(b.vues ?? 0));
      return candidates.take(limit).toList();
    } catch (e) {
      printVm('⚠️ [FeedRepository] fetchNewPostsToBoost: $e');
      return [];
    }
  }

  // ── SCORING ──────────────────────────────────────────────────────────────────

  /// Score composite : engagement×0.30 + fraîcheur×0.20 + pays×0.20 + nouveau_créateur×0.15 + ultra_frais×0.10 + viralité×0.05
  double _computeScore(Post post, int nowMs, String countryCode) {
    final engagement = FeedScoringService.calculateEngagementScore(post).clamp(0.0, 1.0);

    // Fraîcheur : demi-vie 7 jours
    final ageHours = (nowMs - (post.createdAt ?? nowMs)) / 3600000.0;
    final freshness = exp(-ageHours / 168.0);

    // Match pays
    final paysMatch = countryCode.isNotEmpty && post.isAvailableForCountry(countryCode) ? 1.0 : 0.0;

    // Boost nouveau créateur (<200 abonnés ET post <30 jours)
    final isNewCreator = (post.user?.abonnes ?? 999) < 200 && ageHours < 720;
    final newBoost = isNewCreator ? 1.0 : 0.0;

    // Boost ultra-frais : post < 48h → exposition maximale pour ne pas se perdre
    final ultraFreshBoost = ageHours < 48 ? (1.0 - ageHours / 48.0) : 0.0;

    // Viralité (interactions / vues)
    final vues = (post.vues ?? 0).toDouble();
    final interactions = ((post.likes ?? 0) + (post.comments ?? 0) + (post.partage ?? 0)).toDouble();
    final virality = vues > 10 ? (interactions / vues).clamp(0.0, 1.0) : 0.0;

    // Poids total = 1.00
    return (engagement * 0.30 +
        freshness * 0.20 +
        paysMatch * 0.20 +
        newBoost * 0.15 +
        ultraFreshBoost * 0.10 +
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

  /// Tier 2 — posts dont les intérêts (postInterests) matchent ceux de l'user.
  /// Index requis : Posts / postInterests (ARRAY_CONTAINS) + created_at (DESC).
  /// Tous les autres filtres (statut, isAdvertisement, pays) sont faits client-side
  /// pour ne nécessiter qu'un seul index composite simple.
  Future<List<Post>> fetchInterestPosts(
    List<String> interests,
    Set<String> excluded, {
    String? countryCode,
    int limit = 20,
    String? tabbarType,
  }) async {
    if (interests.isEmpty) return [];
    try {
      final tags = interests.take(10).toList();
      Query<Map<String, dynamic>> q = _db
          .collection('Posts')
          .where('postInterests', arrayContainsAny: tags);
      if (tabbarType != null) q = q.where('typeTabbar', isEqualTo: tabbarType);
      final snap = await q
          .orderBy('created_at', descending: true)
          .limit(limit * 4)
          .get();

      final result = <Post>[];
      for (final doc in snap.docs) {
        try {
          final post = Post.fromJson(doc.data());
          post.id = doc.id;
          if (post.id == null || excluded.contains(post.id)) continue;
          if (post.isAdvertisement == true) continue;
          if (post.status != null && post.status != 'VALIDE') continue;
          if (countryCode != null && countryCode.isNotEmpty) {
            final ok = post.availableCountries.isEmpty ||
                post.availableCountries.contains('ALL') ||
                post.availableCountries.contains(countryCode);
            if (!ok) continue;
          }
          result.add(post);
          if (result.length >= limit) break;
        } catch (_) {}
      }
      return result;
    } catch (e) {
      printVm('⚠️ [FeedRepository] fetchInterestPosts: $e');
      return [];
    }
  }

  /// Tier 1 — posts non vus des abonnements.
  /// [unreadMap] = {postId: createdAtMs} depuis UserData.unreadPosts.
  /// Retourne les [limit] posts les plus récents, en excluant [excluded].
  Future<List<Post>> fetchUnreadSubscriptionPosts(
    Map<String, int> unreadMap,
    Set<String> excluded, {
    int limit = 25,
    String? tabbarType,
  }) async {
    if (unreadMap.isEmpty) return [];
    // Trier par timestamp desc, prendre les N plus récents
    final sorted = unreadMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final ids = sorted
        .where((e) => !excluded.contains(e.key))
        .take(limit)
        .map((e) => e.key)
        .toList();
    if (ids.isEmpty) return [];
    return loadPostsByIds(ids, tabbarType: tabbarType);
  }
}
