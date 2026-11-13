import 'package:afrotok/services/post_orientation.dart';
import 'package:afrotok/services/authenticity_watcher.dart';
import 'package:afrotok/services/watch_tracker.dart';
import '../../l10n/tr.dart' show tr;
import '../videos/video_chrome.dart' show AuthenticBadge, NotMonetizedChip, showNotMonetizedSheet;
import 'package:afrotok/services/read_meter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/media_cdn.dart';
import '../../services/comments_prefetch.dart';
import '../../services/media_shrink.dart';
import '../../widgets/studio/post_template_try.dart';
import 'package:afrotok/widgets/name_tag.dart';
import 'package:flutter/services.dart';
import '../cards/card_entry.dart';
import 'package:afrotok/widgets/pseudo_tag.dart';
import 'package:afrotok/widgets/safe_network_avatar.dart';
import '../../services/followers_count_service.dart';
import '../../utils/count_format.dart';
import 'package:afrotok/utils/responsive_sheet.dart';
import 'package:afrotok/layout/responsive_layout.dart';
import 'dart:ui';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:audioplayers/audioplayers.dart';
import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:afrotok/services/api/api_gateway.dart';
import 'package:afrotok/services/api/canal_mapper.dart';
import 'package:afrotok/services/api/posts_api.dart';
import 'package:afrotok/services/api/publications_api.dart';
import 'package:afrotok/services/api/users_api.dart';
import 'package:afrotok/services/api/users_mapper.dart';
import 'package:afrotok/widgets/api_error_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:afrotok/services/block_service.dart';
import 'package:afrotok/pages/defi/defi_ui.dart';
import '../../widgets/smart_video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/postProvider.dart';
import '../../providers/sound_provider.dart';
import '../../providers/userProvider.dart';
import '../canaux/detailsCanal.dart';
import '../component/consoleWidget.dart';
import '../../widgets/post_social_actions.dart';
import '../home/user_presence_widget.dart';
import '../pub/afrolook_inline_ad.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter_vector_icons/flutter_vector_icons.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:hashtagable_v3/widgets/hashtag_text.dart';

import '../../providers/coin_gift_provider.dart';
import '../../services/linkService.dart';
import '../coins/coin_gift_dialog.dart';
import '../coins/coin_recharge_screen.dart';
import '../../widgets/like_coins_helper.dart';
import '../../widgets/gifts/quick_gift_bar.dart' show QuickGiftBar, CadeauBadge;
import '../component/showUserDetails.dart';
import '../postComments.dart';
import '../postDetails.dart';
import '../../widgets/post_media_overlays.dart';
import '../../widgets/original_badge.dart';
import '../postDetailsVideo.dart';

import '../../services/utils/abonnement_utils.dart';
import '../../services/postService/feed_interaction_service.dart';
import '../../services/streak_service.dart';
import '../../providers/streakProvider.dart';
import '../../widgets/user_badge_widget.dart';
import '../../theme/app_colors.dart';
import '../../providers/locale_provider.dart';
import 'postWidgets/translatable_description.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'video_preload_manager.dart';
import '../../services/media_cache_service.dart';
import 'package:afrotok/services/comment_coins.dart';
import 'package:afrotok/widgets/post_coins_earned.dart';
import '../../ads/ad_slot.dart';
import '../studio/artist_marketplace.dart';


class MediaPlaybackManager {
  static VideoPlayerController? _currentVideoController;
  static ChewieController? _currentChewieController;
  static AudioPlayer? _currentAudioPlayer;
  static String? _currentMediaId;
  static String? _currentMediaType;
  static VoidCallback? _onPauseCallback;

  // Nouveau : Référence au provider de son
  static SoundProvider? _soundProvider;
  static VoidCallback? _soundListener;

  // Initialisation avec le provider
  static void init(SoundProvider soundProvider) {
    _soundProvider = soundProvider;

    // Écouter les changements de préférence sonore
    _soundListener = () {
      _onGlobalSoundChanged();
    };
    _soundProvider?.addListener(_soundListener!);
  }

  // Appliquer le changement de son à toutes les vidéos actives
  static void _onGlobalSoundChanged() {
    if (_soundProvider == null) return;

    final volume = _soundProvider!.isMuted ? 0.0 : 1.0;

    // Mettre à jour la vidéo courante
    if (_currentMediaType == 'video' && _currentChewieController != null) {
      _currentChewieController!.setVolume(volume);
    }
    // Mettre à jour l'audio courant
    else if (_currentMediaType == 'audio' && _currentAudioPlayer != null) {
      _currentAudioPlayer!.setVolume(volume);
    }
  }

  static void registerVideo2(
      String postId,
      VideoPlayerController controller,
      ChewieController chewieController,
      VoidCallback onPause,
      )
  {
    // Arrêter l'audio si nécessaire
    if (_currentMediaType == 'audio' && _currentAudioPlayer != null) {
      _currentAudioPlayer!.stop();
      _currentAudioPlayer = null;
    }

    // Pause de l'ancienne vidéo
    if (_currentMediaId != null && _currentMediaId != postId) {
      _onPauseCallback?.call();
      _currentChewieController?.pause();
    }

    _currentMediaId = postId;
    _currentMediaType = 'video';
    _currentVideoController = controller;
    _currentChewieController = chewieController;
    _onPauseCallback = onPause;

    // 🔥 Appliquer le volume global immédiatement
    final isMuted = _soundProvider?.isMuted ?? true;
    chewieController.setVolume(isMuted ? 0.0 : 1.0);
  }

  static void registerVideo(
      String postId,
      VideoPlayerController controller,
      ChewieController chewieController,
      VoidCallback onPause,
      ) {
    printVm('🎬 MediaPlaybackManager: Enregistrement vidéo $postId');

    // Arrêter l'audio si nécessaire
    if (_currentMediaType == 'audio' && _currentAudioPlayer != null) {
      _currentAudioPlayer!.stop();
      _currentAudioPlayer = null;
    }

    // Pause de l'ancienne vidéo
    if (_currentMediaId != null && _currentMediaId != postId) {
      printVm('🎬 Arrêt de l\'ancienne vidéo: $_currentMediaId');
      _onPauseCallback?.call();
      if (_currentChewieController != null) {
        _currentChewieController!.pause();
      }
    }

    _currentMediaId = postId;
    _currentMediaType = 'video';
    _currentVideoController = controller;
    _currentChewieController = chewieController;
    _onPauseCallback = onPause;

    // 🔥 APPLIQUER LE VOLUME DE MANIÈRE ROBUSTE
    final isMuted = _soundProvider?.isMuted ?? true;
    final volume = isMuted ? 0.0 : 1.0;

    printVm('🎬 Application du volume: $volume (muted: $isMuted)');

    // Appliquer sur le ChewieController
    chewieController.setVolume(volume);

    // 🔥 FORCER sur le VideoPlayerController directement
    controller.setVolume(volume);

    // 🔥 Vérification supplémentaire : s'assurer que le volume persiste après un court délai
    Future.delayed(Duration(milliseconds: 100), () {
      if (_currentChewieController == chewieController) {
        chewieController.setVolume(volume);
        controller.setVolume(volume);
        printVm('🎬 Vérification volume: $volume');
      }
    });
  }

  static void registerAudio(
      String postId,
      AudioPlayer audioPlayer,
      VoidCallback onStop,
      ) {
    // Pause de la vidéo courante
    if (_currentMediaType == 'video' && _currentChewieController != null) {
      _onPauseCallback?.call();
      _currentChewieController?.pause();
    }

    // Arrêter l'ancien audio
    if (_currentMediaType == 'audio' && _currentMediaId != postId && _currentAudioPlayer != null) {
      _currentAudioPlayer!.stop();
    }

    _currentMediaId = postId;
    _currentMediaType = 'audio';
    _currentAudioPlayer = audioPlayer;
    _onPauseCallback = onStop;

    // 🔥 Appliquer le volume global
    final isMuted = _soundProvider?.isMuted ?? true;
    audioPlayer.setVolume(isMuted ? 0.0 : 1.0);
  }

  static void unregisterMedia(String postId) {
    if (_currentMediaId == postId) {
      _currentMediaId = null;
      _currentMediaType = null;
      _currentVideoController = null;
      _currentChewieController = null;
      _currentAudioPlayer = null;
      _onPauseCallback = null;
    }
  }

  static void pauseCurrentMedia() {
    if (_currentMediaType == 'video' && _currentChewieController != null) {
      if (_currentChewieController!.isPlaying) {
        _currentChewieController!.pause();
      }
    } else if (_currentMediaType == 'audio' && _currentAudioPlayer != null) {
      if (_currentAudioPlayer!.state == PlayerState.playing) {
        _currentAudioPlayer!.pause();
      }
    }
  }

  // Nettoyage
  static void dispose() {
    if (_soundProvider != null && _soundListener != null) {
      _soundProvider!.removeListener(_soundListener!);
    }
    _soundProvider = null;
    _soundListener = null;
  }
}

class YouTubeVideoCard extends StatefulWidget {
  final Post post;
  final int index;
  final VoidCallback onTap;
  final Function(int)? onNeighborhoodPreload;
  // Session 13 : pays du filtre actif (HomeConstPost._selectedCountryCode), utilisé pour
  // afficher en priorité ce pays dans le badge pays du post (s'il y figure).
  final String? currentFilterCountry;
  final bool suppressInlineAd;

  const YouTubeVideoCard({
    Key? key,
    required this.post,
    required this.onTap,
    this.index = 0,
    this.onNeighborhoodPreload,
    this.currentFilterCountry,
    this.suppressInlineAd = false,
  }) : super(key: key);


  @override
  State<YouTubeVideoCard> createState() => _YouTubeVideoCardState();
}

class _YouTubeVideoCardState extends State<YouTubeVideoCard>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin, TickerProviderStateMixin {

  @override
  bool get wantKeepAlive => true;

  // Authenticité : même contrôle que sur la page des vidéos verticales (marque d'un autre réseau = plus monétisée)
  final AuthenticityWatcher _authWatch = AuthenticityWatcher();

  /// Pastille « plus monétisé » (vidéo marquée) ou mot « Authentique » (vidéo validée), posés sur la vidéo ; rien tant que la vidéo n'est pas jugée.
  Widget _authenticityOverlay() {
    final post = widget.post;
    if (post.authenticity == 'flagged') {
      return Positioned(
        left: 8,
        top: 8,
        right: 60,
        child: Align(
          alignment: Alignment.centerLeft,
          child: NotMonetizedChip(
            onTap: () => showNotMonetizedSheet(context, mark: post.authenticityMark ?? 'other', isOwner: post.user_id == _authProvider.loginUserData.id),
          ),
        ),
      );
    }
    if (post.authenticity == 'validated') return const Positioned(left: 8, top: 8, child: AuthenticBadge());
    return const SizedBox.shrink();
  }

  void _watchAuthenticity() {
    _authWatch.schedule(
      post: widget.post,
      me: _authProvider.loginUserData.id,
      controller: () => _videoController,
      cdn: (u) => _authProvider.convertToCdnUrl(u, _authProvider.appDefaultData),
      stillWanted: () => mounted && _isVisible,
      onState: (state, mark) {
        if (!mounted) return;
        setState(() {
          widget.post.authenticity = state;
          if (state == 'flagged') widget.post.authenticityMark = mark;
        });
      },
    );
  }

  // Contrôleurs vidéo
  VideoPlayerController? _videoController;
  final WatchTracker _watch = WatchTracker();   // visionnage anonyme de cette carte
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;
  bool _isVideoLoading = false;
  bool _isInitializingVideo = false;
  bool _isVisible = false;
  bool _isVideoCompleted = false;

  // Miniature
  String? _thumbnailUrl;
  bool _isGeneratingThumbnail = false;

  // Providers et données
  late UserAuthProvider _authProvider;
  late PostProvider _postProvider;
  late CoinGiftUserProvider _coinProvider;
  // 🔥 Ajoutez cette variable
  late SoundProvider _soundProvider;
  // Données utilisateur/canal
  UserData? _creatorUser;
  Canal? _creatorCanal;
  bool _isLoadingUser = false;
  bool _isProcessingFollow = false;

  // États des interactions
  bool _isFavorite = false;
  bool _isProcessingFavorite = false;
  bool _isSharing = false;
  bool _isExpanded = false;
  String? _translatedDescription;
  bool _isLoading = false;
  bool _isLiking = false;
  bool _isVoting = false;
  int _localDefiVotes = 0;
  bool _hasVotedLocally = false;
  final GlobalKey _voteBtnKey = GlobalKey();
  late AnimationController _voteAnimController;
  late Animation<double> _voteScaleAnim;
  int _localCommentsCount = 0;
  int _localInteractionsCount = 0;
  List<PostComment> _preloadedComments = [];
  bool _isLoadingComment = false;
  final TextEditingController _quickCommentController = TextEditingController();
  bool _isSendingQuickComment = false;

  // Interaction vidéo (une seule fois par jour)
  bool _hasRecordedInteraction = false;
  String? _lastInteractionDateKey;
  SharedPreferences? _prefs;

  // Timer pour la visibilité
  Timer? _visibilityTimer;

  // Timer "Voir plus" après 5s de lecture réelle (sauf pour les posts pub)
  Timer? _seeMoreTimer;
  bool _showSeeMoreCta = false;
  bool _seeMoreTimerStarted = false;

  // Verrou canal privé — s'affiche après 10s de lecture
  Timer? _canalLockTimer;
  bool _showCanalLockCta = false;

  // Pour la publication
  final String appId = 'AfrolookApp';

  bool get _shouldShowAd => (widget.index + 1) % 5 == 0;

  bool get _isLockedContent {
    if (_creatorCanal != null) {
      final isPrivate = _creatorCanal!.isPrivate == true;
      final isSubscribed = _creatorCanal!.usersSuiviId?.contains(_authProvider.loginUserData.id) ?? false;
      final isAdmin = _authProvider.loginUserData.role == UserRole.ADM.name;
      final isCurrentUser = _authProvider.loginUserData.id == widget.post.user_id;
      return isPrivate && !isSubscribed && !isAdmin && !isCurrentUser;
    }
    return false;
  }

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
    WidgetsBinding.instance.addObserver(this);

    _authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _postProvider = Provider.of<PostProvider>(context, listen: false);

    _localCommentsCount = widget.post.comments ?? 0;
    _localInteractionsCount = widget.post.totalInteractions ?? 0;
    _coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);
    _soundProvider = Provider.of<SoundProvider>(context, listen: false);
    _localDefiVotes = widget.post.defiVotes ?? 0;
    _hasVotedLocally = widget.post.defiVoterIds?.contains(_authProvider.loginUserData.id) ?? false;

    if (!_soundProvider.isMuted) {
      _soundProvider.setMuted(true);
    }
    // 🔥 S'abonner aux changements du provider de son (un seul abonnement, retiré dans dispose)
    _soundProvider.addListener(_updateVolume);
    _initSharedPreferences();

    final _swPost = Stopwatch()..start();
    final postId  = widget.post.id ?? '?';
    final postType = widget.post.typeTabbar ?? widget.post.dataType ?? widget.post.type ?? '?';
    final isCanalPost = widget.post.canal_id != null && widget.post.canal_id!.isNotEmpty;
    printVm('⏱️ [POST-DISPLAY] id=$postId type=$postType canal=$isCanalPost — initState start');

    _initFromSnapshot();
    final snapMs = _swPost.elapsedMilliseconds;
    final hadSnapshot = isCanalPost ? widget.post.canalSnapshot != null : widget.post.creatorSnapshot != null;
    printVm('⏱️ [POST-DISPLAY] id=$postId — snapshot=${hadSnapshot ? "✅ ${snapMs}ms (affichage immédiat)" : "❌ pas de snapshot → placeholder"}');

    _loadCreatorData().then((_) {
      final totalMs = _swPost.elapsedMilliseconds;
      final source = isCanalPost
          ? (widget.post.canal != null ? 'canal complet chargé' : 'canal manquant')
          : (widget.post.user != null ? 'user complet chargé' : 'user manquant');
      printVm('⏱️ [POST-DISPLAY] id=$postId — $source — total=${totalMs}ms (snap=${snapMs}ms + fetch=${totalMs - snapMs}ms)');
    });
    _checkIfFavorite();
    _checkInteractionRecordedToday();
    _loadLastComment();

    if (widget.post.thumbnail?.isNotEmpty == true) {
      _thumbnailUrl = widget.post.thumbnail;
    } else {
      _generateAndUploadThumbnail();
    }

    // 🔥 Préchargement Facebook-style : permettre au gestionnaire global de
    // résoudre les URLs CDN (utilisé par VideoPreloadManager.preload)
    VideoPreloadManager.urlResolver ??= (rawUrl) =>
        _authProvider.convertToCdnUrl(rawUrl, _authProvider.appDefaultData);

    // 🔥 NOUVEAU : Initialisation précoce de la vidéo (sans lancer la lecture)
    // Attendre un court instant pour ne pas bloquer l'UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isLockedContent) {
        _preInitializeVideo();
      }
    });
  }

  @override
  void didUpdateWidget(covariant YouTubeVideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.post.id != oldWidget.post.id) {
      // Post différent : réinitialiser tous les états visuels pour éviter
      // qu'un ancien aperçu reste affiché sur une nouvelle carte
      _videoController?.dispose();
      _chewieController?.dispose();
      _videoController = null;
      _chewieController = null;
      setState(() {
        _localCommentsCount = widget.post.comments ?? 0;
        _localInteractionsCount = widget.post.totalInteractions ?? 0;
        _thumbnailUrl = (widget.post.thumbnail?.isNotEmpty == true)
            ? widget.post.thumbnail
            : null;
        _isVideoInitialized = false;
        _isVideoLoading = false;
        _isInitializingVideo = false;
        _isGeneratingThumbnail = false;
        _isVisible = false;
        _isVideoCompleted = false;
      });
      if (widget.post.thumbnail == null || widget.post.thumbnail!.isEmpty) {
        _generateAndUploadThumbnail();
      }
    } else {
      // Même post, données rafraîchies : synchroniser si les valeurs en ligne sont supérieures
      final onlineComments = widget.post.comments ?? 0;
      final onlineInteractions = widget.post.totalInteractions ?? 0;
      if (onlineComments > _localCommentsCount || onlineInteractions > _localInteractionsCount) {
        setState(() {
          if (onlineComments > _localCommentsCount) _localCommentsCount = onlineComments;
          if (onlineInteractions > _localInteractionsCount) _localInteractionsCount = onlineInteractions;
        });
      }
    }
  }

  /// 🔥 Nouvelle méthode : Pré-initialisation sans lecture auto
  /// Réutilise un contrôleur déjà préchargé par [VideoPreloadManager] si
  /// disponible (préchargement Facebook-style des voisins).
  Future<void> _preInitializeVideo() async {
    // Sur web, SmartVideoPlayer gère l'affichage nativement — pas de VideoPlayerController
    if (kIsWeb) return;

    if (_isVideoInitialized || _isVideoLoading || _isInitializingVideo) return;
    if (widget.post.url_media == null || widget.post.url_media!.isEmpty) return;

    _isInitializingVideo = true;
    if (mounted) setState(() => _isVideoLoading = true);

    try {
      await _disposeVideoControllers();

      // 🔥 Réutiliser le contrôleur préchargé par le gestionnaire global s'il existe
      final preloaded = VideoPreloadManager.claimController(widget.post.id ?? '');
      if (preloaded != null) {
        _videoController = preloaded;
      } else {
        final String optimizedUrl = _authProvider.convertToCdnUrl(
            widget.post.url_media!,
            _authProvider.appDefaultData
        );
        _videoController = await MediaCacheService.videoController(optimizedUrl);

        // Attendre l'initialisation (chargement des métadonnées)
        await _videoController!.initialize();
      }
      _watch.start(widget.post.id, _videoController);   // visionnage anonyme (tranche regardée, envoyée une fois)

      _videoController!.addListener(() {
        if (_videoController == null) return;
        final isEnded = _videoController!.value.position >= _videoController!.value.duration;
        if (isEnded) {
          _isVideoCompleted = true;
        } else {
          _isVideoCompleted = false;
        }
        if (_videoController!.value.isPlaying && _isVisible && !_hasRecordedInteraction) {
          _recordVideoInteraction();
        }
        if (_videoController!.value.isPlaying && _isVisible) _watchAuthenticity();
      });

      final colors = AppColors.of(context);
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: false,  // 🔥 TRÈS IMPORTANT : ne pas jouer automatiquement
        looping: true,
        showControls: false,
        allowFullScreen: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: colors.primary,
          handleColor: colors.primary,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.grey,
        ),
        placeholder: Container(
          color: Colors.black,
          child: Center(child: CircularProgressIndicator(color: colors.primary)),
        ),
        autoInitialize: true,
      );

      // Appliquer le volume immédiatement
      final isMuted = _soundProvider.isMuted;
      _chewieController!.setVolume(isMuted ? 0.0 : 1.0);

      // Enregistrer dans le manager (même si non jouée)
      MediaPlaybackManager.registerVideo(
        widget.post.id!,
        _videoController!,
        _chewieController!,
            () => _pauseVideo(),
      );

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _isVideoLoading = false;
          _isInitializingVideo = false;
        });
        printVm('✅ Vidéo pré-initialisée : ${widget.post.id}');
      }
    } catch (e) {
      printVm('Erreur pré-initialisation vidéo: $e');
      if (mounted) {
        setState(() {
          _isVideoLoading = false;
          _isInitializingVideo = false;
        });
      }
    }
  }


  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _lastInteractionDateKey = 'video_interaction_${widget.post.id}_${_authProvider.loginUserData.id}';
  }

  Future<void> _checkInteractionRecordedToday() async {
    if (_prefs == null) return;
    final lastDate = _prefs!.getString(_lastInteractionDateKey!);
    final today = DateTime.now().toIso8601String().split('T').first;
    _hasRecordedInteraction = lastDate == today;
  }

  /// Aperçu de la vidéo : image mise en cache sur le téléphone et servie par le CDN (plus de re-téléchargement à chaque affichage).
  Widget _posterImage({required double width, required double height, required Widget fallback}) {
    return CachedNetworkImage(
      imageUrl: MediaCdn.url(_thumbnailUrl),
      fit: BoxFit.cover,
      width: width,
      height: height,
      fadeInDuration: const Duration(milliseconds: 100),
      placeholder: (_, __) => fallback,
      errorWidget: (_, __, ___) => fallback,
    );
  }

  Future<void> _generateAndUploadThumbnail() async {
    // Miniature : l'API ne permet pas encore de joindre une miniature à une publication (voir lacunes_api_publications.md).
  }

  /// Hydrate _creatorUser / _creatorCanal depuis le snapshot stocké dans le post.
  /// Synchrone — appelé avant _loadCreatorData() pour un affichage immédiat.
  /// Ne stocke que les infos stables (pseudo, image, compteur) — les badges sont
  /// gérés par UserBadgeWidget et chargés avec le profil complet.
  void _initFromSnapshot() {
    final postId = widget.post.id ?? '?';
    final isCanalPost = widget.post.canal_id != null && widget.post.canal_id!.isNotEmpty;
    if (isCanalPost) {
      if (widget.post.canal != null) {
        _creatorCanal = widget.post.canal;
        printVm('⏱️ [POST-SNAP] id=$postId → canal depuis post.canal (cache)');
        return;
      }
      final snap = widget.post.canalSnapshot;
      if (snap != null) {
        _creatorCanal = Canal()
          ..titre = snap['titre'] as String?
          ..urlImage = snap['urlImage'] as String?
          ..suivi = snap['suivi'] as int? ?? 0;
        printVm('⏱️ [POST-SNAP] id=$postId → canal depuis canalSnapshot');
      } else {
        printVm('⏱️ [POST-SNAP] id=$postId → canal: ni cache ni snapshot → placeholder');
      }
    } else {
      if (widget.post.user != null) {
        _creatorUser = widget.post.user;
        printVm('⏱️ [POST-SNAP] id=$postId → user depuis post.user (cache)');
        return;
      }
      final snap = widget.post.creatorSnapshot;
      if (snap != null) {
        _creatorUser = UserData()
          ..pseudo = snap['pseudo'] as String?
          ..imageUrl = snap['imageUrl'] as String?
          ..abonnes = snap['abonnes'] as int? ?? 0;
        printVm('⏱️ [POST-SNAP] id=$postId → user depuis creatorSnapshot');
      } else {
        printVm('⏱️ [POST-SNAP] id=$postId → user: ni cache ni snapshot → placeholder');
      }
    }
  }

  Future<void> _loadCreatorData() async {
    final isCanalPost = widget.post.canal_id != null && widget.post.canal_id!.isNotEmpty;
    if (isCanalPost) {
      if (widget.post.canal != null) {
        _creatorCanal = widget.post.canal;
        if (mounted) setState(() {});
        return;
      }
      if (mounted) setState(() => _isLoadingUser = true);
      try {
        final r = await ApiGateway.instance.client.get('/channels/${widget.post.canal_id}');
        final d = (r as Map)['data'];
        if (d is Map) {
          _creatorCanal = canalFromApi(Map<String, dynamic>.from(d));
          widget.post.canal = _creatorCanal;
        }
      } catch (e) {
        printVm('Erreur chargement canal: $e');
      } finally {
        if (mounted) setState(() => _isLoadingUser = false);
      }
    } else if (widget.post.user_id != null) {
      if (widget.post.user != null) {
        _creatorUser = widget.post.user;
        if (mounted) setState(() {});
      }
      if (mounted && _creatorUser == null) setState(() => _isLoadingUser = true);
      try {
        _creatorUser = userFromApi(await UsersApi.publicProfile(widget.post.user_id!));
        widget.post.user = _creatorUser;
      } catch (e) {
        printVm('Erreur chargement utilisateur: $e');
      } finally {
        if (mounted) setState(() => _isLoadingUser = false);
      }
    }
  }
  void _toggleSound() {
    final newMuteState = !_soundProvider.isMuted;
    _soundProvider.setMuted(newMuteState);
    // L’écouteur _updateVolume (déjà présent) appliquera le changement sur la vidéo courante
  }
  Future<void> _checkIfFavorite() async {
    final userId = _authProvider.loginUserData.id;
    if (userId == null) return;
    setState(() {
      _isFavorite = widget.post.users_favorite_id?.contains(userId) ?? false;
    });
  }

  // ==================== GESTION VIDÉO ====================

  Future<void> _initializeVideo() async {
    if (_isVideoInitialized || _isVideoLoading || _isInitializingVideo) return;
    if (widget.post.url_media == null || widget.post.url_media!.isEmpty) return;

    _isInitializingVideo = true;
    if (mounted) setState(() => _isVideoLoading = true);

    try {
      await _disposeVideoControllers();

      // 🔥 Réutiliser le contrôleur préchargé par le gestionnaire global s'il existe
      final preloaded = VideoPreloadManager.claimController(widget.post.id ?? '');
      if (preloaded != null) {
        _videoController = preloaded;
      } else {
        final String optimizedUrl = _authProvider.convertToCdnUrl(widget.post.url_media!, _authProvider.appDefaultData);
        _videoController = await MediaCacheService.videoController(optimizedUrl);
        await _videoController!.initialize();
      }
      _watch.start(widget.post.id, _videoController);   // visionnage anonyme

      _videoController!.addListener(() {
        if (_videoController == null) return;
        final isEnded = _videoController!.value.position >= _videoController!.value.duration;
        if (isEnded) {
          _isVideoCompleted = true;
        } else {
          _isVideoCompleted = false;
        }
        if (_videoController!.value.isPlaying && _isVisible && !_hasRecordedInteraction) {
          _recordVideoInteraction();
        }
        if (_videoController!.value.isPlaying && _isVisible) _watchAuthenticity();
      });

      final colors = AppColors.of(context);
      _chewieController = ChewieController(

        videoPlayerController: _videoController!,
        autoPlay: false,           // Lecture automatique
        looping: true,
        showControls: false,      // 🔥 PAS DE CONTRÔLES AFFICHÉS
        allowFullScreen: false,   // Désactiver le plein écran (sinon les contrôles réapparaissent)
        materialProgressColors: ChewieProgressColors(
          playedColor: colors.primary,
          handleColor: colors.primary,
          backgroundColor: Colors.grey,
          bufferedColor: Colors.grey,
        ),
        placeholder: Container(
          color: Colors.black,
          child: Center(child: CircularProgressIndicator(color: colors.primary)),
        ),
        autoInitialize: true,
      );
      // 🔥 CRUCIAL : Appliquer le volume global IMMÉDIATEMENT
      final isMuted = _soundProvider.isMuted;
      _chewieController!.setVolume(isMuted ? 0.0 : 1.0);
      MediaPlaybackManager.registerVideo(
        widget.post.id!,
        _videoController!,
        _chewieController!,
            () => _pauseVideo(),
      );

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _isVideoLoading = false;
          _isInitializingVideo = false;
        });
      }
    } catch (e) {
      printVm('Erreur initialisation vidéo: $e');
      if (mounted) {
        setState(() {
          _isVideoLoading = false;
          _isInitializingVideo = false;
        });
      }
    }
  }


  // Méthode statique pour précharger une vidéo
  Future<void> _recordVideoInteraction() async {
    if (_hasRecordedInteraction || _prefs == null) return;

    final today = DateTime.now().toIso8601String().split('T').first;
    final lastDate = _prefs!.getString(_lastInteractionDateKey!);

    if (lastDate == today) {
      _hasRecordedInteraction = true;
      return;
    }

    try {
      await _prefs!.setString(_lastInteractionDateKey!, today);
      _hasRecordedInteraction = true;
      await _authProvider.incrementPostTotalInteractions(postId: widget.post.id!);
    } catch (e) {
      printVm('Erreur enregistrement interaction: $e');
    }
  }

  void _playVideo() {
    if (_showCanalLockCta) return;

    if (_chewieController != null) {
      // 🔥 FORCER le volume juste avant de jouer
      final isMuted = _soundProvider.isMuted;
      final volume = isMuted ? 0.0 : 1.0;
      _chewieController!.setVolume(volume);
      _videoController?.setVolume(volume);

      printVm('🎬 _playVideo: volume forcé à $volume avant lecture');

      if (_isVideoCompleted) {
        _videoController?.seekTo(Duration.zero);
        _isVideoCompleted = false;
      }
      _chewieController!.play();
    }
  }

  void _pauseVideo() {
    if (_chewieController != null && _chewieController!.isPlaying) {
      _chewieController!.pause();
    }
  }

  Future<void> _disposeVideoControllers() async {
    _watch.flush();   // la vidéo quitte l'écran : tranche regardée envoyée (anonyme)
    _chewieController?.dispose();
    await _videoController?.dispose();
    _chewieController = null;
    _videoController = null;
    _isVideoInitialized = false;
  }

  // ==================== GESTION VISIBILITÉ ====================

  void onVisibilityChanged2(double visibleFraction) {
    final isNowVisible = visibleFraction > 0.5;

    if (isNowVisible != _isVisible) {
      _isVisible = isNowVisible;

      if (_isVisible) {
        _onBecameVisible();
      } else {
        _onBecameInvisible();
      }
    }
  }

  void onVisibilityChanged(double visibleFraction) {
    final isNowVisible = visibleFraction > 0.5;

    if (isNowVisible != _isVisible) {
      _isVisible = isNowVisible;

      if (_isVisible) {
        _onBecameVisible();
        // 🔥 Quand la vidéo devient visible, demander le préchargement des suivantes
        if (widget.onNeighborhoodPreload != null) {
          widget.onNeighborhoodPreload!(widget.index);
        }
      } else {
        _onBecameInvisible();
      }
    }
  }
// 🔥 NOUVELLE MÉTHODE: Déclencher le préchargement des vidéos voisines
  void _triggerNeighborhoodPreload() {
    // Cette méthode peut être appelée depuis le parent avec la liste des posts
    // Ou on peut utiliser un callback passé par le parent
    if (widget.onNeighborhoodPreload != null) {
      widget.onNeighborhoodPreload!(widget.index);
    }
  }
  void _onBecameVisible() {
    // Réinitialiser les CTA à chaque nouvelle apparition
    _seeMoreTimer?.cancel();
    _seeMoreTimerStarted = false;
    if (_showSeeMoreCta) setState(() => _showSeeMoreCta = false);

    // Verrou canal privé : laisser 10s de lecture puis bloquer
    _canalLockTimer?.cancel();
    if (_showCanalLockCta) setState(() => _showCanalLockCta = false);
    if (_isLockedContent) {
      _canalLockTimer = Timer(const Duration(seconds: 10), () {
        if (mounted) {
          _pauseVideo();
          setState(() => _showCanalLockCta = true);
        }
      });
    }

    if (_isVideoInitialized && _chewieController != null) {
      // 🔥 ÉTAPE 1: Mettre en pause les autres médias
      MediaPlaybackManager.pauseCurrentMedia();

      // 🔥 ÉTAPE 2: Enregistrer cette vidéo comme courante
      MediaPlaybackManager.registerVideo(
        widget.post.id!,
        _videoController!,
        _chewieController!,
            () => _pauseVideo(),
      );

      // 🔥 ÉTAPE 3: Vérifier l'état global du son ET APPLIQUER
      final isMuted = _soundProvider.isMuted;
      final targetVolume = isMuted ? 0.0 : 1.0;

      // Appliquer le volume AU CHEWIE CONTROLLER
      _chewieController!.setVolume(targetVolume);

      // 🔥 ÉTAPE 4: FORCER la synchronisation du volume avec le VideoPlayerController
      // Certaines versions de Chewie ont un bug où setVolume ne fonctionne pas immédiatement
      _videoController?.setVolume(targetVolume);

      // 🔥 ÉTAPE 5: Attendre un court instant pour que le volume soit appliqué
      Future.delayed(Duration(milliseconds: 50), () {
        if (mounted && _chewieController != null) {
          // Re-appliquer pour être sûr
          _chewieController!.setVolume(targetVolume);

          // Toujours lancer (volume déjà appliqué : 0.0 si muet, 1.0 si son actif)
          _playVideo();
          printVm('▶️ Auto-play vidéo ${widget.post.id} (muted=$isMuted, volume: $targetVolume)');

          // Timer "Voir plus" : 5s après le début de lecture (sauf posts pub)
          if (widget.post.isAdvertisement != true && !_seeMoreTimerStarted) {
            _seeMoreTimerStarted = true;
            _seeMoreTimer?.cancel();
            _seeMoreTimer = Timer(const Duration(seconds: 5), () {
              if (mounted) {
                _pauseVideo();
                setState(() => _showSeeMoreCta = true);
              }
            });
          }
        }
      });

      return;
    }

    if (!_isVideoInitialized && !_isVideoLoading && !_isInitializingVideo) {
      _initializeVideo();
    }
  }

  void _onBecameInvisible() {
    if (_isVideoInitialized && _chewieController != null) {
      _pauseVideo();
    }
    _seeMoreTimer?.cancel();
    if (_showSeeMoreCta && mounted) setState(() => _showSeeMoreCta = false);
    _canalLockTimer?.cancel();
    if (_showCanalLockCta && mounted) setState(() => _showCanalLockCta = false);
  }

  // ==================== ACTIONS DU POST ====================

  Future<void> _handleLike() async {
    if (_isLiking) return;
    final userId = _authProvider.loginUserData.id;
    if (userId == null) return;

    final alreadyLiked = widget.post.users_love_id?.contains(userId) ?? false;

    setState(() {
      _isLiking = true;
      widget.post.loves = ((widget.post.loves ?? 0) + (alreadyLiked ? -1 : 1))
          .clamp(0, double.maxFinite.toInt());
      widget.post.users_love_id ??= [];
      if (alreadyLiked) {
        widget.post.users_love_id!.remove(userId);
      } else {
        widget.post.users_love_id!.add(userId);
      }
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
          widget.post.loves = ((widget.post.loves ?? 0) + 1);
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
        await _coinProvider.refreshBalance(userId);
        if (mounted) _triggerSupportMessage();
      }
    }).catchError((e) {
      if (!mounted) return;
      setState(() {
        widget.post.loves = ((widget.post.loves ?? 1) - 1).clamp(0, double.maxFinite.toInt());
        widget.post.users_love_id?.remove(userId);
      });
      if (e is ApiException && e.isInsufficientCoins) {
        _showInsufficientCoinsDialog();
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

  void _showInsufficientCoinsDialog() {
    showInsufficientCoinsForLikeDialog(
      context: context,
      user: _authProvider.loginUserData,
      coinProvider: _coinProvider,
      authProvider: _authProvider,
    );
  }

  Future<void> _toggleFavorite() async {
    if (_isProcessingFavorite) return;
    _isProcessingFavorite = true;
    final postId = widget.post.id!;
    try {
      if (_isFavorite) {
        await PostsApi.unfavorite(postId);
        setState(() {
          _isFavorite = false;
          widget.post.favoritesCount = (widget.post.favoritesCount ?? 0) - 1;
        });
      } else {
        await PostsApi.favorite(postId);
        setState(() {
          _isFavorite = true;
          widget.post.favoritesCount = (widget.post.favoritesCount ?? 0) + 1;
        });
      }
    } catch (e) {
      printVm('Erreur favori: $e');
      if (mounted) showApiError(context, e, onRetry: _toggleFavorite);
    } finally {
      _isProcessingFavorite = false;
    }
  }

  void _handleShare() async {
    setState(() => _isSharing = true);

    try {
      final shareImageUrl = widget.post.thumbnail ?? '';
      final appLinkService = AppLinkService();
      await appLinkService.shareContent(
        type: AppLinkType.post,
        id: widget.post.id!,
        message: widget.post.description ?? '',
        mediaUrl: shareImageUrl,
      );

      final shared = await PubApi.share(widget.post.id!);
      if (!mounted) return;
      setState(() {
        widget.post.partage = shared.count ?? ((widget.post.partage ?? 0) + (shared.counted ? 1 : 0));
        widget.post.users_partage_id ??= [];
        widget.post.users_partage_id!.add(_authProvider.loginUserData.id!);
      });

      addPointsForAction(UserAction.partagePost);
      addPointsForOtherUserAction(widget.post.user_id!, UserAction.autre);

    } catch (e) {
      printVm('Erreur partage: $e');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  void _handleGift() {
    showDialog(
      context: context,
      builder: (context) => CoinGiftDialog(
        receiverId: widget.post.user_id!,
        receiverName: widget.post.user?.pseudo ?? 'Créateur',
        receiverAvatar: widget.post.user?.imageUrl ?? '',
        post: widget.post,
        onGiftSuccess: () async {
          setState(() {
            widget.post.users_cadeau_id ??= [];
            if (!widget.post.users_cadeau_id!.contains(_authProvider.loginUserData.id!)) {
              widget.post.users_cadeau_id!.add(_authProvider.loginUserData.id!);
            }
          });
          await _coinProvider.refreshBalance(_authProvider.loginUserData.id!);
        },
      ),
    );
  }

  void _showCommentsModal({String? initialText}) {
    final colors = AppColors.of(context);
    showResponsiveBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.94,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Commentaires', style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: Icon(Icons.close, color: colors.textPrimary), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Expanded(
              child: PostComments(
                post: widget.post,
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

  /// Ouvre le post auquel celui-ci répond (réponse en vidéo).
  void _openReplyTarget() {
    final id = widget.post.replyToPostId;
    if (id == null) return;
    void gone() {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Le post d'origine n'est plus disponible.")));
    }
    PostsApi.get(id).then((p) {
      if (!mounted) return;
      if (p == null) return gone();
      _pauseVideo();
      Navigator.push(context, MaterialPageRoute(builder: (_) => DetailsPost(post: p)));
    }).catchError((_) => gone());
  }

  void _navigateToDetails() {
    _pauseVideo();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoYoutubePageDetails(initialPost: widget.post),
      ),
    );
  }

  // ==================== WIDGETS UI ====================

  Widget _buildEventBadge() {
    if (widget.post.typeTabbar != 'EVENEMENT' || widget.post.eventDate == null) return const SizedBox.shrink();

    final eventDateTime = DateTime.fromMillisecondsSinceEpoch(widget.post.eventDate!);
    final now = DateTime.now();
    final difference = eventDateTime.difference(now).inDays;

    String badgeText = '';
    Color badgeColor = const Color(0xFFE21221);

    if (difference < 0) {
      badgeText = '📅 PASSÉ';
      badgeColor = Colors.grey;
    } else if (difference == 0) {
      badgeText = '🔴 AUJOURD\'HUI';
      badgeColor = Colors.red;
    } else if (difference == 1) {
      badgeText = '⭐ DEMAIN';
      badgeColor = Colors.orange;
    } else if (difference <= 7) {
      badgeText = '📅 DANS $difference JOURS';
      badgeColor = const Color(0xFFE21221);
    } else {
      badgeText = '📅 À VENIR';
      badgeColor = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)],
      ),
      child: Text(badgeText, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCountryBadge() {
    final isAllCountries = widget.post.isAvailableInAllCountries == true;
    var countryCodes = widget.post.availableCountries ?? [];

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

    String displayText = '';
    String flagEmoji = '🌍';

    if (isAllCountries) {
      displayText = 'Tous';
      flagEmoji = '🌍';
    } else if (countryCodes.isNotEmpty) {
      final firstCountryCode = countryCodes.first.toUpperCase();
      final country = AfricanCountry.everyCountry.firstWhere(
            (c) => c.code == firstCountryCode,
        orElse: () => AfricanCountry(code: firstCountryCode, name: firstCountryCode, flag: '🏳️'),
      );
      flagEmoji = country.flag;
      displayText = countryCodes.length == 1 ? firstCountryCode : '+${countryCodes.length - 1}';
    }

    final colors = AppColors.of(context);
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

  void _showCountriesModal() {
    final colors = AppColors.of(context);
    final isAllCountries = widget.post.isAvailableInAllCountries == true;
    final countryCodes = widget.post.availableCountries ?? [];

    showResponsiveBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final c = AppColors.of(ctx);
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Text('Pays disponibles', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: c.textPrimary)),
              const SizedBox(height: 12),
              if (isAllCountries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🌍', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 10),
                      Text('Disponible dans tous les pays', style: TextStyle(fontSize: 14, color: c.textSecondary)),
                    ],
                  ),
                )
              else if (countryCodes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text('Aucun pays spécifié', style: TextStyle(color: c.textSecondary)),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: countryCodes.length,
                    itemBuilder: (ctx2, i) {
                      final code = countryCodes[i].toUpperCase();
                      final country = AfricanCountry.everyCountry.firstWhere(
                        (c) => c.code == code,
                        orElse: () => AfricanCountry(code: code, name: code, flag: '🏳️'),
                      );
                      return ListTile(
                        dense: true,
                        leading: Text(country.flag, style: const TextStyle(fontSize: 22)),
                        title: Text(country.name, style: TextStyle(color: c.textPrimary, fontSize: 14)),
                        trailing: Text(code, style: TextStyle(color: c.textSecondary, fontSize: 12)),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPostHeader() {
    final colors = AppColors.of(context);
    final isCanalPost = _creatorCanal != null;

    if (!isCanalPost && _creatorUser == null) {
      return _buildPlaceholderHeader();
    }

    final postOwner = isCanalPost ? _creatorCanal! : _creatorUser!;
    final isCurrentUser = _authProvider.loginUserData.id == widget.post.user_id;
    final isAbonne = isCanalPost
        ? (_creatorCanal?.usersSuiviId?.contains(_authProvider.loginUserData.id) ?? false)
        : (_authProvider.loginUserData.followingIds?.contains(widget.post.user_id) ?? false);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            if (isCanalPost && _creatorCanal != null) {
              Navigator.push(context, MaterialPageRoute(builder: (context) => CanalDetails(canal: _creatorCanal!)));
            } else if (_creatorUser != null) {
              showUserDetailsModalDialog(_creatorUser!, MediaQuery.of(context).size.width, MediaQuery.of(context).size.height, context);
            }
          },
          child: Stack(
            children: [
              SafeNetworkAvatar(
                url: (isCanalPost && _creatorCanal?.urlImage != null) ? _creatorCanal!.urlImage : _creatorUser?.imageUrl,
                radius: 23,
                backgroundColor: colors.primary,
                fallbackIcon: isCanalPost ? Icons.group : Icons.person,
                iconColor: Colors.white,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        NameTag(label: isCanalPost ? '#${_creatorCanal?.titre ?? ''}' : '@${_creatorUser?.pseudo ?? ''}',
                          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(width: 4),

                        if (_creatorUser != null)
                          UserBadgeWidget(user: _creatorUser, size: 14),
                      ],
                    ),
                  ),
                  if (!isCurrentUser && !isAbonne) _buildFollowButton(isCanalPost, postOwner),
                  const SizedBox(width: 5),
                  GestureDetector(
                    onTap: _showCountriesModal,
                    child: _buildCountryBadge(),
                  ),
                ],
              ),
              FollowersCountBuilder(
                userId: isCanalPost ? null : (_creatorUser?.id ?? widget.post.user_id),
                fallback: isCanalPost
                    ? ((_creatorCanal?.membersCount ?? 0))
                    : ((_creatorUser?.followersCount ?? 0)),
                builder: (_, count) {
                  if (count == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${formatCompactCount(count)} abonné${count > 1 ? 's' : ''}',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
  Widget _buildAvatarWidget() {
    final colors = AppColors.of(context);
    final isCanalPost = _creatorCanal != null;
    ImageProvider? profileImage;
    if (isCanalPost && _creatorCanal?.urlImage != null) {
      profileImage = NetworkImage(_creatorCanal!.urlImage!);
    } else if (_creatorUser?.imageUrl != null) {
      profileImage = NetworkImage(_creatorUser!.imageUrl!);
    }
    return GestureDetector(
      onTap: () {
        if (isCanalPost && _creatorCanal != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => CanalDetails(canal: _creatorCanal!)));
        } else if (_creatorUser != null) {
          showUserDetailsModalDialog(_creatorUser!, MediaQuery.of(context).size.width, MediaQuery.of(context).size.height, context);
        }
      },
      child: isCanalPost
          ? Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.rectangle,
                borderRadius: BorderRadius.circular(8),
                color: colors.primary,
                image: profileImage != null ? DecorationImage(image: profileImage, fit: BoxFit.cover) : null,
              ),
              child: profileImage == null ? Icon(Icons.group, color: colors.onPrimary, size: 16) : null,
            )
          : CircleAvatar(
              radius: 18,
              backgroundColor: colors.primary,
              backgroundImage: profileImage,
              child: profileImage == null ? Icon(Icons.person, color: colors.onPrimary, size: 16) : null,
            ),
    );
  }

  Widget _buildPostHeaderInfo() {
    final colors = AppColors.of(context);
    final isCanalPost = _creatorCanal != null;
    if (!isCanalPost && _creatorUser == null) {
      return PseudoTag(label: '@${widget.post.user?.pseudo ?? 'utilisateur'}',
        style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14));
    }
    final postOwner = isCanalPost ? _creatorCanal! : _creatorUser!;
    final isCurrentUser = _authProvider.loginUserData.id == widget.post.user_id;
    final isAbonne = isCanalPost
        ? (_creatorCanal?.usersSuiviId?.contains(_authProvider.loginUserData.id) ?? false)
        : (_authProvider.loginUserData.followingIds?.contains(widget.post.user_id) ?? false);
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
                    child: NameTag(label: isCanalPost ? '#${_creatorCanal?.titre ?? ''}' : '@${_creatorUser?.pseudo ?? ''}',
                      style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 4),
                  if (_creatorUser != null) UserBadgeWidget(user: _creatorUser, size: 13),
                ],
              ),
              FollowersCountBuilder(
                userId: isCanalPost ? null : (_creatorUser?.id ?? widget.post.user_id),
                fallback: isCanalPost
                    ? ((_creatorCanal?.membersCount ?? 0))
                    : ((_creatorUser?.followersCount ?? 0)),
                builder: (_, count) {
                  if (count == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${formatCompactCount(count)} abonné${count > 1 ? 's' : ''}',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                  );
                },
              ),
              if (OriginalBadge.isCaptured(widget.post.captureSource) || VoiceChangedBadge.has(widget.post.voiceEffect))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(spacing: 6, runSpacing: 4, children: [
                    if (OriginalBadge.isCaptured(widget.post.captureSource)) const OriginalBadge(),
                    if (VoiceChangedBadge.has(widget.post.voiceEffect)) const VoiceChangedBadge(),
                  ]),
                ),
              // réponse en vidéo : à quel post on répond (un toucher l'ouvre)
              if (widget.post.replyToPostId != null)
                Align(alignment: Alignment.centerLeft, child: ReplyToLine(username: widget.post.replyToUsername, excerpt: widget.post.replyToExcerpt, onTap: _openReplyTarget)),
            ],
          ),
        ),
        if (!isCurrentUser && !isAbonne) _buildFollowButton(isCanalPost, postOwner),
        const SizedBox(width: 5),
        GestureDetector(onTap: _showCountriesModal, child: _buildCountryBadge()),
      ],
    );
  }

  Widget _buildPlaceholderHeader() {
    final colors = AppColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 23,
          backgroundColor: colors.primary,
          child: const Icon(Icons.person, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: PseudoTag(label: '@${widget.post.user?.pseudo ?? 'utilisateur'}',
                      style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
              const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFollowButton(bool isCanalPost, dynamic postOwner) {
    final colors = AppColors.of(context);
    return Container(
      height: 28,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isCanalPost && (postOwner as Canal).isPrivate == true ? colors.accent : colors.primary,
          foregroundColor: isCanalPost && (postOwner as Canal).isPrivate == true ? colors.onAccent : colors.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: _isProcessingFollow ? null : () async {
          setState(() => _isProcessingFollow = true);
          try {
            if (isCanalPost) {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => CanalDetails(canal: postOwner)));
              await _loadCreatorData();
            } else {
              await _authProvider.abonner(postOwner as UserData, context);
              await _loadCreatorData();
            }
          } catch (e) {
            printVm('Erreur abonnement: $e');
          } finally {
            if (mounted) setState(() => _isProcessingFollow = false);
          }
        },
        child: _isProcessingFollow
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(isCanalPost && (postOwner as Canal).isPrivate == true ? 'S\'abonner' : 'Suivre',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildPostContent() {
    final colors = AppColors.of(context);
    final text = (widget.post.description ?? '')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
    final isLocked = _isLockedContent;

    if (isLocked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text.length > 100 ? '${text.substring(0, 100)}...' : text,
              style: TextStyle(fontSize: 15, color: colors.textSecondary, height: 1.4), maxLines: 2),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.lock, color: colors.accentText, size: 16),
            const SizedBox(width: 4),
            Text('Contenu réservé aux abonnés', style: TextStyle(color: colors.accentText, fontSize: 12, fontWeight: FontWeight.w500)),
          ]),
        ],
      );
    }

    final words = text.split(' ');
    final isLong = words.length > 25;
    final displayedText = _isExpanded || !isLong ? text : '${words.take(25).join(' ')}...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _navigateToDetails,
          child: HashTagText(
            text: displayedText,
            decoratedStyle: TextStyle(fontSize: 15, color: colors.info, height: 1.4),
            basicStyle: TextStyle(fontSize: 15, color: colors.textPrimary, height: 1.4),
            onTap: (_) {},
          ),
        ),
        if (isLong)
          GestureDetector(
            onTap: _navigateToDetails,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Voir plus',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.info)),
            ),
          ),
        _buildEventBadge(),
      ],
    );
  }

  Widget _buildCanalLockOverlay(AppColors colors) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          if (_creatorCanal != null) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => CanalDetails(canal: _creatorCanal!)));
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
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.accent.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.accent, width: 2),
                  ),
                  child: Icon(Icons.lock_outline, color: colors.accentText, size: 32),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Contenu réservé aux abonnés',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, decoration: TextDecoration.none),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Rejoignez ce canal pour continuer à regarder',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 12, decoration: TextDecoration.none),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_user, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text('S\'abonner au canal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, decoration: TextDecoration.none)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoContent2() {
    final colors = AppColors.of(context);
    final isLocked = _isLockedContent;
    final h = MediaQuery.of(context).size.height;

    return VisibilityDetector(
      key: Key('video_${widget.post.id}'),
      onVisibilityChanged: (info) => onVisibilityChanged(info.visibleFraction),
      child: GestureDetector(
        onTap: _showCanalLockCta ? null : _navigateToDetails, // 🔥 Clic → détails
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              child: kIsWeb && !isLocked && widget.post.url_media != null
                  ? AspectRatio(
                      aspectRatio: 16 / 9,
                      child: SmartVideoPlayer(
                        url: _authProvider.convertToCdnUrl(widget.post.url_media!, _authProvider.appDefaultData),
                        autoPlay: false,
                        showControls: true,
                      ),
                    )
                  : _isVideoInitialized && _chewieController != null
                  ? AspectRatio(aspectRatio: 16 / 9, child: Chewie(controller: _chewieController!))
                  : _isGeneratingThumbnail
                  ? Container(height: h * 0.38, width: double.infinity, color: colors.shimmerBase,
                  child: const Center(child: CircularProgressIndicator()))
                  : _thumbnailUrl != null
                  ? _posterImage(height: h * 0.38, width: double.infinity, fallback: Container(height: h * 0.38, width: double.infinity, color: colors.shimmerBase,
                      child: Icon(Icons.videocam, size: 50, color: colors.textSecondary)))
                  : Container(height: h * 0.38, width: double.infinity, color: colors.shimmerBase,
                  child: Icon(Icons.videocam, size: 50, color: colors.textSecondary)),
            ),
            // L'aperçu reste visible pendant que la vidéo se prépare : voile léger + petit indicateur
            if (_isVideoLoading)
              Container(height: h * 0.38, width: double.infinity, color: Colors.black.withOpacity(0.18),
                  child: Center(child: CircularProgressIndicator(color: colors.primary))),
            // Verrou canal privé — s'affiche après 10s de lecture
            if (_showCanalLockCta)
              _buildCanalLockOverlay(colors),
            _authenticityOverlay(),
            Positioned(
              bottom: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(4)),
                child: const Text('VIDÉO', style: TextStyle(color: Colors.white, fontSize: 10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoContent() {
    final colors = AppColors.of(context);
    final isLocked = _isLockedContent;
    final screenWidth = AppLayout.effectiveContentWidth(context);
    final isAd = widget.post.isAdvertisement == true;
    final bool isVideoPortrait = PostOrientation.of(widget.post);

    // ── Posts portrait (non-pub) : rendu identique à AdvertisementVideoWidget ──
    if (isVideoPortrait && !isAd) {
      final double pW = screenWidth * 0.72;
      final double maxH = MediaQuery.of(context).size.height * 0.52;
      double pH;
      if (_isVideoInitialized && _videoController != null) {
        final size = _videoController!.value.size;
        if (size.width > 0 && size.height > 0) {
          pH = (pW * (size.height / size.width) * 0.75).clamp(0.0, maxH);
        } else {
          pH = (pW * 16.0 / 9.0 * 0.75).clamp(0.0, maxH);
        }
      } else {
        pH = (pW * 16.0 / 9.0 * 0.75).clamp(0.0, maxH);
      }

      final Widget portraitPlayer = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.textSecondary.withOpacity(0.18), width: 0.8),
        ),
        child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: pW,
          height: pH,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                color: Colors.black,
                child: _isVideoInitialized && _videoController != null
                    ? FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _videoController!.value.size.width,
                          height: _videoController!.value.size.height,
                          child: VideoPlayer(_videoController!),
                        ),
                      )
                    : _thumbnailUrl != null
                        ? _posterImage(width: pW, height: pH, fallback: Icon(
                                Icons.videocam, size: 40, color: colors.textSecondary))
                        : Center(child: Icon(Icons.videocam,
                            size: 40, color: colors.textSecondary)),
              ),
              if (_isVideoLoading)
                Container(
                  color: Colors.black.withOpacity(0.15),
                  child: Center(child: CircularProgressIndicator(color: colors.primary)),
                ),
              if (_showCanalLockCta) _buildCanalLockOverlay(colors),
              if (_showSeeMoreCta && !_showCanalLockCta)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _navigateToDetails,
                    child: Container(
                      color: Colors.black.withOpacity(0.65),
                      child: Center(
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
                              Text('Voir la suite',
                                style: TextStyle(color: Colors.white,
                                    fontWeight: FontWeight.bold, fontSize: 14,
                                    decoration: TextDecoration.none)),
                            ],
                          ),
                        ).animate(onPlay: (c) => c.repeat(reverse: true))
                            .scaleXY(begin: 1.0, end: 1.08, duration: 600.ms),
                      ),
                    ),
                  ),
                ),
              _authenticityOverlay(),
              // widgets du créateur (sondage, quiz, question, lien…) et vidéos épinglées : comme dans les pages de détail
              if (!isLocked && !isAd) Positioned.fill(child: PostMediaOverlays(post: widget.post, video: _isVideoInitialized ? _videoController : null)),
              Positioned(
                bottom: 8, right: 8,
                child: Container(
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20)),
                  child: Consumer<SoundProvider>(
                    builder: (_, sp, __) => IconButton(
                      icon: Icon(sp.isMuted ? Icons.volume_off : Icons.volume_up,
                          color: Colors.white, size: 20),
                      onPressed: _toggleSound,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      );

      return VisibilityDetector(
        key: Key('video_${widget.post.id}'),
        onVisibilityChanged: (info) => onVisibilityChanged(info.visibleFraction),
        child: GestureDetector(
          onTap: _showCanalLockCta ? null : _navigateToDetails,
          child: Align(alignment: Alignment.centerLeft, child: portraitPlayer),
        ),
      );
    }

    // ── Paysage / pubs : rendu Chewie classique ───────────────────────────────
    final double columnW = screenWidth - 69.0;
    final double videoW = isAd ? screenWidth : columnW;
    final double videoHeight = isAd
        ? (screenWidth * (9.0 / 16.0)).clamp(200.0, 320.0)
        : (videoW * 9.0 / 16.0);

    final Widget videoContainer = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: kIsWeb && widget.post.url_media != null
          ? isAd
              ? AspectRatio(
                  aspectRatio: 16 / 9,
                  child: SmartVideoPlayer(
                    url: _authProvider.convertToCdnUrl(widget.post.url_media!, _authProvider.appDefaultData),
                    autoPlay: false,
                    showControls: true,
                  ),
                )
              : SizedBox(
                  width: videoW,
                  height: videoHeight,
                  child: SmartVideoPlayer(
                    url: _authProvider.convertToCdnUrl(widget.post.url_media!, _authProvider.appDefaultData),
                    autoPlay: false,
                    showControls: true,
                  ),
                )
          : _isVideoInitialized && _chewieController != null
          ? isAd
              ? AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Chewie(controller: _chewieController!),
                )
              : SizedBox(
                  width: videoW,
                  height: videoHeight,
                  child: Chewie(controller: _chewieController!),
                )
          : _isGeneratingThumbnail
          ? Container(
              height: videoHeight,
              width: videoW,
              color: colors.shimmerBase,
              child: const Center(child: CircularProgressIndicator()),
            )
          : _thumbnailUrl != null
          ? _posterImage(
              height: videoHeight,
              width: videoW,
              fallback: Container(
                height: videoHeight,
                width: videoW,
                color: colors.shimmerBase,
                child: Icon(Icons.videocam, size: 50, color: colors.textSecondary),
              ),
            )
          : Container(
              height: videoHeight,
              width: videoW,
              color: colors.shimmerBase,
              child: Icon(Icons.videocam, size: 50, color: colors.textSecondary),
            ),
    );

    return VisibilityDetector(
      key: Key('video_${widget.post.id}'),
      onVisibilityChanged: (info) => onVisibilityChanged(info.visibleFraction),
      child: GestureDetector(
        onTap: _showCanalLockCta ? null : _navigateToDetails,
        child: Stack(
          children: [
            // --- Conteneur vidéo ---
            videoContainer,
            // --- Indicateur de chargement ---
            if (_isVideoLoading)
              Container(
                height: videoHeight,
                width: videoW,
                color: Colors.black.withOpacity(0.18),
                child: Center(child: CircularProgressIndicator(color: colors.primary)),
              ),
            // --- Widgets du créateur et vidéos épinglées ---
            if (!isLocked && !isAd)
              Positioned.fill(child: PostMediaOverlays(post: widget.post, video: _isVideoInitialized ? _chewieController?.videoPlayerController : null)),
            // --- Verrou canal privé — s'affiche après 10s de lecture ---
            if (_showCanalLockCta)
              _buildCanalLockOverlay(colors),
            // --- 🎬 Overlay "Voir plus" après 5s de preview (sauf pubs et verrou) ---
            if (_showSeeMoreCta && !isAd && !_showCanalLockCta)
              Positioned.fill(
                child: GestureDetector(
                  onTap: _navigateToDetails,
                  child: Container(
                    color: Colors.black.withOpacity(0.65),
                    child: Center(
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
                            Text(
                              'Voir la suite',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(begin: 1.0, end: 1.08, duration: 600.ms, curve: Curves.easeInOut),
                    ),
                  ),
                ),
              ),
            // --- 🎵 Bouton de contrôle du son (remplace le badge "VIDÉO") ---
            if (!isLocked)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Consumer<SoundProvider>(
                    builder: (context, soundProvider, _) {
                      return IconButton(
                        icon: Icon(
                          soundProvider.isMuted ? Icons.volume_off : Icons.volume_up,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: _toggleSound,
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleRepost() async {
    // Le serveur enregistre la republication (une par personne), la compte comme un partage et la diffuse aux abonnés.
    await PostSocialActions.repost(context, widget.post, myId: _authProvider.loginUserData.id, onDone: () {
      if (mounted) setState(() {});
    });
  }

  static const Color _defiYellow = Color(0xFFFF9500);

  Future<void> _handleDefiVote() async {
    // Le vote de défi n'a pas encore de route côté API (voir lacunes_api_publications.md).
    if (_hasVotedLocally) {
      DefiDialogs.alreadyVoted(context);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Le vote des défis sera bientôt de retour.'), duration: Duration(seconds: 2)),
    );
  }

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
            Navigator.push(context, MaterialPageRoute(builder: (_) => DetailsPost(post: defiPost)));
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
              isDefiResponse
                  ? 'Réponse à un Défi  •  $_localDefiVotes votes'
                  : 'Défi  •  $_localDefiVotes votes',
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
      if (isDefiCreator(post, _authProvider.loginUserData.id)) return const SizedBox.shrink(); // le créateur ne peut pas participer (403 `creator_cannot_participate`)
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
              border: Border.all(
                color: hasAccess ? _defiYellow : _defiYellow.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sports_score, size: 14, color: Colors.white),
                SizedBox(width: 4),
                Text('Participer',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
    }

    // Réponse DÉFI → bouton Vote
    final canVote = hasAccess && !_hasVotedLocally && !_isVoting;

    return ScaleTransition(
      scale: _voteScaleAnim,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: hasAccess && !_isVoting ? _handleDefiVote : null,
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
                  '${_hasVotedLocally ? 'Voté' : 'Voter'} · '
                  '${_localDefiVotes >= 1000 ? '${(_localDefiVotes / 1000).toStringAsFixed(1)}k' : '$_localDefiVotes'}',
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

  Widget _buildPostActions() {
    final colors = AppColors.of(context);
    final isLiked = widget.post.users_love_id?.contains(_authProvider.loginUserData.id) ?? false;
    final hasAccess = !_isLockedContent;
    final myId = _authProvider.loginUserData.id;
    final totalInteractions = widget.post.interactionsCount;
    final isAd = widget.post.isAdvertisement == true;
    final hasReposted = widget.post.users_republier_id?.contains(myId) ?? false;

    final isDefi = widget.post.type == PostType.DEFI.name;
    final isDefiResponse = widget.post.defiResponseToPostId != null;

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
          _buildActionButton(
            icon: FontAwesome.comment_o,
            count: _localCommentsCount,
            color: colors.textSecondary,
            onPressed: hasAccess ? () => _showCommentsModal() : null,
          ),
          const SizedBox(width: 4),
          _buildActionButton(
            icon: isLiked ? FontAwesome.heart : FontAwesome.heart_o,
            count: widget.post.loves ?? 0,
            color: isLiked ? colors.danger : colors.textSecondary,
            onPressed: (hasAccess && !_isLiking) ? _handleLike : null,
            coinHeart: widget.post.isMonetized,
          ),
          const SizedBox(width: 4),
          if (!isAd && myId != null && myId != widget.post.user_id)
            _buildActionButton(
              icon: Icons.repeat,
              count: widget.post.users_republier_id?.length ?? 0,
              color: hasReposted ? colors.primary : colors.textSecondary,
              onPressed: hasAccess ? _handleRepost : null,
            ),
          const SizedBox(width: 4),
          if (hasAccess && myId != null && myId != widget.post.user_id)
            CadeauBadge(
              receiverId: widget.post.user_id!,
              receiverName: widget.post.user?.pseudo ?? 'Créateur',
              receiverAvatar: widget.post.user?.imageUrl ?? '',
              post: widget.post,
              giftCount: widget.post.totalGiftCoinsSentOnThisPost ?? 0,
              onGiftSuccess: () async {
                setState(() {
                  widget.post.users_cadeau_id ??= [];
                  if (!widget.post.users_cadeau_id!.contains(myId)) {
                    widget.post.users_cadeau_id!.add(myId);
                  }
                });
                await _coinProvider.refreshBalance(myId);
              },
            )
          else
            CadeauBadge(
              receiverId: widget.post.user_id ?? '',
              receiverName: widget.post.user?.pseudo ?? 'Créateur',
              receiverAvatar: widget.post.user?.imageUrl ?? '',
              post: widget.post,
              giftCount: widget.post.totalGiftCoinsSentOnThisPost ?? 0,
            ),
          const Spacer(),
          if (totalInteractions > 0)
            _buildInteractionsBadge(totalInteractions, colors),
        ],
      ),
        ),
      ],
    );
  }

  Widget _buildInteractionsBadge(int total, AppColors colors) {
    final label = total >= 1000 ? '${(total / 1000).toStringAsFixed(1)}k' : '$total';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.textSecondary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.bar_chart_rounded, size: 12, color: colors.textSecondary.withOpacity(0.5)),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: colors.textSecondary.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Future<void> _loadLastComment() async {
    final postId = widget.post.id;
    if (postId == null || _isLoadingComment) return;
    // Aucun commentaire annoncé : inutile d'interroger l'API pour rien (une lecture par post affiché)
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
    if (_authProvider.loginUserData.id == null) return;
    setState(() => _isSendingQuickComment = true);
    try {
      // 10 commentaires gratuits par publication, puis 1 pièce (erreur 402 : proposer de recharger)
      final sent = await CommentsApi.send(widget.post.id!, body: trimmed);
      final comment = sent.comment..user = _authProvider.loginUserData;
      if (mounted) {
        setState(() {
          _quickCommentController.clear();
          _preloadedComments.insert(0, comment);
          CommentsPrefetch.instance.addLocal(comment.post_id ?? '', comment);
          _localCommentsCount++;
          _localInteractionsCount++;
        });
      }
    } catch (e) {
      if (mounted) handleApiError(context, e, onRetry: () => _sendQuickComment(trimmed), fallback: "Erreur lors de l'envoi");
    } finally {
      if (mounted) setState(() => _isSendingQuickComment = false);
    }
  }

  String _capitalizeComment(String text) {
    if (text.isEmpty) return text;
    final first = String.fromCharCode(text.runes.first);
    if (first.toUpperCase() != first.toLowerCase()) {
      return first.toUpperCase() + text.substring(first.length);
    }
    return text;
  }

  Widget _buildCommentPreview() {
    if (_isLockedContent) return const SizedBox.shrink();
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
                    onTap: () => _showCommentsModal(),
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
    Color? color,
    VoidCallback? onPressed,
    bool isLoading = false,
    bool coinHeart = false, // like : cœur plus grand avec la pastille « +1 »
  }) {
    final colors = AppColors.of(context);
    final effectiveColor = onPressed != null ? (color ?? colors.textSecondary) : colors.textSecondary.withOpacity(0.3);
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
                SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: effectiveColor))
              else if (coinHeart)
                LikeCoinHeart(icon: icon, color: effectiveColor, size: 20)
              else
                Icon(icon, size: 18, color: effectiveColor),
              const SizedBox(width: 6),
              Text(_formatCount(count), style: TextStyle(color: effectiveColor, fontSize: 13)),
            ],
          ),
        ),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            children: [
              _isProcessingFavorite
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_isFavorite ? Icons.bookmark : Icons.bookmark_border, size: 18,
                  color: hasAccess ? colors.textSecondary : colors.textSecondary.withOpacity(0.3)),
              const SizedBox(width: 6),
              Text(_formatCount(widget.post.favoritesCount ?? 0),
                  style: TextStyle(color: hasAccess ? colors.textSecondary : colors.textSecondary.withOpacity(0.3), fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  // ==================== CYCLE DE VIE ====================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pauseVideo();
    } else if (state == AppLifecycleState.resumed && _isVisible && _isVideoInitialized && !_showCanalLockCta && !_showSeeMoreCta) {
      _playVideo();
    }
  }

  void _updateVolume() {
    if (_chewieController == null) return;
    final volume = _soundProvider.isMuted ? 0.0 : 1.0;
    _chewieController!.setVolume(volume);
    _videoController?.setVolume(volume);
    // Reprendre seulement si rien ne bloque la vidéo
    if (!_soundProvider.isMuted && _isVisible && !_chewieController!.isPlaying
        && !_showSeeMoreCta && !_showCanalLockCta) {
      _playVideo();
    }
    // Ne jamais mettre en pause à cause du son — seulement changer le volume
  }

  @override
  void dispose() {
    BlockService.instance.removeListener(_onBlockListChanged);
    _voteAnimController.dispose();
    _quickCommentController.dispose();
    _visibilityTimer?.cancel();
    _seeMoreTimer?.cancel();
    _canalLockTimer?.cancel();
    _authWatch.cancel();
    WidgetsBinding.instance.removeObserver(this);
    MediaPlaybackManager.unregisterMedia(widget.post.id ?? '');
    _disposeVideoControllers();

    // 🔥 Nettoyage : retirer l'écouteur
    _soundProvider.removeListener(_updateVolume);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (BlockService.instance.isBlocked(widget.post.user_id)) return const SizedBox.shrink();
    super.build(context);
    // Appui long : proposition « Créer une carte Afrolook » (les vidéos n'ont pas de menu « ⋯ » dans le fil)
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: () {
        if (widget.post.isAdvertisement == true) return;
        HapticFeedback.mediumImpact();
        CardEntry.showQuickSheet(context, widget.post);
      },
      child: _buildVideoCard(context),
    );
  }

  Widget _buildVideoCard(BuildContext context) {
    final colors = AppColors.of(context);
    final isAdCard = widget.post.isAdvertisement == true;

    // Pubs : format carte classique
    if (isAdCard) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: _buildPostHeader(),
            ),
            _buildVideoContent(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_isLockedContent) _buildPostContent() else _buildEventBadge(),
                  if (widget.post.artistSoundId != null && widget.post.artistSoundId!.isNotEmpty)
                    PostSoundCredit(soundId: widget.post.artistSoundId!, title: widget.post.artistSoundTitle ?? ''),
                    PostTemplateTry(post: widget.post),
                  const SizedBox(height: 12),
                  _buildPostActions(),
                  _buildCommentPreview(),
                ],
              ),
            ),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 350.ms)
          .slideY(begin: 0.04, end: 0, duration: 350.ms, curve: Curves.easeOut);
    }

    // Posts normaux : layout Threads
    final bool isPortraitVideoPost = widget.post.dataType == PostDataType.VIDEO.name &&
        (PostOrientation.of(widget.post));

    return Container(
      color: colors.background,
      child: Stack(
        children: [
          Positioned(
            left: 29,
            top: 56,
            bottom: 0,
            child: Container(width: 2, color: colors.divider),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatarWidget(),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPostHeaderInfo(),
                      const SizedBox(height: 8),
                      // Portrait : description au-dessus de la vidéo (comme posts image)
                      if (isPortraitVideoPost && !_isLockedContent) ...[
                        _buildPostContent(),
                        const SizedBox(height: 8),
                      ],
                      _buildVideoContent(),
                      if (widget.post.artistSoundId != null && widget.post.artistSoundId!.isNotEmpty)
                        PostSoundCredit(soundId: widget.post.artistSoundId!, title: widget.post.artistSoundTitle ?? ''),
                        PostTemplateTry(post: widget.post),
                      const SizedBox(height: 10),
                      _buildPostActions(),
                      _buildCommentPreview(),
                      if (_isLockedContent) _buildPostContent() else _buildEventBadge(),
                      if (!widget.suppressInlineAd && _shouldShowAd) ...[
                        const SizedBox(height: 12),
                        AdSlot(key: ValueKey('video_inline_ad_${widget.post.id}'), kind: AdSlotKind.feed, own: () => const AfrolookInlineAd()),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(height: 0.5, color: colors.divider),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.04, end: 0, duration: 350.ms, curve: Curves.easeOut);
  }
}