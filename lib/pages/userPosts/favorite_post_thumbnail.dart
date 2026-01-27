import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../postDetails.dart';
import '../postDetailsVideoListe.dart';

// Couleurs du thème
const _afroDarkBg = Color(0xFF000000);
const _afroCardBg = Color(0xFF1A1A1A);
const _afroTextPrimary = Color(0xFFFFFFFF);
const _afroTextSecondary = Color(0xFF71767B);
const _afroGreen = Color(0xFF2E7D32);
const _afroYellow = Color(0xFFFFD600);
const _afroRed = Color(0xFFF91880);
const _afroBlue = Color(0xFF1D9BF0);

class FavoritePostThumbnailWidget extends StatefulWidget {
  final Post post;
  final double size;
  final bool showStats;
  final bool showUserInfo;

  FavoritePostThumbnailWidget({
    Key? key,
    required this.post,
    this.size = 120,
    this.showStats = true,
    this.showUserInfo = true,
  }) : super(key: key);

  @override
  _FavoritePostThumbnailWidgetState createState() => _FavoritePostThumbnailWidgetState();
}

class _FavoritePostThumbnailWidgetState extends State<FavoritePostThumbnailWidget> {
  late UserAuthProvider _authProvider;
  String? _videoThumbnailPath;
  bool _isGeneratingThumbnail = false;
  bool _isLoadingUser = false;
  UserData? _currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _authProvider = Provider.of<UserAuthProvider>(context, listen: false);

    if (_isVideoPost(widget.post)) {
      _generateVideoThumbnail();
    }

    if (widget.showUserInfo && widget.post.user_id != null) {
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoadingUser = true;
    });

    try {
      final userDoc = await _firestore.collection('Users').doc(widget.post.user_id!).get();
      if (userDoc.exists) {
        setState(() {
          _currentUser = UserData.fromJson(userDoc.data() as Map<String, dynamic>);
          widget.post.user = _currentUser;
        });
      }
    } catch (e) {
      print('Erreur chargement utilisateur: $e');
    } finally {
      setState(() {
        _isLoadingUser = false;
      });
    }
  }

  Future<void> _generateVideoThumbnail() async {
    if (widget.post.url_media == null) return;

    setState(() {
      _isGeneratingThumbnail = true;
    });

    try {
      final thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: widget.post.url_media!,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 200,
        quality: 50,
        timeMs: 1000,
      );

      if (thumbnailPath != null && File(thumbnailPath).existsSync()) {
        setState(() {
          _videoThumbnailPath = thumbnailPath;
          _isGeneratingThumbnail = false;
        });
      }
    } catch (e) {
      print('Erreur génération thumbnail: $e');
      setState(() {
        _isGeneratingThumbnail = false;
      });
    }
  }

  bool _isVideoPost(Post post) {
    return post.dataType == PostDataType.VIDEO.name ||
        (post.url_media ?? '').contains('.mp4') ||
        (post.url_media ?? '').contains('.mov');
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  void _navigateToPostDetails() {
    if (_isVideoPost(widget.post)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => VideoTikTokPageDetails(initialPost: widget.post),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetailsPost(post: widget.post),
        ),
      );
    }
  }

  Widget _buildThumbnail() {
    final size = widget.size;

    // Priorité: images > vidéo > fallback
    if (widget.post.images?.isNotEmpty ?? false) {
      return _buildImageThumbnail(widget.post.images!.first, size);
    } else if (_isVideoPost(widget.post)) {
      return _buildVideoThumbnail(size);
    } else {
      return _buildFallbackThumbnail(size);
    }
  }

  Widget _buildImageThumbnail(String imageUrl, double size) {
    return GestureDetector(
      onTap: _navigateToPostDetails,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: _afroCardBg,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            width: size,
            height: size,
            placeholder: (context, url) => Container(
              color: _afroTextSecondary.withOpacity(0.1),
              child: Center(
                child: Icon(Icons.photo, color: _afroTextSecondary.withOpacity(0.5)),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: _afroTextSecondary.withOpacity(0.1),
              child: Center(
                child: Icon(Icons.broken_image, color: _afroTextSecondary.withOpacity(0.5)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoThumbnail(double size) {
    return GestureDetector(
      onTap: _navigateToPostDetails,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: _afroCardBg,
        ),
        child: Stack(
          children: [
            // Thumbnail vidéo
            if (_videoThumbnailPath != null && File(_videoThumbnailPath!).existsSync())
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_videoThumbnailPath!),
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                ),
              )
            else if (_isGeneratingThumbnail)
              Center(child: CircularProgressIndicator(color: _afroBlue, strokeWidth: 2))
            else
              _buildFallbackThumbnail(size),

            // Overlay play
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black.withOpacity(0.3),
                ),
                child: Center(
                  child: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),

            // Badge vidéo
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.videocam,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackThumbnail(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _afroTextSecondary.withOpacity(0.2),
            _afroTextSecondary.withOpacity(0.1),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.insert_photo,
          color: _afroTextSecondary.withOpacity(0.5),
          size: 30,
        ),
      ),
    );
  }

  Widget _buildStatsOverlay() {
    if (!widget.showStats) return SizedBox.shrink();

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          ),
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Likes
            _buildStatItem(
              icon: Icons.favorite,
              count: widget.post.loves ?? 0,
              color: _afroRed,
            ),

            // Comments
            _buildStatItem(
              icon: Icons.comment,
              count: widget.post.comments ?? 0,
              color: _afroBlue,
            ),

            // Shares
            _buildStatItem(
              icon: Icons.share,
              count: widget.post.partage ?? 0,
              color: _afroGreen,
            ),

            // Views
            _buildStatItem(
              icon: Icons.remove_red_eye,
              count: widget.post.vues ?? 0,
              color: _afroYellow,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({required IconData icon, required int count, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        SizedBox(width: 2),
        Text(
          _formatCount(count),
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildUserInfo() {
    if (!widget.showUserInfo || _isLoadingUser) return SizedBox.shrink();

    final user = _currentUser ?? widget.post.user;
    if (user == null) return SizedBox.shrink();

    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 10,
              backgroundImage: user.imageUrl != null
                  ? NetworkImage(user.imageUrl!)
                  : AssetImage('assets/default_profile.png') as ImageProvider,
            ),
            SizedBox(width: 6),
            Text(
              '@${user.pseudo ?? 'user'}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiImageIndicator() {
    final imageCount = widget.post.images?.length ?? 0;
    if (imageCount <= 1) return SizedBox.shrink();

    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library, color: Colors.white, size: 12),
            SizedBox(width: 4),
            Text(
              '$imageCount',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(4),
      child: Stack(
        children: [
          // Thumbnail principale
          _buildThumbnail(),

          // Informations utilisateur
          _buildUserInfo(),

          // Indicateur multi-images
          _buildMultiImageIndicator(),

          // Statistiques
          _buildStatsOverlay(),

          // Badge favori
          Positioned(
            top: 8,
            right: widget.post!.images!.length> 1 ? 32 : 8,
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _afroYellow,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bookmark,
                color: Colors.black,
                size: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}