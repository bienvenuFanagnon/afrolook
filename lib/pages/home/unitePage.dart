import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/UserServices/ServiceWidget.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/component/showUserDetails.dart';
import 'package:afrotok/pages/contenuPayant/contentDetails.dart';
import 'package:afrotok/pages/contenuPayant/contentSerie.dart';
import 'package:afrotok/pages/home/storyCustom/StoryCustom.dart';
import 'package:afrotok/pages/story/afroStory/storie/storyFormChoise.dart';
import 'package:afrotok/pages/userPosts/postWidgets/postHomeWidget.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/contenuPayantProvider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../providers/afroshop/categorie_produits_provider.dart';
import '../../providers/chroniqueProvider.dart';
import '../../services/postPrepareService.dart';
import '../afroshop/marketPlace/acceuil/home_afroshop.dart';
import '../afroshop/marketPlace/component.dart';
import '../auth/authTest/Screens/Login/loginPageUser.dart';
import '../canaux/listCanal.dart';
import '../challenge/postChallengeWidget.dart';
import '../chronique/chroniqueform.dart';
import '../chronique/chroniquehome.dart';
import '../userPosts/postWidgets/postWidgetPage.dart';

import '../chronique/chroniquedetails.dart';

class UnifiedHomePage extends StatefulWidget {
  const UnifiedHomePage({super.key});

  @override
  State<UnifiedHomePage> createState() => _UnifiedHomePageState();
}

class _UnifiedHomePageState extends State<UnifiedHomePage> {
  final int _initialLimit = 5;
  final int _loadMoreLimit = 5;
  final Map<String, String> _videoThumbnails = {};
  final Map<String, bool> _userVerificationStatus = {};
  final Map<String, UserData> _userDataCache = {};
  late UserAuthProvider _authProvider;
  late PostProvider postProvider;
  late ContentProvider _contentProvider;
  late CategorieProduitProvider categorieProduitProvider;
  late ChroniqueProvider chroniqueProvider;

  List<Post> _posts = [];
  List<ContentPaie> _contents = [];
  List<dynamic> _mixedItems = [];
  List<Chronique> _activeChroniques = [];
  Map<String, List<Chronique>> _groupedChroniques = {};

  bool _isLoading = true;
  bool _hasError = false;
  bool _isLoadingMore = false;
  bool _hasMorePosts = true;
  bool _hasMoreContent = true;
  bool _isLoadingChroniques = false;

  DocumentSnapshot? _lastContentDocument;

  final ScrollController _scrollController = ScrollController();
  final Random _random = Random();
  Color _color = Colors.blue;

  final Map<String, bool> _postsViewedInSession = {};
  final Map<String, Timer> _visibilityTimers = {};

  // Nouvelle variable pour suivre le chargement anticipé
  bool _isNearEnd = false;
  int _lastLoadedItemCount = 0;

  @override
  void initState() {
    super.initState();
    _authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);
    _contentProvider = Provider.of<ContentProvider>(context, listen: false);
    categorieProduitProvider = Provider.of<CategorieProduitProvider>(context, listen: false);
    chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);
    _checkAndCleanViewedPosts();
    _loadAdditionalData();
    _loadInitialData();
    _loadActiveChroniques();
    _scrollController.addListener(_scrollListener);
  }
  Future<void> _checkAndCleanViewedPosts() async {
    final currentUserId = _authProvider.loginUserData.id;
    if (currentUserId != null) {
      await _authProvider.checkAndCleanViewedPosts(currentUserId);
    }
  }
  @override
  void dispose() {
    _scrollController.dispose();
    _visibilityTimers.forEach((key, timer) => timer.cancel());
    _visibilityTimers.clear();
    super.dispose();
  }



  // NOUVELLE FONCTION : Charger les chroniques actives
  Future<void> _loadActiveChroniques() async {
    if (_isLoadingChroniques) return;

    setState(() => _isLoadingChroniques = true);

    try {
      final chroniques = await chroniqueProvider.getActiveChroniques().first;

      // Grouper les chroniques par utilisateur
      final Map<String, List<Chronique>> grouped = {};
      for (var chronique in chroniques) {
        if (!grouped.containsKey(chronique.userId)) {
          grouped[chronique.userId] = [];
        }
        grouped[chronique.userId]!.add(chronique);
      }

      // Trier chaque groupe par date (plus récent en premier)
      grouped.forEach((userId, userChroniques) {
        userChroniques.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });

      // Charger les thumbnails vidéo et données utilisateur
      await _loadVideoThumbnails(chroniques);
      await _loadUserVerificationStatus(grouped.keys.toList());

      setState(() {
        _groupedChroniques = grouped;
        _activeChroniques = chroniques;
        _isLoadingChroniques = false;
      });
    } catch (e) {
      print('Erreur chargement chroniques: $e');
      setState(() => _isLoadingChroniques = false);
    }
  }

  Future<void> _loadVideoThumbnails(List<Chronique> chroniques) async {
    for (var chronique in chroniques) {
      if (chronique.type == ChroniqueType.VIDEO && chronique.mediaUrl != null) {
        try {
          final thumbnail = await VideoThumbnail.thumbnailFile(
            video: chronique.mediaUrl!,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 200,
            quality: 50,
            timeMs: 2000, // 2ème frame
          );
          if (thumbnail != null) {
            _videoThumbnails[chronique.id!] = thumbnail;
          }
        } catch (e) {
          print('Erreur génération thumbnail: $e');
        }
      }
    }
  }

  Future<void> _loadUserVerificationStatus(List<String> userIds) async {
    for (var userId in userIds) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('Users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          final userData = UserData.fromJson(userDoc.data() as Map<String, dynamic>);
          _userDataCache[userId] = userData;
          _userVerificationStatus[userId] = userData.isVerify ?? false;
        }
      } catch (e) {
        print('Erreur chargement statut vérification: $e');
      }
    }
  }
  // NOUVELLE FONCTION : Widget pour la section des chroniques
  Widget _buildChroniquesSection() {
    if (_isLoadingChroniques) {
      return _buildChroniquesShimmer();
    }

    if (_groupedChroniques.isEmpty) {
      return SizedBox(); // Ne rien afficher s'il n'y a pas de chroniques
    }

    final groupedList = _groupedChroniques.values.toList();

    // Trier les groupes par la chronique la plus récente
    groupedList.sort((a, b) {
      final latestA = a.isNotEmpty ? a.first.createdAt : Timestamp.now();
      final latestB = b.isNotEmpty ? b.first.createdAt : Timestamp.now();
      return latestB.compareTo(latestA);
    });

    return Container(
      height: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de la section chroniques
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Chroniques Actives',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChroniqueHomePage(),
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Color(0xFFFFD700).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Color(0xFFFFD700)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Voir tout',
                          style: TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward,
                          color: Color(0xFFFFD700),
                          size: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Liste horizontale des chroniques
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 12),
              itemCount: groupedList.length,
              itemBuilder: (context, index) {
                return _buildChroniqueItem(groupedList[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  // NOUVELLE FONCTION : Widget pour un item de chronique
  Widget _buildChroniqueItem(List<Chronique> userChroniques) {
    if (userChroniques.isEmpty) return SizedBox();

    final firstChronique = userChroniques.first;
    final chroniqueCount = userChroniques.length;
    final hasMultiple = chroniqueCount > 1;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChroniqueDetailPage(
              userChroniques: userChroniques,
            ),
          ),
        );
      },
      child: Container(
        width: 140,
        margin: EdgeInsets.only(right: 8),
        child: Column(
          children: [
            // Carte rectangulaire de la chronique avec stats superposées
            Stack(
              children: [
                // Conteneur principal de l'aperçu
                Container(
                  width: 140,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Color(0xFFFFD700),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 8,
                        offset: Offset(2, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _buildChroniquePreview(firstChronique),
                  ),
                ),

                // Badge de vérification
                if (_isUserVerified(firstChronique.userId))
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 3,
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.verified,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),

                // Badge pour multiples chroniques
                if (hasMultiple)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Color(0xFFFFD700)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 3,
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        '+${chroniqueCount - 1}',
                        style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // Stats superposées en bas (vues seulement)
                Positioned(
                  bottom: 6,
                  left: 6,
                  right: 6,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.remove_red_eye, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          _formatCount(firstChronique.viewCount),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),

            // Informations utilisateur (seulement le pseudo)
            Container(
              constraints: BoxConstraints(maxWidth: 130),
              child: Text(
                '@${firstChronique.userPseudo}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }  // NOUVELLE FONCTION : Preview de la chronique
  Widget _buildChroniquePreview(Chronique chronique) {
    switch (chronique.type) {
      case ChroniqueType.TEXT:
        return Container(
          decoration: BoxDecoration(
            color: Color(int.parse(chronique.backgroundColor!, radix: 16)),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                chronique.textContent ?? '',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );

      case ChroniqueType.IMAGE:
        return Stack(
          children: [
            CachedNetworkImage(
              imageUrl: chronique.mediaUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              placeholder: (context, url) => Container(
                color: Colors.grey[800],
                child: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFFFFD700),
                    strokeWidth: 2,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[800],
                child: Icon(
                  Icons.error,
                  color: Color(0xFFFFD700),
                  size: 30,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ],
        );

      case ChroniqueType.VIDEO:
        return Stack(
          children: [
            // Aperçu de la vidéo (thumbnail)
            if (_videoThumbnails.containsKey(chronique.id!))
              Image.file(
                File(_videoThumbnails[chronique.id!]!),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              )
            else
              Container(
                color: Colors.grey[900],
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_circle_filled,
                        color: Color(0xFFFFD700),
                        size: 30,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Vidéo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ],
        );
    }
  }

  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  String _getTimeLeft(Timestamp expiresAt) {
    final now = DateTime.now();
    final expireTime = expiresAt.toDate();
    final difference = expireTime.difference(now);

    if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Exp';
    }
  }
  bool _isUserVerified(String userId) {
    return _userVerificationStatus[userId] ?? false;
  }
  // NOUVELLE FONCTION : Shimmer pour le chargement des chroniques
  Widget _buildChroniquesShimmer() {
    return Container(
      height: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Shimmer.fromColors(
                  baseColor: Colors.grey[800]!,
                  highlightColor: Colors.grey[700]!,
                  child: Container(
                    width: 120,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Shimmer.fromColors(
                  baseColor: Colors.grey[800]!,
                  highlightColor: Colors.grey[700]!,
                  child: Container(
                    width: 60,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 12),
              itemCount: 5,
              itemBuilder: (context, index) {
                return Container(
                  width: 80,
                  margin: EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      Shimmer.fromColors(
                        baseColor: Colors.grey[800]!,
                        highlightColor: Colors.grey[700]!,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey[800],
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Shimmer.fromColors(
                        baseColor: Colors.grey[800]!,
                        highlightColor: Colors.grey[700]!,
                        child: Container(
                          width: 60,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _scrollListener() {
    final hasMoreData = _hasMorePosts || _hasMoreContent;

    if (!hasMoreData || _isLoadingMore) return;

    // Calculer la position actuelle par rapport à la fin
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    final totalItems = _mixedItems.length;

    // Vérifier si on est à 70% de la liste actuelle
    if (totalItems > 0) {
      final scrollPercentage = currentScroll / (maxScroll == double.infinity ? currentScroll : maxScroll);
      final itemsThreshold = (totalItems * 0.7).floor();

      // Déclencher le chargement quand on atteint 70% des items OU 70% du scroll
      if ((currentScroll > 0 && scrollPercentage > 0.7) ||
          _scrollController.position.extentAfter < 200) {

        if (!_isNearEnd) {
          _isNearEnd = true;
          print('📜 Déclenchement anticipé du chargement supplémentaire (70%)');
          _loadMoreData();
        }
      } else {
        _isNearEnd = false;
      }
    }

    // Garder l'ancienne logique pour la fin absolue
    final isNearBottom = _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100;

    if (isNearBottom && !_isLoadingMore && hasMoreData && !_isNearEnd) {
      print('📜 Déclenchement du chargement en fin de liste');
      _loadMoreData();
    }
  }

  void _changeColor() {
    final List<Color> colors = [
      Colors.blue,
      Colors.green,
      Colors.brown,
      Colors.blueAccent,
      Colors.red,
      Colors.yellow,
    ];
    _color = colors[_random.nextInt(colors.length)];
  }

  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _postsViewedInSession.clear();
        _isNearEnd = false;
      });

      _lastContentDocument = null;

      await Future.wait([
        _loadPostsWithStream(isInitialLoad: true),
      ]);

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      print('Error loading initial data: $e');
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _getTotalContentCount() async {
    try {
      final query = FirebaseFirestore.instance.collection('ContentPaies');
      final snapshot = await query.count().get();
      _totalContentCount = snapshot.count!;
      print('_totalContentCount content count: $_totalContentCount');
    } catch (e) {
      print('Error getting total content count: $e');
      _totalContentCount = 0;
    }
  }

  Future<void> _loadPostsWithStream({bool isInitialLoad = false}) async {
    try {
      final currentUserId = _authProvider.loginUserData.id;

      if (isInitialLoad) {
        await _loadUnseenPostsFirst(currentUserId);
      } else {
        await _loadMoreUnseenPosts(currentUserId);
      }

      _createMixedList();

    } catch (e) {
      print('Error loading posts: $e');
      setState(() {
        _hasMorePosts = false;
      });
    }
  }

  Future<void> cleanInvalidPostIds(AppDefaultData appData) async {
    print('🚀 Début du nettoyage des IDs inexistants dans Firestore...');

    final firestore = FirebaseFirestore.instance;
    final allPostIds = List<String>.from(appData.allPostIds ?? []);

    if (allPostIds.isEmpty) {
      print('⚠️ Aucun ID à vérifier. Fin du processus.');
      return;
    }

    print('📦 Total d\'IDs à vérifier : ${allPostIds.length}');

    final validIds = <String>[];
    final invalidIds = <String>[];

    int checkedCount = 0;

    for (var id in allPostIds.where((id) => id.isNotEmpty)) {
      try {
        final snapshot = await firestore
            .collection('Posts')
            .where(FieldPath.documentId, isEqualTo: id)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          validIds.add(id);
        } else {
          invalidIds.add(id);
        }
      } catch (e) {
        print('⚠️ Erreur lors de la vérification de l\'ID $id : $e');
      }

      checkedCount++;
      if (checkedCount % 10 == 0 || checkedCount == allPostIds.length) {
        final progress = ((checkedCount / allPostIds.length) * 100).toStringAsFixed(1);
        print('🔹 Progression : $checkedCount/${allPostIds.length} IDs vérifiés ($progress%)');
      }
    }

    // Mise à jour de l'objet local
    appData.allPostIds = validIds;

    // 🔹 Mise à jour dans Firestore
    try {
      await firestore.collection('AppData').doc("XgkSxKc10vWsJJ2uBraT").update({
        'allPostIds': validIds,
      });
      print('✅ Firestore mis à jour avec les IDs valides.');
    } catch (e) {
      print('❌ Erreur lors de la mise à jour dans Firestore : $e');
    }

    print('📊 Résumé final :');
    print(' - ✅ ${validIds.length} IDs valides conservés');
    print(' - 🗑️ ${invalidIds.length} IDs supprimés');
    if (invalidIds.isNotEmpty) print('🧾 IDs supprimés : $invalidIds');
    print('🏁 Nettoyage terminé avec succès.');
  }

  Future<void> _loadUnseenPostsFirst(String? currentUserId) async {
    if (currentUserId == null) {
      await _loadMorePostsChronologically();
      return;
    }

    try {
      final appData = await _getAppData();
      final userData = await _getUserData(currentUserId);

      final allPostIds = (appData.allPostIds ?? []).reversed.toList();
      final viewedPostIds = userData.viewedPostIds ?? [];

      print('🔹 Total posts dans AppData: ${allPostIds.length}');
      print('🔹 Posts vus par l\'utilisateur: ${viewedPostIds.length}');

      final unseenPostIds = allPostIds
          .where((postId) => !viewedPostIds.contains(postId))
          .toList();

      print('🔹 Posts non vus identifiés: ${unseenPostIds.length}');

      if (unseenPostIds.isEmpty) {
        print('ℹ️ Aucun post non vu à charger');
        setState(() {
          _hasMorePosts = false;
        });
        return;
      }

      final orderedUnseenIds = List<String>.from(unseenPostIds);
      final idsToLoad = orderedUnseenIds.take(_initialLimit).toList();

      final unseenPosts = await _loadPostsByIds(
          idsToLoad,
          limit: _initialLimit,
          isSeen: false
      );

      print('🔹 Posts non vus chargés initialement: ${unseenPosts.length}');

      unseenPosts.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
      _posts = unseenPosts;

      _hasMorePosts = true;

      print('✅ Chargement initial terminé.');
      print('📊 Posts non vus chargés: ${_posts.length}');
      print('📊 Encore des posts non vus: $_hasMorePosts');

    } catch (e, stack) {
      print('❌ Erreur lors du chargement des posts non vus: $e');
      print(stack);
      await _loadMorePostsChronologically();
    }
  }

  Future<void> _loadMoreUnseenPosts(String? currentUserId) async {
    try {
      if (currentUserId == null) {
        await _loadMorePostsChronologically();
        return;
      }

      final appData = await _getAppData();
      final userData = await _getUserData(currentUserId);

      final allPostIds = (appData.allPostIds ?? []).reversed.toList();
      final viewedPostIds = userData.viewedPostIds ?? [];

      final alreadyLoadedPostIds = _posts.map((p) => p.id).where((id) => id != null).cast<String>().toSet();
      final unseenPostIds = allPostIds.where((postId) =>
      !viewedPostIds.contains(postId) &&
          !alreadyLoadedPostIds.contains(postId)
      ).toList();

      print('🔹 Posts non vus restants: ${unseenPostIds.length}');
      print('🔹 Posts déjà chargés: ${alreadyLoadedPostIds.length}');

      List<Post> newPosts = [];

      if (unseenPostIds.isNotEmpty) {
        final idsToLoad = unseenPostIds.take(_loadMoreLimit).toList();
        newPosts = await _loadPostsByIds(idsToLoad, limit: _loadMoreLimit, isSeen: false);
        print('🔹 Posts non vus supplémentaires chargés: ${newPosts.length}');

        _posts.addAll(newPosts);

        _hasMorePosts = true;

        print('✅ Chargement supplémentaire terminé.');
        print('📊 Nouveaux posts non vus: ${newPosts.length}');
        print('📊 Total posts maintenant: ${_posts.length}');
        print('📊 Encore des posts non vus disponibles: $_hasMorePosts');
      } else {
        print('ℹ️ Plus de posts non vus disponibles');
        setState(() {
          _hasMorePosts = false;
        });
      }

    } catch (e, stack) {
      print('❌ Erreur chargement supplémentaire des posts: $e');
      print(stack);
    }
  }

  Future<int> _getRemainingUnseenPostsCount(String currentUserId) async {
    try {
      final appData = await _getAppData();
      final userData = await _getUserData(currentUserId);

      final allPostIds = appData.allPostIds ?? [];
      final viewedPostIds = userData.viewedPostIds ?? [];
      final loadedPostIds = _posts.map((p) => p.id).where((id) => id != null).cast<String>().toSet();

      final remainingUnseenIds = allPostIds.where((postId) =>
      !viewedPostIds.contains(postId) &&
          !loadedPostIds.contains(postId)
      ).toList();

      return remainingUnseenIds.length;
    } catch (e) {
      print('❌ Erreur comptage posts non vus: $e');
      return 0;
    }
  }

  Future<List<Post>> _loadPostsByIds(List<String> postIds, {required int limit, required bool isSeen}) async {
    if (postIds.isEmpty) return [];

    final posts = <Post>[];
    final idsToLoad = postIds.take(limit).toList();

    print('🔹 Chargement de ${idsToLoad.length} posts par ID (isSeen: $isSeen)');

    for (var i = 0; i < idsToLoad.length; i += 10) {
      final batchIds = idsToLoad.skip(i).take(10).where((id) => id.isNotEmpty).toList();

      if (batchIds.isEmpty) continue;

      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('Posts')
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();

        for (var doc in snapshot.docs) {
          try {
            final post = Post.fromJson(doc.data());
            post.id = doc.id;
            post.hasBeenSeenByCurrentUser = isSeen;
            posts.add(post);
          } catch (e) {
            print('⚠️ Erreur parsing post ${doc.id}: $e');
          }
        }
      } catch (e) {
        print('❌ Erreur batch chargement posts: $e');
      }
    }

    posts.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
    return posts;
  }

  Future<void> _loadMorePostsChronologically() async {
    try {
      Query query = FirebaseFirestore.instance.collection('Posts')
          .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
          .where("type", isEqualTo: PostType.POST.name)
          .orderBy("created_at", descending: true)
          .limit(_loadMoreLimit);

      final snapshot = await query.get();

      final newPosts = <Post>[];

      for (var doc in snapshot.docs) {
        try {
          final post = Post.fromJson(doc.data() as Map<String, dynamic>);
          post.hasBeenSeenByCurrentUser = false;
          newPosts.add(post);
        } catch (e) {
          print('⚠️ Erreur parsing post (chargement supplémentaire): ${doc.id} -> $e');
        }
      }

      final existingIds = _posts.map((p) => p.id).toSet();
      final uniqueNewPosts = newPosts.where((post) =>
      post.id != null && !existingIds.contains(post.id)).toList();

      _posts.addAll(uniqueNewPosts);

      print('✅ Chargement chronologique terminé: ${uniqueNewPosts.length} nouveaux posts');

    } catch (e, stack) {
      print('❌ Erreur chargement chronologique: $e');
      print(stack);
    }
  }

  Future<AppDefaultData> _getAppData() async {
    try {
      final appDataRef = FirebaseFirestore.instance.collection('AppData').doc('XgkSxKc10vWsJJ2uBraT');
      final appDataSnapshot = await appDataRef.get();

      if (appDataSnapshot.exists) {
        return AppDefaultData.fromJson(appDataSnapshot.data() ?? {});
      }

      return AppDefaultData();
    } catch (e) {
      print('❌ Erreur récupération AppData: $e');
      return AppDefaultData();
    }
  }

  Future<UserData> _getUserData(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('Users').doc(userId).get();

      if (userDoc.exists) {
        return UserData.fromJson(userDoc.data() as Map<String, dynamic>);
      }

      return UserData(viewedPostIds: []);
    } catch (e) {
      print('❌ Erreur récupération UserData: $e');
      return UserData(viewedPostIds: []);
    }
  }

  Future<void> _recordPostView2(Post post) async {
    final currentUserId = _authProvider.loginUserData.id;
    if (currentUserId == null || post.id == null) return;

    try {
      if ((_authProvider.loginUserData.viewedPostIds?.contains(post.id) ?? false)) {
        print("⚠️ Vue déjà comptée pour le post ${post.id}");
        return;
      }

      final userRef = FirebaseFirestore.instance.collection('Users').doc(currentUserId);


      await userRef.update({
        'viewedPostIds': FieldValue.arrayUnion([post.id]),
      });

      final postRef = FirebaseFirestore.instance.collection('Posts').doc(post.id);
      await postRef.update({
        'vues': FieldValue.increment(1),
        'users_vue_id': FieldValue.arrayUnion([currentUserId]),
      });

      setState(() {
        post.hasBeenSeenByCurrentUser = true;
        post.vues = (post.vues ?? 0) + 1;

        if (post.users_vue_id == null) {
          post.users_vue_id = [];
        }
        post.users_vue_id!.add(currentUserId);

        if (!_authProvider.loginUserData.viewedPostIds!.contains(post.id!)) {
          _authProvider.loginUserData.viewedPostIds!.add(post.id!);
        }
      });

      print('✅ Vue enregistrée pour le post ${post.id}');
    } catch (e) {
      print('❌ Erreur enregistrement vue: $e');
    }
  }
  Future<void> _recordPostView(Post post) async {
    final currentUserId = _authProvider.loginUserData.id;
    if (currentUserId == null || post.id == null) return;

    try {
      if ((_authProvider.loginUserData.viewedPostIds?.contains(post.id) ?? false)) {
        print("⚠️ Vue déjà comptée pour le post ${post.id}");
        return;
      }

      final userRef = FirebaseFirestore.instance.collection('Users').doc(currentUserId);

      // Vérifier si on atteint 1000 posts vus
      final currentViewedIds = _authProvider.loginUserData.viewedPostIds ?? [];
      final willReachLimit = currentViewedIds.length >= 999; // 999 car on va en ajouter 1

      if (willReachLimit) {
        // Vider le tableau quand on atteint 1000
        await userRef.update({
          'viewedPostIds': [post.id], // Réinitialiser avec seulement le nouveau post
        });

        // Mettre à jour localement
        _authProvider.loginUserData.viewedPostIds = [post.id!];
        print("🔄 Tableau viewedPostIds vidé (limite 1000 atteinte)");
      } else {
        // Ajouter normalement le post
        await userRef.update({
          'viewedPostIds': FieldValue.arrayUnion([post.id]),
        });

        // Mettre à jour localement
        if (!_authProvider.loginUserData.viewedPostIds!.contains(post.id!)) {
          _authProvider.loginUserData.viewedPostIds!.add(post.id!);
        }
      }

      // Mettre à jour les stats du post
      final postRef = FirebaseFirestore.instance.collection('Posts').doc(post.id);
      await postRef.update({
        'vues': FieldValue.increment(1),
        'users_vue_id': FieldValue.arrayUnion([currentUserId]),
      });

      setState(() {
        post.hasBeenSeenByCurrentUser = true;
        post.vues = (post.vues ?? 0) + 1;

        if (post.users_vue_id == null) {
          post.users_vue_id = [];
        }
        post.users_vue_id!.add(currentUserId);
      });

      print('✅ Vue enregistrée pour le post ${post.id}');
      print('📊 Total posts vus: ${_authProvider.loginUserData.viewedPostIds?.length ?? 0}');

    } catch (e) {
      print('❌ Erreur enregistrement vue: $e');
    }
  }
  Future<void> _loadAdditionalData() async {
    try {
      final articleResults = await categorieProduitProvider.getArticleBooster(_authProvider.loginUserData.countryData?['countryCode'] ?? 'TG');
      final canalResults = await postProvider.getCanauxHome();

      setState(() {
        articles = articleResults;
        canaux = canalResults;
        articles.shuffle();
        canaux.shuffle();
      });
    } catch (e) {
      print('Error loading additional data: $e');
    }
  }

  Future<void> _loadContentWithStream({bool isInitialLoad = false}) async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('ContentPaies')
          .orderBy('createdAt', descending: true);

      if (_lastContentDocument != null && !isInitialLoad) {
        query = query.startAfterDocument(_lastContentDocument!);
      }

      query = query.limit(isInitialLoad ? _initialLimit : _loadMoreLimit);

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastContentDocument = snapshot.docs.last;
      }

      final newContents = snapshot.docs
          .map((doc) => ContentPaie.fromJson({
        ...?doc.data() as Map<String, dynamic>?,
        'id': doc.id,
      }))
          .toList();

      if (isInitialLoad) {
        _contents = newContents;
      } else {
        final existingIds = _contents.map((c) => c.id).toSet();
        final uniqueNewContents = newContents.where((content) => !existingIds.contains(content.id)).toList();
        _contents.addAll(uniqueNewContents);
      }

      _hasMoreContent = _contents.length < _totalContentCount;
      _createMixedList();

    } catch (e) {
      print('Error loading content: $e');
      setState(() {
        _hasMoreContent = false;
      });
    }
  }

  List<ArticleData> articles = [];
  List<Canal> canaux = [];
  int _totalContentCount = 0;

  void _createMixedList() {
    _mixedItems = [];

    int postIndex = 0;
    int contentIndex = 0;
    int boosterIndex = 0;
    int canalIndex = 0;

    final random = Random();
    int postsSinceLastInsertion = 0;
    bool nextInsertionIsBooster = true;
    bool lastWasContentGrid = false;

    // Variables pour éviter les posts successifs du même utilisateur
    String? lastUserId;
    List<Post> availablePosts = List.from(_posts);
    List<Post> usedPosts = [];

    int maxIterations = (_posts.length + _contents.length) * 2;
    int currentIteration = 0;

    while ((availablePosts.isNotEmpty || contentIndex < _contents.length) &&
        currentIteration < maxIterations) {

      currentIteration++;

      // Insérer des boosters ou canaux selon le rythme
      if (postsSinceLastInsertion >= 2 + random.nextInt(3) && !lastWasContentGrid) {
        if (nextInsertionIsBooster && boosterIndex < articles.length) {
          final nextBoosters = _getNextBoosters(refIndex: boosterIndex);
          if (nextBoosters.isNotEmpty) {
            _mixedItems.add(_MixedItem(
                type: _MixedItemType.booster,
                data: nextBoosters
            ));
            boosterIndex += nextBoosters.length;
            nextInsertionIsBooster = false;
            lastWasContentGrid = false;
            postsSinceLastInsertion = 0;
            continue;
          }
        } else if (!nextInsertionIsBooster && canalIndex < canaux.length) {
          final nextCanaux = _getNextCanaux(refIndex: canalIndex);
          if (nextCanaux.isNotEmpty) {
            _mixedItems.add(_MixedItem(
                type: _MixedItemType.canal,
                data: nextCanaux
            ));
            canalIndex += nextCanaux.length;
            nextInsertionIsBooster = true;
            lastWasContentGrid = false;
            postsSinceLastInsertion = 0;
            continue;
          }
        }
      }

      // Gestion des posts avec vérification de l'utilisateur
      if (availablePosts.isNotEmpty) {
        // Chercher un post d'un utilisateur différent du dernier
        Post? nextPost;
        int foundIndex = -1;

        for (int i = 0; i < availablePosts.length; i++) {
          if (availablePosts[i].user_id != lastUserId) {
            nextPost = availablePosts[i];
            foundIndex = i;
            break;
          }
        }

        // Si aucun post d'utilisateur différent n'est trouvé, prendre le premier disponible
        if (nextPost == null && availablePosts.isNotEmpty) {
          nextPost = availablePosts.first;
          foundIndex = 0;
        }

        if (nextPost != null && foundIndex != -1) {
          _mixedItems.add(_MixedItem(type: _MixedItemType.post, data: nextPost));
          usedPosts.add(nextPost);
          availablePosts.removeAt(foundIndex);
          lastUserId = nextPost.user_id;
          postsSinceLastInsertion++;
          lastWasContentGrid = false;
        }
      }
      else if (contentIndex < _contents.length && !lastWasContentGrid) {
        // Insérer du contenu payant
        final contentsToAdd = [];
        for (int i = 0; i < 2 && contentIndex < _contents.length; i++) {
          contentsToAdd.add(_contents[contentIndex]);
          contentIndex++;
        }
        if (contentsToAdd.isNotEmpty) {
          _mixedItems.add(_MixedItem(type: _MixedItemType.contentGrid, data: contentsToAdd));
          lastWasContentGrid = true;
          postsSinceLastInsertion = 0;
          lastUserId = null; // Réinitialiser pour le prochain post
        }
      }
      else {
        break;
      }
    }

    // Ajouter les éléments restants
    if (boosterIndex < articles.length) {
      final remainingBoosters = _getRemainingBoosters(refIndex: boosterIndex);
      if (remainingBoosters.isNotEmpty) {
        _mixedItems.add(_MixedItem(
            type: _MixedItemType.booster,
            data: remainingBoosters
        ));
      }
    }

    if (canalIndex < canaux.length) {
      final remainingCanaux = _getRemainingCanaux(refIndex: canalIndex);
      if (remainingCanaux.isNotEmpty) {
        _mixedItems.add(_MixedItem(
            type: _MixedItemType.canal,
            data: remainingCanaux
        ));
      }
    }

    print('Mixed list created: ${_mixedItems.length} items');
    print('Posts utilisés: ${usedPosts.length}/${_posts.length}');
    print('Contents: $contentIndex/${_contents.length}');
    print('Boosters: $boosterIndex/${articles.length}, Canaux: $canalIndex/${canaux.length}');

    setState(() {});
  }

  List<ArticleData> _getNextBoosters({required int refIndex}) {
    if (articles.isEmpty || refIndex >= articles.length) return [];
    final endIndex = refIndex + 3 <= articles.length ? refIndex + 3 : articles.length;
    return articles.sublist(refIndex, endIndex);
  }

  List<Canal> _getNextCanaux({required int refIndex}) {
    if (canaux.isEmpty || refIndex >= canaux.length) return [];
    final endIndex = refIndex + 3 <= canaux.length ? refIndex + 3 : canaux.length;
    return canaux.sublist(refIndex, endIndex);
  }

  List<ArticleData> _getRemainingBoosters({required int refIndex}) {
    if (articles.isEmpty || refIndex >= articles.length) return [];
    return articles.sublist(refIndex);
  }

  List<Canal> _getRemainingCanaux({required int refIndex}) {
    if (canaux.isEmpty || refIndex >= canaux.length) return [];
    return canaux.sublist(refIndex);
  }

  Widget _buildBoosterItem(List<ArticleData> articles, double width,double height) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      height: height * 0.32,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Produits boostés 🔥",
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HomeAfroshopPage(title: ''))),
                  child: Row(
                    children: [
                      Text('Boutiques', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryGreen)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, color: primaryGreen, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 8),
              itemCount: articles.length,
              itemBuilder: (context, index) {
                return Container(
                  width: width * 0.4,
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  child: ProductWidget(
                    article: articles[index],
                    width: width * 0.28,
                    height: height * 0.2,
                    isOtherPage: false,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanalItem(List<Canal> canaux, double width,double h) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      height: h * 0.23,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Canaux à suivre 📺",
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CanalListPage(isUserCanals: false))),
                  child: Row(
                    children: [
                      Text('Voir plus', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryGreen)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, color: primaryGreen, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 8),
              itemCount: canaux.length,
              itemBuilder: (context, index) {
                return Container(
                  width: width * 0.3,
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  child: channelWidget(
                    canaux[index],
                    h * 0.28,
                    width * 0.28,
                    context,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore) return;

    final shouldLoadMore = _hasMorePosts || _hasMoreContent;
    if (!shouldLoadMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      await Future.wait([
        if (_hasMorePosts) _loadPostsWithStream(isInitialLoad: false),
      ]);
    } catch (e) {
      print('Error loading more data: $e');
    } finally {
      setState(() {
        _isLoadingMore = false;
        _isNearEnd = false; // Réinitialiser après le chargement
      });
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _posts = [];
      _contents = [];
      _mixedItems = [];
      _isLoading = true;
      _isLoadingMore = false;
      _hasMorePosts = true;
      _hasMoreContent = true;
      _lastContentDocument = null;
      _totalContentCount = 0;
      _postsViewedInSession.clear();
      _visibilityTimers.forEach((key, timer) => timer.cancel());
      _visibilityTimers.clear();
      _isNearEnd = false;
      _lastLoadedItemCount = 0;
    });

    await _loadAdditionalData();
    await _loadInitialData();
    await _loadActiveChroniques();

    print('🔄 Refresh terminé - Données réinitialisées');
  }

  void _handleVisibilityChanged(Post post, VisibilityInfo info) {
    final postId = post.id!;
    _visibilityTimers[postId]?.cancel();

    if (info.visibleFraction > 0.5) {
      _visibilityTimers[postId] = Timer(Duration(milliseconds: 500), () {
        if (mounted && info.visibleFraction > 0.5) {
          _recordPostView(post);
        }
      });
    } else {
      _visibilityTimers.remove(postId);
    }
  }

  Widget _buildPostWithVisibilityDetection(Post post, double width) {
    final hasUserSeenPost = post.hasBeenSeenByCurrentUser;

    return VisibilityDetector(
      key: Key('post-${post.id}'),
      onVisibilityChanged: (VisibilityInfo info) {
        _handleVisibilityChanged(post, info);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
          border: !hasUserSeenPost!
              ? Border.all(color: Colors.green, width: 2)
              : null,
        ),
        child: Stack(
          children: [
            post.type==PostType.CHALLENGEPARTICIPATION.name? LookChallengePostWidget(post: post, height: MediaQuery.of(context).size.height, width: width)
                :HomePostUsersWidget(
              post: post,
              color: _color,
              height: MediaQuery.of(context).size.height * 0.6,
              width: width,
              isDegrade: true,
            ),

            if (!hasUserSeenPost)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fiber_new, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Nouveau',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _navigateToDetails(dynamic item, _MixedItemType type) {
    if (type == _MixedItemType.post) {
      if (item is Post) {
        _recordPostView(item);
      }
      print('Navigate to post details: ${item.id}');
    } else {
      if (item.isSeries) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SeriesEpisodesScreen(series: item)),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ContentDetailScreen(content: item)),
        );
      }
    }
  }

  Widget _buildContentGrid(List<ContentPaie> contents, double width) {
    return Container(
        margin: EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
              child: Text(
                "🪙 Zone VIP 🔥",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            GridView.builder(
              physics: NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.1,
              ),
              itemCount: contents.length,
              itemBuilder: (context, index) {
                final content = contents[index];
                return _buildContentItem(content, width / 2 - 12);
              },
            ),
          ],)
    );
  }

  Widget _buildContentItem(ContentPaie content, double itemWidth) {
    return GestureDetector(
      onTap: () => _navigateToDetails(content, _MixedItemType.content),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                color: Colors.grey[800],
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: content.thumbnailUrl != null && content.thumbnailUrl!.isNotEmpty
                        ? CachedNetworkImage(
                      imageUrl: content.thumbnailUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[800],
                        child: Center(child: CircularProgressIndicator(color: Colors.green)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[800],
                        child: Icon(Icons.error, color: Colors.white),
                      ),
                    )
                        : Center(child: Icon(Icons.videocam, color: Colors.grey[600], size: 30)),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_circle_fill, color: Colors.red, size: 40),
                        SizedBox(height: 4),
                        Text(
                          "Voir",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Row(
                      children: [
                        if (!content.isFree)
                          Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${content.price} F',
                              style: TextStyle(
                                color: Colors.yellow,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        SizedBox(width: 4),
                        if (content.isSeries)
                          Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(Icons.playlist_play, color: Colors.blue, size: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.title,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        content.isSeries ? 'Série' : 'Film',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                      if (content.views != null && content.views! > 0)
                        Row(
                          children: [
                            Icon(Icons.remove_red_eye, color: Colors.white, size: 10),
                            SizedBox(width: 2),
                            Text(
                              content.views!.toString(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerEffect() {
    return ListView.builder(
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          margin: EdgeInsets.only(bottom: 16),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 12),
              Container(
                width: double.infinity,
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              Container(
                width: double.infinity,
                height: 16,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    _changeColor();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.black,
        title: Text(
          'Découvrir',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: _isLoading
          ? _buildShimmerEffect()
          : _hasError
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 50),
            SizedBox(height: 16),
            Text(
              'Erreur de chargement',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshData,
              child: Text('Réessayer'),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _refreshData,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // NOUVEAU : Section des chroniques actives
            if (_groupedChroniques.isNotEmpty || _isLoadingChroniques)
              SliverToBoxAdapter(
                child: _buildChroniquesSection(),
              ),

            // Contenu principal existant
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (context, index) {
                  final item = _mixedItems[index];
                  switch (item.type) {
                    case _MixedItemType.post:
                      return GestureDetector(
                        onTap: () => _navigateToDetails(item.data, _MixedItemType.post),
                        child: _buildPostWithVisibilityDetection(item.data, width),
                      );
                    case _MixedItemType.contentGrid:
                      return _buildContentGrid(
                        (item.data as List<dynamic>).map((e) => e as ContentPaie).toList(),
                        width,
                      );
                    case _MixedItemType.booster:
                      return _buildBoosterItem(articles, width,MediaQuery.of(context).size.height);
                    case _MixedItemType.canal:
                      return _buildCanalItem(canaux, width,MediaQuery.of(context).size.height,);
                    default:
                      return SizedBox.shrink();
                  }
                },
                childCount: _mixedItems.length,
              ),
            ),
            if (_isLoadingMore)
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: Colors.green),
                        SizedBox(height: 10),
                        Text(
                          'Chargement anticipé...',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (!_hasMorePosts && !_hasMoreContent && _mixedItems.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Vous avez vu tous les contenus',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _MixedItemType { post, content, contentGrid, booster, canal }

class _MixedItem {
  final _MixedItemType type;
  final dynamic data;

  _MixedItem({required this.type, required this.data});
}


