import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:afrotok/models/chatmodels/message.dart';
import 'package:afrotok/models/model_data.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:afrotok/models/chatmodels/message.dart';
import 'package:afrotok/models/model_data.dart';

// class ChatService {
//   static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//
//   // Cache pour optimiser les performances
//   final Map<String, Message> _lastMessagesCache = {};
//   final Map<String, UserData> _usersCache = {};
//
//   // Configuration de pagination - variables non privées
//   static const int initialLimit = 3;
//   static const int incrementStep = 3;
//   static const int maxLimit = 10;
//   static const int infinityLimit = 20;
//
//   // Récupérer les conversations avec pagination OPTIMISÉE
//   Stream<List<ChatWithLastMessage>> getChatsPaginated({
//     required String currentUserId,
//     required int limit,
//   }) {
//     print('🔄 [CHAT_SERVICE] Début getChatsPaginated - limit: $limit, user: $currentUserId');
//
//     try {
//       return _firestore
//           .collection('Chats')
//           .where(Filter.or(
//         Filter('receiver_id', isEqualTo: currentUserId),
//         Filter('sender_id', isEqualTo: currentUserId),
//       ))
//           .where("type", isEqualTo: ChatType.USER.name)
//           .orderBy('updated_at', descending: true)
//           .limit(limit)
//           .snapshots()
//           .asyncMap((chatSnapshot) async {
//         print('📨 [CHAT_SERVICE] Reçu ${chatSnapshot.docs.length} chats de Firestore');
//
//         List<ChatWithLastMessage> listChats = [];
//
//         // Utiliser Future.wait pour charger en parallèle
//         List<Future<ChatWithLastMessage?>> futures = [];
//
//         for (var chatDoc in chatSnapshot.docs) {
//           futures.add(_processChatDocument(chatDoc, currentUserId));
//         }
//
//         final results = await Future.wait(futures);
//         listChats.addAll(results.whereType<ChatWithLastMessage>());
//
//         print('✅ [CHAT_SERVICE] Traitement terminé - ${listChats.length} chats avec derniers messages');
//         return listChats;
//       });
//     } catch (e) {
//       print('❌ [CHAT_SERVICE] Erreur dans getChatsPaginated: $e');
//       return Stream.value([]);
//     }
//   }
//
//   // Traiter un document chat de manière asynchrone
//   Future<ChatWithLastMessage?> _processChatDocument(
//       QueryDocumentSnapshot chatDoc, String currentUserId) async {
//     try {
//       Chat chat = Chat.fromJson(chatDoc.data() as Map<String, dynamic>);
//       print('🔍 [CHAT_SERVICE] Traitement chat: ${chat.id} - docId: ${chat.docId}');
//
//       final otherUserId = currentUserId == chat.receiverId
//           ? chat.senderId
//           : chat.receiverId;
//
//       print('👤 [CHAT_SERVICE] otherUserId: $otherUserId pour chat ${chat.id}');
//
//       if (otherUserId != null) {
//         final userData = await _getUserData(otherUserId);
//         if (userData != null) {
//           chat.chatFriend = userData;
//           chat.receiver = userData;
//
//           // Récupérer le dernier message en parallèle
//           print('📝 [CHAT_SERVICE] Récupération dernier message pour chat ${chat.id}');
//           final lastMessage = await _getLastMessageForChat(chat.docId!);
//
//           if (lastMessage != null) {
//             print('✅ [CHAT_SERVICE] Dernier message trouvé pour ${chat.id}: ${lastMessage.messageType} - "${lastMessage.message}"');
//           } else {
//             print('⚠️ [CHAT_SERVICE] Aucun dernier message trouvé pour ${chat.id}');
//           }
//
//           return ChatWithLastMessage(
//             chat: chat,
//             lastMessage: lastMessage,
//           );
//         } else {
//           print('❌ [CHAT_SERVICE] UserData non trouvé pour $otherUserId');
//         }
//       } else {
//         print('❌ [CHAT_SERVICE] otherUserId est null pour chat ${chat.id}');
//       }
//       return null;
//     } catch (e) {
//       print("❌ [CHAT_SERVICE] Erreur processing chat: $e");
//       return null;
//     }
//   }
//
//   // Récupérer le dernier message d'un chat - OPTIMISÉ avec logs détaillés
//   Future<Message?> _getLastMessageForChat(String chatId) async {
//     print('🔍 [LAST_MESSAGE] Recherche dernier message pour chat: $chatId');
//
//     if (_lastMessagesCache.containsKey(chatId)) {
//       print('💾 [LAST_MESSAGE] Utilisation cache pour chat: $chatId');
//       return _lastMessagesCache[chatId];
//     }
//
//     try {
//       print('📡 [LAST_MESSAGE] Requête Firestore pour chat: $chatId');
//
//       final querySnapshot = await _firestore
//           .collection('Messages')
//           .where('chat_id', isEqualTo: chatId)
//           .where('is_valide', isEqualTo: true)
//           .orderBy('create_at_time_spam', descending: true)
//           .limit(1)
//           .get();
//
//       print('📊 [LAST_MESSAGE] Résultat Firestore: ${querySnapshot.docs.length} messages trouvés');
//
//       if (querySnapshot.docs.isNotEmpty) {
//         final doc = querySnapshot.docs.first;
//         final messageData = doc.data();
//
//         print('📄 [LAST_MESSAGE] Données brutes du message:');
//         print('   - ID: ${doc.id}');
//         print('   - chat_id: ${messageData['chat_id']}');
//         print('   - message: ${messageData['message']}');
//         print('   - message_type: ${messageData['message_type']}');
//         print('   - send_by: ${messageData['send_by']}');
//         print('   - create_at_time_spam: ${messageData['create_at_time_spam']}');
//         print('   - is_valide: ${messageData['is_valide']}');
//         print('   - message_state: ${messageData['message_state']}');
//
//         try {
//           final message = Message.fromJson(messageData);
//           _lastMessagesCache[chatId] = message;
//
//           print('✅ [LAST_MESSAGE] Message créé avec succès:');
//           print('   - Type: ${message.messageType}');
//           print('   - Contenu: ${message.message}');
//           print('   - Date: ${message.createdAt}');
//           print('   - État: ${message.message_state}');
//
//           return message;
//         } catch (e) {
//           print('❌ [LAST_MESSAGE] Erreur création Message.fromJson: $e');
//           print('❌ [LAST_MESSAGE] Données problématiques: $messageData');
//           return null;
//         }
//       } else {
//         print('⚠️ [LAST_MESSAGE] Aucun message valide trouvé pour chat: $chatId');
//         print('ℹ️ [LAST_MESSAGE] Vérifier que:');
//         print('   - Le chat_id $chatId existe dans la collection Messages');
//         print('   - Les messages ont is_valide = true');
//         print('   - Il y a des messages avec create_at_time_spam');
//       }
//     } catch (e) {
//       print("❌ [LAST_MESSAGE] Erreur récupération dernier message pour $chatId: $e");
//       print("❌ [LAST_MESSAGE] Stack trace: ${e.toString()}");
//     }
//
//     return null;
//   }
//
//   // Récupérer les données utilisateur - OPTIMISÉ
//   Future<UserData?> _getUserData(String userId) async {
//     print('👤 [USER_DATA] Recherche utilisateur: $userId');
//
//     if (_usersCache.containsKey(userId)) {
//       print('💾 [USER_DATA] Utilisation cache pour user: $userId');
//       return _usersCache[userId];
//     }
//
//     try {
//       print('📡 [USER_DATA] Requête Firestore pour user: $userId');
//       final userDoc = await _firestore
//           .collection('Users')
//           .doc(userId)
//           .get();
//
//       if (userDoc.exists) {
//         final userData = UserData.fromJson(userDoc.data()!);
//         _usersCache[userId] = userData;
//         print('✅ [USER_DATA] Utilisateur trouvé: ${userData.pseudo}');
//         return userData;
//       } else {
//         print('❌ [USER_DATA] Utilisateur non trouvé: $userId');
//       }
//     } catch (e) {
//       print("❌ [USER_DATA] Erreur récupération utilisateur $userId: $e");
//     }
//
//     return null;
//   }
//
//   // Recherche de conversations - OPTIMISÉE
//   Future<List<Chat>> searchChats({
//     required String query,
//     required String currentUserId,
//   }) async {
//     print('🔍 [SEARCH] Recherche avec query: "$query"');
//
//     if (query.isEmpty) return [];
//
//     try {
//       // Charger en parallèle
//       final [chatsSnapshot, usersSnapshot] = await Future.wait([
//         _firestore
//             .collection('Chats')
//             .where(Filter.or(
//           Filter('receiver_id', isEqualTo: currentUserId),
//           Filter('sender_id', isEqualTo: currentUserId),
//         ))
//             .where("type", isEqualTo: ChatType.USER.name)
//             .get(),
//         _firestore
//             .collection('Users')
//             .where('pseudo', isGreaterThanOrEqualTo: query)
//             .where('pseudo', isLessThan: query + 'z')
//             .get(),
//       ]);
//
//       print('📊 [SEARCH] Résultats: ${chatsSnapshot.docs.length} chats, ${usersSnapshot.docs.length} users');
//
//       List<Chat> foundChats = [];
//
//       // Traiter les conversations existantes
//       for (var chatDoc in chatsSnapshot.docs) {
//         Chat chat = Chat.fromJson(chatDoc.data() as Map<String, dynamic>);
//
//         final otherUserId = currentUserId == chat.receiverId
//             ? chat.senderId
//             : chat.receiverId;
//
//         if (otherUserId != null) {
//           final userData = await _getUserData(otherUserId);
//           if (userData != null) {
//             chat.chatFriend = userData;
//             chat.receiver = userData;
//
//             if (userData.pseudo!.toLowerCase().contains(query.toLowerCase())) {
//               foundChats.add(chat);
//               print('✅ [SEARCH] Chat trouvé: ${userData.pseudo}');
//             }
//           }
//         }
//       }
//
//       // Ajouter les utilisateurs trouvés qui n'ont pas de conversation
//       for (var userDoc in usersSnapshot.docs) {
//         UserData userData = UserData.fromJson(userDoc.data() as Map<String, dynamic>);
//
//         if (userData.id == currentUserId) continue;
//
//         bool alreadyInResults = foundChats.any((chat) =>
//         chat.chatFriend != null && chat.chatFriend!.id == userData.id);
//
//         if (!alreadyInResults) {
//           Chat newChat = Chat(
//             id: 'search_${userData.id}',
//             senderId: currentUserId,
//             receiverId: userData.id!,
//             lastMessage: 'Démarrer une conversation',
//             type: ChatType.USER.name,
//             createdAt: DateTime.now().millisecondsSinceEpoch,
//             updatedAt: DateTime.now().millisecondsSinceEpoch,
//             receiver: userData,
//           );
//           foundChats.add(newChat);
//           print('➕ [SEARCH] Nouveau chat de recherche: ${userData.pseudo}');
//         }
//       }
//
//       print('🎯 [SEARCH] Recherche terminée: ${foundChats.length} résultats');
//       return foundChats;
//     } catch (e) {
//       print("❌ [SEARCH] Erreur de recherche: $e");
//       return [];
//     }
//   }
//
//   // Créer ou récupérer une conversation
//   Future<Chat> createOrGetChat({
//     required Chat chat,
//     required String currentUserId,
//   }) async {
//     print('💬 [CREATE_CHAT] Création/récupération chat: ${chat.id}');
//
//     if (chat.id!.startsWith('search_')) {
//       print('🔍 [CREATE_CHAT] Recherche chat existant...');
//
//       final existingChats = await _firestore
//           .collection('Chats')
//           .where(Filter.or(
//         Filter('docId', isEqualTo: '${chat.senderId}${chat.receiverId}'),
//         Filter('docId', isEqualTo: '${chat.receiverId}${chat.senderId}'),
//       ))
//           .limit(1)
//           .get();
//
//       if (existingChats.docs.isNotEmpty) {
//         print('✅ [CREATE_CHAT] Chat existant trouvé');
//         Chat existingChat = Chat.fromJson(existingChats.docs.first.data());
//         existingChat.chatFriend = chat.chatFriend;
//         existingChat.receiver = chat.receiver;
//         return existingChat;
//       } else {
//         print('➕ [CREATE_CHAT] Création nouveau chat');
//         String chatId = _firestore.collection('Chats').doc().id;
//         Chat newChat = Chat(
//           docId: '${chat.senderId}${chat.receiverId}',
//           id: chatId,
//           senderId: chat.senderId!,
//           receiverId: chat.receiverId!,
//           lastMessage: '',
//           type: ChatType.USER.name,
//           createdAt: DateTime.now().millisecondsSinceEpoch,
//           updatedAt: DateTime.now().millisecondsSinceEpoch,
//           receiver: chat.chatFriend,
//         );
//
//         await _firestore
//             .collection('Chats')
//             .doc(chatId)
//             .set(newChat.toJson());
//
//         return newChat;
//       }
//     }
//     print('✅ [CREATE_CHAT] Retour chat existant: ${chat.id}');
//     return chat;
//   }
//
//   // Vider le cache si nécessaire
//   void clearCache() {
//     print('🗑️ [CACHE] Vidage du cache');
//     _lastMessagesCache.clear();
//     _usersCache.clear();
//   }
// }

// Helper class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:afrotok/models/chatmodels/message.dart';
import 'package:afrotok/models/model_data.dart';

class ChatService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Configuration de pagination - lots de 5
  static const int pageSize = 5;

  // Pour la pagination infinie
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;

  // Cache
  final Map<String, Message> _lastMessagesCache = {};
  final Map<String, UserData> _usersCache = {};

  // Récupérer les conversations avec pagination par lots de 5
  Future<List<ChatWithLastMessage>> getNextChatsBatch({
    required String currentUserId,
    bool loadMore = false,
  }) async {
    if (!loadMore) {
      _lastDocument = null;
      _hasMore = true;
    }

    if (!_hasMore) return [];

    try {
      print('🔄 [CHAT_SERVICE] Chargement lot suivant - loadMore: $loadMore');

      var query = _firestore
          .collection('Chats')
          .where(Filter.or(
        Filter('receiver_id', isEqualTo: currentUserId),
        Filter('sender_id', isEqualTo: currentUserId),
      ))
          .where("type", isEqualTo: ChatType.USER.name)
          .orderBy('updated_at', descending: true)
          .limit(pageSize);

      if (loadMore && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final chatSnapshot = await query.get();

      if (chatSnapshot.docs.isEmpty) {
        _hasMore = false;
        return [];
      }

      _lastDocument = chatSnapshot.docs.last;
      _hasMore = chatSnapshot.docs.length == pageSize;

      List<ChatWithLastMessage> listChats = [];

      // Traiter les chats en parallèle
      List<Future<ChatWithLastMessage?>> futures = [];

      for (var chatDoc in chatSnapshot.docs) {
        futures.add(_processChatDocument(chatDoc, currentUserId));
      }

      final results = await Future.wait(futures);
      listChats.addAll(results.whereType<ChatWithLastMessage>());

      print('✅ [CHAT_SERVICE] Lot chargé: ${listChats.length} chats');
      return listChats;
    } catch (e) {
      print('❌ [CHAT_SERVICE] Erreur: $e');
      return [];
    }
  }

  // Stream pour écouter les mises à jour des messages (lu/non lu)
  Stream<Map<String, dynamic>> getMessageUpdatesStream(String currentUserId) {
    return _firestore
        .collection('Messages')
        .where('receiverBy', isEqualTo: currentUserId)
        .where('is_valide', isEqualTo: true)
        .snapshots()
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

  // Traiter un document chat
  Future<ChatWithLastMessage?> _processChatDocument(
      QueryDocumentSnapshot chatDoc, String currentUserId) async {
    try {
      Chat chat = Chat.fromJson(chatDoc.data() as Map<String, dynamic>);

      final otherUserId = currentUserId == chat.receiverId
          ? chat.senderId
          : chat.receiverId;

      if (otherUserId != null) {
        final userData = await _getUserData(otherUserId);
        if (userData != null) {
          chat.chatFriend = userData;
          chat.receiver = userData;

          final lastMessage = await _getLastMessageForChat(chat.docId!);

          return ChatWithLastMessage(
            chat: chat,
            lastMessage: lastMessage,
          );
        }
      }
      return null;
    } catch (e) {
      print("❌ [CHAT_SERVICE] Erreur: $e");
      return null;
    }
  }

  // Récupérer le dernier message
  Future<Message?> _getLastMessageForChat(String chatId) async {
    if (_lastMessagesCache.containsKey(chatId)) {
      return _lastMessagesCache[chatId];
    }

    try {
      final querySnapshot = await _firestore
          .collection('Messages')
          .where('chat_id', isEqualTo: chatId)
          .where('is_valide', isEqualTo: true)
          .orderBy('create_at_time_spam', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final message = Message.fromJson(querySnapshot.docs.first.data());
        _lastMessagesCache[chatId] = message;
        return message;
      }
    } catch (e) {
      print("❌ [LAST_MESSAGE] Erreur: $e");
    }

    return null;
  }

  // Récupérer les données utilisateur
  Future<UserData?> _getUserData(String userId) async {
    if (_usersCache.containsKey(userId)) {
      return _usersCache[userId];
    }

    try {
      final userDoc = await _firestore
          .collection('Users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final userData = UserData.fromJson(userDoc.data()!);
        _usersCache[userId] = userData;
        return userData;
      }
    } catch (e) {
      print("❌ [USER_DATA] Erreur: $e");
    }

    return null;
  }

  // RECHERCHE DE CONVERSATIONS
  Future<List<Chat>> searchChats({
    required String query,
    required String currentUserId,
  }) async {
    print('🔍 [SEARCH] Recherche avec query: "$query"');

    if (query.isEmpty) return [];

    try {
      final List<Future> futures = [];

      // Rechercher les chats existants
      final chatsFuture = _firestore
          .collection('Chats')
          .where(Filter.or(
        Filter('receiver_id', isEqualTo: currentUserId),
        Filter('sender_id', isEqualTo: currentUserId),
      ))
          .where("type", isEqualTo: ChatType.USER.name)
          .get();

      // Rechercher les utilisateurs
      final usersFuture = _firestore
          .collection('Users')
          .where('pseudo', isGreaterThanOrEqualTo: query)
          .where('pseudo', isLessThan: query + 'z')
          .limit(20)
          .get();

      futures.add(chatsFuture);
      futures.add(usersFuture);

      final results = await Future.wait(futures);
      final chatsSnapshot = results[0] as QuerySnapshot;
      final usersSnapshot = results[1] as QuerySnapshot;

      print('📊 [SEARCH] Résultats: ${chatsSnapshot.docs.length} chats, ${usersSnapshot.docs.length} users');

      List<Chat> foundChats = [];

      // Traiter les conversations existantes
      for (var chatDoc in chatsSnapshot.docs) {
        Chat chat = Chat.fromJson(chatDoc.data() as Map<String, dynamic>);

        final otherUserId = currentUserId == chat.receiverId
            ? chat.senderId
            : chat.receiverId;

        if (otherUserId != null) {
          final userData = await _getUserData(otherUserId);
          if (userData != null && userData.pseudo != null) {
            chat.chatFriend = userData;
            chat.receiver = userData;

            if (userData.pseudo!.toLowerCase().contains(query.toLowerCase())) {
              foundChats.add(chat);
              print('✅ [SEARCH] Chat trouvé: ${userData.pseudo}');
            }
          }
        }
      }

      // Ajouter les utilisateurs trouvés qui n'ont pas de conversation
      for (var userDoc in usersSnapshot.docs) {
        UserData userData = UserData.fromJson(userDoc.data() as Map<String, dynamic>);

        if (userData.id == currentUserId) continue;

        bool alreadyInResults = foundChats.any((chat) =>
        chat.chatFriend != null && chat.chatFriend!.id == userData.id);

        if (!alreadyInResults && userData.pseudo != null) {
          Chat newChat = Chat(
            id: 'search_${userData.id}',
            senderId: currentUserId,
            receiverId: userData.id!,
            lastMessage: 'Démarrer une conversation',
            type: ChatType.USER.name,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            receiver: userData,
            chatFriend: userData,
          );
          foundChats.add(newChat);
          print('➕ [SEARCH] Nouveau chat de recherche: ${userData.pseudo}');
        }
      }

      print('🎯 [SEARCH] Recherche terminée: ${foundChats.length} résultats');
      return foundChats;
    } catch (e) {
      print("❌ [SEARCH] Erreur de recherche: $e");
      return [];
    }
  }

  // CRÉER OU RÉCUPÉRER UNE CONVERSATION
  Future<Chat> createOrGetChat({
    required Chat chat,
    required String currentUserId,
  }) async {
    print('💬 [CREATE_CHAT] Création/récupération chat');

    // Si c'est un chat de recherche (préfixe search_)
    if (chat.id != null && chat.id!.startsWith('search_')) {
      print('🔍 [CREATE_CHAT] Recherche chat existant...');

      final String docId1 = '${chat.senderId}${chat.receiverId}';
      final String docId2 = '${chat.receiverId}${chat.senderId}';

      final existingChats = await _firestore
          .collection('Chats')
          .where(Filter.or(
        Filter('docId', isEqualTo: docId1),
        Filter('docId', isEqualTo: docId2),
      ))
          .limit(1)
          .get();

      if (existingChats.docs.isNotEmpty) {
        print('✅ [CREATE_CHAT] Chat existant trouvé');
        Chat existingChat = Chat.fromJson(existingChats.docs.first.data());
        existingChat.chatFriend = chat.chatFriend;
        existingChat.receiver = chat.receiver;
        return existingChat;
      } else {
        print('➕ [CREATE_CHAT] Création nouveau chat');
        String chatId = _firestore.collection('Chats').doc().id;
        Chat newChat = Chat(
          docId: docId1,
          id: chatId,
          senderId: chat.senderId!,
          receiverId: chat.receiverId!,
          lastMessage: '',
          type: ChatType.USER.name,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          receiver: chat.chatFriend,
          chatFriend: chat.chatFriend,
        );

        await _firestore
            .collection('Chats')
            .doc(chatId)
            .set(newChat.toJson());

        return newChat;
      }
    }

    // Si le chat a un ID valide, le retourner directement
    if (chat.id != null && !chat.id!.startsWith('search_')) {
      // Mettre à jour les infos utilisateur si nécessaire
      if (chat.chatFriend != null) {
        chat.receiver = chat.chatFriend;
      }
      return chat;
    }

    // Par défaut, essayer de trouver par docId
    final String docId1 = '${chat.senderId}${chat.receiverId}';
    final String docId2 = '${chat.receiverId}${chat.senderId}';

    final existingChats = await _firestore
        .collection('Chats')
        .where(Filter.or(
      Filter('docId', isEqualTo: docId1),
      Filter('docId', isEqualTo: docId2),
    ))
        .limit(1)
        .get();

    if (existingChats.docs.isNotEmpty) {
      Chat existingChat = Chat.fromJson(existingChats.docs.first.data());
      existingChat.chatFriend = chat.chatFriend;
      existingChat.receiver = chat.receiver;
      return existingChat;
    }

    // Créer un nouveau chat
    String chatId = _firestore.collection('Chats').doc().id;
    Chat newChat = Chat(
      docId: docId1,
      id: chatId,
      senderId: chat.senderId!,
      receiverId: chat.receiverId!,
      lastMessage: '',
      type: ChatType.USER.name,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      receiver: chat.chatFriend,
      chatFriend: chat.chatFriend,
    );

    await _firestore.collection('Chats').doc(chatId).set(newChat.toJson());
    return newChat;
  }

  // Vider le cache
  void clearCache() {
    _lastMessagesCache.clear();
    _usersCache.clear();
    _lastDocument = null;
    _hasMore = true;
  }

  bool get hasMore => _hasMore;

  // Réinitialiser la pagination
  void resetPagination() {
    _lastDocument = null;
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
