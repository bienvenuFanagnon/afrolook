import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/model_data.dart';
import '../../pages/chat/group/group_chat_page.dart';
import '../../providers/authProvider.dart';
import '../../services/utils/group_permission_utils.dart';
import '../../theme/app_colors.dart';

/// Bottom sheet pour envoyer un post dans une conversation directe ou un groupe.
class PostShareSheet extends StatefulWidget {
  final Post post;
  const PostShareSheet({Key? key, required this.post}) : super(key: key);

  @override
  State<PostShareSheet> createState() => _PostShareSheetState();
}

class _PostShareSheetState extends State<PostShareSheet>
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

  // ──────────────────────────────────────────────────────────────────────────
  // Chargement des données
  // ──────────────────────────────────────────────────────────────────────────

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
        final otherId =
            chat.senderId == myId ? chat.receiverId : chat.senderId;
        if (otherId != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('Users')
              .doc(otherId)
              .get();
          if (userDoc.exists) {
            chat.chatFriend = UserData.fromJson(userDoc.data()!);
          }
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

  // ──────────────────────────────────────────────────────────────────────────
  // Envoi
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> _sendToChat(Chat chat) async {
    if (_sendingId != null) return;
    setState(() => _sendingId = chat.id);
    try {
      final myId = _auth.loginUserData.id!;
      final post = widget.post;
      final thumbnail = _getThumbnail(post);

      final msgId = FirebaseFirestore.instance.collection('Messages').doc().id;
      final now = DateTime.now().millisecondsSinceEpoch;
      await FirebaseFirestore.instance.collection('Messages').doc(msgId).set({
        'id': msgId,
        'send_by': myId,
        'receiverBy': chat.senderId == myId ? chat.receiverId : chat.senderId,
        'chat_id': chat.id,
        'message_type': 'post',
        'message': post.description ?? '',
        'imageText': thumbnail,
        'post_id': post.id,
        'post_data_type': post.dataType ?? 'IMAGE',
        'is_valide': true,
        'is_encrypted': false,
        'message_state': 'NONLU',
        'create_at_time_spam': now,
        'reply_message': {
          'message': '', 'message_type': 'text', 'messageId': '', 'replyTo': ''
        },
      });
      await FirebaseFirestore.instance
          .collection('Chats')
          .doc(chat.id)
          .update({
        'last_message': _lastMsgLabel(post),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
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

    // Vérification centralisée des permissions de partage
    final myId = _auth.loginUserData.id!;
    final memberDoc = await FirebaseFirestore.instance
        .collection('GroupChats').doc(groupId).collection('members').doc(myId).get();
    final role = memberDoc.data()?['role'] as String? ?? 'member';
    final groupData = await GroupPermissionUtils.loadGroupData(groupId);
    if (!GroupPermissionUtils.canShare(groupData: groupData, userId: myId, userRole: role)) {
      if (mounted) {
        final isFrozen = GroupPermissionUtils.isGroupFrozen(groupData);
        showDialog(
          context: context,
          builder: (ctx) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.red.withOpacity(0.12),
                    child: Icon(
                      isFrozen ? Icons.ac_unit_rounded : Icons.block_rounded,
                      color: Colors.red,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isFrozen ? 'Groupe gelé' : 'Partage non autorisé',
                    style: TextStyle(
                      color: _colors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isFrozen
                        ? 'Ce groupe est gelé car le propriétaire n\'est plus abonné Gold. Aucun partage n\'est possible.'
                        : 'L\'administrateur a désactivé le partage dans ce groupe.',
                    style: TextStyle(color: _colors.textSecondary, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _colors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Compris',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return;
    }

    setState(() => _sendingId = groupId);
    try {
      final me = _auth.loginUserData;
      final post = widget.post;
      final thumbnail = _getThumbnail(post);
      final now = DateTime.now().millisecondsSinceEpoch;

      final msgId =
          FirebaseFirestore.instance.collection('GroupMessages').doc().id;
      await FirebaseFirestore.instance
          .collection('GroupMessages')
          .doc(msgId)
          .set({
        'id': msgId,
        'group_id': groupId,
        'send_by': me.id,
        'sender_pseudo': me.pseudo ?? '',
        'sender_image': me.imageUrl ?? '',
        'message': post.description ?? '',
        'message_type': 'post',
        'post_id': post.id,
        'post_thumbnail': thumbnail,
        'post_data_type': post.dataType ?? 'IMAGE',
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
        'last_message': _lastMsgLabel(post),
        'last_message_at': now,
        'updated_at': now,
      };
      for (final id in otherMembers) {
        groupUpdate['unread_counts.$id'] = FieldValue.increment(1);
      }
      await FirebaseFirestore.instance
          .collection('GroupChats')
          .doc(groupId)
          .update(groupUpdate);
      // Notifier chaque membre du groupe
      _notifyGroupMembers(
        group: group,
        now: now,
        notifTitre: '${me.pseudo ?? ''} a partagé un post',
        notifDesc: post.description?.isNotEmpty == true ? post.description! : _lastMsgLabel(post),
        postId: post.id ?? '',
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
    required String postId,
  }) async {
    try {
      final myId = _auth.loginUserData.id!;
      final memberIds = List<String>.from(group['member_ids'] as List? ?? []);
      final others = memberIds.where((id) => id != myId).toList();
      if (others.isEmpty) return;

      final firestore = FirebaseFirestore.instance;
      final oneSignalIds = <String>[];

      // Récupérer les IDs OneSignal en chunks de 10 (limite Firestore whereIn)
      for (var i = 0; i < others.length; i += 10) {
        final chunk = others.sublist(i, i + 10 > others.length ? others.length : i + 10);
        final snap = await firestore.collection('Users').where(FieldPath.documentId, whereIn: chunk).get();
        for (final doc in snap.docs) {
          final data = doc.data();
          final osId = data['oneIgnalUserid'] as String?;
          if (osId != null && osId.length > 5) oneSignalIds.add(osId);
          // Enregistrer une NotificationData pour chaque membre
          final notifId = firestore.collection('Notifications').doc().id;
          final notif = NotificationData(
            id: notifId,
            titre: notifTitre,
            description: notifDesc,
            user_id: myId,
            receiver_id: doc.id,
            post_id: postId,
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

      // Push OneSignal groupé
      if (oneSignalIds.isNotEmpty) {
        _auth.sendNotification(
          userIds: oneSignalIds,
          smallImage: _auth.loginUserData.imageUrl ?? '',
          send_user_id: myId,
          recever_user_id: group['id'] as String,
          message: notifTitre,
          type_notif: NotificationType.MESSAGE.name,
          post_id: postId,
          post_type: 'post',
          chat_id: group['id'] as String,
        );
      }
    } catch (_) {}
  }

  void _done() {
    if (!mounted) return;
    setState(() => _sendingId = null);
    final nav = Navigator.of(context);
    final msg = ScaffoldMessenger.of(context);
    final color = AppColors.of(context).primary;
    nav.pop();
    msg.showSnackBar(SnackBar(
      content: const Text('Post envoyé !'),
      backgroundColor: color,
      duration: const Duration(seconds: 2),
    ));
  }

  void _doneAndOpenGroup({
    required String groupId,
    required String groupName,
    String? groupImage,
  }) {
    if (!mounted) return;
    setState(() => _sendingId = null);
    final nav = Navigator.of(context);
    final msg = ScaffoldMessenger.of(context);
    final color = AppColors.of(context).primary;
    nav.pop();
    msg.showSnackBar(SnackBar(
      content: const Text('Post envoyé !'),
      backgroundColor: color,
      duration: const Duration(seconds: 2),
    ));
    nav.push(MaterialPageRoute(
      builder: (_) => GroupChatPage(
        groupId: groupId,
        groupName: groupName,
        groupImageUrl: groupImage,
      ),
    ));
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────────────────────────────────

  String _getThumbnail(Post post) {
    if (post.thumbnail != null && post.thumbnail!.isNotEmpty) {
      return post.thumbnail!;
    }
    if (post.dataType == 'IMAGE' ||
        post.dataType == PostDataType.IMAGE.name) {
      return post.images?.isNotEmpty == true ? post.images!.first : '';
    }
    return post.url_media ?? '';
  }

  String _lastMsgLabel(Post post) {
    final type = post.dataType ?? 'IMAGE';
    if (type == 'VIDEO') return 'Video partagee';
    if (type == 'AUDIO') return 'Audio partage';
    return 'Post partage';
  }

  IconData _postIcon(String? dataType) {
    switch (dataType) {
      case 'VIDEO':
        return Icons.videocam_rounded;
      case 'AUDIO':
        return Icons.audiotrack_rounded;
      case 'TEXT':
        return Icons.article_outlined;
      default:
        return Icons.image_rounded;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────────────

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
            decoration: BoxDecoration(
                color: _colors.border,
                borderRadius: BorderRadius.circular(2)),
          ),
          _buildPostPreview(),
          const SizedBox(height: 4),
          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: _colors.primary,
            unselectedLabelColor: _colors.textSecondary,
            indicatorColor: _colors.primary,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [
              Tab(text: 'Conversations'),
              Tab(text: 'Groupes'),
            ],
          ),
          Divider(height: 1, color: _colors.border.withOpacity(0.3)),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChatList(),
                _buildGroupList(),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPostPreview() {
    final post = widget.post;
    final thumb = _getThumbnail(post);
    final dataType = post.dataType ?? 'IMAGE';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 52, height: 52,
              color: _colors.surfaceVariant,
              child: thumb.isNotEmpty
                  ? Image.network(thumb, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(_postIcon(dataType), color: _colors.textSecondary))
                  : Icon(_postIcon(dataType),
                      color: _colors.textSecondary, size: 28),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_postIcon(dataType),
                        size: 14, color: _colors.primary),
                    const SizedBox(width: 4),
                    Text(
                      _typeLabel(dataType),
                      style: TextStyle(
                          color: _colors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                  ],
                ),
                if ((post.description ?? '').isNotEmpty)
                  Text(
                    post.description!.length > 60
                        ? '${post.description!.substring(0, 60)}...'
                        : post.description!,
                    style: TextStyle(
                        color: _colors.textSecondary, fontSize: 12),
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

  String _typeLabel(String? dataType) {
    switch (dataType) {
      case 'VIDEO':
        return 'Video Afrolook';
      case 'AUDIO':
        return 'Audio Afrolook';
      case 'TEXT':
        return 'Article Afrolook';
      default:
        return 'Post Afrolook';
    }
  }

  Widget _buildChatList() {
    if (_loadingChats) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      ));
    }
    if (_chats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Aucune conversation',
              style: TextStyle(color: _colors.textSecondary)),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _chats.length,
      itemBuilder: (_, i) => _buildChatTile(_chats[i]),
    );
  }

  Widget _buildGroupList() {
    if (_loadingGroups) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      ));
    }
    if (_groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Aucun groupe',
              style: TextStyle(color: _colors.textSecondary)),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      itemCount: _groups.length,
      itemBuilder: (_, i) => _buildGroupTile(_groups[i]),
    );
  }

  Widget _buildChatTile(Chat chat) {
    final friend = chat.chatFriend;
    final isSending = _sendingId == chat.id;
    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            friend?.imageUrl != null && friend!.imageUrl!.isNotEmpty
                ? CachedNetworkImageProvider(friend.imageUrl!)
                : null,
        backgroundColor: _colors.surfaceVariant,
        child: friend?.imageUrl == null || friend!.imageUrl!.isEmpty
            ? Icon(Icons.person, color: _colors.textSecondary)
            : null,
      ),
      title: Text(
        '@${friend?.pseudo ?? '...'}',
        style: TextStyle(
            color: _colors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14),
      ),
      trailing: isSending
          ? SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                  color: _colors.primary, strokeWidth: 2))
          : Icon(Icons.send_rounded, color: _colors.primary, size: 20),
      onTap: () => _sendToChat(chat),
    );
  }

  Widget _buildGroupTile(Map<String, dynamic> group) {
    final groupId = group['id'] as String;
    final name = group['name'] as String? ?? 'Groupe';
    final imageUrl = group['image_url'] as String? ?? '';
    final memberCount = (group['member_ids'] as List?)?.length ?? 0;
    final isSending = _sendingId == groupId;

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: imageUrl.isNotEmpty
            ? CachedNetworkImageProvider(imageUrl)
            : null,
        backgroundColor: _colors.surfaceVariant,
        child: imageUrl.isEmpty
            ? Icon(Icons.group_rounded, color: _colors.textSecondary)
            : null,
      ),
      title: Text(
        name,
        style: TextStyle(
            color: _colors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 14),
      ),
      subtitle: Text(
        '$memberCount membre${memberCount > 1 ? 's' : ''}',
        style: TextStyle(color: _colors.textSecondary, fontSize: 12),
      ),
      trailing: isSending
          ? SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                  color: _colors.primary, strokeWidth: 2))
          : Icon(Icons.send_rounded, color: _colors.primary, size: 20),
      onTap: () => _sendToGroup(group),
    );
  }
}
