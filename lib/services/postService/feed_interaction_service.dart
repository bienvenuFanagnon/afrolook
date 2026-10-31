import 'package:afrotok/models/model_data.dart';

/// Les scores et l'engagement des publications sont calculés par le serveur à chaque j'aime, commentaire, vue ou partage.
/// Ces méthodes sont conservées pour les écrans qui les appellent encore ; elles n'écrivent plus rien.
class FeedInteractionService {
  static Future<void> onPostLiked(Post post, String userId) async {}
  static Future<void> onPostCommented(Post post, String userId) async {}
  static Future<void> onPostShared(Post post, String userId) async {}
  static Future<void> onPostLoved(Post post, String userId) async {}
  static Future<void> updateUniqueViews(Post post, String userId) async {}
}
