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

  /// Ouvre ou crée la conversation avec [userId]. En cas de blocage (dans un sens ou l'autre) la conversation est quand même renvoyée,
  /// avec `blocked` (vrai) et `blocked_by_me` (vrai seulement pour la personne qui a bloqué) : l'envoi est alors refusé (403 `blocked`).
  static Future<Map<String, dynamic>> openConversation(String userId) async => JeuxApi.map(await _c.post('/conversations', body: {'user_id': userId}));

  static Future<int> unreadConversations() async => JeuxApi.asInt(JeuxApi.map(await _c.get('/conversations/unread-count'))['unread']);

  static Future<void> markConversationRead(String id) => _c.post('/conversations/$id/read');

  /// À appeler après chaque message envoyé sur Firebase (aperçu, non lus de l'autre, série, notification). [kind] : text, image, audio, video, file.
  static Future<void> conversationSent(String id, {String kind = 'text'}) => _c.post('/conversations/$id/sent', body: {'kind': kind});

  /// Signale un message reçu. Le texte est chiffré : l'API ne garde que l'identifiant du message ([messageId], celui du document Firebase) et le motif.
  static Future<void> reportMessage(String conversationId, String messageId, {String? reason}) =>
      _c.post('/conversations/$conversationId/reports', body: {'message_id': messageId, if (reason != null && reason.isNotEmpty) 'reason': reason});

  // ── Groupes ─────────────────────────────────────────────────────────────────────────────────

  /// Mes groupes (200 au plus), du plus récemment actif au plus ancien. Chaque ligne porte `last_message_kind`, `last_sender_id`, `last_message_at`,
  /// `unread` (mes non lus) et `muted` (sourdine).
  static Future<List<Map<String, dynamic>>> groups() async => JeuxApi.list(await _c.get('/groups'));

  /// Rejoint un groupe GRATUIT et public sans code (un groupe privé exige son code d'invitation : 404 sinon).
  static Future<Map<String, dynamic>> joinFreeGroup(String groupId) async => JeuxApi.map(await _c.post('/groups/$groupId/join'));

  /// À appeler après chaque message envoyé dans un groupe (sur Firebase) : l'API tient le type et la date du dernier message, les non lus des autres
  /// membres et prévient ceux qui n'ont pas mis le groupe en sourdine. Jamais de texte. [kind] : text, image, audio, video, file.
  static Future<void> groupSent(String groupId, {String kind = 'text'}) => _c.post('/groups/$groupId/sent', body: {'kind': kind});

  /// Mes non lus du groupe retombent à zéro (à l'ouverture du groupe).
  static Future<void> markGroupRead(String groupId) => _c.post('/groups/$groupId/read');

  /// Sourdine d'un groupe pour moi : plus de notification, les non lus continuent de compter.
  static Future<void> muteGroup(String groupId, bool muted) => _c.put('/groups/$groupId/mute', body: {'muted': muted});

  /// Groupes à découvrir (`GET /groups/discover`) : groupes publics non gelés, officiels d'abord puis les plus peuplés, que j'en sois membre ou non.
  /// [featured] : seulement les officiels et ceux d'un propriétaire Gold. Chaque ligne porte en plus `is_member`, `owner_is_gold` et `featured`.
  static Future<List<Map<String, dynamic>>> discoverGroups({bool featured = false, int limit = 20}) async =>
      JeuxApi.list(await _c.get('/groups/discover', query: {if (featured) 'featured': 1, 'limit': limit}));

  /// Total de mes messages non lus dans les groupes (hors sourdine et supprimés), calculé par le serveur (`GET /groups/unread-count`).
  static Future<int> unreadGroups() async => JeuxApi.asInt(JeuxApi.map(await _c.get('/groups/unread-count'))['unread']);

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

  /// Membres d'un groupe (propriétaire, administrateurs puis les autres). [q] : recherche par pseudo (faite par le serveur, sur tous les membres).
  static Future<({List<Map<String, dynamic>> items, String? next})> members(String id, {String? cursor, int limit = 50, String? q}) async {
    final r = await _c.get('/groups/$id/members', query: {'limit': limit, if (cursor != null) 'cursor': cursor, if (q != null && q.trim().isNotEmpty) 'q': q.trim()});
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

  /// Page de notifications. [types] : ne garde que ces types (le serveur filtre : `type[]=FAVORITE&type[]=COMMENT`). Chaque ligne porte l'auteur (`actor`).
  static Future<({List<Map<String, dynamic>> items, String? next})> notifications({String? cursor, int limit = 60, bool unreadOnly = false, List<String>? types}) async {
    final r = await _c.get('/notifications', query: {
      'limit': limit,
      if (cursor != null) 'cursor': cursor,
      if (unreadOnly) 'unread': 1,
      if (types != null && types.isNotEmpty) 'type[]': types,
    });
    return (items: JeuxApi.list(r), next: r is Map ? r['next_cursor'] as String? : null);
  }

  static Future<int> unreadNotifications() async => JeuxApi.asInt(JeuxApi.map(await _c.get('/notifications/unread-count'))['count']);

  /// Notifications non lues par type : `{FAVORITE: 3, COMMENT: 1}` (pastilles de la page et de l'accueil).
  static Future<Map<String, int>> unreadCountsByType() async =>
      JeuxApi.map(await _c.get('/notifications/unread-counts-by-type')).map((k, v) => MapEntry(k.toUpperCase(), JeuxApi.asInt(v)));

  /// Préférences de notification : `{reminders, activity, news}` (tout activé par défaut).
  static Future<Map<String, bool>> notificationPreferences() async {
    final m = JeuxApi.map(await _c.get('/me/notification-preferences'));
    return {'reminders': m['reminders'] != false, 'activity': m['activity'] != false, 'news': m['news'] != false};
  }

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
    String typeSession = 'talk',   // talk (discussion) ou shopping (vente en direct)
    bool audioOnly = false,        // salon audio : billet bien moins cher quand le gratuit du mois est épuisé
    bool offerEntry = false,       // l'hôte offre l'entrée : il paie les billets de ses spectateurs (mode billet)
    int ticketExtraCoins = 0,      // supplément ajouté au billet, il revient à l'hôte (mode billet)
  }) async =>
      JeuxApi.map(await _c.post('/lives', body: {
        'type_session': typeSession,
        if (audioOnly) 'audio_only': true,
        if (offerEntry) 'offer_entry': true,
        if (ticketExtraCoins > 0) 'ticket_extra_coins': ticketExtraCoins,
        'title': title,
        if (coverUploadId != null) 'cover_upload_id': coverUploadId,
        if (durationMinutes != null) 'duration_minutes': durationMinutes,
        'is_paid': isPaid,
        'participation_fee_coins': feeCoins,
        'free_trial_minutes': freeTrialMinutes,
        if (options != null) 'options': options,
      }));

  /// Signal de l'hôte ; en mode billet la réponse porte `host_fee: { coins, paid_until }` (échéance des frais de diffusion).
  static Future<Map<String, dynamic>> heartbeat(String id, {int? viewers, int? likes, int? shares}) async => JeuxApi.map(await _c.post('/lives/$id/heartbeat', body: {
        if (viewers != null) 'viewer_count': viewers,
        if (likes != null) 'likes_count': likes,
        if (shares != null) 'shares_count': shares,
      }));

  static Future<Map<String, dynamic>> update(String id, Map<String, dynamic> fields) async => JeuxApi.map(await _c.patch('/lives/$id', body: fields));

  static Future<void> end(String id) => _c.post('/lives/$id/end');

  /// Droits de lancement : lives gratuits restants ce mois, durée maximale, prix/durée/nombre des prolongations payantes.
  static Future<Map<String, dynamic>> limits() async => JeuxApi.map(await _c.get('/lives/limits'));

  // Vocaux des spectateurs à l'hôte (30 s au plus, fichier privé, écouté par l'hôte seul)
  static Future<Map<String, dynamic>> voiceStatus(String id) async => JeuxApi.map(await _c.get('/lives/$id/voice-notes/status'));
  static Future<Map<String, dynamic>> sendVoice(String id, String uploadId, int seconds) async =>
      JeuxApi.map(await _c.post('/lives/$id/voice-notes', body: {'upload_id': uploadId, 'duration_seconds': seconds}));
  static Future<Map<String, dynamic>> voiceNotes(String id) async => JeuxApi.map(await _c.get('/lives/$id/voice-notes'));
  static Future<String> voiceListen(String noteId) async => '${JeuxApi.map(await _c.get('/lives/voice-notes/$noteId/listen'))['url']}';
  static Future<void> voiceIgnore(String noteId) => _c.post('/lives/voice-notes/$noteId/ignore');
  static Future<void> voiceReport(String noteId) => _c.post('/lives/voice-notes/$noteId/report');
  static Future<Map<String, dynamic>> voiceSettings(String id, {bool? enabled, String? blockUserId}) async =>
      JeuxApi.map(await _c.put('/lives/$id/voice-notes/settings', body: {if (enabled != null) 'enabled': enabled, if (blockUserId != null) 'block_user_id': blockUserId}));

  /// Jeton Agora : [uid] est l'identifiant numérique Agora du participant ; [role] « host » ou « audience ».
  static Future<Map<String, dynamic>> token(String id, {required int uid, String role = 'audience'}) async =>
      JeuxApi.map(await _c.post('/lives/$id/token', body: {'uid': uid, 'role': role}));

  /// Minutes d'Agora : mode (`free` tant qu'il reste du gratuit, `ticket` ensuite) et prix des billets (pièces, jamais la part gardée par Afrolook).
  static Future<Map<String, dynamic>> minutes() async => JeuxApi.map(await _c.get('/lives/minutes'));

  /// Battement d'un spectateur (toutes les 30 à 60 s) : compte ses minutes ; 402 `ticket_required` quand son billet est fini.
  static Future<Map<String, dynamic>> watch(String id) async => JeuxApi.map(await _c.post('/lives/$id/watch'));

  /// Bilan du live (hôte et équipe) : gains, chiffres, plus généreux, billets payés.
  static Future<Map<String, dynamic>> report(String id) async => JeuxApi.map(await _c.get('/lives/$id/report'));

  // ── Scène à plusieurs : demandes, invitations, validation de l'hôte ──
  static Future<Map<String, dynamic>> stage(String id) async => JeuxApi.map(await _c.get('/lives/$id/stage'));
  static Future<Map<String, dynamic>> stageRequest(String id, String media) async => JeuxApi.map(await _c.post('/lives/$id/stage/request', body: {'media': media}));
  static Future<void> stageCancel(String id) => _c.post('/lives/$id/stage/request/cancel');
  static Future<Map<String, dynamic>> stageInvite(String id, String userId, String media) async =>
      JeuxApi.map(await _c.post('/lives/$id/stage/invite', body: {'user_id': userId, 'media': media}));
  static Future<void> stageDecide(String id, String requestId, {required bool accept}) => _c.post('/lives/$id/stage/requests/$requestId/${accept ? 'accept' : 'refuse'}');
  static Future<void> stageAnswerInvite(String id, String requestId, {required bool accept}) => _c.post('/lives/$id/stage/invites/$requestId/${accept ? 'accept' : 'decline'}');
  static Future<void> stageRemove(String id, String userId) => _c.delete('/lives/$id/stage/$userId');
  static Future<void> stageUid(String id, int uid) => _c.post('/lives/$id/stage/uid', body: {'uid': uid});

  /// Cadeau en live (argent : clé d'idempotence conservée à chaque tentative).
  static Future<Map<String, dynamic>> gift(String id, {required int coins, String? icon, String? label, String? targetId}) async =>
      JeuxApi.map(await _c.pay('/lives/$id/gifts', body: {'coins': coins, if (icon != null) 'icon': icon, if (label != null) 'label': label, if (targetId != null) 'target_id': targetId}));

  // ── Jeux : objectif, duel, défi, sondage, tirage au sort, questions du public ──
  /// Jeu en cours (ou terminé depuis moins de 45 s) et objectif du live.
  static Future<Map<String, dynamic>> game(String id) async => JeuxApi.map(await _c.get('/lives/$id/game'));
  static Future<Map<String, dynamic>> gameStart(String id, Map<String, dynamic> body) async => JeuxApi.map(await _c.post('/lives/$id/game', body: body));
  static Future<void> gameEnd(String id) => _c.post('/lives/$id/game/end');
  static Future<Map<String, dynamic>> gameVote(String id, int option) async => JeuxApi.map(await _c.post('/lives/$id/game/vote', body: {'option': option}));
  static Future<Map<String, dynamic>> gameDraw(String id, int coins, List<String> candidates) async =>
      JeuxApi.map(await _c.post('/lives/$id/game/draw', body: {'coins': coins, 'candidates': candidates}));
  static Future<void> ask(String id, String text) => _c.post('/lives/$id/questions', body: {'text': text});
  static Future<List<Map<String, dynamic>>> questions(String id) async => JeuxApi.list(await _c.get('/lives/$id/questions'));
  static Future<void> pinQuestion(String id, String questionId) => _c.post('/lives/$id/questions/$questionId/pin');

  static Future<List<Map<String, dynamic>>> leaderboard(String id) async => JeuxApi.list(await _c.get('/lives/$id/leaderboard'));
}
