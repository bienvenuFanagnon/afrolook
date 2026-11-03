import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/api/users_api.dart';

/// Abonnements : tout passe par l'API (`POST/DELETE /v1/users/{id}/follow`). Les compteurs sont tenus par le serveur.
class FollowService {
  FollowService._();

  /// Retourne `true` si l'abonnement existait déjà. Lève une exception ([ApiException]) en cas d'échec : l'écran affiche le message.
  static Future<bool> follow(String targetId) => UsersApi.follow(targetId);

  static Future<void> unfollow(String targetId) => UsersApi.unfollow(targetId);

  /// Point de contrôle unique : la personne connectée [me] suit-elle déjà [creator] ?
  /// Sa propre liste d'abonnements (`followingIds`, chargée depuis l'API) fait foi ; la liste d'abonnés du créateur
  /// (`userAbonnesIds`) n'est plus qu'un secours, car avec l'API elle est souvent vide ou partielle (le bouton « Suivre » restait alors affiché).
  static bool isFollowing(UserData? me, UserData? creator) {
    final creatorId = creator?.id;
    final myId = me?.id;
    if (creatorId == null || myId == null) return false;
    if (me!.followingIds?.contains(creatorId) ?? false) return true;
    return creator!.userAbonnesIds?.contains(myId) ?? false;
  }

  /// Vrai quand on sait déjà dire si la personne suit ou non (sinon on masque le bouton plutôt que d'afficher « Suivre » à tort).
  static bool isKnown(UserData? me, UserData? creator) => (me?.followingIds != null) || (creator?.userAbonnesIds != null);
}
