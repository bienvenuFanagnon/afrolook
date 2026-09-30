import 'package:afrotok/pages/canaux/detailsCanal.dart';
import '../l10n/tr.dart';
import 'package:afrotok/widgets/comment_gift_sheet.dart';
import 'package:flutter/services.dart';
import 'package:afrotok/widgets/name_tag.dart';
import 'package:afrotok/widgets/pseudo_tag.dart';
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

import 'coins/post_gifts_list.dart';
import '../services/comment_coins.dart';
import '../widgets/post_coins_earned.dart';
import 'pub/afrolook_inline_ad.dart';
import '../services/stickers/sticker_models.dart';
import '../services/stickers/sticker_service.dart';
import 'stickers/sticker_picker_sheet.dart';
import 'stickers/sticker_recents_bar.dart';
import 'stickers/sticker_widgets.dart';
import 'package:afrotok/utils/responsive_sheet.dart';

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
  final int _commentsPageSize = 3;

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

  // Stickers (abonnés) : quotas du jour et derniers stickers utilisés.
  StickerAccess? _stickerAccess;
  List<StickerItem> _recentStickers = [];
  bool _stickerSending = false;
  StickerItem? _pendingSticker; // sticker choisi, en attente du texte facultatif et de l'envoi

  List<_GifterEntry> _topGifters = [];
  bool _giftersLoaded = false;

  // Stickers-cadeaux reçus, par commentaire (clé « commentId » ou « commentId|replyId »).
  Map<String, List<({String thumb, String url})>> _stickerGifts = {};

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);

    if (widget.initialComments.isNotEmpty) {
      comments = List.from(widget.initialComments);
      _loadUserDataForInitialComments();
    }
    _loadUsers();
    _loadInitialComments();
    _ensureCanalLoaded();
    _loadTopGifters();
    _loadStickerGifts();
    StickerService.instance.prefetchGiftStickers();
    _textController.addListener(_onTextChanged);
    if (_canUseStickers) _refreshStickerData();

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
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Abonné actif (Premium ou Gold) ou admin : le serveur tranche, l'app pré-vérifie.
  bool get _canUseStickers =>
      AbonnementUtils.isPremiumActive(authProvider.loginUserData.abonnement) ||
      authProvider.loginUserData.role == UserRole.ADM.name;

  /// Rafraîchit les quotas (`stickerAccess`) et les récents.
  Future<void> _refreshStickerData() async {
    final uid = authProvider.loginUserData.id;
    if (uid == null) return;
    final results = await Future.wait([
      StickerService.instance.fetchAccess(postId: widget.post.id),
      StickerService.instance.loadRecents(uid),
    ]);
    if (!mounted) return;
    setState(() {
      _stickerAccess = (results[0] as StickerAccess?) ?? _stickerAccess;
      _recentStickers = results[1] as List<StickerItem>;
    });
  }

  Future<void> _onStickerButtonTap() async {
    if (!_canUseStickers) {
      _focusNode.unfocus();
      await showStickerPremiumInvite(context);
      return;
    }
    _focusNode.unfocus();
    if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
    final picked = await showStickerPicker(
      context,
      userId: authProvider.loginUserData.id ?? '',
      postId: widget.post.id,
      initialAccess: _stickerAccess,
      initialRecents: _recentStickers,
    );
    if (picked != null && mounted) await _sendSticker(picked);
  }

  /// Un sticker choisi (sélecteur ou récents) reste en attente : l'utilisateur peut ajouter un texte, puis envoyer.
  Future<void> _sendSticker(StickerItem s) async {
    if (replying || _stickerSending || _isLoading) return;
    setState(() => _pendingSticker = s);
    _focusNode.requestFocus();
  }

  Future<void> _submit() async {
    final s = _pendingSticker;
    if (s == null) return _sendComment();
    if (replying || _stickerSending || _isLoading) return;
    _stickerSending = true;
    setState(() => _pendingSticker = null);
    try {
      await _sendComment(sticker: s);
    } finally {
      _stickerSending = false;
    }
    if (!mounted) return;
    _refreshStickerData();
    // Le trigger serveur met à jour quotas et récents avec un léger délai.
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _refreshStickerData();
    });
  }

  /// Stickers-cadeaux du post (`CommentGifts` avec `stickerId`) : une seule lecture, groupés par commentaire.
  Future<void> _loadStickerGifts() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('CommentGifts')
          .where('postId', isEqualTo: widget.post.id)
          .limit(300)
          .get();
      final docs = snap.docs.where((d) => (d.data()['stickerId'] ?? '').toString().isNotEmpty).toList()
        ..sort((a, b) {
          final x = (a.data()['createdAt'] as num?) ?? 0;
          final y = (b.data()['createdAt'] as num?) ?? 0;
          return x.compareTo(y);
        });
      final map = <String, List<({String thumb, String url})>>{};
      for (final d in docs) {
        final m = d.data();
        final url = (m['stickerUrl'] ?? '').toString();
        final thumb = (m['stickerThumbUrl'] ?? '').toString();
        if (url.isEmpty && thumb.isEmpty) continue;
        final cid = (m['commentId'] ?? '').toString();
        final rid = (m['replyId'] ?? '').toString();
        map.putIfAbsent(rid.isEmpty ? cid : '$cid|$rid', () => []).add((thumb: thumb.isNotEmpty ? thumb : url, url: url));
      }
      if (mounted) setState(() => _stickerGifts = map);
    } catch (e) {
      debugPrint('[Stickers] cadeaux de commentaires indisponibles: $e');
    }
  }

  /// « Offrir un sticker » : sélecteur ouvert sur les stickers-cadeaux, pour ce commentaire (ou cette réponse).
  Future<void> _offerSticker(String commentId, {String? replyId}) async {
    StickerService.instance.prefetchGiftStickers();
    _focusNode.unfocus();
    await showStickerPicker(
      context,
      userId: authProvider.loginUserData.id ?? '',
      postId: widget.post.id,
      giftTarget: StickerGiftTarget(commentId: commentId, replyId: replyId),
    );
    if (mounted) _loadStickerGifts();
  }

  /// Stickers-cadeaux reçus sous un commentaire ou une réponse, avec l'image du sticker.
  Widget _buildStickerGifts(String? commentId, {String? replyId}) {
    if (commentId == null) return const SizedBox.shrink();
    final list = _stickerGifts[replyId == null ? commentId : '$commentId|$replyId'];
    if (list == null || list.isEmpty) return const SizedBox.shrink();
    final gold = _colors.isDark ? const Color(0xFFF5C542) : const Color(0xFF8A5A00);
    final shown = list.length > 6 ? list.sublist(list.length - 6) : list;
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: gold.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: gold.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎁', style: TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Flexible(
              child: Wrap(
                spacing: 3,
                children: [
                  for (final g in shown)
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: Image.network(
                        g.thumb,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        errorBuilder: (_, __, ___) => Icon(Icons.card_giftcard_rounded, size: 16, color: gold),
                      ),
                    ),
                ],
              ),
            ),
            if (list.length > shown.length) ...[
              const SizedBox(width: 4),
              Text('+${list.length - shown.length}', style: TextStyle(color: gold, fontSize: 11, fontWeight: FontWeight.w800)),
            ],
          ],
        ),
      ),
    );
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

  void _ensureCanalLoaded() {
    final canalId = widget.post.canal_id;
    if (canalId == null || canalId.isEmpty || widget.post.canal != null) return;
    FirebaseFirestore.instance.collection('Canaux').doc(canalId).get().then((doc) {
      if (doc.exists && mounted) {
        setState(() => widget.post.canal = Canal.fromJson(doc.data()!));
      }
    }).catchError((_) {});
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
          // Like payant : 2 pièces (1 à l'auteur), une seule fois ; sans solde le like reste compté
          unawaited(CommentCoins.like(context,
              commentId: comment.id!, authorId: comment.user!.id!, authorPseudo: comment.user?.pseudo ?? ''));
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
          unawaited(CommentCoins.like(context,
              commentId: parentComment.id!, replyId: reply.id, authorId: reply.user_id!, authorPseudo: reply.user_pseudo ?? ''));
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

  /// Identifiants des utilisateurs cités (@pseudo) dans un message, sans doublon.
  Set<String> _mentionedUserIds(String message) {
    final ids = <String>{};
    for (final username in _extractMentionedUsers(message)) {
      final u = users.firstWhere((u) => u.pseudo == username, orElse: () => UserData());
      if (u.id != null) ids.add(u.id!);
    }
    return ids;
  }

  Future<void> _sendMentionNotifications(String message, {Set<String> alreadyNotified = const {}}) async {
    try {
      final done = <String>{...alreadyNotified};
      final mentionedUsers = _extractMentionedUsers(message);
      for (final username in mentionedUsers) {
        final user = users.firstWhere((u) => u.pseudo == username, orElse: () => UserData());
        if (user.id != null && user.id != authProvider.loginUserData.id && !done.contains(user.id)) {
          done.add(user.id!);
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

  // ─── TOP GIFTERS ─────────────────────────────────────────────────────────────

  Future<void> _loadTopGifters() async {
    if (widget.post.id == null) return;
    try {
      final snapshot = await firestore
          .collection('PostGifts')
          .where('postId', isEqualTo: widget.post.id!)
          .get();

      final Map<String, _GifterEntry> byUser = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final senderId = data['senderId'] as String?;
        if (senderId == null) continue;
        final coins = (data['coinsAmount'] as int?) ?? 0;
        final qty = (data['quantity'] as int?) ?? 1;
        final icon = (data['giftIcon'] as String?) ?? '🎁';
        final label = (data['giftLabel'] as String?) ?? 'Cadeau';
        final total = coins * qty;

        byUser.putIfAbsent(senderId, () => _GifterEntry(senderId: senderId));
        byUser[senderId]!.totalCoins += total;
        final existing = byUser[senderId]!.giftBreakdown.indexWhere(
            (g) => g.icon == icon && g.coins == coins);
        if (existing >= 0) {
          final old = byUser[senderId]!.giftBreakdown[existing];
          byUser[senderId]!.giftBreakdown[existing] =
              (icon: old.icon, label: old.label, qty: old.qty + qty, coins: old.coins);
        } else {
          byUser[senderId]!.giftBreakdown
              .add((icon: icon, label: label, qty: qty, coins: coins));
        }
      }

      final sorted = byUser.values.toList()
        ..sort((a, b) => b.totalCoins.compareTo(a.totalCoins));

      for (var entry in sorted.take(10)) {
        try {
          final userDoc =
              await firestore.collection('Users').doc(entry.senderId).get();
          if (userDoc.exists) entry.userData = UserData.fromJson(userDoc.data()!);
        } catch (_) {}
      }

      if (mounted) setState(() { _topGifters = sorted; _giftersLoaded = true; });
    } catch (_) {
      if (mounted) setState(() => _giftersLoaded = true);
    }
  }

  Widget _buildGiftersSection() {
    if (!_giftersLoaded || _topGifters.isEmpty) return const SizedBox.shrink();

    final medals = ['🥇', '🥈', '🥉'];
    // Affiche jusqu'à 5 dans la barre ; "Voir tous" ouvre le modal complet
    final visible = _topGifters.take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Label + Voir tous ──
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: Row(
            children: [
              Text('🏆 Top donateurs',
                  style: TextStyle(
                      color: _colors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: 0.2)),
              const Spacer(),
              if (_topGifters.length > 5)
                GestureDetector(
                  onTap: _showAllGifters,
                  child: Text('Voir tous',
                      style: TextStyle(
                          color: _colors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),

        // ── Chips compactes ──
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Row(
            children: visible.asMap().entries.map((e) {
              final i = e.key;
              final gifter = e.value;
              final rawPseudo = gifter.userData?.pseudo
                  ?? gifter.senderId.substring(0, 6);
              final pseudo = rawPseudo.length > 10
                  ? rawPseudo.substring(0, 9)
                  : rawPseudo;
              final avatar = gifter.userData?.imageUrl;
              final medal = i < 3 ? medals[i] : null;

              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: _showAllGifters,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: _colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _colors.border.withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Avatar
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(onBackgroundImageError: (avatar != null
                                  ? NetworkImage(avatar)
                                  : null) != null ? (Object _, StackTrace? __) {} : null, 
                              radius: 13,
                              backgroundColor: _colors.border,
                              backgroundImage: avatar != null
                                  ? NetworkImage(avatar)
                                  : null,
                              child: avatar == null
                                  ? Text(pseudo[0].toUpperCase(),
                                      style: TextStyle(
                                          color: _colors.textPrimary,
                                          fontSize: 10))
                                  : null,
                            ),
                            if (medal != null)
                              Positioned(
                                top: -5,
                                right: -5,
                                child: Text(medal,
                                    style: const TextStyle(fontSize: 10)),
                              ),
                          ],
                        ),
                        const SizedBox(width: 6),
                        // Pseudo
                        Text('@$pseudo',
                            style: TextStyle(
                                color: _colors.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 5),
                        // Pièces
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: _colors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_fmtCoins(gifter.totalCoins)} 🪙',
                            style: TextStyle(
                                color: _colors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        Divider(
            height: 1,
            indent: 14,
            endIndent: 14,
            color: _colors.divider.withOpacity(0.4)),
        const SizedBox(height: 4),
      ],
    );
  }

  String _fmtCoins(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  void _showAllGifters() {
    showResponsiveBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: _colors.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                  width: 36,
                  height: 3,
                  decoration: BoxDecoration(
                      color: _colors.border,
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text('🏆 Tous les donateurs',
                    style: TextStyle(
                        color: _colors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
              Divider(height: 1, color: _colors.divider),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: _topGifters.length,
                  itemBuilder: (_, i) {
                    final gifter = _topGifters[i];
                    final pseudo = gifter.userData?.pseudo ??
                        gifter.senderId.substring(0, 6);
                    final avatar = gifter.userData?.imageUrl;
                    final medals = ['🥇', '🥈', '🥉'];
                    return ListTile(
                      leading: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(onBackgroundImageError: (avatar != null
                                ? NetworkImage(avatar)
                                : null) != null ? (Object _, StackTrace? __) {} : null, 
                            radius: 20,
                            backgroundColor: _colors.border,
                            backgroundImage: avatar != null
                                ? NetworkImage(avatar)
                                : null,
                            child: avatar == null
                                ? Text(pseudo[0].toUpperCase(),
                                    style: TextStyle(
                                        color: _colors.textPrimary))
                                : null,
                          ),
                          if (i < 3)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Text(medals[i],
                                  style:
                                      const TextStyle(fontSize: 12)),
                            ),
                        ],
                      ),
                      title: Text('@$pseudo',
                          style: TextStyle(
                              color: _colors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      subtitle: Text(
                          gifter.giftBreakdown
                              .map((g) => '${g.icon}×${g.qty}')
                              .join(' '),
                          style: TextStyle(
                              color: _colors.textSecondary,
                              fontSize: 11)),
                      trailing: Text('${_fmtCoins(gifter.totalCoins)} 🪙',
                          style: TextStyle(
                              color: _colors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
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
                      child: CircleAvatar(onBackgroundImageError: (_, __) {}, 
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
                              NameTag(label: isCanal ? "#${post.canal!.titre!}" : "@${post.user!.pseudo!}",
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: _colors.textPrimary,
                                )),
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

    final isAutoGift = pcm.isAutoGiftComment == true;
    final needsExpandButton = !isAutoGift && textPainter.didExceedMaxLines;
    final isExpanded = isAutoGift || (_commentExpanded[pcm.id!] ?? false);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            if (pcm.canal_name != null) {
              _openCanalFromComment(canalId: pcm.canal_id, canalName: pcm.canal_name);
            } else {
              _openUserModal(pcm.user_id, pcm.user);
            }
          },
          child: CircleAvatar(onBackgroundImageError: (pcm.canal_name != null
                ? (pcm.canal_image != null && pcm.canal_image!.isNotEmpty
                    ? NetworkImage(pcm.canal_image!)
                    : null)
                : (pcm.user?.imageUrl != null && pcm.user!.imageUrl!.isNotEmpty
                    ? NetworkImage(pcm.user!.imageUrl!)
                    : null)) != null ? (Object _, StackTrace? __) {} : null, 
            radius: 18,
            backgroundColor: _colors.surfaceVariant,
            backgroundImage: pcm.canal_name != null
                ? (pcm.canal_image != null && pcm.canal_image!.isNotEmpty
                    ? NetworkImage(pcm.canal_image!)
                    : null)
                : (pcm.user?.imageUrl != null && pcm.user!.imageUrl!.isNotEmpty
                    ? NetworkImage(pcm.user!.imageUrl!)
                    : null),
            child: (pcm.canal_name != null
                    ? (pcm.canal_image == null || pcm.canal_image!.isEmpty)
                    : (pcm.user?.imageUrl == null || pcm.user!.imageUrl!.isEmpty))
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
                  Flexible(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (pcm.canal_name != null) {
                          _openCanalFromComment(canalId: pcm.canal_id, canalName: pcm.canal_name);
                        } else {
                          _openUserModal(pcm.user_id, pcm.user);
                        }
                      },
                      child: NameTag(label: pcm.canal_name != null
                            ? "#${pcm.canal_name}"
                            : "@${pcm.user?.pseudo ?? '...'}",
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _colors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (pcm.canal_name == null) UserBadgeWidget(user: pcm.user, size: 14),
                  if (pcm.isAutoGiftComment == true) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFD700).withOpacity(0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.4)),
                      ),
                      child: const Text('🎁 cadeau', style: TextStyle(fontSize: 10, color: Color(0xFFFFD700), fontWeight: FontWeight.w700)),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    formaterDateTime(DateTime.fromMicrosecondsSinceEpoch(pcm.createdAt!)),
                    style: TextStyle(color: _colors.textSecondary, fontSize: 11),
                  ),
                  const SizedBox(width: 4),
                  if (pcm.isAutoGiftComment != true)
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
              if (pcm.media != null) _buildCommentMedia(pcm.media!),
              if ((pcm.message ?? '').isNotEmpty || pcm.media == null)
                _buildMentionText(pcm.message ?? '', isExpanded: isExpanded, maxLinesReduced: 2),
              _buildCoinsEarned(pcm.coinsEarned),
              _buildStickerGifts(pcm.id),
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
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 4,
                children: [
                  _buildLikeButton(
                    isLiked: isLiked,
                    count: likeCount,
                    onTap: () => _likeComment(pcm),
                  ),
                  const SizedBox(width: 8),
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
                  if (pcm.user?.id != authProvider.loginUserData.id) ...[
                    const SizedBox(width: 16),
                    _buildActionButton(
                      icon: Icons.card_giftcard_rounded,
                      color: const Color(0xFFD99A00),
                      label: 'Cadeau',
                      onTap: () => showCommentGiftSheet(context,
                          commentId: pcm.id!, authorPseudo: pcm.user?.pseudo ?? ''),
                    ),
                    const SizedBox(width: 16),
                    _buildActionButton(
                      icon: Icons.sticky_note_2_outlined,
                      color: const Color(0xFFD99A00),
                      label: context.tr('Offrir un sticker'),
                      onTap: () => _offerSticker(pcm.id!),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Média d'un commentaire (sticker) : lecture seule, sans enregistrement, partage ni appui long.
  Widget _buildCommentMedia(Map<String, dynamic> media) {
    final url = (media['url'] ?? '').toString();
    final thumb = (media['thumbUrl'] ?? '').toString();
    if (url.isEmpty && thumb.isEmpty) return const SizedBox.shrink();
    final w = (media['w'] as num?)?.toDouble() ?? 1;
    final h = (media['h'] as num?)?.toDouble() ?? 1;
    final ratio = (w > 0 && h > 0) ? (w / h).clamp(0.5, 2.0).toDouble() : 1.0;

    Widget fallback() => Center(
          child: Icon(Icons.image_not_supported_outlined, size: 22, color: _colors.textSecondary),
        );
    Widget thumbImage() => thumb.isEmpty
        ? const SizedBox.shrink()
        : Image.network(thumb, fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, __, ___) => fallback());

    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 2),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 160),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: ratio,
            child: ColoredBox(
              color: _colors.surfaceVariant,
              child: url.isEmpty
                  ? thumbImage()
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      frameBuilder: (ctx, child, frame, sync) => (frame == null && !sync) ? thumbImage() : child,
                      errorBuilder: (_, __, ___) => thumb.isEmpty ? fallback() : thumbImage(),
                    ),
            ),
          ),
        ),
      ),
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
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onReplyAuthorTap(rpc),
            child: CircleAvatar(onBackgroundImageError: ((rpc.user_logo_url != null && rpc.user_logo_url!.isNotEmpty)
                ? NetworkImage(rpc.user_logo_url!)
                : null) != null ? (Object _, StackTrace? __) {} : null, 
            radius: 14,
            backgroundColor: _colors.surfaceVariant,
            backgroundImage: (rpc.user_logo_url != null && rpc.user_logo_url!.isNotEmpty)
                ? NetworkImage(rpc.user_logo_url!)
                : null,
            child: (rpc.user_logo_url == null || rpc.user_logo_url!.isEmpty)
                ? Icon(Icons.person, size: 12, color: _colors.textSecondary)
                : null,
          ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _onReplyAuthorTap(rpc),
                      child: NameTag(label: rpc.canal_name != null && rpc.canal_name!.isNotEmpty
                            ? "#${rpc.canal_name}"
                            : "@${rpc.user_pseudo ?? ''}",
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: _colors.textPrimary)),
                    ),
                    if (rpc.user_reply_pseudo != null && rpc.user_reply_pseudo!.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded, size: 9, color: _colors.textSecondary),
                      const SizedBox(width: 2),
                      PseudoTag(label: "@${rpc.user_reply_pseudo}",
                        style: TextStyle(color: _colors.textSecondary, fontSize: 11.5)),
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
                _buildCoinsEarned(pcm.replyCoins[rpc.id] ?? 0),
                _buildStickerGifts(pcm.id, replyId: rpc.id),
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
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 4,
                  children: [
                    _buildLikeButton(
                      isLiked: isLiked,
                      count: likeCount,
                      onTap: () => _likeReply(pcm, rpc),
                      small: true,
                    ),
                    const SizedBox(width: 6),
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
                    if (rpc.user_id != authProvider.loginUserData.id) ...[
                      const SizedBox(width: 14),
                      _buildActionButton(
                        icon: Icons.card_giftcard_rounded,
                        color: const Color(0xFFD99A00),
                        label: 'Cadeau',
                        small: true,
                        onTap: () => showCommentGiftSheet(context,
                            commentId: pcm.id!, replyId: rpc.id, authorPseudo: rpc.user_pseudo ?? ''),
                      ),
                      const SizedBox(width: 14),
                      _buildActionButton(
                        icon: Icons.sticky_note_2_outlined,
                        color: const Color(0xFFD99A00),
                        label: context.tr('Offrir un sticker'),
                        small: true,
                        onTap: () => _offerSticker(pcm.id!, replyId: rpc.id),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onReplyAuthorTap(ResponsePostComment rpc) {
    if (rpc.canal_name != null && rpc.canal_name!.isNotEmpty) {
      _openCanalFromComment(canalName: rpc.canal_name);
    } else {
      _openUserModal(rpc.user_id, rpc.user);
    }
  }

  /// Ouvre le canal quand le commentaire vient du profil canal (propriétaire du canal) : on n'affiche jamais
  /// le profil utilisateur de son propriétaire dans ce cas.
  Future<void> _openCanalFromComment({String? canalId, String? canalName}) async {
    try {
      final postCanal = widget.post.canal;
      Canal? canal;
      if (postCanal != null &&
          ((canalId != null && postCanal.id == canalId) ||
              (canalName != null && postCanal.titre == canalName))) {
        canal = postCanal;
      } else if (canalId != null && canalId.isNotEmpty) {
        final d = await FirebaseFirestore.instance.collection('Canaux').doc(canalId).get();
        if (d.exists) canal = Canal.fromJson(d.data()!);
      } else if (canalName != null && canalName.isNotEmpty) {
        final q = await FirebaseFirestore.instance.collection('Canaux').where('titre', isEqualTo: canalName).limit(1).get();
        if (q.docs.isNotEmpty) canal = Canal.fromJson(q.docs.first.data());
      }
      if (canal != null && mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => CanalDetails(canal: canal!)));
      }
    } catch (e) {
      debugPrint('Ouverture du canal : $e');
    }
  }

  /// Ouvre le modal de profil d'un utilisateur (charge le profil s'il manque).
  Future<void> _openUserModal(String? userId, UserData? user) async {
    try {
      var u = user;
      if (u == null && userId != null && userId.isNotEmpty) {
        final d = await FirebaseFirestore.instance.collection('Users').doc(userId).get();
        if (d.exists) u = UserData.fromJson(d.data()!);
      }
      if (u != null && mounted) {
        showUserDetailsModalDialog(u, MediaQuery.of(context).size.width, MediaQuery.of(context).size.height, context);
      }
    } catch (e) {
      debugPrint('Ouverture du profil : $e');
    }
  }

  /// Pièces reçues par l'auteur d'un commentaire ou d'une réponse (likes + cadeaux), affichées sous le texte.
  Widget _buildCoinsEarned(int coins) {
    if (coins <= 0) return const SizedBox.shrink();
    final gold = _colors.isDark ? const Color(0xFFF5C542) : const Color(0xFF8A5A00);
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: gold.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: gold.withOpacity(0.4)),
        ),
        child: Text(context.tr('🪙 {a} pièces reçues', {'a': coins}),
            style: TextStyle(color: gold, fontSize: 11, fontWeight: FontWeight.w800)),
      ),
    );
  }

  /// Bouton like des commentaires : grande zone de toucher, retour tactile, rebond du cœur.
  Widget _buildLikeButton({
    required bool isLiked,
    required int count,
    required VoidCallback onTap,
    bool small = false,
  }) {
    final size = small ? 22.0 : 26.0;
    return InkResponse(
      radius: 28,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          TweenAnimationBuilder<double>(
            key: ValueKey(isLiked),
            tween: Tween(begin: isLiked ? 1.6 : 1.0, end: 1.0),
            duration: const Duration(milliseconds: 380),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            // Même cœur que le like d'un post (avec la pastille « +1 »)
            child: LikeCoinHeart(
                icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isLiked ? _colors.danger : _colors.textSecondary,
                size: size),
          ),
          if (count > 0) ...[
            const SizedBox(width: 5),
            Text(formatNumber(count),
                style: TextStyle(color: isLiked ? _colors.danger : _colors.textSecondary, fontSize: small ? 12 : 13.5, fontWeight: FontWeight.w700)),
          ],
        ]),
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
              leading: CircleAvatar(onBackgroundImageError: ((user.imageUrl != null && user.imageUrl!.isNotEmpty)
                    ? NetworkImage(user.imageUrl!)
                    : null) != null ? (Object _, StackTrace? __) {} : null, 
                radius: 16,
                backgroundColor: _colors.surfaceVariant,
                backgroundImage: (user.imageUrl != null && user.imageUrl!.isNotEmpty)
                    ? NetworkImage(user.imageUrl!)
                    : null,
              ),
              title: PseudoTag(label: "@${user.pseudo!}", style: TextStyle(fontSize: 13, color: _colors.textPrimary)),
              onTap: () => _selectUser(user),
            );
          },
        ),
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

          // Stickers récents (abonnés)
          if (!replying && _canUseStickers && _recentStickers.isNotEmpty)
            StickerRecentsBar(
              recents: _recentStickers,
              access: _stickerAccess,
              onSend: _sendSticker,
            ),

          // Sticker en attente : aperçu + texte facultatif avant l'envoi
          if (_pendingSticker != null && !replying)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: _colors.primary.withOpacity(0.06),
              child: Row(
                children: [
                  StickerImage(sticker: _pendingSticker!, size: 56),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      context.tr('Ajoutez un texte (facultatif) puis appuyez sur envoyer'),
                      style: TextStyle(color: _colors.textSecondary, fontSize: 12.5),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _pendingSticker = null),
                    child: Icon(Icons.close_rounded, size: 20, color: _colors.textSecondary),
                  ),
                ],
              ),
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
                // Bouton sticker (pas en mode réponse)
                if (!replying)
                  GestureDetector(
                    onTap: _onStickerButtonTap,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8, right: 6),
                      child: SizedBox(
                        width: 28,
                        height: 26,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Icon(Icons.sticky_note_2_rounded, color: kStickerGold, size: 26),
                            if (!_canUseStickers)
                              const Positioned(right: -6, top: -7, child: StickerPremiumBadge()),
                          ],
                        ),
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
                  onTap: _submit,
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

  Future<void> _sendComment({StickerItem? sticker}) async {
    // Un sticker n'est jamais envoyé en mode réponse (commentaires principaux seulement).
    if (sticker != null && replying) return;
    if (sticker == null && _textController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    final textComment = _textController.text.trim();

    _textController.clear();
    _focusNode.unfocus();
    if (_showEmojiPicker) setState(() => _showEmojiPicker = false);

    try {
      bool success = false;
      String receiverId = '';
      String action = '';
      String? _canalName;
      String? _canalImage;

      if (replying) {
        // Même logique que pour les commentaires simples : si l'utilisateur est
        // owner/admin du canal auquel appartient le post, la réponse s'affiche
        // au nom du canal plutôt qu'au nom de la personne.
        String? _replyCanalName;
        String? _replyCanalImage;
        final replyUserId = authProvider.loginUserData.id;
        final replyCanal = widget.post.canal;
        final replyCanalId = widget.post.canal_id;
        if (replyCanalId != null && replyCanalId.isNotEmpty && replyCanal != null) {
          final isOwner = replyCanal.userId == replyUserId;
          final isAdmin = replyCanal.adminIds?.contains(replyUserId) == true;
          if (isOwner || isAdmin) {
            _replyCanalName = replyCanal.titre;
            _replyCanalImage = replyCanal.urlImage;
          }
        }

        final response = ResponsePostComment(
          user_id: replyUserId,
          user_logo_url: _replyCanalImage ?? authProvider.loginUserData.imageUrl,
          user_pseudo: _replyCanalName ?? authProvider.loginUserData.pseudo,
          post_comment_id: commentSelectedToReply.id,
          user_reply_pseudo: replyUser_pseudo,
          message: textComment,
          createdAt: DateTime.now().microsecondsSinceEpoch,
          updatedAt: DateTime.now().microsecondsSinceEpoch,
          canal_name: _replyCanalName,
          canal_image: _replyCanalImage,
        );
        commentSelectedToReply.responseComments ??= [];
        commentSelectedToReply.responseComments!.add(response);

        success = await postProvider.updateComment(commentSelectedToReply);
        receiverId = replyUser_id;
        action = "répondu à votre commentaire";

        if (success) {
          FeedInteractionService.onPostCommented(widget.post, authProvider.loginUserData.id!);
          _updateCommentLocally(commentSelectedToReply);
        }
      } else {
        // Identité canal : si le post appartient à un canal et que l'utilisateur
        // en est owner ou admin, le commentaire s'affiche au nom du canal.
        final userId = authProvider.loginUserData.id;
        final canal = widget.post.canal;
        final canalId = widget.post.canal_id;
        if (canalId != null && canalId.isNotEmpty && canal != null) {
          final isOwner = canal.userId == userId;
          final isAdmin = canal.adminIds?.contains(userId) == true;
          if (isOwner || isAdmin) {
            _canalName = canal.titre;
            _canalImage = canal.urlImage;
          }
        }

        final comment = PostComment(
          media: sticker?.toMedia(),
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
          canal_id: _canalName != null ? canalId : null,
          canal_name: _canalName,
          canal_image: _canalImage,
        );
        success = await postProvider.newComment(comment);
        if (widget.post.user != null) receiverId = widget.post.user!.id!;
        action = _canalName != null
            ? (sticker != null
                ? "Le canal #$_canalName a envoyé un sticker sur votre publication"
                : "Le canal #$_canalName a commenté votre publication")
            : (sticker != null ? "envoyé un sticker sur votre publication" : "commenté votre publication");
        if (success) {
          _addCommentLocally(comment);
          widget.post.comments = (widget.post.comments ?? 0) + 1;
          // Like automatique silencieux — commenter = intérêt garanti
          _autoLikeIfNeeded();
          // 2 pièces (1 au créateur) — publié même sans solde ; réponses gratuites
          CommentCoins.charge(context, widget.post).then((_) { if (mounted) setState(() {}); });
        }
      }

      // Notifications et effets secondaires isolés — une erreur ici ne doit
      // pas afficher de toast (le commentaire est déjà enregistré).
      if (success) {
        try {
          authProvider.incrementPostTotalInteractions(
            postId: widget.post.id!,
            userId: authProvider.loginUserData.id!,
            interactionType: 'comment',
          );
          await StreakService.onCommentSent(
            userId: authProvider.loginUserData.id!,
            postId: widget.post.id!,
          ).catchError((e) => debugPrint('[Streak] erreur onCommentSent: $e'));

          // Pour les posts de canal, utiliser l'image du canal comme contexte
          // visuel dans la notification aux abonnés.
          final isCanalPost = (widget.post.canal_id ?? '').isNotEmpty;
          final notifImageUrl = widget.post.type != PostDataType.IMAGE.name
              ? (widget.post.thumbnail?.isNotEmpty == true
                  ? widget.post.thumbnail!
                  : (widget.post.canal?.urlImage ?? widget.post.user?.imageUrl ?? ''))
              : (widget.post.images?.isNotEmpty == true
                  ? widget.post.images!.first
                  : '');
          final me = authProvider.loginUserData.id!;
          final isReply = replying;
          // Personnes déjà prévenues : jamais soi-même, jamais deux fois la même personne
          final notified = <String>{me};
          final mentionIds = _mentionedUserIds(textComment)..remove(me);
          if (!isReply) {
            // Les abonnés de l'auteur (sauf le propriétaire du post et les personnes citées, prévenus à part).
            // Une réponse à un commentaire ne prévient pas les abonnés.
            authProvider.notifySubscribersOfInteraction(
              actionUserId: me,
              postOwnerId: widget.post.user_id!,
              postId: widget.post.id!,
              actionType: 'comment',
              commentaireMessage: textComment,
              isSticker: sticker != null,
              excludeUserIds: [widget.post.user_id!, ...mentionIds],
              postDescription: widget.post.description,
              postImageUrl: notifImageUrl,
              postDataType: widget.post.dataType,
            );
            FeedInteractionService.onPostCommented(widget.post, me);
          }

          // Destinataire direct : le propriétaire du post (commentaire) ou l'auteur du commentaire (réponse)
          if (receiverId.isNotEmpty && !notified.contains(receiverId)) {
            notified.add(receiverId);
            await _sendCommentNotification(
              receiverId, action, textComment,
              displayName: isReply
                  ? null
                  : (_canalName != null
                      ? '#$_canalName'
                      : (isCanalPost && widget.post.canal?.titre != null
                          ? '#${widget.post.canal!.titre}'
                          : null)),
              displayImage: isReply
                  ? null
                  : (_canalImage ?? (isCanalPost ? widget.post.canal?.urlImage : null)),
            );
          }
          await _sendMentionNotifications(textComment, alreadyNotified: notified);
          authProvider.checkAndRefreshPostDates(widget.post.id!);
        } catch (e) {
          debugPrint('[Comments] notification error: $e');
        }
      }

      setState(() {
        replying = false;
        replyingTo = "";
        _isLoading = false;
      });
    } catch (_) {
      // Seul l'échec réel d'envoi (postProvider.newComment / updateComment)
      // affiche un toast d'erreur.
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

  void _autoLikeIfNeeded() {
    final uid = authProvider.loginUserData.id;
    final postId = widget.post.id;
    if (uid == null || postId == null) return;
    final alreadyLiked = widget.post.users_love_id?.contains(uid) ?? false;
    if (alreadyLiked) return;
    // Like silencieux sans notification ni paiement
    FirebaseFirestore.instance.collection('Posts').doc(postId).update({
      'loves': FieldValue.increment(1),
      'users_love_id': FieldValue.arrayUnion([uid]),
    }).catchError((_) {});
    widget.post.users_love_id ??= [];
    widget.post.users_love_id!.add(uid);
    widget.post.loves = (widget.post.loves ?? 0) + 1;
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

  Future<void> _sendCommentNotification(
    String receiverId,
    String action,
    String message, {
    String? displayName,
    String? displayImage,
  }) async {
    try {
      final name = displayName ?? "@${authProvider.loginUserData.pseudo!}";
      final image = displayImage ?? authProvider.loginUserData.imageUrl ?? '';
      final msg = displayName != null ? action : "$name a $action";
      final notif = NotificationData(
        id: firestore.collection('Notifications').doc().id,
        titre: "Nouvelle interaction",
        media_url: image,
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
          smallImage: image,
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
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: CenteredContent(
        maxWidth: AppLayout.isDesktop(context) ? 800 : AppLayout.maxFeedWidth,
        child: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildPostHeader()),
                // Ce que le post a rapporté au créateur (likes + commentaires + cadeaux)
                SliverToBoxAdapter(
                  child: PostCoinsBanner(
                    post: widget.post,
                    margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                  ),
                ),
                SliverToBoxAdapter(child: _buildGiftersSection()),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: AfrolookInlineAd(compact: true),
                  ),
                ),
                if (_isLoading && comments.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(
                          color: _colors.primary, strokeWidth: 2),
                    ),
                  )
                else if (comments.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.only(top: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, index) => _buildCommentItem(comments[index]),
                        childCount: comments.length,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _hasMoreComments
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: _isLoadingMore
                                  ? SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                          color: _colors.primary,
                                          strokeWidth: 2),
                                    )
                                  : OutlinedButton.icon(
                                      onPressed: _loadMoreComments,
                                      icon: Icon(Icons.expand_more_rounded,
                                          size: 18, color: _colors.primary),
                                      label: Text(
                                        'Voir plus de commentaires',
                                        style: TextStyle(
                                            color: _colors.primary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                            color: _colors.primary
                                                .withOpacity(0.4)),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20)),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 10),
                                      ),
                                    ),
                            ),
                          )
                        : const SizedBox(height: 16),
                  ),
                ],
              ],
            ),
          ),
          _buildCommentInput(),
        ],
      ),
      ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
      ),
    );
  }
}

// ─── Gifter data holder ───────────────────────────────────────────────────────

class _GifterEntry {
  final String senderId;
  int totalCoins = 0;
  UserData? userData;
  List<({String icon, String label, int qty, int coins})> giftBreakdown = [];

  _GifterEntry({required this.senderId});
}
