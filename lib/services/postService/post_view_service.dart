import '../../models/model_data.dart';

/// Les vues et leurs gains sont comptés par le serveur (POST /posts/{id}/view : vue unique par personne,
/// gain seulement si la personne suit l'auteur et que la publication est monétisée).
/// Ce service est conservé pour les écrans qui l'appellent encore ; il n'écrit plus rien.
class PostViewService {
  /// Plus d'écriture côté application : la vue est comptée par l'API (voir `ApiGateway.markViewed`).
  static Future<void> recordAuthorView(Post post, String viewerUserId) async {}

  /// Migration de l'ancien système : sans objet (les vues sont déjà dans l'API).
  static Future<void> migrateUserPostViews(String userId) async {}

  /// Correction de l'ancien système : sans objet.
  static Future<void> fixMonthlyData(String userId) async {}
}
