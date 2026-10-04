import 'package:cloud_functions/cloud_functions.dart';

/// Abonnements : tout passe par les fonctions serveur (collection `Follows`,
/// compteur `abonnes`, liste `followingIds`). Les clients n'écrivent plus sur le
/// profil du créateur.
class FollowService {
  FollowService._();

  /// Retourne `true` si l'abonnement existait déjà. Lève une exception en cas d'échec.
  static Future<bool> follow(String targetId) async {
    final res = await FirebaseFunctions.instance.httpsCallable('followUser').call({'targetId': targetId});
    return (res.data is Map && res.data['already'] == true);
  }

  static Future<void> unfollow(String targetId) async {
    await FirebaseFunctions.instance.httpsCallable('unfollowUser').call({'targetId': targetId});
  }
}
