import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/api/shop_api.dart';
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
  int _reload = 0;

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
      // Commentaire créé par l'API (compteur et notification au vendeur gérés par le serveur)
      await ShopApi.addComment(widget.articleId, text);
      _commentController.clear();
      if (mounted) setState(() => _reload++);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ShopApi.message(e, fallback: 'Erreur lors de l\'envoi')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
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
            child: FutureBuilder<List<ShopComment>>(
              key: ValueKey(_reload),
              future: ShopApi.comments(widget.articleId),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                        color: CustomConstants.kPrimaryColor),
                  );
                }
                if (snap.hasError) {
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(ShopApi.message(snap.error!), style: TextStyle(color: colors.textSecondary)),
                      TextButton(onPressed: () => setState(() => _reload++), child: Text('Réessayer')),
                    ]),
                  );
                }

                final docs = (snap.data ?? <ShopComment>[]).reversed.toList();
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
                    final pseudo = docs[i].pseudo;
                    final avatar = docs[i].avatar;
                    final text = docs[i].text;

                    return ListTile(
                      leading: CircleAvatar(onBackgroundImageError: (avatar.isNotEmpty
                            ? CachedNetworkImageProvider(avatar)
                            : null) != null ? (Object _, StackTrace? __) {} : null, 
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
                CircleAvatar(onBackgroundImageError: ((_auth.loginUserData.imageUrl?.isNotEmpty ==
                          true)
                      ? CachedNetworkImageProvider(
                          _auth.loginUserData.imageUrl!)
                      : null) != null ? (Object _, StackTrace? __) {} : null, 
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
