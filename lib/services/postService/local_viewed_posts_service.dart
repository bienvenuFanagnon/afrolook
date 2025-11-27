import 'package:shared_preferences/shared_preferences.dart';

class LocalViewedPostsService {
  static const String _viewedPostsKey = 'viewed_posts';
  static const int _maxStoredPosts = 1000; // Éviter trop de stockage
  static const String _lastSeenPostKey = 'last_seen_post'; // 🔥 NOUVEAU

  // 🔥 SAUVEGARDER LE DERNIER POST VU
  static Future<void> updateLastSeenPost(String postId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSeenPostKey, postId);
      print('📍 Dernier post vu mis à jour: $postId');
    } catch (e) {
      print('❌ Erreur sauvegarde dernier post vu: $e');
    }
  }

  // 🔥 RÉCUPÉRER LE DERNIER POST VU
  static Future<String?> getLastSeenPost() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lastSeenPostKey);
    } catch (e) {
      print('❌ Erreur récupération dernier post vu: $e');
      return null;
    }
  }

  // 🔥 MÉTHODE COMBINÉE : MARQUER COMME VU + METTRE À JOUR LE DERNIER
  static Future<void> markPostAsViewedAndUpdateLast(String postId) async {
    try {
      // 1. Sauvegarder dans la liste des posts vus
      await markPostAsViewed(postId);

      // 2. Mettre à jour le dernier post vu
      await updateLastSeenPost(postId);

      print('✅ Post $postId enregistré comme dernier post vu');
    } catch (e) {
      print('❌ Erreur enregistrement complet post $postId: $e');
    }
  }
  // 🔥 SAUVEGARDER UN POST COMME VU
  static Future<void> markPostAsViewed(String postId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final viewedPosts = await getViewedPosts();

      // Ajouter le nouveau post
      if (!viewedPosts.contains(postId)) {
        viewedPosts.add(postId);

        // Limiter la taille (FIFO)
        if (viewedPosts.length > _maxStoredPosts) {
          viewedPosts.removeAt(0); // Retirer le plus ancien
        }

        await prefs.setStringList(_viewedPostsKey, viewedPosts);
        print('✅ Post $postId sauvegardé localement (total: ${viewedPosts.length})');
      }
    } catch (e) {
      print('❌ Erreur sauvegarde locale post $postId: $e');
    }
  }

  // 🔥 RÉCUPÉRER TOUS LES POSTS VUS
  static Future<List<String>> getViewedPosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_viewedPostsKey) ?? [];
    } catch (e) {
      print('❌ Erreur récupération posts vus: $e');
      return [];
    }
  }

  // 🔥 EFFACER L'HISTORIQUE (optionnel)
  static Future<void> clearViewedPosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_viewedPostsKey);
      print('🧹 Historique posts vus effacé');
    } catch (e) {
      print('❌ Erreur effacement historique: $e');
    }
  }

  // 🔥 VERIFIER SI UN POST A ÉTÉ VU
  static Future<bool> isPostViewed(String postId) async {
    final viewedPosts = await getViewedPosts();
    return viewedPosts.contains(postId);
  }
}