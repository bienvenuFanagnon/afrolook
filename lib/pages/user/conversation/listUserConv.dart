import 'package:afrotok/models/chatmodels/message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../theme/app_colors.dart';
import '../../../services/chat_service.dart';
import '../../../pages/chat/myChat.dart';
import '../../home/user_presence_widget.dart';
import '../../pub/native_ad_widget.dart';

class ListUserChatsOptimized extends StatefulWidget {
  const ListUserChatsOptimized({super.key});

  @override
  State<ListUserChatsOptimized> createState() => _ListUserChatsOptimizedState();
}

class _ListUserChatsOptimizedState extends State<ListUserChatsOptimized> {
  late UserAuthProvider authProvider;
  late ChatService chatService;

  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<Chat> _searchResults = [];
  bool _isSearchLoading = false;

  // Gestion de la pagination par lots de 5 - chargement automatique
  List<ChatWithLastMessage> _chats = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  // Stream pour les mises à jour des messages en temps réel
  Stream<List<ChatWithLastMessage>>? _chatsStream;

  // Amis récents (top 7 avec dernière activité)
  List<UserData> _recentFriends = [];
  bool _loadingRecentFriends = true;
  static const int maxRecentFriends = 7;

  // Pour éviter les setState pendant le build
  bool _hasPendingUpdate = false;

  late AppColors _colors;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    chatService = ChatService();

    _scrollController.addListener(_onScroll);

    // Initialiser le stream des chats
    _initChatsStream();
    _loadRecentFriends();
  }

  void _initChatsStream() {
    // Créer un stream combiné pour les mises à jour en temps réel
    _chatsStream = FirebaseFirestore.instance
        .collection('Chats')
        .where(Filter.or(
      Filter('receiver_id', isEqualTo: authProvider.loginUserData.id!),
      Filter('sender_id', isEqualTo: authProvider.loginUserData.id!),
    ))
        .where("type", isEqualTo: ChatType.USER.name)
        .orderBy('updated_at', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      print('📨 [STREAM] Reçu ${snapshot.docs.length} chats de Firestore');

      List<ChatWithLastMessage> listChats = [];
      List<Future<ChatWithLastMessage?>> futures = [];

      for (var chatDoc in snapshot.docs) {
        futures.add(_processChatDocument(chatDoc));
      }

      final results = await Future.wait(futures);
      listChats.addAll(results.whereType<ChatWithLastMessage>());

      // Trier par updated_at décroissant
      listChats.sort((a, b) => (b.chat.updatedAt ?? 0).compareTo(a.chat.updatedAt ?? 0));

      if (mounted) {
        setState(() {
          _chats = listChats;
          _isLoading = false;
          _hasMore = false; // Plus besoin de pagination, tout est en stream
        });
      }

      return listChats;
    });
  }

  Future<ChatWithLastMessage?> _processChatDocument(QueryDocumentSnapshot chatDoc) async {
    try {
      Chat chat = Chat.fromJson(chatDoc.data() as Map<String, dynamic>);

      final otherUserId = authProvider.loginUserData.id == chat.receiverId
          ? chat.senderId
          : chat.receiverId;

      if (otherUserId != null) {
        final userData = await _getUserData(otherUserId);
        if (userData != null) {
          chat.chatFriend = userData;
          chat.receiver = userData;

          // Récupérer le dernier message avec stream
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

  Future<UserData?> _getUserData(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        return UserData.fromJson(userDoc.data()!);
      }
    } catch (e) {
      print("❌ [USER_DATA] Erreur: $e");
    }
    return null;
  }

  Future<Message?> _getLastMessageForChat(String chatId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('Messages')
          .where('chat_id', isEqualTo: chatId)
          .where('is_valide', isEqualTo: true)
          .orderBy('create_at_time_spam', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return Message.fromJson(querySnapshot.docs.first.data());
      }
    } catch (e) {
      print("❌ [LAST_MESSAGE] Erreur: $e");
    }
    return null;
  }

  // Stream pour écouter les nouveaux messages en temps réel et mettre à jour l'affichage
  void _listenToMessageUpdates() {
    FirebaseFirestore.instance
        .collection('Messages')
        .where(Filter.or(
      Filter('receiverBy', isEqualTo: authProvider.loginUserData.id!),
      Filter('sendBy', isEqualTo: authProvider.loginUserData.id!),
    ))
        .where('is_valide', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      for (var doc in snapshot.docChanges) {
        if (doc.type == DocumentChangeType.added || doc.type == DocumentChangeType.modified) {
          final message = Message.fromJson(doc.doc.data() as Map<String, dynamic>);
          _updateChatWithNewMessage(message);
        }
      }
    });
  }

  void _updateChatWithNewMessage(Message message) {
    setState(() {
      final chatIndex = _chats.indexWhere(
              (c) => c.chat.docId == message.chat_id
      );

      if (chatIndex != -1) {
        // Mettre à jour le dernier message
        _chats[chatIndex].lastMessage = message;

        // Mettre à jour le timestamp du chat
        _chats[chatIndex].chat.updatedAt = message.create_at_time_spam;
        _chats[chatIndex].chat.lastMessage = message.messageType == 'text'
            ? message.message
            : (message.messageType == 'image' ? '📷 Image' : '🎤 Audio');

        // Mettre à jour le compteur de non-lus
        final isCurrentUserSender = authProvider.loginUserData.id == message.sendBy;
        if (!isCurrentUserSender && message.message_state != MessageState.LU.name) {
          _chats[chatIndex].chat.your_msg_not_read = (_chats[chatIndex].chat.your_msg_not_read ?? 0) + 1;
        }
      }

      // Re-trier les chats par date
      _chats.sort((a, b) => (b.chat.updatedAt ?? 0).compareTo(a.chat.updatedAt ?? 0));
    });
  }

  void _loadMoreChats() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    final moreChats = await chatService.getNextChatsBatch(
      currentUserId: authProvider.loginUserData.id!,
      loadMore: true,
    );

    if (!mounted) return;

    setState(() {
      _chats.addAll(moreChats);
      _isLoadingMore = false;
      _hasMore = chatService.hasMore;
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200 &&
        _hasMore &&
        !_isLoadingMore &&
        !_isSearching) {
      _loadMoreChats();
    }
  }

  // Vérifier si un utilisateur est en ligne (dans les 10 minutes)
  bool _isUserOnline(UserData user) {
    final bool isConnected = user.state == UserState.ONLINE.name;
    final int lastTimeActive = user.last_time_active ?? 0;
    final int now = DateTime.now().millisecondsSinceEpoch;
    const int tenMinutesInMs = 600000;
    final bool isUnderThreshold = (now - lastTimeActive) < tenMinutesInMs;
    return isConnected && isUnderThreshold;
  }

  // Charger les 7 derniers amis actifs (basé sur last_time_active)
  Future<void> _loadRecentFriends() async {
    if (!mounted) return;

    setState(() {
      _loadingRecentFriends = true;
    });

    try {
      // Récupérer les amis de l'utilisateur
      final friendsSnapshot = await FirebaseFirestore.instance
          .collection('Friends')
          .where(Filter.or(
        Filter('current_user_id', isEqualTo: authProvider.loginUserData.id!),
        Filter('friend_id', isEqualTo: authProvider.loginUserData.id!),
      ))
          .get();

      if (friendsSnapshot.docs.isEmpty) {
        if (mounted) {
          setState(() {
            _loadingRecentFriends = false;
          });
        }
        return;
      }

      // Récupérer tous les IDs des amis
      List<String> friendIds = [];
      for (var doc in friendsSnapshot.docs) {
        final data = doc.data();
        final friendId = authProvider.loginUserData.id == data['current_user_id']
            ? data['friend_id']
            : data['current_user_id'];
        if (friendId != null && friendId != authProvider.loginUserData.id) {
          friendIds.add(friendId as String);
        }
      }

      if (friendIds.isEmpty) {
        if (mounted) {
          setState(() {
            _loadingRecentFriends = false;
          });
        }
        return;
      }

      // Récupérer tous les amis
      List<UserData> allFriends = [];

      for (int i = 0; i < friendIds.length; i += 10) {
        final batch = friendIds.skip(i).take(10).toList();
        final usersSnapshot = await FirebaseFirestore.instance
            .collection('Users')
            .where('id', whereIn: batch)
            .get();

        for (var doc in usersSnapshot.docs) {
          allFriends.add(UserData.fromJson(doc.data()));
        }
      }

      // Trier par last_time_active décroissant (les plus récents d'abord)
      allFriends.sort((a, b) => (b.last_time_active ?? 0).compareTo(a.last_time_active ?? 0));

      // Prendre les 7 plus récents
      final recentFriends = allFriends.take(maxRecentFriends).toList();

      if (mounted) {
        setState(() {
          _recentFriends = recentFriends;
          _loadingRecentFriends = false;
        });
      }
    } catch (e) {
      print('Erreur chargement amis récents: $e');
      if (mounted) {
        setState(() {
          _loadingRecentFriends = false;
        });
      }
    }
  }

  Future<void> _searchChats(String query) async {
    if (query.isEmpty) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchResults.clear();
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isSearching = true;
        _isSearchLoading = true;
      });
    }

    try {
      final results = await chatService.searchChats(
        query: query,
        currentUserId: authProvider.loginUserData.id!,
      );

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearchLoading = false;
        });
      }
    } catch (e) {
      print("Erreur recherche: $e");
      if (mounted) {
        setState(() {
          _isSearchLoading = false;
          _searchResults = [];
        });
      }
    }
  }

  Future<void> _openChat(Chat chat) async {
    try {
      final resultChat = await chatService.createOrGetChat(
        chat: chat,
        currentUserId: authProvider.loginUserData.id!,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        PageTransition(
          type: PageTransitionType.fade,
          child: MyChat(
            title: 'mon chat',
            chat: resultChat,
          ),
        ),
      );
    } catch (e) {
      print("Erreur ouverture chat: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur lors de l'ouverture du chat"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createAndOpenChat(UserData user) async {
    try {
      final tempChat = Chat(
        id: 'temp_${user.id}',
        senderId: authProvider.loginUserData.id,
        receiverId: user.id,
        chatFriend: user,
        receiver: user,
        type: ChatType.USER.name,
      );

      final resultChat = await chatService.createOrGetChat(
        chat: tempChat,
        currentUserId: authProvider.loginUserData.id!,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        PageTransition(
          type: PageTransitionType.fade,
          child: MyChat(
            title: 'mon chat',
            chat: resultChat,
          ),
        ),
      );
    } catch (e) {
      print("Erreur création chat: $e");
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: _colors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Section amis récents (top 7 avec dernière activité)
          if (!_isSearching && !_loadingRecentFriends && _recentFriends.isNotEmpty)
            _buildRecentFriendsSection(),
          if (!_isSearching && _recentFriends.isNotEmpty)
            Divider(height: 1, color: _colors.textSecondary),
          if (!_isSearching) _buildHeader(),
          Expanded(
            child: _isSearching
                ? _buildSearchResults()
                : StreamBuilder<List<ChatWithLastMessage>>(
              stream: _chatsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 48),
                        SizedBox(height: 16),
                        Text(
                          "Erreur de chargement",
                          style: TextStyle(color: Colors.white),
                        ),
                        SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            _initChatsStream();
                          },
                          child: Text(
                            "Réessayer",
                            style: TextStyle(color: _colors.primary),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return _buildLoadingSkeleton();
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState();
                }

                return _buildChatList(snapshot.data!);
              },
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _colors.background,
      elevation: 0,
      title: _isSearching
          ? TextField(
        controller: _searchController,
        autofocus: true,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Rechercher une conversation...",
          hintStyle: TextStyle(color: _colors.border),
          border: InputBorder.none,
        ),
        onChanged: _searchChats,
      )
          : Text(
        "Conversations",
        style: TextStyle(
          color: _colors.accent,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      actions: [
        _isSearching
            ? IconButton(
          icon: Icon(Icons.close, color: _colors.accent),
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
              icon: Icon(Icons.search, color: _colors.accent),
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
            IconButton(
              icon: Icon(Icons.people, color: _colors.accent),
              onPressed: () {
                Navigator.pushNamed(context, '/amis');
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentFriendsSection() {
    final bool hasMoreFriends = _recentFriends.length >= maxRecentFriends;

    return Container(
      height: 140,
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "RÉCEMMENT ACTIFS",
                  style: TextStyle(
                    color: _colors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                if (hasMoreFriends)
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/amis');
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                      minimumSize: Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      "Voir plus d'amis",
                      style: TextStyle(
                        color: _colors.primary,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 4),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: _recentFriends.length,
              itemBuilder: (context, index) {
                final user = _recentFriends[index];
                final bool isOnline = _isUserOnline(user);
                final String lastActiveText = _getLastActiveText(user.last_time_active ?? 0);

                return GestureDetector(
                  onTap: () => _createAndOpenChat(user),
                  child: Container(
                    width: 70,
                    margin: EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundImage: user.imageUrl != null && user.imageUrl!.isNotEmpty
                                  ? NetworkImage(user.imageUrl!)
                                  : AssetImage('assets/icon/amixilo3.png') as ImageProvider,
                              backgroundColor: _colors.textSecondary,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: UserPresenceWidget(
                                userId: user.id!,
                                size: 12.0, // Contrôle de la taille du point vert
                                showTextStatus: false, // Uniquement le point vert sur l'avatar
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          '@${user.pseudo ?? ""}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          isOnline ? "En ligne" : lastActiveText,
                          style: TextStyle(
                            color: isOnline ? _colors.primary : _colors.border,
                            fontSize: 9,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getLastActiveText(int lastTimeActive) {
    final DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(lastTimeActive);
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return "à l'instant";
    } else if (difference.inMinutes < 60) {
      return "il y a ${difference.inMinutes} min";
    } else if (difference.inHours < 24) {
      return "il y a ${difference.inHours} h";
    } else if (difference.inDays < 7) {
      return "il y a ${difference.inDays} j";
    } else {
      return DateFormat('dd/MM').format(dateTime);
    }
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "MESSAGES",
            style: TextStyle(
              color: _colors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          Text(
            "@${authProvider.loginUserData.pseudo}",
            style: TextStyle(
              color: _colors.border,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(List<ChatWithLastMessage> chats) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: chats.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: _buildAdBanner(key: 'chat_list_first_ad'),
          );
        }

        final chatIndex = index - 1;

        if (chatIndex >= chats.length) {
          return SizedBox.shrink();
        }

        final chatWithMessage = chats[chatIndex];
        final Chat chat = chatWithMessage.chat;
        final Message? lastMessage = chatWithMessage.lastMessage;

        final int unreadCount = _getUnreadCount(chat);
        final bool isOnline = _isUserOnline(chat.chatFriend ?? UserData());
        final bool isLastMessageFromMe = _isLastMessageFromCurrentUser(lastMessage);

        return GestureDetector(
          onTap: () => _openChat(chat),
          child: ConversationList(
            name: "@${chat.chatFriend?.pseudo ?? 'Utilisateur'}",
            messageText: _getMessagePreview(lastMessage),
            imageUrl: chat.chatFriend?.imageUrl ?? '',
            time: _formatTime(chat.updatedAt),
            isMessageRead: unreadCount == 0,
            isOnline: isOnline,
            unreadCount: unreadCount,
            isTyping: false,
            isLastMessageFromMe: isLastMessageFromMe,
            messageStatus: _getMessageStatus(lastMessage),
            id_user: chat.chatFriend!.id!,
          ),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_searchController.text.isEmpty) {
      return Center(
        child: Text(
          "Tapez pour rechercher des conversations",
          style: TextStyle(color: _colors.border),
        ),
      );
    }

    if (_isSearchLoading) {
      return _buildLoadingSkeleton();
    }

    if (_searchResults.isEmpty) {
      return ListView(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: _buildAdBanner(key: 'search_empty_ad'),
          ),
          SizedBox(height: 16),
          _buildNoSearchResults(),
        ],
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: _buildAdBanner(key: 'search_results_first_ad'),
          );
        }

        final searchIndex = index - 1;
        final Chat chat = _searchResults[searchIndex];
        final bool isSearchResult = chat.id != null && chat.id!.startsWith('search_');
        final int unreadCount = _getUnreadCount(chat);
        final bool isOnline = _isUserOnline(chat.chatFriend ?? UserData());

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
              id_user: chat.chatFriend!.id!
          ),
        );
      },
    );
  }

  String _getMessagePreview(Message? lastMessage) {
    if (lastMessage == null) return 'Aucun message';

    switch (lastMessage.messageType) {
      case 'text':
        return lastMessage.message;
      case 'image':
        return '📷 Image${lastMessage.imageText != null ? ': ${lastMessage.imageText}' : ''}';
      case 'voice':
        return '🎤 Message audio';
      default:
        return lastMessage.message;
    }
  }

  bool _isLastMessageFromCurrentUser(Message? lastMessage) {
    if (lastMessage == null) return false;
    return lastMessage.sendBy == authProvider.loginUserData.id;
  }

  Widget _getMessageStatus(Message? lastMessage) {
    if (lastMessage == null || !_isLastMessageFromCurrentUser(lastMessage)) {
      return SizedBox.shrink();
    }

    switch (lastMessage.message_state) {
      case 'LU':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.done_all, color: _colors.primary, size: 16),
            SizedBox(width: 2),
            Icon(Icons.done_all, color: _colors.primary, size: 16),
          ],
        );
      case 'NONLU':
        return Icon(Icons.done, color: _colors.border, size: 16);
      default:
        return Icon(Icons.access_time, color: _colors.border, size: 16);
    }
  }

  int _getUnreadCount(Chat chat) {
    final isCurrentUserSender = authProvider.loginUserData.id == chat.senderId;
    return isCurrentUserSender ? (chat.my_msg_not_read ?? 0) : (chat.your_msg_not_read ?? 0);
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(radius: 24, backgroundColor: _colors.textSecondary),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 100, height: 16, color: _colors.textSecondary),
                    SizedBox(height: 6),
                    Container(width: 150, height: 14, color: _colors.textSecondary),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: _buildAdBanner(key: 'empty_state_ad'),
        ),
        SizedBox(height: 16),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_bubble_outline, color: _colors.accent, size: 48),
              SizedBox(height: 16),
              Text(
                "Aucune conversation",
                style: TextStyle(color: Colors.white),
              ),
              SizedBox(height: 8),
              Text(
                "Commencez une conversation avec vos amis",
                style: TextStyle(color: _colors.border, fontSize: 12),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/amis');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _colors.primary,
                  foregroundColor: _colors.background,
                ),
                child: Text("Voir mes amis"),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, color: _colors.accent, size: 48),
          SizedBox(height: 16),
          Text(
            "Aucun résultat trouvé",
            style: TextStyle(color: Colors.white),
          ),
          SizedBox(height: 8),
          Text(
            "Essayez avec d'autres termes",
            style: TextStyle(color: _colors.border, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildAdBanner({required String key}) {
    return Container(
      key: ValueKey(key),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: MrecAdWidget(
        onAdLoaded: () {
          print('✅ Native Ad chargée: $key');
        },
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

// ConversationList Widget (inchangé, gardé tel quel)
class ConversationList extends StatefulWidget {
  final String name;
  final String messageText;
  final String imageUrl;
  final String id_user;
  final String time;
  final bool isMessageRead;
  final bool isOnline;
  final int unreadCount;
  final bool isTyping;
  final bool isLoading;
  final bool isSearchResult;
  final bool isLastMessageFromMe;
  final Widget messageStatus;

  const ConversationList({
    Key? key,
    required this.name,
    required this.id_user,
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
  }) : super(key: key);

  @override
  _ConversationListState createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList> {
  late AppColors _colors;

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: _colors.background,
        border: Border(bottom: BorderSide(color: _colors.divider, width: 0.5)),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          _buildAvatar(widget.id_user),
          SizedBox(width: 16),
          _buildMessageInfo(),
          _buildTimeAndStatus(),
        ],
      ),
    );
  }

  Widget _buildAvatar(String id_user) {
    return Stack(
      children: [
        widget.isLoading
            ? CircleAvatar(
          backgroundColor: _colors.textSecondary,
          radius: 24,
        )
            : CircleAvatar(
          backgroundImage: widget.imageUrl.isNotEmpty
              ? NetworkImage(widget.imageUrl)
              : AssetImage('assets/icon/amixilo3.png') as ImageProvider,
          backgroundColor: _colors.textSecondary,
          radius: 24,
        ),
        if (!widget.isLoading)
          Positioned(
            bottom: 0,
            right: 0,
            child: UserPresenceWidget(
              userId: id_user,
              size: 12.0, // Contrôle de la taille du point vert
              showTextStatus: false, // Uniquement le point vert sur l'avatar
            ),
          )
      ],
    );
  }

  Widget _buildMessageInfo() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            widget.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _colors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 6),
          widget.isLoading
              ? Container(
            width: 150,
            height: 14,
            color: _colors.textSecondary,
          )
              : Row(
            children: [
              if (widget.isLastMessageFromMe)
                Text(
                  "Vous: ",
                  style: TextStyle(
                    fontSize: 14,
                    color: _colors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              Expanded(
                child: Text(
                  widget.isTyping ? "écrit..." : widget.messageText,
                  style: TextStyle(
                    fontSize: 14,
                    color: widget.isTyping
                        ? _colors.accent
                        : (widget.isMessageRead ? _colors.textSecondary : _colors.textPrimary),
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
    );
  }

  Widget _buildTimeAndStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (widget.time.isNotEmpty)
          Text(
            widget.time,
            style: TextStyle(
              fontSize: 12,
              color: _colors.textSecondary,
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
              color: _colors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${widget.unreadCount}',
              style: TextStyle(
                fontSize: 12,
                color: _colors.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        else if (widget.isSearchResult)
          Icon(Icons.add_circle_outline, color: _colors.primary, size: 20)
        else if (widget.isLastMessageFromMe)
            widget.messageStatus,
      ],
    );
  }
}