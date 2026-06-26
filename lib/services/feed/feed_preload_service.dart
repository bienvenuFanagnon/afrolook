import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/model_data.dart';

/// Service de pré-chargement démarré dès la connexion utilisateur.
///
/// Prépare en arrière-plan :
///  • Les posts non vus des following (section "unseenPosts" du feed)
///  • Les posts non vus des canaux suivis
///
/// Architecture scalable (10 000 following+) :
///  1. Si CF hot-set (newPostsByCreator) disponible → query juste ces créateurs
///  2. Sinon → une requête globale Posts filtrée côté client
///
/// Accès : FeedPreloadService.instance (singleton)
class FeedPreloadService {
  FeedPreloadService._();
  static final instance = FeedPreloadService._();

  final _db = FirebaseFirestore.instance;

  List<Post> unseenFollowingPosts = [];
  bool isReady = false;

  /// À appeler au login / splash, avant que HomeConstPost s'ouvre.
  /// [canalIds] : IDs des canaux suivis (optionnel, peut être vide initialement).
  /// [followingIds] : IDs des créateurs que l'utilisateur suit (abonnements réels).
  Future<void> preload(
    UserData me, {
    List<String> canalIds = const [],
    List<String> followingIds = const [],
  }) async {
    isReady = false;
    unseenFollowingPosts = [];

    try {
      final viewedSet = Set<String>.from(me.viewedPostIds ?? []);
      final rawCountry = me.countryData?['countryCode'];
      final userCountry = rawCountry is String ? rawCountry.toUpperCase() : null;

      // Déterminer les IDs à cibler
      final List<String> targetCreatorIds = _getHotCreatorIds(me, followingIds: followingIds);

      final results = await Future.wait<List<Post>>([
        _fetchUnseenCreatorPosts(targetCreatorIds, viewedSet, userCountry),
        _fetchUnseenCanalPosts(canalIds, viewedSet, userCountry),
      ]);

      final all = [...results[0], ...results[1]];
      all.sort((a, b) =>
          ((b.createdAt ?? 0)).compareTo((a.createdAt ?? 0)));
      unseenFollowingPosts = all.take(20).toList();
    } catch (_) {}

    isReady = true;
  }

  /// Vide le cache (ex. après filtre pays changé).
  void clear() {
    unseenFollowingPosts = [];
    isReady = false;
  }

  // ── Privé ─────────────────────────────────────────────────────────────────────

  /// Identifie les créateurs à cibler pour les posts non vus.
  /// Priorité : CF hot-set → me.followingIds → followingIds param.
  List<String> _getHotCreatorIds(UserData me, {List<String> followingIds = const []}) {
    final cfCounts = me.newPostsByCreator ?? {};
    final hotIds = cfCounts.entries
        .where((e) => e.value > 0)
        .map((e) => e.key)
        .toList();

    if (hotIds.isNotEmpty) return hotIds.take(50).toList();

    // CF vide/cassé : préférer me.followingIds (déjà dans le modèle, pas de requête)
    final modelIds = me.followingIds ?? [];
    if (modelIds.isNotEmpty) return modelIds.take(30).toList();

    if (followingIds.isNotEmpty) return followingIds.take(30).toList();
    return [];
  }

  Future<List<Post>> _fetchUnseenCreatorPosts(
    List<String> creatorIds,
    Set<String> viewedSet,
    String? userCountry,
  ) async {
    if (creatorIds.isEmpty) return [];

    final sinceUs = DateTime.now()
        .subtract(const Duration(days: 30))
        .microsecondsSinceEpoch;

    final List<Post> result = [];
    final addedIds = <String>{};

    // Chunks de 30 en parallèle
    final futures = <Future<void>>[];
    for (int i = 0; i < creatorIds.length; i += 30) {
      final chunk = creatorIds.sublist(
          i, (i + 30).clamp(0, creatorIds.length));
      futures.add(() async {
        try {
          final snap = await _db
              .collection('Posts')
              .where('user_id', whereIn: chunk)
              .where('created_at', isGreaterThan: sinceUs)
              .orderBy('created_at', descending: true)
              .limit(50)
              .get();
          for (final doc in snap.docs) {
            if (addedIds.contains(doc.id)) continue;
            if (viewedSet.contains(doc.id)) continue;
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            final post = Post.fromJson(data);
            if (_passesCountryFilter(post, userCountry)) {
              addedIds.add(doc.id);
              result.add(post);
            }
          }
        } catch (_) {}
      }());
    }
    await Future.wait(futures);

    result.sort((a, b) =>
        ((b.createdAt ?? 0)).compareTo((a.createdAt ?? 0)));
    return result.take(15).toList();
  }

  Future<List<Post>> _fetchUnseenCanalPosts(
    List<String> canalIds,
    Set<String> viewedSet,
    String? userCountry,
  ) async {
    if (canalIds.isEmpty) return [];

    final sinceUs = DateTime.now()
        .subtract(const Duration(days: 30))
        .microsecondsSinceEpoch;

    final List<Post> result = [];
    final addedIds = <String>{};

    for (int i = 0; i < canalIds.length; i += 10) {
      final chunk =
          canalIds.sublist(i, (i + 10).clamp(0, canalIds.length));
      try {
        final snap = await _db
            .collection('Posts')
            .where('canal_id', whereIn: chunk)
            .where('createdAt', isGreaterThan: sinceUs)
            .orderBy('createdAt', descending: true)
            .limit(30)
            .get();
        for (final doc in snap.docs) {
          if (addedIds.contains(doc.id)) continue;
          if (viewedSet.contains(doc.id)) continue;
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          final post = Post.fromJson(data);
          if (_passesCountryFilter(post, userCountry)) {
            addedIds.add(doc.id);
            result.add(post);
          }
        }
      } catch (_) {}
    }

    result.sort((a, b) =>
        ((b.createdAt ?? 0)).compareTo((a.createdAt ?? 0)));
    return result.take(5).toList();
  }

  /// Filtre pays : le post doit cibler le pays de l'utilisateur ou tous les pays.
  bool _passesCountryFilter(Post post, String? userCountry) {
    if (userCountry == null) return true;
    if (post.availableCountries.isEmpty) return true;
    if (post.availableCountries.contains('ALL')) return true;
    return post.availableCountries.contains(userCountry);
  }
}
