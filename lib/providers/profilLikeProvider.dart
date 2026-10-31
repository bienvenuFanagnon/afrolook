// providers/profile_like_provider.dart
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:flutter/foundation.dart';

import '../models/model_data.dart';
import 'authProvider.dart';

class ProfileLike {
  String? id;
  String likedUserId; // Utilisateur qui est liké
  String likerUserId; // Utilisateur qui like
  DateTime createdAt;

  ProfileLike({
    this.id,
    required this.likedUserId,
    required this.likerUserId,
    required this.createdAt,
  });
}

/// J'aime sur un profil (API : PUT/DELETE/GET /v1/users/{id}/like). Ces routes sont à ajouter côté API
/// (voir lacunes_api_utilisateurs.md) ; en cas d'erreur, l'écran affiche le message et propose de réessayer.
class ProfileLikeProvider with ChangeNotifier {
  ApiClient get _c => ApiGateway.instance.client;

  // Like un profil
  Future<void> likeProfile(String likedUserId, String likerUserId) async {
    try {
      await _c.put('/users/$likedUserId/like');
      addPointsForAction(UserAction.likeProfil);
      addPointsForOtherUserAction(likedUserId, UserAction.autre);
    } catch (error) {
      throw Exception('Erreur like profil: $error');
    }
  }

  // Unlike un profil
  Future<void> unlikeProfile(String likedUserId, String likerUserId) async {
    try {
      await _c.delete('/users/$likedUserId/like');
    } catch (error) {
      throw Exception('Erreur unlike profil: $error');
    }
  }

  // Vérifier si l'utilisateur a déjà liké le profil
  Future<bool> hasLikedProfile(String likedUserId, String likerUserId) async {
    try {
      final r = ApiClient.data(await _c.get('/users/$likedUserId/like')) as Map;
      return r['liked'] == true;
    } catch (error) {
      throw Exception('Erreur vérification like: $error');
    }
  }

  // Obtenir le nombre de likes d'un profil
  Future<int> getProfileLikesCount(String userId) async {
    try {
      final r = ApiClient.data(await _c.get('/users/$userId/like')) as Map;
      return (r['count'] as num?)?.toInt() ?? 0;
    } catch (error) {
      throw Exception('Erreur comptage likes: $error');
    }
  }

  // Nombre de likes d'un profil (relu toutes les 30 s ; pas de temps réel côté API)
  Stream<int> getProfileLikesStream(String userId) async* {
    while (true) {
      try {
        yield await getProfileLikesCount(userId);
      } catch (_) {
        yield 0;
      }
      await Future<void>.delayed(const Duration(seconds: 30));
    }
  }
}
