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

  // Pagination
  int _currentLimit = 2;
  final int _maxLimit = 100;
  final int _incrementStep = 2;
  bool _hasMoreChats = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

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

    // Écouter le scroll pour le chargement progressif
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent &&
        _hasMoreChats &&
        !_isLoadingMore &&
        !_isSearching) {
      _loadMoreChats();
    }
  }

  Future<void> _loadMoreChats() async {
    if (_currentLimit >= _maxLimit) {
      setState(() {
        _hasMoreChats = false;
      });
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    // Simuler un délai de chargement
    await Future.delayed(Duration(milliseconds: 500));

    setState(() {
      _currentLimit += _incrementStep;
      _isLoadingMore = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
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
      final chatsQuery = FirebaseFirestore.instance
          .collection('Chats')
          .where(Filter.or(
        Filter('receiver_id', isEqualTo: '${authProvider.loginUserData.id}'),
        Filter('sender_id', isEqualTo: '${authProvider.loginUserData.id}'),
      ))
          .where("type", isEqualTo: ChatType.USER.name)
          .get();

      final usersQuery = FirebaseFirestore.instance
          .collection('Users')
          .where('pseudo', isGreaterThanOrEqualTo: query)
          .where('pseudo', isLessThan: query + 'z')
          .get();

      final results = await Future.wait([chatsQuery, usersQuery]);
      final chatsSnapshot = results[0] as QuerySnapshot;
      final usersSnapshot = results[1] as QuerySnapshot;

      List<Chat> foundChats = [];

      for (var chatDoc in chatsSnapshot.docs) {
        Chat chat = Chat.fromJson(chatDoc.data() as Map<String, dynamic>);

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

          if (userData.pseudo!.toLowerCase().contains(query.toLowerCase())) {
            foundChats.add(chat);
          }
        }
      }

      for (var userDoc in usersSnapshot.docs) {
        UserData userData = UserData.fromJson(userDoc.data() as Map<String, dynamic>);

        if (userData.id == authProvider.loginUserData.id) continue;

        bool alreadyInResults = foundChats.any((chat) =>
        chat.chatFriend != null && chat.chatFriend!.id == userData.id);

        if (!alreadyInResults) {
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
        .limit(_currentLimit)
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
    if (chat.id!.startsWith('search_')) {
      final existingChats = await FirebaseFirestore.instance
          .collection('Chats')
          .where(Filter.or(
        Filter('docId', isEqualTo: '${chat.senderId}${chat.receiverId}'),
        Filter('docId', isEqualTo: '${chat.receiverId}${chat.senderId}'),
      ))
          .get();

      if (existingChats.docs.isNotEmpty) {
        Chat existingChat = Chat.fromJson(existingChats.docs.first.data());
        existingChat.chatFriend = chat.chatFriend;
        Navigator.push(
            context,
            PageTransition(
                type: PageTransitionType.fade,
                child: MyChat(
                  title: 'mon chat',
                  chat: existingChat,
                )));
      } else {
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

        Navigator.push(
            context,
            PageTransition(
                type: PageTransitionType.fade,
                child: MyChat(
                  title: 'mon chat',
                  chat: newChat,
                )));
      }
    } else {
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

  // Méthode pour déterminer si le dernier message vient de l'utilisateur actuel ou de son ami
  bool _isLastMessageFromCurrentUser(Chat chat) {
    // Vérifier si le dernier message a été envoyé par l'utilisateur actuel
    return chat.messages!.last.sendBy == authProvider.loginUserData.id;
  }

  // Méthode pour obtenir l'état du message à afficher
  Widget _getMessageStatus(Chat chat) {
    if (!_isLastMessageFromCurrentUser(chat)) {
      // Si le dernier message vient de l'ami, on n'affiche rien de spécial
      return SizedBox.shrink();
    }

    // Si le dernier message vient de l'utilisateur actuel, afficher l'état
    switch (chat.lastMessageIsRead) {
      case true:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.done_all, color: primaryGreen, size: 16),
            SizedBox(width: 2),
            Icon(Icons.done_all, color: primaryGreen, size: 16),
          ],
        );
      case true:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.done_all, color: lightGrey, size: 16),
            SizedBox(width: 2),
            Icon(Icons.done_all, color: lightGrey, size: 16),
          ],
        );
      case false:
        return Icon(Icons.done, color: lightGrey, size: 16);
      default:
        return Icon(Icons.access_time, color: lightGrey, size: 16);
    }
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
          if (!_isSearching) chatXiloWidget(),
          if (!_isSearching) Divider(height: 1, color: darkGrey),
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
      controller: _scrollController,
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final Chat chat = _searchResults[index];
        final bool isSearchResult = chat.id!.startsWith('search_');
        final int unreadCount = isSearchResult ? 0 :
        (authProvider.loginUserData.id == chat.senderId ? (chat.my_msg_not_read ?? 0) : (chat.your_msg_not_read ?? 0));
        final bool isOnline = chat.chatFriend?.state == UserState.ONLINE.name;
        final bool isLastMessageFromMe = _isLastMessageFromCurrentUser(chat);

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
            isLastMessageFromMe: isLastMessageFromMe,
            messageStatus: _getMessageStatus(chat),
          ),
        );
      },
    );
  }

  Widget _buildChatList(List<Chat> chats) {
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollNotification) {
        if (scrollNotification is ScrollEndNotification) {
          _onScroll();
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        itemCount: chats.length + (_hasMoreChats ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == chats.length) {
            return _buildLoadMoreIndicator();
          }

          final Chat chat = chats[index];
          final bool isCurrentUserSender = authProvider.loginUserData.id == chat.senderId;
          final int unreadCount = isCurrentUserSender ? (chat.my_msg_not_read ?? 0) : (chat.your_msg_not_read ?? 0);
          final bool isOnline = chat.chatFriend?.state == UserState.ONLINE.name;
          final bool isLastMessageFromMe = _isLastMessageFromCurrentUser(chat);

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
              isLastMessageFromMe: isLastMessageFromMe,
              messageStatus: _getMessageStatus(chat),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadMoreIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: _isLoadingMore
            ? CircularProgressIndicator(color: primaryGreen)
            : _hasMoreChats
            ? Text(
          "Charger plus de conversations...",
          style: TextStyle(color: lightGrey),
        )
            : Text(
          "Toutes les conversations sont chargées",
          style: TextStyle(color: lightGrey, fontSize: 12),
        ),
      ),
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
  final bool isLastMessageFromMe;
  final Widget messageStatus;

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
    this.isLastMessageFromMe = false,
    this.messageStatus = const SizedBox.shrink(),
  });

  @override
  _ConversationListState createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList> {
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
                            : Row(
                          children: [
                            if (widget.isLastMessageFromMe)
                              Text(
                                "Vous: ",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: primaryGreen,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            Expanded(
                              child: Text(
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
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

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
                Icon(Icons.add_circle_outline, color: primaryGreen, size: 20)
              else if (widget.isLastMessageFromMe)
                  widget.messageStatus,
            ],
          ),
        ],
      ),
    );
  }
}