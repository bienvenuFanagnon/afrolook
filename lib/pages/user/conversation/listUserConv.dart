import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/layout/responsive_layout.dart';
import 'package:afrotok/utils/responsive_sheet.dart';
import 'dart:async';
import 'dart:convert';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:afrotok/models/chatmodels/message.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';

import 'package:flutter/cupertino.dart';

import 'package:flutter/widgets.dart';

import 'package:flutter_slidable/flutter_slidable.dart';


import 'package:local_auth/local_auth.dart';

import 'package:page_transition/page_transition.dart';

import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:skeletonizer/skeletonizer.dart';

import '../../../models/model_data.dart';
import '../../../services/utils/abonnement_utils.dart';

import '../../../providers/authProvider.dart';
import '../../../providers/gold_groups_provider.dart';

import '../../../theme/app_colors.dart';

import '../../../l10n/app_localizations.dart';

import '../../../services/chat_service.dart';


import '../../../pages/chat/myChat.dart';

import 'package:share_plus/share_plus.dart';

import '../../home/user_presence_widget.dart';

import '../../../widgets/user_badge_widget.dart';

import '../../pub/native_ad_widget.dart';

import '../../chat/group/create_group_page.dart';

import '../../chat/group/group_chat_page.dart';

import '../../../services/active_creators_service.dart';
import '../../../widgets/feed/sections/feed_profiles_section.dart';
import '../creator_unseen_posts_page.dart';
import '../active_creators_list_page.dart';
import '../../../services/chat_sound_service.dart';

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
  bool _isSoundMuted = false;

  // Gestion de la pagination par lots de 5 - chargement automatique
  List<ChatWithLastMessage> _chats = [];
  bool _isLoading = false;   // false: pas de skeleton bloquant au démarrage
  bool _isRefreshing = false; // indicateur discret en haut pendant sync Firebase
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  // Stream pour les mises à jour des messages en temps réel
  Stream<List<ChatWithLastMessage>>? _chatsStream;

  // Section créateurs actifs (remplace les amis récents)
  final _activeCreatorsService = ActiveCreatorsService();
  List<UserData> _creators = [];
  Map<String, int> _unseenCounts = {};
  bool _loadingCreators = true;

  // Guard : évite que le cache écrase les données Firebase déjà chargées
  bool _firebaseLoaded = false;

  // Pour éviter les setState pendant le build
  bool _hasPendingUpdate = false;

  // Verrouillage biométrique
  bool _isLocked = false;
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Groupes
  List<Map<String, dynamic>> _groups = [];
  bool _loadingGroups = false;
  String get _groupCacheKey => 'group_list_${authProvider.loginUserData.id ?? ''}';

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _groupsStreamSub;
  // Second stream pour les groupes dont l'utilisateur est propriétaire (ADM non dans member_ids)
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ownedGroupsStreamSub;

  // Groupes Gold (carousel pub) — géré par GoldGroupsProvider

  // Recherche par code de groupe
  final TextEditingController _codeSearchController = TextEditingController();
  bool _codeSearching = false;
  Map<String, dynamic>? _codeSearchResult;
  String? _codeSearchError;

  // Filtre d'affichage : 'all' | 'users' | 'groups'
  String _chatFilter = 'all';

  // Desktop 2-colonnes : conversation active dans le panneau droit
  Widget? _activeChatWidget;

  // Archives (persistées en local)
  Set<String> _archivedChatIds = {};
  String get _archiveCacheKey => 'archived_chats_${authProvider.loginUserData.id ?? ''}';

  late AppColors _colors;
  late AppLocalizations _l10n;

  // ── Cache local conversations ─────────────────────────────────────────────
  String get _convCacheKey => 'conv_list_${authProvider.loginUserData.id ?? ''}';

  Future<void> _saveConvCache(List<ChatWithLastMessage> chats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final items = chats.take(30).map((cwm) {
        final friend = cwm.chat.chatFriend;
        final lm = cwm.lastMessage;
        return {
          ...cwm.chat.toJson(),
          'friendId': friend?.id,
          'friendPseudo': friend?.pseudo,
          'friendImageUrl': friend?.imageUrl,
          'friendHasEntreprise': friend?.hasEntreprise ?? false,
          if (lm != null) 'lastMsg': lm.toJson(),
        };
      }).toList();
      await prefs.setString(_convCacheKey, jsonEncode(items));
    } catch (_) {}
  }

  Future<void> _loadConvCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_convCacheKey);
      if (raw == null) return;
      final list = jsonDecode(raw);
      if (list is! List) return;
      final chats = list.whereType<Map<String, dynamic>>().map((item) {
        final chat = Chat.fromJson(item);
        chat.chatFriend = UserData()
          ..id = item['friendId'] as String?
          ..pseudo = item['friendPseudo'] as String?
          ..imageUrl = item['friendImageUrl'] as String?
          ..hasEntreprise = item['friendHasEntreprise'] == true;
        chat.receiver = chat.chatFriend;
        Message? lastMsg;
        if (item['lastMsg'] is Map<String, dynamic>) {
          lastMsg = Message.fromJson(item['lastMsg'] as Map<String, dynamic>);
        }
        return ChatWithLastMessage(chat: chat, lastMessage: lastMsg);
      }).toList();
      if (!_firebaseLoaded && chats.isNotEmpty && mounted) {
        setState(() {
          _chats = chats;
          _isLoading = false;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveGroupCache(List<Map<String, dynamic>> groups) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_groupCacheKey, jsonEncode(groups.take(30).toList()));
    } catch (_) {}
  }

  Future<void> _loadGroupCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_groupCacheKey);
      if (raw == null) return;
      final list = jsonDecode(raw);
      if (list is! List) return;
      final groups = list.whereType<Map<String, dynamic>>().toList();
      if (groups.isNotEmpty && mounted) {
        setState(() => _groups = groups);
      }
    } catch (_) {}
  }

  Future<void> _loadArchiveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_archiveCacheKey) ?? [];
      if (mounted) setState(() => _archivedChatIds = raw.toSet());
    } catch (_) {}
  }

  Future<void> _saveArchiveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_archiveCacheKey, _archivedChatIds.toList());
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    chatService = ChatService();

    _scrollController.addListener(_onScroll);
    ChatSoundService.isMuted().then((v) {
      if (mounted) setState(() => _isSoundMuted = v);
    });

    // Cache affiché immédiatement, stream Firebase en parallèle
    _loadArchiveCache();
    _loadGroupCache().then((_) => _initGroupsStream());
    _loadConvCache();   // affiche le cache instantanément
    _initChatsStream(); // démarre le stream Firebase sans attendre le cache
    _loadCreators();
    _checkBiometricLock();
  }

  // Cache intermédiaire pour fusionner les deux streams
  List<Map<String, dynamic>> _memberGroups = [];
  List<Map<String, dynamic>> _ownedGroups = [];

  void _mergeAndSetGroups() {
    final seen = <String>{};
    final merged = <Map<String, dynamic>>[];
    for (final g in [..._memberGroups, ..._ownedGroups]) {
      final id = g['id'] as String? ?? '';
      if (id.isNotEmpty && seen.add(id)) merged.add(g);
    }
    merged.sort((a, b) {
      final aAt = (a['last_message_at'] as int?) ?? 0;
      final bAt = (b['last_message_at'] as int?) ?? 0;
      return bAt.compareTo(aAt);
    });
    _saveGroupCache(merged);
    if (mounted) setState(() { _groups = merged; _loadingGroups = false; });
  }

  void _initGroupsStream() {
    final myId = authProvider.loginUserData.id!;
    _groupsStreamSub?.cancel();
    _ownedGroupsStreamSub?.cancel();
    if (mounted) setState(() => _loadingGroups = true);

    // Stream 1 : groupes où l'utilisateur est membre
    _groupsStreamSub = FirebaseFirestore.instance
        .collection('GroupChats')
        .where('member_ids', arrayContains: myId)
        .snapshots()
        .listen((snap) {
      _memberGroups = snap.docs.map((d) => d.data()).toList();
      _mergeAndSetGroups();
    }, onError: (_) {
      if (mounted) setState(() => _loadingGroups = false);
    });

    // Stream 2 : groupes dont l'utilisateur est propriétaire
    // (utile pour ADM qui entre dans ses propres groupes sans être dans member_ids)
    _ownedGroupsStreamSub = FirebaseFirestore.instance
        .collection('GroupChats')
        .where('owner_id', isEqualTo: myId)
        .snapshots()
        .listen((snap) {
      _ownedGroups = snap.docs.map((d) => d.data()).toList();
      _mergeAndSetGroups();
    }, onError: (_) {});

    _loadGoldGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final myId = authProvider.loginUserData.id!;
      final snap = await FirebaseFirestore.instance
          .collection('GroupChats')
          .where('member_ids', arrayContains: myId)
          .get();
      // Met à jour _memberGroups et passe par _mergeAndSetGroups pour ne pas
      // écraser les _ownedGroups (groupes propriétaire non dans member_ids)
      _memberGroups = snap.docs.map((d) => d.data()).toList();
      _mergeAndSetGroups();
    } catch (e) {
      if (mounted) setState(() => _loadingGroups = false);
    }
    _loadGoldGroups();
  }

  void _loadGoldGroups() {
    // Délégué au GoldGroupsProvider — charge si pas encore fait, sinon réutilise le cache
    context.read<GoldGroupsProvider>().load();
  }

  Future<void> _searchGroupByCode(String code) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.length < 4) return;
    if (!mounted) return;
    setState(() { _codeSearching = true; _codeSearchResult = null; _codeSearchError = null; });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('GroupChats')
          .where('join_code', isEqualTo: trimmed)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        if (mounted) setState(() { _codeSearchError = 'Aucun groupe trouvé pour ce code.'; _codeSearching = false; });
        return;
      }

      final groupData = snap.docs.first.data();

      // Vérifier que le code n'a pas expiré (30 jours)
      final codeExpiresAt = groupData['join_code_expires_at'] as int?;
      if (codeExpiresAt != null && codeExpiresAt < DateTime.now().millisecondsSinceEpoch) {
        if (mounted) setState(() { _codeSearchError = 'Ce code a expiré. Demandez un nouveau code au propriétaire.'; _codeSearching = false; });
        return;
      }

      // Vérifier que le groupe n'est pas gelé
      if (groupData['is_frozen'] == true) {
        if (mounted) setState(() { _codeSearchError = 'Ce groupe est suspendu. Le propriétaire doit renouveler son plan Gold.'; _codeSearching = false; });
        return;
      }

      // Vérifier que le propriétaire est toujours Gold
      final ownerId = groupData['owner_id'] as String?;
      if (ownerId != null) {
        final ownerDoc = await FirebaseFirestore.instance.collection('Users').doc(ownerId).get();
        final ab = ownerDoc.data()?['abonnement'] as Map<String, dynamic>?;
        if (ab == null || ab['type'] != 'gold') {
          if (mounted) setState(() { _codeSearchError = 'Le propriétaire de ce groupe n\'est plus Gold.'; _codeSearching = false; });
          return;
        }
        final dateFinStr = ab['dateFin'] as String?;
        final dateFin = dateFinStr != null ? DateTime.tryParse(dateFinStr) : null;
        if (dateFin == null || dateFin.isBefore(DateTime.now())) {
          if (mounted) setState(() { _codeSearchError = 'Le propriétaire de ce groupe n\'est plus Gold.'; _codeSearching = false; });
          return;
        }
      }

      if (mounted) setState(() { _codeSearchResult = groupData; _codeSearching = false; });
    } catch (e) {
      if (mounted) setState(() { _codeSearchError = 'Erreur de recherche.'; _codeSearching = false; });
    }
  }

  Future<void> _joinGroupByCode(Map<String, dynamic> groupData) async {
    final myId = authProvider.loginUserData.id!;
    final groupId = groupData['id'] as String?;
    if (groupId == null) return;

    final memberIds = (groupData['member_ids'] as List<dynamic>? ?? []).cast<String>();
    if (memberIds.contains(myId)) {
      // Déjà membre — ouvrir directement
      if (mounted) {
        _openGroupChat(groupId, groupData['name'] as String? ?? '', groupData['image_url'] as String?, onReturn: _loadGroups);
      }
      return;
    }

    // Vérifier la limite de membres (Premium owner : 100 max, Gold : illimité)
    final ownerId = groupData['owner_id'] as String? ?? '';
    if (ownerId.isNotEmpty) {
      try {
        final ownerDoc = await FirebaseFirestore.instance.collection('Users').doc(ownerId).get();
        if (ownerDoc.exists) {
          final ownerAbJson = ownerDoc.data()?['abonnement'] as Map<String, dynamic>?;
          final ownerAb = ownerAbJson != null ? AfrolookAbonnement.fromJson(ownerAbJson) : null;
          final maxMembers = AbonnementUtils.maxGroupMembers(ownerAb);
          final currentCount = groupData['member_count'] as int?
              ?? (groupData['member_ids'] as List<dynamic>? ?? []).length;
          if (maxMembers != null && currentCount >= maxMembers) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Ce groupe est complet (100 membres maximum pour ce plan).'),
                backgroundColor: Colors.red,
              ));
            }
            return;
          }
        }
      } catch (_) {}
    }

    // Groupe privé payant : vérifier que l'utilisateur a un abonnement actif
    final isPrivate = groupData['is_private'] == true;
    final price = (groupData['subscription_price'] as num?)?.toDouble() ?? 0.0;
    if (isPrivate && price > 0) {
      final paidSubs = (groupData['paid_subscribers'] as Map<String, dynamic>?) ?? {};
      final expiryMs = paidSubs[myId] as int?;
      final isPaid = expiryMs != null && expiryMs > DateTime.now().millisecondsSinceEpoch;
      if (!isPaid) {
        // Ouvrir le groupe sans ajouter comme membre — le paiement sera demandé à l'entrée
        if (mounted) {
          setState(() { _codeSearchResult = null; _codeSearchController.clear(); });
          _openGroupChat(groupId, groupData['name'] as String? ?? '', groupData['image_url'] as String?, onReturn: _loadGroups);
        }
        return;
      }
    }

    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final myPseudo = authProvider.loginUserData.pseudo ?? '';
      final myImageUrl = authProvider.loginUserData.imageUrl ?? '';

      await FirebaseFirestore.instance
          .collection('GroupChats')
          .doc(groupId)
          .collection('members')
          .doc(myId)
          .set({
        'user_id': myId,
        'pseudo': myPseudo,
        'image_url': myImageUrl,
        'role': 'member',
        'joined_at': now,
      });
      await FirebaseFirestore.instance.collection('GroupChats').doc(groupId).update({
        'member_ids': FieldValue.arrayUnion([myId]),
        'member_count': FieldValue.increment(1),
      });

      if (mounted) {
        setState(() { _codeSearchResult = null; _codeSearchController.clear(); });
        _loadGroups();
        _openGroupChat(groupId, groupData['name'] as String? ?? '', groupData['image_url'] as String?, onReturn: _loadGroups);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openCreateGroup() {
    final isPremium = authProvider.loginUserData.abonnement?.estPremium == true;
    if (!isPremium) {
      showResponsiveBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1a0a2a), Color(0xFF2a1a3a)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFDB813).withOpacity(0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('👑', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              const Text('Groupes Premium', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                'Créer et gérer des groupes est réservé aux membres Premium.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFDB813),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/abonnement');
                },
                child: const Text('Passer à Premium', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      );
      return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateGroupPage())).then((_) => _loadGroups());
  }

  Future<void> _checkBiometricLock() async {
    try {
      final uid = authProvider.loginUserData.id;
      if (uid == null) return;
      final doc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
      final privacy = (doc.data()?['privacySettings'] as Map<String, dynamic>?) ?? {};
      final isPremium = authProvider.loginUserData.abonnement?.estPremium == true;
      if (isPremium && privacy['biometricLock'] == true) {
        if (mounted) setState(() => _isLocked = true);
        await _authenticate();
      }
    } catch (_) {}
  }

  Future<void> _authenticate() async {
    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Déverrouillez pour accéder à vos messages',
        options: const AuthenticationOptions(biometricOnly: false),
      );
      if (mounted) {
        if (authenticated) {
          setState(() => _isLocked = false);
        } else {
          Navigator.pop(context);
        }
      }
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  void _initChatsStream() {
    if (mounted) setState(() => _isRefreshing = true);
    _chatsStream = FirebaseFirestore.instance
        .collection('Chats')
        .where(Filter.or(
          Filter('receiver_id', isEqualTo: authProvider.loginUserData.id!),
          Filter('sender_id', isEqualTo: authProvider.loginUserData.id!),
        ))
        .where("type", isEqualTo: ChatType.USER.name)
        .orderBy('updated_at', descending: true)
        .limit(50)
        .snapshots()
        .asyncMap(_processChatsSnapshot);
  }

  Future<List<ChatWithLastMessage>> _processChatsSnapshot(QuerySnapshot snapshot) async {
    final myId = authProvider.loginUserData.id!;

    // 1. Parse tous les docs + collecter les IDs distincts des autres users
    final chats = <Chat>[];
    final otherIds = <String>{};
    for (final doc in snapshot.docs) {
      final chat = Chat.fromJson(doc.data() as Map<String, dynamic>);
      chats.add(chat);
      final oid = myId == chat.receiverId ? chat.senderId : chat.receiverId;
      if (oid != null) otherIds.add(oid);
    }

    // 2. Batch fetch — 1 requête whereIn par tranche de 10 (au lieu de N requêtes)
    final userMap = <String, UserData>{};
    final ids = otherIds.toList();
    final batchFutures = <Future<void>>[];
    for (int i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, (i + 10).clamp(0, ids.length));
      batchFutures.add(() async {
        try {
          final snap = await FirebaseFirestore.instance
              .collection('Users')
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
          for (final d in snap.docs) {
            final data = Map<String, dynamic>.from(d.data() as Map<String, dynamic>);
            data['id'] = d.id;
            userMap[d.id] = UserData.fromJson(data);
          }
        } catch (_) {}
      }());
    }
    await Future.wait(batchFutures);

    // 3. Construire les résultats sans requête Messages :
    //    ConversationList lit chat.lastMessage (string) directement depuis le doc
    final result = <ChatWithLastMessage>[];
    for (final chat in chats) {
      final oid = myId == chat.receiverId ? chat.senderId : chat.receiverId;
      if (oid == null) continue;
      final user = userMap[oid];
      if (user == null) continue;
      chat.chatFriend = user;
      chat.receiver = user;
      result.add(ChatWithLastMessage(chat: chat, lastMessage: null));
    }

    result.sort((a, b) => (b.chat.updatedAt ?? 0).compareTo(a.chat.updatedAt ?? 0));
    _firebaseLoaded = true;
    if (mounted) {
      setState(() {
        _chats = result;
        _isLoading = false;
        _isRefreshing = false;
        _hasMore = false;
      });
    }
    _saveConvCache(result);
    return result;
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
            ? (message.message.startsWith('enc:v1:') ? '🔒 Message ancien' : message.message)
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



  bool _isUserOnline(UserData user) {
    final bool isConnected = user.state == UserState.ONLINE.name;
    final int lastTimeActive = user.last_time_active ?? 0;
    final int now = DateTime.now().millisecondsSinceEpoch;
    const int tenMinutesInMs = 600000;
    return isConnected && (now - lastTimeActive) < tenMinutesInMs;
  }

  // Charger les créateurs actifs (newPostsByCreator + followings)
  Future<void> _loadCreators() async {
    if (!mounted) return;
    final me = authProvider.loginUserData;
    try {
      final list = await _activeCreatorsService.resolve(me, limit: 10);
      if (mounted) {
        setState(() {
          _creators = list.map((c) => c.user).toList();
          _unseenCounts = {
            for (final c in list)
              if (c.unseenCount > 0 && c.user.id != null) c.user.id!: c.unseenCount,
          };
          _loadingCreators = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCreators = false);
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
      printVm("Erreur recherche: $e");
      if (mounted) {
        setState(() {
          _isSearchLoading = false;
          _searchResults = [];
        });
      }
    }
  }

  /// Ouvre ou affiche un groupe — inline sur desktop, navigation sur mobile.
  void _openGroupChat(String groupId, String groupName, String? imageUrl, {VoidCallback? onReturn}) {
    if (AppLayout.isWide(context)) {
      setState(() => _activeChatWidget = GroupChatPage(
        key: ValueKey('group_$groupId'),
        groupId: groupId,
        groupName: groupName,
        groupImageUrl: imageUrl,
      ));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GroupChatPage(groupId: groupId, groupName: groupName, groupImageUrl: imageUrl)),
    ).then((_) => onReturn?.call());
  }

  Future<void> _openChat(Chat chat) async {
    try {
      final resultChat = await chatService.createOrGetChat(
        chat: chat,
        currentUserId: authProvider.loginUserData.id!,
      );

      if (!mounted) return;

      if (AppLayout.isWide(context)) {
        setState(() => _activeChatWidget = MyChat(
          key: ValueKey('chat_${resultChat.id ?? resultChat.receiverId ?? resultChat.senderId}'),
          title: 'mon chat',
          chat: resultChat,
        ));
        return;
      }

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
      printVm("Erreur ouverture chat: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_l10n.convErrorOpeningChat),
            backgroundColor: _colors.danger,
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

      if (AppLayout.isWide(context)) {
        setState(() => _activeChatWidget = MyChat(
          key: ValueKey('chat_${resultChat.id ?? resultChat.receiverId ?? resultChat.senderId}'),
          title: 'mon chat',
          chat: resultChat,
        ));
        return;
      }

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
      printVm("Erreur création chat: $e");
    }
  }

  @override
  void dispose() {
    _groupsStreamSub?.cancel();
    _ownedGroupsStreamSub?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _codeSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    _l10n = AppLocalizations.of(context);

    if (AppLayout.isWide(context)) return _buildWideLayout();

    if (_isLocked) {
      return Scaffold(
        backgroundColor: _colors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_rounded, size: 64, color: _colors.primary),
              const SizedBox(height: 20),
              Text(
                'Messagerie verrouillée',
                style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Utilisez votre empreinte ou Face ID pour déverrouiller',
                style: TextStyle(color: _colors.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: _authenticate,
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text('Déverrouiller'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _colors.background,
      appBar: _buildAppBar(),
      body: _buildChatListContent(),
    );
  }

  /// Layout 2-colonnes style WhatsApp pour desktop.
  Widget _buildWideLayout() {
    if (_isLocked) {
      return Scaffold(
        backgroundColor: _colors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_rounded, size: 64, color: _colors.primary),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _authenticate,
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text('Déverrouiller'),
                style: ElevatedButton.styleFrom(backgroundColor: _colors.primary, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: _colors.background,
      appBar: _buildAppBar(),
      body: Row(
        children: [
          // ── Liste gauche (360px) ──────────────────────────────────
          SizedBox(
            width: 360,
            child: Container(
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: _colors.border, width: 0.5)),
              ),
              child: _buildChatListContent(),
            ),
          ),
          // ── Conversation active (reste) ───────────────────────────
          Expanded(
            child: _activeChatWidget ?? _buildChatPlaceholder(),
          ),
        ],
      ),
    );
  }

  Widget _buildChatPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 72, color: _colors.textSecondary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'Sélectionnez une conversation',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _colors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            'Cliquez sur un chat dans la liste pour l\'ouvrir ici',
            style: TextStyle(fontSize: 13, color: _colors.textSecondary.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  /// Contenu de la liste des conversations (mobile + panneau gauche desktop).
  Widget _buildChatListContent() {
    return Column(
      children: [
        if (!_isSearching) _buildCreatorsSection(),
        if (!_isSearching && (_loadingCreators || _creators.isNotEmpty))
          Divider(height: 1, color: _colors.textSecondary),
        if (!_isSearching && _isRefreshing)
          LinearProgressIndicator(
            minHeight: 2,
            backgroundColor: Colors.transparent,
            color: _colors.primary.withOpacity(0.5),
          ),
        if (!_isSearching) _buildFilterPills(),
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
                      Icon(Icons.error_outline, color: _colors.danger, size: 48),
                      const SizedBox(height: 16),
                      Text(_l10n.convErrorLoading, style: TextStyle(color: _colors.textPrimary)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _initChatsStream,
                        child: Text(_l10n.convRetry, style: TextStyle(color: _colors.primary)),
                      ),
                    ],
                  ),
                );
              }
              if (_chatFilter == 'groups') {
                if (_loadingGroups) return _buildLoadingSkeleton();
                if (_groups.isEmpty) return _buildEmptyState();
                return _buildGroupsVerticalList();
              }
              if (_chatFilter == 'users') {
                if (_chats.isNotEmpty) return _buildChatList(_chats);
                if (_isLoading || snapshot.connectionState == ConnectionState.waiting) return _buildLoadingSkeleton();
                return _buildEmptyState();
              }
              final bool stillLoading = (_isLoading || snapshot.connectionState == ConnectionState.waiting) && _chats.isEmpty;
              if (stillLoading) return _buildLoadingSkeleton();
              if (_chats.isEmpty && _groups.isEmpty) return _buildEmptyState();
              return _buildMergedList(_chats);
            },
          ),
        ),
      ],
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
        style: TextStyle(color: _colors.textPrimary),
        decoration: InputDecoration(
          hintText: _l10n.convSearchHint,
          hintStyle: TextStyle(color: _colors.border),
          border: InputBorder.none,
        ),
        onChanged: _searchChats,
      )
          : Text(
        _l10n.convTitle,
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
            IconButton(
              tooltip: _isSoundMuted ? 'Activer les sons' : 'Couper les sons',
              icon: Icon(
                _isSoundMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: _isSoundMuted ? _colors.textSecondary : _colors.accent,
              ),
              onPressed: () async {
                final newVal = !_isSoundMuted;
                await ChatSoundService.setMuted(newVal);
                if (mounted) setState(() => _isSoundMuted = newVal);
              },
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: _colors.accent),
              color: _colors.surface,
              onSelected: (value) {
                if (value == 'archives') _showArchivedChats();
                if (value == 'mark_all_read') _markAllAsRead();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'mark_all_read',
                  child: Row(
                    children: [
                      Icon(Icons.done_all, color: _colors.primary, size: 20),
                      const SizedBox(width: 10),
                      Text('Tout marquer comme lu', style: TextStyle(color: _colors.textPrimary)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'archives',
                  child: Row(
                    children: [
                      Icon(Icons.archive_outlined, color: _colors.textSecondary, size: 20),
                      const SizedBox(width: 10),
                      Text('Archives', style: TextStyle(color: _colors.textPrimary)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCreatorsSection() {
    final me = authProvider.loginUserData;
    final hasUnseen = _unseenCounts.values.any((c) => c > 0);
    final title = hasUnseen ? 'Posts non vus' : 'Vos créateurs';
    return FeedProfilesSection(
      users: _creators,
      isLoading: _loadingCreators,
      title: title,
      onShowProfile: (_) {},
      unseenCounts: _unseenCounts,
      recentCanaux: const [],
      creatorLastActivityUs: const {},
      roundCards: true,
      onSeeAllOverride: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ActiveCreatorsListPage(
              abonnesIds: me.followingIds ?? me.userAbonnesIds ?? [],
              viewedPostIds: me.viewedPostIds ?? [],
              currentUserId: me.id ?? '',
              unseenCounts: _unseenCounts,
              followedCanalIds: const [],
              recentCanaux: const [],
              preloadedCreators: [],
            ),
          ),
        );
      },
      onTapCard: (user) {
        final unseen = _unseenCounts[user.id] ?? 0;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreatorUnseenPostsPage(
              creator: user,
              unseenCount: unseen,
              viewedPostIds: me.viewedPostIds ?? [],
              currentUserId: me.id ?? '',
              userCreatedAtMs: me.createdAt ?? 0,
            ),
          ),
        ).then((_) {
          if (mounted && user.id != null) {
            setState(() {
              _unseenCounts.remove(user.id);
              _creators = _creators.map((u) => u).toList();
              authProvider.loginUserData.newPostsByCreator?.remove(user.id);
            });
          }
        });
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _l10n.convMessagesTitle,
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

  Widget _buildFilterPills() {
    final filters = [
      {'key': 'all',    'label': 'Tous'},
      {'key': 'users',  'label': 'Messages'},
      {'key': 'groups', 'label': 'Groupes'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ...filters.map((f) {
            final isActive = _chatFilter == f['key'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _chatFilter = f['key']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: isActive ? _colors.primary : _colors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive ? _colors.primary : _colors.border.withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    f['label']!,
                    style: TextStyle(
                      color: isActive ? Colors.white : _colors.textSecondary,
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          // Bouton créer groupe toujours visible
          GestureDetector(
            onTap: _openCreateGroup,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _colors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.group_add_rounded, color: _colors.primary, size: 15),
                  const SizedBox(width: 4),
                  Text('Groupe', style: TextStyle(color: _colors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsVerticalList() {
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        // ── Recherche par code Gold ───────────────────────────────────────
        _buildCodeSearchBar(),

        // Résultat de recherche par code
        if (_codeSearching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        if (_codeSearchError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(_codeSearchError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
          ),
        if (_codeSearchResult != null)
          _buildCodeSearchResultTile(_codeSearchResult!),

        // ── Carousel Gold ─────────────────────────────────────────────────
        Consumer<GoldGroupsProvider>(
          builder: (_, provider, __) {
            if (!provider.isLoaded && !provider.loading) return const SizedBox.shrink();
            if (provider.groups.isEmpty && !provider.loading) return const SizedBox.shrink();
            return _buildGoldCarouselSection();
          },
        ),

        // ── Mes groupes ───────────────────────────────────────────────────
        if (_groups.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'MES GROUPES',
              style: TextStyle(color: _colors.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
            ),
          ),
        ],
        ..._groups.map((g) => _buildGroupTile(g)),
        _buildArchiveTile(),
      ],
    );
  }

  Widget _buildCodeSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeSearchController,
                  style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w700, letterSpacing: 1.5, fontSize: 15),
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Code du groupe (ex: AB3D7K2M)',
                    hintStyle: TextStyle(color: _colors.textSecondary, fontSize: 13, letterSpacing: 0, fontWeight: FontWeight.w400),
                    prefixIcon: const Icon(Icons.key_rounded, color: Color(0xFFFFD700), size: 20),
                    filled: true,
                    fillColor: _colors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: _colors.border.withOpacity(0.4)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: _colors.border.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFFFD700), width: 1.5),
                    ),
                  ),
                  onSubmitted: _searchGroupByCode,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _searchGroupByCode(_codeSearchController.text),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.search_rounded, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCodeSearchResultTile(Map<String, dynamic> group) {
    final name = group['name'] as String? ?? '';
    final imageUrl = group['image_url'] as String? ?? '';
    final isPrivate = group['is_private'] == true;
    final price = (group['subscription_price'] as num?)?.toDouble() ?? 0.0;
    final memberCount = group['member_count'] as int? ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700).withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: _colors.surfaceVariant,
              backgroundImage: imageUrl.isNotEmpty ? CachedNetworkImageProvider(imageUrl) : null,
              child: imageUrl.isEmpty ? Icon(Icons.group_rounded, color: _colors.textSecondary) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(name, style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                      if (isPrivate) ...[
                        const SizedBox(width: 6),
                        const Text('🔒', style: TextStyle(fontSize: 12)),
                      ],
                    ],
                  ),
                  Text(
                    '$memberCount membres${isPrivate && price > 0 ? ' · ${price.toStringAsFixed(0)} FCFA/mois' : ''}',
                    style: TextStyle(color: _colors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _joinGroupByCode(group),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              child: const Text('Rejoindre'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoldCarouselSection() {
    return Consumer<GoldGroupsProvider>(
      builder: (_, provider, __) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium, color: Color(0xFFFFD700), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Groupes Gold',
                    style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(width: 4),
                  Text('· découvrez', style: TextStyle(color: _colors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            SizedBox(
              height: 100,
              child: provider.loading && !provider.isLoaded
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFD700)))
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: provider.groups.length,
                      itemBuilder: (_, i) => _buildGoldGroupCard(provider.groups[i]),
                    ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildGoldGroupCard(Map<String, dynamic> group) {
    final name = group['name'] as String? ?? '';
    final imageUrl = group['image_url'] as String? ?? '';
    final memberCount = group['member_count'] as int? ?? 0;
    final groupId = group['id'] as String? ?? '';
    final isPrivate = group['is_private'] == true;
    final isOfficial = group['is_official'] == true;
    final price = (group['subscription_price'] as num?)?.toDouble() ?? 0.0;
    final myId = authProvider.loginUserData.id ?? '';
    final unreadCounts = group['unread_counts'] as Map<String, dynamic>? ?? {};
    final unreadCount = (unreadCounts[myId] as int?) ?? 0;

    return GestureDetector(
      onTap: () => _openGroupChat(groupId, name, imageUrl.isNotEmpty ? imageUrl : null, onReturn: () {
        context.read<GoldGroupsProvider>().load(force: true);
        _loadGroups();
      }),
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: _colors.surfaceVariant,
                  backgroundImage: imageUrl.isNotEmpty ? CachedNetworkImageProvider(imageUrl) : null,
                  child: imageUrl.isEmpty ? Icon(Icons.group_rounded, color: _colors.textSecondary, size: 24) : null,
                ),
                if (isOfficial)
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 18, height: 18,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.verified_rounded, size: 14, color: Colors.blue),
                    ),
                  )
                else if (isPrivate)
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      width: 18, height: 18,
                      decoration: const BoxDecoration(color: Color(0xFFFFD700), shape: BoxShape.circle),
                      child: const Icon(Icons.lock_rounded, size: 10, color: Colors.white),
                    ),
                  ),
                // Badge non-lus
                if (unreadCount > 0)
                  Positioned(
                    top: -4, right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      constraints: const BoxConstraints(minWidth: 18),
                      decoration: BoxDecoration(
                        color: _colors.primary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _colors.textPrimary,
                fontSize: 11,
                fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            Text(
              isPrivate && price > 0
                  ? '${price.toStringAsFixed(0)}F/m'
                  : '$memberCount mbr',
              style: TextStyle(color: _colors.textSecondary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupTile(Map<String, dynamic> group) {
    final rawName = group['name'] as String? ?? '';
    final name = rawName.length > 50 ? '${rawName.substring(0, 50)}...' : rawName;
    final imageUrl = group['image_url'] as String? ?? '';
    final lastMsg = group['last_message'] as String? ?? '';
    final lastMsgAt = group['last_message_at'] as int? ?? 0;
    final isFrozen = group['is_frozen'] == true;
    final isOfficial = group['is_official'] == true;
    final memberCount = group['member_count'] as int? ?? 0;
    final myId = authProvider.loginUserData.id ?? '';
    final unreadCounts = group['unread_counts'] as Map<String, dynamic>? ?? {};
    final unreadCount = (unreadCounts[myId] as int?) ?? 0;

    String timeStr = '';
    if (lastMsgAt > 0) {
      final date = DateTime.fromMillisecondsSinceEpoch(lastMsgAt);
      final now = DateTime.now();
      if (date.day == now.day && date.month == now.month && date.year == now.year) {
        timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else {
        timeStr = '${date.day}/${date.month}';
      }
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: _colors.surfaceVariant,
            backgroundImage: imageUrl.isNotEmpty ? CachedNetworkImageProvider(imageUrl) : null,
            child: imageUrl.isEmpty
                ? Icon(Icons.group_rounded, color: _colors.textSecondary, size: 24)
                : null,
          ),
          if (isFrozen)
            Positioned(
              bottom: 0, right: 0,
              child: Container(
                width: 14, height: 14,
                decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                child: const Icon(Icons.pause_rounded, size: 9, color: Colors.white),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    name,
                    style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isOfficial) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.verified_rounded, color: Colors.blue, size: 14),
                ],
              ],
            ),
          ),
          if (timeStr.isNotEmpty)
            Text(
              timeStr,
              style: TextStyle(
                color: unreadCount > 0 ? _colors.primary : _colors.textSecondary,
                fontSize: 11,
                fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Icon(Icons.group_outlined, size: 12, color: _colors.textSecondary),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              lastMsg.isNotEmpty ? lastMsg : '$memberCount membres',
              style: TextStyle(
                color: unreadCount > 0 ? _colors.textPrimary : _colors.textSecondary,
                fontSize: 12,
                fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isFrozen)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Gelé', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          if (unreadCount > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              constraints: const BoxConstraints(minWidth: 20),
              decoration: BoxDecoration(
                color: _colors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : '$unreadCount',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 4),
            _GroupAttentionBadge(lastMsgAtMs: lastMsgAt),
          ],
        ],
      ),
      onTap: () => _openGroupChat(group['id'] as String, name, imageUrl.isNotEmpty ? imageUrl : null, onReturn: _loadGroups),
    );
  }

  Widget _buildMergedList(List<ChatWithLastMessage> userChats) {
    // Construit une liste unifiée de type dynamic :
    // - ChatWithLastMessage pour les chats 1-1
    // - Map<String,dynamic> pour les groupes
    final List<dynamic> merged = [
      ...userChats.where((c) => !_archivedChatIds.contains(c.chat.docId)),
      ..._groups,
    ];

    // Trie par date descendante
    merged.sort((a, b) {
      int tsA, tsB;
      if (a is ChatWithLastMessage) {
        tsA = a.chat.updatedAt ?? 0;
        // Épinglés remontent tout en haut
        if (_pinnedChatIds.contains(a.chat.docId)) tsA = 99999999999999;
      } else {
        tsA = (a as Map<String, dynamic>)['last_message_at'] as int? ?? 0;
      }
      if (b is ChatWithLastMessage) {
        tsB = b.chat.updatedAt ?? 0;
        if (_pinnedChatIds.contains(b.chat.docId)) tsB = 99999999999999;
      } else {
        tsB = (b as Map<String, dynamic>)['last_message_at'] as int? ?? 0;
      }
      return tsB.compareTo(tsA);
    });

    return ListView.builder(
      controller: _scrollController,
      itemCount: merged.length + 2, // +1 ad banner, +1 archive tile
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _buildAdBanner(key: 'chat_list_first_ad'),
          );
        }
        if (index == merged.length + 1) return _buildArchiveTile();
        final item = merged[index - 1];
        if (item is Map<String, dynamic>) {
          return _buildGroupTile(item);
        }
        final cwm = item as ChatWithLastMessage;
        return _buildUserChatTile(cwm);
      },
    );
  }

  Widget _buildArchiveTile() {
    final count = _archivedChatIds.length;
    if (count == 0) return const SizedBox.shrink();
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 52, height: 52,
        decoration: BoxDecoration(color: _colors.surfaceVariant, shape: BoxShape.circle),
        child: Icon(Icons.archive_rounded, color: _colors.textSecondary, size: 26),
      ),
      title: Text('Archives', style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text('$count conversation${count > 1 ? 's' : ''}', style: TextStyle(color: _colors.textSecondary, fontSize: 12)),
      trailing: Icon(Icons.chevron_right_rounded, color: _colors.textSecondary),
      onTap: _showArchivedChats,
    );
  }

  Future<void> _markAllAsRead() async {
    final userId = authProvider.loginUserData.id!;
    final firestore = FirebaseFirestore.instance;

    try {
      // 1. Messages directs non lus
      final directSnap = await firestore
          .collection('Messages')
          .where('receiverBy', isEqualTo: userId)
          .where('message_state', isEqualTo: MessageState.NONLU.name)
          .get();

      final batch = firestore.batch();
      for (final doc in directSnap.docs) {
        batch.update(doc.reference, {'message_state': MessageState.LU.name});
      }

      // 2. GroupChats — remettre unread_counts.$userId à 0
      final groupSnap = await firestore
          .collection('GroupChats')
          .where('member_ids', arrayContains: userId)
          .get();

      for (final doc in groupSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final unreadCounts = data['unread_counts'] as Map<String, dynamic>? ?? {};
        if ((unreadCounts[userId] as int? ?? 0) > 0) {
          batch.update(doc.reference, {'unread_counts.$userId': 0});
        }
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tous les messages marqués comme lus'),
            backgroundColor: _colors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: _colors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showArchivedChats() {
    final archived = _chats.where((c) => _archivedChatIds.contains(c.chat.docId)).toList();

    showResponsiveBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: _colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle + header — zone de drag pour fermer
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
                  Navigator.pop(ctx);
                }
              },
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 36, height: 4,
                    decoration: BoxDecoration(color: _colors.border, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Row(
                      children: [
                        Text('Archives', style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 17)),
                        const Spacer(),
                        Text('${archived.length} conv.', style: TextStyle(color: _colors.textSecondary, fontSize: 12)),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => Navigator.pop(ctx),
                          child: Icon(Icons.close_rounded, color: _colors.textSecondary, size: 22),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: _colors.border.withOpacity(0.3)),
                ],
              ),
            ),
            // Liste scrollable
            Expanded(
              child: archived.isEmpty
                  ? Center(child: Text('Aucune conversation archivée', style: TextStyle(color: _colors.textSecondary)))
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: archived.length,
                      itemBuilder: (_, i) {
                        final cwm = archived[i];
                        final chat = cwm.chat;
                        final friend = chat.chatFriend;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundImage: friend?.imageUrl != null && friend!.imageUrl!.isNotEmpty
                                ? CachedNetworkImageProvider(friend.imageUrl!)
                                : null,
                            backgroundColor: _colors.surfaceVariant,
                            child: friend?.imageUrl == null || friend!.imageUrl!.isEmpty
                                ? Icon(Icons.person, color: _colors.textSecondary)
                                : null,
                          ),
                          title: Text('@${friend?.pseudo ?? '...'}',
                              style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(cwm.lastMessage != null ? _getMessagePreview(cwm.lastMessage) : (cwm.chat.lastMessage ?? _l10n.convNoMessage),
                              style: TextStyle(color: _colors.textSecondary, fontSize: 12),
                              overflow: TextOverflow.ellipsis),
                          trailing: TextButton(
                            onPressed: () {
                              setState(() => _archivedChatIds.remove(chat.docId));
                              _saveArchiveCache();
                              Navigator.pop(ctx);
                            },
                            child: Text('Désarchiver', style: TextStyle(color: _colors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _openChat(chat);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserChatTile(ChatWithLastMessage chatWithMessage) {
    final Chat chat = chatWithMessage.chat;
    final Message? lastMessage = chatWithMessage.lastMessage;
    final int unreadCount = _getUnreadCount(chat);
    final bool isOnline = _isUserOnline(chat.chatFriend ?? UserData());
    final bool isLastMessageFromMe = _isLastMessageFromCurrentUser(lastMessage);
    final bool isPinned = _pinnedChatIds.contains(chat.docId);
    final bool isPro = chat.chatFriend?.hasEntreprise == true;

    return Slidable(
      key: ValueKey(chat.docId),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) {
              setState(() {
                if (isPinned) {
                  _pinnedChatIds.remove(chat.docId);
                } else {
                  _pinnedChatIds.add(chat.docId!);
                }
              });
            },
            backgroundColor: _colors.primary,
            foregroundColor: Colors.white,
            icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
            label: isPinned ? 'Désépingler' : 'Épingler',
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        dismissible: DismissiblePane(
          onDismissed: () {
            setState(() { _archivedChatIds.add(chat.docId!); });
            _saveArchiveCache();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Conversation archivée'),
                action: SnackBarAction(
                  label: 'Annuler',
                  onPressed: () { setState(() => _archivedChatIds.remove(chat.docId)); _saveArchiveCache(); },
                ),
              ),
            );
          },
        ),
        children: [
          SlidableAction(
            onPressed: (_) {
              setState(() { _archivedChatIds.add(chat.docId!); });
              _saveArchiveCache();
            },
            backgroundColor: Colors.grey,
            foregroundColor: Colors.white,
            icon: Icons.archive_outlined,
            label: 'Archiver',
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
          ),
        ],
      ),
      child: GestureDetector(
        onTap: () => _openChat(chat),
        child: ConversationList(
          name: "@${chat.chatFriend?.pseudo ?? _l10n.convDefaultUser}",
          messageText: lastMessage != null
              ? _getMessagePreview(lastMessage)
              : (chat.lastMessage?.isNotEmpty == true ? chat.lastMessage! : _l10n.convNoMessage),
          imageUrl: chat.chatFriend?.imageUrl ?? '',
          time: _formatTime(chat.updatedAt),
          isMessageRead: unreadCount == 0,
          isOnline: isOnline,
          unreadCount: unreadCount,
          isTyping: _isOtherUserTyping(chat),
          isLastMessageFromMe: isLastMessageFromMe,
          messageStatus: _getMessageStatus(lastMessage),
          id_user: chat.chatFriend!.id!,
          isPinned: isPinned,
          isPro: isPro,
          messageType: lastMessage?.messageType,
          chatFriend: chat.chatFriend,
          unreadSinceMs: unreadCount > 0 ? (chat.updatedAt ?? 0) : 0,
        ),
      ),
    );
  }

  Widget _buildGroupsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                'GROUPES',
                style: TextStyle(color: _colors.primary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.2),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _openCreateGroup,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _colors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add_rounded, color: _colors.primary, size: 14),
                      const SizedBox(width: 4),
                      Text('Nouveau', style: TextStyle(color: _colors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 86,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _groups.length,
            itemBuilder: (_, index) {
              final group = _groups[index];
              final imageUrl = group['image_url'] as String? ?? '';
              final name = group['name'] as String? ?? '';
              final isFrozen = group['is_frozen'] == true;

              return GestureDetector(
                onTap: () => _openGroupChat(group['id'] as String, name, imageUrl.isNotEmpty ? imageUrl : null, onReturn: _loadGroups),
                child: Container(
                  width: 68,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: _colors.surfaceVariant,
                            backgroundImage: imageUrl.isNotEmpty ? CachedNetworkImageProvider(imageUrl) : null,
                            child: imageUrl.isEmpty
                                ? Icon(Icons.group_rounded, color: _colors.textSecondary, size: 24)
                                : null,
                          ),
                          if (isFrozen)
                            Positioned(
                              bottom: 0, right: 0,
                              child: Container(
                                width: 14, height: 14,
                                decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                                child: const Icon(Icons.pause_rounded, size: 9, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        name,
                        style: TextStyle(color: _colors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Ensemble des chats épinglés (géré localement pour l'instant)
  final Set<String> _pinnedChatIds = {};

  Widget _buildChatList(List<ChatWithLastMessage> chats) {
    final visibleChats = chats.where((c) => !_archivedChatIds.contains(c.chat.docId)).toList();
    // Épinglés en premier
    visibleChats.sort((a, b) {
      final aPinned = _pinnedChatIds.contains(a.chat.docId) ? 0 : 1;
      final bPinned = _pinnedChatIds.contains(b.chat.docId) ? 0 : 1;
      if (aPinned != bPinned) return aPinned - bPinned;
      return (b.chat.updatedAt ?? 0).compareTo(a.chat.updatedAt ?? 0);
    });

    return ListView.builder(
      controller: _scrollController,
      itemCount: visibleChats.length + 2, // +1 ad, +1 archive tile
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _buildAdBanner(key: 'chat_list_first_ad'),
          );
        }
        if (index == visibleChats.length + 1) return _buildArchiveTile();

        final chatIndex = index - 1;
        if (chatIndex >= visibleChats.length) return const SizedBox.shrink();

        final chatWithMessage = visibleChats[chatIndex];
        final Chat chat = chatWithMessage.chat;
        final Message? lastMessage = chatWithMessage.lastMessage;

        final int unreadCount = _getUnreadCount(chat);
        final bool isOnline = _isUserOnline(chat.chatFriend ?? UserData());
        final bool isLastMessageFromMe = _isLastMessageFromCurrentUser(lastMessage);
        final bool isPinned = _pinnedChatIds.contains(chat.docId);
        final bool isPro = chat.chatFriend?.hasEntreprise == true;

        return Slidable(
          key: ValueKey(chat.docId),
          startActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.25,
            children: [
              SlidableAction(
                onPressed: (_) {
                  setState(() {
                    if (isPinned) {
                      _pinnedChatIds.remove(chat.docId);
                    } else {
                      _pinnedChatIds.add(chat.docId!);
                    }
                  });
                },
                backgroundColor: _colors.primary,
                foregroundColor: Colors.white,
                icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                label: isPinned ? 'Désépingler' : 'Épingler',
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
              ),
            ],
          ),
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.25,
            dismissible: DismissiblePane(
              onDismissed: () {
                setState(() { _archivedChatIds.add(chat.docId!); });
                _saveArchiveCache();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Conversation archivée'),
                    action: SnackBarAction(
                      label: 'Annuler',
                      onPressed: () { setState(() => _archivedChatIds.remove(chat.docId)); _saveArchiveCache(); },
                    ),
                    backgroundColor: _colors.surface,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            children: [
              SlidableAction(
                onPressed: (_) {
                  setState(() => _archivedChatIds.add(chat.docId!));
                  _saveArchiveCache();
                },
                backgroundColor: _colors.textSecondary,
                foregroundColor: Colors.white,
                icon: Icons.archive_outlined,
                label: 'Archiver',
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
              ),
            ],
          ),
          child: GestureDetector(
            onTap: () => _openChat(chat),
            child: ConversationList(
              name: "@${chat.chatFriend?.pseudo ?? _l10n.convDefaultUser}",
              messageText: lastMessage != null
                  ? _getMessagePreview(lastMessage)
                  : (chat.lastMessage?.isNotEmpty == true ? chat.lastMessage! : _l10n.convNoMessage),
              imageUrl: chat.chatFriend?.imageUrl ?? '',
              time: _formatTime(chat.updatedAt),
              isMessageRead: unreadCount == 0,
              isOnline: isOnline,
              unreadCount: unreadCount,
              isTyping: _isOtherUserTyping(chat),
              isLastMessageFromMe: isLastMessageFromMe,
              messageStatus: _getMessageStatus(lastMessage),
              id_user: chat.chatFriend!.id!,
              isPinned: isPinned,
              isPro: isPro,
              messageType: lastMessage?.messageType,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    if (_searchController.text.isEmpty) {
      return Center(
        child: Text(
          _l10n.convTypeToSearch,
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
            name: "@${chat.chatFriend?.pseudo ?? _l10n.convDefaultUser}",
            messageText: isSearchResult ? _l10n.convStartConversation : (chat.lastMessage ?? ''),
            imageUrl: chat.chatFriend?.imageUrl ?? '',
            time: isSearchResult ? "" : _formatTime(chat.updatedAt),
            isMessageRead: unreadCount == 0,
            isOnline: isOnline,
            unreadCount: unreadCount,
            isTyping: _isOtherUserTyping(chat),
            isSearchResult: isSearchResult,
            id_user: chat.chatFriend!.id!,
            isPro: chat.chatFriend?.hasEntreprise == true,
          ),
        );
      },
    );
  }

  String _getMessagePreview(Message? lastMessage) {
    if (lastMessage == null) return _l10n.convNoMessage;

    switch (lastMessage.messageType) {
      case 'text':
        if (lastMessage.message.startsWith('enc:v1:')) return '🔒 Message ancien';
        return lastMessage.message;
      case 'image':
        final hasMulti = lastMessage.imageText != null && lastMessage.imageText!.contains('|');
        if (hasMulti) {
          final count = lastMessage.imageText!.split('|').length + 1;
          return '📷 $count photos';
        }
        return '📷 Photo';
      case 'voice':
        return '🎙 Message vocal';
      case 'post':
        return '📎 Post partage';
      default:
        return lastMessage.message.isNotEmpty ? lastMessage.message : '...';
    }
  }

  bool _isLastMessageFromCurrentUser(Message? lastMessage) {
    if (lastMessage == null) return false;
    return lastMessage.sendBy == authProvider.loginUserData.id;
  }

  bool _isOtherUserTyping(Chat chat) {
    final myId = authProvider.loginUserData.id;
    if (chat.senderId == myId) {
      return chat.receiver_sending == 'SENDING';
    } else {
      return chat.send_sending == 'SENDING';
    }
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
                _l10n.convEmptyTitle,
                style: TextStyle(color: _colors.textPrimary),
              ),
              SizedBox(height: 8),
              Text(
                _l10n.convEmptySubtitle,
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
                child: Text(_l10n.convSeeMyFriends),
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
            _l10n.convNoResults,
            style: TextStyle(color: _colors.textPrimary),
          ),
          SizedBox(height: 8),
          Text(
            _l10n.convTryOtherTerms,
            style: TextStyle(color: _colors.border, fontSize: 12),
          ),
          SizedBox(height: 24),
          _buildInviteButton(),
        ],
      ),
    );
  }

  Widget _buildInviteButton() {
    return GestureDetector(
      onTap: _inviteFriend,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_colors.primary, Color.lerp(_colors.primary, const Color(0xFF1abc9c), 0.5)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: _colors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            const Text(
              'Inviter sur Afrolook',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  void _inviteFriend() {
    Share.share(
      'Rejoins-moi sur Afrolook 🌍 — la plateforme mode & lifestyle africaine !\n'
      'Télécharge l\'app : https://afrolook.app',
      subject: 'Invitation Afrolook',
    );
  }

  Widget _buildAdBanner({required String key}) {
    return Container(
      key: ValueKey(key),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _colors.border),
      ),
      child: MrecAdWidget(
        onAdLoaded: () {
          printVm('✅ Native Ad chargée: $key');
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
      return _l10n.convDaysShort(difference.inDays);
    } else if (difference.inHours > 0) {
      return _l10n.convHoursShort(difference.inHours);
    } else if (difference.inMinutes > 0) {
      return _l10n.convMinutesShort(difference.inMinutes);
    } else {
      return _l10n.convJustNowCap;
    }
  }
}

// ---------------------------------------------------------------------------
// ConversationList — item visuel refait (ring gradient, badge PRO, épinglé)
// ---------------------------------------------------------------------------
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
  final bool isPinned;
  final bool isPro;
  final String? messageType;
  final UserData? chatFriend;
  /// Timestamp (ms) du dernier message non lu — 0 si tout est lu.
  final int unreadSinceMs;

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
    this.isPinned = false,
    this.isPro = false,
    this.messageType,
    this.chatFriend,
    this.unreadSinceMs = 0,
  }) : super(key: key);

  @override
  _ConversationListState createState() => _ConversationListState();
}

class _ConversationListState extends State<ConversationList> {
  late AppColors _colors;
  late AppLocalizations _l10n;

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    _l10n = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: widget.isPinned
            ? _colors.primary.withAlpha(13)  // légère teinte pour épinglé
            : _colors.background,
        border: Border(bottom: BorderSide(color: _colors.divider, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          _buildAvatar(),
          const SizedBox(width: 12),
          _buildMessageInfo(),
          const SizedBox(width: 8),
          _buildTrailing(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    if (widget.isLoading) {
      return Container(
        width: 52, height: 52,
        decoration: BoxDecoration(shape: BoxShape.circle, color: _colors.textSecondary),
      );
    }
    return Stack(
      children: [
        // Ring gradient
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: widget.isOnline
                  ? [_colors.primary, Color.lerp(_colors.primary, const Color(0xFF1abc9c), 0.6)!]
                  : [_colors.textSecondary, _colors.border],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: widget.isOnline
                ? [BoxShadow(color: _colors.primary.withAlpha(77), blurRadius: 8, spreadRadius: 1)]
                : [],
          ),
          padding: const EdgeInsets.all(2.5),
          child: CircleAvatar(
            radius: 23,
            backgroundImage: widget.imageUrl.isNotEmpty
                ? NetworkImage(widget.imageUrl)
                : const AssetImage('assets/icon/amixilo3.png') as ImageProvider,
            backgroundColor: _colors.surface,
          ),
        ),
        // Point de présence en bas à droite
        Positioned(
          bottom: 1,
          right: 1,
          child: UserPresenceWidget(
            userId: widget.id_user,
            size: 12.0,
            showTextStatus: false,
          ),
        ),
        // Badge abonnement en bas à gauche
        if (widget.chatFriend != null)
          Positioned(
            bottom: 0,
            left: 0,
            child: UserBadgeWidget(
              user: widget.chatFriend,
              size: 13,
              withBackground: true,
            ),
          ),
      ],
    );
  }

  Widget _buildMessageInfo() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icône épinglé
              if (widget.isPinned) ...[
                Icon(Icons.push_pin, size: 13, color: _colors.primary),
                const SizedBox(width: 3),
              ],
              // Nom
              Flexible(
                child: Text(
                  widget.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _colors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Badge PRO entreprise
              if (widget.isPro) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFDB813), Color(0xFFFF8C00)],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'PRO',
                    style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          widget.isLoading
              ? Container(width: 140, height: 13, color: _colors.textSecondary)
              : Row(
            children: [
              if (widget.isLastMessageFromMe) ...[
                Text(
                  _l10n.convYouPrefix,
                  style: TextStyle(fontSize: 13, color: _colors.primary, fontWeight: FontWeight.w500),
                ),
              ],
              Expanded(
                child: Text(
                  widget.isTyping
                      ? '${_l10n.convTyping}...'
                      : widget.messageText,
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.isTyping
                        ? _colors.primary
                        : (widget.isMessageRead ? _colors.textSecondary : _colors.textPrimary),
                    fontWeight: widget.isMessageRead ? FontWeight.normal : FontWeight.w500,
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

  Widget _buildTrailing() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.time.isNotEmpty)
          Text(
            widget.time,
            style: TextStyle(
              fontSize: 11,
              color: widget.isMessageRead ? _colors.textSecondary : _colors.primary,
              fontWeight: widget.isMessageRead ? FontWeight.normal : FontWeight.w600,
            ),
          ),
        const SizedBox(height: 5),
        if (widget.unreadCount > 0) ...[
          Container(
            constraints: const BoxConstraints(minWidth: 22),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: _colors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.unreadCount > 99 ? '99+' : '${widget.unreadCount}',
              style: const TextStyle(fontSize: 11, color: Colors.black, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          if (widget.unreadSinceMs > 0)
            _UnreadEmotionBadge(unreadSinceMs: widget.unreadSinceMs),
        ] else if (widget.isSearchResult)
          Icon(Icons.add_circle_outline, color: _colors.primary, size: 20)
        else if (widget.isLastMessageFromMe)
          widget.messageStatus
        else
          const SizedBox(height: 22),
      ],
    );
  }
}

// ── Émotion animée sur messages non lus (chats simples) ────────────────────

class _UnreadEmotionBadge extends StatefulWidget {
  final int unreadSinceMs;
  const _UnreadEmotionBadge({required this.unreadSinceMs});

  @override
  State<_UnreadEmotionBadge> createState() => _UnreadEmotionBadgeState();
}

class _UnreadEmotionBadgeState extends State<_UnreadEmotionBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  int get _level {
    final elapsed = DateTime.now().millisecondsSinceEpoch - widget.unreadSinceMs;
    if (elapsed < 5 * 60 * 1000) return 0;
    if (elapsed < 30 * 60 * 1000) return 1;
    if (elapsed < 2 * 60 * 60 * 1000) return 2;
    if (elapsed < 6 * 60 * 60 * 1000) return 3;
    return 4;
  }

  static const _emojis = ['', '👀', '😅', '🥺', '😱'];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = _level;
    if (level == 0) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        double scale;
        double opacity;
        double angle = 0;

        switch (level) {
          case 1: // 👀 clignote → scale 0.7↔1.0 (évite Opacity+emoji Impeller bug)
            scale = 0.7 + _ctrl.value * 0.3;
            opacity = 1.0;
            break;
          case 2: // 😅 tremble légèrement
            scale = 1.0 + (_ctrl.value - 0.5).abs() * 0.12;
            opacity = 1.0;
            angle = (_ctrl.value - 0.5) * 0.25;
            break;
          case 3: // 🥺 pulse lent
            scale = 0.85 + _ctrl.value * 0.3;
            opacity = 1.0;
            break;
          case 4: // 😱 pulse rapide et fort
            scale = 0.75 + _ctrl.value * 0.5;
            opacity = 1.0;
            angle = (_ctrl.value - 0.5) * 0.4;
            break;
          default:
            scale = 1.0;
            opacity = 1.0;
        }

        // RepaintBoundary évite le bug Impeller SetInheritedOpacity sur emoji
        return Padding(
          padding: const EdgeInsets.only(top: 3),
          child: RepaintBoundary(
            child: Transform.rotate(
              angle: angle,
              child: Transform.scale(
                scale: scale,
                child: Text(_emojis[level], style: const TextStyle(fontSize: 15)),
              ),
            ),
          ),
        );
      },
    );
  }
}


// ── Animation "appel à regarder" pour les groupes ──────────────────────────

class _GroupAttentionBadge extends StatefulWidget {
  final int lastMsgAtMs;
  const _GroupAttentionBadge({required this.lastMsgAtMs});

  @override
  State<_GroupAttentionBadge> createState() => _GroupAttentionBadgeState();
}

class _GroupAttentionBadgeState extends State<_GroupAttentionBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // < 5 min → 🔔 pulse rapide (nouveau message)
  // 5-30 min → 👁️ clignote
  // 30min-2h → 👁️ + rotation lente
  // 2h+ → 👁️ pulse fort + rotation
  int get _level {
    if (widget.lastMsgAtMs <= 0) return 0;
    final elapsed = DateTime.now().millisecondsSinceEpoch - widget.lastMsgAtMs;
    if (elapsed < 5 * 60 * 1000) return 0;
    if (elapsed < 30 * 60 * 1000) return 1;
    if (elapsed < 2 * 60 * 60 * 1000) return 2;
    return 3;
  }

  @override
  void initState() {
    super.initState();
    final duration = _level <= 1
        ? const Duration(milliseconds: 900)
        : const Duration(milliseconds: 600);
    _ctrl = AnimationController(vsync: this, duration: duration)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final level = _level;
    if (level == 0) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        double scale;
        double angle = 0;
        String icon;

        switch (level) {
          case 1: // 👁️ scale 0.6↔1.0 (effet clignotant sans Opacity)
            icon = '👁️';
            scale = 0.6 + t * 0.4;
            break;
          case 2: // 👁️ tourne lentement
            icon = '👁️';
            scale = 0.9 + t * 0.2;
            angle = (t - 0.5) * 0.3;
            break;
          case 3: // 👁️ pulse fort
            icon = '👁️';
            scale = 0.8 + t * 0.5;
            angle = (t - 0.5) * 0.5;
            break;
          default:
            return const SizedBox.shrink();
        }

        // RepaintBoundary évite le bug Impeller SetInheritedOpacity sur emoji
        return RepaintBoundary(
          child: Transform.rotate(
            angle: angle,
            child: Transform.scale(
              scale: scale,
              child: Text(icon, style: const TextStyle(fontSize: 14)),
            ),
          ),
        );
      },
    );
  }
}
