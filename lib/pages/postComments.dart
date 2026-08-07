import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/layout/responsive_layout.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:afrotok/pages/postDetails.dart';
import 'package:afrotok/pages/postDetailsVideo.dart';
import 'package:afrotok/pages/post_video_format_tel_details.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/authProvider.dart';
import '../providers/userProvider.dart';
import '../services/postService/feed_interaction_service.dart';
import '../services/streak_service.dart';
import '../services/utils/abonnement_utils.dart';
import '../widgets/user_badge_widget.dart';
import '../theme/app_colors.dart';
import '../l10n/app_localizations.dart';
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import '../services/comment_suggestion_service.dart';

import 'coins/post_gifts_list.dart';

class PostComments extends StatefulWidget {
  final Post post;
  final bool isInModal;
  final bool focusKeyboard;
  final List<PostComment> initialComments;
  final String? initialText;

  const PostComments({
    super.key,
    required this.post,
    this.isInModal = false,
    this.focusKeyboard = false,
    this.initialComments = const [],
    this.initialText,
  });

  @override
  State<PostComments> createState() => _PostCommentsState();
}

class _PostCommentsState extends State<PostComments> with TickerProviderStateMixin {
  late AppColors _colors;
  late UserAuthProvider authProvider;
  late UserProvider userProvider;
  late PostProvider postProvider;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  PostComment commentSelectedToReply = PostComment();
  bool replying = false;
  String replyingTo = '';
  // ignore: non_constant_identifier_names
  String replyUser_pseudo = '';
  // ignore: non_constant_identifier_names
  String replyUser_id = '';
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreComments = true;

  DocumentSnapshot? _lastCommentDocument;
  final int _commentsPageSize = 6;

  final Map<String, bool> _commentExpanded = {};
  final Map<String, bool> _replyExpanded = {};
  final Map<String, bool> _showAllReplies = {};

  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<UserData> users = [];
  List<PostComment> comments = [];
  List<UserData> suggestedUsers = [];
  bool showUserSuggestions = false;
  String currentSearchQuery = '';

  int _userSuggestionsPage = 0;
  final int _userSuggestionsPageSize = 10;
  bool _hasMoreUsers = true;

  bool _showEmojiPicker = false;
  List<String> _shuffledSuggestions = [];
  bool _suggestionsFromAi = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _suggestionSub;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);

    final aiSuggestions = widget.post.commentSuggestions;
    if (aiSuggestions != null && aiSuggestions.isNotEmpty) {
      _shuffledSuggestions = List<String>.from(aiSuggestions)..shuffle();
      _suggestionsFromAi = true;
    } else {
      // Fallback local immédiat pendant que l'IA génère (ou si pas de clé configurée)
      _shuffledSuggestions = CommentSuggestionService.getSuggestions(
        widget.post.id ?? '',
        widget.post.description ?? '',
        postType: widget.post.typeTabbar,
      );
      // Listener Firestore : mise à jour en temps réel quand l'IA génère les suggestions
      _listenForAiSuggestions();
    }

    if (widget.initialComments.isNotEmpty) {
      comments = List.from(widget.initialComments);
      _loadUserDataForInitialComments();
    }
    _loadUsers();
    _loadInitialComments();
    _textController.addListener(_onTextChanged);

    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _textController.text = widget.initialText!;
      _textController.selection =
          TextSelection.fromPosition(TextPosition(offset: widget.initialText!.length));
    }

    if (widget.focusKeyboard) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) _focusNode.requestFocus();
        });
      });
    }
  }

  @override
  void dispose() {
    _suggestionSub?.cancel();
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _listenForAiSuggestions() {
    final postId = widget.post.id;
    if (postId == null || postId.isEmpty) return;
    _suggestionSub = FirebaseFirestore.instance
        .collection('Posts')
        .doc(postId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final data = snap.data();
      if (data == null) return;
      final raw = data['commentSuggestions'];
      if (raw is List && raw.isNotEmpty) {
        final updated = List<String>.from(raw)..shuffle();
        setState(() {
          _shuffledSuggestions = updated;
          _suggestionsFromAi = true;
        });
        _suggestionSub?.cancel();
        _suggestionSub = null;
      }
    });
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
        setState(() => showUserSuggestions = false);
      }
    } else {
      setState(() => showUserSuggestions = false);
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
      _textController.selection = TextSelection.fromPosition(TextPosition(offset: newText.length));
    }
    setState(() => showUserSuggestions = false);
  }

  Future<void> _loadUsers() async {
    final usersList = await userProvider.getUserAbonnes(authProvider.loginUserData.id!);
    setState(() => users = usersList);
  }

  Future<void> _loadInitialComments() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      if (comments.isEmpty) comments.clear();
      _lastCommentDocument = null;
      _hasMoreComments = true;
    });
    try {
      await _loadCommentsBatch();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreComments() async {
    if (_isLoadingMore || !_hasMoreComments) return;
    setState(() => _isLoadingMore = true);
    try {
      await _loadCommentsBatch();
    } catch (_) {
    } finally {
      setState(() => _isLoadingMore = false);
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

    List<PostComment> newComments = querySnapshot.docs
        .map((doc) => PostComment.fromJson(doc.data() as Map<String, dynamic>))
        .toList();

    // Charger toutes les données utilisateurs en parallèle
    final userFutures = newComments.map((c) => _loadUserData(c.user_id ?? '')).toList();
    final usersData = await Future.wait(userFutures);
    for (int i = 0; i < newComments.length; i++) {
      newComments[i].user = usersData[i];
    }

    // Dédupliquer avec les commentaires déjà affichés (preloaded)
    final existingIds = comments.map((c) => c.id).toSet();
    final deduplicated = newComments.where((c) => !existingIds.contains(c.id)).toList();

    setState(() {
      comments.addAll(deduplicated);
      _isLoading = false;
    });
  }

  Future<UserData?> _loadUserData(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final doc = await FirebaseFirestore.instance.collection('Users').doc(userId).get();
      if (doc.exists) return UserData.fromJson(doc.data()!);
    } catch (_) {}
    return null;
  }

  Future<void> _loadUserDataForInitialComments() async {
    final futures = comments.map((c) => _loadUserData(c.user_id ?? '')).toList();
    final loaded = await Future.wait(futures);
    if (!mounted) return;
    setState(() {
      for (int i = 0; i < comments.length; i++) {
        if (comments[i].user == null) comments[i].user = loaded[i];
      }
    });
  }

  String formatNumber(int number) {
    if (number < 1000) return number.toString();
    if (number < 1000000) return "${(number / 1000).toStringAsFixed(1)}k";
    return "${(number / 1000000).toStringAsFixed(1)}m";
  }

  String formaterDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inDays < 1) {
      if (diff.inHours < 1) {
        if (diff.inMinutes < 1) return "maintenant";
        return "${diff.inMinutes}m";
      }
      return "${diff.inHours}h";
    } else if (diff.inDays < 7) {
      return "${diff.inDays}j";
    }
    return DateFormat('dd/MM/yy').format(dateTime);
  }

  Future<void> _likeComment(PostComment comment) async {
    try {
      final userId = authProvider.loginUserData.id!;
      final isLiked = comment.users_like_id?.contains(userId) ?? false;

      if (isLiked) {
        comment.users_like_id?.remove(userId);
        comment.likes = (comment.likes ?? 1) - 1;
        setState(() {});
      } else {
        comment.users_like_id?.add(userId);
        comment.likes = (comment.likes ?? 0) + 1;
        setState(() {});
        if (comment.user!.id != userId) {
          await _sendLikeNotification(comment.user!.id!, comment);
        }
      }
      await postProvider.updateComment(comment);
    } catch (_) {}
  }

  Future<void> _likeReply(PostComment parentComment, ResponsePostComment reply) async {
    try {
      final userId = authProvider.loginUserData.id!;
      final isLiked = reply.users_like_id?.contains(userId) ?? false;

      if (isLiked) {
        reply.users_like_id?.remove(userId);
        reply.likes = (reply.likes ?? 1) - 1;
        setState(() {});
      } else {
        reply.users_like_id?.add(userId);
        reply.likes = (reply.likes ?? 0) + 1;
        setState(() {});
        if (reply.user_id != userId) {
          await _sendLikeNotification(reply.user_id!, parentComment, isReply: true, reply: reply);
        }
      }
      await postProvider.updateComment(parentComment);
    } catch (_) {}
  }

  Future<void> _sendLikeNotification(String receiverId, PostComment comment,
      {bool isReply = false, ResponsePostComment? reply}) async {
    try {
      final action = isReply ? 'reponse' : 'commentaire';
      final msg = "@${authProvider.loginUserData.pseudo!} a aime votre $action";
      final notif = NotificationData(
        id: firestore.collection('Notifications').doc().id,
        titre: "Nouveau like",
        media_url: authProvider.loginUserData.imageUrl,
        type: NotificationType.POST.name,
        description: msg,
        user_id: authProvider.loginUserData.id,
        receiver_id: receiverId,
        post_id: widget.post.id!,
        post_data_type: PostDataType.COMMENT.name,
        createdAt: DateTime.now().microsecondsSinceEpoch,
        updatedAt: DateTime.now().microsecondsSinceEpoch,
        status: PostStatus.VALIDE.name,
      );
      await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());

      authProvider.getUserById(receiverId).then((value) async {
        final List<UserData> receiverUser = value;
        if (receiverUser.isNotEmpty && receiverUser.first.oneIgnalUserid != null) {
          authProvider.sendNotification(
            userIds: [receiverUser.first.oneIgnalUserid!],
            smallImage: authProvider.loginUserData.imageUrl!,
            send_user_id: authProvider.loginUserData.id!,
            recever_user_id: receiverId,
            message: msg,
            type_notif: NotificationType.POST.name,
            post_id: widget.post.id!,
            post_type: PostDataType.COMMENT.name,
            chat_id: '',
          );
        }
      });
    } catch (_) {}
  }

  Future<void> _sendMentionNotifications(String message) async {
    try {
      final mentionedUsers = _extractMentionedUsers(message);
      for (final username in mentionedUsers) {
        final user = users.firstWhere((u) => u.pseudo == username, orElse: () => UserData());
        if (user.id != null && user.id != authProvider.loginUserData.id) {
          final msg = "@${authProvider.loginUserData.pseudo!} vous a mentionne dans un commentaire";
          final mentionNotif = NotificationData(
            id: firestore.collection('Notifications').doc().id,
            titre: "Vous avez ete mentionne",
            media_url: authProvider.loginUserData.imageUrl,
            type: NotificationType.MESSAGE.name,
            description: msg,
            user_id: authProvider.loginUserData.id,
            receiver_id: user.id!,
            post_id: widget.post.id!,
            post_data_type: PostDataType.COMMENT.name,
            createdAt: DateTime.now().microsecondsSinceEpoch,
            updatedAt: DateTime.now().microsecondsSinceEpoch,
            status: PostStatus.VALIDE.name,
          );
          await firestore.collection('Notifications').doc(mentionNotif.id).set(mentionNotif.toJson());

          if (user.oneIgnalUserid != null) {
            await authProvider.sendNotification(
              userIds: [user.oneIgnalUserid!],
              smallImage: authProvider.loginUserData.imageUrl!,
              send_user_id: authProvider.loginUserData.id!,
              recever_user_id: user.id!,
              message: msg,
              type_notif: NotificationType.MESSAGE.name,
              post_id: widget.post.id!,
              post_type: PostDataType.COMMENT.name,
              chat_id: '',
            );
          }
        }
      }
    } catch (_) {}
  }

  List<String> _extractMentionedUsers(String message) {
    final RegExp mentionRegex = RegExp(r'@(\w+)');
    final matches = mentionRegex.allMatches(message);
    return matches.map((match) => match.group(1)!).toList();
  }

  Widget _buildMentionText(String text, {bool isExpanded = false, int maxLinesReduced = 2}) {
    final List<TextSpan> spans = [];
    final RegExp mentionRegex = RegExp(r'@(\w+)');
    final matches = mentionRegex.allMatches(text);
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(color: _colors.textPrimary, fontSize: 13.5, height: 1.4),
        ));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(color: _colors.primary, fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.4),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(color: _colors.textPrimary, fontSize: 13.5, height: 1.4),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: isExpanded ? null : maxLinesReduced,
      overflow: isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
    );
  }

  // ─── POST HEADER ────────────────────────────────────────────────────────────

  Widget _buildPostHeader() {
    final post = widget.post;
    final isCanal = post.canal != null;

    return post.user == null
        ? const SizedBox.shrink()
        : Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: _colors.surface,
              border: Border(bottom: BorderSide(color: _colors.divider.withOpacity(0.5))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (!isCanal) {
                          showUserDetailsModalDialog(
                            post.user!,
                            MediaQuery.of(context).size.width,
                            MediaQuery.of(context).size.height,
                            context,
                          );
                        }
                      },
                      child: CircleAvatar(
                        radius: 19,
                        backgroundColor: _colors.surfaceVariant,
                        backgroundImage: NetworkImage(
                          isCanal ? post.canal!.urlImage! : post.user!.imageUrl!,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                isCanal ? "#${post.canal!.titre!}" : "@${post.user!.pseudo!}",
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: _colors.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              UserBadgeWidget(user: post.user, size: 14),
                            ],
                          ),
                          Text(
                            formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(post.createdAt!)),
                            style: TextStyle(color: _colors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    if (!widget.isInModal)
                      TextButton(
                        onPressed: () {
                          final post = widget.post;
                          final isVideo = post.dataType == 'VIDEO';
                          final isPortrait = post.isPortrait ?? true;
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => isVideo
                                ? (isPortrait
                                    ? PostDetailsVideoFormatTel(initialPost: post)
                                    : VideoYoutubePageDetails(initialPost: post))
                                : DetailsPost(post: post),
                          ));
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: _colors.primary.withOpacity(0.4)),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context).postCommentViewPost,
                          style: TextStyle(color: _colors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                PostGiftsList(
                  postId: widget.post.id!,
                  compactLevel: CompactLevel.light,
                  maxDisplayItems: 10,
                ),
              ],
            ),
          );
  }

  // ─── COMMENT ITEM ────────────────────────────────────────────────────────────

  Widget _buildCommentItem(PostComment comment) {
    final hasReplies = comment.responseComments != null && comment.responseComments!.isNotEmpty;
    final repliesCount = comment.responseComments?.length ?? 0;
    final showAll = _showAllReplies[comment.id!] ?? false;
    final displayedReplies = showAll
        ? comment.responseComments!
        : (hasReplies ? [comment.responseComments!.first] : []);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCommentContent(comment),
          if (hasReplies) ...[
            const SizedBox(height: 4),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 18),
                    child: Container(
                      width: 1.5,
                      color: _colors.border.withOpacity(0.3),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...displayedReplies.map((reply) => _buildReplyContent(comment, reply)),
                        if (repliesCount > 1)
                          GestureDetector(
                            onTap: () => setState(() => _showAllReplies[comment.id!] = !showAll),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 18,
                                    height: 1.5,
                                    color: _colors.primary.withOpacity(0.5),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    showAll
                                        ? 'Masquer les reponses'
                                        : 'Voir ${repliesCount - 1} reponse(s) de plus',
                                    style: TextStyle(
                                      color: _colors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          Divider(height: 1, color: _colors.divider.withOpacity(0.3)),
        ],
      ),
    );
  }

  Widget _buildCommentContent(PostComment pcm) {
    final isLiked = pcm.users_like_id?.contains(authProvider.loginUserData.id!) ?? false;
    final likeCount = pcm.likes ?? 0;

    final textPainter = TextPainter(
      text: TextSpan(
        text: pcm.message ?? '',
        style: TextStyle(fontSize: 13.5, color: _colors.textPrimary),
      ),
      maxLines: 2,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: MediaQuery.of(context).size.width - 80);

    final needsExpandButton = textPainter.didExceedMaxLines;
    final isExpanded = _commentExpanded[pcm.id!] ?? false;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            if (pcm.user != null) {
              showUserDetailsModalDialog(
                pcm.user!,
                MediaQuery.of(context).size.width,
                MediaQuery.of(context).size.height,
                context,
              );
            }
          },
          child: CircleAvatar(
            radius: 18,
            backgroundColor: _colors.surfaceVariant,
            backgroundImage: (pcm.user?.imageUrl != null && pcm.user!.imageUrl!.isNotEmpty)
                ? NetworkImage(pcm.user!.imageUrl!)
                : null,
            child: (pcm.user?.imageUrl == null || pcm.user!.imageUrl!.isEmpty)
                ? Icon(Icons.person, size: 16, color: _colors.textSecondary)
                : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    "@${pcm.user?.pseudo ?? '...'}",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _colors.textPrimary),
                  ),
                  const SizedBox(width: 4),
                  UserBadgeWidget(user: pcm.user, size: 14),
                  const Spacer(),
                  Text(
                    formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(pcm.createdAt!)),
                    style: TextStyle(color: _colors.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    icon: Icon(Icons.more_horiz_rounded, size: 16, color: _colors.textSecondary),
                    color: _colors.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    itemBuilder: (_) => [
                      if (pcm.user?.id == authProvider.loginUserData.id ||
                          authProvider.loginUserData.role == UserRole.ADM.name)
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, color: _colors.danger, size: 16),
                              const SizedBox(width: 8),
                              Text('Supprimer', style: TextStyle(color: _colors.danger, fontSize: 13)),
                            ],
                          ),
                        ),
                    ],
                    onSelected: (value) async {
                      if (value == 'delete') await _deleteComment(pcm);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 3),
              _buildMentionText(pcm.message ?? '', isExpanded: isExpanded, maxLinesReduced: 2),
              if (needsExpandButton)
                GestureDetector(
                  onTap: () => setState(() => _commentExpanded[pcm.id!] = !isExpanded),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      isExpanded ? 'Reduire' : 'Lire la suite',
                      style: TextStyle(color: _colors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildActionButton(
                    icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isLiked ? _colors.danger : _colors.textSecondary,
                    label: likeCount > 0 ? formatNumber(likeCount) : null,
                    onTap: () => _likeComment(pcm),
                  ),
                  const SizedBox(width: 16),
                  _buildActionButton(
                    icon: Icons.mode_comment_outlined,
                    color: _colors.textSecondary,
                    label: 'Repondre',
                    onTap: () {
                      setState(() {
                        commentSelectedToReply = pcm;
                        replyUser_id = pcm.user!.id!;
                        replyUser_pseudo = pcm.user!.pseudo!;
                        replyingTo = "@${pcm.user!.pseudo}";
                        replying = true;
                        _showEmojiPicker = false;
                      });
                      _focusNode.requestFocus();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReplyContent(PostComment pcm, ResponsePostComment rpc) {
    final isLiked = rpc.users_like_id?.contains(authProvider.loginUserData.id!) ?? false;
    final likeCount = rpc.likes ?? 0;

    final textPainter = TextPainter(
      text: TextSpan(
        text: rpc.message ?? '',
        style: TextStyle(fontSize: 13, color: _colors.textPrimary),
      ),
      maxLines: 2,
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: MediaQuery.of(context).size.width - 80);

    final needsExpandButton = textPainter.didExceedMaxLines;
    final replyKey = '${pcm.id}_${rpc.user_id}_${rpc.createdAt}';
    final isExpanded = _replyExpanded[replyKey] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: _colors.surfaceVariant,
            backgroundImage: (rpc.user_logo_url != null && rpc.user_logo_url!.isNotEmpty)
                ? NetworkImage(rpc.user_logo_url!)
                : null,
            child: (rpc.user_logo_url == null || rpc.user_logo_url!.isEmpty)
                ? Icon(Icons.person, size: 12, color: _colors.textSecondary)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      "@${rpc.user_pseudo ?? ''}",
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: _colors.textPrimary),
                    ),
                    if (rpc.user_reply_pseudo != null && rpc.user_reply_pseudo!.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded, size: 9, color: _colors.textSecondary),
                      const SizedBox(width: 2),
                      Text(
                        "@${rpc.user_reply_pseudo}",
                        style: TextStyle(color: _colors.textSecondary, fontSize: 11.5),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(rpc.createdAt!)),
                      style: TextStyle(color: _colors.textSecondary, fontSize: 10),
                    ),
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      iconSize: 14,
                      icon: Icon(Icons.more_horiz_rounded, size: 14, color: _colors.textSecondary),
                      color: _colors.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      itemBuilder: (_) => [
                        if (rpc.user_id == authProvider.loginUserData.id ||
                            authProvider.loginUserData.role == UserRole.ADM.name)
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline_rounded, color: _colors.danger, size: 14),
                                const SizedBox(width: 8),
                                Text('Supprimer', style: TextStyle(color: _colors.danger, fontSize: 12)),
                              ],
                            ),
                          ),
                      ],
                      onSelected: (value) async {
                        if (value == 'delete') await _deleteResponse(pcm, rpc);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                _buildMentionText(rpc.message ?? '', isExpanded: isExpanded, maxLinesReduced: 2),
                if (needsExpandButton)
                  GestureDetector(
                    onTap: () => setState(() => _replyExpanded[replyKey] = !isExpanded),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        isExpanded ? 'Reduire' : 'Lire la suite',
                        style: TextStyle(color: _colors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    _buildActionButton(
                      icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isLiked ? _colors.danger : _colors.textSecondary,
                      label: likeCount > 0 ? formatNumber(likeCount) : null,
                      onTap: () => _likeReply(pcm, rpc),
                      small: true,
                    ),
                    const SizedBox(width: 14),
                    _buildActionButton(
                      icon: Icons.mode_comment_outlined,
                      color: _colors.textSecondary,
                      label: 'Repondre',
                      onTap: () {
                        setState(() {
                          commentSelectedToReply = pcm;
                          replyUser_id = rpc.user_id!;
                          replyUser_pseudo = rpc.user_pseudo!;
                          replyingTo = "@${rpc.user_pseudo}";
                          replying = true;
                          _showEmojiPicker = false;
                        });
                        _focusNode.requestFocus();
                      },
                      small: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    String? label,
    required VoidCallback onTap,
    bool small = false,
  }) {
    final size = small ? 14.0 : 15.0;
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: size),
          if (label != null) ...[
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: _colors.textSecondary, fontSize: small ? 11 : 12)),
          ],
        ],
      ),
    );
  }

  // ─── USER SUGGESTIONS ───────────────────────────────────────────────────────

  Widget _buildUserSuggestions() {
    if (!showUserSuggestions || suggestedUsers.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _colors.border.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, -4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: suggestedUsers.length + (_hasMoreUsers ? 1 : 0),
          separatorBuilder: (_, __) => Divider(height: 1, color: _colors.divider.withOpacity(0.3)),
          itemBuilder: (_, index) {
            if (index == suggestedUsers.length) {
              return ListTile(
                dense: true,
                title: Center(
                  child: Text('Charger plus...', style: TextStyle(color: _colors.primary, fontSize: 12)),
                ),
                onTap: _loadMoreUserSuggestions,
              );
            }
            final user = suggestedUsers[index];
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: _colors.surfaceVariant,
                backgroundImage: (user.imageUrl != null && user.imageUrl!.isNotEmpty)
                    ? NetworkImage(user.imageUrl!)
                    : null,
              ),
              title: Text("@${user.pseudo!}", style: TextStyle(fontSize: 13, color: _colors.textPrimary)),
              onTap: () => _selectUser(user),
            );
          },
        ),
      ),
    );
  }

  // ─── SUGGESTIONS ────────────────────────────────────────────────────────────

  Widget _buildCommentSuggestions() {
    return SizedBox(
      height: 34,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _shuffledSuggestions.length + 1,
        itemBuilder: (_, i) {
          // Premier item : badge source (IA ou local)
          if (i == 0) {
            return Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: _suggestionsFromAi
                    ? const Color(0xFF6C3EDB).withOpacity(0.12)
                    : _colors.surfaceVariant,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: _suggestionsFromAi
                      ? const Color(0xFF6C3EDB).withOpacity(0.35)
                      : _colors.border.withOpacity(0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _suggestionsFromAi ? '✨' : '💡',
                    style: const TextStyle(fontSize: 11),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    _suggestionsFromAi ? 'IA' : 'local',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: _suggestionsFromAi
                          ? const Color(0xFF6C3EDB)
                          : _colors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          final text = _shuffledSuggestions[i - 1];
          return GestureDetector(
            onTap: () {
              if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
              _textController.text = text;
              _sendComment();
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _colors.surfaceVariant,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: _colors.border.withOpacity(0.5)),
              ),
              child: Text(
                text,
                style: TextStyle(fontSize: 12, color: _colors.textPrimary),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── INPUT BAR ───────────────────────────────────────────────────────────────

  Widget _buildCommentInput() {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Banniere reponse
          if (replying)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: _colors.primary.withOpacity(0.08),
              child: Row(
                children: [
                  Icon(Icons.reply_rounded, color: _colors.primary, size: 15),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Repondre a $replyingTo",
                      style: TextStyle(color: _colors.primary, fontSize: 12.5, fontWeight: FontWeight.w500),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() { replying = false; replyingTo = ""; }),
                    child: Icon(Icons.close_rounded, size: 16, color: _colors.primary),
                  ),
                ],
              ),
            ),

          // Suggestions @mention
          if (showUserSuggestions && suggestedUsers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _buildUserSuggestions(),
            ),

          // Suggestions de commentaires rapides
          if (!showUserSuggestions)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: _buildCommentSuggestions(),
            ),

          // Barre de saisie
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _colors.surface,
              border: Border(top: BorderSide(color: _colors.divider.withOpacity(0.4))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Bouton emoji/sticker
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showEmojiPicker = !_showEmojiPicker;
                      if (_showEmojiPicker) {
                        _focusNode.unfocus();
                      } else {
                        _focusNode.requestFocus();
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8, right: 6),
                    child: Icon(
                      _showEmojiPicker ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
                      color: _colors.textSecondary,
                      size: 24,
                    ),
                  ),
                ),
                // Champ de texte
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 100),
                    decoration: BoxDecoration(
                      color: _colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _colors.border.withOpacity(0.3)),
                    ),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      maxLines: null,
                      style: TextStyle(color: _colors.textPrimary, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: replying ? 'Ecrire une reponse...' : 'Ajouter un commentaire...',
                        hintStyle: TextStyle(fontSize: 13.5, color: _colors.textSecondary),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        isDense: true,
                      ),
                      onTap: () {
                        if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Bouton envoi
                GestureDetector(
                  onTap: _sendComment,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _colors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: _isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),

          // Emoji picker
          if (_showEmojiPicker)
            SizedBox(
              height: 280,
              child: EmojiPicker(
                textEditingController: _textController,
                onEmojiSelected: (category, emoji) => setState(() {}),
                config: Config(
                  height: 280,
                  emojiViewConfig: EmojiViewConfig(
                    columns: 8,
                    emojiSizeMax: 28,
                    backgroundColor: _colors.background,
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    backgroundColor: _colors.surfaceVariant,
                    indicatorColor: _colors.primary,
                    iconColorSelected: _colors.primary,
                    iconColor: _colors.textSecondary,
                  ),
                  searchViewConfig: SearchViewConfig(
                    backgroundColor: _colors.background,
                    buttonIconColor: _colors.primary,
                  ),
                  skinToneConfig: const SkinToneConfig(),
                  bottomActionBarConfig: BottomActionBarConfig(
                    backgroundColor: _colors.surfaceVariant,
                    buttonColor: _colors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── SEND / DELETE ───────────────────────────────────────────────────────────

  static const int _freeCommentLimit = 10;
  static const int _commentCost = 5; // pièces
  static const int _creatorShare = 2; // pièces au créateur
  static const int _appShare = 3;     // pièces à l'app

  /// Retourne true si l'envoi peut continuer (gratuit ou paiement accepté).
  Future<bool> _checkAndDeductCommentFee() async {
    final userId = authProvider.loginUserData.id!;
    final postId = widget.post.id!;
    final creatorId = widget.post.user_id;

    // Le créateur ne paie pas sur son propre post
    if (creatorId == userId) return true;

    // Compter les commentaires de cet user sur ce post (côté serveur)
    final countSnap = await firestore
        .collection('PostComments')
        .where('user_id', isEqualTo: userId)
        .where('post_id', isEqualTo: postId)
        .count()
        .get();
    final commentCount = countSnap.count ?? 0;

    if (commentCount < _freeCommentLimit) return true;

    // Au-delà de la limite gratuite → vérifier les pièces
    final coins = authProvider.loginUserData.coinsBalance ?? 0;
    if (coins < _commentCost) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Pièces insuffisantes'),
            content: Text(
              'Vous avez utilisé vos $_freeCommentLimit commentaires gratuits sur cette publication.\n\n'
              'Chaque commentaire supplémentaire coûte $_commentCost pièces. '
              'Rechargez vos pièces pour continuer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return false;
    }

    // Confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Commentaire payant'),
        content: Text(
          'Vous avez déjà commenté $_freeCommentLimit fois cette publication.\n\n'
          'Ce commentaire coûte $_commentCost pièces (2 au créateur, 3 à la plateforme).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Envoyer ($_commentCost pièces)'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;

    // Transaction Firestore : déduire coins + créditer créateur + app
    final userRef = firestore.collection('Users').doc(userId);
    final appId = authProvider.appDefaultData.id;

    await firestore.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final currentCoins = (userSnap.data()?['coinsBalance'] as num? ?? 0).toInt();
      if (currentCoins < _commentCost) throw Exception('Pièces insuffisantes');

      tx.update(userRef, {'coinsBalance': FieldValue.increment(-_commentCost)});

      if (creatorId != null && creatorId.isNotEmpty) {
        tx.update(firestore.collection('Users').doc(creatorId), {
          'giftCoinsBalance': FieldValue.increment(_creatorShare),
        });
      }
      if (appId != null && appId.isNotEmpty) {
        tx.update(firestore.collection('AppData').doc(appId), {
          'solde_gain_pieces': FieldValue.increment(_appShare),
        });
      }
    });

    authProvider.loginUserData.coinsBalance = (coins - _commentCost);
    return true;
  }

  Future<void> _sendComment() async {
    if (_textController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    final textComment = _textController.text.trim();

    // Vérification du quota de commentaires gratuits (max 10 par user par post)
    final canSend = await _checkAndDeductCommentFee();
    if (!canSend) {
      setState(() => _isLoading = false);
      return;
    }

    _textController.clear();
    _focusNode.unfocus();
    if (_showEmojiPicker) setState(() => _showEmojiPicker = false);

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
        action = "repondu a votre commentaire";

        if (success) {
          FeedInteractionService.onPostCommented(widget.post, authProvider.loginUserData.id!);
          _updateCommentLocally(commentSelectedToReply);
        }
      } else {
        final comment = PostComment(
          id: FirebaseFirestore.instance.collection('PostComments').doc().id,
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
        if (widget.post.user != null) receiverId = widget.post.user!.id!;
        action = "commente votre publication";
        if (success) {
          _addCommentLocally(comment);
          widget.post.comments = (widget.post.comments ?? 0) + 1;
        }
      }

      if (success) {
        authProvider.incrementPostTotalInteractions(
          postId: widget.post.id!,
          userId: authProvider.loginUserData.id!,
          interactionType: 'comment',
        );
        try {
          await StreakService.onCommentSent(
            userId: authProvider.loginUserData.id!,
            postId: widget.post.id!,
          );
        } catch (e) {
          debugPrint('[Streak] erreur onCommentSent: $e');
        }
        authProvider.notifySubscribersOfInteraction(
          actionUserId: authProvider.loginUserData.id!,
          postOwnerId: widget.post.user_id!,
          postId: widget.post.id!,
          actionType: 'comment',
          commentaireMessage: textComment,
          postDescription: widget.post.description,
          postImageUrl: widget.post.type != PostDataType.IMAGE.name
              ? (widget.post.thumbnail != null && widget.post.thumbnail!.isNotEmpty
                  ? widget.post.thumbnail!
                  : (widget.post.user?.imageUrl ?? ''))
              : (widget.post.images != null && widget.post.images!.isNotEmpty
                  ? widget.post.images!.first
                  : ''),
          postDataType: widget.post.dataType,
        );
        FeedInteractionService.onPostCommented(widget.post, authProvider.loginUserData.id!);

        if (widget.post.user != null) {
          await _sendCommentNotification(receiverId, action, textComment);
        }
        await _sendMentionNotifications(textComment);
        authProvider.checkAndRefreshPostDates(widget.post.id!);
      }

      setState(() {
        replying = false;
        replyingTo = "";
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de l\'envoi'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addCommentLocally(PostComment newComment) {
    setState(() => comments.insert(0, newComment));
  }

  void _updateCommentLocally(PostComment updatedComment) {
    setState(() {
      final index = comments.indexWhere((c) => c.id == updatedComment.id);
      if (index != -1) comments[index] = updatedComment;
    });
  }

  Future<void> _sendCommentNotification(String receiverId, String action, String message) async {
    try {
      final msg = "@${authProvider.loginUserData.pseudo!} a $action";
      final notif = NotificationData(
        id: firestore.collection('Notifications').doc().id,
        titre: "Nouvelle interaction",
        media_url: authProvider.loginUserData.imageUrl,
        type: NotificationType.POST.name,
        description: msg,
        user_id: authProvider.loginUserData.id,
        receiver_id: receiverId,
        post_id: widget.post.id!,
        post_data_type: PostDataType.COMMENT.name,
        createdAt: DateTime.now().microsecondsSinceEpoch,
        updatedAt: DateTime.now().microsecondsSinceEpoch,
        status: PostStatus.VALIDE.name,
      );
      await firestore.collection('Notifications').doc(notif.id).set(notif.toJson());

      final receiverUser = await authProvider.getUserById(receiverId);
      if (receiverUser.isNotEmpty && receiverUser.first.oneIgnalUserid != null) {
        await authProvider.sendNotification(
          userIds: [receiverUser.first.oneIgnalUserid!],
          smallImage: authProvider.loginUserData.imageUrl!,
          send_user_id: authProvider.loginUserData.id!,
          recever_user_id: receiverId,
          message: msg,
          type_notif: NotificationType.POST.name,
          post_id: widget.post.id!,
          post_type: PostDataType.COMMENT.name,
          chat_id: '',
        );
      }
    } catch (_) {}
  }

  Future<void> _deleteComment(PostComment comment) async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('PostComments').doc(comment.id).delete();
      setState(() => comments.removeWhere((c) => c.id == comment.id));
      await FirebaseFirestore.instance
          .collection("Posts")
          .doc(widget.post.id)
          .update({"comments": FieldValue.increment(-1)});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Commentaire supprime'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _deleteResponse(PostComment parentComment, ResponsePostComment response) async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('PostComments')
          .doc(parentComment.id)
          .get();

      if (!doc.exists) throw Exception('Commentaire parent non trouve');

      final firebaseComment = PostComment.fromJson(doc.data() as Map<String, dynamic>);
      final initialCount = firebaseComment.responseComments?.length ?? 0;

      firebaseComment.responseComments?.removeWhere((r) {
        if (r.message != response.message) return false;
        if (r.user_id != response.user_id) return false;
        if (r.createdAt != null && response.createdAt != null && r.createdAt != response.createdAt) return false;
        if (r.user_pseudo != response.user_pseudo) return false;
        return true;
      });

      if (firebaseComment.responseComments?.length == initialCount) {
        throw Exception('Reponse non trouvee');
      }

      await FirebaseFirestore.instance.collection('PostComments').doc(parentComment.id).update({
        'responseComments': firebaseComment.responseComments != null
            ? firebaseComment.responseComments!.map((r) => r.toJson()).toList()
            : [],
      });

      setState(() {
        final parentIndex = comments.indexWhere((c) => c.id == parentComment.id);
        if (parentIndex != -1) comments[parentIndex] = firebaseComment;
      });

      await FirebaseFirestore.instance
          .collection("Posts")
          .doc(widget.post.id)
          .update({"comments": FieldValue.increment(-1)});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reponse supprimee'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);

    return Scaffold(
      backgroundColor: _colors.background,
      appBar: AppBar(
        backgroundColor: _colors.background,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        automaticallyImplyLeading: !widget.isInModal,
        leading: widget.isInModal
            ? const SizedBox.shrink()
            : IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: _colors.textPrimary, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).postCommentTitle,
              style: TextStyle(
                color: _colors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            if (comments.isNotEmpty)
              Text(
                '${comments.length} commentaire${comments.length > 1 ? 's' : ''}',
                style: TextStyle(color: _colors.textSecondary, fontSize: 11),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: _colors.textSecondary, size: 20),
            onPressed: _loadInitialComments,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: _colors.divider.withOpacity(0.4)),
        ),
      ),
      body: CenteredContent(
        maxWidth: AppLayout.isDesktop(context) ? 800 : AppLayout.maxFeedWidth,
        child: Column(
        children: [
          _buildPostHeader(),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (info) {
                if (info.metrics.pixels >= info.metrics.maxScrollExtent - 80) {
                  _loadMoreComments();
                }
                return false;
              },
              child: _isLoading && comments.isEmpty
                  ? Center(child: CircularProgressIndicator(color: _colors.primary, strokeWidth: 2))
                  : comments.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 8, bottom: 16),
                          itemCount: comments.length + (_hasMoreComments ? 1 : 0),
                          itemBuilder: (_, index) {
                            if (index == comments.length) {
                              return _isLoadingMore
                                  ? Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Center(
                                        child: CircularProgressIndicator(color: _colors.primary, strokeWidth: 2),
                                      ),
                                    )
                                  : const SizedBox.shrink();
                            }
                            return _buildCommentItem(comments[index]);
                          },
                        ),
            ),
          ),
          _buildCommentInput(),
        ],
      ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _colors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.chat_bubble_outline_rounded, size: 32, color: _colors.textSecondary),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).postCommentNoComment,
            style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'Soyez le premier a commenter !',
            style: TextStyle(color: _colors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
