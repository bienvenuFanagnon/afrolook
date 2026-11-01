import 'package:afrotok/services/api/api_identity.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/post_mapper.dart';
import 'dart:math';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:afrotok/services/api/canaux_api.dart';
import 'package:afrotok/services/api/chroniques_api.dart';
import 'package:afrotok/services/api/home_feed_api.dart';
import 'package:afrotok/services/api/posts_api.dart';
import 'package:afrotok/services/api/shop_api.dart';
import 'package:afrotok/services/api/users_api.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/model_data.dart';

import '../../pages/chronique/chroniqueform.dart';

import '../chronique_first_page.dart';
import '../postService/feed_scoring_service.dart';

/// Types de feed disponibles dans l'application.
enum FeedType { home, looks, sport, events, video, vibes }

/// Paramètres d'une requête de feed.
class FeedQuery {
  final FeedType type;
  final String userId;
  final String countryCode;
  final List<String> subscriptionPostIds; // newPostsFromSubscriptions de l'utilisateur
  final Set<String> excludeIds;
  final int targetCount;

  /// Fil « pour vous » : repartir d'une nouvelle lecture (bouton « voir les posts à découvrir », rafraîchir).
  final bool reset;

  const FeedQuery({
    required this.type,
    required this.userId,
    this.countryCode = '',
    this.subscriptionPostIds = const [],
    this.excludeIds = const {},
    this.targetCount = 40,
    this.reset = false,
  });
}

/// Couche d'accès au fil, entièrement basée sur l'API (aucune page ne lit les publications directement).
///
/// Toutes les méthodes restent tolérantes : en cas d'erreur de l'API elles journalisent, mémorisent [lastError] (message en français)
/// et renvoient une liste vide ; l'écran peut afficher [lastError] avec « Réessayer ». Aucun retour à Firebase.
class FeedRepository {
  static final FeedRepository _instance = FeedRepository._();
  factory FeedRepository() => _instance;
  FeedRepository._();

  /// Dernière erreur de l'API (message prêt à afficher) ; null si le dernier appel a réussi.
  String? lastError;

  void _fail(String where, Object e) {
    lastError = UsersApi.message(e);
    printVm('❌ [FeedRepository] $where : $e');
  }

  /// Feed « pour vous » de l'API : un seul fil (abonnements, goûts, découverte, nouveaux créateurs/canaux), toujours des publications NON VUES.
  /// [reset] = nouvelle lecture (ouverture, rafraîchir).
  Future<List<Post>> _apiForYou(Set<String> excluded, int limit, {required bool reset}) async {
    try {
      final rows = await ApiGateway.instance.forYou(limit: limit, reset: reset);
      lastError = null;
      return rows.map(postFromApi).where((p) => p.id != null && !excluded.contains(p.id)).toList();
    } catch (e) {
      _fail('fil « pour vous »', e);
      return <Post>[];
    }
  }

  /// Lit des pages du fil de l'API (niveau [tier]) jusqu'à avoir [limit] publications retenues (4 pages au plus).
  Future<List<Post>> _pages(
    Set<String> excluded,
    int limit, {
    int tier = 3,
    String? category,
    String? country,
    String? mediaType,
    bool Function(Post)? where,
  }) async {
    final out = <Post>[];
    final seen = <String>{...excluded};
    String? cursor;
    try {
      for (var i = 0; i < 4 && out.length < limit; i++) {
        final page = await HomeFeedApi.discover(tier: tier, category: category, country: country, cursor: cursor, limit: 50);
        for (final p in page.posts) {
          if (p.id == null || seen.contains(p.id)) continue;
          if (p.status == 'SUPPRIMER') continue;
          if (mediaType != null && p.dataType != mediaType) continue;
          if (where != null && !where(p)) continue;
          seen.add(p.id!);
          out.add(p);
          if (out.length >= limit) break;
        }
        cursor = page.next;
        if (cursor == null) break;
      }
      lastError = null;
    } catch (e) {
      _fail('pages du fil', e);
    }
    return out;
  }

  // ── POINT D'ENTRÉE PRINCIPAL ─────────────────────────────────────────────────

  /// Charge un batch de posts. Accueil : fil « pour vous » du serveur (le mélange est décidé côté serveur) ; autres types : thème / média.
  Future<List<Post>> fetchFeed(FeedQuery query) async {
    final target = query.targetCount;
    final excluded = Set<String>.from(query.excludeIds);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final results = <Post>[];

    switch (query.type) {
      case FeedType.home:
        return _apiForYou(excluded, target, reset: query.reset);   // pages suivantes (reset = nouvelle lecture)

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

    for (final post in results) {
      post.feedScore = _computeScore(post, nowMs, query.countryCode);
    }
    results.sort((a, b) => (b.feedScore ?? 0).compareTo(a.feedScore ?? 0));
    return results;
  }

  // ── REQUÊTES SPÉCIALISÉES (découverte de l'API) ──────────────────────────────

  /// Posts ouverts au pays donné (optionnellement filtrés par type média ou thème).
  Future<List<Post>> fetchCountryPosts(String countryCode, Set<String> excluded, {int limit = 10, String? mediaType, String? tabbarType}) async {
    if (countryCode.isEmpty) return [];
    return _pages(excluded, limit, country: countryCode, category: tabbarType, mediaType: mediaType);
  }

  /// Posts populaires : le serveur classe déjà la découverte, on prend le début de la liste.
  Future<List<Post>> fetchScorePosts(Set<String> excluded, {int limit = 8}) => _pages(excluded, limit);

  /// Posts récents de créateurs non suivis (découverte).
  Future<List<Post>> fetchDiscoveryPosts(Set<String> followedPostIds, Set<String> excluded, {int limit = 6}) =>
      _pages({...excluded, ...followedPostIds}, limit);

  /// Anciens posts : le serveur ne renvoie que la fenêtre récente (60 jours) ; on garde ceux de plus de 2 semaines.
  Future<List<Post>> fetchResurgencePosts(Set<String> excluded, {int limit = 4}) {
    final cutoff = DateTime.now().subtract(const Duration(days: 14)).millisecondsSinceEpoch;
    return _pages(excluded, limit, where: (p) => (p.createdAt ?? 0) <= cutoff);
  }

  /// Posts d'un thème (LOOKS, SPORT, EVENEMENT…), ceux du pays de la personne en premier.
  Future<List<Post>> fetchByTabbarType(String tabbarType, String countryCode, Set<String> excluded, {int limit = 40}) async {
    final posts = await _pages(excluded, limit, category: tabbarType);
    if (countryCode.isNotEmpty) {
      posts.sort((a, b) => (b.isAvailableForCountry(countryCode) ? 1 : 0).compareTo(a.isAvailableForCountry(countryCode) ? 1 : 0));
    }
    return posts;
  }

  /// Posts d'un type média (VIDEO, AUDIO, IMAGE…).
  Future<List<Post>> fetchByMediaType(String mediaType, String countryCode, Set<String> excluded, {int limit = 40}) =>
      _pages(excluded, limit, mediaType: mediaType);

  /// Posts récents sans filtre pays.
  Future<List<Post>> fetchRecentPosts(Set<String> excluded, {int limit = 20, String? mediaType, String? tabbarType}) =>
      _pages(excluded, limit, mediaType: mediaType, category: tabbarType);

  /// Posts de pays autres que [excludeCountry].
  Future<List<Post>> fetchOtherCountriesPosts(String excludeCountry, Set<String> excluded, {int limit = 10, String? mediaType, String? tabbarType}) =>
      _pages(excluded, limit, mediaType: mediaType, category: tabbarType, where: (p) => p.isAdvertisement != true && !p.availableCountries.contains(excludeCountry));

  /// Charge des posts par leurs identifiants (lectures en parallèle). Le thème [tabbarType], s'il est donné, est appliqué ici.
  Future<List<Post>> loadPostsByIds(List<String> ids, {String? tabbarType}) async {
    if (ids.isEmpty) return [];
    try {
      var posts = await PostsApi.getMany(ids);
      for (final p in posts) {
        p.typeTabbar ??= p.categorie;
      }
      if (tabbarType != null) posts = posts.where((p) => p.typeTabbar == tabbarType || p.categorie == tabbarType).toList();
      lastError = null;
      return posts;
    } catch (e) {
      _fail('chargement par identifiants', e);
      return [];
    }
  }

  // ── CONTENU GLOBAL (partagé par tous les feeds) ──────────────────────────────

  Future<List<Chronique>> fetchChroniques({int limit = 8}) async {
    try {
      final page = await ChroniquesApi.list(limit: limit, myId: ApiIdentity.myId);
      final valid = page.items.where((c) => !c.isExpired).toList();
      ChroniqueFirstPage.save(valid, page.next, hasMore: page.next != null);
      lastError = null;
      return valid;
    } catch (e) {
      _fail('chroniques', e);
      return [];
    }
  }

  Future<List<Canal>> fetchCanaux({int limit = 6}) async {
    try {
      final r = await CanauxApi.list(limit: limit, myId: ApiIdentity.myId);
      lastError = null;
      return r.items;
    } catch (e) {
      _fail('canaux', e);
      return [];
    }
  }

  Future<List<ArticleData>> fetchArticles({int limit = 3}) async {
    try {
      final r = await ShopApi.articles(limit: limit);
      lastError = null;
      return r.items;
    } catch (e) {
      _fail('articles', e);
      return [];
    }
  }

  // ── ABONNEMENTS & BOOST NOUVEAUX POSTS ─────────────────────────────────────

  /// Posts récents (≤ [withinDays] jours) des créateurs suivis (niveau 1 de l'API : publications non vues des abonnements).
  Future<List<Post>> fetchFollowingRecentPosts(List<String> followingIds, Set<String> excluded, {int limit = 10, int withinDays = 7}) async {
    if (followingIds.isEmpty) return [];
    final since = DateTime.now().subtract(Duration(days: withinDays)).millisecondsSinceEpoch;
    final posts = await _pages(excluded, limit * 2, tier: 1, where: (p) => (p.createdAt ?? 0) >= since);
    posts.shuffle();
    return posts.take(limit).toList();
  }

  /// Posts très récents (≤ 48h) avec peu de vues, pour donner de l'exposition aux nouveaux créateurs.
  Future<List<Post>> fetchNewPostsToBoost(Set<String> excluded, {int limit = 5}) async {
    final since = DateTime.now().subtract(const Duration(hours: 48)).millisecondsSinceEpoch;
    final candidates = await _pages(excluded, limit * 4, where: (p) => (p.createdAt ?? 0) >= since);
    candidates.sort((a, b) => (a.vues ?? 0).compareTo(b.vues ?? 0));
    return candidates.take(limit).toList();
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

  /// Tier 2 — posts selon les centres d'intérêt. Sans thème, ils sont déjà dans le feed « pour vous » (liste vide).
  Future<List<Post>> fetchInterestPosts(
    List<String> interests,
    Set<String> excluded, {
    String? countryCode,
    int limit = 20,
    String? tabbarType,
  }) async {
    if (tabbarType == null) return <Post>[];
    return _pages(excluded, limit, category: tabbarType, country: countryCode, where: (p) => p.isAdvertisement != true && (p.status == null || p.status == 'VALIDE'));
  }

  /// Tier 1 — posts non vus des abonnements. Accueil : feed « pour vous » ; avec [tabbarType] : niveau 1 filtré par thème.
  /// [repostMeta] = {postId: {reposterUserId, reposterPseudo, reposterImageUrl}} depuis UserData.repostMeta.
  Future<List<Post>> fetchUnreadSubscriptionPosts(
    Map<String, int> unreadMap,
    Set<String> excluded, {
    int limit = 25,
    String? tabbarType,
    Map<String, Map<String, dynamic>> repostMeta = const {},
  }) async {
    if (tabbarType == null) {
      return _apiForYou(excluded, limit, reset: true);   // première page : abonnements + goûts + découverte + nouveaux créateurs
    }
    final result = await _pages(excluded, limit, tier: 1, category: tabbarType);
    for (final post in result) {
      final meta = repostMeta[post.id];
      if (meta != null) {
        post.isRepost = true;
        post.reposterUserId = meta['reposterUserId'] as String?;
        post.reposterPseudo = meta['reposterPseudo'] as String?;
        post.reposterImageUrl = meta['reposterImageUrl'] as String?;
        post.originalPostId = post.id;
      }
    }
    return result;
  }
}
