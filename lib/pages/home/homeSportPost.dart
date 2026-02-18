import 'dart:async';
import 'dart:math';
import 'package:afrotok/pages/canaux/listCanal.dart';
import 'package:afrotok/pages/challenge/postChallengeWidget.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';
import 'package:afrotok/pages/home/unitePostPage/chronique_section.dart';
import 'package:flutter/material.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/providers/userProvider.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';

import 'package:skeletonizer/skeletonizer.dart';

import '../UserServices/ServiceWidget.dart';

import '../afroshop/marketPlace/acceuil/home_afroshop.dart';
import '../afroshop/marketPlace/component.dart';

import '../chronique/chroniqueform.dart';
import '../component/showUserDetails.dart';
import '../../providers/afroshop/authAfroshopProvider.dart';
import '../../providers/afroshop/categorie_produits_provider.dart';
import '../../providers/authProvider.dart';
import 'package:shimmer/shimmer.dart';
import '../listeUserLikepage.dart';
import '../pub/banner_ad_widget.dart';
import '../userPosts/postWidgets/postWidgetPage.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../../providers/mixed_feed_service_provider.dart';
import 'dart:typed_data';


// Constantes de couleur
const Color primaryGreen = Color(0xFF25D366);
const Color darkBackground = Colors.black;
const Color lightBackground = Color(0xFF1E1E1E);
const Color textColor = Colors.white;
const Color accentYellow = Color(0xFFFFD700);

// Types disponibles basés sur votre enum TabBarType
const List<String> availablePostTypes = [
  'ACTUALITES',
  'LOOKS',
  'SPORT',
  'EVENEMENT',
  'OFFRES',
  'GAMER'
];

class HomeSportPostPage extends StatefulWidget {
  final String type;
  final String? sortType;

  HomeSportPostPage({super.key, required this.type, this.sortType});

  @override
  State<HomeSportPostPage> createState() => _HomeSportPostPageState();
}

class _HomeSportPostPageState extends State<HomeSportPostPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // Providers
  late UserAuthProvider authProvider;
  late UserShopAuthProvider authProviderShop;
  late CategorieProduitProvider categorieProduitProvider;
  late UserProvider userProvider;
  late PostProvider postProvider;
  late MixedFeedServiceProvider mixedFeedProvider;

  // Contrôleurs
  final ScrollController _scrollController = ScrollController();
  final Random _random = Random();

  // Variables d'état pour les posts
  List<Post> _posts = [];
  bool _isLoadingPosts = true;
  bool _hasErrorPosts = false;
  bool _isLoadingMorePosts = false;
  bool _hasMorePosts = true;
  bool _isLoadingBackground = false;

  // Système hybride de chargement
  DocumentSnapshot? _lastCountryDocument;
  DocumentSnapshot? _lastAllDocument;
  DocumentSnapshot? _lastOtherDocument;
  Set<String> _loadedPostIds = Set();
  int _totalPostsLoaded = 0;
  int _backgroundPostsLoaded = 0;
  final int _initialLimit = 3;
  final int _backgroundLoadLimit = 5;
  final int _manualLoadLimit = 5;
  final int _maxBackgroundPosts = 20;
  final int _maxTotalPosts = 1000;
  Timer? _backgroundLoadTimer;
  bool _useBackgroundLoading = true;

  // Filtrage par pays
  String? _selectedCountryCode;
  // String _currentFilter = 'MIXED';
  String _currentFilter = 'ALL';
  bool _isFirstLoad = true;

  // Filtrage par type (le paramètre principal de cette page)
  String _selectedPostType = 'ACTUALITES';

  // Données supplémentaires
  List<ArticleData> _articles = [];
  bool _isLoadingArticles = false;

  List<Canal> _canaux = [];
  bool _isLoadingCanaux = false;

  List<UserData> _suggestedUsers = [];
  bool _isLoadingSuggestedUsers = false;

  // Chroniques
  List<Chronique> _chroniques = [];
  bool _isLoadingChroniques = false;
  Map<String, List<Chronique>> _groupedChroniques = {};
  final Map<String, Uint8List> _videoThumbnails = {};
  final Map<String, bool> _userVerificationStatus = {};
  final Map<String, UserData> _userDataCache = {};

  // Gestion de visibilité
  final Map<String, Timer> _visibilityTimers = {};
  final Map<String, bool> _postsViewedInSession = {};

  // Animation
  late AnimationController _starController;
  late AnimationController _unlikeController;

  // Utilitaires
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentTitleIndex = 0;
  Timer? _titleTimer;

  void _startTitleAnimation() {
    _titleTimer?.cancel();
    _titleTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      if (mounted && _selectedPostType == 'SPORT') {
        setState(() {
          _currentTitleIndex = (_currentTitleIndex + 1) % _sportTitles.length;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _startTitleAnimation();
    _sportTitles.shuffle();

    // Initialiser le type de post
    _selectedPostType = widget.type.toUpperCase();

    // Initialisation des providers
    authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    authProviderShop = Provider.of<UserShopAuthProvider>(context, listen: false);
    categorieProduitProvider = Provider.of<CategorieProduitProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    postProvider = Provider.of<PostProvider>(context, listen: false);
    mixedFeedProvider = Provider.of<MixedFeedServiceProvider>(context, listen: false);

    // Configuration initiale
    _initializeAnimations();
    _setupScrollController();
    _setupLifecycleObservers();
    _initializeData();
  }
// Ajoutez cette méthode pour les titres sportifs dynamiques
  String _getSportTitle() {
    if (_selectedPostType != 'SPORT') return _selectedPostType;

    List<String> sportTitles = [
      '⚽ Actualité du football',
      '🏆 Ligue des Champions',
      '⚡ Transferts et rumeurs',
      '⭐ Mbappé, Messi, Ronaldo...',
      '🌍 CAN 2024',
      '🇫🇷 Équipe de France',
      '🏟️ Résultats en direct',
      '🎯 Tops buteurs',
    ];
    return sportTitles[_random.nextInt(sportTitles.length)];
  }

// Ajoutez cette méthode pour les sous-titres
  String _getSportSubtitle() {
    if (_selectedPostType != 'SPORT') return _getFilterDescription();

    List<String> sportSubtitles = [
      'Toute l\'actu foot en direct',
      'Analyses et débats sportifs',
      'Les stars du ballon rond',
      'Matchs et compétitions',
      'Mercato et transferts',
      'Exclu interviews',
    ];
    return sportSubtitles[_random.nextInt(sportSubtitles.length)];
  }

// Ajoutez cette méthode pour les hashtags
  Widget _buildSportTags() {
    List<String> tags = [
      '#Football', '#LDC', '#Ligue1', '#PremierLeague',
      '#Liga', '#Basketball', '#NBA', '#Handball',
      '#LigueAfricaine', '#LigueEuropa', '#ChampionsLeague',
    ];

    // Mélanger pour variété
    tags.shuffle();
    tags = tags.take(6).toList(); // Garder 6 tags

    return Container(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tags.length,
        itemBuilder: (context, index) {
          return Container(
            margin: EdgeInsets.only(right: 8),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Text(
              tags[index],
              style: TextStyle(color: Colors.green, fontSize: 11),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _titleTimer?.cancel();
    _scrollController.dispose();
    _visibilityTimers.forEach((key, timer) => timer.cancel());
    _backgroundLoadTimer?.cancel();
    _starController.dispose();
    _unlikeController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setupScrollController() {
    _scrollController.addListener(_scrollListener);
  }

  void _setupLifecycleObservers() {
    WidgetsBinding.instance.addObserver(this);
    SystemChannels.lifecycle.setMessageHandler((message) {
      _handleAppLifecycle(message);
      return Future.value(message);
    });
  }

  void _initializeAnimations() {
    _starController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _unlikeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
  }

  void _initializeData() async {
    // 1. Détecter le pays de l'utilisateur
    _selectedCountryCode = authProvider.loginUserData.countryData?['countryCode']?.toUpperCase();
    print('Pays utilisateur détecté: ${_selectedCountryCode}');
    print('Type de post sélectionné: $_selectedPostType');

    // 2. Par défaut: mode "Mix" pour variété
    // _currentFilter = 'MIXED';
    _currentFilter = 'ALL';
    _isFirstLoad = true;
    _useBackgroundLoading = true;
    _backgroundPostsLoaded = 0;

    // 3. Réinitialiser et charger les posts initiaux
    _resetPagination();
    await _loadInitialPosts();

    // 4. Démarrer le chargement background
    _startBackgroundLoading();

    // 5. Charger les autres données EN PARALLÈLE
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllAdditionalDataInParallel();
    });
  }

  void _resetPagination() {
    _posts.clear();
    _loadedPostIds.clear();
    _lastCountryDocument = null;
    _lastAllDocument = null;
    _lastOtherDocument = null;
    _totalPostsLoaded = 0;
    _backgroundPostsLoaded = 0;
    _hasMorePosts = true;
    _isLoadingMorePosts = false;
    _isLoadingBackground = false;
  }

  // ===========================================================================
  // SYSTÈME HYBRIDE DE CHARGEMENT
  // ===========================================================================

  void _startBackgroundLoading() {
    if (!_useBackgroundLoading) return;

    _backgroundLoadTimer?.cancel();

    print('🚀 Démarrage du chargement background pour $_selectedPostType');

    _backgroundLoadTimer = Timer.periodic(Duration(seconds: 2), (timer) async {
      if (_useBackgroundLoading &&
          !_isLoadingBackground &&
          !_isLoadingMorePosts &&
          _hasMorePosts &&
          _backgroundPostsLoaded < _maxBackgroundPosts &&
          _totalPostsLoaded < _maxTotalPosts &&
          !_isUserScrolling()) {
        await _loadBackgroundPosts();
      }

      if (_backgroundPostsLoaded >= _maxBackgroundPosts ||
          !_hasMorePosts ||
          !_useBackgroundLoading) {
        print('⏹️ Arrêt du chargement background');
        timer.cancel();
        _useBackgroundLoading = false;
      }
    });
  }

  bool _isUserScrolling() {
    // Vérifier si le controller est attaché avant d'accéder à position
    if (!_scrollController.hasClients) {
      return false; // Pas encore attaché, donc l'utilisateur ne scroll pas
    }

    try {
      return _scrollController.position.isScrollingNotifier.value;
    } catch (e) {
      print('Erreur isUserScrolling: $e');
      return false;
    }
  }

  Future<void> _loadBackgroundPosts() async {
    if (_isLoadingBackground ||
        !_hasMorePosts ||
        _backgroundPostsLoaded >= _maxBackgroundPosts ||
        _totalPostsLoaded >= _maxTotalPosts) {
      return;
    }

    print('🔄 Chargement background...');

    setState(() {
      _isLoadingBackground = true;
    });

    try {
      Set<String> loadedIds = Set.from(_loadedPostIds);
      List<Post> newPosts = [];

      await _loadMorePostsByFilter(loadedIds, newPosts, _backgroundLoadLimit);

      if (newPosts.isNotEmpty) {
        setState(() {
          _posts.addAll(newPosts);
          _loadedPostIds.addAll(newPosts.map((p) => p.id!));
          _totalPostsLoaded += newPosts.length;
          _backgroundPostsLoaded += newPosts.length;
        });

        print('✅ ${newPosts.length} posts chargés en background');
      }

      _hasMorePosts = newPosts.length >= (_backgroundLoadLimit ~/ 2);

      if (_backgroundPostsLoaded >= _maxBackgroundPosts) {
        _useBackgroundLoading = false;
      }

    } catch (e) {
      print('❌ Erreur chargement background: $e');
    } finally {
      setState(() {
        _isLoadingBackground = false;
      });
    }
  }

  // ===========================================================================
  // FILTRES PAR PAYS
  // ===========================================================================

  void _showCountryFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final TextEditingController searchController = TextEditingController();
        String searchQuery = '';

        return StatefulBuilder(
          builder: (context, setModalState) {
            void updateSearch(String query) {
              searchQuery = query.toLowerCase();
              setModalState(() {});
            }

            List<AfricanCountry> filteredCountries = AfricanCountry.allCountries
                .where((country) {
              if (searchQuery.isEmpty) return true;
              return country.name.toLowerCase().contains(searchQuery) ||
                  country.code.toLowerCase().contains(searchQuery) ||
                  country.name?.toLowerCase().contains(searchQuery) == true;
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: darkBackground,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    height: 4,
                    width: 40,
                    margin: EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: 12),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '🌍 Filtrer par pays',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey[400], size: 24),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[700]!),
                      ),
                      child: Row(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(left: 16),
                            child: Icon(Icons.search, color: Colors.grey[500], size: 20),
                          ),
                          Expanded(
                            child: TextField(
                              controller: searchController,
                              onChanged: updateSearch,
                              style: TextStyle(color: Colors.white, fontSize: 15),
                              decoration: InputDecoration(
                                hintText: 'Rechercher un pays...',
                                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ),
                          if (searchController.text.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.clear, size: 18, color: Colors.grey[500]),
                              onPressed: () {
                                searchController.clear();
                                updateSearch('');
                              },
                            ),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildQuickFilterOption(
                            icon: Icons.public,
                            label: 'Tous',
                            isSelected: _currentFilter == 'ALL',
                            color: primaryGreen,
                            onTap: () async {
                              Navigator.pop(context);
                              await _applyFilter(filterType: 'ALL', countryCode: null);
                            },
                          ),
                          SizedBox(width: 8),

                          if (_selectedCountryCode != null)
                            _buildQuickFilterOption(
                              icon: null,
                              label: 'Mon pays',
                              flag: _getCountryFlag(_selectedCountryCode!),
                              isSelected: _currentFilter == 'COUNTRY',
                              color: Colors.blue,
                              onTap: () async {
                                Navigator.pop(context);
                                await _applyFilter(filterType: 'COUNTRY', countryCode: _selectedCountryCode);
                              },
                            ),

                          if (_selectedCountryCode != null) SizedBox(width: 8),

                          if (_selectedCountryCode != null)
                            _buildQuickFilterOption(
                              icon: Icons.blender,
                              label: 'Mix',
                              isSelected: _currentFilter == 'MIXED',
                              color: Colors.purple,
                              onTap: () async {
                                Navigator.pop(context);
                                await _applyFilter(filterType: 'MIXED', countryCode: _selectedCountryCode);
                              },
                            ),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(color: Colors.grey[800], thickness: 1),
                  ),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          'Choisir un pays',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Spacer(),
                        Text(
                          '${filteredCountries.length} pays',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),

                  Expanded(
                    child: _buildCountryList(filteredCountries, searchQuery),
                  ),

                  Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Fermer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQuickFilterOption({
    IconData? icon,
    required String label,
    String? flag,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey[900],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (flag != null)
              Text(flag, style: TextStyle(fontSize: 16))
            else if (icon != null)
              Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey[400]),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[300],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (isSelected) SizedBox(width: 4),
            if (isSelected)
              Icon(Icons.check, size: 14, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryList(List<AfricanCountry> countries, String searchQuery) {
    if (countries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, color: Colors.grey[600], size: 48),
            SizedBox(height: 12),
            Text(
              searchQuery.isEmpty ? 'Chargement...' : 'Aucun pays trouvé',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 16,
              ),
            ),
            if (searchQuery.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Essayez une autre recherche',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: countries.length,
      itemBuilder: (context, index) {
        final country = countries[index];
        final isCurrentCountry = _selectedCountryCode?.toUpperCase() == country.code.toUpperCase();
        final isSelected = _currentFilter == 'CUSTOM' &&
            _selectedCountryCode?.toUpperCase() == country.code.toUpperCase();

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                Navigator.pop(context);
                await _applyFilter(
                  filterType: 'CUSTOM',
                  countryCode: country.code.toUpperCase(),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.orange.withOpacity(0.2) : Colors.grey[900],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? Colors.orange : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          country.flag,
                          style: TextStyle(fontSize: 20),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  country.name,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isCurrentCountry)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Votre pays',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 2),
                          Text(
                            country.code.toUpperCase(),
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: Colors.orange, size: 22),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _getCountryFlag(String countryCode) {
    try {
      final country = AfricanCountry.allCountries.firstWhere(
            (c) => c.code.toUpperCase() == countryCode.toUpperCase(),
        orElse: () => AfricanCountry(
          code: countryCode,
          name: countryCode,
          flag: '🏳️',
        ),
      );
      return country.flag;
    } catch (e) {
      return '🏳️';
    }
  }

  Future<void> _applyFilter({
    required String filterType,
    String? countryCode,
  }) async
  {
    _backgroundLoadTimer?.cancel();

    setState(() {
      _currentFilter = filterType;
      if (countryCode != null) {
        _selectedCountryCode = countryCode.toUpperCase();
      }
      _isLoadingPosts = true;
      _isFirstLoad = true;
      _useBackgroundLoading = true;
      _backgroundPostsLoaded = 0;
    });

    _resetPagination();
    await _loadInitialPosts();

    _startBackgroundLoading();

    setState(() {
      _isLoadingPosts = false;
    });

    print('✅ Filtre appliqué: $_currentFilter - Pays: $_selectedCountryCode - Type: $_selectedPostType');
  }
  void _showTypeFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final TextEditingController searchController = TextEditingController();
            String searchQuery = '';

            void updateSearch(String query) {
              searchQuery = query.toLowerCase();
              setModalState(() {});
            }

            // Filtrer les types selon la recherche
            List<String> filteredTypes = availablePostTypes
                .where((type) => searchQuery.isEmpty ||
                type.toLowerCase().contains(searchQuery))
                .toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: darkBackground,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Poignée
                  Container(
                    height: 4,
                    width: 40,
                    margin: EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: 12),

                  // Titre et bouton fermer
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '📝 Choisir un type',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey[400], size: 24),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  // Barre de recherche
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[700]!),
                      ),
                      child: Row(
                        children: [
                          Padding(
                            padding: EdgeInsets.only(left: 16),
                            child: Icon(Icons.search, color: Colors.grey[500], size: 20),
                          ),
                          Expanded(
                            child: TextField(
                              controller: searchController,
                              onChanged: updateSearch,
                              style: TextStyle(color: Colors.white, fontSize: 15),
                              decoration: InputDecoration(
                                hintText: 'Rechercher un type...',
                                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                            ),
                          ),
                          if (searchController.text.isNotEmpty)
                            IconButton(
                              icon: Icon(Icons.clear, size: 18, color: Colors.grey[500]),
                              onPressed: () {
                                searchController.clear();
                                updateSearch('');
                              },
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Titre liste
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          'Types disponibles',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Spacer(),
                        Text(
                          '${filteredTypes.length} types',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),

                  // Liste des types
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: filteredTypes.length,
                      itemBuilder: (context, index) {
                        final type = filteredTypes[index];
                        final isSelected = _selectedPostType == type;

                        return _buildTypeOption(
                          type: type,
                          isSelected: isSelected,
                          onTap: () => _applyTypeFilter(type),
                        );
                      },
                    ),
                  ),

                  // Bouton fermer
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Fermer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  Future<void> _applyTypeFilter(String newType) async {
    // Arrêter le chargement background pendant le changement de filtre
    _backgroundLoadTimer?.cancel();

    print('🔄 Changement de type: $_selectedPostType -> $newType');

    setState(() {
      _selectedPostType = newType;
      _isLoadingPosts = true;
      _isFirstLoad = true;
      _useBackgroundLoading = true;
      _backgroundPostsLoaded = 0;
    });

    // Réinitialiser la pagination
    _resetPagination();

    // Charger les posts initiaux avec le nouveau type
    await _loadInitialPosts();

    // Redémarrer le chargement background
    _startBackgroundLoading();

    setState(() {
      _isLoadingPosts = false;
    });

    print('✅ Type changé: $newType');
  }
  Widget _buildTypeOption({
    required String type,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pop(context); // Fermer le modal
            onTap(); // Appliquer le filtre
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? Colors.purple.withOpacity(0.2) : Colors.grey[900],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? Colors.purple : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Icon(
                      _getTypeIcon(type),
                      color: isSelected ? Colors.purple : Colors.grey[400],
                      size: 22,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[300],
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _getTypeDescription(type),
                        style: TextStyle(
                          color: isSelected ? Colors.grey[300] : Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: Colors.purple, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getTypeDescription(String type) {
    switch (type.toUpperCase()) {
      case 'ACTUALITES':
        return 'Actualités et informations';
      case 'LOOKS':
        return 'Mode, style et looks';
      case 'SPORT':
        return 'Sports et compétitions';
      case 'EVENEMENT':
        return 'Événements et manifestations';
      case 'OFFRES':
        return 'Offres et promotions';
      case 'GAMER':
        return 'Jeux vidéo et e-sport';
      default:
        return 'Contenu de type $type';
    }
  }
  // ===========================================================================
  // CHARGEMENT DES POSTS AVEC FILTRES TYPE + PAYS
  // ===========================================================================

  Future<void> _loadInitialPosts() async {
    try {
      setState(() {
        _isLoadingPosts = true;
        _hasErrorPosts = false;
      });

      Set<String> loadedIds = Set();
      List<Post> newPosts = [];

      int limit = _initialLimit;

      switch (_currentFilter) {
        case 'ALL':
          await _loadPostsWithTypeAndCountry(
            loadedIds,
            newPosts,
            postType: _selectedPostType,
            countryCode: null, // Tous les pays
            isInitialLoad: true,
            limit: limit,
          );
          break;

        case 'COUNTRY':
          if (_selectedCountryCode != null) {
            await _loadPostsWithTypeAndCountry(
              loadedIds,
              newPosts,
              postType: _selectedPostType,
              countryCode: _selectedCountryCode,
              isInitialLoad: true,
              limit: limit,
            );
          }
          break;

        case 'MIXED':
          if (_selectedCountryCode != null) {
            await _loadMixedPostsWithType(loadedIds, newPosts, limit);
          }
          break;

        case 'CUSTOM':
          if (_selectedCountryCode != null) {
            await _loadPostsWithTypeAndCountry(
              loadedIds,
              newPosts,
              postType: _selectedPostType,
              countryCode: _selectedCountryCode,
              isInitialLoad: true,
              limit: limit,
            );
          }
          break;
      }

      setState(() {
        _posts = newPosts;
        _loadedPostIds.addAll(loadedIds);
        _totalPostsLoaded = newPosts.length;
        _isFirstLoad = false;
      });

      print('✅ ${newPosts.length} posts chargés avec filtre: $_currentFilter - Type: $_selectedPostType');

    } catch (e) {
      print('❌ Erreur chargement posts: $e');
      setState(() {
        _hasErrorPosts = true;
      });
    } finally {
      setState(() {
        _isLoadingPosts = false;
      });
    }
  }

  // Méthode principale pour charger les posts avec type et pays
  Future<void> _loadPostsWithTypeAndCountry(
      Set<String> loadedIds,
      List<Post> newPosts, {
        required String postType,
        String? countryCode,
        bool isInitialLoad = false,
        int limit = 5,
      }) async {
    if (limit <= 0) return;

    try {
      print('🎯 Chargement posts - Type: $postType - Pays: ${countryCode ?? "ALL"}');

      Query query = _firestore.collection('Posts');

      // 1. Filtrer par TYPE (requête Firebase)
      query = query.where("typeTabbar", isEqualTo: postType);

      // 2. Filtrer par PAYS si spécifié
      if (countryCode != null) {
        // Essayer différents noms de champs pour le pays
        try {
          query = query.where("available_countries", arrayContains: countryCode);
        } catch (e) {
          try {
            query = query.where("availableCountries", arrayContains: countryCode);
          } catch (e2) {
            query = query.where("country", isEqualTo: countryCode);
          }
        }
      }
      else {
        // Sinon, charger les posts disponibles dans tous les pays
        // try {
        //   query = query.where("available_countries", arrayContains: "ALL");
        // } catch (e) {
        //   try {
        //     query = query.where("availableCountries", arrayContains: "ALL");
        //   } catch (e2) {
        //     query = query.where("is_available_in_all_countries", isEqualTo: true);
        //   }
        // }
      }

      // 3. Trier par date
      query = query.orderBy("created_at", descending: true);

      // 4. Pagination
      if (!isInitialLoad && _lastCountryDocument != null) {
        query = query.startAfterDocument(_lastCountryDocument!);
      }

      // 5. Limite
      query = query.limit(limit * 2);

      final snapshot = await query.get();
      printVm('snapshot.docs.length: ${snapshot.docs.length}');

      if (snapshot.docs.isNotEmpty) {
        _lastCountryDocument = snapshot.docs.last;
      }

      int added = 0;
      snapshot.docs.shuffle();
      for (var doc in snapshot.docs) {
        if (added >= limit) break;

        try {
          final post = Post.fromJson(doc.data() as Map<String, dynamic>);
          post.id = doc.id;

          if (!loadedIds.contains(post.id) && !_loadedPostIds.contains(post.id)) {
            post.hasBeenSeenByCurrentUser = _checkIfPostSeen(post);
            newPosts.add(post);
            loadedIds.add(post.id!);
            added++;
          }
        } catch (e) {
          print('Erreur parsing post: $e');
        }
      }
      newPosts.shuffle();

      print('✅ $added posts chargés (Type: $postType, Pays: ${countryCode ?? "ALL"})');

    } catch (e) {
      print('❌ Erreur chargement posts: $e');
    }
  }
  Widget _buildAdBanner({required String key}) {
    return SizedBox.shrink();
    // return Container(
    //   key: ValueKey(key),
    //   margin: EdgeInsets.symmetric(vertical: 16),
    //   decoration: BoxDecoration(
    //     color: Colors.grey[100],
    //     borderRadius: BorderRadius.circular(12),
    //     border: Border.all(color: Colors.grey[300]!),
    //   ),
    //   child: BannerAdWidget(
    //     onAdLoaded: () {
    //       print('✅ Bannière Afrolook chargée: $key');
    //     },
    //   ),
    // );
  }

  // Méthode pour les posts MIXED (mélange intelligent)
  Future<void> _loadMixedPostsWithType(Set<String> loadedIds, List<Post> newPosts, int limit) async {
    print('🔄 Chargement mode "Mix" avec type: $_selectedPostType');
    print('🔄 Chargement mode "Mix" avec type et pays: $_selectedCountryCode');

    if (_selectedCountryCode == null) return;

    // 1. Posts du pays utilisateur (60%)
    int countryPostsNeeded = (limit * 0.6).ceil();
    await _loadPostsWithTypeAndCountry(
      loadedIds,
      newPosts,
      postType: _selectedPostType,
      countryCode: _selectedCountryCode,
      isInitialLoad: true,
      limit: countryPostsNeeded,
    );

    // 2. Posts ALL (40%)
    int allPostsNeeded = limit - newPosts.length;
    if (allPostsNeeded > 0) {
      await _loadPostsWithTypeAndCountry(
        loadedIds,
        newPosts,
        postType: _selectedPostType,
        countryCode: null, // Tous les pays
        isInitialLoad: true,
        limit: allPostsNeeded,
      );
    }
  }

  // ===========================================================================
  // PAGINATION - CHARGEMENT MANUEL
  // ===========================================================================

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMorePosts &&
        !_isLoadingBackground &&
        _hasMorePosts &&
        _totalPostsLoaded < _maxTotalPosts &&
        !_useBackgroundLoading) {
      _loadMorePostsManually();
    }
  }

  Future<void> _loadMorePostsManually() async {
    if (_isLoadingMorePosts || _isLoadingBackground || !_hasMorePosts || _totalPostsLoaded >= _maxTotalPosts) {
      return;
    }

    setState(() {
      _isLoadingMorePosts = true;
    });

    try {
      Set<String> loadedIds = Set.from(_loadedPostIds);
      List<Post> newPosts = [];

      await _loadMorePostsByFilter(loadedIds, newPosts, _manualLoadLimit);

      if (newPosts.isNotEmpty) {
        setState(() {
          _posts.addAll(newPosts);
          _loadedPostIds.addAll(newPosts.map((p) => p.id!));
          _totalPostsLoaded += newPosts.length;
        });

        print('📱 ${newPosts.length} posts chargés manuellement');
      }

      _hasMorePosts = newPosts.length >= (_manualLoadLimit ~/ 2);

    } catch (e) {
      print('❌ Erreur chargement manuel: $e');
      _hasMorePosts = false;
    } finally {
      setState(() {
        _isLoadingMorePosts = false;
      });
    }
  }

  Future<void> _loadMorePostsByFilter(Set<String> loadedIds, List<Post> newPosts, int limit) async {
    switch (_currentFilter) {
      case 'ALL':
        await _loadPostsWithTypeAndCountry(
          loadedIds,
          newPosts,
          postType: _selectedPostType,
          countryCode: null,
          isInitialLoad: false,
          limit: limit,
        );
        break;

      case 'COUNTRY':
        if (_selectedCountryCode != null) {
          await _loadPostsWithTypeAndCountry(
            loadedIds,
            newPosts,
            postType: _selectedPostType,
            countryCode: _selectedCountryCode,
            isInitialLoad: false,
            limit: limit,
          );
        }
        break;

      case 'MIXED':
        await _loadMixedPostsWithType(loadedIds, newPosts, limit);
        break;

      case 'CUSTOM':
        if (_selectedCountryCode != null) {
          await _loadPostsWithTypeAndCountry(
            loadedIds,
            newPosts,
            postType: _selectedPostType,
            countryCode: _selectedCountryCode,
            isInitialLoad: false,
            limit: limit,
          );
        }
        break;
    }
  }

  // ===========================================================================
  // CHARGEMENT DES DONNÉES SUPPLÉMENTAIRES
  // ===========================================================================

  Future<void> _loadAllAdditionalDataInParallel() async {
    _loadSuggestedUsersInBackground();
    _loadArticlesInBackground();
    _loadCanauxInBackground();
    _loadChroniquesInBackground();
  }

  Future<void> _loadSuggestedUsersInBackground() async {
    if (_isLoadingSuggestedUsers) return;

    setState(() {
      _isLoadingSuggestedUsers = true;
    });

    try {
      final users = await userProvider.getProfileUsers(
        authProvider.loginUserData.id!,
        context,
        8,
      );

      setState(() {
        _suggestedUsers = users..shuffle();
      });
    } catch (e) {
      print('Error loading suggested users: $e');
    } finally {
      setState(() {
        _isLoadingSuggestedUsers = false;
      });
    }
  }

  Future<void> _loadArticlesInBackground() async {
    if (_isLoadingArticles) return;

    setState(() {
      _isLoadingArticles = true;
    });

    try {
      final articleResults = await categorieProduitProvider.getArticleBooster(
          _selectedCountryCode?.toUpperCase() ?? 'TG'
      );

      setState(() {
        _articles = articleResults;
      });
    } catch (e) {
      print('Error loading articles: $e');
    } finally {
      setState(() {
        _isLoadingArticles = false;
      });
    }
  }

  Future<void> _loadCanauxInBackground() async {
    if (_isLoadingCanaux) return;

    setState(() {
      _isLoadingCanaux = true;
    });

    try {
      final canalResults = await postProvider.getCanauxHome();

      setState(() {
        _canaux = canalResults..shuffle();
      });
    } catch (e) {
      print('Error loading canaux: $e');
    } finally {
      setState(() {
        _isLoadingCanaux = false;
      });
    }
  }

  Future<void> _loadChroniquesInBackground() async {
    if (_isLoadingChroniques) return;

    setState(() {
      _isLoadingChroniques = true;
    });

    try {
      final snapshot = await _firestore.collection('chroniques')
          .orderBy('createdAt', descending: true)
          .limit(6)
          .get();

      final List<Chronique> validChroniques = [];

      for (final doc in snapshot.docs) {
        try {
          final chronique = Chronique.fromMap(doc.data(), doc.id);
          if (!chronique.isExpired) {
            validChroniques.add(chronique);
          }
        } catch (e) {
          print('❌ Erreur parsing chronique: $e');
        }
      }

      setState(() {
        _chroniques = validChroniques;
      });

      if (validChroniques.isNotEmpty) {
        _loadChroniqueUserDataInBackground(validChroniques);
      }

    } catch (e) {
      print('❌ Erreur chargement chroniques: $e');
    } finally {
      setState(() {
        _isLoadingChroniques = false;
      });
    }
  }

  Future<void> _loadChroniqueUserDataInBackground(List<Chronique> chroniques) async {
    try {
      final userIds = chroniques.map((c) => c.userId).toSet();

      for (final userId in userIds) {
        if (!_userDataCache.containsKey(userId)) {
          final userDoc = await _firestore.collection('Users').doc(userId).get();
          if (userDoc.exists) {
            final userData = UserData.fromJson(userDoc.data()!);
            _userDataCache[userId] = userData;
            _userVerificationStatus[userId] = userData.isVerify ?? false;
          }
        }
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('❌ Erreur chargement données chroniques: $e');
    }
  }

  // ===========================================================================
  // WIDGETS PRINCIPAUX
  // ===========================================================================

  Widget _buildPostWidget(Post post, double width, double height) {
    return VisibilityDetector(
      key: Key('post-${post.id}'),
      onVisibilityChanged: (VisibilityInfo info) {
        _handleVisibilityChanged(post, info);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: darkBackground.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              top: 8,
              left: 8,
              child: _buildAvailabilityBadge(post),
            ),

            post.type == PostType.CHALLENGEPARTICIPATION.name
                ? LookChallengePostWidget(post: post, height: height, width: width)
                : HomePostUsersWidget(
              post: post,
              color: _getRandomColor(),
              height: height * 0.6,
              width: width,
              isDegrade: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityBadge(Post post) {
    String badgeText = '';
    Color badgeColor = Colors.grey;

    if (post.availableCountries.contains('ALL')) {
      badgeText = '🌍 ALL';
      badgeColor = Colors.green;
    } else if (_selectedCountryCode != null &&
        post.availableCountries.contains(_selectedCountryCode!)) {
      badgeText = '📍 ${_selectedCountryCode}';
      badgeColor = Colors.blue;
    } else {
      badgeText = '🌐 MULTI';
      badgeColor = Colors.orange;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getRandomColor() {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.teal,
    ];
    return colors[_random.nextInt(colors.length)];
  }

  Widget _buildFilterChips() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              label: '🌍 Tous',
              isSelected: _currentFilter == 'ALL',
              color: primaryGreen,
              onTap: () => _applyFilter(filterType: 'ALL', countryCode: null),
            ),
            SizedBox(width: 8),
            if (_selectedCountryCode != null)
              _buildFilterChip(
                label: '📍Mon pays ${_selectedCountryCode}',
                isSelected: _currentFilter == 'COUNTRY',
                color: Colors.blue,
                onTap: () => _applyFilter(filterType: 'COUNTRY', countryCode: _selectedCountryCode),
              ),
            if (_selectedCountryCode != null) SizedBox(width: 8),
            if (_selectedCountryCode != null)
              _buildFilterChip(
                label: '🔄 Mix',
                isSelected: _currentFilter == 'MIXED',
                color: Colors.purple,
                onTap: () => _applyFilter(filterType: 'MIXED', countryCode: _selectedCountryCode),
              ),
            SizedBox(width: 8),
            _buildFilterChip(
              label: '⚙️ Autre',
              isSelected: _currentFilter == 'CUSTOM',
              color: Colors.orange,
              onTap: _showCountryFilterModal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.grey[800],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[300],
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // SECTIONS SUPPLÉMENTAIRES
  // ===========================================================================

  Widget _buildChroniquesSection() {
    if (_isLoadingChroniques) {
      return _buildLoadingSection('📝 Chroniques récentes');
    }

    if (_chroniques.isEmpty) {
      return SizedBox.shrink();
    }

    return ChroniqueSectionComponent(
      videoThumbnails: _videoThumbnails,
      userVerificationStatus: _userVerificationStatus,
      userDataCache: _userDataCache,
      isLoadingChroniques: _isLoadingChroniques,
      groupedChroniques: _groupChroniquesByUser(_chroniques),
    );
  }

  Map<String, List<Chronique>> _groupChroniquesByUser(List<Chronique> chroniques) {
    final grouped = <String, List<Chronique>>{};
    for (final chronique in chroniques) {
      grouped[chronique.userId] = [...grouped[chronique.userId] ?? [], chronique];
    }
    return grouped;
  }

  Widget _buildProfilesSection() {
    if (_isLoadingSuggestedUsers) {
      return _buildLoadingSection('👑 Profils à découvrir');
    }

    if (_suggestedUsers.isEmpty) {
      return SizedBox.shrink();
    }

    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '👑 Profils à découvrir',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              Container(
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFF8B0000)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UsersListPage(),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Voir tout', style: TextStyle(color: Colors.white, fontSize: 11)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, color: Colors.white, size: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: height * 0.25,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _suggestedUsers.length,
            itemBuilder: (context, index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              width: width * 0.35,
              child: _buildProfileCard(_suggestedUsers[index], width, height),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard(UserData user, double width, double height) {
    return Container(
      decoration: BoxDecoration(
        color: darkBackground.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryGreen.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _showUserDetails(user),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  width: width * 0.4,
                  height: height * 0.18,
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: CachedNetworkImage(
                      fit: BoxFit.cover,
                      imageUrl: user.imageUrl ?? '',
                      placeholder: (context, url) => Container(
                        color: Colors.grey[800],
                        child: Center(child: CircularProgressIndicator(color: primaryGreen)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[800],
                        child: Icon(Icons.person, color: Colors.grey[400]),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: width * 0.4,
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black87, Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '@${user.pseudo?.replaceAll("@", "") ?? "user"}',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (user.isVerify ?? false)
                            Icon(Icons.verified, color: primaryGreen, size: 12),
                        ],
                      ),
                      SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.group, size: 9, color: accentYellow),
                              SizedBox(width: 2),
                              Text(
                                _formatNumber(user.userAbonnesIds?.length ?? 0),
                                style: TextStyle(
                                  color: accentYellow,
                                  fontSize: 9,
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
          Container(
            width: double.infinity,
            height: 30,
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: ElevatedButton(
              onPressed: () => _showUserDetails(user),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: darkBackground,
                padding: EdgeInsets.symmetric(vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'S\'abonner',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUserDetails(UserData user) async {
    final users = await authProvider.getUserById(user.id!);
    if (users.isNotEmpty && mounted) {
      double width = MediaQuery.of(context).size.width;
      double height = MediaQuery.of(context).size.height;
      showUserDetailsModalDialog(users.first, width, height, context);
    }
  }

  Widget _buildArticlesSection() {
    if (_isLoadingArticles) {
      return _buildLoadingSection('🔥 Produits Boostés');
    }

    if (_articles.isEmpty) {
      return SizedBox.shrink();
    }

    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('🔥 Produits Boostés',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (context) => HomeAfroshopPage(title: ''))),
                  child: Row(
                    children: [
                      Text('Boutiques', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, color: primaryGreen, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: height * 0.22,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _articles.length,
              itemBuilder: (context, index) => Container(
                margin: EdgeInsets.symmetric(horizontal: 8),
                width: width * 0.55,
                child: ProductWidget(
                  article: _articles[index],
                  width: width * 0.55,
                  height: height * 0.22,
                  isOtherPage: true,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanauxSection() {
    if (_isLoadingCanaux) {
      return _buildLoadingSection('📺 Afrolook Canal');
    }

    if (_canaux.isEmpty) {
      return SizedBox.shrink();
    }

    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('📺 Afrolook Canal',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (context) => CanalListPage(isUserCanals: false))),
                  child: Row(
                    children: [
                      Text('Voir plus', style: TextStyle(color: primaryGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, color: primaryGreen, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: height * 0.16,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _canaux.length,
              itemBuilder: (context, index) => Container(
                margin: EdgeInsets.symmetric(horizontal: 8),
                width: width * 0.28,
                child: channelWidget(
                  _canaux[index],
                  height * 0.25,
                  width * 0.28,
                  context,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSection(String title) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: darkBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primaryGreen,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
        ],
      ),
    );
  }

  // ===========================================================================
  // CONTENU PRINCIPAL
  // ===========================================================================

  Widget _buildContent() {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    if (_isLoadingPosts && _posts.isEmpty) {
      return _buildLoadingShimmer(width, height);
    }

    if (_hasErrorPosts && _posts.isEmpty) {
      return _buildErrorWidget();
    }

    if (_posts.isEmpty) {
      return _buildEmptyWidget();
    }

    List<Widget> contentWidgets = [];

    // 1. Filtres
    contentWidgets.add(_buildFilterChips());
    contentWidgets.add(SizedBox(height: 8));

    // 2. Chroniques (si chargées)
    final chroniquesSection = _buildChroniquesSection();
    if (chroniquesSection is! SizedBox) {
      contentWidgets.add(chroniquesSection);
    }

    // 3. Profils utilisateurs (si chargés)
    final profilesSection = _buildProfilesSection();
    if (profilesSection is! SizedBox) {
      contentWidgets.add(profilesSection);
      contentWidgets.add(SizedBox(height: 16));
    }

    // 4. Posts avec bannières
    int postIndex = 0;
    for (int i = 0; i < _posts.length; i++) {
      final post = _posts[i];

      // Ajouter le post
      contentWidgets.add(
        GestureDetector(
          onTap: () => _navigateToPostDetails(post),
          child: _buildPostWidget(post, width, height),
        ),
      );

      postIndex++;

      // 🔴 AJOUT DES BANNIÈRES ADMOB
      // Après le PREMIER post (postIndex == 1)
      if (postIndex == 1) {
        contentWidgets.add(_buildAdBanner(key: 'ad_after_first'));
      }

      // Ensuite, tous les 3 posts (après le 4ème, 7ème, 10ème...)
      if (postIndex > 1 && (postIndex - 1) % 3 == 0) {
        contentWidgets.add(_buildAdBanner(key: 'ad_${postIndex}'));
      }

      // Garder vos sections spéciales existantes
      if (postIndex % 3 == 0) {
        if (postIndex % 6 == 3) {
          final articlesSection = _buildArticlesSection();
          if (articlesSection is! SizedBox) {
            contentWidgets.add(articlesSection);
          }
        } else if (postIndex % 6 == 0) {
          final canauxSection = _buildCanauxSection();
          if (canauxSection is! SizedBox) {
            contentWidgets.add(canauxSection);
          }
        }
      }
    }
    // 5. Indicateurs de chargement/fin
    if (_isLoadingMorePosts) {
      contentWidgets.add(
        Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Column(
              children: [
                CircularProgressIndicator(color: primaryGreen),
                SizedBox(height: 10),
                Text('Chargement de plus de posts...', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    } else if (_isLoadingBackground && _useBackgroundLoading) {
      contentWidgets.add(
        Container(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Column(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.grey[500],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Préparation de plus de contenu... ($_backgroundPostsLoaded/$_maxBackgroundPosts)',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (!_hasMorePosts) {
      contentWidgets.add(
        Container(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.flag, color: Colors.green, size: 36),
                SizedBox(height: 10),
                Text(
                  _getEndMessage(),
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 5),
                Text(
                  'Revenez plus tard pour de nouveaux contenus',
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (!_useBackgroundLoading) {
      // Bouton "Charger plus" quand le background est désactivé
      contentWidgets.add(
        Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Column(
              children: [
                Text(
                  'Chargement automatique terminé',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _loadMorePostsManually,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  ),
                  child: Text(
                    'Charger 5 posts de plus',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) => contentWidgets[index],
            childCount: contentWidgets.length,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // WIDGETS D'ÉTAT
  // ===========================================================================

  Widget _buildLoadingShimmer(double width, double height) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            height: 100,
            margin: EdgeInsets.all(8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              itemBuilder: (context, index) {
                return Container(
                  width: width * 0.2,
                  margin: EdgeInsets.all(4),
                  child: Shimmer.fromColors(
                    baseColor: Colors.grey[800]!,
                    highlightColor: Colors.grey[700]!,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
                (context, index) {
              return Container(
                margin: EdgeInsets.all(8),
                child: Shimmer.fromColors(
                  baseColor: Colors.grey[800]!,
                  highlightColor: Colors.grey[700]!,
                  child: Container(
                    height: 350,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              );
            },
            childCount: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 40),
          SizedBox(height: 12),
          Text('Erreur de chargement', style: TextStyle(color: Colors.white, fontSize: 14)),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: _refreshData,
            child: Text('Réessayer', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.feed, color: Colors.grey, size: 40),
          SizedBox(height: 12),
          Text(
            _getEmptyMessage(),
            style: TextStyle(color: Colors.grey, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          ElevatedButton(
            onPressed: _refreshData,
            child: Text('Actualiser', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  String _getEmptyMessage() {
    String typeMsg = ' de type $_selectedPostType';

    switch (_currentFilter) {
      case 'ALL':
        return 'Aucun contenu disponible pour tous les pays$typeMsg';
      case 'COUNTRY':
        return 'Aucun contenu disponible en ${_selectedCountryCode ?? "ce pays"}$typeMsg';
      case 'MIXED':
        return 'Aucun contenu disponible pour le moment$typeMsg';
      case 'CUSTOM':
        return 'Aucun contenu disponible pour ${_selectedCountryCode ?? "ce pays"}$typeMsg';
      default:
        return 'Aucun contenu disponible$typeMsg';
    }
  }

  String _getEndMessage() {
    String typeMsg = ' de type $_selectedPostType';

    switch (_currentFilter) {
      case 'ALL':
        return 'Vous avez vu tous les contenus disponibles$typeMsg';
      case 'COUNTRY':
        return 'Fin des contenus en ${_selectedCountryCode ?? "ce pays"}$typeMsg';
      case 'MIXED':
        return 'Fin des contenus pour le mix actuel$typeMsg';
      case 'CUSTOM':
        return 'Fin des contenus pour ${_selectedCountryCode ?? "ce pays"}$typeMsg';
      default:
        return 'Fin des contenus$typeMsg';
    }
  }

  String _getFilterDescription() {
    String countryDesc = '';
    String typeDesc = 'Type: $_selectedPostType';

    switch (_currentFilter) {
      case 'ALL':
        countryDesc = '🌍 Tous les pays';
        break;
      case 'COUNTRY':
        countryDesc = '📍 ${_selectedCountryCode ?? "Mon pays"}';
        break;
      case 'MIXED':
        countryDesc = '🔄 Mix intelligent';
        break;
      case 'CUSTOM':
        countryDesc = '⚙️ ${_selectedCountryCode ?? "Pays spécifique"}';
        break;
      default:
        countryDesc = 'Filtrer par pays';
    }

    return '$countryDesc • $typeDesc';
  }
  Widget _getFilterIcon() {
    switch (_currentFilter) {
      case 'ALL':
        return Icon(Icons.public, color: Colors.white, size: 18);
      case 'COUNTRY':
      case 'CUSTOM':
        return Text(
          _getCountryFlag(_selectedCountryCode ?? ''),
          style: TextStyle(fontSize: 16),
        );
      case 'MIXED':
        return Icon(Icons.blender, color: Colors.white, size: 18);
      default:
        return Icon(Icons.filter_alt, color: Colors.white, size: 18);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toUpperCase()) {
      case 'SPORT':
        return Icons.sports_soccer;
      case 'MUSIC':
        return Icons.music_note;
      case 'ACTUALITES':
        return Icons.newspaper;
      case 'LOOKS':
        return Icons.style;
      case 'EVENEMENT':
        return Icons.event;
      case 'OFFRES':
        return Icons.local_offer;
      case 'GAMER':
        return Icons.videogame_asset;
      default:
        return Icons.category;
    }
  }

  // ===========================================================================
  // MÉTHODES UTILITAIRES
  // ===========================================================================

  bool _checkIfPostSeen(Post post) {
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null || post.id == null) return false;

    if (_postsViewedInSession.containsKey(post.id)) {
      return _postsViewedInSession[post.id]!;
    }

    if (authProvider.loginUserData.viewedPostIds?.contains(post.id!) ?? false) {
      return true;
    }

    if (post.users_vue_id?.contains(currentUserId) ?? false) {
      return true;
    }

    return false;
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

  Future<void> _recordPostView(Post post) async {
    final currentUserId = authProvider.loginUserData.id;
    if (currentUserId == null || post.id == null) return;

    if (_postsViewedInSession.containsKey(post.id!)) {
      return;
    }

    try {
      _postsViewedInSession[post.id!] = true;

      setState(() {
        post.hasBeenSeenByCurrentUser = true;
        post.vues = (post.vues ?? 0) + 1;
        post.users_vue_id ??= [];
        if (!post.users_vue_id!.contains(currentUserId)) {
          post.users_vue_id!.add(currentUserId);
        }
      });

      final batch = _firestore.batch();
      final postRef = _firestore.collection('Posts').doc(post.id);
      batch.update(postRef, {
        'vues': FieldValue.increment(1),
        'users_vue_id': FieldValue.arrayUnion([currentUserId]),
      });

      final userRef = _firestore.collection('Users').doc(currentUserId);
      batch.update(userRef, {
        'viewedPostIds': FieldValue.arrayUnion([post.id!]),
      });

      await batch.commit();

      authProvider.loginUserData.viewedPostIds ??= [];
      if (!authProvider.loginUserData.viewedPostIds!.contains(post.id!)) {
        authProvider.loginUserData.viewedPostIds!.add(post.id!);
      }

    } catch (e) {
      print('Error recording post view: $e');
      _postsViewedInSession.remove(post.id!);
    }
  }

  void _navigateToPostDetails(Post post) {
    _recordPostView(post);
    // Naviguer vers la page de détails du post
  }

  Future<void> _refreshData() async {
    _backgroundLoadTimer?.cancel();

    setState(() {
      _isLoadingPosts = true;
      _isFirstLoad = true;
      _useBackgroundLoading = true;
      _backgroundPostsLoaded = 0;
    });

    _resetPagination();
    await _loadInitialPosts();

    _startBackgroundLoading();

    setState(() {
      _isLoadingPosts = false;
    });
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}k';
    }
    return number.toString();
  }

  void _handleAppLifecycle(String? message) {
    if (message?.contains('resume') == true) {
      _setUserOnline();
    } else {
      _setUserOffline();
    }
  }
// Dans votre classe, ajoutez ces listes
  final List<String> _sportTitles = [
    '⚽ LIGUE DES CHAMPIONS',
    '⚽ LIGUE EUROPA',

    '🏆 LIGA - REAL MADRID',
    '🏆 LIGA - BARÇA',
    '🏆 LIGA - ATLETICO MADRID',

    '⚽ LIGUE 1 - PSG',
    '⚽ LIGUE 1 - MARSEILLE',

    '⚽ PREMIER LEAGUE',
    '⚽ PREMIER LEAGUE - MANCHESTER CITY',
    '⚽ PREMIER LEAGUE - LIVERPOOL',

    '⚽ LDC - CAN',
    '⚽ LIGUE AFRICAINE',
    '⚽ CAF - AL AHLY',
    '⚽ CAF - ZAMALEK',
    '⚽ CAF - TP MAZEMBE',
    '⚽ CAF - WYDAD CASABLANCA',

    '🏀 BASKETBALL - NBA',
    '🤾 HANDBALL',
  ];

  void _setUserOnline() {
    if (authProvider.loginUserData != null) {
      authProvider.loginUserData!.isConnected = true;
      userProvider.changeState(
          user: authProvider.loginUserData,
          state: UserState.ONLINE.name
      );
    }
  }

  void _setUserOffline() {
    if (authProvider.loginUserData != null) {
      authProvider.loginUserData!.isConnected = false;
      userProvider.changeState(
          user: authProvider.loginUserData,
          state: UserState.OFFLINE.name
      );
    }
  }

  Color _getFilterBorderColor() {
    switch (_currentFilter) {
      case 'ALL':
        return primaryGreen;
      case 'COUNTRY':
        return Colors.blue;
      case 'MIXED':
        return Colors.purple;
      case 'CUSTOM':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
  String _getFilterLabel() {
    switch (_currentFilter) {
      case 'ALL':
        return 'Tous';
      case 'COUNTRY':
        return 'Mon pays';
      case 'MIXED':
        return 'Mix';
      case 'CUSTOM':
        return _selectedCountryCode ?? 'Pays';
      default:
        return 'Filtre';
    }
  }
  // ===========================================================================
  // BUILD
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: darkBackground,
        body: SafeArea(
          child: Column(
            children: [
              // ============================================================
              // LIGNE 1: Titre animé + bouton retour (compact)
              // ============================================================
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: Colors.black,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Bouton retour
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.arrow_back, color: Colors.white, size: 18),
                      ),
                    ),
                    SizedBox(width: 10,),


                    // Titre animé (expand)
                    Container(
                      child: _selectedPostType == 'SPORT'
                          ? _buildCompactSportTitle()
                          : Text(
                        _selectedPostType,
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // ============================================================
              // LIGNE 2: Boutons d'action + hashtags (scroll horizontal)
              // ============================================================
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                color: Colors.black,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Bouton Poster compact
                      _buildCompactButton(
                        label: 'Poster',
                        icon: Icons.add,
                        color: Colors.green,
                        onTap: () => Navigator.pushNamed(context, '/user_posts_form'),
                      ),

                      SizedBox(width: 6),

                      // Bouton Type compact
                      _buildCompactButton(
                        label: _selectedPostType,
                        icon: _getTypeIcon(_selectedPostType),
                        color: Colors.purple,
                        onTap: _showTypeFilterModal,
                      ),

                      SizedBox(width: 6),

                      // Bouton Filtre compact
                      _buildCompactButton(
                        label: _getFilterLabel(),
                        iconDataWidget: _getFilterIcon(),
                        color: _getFilterBorderColor(),
                        onTap: _showCountryFilterModal,
                      ),

                      SizedBox(width: 6),

                      // Bouton Rafraîchir
                      InkWell(
                        onTap: _refreshData,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.grey[800],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.refresh, color: Colors.white, size: 14),
                        ),
                      ),

                      // Hashtags sport (sur la même ligne que les boutons)
                      if (_selectedPostType == 'SPORT') ...[
                        SizedBox(width: 8),
                        _buildCompactSportTags(),
                      ],
                    ],
                  ),
                ),
              ),

              // ============================================================
              // CONTENU PRINCIPAL
              // ============================================================
              Expanded(
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

// Titre sport compact animé
// Titre sport compact animé (version corrigée)
  Widget _buildCompactSportTitle() {
    if (_selectedPostType != 'SPORT') {
      return Text(
        _selectedPostType,
        style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
      );
    }

    return AnimatedSwitcher(
      duration: Duration(milliseconds: 500),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0.2, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Text(
        _sportTitles[_currentTitleIndex],
        key: ValueKey(_currentTitleIndex),
        style: TextStyle(
          fontSize: 16,
          color: Colors.green,
          fontWeight: FontWeight.bold,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
// Bouton compact
  Widget _buildCompactButton({
    required String label,
    IconData? icon,
    Widget? iconDataWidget,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(icon, color: Colors.white, size: 12)
            else if (iconDataWidget != null)
              Container(width: 16, height: 16, child: Center(child: iconDataWidget)),

            if (label.isNotEmpty) ...[
              SizedBox(width: 4),
              Text(
                label.length > 6 ? '${label.substring(0, 4)}..' : label,
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ],
          ],
        ),
      ),
    );
  }

// Hashtags sport compacts (une seule ligne avec les boutons)
  Widget _buildCompactSportTags() {
    List<String> tags = ['#Football', '#LDC', '#Ligue1', '#NBA', '#Handball', '#Liga'];
    tags.shuffle();
    tags = tags.take(3).toList(); // Seulement 3 tags pour garder compact

    return Row(
      children: tags.map((tag) => Container(
        margin: EdgeInsets.only(right: 4),
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Text(
          tag,
          style: TextStyle(color: Colors.green, fontSize: 9),
        ),
      )).toList(),
    );
  }
}