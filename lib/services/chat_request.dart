import 'package:afrotok/services/api/users_api.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../models/model_data.dart';
import '../providers/authProvider.dart';

/// Demande de discussion (réponse à une chronique) : la discussion existe dès l'envoi, avec le premier message visible, mais seule la personne
/// qui a répondu peut écrire tant que l'autre n'a pas accepté. Accepter ou refuser se fait depuis la discussion ou la page Invitations ;
/// dans les deux cas c'est l'invitation qui décide (le serveur recopie son état dans la discussion).
class ChatRequestService {
  ChatRequestService._();

  static bool isPending(Chat c) => c.requestStatus == 'pending';
  static bool isRefused(Chat c) => c.requestStatus == 'refused';

  /// Vrai pour la personne qui a écrit en premier (elle attend la réponse).
  static bool iAmRequester(Chat c, String? myId) => c.requestFrom != null && c.requestFrom == myId;

  /// Invitation en attente reçue de la personne qui a écrit en premier (l'API ne donne pas son identifiant dans la conversation).
  static Future<String?> _pendingInvitationId(Chat chat, String? myId) async {
    final from = chat.requestFrom;
    if (from == null || from == myId) return null;
    String? cursor;
    for (var i = 0; i < 3; i++) {
      final page = await UsersApi.invitations(direction: 'received', status: 'pending', cursor: cursor, limit: 50);
      for (final j in page.items) {
        final other = j['user'] is Map ? Map<String, dynamic>.from(j['user'] as Map) : <String, dynamic>{};
        if (other['id'] == from) return j['id'] as String?;
      }
      cursor = page.next;
      if (cursor == null) break;
    }
    return null;
  }

  /// Accepte : l'invitation passe à « acceptée » (amis, comme sur la page Invitations), la discussion devient normale, la personne est prévenue par l'API.
  static Future<bool> accept(BuildContext context, Chat chat) async {
    final me = context.read<UserAuthProvider>().loginUserData;
    try {
      final id = await _pendingInvitationId(chat, me.id);
      if (id != null) await UsersApi.acceptInvitation(id);
      chat.requestStatus = 'accepted';
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Refuse : la discussion disparaît de la liste de la personne qui refuse ; l'autre voit « refusée » et peut réessayer après 7 jours.
  static Future<bool> refuse(BuildContext context, Chat chat) async {
    final me = context.read<UserAuthProvider>().loginUserData;
    try {
      final id = await _pendingInvitationId(chat, me.id);
      if (id != null) await UsersApi.refuseInvitation(id);
      chat.requestStatus = 'refused';
      return true;
    } catch (_) {
      return false;
    }
  }
}
