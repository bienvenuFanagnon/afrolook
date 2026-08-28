import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ContentCommentsSection extends StatefulWidget {
  final String contentId;

  const ContentCommentsSection({Key? key, required this.contentId})
      : super(key: key);

  @override
  State<ContentCommentsSection> createState() =>
      _ContentCommentsSectionState();
}

class _ContentCommentsSectionState extends State<ContentCommentsSection> {
  final _controller = TextEditingController();
  bool _sending = false;

  static const int _maxChars = 100;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isAdmin =>
      Provider.of<UserAuthProvider>(context, listen: false)
          .loginUserData
          .role ==
      'ADM';

  String get _currentUserId =>
      Provider.of<UserAuthProvider>(context, listen: false)
          .loginUserData
          .id ??
      '';

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (!_isAdmin && text.length > _maxChars) return;
    final authProvider =
        Provider.of<UserAuthProvider>(context, listen: false);
    final user = authProvider.loginUserData;
    if (user.id == null) return;

    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance.collection('ContentComments').add({
        'contentId': widget.contentId,
        'userId': user.id ?? '',
        'pseudo': user.pseudo ?? 'Utilisateur',
        'avatarUrl': user.imageUrl ?? '',
        'text': text,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      await FirebaseFirestore.instance
          .collection('ContentPaies')
          .doc(widget.contentId)
          .update({
        'comments': FieldValue.increment(1),
      });
      _controller.clear();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteComment(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('ContentComments')
          .doc(docId)
          .delete();
      await FirebaseFirestore.instance
          .collection('ContentPaies')
          .doc(widget.contentId)
          .update({'comments': FieldValue.increment(-1)});
    } catch (_) {}
  }

  Future<void> _editComment(String docId, String current) async {
    final colors = AppColors.of(context);
    final ctrl = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Modifier le commentaire',
            style: TextStyle(color: colors.textPrimary, fontSize: 14)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          maxLength: _isAdmin ? null : _maxChars,
          style: TextStyle(color: colors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: colors.primary),
            child: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (result != null && result.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('ContentComments')
          .doc(docId)
          .update({'text': result, 'editedAt': DateTime.now().millisecondsSinceEpoch});
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            '💬 COMMENTAIRES',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: colors.textSecondary),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _CommentInput(
            controller: _controller,
            sending: _sending,
            onSend: _send,
            colors: colors,
            isAdmin: _isAdmin,
            maxChars: _maxChars,
          ),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('ContentComments')
              .where('contentId', isEqualTo: widget.contentId)
              .orderBy('createdAt', descending: true)
              .limit(30)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Soyez le premier à commenter',
                  style: TextStyle(
                      fontSize: 11, color: colors.textSecondary),
                ),
              );
            }
            return Column(
              children: snap.data!.docs.map((d) {
                final data = d.data() as Map<String, dynamic>;
                final docId = d.id;
                final commentUserId = data['userId'] as String? ?? '';
                final canEdit = commentUserId == _currentUserId;
                final canDelete = canEdit || _isAdmin;
                return _CommentItem(
                  data: data,
                  docId: docId,
                  colors: colors,
                  canEdit: canEdit,
                  canDelete: canDelete,
                  onDelete: () => _deleteComment(docId),
                  onEdit: () => _editComment(docId, data['text'] as String? ?? ''),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _CommentInput extends StatefulWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final AppColors colors;
  final bool isAdmin;
  final int maxChars;

  const _CommentInput({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.colors,
    required this.isAdmin,
    required this.maxChars,
  });

  @override
  State<_CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<_CommentInput> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.colors.divider),
      ),
      child: Column(
        children: [
          TextField(
            controller: widget.controller,
            maxLength: widget.isAdmin ? null : widget.maxChars,
            maxLines: 2,
            minLines: 1,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                null,
            onChanged: (v) => setState(() => _count = v.length),
            style: TextStyle(
                fontSize: 13, color: widget.colors.textPrimary),
            decoration: InputDecoration(
              hintText: widget.isAdmin
                  ? 'Votre commentaire...'
                  : 'Votre avis... (${widget.maxChars} car. max)',
              hintStyle: TextStyle(
                  fontSize: 12, color: widget.colors.textSecondary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 8, 8),
            child: Row(
              children: [
                if (!widget.isAdmin)
                  Text(
                    '$_count/${widget.maxChars}',
                    style: TextStyle(
                      fontSize: 10,
                      color: _count > widget.maxChars - 10
                          ? Colors.red
                          : widget.colors.textSecondary,
                    ),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: widget.sending ? null : widget.onSend,
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: widget.sending
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                      : const Text('Envoyer',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentItem extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final AppColors colors;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _CommentItem({
    required this.data,
    required this.docId,
    required this.colors,
    required this.canEdit,
    required this.canDelete,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = data['avatarUrl'] as String? ?? '';
    final pseudo = data['pseudo'] as String? ?? 'Utilisateur';
    final text = data['text'] as String? ?? '';
    final ts = data['createdAt'] as int? ?? 0;
    final edited = data['editedAt'] != null;
    final date = _relativeTime(ts);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: colors.surface,
            backgroundImage: avatarUrl.isNotEmpty
                ? CachedNetworkImageProvider(avatarUrl)
                : null,
            child: avatarUrl.isEmpty
                ? Text(pseudo[0].toUpperCase(),
                    style: TextStyle(
                        fontSize: 12, color: colors.textPrimary))
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('@$pseudo',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary)),
                      const Spacer(),
                      Text(
                        edited ? '$date · modifié' : date,
                        style: TextStyle(
                            fontSize: 9,
                            color: colors.textSecondary),
                      ),
                      if (canEdit || canDelete) ...[
                        const SizedBox(width: 4),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert,
                              size: 14, color: colors.textSecondary),
                          padding: EdgeInsets.zero,
                          onSelected: (v) {
                            if (v == 'edit') onEdit();
                            if (v == 'delete') onDelete();
                          },
                          itemBuilder: (_) => [
                            if (canEdit)
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(children: [
                                  Icon(Icons.edit, size: 16, color: colors.textPrimary),
                                  const SizedBox(width: 8),
                                  Text('Modifier', style: TextStyle(color: colors.textPrimary, fontSize: 13)),
                                ]),
                              ),
                            if (canDelete)
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(children: [
                                  const Icon(Icons.delete, size: 16, color: Colors.red),
                                  const SizedBox(width: 8),
                                  const Text('Supprimer', style: TextStyle(color: Colors.red, fontSize: 13)),
                                ]),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(text,
                      style: TextStyle(
                          fontSize: 12,
                          color: colors.textPrimary,
                          height: 1.4)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _relativeTime(int ms) {
    if (ms == 0) return '';
    final diff =
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inHours < 1) return '${diff.inMinutes}min';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays < 30) return '${diff.inDays}j';
    return '${(diff.inDays / 30).floor()}mois';
  }
}
