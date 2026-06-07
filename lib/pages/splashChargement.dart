import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chatmodels/message.dart';
import '../models/model_data.dart';
import '../providers/authProvider.dart';
import '../providers/chroniqueProvider.dart';
import '../providers/contenuPayantProvider.dart';
import '../providers/postProvider.dart';
import '../providers/userProvider.dart';
import '../services/nav_cache_service.dart';
import 'auth/authTest/Screens/Login/loginPageUser.dart';
import 'auth/authTest/Screens/updateUserData.dart';
import 'chat/myChat.dart';
import 'chronique/chroniquedetails.dart';
import 'chronique/chroniquehome.dart';
import 'home/homeScreen.dart';
import 'mes_notifications.dart';
import 'postDetails.dart';
import 'postDetailsVideo.dart';
import 'user/amis/ami.dart';
import 'user/amis/pageMesInvitations.dart';
import 'user/monetisation.dart';

class DestinationData {
  final String type;
  final Post? post;
  final Chat? chat;
  final String? chroniqueId;
  final String? chatId;
  final String? sendUserId;
  DestinationData({required this.type, this.post, this.chat, this.chroniqueId, this.chatId, this.sendUserId});
}

class SplashChargement extends StatefulWidget {
  const SplashChargement({super.key});
  @override
  State<SplashChargement> createState() => _SplashChargementState();
}

class _SplashChargementState extends State<SplashChargement> {
  late UserAuthProvider authProvider;
  late PostProvider postProvider;
  late UserProvider userProvider;
  late ChroniqueProvider chroniqueProvider;
  late ContentProvider contentProvider;

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
  bool _authHandled = false;          // éviter multiples appels handleAuthenticatedUser
  final Completer<void> _cacheReady = Completer<void>(); // attendre chargement cache

  Map<String, dynamic>? _cachedNavigation;
  DestinationData? _destinationToSend;

  String? _pendingPostId;
  String? _pendingPostType;
  String? _pendingChatId;
  String? _pendingSendUserId;
  String? _pendingChroniqueId;
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

    // _loadCachedNavigationOnce();   // démarre le chargement asynchrone du cache
    _startInitFlow();
  }

  Future<void> _loadCachedNavigationOnce() async {
    print("🔍 [SPLASH] Chargement du cache...");
    _cachedNavigation = await NavigationCacheService().getAndClearPendingNavigation();
    if (_cachedNavigation != null) {
      print("✅ [SPLASH] Cache trouvé : $_cachedNavigation");
      _pendingNavigationType = _cachedNavigation!['type'];
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
        default: break;
      }
    } else {
      print("📦 [SPLASH] Aucune navigation en cache");
    }
    // Signaler que le cache est prêt
    if (!_cacheReady.isCompleted) _cacheReady.complete();
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
      print("❌ Erreur initialisation : $e");
      setState(() { _hasError = true; _errorMessage = e.toString(); });
      _isProcessing = false;
    }
  }

  Future<void> _handleAuthenticatedUser(User user) async {
    if (_authHandled || _isAuthCompleted || _hasNavigated) return;
    _authHandled = true;
    print("🔐 [SPLASH] _handleAuthenticatedUser start for ${user.uid}");

    // // Attendre que le cache soit chargé (nécessaire pour _pendingNavigationType)
    // await _cacheReady.future;
    print("✅ [SPLASH] Cache prêt, _pendingNavigationType = $_pendingNavigationType");

    try {
      setState(() => _loadingText = "Chargement des données...");
      await authProvider.getAppData();

      setState(() => _loadingText = "Connexion...");
      final success = await authProvider.getLoginUser(user.uid);
      if (!success) { _redirectToLogin(); return; }

      final countryCode = authProvider.loginUserData.countryData?["countryCode"]?.toString();
      if (countryCode == null || countryCode.isEmpty) {
        if (mounted && !_hasNavigated) {
          _hasNavigated = true;
          Navigator.push(context, MaterialPageRoute(builder: (_) => UpdateUserData(title: "Mise à jour d'adresse")));
        }
        return;
      }

      setState(() => _isAuthCompleted = true);
      await _prepareDestination().then((value) {
        // _navigateToHomeWithDestination();

      },);

    } catch (e) {
      print("❌ [AUTH] Erreur : $e");
      if (mounted) setState(() { _hasError = true; _errorMessage = e.toString(); });
    }
  }

  Future<void> _prepareDestination() async {

    print("🔍 [SPLASH] Chargement du cache...");
   await NavigationCacheService().getAndClearPendingNavigation().then((value) {
     _cachedNavigation = value;
      if (_cachedNavigation != null) {
        print("✅ [SPLASH] Cache trouvé : $_cachedNavigation");
        _pendingNavigationType = _cachedNavigation!['type'];
        print("✅ [SPLASH] Cache trouvé _pendingNavigationType : $_pendingNavigationType");

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
          default: break;
        }
      } else {
        if (_hasNavigated) return;
        _hasNavigated = true;
        print("🚀 [SPLASH] Navigation vers Home avec destination ${_destinationToSend?.type}");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MyHomePage(title: '', initialDestination: _destinationToSend)),
        );
        print("📦 [SPLASH] Aucune navigation en cache");
      }
    },);

    // Signaler que le cache est prêt
    // if (!_cacheReady.isCompleted) _cacheReady.complete();
    print("📦 2 [SPLASH] _prepareDestination - pendingType = $_pendingNavigationType");
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
      default:
        _destinationToSend = DestinationData(type: 'home');
    }
    print("✅ [SPLASH] Destination créée : ${_destinationToSend?.type}");

    if (_hasNavigated) return;
    _hasNavigated = true;
    print("🚀 [SPLASH] Navigation vers Home avec destination ${_destinationToSend?.type}");
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => MyHomePage(title: '', initialDestination: _destinationToSend)),
    );
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
    } catch (e) { print("❌ Erreur chargement post : $e"); }
    finally { if (mounted) setState(() => _isLoadingTarget = false); }
  }

  Future<void> _loadChatData() async {
    if (_pendingChatId == null || _pendingSendUserId == null) return;
    setState(() { _isLoadingTarget = true; _loadingText = "Chargement du chat..."; });
    try {
      final chatDoc = await FirebaseFirestore.instance.collection('Chats').doc(_pendingChatId).get();
      if (!chatDoc.exists) return;
      final chat = Chat.fromJson(chatDoc.data() as Map<String, dynamic>);
      final userDoc = await FirebaseFirestore.instance.collection('Users').doc(_pendingSendUserId).get();
      if (userDoc.exists) {
        chat.chatFriend = UserData.fromJson(userDoc.data() as Map<String, dynamic>);
        chat.receiver = chat.chatFriend;
      }
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('Messages')
          .where('chat_id', isEqualTo: _pendingChatId)
          .orderBy('createdAt', descending: true)
          .limit(25)
          .get();
      chat.messages = messagesSnapshot.docs.map((d) => Message.fromJson(d.data() as Map<String, dynamic>)).toList();
      _loadedChat = chat;
    } catch (e) { print("❌ Erreur chargement chat : $e"); }
    finally { if (mounted) setState(() => _isLoadingTarget = false); }
  }

  void _navigateToHomeWithDestination() {
    if (_hasNavigated) return;
    _hasNavigated = true;
    print("🚀 [SPLASH] Navigation vers Home avec destination ${_destinationToSend?.type}");
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => MyHomePage(title: '', initialDestination: _destinationToSend)),
    );
  }

  void _redirectToLogin() {
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginPageUser()));
  }

  // --- Gestion vidéo (inchangée) ---
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
      print("❌ Erreur vérification vidéo : $e");
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
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    // if (_isAuthCompleted && !_hasError && !_hasNavigated && (isFinished || !shouldPlayVideo)) {
    //   WidgetsBinding.instance.addPostFrameCallback((_) { if (!_hasNavigated) _navigateToHomeWithDestination(); });
    // }

    if (_hasError) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 16),
              const Text('Une erreur est survenue', style: TextStyle(color: Colors.white, fontSize: 16)),
              const SizedBox(height: 8),
              Text(_errorMessage, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _redirectToLogin,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                child: const Text('Retour à l\'accueil'),
              ),
            ],
          ),
        ),
      );
    }

    if (isLoadingVideo && shouldPlayVideo) return _buildLoadingScreen("Chargement de la vidéo...");
    if (isFinished || !shouldPlayVideo) return _buildSplashWithStream(height, width);
    return _buildVideoScreen();
  }

  Widget _buildSplashWithStream(double height, double width) {
    return Scaffold(
      body: Container(
        height: height, width: width,
        decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/splash/spc2.jpg'), fit: BoxFit.cover)),
        child: Padding(
          padding: const EdgeInsets.only(top: 40.0, bottom: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(height: 100, width: 100, child: Image.asset('assets/logo/afrolook_logo.png')),
              Expanded(
                child: StreamBuilder<User?>(
                  stream: FirebaseAuth.instance.authStateChanges(),
                  builder: (context, snapshot) {
                    if (_authHandled || _isAuthCompleted || _hasNavigated) return const SizedBox.shrink();
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: Color(0xFF25D366)),
                          const SizedBox(height: 20),
                          Text("Vérification de la session...", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        ],
                      );
                    }
                    if (snapshot.hasData && snapshot.data != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!_authHandled && !_isAuthCompleted && !_hasNavigated) _handleAuthenticatedUser(snapshot.data!);
                      });
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 40),
                          const SizedBox(height: 16),
                          Text(_loadingText, style: const TextStyle(color: Colors.white, fontSize: 14)),
                          const SizedBox(height: 8),
                          const LinearProgressIndicator(
                            backgroundColor: Colors.grey,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF25D366)),
                          ),
                        ],
                      );
                    }
                    WidgetsBinding.instance.addPostFrameCallback((_) { if (!_hasNavigated) _redirectToLogin(); });
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_outline, color: Colors.orange, size: 40),
                        const SizedBox(height: 16),
                        const Text("Session expirée", style: TextStyle(color: Colors.white, fontSize: 14)),
                        const SizedBox(height: 8),
                        Text("Redirection vers la connexion...", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                      ],
                    );
                  },
                ),
              ),
              if (_isLoadingTarget || _loadedPost != null || _loadedChat != null)
                Padding(padding: const EdgeInsets.only(bottom: 30), child: _buildLoadingStatus()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingStatus() {
    if (_isLoadingTarget) {
      return const Column(children: [
        Icon(Icons.downloading, color: Colors.orange, size: 30),
        SizedBox(height: 8),
        Text("Chargement du contenu...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
      ]);
    }
    if (_loadedPost != null || _loadedChat != null) {
      return const Column(children: [
        Icon(Icons.check_circle, color: Colors.green, size: 30),
        SizedBox(height: 8),
        Text("Contenu prêt !", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
        SizedBox(height: 4),
        Text("Redirection...", style: TextStyle(color: Colors.grey, fontSize: 12)),
      ]);
    }
    return const SizedBox.shrink();
  }

  Widget _buildLoadingScreen(String text) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF25D366)),
            const SizedBox(height: 20),
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
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


// import 'package:afrotok/pages/postDetailsVideo.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/foundation.dart';
// import 'package:intl/intl.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// import 'package:afrotok/pages/auth/authTest/Screens/updateUserData.dart';
// import 'package:afrotok/pages/postDetails.dart';
// import 'package:afrotok/providers/afroshop/categorie_produits_provider.dart';
// import 'package:afrotok/providers/postProvider.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
//
// import 'package:video_player/video_player.dart';
//
// import '../models/model_data.dart';
// import '../providers/authProvider.dart';
// import '../providers/userProvider.dart';
//
// import 'auth/authTest/Screens/Login/loginPageUser.dart';
//
// import 'dart:async';
//
// import '../providers/chroniqueProvider.dart';
// import '../providers/contenuPayantProvider.dart';
// import 'home/homeScreen.dart';
//
// class SplashChargement extends StatefulWidget {
//   final String postId;
//   final String postType;
//
//   const SplashChargement({super.key, required this.postId, required this.postType});
//
//   @override
//   State<SplashChargement> createState() => _ChargementState();
// }
//
// class _ChargementState extends State<SplashChargement> {
//   late UserAuthProvider authProvider;
//   late PostProvider postProvider;
//   late CategorieProduitProvider categorieProduitProvider;
//   late UserProvider userProvider;
//   late ChroniqueProvider chroniqueProvider;
//   late ContentProvider contentProvider;
//
//   VideoPlayerController? _controller;
//   bool isFinished = false;
//   bool isLoadingVideo = true;
//   bool shouldPlayVideo = false;
//   bool _isAuthCompleted = false;
//   bool _hasError = false;
//   String _loadingText = "Initialisation...";
//   String _errorMessage = "";
//
//   Post? _targetPost;
//   bool _isLoadingTargetPost = false;
//
//   bool _hasNavigated = false;
//   bool _isProcessing = false;
//
//   @override
//   void initState() {
//     super.initState();
//
//     authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     postProvider = Provider.of<PostProvider>(context, listen: false);
//     categorieProduitProvider = Provider.of<CategorieProduitProvider>(context, listen: false);
//     userProvider = Provider.of<UserProvider>(context, listen: false);
//     chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);
//     contentProvider = Provider.of<ContentProvider>(context, listen: false);
//
//     _startInitFlow();
//   }
//
//   void _startInitFlow() async {
//     if (_isProcessing) return;
//     _isProcessing = true;
//
//     try {
//       setState(() {
//         isFinished = false;
//         _loadingText = "Initialisation...";
//         _hasError = false;
//       });
//
//       // 1️⃣ Vérifier si c'est la première ouverture
//       final isFirst = await authProvider.getIsFirst();
//
//       if (isFirst == null || isFirst == false) {
//         await authProvider.storeIsFirst(true);
//         if (mounted && !_hasNavigated) {
//           _hasNavigated = true;
//           Navigator.pushReplacementNamed(context, '/introduction');
//         }
//         return;
//       }
//
//       // 2️⃣ Vérifier la vidéo d'intro
//       await _checkIfShouldPlayVideo();
//
//     } catch (e) {
//       print('❌ Erreur initialisation: $e');
//       setState(() {
//         _hasError = true;
//         _errorMessage = e.toString();
//       });
//       _isProcessing = false;
//     }
//   }
//
//   // Gestion utilisateur authentifié (appelée par StreamBuilder)
//   Future<void> _handleAuthenticatedUser(User user) async {
//     if (_isAuthCompleted || _hasNavigated) return;
//
//     print("✅ [AUTH] Utilisateur connecté: ${user.uid}");
//
//     try {
//       // Charger les données de l'application
//       setState(() => _loadingText = "Chargement des données...");
//       await authProvider.getAppData();
//
//       // Login backend
//       setState(() => _loadingText = "Connexion...");
//       final success = await authProvider.getLoginUser(user.uid);
//
//       if (!success) {
//         print("❌ [AUTH] Échec du login backend");
//         if (mounted && !_hasNavigated) {
//           _hasNavigated = true;
//           _redirectToLoginAndClearStack();
//         }
//         return;
//       }
//
//       // Vérifier les données pays
//       final countryCode = authProvider.loginUserData.countryData?["countryCode"]?.toString();
//
//       if (countryCode == null || countryCode.isEmpty) {
//         print("📍 [AUTH] Pays manquant, redirection vers mise à jour");
//         if (mounted && !_hasNavigated) {
//           _hasNavigated = true;
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (context) => UpdateUserData(title: "Mise à jour d'adresse"),
//             ),
//           );
//         }
//         return;
//       }
//
//       // Si on a un postId à charger, le charger maintenant
//       if (widget.postId.isNotEmpty) {
//         setState(() {
//           _isLoadingTargetPost = true;
//           _loadingText = "Chargement du post...";
//         });
//         await _loadTargetPost(widget.postId);
//         setState(() {
//           _isLoadingTargetPost = false;
//         });
//       }
//
//       // Marquer l'authentification comme terminée
//       setState(() {
//         _isAuthCompleted = true;
//       });
//
//       // Naviguer vers la destination finale
//       _navigateToDestination();
//
//     } catch (e) {
//       print('❌ [AUTH] Erreur: $e');
//       setState(() {
//         _hasError = true;
//         _errorMessage = e.toString();
//       });
//     }
//   }
//
//   Future<void> _loadTargetPost(String postId) async {
//     try {
//       final doc = await FirebaseFirestore.instance
//           .collection('Posts')
//           .doc(postId)
//           .get();
//
//       if (doc.exists) {
//         final post = Post.fromJson(doc.data() as Map<String, dynamic>);
//         post.id = doc.id;
//
//         // Charger les données utilisateur
//         if (post.user_id != null && post.user_id!.isNotEmpty) {
//           final userDoc = await FirebaseFirestore.instance
//               .collection('Users')
//               .doc(post.user_id)
//               .get();
//           if (userDoc.exists) {
//             post.user = UserData.fromJson(userDoc.data() as Map<String, dynamic>);
//           }
//         }
//
//         // Charger les données canal si nécessaire
//         if (post.canal_id != null && post.canal_id!.isNotEmpty) {
//           final canalDoc = await FirebaseFirestore.instance
//               .collection('Canaux')
//               .doc(post.canal_id)
//               .get();
//           if (canalDoc.exists) {
//             post.canal = Canal.fromJson(canalDoc.data() as Map<String, dynamic>);
//           }
//         }
//
//         _targetPost = post;
//         print('✅ [POST] Post chargé: ${post.id}');
//       } else {
//         print('⚠️ [POST] Post non trouvé: $postId');
//       }
//     } catch (e) {
//       print('❌ [POST] Erreur chargement post: $e');
//     }
//   }
//
//   Future<void> _checkIfShouldPlayVideo() async {
//     try {
//       final prefs = await SharedPreferences.getInstance();
//       final lastPlayedDate = prefs.getString('last_video_date3');
//       final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
//
//       if (lastPlayedDate != today) {
//         shouldPlayVideo = true;
//         await prefs.setString('last_video_date3', today);
//         await _initializeVideo();
//       } else {
//         shouldPlayVideo = false;
//         if (mounted) {
//           setState(() {
//             isFinished = true;
//             isLoadingVideo = false;
//             _loadingText = "Chargement de l'application...";
//           });
//         }
//       }
//     } catch (e) {
//       print('❌ Erreur vérification vidéo: $e');
//       shouldPlayVideo = false;
//       if (mounted) {
//         setState(() {
//           isFinished = true;
//           isLoadingVideo = false;
//         });
//       }
//     }
//   }
//
//   Future<void> _initializeVideo() async {
//     try {
//       _controller = VideoPlayerController.asset('assets/videos/intro_video.mp4');
//       await _controller!.initialize();
//       _controller!.setVolume(0.0);
//       _controller!.play();
//
//       _controller!.addListener(() {
//         if (_controller!.value.position >= _controller!.value.duration && !isFinished) {
//           if (mounted) {
//             setState(() {
//               isFinished = true;
//               _loadingText = "Finalisation...";
//             });
//           }
//         }
//       });
//
//       if (mounted) {
//         setState(() => isLoadingVideo = false);
//       }
//     } catch (e) {
//       debugPrint("❌ Erreur d'initialisation vidéo : $e");
//       if (mounted) {
//         setState(() {
//           isFinished = true;
//           isLoadingVideo = false;
//         });
//       }
//     }
//   }
//
//   void _redirectToLoginAndClearStack() {
//     if (!mounted) return;
//     Navigator.of(context).pushAndRemoveUntil(
//       MaterialPageRoute(builder: (_) => LoginPageUser()),
//           (route) => false,
//     );
//   }
//
//   void _navigateToDestination() {
//     if (!mounted) return;
//     if (_hasNavigated) return;
//
//     // Attendre la fin de la vidéo si elle doit être jouée
//     if (shouldPlayVideo && !isFinished) {
//       return;
//     }
//
//     _hasNavigated = true;
//
//     // Si on a un post cible (notification)
//     if (_targetPost != null) {
//       print("🚀 [NAVIGATION] Vers le post cible");
//       if (_targetPost!.dataType == PostDataType.VIDEO.name) {
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(
//             builder: (context) => VideoYoutubePageDetails(initialPost: _targetPost!),
//           ),
//         );
//       } else {
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(
//             builder: (context) => DetailsPost(post: _targetPost!),
//           ),
//         );
//       }
//     }
//     // Si on a un postId mais pas encore chargé (cas rare)
//     else if (widget.postId.isNotEmpty && _targetPost == null && !_isLoadingTargetPost) {
//       print("🚀 [NAVIGATION] Chargement tardif du post");
//       _loadTargetPost(widget.postId).then((_) {
//         if (_targetPost != null) {
//           _navigateToDestination();
//         } else {
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(
//               builder: (context) => MyHomePage(title: ''),
//             ),
//           );
//         }
//       });
//     }
//     // Sinon aller à l'accueil
//     else {
//       print("🚀 [NAVIGATION] Vers MyHomePage");
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(
//           builder: (context) => MyHomePage(title: ''),
//         ),
//       );
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
//     // Vérifier si on peut naviguer (auth + vidéo)
//     if (_isAuthCompleted && !_hasError && !_hasNavigated && (isFinished || !shouldPlayVideo)) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         _navigateToDestination();
//       });
//     }
//
//     // Écran d'erreur
//     if (_hasError) {
//       return Scaffold(
//         backgroundColor: Colors.black,
//         body: Center(
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               const Icon(Icons.error_outline, color: Colors.red, size: 60),
//               const SizedBox(height: 16),
//               const Text(
//                 'Une erreur est survenue',
//                 style: TextStyle(color: Colors.white, fontSize: 16),
//               ),
//               const SizedBox(height: 8),
//               Text(
//                 _errorMessage,
//                 style: const TextStyle(color: Colors.grey, fontSize: 12),
//                 textAlign: TextAlign.center,
//               ),
//               const SizedBox(height: 24),
//               ElevatedButton(
//                 onPressed: () {
//                   _redirectToLoginAndClearStack();
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: const Color(0xFF25D366),
//                 ),
//                 child: const Text('Retour à l\'accueil'),
//               ),
//             ],
//           ),
//         ),
//       );
//     }
//
//     // Chargement de la vidéo
//     if (isLoadingVideo && shouldPlayVideo) {
//       return _buildLoadingScreen("Chargement de la vidéo...");
//     }
//
//     // Splash screen avec StreamBuilder
//     if (isFinished || !shouldPlayVideo) {
//       return _buildSplashScreenWithStream(height, width);
//     }
//
//     // Lecture vidéo
//     return _buildVideoScreen();
//   }
//
//   // NOUVEAU: Splash screen avec StreamBuilder intégré
//   Widget _buildSplashScreenWithStream(double height, double width) {
//     return Scaffold(
//       body: Container(
//         height: height,
//         width: width,
//         decoration: const BoxDecoration(
//           image: DecorationImage(
//             image: AssetImage('assets/splash/spc2.jpg'),
//             fit: BoxFit.cover,
//           ),
//         ),
//         child: Padding(
//           padding: const EdgeInsets.only(top: 40.0, bottom: 10),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               // LOGO
//               SizedBox(
//                 height: 100,
//                 width: 100,
//                 child: Image.asset('assets/logo/afrolook_logo.png'),
//               ),
//
//               // STREAM BUILDER POUR L'AUTHENTIFICATION
//               Expanded(
//                 child: StreamBuilder<User?>(
//                   stream: FirebaseAuth.instance.authStateChanges(),
//                   builder: (context, snapshot) {
//                     print("🔥 [STREAM] connectionState: ${snapshot.connectionState}");
//                     print("🔥 [STREAM] hasData: ${snapshot.hasData}");
//
//                     // Pendant le chargement
//                     if (snapshot.connectionState == ConnectionState.waiting) {
//                       return Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           const CircularProgressIndicator(color: Color(0xFF25D366)),
//                           const SizedBox(height: 20),
//                           Text(
//                             "Vérification de la session...",
//                             style: const TextStyle(color: Colors.white70, fontSize: 14),
//                           ),
//                         ],
//                       );
//                     }
//
//                     // Utilisateur connecté
//                     if (snapshot.hasData && snapshot.data != null) {
//                       // Appeler la gestion utilisateur (une seule fois)
//                       WidgetsBinding.instance.addPostFrameCallback((_) {
//                         if (!_isAuthCompleted && !_hasNavigated) {
//                           _handleAuthenticatedUser(snapshot.data!);
//                         }
//                       });
//
//                       return Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           const Icon(Icons.check_circle, color: Colors.green, size: 40),
//                           const SizedBox(height: 16),
//                           Text(
//                             _loadingText,
//                             style: const TextStyle(color: Colors.white, fontSize: 14),
//                           ),
//                           const SizedBox(height: 8),
//                           const LinearProgressIndicator(
//                             backgroundColor: Colors.grey,
//                             valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF25D366)),
//                           ),
//                         ],
//                       );
//                     }
//
//                     // Utilisateur NON connecté
//                     if (!snapshot.hasData || snapshot.data == null) {
//                       WidgetsBinding.instance.addPostFrameCallback((_) {
//                         if (!_hasNavigated) {
//                           _hasNavigated = true;
//                           _redirectToLoginAndClearStack();
//                         }
//                       });
//
//                       return Column(
//                         mainAxisAlignment: MainAxisAlignment.center,
//                         children: [
//                           const Icon(Icons.lock_outline, color: Colors.orange, size: 40),
//                           const SizedBox(height: 16),
//                           const Text(
//                             "Session expirée",
//                             style: TextStyle(color: Colors.white, fontSize: 14),
//                           ),
//                           const SizedBox(height: 8),
//                           Text(
//                             "Redirection vers la connexion...",
//                             style: TextStyle(color: Colors.grey[400], fontSize: 12),
//                           ),
//                         ],
//                       );
//                     }
//
//                     return const SizedBox.shrink();
//                   },
//                 ),
//               ),
//
//               // STATUT DE CHARGEMENT (post cible)
//               if (_isLoadingTargetPost || _targetPost != null)
//                 Column(
//                   children: [
//                     _buildLoadingStatus(),
//                     const SizedBox(height: 10),
//                     SizedBox(
//                       width: 100,
//                       child: LinearProgressIndicator(
//                         backgroundColor: Colors.grey[800],
//                         valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF25D366)),
//                         minHeight: 4,
//                       ),
//                     ),
//                   ],
//                 ),
//
//               const SizedBox(height: 50),
//             ],
//           ),
//         ),
//       ),
//     );
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
//             Text(
//               text,
//               style: const TextStyle(color: Colors.white, fontSize: 16),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildLoadingStatus() {
//     // Chargement du post cible (notification)
//     if (_isLoadingTargetPost) {
//       return Column(
//         children: [
//           const Icon(Icons.downloading, color: Colors.orange, size: 30),
//           const SizedBox(height: 8),
//           const Text(
//             "Chargement du contenu...",
//             style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             _loadingText,
//             style: const TextStyle(color: Colors.grey, fontSize: 12),
//           ),
//         ],
//       );
//     }
//
//     // Si on a un post cible chargé
//     if (_targetPost != null) {
//       return Column(
//         children: [
//           const Icon(Icons.check_circle, color: Colors.green, size: 30),
//           const SizedBox(height: 8),
//           const Text(
//             "Contenu prêt !",
//             style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
//           ),
//           const SizedBox(height: 4),
//           Text(
//             "Redirection...",
//             style: TextStyle(color: Colors.grey, fontSize: 12),
//           ),
//         ],
//       );
//     }
//
//     return const SizedBox.shrink();
//   }
//
//   Widget _buildVideoScreen() {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Stack(
//         children: [
//           // VIDÉO
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
//
//           // INDICATEUR DE CHARGEMENT
//           Positioned(
//             bottom: 100,
//             left: 0,
//             right: 0,
//             child: Container(
//               padding: const EdgeInsets.all(16),
//               child: Column(
//                 children: [
//                   if (_isAuthCompleted && _targetPost != null)
//                     const Text(
//                       "Redirection...",
//                       style: TextStyle(color: Colors.white, fontSize: 14),
//                     ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }