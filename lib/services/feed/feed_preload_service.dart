import 'package:afrotok/services/api/home_feed_api.dart';
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

      // Niveau 1 du serveur : publications non vues des abonnements (créateurs et canaux suivis), déjà filtrées côté serveur.
      final page = await HomeFeedApi.discover(tier: 1, limit: 40);
      final results = [
        page.posts.where((p) => !viewedSet.contains(p.id) && _passesCountryFilter(p, userCountry)).toList(),
        <Post>[],
      ];

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

  /// Filtre pays : le post doit cibler le pays de l'utilisateur ou tous les pays.
  bool _passesCountryFilter(Post post, String? userCountry) {
    if (userCountry == null) return true;
    if (post.availableCountries.isEmpty) return true;
    if (post.availableCountries.contains('ALL')) return true;
    return post.availableCountries.contains(userCountry);
  }
}
