import 'dart:async';
import 'dart:math';

import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:afrotok/pages/postDetails.dart';
import 'package:afrotok/pages/userPosts/postWidgets/postMenu.dart';
import 'package:afrotok/pages/userPosts/hashtag/textHashTag/views/view_models/home_view_model.dart';
import 'package:afrotok/pages/userPosts/hashtag/textHashTag/views/view_models/search_view_model.dart';
import 'package:afrotok/pages/userPosts/hashtag/textHashTag/views/widgets/comment_text_field.dart';
import 'package:afrotok/pages/userPosts/hashtag/textHashTag/views/widgets/search_result_overlay.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:comment_tree/widgets/comment_tree_widget.dart';
import 'package:comment_tree/widgets/tree_theme_data.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flash/flash.dart';
import 'package:flash/flash_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:afrotok/constant/constColors.dart';
import 'package:afrotok/constant/iconGradient.dart';
import 'package:afrotok/constant/logo.dart';
import 'package:afrotok/constant/sizeText.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/userProvider.dart';
import 'package:afrotok/services/api.dart';
import 'package:flutter/material.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter/services.dart';
import 'package:flutter_list_view/flutter_list_view.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:fluttertagger/fluttertagger.dart';
import 'package:hashtagable_v3/widgets/hashtag_text.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:popover_gtk/popover_gtk.dart';
import 'package:popup_menu_plus/popup_menu_plus.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:stories_for_flutter/stories_for_flutter.dart';
import '../../constant/listItemsCarousel.dart';
import '../../constant/textCustom.dart';
import '../../models/chatmodels/message.dart';
import '../../providers/authProvider.dart';


// Couleurs AfroLook
const _afroGreen = Color(0xFF2ECC71);
const _afroDarkGreen = Color(0xFF27AE60);
const _afroYellow = Color(0xFFF1C40F);
const _afroBlack = Color(0xFF2C3E50);
const _afroLightBg = Color(0xFFECF0F1);
const _afroRed = Color(0xFFE74C3C);

class PostComments extends StatefulWidget {
  final Post post;
  const PostComments({super.key, required this.post});

  @override
  State<PostComments> createState() => _PostCommentsState();
}

class _PostCommentsState extends State<PostComments> {
  late UserAuthProvider authProvider;
  late UserProvider userProvider;
  late PostProvider postProvider;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  PostComment commentSelectedToReply = PostComment();
  UserData commentRecever = UserData();
  bool replying = false;
  String replyingTo = '';
  String replyUser_pseudo = '';
  String replyUser_id = '';
  bool _isLoading = false;
  bool sendMessageTap = false;

  TextEditingController _textController = TextEditingController();
  FocusNode _focusNode = FocusNode();
  List<UserData> users = [];
  List<PostComment> comments = [];
  List<UserData> suggestedUsers = [];
  bool showUserSuggestions = false;
  String currentSearchQuery = '';

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);

    _loadUsers();
    _loadComments();

    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _textController.text;
    final lastAtPos = text.lastIndexOf('@');

    if (lastAtPos != -1) {
      final query = text.substring(lastAtPos + 1).split(' ')[0];
      if (query.isNotEmpty) {
        setState(() {
          currentSearchQuery = query;
          showUserSuggestions = true;
          _filterUsers(query);
        });
      } else {
        setState(() {
          showUserSuggestions = false;
        });
      }
    } else {
      setState(() {
        showUserSuggestions = false;
      });
    }
  }

  void _filterUsers(String query) {
    setState(() {
      suggestedUsers = users.where((user) {
        return user.pseudo!.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  void _selectUser(UserData user) {
    final text = _textController.text;
    final lastAtPos = text.lastIndexOf('@');

    if (lastAtPos != -1) {
      final newText = text.substring(0, lastAtPos) + '@${user.pseudo!} ';
      _textController.text = newText;
      _textController.selection = TextSelection.fromPosition(
        TextPosition(offset: newText.length),
      );
    }

    setState(() {
      showUserSuggestions = false;
    });
  }

  Future<void> _loadUsers() async {
    final usersList = await userProvider.getAllUsers();
    setState(() {
      users = usersList;
    });
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final commentsList = await postProvider.getPostCommentsNoStream(widget.post);
      setState(() {
        comments = commentsList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Erreur chargement commentaires: $e');
    }
  }

  String formatNumber(int number) {
    if (number < 1000) return number.toString();
    if (number < 1000000) return "${(number / 1000).toStringAsFixed(1)} k";
    if (number < 1000000000) return "${(number / 1000000).toStringAsFixed(1)} m";
    return "${(number / 1000000000).toStringAsFixed(1)} b";
  }

  String formaterDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays < 1) {
      if (difference.inHours < 1) {
        if (difference.inMinutes < 1) return "à l'instant";
        return "il y a ${difference.inMinutes} min";
      } else {
        return "il y a ${difference.inHours} h";
      }
    } else if (difference.inDays < 7) {
      return "il y a ${difference.inDays} j";
    } else {
      return DateFormat('dd MMM yyyy').format(dateTime);
    }
  }

  void _showCommentMenuModalDialog(PostComment postComment) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            'Options',
            style: TextStyle(color: _afroBlack, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (postComment.user!.id == authProvider.loginUserData.id ||
                  authProvider.loginUserData.role == UserRole.ADM.name)
                ListTile(
                  onTap: () async {
                    Navigator.pop(context);
                    await _deleteComment(postComment);
                  },
                  leading: Icon(Icons.delete, color: _afroRed),
                  title: Text(
                    'Supprimer',
                    style: TextStyle(color: _afroBlack),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showResponseMenuModalDialog(PostComment parentComment, ResponsePostComment response) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: Text(
            'Options',
            style: TextStyle(color: _afroBlack, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (response.user_id == authProvider.loginUserData.id ||
                  authProvider.loginUserData.role == UserRole.ADM.name)
                ListTile(
                  onTap: () async {
                    Navigator.pop(context);
                    await _deleteResponse(parentComment, response);
                  },
                  leading: Icon(Icons.delete, color: _afroRed),
                  title: Text(
                    'Supprimer',
                    style: TextStyle(color: _afroBlack),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteComment(PostComment comment) async {
    setState(() => _isLoading = true);

    comment.status = PostStatus.SUPPRIMER.name;
    bool success = await postProvider.updateComment(comment);

    setState(() => _isLoading = false);

    if (success) {
      await _loadComments(); // Recharger seulement après suppression
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Commentaire supprimé'),
          backgroundColor: _afroGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression'),
          backgroundColor: _afroRed,
        ),
      );
    }
  }

  Future<void> _deleteResponse(PostComment parentComment, ResponsePostComment response) async {
    setState(() => _isLoading = true);

    response.status = PostStatus.SUPPRIMER.name;
    bool success = await postProvider.updateComment(parentComment);

    setState(() => _isLoading = false);

    if (success) {
      await _loadComments(); // Recharger seulement après suppression
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Réponse supprimée'),
          backgroundColor: _afroGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression'),
          backgroundColor: _afroRed,
        ),
      );
    }
  }

  Widget _buildUserHeader() {
    final post = widget.post;
    final isCanal = post.canal != null;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _afroBlack.withOpacity(0.1),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _afroYellow, width: 2),
                ),
                child: CircleAvatar(
                  radius: 25,
                  backgroundColor: _afroGreen,
                  backgroundImage: NetworkImage(
                    isCanal ? post.canal!.urlImage! : post.user!.imageUrl!,
                  ),
                  child: (isCanal ? post.canal!.urlImage : post.user!.imageUrl) == null
                      ? Icon(Icons.person, color: Colors.white)
                      : null,
                ),
              ),
              if ((isCanal ? post.canal!.isVerify : post.user!.isVerify) ?? false)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.verified,
                      color: _afroYellow,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCanal ? "#${post.canal!.titre!}" : "@${post.user!.pseudo!}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _afroBlack,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  isCanal
                      ? "${formatNumber(post.canal!.usersSuiviId?.length ?? 0)} abonnés"
                      : "${formatNumber(post.user!.userAbonnesIds?.length ?? 0)} abonnés",
                  style: TextStyle(
                    color: _afroBlack.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostContent() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: _afroLightBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: HashTagText(
        text: widget.post.description ?? "",
        decoratedStyle: TextStyle(
          fontSize: 15,
          color: _afroDarkGreen,
          fontWeight: FontWeight.w600,
        ),
        basicStyle: TextStyle(
          fontSize: 14,
          color: _afroBlack,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildCommentContent(PostComment pcm) {
    return Container(
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _afroBlack.withOpacity(0.05),
            blurRadius: 2,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              double w= MediaQuery.of(context).size.width;
              double h= MediaQuery.of(context).size.height;
              showUserDetailsModalDialog(pcm.user!!, w, h, context);
              },
            child: Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundImage: NetworkImage(pcm.user!.imageUrl ?? ''),
                  backgroundColor: _afroGreen,
                  child: pcm.user!.imageUrl == null
                      ? Icon(Icons.person, size: 14, color: Colors.white)
                      : null,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        "@${pcm.user!.pseudo!}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _afroBlack,
                        ),
                      ),
                      SizedBox(width: 4),
                      if (pcm.user!.isVerify ?? false)
                        Icon(Icons.verified, size: 14, color: _afroYellow),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          commentSelectedToReply = pcm;
                          commentRecever = pcm.user!;
                          replyUser_id = pcm.user!.id!;
                          replyUser_pseudo = pcm.user!.pseudo!;
                          replyingTo = "@${pcm.user!.pseudo}";
                          replying = true;
                        });
                        _focusNode.requestFocus();
                      },
                      icon: Icon(Icons.reply, size: 16, color: _afroGreen),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                    IconButton(
                      onPressed: () => _showCommentMenuModalDialog(pcm),
                      icon: Icon(Icons.more_vert, size: 16, color: _afroBlack),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 6),
          HashTagText(

            text: pcm.status == PostStatus.SUPPRIMER.name
                ? "Commentaire supprimé"
                : pcm.message!,
            decoratedStyle: TextStyle(
              fontSize: 12,
              color: _afroDarkGreen,
              fontWeight: FontWeight.w600,
            ),
            basicStyle: TextStyle(
              fontSize: 13,
              color: pcm.status == PostStatus.SUPPRIMER.name
                  ? _afroRed
                  : _afroBlack,
            ),
          ),
          SizedBox(height: 4),
          Text(
            formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(pcm.createdAt!)),
            style: TextStyle(
              fontSize: 10,
              color: _afroBlack.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyContent(PostComment pcm, ResponsePostComment rpc) {
    return Container(
      padding: EdgeInsets.all(10),
      margin: EdgeInsets.only(left: 20, bottom: 6),
      decoration: BoxDecoration(
        color: _afroLightBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              if(rpc.user!=null){
                double w= MediaQuery.of(context).size.width;
                double h= MediaQuery.of(context).size.height;
                showUserDetailsModalDialog(rpc.user!, w, h, context);
              }
            },
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundImage: NetworkImage(rpc.user_logo_url ?? ''),
                  backgroundColor: _afroGreen,
                ),
                SizedBox(width: 6),
                Text(
                  "@${rpc.user_pseudo}",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: _afroBlack,
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  "→ @${rpc.user_reply_pseudo ?? ''}",
                  style: TextStyle(
                    fontSize: 11,
                    color: _afroBlack.withOpacity(0.6),
                  ),
                ),
                Spacer(),
                Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() {
                          commentSelectedToReply = pcm;
                          commentRecever = pcm.user!;
                          replyUser_id = rpc.user_id!;
                          replyUser_pseudo = rpc.user_pseudo!;
                          replyingTo = "@${rpc.user_pseudo}";
                          replying = true;
                        });
                        _focusNode.requestFocus();
                      },
                      icon: Icon(Icons.reply, size: 14, color: _afroGreen),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                    IconButton(
                      onPressed: () => _showResponseMenuModalDialog(pcm, rpc),
                      icon: Icon(Icons.more_vert, size: 14, color: _afroBlack),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 4),
          HashTagText(
            text: rpc.status == PostStatus.SUPPRIMER.name
                ? "Réponse supprimée"
                : rpc.message!,
            decoratedStyle: TextStyle(
              fontSize: 11,
              color: _afroDarkGreen,
              fontWeight: FontWeight.w600,
            ),
            basicStyle: TextStyle(
              fontSize: 12,
              color: rpc.status == PostStatus.SUPPRIMER.name
                  ? _afroRed
                  : _afroBlack,
            ),
          ),
          SizedBox(height: 4),
          Text(
            formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(rpc.createdAt!)),
            style: TextStyle(
              fontSize: 9,
              color: _afroBlack.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList() {
    if (_isLoading) {
      return Center(
        child: LoadingAnimationWidget.fourRotatingDots(
          color: _afroGreen,
          size: 40,
        ),
      );
    }

    if (comments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.comment_outlined, color: _afroBlack.withOpacity(0.3), size: 50),
            SizedBox(height: 12),
            Text(
              'Soyez le premier à commenter',
              style: TextStyle(
                color: _afroBlack.withOpacity(0.5),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: comments.length,
      itemBuilder: (context, index) {
        final comment = comments[index];
        return Column(
          children: [
            _buildCommentContent(comment),
            if (comment.responseComments != null && comment.responseComments!.isNotEmpty)
              ...comment.responseComments!.map((reply) =>
                  _buildReplyContent(comment, reply)
              ).toList(),
            Divider(height: 20, color: _afroLightBg),
          ],
        );
      },
    );
  }

  Widget _buildUserSuggestions() {
    if (!showUserSuggestions || suggestedUsers.isEmpty) {
      return SizedBox();
    }

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: _afroBlack.withOpacity(0.1),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: suggestedUsers.take(5).map((user) => ListTile(
          leading: CircleAvatar(
            radius: 16,
            backgroundImage: NetworkImage(user.imageUrl ?? ''),
            backgroundColor: _afroGreen,
          ),
          title: Text("@${user.pseudo!}", style: TextStyle(fontSize: 14)),
          onTap: () => _selectUser(user),
        )).toList(),
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _afroLightBg)),
      ),
      child: Column(
        children: [
          if (replying)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: _afroYellow.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.reply, color: _afroGreen, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Réponse à $replyingTo",
                      style: TextStyle(
                        color: _afroBlack,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 16, color: _afroRed),
                    onPressed: () {
                      setState(() {
                        replying = false;
                        replyingTo = "";
                      });
                    },
                  ),
                ],
              ),
            ),
          _buildUserSuggestions(),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _afroLightBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    decoration: InputDecoration(
                      hintText: replying ? 'Répondre...' : 'Ajouter un commentaire...',
                      hintStyle: TextStyle(color: _afroBlack.withOpacity(0.5)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      suffixIcon: _textController.text.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.send, color: _afroGreen),
                        onPressed: _sendComment,
                      )
                          : null,
                    ),
                    onSubmitted: (value) => _sendComment(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _sendComment() async {
    if (_textController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    final textComment = _textController.text.trim();
    _textController.clear();
    _focusNode.unfocus();

    try {
      bool success = false;

      if (replying) {
        // Envoyer une réponse
        final response = ResponsePostComment(
          user_id: authProvider.loginUserData.id,
          user_logo_url: authProvider.loginUserData.imageUrl,
          user_pseudo: authProvider.loginUserData.pseudo,
          post_comment_id: commentSelectedToReply.id,
          user_reply_pseudo: replyingTo,
          message: textComment,
          createdAt: DateTime.now().microsecondsSinceEpoch,
          updatedAt: DateTime.now().microsecondsSinceEpoch,
        );

        commentSelectedToReply.responseComments ??= [];
        commentSelectedToReply.responseComments!.add(response);

        success = await postProvider.updateComment(commentSelectedToReply);

        if (success) {
          widget.post.comments = (widget.post.comments ?? 0) + 1;
          await _sendNotification(replyUser_id, "répondu à votre commentaire", textComment);
        }
      } else {
        // Envoyer un nouveau commentaire
        final comment = PostComment(
          user_id: authProvider.loginUserData.id,
          user: authProvider.loginUserData,
          post_id: widget.post.id,
          users_like_id: [],
          responseComments: [],
          message: textComment,
          loves: 0,
          likes: 0,
          comments: 0,
          createdAt: DateTime.now().microsecondsSinceEpoch,
          updatedAt: DateTime.now().microsecondsSinceEpoch,
        );

        success = await postProvider.newComment(comment);

        if (success) {
          widget.post.comments = (widget.post.comments ?? 0) + 1;
          await _sendNotification(widget.post.user!.id!, "commenté votre look", textComment);
        }
      }

      // Réinitialiser l'état de réponse
      setState(() {
        replying = false;
        replyingTo = "";
      });

      // Recharger les commentaires seulement après succès
      if (success) {
        await _loadComments();
      }

    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: _afroRed,
        ),
      );
    }
  }

  Future<void> _sendNotification(String receiverId, String action, String message) async {
    try {
      // Notification au propriétaire du commentaire/post
      final receiver = await authProvider.getUserById(receiverId);
      if (receiver.isNotEmpty) {
        final notif = NotificationData(
          id: firestore.collection('Notifications').doc().id,
          titre: "Nouvelle interaction",
          media_url: authProvider.loginUserData.imageUrl,
          type: NotificationType.POST.name,
          description: "@${authProvider.loginUserData.pseudo!} a $action",
          user_id: authProvider.loginUserData.id,
          receiver_id: receiverId,
          post_id: widget.post.id!,
          post_data_type: PostDataType.COMMENT.name!,
          createdAt: DateTime.now().microsecondsSinceEpoch,
          updatedAt: DateTime.now().microsecondsSinceEpoch,
          status: PostStatus.VALIDE.name,
        );

        await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());

        await authProvider.sendNotification(
            userIds: [receiver.first.oneIgnalUserid!],
            smallImage: authProvider.loginUserData.imageUrl!,
            send_user_id: authProvider.loginUserData.id!,
            recever_user_id: receiverId,
            message: "@${authProvider.loginUserData.pseudo!} a $action",
            type_notif: NotificationType.POST.name,
            post_id: widget.post.id!,
            post_type: PostDataType.COMMENT.name,
            chat_id: ''
        );
      }

      // Notifications pour les utilisateurs tagués
      final mentionedUsers = _extractMentionedUsers(message);
      for (final username in mentionedUsers) {
        final user = users.firstWhere((u) => u.pseudo == username, orElse: () => UserData());
        if (user.id != null && user.id != receiverId) {
          final mentionNotif = NotificationData(
            id: firestore.collection('Notifications').doc().id,
            titre: "Vous avez été mentionné",
            media_url: authProvider.loginUserData.imageUrl,
            type: NotificationType.MESSAGE.name,
            description: "@${authProvider.loginUserData.pseudo!} vous a mentionné dans un commentaire",
            user_id: authProvider.loginUserData.id,
            receiver_id: user.id!,
            post_id: widget.post.id!,
            post_data_type: PostDataType.COMMENT.name!,
            createdAt: DateTime.now().microsecondsSinceEpoch,
            updatedAt: DateTime.now().microsecondsSinceEpoch,
            status: PostStatus.VALIDE.name,
          );

          await firestore.collection('Notifications').doc(mentionNotif.id).set(mentionNotif.toJson());

          await authProvider.sendNotification(
              userIds: [user.oneIgnalUserid!],
              smallImage: authProvider.loginUserData.imageUrl!,
              send_user_id: authProvider.loginUserData.id!,
              recever_user_id: user.id!,
              message: "@${authProvider.loginUserData.pseudo!} vous a mentionné dans un commentaire",
              type_notif: NotificationType.MESSAGE.name,
              post_id: widget.post.id!,
              post_type: PostDataType.COMMENT.name,
              chat_id: ''
          );
        }
      }

    } catch (e) {
      print('Erreur envoi notification: $e');
    }
  }

  List<String> _extractMentionedUsers(String message) {
    final RegExp mentionRegex = RegExp(r'@(\w+)');
    final matches = mentionRegex.allMatches(message);
    return matches.map((match) => match.group(1)!).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _afroBlack),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Commentaires',
          style: TextStyle(
            color: _afroBlack,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildUserHeader(),
                  SizedBox(height: 12),
                  _buildPostContent(),
                  SizedBox(height: 16),
                  Text(
                    'Commentaires (${widget.post.comments ?? 0})',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: _afroBlack,
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildCommentsList(),
                ],
              ),
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }
}
