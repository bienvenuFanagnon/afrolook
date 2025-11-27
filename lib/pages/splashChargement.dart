import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';
import 'dart:math';

import 'package:afrotok/constant/constColors.dart';
import 'package:afrotok/pages/auth/authTest/Screens/updateUserData.dart';
import 'package:afrotok/pages/postDetails.dart';
import 'package:afrotok/providers/afroshop/categorie_produits_provider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:provider/provider.dart';
import 'package:ripple_wave/ripple_wave.dart';
import 'package:upgrader/upgrader.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../models/model_data.dart';
import '../providers/authProvider.dart';
import '../providers/mixed_feed_service_provider.dart';
import '../providers/userProvider.dart';
import '../services/linkService.dart';

import '../services/postService/mixed_feed_service.dart';
import 'component/consoleWidget.dart';

import 'dart:async';

import '../providers/chroniqueProvider.dart';
import '../providers/contenuPayantProvider.dart';
import 'home/homeScreen.dart';

class SplahsChargement extends StatefulWidget {
  final String postId;
  final String postType;
  const SplahsChargement({super.key, required this.postId, required this.postType});

  @override
  State<SplahsChargement> createState() => _ChargementState();
}

class _ChargementState extends State<SplahsChargement> {
  late UserAuthProvider authProvider;
  late PostProvider postProvider;
  late CategorieProduitProvider categorieProduitProvider;
  late UserProvider userProvider;
  late ChroniqueProvider chroniqueProvider;
  late ContentProvider contentProvider;

  // 🔥 SERVICE DE FEED - SEULEMENT POUR LES POSTS
  MixedFeedService? _mixedFeedService;

  VideoPlayerController? _controller;
  bool isFinished = false;
  bool isLoadingVideo = true;
  bool shouldPlayVideo = false;
  bool _isAuthCompleted = false;
  bool _arePostsPrepared = false;
  bool _hasError = false;
  String _loadingText = "Initialisation...";

  final int app_version_code = 36;

  @override
  void initState() {
    super.initState();

    // Initialiser les providers
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);
    categorieProduitProvider = Provider.of<CategorieProduitProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);
    contentProvider = Provider.of<ContentProvider>(context, listen: false);

    _startInitFlow();
  }

  Future<void> _startInitFlow() async {
    setState(() {
      isFinished = false;
      _loadingText = "Vérification de la vidéo...";
    });

    await _checkIfShouldPlayVideo();

    // 🔥 LANCER L'AUTHENTIFICATION ET PRÉPARATION DES POSTS
    _initAuthAndPosts();
  }

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
        // MODIFIER ICI :
        if (mounted) {
          setState(() {
            isFinished = true;
            isLoadingVideo = false;
            _loadingText = "Chargement de l'application...";
          });
        }
      }
    } catch (e) {
      print('❌ Erreur vérification vidéo: $e');
      shouldPlayVideo = false;
      // MODIFIER ICI AUSSI :
      if (mounted) {
        setState(() {
          isFinished = true;
          isLoadingVideo = false;
          _loadingText = "Chargement de l'application...";
        });
      }
    }
  }
  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.asset('assets/videos/intro_video.mp4');
      await _controller!.initialize();
      _controller!.setVolume(0.0);
      _controller!.play();

      _controller!.addListener(() {
        if (_controller!.value.position >= _controller!.value.duration && !isFinished) {
          // MODIFIER ICI :
          if (mounted) {
            setState(() {
              isFinished = true;
              _loadingText = "Finalisation...";
            });
          }
        }
      });

      // MODIFIER ICI AUSSI :
      if (mounted) {
        setState(() => isLoadingVideo = false);
      }
    } catch (e) {
      debugPrint("❌ Erreur d'initialisation vidéo : $e");
      // MODIFIER ICI AUSSI :
      if (mounted) {
        setState(() {
          isFinished = true;
          isLoadingVideo = false;
          _loadingText = "Chargement de l'application...";
        });
      }
    }
  }
  // 🔥 AUTHENTIFICATION ET PRÉPARATION DES POSTS
  Future<void> _initAuthAndPosts() async {
    try {
      if (mounted) {
        setState(() => _loadingText = "Chargement des données...");
      }
      // 1. CHARGER LES DONNÉES DE L'APP
      await authProvider.getAppData();

      // 2. VÉRIFIER SI PREMIÈRE UTILISATION
      final isFirst = await authProvider.getIsFirst();
      if (isFirst == null || isFirst == false) {
        authProvider.storeIsFirst(true);
        if (mounted) {
          Navigator.pushNamed(context, '/introduction');
        }
        return;
      }

      // 3. VÉRIFIER LE TOKEN
      final token = await authProvider.getToken();
      if (token == null || token.isEmpty) {
        if (mounted) {
          Navigator.pushNamed(context, '/introduction');
        }
        return;
      }

      // 4. CONNEXION UTILISATEUR
      setState(() => _loadingText = "Connexion...");
      final success = await authProvider.getLoginUser(token);

      if (!success) {
        if (mounted) {
          Navigator.pushNamed(context, '/introduction');
        }
        return;
      }

      setState(() => _isAuthCompleted = true);

      // 5. VÉRIFIER LES DONNÉES PAYS
      if (authProvider.loginUserData.countryData?["countryCode"] == null) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UpdateUserData(title: "Mise à jour d'adresse"),
            ),
          );
        }
        return;
      }

      // 6. 🔥 PRÉPARER UNIQUEMENT LES POSTS (100 IDs uniques)
      await _preparePostsOnly();

      // 7. NAVIGUER VERS MY HOMEPAGE
      _navigateToDestination();

    } catch (e) {
      print('❌ Erreur lors de l\'initialisation: $e');
      setState(() {
        _hasError = true;
        _loadingText = "Erreur de chargement";
      });

      // Fallback: aller à l'introduction en cas d'erreur
      if (mounted) {
        await Future.delayed(Duration(seconds: 2));
        Navigator.pushNamed(context, '/introduction');
      }
    }
  }

  // 🔥 PRÉPARER SEULEMENT LES POSTS (100 IDs uniques)
// 🔥 DANS VOTRE SPLASH SCREEN
  Future<void> _preparePostsOnly() async {
    try {
      if (authProvider.loginUserData.id == null) return;

      if (mounted) {
        setState(() => _loadingText = "Préparation des posts...");
      }

      // 🔥 INITIALISER LE PROVIDER
      final mixedFeedProvider = Provider.of<MixedFeedServiceProvider>(context, listen: false);

      // Initialiser le service
      mixedFeedProvider.initializeService(
        authProvider: authProvider,
        categorieProvider: categorieProduitProvider,
        postProvider: postProvider,
        chroniqueProvider: chroniqueProvider,
        contentProvider: contentProvider,
      );

      // 🔥 PRÉPARER LES POSTS (100 IDs uniques)
      await mixedFeedProvider.preparePosts();

      // MODIFIER ICI AUSSI :
      if (mounted) {
        setState(() => _arePostsPrepared = mixedFeedProvider.isPrepared);
      }

      print('✅ Posts préparés avec succès: ${mixedFeedProvider.preparedPostsCount} IDs uniques');

    } catch (e) {
      print('❌ Erreur préparation posts: $e');
    }
  }

// 🔥 NAVIGATION SIMPLIFIÉE
  void _navigateToDestination() {
    if (!mounted) return;

    if (shouldPlayVideo && !isFinished) {
      return;
    }

    if (widget.postId.isNotEmpty) {
      final AppLinkService linkService = AppLinkService();
      linkService.handleNavigation(context, widget.postId, widget.postType);
    } else {
      // 🔥 NAVIGATION SIMPLE - LE SERVICE EST DÉJÀ DANS LE PROVIDER
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MyHomePage(
            title: '',
            preloadedFeedService: _mixedFeedService, // 🔥 PASSER LE SERVICE
          ),
        ),
      );
    }
  }  // 🔥 NAVIGATION VERS MY HOMEPAGE

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    // 🔥 VÉRIFIER SI ON PEUT NAVIGUER (auth complète + vidéo finie)
    if (_isAuthCompleted && (isFinished || !shouldPlayVideo)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToDestination();
      });
    }

    // ✅ ÉTAPE 1 : LOADER PENDANT LA PRÉPARATION VIDÉO
    if (isLoadingVideo && shouldPlayVideo) {
      return _buildLoadingScreen("Chargement de la vidéo...");
    }

    // ✅ ÉTAPE 2 : SPLASH APRÈS VIDÉO OU SANS VIDÉO
    if (isFinished || !shouldPlayVideo) {
      return _buildSplashScreen(height, width);
    }

    // ✅ ÉTAPE 3 : LECTURE VIDÉO
    return _buildVideoScreen();
  }

  Widget _buildLoadingScreen(String text) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.green),
            SizedBox(height: 20),
            Text(
              text,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplashScreen(double height, double width) {
    return Scaffold(
      body: Container(
        height: height,
        width: width,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/splash/spc2.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 40.0, bottom: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // LOGO
              SizedBox(
                height: 100,
                width: 100,
                child: Image.asset('assets/logo/afrolook_logo.png'),
              ),

              // 🔥 STATUT DE CHARGEMENT DYNAMIQUE
              Column(
                children: [
                  if (_hasError)
                    _buildErrorStatus()
                  else if (!_isAuthCompleted)
                    _buildAuthStatus()
                  else
                    _buildPostsStatus(),

                  SizedBox(height: 10),

                  // INDICATEUR DE PROGRESSION
                  SizedBox(
                    width: 100,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.grey[800],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorStatus() {
    return Column(
      children: [
        Icon(Icons.error_outline, color: Colors.red, size: 30),
        SizedBox(height: 8),
        Text(
          "Erreur de connexion",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 4),
        Text(
          "Redirection...",
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthStatus() {
    return Column(
      children: [
        Icon(Icons.security, color: Colors.blue, size: 30),
        SizedBox(height: 8),
        Text(
          _loadingText,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 4),
        Text(
          "Vérification des identifiants...",
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildPostsStatus() {
    return Column(
      children: [
        Icon(
          _arePostsPrepared ? Icons.check_circle : Icons.downloading,
          color: _arePostsPrepared ? Colors.green : Colors.orange,
          size: 30,
        ),
        SizedBox(height: 8),
        Text(
          _arePostsPrepared ? "Prêt !" : "Préparation des posts...",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 4),
        Text(
          _arePostsPrepared ? "Redirection..." : "Chargement des publications...",
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildVideoScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // VIDÉO
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

          // OVERLAY DE CHARGEMENT
          if (_isAuthCompleted && _arePostsPrepared)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      "Posts prêts !",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Redirection vers l'accueil...",
                      style: TextStyle(
                        color: Colors.grey[300],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}