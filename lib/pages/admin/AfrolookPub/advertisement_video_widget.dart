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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Interactions : like + commentaire
          Row(
            children: [
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
              const SizedBox(width: 16),
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
              const Spacer(),
              Icon(Icons.remove_red_eye, color: _colors.textSecondary, size: 13),
              const SizedBox(width: 3),
              Text(
                '${_formatCount(widget.ad.views ?? 0)} vues',
                style: TextStyle(color: _colors.textSecondary, fontSize: 11),
              ),
              if ((widget.ad.views ?? 0) > 0) ...[
                const SizedBox(width: 8),
                const Icon(Icons.ads_click, color: _primaryColor, size: 13),
                const SizedBox(width: 3),
                Text(
                  '${widget.ad.ctr.toStringAsFixed(1)}%',
                  style: const TextStyle(color: _primaryColor, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _handleActionButtonClick,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_primaryColor, Color(0xFFFF5252)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.ad.getActionIcon(), color: Colors.white, size: 15),
                  const SizedBox(width: 6),
                  Text(
                    widget.ad.getActionButtonText().toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward, color: Colors.white, size: 13),
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
    final videoHeight = widget.height ?? screenWidth * 9 / 16;
    return GestureDetector(
      onTap: _navigateToDetails,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            child: SizedBox(
              width: double.infinity,
              height: videoHeight,
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
          ),
          if (_isVideoLoading)
            Positioned(
              left: 0, right: 0, top: 0, bottom: 0,
              child: Container(
                color: Colors.black.withOpacity(0.4),
                child: Center(child: CircularProgressIndicator(color: _primaryColor)),
              ),
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

    return VisibilityDetector(
      key: Key('ad-video-${widget.post.id}'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: Container(
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
            _buildVideoSection(screenWidth),
            _buildAdExtras(),
          ],
        ),
      ),
    );
  }
}
