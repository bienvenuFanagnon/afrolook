import 'dart:async';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/postDetailsVideoListe.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:afrotok/providers/afroshop/categorie_produits_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../UserServices/ServiceWidget.dart';
import '../../afroshop/marketPlace/acceuil/home_afroshop.dart';
import '../../afroshop/marketPlace/component.dart';
import '../../canaux/listCanal.dart';

class VideoTikTokPage extends StatefulWidget {
  const VideoTikTokPage({Key? key}) : super(key: key);

  @override
  _VideoTikTokPageState createState() => _VideoTikTokPageState();
}

class _VideoTikTokPageState extends State<VideoTikTokPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PageController _pageController = PageController();

  List<dynamic> _mixedItems = [];
  List<Post> _allVideoPosts = [];
  List<ArticleData> _articles = [];
  List<Canal> _canaux = [];

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMoreVideos = true;
  bool _adsDataLoaded = false;

  DocumentSnapshot? _lastDocument;
  final int _pageSize = 5;

  int _currentPage = 0;
  int _adCounter = 0; // Compteur pour alterner les types de publicités
  Timer? _autoPlayTimer;

  late PostProvider _postProvider;
  late CategorieProduitProvider _categorieProduitProvider;

  @override
  void initState() {
    super.initState();
    _postProvider = Provider.of<PostProvider>(context, listen: false);
    _categorieProduitProvider = Provider.of<CategorieProduitProvider>(context, listen: false);

    _loadInitialData();
    _pageController.addListener(_pageListener);
  }

  @override
  void dispose() {
    _pageController.removeListener(_pageListener);
    _pageController.dispose();
    _autoPlayTimer?.cancel();
    super.dispose();
  }

  void _loadInitialData() async {
    try {
      setState(() => _isLoading = true);

      // Charger les données publicitaires en arrière-plan

      // Charger les vidéos initiales
      await _loadInitialVideos();
      _loadAdsData();


    } catch (e) {
      print('❌ Erreur chargement données initiales: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAdsData() async {
    try {
      final articleResults = await _categorieProduitProvider.getArticleBooster();
      final canalResults = await _postProvider.getCanauxHome();

      setState(() {
        _articles = articleResults;
        _canaux = canalResults;
        _adsDataLoaded = true;
      });

      print('🛍️ Données publicitaires chargées: ${_articles.length} articles, ${_canaux.length} canaux');

    } catch (e) {
      print('❌ Erreur chargement données publicitaires: $e');
    }
  }

  void _pageListener() {
    final newPage = _pageController.page?.round() ?? 0;
    if (newPage != _currentPage) {
      setState(() => _currentPage = newPage);
      _startAutoPlayTimer();
      _recordVideoViewIfNeeded(newPage);
      _checkAndLoadMoreVideos(newPage);
    }
  }

  void _startAutoPlayTimer() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer(Duration(seconds: 300), () {
      if (mounted && _currentPage < _mixedItems.length - 1) {
        _pageController.nextPage(
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _recordVideoViewIfNeeded(int pageIndex) {
    if (pageIndex < _mixedItems.length) {
      final item = _mixedItems[pageIndex];
      if (item is Post && !item.hasBeenSeenByCurrentUser!) {
        _recordVideoView(item);
      }
    }
  }

  void _checkAndLoadMoreVideos(int currentPage) {
    if (currentPage >= _mixedItems.length - 2 && _hasMoreVideos && !_isLoadingMore) {
      print('🔄 Déclenchement chargement lot suivant (page $currentPage sur ${_mixedItems.length})');
      _loadMoreVideos();
    }
  }

  Future<void> _loadInitialVideos() async {
    try {
      await _loadVideoBatch(isInitialLoad: true);
      _createMixedListWithAds();

      if (_mixedItems.isNotEmpty) {
        _startAutoPlayTimer();
      }

      print('✅ Chargement initial: ${_allVideoPosts.length} vidéos, ${_mixedItems.length} items mixte');

    } catch (e) {
      print('❌ Erreur chargement vidéos initial: $e');
    }
  }

  Future<void> _loadVideoBatch({bool isInitialLoad = false}) async {
    try {
      final currentUserId = Provider.of<UserAuthProvider>(context, listen: false).loginUserData.id;

      // Récupérer les posts vus par l'utilisateur
      List<String> viewedPostIds = [];
      if (currentUserId != null) {
        final userDoc = await _firestore.collection('Users').doc(currentUserId).get();
        viewedPostIds = List<String>.from(userDoc.data()?['viewedPostIds'] ?? []);
      }

      var query = _firestore
          .collection('Posts')
          .where('dataType', isEqualTo: 'VIDEO')
          .where('type', whereIn: [PostType.POST.name, PostType.CHALLENGEPARTICIPATION.name])
          .orderBy('created_at', descending: true)
          .limit(_pageSize);

      if (!isInitialLoad && _lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;

        final newVideos = snapshot.docs.map((doc) {
          final post = Post.fromJson({'id': doc.id, ...doc.data()});

          // Marquer comme vu ou non vu
          post.hasBeenSeenByCurrentUser = viewedPostIds.contains(post.id);

          return post;
        }).toList();

        if (isInitialLoad) {
          _allVideoPosts = newVideos;
        } else {
          final existingIds = _allVideoPosts.map((p) => p.id).toSet();
          final uniqueNewVideos = newVideos.where((post) => !existingIds.contains(post.id)).toList();
          _allVideoPosts.addAll(uniqueNewVideos);
        }
        // _allVideoPosts.shuffle();
        // _allVideoPosts.shuffle();
        _hasMoreVideos = snapshot.docs.length == _pageSize;

        print('📹 Lot de ${newVideos.length} vidéos chargées (${newVideos.where((p) => !p.hasBeenSeenByCurrentUser!).length} non vues)');

      } else {
        _hasMoreVideos = false;
        print('ℹ️ Aucune vidéo supplémentaire à charger');
      }

    } catch (e) {
      print('❌ Erreur chargement lot vidéos: $e');
      _hasMoreVideos = false;
    }
  }

  // Nouvelle méthode pour créer la liste mixte avec alternance des publicités
  void _createMixedListWithAds() {
    _mixedItems = [];
    int videoCount = 0;
    int videoIndex = 0;
    _adCounter = 0; // Reset du compteur

    while (videoIndex < _allVideoPosts.length) {
      // Ajouter la vidéo
      _mixedItems.add(_allVideoPosts[videoIndex]);
      videoCount++;
      videoIndex++;

      // Insérer UNE SEULE publicité après 4 vidéos
      if (videoCount >= 4 && videoIndex < _allVideoPosts.length) {
        // Alterner entre produit et canal
        final adType = _adCounter % 2 == 0 ? AdType.product : AdType.channel;
        _mixedItems.add(AdItem(type: adType));
        _adCounter++;
        videoCount = 0; // Reset le compteur

        print('🛍️ Publicité ${adType == AdType.product ? 'produit' : 'canal'} insérée après vidéo $videoIndex');
      }
    }

    print('📊 Liste mixte: ${_mixedItems.length} items (${_allVideoPosts.length} vidéos + ${_mixedItems.length - _allVideoPosts.length} publicités)');
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoadingMore || !_hasMoreVideos) return;

    print('🔄 Début chargement lot supplémentaire...');

    try {
      setState(() => _isLoadingMore = true);

      await _loadVideoBatch(isInitialLoad: false);
      _createMixedListWithAds();

      print('✅ Chargement lot terminé: ${_allVideoPosts.length} vidéos totales');

    } catch (e) {
      print('❌ Erreur chargement lot supplémentaire: $e');
    } finally {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _recordVideoView(Post post) async {
    final currentUserId = Provider.of<UserAuthProvider>(context, listen: false).loginUserData.id;
    if (currentUserId == null || post.id == null || post.hasBeenSeenByCurrentUser == true) return;

    try {
      await _firestore.collection('Users').doc(currentUserId).update({
        'viewedPostIds': FieldValue.arrayUnion([post.id]),
      });

      await _firestore.collection('Posts').doc(post.id).update({
        'vues': FieldValue.increment(1),
        'users_vue_id': FieldValue.arrayUnion([currentUserId]),
      });

      setState(() {
        post.hasBeenSeenByCurrentUser = true;
        post.vues = (post.vues ?? 0) + 1;
      });

      print('👁️ Vue enregistrée pour la vidéo ${post.id}');

    } catch (e) {
      print('❌ Erreur enregistrement vue vidéo: $e');
    }
  }

  Future<void> _refreshVideos() async {
    setState(() {
      _mixedItems.clear();
      _allVideoPosts.clear();
      _isLoading = true;
      _hasMoreVideos = true;
      _lastDocument = null;
      _currentPage = 0;
    });

    _autoPlayTimer?.cancel();
    await _loadInitialVideos();
    setState(() => _isLoading = false);
  }

  Widget _buildVideoPageView() {
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: _mixedItems.length + (_isLoadingMore ? 1 : 0),
      onPageChanged: (index) {
        if (index < _mixedItems.length) {
          _onPageChanged(index);
        }
      },
      itemBuilder: (context, index) {
        if (index >= _mixedItems.length) {
          return _buildLoadMorePage();
        }

        final item = _mixedItems[index];
        if (item is Post) {
          return _buildVideoItem(item, index);
        } else if (item is AdItem) {
          return _buildAdItem(item, index);
        } else {
          return Container(color: Colors.black);
        }
      },
    );
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _startAutoPlayTimer();
  }

  Widget _buildVideoItem(Post post, int index) {
    return Stack(
      children: [
        VideoTikTokPageDetails(initialPost: post),

        if (!post.hasBeenSeenByCurrentUser!)
          Positioned(
            top: 50,
            right: 16,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.fiber_new, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Nouveau',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

        Positioned(
          top: 50,
          left: 16,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              post.type == PostType.CHALLENGEPARTICIPATION.name ? '🎯 Challenge' : '📹 Vidéo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        if (_isLoadingMore && index >= _mixedItems.length - 3)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Chargement des vidéos...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Widget amélioré pour afficher les vraies publicités
  Widget _buildAdItem(AdItem ad, int index) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    if (ad.type == AdType.product && _articles.isNotEmpty) {
      return _buildProductsGrid();
    } else if (ad.type == AdType.channel && _canaux.isNotEmpty) {
      return _buildChannelsGrid();
    } else {
      // Fallback si pas de données
      return _buildFallbackAd(ad);
    }
  }

  Widget _buildProductsGrid() {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // En-tête
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "🛍️ Produits Exclusifs",
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => const HomeAfroshopPage(title: ''),
                    ));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Redirection vers la boutique...'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        'Boutiques',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, color: Colors.orange, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Grille des produits
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.8,
              ),
              itemCount: _articles.length,
              itemBuilder: (context, index) {
                return _buildProductItem(_articles[index]);
              },
            ),
          ),

          SizedBox(height: 10),
          Text(
            'Publicité • Afrolook',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildProductItem(ArticleData article) {
    double width =MediaQuery.of(context).size.width;
    double height =MediaQuery.of(context).size.height;
    return Container(
      width: width * 0.4,
      margin: EdgeInsets.symmetric(horizontal: 4),
      child: ProductWidget(
        article: article,
        width: width * 0.28,
        height: height * 0.2,
        isOtherPage: false,
      ),
    );
  }

  Widget _buildChannelsGrid() {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // En-tête
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "📺 Canaux Populaires",
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) => CanalListPage(isUserCanals: false),
                    ));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Redirection vers les canaux...'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        'Voir plus',
                        style: TextStyle(
                          color: Colors.blue,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, color: Colors.blue, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Grille des canaux
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.9,
              ),
              itemCount: _canaux.length,
              itemBuilder: (context, index) {
                return _buildChannelItem(_canaux[index]);
              },
            ),
          ),

          SizedBox(height: 10),
          Text(
            'Publicité • Afrolook',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildChannelItem(Canal canal) {
    double width =MediaQuery.of(context).size.width;
    double height =MediaQuery.of(context).size.height;
    return Container(
      width: width * 0.3,
      margin: EdgeInsets.symmetric(horizontal: 4),
      child: channelWidget(
        canal,
        height * 0.28,
        width * 0.28,
        context,
      ),
    );
  }

  Widget _buildFallbackAd(AdItem ad) {
    return Container(
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            ad.type == AdType.product ? Icons.shopping_bag : Icons.people,
            size: 80,
            color: ad.type == AdType.product ? Colors.orange : Colors.blue,
          ),
          SizedBox(height: 20),
          Text(
            ad.type == AdType.product ? '🛍️ Produits Exclusifs' : '📺 Canaux Populaires',
            style: TextStyle(
              color: ad.type == AdType.product ? Colors.orange : Colors.blue,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          Text(
            ad.type == AdType.product
                ? 'Découvrez nos articles tendance\net boostez votre style'
                : 'Suivez les créateurs les plus\npopulaires de la communauté',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
          SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Redirection vers ${ad.type == AdType.product ? 'la boutique' : 'les canaux'}...'),
                  backgroundColor: ad.type == AdType.product ? Colors.orange : Colors.blue,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ad.type == AdType.product ? Colors.orange : Colors.blue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: Text(
              'Explorer maintenant',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: 20),
          Text(
            'Publicité • Afrolook',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // Les autres méthodes (_buildLoadMorePage, _buildLoadingIndicator, _buildEmptyState, build) restent identiques
  Widget _buildLoadMorePage() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
            ),
            SizedBox(height: 16),
            Text(
              'Chargement des vidéos suivantes...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Lot de $_pageSize vidéos',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
          ),
          SizedBox(height: 16),
          Text(
            'Chargement des premières vidéos...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Lot de $_pageSize vidéos',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam_off,
            size: 80,
            color: Colors.grey[600],
          ),
          SizedBox(height: 16),
          Text(
            'Aucune vidéo disponible',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 18,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Revenez plus tard pour découvrir\n de nouvelles vidéos',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _refreshVideos,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('Actualiser'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 50,
              padding: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.green.withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'AFROLOOK',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Spacer(),
                  if (_mixedItems.isNotEmpty)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_currentPage + 1}/${_mixedItems.length}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_hasMoreVideos)
                          Text(
                            '+',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? _buildLoadingIndicator()
                  : _mixedItems.isEmpty
                  ? _buildEmptyState()
                  : _buildVideoPageView(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshVideos,
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        child: Icon(Icons.refresh),
        mini: true,
        tooltip: 'Recharger les vidéos',
      ),
    );
  }
}

enum AdType { product, channel }

class AdItem {
  final AdType type;

  AdItem({required this.type});
}