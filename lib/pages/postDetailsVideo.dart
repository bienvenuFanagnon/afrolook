import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:afrotok/pages/paiement/newDepot.dart';
import 'package:afrotok/pages/pub/banner_ad_widget.dart';
import 'package:afrotok/pages/pub/native_ad_widget.dart';
import 'package:afrotok/pages/pub/rewarded_ad_widget.dart';
import 'package:afrotok/pages/widgetGlobal.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
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
    _loadSupportModalSeen();
    _loadPostRelations();
    _checkIfFavorite();
    if (_isLookChallenge && _currentPost.challenge_id != null) {
      _loadChallengeData();
    }
    _checkIfUserHasVoted();
    _loadSuggestedVideos();
    _initializeVideo();
    _incrementViews();
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

  // ==================== SUGGESTIONS ====================
  Future<void> _loadSuggestedVideos() async {
    if (_isLoadingSuggestions) return;
    setState(() => _isLoadingSuggestions = true);
    try {
      // Choix aléatoire de la stratégie (0, 1, 2)
      int strategy = Random().nextInt(3);
      List<Post> selectedPosts = [];

      switch (strategy) {
        case 0:
        // 10 vidéos les plus populaires
          selectedPosts = await _fetchVideosByOrder('popularity', descending: true, limit: 10);
          break;
          case 3:
        // 10 vidéos les plus populaires
          selectedPosts = await _fetchVideosByOrder('popularity', descending: false, limit: 10);
          break;
        case 1:
        // 10 vidéos les plus récentes
          selectedPosts = await _fetchVideosByOrder('createdAt', descending: true, limit: 10);
          break;
        case 2:
        // Mixte : 6 populaires + 6 récentes, mélange, prend 10
          List<Post> popular = await _fetchVideosByOrder('popularity', descending: true, limit: 6);
          List<Post> recent = await _fetchVideosByOrder('createdAt', descending: true, limit: 6);
          Set<String> ids = {};
          List<Post> mixed = [];
          for (var p in [...popular, ...recent]) {
            if (p.id != _currentPost.id && !ids.contains(p.id)) {
              ids.add(p.id!);
              mixed.add(p);
            }
          }
          mixed.shuffle();
          selectedPosts = mixed.take(10).toList();
          break;
      }

      // Retirer la vidéo actuelle (si jamais elle s'est glissée)
      selectedPosts.removeWhere((p) => p.id == _currentPost.id);

      // Compléter si moins de 10 (avec des populaires par exemple)
      if (selectedPosts.length < 10) {
        List<Post> complement = await _fetchVideosByOrder('popularity', descending: true, limit: 15);
        for (var p in complement) {
          if (p.id != _currentPost.id && !selectedPosts.any((s) => s.id == p.id)) {
            selectedPosts.add(p);
            if (selectedPosts.length >= 10) break;
          }
        }
      }

      setState(() => _suggestedVideos = selectedPosts);

      // Générer les miniatures manquantes
      for (var post in selectedPosts) {
        if (post.thumbnail == null || post.thumbnail!.isEmpty) {
          _ensureThumbnailForPost(post);
        }
      }
    } catch (e) {
      print('Erreur chargement suggestions: $e');
    } finally {
      setState(() => _isLoadingSuggestions = false);
    }
  }

// Méthode utilitaire pour récupérer des vidéos selon un ordre
  Future<List<Post>> _fetchVideosByOrder(String field, {required bool descending, required int limit}) async {
    try {
      Query query = _firestore.collection('Posts')
          .where('dataType', isEqualTo: PostDataType.VIDEO.name)
          .orderBy(field, descending: descending)
          .limit(limit);
      final snapshot = await query.get();
      List<Post> posts = [];
      for (var doc in snapshot.docs) {
        final post = Post.fromJson(doc.data() as Map<String, dynamic>);
        post.id = doc.id;
        posts.add(post);
      }
      return posts;
    } catch (e) {
      print('Erreur fetch $field: $e');
      return [];
    }
  }
  void _onSuggestedVideoSelected(Post newPost) async {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => VideoYoutubePageDetails(initialPost: newPost),))
;    // Remplacer la vidéo courante
    // setState(() {
    //   _currentPost = newPost;
    //   _isVideoInitialized = false;
    //   _isLoading = false;
    // });
    // await _loadPostRelations();
    // await _checkIfFavorite();
    // await _checkIfUserHasVoted();
    // if (_isLookChallenge && _currentPost.challenge_id != null) {
    //   await _loadChallengeData();
    // }
    // await _initializeVideo();
    // await _loadSuggestedVideos();
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
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      // child: NativeAdWidget(
      //   key: ValueKey(key),
      //   templateType: TemplateType.small, // ou TemplateType.small
      //
      //   onAdLoaded: () {
      //     print('✅ Native Ad Afrolook chargée: $key');
      //   },
      // ),
      child: BannerAdWidget(
        onAdLoaded: () {

          print('✅ Bannière Afrolook chargée: $key');
          authProvider.incrementCreatorCoins(widget.initialPost.user_id!);
        },
      ),
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
        templateType: TemplateType.small, // ou TemplateType.small

        onAdLoaded: () {
          print('✅ Native Ad Afrolook chargée: $key');
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
    if (_isLoadingSuggestions) return Center(child: CircularProgressIndicator(color: _afroGreen));
    if (_suggestedVideos.isEmpty) return SizedBox.shrink();

    // Variable pour savoir si la pub a déjà été affichée
    bool _adDisplayed = false;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Suggestions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
      ListView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: _suggestedVideos.length + (_adDisplayed ? 0 : 1), // +1 seulement si pub pas encore affichée
        itemBuilder: (context, index) {
          // Vérifier si on doit afficher la pub à la 4ème position (index 3)
          if (!_adDisplayed && index == 3 && _suggestedVideos.length >= 3) {
            _adDisplayed = true;
            return Column(
              children: [
                Divider(color: Colors.grey[800]),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      _buildAdBanner(key: 'ad_details_post_unique'),
                      _buildAdNative(key: 'ad_native_post_unique')
                    ],
                  ),
                ),
                Divider(color: Colors.grey[800]),
              ],
            );
          }

          // Ajuster l'index pour les vidéos (si pub affichée, on décale)
          final videoIndex = _adDisplayed && index > 3 ? index - 1 : index;

          // Vérifier qu'on n'est pas hors limites
          if (videoIndex >= _suggestedVideos.length) {
            return SizedBox.shrink();
          }

          // Afficher la vidéo suggérée
          return Column(
            children: [
              _buildSuggestionCard(_suggestedVideos[videoIndex]),
              if (index != _suggestedVideos.length + (_adDisplayed ? 0 : 1) - 1)
                Divider(color: Colors.grey[800]),
            ],
          );
        },
      )
    ]);
  }
  Widget _buildSuggestionCard(Post post) {
    final bool isGenerating = _generatingThumbnails.contains(post.id);
    final String thumbnailUrl = post.thumbnail ?? '';

    return InkWell(
      onTap: () => _onSuggestedVideoSelected(post),
      child: Container(padding: EdgeInsets.symmetric(vertical: 8), child: Row(children: [
        Container(
          width: 120,
          height: 68,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: _afroDarkGrey),
          child: isGenerating
              ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: _afroGreen))
              : (thumbnailUrl.isNotEmpty
              ? CachedNetworkImage(
            imageUrl: thumbnailUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: _afroDarkGrey, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            errorWidget: (context, url, error) => Icon(Icons.videocam, color: _afroLightGrey),
          )
              : Icon(Icons.videocam, color: _afroLightGrey)),
        ),
        SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(post.description ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white, fontSize: 14)),
          SizedBox(height: 4),
          Text("${_formatCount(post.vues ?? 0)} vues . ${_formatCount(post.loves ?? 0)} J'aime", style: TextStyle(color: Colors.grey, fontSize: 12)),
        ])),
      ])),
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
      if (_rewardedAdKey.currentState != null && await _rewardedAdKey.currentState!.waitForAdReady()) {
        _rewardedAdKey.currentState!.showAd();
      } else {
        setState(() { _isSupporting = false; _showRewardedAd = false; });
      }
    });
  }

  Future<void> _onSupportAdRewarded() async {
    final userId = authProvider.loginUserData.id!;
    await _firestore.collection('Posts').doc(_currentPost.id).update({'adSupportCount': FieldValue.increment(1)});
    await _firestore.collection('Users').doc(_currentPost.user_id).update({'totalCoinsEarnedFromAdSupport': FieldValue.increment(10)});
    await _firestore.collection('post_supports').add({'postId': _currentPost.id, 'userId': userId, 'supportedAt': DateTime.now().millisecondsSinceEpoch});
    setState(() {
      _currentPost.adSupportCount = (_currentPost.adSupportCount ?? 0) + 1;
      _isSupporting = false;
      _showRewardedAd = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Merci ! Le créateur a reçu 10 pièces.'), backgroundColor: Colors.green));
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
              Padding(padding: EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildUserHeader(),
                SizedBox(height: 12),
                if (_currentPost.description != null) Text(_currentPost.description!, style: TextStyle(color: Colors.white, fontSize: 15)),
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
          if (_showRewardedAd) RewardedAdWidget(key: _rewardedAdKey, onUserEarnedReward: (reward) => _onSupportAdRewarded(), onAdDismissed: () => setState(() { _showRewardedAd = false; _isSupporting = false; }), child: SizedBox.shrink()),
        ],
      ),
    );
  }
}




// import 'dart:async';
// import 'dart:math';
// import 'dart:typed_data';
// import 'package:afrotok/pages/component/showUserDetails.dart';
// import 'package:afrotok/pages/paiement/newDepot.dart';
// import 'package:afrotok/pages/pub/banner_ad_widget.dart';
// import 'package:afrotok/pages/pub/native_ad_widget.dart';
// import 'package:afrotok/pages/pub/rewarded_ad_widget.dart';
// import 'package:afrotok/pages/widgetGlobal.dart';
// import 'package:flutter/material.dart';
// import 'package:google_mobile_ads/google_mobile_ads.dart';
// import 'package:video_player/video_player.dart';
// import 'package:chewie/chewie.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:provider/provider.dart';
// import 'package:afrotok/models/model_data.dart';
// import 'package:afrotok/providers/authProvider.dart';
// import 'package:afrotok/providers/postProvider.dart';
// import 'package:afrotok/pages/postComments.dart';
// import 'package:afrotok/services/linkService.dart';
// import 'package:video_thumbnail/video_thumbnail.dart';
//
// import 'UserServices/deviceService.dart';
// import 'canaux/detailsCanal.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// import 'home/homeWidget.dart';
//
// const _twitterDarkBg = Color(0xFF000000);
// const _twitterCardBg = Color(0xFF16181C);
// const _twitterTextPrimary = Color(0xFFFFFFFF);
// const _twitterTextSecondary = Color(0xFF71767B);
// const _twitterBlue = Color(0xFF1D9BF0);
// const _twitterRed = Color(0xFFF91880);
// const _twitterGreen = Color(0xFF00BA7C);
// const _twitterYellow = Color(0xFFFFD400);
//
// // Couleurs Afrolook
// const _afroBlack = Color(0xFF000000);
// const _afroGreen = Color(0xFF2ECC71);
// const _afroYellow = Color(0xFFF1C40F);
// const _afroRed = Color(0xFFE74C3C);
// const _afroDarkGrey = Color(0xFF16181C);
// const _afroLightGrey = Color(0xFF71767B);
//
// class VideoYoutubePageDetails extends StatefulWidget {
//   final Post initialPost;
//   final bool isIn;
//
//   const VideoYoutubePageDetails({Key? key, required this.initialPost,  this.isIn = false}) : super(key: key);
//
//   @override
//   _VideoYoutubePageDetailsState createState() => _VideoYoutubePageDetailsState();
// }
//
// class _VideoYoutubePageDetailsState extends State<VideoYoutubePageDetails> {
//   late PageController _pageController;
//   late UserAuthProvider authProvider;
//   late PostProvider postProvider;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   late SharedPreferences _prefs;
//   final String _lastViewDatePrefix = 'last_view_date_';
//   // Paramètres de chargement
//   final int _initialLimit = 5;
//   final int _loadMoreLimit = 5;
//
//   List<Post> _videoPosts = [];
//   int _currentPage = 0;
//
//   // Gestion des vidéos
//   VideoPlayerController? _currentVideoController;
//   ChewieController? _chewieController;
//   bool _isVideoInitialized = false;
//
//   // États de chargement
//   bool _isLoading = true;
//   bool _isLoadingMore = false;
//   bool _hasMoreVideos = true;
//   int _totalVideoCount = 1000;
//   int _selectedGiftIndex = 0;
//   int _selectedRepostPrice = 25;
//   bool _isSharing = false;
//
//   // Variables pour le vote
//   bool _hasVoted = false;
//   bool _isVoting = false;
//   List<String> _votersList = [];
//   Challenge? _challenge;
//   bool _loadingChallenge = false;
//
//   // Données pour la pagination intelligente
//   List<String> _allVideoPostIds = [];
//   List<String> _viewedVideoPostIds = [];
//   DocumentSnapshot? _lastDocument;
//
//   final GlobalKey<RewardedAdWidgetState> _rewardedAdKey = GlobalKey();
//   bool _showRewardedAd = false;
//   bool _isSupporting = false;
//   bool? _hasSeenSupportModal;
//
//   // Variables pour stocker les données récupérées individuellement
//   UserData? _currentUser;
//   Canal? _currentCanal;
//   bool _isLoadingUser = false;
//   bool _isLoadingCanal = false;
//
//   List<double> giftPrices = [
//     10, 25, 50, 100, 200, 300, 500, 700, 1500, 2000,
//     2500, 5000, 7000, 10000, 15000, 20000, 30000,
//     50000, 75000, 100000
//   ];
//
//   List<String> giftIcons = [
//     '🌹','❤️','👑','💎','🏎️','⭐','🍫','🧰','🌵','🍕',
//     '🍦','💻','🚗','🏠','🛩️','🛥️','🏰','💎','🏎️','🚗'
//   ];
//
//   // Stream pour les mises à jour en temps réel
//   final Map<String, StreamSubscription<DocumentSnapshot>> _postSubscriptions = {};
//
//   // Vérifier si c'est un Look Challenge
//   bool get _isLookChallenge {
//     return widget.initialPost.type == 'CHALLENGEPARTICIPATION';
//   }
//
//   Future<void> _loadSupportModalSeen() async {
//     final prefs = await SharedPreferences.getInstance();
//     final userId = authProvider.loginUserData.id;
//     final key = 'has_seen_support_modal_$userId';
//     setState(() {
//       _hasSeenSupportModal = prefs.getBool(key) ?? false;
//     });
//   }
//
//   Future<void> _markSupportModalSeen() async {
//     final prefs = await SharedPreferences.getInstance();
//     final userId = authProvider.loginUserData.id;
//     await prefs.setBool('has_seen_support_modal_$userId', true);
//     setState(() {
//       _hasSeenSupportModal = true;
//     });
//   }
//
//   Future<bool> _hasSupportedToday(String postId, String userId) async {
//     final now = DateTime.now();
//     final startOfDay = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
//     final endOfDay = startOfDay + Duration(days: 1).inMilliseconds;
//
//     final query = await _firestore
//         .collection('post_supports')
//         .where('postId', isEqualTo: postId)
//         .where('userId', isEqualTo: userId)
//         .where('supportedAt', isGreaterThanOrEqualTo: startOfDay)
//         .where('supportedAt', isLessThan: endOfDay)
//         .limit(1)
//         .get();
//
//     return query.docs.isNotEmpty;
//   }
//
//   Future<void> _recordSupport(String postId, String userId) async {
//     final support = PostSupport(
//       id: _firestore.collection('post_supports').doc().id,
//       postId: postId,
//       userId: userId,
//       supportedAt: DateTime.now().millisecondsSinceEpoch,
//     );
//     await _firestore.collection('post_supports').doc(support.id).set(support.toJson());
//   }
//
//   Future<void> _handleSupportAd(Post post) async {
//     // if (_isSupporting) return;
//     final currentUserId = authProvider.loginUserData.id;
//     if (currentUserId == post.user_id) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Vous ne pouvez pas soutenir votre propre post'), backgroundColor: Colors.orange),
//       );
//       return;
//     }
//
//     final hasSupported = await _hasSupportedToday(post.id!, currentUserId!);
//     if (hasSupported) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Vous avez déjà soutenu ce post aujourd\'hui. Revenez demain !'),
//           backgroundColor: Colors.orange,
//           duration: Duration(seconds: 2),
//         ),
//       );
//       return;
//     }
//
//     if (_hasSeenSupportModal == null) await _loadSupportModalSeen();
//     if (_hasSeenSupportModal == false) {
//       _showSupportModal(post);
//       return;
//     }
//     _startSupportAd(post);
//   }
//
//   void _startSupportAd(Post post) {
//     setState(() {
//       _isSupporting = true;
//       _showRewardedAd = true;
//     });
//     WidgetsBinding.instance.addPostFrameCallback((_) async {
//       if (_rewardedAdKey.currentState != null) {
//         bool ready = await _rewardedAdKey.currentState!.waitForAdReady();
//         if (ready) {
//           _rewardedAdKey.currentState!.showAd();
//         } else {
//           setState(() {
//             _isSupporting = false;
//             _showRewardedAd = false;
//           });
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('Publicité non disponible'), backgroundColor: Colors.red),
//           );
//         }
//       } else {
//         setState(() {
//           _isSupporting = false;
//           _showRewardedAd = false;
//         });
//       }
//     });
//   }
//
//   void _showSupportModal(Post post) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
//         backgroundColor: _twitterCardBg,
//         title: Row(
//           children: [
//             Icon(Icons.volunteer_activism, color: _twitterYellow),
//             SizedBox(width: 8),
//             Text('Soutenir le créateur', style: TextStyle(color: _twitterTextPrimary)),
//           ],
//         ),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'En regardant cette publicité, vous offrez 10 pièces au créateur de ce post.',
//               style: TextStyle(color: _twitterTextSecondary),
//             ),
//             SizedBox(height: 12),
//             Text(
//               'Cela l’encourage à produire plus de contenu et peut lui rapporter jusqu’à 100€ (environ 65 000 FCFA) par mois !',
//               style: TextStyle(color: _twitterTextPrimary),
//             ),
//             SizedBox(height: 12),
//             Container(
//               padding: EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: Colors.green.withOpacity(0.2),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Row(
//                 children: [
//                   Icon(Icons.monetization_on, color: _twitterYellow),
//                   SizedBox(width: 8),
//                   Expanded(
//                     child: Text(
//                       '💰 Les pièces récoltées peuvent être converties en argent réel.',
//                       style: TextStyle(color: _twitterTextPrimary, fontSize: 12),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Plus tard', style: TextStyle(color: _twitterTextSecondary)),
//           ),
//           ElevatedButton(
//             onPressed: () async {
//               Navigator.pop(context);
//               await _markSupportModalSeen();
//               _startSupportAd(post);
//             },
//             style: ElevatedButton.styleFrom(backgroundColor: _twitterYellow),
//             child: Text('Regarder la pub', style: TextStyle(color: Colors.black)),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Future<void> _onSupportAdRewarded(Post post) async {
//     final currentUserId = authProvider.loginUserData.id;
//     final postId = post.id!;
//     final creatorId = post.user_id!;
//
//     // Incrémenter le compteur de pub sur le post
//     final postRef = _firestore.collection('Posts').doc(postId);
//     await postRef.update({
//       'adSupportCount': FieldValue.increment(1),
//     });
//
//     // Créditer le créateur (10 pièces)
//     final creatorRef = _firestore.collection('Users').doc(creatorId);
//     await creatorRef.update({
//       'totalCoinsEarnedFromAdSupport': FieldValue.increment(10),
//     });
//
//     // Incrémenter le compteur du spectateur
//     final viewerRef = _firestore.collection('Users').doc(currentUserId);
//     await viewerRef.update({
//       'totalAdViewsSupported': FieldValue.increment(1),
//     });
//
//     // Enregistrer le soutien
//     await _recordSupport(postId, currentUserId!);
//
//     // Envoyer une notification au créateur
//     await _sendSupportNotification(creatorId, currentUserId!, postId, post);
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('🎉 Merci ! Le créateur a reçu 10 pièces.'),
//         backgroundColor: Colors.green,
//         duration: Duration(seconds: 2),
//       ),
//     );
//     // Mettre à jour l'état local
//     setState(() {
//       post.adSupportCount = (post.adSupportCount ?? 0) + 1;
//       _isSupporting = false;
//       _showRewardedAd = false;
//     });
//
//
//   }
//
//   Future<void> _sendSupportNotification(String creatorId, String supporterId, String postId, Post post) async {
//     final now = DateTime.now().microsecondsSinceEpoch;
//     final supporter = authProvider.loginUserData;
//     final supporterName = supporter.pseudo ?? 'Un utilisateur';
//
//     final description = "@$supporterName a soutenu votre vidéo en regardant une publicité ! (+10 pièces) 💰 Chaque soutien vous rapproche des 100€ (≈65 000 FCFA) par mois. Continuez à créer, on vous soutient !";
//
//     final notificationId = _firestore.collection('Notifications').doc().id;
//     final notification = NotificationData(
//       id: notificationId,
//       titre: "Soutien 💪 +10 pièces",
//       media_url: supporter.imageUrl ?? '',
//       type: NotificationType.POST.name,
//       description: description,
//       users_id_view: [],
//       user_id: supporterId,
//       receiver_id: creatorId,
//       post_id: postId,
//       post_data_type: PostDataType.VIDEO.name,
//       updatedAt: now,
//       createdAt: now,
//       status: PostStatus.VALIDE.name,
//     );
//     await _firestore.collection('Notifications').doc(notificationId).set(notification.toJson());
//
//     final creatorDoc = await _firestore.collection('Users').doc(creatorId).get();
//     final creatorToken = creatorDoc.data()?['oneIgnalUserid'] as String?;
//     if (creatorToken != null && creatorToken.isNotEmpty) {
//       await authProvider.sendNotification(
//         userIds: [creatorToken],
//         smallImage: supporter.imageUrl ?? '',
//         send_user_id: supporterId,
//         recever_user_id: creatorId,
//         message: "💪 @$supporterName vous a soutenu en regardant une vidéo ! +10 pièces 🎉 Continuez avec du contenu de qualité pour obtenir plus de soutiens !",        type_notif: NotificationType.SUPPORT.name,
//         post_id: postId,
//         post_type: PostDataType.VIDEO.name,
//         chat_id: '',
//       );
//     }
//   }
//   // Vérifier si l'utilisateur a accès au contenu
//   bool _hasAccessToContent(Post post) {
//     final canal = post.canal ?? _currentCanal;
//     if (canal != null) {
//       final isPrivate = canal.isPrivate == true;
//       final isSubscribed = canal.usersSuiviId?.contains(authProvider.loginUserData.id) ?? false;
//       final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;
//       final isCurrentUser = authProvider.loginUserData.id == post.user_id;
//
//       // Accès autorisé si :
//       // - Le canal n'est pas privé
//       // - OU l'utilisateur est abonné
//       // - OU c'est un admin
//       // - OU c'est l'utilisateur actuel
//       if (!isPrivate || isSubscribed || isAdmin || isCurrentUser) {
//         return true;
//       }
//
//       // Sinon, accès refusé
//       return false;
//     }
//
//     // Si ce n'est pas un post de canal → accès libre
//     return true;
//   }
//
//   // Vérifier si c'est un post de canal privé non accessible
//   bool _isLockedContent(Post post) {
//     final canal = post.canal ?? _currentCanal;
//     if (canal != null) {
//       final isPrivate = canal.isPrivate == true;
//       final isSubscribed = canal.usersSuiviId?.contains(authProvider.loginUserData.id) ?? false;
//       final isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;
//       final isCurrentUser = authProvider.loginUserData.id == post.user_id;
//
//       // Le contenu est verrouillé uniquement si :
//       // - Le canal est privé
//       // - L'utilisateur n'est pas abonné
//       // - Et ce n'est pas un administrateur
//       // - Et ce n'est pas l'utilisateur actuel
//       return isPrivate && !isSubscribed && !isAdmin && !isCurrentUser;
//     }
//     return false;
//   }
//
//   Future<void> _loadPostRelations() async {
//     try {
//       // Vérifier qu'on a des IDs
//       final post = widget.initialPost;
//       if (post.user_id == null) return;
//
//       // Récupérer l'utilisateur
//       setState(() {
//         _isLoadingUser = true;
//       });
//       final userDoc = await FirebaseFirestore.instance
//           .collection('Users')
//           .doc(post.user_id)
//           .get();
//
//       if (userDoc.exists) {
//         setState(() {
//           _currentUser = UserData.fromJson(userDoc.data()!);
//           post.user = _currentUser;
//         });
//       }
//
//       // Récupérer le canal si canal_id existe
//       if (post.canal_id != null && post.canal_id!.isNotEmpty) {
//         setState(() {
//           _isLoadingCanal = true;
//         });
//         final canalDoc = await FirebaseFirestore.instance
//             .collection('Canaux')
//             .doc(post.canal_id)
//             .get();
//
//         if (canalDoc.exists) {
//           setState(() {
//             _currentCanal = Canal.fromJson(canalDoc.data()!);
//             post.canal = _currentCanal;
//           });
//         }
//         setState(() {
//           _isLoadingCanal = false;
//         });
//       }
//       setState(() {
//         _isLoadingUser = false;
//       });
//
//       // Rebuild UI avec les données chargées
//       if (mounted) setState(() {});
//     } catch (e, stack) {
//       debugPrint('❌ Erreur récupération user/canal: $e\n$stack');
//       setState(() {
//         _isLoadingUser = false;
//         _isLoadingCanal = false;
//       });
//     }
//   }
//
//   UserData? get currentUser {
//     return widget.initialPost.user ?? _currentUser;
//   }
//
//   Canal? get currentCanal {
//     return widget.initialPost.canal ?? _currentCanal;
//   }
//
//   @override
//   void initState() {
//     super.initState();
//
//     // 🔥 NOUVEAU : Initialiser SharedPreferences
//     _initSharedPreferences();
//     authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     authProvider. incrementPostTotalInteractions(postId: widget.initialPost.id!);
//
//     postProvider = Provider.of<PostProvider>(context, listen: false);
//     _loadPostRelations();
//     _pageController = PageController();
//     _loadSupportModalSeen();
//     // Initialiser les fonctionnalités de challenge
//     if (_isLookChallenge && widget.initialPost.challenge_id != null) {
//       _loadChallengeData();
//     }
//     _checkIfUserHasVoted();
//     _loadInitialVideos();
//   }
// // 🔥 NOUVELLE MÉTHODE
//   Future<void> _initSharedPreferences() async {
//     _prefs = await SharedPreferences.getInstance();
//   }
//   @override
//   void dispose() {
//     _pageController.dispose();
//     _disposeCurrentVideo();
//     _disposePreviewVideos();
//     _postSubscriptions.forEach((key, subscription) => subscription.cancel());
//     super.dispose();
//   }
//
//   void _disposeCurrentVideo() {
//     _chewieController?.dispose();
//     _currentVideoController?.dispose();
//     setState(() {
//       _isVideoInitialized = false;
//     });
//   }
//
//   // ==================== FONCTIONNALITÉS CHALLENGE ET VOTE ====================
//
//   Future<void> _checkIfUserHasVoted() async {
//     try {
//       final postDoc = await _firestore.collection('Posts').doc(widget.initialPost.id).get();
//       if (postDoc.exists) {
//         final data = postDoc.data() as Map<String, dynamic>;
//         final voters = List<String>.from(data['users_votes_ids'] ?? []);
//         setState(() {
//           _hasVoted = voters.contains(authProvider.loginUserData.id);
//           _votersList = voters;
//         });
//       }
//     } catch (e) {
//       print('Erreur lors de la vérification du vote: $e');
//     }
//   }
//
//   Future<void> _loadChallengeData() async {
//     if (widget.initialPost.challenge_id == null) return;
//
//     setState(() {
//       _loadingChallenge = true;
//     });
//
//     try {
//       final challengeDoc = await _firestore
//           .collection('Challenges')
//           .doc(widget.initialPost.challenge_id)
//           .get();
//       if (challengeDoc.exists) {
//         setState(() {
//           _challenge = Challenge.fromJson(challengeDoc.data()!)
//             ..id = challengeDoc.id;
//         });
//       }
//     } catch (e) {
//       print('Erreur chargement challenge: $e');
//     } finally {
//       setState(() {
//         _loadingChallenge = false;
//       });
//     }
//   }
//
//   Future<void> _reloadChallengeData() async {
//     try {
//       if (widget.initialPost.challenge_id == null) return;
//
//       if (mounted) {
//         setState(() {
//           _loadingChallenge = true;
//         });
//       }
//
//       final challengeDoc = await _firestore
//           .collection('Challenges')
//           .doc(widget.initialPost.challenge_id)
//           .get();
//
//       if (challengeDoc.exists) {
//         if (mounted) {
//           setState(() {
//             _challenge = Challenge.fromJson(challengeDoc.data()!)
//               ..id = challengeDoc.id;
//           });
//         }
//       } else {
//         print('Challenge non trouvé: ${widget.initialPost.challenge_id}');
//         if (mounted) {
//           setState(() {
//             _challenge = null;
//           });
//         }
//       }
//     } catch (e) {
//       print('Erreur rechargement challenge: $e');
//       if (mounted) {
//         setState(() {
//           _challenge = null;
//         });
//       }
//       rethrow;
//     } finally {
//       if (mounted) {
//         setState(() {
//           _loadingChallenge = false;
//         });
//       }
//     }
//   }
//
//   Future<void> _voteForLook() async {
//     if (_hasVoted || _isVoting) return;
//
//     final user = _auth.currentUser;
//     if (user == null) {
//       _showError('CONNECTEZ-VOUS POUR POUVOIR VOTER\nVotre vote compte pour élire le gagnant !');
//       return;
//     }
//
//     setState(() {
//       _isVoting = true;
//     });
//
//     try {
//       // Si c'est un look challenge, recharger les données d'abord
//       if (_isLookChallenge && widget.initialPost.challenge_id != null) {
//         await _reloadChallengeData();
//
//         // Vérifier à nouveau après rechargement
//         if (_challenge == null) {
//           _showError('Impossible de charger les données du challenge. Veuillez réessayer.');
//           return;
//         }
//
//         final now = DateTime.now().microsecondsSinceEpoch;
//
//         // Vérifier si le challenge est terminé
//         if (_challenge!.isTermine || now > (_challenge!.finishedAt ?? 0)) {
//           _showError('CE CHALLENGE EST TERMINÉ\nMerci pour votre intérêt !');
//           return;
//         }
//
//         if (_challenge!.aVote(user.uid)) {
//           _showError('VOUS AVEZ DÉJÀ VOTÉ DANS CE CHALLENGE\nMerci pour votre participation !');
//           return;
//         }
//
//         if (!_challenge!.isEnCours) {
//           _showError('CE CHALLENGE N\'EST PLUS ACTIF\nLe vote n\'est pas possible actuellement.');
//           return;
//         }
//
//         // Vérifier le solde si vote payant
//         if (!_challenge!.voteGratuit!) {
//           final solde = await _getSoldeUtilisateur(user.uid);
//           if (solde < _challenge!.prixVote!) {
//             _showSoldeInsuffisant(_challenge!.prixVote! - solde.toInt());
//             return;
//           }
//         }
//
//         // Afficher la confirmation de vote
//         showDialog(
//           context: context,
//           builder: (context) => AlertDialog(
//             backgroundColor: Colors.grey[900],
//             title: Text('Confirmer votre vote', style: TextStyle(color: Colors.white)),
//             content: Text(
//               !_challenge!.voteGratuit!
//                   ? 'Êtes-vous sûr de vouloir voter pour ce look ?\n\nCe vote vous coûtera ${_challenge!.prixVote} FCFA.'
//                   : 'Voulez-vous vraiment voter pour ce look ?\n\nVotre vote est gratuit et ne peut être changé.',
//               style: TextStyle(color: Colors.grey[300]),
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () {
//                   Navigator.pop(context);
//                   setState(() {
//                     _isVoting = false;
//                   });
//                 },
//                 child: Text('ANNULER', style: TextStyle(color: Colors.grey)),
//               ),
//               ElevatedButton(
//                 onPressed: () async {
//                   Navigator.pop(context);
//                   await _processVoteWithChallenge(user.uid);
//                 },
//                 style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
//                 child: Text('CONFIRMER MON VOTE', style: TextStyle(color: Colors.white)),
//               ),
//             ],
//           ),
//         );
//       } else {
//         // Vote normal (sans challenge)
//         // await _processVoteNormal(user.uid);
//       }
//     } catch (e) {
//       print("Erreur lors de la préparation du vote: $e");
//       _showError('Erreur lors de la préparation du vote: $e');
//     }
//   }
//
//   Future<void> _processVoteWithChallenge2(String userId) async {
//     try {
//       // Recharger une dernière fois avant le vote pour être sûr
//       await _reloadChallengeData();
//
//       if (_challenge == null) {
//         throw Exception('Données du challenge non disponibles');
//       }
//
//       await _firestore.runTransaction((transaction) async {
//         // Vérifier à nouveau le challenge avec les données fraîches
//         final challengeRef = _firestore.collection('Challenges').doc(_challenge!.id!);
//         final challengeDoc = await transaction.get(challengeRef);
//
//         if (!challengeDoc.exists) throw Exception('Challenge non trouvé');
//
//         final currentChallenge = Challenge.fromJson(challengeDoc.data()!);
//
//         // Vérifications finales
//         if (!currentChallenge.isEnCours) {
//           throw Exception('Le challenge n\'est plus actif');
//         }
//
//         if (currentChallenge.aVote(userId)) {
//           throw Exception('Vous avez déjà voté dans ce challenge');
//         }
//
//         final postRef = _firestore.collection('Posts').doc(widget.initialPost.id);
//         final postDoc = await transaction.get(postRef);
//
//         if (!postDoc.exists) throw Exception('Post non trouvé');
//
//         // Débiter si vote payant
//         if (!_challenge!.voteGratuit!) {
//           await _debiterUtilisateur(userId, _challenge!.prixVote!,
//               'Vote pour le challenge ${_challenge!.titre}');
//         }
//
//         // Mettre à jour le post
//         transaction.update(postRef, {
//           'votes_challenge': FieldValue.increment(1),
//           'users_votes_ids': FieldValue.arrayUnion([userId]),
//           'popularity': FieldValue.increment(3),
//         });
//
//         // Mettre à jour le challenge
//         transaction.update(challengeRef, {
//           'users_votants_ids': FieldValue.arrayUnion([userId]),
//           'total_votes': FieldValue.increment(1),
//           'updated_at': DateTime.now().microsecondsSinceEpoch
//         });
//       });
//
//       // Mettre à jour l'état local
//       if (mounted) {
//         setState(() {
//           _hasVoted = true;
//           _votersList.add(userId);
//           widget.initialPost.votesChallenge = (widget.initialPost.votesChallenge ?? 0) + 1;
//         });
//       }
//
//       // Envoyer une notification
//       await authProvider.sendNotification(
//         userIds: [widget.initialPost.user!.oneIgnalUserid!],
//         smallImage: authProvider.loginUserData.imageUrl!,
//         send_user_id: authProvider.loginUserData.id!,
//         recever_user_id: widget.initialPost.user_id!,
//         message:
//         "🎉 @${authProvider.loginUserData.pseudo!} a voté pour votre look dans le challenge ${_challenge!.titre}!",
//         type_notif: NotificationType.POST.name,
//         post_id: widget.initialPost.id!,
//         post_type: PostDataType.VIDEO.name,
//         chat_id: '',
//       );
//
//       // Récompense pour le vote
//       await postProvider.interactWithPostAndIncrementSolde(widget.initialPost.id!,
//           authProvider.loginUserData.id!, "vote_look", widget.initialPost.user_id!);
//
//       _showSuccess('VOTE ENREGISTRÉ !\nMerci d\'avoir participé à l\'élection du gagnant.');
//       _envoyerNotificationVote(userVotant:  authProvider.loginUserData!, userVote:widget.initialPost!.user!);
//
//     } catch (e) {
//       print("Erreur lors du vote avec challenge: $e");
//       _showError('ERREUR LORS DU VOTE: ${e.toString()}\nVeuillez réessayer.');
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isVoting = false;
//         });
//       }
//     }
//   }
//   Future<void> _processVoteWithChallenge(String userId) async {
//     try {
//       // Recharger une dernière fois avant le vote pour être sûr
//       await _reloadChallengeData();
//
//       if (_challenge == null) {
//         throw Exception('Données du challenge non disponibles');
//       }
//
//       // Récupérer l'ID unique de l'appareil
//       final String deviceId = await DeviceInfoService.getDeviceId();
//       print("Vérification appareil pour vote vidéo: $deviceId");
//
//       // Vérifier si l'appareil a déjà voté (uniquement si ID valide)
//       if (DeviceInfoService.isDeviceIdValid(deviceId) &&
//           _challenge!.aVoteAvecAppareil(deviceId)) {
//         throw Exception('🚨 VIOLATION DÉTECTÉE: Cet appareil a déjà été utilisé pour voter dans ce challenge. L\'utilisation de comptes multiples est strictement interdite.');
//       }
//
//       await _firestore.runTransaction((transaction) async {
//         // Vérifier à nouveau le challenge avec les données fraîches
//         final challengeRef = _firestore.collection('Challenges').doc(_challenge!.id!);
//         final challengeDoc = await transaction.get(challengeRef);
//
//         if (!challengeDoc.exists) throw Exception('Challenge non trouvé');
//
//         final currentChallenge = Challenge.fromJson(challengeDoc.data()!);
//
//         // Vérifications finales
//         if (!currentChallenge.isEnCours) {
//           throw Exception('Le challenge n\'est plus actif');
//         }
//
//         if (currentChallenge.aVote(userId)) {
//           throw Exception('Vous avez déjà voté dans ce challenge');
//         }
//
//         // Vérification supplémentaire de l'appareil dans la transaction
//         if (DeviceInfoService.isDeviceIdValid(deviceId) &&
//             currentChallenge.aVoteAvecAppareil(deviceId)) {
//           throw Exception('🚨 VIOLATION DÉTECTÉE: Cet appareil a déjà été utilisé pour voter. Utilisation de comptes multiples interdite.');
//         }
//
//         final postRef = _firestore.collection('Posts').doc(widget.initialPost.id);
//         final postDoc = await transaction.get(postRef);
//
//         if (!postDoc.exists) throw Exception('Post non trouvé');
//
//         // Débiter si vote payant
//         if (!_challenge!.voteGratuit!) {
//           await _debiterUtilisateur(userId, _challenge!.prixVote!,
//               'Vote pour le challenge ${_challenge!.titre}');
//         }
//
//         // Mettre à jour le post
//         transaction.update(postRef, {
//           'votes_challenge': FieldValue.increment(1),
//           'users_votes_ids': FieldValue.arrayUnion([userId]),
//           'popularity': FieldValue.increment(3),
//         });
//
//         // Préparer les updates pour le challenge
//         final challengeUpdates = {
//           'users_votants_ids': FieldValue.arrayUnion([userId]),
//           'total_votes': FieldValue.increment(1),
//           'updated_at': DateTime.now().microsecondsSinceEpoch
//         };
//
//         // Ajouter l'ID appareil uniquement s'il est valide
//         if (DeviceInfoService.isDeviceIdValid(deviceId)) {
//           challengeUpdates['devices_votants_ids'] = FieldValue.arrayUnion([deviceId]);
//         }
//
//         // Mettre à jour le challenge
//         transaction.update(challengeRef, challengeUpdates);
//       });
//
//       // Mettre à jour l'état local
//       if (mounted) {
//         setState(() {
//           _hasVoted = true;
//           _votersList.add(userId);
//           widget.initialPost.votesChallenge = (widget.initialPost.votesChallenge ?? 0) + 1;
//         });
//       }
//
//       // Ajouter des points pour l'action de vote
//       addPointsForAction(UserAction.voteChallenge);
//
//       // Envoyer une notification
//       await authProvider.sendNotification(
//         userIds: [widget.initialPost.user!.oneIgnalUserid!],
//         smallImage: authProvider.loginUserData.imageUrl!,
//         send_user_id: authProvider.loginUserData.id!,
//         recever_user_id: widget.initialPost.user_id!,
//         message:
//         "🎉 @${authProvider.loginUserData.pseudo!} a voté pour votre vidéo dans le challenge ${_challenge!.titre}!",
//         type_notif: NotificationType.POST.name,
//         post_id: widget.initialPost.id!,
//         post_type: PostDataType.VIDEO.name,
//         chat_id: '',
//       );
//
//       // Récompense pour le vote
//       await postProvider.interactWithPostAndIncrementSolde(widget.initialPost.id!,
//           authProvider.loginUserData.id!, "vote_look", widget.initialPost.user_id!);
//
//       _showSuccess('✅ VOTE ENREGISTRÉ !\nMerci d\'avoir participé à l\'élection du gagnant.');
//       _envoyerNotificationVote(userVotant:  authProvider.loginUserData!, userVote:widget.initialPost!.user!);
//
//     } catch (e) {
//       print("Erreur lors du vote avec challenge: $e");
//
//       // Message d'erreur spécifique pour les violations
//       if (e.toString().contains('VIOLATION DÉTECTÉE')) {
//         _showError('''🚨 FRAUDE DÉTECTÉE
//
// Cet appareil a déjà été utilisé pour voter dans ce challenge.
//
// Pour garantir l'équité du concours, chaque appareil ne peut voter qu'une seule fois, quel que soit le compte utilisé.
//
// 📞 Contactez le support si vous pensez qu'il s'agit d'une erreur.''');
//       } else {
//         _showError('❌ ERREUR LORS DU VOTE: ${e.toString()}\nVeuillez réessayer.');
//       }
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isVoting = false;
//         });
//       }
//     }
//   }
//   Future<void> _processVoteNormal(String userId) async {
//     try {
//       // Mettre à jour Firestore
//       await _firestore.collection('Posts').doc(widget.initialPost.id).update({
//         'votes_challenge': FieldValue.increment(1),
//         'users_votes_ids': FieldValue.arrayUnion([userId]),
//         'popularity': FieldValue.increment(3),
//       });
//
//       // Mettre à jour l'état local
//       if (mounted) {
//         setState(() {
//           _hasVoted = true;
//           _votersList.add(userId);
//           widget.initialPost.votesChallenge = (widget.initialPost.votesChallenge ?? 0) + 1;
//         });
//       }
//
//       // Envoyer une notification au propriétaire du look
//       await authProvider.sendNotification(
//         userIds: [widget.initialPost.user!.oneIgnalUserid!],
//         smallImage: authProvider.loginUserData.imageUrl!,
//         send_user_id: authProvider.loginUserData.id!,
//         recever_user_id: widget.initialPost.user_id!,
//         message: "🎉 @${authProvider.loginUserData.pseudo!} a voté pour votre look !",
//         type_notif: NotificationType.POST.name,
//         post_id: widget.initialPost.id!,
//         post_type: PostDataType.VIDEO.name,
//         chat_id: '',
//       );
//
//       // Récompense pour le vote
//       await postProvider.interactWithPostAndIncrementSolde(widget.initialPost.id!,
//           authProvider.loginUserData.id!, "vote_look", widget.initialPost.user_id!);
//
//       _showSuccess('🎉 Vote enregistré !');
//     } catch (e) {
//       print("Erreur lors du vote normal: $e");
//       _showError('Erreur lors du vote: ${e.toString()}');
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isVoting = false;
//         });
//       }
//     }
//   }
//
//   // Méthodes utilitaires pour le vote
//   Future<double> _getSoldeUtilisateur(String userId) async {
//     final doc = await _firestore.collection('Users').doc(userId).get();
//     return (doc.data()?['votre_solde_principal'] ?? 0).toDouble();
//   }
//
//   Future<void> _debiterUtilisateur(String userId, int montant, String raison) async {
//     await _firestore.collection('Users').doc(userId).update({
//       'votre_solde_principal': FieldValue.increment(-montant)
//     });
//     String appDataId = authProvider.appDefaultData.id!;
//
//     await _firestore.collection('AppData').doc(appDataId).set({
//       'solde_gain': FieldValue.increment(montant)
//     }, SetOptions(merge: true));
//     await _createTransaction(
//         TypeTransaction.DEPENSE.name, montant.toDouble(), raison, userId);
//   }
//
//   void _showError(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message, style: TextStyle(color: Colors.white)),
//         backgroundColor: Colors.red,
//         duration: Duration(seconds: 4),
//       ),
//     );
//   }
//
//   void _showSuccess(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message, style: TextStyle(color: Colors.white)),
//         backgroundColor: Colors.green,
//         duration: Duration(seconds: 4),
//       ),
//     );
//   }
//
//   void _showSoldeInsuffisant(int montantManquant) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         backgroundColor: Colors.grey[900],
//         title: Text('SOLDE INSUFFISANT', style: TextStyle(color: Colors.yellow)),
//         content: Text(
//           'Il vous manque $montantManquant FCFA pour pouvoir voter.\n\n'
//               'Rechargez votre compte pour soutenir votre look préféré !',
//           style: TextStyle(color: Colors.grey[300]),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('PLUS TARD', style: TextStyle(color: Colors.grey)),
//           ),
//           ElevatedButton(
//             onPressed: () {
//               Navigator.pop(context);
//               Navigator.push(context,
//                   MaterialPageRoute(builder: (context) => DepositScreen()));
//             },
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
//             child: Text('RECHARGER MAINTENANT', style: TextStyle(color: Colors.white)),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _showVoteConfirmationDialog() {
//     final user = _auth.currentUser;
//
//     // Si c'est un look challenge avec vote payant
//     if (_isLookChallenge && _challenge != null && !_challenge!.voteGratuit!) {
//       showDialog(
//         context: context,
//         builder: (BuildContext context) {
//           return AlertDialog(
//             backgroundColor: _twitterCardBg,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(20),
//               side: BorderSide(color: _twitterGreen, width: 2),
//             ),
//             title: Text(
//               '🎉 Voter pour ce Look',
//               style: TextStyle(
//                 color: _twitterGreen,
//                 fontWeight: FontWeight.bold,
//               ),
//               textAlign: TextAlign.center,
//             ),
//             content: Text(
//               'Ce vote vous coûtera ${_challenge!.prixVote} FCFA.\n\n'
//                   'Voulez-vous continuer ?',
//               style: TextStyle(color: _twitterTextPrimary),
//               textAlign: TextAlign.center,
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: Text('Annuler', style: TextStyle(color: _twitterTextSecondary)),
//               ),
//               ElevatedButton(
//                 onPressed: () {
//                   Navigator.pop(context);
//                   _voteForLook();
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: _twitterGreen,
//                 ),
//                 child: Text('Voter ${_challenge!.prixVote} FCFA',
//                     style: TextStyle(color: Colors.white)),
//               ),
//             ],
//           );
//         },
//       );
//     } else {
//       // Dialogue de confirmation normal
//       showDialog(
//         context: context,
//         builder: (BuildContext context) {
//           return AlertDialog(
//             backgroundColor: _twitterCardBg,
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(20),
//               side: BorderSide(color: _twitterGreen, width: 2),
//             ),
//             title: Text(
//               '🎉 Voter pour ce Look',
//               style: TextStyle(
//                 color: _twitterGreen,
//                 fontWeight: FontWeight.bold,
//               ),
//               textAlign: TextAlign.center,
//             ),
//             content: Text(
//               'Vous allez voter pour ce look${_isLookChallenge ? ' challenge' : ''}. Cette action est irréversible${_isLookChallenge && _challenge != null ? ' et vous rapportera 3 points' : ''}!',
//               style: TextStyle(color: _twitterTextPrimary),
//               textAlign: TextAlign.center,
//             ),
//             actions: [
//               TextButton(
//                 onPressed: () => Navigator.pop(context),
//                 child: Text('Annuler', style: TextStyle(color: _twitterTextSecondary)),
//               ),
//               ElevatedButton(
//                 onPressed: () {
//                   Navigator.pop(context);
//                   _voteForLook();
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: _twitterGreen,
//                 ),
//                 child: Text('Voter', style: TextStyle(color: Colors.white)),
//               ),
//             ],
//           );
//         },
//       );
//     }
//   }
//
//   Future<void> _envoyerNotificationVote({
//     required UserData userVotant,   // celui qui a voté
//     required UserData userVote,     // celui qui reçoit le vote
//   }) async
//   {
//     try {
//       // Récupérer tous les IDs OneSignal des utilisateurs
//       final userIds = await authProvider.getAllUsersOneSignaUserId();
//
//       if (userIds.isEmpty) {
//         debugPrint("⚠️ Aucun utilisateur à notifier.");
//         return;
//       }
//
//       // Construire le message
//       final message = "👏 ${userVotant.pseudo} a voté pour ${userVote.pseudo}!";
//
//       await authProvider.sendNotification(
//         userIds: userIds,
//         smallImage: userVotant.imageUrl ?? '', // image de l'utilisateur qui a voté
//         send_user_id: userVotant.id!,
//         recever_user_id: userVote.id ?? "",
//         message: message,
//         type_notif: 'VOTE',
//         post_id: '',      // optionnel si tu n'as pas de post associé
//         post_type: '',    // optionnel
//         chat_id: '',      // optionnel
//       );
//
//       debugPrint("✅ Notification envoyée: $message");
//     } catch (e, stack) {
//       debugPrint("❌ Erreur envoi notification vote: $e\n$stack");
//     }
//   }
//
//   // ==================== GESTION DES VIDÉOS ====================
//
//   Future<void> _loadInitialVideos() async {
//     try {
//       setState(() => _isLoading = true);
//
//       // Charger les données nécessaires
//       await Future.wait([
//         _getTotalVideoCount(),
//         _getAppData(),
//         _getUserData(),
//       ]);
//
//       // Commencer avec la vidéo initiale
//       _videoPosts = [widget.initialPost];
//
//       // Marquer la vidéo initiale comme vue
//       await _markPostAsSeen(widget.initialPost);
//
//       // Charger les vidéos suivantes avec priorité aux non vues
//       await _loadMoreVideos(isInitialLoad: true);
//
//       // Initialiser la première vidéo
//       if (_videoPosts.isNotEmpty) {
//         _initializeVideo(_videoPosts.first);
//       }
//     } catch (e) {
//       print('Erreur chargement initial: $e');
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
//
//   Future<void> _getTotalVideoCount() async {
//     try {
//       final query = _firestore.collection('Posts')
//           .where('postDataType', isEqualTo: PostDataType.VIDEO.name)
//           .where('status', isEqualTo: PostStatus.VALIDE.name);
//
//       final snapshot = await query.count().get();
//       _totalVideoCount = snapshot.count ?? 1000;
//       print('Nombre total de vidéos: $_totalVideoCount');
//     } catch (e) {
//       print('Erreur comptage vidéos: $e');
//       _totalVideoCount = 1000;
//     }
//   }
//
//   Future<void> _getAppData() async {
//     try {
//       final appDataRef = _firestore.collection('AppData').doc(appId);
//       final appDataSnapshot = await appDataRef.get();
//
//       if (appDataSnapshot.exists) {
//         final appData = AppDefaultData.fromJson(appDataSnapshot.data() ?? {});
//         _allVideoPostIds = appData.allPostIds?.where((id) => id.isNotEmpty).toList() ?? [];
//         print('IDs vidéo disponibles: ${_allVideoPostIds.length}');
//       }
//     } catch (e) {
//       print('Erreur récupération AppData: $e');
//       _allVideoPostIds = [];
//     }
//   }
//
//   Future<void> _getUserData() async {
//     try {
//       final currentUserId = authProvider.loginUserData.id;
//       if (currentUserId == null) return;
//
//       final userDoc = await _firestore.collection('Users').doc(currentUserId).get();
//       if (userDoc.exists) {
//         final userData = UserData.fromJson(userDoc.data() as Map<String, dynamic>);
//         _viewedVideoPostIds = userData.viewedPostIds?.where((id) => id.isNotEmpty).toList() ?? [];
//         print('Vidéos déjà vues: ${_viewedVideoPostIds.length}');
//       }
//     } catch (e) {
//       print('Erreur récupération UserData: $e');
//       _viewedVideoPostIds = [];
//     }
//   }
//
//   Future<void> _loadMoreVideos({bool isInitialLoad = false}) async {
//     if (_isLoadingMore || !_hasMoreVideos) return;
//
//     try {
//       setState(() => _isLoadingMore = true);
//
//       final currentUserId = authProvider.loginUserData.id;
//
//       if (currentUserId != null && _allVideoPostIds.isNotEmpty) {
//         await _loadVideosWithPriority(currentUserId, isInitialLoad);
//       } else {
//         await _loadVideosChronologically();
//       }
//
//       _hasMoreVideos = _videoPosts.length < _totalVideoCount;
//
//     } catch (e) {
//       print('Erreur chargement supplémentaire: $e');
//     } finally {
//       setState(() => _isLoadingMore = false);
//     }
//   }
//
//   Future<void> _loadVideosWithPriority(String currentUserId, bool isInitialLoad) async {
//     final unseenVideoIds = _allVideoPostIds.where((postId) =>
//     !_viewedVideoPostIds.contains(postId) &&
//         !_videoPosts.any((post) => post.id == postId)
//     ).toList();
//
//     final seenVideoIds = _allVideoPostIds.where((postId) =>
//     _viewedVideoPostIds.contains(postId) &&
//         !_videoPosts.any((post) => post.id == postId)
//     ).toList();
//
//     print('📊 Vidéos non vues disponibles: ${unseenVideoIds.length}');
//     print('📊 Vidéos déjà vues disponibles: ${seenVideoIds.length}');
//
//     final limit = isInitialLoad ? _initialLimit - 1 : _loadMoreLimit;
//
//     final unseenVideos = await _loadVideosByIds(unseenVideoIds, limit: limit, isSeen: false);
//     print('✅ Vidéos non vues chargées: ${unseenVideos.length}');
//
//     if (unseenVideos.length < limit) {
//       final remainingLimit = limit - unseenVideos.length;
//       final seenVideos = await _loadVideosByIds(seenVideoIds, limit: remainingLimit, isSeen: true);
//       print('✅ Vidéos vues chargées: ${seenVideos.length}');
//
//       _videoPosts.addAll([...unseenVideos, ...seenVideos]);
//     } else {
//       _videoPosts.addAll(unseenVideos);
//     }
//
//     for (final post in _videoPosts) {
//       _subscribeToPostUpdates(post);
//     }
//   }
//
//   Future<List<Post>> _loadVideosByIds(List<String> videoIds, {required int limit, required bool isSeen}) async {
//     if (videoIds.isEmpty || limit <= 0) return [];
//
//     final idsToLoad = videoIds.take(limit).toList();
//     final videos = <Post>[];
//
//     print('🔹 Chargement de ${idsToLoad.length} vidéos par ID');
//
//     for (var i = 0; i < idsToLoad.length; i += 10) {
//       final batchIds = idsToLoad.skip(i).take(10).where((id) => id.isNotEmpty).toList();
//       if (batchIds.isEmpty) continue;
//
//       try {
//         final snapshot = await _firestore
//             .collection('Posts')
//             .where(FieldPath.documentId, whereIn: batchIds)
//             .where('postDataType', isEqualTo: PostDataType.VIDEO.name)
//             .get();
//
//         for (var doc in snapshot.docs) {
//           try {
//             final post = Post.fromJson(doc.data() as Map<String, dynamic>);
//             post.hasBeenSeenByCurrentUser = isSeen;
//             videos.add(post);
//           } catch (e) {
//             print('⚠️ Erreur parsing vidéo ${doc.id}: $e');
//           }
//         }
//       } catch (e) {
//         print('❌ Erreur batch chargement vidéos: $e');
//         for (final id in batchIds) {
//           try {
//             final doc = await _firestore.collection('Posts').doc(id).get();
//             if (doc.exists) {
//               final post = Post.fromJson(doc.data() as Map<String, dynamic>);
//               post.hasBeenSeenByCurrentUser = isSeen;
//               videos.add(post);
//             }
//           } catch (e) {
//             print('❌ Erreur chargement vidéo $id: $e');
//           }
//         }
//       }
//     }
//
//     return videos;
//   }
//
//   Future<void> _loadVideosChronologically() async {
//     try {
//       Query query = _firestore.collection('Posts')
//           .where('postDataType', isEqualTo: PostDataType.VIDEO.name)
//           .where('status', isEqualTo: PostStatus.VALIDE.name)
//           .orderBy('created_at', descending: true);
//
//       if (_lastDocument != null) {
//         query = query.startAfterDocument(_lastDocument!);
//       }
//
//       final snapshot = await query.limit(_loadMoreLimit).get();
//
//       if (snapshot.docs.isNotEmpty) {
//         _lastDocument = snapshot.docs.last;
//       }
//
//       final newVideos = snapshot.docs.map((doc) {
//         final post = Post.fromJson(doc.data() as Map<String, dynamic>);
//         post.hasBeenSeenByCurrentUser = _viewedVideoPostIds.contains(post.id);
//         _subscribeToPostUpdates(post);
//         return post;
//       }).toList();
//
//       final existingIds = _videoPosts.map((v) => v.id).toSet();
//       final uniqueNewVideos = newVideos.where((video) =>
//       video.id != null && !existingIds.contains(video.id)).toList();
//
//       _videoPosts.addAll(uniqueNewVideos);
//
//     } catch (e) {
//       print('❌ Erreur chargement chronologique: $e');
//     }
//   }
//
//   void _subscribeToPostUpdates(Post post) {
//     if (post.id == null || _postSubscriptions.containsKey(post.id)) return;
//
//     final subscription = _firestore.collection('Posts').doc(post.id).snapshots().listen((snapshot) {
//       if (snapshot.exists && mounted) {
//         final updatedPost = Post.fromJson(snapshot.data() as Map<String, dynamic>);
//
//         setState(() {
//           final index = _videoPosts.indexWhere((p) => p.id == post.id);
//           if (index != -1) {
//             updatedPost.user = _videoPosts[index].user;
//             updatedPost.canal = _videoPosts[index].canal;
//             updatedPost.hasBeenSeenByCurrentUser = _videoPosts[index].hasBeenSeenByCurrentUser;
//             _videoPosts[index] = updatedPost;
//           }
//         });
//       }
//     });
//
//     _postSubscriptions[post.id!] = subscription;
//   }
//
//   Future<void> _initializeVideo(Post post) async {
//     _disposeCurrentVideo();
//
//     if (post.url_media == null || post.url_media!.isEmpty) {
//       print('⚠️ Aucune URL média pour la vidéo ${post.id}');
//       return;
//     }
//
//     try {
//       print('🎬 Initialisation vidéo: ${post.url_media}');
//
//       _currentVideoController = VideoPlayerController.network(post.url_media!);
//       await _currentVideoController!.initialize();
//
//       _chewieController = ChewieController(
//         videoPlayerController: _currentVideoController!,
//         autoPlay: true,
//         looping: true,
//         showControls: true,
//         allowFullScreen: true,
//         allowMuting: true,
//         materialProgressColors: ChewieProgressColors(
//           playedColor: _afroGreen,
//           handleColor: _afroGreen,
//           backgroundColor: _afroLightGrey.withOpacity(0.3),
//           bufferedColor: _afroLightGrey.withOpacity(0.1),
//         ),
//         placeholder: Container(
//           color: _afroBlack,
//           child: Center(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 CircularProgressIndicator(color: _afroGreen),
//                 SizedBox(height: 16),
//                 Text('Chargement...', style: TextStyle(color: Colors.white)),
//               ],
//             ),
//           ),
//         ),
//         autoInitialize: true,
//       );
//
//       setState(() => _isVideoInitialized = true);
//       await _recordPostView(post);
//
//     } catch (e) {
//       print('❌ Erreur initialisation vidéo: $e');
//       setState(() => _isVideoInitialized = false);
//     }
//   }
// // 🔥 NOUVELLE MÉTHODE UTILITAIRE
//   String _getTodayDateString() {
//     final now = DateTime.now();
//     return '${now.year}-${now.month}-${now.day}';
//   }
// // 🔥 MODIFIÉE : Marquer le post comme vu sans compter
//   Future<void> _markPostAsSeen(Post post) async {
//     if (post.id == null) return;
//
//     final currentUserId = authProvider.loginUserData.id;
//     if (currentUserId == null) return;
//
//     try {
//       if (!_viewedVideoPostIds.contains(post.id)) {
//         _viewedVideoPostIds.add(post.id!);
//
//         await _firestore.collection('Users').doc(currentUserId).update({
//           'viewedPostIds': FieldValue.arrayUnion([post.id]),
//         });
//
//         post.hasBeenSeenByCurrentUser = true;
//       }
//     } catch (e) {
//       print('❌ Erreur marquage post comme vu: $e');
//     }
//   }
//
// // 🔥 NOUVELLE VERSION : Enregistrer la vue avec contrôle journalier
//   Future<void> _recordPostView2(Post post) async {
//     if (post.id == null) return;
//
//     final currentUserId = authProvider.loginUserData.id;
//     if (currentUserId == null) return;
//
//     try {
//       // 🔥 Vérification avec SharedPreferences (une fois par jour)
//       String todayDate = _getTodayDateString();
//       String viewKey = '${_lastViewDatePrefix}${currentUserId}_${post.id}';
//
//       // Récupérer la dernière date de vue pour ce post par cet utilisateur
//       String? lastViewDate = _prefs.getString(viewKey);
//
//       // Marquer le post comme vu dans la session (pour l'UI)
//       await _markPostAsSeen(post);
//
//       // Si déjà vu aujourd'hui, NE PAS COMPTER la vue
//       if (lastViewDate == todayDate) {
//         print('⏭️ Vidéo ${post.id} déjà vue aujourd\'hui par $currentUserId - Vue NON comptée');
//
//         // Mettre à jour l'UI locale si nécessaire
//         if (!post.users_vue_id!.contains(currentUserId)) {
//           setState(() {
//             post.users_vue_id!.add(currentUserId);
//             // On n'incrémente PAS vues
//           });
//         }
//         return; // On ne compte pas la vue
//       }
//
//       // 🔥 PREMIÈRE VUE AUJOURD'HUI : On compte la vue
//       print('✅ Première vue du jour pour vidéo ${post.id} par $currentUserId');
//
//       // Sauvegarder la date dans SharedPreferences
//       await _prefs.setString(viewKey, todayDate);
//
//       // Mettre à jour Firestore (incrémenter le compteur)
//       await _firestore.collection('Posts').doc(post.id).update({
//         'vues': FieldValue.increment(1),
//         'users_vue_id': FieldValue.arrayUnion([currentUserId]),
//       });
//
//       // Mettre à jour localement
//       setState(() {
//         post.vues = (post.vues ?? 0) + 1;
//         if (!post.users_vue_id!.contains(currentUserId)) {
//           post.users_vue_id!.add(currentUserId);
//         }
//       });
//
//     } catch (e) {
//       print('❌ Erreur enregistrement vue: $e');
//     }
//   }
//
//   Future<void> _recordPostView(Post post) async {
//     if (post.id == null) return;
//
//     final currentUserId = authProvider.loginUserData.id;
//     if (currentUserId == null) return;
//
//     try {
//       // Marquer le post comme vu pour l'UI
//       await _markPostAsSeen(post);
//
//       post.users_vue_id ??= [];
//
//       // 🔥 Vérifier si l'utilisateur a déjà vu
//       if (post.users_vue_id!.contains(currentUserId)) {
//         print('⏭️ Vidéo ${post.id} déjà vue par $currentUserId');
//         return;
//       }
//
//       // ✅ Mise à jour Firestore
//       await _firestore.collection('Posts').doc(post.id).update({
//         'vues': FieldValue.increment(1),
//         'users_vue_id': FieldValue.arrayUnion([currentUserId]),
//       });
//
//       // ✅ Mise à jour locale
//       setState(() {
//         post.vues = (post.vues ?? 0) + 1;
//         post.users_vue_id!.add(currentUserId);
//       });
//
//       print('✅ Vue unique enregistrée pour vidéo ${post.id}');
//
//     } catch (e) {
//       print('❌ Erreur enregistrement vue: $e');
//     }
//   }
//
//   // ==================== WIDGETS ====================
//
//   Widget _buildVideoPlayer(Post post) {
//     if (!_isVideoInitialized) {
//       return _buildVideoPlaceholder(post);
//     }
//
//     return Stack(
//       children: [
//         Chewie(controller: _chewieController!),
//       ],
//     );
//   }
//
//   Widget _buildVideoPlaceholder(Post post) {
//     return Container(
//       color: _afroBlack,
//       child: Stack(
//         children: [
//           if (post.images != null && post.images!.isNotEmpty)
//             CachedNetworkImage(
//               imageUrl: post.images!.first,
//               fit: BoxFit.cover,
//               width: double.infinity,
//               height: double.infinity,
//             )
//           else
//             Container(
//               color: _afroDarkGrey,
//               child: Center(
//                 child: Icon(Icons.videocam, color: _afroLightGrey, size: 80),
//               ),
//             ),
//
//           Center(
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 CircularProgressIndicator(color: _afroGreen),
//                 SizedBox(height: 16),
//                 Text(
//                   'Chargement de la vidéo...',
//                   style: TextStyle(color: Colors.white),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildLockedContent(Post post) {
//     final canal = post.canal ?? _currentCanal;
//     final isPrivate = canal?.isPrivate == true;
//     final subscriptionPrice = canal?.subscriptionPrice ?? 0;
//
//     return Container(
//       color: _afroBlack,
//       child: Stack(
//         children: [
//           // Aperçu de la vidéo (thumbnail) ou image de profil
//           if (post.url_media != null && post.url_media!.isNotEmpty)
//             _buildVideoThumbnail(post) // Assure-toi que _buildVideoThumbnail utilise FutureBuilder pour la vraie miniature
//           else if (post.user != null && post.user!.imageUrl!.isNotEmpty)
//             CachedNetworkImage(
//               imageUrl: post.user!.imageUrl!,
//               fit: BoxFit.cover,
//               width: double.infinity,
//               height: double.infinity,
//             )
//           else
//             Container(color: _afroDarkGrey),
//
//           // Overlay semi-transparent global (moins opaque pour voir l'image)
//           Positioned.fill(
//             child: Container(
//               color: Colors.black.withOpacity(0.3), // 0.7 -> 0.3 pour voir derrière
//             ),
//           ),
//
//           // Contenu verrouillé
//           Positioned.fill(
//             child: Column(
//               children: [
//                 _buildLockedHeader(post, canal),
//                 Expanded(
//                   child: Center(
//                     child: Padding(
//                       padding: EdgeInsets.all(20),
//                       child: Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           Icon(Icons.lock, color: _afroYellow, size: 80),
//                           SizedBox(height: 20),
//                           Text(
//                             'Contenu Verrouillé',
//                             style: TextStyle(
//                               color: _afroYellow,
//                               fontSize: 24,
//                               fontWeight: FontWeight.bold,
//                             ),
//                             textAlign: TextAlign.center,
//                           ),
//                           SizedBox(height: 16),
//                           Text(
//                             isPrivate
//                                 ? 'Ce contenu est réservé aux abonnés du canal.\nAbonnez-vous pour accéder à cette vidéo et à tout le contenu exclusif.'
//                                 : 'Ce contenu est réservé aux abonnés du canal.',
//                             style: TextStyle(color: Colors.white, fontSize: 16),
//                             textAlign: TextAlign.center,
//                           ),
//                           SizedBox(height: 30),
//                           Container(
//                             width: double.infinity,
//                             margin: EdgeInsets.symmetric(horizontal: 40),
//                             child: ElevatedButton(
//                               style: ElevatedButton.styleFrom(
//                                 backgroundColor: _afroYellow,
//                                 foregroundColor: Colors.black,
//                                 padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
//                                 shape: RoundedRectangleBorder(
//                                   borderRadius: BorderRadius.circular(25),
//                                 ),
//                               ),
//                               onPressed: () {
//                                 if (canal != null) {
//                                   Navigator.push(
//                                     context,
//                                     MaterialPageRoute(
//                                       builder: (context) => CanalDetails(canal: canal),
//                                     ),
//                                   );
//                                 }
//                               },
//                               child: Row(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Icon(Icons.lock_open, size: 24),
//                                   SizedBox(width: 12),
//                                   Text(
//                                     isPrivate
//                                         ? 'S\'ABONNER - ${subscriptionPrice.toInt()} FCFA'
//                                         : 'SUIVRE LE CANAL',
//                                     style: TextStyle(
//                                       fontSize: 16,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                           SizedBox(height: 16),
//                           TextButton(
//                             onPressed: () {
//                               Navigator.pop(context);
//                             },
//                             child: Text(
//                               'Retour',
//                               style: TextStyle(color: _afroGreen, fontSize: 16),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//
//
//   Future<Uint8List?> generateVideoThumbnail(String videoUrl) async {
//     // Vérifie si c'est une vidéo
//     final videoExtensions = ['.mp4', '.mov', '.webm', '.mkv'];
//     if (!videoExtensions.any((ext) => videoUrl.toLowerCase().contains(ext))) {
//       return null; // Pas une vidéo
//     }
//
//     try {
//       final uint8list = await VideoThumbnail.thumbnailData(
//         video: videoUrl,
//         imageFormat: ImageFormat.JPEG,
//         maxWidth: 300, // largeur souhaitée de la miniature
//         quality: 75,
//       );
//
//       return uint8list; // retourne les données de l'image
//     } catch (e) {
//       print('Erreur génération miniature: $e');
//       return null;
//     }
//   }
//   Widget _buildVideoThumbnail(Post post) {
//     return FutureBuilder<Uint8List?>(
//       future: _generateEnhancedThumbnailUrl(post.url_media!),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return Container(
//             color: _afroDarkGrey,
//             child: Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   CircularProgressIndicator(color: _afroGreen),
//                   SizedBox(height: 8),
//                   Text(
//                     'Chargement de l\'aperçu...',
//                     style: TextStyle(color: Colors.white, fontSize: 12),
//                   ),
//                 ],
//               ),
//             ),
//           );
//         }
//
//         final thumbnail = snapshot.data;
//
//         return Stack(
//           children: [
//             // Affichage de la vraie miniature
//             if (thumbnail != null)
//               Image.memory(
//                 thumbnail,
//                 fit: BoxFit.cover,
//                 width: double.infinity,
//                 height: double.infinity,
//               )
//             else
//               Container(
//                 color: _afroDarkGrey,
//                 child: Center(
//                   child: Column(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Icon(Icons.videocam, color: _afroLightGrey, size: 50),
//                       SizedBox(height: 8),
//                       Text(
//                         'Aperçu vidéo',
//                         style: TextStyle(color: _afroLightGrey),
//                       ),
//                       SizedBox(height: 4),
//                       Text(
//                         'Abonnez-vous pour voir la vidéo',
//                         style: TextStyle(color: _afroYellow, fontSize: 12),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//
//             // Overlay de lecture
//             Positioned.fill(
//               child: Container(
//                 color: Colors.black.withOpacity(0.4),
//                 child: Center(
//                   child: Container(
//                     padding: EdgeInsets.all(20),
//                     decoration: BoxDecoration(
//                       color: Colors.black.withOpacity(0.8),
//                       shape: BoxShape.circle,
//                       border: Border.all(color: _afroYellow, width: 2),
//                     ),
//                     child: Icon(
//                       Icons.play_arrow,
//                       color: _afroYellow,
//                       size: 50,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//
//   Widget _buildLockedHeader(Post post, Canal? canal) {
//     return Container(
//       width: double.infinity,
//       padding: EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         gradient: LinearGradient(
//           begin: Alignment.topCenter,
//           end: Alignment.bottomCenter,
//           colors: [
//             Colors.black.withOpacity(0.9),
//             Colors.transparent,
//           ],
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Profil du canal
//           if (canal != null)
//             _buildCanalProfile(canal),
//
//           SizedBox(height: 16),
//
//           // Description
//           if (post.description != null && post.description!.isNotEmpty)
//             Container(
//               constraints: BoxConstraints(maxWidth: 300),
//               child: Text(
//                 post.description!,
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 14,
//                 ),
//                 maxLines: 2,
//                 overflow: TextOverflow.ellipsis,
//               ),
//             ),
//
//           SizedBox(height: 16),
//
//           // Statistiques de la vidéo
//           _buildVideoStatistics(post),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildCanalProfile(Canal canal) {
//     return Row(
//       children: [
//         // Avatar du canal
//         Container(
//           decoration: BoxDecoration(
//             border: Border.all(color: _afroYellow, width: 2),
//             shape: BoxShape.circle,
//           ),
//           child: GestureDetector(
//             onTap: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                   builder: (context) => CanalDetails(canal: canal),
//                 ),
//               );
//             },
//             child: CircleAvatar(
//               radius: 25,
//               backgroundImage: CachedNetworkImageProvider(
//                 canal.urlImage ?? '',
//               ),
//               backgroundColor: _afroDarkGrey,
//               child: canal.urlImage == null || canal.urlImage!.isEmpty
//                   ? Icon(Icons.people, color: _afroYellow)
//                   : null,
//             ),
//           ),
//         ),
//
//         SizedBox(width: 12),
//
//         // Informations du canal
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 canal.titre ?? 'Canal sans nom',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontWeight: FontWeight.bold,
//                   fontSize: 16,
//                 ),
//                 maxLines: 1,
//                 overflow: TextOverflow.ellipsis,
//               ),
//
//               SizedBox(height: 4),
//
//               Text(
//                 '${canal.usersSuiviId?.length ?? 0} abonnés • ${canal.publication ?? 0} publications',
//                 style: TextStyle(
//                   color: Colors.white70,
//                   fontSize: 12,
//                 ),
//               ),
//
//               if (canal.description != null && canal.description!.isNotEmpty) ...[
//                 SizedBox(height: 4),
//                 Text(
//                   canal.description!,
//                   style: TextStyle(
//                     color: Colors.white70,
//                     fontSize: 11,
//                   ),
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ],
//             ],
//           ),
//         ),
//
//         // Badge canal privé
//         if (canal.isPrivate == true)
//           Container(
//             padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//             decoration: BoxDecoration(
//               color: _afroYellow.withOpacity(0.2),
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: _afroYellow),
//             ),
//             child: Row(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Icon(Icons.lock, size: 12, color: _afroYellow),
//                 SizedBox(width: 4),
//                 Text(
//                   'Privé',
//                   style: TextStyle(
//                     color: _afroYellow,
//                     fontSize: 10,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//       ],
//     );
//   }
//
//   Widget _buildVideoStatistics(Post post) {
//     return Container(
//       padding: EdgeInsets.all(12),
//       decoration: BoxDecoration(
//         color: Colors.black.withOpacity(0.5),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: _afroYellow.withOpacity(0.3)),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceAround,
//         children: [
//           _buildStatItem(
//             Icons.remove_red_eye,
//             'Vues',
//             _formatCount(post.vues ?? 0),
//           ),
//           _buildStatItem(
//             Icons.favorite,
//             'J\'aime',
//             _formatCount(post.loves ?? 0),
//           ),
//           _buildStatItem(
//             Icons.chat_bubble,
//             'Commentaires',
//             _formatCount(post.comments ?? 0),
//           ),
//           if (_isLookChallenge)
//             _buildStatItem(
//               Icons.how_to_vote,
//               'Votes',
//               _formatCount(post.votesChallenge ?? 0),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildStatItem(IconData icon, String label, String count) {
//     return Column(
//       children: [
//         Icon(
//           icon,
//           color: _afroYellow,
//           size: 20,
//         ),
//         SizedBox(height: 4),
//         Text(
//           count,
//           style: TextStyle(
//             color: Colors.white,
//             fontSize: 12,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         Text(
//           label,
//           style: TextStyle(
//             color: Colors.white70,
//             fontSize: 10,
//           ),
//         ),
//       ],
//     );
//   }
//
// // Ajoutez cette méthode pour améliorer la génération des thumbnails
//   Future<Uint8List?> _generateEnhancedThumbnailUrl(String videoUrl) async {
//     try {
//       // Vérifie si c'est une vidéo
//       final videoExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm'];
//       if (!videoExtensions.any((ext) => videoUrl.toLowerCase().contains(ext))) {
//         return null; // pas une vidéo
//       }
//
//       // Génère la vraie miniature
//       final uint8list = await VideoThumbnail.thumbnailData(
//         video: videoUrl,
//         imageFormat: ImageFormat.JPEG,
//         maxWidth: 300, // largeur souhaitée
//         quality: 75,
//       );
//
//       return uint8list;
//     } catch (e) {
//       print('❌ Erreur génération thumbnail: $e');
//       return null;
//     }
//   }
// // Mettez à jour la méthode _buildVideoThumbnail pour utiliser la version améliorée
//
// // N'oubliez pas de disposer les contrôleurs de prévision
// //   @override
// //   void dispose() {
// //     _pageController.dispose();
// //     _disposeCurrentVideo();
// //     _disposePreviewVideos();
// //     _postSubscriptions.forEach((key, subscription) => subscription.cancel());
// //     super.dispose();
// //   }
//
//   void _disposePreviewVideos() {
//     // Vous devriez maintenir une liste des contrôleurs de prévision pour les disposer
//     // Pour l'instant, on dispose seulement du contrôleur courant
//     _disposeCurrentVideo();
//   }
//
// // Modifiez également la méthode _buildUserInfo pour inclure les stats si nécessaire
// //   Widget _buildUserInfo(Post post) {
// //     final user = post.user;
// //     final canal = post.canal;
// //
// //     return Positioned(
// //       bottom: 120,
// //       left: 16,
// //       child: Column(
// //         crossAxisAlignment: CrossAxisAlignment.start,
// //         children: [
// //           if (canal != null) ...[
// //             GestureDetector(
// //               onTap: () {
// //                 if (canal != null) {
// //                   Navigator.push(
// //                     context,
// //                     MaterialPageRoute(
// //                       builder: (context) => CanalDetails(canal: canal),
// //                     ),
// //                   );
// //                 }
// //               },
// //               child: Text(
// //                 '#${canal. titre ?? ''}',
// //                 style: TextStyle(
// //                   color: Colors.white,
// //                   fontWeight: FontWeight.bold,
// //                   fontSize: 16,
// //                 ),
// //               ),
// //             ),
// //             Text(
// //               '${canal.usersSuiviId?.length ?? 0} abonnés',
// //               style: TextStyle(color: Colors.white),
// //             ),
// //           ] else if (user != null) ...[
// //             GestureDetector(
// //               onTap: () {
// //                 if (user != null) {
// //                   showUserDetailsModalDialog(user, MediaQuery.of(context).size.width, MediaQuery.of(context).size.height, context);
// //                 }
// //               },
// //               child: Text(
// //                 '@${user.pseudo ?? ''}',
// //                 style: TextStyle(
// //                   color: Colors.white,
// //                   fontWeight: FontWeight.bold,
// //                   fontSize: 16,
// //                 ),
// //               ),
// //             ),
// //             Text(
// //               '${user.userAbonnesIds?.length ?? 0} abonnés',
// //               style: TextStyle(color: Colors.white),
// //             ),
// //           ],
// //           SizedBox(height: 8),
// //
// //           // Statistiques rapides sous les infos utilisateur
// //           _buildQuickStats(post),
// //
// //           SizedBox(height: 8),
// //           if (post.description != null)
// //             Container(
// //               constraints: BoxConstraints(maxWidth: 250),
// //               child: Text(
// //                 post.description!,
// //                 style: TextStyle(color: Colors.white),
// //                 maxLines: 3,
// //                 overflow: TextOverflow.ellipsis,
// //               ),
// //             ),
// //         ],
// //       ),
// //     );
// //   }
//   Widget _buildUserInfo(Post post) {
//     final user = post.user;
//     final canal = post.canal;
//     final hasAccess = _hasAccessToContent(post);
//     final isOwner = authProvider.loginUserData.id == post.user_id;
//     final count = post.adSupportCount ?? 0;
//
//     return Positioned(
//       bottom: 120,
//       left: 16,
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           if (canal != null) ...[
//             GestureDetector(
//               onTap: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => CanalDetails(canal: canal),
//                   ),
//                 );
//               },
//               child: Text(
//                 '#${canal.titre ?? ''}',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontWeight: FontWeight.bold,
//                   fontSize: 16,
//                 ),
//               ),
//             ),
//             Text(
//               '${canal.usersSuiviId?.length ?? 0} abonnés',
//               style: TextStyle(color: Colors.white),
//             ),
//           ] else if (user != null) ...[
//             GestureDetector(
//               onTap: () {
//                 showUserDetailsModalDialog(
//                   user,
//                   MediaQuery.of(context).size.width,
//                   MediaQuery.of(context).size.height,
//                   context,
//                 );
//               },
//               child: Text(
//                 '@${user.pseudo ?? ''}',
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontWeight: FontWeight.bold,
//                   fontSize: 16,
//                 ),
//               ),
//             ),
//             Text(
//               '${user.userAbonnesIds?.length ?? 0} abonnés',
//               style: TextStyle(color: Colors.white),
//             ),
//           ],
//           SizedBox(height: 4),
//
//           if (post.description != null)
//             Container(
//               constraints: BoxConstraints(maxWidth: 250),
//               child: Text(
//                 post.description!,
//                 style: TextStyle(color: Colors.white),
//                 maxLines: 2,
//                 overflow: TextOverflow.ellipsis,
//               ),
//             ),
//
//           // 🔥 NOUVEAU : Bouton Soutenir le créateur (juste après la description)
//           if (hasAccess && !isOwner)
//             Padding(
//               padding: EdgeInsets.only(top: 12),
//               child: GestureDetector(
//                 onTap: _isSupporting ? null : () => _handleSupportAd(post),
//                 child: Container(
//                   padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                   decoration: BoxDecoration(
//                     color: _afroDarkGrey.withOpacity(0.8),
//                     borderRadius: BorderRadius.circular(20),
//                     border: Border.all(color: _afroYellow.withOpacity(0.5)),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       if (_isSupporting)
//                         SizedBox(
//                           width: 16,
//                           height: 16,
//                           child: CircularProgressIndicator(strokeWidth: 2, color: _afroYellow),
//                         )
//                       else
//                         Icon(Icons.volunteer_activism, color: _afroYellow, size: 16),
//                       SizedBox(width: 6),
//                       Text(
//                         'Soutenir le créateur',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 12,
//                           fontWeight: FontWeight.w500,
//                         ),
//                       ),
//                       if (count > 0) ...[
//                         SizedBox(width: 6),
//                         Container(
//                           padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//                           decoration: BoxDecoration(
//                             color: _afroYellow.withOpacity(0.2),
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           child: Text(
//                             '$count',
//                             style: TextStyle(
//                               color: _afroYellow,
//                               fontSize: 10,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildQuickStats(Post post) {
//     return Container(
//       padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       decoration: BoxDecoration(
//         color: Colors.black.withOpacity(0.5),
//         borderRadius: BorderRadius.circular(8),
//       ),
//       child: Row(
//         children: [
//           _buildQuickStatItem('👁️', _formatCount(post.vues ?? 0)),
//           SizedBox(width: 8),
//           _buildQuickStatItem('❤️', _formatCount(post.loves ?? 0)),
//           SizedBox(width: 8),
//           _buildQuickStatItem('💬', _formatCount(post.comments ?? 0)),
//           if (_isLookChallenge) ...[
//             SizedBox(width: 8),
//             _buildQuickStatItem('🗳️', _formatCount(post.votesChallenge ?? 0)),
//           ],
//         ],
//       ),
//     );
//   }
//
//   Widget _buildQuickStatItem(String icon, String count) {
//     return Row(
//       children: [
//         Text(icon, style: TextStyle(fontSize: 12)),
//         SizedBox(width: 2),
//         Text(
//           count,
//           style: TextStyle(
//             color: Colors.white,
//             fontSize: 10,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildLookChallengeSection(Post post) {
//     if (!_isLookChallenge) return SizedBox();
//
//     return Positioned(
//       top: 0,
//       left: 16,
//       right: 16,
//       child: Container(
//         padding: EdgeInsets.all(12),
//         decoration: BoxDecoration(
//           color: Colors.black.withOpacity(0.7),
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: _twitterGreen),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Icon(Icons.emoji_events, color: _twitterGreen, size: 20),
//                 SizedBox(width: 8),
//                 Text(
//                   'LOOK CHALLENGE',
//                   style: TextStyle(
//                     color: _twitterGreen,
//                     fontSize: 10,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ],
//             ),
//             SizedBox(height: 8),
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 IconButton(
//                   onPressed: () {
//                     Navigator.pop(context);
//                   },
//                   icon: Icon(Icons.arrow_back, color: Colors.yellow),
//                 ),
//
//                 Text(
//                   '${post.votesChallenge ?? 0} votes',
//                   style: TextStyle(color: Colors.white, fontSize: 12),
//                 ),
//                 if (!_hasVoted && _challenge != null && _challenge!.isEnCours)
//                   ElevatedButton(
//                     onPressed: _isVoting ? null : _showVoteConfirmationDialog,
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: _twitterGreen,
//                       padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                     ),
//                     child: _isVoting
//                         ? SizedBox(
//                       width: 16,
//                       height: 10,
//                       child: CircularProgressIndicator(
//                         strokeWidth: 2,
//                         color: Colors.white,
//                       ),
//                     )
//                         : Text(
//                       'VOTER',
//                       style: TextStyle(
//                           fontSize: 10,
//                           fontWeight: FontWeight.bold,
//                           color: Colors.white
//                       ),
//                     ),
//                   )
//                 else if (_hasVoted)
//                   Container(
//                     padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//                     decoration: BoxDecoration(
//                       color: _twitterGreen.withOpacity(0.2),
//                       borderRadius: BorderRadius.circular(12),
//                       border: Border.all(color: _twitterGreen),
//                     ),
//                     child: Text(
//                       'DÉJÀ VOTÉ',
//                       style: TextStyle(
//                         color: _twitterGreen,
//                         fontSize: 10,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//
//   Widget _buildActionButtons(Post post) {
//     final isLiked = post.users_love_id!.contains(authProvider.loginUserData.id);
//     final hasAccess = _hasAccessToContent(post);
//
//     return Positioned(
//       right: 16,
//       bottom: 90,
//       child: Column(
//         children: [
//           // Avatar utilisateur
//           post.type == PostType.CHALLENGE.name ? SizedBox.shrink() : GestureDetector(
//             onTap: () {
//
//               final user = post.user??_currentUser;
//               final canal = post.canal??_currentCanal;
//
//
//               if (canal != null) {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (context) => CanalDetails(canal: canal),
//                   ),
//                 );
//               }else
//
//                 if (user != null) {
//               showUserDetailsModalDialog(user, MediaQuery.of(context).size.width, MediaQuery.of(context).size.height, context);
//               }
//                         },
//             child: Container(
//               decoration: BoxDecoration(
//                 border: Border.all(color: _afroGreen, width: 2),
//                 shape: BoxShape.circle,
//               ),
//               child: CircleAvatar(
//                 radius: 25,
//                 backgroundImage: NetworkImage(
//                 post.canal?.urlImage ??    post.user?.imageUrl ??'',
//                 ),
//               ),
//             ),
//           ),
//           post.type == PostType.CHALLENGE.name ? SizedBox.shrink() : SizedBox(height: 20),
//
//           // Like
//           Column(
//             children: [
//               if (_isLookChallenge)
//                 Column(
//                   children: [
//                     IconButton(
//                       icon: Icon(
//                         _hasVoted ? Icons.how_to_vote : Icons.how_to_vote_outlined,
//                         color: _hasVoted ? _twitterGreen : Colors.white,
//                         size: 35,
//                       ),
//                       onPressed: hasAccess ? _voteForLook : null,
//                     ),
//                     Text(
//                       _formatCount(post.votesChallenge ?? 0),
//                       style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//                     ),
//                   ],
//                 ),
//               IconButton(
//                 icon: Icon(
//                   isLiked ? Icons.favorite : Icons.favorite_border,
//                   color: isLiked ? _afroRed : Colors.white,
//                   size: 30,
//                 ),
//                 onPressed: () => _handleLike(post) ,
//               ),
//               Text(
//                 _formatCount(post.loves ?? 0),
//                 style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//               ),
//             ],
//           ),
//
//           // Commentaires
//           Column(
//             children: [
//               IconButton(
//                 icon: Icon(Icons.chat_bubble_outline, color: Colors.white, size: 33),
//                 onPressed: hasAccess ? () => _showCommentsModal(post) : null,
//               ),
//               Text(
//                 _formatCount(post.comments ?? 0),
//                 style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//               ),
//             ],
//           ),
//
//           // Cadeaux
//           post.type == PostType.CHALLENGEPARTICIPATION .name ? SizedBox.shrink() :   Column(
//             children: [
//               IconButton(
//                 icon: Icon(Icons.card_giftcard, color: _afroYellow, size: 30),
//                 onPressed: hasAccess ? () => _showGiftDialog(post) : null,
//               ),
//               Text(
//                 _formatCount(post.users_cadeau_id?.length ?? 0),
//                 style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//               ),
//             ],
//           ),
//
//           // Vue
//           Column(
//             children: [
//               IconButton(
//                 icon: Icon(Icons.remove_red_eye_rounded, color: Colors.white, size: 35),
//                 onPressed: hasAccess ? () {} : null,
//               ),
//               Text(
//                 _formatCount(post.vues ?? 0),
//                 style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//               ),
//             ],
//           ),
//           // Vue
//           Column(
//             children: [
//               IconButton(
//                 icon: Icon(Icons.bar_chart, color: Colors.blue, size: 35),
//                 onPressed: hasAccess ? () {} : null,
//               ),
//               Text(
//                 _formatCount(post.totalInteractions ?? 0),
//                 style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//               ),
//             ],
//           ),    // Vue
//           Column(
//             children: [
//               // Partager
//               _isSharing
//                   ? const SizedBox(
//                 width: 40, // Ajustez selon la taille de vos boutons
//                 height: 40,
//                 child: Padding(
//                   padding: EdgeInsets.all(8.0),
//                   child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber), // ou votre couleur _afroTextSecondary
//                 ),
//               )
//                   : IconButton(
//                 icon: Icon(Icons.share, color: Colors.white, size: 30),
//                 onPressed: hasAccess ? () => _sharePost() : null,
//               ),
//               Text(
//                 _formatCount(post.partage ?? 0),
//                 style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
//               ),
//             ],
//           ),
//
//
//
//           // Menu
//           IconButton(
//             icon: Icon(Icons.more_vert, color: Colors.white, size: 30),
//             onPressed: hasAccess ? () => _showPostMenu(post) : null,
//           ),
//         ],
//       ),
//     );
//   }
//
//   // ==================== MÉTHODES D'INTERACTION ====================
//
//   Future<void> _handleLike2(Post post) async {
//     try {
//       if (!post.users_love_id!.contains(authProvider.loginUserData.id)) {
//         await _firestore.collection('Posts').doc(post.id).update({
//           'loves': FieldValue.increment(1),
//           'users_love_id': FieldValue.arrayUnion([authProvider.loginUserData.id!]),
//         });
//
//         await postProvider.interactWithPostAndIncrementSolde(
//             post.id!,
//             authProvider.loginUserData.id!,
//             "like",
//             post.user_id!
//         );
//       }
//     } catch (e) {
//       print('Erreur like: $e');
//     }
//   }
//
//   Future<void> _handleLike(Post post) async {
//     try {
//       if (!post.users_love_id!.contains(authProvider.loginUserData.id)) {
//         // ✅ Mise à jour du post (toujours effectuée)
//         await _firestore.collection('Posts').doc(post.id).update({
//           'loves': FieldValue.increment(1),
//           'users_love_id': FieldValue.arrayUnion([authProvider.loginUserData.id!]),
//         });
//         widget.initialPost.users_love_id!.add(authProvider.loginUserData.id!);
//
//         postProvider.interactWithPostAndIncrementSolde(
//             post.id!,
//             authProvider.loginUserData.id!,
//             "like",
//             post.user_id!
//         );
//
//         // ✅ Récupérer l'utilisateur qui a créé le post
//         final userDoc = await _firestore.collection('Users').doc(post.user_id).get();
//
//         if (userDoc.exists) {
//           final userData = userDoc.data();
//           final currentTimeMicroseconds = DateTime.now().microsecondsSinceEpoch;
//
//           // ✅ Récupérer le dernier timestamp de notification
//           final lastNotificationTime = userData?['lastNotificationTime'] ?? 0;
//
//           // 20 minutes en microsecondes = 20 * 60 * 1000 * 1000
//           const twentyMinutesMicroseconds = 20 * 60 * 1000 * 1000;
//           final timeSinceLastNotification = currentTimeMicroseconds - lastNotificationTime;
//
//           // ✅ Vérification si 20 minutes se sont écoulées
//           if (timeSinceLastNotification >= twentyMinutesMicroseconds || lastNotificationTime == 0) {
//
//             // =====================================================
//             // ✅ 1. ENREGISTRER LA NOTIFICATION DANS FIREBASE
//             // =====================================================
//             final notificationId = _firestore.collection('Notifications').doc().id;
//
//             final notification = NotificationData(
//               id: notificationId,
//               titre: "Like ❤️",
//               media_url: authProvider.loginUserData.imageUrl,
//               type: NotificationType.POST.name,
//               description: "@${authProvider.loginUserData.pseudo!} a aimé votre post",
//               users_id_view: [],
//               user_id: authProvider.loginUserData.id!,
//               receiver_id: post.user_id!,
//               post_id: post.id!,
//               post_data_type: post.dataType ?? PostDataType.IMAGE.name,
//               updatedAt: currentTimeMicroseconds,
//               createdAt: currentTimeMicroseconds,
//               status: PostStatus.VALIDE.name,
//             );
//
//             // Sauvegarder la notification
//             await _firestore.collection('Notifications').doc(notificationId).set(notification.toJson());
//             print("✅ Notification Firebase enregistrée pour @${userData?['pseudo']}");
//
//             // =====================================================
//             // ✅ 2. ENVOYER LA PUSH NOTIFICATION (OneSignal)
//             // =====================================================
//             if (userData?['oneIgnalUserid'] != null &&
//                 (userData!['oneIgnalUserid'] as String).isNotEmpty) {
//
//               await authProvider.sendNotification(
//                 userIds: [userData['oneIgnalUserid']],
//                 smallImage: authProvider.loginUserData.imageUrl!,
//                 send_user_id: authProvider.loginUserData.id!,
//                 recever_user_id: post.user_id!,
//                 message: "📢 @${authProvider.loginUserData.pseudo!} a aimé votre post",
//                 type_notif: NotificationType.POST.name,
//                 post_id: post.id!,
//                 post_type: post.dataType ?? PostDataType.IMAGE.name,
//                 chat_id: '',
//               );
//               print("✅ Push notification envoyée à @${userData['pseudo']}");
//             }
//
//             // =====================================================
//             // ✅ 3. METTRE À JOUR LE TIMESTAMP
//             // =====================================================
//             await _firestore.collection('Users').doc(post.user_id).update({
//               'lastNotificationTime': currentTimeMicroseconds
//             });
//
//           } else {
//             // ⏱️ LIMITE ATTEINTE - NI NOTIFICATION NI PUSH
//             final minutesPassed = (timeSinceLastNotification / (60 * 1000 * 1000)).toStringAsFixed(1);
//             final minutesRemaining = ((twentyMinutesMicroseconds - timeSinceLastNotification) / (60 * 1000 * 1000)).toStringAsFixed(1);
//
//             print("⏱️ Notification limitée pour @${userData?['pseudo']} - Dernière notification il y a $minutesPassed min");
//             print("⏱️ Prochaine notification possible dans $minutesRemaining min");
//           }
//           setState(() {
//
//           });
//            authProvider. incrementPostTotalInteractions(postId: widget.initialPost.id!);
//
//           authProvider. notifySubscribersOfInteraction(
//             actionUserId: authProvider.loginUserData.id!,
//             postOwnerId: widget.initialPost.user_id!,
//             postId: widget.initialPost.id!,
//             actionType: 'like',
//             postDescription: widget.initialPost.description,
//             postImageUrl: widget.initialPost.thumbnail!=null?widget.initialPost.thumbnail:'',
//             postDataType: widget.initialPost.dataType,
//           );
//         }
//       }
//     } catch (e) {
//       print('❌ Erreur like: $e');
//     }
//   }
//
//   void _showCommentsModal(Post post) {
//     authProvider. incrementPostTotalInteractions(postId:post.id!);
//
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) => Container(
//         height: MediaQuery.of(context).size.height * 0.85,
//         decoration: BoxDecoration(
//           color: _afroBlack,
//           borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//         ),
//         child: Column(
//           children: [
//             Container(
//               padding: EdgeInsets.all(16),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     'Commentaires',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   IconButton(
//                     icon: Icon(Icons.close, color: Colors.white),
//                     onPressed: () => Navigator.pop(context),
//                   ),
//                 ],
//               ),
//             ),
//             Expanded(
//               child: PostComments(post: post),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   void _showInsufficientBalanceDialog() {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return AlertDialog(
//           backgroundColor: Colors.black,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(20),
//             side: BorderSide(color: Colors.yellow, width: 2),
//           ),
//           title: Text(
//             'Solde Insuffisant',
//             style: TextStyle(
//               color: Colors.yellow,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           content: Text(
//             'Votre solde est insuffisant pour effectuer cette action. Veuillez recharger votre compte.',
//             style: TextStyle(color: Colors.white),
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: Text('Annuler', style: TextStyle(color: Colors.white)),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 Navigator.pop(context);
//                 Navigator.push(context, MaterialPageRoute(builder: (context) => DepositScreen()));
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.green,
//               ),
//               child: Text('Recharger', style: TextStyle(color: Colors.black)),
//             ),
//           ],
//         );
//       },
//     );
//   }
//
//   void _showGiftDialog(Post post) {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         final height = MediaQuery.of(context).size.height * 0.6;
//         return StatefulBuilder(
//           builder: (context, setState) {
//             return Dialog(
//               backgroundColor: Colors.black,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(20),
//                 side: BorderSide(color: Colors.yellow, width: 2),
//               ),
//               child: Container(
//                 height: height,
//                 padding: EdgeInsets.all(16),
//                 child: Column(
//                   children: [
//                     Text(
//                       'Envoyer un Cadeau',
//                       style: TextStyle(
//                         color: Colors.yellow,
//                         fontWeight: FontWeight.bold,
//                         fontSize: 20,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                     SizedBox(height: 12),
//                     Text(
//                       'Choisissez le montant en FCFA',
//                       style: TextStyle(color: Colors.white),
//                     ),
//                     SizedBox(height: 12),
//                     Expanded(
//                       child: GridView.builder(
//                         physics: BouncingScrollPhysics(),
//                         gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                           crossAxisCount: 3,
//                           crossAxisSpacing: 10,
//                           mainAxisSpacing: 10,
//                           childAspectRatio: 0.8,
//                         ),
//                         itemCount: giftPrices.length,
//                         itemBuilder: (context, index) {
//                           return GestureDetector(
//                             onTap: () => setState(() => _selectedGiftIndex = index),
//                             child: Container(
//                               padding: EdgeInsets.all(10),
//                               decoration: BoxDecoration(
//                                 color: _selectedGiftIndex == index
//                                     ? Colors.green
//                                     : Colors.grey[800],
//                                 borderRadius: BorderRadius.circular(10),
//                                 border: Border.all(
//                                   color: _selectedGiftIndex == index
//                                       ? Colors.yellow
//                                       : Colors.transparent,
//                                   width: 1,
//                                 ),
//                               ),
//                               child: Column(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Text(
//                                     giftIcons[index],
//                                     style: TextStyle(fontSize: 24),
//                                   ),
//                                   SizedBox(height: 5),
//                                   Text(
//                                     '${giftPrices[index].toInt()} FCFA',
//                                     style: TextStyle(
//                                       fontSize: 12,
//                                       color: Colors.white,
//                                       fontWeight: FontWeight.bold,
//                                     ),
//                                     textAlign: TextAlign.center,
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//                     ),
//                     SizedBox(height: 12),
//                     Text(
//                       'Votre solde: ${authProvider.loginUserData.votre_solde_principal?.toInt() ?? 0} FCFA',
//                       style: TextStyle(
//                         color: Colors.yellow,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     SizedBox(height: 12),
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         TextButton(
//                           onPressed: () => Navigator.pop(context),
//                           child: Text('Annuler', style: TextStyle(color: Colors.white)),
//                         ),
//                         ElevatedButton(
//                           onPressed: () {
//                             Navigator.pop(context);
//                             _sendGift(giftPrices[_selectedGiftIndex], post);
//                           },
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: Colors.green,
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(10),
//                             ),
//                           ),
//                           child: Text(
//                             'Envoyer',
//                             style: TextStyle(color: Colors.black),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         );
//       },
//     );
//   }
//
//   Future<void> _sendGift(double amount, Post post) async {
//     try {
//       setState(() => _isLoading = true);
//
//       final firestore = FirebaseFirestore.instance;
//       await authProvider.getAppData();
//
//       final senderSnap = await firestore.collection('Users').doc(authProvider.loginUserData.id).get();
//       if (!senderSnap.exists) {
//         throw Exception("Utilisateur expéditeur introuvable");
//       }
//
//       final senderData = senderSnap.data() as Map<String, dynamic>;
//       final double senderBalance = (senderData['votre_solde_principal'] ?? 0.0).toDouble();
//
//       if (senderBalance >= amount) {
//         final double gainDestinataire = amount * 0.7;
//         final double gainApplication = amount * 0.3;
//
//         await firestore.collection('Users').doc(authProvider.loginUserData.id).update({
//           'votre_solde_principal': FieldValue.increment(-amount),
//         });
//
//         await firestore.collection('Users').doc(post.user!.id).update({
//           'votre_solde_principal': FieldValue.increment(gainDestinataire),
//         });
//
//         String appDataId = authProvider.appDefaultData.id!;
//         await firestore.collection('AppData').doc(appDataId).update({
//           'solde_gain': FieldValue.increment(gainApplication),
//         });
//
//         await firestore.collection('Posts').doc(post.id).update({
//           'users_cadeau_id': FieldValue.arrayUnion([authProvider.loginUserData.id]),
//           'popularity': FieldValue.increment(5),
//         });
//
//         await _createTransaction(TypeTransaction.DEPENSE.name, amount, "Cadeau envoyé à @${post.user!.pseudo}", authProvider.loginUserData.id!);
//         await _createTransaction(TypeTransaction.GAIN.name, gainDestinataire, "Cadeau reçu de @${authProvider.loginUserData.pseudo}", post.user_id!);
//
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             backgroundColor: Colors.green,
//             content: Text(
//               '🎁 Cadeau de ${amount.toInt()} FCFA envoyé avec succès!',
//               style: TextStyle(color: Colors.white),
//             ),
//           ),
//         );
//
//         await authProvider.sendNotification(
//           userIds: [post.user!.oneIgnalUserid!],
//           smallImage: "",
//           send_user_id: "",
//           recever_user_id: "${post.user_id!}",
//           message: "🎁 Vous avez reçu un cadeau de ${amount.toInt()} FCFA !",
//           type_notif: NotificationType.POST.name,
//           post_id: "${post.id!}",
//           post_type: PostDataType.VIDEO.name,
//           chat_id: '',
//         );
//       } else {
//         _showInsufficientBalanceDialog();
//       }
//     } catch (e) {
//       print("Erreur envoi cadeau: $e");
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           backgroundColor: Colors.red,
//           content: Text(
//             'Erreur lors de l\'envoi du cadeau',
//             style: TextStyle(color: Colors.white),
//           ),
//         ),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
//
//   Future<void> _createTransaction(String type, double montant, String description, String userid) async {
//     try {
//       final transaction = TransactionSolde()
//         ..id = _firestore.collection('TransactionSoldes').doc().id
//         ..user_id = userid
//         ..type = type
//         ..statut = StatutTransaction.VALIDER.name
//         ..description = description
//         ..montant = montant
//         ..methode_paiement = "cadeau"
//         ..createdAt = DateTime.now().millisecondsSinceEpoch
//         ..updatedAt = DateTime.now().millisecondsSinceEpoch;
//
//       await _firestore.collection('TransactionSoldes').doc(transaction.id).set(transaction.toJson());
//     } catch (e) {
//       print("Erreur création transaction: $e");
//     }
//   }
//   // Méthodes utilitaires globales
//   bool isIn(List<String> list, String value) {
//     return list.contains(value);
//   }
//
//   void _sharePost() async {
//     // Activer le mode chargement
//     setState(() {
//       _isSharing = true;
//     });
//
//     try {
//       // 1. GESTION DU THUMBNAIL POUR LES VIDÉOS
//       if (widget.initialPost.dataType == "VIDEO" &&
//           (widget.initialPost.thumbnail == null || widget.initialPost.thumbnail!.isEmpty)) {
//         // On attend la fin de la génération avant de continuer
//         await checkAndGenerateThumbnail(
//           postId: widget.initialPost.id!,
//           videoUrl: widget.initialPost.url_media!,
//           currentThumbnail: widget.initialPost.thumbnail,
//         );
//       }
//
//       // 2. PRÉPARATION DU PARTAGE
//       String shareImageUrl = "";
//       if (widget.initialPost.dataType == "VIDEO") {
//         shareImageUrl = widget.initialPost.thumbnail ?? "";
//       } else {
//         shareImageUrl = (widget.initialPost.images?.isNotEmpty ?? false)
//             ? widget.initialPost.images!.first
//             : "";
//       }
//
//       final AppLinkService _appLinkService = AppLinkService();
//       await _appLinkService.shareContent(
//         type: AppLinkType.post,
//         id: widget.initialPost.id!,
//         message: widget.initialPost.description ?? "",
//         mediaUrl: shareImageUrl,
//       );
//
//       // 3. MISE À JOUR FIREBASE & UI (Code existant)
//       setState(() {
//         widget.initialPost.partage = (widget.initialPost.partage ?? 0) + 1;
//         widget.initialPost.users_partage_id!.add(authProvider.loginUserData.id!);
//       });
//
//       await _firestore.collection('Posts').doc(widget.initialPost.id).update({
//         'partage': FieldValue.increment(1),
//         'users_partage_id':
//         FieldValue.arrayUnion([authProvider.loginUserData.id]),
//       });
//
//       authProvider.checkAndRefreshPostDates(widget.initialPost.id!);
//
//       if (!isIn(
//           widget.initialPost.users_partage_id!, authProvider.loginUserData.id!)) {
//         addPointsForAction(UserAction.partagePost);
//         addPointsForOtherUserAction(widget.initialPost.user_id!, UserAction.autre);
//
//
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(
//               '+ de points ajoutés à votre compte',
//               textAlign: TextAlign.center,
//               style: TextStyle(color: Colors.green),
//             ),
//           ),
//         );
//       }
//       authProvider. incrementPostTotalInteractions(postId: widget.initialPost.id!);
//
//       authProvider. notifySubscribersOfInteraction(
//         actionUserId: authProvider.loginUserData.id!,
//         postOwnerId: widget.initialPost.user_id!,
//         postId: widget.initialPost.id!,
//         actionType: 'share',
//         postDescription: widget.initialPost.description,
//         postImageUrl: widget.initialPost.images?.first,
//         postDataType: widget.initialPost.dataType,
//       );
//     } catch (e) {
//       print("Erreur partage: $e");
//     } finally {
//       // Désactiver le chargement même en cas d'erreur
//       if (mounted) {
//         setState(() {
//           _isSharing = false;
//         });
//       }
//     }
//   }
//
//   Future<void> _sharePost2(Post post) async {
//     final AppLinkService _appLinkService = AppLinkService();
//     _appLinkService.shareContent(
//       type: AppLinkType.post,
//       id: post.id!,
//       message: post.description ?? "",
//       mediaUrl: post.url_media ?? "",
//     );
//
//
//     setState(() {
//       widget.initialPost.partage =widget.initialPost.partage! + 1;
//      widget.initialPost.users_partage_id!.add(authProvider.loginUserData.id!);
//     });
//
//     await _firestore.collection('Posts').doc(widget.initialPost.id).update({
//       'partage': FieldValue.increment(1),
//       'users_partage_id': FieldValue.arrayUnion([authProvider.loginUserData.id]),
//     });
//     if (!isIn(widget.initialPost.users_partage_id!, authProvider.loginUserData.id!)) {
//       addPointsForAction(UserAction.partagePost);
//       addPointsForOtherUserAction(post.user_id!, UserAction.autre);
//     }
//   }
//
//   void _showPostMenu(Post post) {
//     final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     final postProvider = Provider.of<PostProvider>(context, listen: false);
//
//     showModalBottomSheet(
//       context: context,
//       backgroundColor: _twitterCardBg,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
//       ),
//       builder: (context) => Container(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             if (post.user_id != authProvider.loginUserData.id)
//               _buildMenuOption(
//                 Icons.flag,
//                 "Signaler",
//                 _twitterTextPrimary,
//                     () async {
//                   post.status = PostStatus.SIGNALER.name;
//                   final value = await postProvider.updateVuePost(post, context);
//                   Navigator.pop(context);
//
//                   final snackBar = SnackBar(
//                     content: Text(
//                       value ? 'Post signalé !' : 'Échec du signalement !',
//                       textAlign: TextAlign.center,
//                       style: TextStyle(color: value ? Colors.green : Colors.red),
//                     ),
//                   );
//                   ScaffoldMessenger.of(context).showSnackBar(snackBar);
//                 },
//               ),
//
//             if (post.user!.id == authProvider.loginUserData.id ||
//                 authProvider.loginUserData.role == UserRole.ADM.name)
//               _buildMenuOption(
//                 Icons.delete,
//                 "Supprimer",
//                 Colors.red,
//                     () async {
//                   if (authProvider.loginUserData.role == UserRole.ADM.name) {
//                     await _deletePost(post, context);
//                   } else {
//                     post.status = PostStatus.SUPPRIMER.name;
//                     await _deletePost(post, context);
//                   }
//                   Navigator.pop(context);
//
//                   final snackBar = SnackBar(
//                     content: Text(
//                       'Post supprimé !',
//                       textAlign: TextAlign.center,
//                       style: TextStyle(color: Colors.green),
//                     ),
//                   );
//                   ScaffoldMessenger.of(context).showSnackBar(snackBar);
//                 },
//               ),
//
//             SizedBox(height: 8),
//             Container(height: 0.5, color: _twitterTextSecondary.withOpacity(0.3)),
//             SizedBox(height: 8),
//
//             _buildMenuOption(Icons.cancel, "Annuler", _twitterTextSecondary, () {
//               Navigator.pop(context);
//             }),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildMenuOption(IconData icon, String text, Color color, VoidCallback onTap) {
//     return Material(
//       color: Colors.transparent,
//       child: InkWell(
//         onTap: onTap,
//         child: Container(
//           padding: EdgeInsets.symmetric(vertical: 16),
//           child: Row(
//             children: [
//               Icon(icon, color: color, size: 20),
//               SizedBox(width: 12),
//               Text(text, style: TextStyle(color: color, fontSize: 16)),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Future<void> _deletePost(Post post, BuildContext context) async {
//     try {
//       final canDelete = authProvider.loginUserData.role == UserRole.ADM.name ||
//           (post.type == PostType.POST.name &&
//               post.user?.id == authProvider.loginUserData.id);
//
//       if (!canDelete) return;
//
//       await _firestore.collection('Posts').doc(post.id).delete();
//       // 🔹 Retirer l'ID de allPostIds
//       final appDefaultRef = _firestore.collection('AppData').doc(appId); // Remplace par ton docId réel
//
//       await appDefaultRef.update({
//         'allPostIds': FieldValue.arrayRemove([post.id]),
//       });
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             'Post supprimé !',
//             textAlign: TextAlign.center,
//             style: TextStyle(color: Colors.green),
//           ),
//         ),
//       );
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             'Échec de la suppression !',
//             textAlign: TextAlign.center,
//             style: TextStyle(color: Colors.red),
//           ),
//         ),
//       );
//       print('Erreur suppression post: $e');
//     }
//   }
//
//   String _formatCount(int count) {
//     if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
//     if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
//     return count.toString();
//   }
//
//   // ==================== BUILD PRINCIPAL ====================
//
//   Widget _buildVideoPage(Post post) {
//     final isLocked = _isLockedContent(post);
//     final hasAccess = _hasAccessToContent(post);
//
//     if (isLocked) {
//       return _buildLockedContent(post);
//     }
//
//     return Stack(
//       children: [
//         // Lecteur vidéo
//         _buildVideoPlayer(post),
//
//         // Informations utilisateur
//         _buildUserInfo(post),
//
//         // Section Look Challenge
//         _buildLookChallengeSection(post),
//
//         // Boutons d'action
//         _buildActionButtons(post),
//         if (widget.isIn)
//           Positioned(
//             top: MediaQuery.of(context).padding.top + 16,
//             left: 16,
//             child: Row(
//               children: [
//                 IconButton(
//                   onPressed: () {
//                     Navigator.pop(context);
//                   },
//                   icon: Icon(Icons.arrow_back, color: Colors.yellow),
//                 ),
//                 Text(
//                   'Afrolook',
//                   style: TextStyle(
//                     color: _afroGreen,
//                     fontSize: 24,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//         // Indicateur de chargement suivant
//         if (_isLoadingMore)
//           Positioned(
//             bottom: 100,
//             left: 0,
//             right: 0,
//             child: Center(
//               child: CircularProgressIndicator(color: _afroGreen),
//             ),
//           ),
//       ],
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: [
//         Scaffold(
//           backgroundColor: _afroBlack,
//           body: _isLoading
//               ? Center(child: CircularProgressIndicator(color: _afroGreen))
//               : PageView.builder(
//             controller: _pageController,
//             scrollDirection: Axis.vertical,
//             itemCount: _videoPosts.length + (_hasMoreVideos ? 1 : 0),
//             onPageChanged: (index) async {
//               if (index >= _videoPosts.length - 2 && _hasMoreVideos && !_isLoadingMore) {
//                 await _loadMoreVideos();
//               }
//
//               if (index < _videoPosts.length) {
//                 setState(() => _currentPage = index);
//                 _initializeVideo(_videoPosts[index]);
//               }
//             },
//             itemBuilder: (context, index) {
//               if (index >= _videoPosts.length) {
//                 return Center(
//                   child: CircularProgressIndicator(color: _afroGreen),
//                 );
//               }
//
//               final post = _videoPosts[index];
//               return _buildVideoPage(post);
//             },
//           ),
//         ),
//
//         // 👉 PUB AU-DESSUS
//         if (_showRewardedAd)
//           RewardedAdWidget(
//             key: _rewardedAdKey,
//             onUserEarnedReward: (reward) async {
//               final currentPost = _videoPosts[_currentPage];
//               await _onSupportAdRewarded(currentPost);
//             },
//             onAdDismissed: () {
//               setState(() {
//                 _showRewardedAd = false;
//                 _isSupporting = false;
//               });
//             },
//             child: const SizedBox.shrink(),
//           ),
//       ],
//     );
//   }
//
// }
