import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:afrotok/pages/postDetails.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/authProvider.dart';
import '../providers/userProvider.dart';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:afrotok/pages/postDetails.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/authProvider.dart';
import '../providers/userProvider.dart';
import '../services/postService/feed_interaction_service.dart';

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
  bool replying = false;
  String replyingTo = '';
  String replyUser_pseudo = '';
  String replyUser_id = '';
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreComments = true;

  // Pagination des commentaires
  DocumentSnapshot? _lastCommentDocument;
  final int _commentsPageSize = 6;

  // États pour gérer l'expansion des commentaires et réponses
  final Map<String, bool> _commentExpanded = {};
  final Map<String, bool> _replyExpanded = {};
  final Map<String, bool> _showAllReplies = {};

  TextEditingController _textController = TextEditingController();
  FocusNode _focusNode = FocusNode();
  List<UserData> users = [];
  List<PostComment> comments = [];
  List<UserData> suggestedUsers = [];
  bool showUserSuggestions = false;
  String currentSearchQuery = '';

  // Pagination pour les suggestions d'utilisateurs
  int _userSuggestionsPage = 0;
  final int _userSuggestionsPageSize = 10;
  bool _hasMoreUsers = true;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);

    _loadUsers();
    _loadInitialComments();

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
          _userSuggestionsPage = 0;
          _hasMoreUsers = true;
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
    final filtered = users.where((user) {
      return user.pseudo!.toLowerCase().contains(query.toLowerCase());
    }).toList();

    setState(() {
      suggestedUsers = filtered.take((_userSuggestionsPage + 1) * _userSuggestionsPageSize).toList();
      _hasMoreUsers = filtered.length > suggestedUsers.length;
    });
  }

  void _loadMoreUserSuggestions() {
    if (_hasMoreUsers) {
      setState(() {
        _userSuggestionsPage++;
        _filterUsers(currentSearchQuery);
      });
    }
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
    final usersList = await userProvider.getUserAbonnes(authProvider.loginUserData.id!);
    setState(() {
      users = usersList;
    });
  }


  Future<void> _loadInitialComments() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      // Ne pas vider les commentaires existants pour garder l'UI responsive
      if (comments.isEmpty) {
        comments.clear();
      }
      _lastCommentDocument = null;
      _hasMoreComments = true;
    });

    try {
      await _loadCommentsBatch();
    } catch (e) {
      setState(() => _isLoading = false);
      print('Erreur chargement commentaires: $e');
    }
  }
  Future<void> _loadMoreComments() async {
    if (_isLoadingMore || !_hasMoreComments) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      await _loadCommentsBatch();
    } catch (e) {
      print('Erreur chargement plus de commentaires: $e');
    } finally {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadCommentsBatch() async {
    Query query = FirebaseFirestore.instance
        .collection('PostComments')
        .where("post_id", isEqualTo: widget.post.id)
        .orderBy('created_at', descending: true)
        .limit(_commentsPageSize);

    if (_lastCommentDocument != null) {
      query = query.startAfterDocument(_lastCommentDocument!);
    }

    final querySnapshot = await query.get();

    if (querySnapshot.docs.isEmpty) {
      setState(() {
        _hasMoreComments = false;
        _isLoading = false;
      });
      return;
    }

    _lastCommentDocument = querySnapshot.docs.last;

    List<PostComment> newComments = querySnapshot.docs.map((doc) =>
        PostComment.fromJson(doc.data() as Map<String, dynamic>)).toList();

    // Charger les données utilisateur pour les nouveaux commentaires
    for (var comment in newComments) {
      final userData = await _loadUserData(comment.user_id!);
      comment.user = userData;
    }

    setState(() {
      comments.addAll(newComments);
      _isLoading = false;
    });
  }

  Future<UserData?> _loadUserData(String userId) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where("id", isEqualTo: userId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return UserData.fromJson(querySnapshot.docs.first.data() as Map<String, dynamic>);
      }
    } catch (e) {
      print('Erreur chargement user $userId: $e');
    }
    return null;
  }

  String formatNumber(int number) {
    if (number < 1000) return number.toString();
    if (number < 1000000) return "${(number / 1000).toStringAsFixed(1)}k";
    return "${(number / 1000000).toStringAsFixed(1)}m";
  }

  String formaterDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays < 1) {
      if (difference.inHours < 1) {
        if (difference.inMinutes < 1) return "maintenant";
        return "${difference.inMinutes}m";
      } else {
        return "${difference.inHours}h";
      }
    } else if (difference.inDays < 7) {
      return "${difference.inDays}j";
    } else {
      return DateFormat('dd/MM/yy').format(dateTime);
    }
  }

  // Fonction pour liker un commentaire
  Future<void> _likeComment(PostComment comment) async {
    try {
      final userId = authProvider.loginUserData.id!;
      final isLiked = comment.users_like_id?.contains(userId) ?? false;

      if (isLiked) {
        comment.users_like_id?.remove(userId);
        comment.likes = (comment.likes ?? 1) - 1;
      } else {
        comment.users_like_id?.add(userId);
        comment.likes = (comment.likes ?? 0) + 1;

        // Envoyer notification au propriétaire du commentaire
        if (comment.user!.id != userId) {
          await _sendLikeNotification(comment.user!.id!, comment);
        }
      }

      await postProvider.updateComment(comment);
      setState(() {});

    } catch (e) {
      print('Erreur like commentaire: $e');
    }
  }

  // Fonction pour liker une réponse
  Future<void> _likeReply(PostComment parentComment, ResponsePostComment reply) async {
    try {
      final userId = authProvider.loginUserData.id!;
      final isLiked = reply.users_like_id?.contains(userId) ?? false;

      if (isLiked) {
        reply.users_like_id?.remove(userId);
        reply.likes = (reply.likes ?? 1) - 1;
      } else {
        reply.users_like_id?.add(userId);
        reply.likes = (reply.likes ?? 0) + 1;

        // Envoyer notification au propriétaire de la réponse
        if (reply.user_id != userId) {
          await _sendLikeNotification(reply.user_id!, parentComment, isReply: true, reply: reply);
        }
      }

      await postProvider.updateComment(parentComment);
      setState(() {});

    } catch (e) {
      print('Erreur like réponse: $e');
    }
  }

  // Fonction pour envoyer une notification de like
  Future<void> _sendLikeNotification(String receiverId, PostComment comment, {bool isReply = false, ResponsePostComment? reply}) async {
    try {
      // 1. Enregistrer dans Firebase
      final notif = NotificationData(
        id: firestore.collection('Notifications').doc().id,
        titre: "Nouveau like",
        media_url: authProvider.loginUserData.imageUrl,
        type: NotificationType.POST.name,
        description: "@${authProvider.loginUserData.pseudo!} a aimé votre ${isReply ? 'réponse' : 'commentaire'}",
        // user_id: receiverId,
        user_id: authProvider.loginUserData.id,
        receiver_id: receiverId,
        post_id: widget.post.id!,
        post_data_type: PostDataType.COMMENT.name!,
        createdAt: DateTime.now().microsecondsSinceEpoch,
        updatedAt: DateTime.now().microsecondsSinceEpoch,
        status: PostStatus.VALIDE.name,
      );

      await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());

      // 2. Envoyer la notification push
       authProvider.getUserById(receiverId).then((value) async {
         final List<UserData> receiverUser = value;
         print('send notif receiverUser: ${receiverUser.first.pseudo}');
         if (receiverUser.isNotEmpty && receiverUser.first.oneIgnalUserid != null) {
            authProvider.sendNotification(
               userIds: [receiverUser.first.oneIgnalUserid!],
               smallImage: authProvider.loginUserData.imageUrl!,
               send_user_id: authProvider.loginUserData.id!,
               recever_user_id: receiverId,
               message: "@${authProvider.loginUserData.pseudo!} a aimé votre ${isReply ? 'réponse' : 'commentaire'}",
               type_notif: NotificationType.POST.name,
               post_id: widget.post.id!,
               post_type: PostDataType.COMMENT.name!,
               chat_id: ''
           );
         }
       },);

    } catch (e) {
      print('Erreur envoi notification like: $e');
    }
  }

  // Fonction pour envoyer des notifications de mention
  Future<void> _sendMentionNotifications(String message) async {
    try {
      final mentionedUsers = _extractMentionedUsers(message);

      for (final username in mentionedUsers) {
        final user = users.firstWhere((u) => u.pseudo == username, orElse: () => UserData());
        if (user.id != null && user.id != authProvider.loginUserData.id) {

          // 1. Enregistrer dans Firebase
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

          // 2. Envoyer la notification push
          if (user.oneIgnalUserid != null) {
            await authProvider.sendNotification(
                userIds: [user.oneIgnalUserid!],
                smallImage: authProvider.loginUserData.imageUrl!,
                send_user_id: authProvider.loginUserData.id!,
                recever_user_id: user.id!,
                message: "@${authProvider.loginUserData.pseudo!} vous a mentionné dans un commentaire",
                type_notif: NotificationType.MESSAGE.name,
                post_id: widget.post.id!,
                post_type: PostDataType.COMMENT.name!,
                chat_id: ''
            );
          }
        }
      }
    } catch (e) {
      print('Erreur envoi notifications mention: $e');
    }
  }

  List<String> _extractMentionedUsers(String message) {
    final RegExp mentionRegex = RegExp(r'@(\w+)');
    final matches = mentionRegex.allMatches(message);
    return matches.map((match) => match.group(1)!).toList();
  }

  // Widget pour le texte avec mentions en vert
  Widget _buildMentionText(String text) {
    final List<TextSpan> spans = [];
    final RegExp mentionRegex = RegExp(r'@(\w+)');
    final matches = mentionRegex.allMatches(text);
    int lastEnd = 0;

    for (final match in matches) {
      // Texte avant la mention
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(color: Colors.black87, fontSize: 13),
        ));
      }

      // La mention en vert
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w500),
      ));

      lastEnd = match.end;
    }

    // Texte après la dernière mention
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(color: Colors.black87, fontSize: 13),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: _commentExpanded[text] ?? false ? null : 2,
      overflow: _commentExpanded[text] ?? false ? TextOverflow.visible : TextOverflow.ellipsis,
    );
  }

  Widget _buildPostHeader() {
    final post = widget.post;
    final isCanal = post.canal != null;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              double w = MediaQuery.of(context).size.width;
              double h = MediaQuery.of(context).size.height;
              if(!isCanal)
                showUserDetailsModalDialog( post.user!, w, h, context);
            },
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: NetworkImage(
                    isCanal ? post.canal!.urlImage! : post.user!.imageUrl!,
                  ),
                ),
                if ((isCanal ? post.canal!.isVerify : post.user!.isVerify) ?? false)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Icon(Icons.verified, color: Colors.blue, size: 14),
                  ),
              ],
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCanal ? "#${post.canal!.titre!}" : "@${post.user!.pseudo!}",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 2),
                Text(
                  formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(post.createdAt!)),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward_ios, size: 16),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => DetailsPost(post: widget.post),
              ));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(PostComment comment) {
    final hasReplies = comment.responseComments != null && comment.responseComments!.isNotEmpty;
    final repliesCount = comment.responseComments?.length ?? 0;
    final showAll = _showAllReplies[comment.id!] ?? false;
    final displayedReplies = showAll ? comment.responseComments! : (hasReplies ? [comment.responseComments!.first] : []);

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Commentaire principal
          _buildCommentContent(comment),

          // Réponses
          if (hasReplies) ...[
            ...displayedReplies.map((reply) => _buildReplyContent(comment, reply)),

            // Bouton pour voir plus/moins de réponses
            if (repliesCount > 1)
              Padding(
                padding: EdgeInsets.only(left: 40, top: 4),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showAllReplies[comment.id!] = !showAll;
                    });
                  },
                  child: Text(
                    showAll ? 'Masquer les réponses' : 'Voir ${repliesCount - 1} réponse(s) supplémentaire(s)',
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentContent(PostComment pcm) {
    final isLiked = pcm.users_like_id?.contains(authProvider.loginUserData.id!) ?? false;
    final likeCount = pcm.likes ?? 0;

    return Container(
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  double w = MediaQuery.of(context).size.width;
                  double h = MediaQuery.of(context).size.height;
                  showUserDetailsModalDialog(pcm.user!!, w, h, context);
                },
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: NetworkImage(pcm.user!.imageUrl ?? ''),
                  backgroundColor: Colors.grey.shade300,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "@${pcm.user!.pseudo!}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(width: 6),
                        if (pcm.user!.isVerify ?? false)
                          Icon(Icons.verified, size: 14, color: Colors.blue),
                        Spacer(),
                        Text(
                          formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(pcm.createdAt!)),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    _buildMentionText(pcm.message!),
                    if ((pcm.message ?? '').length > 100)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _commentExpanded[pcm.message!] = !(_commentExpanded[pcm.message!] ?? false);
                          });
                        },
                        child: Text(
                          _commentExpanded[pcm.message!] ?? false ? 'Voir moins' : 'Voir plus',
                          style: TextStyle(
                            color: Colors.blue.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              // Bouton Like
              GestureDetector(
                onTap: () => _likeComment(pcm),
                child: Row(
                  children: [
                    Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : Colors.grey.shade600,
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      formatNumber(likeCount),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              // Bouton Répondre
              GestureDetector(
                onTap: () {
                  setState(() {
                    commentSelectedToReply = pcm;
                    replyUser_id = pcm.user!.id!;
                    replyUser_pseudo = pcm.user!.pseudo!;
                    replyingTo = "@${pcm.user!.pseudo}";
                    replying = true;
                  });
                  _focusNode.requestFocus();
                },
                child: Row(
                  children: [
                    Icon(Icons.reply, size: 16, color: Colors.grey.shade600),
                    SizedBox(width: 4),
                    Text(
                      'Répondre',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Spacer(),
              // Menu options
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 16),
                itemBuilder: (context) => [
                  if (pcm.user!.id == authProvider.loginUserData.id || authProvider.loginUserData.role == UserRole.ADM.name)
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 16),
                          SizedBox(width: 8),
                          Text('Supprimer'),
                        ],
                      ),
                    ),
                ],
                onSelected: (value) async {
                  if (value == 'delete') {
                    await _deleteComment(pcm);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyContent(PostComment pcm, ResponsePostComment rpc) {
    final isLiked = rpc.users_like_id?.contains(authProvider.loginUserData.id!) ?? false;
    final likeCount = rpc.likes ?? 0;

    return Container(
      margin: EdgeInsets.only(left: 40, top: 4),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  if (rpc.user != null) {
                    double w = MediaQuery.of(context).size.width;
                    double h = MediaQuery.of(context).size.height;
                    showUserDetailsModalDialog(rpc.user!, w, h, context);
                  }
                },
                child: CircleAvatar(
                  radius: 14,
                  backgroundImage: NetworkImage(rpc.user_logo_url ?? ''),
                  backgroundColor: Colors.grey.shade300,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "@${rpc.user_pseudo}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(width: 4),
                        if (rpc.user_reply_pseudo != null && rpc.user_reply_pseudo!.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.reply, size: 12, color: Colors.grey),
                              SizedBox(width: 2),
                              Text(
                                "@${rpc.user_reply_pseudo}",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        Spacer(),
                        Text(
                          formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(rpc.createdAt!)),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    _buildMentionText(rpc.message!),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Row(
            children: [
              // Bouton Like
              GestureDetector(
                onTap: () => _likeReply(pcm, rpc),
                child: Row(
                  children: [
                    Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : Colors.grey.shade600,
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      formatNumber(likeCount),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              // Bouton Répondre
              GestureDetector(
                onTap: () {
                  setState(() {
                    commentSelectedToReply = pcm;
                    replyUser_id = rpc.user_id!;
                    replyUser_pseudo = rpc.user_pseudo!;
                    replyingTo = "@${rpc.user_pseudo}";
                    replying = true;
                  });
                  _focusNode.requestFocus();
                },
                child: Row(
                  children: [
                    Icon(Icons.reply, size: 14, color: Colors.grey.shade600),
                    SizedBox(width: 4),
                    Text(
                      'Répondre',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Spacer(),
              // Menu options
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, size: 14),
                itemBuilder: (context) => [
                  if (rpc.user_id == authProvider.loginUserData.id || authProvider.loginUserData.role == UserRole.ADM.name)
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 14),
                          SizedBox(width: 8),
                          Text('Supprimer'),
                        ],
                      ),
                    ),
                ],
                onSelected: (value) async {
                  if (value == 'delete') {
                    await _deleteResponse(pcm, rpc);
                  }
                },
              ),
            ],
          ),
        ],
      ),
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
            color: Colors.black12,
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      constraints: BoxConstraints(maxHeight: 300),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: suggestedUsers.length + (_hasMoreUsers ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == suggestedUsers.length) {
            return ListTile(
              title: Center(
                child: Text(
                  'Charger plus...',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
              onTap: _loadMoreUserSuggestions,
            );
          }

          final user = suggestedUsers[index];
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(user.imageUrl ?? ''),
            ),
            title: Text("@${user.pseudo!}", style: TextStyle(fontSize: 13)),
            onTap: () => _selectUser(user),
          );
        },
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        children: [
          if (replying)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.reply, color: Colors.blue, size: 14),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Réponse à $replyingTo",
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        replying = false;
                        replyingTo = "";
                      });
                    },
                    child: Icon(Icons.close, size: 14, color: Colors.blue.shade800),
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
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: replying ? 'Répondre...' : 'Ajouter un commentaire...',
                      hintStyle: TextStyle(fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      suffixIcon: _textController.text.isNotEmpty
                          ? IconButton(
                        icon: Icon(Icons.send, color: Colors.blue, size: 18),
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

  Future<void> _sendComment2() async {
    if (_textController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    final textComment = _textController.text.trim();
    _textController.clear();
    _focusNode.unfocus();

    try {
      bool success = false;
      String receiverId = '';
      String action = '';

      if (replying) {
        final response = ResponsePostComment(
          user_id: authProvider.loginUserData.id,
          user_logo_url: authProvider.loginUserData.imageUrl,
          user_pseudo: authProvider.loginUserData.pseudo,
          post_comment_id: commentSelectedToReply.id,
          user_reply_pseudo: replyUser_pseudo,
          message: textComment,
          createdAt: DateTime.now().microsecondsSinceEpoch,
          updatedAt: DateTime.now().microsecondsSinceEpoch,
        );

        commentSelectedToReply.responseComments ??= [];
        commentSelectedToReply.responseComments!.add(response);

        success = await postProvider.updateComment(commentSelectedToReply);
        receiverId = replyUser_id;
        action = "répondu à votre commentaire";
      } else {
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
        receiverId = widget.post.user!.id!;
        action = "commenté votre publication";
      }

      if (success) {
        await FirebaseFirestore.instance
            .collection("Posts")
            .doc(widget.post.id)
            .update({
          "comments": FieldValue.increment(1),
        });

        // Envoyer notification au propriétaire du commentaire/post
        await _sendCommentNotification(receiverId, action, textComment);

        // Envoyer notifications pour les mentions
        await _sendMentionNotifications(textComment);
      }

      setState(() {
        replying = false;
        replyingTo = "";
      });

      if (success) {
        // Recharger les commentaires depuis le début
        await _loadInitialComments();
      }

    } catch (e) {
      setState(() => _isLoading = false);
      print('Erreur envoi commentaire: $e');
    }
  }
  Future<void> _sendComment() async {
    if (_textController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    final textComment = _textController.text.trim();
    _textController.clear();
    _focusNode.unfocus();

    try {
      bool success = false;
      String receiverId = '';
      String action = '';

      if (replying) {
        final response = ResponsePostComment(
          user_id: authProvider.loginUserData.id,
          user_logo_url: authProvider.loginUserData.imageUrl,
          user_pseudo: authProvider.loginUserData.pseudo,
          post_comment_id: commentSelectedToReply.id,
          user_reply_pseudo: replyUser_pseudo,
          message: textComment,
          createdAt: DateTime.now().microsecondsSinceEpoch,
          updatedAt: DateTime.now().microsecondsSinceEpoch,
        );

        commentSelectedToReply.responseComments ??= [];
        commentSelectedToReply.responseComments!.add(response);

        success = await postProvider.updateComment(commentSelectedToReply);
        receiverId = replyUser_id;
        action = "répondu à votre commentaire";

        // Mettre à jour localement immédiatement
        if (success) {
          _updateCommentLocally(commentSelectedToReply);
        }
      } else {
        final comment = PostComment(
          id: FirebaseFirestore.instance.collection('PostComments').doc().id, // Ajouter un ID
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
        receiverId = widget.post.user!.id!;
        action = "commenté votre publication";

        // Ajouter localement immédiatement
        if (success) {
          _addCommentLocally(comment);
        }
      }

      if (success) {
        await FirebaseFirestore.instance
            .collection("Posts")
            .doc(widget.post.id)
            .update({
          "comments": FieldValue.increment(1),
        });

        // Envoyer notification au propriétaire du commentaire/post
        await _sendCommentNotification(receiverId, action, textComment);

        // Envoyer notifications pour les mentions
        await _sendMentionNotifications(textComment);
      }
      FeedInteractionService.onPostCommented(widget.post, authProvider.loginUserData.id!);
      setState(() {
        replying = false;
        replyingTo = "";
        _isLoading = false; // IMPORTANT: Arrêter le loading
      });

    } catch (e) {
      setState(() => _isLoading = false);
      print('Erreur envoi commentaire: $e');

      // Optionnel: Afficher un message d'erreur à l'utilisateur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'envoi du commentaire'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Ajouter un nouveau commentaire localement
  void _addCommentLocally(PostComment newComment) {
    setState(() {
      comments.insert(0, newComment); // Ajouter en haut de la liste
    });
  }

// Mettre à jour un commentaire existant localement
  void _updateCommentLocally(PostComment updatedComment) {
    setState(() {
      final index = comments.indexWhere((c) => c.id == updatedComment.id);
      if (index != -1) {
        comments[index] = updatedComment;
      }
    });
  }
  // Fonction pour envoyer une notification de commentaire/réponse
  Future<void> _sendCommentNotification(String receiverId, String action, String message) async {
    try {
      // 1. Enregistrer dans Firebase
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

      // 2. Envoyer la notification push
      final receiverUser = await authProvider.getUserById(receiverId);
      if (receiverUser.isNotEmpty && receiverUser.first.oneIgnalUserid != null) {
        await authProvider.sendNotification(
            userIds: [receiverUser.first.oneIgnalUserid!],
            smallImage: authProvider.loginUserData.imageUrl!,
            send_user_id: authProvider.loginUserData.id!,
            recever_user_id: receiverId,
            message: "@${authProvider.loginUserData.pseudo!} a $action",
            type_notif: NotificationType.POST.name,
            post_id: widget.post.id!,
            post_type: PostDataType.COMMENT.name!,
            chat_id: ''
        );
      }
    } catch (e) {
      print('Erreur envoi notification commentaire: $e');
    }
  }

  Future<void> _deleteComment(PostComment comment) async {
    setState(() => _isLoading = true);
    comment.status = PostStatus.SUPPRIMER.name;
    bool success = await postProvider.updateComment(comment);
    setState(() => _isLoading = false);

    if (success) {
      await _loadInitialComments();
    }
  }

  Future<void> _deleteResponse(PostComment parentComment, ResponsePostComment response) async {
    setState(() => _isLoading = true);
    response.status = PostStatus.SUPPRIMER.name;
    bool success = await postProvider.updateComment(parentComment);
    setState(() => _isLoading = false);

    if (success) {
      await _loadInitialComments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Commentaires',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _buildPostHeader(),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
                  _loadMoreComments();
                }
                return false;
              },
              child: _isLoading && comments.isEmpty
                  ? Center(child: CircularProgressIndicator())
                  : comments.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.comment_outlined, size: 50, color: Colors.grey.shade400),
                    SizedBox(height: 12),
                    Text(
                      'Aucun commentaire',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: EdgeInsets.all(8),
                itemCount: comments.length + (_hasMoreComments ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == comments.length) {
                    return _isLoadingMore
                        ? Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                        : SizedBox.shrink();
                  }
                  return _buildCommentItem(comments[index]);
                },
              ),
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }
}



