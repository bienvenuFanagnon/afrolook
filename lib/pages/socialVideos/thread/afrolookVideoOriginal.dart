import 'dart:async';
import 'dart:math';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/afroshop/marketPlace/acceuil/produit_details.dart';
import 'package:afrotok/pages/canaux/detailsCanal.dart';
import 'package:afrotok/pages/postDetailsVideoListe.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:afrotok/providers/afroshop/categorie_produits_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/chroniqueProvider.dart';
import '../../../providers/contenuPayantProvider.dart';
import '../../../services/postService/mixed_feedvideo_service.dart';
import '../../UserServices/ServiceWidget.dart';
import '../../afroshop/marketPlace/acceuil/home_afroshop.dart';
import '../../afroshop/marketPlace/component.dart';
import '../../canaux/listCanal.dart';

import 'dart:async';
import 'dart:math';
import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/afroshop/marketPlace/acceuil/produit_details.dart';
import 'package:afrotok/pages/canaux/detailsCanal.dart';
import 'package:afrotok/pages/postDetailsVideoListe.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:afrotok/providers/afroshop/categorie_produits_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/chroniqueProvider.dart';
import '../../../providers/contenuPayantProvider.dart';
import '../../../services/postService/mixed_feedvideo_service.dart';
import '../../UserServices/ServiceWidget.dart';
import '../../afroshop/marketPlace/acceuil/home_afroshop.dart';
import '../../canaux/listCanal.dart';

class VideoTikTokPage extends StatefulWidget {
  const VideoTikTokPage({Key? key}) : super(key: key);

  @override
  _VideoTikTokPageState createState() => _VideoTikTokPageState();
}

class _VideoTikTokPageState extends State<VideoTikTokPage> {
  final PageController _pageController = PageController();
  late MixedTikTokVideoService _mixedVideoService;

  List<dynamic> _mixedFeed = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 0;

  // 🔥 TIMER pour publicités automatiques
  Timer? _adAutoScrollTimer;
  final int _adDisplayDuration = 5; // secondes
  int _remainingAdTime = 5;

  // 🔥 CONTENU PUBLICITAIRE
  List<ArticleData> _articles = [];
  List<Canal> _canaux = [];

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _pageController.addListener(_pageListener);
  }

  @override
  void dispose() {
    _pageController.removeListener(_pageListener);
    _pageController.dispose();
    _adAutoScrollTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final categorieProvider = Provider.of<CategorieProduitProvider>(context, listen: false);
      final postProvider = Provider.of<PostProvider>(context, listen: false);
      final chroniqueProvider = Provider.of<ChroniqueProvider>(context, listen: false);
      final contentProvider = Provider.of<ContentProvider>(context, listen: false);

      _mixedVideoService = MixedTikTokVideoService(
        authProvider: authProvider,
        categorieProvider: categorieProvider,
        postProvider: postProvider,
        chroniqueProvider: chroniqueProvider,
        contentProvider: contentProvider,
      );

      await _mixedVideoService.initialize();
      await _loadAdsContent();
      await _loadInitialVideos();

    } catch (e) {
      print('❌ Erreur initialisation services TikTok: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // 🔥 CHARGEMENT DU CONTENU PUBLICITAIRE
  Future<void> _loadAdsContent() async {
    try {
      final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
      final categorieProvider = Provider.of<CategorieProduitProvider>(context, listen: false);
      final postProvider = Provider.of<PostProvider>(context, listen: false);

      // Charger les articles boostés
      final countryCode = authProvider.loginUserData.countryData?['countryCode'] ?? 'TG';
      final articles = await categorieProvider.getArticleBooster(countryCode);

      // Charger les canaux
      final canaux = await postProvider.getCanauxHome();

      setState(() {
        _articles = articles.take(6).toList();
        _canaux = canaux.take(6).toList();
      });

      print('🛍️ Contenu publicitaire chargé: ${_articles.length} articles, ${_canaux.length} canaux');

    } catch (e) {
      print('❌ Erreur chargement contenu publicitaire: $e');
    }
  }

  // 🔥 CHARGEMENT DES VIDÉOS AVEC LE NOUVEAU SERVICE MIXTE
  Future<void> _loadInitialVideos() async {
    try {
      final mixedContent = await _mixedVideoService.loadMixedVideoContent(
        loadMore: false,
      );

      if (mounted) {
        setState(() {
          _mixedFeed = mixedContent;
          _hasMore = _mixedVideoService.hasMore;
        });
      }

      if (_mixedFeed.isNotEmpty) {
        _startAutoPlayTimer();
      }

      print('✅ Chargement initial: ${_mixedFeed.length} éléments mixte');

    } catch (e) {
      print('❌ Erreur chargement vidéos: $e');
    }
  }

  // 🔥 CHARGEMENT SUPPLÉMENTAIRE
  Future<void> _loadMoreVideos() async {
    if (_isLoadingMore || !_mixedVideoService.hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final newContent = await _mixedVideoService.loadMixedVideoContent(
        loadMore: true,
      );

      if (newContent.isNotEmpty && mounted) {
        setState(() {
          _mixedFeed.addAll(newContent);
        });
      } else {
        setState(() => _hasMore = false);
      }

    } catch (e) {
      print('❌ Erreur chargement supplémentaire: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  // 🔥 GESTION DU SCROLL AUTOMATIQUE POUR LES PUBS
  void _pageListener() {
    final newPage = _pageController.page?.round() ?? 0;

    if (newPage != _currentPage) {
      setState(() => _currentPage = newPage);
      _checkAndLoadMore(newPage);
      _handleAutoScrollForAds(newPage);
    }
  }

  void _handleAutoScrollForAds(int pageIndex) {
    // Arrêter tout timer existant
    _adAutoScrollTimer?.cancel();

    if (pageIndex < _mixedFeed.length) {
      final section = _mixedFeed[pageIndex] as VideoContentSection;

      // Vérifier si l'élément actuel est une publicité
      if (section.type == VideoContentType.AD) {
        _startAdCountdown();
      }
    }
  }

  void _startAdCountdown() {
    _remainingAdTime = _adDisplayDuration;
    _adAutoScrollTimer?.cancel();

    _adAutoScrollTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _remainingAdTime--;
        });

        if (_remainingAdTime <= 0) {
          timer.cancel();
          _goToNextVideo();
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _goToNextVideo() {
    if (_currentPage < _mixedFeed.length - 1) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _checkAndLoadMore(int currentPage) {
    if (currentPage >= _mixedFeed.length - 3 && _hasMore && !_isLoadingMore) {
      _loadMoreVideos();
    }
  }

  void _startAutoPlayTimer() {
    _adAutoScrollTimer?.cancel();
  }

  // 🔥 MARQUER UNE VIDÉO COMME VUE
  void _markVideoAsSeen(String videoId) {
    _mixedVideoService.markVideoAsSeen(videoId);
  }

  // 🔥 RAFRAÎCHISSEMENT
  Future<void> _refreshVideos() async {
    setState(() {
      _mixedFeed.clear();
      _isLoading = true;
      _hasMore = true;
      _currentPage = 0;
    });

    _adAutoScrollTimer?.cancel();
    await _mixedVideoService.reset();
    await _loadInitialVideos();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // 🔥 CONSTRUCTION DE LA PAGE
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            _buildHeader(),

            // CONTENU PRINCIPAL
            Expanded(
              child: _isLoading
                  ? _buildLoadingIndicator()
                  : _mixedFeed.isEmpty
                  ? _buildEmptyState()
                  : _buildVideoPageView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
            icon: Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          SizedBox(width: 8),
          Text(
            'AFROLOOK VIDEO',
            style: TextStyle(
              color: Colors.green,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Spacer(),
          if (_mixedFeed.isNotEmpty)
            Text(
              '${_currentPage + 1}/${_mixedFeed.length}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoPageView() {
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: _mixedFeed.length + (_isLoadingMore ? 1 : 0),
      onPageChanged: (index) {
        // Marquer la vidéo comme vue quand elle devient visible
        if (index < _mixedFeed.length) {
          final section = _mixedFeed[index] as VideoContentSection;
          if (section.type == VideoContentType.VIDEO) {
            final post = section.data as Post;
            if (post.id != null) {
              _markVideoAsSeen(post.id!);
            }
          }
        }
      },
      itemBuilder: (context, index) {
        if (index >= _mixedFeed.length) {
          return _buildLoadMorePage();
        }

        final section = _mixedFeed[index] as VideoContentSection;

        if (section.type == VideoContentType.VIDEO) {
          final post = section.data as Post;
          return _buildVideoItem(post, index);
        } else if (section.type == VideoContentType.AD) {
          final adType = section.data as AdType;
          return _buildAdItem(adType, index);
        } else {
          return Container(color: Colors.black);
        }
      },
    );
  }

  Widget _buildVideoItem(Post post, int index) {
    final isCurrentPage = index == _currentPage;

    return Stack(
      children: [
        // VIDÉO PRINCIPALE
        VideoTikTokPageDetails(
          initialPost: post,

          // isCurrentPage: isCurrentPage,
        ),

        // BADGE NOUVEAU
        if (!_isVideoSeen(post))
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

        // INDICATEUR DE TYPE
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

        // INDICATEUR DE SCORE
        if (post.feedScore != null)
          Positioned(
            top: 50,
            right: 16,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getScoreColor(post.feedScore!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${(post.feedScore! * 100).toInt()}%',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 0.7) return Colors.green;
    if (score >= 0.4) return Colors.orange;
    return Colors.red;
  }

  bool _isVideoSeen(Post post) {
    // La logique est gérée par le service MixedTikTokVideoService
    return false;
  }

  // 🔥 WIDGET PUBLICITÉ
  Widget _buildAdItem(AdType adType, int index) {
    final isCurrentPage = index == _currentPage;

    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // EN-TÊTE PUB AVEC COMPTEUR
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  adType == AdType.PRODUCT ? "🛍️ Produits Exclusifs" : "📺 Canaux Populaires",
                  style: TextStyle(
                    color: adType == AdType.PRODUCT ? Colors.orange : Colors.blue,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isCurrentPage) _buildAdCountdown(),
              ],
            ),
          ),

          // CONTENU EN GRILLE
          Expanded(
            child: adType == AdType.PRODUCT
                ? _buildProductsSection()
                : _buildChannelsSection(),
          ),

          // BOUTON SUIVANT
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: _goToNextVideo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: Text('Vidéo Suivante →'),
                ),
                SizedBox(height: 8),
                Text(
                  'La vidéo suivante démarre automatiquement dans $_remainingAdTime secondes',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // LABEL PUB
          Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Publicité • Afrolook',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 SECTION PRODUITS EN GRILLE
  Widget _buildProductsSection() {
    if (_articles.isEmpty) {
      return _buildNoProducts();
    }

    return Column(
      children: [
        // Titre
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              Text(
                "🛍️ Produits Exclusifs",
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "Découvrez nos articles tendance",
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        // Grille de produits
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.75,
            ),
            itemCount: min(_articles.length, 4),
            itemBuilder: (context, index) {
              return _buildProductGridItem(_articles[index]);
            },
          ),
        ),

        // Bouton d'action
        Container(
          padding: EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => const HomeAfroshopPage(title: ''),
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shopping_bag, size: 18),
                SizedBox(width: 8),
                Text('Voir la Boutique'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 🔥 SECTION CANAUX EN GRILLE
  Widget _buildChannelsSection() {
    if (_canaux.isEmpty) {
      return _buildNoChannels();
    }

    return Column(
      children: [
        // Titre
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              Text(
                "📺 Canaux Populaires",
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                "Rejoignez nos créateurs talentueux",
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),

        // Grille de canaux
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            itemCount: min(_canaux.length, 4),
            itemBuilder: (context, index) {
              return _buildChannelGridItem(_canaux[index]);
            },
          ),
        ),

        // Bouton d'action
        Container(
          padding: EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => CanalListPage(isUserCanals: false),
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people, size: 18),
                SizedBox(width: 8),
                Text('Explorer les Canaux'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 🔥 WIDGETS PAS DE CONTENU
  Widget _buildNoProducts() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 60, color: Colors.grey[600]),
          SizedBox(height: 16),
          Text(
            'Aucun produit disponible',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Revenez plus tard pour découvrir\nnos nouvelles collections',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildNoChannels() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 60, color: Colors.grey[600]),
          SizedBox(height: 16),
          Text(
            'Aucun canal disponible',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'De nouveaux créateurs arrivent bientôt',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  // 🔥 WIDGET PRODUIT EN GRILLE
  Widget _buildProductGridItem(ArticleData article) {
    final prixAffichage = article.estEnPromotion
        ? article.prixAvecReduction
        : (article.prix?.toDouble() ?? 0);

    return GestureDetector(
      onTap: () => _onProductTap(article),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image du produit avec badge boosté
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  // Image principale
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                      image: article.images != null && article.images!.isNotEmpty
                          ? DecorationImage(
                        image: NetworkImage(article.images!.first),
                        fit: BoxFit.cover,
                      )
                          : null,
                      color: Colors.grey[800],
                    ),
                    child: article.images == null || article.images!.isEmpty
                        ? Center(
                      child: Icon(
                        Icons.shopping_bag,
                        color: Colors.grey[600],
                        size: 40,
                      ),
                    )
                        : null,
                  ),

                  // Badge boosté
                  if (article.estBoosted)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.rocket_launch, size: 10, color: Colors.white),
                            SizedBox(width: 2),
                            Text(
                              'Boosté',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Badge promotion
                  if (article.estEnPromotion)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '-${article.reduction}%',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Informations du produit
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Nom du produit
                    Text(
                      article.titre?.substring(0, min(article.titre?.length ?? 0, 20)) ?? 'Produit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Prix et condition
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Prix
                        Row(
                          children: [
                            Text(
                              '${prixAffichage.toInt()} FCFA',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            // Ancien prix barré si promotion
                            if (article.estEnPromotion)
                              Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Text(
                                  '${article.prix} FCFA',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 10,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        // Condition et état
                        if (article.condition != null || article.etat != null)
                          Text(
                            '${article.condition ?? ''} ${article.etat ?? ''}'.trim(),
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 9,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),

                    // Bouton rapide et statistiques
                    Row(
                      children: [
                        // Bouton Voir
                        Expanded(
                          child: Container(
                            height: 25,
                            child: ElevatedButton(
                              onPressed: () => _onProductTap(article),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              child: Text(
                                'Voir',
                                style: TextStyle(fontSize: 10),
                              ),
                            ),
                          ),
                        ),

                        // Statistiques
                        if (article.vues != null && article.vues! > 0)
                          Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Row(
                              children: [
                                Icon(Icons.remove_red_eye, size: 10, color: Colors.grey[400]),
                                SizedBox(width: 2),
                                Text(
                                  '${article.vues}',
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
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

  void _onProductTap(ArticleData article) {
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => ProduitDetail(productId: article.id!),
    ));
  }

  // 🔥 WIDGET CANAL EN GRILLE
  Widget _buildChannelGridItem(Canal canal) {
    final abonnesCount = canal.suivi ?? 0;
    final publicationsCount = canal.publication ?? 0;
    final isPrivate = canal.isPrivate;
    final hasSubscription = canal.subscriptionPrice > 0;

    return GestureDetector(
      onTap: () => _onChannelTap(canal),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image de couverture avec avatar
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  // Image de couverture
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                      image: canal.urlCouverture != null && canal.urlCouverture!.isNotEmpty
                          ? DecorationImage(
                        image: NetworkImage(canal.urlCouverture!),
                        fit: BoxFit.cover,
                      )
                          : null,
                      color: Colors.grey[800],
                    ),
                  ),

                  // Avatar du canal au centre
                  Positioned(
                    bottom: -20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.grey[900]!, width: 3),
                          image: canal.urlImage != null && canal.urlImage!.isNotEmpty
                              ? DecorationImage(
                            image: NetworkImage(canal.urlImage!),
                            fit: BoxFit.cover,
                          )
                              : null,
                          color: Colors.grey[700],
                        ),
                        child: canal.urlImage == null || canal.urlImage!.isEmpty
                            ? Icon(Icons.people, color: Colors.grey[400], size: 24)
                            : null,
                      ),
                    ),
                  ),

                  // Badges en haut
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Badge vérifié
                        if (canal.isVerify == true)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified, size: 10, color: Colors.white),
                                SizedBox(width: 2),
                                Text(
                                  'Vérifié',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Badge privé ou payant
                        if (isPrivate)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: hasSubscription ? Colors.purple : Colors.green,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  hasSubscription ? Icons.lock : Icons.private_connectivity,
                                  size: 10,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 2),
                                Text(
                                  hasSubscription ? '${canal.subscriptionPrice.toInt()} FCFA' : 'Privé',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Informations du canal
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.fromLTRB(8, 20, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Nom et description
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nom du canal
                        Text(
                          canal.titre?.substring(0, min(canal.titre?.length ?? 0, 18)) ?? 'Canal',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // Description
                        if (canal.description != null && canal.description!.isNotEmpty)
                          Text(
                            canal.description!.substring(0, min(canal.description!.length, 30)),
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 9,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),

                    // Statistiques et bouton
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Statistiques
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Abonnés
                            Row(
                              children: [
                                Icon(Icons.people, size: 10, color: Colors.grey[400]),
                                SizedBox(width: 4),
                                Text(
                                  _formatCount(abonnesCount),
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),

                            // Publications
                            Row(
                              children: [
                                Icon(Icons.video_library, size: 10, color: Colors.grey[400]),
                                SizedBox(width: 4),
                                Text(
                                  _formatCount(publicationsCount),
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Bouton Voir
                        Container(
                          width: 60,
                          height: 25,
                          child: ElevatedButton(
                            onPressed: () => _onChannelTap(canal),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            child: Text(
                              'Voir',
                              style: TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                      ],
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

  // 🔥 FONCTION POUR FORMATER LES NOMBRES
  String _formatCount(int count) {
    if (count < 1000) return count.toString();
    if (count < 1000000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }

  void _onChannelTap(Canal canal) {
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => CanalDetails(canal: canal),
    ));
  }

  Widget _buildAdCountdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green),
      ),
      child: Text(
        '$_remainingAdTime s',
        style: TextStyle(
          color: Colors.green,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLoadMorePage() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.green),
            SizedBox(height: 16),
            Text(
              'Chargement...',
              style: TextStyle(color: Colors.white),
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
          CircularProgressIndicator(color: Colors.green),
          SizedBox(height: 16),
          Text(
            'Chargement des vidéos...',
            style: TextStyle(color: Colors.white),
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
          Icon(Icons.videocam_off, size: 80, color: Colors.grey[600]),
          SizedBox(height: 16),
          Text(
            'Aucune vidéo disponible',
            style: TextStyle(color: Colors.grey[500], fontSize: 18),
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
}

// import 'dart:async';
// import 'package:afrotok/models/model_data.dart';
// import 'package:afrotok/pages/postDetailsVideoListe.dart';
// import 'package:afrotok/providers/authProvider.dart';
// import 'package:afrotok/providers/postProvider.dart';
// import 'package:afrotok/providers/afroshop/categorie_produits_provider.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
//
// import '../../UserServices/ServiceWidget.dart';
// import '../../afroshop/marketPlace/acceuil/home_afroshop.dart';
// import '../../afroshop/marketPlace/component.dart';
// import '../../canaux/listCanal.dart';
//
// class VideoTikTokPage extends StatefulWidget {
//   const VideoTikTokPage({Key? key}) : super(key: key);
//
//   @override
//   _VideoTikTokPageState createState() => _VideoTikTokPageState();
// }
//
// class _VideoTikTokPageState extends State<VideoTikTokPage> {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final PageController _pageController = PageController();
//
//   List<dynamic> _mixedItems = [];
//   List<Post> _allVideoPosts = [];
//   List<ArticleData> _articles = [];
//   List<Canal> _canaux = [];
//
//   bool _isLoading = true;
//   bool _isLoadingMore = false;
//   bool _hasMoreVideos = true;
//   bool _adsDataLoaded = false;
//
//   DocumentSnapshot? _lastDocument;
//   final int _pageSize = 5;
//
//   int _currentPage = 0;
//   int _adCounter = 0; // Compteur pour alterner les types de publicités
//   Timer? _autoPlayTimer;
//
//   late PostProvider _postProvider;
//   late CategorieProduitProvider _categorieProduitProvider;
//   late UserAuthProvider _authProvider;
//
//   @override
//   void initState() {
//     super.initState();
//     _authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     _postProvider = Provider.of<PostProvider>(context, listen: false);
//     _categorieProduitProvider = Provider.of<CategorieProduitProvider>(context, listen: false);
//
//     _loadInitialData();
//     _pageController.addListener(_pageListener);
//   }
//
//   @override
//   void dispose() {
//     _pageController.removeListener(_pageListener);
//     _pageController.dispose();
//     _autoPlayTimer?.cancel();
//     super.dispose();
//   }
//
//   void _loadInitialData() async {
//     try {
//       setState(() => _isLoading = true);
//
//       // Charger les données publicitaires en arrière-plan
//
//       // Charger les vidéos initiales
//       await _loadInitialVideos();
//       _loadAdsData();
//
//
//     } catch (e) {
//       print('❌ Erreur chargement données initiales: $e');
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }
//
//   Future<void> _loadAdsData() async {
//     try {
//       final articleResults = await _categorieProduitProvider.getArticleBooster(_authProvider.loginUserData.countryData?['countryCode'] ?? 'TG');
//       final canalResults = await _postProvider.getCanauxHome();
//
//       setState(() {
//         _articles = articleResults;
//         _canaux = canalResults;
//         _adsDataLoaded = true;
//       });
//
//       print('🛍️ Données publicitaires chargées: ${_articles.length} articles, ${_canaux.length} canaux');
//
//     } catch (e) {
//       print('❌ Erreur chargement données publicitaires: $e');
//     }
//   }
//
//   void _pageListener() {
//     final newPage = _pageController.page?.round() ?? 0;
//     if (newPage != _currentPage) {
//       setState(() => _currentPage = newPage);
//       _startAutoPlayTimer();
//       _recordVideoViewIfNeeded(newPage);
//       _checkAndLoadMoreVideos(newPage);
//     }
//   }
//
//   void _startAutoPlayTimer() {
//     _autoPlayTimer?.cancel();
//     _autoPlayTimer = Timer(Duration(seconds: 300), () {
//       if (mounted && _currentPage < _mixedItems.length - 1) {
//         _pageController.nextPage(
//           duration: Duration(milliseconds: 300),
//           curve: Curves.easeInOut,
//         );
//       }
//     });
//   }
//
//   void _recordVideoViewIfNeeded(int pageIndex) {
//     if (pageIndex < _mixedItems.length) {
//       final item = _mixedItems[pageIndex];
//       if (item is Post && !item.hasBeenSeenByCurrentUser!) {
//         _recordVideoView(item);
//       }
//     }
//   }
//
//   void _checkAndLoadMoreVideos(int currentPage) {
//     if (currentPage >= _mixedItems.length - 2 && _hasMoreVideos && !_isLoadingMore) {
//       print('🔄 Déclenchement chargement lot suivant (page $currentPage sur ${_mixedItems.length})');
//       _loadMoreVideos();
//     }
//   }
//
//   Future<void> _loadInitialVideos() async {
//     try {
//       await _loadVideoBatch(isInitialLoad: true);
//       _createMixedListWithAds();
//
//       if (_mixedItems.isNotEmpty) {
//         _startAutoPlayTimer();
//       }
//
//       print('✅ Chargement initial: ${_allVideoPosts.length} vidéos, ${_mixedItems.length} items mixte');
//
//     } catch (e) {
//       print('❌ Erreur chargement vidéos initial: $e');
//     }
//   }
//
//   Future<void> _loadVideoBatch({bool isInitialLoad = false}) async {
//     try {
//       final currentUserId = Provider.of<UserAuthProvider>(context, listen: false).loginUserData.id;
//
//       // Récupérer les posts vus par l'utilisateur
//       List<String> viewedPostIds = [];
//       if (currentUserId != null) {
//         final userDoc = await _firestore.collection('Users').doc(currentUserId).get();
//         viewedPostIds = List<String>.from(userDoc.data()?['viewedPostIds'] ?? []);
//       }
//
//       var query = _firestore
//           .collection('Posts')
//           .where('dataType', isEqualTo: 'VIDEO')
//           .where('type', whereIn: [PostType.POST.name, PostType.CHALLENGEPARTICIPATION.name])
//           .orderBy('created_at', descending: true)
//           .limit(_pageSize);
//
//       if (!isInitialLoad && _lastDocument != null) {
//         query = query.startAfterDocument(_lastDocument!);
//       }
//
//       final snapshot = await query.get();
//
//       if (snapshot.docs.isNotEmpty) {
//         _lastDocument = snapshot.docs.last;
//
//         final newVideos = snapshot.docs.map((doc) {
//           final post = Post.fromJson({'id': doc.id, ...doc.data()});
//
//           // Marquer comme vu ou non vu
//           post.hasBeenSeenByCurrentUser = viewedPostIds.contains(post.id);
//
//           return post;
//         }).toList();
//
//         if (isInitialLoad) {
//           _allVideoPosts = newVideos;
//         } else {
//           final existingIds = _allVideoPosts.map((p) => p.id).toSet();
//           final uniqueNewVideos = newVideos.where((post) => !existingIds.contains(post.id)).toList();
//           _allVideoPosts.addAll(uniqueNewVideos);
//         }
//         // _allVideoPosts.shuffle();
//         // _allVideoPosts.shuffle();
//         _hasMoreVideos = snapshot.docs.length == _pageSize;
//
//         print('📹 Lot de ${newVideos.length} vidéos chargées (${newVideos.where((p) => !p.hasBeenSeenByCurrentUser!).length} non vues)');
//
//       } else {
//         _hasMoreVideos = false;
//         print('ℹ️ Aucune vidéo supplémentaire à charger');
//       }
//
//     } catch (e) {
//       print('❌ Erreur chargement lot vidéos: $e');
//       _hasMoreVideos = false;
//     }
//   }
//
//   // Nouvelle méthode pour créer la liste mixte avec alternance des publicités
//   void _createMixedListWithAds() {
//     _mixedItems = [];
//     int videoCount = 0;
//     int videoIndex = 0;
//     _adCounter = 0; // Reset du compteur
//
//     while (videoIndex < _allVideoPosts.length) {
//       // Ajouter la vidéo
//       _mixedItems.add(_allVideoPosts[videoIndex]);
//       videoCount++;
//       videoIndex++;
//
//       // Insérer UNE SEULE publicité après 4 vidéos
//       if (videoCount >= 4 && videoIndex < _allVideoPosts.length) {
//         // Alterner entre produit et canal
//         final adType = _adCounter % 2 == 0 ? AdType.product : AdType.channel;
//         _mixedItems.add(AdItem(type: adType));
//         _adCounter++;
//         videoCount = 0; // Reset le compteur
//
//         print('🛍️ Publicité ${adType == AdType.product ? 'produit' : 'canal'} insérée après vidéo $videoIndex');
//       }
//     }
//
//     print('📊 Liste mixte: ${_mixedItems.length} items (${_allVideoPosts.length} vidéos + ${_mixedItems.length - _allVideoPosts.length} publicités)');
//   }
//
//   Future<void> _loadMoreVideos() async {
//     if (_isLoadingMore || !_hasMoreVideos) return;
//
//     print('🔄 Début chargement lot supplémentaire...');
//
//     try {
//       setState(() => _isLoadingMore = true);
//
//       await _loadVideoBatch(isInitialLoad: false);
//       _createMixedListWithAds();
//
//       print('✅ Chargement lot terminé: ${_allVideoPosts.length} vidéos totales');
//
//     } catch (e) {
//       print('❌ Erreur chargement lot supplémentaire: $e');
//     } finally {
//       setState(() => _isLoadingMore = false);
//     }
//   }
//
//   Future<void> _recordVideoView(Post post) async {
//     final currentUserId = Provider.of<UserAuthProvider>(context, listen: false).loginUserData.id;
//     if (currentUserId == null || post.id == null || post.hasBeenSeenByCurrentUser == true) return;
//
//     try {
//       await _firestore.collection('Users').doc(currentUserId).update({
//         'viewedPostIds': FieldValue.arrayUnion([post.id]),
//       });
//
//       await _firestore.collection('Posts').doc(post.id).update({
//         'vues': FieldValue.increment(1),
//         'users_vue_id': FieldValue.arrayUnion([currentUserId]),
//       });
//
//       setState(() {
//         post.hasBeenSeenByCurrentUser = true;
//         post.vues = (post.vues ?? 0) + 1;
//       });
//
//       print('👁️ Vue enregistrée pour la vidéo ${post.id}');
//
//     } catch (e) {
//       print('❌ Erreur enregistrement vue vidéo: $e');
//     }
//   }
//
//   Future<void> _refreshVideos() async {
//     setState(() {
//       _mixedItems.clear();
//       _allVideoPosts.clear();
//       _isLoading = true;
//       _hasMoreVideos = true;
//       _lastDocument = null;
//       _currentPage = 0;
//     });
//
//     _autoPlayTimer?.cancel();
//     await _loadInitialVideos();
//     setState(() => _isLoading = false);
//   }
//
//   Widget _buildVideoPageView() {
//     return PageView.builder(
//       controller: _pageController,
//       scrollDirection: Axis.vertical,
//       itemCount: _mixedItems.length + (_isLoadingMore ? 1 : 0),
//       onPageChanged: (index) {
//         if (index < _mixedItems.length) {
//           _onPageChanged(index);
//         }
//       },
//       itemBuilder: (context, index) {
//         if (index >= _mixedItems.length) {
//           return _buildLoadMorePage();
//         }
//
//         final item = _mixedItems[index];
//         if (item is Post) {
//           return _buildVideoItem(item, index);
//         } else if (item is AdItem) {
//           return _buildAdItem(item, index);
//         } else {
//           return Container(color: Colors.black);
//         }
//       },
//     );
//   }
//
//   void _onPageChanged(int index) {
//     setState(() => _currentPage = index);
//     _startAutoPlayTimer();
//   }
//
//   Widget _buildVideoItem(Post post, int index) {
//     return Stack(
//       children: [
//         VideoTikTokPageDetails(initialPost: post),
//
//         if (!post.hasBeenSeenByCurrentUser!)
//           Positioned(
//             top: 50,
//             right: 16,
//             child: Container(
//               padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//               decoration: BoxDecoration(
//                 color: Colors.green,
//                 borderRadius: BorderRadius.circular(12),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.3),
//                     blurRadius: 6,
//                     offset: Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: Row(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   Icon(Icons.fiber_new, color: Colors.white, size: 16),
//                   SizedBox(width: 4),
//                   Text(
//                     'Nouveau',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontSize: 12,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//
//         Positioned(
//           top: 50,
//           left: 16,
//           child: Container(
//             padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//             decoration: BoxDecoration(
//               color: Colors.black.withOpacity(0.6),
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: Text(
//               post.type == PostType.CHALLENGEPARTICIPATION.name ? '🎯 Challenge' : '📹 Vidéo',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 10,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//         ),
//
//         if (_isLoadingMore && index >= _mixedItems.length - 3)
//           Positioned(
//             bottom: 20,
//             left: 0,
//             right: 0,
//             child: Center(
//               child: Container(
//                 padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                 decoration: BoxDecoration(
//                   color: Colors.black.withOpacity(0.7),
//                   borderRadius: BorderRadius.circular(20),
//                 ),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     SizedBox(
//                       width: 16,
//                       height: 16,
//                       child: CircularProgressIndicator(
//                         strokeWidth: 2,
//                         valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
//                       ),
//                     ),
//                     SizedBox(width: 8),
//                     Text(
//                       'Chargement des vidéos...',
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontSize: 12,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//       ],
//     );
//   }
//
//   // Widget amélioré pour afficher les vraies publicités
//   Widget _buildAdItem(AdItem ad, int index) {
//     final width = MediaQuery.of(context).size.width;
//     final height = MediaQuery.of(context).size.height;
//
//     if (ad.type == AdType.product && _articles.isNotEmpty) {
//       return _buildProductsGrid();
//     } else if (ad.type == AdType.channel && _canaux.isNotEmpty) {
//       return _buildChannelsGrid();
//     } else {
//       // Fallback si pas de données
//       return _buildFallbackAd(ad);
//     }
//   }
//
//   Widget _buildProductsGrid() {
//     final width = MediaQuery.of(context).size.width;
//     final height = MediaQuery.of(context).size.height;
//
//     return Container(
//       color: Colors.black,
//       child: Column(
//         children: [
//           // En-tête
//           Container(
//             padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   "🛍️ Produits Exclusifs",
//                   style: TextStyle(
//                     color: Colors.orange,
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 GestureDetector(
//                   onTap: () {
//                     Navigator.push(context, MaterialPageRoute(
//                       builder: (context) => const HomeAfroshopPage(title: ''),
//                     ));
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(
//                         content: Text('Redirection vers la boutique...'),
//                         backgroundColor: Colors.orange,
//                       ),
//                     );
//                   },
//                   child: Row(
//                     children: [
//                       Text(
//                         'Boutiques',
//                         style: TextStyle(
//                           color: Colors.orange,
//                           fontSize: 14,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       SizedBox(width: 4),
//                       Icon(Icons.arrow_forward, color: Colors.orange, size: 16),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           // Grille des produits
//           Expanded(
//             child: GridView.builder(
//               padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//               gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: 2,
//                 crossAxisSpacing: 8,
//                 mainAxisSpacing: 8,
//                 childAspectRatio: 0.8,
//               ),
//               itemCount: _articles.length,
//               itemBuilder: (context, index) {
//                 return _buildProductItem(_articles[index]);
//               },
//             ),
//           ),
//
//           SizedBox(height: 10),
//           Text(
//             'Publicité • Afrolook',
//             style: TextStyle(
//               color: Colors.grey[600],
//               fontSize: 12,
//             ),
//           ),
//           SizedBox(height: 10),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildProductItem(ArticleData article) {
//     double width =MediaQuery.of(context).size.width;
//     double height =MediaQuery.of(context).size.height;
//     return Container(
//       width: width * 0.4,
//       margin: EdgeInsets.symmetric(horizontal: 4),
//       child: ProductWidget(
//         article: article,
//         width: width * 0.28,
//         height: height * 0.2,
//         isOtherPage: false,
//       ),
//     );
//   }
//
//   Widget _buildChannelsGrid() {
//     final width = MediaQuery.of(context).size.width;
//     final height = MediaQuery.of(context).size.height;
//
//     return Container(
//       color: Colors.black,
//       child: Column(
//         children: [
//           // En-tête
//           Container(
//             padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text(
//                   "📺 Canaux Populaires",
//                   style: TextStyle(
//                     color: Colors.blue,
//                     fontSize: 18,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 GestureDetector(
//                   onTap: () {
//                     Navigator.push(context, MaterialPageRoute(
//                       builder: (context) => CanalListPage(isUserCanals: false),
//                     ));
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(
//                         content: Text('Redirection vers les canaux...'),
//                         backgroundColor: Colors.blue,
//                       ),
//                     );
//                   },
//                   child: Row(
//                     children: [
//                       Text(
//                         'Voir plus',
//                         style: TextStyle(
//                           color: Colors.blue,
//                           fontSize: 14,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                       SizedBox(width: 4),
//                       Icon(Icons.arrow_forward, color: Colors.blue, size: 16),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//
//           // Grille des canaux
//           Expanded(
//             child: GridView.builder(
//               padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//               gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//                 crossAxisCount: 2,
//                 crossAxisSpacing: 8,
//                 mainAxisSpacing: 8,
//                 childAspectRatio: 0.9,
//               ),
//               itemCount: _canaux.length,
//               itemBuilder: (context, index) {
//                 return _buildChannelItem(_canaux[index]);
//               },
//             ),
//           ),
//
//           SizedBox(height: 10),
//           Text(
//             'Publicité • Afrolook',
//             style: TextStyle(
//               color: Colors.grey[600],
//               fontSize: 12,
//             ),
//           ),
//           SizedBox(height: 10),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildChannelItem(Canal canal) {
//     double width =MediaQuery.of(context).size.width;
//     double height =MediaQuery.of(context).size.height;
//     return Container(
//       width: width * 0.3,
//       margin: EdgeInsets.symmetric(horizontal: 4),
//       child: channelWidget(
//         canal,
//         height * 0.28,
//         width * 0.28,
//         context,
//       ),
//     );
//   }
//
//   Widget _buildFallbackAd(AdItem ad) {
//     return Container(
//       color: Colors.black,
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(
//             ad.type == AdType.product ? Icons.shopping_bag : Icons.people,
//             size: 80,
//             color: ad.type == AdType.product ? Colors.orange : Colors.blue,
//           ),
//           SizedBox(height: 20),
//           Text(
//             ad.type == AdType.product ? '🛍️ Produits Exclusifs' : '📺 Canaux Populaires',
//             style: TextStyle(
//               color: ad.type == AdType.product ? Colors.orange : Colors.blue,
//               fontSize: 22,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           SizedBox(height: 12),
//           Text(
//             ad.type == AdType.product
//                 ? 'Découvrez nos articles tendance\net boostez votre style'
//                 : 'Suivez les créateurs les plus\npopulaires de la communauté',
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               color: Colors.grey[400],
//               fontSize: 16,
//             ),
//           ),
//           SizedBox(height: 30),
//           ElevatedButton(
//             onPressed: () {
//               ScaffoldMessenger.of(context).showSnackBar(
//                 SnackBar(
//                   content: Text('Redirection vers ${ad.type == AdType.product ? 'la boutique' : 'les canaux'}...'),
//                   backgroundColor: ad.type == AdType.product ? Colors.orange : Colors.blue,
//                 ),
//               );
//             },
//             style: ElevatedButton.styleFrom(
//               backgroundColor: ad.type == AdType.product ? Colors.orange : Colors.blue,
//               foregroundColor: Colors.white,
//               padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(25),
//               ),
//             ),
//             child: Text(
//               'Explorer maintenant',
//               style: TextStyle(
//                 fontSize: 16,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//           SizedBox(height: 20),
//           Text(
//             'Publicité • Afrolook',
//             style: TextStyle(
//               color: Colors.grey[600],
//               fontSize: 12,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // Les autres méthodes (_buildLoadMorePage, _buildLoadingIndicator, _buildEmptyState, build) restent identiques
//   Widget _buildLoadMorePage() {
//     return Container(
//       color: Colors.black,
//       child: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             CircularProgressIndicator(
//               valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
//             ),
//             SizedBox(height: 16),
//             Text(
//               'Chargement des vidéos suivantes...',
//               style: TextStyle(
//                 color: Colors.white,
//                 fontSize: 16,
//               ),
//             ),
//             SizedBox(height: 8),
//             Text(
//               'Lot de $_pageSize vidéos',
//               style: TextStyle(
//                 color: Colors.grey[400],
//                 fontSize: 12,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildLoadingIndicator() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           CircularProgressIndicator(
//             valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
//           ),
//           SizedBox(height: 16),
//           Text(
//             'Chargement des premières vidéos...',
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 16,
//             ),
//           ),
//           SizedBox(height: 8),
//           Text(
//             'Lot de $_pageSize vidéos',
//             style: TextStyle(
//               color: Colors.grey[400],
//               fontSize: 12,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(
//             Icons.videocam_off,
//             size: 80,
//             color: Colors.grey[600],
//           ),
//           SizedBox(height: 16),
//           Text(
//             'Aucune vidéo disponible',
//             style: TextStyle(
//               color: Colors.grey[500],
//               fontSize: 18,
//             ),
//           ),
//           SizedBox(height: 8),
//           Text(
//             'Revenez plus tard pour découvrir\n de nouvelles vidéos',
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               color: Colors.grey[400],
//               fontSize: 14,
//             ),
//           ),
//           SizedBox(height: 20),
//           ElevatedButton(
//             onPressed: _refreshVideos,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: Colors.green,
//               foregroundColor: Colors.white,
//             ),
//             child: Text('Actualiser'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.black,
//       body: SafeArea(
//         child: Column(
//           children: [
//             Container(
//               height: 50,
//               padding: EdgeInsets.symmetric(horizontal: 16),
//               decoration: BoxDecoration(
//                 color: Colors.black,
//                 border: Border(
//                   bottom: BorderSide(
//                     color: Colors.green.withOpacity(0.3),
//                     width: 1,
//                   ),
//                 ),
//               ),
//               child: Row(
//                 children: [
//                   IconButton(
//                     icon: Icon(
//                       Icons.arrow_back_ios,
//                       color: Colors.white,
//                       size: 20,
//                     ),
//                     onPressed: () => Navigator.of(context).pop(),
//                   ),
//                   SizedBox(width: 8),
//                   Text(
//                     'AFROLOOK',
//                     style: TextStyle(
//                       color: Colors.green,
//                       fontSize: 20,
//                       fontWeight: FontWeight.bold,
//                       letterSpacing: 1.5,
//                     ),
//                   ),
//                   Spacer(),
//                   if (_mixedItems.isNotEmpty)
//                     Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       children: [
//                         Text(
//                           '${_currentPage + 1}/${_mixedItems.length}',
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 14,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                         if (_hasMoreVideos)
//                           Text(
//                             '+',
//                             style: TextStyle(
//                               color: Colors.green,
//                               fontSize: 12,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                       ],
//                     ),
//                 ],
//               ),
//             ),
//             Expanded(
//               child: _isLoading
//                   ? _buildLoadingIndicator()
//                   : _mixedItems.isEmpty
//                   ? _buildEmptyState()
//                   : _buildVideoPageView(),
//             ),
//           ],
//         ),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: _refreshVideos,
//         backgroundColor: Colors.green,
//         foregroundColor: Colors.white,
//         child: Icon(Icons.refresh),
//         mini: true,
//         tooltip: 'Recharger les vidéos',
//       ),
//     );
//   }
// }
//
// enum AdType { product, channel }
//
// class AdItem {
//   final AdType type;
//
//   AdItem({required this.type});
// }