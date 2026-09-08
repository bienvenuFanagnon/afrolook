import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/model_data.dart';

/// Service de boost de visibilité pour les nouveaux créateurs.
///
/// Critères éligibilité :
///  - Compte créé il y a moins de [creatorAgeDays] jours (60 jours)
///  - Moins de [followersThreshold] abonnés (20)
///  - Non suivi par l'utilisateur courant
///
/// Variété : le cache stocke jusqu'à 50 créateurs éligibles.
/// Chaque appel à [getBoostPosts] retourne un sous-ensemble shufflé aléatoirement
/// pour ne pas toujours afficher les mêmes.
class DiscoveryBoostService {
  DiscoveryBoostService._();
  static final instance = DiscoveryBoostService._();

  static const int followersThreshold = 20;
  static const int creatorAgeDays = 60;
  static const int injectEvery = 10;
  static const Duration _cacheTtl = Duration(minutes: 20);

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

  /// Retourne un sous-ensemble shufflé des posts boostés (variété à chaque appel).
  List<Post> getBoostPosts({
    required Set<String> followedSet,
    required String currentUserId,
    required String? userCountry,
    int limit = 10,
  }) {
    if (!_cacheValid) {
      preload(
        followedSet: followedSet,
        currentUserId: currentUserId,
        userCountry: userCountry,
      );
    }
    final copy = List<Post>.from(_cachedPosts)..shuffle(Random());
    return copy.take(limit).toList();
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

  /// Posts les mieux scorés de créateurs non suivis.
  /// Utilisé pour remplir les slots 2 & 3 de chaque batch découverte.
  /// Trié par postScore desc : on montre le meilleur contenu, pas le plus récent.
  Future<List<Post>> fetchRegularDiscovery({
    required Set<String> followedSet,
    required String currentUserId,
    required String? userCountry,
    int limit = 18,
  }) async {
    try {
      final snap = await _db
          .collection('Posts')
          .orderBy('postScore', descending: true)
          .limit(limit * 8)
          .get();

      // Un seul post par créateur : celui avec le meilleur score (le premier rencontré)
      final bestByCreator = <String, Post>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final uid = data['user_id'] as String? ?? '';
        if (uid.isEmpty || uid == currentUserId || followedSet.contains(uid)) continue;
        if (bestByCreator.containsKey(uid)) continue;
        final postData = Map<String, dynamic>.from(data);
        postData['id'] = doc.id;
        final post = Post.fromJson(postData);
        if (_passesCountryFilter(post, userCountry)) {
          bestByCreator[uid] = post;
        }
      }

      // Légère randomisation dans le top pour varier les suggestions à chaque ouverture
      final eligible = bestByCreator.values.toList()..shuffle(Random());
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
    int globalLimit = 400,
    int maxPosts = 50,
  }) async {
    final sinceUs = DateTime.now()
        .subtract(const Duration(days: 30))
        .microsecondsSinceEpoch;
    // Seuil 60 jours pour l'ancienneté du compte (en ms, Firestore stocke ms ou µs)
    final creatorSinceMs = DateTime.now()
        .subtract(const Duration(days: creatorAgeDays))
        .millisecondsSinceEpoch;

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

      // 4. Garder seulement les nouveaux petits créateurs :
      //    - < followersThreshold abonnés
      //    - compte créé il y a moins de creatorAgeDays jours
      final eligible = <Post>[];
      for (final user in users) {
        if ((user.abonnes ?? 0) >= followersThreshold) continue;
        if (user.id == null) continue;
        // Filtre ancienneté compte (createdAt en ms)
        final ca = user.createdAt;
        if (ca != null && ca < creatorSinceMs) continue;
        final post = latestByCreator[user.id!];
        if (post != null) eligible.add(post);
      }

      eligible.shuffle(Random());
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
