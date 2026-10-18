import 'package:afrotok/services/read_meter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/authProvider.dart';
import '../../providers/chroniqueProvider.dart';
import '../../theme/app_colors.dart';
import 'chronique_widgets.dart';
import 'chroniqueform.dart';

/// Panneau des commentaires publics d'une chronique.
/// Lecture à la demande : 20 commentaires à l'ouverture puis 20 de plus à chaque « Voir plus » (plus d'écoute en direct de toute la liste).
/// [onChanged] : variation du nombre de commentaires et dernier commentaire, pour l'aperçu du lecteur.
Future<void> showChroniqueComments(BuildContext context, {required Chronique chronique, required void Function(int delta, String? pseudo, String? text) onChanged}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.of(context).surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _CommentsSheet(chronique: chronique, onChanged: onChanged),
  );
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.chronique, required this.onChanged});
  final Chronique chronique;
  final void Function(int delta, String? pseudo, String? text) onChanged;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _input = TextEditingController();
  final List<ChroniqueMessage> _items = [];
  DocumentSnapshot? _last;
  bool _loading = true;
  bool _hasMore = false;
  bool _sending = false;
  bool _error = false;
  late int _count = widget.chronique.commentCount;

  ChroniqueProvider get _provider => context.read<ChroniqueProvider>();
  UserAuthProvider get _auth => context.read<UserAuthProvider>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final page = await _provider.getMessagesPage(widget.chronique.id!, after: _last);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _last = page.last ?? _last;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  bool _canDelete(ChroniqueMessage m) {
    final me = _auth.loginUserData;
    return me.id == m.userId || me.id == widget.chronique.userId || me.role == 'ADM';
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final me = _auth.loginUserData;
    setState(() => _sending = true);
    try {
      await _provider.addMessage(chroniqueId: widget.chronique.id!, userId: me.id!, userPseudo: me.pseudo ?? '', userImageUrl: me.imageUrl ?? '', message: text);
      _input.clear();
      setState(() {
        _items.insert(0, ChroniqueMessage(chroniqueId: widget.chronique.id!, userId: me.id!, userPseudo: me.pseudo ?? '', userImageUrl: me.imageUrl ?? '', message: text, createdAt: Timestamp.now()));
        _count++;
      });
      widget.onChanged(1, me.pseudo, text);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Commentaire non envoyé. Réessayez.')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _like(ChroniqueMessage m) async {
    final me = _auth.loginUserData;
    if (m.id == null || m.likers.contains(me.id)) return;
    setState(() {
      m.likers = [...m.likers, me.id!];
      m.likeCount++;
    });
    try {
      await _provider.likeMessage(m.id!, me.id!);
      if (m.userId != me.id) await _notifyLike(m);
    } catch (_) {}
  }

  /// Prévient l'auteur du commentaire (une lecture de son profil pour retrouver son identifiant de notification).
  Future<void> _notifyLike(ChroniqueMessage m) async {
    final me = _auth.loginUserData;
    final doc = await FirebaseFirestore.instance.collection('Users').doc(m.userId).getM('chronique_comments_sheet.dart:123');
    final player = doc.data()?['oneIgnalUserid'];
    if (player == null) return;
    await _auth.sendNotification(
      appName: '@${me.pseudo}',
      userIds: [player],
      smallImage: me.imageUrl ?? '',
      send_user_id: me.id!,
      recever_user_id: m.userId,
      message: '🙏 a aimé votre commentaire',
      type_notif: 'COMMENT_LIKE',
      post_id: widget.chronique.id!,
      post_type: 'CHRONIQUE',
      chat_id: '',
    );
  }

  Future<void> _delete(ChroniqueMessage m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce commentaire ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true || m.id == null) return;
    try {
      await _provider.deleteMessage(widget.chronique.id!, m.id!);
      if (!mounted) return;
      setState(() {
        _items.remove(m);
        _count = (_count - 1).clamp(0, 1 << 30);
      });
      final next = _items.isEmpty ? null : _items.first;
      widget.onChanged(-1, next?.userPseudo, next?.message);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final me = context.read<UserAuthProvider>().loginUserData;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .72,
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 38, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
            child: Row(children: [
              Text(_count == 0 ? 'Commentaires' : '$_count commentaire${_count > 1 ? 's' : ''}', style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text('Visibles par tout le monde', style: TextStyle(color: c.textSecondary, fontSize: 11)),
            ]),
          ),
          Expanded(
            child: _loading && _items.isEmpty
                ? Center(child: CircularProgressIndicator(color: c.primary))
                : _error && _items.isEmpty
                    ? Center(child: TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Réessayer')))
                    : _items.isEmpty
                        ? Center(child: Text('Soyez le premier à commenter.', style: TextStyle(color: c.textSecondary)))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                            itemCount: _items.length + (_hasMore ? 1 : 0),
                            itemBuilder: (_, i) {
                              if (i == _items.length) {
                                return Center(
                                  child: TextButton(onPressed: _loading ? null : _load, child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Voir plus')),
                                );
                              }
                              return _row(c, _items[i], me.id);
                            },
                          ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  maxLength: ChroniqueProvider.maxCommentLength,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  style: TextStyle(color: c.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Écrire un commentaire public…',
                    hintStyle: TextStyle(color: c.textSecondary),
                    counterText: '',
                    filled: true,
                    fillColor: c.surfaceVariant,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _send,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [kRingGreen, kRingYellow])),
                  child: _sending ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF07120B))) : const Icon(Icons.send_rounded, color: Color(0xFF07120B), size: 19),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _row(AppColors c, ChroniqueMessage m, String? myId) {
    final isOwner = m.userId == widget.chronique.userId;
    final liked = m.likers.contains(myId);
    return GestureDetector(
      onLongPress: _canDelete(m) ? () => _delete(m) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ChroniqueAvatar(imageUrl: m.userImageUrl, name: m.userPseudo, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(m.userPseudo, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 12.5))),
                if (isOwner) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(5)),
                    child: const Text('CRÉATEUR', style: TextStyle(color: Color(0xFF2A1F00), fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: .6)),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              Text(m.message, style: TextStyle(color: c.textPrimary, fontSize: 13.5, height: 1.3)),
            ]),
          ),
          GestureDetector(
            onTap: () => _like(m),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(children: [
                Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 18, color: liked ? const Color(0xFFFF4D6A) : c.textSecondary),
                if (m.likeCount > 0) Text('${m.likeCount}', style: TextStyle(color: c.textSecondary, fontSize: 10, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
