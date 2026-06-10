import 'dart:io';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/postProvider.dart';
import '../../providers/sound_provider.dart';
import '../../providers/userProvider.dart';
import '../canaux/detailsCanal.dart';
import '../coins/post_gifts_list.dart';
import '../component/consoleWidget.dart';
import '../home/user_presence_widget.dart';
import '../pub/native_ad_widget.dart';
import 'dart:async';

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
import '../component/showUserDetails.dart';
import '../postComments.dart';
import '../postDetailsVideo.dart';

import '../../services/utils/abonnement_utils.dart';


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

  static void registerVideo(
      String postId,
      VideoPlayerController controller,
      ChewieController chewieController,
      VoidCallback onPause,
      ) {
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

  const YouTubeVideoCard({
    Key? key,
    required this.post,
    required this.onTap,
    this.index = 0,
    this.onNeighborhoodPreload,
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
  bool _isLoading = false;

  // Interaction vidéo (une seule fois par jour)
  bool _hasRecordedInteraction = false;
  String? _lastInteractionDateKey;
  SharedPreferences? _prefs;

  // Timer pour la visibilité
  Timer? _visibilityTimer;

  // Pour la publication
  final String appId = 'AfrolookApp';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool get _shouldShowAd => (widget.index + 1) % 2 == 0;

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
    _coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);
    // 🔥 Récupérez le SoundProvider
    _soundProvider = Provider.of<SoundProvider>(context, listen: false);

    // 🔥 Forcer le son coupé par défaut (si ce n’est pas déjà le cas)
    if (!_soundProvider.isMuted) {
      _soundProvider.setMuted(true);
    }
    _initSharedPreferences();
    _loadCreatorData();
    _checkIfFavorite();
    _checkInteractionRecordedToday();

    if (widget.post.thumbnail == null || widget.post.thumbnail!.isEmpty) {
      _generateAndUploadThumbnail();
    } else {
      _thumbnailUrl = widget.post.thumbnail;
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
      final uploadTask = ref.putFile(File(thumbnailFile));
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
      print('Erreur génération miniature: $e');
    } finally {
      if (mounted) setState(() => _isGeneratingThumbnail = false);
    }
  }

  Future<void> _loadCreatorData() async {
    if (widget.post.canal_id != null && widget.post.canal_id!.isNotEmpty) {
      setState(() => _isLoadingUser = true);
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
        print('Erreur chargement canal: $e');
      } finally {
        setState(() => _isLoadingUser = false);
      }
    }
    if (widget.post.user_id != null) {
      setState(() => _isLoadingUser = true);
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
        print('Erreur chargement utilisateur: $e');
      } finally {
        setState(() => _isLoadingUser = false);
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
    if (_isLockedContent) {
      print('🎬 Vidéo verrouillée - initialisation bloquée');
      return;
    }

    if (_isVideoInitialized || _isVideoLoading || _isInitializingVideo) return;
    if (widget.post.url_media == null || widget.post.url_media!.isEmpty) return;

    _isInitializingVideo = true;
    setState(() => _isVideoLoading = true);

    try {
      await _disposeVideoControllers();

      // _videoController = VideoPlayerController.network(widget.post.url_media!);
      final String optimizedUrl = _authProvider. convertToCdnUrl(widget.post.url_media!, _authProvider.appDefaultData);
      _videoController = VideoPlayerController.network(optimizedUrl);
      await _videoController!.initialize();

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

      _chewieController = ChewieController(

        videoPlayerController: _videoController!,
        autoPlay: false,           // Lecture automatique
        looping: true,
        showControls: false,      // 🔥 PAS DE CONTRÔLES AFFICHÉS
        allowFullScreen: false,   // Désactiver le plein écran (sinon les contrôles réapparaissent)
        materialProgressColors: ChewieProgressColors(
          playedColor: Color(0xFF25D366),
          handleColor: Color(0xFF25D366),
          backgroundColor: Colors.grey,
          bufferedColor: Colors.grey,
        ),
        placeholder: Container(
          color: Colors.black,
          child: const Center(child: CircularProgressIndicator(color: Color(0xFF25D366))),
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
      print('Erreur initialisation vidéo: $e');
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
      print('Erreur enregistrement interaction: $e');
    }
  }

  void _playVideo() {
    // 🔥 CRITIQUE: Ne pas jouer la vidéo si le contenu est verrouillé
    if (_isLockedContent) {
      print('🎬 Vidéo verrouillée - lecture bloquée');
      return;
    }

    if (_chewieController != null) {
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
    // 🔥 CRITIQUE: Ne rien faire si le contenu est verrouillé
    if (_isLockedContent) {
      print('🎬 Vidéo verrouillée - visibilité ignorée');
      return;
    }

    if (_isVideoInitialized && _chewieController != null) {
      MediaPlaybackManager.pauseCurrentMedia();
      MediaPlaybackManager.registerVideo(
        widget.post.id!,
        _videoController!,
        _chewieController!,
            () => _pauseVideo(),
      );

      // 🔥 NOUVEAU : Vérifier l'état global du son AVANT de jouer
      final isMuted = _soundProvider.isMuted;

      // Appliquer le volume selon l'état global
      _chewieController!.setVolume(isMuted ? 0.0 : 1.0);

      // Jouer la vidéo si le son est activé, sinon la laisser en pause
      if (!isMuted) {
        _playVideo();
        print('🔊 Son activé : lecture vidéo');
      } else {
        print('🔇 Son coupé globalement : vidéo en pause');
        // La vidéo reste en pause, l'utilisateur devra activer le son manuellement
      }
      return;
    }

    if (!_isVideoInitialized && !_isVideoLoading && !_isInitializingVideo) {
      _initializeVideo();
    }
  }

  void _onBecameVisible2() {
    // 🔥 CRITIQUE: Ne rien faire si le contenu est verrouillé
    if (_isLockedContent) {
      print('🎬 Vidéo verrouillée - visibilité ignorée');
      return;
    }

    if (_isVideoInitialized && _chewieController != null) {
      MediaPlaybackManager.pauseCurrentMedia();

      MediaPlaybackManager.registerVideo(
        widget.post.id!,
        _videoController!,
        _chewieController!,
            () => _pauseVideo(),
      );

      _playVideo();
      return;
    }

    if (!_isVideoInitialized && !_isVideoLoading && !_isInitializingVideo) {
      _initializeVideo();
    }
  }

  void _onBecameInvisible() {
    // On peut toujours mettre en pause même si verrouillé (au cas où)
    if (_isVideoInitialized && _chewieController != null) {
      _pauseVideo();
    }
  }

  // ==================== ACTIONS DU POST ====================

  Future<void> _handleLike() async {
    final hasEnoughCoins = _coinProvider.giftCoinsBalance >= 2;

    if (!hasEnoughCoins) {
      _showInsufficientCoinsDialog();
      return;
    }

    final success = await _coinProvider.sendLikeWithCoins(
      senderId: _authProvider.loginUserData.id!,
      receiverId: widget.post.user_id!,
      post: widget.post,
      context: context,
    );

    if (!success) {
      _showInsufficientCoinsDialog();
      return;
    }

    setState(() {
      widget.post.loves = (widget.post.loves ?? 0) + 1;
      widget.post.users_love_id ??= [];
      widget.post.users_love_id!.add(_authProvider.loginUserData.id!);
    });

    addPointsForAction(UserAction.like);
    addPointsForOtherUserAction(widget.post.user_id!, UserAction.autre);
    await _sendLikeNotifications();
  }

  void _showInsufficientCoinsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '💡 Soutenez le créateur !',
          style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chaque like que vous envoyez offre 1 pièce au créateur du post !',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Text('🪙', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Le like coûte 2 pièces :\n• 1 pour soutenir le créateur\n• 1 pour le système',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Rechargez votre compte pour continuer à soutenir vos créateurs préférés !',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
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
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
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

        if (_creatorUser?.oneIgnalUserid != null) {
          await _authProvider.sendNotification(
            userIds: [_creatorUser!.oneIgnalUserid!],
            smallImage: _authProvider.loginUserData.imageUrl!,
            send_user_id: _authProvider.loginUserData.id!,
            recever_user_id: widget.post.user_id!,
            message: "📢 @${_authProvider.loginUserData.pseudo!} a aimé votre vidéo et vous a offert 1 pièce !",
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
      print('Erreur favori: $e');
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
      print('Erreur partage: $e');
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

  void _showCommentsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFF000000),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Commentaires', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Expanded(child: PostComments(post: widget.post)),
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
    final countryCodes = widget.post.availableCountries ?? [];

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

  Widget _buildPostHeader() {
    final isCanalPost = _creatorCanal != null;

    if (!isCanalPost && _creatorUser == null) {
      return _buildPlaceholderHeader();
    }

    final postOwner = isCanalPost ? _creatorCanal! : _creatorUser!;
    final isCurrentUser = _authProvider.loginUserData.id == widget.post.user_id;
    final isAbonne = isCanalPost
        ? (_creatorCanal?.usersSuiviId?.contains(_authProvider.loginUserData.id) ?? false)
        : (_creatorUser?.userAbonnesIds?.contains(_authProvider.loginUserData.id) ?? false);

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
                backgroundColor: const Color(0xFF2E7D32),
                backgroundImage: (isCanalPost && _creatorCanal?.urlImage != null)
                    ? NetworkImage(_creatorCanal!.urlImage!)
                    : (_creatorUser?.imageUrl != null ? NetworkImage(_creatorUser!.imageUrl!) : null),
                child: ((isCanalPost && _creatorCanal?.urlImage == null) || (_creatorUser?.imageUrl == null))
                    ? Icon(isCanalPost ? Icons.group : Icons.person, color: Colors.white, size: 20)
                    : null,
              ),

              // 🔥 INDICATEUR EN LIGNE (Utilise directement l'ID de l'auteur du post)
              if (widget.post.user_id != null)
                Positioned(
                  top: 0,
                  left: 0,
                  child: UserPresenceWidget(
                    userId: widget.post.user_id!,
                    size: 11.0, // Contrôle de la taille du point vert
                    showTextStatus: false, // Uniquement le point vert sur l'avatar
                  ),
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
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(width: 4),

                        if (_creatorUser?.abonnement != null)
                          AbonnementUtils.getUserBadge(abonnement: _creatorUser?.abonnement, isVerified: _creatorUser?.isVerify ?? false),
                      ],
                    ),
                  ),
                  if (!isCurrentUser && !isAbonne) _buildFollowButton(isCanalPost, postOwner),
                  const SizedBox(width: 5),
                  _buildCountryBadge(),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                isCanalPost
                    ? '${_creatorCanal?.usersSuiviId?.length ?? 0} abonné(s)'
                    : '${_creatorUser?.userAbonnesIds?.length ?? 0} abonné(s)',
                style: const TextStyle(color: Color(0xFF71767B), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
  Widget _buildPlaceholderHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CircleAvatar(
          radius: 23,
          backgroundColor: Color(0xFF2E7D32),
          child: Icon(Icons.person, color: Colors.white, size: 20),
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
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              const Text(
                '0 abonné(s)',
                style: TextStyle(color: Color(0xFF71767B), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFollowButton(bool isCanalPost, dynamic postOwner) {
    return Container(
      height: 28,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isCanalPost && (postOwner as Canal).isPrivate == true ? const Color(0xFFFFD600) : const Color(0xFF2E7D32),
          foregroundColor: isCanalPost && (postOwner as Canal).isPrivate == true ? Colors.black : Colors.white,
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
            print('Erreur abonnement: $e');
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
    final text = widget.post.description ?? "";
    final isLocked = _isLockedContent;

    if (isLocked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text.length > 100 ? '${text.substring(0, 100)}...' : text,
              style: const TextStyle(fontSize: 15, color: Color(0xFF71767B), height: 1.4), maxLines: 2),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.lock, color: Color(0xFFFFD600), size: 16),
            const SizedBox(width: 4),
            const Text('Contenu réservé aux abonnés', style: TextStyle(color: Color(0xFFFFD600), fontSize: 12, fontWeight: FontWeight.w500)),
          ]),
        ],
      );
    }

    final words = text.split(' ');
    final isLong = words.length > 50;
    final displayedText = _isExpanded || !isLong ? text : '${words.take(50).join(' ')}...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _navigateToDetails,
          child: HashTagText(
            text: displayedText,
            decoratedStyle: const TextStyle(fontSize: 15, color: Color(0xFF1D9BF0), height: 1.4),
            basicStyle: const TextStyle(fontSize: 15, color: Colors.white, height: 1.4),
            onTap: (text) {},
          ),
        ),
        if (isLong)
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_isExpanded ? "Voir moins" : "Voir plus",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1D9BF0))),
            ),
          ),
        _buildEventBadge(),
      ],
    );
  }

  Widget _buildVideoContent2() {
    final isLocked = _isLockedContent;
    final h = MediaQuery.of(context).size.height;

    return VisibilityDetector(
      key: Key('video_${widget.post.id}'),
      onVisibilityChanged: (info) => onVisibilityChanged(info.visibleFraction),
      child: GestureDetector(
        onTap: isLocked ? null : _navigateToDetails, // 🔥 Clic → détails
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              child: _isVideoInitialized && _chewieController != null && !isLocked
                  ? AspectRatio(aspectRatio: 16 / 9, child: Chewie(controller: _chewieController!))
                  : _isGeneratingThumbnail
                  ? Container(height: h * 0.25, width: double.infinity, color: Colors.grey[900],
                  child: const Center(child: CircularProgressIndicator()))
                  : _thumbnailUrl != null
                  ? Image.network(_thumbnailUrl!, fit: BoxFit.cover, height: h * 0.25, width: double.infinity)
                  : Container(height: h * 0.25, width: double.infinity, color: Colors.grey[900],
                  child: const Icon(Icons.videocam, size: 50, color: Colors.grey)),
            ),
            if (_isVideoLoading && !isLocked)
              Container(height: h * 0.25, width: double.infinity, color: Colors.black.withOpacity(0.7),
                  child: const Center(child: CircularProgressIndicator(color: Color(0xFF25D366)))),
            // 🔥 Supprimer l'icône play superflue – on garde juste la vidéo sans contrôle
            // Overlay de verrouillage
            if (isLocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock, color: Color(0xFFFFD600), size: 50),
                        const SizedBox(height: 8),
                        const Text('Vidéo verrouillée', style: TextStyle(color: Color(0xFFFFD600), fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('Abonnez-vous pour voir cette vidéo', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            if (_creatorCanal != null) {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => CanalDetails(canal: _creatorCanal!)));
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD600), foregroundColor: Colors.black),
                          child: const Text('S\'abonner maintenant'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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
    final isLocked = _isLockedContent;
    final screenWidth = MediaQuery.of(context).size.width;

// 📺 Mini player pour vidéos portrait
    final double videoHeight =  (screenWidth * 1.15).clamp(320.0, 500.0);

    return VisibilityDetector(
      key: Key('video_${widget.post.id}'),
      onVisibilityChanged: (info) => onVisibilityChanged(info.visibleFraction),
      child: GestureDetector(
        onTap: isLocked ? null : _navigateToDetails,
        child: Stack(
          children: [
            // --- Conteneur vidéo agrandi ---
            ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              child: _isVideoInitialized && _chewieController != null && !isLocked
                  ? SizedBox(
                width: double.infinity,
                height: videoHeight,
                child: Chewie(controller: _chewieController!),
              )
                  : _isGeneratingThumbnail
                  ? Container(
                height: videoHeight,
                width: double.infinity,
                color: Colors.grey[900],
                child: const Center(child: CircularProgressIndicator()),
              )
                  : _thumbnailUrl != null
                  ? Image.network(
                _thumbnailUrl!,
                fit: BoxFit.cover,
                height: videoHeight,
                width: double.infinity,
              )
                  : Container(
                height: videoHeight,
                width: double.infinity,
                color: Colors.grey[900],
                child: const Icon(Icons.videocam, size: 50, color: Colors.grey),
              ),
            ),
            // --- Indicateur de chargement ---
            if (_isVideoLoading && !isLocked)
              Container(
                height: videoHeight,
                width: double.infinity,
                color: Colors.black.withOpacity(0.7),
                child: const Center(child: CircularProgressIndicator(color: Color(0xFF25D366))),
              ),
            // --- Overlay de contenu verrouillé (inchangé) ---
            if (isLocked)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock, color: Color(0xFFFFD600), size: 50),
                        const SizedBox(height: 8),
                        const Text('Vidéo verrouillée', style: TextStyle(color: Color(0xFFFFD600), fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('Abonnez-vous pour voir cette vidéo', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            if (_creatorCanal != null) {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => CanalDetails(canal: _creatorCanal!)));
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFD600), foregroundColor: Colors.black),
                          child: const Text('S\'abonner maintenant'),
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
    final isLiked = widget.post.users_love_id?.contains(_authProvider.loginUserData.id) ?? false;
    final hasAccess = !_isLockedContent;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildActionButton(icon: FontAwesome.comment_o, count: widget.post.comments ?? 0, onPressed: hasAccess ? _showCommentsModal : null),
          _buildActionButton(icon: Icons.bar_chart, count: widget.post.totalInteractions ?? 0, color: Colors.blue, onPressed: hasAccess ? _navigateToDetails : null),
          _buildActionButton(icon: FontAwesome.heart_o, count: widget.post.loves ?? 0, color: isLiked ? const Color(0xFFF91880) : null, onPressed: hasAccess ? _handleLike : null),
          _buildFavoriteButton(hasAccess),
          _buildActionButton(icon: FontAwesome.gift, count: widget.post.totalGiftCoinsSentOnThisPost ?? 0, color: const Color(0xFFFFD600), onPressed: hasAccess ? _handleGift : null),
          _isSharing
              ? const SizedBox(width: 40, height: 40, child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)))
              : _buildActionButton(icon: Icons.share, count: widget.post.partage ?? 0, onPressed: hasAccess ? _handleShare : null),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required int count, Color? color, VoidCallback? onPressed}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            children: [
              Icon(icon, size: 18, color: onPressed != null ? (color ?? const Color(0xFF71767B)) : const Color(0xFF71767B).withOpacity(0.3)),
              const SizedBox(width: 6),
              Text(_formatCount(count), style: TextStyle(color: onPressed != null ? (color ?? const Color(0xFF71767B)) : const Color(0xFF71767B).withOpacity(0.3), fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteButton(bool hasAccess) {
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
                  color: hasAccess ? (_isFavorite ? const Color(0xFFFFD600) : const Color(0xFF71767B)) : const Color(0xFF71767B).withOpacity(0.3)),
              const SizedBox(width: 6),
              Text(_formatCount(widget.post.favoritesCount ?? 0),
                  style: TextStyle(color: hasAccess ? (_isFavorite ? const Color(0xFFFFD600) : const Color(0xFF71767B)) : const Color(0xFF71767B).withOpacity(0.3), fontSize: 13)),
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
    } else if (state == AppLifecycleState.resumed && _isVisible && _isVideoInitialized && !_isLockedContent) {
      _playVideo();
    }
  }

  // 🔥 Nouvelle méthode : Mettre à jour le volume quand la préférence change
  void _updateVolume() {
    if (_chewieController != null) {
      final isMuted = _soundProvider.isMuted;
      _chewieController!.setVolume(isMuted ? 0.0 : 1.0);

      // 🔥 NOUVEAU : Si le son vient d'être activé ET que la vidéo est visible ET en pause -> jouer
      if (!isMuted && _isVisible && _chewieController != null && !_chewieController!.isPlaying) {
        print('🔊 Son activé pendant la visibilité : reprise de la vidéo');
        _playVideo();
      }
      // Si le son est coupé et que la vidéo joue, on la met en pause
      else if (isMuted && _chewieController!.isPlaying) {
        print('🔇 Son coupé pendant la visibilité : pause vidéo');
        _pauseVideo();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // S'abonner aux changements du provider
    _soundProvider.addListener(_updateVolume);
  }

  @override
  void dispose() {
    _visibilityTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    MediaPlaybackManager.unregisterMedia(widget.post.id ?? '');
    _videoController?.removeListener(() {});
    _disposeVideoControllers();

    // 🔥 Nettoyage : retirer l'écouteur
    _soundProvider.removeListener(_updateVolume);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final h = MediaQuery.of(context).size.height;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF000000),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF71767B).withOpacity(0.3), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVideoContent(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPostHeader(),
                const SizedBox(height: 8),
                _buildPostContent(),
                const SizedBox(height: 12),
                _buildPostActions(),
                PostGiftsList(
                  postId: widget.post.id!,
                  compactLevel: CompactLevel.light,
                  maxDisplayItems: 10,
                ),
                if (_shouldShowAd) ...[
                  const SizedBox(height: 12),
                  MrecAdWidget(
                    onAdLoaded: () => print('✅ Pub MREC affichée après le post ${widget.index}'),
                    showLessAdsButton: false,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}