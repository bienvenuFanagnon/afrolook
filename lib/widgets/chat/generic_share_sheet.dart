import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/model_data.dart';
import '../../pages/chat/group/group_chat_page.dart';
import '../../providers/authProvider.dart';
import '../../services/utils/group_permission_utils.dart';
import '../../theme/app_colors.dart';

/// Partage un produit, un contenu VIP ou un live dans une conversation ou un groupe.
/// itemType : 'product' | 'vip' | 'live'
class GenericShareSheet extends StatefulWidget {
  final String itemId;
  final String itemType;
  final String title;
  final String subtitle;
  final String thumbnail;
  final IconData icon;

  const GenericShareSheet({
    Key? key,
    required this.itemId,
    required this.itemType,
    required this.title,
    required this.subtitle,
    required this.thumbnail,
    required this.icon,
  }) : super(key: key);

  @override
  State<GenericShareSheet> createState() => _GenericShareSheetState();
}

class _GenericShareSheetState extends State<GenericShareSheet>
    with SingleTickerProviderStateMixin {
  late AppColors _colors;
  late UserAuthProvider _auth;
  late TabController _tabController;

  List<Chat> _chats = [];
  List<Map<String, dynamic>> _groups = [];
  bool _loadingChats = true;
  bool _loadingGroups = true;
  String? _sendingId;

  @override
  void initState() {
    super.initState();
    _auth = Provider.of<UserAuthProvider>(context, listen: false);
    _tabController = TabController(length: 2, vsync: this);
    _loadChats();
    _loadGroups();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    try {
      final myId = _auth.loginUserData.id!;
      final snap = await FirebaseFirestore.instance
          .collection('Chats')
          .where(Filter.or(
            Filter('receiver_id', isEqualTo: myId),
            Filter('sender_id', isEqualTo: myId),
          ))
          .where('type', isEqualTo: ChatType.USER.name)
          .orderBy('updated_at', descending: true)
          .limit(20)
          .get();

      final chats = <Chat>[];
      for (final doc in snap.docs) {
        final chat = Chat.fromJson(doc.data());
        final otherId = chat.senderId == myId ? chat.receiverId : chat.senderId;
        if (otherId != null) {
          final userDoc = await FirebaseFirestore.instance.collection('Users').doc(otherId).get();
          if (userDoc.exists) chat.chatFriend = UserData.fromJson(userDoc.data()!);
        }
        chats.add(chat);
      }
      if (mounted) setState(() { _chats = chats; _loadingChats = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingChats = false);
    }
  }

  Future<void> _loadGroups() async {
    try {
      final myId = _auth.loginUserData.id!;
      final snap = await FirebaseFirestore.instance
          .collection('GroupChats')
          .where('member_ids', arrayContains: myId)
          .get();

      final sorted = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList()
        ..sort((a, b) {
          final aAt = (a['last_message_at'] as int?) ?? 0;
          final bAt = (b['last_message_at'] as int?) ?? 0;
          return bAt.compareTo(aAt);
        });
      if (mounted) {
        setState(() {
          _groups = sorted;
          _loadingGroups = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingGroups = false);
    }
  }

  Future<void> _sendToChat(Chat chat) async {
    if (_sendingId != null) return;
    setState(() => _sendingId = chat.id);
    try {
      final myId = _auth.loginUserData.id!;
      final now = DateTime.now().millisecondsSinceEpoch;
      final msgId = FirebaseFirestore.instance.collection('Messages').doc().id;

      await FirebaseFirestore.instance.collection('Messages').doc(msgId).set({
        'id': msgId,
        'send_by': myId,
        'receiverBy': chat.senderId == myId ? chat.receiverId : chat.senderId,
        'chat_id': chat.id,
        'message_type': 'link_share',
        'message': widget.title,
        'imageText': widget.thumbnail,
        'item_id': widget.itemId,
        'item_type': widget.itemType,
        'item_title': widget.title,
        'item_subtitle': widget.subtitle,
        'item_thumbnail': widget.thumbnail,
        'is_valide': true,
        'is_deleted': false,
        'is_encrypted': false,
        'message_state': 'NONLU',
        'create_at_time_spam': now,
        'reply_message': {'message': '', 'message_type': 'text', 'messageId': '', 'replyTo': ''},
      });
      await FirebaseFirestore.instance.collection('Chats').doc(chat.id).update({
        'last_message': '📎 ${widget.title}',
        'updated_at': now,
      });
      _done();
    } catch (_) {
      if (mounted) setState(() => _sendingId = null);
    }
  }

  Future<void> _sendToGroup(Map<String, dynamic> group) async {
    final groupId = group['id'] as String;
    final groupName = group['name'] as String? ?? '';
    final groupImage = group['image_url'] as String?;
    if (_sendingId != null) return;

    final myId = _auth.loginUserData.id!;
    final memberDoc = await FirebaseFirestore.instance
        .collection('GroupChats')
        .doc(groupId)
        .collection('members')
        .doc(myId)
        .get();
    final role = memberDoc.data()?['role'] as String? ?? 'member';

    // Vérification centralisée des permissions de partage
    final groupData = await GroupPermissionUtils.loadGroupData(groupId);
    final canShare = GroupPermissionUtils.canShare(
      groupData: groupData,
      userId: myId,
      userRole: role,
    );
    if (!canShare) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              GroupPermissionUtils.isGroupFrozen(groupData)
                  ? 'Groupe gelé — le propriétaire n\'est plus Gold.'
                  : 'Partage non autorisé dans ce groupe.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _sendingId = groupId);
    try {
      final me = _auth.loginUserData;
      final now = DateTime.now().millisecondsSinceEpoch;
      final msgId = FirebaseFirestore.instance.collection('GroupMessages').doc().id;

      await FirebaseFirestore.instance.collection('GroupMessages').doc(msgId).set({
        'id': msgId,
        'group_id': groupId,
        'send_by': me.id,
        'sender_pseudo': me.pseudo ?? '',
        'sender_image': me.imageUrl ?? '',
        'message': widget.title,
        'message_type': 'link_share',
        'item_id': widget.itemId,
        'item_type': widget.itemType,
        'item_title': widget.title,
        'item_subtitle': widget.subtitle,
        'item_thumbnail': widget.thumbnail,
        'is_valide': true,
        'is_deleted': false,
        'is_encrypted': false,
        'reply_to_id': '',
        'create_at_time_spam': now,
      });
      final otherMembers = (group['member_ids'] as List<dynamic>? ?? [])
          .cast<String>()
          .where((id) => id != me.id)
          .toList();
      final groupUpdate = <String, dynamic>{
        'last_message': '📎 ${widget.title}',
        'last_message_at': now,
      };
      for (final id in otherMembers) {
        groupUpdate['unread_counts.$id'] = FieldValue.increment(1);
      }
      await FirebaseFirestore.instance.collection('GroupChats').doc(groupId).update(groupUpdate);
      // Notifier chaque membre du groupe
      _notifyGroupMembers(
        group: group,
        now: now,
        notifTitre: '${me.pseudo ?? ''} a partagé ${widget.subtitle}',
        notifDesc: widget.title,
        itemId: widget.itemId,
      );
      _doneAndOpenGroup(groupId: groupId, groupName: groupName, groupImage: groupImage);
    } catch (_) {
      if (mounted) setState(() => _sendingId = null);
    }
  }

  /// Enregistre une NotificationData + envoie un push OneSignal à chaque membre (sauf moi).
  Future<void> _notifyGroupMembers({
    required Map<String, dynamic> group,
    required int now,
    required String notifTitre,
    required String notifDesc,
    required String itemId,
  }) async {
    try {
      final myId = _auth.loginUserData.id!;
      final memberIds = List<String>.from(group['member_ids'] as List? ?? []);
      final others = memberIds.where((id) => id != myId).toList();
      if (others.isEmpty) return;

      final firestore = FirebaseFirestore.instance;
      final oneSignalIds = <String>[];

      for (var i = 0; i < others.length; i += 10) {
        final chunk = others.sublist(i, i + 10 > others.length ? others.length : i + 10);
        final snap = await firestore.collection('Users').where(FieldPath.documentId, whereIn: chunk).get();
        for (final doc in snap.docs) {
          final data = doc.data();
          final osId = data['oneIgnalUserid'] as String?;
          if (osId != null && osId.length > 5) oneSignalIds.add(osId);
          final notifId = firestore.collection('Notifications').doc().id;
          final notif = NotificationData(
            id: notifId,
            titre: notifTitre,
            description: notifDesc,
            user_id: myId,
            receiver_id: doc.id,
            post_id: itemId,
            type: NotificationType.MESSAGE.name,
            status: PostStatus.VALIDE.name,
            is_open: false,
            users_id_view: [],
            createdAt: now,
            updatedAt: now,
          );
          firestore.collection('Notifications').doc(notifId).set(notif.toJson());
        }
      }

      if (oneSignalIds.isNotEmpty) {
        _auth.sendNotification(
          userIds: oneSignalIds,
          smallImage: _auth.loginUserData.imageUrl ?? '',
          send_user_id: myId,
          recever_user_id: group['id'] as String,
          message: notifTitre,
          type_notif: NotificationType.MESSAGE.name,
          post_id: itemId,
          post_type: widget.itemType,
          chat_id: group['id'] as String,
        );
      }
    } catch (_) {}
  }

  void _done() {
    if (!mounted) return;
    setState(() => _sendingId = null);
    final nav = Navigator.of(context);
    final snack = ScaffoldMessenger.of(context);
    final color = AppColors.of(context).primary;
    nav.pop();
    snack.showSnackBar(SnackBar(
      content: const Text('Envoyé !'),
      backgroundColor: color,
      duration: const Duration(seconds: 2),
    ));
  }

  void _doneAndOpenGroup({required String groupId, required String groupName, String? groupImage}) {
    if (!mounted) return;
    setState(() => _sendingId = null);
    final nav = Navigator.of(context);
    final snack = ScaffoldMessenger.of(context);
    final color = AppColors.of(context).primary;
    nav.pop();
    snack.showSnackBar(SnackBar(
      content: const Text('Envoyé !'),
      backgroundColor: color,
      duration: const Duration(seconds: 2),
    ));
    nav.push(MaterialPageRoute(
      builder: (_) => GroupChatPage(groupId: groupId, groupName: groupName, groupImageUrl: groupImage),
    ));
  }

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(color: _colors.border, borderRadius: BorderRadius.circular(2)),
          ),
          _buildPreview(),
          const SizedBox(height: 4),
          TabBar(
            controller: _tabController,
            labelColor: _colors.primary,
            unselectedLabelColor: _colors.textSecondary,
            indicatorColor: _colors.primary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [Tab(text: 'Conversations'), Tab(text: 'Groupes')],
          ),
          Divider(height: 1, color: _colors.border.withOpacity(0.3)),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: TabBarView(
              controller: _tabController,
              children: [_buildChatList(), _buildGroupList()],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 52, height: 52,
              color: _colors.surfaceVariant,
              child: widget.thumbnail.isNotEmpty
                  ? CachedNetworkImage(imageUrl: widget.thumbnail, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Icon(widget.icon, color: _colors.textSecondary))
                  : Icon(widget.icon, color: _colors.textSecondary, size: 28),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(widget.icon, size: 14, color: _colors.primary),
                    const SizedBox(width: 4),
                    Text(widget.subtitle,
                        style: TextStyle(color: _colors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                  ],
                ),
                Text(
                  widget.title.length > 60 ? '${widget.title.substring(0, 60)}...' : widget.title,
                  style: TextStyle(color: _colors.textSecondary, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    if (_loadingChats) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    }
    if (_chats.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(24),
          child: Text('Aucune conversation', style: TextStyle(color: _colors.textSecondary))));
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _chats.length,
      itemBuilder: (_, i) {
        final chat = _chats[i];
        final friend = chat.chatFriend;
        final pseudo = friend?.pseudo ?? '…';
        final img = friend?.imageUrl ?? '';
        final sending = _sendingId == chat.id;
        return ListTile(
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: _colors.surfaceVariant,
            backgroundImage: img.isNotEmpty ? CachedNetworkImageProvider(img) : null,
            child: img.isEmpty ? Icon(Icons.person, color: _colors.textSecondary) : null,
          ),
          title: Text('@$pseudo', style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
          trailing: sending
              ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: _colors.primary))
              : Icon(Icons.send_rounded, color: _colors.primary, size: 20),
          onTap: sending ? null : () => _sendToChat(chat),
        );
      },
    );
  }

  Widget _buildGroupList() {
    if (_loadingGroups) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    }
    if (_groups.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(24),
          child: Text('Aucun groupe', style: TextStyle(color: _colors.textSecondary))));
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _groups.length,
      itemBuilder: (_, i) {
        final g = _groups[i];
        final name = g['name'] as String? ?? 'Groupe';
        final img = g['image_url'] as String? ?? '';
        final sending = _sendingId == g['id'];
        return ListTile(
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: _colors.surfaceVariant,
            backgroundImage: img.isNotEmpty ? CachedNetworkImageProvider(img) : null,
            child: img.isEmpty ? Icon(Icons.group_rounded, color: _colors.textSecondary) : null,
          ),
          title: Text(name, style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
          trailing: sending
              ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: _colors.primary))
              : Icon(Icons.send_rounded, color: _colors.primary, size: 20),
          onTap: sending ? null : () => _sendToGroup(g),
        );
      },
    );
  }
}
