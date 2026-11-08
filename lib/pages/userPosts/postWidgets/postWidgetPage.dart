import '../../../ads/gold_gate.dart';
import 'package:afrotok/services/post_reply.dart';
import '../../../widgets/commerce_card.dart';
import '../../../services/api/commerce_api.dart';
import '../../studio/montage/montage_pin.dart';
import 'package:afrotok/services/post_orientation.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/services/read_meter.dart';
import '../../../services/comments_prefetch.dart';
import '../../../widgets/original_badge.dart';
import '../../../widgets/post_widget_view.dart';
import '../../videos/video_chrome.dart';
import '../../create/create_hub_page.dart';
import '../../../widgets/studio/post_template_try.dart';
import '../../defi/defi_boost.dart';
import 'package:afrotok/widgets/link_preview_card.dart';
import 'package:afrotok/widgets/name_tag.dart';
import '../../../services/followers_count_service.dart';
import '../../../utils/count_format.dart';
import 'package:afrotok/utils/responsive_sheet.dart';
import 'package:afrotok/pages/user/userPubs/user_create_advertisement_page.dart';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:afrotok/services/block_service.dart';
import 'package:afrotok/pages/defi/defi_ui.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'dart:math';

import 'package:afrotok/pages/user/monetisation.dart';

import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/canal_mapper.dart';
import 'package:afrotok/services/api/posts_api.dart';
import 'package:afrotok/services/api/publications_api.dart';
import 'package:afrotok/services/api/users_api.dart';
import 'package:afrotok/services/api/users_mapper.dart';
import 'package:afrotok/widgets/api_error_dialogs.dart';

import 'package:hashtagable_v3/widgets/hashtag_text.dart';

import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:flutter_animate/flutter_animate.dart';

import '../../../models/model_data.dart';
import '../../../services/follow_service.dart';
import '../../../theme/app_colors.dart';
import '../../cards/card_entry.dart';
import '../../defi/defi_convert.dart';
import '../../../providers/locale_provider.dart';
import '../../../l10n/app_localizations.dart';
import 'translatable_description.dart';

import '../../../providers/coin_gift_provider.dart';
import '../../../providers/sound_provider.dart';
import '../../../services/linkService.dart';
import '../../../services/utils/abonnement_utils.dart';
import '../../../widgets/user_badge_widget.dart';
import '../../../widgets/double_tap_like.dart';
import '../../../widgets/like_coins_helper.dart';
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
import '../reply_videos_page.dart';

import '../../component/showUserDetails.dart';
import '../../postComments.dart';
import '../../postDetails.dart';
import '../../postDetailsVideo.dart';
import '../../post_video_format_tel_details.dart';
import '../../pub/afrolook_inline_ad.dart';
import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/services/api/post_social_api.dart';
import 'package:afrotok/widgets/post_social_actions.dart';
import '../../widgetGlobal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../youTube_video_card.dart';
import 'audioPostWidget.dart';
import '../../../services/postService/post_view_service.dart';
import '../../../services/postService/feed_interaction_service.dart';
import '../../../services/streak_service.dart';
import '../../../providers/streakProvider.dart';
import 'package:afrotok/services/comment_coins.dart';
import 'package:afrotok/widgets/post_coins_earned.dart';
import '../../../ads/ad_slot.dart';
import '../../studio/artist_marketplace.dart';
import '../../../widgets/feed/sections/news_feed_card.dart';



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
  final String? feedTier;
  // Si fourni, surcharge la navigation par défaut (utilisé dans les suggestions des pages de détails)
  final void Function(Post)? onOpenPost;

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
    this.feedTier,
    this.onOpenPost,
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
  bool _isFavorite = false;
  bool _isProcessingFavorite = false;
  Random random = Random();
  bool _isLoading = false;
  bool _isProcessingFollow = false;
  bool _removedByDelete = false; // la publication vient d'être supprimée : la carte disparaît tout de suite, sans attendre l'actualisation du fil
  bool _isSupporting = false;
  bool? _hasSeenSupportModal; // null = pas encore chargé
  // Variables pour stocker les données récupérées individuellement
  UserData? _currentUser;
  Canal? _currentCanal;
  bool _isLoadingUser = false;
  bool _isLoadingCanal = false;
  bool _isLiking = false;
  bool _isVoting = false;
  int _localDefiVotes = 0;
  bool _hasVotedLocally = false;
  final GlobalKey _voteBtnKey = GlobalKey();
  late AnimationController _voteAnimController;
  late Animation<double> _voteScaleAnim;
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
  // url → isPortrait détecté depuis les dimensions réelles de l'image
  final Map<String, bool> _imageOrientations = {};

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
Future<bool> _hasSupportedToday(String postId, String userId) async => false;

// Enregistrer le soutien
Future<void> recordUniquePostView() async {
    // La vue (unique par personne et par publication) est comptée par le serveur, gains compris.
    final postId = widget.post.id;
    if (postId == null) return;
    await ApiGateway.instance.markViewed(postId);
  }

// Nettoyer les ressources audio quand le widget est détruit
  // 🔥 S'assurer d'avoir authProvider et appDefaultData
  late AppDefaultData appDefaultData;
  void _onBlockListChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    BlockService.instance.addListener(_onBlockListChanged);
    _voteAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _voteScaleAnim = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _voteAnimController, curve: Curves.elasticOut),
    );
    final swInit = Stopwatch()..start();
    final postId = widget.post.id ?? '?';
    final isCanalPost = widget.post.canal_id != null && widget.post.canal_id!.isNotEmpty;
    printVm('⏱️ [POST-WIDGET] id=$postId canal=$isCanalPost — initState start');

    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);

    postProvider = Provider.of<PostProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    appDefaultData = authProvider.appDefaultData;
    _initLikeState();
    _initFromSnapshot();
    final snapMs = swInit.elapsedMilliseconds;
    final hadSnapshot = isCanalPost ? widget.post.canalSnapshot != null : widget.post.creatorSnapshot != null;
    printVm('⏱️ [POST-WIDGET] id=$postId — snapshot=${hadSnapshot ? "✅ ${snapMs}ms (affichage immédiat)" : "❌ pas de snapshot → chargement du profil par l'API"}');

    _loadUserData();
    _loadCanalData();
    _generateVideoThumbnail();

    _checkIfFavorite();
    _loadSupportModalSeen();
    _loadLastComment();
    // Détection orientation pour toutes les images du post
    for (final img in widget.post.images ?? []) {
      if (img.isNotEmpty) _detectImageOrientation(img);
    }
  }

  void _detectImageOrientation(String rawUrl) {
    final url = _optimizeUrl(rawUrl);
    if (_imageOrientations.containsKey(url)) return;
    final provider = NetworkImage(url);
    provider.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener(
        (ImageInfo info, bool _) {
          if (!mounted) return;
          setState(() {
            _imageOrientations[url] = info.image.height > info.image.width;
          });
        },
        onError: (_, __) {
          if (!mounted) return;
          // En cas d'erreur, on suppose portrait
          setState(() { _imageOrientations[url] = true; });
        },
      ),
    );
  }


  void _initLikeState() {
    final userId = authProvider.loginUserData.id;
    _isLikedLocally = widget.post.users_love_id?.contains(userId) ?? false;
    _localLovesCount = widget.post.loves ?? 0;
    _localCommentsCount = widget.post.comments ?? 0;
    _localDefiVotes = widget.post.defiVotes ?? 0;
    _hasVotedLocally = widget.post.defiVoterIds?.contains(userId) ?? false;
  }

  /// Charge créateur/canal depuis le snapshot dénormalisé stocké dans le post.
  /// Synchrone — appelé avant _loadUserData/_loadCanalData pour un affichage immédiat.
  void _initFromSnapshot() {
    final post = widget.post;
    final isCanalPost = post.canal_id != null && post.canal_id!.isNotEmpty;
    if (isCanalPost) {
      if (post.canal != null) { _currentCanal = post.canal; return; }
      final snap = post.canalSnapshot;
      if (snap != null) {
        _currentCanal = Canal()
          ..id = post.canal_id
          ..titre = snap['titre'] as String?
          ..urlImage = snap['urlImage'] as String?
          ..suivi = snap['suivi'] as int? ?? 0;
      }
    } else {
      if (post.user != null) { _currentUser = post.user; return; }
      final snap = post.creatorSnapshot;
      if (snap != null) {
        _currentUser = UserData()
          ..pseudo = snap['pseudo'] as String?
          ..imageUrl = snap['imageUrl'] as String?
          ..abonnes = snap['abonnes'] as int? ?? 0;
      }
    }
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
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == widget.post.user_id) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).postSupportCannotSelf), backgroundColor: AppColors.of(context).warning),
      );
      return;
    }
    if (await PostSocialApi.supportedToday(widget.post.id!)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('Tu as déjà soutenu cette publication aujourd\'hui. Reviens demain !')), backgroundColor: AppColors.of(context).warning),
        );
      }
      return;
    }
    if (_hasSeenSupportModal == null) await _loadSupportModalSeen();
    if (_hasSeenSupportModal == false) {
      if (mounted) _showSupportModal();
      return;
    }
    _startSupportAd();
  }

  /// Pub récompensée regardée en entier, déclarée au serveur puis consommée par `POST /posts/{id}/support-ad` (messages et « Réessayer » inclus).
  Future<void> _startSupportAd() async {
    if (_isSupporting) return;
    setState(() => _isSupporting = true);
    await PostSocialActions.supportWithAd(context, widget.post, myId: authProvider.loginUserData.id, onSupported: (_) {
      if (mounted) setState(() {});
    });
    if (mounted) setState(() => _isSupporting = false);
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
    BlockService.instance.removeListener(_onBlockListChanged);
    _voteAnimController.dispose();
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
        builder: (c) => VideoYoutubePageDetails(initialPost: widget.post, feedTier: widget.feedTier),
      ));
      return;
    }
    setState(() { _isPreviewPlaying = true; _showPreviewCta = false; });
    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(_optimizeUrl(url)));
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
        builder: (c) => VideoYoutubePageDetails(initialPost: widget.post, feedTier: widget.feedTier),
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
    final wasFavorite = _isFavorite;

    setState(() {
      _isProcessingFavorite = true;
    });

    try {
      if (wasFavorite) {
        await PostsApi.unfavorite(postId);
      } else {
        await PostsApi.favorite(postId);
      }

      if (!mounted) return;
      setState(() {
        _isFavorite = !wasFavorite;
        widget.post.users_favorite_id ??= [];
        if (_isFavorite) {
          widget.post.favoritesCount = (widget.post.favoritesCount ?? 0) + 1;
          widget.post.users_favorite_id!.add(userId);
        } else {
          widget.post.favoritesCount = ((widget.post.favoritesCount ?? 1) - 1).clamp(0, 1 << 31);
          widget.post.users_favorite_id!.remove(userId);
        }
      });

      if (_isFavorite) {
        widget.onLoved?.call();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFavorite ? '✅ Post ajouté aux favoris' : '🗑️ Post retiré des favoris',
            style: TextStyle(color: AppColors.of(context).onPrimary),
          ),
          backgroundColor: _isFavorite ? AppColors.of(context).primary : AppColors.of(context).surfaceVariant,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      printVm('Erreur toggle favori: $e');
      if (mounted) showApiError(context, e, onRetry: _toggleFavorite, fallback: '❌ Erreur lors de la modification');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingFavorite = false;
        });
      }
    }
  }

  Future<void> _loadUserData() async {
    // Pseudo et avatar viennent déjà avec la publication ; le profil complet est lu via l'API (GET /users/{id}, voir lacunes_api_publications.md).
    if (widget.post.user_id == null || !mounted) return;
    if (_currentUser == null && widget.post.user != null) {
      setState(() => _currentUser = widget.post.user);
    }
    try {
      final full = userFromApi(await UsersApi.publicProfile(widget.post.user_id!));
      if (mounted) {
        setState(() {
          _currentUser = full;
          widget.post.user = full;
        });
      }
    } catch (e) {
      printVm('Profil de auteur indisponible : $e');
    }
  }

Future<void> _loadCanalData() async {
    if (widget.post.canal_id == null || widget.post.canal_id!.isEmpty) return;
    if (!mounted) return;

    final hasData = _currentCanal != null || widget.post.canal != null;
    if (!hasData) {
      setState(() { _isLoadingCanal = true; });
    }

    try {
      final r = await ApiGateway.instance.client.get('/channels/${widget.post.canal_id}');
      final d = (r as Map)['data'];
      if (d is Map && mounted) {
        setState(() {
          _currentCanal = canalFromApi(Map<String, dynamic>.from(d));
          widget.post.canal = _currentCanal;
        });
      }
    } catch (e) {
      printVm('Erreur lors du chargement du canal: $e');
    } finally {
      if (mounted && _isLoadingCanal) {
        setState(() { _isLoadingCanal = false; });
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
    if (_removedByDelete) return const SizedBox.shrink();
    // Article d'actualité : jamais le rendu d'un post ordinaire (qui n'en montrerait que le chapô, sans ses sources)
    if (widget.post.type == 'NEWS' && (widget.post.id ?? '').isNotEmpty) {
      return NewsFeedCard(key: ValueKey('news_post_${widget.post.id}'), slotKey: 'post_${widget.post.id}', postId: widget.post.id);
    }
    // Appui long : menu du post (avec « Créer une carte Afrolook »)
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: () {
        if (widget.post.isAdvertisement == true || widget.post.user == null) return;
        HapticFeedback.mediumImpact();
        _showPostMenu(widget.post);
      },
      child: _buildPostBody(context),
    );
  }

  Widget _buildPostBody(BuildContext context) {
    if (BlockService.instance.isBlocked(widget.post.user_id)) return const SizedBox.shrink();
    final colors = AppColors.of(context);
    final h = MediaQuery.of(context).size.height;
    final w = widget.width;

    if (_isLoadingUser || _isLoadingCanal) {
      return _buildSkeletonLoader();
    }

    final isLocked = _isLockedContent();
    final hasAccess = _hasAccessToContent();

    // ── Layout Threads : avatar + fil à gauche, contenu à droite ──────────────
    return Container(
      color: colors.background,
      child: Stack(
        children: [
          // Fil vertical sous l'avatar (connecte les posts visuellement)
          Positioned(
            left: 29, // 12 padding + 18 (centre du cercle 36px)
            top: 56,  // 12 padding + 36 avatar + 8 gap
            bottom: 0,
            child: Container(width: 2, color: colors.divider),
          ),
          // Contenu principal
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Colonne gauche : avatar
                _buildAvatarWidget(w, h),
                const SizedBox(width: 9),
                // Colonne droite : tout le contenu du post
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.post.isRepost == true)
                        _buildRepostBanner(),
                      _buildPostHeaderInfo(w, h),
                      const SizedBox(height: 4),
                      _buildPostContent(isLocked),
                      if (widget.post.dataType == PostDataType.AUDIO.name) ...[
                        const SizedBox(height: 8),
                        AudioPostCard(post: widget.post, isLocked: isLocked),
                        const SizedBox(height: 8),
                      ],
                      if ((widget.post.images?.isNotEmpty ?? false) &&
                          widget.post.dataType != PostDataType.AUDIO.name) ...[
                        const SizedBox(height: 8),
                        Stack(children: [
                          _buildMediaContent(h, isLocked),
                          if (!isLocked && widget.post.widgets.isNotEmpty) Positioned.fill(child: PostWidgetsLayer(widgets: widget.post.widgets)),
                        ]),
                      ],
                      if (_isVideoPost(widget.post)) ...[
                        const SizedBox(height: 8),
                        Stack(children: [
                          _buildVideoContent(h, isLocked),
                          if (!isLocked && widget.post.widgets.isNotEmpty) Positioned.fill(child: PostWidgetsLayer(widgets: widget.post.widgets)),
                        ]),
                      ],
                      if (isLocked && _showCanalLockCta) _buildSubscribeButton(),
                      if (!widget.isAdContext) ...[
                        if (widget.post.artistSoundId != null && widget.post.artistSoundId!.isNotEmpty)
                          PostSoundCredit(soundId: widget.post.artistSoundId!, title: widget.post.artistSoundTitle ?? ''),
                          PostTemplateTry(post: widget.post),
                        const SizedBox(height: 10),
                        _buildPostActions(hasAccess),
                        _buildCommentPreview(hasAccess),
                        PostGiftsList(
                          postId: widget.post.id!,
                          compactLevel: CompactLevel.light,
                          maxDisplayItems: 10,
                        ),
                      ],
                      if (!widget.isAdContext && !widget.suppressInlineAd &&
                          _shouldShowAd && widget.post.isAdvertisement != true) ...[
                        const SizedBox(height: 12),
                        AdSlot(key: ValueKey('post_inline_ad_${widget.post.id}'), kind: AdSlotKind.feed, own: () => const AfrolookInlineAd()),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Ligne de séparation basse entre les posts
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(height: 0.5, color: colors.divider),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.03, end: 0, duration: 300.ms, curve: Curves.easeOut);
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
  // ── Mention de republication ─────────────────────────────────────────────────
  Widget _buildRepostBanner() {
    final colors = AppColors.of(context);
    final reposterPseudo = widget.post.reposterPseudo ?? '';
    final reposterImageUrl = widget.post.reposterImageUrl;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          if (reposterImageUrl != null && reposterImageUrl.isNotEmpty)
            ClipOval(
              child: Image.network(reposterImageUrl, width: 16, height: 16, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(Icons.repeat, size: 14, color: colors.textSecondary)),
            )
          else
            Icon(Icons.repeat, size: 14, color: colors.textSecondary),
          const SizedBox(width: 5),
          Text(
            tr('@{p} a republié', {'p': reposterPseudo}),
            style: TextStyle(fontSize: 12, color: colors.textSecondary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ── Logique de republication ─────────────────────────────────────────────────
Future<void> _handleRepost() async {
    final me = context.read<UserAuthProvider>().loginUserData;
    // Le serveur enregistre la republication (une par personne), la compte comme un partage et la diffuse aux abonnés.
    await PostSocialActions.repost(context, widget.post, myId: me.id, onDone: () {
      if (mounted) setState(() {});
    });
  }

  // ── Avatar seul (36px) pour la colonne gauche du layout Threads ─────────────
  Widget _buildAvatarWidget(double w, double h) {
    final colors = AppColors.of(context);
    final isCanalPost = currentCanal != null;
    return GestureDetector(
      onTap: () {
        if (isCanalPost) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => CanalDetails(canal: currentCanal!),
          ));
        } else if (currentUser != null) {
          showUserDetailsModalDialog(currentUser!, w, h, context);
        }
      },
      child: isCanalPost
          ? Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8),
                color: colors.primary,
                image: _getProfileImage() != null
                    ? DecorationImage(image: _getProfileImage()!, fit: BoxFit.cover)
                    : null,
              ),
              child: _getProfileImage() == null
                  ? Icon(Icons.group, color: colors.onPrimary, size: 16)
                  : null,
            )
          : CircleAvatar(
              radius: 18,
              backgroundColor: colors.primary,
              backgroundImage: _getProfileImage(),
              child: _getProfileImage() == null
                  ? Icon(Icons.person, color: colors.onPrimary, size: 16)
                  : null,
            ),
    );
  }

  // ── En-tête (nom + badges + follow + menu) sans avatar ────────────────────
  Widget _buildPostHeaderInfo(double w, double h) {
    final colors = AppColors.of(context);
    final currentUserId = authProvider.loginUserData.id;
    final isCanalPost = currentCanal != null;
    final dynamic postOwner = isCanalPost ? currentCanal : currentUser;
    final isCurrentUser = currentUserId == currentUser?.id;
    final subscriptionLoaded = isCanalPost
        ? currentCanal?.usersSuiviId != null
        : FollowService.isKnown(authProvider.loginUserData, currentUser);
    final isAbonne = isCanalPost
        ? currentCanal?.usersSuiviId?.contains(currentUserId) ?? false
        : FollowService.isFollowing(authProvider.loginUserData, currentUser);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: NameTag(label: _getDisplayName(),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                      overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 3),
                  UserBadgeWidget(user: widget.post.user, size: 13),
                  if (currentCanal == null && (widget.post.user?.commentStreak ?? 0) >= 1)
                    _buildFlameStreakBadge(widget.post.user!.commentStreak),
                ],
              ),
              _followersText(TextStyle(color: colors.textSecondary, fontSize: 11)),
            ],
          ),
        ),
        if (!isCurrentUser && subscriptionLoaded && !isAbonne && postOwner != null)
          _buildFollowButton(isCanalPost, postOwner!, isAbonne),
        const SizedBox(width: 4),
        _buildCountryBadge(widget.post),
        GestureDetector(
          onTap: () => _showPostMenu(widget.post),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(Icons.more_horiz, color: colors.textSecondary, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildPostHeader(double w, double h) {
    final colors = AppColors.of(context);
    final currentUserId = authProvider.loginUserData.id;
    final isCanalPost = currentCanal != null;
    final dynamic postOwner = isCanalPost ? currentCanal : currentUser;
    final isCurrentUser = currentUserId == currentUser?.id;

    // Vérifier si déjà abonné — uniquement si la liste est chargée (non null).
    // Si null = données pas encore chargées → on masque le bouton pour éviter
    // d'afficher "Suivre/S'abonner" à tort à quelqu'un qui suit déjà.
    final subscriptionLoaded = isCanalPost
        ? currentCanal?.usersSuiviId != null
        : FollowService.isKnown(authProvider.loginUserData, currentUser);
    final isAbonne = isCanalPost
        ? currentCanal?.usersSuiviId?.contains(currentUserId) ?? false
        : FollowService.isFollowing(authProvider.loginUserData, currentUser);

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
          // Avatar : rond pour un utilisateur, carré (sans bordure) pour un canal
          child: isCanalPost
              ? Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(10),
                    color: colors.primary,
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
                        NameTag(label: _getDisplayName(),
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          )),
                        SizedBox(width: 4),
                        UserBadgeWidget(user: widget.post.user, size: 14),
                        if (currentCanal == null && (widget.post.user?.commentStreak ?? 0) >= 1)
                          _buildFlameStreakBadge(widget.post.user!.commentStreak),
                      ],
                    ),
                  ),

                  // Bouton S'abonner uniquement si le statut est confirmé chargé
                  if (!isCurrentUser && subscriptionLoaded && !isAbonne && postOwner != null)
                    _buildFollowButton(isCanalPost, postOwner!, isAbonne),
                  SizedBox(width: 5),
                  _buildCountryBadge(widget.post)
                ],
              ),
              _followersText(TextStyle(color: colors.textSecondary, fontSize: 12), topGap: 2),
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

    // Vérifier si déjà abonné — uniquement si la liste est chargée (non null)
    final subscriptionLoaded2 = isCanalPost
        ? currentCanal?.usersSuiviId != null
        : FollowService.isKnown(authProvider.loginUserData, currentUser);
    final isAbonne = isCanalPost
        ? currentCanal?.usersSuiviId?.contains(currentUserId) ?? false
        : FollowService.isFollowing(authProvider.loginUserData, currentUser);

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
                        NameTag(label: _getDisplayName(),
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          )),
                        SizedBox(width: 4),
                        // if (_isVerified())
                          UserBadgeWidget(user: widget.post.user, size: 14),
                        if (currentCanal == null && (widget.post.user?.commentStreak ?? 0) >= 1)
                          _buildFlameStreakBadge(widget.post.user!.commentStreak),
                      ],
                    ),
                  ),

                  // Bouton S'abonner uniquement si statut confirmé chargé
                  if (!isCurrentUser && subscriptionLoaded2 && !isAbonne && postOwner != null)
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
              _followersText(TextStyle(color: colors.textSecondary, fontSize: 12), topGap: 2),
              if (OriginalBadge.isCaptured(widget.post.captureSource) || VoiceChangedBadge.has(widget.post.voiceEffect) || widget.post.authenticity != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 6, runSpacing: 4, children: [
                    if (OriginalBadge.isCaptured(widget.post.captureSource)) const OriginalBadge(),
                    if (VoiceChangedBadge.has(widget.post.voiceEffect)) const VoiceChangedBadge(),
                    // authenticité : « Validé » après plusieurs contrôles propres ; « Non monétisé » si la marque d'un autre réseau a été vue
                    if (widget.post.authenticity == 'validated') const AuthenticBadge(compact: true),
                    if (widget.post.authenticity == 'flagged')
                      GestureDetector(
                        onTap: () => showNotMonetizedSheet(context, mark: widget.post.authenticityMark ?? 'other'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFFFFC400), borderRadius: BorderRadius.circular(99)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.warning_amber_rounded, size: 11, color: Color(0xFF3A2C00)),
                            const SizedBox(width: 3),
                            Text(context.tr('Non monétisé'), style: const TextStyle(color: Color(0xFF3A2C00), fontSize: 9, fontWeight: FontWeight.w800)),
                          ]),
                        ),
                      ),
                  ])),
                ),
              if (widget.post.replyToPostId != null) Align(alignment: Alignment.centerLeft, child: ReplyToLine(username: widget.post.replyToUsername, excerpt: widget.post.replyToExcerpt, onTap: _openReplyTarget)),
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
      final country = AfricanCountry.everyCountry.firstWhere(
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

    // Badge discret : fond légèrement teinté, pas de couleur vive
    final isDark = colors.isDark;
    final pillBg = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.05);
    final labelColor = isDark
        ? Colors.white.withOpacity(0.55)
        : Colors.black.withOpacity(0.40);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.black.withOpacity(0.08);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: pillBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(flagEmoji, style: const TextStyle(fontSize: 10)),
          if (displayText.isNotEmpty) ...[
            const SizedBox(width: 3),
            Text(
              displayText,
              style: TextStyle(
                color: labelColor,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
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
    final text = (_translatedDescription ?? widget.post.description ?? '')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')  // lignes vides avec espaces → vraie ligne vide
        .replaceAll(RegExp(r'\n{3,}'), '\n\n'); // max 2 sauts de ligne consécutifs

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
              Icon(Icons.lock, color: colors.accentText, size: 16),
              SizedBox(width: 4),
              Text(
                AppLocalizations.of(context).postLockedSubscribers,
                style: TextStyle(
                  color: colors.accentText,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      );
    }

    final words = text.split(' ');
    final isLong = words.length > 25;
    final displayedText = _isExpanded || !isLong
        ? text
        : words.take(25).join(' ') + '...';

    // Posts avec images ou vidéos : affiche la description au-dessus du média
    // Posts texte uniquement : affiche la description seule
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (text.isNotEmpty) ...[
          GestureDetector(
            onTap: _openDetailsPage,
            child: HashTagText(
              text: displayedText,
              decoratedStyle: TextStyle(fontSize: 15, color: colors.info, fontWeight: FontWeight.w400, height: 1.4),
              basicStyle: TextStyle(fontSize: 15, color: colors.textPrimary, fontWeight: FontWeight.w400, height: 1.4),
              onTap: (_) {},
            ),
          ),
          // "Voir plus" et "Voir la traduction" sur la même ligne
          Wrap(
            spacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (isLong)
                GestureDetector(
                  onTap: _openDetailsPage,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(AppLocalizations.of(context).commonSeeMore,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.info)),
                  ),
                ),
              TranslatableDescription(
                postId: widget.post.id ?? '',
                text: widget.post.description ?? '',
                targetLang: Provider.of<LocaleProvider>(context, listen: false).locale.languageCode,
                onToggle: (t) => setState(() => _translatedDescription = t),
                style: TextStyle(color: colors.textPrimary),
              ),
            ],
          ),
        ],
        if (widget.post.linkPreview != null)
          LinkPreviewCard(data: widget.post.linkPreview!, margin: const EdgeInsets.only(top: 8, bottom: 4)),
        _buildEventBadge(widget.post),
      ],
    );
  }

  Widget _buildMediaContent(double h, bool isLocked) {
    final colors = AppColors.of(context);
    final images = widget.post.images!;
    final imageCount = images.length;

    if (imageCount == 1) {
      // ── Image unique : aspect ratio selon orientation détectée ─────────────
      final imgUrl = _optimizeUrl(images[0]);
      final isPortrait = _imageOrientations[imgUrl] ?? true; // défaut portrait
      final aspectRatio = isPortrait ? (4.0 / 5.0) : (16.0 / 9.0);

      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.textSecondary.withOpacity(0.18), width: 0.8),
        ),
        child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: isLocked ? 0.15 : 1.0,
                child: GestureDetector(
                  onTap: _openDetailsPage,
                  child: CachedNetworkImage(
                    imageUrl: imgUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: colors.shimmerBase),
                    errorWidget: (context, url, error) => Container(
                      color: colors.shimmerBase,
                      child: Icon(Icons.broken_image, color: colors.textSecondary),
                    ),
                  ),
                ),
              ),
              if (isLocked)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.6),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.lock, color: colors.accentText, size: 50),
                          const SizedBox(height: 8),
                          Text('Contenu verrouillé', style: TextStyle(
                            color: colors.accentText, fontSize: 16, fontWeight: FontWeight.bold,
                          )),
                          const SizedBox(height: 4),
                          const Text('Abonnez-vous pour voir ce contenu',
                              style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    }

    // ── 2+ images : grille avec cellules carrées ─────────────────────────────
    final double gridHeight = imageCount == 2 ? 152.0 : 190.0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.textSecondary.withOpacity(0.18), width: 0.8),
      ),
      child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: gridHeight,
        child: Stack(
          children: [
            Opacity(
              opacity: isLocked ? 0.15 : 1.0,
              child: _buildImageGrid(gridHeight, imageCount),
            ),
            if (isLocked)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock, color: colors.accentText, size: 50),
                        const SizedBox(height: 8),
                        Text('Contenu verrouillé', style: TextStyle(
                          color: colors.accentText, fontSize: 16, fontWeight: FontWeight.bold,
                        )),
                        const SizedBox(height: 4),
                        const Text('Abonnez-vous pour voir ce contenu',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            if (imageCount > 1 && !isLocked)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.photo_library, color: Colors.white, size: 14),
                      const SizedBox(width: 5),
                      Text('$imageCount', style: const TextStyle(
                        color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold,
                      )),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }

// 🔥 MÉTHODE MODIFIÉE POUR PRENDRE LA HAUTEUR EN PARAMÈTRE
  Widget _buildImageGrid(double height, int imageCount) {
    final images = widget.post.images!;

    if (imageCount == 1) {
      return _buildSingleImage(images[0], height);
    } else if (imageCount == 2) {
      return _buildTwoImages(images, height);
    } else {
      // 3+ images : layout 1 grande + 2 petites.
      // Si plus de 3, la dernière petite affiche "+N" pour les images cachées.
      final extra = imageCount > 3 ? imageCount - 3 : 0;
      return _buildThreeImages(images, height, extraCount: extra);
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

  Widget _buildThreeImages(List<String> images, double height, {int extraCount = 0}) {
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

                  // Troisième image - moitié inférieure (+ badge si images cachées)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
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
                          if (extraCount > 0)
                            Container(
                              color: Colors.black.withOpacity(0.55),
                              alignment: Alignment.center,
                              child: Text(
                                '+$extraCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
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
    final screenWidth = widget.width;
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

    // Portrait : 72% de la largeur écran (même traitement que pub video) pour éviter trop de hauteur
    // Paysage : largeur colonne contenu standard
    final bool isVideoPortrait = PostOrientation.of(widget.post);
    final double screenW = MediaQuery.of(context).size.width;
    final double videoW = isVideoPortrait
        ? screenW * 0.72
        : screenW - 12 - 36 - 9 - 12;
    final double videoH = isVideoPortrait
        ? (videoW * 16.0 / 9.0 * 0.75).clamp(0.0, (screenW * 0.52))
        : (videoW * 9.0 / 16.0);

    final Widget videoContainer = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.textSecondary.withOpacity(0.18), width: 0.8),
      ),
      child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: _isGeneratingThumbnail
          ? Container(
              width: videoW, height: videoH,
              color: colors.shimmerBase,
              child: Center(child: CircularProgressIndicator(color: colors.info)),
            )
          : previewReady
              ? GestureDetector(
                  onTap: _openDetailsPage,
                  child: SizedBox(
                  width: videoW,
                  height: videoH,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _previewController!.value.size.width,
                      height: _previewController!.value.size.height,
                      child: VideoPlayer(_previewController!),
                    ),
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
                      child: Image.file(
                        File(_videoThumbnailPath!),
                        fit: BoxFit.cover,
                        width: videoW,
                        height: videoH,
                      ),
                    )
                  : GestureDetector(
                      onTap: _startVideoPreview,
                      child: SizedBox(width: videoW, height: videoH, child: _buildFallbackThumbnail()),
                    ),
        ),
        );

    return Stack(
      children: [
        isVideoPortrait
            ? Align(alignment: Alignment.centerLeft, child: videoContainer)
            : videoContainer,

        // Vidéo épinglée dans le post : un toucher ouvre la vidéo d'origine (repère « ▶ voir l'original » à l'endroit où elle est posée)
        if (widget.post.studioPins.isNotEmpty)
          Positioned.fill(
            child: LayoutBuilder(builder: (context, box) {
              return Stack(children: [
                for (final p in widget.post.studioPins.take(2))
                  Positioned(
                    left: (((p['x'] as num?)?.toDouble() ?? .8) * box.maxWidth - 46).clamp(4, box.maxWidth - 96).toDouble(),
                    top: (((p['y'] as num?)?.toDouble() ?? .2) * box.maxHeight + ((p['w'] as num?)?.toDouble() ?? .3) * box.maxWidth * .3).clamp(4, box.maxHeight - 34).toDouble(),
                    child: GestureDetector(
                      key: ValueKey('pin_open_${p['post_id']}'),
                      onTap: () async {
                        final id = '${p['post_id']}';
                        final target = await PostsApi.get(id);
                        if (!mounted) return;
                        if (target == null) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Vidéo indisponible'))));
                          return;
                        }
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => PostOrientation.of(target) ? PostDetailsVideoFormatTel(initialPost: target, isIn: false) : VideoYoutubePageDetails(initialPost: target, feedTier: widget.feedTier)));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xB3000000), borderRadius: BorderRadius.circular(99)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.play_arrow_rounded, size: 14, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(context.tr('Voir l\'original'), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                        ]),
                      ),
                    ),
                  ),
              ]);
            }),
          ),

        // Carte Commerce : pastille (prix ou titre) dépliée au toucher, boutons WhatsApp / appel / lien
        if (widget.post.hasCommerce && widget.post.id != null)
          Positioned(left: 10, bottom: 10, child: PostCommerceOverlay(postId: widget.post.id!)),

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
                        child: Icon(Icons.lock_outline, color: colors.accentText, size: 28),
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
            // Laisse passer le tap jusqu'à la miniature (sinon le bouton play ne fait rien)
            child: IgnorePointer(child: Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
              ),
            )),
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
                    onTap: _openDetailsPage,
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
    final subscriptionPrice = currentCanal?.subscriptionPriceCoins ?? 0;

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
                  ? 'S\'ABONNER - $subscriptionPrice pièces'
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

  static const Color _defiYellow = Color(0xFFFF9500);

  Widget _buildDefiMiniBanner() {
    final colors = AppColors.of(context);
    final post = widget.post;
    final isDefiResponse = post.defiResponseToPostId != null;
    final isDefi = post.type == PostType.DEFI.name;
    if (!isDefi && !isDefiResponse) return const SizedBox.shrink();

    return GestureDetector(
      onTap: isDefiResponse ? () {
        PostsApi.get(post.defiResponseToPostId!).then((defiPost) {
          if (defiPost != null && mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DetailsPost(post: defiPost)),
            );
          }
        }).catchError((_) {});
      } : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0x22FFE14D),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _defiYellow.withOpacity(0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, color: _defiYellow, size: 14),
            const SizedBox(width: 6),
            Text(
              isDefiResponse ? 'Réponse à un Défi  •  $_localDefiVotes votes' : 'Défi  •  $_localDefiVotes votes',
              style: const TextStyle(color: _defiYellow, fontSize: 11, fontWeight: FontWeight.w600),
            ),
            if (isDefiResponse) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: _defiYellow, size: 14),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVoteButton(bool hasAccess) {
    final post = widget.post;
    final isDefi = post.type == PostType.DEFI.name;
    final isDefiResponse = post.defiResponseToPostId != null;
    if (!isDefi && !isDefiResponse) return const SizedBox.shrink();

    // Post DÉFI original → bouton "Participer" (ou badge "Terminé")
    if (isDefi) {
      if (isDefiOver(post)) return const DefiEndedChip();
      if (isDefiCreator(post, authProvider.loginUserData.id)) return const SizedBox.shrink(); // le créateur ne peut pas participer (403 `creator_cannot_participate`)
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: hasAccess ? () => openDefiParticipation(context, post) : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: hasAccess ? _defiYellow : _defiYellow.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sports_score, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'Participer',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Réponse DÉFI → bouton Voter (reste cliquable après vote pour expliquer "déjà voté")
    final canVote = hasAccess && !_hasVotedLocally && !_isVoting;

    return ScaleTransition(
      scale: _voteScaleAnim,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: hasAccess && !_isVoting ? () {
            _handleDefiVote();
            recordUniquePostView();
          } : null,
          child: Container(
            key: _voteBtnKey,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: canVote
                  ? _defiYellow
                  : _hasVotedLocally
                      ? _defiYellow.withOpacity(0.2)
                      : _defiYellow.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: _hasVotedLocally
                  ? Border.all(color: _defiYellow, width: 1)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _isVoting
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(
                        _hasVotedLocally ? Icons.how_to_vote : Icons.how_to_vote_outlined,
                        size: 14,
                        color: canVote ? Colors.white
                            : _hasVotedLocally ? _defiYellow
                            : _defiYellow.withOpacity(0.5),
                      ),
                const SizedBox(width: 4),
                Text(
                  '${_hasVotedLocally ? 'Voté' : 'Voter'} · ${_formatCount(_localDefiVotes)}',
                  style: TextStyle(
                    color: canVote ? Colors.white
                        : _hasVotedLocally ? _defiYellow
                        : _defiYellow.withOpacity(0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPostActions(bool hasAccess) {
    final colors = AppColors.of(context);
    final isLiked = _isLikedLocally;
    final post = widget.post;
    final isDefi = post.type == PostType.DEFI.name;
    final isDefiResponse = post.defiResponseToPostId != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Banner DÉFI + bouton Participer/Vote sur la même ligne ──────
        if (isDefi || isDefiResponse)
          Padding(
            padding: const EdgeInsets.only(bottom: 6, top: 4),
            child: Row(
              children: [
                _buildDefiMiniBanner(),
                const SizedBox(width: 8),
                _buildVoteButton(hasAccess),
              ],
            ),
          ),
        Container(
      margin: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          // ── Actions interactives (proches des doigts) ────────────────────
          _buildActionButton(
            icon: FontAwesome.comment_o,
            count: _localCommentsCount,
            color: colors.textSecondary,
            onPressed: hasAccess ? () {
              _showCommentsModal(widget.post);
              recordUniquePostView();
              widget.onCommented?.call();
            } : null,
          ),
          _buildActionButton(
            icon: isLiked ? FontAwesome.heart : FontAwesome.heart_o,
            count: _localLovesCount,
            color: isLiked ? colors.danger : colors.textSecondary,
            onPressed: (hasAccess && !_isLiking) ? () {
              _handleLike();
              recordUniquePostView();
              widget.onLiked?.call();
            } : null,
            coinHeart: widget.post.isMonetized,
          ),
          if (widget.post.isAdvertisement != true &&
              authProvider.loginUserData.id != widget.post.user_id)
            _buildActionButton(
              icon: Icons.repeat,
              count: widget.post.users_republier_id?.length ?? 0,
              color: (widget.post.users_republier_id?.contains(authProvider.loginUserData.id) ?? false)
                  ? colors.primary
                  : colors.textSecondary,
              onPressed: hasAccess ? () {
                _handleRepost();
                recordUniquePostView();
                widget.onViewed?.call();
              } : null,
            ),
          if (hasAccess && widget.post.isAdvertisement != true && widget.post.type == PostType.POST.name && widget.post.dataType == PostDataType.VIDEO.name)
            IconButton(
              key: const ValueKey('pin_video_button'),
              tooltip: context.tr('Épingler cette vidéo'),
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.push_pin_outlined, size: 21, color: colors.textSecondary),
              onPressed: _pinThisVideo,
            ),
          if (hasAccess && widget.post.isAdvertisement != true && widget.post.type == PostType.POST.name)
            IconButton(
              key: const ValueKey('reply_video_button'),
              tooltip: context.tr('Répondre en vidéo'),
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.videocam_outlined, size: 21, color: colors.textSecondary),
              onPressed: _replyWithVideo,
            ),
          if (widget.post.isAdvertisement != true) ...[
            const SizedBox(width: 4),
            if (hasAccess && authProvider.loginUserData.id != widget.post.user_id)
              CadeauBadge(
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
                  await _coinProvider.refreshBalance(authProvider.loginUserData.id!);
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

          // ── Stat passive (loin, discrète) ────────────────────────────────
          const Spacer(),
          if ((widget.post.totalInteractions ?? 0) > 0)
            _buildInteractionsTotalBadge(widget.post.totalInteractions!, colors),
        ],
      ),
    ),
      ],
    );
  }
  /// « Épingler cette vidéo » : la caméra s'ouvre ; cette vidéo (un extrait léger) est posée dans le coin de ce qu'on filme, réglable dans le Studio.
  Future<void> _pinThisVideo() async {
    final id = widget.post.id;
    if (id == null) return;
    final src = MontagePinSource(postId: id, thumbUrl: widget.post.thumbnail ?? '', authorPseudo: widget.post.user?.pseudo ?? 'créateur', durationSec: 0, previewUrl: widget.post.url_media);
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CreateHubPage(start: CreateStart.video, pinSource: src)));
  }

  /// « Répondre en vidéo » : la caméra s'ouvre tout de suite (15 s au plus) ; la publication part avec le lien vers ce post.
  Future<void> _replyWithVideo() async {
    await PostReply.start(context, widget.post);
  }

  /// Ouvre le post auquel celui-ci répond.
  void _openReplyTarget() {
    final id = widget.post.replyToPostId;
    if (id == null) return;
    void gone() {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('Le post d\'origine n\'est plus disponible.'))));
    }
    PostsApi.get(id).then((p) {
      if (!mounted) return;
      if (p == null) return gone();
      Navigator.push(context, MaterialPageRoute(builder: (_) => DetailsPost(post: p)));
    }).catchError((_) => gone());
  }

  Widget _buildInteractionsTotalBadge(int total, AppColors colors) {
    final isDark = colors.isDark;
    final bg = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04);
    final border = isDark ? Colors.white.withOpacity(0.09) : Colors.black.withOpacity(0.07);
    final textC = colors.textSecondary;

    String fmt(int n) {
      if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
      if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
      return '$n';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bar_chart_rounded, size: 13, color: textC),
          const SizedBox(width: 3),
          Text(
            fmt(total),
            style: TextStyle(
              color: textC,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
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
    // Aucun commentaire annoncé : inutile de lire Firestore pour rien (une lecture par post affiché)
    if ((widget.post.comments ?? 0) <= 0) return;
    setState(() => _isLoadingComment = true);
    try {
      // Cache partagé : une seule lecture (5 commentaires, auteurs des 3 premiers) pour tous les écrans, prête avant l'ouverture des commentaires
      final page = await CommentsPrefetch.instance.first(postId);
      if (page.comments.isNotEmpty && mounted) {
        setState(() {
          _preloadedComments = List.of(page.comments);
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

    setState(() => _isSendingQuickComment = true);
    try {
      // 10 commentaires gratuits par publication, puis 1 pièce (erreur 402 : proposer de recharger)
      final sent = await CommentsApi.send(widget.post.id!, body: trimmed);
      final comment = sent.comment..user = authProvider.loginUserData;
      if (mounted) {
        setState(() {
          _quickCommentController.clear();
          _preloadedComments.insert(0, comment);
          CommentsPrefetch.instance.addLocal(comment.post_id ?? '', comment);
          _localCommentsCount++;
        });
        if (sent.paidCoins > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Commentaire envoyé : ${sent.paidCoins} pièce débitée.'), duration: const Duration(seconds: 2)),
          );
        }
      }
      // Notifications, série et goûts du fil : gérés par le serveur.
    } catch (e) {
      if (mounted) handleApiError(context, e, onRetry: () => _sendQuickComment(trimmed), fallback: "Erreur lors de l'envoi");
    } finally {
      if (mounted) setState(() => _isSendingQuickComment = false);
    }
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
    bool coinHeart = false, // like : cœur plus grand avec la pastille « +1 »
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: coinHeart ? 4.5 : 12, vertical: coinHeart ? 5 : 6),
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
              else if (coinHeart)
                LikeCoinHeart(icon: icon, color: onPressed != null ? color : color.withOpacity(0.3), size: 20)
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

  /// Nombre d'abonnés : même source et même format que les pages de détails.
  Widget _followersText(TextStyle style, {double topGap = 0}) {
    if (currentCanal != null) {
      final c = currentCanal!.membersCount;
      if (c == 0) return const SizedBox.shrink();
      return Padding(padding: EdgeInsets.only(top: topGap), child: Text("${_formatCount(c)} abonné(s)", style: style));
    }
    final user = currentUser;
    if (user == null) return const SizedBox.shrink();
    return FollowersCountBuilder(
      userId: user.id ?? widget.post.user_id,
      fallback: user.followersCount,
      builder: (_, c) => c == 0
          ? const SizedBox.shrink()
          : Padding(padding: EdgeInsets.only(top: topGap), child: Text("${_formatCount(c)} abonné(s)", style: style)),
    );
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

  String _formatCount(int count) => formatCompactCount(count);

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
        height: MediaQuery.of(context).size.height * 0.94,
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
                focusKeyboard: false,
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
            if (CardEntry.canMake(post, authProvider.loginUserData))
              CardMenuTile(
                onTap: () {
                  Navigator.pop(context);
                  CardEntry.openFromPost(this.context, post);
                },
              ),
            if (DefiConvert.canConvert(post, authProvider.loginUserData))
              DefiMenuTile(
                onTap: () {
                  Navigator.pop(context);
                  DefiConvert.openFromPost(this.context, post);
                },
              ),
            if (post.user!.id == authProvider.loginUserData.id &&
                post.isAdvertisement != true)
              _buildMenuOption(
                Icons.rocket_launch_outlined,
                "Booster ce post",
                const Color(0xFFFFD700),
                () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => boostPageFor(post),
                  ));
                },
              ),

            _buildMenuOption(
              Icons.video_call_rounded,
              context.tr('Réponses en vidéo'),
              colors.textPrimary,
              () {
                Navigator.pop(context);
                Navigator.push(this.context, MaterialPageRoute(builder: (_) => ReplyVideosPage(postId: post.id!)));
              },
            ),
            if (post.user_id != authProvider.loginUserData.id)
              _buildMenuOption(
                Icons.flag,
                "Signaler",
                colors.textPrimary,
                    () async {
                  Navigator.pop(context);
                  // Même Cloud Function que les pages de détail : le signalement entre dans la
                  // file de modération et les admins sont prévenus (règle App Store 1.2).
                  bool value;
                  try {
                    await PostsApi.report(post.id!);
                    value = true;
                  } on ApiException catch (e) {
                    value = e.status == 409 || e.code == 'already_reported';
                  } catch (_) {
                    value = false;
                  }
                  if (!mounted) return;

                  final snackBar = SnackBar(
                    content: Text(
                      value ? 'Post signalé, merci ! Notre équipe va l\'examiner.' : 'Échec du signalement, réessaie.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: value ? AppColors.of(context).primary : AppColors.of(context).danger),
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                },
              ),

            if (post.user_id != null && post.user_id != authProvider.loginUserData.id)
              _buildMenuOption(
                Icons.block,
                "Bloquer cet utilisateur",
                colors.danger,
                () {
                  Navigator.pop(context);
                  confirmAndBlockUser(
                    context,
                    userId: post.user_id!,
                    pseudo: post.user?.pseudo,
                    postId: post.id,
                  );
                },
              ),

            if (post.user!.id == authProvider.loginUserData.id && post.id != null)
              _buildMenuOption(
                Icons.shopping_bag_outlined,
                post.hasCommerce ? "Modifier la carte Commerce" : "Ajouter une carte Commerce",
                colors.textPrimary,
                () async {
                  Navigator.pop(context);
                  if (!await GoldGate.feature(context, authProvider.loginUserData.id ?? '', 'commerce_card')) return;
                  if (!context.mounted) return;
                  showCommerceEditor(context, post.id!).then((_) => CommerceApi.get(post.id!).then((c) {
                        post.hasCommerce = c != null;
                        if (mounted) setState(() {});
                      }).catchError((_) {}));
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
    PostsApi.unlike(postId).catchError((e) {
      if (mounted) {
        setState(() {
          _isLikedLocally = true;
          _localLovesCount = _localLovesCount + 1;
          widget.post.loves = _localLovesCount;
          widget.post.users_love_id?.add(userId);
        });
        showApiError(context, e);
      }
    }).whenComplete(() {
      if (mounted) setState(() => _isLiking = false);
    });
  }

void _processLikeBackground(String userId) {
    final postId = widget.post.id;
    if (postId == null) {
      if (mounted) setState(() => _isLiking = false);
      return;
    }
    // Le serveur débite 2 pièces (1 au créateur) et refuse (402) si le solde manque : le j'aime est alors annulé à l'écran.
    PostsApi.like(postId).then((added) async {
      if (!mounted) return;
      if (added) {
        final coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);
        await coinProvider.refreshBalance(userId);
        if (mounted) _triggerSupportMessage();
      }
      widget.onLoved?.call();
    }).catchError((e) {
      if (!mounted) return;
      setState(() {
        _isLikedLocally = false;
        _localLovesCount = (_localLovesCount - 1).clamp(0, 999999);
        widget.post.loves = _localLovesCount;
        widget.post.users_love_id?.remove(userId);
      });
      if (e is ApiException && e.isInsufficientCoins) {
        _showInsufficientCoinsForLikeDialog();
      } else {
        showApiError(context, e);
      }
    }).whenComplete(() {
      if (mounted) setState(() => _isLiking = false);
    });
  }

  void _triggerSupportMessage() {
    if (!mounted) return;
    showLikeOverlay(context, creatorName: widget.post.user?.pseudo ?? '');
  }

  void _showInsufficientCoinsForLikeDialog() {
    showInsufficientCoinsForLikeDialog(
      context: context,
      user: authProvider.loginUserData,
      coinProvider: Provider.of<CoinGiftUserProvider>(context, listen: false),
      authProvider: authProvider,
    );
  }

// Extraire la logique des notifications dans une méthode séparée
Future<void> _handleDefiVote() async {
    // Le vote de défi n'a pas encore de route côté API (voir lacunes_api_publications.md) : aucun vote n'est simulé.
    if (_hasVotedLocally) {
      DefiDialogs.alreadyVoted(context);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Le vote des défis sera bientôt de retour.'), duration: Duration(seconds: 2)),
    );
  }

Future<void> _refreshPostStats() async {
    if (widget.post.id == null || !mounted) return;
    try {
      final fresh = await PostsApi.get(widget.post.id!);
      if (fresh != null && mounted) {
        setState(() {
          widget.post.loves = fresh.loves;
          widget.post.comments = fresh.comments;
          widget.post.vues = fresh.vues;
        });
      }
    } catch (_) {}
  }

  void _openDetailsPage() {
    if (widget.onOpenPost != null) {
      widget.onOpenPost!(widget.post);
      return;
    }
    final isVideoPost = widget.post.dataType == PostDataType.VIDEO.name;
    final isPortrait = PostOrientation.of(widget.post);
    if (isVideoPost && isPortrait) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostDetailsVideoFormatTel(
            initialPost: widget.post,
            isIn: false,
          ),
        ),
      ).then((_) => _refreshPostStats());
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => isVideoPost
            ? VideoYoutubePageDetails(initialPost: widget.post, feedTier: widget.feedTier)
            : DetailsPost(post: widget.post, feedTier: widget.feedTier),
      ),
    ).then((_) => _refreshPostStats());
  }

// 2. Modifier la méthode _handleGift
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
          videoUrl: _optimizeUrl(widget.post.url_media!),
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

      // Compteur de partages tenu par le serveur (un partage par personne) : on affiche son chiffre
      final shared = await PubApi.share(widget.post.id!);
      if (!mounted) return;
      setState(() {
        widget.post.partage = shared.count ?? ((widget.post.partage ?? 0) + (shared.counted ? 1 : 0));
        widget.post.users_partage_id ??= [];
        widget.post.users_partage_id!.add(authProvider.loginUserData.id!);
      });

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
    final bool othersPost = post.user_id != null && post.user_id != authProvider.loginUserData.id;
    final reasonCtrl = TextEditingController();
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              othersPost ? 'Ce post sera retiré pour tout le monde. Ta décision est enregistrée au journal de modération.' : 'Ce post sera supprimé définitivement. Cette action est irréversible.',
              style: TextStyle(color: colors.textSecondary, fontSize: 14),
            ),
            if (othersPost) ...[
              const SizedBox(height: 12),
              TextField(
                controller: reasonCtrl,
                maxLength: 200,
                style: TextStyle(color: colors.textPrimary, fontSize: 14),
                decoration: InputDecoration(hintText: 'Motif (facultatif)', hintStyle: TextStyle(color: colors.textSecondary)),
              ),
            ],
          ],
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
      await _deletePost(post, reason: othersPost ? reasonCtrl.text : null);
      if (!mounted) return;
      Navigator.pop(context); // loader
      setState(() => _removedByDelete = true);
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
        content: Row(children: [
          const Icon(Icons.error_outline, color: Colors.white),
          const SizedBox(width: 10),
          Flexible(child: Text(_deleteErrorMessage(e))),
        ]),
        backgroundColor: colors.danger,
        duration: const Duration(seconds: 4),
      ));
    }
  }

/// Message précis selon la réponse de l'API : droit manquant (403), publication déjà supprimée (404), pas de réseau.
  String _deleteErrorMessage(Object e) {
    if (e is ApiException) {
      if (e.isNetwork) return 'Connexion impossible. Vérifie ta connexion puis réessaie.';
      if (e.status == 403) return "Suppression refusée : ton compte n'a pas le droit de modération sur ce post.";
      if (e.isNotFound) return 'Ce post a déjà été supprimé.';
      if (e.message.isNotEmpty) return e.message;
    }
    return 'Échec de la suppression. Réessaie.';
  }

Future<void> _deletePost(Post post, {String? reason}) async {
    try {
      await PostsApi.delete(post.id!, reason: reason);
      printVm('✅ Post ${post.id} supprimé');
    } catch (e) {
      printVm('❌ Erreur lors de la suppression du post ${post.id}: $e');
      rethrow;
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
                Navigator.push(ctx, MaterialPageRoute(builder: (context) => const CoinRechargeScreen()));
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



