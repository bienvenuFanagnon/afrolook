import 'package:afrotok/services/api/users_api.dart';

/// Abonnements : tout passe par l'API (`POST/DELETE /v1/users/{id}/follow`). Les compteurs sont tenus par le serveur.
class FollowService {
  FollowService._();

  /// Retourne `true` si l'abonnement existait déjà. Lève une exception ([ApiException]) en cas d'échec : l'écran affiche le message.
  static Future<bool> follow(String targetId) => UsersApi.follow(targetId);

  static Future<void> unfollow(String targetId) => UsersApi.unfollow(targetId);
}
