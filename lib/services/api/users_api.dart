import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart';

/// Accès à l'API pour le module « utilisateurs » (profil, abonnements, amis, invitations, blocages, clés de chiffrement, série).
/// Aucun retour à Firebase : en cas d'erreur, l'écran affiche le message et propose « Réessayer ».
class UsersApi {
  UsersApi._();

  static ApiClient get _c => ApiGateway.instance.client;

  static Map<String, dynamic> _map(dynamic r) => Map<String, dynamic>.from(ApiClient.data(r) as Map);
  static List<Map<String, dynamic>> _list(dynamic r) => ((r is Map ? r['data'] : r) as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  /// Message en français prêt à afficher (l'API renvoie déjà un texte français).
  static String message(Object e, {String fallback = 'Une erreur est survenue. Réessaie.'}) {
    if (e is ApiException) {
      if (e.isNetwork) return 'Connexion impossible. Vérifie ta connexion puis réessaie.';
      return e.message.isNotEmpty ? e.message : fallback;
    }
    return fallback;
  }

  // ── Profil ──
  /// Profil complet de la personne connectée + soldes, abonnements, non lus, série, pubs, rôle (un seul appel).
  static Future<Map<String, dynamic>> bootstrap() async => _map(await _c.get('/bootstrap'));

  static Future<Map<String, dynamic>> me() async => _map(await _c.get('/me'));

  /// Création du profil à la première connexion (idempotente).
  static Future<Map<String, dynamic>> register({required String username, String? displayName, String? countryCode, String? language}) async =>
      _map(await _c.post('/me/register', body: {'username': username, if (displayName != null) 'display_name': displayName, if (countryCode != null) 'country_code': countryCode, if (language != null) 'language': language}));

  /// Champs acceptés : display_name, avatar_url, country_code, language, phone, bio, gender, city.
  static Future<Map<String, dynamic>> updateMe(Map<String, dynamic> fields) async => _map(await _c.patch('/me', body: fields));

  static Future<void> updateInterests(List<String> interests) => _c.put('/me/interests', body: {'interests': interests});

  static Future<void> updateNotificationPreferences({bool? reminders, bool? activity, bool? news}) =>
      _c.put('/me/notification-preferences', body: {if (reminders != null) 'reminders': reminders, if (activity != null) 'activity': activity, if (news != null) 'news': news});

  static Future<void> setPersonalization(bool enabled) => _c.put('/me/personalization', body: {'enabled': enabled});

  static Future<void> registerDevice({required String fcmToken, String? platform, int? timezoneOffsetMin, String? language}) =>
      _c.put('/me/devices', body: {'fcm_token': fcmToken, if (platform != null) 'platform': platform, if (timezoneOffsetMin != null) 'timezone_offset_min': timezoneOffsetMin, if (language != null) 'language': language});

  static Future<void> deleteDevice(String fcmToken) => _c.delete('/me/devices/${Uri.encodeComponent(fcmToken)}');

  /// Profil PUBLIC d'une autre personne (GET /users/{id}) : route absente de l'API au 31/10 → voir lacunes_api_utilisateurs.md.
  static Future<Map<String, dynamic>> publicProfile(String userId) async => _map(await _c.get('/users/$userId'));

  // ── Abonnements ──
  /// Retourne true si l'abonnement existait déjà.
  static Future<bool> follow(String userId) async => _map(await _c.post('/users/$userId/follow'))['already'] == true;

  static Future<void> unfollow(String userId) => _c.delete('/users/$userId/follow');

  /// Page d'abonnés : {data: [...], next_cursor}.
  static Future<({List<Map<String, dynamic>> items, String? next})> followers(String userId, {String? cursor, int limit = 30}) async {
    final r = await _c.get('/users/$userId/followers', query: {'limit': limit, if (cursor != null) 'cursor': cursor}) as Map;
    return (items: _list(r), next: r['next_cursor'] as String?);
  }

  static Future<({List<Map<String, dynamic>> items, String? next})> following(String userId, {String? cursor, int limit = 30}) async {
    final r = await _c.get('/users/$userId/following', query: {'limit': limit, if (cursor != null) 'cursor': cursor}) as Map;
    return (items: _list(r), next: r['next_cursor'] as String?);
  }

  // ── Blocages ──
  static Future<List<Map<String, dynamic>>> blocks() async => _list(await _c.get('/blocks'));

  static Future<void> block(String userId, {String? source, String? postId}) =>
      _c.put('/blocks/$userId', body: {if (source != null) 'source': source, if (postId != null) 'post_id': postId});

  static Future<void> unblock(String userId) => _c.delete('/blocks/$userId');

  // ── Amis et invitations ──
  static Future<({List<Map<String, dynamic>> items, String? next})> friends({String? cursor, int limit = 50}) async {
    final r = await _c.get('/friends', query: {'limit': limit, if (cursor != null) 'cursor': cursor}) as Map;
    return (items: _list(r), next: r['next_cursor'] as String?);
  }

  static Future<void> unfriend(String userId) => _c.delete('/friends/$userId');

  /// [direction] : 'received' ou 'sent' ; [status] : pending, accepted, refused, cancelled.
  static Future<({List<Map<String, dynamic>> items, String? next})> invitations({String direction = 'received', String status = 'pending', String? cursor, int limit = 50}) async {
    final r = await _c.get('/invitations', query: {'direction': direction, 'status': status, 'limit': limit, if (cursor != null) 'cursor': cursor}) as Map;
    return (items: _list(r), next: r['next_cursor'] as String?);
  }

  /// Envoie une invitation. Retourne {status: sent|friends|accepted…}. Erreurs : cooldown, limit, blocked…
  static Future<Map<String, dynamic>> invite(String receiverId, {String? message}) async =>
      _map(await _c.post('/invitations', body: {'receiver_id': receiverId, if (message != null && message.isNotEmpty) 'message': message}));

  static Future<void> acceptInvitation(String id) => _c.post('/invitations/$id/accept');
  static Future<void> refuseInvitation(String id) => _c.post('/invitations/$id/refuse');
  static Future<void> cancelInvitation(String id) => _c.delete('/invitations/$id');

  // ── Série de commentaires ──
  static Future<Map<String, dynamic>> streak() async => _map(await _c.get('/streak'));
  static Future<List<Map<String, dynamic>>> streakLeaderboard() async => _list(await _c.get('/streak/leaderboard'));

  // ── Annuaire des clés de chiffrement ──
  /// Publie MA clé publique (base64, 32 octets).
  static Future<Map<String, dynamic>> publishKey(String publicKeyB64) async => _map(await _c.put('/me/keys', body: {'public_key': publicKeyB64, 'algorithm': 'x25519'}));

  /// Clé publique d'une personne (null si elle n'en a pas encore : 404).
  static Future<Map<String, dynamic>?> userKey(String userId) async {
    try {
      return _map(await _c.get('/users/$userId/key'));
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> userKeys(List<String> ids) async => _list(await _c.post('/users/keys', body: {'user_ids': ids}));

  // ── Portefeuille et gains (lecture) ──
  static Future<Map<String, dynamic>> wallet() async => _map(await _c.get('/wallet'));

  static Future<({List<Map<String, dynamic>> items, String? next})> transactions({String? cursor, int limit = 30}) async {
    final r = await _c.get('/wallet/transactions', query: {'limit': limit, if (cursor != null) 'cursor': cursor}) as Map;
    return (items: _list(r), next: r['next_cursor'] as String?);
  }

  static Future<Map<String, dynamic>> viewEarnings() async => _map(await _c.get('/wallet/earnings/views'));

  /// Convertit des gains en pièces (clé d'idempotence conservée par l'écran tant que la personne n'a pas confirmé ou annulé).
  static Future<Map<String, dynamic>> convert(Map<String, dynamic> body, {required String idempotencyKey}) async =>
      _map(await _c.pay('/wallet/convert', body: body, idempotencyKey: idempotencyKey));

  static Future<Map<String, dynamic>> cashViews({required String idempotencyKey}) async => _map(await _c.pay('/wallet/earnings/views/cash', idempotencyKey: idempotencyKey));

  // ── Routes prévues mais ABSENTES de l'API au 31/10/2026 (voir lacunes_api_utilisateurs.md) ──
  /// Recherche de personnes par pseudo. Route souhaitée : GET /users/search?q=
  static Future<List<Map<String, dynamic>>> searchUsers(String q, {int limit = 30}) async => _list(await _c.get('/users/search', query: {'q': q, 'limit': limit}));

  /// État de la règle d'inactivité (20 jours) : {blocked, cost, days_inactive}. Route souhaitée : GET /me/publish-status
  static Future<Map<String, dynamic>> publishStatus() async => _map(await _c.get('/me/publish-status'));

  /// Déblocage du compte contre des pièces. Route souhaitée : POST /me/unlock
  static Future<Map<String, dynamic>> unlockAccount({required String idempotencyKey}) async => _map(await _c.pay('/me/unlock', idempotencyKey: idempotencyKey));

  /// Demande de suppression du compte (J+15). Route souhaitée : POST /me/deletion ; annulation : DELETE /me/deletion
  static Future<Map<String, dynamic>> requestDeletion({bool acceptLoss = false}) async => _map(await _c.post('/me/deletion', body: {'accept_loss': acceptLoss}));
  static Future<void> cancelDeletion() => _c.delete('/me/deletion');

  /// Publications d'une personne. Route souhaitée : GET /users/{id}/posts (curseur)
  static Future<({List<Map<String, dynamic>> items, String? next})> userPosts(String userId, {String? cursor, int limit = 20, bool? ads, String? dataType}) async {
    final r = await _c.get('/users/$userId/posts', query: {'limit': limit, if (cursor != null) 'cursor': cursor, if (ads != null) 'ads': ads ? 1 : 0, if (dataType != null) 'data_type': dataType}) as Map;
    return (items: _list(r), next: r['next_cursor'] as String?);
  }

  // ── Listes de personnes (routes absentes de l'API au 31/10 : voir lacunes_api_utilisateurs.md) ──
  /// Suggestions de profils à découvrir. Route souhaitée : GET /users/suggestions?limit=
  static Future<List<Map<String, dynamic>>> suggestions({int limit = 20}) async => _list(await _c.get('/users/suggestions', query: {'limit': limit}));

  /// Classement des créateurs les plus actifs. Route souhaitée : GET /users/top?limit=
  static Future<List<Map<String, dynamic>>> topUsers({int limit = 10}) async => _list(await _c.get('/users/top', query: {'limit': limit}));

  /// Profils de plusieurs personnes (50 au plus). Route souhaitée : POST /users/lookup {ids}.
  /// Tant que la route manque (404), repli sur un profil public par personne (toujours l'API, jamais Firebase).
  static Future<List<Map<String, dynamic>>> lookup(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      return _list(await _c.post('/users/lookup', body: {'ids': ids.take(50).toList()}));
    } on ApiException catch (e) {
      if (e.status != 404 && e.status != 405) rethrow;
      final res = await Future.wait(ids.take(50).map((id) async {
        try {
          return await publicProfile(id);
        } catch (_) {
          return null;
        }
      }));
      return res.whereType<Map<String, dynamic>>().toList();
    }
  }

  /// Réglages de confidentialité (mode fantôme, dernière connexion, accusés de lecture, verrou biométrique). Route souhaitée : GET/PUT /me/privacy
  static Future<Map<String, dynamic>> privacy() async => _map(await _c.get('/me/privacy'));
  static Future<void> savePrivacy(Map<String, dynamic> fields) => _c.put('/me/privacy', body: fields);

  /// Droits d'équipe de la personne connectée (remplace la lecture de TeamMembers).
  static Future<Map<String, dynamic>> capabilities() async => _map(await _c.get('/me/capabilities'));

  /// Transactions d'une AUTRE personne (administration). Route souhaitée : GET /admin/users/{id}/transactions
  static Future<({List<Map<String, dynamic>> items, String? next})> adminUserTransactions(String userId, {String? cursor, int limit = 100}) async {
    final r = await _c.get('/admin/users/$userId/transactions', query: {'limit': limit, if (cursor != null) 'cursor': cursor}) as Map;
    return (items: _list(r), next: r['next_cursor'] as String?);
  }

  /// Signalement d'un compte. Route souhaitée : POST /users/{id}/report {reason}
  static Future<void> reportUser(String userId, String reason) => _c.post('/users/$userId/report', body: {'reason': reason});

  /// Suppression d'une publication (la sienne).
  static Future<void> deletePost(String postId) => _c.delete('/posts/$postId');

  /// Pseudo libre ? Route souhaitée : GET /users/username-available?username=
  static Future<bool> usernameAvailable(String username) async => _map(await _c.get('/users/username-available', query: {'username': username}))['available'] == true;

  /// Administration : toutes les transactions (filtres facultatifs). Route souhaitée : GET /admin/transactions?user_id=&kinds=&cursor=&limit=
  static Future<({List<Map<String, dynamic>> items, String? next})> adminTransactions({String? userId, List<String>? kinds, String? cursor, int limit = 10}) async {
    final r = await _c.get('/admin/transactions', query: {'limit': limit, if (userId != null) 'user_id': userId, if (kinds != null) 'kinds': kinds.join(','), if (cursor != null) 'cursor': cursor}) as Map;
    return (items: _list(r), next: r['next_cursor'] as String?);
  }

  /// Administration : nombre de transactions pour des natures données. Route souhaitée : GET /admin/transactions/count
  static Future<int> adminTransactionsCount({String? userId, List<String>? kinds}) async =>
      ((_map(await _c.get('/admin/transactions/count', query: {if (userId != null) 'user_id': userId, if (kinds != null) 'kinds': kinds.join(',')}))['count']) as num?)?.toInt() ?? 0;

  /// Administration : trouver un compte par e-mail. Route souhaitée : GET /admin/users/by-email?email=
  static Future<Map<String, dynamic>?> adminUserByEmail(String email) async {
    try {
      return _map(await _c.get('/admin/users/by-email', query: {'email': email}));
    } on ApiException catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  // Services des utilisateurs : voir `services_api.dart` (ServicesApi).
}
