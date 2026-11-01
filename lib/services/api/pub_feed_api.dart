import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/users_api.dart';
import 'package:afrotok/services/api/users_mapper.dart';

/// Listes de personnes, de discussions et de groupes pour le fil, la recherche et l'accueil (API uniquement, aucun retour à Firebase).
class PubFeedApi {
  PubFeedApi._();

  static ApiClient get _c => ApiGateway.instance.client;

  static String message(Object e) => UsersApi.message(e);

  /// Classement des créateurs (les plus suivis).
  static Future<List<UserData>> topUsers({int limit = 20}) async => (await UsersApi.topUsers(limit: limit)).map(userSummaryFromApi).toList();

  /// Profils à découvrir.
  static Future<List<UserData>> suggestions({int limit = 20}) async => (await UsersApi.suggestions(limit: limit)).map(userSummaryFromApi).toList();

  /// Recherche par pseudo / nom.
  static Future<List<UserData>> search(String q, {int limit = 30}) async => (await UsersApi.searchUsers(q, limit: limit)).map(userSummaryFromApi).toList();

  /// Profil public (null si introuvable).
  static Future<UserData?> profile(String id) async {
    try {
      return userFromApi(await UsersApi.publicProfile(id));
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  /// Profils en lot.
  static Future<List<UserData>> lookup(List<String> ids) async => (await UsersApi.lookup(ids)).map(userSummaryFromApi).toList();

  /// Appel brut de lecture (pour les routes sans méthode dédiée).
  static Future<dynamic> get(String path, {Map<String, dynamic>? query}) => _c.get(path, query: query);

  /// Messages non lus des groupes (`GET /groups/unread-count` -> {data:{unread}}).
  static Future<int> groupsUnread() async {
    final d = ApiClient.data(await _c.get('/groups/unread-count'));
    return d is Map ? (d['unread'] as num?)?.toInt() ?? 0 : 0;
  }
}
