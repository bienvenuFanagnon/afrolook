import 'dart:async';
import 'dart:math';
import 'package:afrotok/pages/canaux/listCanal.dart';
import 'package:afrotok/pages/challenge/postChallengeWidget.dart';

import 'package:flutter/material.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:afrotok/constant/constColors.dart';
import 'package:afrotok/constant/logo.dart';
import 'package:afrotok/constant/sizeText.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/userProvider.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter/services.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:popup_menu_plus/popup_menu_plus.dart';
import 'package:provider/provider.dart';
import 'package:random_color/random_color.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:upgrader/upgrader.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constant/custom_theme.dart';
import '../UserServices/ServiceWidget.dart';
import '../UserServices/listUserService.dart';
import '../UserServices/newUserService.dart';
import '../afroshop/marketPlace/acceuil/home_afroshop.dart';
import '../afroshop/marketPlace/component.dart';
import '../afroshop/marketPlace/modalView/bottomSheetModalView.dart';
import '../auth/authTest/Screens/Welcome/welcome_screen.dart';
import '../component/showUserDetails.dart';
import '../../constant/textCustom.dart';
import '../../models/chatmodels/message.dart';
import '../../providers/afroshop/authAfroshopProvider.dart';
import '../../providers/afroshop/categorie_produits_provider.dart';
import '../../providers/authProvider.dart';
import 'package:shimmer/shimmer.dart';
import '../component/consoleWidget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../user/conponent.dart';
import '../userPosts/postWidgets/postWidgetPage.dart';
import 'package:visibility_detector/visibility_detector.dart';

const Color primaryGreen = Color(0xFF25D366);
const Color darkBackground = Color(0xFF121212);
const Color lightBackground = Color(0xFF1E1E1E);
const Color textColor = Colors.white;

class HomeConstPostPage extends StatefulWidget {
   HomeConstPostPage({super.key, required this.type, this.sortType});

  final String type;
   String? sortType;

  @override
  State<HomeConstPostPage> createState() => _HomeConstPostPageState();
}

class _HomeConstPostPageState extends State<HomeConstPostPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // Variables principales
  late UserAuthProvider authProvider;
  late UserShopAuthProvider authProviderShop;
  late CategorieProduitProvider categorieProduitProvider;
  late UserProvider userProvider;
  late PostProvider postProvider;

  final ScrollController _scrollController = ScrollController();
  final Random _random = Random();
  Color _color = Colors.blue;

  // Paramètres de pagination
  final int _initialLimit = 5;
  final int _loadMoreLimit = 5;
  final int _totalPostsLimit = 1000; // Limite totale des posts

  // États des posts
  List<Post> _posts = [];
  bool _isLoadingPosts = true;
  bool _hasErrorPosts = false;
  bool _isLoadingMorePosts = false;
  bool _hasMorePosts = true;
  DocumentSnapshot? _lastPostDocument;

  // Compteurs
  int _totalPostsLoaded = 0;
  int _totalPostsInDatabase = 1000;

  // Gestion de la visibilité
  final Map<String, Timer> _visibilityTimers = {};
  final Map<String, bool> _postsViewedInSession = {};

  // Autres données
  List<ArticleData> articles = [];
  List<UserServiceData> userServices = [];
  List<Canal> canaux = [];
  List<UserData> userList = [];
  late Future<List<UserData>> _futureUsers = Future.value([]);

  // Contrôleurs et clés
  TextEditingController commentController = TextEditingController();
  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool _buttonEnabled = true;
  RandomColor _randomColor = RandomColor();
  int postLenght = 8;
  int limiteUsers = 200;
  bool is_actualised = false;
  late AnimationController _starController;
  late AnimationController _unlikeController;

  @override
  void initState() {
    super.initState();

    // Initialisation des providers
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    authProviderShop = Provider.of<UserShopAuthProvider>(context, listen: false);
    categorieProduitProvider = Provider.of<CategorieProduitProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);
printVm('widget.sortType : ${widget.sortType}');
    // Configuration initiale
    _initializeData();
    _setupLifecycleObservers();
    _initializeAnimations();
    _setupScrollController();
  }

  void _setupScrollController() {
    _scrollController.addListener(_scrollListener);
  }

  void _setupLifecycleObservers() {
    WidgetsBinding.instance.addObserver(this);
    SystemChannels.lifecycle.setMessageHandler((message) {
      _handleAppLifecycle(message);
      return Future.value(message);
    });
  }

  void _initializeAnimations() {
    _starController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _unlikeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
  }

  void _initializeData() async {

    // Chargement des données supplémentaires
    _futureUsers = userProvider.getProfileUsers(
      authProvider.loginUserData.id!,
      context,
      limiteUsers,
    );
    // await _getTotalPostsCount(); // Obtenir le nombre total de posts d'abord
    if (widget.sortType != null) {
       _loadInitialPosts(widget.sortType);
    } else {
       _loadInitialPosts('null');
    }



     _loadAdditionalData();
    _checkAndShowDialog();
  }

  Future<void> _loadAdditionalData() async {
    try {
      await authProvider.getAppData();

      final articleResults = await categorieProduitProvider.getArticleBooster();
      final serviceResults = await postProvider.getAllUserServiceHome();
      final canalResults = await postProvider.getCanauxHome();

      setState(() {
        articles = articleResults;
        userServices = serviceResults..shuffle();
        canaux = canalResults..shuffle();
      });
    } catch (e) {
      print('Error loading additional data: $e');
    }
  }

  // OBTENIR LE NOMBRE TOTAL DE POSTS
  Future<void> _getTotalPostsCount() async {
    try {
      final query = FirebaseFirestore.instance.collection('Posts')
          .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
          .where("type", isEqualTo: PostType.POST.name);

      final snapshot = await query.count().get();
      _totalPostsInDatabase = snapshot.count!;

      print('📊 Total posts in database: $_totalPostsInDatabase');
      print('🎯 Posts limit: $_totalPostsLimit');

    } catch (e) {
      print('Error getting total posts count: $e');
      _totalPostsInDatabase = 0;
    }
  }

  // GESTION DE LA PAGINATION ET CHARGEMENT DES POSTS

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMorePosts &&
        _hasMorePosts &&
        _totalPostsLoaded < _totalPostsLimit) {
      _loadMorePosts();
    }
  }

  Future<void> _loadInitialPosts(String? sortT) async {
    try {
      setState(() {
        _isLoadingPosts = true;
        _hasErrorPosts = false;
        _postsViewedInSession.clear();
        _totalPostsLoaded = 0;
      });

      _lastPostDocument = null;

      final currentUserId = authProvider.loginUserData.id;

      // Sélection de l'algorithme en fonction du sortType
      if (sortT == 'null') {
        await _loadUnseenPostsFirst(currentUserId);
      }else if (sortT == 'recent') {
        await _loadRecentPosts(isInitialLoad: true);
      } else if (sortT== 'popular') {
        await _loadPopularPosts(isInitialLoad: true);
      } else {
        await _loadUnseenPostsFirst(currentUserId);
      }

      setState(() {
        _isLoadingPosts = false;
      });

    } catch (e) {
      print('Error loading initial posts: $e');
      setState(() {
        _isLoadingPosts = false;
        _hasErrorPosts = true;
      });
    }
  }

  Future<void> _loadRecentPosts({bool isInitialLoad = true}) async {
    try {
      final limit = isInitialLoad ? _initialLimit : _loadMoreLimit;

      Query query = FirebaseFirestore.instance.collection('Posts')
          // .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
          // .where("type", isEqualTo: PostType.POST.name)
          .where("type", whereIn: [PostType.POST.name, PostType.CHALLENGEPARTICIPATION.name])

          .orderBy("created_at", descending: true);

      if (_lastPostDocument != null && !isInitialLoad) {
        query = query.startAfterDocument(_lastPostDocument!);
      }

      query = query.limit(limit);

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastPostDocument = snapshot.docs.last;
      }

      final newPosts = snapshot.docs.map((doc) {
        final post = Post.fromJson(doc.data() as Map<String, dynamic>);
        post.id = doc.id;
        post.hasBeenSeenByCurrentUser = _checkIfPostSeen(post);
        return post;
      }).toList();

      if (isInitialLoad) {
        _posts = newPosts;
        _totalPostsLoaded = newPosts.length;
      } else {
        _posts.addAll(newPosts);
        _totalPostsLoaded += newPosts.length;
      }

      // Vérifier s'il reste des posts à charger
      _hasMorePosts = newPosts.length == limit && _totalPostsLoaded < _totalPostsLimit;

      print('📥 Chargement ${isInitialLoad ? 'initial' : 'supplémentaire'}: ${newPosts.length} posts');
      print('📊 Total chargé: $_totalPostsLoaded / $_totalPostsLimit');
      print('🎯 Has more posts: $_hasMorePosts');

    } catch (e) {
      print('Error loading recent posts: $e');
      _hasMorePosts = false;
    }
  }

  Future<void> _loadPopularPosts({bool isInitialLoad = true}) async {
    try {
      final limit = isInitialLoad ? _initialLimit : _loadMoreLimit;
      Query query = FirebaseFirestore.instance.collection('Posts')
          // .where("type", isEqualTo: PostType.POST.name)
          .where("type", whereIn: [PostType.POST.name, PostType.CHALLENGEPARTICIPATION.name])

          .orderBy("vues", descending: true)
          .orderBy("created_at", descending: true);

      // Query query = FirebaseFirestore.instance.collection('Posts')
      //     .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
      //     .where("type", isEqualTo: PostType.POST.name)
      //     .orderBy("vues", descending: true)
      //     .orderBy("created_at", descending: true);

      printVm("Début du chargement _lastPostDocument: ${_lastPostDocument}");
      printVm("Début du chargement isInitialLoad: ${isInitialLoad}");

      if (_lastPostDocument != null && !isInitialLoad) {
        query = query.startAfterDocument(_lastPostDocument!);
      }

      query = query.limit(limit);

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastPostDocument = snapshot.docs.last;
      }

      final newPosts = snapshot.docs.map((doc) {
        final post = Post.fromJson(doc.data() as Map<String, dynamic>);
        post.id = doc.id;
        post.hasBeenSeenByCurrentUser = _checkIfPostSeen(post);
        return post;
      }).toList();

      if (isInitialLoad) {
        _posts = newPosts;
        _totalPostsLoaded = newPosts.length;
      } else {

        _posts.addAll(newPosts);
        _totalPostsLoaded += newPosts.length;
      }

      _hasMorePosts = newPosts.length == limit && _totalPostsLoaded < _totalPostsLimit;

      print('📥 Chargement populaire ${isInitialLoad ? 'initial' : 'supplémentaire'}: ${newPosts.length} posts');
      print('📊 Total chargé: $_totalPostsLoaded / $_totalPostsLimit');

    } catch (e) {
      print('Error loading popular posts: $e');
      _hasMorePosts = false;
    }
  }

  Future<void> _loadUnseenPostsFirst(String? currentUserId) async {
    if (currentUserId == null) {
      await _loadRecentPosts(isInitialLoad: true);
      return;
    }

    try {
      // 🔹 1. Récupérer AppData et UserData
      final appData = await _getAppData();
      final userData = await _getUserData(currentUserId);

      final allPostIds = appData.allPostIds ?? [];
      final viewedPostIds = userData.viewedPostIds ?? [];

      print('🔹 Total posts dans AppData: ${allPostIds.length}');
      print('🔹 Posts vus par l\'utilisateur: ${viewedPostIds.length}');

      // 🔹 2. Identifier les posts non vus
      final unseenPostIds = allPostIds
          .where((postId) => !viewedPostIds.contains(postId))
          .toList();

      print('🔹 Posts non vus identifiés: ${unseenPostIds.length}');

      List<Post> loadedPosts = [];

      if (unseenPostIds.isNotEmpty) {
        // 🔹 3. Charger les posts non vus
        final unseenPosts = await _loadPostsByIds(
          List<String>.from(unseenPostIds.reversed),
          limit: _initialLimit,
          isSeen: false,
        );
        loadedPosts.addAll(unseenPosts);
      }

      // 🔹 4. Si on n'a pas assez de posts, compléter avec des posts vus
      if (loadedPosts.length < _initialLimit) {
        final remaining = _initialLimit - loadedPosts.length;
        final seenPostIds = viewedPostIds
            .where((postId) => !loadedPosts.any((p) => p.id == postId))
            .take(remaining)
            .toList();

        if (seenPostIds.isNotEmpty) {
          final seenPosts = await _loadPostsByIds(
            seenPostIds,
            limit: remaining,
            isSeen: true,
          );
          loadedPosts.addAll(seenPosts);
        }
      }

      // 🔹 5. Tri final par date
      loadedPosts.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));

      // 🔹 6. Limiter au nombre exact demandé
      loadedPosts = loadedPosts.take(_initialLimit).toList();

      _posts = loadedPosts;
      _totalPostsLoaded = loadedPosts.length;

      // 🔹 7. Mettre à jour le dernier document pour pagination
      if (_posts.isNotEmpty) {
        final lastPostId = _posts.last.id;
        if (lastPostId != null) {
          _lastPostDocument = await FirebaseFirestore.instance
              .collection('Posts')
              .doc(lastPostId)
              .get();
        }
      }

      _hasMorePosts = _totalPostsLoaded < _totalPostsLimit;

      print('✅ Chargement terminé. Total posts: ${_posts.length}');
      print('📊 Stats: ${_posts.where((p) => !p.hasBeenSeenByCurrentUser!).length} non vus');
      print('🎯 Has more posts: $_hasMorePosts');

    } catch (e, stack) {
      print('❌ Erreur lors du chargement des posts non vus: $e');
      print(stack);
      // Fallback: charger les posts récents
      await _loadRecentPosts(isInitialLoad: true);
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMorePosts || !_hasMorePosts || _totalPostsLoaded >= _totalPostsLimit) {
      print('🛑 Chargement bloqué - isLoading: $_isLoadingMorePosts, hasMore: $_hasMorePosts, total: $_totalPostsLoaded/$_totalPostsLimit');
      return;
    }

    print('🔄 Début du chargement supplémentaire...');

    setState(() {
      _isLoadingMorePosts = true;
    });

    try {
      final currentUserId = authProvider.loginUserData.id;

      if (widget.sortType == 'recent') {
        await _loadRecentPosts(isInitialLoad: false);
      } else if (widget.sortType == 'popular') {
        await _loadPopularPosts(isInitialLoad: false);
      } else {
        await _loadMorePostsByDate(currentUserId);
      }

      print('✅ Chargement supplémentaire terminé - $_totalPostsLoaded posts au total');

    } catch (e) {
      print('❌ Erreur chargement supplémentaire: $e');
      setState(() {
        _hasMorePosts = false;
      });
    } finally {
      setState(() {
        _isLoadingMorePosts = false;
      });
    }
  }

  Future<void> _loadMorePostsByDate(String? currentUserId) async {
    try {
      if (currentUserId == null) {
        await _loadRecentPosts(isInitialLoad: false);
        return;
      }

      // 🔹 Récupérer les données nécessaires
      final appData = await _getAppData();
      final userData = await _getUserData(currentUserId);

      final allPostIds = appData.allPostIds ?? [];
      final viewedPostIds = userData.viewedPostIds ?? [];

      // 🔹 Identifier les posts non vus non encore chargés
      final alreadyLoadedPostIds = _posts.map((p) => p.id).toSet();
      final unseenPostIds = allPostIds.where((postId) =>
      !viewedPostIds.contains(postId) && !alreadyLoadedPostIds.contains(postId)).toList();

      print('🔹 Posts non vus restants: ${unseenPostIds.length}');

      List<Post> newPosts = [];

      // 🔹 Charger les posts non vus suivants
      if (unseenPostIds.isNotEmpty) {
        final unseenPosts = await _loadPostsByIds(unseenPostIds, limit: _loadMoreLimit, isSeen: false);
        newPosts.addAll(unseenPosts);
        print('🔹 Posts non vus supplémentaires chargés: ${unseenPosts.length}');
      }

      // 🔹 Compléter avec des posts vus si nécessaire
      if (newPosts.length < _loadMoreLimit) {
        final remainingLimit = _loadMoreLimit - newPosts.length;

        // Charger des posts vus non encore chargés
        final seenPostIdsToLoad = viewedPostIds
            .where((postId) => !alreadyLoadedPostIds.contains(postId))
            .take(remainingLimit)
            .toList();

        if (seenPostIdsToLoad.isNotEmpty) {
          final seenPosts = await _loadPostsByIds(seenPostIdsToLoad, limit: remainingLimit, isSeen: true);
          newPosts.addAll(seenPosts);
          print('🔹 Posts vus supplémentaires chargés: ${seenPosts.length}');
        }
      }

      // 🔹 Ajouter les nouveaux posts à la liste
      _posts.addAll(newPosts);
      _totalPostsLoaded += newPosts.length;

      // 🔹 Mettre à jour le dernier document pour la pagination
      if (_posts.isNotEmpty) {
        final lastPostId = _posts.last.id;
        if (lastPostId != null) {
          final lastDoc = await FirebaseFirestore.instance.collection('Posts').doc(lastPostId).get();
          _lastPostDocument = lastDoc;
        }
      }

      _hasMorePosts = newPosts.length >= _loadMoreLimit && _totalPostsLoaded < _totalPostsLimit;

      print('✅ Chargement supplémentaire terminé. Nouveaux posts: ${newPosts.length}');
      print('📊 Total posts chargés: $_totalPostsLoaded / $_totalPostsLimit');
      print('🎯 Has more posts: $_hasMorePosts');

    } catch (e, stack) {
      print('❌ Erreur chargement supplémentaire des posts: $e');
      print(stack);
      _hasMorePosts = false;
    }
  }

  // 🔹 Méthode utilitaire pour charger des posts par leurs IDs
  Future<List<Post>> _loadPostsByIds(List<String> postIds, {required int limit, required bool isSeen}) async {
    if (postIds.isEmpty) return [];

    final posts = <Post>[];
    final idsToLoad = postIds.take(limit).toList();

    print('🔹 Chargement de ${idsToLoad.length} posts par ID (isSeen: $isSeen)');

    for (var i = 0; i < idsToLoad.length; i += 10) {
      final batchIds = idsToLoad.skip(i).take(10).where((id) => id.isNotEmpty).toList();
      if (batchIds.isEmpty) continue;

      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('Posts')
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();

        for (var doc in snapshot.docs) {
          try {
            final post = Post.fromJson(doc.data());
            post.id = doc.id;
            post.hasBeenSeenByCurrentUser = isSeen;
            posts.add(post);
          } catch (e) {
            print('⚠️ Erreur parsing post ${doc.id}: $e');
          }
        }
      } catch (e) {
        print('❌ Erreur batch chargement posts: $e');
      }
    }

    // 🔹 TRI par date la plus récente
    posts.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));

    return posts;
  }

  Future<AppDefaultData> _getAppData() async {
    try {
      final appDataRef = FirebaseFirestore.instance.collection('AppData').doc('XgkSxKc10vWsJJ2uBraT');
      final appDataSnapshot = await appDataRef.get();

      if (appDataSnapshot.exists) {
        return AppDefaultData.fromJson(appDataSnapshot.data() ?? {});
      }

      return AppDefaultData(allPostIds: []);
    } catch (e) {
      print('Error getting AppData: $e');
      return AppDefaultData(allPostIds: []);
    }
  }

  Future<UserData> _getUserData(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('Users').doc(userId).get();

      if (userDoc.exists) {
        return UserData.fromJson(userDoc.data() as Map<String, dynamic>);
      }

      return UserData(viewedPostIds: []);
    } catch (e) {
      print('Error getting UserData: $e');
      return UserData(viewedPostIds: []);
    }
  }

  // GESTION DE LA VISIBILITÉ ET DES VUES

  bool _checkIfPostSeen(Post post) {
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null || post.id == null) return false;

    // Vérifier dans la session courante
    if (_postsViewedInSession.containsKey(post.id)) {
      return _postsViewedInSession[post.id]!;
    }

    // Vérifier dans les données utilisateur
    if (authProvider.loginUserData.viewedPostIds?.contains(post.id!) ?? false) {
      return true;
    }

    // Vérifier dans les vues du post
    if (post.users_vue_id?.contains(currentUserId) ?? false) {
      return true;
    }

    return false;
  }

  void _handleVisibilityChanged(Post post, VisibilityInfo info) {
    final postId = post.id!;
    _visibilityTimers[postId]?.cancel();

    if (info.visibleFraction > 0.5) {
      _visibilityTimers[postId] = Timer(Duration(milliseconds: 500), () {
        if (mounted && info.visibleFraction > 0.5) {
          _recordPostView(post);
        }
      });
    } else {
      _visibilityTimers.remove(postId);
    }
  }

  Future<void> _recordPostView(Post post) async {
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null || post.id == null) return;

    // Vérifier si déjà enregistré dans cette session
    if (_postsViewedInSession.containsKey(post.id!)) {
      return;
    }

    try {
      // Marquer comme vu dans la session
      _postsViewedInSession[post.id!] = true;

      // Mettre à jour localement
      setState(() {
        post.hasBeenSeenByCurrentUser = true;
        post.vues = (post.vues ?? 0) + 1;
        post.users_vue_id ??= [];
        if (!post.users_vue_id!.contains(currentUserId)) {
          post.users_vue_id!.add(currentUserId);
        }
      });

      // Mettre à jour Firestore (de manière asynchrone)
      final batch = FirebaseFirestore.instance.batch();

      // Mettre à jour le compteur de vues du post
      final postRef = FirebaseFirestore.instance.collection('Posts').doc(post.id);
      batch.update(postRef, {
        'vues': FieldValue.increment(1),
        'users_vue_id': FieldValue.arrayUnion([currentUserId]),
      });

      // Mettre à jour les posts vus par l'utilisateur
      final userRef = FirebaseFirestore.instance.collection('Users').doc(currentUserId);
      batch.update(userRef, {
        'viewedPostIds': FieldValue.arrayUnion([post.id!]),
      });

      await batch.commit();

      // Mettre à jour les données locales de l'utilisateur
      authProvider.loginUserData.viewedPostIds ??= [];
      if (!authProvider.loginUserData.viewedPostIds!.contains(post.id!)) {
        authProvider.loginUserData.viewedPostIds!.add(post.id!);
      }

    } catch (e) {
      print('Error recording post view: $e');
      // Annuler le marquage local en cas d'erreur
      _postsViewedInSession.remove(post.id!);
    }
  }

  // WIDGETS PRINCIPAUX

  Widget _buildPostWithVisibilityDetection(Post post, double width, double height) {
    final hasUserSeenPost = post.hasBeenSeenByCurrentUser ?? false;

    return VisibilityDetector(
      key: Key('post-${post.id}'),
      onVisibilityChanged: (VisibilityInfo info) {
        _handleVisibilityChanged(post, info);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: darkBackground.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
          border: (!hasUserSeenPost && widget.sortType=="recent"&& widget.sortType=="popular")
              ? Border.all(color: Colors.green, width: 2)
              : null,
        ),
        child: Stack(
          children: [
            post.type==PostType.CHALLENGEPARTICIPATION.name? LookChallengePostWidget(post: post, height: height, width: width)
           : HomePostUsersWidget(
              post: post,
              color: _color,
              height: height * 0.6,
              width: width,
              isDegrade: true,
            ),
            if (!hasUserSeenPost)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fiber_new, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Nouveau',
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
      ),
    );
  }

  Widget _buildContentScroll(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    // GESTION DES ÉTATS DE CHARGEMENT
    if (_isLoadingPosts && _posts.isEmpty) {
      return _buildLoadingShimmer(width, height);
    }

    if (_hasErrorPosts && _posts.isEmpty) {
      return _buildErrorWidget();
    }

    if (_posts.isEmpty) {
      return _buildEmptyWidget();
    }

    // Construire les posts avec boosters et canaux
    List<Widget> postWidgets = [];
    for (int i = 0; i < _posts.length; i++) {
      // Ajouter le post actuel
      postWidgets.add(
        GestureDetector(
          onTap: () => _navigateToPostDetails(_posts[i]),
          child: _buildPostWithVisibilityDetection(_posts[i], width, height),
        ),
      );

      // Après chaque 3 posts, alterner entre articles et canaux
      if ((i + 1) % 3 == 0) {
        // Pair : Articles boosters (après 3, 9, 15... posts)
        // Impair : Canaux (après 6, 12, 18... posts)
        final cycleIndex = (i + 1) ~/ 3;

        if (cycleIndex % 2 == 1 && articles.isNotEmpty) {
          // Articles après 3, 9, 15... posts (cycles impairs)
          postWidgets.add(_buildBoosterPage(context));
        } else if (cycleIndex % 2 == 0 && canaux.isNotEmpty) {
          // Canaux après 6, 12, 18... posts (cycles pairs)
          postWidgets.add(_buildCanalPage(context));
        }
      }
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Section profils utilisateurs
        SliverToBoxAdapter(
          child: _buildProfilesSection(),
        ),

        // Section posts (liste principale)
        SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) => postWidgets[index],
            childCount: postWidgets.length,
          ),
        ),

        // Indicateur de chargement
        if (_isLoadingMorePosts)
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: CircularProgressIndicator(color: Colors.green),
              ),
            ),
          )
        // Indicateur de fin
        else if (!_hasMorePosts || _totalPostsLoaded >= _totalPostsLimit)
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Vous avez vu tous les contenus',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            ),
          ),
      ],
    );
  }
// AJOUTER CES MÉTHODES DANS VOTRE CLASSE

  Widget _buildLoadingShimmer(double width, double height) {
    return CustomScrollView(
      slivers: [
        // Shimmer pour la section profils
        SliverToBoxAdapter(
          child: Container(
            height: 120,
            margin: EdgeInsets.all(8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              itemBuilder: (context, index) {
                return Container(
                  width: width * 0.22,
                  margin: EdgeInsets.all(4),
                  child: Shimmer.fromColors(
                    baseColor: Colors.grey[800]!,
                    highlightColor: Colors.grey[700]!,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        // Shimmer pour les posts
        SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              return Container(
                margin: EdgeInsets.all(8),
                child: Shimmer.fromColors(
                  baseColor: Colors.grey[800]!,
                  highlightColor: Colors.grey[700]!,
                  child: Container(
                    height: 400,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              );
            },
            childCount: 3,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 50),
          SizedBox(height: 16),
          Text(
            'Erreur de chargement',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              // Recharger les données
              _initializeData();
            },
            child: Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.feed, color: Colors.grey, size: 50),
          SizedBox(height: 16),
          Text(
            'Aucun contenu disponible',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsSection(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    if (_isLoadingPosts) {
      return _buildPostsShimmerEffect(width, height);
    }

    if (_hasErrorPosts) {
      return _buildErrorWidget();
    }

    if (_posts.isEmpty) {
      return _buildEmptyWidget();
    }

    List<Widget> postWidgets = [];

    // Construction de la liste des posts avec intégration des boosters et canaux
    for (int i = 0; i < _posts.length; i++) {
      // Ajouter un booster tous les 9 posts
      if (i % 9 == 8 && articles.isNotEmpty) {
        postWidgets.add(_buildBoosterPage(context));
      }

      // Ajouter un canal tous les 7 posts
      if (i % 7 == 6 && canaux.isNotEmpty) {
        postWidgets.add(_buildCanalPage(context));
      }

      // Ajouter le post
      postWidgets.add(
        GestureDetector(
          onTap: () => _navigateToPostDetails(_posts[i]),
          child: _buildPostWithVisibilityDetection(_posts[i], width, height),
        ),
      );
    }

    return SizedBox(
      height: height, // nécessaire pour CustomScrollView
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // En-tête de section
          SliverToBoxAdapter(child: _buildSectionHeader()),

          // Liste des posts
          SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) => postWidgets[index],
              childCount: postWidgets.length,
            ),
          ),

          // Indicateurs de chargement/fin
          if (_isLoadingMorePosts)
            SliverToBoxAdapter(child: _buildLoadingIndicator())
          else if (!_hasMorePosts || _totalPostsLoaded >= _totalPostsLimit)
            SliverToBoxAdapter(child: _buildEndIndicator()),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    String title = 'Derniers Looks';
    if (widget.sortType == 'recent') title = 'Looks Récents';
    if (widget.sortType == 'popular') title = 'Looks Populaires';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          // if (widget.sortType == null)
            IconButton(
              icon: Icon(Icons.filter_list, color: primaryGreen),
              onPressed: _showFilterOptions,
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          LoadingAnimationWidget.flickr(
            size: 40,
            leftDotColor: primaryGreen,
            rightDotColor: accentYellow,
          ),
          SizedBox(height: 10),
          Text(
            'Chargement de plus de looks...',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEndIndicator() {
    String message = '';

    if (_totalPostsLoaded >= _totalPostsLimit) {
      message = 'Vous avez atteint la limite de visionnage (${_totalPostsLimit} looks)';
    } else if (!_hasMorePosts) {
      message = 'Vous avez vu tous les looks disponibles pour le moment';
    }

    return Container(
      padding: EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline, color: primaryGreen, size: 50),
          SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Revenez plus tard pour découvrir de nouveaux looks !',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildPostsShimmerEffect(double width, double height) {
    return Column(
      children: List.generate(3, (index) =>
          Container(
            margin: EdgeInsets.only(bottom: 16),
            padding: EdgeInsets.all(12),
            child: Shimmer.fromColors(
              baseColor: Colors.grey[800]!,
              highlightColor: Colors.grey[600]!,
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(backgroundColor: Colors.grey[700], radius: 20),
                      SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: width * 0.4, height: 14, color: Colors.grey[700]),
                          SizedBox(height: 6),
                          Container(width: width * 0.3, height: 12, color: Colors.grey[700]),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Container(width: double.infinity, height: height * 0.3, color: Colors.grey[700]),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(3, (i) =>
                        Container(width: width * 0.2, height: 14, color: Colors.grey[700]),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ),
    );
  }

  // WIDGETS DES SECTIONS SUPPLÉMENTAIRES

  Widget _buildProfilesSection() {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return FutureBuilder<List<UserData>>(
      future: _futureUsers,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || snapshot.hasError) {
          return SizedBox(
            // height: height * 0.35,
            child: _buildShimmerEffect(width, height),
          );
        } else {
          List<UserData> list = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 16, bottom: 8),
                child: Text(
                  'Profils à découvrir',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              SizedBox(
                height: height * 0.3,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: list.length,
                  itemBuilder: (context, index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    width: width * 0.35,
                    child: homeProfileUsers(list[index], width, height),
                  ),
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildBoosterPage(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('🔥 Produits Boostés',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HomeAfroshopPage(title: ''))),
                  child: Row(
                    children: [
                      Text('Boutiques', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryGreen)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, color: primaryGreen, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: height * 0.25,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: articles.length,
              itemBuilder: (context, index) => Container(
                margin: EdgeInsets.symmetric(horizontal: 8),
                width: width * 0.6,
                child: ProductWidget(
                  article: articles[index],
                  width: width * 0.6,
                  height: height * 0.25,
                  isOtherPage: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanalPage(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('📺 Afrolook Canal',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CanalListPage(isUserCanals: false))),
                  child: Row(
                    children: [
                      Text('Voir plus', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryGreen)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, color: primaryGreen, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: height * 0.18,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: canaux.length,
              itemBuilder: (context, index) => Container(
                margin: EdgeInsets.symmetric(horizontal: 8),
                width: width * 0.3,
                child: channelWidget(canaux[index],
                height * 0.28,
                    width * 0.28,
                    context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerEffect(double width, double height) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[900]!,
      highlightColor: Colors.grey[700]!,
      period: Duration(milliseconds: 1500),
      child: Container(
        width: width * 0.22,
        height: width * 0.22,
        margin: EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryGreen.withOpacity(0.2)),
        ),
      ),
    );
  }

  // WIDGETS EXISTANTS

  Widget homeProfileUsers(UserData user, double w, double h) {
    List<String> userAbonnesIds = user.userAbonnesIds ?? [];
    bool alreadySubscribed = userAbonnesIds.contains(authProvider.loginUserData.id);

    return Container(
      decoration: BoxDecoration(
        color: darkBackground.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryGreen.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () async {
              await authProvider.getUserById(user.id!).then((users) async {
                if (users.isNotEmpty) {
                  showUserDetailsModalDialog(users.first, w, h, context);
                }
              });
            },
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  width: w * 0.4,
                  height: h * 0.2,
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: CachedNetworkImage(
                      fit: BoxFit.cover,
                      imageUrl: user.imageUrl ?? '',
                      progressIndicatorBuilder: (context, url, downloadProgress) =>
                          Container(
                            color: Colors.grey[800],
                            child: Center(
                              child: CircularProgressIndicator(
                                value: downloadProgress.progress,
                                color: primaryGreen,
                              ),
                            ),
                          ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[800],
                        child: Icon(Icons.person, color: Colors.grey[400], size: 40),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: w * 0.4,
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black87, Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '@${user.pseudo!.startsWith('@') ? user.pseudo!.substring(1) : user.pseudo!}',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (user.isVerify!) Icon(Icons.verified, color: primaryGreen, size: 14),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.group, size: 10, color: accentYellow),
                              SizedBox(width: 2),
                              Text(
                                formatNumber(user.userAbonnesIds?.length ?? 0),
                                style: TextStyle(
                                  color: accentYellow,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          countryFlag(user.countryData?['countryCode'] ?? "", size: 16),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!alreadySubscribed)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: ElevatedButton(
                onPressed: () async {
                  await authProvider.getUserById(user.id!).then((users) async {
                    if (users.isNotEmpty) {
                      showUserDetailsModalDialog(users.first, w, h, context);
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryGreen,
                  foregroundColor: darkBackground,
                  padding: EdgeInsets.symmetric(vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'S\'abonner',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }


  // MÉTHODES D'INTERACTION

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: darkBackground,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Trier par', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.new_releases, color: primaryGreen),
              title: Text('Posts non vus en premier', style: TextStyle(color: textColor)),
              onTap: () {
                Navigator.pop(context);
                _applyFilter(null);
              },
            ),
            ListTile(
              leading: Icon(Icons.trending_up, color: Colors.orange),
              title: Text('Posts populaires', style: TextStyle(color: textColor)),
              onTap: () {
                widget.sortType = "popular";

                Navigator.pop(context);
                _applyFilter('popular');
              },
            ),
            ListTile(
              leading: Icon(Icons.access_time, color: Colors.blue),
              title: Text('Posts récents', style: TextStyle(color: textColor)),
              onTap: () {
                widget.sortType = "recent";
                Navigator.pop(context);

                _applyFilter('recent');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _applyFilter(String? sortType) {
    // Dans une implémentation réelle, vous reconstruiriez le widget avec le nouveau sortType
    // Pour l'instant, on recharge simplement avec le nouveau filtre
    // _loadInitialPosts(sortType!);
    // _initializeData(sortType!);
    _loadInitialPosts(sortType!);
  }

  void _navigateToPostDetails(Post post) {
    _recordPostView(post);
    // Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailsPage(post: post)));
  }

  Future<void> _refreshData() async {
    setState(() {
      _posts = [];
      _futureUsers  = Future.value([]);
      _hasMorePosts = true;
      _lastPostDocument = null;
      _totalPostsLoaded = 0;
      _postsViewedInSession.clear();
      _visibilityTimers.forEach((key, timer) => timer.cancel());
      _visibilityTimers.clear();
    });
    _futureUsers = userProvider.getProfileUsers(
      authProvider.loginUserData.id!,
      context,
      limiteUsers,
    );
    // await _getTotalPostsCount(); // Recalculer le total
    if(widget.sortType!=null){
      await _loadInitialPosts(widget.sortType!);

    }else{
      await _loadInitialPosts("null");

    }}

  // MÉTHODES UTILITAIRES

  String formatNumber(int number) {
    if (number >= 1000) {
      double nombre = number / 1000;
      return nombre.toStringAsFixed(1) + 'k';
    } else {
      return number.toString();
    }
  }

  Widget countryFlag(String countryCode, {double size = 24}) {
    if (countryCode.isEmpty) return SizedBox.shrink();

    try {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.asset(
            'assets/flags/${countryCode.toLowerCase()}.png',
            package: 'country_icons',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Icon(Icons.flag, size: size - 8),
          ),
        ),
      );
    } catch (e) {
      return Icon(Icons.flag, size: size - 8, color: Colors.grey);
    }
  }

  void _handleAppLifecycle(String? message) {
    if (message?.contains('resume') == true) {
      _setUserOnline();
    } else {
      _setUserOffline();
    }
  }

  void _setUserOnline() {
    if (authProvider.loginUserData != null) {
      authProvider.loginUserData!.isConnected = true;
      userProvider.changeState(
          user: authProvider.loginUserData,
          state: UserState.ONLINE.name
      );
    }
  }

  void _setUserOffline() {
    if (authProvider.loginUserData != null) {
      authProvider.loginUserData!.isConnected = false;
      userProvider.changeState(
          user: authProvider.loginUserData,
          state: UserState.OFFLINE.name
      );
    }
  }

  void _changeColor() {
    final colors = [Colors.blue, Colors.green, Colors.brown, Colors.blueAccent, Colors.red, Colors.yellow];
    _color = colors[_random.nextInt(colors.length)];
  }

  Future<void> _checkAndShowDialog() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    bool shouldShow = await hasShownDialogToday();

    if (shouldShow && mounted) {
      // Votre logique pour afficher le dialogue
    }
  }

  Future<bool> hasShownDialogToday() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String lastShownDateKey = 'lastShownDialogDate2';
    DateTime now = DateTime.now();
    String nowDate = DateFormat('dd, MMMM, yyyy').format(now);

    if (prefs.getString(lastShownDateKey) == null ||
        prefs.getString(lastShownDateKey) != nowDate) {
      prefs.setString(lastShownDateKey, nowDate);
      return true;
    } else {
      return false;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _visibilityTimers.forEach((key, timer) => timer.cancel());
    _starController.dispose();
    _unlikeController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _changeColor();

    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: darkBackground,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.black,
          title: Text(
            'Découvrir',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.white),
              onPressed: _refreshData,
            ),
          ],
        ),
        body: SafeArea(
          child: Container(
            decoration: BoxDecoration(
color: Colors.black            ),
            child: _buildContentScroll(context), // <-- ici
          ),
        ),
      ),
    );
  }
}