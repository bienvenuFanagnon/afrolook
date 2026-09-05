import 'package:afrotok/utils/responsive_sheet.dart';
import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/layout/responsive_layout.dart';
import 'dart:async';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'dart:math';

import 'dart:typed_data';

import 'package:afrotok/pages/component/showUserDetails.dart';

import 'package:afrotok/pages/paiement/newDepot.dart';

import 'package:afrotok/pages/postDetails.dart';

import 'package:afrotok/pages/post_video_format_tel_details.dart';

import 'package:afrotok/widgets/chat/post_share_sheet.dart';

import 'package:afrotok/pages/pub/banner_ad_widget.dart';
import 'package:afrotok/pages/user/userAbonnementPage.dart';
import 'package:afrotok/services/utils/abonnement_utils.dart';

import 'package:afrotok/pages/pub/afrolook_inline_ad.dart';

import 'package:afrotok/pages/pub/rewarded_ad_widget.dart';

import 'package:afrotok/pages/widgetGlobal.dart';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:afrotok/widgets/smart_video_player.dart';
import '../services/media_cache_service.dart';

import 'package:flutter_linkify/flutter_linkify.dart';

import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_colors.dart';
import '../widgets/gifts/quick_gift_bar.dart';

import '../providers/locale_provider.dart';

import 'userPosts/postWidgets/translatable_description.dart';

import 'package:intl/intl.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:video_player/video_player.dart';

import 'package:chewie/chewie.dart';

import 'package:cached_network_image/cached_network_image.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:provider/provider.dart';

import 'package:afrotok/models/model_data.dart';

import 'package:afrotok/providers/postProvider.dart';

import 'package:afrotok/pages/postComments.dart';

import 'package:afrotok/services/linkService.dart';

import 'package:afrotok/widgets/user_badge_widget.dart';
import '../widgets/double_tap_like.dart';

import 'package:video_thumbnail/video_thumbnail.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:firebase_storage/firebase_storage.dart';

import 'package:path_provider/path_provider.dart';

import '../providers/authProvider.dart';

import '../providers/coin_gift_provider.dart';
import '../services/postService/feed_interaction_service.dart';
import '../services/streak_service.dart';

import 'canaux/detailsCanal.dart';
import 'user/otherUser/otherUser.dart';

import 'coins/coin_gift_dialog.dart';

import 'coins/coin_recharge_screen.dart';

import 'coins/post_gifts_list.dart';

import 'home/homeWidget.dart';

import '../services/postService/post_view_service.dart';

// Couleurs Afrolook (accent, non remplacées par AppColors)
const _afroGreen = Color(0xFF2ECC71);
const _afroYellow = Color(0xFFF1C40F);
const _afroRed = Color(0xFFE74C3C);
const _afroLightGrey = Color(0xFF71767B);

class VideoYoutubePageDetails extends StatefulWidget {
  final Post initialPost;
  final bool isIn;
  final String? feedTier;

  const VideoYoutubePageDetails({Key? key, required this.initialPost, this.isIn = false, this.feedTier}) : super(key: key);

  @override
  _VideoYoutubePageDetailsState createState() => _VideoYoutubePageDetailsState();
}

class _VideoYoutubePageDetailsState extends State<VideoYoutubePageDetails> {
  late UserAuthProvider authProvider;
  late PostProvider postProvider;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late SharedPreferences _prefs;
  final String _lastViewDatePrefix = 'last_view_date_';
  bool _isDescriptionExpanded = false;
  final Map<String, String> _translatedDescriptions = {};
  // Données actuelles
  Post _currentPost = Post();
  bool _isLoading = true;

  // Lecteur vidéo
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;

  // Suggestions
  List<Post> _suggestedVideos = [];
  bool _isLoadingSuggestions = false;
  // Set pour suivre les générations de miniatures en cours (éviter doublons)
  Set<String> _generatingThumbnails = {};

  // États pour les interactions
  bool _isFavorite = false;
  bool _isProcessingFavorite = false;
  bool _isSharing = false;
  bool _isSupporting = false;
  bool _showRewardedAd = false;
  bool? _hasSeenSupportModal;
  final GlobalKey<RewardedAdWidgetState> _rewardedAdKey = GlobalKey();

  // Vote challenge
  bool _hasVoted = false;
  bool _isVoting = false;
  List<String> _votersList = [];
  Challenge? _challenge;
  bool _loadingChallenge = false;

  // Cadeau
  int _selectedGiftIndex = 0;
  List<double> giftPrices = [10, 25, 50, 100, 200, 300, 500, 700, 1500, 2000, 2500, 5000, 7000, 10000, 15000, 20000, 30000, 50000, 75000, 100000];
  List<String> giftIcons = ['🌹','❤️','👑','💎','🏎️','⭐','🍫','🧰','🌵','🍕','🍦','💻','🚗','🏠','🛩️','🛥️','🏰','💎','🏎️','🚗'];
  bool _isLoadingGift = false;

  // Données utilisateur/canal
  UserData? _currentUser;
  Canal? _currentCanal;
  bool _isLoadingUser = false;
  bool _isLoadingCanal = false;
// Publicité
  bool _isAd = false;
  Advertisement? _advertisement;
  bool _isLoadingAd = false;

  // Midroll
  bool _showMidrollAd = false;
  Timer? _midrollTimer;
  bool _midrollShownForCurrentVideo = false;
  Map<String, dynamic>? _midrollAdData;
  VideoPlayerController? _midrollVideoController;
  bool _midrollVideoInitialized = false;
  VoidCallback? _videoPositionListener;
  // Streams de mise à jour
  StreamSubscription<DocumentSnapshot>? _postSubscription;

  bool get _isLookChallenge => _currentPost.type == 'CHALLENGEPARTICIPATION';
  // Suggestions
  Timer? _suggestionModalTimer;
  bool _hasSeenSuggestionsModal = false;

  // Nouveau système de like + commentaire rapide
  bool _isLiking = false;
  List<PostComment> _preloadedComments = [];
  final TextEditingController _quickCommentController = TextEditingController();
  bool _isSendingQuickComment = false;

  @override
  void initState() {
    super.initState();

    _initSharedPreferences();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);
    _currentPost = widget.initialPost;

    // Marquer le post comme vu (Tier 1) si l'utilisateur l'ouvre consciemment
    final _pid = widget.initialPost.id;
    if (_pid != null &&
        (authProvider.loginUserData.unreadPosts ?? {}).containsKey(_pid)) {
      SharedPreferences.getInstance().then((prefs) {
        final list = prefs.getStringList('seen_tier1_posts_pending') ?? [];
        if (!list.contains(_pid)) {
          list.add(_pid);
          prefs.setStringList('seen_tier1_posts_pending', list);
        }
      });
    }

    _startSuggestionModalTimer();

    // ✅ Vérification correcte : portrait ET pas déjà sur la page adaptée

      // Attendre que le premier frame soit terminé pour éviter l'erreur de contexte
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.initialPost.isPortrait == true) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PostDetailsVideoFormatTel(
                initialPost: widget.initialPost,
                isIn: true, // important pour éviter une nouvelle redirection
              ),
            ),
          );

        }
      });
    _loadSuggestions();
    _loadSupportModalSeen();
    _loadPostRelations();
    _checkIfFavorite();
    if (_isLookChallenge && _currentPost.challenge_id != null) {
      _loadChallengeData();
    }
    _checkIfUserHasVoted();
    _initializeVideo();
    _incrementViews();
    _isAd = _currentPost.isAdvertisement == true;
    if (_isAd && _currentPost.advertisementId != null) {
      _loadAdvertisement();
    }
    _loadLastComment();
  }

  void _startSuggestionModalTimer() {
    _suggestionModalTimer?.cancel();
    if (_hasSeenSuggestionsModal) return;
    _suggestionModalTimer = Timer(Duration(seconds: 5), () {
      if (mounted && !_hasSeenSuggestionsModal) {
        _showSuggestionsModal();
      }
    });
  }
  Future<void> _markSuggestionsModalSeen() async {
    final userId = authProvider.loginUserData?.id;
    printVm('🔍 _markSuggestionsModalSeen - userId: $userId');
    if (userId == null) {
      printVm('⚠️ userId est null, impossible de sauvegarder');
      return;
    }
    final key = 'has_seen_suggestions_modal_video_$userId';
    await _prefs.setBool(key, true);
    printVm('💾 Clé sauvegardée: $key = true');
    setState(() {
      _hasSeenSuggestionsModal = true;
    });
  }

  void _showSuggestionsModal() {
    final suggestions = getFilteredSuggestions().take(10).toList();

    if (suggestions.isEmpty) return;

    final colors = AppColors.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.lightbulb, color: colors.accent),
            SizedBox(width: 8),
            Text(
              'Découvrez d’autres posts',
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold,fontSize: 13),
            ),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vous pouvez faire défiler vers le bas pour voir d’autres vidéos tendance du moment !',
                style: TextStyle(color: colors.textSecondary),
              ),
              SizedBox(height: 16),
              Text(
                'Suggestions pour vous :',
                style: TextStyle(color: colors.accent, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      for (int i = 0; i < suggestions.length; i++)
                        Column(
                          children: [
                            // if (i == 3) // 4ème élément (index 3)
                            // _buildAdMrec(key: 'ad_suggestion_modal'),
                            _buildSuggestionItem(suggestions[i])
                                .animate()
                                .fadeIn(duration: 300.ms, delay: (i * 60).ms)
                                .slideX(begin: 0.05, end: 0, duration: 300.ms, curve: Curves.easeOut),
                            if (i != suggestions.length - 1) SizedBox(height: 12),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _markSuggestionsModalSeen();
            },
            style: ElevatedButton.styleFrom(backgroundColor: colors.primary),
            child: Text('J’ai compris', style: TextStyle(color: colors.onPrimary)),
          ),
        ],
      ),
    );
  }
  Widget _buildSuggestionItem(Post post) {
    return _buildYouTubeCard(post);
  }

  Widget _buildYouTubeCard(Post post) {
    final colors = AppColors.of(context);
    final thumb = _thumbUrlFor(post);
    return GestureDetector(
      onTap: () => _onSuggestedPostSelected(post),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 170,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Miniature plein-écran ──────────────────────────────────
              thumb.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: thumb,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: colors.shimmerBase),
                      errorWidget: (_, __, ___) => _thumbFallback(post, colors),
                    )
                  : _thumbFallback(post, colors),

              // ── Gradient bas ───────────────────────────────────────────
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.25, 1.0],
                      colors: [Colors.transparent, Colors.black.withOpacity(0.88)],
                    ),
                  ),
                ),
              ),

              // ── Badge type ─────────────────────────────────────────────
              Positioned(
                top: 8,
                right: 8,
                child: _buildPostTypeBadge(post),
              ),

              // ── Description + stats ────────────────────────────────────
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        post.description ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _suggStatItem(Icons.remove_red_eye_outlined, _formatCount(post.vues ?? post.totalInteractions ?? 0)),
                          const SizedBox(width: 12),
                          _suggStatItem(Icons.favorite_rounded, _formatCount(post.loves ?? 0), color: const Color(0xFFFF6B6B)),
                          const SizedBox(width: 12),
                          _suggStatItem(Icons.chat_bubble_outline_rounded, _formatCount(post.comments ?? 0)),
                        ],
                      ),
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

  String _thumbUrlFor(Post post) {
    if (post.dataType == PostDataType.VIDEO.name && post.thumbnail != null && post.thumbnail!.isNotEmpty) {
      return post.thumbnail!;
    }
    if (post.images != null && post.images!.isNotEmpty) return post.images!.first;
    if (post.url_media != null && post.url_media!.isNotEmpty) return post.url_media!;
    return '';
  }

  Widget _thumbFallback(Post post, AppColors colors) {
    final isVideo = post.dataType == PostDataType.VIDEO.name;
    final isAudio = post.dataType == PostDataType.AUDIO.name;
    return Container(
      color: colors.shimmerBase,
      child: Center(
        child: Icon(
          isVideo ? Icons.play_circle_outline_rounded
              : isAudio ? Icons.music_note_rounded
              : Icons.image_outlined,
          size: 48,
          color: colors.textSecondary.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildPostTypeBadge(Post post) {
    final bool isVideo = post.dataType == PostDataType.VIDEO.name;
    final bool isAudio = post.dataType == PostDataType.AUDIO.name;
    final bool isText  = post.dataType == PostDataType.TEXT.name;
    final String emoji = isVideo ? '🎬' : isAudio ? '🎵' : isText ? '✍️' : '📷';
    final String label = isVideo ? 'VIDÉO' : isAudio ? 'AUDIO' : isText ? 'TEXTE' : 'IMAGE';
    final Color bg = isVideo
        ? Colors.red.withOpacity(0.85)
        : isAudio
            ? Colors.purple.withOpacity(0.85)
            : isText
                ? Colors.blueAccent.withOpacity(0.85)
                : Colors.black54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 10)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _suggStatItem(IconData icon, String value, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color ?? Colors.white,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 4)]),
        const SizedBox(width: 3),
        Text(value, style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
        )),
      ],
    );
  }

  void _loadSuggestions() {
    setState(() {
      _isLoadingSuggestions = true;
    });
    // Simuler un petit délai pour l'UI (optionnel)
    Future.delayed(Duration(milliseconds: 100), () {
      final suggestions = getFilteredSuggestions();
      setState(() {
        _suggestedVideos = suggestions;
        _isLoadingSuggestions = false;
      });
      // Générer les miniatures manquantes pour les vidéos suggérées
      for (var post in suggestions) {
        if (post.dataType == PostDataType.VIDEO.name && (post.thumbnail == null || post.thumbnail!.isEmpty)) {
          _ensureThumbnailForPost(post);
        }
      }
    });
  }

  final Set<String> _clickedInSession = {};

  Future<void> _recordAdClick(Advertisement ad, Post post) async {
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null || ad.id == null) return;

    final clickKey = '${ad.id}_$currentUserId';
    if (_clickedInSession.contains(clickKey)) return;

    _clickedInSession.add(clickKey);

    try {
      final adRef = _firestore.collection('Advertisements').doc(ad.id);
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      await _firestore.runTransaction((transaction) async {
        final adDoc = await transaction.get(adRef);
        if (!adDoc.exists) return;

        final currentAd = Advertisement.fromJson(adDoc.data()!);

        final clickIncr = Random().nextInt(3) + 1;
        Map<String, dynamic> updates = {
          'clicks': FieldValue.increment(clickIncr),
          'updatedAt': DateTime.now().microsecondsSinceEpoch,
        };

        if (currentAd.dailyStats != null) {
          updates['dailyStats.$today.clicks'] = FieldValue.increment(1);
        }

        final hasClicked = currentAd.clickersIds?.contains(currentUserId) ?? false;
        if (!hasClicked) {
          updates['uniqueClicks'] = FieldValue.increment(1);
          updates['clickersIds'] = FieldValue.arrayUnion([currentUserId]);
        }

        transaction.update(adRef, updates);
      });

      printVm('✅ Clic enregistré pour la pub: ${ad.id}');
    } catch (e) {
      printVm('❌ Erreur clic: $e');
      _clickedInSession.remove(clickKey);
    }
  }
  // ==================== GÉNÉRATION DE MINIATURE ====================
  Future<void> _ensureThumbnailForPost(Post post) async {
    // VideoThumbnail + dart:io File ne fonctionnent pas sur Flutter Web
    if (kIsWeb) return;
    // Si déjà une thumbnail ou en cours de génération, on ignore
    if (post.thumbnail != null && post.thumbnail!.isNotEmpty) return;
    if (_generatingThumbnails.contains(post.id)) return;

    // Si le post n'a pas d'URL vidéo, on ignore
    if (post.url_media == null || post.url_media!.isEmpty) return;

    _generatingThumbnails.add(post.id!);

    // Mettre à jour l'affichage pour ce post (afficher un indicateur)
    setState(() {});

    try {
      // Générer la miniature locale
      final thumbnailFile = await VideoThumbnail.thumbnailFile(
        video: post.url_media!,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 75,
        timeMs: 1000,
      );

      if (thumbnailFile == null) {
        _generatingThumbnails.remove(post.id);
        setState(() {});
        return;
      }

      // Upload vers Firebase Storage
      final fileName = 'thumbnails/thumb_${post.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      final bytes = await XFile(thumbnailFile).readAsBytes();
      final snapshot = await ref.putData(bytes);
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Mettre à jour Firestore
      await _firestore.collection('Posts').doc(post.id).update({
        'thumbnail': downloadUrl,
      });

      // Mettre à jour l'objet local dans la liste des suggestions
      final index = _suggestedVideos.indexWhere((p) => p.id == post.id);
      if (index != -1) {
        setState(() {
          _suggestedVideos[index].thumbnail = downloadUrl;
        });
      }

      // Si c'est le post courant (peu probable, mais au cas où)
      if (_currentPost.id == post.id) {
        setState(() {
          _currentPost.thumbnail = downloadUrl;
        });
      }
    } catch (e) {
      printVm('Erreur génération miniature pour post ${post.id}: $e');
    } finally {
      _generatingThumbnails.remove(post.id);
      setState(() {});
    }
  }
  Future<void> _loadAdvertisement() async {
    if (_currentPost.advertisementId == null) return;
    setState(() => _isLoadingAd = true);
    try {
      final adDoc = await _firestore
          .collection('Advertisements')
          .doc(_currentPost.advertisementId)
          .get();
      if (adDoc.exists) {
        final ad = Advertisement.fromJson(adDoc.data()!);
        ad.id = adDoc.id;
        setState(() => _advertisement = ad);
        _recordAdView(ad);
      }
    } catch (e) {
      printVm('Erreur chargement publicité: $e');
    } finally {
      setState(() => _isLoadingAd = false);
    }
  }

  Future<void> _recordAdView(Advertisement ad) async {
    if (ad.id == null) return;
    final viewIncr = Random().nextInt(3) + 1;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      await _firestore.collection('Advertisements').doc(ad.id).update({
        'views': FieldValue.increment(viewIncr),
        'uniqueViews': FieldValue.increment(1),
        'dailyStats.$today.views': FieldValue.increment(viewIncr),
        'updatedAt': DateTime.now().microsecondsSinceEpoch,
      });
    } catch (e) {
      printVm('Erreur enregistrement vue pub: $e');
    }
  }

  // Boost : état pour les posts non-pub dont l'utilisateur est propriétaire
  Advertisement? _ownerAdForPost;
  bool _ownerAdLoaded = false;

  Future<void> _loadOwnerAd() async {
    if (_ownerAdLoaded || _currentPost.id == null) return;
    _ownerAdLoaded = true;
    try {
      final snap = await _firestore
          .collection('Advertisements')
          .where('postId', isEqualTo: _currentPost.id)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty && mounted) {
        final ad = Advertisement.fromJson(snap.docs.first.data());
        ad.id = snap.docs.first.id;
        setState(() => _ownerAdForPost = ad);
      }
    } catch (_) {}
  }

  // ==================== SUGGESTIONS ====================
  List<Post> getFilteredSuggestions() {
    final seenIds = <String>{widget.initialPost.id ?? ''};
    final seenUserIds = <String>{};
    final result = <Post>[];
    for (final p in postProvider.suggestedPosts) {
      if (p.id == null) continue;
      if (!seenIds.add(p.id!)) continue;
      // 1 post max par utilisateur
      final uid = p.user_id ?? '';
      if (uid.isNotEmpty && !seenUserIds.add(uid)) continue;
      result.add(p);
    }
    return result;
  }

// Navigation vers un post suggéré
  void _onSuggestedPostSelected(Post newPost) {
    if(newPost.dataType==PostDataType.VIDEO.name){
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VideoYoutubePageDetails(initialPost: newPost,isIn: true,),
        ),
      );
    }else{
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DetailsPost(post: newPost),
        ),
      );
    }

  }

  // ==================== AUTRES MÉTHODES (inchangées) ====================
  Future<void> _incrementViews() async {
    try {
      if (authProvider.loginUserData == null ||
          widget.initialPost == null ||
          widget.initialPost.id == null) return;
      final currentUserId = authProvider.loginUserData.id;
      if (currentUserId == null) return;

      // Garde permanente par appareil — une seule vue par utilisateur par post
      final prefKey = 'view_${widget.initialPost.id}_$currentUserId';
      if (_prefs.getBool(prefKey) ?? false) {
        printVm('⏭️ Vue déjà enregistrée pour cet utilisateur');
        return;
      }
      await _prefs.setBool(prefKey, true);

      authProvider.incrementPostTotalInteractions(
        postId: widget.initialPost.id!,
        userId: currentUserId,
        interactionType: 'view',
      );

      setState(() {
        widget.initialPost.vues = (widget.initialPost.vues ?? 0) + 1;
        widget.initialPost.users_vue_id ??= [];
        widget.initialPost.users_vue_id!.add(currentUserId);
      });
      await _firestore.collection('Posts').doc(widget.initialPost.id).update({
        'vues': FieldValue.increment(1),
        'users_vue_id': FieldValue.arrayUnion([currentUserId]),
        'popularity': FieldValue.increment(2),
      });
      PostViewService.recordAuthorView(widget.initialPost, currentUserId);
      printVm('✅ Vue unique enregistrée pour ${widget.initialPost.id}');
    } catch (e) {
      printVm("Erreur incrémentation vues: $e");
    }
  }

  @override
  void dispose() {
    _postSubscription?.cancel();
    _midrollTimer?.cancel();
    _midrollVideoController?.dispose();
    _midrollVideoController = null;
    _removeMidrollListener();
    _videoController?.dispose();
    _chewieController?.dispose();
    _quickCommentController.dispose();
    super.dispose();
  }

  Future<void> _initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> _loadSupportModalSeen() async {
    final userId = authProvider.loginUserData.id;
    final key = 'has_seen_support_modal_$userId';
    _hasSeenSupportModal = _prefs.getBool(key) ?? false;
  }

  Future<void> _markSupportModalSeen() async {
    final userId = authProvider.loginUserData.id;
    await _prefs.setBool('has_seen_support_modal_$userId', true);
    _hasSeenSupportModal = true;
  }

  Future<void> _loadPostRelations() async {
    if (_currentPost.user_id == null) return;
    setState(() => _isLoadingUser = true);
    try {
      final userDoc = await _firestore.collection('Users').doc(_currentPost.user_id).get();
      if (userDoc.exists) {
        _currentUser = UserData.fromJson(userDoc.data()!);
        _currentPost.user = _currentUser;
      }
      if (_currentPost.canal_id != null && _currentPost.canal_id!.isNotEmpty) {
        setState(() => _isLoadingCanal = true);
        final canalDoc = await _firestore.collection('Canaux').doc(_currentPost.canal_id).get();
        if (canalDoc.exists) {
          _currentCanal = Canal.fromJson(canalDoc.data()!);
          _currentPost.canal = _currentCanal;
        }
        setState(() => _isLoadingCanal = false);
      }
    } catch (e) {
      printVm('Erreur chargement relations: $e');
    } finally {
      setState(() => _isLoadingUser = false);
    }
  }

  Future<void> _checkIfFavorite() async {
    final userId = authProvider.loginUserData.id;
    if (userId == null) return;
    try {
      final postDoc = await _firestore.collection('Posts').doc(_currentPost.id).get();
      if (postDoc.exists) {
        final favorites = List<String>.from(postDoc.data()?['users_favorite_id'] ?? []);
        setState(() => _isFavorite = favorites.contains(userId));
      }
    } catch (e) {
      printVm('Erreur vérification favori: $e');
    }
  }

  Future<void> _loadChallengeData() async {
    if (_currentPost.challenge_id == null) return;
    setState(() => _loadingChallenge = true);
    try {
      final doc = await _firestore.collection('Challenges').doc(_currentPost.challenge_id).get();
      if (doc.exists) {
        _challenge = Challenge.fromJson(doc.data()!)..id = doc.id;
      }
    } catch (e) {
      printVm('Erreur chargement challenge: $e');
    } finally {
      setState(() => _loadingChallenge = false);
    }
  }
  Widget _buildExpandableDescription(String text) {
    final colors = AppColors.of(context);
    const int maxWords = 10;
    final words = text.split(' ');
    final bool isLong = words.length > maxWords;
    final String displayedText = _isDescriptionExpanded || !isLong
        ? text
        : words.take(maxWords).join(' ') + '...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Linkify(
          onOpen: (link) async {
            if (await canLaunchUrl(Uri.parse(link.url))) {
              await launchUrl(Uri.parse(link.url));
            }
          },
          text: displayedText,
          style: TextStyle(color: colors.textPrimary, fontSize: 15, height: 1.4),
          linkStyle: TextStyle(color: colors.info),
        ),
        if (isLong)
          GestureDetector(
            onTap: () {
              setState(() {
                _isDescriptionExpanded = !_isDescriptionExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _isDescriptionExpanded ? "Voir moins" : "Voir plus",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1D9BF0), // bleu twitter
                ),
              ),
            ),
          ),
        if (_currentPost.id != null && (_currentPost.description ?? '').trim().isNotEmpty)
          TranslatableDescription(
            postId: _currentPost.id!,
            text: _currentPost.description!,
            targetLang: Provider.of<LocaleProvider>(context, listen: false).locale.languageCode,
            onToggle: (t) => setState(() {
              if (t == null) {
                _translatedDescriptions.remove(_currentPost.id);
              } else {
                _translatedDescriptions[_currentPost.id!] = t;
              }
            }),
            style: TextStyle(color: colors.textPrimary),
          ),
      ],
    );
  }
  Future<void> _checkIfUserHasVoted() async {
    try {
      final postDoc = await _firestore.collection('Posts').doc(_currentPost.id).get();
      if (postDoc.exists) {
        final voters = List<String>.from(postDoc.data()?['users_votes_ids'] ?? []);
        setState(() {
          _hasVoted = voters.contains(authProvider.loginUserData.id);
          _votersList = voters;
        });
      }
    } catch (e) {
      printVm('Erreur vérification vote: $e');
    }
  }

  Future<void> _initializeVideo() async {
    // Sur web, SmartVideoPlayer gère l'affichage nativement via <video> HTML
    if (kIsWeb) return;
    if (_currentPost.url_media == null || _currentPost.url_media!.isEmpty) return;
    _videoController?.dispose();
    _chewieController?.dispose();
    try {
      final String optimizedUrl = authProvider.convertToCdnUrl(_currentPost.url_media!, authProvider.appDefaultData);
      _videoController = await MediaCacheService.videoController(optimizedUrl);
      await _videoController!.initialize();
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        showControls: true,
        allowFullScreen: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: _afroGreen,
          handleColor: _afroGreen,
          backgroundColor: _afroLightGrey.withOpacity(0.3),
          bufferedColor: _afroLightGrey.withOpacity(0.1),
        ),
        placeholder: Container(color: Colors.black, child: Center(child: CircularProgressIndicator(color: _afroGreen))),
        autoInitialize: true,
      );
      if (mounted) setState(() => _isVideoInitialized = true);
      _attachMidrollListener();
      await _recordPostView();
    } catch (e) {
      printVm('Erreur initialisation vidéo: $e');
      if (mounted) setState(() => _isVideoInitialized = false);
    }
  }

  // ── Midroll ────────────────────────────────────────────────────────────────

  bool _isUserPremium() =>
      AbonnementUtils.isPremiumActive(authProvider.loginUserData?.abonnement) ||
      AbonnementUtils.isAdmin(authProvider.loginUserData?.role);

  void _attachMidrollListener() {
    if (_videoController == null) return;
    _removeMidrollListener();
    _midrollShownForCurrentVideo = false;
    final listener = () {
      if (_midrollShownForCurrentVideo || !mounted) return;
      final vpc = _videoController;
      if (vpc == null) return;
      final value = vpc.value;
      if (!value.isPlaying) return;
      final duration = value.duration;
      final position = value.position;
      if (duration.inSeconds < 20) return;
      final remaining = duration - position;
      if (remaining.inSeconds <= 15 && remaining.inSeconds > 0 && position.inSeconds > 5) {
        _midrollShownForCurrentVideo = true;
        _showMidrollOverlay();
      }
    };
    _videoPositionListener = listener;
    _videoController!.addListener(listener);
  }

  void _removeMidrollListener() {
    if (_videoPositionListener != null && _videoController != null) {
      _videoController!.removeListener(_videoPositionListener!);
    }
    _videoPositionListener = null;
  }

  Future<void> _showMidrollOverlay() async {
    if (!mounted || _isUserPremium()) return;
    _videoController?.pause();
    _chewieController?.pause();
    final ads = authProvider.advertisements;
    Map<String, dynamic>? picked;
    if (ads.isNotEmpty) {
      picked = ads[Random().nextInt(ads.length)];
      _midrollAdData = picked;
    }
    setState(() { _showMidrollAd = true; _midrollVideoInitialized = false; });
    _midrollTimer?.cancel();
    _midrollTimer = Timer(const Duration(seconds: 5), _closeMidrollOverlay);

    if (picked != null && picked['isEntityBoost'] != true && picked['post'] != null) {
      try {
        final post = Post.fromJson(picked['post'] as Map<String, dynamic>);
        final isVideo = post.dataType == PostDataType.VIDEO.name ||
            (post.url_media?.contains('.mp4') ?? false) ||
            (post.url_media?.contains('.mov') ?? false);
        if (isVideo && post.url_media?.isNotEmpty == true) {
          final cdnUrl = authProvider.convertToCdnUrl(post.url_media!, authProvider.appDefaultData);
          _midrollVideoController?.dispose();
          final ctrl = VideoPlayerController.networkUrl(Uri.parse(cdnUrl));
          _midrollVideoController = ctrl;
          await ctrl.initialize();
          await ctrl.setVolume(0);
          ctrl.setLooping(true);
          ctrl.play();
          if (mounted) setState(() => _midrollVideoInitialized = true);
        }
      } catch (_) {
        _midrollVideoController?.dispose();
        _midrollVideoController = null;
      }
    }
  }

  void _closeMidrollOverlay() {
    if (!mounted) return;
    _midrollTimer?.cancel();
    _midrollVideoController?.dispose();
    _midrollVideoController = null;
    setState(() { _showMidrollAd = false; _midrollVideoInitialized = false; });
    _videoController?.play();
    _chewieController?.play();
  }

  String _ownerCtaLabel(String? type) {
    switch (type) {
      case 'canal':     return "S'abonner";
      case 'group':     return 'Rejoindre';
      case 'event':     return 'Participer';
      case 'challenge': return 'Participer';
      case 'product':   return 'Commander';
      case 'service':   return 'Contacter';
      case 'content':   return 'Voir';
      case 'user':      return 'Suivre';
      default:          return 'Voir';
    }
  }

  Future<void> _navigateToAdOwner(BuildContext ctx, String ownerId, String? ownerType) async {
    try {
      final fs = FirebaseFirestore.instance;
      switch (ownerType) {
        case 'canal':
          final doc = await fs.collection('Canaux').doc(ownerId).get();
          if (!doc.exists || !ctx.mounted) return;
          final data = Map<String, dynamic>.from(doc.data()!);
          data['id'] = doc.id;
          Navigator.push(ctx, MaterialPageRoute(
            builder: (_) => CanalDetails(canal: Canal.fromJson(data)),
          ));
          break;
        case 'user':
        default:
          final doc = await fs.collection('Users').doc(ownerId).get();
          if (!doc.exists || !ctx.mounted) return;
          final data = Map<String, dynamic>.from(doc.data()!);
          data['id'] = doc.id;
          Navigator.push(ctx, MaterialPageRoute(
            builder: (_) => OtherUserPage(otherUser: UserData.fromJson(data)),
          ));
      }
    } catch (e) {
      debugPrint('_navigateToAdOwner error: $e');
    }
  }

  Widget _buildMidrollCard() {
    final screenH = MediaQuery.of(context).size.height;
    final adData = _midrollAdData;

    Post? post;
    Advertisement? ad;
    String? thumb;
    String caption = '';
    String btnText = 'En savoir plus';
    bool isEntityBoost = adData?['isEntityBoost'] == true;

    if (adData != null) {
      try {
        ad = Advertisement.fromJson(adData['ad'] as Map<String, dynamic>);
        caption = ad.description ?? ''; // description de la pub, pas du post
        btnText = ad.actionButtonText ?? 'En savoir plus';
        if (!isEntityBoost && adData['post'] != null) {
          post = Post.fromJson(adData['post'] as Map<String, dynamic>);
          if (thumb == null && post.thumbnail?.isNotEmpty == true) thumb = post.thumbnail;
          if (thumb == null && post.images?.isNotEmpty == true && post.images!.first.isNotEmpty) thumb = post.images!.first;
          if (caption.isEmpty) caption = post.description ?? '';
        }
      } catch (_) {}
    }

    // ── Boost entité : carte centrée style chronique ──
    if (isEntityBoost && ad != null) {
      final typeLabel = ad.ownerType == 'canal' ? 'Canal' : ad.ownerType == 'group' ? 'Groupe' : 'Créateur';
      final ctaLabel = _ownerCtaLabel(ad.ownerType);
      return Positioned.fill(
        child: Material(
          color: Colors.black.withOpacity(0.93),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: screenH * 0.82, maxWidth: 400),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.verified, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text('SPONSORISÉ • $typeLabel',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
                          ]),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _closeMidrollOverlay,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 18),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 20),
                      // Avatar
                      Container(
                        width: 84, height: 84,
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
                      const SizedBox(height: 14),
                      Text(ad.ownerName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
                      if ((ad.ownerFollowers ?? 0) > 0) ...[
                        const SizedBox(height: 4),
                        Text('${ad.ownerFollowers} ${ad.ownerType == 'group' ? 'membres' : 'abonnés'}',
                          style: const TextStyle(color: Color(0xFFFFD700), fontSize: 13, fontWeight: FontWeight.w500, decoration: TextDecoration.none)),
                      ],
                      if (caption.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(caption, maxLines: 3, overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.45, decoration: TextDecoration.none)),
                      ],
                      // Stats pub
                      if ((ad.views ?? 0) > 0) ...[
                        const SizedBox(height: 12),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.remove_red_eye_outlined, size: 13, color: Colors.white54),
                          const SizedBox(width: 4),
                          Text('${ad.views} vues', style: const TextStyle(color: Colors.white54, fontSize: 11, decoration: TextDecoration.none)),
                          if ((ad.clicks ?? 0) > 0) ...[
                            const SizedBox(width: 12),
                            const Icon(Icons.touch_app_outlined, size: 13, color: Colors.white54),
                            const SizedBox(width: 4),
                            Text('${ad.clicks} clics', style: const TextStyle(color: Colors.white54, fontSize: 11, decoration: TextDecoration.none)),
                          ],
                        ]),
                      ],
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: () {
                          final ownerId = ad!.ownerId;
                          final ownerType = ad.ownerType;
                          if (ownerId == null) return;
                          _closeMidrollOverlay();
                          _navigateToAdOwner(context, ownerId, ownerType);
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
                            style: const TextStyle(color: Colors.black, fontSize: 15, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Positioned.fill(
      child: Material(
        color: Colors.black.withOpacity(0.93),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: screenH * 0.82, maxWidth: 440),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Header : badge + close ──
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text('SPONSORISÉ', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
                            ],
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _closeMidrollOverlay,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Carte pub ──
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        color: const Color(0xFF1A1A1A),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Zone média
                            GestureDetector(
                              onTap: () {
                                if (post != null && ad != null) {
                                  _closeMidrollOverlay();
                                  if (post.dataType == PostDataType.VIDEO.name || (post.url_media?.contains('.mp4') ?? false)) {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailsVideoFormatTel(initialPost: post!, isIn: false)));
                                  } else {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => DetailsPost(post: post!)));
                                  }
                                }
                              },
                              child: Builder(builder: (ctx) {
                                final isVideo = _midrollVideoInitialized && _midrollVideoController != null;
                                final videoSize = isVideo ? _midrollVideoController!.value.size : Size.zero;
                                final videoRatio = (isVideo && videoSize.height > 0) ? videoSize.width / videoSize.height : 16 / 9;
                                return Container(
                                  color: Colors.black,
                                  constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.42),
                                  child: AspectRatio(
                                    aspectRatio: isVideo ? videoRatio : 4 / 3,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Container(color: Colors.black),
                                        if (isVideo)
                                          FittedBox(
                                            fit: BoxFit.contain,
                                            child: SizedBox(
                                              width: videoSize.width,
                                              height: videoSize.height,
                                              child: VideoPlayer(_midrollVideoController!),
                                            ),
                                          )
                                        else if (thumb != null)
                                          CachedNetworkImage(imageUrl: thumb, fit: BoxFit.contain,
                                            placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFD700))),
                                            errorWidget: (_, __, ___) => const Icon(Icons.image, color: Colors.white38, size: 48),
                                          )
                                        else
                                          const Icon(Icons.image, color: Colors.white38, size: 48),
                                        if (post != null && (post.dataType == PostDataType.VIDEO.name || (post.url_media?.contains('.mp4') ?? false)))
                                          Positioned(bottom: 8, right: 8,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                              decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(6)),
                                              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                                Icon(Icons.videocam, color: Colors.white, size: 12),
                                                SizedBox(width: 3),
                                                Text('VIDÉO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
                                              ]),
                                            ),
                                          ),
                                        if (_midrollVideoInitialized)
                                          Positioned(top: 8, left: 8,
                                            child: Container(
                                              padding: const EdgeInsets.all(5),
                                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                              child: const Icon(Icons.volume_off, color: Colors.white, size: 14),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),

                            // ── Infos pub ──
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (caption.isNotEmpty)
                                    Text(caption, maxLines: ad?.ownerName?.isNotEmpty == true ? 1 : 3, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, height: 1.4, decoration: TextDecoration.none)),
                                  if (caption.isNotEmpty) const SizedBox(height: 10),

                                  // ── Profil / entité boostée ──
                                  if (ad != null && ad!.ownerName?.isNotEmpty == true) ...[
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.07),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                                      ),
                                      child: Row(
                                        children: [
                                          ClipOval(
                                            child: SizedBox(width: 42, height: 42,
                                              child: ad!.ownerAvatar?.isNotEmpty == true
                                                  ? CachedNetworkImage(imageUrl: ad!.ownerAvatar!, fit: BoxFit.cover,
                                                      placeholder: (_, __) => Container(color: const Color(0xFFFFD700).withOpacity(0.3)),
                                                      errorWidget: (_, __, ___) => Container(color: const Color(0xFFFFD700).withOpacity(0.3), child: const Icon(Icons.person, color: Color(0xFFFFD700), size: 20)),
                                                    )
                                                  : Container(color: const Color(0xFFFFD700).withOpacity(0.3), child: const Icon(Icons.person, color: Color(0xFFFFD700), size: 20)),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(ad!.ownerName!, maxLines: 1, overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
                                                if (ad!.ownerDescription?.isNotEmpty == true)
                                                  Text(ad!.ownerDescription!, maxLines: 1, overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(color: Colors.white54, fontSize: 11, decoration: TextDecoration.none))
                                                else if ((ad!.ownerFollowers ?? 0) > 0)
                                                  Text('${ad!.ownerFollowers} abonnés',
                                                    style: const TextStyle(color: Colors.white54, fontSize: 11, decoration: TextDecoration.none)),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () {
                                              final ownerId = ad!.ownerId;
                                              final ownerType = ad!.ownerType;
                                              if (ownerId == null) return;
                                              _closeMidrollOverlay();
                                              _navigateToAdOwner(context, ownerId, ownerType);
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(color: const Color(0xFFFFD700), borderRadius: BorderRadius.circular(20)),
                                              child: Text(_ownerCtaLabel(ad!.ownerType),
                                                style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // ── Mini-feed 3 derniers posts ──
                                    if (ad!.ownerRecentPosts?.isNotEmpty == true) ...[
                                      Row(
                                        children: ad!.ownerRecentPosts!.take(3).map((p) {
                                          final pThumb = p['thumb'] as String? ?? '';
                                          final isVideo = p['isVideo'] as bool? ?? false;
                                          return Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.only(right: 6),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(10),
                                                child: AspectRatio(
                                                  aspectRatio: 1,
                                                  child: Stack(
                                                    fit: StackFit.expand,
                                                    children: [
                                                      if (pThumb.isNotEmpty)
                                                        CachedNetworkImage(imageUrl: pThumb, fit: BoxFit.cover,
                                                          placeholder: (_, __) => Container(color: Colors.white10),
                                                          errorWidget: (_, __, ___) => Container(color: Colors.white10),
                                                        )
                                                      else
                                                        Container(color: Colors.white10),
                                                      Container(color: Colors.black.withOpacity(0.40)),
                                                      if (isVideo) const Center(child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 22)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                      const SizedBox(height: 12),
                                      // CTA pleine largeur
                                      GestureDetector(
                                        onTap: () {
                                          final ownerId = ad!.ownerId;
                                          final ownerType = ad!.ownerType;
                                          if (ownerId == null) return;
                                          _closeMidrollOverlay();
                                          _navigateToAdOwner(context, ownerId, ownerType);
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          decoration: BoxDecoration(color: const Color(0xFFFFD700), borderRadius: BorderRadius.circular(10)),
                                          child: Text(
                                            _ownerCtaLabel(ad!.ownerType) == 'Suivre' ? 'Suivre ce créateur'
                                              : _ownerCtaLabel(ad!.ownerType) == "S'abonner" ? "S'abonner à ce canal"
                                              : 'Rejoindre ${ad!.ownerName ?? ''}',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w800, decoration: TextDecoration.none),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                    ],
                                  ],

                                  // Stats pub (vues + clics)
                                  if (ad != null && (ad!.views ?? 0) > 0) ...[
                                    const SizedBox(height: 10),
                                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      const Icon(Icons.remove_red_eye_outlined, size: 13, color: Colors.white54),
                                      const SizedBox(width: 4),
                                      Text('${ad!.views} vues',
                                        style: const TextStyle(color: Colors.white54, fontSize: 11, decoration: TextDecoration.none)),
                                      if ((ad!.clicks ?? 0) > 0) ...[
                                        const SizedBox(width: 12),
                                        const Icon(Icons.touch_app_outlined, size: 13, color: Colors.white54),
                                        const SizedBox(width: 4),
                                        Text('${ad!.clicks} clics',
                                          style: const TextStyle(color: Colors.white54, fontSize: 11, decoration: TextDecoration.none)),
                                      ],
                                    ]),
                                  ],
                                  const SizedBox(height: 12),
                                  // Bouton CTA pub
                                  SizedBox(
                                    width: double.infinity,
                                    child: GestureDetector(
                                      onTap: () {
                                        if (ad != null) {
                                          _closeMidrollOverlay();
                                          final url = ad!.actionUrl ?? '';
                                          if (url.isNotEmpty) {
                                            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                          }
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)]),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(btnText, textAlign: TextAlign.center,
                                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, decoration: TextDecoration.none)),
                                      ),
                                    ),
                                  ),
                                ],
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
          ),
        ),
      ),
    );
  }

  Future<void> _recordPostView() async {
    final userId = authProvider.loginUserData.id;
    if (userId == null || _currentPost.id == null) return;

    // Garde permanente par appareil — une seule vue par utilisateur par post
    final prefKey = 'view_${_currentPost.id}_$userId';
    if (_prefs.getBool(prefKey) ?? false) return;
    await _prefs.setBool(prefKey, true);

    await _firestore.collection('Posts').doc(_currentPost.id).update({
      'vues': FieldValue.increment(1),
      'users_vue_id': FieldValue.arrayUnion([userId]),
    });
    setState(() {
      _currentPost.vues = (_currentPost.vues ?? 0) + 1;
      _currentPost.users_vue_id ??= [];
      if (!_currentPost.users_vue_id!.contains(userId)) _currentPost.users_vue_id!.add(userId);
    });
    PostViewService.recordAuthorView(_currentPost, userId);
  }

  // ==================== INTERACTIONS (inchangées) ====================
  Future<void> _toggleFavorite() async {
    if (_isProcessingFavorite) return;
    setState(() => _isProcessingFavorite = true);
    final userId = authProvider.loginUserData.id!;
    final postId = _currentPost.id!;
    try {
      if (_isFavorite) {
        await _firestore.collection('Posts').doc(postId).update({
          'users_favorite_id': FieldValue.arrayRemove([userId]),
          'favorites_count': FieldValue.increment(-1),
        });
        setState(() {
          _isFavorite = false;
          _currentPost.favoritesCount = (_currentPost.favoritesCount ?? 0) - 1;
        });
      } else {
        await _firestore.collection('Posts').doc(postId).update({
          'users_favorite_id': FieldValue.arrayUnion([userId]),
          'favorites_count': FieldValue.increment(1),
        });
        setState(() {
          _isFavorite = true;
          _currentPost.favoritesCount = (_currentPost.favoritesCount ?? 0) + 1;
        });
        await authProvider.sendNotification(
          userIds: [_currentPost.user?.oneIgnalUserid ?? ''],
          smallImage: authProvider.loginUserData.imageUrl!,
          send_user_id: userId,
          recever_user_id: _currentPost.user_id!,
          message: "❤️ @${authProvider.loginUserData.pseudo} a ajouté votre vidéo à ses favoris",
          type_notif: NotificationType.FAVORITE.name,
          post_id: postId,
          post_type: PostDataType.VIDEO.name,
          chat_id: '',
        );
      }
    } catch (e) {
      printVm('Erreur favori: $e');
    } finally {
      setState(() => _isProcessingFavorite = false);
    }
  }
  Future<void> _handleLike() async {
    if (_isLiking) return;
    final userId = authProvider.loginUserData.id;
    if (userId == null) return;

    final alreadyLiked = _currentPost.users_love_id?.contains(userId) ?? false;

    setState(() {
      _isLiking = true;
      _currentPost.loves = ((_currentPost.loves ?? 0) + (alreadyLiked ? -1 : 1)).clamp(0, double.maxFinite.toInt());
      _currentPost.users_love_id ??= [];
      if (alreadyLiked) {
        _currentPost.users_love_id!.remove(userId);
      } else {
        _currentPost.users_love_id!.add(userId);
      }
    });
    // Déverrouiller immédiatement — le reste s'exécute en arrière-plan
    setState(() => _isLiking = false);

    if (alreadyLiked) {
      _firestore.collection('Posts').doc(_currentPost.id).update({
        'loves': FieldValue.increment(-1),
        'users_love_id': FieldValue.arrayRemove([userId]),
        'popularity': FieldValue.increment(-1),
      }).catchError((_) {
        if (mounted) setState(() {
          _currentPost.loves = ((_currentPost.loves ?? 0) + 1);
          _currentPost.users_love_id?.add(userId);
        });
      });
    } else {
      _processLikeBackground(userId, alreadyLiked);
    }
  }

  void _processLikeBackground(String userId, bool alreadyLiked) {
    final coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);
    coinProvider.sendLikeWithCoins(
      senderId: userId,
      receiverId: _currentPost.user_id!,
      post: _currentPost,
      context: context,
    ).then((success) async {
      if (!mounted) return;
      if (!success) {
        // Pas de pièces : compter quand même le like dans Firestore
        _firestore.collection('Posts').doc(_currentPost.id).update({
          'loves': FieldValue.increment(1),
          'users_love_id': FieldValue.arrayUnion([userId]),
          'popularity': FieldValue.increment(1),
        });
        _showInsufficientCoinsForLikeDialog();
        return;
      }
      // Succès pièces : popularité + notifications
      if (!alreadyLiked) {
        try {
          await _firestore.collection('Posts').doc(_currentPost.id).update({
            'popularity': FieldValue.increment(3),
          });
          addPointsForAction(UserAction.like);
          addPointsForOtherUserAction(_currentPost.user_id!, UserAction.autre);
          final nowMicro = DateTime.now().microsecondsSinceEpoch;
          final userDoc = await _firestore.collection('Users').doc(_currentPost.user_id).get();
          final lastNotif = userDoc.data()?['lastNotificationTime'] ?? 0;
          if (nowMicro - lastNotif >= 20 * 60 * 1000000) {
            await authProvider.sendNotification(
              userIds: [_currentPost.user?.oneIgnalUserid ?? ''],
              smallImage: authProvider.loginUserData.imageUrl ?? '',
              send_user_id: userId,
              recever_user_id: _currentPost.user_id!,
              message: "📢 @${authProvider.loginUserData.pseudo} a aimé votre vidéo et vous a offert 1 pièce !",
              type_notif: NotificationType.POST.name,
              post_id: _currentPost.id!,
              post_type: PostDataType.VIDEO.name,
              chat_id: '',
            );
            await _firestore.collection('Users').doc(_currentPost.user_id).update({
              'lastNotificationTime': nowMicro,
            });
          }
        } catch (e) {
          printVm("❌ Erreur post-like vidéo: $e");
        }
      }
    }).catchError((e) {
      printVm("❌ Erreur like background: $e");
    });
  }
  void _showInsufficientCoinsForLikeDialog() {
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
                      'Le like coûte 2 pièces :\n• Pour soutenir le créateur',
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
  void _showCommentsModal() {
    showResponsiveBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(color: AppColors.of(context).background, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          children: [
            Container(padding: EdgeInsets.all(16), child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text('Commentaires', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), IconButton(icon: Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context))],
            )),
            Expanded(child: PostComments(post: _currentPost)),
          ],
        ),
      ),
    );
  }

  Widget _buildAdBanner({required String key}) {
    return AfrolookInlineAd(key: ValueKey(key));
  }

  Widget _buildAdNative({required String key}) {
    return AfrolookInlineAd(key: ValueKey(key));
  }

  void _sharePost(Post post) async {
    setState(() => _isSharing = true);
    try {
      final shareUrl = post.thumbnail ?? post.images?.first ?? '';
      final appLink = AppLinkService();
      await appLink.shareContent(type: AppLinkType.post, id: post.id!, message: post.description ?? '', mediaUrl: shareUrl);
      await _firestore.collection('Posts').doc(post.id).update({'partage': FieldValue.increment(1), 'users_partage_id': FieldValue.arrayUnion([authProvider.loginUserData.id!])});
      setState(() => post.partage = (post.partage ?? 0) + 1);
      addPointsForAction(UserAction.partagePost);
    } catch (e) {
      printVm('Erreur partage: $e');
    } finally {
      setState(() => _isSharing = false);
    }
  }

  void _showShareOptions(Post post) {
    final colors = AppColors.of(context);
    showResponsiveBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: colors.border, borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: Icon(Icons.share, color: colors.info),
              title: Text('Partager', style: TextStyle(color: colors.textPrimary)),
              onTap: () { Navigator.pop(ctx); _sharePost(post); },
            ),
            ListTile(
              leading: Icon(Icons.send_rounded, color: colors.primary),
              title: Text('Envoyer dans un chat',
                  style: TextStyle(color: colors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                showResponsiveBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => PostShareSheet(post: post),
                );
              },
            ),
            Divider(color: colors.divider),
            ListTile(
              leading: Icon(Icons.cancel, color: colors.textSecondary),
              title: Text('Annuler', style: TextStyle(color: colors.textPrimary)),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _showGiftDialog(Post post) {
    _handleGift(post);
  }
  void _handleGift(Post post) {
    showDialog(
      context: context,
      builder: (context) => CoinGiftDialog(
        receiverId: post.user_id!,
        receiverName: post.user?.pseudo ?? 'Créateur',
        receiverAvatar: post.user?.imageUrl ?? '',
        post: post,
        onGiftSuccess: () async {
          // Mettre à jour l'affichage local du compteur de cadeaux
          setState(() {
            post.users_cadeau_id ??= [];
            if (!post.users_cadeau_id!.contains(authProvider.loginUserData.id!)) {
              post.users_cadeau_id!.add(authProvider.loginUserData.id!);
            }
          });

          // Rafraîchir le provider pour mettre à jour le solde
          final coinProvider = Provider.of<CoinGiftUserProvider>(context, listen: false);
          await coinProvider.refreshBalance(authProvider.loginUserData.id!);

          // Afficher un snackbar de confirmation
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎁 Cadeau envoyé avec succès !'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );

          // 🔥 Appeler le callback parent si existant
          // widget.onGiftSuccess?.call();
        },
      ),
    );
  }
  void _showGiftDialog2() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setStateDialog) {
        return Dialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.yellow, width: 2)),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Text('Envoyer un Cadeau', style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 20)),
                SizedBox(height: 12),
                Text('Choisissez le montant en FCFA', style: TextStyle(color: Colors.white)),
                SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.8),
                    itemCount: giftPrices.length,
                    itemBuilder: (context, index) => GestureDetector(
                      onTap: () => setStateDialog(() => _selectedGiftIndex = index),
                      child: Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(color: _selectedGiftIndex == index ? Colors.green : Colors.grey[800], borderRadius: BorderRadius.circular(10), border: Border.all(color: _selectedGiftIndex == index ? Colors.yellow : Colors.transparent)),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(giftIcons[index], style: TextStyle(fontSize: 24)), Text('${giftPrices[index].toInt()} FCFA', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold))]),
                      ),
                    ),
                  ),
                ),
                Text('Votre solde: ${authProvider.loginUserData.votre_solde_principal?.toInt() ?? 0} FCFA', style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold)),
                SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: Colors.white))),
                  ElevatedButton(onPressed: () { Navigator.pop(context); _sendGift(giftPrices[_selectedGiftIndex]); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: Text('Envoyer', style: TextStyle(color: Colors.black))),
                ]),
              ],
            ),
          ),
        );
      }),
    );
  }

  Future<void> _sendGift(double amount) async {
    setState(() => _isLoadingGift = true);
    try {
      final senderBalance = authProvider.loginUserData.votre_solde_principal ?? 0;
      if (senderBalance < amount) { _showInsufficientBalanceDialog(); return; }
      final gainDest = amount * 0.7;
      final gainApp = amount * 0.3;
      await _firestore.collection('Users').doc(authProvider.loginUserData.id).update({'votre_solde_principal': FieldValue.increment(-amount)});
      await _firestore.collection('Users').doc(_currentPost.user_id).update({'votre_solde_principal': FieldValue.increment(gainDest)});
      await _firestore.collection('AppData').doc(authProvider.appDefaultData.id).update({'solde_gain': FieldValue.increment(gainApp)});
      await _firestore.collection('Posts').doc(_currentPost.id).update({'users_cadeau_id': FieldValue.arrayUnion([authProvider.loginUserData.id])});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('🎁 Cadeau envoyé avec succès!'), backgroundColor: Colors.green));
    } catch (e) {
      printVm('Erreur envoi cadeau: $e');
    } finally {
      setState(() => _isLoadingGift = false);
    }
  }

  void _showInsufficientBalanceDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.yellow, width: 2)),
      title: Text('Solde Insuffisant', style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold)),
      content: Text('Votre solde est insuffisant. Veuillez recharger.', style: TextStyle(color: Colors.white)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler', style: TextStyle(color: Colors.white))),
        ElevatedButton(onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => DepositScreen())); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: Text('Recharger', style: TextStyle(color: Colors.black))),
      ],
    ));
  }

  void _showPostMenu() {
    final colors = AppColors.of(context);
    showResponsiveBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        final sheetColors = AppColors.of(context);
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_currentPost.user_id != authProvider.loginUserData.id)
              _buildMenuOption(Icons.flag, 'Signaler', sheetColors.textPrimary, () async {
                _currentPost.status = PostStatus.SIGNALER.name;
                await postProvider.updateVuePost(_currentPost, context);
                Navigator.pop(context);
              }),
            if (_currentPost.user_id == authProvider.loginUserData.id || authProvider.loginUserData.role == UserRole.ADM.name)
              _buildMenuOption(Icons.delete, 'Supprimer', Colors.red, () {
                Navigator.pop(context);
                _confirmAndDeletePost();
              }),
            SizedBox(height: 8),
            Container(height: 0.5, color: sheetColors.border),
            SizedBox(height: 8),
            _buildMenuOption(Icons.cancel, 'Annuler', sheetColors.textSecondary, () => Navigator.pop(context)),
          ]),
        );
      },
    );
  }

  Widget _buildMenuOption(IconData icon, String text, Color color, VoidCallback onTap) {
    return InkWell(onTap: onTap, child: Container(padding: EdgeInsets.symmetric(vertical: 12), child: Row(children: [Icon(icon, color: color, size: 20), SizedBox(width: 12), Text(text, style: TextStyle(color: color, fontSize: 16))])));
  }

  // ==================== SUGGESTIONS — style YouTube plein-écran ====================
  Widget _buildSuggestedVideos() {
    final colors = AppColors.of(context);
    final suggestions = getFilteredSuggestions();
    final isLoading = postProvider.isLoadingSuggestions;

    if (isLoading && suggestions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: CircularProgressIndicator(color: colors.accent),
        ),
      );
    }

    if (suggestions.isEmpty) return const SizedBox.shrink();

    // Construire la liste mixte : pub avant chaque groupe de 3 posts
    // Structure : [pub, p0, p1, p2, pub, p3, p4, p5, pub, ...]
    final items = <dynamic>[];
    for (int i = 0; i < suggestions.length; i++) {
      if (i % 3 == 0) items.add('ad_$i');
      items.add(suggestions[i]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Suggestions',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            if (item is String) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _buildAdBanner(key: 'ad_suggestion_$index'),
              );
            }
            final post = item as Post;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildYouTubeCard(post),
            );
          },
        ),
      ],
    );
  }

  // Les autres widgets (video player, header, etc.) restent strictement identiques à l'original
  Widget _buildVideoPlayer() {
    // Sur Flutter Web : lecteur HTML natif (contourne video_player_web)
    if (kIsWeb) {
      final url = _currentPost.url_media;
      if (url == null || url.isEmpty) {
        return Container(
          color: AppColors.of(context).background,
          height: MediaQuery.of(context).size.width * 9 / 16,
          child: const Center(child: Icon(Icons.play_circle_outline, color: Colors.white54, size: 48)),
        );
      }
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: SmartVideoPlayer(url: url, autoPlay: true, progressColor: _afroGreen),
      );
    }
    if (!_isVideoInitialized || _chewieController == null) {
      return Container(
        color: AppColors.of(context).background,
        height: MediaQuery.of(context).size.width * 9 / 16,
        child: Center(child: CircularProgressIndicator(color: _afroGreen)),
      );
    }
    final isLiked = _currentPost.users_love_id?.contains(authProvider.loginUserData.id) ?? false;
    return Stack(
      children: [
        DoubleTapLike(
          alreadyLiked: isLiked,
          onDoubleTap: _handleLike,
          child: AspectRatio(aspectRatio: 16 / 9, child: Chewie(controller: _chewieController!)),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: _buildPostTypeBadge(_currentPost),
        ),
      ],
    );
  }

  Widget _buildUserHeader() {
    final canal = _currentPost.canal ?? _currentCanal;
    final user = _currentPost.user ?? _currentUser;
    final isLocked = _isLockedContent();
    final colors = AppColors.of(context);
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            if (canal != null) Navigator.push(context, MaterialPageRoute(builder: (context) => CanalDetails(canal: canal)));
            else if (user != null) showUserDetailsModalDialog(user, MediaQuery.of(context).size.width, MediaQuery.of(context).size.height, context);
          },
          child: CircleAvatar(radius: 25, backgroundImage: NetworkImage(canal?.urlImage ?? user?.imageUrl ?? ''), backgroundColor: colors.surface),
        ),
        SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (canal != null) Navigator.push(context, MaterialPageRoute(builder: (context) => CanalDetails(canal: canal)));
              else if (user != null) showUserDetailsModalDialog(user, MediaQuery.of(context).size.width, MediaQuery.of(context).size.height, context);
            },
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(canal != null ? '#${canal.titre}' : '@${user?.pseudo ?? ''}', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                if (user != null) UserBadgeWidget(user: user, size: 15),
                if (isLocked) Icon(Icons.lock, color: _afroYellow, size: 16),
                if ((_currentPost.typeTabbar ?? '').isNotEmpty) _buildTabbarBadge(_currentPost.typeTabbar!),
              ]),
              Text(canal != null ? '${canal?.usersSuiviId?.length ?? 0} abonnés' : '${user?.userAbonnesIds?.length ?? 0} abonnés', style: TextStyle(color: Colors.grey)),
            ]),
          ),
        ),
        IconButton(
          icon: Icon(Icons.more_vert, color: colors.textPrimary),
          onPressed: _showPostMenu,
        ),
      ],
    );
  }

  bool _isLockedContent() {
    final canal = _currentPost.canal ?? _currentCanal;
    if (canal == null) return false;
    final isPrivate = canal.isPrivate == true;
    final isSubscribed = canal.usersSuiviId?.contains(authProvider.loginUserData.id) ?? false;
    final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;
    final isOwner = authProvider.loginUserData.id == _currentPost.user_id;
    return isPrivate && !isSubscribed && !isAdmin && !isOwner;
  }

  Widget _buildLockedOverlay() {
    final canal = _currentPost.canal ?? _currentCanal;
    final isPrivate = canal?.isPrivate == true;
    final price = canal?.subscriptionPrice ?? 0;
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.lock, color: _afroYellow, size: 60),
            SizedBox(height: 16),
            Text('Contenu verrouillé', style: TextStyle(color: _afroYellow, fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(isPrivate ? 'Ce contenu est réservé aux abonnés du canal.' : 'Abonnez-vous pour accéder à cette vidéo.', style: TextStyle(color: Colors.white), textAlign: TextAlign.center),
            SizedBox(height: 20),
            ElevatedButton(onPressed: () { if (canal != null) Navigator.push(context, MaterialPageRoute(builder: (context) => CanalDetails(canal: canal))); },
              style: ElevatedButton.styleFrom(backgroundColor: _afroYellow, foregroundColor: Colors.black, padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              child: Text(isPrivate ? 'S\'ABONNER - ${price.toInt()} FCFA' : 'SUIVRE LE CANAL', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
      ),
    );
  }


  Widget _buildStatItem(IconData icon, int count, String label) {
    final colors = AppColors.of(context);
    return Column(children: [
      Icon(icon, color: _afroYellow, size: 24),
      SizedBox(height: 4),
      Text(_formatCount(count), style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
      Text(label, style: TextStyle(color: colors.textSecondary, fontSize: 12)),
    ]);
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  Future<void> _loadLastComment() async {
    final postId = _currentPost.id;
    if (postId == null) return;
    try {
      final snap = await _firestore
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
  }

  Future<void> _confirmAndDeletePost() async {
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
          Text('Supprimer la vidéo', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        ]),
        content: Text(
          'Cette vidéo sera supprimée définitivement. Cette action est irréversible.',
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
      await _firestore.collection('Posts').doc(_currentPost.id).delete();
      if (!mounted) return;
      Navigator.pop(context); // loader
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle, color: Colors.white),
          SizedBox(width: 10),
          Text('Vidéo supprimée avec succès'),
        ]),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 3),
      ));
      Navigator.pop(context); // retour page précédente
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

  void _autoLikeIfNeeded(String userId) {
    final postId = _currentPost.id;
    if (postId == null) return;
    final alreadyLiked = _currentPost.users_love_id?.contains(userId) ?? false;
    if (alreadyLiked) return;
    FirebaseFirestore.instance.collection('Posts').doc(postId).update({
      'loves': FieldValue.increment(1),
      'users_love_id': FieldValue.arrayUnion([userId]),
    }).catchError((_) {});
    if (mounted) setState(() {
      _currentPost.users_love_id ??= [];
      _currentPost.users_love_id!.add(userId);
      _currentPost.loves = (_currentPost.loves ?? 0) + 1;
    });
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
        post_id: _currentPost.id,
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

      if (success && mounted) {
        setState(() {
          _preloadedComments.insert(0, comment);
          _currentPost.comments = (_currentPost.comments ?? 0) + 1;
        });
        authProvider.incrementPostTotalInteractions(
          postId: _currentPost.id!,
          userId: userId,
          interactionType: 'comment',
        );
        try {
          await StreakService.onCommentSent(
            userId: userId,
            postId: _currentPost.id!,
          );
        } catch (e) {
          debugPrint('[Streak] erreur onCommentSent: $e');
        }
        authProvider.notifySubscribersOfInteraction(
          actionUserId: userId,
          postOwnerId: _currentPost.user_id!,
          postId: _currentPost.id!,
          actionType: 'comment',
          commentaireMessage: trimmed,
          postDescription: _currentPost.description,
          postImageUrl: _currentPost.thumbnail ?? _currentPost.user?.imageUrl ?? '',
          postDataType: _currentPost.dataType,
        );
        _autoLikeIfNeeded(userId);
        FeedInteractionService.onPostCommented(_currentPost, userId);

        if (_currentPost.user != null && _currentPost.user!.id != userId) {
          try {
            final msg = "@${authProvider.loginUserData.pseudo!} a commenté votre vidéo";
            final notif = NotificationData(
              id: FirebaseFirestore.instance.collection('Notifications').doc().id,
              titre: "Nouvelle interaction",
              media_url: authProvider.loginUserData.imageUrl,
              type: NotificationType.POST.name,
              description: msg,
              user_id: userId,
              receiver_id: _currentPost.user!.id!,
              post_id: _currentPost.id!,
              post_data_type: PostDataType.COMMENT.name,
              createdAt: DateTime.now().microsecondsSinceEpoch,
              updatedAt: DateTime.now().microsecondsSinceEpoch,
              status: PostStatus.VALIDE.name,
            );
            await FirebaseFirestore.instance.collection('Notifications').doc(notif.id).set(notif.toJson());
            final receiverUser = await authProvider.getUserById(_currentPost.user!.id!);
            if (receiverUser.isNotEmpty && receiverUser.first.oneIgnalUserid != null) {
              await authProvider.sendNotification(
                userIds: [receiverUser.first.oneIgnalUserid!],
                smallImage: authProvider.loginUserData.imageUrl!,
                send_user_id: userId,
                recever_user_id: _currentPost.user!.id!,
                message: msg,
                type_notif: NotificationType.POST.name,
                post_id: _currentPost.id!,
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

  Widget _buildCommentPreview(bool hasAccess) {
    if (!hasAccess) return const SizedBox.shrink();
    final colors = AppColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 5),
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
                    onSubmitted: _sendQuickComment,
                    style: TextStyle(fontSize: 12, color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Ajouter un commentaire…',
                      hintStyle: TextStyle(color: colors.textSecondary.withOpacity(0.55), fontSize: 12),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      isDense: true,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _sendQuickComment(_quickCommentController.text),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _isSendingQuickComment
                        ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: colors.primary))
                        : Icon(Icons.send_outlined, size: 14, color: colors.textSecondary.withOpacity(0.6)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    final isLiked = _currentPost.users_love_id?.contains(authProvider.loginUserData.id) ?? false;
    final hasAccess = !_isLockedContent();
    final isOwner = authProvider.loginUserData.id == _currentPost.user_id;
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      GestureDetector(
        onTap: (hasAccess && !_isLiking) ? _handleLike : null,
        child: _isLiking
            ? Column(children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFFD600)),
                ),
                const SizedBox(height: 4),
                Text(_formatCount(_currentPost.loves ?? 0), style: TextStyle(color: AppColors.of(context).textPrimary, fontWeight: FontWeight.bold)),
                Text('J\'aime', style: TextStyle(color: AppColors.of(context).textSecondary, fontSize: 12)),
              ])
            : _buildStatItem(
                isLiked ? Icons.favorite : Icons.favorite_border,
                _currentPost.loves ?? 0,
                'J\'aime',
              ),
      ),
      GestureDetector(
        onTap: hasAccess ? _showCommentsModal : null,
        child: _buildStatItem(Icons.chat_bubble_outline, _currentPost.comments ?? 0, 'Commentaires'),
      ),
      GestureDetector(
        onTap: hasAccess ? _toggleFavorite : null,
        child: _buildStatItem(
          _isFavorite ? Icons.bookmark : Icons.bookmark_border,
          _currentPost.favoritesCount ?? 0,
          'Favoris',
        ),
      ),
      if (isOwner || !hasAccess)
        _buildStatItem(Icons.card_giftcard, _currentPost.totalGiftCoinsSentOnThisPost ?? 0, 'Cadeaux')
      else
        QuickGiftBar(
          receiverId: _currentPost.user_id!,
          receiverName: _currentPost.user?.pseudo ?? 'Créateur',
          receiverAvatar: _currentPost.user?.imageUrl ?? '',
          post: _currentPost,
          giftCount: _currentPost.totalGiftCoinsSentOnThisPost ?? 0,
        ),
      _isSharing
          ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2))
          : GestureDetector(
              onTap: hasAccess ? () => _showShareOptions(_currentPost) : null,
              child: _buildStatItem(Icons.share, _currentPost.partage ?? 0, 'Partage'),
            ),
    ]);
  }

  Widget _buildChallengeSection() {
    if (!_isLookChallenge || _challenge == null) return SizedBox.shrink();
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.of(context).surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _afroGreen)),
      child: Column(children: [
        Row(children: [Icon(Icons.emoji_events, color: _afroGreen), SizedBox(width: 8), Text('LOOK CHALLENGE', style: TextStyle(color: _afroGreen, fontWeight: FontWeight.bold))]),
        SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${_currentPost.votesChallenge ?? 0} votes', style: TextStyle(color: AppColors.of(context).textPrimary)),
          if (!_hasVoted && _challenge!.isEnCours)
            ElevatedButton(onPressed: _isVoting ? null : _showVoteConfirmationDialog, style: ElevatedButton.styleFrom(backgroundColor: _afroGreen), child: _isVoting ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text('VOTER', style: TextStyle(color: Colors.white))),
          if (_hasVoted) Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: _afroGreen.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Text('DÉJÀ VOTÉ', style: TextStyle(color: _afroGreen, fontSize: 12, fontWeight: FontWeight.bold))),
        ]),
      ]),
    );
  }

  void _showVoteConfirmationDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(
      backgroundColor: AppColors.of(context).surface,
      title: Text('Confirmer le vote', style: TextStyle(color: AppColors.of(context).textPrimary)),
      content: Text(_challenge!.voteGratuit! ? 'Voter pour ce look est gratuit.' : 'Ce vote vous coûtera ${_challenge!.prixVote} FCFA.', style: TextStyle(color: Colors.grey)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler')),
        ElevatedButton(onPressed: () async { Navigator.pop(context); await _voteForLook(); }, style: ElevatedButton.styleFrom(backgroundColor: _afroGreen), child: Text('VOTER')),
      ],
    ));
  }

  Future<void> _voteForLook() async {
    if (_hasVoted || _isVoting) return;
    setState(() => _isVoting = true);
    try {
      await _firestore.collection('Posts').doc(_currentPost.id).update({
        'votes_challenge': FieldValue.increment(1),
        'users_votes_ids': FieldValue.arrayUnion([authProvider.loginUserData.id!]),
      });
      setState(() {
        _hasVoted = true;
        _currentPost.votesChallenge = (_currentPost.votesChallenge ?? 0) + 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vote enregistré !'), backgroundColor: Colors.green));
    } catch (e) {
      printVm('Erreur vote: $e');
    } finally {
      setState(() => _isVoting = false);
    }
  }


  Future<void> _handleSupportAd() async {
    final userId = authProvider.loginUserData.id;
    if (userId == _currentPost.user_id) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vous ne pouvez pas soutenir votre propre post'), backgroundColor: Colors.orange)); return; }
    final hasSupported = await _hasSupportedToday();
    if (hasSupported) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vous avez déjà soutenu ce post aujourd\'hui'), backgroundColor: Colors.orange)); return; }
    if (_hasSeenSupportModal == false) { _showSupportModal(); return; }
    _startSupportAd();
  }

  Future<bool> _hasSupportedToday() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final end = start + Duration(days: 1).inMilliseconds;
    final query = await _firestore.collection('post_supports').where('postId', isEqualTo: _currentPost.id).where('userId', isEqualTo: authProvider.loginUserData.id).where('supportedAt', isGreaterThanOrEqualTo: start).where('supportedAt', isLessThan: end).get();
    return query.docs.isNotEmpty;
  }

  void _showSupportModal() {
    showDialog(context: context, builder: (context) => AlertDialog(
      backgroundColor: AppColors.of(context).surface,
      title: Row(children: [Icon(Icons.volunteer_activism, color: _afroYellow), Text('Soutenir le créateur', style: TextStyle(color: AppColors.of(context).textPrimary))]),
      content: Text('Regardez une publicité pour offrir 10 pièces au créateur.', style: TextStyle(color: AppColors.of(context).textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Plus tard')),
        ElevatedButton(onPressed: () async { Navigator.pop(context); await _markSupportModalSeen(); _startSupportAd(); }, style: ElevatedButton.styleFrom(backgroundColor: _afroYellow), child: Text('Regarder la pub', style: TextStyle(color: Colors.black))),
      ],
    ));
  }

  void _startSupportAd() {
    setState(() { _isSupporting = true; _showRewardedAd = true; });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_rewardedAdKey.currentState != null) {
        _rewardedAdKey.currentState!.showAd();
      } else {
        setState(() { _isSupporting = false; _showRewardedAd = false; });
      }
    });
  }

  Future<void> _onSupportAdRewarded() async {
    final userId = authProvider.loginUserData.id!;
    await _firestore.collection('Posts').doc(_currentPost.id).update({'adSupportCount': FieldValue.increment(1)});
    await _firestore.collection('Users').doc(_currentPost.user_id).update({'totalCoinsEarnedFromAdSupport': FieldValue.increment(1)});
    await _firestore.collection('post_supports').add({'postId': _currentPost.id, 'userId': userId, 'supportedAt': DateTime.now().millisecondsSinceEpoch});
    setState(() {
      _currentPost.adSupportCount = (_currentPost.adSupportCount ?? 0) + 1;
      _isSupporting = false;
      _showRewardedAd = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Merci ! Le créateur a reçu 1 pièce.'), backgroundColor: Colors.green));
  }
  Widget _buildAdvertisementHeader() {
    if (!_isAd || _advertisement == null) return const SizedBox.shrink();

    final ad = _advertisement!;
    final colors = AppColors.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD600).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD600), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Badge SPONSORISÉ
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD600),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, color: Colors.black, size: 14),
                    SizedBox(width: 4),
                    Text('SPONSORISÉ', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              // Bouton d'action
              InkWell(
                onTap: () async {
                  if (ad.actionUrl != null && ad.actionUrl!.isNotEmpty) {
                    final url = Uri.parse(ad.actionUrl!);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  }
                  _recordAdClick(ad, _currentPost);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE21221), Color(0xFFFF5252)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        ad.actionType == 'download' ? Icons.download
                            : ad.actionType == 'visit' ? Icons.language
                            : Icons.info,
                        color: Colors.white,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(ad.getActionButtonText().toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_forward, color: Colors.white, size: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Stats ligne
          Row(
            children: [
              Icon(Icons.visibility_outlined, size: 13, color: colors.textSecondary),
              const SizedBox(width: 3),
              Text('${ad.views} vues', style: TextStyle(color: colors.textSecondary, fontSize: 11)),
              const SizedBox(width: 12),
              Icon(Icons.touch_app_outlined, size: 13, color: colors.textSecondary),
              const SizedBox(width: 3),
              Text('${ad.clicks} clics', style: TextStyle(color: colors.textSecondary, fontSize: 11)),
              const SizedBox(width: 12),
              Icon(Icons.percent, size: 13, color: colors.accent),
              const SizedBox(width: 3),
              Text('CTR ${ad.ctr.toStringAsFixed(1)}%', style: TextStyle(color: colors.accent, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBoostSection() {
    final currentUserId = authProvider.loginUserData.id;
    final isOwner = currentUserId != null && currentUserId == _currentPost.user_id;
    if (!isOwner) return const SizedBox.shrink();
    if (_isAd) return const SizedBox.shrink(); // déjà affiché via _buildAdvertisementHeader

    final colors = AppColors.of(context);

    // Charger la pub existante si pas encore fait
    if (!_ownerAdLoaded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadOwnerAd());
    }

    if (_ownerAdForPost == null) {
      // Pas de pub existante → proposer de booster
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.rocket_launch_outlined, color: colors.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Booster ce post', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('Transformez ce post en publicité', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const SizedBox.shrink(), // remplacé à la session suivante par UserCreateAdvertisementPage(existingPost: _currentPost)
              )),
              style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: colors.onPrimary, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              child: const Text('Booster', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    // Pub existante → afficher statut
    final ad = _ownerAdForPost!;
    final statusLabel = {
      'pending': 'En attente',
      'active': 'Active',
      'expired': 'Expirée',
      'rejected': 'Rejetée',
      'cancelled': 'Annulée',
    }[ad.status] ?? ad.status ?? '';
    final statusColor = ad.status == 'active' ? colors.accent : ad.status == 'pending' ? colors.warning : colors.danger;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign_outlined, color: colors.primary, size: 20),
              const SizedBox(width: 8),
              Text('Publicité', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (ad.status == 'active') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.visibility_outlined, size: 13, color: colors.textSecondary),
                const SizedBox(width: 3),
                Text('${ad.views}', style: TextStyle(color: colors.textSecondary, fontSize: 11)),
                const SizedBox(width: 10),
                Icon(Icons.touch_app_outlined, size: 13, color: colors.textSecondary),
                const SizedBox(width: 3),
                Text('${ad.clicks}', style: TextStyle(color: colors.textSecondary, fontSize: 11)),
                const SizedBox(width: 10),
                Icon(Icons.percent, size: 13, color: colors.accent),
                const SizedBox(width: 3),
                Text('CTR ${ad.ctr.toStringAsFixed(1)}%', style: TextStyle(color: colors.accent, fontSize: 11)),
              ],
            ),
          ],
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final isLocked = _isLockedContent();
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(backgroundColor: colors.surface, elevation: 0, leading: IconButton(icon: Icon(Icons.arrow_back, color: _afroYellow), onPressed: () => Navigator.pop(context)), title: Text('Afrolook Vidéo', style: TextStyle(color: _afroGreen, fontWeight: FontWeight.bold))),
      body: Stack(
        children: [
          CenteredContent(
            maxWidth: AppLayout.isDesktop(context) ? 800 : AppLayout.maxFeedWidth,
            child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Lecteur vidéo
              isLocked ? Container(height: MediaQuery.of(context).size.width * 9 / 16, child: _buildLockedOverlay()) : _buildVideoPlayer(),
              // Badges Tier + Pays
              _PostDetailBadgesRow(post: _currentPost, feedTier: widget.feedTier),
              // Informations
              // Badge SPONSORISÉ si publicité
              if (_currentPost.isAdvertisement == true)
                _buildAdvertisementHeader(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _buildBoostSection(),
              ),
              Padding(padding: EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildUserHeader(),
                SizedBox(height: 12),
                if (_currentPost.description != null && _currentPost.description!.isNotEmpty)
                  _buildExpandableDescription(
                    _translatedDescriptions[_currentPost.id] ?? _currentPost.description!,
                  ),
                SizedBox(height: 12),
                _buildCommentPreview(!_isLockedContent()),
                SizedBox(height: 4),
                _buildActionButtons(),
                SizedBox(height: 8),
                PostGiftsList(
                  postId: _currentPost.id!,
                  compactLevel: CompactLevel.light,
                  maxDisplayItems: 10,
                ),
                _buildChallengeSection(),
                _buildSuggestedVideos(),
                SizedBox(height: 20),
              ])),
            ]),
          ),
          ),  // CenteredContent
          if (_showRewardedAd) RewardedAdWidget(key: _rewardedAdKey, onUserEarnedReward: (amount, name)  => _onSupportAdRewarded(), onAdDismissed: () => setState(() { _showRewardedAd = false; _isSupporting = false; }), child: SizedBox.shrink()),
          if (_showMidrollAd && !_isUserPremium()) _buildMidrollCard(),
        ],
      ),
    );
  }

  Widget _buildTabbarBadge(String typeTabbar) {
    final Map<String, _VideoTabbarMeta> meta = {
      'SPORT':      _VideoTabbarMeta('⚽', 'Sport',      const Color(0xFF2196F3)),
      'LOOKS':      _VideoTabbarMeta('👗', 'Looks',      const Color(0xFFE91E63)),
      'ACTUALITES': _VideoTabbarMeta('📰', 'Actus',      const Color(0xFF607D8B)),
      'EVENEMENT':  _VideoTabbarMeta('🎉', 'Événement',  const Color(0xFFFF9800)),
      'OFFRES':     _VideoTabbarMeta('🛍️', 'Offres',    const Color(0xFF4CAF50)),
      'GAMER':      _VideoTabbarMeta('🎮', 'Gamer',      const Color(0xFF9C27B0)),
    };
    final m = meta[typeTabbar.toUpperCase()];
    if (m == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: m.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: m.color),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(m.emoji, style: const TextStyle(fontSize: 9)),
        const SizedBox(width: 3),
        Text(m.label, style: TextStyle(color: m.color, fontSize: 9, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

// ── Badges Tier + Pays pour les pages de détail ──────────────────────────────
class _PostDetailBadgesRow extends StatelessWidget {
  final Post post;
  final String? feedTier;
  const _PostDetailBadgesRow({required this.post, this.feedTier});

  String _flagEmoji(String code) => code.toUpperCase().codeUnits
      .map((c) => String.fromCharCode(c + 127397))
      .join();

  @override
  Widget build(BuildContext context) {
    final tierLabel = switch (feedTier) {
      'tier1' => ('Nouveau · Abonnement', const Color(0xFF25D366)),
      'tier2' => ('Découverte · Intérêts', const Color(0xFF6C63FF)),
      'tier3' => ('Tendance', const Color(0xFF9E9E9E)),
      _ => null,
    };

    final countries = post.availableCountries;
    final isAll = countries.contains('ALL') || countries.isEmpty;
    String flagText;
    String countryLabel;
    if (isAll) {
      flagText = '🌍';
      countryLabel = 'Tous';
    } else {
      final code = countries.first.toUpperCase();
      final found = AfricanCountry.allCountries.where((c) => c.code.toUpperCase() == code).toList();
      flagText = found.isNotEmpty ? found.first.flag : '🏳️';
      countryLabel = countries.length == 1 ? code : '+${countries.length - 1}';
    }

    if (tierLabel == null && isAll) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          if (tierLabel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: tierLabel.$2.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: tierLabel.$2.withOpacity(0.35)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle, color: tierLabel.$2, size: 6),
                const SizedBox(width: 5),
                Text(tierLabel.$1, style: TextStyle(color: tierLabel.$2, fontSize: 10.5, fontWeight: FontWeight.w700)),
              ]),
            ),
          if (!isAll)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE74C3C).withOpacity(0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(flagText, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 5),
                Text(countryLabel, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600)),
              ]),
            ),
        ],
      ),
    );
  }
}

class _VideoTabbarMeta {
  final String emoji;
  final String label;
  final Color color;
  const _VideoTabbarMeta(this.emoji, this.label, this.color);
}

