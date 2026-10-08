import 'package:cloud_functions/cloud_functions.dart';

/// Abonnements : tout passe par les fonctions serveur (collection `Follows`,
/// compteur `abonnes`, liste `followingIds`). Les clients n'écrivent plus sur le
/// profil du créateur.
class FollowService {
  FollowService._();

  /// Codes renvoyés quand le serveur est momentanément saturé (quota CPU Cloud Run, démarrage à froid…).
  static const _transient = {'resource-exhausted', 'unavailable', 'deadline-exceeded', 'internal'};

  /// Appelle la fonction avec 2 nouvelles tentatives (1 s puis 2 s) si le serveur est saturé,
  /// pour que l'utilisateur ne voie pas « Erreur technique » lors d'un simple à-coup.
  static Future<HttpsCallableResult> _call(String name, String targetId) async {
    for (var attempt = 0;; attempt++) {
      try {
        return await FirebaseFunctions.instance.httpsCallable(name).call({'targetId': targetId});
      } on FirebaseFunctionsException catch (e) {
        if (attempt >= 2 || !_transient.contains(e.code)) rethrow;
        await Future.delayed(Duration(seconds: attempt + 1));
      }
    }
  }

  /// Retourne `true` si l'abonnement existait déjà. Lève une exception en cas d'échec.
  static Future<bool> follow(String targetId) async {
    final res = await _call('followUser', targetId);
    return (res.data is Map && res.data['already'] == true);
  }

  static Future<void> unfollow(String targetId) async {
    await _call('unfollowUser', targetId);
  }
}
