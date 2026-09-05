import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/model_data.dart';

/// Service de boost de visibilité pour les nouveaux créateurs (< 200 abonnés).
///
/// Stratégie :
///  1. Query globale des posts récents (< 7 jours)
///  2. Filtre client : exclure les créateurs déjà suivis, appliquer filtre pays
///  3. Fetch les users → garder seulement ceux avec < [followersThreshold] abonnés
///  4. Cache 1h pour ne pas requêter à chaque scroll
///
/// Injection dans le feed : 1 post boosté toutes les [injectEvery] posts normaux.
class DiscoveryBoostService {
  DiscoveryBoostService._();
  static final instance = DiscoveryBoostService._();

  static const int followersThreshold = 20;
  static const int injectEvery = 10;
  static const Duration _cacheTtl = Duration(hours: 1);

  final _db = FirebaseFirestore.instance;

  List<Post> _cachedPosts = [];
  DateTime? _cacheTime;
  final _discoveryPostIds = <String>{};

  /// IDs des posts injectés via boost (pour afficher le badge).
  Set<String> get discoveryPostIds => _discoveryPostIds;

  /// Ajoute des IDs externes à l'ensemble (posts réguliers injectés depuis HomeConstPost).
  void addDiscoveryIds(Iterable<String> ids) => _discoveryPostIds.addAll(ids);

  bool get _cacheValid =>
      _cacheTime != null &&
      DateTime.now().difference(_cacheTime!) < _cacheTtl &&
      _cachedPosts.isNotEmpty;

  /// Charge les posts de nouveaux créateurs éligibles.
  Future<void> preload({
    required Set<String> followedSet,
    required String currentUserId,
    required String? userCountry,
  }) async {
    if (_cacheValid) return;

    _cachedPosts = await _fetchDiscoveryPosts(
      followedSet: followedSet,
      currentUserId: currentUserId,
      userCountry: userCountry,
    );
    _cacheTime = DateTime.now();
  }

  /// Retourne les posts boostés (depuis le cache si valide).
  List<Post> getBoostPosts({
    required Set<String> followedSet,
    required String currentUserId,
    required String? userCountry,
  }) {
    if (!_cacheValid) {
      // Lance en arrière-plan si cache expiré
      preload(
        followedSet: followedSet,
        currentUserId: currentUserId,
        userCountry: userCountry,
      );
    }
    return List.from(_cachedPosts);
  }

  /// Injecte les posts boostés dans la liste de posts du feed.
  /// Retourne la liste finale mélangée et met à jour [discoveryPostIds].
  List<Post> injectIntoFeed(List<Post> regularPosts, List<Post> boostPosts) {
    if (boostPosts.isEmpty) return regularPosts;

    final result = <Post>[];
    int boostIndex = 0;

    for (int i = 0; i < regularPosts.length; i++) {
      result.add(regularPosts[i]);

      // Toutes les [injectEvery] posts : injecter 1 post boosté
      if ((i + 1) % injectEvery == 0 && boostIndex < boostPosts.length) {
        final boostedPost = boostPosts[boostIndex++];
        if (boostedPost.id != null) {
          _discoveryPostIds.add(boostedPost.id!);
        }
        result.add(boostedPost);
      }
    }

    return result;
  }

  /// Invalide le cache (ex. si l'utilisateur s'abonne à un créateur boosté).
  void invalidateCache() {
    _cacheTime = null;
    _cachedPosts = [];
  }

  /// Retire un post des IDs boostés (ex. après s'être abonné au créateur).
  void markCreatorGraduated(String creatorId) {
    _cachedPosts.removeWhere((p) => p.user_id == creatorId);
    _discoveryPostIds
        .removeWhere((id) => _cachedPosts.every((p) => p.id != id));
  }

  /// Posts récents de créateurs non suivis, sans filtre de taille (tous créateurs).
  /// Utilisé pour remplir les slots 2 & 3 de chaque batch découverte.
  Future<List<Post>> fetchRegularDiscovery({
    required Set<String> followedSet,
    required String currentUserId,
    required String? userCountry,
    int limit = 18,
  }) async {
    final sinceUs = DateTime.now()
        .subtract(const Duration(days: 30))
        .microsecondsSinceEpoch;
    try {
      final snap = await _db
          .collection('Posts')
          .where('created_at', isGreaterThan: sinceUs)
          .orderBy('created_at', descending: true)
          .limit(limit * 8)
          .get();

      final latestByCreator = <String, Post>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final uid = data['user_id'] as String? ?? '';
        if (uid.isEmpty || uid == currentUserId || followedSet.contains(uid)) continue;
        if (latestByCreator.containsKey(uid)) continue;
        final postData = Map<String, dynamic>.from(data);
        postData['id'] = doc.id;
        final post = Post.fromJson(postData);
        if (_passesCountryFilter(post, userCountry)) {
          latestByCreator[uid] = post;
        }
      }

      final eligible = latestByCreator.values.toList()..shuffle();
      return eligible.take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Privé ─────────────────────────────────────────────────────────────────────

  Future<List<Post>> _fetchDiscoveryPosts({
    required Set<String> followedSet,
    required String currentUserId,
    required String? userCountry,
    int globalLimit = 300,
    int maxPosts = 30,
  }) async {
    final sinceUs = DateTime.now()
        .subtract(const Duration(days: 7))
        .microsecondsSinceEpoch;

    try {
      // 1. Posts récents (< 7 jours), un seul appel Firestore
      final snap = await _db
          .collection('Posts')
          .where('created_at', isGreaterThan: sinceUs)
          .orderBy('created_at', descending: true)
          .limit(globalLimit)
          .get();

      // 2. Grouper par créateur — garder seulement le post le plus récent
      //    Exclure : suivis, soi-même, posts vus
      final Map<String, Post> latestByCreator = {};
      for (final doc in snap.docs) {
        final data = doc.data();
        final uid = data['user_id'] as String? ?? '';
        if (uid.isEmpty || uid == currentUserId || followedSet.contains(uid)) {
          continue;
        }
        if (latestByCreator.containsKey(uid)) continue;

        final postData = Map<String, dynamic>.from(data);
        postData['id'] = doc.id;
        final post = Post.fromJson(postData);

        if (_passesCountryFilter(post, userCountry)) {
          latestByCreator[uid] = post;
        }
      }

      if (latestByCreator.isEmpty) return [];

      // 3. Fetch les users pour vérifier le nombre d'abonnés
      final creatorIds = latestByCreator.keys.toList();
      final users = await _fetchUsers(creatorIds);

      // 4. Garder seulement les petits créateurs (< followersThreshold abonnés)
      final eligible = <Post>[];
      for (final user in users) {
        if ((user.abonnes ?? 0) >= followersThreshold) continue;
        if (user.id == null) continue;
        final post = latestByCreator[user.id!];
        if (post != null) eligible.add(post);
      }

      // Mélanger pour la variété et limiter
      eligible.shuffle();
      return eligible.take(maxPosts).toList();
    } catch (_) {
      return [];
    }
  }

  bool _passesCountryFilter(Post post, String? userCountry) {
    if (userCountry == null) return true;
    if (post.availableCountries.isEmpty) return true;
    if (post.availableCountries.contains('ALL')) return true;
    return post.availableCountries.contains(userCountry);
  }

  Future<List<UserData>> _fetchUsers(List<String> ids) async {
    final result = <UserData>[];
    for (int i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, (i + 10).clamp(0, ids.length));
      try {
        final snap = await _db
            .collection('Users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final d in snap.docs) {
          final data = Map<String, dynamic>.from(d.data());
          data['id'] = d.id;
          result.add(UserData.fromJson(data));
        }
      } catch (_) {}
    }
    return result;
  }
}
