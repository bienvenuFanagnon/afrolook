import 'dart:async';
import 'dart:math';
import 'package:afrotok/pages/paiement/newDepot.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:afrotok/pages/postComments.dart';
import 'package:afrotok/pages/user/monetisation.dart';
import 'package:afrotok/services/linkService.dart';

const _twitterDarkBg = Color(0xFF000000);
const _twitterCardBg = Color(0xFF16181C);
const _twitterTextPrimary = Color(0xFFFFFFFF);
const _twitterTextSecondary = Color(0xFF71767B);
const _twitterBlue = Color(0xFF1D9BF0);
const _twitterRed = Color(0xFFF91880);
const _twitterGreen = Color(0xFF00BA7C);
const _twitterYellow = Color(0xFFFFD400);

// Couleurs Afrolook
const _afroBlack = Color(0xFF000000);
const _afroGreen = Color(0xFF2ECC71);
const _afroYellow = Color(0xFFF1C40F);
const _afroRed = Color(0xFFE74C3C);
const _afroDarkGrey = Color(0xFF16181C);
const _afroLightGrey = Color(0xFF71767B);

class VideoTikTokPage extends StatefulWidget {
  final Post initialPost;

  const VideoTikTokPage({Key? key, required this.initialPost}) : super(key: key);

  @override
  _VideoTikTokPageState createState() => _VideoTikTokPageState();
}

class _VideoTikTokPageState extends State<VideoTikTokPage> {
  late PageController _pageController;
  late UserAuthProvider authProvider;
  late PostProvider postProvider;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Paramètres de chargement
  final int _initialLimit = 5;
  final int _loadMoreLimit = 5;

  List<Post> _videoPosts = [];
  int _currentPage = 0;

  // Gestion des vidéos
  VideoPlayerController? _currentVideoController;
  ChewieController? _chewieController;
  bool _isVideoInitialized = false;

  // États de chargement
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreVideos = true;
  int _totalVideoCount = 1000;
  int _selectedGiftIndex = 0;
  int _selectedRepostPrice = 25;
  // Données pour la pagination intelligente
  List<String> _allVideoPostIds = [];
  List<String> _viewedVideoPostIds = [];
  DocumentSnapshot? _lastDocument;


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
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.yellow, width: 2),
          ),
          title: Text(
            'Solde Insuffisant',
            style: TextStyle(
              color: Colors.yellow,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Votre solde est insuffisant pour effectuer cette action. Veuillez recharger votre compte.',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Annuler', style: TextStyle(color: Colors.white)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Naviguer vers la page de recharge
                Navigator.push(context, MaterialPageRoute(builder: (context) => DepositScreen()));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: Text('Recharger', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  // Stream pour les mises à jour en temps réel
  final Map<String, StreamSubscription<DocumentSnapshot>> _postSubscriptions = {};

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);

    _pageController = PageController();
    _loadInitialVideos();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _disposeCurrentVideo();
    _postSubscriptions.forEach((key, subscription) => subscription.cancel());
    super.dispose();
  }

  void _disposeCurrentVideo() {
    _chewieController?.dispose();
    _currentVideoController?.dispose();
    setState(() {
      _isVideoInitialized = false;
    });
  }

  Future<void> _loadInitialVideos() async {
    try {
      setState(() => _isLoading = true);

      // Charger les données nécessaires
      await Future.wait([
        _getTotalVideoCount(),
        _getAppData(),
        _getUserData(),
      ]);

      // Commencer avec la vidéo initiale
      _videoPosts = [widget.initialPost];

      // Marquer la vidéo initiale comme vue
      await _markPostAsSeen(widget.initialPost);

      // Charger les vidéos suivantes avec priorité aux non vues
      await _loadMoreVideos(isInitialLoad: true);

      // Initialiser la première vidéo
      if (_videoPosts.isNotEmpty) {
        _initializeVideo(_videoPosts.first);
      }
    } catch (e) {
      print('Erreur chargement initial: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getTotalVideoCount() async {
    try {
      final query = _firestore.collection('Posts')
          .where('postDataType', isEqualTo: PostDataType.VIDEO.name)
          .where('status', isEqualTo: PostStatus.VALIDE.name);

      final snapshot = await query.count().get();
      _totalVideoCount = snapshot.count ?? 1000;
      print('Nombre total de vidéos: $_totalVideoCount');
    } catch (e) {
      print('Erreur comptage vidéos: $e');
      _totalVideoCount = 1000;
    }
  }

  Future<void> _getAppData() async {
    try {
      final appDataRef = _firestore.collection('AppData').doc('XgkSxKc10vWsJJ2uBraT');
      final appDataSnapshot = await appDataRef.get();

      if (appDataSnapshot.exists) {
        final appData = AppDefaultData.fromJson(appDataSnapshot.data() ?? {});
        // Filtrer pour garder seulement les IDs des posts vidéo
        _allVideoPostIds = appData.allPostIds?.where((id) => id.isNotEmpty).toList() ?? [];
        print('IDs vidéo disponibles: ${_allVideoPostIds.length}');
      }
    } catch (e) {
      print('Erreur récupération AppData: $e');
      _allVideoPostIds = [];
    }
  }

  Future<void> _getUserData() async {
    try {
      final currentUserId = authProvider.loginUserData.id;
      if (currentUserId == null) return;

      final userDoc = await _firestore.collection('Users').doc(currentUserId).get();
      if (userDoc.exists) {
        final userData = UserData.fromJson(userDoc.data() as Map<String, dynamic>);
        _viewedVideoPostIds = userData.viewedPostIds?.where((id) => id.isNotEmpty).toList() ?? [];
        print('Vidéos déjà vues: ${_viewedVideoPostIds.length}');
      }
    } catch (e) {
      print('Erreur récupération UserData: $e');
      _viewedVideoPostIds = [];
    }
  }

  Future<void> _loadMoreVideos({bool isInitialLoad = false}) async {
    if (_isLoadingMore || !_hasMoreVideos) return;

    try {
      setState(() => _isLoadingMore = true);

      final currentUserId = authProvider.loginUserData.id;

      if (currentUserId != null && _allVideoPostIds.isNotEmpty) {
        // Utiliser l'algorithme de priorité aux non vus
        await _loadVideosWithPriority(currentUserId, isInitialLoad);
      } else {
        // Fallback: chargement chronologique simple
        await _loadVideosChronologically();
      }

      _hasMoreVideos = _videoPosts.length < _totalVideoCount;

    } catch (e) {
      print('Erreur chargement supplémentaire: $e');
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadVideosWithPriority(String currentUserId, bool isInitialLoad) async {
    // Identifier les vidéos non vues
    final unseenVideoIds = _allVideoPostIds.where((postId) =>
    !_viewedVideoPostIds.contains(postId) &&
        !_videoPosts.any((post) => post.id == postId)
    ).toList();

    // Identifier les vidéos déjà vues
    final seenVideoIds = _allVideoPostIds.where((postId) =>
    _viewedVideoPostIds.contains(postId) &&
        !_videoPosts.any((post) => post.id == postId)
    ).toList();

    print('📊 Vidéos non vues disponibles: ${unseenVideoIds.length}');
    print('📊 Vidéos déjà vues disponibles: ${seenVideoIds.length}');

    final limit = isInitialLoad ? _initialLimit - 1 : _loadMoreLimit; // -1 car on a déjà la vidéo initiale

    // Charger d'abord les non vues
    final unseenVideos = await _loadVideosByIds(unseenVideoIds, limit: limit, isSeen: false);
    print('✅ Vidéos non vues chargées: ${unseenVideos.length}');

    // Compléter avec des vidéos vues si nécessaire
    if (unseenVideos.length < limit) {
      final remainingLimit = limit - unseenVideos.length;
      final seenVideos = await _loadVideosByIds(seenVideoIds, limit: remainingLimit, isSeen: true);
      print('✅ Vidéos vues chargées: ${seenVideos.length}');

      _videoPosts.addAll([...unseenVideos, ...seenVideos]);
    } else {
      _videoPosts.addAll(unseenVideos);
    }

    // Souscrire aux mises à jour pour toutes les nouvelles vidéos
    for (final post in _videoPosts) {
      _subscribeToPostUpdates(post);
    }
  }

  Future<List<Post>> _loadVideosByIds(List<String> videoIds, {required int limit, required bool isSeen}) async {
    if (videoIds.isEmpty || limit <= 0) return [];

    final idsToLoad = videoIds.take(limit).toList();
    final videos = <Post>[];

    print('🔹 Chargement de ${idsToLoad.length} vidéos par ID');

    // Charger par batches de 10 (limite Firebase)
    for (var i = 0; i < idsToLoad.length; i += 10) {
      final batchIds = idsToLoad.skip(i).take(10).where((id) => id.isNotEmpty).toList();
      if (batchIds.isEmpty) continue;

      try {
        final snapshot = await _firestore
            .collection('Posts')
            .where(FieldPath.documentId, whereIn: batchIds)
            .where('postDataType', isEqualTo: PostDataType.VIDEO.name)
            .get();

        for (var doc in snapshot.docs) {
          try {
            final post = Post.fromJson(doc.data() as Map<String, dynamic>);
            post.hasBeenSeenByCurrentUser = isSeen;
            videos.add(post);
          } catch (e) {
            print('⚠️ Erreur parsing vidéo ${doc.id}: $e');
          }
        }
      } catch (e) {
        print('❌ Erreur batch chargement vidéos: $e');
        // Fallback: charger les vidéos une par une
        for (final id in batchIds) {
          try {
            final doc = await _firestore.collection('Posts').doc(id).get();
            if (doc.exists) {
              final post = Post.fromJson(doc.data() as Map<String, dynamic>);
              post.hasBeenSeenByCurrentUser = isSeen;
              videos.add(post);
            }
          } catch (e) {
            print('❌ Erreur chargement vidéo $id: $e');
          }
        }
      }
    }

    return videos;
  }

  Future<void> _loadVideosChronologically() async {
    try {
      Query query = _firestore.collection('Posts')
          .where('postDataType', isEqualTo: PostDataType.VIDEO.name)
          .where('status', isEqualTo: PostStatus.VALIDE.name)
          .orderBy('created_at', descending: true);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.limit(_loadMoreLimit).get();

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }

      final newVideos = snapshot.docs.map((doc) {
        final post = Post.fromJson(doc.data() as Map<String, dynamic>);
        post.hasBeenSeenByCurrentUser = _viewedVideoPostIds.contains(post.id);
        _subscribeToPostUpdates(post);
        return post;
      }).toList();

      // Éviter les doublons
      final existingIds = _videoPosts.map((v) => v.id).toSet();
      final uniqueNewVideos = newVideos.where((video) =>
      video.id != null && !existingIds.contains(video.id)).toList();

      _videoPosts.addAll(uniqueNewVideos);

    } catch (e) {
      print('❌ Erreur chargement chronologique: $e');
    }
  }

  void _subscribeToPostUpdates(Post post) {
    if (post.id == null || _postSubscriptions.containsKey(post.id)) return;

    final subscription = _firestore.collection('Posts').doc(post.id).snapshots().listen((snapshot) {
      if (snapshot.exists && mounted) {
        final updatedPost = Post.fromJson(snapshot.data() as Map<String, dynamic>);

        setState(() {
          final index = _videoPosts.indexWhere((p) => p.id == post.id);
          if (index != -1) {
            // Conserver les données utilisateur/canal et l'état "vu"
            updatedPost.user = _videoPosts[index].user;
            updatedPost.canal = _videoPosts[index].canal;
            updatedPost.hasBeenSeenByCurrentUser = _videoPosts[index].hasBeenSeenByCurrentUser;
            _videoPosts[index] = updatedPost;
          }
        });
      }
    });

    _postSubscriptions[post.id!] = subscription;
  }

  Future<void> _initializeVideo(Post post) async {
    _disposeCurrentVideo();

    if (post.url_media == null || post.url_media!.isEmpty) {
      print('⚠️ Aucune URL média pour la vidéo ${post.id}');
      return;
    }

    try {
      print('🎬 Initialisation vidéo: ${post.url_media}');

      _currentVideoController = VideoPlayerController.network(post.url_media!);
      await _currentVideoController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _currentVideoController!,
        autoPlay: true,
        looping: true,
        // mute: true, // Lecture sans son par défaut
        showControls: false,
        allowFullScreen: false,
        allowMuting: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: _afroGreen,
          handleColor: _afroGreen,
          backgroundColor: _afroLightGrey.withOpacity(0.3),
          bufferedColor: _afroLightGrey.withOpacity(0.1),
        ),
        placeholder: Container(
          color: _afroBlack,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: _afroGreen),
                SizedBox(height: 16),
                Text('Chargement...', style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),
        autoInitialize: true,
      );

      setState(() => _isVideoInitialized = true);

      // Enregistrer la vue immédiatement
      await _recordPostView(post);

    } catch (e) {
      print('❌ Erreur initialisation vidéo: $e');
      setState(() => _isVideoInitialized = false);

      // Fallback: afficher une image de preview si disponible
      if (post.images != null && post.images!.isNotEmpty) {
        // Vous pourriez afficher la première image comme fallback
      }
    }
  }

  Future<void> _markPostAsSeen(Post post) async {
    if (post.id == null) return;

    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null) return;

    try {
      if (!_viewedVideoPostIds.contains(post.id)) {
        _viewedVideoPostIds.add(post.id!);

        // Mettre à jour Firestore
        await _firestore.collection('Users').doc(currentUserId).update({
          'viewedPostIds': FieldValue.arrayUnion([post.id]),
        });

        // Mettre à jour localement
        post.hasBeenSeenByCurrentUser = true;
      }
    } catch (e) {
      print('❌ Erreur marquage post comme vu: $e');
    }
  }

  Future<void> _recordPostView(Post post) async {
    if (post.id == null) return;

    try {
      await _markPostAsSeen(post);

      // Incrémenter le compteur de vues seulement si pas déjà vu
      if (!post.users_vue_id!.contains(authProvider.loginUserData.id)) {
        await _firestore.collection('Posts').doc(post.id).update({
          'vues': FieldValue.increment(1),
          'users_vue_id': FieldValue.arrayUnion([authProvider.loginUserData.id!]),
        });

        // Mettre à jour localement
        post.vues = (post.vues ?? 0) + 1;
        post.users_vue_id!.add(authProvider.loginUserData.id!);
      }
    } catch (e) {
      print('❌ Erreur enregistrement vue: $e');
    }
  }

  // ... (les méthodes _handleLike, _showCommentsModal, _showPostMenu, etc. restent les mêmes)

  Widget _buildVideoPlayer(Post post) {
    if (!_isVideoInitialized) {
      return _buildVideoPlaceholder(post);
    }

    return Stack(
      children: [
        Chewie(controller: _chewieController!),

        // Overlay de contrôle personnalisé
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              if (_chewieController?.isPlaying ?? false) {
                _chewieController?.pause();
              } else {
                _chewieController?.play();
              }
            },
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _chewieController?.isPlaying ?? false ? 0.0 : 1.0,
                  duration: Duration(milliseconds: 300),
                  child: Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Indicateur "Nouveau" pour les vidéos non vues
        if (!post.hasBeenSeenByCurrentUser!)
          Positioned(
            top: 50,
            left: 16,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _afroGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Nouveau',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoPlaceholder(Post post) {
    return Container(
      color: _afroBlack,
      child: Stack(
        children: [
          // Afficher une image de preview si disponible
          if (post.images != null && post.images!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: post.images!.first,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            )
          else
            Container(
              color: _afroDarkGrey,
              child: Center(
                child: Icon(Icons.videocam, color: _afroLightGrey, size: 80),
              ),
            ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: _afroGreen),
                SizedBox(height: 16),
                Text(
                  'Chargement de la vidéo...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _afroBlack,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _afroGreen))
          : PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _videoPosts.length + (_hasMoreVideos ? 1 : 0),
        onPageChanged: (index) async {
          // Précharger les vidéos suivantes
          if (index >= _videoPosts.length - 2 && _hasMoreVideos && !_isLoadingMore) {
            await _loadMoreVideos();
          }

          if (index < _videoPosts.length) {
            setState(() => _currentPage = index);
            _initializeVideo(_videoPosts[index]);
          }
        },
        itemBuilder: (context, index) {
          if (index >= _videoPosts.length) {
            return Center(
              child: CircularProgressIndicator(color: _afroGreen),
            );
          }

          final post = _videoPosts[index];
          return _buildVideoPage(post);
        },
      ),
    );
  }

  Widget _buildVideoPage(Post post) {
    return Stack(
      children: [
        // Lecteur vidéo
        _buildVideoPlayer(post),

        // Informations utilisateur
        _buildUserInfo(post),

        // Boutons d'action
        _buildActionButtons(post),

        // En-tête avec logo Afrolook
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          child: Text(
            'Afrolook',
            style: TextStyle(
              color: _afroGreen,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // Indicateur de son
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          right: 16,
          child: IconButton(
            icon: Icon(
              _chewieController?.isPlaying ?? false ? Icons.volume_off : Icons.volume_up,
              color: Colors.white,
              size: 30,
            ),
            onPressed: () {
              final isMuted = _chewieController?.isPlaying ?? false;
              _chewieController?.setVolume(isMuted ? 1.0 : 0.0);
            },
          ),
        ),

        // Indicateur de chargement suivant
        if (_isLoadingMore)
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Center(
              child: CircularProgressIndicator(color: _afroGreen),
            ),
          ),
      ],
    );
  }


  Future<void> _handleLike(Post post) async {
    try {
      if (!post.users_love_id!.contains(authProvider.loginUserData.id)) {
        await _firestore.collection('Posts').doc(post.id).update({
          'loves': FieldValue.increment(1),
          'users_love_id': FieldValue.arrayUnion([authProvider.loginUserData.id!]),
        });

        // Notification et incrémentation du solde
        await postProvider.interactWithPostAndIncrementSolde(
            post.id!,
            authProvider.loginUserData.id!,
            "like",
            post.user_id!
        );
      }
    } catch (e) {
      print('Erreur like: $e');
    }
  }

  void _showCommentsModal(Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: _afroBlack,
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
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PostComments(post: post),
            ),
          ],
        ),
      ),
    );
  }
  Future<void> deletePost(Post post, BuildContext context) async {
    late UserAuthProvider authProvider =
    Provider.of<UserAuthProvider>(context, listen: false);
    late PostProvider postProvider =
    Provider.of<PostProvider>(context, listen: false);
    try {
      // Vérifie les droits
      final canDelete = authProvider.loginUserData.role == UserRole.ADM.name ||
          (post.type == PostType.POST.name &&
              post.user?.id == authProvider.loginUserData.id);

      if (!canDelete) return;

      // Supprime le document dans Firestore
      await FirebaseFirestore.instance
          .collection('Posts')
          .doc(post.id)
          .delete();

      // SnackBar de succès
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Post supprimé !',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.green),
          ),
        ),
      );
    } catch (e) {
      // SnackBar d'erreur
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Échec de la suppression !',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
      print('Erreur suppression post: $e');
    }
  }

  void _showPostMenu(Post post) {
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final postProvider = Provider.of<PostProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      backgroundColor: _twitterCardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Signaler (si ce n’est pas ton post)
            if (post.user_id != authProvider.loginUserData.id)
              _buildMenuOption(
                Icons.flag,
                "Signaler",
                _twitterTextPrimary,
                    () async {
                  post.status = PostStatus.SIGNALER.name;
                  final value = await postProvider.updateVuePost(post, context);
                  Navigator.pop(context);

                  final snackBar = SnackBar(
                    content: Text(
                      value ? 'Post signalé !' : 'Échec du signalement !',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: value ? Colors.green : Colors.red),
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                },
              ),

            // --- Supprimer (si admin OU propriétaire)
            if (post.user!.id == authProvider.loginUserData.id ||
                authProvider.loginUserData.role == UserRole.ADM.name)
              _buildMenuOption(
                Icons.delete,
                "Supprimer",
                Colors.red,
                    () async {
                  if (authProvider.loginUserData.role == UserRole.ADM.name) {
                    await deletePost(post, context);
                  } else {
                    post.status = PostStatus.SUPPRIMER.name;
                    await deletePost(post, context);
                  }
                  Navigator.pop(context);

                  final snackBar = SnackBar(
                    content: Text(
                      'Post supprimé !',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.green),
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(snackBar);
                },
              ),

            SizedBox(height: 8),
            Container(height: 0.5, color: _twitterTextSecondary.withOpacity(0.3)),
            SizedBox(height: 8),

            // --- Annuler
            _buildMenuOption(Icons.cancel, "Annuler", _twitterTextSecondary, () {
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


  Widget _buildUserInfo(Post post) {
    final user = post.user;
    final canal = post.canal;

    return Positioned(
      bottom: 120,
      left: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (canal != null) ...[
            Text(
              '#${canal.titre ?? ''}',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              '${canal.usersSuiviId?.length ?? 0} abonnés',
              style: TextStyle(color: Colors.white),
            ),
          ] else if (user != null) ...[
            Text(
              '@${user.pseudo ?? ''}',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              '${user.userAbonnesIds?.length ?? 0} abonnés',
              style: TextStyle(color: Colors.white),
            ),
          ],
          SizedBox(height: 8),
          if (post.description != null)
            Container(
              constraints: BoxConstraints(maxWidth: 250),
              child: Text(
                post.description!,
                style: TextStyle(color: Colors.white),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Post post) {
    final isLiked = post.users_love_id!.contains(authProvider.loginUserData.id);

    return Positioned(
      right: 16,
      bottom: 120,
      child: Column(
        children: [
          // Avatar utilisateur
          GestureDetector(
            onTap: () {
              // Navigation vers le profil
            },
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: _afroGreen, width: 2),
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 25,
                backgroundImage: NetworkImage(
                  post.user?.imageUrl ?? post.canal?.urlImage ?? '',
                ),
              ),
            ),
          ),
          SizedBox(height: 20),

          // Like
          Column(
            children: [
              IconButton(
                icon: Icon(
                  isLiked ? Icons.favorite : Icons.favorite_border,
                  color: isLiked ? _afroRed : Colors.white,
                  size: 35,
                ),
                onPressed: () => _handleLike(post),
              ),
              Text(
                _formatCount(post.loves ?? 0),
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 10),

          // Commentaires
          Column(
            children: [
              IconButton(
                icon: Icon(Icons.chat_bubble_outline, color: Colors.white, size: 35),
                onPressed: () => _showCommentsModal(post),
              ),
              Text(
                _formatCount(post.comments ?? 0),
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 10),


          // Cadeaux
          Column(
            children: [
              IconButton(
                icon: Icon(Icons.card_giftcard, color: _afroYellow, size: 35),
                onPressed: () => _showGiftDialog(post),
              ),
              Text(
                _formatCount(post.users_cadeau_id?.length ?? 0),
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 10),
          // Vue
          Column(
            children: [
              IconButton(
                icon: Icon(Icons.remove_red_eye_rounded, color: Colors.white, size: 35),
                onPressed: () {

                },
              ),
              Text(
                _formatCount(post.vues ?? 0),
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 10),

          // Partager
          IconButton(
            icon: Icon(Icons.share, color: Colors.white, size: 35),
            onPressed: () => _sharePost(post),
          ),
          SizedBox(height: 10),

          // Menu
          IconButton(
            icon: Icon(Icons.more_vert, color: Colors.white, size: 35),
            onPressed: () => _showPostMenu(post),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }



  Future<void> _sendGift(double amount) async {
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
        final double gainDestinataire = amount * 0.5;
        final double gainApplication = amount * 0.5;

        // Débiter l’expéditeur
        await firestore.collection('Users').doc(authProvider.loginUserData.id).update({
          'votre_solde_principal': FieldValue.increment(-amount),
        });

        // Créditer le destinataire
        await firestore.collection('Users').doc(widget.initialPost.user!.id).update({
          'votre_solde_principal': FieldValue.increment(gainDestinataire),
        });

        // Créditer l'application
        String appDataId = authProvider.appDefaultData.id!;
        await firestore.collection('AppData').doc(appDataId).update({
          'solde_gain': FieldValue.increment(gainApplication),
        });

        // Ajouter l'expéditeur à la liste des cadeaux du post
        await firestore.collection('Posts').doc(widget.initialPost.id).update({
          'users_cadeau_id': FieldValue.arrayUnion([authProvider.loginUserData.id]),
          'popularity': FieldValue.increment(5), // pondération pour un commentaire

        });

        // Créer les transactions
        // Créer les transactions
        await _createTransaction(TypeTransaction.DEPENSE.name, amount, "Cadeau envoyé à @${widget.initialPost.user!.pseudo}",authProvider.loginUserData.id!);
        await _createTransaction(TypeTransaction.GAIN.name, gainDestinataire, "Cadeau reçu de @${authProvider.loginUserData.pseudo}",widget.initialPost.user_id!);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              '🎁 Cadeau de ${amount.toInt()} FCFA envoyé avec succès!',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
        await authProvider.sendNotification(
          userIds: [widget.initialPost.user!.oneIgnalUserid!],
          smallImage: "", // pas besoin de montrer l'image de l'expéditeur
          send_user_id: "", // pas besoin de l'expéditeur
          recever_user_id: "${widget.initialPost.user_id!}",
          message: "🎁 Vous avez reçu un cadeau de ${amount.toInt()} FCFA !",
          type_notif: NotificationType.POST.name,
          post_id: "${widget.initialPost!.id!}",
          post_type: PostDataType.IMAGE.name,
          chat_id: '',
        );
      } else {
        _showInsufficientBalanceDialog();
      }
    } catch (e) {
      print("Erreur envoi cadeau: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Erreur lors de l\'envoi du cadeau',
            style: TextStyle(color: Colors.white),
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
      builder: (BuildContext context) {
        final height = MediaQuery.of(context).size.height * 0.6; // 60% de l'écran
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.yellow, width: 2),
              ),
              child: Container(
                height: height,
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Envoyer un Cadeau',
                      style: TextStyle(
                        color: Colors.yellow,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Choisissez le montant en FCFA',
                      style: TextStyle(color: Colors.white),
                    ),
                    SizedBox(height: 12),
                    // -----------------------------
                    // Expanded pour GridView scrollable
                    Expanded(
                      child: GridView.builder(
                        physics: BouncingScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3, // 3 colonnes
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
                                    ? Colors.green
                                    : Colors.grey[800],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _selectedGiftIndex == index
                                      ? Colors.yellow
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
                                      color: Colors.white,
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
                        color: Colors.yellow,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Annuler', style: TextStyle(color: Colors.white)),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _sendGift(giftPrices[_selectedGiftIndex]);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Envoyer',
                            style: TextStyle(color: Colors.black),
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
      print("Erreur création transaction: $e");
    }
  }

  Future<void> _sharePost(Post post) async {
    final AppLinkService _appLinkService = AppLinkService();
    _appLinkService.shareContent(
      type: AppLinkType.post,
      id: post.id!,
      message: post.description ?? "",
      mediaUrl: post.url_media ?? "",
    );
  }

}