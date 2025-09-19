import 'package:afrotok/models/chatmodels/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:insta_image_viewer/insta_image_viewer.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:searchable_listview/searchable_listview.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../constant/constColors.dart';
import '../../../constant/logo.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import '../../auth/authTest/constants.dart';
import '../../chat/chatXilo.dart';
import '../../chat/myChat.dart';
import '../../component/consoleWidget.dart';
import '../detailsOtherUser.dart';


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Modèles et providers (gardez vos imports existants)
import 'package:afrotok/models/chatmodels/message.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/userProvider.dart';
import 'package:afrotok/constant/constColors.dart';

class ListUserChats extends StatefulWidget {
  const ListUserChats({super.key});

  @override
  State<ListUserChats> createState() => _ListUserChatsState();
}

class _ListUserChatsState extends State<ListUserChats> {
  late UserAuthProvider authProvider;
  late UserProvider userProvider;
  late List<Chat> listChatsSearch = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<Chat> _searchResults = [];

  // Couleurs de la palette
  final Color primaryBlack = Colors.black;
  final Color primaryGreen = Colors.green;
  final Color primaryYellow = Colors.yellow;
  final Color lightGrey = Colors.grey.shade300;
  final Color darkGrey = Colors.grey.shade700;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Méthode de recherche dans Firebase
  Future<void> _searchChats(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults.clear();
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      // Recherche dans les conversations existantes
      final chatsQuery = FirebaseFirestore.instance
          .collection('Chats')
          .where(Filter.or(
        Filter('receiver_id', isEqualTo: '${authProvider.loginUserData.id}'),
        Filter('sender_id', isEqualTo: '${authProvider.loginUserData.id}'),
      ))
          .where("type", isEqualTo: ChatType.USER.name)
          .get();

      // Recherche dans les utilisateurs pour trouver des correspondances
      final usersQuery = FirebaseFirestore.instance
          .collection('Users')
          .where('pseudo', isGreaterThanOrEqualTo: query)
          .where('pseudo', isLessThan: query + 'z')
          .get();

      final results = await Future.wait([chatsQuery, usersQuery]);
      final chatsSnapshot = results[0] as QuerySnapshot;
      final usersSnapshot = results[1] as QuerySnapshot;

      List<Chat> foundChats = [];

      // Traiter les conversations existantes
      for (var chatDoc in chatsSnapshot.docs) {
        Chat chat = Chat.fromJson(chatDoc.data() as Map<String, dynamic>);

        // Récupérer les informations de l'utilisateur correspondant
        CollectionReference friendCollect = FirebaseFirestore.instance.collection('Users');
        QuerySnapshot querySnapshotUser = await friendCollect
            .where("id",
            isEqualTo: authProvider.loginUserData.id == chat.receiverId
                ? chat.senderId
                : chat.receiverId)
            .get();

        if (querySnapshotUser.docs.isNotEmpty) {
          UserData userData = UserData.fromJson(
              querySnapshotUser.docs.first.data() as Map<String, dynamic>);
          chat.chatFriend = userData;

          // Vérifier si le pseudo correspond à la recherche
          if (userData.pseudo!.toLowerCase().contains(query.toLowerCase())) {
            foundChats.add(chat);
          }
        }
      }

      // Vérifier si on a trouvé des utilisateurs qui ne sont pas encore dans les conversations
      for (var userDoc in usersSnapshot.docs) {
        UserData userData = UserData.fromJson(userDoc.data() as Map<String, dynamic>);

        // Éviter de s'ajouter soi-même
        if (userData.id == authProvider.loginUserData.id) continue;

        // Vérifier si cet utilisateur n'est pas déjà dans les résultats
        bool alreadyInResults = foundChats.any((chat) =>
        chat.chatFriend != null && chat.chatFriend!.id == userData.id);

        if (!alreadyInResults) {
          // Créer une conversation fictive pour l'affichage
          Chat newChat = Chat(
            id: 'search_${userData.id}',
            senderId: authProvider.loginUserData.id!,
            receiverId: userData.id!,
            lastMessage: 'Démarrer une conversation',
            type: ChatType.USER.name,
            createdAt: DateTime.now().millisecondsSinceEpoch,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            receiver: userData,
          );
          foundChats.add(newChat);
        }
      }

      setState(() {
        _searchResults = foundChats;
      });
    } catch (e) {
      print("Erreur de recherche: $e");
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
    }
  }

  Widget chatXiloWidget() {
    return GestureDetector(
      onTap: () {
        // Votre logique pour ouvrir le chat XILO
      },
      child: ConversationList(
        name: "@XILO",
        messageText: "Assistant virtuel",
        imageUrl: "",
        time: "",
        isMessageRead: false,
        isOnline: true,
        unreadCount: 0,
        isTyping: false,
      ),
    );
  }

  Stream<List<Chat>> getAllChatsData() async* {
    var chatsStream = FirebaseFirestore.instance
        .collection('Chats')
        .where(Filter.or(
      Filter('receiver_id', isEqualTo: '${authProvider.loginUserData.id}'),
      Filter('sender_id', isEqualTo: '${authProvider.loginUserData.id}'),
    ))
        .where("type", isEqualTo: ChatType.USER.name)
        .orderBy('updated_at', descending: true)
        .snapshots();

    List<Chat> listChats = [];

    await for (var chatSnapshot in chatsStream) {
      for (var chatDoc in chatSnapshot.docs) {
        CollectionReference friendCollect = FirebaseFirestore.instance.collection('Users');
        QuerySnapshot querySnapshotUser = await friendCollect
            .where("id",
            isEqualTo: authProvider.loginUserData.id == chatDoc["receiver_id"]
                ? chatDoc["sender_id"]
                : chatDoc["receiver_id"]!)
            .get();

        List<UserData> userList = querySnapshotUser.docs
            .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
            .toList();

        if (userList.isNotEmpty) {
          Chat usersChat = Chat.fromJson(chatDoc.data());
          usersChat.chatFriend = userList.first;
          usersChat.receiver = userList.first;
          listChats.add(usersChat);
        }
      }
      listChatsSearch = List.from(listChats);
      yield listChats;
      listChats = [];
    }
  }

  // Créer ou récupérer une conversation
  Future<void> _openChat(Chat chat) async {
    // Si c'est une conversation de recherche (non existante)
    if (chat.id!.startsWith('search_')) {
      // Vérifier si une conversation existe déjà
      final existingChats = await FirebaseFirestore.instance
          .collection('Chats')
          .where(Filter.or(
        Filter('docId', isEqualTo: '${chat.senderId}${chat.receiverId}'),
        Filter('docId', isEqualTo: '${chat.receiverId}${chat.senderId}'),
      ))
          .get();

      if (existingChats.docs.isNotEmpty) {
        // Conversation existe déjà, l'ouvrir
        Chat existingChat = Chat.fromJson(existingChats.docs.first.data());
        existingChat.chatFriend = chat.chatFriend;
        // Navigation vers le chat existant
        // Navigator.push(...);
      } else {
        // Créer une nouvelle conversation
        String chatId = FirebaseFirestore.instance.collection('Chats').doc().id;
        Chat newChat = Chat(
          docId: '${chat.senderId}${chat.receiverId}',
          id: chatId,
          senderId: chat.senderId!,
          receiverId: chat.receiverId!,
          lastMessage: '',
          type: ChatType.USER.name,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
          receiver: chat.chatFriend,
        );

        await FirebaseFirestore.instance
            .collection('Chats')
            .doc(chatId)
            .set(newChat.toJson());

        // Navigation vers le nouveau chat
        Navigator.push(
            context,
            PageTransition(
                type: PageTransitionType.fade,
                child: MyChat(
                  title: 'mon chat',
                  chat: chat,
                )));      }
    } else {
      // Conversation existante, l'ouvrir normalement
      // Navigation vers le chat
      Navigator.push(
          context,
          PageTransition(
              type: PageTransitionType.fade,
              child: MyChat(
                title: 'mon chat',
                chat: chat,
              )));
    }
  }

  Future<Chat> getChatsData(Friends amigo) async {
    // Définissez la requête
    var friendsStream = FirebaseFirestore.instance
        .collection('Chats')
        .where(Filter.or(
      Filter('docId', isEqualTo: '${amigo.friendId}${amigo.currentUserId}'),
      Filter('docId', isEqualTo: '${amigo.currentUserId}${amigo.friendId}'),
    ))
        .snapshots();

// Obtenez la liste des utilisateurs
    //List<DocumentSnapshot> users = await usersQuery.sget();
    Chat usersChat = Chat();

    if (await friendsStream.isEmpty) {
      printVm("pas de chat ");
      String chatId = FirebaseFirestore.instance.collection('Chats').doc().id;
      Chat chat = Chat(
        docId: '${amigo.friendId}${amigo.currentUserId}',
        id: chatId,
        senderId: authProvider.loginUserData.id == amigo.friendId
            ? '${amigo.friendId}'
            : '${amigo.currentUserId}',
        receiverId: authProvider.loginUserData.id == amigo.friendId
            ? '${amigo.currentUserId}'
            : '${amigo.friendId}',
        lastMessage: 'hi',

        type: ChatType.USER.name,
        createdAt: DateTime.now()
            .millisecondsSinceEpoch, // Get current time in milliseconds
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        // Optional: You can initialize sender and receiver with UserData objects, and messages with a list of Message objects
      );
      await FirebaseFirestore.instance
          .collection('Chats')
          .doc(chatId)
          .set(chat.toJson());
      usersChat = chat;
    } else {
      printVm("le chat existe  ");
      printVm("stream :${friendsStream}");
      usersChat = await friendsStream.first.then((value) async {
        printVm("stream value l :${value.docs.length}");
        if (value.docs.length <= 0) {
          printVm("pas de chat ");
          String chatId =
              FirebaseFirestore.instance.collection('Chats').doc().id;
          Chat chat = Chat(
            docId: '${amigo.friendId}${amigo.currentUserId}',
            id: chatId,
            senderId: authProvider.loginUserData.id == amigo.friendId
                ? '${amigo.friendId}'
                : '${amigo.currentUserId}',
            receiverId: authProvider.loginUserData.id == amigo.friendId
                ? '${amigo.currentUserId}'
                : '${amigo.friendId}',
            lastMessage: 'hi',

            type: ChatType.USER.name,
            createdAt: DateTime.now()
                .millisecondsSinceEpoch, // Get current time in milliseconds
            updatedAt: DateTime.now().millisecondsSinceEpoch,
            // Optional: You can initialize sender and receiver with UserData objects, and messages with a list of Message objects
          );
          await FirebaseFirestore.instance
              .collection('Chats')
              .doc(chatId)
              .set(chat.toJson());
          usersChat = chat;
          return chat;
        } else {
          return Chat.fromJson(value.docs.first.data());
        }
      });
      CollectionReference messageCollect =
      await FirebaseFirestore.instance.collection('Messages');
      QuerySnapshot querySnapshotMessage =
      await messageCollect.where("chat_id", isEqualTo: usersChat.id!).get();
      // Afficher la liste
      List<Message> messageList = querySnapshotMessage.docs
          .map((doc) => Message.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      if (messageList.isEmpty) {
        usersChat.messages = [];
        userProvider.chat = usersChat;
        printVm("messgae vide ");
      } else {
        printVm("have messages");
        usersChat.messages = messageList;
        userProvider.chat = usersChat;
      }

      /////////////ami//////////
      CollectionReference friendCollect =
      await FirebaseFirestore.instance.collection('Users');
      QuerySnapshot querySnapshotUserSender = await friendCollect
          .where("id",
          isEqualTo: authProvider.loginUserData.id == amigo.friendId
              ? '${amigo.friendId}'
              : '${amigo.currentUserId}')
          .get();
      // Afficher la liste
      QuerySnapshot querySnapshotUserReceiver = await friendCollect
          .where("id",
          isEqualTo: authProvider.loginUserData.id == amigo.friendId
              ? '${amigo.currentUserId}'
              : '${amigo.friendId}')
          .get();

      List<UserData> receiverUserList = querySnapshotUserReceiver.docs
          .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      usersChat.receiver = receiverUserList.first;

      List<UserData> senderUserList = querySnapshotUserSender.docs
          .map((doc) => UserData.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      usersChat.sender = senderUserList.first;
    }

    return usersChat;
  }





  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBlack,
      appBar: AppBar(
        backgroundColor: primaryBlack,
        elevation: 0,
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Rechercher une conversation...",
            hintStyle: TextStyle(color: lightGrey),
            border: InputBorder.none,
          ),
          onChanged: _searchChats,
        )
            : Text(
          "Conversations",
          style: TextStyle(
            color: primaryYellow,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          _isSearching
              ? IconButton(
            icon: Icon(Icons.close, color: primaryYellow),
            onPressed: () {
              setState(() {
                _isSearching = false;
                _searchController.clear();
                _searchResults.clear();
              });
            },
          )
              : Row(
            children: [
              IconButton(
                icon: Icon(Icons.search, color: primaryYellow),
                onPressed: () {
                  setState(() {
                    _isSearching = true;
                  });
                },
              ),
              // Bouton pour aller à la liste d'amis
              IconButton(
                icon: Icon(Icons.people, color: primaryYellow),
                onPressed: () {
                  Navigator.pushNamed(context, '/amis');
                },
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Section XILO
          if (!_isSearching) chatXiloWidget(),

          if (!_isSearching) Divider(height: 1, color: darkGrey),

          // En-tête des conversations
          if (!_isSearching)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "MESSAGES",
                    style: TextStyle(
                      color: primaryGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    "${authProvider.loginUserData.pseudo}",
                    style: TextStyle(
                      color: lightGrey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

          // Liste des conversations ou résultats de recherche
          Expanded(
            child: _isSearching
                ? _buildSearchResults()
                : StreamBuilder<List<Chat>>(
              stream: getAllChatsData(),
              builder: (context, AsyncSnapshot<List<Chat>> snapshot) {
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  return _buildChatList(snapshot.data!);
                } else if (snapshot.hasError) {
                  return _buildErrorWidget();
                } else if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingSkeleton();
                } else {
                  return _buildEmptyState();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchController.text.isEmpty) {
      return Center(
        child: Text(
          "Tapez pour rechercher des conversations",
          style: TextStyle(color: lightGrey),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, color: primaryYellow, size: 48),
            SizedBox(height: 16),
            Text(
              "Aucun résultat trouvé",
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 8),
            Text(
              "Essayez avec d'autres termes",
              style: TextStyle(color: lightGrey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final Chat chat = _searchResults[index];
        final bool isSearchResult = chat.id!.startsWith('search_');
        final int unreadCount = isSearchResult ? 0 :
        (authProvider.loginUserData.id == chat.senderId ? (chat.my_msg_not_read ?? 0) : (chat.your_msg_not_read ?? 0));
        final bool isOnline = chat.chatFriend?.state == UserState.ONLINE.name;

        return GestureDetector(
          onTap: () => _openChat(chat),
          child: ConversationList(
            name: "@${chat.chatFriend?.pseudo ?? 'Utilisateur'}",
            messageText: isSearchResult ? "Démarrer une conversation" : (chat.lastMessage ?? ''),
            imageUrl: chat.chatFriend?.imageUrl ?? '',
            time: isSearchResult ? "" : _formatTime(chat.updatedAt),
            isMessageRead: unreadCount == 0,
            isOnline: isOnline,
            unreadCount: unreadCount,
            isTyping: false,
            isSearchResult: isSearchResult,
          ),
        );
      },
    );
  }

  Widget _buildChatList(List<Chat> chats) {
    return ListView.builder(
      itemCount: chats.length,
      itemBuilder: (context, index) {
        final Chat chat = chats[index];
        final bool isCurrentUserSender = authProvider.loginUserData.id == chat.senderId;
        final int unreadCount = isCurrentUserSender ? (chat.my_msg_not_read ?? 0) : (chat.your_msg_not_read ?? 0);
        final bool isOnline = chat.chatFriend?.state == UserState.ONLINE.name;

        return GestureDetector(
          onTap: () => _openChat(chat),
          child: ConversationList(
            name: "@${chat.chatFriend?.pseudo ?? 'Utilisateur'}",
            messageText: chat.lastMessage ?? '',
            imageUrl: chat.chatFriend?.imageUrl ?? '',
            time: _formatTime(chat.updatedAt),
            isMessageRead: unreadCount == 0,
            isOnline: isOnline,
            unreadCount: unreadCount,
            isTyping: false,
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: primaryYellow, size: 48),
          SizedBox(height: 16),
          Text(
            "Erreur de chargement",
            style: TextStyle(color: Colors.white),
          ),
          SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() {}),
            child: Text(
              "Réessayer",
              style: TextStyle(color: primaryYellow),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) {
        return ConversationList(
          name: "Chargement...",
          messageText: "Message en cours de chargement",
          imageUrl: "",
          time: "",
          isMessageRead: true,
          isOnline: false,
          unreadCount: 0,
          isTyping: false,
          isLoading: true,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, color: primaryYellow, size: 48),
          SizedBox(height: 16),
          Text(
            "Aucune conversation",
            style: TextStyle(color: Colors.white),
          ),
          SizedBox(height: 8),
          Text(
            "Commencez une conversation avec vos amis",
            style: TextStyle(color: lightGrey, fontSize: 12),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/amis');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: primaryBlack,
            ),
            child: Text("Voir mes amis"),
          ),
        ],
      ),
    );
  }

  String _formatTime(int? timestamp) {
    if (timestamp == null) return "";

    final DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return "${date.day}/${date.month}/${date.year}";
    } else if (difference.inDays > 0) {
      return "${difference.inDays}j";
    } else if (difference.inHours > 0) {
      return "${difference.inHours}h";
    } else if (difference.inMinutes > 0) {
      return "${difference.inMinutes}min";
    } else {
      return "À l'instant";
    }
  }
}

class ConversationList extends StatefulWidget {
  final String name;
  final String messageText;
  final String imageUrl;
  final String time;
  final bool isMessageRead;
  final bool isOnline;
  final int unreadCount;
  final bool isTyping;
  final bool isLoading;
  final bool isSearchResult;

  ConversationList({
    required this.name,
    required this.messageText,
    required this.imageUrl,
    required this.time,
    required this.isMessageRead,
    this.isOnline = false,
    this.unreadCount = 0,
    this.isTyping = false,
    this.isLoading = false,
    this.isSearchResult = false,
  });

  @override
  _ConversationListState createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList> {
  // Couleurs de la palette
  final Color primaryBlack = Colors.black;
  final Color primaryGreen = Colors.green;
  final Color primaryYellow = Colors.yellow;
  final Color lightGrey = Colors.grey.shade300;
  final Color darkGrey = Colors.grey.shade700;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: primaryBlack,
        border: Border(bottom: BorderSide(color: darkGrey, width: 0.5)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          // Avatar avec indicateur de statut
          Stack(
            children: [
              widget.isLoading
                  ? CircleAvatar(
                backgroundColor: darkGrey,
                radius: 24,
              )
                  : CircleAvatar(
                backgroundImage: widget.imageUrl.isNotEmpty
                    ? NetworkImage(widget.imageUrl)
                    : AssetImage('assets/icon/amixilo3.png') as ImageProvider,
                backgroundColor: darkGrey,
                radius: 24,
              ),
              if (!widget.isLoading)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: widget.isOnline ? primaryGreen : darkGrey,
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryBlack, width: 2),
                    ),
                  ),
                )
            ],
          ),

          SizedBox(width: 16),

          Expanded(
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Container(
                    color: Colors.transparent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),

                        SizedBox(height: 6),

                        widget.isLoading
                            ? Container(
                          width: 150,
                          height: 14,
                          color: darkGrey,
                        )
                            : Text(
                          widget.isTyping
                              ? "écrit..."
                              : widget.messageText,
                          style: TextStyle(
                            fontSize: 14,
                            color: widget.isTyping
                                ? primaryYellow
                                : (widget.isMessageRead ? lightGrey : Colors.white),
                            fontWeight: widget.isMessageRead
                                ? FontWeight.normal
                                : FontWeight.w500,
                            fontStyle: widget.isSearchResult ? FontStyle.italic : FontStyle.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Badge de messages non lus et heure
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (widget.time.isNotEmpty)
                Text(
                  widget.time,
                  style: TextStyle(
                    fontSize: 12,
                    color: lightGrey,
                    fontWeight: widget.isMessageRead
                        ? FontWeight.normal
                        : FontWeight.bold,
                  ),
                ),

              if (widget.time.isNotEmpty) SizedBox(height: 6),

              if (widget.unreadCount > 0)
                Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: primaryGreen,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${widget.unreadCount}',
                    style: TextStyle(
                      fontSize: 12,
                      color: primaryBlack,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else if (widget.isSearchResult)
                Icon(Icons.add_circle_outline, color: primaryGreen, size: 20),
            ],
          ),
        ],
      ),
    );
  }
}
