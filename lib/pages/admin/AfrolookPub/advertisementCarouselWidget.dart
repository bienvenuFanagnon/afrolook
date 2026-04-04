// widgets/advertisement_carousel_widget.dart
import 'dart:async';
import 'package:afrotok/models/model_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/authProvider.dart';
import '../../../services/ad_carousel_service.dart';
import 'advertisementPostImageWidget.dart';
import 'advertisement_video_widget.dart';

class AdvertisementCarouselWidget extends StatefulWidget {
  final double height;
  final double width;
  final bool showIndicators;
  final Function(Post, Advertisement)? onAdClicked;
  final Function(Post, Advertisement)? onAdViewed;

  const AdvertisementCarouselWidget({
    Key? key,
    required this.height,
    required this.width,
    this.showIndicators = true,
    this.onAdClicked,
    this.onAdViewed,
  }) : super(key: key);

  @override
  State<AdvertisementCarouselWidget> createState() => _AdvertisementCarouselWidgetState();
}

class _AdvertisementCarouselWidgetState extends State<AdvertisementCarouselWidget> {
  late UserAuthProvider authProvider;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdCarouselService _carouselService = AdCarouselService.instance;

  List<Map<String, dynamic>> _activeAds = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _hasError = false;
  final Color _secondaryColor = Color(0xFFFFD600);
  final Color _hintColor = Colors.grey[400]!;

  @override
  void initState() {
    super.initState();
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    _loadActiveAds();
  }

  Future<void> _loadActiveAds() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final now = DateTime.now().microsecondsSinceEpoch;
      final adsSnapshot = await _firestore
          .collection('Advertisements')
          .where('status', isEqualTo: 'active')
          .where('endDate', isGreaterThan: now)
          .get();

      if (adsSnapshot.docs.isEmpty) {
        setState(() => _activeAds = []);
        _isLoading = false;
        return;
      }

      List<Map<String, dynamic>> tempAds = [];
      for (var adDoc in adsSnapshot.docs) {
        final ad = Advertisement.fromJson(adDoc.data());
        if (ad.postId == null) continue;
        final postDoc = await _firestore.collection('Posts').doc(ad.postId).get();
        if (postDoc.exists) {
          final post = Post.fromJson(postDoc.data()!);
          post.advertisementId = ad.id;
          post.isAdvertisement = true;
          tempAds.add({'ad': ad.toJson(), 'post': post.toJson()});
        }
      }

      // 🔥 AJOUTER LE MÉLANGE ICI 🔥
      tempAds.shuffle();

      setState(() => _activeAds = tempAds);

      // Gestion de l'index persistant (mais comme la liste a changé, il sera réinitialisé)
      final savedIndex = await _carouselService.getCurrentIndex();
      final adsIds = _activeAds.map((e) => e['ad']['id'] as String).toList();
      final savedIds = await _carouselService.getAdsList();

      if (!_listsEqual(adsIds, savedIds)) {
        await _carouselService.saveAdsList(adsIds);
        await _carouselService.setCurrentIndex(0);
        _currentIndex = 0;
      } else {
        _currentIndex = savedIndex % (_activeAds.length);
      }
      _isLoading = false;
    } catch (e) {
      print('❌ Erreur chargement carousel: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }
  bool _listsEqual(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) if (a[i] != b[i]) return false;
    return true;
  }

  Future<void> _goToPrevious() async {
    if (_activeAds.isEmpty) return;
    int newIndex = (_currentIndex - 1) % _activeAds.length;
    if (newIndex < 0) newIndex = _activeAds.length - 1;
    setState(() => _currentIndex = newIndex);
    await _carouselService.setCurrentIndex(newIndex);
  }

  Future<void> _goToNext() async {
    if (_activeAds.isEmpty) return;
    int newIndex = (_currentIndex + 1) % _activeAds.length;
    setState(() => _currentIndex = newIndex);
    await _carouselService.setCurrentIndex(newIndex);
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        height: widget.height * 0.5,
        decoration: BoxDecoration(color: Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16)),
        child: Center(child: CircularProgressIndicator(color: _secondaryColor)),
      );
    }
    if (_hasError || _activeAds.isEmpty) return const SizedBox.shrink();

    final currentAdData = _activeAds[_currentIndex];
    final post = Post.fromJson(currentAdData['post']);
    final ad = Advertisement.fromJson(currentAdData['ad']);
    final bool isVideo = post.dataType == PostDataType.VIDEO.name ||
        (post.url_media?.contains('.mp4') ?? false) ||
        (post.url_media?.contains('.mov') ?? false);

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // En-tête avec compteur et navigation
          // Padding(
          //   padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          //   child: Row(
          //     children: [
          //       Container(
          //         padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          //         decoration: BoxDecoration(color: _secondaryColor, borderRadius: BorderRadius.circular(12)),
          //         child: Row(
          //           mainAxisSize: MainAxisSize.min,
          //           children: [
          //             Icon(Icons.campaign, color: Colors.black, size: 14),
          //             SizedBox(width: 4),
          //             Text('SPONSORISÉ', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
          //           ],
          //         ),
          //       ),
          //       SizedBox(width: 8),
          //       Text('${_currentIndex + 1}/${_activeAds.length}', style: TextStyle(color: _hintColor, fontSize: 12)),
          //       Spacer(),
          //       // Statistiques globales (optionnel)
          //       Row(
          //         children: [
          //           Icon(Icons.remove_red_eye, color: _hintColor, size: 14),
          //           SizedBox(width: 2),
          //           Text(_formatCount(ad.views ?? 0), style: TextStyle(color: _hintColor, fontSize: 11)),
          //           SizedBox(width: 8),
          //           Icon(Icons.ads_click, color: _secondaryColor, size: 14),
          //           SizedBox(width: 2),
          //           Text(_formatCount(ad.clicks ?? 0), style: TextStyle(color: _secondaryColor, fontSize: 11)),
          //         ],
          //       ),
          //     ],
          //   ),
          // ),
          // Contenu de la pub courante
          isVideo
              ? AdvertisementVideoWidget(
            post: post,
            ad: ad,
            width: widget.width,
            height: widget.height,
            onAdClicked: widget.onAdClicked,
            onAdViewed: widget.onAdViewed,
          )
              : AdvertisementPostImageWidget(
            post: post,
            ad: ad,
            width: widget.width,
            height: widget.height,
            onAdClicked: widget.onAdClicked,
            onAdViewed: widget.onAdViewed,
          ),
          // Indicateurs et boutons de navigation
          if (widget.showIndicators && _activeAds.length > 1)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left, color: _secondaryColor, size: 28),
                    onPressed: _goToPrevious,
                  ),
                  ...List.generate(_activeAds.length, (index) {
                    return GestureDetector(
                      onTap: () async {
                        setState(() => _currentIndex = index);
                        await _carouselService.setCurrentIndex(index);
                      },
                      child: AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        width: _currentIndex == index ? 20 : 8,
                        height: 8,
                        margin: EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: _currentIndex == index ? _secondaryColor : _secondaryColor.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    );
                  }),
                  IconButton(
                    icon: Icon(Icons.chevron_right, color: _secondaryColor, size: 28),
                    onPressed: _goToNext,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}


// // widgets/advertisement_carousel_widget.dart
// import 'dart:async';
// import 'package:afrotok/models/model_data.dart';
// import 'package:afrotok/pages/component/consoleWidget.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:provider/provider.dart';
//
// import '../../../providers/authProvider.dart';
// import 'advertisementPostImageWidget.dart';
//
// class AdvertisementCarouselWidget extends StatefulWidget {
//   final double height;
//   final double width;
//   final Duration autoPlayDuration;
//   final bool showIndicators;
//   final Function(Post, Advertisement)? onAdClicked;
//   final Function(Post, Advertisement)? onAdViewed;
//
//   const AdvertisementCarouselWidget({
//     Key? key,
//     required this.height,
//     required this.width,
//     this.autoPlayDuration = const Duration(seconds: 5),
//     this.showIndicators = true,
//     this.onAdClicked,
//     this.onAdViewed,
//   }) : super(key: key);
//
//   @override
//   State<AdvertisementCarouselWidget> createState() => _AdvertisementCarouselWidgetState();
// }
//
// class _AdvertisementCarouselWidgetState extends State<AdvertisementCarouselWidget> {
//   late UserAuthProvider authProvider;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//
//   List<Map<String, dynamic>> _activeAds = [];
//   late PageController _pageController;
//   int _currentIndex = 0;
//   int _lastShownIndex = -1;
//   Timer? _autoPlayTimer;
//   bool _isLoading = true;
//   bool _hasError = false;
//
//   // Map pour suivre les IDs des pubs déjà comptées dans cette session
//   final Set<String> _viewedInSession = {};
//   final Set<String> _clickedInSession = {};
//
//   final Color _secondaryColor = Color(0xFFFFD600);
//   final Color _hintColor = Colors.grey[400]!;
//
//   @override
//   void initState() {
//     super.initState();
//     authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     _pageController = PageController();
//     _loadActiveAds();
//   }
//
//   @override
//   void dispose() {
//     _autoPlayTimer?.cancel();
//     _pageController.dispose();
//     super.dispose();
//   }
//
//   Future<void> _loadActiveAds() async {
//     setState(() {
//       _isLoading = true;
//       _hasError = false;
//     });
//
//     try {
//       final now = DateTime.now().microsecondsSinceEpoch;
//
//       final adsSnapshot = await _firestore
//           .collection('Advertisements')
//           .where('status', isEqualTo: 'active')
//           .where('endDate', isGreaterThan: now)
//           .orderBy('endDate', descending: false)
//           .get();
//
//       if (adsSnapshot.docs.isEmpty) {
//         setState(() {
//           _activeAds = [];
//           _isLoading = false;
//         });
//         return;
//       }
//
//       List<Map<String, dynamic>> tempAds = [];
//       printVm("ad data: ${adsSnapshot.docs.length}");
//
//       for (var adDoc in adsSnapshot.docs) {
//         final ad = Advertisement.fromJson(adDoc.data());
//         // printVm("ad data: ${ad.toJson()}");
//
//         if (ad.postId == null) continue;
//
//         final postDoc = await _firestore.collection('Posts').doc(ad.postId).get();
//
//         if (postDoc.exists) {
//           final post = Post.fromJson(postDoc.data()!);
//           post.advertisementId = ad.id;
//           post.isAdvertisement = true;
//
//           tempAds.add({
//             'ad': ad.toJson(),
//             'post': post.toJson(),
//           });
//         }
//       }
//       // printVm("ad data: tempAds: ${tempAds}");
//
//       tempAds.shuffle();
//
//       setState(() {
//         _activeAds = tempAds;
//         _isLoading = false;
//
//         if (_activeAds.isNotEmpty) {
//           _currentIndex = 0;
//           _lastShownIndex = 0;
//           _startAutoPlay();
//         }
//       });
//
//     } catch (e) {
//       print('❌ Erreur chargement carousel pubs: $e');
//       setState(() {
//         _isLoading = false;
//         _hasError = true;
//       });
//     }
//   }
//
//   void _startAutoPlay() {
//     _autoPlayTimer?.cancel();
//
//     if (_activeAds.length > 1) {
//       _autoPlayTimer = Timer.periodic(widget.autoPlayDuration, (timer) {
//         if (mounted) {
//           _goToNextAd();
//         }
//       });
//     }
//   }
//
//   void _goToNextAd() {
//     if (_activeAds.isEmpty) return;
//     if (!_pageController.hasClients) return;
//
//     int nextIndex =
//         (_currentIndex + 1) % _activeAds.length;
//
//     _pageController.animateToPage(
//       nextIndex,
//       duration: Duration(milliseconds: 400),
//       curve: Curves.easeInOut,
//     );
//   }
//   // ===========================================================================
//   // MISE À JOUR DES STATISTIQUES DANS FIRESTORE
//   // ===========================================================================
//
//   Future<void> _recordAdView(Advertisement ad, Post post) async {
//     final currentUserId = authProvider.loginUserData.id;
//     if (currentUserId == null || ad.id == null) return;
//
//     // Éviter les doubles comptages dans la même session
//     final viewKey = '${ad.id}_$currentUserId';
//     if (_viewedInSession.contains(viewKey)) return;
//
//     _viewedInSession.add(viewKey);
//
//     try {
//       final adRef = _firestore.collection('Advertisements').doc(ad.id);
//       final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
//
//       await _firestore.runTransaction((transaction) async {
//         final adDoc = await transaction.get(adRef);
//         if (!adDoc.exists) return;
//
//         final currentAd = Advertisement.fromJson(adDoc.data()!);
//
//         // Préparer les mises à jour
//         Map<String, dynamic> updates = {
//           'views': FieldValue.increment(1),
//           'updatedAt': DateTime.now().microsecondsSinceEpoch,
//         };
//
//         // Mettre à jour dailyStats
//         if (currentAd.dailyStats == null) {
//           updates['dailyStats'] = {today: 1};
//         } else {
//           updates['dailyStats.$today'] = FieldValue.increment(1);
//         }
//
//         // Vérifier si c'est une vue unique
//         final hasSeen = currentAd.viewersIds?.contains(currentUserId) ?? false;
//         if (!hasSeen) {
//           updates['uniqueViews'] = FieldValue.increment(1);
//           updates['viewersIds'] = FieldValue.arrayUnion([currentUserId]);
//         }
//
//         transaction.update(adRef, updates);
//       });
//
//       // Mettre à jour l'objet local
//       // ad.views = (ad.views ?? 0) + 1;
//
//       // Notifier le parent
//       widget.onAdViewed?.call(post, ad);
//
//       print('✅ Vue enregistrée pour la pub: ${ad.id}');
//
//     } catch (e) {
//       print('❌ Erreur lors de l\'enregistrement de la vue: $e');
//       _viewedInSession.remove(viewKey);
//     }
//   }
//
//   Future<void> _recordAdClick(Advertisement ad, Post post) async {
//     final currentUserId = authProvider.loginUserData.id;
//     if (currentUserId == null || ad.id == null) return;
//
//     // Éviter les doubles comptages dans la même session
//     final clickKey = '${ad.id}_$currentUserId';
//     if (_clickedInSession.contains(clickKey)) return;
//
//     _clickedInSession.add(clickKey);
//
//     try {
//       final adRef = _firestore.collection('Advertisements').doc(ad.id);
//       final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
//
//       await _firestore.runTransaction((transaction) async {
//         final adDoc = await transaction.get(adRef);
//         if (!adDoc.exists) return;
//
//         final currentAd = Advertisement.fromJson(adDoc.data()!);
//
//         // Préparer les mises à jour
//         Map<String, dynamic> updates = {
//           'clicks': FieldValue.increment(1),
//           'updatedAt': DateTime.now().microsecondsSinceEpoch,
//         };
//
//         // Mettre à jour dailyStats
//         if (currentAd.dailyStats != null) {
//           updates['dailyStats.$today.clicks'] = FieldValue.increment(1);
//         }
//
//         // Vérifier si c'est un clic unique
//         final hasClicked = currentAd.clickersIds?.contains(currentUserId) ?? false;
//         if (!hasClicked) {
//           updates['uniqueClicks'] = FieldValue.increment(1);
//           updates['clickersIds'] = FieldValue.arrayUnion([currentUserId]);
//         }
//
//         transaction.update(adRef, updates);
//       });
//
//       // Mettre à jour l'objet local
//       ad.clicks = (ad.clicks ?? 0) + 1;
//
//       // Notifier le parent
//       widget.onAdClicked?.call(post, ad);
//
//       print('✅ Clic enregistré pour la pub: ${ad.id}');
//
//     } catch (e) {
//       print('❌ Erreur lors de l\'enregistrement du clic: $e');
//       _clickedInSession.remove(clickKey);
//     }
//   }
//
//   void _handleAdViewed(Post post, Advertisement ad) {
//     _recordAdView(ad, post);
//   }
//
//   void _handleAdClicked(Post post, Advertisement ad) {
//     _recordAdClick(ad, post);
//   }
//
//   String _formatCount(int count) {
//     if (count < 1000) return count.toString();
//     if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
//     return '${(count / 1000000).toStringAsFixed(1)}M';
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return _buildLoadingSkeleton();
//     }
//
//     if (_hasError || _activeAds.isEmpty) {
//       return SizedBox.shrink();
//     }
//     return LayoutBuilder(
//       builder: (context, constraints) {
//
//         int totalViews = _activeAds.fold<int>(
//           0,
//               (sum, item) {
//             final views = item['ad']?['views'];
//             if (views is int) {
//               return sum + views;
//             }
//             return sum;
//           },
//         );
//
//         int totalClicks = _activeAds.fold<int>(
//           0,
//               (sum, item) {
//             final clicks = item['ad']?['clicks'];
//             if (clicks is int) {
//               return sum + clicks;
//             }
//             return sum;
//           },
//         );
//
//         return Container(
//           margin: EdgeInsets.symmetric(vertical: 8),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               // En-tête du carousel avec statistiques
//               Padding(
//                 padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                 child: Row(
//                   children: [
//                     Container(
//                       padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
//                       decoration: BoxDecoration(
//                         color: _secondaryColor,
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: Row(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           Icon(Icons.campaign, color: Colors.black, size: 14),
//                           SizedBox(width: 4),
//                           Text(
//                             'PUBLICITÉS',
//                             style: TextStyle(
//                               color: Colors.black,
//                               fontSize: 11,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     SizedBox(width: 8),
//                     Text(
//                       '${_currentIndex + 1}/${_activeAds.length}',
//                       style: TextStyle(
//                         color: _hintColor,
//                         fontSize: 12,
//                       ),
//                     ),
//                     Spacer(),
//                     // Statistiques globales depuis Firestore
//                     Row(
//                       children: [
//                         Icon(Icons.remove_red_eye, color: _hintColor, size: 14),
//                         SizedBox(width: 2),
//                         Text(
//                           _formatCount(totalViews),
//                           style: TextStyle(color: _hintColor, fontSize: 11),
//                         ),
//                         SizedBox(width: 8),
//                         Icon(Icons.ads_click, color: _secondaryColor, size: 14),
//                         SizedBox(width: 2),
//                         Text(
//                           _formatCount(totalClicks),
//                           style: TextStyle(color: _secondaryColor, fontSize: 11),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//
//               // Publicités
//               ConstrainedBox(
//                 constraints: BoxConstraints(
//                   minHeight: widget.height* 0.53,
//                   maxHeight: widget.height* 0.53,
//                 ),
//                 child: PageView.builder(
//                   itemCount: _activeAds.length,
//                   // controller: PageController(initialPage: _currentIndex),
//                   controller: _pageController,
//                   onPageChanged: (index) {
//                     setState(() {
//                       _currentIndex = index;
//                       _lastShownIndex = index;
//                     });
//                   },
//                   itemBuilder: (context, index) {
//                     final adData = _activeAds[index];
//                     return Padding(
//                       padding: EdgeInsets.symmetric(horizontal: 8),
//                       child: AdvertisementPostWidget(
//                         post: Post.fromJson(adData['post']),
//                         ad:Advertisement.fromJson(adData['ad']),
//                         width: widget.height* 0.54,
//                         isPreview: true,
//                         onAdClicked: _handleAdClicked,
//                         onAdViewed: _handleAdViewed,
//                       ),
//                     );
//                   },
//                 ),
//               ),
//
//               // Indicateurs de pagination
//               if (widget.showIndicators && _activeAds.length > 1)
//                 Padding(
//                   padding: EdgeInsets.symmetric(vertical: 12),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: List.generate(
//                       _activeAds.length,
//                           (index) => GestureDetector(
//                         onTap: () {
//                           setState(() {
//                             _currentIndex = index;
//                             _lastShownIndex = index;
//                           });
//                           // _startAutoPlay();
//                           WidgetsBinding.instance.addPostFrameCallback((_) {
//                             _startAutoPlay();
//                           });
//                         },
//                         child: AnimatedContainer(
//                           duration: Duration(milliseconds: 300),
//                           width: _currentIndex == index ? 24 : 8,
//                           height: 8,
//                           margin: EdgeInsets.symmetric(horizontal: 4),
//                           decoration: BoxDecoration(
//                             color: _currentIndex == index
//                                 ? _secondaryColor
//                                 : _secondaryColor.withOpacity(0.3),
//                             borderRadius: BorderRadius.circular(4),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//             ],
//           ),
//         );
//       },
//     );
//   }
//
//   Widget _buildLoadingSkeleton() {
//     return Container(
//       margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       height: 300,
//       decoration: BoxDecoration(
//         color: Color(0xFF1E1E1E),
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Center(
//         child: CircularProgressIndicator(
//           color: _secondaryColor,
//         ),
//       ),
//     );
//   }
// }