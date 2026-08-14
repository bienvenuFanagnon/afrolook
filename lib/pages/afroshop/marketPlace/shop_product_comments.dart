import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../constant/custom_theme.dart';
import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../theme/app_colors.dart';

class ShopProductComments extends StatefulWidget {
  final String articleId;

  const ShopProductComments({Key? key, required this.articleId})
      : super(key: key);

  @override
  State<ShopProductComments> createState() => _ShopProductCommentsState();
}

class _ShopProductCommentsState extends State<ShopProductComments> {
  final TextEditingController _commentController = TextEditingController();
  bool _sending = false;

  late UserAuthProvider _auth;

  @override
  void initState() {
    super.initState();
    _auth = Provider.of<UserAuthProvider>(context, listen: false);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final me = _auth.loginUserData;
      final commentId =
          FirebaseFirestore.instance.collection('ArticleComments').doc().id;

      await FirebaseFirestore.instance
          .collection('ArticleComments')
          .doc(commentId)
          .set({
        'id': commentId,
        'article_id': widget.articleId,
        'user_id': me.id,
        'pseudo': me.pseudo ?? '',
        'avatar_url': me.imageUrl ?? '',
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
      });

      // Incrémenter le compteur dénormalisé
      await FirebaseFirestore.instance
          .collection('Articles')
          .doc(widget.articleId)
          .update({'commentaires': FieldValue.increment(1)});

      _commentController.clear();

      // Notification au propriétaire du produit
      _notifyProductOwner(me, text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'envoi'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _notifyProductOwner(UserData me, String commentText) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Articles')
          .doc(widget.articleId)
          .get();
      if (!snap.exists) return;

      final data = snap.data()!;
      final userMap = data['user'] as Map<String, dynamic>?;
      final ownerId = userMap?['id'] as String? ?? data['user_id'] as String?;
      final ownerOneSignalId =
          userMap?['oneIgnalUserid'] as String? ?? userMap?['oneSignalUserId'] as String?;
      final images = (data['images'] as List?)?.cast<String>() ?? [];
      final thumbnail = images.isNotEmpty ? images.first : '';

      // Pas de notif si c'est le proprio lui-même qui commente
      if (ownerId == null || ownerId == me.id) return;

      final pseudo = me.pseudo ?? 'Quelqu\'un';
      final message = '\u{1F4AC} @$pseudo a commenté votre produit';

      // Push OneSignal
      if (ownerOneSignalId != null && ownerOneSignalId.isNotEmpty) {
        await _auth.sendNotification(
          userIds: [ownerOneSignalId],
          smallImage: thumbnail,
          send_user_id: me.id ?? '',
          recever_user_id: ownerId,
          message: message,
          type_notif: NotificationType.ARTICLE.name,
          post_id: widget.articleId,
          post_type: PostDataType.IMAGE.name,
          chat_id: '',
        );
      }

      // Enregistrement Firestore
      final notifId =
          FirebaseFirestore.instance.collection('Notifications').doc().id;
      final notif = NotificationData();
      notif.id = notifId;
      notif.titre = '\u{1F6D2} Boutique';
      notif.media_url = thumbnail;
      notif.type = NotificationType.ARTICLE.name;
      notif.description = message;
      notif.users_id_view = [];
      notif.user_id = me.id;
      notif.receiver_id = ownerId;
      notif.post_id = widget.articleId;
      notif.post_data_type = PostDataType.IMAGE.name!;
      notif.updatedAt = DateTime.now().microsecondsSinceEpoch;
      notif.createdAt = DateTime.now().microsecondsSinceEpoch;
      notif.status = PostStatus.VALIDE.name;

      await FirebaseFirestore.instance
          .collection('Notifications')
          .doc(notifId)
          .set(notif.toJson());
    } catch (_) {
      // Erreur silencieuse — le commentaire est déjà sauvegardé
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Poignée
          Container(
            margin: EdgeInsets.symmetric(vertical: 10),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Titre
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.comment_rounded,
                    color: CustomConstants.kPrimaryColor, size: 20),
                SizedBox(width: 8),
                Text(
                  'Commentaires',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: colors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.border),

          // Liste des commentaires
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('ArticleComments')
                  .where('article_id', isEqualTo: widget.articleId)
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                        color: CustomConstants.kPrimaryColor),
                  );
                }

                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 48, color: colors.textSecondary),
                        SizedBox(height: 8),
                        Text(
                          'Soyez le premier à commenter',
                          style: TextStyle(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, indent: 60, color: colors.border),
                  itemBuilder: (_, i) {
                    final data =
                        docs[i].data() as Map<String, dynamic>;
                    final pseudo = data['pseudo'] as String? ?? '';
                    final avatar = data['avatar_url'] as String? ?? '';
                    final text = data['text'] as String? ?? '';

                    return ListTile(
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: colors.shimmerBase,
                        backgroundImage: avatar.isNotEmpty
                            ? CachedNetworkImageProvider(avatar)
                            : null,
                        child: avatar.isEmpty
                            ? Icon(Icons.person,
                                color: colors.textSecondary, size: 18)
                            : null,
                      ),
                      title: Text(
                        '@$pseudo',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: colors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        text,
                        style: TextStyle(
                          fontSize: 13,
                          color: colors.textSecondary,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Champ de saisie
          Padding(
            padding: EdgeInsets.only(
                left: 12, right: 12, top: 8, bottom: bottomPadding + 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: colors.shimmerBase,
                  backgroundImage: (_auth.loginUserData.imageUrl?.isNotEmpty ==
                          true)
                      ? CachedNetworkImageProvider(
                          _auth.loginUserData.imageUrl!)
                      : null,
                  child: (_auth.loginUserData.imageUrl?.isEmpty != false)
                      ? Icon(Icons.person, color: colors.textSecondary, size: 18)
                      : null,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Ajouter un commentaire…',
                      hintStyle: TextStyle(color: colors.textSecondary),
                      filled: true,
                      fillColor: colors.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: colors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(
                            color: CustomConstants.kPrimaryColor),
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                _sending
                    ? SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: CustomConstants.kPrimaryColor),
                      )
                    : IconButton(
                        onPressed: _sendComment,
                        icon: Icon(Icons.send_rounded,
                            color: CustomConstants.kPrimaryColor),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
