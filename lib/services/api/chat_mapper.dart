import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/api/jeux_api.dart';

/// Convertit les conversations et groupes de l'API vers les modèles / tables que les écrans de chat utilisent déjà.

/// Conversation 1 à 1 de l'API -> [Chat]. Les messages de la discussion sont sur Firebase sous `chat_id` = [Chat.docId].
/// Pour une conversation importée, l'API peut fournir `legacy_chat_id` (ancien `docId`) : c'est alors lui qui garde l'historique lisible.
Chat chatFromConversation(Map<String, dynamic> j, String myId) {
  final other = j['other'] is Map ? Map<String, dynamic>.from(j['other'] as Map) : <String, dynamic>{};
  final otherId = '${other['id'] ?? ''}';
  final user = UserData()
    ..id = otherId
    ..pseudo = (other['username'] as String?) ?? ''
    ..imageUrl = (other['avatar_url'] as String?) ?? '';
  final at = JeuxApi.ms(j['last_message_at']);
  final req = j['request'] is Map ? Map<String, dynamic>.from(j['request'] as Map) : null;
  final unread = JeuxApi.asInt(j['unread']);
  final id = '${j['id']}';
  final chat = Chat(
    id: id,
    docId: (j['legacy_chat_id'] as String?)?.isNotEmpty == true ? j['legacy_chat_id'] as String : id,
    senderId: myId,
    receiverId: otherId,
    lastMessage: (j['last_message'] as String?) ?? '',
    type: ChatType.USER.name,
    createdAt: at,
    updatedAt: at,
    my_msg_not_read: unread,
    your_msg_not_read: 0,
    receiver: user,
    chatFriend: user,
  );
  chat.streak = JeuxApi.asInt(j['streak']);
  chat.lastMessageIsRead = unread == 0;
  if (req != null) {
    chat.requestStatus = req['status'] as String?;
    chat.requestFrom = req['i_am_requester'] == true ? myId : otherId;
  }
  return chat;
}

/// Groupe de l'API -> table au format des anciens documents `GroupChats/{id}` (les écrans de groupe lisent ces clés).
Map<String, dynamic> groupToLegacy(Map<String, dynamic> g) {
  final me = g['me'] is Map ? Map<String, dynamic>.from(g['me'] as Map) : <String, dynamic>{};
  final created = JeuxApi.ms(g['created_at']);
  final expires = g['join_code_expires_at'] == null ? null : JeuxApi.ms(g['join_code_expires_at']);
  return {
    'id': g['id'],
    'name': g['name'] ?? '',
    'description': g['description'] ?? '',
    'image_url': g['image_url'],
    'owner_id': g['owner_id'],
    'member_ids': const <String>[],
    'is_frozen': g['is_frozen'] == true,
    'is_private': g['is_private'] == true,
    'subscription_price_coins': JeuxApi.asInt(g['price_coins']),
    'subscription_price': JeuxApi.asInt(g['price_coins']),
    'join_code': g['join_code'],
    'join_code_expires_at': expires,
    'created_at': created,
    'updated_at': created,
    'member_count': JeuxApi.asInt(g['member_count']),
    'ephemeral_duration': JeuxApi.asInt(g['ephemeral_seconds']),
    'is_official': g['is_official'] == true,
    'is_read_only': g['is_read_only'] == true,
    'only_admins_can_write': g['is_read_only'] == true,
    'default_can_write': g['default_can_write'] != false,
    'default_can_share': g['default_can_share'] != false,
    'allow_external_links': g['allow_external_links'] == true,
    'allow_hidden_msgs': g['allow_hidden_msgs'] == true,
    'cannot_leave': g['cannot_leave'] == true,
    // droits CALCULÉS par l'API pour la personne connectée (jamais recalculés dans l'application)
    'me_role': me['role'],
    'me_is_member': me['is_member'] == true,
    'me_can_write': me['can_write'] == true,
    'me_can_share': me['can_share'] == true,
    'me_subscription_active': me['subscription_active'] == true,
    'me_expires_at': me['expires_at'],
    'key_epoch': g['key_epoch'],
  };
}

/// Membre de groupe de l'API -> table au format des anciens documents `GroupChats/{id}/members/{uid}`.
Map<String, dynamic> memberToLegacy(Map<String, dynamic> m) => {
      'user_id': m['user_id'],
      'pseudo': m['username'] ?? '',
      'image_url': m['avatar_url'] ?? '',
      'role': m['role'] ?? 'member',
      'can_write': m['can_write'],
      'can_share': m['can_share'],
      'is_paid': m['is_paid'] == true,
      'expires_at': m['expires_at'],
      'joined_at': 0,
    };

/// Notification de l'API -> [NotificationData] (microsecondes pour `createdAt`, comme l'ancien format).
NotificationData notificationFromApi(Map<String, dynamic> j) {
  final subjectType = '${j['subject_type'] ?? ''}';
  final subjectId = '${j['subject_id'] ?? ''}';
  final created = JeuxApi.ms(j['created_at']) * 1000;
  final n = NotificationData(
    id: '${j['id']}',
    type: '${j['type'] ?? ''}',
    titre: '${j['title'] ?? ''}',
    description: '${j['body'] ?? ''}',
    user_id: (j['actor_id'] as String?) ?? '',
    receiver_id: '',
    media_url: (j['media_url'] as String?) ?? '',
    is_open: j['is_read'] == true,
    status: 'VALIDE',
    createdAt: created,
    updatedAt: created,
    users_id_view: const [],
  );
  if (subjectType == 'channel' || subjectType == 'canal') {
    n.canal_id = subjectId;
  } else if (subjectType != 'conversation' && subjectType != 'group') {
    n.post_id = subjectId;
  }
  n.post_thumbnail = (j['media_url'] as String?);
  return n;
}
