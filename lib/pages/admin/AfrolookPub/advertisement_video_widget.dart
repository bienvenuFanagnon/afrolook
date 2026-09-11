import 'dart:async';
import 'dart:math';

import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../../../providers/authProvider.dart';
import '../../../services/ad_preload_service.dart';
import '../../../theme/app_colors.dart';
import '../../postComments.dart';
import '../../userPosts/video_preload_manager.dart';
import '../../post_video_format_tel_details.dart';

class AdvertisementVideoWidget extends StatefulWidget {
  final Post post;
  final Advertisement ad;
  final double? height;
  final double width;
  final bool isPreview;
  final Function(Post, Advertisement)? onAdClicked;
  final Function(Post, Advertisement)? onAdViewed;

  const AdvertisementVideoWidget({
    Key? key,
    required this.post,
    required this.ad,
    this.height,
    required this.width,
    this.isPreview = true,
    this.onAdClicked,
    this.onAdViewed,
  }) : super(key: key);

  @override
  State<AdvertisementVideoWidget> createState() => _AdvertisementVideoWidgetState();
}

class _AdvertisementVideoWidgetState extends State<AdvertisementVideoWidget> {
  late UserAuthProvider authProvider;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Timer? _visibilityTimer;
  bool _hasRecordedView = false;
  bool _isWidgetVisible = false;

  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isVideoLoading = false;
  bool _adVideoMuted = true;

  bool _isLiked = false;
  int _likesCount = 0;
  bool _isLiking = false;

  late AppColors _colors;
  static const Color _primaryColor = Color(0xFFE21221);

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final uid = authProvider.loginUserData.id;
    _isLiked = widget.post.users_love_id?.contains(uid) ?? false;
    _likesCount = widget.post.loves ?? 0;
    _initAdVideo();
  }

  Future<void> _initAdVideo() async {
    final url = widget.post.url_media;
    if (url == null || url.isEmpty) return;
    if (_isVideoInitialized || _isVideoLoading) return;

    if (mounted) setState(() => _isVideoLoading = true);

    try {
      // 1. Contrôleur pré-initialisé par AdPreloadService (le plus rapide)
      final adKey = widget.ad.id ?? '';
      VideoPlayerController? ctrl = adKey.isNotEmpty ? AdPreloadService.instance.claimController(adKey) : null;

      // 2. Cache VideoPreloadManager (post déjà vu dans le feed)
      ctrl ??= VideoPreloadManager.claimController(widget.post.id ?? '');

      // 3. Initialisation fraîche
      if (ctrl == null) {
        final optimizedUrl = authProvider.convertToCdnUrl(url, authProvider.appDefaultData);
        ctrl = VideoPlayerController.networkUrl(Uri.parse(optimizedUrl));
        await ctrl.initialize();
      }

      _videoController = ctrl;
      _videoController!.setLooping(true);
      await _videoController!.setVolume(0);

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
          _isVideoLoading = false;
        });
        if (_isWidgetVisible) _videoController!.play();
      }
    } catch (e) {
      if (mounted) setState(() => _isVideoLoading = false);
    }
  }

  Future<void> _handleLike() async {
    if (_isLiking) return;
    final uid = authProvider.loginUserData.id;
    if (uid == null || widget.post.id == null) return;

    setState(() {
      _isLiking = true;
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });

    try {
      final postRef = _firestore.collection('Posts').doc(widget.post.id);
      if (_isLiked) {
        await postRef.update({
          'loves': FieldValue.increment(1),
          'users_love_id': FieldValue.arrayUnion([uid]),
        });
      } else {
        await postRef.update({
          'loves': FieldValue.increment(-1),
          'users_love_id': FieldValue.arrayRemove([uid]),
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likesCount += _isLiked ? 1 : -1;
        });
      }
    } finally {
      if (mounted) setState(() => _isLiking = false);
    }
  }

  void _openComments() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostComments(post: widget.post)),
    );
  }

  @override
  void dispose() {
    _visibilityTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    final isNowVisible = info.visibleFraction > 0.5;
    _isWidgetVisible = isNowVisible;

    if (isNowVisible) {
      if (_isVideoInitialized && _videoController != null && !_videoController!.value.isPlaying) {
        _videoController!.play();
      }
      _visibilityTimer?.cancel();
      _visibilityTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted && _isWidgetVisible) _recordAdView();
      });
    } else {
      _videoController?.pause();
      _visibilityTimer?.cancel();
    }
  }

  Future<void> _recordAdView() async {
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null || widget.ad.id == null) return;
    if (_hasRecordedView) return;

    try {
      _hasRecordedView = true;
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final adRef = _firestore.collection('Advertisements').doc(widget.ad.id);

      await _firestore.runTransaction((transaction) async {
        final adDoc = await transaction.get(adRef);
        if (!adDoc.exists) return;

        final currentAd = Advertisement.fromJson(adDoc.data()!);
        final hasSeen = currentAd.viewersIds?.contains(currentUserId) ?? false;
        final viewIncr = Random().nextInt(3) + 1;

        final updates = <String, dynamic>{
          'views': FieldValue.increment(viewIncr),
          'updatedAt': DateTime.now().microsecondsSinceEpoch,
        };
        if (!hasSeen) {
          updates['uniqueViews'] = FieldValue.increment(1);
          updates['viewersIds'] = FieldValue.arrayUnion([currentUserId]);
        }
        if (currentAd.dailyStats == null) {
          updates['dailyStats'] = {today: viewIncr};
        } else {
          updates['dailyStats.$today'] = FieldValue.increment(viewIncr);
        }
        transaction.update(adRef, updates);
      });

      if (mounted) setState(() => widget.ad.views = (widget.ad.views ?? 0) + 1);
      widget.onAdViewed?.call(widget.post, widget.ad);
    } catch (e) {
      _hasRecordedView = false;
    }
  }

  Future<void> _handleActionButtonClick() async {
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null || widget.ad.id == null) return;

    try {
      final adRef = _firestore.collection('Advertisements').doc(widget.ad.id);
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      await _firestore.runTransaction((transaction) async {
        final adDoc = await transaction.get(adRef);
        if (!adDoc.exists) return;

        final currentAd = Advertisement.fromJson(adDoc.data()!);
        final hasClicked = currentAd.clickersIds?.contains(currentUserId) ?? false;
        final clickIncr = Random().nextInt(3) + 1;

        final updates = <String, dynamic>{
          'clicks': FieldValue.increment(clickIncr),
          'updatedAt': DateTime.now().microsecondsSinceEpoch,
        };
        if (!hasClicked) {
          updates['uniqueClicks'] = FieldValue.increment(1);
          updates['clickersIds'] = FieldValue.arrayUnion([currentUserId]);
        }
        if (currentAd.dailyStats == null) {
          updates['dailyStats'] = {today: {'clicks': clickIncr}};
        } else {
          updates['dailyStats.$today.clicks'] = FieldValue.increment(clickIncr);
        }
        transaction.update(adRef, updates);
      });

      if (mounted) setState(() => widget.ad.clicks = (widget.ad.clicks ?? 0) + 1);
      widget.onAdClicked?.call(widget.post, widget.ad);

      if (widget.ad.actionUrl != null && widget.ad.actionUrl!.isNotEmpty) {
        final url = Uri.parse(widget.ad.actionUrl!);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      // silently ignore
    }
  }

  Widget _buildCreatorHeader() {
    final user = widget.post.user;
    final pseudo = user?.pseudo ?? widget.ad.ownerName ?? '';
    final imageUrl = user?.imageUrl ?? '';
    final isDark = _colors.isDark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _colors.shimmerBase,
              border: Border.all(color: _primaryColor.withOpacity(0.6), width: 1.5),
            ),
            child: ClipOval(
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Icon(Icons.person, color: _colors.textSecondary, size: 18))
                  : Icon(Icons.person, color: _colors.textSecondary, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pseudo.isNotEmpty)
                  Text(pseudo,
                      style: TextStyle(color: _colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('Publicité', style: TextStyle(color: _colors.textSecondary, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSponsoredBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.93),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, color: Colors.black, size: 11),
          const SizedBox(width: 3),
          const Text(
            'SPONSORISÉ',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 9),
          ),
          if ((widget.ad.renewalCount ?? 0) > 0) ...[
            const SizedBox(width: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'x${widget.ad.renewalCount}',
                style: const TextStyle(color: Colors.black, fontSize: 7, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdExtras() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Like
          GestureDetector(
            onTap: _handleLike,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  color: _isLiked ? Colors.red : _colors.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 3),
                Text(
                  _formatCount(_likesCount),
                  style: TextStyle(color: _colors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Commentaire
          GestureDetector(
            onTap: _openComments,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline, color: _colors.textSecondary, size: 18),
                const SizedBox(width: 3),
                Text(
                  _formatCount(widget.post.comments ?? 0),
                  style: TextStyle(color: _colors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Vues
          Icon(Icons.remove_red_eye, color: _colors.textSecondary, size: 12),
          const SizedBox(width: 2),
          Text(
            _formatCount(widget.ad.views ?? 0),
            style: TextStyle(color: _colors.textSecondary, fontSize: 11),
          ),
          const Spacer(),
          // Bouton d'action — compact, aligné à droite
          GestureDetector(
            onTap: _handleActionButtonClick,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_primaryColor, Color(0xFFFF5252)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.ad.getActionIcon(), color: Colors.white, size: 13),
                  const SizedBox(width: 5),
                  Text(
                    widget.ad.getActionButtonText(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailsVideoFormatTel(
          initialPost: widget.post,
          isIn: false,
        ),
      ),
    );
  }

  Widget _buildVideoSection(double screenWidth) {
    // Utiliser post.isPortrait en priorité pour éviter le saut de layout au chargement
    final isPortraitVideo = widget.post.isPortrait ??
        (_isVideoInitialized && _videoController != null &&
            _videoController!.value.size.height > _videoController!.value.size.width);

    // Portrait : colonne plus étroite (~72% de l'écran), ratio naturel, pas de barres noires
    // Paysage : pleine largeur, ratio 16:9
    final double videoWidth = isPortraitVideo ? screenWidth * 0.72 : screenWidth;
    double videoHeight;
    if (_isVideoInitialized && _videoController != null) {
      final size = _videoController!.value.size;
      if (isPortraitVideo) {
        videoHeight = videoWidth * (size.height / size.width) * 0.75; // -1/4
        final maxH = MediaQuery.of(context).size.height * 0.52;
        if (videoHeight > maxH) videoHeight = maxH;
      } else {
        videoHeight = widget.height ?? videoWidth * (size.height / size.width.clamp(1, double.infinity));
      }
    } else {
      // Avant init vidéo : déjà calculer la bonne hauteur selon isPortrait
      if (isPortraitVideo) {
        videoHeight = (videoWidth * 16.0 / 9.0 * 0.75).clamp(0.0, MediaQuery.of(context).size.height * 0.52);
      } else {
        videoHeight = widget.height ?? screenWidth * 9 / 16;
      }
    }

    // Tout dans un seul bloc borné par videoWidth x videoHeight
    final videoWidget = ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
      ),
      child: SizedBox(
        width: videoWidth,
        height: videoHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: Colors.black,
              child: _isVideoInitialized && _videoController != null
                  ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _videoController!.value.size.width,
                        height: _videoController!.value.size.height,
                        child: VideoPlayer(_videoController!),
                      ),
                    )
                  : _buildVideoPlaceholderFixed(videoHeight),
            ),
            if (_isVideoLoading)
              Container(
                color: Colors.black.withOpacity(0.4),
                child: Center(child: CircularProgressIndicator(color: _primaryColor)),
              ),
            Positioned(top: 8, right: 8, child: _buildSponsoredBadge()),
            Positioned(
              bottom: 8,
              right: 8,
              child: GestureDetector(
                onTap: () {
                  setState(() => _adVideoMuted = !_adVideoMuted);
                  _videoController?.setVolume(_adVideoMuted ? 0 : 1);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    _adVideoMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return GestureDetector(
      onTap: _navigateToDetails,
      child: isPortraitVideo
          ? Align(alignment: Alignment.centerLeft, child: videoWidget)
          : videoWidget,
    );
  }

  Widget _buildVideoPlaceholder() {
    final thumb = widget.post.thumbnail;
    if (thumb != null && thumb.isNotEmpty) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          thumb,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (_, __, ___) => _buildFallback(),
        ),
      );
    }
    return _buildFallback();
  }

  Widget _buildVideoPlaceholderFixed(double height) {
    final thumb = widget.post.thumbnail;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: thumb != null && thumb.isNotEmpty
          ? Image.network(thumb, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.black,
                child: const Center(child: Icon(Icons.videocam, color: Colors.grey, size: 40))))
          : Container(color: Colors.black,
              child: const Center(child: Icon(Icons.videocam, color: Colors.grey, size: 40))),
    );
  }

  Widget _buildFallback() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        width: double.infinity,
        color: Colors.black,
        child: const Icon(Icons.videocam, color: Colors.grey, size: 50),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isPortrait = widget.post.isPortrait ?? false;
    // Pour portrait : card + marge = 72% écran + 2*12 de marge
    final double cardOuterWidth = isPortrait ? screenWidth * 0.72 + 24 : double.infinity;

    final card = Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: _colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _colors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCreatorHeader(),
          _buildVideoSection(screenWidth),
          _buildAdExtras(),
        ],
      ),
    );

    return VisibilityDetector(
      key: Key('ad-video-${widget.post.id}'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: isPortrait
          ? Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(width: cardOuterWidth, child: card),
            )
          : card,
    );
  }
}
