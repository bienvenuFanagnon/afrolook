import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
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
          .orderBy('last_message_at', descending: true)
          .limit(20)
          .get();

      if (mounted) {
        setState(() {
          _groups = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
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
      await FirebaseFirestore.instance.collection('Messages').doc(msgId).set({
        'id': msgId,
        'sendBy': myId,
        'chat_id': chat.id,
        'messageType': 'post',
        'message': post.description ?? '',
        'post_id': post.id,
        'post_thumbnail': thumbnail,
        'post_data_type': post.dataType ?? 'IMAGE',
        'post_owner_id': post.user_id ?? '',
        'is_valide': true,
        'is_encrypted': false,
        'message_state': 'NONLU',
        'create_at_time_spam': DateTime.now().millisecondsSinceEpoch,
        'replyMessage': {
          'message': '', 'messageType': '', 'messageId': '', 'replyTo': ''
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
    if (_sendingId != null) return;
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
      await FirebaseFirestore.instance
          .collection('GroupChats')
          .doc(groupId)
          .update({
        'last_message': _lastMsgLabel(post),
        'last_message_at': now,
      });
      _done();
    } catch (_) {
      if (mounted) setState(() => _sendingId = null);
    }
  }

  void _done() {
    if (!mounted) return;
    setState(() => _sendingId = null);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Post envoye !'),
      backgroundColor: AppColors.of(context).primary,
      duration: const Duration(seconds: 2),
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
