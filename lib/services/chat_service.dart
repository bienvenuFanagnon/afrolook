import 'package:afrotok/services/read_meter.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/services/api/chat_api.dart';
import 'package:afrotok/services/api/chat_mapper.dart';
import 'package:afrotok/services/api/users_api.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:afrotok/models/chatmodels/message.dart';

import 'package:afrotok/models/model_data.dart';

/// Conversations 1 à 1. La LISTE (ordre, personne, non lus, série, demande, blocage) vient de l'API ; seuls les MESSAGES restent sur Firebase
/// (collection Messages) : l'aperçu du dernier message est déchiffré par l'application, l'API ne stocke jamais le texte.
class ChatService {
  // Configuration de pagination - lots de 5
  static const int pageSize = 5;

  // Pour la pagination infinie (curseur fourni par l'API)
  String? _cursor;
  bool _hasMore = true;

  // Cache
  final Map<String, Message> _lastMessagesCache = {};

  // Récupérer les conversations avec pagination par lots de 5 (erreur de l'API : remontée, jamais d'ancienne source)
  Future<List<ChatWithLastMessage>> getNextChatsBatch({
    required String currentUserId,
    bool loadMore = false,
  }) async {
    if (!loadMore) {
      _cursor = null;
      _hasMore = true;
    }

    if (!_hasMore) return [];

    printVm('🔄 [CHAT_SERVICE] Chargement lot suivant - loadMore: $loadMore');
    final page = await ChatApi.conversations(cursor: _cursor, limit: pageSize);
    _cursor = page.next;
    _hasMore = page.next != null;

    final futures = page.items.map((j) => _process(chatFromConversation(j, currentUserId)));
    final results = await Future.wait(futures);
    final listChats = results.whereType<ChatWithLastMessage>().toList();
    printVm('✅ [CHAT_SERVICE] Lot chargé: ${listChats.length} chats');
    return listChats;
  }

  // Stream pour écouter les mises à jour des messages (lu/non lu) : les messages restent sur Firebase
  Stream<Map<String, dynamic>> getMessageUpdatesStream(String currentUserId) {
    return FirebaseFirestore.instance
        .collection('Messages')
        .where('receiverBy', isEqualTo: currentUserId)
        .where('is_valide', isEqualTo: true)
        .snapshotsM('chat_service.dart:445')
        .map((snapshot) {
      Map<String, dynamic> updates = {};
      for (var doc in snapshot.docs) {
        final message = Message.fromJson(doc.data());
        final chatId = message.chat_id;
        if (chatId != null) {
          if (!updates.containsKey(chatId)) {
            updates[chatId] = {};
          }
          updates[chatId]['lastMessage'] = message;
          updates[chatId]['unreadCount'] = message.message_state == MessageState.NONLU.name
              && message.sendBy != currentUserId ? 1 : 0;
        }
      }
      return updates;
    });
  }

  Future<ChatWithLastMessage> _process(Chat chat) async {
    final lastMessage = await _getLastMessageForChat(chat.docId ?? chat.id ?? '');
    return ChatWithLastMessage(chat: chat, lastMessage: lastMessage);
  }

  // Récupérer le dernier message (sur Firebase, avec les messages)
  Future<Message?> _getLastMessageForChat(String chatId) async {
    if (chatId.isEmpty) return null;
    if (_lastMessagesCache.containsKey(chatId)) {
      return _lastMessagesCache[chatId];
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('Messages')
          .where('chat_id', isEqualTo: chatId)
          .where('is_valide', isEqualTo: true)
          .orderBy('create_at_time_spam', descending: true)
          .limit(1)
          .getM('chat_service.dart:508');

      if (querySnapshot.docs.isNotEmpty) {
        final message = Message.fromJson(querySnapshot.docs.first.data());
        _lastMessagesCache[chatId] = message;
        return message;
      }
    } catch (e) {
      printVm("❌ [LAST_MESSAGE] Erreur: $e");
    }

    return null;
  }

  // RECHERCHE DE CONVERSATIONS : parmi mes conversations puis parmi mes amis (la recherche de tous les comptes n'est pas encore dans l'API)
  Future<List<Chat>> searchChats({
    required String query,
    required String currentUserId,
  }) async {
    printVm('🔍 [SEARCH] Recherche avec query: "$query"');
    if (query.isEmpty) return [];
    final q = query.toLowerCase();

    final found = <Chat>[];
    final seen = <String>{};

    // Conversations existantes (trois pages au plus)
    String? cursor;
    for (var i = 0; i < 3; i++) {
      final page = await ChatApi.conversations(cursor: cursor, limit: 50);
      for (final j in page.items) {
        final chat = chatFromConversation(j, currentUserId);
        final pseudo = chat.chatFriend?.pseudo ?? '';
        if (pseudo.toLowerCase().contains(q) && seen.add(chat.receiverId ?? '')) found.add(chat);
      }
      cursor = page.next;
      if (cursor == null) break;
    }

    // Amis sans conversation : on propose de démarrer
    try {
      final friends = await UsersApi.friends(limit: 50);
      for (final f in friends.items) {
        final id = '${f['id'] ?? f['user_id'] ?? ''}';
        final pseudo = '${f['username'] ?? f['pseudo'] ?? ''}';
        if (id.isEmpty || id == currentUserId || !pseudo.toLowerCase().contains(q) || !seen.add(id)) continue;
        final user = UserData()
          ..id = id
          ..pseudo = pseudo
          ..imageUrl = '${f['avatar_url'] ?? ''}';
        found.add(Chat(
          id: 'search_$id',
          senderId: currentUserId,
          receiverId: id,
          lastMessage: 'Démarrer une conversation',
          type: ChatType.USER.name,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          receiver: user,
          chatFriend: user,
        ));
      }
    } catch (e) {
      printVm('⚠️ [SEARCH] amis indisponibles : $e');
    }
    printVm('🎯 [SEARCH] Recherche terminée: ${found.length} résultats');
    return found;
  }

  // CRÉER OU RÉCUPÉRER UNE CONVERSATION (l'API garde une seule conversation par paire de personnes)
  Future<Chat> createOrGetChat({
    required Chat chat,
    required String currentUserId,
  }) async {
    final isSearch = chat.id != null && chat.id!.startsWith('search_');
    if (!isSearch && chat.id != null && chat.id!.isNotEmpty) {
      if (chat.chatFriend != null) chat.receiver = chat.chatFriend;
      return chat;
    }
    final otherId = chat.receiverId == currentUserId ? chat.senderId : chat.receiverId;
    if (otherId == null || otherId.isEmpty) throw StateError('Personne inconnue');
    final opened = chatFromConversation(await ChatApi.openConversation(otherId), currentUserId);
    if (chat.chatFriend != null && (opened.chatFriend?.pseudo ?? '').isEmpty) {
      opened.chatFriend = chat.chatFriend;
      opened.receiver = chat.chatFriend;
    }
    return opened;
  }

  // Vider le cache
  void clearCache() {
    _lastMessagesCache.clear();
    _cursor = null;
    _hasMore = true;
  }

  bool get hasMore => _hasMore;

  // Réinitialiser la pagination
  void resetPagination() {
    _cursor = null;
    _hasMore = true;
  }
}

// Helper class
class ChatWithLastMessage {
  final Chat chat;
  late Message? lastMessage;

  ChatWithLastMessage({
    required this.chat,
    required this.lastMessage,
  });
}
