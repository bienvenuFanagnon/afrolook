import 'dart:async';
import 'package:afrotok/pages/pub/native_ad_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:afrotok/models/model_data.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:linkify/linkify.dart'; // ajoutez cette dépendance

const _afroBlack = Color(0xFF000000);
const _afroGreen = Color(0xFF2ECC71);
const _afroYellow = Color(0xFFF1C40F);
const _afroRed = Color(0xFFE74C3C);
const _afroDarkGrey = Color(0xFF16181C);
const _afroLightGrey = Color(0xFF71767B);
const _twitterTextSecondary = Color(0xFF71767B);
const _twitterBlue = Color(0xFF1D9BF0);

class AdPostWidget extends StatefulWidget {
  final Map<String, dynamic> adData;
  final double width;
  final double height;
  final VoidCallback onComplete;

  const AdPostWidget({
    Key? key,
    required this.adData,
    required this.width,
    required this.height,
    required this.onComplete,
  }) : super(key: key);

  @override
  _AdPostWidgetState createState() => _AdPostWidgetState();
}

class _AdPostWidgetState extends State<AdPostWidget> {
  late Post post;
  late Advertisement ad;
  bool isVideo = false;
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  Timer? _autoAdvanceTimer;
  bool _isVideoInitialized = false;
  int _currentImageIndex = 0;
  PageController? _imagePageController;
  bool _isLoading = true;
  bool _isDescriptionExpanded = false;
  bool _hasRecordedView = false;
  Timer? _visibilityTimer;
  @override
  void initState() {
    super.initState();
    post = Post.fromJson(widget.adData['post']);
    ad = Advertisement.fromJson(widget.adData['ad']);
    isVideo = post.dataType == PostDataType.VIDEO.name ||
        (post.url_media?.contains('.mp4') ?? false) ||
        (post.url_media?.contains('.mov') ?? false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startVisibilityTimer();
    });
    if (isVideo) {
      _initVideo();
    } else {
      _initImageCarousel();
    }

    // Auto-avance après 30 secondes
    _autoAdvanceTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) {
        _cleanup();
        widget.onComplete();
      }
    });
  }
  void _startVisibilityTimer() {
    _visibilityTimer?.cancel();
    _visibilityTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted && !_hasRecordedView) {
        _recordAdView();
      }
    });
  }

  Future<void> _recordAdView() async {
    if (_hasRecordedView) return;
    _hasRecordedView = true;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || ad.id == null) return;

    try {
      final adRef = FirebaseFirestore.instance.collection('Advertisements').doc(ad.id);
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Mise à jour des vues totales et journalières
      await adRef.update({
        'views': FieldValue.increment(1),
        'dailyStats.$today': FieldValue.increment(1),
        'updatedAt': DateTime.now().microsecondsSinceEpoch,
      });

      // Vérifier si c’est une vue unique
      final doc = await adRef.get();
      if (doc.exists) {
        final viewersIds = List<String>.from(doc.data()?['viewersIds'] ?? []);
        if (!viewersIds.contains(currentUserId)) {
          await adRef.update({
            'uniqueViews': FieldValue.increment(1),
            'viewersIds': FieldValue.arrayUnion([currentUserId]),
          });
        }
      }
    } catch (e) {
      print('Erreur enregistrement vue pub: $e');
    }
  }

  Future<void> _recordAdClick() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || ad.id == null) return;

    try {
      final adRef = FirebaseFirestore.instance.collection('Advertisements').doc(ad.id);
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      await adRef.update({
        'clicks': FieldValue.increment(1),
        'dailyStats.$today.clicks': FieldValue.increment(1),
        'updatedAt': DateTime.now().microsecondsSinceEpoch,
      });

      final doc = await adRef.get();
      if (doc.exists) {
        final clickersIds = List<String>.from(doc.data()?['clickersIds'] ?? []);
        if (!clickersIds.contains(currentUserId)) {
          await adRef.update({
            'uniqueClicks': FieldValue.increment(1),
            'clickersIds': FieldValue.arrayUnion([currentUserId]),
          });
        }
      }
    } catch (e) {
      print('Erreur enregistrement clic pub: $e');
    }
  }

  void _initVideo() async {
    if (post.url_media == null || post.url_media!.isEmpty) {
      _autoAdvanceTimer?.cancel();
      _cleanup();
      widget.onComplete();
      return;
    }
    try {
      _videoController = VideoPlayerController.network(post.url_media!);
      await _videoController!.initialize();
      // Suppression de l'aspectRatio forcé : la vidéo prend tout l'espace disponible
      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        looping: false,
        showControls: true,
        allowFullScreen: true,
        allowMuting: true,
        // Pas de aspectRatio => la vidéo s'adapte à la taille du conteneur
        placeholder: Container(color: Colors.black),
      );
      _videoController!.addListener(() {
        if (_videoController!.value.isCompleted) {
          _autoAdvanceTimer?.cancel();
          _cleanup();
          widget.onComplete();
        }
      });
      setState(() {
        _isVideoInitialized = true;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur vidéo pub: $e');
      _autoAdvanceTimer?.cancel();
      _cleanup();
      widget.onComplete();
    }
  }

  void _initImageCarousel() {
    final images = post.images ?? [];
    if (images.isEmpty) {
      _autoAdvanceTimer?.cancel();
      _cleanup();
      widget.onComplete();
      return;
    }
    if (images.length > 1) {
      _imagePageController = PageController();
    }
    setState(() => _isLoading = false);
  }

  void _cleanup() {
    _autoAdvanceTimer?.cancel();
    _chewieController?.dispose();
    _videoController?.dispose();
    _imagePageController?.dispose();
    _visibilityTimer?.cancel();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }

  Widget _buildImageCarousel() {
    final images = post.images ?? [];
    if (images.isEmpty) return const SizedBox.shrink();

    if (images.length == 1) {
      return GestureDetector(
        onTap: _handleActionClick,
        child: Container(
          color: Colors.black,
          child: Center(
            child: CachedNetworkImage(
              imageUrl: images.first,
              fit: BoxFit.contain, // Remplit tout l'écran
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _imagePageController,
          itemCount: images.length,
          onPageChanged: (index) => setState(() => _currentImageIndex = index),
          itemBuilder: (context, index) => GestureDetector(
            onTap: _handleActionClick,
            child: Container(
              color: Colors.black,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: images[index],
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 80,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(images.length, (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 6, height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentImageIndex == index ? Colors.yellow : Colors.white54,
              ),
            )),
          ),
        ),
      ],
    );
  }

  // Widget pour la description avec "Voir plus" et liens cliquables
  Widget _buildDescription() {
    if (post.description == null || post.description!.isEmpty) {
      return const SizedBox.shrink();
    }
    final String text = post.description!;
    final bool isLong = text.length > 100; // seuil arbitraire
    final String displayedText = _isDescriptionExpanded ? text : (isLong ? text.substring(0, 100) + '...' : text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Linkify(
          onOpen: (link) async {
            if (await canLaunchUrl(Uri.parse(link.url))) {
              await launchUrl(Uri.parse(link.url), mode: LaunchMode.externalApplication);
            } else {
              throw Exception('Could not launch ${link.url}');
            }
          },
          text: displayedText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.4,
          ),
          linkStyle: const TextStyle(
            color: _twitterBlue,
            fontWeight: FontWeight.w500,
          ),
          options: const LinkifyOptions(humanize: false),
        ),
        if (isLong)
          GestureDetector(
            onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _isDescriptionExpanded ? 'Voir moins' : 'Voir plus',
                style: const TextStyle(color: _twitterBlue, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionButton() {
    return InkWell(
      onTap: _handleActionClick,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFE21221), Color(0xFFFF5252)]),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(ad.getActionIcon(), color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              ad.getActionButtonText().toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }

  void _handleActionClick() async {
    await _recordAdClick();   // <-- AJOUT
    if (ad.actionUrl != null && ad.actionUrl!.isNotEmpty) {
      final url = Uri.parse(ad.actionUrl!);
      if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
    }
    _autoAdvanceTimer?.cancel();
    _cleanup();
    widget.onComplete();
  }
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator(color: Colors.yellow)),
      );
    }

    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.black,
      child: Stack(
        children: [
          // Contenu vidéo/image en plein écran
          if (isVideo && _isVideoInitialized)
            Chewie(controller: _chewieController!)
          else if (!isVideo)
            _buildImageCarousel(),

          // Dégradé en bas uniquement si la description n'est pas étendue
          if (!_isDescriptionExpanded)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.7), Colors.black.withOpacity(0.9)],
                  ),
                ),
              ),
            ),

          // Zone de texte : description + bouton d'action
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Container(
              // Fond semi-transparent uniquement quand la description est étendue
              decoration: _isDescriptionExpanded
                  ? BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(12),
              )
                  : null,
              padding: _isDescriptionExpanded ? const EdgeInsets.all(12) : EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDescription(),
                  const SizedBox(height: 12),
                  _buildActionButton(),
                  MrecAdWidget(
                    onAdLoaded: () {

                  },)
                ],
              ),
            ),
          ),

          // Badge SPONSORISÉ
          Positioned(
            top: 50,
            right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.yellow, borderRadius: BorderRadius.circular(12)),
              child: const Text(
                'SPONSORISÉ',
                style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Barre de progression (en haut)
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              value: 1.0,
              backgroundColor: Colors.white30,
              color: Colors.yellow,
            ),
          ),
        ],
      ),
    );
  }
}