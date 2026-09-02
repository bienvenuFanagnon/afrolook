import 'package:afrotok/utils/responsive_sheet.dart';
import 'package:afrotok/pages/user/userPubs/user_create_advertisement_page.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'dart:math';

import 'package:afrotok/pages/user/monetisation.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:hashtagable_v3/widgets/hashtag_text.dart';

import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:flutter_animate/flutter_animate.dart';

import '../../../models/model_data.dart';
import '../../../theme/app_colors.dart';
import '../../../providers/locale_provider.dart';
import '../../../l10n/app_localizations.dart';
import 'translatable_description.dart';

import '../../../providers/coin_gift_provider.dart';
import '../../../providers/sound_provider.dart';
import '../../../services/linkService.dart';
import '../../../services/utils/abonnement_utils.dart';
import '../../../widgets/user_badge_widget.dart';
import '../../coins/coin_gift_dialog.dart';
import '../../coins/coin_recharge_screen.dart';
import '../../../widgets/gifts/quick_gift_bar.dart';
import '../../coins/post_gifts_list.dart';
import '../../component/consoleWidget.dart';
import '../../home/homeWidget.dart';
import '../../home/user_presence_widget.dart';
import '../../paiement/newDepot.dart';
import '../../postComments.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/postProvider.dart';
import '../../../providers/userProvider.dart';
import '../../canaux/detailsCanal.dart';

import '../../component/showUserDetails.dart';
import '../../postComments.dart';
import '../../postDetails.dart';
import '../../postDetailsVideo.dart';
import '../../pub/afrolook_inline_ad.dart';
import '../../pub/rewarded_ad_widget.dart';
import '../../widgetGlobal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../youTube_video_card.dart';
import 'audioPostWidget.dart';
import '../../../services/postService/post_view_service.dart';
import '../../../services/postService/feed_interaction_service.dart';
import '../../../services/streak_service.dart';
import '../../../providers/streakProvider.dart';



class HomePostUsersWidget extends StatefulWidget {
  late Post post;
  late Color? color;
  final double height;
  final double width;
   late int index;
  final bool isDegrade;
  bool isPreview;
  final Function(Post, VisibilityInfo)? onVisibilityChanged;

  // 🔥 NOUVEAUX CALLBACKS POUR LES INTERACTIONS
  final VoidCallback? onLiked;
  final VoidCallback? onCommented;
  final VoidCallback? onShared;
  final VoidCallback? onLoved;
  final VoidCallback? onViewed;
  // Session 13 : pays du filtre actif (HomeConstPost._selectedCountryCode), utilisé pour
  // afficher en priorité ce pays dans le badge pays du post (s'il y figure).
  final String? currentFilterCountry;
  final bool isAdContext;
  final bool suppressInlineAd;

  HomePostUsersWidget({
    required this.post,
    this.color,
    this.isDegrade = false,
    required this.height,
    required this.width,
    Key? key,
    this.isPreview = true,
    this.onVisibilityChanged,
    this.onLiked,
    this.onCommented,
    this.onShared,
    this.onLoved,
    this.onViewed,
    this.index=0,
    this.currentFilterCountry,
    this.isAdContext = false,
    this.suppressInlineAd = false,
  }) : super(key: key);

  @override
  _HomePostUsersWidgetState createState() => _HomePostUsersWidgetState();
}

class _HomePostUsersWidgetState extends State<HomePostUsersWidget>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  bool _isExpanded = false;
  bool _isSharing = false;
  String? _translatedDescription;
  late UserAuthProvider authProvider;
  late CoinGiftUserProvider _coinProvider;

  late PostProvider postProvider;
  late UserProvider userProvider;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool _isFavorite = false;
  bool _isProcessingFavorite = false;
  Random random = Random();
  bool _isLoading = false;
  bool _isProcessingFollow = false;
  final GlobalKey<RewardedAdWidgetState> _rewardedAdKey = GlobalKey();
  bool _showRewardedAd = false;
  bool _isSupporting = false;
  bool? _hasSeenSupportModal; // null = pas encore chargé
  // Variables pour stocker les données récupérées individuellement
  UserData? _currentUser;
  Canal? _currentCanal;
  bool _isLoadingUser = false;
  bool _isLoadingCanal = false;
  bool _isLiking = false;
  // État local du like — résistant aux rebuilds du parent qui remplace widget.post
  // depuis le cache stale (FeedCacheService). L'état local persiste tant que
  // le même State est réutilisé par Flutter (garanti par ValueKey dans le parent).
  bool _isLikedLocally = false;
  int _localLovesCount = 0;
  int _localCommentsCount = 0;
  List<PostComment> _preloadedComments = [];
  bool _isLoadingComment = false;
  final TextEditingController _quickCommentController = TextEditingController();
  bool _isSendingQuickComment = false;

  // Variables pour la thumbnail vidéo
  String? _videoThumbnailPath;
  bool _isGeneratingThumbnail = false;

  // Preview vidéo 5 secondes dans le feed
  bool _isPreviewPlaying = false;
  bool _showPreviewCta = false;
  VideoPlayerController? _previewController;
  Timer? _previewTimer;
  bool _showCanalLockCta = false;
  bool get _shouldShowAd {
    // 1 pub tous les 5 posts
    return (widget.index + 1) % 5 == 0;
  }
  // CONFIGURATION - Paiement pour abonnés existants
  final bool _requirePaymentForExistingSubscribers = false;
  // Dans _HomePostUsersWidgetState
  Widget _buildEventBadge(Post post) {


    if (post.typeTabbar != 'EVENEMENT' || post.eventDate == null) return SizedBox.shrink();
    printVm("eventDate : ${post.eventDate!}");
    final eventDateTime = DateTime.fromMillisecondsSinceEpoch(post.eventDate!);
    final now = DateTime.now();
    final difference = eventDateTime.difference(now).inDays;

    final colors = AppColors.of(context);
    String badgeText = '';
    Color badgeColor = colors.danger;

    if (difference < 0) {
      badgeText = '📅 PASSÉ';
      badgeColor = colors.textSecondary;
    } else if (difference == 0) {
      badgeText = '🔴 AUJOURD\'HUI';
      badgeColor = colors.danger;
    } else if (difference == 1) {
      badgeText = '⭐ DEMAIN';
      badgeColor = colors.warning;
    } else if (difference <= 7) {
      badgeText = '📅 DANS $difference JOURS';
      badgeColor = colors.danger;
    } else {
      badgeText = '📅 À VENIR';
      badgeColor = colors.info;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4),
        ],
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }


  // Vérifier si l'utilisateur a déjà soutenu ce post aujourd'hui
  Future<bool> _hasSupportedToday(String postId, String userId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endOfDay = startOfDay + Duration(days: 1).inMilliseconds;

    final query = await firestore
        .collection('post_supports')
        .where('postId', isEqualTo: postId)
        .where('userId', isEqualTo: userId)
        .where('supportedAt', isGreaterThanOrEqualTo: startOfDay)
        .where('supportedAt', isLessThan: endOfDay)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

// Enregistrer le soutien
  Future<void> _recordSupport(String postId, String userId) async {
    final support = PostSupport(
      id: firestore.collection('post_supports').doc().id,
      postId: postId,
      userId: userId,
      supportedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await firestore.collection('post_supports').doc(support.id).set(support.toJson());
  }

  Future<void> recordUniquePostView() async {

     String userId = authProvider.loginUserData.id!;
     String postId = widget.post.id!;
    try {
      final postRef = FirebaseFirestore.instance.collection('Posts').doc(postId);

      final postDoc = await postRef.get();

      if (!postDoc.exists) return;

      List usersViewed = postDoc.data()?['users_vue_id'] ?? [];

      // Vérifier si l'utilisateur a déjà vu
      if (usersViewed.contains(userId)) {
        printVm("⏭️ L'utilisateur a déjà vu ce post");
        return;
      }

      // Enregistrer la vue
      await postRef.update({
        'vues': FieldValue.increment(1),
        'users_vue_id': FieldValue.arrayUnion([userId]),
      });

      PostViewService.recordAuthorView(widget.post, userId);
      printVm("✅ Vue enregistrée pour $userId");

    } catch (e) {
      printVm("Erreur enregistrement vue : $e");
    }
  }

// Nettoyer les ressources audio quand le widget est détruit
  // 🔥 S'assurer d'avoir authProvider et appDefaultData
  late AppDefaultData appDefaultData;
  @override
  void initState() {
    super.initState();
    printVm("index du post: ${widget.index}");
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);

    postProvider = Provider.of<PostProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    appDefaultData = authProvider.appDefaultData;
    _initLikeState();
    _loadUserData();
    _loadCanalData();
    _generateVideoThumbnail();

    _checkIfFavorite();
    _loadSupportModalSeen();
    _loadLastComment();
  }


  void _initLikeState() {
    final userId = authProvider.loginUserData.id;
    _isLikedLocally = widget.post.users_love_id?.contains(userId) ?? false;
    _localLovesCount = widget.post.loves ?? 0;
    _localCommentsCount = widget.post.comments ?? 0;
  }

  @override
  void didUpdateWidget(HomePostUsersWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post.id != oldWidget.post.id) {
      _initLikeState();
    } else if (!_isLiking) {
      final userId = authProvider.loginUserData.id;
      final onlineLiked = widget.post.users_love_id?.contains(userId) ?? false;
      final onlineCount = widget.post.loves ?? 0;
      final onlineComments = widget.post.comments ?? 0;
      setState(() {
        // Ne jamais rétrograder l'état optimiste local depuis un cache stale.
        // On sync seulement si la donnée en ligne est cohérente ou clairement plus récente.
        if (onlineLiked == _isLikedLocally) {
          _localLovesCount = onlineCount;
        } else if (onlineCount > _localLovesCount) {
          _isLikedLocally = onlineLiked;
          _localLovesCount = onlineCount;
        }
        if (onlineComments > _localCommentsCount) _localCommentsCount = onlineComments;
      });
    }
  }

  // Méthode utilitaire pour optimiser les URLs d'images
  String _optimizeUrl(String? url) {
    if (url == null || url.isEmpty) return '';

    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final appDefaultData = authProvider.appDefaultData;

    return authProvider.convertToCdnUrl(url, appDefaultData);
  }

  Future<void> _loadSupportModalSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = authProvider.loginUserData.id;
    final key = 'has_seen_support_modal_$userId';
    if (!mounted) return;
    setState(() {
      _hasSeenSupportModal = prefs.getBool(key) ?? false;
    });
  }


  Future<void> _markSupportModalSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = authProvider.loginUserData.id;
    await prefs.setBool('has_seen_support_modal_$userId', true);
    if (!mounted) return;
    setState(() {
      _hasSeenSupportModal = true;
    });
  }

  void _showSupportModal() {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: colors.surface,
        title: Row(
          children: [
            Icon(Icons.volunteer_activism, color: colors.supportAccent),
            SizedBox(width: 8),
            Text(l10n.postSupportCreator, style: TextStyle(color: colors.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.postSupportWatchAdInfo,
              style: TextStyle(color: colors.textSecondary),
            ),
            SizedBox(height: 12),
            Text(
              l10n.postSupportEarnings,
              style: TextStyle(color: colors.textPrimary),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.monetization_on, color: colors.supportAccent),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.postSupportCoinsConvert,
                      style: TextStyle(color: colors.textPrimary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.postSupportLater, style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _markSupportModalSeen();
              _startSupportAd();
            },
            style: ElevatedButton.styleFrom(backgroundColor: colors.supportAccent),
            child: Text(l10n.postSupportWatchAdButton, style: TextStyle(color: colors.onAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSupportAd() async {
    // if (_isSupporting) return;
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == widget.post.user_id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).postSupportCannotSelf), backgroundColor: AppColors.of(context).warning),
      );
      return;
    }

    // Vérifier la limite quotidienne
    final hasSupported = await _hasSupportedToday(widget.post.id!, currentUserId!);
    if (hasSupported) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).postSupportAlreadyToday),
          backgroundColor: AppColors.of(context).warning,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_hasSeenSupportModal == null) await _loadSupportModalSeen();
    if (_hasSeenSupportModal == false) {
      _showSupportModal();
      return;
    }
    _startSupportAd();
  }
  void _startSupportAd() {
    setState(() {
      _isSupporting = true;
      _showRewardedAd = true;
    });
    // Attendre que le widget soit monté puis lancer la pub
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_rewardedAdKey.currentState != null) {
        _rewardedAdKey.currentState!.showAd();

      } else {
        setState(() {
          _isSupporting = false;
          _showRewardedAd = false;
        });
      }
    });
  }

  Future<void> _onSupportAdRewarded() async {
    final currentUserId = authProvider.loginUserData.id;
    final postId = widget.post.id!;
    final creatorId = widget.post.user_id!;

    // Incrémenter le compteur de pub sur le post
    final postRef = firestore.collection('Posts').doc(postId);
    await postRef.update({
      'adSupportCount': FieldValue.increment(1),
    });

    // Créditer le créateur (10 pièces)
    final creatorRef = firestore.collection('Users').doc(creatorId);
    await creatorRef.update({
      'totalCoinsEarnedFromAdSupport': FieldValue.increment(1),
    });

    // Incrémenter le compteur du spectateur
    final viewerRef = firestore.collection('Users').doc(currentUserId);
    await viewerRef.update({
      'totalAdViewsSupported': FieldValue.increment(1),
    });

    // Enregistrer le soutien (pour la limite quotidienne)
    await _recordSupport(postId, currentUserId!);

    // ✅ ENVOYER LA NOTIFICATION AU CRÉATEUR
    await _sendSupportNotification(creatorId, currentUserId!, postId);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).postSupportThanks),
        backgroundColor: AppColors.of(context).primary,
        duration: Duration(seconds: 2),
      ),
    );
    setState(() {
      widget.post.adSupportCount = (widget.post.adSupportCount ?? 0) + 1;
      _isSupporting = false;
      _showRewardedAd = false;
    });
  }
  Widget _buildSupportButton(bool hasAccess) {
    final isOwner = authProvider.loginUserData.id == widget.post.user_id;
    if (isOwner) return const SizedBox.shrink();
    return QuickGiftBar(
      receiverId: widget.post.user_id!,
      receiverName: widget.post.user?.pseudo ?? 'Créateur',
      receiverAvatar: widget.post.user?.imageUrl ?? '',
      post: widget.post,
      giftCount: widget.post.totalGiftCoinsSentOnThisPost ?? 0,
      onGiftSuccess: () async {
        setState(() {
          widget.post.users_cadeau_id ??= [];
          if (!widget.post.users_cadeau_id!.contains(authProvider.loginUserData.id!)) {
            widget.post.users_cadeau_id!.add(authProvider.loginUserData.id!);
          }
        });
        final coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);
        await coinProvider.refreshBalance(authProvider.loginUserData.id!);
      },
    );
  }
  @override
  void dispose() {
    _quickCommentController.dispose();
    _previewTimer?.cancel();
    _previewController?.dispose();
    MediaPlaybackManager.unregisterMedia(widget.post.id ?? '');
    super.dispose();
  }

  Future<void> _startVideoPreview() async {
    if (_isPreviewPlaying) return;
    final url = widget.post.url_media;
    if (url == null || url.isEmpty) {
      Navigator.push(context, MaterialPageRoute(
        builder: (c) => VideoYoutubePageDetails(initialPost: widget.post),
      ));
      return;
    }
    setState(() { _isPreviewPlaying = true; _showPreviewCta = false; });
    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      _previewController = ctrl;
      await ctrl.initialize();
      if (!mounted) return;
      await ctrl.setVolume(0);
      await ctrl.play();
      if (!mounted) return;
      setState(() {});
      final isLocked = _isLockedContent();
      if (isLocked) {
        // Contenu verrouillé : 10s de preview puis bloquer
        _previewTimer = Timer(const Duration(seconds: 10), () {
          if (!mounted) return;
          _previewController?.pause();
          setState(() => _showCanalLockCta = true);
        });
      } else {
        _previewTimer = Timer(const Duration(seconds: 5), () {
          if (!mounted) return;
          _previewController?.pause();
          setState(() => _showPreviewCta = true);
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() { _isPreviewPlaying = false; _showPreviewCta = false; });
      Navigator.push(context, MaterialPageRoute(
        builder: (c) => VideoYoutubePageDetails(initialPost: widget.post),
      ));
    }
  }

  void _checkIfFavorite() {
    final userId = authProvider.loginUserData.id!;
    setState(() {
      _isFavorite = widget.post.users_favorite_id?.contains(userId) ?? false;
    });
  }

  Future<void> _toggleFavorite() async {
    if (_isProcessingFavorite) return;

    final userId = authProvider.loginUserData.id!;
    final postId = widget.post.id!;

    setState(() {
      _isProcessingFavorite = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      if (_isFavorite) {
        // Retirer des favoris
        await _removeFromFavorites(userId, postId, firestore);
      } else {
        // Ajouter aux favoris
        await _addToFavorites(userId, postId, firestore);
      }

      if (!mounted) return;
      // Mettre à jour l'état local
      setState(() {
        _isFavorite = !_isFavorite;
        if (_isFavorite) {
          widget.post.favoritesCount = (widget.post.favoritesCount ?? 0) + 1;
          widget.post.users_favorite_id?.add(userId);
        } else {
          widget.post.favoritesCount = (widget.post.favoritesCount ?? 0) - 1;
          widget.post.users_favorite_id?.remove(userId);
        }
      });

      if (_isFavorite) {
        widget.onLoved?.call();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFavorite
                ? '✅ Post ajouté aux favoris'
                : '🗑️ Post retiré des favoris',
            style: TextStyle(color: AppColors.of(context).onPrimary),
          ),
          backgroundColor: _isFavorite ? AppColors.of(context).primary : AppColors.of(context).surfaceVariant,
          duration: Duration(seconds: 2),
        ),
      );

    } catch (e) {
      printVm('Erreur toggle favori: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Erreur lors de la modification',
            style: TextStyle(color: AppColors.of(context).onPrimary),
          ),
          backgroundColor: AppColors.of(context).danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingFavorite = false;
        });
      }
    }
  }

  Future<void> _addToFavorites(String userId, String postId, FirebaseFirestore firestore) async {
    // Mettre à jour le post
    await firestore.collection('Posts').doc(postId).update({
      'users_favorite_id': FieldValue.arrayUnion([userId]),
      'favorites_count': FieldValue.increment(1),
      'popularity': FieldValue.increment(2), // Bonus de popularité pour favoris
      'updatedAt': DateTime.now().microsecondsSinceEpoch,
    });

    // Mettre à jour l'utilisateur
    await firestore.collection('Users').doc(userId).update({
      'favoritePostsIds': FieldValue.arrayUnion([postId]),
      'updatedAt': DateTime.now().microsecondsSinceEpoch,
    });

    // Créer une notification pour l'auteur du post
    if (widget.post.user_id != userId) {
      await _createFavoriteNotification(userId);
    }
    authProvider.incrementPostTotalInteractions(
      postId: widget.post.id!,
      userId: userId,
      interactionType: 'favorite',
    );

    authProvider.notifySubscribersOfInteraction(
      actionUserId: authProvider.loginUserData.id!,
      postOwnerId: widget.post.user_id!,
      postId: widget.post.id!,
      actionType: 'favorite',
      postDescription: widget.post.description,
      postImageUrl: widget.post.images?.first,
      postDataType: widget.post.dataType,
    );
    // Ajouter des points pour l'action
    addPointsForAction(UserAction.favorite);
    addPointsForOtherUserAction(widget.post.user_id!, UserAction.autre);
  }

  Future<void> _removeFromFavorites(String userId, String postId, FirebaseFirestore firestore) async {
    // Mettre à jour le post
    await firestore.collection('Posts').doc(postId).update({
      'users_favorite_id': FieldValue.arrayRemove([userId]),
      'favorites_count': FieldValue.increment(-1),
      'popularity': FieldValue.increment(-2),
      'updatedAt': DateTime.now().microsecondsSinceEpoch,
    });

    // Mettre à jour l'utilisateur
    await firestore.collection('Users').doc(userId).update({
      'favoritePostsIds': FieldValue.arrayRemove([postId]),
      'updatedAt': DateTime.now().microsecondsSinceEpoch,
    });
  }

  Future<void> _createFavoriteNotification(String userId) async {
    try {
      final notification = NotificationData(
        id: firestore.collection('Notifications').doc().id,
        titre: "Favoris ❤️",
        media_url: authProvider.loginUserData.imageUrl,
        type: NotificationType.FAVORITE.name,
        description: "@${authProvider.loginUserData.pseudo!} a ajouté votre post à ses favoris",
        users_id_view: [],
        user_id: userId,
        receiver_id: widget.post.user_id!,
        post_id: widget.post.id!,
        post_data_type: widget.post.dataType ?? PostDataType.IMAGE.name,
        updatedAt: DateTime.now().microsecondsSinceEpoch,
        createdAt: DateTime.now().microsecondsSinceEpoch,
        status: PostStatus.VALIDE.name,
      );

      await firestore.collection('Notifications').doc(notification.id).set(notification.toJson());

      // Notification push
      if (currentUser != null && currentUser!.oneIgnalUserid != null) {
        await authProvider.sendNotification(
          userIds: [currentUser!.oneIgnalUserid!],
          smallImage: authProvider.loginUserData.imageUrl!,
          send_user_id: userId,
          recever_user_id: widget.post.user_id!,
          message: "❤️ @${authProvider.loginUserData.pseudo!} a ajouté votre post à ses favoris",
          type_notif: NotificationType.FAVORITE.name,
          post_id: widget.post.id!,
          post_type: widget.post.dataType ?? PostDataType.IMAGE.name,
          chat_id: '',
        );
      }
    } catch (e) {
      printVm('Erreur création notification favori: $e');
    }
  }
  Future<void> _loadUserData() async {
    if (widget.post.user_id == null) return;
    if (!mounted) return;

    setState(() {
      _isLoadingUser = true;
    });

    try {
      final userDoc = await firestore.collection('Users').doc(widget.post.user_id!).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _currentUser = UserData.fromJson(userDoc.data() as Map<String, dynamic>);
          widget.post.user = _currentUser;
        });
      }
    } catch (e) {
      printVm('Erreur lors du chargement de l\'utilisateur: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingUser = false;
        });
      }
    }
  }

  Future<void> _loadCanalData() async {
    if (widget.post.canal_id == null || widget.post.canal_id!.isEmpty) return;
    if (!mounted) return;

    setState(() {
      _isLoadingCanal = true;
    });

    try {
      final canalDoc = await firestore.collection('Canaux').doc(widget.post.canal_id!).get();
      if (canalDoc.exists && mounted) {
        final canalData = canalDoc.data() as Map<String, dynamic>;
        setState(() {
          _currentCanal = Canal.fromJson(canalData);
          widget.post.canal = _currentCanal;
        });
      }
    } catch (e) {
      printVm('Erreur lors du chargement du canal: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCanal = false;
        });
      }
    }
  }

  UserData? get currentUser {
    return widget.post.user ?? _currentUser;
  }

  Canal? get currentCanal {
    return widget.post.canal ?? _currentCanal;
  }

  // Vérifier si l'utilisateur a accès au contenu
  bool _hasAccessToContent() {
    if (currentCanal != null) {
      final isPrivate = currentCanal!.isPrivate == true;
      final isSubscribed = currentCanal!.usersSuiviId?.contains(authProvider.loginUserData.id) ?? false;
      final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;
      final isCurrentUser = authProvider.loginUserData.id == widget.post.user_id;

      // Accès autorisé si :
      // - Le canal n'est pas privé
      // - OU l'utilisateur est abonné
      // - OU c'est un admin
      if (!isPrivate || isSubscribed || isAdmin|| isCurrentUser) {
        return true;
      }

      // Sinon, accès refusé
      return false;
    }

    // Si ce n'est pas un post de canal → accès libre
    return true;
  }

  // Vérifier si c'est un post de canal privé non accessible
  bool _isLockedContent() {
    if (currentCanal != null) {
      final isPrivate = currentCanal!.isPrivate == true;
      final isSubscribed = currentCanal!.usersSuiviId?.contains(authProvider.loginUserData.id) ?? false;
      final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;
      final isCurrentUser = authProvider.loginUserData.id == widget.post.user_id;

      // Le contenu est verrouillé uniquement si :
      // - Le canal est privé
      // - L'utilisateur n'est pas abonné
      // - Et ce n'est pas un administrateur
      return isPrivate && !isSubscribed && !isAdmin&& !isCurrentUser;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = AppColors.of(context);
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;

    if (_isLoadingUser || _isLoadingCanal) {
      return _buildSkeletonLoader();
    }

    final isLocked = _isLockedContent();
    final hasAccess = _hasAccessToContent();

    return Container(
      color: colors.background,
      child: Column(
        children: [
          // Ligne de séparation supérieure
          Container(
            height: 0.5,
            color: colors.divider,
          ),

          // Contenu du post
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // En-tête du post
                _buildPostHeader(w, h),
                SizedBox(height: 8),

                // Contenu texte (avec limitation si contenu verrouillé)
                _buildPostContent(isLocked),
                SizedBox(height: 12),

                // Médias (images/vidéos) - verrouillés si pas d'accès

              if (widget.post.dataType == PostDataType.AUDIO.name)
    AudioPostCard(post: widget.post, isLocked: isLocked),
        if (widget.post.dataType == PostDataType.AUDIO.name)

    SizedBox(height: 12),

                if ((widget.post.images?.isNotEmpty ?? false)&&widget.post.dataType != PostDataType.AUDIO.name)
                  _buildMediaContent(h, isLocked),

                if (_isVideoPost(widget.post))
                  _buildVideoContent(h, isLocked),



                // Bouton d'abonnement — visible seulement après les 10s de preview
                if (isLocked && _showCanalLockCta) _buildSubscribeButton(),

                // Actions du post (masquées en contexte pub)
                if (!widget.isAdContext) ...[
                  SizedBox(height: 12),
                  _buildPostActions(hasAccess),
                  _buildCommentPreview(hasAccess),
                  PostGiftsList(
                    postId: widget.post.id!,
                    compactLevel: CompactLevel.light,
                    maxDisplayItems: 10,
                  ),
                ],
                // 🆕 AFFICHAGE DE LA PUB APRÈS LE POST SI CONDITION REMPLIE
                if (!widget.isAdContext && !widget.suppressInlineAd && _shouldShowAd && widget.post.isAdvertisement != true) ...[
                  const SizedBox(height: 12),
                  const AfrolookInlineAd(),
                  const SizedBox(height: 8),
                ],

                if (_showRewardedAd)
                  RewardedAdWidget(
                    key: _rewardedAdKey,
                    onUserEarnedReward:(amount, name) async {
                      await _onSupportAdRewarded();
                    },
                    onAdDismissed: () {
                      setState(() {
                        _showRewardedAd = false;
                        _isSupporting = false;
                      });
                    },
                    child: SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.03, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }
  Future<void> _sendSupportNotification(String creatorId, String supporterId, String postId) async {
    final now = DateTime.now().microsecondsSinceEpoch;
    final supporter = authProvider.loginUserData;
    final supporterName = supporter.pseudo ?? 'Un utilisateur';

    // Message incitatif avec le potentiel de gain
    final description = "@$supporterName a soutenu votre post en regardant une publicité ! (+1 pièces) 💰 Chaque soutien vous rapproche des 100€ (≈65 000 FCFA) par mois. Continuez à créer, on vous soutient !";

    // 1. Créer la notification dans Firestore
    final notificationId = firestore.collection('Notifications').doc().id;
    final notification = NotificationData(
      id: notificationId,
      titre: "Soutien 💪 + pièces",
      media_url: supporter.imageUrl ?? '',
      type: NotificationType.POST.name,
      description: description,
      users_id_view: [],
      user_id: supporterId,
      receiver_id: creatorId,
      post_id: postId,
      post_data_type: widget.post.dataType ?? PostDataType.IMAGE.name,
      updatedAt: now,
      createdAt: now,
      status: PostStatus.VALIDE.name,
    );
    await firestore.collection('Notifications').doc(notificationId).set(notification.toJson());

    // 2. Récupérer le token OneSignal du créateur
    final creatorDoc = await firestore.collection('Users').doc(creatorId).get();
    final creatorToken = creatorDoc.data()?['oneIgnalUserid'] as String?;
    if (creatorToken != null && creatorToken.isNotEmpty) {
      await authProvider.sendNotification(
        userIds: [creatorToken],
        smallImage: supporter.imageUrl ?? '',
        send_user_id: supporterId,
        recever_user_id: creatorId,
        message: "💪 @$supporterName vous a soutenu en regardant une vidéo ! + pièces 🎉 Continuez avec du contenu de qualité pour obtenir plus de soutiens !",        type_notif: NotificationType.SUPPORT.name,
        post_id: postId,
        post_type: widget.post.dataType ?? PostDataType.IMAGE.name,
        chat_id: '',
      );
    }
  }
  Widget _buildSkeletonLoader() {
    final colors = AppColors.of(context);
    return Container(
      color: colors.background,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(radius: 20, backgroundColor: colors.shimmerBase),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 120, height: 14, color: colors.shimmerBase),
                    SizedBox(height: 4),
                    Container(width: 80, height: 12, color: colors.shimmerBase),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Container(width: double.infinity, height: 16, color: colors.shimmerBase),
          SizedBox(height: 4),
          Container(width: double.infinity, height: 16, color: colors.shimmerBase),
          SizedBox(height: 8),
          Container(
            height: 200,
            width: double.infinity,
            color: colors.shimmerBase,
          ),
        ],
      ),
    );
  }
  Widget _buildPostHeader(double w, double h) {
    final colors = AppColors.of(context);
    final currentUserId = authProvider.loginUserData.id;
    final isCanalPost = currentCanal != null;
    final dynamic postOwner = isCanalPost ? currentCanal : currentUser;
    final isCurrentUser = currentUserId == currentUser?.id;

    // Vérifier si déjà abonné
    final isAbonne = isCanalPost
        ? currentCanal?.usersSuiviId?.contains(currentUserId) ?? false
        : currentUser?.userAbonnesIds?.contains(currentUserId) ?? false;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar avec détection de présence
        GestureDetector(
          onTap: () {
            if (isCanalPost) {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => CanalDetails(canal: currentCanal!),
              ));
            } else {
              showUserDetailsModalDialog(currentUser!, w, h, context);
            }
          },
          // 🔥 Bordure verte : ronde pour un utilisateur, carrée pour un canal
          child: isCanalPost
              ? Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(10),
                    color: colors.primary,
                    border: Border.all(color: colors.primary, width: 2),
                    image: _getProfileImage() != null
                        ? DecorationImage(image: _getProfileImage()!, fit: BoxFit.cover)
                        : null,
                  ),
                  child: _getProfileImage() == null
                      ? Icon(Icons.group, color: colors.onPrimary, size: 20)
                      : null,
                )
              : CircleAvatar(
                  radius: 25,
                  backgroundColor: colors.primary,
                  child: CircleAvatar(
                    radius: 23,
                    backgroundColor: colors.primary,
                    backgroundImage: _getProfileImage(),
                    child: _getProfileImage() == null
                        ? Icon(Icons.person, color: colors.onPrimary, size: 20)
                        : null,
                  ),
                ),
        ),
        SizedBox(width: 12),

        // Informations utilisateur et menu
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          _getDisplayName(),
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(width: 4),
                        UserBadgeWidget(user: widget.post.user, size: 14),
                        if (currentCanal == null && (widget.post.user?.commentStreak ?? 0) >= 1)
                          _buildFlameStreakBadge(widget.post.user!.commentStreak),
                      ],
                    ),
                  ),

                  // Bouton S'abonner ou menu
                  if (!isCurrentUser && !isAbonne && postOwner != null)
                    _buildFollowButton(isCanalPost, postOwner!, isAbonne),
                  SizedBox(width: 5),
                  _buildCountryBadge(widget.post)
                ],
              ),
              SizedBox(height: 2),
              Text(
                _getFollowerCount(),
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  Widget _buildPostHeader2(double w, double h) {
    final colors = AppColors.of(context);
    final currentUserId = authProvider.loginUserData.id;
    final isCanalPost = currentCanal != null;
    final dynamic postOwner = isCanalPost ? currentCanal : currentUser;
    final isCurrentUser = currentUserId == currentUser?.id;

    // Vérifier si déjà abonné
    final isAbonne = isCanalPost
        ? currentCanal?.usersSuiviId?.contains(currentUserId) ?? false
        : currentUser?.userAbonnesIds?.contains(currentUserId) ?? false;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar
        GestureDetector(
          onTap: () {
            if (isCanalPost) {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => CanalDetails(canal: currentCanal!),
              ));
            } else {
              showUserDetailsModalDialog(currentUser!, w, h, context);
            }
          },
          child: Stack(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: colors.primary,
                backgroundImage: _getProfileImage(),
                child: _getProfileImage() == null
                    ? Icon(
                  isCanalPost ? Icons.group : Icons.person,
                  color: colors.onPrimary,
                  size: 20,
                )
                    : null,
              ),
              if (_isVerified())
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: colors.background,
                      shape: BoxShape.circle,
                    ),
                    child:  Icon(Icons.verified, color: colors.info, size: 20),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(width: 12),

        // Informations utilisateur et menu
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          _getDisplayName(),
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(width: 4),
                        // if (_isVerified())
                          UserBadgeWidget(user: widget.post.user, size: 14),
                        if (currentCanal == null && (widget.post.user?.commentStreak ?? 0) >= 1)
                          _buildFlameStreakBadge(widget.post.user!.commentStreak),
                      ],
                    ),
                  ),

                  // Bouton S'abonner ou menu
                  if (!isCurrentUser && !isAbonne && postOwner != null)
                    _buildFollowButton(isCanalPost, postOwner!, isAbonne),
                  SizedBox(width: 5),
                  _buildCountryBadge(widget.post),
                  GestureDetector(
                    onTap: () => _showPostMenu(widget.post),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.more_horiz, color: colors.textSecondary, size: 22),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 2),
              Text(
                _getFollowerCount(),
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  Widget _buildCountryBadge(Post post) {
    final colors = AppColors.of(context);
    final isAllCountries = post.isAvailableInAllCountries == true;
    var countryCodes = post.availableCountries ?? [];

    // Session 13 : si le pays du filtre actif figure dans la liste, le placer en premier
    // (sans ajouter/retirer d'éléments) pour que le badge affiche prioritairement ce pays.
    final filterCountry = widget.currentFilterCountry?.toUpperCase();
    if (filterCountry != null && countryCodes.length > 1) {
      final idx = countryCodes.indexWhere((c) => c.toUpperCase() == filterCountry);
      if (idx > 0) {
        countryCodes = [
          countryCodes[idx],
          ...countryCodes.where((c) => c.toUpperCase() != filterCountry),
        ];
      }
    }

    // Déterminer le contenu du badge
    String displayText = '';
    String flagEmoji = '🌍';
    int countryCount = 1;

    if (isAllCountries) {
      displayText = 'Tous';
      flagEmoji = '🌍';
    } else if (countryCodes.isNotEmpty) {
      // Prendre le premier pays comme indicateur
      final firstCountryCode = countryCodes.first.toUpperCase();

      // Chercher l'emoji du drapeau
      final country = AfricanCountry.allCountries.firstWhere(
            (c) => c.code == firstCountryCode,
        orElse: () => AfricanCountry(
            code: firstCountryCode,
            name: firstCountryCode,
            flag: '🏳️'
        ),
      );
      flagEmoji = country.flag;
      countryCount = countryCodes.length;

      // Afficher le code du pays ou "+X" pour multiples
      if (countryCount == 1) {
        displayText = firstCountryCode;
      } else {
        displayText = '+${countryCount - 1}';
      }
    }

    // Choisir la couleur selon le type
    Color backgroundColor;
    Color textColor;
    IconData? icon;

    if (isAllCountries) {
      backgroundColor = colors.accent.withOpacity(0.9);
      textColor = colors.onAccent;
      icon = Icons.public;
    } else if (countryCodes.isNotEmpty) {
      backgroundColor = colors.danger.withOpacity(0.9);
      textColor = Colors.white;
    } else {
      // Par défaut : gris
      backgroundColor = Colors.grey[800]!.withOpacity(0.9);
      textColor = Colors.white;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icône/drapeau
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.2),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Center(
              child: Text(
                flagEmoji,
                style: TextStyle(fontSize: 10),
              ),
            ),
          ),

          SizedBox(width: 6),

          // Texte
          Text(
            displayText,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),

          // Indicateur multi-pays
          if (countryCodes.length > 1) ...[
            SizedBox(width: 2),
            Icon(
              Icons.add,
              color: textColor,
              size: 10,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFollowButton(bool isCanalPost, dynamic postOwner, bool isAbonne) {
    final colors = AppColors.of(context);
    return Container(
      height: 28,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isCanalPost && (postOwner as Canal).isPrivate == true
              ? colors.accent
              : colors.primary,
          foregroundColor: isCanalPost && (postOwner as Canal).isPrivate == true
              ? colors.onAccent
              : colors.onPrimary,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        onPressed: _isProcessingFollow ? null : () async {
          setState(() {
            _isProcessingFollow = true;
          });

          try {
            if (isCanalPost) {
              // Navigation vers la page du canal pour l'abonnement
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CanalDetails(canal: postOwner),
                ),
              );

              // Recharger les données si nécessaire
              if (result != null) {
                await _loadCanalData();
              }
            } else {
              // Abonnement à l'utilisateur
              await authProvider.abonner(postOwner as UserData, context);
              // Recharger les données utilisateur
              await _loadUserData();
            }
          } catch (e) {
            printVm('Erreur lors de l\'abonnement: $e');
          } finally {
            if (mounted) {
              setState(() {
                _isProcessingFollow = false;
              });
            }
          }
        },
        child: _isProcessingFollow
            ? SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: isCanalPost && (postOwner as Canal).isPrivate == true
                ? colors.onAccent
                : colors.onPrimary,
          ),
        )
            : Text(
          isCanalPost && (postOwner as Canal).isPrivate == true
              ? 'S\'abonner'
              : 'Suivre',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _generateVideoThumbnail() async {
    if (!_isVideoPost(widget.post) || widget.post.url_media == null) return;

    setState(() {
      _isGeneratingThumbnail = true;
    });

    try {
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video:_optimizeUrl(widget.post.url_media!)  ,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 75,
        timeMs: 1000,
      );

      if (thumbnailPath != null && File(thumbnailPath).existsSync() && mounted) {
        setState(() {
          _videoThumbnailPath = thumbnailPath;
          _isGeneratingThumbnail = false;
        });
      }
    } catch (e) {
      printVm('Erreur génération thumbnail: $e');
      if (mounted) {
        setState(() {
          _isGeneratingThumbnail = false;
        });
      }
    }
  }

  Widget _buildPostContent(bool isLocked) {
    final colors = AppColors.of(context);
    final text = widget.post.description ?? "";

    if (isLocked) {
      // Contenu verrouillé - afficher seulement 2 lignes
      final words = text.split(' ');
      final limitedText = words.length > 20
          ? words.take(20).join(' ') + '...'
          : text;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            limitedText,
            style: TextStyle(
              fontSize: 15,
              color: colors.textSecondary, // Texte grisé pour contenu verrouillé
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.lock, color: colors.accent, size: 16),
              SizedBox(width: 4),
              Text(
                'Contenu réservé aux abonnés',
                style: TextStyle(
                  color: colors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Description sur l'image (overlay) — ici on affiche seulement l'event badge
    // pour les posts avec images. Pour les posts texte, on affiche la description.
    final hasMedia = (widget.post.images?.isNotEmpty == true);

    if (hasMedia) {
      return _buildEventBadge(widget.post);
    }

    // Post texte uniquement — afficher la description normalement
    final words = text.split(' ');
    final isLong = words.length > 25;
    final displayedText = _isExpanded || !isLong
        ? text
        : words.take(25).join(' ') + '...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _openDetailsPage,
          child: HashTagText(
            text: displayedText,
            decoratedStyle: TextStyle(fontSize: 15, color: colors.info, fontWeight: FontWeight.w400, height: 1.4),
            basicStyle: TextStyle(fontSize: 15, color: colors.textPrimary, fontWeight: FontWeight.w400, height: 1.4),
            onTap: (_) {},
          ),
        ),
        if (isLong)
          GestureDetector(
            onTap: _openDetailsPage,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Voir plus',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.info)),
            ),
          ),
        _buildEventBadge(widget.post),
      ],
    );
  }

  Widget _buildMediaContent(double h, bool isLocked) {
    final colors = AppColors.of(context);
    final images = widget.post.images!;
    final imageCount = images.length;

    // Définir la hauteur en fonction du nombre d'images
    double contentHeight;
    if (imageCount == 1) {
      contentHeight = h * 0.55;
    } else if (imageCount == 2) {
      contentHeight = h * 0.55;
    } else if (imageCount == 3) {
      contentHeight = h * 0.55;
    } else {
      contentHeight = h * 0.55;
    }

    return Container(
      height: contentHeight, // 🔥 HAUTEUR EXPLICITE POUR ÉVITER L'ERREUR
      child: Stack(
        children: [
          // Conteneur principal pour le grid d'images
          Container(
            width: double.infinity,
            height: contentHeight,
            color: colors.shimmerBase,
            child: Opacity(
              opacity: isLocked ? 0.15 : 1.0,
              child: _buildImageGrid(contentHeight, imageCount),
            ),
          ),

          // Description overlay en bas du media (contenu déverrouillé)
          if (!isLocked && (widget.post.description ?? '').trim().isNotEmpty)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: GestureDetector(
                onTap: _openDetailsPage,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 40, 12, 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.78)],
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          widget.post.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.35,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Voir plus',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Overlay pour contenu verrouillé
          if (isLocked)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock, color: colors.accent, size: 50),
                      SizedBox(height: 8),
                      Text(
                        'Contenu verrouillé',
                        style: TextStyle(
                          color: colors.accent,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Abonnez-vous pour voir ce contenu',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Badge indiquant le nombre d'images (si plus de 1)
          if (imageCount > 1 && !isLocked)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_library, color: Colors.white, size: 14),
                    SizedBox(width: 5),
                    Text(
                      '$imageCount',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

// 🔥 MÉTHODE MODIFIÉE POUR PRENDRE LA HAUTEUR EN PARAMÈTRE
  Widget _buildImageGrid(double height, int imageCount) {
    final images = widget.post.images!;

    if (imageCount == 1) {
      // 1 image : pleine largeur
      return _buildSingleImage(images[0], height);
    } else if (imageCount == 2) {
      // 2 images : côte à côte
      return _buildTwoImages(images, height);
    } else if (imageCount == 3) {
      // 3 images : 1 grande + 2 petites
      return _buildThreeImages(images, height);
    } else {
      // 4+ images : grid 2x2 avec indicateur
      return _buildMultipleImages(images, height);
    }
  }

  Widget _buildSingleImage(String url, double height) {
    final colors = AppColors.of(context);
    final imageUrl = _optimizeUrl(url);
    return GestureDetector(
      onTap: () {
        _openDetailsPage();
      },
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: height,
        placeholder: (context, url) => Container(
          color: colors.shimmerBase,
        ),
        errorWidget: (context, url, error) => Container(
          color: colors.shimmerBase,
          child: Icon(Icons.broken_image, color: colors.textSecondary),
        ),
      ),
    );
  }

  Widget _buildTwoImages(List<String> images, double height) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: _openDetailsPage,
      child: Row(
        children: [
          // Première image - moitié gauche
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: 2),
              child: CachedNetworkImage(
                imageUrl: _optimizeUrl(images[0]),
                fit: BoxFit.cover,
                height: height,
                placeholder: (context, url) => Container(
                  color: colors.shimmerBase,
                ),
                errorWidget: (context, url, error) => Container(
                  color: colors.shimmerBase,
                  child: Icon(Icons.broken_image, color: colors.textSecondary),
                ),
              ),
            ),
          ),

          // Deuxième image - moitié droite
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 2),
              child: CachedNetworkImage(
                imageUrl: _optimizeUrl(images[1]),
                fit: BoxFit.cover,
                height: height,
                placeholder: (context, url) => Container(
                  color: colors.shimmerBase,
                ),
                errorWidget: (context, url, error) => Container(
                  color: colors.shimmerBase,
                  child: Icon(Icons.broken_image, color: colors.textSecondary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreeImages(List<String> images, double height) {
    final colors = AppColors.of(context);
    return GestureDetector(
      onTap: _openDetailsPage,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Première image - 2/3 de la largeur
          Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.only(right: 2),
              child: CachedNetworkImage(
                imageUrl: _optimizeUrl(images[0]),
                fit: BoxFit.cover,
                height: height,
                placeholder: (context, url) => Container(
                  color: colors.shimmerBase,
                ),
                errorWidget: (context, url, error) => Container(
                  color: colors.shimmerBase,
                  child: Icon(Icons.broken_image, color: colors.textSecondary),
                ),
              ),
            ),
          ),

          // Deuxième et troisième images - 1/3 de la largeur, divisées verticalement
          Expanded(
            flex: 1,
            child: Container(
              height: height,
              padding: EdgeInsets.only(left: 2),
              child: Column(
                children: [
                  // Deuxième image - moitié supérieure
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 2),
                      child: CachedNetworkImage(
                        imageUrl: _optimizeUrl(images[1]),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => Container(
                          color: colors.shimmerBase,
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: colors.shimmerBase,
                          child: Icon(Icons.broken_image, color: colors.textSecondary),
                        ),
                      ),
                    ),
                  ),

                  // Troisième image - moitié inférieure
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: CachedNetworkImage(
                        imageUrl: _optimizeUrl(images[2]),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => Container(
                          color: colors.shimmerBase,
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: colors.shimmerBase,
                          child: Icon(Icons.broken_image, color: colors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultipleImages(List<String> images, double height) {
    final colors = AppColors.of(context);
    final displayedImages = images.take(4).toList();
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = (screenWidth / 2).toInt();

    return GestureDetector(
      onTap: _openDetailsPage,
      child: Container(
        height: height,
        child: GridView.builder(
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: displayedImages.length,
          itemBuilder: (context, index) {
            final optimizedUrl = _optimizeUrl(displayedImages[index]);

            const BorderRadius borderRadius = BorderRadius.zero;

            bool hasOverlay = index == 3 && images.length > 4;

            return Stack(
              children: [
                ClipRRect(
                  borderRadius: borderRadius,
                  child: CachedNetworkImage(
                    imageUrl: optimizedUrl,  // 🔥 URL OPTIMISÉE
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (context, url) => Container(
                      color: colors.shimmerBase,
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: colors.shimmerBase,
                      child: Icon(Icons.broken_image, color: colors.textSecondary),
                    ),
                  ),
                ),
                if (hasOverlay)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.6),
                      child: Center(
                        child: Text(
                          '+${images.length - 4}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
  Widget _buildVideoContent(double h, bool isLocked) {
    final colors = AppColors.of(context);
    final previewReady = _isPreviewPlaying &&
        _previewController != null &&
        _previewController!.value.isInitialized;

    return Stack(
      children: [
        // Thumbnail, preview en cours, ou fallback
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: _isGeneratingThumbnail
              ? Center(child: CircularProgressIndicator(color: colors.info))
              : previewReady
                  ? SizedBox(
                      width: double.infinity,
                      height: h * 0.55,
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _previewController!.value.size.width,
                          height: _previewController!.value.size.height,
                          child: VideoPlayer(_previewController!),
                        ),
                      ),
                    )
                  : (_videoThumbnailPath != null && File(_videoThumbnailPath!).existsSync())
                      ? GestureDetector(
                          onTap: () {
                            if (widget.post.dataType == PostDataType.VIDEO.name) {
                              _startVideoPreview();
                            } else {
                              _openDetailsPage();
                            }
                          },
                          child: Opacity(
                            opacity: 1.0,
                            child: Image.file(
                              File(_videoThumbnailPath!),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: h * 0.55,
                            ),
                          ),
                        )
                      : _buildFallbackThumbnail(),
        ),

        // Overlay verrou canal — s'affiche après 10s de lecture
        if (_showCanalLockCta)
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                if (currentCanal != null) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => CanalDetails(canal: currentCanal!)));
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.accent.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: colors.accent, width: 2),
                        ),
                        child: Icon(Icons.lock_outline, color: colors.accent, size: 28),
                      ),
                      const SizedBox(height: 10),
                      const Text('Contenu réservé aux abonnés',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
                      const SizedBox(height: 4),
                      const Text('Rejoignez ce canal pour continuer',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60, fontSize: 11, decoration: TextDecoration.none)),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                        decoration: BoxDecoration(color: colors.accent, borderRadius: BorderRadius.circular(20)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_user, color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text("S'abonner au canal", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, decoration: TextDecoration.none)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Overlay play (masqué pendant la preview et le verrou)
        if (!_isPreviewPlaying && !_showCanalLockCta)
          Positioned.fill(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
              ),
            ),
          ),

        // Badge vidéo en haut à gauche
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam, color: Colors.white, size: 12),
                SizedBox(width: 4),
                Text('Vidéo', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),

        // CTA "Voir la suite" après 5 secondes de preview
        if (_showPreviewCta)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: Colors.black.withOpacity(0.75),
                child: Center(
                  child: GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (context) => VideoYoutubePageDetails(initialPost: widget.post),
                    )),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: colors.accent,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_circle_fill, color: Colors.white, size: 20),
                          SizedBox(width: 6),
                          Text('Voir la suite', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, decoration: TextDecoration.none)),
                        ],
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleXY(begin: 1.0, end: 1.08, duration: 600.ms, curve: Curves.easeInOut),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFallbackThumbnail() {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.shimmerBase,
            colors.shimmerHighlight,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam,
              color: colors.textSecondary.withOpacity(0.7),
              size: 50,
            ),
            SizedBox(height: 8),
            Text(
              'Vidéo',
              style: TextStyle(
                color: colors.textSecondary.withOpacity(0.7),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscribeButton() {
    final colors = AppColors.of(context);
    final isCanalPost = currentCanal != null;
    final isPrivate = currentCanal?.isPrivate == true;
    final subscriptionPrice = currentCanal?.subscriptionPrice ?? 0;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 12),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.onAccent,
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        onPressed: () {
          if (isCanalPost) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CanalDetails(canal: currentCanal!),
              ),
            );
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_open, size: 18),
            SizedBox(width: 8),
            Text(
              isPrivate
                  ? 'S\'ABONNER - ${subscriptionPrice.toInt()} FCFA'
                  : 'SUIVRE LE CANAL',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostActions(bool hasAccess) {
    final colors = AppColors.of(context);
    final isLiked = _isLikedLocally;

    return Container(
      margin: EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Commentaire
          _buildActionButton(
            icon: FontAwesome.comment_o,
            count: _localCommentsCount,
            color: colors.textSecondary,
            onPressed: hasAccess ? () {
              _showCommentsModal(widget.post);

              recordUniquePostView();
              // 🔥 APPEL DU CALLBACK
              widget.onCommented?.call();
            } : null,
          ),

          // Vues
          _buildActionButton(
            icon:  Icons.bar_chart,
            count: widget.post.totalInteractions ?? 0,
            color: colors.textSecondary,
            onPressed: hasAccess ? () {
              _handleRepost();
              recordUniquePostView();
              // 🔥 APPEL DU CALLBACK
              widget.onViewed?.call();
            } : null,
          ),

          // Like
          _buildActionButton(
            icon: isLiked ? FontAwesome.heart : FontAwesome.heart_o,
            count: _localLovesCount,
            color: isLiked ? colors.danger : colors.textSecondary,
            isLoading: _isLiking,
            onPressed: (hasAccess && !_isLiking) ? () {
              _handleLike();
              recordUniquePostView();
              widget.onLiked?.call();
            } : null,
          ),
          // FAVORIS (NOUVEAU)
          _buildFavoriteButton(hasAccess),

          // Cadeau (masqué pour les pubs)
          if (widget.post.isAdvertisement != true) ...[
            if (hasAccess && authProvider.loginUserData.id != widget.post.user_id)
              QuickGiftBar(
                receiverId: widget.post.user_id!,
                receiverName: widget.post.user?.pseudo ?? 'Créateur',
                receiverAvatar: widget.post.user?.imageUrl ?? '',
                post: widget.post,
                giftCount: widget.post.totalGiftCoinsSentOnThisPost ?? 0,
                onGiftSuccess: () async {
                  setState(() {
                    widget.post.users_cadeau_id ??= [];
                    if (!widget.post.users_cadeau_id!.contains(authProvider.loginUserData.id!)) {
                      widget.post.users_cadeau_id!.add(authProvider.loginUserData.id!);
                    }
                  });
                  await  _coinProvider.refreshBalance(authProvider.loginUserData.id!);
                },
              )
            else
              _buildActionButton(
                icon: FontAwesome.gift,
                count: widget.post.totalGiftCoinsSentOnThisPost ?? 0,
                color: colors.textSecondary,
                onPressed: null,
              ),
          ],

          // Partager
          // _isSharing
          //     ? SizedBox(
          //   width: 40, // Ajustez selon la taille de vos boutons
          //   height: 40,
          //   child: Padding(
          //     padding: const EdgeInsets.all(8.0),
          //     child: CircularProgressIndicator(strokeWidth: 2, color: colors.textSecondary),
          //   ),
          // )
          //     : _buildActionButton(
          //   icon: Icons.share,
          //   count: widget.post.partage ?? 0,
          //   color: colors.textSecondary,
          //   onPressed: hasAccess ? () {
          //     _handleShare();
          //     recordUniquePostView();
          //     // Le callback est déjà appelé dans _handleShare ou ici
          //   } : null,
          // ),
        ],
      ),
    );
  }
  Widget _buildFavoriteButton(bool hasAccess) {
    final colors = AppColors.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: hasAccess && !_isProcessingFavorite ? _toggleFavorite : null,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            children: [
              if (_isProcessingFavorite)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.textSecondary.withOpacity(_isFavorite ? 1.0 : 0.3),
                  ),
                )
              else
                Icon(
                  _isFavorite ? Icons.bookmark : Icons.bookmark_border,
                  size: 18,
                  color: hasAccess
                      ? colors.textSecondary
                      : colors.textSecondary.withOpacity(0.3),
                ).animate(target: _isFavorite ? 1 : 0).scaleXY(begin: 1.0, end: 1.2, duration: 150.ms, curve: Curves.easeOut).then().scaleXY(begin: 1.2, end: 1.0, duration: 150.ms),
              SizedBox(width: 6),
              Text(
                _formatCount(widget.post.favoritesCount ?? 0),
                style: TextStyle(
                  color: hasAccess
                      ? colors.textSecondary
                      : colors.textSecondary.withOpacity(0.3),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _loadLastComment() async {
    final postId = widget.post.id;
    if (postId == null || _isLoadingComment) return;
    setState(() => _isLoadingComment = true);
    try {
      final snap = await firestore
          .collection('PostComments')
          .where('post_id', isEqualTo: postId)
          .orderBy('created_at', descending: true)
          .limit(10)
          .get();
      if (snap.docs.isNotEmpty && mounted) {
        setState(() {
          _preloadedComments = snap.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            return PostComment.fromJson(data);
          }).toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingComment = false);
  }

  Future<void> _sendQuickComment(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSendingQuickComment) return;
    final userId = authProvider.loginUserData.id;
    if (userId == null) return;

    setState(() {
      _isSendingQuickComment = true;
      _quickCommentController.clear();
    });

    try {
      final comment = PostComment(
        id: FirebaseFirestore.instance.collection('PostComments').doc().id,
        user_id: userId,
        user: authProvider.loginUserData,
        post_id: widget.post.id,
        users_like_id: [],
        responseComments: [],
        message: trimmed,
        loves: 0,
        likes: 0,
        comments: 0,
        createdAt: DateTime.now().microsecondsSinceEpoch,
        updatedAt: DateTime.now().microsecondsSinceEpoch,
      );

      final success = await postProvider.newComment(comment);

      if (success) {
        if (mounted) {
          setState(() {
            _preloadedComments.insert(0, comment);
            _localCommentsCount++;
          });
        }

        authProvider.incrementPostTotalInteractions(postId: widget.post.id!);
        authProvider.notifySubscribersOfInteraction(
          actionUserId: userId,
          postOwnerId: widget.post.user_id!,
          postId: widget.post.id!,
          actionType: 'comment',
          commentaireMessage: trimmed,
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
        _autoLikeIfNeeded(userId);
        FeedInteractionService.onPostCommented(widget.post, userId);
        try {
          final result = await StreakService.onCommentSent(
            userId: userId,
            postId: widget.post.id!,
          );
          if (mounted) context.read<StreakProvider>().updateFromResult(result);
        } catch (e) {
          debugPrint('[Streak] erreur quickComment postWidget: $e');
        }
        authProvider.checkAndRefreshPostDates(widget.post.id!);

        // Notification au propriétaire du post
        if (widget.post.user != null && widget.post.user!.id != userId) {
          try {
            final msg = "@${authProvider.loginUserData.pseudo!} a commenté votre publication";
            final notif = NotificationData(
              id: FirebaseFirestore.instance.collection('Notifications').doc().id,
              titre: "Nouvelle interaction",
              media_url: authProvider.loginUserData.imageUrl,
              type: NotificationType.POST.name,
              description: msg,
              user_id: userId,
              receiver_id: widget.post.user!.id!,
              post_id: widget.post.id!,
              post_data_type: PostDataType.COMMENT.name,
              createdAt: DateTime.now().microsecondsSinceEpoch,
              updatedAt: DateTime.now().microsecondsSinceEpoch,
              status: PostStatus.VALIDE.name,
            );
            await FirebaseFirestore.instance
                .collection('Notifications')
                .doc(notif.id)
                .set(notif.toJson());
            final receiverUser = await authProvider.getUserById(widget.post.user!.id!);
            if (receiverUser.isNotEmpty && receiverUser.first.oneIgnalUserid != null) {
              await authProvider.sendNotification(
                userIds: [receiverUser.first.oneIgnalUserid!],
                smallImage: authProvider.loginUserData.imageUrl!,
                send_user_id: userId,
                recever_user_id: widget.post.user!.id!,
                message: msg,
                type_notif: NotificationType.POST.name,
                post_id: widget.post.id!,
                post_type: PostDataType.COMMENT.name,
                chat_id: '',
              );
            }
          } catch (_) {}
        }
      }
    } finally {
      if (mounted) setState(() => _isSendingQuickComment = false);
    }
  }

  void _autoLikeIfNeeded(String userId) {
    final postId = widget.post.id;
    if (postId == null) return;
    final alreadyLiked = _isLikedLocally;
    if (alreadyLiked) return;
    // Like silencieux sans notification ni paiement
    FirebaseFirestore.instance.collection('Posts').doc(postId).update({
      'loves': FieldValue.increment(1),
      'users_love_id': FieldValue.arrayUnion([userId]),
    }).catchError((_) {});
    if (mounted) setState(() {
      _isLikedLocally = true;
      _localLovesCount++;
      widget.post.loves = _localLovesCount;
      widget.post.users_love_id ??= [];
      widget.post.users_love_id!.add(userId);
    });
  }

  String _capitalizeComment(String text) {
    if (text.isEmpty) return text;
    final first = String.fromCharCode(text.runes.first);
    // Si le caractère a une forme majuscule distincte → c'est une lettre
    if (first.toUpperCase() != first.toLowerCase()) {
      return first.toUpperCase() + text.substring(first.length);
    }
    // Emoji, chiffre ou symbole → on ne touche pas
    return text;
  }

  Widget _buildCommentPreview(bool hasAccess) {
    if (!hasAccess) return const SizedBox.shrink();
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vrais commentaires utilisateurs — défilement horizontal automatique
          if (_preloadedComments.isNotEmpty)
            SizedBox(
              height: 30,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _preloadedComments.length,
                itemBuilder: (_, i) {
                  final text = _preloadedComments[i].message?.trim() ?? '';
                  if (text.isEmpty) return const SizedBox.shrink();
                  return GestureDetector(
                    onTap: () => _showCommentsModal(widget.post),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6, bottom: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: colors.surfaceVariant,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colors.border.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.record_voice_over_outlined, size: 11, color: colors.textSecondary),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(
                              text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: colors.textSecondary, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 5),

          // Vrai champ de saisie
          Container(
            height: 34,
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quickCommentController,
                    enabled: !_isSendingQuickComment,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (v) => _sendQuickComment(v),
                    style: TextStyle(fontSize: 12, color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Ajouter un commentaire…',
                      hintStyle: TextStyle(
                          color: colors.textSecondary.withOpacity(0.55), fontSize: 12),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      isDense: true,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _sendQuickComment(_quickCommentController.text),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _isSendingQuickComment
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: colors.primary),
                          )
                        : Icon(Icons.send_outlined,
                            size: 14, color: colors.textSecondary.withOpacity(0.6)),
                  ),
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
    required int count,
    required Color color,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            children: [
              if (isLoading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: onPressed != null ? color : color.withOpacity(0.3),
                  ),
                )
              else
                Icon(icon, size: 18, color: onPressed != null ? color : color.withOpacity(0.3)),
              SizedBox(width: 6),
              Text(
                _formatCount(count),
                style: TextStyle(
                  color: onPressed != null ? color : color.withOpacity(0.3),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



  // Méthodes utilitaires
// Dans _getProfileImage()
  ImageProvider? _getProfileImage() {
    String? imageUrl;

    if (currentCanal != null && currentCanal!.urlImage != null) {
      imageUrl = currentCanal!.urlImage;
    } else if (currentUser != null && currentUser!.imageUrl != null) {
      imageUrl = currentUser!.imageUrl;
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      final optimizedUrl = _optimizeUrl(imageUrl); // 100px suffisant pour un avatar
      return NetworkImage(optimizedUrl);
    }

    return null;
  }

  String _getFollowerCount() {
    if (currentCanal != null) {
      return "${currentCanal!.usersSuiviId?.length ?? 0} abonné(s)";
    } else if (currentUser != null) {
      return "${currentUser!.userAbonnesIds?.length ?? 0} abonné(s)";
    }
    return "0 abonné(s)";
  }

  bool _isVerified() {
    if (currentCanal != null) return currentCanal!.isVerify ?? false;
    if (currentUser != null) return currentUser!.isVerify ?? false;
    return false;
  }

  String _getDisplayName() {
    String name;

    if (currentCanal != null) {
      final titre = currentCanal!.titre;
      name = '#${(titre == null || titre.trim().isEmpty) ? 'Canal' : titre}';
    } else if (currentUser != null) {
      name = '@${currentUser!.pseudo ?? 'Utilisateur'}';
    } else {
      name = 'Utilisateur';
    }

    const maxLength = 20;
    if (name.runes.length > maxLength) {
      name = String.fromCharCodes(name.runes.take(maxLength)) + '...';
    }

    return name;
  }

  /// Badge série commentaires affiché à côté du pseudo — emoji et couleur selon le niveau.
  Widget _buildFlameStreakBadge(int streak) {
    const emojis = ['👀', '💬', '🗣️', '🔥', '⚡', '👑'];
    const colors = [
      Color(0xFF8E8E93), Color(0xFF5B9CFA), Color(0xFFFF9500),
      Color(0xFFFF6B35), Color(0xFFFF3B30), Color(0xFFAF52DE),
    ];
    final level = streak == 0 ? 0 : streak < 3 ? 1 : streak < 7 ? 2 : streak < 14 ? 3 : streak < 30 ? 4 : 5;
    final color = colors[level];
    final emoji = emojis[level];
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        '$emoji$streak',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  bool _isVideoPost(Post post) {
    return post.dataType == PostDataType.VIDEO.name ||
        (post.url_media ?? '').contains('.mp4') ||
        (post.url_media ?? '').contains('.mov') ||
        (post.url_media ?? '').contains('.avi') ||
        (post.url_media ?? '').contains('.webm') ||
        (post.url_media ?? '').contains('.mkv') ||
        (post.description ?? '').toLowerCase().contains('#video');
  }

  // Méthodes de gestion des actions
  void _showCommentsModal(Post post, {String? initialText}) {
    final colors = AppColors.of(context);
    showResponsiveBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Commentaires',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PostComments(
                post: post,
                isInModal: true,
                focusKeyboard: true,
                initialComments: _preloadedComments,
                initialText: initialText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPostMenu(Post post) {
    final colors = AppColors.of(context);
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final postProvider = Provider.of<PostProvider>(context, listen: false);

    showResponsiveBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (post.user!.id == authProvider.loginUserData.id &&
                post.isAdvertisement != true)
              _buildMenuOption(
                Icons.rocket_launch_outlined,
                "Booster ce post",
                const Color(0xFFFFD700),
                () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => UserCreateAdvertisementPage(existingPost: post),
                  ));
                },
              ),

            if (post.user_id != authProvider.loginUserData.id)
              _buildMenuOption(
                Icons.flag,
                "Signaler",
                colors.textPrimary,
                    () async {
                  post.status = PostStatus.SIGNALER.name;
                  final value = await postProvider.updateVuePost(post, context);
                  Navigator.pop(context);

                  final snackBar = SnackBar(
                    content: Text(
                      value ? 'Post signalé !' : 'Échec du signalement !',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: value ? AppColors.of(context).primary : AppColors.of(context).danger),
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                },
              ),

            if (post.user!.id == authProvider.loginUserData.id ||
                authProvider.loginUserData.role == UserRole.ADM.name)
              _buildMenuOption(
                Icons.delete,
                "Supprimer",
                colors.danger,
                () {
                  Navigator.pop(context);
                  _confirmAndDeletePost(post);
                },
              ),

            SizedBox(height: 8),
            Container(height: 0.5, color: colors.divider),
            SizedBox(height: 8),

            _buildMenuOption(Icons.cancel, "Annuler", colors.textSecondary, () {
              Navigator.pop(context);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption(
      IconData icon, String text, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 12),
              Text(text, style: TextStyle(color: color, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  // 🔥 MÉTHODE LIKE AVEC CALLBACK
  Future<void> _handleLike2() async {
    final userId = authProvider.loginUserData.id;
    if (userId == null) return;
    if (isIn(widget.post.users_love_id!, userId)) return;

    // Mise à jour UI instantanée
    setState(() {
      widget.post.loves = (widget.post.loves ?? 0) + 1;
      widget.post.users_love_id ??= [];
      widget.post.users_love_id!.add(userId);
    });

    // Firestore + notifications en arrière plan
    firestore.collection('Posts').doc(widget.post.id).update({
      'loves': FieldValue.increment(1),
      'users_love_id': FieldValue.arrayUnion([userId]),
      'popularity': FieldValue.increment(1),
    });
    addPointsForAction(UserAction.like);
    addPointsForOtherUserAction(widget.post.user_id!, UserAction.autre);
    if (currentUser?.oneIgnalUserid != null) {
      authProvider.sendNotification(
        userIds: [currentUser!.oneIgnalUserid!],
        smallImage: authProvider.loginUserData.imageUrl ?? '',
        send_user_id: userId,
        recever_user_id: widget.post.user_id!,
        message: "📢 @${authProvider.loginUserData.pseudo ?? ''} a aimé votre look",
        type_notif: NotificationType.POST.name,
        post_id: widget.post.id!,
        post_type: PostDataType.IMAGE.name,
        chat_id: '',
      );
    }
    widget.onLoved?.call();
  }
  Future<void> _handleLike() async {
    if (_isLiking) return;
    final userId = authProvider.loginUserData.id;
    if (userId == null) return;

    // Source de vérité : l'état local (résistant aux remplacement de widget.post)
    final alreadyLiked = _isLikedLocally;

    setState(() {
      _isLiking = true;
      _isLikedLocally = !alreadyLiked;
      _localLovesCount = alreadyLiked
          ? (_localLovesCount - 1).clamp(0, 999999)
          : _localLovesCount + 1;
      // Sync widget.post pour la compatibilité avec le reste du code
      widget.post.loves = _localLovesCount;
      widget.post.users_love_id ??= [];
      if (alreadyLiked) {
        widget.post.users_love_id!.remove(userId);
      } else {
        widget.post.users_love_id!.add(userId);
      }
    });

    // Réinitialise l'indicateur de chargement immédiatement — l'UI est déjà à jour
    Future.microtask(() {
      if (mounted) setState(() => _isLiking = false);
    });

    if (alreadyLiked) {
      _processUnlikeBackground(userId);
    } else {
      _processLikeBackground(userId);
    }
  }

  void _processUnlikeBackground(String userId) {
    final postId = widget.post.id;
    if (postId == null) {
      if (mounted) setState(() => _isLiking = false);
      return;
    }
    firestore.collection('Posts').doc(postId).update({
      'loves': FieldValue.increment(-1),
      'users_love_id': FieldValue.arrayRemove([userId]),
      'popularity': FieldValue.increment(-1),
    }).catchError((_) {
      if (mounted) setState(() {
        _isLikedLocally = true;
        _localLovesCount = _localLovesCount + 1;
        widget.post.loves = _localLovesCount;
        widget.post.users_love_id?.add(userId);
      });
    }).whenComplete(() {
      if (mounted) setState(() => _isLiking = false);
    });
  }

  void _processLikeBackground(String userId) {
    final postId = widget.post.id;
    final receiverId = widget.post.user_id;
    if (postId == null || receiverId == null) {
      if (mounted) setState(() => _isLiking = false);
      return;
    }

    final coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);
    coinProvider.sendLikeWithCoins(
      senderId: userId,
      receiverId: receiverId,
      post: widget.post,
      context: context,
    ).then((success) async {
      if (!success) {
        await firestore.collection('Posts').doc(postId).update({
          'loves': FieldValue.increment(1),
          'users_love_id': FieldValue.arrayUnion([userId]),
          'popularity': FieldValue.increment(1),
        }).catchError((_) {});
        if (mounted) _showInsufficientCoinsForLikeDialog();
        return;
      }
      if (mounted) {
        try {
          addPointsForAction(UserAction.like);
          addPointsForOtherUserAction(receiverId, UserAction.autre);
          await _sendLikeNotifications();
          widget.onLoved?.call();
        } catch (e) {
          printVm("Erreur post-like: $e");
        }
      }
    }).catchError((e) async {
      printVm("Like transaction failed: $e");
      try {
        await firestore.collection('Posts').doc(postId).update({
          'loves': FieldValue.increment(1),
          'users_love_id': FieldValue.arrayUnion([userId]),
          'popularity': FieldValue.increment(1),
        });
        if (mounted) {
          try {
            await _sendLikeNotifications();
            widget.onLoved?.call();
          } catch (_) {}
        }
      } catch (_) {
        if (mounted) setState(() {
          _isLikedLocally = false;
          _localLovesCount = (_localLovesCount - 1).clamp(0, 999999);
          widget.post.loves = _localLovesCount;
          widget.post.users_love_id?.remove(userId);
        });
      }
    }).whenComplete(() {
      if (mounted) setState(() => _isLiking = false);
    });
  }

// Nouveau dialog pour solde de pièces insuffisant pour le like
  void _showInsufficientCoinsForLikeDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final dc = AppColors.of(ctx);
        return AlertDialog(
          backgroundColor: dc.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            '💡 Soutenez le créateur !',
            style: TextStyle(color: dc.accent, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chaque like que vous envoyez offre 1 pièce au créateur du post !',
                style: TextStyle(color: dc.textSecondary),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: dc.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: dc.accent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Le like coûte 2 pièces :\n• Pour soutenir le créateur',
                        style: TextStyle(color: dc.textSecondary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Rechargez votre compte pour continuer à soutenir vos créateurs préférés !',
                style: TextStyle(color: dc.textSecondary, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: TextStyle(color: dc.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CoinRechargeScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: dc.accent,
                foregroundColor: dc.onAccent,
              ),
              child: const Text('Recharger', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

// Extraire la logique des notifications dans une méthode séparée
  Future<void> _sendLikeNotifications() async {
    final currentTimeMicroseconds = DateTime.now().microsecondsSinceEpoch;
    final userDoc = await firestore.collection('Users').doc(widget.post.user_id!).get();

    if (userDoc.exists) {
      final userData = userDoc.data();
      final lastNotificationTime = userData?['lastNotificationTime'] ?? 0;
      const twentyMinutesMicroseconds = 20 * 60 * 1000 * 1000;
      final timeSinceLastNotification = currentTimeMicroseconds - lastNotificationTime;

      if (timeSinceLastNotification >= twentyMinutesMicroseconds || lastNotificationTime == 0) {
        // Notification Firebase
        final notificationId = firestore.collection('Notifications').doc().id;
        final notification = NotificationData(
          id: notificationId,
          titre: "Like ❤️ + 1 pièce",
          media_url: authProvider.loginUserData.imageUrl,
          type: NotificationType.POST.name,
          description: "@${authProvider.loginUserData.pseudo!} a aimé votre post et vous a offert 1 pièce !",
          users_id_view: [],
          user_id: authProvider.loginUserData.id!,
          receiver_id: widget.post.user_id!,
          post_id: widget.post.id!,
          post_data_type: widget.post.dataType ?? PostDataType.IMAGE.name,
          updatedAt: currentTimeMicroseconds,
          createdAt: currentTimeMicroseconds,
          status: PostStatus.VALIDE.name,
        );
        await firestore.collection('Notifications').doc(notificationId).set(notification.toJson());

        // Push notification — oneSignalId depuis le doc fetchée (fallback currentUser)
        final oneSignalId = (userData?['oneIgnalUserid'] as String?)
            ?? currentUser?.oneIgnalUserid;
        if (oneSignalId != null) {
          await authProvider.sendNotification(
            userIds: [oneSignalId],
            smallImage: authProvider.loginUserData.imageUrl ?? '',
            send_user_id: authProvider.loginUserData.id!,
            recever_user_id: widget.post.user_id!,
            message: "📢 @${authProvider.loginUserData.pseudo ?? ''} a aimé votre look et vous a offert 1 pièce !",
            type_notif: NotificationType.POST.name,
            post_id: widget.post.id!,
            post_type: PostDataType.IMAGE.name,
            chat_id: '',
          );
        }

        await firestore.collection('Users').doc(widget.post.user_id!).update({
          'lastNotificationTime': currentTimeMicroseconds
        });
      }
    }

    authProvider.incrementPostTotalInteractions(postId: widget.post.id!);
    authProvider.notifySubscribersOfInteraction(
      actionUserId: authProvider.loginUserData.id!,
      postOwnerId: widget.post.user_id!,
      postId: widget.post.id!,
      actionType: 'like',
      postDescription: widget.post.description,
      postImageUrl: widget.post.images?.first,
      postDataType: widget.post.dataType,
    );
  }
  Future<void> _handleLike3() async {
    final userId = authProvider.loginUserData.id;
    if (userId == null) return;
    if (isIn(widget.post.users_love_id!, userId)) return;

    // Mise à jour UI instantanée
    setState(() {
      widget.post.loves = (widget.post.loves ?? 0) + 1;
      widget.post.users_love_id ??= [];
      widget.post.users_love_id!.add(userId);
    });

    // Firestore + notifications en arrière plan
    _processLike3Background(userId);
  }

  void _processLike3Background(String userId) {
    // Firestore likes — fire & forget
    firestore.collection('Posts').doc(widget.post.id).update({
      'loves': FieldValue.increment(1),
      'users_love_id': FieldValue.arrayUnion([userId]),
      'popularity': FieldValue.increment(1),
    });
    addPointsForAction(UserAction.like);
    addPointsForOtherUserAction(widget.post.user_id!, UserAction.autre);
    authProvider.incrementPostTotalInteractions(postId: widget.post.id!);
    authProvider.notifySubscribersOfInteraction(
      actionUserId: userId,
      postOwnerId: widget.post.user_id!,
      postId: widget.post.id!,
      actionType: 'like',
      postDescription: widget.post.description,
      postImageUrl: widget.post.images?.first,
      postDataType: widget.post.dataType,
    );

    // Notification avec contrôle 20 minutes — en arrière plan
    firestore.collection('Users').doc(widget.post.user_id!).get().then((userDoc) async {
      if (!mounted || !userDoc.exists) return;
      final nowMicro = DateTime.now().microsecondsSinceEpoch;
      final lastNotif = (userDoc.data()?['lastNotificationTime'] ?? 0) as int;
      const twentyMin = 20 * 60 * 1000 * 1000;
      if (nowMicro - lastNotif >= twentyMin || lastNotif == 0) {
        final notifId = firestore.collection('Notifications').doc().id;
        final notif = NotificationData(
          id: notifId,
          titre: "Like ❤️",
          media_url: authProvider.loginUserData.imageUrl,
          type: NotificationType.POST.name,
          description: "@${authProvider.loginUserData.pseudo ?? ''} a aimé votre post",
          users_id_view: [],
          user_id: userId,
          receiver_id: widget.post.user_id!,
          post_id: widget.post.id!,
          post_data_type: widget.post.dataType ?? PostDataType.IMAGE.name,
          updatedAt: nowMicro,
          createdAt: nowMicro,
          status: PostStatus.VALIDE.name,
        );
        await firestore.collection('Notifications').doc(notifId).set(notif.toJson());
        if (currentUser?.oneIgnalUserid != null) {
          await authProvider.sendNotification(
            userIds: [currentUser!.oneIgnalUserid!],
            smallImage: authProvider.loginUserData.imageUrl ?? '',
            send_user_id: userId,
            recever_user_id: widget.post.user_id!,
            message: "📢 @${authProvider.loginUserData.pseudo ?? ''} a aimé votre look",
            type_notif: NotificationType.POST.name,
            post_id: widget.post.id!,
            post_type: PostDataType.IMAGE.name,
            chat_id: '',
          );
        }
        await firestore.collection('Users').doc(widget.post.user_id!).update({
          'lastNotificationTime': nowMicro,
        });
      }
      widget.onLoved?.call();
    }).catchError((_) {});
  }

  Future<void> _refreshPostStats() async {
    if (widget.post.id == null || !mounted) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('Posts').doc(widget.post.id).get();
      if (doc.exists && mounted) {
        final fresh = Post.fromJson(doc.data()!);
        setState(() {
          widget.post.users_like_id = fresh.users_like_id;
          widget.post.users_love_id = fresh.users_love_id;
          widget.post.users_comments_id = fresh.users_comments_id;
          widget.post.vues = fresh.vues;
        });
      }
    } catch (_) {}
  }

  void _openDetailsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DetailsPost(post: widget.post)),
    ).then((_) => _refreshPostStats());
  }

  void _handleRepost() {
    _openDetailsPage();
  }

  void _handleGift2() {
    _showGiftDialog(widget.post);
  }



// 2. Modifier la méthode _handleGift
  void _handleGift() {
    showDialog(
      context: context,
      builder: (context) => CoinGiftDialog(
        receiverId: widget.post.user_id!,
        receiverName: widget.post.user?.pseudo ?? 'Créateur',
        receiverAvatar: widget.post.user?.imageUrl ?? '',
        post: widget.post,
        onGiftSuccess: () async {
          // Mettre à jour l'affichage local du compteur de cadeaux
          setState(() {
            widget.post.users_cadeau_id ??= [];
            if (!widget.post.users_cadeau_id!.contains(authProvider.loginUserData.id!)) {
              widget.post.users_cadeau_id!.add(authProvider.loginUserData.id!);
            }
          });

          // Rafraîchir le provider pour mettre à jour le solde
          final coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);
          await coinProvider.refreshBalance(authProvider.loginUserData.id!);

          // Afficher un snackbar de confirmation
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('🎁 Cadeau envoyé avec succès !'),
              backgroundColor: AppColors.of(context).primary,
              duration: const Duration(seconds: 2),
            ),
          );

          // 🔥 Appeler le callback parent si existant
          // widget.onGiftSuccess?.call();
        },
      ),
    );
  }

  // 🔥 MÉTHODE SHARE AVEC CALLBACK

  void _handleShare() async {
    // Activer le mode chargement
    setState(() { _isSharing = true; });

    try {
      // 1. GESTION DU THUMBNAIL POUR LES VIDÉOS
      if (widget.post.dataType == "VIDEO" &&
          (widget.post.thumbnail == null || widget.post.thumbnail!.isEmpty)) {

        // On attend la fin de la génération avant de continuer
        await checkAndGenerateThumbnail(
          postId: widget.post.id!,
          videoUrl: widget.post.url_media!,
          currentThumbnail: widget.post.thumbnail,
        );
      }

      // 2. PRÉPARATION DU PARTAGE
      String shareImageUrl = "";
      if (widget.post.dataType == "VIDEO") {
        shareImageUrl = widget.post.thumbnail ?? "";
      } else {
        shareImageUrl = (widget.post.images?.isNotEmpty ?? false) ? widget.post.images!.first : "";
      }

      final AppLinkService _appLinkService = AppLinkService();
      await _appLinkService.shareContent(
        type: AppLinkType.post,
        id: widget.post.id!,
        message: widget.post.description ?? "",
        mediaUrl: shareImageUrl,
      );

      // 3. MISE À JOUR FIREBASE & UI (Code existant)
      setState(() {
        widget.post.partage = (widget.post.partage ?? 0) + 1;
        widget.post.users_partage_id!.add(authProvider.loginUserData.id!);
      });

      await firestore.collection('Posts').doc(widget.post.id).update({
        'partage': FieldValue.increment(1),
        'users_partage_id': FieldValue.arrayUnion([authProvider.loginUserData.id]),
      });

      authProvider.checkAndRefreshPostDates(widget.post.id!);

      if (!isIn(widget.post.users_partage_id!, authProvider.loginUserData.id!)) {

        addPointsForAction(UserAction.partagePost);
        addPointsForOtherUserAction(widget.post.user_id!, UserAction.autre);
        // 🔥 APPEL DU CALLBACK LOVE
        widget.onShared?.call();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '+ de points ajoutés à votre compte',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.of(context).primary),
            ),
          ),
        );
      }

    } catch (e) {
      printVm("Erreur partage: $e");
    } finally {
      // Désactiver le chargement même en cas d'erreur
      if (mounted) {
        setState(() { _isSharing = false; });
      }
    }
  }
  // Méthode pour supprimer un post
  Future<void> _confirmAndDeletePost(Post post) async {
    if (!mounted) return;
    final colors = AppColors.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.delete_forever_rounded, color: colors.danger, size: 24),
          const SizedBox(width: 10),
          Text('Supprimer ce post', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        content: Text(
          'Ce post sera supprimé définitivement. Cette action est irréversible.',
          style: TextStyle(color: colors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Annuler', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator(color: colors.primary)),
    );

    try {
      if (authProvider.loginUserData.role != UserRole.ADM.name) {
        post.status = PostStatus.SUPPRIMER.name;
      }
      await _deletePost(post);
      if (!mounted) return;
      Navigator.pop(context); // loader
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle, color: Colors.white),
          SizedBox(width: 10),
          Text('Post supprimé avec succès'),
        ]),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 3),
      ));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // loader
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.error_outline, color: Colors.white),
          SizedBox(width: 10),
          Text('Échec de la suppression. Réessaie.'),
        ]),
        backgroundColor: colors.danger,
        duration: const Duration(seconds: 4),
      ));
    }
  }

  Future<void> _deletePost(Post post) async {
    final firestore = FirebaseFirestore.instance;
    final appDefaultRef = firestore.collection('AppData').doc(appId);

    try {
      // 🔹 Supprimer le post de Firestore
      await firestore.collection('Posts').doc(post.id).delete();
      printVm('✅ Post ${post.id} supprimé de Firestore');

      // 🔹 Retirer l'ID de allPostIds
      await appDefaultRef.update({
        'allPostIds': FieldValue.arrayRemove([post.id]),
      });
      printVm('✅ ID ${post.id} retiré de allPostIds');
    } catch (e) {
      printVm('❌ Erreur lors de la suppression du post ${post.id}: $e');
      throw e;
    }
  }

  int _selectedGiftIndex = 0;
  //Méthode pour afficher le dialogue de cadeau (simplifiée)
  List<double> giftPrices = [
    10, 25, 50, 100, 200, 300, 500, 700, 1500, 2000,
    2500, 5000, 7000, 10000, 15000, 20000, 30000,
    50000, 75000, 100000
  ];

  List<String> giftIcons = [
    '🌹','❤️','👑','💎','🏎️','⭐','🍫','🧰','🌵','🍕',
    '🍦','💻','🚗','🏠','🛩️','🛥️','🏰','💎','🏎️','🚗'
  ];
  void _showInsufficientBalanceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        final dc = AppColors.of(ctx);
        return AlertDialog(
          backgroundColor: dc.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: dc.accent, width: 2),
          ),
          title: Text(
            'Solde Insuffisant',
            style: TextStyle(
              color: dc.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Votre solde est insuffisant pour effectuer cette action. Veuillez recharger votre compte.',
            style: TextStyle(color: dc.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Annuler', style: TextStyle(color: dc.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(ctx, MaterialPageRoute(builder: (context) => DepositScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: dc.primary,
              ),
              child: Text('Recharger', style: TextStyle(color: dc.onPrimary)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendGiftFcfa(double amount) async {
    try {
      setState(() => _isLoading = true);

      final firestore = FirebaseFirestore.instance;
      await authProvider.getAppData();
      // Récupérer l'utilisateur expéditeur à jour
      final senderSnap = await firestore.collection('Users').doc(authProvider.loginUserData.id).get();
      if (!senderSnap.exists) {
        throw Exception("Utilisateur expéditeur introuvable");
      }
      final senderData = senderSnap.data() as Map<String, dynamic>;
      final double senderBalance = (senderData['votre_solde_principal'] ?? 0.0).toDouble();

      // Vérifier le solde
      if (senderBalance >= amount) {
        final double gainDestinataire = amount * 0.7;
        // final double gainApplication = amount * 0.3;

        // Débiter l'expéditeur
        await firestore.collection('Users').doc(authProvider.loginUserData.id).update({
          'votre_solde_principal': FieldValue.increment(-amount),
        });

        // Créditer le destinataire
        await firestore.collection('Users').doc(widget.post.user!.id).update({
          'votre_solde_principal': FieldValue.increment(gainDestinataire),
        });

        // Créditer l'application
        String appDataId = authProvider.appDefaultData.id!;


        if(widget.post.user!.codeParrain!=null){

          if(authProvider.loginUserData!.codeParrain!=null){
            final double gainApplication = amount * 0.25;

            await firestore.collection('AppData').doc(appDataId).update({
              'solde_gain': FieldValue.increment(gainApplication),
            });
            authProvider.ajouterCadeauCommissionParrain(codeParrainage: authProvider.loginUserData!.codeParrain!, montant: amount);
            authProvider.ajouterCadeauCommissionParrain(codeParrainage: widget.post.user!.codeParrain!, montant: amount);

          }
          else{
            final double gainApplication = amount * 0.25;

            await firestore.collection('AppData').doc(appDataId).update({
              'solde_gain': FieldValue.increment(gainApplication),
            });
            authProvider.ajouterCommissionParrain(codeParrainage: widget.post.user!.codeParrain!, montant: amount);

          }

        }else{
          if(authProvider.loginUserData!.codeParrain!=null){
            final double gainApplication = amount * 0.25;

            await firestore.collection('AppData').doc(appDataId).update({
              'solde_gain': FieldValue.increment(gainApplication),
            });
            authProvider.ajouterCommissionParrain(codeParrainage: authProvider.loginUserData!.codeParrain!, montant: amount);

          }
          else{
            final double gainApplication = amount * 0.3;

            await firestore.collection('AppData').doc(appDataId).update({
              'solde_gain': FieldValue.increment(gainApplication),
            });

          }
        }

        // Ajouter l'expéditeur à la liste des cadeaux du post
        await firestore.collection('Posts').doc(widget.post.id).update({
          'users_cadeau_id': FieldValue.arrayUnion([authProvider.loginUserData.id]),
          'popularity': FieldValue.increment(5), // pondération pour un commentaire
        });

        // Créer les transactions
        await _createTransaction(TypeTransaction.DEPENSE.name, amount, "Cadeau envoyé à @${widget.post.user!.pseudo}",authProvider.loginUserData.id!);
        await _createTransaction(TypeTransaction.GAIN.name, gainDestinataire, "Cadeau reçu de @${authProvider.loginUserData.pseudo}",widget.post.user_id!);
        addPointsForAction(UserAction.cadeau);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.of(context).primary,
            content: Text(
              '🎁 Cadeau de ${amount.toInt()} FCFA envoyé avec succès!',
              style: TextStyle(color: AppColors.of(context).onPrimary),
            ),
          ),
        );
        await authProvider.sendNotification(
          userIds: [widget.post.user!.oneIgnalUserid!],
          smallImage: "", // pas besoin de montrer l'image de l'expéditeur
          send_user_id: "", // pas besoin de l'expéditeur
          recever_user_id: "${widget.post.user_id!}",
          message: "🎁 Vous avez reçu un cadeau de ${amount.toInt()} FCFA !",
          type_notif: NotificationType.POST.name,
          post_id: "${widget.post!.id!}",
          post_type: PostDataType.IMAGE.name,
          chat_id: '',
        );
      } else {
        _showInsufficientBalanceDialog();
      }
    } catch (e) {
      printVm("Erreur envoi cadeau: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.of(context).danger,
          content: Text(
              "Erreur lors de l'envoi du cadeau",
          style: TextStyle(color: AppColors.of(context).onPrimary),
        ),
      ),
    );
    } finally {
    setState(() => _isLoading = false);
    }
  }
  void _showGiftDialog(Post post) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        final dc = AppColors.of(ctx);
        final height = MediaQuery.of(ctx).size.height * 0.6;
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: dc.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: dc.accent, width: 2),
              ),
              child: Container(
                height: height,
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Envoyer un Cadeau',
                      style: TextStyle(
                        color: dc.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Choisissez le montant en FCFA',
                      style: TextStyle(color: dc.textSecondary),
                    ),
                    SizedBox(height: 12),
                    // -----------------------------
                    // Expanded pour GridView scrollable
                    Expanded(
                      child: GridView.builder(
                        physics: BouncingScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: giftPrices.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () => setState(() => _selectedGiftIndex = index),
                            child: Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _selectedGiftIndex == index
                                    ? dc.primary
                                    : dc.surfaceVariant,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _selectedGiftIndex == index
                                      ? dc.accent
                                      : Colors.transparent,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    giftIcons[index],
                                    style: TextStyle(fontSize: 24),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    '${giftPrices[index].toInt()} FCFA',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: dc.textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Votre solde: ${authProvider.loginUserData.votre_solde_principal?.toInt() ?? 0} FCFA',
                      style: TextStyle(
                        color: dc.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Annuler', style: TextStyle(color: dc.textSecondary)),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _sendGiftFcfa(giftPrices[_selectedGiftIndex]);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: dc.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Envoyer',
                            style: TextStyle(color: dc.onPrimary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  Future<void> _createTransaction(String type, double montant, String description,String userid) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    try {
      final transaction = TransactionSolde()
        ..id = firestore.collection('TransactionSoldes').doc().id
        ..user_id =userid
        ..type = type
        ..statut = StatutTransaction.VALIDER.name
        ..description = description
        ..montant = montant
        ..methode_paiement = "cadeau"
        ..createdAt = DateTime.now().millisecondsSinceEpoch
        ..updatedAt = DateTime.now().millisecondsSinceEpoch;

      await firestore.collection('TransactionSoldes').doc(transaction.id).set(transaction.toJson());
    } catch (e) {
      printVm("Erreur création transaction: $e");
    }
  }

  // Méthodes existantes conservées (simplifiées pour l'exemple)
  void showRepublishDialog(Post post, UserData userSendCadeau, AppDefaultData appdata, BuildContext context) {
    // Implémentation existante conservée
    showDialog(
      context: context,
      builder: (context) {
        final dialogColors = AppColors.of(context);
        return AlertDialog(
          backgroundColor: dialogColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "✨ Republier",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: dialogColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          content: Text(
            "🔝 Cette action mettra votre post en première position.\n\n💰 1 PC sera retiré de votre compte principal.",
            textAlign: TextAlign.center,
            style: TextStyle(color: dialogColors.textSecondary, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("❌ Fermer", style: TextStyle(color: dialogColors.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                // Logique existante
              },
              child: Text("🚀 Republier", style: TextStyle(color: dialogColors.info)),
            ),
          ],
        );
      },
    );
  }

// Méthodes utilitaires globales
  bool isIn(List<String> list, String value) {
    return list.contains(value);
  }

  bool isUserAbonne(List<String> abonnesIds, String userId) {
    return abonnesIds.contains(userId);
  }
}
void showInsufficientBalanceDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      final dialogColors = AppColors.of(context);
      return AlertDialog(
        backgroundColor: dialogColors.surface,
        title: Text("Solde insuffisant", style: TextStyle(color: dialogColors.textPrimary)),
        content: Text("Votre solde principal est insuffisant.", style: TextStyle(color: dialogColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Fermer", style: TextStyle(color: dialogColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => MonetisationPage()));
            },
            child: Text("Recharger", style: TextStyle(color: dialogColors.info)),
          ),
        ],
      );
    },
  );
}



