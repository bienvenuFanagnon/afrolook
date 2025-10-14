
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
import '../providers/userProvider.dart';
import '../services/linkService.dart';

import '../services/postPrepareService.dart';
import 'component/consoleWidget.dart';

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';



class SplahsChargement extends StatefulWidget {
  final String postId;
  final String postType;
  const SplahsChargement({super.key, required this.postId, required this.postType});

  @override
  State<SplahsChargement> createState() => _ChargementState();
}

class _ChargementState extends State<SplahsChargement> {
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  late CategorieProduitProvider categorieProduitProvider =
  Provider.of<CategorieProduitProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);

  VideoPlayerController? _controller;
  bool isFinished = false;
  bool isLoadingVideo = true;
  bool shouldPlayVideo = false;
  final int app_version_code = 36;

  @override
  void initState() {
    super.initState();
    _startInitFlow();
  }

  Future<void> _startInitFlow() async {
    setState(() => isFinished = false);

    await _checkIfShouldPlayVideo(); // vérifie si on doit jouer la vidéo

    // Pendant que la vidéo charge, on peut déjà préparer authProvider
    _initAuthFlow();
  }

  Future<void> _checkIfShouldPlayVideo() async {
    final prefs = await SharedPreferences.getInstance();
    final lastPlayedDate = prefs.getString('last_video_date3');
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    if (lastPlayedDate != today) {
      shouldPlayVideo = true;
      await prefs.setString('last_video_date3', today);
      await _initializeVideo();
    } else {
      shouldPlayVideo = false;
      setState(() {
        isFinished = true;
        isLoadingVideo = false;
      });
    }
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.asset('assets/videos/intro_video.mp4');
    try {
      await _controller!.initialize();
      _controller!.setVolume(0.0);
      _controller!.play();

      _controller!.addListener(() {
        if (_controller!.value.position >= _controller!.value.duration &&
            !isFinished) {
          setState(() => isFinished = true);
        }
      });

      setState(() => isLoadingVideo = false);
    } catch (e) {
      debugPrint("❌ Erreur d'initialisation vidéo : $e");
      setState(() {
        isFinished = true;
        isLoadingVideo = false;
      });
    }
  }

  void _initAuthFlow() {
    authProvider.getAppData().then((_) async {
      authProvider.getIsFirst().then((value) {
        if (value == null || value == false) {
          authProvider.storeIsFirst(true);
          if (mounted) Navigator.pushNamed(context, '/introduction');
        } else {
          authProvider.getToken().then((token) async {
            if (token == null || token.isEmpty) {
              Navigator.pushNamed(context, '/introduction');
            } else {
              final success = await authProvider.getLoginUser(token);
              if (success) {
                if (authProvider.loginUserData.countryData?["countryCode"] != null) {
                  if (widget.postId.isNotEmpty) {
                    final AppLinkService linkService = AppLinkService();
                    linkService.handleNavigation(context, widget.postId, widget.postType);
                  } else {
                    Navigator.pushNamed(context, '/home');
                  }
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          UpdateUserData(title: "Mise à jour d'adresse"),
                    ),
                  );
                }
              } else {
                Navigator.pushNamed(context, '/introduction');
              }
            }
          });
        }
      });
    });
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

    // ✅ Étape 1 : loader pendant la préparation
    if (isLoadingVideo && shouldPlayVideo) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.green)),
      );
    }

    // ✅ Étape 2 : splash après vidéo
    if (isFinished || !shouldPlayVideo) {
      return _buildSplash(height, width);
    }

    // ✅ Étape 3 : lecture vidéo
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _controller != null && _controller!.value.isInitialized
            ? SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
        )
            : const CircularProgressIndicator(color: Colors.green),
      ),
    );
  }

  Widget _buildSplash(double height, double width) {
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
              SizedBox(
                height: 100,
                width: 100,
                child: Image.asset('assets/logo/afrolook_logo.png'),
              ),
              const Text(
                "Connexion...",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// Importez votre service de préparation des posts
// import '../services/post_preparation_service.dart';

// class SplahsChargement extends StatefulWidget {
//   final String postId;
//   final String postType;
//   const SplahsChargement({super.key, required this.postId, required this.postType});
//
//   @override
//   State<SplahsChargement> createState() => _ChargementState();
// }
//
// class _ChargementState extends State<SplahsChargement> {
//   late UserAuthProvider authProvider;
//   late PostProvider postProvider;
//   late CategorieProduitProvider categorieProduitProvider;
//   late UserProvider userProvider;
//
//   VideoPlayerController? _controller;
//   bool isFinished = false;
//   bool isLoadingVideo = true;
//   bool shouldPlayVideo = false;
//   bool _arePostsPrepared = false;
//   bool _isAuthCompleted = false;
//   bool _hasError = false;
//   String _currentStatus = "Initialisation...";
//
//   final int app_version_code = 36;
//   final Stopwatch _stopwatch = Stopwatch();
//
//   @override
//   void initState() {
//     super.initState();
//     authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     postProvider = Provider.of<PostProvider>(context, listen: false);
//     categorieProduitProvider = Provider.of<CategorieProduitProvider>(context, listen: false);
//     userProvider = Provider.of<UserProvider>(context, listen: false);
//
//     _stopwatch.start();
//     _startOptimizedInitFlow();
//   }
//
//   Future<void> _startOptimizedInitFlow() async {
//     print('🚀 Démarrage optimisé du splash screen');
//
//     try {
//       // Étape 1: Vérifier la vidéo en parallèle avec les autres traitements
//       await _checkIfShouldPlayVideo();
//
//       // Étape 2: Lancer TOUS les traitements en parallèle
//       await Future.wait([
//         // _startPostsPreparation(),     // Préparation des posts
//         _initAuthFlowOptimized(),     // Authentification
//         if (shouldPlayVideo) _initializeVideo(), // Vidéo si nécessaire
//       ], eagerError: false); // Ne pas s'arrêter aux erreurs
//
//     } catch (e) {
//       print('❌ Erreur lors de l\'initialisation: $e');
//       _hasError = true;
//     } finally {
//       // Marquer comme terminé après un délai maximum
//       _markAsCompleted();
//     }
//   }
//
//   Future<void> _checkIfShouldPlayVideo() async {
//     _updateStatus("Vérification vidéo...");
//     final prefs = await SharedPreferences.getInstance();
//     final lastPlayedDate = prefs.getString('last_video_date3');
//     final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
//
//     if (lastPlayedDate != today) {
//       shouldPlayVideo = true;
//       unawaited(prefs.setString('last_video_date3', today));
//     } else {
//       shouldPlayVideo = false;
//       setState(() {
//         isFinished = true;
//         isLoadingVideo = false;
//       });
//     }
//     print('📹 Vidéo nécessaire: $shouldPlayVideo (${_stopwatch.elapsedMilliseconds}ms)');
//   }
//
//   Future<void> _initializeVideo() async {
//     _updateStatus("Chargement vidéo...");
//     _controller = VideoPlayerController.asset('assets/videos/intro_video.mp4');
//
//     try {
//       await _controller!.initialize();
//       _controller!.setVolume(0.0);
//       _controller!.play();
//
//       _controller!.addListener(_videoListener);
//       setState(() => isLoadingVideo = false);
//
//       print('🎬 Vidéo initialisée (${_stopwatch.elapsedMilliseconds}ms)');
//     } catch (e) {
//       debugPrint("❌ Erreur vidéo: $e");
//       setState(() {
//         isFinished = true;
//         isLoadingVideo = false;
//       });
//     }
//   }
//
//   void _videoListener() {
//     if (_controller!.value.position >= _controller!.value.duration && !isFinished) {
//       print('⏹️ Fin vidéo (${_stopwatch.elapsedMilliseconds}ms)');
//       setState(() => isFinished = true);
//       _checkAllTasksCompleted();
//     }
//   }
//
//   // NOUVEAU: Préparation des posts en arrière-plan
//   Future<void> _startPostsPreparation() async {
//     _updateStatus("Préparation du flux...");
//
//     try {
//       final user = FirebaseAuth.instance.currentUser;
//       print('📝 Début préparation posts pour ${user?.uid ?? "anonyme"}');
//
//       // Utilisez votre service de préparation
//       await AppInitializer.initializeApp(userId: user?.uid);
//
//       setState(() {
//         _arePostsPrepared = true;
//       });
//       print('✅ Posts préparés (${_stopwatch.elapsedMilliseconds}ms)');
//       _checkAllTasksCompleted();
//
//     } catch (e) {
//       print('❌ Erreur préparation posts: $e');
//       setState(() {
//         _arePostsPrepared = true; // Continuer même en cas d'erreur
//       });
//       _checkAllTasksCompleted();
//     }
//   }
//
//   // AUTH OPTIMISÉE
//   Future<void> _initAuthFlowOptimized() async {
//     _updateStatus("Authentification...");
//
//     try {
//       print('🔐 Début auth optimisée (${_stopwatch.elapsedMilliseconds}ms)');
//
//       // 1. AppData en premier
//       await authProvider.getAppData();
//       print('📊 AppData chargé (${_stopwatch.elapsedMilliseconds}ms)');
//
//       // 2. Vérifier si premier lancement
//       final isFirst = await authProvider.getIsFirst();
//       if (isFirst == null || isFirst == false) {
//         authProvider.storeIsFirst(true);
//         if (mounted) {
//           _navigateTo('/introduction');
//           return;
//         }
//       }
//
//       // 3. Vérifier le token
//       final token = await authProvider.getToken();
//       if (token == null || token.isEmpty) {
//         _navigateTo('/introduction');
//         return;
//       }
//
//       // 4. Connexion utilisateur
//       final success = await authProvider.getLoginUser(token);
//       if (!success) {
//         _navigateTo('/introduction');
//         return;
//       }
//
//       // 5. Vérifier les données pays
//       if (authProvider.loginUserData.countryData?["countryCode"] == null) {
//         _navigateToPage(UpdateUserData(title: "Mise à jour d'adresse"));
//         return;
//       }
//
//       // Auth réussie
//       setState(() {
//         _isAuthCompleted = true;
//       });
//       print('✅ Auth réussie (${_stopwatch.elapsedMilliseconds}ms)');
//       _checkAllTasksCompleted();
//
//     } catch (e) {
//       print('❌ Erreur auth: $e');
//       _navigateTo('/introduction');
//     }
//   }
//
//   void _checkAllTasksCompleted() {
//     if (_isAuthCompleted && _arePostsPrepared && (isFinished || !shouldPlayVideo)) {
//       print('🎉 TOUTES LES TÂCHES TERMINÉES (${_stopwatch.elapsedMilliseconds}ms)');
//       _navigateToDestination();
//     }
//   }
//
//   void _markAsCompleted() {
//     Future.delayed(Duration(seconds: 8), () { // Timeout de sécurité
//       if (mounted && (!_isAuthCompleted || !_arePostsPrepared)) {
//         print('⏰ Timeout - Navigation forcée');
//         _navigateToDestination();
//       }
//     });
//   }
//
//   void _navigateToDestination() {
//     if (!mounted) return;
//
//     _stopwatch.stop();
//     print('🏁 Navigation après ${_stopwatch.elapsedMilliseconds}ms');
//
//     if (widget.postId.isNotEmpty) {
//       final AppLinkService linkService = AppLinkService();
//       linkService.handleNavigation(context, widget.postId, widget.postType);
//     } else {
//       _navigateTo('/home');
//     }
//   }
//
//   void _navigateTo(String route) {
//     if (mounted) {
//       Navigator.pushNamed(context, route);
//     }
//   }
//
//   void _navigateToPage(Widget page) {
//     if (mounted) {
//       Navigator.push(context, MaterialPageRoute(builder: (context) => page));
//     }
//   }
//
//   void _updateStatus(String status) {
//     if (mounted) {
//       setState(() {
//         _currentStatus = status;
//       });
//     }
//     print('🔄 $status (${_stopwatch.elapsedMilliseconds}ms)');
//   }
//
//   @override
//   void dispose() {
//     _stopwatch.stop();
//     _controller?.removeListener(_videoListener);
//     _controller?.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final height = MediaQuery.of(context).size.height;
//     final width = MediaQuery.of(context).size.width;
//
//     // Écran de chargement vidéo
//     if (isLoadingVideo && shouldPlayVideo) {
//       return _buildLoadingScreen("Chargement de la vidéo...");
//     }
//
//     // Vidéo en cours
//     if (!isFinished && shouldPlayVideo) {
//       return _buildVideoScreen();
//     }
//
//     // Splash screen final (après vidéo ou sans vidéo)
//     return _buildOptimizedSplash(height, width);
//   }
//
//   Widget _buildLoadingScreen(String message) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             CircularProgressIndicator(color: Colors.green),
//             SizedBox(height: 20),
//             Text(
//               message,
//               style: TextStyle(color: Colors.white, fontSize: 16),
//             ),
//             SizedBox(height: 10),
//             Text(
//               _currentStatus,
//               style: TextStyle(color: Colors.grey, fontSize: 12),
//             ),
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
//             _buildLoadingScreen("Initialisation vidéo..."),
//
//           // Overlay de statut pendant la vidéo
//           Positioned(
//             bottom: 100,
//             left: 0,
//             right: 0,
//             child: Container(
//               padding: EdgeInsets.all(16),
//               child: Text(
//                 _currentStatus,
//                 textAlign: TextAlign.center,
//                 style: TextStyle(
//                   color: Colors.white,
//                   fontSize: 14,
//                   backgroundColor: Colors.black54,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildOptimizedSplash(double height, double width) {
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
//               SizedBox(
//                 height: 100,
//                 width: 100,
//                 child: Image.asset('assets/logo/afrolook_logo.png'),
//               ),
//
//               // Section de statut améliorée
//               Column(
//                 children: [
//                   // Indicateur de progression
//                   if (!_arePostsPrepared || !_isAuthCompleted) ...[
//                     SizedBox(
//                       width: 50,
//                       height: 50,
//                       child: Stack(
//                         children: [
//                           CircularProgressIndicator(
//                             value: _getOverallProgress(),
//                             color: Colors.green,
//                             strokeWidth: 4,
//                           ),
//                           Center(
//                             child: Text(
//                               '${(_getOverallProgress() * 100).toInt()}%',
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.bold,
//                               ),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     SizedBox(height: 15),
//                   ],
//
//                   // Statut actuel
//                   Text(
//                     _currentStatus,
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 16,
//                       fontWeight: FontWeight.w500,
//                     ),
//                   ),
//
//                   SizedBox(height: 10),
//
//                   // Détails de progression
//                   if (!_arePostsPrepared || !_isAuthCompleted) ...[
//                     _buildProgressIndicator("Authentification", _isAuthCompleted),
//                     _buildProgressIndicator("Flux personnel", _arePostsPrepared),
//                     SizedBox(height: 20),
//                   ],
//
//                   const Text(
//                     "Connexion...",
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontWeight: FontWeight.w900,
//                       fontSize: 20,
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildProgressIndicator(String label, bool isCompleted) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4.0),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(
//             isCompleted ? Icons.check_circle : Icons.access_time,
//             color: isCompleted ? Colors.green : Colors.orange,
//             size: 16,
//           ),
//           SizedBox(width: 8),
//           Text(
//             label,
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 12,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   double _getOverallProgress() {
//     int completedTasks = 0;
//     if (_isAuthCompleted) completedTasks++;
//     if (_arePostsPrepared) completedTasks++;
//     if (isFinished || !shouldPlayVideo) completedTasks++;
//
//     return completedTasks / 3;
//   }
//}

