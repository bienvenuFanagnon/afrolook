import 'package:afrotok/services/read_meter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';
import '../../utils/media_cdn.dart';
import '../chat/myChat.dart';
import '../user/amis/pageMesInvitations.dart';
import 'chronique_widgets.dart';
import 'chroniqueform.dart';

/// Réponse privée à une chronique.
/// - Amis : le message part dans la discussion, avec la chronique citée en premier.
/// - Pas encore amis : demande de discussion temporaire, comme sur TikTok. Le message est visible tout de suite dans une discussion en attente ;
///   la suite n'est possible qu'après acceptation (le serveur applique les règles : une seule invitation en attente, 7 jours après un refus, 10 par jour).
Future<void> showChroniqueReply(BuildContext context, Chronique chronique) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.of(context).surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _ReplySheet(chronique: chronique),
  );
}

enum _Step { form, pending, incoming, sent }

class _ReplySheet extends StatefulWidget {
  const _ReplySheet({required this.chronique});
  final Chronique chronique;

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  static const int _max = 200;
  final TextEditingController _input = TextEditingController();
  late _Step _step;
  late bool _friends;
  bool _busy = false;
  String? _error;

  Chronique get c => widget.chronique;

  @override
  void initState() {
    super.initState();
    final me = context.read<UserAuthProvider>().loginUserData;
    _friends = me.friendsIds?.contains(c.userId) == true;
    _step = !_friends && me.mesInvitationsEnvoyerId?.contains(c.userId) == true ? _Step.pending : _Step.form;
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  String get _thumb {
    if ((c.posterUrl ?? '').isNotEmpty) return c.posterUrl!;
    if (c.type == ChroniqueType.IMAGE) return c.mediaUrl ?? '';
    return c.coverImageUrl ?? '';
  }

  Future<void> _send() async {
    final text = _input.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.isEmpty || text.length > _max || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_friends) {
        await _sendToFriend(text);
        return;
      }
      final r = (await FirebaseFunctions.instance.httpsCallable('chroniqueReplyInvite').call({'chroniqueId': c.id, 'message': text})).data as Map;
      if (!mounted) return;
      switch (r['status']) {
        case 'sent':
          context.read<UserAuthProvider>().loginUserData.mesInvitationsEnvoyerId?.add(c.userId);
          _chatId = r['chatId'] as String?;
          setState(() => _step = _Step.sent);
          break;
        case 'pending':
          setState(() => _step = _Step.pending);
          break;
        case 'incoming':
          setState(() => _step = _Step.incoming);
          break;
        case 'friends':
          _friends = true;
          await _sendToFriend(text);
          return;
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Envoi impossible. Réessayez.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Envoi impossible. Vérifiez votre connexion.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Déjà amis : trouve ou crée la discussion, y met la chronique citée puis le message, et l'ouvre.
  Future<void> _sendToFriend(String text) async {
    final fs = FirebaseFirestore.instance;
    final me = context.read<UserAuthProvider>().loginUserData;
    final myId = me.id!;
    final other = c.userId;
    final now = DateTime.now().millisecondsSinceEpoch;
    final found = await fs.collection('Chats').where('docId', whereIn: ['$other$myId', '$myId$other']).limit(1).getM('chronique_reply_sheet.dart:118');
    Chat chat;
    if (found.docs.isNotEmpty) {
      chat = Chat.fromJson(found.docs.first.data());
    } else {
      final id = fs.collection('Chats').doc().id;
      chat = Chat(docId: '$other$myId', id: id, senderId: myId, receiverId: other, lastMessage: text, type: ChatType.USER.name, createdAt: now, updatedAt: now);
      await fs.collection('Chats').doc(id).set(chat.toJson());
    }
    final chatDocId = chat.docId ?? chat.id; // les messages d'une discussion portent son « docId » (voir myChat._chatId)
    Map<String, dynamic> base(String id, int at) => {
          'id': id, 'send_by': myId, 'receiverBy': other, 'chat_id': chatDocId, 'is_valide': true, 'is_deleted': false, 'is_encrypted': false,
          'message_state': 'NONLU', 'create_at_time_spam': at, 'createdAt': FieldValue.serverTimestamp(), 'status': 'delivered',
          'reply_message': {'message': '', 'message_type': 'text', 'id': '', 'replyTo': '', 'replyBy': ''},
          'reaction': {'reactions': <String>[], 'reactedUserIds': <String>[]}, 'send_sending': false, 'receiver_sending': false,
        };
    final cardId = fs.collection('Messages').doc().id;
    final textId = fs.collection('Messages').doc().id;
    final batch = fs.batch();
    batch.set(fs.collection('Messages').doc(cardId), {
      ...base(cardId, now), 'message_type': 'link_share', 'message': 'Ma réponse à votre chronique', 'imageText': _thumb, 'item_id': c.id, 'item_type': 'chronique',
      'item_title': 'Chronique', 'item_subtitle': 'Réponse à votre chronique', 'item_thumbnail': _thumb,
    });
    batch.set(fs.collection('Messages').doc(textId), {...base(textId, now + 1), 'message_type': 'text', 'message': text});
    batch.update(fs.collection('Chats').doc(chat.id), {
      'last_message': text, 'updated_at': now, (chat.senderId == myId ? 'your_msg_not_read' : 'my_msg_not_read'): FieldValue.increment(2),
    });
    await batch.commit();
    Map<String, dynamic>? owner;
    try {
      owner = (await fs.collection('Users').doc(other).getM('chronique_reply_sheet.dart:148')).data();
      if (owner != null) chat.receiver = UserData.fromJson({...owner, 'id': other});
      final player = owner?['oneIgnalUserid'];
      if (player != null && mounted) {
        await context.read<UserAuthProvider>().sendNotification(
              appName: '@${me.pseudo}', userIds: [player], smallImage: me.imageUrl ?? '', send_user_id: myId, recever_user_id: other,
              message: '@${me.pseudo} répond à votre chronique : $text', type_notif: NotificationType.MESSAGE.name, post_id: '', post_type: '', chat_id: chat.id ?? '',
            );
      }
    } catch (_) {}
    if (!mounted) return;
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(MaterialPageRoute(builder: (_) => MyChat(title: 'Chat avec ${c.userPseudo}', chat: chat)));
  }

  /// Ouvre la discussion temporaire (par son identifiant, sinon en la cherchant) : le premier message y est visible, la suite attend l'acceptation.
  Future<void> _openPendingChat({String? chatId}) async {
    final fs = FirebaseFirestore.instance;
    final myId = context.read<UserAuthProvider>().loginUserData.id!;
    try {
      DocumentSnapshot<Map<String, dynamic>>? doc;
      if (chatId != null && chatId.isNotEmpty) {
        doc = await fs.collection('Chats').doc(chatId).getM('chronique_reply_sheet.dart:171');
      } else {
        final q = await fs.collection('Chats').where('docId', whereIn: ['${c.userId}$myId', '$myId${c.userId}']).limit(1).getM('chronique_reply_sheet.dart:173');
        if (q.docs.isNotEmpty) doc = q.docs.first;
      }
      if (doc == null || !doc.exists) return;
      final chat = Chat.fromJson(doc.data()!);
      final owner = (await fs.collection('Users').doc(c.userId).getM('chronique_reply_sheet.dart:178')).data();
      if (owner != null) chat.receiver = UserData.fromJson({...owner, 'id': c.userId});
      if (!mounted) return;
      final nav = Navigator.of(context);
      nav.pop();
      nav.push(MaterialPageRoute(builder: (_) => MyChat(title: 'Chat avec ${c.userPseudo}', chat: chat)));
    } catch (_) {
      if (mounted) setState(() => _error = 'Discussion introuvable pour le moment.');
    }
  }

  String? _chatId;

  Widget _openChatButton(AppColors colors) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _openPendingChat(chatId: _chatId),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
            label: const Text('Voir la discussion', style: TextStyle(fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(foregroundColor: colors.textPrimary, side: BorderSide(color: colors.border), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final left = _max - _input.text.length;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 38, height: 4, decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Text('Répondre en privé à @${c.userPseudo}', style: TextStyle(color: colors.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _quoted(colors),
            const SizedBox(height: 12),
            if (_step == _Step.form) ..._form(colors, left),
            if (_step == _Step.pending) ...[
              _state(colors, Icons.hourglass_top_rounded, 'En attente de sa réponse', 'Votre message est visible dans la discussion. Vous pourrez continuer dès que @${c.userPseudo} aura accepté.'),
              _openChatButton(colors),
            ],
            if (_step == _Step.sent) ...[
              _state(colors, Icons.check_circle_rounded, 'Message envoyé', '@${c.userPseudo} le voit dans ses demandes et choisit d\'accepter ou non. Vous serez prévenu.'),
              _openChatButton(colors),
            ],
            if (_step == _Step.incoming) ...[
              _state(colors, Icons.mail_rounded, '@${c.userPseudo} vous a déjà invité', 'Acceptez son invitation pour ouvrir la discussion.'),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (ctx) => MesInvitationsPage(context: ctx)));
                  },
                  style: FilledButton.styleFrom(backgroundColor: colors.primary, foregroundColor: colors.onPrimary, padding: const EdgeInsets.symmetric(vertical: 13)),
                  child: const Text('Voir mes invitations', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _quoted(AppColors colors) {
    final thumb = _thumb;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 44,
            height: 56,
            child: thumb.isEmpty
                ? ChroniquePreviewFill(chronique: c, textSize: 7, maxTextLines: 4)
                : CachedNetworkImage(imageUrl: MediaCdn.url(thumb), fit: BoxFit.cover, memCacheWidth: 140, errorWidget: (_, __, ___) => const SizedBox.shrink()),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Sa chronique du moment', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
            Text('${chroniqueTypeLabel(c.type)[0]}${chroniqueTypeLabel(c.type).substring(1).toLowerCase()}', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }

  List<Widget> _form(AppColors colors, int left) => [
        if (!_friends)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: colors.accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(14), border: Border.all(color: colors.accent.withValues(alpha: .5))),
            child: Text.rich(TextSpan(style: TextStyle(color: colors.textPrimary, fontSize: 12.5, height: 1.35), children: [
              const TextSpan(text: 'Vous n\'êtes pas encore amis. ', style: TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(text: 'Votre message arrive comme une demande de discussion : @${c.userPseudo} le lit puis accepte ou refuse. Tant qu\'il n\'a pas accepté, vous ne pouvez pas lui écrire d\'autres messages.'),
            ])),
          ),
        if (!_friends) const SizedBox(height: 12),
        TextField(
          controller: _input,
          autofocus: true,
          maxLength: _max,
          minLines: 3,
          maxLines: 5,
          style: TextStyle(color: colors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: _friends ? 'Votre message…' : 'Présentez-vous et dites pourquoi vous écrivez…',
            hintStyle: TextStyle(color: colors.textSecondary),
            counterText: '$left',
            counterStyle: TextStyle(color: left < 20 ? Colors.orange : colors.textSecondary, fontSize: 11),
            filled: true,
            fillColor: colors.surfaceVariant,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12.5))),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _busy || _input.text.trim().isEmpty ? null : _send,
            style: FilledButton.styleFrom(backgroundColor: colors.primary, foregroundColor: colors.onPrimary, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: _busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2))
                : Text(_friends ? 'Envoyer' : 'Envoyer ma demande', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
      ];

  Widget _state(AppColors colors, IconData icon, String title, String text) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: colors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 3),
              Text(text, style: TextStyle(color: colors.textSecondary, fontSize: 12.5, height: 1.35)),
            ]),
          ),
        ]),
      );
}
