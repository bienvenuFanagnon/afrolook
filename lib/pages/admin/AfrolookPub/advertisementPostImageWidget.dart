// widgets/advertisement_post_widget.dart
import 'dart:async';
import 'dart:math';
import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../providers/authProvider.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/gifts/quick_gift_bar.dart' show CadeauBadge;
import '../../postComments.dart';
import '../../userPosts/postWidgets/postWidgetPage.dart';

class AdvertisementPostImageWidget extends StatefulWidget {
  final Post post;
  final Advertisement ad;
  final double? height;
  final double width;
  final bool isPreview;
  final Function(Post, Advertisement)? onAdClicked;
  final Function(Post, Advertisement)? onAdViewed;

  const AdvertisementPostImageWidget({
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
  State<AdvertisementPostImageWidget> createState() => _AdvertisementPostImageWidgetState();
}

class _AdvertisementPostImageWidgetState extends State<AdvertisementPostImageWidget> {
  late UserAuthProvider authProvider;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Timer? _visibilityTimer;
  bool _hasRecordedView = false;

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
    super.dispose();
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    _visibilityTimer?.cancel();
    if (info.visibleFraction > 0.5) {
      _visibilityTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted && info.visibleFraction > 0.5) {
          _recordAdView();
        }
      });
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
          updates['dailyStats'] = {today: {'views': viewIncr}};
        } else {
          updates['dailyStats.$today.views'] = FieldValue.increment(viewIncr);
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
        color: _colors.accent.withOpacity(0.93),
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

  Widget _buildActionRow() {
    final myId = authProvider.loginUserData.id;
    final postOwnerId = widget.post.user_id ?? '';
    final giftCount = widget.post.totalGiftCoinsSentOnThisPost ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // Commentaire
          _buildActionButton(
            icon: FontAwesome.comment_o,
            count: widget.post.comments ?? 0,
            color: _colors.textSecondary,
            onPressed: _openComments,
          ),
          const SizedBox(width: 4),
          // Like
          _buildActionButton(
            icon: _isLiked ? FontAwesome.heart : FontAwesome.heart_o,
            count: _likesCount,
            color: _isLiked ? _primaryColor : _colors.textSecondary,
            onPressed: _isLiking ? null : _handleLike,
          ),
          const SizedBox(width: 4),
          // Cadeau
          if (myId != null && myId != postOwnerId)
            CadeauBadge(
              receiverId: postOwnerId,
              receiverName: widget.post.user?.pseudo ?? 'Créateur',
              receiverAvatar: widget.post.user?.imageUrl ?? '',
              post: widget.post,
              giftCount: giftCount,
            )
          else
            CadeauBadge(
              receiverId: postOwnerId,
              receiverName: widget.post.user?.pseudo ?? 'Créateur',
              receiverAvatar: widget.post.user?.imageUrl ?? '',
              post: widget.post,
              giftCount: giftCount,
            ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required int count,
    required Color color,
    VoidCallback? onPressed,
  }) {
    final effectiveColor = onPressed != null ? color : _colors.textSecondary.withOpacity(0.3);
    return GestureDetector(
      onTap: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: effectiveColor),
          const SizedBox(width: 4),
          Text(
            count >= 1000 ? '${(count / 1000).toStringAsFixed(1)}k' : '$count',
            style: TextStyle(color: effectiveColor, fontSize: 12, fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }

  Widget _buildAdExtras() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          // Stats pub : vues + clics
          Icon(Icons.remove_red_eye_outlined, color: _colors.textSecondary, size: 13),
          const SizedBox(width: 4),
          Text(
            '${_formatCount(widget.ad.views ?? 0)} vues',
            style: TextStyle(color: _colors.textSecondary, fontSize: 11),
          ),
          if ((widget.ad.clicks ?? 0) > 0) ...[
            const SizedBox(width: 10),
            Icon(Icons.touch_app_outlined, color: _colors.textSecondary, size: 13),
            const SizedBox(width: 3),
            Text(
              '${_formatCount(widget.ad.clicks ?? 0)} clics',
              style: TextStyle(color: _colors.textSecondary, fontSize: 11),
            ),
          ],
          if ((widget.ad.views ?? 0) > 0 && (widget.ad.clicks ?? 0) > 0) ...[
            const SizedBox(width: 10),
            Text(
              'CTR ${widget.ad.ctr.toStringAsFixed(1)}%',
              style: const TextStyle(color: _primaryColor, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ],
          const Spacer(),
          // Bouton action compact
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
                    widget.ad.getActionButtonText().toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward, color: Colors.white, size: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _colors = AppColors.of(context);
    final double postHeight = widget.height ?? widget.width * 0.75;

    return VisibilityDetector(
      key: Key('ad-post-${widget.post.id}'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              HomePostUsersWidget(
                post: widget.post,
                height: postHeight,
                width: widget.width,
                isPreview: widget.isPreview,
                isAdContext: true,
              ),
              Positioned(
                top: 8,
                right: 8,
                child: _buildSponsoredBadge(),
              ),
            ],
          ),
          _buildActionRow(),
          _buildAdExtras(),
        ],
      ),
    );
  }
}
