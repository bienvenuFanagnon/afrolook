// widgets/advertisement_video_widget.dart
import 'dart:async';
import 'package:afrotok/models/model_data.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../providers/authProvider.dart';
import '../../canaux/detailsCanal.dart';
import '../../component/showUserDetails.dart';
import '../../postDetailsVideo.dart';

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

  bool _isLoadingUser = false;
  UserData? _currentUser;
  Canal? _currentCanal;

  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  Timer? _visibilityTimer;
  bool _hasRecordedView = false;
  bool _hasRecordedClick = false;

  final Color _primaryColor = Color(0xFFE21221);
  final Color _secondaryColor = Color(0xFFFFD600);
  final Color _cardColor = Color(0xFF1E1E1E);
  final Color _textColor = Colors.white;
  final Color _hintColor = Colors.grey[400]!;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _loadUserData();
    _loadCanalData();
    _initializeVideo();
  }

  @override
  void dispose() {
    _visibilityTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (widget.post.user_id == null) return;
    setState(() => _isLoadingUser = true);
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
      setState(() => _isLoadingUser = false);
    }
  }

  Future<void> _loadCanalData() async {
    if (widget.post.canal_id == null || widget.post.canal_id!.isEmpty) return;
    setState(() => _isLoadingUser = true);
    try {
      final canalDoc = await _firestore.collection('Canaux').doc(widget.post.canal_id!).get();
      if (canalDoc.exists) {
        final canalData = canalDoc.data() as Map<String, dynamic>;
        setState(() {
          _currentCanal = Canal.fromJson(canalData);
          widget.post.canal = _currentCanal;
        });
      }
    } catch (e) {
      print('Erreur chargement canal: $e');
    } finally {
      setState(() => _isLoadingUser = false);
    }
  }

  UserData? get currentUser => widget.post.user ?? _currentUser;
  Canal? get currentCanal => widget.post.canal ?? _currentCanal;

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  String formaterDateTime(int? timestamp) {
    if (timestamp == null) return '';
    final dateTime = DateTime.fromMicrosecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays < 1) {
      if (difference.inHours < 1) {
        if (difference.inMinutes < 1) return "à l'instant";
        else return "il y a ${difference.inMinutes} min";
      } else return "il y a ${difference.inHours} h";
    } else if (difference.inDays < 7) return "il y a ${difference.inDays} j";
    else return DateFormat('dd/MM/yy').format(dateTime);
  }

  String _getDisplayName() {
    if (currentCanal != null) return '#${currentCanal!.titre}';
    else if (currentUser != null) return '@${currentUser!.pseudo}';
    return 'Utilisateur';
  }

  ImageProvider? _getProfileImage() {
    if (currentCanal != null && currentCanal!.urlImage != null) return NetworkImage(currentCanal!.urlImage!);
    else if (currentUser != null && currentUser!.imageUrl != null) return NetworkImage(currentUser!.imageUrl!);
    return null;
  }

  void _navigateToVideoDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => VideoYoutubePageDetails(initialPost: widget.post)),
    );
  }

  void _handleVisibilityChanged(VisibilityInfo info) {
    _visibilityTimer?.cancel();
    if (info.visibleFraction > 0.5) {
      _visibilityTimer = Timer(Duration(milliseconds: 500), () {
        if (mounted && info.visibleFraction > 0.5) {
          _recordAdView();
          if (_videoController != null && _videoController!.value.isInitialized && !_videoController!.value.isPlaying) {
            _videoController!.play();
          }
        }
      });
    } else {
      _videoController?.pause();
    }
  }

  Future<void> _recordAdView() async {
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null || widget.ad.id == null) return;
    if (_hasRecordedView) return;
    _hasRecordedView = true;
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final adRef = _firestore.collection('Advertisements').doc(widget.ad.id);
      await _firestore.runTransaction((transaction) async {
        final adDoc = await transaction.get(adRef);
        if (!adDoc.exists) return;
        final currentAd = Advertisement.fromJson(adDoc.data()!);
        final hasSeen = currentAd.viewersIds?.contains(currentUserId) ?? false;
        final updates = {
          'views': FieldValue.increment(1),
          'updatedAt': DateTime.now().microsecondsSinceEpoch,
        };
        if (!hasSeen) {
          updates['uniqueClicks'] = FieldValue.increment(1);
          updates['viewersIds'] = FieldValue.arrayUnion([currentUserId]);
        }
        if (currentAd.dailyStats == null) updates['dailyStats'] = {today: 1};
        else updates['dailyStats.$today'] = FieldValue.increment(1);
        transaction.update(adRef, updates);
      });
      setState(() => widget.ad.views = (widget.ad.views ?? 0) + 1);
      widget.onAdViewed?.call(widget.post, widget.ad);
    } catch (e) {
      print('❌ Erreur vue: $e');
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
        final updates = {
          'clicks': FieldValue.increment(1),
          'updatedAt': DateTime.now().microsecondsSinceEpoch,
        };
        if (!hasClicked) {
          updates['uniqueClicks'] = FieldValue.increment(1);
          updates['clickersIds'] = FieldValue.arrayUnion([currentUserId]);
        }
        if (currentAd.dailyStats != null) updates['dailyStats.$today.clicks'] = FieldValue.increment(1);
        transaction.update(adRef, updates);
      });
      setState(() => widget.ad.clicks = (widget.ad.clicks ?? 0) + 1);
      _hasRecordedClick = true;
      widget.onAdClicked?.call(widget.post, widget.ad);
      if (widget.ad.actionUrl != null && widget.ad.actionUrl!.isNotEmpty) {
        final url = Uri.parse(widget.ad.actionUrl!);
        if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('❌ Erreur clic: $e');
    }
  }

  Future<void> _initializeVideo() async {
    if (widget.post.url_media == null || widget.post.url_media!.isEmpty) return;
    _videoController = VideoPlayerController.network(widget.post.url_media!);
    await _videoController!.initialize();
    await _videoController!.setVolume(0.1);
    setState(() => _isVideoInitialized = true);
  }

  Widget _buildHeaderCompact() {
    return GestureDetector(
      onTap: () {
        if (currentCanal != null) Navigator.push(context, MaterialPageRoute(builder: (context) => CanalDetails(canal: currentCanal!)));
        else if (currentUser != null) showUserDetailsModalDialog(currentUser!, MediaQuery.of(context).size.width, MediaQuery.of(context).size.height, context);
      },
      child: Row(
        children: [
          CircleAvatar(radius: 16, backgroundColor: _primaryColor, backgroundImage: _getProfileImage(),
              child: _getProfileImage() == null ? Icon(currentCanal != null ? Icons.group : Icons.person, color: Colors.white, size: 16) : null),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_getDisplayName(), style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                SizedBox(height: 2),
                Text(formaterDateTime(widget.post.createdAt), style: TextStyle(color: _hintColor, fontSize: 9)),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: widget.ad.isActive ? Colors.green.withOpacity(0.2) : (widget.ad.isPending ? Colors.orange.withOpacity(0.2) : Colors.grey.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: widget.ad.isActive ? Colors.green : (widget.ad.isPending ? Colors.orange : Colors.grey)),
            ),
            child: Text(widget.ad.isActive ? 'Active' : (widget.ad.isPending ? 'Attente' : 'Expirée'),
                style: TextStyle(color: widget.ad.isActive ? Colors.green : (widget.ad.isPending ? Colors.orange : Colors.grey), fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _truncateDescription(String text) {
    const maxLines = 2;
    const approxCharsPerLine = 40;
    int maxLength = maxLines * approxCharsPerLine;
    if (text.length <= maxLength) return text;
    return text.substring(0, maxLength - 3) + '...';
  }

  double _calculatePostHeight() {
    double totalHeight = 0;
    totalHeight += 28;
    totalHeight += 16;
    totalHeight += 40;
    totalHeight += 6 + 8 + 10 + 8;
    totalHeight += 40;
    totalHeight += widget.width * 0.5;
    totalHeight += 20;
    totalHeight += 36;
    return totalHeight;
  }

  @override
  Widget build(BuildContext context) {
    final double maxVideoHeight = MediaQuery.of(context).size.height * 0.35; // 35% de l'écran

    return VisibilityDetector(
      key: Key('ad-video-${widget.post.id}'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: _secondaryColor, width: 1.5)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge "Sponsorisé"
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _secondaryColor, borderRadius: BorderRadius.only(topLeft: Radius.circular(12), bottomRight: Radius.circular(12))),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, color: Colors.black, size: 14),
                  SizedBox(width: 4),
                  Text('SPONSORISÉ', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                  if (widget.ad.renewalCount! > 0) ...[
                    SizedBox(width: 4),
                    Container(padding: EdgeInsets.symmetric(horizontal: 3, vertical: 1), decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                        child: Text('x${widget.ad.renewalCount}', style: TextStyle(color: Colors.black, fontSize: 7, fontWeight: FontWeight.bold))),
                  ],
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCompact(),
                  SizedBox(height: 6),
                  if (widget.post.description != null && widget.post.description!.isNotEmpty)
                    Text(_truncateDescription(widget.post.description!), style: TextStyle(color: _textColor, fontSize: 13, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                  SizedBox(height: 8),
                  // Lecteur vidéo avec hauteur maximale
                  GestureDetector(
                    onTap: _navigateToVideoDetails,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _isVideoInitialized && _videoController != null
                          ? ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: maxVideoHeight),
                        child: AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        ),
                      )
                          : Container(
                        height: maxVideoHeight,
                        color: Colors.grey[900],
                        child: Center(child: CircularProgressIndicator(color: _secondaryColor)),
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                  // Statistiques
                  Row(
                    children: [
                      Row(children: [Icon(Icons.remove_red_eye, color: _hintColor, size: 14), SizedBox(width: 3), Text('${_formatCount(widget.ad.views ?? 0)} vues', style: TextStyle(color: _hintColor, fontSize: 11))]),
                      SizedBox(width: 12),
                      if ((widget.ad.views ?? 0) > 0)
                        Row(children: [Icon(Icons.ads_click, color: _primaryColor, size: 14), SizedBox(width: 3), Text('${widget.ad.ctr.toStringAsFixed(1)}% CTR', style: TextStyle(color: _primaryColor, fontSize: 11, fontWeight: FontWeight.w500))]),
                    ],
                  ),
                  SizedBox(height: 8),
                  // Bouton d'action
                  InkWell(
                    onTap: _handleActionButtonClick,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(gradient: LinearGradient(colors: [_primaryColor, Color(0xFFFF5252)]), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(widget.ad.getActionIcon(), color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(widget.ad.getActionButtonText().toUpperCase(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward, color: Colors.white, size: 14),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}