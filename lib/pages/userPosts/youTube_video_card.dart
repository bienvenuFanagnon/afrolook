import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/postProvider.dart';
import '../../providers/userProvider.dart';
import '../canaux/detailsCanal.dart';
import '../component/consoleWidget.dart';
import '../pub/native_ad_widget.dart';

class YouTubeVideoCard extends StatefulWidget {
  final Post post;
  late int index;
  final VoidCallback onTap;

   YouTubeVideoCard({Key? key, required this.post, required this.onTap,this.index=0}) : super(key: key);

  @override
  State<YouTubeVideoCard> createState() => _YouTubeVideoCardState();
}

class _YouTubeVideoCardState extends State<YouTubeVideoCard> {
  String? _thumbnailPath;
  bool _isGeneratingThumbnail = false;
  late UserAuthProvider _authProvider;
  late PostProvider _postProvider;
  late UserProvider _userProvider;
  UserData? _creatorUser;
  Canal? _creatorCanal;
  bool _isLoadingUser = false;
  bool _isProcessingFollow = false;
  String? _thumbnailUrl;

  bool get _shouldShowAd {
    // Affiche la pub pour les indices 2, 5, 8, 11... (1-indexé)
    // Exemple : index 0 -> 1er post -> pas de pub
    //          index 2 -> 3ème post -> pub
    return (widget.index + 1) % 2 == 0;
  }
  Widget _buildEventBadge(Post post) {


    if (post.typeTabbar != 'EVENEMENT' || post.eventDate == null) return SizedBox.shrink();
    printVm("eventDate : ${post.eventDate!}");
    final eventDateTime = DateTime.fromMillisecondsSinceEpoch(post.eventDate!);
    final now = DateTime.now();
    final difference = eventDateTime.difference(now).inDays;

    String badgeText = '';
    Color badgeColor = Color(0xFFE21221);

    if (difference < 0) {
      badgeText = '📅 PASSÉ';
      badgeColor = Colors.grey;
    } else if (difference == 0) {
      badgeText = '🔴 AUJOURD\'HUI';
      badgeColor = Colors.red;
    } else if (difference == 1) {
      badgeText = '⭐ DEMAIN';
      badgeColor = Colors.orange;
    } else if (difference <= 7) {
      badgeText = '📅 DANS $difference JOURS';
      badgeColor = Color(0xFFE21221);
    } else {
      badgeText = '📅 À VENIR';
      badgeColor = Colors.blue;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4),
        ],
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _postProvider = Provider.of<PostProvider>(context, listen: false);
    _userProvider = Provider.of<UserProvider>(context, listen: false);
    _loadCreatorData();
    if (widget.post.thumbnail == null || widget.post.thumbnail!.isEmpty) {
      _generateAndUploadThumbnail();
    } else {
      _thumbnailUrl = widget.post.thumbnail;
    }
  }
  Future<void> _generateAndUploadThumbnail() async {
    if (_isGeneratingThumbnail) return;
    setState(() {
      _isGeneratingThumbnail = true;
    });
    try {
      final videoUrl = widget.post.url_media;
      if (videoUrl == null) return;

      // Générer la miniature à partir de l'URL
      final thumbnailFile = await VideoThumbnail.thumbnailFile(
        video: videoUrl,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 75,
        timeMs: 1000,
      );
      if (thumbnailFile == null) return;

      // Upload vers Firebase Storage
      final fileName = 'thumbnails/thumb_${widget.post.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      final uploadTask = ref.putFile(File(thumbnailFile));
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Mettre à jour le post dans Firestore
      await FirebaseFirestore.instance.collection('Posts').doc(widget.post.id).update({
        'thumbnail': downloadUrl,
      });

      // Mettre à jour l'état local
      if (mounted) {
        setState(() {
          _thumbnailUrl = downloadUrl;
          widget.post.thumbnail = downloadUrl;
          _isGeneratingThumbnail = false;
        });
      }
    } catch (e) {
      print('Erreur génération miniature pour post ${widget.post.id}: $e');
      if (mounted) {
        setState(() {
          _isGeneratingThumbnail = false;
        });
      }
    }
  }
  Future<void> _loadCreatorData() async {
    if (widget.post.canal_id != null && widget.post.canal_id!.isNotEmpty) {
      setState(() => _isLoadingUser = true);
      try {
        final canalDoc = await FirebaseFirestore.instance
            .collection('Canaux')
            .doc(widget.post.canal_id)
            .get();
        if (canalDoc.exists) {
          _creatorCanal = Canal.fromJson(canalDoc.data() as Map<String, dynamic>);
          widget.post.canal = _creatorCanal;
        }
      } catch (e) {
        print('Erreur chargement canal: $e');
      } finally {
        setState(() => _isLoadingUser = false);
      }
    } else if (widget.post.user_id != null) {
      setState(() => _isLoadingUser = true);
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('Users')
            .doc(widget.post.user_id)
            .get();
        if (userDoc.exists) {
          _creatorUser = UserData.fromJson(userDoc.data() as Map<String, dynamic>);
          widget.post.user = _creatorUser;
        }
      } catch (e) {
        print('Erreur chargement utilisateur: $e');
      } finally {
        setState(() => _isLoadingUser = false);
      }
    }
  }

  Future<void> _generateThumbnail() async {
    if (widget.post.url_media == null) return;
    setState(() => _isGeneratingThumbnail = true);
    try {
      final thumbnailFile = await VideoThumbnail.thumbnailFile(
        video: widget.post.url_media!,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 75,
        timeMs: 1000,
      );
      if (thumbnailFile != null && File(thumbnailFile).existsSync()) {
        setState(() {
          _thumbnailPath = thumbnailFile;
          _isGeneratingThumbnail = false;
        });
      } else {
        setState(() => _isGeneratingThumbnail = false);
      }
    } catch (e) {
      print('Erreur génération miniature: $e');
      setState(() => _isGeneratingThumbnail = false);
    }
  }

  bool get _isCanalPost => _creatorCanal != null;
  bool get _isSubscribed {
    final currentUserId = _authProvider.loginUserData.id;
    if (_isCanalPost) {
      return _creatorCanal!.usersSuiviId?.contains(currentUserId) ?? false;
    } else {
      return _creatorUser?.userAbonnesIds?.contains(currentUserId) ?? false;
    }
  }

  String _getDisplayName() {
    if (_isCanalPost) return '#${_creatorCanal!.titre}';
    return '@${_creatorUser?.pseudo ?? 'inconnu'}';
  }

  String _getSubscriberCount() {
    if (_isCanalPost) {
      return '${_creatorCanal!.usersSuiviId?.length ?? 0} abonnés';
    } else {
      return '${_creatorUser?.userAbonnesIds?.length ?? 0} abonnés';
    }
  }

  ImageProvider? _getAvatar() {
    if (_isCanalPost && _creatorCanal!.urlImage != null) {
      return NetworkImage(_creatorCanal!.urlImage!);
    } else if (_creatorUser?.imageUrl != null) {
      return NetworkImage(_creatorUser!.imageUrl!);
    }
    return null;
  }

  Future<void> _follow() async {
    if (_isProcessingFollow) return;
    setState(() => _isProcessingFollow = true);
    try {
      if (_isCanalPost) {
        // Naviguer vers la page du canal pour s'abonner (car l'abonnement peut être payant)
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CanalDetails(canal: _creatorCanal!)),
        );
        // Recharger les données du canal après retour
        await _loadCreatorData();
      } else {
        await _authProvider.abonner(_creatorUser!, context);
        await _loadCreatorData();
      }
    } catch (e) {
      print('Erreur abonnement: $e');
    } finally {
      setState(() => _isProcessingFollow = false);
    }
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Miniature vidéo avec overlay play
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                  child: _isGeneratingThumbnail
                      ? Container(
                    height: h * 0.25,
                    width: double.infinity,
                    color: Colors.grey[900],
                    child: const Center(child: CircularProgressIndicator()),
                  )
                      : (_thumbnailUrl != null
                      ? Image.network(
                    _thumbnailUrl!,
                    fit: BoxFit.cover,
                    height: h * 0.25,
                    width: double.infinity,
                  )
                      : Container(
                    height: h * 0.25,
                    width: double.infinity,
                    color: Colors.grey[900],
                    child: const Icon(Icons.videocam, size: 50, color: Colors.grey),
                  )),
                ),
                // Icône play au centre
                Positioned.fill(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
                    ),
                  ),
                ),
                // Badge durée (optionnel si vous avez la durée du post)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'VIDÉO',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
              ],
            ),
            // Informations sous la miniature
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ligne : avatar, nom, abonnés, bouton suivre
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: _getAvatar(),
                        child: _getAvatar() == null
                            ? Icon(_isCanalPost ? Icons.group : Icons.person, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getDisplayName(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _getSubscriberCount(),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_authProvider.loginUserData.id != widget.post.user_id && !_isSubscribed)
                        ElevatedButton(
                          onPressed: _isProcessingFollow ? null : _follow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: _isProcessingFollow
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Text('S\'abonner', style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Titre / description
                  Text(
                    widget.post.description ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  // Statistiques : vues, commentaires, interactions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _buildStat(Icons.bar_chart, widget.post.totalInteractions ?? 0),
                          const SizedBox(width: 16),
                          _buildStat(Icons.comment, widget.post.comments ?? 0),
                          const SizedBox(width: 16),
                          _buildStat(Icons.favorite, widget.post.loves ?? 0),
                        ],
                      ),
                      _buildEventBadge(widget.post),

                    ],
                  ),
                  if (_shouldShowAd) ...[
                    const SizedBox(height: 12),
                    MrecAdWidget(  // ou AdaptiveAdWidget(useBanner: false)
                      onAdLoaded: () {
                        print('✅ Pub MREC affichée après le post ${widget.index}');
                      },
                      showLessAdsButton: false, // désactive le bouton "moins de pub" si tu veux
                    ),
                    const SizedBox(height: 8),
                  ],

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, int count) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 16),
        const SizedBox(width: 4),
        Text(
          _formatCount(count),
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }
}