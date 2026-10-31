import 'dart:typed_data';

import 'package:afrotok/services/api/jeux_api.dart';
import 'package:afrotok/services/api/posts_api.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart';

/// Accès à l'API pour les conversations 1 à 1, les groupes (liste, membres, droits, invitations, clés) et les notifications.
/// Les MESSAGES restent sur Firebase (collections Messages et GroupMessages). Aucun retour à Firebase en cas d'erreur de l'API.
class ChatApi {
  ChatApi._();

  static ApiClient get _c => JeuxApi.client;

  /// Message en français prêt à afficher.
  static String message(Object e, {String fallback = 'Une erreur est survenue. Réessaie.'}) {
    if (e is ApiException) {
      if (e.isNetwork) return 'Connexion impossible. Vérifie ta connexion puis réessaie.';
      return e.message.isNotEmpty ? e.message : fallback;
    }
    return fallback;
  }

  // ── Conversations 1 à 1 ──────────────────────────────────────────────────────────────────────

  /// Page de conversations (la plus récente d'abord). [cursor] : `next` de la page précédente.
  static Future<({List<Map<String, dynamic>> items, String? next})> conversations({String? cursor, int limit = 30}) async {
    final r = await _c.get('/conversations', query: {'limit': limit, if (cursor != null) 'cursor': cursor});
    return (items: JeuxApi.list(r), next: r is Map ? r['next_cursor'] as String? : null);
  }

  /// Ouvre ou crée la conversation avec [userId].
  static Future<Map<String, dynamic>> openConversation(String userId) async => JeuxApi.map(await _c.post('/conversations', body: {'user_id': userId}));

  static Future<int> unreadConversations() async => JeuxApi.asInt(JeuxApi.map(await _c.get('/conversations/unread-count'))['unread']);

  static Future<void> markConversationRead(String id) => _c.post('/conversations/$id/read');

  /// À appeler après chaque message envoyé sur Firebase (aperçu, non lus de l'autre, série, notification). [kind] : text, image, audio, video, file.
  static Future<void> conversationSent(String id, {String kind = 'text'}) => _c.post('/conversations/$id/sent', body: {'kind': kind});

  // ── Groupes ─────────────────────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> groups() async => JeuxApi.list(await _c.get('/groups'));

  static Future<Map<String, dynamic>> group(String id) async => JeuxApi.map(await _c.get('/groups/$id'));

  /// Téléverse une image (JPEG) et retourne l'identifiant d'envoi à fournir à l'API.
  static Future<String> uploadImage(Uint8List bytes, {String contentType = 'image/jpeg'}) => UploadsApi.uploadBytes(bytes, contentType: contentType);

  static Future<Map<String, dynamic>> createGroup({
    required String name,
    String? description,
    bool isPrivate = false,
    int priceCoins = 0,
    String? imageUploadId,
  }) async =>
      JeuxApi.map(await _c.post('/groups', body: {
        'name': name,
        if (description != null && description.isNotEmpty) 'description': description,
        'is_private': isPrivate,
        'price_coins': priceCoins,
        if (imageUploadId != null) 'image_upload_id': imageUploadId,
      }));

  /// Modifie un groupe (champs de l'API : name, description, is_private, price_coins, is_read_only, default_can_write, default_can_share,
  /// allow_external_links, allow_hidden_msgs, ephemeral_seconds, image_upload_id).
  static Future<Map<String, dynamic>> updateGroup(String id, Map<String, dynamic> fields) async => JeuxApi.map(await _c.patch('/groups/$id', body: fields));

  static Future<void> deleteGroup(String id) => _c.delete('/groups/$id');

  static Future<({List<Map<String, dynamic>> items, String? next})> members(String id, {String? cursor, int limit = 50}) async {
    final r = await _c.get('/groups/$id/members', query: {'limit': limit, if (cursor != null) 'cursor': cursor});
    return (items: JeuxApi.list(r), next: r is Map ? r['next_cursor'] as String? : null);
  }

  static Future<void> addMember(String groupId, String userId) => _c.post('/groups/$groupId/members', body: {'user_id': userId});

  /// Rôle (admin/member) et droits d'un membre (can_write, can_share : true, false ou null = valeur par défaut du groupe).
  static Future<void> updateMember(String groupId, String userId, Map<String, dynamic> fields) => _c.patch('/groups/$groupId/members/$userId', body: fields);

  static Future<void> removeMember(String groupId, String userId) => _c.delete('/groups/$groupId/members/$userId');

  static Future<void> leaveGroup(String groupId) => _c.delete('/groups/$groupId/membership');

  /// Nouveau code d'invitation (administrateurs).
  static Future<Map<String, dynamic>> regenerateInvitationCode(String groupId) async => JeuxApi.map(await _c.post('/groups/$groupId/invitation-code'));

  static Future<Map<String, dynamic>> invitationPreview(String code) async => JeuxApi.map(await _c.get('/groups/invitation/$code'));

  static Future<Map<String, dynamic>> joinByCode(String code) async => JeuxApi.map(await _c.post('/groups/invitation/$code/join'));

  /// Mes enveloppes de clé de groupe (chiffrement de bout en bout des groupes : voir fiche 34).
  static Future<Map<String, dynamic>> groupKeys(String groupId) async => JeuxApi.map(await _c.get('/groups/$groupId/keys'));

  static Future<Map<String, dynamic>> postGroupKeys(String groupId, int epoch, List<Map<String, dynamic>> envelopes) async =>
      JeuxApi.map(await _c.post('/groups/$groupId/keys', body: {'epoch': epoch, 'envelopes': envelopes}));

  // ── Notifications ───────────────────────────────────────────────────────────────────────────

  static Future<({List<Map<String, dynamic>> items, String? next})> notifications({String? cursor, int limit = 60, bool unreadOnly = false}) async {
    final r = await _c.get('/notifications', query: {'limit': limit, if (cursor != null) 'cursor': cursor, if (unreadOnly) 'unread': 1});
    return (items: JeuxApi.list(r), next: r is Map ? r['next_cursor'] as String? : null);
  }

  static Future<int> unreadNotifications() async => JeuxApi.asInt(JeuxApi.map(await _c.get('/notifications/unread-count'))['count']);

  static Future<void> markNotificationRead(String id) => _c.post('/notifications/$id/read');

  static Future<void> markAllNotificationsRead() => _c.post('/notifications/read-all');

  static Future<void> deleteNotification(String id) => _c.delete('/notifications/$id');
}

/// Accès à l'API pour les lives (registre, accès payant, jetons Agora, cadeaux). Le flux vidéo reste chez Agora.
class LivesApi {
  LivesApi._();

  static ApiClient get _c => JeuxApi.client;

  static Future<({List<Map<String, dynamic>> items, String? next})> list({String status = 'live', String? hostId, String? cursor, int limit = 20}) async {
    final r = await _c.get('/lives', query: {'status': status, 'limit': limit, if (hostId != null) 'host_id': hostId, if (cursor != null) 'cursor': cursor});
    return (items: JeuxApi.list(r), next: r is Map ? r['next_cursor'] as String? : null);
  }

  static Future<Map<String, dynamic>> get(String id) async => JeuxApi.map(await _c.get('/lives/$id'));

  static Future<Map<String, dynamic>> start({
    required String title,
    String? coverUploadId,
    int? durationMinutes,
    bool isPaid = false,
    int feeCoins = 0,
    int freeTrialMinutes = 0,
    Map<String, dynamic>? options,
  }) async =>
      JeuxApi.map(await _c.post('/lives', body: {
        'title': title,
        if (coverUploadId != null) 'cover_upload_id': coverUploadId,
        if (durationMinutes != null) 'duration_minutes': durationMinutes,
        'is_paid': isPaid,
        'participation_fee_coins': feeCoins,
        'free_trial_minutes': freeTrialMinutes,
        if (options != null) 'options': options,
      }));

  static Future<void> heartbeat(String id, {int? viewers, int? likes, int? shares}) => _c.post('/lives/$id/heartbeat', body: {
        if (viewers != null) 'viewer_count': viewers,
        if (likes != null) 'likes_count': likes,
        if (shares != null) 'shares_count': shares,
      });

  static Future<Map<String, dynamic>> update(String id, Map<String, dynamic> fields) async => JeuxApi.map(await _c.patch('/lives/$id', body: fields));

  static Future<void> end(String id) => _c.post('/lives/$id/end');

  /// Jeton Agora : [uid] est l'identifiant numérique Agora du participant ; [role] « host » ou « audience ».
  static Future<Map<String, dynamic>> token(String id, {required int uid, String role = 'audience'}) async =>
      JeuxApi.map(await _c.post('/lives/$id/token', body: {'uid': uid, 'role': role}));

  /// Cadeau en live (argent : clé d'idempotence conservée à chaque tentative).
  static Future<Map<String, dynamic>> gift(String id, {required int coins, String? icon, String? label}) async =>
      JeuxApi.map(await _c.pay('/lives/$id/gifts', body: {'coins': coins, if (icon != null) 'icon': icon, if (label != null) 'label': label}));

  static Future<List<Map<String, dynamic>>> leaderboard(String id) async => JeuxApi.list(await _c.get('/lives/$id/leaderboard'));
}
