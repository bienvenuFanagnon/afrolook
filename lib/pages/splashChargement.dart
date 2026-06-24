import 'dart:async';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:intl/intl.dart';

import 'package:video_player/video_player.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../models/chatmodels/message.dart';

import '../theme/app_colors.dart';

import '../models/model_data.dart';

import '../providers/authProvider.dart';

import '../providers/chroniqueProvider.dart';

import '../providers/contenuPayantProvider.dart';

import '../providers/postProvider.dart';

import '../providers/userProvider.dart';

import '../providers/feed_provider.dart';

import '../services/cache/startup_cache_service.dart';

import '../services/feed/feed_repository.dart';

import '../services/utils/afrolook_defaults.dart';

import '../services/nav_cache_service.dart';

import '../services/sessions/session_service.dart';

import 'auth/authTest/Screens/Login/loginPageUser.dart';

import 'auth/authTest/Screens/updateUserData.dart';

import 'home/homeScreen.dart';

class DestinationData {
  final String type;
  final Post? post;
  final Chat? chat;
  final String? chroniqueId;
  final String? chatId;
  final String? sendUserId;
  final String? joinCode;
  DestinationData({required this.type, this.post, this.chat, this.chroniqueId, this.chatId, this.sendUserId, this.joinCode});
}

class SplashChargement extends StatefulWidget {
  const SplashChargement({super.key});
  @override
  State<SplashChargement> createState() => _SplashChargementState();
}

class _SplashChargementState extends State<SplashChargement> {
  late AppColors _colors;
  late UserAuthProvider authProvider;
  late PostProvider postProvider;
  late UserProvider userProvider;
  late ChroniqueProvider chroniqueProvider;
  late ContentProvider contentProvider;
  bool _isCheckingSession = false;

  VideoPlayerController? _controller;
  bool isFinished = false;
  bool isLoadingVideo = true;
  bool shouldPlayVideo = false;
  bool _hasError = false;
  String _loadingText = "Initialisation...";
  String _errorMessage = "";

  bool _isAuthCompleted = false;
  bool _hasNavigated = false;
  bool _isProcessing = false;
  bool _authHandled = false;
  final Completer<void> _cacheReady = Completer<void>();

  Map<String, dynamic>? _cachedNavigation;
  DestinationData? _destinationToSend;

  String? _pendingPostId;
  String? _pendingPostType;
  String? _pendingChatId;
  String? _pendingSendUserId;
  String? _pendingChroniqueId;
  String? _pendingJoinCode;
  String? _pendingNavigationType;

  Post? _loadedPost;
  Chat? _loadedChat;
  bool _isLoadingTarget = false;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);
    contentProvider = Provider.of<ContentProvider>(context, listen: false);

    // Lancer la vérification directement dans initState
    _startSessionCheck();
  }

  // Vérification de session basée uniquement sur SharedPreferences
  Future<bool> _checkSessionAndRedirect() async {
    // 1. Vérifier si on a un token stocké
   return  await SessionUserFirebaseService.getStoredUserId().then((value) async {
     printVm('🔍 Aucun token trouvé: $value');

     final storedUserId = value;
      if (storedUserId == null) {
        printVm('🔍 Aucun token trouvé, redirection vers login');
        _redirectToLogin();
        return false;
      }

      // 2. Vérifier si la session est encore valide (moins de 3 jours)
      final canStayConnected = await SessionUserFirebaseService.canStayConnected();

      if (!canStayConnected) {
        printVm('🔍 Session expirée (> 3 jours), redirection vers login');
        await SessionUserFirebaseService.clearSession();
        _redirectToLogin();
        return false;
      }

      // 4. Session valide, mettre à jour la date d'activité
      await SessionUserFirebaseService.updateLastActive();
      printVm('✅ Session valide pour: $storedUserId');
       return true;

     },);

  }

  // Nouvelle méthode: Lancer la vérification de session
  Future<void> _startSessionCheck() async {
    if (_authHandled || _isAuthCompleted || _hasNavigated || _isCheckingSession) return;

    _isCheckingSession = true;

    // Vérifier la session
    final isValid = await _checkSessionAndRedirect();

    if (isValid) {
      final storedUserId = await SessionUserFirebaseService.getStoredUserId();
      if (storedUserId != null) {
        await _updateUserLastActive(storedUserId);
        _handleAuthenticatedUserById(storedUserId);
      }
    }

    _isCheckingSession = false;
  }

  void _startInitFlow() async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      setState(() { _loadingText = "Initialisation..."; _hasError = false; });
      final isFirst = await authProvider.getIsFirst();
      if (isFirst == null || isFirst == false) {
        await authProvider.storeIsFirst(true);
        if (mounted && !_hasNavigated) {
          _hasNavigated = true;
          Navigator.pushReplacementNamed(context, '/introduction');
        }
        return;
      }
      await _checkIfShouldPlayVideo();
    } catch (e) {
      printVm("❌ Erreur initialisation : $e");
      setState(() { _hasError = true; _errorMessage = e.toString(); });
      _isProcessing = false;
    }
  }

  Future<void> _loadPostData() async {
    if (_pendingPostId == null) return;
    setState(() { _isLoadingTarget = true; _loadingText = "Chargement du post..."; });
    try {
      final doc = await FirebaseFirestore.instance.collection('Posts').doc(_pendingPostId).get();
      if (doc.exists) {
        final post = Post.fromJson(doc.data() as Map<String, dynamic>);
        post.id = doc.id;
        if (post.user_id != null && post.user_id!.isNotEmpty) {
          final userDoc = await FirebaseFirestore.instance.collection('Users').doc(post.user_id).get();
          if (userDoc.exists) post.user = UserData.fromJson(userDoc.data() as Map<String, dynamic>);
        }
        _loadedPost = post;
      }
    } catch (e) { printVm("❌ Erreur chargement post : $e"); }
    finally { if (mounted) setState(() => _isLoadingTarget = false); }
  }

  Future<void> _loadChatData() async {
    if (_pendingChatId == null || _pendingSendUserId == null) return;
    setState(() { _isLoadingTarget = true; _loadingText = "Chargement du chat..."; });
    try {
      final chatDoc = await FirebaseFirestore.instance.collection('Chats').doc(_pendingChatId).get();
      if (!chatDoc.exists) return;
      final chat = Chat.fromJson(chatDoc.data() as Map<String, dynamic>);

      // User + messages en parallèle (indépendants)
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('Users').doc(_pendingSendUserId).get(),
        FirebaseFirestore.instance
            .collection('Messages')
            .where('chat_id', isEqualTo: _pendingChatId)
            .orderBy('createdAt', descending: true)
            .limit(25)
            .get(),
      ]);

      final userDoc = results[0] as DocumentSnapshot;
      final messagesSnapshot = results[1] as QuerySnapshot;

      if (userDoc.exists) {
        chat.chatFriend = UserData.fromJson(userDoc.data() as Map<String, dynamic>);
        chat.receiver = chat.chatFriend;
      }
      chat.messages = messagesSnapshot.docs.map((d) => Message.fromJson(d.data() as Map<String, dynamic>)).toList();
      _loadedChat = chat;
    } catch (e) { printVm("❌ Erreur chargement chat : $e"); }
    finally { if (mounted) setState(() => _isLoadingTarget = false); }
  }

  void _navigateToHomeWithDestination() {
    if (_hasNavigated) return;
    _hasNavigated = true;
    printVm("🚀 [SPLASH] Navigation vers Home avec destination ${_destinationToSend?.type}");
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => MyHomePage(title: '', initialDestination: _destinationToSend)),
    );
  }

  // --- Gestion vidéo ---
  Future<void> _checkIfShouldPlayVideo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastPlayedDate = prefs.getString('last_video_date3');
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      if (lastPlayedDate != today) {
        shouldPlayVideo = true;
        await prefs.setString('last_video_date3', today);
        await _initializeVideo();
      } else {
        shouldPlayVideo = false;
        if (mounted) setState(() { isFinished = true; isLoadingVideo = false; });
      }
    } catch (e) {
      printVm("❌ Erreur vérification vidéo : $e");
      shouldPlayVideo = false;
      if (mounted) setState(() { isFinished = true; isLoadingVideo = false; });
    }
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.asset('assets/videos/intro_video.mp4');
      await _controller!.initialize();
      _controller!.setVolume(0.0);
      _controller!.play();
      _controller!.addListener(() {
        if (_controller!.value.position >= _controller!.value.duration && !isFinished && mounted) {
          setState(() => isFinished = true);
        }
      });
      if (mounted) setState(() => isLoadingVideo = false);
    } catch (e) {
      debugPrint("❌ Erreur vidéo : $e");
      if (mounted) setState(() { isFinished = true; isLoadingVideo = false; });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    if (_hasError) {
      return Scaffold(
        backgroundColor: _colors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: _colors.danger, size: 60),
              const SizedBox(height: 16),
              Text('Une erreur est survenue', style: TextStyle(color: _colors.textPrimary, fontSize: 16)),
              const SizedBox(height: 8),
              Text(_errorMessage, style: TextStyle(color: _colors.textSecondary, fontSize: 12)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _redirectToLogin,
                style: ElevatedButton.styleFrom(backgroundColor: _colors.primary),
                child: const Text('Retour à l\'accueil'),
              ),
            ],
          ),
        ),
      );
    }

    if (isLoadingVideo && shouldPlayVideo) return _buildLoadingScreen("Chargement de la vidéo...");
    if (isFinished || !shouldPlayVideo) return _buildSplashScreen(height, width);
    return _buildVideoScreen();
  }

  // Splash screen sans StreamBuilder
  // Session 13 : logo conservé en haut, texte de chargement déplacé en bas de l'écran.
  Widget _buildSplashScreen(double height, double width) {
    return Scaffold(
      body: Container(
        height: height, width: width,
        decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/splash/spc2.jpg'), fit: BoxFit.cover)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0).copyWith(top: 40.0, bottom: 24.0),
            child: Column(
              children: [
                SizedBox(height: 100, width: 100, child: Image.asset('assets/logo/afrolook_logo.png')),
                const Spacer(),
                // Bloc de chargement déplacé en bas de l'écran
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: _colors.primary),
                    const SizedBox(height: 20),
                    Text(
                      _loadingText,
                      style: TextStyle(color: _colors.textSecondary, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      backgroundColor: _colors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(_colors.primary),
                    ),
                    if (_isLoadingTarget || _loadedPost != null || _loadedChat != null) ...[
                      const SizedBox(height: 20),
                      _buildLoadingStatus(),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Gérer l'authentification avec l'ID stocké (cache-first)
  Future<void> _handleAuthenticatedUserById(String userId) async {
    if (_authHandled || _isAuthCompleted || _hasNavigated) return;
    _authHandled = true;
    printVm("🔐 [SPLASH] _handleAuthenticatedUserById start for $userId");

    // ── Cache-first : tenter de servir depuis le cache local ────────────────
    final cachedUser = await StartupCacheService.loadUserData();
    final cachedApp = await StartupCacheService.loadAppData();

    if (cachedUser != null && cachedUser.id == userId) {
      printVm("⚡ [SPLASH] Cache hit — navigation immédiate");
      authProvider.loginUserData = cachedUser;
      if (cachedApp != null) authProvider.appDefaultData = cachedApp;

      final countryCode = cachedUser.countryData?["countryCode"]?.toString();
      if (countryCode == null || countryCode.isEmpty) {
        if (mounted && !_hasNavigated) {
          _hasNavigated = true;
          Navigator.push(context, MaterialPageRoute(builder: (_) => UpdateUserData(title: "Mise à jour d'adresse")));
        }
        return;
      }

      setState(() => _isAuthCompleted = true);
      await _prepareDestination();

      // Auto-join groupe Afrolook + rafraîchissement silencieux en arrière-plan
      unawaited(_autoJoinAfrolookGroup(userId));
      _backgroundRefresh(userId);
      return;
    }

    // ── Cache miss : chargement Firestore séquentiel ─────────────────────────
    printVm("🌐 [SPLASH] Cache miss — chargement Firestore pour $userId");
    try {
      setState(() => _loadingText = "Chargement des données...");
      await authProvider.getAppData();

      setState(() => _loadingText = "Connexion...");
      final success = await authProvider.getLoginUser(userId);
      if (!success) {
        _redirectToLogin();
        return;
      }

      // Sauvegarder en cache pour les prochains lancements
      unawaited(StartupCacheService.saveUserData(authProvider.loginUserData));
      unawaited(StartupCacheService.saveAppData(authProvider.appDefaultData));

      final countryCode = authProvider.loginUserData.countryData?["countryCode"]?.toString();
      if (countryCode == null || countryCode.isEmpty) {
        if (mounted && !_hasNavigated) {
          _hasNavigated = true;
          Navigator.push(context, MaterialPageRoute(builder: (_) => UpdateUserData(title: "Mise à jour d'adresse")));
        }
        return;
      }

      unawaited(_autoJoinAfrolookGroup(userId));
      setState(() => _isAuthCompleted = true);
      await _prepareDestination();

    } catch (e) {
      printVm("❌ [AUTH] Erreur : $e");
      if (mounted) setState(() { _hasError = true; _errorMessage = e.toString(); });
    }
  }

  /// Auto-rejoint le groupe officiel Afrolook si l'utilisateur n'en est pas membre.
  /// Silencieux — ne bloque jamais le login.
  Future<void> _autoJoinAfrolookGroup(String userId) async {
    try {
      final groupRef = FirebaseFirestore.instance
          .collection('GroupChats')
          .doc(kAfrolookGroupId);
      final groupDoc = await groupRef.get();
      if (!groupDoc.exists) return; // groupe pas encore créé

      final memberIds = (groupDoc.data()?['member_ids'] as List<dynamic>? ?? []).cast<String>();
      if (memberIds.contains(userId)) return; // déjà membre

      final userDoc = await FirebaseFirestore.instance.collection('Users').doc(userId).get();
      final ud = userDoc.data();
      final now = DateTime.now().millisecondsSinceEpoch;

      await groupRef.collection('members').doc(userId).set({
        'user_id': userId,
        'pseudo': ud?['pseudo'] ?? '',
        'image_url': ud?['imageUrl'] ?? '',
        'role': 'member',
        'joined_at': now,
      });
      await groupRef.update({
        'member_ids': FieldValue.arrayUnion([userId]),
        'member_count': FieldValue.increment(1),
      });
      printVm('✅ [SPLASH] Auto-join groupe Afrolook pour $userId');
    } catch (e) {
      printVm('⚠️ [SPLASH] Auto-join Afrolook ignoré : $e');
    }
  }

  /// Rafraîchit les données utilisateur en arrière-plan après navigation immédiate.
  void _backgroundRefresh(String userId) {
    Future.microtask(() async {
      try {
        await authProvider.getLoginUser(userId);
        await StartupCacheService.saveUserData(authProvider.loginUserData);
        await StartupCacheService.saveAppData(authProvider.appDefaultData);
        printVm("✅ [SPLASH] Background refresh terminé");
      } catch (e) {
        printVm("⚠️ [SPLASH] Background refresh échoué (ignoré): $e");
      }

      // Préchargement silencieux du feed home + contenu global pour que
      // HomeScreen affiche les données instantanément à l'arrivée.
      try {
        final feedProvider = Provider.of<FeedProvider>(context, listen: false);
        final user = authProvider.loginUserData;
        final country = user.countryData?['countryCode']?.toUpperCase() ?? '';
        feedProvider.loadGlobalContent();
        feedProvider.preload(
          FeedType.home,
          userId: user.id ?? '',
          countryCode: country,
          subscriptionPostIds: user.newPostsFromSubscriptions,
        );
        feedProvider.preload(
          FeedType.sport,
          userId: user.id ?? '',
          countryCode: country,
          subscriptionPostIds: user.newPostsFromSubscriptions,
        );
        feedProvider.preload(
          FeedType.vibes,
          userId: user.id ?? '',
          countryCode: country,
          subscriptionPostIds: user.newPostsFromSubscriptions,
        );
      } catch (e) {
        printVm("⚠️ [SPLASH] Preload feed échoué (ignoré): $e");
      }
    });
  }

  Future<void> _updateUserLastActive(String userId) async {
    try {
      await FirebaseFirestore.instance.collection('Users').doc(userId).update({
        'last_time_active': DateTime.now().millisecondsSinceEpoch,
      });
      printVm('✅ last_time_active mis à jour pour: $userId');
    } catch (e) {
      printVm('❌ Erreur mise à jour last_time_active: $e');
    }
  }

  Future<void> _prepareDestination() async {
    printVm("🔍 [SPLASH] Chargement du cache...");
    await NavigationCacheService().getAndClearPendingNavigation().then((value) {
      _cachedNavigation = value;
      if (_cachedNavigation != null) {
        printVm("✅ [SPLASH] Cache trouvé : $_cachedNavigation");
        _pendingNavigationType = _cachedNavigation!['type'];
        printVm("✅ [SPLASH] Cache trouvé _pendingNavigationType : $_pendingNavigationType");

        switch (_pendingNavigationType) {
          case 'post':
            _pendingPostId = _cachedNavigation!['postId'];
            _pendingPostType = _cachedNavigation!['postType'] ?? '';
            break;
          case 'message':
            _pendingChatId = _cachedNavigation!['chatId'];
            _pendingSendUserId = _cachedNavigation!['sendUserId'];
            break;
          case 'chronique':
            _pendingChroniqueId = _cachedNavigation!['chroniqueId'];
            break;
          case 'group':
            _pendingJoinCode = _cachedNavigation!['joinCode'] as String?;
            break;
          default: break;
        }
      } else {
        if (_hasNavigated) return;
        _hasNavigated = true;
        printVm("🚀 [SPLASH] Navigation vers Home avec destination ${_destinationToSend?.type}");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MyHomePage(title: '', initialDestination: _destinationToSend)),
        );
        printVm("📦 [SPLASH] Aucune navigation en cache");
      }
    });

    printVm("📦 2 [SPLASH] _prepareDestination - pendingType = $_pendingNavigationType");
    if (_pendingNavigationType == null) {
      _destinationToSend = DestinationData(type: 'home');
      return;
    }

    switch (_pendingNavigationType) {
      case 'post':
        await _loadPostData();
        _destinationToSend = (_loadedPost != null) ? DestinationData(type: 'post', post: _loadedPost) : DestinationData(type: 'home');
        break;
      case 'message':
        await _loadChatData();
        _destinationToSend = (_loadedChat != null) ? DestinationData(type: 'chat', chat: _loadedChat) : DestinationData(type: 'home');
        break;
      case 'chronique':
        _destinationToSend = DestinationData(type: 'chronique', chroniqueId: _pendingChroniqueId);
        break;
      case 'chronique_home':
        _destinationToSend = DestinationData(type: 'chronique_home');
        break;
      case 'invitation':
        _destinationToSend = DestinationData(type: 'invitation');
        break;
      case 'acceptInvitation':
        _destinationToSend = DestinationData(type: 'acceptInvitation');
        break;
      case 'parrainage':
        _destinationToSend = DestinationData(type: 'parrainage');
        break;
      case 'article':
        _destinationToSend = DestinationData(type: 'article');
        break;
      case 'group':
        _destinationToSend = DestinationData(type: 'group', joinCode: _pendingJoinCode);
        break;
      default:
        _destinationToSend = DestinationData(type: 'home');
    }
    printVm("✅ [SPLASH] Destination créée : ${_destinationToSend?.type}");

    if (_hasNavigated) return;
    _hasNavigated = true;
    printVm("🚀 [SPLASH] Navigation vers Home avec destination ${_destinationToSend?.type}");
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => MyHomePage(title: '', initialDestination: _destinationToSend)),
    );
  }

  void _redirectToLogin() {
    if (!mounted) return;
    // SessionUserFirebaseService.clearSession();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginPageUser()));
  }

  Widget _buildLoadingStatus() {
    if (_isLoadingTarget) {
      return Column(children: [
        Icon(Icons.downloading, color: _colors.warning, size: 30),
        const SizedBox(height: 8),
        Text("Chargement du contenu...", style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
      ]);
    }
    if (_loadedPost != null || _loadedChat != null) {
      return Column(children: [
        Icon(Icons.check_circle, color: _colors.primary, size: 30),
        const SizedBox(height: 8),
        Text("Contenu prêt !", style: TextStyle(color: _colors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 4),
        Text("Redirection...", style: TextStyle(color: _colors.textSecondary, fontSize: 12)),
      ]);
    }
    return const SizedBox.shrink();
  }

  Widget _buildLoadingScreen(String text) {
    return Scaffold(
      backgroundColor: _colors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: _colors.primary),
            const SizedBox(height: 20),
            Text(text, style: TextStyle(color: _colors.textPrimary, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_controller != null && _controller!.value.isInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            )
          else
            _buildLoadingScreen("Chargement de la vidéo..."),
          if (_isAuthCompleted && (_loadedPost != null || _loadedChat != null))
            const Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Text("Redirection...", style: TextStyle(color: Colors.white, fontSize: 14), textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }
}

// class SplashChargement extends StatefulWidget {
//   const SplashChargement({super.key});
//   @override
//   State<SplashChargement> createState() => _SplashChargementState();
// }
//
// class _SplashChargementState extends State<SplashChargement> {
//   late UserAuthProvider authProvider;
//   late PostProvider postProvider;
//   late UserProvider userProvider;
//   late ChroniqueProvider chroniqueProvider;
//   late ContentProvider contentProvider;
//   bool _isCheckingSession = false; // Nouvelle variable
//
//
//   VideoPlayerController? _controller;
//   bool isFinished = false;
//   bool isLoadingVideo = true;
//   bool shouldPlayVideo = false;
//   bool _hasError = false;
//   String _loadingText = "Initialisation...";
//   String _errorMessage = "";
//
//   bool _isAuthCompleted = false;
//   bool _hasNavigated = false;
//   bool _isProcessing = false;
//   bool _authHandled = false;          // éviter multiples appels handleAuthenticatedUser
//   final Completer<void> _cacheReady = Completer<void>(); // attendre chargement cache
//
//   Map<String, dynamic>? _cachedNavigation;
//   DestinationData? _destinationToSend;
//
//   String? _pendingPostId;
//   String? _pendingPostType;
//   String? _pendingChatId;
//   String? _pendingSendUserId;
//   String? _pendingChroniqueId;
//   String? _pendingNavigationType;
//
//   Post? _loadedPost;
//   Chat? _loadedChat;
//   bool _isLoadingTarget = false;
//
//   @override
//   void initState() {
//     super.initState();
//     authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     postProvider = Provider.of<PostProvider>(context, listen: false);
//     userProvider = Provider.of<UserProvider>(context, listen: false);
//     chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);
//     contentProvider = Provider.of<ContentProvider>(context, listen: false);
//
//     // _loadCachedNavigationOnce();   // démarre le chargement asynchrone du cache
//     _startInitFlow();
//   }
//   // MODIFICATION: Nouvelle méthode pour vérifier la session avant tout
//   Future<bool> _checkSessionAndRedirect() async {
//     // 1. Vérifier si on a un token stocké
//     final storedUserId = await SessionUserFirebaseService.getStoredUserId();
//
//     if (storedUserId == null) {
//       printVm('🔍 Aucun token trouvé, redirection vers login');
//       _redirectToLogin();
//       return false;
//     }
//
//     // 2. Vérifier si la session est encore valide (moins de 3 jours)
//     final canStayConnected = await SessionUserFirebaseService.canStayConnected();
//
//     if (!canStayConnected) {
//       printVm('🔍 Session expirée (> 3 jours), redirection vers login');
//       await SessionUserFirebaseService.clearSession();
//       _redirectToLogin();
//       return false;
//     }
//
//     // 3. Vérifier l'inactivité dans Firestore (last_time_active)
//     final isInactive = await SessionUserFirebaseService.isUserInactive(storedUserId);
//
//     if (isInactive) {
//       printVm('🔍 Utilisateur inactif (> 3 jours sans connexion app), redirection vers login');
//       await SessionUserFirebaseService.clearSession();
//       _redirectToLogin();
//       return false;
//     }
//
//     // 4. Session valide, mettre à jour la date d'activité
//     await SessionUserFirebaseService.updateLastActive();
//     printVm('✅ Session valide pour: $storedUserId');
//
//     return true;
//   }
//
//   Future<void> _loadCachedNavigationOnce() async {
//     printVm("🔍 [SPLASH] Chargement du cache...");
//     _cachedNavigation = await NavigationCacheService().getAndClearPendingNavigation();
//     if (_cachedNavigation != null) {
//       printVm("✅ [SPLASH] Cache trouvé : $_cachedNavigation");
//       _pendingNavigationType = _cachedNavigation!['type'];
//       switch (_pendingNavigationType) {
//         case 'post':
//           _pendingPostId = _cachedNavigation!['postId'];
//           _pendingPostType = _cachedNavigation!['postType'] ?? '';
//           break;
//         case 'message':
//           _pendingChatId = _cachedNavigation!['chatId'];
//           _pendingSendUserId = _cachedNavigation!['sendUserId'];
//           break;
//         case 'chronique':
//           _pendingChroniqueId = _cachedNavigation!['chroniqueId'];
//           break;
//         default: break;
//       }
//     } else {
//       printVm("📦 [SPLASH] Aucune navigation en cache");
//     }
//     // Signaler que le cache est prêt
//     if (!_cacheReady.isCompleted) _cacheReady.complete();
//   }
//
//   void _startInitFlow() async {
//     if (_isProcessing) return;
//     _isProcessing = true;
//     try {
//       setState(() { _loadingText = "Initialisation..."; _hasError = false; });
//       final isFirst = await authProvider.getIsFirst();
//       if (isFirst == null || isFirst == false) {
//         await authProvider.storeIsFirst(true);
//         if (mounted && !_hasNavigated) {
//           _hasNavigated = true;
//           Navigator.pushReplacementNamed(context, '/introduction');
//         }
//         return;
//       }
//       await _checkIfShouldPlayVideo();
//     } catch (e) {
//       printVm("❌ Erreur initialisation : $e");
//       setState(() { _hasError = true; _errorMessage = e.toString(); });
//       _isProcessing = false;
//     }
//   }
//
//
//
//   Future<void> _loadPostData() async {
//     if (_pendingPostId == null) return;
//     setState(() { _isLoadingTarget = true; _loadingText = "Chargement du post..."; });
//     try {
//       final doc = await FirebaseFirestore.instance.collection('Posts').doc(_pendingPostId).get();
//       if (doc.exists) {
//         final post = Post.fromJson(doc.data() as Map<String, dynamic>);
//         post.id = doc.id;
//         if (post.user_id != null && post.user_id!.isNotEmpty) {
//           final userDoc = await FirebaseFirestore.instance.collection('Users').doc(post.user_id).get();
//           if (userDoc.exists) post.user = UserData.fromJson(userDoc.data() as Map<String, dynamic>);
//         }
//         _loadedPost = post;
//       }
//     } catch (e) { printVm("❌ Erreur chargement post : $e"); }
//     finally { if (mounted) setState(() => _isLoadingTarget = false); }
//   }
//
//   Future<void> _loadChatData() async {
//     if (_pendingChatId == null || _pendingSendUserId == null) return;
//     setState(() { _isLoadingTarget = true; _loadingText = "Chargement du chat..."; });
//     try {
//       final chatDoc = await FirebaseFirestore.instance.collection('Chats').doc(_pendingChatId).get();
//       if (!chatDoc.exists) return;
//       final chat = Chat.fromJson(chatDoc.data() as Map<String, dynamic>);
//       final userDoc = await FirebaseFirestore.instance.collection('Users').doc(_pendingSendUserId).get();
//       if (userDoc.exists) {
//         chat.chatFriend = UserData.fromJson(userDoc.data() as Map<String, dynamic>);
//         chat.receiver = chat.chatFriend;
//       }
//       final messagesSnapshot = await FirebaseFirestore.instance
//           .collection('Messages')
//           .where('chat_id', isEqualTo: _pendingChatId)
//           .orderBy('createdAt', descending: true)
//           .limit(25)
//           .get();
//       chat.messages = messagesSnapshot.docs.map((d) => Message.fromJson(d.data() as Map<String, dynamic>)).toList();
//       _loadedChat = chat;
//     } catch (e) { printVm("❌ Erreur chargement chat : $e"); }
//     finally { if (mounted) setState(() => _isLoadingTarget = false); }
//   }
//
//   void _navigateToHomeWithDestination() {
//     if (_hasNavigated) return;
//     _hasNavigated = true;
//     printVm("🚀 [SPLASH] Navigation vers Home avec destination ${_destinationToSend?.type}");
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(builder: (_) => MyHomePage(title: '', initialDestination: _destinationToSend)),
//     );
//   }
//
//
//
//   // --- Gestion vidéo (inchangée) ---
//   Future<void> _checkIfShouldPlayVideo() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final lastPlayedDate = prefs.getString('last_video_date3');
//       final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
//       if (lastPlayedDate != today) {
//         shouldPlayVideo = true;
//         await prefs.setString('last_video_date3', today);
//         await _initializeVideo();
//       } else {
//         shouldPlayVideo = false;
//         if (mounted) setState(() { isFinished = true; isLoadingVideo = false; });
//       }
//     } catch (e) {
//       printVm("❌ Erreur vérification vidéo : $e");
//       shouldPlayVideo = false;
//       if (mounted) setState(() { isFinished = true; isLoadingVideo = false; });
//     }
//   }
//
//   Future<void> _initializeVideo() async {
//     try {
//       _controller = VideoPlayerController.asset('assets/videos/intro_video.mp4');
//       await _controller!.initialize();
//       _controller!.setVolume(0.0);
//       _controller!.play();
//       _controller!.addListener(() {
//         if (_controller!.value.position >= _controller!.value.duration && !isFinished && mounted) {
//           setState(() => isFinished = true);
//         }
//       });
//       if (mounted) setState(() => isLoadingVideo = false);
//     } catch (e) {
//       debugPrint("❌ Erreur vidéo : $e");
//       if (mounted) setState(() { isFinished = true; isLoadingVideo = false; });
//     }
//   }
//
//   @override
//   void dispose() {
//     _controller?.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final height = MediaQuery.of(context).size.height;
//     final width = MediaQuery.of(context).size.width;
//
//     // if (_isAuthCompleted && !_hasError && !_hasNavigated && (isFinished || !shouldPlayVideo)) {
//     //   WidgetsBinding.instance.addPostFrameCallback((_) { if (!_hasNavigated) _navigateToHomeWithDestination(); });
//     // }
//
//     if (_hasError) {
//       return Scaffold(
//         backgroundColor: Colors.black,
//         body: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               const Icon(Icons.error_outline, color: Colors.red, size: 60),
//               const SizedBox(height: 16),
//               const Text('Une erreur est survenue', style: TextStyle(color: Colors.white, fontSize: 16)),
//               const SizedBox(height: 8),
//               Text(_errorMessage, style: const TextStyle(color: Colors.grey, fontSize: 12)),
//               const SizedBox(height: 24),
//               ElevatedButton(
//                 onPressed: _redirectToLogin,
//                 style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
//                 child: const Text('Retour à l\'accueil'),
//               ),
//             ],
//           ),
//         ),
//       );
//     }
//
//     if (isLoadingVideo && shouldPlayVideo) return _buildLoadingScreen("Chargement de la vidéo...");
//     if (isFinished || !shouldPlayVideo) return _buildSplashWithStream(height, width);
//     return _buildVideoScreen();
//   }
//
//   Widget _buildSplashWithStream2(double height, double width) {
//     return Scaffold(
//       body: Container(
//         height: height, width: width,
//         decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/splash/spc2.jpg'), fit: BoxFit.cover)),
//         child: Padding(
//           padding: const EdgeInsets.only(top: 40.0, bottom: 10),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               SizedBox(height: 100, width: 100, child: Image.asset('assets/logo/afrolook_logo.png')),
//               Expanded(
//                 child: StreamBuilder<User?>(
//                   stream: FirebaseAuth.instance.authStateChanges(),
//                   builder: (context, snapshot) {
//                     if (_authHandled || _isAuthCompleted || _hasNavigated) return const SizedBox.shrink();
//                     if (snapshot.connectionState == ConnectionState.waiting) {
//                       return Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           const CircularProgressIndicator(color: Color(0xFF25D366)),
//                           const SizedBox(height: 20),
//                           Text("Vérification de la session...", style: const TextStyle(color: Colors.white70, fontSize: 14)),
//                         ],
//                       );
//                     }
//                     if (snapshot.hasData && snapshot.data != null) {
//                       WidgetsBinding.instance.addPostFrameCallback((_) {
//                         if (!_authHandled && !_isAuthCompleted && !_hasNavigated) _handleAuthenticatedUser(snapshot.data!);
//                       });
//                       return Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           const Icon(Icons.check_circle, color: Colors.green, size: 40),
//                           const SizedBox(height: 16),
//                           Text(_loadingText, style: const TextStyle(color: Colors.white, fontSize: 14)),
//                           const SizedBox(height: 8),
//                           const LinearProgressIndicator(
//                             backgroundColor: Colors.grey,
//                             valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF25D366)),
//                           ),
//                         ],
//                       );
//                     }
//                     WidgetsBinding.instance.addPostFrameCallback((_) { if (!_hasNavigated) _redirectToLogin(); });
//                     return Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         const Icon(Icons.lock_outline, color: Colors.orange, size: 40),
//                         const SizedBox(height: 16),
//                         const Text("Session expirée", style: TextStyle(color: Colors.white, fontSize: 14)),
//                         const SizedBox(height: 8),
//                         Text("Redirection vers la connexion...", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
//                       ],
//                     );
//                   },
//                 ),
//               ),
//               if (_isLoadingTarget || _loadedPost != null || _loadedChat != null)
//                 Padding(padding: const EdgeInsets.only(bottom: 30), child: _buildLoadingStatus()),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   // MODIFICATION: La méthode _buildSplashWithStream
//   Widget _buildSplashWithStream(double height, double width) {
//     return Scaffold(
//       body: Container(
//         height: height, width: width,
//         decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/splash/spc2.jpg'), fit: BoxFit.cover)),
//         child: Padding(
//           padding: const EdgeInsets.only(top: 40.0, bottom: 10),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               SizedBox(height: 100, width: 100, child: Image.asset('assets/logo/afrolook_logo.png')),
//               Expanded(
//                 child: StreamBuilder<User?>(
//                   stream: FirebaseAuth.instance.authStateChanges(),
//                   builder: (context, snapshot) {
//                     if (_authHandled || _isAuthCompleted || _hasNavigated) return const SizedBox.shrink();
//
//                     if (snapshot.connectionState == ConnectionState.waiting) {
//                       return Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           const CircularProgressIndicator(color: Color(0xFF25D366)),
//                           const SizedBox(height: 20),
//                           Text("Vérification de la session...", style: const TextStyle(color: Colors.white70, fontSize: 14)),
//                         ],
//                       );
//                     }
//
//                     // NOUVEAU: Si utilisateur Firebase existe
//                     if (snapshot.hasData && snapshot.data != null) {
//                       // Vérifier la session avant de continuer
//                       WidgetsBinding.instance.addPostFrameCallback((_) async {
//                         if (!_authHandled && !_isAuthCompleted && !_hasNavigated && !_isCheckingSession) {
//                           _isCheckingSession = true;
//
//                           // Vérifier si l'utilisateur peut rester connecté
//                           final isValid = await _checkSessionAndRedirect();
//
//                           if (isValid) {
//                             // Mettre à jour le last_time_active dans Firestore
//                             await _updateUserLastActive(snapshot.data!.uid);
//                             // Continuer avec l'authentification normale
//                             _handleAuthenticatedUser(snapshot.data!);
//                           }
//                           _isCheckingSession = false;
//                         }
//                       });
//
//                       return Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           const Icon(Icons.check_circle, color: Colors.green, size: 40),
//                           const SizedBox(height: 16),
//                           Text(_loadingText, style: const TextStyle(color: Colors.white, fontSize: 14)),
//                           const SizedBox(height: 8),
//                           const LinearProgressIndicator(
//                             backgroundColor: Colors.grey,
//                             valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF25D366)),
//                           ),
//                         ],
//                       );
//                     }
//
//                     // NOUVEAU: Si Firebase Auth est null mais on a un token
//                     WidgetsBinding.instance.addPostFrameCallback((_) async {
//                       if (!_hasNavigated && !_isCheckingSession) {
//                         _isCheckingSession = true;
//
//                         // Vérifier s'il y a un token stocké
//                         final storedUserId = await SessionUserFirebaseService.getStoredUserId();
//
//                         if (storedUserId != null) {
//                           // Vérifier si la session est encore valide
//                           final canStayConnected = await SessionUserFirebaseService.canStayConnected();
//
//                           if (canStayConnected) {
//                             // Session valide, on essaie de reconnecter automatiquement
//                             printVm('🔄 Tentative de reconnexion automatique pour: $storedUserId');
//                             // Ici vous pouvez déclencher une reconnexion silencieuse
//                             // Ou simplement rediriger vers login avec message
//                             _redirectToLogin();
//                           } else {
//                             printVm('🔍 Session expirée, redirection vers login');
//                             await SessionUserFirebaseService.clearSession();
//                             _redirectToLogin();
//                           }
//                         } else {
//                           _redirectToLogin();
//                         }
//                         _isCheckingSession = false;
//                       }
//                     });
//
//                     return Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         const Icon(Icons.lock_outline, color: Colors.orange, size: 40),
//                         const SizedBox(height: 16),
//                         const Text("Vérification de session...", style: TextStyle(color: Colors.white, fontSize: 14)),
//                         const SizedBox(height: 8),
//                         Text("Veuillez patienter", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
//                       ],
//                     );
//                   },
//                 ),
//               ),
//               if (_isLoadingTarget || _loadedPost != null || _loadedChat != null)
//                 Padding(padding: const EdgeInsets.only(bottom: 30), child: _buildLoadingStatus()),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   // NOUVELLE MÉTHODE: Mettre à jour last_time_active dans Firestore
//   Future<void> _updateUserLastActive(String userId) async {
//     try {
//       await FirebaseFirestore.instance.collection('Users').doc(userId).update({
//         'last_time_active': DateTime.now().millisecondsSinceEpoch,
//       });
//       printVm('✅ last_time_active mis à jour pour: $userId');
//     } catch (e) {
//       printVm('❌ Erreur mise à jour last_time_active: $e');
//     }
//   }
//
//   Future<void> _prepareDestination() async {
//
//     printVm("🔍 [SPLASH] Chargement du cache...");
//     await NavigationCacheService().getAndClearPendingNavigation().then((value) {
//       _cachedNavigation = value;
//       if (_cachedNavigation != null) {
//         printVm("✅ [SPLASH] Cache trouvé : $_cachedNavigation");
//         _pendingNavigationType = _cachedNavigation!['type'];
//         printVm("✅ [SPLASH] Cache trouvé _pendingNavigationType : $_pendingNavigationType");
//
//         switch (_pendingNavigationType) {
//           case 'post':
//             _pendingPostId = _cachedNavigation!['postId'];
//             _pendingPostType = _cachedNavigation!['postType'] ?? '';
//             break;
//           case 'message':
//             _pendingChatId = _cachedNavigation!['chatId'];
//             _pendingSendUserId = _cachedNavigation!['sendUserId'];
//             break;
//           case 'chronique':
//             _pendingChroniqueId = _cachedNavigation!['chroniqueId'];
//             break;
//           default: break;
//         }
//       } else {
//         if (_hasNavigated) return;
//         _hasNavigated = true;
//         printVm("🚀 [SPLASH] Navigation vers Home avec destination ${_destinationToSend?.type}");
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (_) => MyHomePage(title: '', initialDestination: _destinationToSend)),
//         );
//         printVm("📦 [SPLASH] Aucune navigation en cache");
//       }
//     },);
//
//     // Signaler que le cache est prêt
//     // if (!_cacheReady.isCompleted) _cacheReady.complete();
//     printVm("📦 2 [SPLASH] _prepareDestination - pendingType = $_pendingNavigationType");
//     if (_pendingNavigationType == null) {
//       _destinationToSend = DestinationData(type: 'home');
//       return;
//     }
//
//     switch (_pendingNavigationType) {
//       case 'post':
//         await _loadPostData();
//         _destinationToSend = (_loadedPost != null) ? DestinationData(type: 'post', post: _loadedPost) : DestinationData(type: 'home');
//         break;
//       case 'message':
//         await _loadChatData();
//         _destinationToSend = (_loadedChat != null) ? DestinationData(type: 'chat', chat: _loadedChat) : DestinationData(type: 'home');
//         break;
//       case 'chronique':
//         _destinationToSend = DestinationData(type: 'chronique', chroniqueId: _pendingChroniqueId);
//         break;
//       case 'chronique_home':
//         _destinationToSend = DestinationData(type: 'chronique_home');
//         break;
//       case 'invitation':
//         _destinationToSend = DestinationData(type: 'invitation');
//         break;
//       case 'acceptInvitation':
//         _destinationToSend = DestinationData(type: 'acceptInvitation');
//         break;
//       case 'parrainage':
//         _destinationToSend = DestinationData(type: 'parrainage');
//         break;
//       case 'article':
//         _destinationToSend = DestinationData(type: 'article');
//         break;
//       default:
//         _destinationToSend = DestinationData(type: 'home');
//     }
//     printVm("✅ [SPLASH] Destination créée : ${_destinationToSend?.type}");
//
//     if (_hasNavigated) return;
//     _hasNavigated = true;
//     printVm("🚀 [SPLASH] Navigation vers Home avec destination ${_destinationToSend?.type}");
//     Navigator.pushReplacement(
//       context,
//       MaterialPageRoute(builder: (_) => MyHomePage(title: '', initialDestination: _destinationToSend)),
//     );
//   }
//
//   // MODIFICATION: La méthode _handleAuthenticatedUser
//   Future<void> _handleAuthenticatedUser(User user) async {
//     if (_authHandled || _isAuthCompleted || _hasNavigated) return;
//     _authHandled = true;
//     printVm("🔐 [SPLASH] _handleAuthenticatedUser start for ${user.uid}");
//
//     // Sauvegarder la session dans SharedPreferences
//     await SessionUserFirebaseService.saveUserSession(user.uid);
//
//     try {
//       setState(() => _loadingText = "Chargement des données...");
//       await authProvider.getAppData();
//
//       setState(() => _loadingText = "Connexion...");
//       final success = await authProvider.getLoginUser(user.uid);
//       if (!success) {
//         _redirectToLogin();
//         return;
//       }
//
//       final countryCode = authProvider.loginUserData.countryData?["countryCode"]?.toString();
//       if (countryCode == null || countryCode.isEmpty) {
//         if (mounted && !_hasNavigated) {
//           _hasNavigated = true;
//           Navigator.push(context, MaterialPageRoute(builder: (_) => UpdateUserData(title: "Mise à jour d'adresse")));
//         }
//         return;
//       }
//
//       setState(() => _isAuthCompleted = true);
//       await _prepareDestination();
//
//     } catch (e) {
//       printVm("❌ [AUTH] Erreur : $e");
//       if (mounted) setState(() { _hasError = true; _errorMessage = e.toString(); });
//     }
//   }
//
//   // MODIFICATION: La méthode _redirectToLogin doit aussi effacer la session
//   void _redirectToLogin() {
//     if (!mounted) return;
//     // Effacer la session avant redirection
//     SessionUserFirebaseService.clearSession();
//     Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginPageUser()));
//   }
//
//   Widget _buildLoadingStatus() {
//     if (_isLoadingTarget) {
//       return const Column(children: [
//         Icon(Icons.downloading, color: Colors.orange, size: 30),
//         SizedBox(height: 8),
//         Text("Chargement du contenu...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
//       ]);
//     }
//     if (_loadedPost != null || _loadedChat != null) {
//       return const Column(children: [
//         Icon(Icons.check_circle, color: Colors.green, size: 30),
//         SizedBox(height: 8),
//         Text("Contenu prêt !", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
//         SizedBox(height: 4),
//         Text("Redirection...", style: TextStyle(color: Colors.grey, fontSize: 12)),
//       ]);
//     }
//     return const SizedBox.shrink();
//   }
//
//   Widget _buildLoadingScreen(String text) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             const CircularProgressIndicator(color: Color(0xFF25D366)),
//             const SizedBox(height: 20),
//             Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildVideoScreen() {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Stack(
//         children: [
//           if (_controller != null && _controller!.value.isInitialized)
//             SizedBox.expand(
//               child: FittedBox(
//                 fit: BoxFit.cover,
//                 child: SizedBox(
//                   width: _controller!.value.size.width,
//                   height: _controller!.value.size.height,
//                   child: VideoPlayer(_controller!),
//                 ),
//               ),
//             )
//           else
//             _buildLoadingScreen("Chargement de la vidéo..."),
//           if (_isAuthCompleted && (_loadedPost != null || _loadedChat != null))
//             const Positioned(
//               bottom: 100,
//               left: 0,
//               right: 0,
//               child: Text("Redirection...", style: TextStyle(color: Colors.white, fontSize: 14), textAlign: TextAlign.center),
//             ),
//         ],
//       ),
//     );
//   }
// }
