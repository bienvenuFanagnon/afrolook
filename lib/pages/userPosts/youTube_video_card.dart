import 'package:afrotok/utils/responsive_sheet.dart';
import 'dart:ui';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
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
import '../../widgets/gifts/quick_gift_bar.dart';
import '../component/showUserDetails.dart';
import '../postComments.dart';
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
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  // Contrôleurs vidéo
  VideoPlayerController? _videoController;
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _postProvider = Provider.of<PostProvider>(context, listen: false);

    _localCommentsCount = widget.post.comments ?? 0;
    _localInteractionsCount = widget.post.totalInteractions ?? 0;
    _coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);
    _soundProvider = Provider.of<SoundProvider>(context, listen: false);

    if (!_soundProvider.isMuted) {
      _soundProvider.setMuted(true);
    }
    // 🔥 S'abonner aux changements du provider de son (un seul abonnement, retiré dans dispose)
    _soundProvider.addListener(_updateVolume);
    _initSharedPreferences();
    _initFromSnapshot();
    _loadCreatorData();
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

  Future<void> _generateAndUploadThumbnail() async {
    // VideoThumbnail + dart:io File indisponibles sur Flutter Web
    if (kIsWeb) return;
    if (_isGeneratingThumbnail) return;
    setState(() => _isGeneratingThumbnail = true);

    try {
      final videoUrl = widget.post.url_media;
      if (videoUrl == null) return;

      final thumbnailFile = await VideoThumbnail.thumbnailFile(
        video: videoUrl,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 75,
        timeMs: 1000,
      );

      if (thumbnailFile == null) return;

      final fileName = 'thumbnails/thumb_${widget.post.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      final bytes = await XFile(thumbnailFile).readAsBytes();
      final uploadTask = ref.putData(bytes);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      await _firestore.collection('Posts').doc(widget.post.id).update({
        'thumbnail': downloadUrl,
      });

      if (mounted) {
        setState(() {
          _thumbnailUrl = downloadUrl;
          widget.post.thumbnail = downloadUrl;
        });
      }
    } catch (e) {
      printVm('Erreur génération miniature: $e');
    } finally {
      if (mounted) setState(() => _isGeneratingThumbnail = false);
    }
  }

  /// Hydrate _creatorUser / _creatorCanal depuis le snapshot stocké dans le post.
  /// Synchrone — appelé avant _loadCreatorData() pour un affichage immédiat.
  /// Ne stocke que les infos stables (pseudo, image, compteur) — les badges sont
  /// gérés par UserBadgeWidget et chargés avec le profil complet.
  void _initFromSnapshot() {
    final isCanalPost = widget.post.canal_id != null && widget.post.canal_id!.isNotEmpty;
    if (isCanalPost) {
      final snap = widget.post.canalSnapshot;
      if (snap != null) {
        _creatorCanal = Canal()
          ..titre = snap['titre'] as String?
          ..urlImage = snap['urlImage'] as String?
          ..suivi = snap['suivi'] as int? ?? 0;
      }
    } else {
      if (widget.post.user != null) {
        _creatorUser = widget.post.user;
        return;
      }
      final snap = widget.post.creatorSnapshot;
      if (snap != null) {
        _creatorUser = UserData()
          ..pseudo = snap['pseudo'] as String?
          ..imageUrl = snap['imageUrl'] as String?
          ..abonnes = snap['abonnes'] as int? ?? 0;
      }
    }
  }

  Future<void> _loadCreatorData() async {
    final isCanalPost = widget.post.canal_id != null && widget.post.canal_id!.isNotEmpty;
    if (isCanalPost) {
      // Réutilise le cache post si déjà chargé (scroll retour = 0 fetch)
      if (widget.post.canal != null) {
        _creatorCanal = widget.post.canal;
        if (mounted) setState(() {});
        return;
      }
      if (mounted) setState(() => _isLoadingUser = true);
      try {
        final canalDoc = await _firestore
            .collection('Canaux')
            .doc(widget.post.canal_id)
            .get();
        if (canalDoc.exists) {
          _creatorCanal = Canal.fromJson(canalDoc.data() as Map<String, dynamic>);
          widget.post.canal = _creatorCanal;
        }
      } catch (e) {
        printVm('Erreur chargement canal: $e');
      } finally {
        if (mounted) setState(() => _isLoadingUser = false);
      }
    } else if (widget.post.user_id != null) {
      // Réutilise le cache post si déjà chargé
      if (widget.post.user != null) {
        _creatorUser = widget.post.user;
        if (mounted) setState(() {});
        return;
      }
      if (mounted) setState(() => _isLoadingUser = true);
      try {
        final userDoc = await _firestore
            .collection('Users')
            .doc(widget.post.user_id)
            .get();
        if (userDoc.exists) {
          _creatorUser = UserData.fromJson(userDoc.data() as Map<String, dynamic>);
          widget.post.user = _creatorUser;
        }
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
    _firestore.collection('Posts').doc(postId).update({
      'loves': FieldValue.increment(-1),
      'users_love_id': FieldValue.arrayRemove([userId]),
      'popularity': FieldValue.increment(-1),
    }).catchError((_) {
      if (mounted) setState(() {
        widget.post.loves = ((widget.post.loves ?? 0) + 1);
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

    _coinProvider.sendLikeWithCoins(
      senderId: userId,
      receiverId: receiverId,
      post: widget.post,
      context: context,
    ).then((success) async {
      if (!success) {
        await _firestore.collection('Posts').doc(postId).update({
          'loves': FieldValue.increment(1),
          'users_love_id': FieldValue.arrayUnion([userId]),
          'popularity': FieldValue.increment(1),
        }).catchError((_) {});
        if (mounted) _showInsufficientCoinsDialog();
        return;
      }
      if (mounted) {
        try {
          addPointsForAction(UserAction.like);
          addPointsForOtherUserAction(receiverId, UserAction.autre);
          await _sendLikeNotifications();
        } catch (_) {}
      }
    }).catchError((e) async {
      debugPrint('Like transaction failed: $e');
      try {
        await _firestore.collection('Posts').doc(postId).update({
          'loves': FieldValue.increment(1),
          'users_love_id': FieldValue.arrayUnion([userId]),
          'popularity': FieldValue.increment(1),
        });
        if (mounted) {
          try { await _sendLikeNotifications(); } catch (_) {}
        }
      } catch (_) {
        if (mounted) setState(() {
          widget.post.loves = ((widget.post.loves ?? 1) - 1).clamp(0, double.maxFinite.toInt());
          widget.post.users_love_id?.remove(userId);
        });
      }
    }).whenComplete(() {
      if (mounted) setState(() => _isLiking = false);
    });
  }

  void _showInsufficientCoinsDialog() {
    final colors = AppColors.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '💡 Soutenez le créateur !',
          style: TextStyle(color: colors.accent, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chaque like que vous envoyez offre 1 pièce au créateur du post !',
              style: TextStyle(color: colors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.accent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Le like coûte 2 pièces :\n• 1 pour soutenir le créateur\n• 1 pour le système',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Rechargez votre compte pour continuer à soutenir vos créateurs préférés !',
              style: TextStyle(color: colors.textSecondary, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annuler', style: TextStyle(color: colors.textSecondary)),
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
              backgroundColor: colors.accent,
              foregroundColor: colors.onAccent,
            ),
            child: const Text('Recharger', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendLikeNotifications() async {
    final currentTimeMicroseconds = DateTime.now().microsecondsSinceEpoch;
    final userDoc = await _firestore.collection('Users').doc(widget.post.user_id!).get();

    if (userDoc.exists) {
      final lastNotificationTime = userDoc.data()?['lastNotificationTime'] ?? 0;
      const twentyMinutesMicroseconds = 20 * 60 * 1000 * 1000;

      if (currentTimeMicroseconds - lastNotificationTime >= twentyMinutesMicroseconds || lastNotificationTime == 0) {
        final notificationId = _firestore.collection('Notifications').doc().id;
        final notification = NotificationData(
          id: notificationId,
          titre: "Like ❤️ + 1 pièce",
          media_url: _authProvider.loginUserData.imageUrl,
          type: NotificationType.POST.name,
          description: "@${_authProvider.loginUserData.pseudo!} a aimé votre vidéo et vous a offert 1 pièce !",
          users_id_view: [],
          user_id: _authProvider.loginUserData.id!,
          receiver_id: widget.post.user_id!,
          post_id: widget.post.id!,
          post_data_type: PostDataType.VIDEO.name,
          updatedAt: currentTimeMicroseconds,
          createdAt: currentTimeMicroseconds,
          status: PostStatus.VALIDE.name,
        );
        await _firestore.collection('Notifications').doc(notificationId).set(notification.toJson());

        final oneSignalId = (userDoc.data()?['oneIgnalUserid'] as String?)
            ?? _creatorUser?.oneIgnalUserid;
        if (oneSignalId != null) {
          await _authProvider.sendNotification(
            userIds: [oneSignalId],
            smallImage: _authProvider.loginUserData.imageUrl ?? '',
            send_user_id: _authProvider.loginUserData.id!,
            recever_user_id: widget.post.user_id!,
            message: "📢 @${_authProvider.loginUserData.pseudo ?? ''} a aimé votre vidéo et vous a offert 1 pièce !",
            type_notif: NotificationType.POST.name,
            post_id: widget.post.id!,
            post_type: PostDataType.VIDEO.name,
            chat_id: '',
          );
        }

        await _firestore.collection('Users').doc(widget.post.user_id!).update({
          'lastNotificationTime': currentTimeMicroseconds
        });
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isProcessingFavorite) return;
    _isProcessingFavorite = true;

    final userId = _authProvider.loginUserData.id!;
    final postId = widget.post.id!;

    try {
      if (_isFavorite) {
        await _firestore.collection('Posts').doc(postId).update({
          'users_favorite_id': FieldValue.arrayRemove([userId]),
          'favorites_count': FieldValue.increment(-1),
        });
        setState(() {
          _isFavorite = false;
          widget.post.favoritesCount = (widget.post.favoritesCount ?? 0) - 1;
        });
      } else {
        await _firestore.collection('Posts').doc(postId).update({
          'users_favorite_id': FieldValue.arrayUnion([userId]),
          'favorites_count': FieldValue.increment(1),
        });
        setState(() {
          _isFavorite = true;
          widget.post.favoritesCount = (widget.post.favoritesCount ?? 0) + 1;
        });

        if (_creatorUser?.oneIgnalUserid != null) {
          await _authProvider.sendNotification(
            userIds: [_creatorUser!.oneIgnalUserid!],
            smallImage: _authProvider.loginUserData.imageUrl!,
            send_user_id: userId,
            recever_user_id: widget.post.user_id!,
            message: "❤️ @${_authProvider.loginUserData.pseudo} a ajouté votre vidéo à ses favoris",
            type_notif: NotificationType.FAVORITE.name,
            post_id: postId,
            post_type: PostDataType.VIDEO.name,
            chat_id: '',
          );
        }
      }
    } catch (e) {
      printVm('Erreur favori: $e');
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

      setState(() {
        widget.post.partage = (widget.post.partage ?? 0) + 1;
        widget.post.users_partage_id ??= [];
        widget.post.users_partage_id!.add(_authProvider.loginUserData.id!);
      });

      await _firestore.collection('Posts').doc(widget.post.id).update({
        'partage': FieldValue.increment(1),
        'users_partage_id': FieldValue.arrayUnion([_authProvider.loginUserData.id]),
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
        height: MediaQuery.of(context).size.height * 0.85,
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
      final country = AfricanCountry.allCountries.firstWhere(
            (c) => c.code == firstCountryCode,
        orElse: () => AfricanCountry(code: firstCountryCode, name: firstCountryCode, flag: '🏳️'),
      );
      flagEmoji = country.flag;
      displayText = countryCodes.length == 1 ? firstCountryCode : '+${countryCodes.length - 1}';
    }

    final backgroundColor = isAllCountries ? const Color(0xFFFFD700).withOpacity(0.9) : const Color(0xFFE21221).withOpacity(0.9);
    final textColor = isAllCountries ? Colors.black : Colors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18, height: 18,
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(9)),
            child: Center(child: Text(flagEmoji, style: const TextStyle(fontSize: 10))),
          ),
          const SizedBox(width: 6),
          Text(displayText, style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.w600)),
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
                      final country = AfricanCountry.allCountries.firstWhere(
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
              CircleAvatar(
                radius: 23,
                backgroundColor: colors.primary,
                backgroundImage: (isCanalPost && _creatorCanal?.urlImage != null)
                    ? NetworkImage(_creatorCanal!.urlImage!)
                    : (_creatorUser?.imageUrl != null ? NetworkImage(_creatorUser!.imageUrl!) : null),
                child: ((isCanalPost && _creatorCanal?.urlImage == null) || (_creatorUser?.imageUrl == null))
                    ? Icon(isCanalPost ? Icons.group : Icons.person, color: Colors.white, size: 20)
                    : null,
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
                        Text(
                          isCanalPost ? '#${_creatorCanal?.titre ?? ''}' : '@${_creatorUser?.pseudo ?? ''}',
                          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
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
              const SizedBox(height: 2),
              Text(
                isCanalPost
                    ? '${_creatorCanal?.usersSuiviId?.length ?? 0} abonné(s)'
                    : '${_creatorUser?.userAbonnesIds?.length ?? 0} abonné(s)',
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
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
                    child: Text(
                      '@${widget.post.user?.pseudo ?? 'utilisateur'}',
                      style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '0 abonné(s)',
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
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
    final text = widget.post.description ?? "";
    final isLocked = _isLockedContent;

    if (isLocked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text.length > 100 ? '${text.substring(0, 100)}...' : text,
              style: TextStyle(fontSize: 15, color: colors.textSecondary, height: 1.4), maxLines: 2),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.lock, color: colors.accent, size: 16),
            const SizedBox(width: 4),
            Text('Contenu réservé aux abonnés', style: TextStyle(color: colors.accent, fontSize: 12, fontWeight: FontWeight.w500)),
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
                  child: Icon(Icons.lock_outline, color: colors.accent, size: 32),
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
                  ? Image.network(_thumbnailUrl!, fit: BoxFit.cover, height: h * 0.38, width: double.infinity,
                  errorBuilder: (context, error, stackTrace) => Container(height: h * 0.38, width: double.infinity, color: colors.shimmerBase,
                      child: Icon(Icons.videocam, size: 50, color: colors.textSecondary)))
                  : Container(height: h * 0.38, width: double.infinity, color: colors.shimmerBase,
                  child: Icon(Icons.videocam, size: 50, color: colors.textSecondary)),
            ),
            if (_isVideoLoading)
              Container(height: h * 0.38, width: double.infinity, color: Colors.black.withOpacity(0.7),
                  child: Center(child: CircularProgressIndicator(color: colors.primary))),
            // Verrou canal privé — s'affiche après 10s de lecture
            if (_showCanalLockCta)
              _buildCanalLockOverlay(colors),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isAd = widget.post.isAdvertisement == true;

    // Pubs vidéo : 16:9 paysage (pas de déformation, pas de boîtes noires)
    // Vidéos normales : portrait ~1.3x
    final double videoHeight = isAd
        ? (screenWidth * (9.0 / 16.0)).clamp(200.0, 320.0)
        : (screenWidth * 1.3).clamp(380.0, 620.0);

    return VisibilityDetector(
      key: Key('video_${widget.post.id}'),
      onVisibilityChanged: (info) => onVisibilityChanged(info.visibleFraction),
      child: GestureDetector(
        onTap: _showCanalLockCta ? null : _navigateToDetails,
        child: Stack(
          children: [
            // --- Conteneur vidéo ---
            ClipRRect(
              borderRadius: BorderRadius.zero,
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
                          width: double.infinity,
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
                          width: double.infinity,
                          height: videoHeight,
                          child: Chewie(controller: _chewieController!),
                        )
                  : _isGeneratingThumbnail
                  ? Container(
                      height: videoHeight,
                      width: double.infinity,
                      color: colors.shimmerBase,
                      child: const Center(child: CircularProgressIndicator()),
                    )
                  : _thumbnailUrl != null
                  ? Image.network(
                      _thumbnailUrl!,
                      fit: BoxFit.cover,
                      height: videoHeight,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: videoHeight,
                        width: double.infinity,
                        color: colors.shimmerBase,
                        child: Icon(Icons.videocam, size: 50, color: colors.textSecondary),
                      ),
                    )
                  : Container(
                      height: videoHeight,
                      width: double.infinity,
                      color: colors.shimmerBase,
                      child: Icon(Icons.videocam, size: 50, color: colors.textSecondary),
                    ),
            ),
            // --- Indicateur de chargement ---
            if (_isVideoLoading)
              Container(
                height: videoHeight,
                width: double.infinity,
                color: Colors.black.withOpacity(0.7),
                child: Center(child: CircularProgressIndicator(color: colors.primary)),
              ),
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
            // --- Description overlay en bas (masquée quand "Voir la suite" ou verrou) ---
            if (!isLocked && !_showSeeMoreCta && !_showCanalLockCta && !isAd &&
                (widget.post.description ?? '').trim().isNotEmpty)
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: GestureDetector(
                  onTap: _navigateToDetails,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 36, 48, 10),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
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
                        const SizedBox(width: 6),
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

  Widget _buildPostActions() {
    final colors = AppColors.of(context);
    final isLiked = widget.post.users_love_id?.contains(_authProvider.loginUserData.id) ?? false;
    final hasAccess = !_isLockedContent;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildActionButton(icon: FontAwesome.comment_o, count: _localCommentsCount, color: colors.textSecondary, onPressed: hasAccess ? () => _showCommentsModal() : null),
          _buildActionButton(icon: Icons.bar_chart, count: _localInteractionsCount, color: colors.textSecondary, onPressed: hasAccess ? _navigateToDetails : null),
          _buildActionButton(
            icon: isLiked ? FontAwesome.heart : FontAwesome.heart_o,
            count: widget.post.loves ?? 0,
            color: isLiked ? colors.danger : colors.textSecondary,
            onPressed: (hasAccess && !_isLiking) ? _handleLike : null,
          ),
          _buildFavoriteButton(hasAccess),
          if (hasAccess && _authProvider.loginUserData.id != widget.post.user_id)
            QuickGiftBar(
              receiverId: widget.post.user_id!,
              receiverName: widget.post.user?.pseudo ?? 'Créateur',
              receiverAvatar: widget.post.user?.imageUrl ?? '',
              post: widget.post,
              giftCount: widget.post.totalGiftCoinsSentOnThisPost ?? 0,
              onGiftSuccess: () async {
                setState(() {
                  widget.post.users_cadeau_id ??= [];
                  if (!widget.post.users_cadeau_id!.contains(_authProvider.loginUserData.id!)) {
                    widget.post.users_cadeau_id!.add(_authProvider.loginUserData.id!);
                  }
                });
                await _coinProvider.refreshBalance(_authProvider.loginUserData.id!);
              },
            )
          else
            _buildActionButton(icon: FontAwesome.gift, count: widget.post.totalGiftCoinsSentOnThisPost ?? 0, color: colors.textSecondary, onPressed: null),
        //   _isSharing
        //       ? const SizedBox(width: 40, height: 40, child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
        //       : _buildActionButton(icon: Icons.share, count: widget.post.partage ?? 0, color: colors.textSecondary, onPressed: hasAccess ? _handleShare : null),
         ],
      ),
    );
  }

  Future<void> _loadLastComment() async {
    final postId = widget.post.id;
    if (postId == null || _isLoadingComment) return;
    setState(() => _isLoadingComment = true);
    try {
      final snap = await _firestore
          .collection('PostComments')
          .where('post_id', isEqualTo: postId)
          .orderBy('created_at', descending: true)
          .limit(5)
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

  void _autoLikeIfNeeded(String userId) {
    final postId = widget.post.id;
    if (postId == null) return;
    final alreadyLiked = widget.post.users_love_id?.contains(userId) ?? false;
    if (alreadyLiked) return;
    FirebaseFirestore.instance.collection('Posts').doc(postId).update({
      'loves': FieldValue.increment(1),
      'users_love_id': FieldValue.arrayUnion([userId]),
    }).catchError((_) {});
    if (mounted) setState(() {
      widget.post.users_love_id ??= [];
      widget.post.users_love_id!.add(userId);
      widget.post.loves = (widget.post.loves ?? 0) + 1;
    });
  }

  Future<void> _sendQuickComment(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSendingQuickComment) return;
    final userId = _authProvider.loginUserData.id;
    if (userId == null) return;

    setState(() {
      _isSendingQuickComment = true;
      _quickCommentController.clear();
    });

    try {
      final comment = PostComment(
        id: FirebaseFirestore.instance.collection('PostComments').doc().id,
        user_id: userId,
        user: _authProvider.loginUserData,
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

      final success = await _postProvider.newComment(comment);

      if (success) {
        if (mounted) {
          setState(() {
            _preloadedComments.insert(0, comment);
            _localCommentsCount++;
            _localInteractionsCount++;
          });
        }

        _authProvider.incrementPostTotalInteractions(postId: widget.post.id!);
        _authProvider.notifySubscribersOfInteraction(
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
          debugPrint('[Streak] erreur quickComment youtube: $e');
        }
        _authProvider.checkAndRefreshPostDates(widget.post.id!);

        // Notification au propriétaire du post
        if (widget.post.user != null && widget.post.user!.id != userId) {
          try {
            final msg = "@${_authProvider.loginUserData.pseudo!} a commenté votre publication";
            final notif = NotificationData(
              id: FirebaseFirestore.instance.collection('Notifications').doc().id,
              titre: "Nouvelle interaction",
              media_url: _authProvider.loginUserData.imageUrl,
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
            final receiverUser = await _authProvider.getUserById(widget.post.user!.id!);
            if (receiverUser.isNotEmpty && receiverUser.first.oneIgnalUserid != null) {
              await _authProvider.sendNotification(
                userIds: [receiverUser.first.oneIgnalUserid!],
                smallImage: _authProvider.loginUserData.imageUrl!,
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
    final rawMsg = _preloadedComments.isNotEmpty ? _preloadedComments.first.message : null;
    final msg = rawMsg != null && rawMsg.trim().isNotEmpty
        ? _capitalizeComment(rawMsg.trim())
        : null;

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
    Color? color,
    VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    final colors = AppColors.of(context);
    final effectiveColor = onPressed != null ? (color ?? colors.textSecondary) : colors.textSecondary.withOpacity(0.3);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            children: [
              if (isLoading)
                SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: effectiveColor))
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
    _quickCommentController.dispose();
    _visibilityTimer?.cancel();
    _seeMoreTimer?.cancel();
    _canalLockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    MediaPlaybackManager.unregisterMedia(widget.post.id ?? '');
    _disposeVideoControllers();

    // 🔥 Nettoyage : retirer l'écouteur
    _soundProvider.removeListener(_updateVolume);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = AppColors.of(context);
    final h = MediaQuery.of(context).size.height;

    final isAdCard = widget.post.isAdvertisement == true;
    return Container(
      margin: isAdCard
          ? const EdgeInsets.symmetric(vertical: 8)
          : const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: isAdCard ? BorderRadius.zero : BorderRadius.circular(16),
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
                // Description montrée en overlay sur la vidéo — ici on garde uniquement contenu verrouillé et badge
                if (_isLockedContent) _buildPostContent() else _buildEventBadge(),
                const SizedBox(height: 12),
                _buildPostActions(),
                _buildCommentPreview(),
                if (!widget.suppressInlineAd && _shouldShowAd && widget.post.isAdvertisement != true) ...[
                  const SizedBox(height: 12),
                  const AfrolookInlineAd(),
                ],
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
}