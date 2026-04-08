import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:afrotok/pages/paiement/newDepot.dart';
import 'package:afrotok/pages/postDetails.dart';
import 'package:afrotok/pages/post_video_format_tel_details.dart';
import 'package:afrotok/pages/pub/banner_ad_widget.dart';
import 'package:afrotok/pages/pub/native_ad_widget.dart';
import 'package:afrotok/pages/pub/rewarded_ad_widget.dart';
import 'package:afrotok/pages/widgetGlobal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';

import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:afrotok/pages/postComments.dart';
import 'package:afrotok/services/linkService.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'canaux/detailsCanal.dart';
import 'home/homeWidget.dart';

// Couleurs Afrolook
const _afroBlack = Color(0xFF000000);
const _afroGreen = Color(0xFF2ECC71);
const _afroYellow = Color(0xFFF1C40F);
const _afroRed = Color(0xFFE74C3C);
const _afroDarkGrey = Color(0xFF16181C);
const _afroLightGrey = Color(0xFF71767B);

class VideoYoutubePageDetails extends StatefulWidget {
  final Post initialPost;
  final bool isIn;

  const VideoYoutubePageDetails({Key? key, required this.initialPost, this.isIn = false}) : super(key: key);

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
  // Streams de mise à jour
  StreamSubscription<DocumentSnapshot>? _postSubscription;

  bool get _isLookChallenge => _currentPost.type == 'CHALLENGEPARTICIPATION';




  @override
  void initState() {
    super.initState();


    _initSharedPreferences();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);
    _currentPost = widget.initialPost;
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

        Map<String, dynamic> updates = {
          'clicks': FieldValue.increment(1),
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

      print('✅ Clic enregistré pour la pub: ${ad.id}');
    } catch (e) {
      print('❌ Erreur clic: $e');
      _clickedInSession.remove(clickKey);
    }
  }
  // ==================== GÉNÉRATION DE MINIATURE ====================
  Future<void> _ensureThumbnailForPost(Post post) async {
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
      final uploadTask = ref.putFile(File(thumbnailFile));
      final snapshot = await uploadTask;
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
      print('Erreur génération miniature pour post ${post.id}: $e');
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
        setState(() {
          _advertisement = Advertisement.fromJson(adDoc.data()!);
        });
      }
    } catch (e) {
      print('Erreur chargement publicité: $e');
    } finally {
      setState(() => _isLoadingAd = false);
    }
  }
  // ==================== SUGGESTIONS ====================
// Nouvelle méthode pour obtenir les suggestions filtrées (exclut le post courant)
  List<Post> getFilteredSuggestions() {
    final allSuggestions = postProvider.suggestedPosts;
    // Exclure le post actuel
    return allSuggestions.where((p) => p.id != widget.initialPost.id).toList();
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
      widget.initialPost.users_vue_id ??= [];
      if (widget.initialPost.users_vue_id!.contains(currentUserId)) {
        print('⏭️ Vue déjà enregistrée pour cet utilisateur');
        return;
      }
      setState(() {
        widget.initialPost.vues = (widget.initialPost.vues ?? 0) + 1;
        widget.initialPost.users_vue_id!.add(currentUserId);
      });
      await _firestore.collection('Posts').doc(widget.initialPost.id).update({
        'vues': FieldValue.increment(1),
        'users_vue_id': FieldValue.arrayUnion([currentUserId]),
        'popularity': FieldValue.increment(2),
      });
      print('✅ Vue unique enregistrée pour ${widget.initialPost.id}');
    } catch (e) {
      print("Erreur incrémentation vues: $e");
    }
  }

  @override
  void dispose() {
    _postSubscription?.cancel();
    _videoController?.dispose();
    _chewieController?.dispose();
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
      print('Erreur chargement relations: $e');
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
      print('Erreur vérification favori: $e');
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
      print('Erreur chargement challenge: $e');
    } finally {
      setState(() => _loadingChallenge = false);
    }
  }
  Widget _buildExpandableDescription(String text) {
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
          style: TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
          linkStyle: TextStyle(color: Colors.blue),
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
      print('Erreur vérification vote: $e');
    }
  }

  Future<void> _initializeVideo() async {
    if (_currentPost.url_media == null || _currentPost.url_media!.isEmpty) return;
    _videoController?.dispose();
    _chewieController?.dispose();
    try {
      _videoController = VideoPlayerController.network(_currentPost.url_media!);
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
        placeholder: Container(color: _afroBlack, child: Center(child: CircularProgressIndicator(color: _afroGreen))),
        autoInitialize: true,
      );
      setState(() => _isVideoInitialized = true);
      await _recordPostView();
    } catch (e) {
      print('Erreur initialisation vidéo: $e');
      setState(() => _isVideoInitialized = false);
    }
  }

  Future<void> _recordPostView() async {
    final userId = authProvider.loginUserData.id;
    if (userId == null || _currentPost.id == null) return;
    final today = DateTime.now().toIso8601String().split('T').first;
    final key = '${_lastViewDatePrefix}${userId}_${_currentPost.id}';
    final lastView = _prefs.getString(key);
    if (lastView == today) return;
    await _prefs.setString(key, today);
    await _firestore.collection('Posts').doc(_currentPost.id).update({
      'vues': FieldValue.increment(1),
      'users_vue_id': FieldValue.arrayUnion([userId]),
    });
    setState(() {
      _currentPost.vues = (_currentPost.vues ?? 0) + 1;
      _currentPost.users_vue_id ??= [];
      if (!_currentPost.users_vue_id!.contains(userId)) _currentPost.users_vue_id!.add(userId);
    });
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
      print('Erreur favori: $e');
    } finally {
      setState(() => _isProcessingFavorite = false);
    }
  }

  Future<void> _handleLike() async {
    final userId = authProvider.loginUserData.id!;
    if (_currentPost.users_love_id!.contains(userId)) return;
    await _firestore.collection('Posts').doc(_currentPost.id).update({
      'loves': FieldValue.increment(1),
      'users_love_id': FieldValue.arrayUnion([userId]),
    });
    setState(() {
      _currentPost.loves = (_currentPost.loves ?? 0) + 1;
      _currentPost.users_love_id!.add(userId);
    });
    addPointsForAction(UserAction.like);
    final nowMicro = DateTime.now().microsecondsSinceEpoch;
    final userDoc = await _firestore.collection('Users').doc(_currentPost.user_id).get();
    final lastNotif = userDoc.data()?['lastNotificationTime'] ?? 0;
    if (nowMicro - lastNotif >= 20 * 60 * 1000000) {
      await authProvider.sendNotification(
        userIds: [_currentPost.user?.oneIgnalUserid ?? ''],
        smallImage: authProvider.loginUserData.imageUrl!,
        send_user_id: userId,
        recever_user_id: _currentPost.user_id!,
        message: "📢 @${authProvider.loginUserData.pseudo} a aimé votre vidéo",
        type_notif: NotificationType.POST.name,
        post_id: _currentPost.id!,
        post_type: PostDataType.VIDEO.name,
        chat_id: '',
      );
      await _firestore.collection('Users').doc(_currentPost.user_id).update({'lastNotificationTime': nowMicro});
    }
  }

  void _showCommentsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(color: _afroBlack, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
    // return SizedBox.shrink();

    return Container(
      key: ValueKey(key),
      margin: EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent),
      ),
      child: NativeAdWidget(
        key: ValueKey(key),
        // templateType: TemplateType.medium, // ou TemplateType.small

        onAdLoaded: () {
          print('✅ Native Ad Afrolook chargée: $key');
          authProvider.incrementCreatorCoins(postId: widget.initialPost.id!, creatorId: widget.initialPost.user_id!, currentUserId:authProvider.loginUserData.id!);

        },
      ),
      // child: BannerAdWidget(
      //   onAdLoaded: () {
      //
      //     print('✅ Bannière Afrolook chargée: $key');
      //     authProvider.incrementCreatorCoins(widget.initialPost.user_id!);
      //   },
      // ),
    );
  }
  Widget _buildAdNative({required String key}) {
    // return SizedBox.shrink();

    return Container(
      key: ValueKey(key),
      margin: EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: NativeAdWidget(
        key: ValueKey(key),
        // templateType: TemplateType.small, // ou TemplateType.small

        onAdLoaded: () {
          print('✅ Native Ad Afrolook chargée: $key');
          authProvider.incrementCreatorCoins(postId: widget.initialPost.id!, creatorId: widget.initialPost.user_id!, currentUserId:authProvider.loginUserData.id!);

        },
      ),
      // child: BannerAdWidget(
      //   onAdLoaded: () {
      //     print('✅ Bannière Afrolook chargée: $key');
      //   },
      // ),
    );
  }


  void _sharePost() async {
    setState(() => _isSharing = true);
    try {
      final shareUrl = _currentPost.thumbnail ?? _currentPost.images?.first ?? '';
      final appLink = AppLinkService();
      await appLink.shareContent(type: AppLinkType.post, id: _currentPost.id!, message: _currentPost.description ?? '', mediaUrl: shareUrl);
      await _firestore.collection('Posts').doc(_currentPost.id).update({'partage': FieldValue.increment(1), 'users_partage_id': FieldValue.arrayUnion([authProvider.loginUserData.id!])});
      setState(() => _currentPost.partage = (_currentPost.partage ?? 0) + 1);
      addPointsForAction(UserAction.partagePost);
    } catch (e) {
      print('Erreur partage: $e');
    } finally {
      setState(() => _isSharing = false);
    }
  }

  void _showGiftDialog() {
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
      print('Erreur envoi cadeau: $e');
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
    showModalBottomSheet(
      context: context,
      backgroundColor: _afroDarkGrey,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_currentPost.user_id != authProvider.loginUserData.id)
            _buildMenuOption(Icons.flag, 'Signaler', Colors.white, () async {
              _currentPost.status = PostStatus.SIGNALER.name;
              await postProvider.updateVuePost(_currentPost, context);
              Navigator.pop(context);
            }),
          if (_currentPost.user_id == authProvider.loginUserData.id || authProvider.loginUserData.role == UserRole.ADM.name)
            _buildMenuOption(Icons.delete, 'Supprimer', Colors.red, () async {
              await _firestore.collection('Posts').doc(_currentPost.id).delete();
              Navigator.pop(context);
              Navigator.pop(context);
            }),
          SizedBox(height: 8),
          Container(height: 0.5, color: Colors.grey),
          SizedBox(height: 8),
          _buildMenuOption(Icons.cancel, 'Annuler', Colors.grey, () => Navigator.pop(context)),
        ]),
      ),
    );
  }

  Widget _buildMenuOption(IconData icon, String text, Color color, VoidCallback onTap) {
    return InkWell(onTap: onTap, child: Container(padding: EdgeInsets.symmetric(vertical: 12), child: Row(children: [Icon(icon, color: color, size: 20), SizedBox(width: 12), Text(text, style: TextStyle(color: color, fontSize: 16))])));
  }

  // ==================== WIDGETS (version modifiée pour suggestions avec indicateur) ====================
  Widget _buildSuggestedVideos() {
    final suggestions = getFilteredSuggestions();
    final isLoading = postProvider.isLoadingSuggestions;

    if (isLoading && suggestions.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: Colors.yellow),
        ),
      );
    }

    if (suggestions.isEmpty) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Suggestions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: suggestions.length + 1, // +1 pour la pub
          itemBuilder: (context, index) {
            if (index == 3) {
              return Column(
                children: [
                  Divider(color: Colors.grey[800]),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: _buildAdBanner(key: 'ad_suggestion_unique'),
                  ),
                  Divider(color: Colors.grey[800]),
                ],
              );
            }

            final int postIndex = index > 3 ? index - 1 : index;
            if (postIndex >= suggestions.length) return SizedBox.shrink();

            final post = suggestions[postIndex];
            final bool isLastItem = index == suggestions.length;

            return Column(
              children: [
                InkWell(
                  onTap: () => _onSuggestedPostSelected(post),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.grey[800],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Miniature (image ou vidéo)
                                  (post.dataType == PostDataType.VIDEO.name && post.thumbnail != null && post.thumbnail!.isNotEmpty)
                                      ? CachedNetworkImage(
                                    imageUrl: post.thumbnail!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Center(
                                      child: CircularProgressIndicator(color: Colors.yellow),
                                    ),
                                    errorWidget: (context, url, error) => Icon(Icons.video_library, color: Colors.grey, size: 40),
                                  )
                                      : (post.images != null && post.images!.isNotEmpty)
                                      ? CachedNetworkImage(
                                    imageUrl: post.images!.first,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Center(
                                      child: CircularProgressIndicator(color: Colors.yellow),
                                    ),
                                    errorWidget: (context, url, error) => Icon(Icons.image, color: Colors.grey, size: 40),
                                  )
                                      : Icon(Icons.image, color: Colors.grey, size: 40),

                                  // Badge vidéo (seulement si c'est une vidéo)
                                  if (post.dataType == PostDataType.VIDEO.name)
                                    Positioned(
                                      bottom: 8,
                                      right: 8,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.7),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.play_arrow, color: Colors.white, size: 14),
                                            SizedBox(width: 2),
                                            Text(
                                              'VIDEO',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            )
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.description ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white, fontSize: 14),
                              ),

                              SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.bar_chart, size: 12, color: Colors.blue),
                                  SizedBox(width: 4),
                                  Text(
                                    '${post.totalInteractions ?? 0}',
                                    style: TextStyle(color: Colors.grey[400], fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!isLastItem) Divider(color: Colors.grey[800]),
              ],
            );
          },
        ),
      ],
    );
  }

  // Les autres widgets (video player, header, etc.) restent strictement identiques à l'original
  Widget _buildVideoPlayer() {
    if (!_isVideoInitialized || _chewieController == null) {
      return Container(
        color: _afroBlack,
        height: MediaQuery.of(context).size.width * 9 / 16,
        child: Center(child: CircularProgressIndicator(color: _afroGreen)),
      );
    }
    return AspectRatio(aspectRatio: 16 / 9, child: Chewie(controller: _chewieController!));
  }

  Widget _buildUserHeader() {
    final canal = _currentPost.canal ?? _currentCanal;
    final user = _currentPost.user ?? _currentUser;
    final isLocked = _isLockedContent();
    return GestureDetector(
      onTap: () {
        if (canal != null) Navigator.push(context, MaterialPageRoute(builder: (context) => CanalDetails(canal: canal)));
        else if (user != null) showUserDetailsModalDialog(user, MediaQuery.of(context).size.width, MediaQuery.of(context).size.height, context);
      },
      child: Row(
        children: [
          CircleAvatar(radius: 25, backgroundImage: NetworkImage(canal?.urlImage ?? user?.imageUrl ?? ''), backgroundColor: _afroDarkGrey),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(canal != null ? '#${canal.titre}' : '@${user?.pseudo ?? ''}', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              if (canal?.isVerify == true || user?.isVerify == true) Icon(Icons.verified, color: Colors.blue, size: 16),
              if (isLocked) Icon(Icons.lock, color: _afroYellow, size: 16),
            ]),
            Text(canal != null ? '${canal?.usersSuiviId?.length ?? 0} abonnés' : '${user?.userAbonnesIds?.length ?? 0} abonnés', style: TextStyle(color: Colors.grey)),
          ])),
          IconButton(icon: Icon(Icons.more_vert, color: Colors.white), onPressed: _showPostMenu),
        ],
      ),
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

  Widget _buildStatsRow() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      _buildStatItem(Icons.remove_red_eye, _currentPost.vues ?? 0, 'Vues'),
      _buildStatItem(Icons.favorite, _currentPost.loves ?? 0, 'J\'aime'),
      _buildStatItem(Icons.chat_bubble, _currentPost.comments ?? 0, 'Commentaires'),
      _buildStatItem(Icons.bar_chart, _currentPost.totalInteractions ?? 0, 'Interactions'),
      _buildStatItem(_isFavorite ? Icons.bookmark : Icons.bookmark_border, _currentPost.favoritesCount ?? 0, 'Favoris'),
    ]);
  }

  Widget _buildStatItem(IconData icon, int count, String label) {
    return Column(children: [
      Icon(icon, color: _afroYellow, size: 24),
      SizedBox(height: 4),
      Text(_formatCount(count), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      Text(label, style: TextStyle(color: Colors.grey, fontSize: 12)),
    ]);
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  Widget _buildActionButtons() {
    final isLiked = _currentPost.users_love_id?.contains(authProvider.loginUserData.id) ?? false;
    final hasAccess = !_isLockedContent();
    return Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      IconButton(icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? _afroRed : Colors.white, size: 28), onPressed: hasAccess ? _handleLike : null),
      IconButton(icon: Icon(Icons.chat_bubble_outline, color: Colors.white, size: 28), onPressed: hasAccess ? _showCommentsModal : null),
      IconButton(icon: Icon(_isFavorite ? Icons.bookmark : Icons.bookmark_border, color: _isFavorite ? _afroYellow : Colors.white, size: 28), onPressed: hasAccess ? _toggleFavorite : null),
      IconButton(icon: Icon(Icons.card_giftcard, color: _afroYellow, size: 28), onPressed: hasAccess ? _showGiftDialog : null),
      _isSharing ? SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2)) : IconButton(icon: Icon(Icons.share, color: Colors.white, size: 28), onPressed: hasAccess ? _sharePost : null),
    ]);
  }

  Widget _buildChallengeSection() {
    if (!_isLookChallenge || _challenge == null) return SizedBox.shrink();
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(color: _afroDarkGrey, borderRadius: BorderRadius.circular(12), border: Border.all(color: _afroGreen)),
      child: Column(children: [
        Row(children: [Icon(Icons.emoji_events, color: _afroGreen), SizedBox(width: 8), Text('LOOK CHALLENGE', style: TextStyle(color: _afroGreen, fontWeight: FontWeight.bold))]),
        SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${_currentPost.votesChallenge ?? 0} votes', style: TextStyle(color: Colors.white)),
          if (!_hasVoted && _challenge!.isEnCours)
            ElevatedButton(onPressed: _isVoting ? null : _showVoteConfirmationDialog, style: ElevatedButton.styleFrom(backgroundColor: _afroGreen), child: _isVoting ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Text('VOTER', style: TextStyle(color: Colors.white))),
          if (_hasVoted) Container(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: _afroGreen.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Text('DÉJÀ VOTÉ', style: TextStyle(color: _afroGreen, fontSize: 12, fontWeight: FontWeight.bold))),
        ]),
      ]),
    );
  }

  void _showVoteConfirmationDialog() {
    showDialog(context: context, builder: (context) => AlertDialog(
      backgroundColor: _afroDarkGrey,
      title: Text('Confirmer le vote', style: TextStyle(color: Colors.white)),
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
      print('Erreur vote: $e');
    } finally {
      setState(() => _isVoting = false);
    }
  }

  Widget _buildSupportButton() {
    final isOwner = authProvider.loginUserData.id == _currentPost.user_id;
    if (isOwner) return SizedBox.shrink();
    final hasAccess = !_isLockedContent();
    if (!hasAccess) return SizedBox.shrink();
    return GestureDetector(
      onTap: _isSupporting ? null : _handleSupportAd,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: _afroDarkGrey, borderRadius: BorderRadius.circular(20), border: Border.all(color: _afroYellow.withOpacity(0.5))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _isSupporting ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.volunteer_activism, color: _afroYellow, size: 16),
          SizedBox(width: 6),
          Text('Soutenir le créateur', style: TextStyle(color: Colors.white, fontSize: 12)),
        ]),
      ),
    );
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
      backgroundColor: _afroDarkGrey,
      title: Row(children: [Icon(Icons.volunteer_activism, color: _afroYellow), Text('Soutenir le créateur', style: TextStyle(color: Colors.white))]),
      content: Text('Regardez une publicité pour offrir 10 pièces au créateur.', style: TextStyle(color: Colors.grey)),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD600).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD600), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Groupe badge + bouton d'action
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD600),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.verified, color: Colors.black, size: 14),
                const SizedBox(width: 4),
                const Text(
                  'SPONSORISÉ',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Bouton d'action (compact)
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
                    ad.actionType == 'download'
                        ? Icons.download
                        : ad.actionType == 'visit'
                        ? Icons.language
                        : Icons.info,
                    color: Colors.white,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ad.getActionButtonText().toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward, color: Colors.white, size: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final isLocked = _isLockedContent();
    return Scaffold(
      backgroundColor: _afroBlack,
      appBar: AppBar(backgroundColor: _afroBlack, elevation: 0, leading: IconButton(icon: Icon(Icons.arrow_back, color: _afroYellow), onPressed: () => Navigator.pop(context)), title: Text('Afrolook Vidéo', style: TextStyle(color: _afroGreen, fontWeight: FontWeight.bold))),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Lecteur vidéo
              isLocked ? Container(height: MediaQuery.of(context).size.width * 9 / 16, child: _buildLockedOverlay()) : _buildVideoPlayer(),
              // Informations
              // Badge SPONSORISÉ si publicité
              if (_currentPost.isAdvertisement == true)
                _buildAdvertisementHeader(),
              Padding(padding: EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildUserHeader(),
                SizedBox(height: 12),
                if (_currentPost.description != null && _currentPost.description!.isNotEmpty)
                  _buildExpandableDescription(_currentPost.description!),
                SizedBox(height: 12),
                _buildStatsRow(),
                SizedBox(height: 12),
                _buildActionButtons(),
                SizedBox(height: 8),
                _buildSupportButton(),
                _buildChallengeSection(),
                Divider(color: Colors.grey[800]),
                _buildAdBanner(key: 'ad_details_post'),

                _buildSuggestedVideos(),
                SizedBox(height: 20),
              ])),
            ]),
          ),
          if (_showRewardedAd) RewardedAdWidget(key: _rewardedAdKey, onUserEarnedReward: (amount, name)  => _onSupportAdRewarded(), onAdDismissed: () => setState(() { _showRewardedAd = false; _isSupporting = false; }), child: SizedBox.shrink()),
        ],
      ),
    );
  }
}




