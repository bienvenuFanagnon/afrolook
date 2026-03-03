// widgets/advertisement_post_widget.dart
import 'dart:async';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/postDetails.dart';
import 'package:afrotok/pages/postDetailsVideoListe.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../providers/authProvider.dart';
import '../../canaux/detailsCanal.dart';
import '../../component/showUserDetails.dart';

class AdvertisementPostWidget extends StatefulWidget {
  final Post post;
  final Advertisement ad;
  final double? height;
  final double width;
  final bool isPreview;
  final Function(Post, Advertisement)? onAdClicked;
  final Function(Post, Advertisement)? onAdViewed;

  const AdvertisementPostWidget({
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
  State<AdvertisementPostWidget> createState() => _AdvertisementPostWidgetState();
}

class _AdvertisementPostWidgetState extends State<AdvertisementPostWidget> {
  late UserAuthProvider authProvider;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isExpanded = false;
  bool _isLoadingUser = false;
  UserData? _currentUser;
  Canal? _currentCanal;

  // Variables pour le comptage de vues
  Timer? _visibilityTimer;
  bool _hasRecordedView = false;
  bool _hasRecordedClick = false;

  // Couleurs
  final Color _primaryColor = Color(0xFFE21221); // Rouge
  final Color _secondaryColor = Color(0xFFFFD600); // Jaune
  final Color _backgroundColor = Color(0xFF121212); // Noir
  final Color _cardColor = Color(0xFF1E1E1E);
  final Color _textColor = Colors.white;
  final Color _hintColor = Colors.grey[400]!;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _loadUserData();
    _loadCanalData();
  }

  @override
  void dispose() {
    _visibilityTimer?.cancel();
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
      print('Erreur lors du chargement de l\'utilisateur: $e');
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
      print('Erreur lors du chargement du canal: $e');
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
        if (difference.inMinutes < 1) {
          return "il y a quelques secondes";
        } else {
          return "il y a ${difference.inMinutes} min";
        }
      } else {
        return "il y a ${difference.inHours} h";
      }
    } else if (difference.inDays < 7) {
      return "il y a ${difference.inDays} j";
    } else {
      return DateFormat('dd/MM/yy').format(dateTime);
    }
  }

  String _getDisplayName() {
    if (currentCanal != null) {
      return '#${currentCanal!.titre}';
    } else if (currentUser != null) {
      return '@${currentUser!.pseudo}';
    }
    return 'Utilisateur';
  }

  ImageProvider? _getProfileImage() {
    if (currentCanal != null && currentCanal!.urlImage != null) {
      return NetworkImage(currentCanal!.urlImage!);
    } else if (currentUser != null && currentUser!.imageUrl != null) {
      return NetworkImage(currentUser!.imageUrl!);
    }
    return null;
  }

  bool _isVideoPost(Post post) {
    return post.dataType == PostDataType.VIDEO.name ||
        (post.url_media ?? '').contains('.mp4') ||
        (post.url_media ?? '').contains('.mov');
  }

  void _navigateToDetails() {
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

  // ===========================================================================
  // COMPTAGE DES VUES
  // ===========================================================================

  void _handleVisibilityChanged(VisibilityInfo info) {
    final postId = widget.post.id!;
    _visibilityTimer?.cancel();

    if (info.visibleFraction > 0.5) {
      _visibilityTimer = Timer(Duration(milliseconds: 500), () {
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

      // Statistiques quotidiennes
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final adRef = _firestore.collection('Advertisements').doc(widget.ad.id);

      // Mise à jour atomique
      await _firestore.runTransaction((transaction) async {
        final adDoc = await transaction.get(adRef);
        if (!adDoc.exists) return;

        final currentAd = Advertisement.fromJson(adDoc.data()!);

        // Vérifier si l'utilisateur a déjà vu
        final hasSeen = currentAd.viewersIds?.contains(currentUserId) ?? false;

        final updates = {
          'views': FieldValue.increment(1),
          'updatedAt': DateTime.now().microsecondsSinceEpoch,
        };

        if (!hasSeen) {
          updates['uniqueClicks'] = FieldValue.increment(1);
          updates['viewersIds'] = FieldValue.arrayUnion([currentUserId]);
        }

        // Mettre à jour les stats quotidiennes
        if (currentAd.dailyStats == null) {
          updates['dailyStats'] = {today: 1};
        } else {
          updates['dailyStats.$today'] = FieldValue.increment(1);
        }

        transaction.update(adRef, updates);
      });

      // Mettre à jour localement
      setState(() {
        widget.ad.views = (widget.ad.views ?? 0) + 1;
      });

      widget.onAdViewed?.call(widget.post, widget.ad);
      print('✅ Vue enregistrée pour la pub: ${widget.ad.id}');

    } catch (e) {
      print('❌ Erreur lors de l\'enregistrement de la vue: $e');
      _hasRecordedView = false;
    }
  }

  // ===========================================================================
  // COMPTAGE DES CLICS
  // ===========================================================================

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

        // Vérifier si l'utilisateur a déjà cliqué
        final hasClicked = currentAd.clickersIds?.contains(currentUserId) ?? false;

        final updates = {
          'clicks': FieldValue.increment(1),
          'updatedAt': DateTime.now().microsecondsSinceEpoch,
        };

        if (!hasClicked) {
          updates['uniqueClicks'] = FieldValue.increment(1);
          updates['clickersIds'] = FieldValue.arrayUnion([currentUserId]);
        }

        // Mettre à jour les stats quotidiennes
        if (currentAd.dailyStats == null) {
          updates['dailyStats'] = {today: {}};
        } else {
          updates['dailyStats.$today.clicks'] = FieldValue.increment(1);
        }

        transaction.update(adRef, updates);
      });

      // Mettre à jour localement
      setState(() {
        widget.ad.clicks = (widget.ad.clicks ?? 0) + 1;
      });

      _hasRecordedClick = true;
      widget.onAdClicked?.call(widget.post, widget.ad);

      print('✅ Clic enregistré pour la pub: ${widget.ad.id}');

      // Ouvrir le lien après avoir enregistré le clic
      if (widget.ad.actionUrl != null && widget.ad.actionUrl!.isNotEmpty) {
        final url = Uri.parse(widget.ad.actionUrl!);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      }

    } catch (e) {
      print('❌ Erreur lors de l\'enregistrement du clic: $e');
    }
  }

  // ===========================================================================
  // WIDGETS DE MÉDIAS
  // ===========================================================================

  Widget _buildImageGrid(double height, int imageCount) {
    final images = widget.post.images!;

    if (imageCount == 1) {
      return _buildSingleImage(images[0], height);
    } else if (imageCount == 2) {
      return _buildTwoImages(images, height);
    } else if (imageCount == 3) {
      return _buildThreeImages(images, height);
    } else {
      return _buildMultipleImages(images, height);
    }
  }

  Widget _buildSingleImage(String imageUrl, double height) {
    return GestureDetector(
      onTap: _navigateToDetails,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: height,
          placeholder: (context, url) => Container(
            color: _hintColor.withOpacity(0.1),
          ),
          errorWidget: (context, url, error) => Container(
            color: _hintColor.withOpacity(0.1),
            child: Icon(Icons.broken_image, color: _hintColor),
          ),
        ),
      ),
    );
  }

  Widget _buildTwoImages(List<String> images, double height) {
    return GestureDetector(
      onTap: _navigateToDetails,
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: 2),
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                child: CachedNetworkImage(
                  imageUrl: images[0],
                  fit: BoxFit.cover,
                  height: height,
                  placeholder: (context, url) => Container(
                    color: _hintColor.withOpacity(0.1),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: _hintColor.withOpacity(0.1),
                    child: Icon(Icons.broken_image, color: _hintColor),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 2),
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                child: CachedNetworkImage(
                  imageUrl: images[1],
                  fit: BoxFit.cover,
                  height: height,
                  placeholder: (context, url) => Container(
                    color: _hintColor.withOpacity(0.1),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: _hintColor.withOpacity(0.1),
                    child: Icon(Icons.broken_image, color: _hintColor),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreeImages(List<String> images, double height) {
    return GestureDetector(
      onTap: _navigateToDetails,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: EdgeInsets.only(right: 2),
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                child: CachedNetworkImage(
                  imageUrl: images[0],
                  fit: BoxFit.cover,
                  height: height,
                  placeholder: (context, url) => Container(
                    color: _hintColor.withOpacity(0.1),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: _hintColor.withOpacity(0.1),
                    child: Icon(Icons.broken_image, color: _hintColor),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              height: height,
              padding: EdgeInsets.only(left: 2),
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(16),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: images[1],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (context, url) => Container(
                            color: _hintColor.withOpacity(0.1),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: _hintColor.withOpacity(0.1),
                            child: Icon(Icons.broken_image, color: _hintColor),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          bottomRight: Radius.circular(16),
                        ),
                        child: CachedNetworkImage(
                          imageUrl: images[2],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          placeholder: (context, url) => Container(
                            color: _hintColor.withOpacity(0.1),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: _hintColor.withOpacity(0.1),
                            child: Icon(Icons.broken_image, color: _hintColor),
                          ),
                        ),
                      ),
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

  Widget _buildMultipleImages(List<String> images, double height) {
    final displayedImages = images.take(4).toList();

    return GestureDetector(
      onTap: _navigateToDetails,
      child: Container(
        height: height,
        child: GridView.builder(
          physics: NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: displayedImages.length,
          itemBuilder: (context, index) {
            BorderRadius borderRadius;
            if (displayedImages.length == 4) {
              switch (index) {
                case 0:
                  borderRadius = BorderRadius.only(topLeft: Radius.circular(16));
                  break;
                case 1:
                  borderRadius = BorderRadius.only(topRight: Radius.circular(16));
                  break;
                case 2:
                  borderRadius = BorderRadius.only(bottomLeft: Radius.circular(16));
                  break;
                case 3:
                  borderRadius = BorderRadius.only(bottomRight: Radius.circular(16));
                  break;
                default:
                  borderRadius = BorderRadius.circular(0);
              }
            } else {
              borderRadius = BorderRadius.circular(0);
            }

            bool hasOverlay = index == 3 && images.length > 4;

            return Stack(
              children: [
                ClipRRect(
                  borderRadius: borderRadius,
                  child: CachedNetworkImage(
                    imageUrl: displayedImages[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    placeholder: (context, url) => Container(
                      color: _hintColor.withOpacity(0.1),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: _hintColor.withOpacity(0.1),
                      child: Icon(Icons.broken_image, color: _hintColor),
                    ),
                  ),
                ),
                if (hasOverlay)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.6),
                      child: Center(
                        child: Text(
                          '+${images.length - 4}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildVideoContent(double height) {
    return Stack(
      children: [
        // Thumbnail vidéo
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: GestureDetector(
            onTap: _navigateToDetails,
            child: (widget.post.images != null && widget.post.images!.isNotEmpty)
                ? CachedNetworkImage(
              imageUrl: widget.post.images!.first,
              fit: BoxFit.cover,
              width: double.infinity,
              height: height,
              placeholder: (context, url) => Container(
                color: _hintColor.withOpacity(0.1),
              ),
              errorWidget: (context, url, error) => Container(
                color: _hintColor.withOpacity(0.1),
                child: Icon(Icons.videocam, color: _hintColor, size: 40),
              ),
            )
                : Container(
              color: _hintColor.withOpacity(0.1),
              child: Center(
                child: Icon(Icons.videocam, color: _hintColor, size: 40),
              ),
            ),
          ),
        ),

        // Overlay play
        Positioned.fill(
          child: Center(
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_arrow, color: Colors.white, size: 30),
            ),
          ),
        ),

        // Badge vidéo
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam, color: _secondaryColor, size: 12),
                SizedBox(width: 4),
                Text(
                  'VIDÉO',
                  style: TextStyle(
                    color: _secondaryColor,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _truncateDescription(String text) {
    final words = text.split(' ');
    if (words.length <= 50) return text;
    return words.take(50).join(' ') + '...';
  }

  double _calculatePostHeight() {
    double totalHeight = 0;

    // Badge PUBLICITÉ (40px)
    totalHeight += 40;

    // Padding (24px)
    totalHeight += 24;

    // En-tête (avatar + texte) (50px)
    totalHeight += 50;

    // Espacements (SizedBox) (12+12+12+16+12 = 64px)
    totalHeight += 64;

    // Description
    if (widget.post.description != null && widget.post.description!.isNotEmpty) {
      int lines = (widget.post.description!.length / 40).ceil();
      if (lines > 3) lines = 3;
      totalHeight += lines * 20.0;
    }

    // Médias
    if (widget.post.images != null && widget.post.images!.isNotEmpty && !_isVideoPost(widget.post)) {
      totalHeight += widget.width * 0.6; // Hauteur des images
    } else if (_isVideoPost(widget.post)) {
      totalHeight += widget.width * 0.6; // Hauteur vidéo
    }

    // Statistiques (30px)
    totalHeight += 30;

    // Bouton d'action (50px)
    totalHeight += 50;

    // Indicateur de fin (30px)
    if (widget.ad.endDate != null) {
      totalHeight += 30;
    }

    return totalHeight;
  }

  // ===========================================================================
  // BUILD PRINCIPAL
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final double mediaHeight = widget.height ?? _calculatePostHeight();
    final double imageHeight = widget.width * 0.5;

    return VisibilityDetector(
      key: Key('ad-post-${widget.post.id}'),
      onVisibilityChanged: _handleVisibilityChanged,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _secondaryColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: _secondaryColor.withOpacity(0.2),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge PUBLICITÉ
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _secondaryColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.campaign, color: Colors.black, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'PUBLICITÉ',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  if (widget.ad.renewalCount! > 0) ...[
                    SizedBox(width: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'x${widget.ad.renewalCount}',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // // En-tête avec utilisateur
                  // _buildHeader(),

                  // SizedBox(height: 12),

                  // DESCRIPTION EN HAUT
                  if (widget.post.description != null && widget.post.description!.isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '${widget.post.description!}',
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 14,
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                  SizedBox(height: 12),

                  // MÉDIAS
                  (widget.post.images != null && widget.post.images!.isNotEmpty && !_isVideoPost(widget.post))
                      ? Container(
                    height: imageHeight,
                    child: _buildImageGrid(imageHeight, widget.post.images!.length),
                  )
                      : _isVideoPost(widget.post)
                      ? Container(
                    height: imageHeight,
                    child: _buildVideoContent(imageHeight),
                  )
                      : SizedBox.shrink(),

                  SizedBox(height: 16),

                  // STATISTIQUES (VUES ET PERFORMANCE)
                  Row(
                    children: [
                      // Vues
                      Row(
                        children: [
                          Icon(Icons.remove_red_eye, color: _hintColor, size: 16),
                          SizedBox(width: 4),
                          Text(
                            '${_formatCount(widget.ad.views ?? 0)} vues',
                            style: TextStyle(
                              color: _hintColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(width: 16),

                      // Taux de clic (CTR)
                      if ((widget.ad.views ?? 0) > 0)
                        Row(
                          children: [
                            Icon(Icons.ads_click, color: _primaryColor, size: 16),
                            SizedBox(width: 4),
                            Text(
                              '${widget.ad.ctr.toStringAsFixed(1)}% CTR',
                              style: TextStyle(
                                color: _primaryColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),

                      Spacer(),

                      // // Badge durée
                      // Container(
                      //   padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      //   decoration: BoxDecoration(
                      //     color: _primaryColor.withOpacity(0.2),
                      //     borderRadius: BorderRadius.circular(12),
                      //   ),
                      //   child: Text(
                      //     '${widget.ad.durationDays} jours',
                      //     style: TextStyle(
                      //       color: _primaryColor,
                      //       fontSize: 11,
                      //       fontWeight: FontWeight.bold,
                      //     ),
                      //   ),
                      // ),
                    ],
                  ),

                  SizedBox(height: 12),

                  // BOUTON D'ACTION EN BAS
                  InkWell(
                    onTap: _handleActionButtonClick,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_primaryColor, Color(0xFFFF5252)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.ad.getActionIcon(),
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Text(
                            widget.ad.getActionButtonText().toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 16,
                          ),
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

  Widget _buildHeader() {
    return GestureDetector(
      onTap: () {
        if (currentCanal != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CanalDetails(canal: currentCanal!),
            ),
          );
        } else if (currentUser != null) {
          showUserDetailsModalDialog(
            currentUser!,
            MediaQuery.of(context).size.width,
            MediaQuery.of(context).size.height,
            context,
          );
        }
      },
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: _primaryColor,
            backgroundImage: _getProfileImage(),
            child: _getProfileImage() == null
                ? Icon(
              currentCanal != null ? Icons.group : Icons.person,
              color: Colors.white,
              size: 18,
            )
                : null,
          ),
          SizedBox(width: 12),

          // Informations
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getDisplayName(),
                  style: TextStyle(
                    color: _textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  formaterDateTime(widget.post.createdAt),
                  style: TextStyle(
                    color: _hintColor,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          // Badge statut pub
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: widget.ad.isActive
                  ? Colors.green.withOpacity(0.2)
                  : widget.ad.isPending
                  ? Colors.orange.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.ad.isActive
                    ? Colors.green
                    : widget.ad.isPending
                    ? Colors.orange
                    : Colors.grey,
              ),
            ),
            child: Text(
              widget.ad.isActive
                  ? 'Active'
                  : widget.ad.isPending
                  ? 'En attente'
                  : 'Expirée',
              style: TextStyle(
                color: widget.ad.isActive
                    ? Colors.green
                    : widget.ad.isPending
                    ? Colors.orange
                    : Colors.grey,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}