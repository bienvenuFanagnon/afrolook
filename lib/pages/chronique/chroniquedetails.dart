// pages/chronique/chronique_detail_page.dart

import 'package:afrotok/services/read_meter.dart';
import 'package:afrotok/services/ads_engine_service.dart';
import '../../utils/media_cdn.dart';
import 'dart:async';
import '../../widgets/video_poster_image.dart';
import 'chronique_comments_sheet.dart';
import 'chronique_reply_sheet.dart';
import 'chronique_overlay_text.dart';
import 'chronique_text_view.dart';
import 'chronique_widgets.dart';
import '../../widgets/music/music_overlay.dart';
import '../pub/ad_actions.dart';
import '../../ads/ad_gate.dart';
import '../../ads/ad_banner.dart';
import '../../ads/admob_widgets.dart';
import 'package:afrotok/widgets/pseudo_tag.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/services/media_cache_service.dart';
import 'package:afrotok/services/ad_preload_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/chroniqueProvider.dart';
import '../component/showUserDetails.dart';
import '../user/detailsOtherUser.dart';
import 'chroniqueform.dart';// pages/chronique/chronique_detail_page.dart
// pages/chronique/chronique_detail_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/chroniqueProvider.dart';
import '../component/showUserDetails.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/chroniqueProvider.dart';
import '../component/showUserDetails.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/chroniqueProvider.dart';
import '../component/showUserDetails.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/chroniqueProvider.dart';
import '../component/showUserDetails.dart';

import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/chroniqueProvider.dart';
import '../component/showUserDetails.dart';
import 'chroniqueform.dart';
// pages/chronique/chronique_detail_page.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/chroniqueProvider.dart';
import '../../providers/sound_provider.dart';
import '../canaux/detailsCanal.dart';
import '../chat/group/group_info_page.dart';
import '../chat/group/group_chat_page.dart';
import '../component/showUserDetails.dart';
import '../postComments.dart';
import '../user/otherUser/otherUser.dart';
import '../userPosts/video_preload_manager.dart';
import 'chroniqueform.dart';
import '../../services/news/news_service.dart';
import '../../widgets/feed/sections/news_full_page.dart';
import 'package:audioplayers/audioplayers.dart';

/// Emplacement d'une actualité en page entière entre deux chroniques.
class _NewsSlot {
  const _NewsSlot(this.n);
  final int n;
}

/// Emplacement AdMob entre deux chroniques (grand format 300×250). [fallback] : pub Afrolook montrée si AdMob ne charge pas.
class _AdmobSlot {
  const _AdmobSlot(this.ordinal, this.fallback);
  final int ordinal;
  final Advertisement? fallback;
}

class ChroniqueDetailPage extends StatefulWidget {
  final String initialChroniqueId;
  /// Groupes pré-chargés par la section (évite un rechargement Firestore).
  /// Clé = userId, valeur = chroniques de cet utilisateur.
  final List<List<Chronique>>? allGroups;
  /// userId de l'utilisateur sur lequel on a cliqué — son groupe passe en 1er.
  final String? startUserId;

  const ChroniqueDetailPage({
    Key? key,
    required this.initialChroniqueId,
    this.allGroups,
    this.startUserId,
  }) : super(key: key);

  @override
  State<ChroniqueDetailPage> createState() => _ChroniqueDetailPageState();
}

class _ChroniqueDetailPageState extends State<ChroniqueDetailPage> with TickerProviderStateMixin, MusicSuspendMixin {
  late PageController _pageController;
  int _currentPage = 0;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  AudioPlayer? _audioPlayer;
  bool _isAudioPlaying = false;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;

  // ── Story auto-avance ──────────────────────────────────────────────────────
  Timer? _storyTimer;
  double _storyProgress = 0.0; // 0.0 → 1.0 pour la slide courante
  static const int _timerIntervalMs = 50; // résolution 50ms
  AudioPlayer? _musicPlayer; // musique de la chronique affichée
  bool _musicMuted = false;
  int _sheetOpen = 0; // panneaux ouverts (commentaires, réponse) : le minuteur attend
  bool _held = false; // geste sur un texte long : le minuteur attend
  Timer? _holdTimer;
  late final AnimationController _vinylController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
  UserData? _chroniqueOwner;
  late UserAuthProvider authProvider ;
  late ChroniqueProvider chroniqueProvider ;
  late AnimationController _heartAnimationController;
  late Animation<double> _heartScaleAnimation;
  late Animation<double> _heartOpacityAnimation;
  bool _showHeartAnimation = false;
  bool _hasLikedCurrent = false;

  DateTime? _lastTap;
  final int _doubleTapTimeout = 300;

  List<Chronique> _allChroniques = [];
  bool _isLoading = true;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  final int _batchSize = 5;
  bool _isLoadingMore = false;

  // Publicités injectées entre les chroniques
  List<Advertisement> _activeAds = [];
  List<Advertisement> _shuffledAds = [];
  final Map<String, String?> _adImageUrls = {};
  final Map<String, Post> _adPosts = {};

  // Lecteur vidéo pour les pubs vidéo
  VideoPlayerController? _adVideoController;
  bool _adVideoInitialized = false;
  bool _adVideoMuted = true;
  String? _currentAdId;

  Map<String, bool> _likesMap = {};
  Map<String, int> _likesCountMap = {};


  // Actualités en page entière entre les chroniques (après la 3e, puis toutes les 5, 3 au plus par ouverture), si elles sont activées et disponibles
  bool _newsOn = false;
  bool _showingNews = false;
  static const int _maxNewsPerSession = 3;

  Future<void> _initNews() async {
    try {
      final cfg = await NewsService.instance.loadConfig();
      if (!cfg.enabled || !cfg.feedEnabled) return;
      final items = await NewsService.instance.feedFor(authProvider.loginUserData.countryData?['countryCode']);
      if (items.isNotEmpty && mounted) setState(() => _newsOn = true);
    } catch (_) {}
  }

  // État pour la slide pub courante
  bool _isShowingAd = false;
  Advertisement? _currentDisplayAd;
  bool _adPostLiked = false;
  int _adPostLikesCount = 0;
  bool _adPostLiking = false;

  @override
  void initState() {
    super.initState();
 authProvider = Provider.of<UserAuthProvider>(context, listen: false);
     chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);
    _pageController = PageController();
    _initializeLikesData();
    _loadInitialChroniques();
    _loadActiveAds();
    _initNews();

    _heartAnimationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _heartScaleAnimation = Tween<double>(begin: 0.0, end: 1.5).animate(
      CurvedAnimation(parent: _heartAnimationController, curve: Curves.elasticOut),
    );

    _heartOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _heartAnimationController, curve: Interval(0.5, 1.0, curve: Curves.easeOut)),
    );

    _heartAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _showHeartAnimation = false);
        _heartAnimationController.reset();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 🔥 Recharger les likes à chaque fois qu'on revient sur la page
    _refreshLikesFromCurrentChronique();
  }

  void _refreshLikesFromCurrentChronique() {
    if (_allChroniques.isEmpty) return;

    final currentChronique = _allChroniques[_currentPage];
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);

    // 🔥 Vérifier directement dans la chronique locale si l'utilisateur a liké
    final hasLiked = currentChronique.likers.contains(authProvider.loginUserData.id);
    final likesCount = currentChronique.likeCount;

    setState(() {
      _hasLikedCurrent = hasLiked;
      if (currentChronique.id != null) {
        _likesMap[currentChronique.id!] = hasLiked;
        _likesCountMap[currentChronique.id!] = likesCount;
      }
    });

    printVm('🔄 Refresh likes - hasLiked: $hasLiked, likesCount: $likesCount, likers: ${currentChronique.likers}');
  }
  Future<void> _loadInitialChroniques() async {
    // Chemin rapide : données déjà chargées par la section (pas de requête Firestore)
    if (widget.allGroups != null) {
      _buildFromPreloadedGroups();
      return;
    }

    setState(() {
      _isLoading = true;
      _allChroniques.clear();
      _hasMore = true;
      _lastDocument = null;
    });

    try {
      final chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);
      final result = await chroniqueProvider.getActiveChroniquesBatch(
        limit: _batchSize,
        lastDocument: _lastDocument,
      );

      if (result.isNotEmpty) {
        DocumentSnapshot? newLastDocument;
        if (result.last.id != null) {
          newLastDocument = await FirebaseFirestore.instance
              .collection('chroniques')
              .doc(result.last.id)
              .getM('chroniquedetails.dart:289');
        }

        setState(() {
          _allChroniques = result;
          _lastDocument = newLastDocument;
          _hasMore = result.length == _batchSize;
        });

        _initializeLikesData();

        int initialIndex = _allChroniques.indexWhere((c) => c.id == widget.initialChroniqueId);
        if (initialIndex != -1 && initialIndex != 0) {
          _currentPage = initialIndex;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _pageController.jumpToPage(_chroniqueToVirtual(initialIndex)),
          );
        }

        if (_allChroniques.isNotEmpty) {
          _initializeCurrentMedia();
          _loadChroniqueOwner();
        }
      }
      setState(() => _isLoading = false);
    } catch (e) {
      printVm('Erreur chargement chroniques: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Construit la liste à plat depuis les groupes pré-chargés.
  /// Le groupe de [widget.startUserId] passe toujours en tête.
  void _buildFromPreloadedGroups() {
    final groups = List<List<Chronique>>.from(widget.allGroups!);

    // Remettre le groupe du user cliqué en premier
    List<Chronique>? startGroup;
    groups.removeWhere((g) {
      if (g.isNotEmpty && g.first.userId == widget.startUserId) {
        startGroup = g;
        return true;
      }
      return false;
    });
    if (startGroup != null) groups.insert(0, startGroup!);

    final flat = groups.expand((g) => g).toList();

    setState(() {
      _allChroniques = flat;
      _isLoading = false;
      _hasMore = false;
    });

    if (flat.isNotEmpty) {
      _initializeLikesData();
      _initializeCurrentMedia();
      _loadChroniqueOwner();
    }
  }
  Future<void> _loadMoreChroniques() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);
      final result = await chroniqueProvider.getActiveChroniquesBatch(
        limit: _batchSize,
        lastDocument: _lastDocument,
      );

      if (result.isNotEmpty) {
        DocumentSnapshot? newLastDocument;
        if (result.last.id != null) {
          newLastDocument = await FirebaseFirestore.instance
              .collection('chroniques')
              .doc(result.last.id)
              .getM('chroniquedetails.dart:368');
        }

        setState(() {
          _allChroniques.addAll(result);
          _lastDocument = newLastDocument;
          _hasMore = result.length == _batchSize;
        });
      } else {
        setState(() => _hasMore = false);
      }
    } catch (e) {
      printVm('Erreur chargement plus de chroniques: $e');
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  void _initializeLikesData() {
    // 🔥 Plus besoin d'appeler Firestore, on utilise les données déjà chargées

    for (var chronique in _allChroniques) {
      if (chronique.id != null) {
        // Utiliser les listes déjà présentes dans l'objet Chronique
        bool hasLiked = chronique.likers.contains(authProvider.loginUserData.id);
        int likesCount = chronique.likeCount;  // Directement depuis l'objet

        _likesMap[chronique.id!] = hasLiked;
        _likesCountMap[chronique.id!] = likesCount;
      }
    }

    if (_allChroniques.isNotEmpty && _allChroniques[_currentPage].id != null) {
      setState(() => _hasLikedCurrent = _likesMap[_allChroniques[_currentPage].id!] ?? false);
    }
  }

  void _loadChroniqueOwner() async {
    if (_allChroniques.isEmpty) return;
    final currentChronique = _allChroniques[_currentPage];
    // Un profil n'est lu qu'une fois par ouverture de l'application (la coche « vérifié » change rarement)
    final cached = _ownerCache[currentChronique.userId];
    if (cached != null) {
      if (mounted) setState(() => _chroniqueOwner = cached);
      return;
    }
    final userDoc = await FirebaseFirestore.instance.collection('Users').doc(currentChronique.userId).getM('chroniquedetails.dart:414');
    if (userDoc.exists && mounted) {
      final owner = UserData.fromJson(userDoc.data()!);
      _ownerCache[currentChronique.userId] = owner;
      setState(() => _chroniqueOwner = owner);
    }
  }

  static final Map<String, UserData> _ownerCache = {};

  void _initializeCurrentMedia() async {
    if (_allChroniques.isEmpty) return;
    final currentChronique = _allChroniques[_currentPage];

    // Réinitialiser le flag AVANT de disposer pour éviter que le widget tente
    // de rendre un VideoPlayer avec un controller déjà libéré.
    setState(() { _isVideoInitialized = false; _isAudioPlaying = false; });
    _videoController?.dispose();
    _videoController = null;
    await _audioPlayer?.stop();
    await _audioPlayer?.dispose();
    _audioPlayer = null;
    _audioPosition = Duration.zero;
    _audioDuration = Duration.zero;

    if (currentChronique.type == ChroniqueType.AUDIO && currentChronique.mediaUrl != null) {
      final player = AudioPlayer();
      _audioPlayer = player;
      player.onDurationChanged.listen((d) { if (mounted) setState(() => _audioDuration = d); });
      player.onPositionChanged.listen((p) {
        if (!mounted) return;
        final startMs = currentChronique.audioStartMs ?? 0;
        final endMs = currentChronique.audioEndMs ?? _audioDuration.inMilliseconds;
        if (endMs > 0 && p.inMilliseconds >= endMs) player.seek(Duration(milliseconds: startMs));
        setState(() => _audioPosition = p);
      });
      player.onPlayerStateChanged.listen((s) {
        if (mounted) setState(() => _isAudioPlaying = s == PlayerState.playing);
      });
      await player.setSourceUrl(currentChronique.mediaUrl!);
      final startMs = currentChronique.audioStartMs ?? 0;
      if (startMs > 0) await player.seek(Duration(milliseconds: startMs));
      await player.resume();
    }

    if (currentChronique.type == ChroniqueType.VIDEO && currentChronique.mediaUrl != null) {
      final ctrl = await MediaCacheService.videoController(currentChronique.mediaUrl!);
      if (!mounted) { ctrl.dispose(); return; }
      _videoController = ctrl;
      await _videoController!.initialize();
      if (!mounted) return;
      if (currentChronique.hasMusic) await _videoController!.setVolume(currentChronique.videoSoundKept ? 1.0 : 0.0);
      _videoController!.play();
      _videoController!.setLooping(true);
      setState(() => _isVideoInitialized = true);
    }

    unawaited(_startMusic(currentChronique));

    _markAsViewed(currentChronique);
    _updateCurrentLikeStatus(currentChronique);
    _startStoryTimer(currentChronique);
    _prefetchNext();
  }

  /// La chronique suivante est préparée pendant qu'on regarde celle-ci : vidéo en cache disque, image dans le cache d'images.
  void _prefetchNext() {
    final next = _currentPage + 1;
    if (next >= _allChroniques.length) return;
    final c = _allChroniques[next];
    final url = c.mediaUrl;
    if (url == null || url.isEmpty) return;
    if (c.type == ChroniqueType.VIDEO) {
      MediaCacheService.prefetchVideo(url);
      if ((c.posterUrl ?? '').isNotEmpty && mounted) {
        precacheImage(CachedNetworkImageProvider(MediaCdn.url(c.posterUrl)), context).catchError((_) {});
      }
    } else if (c.type == ChroniqueType.IMAGE && mounted) {
      precacheImage(CachedNetworkImageProvider(url), context).catchError((_) {});
    }
  }

  // ── Timer story ────────────────────────────────────────────────────────────

  /// Durée d'une pub = celle d'une chronique : 5 s pour une image / un bloc AdMob, durée de la vidéo (3 à 60 s) pour une vidéo.
  static const int _adImageMs = 5000;

  void _startAdTimer(int durationMs) {
    _stopStoryTimer();
    _storyProgress = 0.0;
    _runTimer(durationMs.clamp(3000, 60000));
  }

  void _startStoryTimer(Chronique chronique) {
    _stopStoryTimer();
    _storyProgress = 0.0;

    // Durée de la slide en millisecondes selon le type
    final int durationMs;
    switch (chronique.type) {
      case ChroniqueType.TEXT:
        durationMs = chroniqueTextDurationMs((chronique.textContent ?? '').length);
        break;
      case ChroniqueType.IMAGE:
        durationMs = 5000;
        break;
      case ChroniqueType.VIDEO:
        durationMs = (chronique.duration * 1000).clamp(3000, 60000);
        break;
      case ChroniqueType.AUDIO:
        final start = chronique.audioStartMs ?? 0;
        final end = chronique.audioEndMs ?? (chronique.duration * 1000);
        durationMs = (end - start).clamp(3000, 60000);
        break;
    }

    _runTimer(durationMs);
  }

  void _runTimer(int durationMs) {
    final steps = durationMs ~/ _timerIntervalMs;
    final increment = 1.0 / steps;

    _storyTimer = Timer.periodic(Duration(milliseconds: _timerIntervalMs), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_held || _sheetOpen > 0) return; // geste sur le texte, panneau ouvert : on attend
      setState(() => _storyProgress = (_storyProgress + increment).clamp(0.0, 1.0));
      if (_storyProgress >= 1.0) {
        t.cancel();
        _goToNextStory();
      }
    });
  }

  void _stopStoryTimer() {
    _storyTimer?.cancel();
    _storyTimer = null;
  }

  void _goToNextStory() {
    if (!mounted) return;
    final nextVirtual = _pageController.page!.round() + 1;
    if (nextVirtual < _displayItems.length) {
      _pageController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _markAsViewed(Chronique chronique) {
    if (!chronique.viewers.contains(authProvider.loginUserData.id!)) {
      chroniqueProvider.markAsViewed(chronique.id!, authProvider.loginUserData.id!);
    }
  }

  void _updateCurrentLikeStatus(Chronique chronique) {
    setState(() => _hasLikedCurrent = _likesMap[chronique.id!] ?? false);
  }

  void _handleDoubleTap() {
    final now = DateTime.now();
    if (_lastTap != null && now.difference(_lastTap!).inMilliseconds < _doubleTapTimeout) {
      if (!_hasLikedCurrent) {
        _likeCurrentChronique();
        _triggerHeartAnimation();
      }
    }
    _lastTap = now;
  }

  void _triggerHeartAnimation() {
    setState(() => _showHeartAnimation = true);
    _heartAnimationController.forward();
  }

  void _likeCurrentChronique() async {
    if (_allChroniques.isEmpty) return;

    final currentChronique = _allChroniques[_currentPage];
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);

    if (!_hasLikedCurrent && currentChronique.id != null) {

      // 🔥 1. METTRE À JOUR LOCALEMENT D'ABORD
      setState(() {
        // Mettre à jour la chronique dans _allChroniques
        final index = _currentPage;
        _allChroniques[index].likers.add(authProvider.loginUserData.id!);
        _allChroniques[index].likeCount += 1;

        // Mettre à jour les maps
        _likesMap[currentChronique.id!] = true;
        _likesCountMap[currentChronique.id!] = (_likesCountMap[currentChronique.id!] ?? 0) + 1;
        _hasLikedCurrent = true;
      });

      // 🔥 2. ENSUITE SYNC AVEC FIRESTORE (en arrière-plan)
      try {
        await chroniqueProvider.addLike(currentChronique.id!, authProvider.loginUserData.id!);

        // Points et notifications
        addPointsForAction(UserAction.like);
        addPointsForOtherUserAction(currentChronique.userId, UserAction.autre);

        await _sendNotification(
            authProvider,
            currentChronique,
            '❤️ a aimé votre chronique',
            'LIKE'
        );
      } catch (e) {
        // En cas d'erreur, on annule localement
        setState(() {
          _allChroniques[_currentPage].likers.remove(authProvider.loginUserData.id!);
          _allChroniques[_currentPage].likeCount -= 1;
          _likesMap[currentChronique.id!] = false;
          _likesCountMap[currentChronique.id!] = (_likesCountMap[currentChronique.id!] ?? 1) - 1;
          _hasLikedCurrent = false;
        });
        printVm('Erreur like: $e');
      }
    }
  }
  Future<void> _sendNotification(UserAuthProvider authProvider, Chronique chronique, String message, String type) async {
    final ownerDoc = await FirebaseFirestore.instance.collection('Users').doc(chronique.userId).getM('chroniquedetails.dart:639');
    if (ownerDoc.exists && ownerDoc.data()!['oneIgnalUserid'] != null) {
      await authProvider.sendNotification(
        appName: '@${authProvider.loginUserData.pseudo!}',
        userIds: [ownerDoc.data()!['oneIgnalUserid']],
        smallImage: authProvider.loginUserData.imageUrl!,
        send_user_id: authProvider.loginUserData.id!,
        recever_user_id: chronique.userId,
        message: message,
        type_notif: type,
        post_id: chronique.id!,
        post_type: 'CHRONIQUE',
        chat_id: '',
      );
    }
  }

  void _deleteChronique(Chronique chronique) async {
    final me = authProvider.loginUserData;
    final isMine = me.id == chronique.userId;
    if (!isMine && me.role != 'ADM') return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isMine ? 'Supprimer ma chronique ?' : 'Supprimer cette chronique ?'),
        content: Text(isMine
            ? 'Elle disparaîtra pour tout le monde, avec ses commentaires et sa musique.'
            : 'Suppression en tant qu\'administrateur : la chronique de @${chronique.userPseudo} disparaîtra pour tout le monde, avec ses commentaires.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await chroniqueProvider.deleteChronique(chronique.id!, chronique.mediaUrl ?? '', userId: chronique.userId, posterUrl: chronique.posterUrl, voiceUrl: chronique.musicKind == 'voice' ? chronique.musicUrl : null);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Suppression impossible. Réessayez.')));
      return;
    }
    if (!mounted) return;
    await _stopMusic();
    setState(() => _allChroniques.removeWhere((c) => c.id == chronique.id));
    if (_allChroniques.isEmpty) {
      Navigator.pop(context);
    } else {
      _currentPage = _currentPage.clamp(0, _allChroniques.length - 1);
      _initializeCurrentMedia();
    }
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              PhotoView(
                imageProvider: CachedNetworkImageProvider(imageUrl),
                backgroundDecoration: BoxDecoration(color: Colors.black),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 2,
              ),
              Positioned(
                top: 40,
                left: 16,
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullScreenVideo() {
    if (_videoController == null || !_isVideoInitialized) return;

    final oldController = _videoController;
    final isPlaying = _videoController!.value.isPlaying;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
              ),
              Positioned(
                top: 40,
                left: 16,
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      if (isPlaying && oldController != null) {
        oldController.play();
      }
    });
  }

  void _showUserProfile(String userId) async {
    final userDoc = await FirebaseFirestore.instance.collection('Users').doc(userId).getM('chroniquedetails.dart:759');
    if (userDoc.exists) {
      showUserDetailsModalDialog(UserData.fromJson(userDoc.data()!), MediaQuery.of(context).size.width, MediaQuery.of(context).size.height, context);
    }
  }

  // ============================================================
  // PUBS — chargement et injection entre chroniques
  // ============================================================

  // Charge les pubs depuis authProvider (déjà préchargé) ou Firestore en fallback
  Future<void> _loadActiveAds() async {
    try {
      final auth = Provider.of<UserAuthProvider>(context, listen: false);
      final providerAds = auth.advertisements;

      if (providerAds.isNotEmpty) {
        _loadAdsFromProvider(providerAds);
        return;
      }

      // Fallback Firestore si le provider n'a pas encore chargé
      final snap = await FirebaseFirestore.instance
          .collection('Advertisements')
          .where('status', isEqualTo: 'active')
          .limit(5)
          .getM('chroniquedetails.dart:785');

      final ads = <Advertisement>[];
      final futures = <Future<void>>[];

      for (final doc in snap.docs) {
        final ad = Advertisement.fromJson(doc.data());
        ad.id = doc.id;
        ads.add(ad);

        if (ad.postId != null) {
          futures.add(
            FirebaseFirestore.instance.collection('Posts').doc(ad.postId).getM('chroniquedetails.dart:797').then((postDoc) {
              if (!postDoc.exists) return;
              final post = Post.fromJson(postDoc.data()!);
              post.id = postDoc.id;
              _adPosts[ad.id!] = post;
              final images = post.images;
              final url = (images != null && images.isNotEmpty) ? images.first : post.url_media;
              if (url != null && url.isNotEmpty) _adImageUrls[ad.id!] = url;
              final isVideo = post.dataType == PostDataType.VIDEO.name ||
                  (post.url_media ?? '').contains('.mp4') ||
                  (post.url_media ?? '').contains('.mov');
              if (isVideo && post.url_media != null) {
                VideoPreloadManager.preload(post.id ?? ad.id!, post.url_media);
              }
            }).catchError((_) {}),
          );
        }
      }

      await Future.wait(futures);
      if (mounted && ads.isNotEmpty) _applyAds(ads);
    } catch (_) {}
  }

  void _loadAdsFromProvider(List<Map<String, dynamic>> providerAds) {
    final ads = <Advertisement>[];
    for (final adData in providerAds) {
      final adMap = adData['ad'] as Map<String, dynamic>?;
      if (adMap == null) continue;
      final ad = Advertisement.fromJson(adMap);
      if (ad.id == null) continue;
      ads.add(ad);

      if (adData['isEntityBoost'] == true) continue;

      final postMap = adData['post'] as Map<String, dynamic>?;
      if (postMap != null) {
        final post = Post.fromJson(postMap);
        _adPosts[ad.id!] = post;
        final images = post.images;
        final url = (images != null && images.isNotEmpty) ? images.first : post.url_media;
        if (url != null && url.isNotEmpty) _adImageUrls[ad.id!] = url;
        final isVideo = post.dataType == PostDataType.VIDEO.name ||
            (post.url_media ?? '').contains('.mp4') ||
            (post.url_media ?? '').contains('.mov');
        if (isVideo && post.url_media != null) {
          VideoPreloadManager.preload(post.id ?? ad.id!, post.url_media);
        }
      }
    }
    if (mounted && ads.isNotEmpty) _applyAds(ads);
  }

  void _applyAds(List<Advertisement> ads) {
    ads.shuffle();
    final currentChroniqueIdx = _currentPage;
    setState(() {
      _activeAds = ads;
      _shuffledAds = List.from(ads);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageController.hasClients) {
        final newVirtual = _chroniqueToVirtual(currentChroniqueIdx);
        _pageController.jumpToPage(newVirtual);
      }
    });
  }

  Future<void> _navigateToEntityOwner(Advertisement ad) async {
    final id = ad.ownerId;
    if (id == null || id.isEmpty || !mounted) return;
    try {
      final fs = FirebaseFirestore.instance;
      switch (ad.ownerType) {
        case 'canal':
          final doc = await fs.collection('Canaux').doc(id).getM('chroniquedetails.dart:872');
          if (!doc.exists || !context.mounted) return;
          final data = Map<String, dynamic>.from(doc.data()!)..['id'] = doc.id;
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => CanalDetails(canal: Canal.fromJson(data)),
          ));
          break;
        case 'group':
          if (!context.mounted) return;
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => GroupChatPage(
              groupId: id,
              groupName: ad.ownerName ?? 'Groupe',
              groupImageUrl: ad.ownerAvatar ?? '',
            ),
          ));
          break;
        default:
          final doc = await fs.collection('Users').doc(id).getM('chroniquedetails.dart:890');
          if (!doc.exists || !context.mounted) return;
          final data = Map<String, dynamic>.from(doc.data()!)..['id'] = doc.id;
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => OtherUserPage(otherUser: UserData.fromJson(data)),
          ));
      }
    } catch (_) {}
  }

  Future<void> _initializeAdVideo(Advertisement ad) async {
    final post = _adPosts[ad.id ?? ''];
    if (post == null) return;

    final isVideo = post.dataType == PostDataType.VIDEO.name ||
        (post.url_media ?? '').contains('.mp4') ||
        (post.url_media ?? '').contains('.mov');
    if (!isVideo || post.url_media == null) return;
    if (_currentAdId == ad.id && _adVideoController != null) {
      _adVideoController?.play();
      return;
    }

    _adVideoController?.pause();
    _adVideoController?.dispose();
    _adVideoController = null;
    _adVideoInitialized = false;
    _currentAdId = ad.id;

    final soundProvider = Provider.of<SoundProvider>(context, listen: false);

    // Réutiliser le contrôleur préchargé si disponible
    final preloaded = VideoPreloadManager.claimController(post.id ?? '') ??
        (ad.id != null ? AdPreloadService.instance.claimController(ad.id!) : null);
    if (preloaded != null && preloaded.value.isInitialized) {
      preloaded.setVolume(_adVideoMuted ? 0.0 : (soundProvider.isMuted ? 0.0 : 1.0));
      preloaded.setLooping(true);
      preloaded.play();
      if (mounted) setState(() { _adVideoController = preloaded; _adVideoInitialized = true; });
      _syncAdTimerWithVideo(ad);
    } else {
      final url = VideoPreloadManager.urlResolver != null
          ? VideoPreloadManager.urlResolver!(post.url_media!)
          : post.url_media!;
      try {
        final controller = await MediaCacheService.adVideoController(post.url_media!, networkUrl: url);
        await controller.initialize();
        if (!mounted || _currentAdId != ad.id) {
          controller.dispose();
          return;
        }
        controller.setVolume(_adVideoMuted ? 0.0 : (soundProvider.isMuted ? 0.0 : 1.0));
        controller.setLooping(true);
        controller.play();
        setState(() { _adVideoController = controller; _adVideoInitialized = true; });
        _syncAdTimerWithVideo(ad);
      } catch (_) {}
    }
  }

  /// Une pub vidéo dure comme sa vidéo (3 à 60 s, comme une chronique vidéo).
  void _syncAdTimerWithVideo(Advertisement ad) {
    final c = _adVideoController;
    if (!mounted || c == null || _currentAdId != ad.id || !_isShowingAd) return;
    final ms = c.value.duration.inMilliseconds;
    if (ms > 0) _startAdTimer(ms);
  }

  void _stopAdVideo() {
    _adVideoController?.pause();
    _adVideoInitialized = false;
    _currentAdId = null;
  }

  Future<void> _recordAdView(Advertisement ad) async {
    if (ad.id == null) return;
    AdsEngineService.instance.view(ad.id!, format: 'native', slot: 'chronique');
  }

  Future<void> _recordAdClick(Advertisement ad) async {
    if (ad.id == null) return;
    AdsEngineService.instance.click(ad.id!, format: 'native', slot: 'chronique');
  }

  /// Liste mixte Chronique + pub pour le PageView.
  ///
  /// Rythme : jamais deux pubs d'affilée et jamais trop de pubs. Une pub après la 2e chronique regardée, puis une toutes les 4 chroniques
  /// (après la 2e, la 6e, la 10e, la 14e…), 4 au plus par ouverture. S'il n'y a qu'une chronique, la pub passe après elle (une seule).
  /// Cas : 1 chronique → [c, pub] ; 2 → [c, c, pub] ; 3 → [c, c, pub, c] ; 5 → [c, c, pub, c, c] ; 7 → [c, c, pub, c, c, c, pub, c] ;
  /// 10 → 3 pubs (après la 2e, la 6e et la 10e).
  ///
  /// À chaque emplacement le réseau d'abord (Appodeal / AdMob) si le compte peut en voir ; sinon la pub Afrolook suivante (sans cycle).
  /// Si le bloc du réseau ne charge pas, la slide montre une pub Afrolook de repli, ou passe toute seule à la suite.
  static const int _maxAdsPerSession = 4;

  List<dynamic> get _displayItems {
    final ads = _shuffledAds.isNotEmpty ? _shuffledAds : _activeAds;
    final user = authProvider.loginUserData;
    final admob = AdGate.canShowType(user, 'banner');
    if (ads.isEmpty && !admob && !_newsOn) return _allChroniques;
    final result = <dynamic>[];
    final n = _allChroniques.length;
    int adCursor = 0;
    int slotOrdinal = 0;
    int newsOrdinal = 0;
    for (int i = 0; i < n; i++) {
      result.add(_allChroniques[i]);
      final seen = i + 1; // chroniques regardées jusqu'ici
      final isAdSlot = n == 1 || seen == 2 || (seen > 2 && (seen - 2) % 4 == 0);
      if (isAdSlot && slotOrdinal + adCursor < _maxAdsPerSession) {
        if (admob) {
          result.add(_AdmobSlot(slotOrdinal, ads.isEmpty ? null : ads[slotOrdinal % ads.length]));
          slotOrdinal++;
        } else if (adCursor < ads.length) {
          result.add(ads[adCursor++]);
        }
      }
      // actualité en page entière : après la 3e chronique, puis toutes les 5 (jamais en dernière page)
      if (_newsOn && newsOrdinal < _maxNewsPerSession && seen >= 3 && (seen - 3) % 5 == 0 && i != n - 1) {
        result.add(_NewsSlot(newsOrdinal));
        newsOrdinal++;
      }
    }
    return result;
  }

  int _virtualToChronique(int virtualIndex) {
    int count = 0;
    for (int i = 0; i < virtualIndex && i < _displayItems.length; i++) {
      if (_displayItems[i] is Chronique) count++;
    }
    return count;
  }

  bool _isVirtualAd(int virtualIndex) {
    if (virtualIndex < 0 || virtualIndex >= _displayItems.length) return false;
    final it = _displayItems[virtualIndex];
    return it is Advertisement || it is _AdmobSlot || it is _NewsSlot; // _NewsSlot : page entière d'actualité, traitée comme une pause entre chroniques
  }

  /// Slides AdMob dont le chargement a échoué (par ordinal) : elles montrent la pub de repli ou sont sautées.
  final Set<int> _admobFailed = {};

  Widget _buildAdmobSlide(_AdmobSlot slot) {
    if (_admobFailed.contains(slot.ordinal)) {
      if (slot.fallback != null) return _buildAdSlide(slot.fallback!);
      return const ColoredBox(color: Colors.black);
    }
    return Container(
      color: Colors.black,
      child: Stack(fit: StackFit.expand, children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF14110A), Color(0xFF000000)]),
          ),
        ),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(99)),
              child: const Text('Publicité', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .8)),
            ),
            const SizedBox(height: 10),
            AdBanner(
              key: ValueKey('chronique_admob_${slot.ordinal}'),
              mrec: true,
              onFailed: () {
                if (!mounted || _admobFailed.contains(slot.ordinal)) return;
                setState(() => _admobFailed.add(slot.ordinal));
                // Pas de pub de repli : on passe à la chronique suivante tout de suite ; sinon la pub Afrolook dure comme une pub normale
                if (slot.fallback == null) {
                  _goToNextStory();
                } else {
                  _startAdTimer(_adImageMs);
                }
              },
            ),
          ]),
        ),
      ]),
    );
  }

  int _chroniqueToVirtual(int chroniqueIndex) {
    int count = 0;
    for (int i = 0; i < _displayItems.length; i++) {
      if (_displayItems[i] is Chronique) {
        if (count == chroniqueIndex) return i;
        count++;
      }
    }
    return chroniqueIndex;
  }

  Widget _buildEntityBoostSlide(Advertisement ad) {
    final typeLabel = ad.ownerType == 'canal' ? 'Canal' : ad.ownerType == 'group' ? 'Groupe' : 'Créateur';
    final ctaLabel = ad.ownerType == 'canal' ? "S'abonner" : ad.ownerType == 'group' ? 'Rejoindre' : 'Suivre';
    final adDescription = ad.description ?? '';
    return Stack(
      fit: StackFit.expand,
      children: [
        // Fond dégradé
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFF1a0a00), Color(0xFF3a1800)],
            ),
          ),
        ),
        // Motif décoratif
        Positioned.fill(
          child: Opacity(
            opacity: 0.07,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
              itemBuilder: (_, __) => const Icon(Icons.circle, size: 4, color: Color(0xFFFFD700)),
            ),
          ),
        ),
        // Carte centrale
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3), width: 1),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified, size: 11, color: Colors.black),
                        const SizedBox(width: 4),
                        Text('SPONSORISÉ • $typeLabel',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Avatar
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: const Border.fromBorderSide(BorderSide(color: Color(0xFFFFD700), width: 3)),
                    ),
                    child: ClipOval(
                      child: ad.ownerAvatar?.isNotEmpty == true
                          ? CachedNetworkImage(imageUrl: ad.ownerAvatar!, fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(color: const Color(0xFF3a1800),
                                child: const Icon(Icons.person, color: Color(0xFFFFD700), size: 36)))
                          : Container(color: const Color(0xFF3a1800),
                              child: const Icon(Icons.person, color: Color(0xFFFFD700), size: 36)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Nom
                  Text(ad.ownerName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  if (adDescription.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(adDescription, maxLines: 3, overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.45)),
                  ],
                  const SizedBox(height: 20),
                  // CTA
                  GestureDetector(
                    onTap: () async {
                      _recordAdClick(ad);
                      await _navigateToEntityOwner(ad);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [BoxShadow(color: const Color(0xFFFFD700).withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: Text(ctaLabel, textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdSlide(Advertisement ad) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _recordAdView(ad));

    // ── Boost entité (profil / canal / groupe) — format carte centré ──
    if (ad.ownerType != null && ad.ownerType!.isNotEmpty && ad.postId == null) {
      return _buildEntityBoostSlide(ad);
    }

    final post = _adPosts[ad.id ?? ''];
    final imageUrl = _adImageUrls[ad.id ?? ''];
    final isVideoAd = post != null && (
        post.dataType == PostDataType.VIDEO.name ||
        (post.url_media ?? '').contains('.mp4') ||
        (post.url_media ?? '').contains('.mov'));

    final actionBottomOffset = 120.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Fond (vidéo ou image) ──
        if (isVideoAd && _adVideoInitialized && _adVideoController != null) ...[
          // Fond flouté (cover) pour remplir les bandes noires
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _adVideoController!.value.size.width,
              height: _adVideoController!.value.size.height,
              child: VideoPlayer(_adVideoController!),
            ),
          ),
          // Filtre assombri
          Positioned.fill(child: ColoredBox(color: Colors.black.withOpacity(0.35))),
          // Vidéo principale (contain) au centre
          Center(
            child: AspectRatio(
              aspectRatio: _adVideoController!.value.aspectRatio,
              child: VideoPlayer(_adVideoController!),
            ),
          ),
        ] else if (isVideoAd && !_adVideoInitialized) ...[
          // Placeholder pendant le chargement vidéo
          Container(color: Colors.black),
          if (imageUrl != null)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                color: Colors.black.withOpacity(0.5),
                colorBlendMode: BlendMode.darken,
                placeholder: (_, __) => const SizedBox.shrink(),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          const Center(child: CircularProgressIndicator(color: Color(0xFFFFD700), strokeWidth: 2)),
        ] else ...[
          // Pub image : fond flouté + image contain
          if (imageUrl != null)
            CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.55),
              colorBlendMode: BlendMode.darken,
              placeholder: (_, __) => Container(color: Colors.black),
              errorWidget: (_, __, ___) => Container(color: Colors.black),
            )
          else
            Container(color: Colors.black87),
          if (imageUrl != null)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) => const SizedBox.shrink(),
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
        ],

        // ── Dégradés haut / bas ──
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.5),
                  Colors.transparent,
                  Colors.black.withOpacity(0.75),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),

        // ── Badge SPONSORISÉ ──
        Positioned(
          top: MediaQuery.of(context).padding.top + 56,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD600),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified, color: Colors.black, size: 13),
                SizedBox(width: 4),
                Text('SPONSORISÉ', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),

        // ── Bouton son (vidéo uniquement) ──
        if (isVideoAd)
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
            right: 16,
            child: GestureDetector(
              onTap: () {
                setState(() => _adVideoMuted = !_adVideoMuted);
                final vol = _adVideoMuted ? 0.0 : 1.0;
                _adVideoController?.setVolume(vol);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _adVideoMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),

        // ── Bouton d'action CTA ──
        if (ad.actionType != null || ad.actionButtonText != null)
          Positioned(
            bottom: actionBottomOffset,
            left: 16,
            right: 16,
            child: GestureDetector(
              onTap: () async {
                _recordAdClick(ad);
                await AdActions.open(ad);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE21221), Color(0xFFFF5252)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      ad.actionType == 'download' ? Icons.download
                          : ad.actionType == 'visit' ? Icons.language
                          : Icons.info_outline,
                      color: Colors.white,
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ad.getActionButtonText(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 12),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _handleAdPostLike() async {
    if (_adPostLiking) return;
    final adPost = _currentDisplayAd != null ? _adPosts[_currentDisplayAd!.id ?? ''] : null;
    if (adPost == null || adPost.id == null) return;
    final uid = Provider.of<UserAuthProvider>(context, listen: false).loginUserData.id;
    if (uid == null) return;

    setState(() {
      _adPostLiking = true;
      _adPostLiked = !_adPostLiked;
      _adPostLikesCount += _adPostLiked ? 1 : -1;
    });

    try {
      await FirebaseFirestore.instance.collection('Posts').doc(adPost.id).update({
        'loves': FieldValue.increment(_adPostLiked ? 1 : -1),
        'users_love_id': _adPostLiked
            ? FieldValue.arrayUnion([uid])
            : FieldValue.arrayRemove([uid]),
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _adPostLiked = !_adPostLiked;
          _adPostLikesCount += _adPostLiked ? 1 : -1;
        });
      }
    } finally {
      if (mounted) setState(() => _adPostLiking = false);
    }
  }

  String _formatStatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  Widget _buildAdActionsOverlay(Advertisement ad) {
    final isEntityBoost = ad.ownerType != null && ad.ownerType!.isNotEmpty && ad.postId == null;
    final adPost = isEntityBoost ? null : _adPosts[ad.id ?? ''];
    final commentCount = adPost?.comments ?? 0;

    return Positioned(
      right: 12,
      bottom: 120,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Like + commentaire uniquement pour les pubs post (pas les boosts entité)
          if (!isEntityBoost) ...[
            GestureDetector(
              onTap: _handleAdPostLike,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _adPostLiked ? Icons.favorite : Icons.favorite_border,
                    color: _adPostLiked ? Colors.red : Colors.white,
                    size: 30,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatStatCount(_adPostLikesCount),
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: adPost != null
                  ? () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PostComments(post: adPost)))
                  : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 28),
                  const SizedBox(height: 3),
                  Text(
                    _formatStatCount(commentCount),
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          // Vues pub (toujours visible)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.remove_red_eye, color: Colors.white70, size: 24),
              const SizedBox(height: 3),
              Text(
                _formatStatCount(ad.views ?? 0),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
          // Clics pub — admin uniquement
          if (authProvider.loginUserData.role == 'ADM' && (ad.clicks ?? 0) > 0) ...[
            const SizedBox(height: 12),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.touch_app_outlined, color: Colors.white54, size: 22),
                const SizedBox(height: 3),
                Text(
                  _formatStatCount(ad.clicks ?? 0),
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFFFFD700)),
              SizedBox(height: 16),
              Text('Chargement des chroniques...', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }

    if (_allChroniques.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_toggle_off, color: Color(0xFFFFD700), size: 80),
              SizedBox(height: 20),
              Text('Aucune chronique disponible', style: TextStyle(color: Colors.white, fontSize: 18)),
              SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AddChroniquePage())),
                icon: Icon(Icons.add, color: Colors.black),
                label: Text('Créer une chronique'),
                style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFFD700), foregroundColor: Colors.black),
              ),
            ],
          ),
        ),
      );
    }

    final currentChronique = _allChroniques[_currentPage.clamp(0, _allChroniques.length - 1)];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _displayItems.length,
              onPageChanged: (virtualIndex) {
                if (_isVirtualAd(virtualIndex)) {
                  // Page pub : on ne touche pas à _currentPage (garder le dernier index chronique valide)
                  _videoController?.pause();
                  _audioPlayer?.pause();
                  unawaited(_stopMusic());
                  final item = _displayItems[virtualIndex];
                  // La pub avance toute seule, comme une chronique (5 s ; une vidéo : sa durée, voir _initializeAdVideo)
                  _startAdTimer(item is _NewsSlot ? 9000 : _adImageMs); // une actualité reste plus longtemps (temps de lire)
                  if (item is _NewsSlot) {
                    _stopAdVideo();
                    setState(() {
                      _isShowingAd = true;
                      _showingNews = true;
                      _currentDisplayAd = null;
                    });
                  } else if (item is _AdmobSlot) {
                    _stopAdVideo();
                    setState(() {
                      _isShowingAd = true;
                      _showingNews = false;
                      _currentDisplayAd = null;
                    });
                  } else if (item is Advertisement) {
                    _initializeAdVideo(item);
                    final adPost = _adPosts[item.id ?? ''];
                    final uid = Provider.of<UserAuthProvider>(context, listen: false).loginUserData.id;
                    setState(() {
                      _isShowingAd = true;
                      _showingNews = false;
                      _currentDisplayAd = item;
                      _adPostLiked = adPost?.users_love_id?.contains(uid) ?? false;
                      _adPostLikesCount = adPost?.loves ?? 0;
                    });
                  }
                } else {
                  final chroniqueIdx = _virtualToChronique(virtualIndex);
                  // Sécurité : ne jamais dépasser les bornes de _allChroniques
                  if (chroniqueIdx < _allChroniques.length) {
                    setState(() {
                      _currentPage = chroniqueIdx;
                      _isShowingAd = false;
                      _showingNews = false;
                      _currentDisplayAd = null;
                    });
                  }
                  _stopAdVideo();
                  _initializeCurrentMedia();
                  _loadChroniqueOwner();
                }
                if (_currentPage >= _allChroniques.length - 2 && _hasMore && !_isLoadingMore) {
                  _loadMoreChroniques();
                }
              },
              itemBuilder: (context, index) {
                final item = _displayItems[index];
                if (item is _NewsSlot) {
                  return NewsFullPage(
                    key: ValueKey('chronique_news_${item.n}'),
                    slotKey: 'chronique_${item.n}',
                    onEmpty: _goToNextStory, // aucun article disponible : on passe tout de suite à la suite
                    onOpenStart: () => _sheetOpen++, // le minuteur attend pendant la lecture de l'article ou d'un panneau
                    onOpenEnd: () {
                      if (_sheetOpen > 0) _sheetOpen--;
                    },
                  );
                }
                if (item is _AdmobSlot) {
                  return _buildAdmobSlide(item);
                }
                if (item is Advertisement) {
                  return _buildAdSlide(item);
                }
                final chronique = item as Chronique;
                return GestureDetector(
                  onTap: () {
                    if (chronique.type == ChroniqueType.IMAGE) {
                      _showFullScreenImage(chronique.mediaUrl!);
                    } else if (chronique.type == ChroniqueType.VIDEO && _isVideoInitialized) {
                      _showFullScreenVideo();
                    } else {
                      _handleDoubleTap();
                    }
                  },
                  child: _buildChroniqueContent(chronique),
                );
              },
            ),
            _buildHeader(currentChronique),
            _buildProgressIndicator(),
            if (_isShowingAd) _buildAdProgress(),
            if (!_isShowingAd) ...[
              _buildStatsPill(currentChronique),
              _buildMusicPill(currentChronique),
              _buildBottomRow(currentChronique),
              _buildHeartAnimation(),
            ] else if (_currentDisplayAd != null)
              _buildAdActionsOverlay(_currentDisplayAd!),
            if (_isLoadingMore)
              Positioned(
                bottom: 100,
                left: 0,
                right: 0,
                child: Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
              ),
          ],
        ),
      ),
    );
  }

  /// Pendant une pub : fine barre dorée « Publicité » qui se remplit pendant la durée de la pub.
  Widget _buildAdProgress() {
    return Positioned(
      top: 18,
      left: 12,
      right: 12,
      child: Row(children: [
        Text(_showingNews ? 'Actualité' : 'Publicité', style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: _storyProgress,
              minHeight: 2.5,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildProgressIndicator() {
    if (_allChroniques.isEmpty) return const SizedBox();
    // Limite le nombre de segments affichés (évite une barre illisible)
    const int maxSegments = 15;
    final total = _allChroniques.length.clamp(1, maxSegments);
    final page = _currentPage.clamp(0, total - 1);

    return Positioned(
      top: 8,
      left: 10,
      right: 10,
      child: Row(
        children: List.generate(total, (i) {
          double fillValue;
          if (i < page || (_isShowingAd && i == page)) {
            fillValue = 1.0; // passé — plein (pendant une pub, la chronique d'avant est terminée)
          } else if (i == page) {
            fillValue = _storyProgress; // courant — animé
          } else {
            fillValue = 0.0; // futur — vide
          }
          return Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                widthFactor: fillValue,
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Nouveau décor du lecteur : en-tête, pastille de chiffres, rangée du bas, musique ─────────────

  String _ago(Timestamp t) {
    final d = DateTime.now().difference(t.toDate());
    if (d.inMinutes < 1) return 'à l\'instant';
    if (d.inMinutes < 60) return 'il y a ${d.inMinutes} min';
    if (d.inHours < 24) return 'il y a ${d.inHours} h';
    return 'il y a ${d.inDays} j';
  }

  Widget _glassIcon(IconData icon, VoidCallback onTap, {String? tip}) {
    return Tooltip(
      message: tip ?? '',
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: .4), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Widget _buildHeader(Chronique chronique) {
    final me = authProvider.loginUserData;
    final isMine = me.id == chronique.userId;
    final isAdmin = me.role == 'ADM';
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 22, 10, 26),
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: .7), Colors.transparent])),
        child: Row(children: [
          if (!_isShowingAd)
            Expanded(
              child: GestureDetector(
                onTap: () => _showUserProfile(chronique.userId),
                behavior: HitTestBehavior.opaque,
                child: Row(children: [
                  Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                    child: ChroniqueAvatar(imageUrl: chronique.userImageUrl, name: chronique.userPseudo, size: 34),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Flexible(child: PseudoTag(label: isMine ? 'Moi · @${chronique.userPseudo}' : '@${chronique.userPseudo}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        if (_chroniqueOwner?.isVerify == true) ...[const SizedBox(width: 4), const Icon(Icons.verified, color: Color(0xFF2D8CFF), size: 14)],
                      ]),
                      Text(_ago(chronique.createdAt), style: TextStyle(color: Colors.white.withValues(alpha: .8), fontSize: 10.5)),
                    ]),
                  ),
                ]),
              ),
            )
          else
            const Spacer(),
          if (!_isShowingAd && chronique.hasMusic && chronique.type != ChroniqueType.AUDIO) ...[
            _glassIcon(_musicMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded, _toggleMusicMute, tip: _musicMuted ? 'Activer le son' : 'Couper la musique'),
            const SizedBox(width: 8),
          ],
          if (!_isShowingAd) ...[
            _menu(chronique, isMine, isAdmin),
            const SizedBox(width: 8),
          ],
          _glassIcon(Icons.close_rounded, () => Navigator.pop(context), tip: 'Fermer'),
        ]),
      ),
    );
  }

  /// Menu « ⋯ » : ajouter une chronique, commentaires, réponse privée, profil, suppression (créateur ou administrateur).
  Widget _menu(Chronique c, bool isMine, bool isAdmin) {
    PopupMenuItem<String> item(String v, IconData icon, String label, {String? sub, bool danger = false}) => PopupMenuItem<String>(
          value: v,
          child: Row(children: [
            Icon(icon, size: 18, color: danger ? const Color(0xFFFF5C5C) : Colors.white70),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(label, style: TextStyle(color: danger ? const Color(0xFFFF5C5C) : Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5)),
                if (sub != null) Text(sub, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ]),
            ),
          ]),
        );
    return PopupMenuButton<String>(
      tooltip: 'Plus',
      color: const Color(0xFF1B1B1B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      offset: const Offset(0, 44),
      onSelected: (v) {
        switch (v) {
          case 'add':
            Navigator.push(context, MaterialPageRoute(builder: (_) => AddChroniquePage()));
            break;
          case 'comments':
            _openComments(c);
            break;
          case 'reply':
            _openReply(c);
            break;
          case 'profile':
            _showUserProfile(c.userId);
            break;
          case 'delete':
            _deleteChronique(c);
            break;
        }
      },
      itemBuilder: (_) => [
        item('add', Icons.add_rounded, 'Ajouter une chronique'),
        item('comments', Icons.chat_bubble_outline_rounded, 'Voir les commentaires', sub: '${c.commentCount} commentaire${c.commentCount > 1 ? 's' : ''}'),
        if (!isMine) item('reply', Icons.mail_outline_rounded, 'Répondre en privé'),
        if (!isMine) item('profile', Icons.person_outline_rounded, 'Voir le profil'),
        if (isMine || isAdmin) item('delete', Icons.delete_outline_rounded, isMine ? 'Supprimer ma chronique' : 'Supprimer (administrateur)', sub: 'Média, musique et commentaires retirés', danger: true),
      ],
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: .4), shape: BoxShape.circle),
        child: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 20),
      ),
    );
  }

  /// Pastille de chiffres : vues, j'aime, temps restant.
  Widget _buildStatsPill(Chronique c) {
    Widget stat(IconData i, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(i, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(t, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ]);
    return Positioned(
      top: 84,
      left: 14,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: .42), borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          stat(Icons.remove_red_eye_rounded, chroniqueCount(c.viewCount)),
          const SizedBox(width: 12),
          stat(Icons.favorite_rounded, chroniqueCount(c.likeCount)),
          const SizedBox(width: 12),
          stat(Icons.hourglass_bottom_rounded, _getTimeLeft(c.expiresAt)),
        ]),
      ),
    );
  }

  Widget _buildMusicPill(Chronique c) {
    if (!c.hasMusic || c.type == ChroniqueType.AUDIO) return const SizedBox.shrink();
    final isMine = authProvider.loginUserData.id == c.userId;
    return Positioned(
      left: 14,
      right: 14,
      bottom: isMine ? 92 : 76,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: .5), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          RotationTransition(
            turns: _vinylController,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color(0xFF111111), Color(0xFF111111), kRingGreen, kRingGreen, Color(0xFF111111)], stops: [0, .18, .19, .3, .31])),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(c.musicTitle ?? 'Musique', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5)),
              Text('${c.musicArtist ?? ''} · extrait ${((c.musicEndMs ?? 0) - (c.musicStartMs ?? 0)) ~/ 1000} s', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
            ]),
          ),
          GestureDetector(
            onTap: _toggleMusicMute,
            child: Icon(_musicMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white, size: 20),
          ),
        ]),
      ),
    );
  }

  Widget _buildBottomRow(Chronique c) {
    final isMine = authProvider.loginUserData.id == c.userId;
    if (isMine) {
      Widget tile(String n, String label, {VoidCallback? onTap}) => Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: .2))),
                child: Column(children: [
                  Text(n, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                  Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: .5)),
                ]),
              ),
            ),
          );
      return Positioned(
        left: 14,
        right: 14,
        bottom: 18,
        child: Row(children: [
          tile(chroniqueCount(c.viewCount), 'VUES'),
          const SizedBox(width: 8),
          tile(chroniqueCount(c.likeCount), 'J\'AIME'),
          const SizedBox(width: 8),
          tile(chroniqueCount(c.commentCount), 'COMMENTAIRES', onTap: () => _openComments(c)),
        ]),
      );
    }
    final liked = _hasLikedCurrent;
    return Positioned(
      left: 14,
      right: 14,
      bottom: 18,
      child: Row(children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _openComments(c),
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(99), border: Border.all(color: Colors.white.withValues(alpha: .22))),
              child: Row(children: [
                const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 17),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Ajouter un commentaire', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    if ((c.lastCommentText ?? '').isNotEmpty)
                      Text('@${c.lastCommentPseudo ?? ''} : ${c.lastCommentText}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                  ]),
                ),
                if (c.commentCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(99)),
                    child: Text(chroniqueCount(c.commentCount), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _roundAction(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, _likeCurrentChronique, color: liked ? const Color(0xFFFF4D6A) : Colors.white, badge: chroniqueCount(c.likeCount)),
        const SizedBox(width: 8),
        _roundAction(Icons.mail_outline_rounded, () => _openReply(c)),
      ]),
    );
  }

  Widget _roundAction(IconData icon, VoidCallback onTap, {Color color = Colors.white, String? badge}) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: .22))),
            child: Icon(icon, color: color, size: 20),
          ),
          if (badge != null)
            Positioned(
              right: -4,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)),
                child: Text(badge, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF111111), fontSize: 9.5, fontWeight: FontWeight.w800)),
              ),
            ),
        ]),
      ),
    );
  }

  // ── Panneaux (commentaires, réponse privée) : la chronique se met en pause pendant qu'ils sont ouverts ──

  Future<void> _holdWhile(Future<void> Function() open) async {
    _sheetOpen++;
    final wasPlaying = _videoController?.value.isPlaying == true;
    if (wasPlaying) await _videoController?.pause();
    try {
      await open();
    } finally {
      _sheetOpen--;
      if (mounted && wasPlaying && _sheetOpen == 0) _videoController?.play();
    }
  }

  Future<void> _openComments(Chronique c) => _holdWhile(() => showChroniqueComments(
        context,
        chronique: c,
        onChanged: (delta, pseudo, text) {
          if (!mounted) return;
          setState(() {
            c.commentCount = (c.commentCount + delta).clamp(0, 1 << 30);
            c.lastCommentPseudo = pseudo;
            c.lastCommentText = text;
          });
        },
      ));

  Future<void> _openReply(Chronique c) => _holdWhile(() => showChroniqueReply(context, c));

  /// Un geste sur le texte long : le minuteur attend 2 secondes de calme avant de reprendre.
  void _pauseStoryBriefly() {
    _held = true;
    _holdTimer?.cancel();
    _holdTimer = Timer(const Duration(seconds: 2), () => _held = false);
  }

  // ── Musique de la chronique ────────────────────────────────────────────────

  Future<void> _stopMusic() async {
    final p = _musicPlayer;
    _musicPlayer = null;
    try {
      await p?.stop();
      await p?.dispose();
    } catch (_) {}
  }

  Future<void> _startMusic(Chronique c) async {
    await _stopMusic();
    if (!c.hasMusic || c.type == ChroniqueType.AUDIO) return;
    final player = AudioPlayer();
    _musicPlayer = player;
    final start = c.musicStartMs ?? 0;
    final end = c.musicEndMs ?? 0;
    try {
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(_musicMuted ? 0 : c.musicVolume);
      player.onPositionChanged.listen((pos) {
        if (end > start && pos.inMilliseconds >= end) player.seek(Duration(milliseconds: start));
      });
      await player.setSourceUrl(MediaCdn.url(c.musicUrl));
      if (start > 0) await player.seek(Duration(milliseconds: start));
      if (_musicPlayer == player && mounted) await player.resume();
    } catch (e) {
      printVm('Musique de chronique indisponible : $e');
    }
  }

  void _toggleMusicMute() {
    setState(() => _musicMuted = !_musicMuted);
    final c = _allChroniques.isEmpty ? null : _allChroniques[_currentPage];
    _musicPlayer?.setVolume(_musicMuted ? 0 : (c?.musicVolume ?? .7));
  }

  Widget _buildHeartAnimation() {
    if (!_showHeartAnimation) return SizedBox();
    return Positioned.fill(
      child: Align(
        alignment: Alignment.center,
        child: AnimatedBuilder(
          animation: _heartAnimationController,
          builder: (context, child) {
            return Opacity(
              opacity: _heartOpacityAnimation.value,
              child: Transform.scale(scale: _heartScaleAnimation.value, child: Icon(Icons.favorite, color: Colors.red, size: 100)),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String count, double iconSize) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white, size: iconSize),
      SizedBox(width: 2),
      Text(count, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    ]);
  }

  Widget _buildChroniqueContent(Chronique chronique) {
    return Container(color: Colors.black, child: _buildMainContent(chronique));
  }

  Widget _buildMainContent(Chronique chronique) {
    switch (chronique.type) {
      case ChroniqueType.TEXT:
        return ChroniqueTextView(chronique: chronique, onTouch: _pauseStoryBriefly);

      case ChroniqueType.IMAGE:
        return ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: chronique.mediaUrl!,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
                placeholder: (context, url) => Container(color: Colors.grey[800], child: Center(child: CircularProgressIndicator(color: Color(0xFFFFD700)))),
              ),
              _overlayTextOf(chronique),
            ],
          ),
        );

      case ChroniqueType.VIDEO:
        return ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            children: [
              if (_videoController != null && _isVideoInitialized)
                AspectRatio(aspectRatio: _videoController!.value.aspectRatio, child: VideoPlayer(_videoController!)),
              if (!_isVideoInitialized)
                Positioned.fill(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // L'aperçu reste affiché jusqu'à ce que la vidéo soit prête et lancée
                      VideoPosterImage(
                        cacheKey: 'chronique_${chronique.id}',
                        posterUrl: chronique.posterUrl,
                        videoUrl: chronique.mediaUrl,
                        fit: BoxFit.contain,
                        placeholder: Container(color: Colors.grey[800]),
                      ),
                      Center(child: CircularProgressIndicator(color: Color(0xFFFFD700))),
                    ],
                  ),
                ),
              _overlayTextOf(chronique),
              Center(
                child: IconButton(
                  icon: Icon(_videoController?.value.isPlaying == true ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white.withOpacity(0.7), size: 50),
                  onPressed: () {
                    if (_videoController?.value.isPlaying == true) {
                      _videoController?.pause();
                    } else {
                      _videoController?.play();
                    }
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        );

      case ChroniqueType.AUDIO:
        return _buildAudioContent(chronique);
    }
  }

  /// Texte que l'auteur a posé sur son image ou sa vidéo, à l'endroit qu'il a choisi.
  Widget _overlayTextOf(Chronique c) {
    final t = (c.textContent ?? '').trim();
    if (t.isEmpty) return const SizedBox.shrink();
    return Positioned.fill(child: ChroniqueOverlayText(text: t, x: c.textX ?? kOverlayDefaultX, y: c.textY ?? kOverlayDefaultY));
  }

  Widget _buildAudioContent(Chronique chronique) {
    final startMs = chronique.audioStartMs ?? 0;
    final endMs = chronique.audioEndMs ?? _audioDuration.inMilliseconds;
    final clipDurationMs = (endMs > startMs) ? (endMs - startMs) : _audioDuration.inMilliseconds;
    final relativePos = (_audioPosition.inMilliseconds - startMs).clamp(0, clipDurationMs).toDouble();
    final progress = clipDurationMs > 0 ? (relativePos / clipDurationMs).clamp(0.0, 1.0) : 0.0;

    String fmtMs(int ms) {
      final s = (ms / 1000).round();
      return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Pochette
          if (chronique.coverImageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: chronique.coverImageUrl!,
                width: 160,
                height: 160,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(width: 160, height: 160, color: Colors.white10),
              ),
            )
          else
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white10,
              ),
              child: const Icon(Icons.music_note, color: Colors.white38, size: 56),
            ),

          const SizedBox(height: 20),

          // Titre
          if (chronique.textContent != null && chronique.textContent!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                chronique.textContent!,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          const SizedBox(height: 16),

          // Barre de progression
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: const Color(0xFFFFD700),
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white24,
                  ),
                  child: Slider(
                    value: progress,
                    min: 0,
                    max: 1,
                    onChanged: (v) {
                      final ms = startMs + (v * clipDurationMs).round();
                      _audioPlayer?.seek(Duration(milliseconds: ms));
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(fmtMs(relativePos.round()), style: const TextStyle(fontSize: 11, color: Colors.white54)),
                    Text(fmtMs(clipDurationMs), style: const TextStyle(fontSize: 11, color: Colors.white54)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Bouton play/pause
          GestureDetector(
            onTap: () async {
              if (_isAudioPlaying) {
                await _audioPlayer?.pause();
              } else {
                await _audioPlayer?.resume();
              }
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFD700),
              ),
              child: Icon(
                _isAudioPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.black,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeLeft(Timestamp expiresAt) {
    final difference = expiresAt.toDate().difference(DateTime.now());
    if (difference.inHours > 0) return '${difference.inHours}h';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m';
    return 'Expiré';
  }

  @override
  void dispose() {
    _stopStoryTimer();
    _pageController.dispose();
    _videoController?.dispose();
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    _adVideoController?.dispose();
    _holdTimer?.cancel();
    _vinylController.dispose();
    _musicPlayer?.stop();
    _musicPlayer?.dispose();
    _heartAnimationController.dispose();
    super.dispose();
  }
}
