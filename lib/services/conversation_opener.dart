import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/services/api/chat_api.dart';
import 'package:afrotok/services/api/chat_mapper.dart';
import 'package:flutter/material.dart';

/// Ouverture d'une discussion 1 à 1 depuis un profil ou la liste des amis : `POST /conversations` renvoie toujours la conversation, même en cas de
/// blocage (dans un sens ou dans l'autre), avec `blocked` et `blocked_by_me`. L'écran de messages affiche alors la bannière et désactive l'envoi ;
/// ici on prévient la personne, avant d'ouvrir, de qui a bloqué.
class ConversationOpener {
  ConversationOpener._();

  /// Phrase en français décrivant le blocage de [chat] (null s'il n'y en a pas).
  static String? blockedNotice(Chat chat, {String? pseudo}) {
    if (!chat.blocked) return null;
    final who = (pseudo ?? chat.receiver?.pseudo ?? '').trim();
    final name = who.isEmpty ? 'Cette personne' : '@$who';
    return chat.blockedByMe
        ? 'Tu as bloqué $name : tu peux relire la discussion, mais tu ne peux plus lui écrire. Débloque-la pour reprendre.'
        : '$name t\'a bloqué : tu peux relire la discussion, mais tu ne peux plus lui écrire.';
  }

  /// Ouvre ou crée la conversation avec [other]. Erreurs : [ApiException] (message en français) ; aucun repli sur Firebase.
  static Future<Chat> open(String myId, UserData other) async {
    final otherId = other.id;
    if (otherId == null || otherId.isEmpty) throw ApiException(status: 0, code: 'unknown_user', message: 'Personne inconnue.');
    final chat = chatFromConversation(await ChatApi.openConversation(otherId), myId);
    if ((chat.receiver?.pseudo ?? '').isEmpty) {
      chat.receiver = other;
      chat.chatFriend = other;
    }
    return chat;
  }

  /// Comme [open], puis prévient dans un bandeau si la discussion est bloquée (qui a bloqué). L'envoi reste impossible dans l'écran de messages.
  static Future<Chat> openAndWarn(BuildContext context, String myId, UserData other) async {
    final chat = await open(myId, other);
    final notice = blockedNotice(chat, pseudo: other.pseudo);
    if (notice != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(notice), duration: const Duration(seconds: 5)));
    }
    return chat;
  }
}
