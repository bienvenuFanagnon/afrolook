import '../ads/ad_slot.dart';
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
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/canal_mapper.dart';
import 'package:afrotok/services/api/posts_api.dart';
import 'package:afrotok/services/api/users_api.dart';
import 'package:afrotok/services/api/users_mapper.dart';
import 'package:afrotok/widgets/api_error_dialogs.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/authProvider.dart';
import '../providers/userProvider.dart';
import '../services/utils/abonnement_utils.dart';
import '../widgets/user_badge_widget.dart';
import '../theme/app_colors.dart';
import '../l10n/app_localizations.dart';
import 'dart:async';
import 'dart:ui' as ui;

import '../services/comment_coins.dart';
import '../services/comments_prefetch.dart';
import '../widgets/post_coins_earned.dart';
import 'pub/afrolook_inline_ad.dart';
import '../services/stickers/sticker_models.dart';
import '../services/stickers/sticker_service.dart';
import 'stickers/sticker_picker_sheet.dart';
import 'stickers/sticker_recents_bar.dart';
import 'stickers/sticker_widgets.dart';
import 'package:afrotok/utils/responsive_sheet.dart';
import 'userPosts/postWidgets/translatable_comment.dart';

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

  String? _lastCommentDocument;   // curseur de la page suivante (API)
  final int _commentsPageSize = CommentsPrefetch.pageSize;
  // Page suivante lue en avance : « Voir plus » l'affiche aussitôt, puis la suivante se prépare
  Future<CommentPage>? _readAhead;
  String? _readAheadAfterId;

  final Map<String, bool> _commentExpanded = {};
  final Map<String, bool> _replyExpanded = {};
  final Map<String, bool> _showAllReplies = {};
  final Map<String, String?> _translatedComments = {};
  final Map<String, String?> _translatedReplies = {};

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

    final postId = widget.post.id;
    final cached = postId == null ? null : CommentsPrefetch.instance.peek(postId);
    if (cached != null) {
      // Premiers commentaires déjà prêts (cherchés quand le post s'est affiché) : affichage immédiat, sans attente
      comments = List.from(cached.comments);
      _lastCommentDocument = cached.last;
      _hasMoreComments = cached.hasMore;
      _loadUserDataForInitialComments();
      _startReadAhead();
    } else {
      if (widget.initialComments.isNotEmpty) {
        comments = List.from(widget.initialComments);
        _loadUserDataForInitialComments();
      }
      _loadInitialComments();
    }
    _loadUsers();
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
  bool get _canUseStickers {
    final u = authProvider.loginUserData;
    if (AbonnementUtils.isPremiumActive(u.abonnement) || u.role == UserRole.ADM.name) return true;
    // Stickers offerts par les pubs : le quota exact vient du serveur (stickerAccess), à défaut du profil
    return (_stickerAccess?.bonusRemaining ?? AbonnementUtils.stickerBonusToday(u)) > 0;
  }

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
    if (_stickerSending || _isLoading) return;
    setState(() => _pendingSticker = s);
    _focusNode.requestFocus();
  }

  Future<void> _submit() async {
    final s = _pendingSticker;
    if (s == null) return _sendComment();
    if (_stickerSending || _isLoading) return;
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

  /// Stickers-cadeaux du post : l'API ne les expose pas encore en lecture (voir lacunes_api_publications.md) ; rien n'est affiché en attendant.
  Future<void> _loadStickerGifts() async {}

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
    ApiGateway.instance.client.get('/channels/$canalId').then((r) {
      final d = (r as Map)['data'];
      if (d is Map && mounted) setState(() => widget.post.canal = canalFromApi(Map<String, dynamic>.from(d)));
    }).catchError((_) {});
  }

  Future<void> _loadUsers() async {
    final usersList = await userProvider.getUserAbonnes(authProvider.loginUserData.id!);
    setState(() => users = usersList);
  }

  Future<void> _loadInitialComments({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh && widget.post.id != null) CommentsPrefetch.instance.invalidate(widget.post.id!);
    setState(() {
      _isLoading = true;
      if (refresh) comments = [];
      _lastCommentDocument = null;
      _hasMoreComments = true;
      _readAhead = null;
    });
    try {
      await _loadCommentsBatch();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMoreComments() async {
    if (_isLoadingMore || !_hasMoreComments) return;
    setState(() => _isLoadingMore = true);
    try {
      // Les commentaires déjà affichés (reçus avant la page) peuvent remplir une page entière : on enchaîne jusqu'à en trouver de nouveaux
      for (var tries = 0; tries < 4 && _hasMoreComments; tries++) {
        final added = await _loadCommentsBatch();
        if (added > 0) break;
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  /// Lit en avance la page qui suivra, pour que « Voir plus » soit instantané.
  void _startReadAhead() {
    final postId = widget.post.id;
    final after = _lastCommentDocument;
    if (postId == null || after == null || !_hasMoreComments) return;
    _readAheadAfterId = after;
    final f = CommentsPrefetch.instance.loadPage(postId, after: after, limit: _commentsPageSize);
    f.then((_) {}, onError: (_) {});
    _readAhead = f;
  }

  /// Charge une page de commentaires ; renvoie combien de nouveaux commentaires ont été ajoutés à la liste.
  Future<int> _loadCommentsBatch() async {
    final postId = widget.post.id;
    if (postId == null) {
      if (mounted) setState(() { _hasMoreComments = false; _isLoading = false; });
      return 0;
    }
    CommentPage page;
    final ahead = _readAhead;
    if (ahead != null && _lastCommentDocument != null && _readAheadAfterId == _lastCommentDocument) {
      _readAhead = null;
      try {
        page = await ahead;
      } catch (_) {
        page = await CommentsPrefetch.instance.loadPage(postId, after: _lastCommentDocument, limit: _commentsPageSize);
      }
    } else {
      page = await CommentsPrefetch.instance.loadPage(postId, after: _lastCommentDocument, limit: _commentsPageSize);
    }
    if (!mounted) return 0;

    if (page.comments.isEmpty) {
      setState(() {
        _hasMoreComments = false;
        _isLoading = false;
      });
      return 0;
    }

    _lastCommentDocument = page.last;

    // Dédupliquer avec les commentaires déjà affichés (reçus avant la page)
    final existingIds = comments.map((c) => c.id).toSet();
    final deduplicated = page.comments.where((c) => !existingIds.contains(c.id)).toList();

    setState(() {
      comments.addAll(deduplicated);
      _hasMoreComments = page.hasMore;
      _isLoading = false;
    });
    _startReadAhead();
    return deduplicated.length;
  }


  Future<void> _loadUserDataForInitialComments() async {
    await CommentsPrefetch.instance.fillAuthors(comments);
    if (!mounted) return;
    setState(() {});
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
    final userId = authProvider.loginUserData.id!;
    final isLiked = comment.users_like_id?.contains(userId) ?? false;
    // Affichage immédiat, annulé si l'API refuse
    setState(() {
      if (isLiked) {
        comment.users_like_id?.remove(userId);
        comment.likes = (comment.likes ?? 1) - 1;
      } else {
        (comment.users_like_id ??= []).add(userId);
        comment.likes = (comment.likes ?? 0) + 1;
      }
    });
    try {
      if (isLiked) {
        await CommentsApi.unlike(comment.id!);
      } else {
        final r = await CommentsApi.like(comment.id!);
        if (comment.user?.id != userId && mounted) {
          unawaited(CommentCoins.afterLike(context, r, authorPseudo: comment.user?.pseudo ?? ''));
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (isLiked) {
          (comment.users_like_id ??= []).add(userId);
          comment.likes = (comment.likes ?? 0) + 1;
        } else {
          comment.users_like_id?.remove(userId);
          comment.likes = (comment.likes ?? 1) - 1;
        }
      });
      showApiError(context, e);
    }
  }

  Future<void> _likeReply(PostComment parentComment, ResponsePostComment reply) async {
    final userId = authProvider.loginUserData.id!;
    final isLiked = reply.users_like_id?.contains(userId) ?? false;
    setState(() {
      if (isLiked) {
        reply.users_like_id?.remove(userId);
        reply.likes = (reply.likes ?? 1) - 1;
      } else {
        (reply.users_like_id ??= []).add(userId);
        reply.likes = (reply.likes ?? 0) + 1;
      }
    });
    try {
      if (isLiked) {
        await CommentsApi.unlike(reply.id!);
      } else {
        final r = await CommentsApi.like(reply.id!);
        if (reply.user_id != userId && mounted) {
          unawaited(CommentCoins.afterLike(context, r, authorPseudo: reply.user_pseudo ?? ''));
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (isLiked) {
          (reply.users_like_id ??= []).add(userId);
          reply.likes = (reply.likes ?? 0) + 1;
        } else {
          reply.users_like_id?.remove(userId);
          reply.likes = (reply.likes ?? 1) - 1;
        }
      });
      showApiError(context, e);
    }
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

  /// Classement des donateurs : l'API ne l'expose pas encore (voir lacunes_api_publications.md).
  Future<void> _loadTopGifters() async {
    if (mounted) setState(() => _giftersLoaded = true);
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
                _buildMentionText(_translatedComments[pcm.id!] ?? pcm.message ?? '', isExpanded: isExpanded, maxLinesReduced: 2),
              if ((pcm.message ?? '').trim().isNotEmpty)
                TranslatableComment(
                  commentId: pcm.id!,
                  text: pcm.message!,
                  targetLang: Localizations.localeOf(context).languageCode,
                  onToggle: (t) => setState(() => _translatedComments[pcm.id!] = t),
                ),
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
  Widget _buildCommentMedia(Map<String, dynamic> media, {double maxWidth = 110}) {
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
        constraints: BoxConstraints(maxWidth: maxWidth),
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
                // Sticker d'une réponse : plus petit que dans un commentaire
                if (rpc.media != null) _buildCommentMedia(rpc.media!, maxWidth: 72),
                if ((rpc.message ?? '').isNotEmpty || rpc.media == null)
                  _buildMentionText(_translatedReplies['${pcm.id}_${rpc.id}'] ?? rpc.message ?? '', isExpanded: isExpanded, maxLinesReduced: 2),
                if ((rpc.message ?? '').trim().isNotEmpty)
                  TranslatableComment(
                    commentId: pcm.id!,
                    text: rpc.message!,
                    targetLang: Localizations.localeOf(context).languageCode,
                    replyId: rpc.id,
                    onToggle: (t) => setState(() => _translatedReplies['${pcm.id}_${rpc.id}'] = t),
                  ),
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
        final r = await ApiGateway.instance.client.get('/channels/$canalId');
        final d = (r as Map)['data'];
        if (d is Map) canal = canalFromApi(Map<String, dynamic>.from(d));
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
      // L'API fournit pseudo et avatar avec chaque commentaire ; le profil complet n'a pas de route de lecture (voir lacunes_api_publications.md).
      var u = user;
      if (userId != null && userId.isNotEmpty) {
        try {
          u = userFromApi(await UsersApi.publicProfile(userId));
        } catch (_) {/* on garde pseudo et avatar fournis avec le commentaire */}
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
          if (_canUseStickers && _recentStickers.isNotEmpty)
            StickerRecentsBar(
              recents: _recentStickers,
              access: _stickerAccess,
              onSend: _sendSticker,
            ),

          // Sticker en attente : aperçu + texte facultatif avant l'envoi
          if (_pendingSticker != null)
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
                // Bouton sticker (commentaire et réponse)
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
    if (sticker == null && _textController.text.trim().isEmpty) return;
    final postId = widget.post.id;
    if (postId == null) return;

    final textComment = _textController.text.trim();
    final replyTo = replying ? commentSelectedToReply : null;
    final replyPseudo = replyUser_pseudo;
    setState(() => _isLoading = true);

    try {
      // Quota : 10 gratuits par publication, puis 1 pièce (le serveur débite ; erreur 402 si le solde manque)
      final sent = await CommentsApi.send(
        postId,
        body: textComment.isEmpty ? null : textComment,
        parentId: replyTo?.id,
        sticker: sticker == null ? null : {'id': sticker.id, 'source': sticker.source},
      );
      // Succès : on vide la saisie seulement maintenant (en cas d'erreur le texte reste, pour réessayer)
      _textController.clear();
      _focusNode.unfocus();
      if (_showEmojiPicker) _showEmojiPicker = false;

      if (replyTo != null) {
        final reply = sent.reply..user_reply_pseudo = replyPseudo;
        replyTo.responseComments ??= [];
        replyTo.responseComments!.add(reply);
        replyTo.comments = (replyTo.comments ?? 0) + 1;
        _updateCommentLocally(replyTo);
      } else {
        final comment = sent.comment..user = authProvider.loginUserData;
        _addCommentLocally(comment);
        widget.post.comments = (widget.post.comments ?? 0) + 1;
      }
      if (sent.paidCoins > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Commentaire envoyé : ${sent.paidCoins} pièce débitée.'), duration: const Duration(seconds: 2)),
        );
      }
      // Notifications, série, goûts du fil : gérés par le serveur à l'envoi du commentaire.
      setState(() {
        replying = false;
        replyingTo = '';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      handleApiError(context, e, onRetry: () => _sendComment(sticker: sticker), fallback: "Erreur lors de l'envoi");
    }
  }

  void _addCommentLocally(PostComment newComment) {
    setState(() => comments.insert(0, newComment));
    if (widget.post.id != null) CommentsPrefetch.instance.addLocal(widget.post.id!, newComment);
  }

  void _updateCommentLocally(PostComment updatedComment) {
    setState(() {
      final index = comments.indexWhere((c) => c.id == updatedComment.id);
      if (index != -1) comments[index] = updatedComment;
    });
  }

  Future<void> _deleteComment(PostComment comment) async {
    setState(() => _isLoading = true);
    try {
      await CommentsApi.delete(comment.id!);
      setState(() => comments.removeWhere((c) => c.id == comment.id));
      if (widget.post.id != null) CommentsPrefetch.instance.invalidate(widget.post.id!);
      widget.post.comments = ((widget.post.comments ?? 1) - 1).clamp(0, 1 << 31);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Commentaire supprimé'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) showApiError(context, e, onRetry: () => _deleteComment(comment));
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _deleteResponse(PostComment parentComment, ResponsePostComment response) async {
    setState(() => _isLoading = true);
    try {
      await CommentsApi.delete(response.id!);
      setState(() {
        parentComment.responseComments?.removeWhere((r) => r.id == response.id);
        parentComment.comments = ((parentComment.comments ?? 1) - 1).clamp(0, 1 << 31);
      });
      if (widget.post.id != null) CommentsPrefetch.instance.invalidate(widget.post.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réponse supprimée'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) showApiError(context, e, onRetry: () => _deleteResponse(parentComment, response));
    }
    if (mounted) setState(() => _isLoading = false);
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
            onPressed: () => _loadInitialComments(refresh: true),
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
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: AdSlot(key: const ValueKey('comments_ad_top'), kind: AdSlotKind.comments, own: () => const AfrolookInlineAd(compact: true)),
                  ),
                ),
                if (!_isLoading && comments.isEmpty)
                  SliverToBoxAdapter(
                    child: AdSlot(
                      key: const ValueKey('comments_ad_empty'),
                      kind: AdSlotKind.comments,
                      own: () => const SizedBox.shrink(),
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
                    sliver: Builder(builder: (_) {
                      // Une pub en haut de la page, puis une après le 3e commentaire, ensuite toutes les 10 (rien avant : pas de pub collée à 2 commentaires)
                      final adAfter = <int>{for (var i = 2; i < comments.length; i += 10) i};
                      final entries = <int>[
                        for (var i = 0; i < comments.length; i++) ...[i, if (adAfter.contains(i)) -1]
                      ];
                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, index) {
                            final e = entries[index];
                            if (e < 0) {
                              return AdSlot(
                                key: ValueKey('comments_ad_$index'),
                                kind: AdSlotKind.comments,
                                own: () => const AfrolookInlineAd(compact: true),
                              );
                            }
                            return _buildCommentItem(comments[e]);
                          },
                          childCount: entries.length,
                        ),
                      );
                    }),
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
