import 'package:afrotok/services/read_meter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../models/model_data.dart';
import '../providers/authProvider.dart';
import '../providers/userProvider.dart';

/// Demande de discussion (réponse à une chronique) : la discussion existe dès l'envoi, avec le premier message visible, mais seule la personne
/// qui a répondu peut écrire tant que l'autre n'a pas accepté. Accepter ou refuser se fait depuis la discussion ou la page Invitations ;
/// dans les deux cas c'est l'invitation qui décide (le serveur recopie son état dans la discussion).
class ChatRequestService {
  ChatRequestService._();

  static bool isPending(Chat c) => c.requestStatus == 'pending';
  static bool isRefused(Chat c) => c.requestStatus == 'refused';

  /// Vrai pour la personne qui a écrit en premier (elle attend la réponse).
  static bool iAmRequester(Chat c, String? myId) => c.requestFrom != null && c.requestFrom == myId;

  static Future<Invitation?> _invitation(Chat chat) async {
    final id = chat.requestInvitationId;
    if (id == null || id.isEmpty) return null;
    final doc = await FirebaseFirestore.instance.collection('Invitations').doc(id).getM('chat_request.dart:24');
    if (!doc.exists) return null;
    return Invitation.fromJson(doc.data()!, reference: doc.reference)..id = doc.id;
  }

  static Future<void> _setStatus(Chat chat, String status) async {
    chat.requestStatus = status;
    if (chat.id == null) return;
    await FirebaseFirestore.instance.collection('Chats').doc(chat.id).update({'request_status': status, 'updated_at': DateTime.now().millisecondsSinceEpoch});
  }

  /// Accepte : l'invitation passe à ACCEPTER (amis, comme sur la page Invitations), la discussion devient normale, la personne est prévenue.
  static Future<bool> accept(BuildContext context, Chat chat) async {
    final auth = context.read<UserAuthProvider>();
    final users = context.read<UserProvider>();
    final me = auth.loginUserData;
    final fs = FirebaseFirestore.instance;
    try {
      final inv = await _invitation(chat);
      final senderId = chat.requestFrom ?? inv?.senderId;
      if (inv != null && inv.status == InvitationStatus.ENCOURS.name) {
        if (!await users.acceptInvitation(inv)) return false;
      }
      if (senderId != null) {
        me.friendsIds ??= [];
        if (!me.friendsIds!.contains(senderId)) me.friendsIds!.add(senderId);
        await fs.collection('Users').doc(me.id).update({'friendsIds': FieldValue.arrayUnion([senderId])});
      }
      await _setStatus(chat, 'accepted');
      if (senderId != null) {
        try {
          final other = (await fs.collection('Users').doc(senderId).getM('chat_request.dart:55')).data();
          final player = other?['oneIgnalUserid'];
          if (player != null && player.toString().isNotEmpty) {
            await auth.sendNotification(
              userIds: [player],
              smallImage: me.imageUrl ?? '',
              send_user_id: me.id!,
              recever_user_id: senderId,
              message: '✅ @${me.pseudo} a accepté votre invitation !',
              type_notif: NotificationType.ACCEPTINVITATION.name,
              post_id: '',
              post_type: '',
              chat_id: chat.id ?? '',
            );
          }
        } catch (_) {}
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Refuse : la discussion disparaît de la liste de la personne qui refuse ; l'autre voit « refusée » et peut réessayer après 7 jours.
  static Future<bool> refuse(BuildContext context, Chat chat) async {
    final users = context.read<UserProvider>();
    try {
      final inv = await _invitation(chat);
      if (inv != null && inv.status == InvitationStatus.ENCOURS.name) {
        if (!await users.refuserInvitation(inv)) return false;
      }
      await _setStatus(chat, 'refused');
      return true;
    } catch (_) {
      return false;
    }
  }
}
