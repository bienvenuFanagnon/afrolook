import 'package:afrolook_api_client/afrolook_api_client.dart' show ApiException;
import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/services/api/paid_content_b2_api.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:afrotok/services/api/contenu_payant_api.dart';
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
  late Future<LegacySnap> _comments = ContenuPayantApi.comments(widget.contentId, limit: 30);

  void _reload() {
    if (mounted) setState(() => _comments = ContenuPayantApi.comments(widget.contentId, limit: 30));
  }

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
      await ContenuPayantApi.addComment(widget.contentId, text);
      _controller.clear();
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ContenuPayantApi.message(e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteComment(String docId) async {
    try {
      await ContenuPayantApi.deleteComment(docId);
      _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ContenuPayantApi.message(e))));
    }
  }

  /// Modifie MON commentaire (`PATCH /paid-content-comments/{id}`, 1 à 1000 caractères) ; la liste indique ensuite « modifié ».
  Future<void> _editComment(String docId, String current) async {
    if (!mounted) return;
    final colors = AppColors.of(context);
    final ctrl = TextEditingController(text: current);
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(tr('Modifier le commentaire'), style: TextStyle(color: colors.textPrimary, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          minLines: 1,
          maxLines: 5,
          maxLength: 1000,
          style: TextStyle(color: colors.textPrimary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Annuler'))),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(tr('Enregistrer'))),
        ],
      ),
    );
    ctrl.dispose();
    if (text == null || text.isEmpty || text == current.trim()) return;
    try {
      await PaidExtrasApi.editComment(docId, text);
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e is ApiException && e.status == 403 ? tr('Tu ne peux modifier que tes propres commentaires.') : PaidContentMessages.of(e)),
        action: SnackBarAction(label: tr('Réessayer'), onPressed: () => _editComment(docId, text)),
      ));
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
        FutureBuilder<LegacySnap>(
          future: _comments,
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
                final data = d.data();
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
          CircleAvatar(onBackgroundImageError: (avatarUrl.isNotEmpty
                ? CachedNetworkImageProvider(avatarUrl)
                : null) != null ? (Object _, StackTrace? __) {} : null, 
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
                        edited ? '$date · ${tr('modifié')}' : date,
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
                                  Text(tr('Modifier'), style: TextStyle(color: colors.textPrimary, fontSize: 13)),
                                ]),
                              ),
                            if (canDelete)
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(children: [
                                  const Icon(Icons.delete, size: 16, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Text(tr('Supprimer'), style: const TextStyle(color: Colors.red, fontSize: 13)),
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
