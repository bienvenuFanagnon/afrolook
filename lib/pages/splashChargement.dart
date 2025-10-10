
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

import 'component/consoleWidget.dart';

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
