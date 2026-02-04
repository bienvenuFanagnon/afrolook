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
import '../userPosts/postWidgets/postWidgetPage.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../../providers/mixed_feed_service_provider.dart';
import 'dart:typed_data';


// Constantes de couleur
const Color primaryGreen = Color(0xFF25D366);
const Color darkBackground = Color(0xFF121212);
const Color lightBackground = Color(0xFF1E1E1E);
const Color textColor = Colors.white;
const Color accentYellow = Color(0xFFFFD700);

class HomeConstPostPage extends StatefulWidget {
  final String type;
  final String? sortType;

  HomeConstPostPage({super.key, required this.type, this.sortType});

  @override
  State<HomeConstPostPage> createState() => _HomeConstPostPageState();
}

class _HomeConstPostPageState extends State<HomeConstPostPage>
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
  int _backgroundPostsLoaded = 0; // Compteur des posts chargés en background
  final int _initialLimit = 3; // Premier chargement: 3 posts
  final int _backgroundLoadLimit = 5; // Chargement background: 5 posts
  final int _manualLoadLimit = 5; // Chargement manuel: 5 posts
  final int _maxBackgroundPosts = 20; // MAX posts en background
  final int _maxTotalPosts = 1000; // Limite totale
  Timer? _backgroundLoadTimer;
  bool _useBackgroundLoading = true; // Active/désactive le chargement background

  // Filtrage par pays
  String? _selectedCountryCode;
  String _currentFilter = 'MIXED'; // 'ALL', 'COUNTRY', 'MIXED', 'CUSTOM'
  // String _currentFilter = 'ALL'; // 'ALL', 'COUNTRY', 'MIXED', 'CUSTOM'
  bool _isFirstLoad = true;

  // Données supplémentaires - chargement séparé
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

  @override
  void initState() {
    super.initState();

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

  @override
  void dispose() {
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

    // 2. Par défaut: mode "Tous les pays"
    _currentFilter = 'MIXED';
    // _currentFilter = 'ALL';
    _isFirstLoad = true;
    _useBackgroundLoading = true; // Activer le chargement background initial
    _backgroundPostsLoaded = 0; // Réinitialiser le compteur

    // 3. Réinitialiser et charger les posts initiaux (3 posts)
    _resetPagination();
    await _loadInitialPosts();

    // 4. Démarrer le chargement background (si activé)
    _startBackgroundLoading();

    // 5. Charger les autres données EN PARALLÈLE (non bloquant)
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
  // SYSTÈME HYBRIDE DE CHARGEMENT (Background + Manuel)
  // ===========================================================================

  void _startBackgroundLoading() {
    if (!_useBackgroundLoading) return;

    // Arrêter tout timer existant
    _backgroundLoadTimer?.cancel();

    print('🚀 Démarrage du chargement background (max: $_maxBackgroundPosts posts)');

    // Démarrer un nouveau timer pour le chargement background
    _backgroundLoadTimer = Timer.periodic(Duration(seconds: 2), (timer) async {
      // Conditions pour charger en background :
      // 1. Background activé
      // 2. Pas déjà en cours de chargement background
      // 3. Pas de chargement manuel en cours
      // 4. Il reste des posts à charger
      // 5. On n'a pas dépassé la limite de background
      // 6. L'utilisateur ne scroll pas activement
      if (_useBackgroundLoading &&
          !_isLoadingBackground &&
          !_isLoadingMorePosts &&
          _hasMorePosts &&
          _backgroundPostsLoaded < _maxBackgroundPosts &&
          _totalPostsLoaded < _maxTotalPosts &&
          !_isUserScrolling()) {

        await _loadBackgroundPosts();
      }

      // Arrêter le timer si :
      // 1. On a atteint la limite de background
      // 2. Il n'y a plus de posts à charger
      // 3. Le background est désactivé
      if (_backgroundPostsLoaded >= _maxBackgroundPosts ||
          !_hasMorePosts ||
          !_useBackgroundLoading) {
        print('⏹️ Arrêt du chargement background (posts background: $_backgroundPostsLoaded)');
        timer.cancel();
        _useBackgroundLoading = false; // Passer en mode manuel
      }
    });
  }

  bool _isUserScrolling() {
    return _scrollController.position.isScrollingNotifier.value;
  }

  Future<void> _loadBackgroundPosts() async {
    if (_isLoadingBackground ||
        !_hasMorePosts ||
        _backgroundPostsLoaded >= _maxBackgroundPosts ||
        _totalPostsLoaded >= _maxTotalPosts) {
      return;
    }

    print('🔄 Chargement background... ($_backgroundPostsLoaded/$_maxBackgroundPosts)');

    setState(() {
      _isLoadingBackground = true;
    });

    try {
      Set<String> loadedIds = Set.from(_loadedPostIds);
      List<Post> newPosts = [];

      await _loadMorePostsByFilter(loadedIds, newPosts, _backgroundLoadLimit);

      // Ajouter les nouveaux posts à la liste
      if (newPosts.isNotEmpty) {
        setState(() {
          _posts.addAll(newPosts);
          _loadedPostIds.addAll(newPosts.map((p) => p.id!));
          _totalPostsLoaded += newPosts.length;
          _backgroundPostsLoaded += newPosts.length;
        });

        print('✅ ${newPosts.length} posts chargés en background (total: $_totalPostsLoaded, background: $_backgroundPostsLoaded)');
      }

      // Vérifier s'il reste des posts à charger
      _hasMorePosts = newPosts.length >= (_backgroundLoadLimit ~/ 2);

      // Si on atteint la limite de background, désactiver
      if (_backgroundPostsLoaded >= _maxBackgroundPosts) {
        _useBackgroundLoading = false;
        print('📊 Passage en mode chargement manuel (limite background atteinte)');
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
  // MODAL DE FILTRE PAR PAYS - VERSION AMÉLIORÉE
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
            // Fonction pour mettre à jour la recherche
            void updateSearch(String query) {
              searchQuery = query.toLowerCase();
              setModalState(() {});
            }

            // Filtrer les pays
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

                  // Barre de recherche AMÉLIORÉE
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

                  // Options rapides sur UNE SEULE LIGNE
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Option "Tous les pays"
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

                          // Option "Mon pays"
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

                          // Option "Mix"
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

                  // Séparateur
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(color: Colors.grey[800], thickness: 1),
                  ),

                  // Titre liste pays
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

                  // Liste des pays avec recherche fonctionnelle
                  Expanded(
                    child: _buildCountryList(filteredCountries, searchQuery),
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
    // Arrêter le chargement background pendant le changement de filtre
    _backgroundLoadTimer?.cancel();

    setState(() {
      _currentFilter = filterType;
      if (countryCode != null) {
        _selectedCountryCode = countryCode.toUpperCase();
      }
      _isLoadingPosts = true;
      _isFirstLoad = true;
      _useBackgroundLoading = true; // Réactiver le background pour le nouveau filtre
      _backgroundPostsLoaded = 0; // Réinitialiser le compteur
    });

    // Réinitialiser la pagination
    _resetPagination();

    // Charger les posts initiaux (3 posts)
    await _loadInitialPosts();

    // Redémarrer le chargement background
    _startBackgroundLoading();

    setState(() {
      _isLoadingPosts = false;
    });

    print('✅ Filtre appliqué: $_currentFilter - Pays: $_selectedCountryCode');
  }

  // ===========================================================================
  // CHARGEMENT DES POSTS
  // ===========================================================================

  Future<void> _loadInitialPosts() async {
    try {
      setState(() {
        _isLoadingPosts = true;
        _hasErrorPosts = false;
      });

      Set<String> loadedIds = Set();
      List<Post> newPosts = [];

      // Premier chargement: 3 posts seulement
      int limit = _initialLimit;
printVm("_currentFilter data: ${_currentFilter}");
      switch (_currentFilter) {
        case 'ALL':
          await _loadAllCountriesMixed(loadedIds, newPosts, limit);
          break;

        case 'COUNTRY':
          if (_selectedCountryCode != null) {
            await _loadCountrySpecificPosts(
              loadedIds,
              newPosts,
              _selectedCountryCode!,
              isInitialLoad: true,
              limit: limit,
            );

            // Compléter avec posts ALL si pas assez
            if (newPosts.length < limit) {
              await _loadAllCountriesPosts(
                loadedIds,
                newPosts,
                isInitialLoad: true,
                limit: limit - newPosts.length,
              );
            }
          }
          break;

        case 'MIXED':
          if (_selectedCountryCode != null) {
            await _loadMixedPostsSmart(loadedIds, newPosts, _selectedCountryCode!, limit);
          }
          break;

        case 'CUSTOM':
          if (_selectedCountryCode != null) {
            await _loadCountrySpecificPosts(
              loadedIds,
              newPosts,
              _selectedCountryCode!,
              isInitialLoad: true,
              limit: limit,
            );
          }
          break;
      }

      // Mettre à jour la liste des posts
      setState(() {
        _posts = newPosts;
        _loadedPostIds.addAll(loadedIds);
        _totalPostsLoaded = newPosts.length;
        _isFirstLoad = false;
      });

      print('✅ ${newPosts.length} posts chargés avec filtre: $_currentFilter');

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

  // ===========================================================================
  // ALGORITHMES DE CHARGEMENT SPÉCIFIQUES
  // ===========================================================================

  Future<void> _loadAllCountriesMixed(Set<String> loadedIds, List<Post> newPosts, int limit) async {
    print('🌍 Chargement mode "Tous les pays" - limite: $limit');

    int attempts = 0;
    int maxAttempts = 3;

    while (newPosts.length < limit && attempts < maxAttempts) {
      // 1. Posts ALL (60%)
      if (newPosts.length < limit) {
        int needed = (limit * 0.6).ceil();
        await _loadAllCountriesPosts(
          loadedIds,
          newPosts,
          isInitialLoad: attempts == 0,
          limit: needed,
        );
      }

      // 2. Autres pays (40%)
      if (_selectedCountryCode != null && newPosts.length < limit) {
        int needed = limit - newPosts.length;
        await _loadOtherCountriesPosts(
          loadedIds,
          newPosts,
          excludeCountry: _selectedCountryCode!,
          isInitialLoad: attempts == 0,
          limit: needed,
        );
      }

      attempts++;
    }

    // Mélanger pour variété
    if (newPosts.length > 1) {
      newPosts.shuffle();
    }
  }

  Future<void> _loadMixedPostsSmart(Set<String> loadedIds, List<Post> newPosts, String userCountryCode, int limit) async {
    print('🔄 Chargement mode "Mix intelligent" - limite: $limit');

    // 1. Posts du pays utilisateur (40%)
    int countryPostsNeeded = (limit * 0.4).ceil();
    await _loadCountrySpecificPosts(
      loadedIds,
      newPosts,
      userCountryCode,
      isInitialLoad: true,
      limit: countryPostsNeeded,
    );

    // 2. Posts ALL (40%)
    int allPostsNeeded = (limit * 0.4).ceil();
    await _loadAllCountriesPosts(
      loadedIds,
      newPosts,
      isInitialLoad: true,
      limit: allPostsNeeded,
    );

    // 3. Posts autres pays (20%)
    int otherPostsNeeded = limit - newPosts.length;
    if (otherPostsNeeded > 0) {
      await _loadOtherCountriesPosts(
        loadedIds,
        newPosts,
        excludeCountry: userCountryCode,
        isInitialLoad: true,
        limit: otherPostsNeeded,
      );
    }
  }

  Future<void> _loadCountrySpecificPosts(
      Set<String> loadedIds,
      List<Post> newPosts,
      String countryCode, {
        bool isInitialLoad = false,
        int limit = 5,
      }) async
  {
    if (limit <= 0) return;

    try {
      print('🎯 Chargement posts pays: $countryCode - limite: $limit');

      Query query = _firestore.collection('Posts');

      // Essayer différents noms de champs
      try {
        query = query.where("available_countries", arrayContains: countryCode);
      } catch (e) {
        try {
          query = query.where("availableCountries", arrayContains: countryCode);
        } catch (e2) {
          query = query.where("country", isEqualTo: countryCode);
        }
      }

      query = query.orderBy("created_at", descending: true);

      if (!isInitialLoad && _lastCountryDocument != null) {
        query = query.startAfterDocument(_lastCountryDocument!);
      }

      query = query.limit(limit * 2);

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastCountryDocument = snapshot.docs.last;
      }

      int added = 0;
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

      print('✅ $added posts du pays $countryCode ajoutés');

    } catch (e) {
      print('❌ Erreur chargement pays $countryCode: $e');
    }
  }

  Future<void> _loadAllCountriesPosts(
      Set<String> loadedIds,
      List<Post> newPosts, {
        bool isInitialLoad = false,
        int limit = 5,
      }) async
  {
    if (limit <= 0) return;

    try {
      print('🌐 Chargement posts ALL - limite: $limit');

      Query query = _firestore.collection('Posts');

      // Essayer différents noms de champs
      try {
        query = query.where("available_countries", arrayContains: "ALL");
      } catch (e) {
        try {
          query = query.where("availableCountries", arrayContains: "ALL");
        } catch (e2) {
          query = query.where("is_available_in_all_countries", isEqualTo: true);
        }
      }

      query = query.orderBy("created_at", descending: true);

      if (!isInitialLoad && _lastAllDocument != null) {
        query = query.startAfterDocument(_lastAllDocument!);
      }

      query = query.limit(limit * 2);

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastAllDocument = snapshot.docs.last;
      }

      int added = 0;
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

      print('✅ $added posts ALL ajoutés');

    } catch (e) {
      print('❌ Erreur chargement posts ALL: $e');
    }
  }

  Future<void> _loadOtherCountriesPosts(
      Set<String> loadedIds,
      List<Post> newPosts, {
        required String excludeCountry,
        bool isInitialLoad = false,
        int limit = 5,
      }) async
  {
    if (limit <= 0) return;

    try {
      print('🌍 Chargement autres pays (exclure: $excludeCountry) - limite: $limit');

      Query query = _firestore.collection('Posts')
          .orderBy("created_at", descending: true);

      if (!isInitialLoad && _lastOtherDocument != null) {
        query = query.startAfterDocument(_lastOtherDocument!);
      }

      query = query.limit(limit * 4);

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastOtherDocument = snapshot.docs.last;
      }

      int added = 0;
      for (var doc in snapshot.docs) {
        if (added >= limit) break;

        try {
          final post = Post.fromJson(doc.data() as Map<String, dynamic>);
          post.id = doc.id;

          if (loadedIds.contains(post.id) || _loadedPostIds.contains(post.id)) {
            continue;
          }

          // Filtrer manuellement
          bool isExcluded = false;

          if (post.availableCountries.contains(excludeCountry)) {
            isExcluded = true;
          }

          if (post.availableCountries.contains("ALL")) {
            isExcluded = true;
          }

          if (post.availableCountries.isEmpty) {
            isExcluded = true;
          }

          if (!isExcluded) {
            post.hasBeenSeenByCurrentUser = _checkIfPostSeen(post);
            newPosts.add(post);
            loadedIds.add(post.id!);
            added++;
          }
        } catch (e) {
          print('Erreur parsing post: $e');
        }
      }

      print('✅ $added posts autres pays ajoutés');

    } catch (e) {
      print('❌ Erreur chargement autres pays: $e');
    }
  }

  // ===========================================================================
  // PAGINATION - CHARGEMENT MANUEL (Après les 20 posts background)
  // ===========================================================================

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMorePosts &&
        !_isLoadingBackground &&
        _hasMorePosts &&
        _totalPostsLoaded < _maxTotalPosts &&
        !_useBackgroundLoading) { // Seulement en mode manuel
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

      // Ajouter les nouveaux posts
      if (newPosts.isNotEmpty) {
        setState(() {
          _posts.addAll(newPosts);
          _loadedPostIds.addAll(newPosts.map((p) => p.id!));
          _totalPostsLoaded += newPosts.length;
        });

        print('📱 ${newPosts.length} posts chargés manuellement (total: $_totalPostsLoaded)');
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
        await _loadMoreAllCountriesMixed(loadedIds, newPosts, limit);
        break;

      case 'COUNTRY':
        if (_selectedCountryCode != null) {
          await _loadMoreCountrySpecific(loadedIds, newPosts, _selectedCountryCode!, limit);
        }
        break;

      case 'MIXED':
        if (_selectedCountryCode != null) {
          await _loadMoreMixed(loadedIds, newPosts, _selectedCountryCode!, limit);
        }
        break;

      case 'CUSTOM':
        if (_selectedCountryCode != null) {
          await _loadMoreCountrySpecific(loadedIds, newPosts, _selectedCountryCode!, limit);
        }
        break;
    }
  }

  Future<int> _loadMoreAllCountriesMixed(Set<String> loadedIds, List<Post> newPosts, int limit) async {
    int added = 0;
    int attempts = 0;

    while (added < limit && attempts < 2) {
      int needed = limit - added;
      await _loadAllCountriesPosts(
        loadedIds,
        newPosts,
        isInitialLoad: false,
        limit: needed,
      );

      if (_selectedCountryCode != null && added < limit) {
        needed = limit - added;
        await _loadOtherCountriesPosts(
          loadedIds,
          newPosts,
          excludeCountry: _selectedCountryCode!,
          isInitialLoad: false,
          limit: needed,
        );
      }

      added = newPosts.length;
      attempts++;
    }

    return added;
  }

  Future<int> _loadMoreCountrySpecific(Set<String> loadedIds, List<Post> newPosts, String countryCode, int limit) async {
    await _loadCountrySpecificPosts(
      loadedIds,
      newPosts,
      countryCode,
      isInitialLoad: false,
      limit: limit,
    );

    int added = newPosts.length;

    if (added < limit) {
      int needed = limit - added;
      await _loadAllCountriesPosts(
        loadedIds,
        newPosts,
        isInitialLoad: false,
        limit: needed,
      );
      added = newPosts.length;
    }

    return added;
  }

  Future<int> _loadMoreMixed(Set<String> loadedIds, List<Post> newPosts, String countryCode, int limit) async {
    int countryNeeded = (limit * 0.4).ceil();
    await _loadCountrySpecificPosts(
      loadedIds,
      newPosts,
      countryCode,
      isInitialLoad: false,
      limit: countryNeeded,
    );

    int allNeeded = (limit * 0.4).ceil();
    await _loadAllCountriesPosts(
      loadedIds,
      newPosts,
      isInitialLoad: false,
      limit: allNeeded,
    );

    int otherNeeded = limit - newPosts.length;
    if (otherNeeded > 0) {
      await _loadOtherCountriesPosts(
        loadedIds,
        newPosts,
        excludeCountry: countryCode,
        isInitialLoad: false,
        limit: otherNeeded,
      );
    }

    return newPosts.length;
  }

  // ===========================================================================
  // CHARGEMENT DES DONNÉES SUPPLÉMENTAIRES (SÉPARÉ)
  // ===========================================================================

  Future<void> _loadAllAdditionalDataInParallel() async {
    // Charger tout en parallèle sans bloquer
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
        8, // Limité à 8 pour la performance
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

      final now = DateTime.now();
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

      // Charger les données utilisateurs en arrière-plan
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

      // Mettre à jour l'UI si nécessaire
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
            // Badge de disponibilité
            Positioned(
              top: 8,
              left: 8,
              child: _buildAvailabilityBadge(post),
            ),

            // Contenu du post
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

  // ===========================================================================
  // FILTRES CHIPS (Pour le contenu principal)
  // ===========================================================================

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
  // SECTION CHRONIQUES
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

  // ===========================================================================
  // SECTION PROFILS UTILISATEURS
  // ===========================================================================

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
      // Utiliser votre fonction showUserDetailsModalDialog
     double  width = MediaQuery.of(context).size.width;
     double height = MediaQuery.of(context).size.height;
      showUserDetailsModalDialog(users.first, width, height, context);
    }
  }

  // ===========================================================================
  // SECTION ARTICLES
  // ===========================================================================

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

  // ===========================================================================
  // SECTION CANAUX
  // ===========================================================================

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
    ));
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

    // 4. Posts
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

      // Ajouter des sections spéciales tous les 3 posts
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

  String _getEndMessage() {
    switch (_currentFilter) {
      case 'ALL':
        return 'Vous avez vu tous les contenus disponibles';
      case 'COUNTRY':
        return 'Fin des contenus en ${_selectedCountryCode ?? "ce pays"}';
      case 'MIXED':
        return 'Fin des contenus pour le mix actuel';
      case 'CUSTOM':
        return 'Fin des contenus pour ${_selectedCountryCode ?? "ce pays"}';
      default:
        return 'Fin des contenus';
    }
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
    switch (_currentFilter) {
      case 'ALL':
        return 'Aucun contenu disponible pour tous les pays';
      case 'COUNTRY':
        return 'Aucun contenu disponible en ${_selectedCountryCode ?? "ce pays"}';
      case 'MIXED':
        return 'Aucun contenu disponible pour le moment';
      case 'CUSTOM':
        return 'Aucun contenu disponible pour ${_selectedCountryCode ?? "ce pays"}';
      default:
        return 'Aucun contenu disponible';
    }
  }

  String _getFilterDescription() {
    switch (_currentFilter) {
      case 'ALL':
        return '🌍 Tous les pays';
      case 'COUNTRY':
        return '📍 ${_selectedCountryCode ?? "Mon pays"}';
      case 'MIXED':
        return '🔄 Mix intelligent';
      case 'CUSTOM':
        return '⚙️ ${_selectedCountryCode ?? "Pays spécifique"}';
      default:
        return 'Filtrer par pays';
    }
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
    // Arrêter le chargement background pendant le refresh
    _backgroundLoadTimer?.cancel();

    setState(() {
      _isLoadingPosts = true;
      _isFirstLoad = true;
      _useBackgroundLoading = true; // Réactiver le background
      _backgroundPostsLoaded = 0; // Réinitialiser le compteur
    });

    _resetPagination();
    await _loadInitialPosts();

    // Redémarrer le chargement background
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
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.black,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Découvrir',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 2),
              Text(
                _getFilterDescription(),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
          elevation: 0,
          actions: [
            // Bouton filtre avec icône personnalisée
            InkWell(
              onTap: _showCountryFilterModal,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 36,
                height: 36,
                margin: EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _getFilterBorderColor(),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: _getFilterIcon(),
                ),
              ),
            ),
            // Bouton rafraîchir
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.white, size: 22),
              onPressed: _refreshData,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
            SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: Container(
            color: Colors.black,
            child: _buildContent(),
          ),
        ),
      ),
    );
  }
}

// const Color primaryGreen = Color(0xFF25D366);
// const Color darkBackground = Color(0xFF121212);
// const Color lightBackground = Color(0xFF1E1E1E);
// const Color textColor = Colors.white;
//
// class HomeConstPostPage extends StatefulWidget {
//   HomeConstPostPage({super.key, required this.type, this.sortType});
//
//   final String type;
//   String? sortType;
//
//   @override
//   State<HomeConstPostPage> createState() => _HomeConstPostPageState();
// }
//
// class _HomeConstPostPageState extends State<HomeConstPostPage>
//     with WidgetsBindingObserver, TickerProviderStateMixin {
//   // Variables principales
//   late UserAuthProvider authProvider;
//   late UserShopAuthProvider authProviderShop;
//   late CategorieProduitProvider categorieProduitProvider;
//   late UserProvider userProvider;
//   late PostProvider postProvider;
//   late MixedFeedServiceProvider mixedFeedProvider;
//
//   final ScrollController _scrollController = ScrollController();
//   final Random _random = Random();
//   Color _color = Colors.blue;
//
//   // Paramètres de pagination
//   final int _initialLimit = 6;
//   final int _loadMoreLimit = 8; // Augmenté pour charger plus de posts
//   final int _totalPostsLimit = 2000;
//
//   // États des posts
//   List<Post> _posts = [];
//   bool _isLoadingPosts = true;
//   bool _hasErrorPosts = false;
//   bool _isLoadingMorePosts = false;
//   bool _hasMorePosts = true;
//   DocumentSnapshot? _lastPostDocument;
//   Set<String> _loadedPostIds = Set(); // Pour éviter les doublons
//
//   // Compteurs
//   int _totalPostsLoaded = 0;
//   int _maxPostsToLoad = 200; // Limite max pour éviter les problèmes
// // Variables pour les chroniques
//   List<Chronique> _chroniques = [];
//   bool _isLoadingChroniques = false;
//   Map<String, List<Chronique>> _groupedChroniques = {};
//   final Map<String, Uint8List> _videoThumbnails = {};
//   final Map<String, bool> _userVerificationStatus = {};
//   final Map<String, UserData> _userDataCache = {};
//   // Gestion de la visibilité
//   final Map<String, Timer> _visibilityTimers = {};
//   final Map<String, bool> _postsViewedInSession = {};
//
//   // Autres données
//   List<ArticleData> articles = [];
//   List<UserServiceData> userServices = [];
//   List<Canal> canaux = [];
//   List<UserData> userList = [];
//   late Future<List<UserData>> _futureUsers = Future.value([]);
//
//   // Contrôleurs et clés
//   TextEditingController commentController = TextEditingController();
//   GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//   final FirebaseFirestore firestore = FirebaseFirestore.instance;
//   bool _buttonEnabled = true;
//   RandomColor _randomColor = RandomColor();
//   int postLenght = 8;
//   int limiteUsers = 200;
//   bool is_actualised = false;
//   late AnimationController _starController;
//   late AnimationController _unlikeController;
//
//   // Filtrage par pays
//   String? _selectedCountryCode;
//   bool _showAllCountries = true;
//   bool _showCountryFilter = false;
//   final int _postsPerCountry = 3;
//
//   // Variables pour les chroniques
//   final Set<String> _alreadyViewedPosts = Set<String>();
//   bool _hasDisplayedImmediatePosts = false;
//   bool _isInitialLoadComplete = false;
//   Timer? _backgroundLoadTimer;
//   final Set<String> _displayedPostIds = Set();
//   final Set<String> _displayedChroniqueIds = Set();
//
//   @override
//   void initState() {
//     super.initState();
//
//     // Initialisation des providers
//     authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     authProviderShop = Provider.of<UserShopAuthProvider>(context, listen: false);
//     categorieProduitProvider = Provider.of<CategorieProduitProvider>(context, listen: false);
//     userProvider = Provider.of<UserProvider>(context, listen: false);
//     postProvider = Provider.of<PostProvider>(context, listen: false);
//     mixedFeedProvider = Provider.of<MixedFeedServiceProvider>(context, listen: false);
//
//     print('widget.sortType : ${widget.sortType}');
//
//     // Configuration initiale
//     _initializeData();
//     _setupLifecycleObservers();
//     _initializeAnimations();
//     _setupScrollController();
//   }
//
//   void _setupScrollController() {
//     _scrollController.addListener(_scrollListener);
//   }
//
//   void _setupLifecycleObservers() {
//     WidgetsBinding.instance.addObserver(this);
//     SystemChannels.lifecycle.setMessageHandler((message) {
//       _handleAppLifecycle(message);
//       return Future.value(message);
//     });
//   }
//
//   void _initializeAnimations() {
//     _starController = AnimationController(
//       vsync: this,
//       duration: Duration(milliseconds: 500),
//     );
//     _unlikeController = AnimationController(
//       vsync: this,
//       duration: Duration(milliseconds: 500),
//     );
//   }
//
//   void _initializeData() async {
//     // Récupérer le code pays de l'utilisateur
//     _selectedCountryCode = authProvider.loginUserData.countryData?['countryCode']?.toUpperCase();
//
//     print('countryCode : ${_selectedCountryCode}');
//
//     _showAllCountries = true;
//
//     // Chargement des données supplémentaires
//     _futureUsers = userProvider.getProfileUsers(
//       authProvider.loginUserData.id!,
//       context,
//       limiteUsers,
//     );
//
//     // Réinitialiser la pagination
//     _resetPagination();
//
//     // Charger les posts initiaux
//     await _loadInitialPostsByCountry();
//
//     _loadAdditionalData();
//     _checkAndShowDialog();
//   }
//
//   // 🔥 RÉINITIALISER LA PAGINATION
//   void _resetPagination() {
//     _posts.clear();
//     _loadedPostIds.clear();
//     _lastPostDocument = null;
//     _totalPostsLoaded = 0;
//     _hasMorePosts = true;
//     _isLoadingMorePosts = false;
//   }
//
//   Future<void> _loadAdditionalData() async {
//     try {
//       await authProvider.getAppData();
//
//       final articleResults = await categorieProduitProvider.getArticleBooster(
//           authProvider.loginUserData.countryData?['countryCode']?.toUpperCase() ?? 'TG');
//       final serviceResults = await postProvider.getAllUserServiceHome();
//       final canalResults = await postProvider.getCanauxHome();
//
//       setState(() {
//         articles = articleResults;
//         userServices = serviceResults..shuffle();
//         canaux = canalResults..shuffle();
//       });
//     } catch (e) {
//       print('Error loading additional data: $e');
//     }
//   }
//
//   // 🔥 CHARGEMENT INITIAL DES POSTS PAR PAYS
//   Future<void> _loadInitialPostsByCountry() async {
//     try {
//       setState(() {
//         _isLoadingPosts = true;
//       });
//
//       // Réinitialiser la pagination
//       _resetPagination();
//
//       // Récupérer le code pays de l'utilisateur
//       final userCountryCode = _selectedCountryCode?.toUpperCase();
//
//       if (_showAllCountries) {
//         // MODE "TOUS LES PAYS" - Mélange intelligent
//         print('🌍 Mode: Tous les pays - Récupération mixte');
//         await _loadMixedPostsForAllCountries(userCountryCode);
//       } else if (userCountryCode != null) {
//         // MODE "PAYS SPÉCIFIQUE"
//         print('🎯 Mode: Pays spécifique - ${userCountryCode}');
//         await _loadPostsForSpecificCountry(userCountryCode);
//       } else {
//         // Fallback: Tous les posts
//         print('⚠️ Mode: Fallback - Tous les posts');
//         await _loadAllPostsFallback();
//       }
//
//       setState(() {
//         _isLoadingPosts = false;
//       });
//
//       print('✅ ${_posts.length} posts chargés initialement');
//
//     } catch (e) {
//       print('❌ Error: $e');
//       setState(() {
//         _isLoadingPosts = false;
//         _hasErrorPosts = true;
//       });
//     }
//   }
//
//   // 🔥 MODE "TOUS LES PAYS": Mélange de posts du pays utilisateur + autres
//   Future<void> _loadMixedPostsForAllCountries(String? userCountryCode) async {
//     print('🔄 Chargement mixte pour tous les pays');
//
//     Set<String> loadedPostIds = Set();
//     int targetTotal = _initialLimit;
//
//     // ÉTAPE 1: D'abord les posts du pays de l'utilisateur (priorité)
//     if (userCountryCode != null) {
//       print('🎯 Priorité: Posts du pays $userCountryCode');
//       await _loadCountrySpecificPosts(
//         targetCount: 3,
//         loadedIds: loadedPostIds,
//         countryCode: userCountryCode,
//         isInitialLoad: true,
//       );
//     }
//
//     // ÉTAPE 2: Posts disponibles pour tous les pays (ALL)
//     if (loadedPostIds.length < targetTotal) {
//       final needed = targetTotal - loadedPostIds.length;
//       print('🌐 Compléter avec posts ALL ($needed)');
//       await _loadAllCountriesPosts(
//         targetCount: needed,
//         loadedIds: loadedPostIds,
//         isInitialLoad: true,
//       );
//     }
//
//     // ÉTAPE 3: Posts d'autres pays si nécessaire
//     if (loadedPostIds.length < targetTotal && userCountryCode != null) {
//       final needed = targetTotal - loadedPostIds.length;
//       print('🌍 Compléter avec autres pays ($needed)');
//       await _loadPostsFromOtherCountries(
//         targetCount: needed,
//         loadedIds: loadedPostIds,
//         excludeCountry: userCountryCode,
//         isInitialLoad: true,
//       );
//     }
//
//     // Mettre à jour les IDs chargés
//     _loadedPostIds.addAll(loadedPostIds);
//
//     print('📊 Mix final: ${loadedPostIds.length} posts');
//   }
//
//   // 🔥 MODE "PAYS SPÉCIFIQUE"
//   Future<void> _loadPostsForSpecificCountry(String countryCode) async {
//     print('🎯 Chargement pour pays spécifique: $countryCode');
//
//     Set<String> loadedPostIds = Set();
//     int targetTotal = _initialLimit;
//
//     // ÉTAPE 1: Posts spécifiques au pays
//     await _loadCountrySpecificPosts(
//       targetCount: 4,
//       loadedIds: loadedPostIds,
//       countryCode: countryCode,
//       isInitialLoad: true,
//     );
//
//     // ÉTAPE 2: Posts disponibles pour tous
//     if (loadedPostIds.length < targetTotal) {
//       final needed = targetTotal - loadedPostIds.length;
//       await _loadAllCountriesPosts(
//         targetCount: needed,
//         loadedIds: loadedPostIds,
//         isInitialLoad: true,
//       );
//     }
//
//     // Mettre à jour les IDs chargés
//     _loadedPostIds.addAll(loadedPostIds);
//   }
//
//   // 🔥 FALLBACK: Tous les posts
//   Future<void> _loadAllPostsFallback() async {
//     try {
//       Query query = firestore.collection('Posts')
//           .orderBy("created_at", descending: true)
//           .limit(_initialLimit);
//
//       final snapshot = await query.get();
//
//       _posts = snapshot.docs.map((doc) {
//         try {
//           final post = Post.fromJson(doc.data() as Map<String, dynamic>);
//           post.id = doc.id;
//           post.hasBeenSeenByCurrentUser = _checkIfPostSeen(post);
//           return post;
//         } catch (e) {
//           print('Error parsing post ${doc.id}: $e');
//           return null;
//         }
//       }).where((p) => p != null).cast<Post>().toList();
//
//       // Mettre à jour le dernier document et les IDs
//       if (snapshot.docs.isNotEmpty) {
//         _lastPostDocument = snapshot.docs.last;
//         _loadedPostIds.addAll(_posts.map((p) => p.id!).where((id) => id != null));
//       }
//     } catch (e) {
//       print('❌ Error fallback: $e');
//       rethrow;
//     }
//   }
//
//   // 🔥 Charger posts spécifiques à un pays
//   Future<void> _loadCountrySpecificPosts({
//     required int targetCount,
//     required Set<String> loadedIds,
//     required String countryCode,
//     bool isInitialLoad = false,
//   }) async {
//     if (targetCount <= 0) return;
//
//     try {
//       print('🇨🇺 Chargement posts du pays : $countryCode');
//
//       Query query = firestore.collection('Posts')
//           .where("available_countries", arrayContains: countryCode)
//           .orderBy("created_at", descending: true);
//
//       if (!isInitialLoad && _lastPostDocument != null) {
//         query = query.startAfterDocument(_lastPostDocument!);
//       }
//
//       query = query.limit(targetCount);
//
//       final snapshot = await query.get();
//
//       if (snapshot.docs.isNotEmpty) {
//         _lastPostDocument = snapshot.docs.last;
//       }
//
//       int added = 0;
//       for (var doc in snapshot.docs) {
//         final post = Post.fromJson(doc.data() as Map<String, dynamic>);
//         post.id = doc.id;
//
//         if (!loadedIds.contains(post.id) && !_loadedPostIds.contains(post.id)) {
//           post.hasBeenSeenByCurrentUser = _checkIfPostSeen(post);
//
//           _posts.add(post);
//           loadedIds.add(post.id!);
//           _loadedPostIds.add(post.id!);
//           _totalPostsLoaded++;
//           added++;
//         }
//       }
//
//       print('✅ $added posts du pays ajoutés');
//
//     } catch (e) {
//       print('❌ Erreur pays $countryCode: $e');
//     }
//   }
//
//
//   // 🔥 Charger posts disponibles pour tous les pays
//   Future<void> _loadAllCountriesPosts({
//     required int targetCount,
//     required Set<String> loadedIds,
//     bool isInitialLoad = false,
//   }) async {
//     if (targetCount <= 0) return;
//
//     try {
//       print('🌍 Chargement posts ALL');
//
//       Query query = firestore.collection('Posts')
//           .where("available_countries", arrayContains: "ALL")
//           .orderBy("created_at", descending: true);
//
//       if (!isInitialLoad && _lastPostDocument != null) {
//         query = query.startAfterDocument(_lastPostDocument!);
//       }
//
//       query = query.limit(targetCount);
//
//       final snapshot = await query.get();
//
//       if (snapshot.docs.isNotEmpty) {
//         _lastPostDocument = snapshot.docs.last;
//       }
//
//       int added = 0;
//       for (var doc in snapshot.docs) {
//         final post = Post.fromJson(doc.data() as Map<String, dynamic>);
//         post.id = doc.id;
//
//         if (!loadedIds.contains(post.id) && !_loadedPostIds.contains(post.id)) {
//           post.hasBeenSeenByCurrentUser = _checkIfPostSeen(post);
//
//           _posts.add(post);
//           loadedIds.add(post.id!);
//           _loadedPostIds.add(post.id!);
//           _totalPostsLoaded++;
//           added++;
//         }
//       }
//
//       print('✅ $added posts ALL ajoutés');
//
//     } catch (e) {
//       print('❌ Erreur posts ALL: $e');
//     }
//   }
//
//
//   // 🔥 Charger posts d'autres pays (excluant un pays spécifique)
//   Future<void> _loadPostsFromOtherCountries({
//     required int targetCount,
//     required Set<String> loadedIds,
//     required String excludeCountry,
//     bool isInitialLoad = false,
//   }) async {
//     if (targetCount <= 0) return;
//
//     try {
//       print('🌍 Chargement autres pays (exclure : $excludeCountry)');
//
//       // ⚠️ On ne peut pas faire array-does-not-contain -> Firestore interdit
//       // Donc on charge un pool plus grand et on filtre manuellement
//       Query query = firestore.collection('Posts')
//           .orderBy("created_at", descending: true);
//
//       if (!isInitialLoad && _lastPostDocument != null) {
//         query = query.startAfterDocument(_lastPostDocument!);
//       }
//
//       // On prend large pour filtrer localement
//       query = query.limit(targetCount * 4);
//
//       final snapshot = await query.get();
//
//       if (snapshot.docs.isNotEmpty) {
//         _lastPostDocument = snapshot.docs.last;
//       }
//
//       int added = 0;
//       for (var doc in snapshot.docs) {
//         final post = Post.fromJson(doc.data() as Map<String, dynamic>);
//         post.id = doc.id;
//
//         if (added >= targetCount) break;
//
//         if (loadedIds.contains(post.id) || _loadedPostIds.contains(post.id)) {
//           continue;
//         }
//
//         // 🔥 Filtrage manuel :
//         if (post.availableCountries.contains("ALL")) continue; // déjà géré ailleurs
//         if (post.availableCountries.contains(excludeCountry)) continue;
//
//         post.hasBeenSeenByCurrentUser = _checkIfPostSeen(post);
//
//         _posts.add(post);
//         loadedIds.add(post.id!);
//         _loadedPostIds.add(post.id!);
//         _totalPostsLoaded++;
//         added++;
//       }
//
//       print('✅ $added posts autres pays ajoutés');
//
//     } catch (e) {
//       print('❌ Erreur autres pays: $e');
//     }
//   }
//
//
//
//   // 🔥 Gestion du scroll pour charger plus de posts - CORRIGÉE
//   void _scrollListener() {
//     if (_scrollController.position.pixels >=
//         _scrollController.position.maxScrollExtent - 300 &&
//         !_isLoadingMorePosts &&
//         _hasMorePosts &&
//         _totalPostsLoaded < _maxPostsToLoad) {
//       _loadMorePosts();
//     }
//   }
//
//   // 🔥 CHARGEMENT SUPPLÉMENTAIRE CORRIGÉ
//   Future<void> _loadMorePosts() async {
//     if (_isLoadingMorePosts || !_hasMorePosts || _totalPostsLoaded >= _maxPostsToLoad) {
//       print('🛑 Chargement bloqué - isLoading: $_isLoadingMorePosts, hasMore: $_hasMorePosts, total: $_totalPostsLoaded');
//       return;
//     }
//
//     print('🔄 Début du chargement supplémentaire...');
//
//     setState(() {
//       _isLoadingMorePosts = true;
//     });
//
//     try {
//       // Variables locales pour ce chargement
//       Set<String> loadedThisBatch = Set();
//       int targetForThisBatch = _loadMoreLimit;
//
//       // Stratégie selon le mode de filtrage
//       if (_showAllCountries && _selectedCountryCode != null) {
//         // MODE TOUS LES PAYS avec pays utilisateur
//         final userCountryCode = _selectedCountryCode!;
//
//         // 1. Essayer d'abord les posts du pays utilisateur
//         await _loadCountrySpecificPosts(
//           targetCount: 3,
//           loadedIds: loadedThisBatch,
//           countryCode: userCountryCode,
//           isInitialLoad: false,
//         );
//
//         // 2. Compléter avec posts ALL si nécessaire
//         if (loadedThisBatch.length < targetForThisBatch) {
//           final needed = targetForThisBatch - loadedThisBatch.length;
//           await _loadAllCountriesPosts(
//             targetCount: needed,
//             loadedIds: loadedThisBatch,
//             isInitialLoad: false,
//           );
//         }
//
//         // 3. Compléter avec autres pays si toujours nécessaire
//         if (loadedThisBatch.length < targetForThisBatch) {
//           final needed = targetForThisBatch - loadedThisBatch.length;
//           await _loadPostsFromOtherCountries(
//             targetCount: needed,
//             loadedIds: loadedThisBatch,
//             excludeCountry: userCountryCode,
//             isInitialLoad: false,
//           );
//         }
//
//       } else if (!_showAllCountries && _selectedCountryCode != null) {
//         // MODE PAYS SPÉCIFIQUE
//         await _loadCountrySpecificPosts(
//           targetCount: targetForThisBatch,
//           loadedIds: loadedThisBatch,
//           countryCode: _selectedCountryCode!,
//           isInitialLoad: false,
//         );
//
//         // Si pas assez de posts du pays spécifique, compléter avec posts ALL
//         if (loadedThisBatch.length < targetForThisBatch) {
//           final needed = targetForThisBatch - loadedThisBatch.length;
//           await _loadAllCountriesPosts(
//             targetCount: needed,
//             loadedIds: loadedThisBatch,
//             isInitialLoad: false,
//           );
//         }
//
//       } else {
//         // MODE FALLBACK - Tous les posts
//         Query query = firestore.collection('Posts')
//             .orderBy("created_at", descending: true);
//
//         if (_lastPostDocument != null) {
//           query = query.startAfterDocument(_lastPostDocument!);
//         }
//
//         query = query.limit(_loadMoreLimit);
//
//         final snapshot = await query.get();
//
//         if (snapshot.docs.isNotEmpty) {
//           _lastPostDocument = snapshot.docs.last;
//         }
//
//         final newPosts = snapshot.docs.map((doc) {
//           final post = Post.fromJson(doc.data() as Map<String, dynamic>);
//           post.id = doc.id;
//           post.hasBeenSeenByCurrentUser = _checkIfPostSeen(post);
//           return post;
//         }).toList();
//
//         // Filtrer les doublons
//         final uniqueNewPosts = newPosts.where((post) =>
//         !_loadedPostIds.contains(post.id)).toList();
//
//         for (final post in uniqueNewPosts) {
//           _posts.add(post);
//           _loadedPostIds.add(post.id!);
//           _totalPostsLoaded++;
//         }
//
//         loadedThisBatch.addAll(uniqueNewPosts.map((p) => p.id!));
//       }
//
//       // Mettre à jour l'état "hasMore"
//       final newPostsCount = loadedThisBatch.length;
//       _hasMorePosts = newPostsCount >= (_loadMoreLimit ~/ 2) &&
//           _totalPostsLoaded < _maxPostsToLoad;
//
//       print('''
// ✅ Chargement supplémentaire terminé:
//    - Nouveaux posts: $newPostsCount
//    - Total chargé: $_totalPostsLoaded
//    - Has more: $_hasMorePosts
//    - Dernier document: ${_lastPostDocument?.id ?? 'aucun'}
// ''');
//
//     } catch (e) {
//       print('❌ Erreur chargement supplémentaire: $e');
//       setState(() {
//         _hasMorePosts = false;
//       });
//     } finally {
//       setState(() {
//         _isLoadingMorePosts = false;
//       });
//     }
//   }
//
//   // 🔥 WIDGETS PRINCIPAUX
//
//   Widget _buildPostWithVisibilityDetection(Post post, double width, double height) {
//     return VisibilityDetector(
//       key: Key('post-${post.id}'),
//       onVisibilityChanged: (VisibilityInfo info) {
//         _handleVisibilityChanged(post, info);
//       },
//       child: Container(
//         margin: EdgeInsets.only(bottom: 12),
//         decoration: BoxDecoration(
//           color: darkBackground.withOpacity(0.7),
//           borderRadius: BorderRadius.circular(12),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.2),
//               blurRadius: 6,
//               offset: Offset(0, 2),
//             ),
//           ],
//         ),
//         child: Stack(
//           children: [
//             post.type == PostType.CHALLENGEPARTICIPATION.name
//                 ? LookChallengePostWidget(post: post, height: height, width: width)
//                 : HomePostUsersWidget(
//               post: post,
//               color: _color,
//               height: height * 0.6,
//               width: width,
//               isDegrade: true,
//             ),
//
//             // Badge du pays en haut à gauche
//           ],
//         ),
//       ),
//     );
//   }
//
//   // 🔥 Badge indiquant la disponibilité du post
//
//   // 🔥 SECTION CHRONIQUES - RÉCUPÉRÉES DU SERVICE
//   Widget _buildChroniquesSection() {
//     // Si pas encore chargé, on lance le chargement
//     if (_chroniques.isEmpty && !_isLoadingChroniques) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         _loadChroniques();
//       });
//     }
//
//     // Si en cours de chargement
//     if (_isLoadingChroniques) {
//       return Container(
//         margin: EdgeInsets.symmetric(vertical: 8),
//         decoration: BoxDecoration(
//           color: darkBackground,
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Padding(
//               padding: EdgeInsets.all(12),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     '📝 Chroniques récentes',
//                     style: TextStyle(
//                       color: textColor,
//                       fontSize: 16,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   SizedBox(
//                     width: 20,
//                     height: 20,
//                     child: CircularProgressIndicator(
//                       strokeWidth: 2,
//                       color: Colors.grey,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//             SizedBox(
//               height: 120,
//               child: Center(
//                 child: CircularProgressIndicator(color: primaryGreen),
//               ),
//             ),
//             SizedBox(height: 8),
//           ],
//         ),
//       );
//     }
//
//     // Si pas de chroniques
//     if (_chroniques.isEmpty) {
//       return SizedBox.shrink();
//     }
//
//     // Charger les données si nécessaire
//     if (!_isLoadingChroniques && _groupedChroniques.isEmpty) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         _loadChroniqueData(_chroniques);
//       });
//     }
//
//     // Retourner le widget ChroniqueSectionComponent
//     return ChroniqueSectionComponent(
//       videoThumbnails: _videoThumbnails,
//       userVerificationStatus: _userVerificationStatus,
//       userDataCache: _userDataCache,
//       isLoadingChroniques: _isLoadingChroniques,
//       groupedChroniques: _groupedChroniques,
//     );
//   }
//
// // 🔥 CHARGEMENT DES CHRONIQUES DEPUIS FIREBASE
//   Future<void> _loadChroniques() async {
//     if (_isLoadingChroniques) return;
//
//     setState(() {
//       _isLoadingChroniques = true;
//     });
//
//     try {
//       print('📝 Chargement des chroniques depuis Firebase...');
//
//       final snapshot = await FirebaseFirestore.instance
//           .collection('chroniques')
//           .orderBy('createdAt', descending: true)
//           .limit(20)
//           .get();
//
//       final now = DateTime.now();
//       final List<Chronique> validChroniques = [];
//       final List<String> expiredChroniqueIds = [];
//
//       // 🔥 PARCOURIR ET FILTRER LES CHRONIQUES
//       for (final doc in snapshot.docs) {
//         try {
//           final chronique = Chronique.fromMap(doc.data(), doc.id);
//
//           // Vérifier si la chronique est expirée
//           if (chronique.isExpired) {
//             print('🗑️ Chronique expirée détectée: ${chronique.id}');
//             expiredChroniqueIds.add(chronique.id!);
//           } else {
//             // Calculer le temps restant pour debug
//             final timeLeft = chronique.expiresAt.toDate().difference(now);
//             print('✅ Chronique valide: ${chronique.id} - Type: ${chronique.type} - Expire dans: ${timeLeft.inHours}h');
//             validChroniques.add(chronique);
//           }
//         } catch (e) {
//           print('❌ Erreur parsing chronique ${doc.id}: $e');
//         }
//       }
//
//       // 🔥 SUPPRESSION DES CHRONIQUES EXPIRÉES
//       if (expiredChroniqueIds.isNotEmpty) {
//         await _deleteExpiredChroniques(expiredChroniqueIds);
//       }
//
//       // 🔥 LIMITER AUX PREMIÈRES CHRONIQUES VALIDES
//       _chroniques = validChroniques.take(8).toList();
//
//       print('📊 Chroniques chargées: ${_chroniques.length} valides sur ${snapshot.docs.length}');
//
//     } catch (e) {
//       print('❌ Erreur chargement chroniques: $e');
//       _chroniques = [];
//     } finally {
//       setState(() {
//         _isLoadingChroniques = false;
//       });
//     }
//   }
//
// // 🔥 CHARGEMENT DES DONNÉES DES CHRONIQUES POUR LE WIDGET
//   Future<void> _loadChroniqueData(List<Chronique> chroniques) async {
//     if (_isLoadingChroniques || chroniques.isEmpty) return;
//
//     try {
//       // Grouper par utilisateur
//       _groupedChroniques = _groupChroniquesByUser(chroniques);
//
//       // Charger les statuts de vérification
//       await _loadUserVerificationStatus(chroniques);
//
//       // Charger les données utilisateurs
//       await _loadUserData(chroniques);
//
//       // Générer les thumbnails pour les vidéos
//       await _generateVideoThumbnails(chroniques);
//
//       print('✅ Données chroniques préparées pour ${chroniques.length} chroniques');
//
//     } catch (e) {
//       print('❌ Erreur préparation données chroniques: $e');
//     }
//   }
//
// // 🔥 SUPPRESSION DES CHRONIQUES EXPIRÉES
//   Future<void> _deleteExpiredChroniques(List<String> chroniqueIds) async {
//     try {
//       print('🧹 Suppression de ${chroniqueIds.length} chroniques expirées...');
//
//       // Supprimer par lots de 500 pour éviter les limites
//       for (int i = 0; i < chroniqueIds.length; i += 500) {
//         final batch = FirebaseFirestore.instance.batch();
//         final batchIds = chroniqueIds.sublist(i, min(i + 500, chroniqueIds.length));
//
//         for (final id in batchIds) {
//           batch.delete(FirebaseFirestore.instance.collection('chroniques').doc(id));
//         }
//
//         await batch.commit();
//         print('✅ Lot supprimé: ${batchIds.length} chroniques');
//       }
//
//       print('🎯 Suppression terminée');
//
//     } catch (e) {
//       print('❌ Erreur suppression chroniques expirées: $e');
//     }
//   }
//
// // 🔥 GROUPER LES CHRONIQUES PAR UTILISATEUR
//   Map<String, List<Chronique>> _groupChroniquesByUser(List<Chronique> chroniques) {
//     final grouped = <String, List<Chronique>>{};
//     for (final chronique in chroniques) {
//       grouped[chronique.userId] = [...grouped[chronique.userId] ?? [], chronique];
//     }
//     return grouped;
//   }
//
// // 🔥 CHARGER LE STATUT DE VÉRIFICATION DES UTILISATEURS
//   Future<void> _loadUserVerificationStatus(List<Chronique> chroniques) async {
//     try {
//       final userIds = chroniques.map((c) => c.userId).toSet();
//       for (final userId in userIds) {
//         if (!_userVerificationStatus.containsKey(userId)) {
//           final userDoc = await FirebaseFirestore.instance.collection('Users').doc(userId).get();
//           final isVerified = userDoc.data()?['isVerify'] ?? false;
//           _userVerificationStatus[userId] = isVerified;
//         }
//       }
//     } catch (e) {
//       print('❌ Erreur chargement statut vérification: $e');
//     }
//   }
//
// // 🔥 CHARGER LES DONNÉES DES UTILISATEURS
//   Future<void> _loadUserData(List<Chronique> chroniques) async {
//     try {
//       final userIds = chroniques.map((c) => c.userId).toSet();
//       for (final userId in userIds) {
//         if (!_userDataCache.containsKey(userId)) {
//           final userDoc = await FirebaseFirestore.instance.collection('Users').doc(userId).get();
//           if (userDoc.exists) {
//             final userData = UserData.fromJson(userDoc.data()!);
//             _userDataCache[userId] = userData;
//           }
//         }
//       }
//     } catch (e) {
//       print('❌ Erreur chargement données utilisateurs: $e');
//     }
//   }
//
// // 🔥 GÉNÉRER LES THUMBNAILS DES VIDÉOS
//   Future<void> _generateVideoThumbnails(List<Chronique> chroniques) async {
//     try {
//       final videoChroniques = chroniques.where((c) => c.type == ChroniqueType.VIDEO).toList();
//
//       for (final chronique in videoChroniques) {
//         if (chronique.mediaUrl != null && !_videoThumbnails.containsKey(chronique.id)) {
//           // Générer le thumbnail
//           final thumbnail = await _generateThumbnail(chronique.mediaUrl!);
//           if (thumbnail != null) {
//             _videoThumbnails[chronique.id!] = thumbnail;
//           }
//         }
//       }
//     } catch (e) {
//       print('❌ Erreur génération thumbnails: $e');
//     }
//   }
//
// // 🔥 GÉNÉRER UN THUMBNAIL POUR UNE VIDÉO
//   Future<Uint8List?> _generateThumbnail(String videoUrl) async {
//     try {
//       final uint8list = await VideoThumbnail.thumbnailData(
//         video: videoUrl,
//         imageFormat: ImageFormat.JPEG,
//         maxWidth: 400,
//         quality: 75,
//         timeMs: 1000,
//       );
//       return uint8list;
//     } catch (e) {
//       debugPrint("Erreur génération thumbnail: $e");
//       return null;
//     }
//   }
//
//
//   // 🔥 Widget profil utilisateur
//   Widget homeProfileUsers(UserData user, double w, double h) {
//     List<String> userAbonnesIds = user.userAbonnesIds ?? [];
//     bool alreadySubscribed = userAbonnesIds.contains(authProvider.loginUserData.id);
//
//     return Container(
//       decoration: BoxDecoration(
//         color: darkBackground.withOpacity(0.8),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: primaryGreen.withOpacity(0.3)),
//       ),
//       child: Column(
//         children: [
//           GestureDetector(
//             onTap: () async {
//               await authProvider.getUserById(user.id!).then((users) async {
//                 if (users.isNotEmpty) {
//                   showUserDetailsModalDialog(users.first, w, h, context);
//                 }
//               });
//             },
//             child: Stack(
//               alignment: Alignment.bottomCenter,
//               children: [
//                 Container(
//                   width: w * 0.4,
//                   height: h * 0.2,
//                   child: ClipRRect(
//                     borderRadius: BorderRadius.only(
//                       topLeft: Radius.circular(12),
//                       topRight: Radius.circular(12),
//                     ),
//                     child: CachedNetworkImage(
//                       fit: BoxFit.cover,
//                       imageUrl: user.imageUrl ?? '',
//                       progressIndicatorBuilder: (context, url, downloadProgress) =>
//                           Container(
//                             color: Colors.grey[800],
//                             child: Center(
//                               child: CircularProgressIndicator(
//                                 value: downloadProgress.progress,
//                                 color: primaryGreen,
//                               ),
//                             ),
//                           ),
//                       errorWidget: (context, url, error) => Container(
//                         color: Colors.grey[800],
//                         child: Icon(Icons.person, color: Colors.grey[400], size: 40),
//                       ),
//                     ),
//                   ),
//                 ),
//                 Container(
//                   width: w * 0.4,
//                   padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       colors: [Colors.black87, Colors.transparent],
//                       begin: Alignment.bottomCenter,
//                       end: Alignment.topCenter,
//                     ),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Expanded(
//                             child: Text(
//                               '@${user.pseudo!.startsWith('@') ? user.pseudo!.substring(1) : user.pseudo!}',
//                               style: TextStyle(
//                                 color: textColor,
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.bold,
//                                 overflow: TextOverflow.ellipsis,
//                               ),
//                             ),
//                           ),
//                           if (user.isVerify!) Icon(Icons.verified, color: primaryGreen, size: 14),
//                         ],
//                       ),
//                       SizedBox(height: 4),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Row(
//                             children: [
//                               Icon(Icons.group, size: 10, color: accentYellow),
//                               SizedBox(width: 2),
//                               Text(
//                                 formatNumber(user.userAbonnesIds?.length ?? 0),
//                                 style: TextStyle(
//                                   color: accentYellow,
//                                   fontSize: 10,
//                                   fontWeight: FontWeight.w500,
//                                 ),
//                               ),
//                             ],
//                           ),
//                           countryFlag(user.countryData?['countryCode'] ?? "", size: 16),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           if (!alreadySubscribed)
//             Container(
//               width: double.infinity,
//               padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//               child: ElevatedButton(
//                 onPressed: () async {
//                   await authProvider.getUserById(user.id!).then((users) async {
//                     if (users.isNotEmpty) {
//                       showUserDetailsModalDialog(users.first, w, h, context);
//                     }
//                   });
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: primaryGreen,
//                   foregroundColor: darkBackground,
//                   padding: EdgeInsets.symmetric(vertical: 4),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                 ),
//                 child: Text(
//                   'S\'abonner',
//                   style: TextStyle(
//                     fontSize: 12,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//   // 🔥 Modal de filtre par pays (inchangé)
//   void _showCountryFilterModal() {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (context) {
//         final TextEditingController searchController = TextEditingController();
//
//         return StatefulBuilder(
//           builder: (context, setModalState) {
//             String searchQuery = searchController.text;
//
//             List<AfricanCountry> filteredCountries = AfricanCountry.allCountries
//                 .where((country) {
//               if (searchQuery.isEmpty) return true;
//               return country.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
//                   country.code.toLowerCase().contains(searchQuery.toLowerCase());
//             })
//                 .toList();
//
//             return Container(
//               height: MediaQuery.of(context).size.height * 0.7,
//               decoration: BoxDecoration(
//                 color: darkBackground,
//                 borderRadius: BorderRadius.only(
//                   topLeft: Radius.circular(20),
//                   topRight: Radius.circular(20),
//                 ),
//               ),
//               child: Column(
//                 children: [
//                   Container(
//                     height: 4,
//                     width: 40,
//                     margin: EdgeInsets.only(top: 8),
//                     decoration: BoxDecoration(
//                       color: Colors.grey[600],
//                       borderRadius: BorderRadius.circular(2),
//                     ),
//                   ),
//                   SizedBox(height: 12),
//
//                   Padding(
//                     padding: EdgeInsets.symmetric(horizontal: 16),
//                     child: Row(
//                       children: [
//                         Expanded(
//                           child: Text(
//                             '🌍 Choisir un pays',
//                             style: TextStyle(
//                               color: textColor,
//                               fontSize: 18,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                         ),
//                         IconButton(
//                           icon: Icon(Icons.close, color: Colors.grey[400], size: 20),
//                           onPressed: () => Navigator.pop(context),
//                           padding: EdgeInsets.zero,
//                           constraints: BoxConstraints(),
//                         ),
//                       ],
//                     ),
//                   ),
//
//                   Padding(
//                     padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                     child: Container(
//                       height: 40,
//                       decoration: BoxDecoration(
//                         color: Colors.grey[900],
//                         borderRadius: BorderRadius.circular(10),
//                       ),
//                       child: TextField(
//                         controller: searchController,
//                         onChanged: (value) {
//                           setModalState(() {});
//                         },
//                         style: TextStyle(color: Colors.white, fontSize: 14),
//                         decoration: InputDecoration(
//                           hintText: 'Rechercher un pays...',
//                           hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
//                           prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 18),
//                           border: InputBorder.none,
//                           contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//                           suffixIcon: searchController.text.isNotEmpty
//                               ? IconButton(
//                             icon: Icon(Icons.clear, size: 16, color: Colors.grey[500]),
//                             onPressed: () {
//                               searchController.clear();
//                               setModalState(() {});
//                             },
//                           )
//                               : null,
//                         ),
//                       ),
//                     ),
//                   ),
//
//                   Padding(
//                     padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//                     child: Material(
//                       color: Colors.transparent,
//                       child: InkWell(
//                         onTap: () async {
//                           Navigator.pop(context);
//                           setState(() {
//                             _showAllCountries = true;
//                             _isLoadingPosts = true;
//                           });
//                           await _loadInitialPostsByCountry();
//                         },
//                         borderRadius: BorderRadius.circular(10),
//                         child: Container(
//                           padding: EdgeInsets.all(12),
//                           decoration: BoxDecoration(
//                             color: _showAllCountries ? Color(0xFFE21221) : Colors.grey[900],
//                             borderRadius: BorderRadius.circular(10),
//                             border: Border.all(
//                               color: _showAllCountries ? Color(0xFFFFD700) : Colors.transparent,
//                               width: 2,
//                             ),
//                           ),
//                           child: Row(
//                             children: [
//                               Container(
//                                 width: 32,
//                                 height: 32,
//                                 decoration: BoxDecoration(
//                                   color: Colors.black.withOpacity(0.2),
//                                   borderRadius: BorderRadius.circular(8),
//                                 ),
//                                 child: Center(
//                                   child: Icon(
//                                     Icons.public,
//                                     color: _showAllCountries ? Colors.white : Colors.grey[400],
//                                     size: 18,
//                                   ),
//                                 ),
//                               ),
//                               SizedBox(width: 12),
//                               Expanded(
//                                 child: Column(
//                                   crossAxisAlignment: CrossAxisAlignment.start,
//                                   children: [
//                                     Text(
//                                       'Tous les pays',
//                                       style: TextStyle(
//                                         color: Colors.white,
//                                         fontSize: 14,
//                                         fontWeight: FontWeight.w600,
//                                       ),
//                                     ),
//                                     SizedBox(height: 2),
//                                     Text(
//                                       'Contenu de toute l\'Afrique',
//                                       style: TextStyle(
//                                         color: Colors.grey[400],
//                                         fontSize: 11,
//                                       ),
//                                     ),
//                                   ],
//                                 ),
//                               ),
//                               if (_showAllCountries)
//                                 Icon(Icons.check_circle, color: Color(0xFFFFD700), size: 20),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//
//                   Divider(color: Colors.grey[800], thickness: 1, height: 16),
//
//                   Padding(
//                     padding: EdgeInsets.symmetric(horizontal: 16),
//                     child: Row(
//                       children: [
//                         Text(
//                           'Pays africains',
//                           style: TextStyle(
//                             color: Colors.grey[400],
//                             fontSize: 12,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                         Spacer(),
//                         Text(
//                           '${filteredCountries.length} pays',
//                           style: TextStyle(
//                             color: Colors.grey[500],
//                             fontSize: 11,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   SizedBox(height: 8),
//
//                   Expanded(
//                     child: _buildCountryList(filteredCountries, setModalState),
//                   ),
//                 ],
//               ),
//             );
//           },
//         );
//       },
//     ).then((_) {
//       setState(() {
//         _showCountryFilter = false;
//       });
//     });
//   }
//
//   Widget _buildCountryList(List<AfricanCountry> countries, StateSetter setModalState) {
//     if (countries.isEmpty) {
//       return Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.search_off, color: Colors.grey[600], size: 40),
//             SizedBox(height: 8),
//             Text(
//               'Aucun pays trouvé',
//               style: TextStyle(
//                 color: Colors.grey[500],
//                 fontSize: 14,
//               ),
//             ),
//           ],
//         ),
//       );
//     }
//
//     return ListView.builder(
//       padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//       itemCount: countries.length,
//       itemBuilder: (context, index) {
//         final country = countries[index];
//         final isSelected = !_showAllCountries &&
//             _selectedCountryCode?.toUpperCase() == country.code.toUpperCase();
//
//         return Container(
//           margin: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
//           child: Material(
//             color: Colors.transparent,
//             child: InkWell(
//               onTap: () async {
//                 Navigator.pop(context);
//                 setState(() {
//                   _showAllCountries = false;
//                   _selectedCountryCode = country.code.toUpperCase();
//                   _isLoadingPosts = true;
//                 });
//                 await _loadInitialPostsByCountry();
//               },
//               borderRadius: BorderRadius.circular(8),
//               child: Container(
//                 padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//                 decoration: BoxDecoration(
//                   color: isSelected ? Color(0xFFE21221) : Colors.grey[900],
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(
//                     color: isSelected ? Color(0xFFFFD700) : Colors.transparent,
//                     width: 1.5,
//                   ),
//                 ),
//                 child: Row(
//                   children: [
//                     Text(country.flag, style: TextStyle(fontSize: 20)),
//                     SizedBox(width: 12),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             country.name,
//                             style: TextStyle(
//                               color: Colors.white,
//                               fontSize: 14,
//                               fontWeight: FontWeight.w500,
//                             ),
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                           SizedBox(height: 2),
//                           Text(
//                             country.code,
//                             style: TextStyle(
//                               color: Colors.grey[400],
//                               fontSize: 11,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     if (isSelected)
//                       Container(
//                         width: 20,
//                         height: 20,
//                         decoration: BoxDecoration(
//                           color: Color(0xFFFFD700),
//                           shape: BoxShape.circle,
//                         ),
//                         child: Center(
//                           child: Icon(Icons.check, color: Colors.black, size: 12),
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   // 🔥 Contenu principal avec scroll
//   Widget _buildContentScroll(BuildContext context) {
//     double height = MediaQuery.of(context).size.height;
//     double width = MediaQuery.of(context).size.width;
//
//     if (_isLoadingPosts && _posts.isEmpty) {
//       return _buildLoadingShimmer(width, height);
//     }
//
//     if (_hasErrorPosts && _posts.isEmpty) {
//       return _buildErrorWidget();
//     }
//
//     if (_posts.isEmpty) {
//       return _buildEmptyWidget();
//     }
//
//     // Construire la liste des éléments à afficher
//     List<Widget> contentWidgets = [];
//
//     // 1. 🔥 Section Chroniques (en premier) - depuis le service
//     final chroniquesSection = _buildChroniquesSection();
//     if (chroniquesSection is! SizedBox) {
//       contentWidgets.add(chroniquesSection);
//     }
//
//     // 2. Section Profils utilisateurs
//     contentWidgets.add(_buildProfilesSection());
//
//     // 3. Indicateur de filtre actif
//     if (!_showAllCountries && _selectedCountryCode != null) {
//       contentWidgets.add(
//         Container(
//           padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//           child: Container(
//             padding: EdgeInsets.all(12),
//             decoration: BoxDecoration(
//               color: Color(0xFFE21221).withOpacity(0.2),
//               borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: Color(0xFFE21221)),
//             ),
//             child: Row(
//               children: [
//                 Icon(Icons.filter_alt, color: Color(0xFFE21221), size: 16),
//                 SizedBox(width: 8),
//                 Expanded(
//                   child: Text(
//                     'Filtre actif : ${_selectedCountryCode!.toUpperCase()}',
//                     style: TextStyle(color: textColor, fontSize: 14),
//                   ),
//                 ),
//                 TextButton(
//                   onPressed: () async {
//                     setState(() {
//                       _showAllCountries = true;
//                       _isLoadingPosts = true;
//                     });
//                     await _loadInitialPostsByCountry();
//                   },
//                   child: Text(
//                     'Réinitialiser',
//                     style: TextStyle(color: Color(0xFFFFD600), fontWeight: FontWeight.bold),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//     }
//
//     // 4. Posts avec alternance de sections spéciales
//     String? _lastDisplayedUserId;
//     List<Post> remainingPosts = List.from(_posts);
//     int postIndex = 0;
//
//     while (remainingPosts.isNotEmpty) {
//       Post? nextPost;
//       int foundIndex = -1;
//
//       for (int i = 0; i < remainingPosts.length; i++) {
//         if (remainingPosts[i].user_id != _lastDisplayedUserId) {
//           nextPost = remainingPosts[i];
//           foundIndex = i;
//           break;
//         }
//       }
//
//       if (nextPost == null && remainingPosts.isNotEmpty) {
//         nextPost = remainingPosts.first;
//         foundIndex = 0;
//       }
//
//       if (nextPost != null && foundIndex != -1) {
//         contentWidgets.add(
//           GestureDetector(
//             onTap: () => _navigateToPostDetails(nextPost!),
//             child: _buildPostWithVisibilityDetection(nextPost!, width, height),
//           ),
//         );
//
//         _lastDisplayedUserId = nextPost.user_id;
//         remainingPosts.removeAt(foundIndex);
//         postIndex++;
//
//         // Ajouter des sections spéciales tous les 3 posts
//         if (postIndex % 3 == 0) {
//           if (postIndex % 6 == 3 && articles.isNotEmpty) {
//             contentWidgets.add(_buildBoosterPage(context));
//           } else if (postIndex % 6 == 0 && canaux.isNotEmpty) {
//             contentWidgets.add(_buildCanalPage(context));
//           }
//         }
//       } else {
//         break;
//       }
//     }
//
//     return CustomScrollView(
//       controller: _scrollController,
//       slivers: [
//         SliverList(
//           delegate: SliverChildBuilderDelegate(
//                 (context, index) => contentWidgets[index],
//             childCount: contentWidgets.length,
//           ),
//         ),
//
//         if (_isLoadingMorePosts)
//           SliverToBoxAdapter(
//             child: Container(
//               padding: EdgeInsets.symmetric(vertical: 20),
//               child: Center(
//                 child: Column(
//                   children: [
//                     CircularProgressIndicator(color: primaryGreen),
//                     SizedBox(height: 10),
//                     Text('Chargement de plus de contenus...',
//                         style: TextStyle(color: Colors.grey, fontSize: 12)),
//                   ],
//                 ),
//               ),
//             ),
//           )
//         else if (!_hasMorePosts)
//           SliverToBoxAdapter(
//             child: Container(
//               padding: EdgeInsets.symmetric(vertical: 30),
//               child: Center(
//                 child: Column(
//                   children: [
//                     Icon(Icons.flag, color: Colors.green, size: 40),
//                     SizedBox(height: 10),
//                     Text(
//                       _showAllCountries
//                           ? 'Vous avez vu beaucoup de contenus'
//                           : 'Fin des contenus disponibles en ${_selectedCountryCode!.toUpperCase()}',
//                       style: TextStyle(color: Colors.grey, fontSize: 14),
//                     ),
//                     SizedBox(height: 10),
//                     Text(
//                       'Revenez plus tard pour de nouveaux contenus',
//                       style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
//   // 🔥 Section profils utilisateurs
//   Widget _buildProfilesSection() {
//     double height = MediaQuery.of(context).size.height;
//     double width = MediaQuery.of(context).size.width;
//
//     return FutureBuilder<List<UserData>>(
//       future: _futureUsers,
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting || snapshot.hasError) {
//           return SizedBox(
//             child: _buildShimmerEffect(width, height),
//           );
//         } else {
//           List<UserData> list = snapshot.data!;
//           if (list.isEmpty) return SizedBox.shrink();
//
//           return Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
//                 child: Row(
//                   children: [
//                     Expanded(
//                       child: Text(
//                         '👑 Profils à découvrir',
//                         style: TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                           color: textColor,
//                         ),
//                       ),
//                     ),
//                     SizedBox(width: 10),
//                     Container(
//                       height: 36,
//                       decoration: BoxDecoration(
//                         gradient: LinearGradient(
//                           colors: [Color(0xFFFFD700), Color(0xFF8B0000)],
//                           begin: Alignment.centerLeft,
//                           end: Alignment.centerRight,
//                         ),
//                         borderRadius: BorderRadius.circular(20),
//                         boxShadow: [
//                           BoxShadow(
//                             color: Color(0xFFFFD700).withOpacity(0.3),
//                             blurRadius: 8,
//                             offset: Offset(0, 3),
//                           ),
//                         ],
//                       ),
//                       child: TextButton(
//                         onPressed: () {
//                           Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder: (context) => UsersListPage(),
//                             ),
//                           );
//                         },
//                         style: TextButton.styleFrom(
//                           padding: EdgeInsets.symmetric(horizontal: 16),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(20),
//                           ),
//                         ),
//                         child: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             Text(
//                               'Voir tout',
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontWeight: FontWeight.w600,
//                                 fontSize: 12,
//                               ),
//                             ),
//                             SizedBox(width: 4),
//                             Icon(Icons.arrow_forward, color: Colors.white, size: 14),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               SizedBox(
//                 height: height * 0.3,
//                 child: ListView.builder(
//                   scrollDirection: Axis.horizontal,
//                   itemCount: list.length,
//                   itemBuilder: (context, index) => Container(
//                     margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
//                     width: width * 0.35,
//                     child: homeProfileUsers(list[index], width, height),
//                   ),
//                 ),
//               ),
//             ],
//           );
//         }
//       },
//     );
//   }
//
//   // 🔥 Section booster (articles)
//   Widget _buildBoosterPage(BuildContext context) {
//     double height = MediaQuery.of(context).size.height;
//     double width = MediaQuery.of(context).size.width;
//
//     return Container(
//       margin: EdgeInsets.symmetric(vertical: 8),
//       decoration: BoxDecoration(
//         color: Colors.black,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Row(
//                   children: [
//                     Text('🔥 Produits Boostés',
//                         style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
//                   ],
//                 ),
//                 GestureDetector(
//                   onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HomeAfroshopPage(title: ''))),
//                   child: Row(
//                     children: [
//                       Text('Boutiques', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryGreen)),
//                       SizedBox(width: 4),
//                       Icon(Icons.arrow_forward, color: primaryGreen, size: 16),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           SizedBox(
//             height: height * 0.25,
//             child: ListView.builder(
//               scrollDirection: Axis.horizontal,
//               itemCount: articles.length,
//               itemBuilder: (context, index) => Container(
//                 margin: EdgeInsets.symmetric(horizontal: 8),
//                 width: width * 0.6,
//                 child: ProductWidget(
//                   article: articles[index],
//                   width: width * 0.6,
//                   height: height * 0.25,
//                   isOtherPage: true,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // 🔥 Section canaux
//   Widget _buildCanalPage(BuildContext context) {
//     double height = MediaQuery.of(context).size.height;
//     double width = MediaQuery.of(context).size.width;
//
//     return Container(
//       margin: EdgeInsets.symmetric(vertical: 8),
//       decoration: BoxDecoration(
//         color: Colors.black,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text('📺 Afrolook Canal',
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
//                 GestureDetector(
//                   onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CanalListPage(isUserCanals: false))),
//                   child: Row(
//                     children: [
//                       Text('Voir plus', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryGreen)),
//                       SizedBox(width: 4),
//                       Icon(Icons.arrow_forward, color: primaryGreen, size: 16),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           SizedBox(
//             height: height * 0.18,
//             child: ListView.builder(
//               scrollDirection: Axis.horizontal,
//               itemCount: canaux.length,
//               itemBuilder: (context, index) => Container(
//                 margin: EdgeInsets.symmetric(horizontal: 8),
//                 width: width * 0.3,
//                 child: channelWidget(canaux[index],
//                     height * 0.28,
//                     width * 0.28,
//                     context),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   // 🔥 Méthodes utilitaires existantes
//
//   bool _checkIfPostSeen(Post post) {
//     final currentUserId = authProvider.loginUserData.id;
//     if (currentUserId == null || post.id == null) return false;
//
//     if (_postsViewedInSession.containsKey(post.id)) {
//       return _postsViewedInSession[post.id]!;
//     }
//
//     if (authProvider.loginUserData.viewedPostIds?.contains(post.id!) ?? false) {
//       return true;
//     }
//
//     if (post.users_vue_id?.contains(currentUserId) ?? false) {
//       return true;
//     }
//
//     return false;
//   }
//
//   void _handleVisibilityChanged(Post post, VisibilityInfo info) {
//     final postId = post.id!;
//     _visibilityTimers[postId]?.cancel();
//
//     if (info.visibleFraction > 0.5) {
//       _visibilityTimers[postId] = Timer(Duration(milliseconds: 500), () {
//         if (mounted && info.visibleFraction > 0.5) {
//           _recordPostView(post);
//         }
//       });
//     } else {
//       _visibilityTimers.remove(postId);
//     }
//   }
//
//   Future<void> _recordPostView(Post post) async {
//     final currentUserId = authProvider.loginUserData.id;
//     if (currentUserId == null || post.id == null) return;
//
//     if (_postsViewedInSession.containsKey(post.id!)) {
//       return;
//     }
//
//     try {
//       _postsViewedInSession[post.id!] = true;
//
//       setState(() {
//         post.hasBeenSeenByCurrentUser = true;
//         post.vues = (post.vues ?? 0) + 1;
//         post.users_vue_id ??= [];
//         if (!post.users_vue_id!.contains(currentUserId)) {
//           post.users_vue_id!.add(currentUserId);
//         }
//       });
//
//       final batch = firestore.batch();
//       final postRef = firestore.collection('Posts').doc(post.id);
//       batch.update(postRef, {
//         'vues': FieldValue.increment(1),
//         'users_vue_id': FieldValue.arrayUnion([currentUserId]),
//       });
//
//       final userRef = firestore.collection('Users').doc(currentUserId);
//       batch.update(userRef, {
//         'viewedPostIds': FieldValue.arrayUnion([post.id!]),
//       });
//
//       await batch.commit();
//
//       authProvider.loginUserData.viewedPostIds ??= [];
//       if (!authProvider.loginUserData.viewedPostIds!.contains(post.id!)) {
//         authProvider.loginUserData.viewedPostIds!.add(post.id!);
//       }
//
//     } catch (e) {
//       print('Error recording post view: $e');
//       _postsViewedInSession.remove(post.id!);
//     }
//   }
//
//   Widget _buildLoadingShimmer(double width, double height) {
//     return CustomScrollView(
//       slivers: [
//         SliverToBoxAdapter(
//           child: Container(
//             height: 120,
//             margin: EdgeInsets.all(8),
//             child: ListView.builder(
//               scrollDirection: Axis.horizontal,
//               itemCount: 5,
//               itemBuilder: (context, index) {
//                 return Container(
//                   width: width * 0.22,
//                   margin: EdgeInsets.all(4),
//                   child: Shimmer.fromColors(
//                     baseColor: Colors.grey[800]!,
//                     highlightColor: Colors.grey[700]!,
//                     child: Container(
//                       decoration: BoxDecoration(
//                         color: Colors.grey[800],
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//         ),
//         SliverList(
//           delegate: SliverChildBuilderDelegate(
//                 (context, index) {
//               return Container(
//                 margin: EdgeInsets.all(8),
//                 child: Shimmer.fromColors(
//                   baseColor: Colors.grey[800]!,
//                   highlightColor: Colors.grey[700]!,
//                   child: Container(
//                     height: 400,
//                     decoration: BoxDecoration(
//                       color: Colors.grey[800],
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                   ),
//                 ),
//               );
//             },
//             childCount: 3,
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildErrorWidget() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.error_outline, color: Colors.red, size: 50),
//           SizedBox(height: 16),
//           Text('Erreur de chargement', style: TextStyle(color: Colors.white, fontSize: 16)),
//           SizedBox(height: 8),
//           ElevatedButton(
//             onPressed: () => _initializeData(),
//             child: Text('Réessayer'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildEmptyWidget() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.feed, color: Colors.grey, size: 50),
//           SizedBox(height: 16),
//           Text(
//             _showAllCountries
//                 ? 'Aucun contenu disponible pour le moment'
//                 : 'Aucun contenu disponible en ${_selectedCountryCode?.toUpperCase() ?? "ce pays"}',
//             style: TextStyle(color: Colors.grey, fontSize: 16),
//           ),
//           SizedBox(height: 8),
//           if (!_showAllCountries)
//             ElevatedButton(
//               onPressed: () async {
//                 setState(() {
//                   _showAllCountries = true;
//                   _isLoadingPosts = true;
//                 });
//                 await _loadInitialPostsByCountry();
//               },
//               child: Text('Voir tous les pays'),
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildShimmerEffect(double width, double height) {
//     return Shimmer.fromColors(
//       baseColor: Colors.grey[900]!,
//       highlightColor: Colors.grey[700]!,
//       period: Duration(milliseconds: 1500),
//       child: Container(
//         width: width * 0.22,
//         height: width * 0.22,
//         margin: EdgeInsets.all(4),
//         decoration: BoxDecoration(
//           color: Colors.grey[800],
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: primaryGreen.withOpacity(0.2)),
//         ),
//       ),
//     );
//   }
//
//   void _navigateToPostDetails(Post post) {
//     _recordPostView(post);
//   }
//
//   Future<void> _refreshData() async {
//     setState(() {
//       _isLoadingPosts = true;
//     });
//
//     await _loadInitialPostsByCountry();
//
//     setState(() {
//       _isLoadingPosts = false;
//     });
//   }
//
//   // 🔥 Méthodes utilitaires
//
//   String formatNumber(int number) {
//     if (number >= 1000) {
//       double nombre = number / 1000;
//       return nombre.toStringAsFixed(1) + 'k';
//     } else {
//       return number.toString();
//     }
//   }
//
//   void _handleAppLifecycle(String? message) {
//     if (message?.contains('resume') == true) {
//       _setUserOnline();
//     } else {
//       _setUserOffline();
//     }
//   }
//
//   void _setUserOnline() {
//     if (authProvider.loginUserData != null) {
//       authProvider.loginUserData!.isConnected = true;
//       userProvider.changeState(
//           user: authProvider.loginUserData,
//           state: UserState.ONLINE.name
//       );
//     }
//   }
//
//   void _setUserOffline() {
//     if (authProvider.loginUserData != null) {
//       authProvider.loginUserData!.isConnected = false;
//       userProvider.changeState(
//           user: authProvider.loginUserData,
//           state: UserState.OFFLINE.name
//       );
//     }
//   }
//
//   void _changeColor() {
//     final colors = [Colors.blue, Colors.green, Colors.brown, Colors.blueAccent, Colors.red, Colors.yellow];
//     _color = colors[_random.nextInt(colors.length)];
//   }
//
//   Future<void> _checkAndShowDialog() async {
//     final SharedPreferences prefs = await SharedPreferences.getInstance();
//     bool shouldShow = await hasShownDialogToday();
//
//     if (shouldShow && mounted) {
//       // Votre logique pour afficher le dialogue
//     }
//   }
//
//   Future<bool> hasShownDialogToday() async {
//     final SharedPreferences prefs = await SharedPreferences.getInstance();
//     final String lastShownDateKey = 'lastShownDialogDate2';
//     DateTime now = DateTime.now();
//     String nowDate = DateFormat('dd, MMMM, yyyy').format(now);
//
//     if (prefs.getString(lastShownDateKey) == null ||
//         prefs.getString(lastShownDateKey) != nowDate) {
//       prefs.setString(lastShownDateKey, nowDate);
//       return true;
//     } else {
//       return false;
//     }
//   }
//
//   Widget _getCountryFlagWidget() {
//     if (_selectedCountryCode == null) {
//       return Icon(Icons.public, color: Colors.yellow, size: 14);
//     }
//
//     final country = AfricanCountry.allCountries.firstWhere(
//           (c) => c.code.toUpperCase() == _selectedCountryCode!.toUpperCase(),
//       orElse: () => AfricanCountry(
//           code: _selectedCountryCode!,
//           name: _selectedCountryCode!,
//           flag: '🏳️'
//       ),
//     );
//
//     return Text(
//       country.flag,
//       style: TextStyle(fontSize: 14),
//     );
//   }
//
//   @override
//   void dispose() {
//     _scrollController.dispose();
//     _visibilityTimers.forEach((key, timer) => timer.cancel());
//     _starController.dispose();
//     _unlikeController.dispose();
//     WidgetsBinding.instance.removeObserver(this);
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     _changeColor();
//
//     double height = MediaQuery.of(context).size.height;
//     double width = MediaQuery.of(context).size.width;
//
//     return RefreshIndicator(
//       onRefresh: _refreshData,
//       child: Scaffold(
//         key: _scaffoldKey,
//         backgroundColor: darkBackground,
//         appBar: AppBar(
//           automaticallyImplyLeading: false,
//           backgroundColor: Colors.black,
//           title: Text(
//             'Découvrir',
//             style: TextStyle(
//               fontSize: 18,
//               color: Colors.white,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           elevation: 0,
//           actions: [
//             InkWell(
//               onTap: _showCountryFilterModal,
//               borderRadius: BorderRadius.circular(20),
//               child: Container(
//                 width: 32,
//                 height: 32,
//                 decoration: BoxDecoration(
//                   color: Colors.grey[800],
//                   borderRadius: BorderRadius.circular(20),
//                   border: Border.all(
//                     color: _showAllCountries ? Colors.green : Color(0xFFE21221),
//                     width: 2,
//                   ),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.black.withOpacity(0.3),
//                       blurRadius: 3,
//                       offset: Offset(0, 1),
//                     ),
//                   ],
//                 ),
//                 child: Center(
//                   child: _showAllCountries
//                       ? Icon(Icons.public, color: Colors.white, size: 14)
//                       : _getCountryFlagWidget(),
//                 ),
//               ),
//             ),
//             SizedBox(width: 8),
//             IconButton(
//               icon: Icon(Icons.refresh, color: Colors.white),
//               onPressed: _refreshData,
//             ),
//           ],
//         ),
//         body: SafeArea(
//           child: Container(
//             decoration: BoxDecoration(color: Colors.black),
//             child: _buildContentScroll(context),
//           ),
//         ),
//       ),
//     );
//   }
// }



// import 'dart:async';
// import 'dart:math';
// import 'package:afrotok/pages/canaux/listCanal.dart';
// import 'package:afrotok/pages/challenge/postChallengeWidget.dart';
//
// import 'package:flutter/material.dart';
// import 'package:afrotok/providers/postProvider.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:afrotok/constant/constColors.dart';
// import 'package:afrotok/constant/logo.dart';
// import 'package:afrotok/constant/sizeText.dart';
// import 'package:afrotok/models/model_data.dart';
// import 'package:afrotok/providers/userProvider.dart';
// import 'package:badges/badges.dart' as badges;
// import 'package:flutter/services.dart';
// import 'package:flutter_vector_icons/flutter_vector_icons.dart';
// import 'package:intl/intl.dart';
// import 'package:loading_animation_widget/loading_animation_widget.dart';
// import 'package:popup_menu_plus/popup_menu_plus.dart';
// import 'package:provider/provider.dart';
// import 'package:random_color/random_color.dart';
// import 'package:share_plus/share_plus.dart';
// import 'package:skeletonizer/skeletonizer.dart';
// import 'package:upgrader/upgrader.dart';
// import 'package:url_launcher/url_launcher.dart';
// import '../../constant/custom_theme.dart';
// import '../UserServices/ServiceWidget.dart';
// import '../UserServices/listUserService.dart';
// import '../UserServices/newUserService.dart';
// import '../afroshop/marketPlace/acceuil/home_afroshop.dart';
// import '../afroshop/marketPlace/component.dart';
// import '../afroshop/marketPlace/modalView/bottomSheetModalView.dart';
// import '../auth/authTest/Screens/Welcome/welcome_screen.dart';
// import '../component/showUserDetails.dart';
// import '../../constant/textCustom.dart';
// import '../../models/chatmodels/message.dart';
// import '../../providers/afroshop/authAfroshopProvider.dart';
// import '../../providers/afroshop/categorie_produits_provider.dart';
// import '../../providers/authProvider.dart';
// import 'package:shimmer/shimmer.dart';
// import '../component/consoleWidget.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../listeUserLikepage.dart';
// import '../user/conponent.dart';
// import '../userPosts/postWidgets/postWidgetPage.dart';
// import 'package:visibility_detector/visibility_detector.dart';
//
// const Color primaryGreen = Color(0xFF25D366);
// const Color darkBackground = Color(0xFF121212);
// const Color lightBackground = Color(0xFF1E1E1E);
// const Color textColor = Colors.white;
//
// class HomeConstPostPage extends StatefulWidget {
//    HomeConstPostPage({super.key, required this.type, this.sortType});
//
//   final String type;
//    String? sortType;
//
//   @override
//   State<HomeConstPostPage> createState() => _HomeConstPostPageState();
// }
//
// class _HomeConstPostPageState extends State<HomeConstPostPage>
//     with WidgetsBindingObserver, TickerProviderStateMixin {
//   // Variables principales
//   late UserAuthProvider authProvider;
//   late UserShopAuthProvider authProviderShop;
//   late CategorieProduitProvider categorieProduitProvider;
//   late UserProvider userProvider;
//   late PostProvider postProvider;
//
//   final ScrollController _scrollController = ScrollController();
//   final Random _random = Random();
//   Color _color = Colors.blue;
//
//   // Paramètres de pagination
//   final int _initialLimit = 5;
//   final int _loadMoreLimit = 5;
//   final int _totalPostsLimit = 1000; // Limite totale des posts
//
//   // États des posts
//   List<Post> _posts = [];
//   bool _isLoadingPosts = true;
//   bool _hasErrorPosts = false;
//   bool _isLoadingMorePosts = false;
//   bool _hasMorePosts = true;
//   DocumentSnapshot? _lastPostDocument;
//
//   // Compteurs
//   int _totalPostsLoaded = 0;
//   int _totalPostsInDatabase = 1000;
//
//   // Gestion de la visibilité
//   final Map<String, Timer> _visibilityTimers = {};
//   final Map<String, bool> _postsViewedInSession = {};
//
//   // Autres données
//   List<ArticleData> articles = [];
//   List<UserServiceData> userServices = [];
//   List<Canal> canaux = [];
//   List<UserData> userList = [];
//   late Future<List<UserData>> _futureUsers = Future.value([]);
//
//   // Contrôleurs et clés
//   TextEditingController commentController = TextEditingController();
//   GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
//   final FirebaseFirestore firestore = FirebaseFirestore.instance;
//   bool _buttonEnabled = true;
//   RandomColor _randomColor = RandomColor();
//   int postLenght = 8;
//   int limiteUsers = 200;
//   bool is_actualised = false;
//   late AnimationController _starController;
//   late AnimationController _unlikeController;
//
//   @override
//   void initState() {
//     super.initState();
//
//     // Initialisation des providers
//     authProvider = Provider.of<UserAuthProvider>(context, listen: false);
//     authProviderShop = Provider.of<UserShopAuthProvider>(context, listen: false);
//     categorieProduitProvider = Provider.of<CategorieProduitProvider>(context, listen: false);
//     userProvider = Provider.of<UserProvider>(context, listen: false);
//     postProvider = Provider.of<PostProvider>(context, listen: false);
// printVm('widget.sortType : ${widget.sortType}');
//     // Configuration initiale
//     _initializeData();
//     _setupLifecycleObservers();
//     _initializeAnimations();
//     _setupScrollController();
//   }
//
//   void _setupScrollController() {
//     _scrollController.addListener(_scrollListener);
//   }
//
//   void _setupLifecycleObservers() {
//     WidgetsBinding.instance.addObserver(this);
//     SystemChannels.lifecycle.setMessageHandler((message) {
//       _handleAppLifecycle(message);
//       return Future.value(message);
//     });
//   }
//
//   void _initializeAnimations() {
//     _starController = AnimationController(
//       vsync: this,
//       duration: Duration(milliseconds: 500),
//     );
//     _unlikeController = AnimationController(
//       vsync: this,
//       duration: Duration(milliseconds: 500),
//     );
//   }
//
//   void _initializeData() async {
//
//     // Chargement des données supplémentaires
//     _futureUsers = userProvider.getProfileUsers(
//       authProvider.loginUserData.id!,
//       context,
//       limiteUsers,
//     );
//     // await _getTotalPostsCount(); // Obtenir le nombre total de posts d'abord
//     if (widget.sortType != null) {
//        _loadInitialPosts(widget.sortType);
//     } else {
//        _loadInitialPosts('null');
//     }
//
//
//
//      _loadAdditionalData();
//     _checkAndShowDialog();
//   }
//
//   Future<void> _loadAdditionalData() async {
//     try {
//       await authProvider.getAppData();
//
//       final articleResults = await categorieProduitProvider.getArticleBooster(authProvider.loginUserData.countryData?['countryCode'] ?? 'TG');
//       final serviceResults = await postProvider.getAllUserServiceHome();
//       final canalResults = await postProvider.getCanauxHome();
//
//       setState(() {
//         articles = articleResults;
//         userServices = serviceResults..shuffle();
//         canaux = canalResults..shuffle();
//       });
//     } catch (e) {
//       print('Error loading additional data: $e');
//     }
//   }
//
//   // OBTENIR LE NOMBRE TOTAL DE POSTS
//   Future<void> _getTotalPostsCount() async {
//     try {
//       final query = FirebaseFirestore.instance.collection('Posts')
//           .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
//           .where("type", isEqualTo: PostType.POST.name);
//
//       final snapshot = await query.count().get();
//       _totalPostsInDatabase = snapshot.count!;
//
//       print('📊 Total posts in database: $_totalPostsInDatabase');
//       print('🎯 Posts limit: $_totalPostsLimit');
//
//     } catch (e) {
//       print('Error getting total posts count: $e');
//       _totalPostsInDatabase = 0;
//     }
//   }
//
//   // GESTION DE LA PAGINATION ET CHARGEMENT DES POSTS
//
//   void _scrollListener() {
//     if (_scrollController.position.pixels >=
//         _scrollController.position.maxScrollExtent - 200 &&
//         !_isLoadingMorePosts &&
//         _hasMorePosts &&
//         _totalPostsLoaded < _totalPostsLimit) {
//       _loadMorePosts();
//     }
//   }
//
//   Future<void> _loadInitialPosts(String? sortT) async {
//     try {
//       setState(() {
//         _isLoadingPosts = true;
//         _hasErrorPosts = false;
//         _postsViewedInSession.clear();
//         _totalPostsLoaded = 0;
//       });
//
//       _lastPostDocument = null;
//
//       final currentUserId = authProvider.loginUserData.id;
//
//       // Sélection de l'algorithme en fonction du sortType
//       if (sortT == 'null') {
//         await _loadUnseenPostsFirst(currentUserId);
//       }else if (sortT == 'recent') {
//         await _loadRecentPosts(isInitialLoad: true);
//       } else if (sortT== 'popular') {
//         await _loadPopularPosts(isInitialLoad: true);
//       } else {
//         await _loadUnseenPostsFirst(currentUserId);
//       }
//
//       setState(() {
//         _isLoadingPosts = false;
//       });
//
//     } catch (e) {
//       print('Error loading initial posts: $e');
//       setState(() {
//         _isLoadingPosts = false;
//         _hasErrorPosts = true;
//       });
//     }
//   }
//
//   Future<void> _loadRecentPosts({bool isInitialLoad = true}) async {
//     try {
//       final limit = isInitialLoad ? _initialLimit : _loadMoreLimit;
//
//       Query query = FirebaseFirestore.instance.collection('Posts')
//           // .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
//           // .where("type", isEqualTo: PostType.POST.name)
//           .where("type", whereIn: [PostType.POST.name, PostType.CHALLENGEPARTICIPATION.name])
//
//           .orderBy("created_at", descending: true);
//
//       if (_lastPostDocument != null && !isInitialLoad) {
//         query = query.startAfterDocument(_lastPostDocument!);
//       }
//
//       query = query.limit(limit);
//
//       final snapshot = await query.get();
//
//       if (snapshot.docs.isNotEmpty) {
//         _lastPostDocument = snapshot.docs.last;
//       }
//
//       final newPosts = snapshot.docs.map((doc) {
//         final post = Post.fromJson(doc.data() as Map<String, dynamic>);
//         post.id = doc.id;
//         post.hasBeenSeenByCurrentUser = _checkIfPostSeen(post);
//         return post;
//       }).toList();
//
//       if (isInitialLoad) {
//         _posts = newPosts;
//         _totalPostsLoaded = newPosts.length;
//       } else {
//         _posts.addAll(newPosts);
//         _totalPostsLoaded += newPosts.length;
//       }
//
//       // Vérifier s'il reste des posts à charger
//       _hasMorePosts = newPosts.length == limit && _totalPostsLoaded < _totalPostsLimit;
//
//       print('📥 Chargement ${isInitialLoad ? 'initial' : 'supplémentaire'}: ${newPosts.length} posts');
//       print('📊 Total chargé: $_totalPostsLoaded / $_totalPostsLimit');
//       print('🎯 Has more posts: $_hasMorePosts');
//
//     } catch (e) {
//       print('Error loading recent posts: $e');
//       _hasMorePosts = false;
//     }
//   }
//
//   Future<void> _loadPopularPosts({bool isInitialLoad = true}) async {
//     try {
//       final limit = isInitialLoad ? _initialLimit : _loadMoreLimit;
//       Query query = FirebaseFirestore.instance.collection('Posts')
//           // .where("type", isEqualTo: PostType.POST.name)
//           .where("type", whereIn: [PostType.POST.name, PostType.CHALLENGEPARTICIPATION.name])
//
//           .orderBy("vues", descending: true)
//           .orderBy("created_at", descending: true);
//
//       // Query query = FirebaseFirestore.instance.collection('Posts')
//       //     .where("status", isNotEqualTo: PostStatus.SUPPRIMER.name)
//       //     .where("type", isEqualTo: PostType.POST.name)
//       //     .orderBy("vues", descending: true)
//       //     .orderBy("created_at", descending: true);
//
//       printVm("Début du chargement _lastPostDocument: ${_lastPostDocument}");
//       printVm("Début du chargement isInitialLoad: ${isInitialLoad}");
//
//       if (_lastPostDocument != null && !isInitialLoad) {
//         query = query.startAfterDocument(_lastPostDocument!);
//       }
//
//       query = query.limit(limit);
//
//       final snapshot = await query.get();
//
//       if (snapshot.docs.isNotEmpty) {
//         _lastPostDocument = snapshot.docs.last;
//       }
//
//       final newPosts = snapshot.docs.map((doc) {
//         final post = Post.fromJson(doc.data() as Map<String, dynamic>);
//         post.id = doc.id;
//         post.hasBeenSeenByCurrentUser = _checkIfPostSeen(post);
//         return post;
//       }).toList();
//
//       if (isInitialLoad) {
//         _posts = newPosts;
//         _totalPostsLoaded = newPosts.length;
//       } else {
//
//         _posts.addAll(newPosts);
//         _totalPostsLoaded += newPosts.length;
//       }
//
//       _hasMorePosts = newPosts.length == limit && _totalPostsLoaded < _totalPostsLimit;
//
//       print('📥 Chargement populaire ${isInitialLoad ? 'initial' : 'supplémentaire'}: ${newPosts.length} posts');
//       print('📊 Total chargé: $_totalPostsLoaded / $_totalPostsLimit');
//
//     } catch (e) {
//       print('Error loading popular posts: $e');
//       _hasMorePosts = false;
//     }
//   }
//
//   Future<void> _loadUnseenPostsFirst(String? currentUserId) async {
//     if (currentUserId == null) {
//       await _loadRecentPosts(isInitialLoad: true);
//       return;
//     }
//
//     try {
//       // 🔹 1. Récupérer AppData et UserData
//       final appData = await _getAppData();
//       final userData = await _getUserData(currentUserId);
//
//       final allPostIds = appData.allPostIds ?? [];
//       final viewedPostIds = userData.viewedPostIds ?? [];
//
//       print('🔹 Total posts dans AppData: ${allPostIds.length}');
//       print('🔹 Posts vus par l\'utilisateur: ${viewedPostIds.length}');
//
//       // 🔹 2. Identifier les posts non vus
//       final unseenPostIds = allPostIds
//           .where((postId) => !viewedPostIds.contains(postId))
//           .toList();
//
//       print('🔹 Posts non vus identifiés: ${unseenPostIds.length}');
//
//       List<Post> loadedPosts = [];
//
//       if (unseenPostIds.isNotEmpty) {
//         // 🔹 3. Charger les posts non vus
//         final unseenPosts = await _loadPostsByIds(
//           List<String>.from(unseenPostIds.reversed),
//           limit: _initialLimit,
//           isSeen: false,
//         );
//         loadedPosts.addAll(unseenPosts);
//       }
//
//       // 🔹 4. Si on n'a pas assez de posts, compléter avec des posts vus
//       if (loadedPosts.length < _initialLimit) {
//         final remaining = _initialLimit - loadedPosts.length;
//         final seenPostIds = viewedPostIds
//             .where((postId) => !loadedPosts.any((p) => p.id == postId))
//             .take(remaining)
//             .toList();
//
//         if (seenPostIds.isNotEmpty) {
//           final seenPosts = await _loadPostsByIds(
//             seenPostIds,
//             limit: remaining,
//             isSeen: true,
//           );
//           loadedPosts.addAll(seenPosts);
//         }
//       }
//
//       // 🔹 5. Tri final par date
//       loadedPosts.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
//
//       // 🔹 6. Limiter au nombre exact demandé
//       loadedPosts = loadedPosts.take(_initialLimit).toList();
//
//       _posts = loadedPosts;
//       _totalPostsLoaded = loadedPosts.length;
//
//       // 🔹 7. Mettre à jour le dernier document pour pagination
//       if (_posts.isNotEmpty) {
//         final lastPostId = _posts.last.id;
//         if (lastPostId != null) {
//           _lastPostDocument = await FirebaseFirestore.instance
//               .collection('Posts')
//               .doc(lastPostId)
//               .get();
//         }
//       }
//
//       _hasMorePosts = _totalPostsLoaded < _totalPostsLimit;
//
//       print('✅ Chargement terminé. Total posts: ${_posts.length}');
//       print('📊 Stats: ${_posts.where((p) => !p.hasBeenSeenByCurrentUser!).length} non vus');
//       print('🎯 Has more posts: $_hasMorePosts');
//
//     } catch (e, stack) {
//       print('❌ Erreur lors du chargement des posts non vus: $e');
//       print(stack);
//       // Fallback: charger les posts récents
//       await _loadRecentPosts(isInitialLoad: true);
//     }
//   }
//
//   Future<void> _loadMorePosts() async {
//     if (_isLoadingMorePosts || !_hasMorePosts || _totalPostsLoaded >= _totalPostsLimit) {
//       print('🛑 Chargement bloqué - isLoading: $_isLoadingMorePosts, hasMore: $_hasMorePosts, total: $_totalPostsLoaded/$_totalPostsLimit');
//       return;
//     }
//
//     print('🔄 Début du chargement supplémentaire...');
//
//     setState(() {
//       _isLoadingMorePosts = true;
//     });
//
//     try {
//       final currentUserId = authProvider.loginUserData.id;
//
//       if (widget.sortType == 'recent') {
//         await _loadRecentPosts(isInitialLoad: false);
//       } else if (widget.sortType == 'popular') {
//         await _loadPopularPosts(isInitialLoad: false);
//       } else {
//         await _loadMorePostsByDate(currentUserId);
//       }
//
//       print('✅ Chargement supplémentaire terminé - $_totalPostsLoaded posts au total');
//
//     } catch (e) {
//       print('❌ Erreur chargement supplémentaire: $e');
//       setState(() {
//         _hasMorePosts = false;
//       });
//     } finally {
//       setState(() {
//         _isLoadingMorePosts = false;
//       });
//     }
//   }
//
//   Future<void> _loadMorePostsByDate(String? currentUserId) async {
//     try {
//       if (currentUserId == null) {
//         await _loadRecentPosts(isInitialLoad: false);
//         return;
//       }
//
//       // 🔹 Récupérer les données nécessaires
//       final appData = await _getAppData();
//       final userData = await _getUserData(currentUserId);
//
//       final allPostIds = appData.allPostIds ?? [];
//       final viewedPostIds = userData.viewedPostIds ?? [];
//
//       // 🔹 Identifier les posts non vus non encore chargés
//       final alreadyLoadedPostIds = _posts.map((p) => p.id).toSet();
//       final unseenPostIds = allPostIds.where((postId) =>
//       !viewedPostIds.contains(postId) && !alreadyLoadedPostIds.contains(postId)).toList();
//
//       print('🔹 Posts non vus restants: ${unseenPostIds.length}');
//
//       List<Post> newPosts = [];
//
//       // 🔹 Charger les posts non vus suivants
//       if (unseenPostIds.isNotEmpty) {
//         final unseenPosts = await _loadPostsByIds(unseenPostIds, limit: _loadMoreLimit, isSeen: false);
//         newPosts.addAll(unseenPosts);
//         print('🔹 Posts non vus supplémentaires chargés: ${unseenPosts.length}');
//       }
//
//       // 🔹 Compléter avec des posts vus si nécessaire
//       if (newPosts.length < _loadMoreLimit) {
//         final remainingLimit = _loadMoreLimit - newPosts.length;
//
//         // Charger des posts vus non encore chargés
//         final seenPostIdsToLoad = viewedPostIds
//             .where((postId) => !alreadyLoadedPostIds.contains(postId))
//             .take(remainingLimit)
//             .toList();
//
//         if (seenPostIdsToLoad.isNotEmpty) {
//           final seenPosts = await _loadPostsByIds(seenPostIdsToLoad, limit: remainingLimit, isSeen: true);
//           newPosts.addAll(seenPosts);
//           print('🔹 Posts vus supplémentaires chargés: ${seenPosts.length}');
//         }
//       }
//
//       // 🔹 Ajouter les nouveaux posts à la liste
//       _posts.addAll(newPosts);
//       _totalPostsLoaded += newPosts.length;
//
//       // 🔹 Mettre à jour le dernier document pour la pagination
//       if (_posts.isNotEmpty) {
//         final lastPostId = _posts.last.id;
//         if (lastPostId != null) {
//           final lastDoc = await FirebaseFirestore.instance.collection('Posts').doc(lastPostId).get();
//           _lastPostDocument = lastDoc;
//         }
//       }
//
//       _hasMorePosts = newPosts.length >= _loadMoreLimit && _totalPostsLoaded < _totalPostsLimit;
//
//       print('✅ Chargement supplémentaire terminé. Nouveaux posts: ${newPosts.length}');
//       print('📊 Total posts chargés: $_totalPostsLoaded / $_totalPostsLimit');
//       print('🎯 Has more posts: $_hasMorePosts');
//
//     } catch (e, stack) {
//       print('❌ Erreur chargement supplémentaire des posts: $e');
//       print(stack);
//       _hasMorePosts = false;
//     }
//   }
//
//   // 🔹 Méthode utilitaire pour charger des posts par leurs IDs
//   Future<List<Post>> _loadPostsByIds(List<String> postIds, {required int limit, required bool isSeen}) async {
//     if (postIds.isEmpty) return [];
//
//     final posts = <Post>[];
//     final idsToLoad = postIds.take(limit).toList();
//
//     print('🔹 Chargement de ${idsToLoad.length} posts par ID (isSeen: $isSeen)');
//
//     for (var i = 0; i < idsToLoad.length; i += 10) {
//       final batchIds = idsToLoad.skip(i).take(10).where((id) => id.isNotEmpty).toList();
//       if (batchIds.isEmpty) continue;
//
//       try {
//         final snapshot = await FirebaseFirestore.instance
//             .collection('Posts')
//             .where(FieldPath.documentId, whereIn: batchIds)
//             .get();
//
//         for (var doc in snapshot.docs) {
//           try {
//             final post = Post.fromJson(doc.data());
//             post.id = doc.id;
//             post.hasBeenSeenByCurrentUser = isSeen;
//             posts.add(post);
//           } catch (e) {
//             print('⚠️ Erreur parsing post ${doc.id}: $e');
//           }
//         }
//       } catch (e) {
//         print('❌ Erreur batch chargement posts: $e');
//       }
//     }
//
//     // 🔹 TRI par date la plus récente
//     posts.sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
//
//     return posts;
//   }
//
//   Future<AppDefaultData> _getAppData() async {
//     try {
//       final appDataRef = FirebaseFirestore.instance.collection('AppData').doc('XgkSxKc10vWsJJ2uBraT');
//       final appDataSnapshot = await appDataRef.get();
//
//       if (appDataSnapshot.exists) {
//         return AppDefaultData.fromJson(appDataSnapshot.data() ?? {});
//       }
//
//       return AppDefaultData();
//     } catch (e) {
//       print('Error getting AppData: $e');
//       return AppDefaultData();
//     }
//   }
//
//   Future<UserData> _getUserData(String userId) async {
//     try {
//       final userDoc = await FirebaseFirestore.instance.collection('Users').doc(userId).get();
//
//       if (userDoc.exists) {
//         return UserData.fromJson(userDoc.data() as Map<String, dynamic>);
//       }
//
//       return UserData(viewedPostIds: []);
//     } catch (e) {
//       print('Error getting UserData: $e');
//       return UserData(viewedPostIds: []);
//     }
//   }
//
//   // GESTION DE LA VISIBILITÉ ET DES VUES
//
//   bool _checkIfPostSeen(Post post) {
//     final currentUserId = authProvider.loginUserData.id;
//     if (currentUserId == null || post.id == null) return false;
//
//     // Vérifier dans la session courante
//     if (_postsViewedInSession.containsKey(post.id)) {
//       return _postsViewedInSession[post.id]!;
//     }
//
//     // Vérifier dans les données utilisateur
//     if (authProvider.loginUserData.viewedPostIds?.contains(post.id!) ?? false) {
//       return true;
//     }
//
//     // Vérifier dans les vues du post
//     if (post.users_vue_id?.contains(currentUserId) ?? false) {
//       return true;
//     }
//
//     return false;
//   }
//
//   void _handleVisibilityChanged(Post post, VisibilityInfo info) {
//     final postId = post.id!;
//     _visibilityTimers[postId]?.cancel();
//
//     if (info.visibleFraction > 0.5) {
//       _visibilityTimers[postId] = Timer(Duration(milliseconds: 500), () {
//         if (mounted && info.visibleFraction > 0.5) {
//           _recordPostView(post);
//         }
//       });
//     } else {
//       _visibilityTimers.remove(postId);
//     }
//   }
//
//   Future<void> _recordPostView(Post post) async {
//     final currentUserId = authProvider.loginUserData.id;
//     if (currentUserId == null || post.id == null) return;
//
//     // Vérifier si déjà enregistré dans cette session
//     if (_postsViewedInSession.containsKey(post.id!)) {
//       return;
//     }
//
//     try {
//       // Marquer comme vu dans la session
//       _postsViewedInSession[post.id!] = true;
//
//       // Mettre à jour localement
//       setState(() {
//         post.hasBeenSeenByCurrentUser = true;
//         post.vues = (post.vues ?? 0) + 1;
//         post.users_vue_id ??= [];
//         if (!post.users_vue_id!.contains(currentUserId)) {
//           post.users_vue_id!.add(currentUserId);
//         }
//       });
//
//       // Mettre à jour Firestore (de manière asynchrone)
//       final batch = FirebaseFirestore.instance.batch();
//
//       // Mettre à jour le compteur de vues du post
//       final postRef = FirebaseFirestore.instance.collection('Posts').doc(post.id);
//       batch.update(postRef, {
//         'vues': FieldValue.increment(1),
//         'users_vue_id': FieldValue.arrayUnion([currentUserId]),
//       });
//
//       // Mettre à jour les posts vus par l'utilisateur
//       final userRef = FirebaseFirestore.instance.collection('Users').doc(currentUserId);
//       batch.update(userRef, {
//         'viewedPostIds': FieldValue.arrayUnion([post.id!]),
//       });
//
//       await batch.commit();
//
//       // Mettre à jour les données locales de l'utilisateur
//       authProvider.loginUserData.viewedPostIds ??= [];
//       if (!authProvider.loginUserData.viewedPostIds!.contains(post.id!)) {
//         authProvider.loginUserData.viewedPostIds!.add(post.id!);
//       }
//
//     } catch (e) {
//       print('Error recording post view: $e');
//       // Annuler le marquage local en cas d'erreur
//       _postsViewedInSession.remove(post.id!);
//     }
//   }
//
//   // WIDGETS PRINCIPAUX
//
//   Widget _buildPostWithVisibilityDetection(Post post, double width, double height) {
//     final hasUserSeenPost = post.hasBeenSeenByCurrentUser ?? false;
//
//     return VisibilityDetector(
//       key: Key('post-${post.id}'),
//       onVisibilityChanged: (VisibilityInfo info) {
//         _handleVisibilityChanged(post, info);
//       },
//       child: Container(
//         margin: EdgeInsets.only(bottom: 12),
//         decoration: BoxDecoration(
//           color: darkBackground.withOpacity(0.7),
//           borderRadius: BorderRadius.circular(12),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.2),
//               blurRadius: 6,
//               offset: Offset(0, 2),
//             ),
//           ],
//           border: (!hasUserSeenPost && widget.sortType=="recent"&& widget.sortType=="popular")
//               ? Border.all(color: Colors.green, width: 2)
//               : null,
//         ),
//         child: Stack(
//           children: [
//             post.type==PostType.CHALLENGEPARTICIPATION.name? LookChallengePostWidget(post: post, height: height, width: width)
//            : HomePostUsersWidget(
//               post: post,
//               color: _color,
//               height: height * 0.6,
//               width: width,
//               isDegrade: true,
//             ),
//             if (!hasUserSeenPost)
//               Positioned(
//                 top: 10,
//                 right: 10,
//                 child: Container(
//                   padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                   decoration: BoxDecoration(
//                     color: Colors.green,
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(Icons.fiber_new, color: Colors.white, size: 14),
//                       SizedBox(width: 4),
//                       Text(
//                         'Nouveau',
//                         style: TextStyle(
//                           color: Colors.white,
//                           fontSize: 10,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
//   String? _lastDisplayedUserId;
//
//   Widget _buildContentScroll(BuildContext context) {
//     double height = MediaQuery.of(context).size.height;
//     double width = MediaQuery.of(context).size.width;
//
//     // GESTION DES ÉTATS DE CHARGEMENT
//     if (_isLoadingPosts && _posts.isEmpty) {
//       return _buildLoadingShimmer(width, height);
//     }
//
//     if (_hasErrorPosts && _posts.isEmpty) {
//       return _buildErrorWidget();
//     }
//
//     if (_posts.isEmpty) {
//       return _buildEmptyWidget();
//     }
//
//     // Réinitialiser le dernier utilisateur affiché
//     _lastDisplayedUserId = null;
//
//     // Construire les posts en évitant les successions du même utilisateur
//     List<Widget> postWidgets = [];
//     List<Post> remainingPosts = List.from(_posts);
//
//     while (remainingPosts.isNotEmpty) {
//       // Trouver le prochain post d'un utilisateur différent
//       Post? nextPost;
//       int foundIndex = -1;
//
//       for (int i = 0; i < remainingPosts.length; i++) {
//         if (remainingPosts[i].user_id != _lastDisplayedUserId) {
//           nextPost = remainingPosts[i];
//           foundIndex = i;
//           break;
//         }
//       }
//
//       // Si aucun post d'utilisateur différent n'est trouvé, prendre le premier disponible
//       if (nextPost == null && remainingPosts.isNotEmpty) {
//         nextPost = remainingPosts.first;
//         foundIndex = 0;
//       }
//
//       if (nextPost != null && foundIndex != -1) {
//         // Ajouter le post actuel
//         postWidgets.add(
//           GestureDetector(
//             onTap: () => _navigateToPostDetails(nextPost!),
//             child: _buildPostWithVisibilityDetection(nextPost!, width, height),
//           ),
//         );
//
//         // Mettre à jour le dernier utilisateur affiché
//         _lastDisplayedUserId = nextPost.user_id;
//
//         // Retirer le post de la liste des posts restants
//         remainingPosts.removeAt(foundIndex);
//
//         // Ajouter des boosters et canaux selon le rythme
//         final currentIndex = postWidgets.length;
//
//         // Après chaque 3 posts, alterner entre articles et canaux
//         if (currentIndex % 3 == 0) {
//           final cycleIndex = currentIndex ~/ 3;
//
//           if (cycleIndex % 2 == 1 && articles.isNotEmpty) {
//             // Articles après 3, 9, 15... posts
//             postWidgets.add(_buildBoosterPage(context));
//           } else if (cycleIndex % 2 == 0 && canaux.isNotEmpty) {
//             // Canaux après 6, 12, 18... posts
//             postWidgets.add(_buildCanalPage(context));
//           }
//         }
//       } else {
//         break;
//       }
//     }
//
//     return CustomScrollView(
//       controller: _scrollController,
//       slivers: [
//         // Section profils utilisateurs
//         SliverToBoxAdapter(
//           child: _buildProfilesSection(),
//         ),
//
//         // Section posts (liste principale)
//         SliverList(
//           delegate: SliverChildBuilderDelegate(
//                 (context, index) => postWidgets[index],
//             childCount: postWidgets.length,
//           ),
//         ),
//
//         // Indicateur de chargement
//         if (_isLoadingMorePosts)
//           SliverToBoxAdapter(
//             child: Container(
//               padding: EdgeInsets.symmetric(vertical: 20),
//               child: Center(
//                 child: CircularProgressIndicator(color: Colors.green),
//               ),
//             ),
//           )
//         // Indicateur de fin
//         else if (!_hasMorePosts || _totalPostsLoaded >= _totalPostsLimit)
//           SliverToBoxAdapter(
//             child: Container(
//               padding: EdgeInsets.symmetric(vertical: 20),
//               child: Center(
//                 child: Text(
//                   'Vous avez vu tous les contenus',
//                   style: TextStyle(color: Colors.grey, fontSize: 14),
//                 ),
//               ),
//             ),
//           ),
//       ],
//     );
//   }
//   Widget _buildContentScroll2(BuildContext context) {
//     double height = MediaQuery.of(context).size.height;
//     double width = MediaQuery.of(context).size.width;
//
//     // GESTION DES ÉTATS DE CHARGEMENT
//     if (_isLoadingPosts && _posts.isEmpty) {
//       return _buildLoadingShimmer(width, height);
//     }
//
//     if (_hasErrorPosts && _posts.isEmpty) {
//       return _buildErrorWidget();
//     }
//
//     if (_posts.isEmpty) {
//       return _buildEmptyWidget();
//     }
//
//     // Construire les posts avec boosters et canaux
//     List<Widget> postWidgets = [];
//     for (int i = 0; i < _posts.length; i++) {
//       // Ajouter le post actuel
//       postWidgets.add(
//         GestureDetector(
//           onTap: () => _navigateToPostDetails(_posts[i]),
//           child: _buildPostWithVisibilityDetection(_posts[i], width, height),
//         ),
//       );
//
//       // Après chaque 3 posts, alterner entre articles et canaux
//       if ((i + 1) % 3 == 0) {
//         // Pair : Articles boosters (après 3, 9, 15... posts)
//         // Impair : Canaux (après 6, 12, 18... posts)
//         final cycleIndex = (i + 1) ~/ 3;
//
//         if (cycleIndex % 2 == 1 && articles.isNotEmpty) {
//           // Articles après 3, 9, 15... posts (cycles impairs)
//           postWidgets.add(_buildBoosterPage(context));
//         } else if (cycleIndex % 2 == 0 && canaux.isNotEmpty) {
//           // Canaux après 6, 12, 18... posts (cycles pairs)
//           postWidgets.add(_buildCanalPage(context));
//         }
//       }
//     }
//
//     return CustomScrollView(
//       controller: _scrollController,
//       slivers: [
//         // Section profils utilisateurs
//         SliverToBoxAdapter(
//           child: _buildProfilesSection(),
//         ),
//
//         // Section posts (liste principale)
//         SliverList(
//           delegate: SliverChildBuilderDelegate(
//                 (context, index) => postWidgets[index],
//             childCount: postWidgets.length,
//           ),
//         ),
//
//         // Indicateur de chargement
//         if (_isLoadingMorePosts)
//           SliverToBoxAdapter(
//             child: Container(
//               padding: EdgeInsets.symmetric(vertical: 20),
//               child: Center(
//                 child: CircularProgressIndicator(color: Colors.green),
//               ),
//             ),
//           )
//         // Indicateur de fin
//         else if (!_hasMorePosts || _totalPostsLoaded >= _totalPostsLimit)
//           SliverToBoxAdapter(
//             child: Container(
//               padding: EdgeInsets.symmetric(vertical: 20),
//               child: Center(
//                 child: Text(
//                   'Vous avez vu tous les contenus',
//                   style: TextStyle(color: Colors.grey, fontSize: 14),
//                 ),
//               ),
//             ),
//           ),
//       ],
//     );
//   }
// // AJOUTER CES MÉTHODES DANS VOTRE CLASSE
//
//   Widget _buildLoadingShimmer(double width, double height) {
//     return CustomScrollView(
//       slivers: [
//         // Shimmer pour la section profils
//         SliverToBoxAdapter(
//           child: Container(
//             height: 120,
//             margin: EdgeInsets.all(8),
//             child: ListView.builder(
//               scrollDirection: Axis.horizontal,
//               itemCount: 5,
//               itemBuilder: (context, index) {
//                 return Container(
//                   width: width * 0.22,
//                   margin: EdgeInsets.all(4),
//                   child: Shimmer.fromColors(
//                     baseColor: Colors.grey[800]!,
//                     highlightColor: Colors.grey[700]!,
//                     child: Container(
//                       decoration: BoxDecoration(
//                         color: Colors.grey[800],
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//         ),
//
//         // Shimmer pour les posts
//         SliverList(
//           delegate: SliverChildBuilderDelegate(
//                 (context, index) {
//               return Container(
//                 margin: EdgeInsets.all(8),
//                 child: Shimmer.fromColors(
//                   baseColor: Colors.grey[800]!,
//                   highlightColor: Colors.grey[700]!,
//                   child: Container(
//                     height: 400,
//                     decoration: BoxDecoration(
//                       color: Colors.grey[800],
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                   ),
//                 ),
//               );
//             },
//             childCount: 3,
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildErrorWidget() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.error_outline, color: Colors.red, size: 50),
//           SizedBox(height: 16),
//           Text(
//             'Erreur de chargement',
//             style: TextStyle(color: Colors.white, fontSize: 16),
//           ),
//           SizedBox(height: 8),
//           ElevatedButton(
//             onPressed: () {
//               // Recharger les données
//               _initializeData();
//             },
//             child: Text('Réessayer'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildEmptyWidget() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(Icons.feed, color: Colors.grey, size: 50),
//           SizedBox(height: 16),
//           Text(
//             'Aucun contenu disponible',
//             style: TextStyle(color: Colors.grey, fontSize: 16),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildPostsSection(BuildContext context) {
//     double height = MediaQuery.of(context).size.height;
//     double width = MediaQuery.of(context).size.width;
//
//     if (_isLoadingPosts) {
//       return _buildPostsShimmerEffect(width, height);
//     }
//
//     if (_hasErrorPosts) {
//       return _buildErrorWidget();
//     }
//
//     if (_posts.isEmpty) {
//       return _buildEmptyWidget();
//     }
//
//     List<Widget> postWidgets = [];
//
//     // Construction de la liste des posts avec intégration des boosters et canaux
//     for (int i = 0; i < _posts.length; i++) {
//       // Ajouter un booster tous les 9 posts
//       if (i % 9 == 8 && articles.isNotEmpty) {
//         postWidgets.add(_buildBoosterPage(context));
//       }
//
//       // Ajouter un canal tous les 7 posts
//       if (i % 7 == 6 && canaux.isNotEmpty) {
//         postWidgets.add(_buildCanalPage(context));
//       }
//
//       // Ajouter le post
//       postWidgets.add(
//         GestureDetector(
//           onTap: () => _navigateToPostDetails(_posts[i]),
//           child: _buildPostWithVisibilityDetection(_posts[i], width, height),
//         ),
//       );
//     }
//
//     return SizedBox(
//       height: height, // nécessaire pour CustomScrollView
//       child: CustomScrollView(
//         controller: _scrollController,
//         slivers: [
//           // En-tête de section
//           SliverToBoxAdapter(child: _buildSectionHeader()),
//
//           // Liste des posts
//           SliverList(
//             delegate: SliverChildBuilderDelegate(
//                   (context, index) => postWidgets[index],
//               childCount: postWidgets.length,
//             ),
//           ),
//
//           // Indicateurs de chargement/fin
//           if (_isLoadingMorePosts)
//             SliverToBoxAdapter(child: _buildLoadingIndicator())
//           else if (!_hasMorePosts || _totalPostsLoaded >= _totalPostsLimit)
//             SliverToBoxAdapter(child: _buildEndIndicator()),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildSectionHeader() {
//     String title = 'Derniers Looks';
//     if (widget.sortType == 'recent') title = 'Looks Récents';
//     if (widget.sortType == 'popular') title = 'Looks Populaires';
//
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(
//             title,
//             style: TextStyle(
//               fontSize: 18,
//               fontWeight: FontWeight.bold,
//               color: textColor,
//             ),
//           ),
//           // if (widget.sortType == null)
//             IconButton(
//               icon: Icon(Icons.filter_list, color: primaryGreen),
//               onPressed: _showFilterOptions,
//             ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildLoadingIndicator() {
//     return Container(
//       padding: EdgeInsets.symmetric(vertical: 20),
//       child: Column(
//         children: [
//           LoadingAnimationWidget.flickr(
//             size: 40,
//             leftDotColor: primaryGreen,
//             rightDotColor: accentYellow,
//           ),
//           SizedBox(height: 10),
//           Text(
//             'Chargement de plus de looks...',
//             style: TextStyle(
//               color: Colors.grey,
//               fontSize: 14,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildEndIndicator() {
//     String message = '';
//
//     if (_totalPostsLoaded >= _totalPostsLimit) {
//       message = 'Vous avez atteint la limite de visionnage (${_totalPostsLimit} looks)';
//     } else if (!_hasMorePosts) {
//       message = 'Vous avez vu tous les looks disponibles pour le moment';
//     }
//
//     return Container(
//       padding: EdgeInsets.symmetric(vertical: 30, horizontal: 20),
//       child: Column(
//         children: [
//           Icon(Icons.check_circle_outline, color: primaryGreen, size: 50),
//           SizedBox(height: 16),
//           Text(
//             message,
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               color: Colors.grey,
//               fontSize: 16,
//             ),
//           ),
//           SizedBox(height: 10),
//           Text(
//             'Revenez plus tard pour découvrir de nouveaux looks !',
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               color: Colors.grey[600],
//               fontSize: 14,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//
//
//   Widget _buildPostsShimmerEffect(double width, double height) {
//     return Column(
//       children: List.generate(3, (index) =>
//           Container(
//             margin: EdgeInsets.only(bottom: 16),
//             padding: EdgeInsets.all(12),
//             child: Shimmer.fromColors(
//               baseColor: Colors.grey[800]!,
//               highlightColor: Colors.grey[600]!,
//               child: Column(
//                 children: [
//                   Row(
//                     children: [
//                       CircleAvatar(backgroundColor: Colors.grey[700], radius: 20),
//                       SizedBox(width: 10),
//                       Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Container(width: width * 0.4, height: 14, color: Colors.grey[700]),
//                           SizedBox(height: 6),
//                           Container(width: width * 0.3, height: 12, color: Colors.grey[700]),
//                         ],
//                       ),
//                     ],
//                   ),
//                   SizedBox(height: 16),
//                   Container(width: double.infinity, height: height * 0.3, color: Colors.grey[700]),
//                   SizedBox(height: 16),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceAround,
//                     children: List.generate(3, (i) =>
//                         Container(width: width * 0.2, height: 14, color: Colors.grey[700]),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//       ),
//     );
//   }
//
//   // WIDGETS DES SECTIONS SUPPLÉMENTAIRES
//
//   Widget _buildProfilesSection() {
//     double height = MediaQuery.of(context).size.height;
//     double width = MediaQuery.of(context).size.width;
//
//     return FutureBuilder<List<UserData>>(
//       future: _futureUsers,
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting || snapshot.hasError) {
//           return SizedBox(
//             // height: height * 0.35,
//             child: _buildShimmerEffect(width, height),
//           );
//         } else {
//           List<UserData> list = snapshot.data!;
//           return Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
//                 child: Row(
//                   children: [
//                     Expanded(
//                       child: Text(
//                         '👑 Profils à découvrir',
//                         style: TextStyle(
//                           fontSize: 18,
//                           fontWeight: FontWeight.bold,
//                           color: textColor,
//                         ),
//                       ),
//                     ),
//                     SizedBox(width: 10),
//                     Container(
//                       height: 36,
//                       decoration: BoxDecoration(
//                         gradient: LinearGradient(
//                           colors: [Color(0xFFFFD700), Color(0xFF8B0000)],
//                           begin: Alignment.centerLeft,
//                           end: Alignment.centerRight,
//                         ),
//                         borderRadius: BorderRadius.circular(20),
//                         boxShadow: [
//                           BoxShadow(
//                             color: Color(0xFFFFD700).withOpacity(0.3),
//                             blurRadius: 8,
//                             offset: Offset(0, 3),
//                           ),
//                         ],
//                       ),
//                       child: TextButton(
//                         onPressed: () {
//                           Navigator.push(
//                             context,
//                             MaterialPageRoute(
//                               builder: (context) => UsersListPage(),
//                             ),
//                           );
//                         },
//                         style: TextButton.styleFrom(
//                           padding: EdgeInsets.symmetric(horizontal: 16),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(20),
//                           ),
//                         ),
//                         child: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             Text(
//                               'Voir tout',
//                               style: TextStyle(
//                                 color: Colors.white,
//                                 fontWeight: FontWeight.w600,
//                                 fontSize: 12,
//                               ),
//                             ),
//                             SizedBox(width: 4),
//                             Icon(
//                               Icons.arrow_forward,
//                               color: Colors.white,
//                               size: 14,
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               SizedBox(
//                 height: height * 0.3,
//                 child: ListView.builder(
//                   scrollDirection: Axis.horizontal,
//                   itemCount: list.length,
//                   itemBuilder: (context, index) => Container(
//                     margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
//                     width: width * 0.35,
//                     child: homeProfileUsers(list[index], width, height),
//                   ),
//                 ),
//               ),
//             ],
//           );
//         }
//       },
//     );
//   }
//
//   Widget _buildBoosterPage(BuildContext context) {
//     double height = MediaQuery.of(context).size.height;
//     double width = MediaQuery.of(context).size.width;
//
//     return Container(
//       margin: EdgeInsets.symmetric(vertical: 8),
//       decoration: BoxDecoration(
//         color: Colors.black,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Row(
//                   children: [
//                     Text('🔥 Produits Boostés',
//                         style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
//                   ],
//                 ),
//                 GestureDetector(
//                   onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HomeAfroshopPage(title: ''))),
//                   child: Row(
//                     children: [
//                       Text('Boutiques', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryGreen)),
//                       SizedBox(width: 4),
//                       Icon(Icons.arrow_forward, color: primaryGreen, size: 16),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           SizedBox(
//             height: height * 0.25,
//             child: ListView.builder(
//               scrollDirection: Axis.horizontal,
//               itemCount: articles.length,
//               itemBuilder: (context, index) => Container(
//                 margin: EdgeInsets.symmetric(horizontal: 8),
//                 width: width * 0.6,
//                 child: ProductWidget(
//                   article: articles[index],
//                   width: width * 0.6,
//                   height: height * 0.25,
//                   isOtherPage: true,
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildCanalPage(BuildContext context) {
//     double height = MediaQuery.of(context).size.height;
//     double width = MediaQuery.of(context).size.width;
//
//     return Container(
//       margin: EdgeInsets.symmetric(vertical: 8),
//       decoration: BoxDecoration(
//         color: Colors.black,
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Column(
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(8.0),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 Text('📺 Afrolook Canal',
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
//                 GestureDetector(
//                   onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CanalListPage(isUserCanals: false))),
//                   child: Row(
//                     children: [
//                       Text('Voir plus', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryGreen)),
//                       SizedBox(width: 4),
//                       Icon(Icons.arrow_forward, color: primaryGreen, size: 16),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           SizedBox(
//             height: height * 0.18,
//             child: ListView.builder(
//               scrollDirection: Axis.horizontal,
//               itemCount: canaux.length,
//               itemBuilder: (context, index) => Container(
//                 margin: EdgeInsets.symmetric(horizontal: 8),
//                 width: width * 0.3,
//                 child: channelWidget(canaux[index],
//                 height * 0.28,
//                     width * 0.28,
//                     context),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildShimmerEffect(double width, double height) {
//     return Shimmer.fromColors(
//       baseColor: Colors.grey[900]!,
//       highlightColor: Colors.grey[700]!,
//       period: Duration(milliseconds: 1500),
//       child: Container(
//         width: width * 0.22,
//         height: width * 0.22,
//         margin: EdgeInsets.all(4),
//         decoration: BoxDecoration(
//           color: Colors.grey[800],
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: primaryGreen.withOpacity(0.2)),
//         ),
//       ),
//     );
//   }
//
//   // WIDGETS EXISTANTS
//
//   Widget homeProfileUsers(UserData user, double w, double h) {
//     List<String> userAbonnesIds = user.userAbonnesIds ?? [];
//     bool alreadySubscribed = userAbonnesIds.contains(authProvider.loginUserData.id);
//
//     return Container(
//       decoration: BoxDecoration(
//         color: darkBackground.withOpacity(0.8),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: primaryGreen.withOpacity(0.3)),
//       ),
//       child: Column(
//         children: [
//           GestureDetector(
//             onTap: () async {
//               await authProvider.getUserById(user.id!).then((users) async {
//                 if (users.isNotEmpty) {
//                   showUserDetailsModalDialog(users.first, w, h, context);
//                 }
//               });
//             },
//             child: Stack(
//               alignment: Alignment.bottomCenter,
//               children: [
//                 Container(
//                   width: w * 0.4,
//                   height: h * 0.2,
//                   child: ClipRRect(
//                     borderRadius: BorderRadius.only(
//                       topLeft: Radius.circular(12),
//                       topRight: Radius.circular(12),
//                     ),
//                     child: CachedNetworkImage(
//                       fit: BoxFit.cover,
//                       imageUrl: user.imageUrl ?? '',
//                       progressIndicatorBuilder: (context, url, downloadProgress) =>
//                           Container(
//                             color: Colors.grey[800],
//                             child: Center(
//                               child: CircularProgressIndicator(
//                                 value: downloadProgress.progress,
//                                 color: primaryGreen,
//                               ),
//                             ),
//                           ),
//                       errorWidget: (context, url, error) => Container(
//                         color: Colors.grey[800],
//                         child: Icon(Icons.person, color: Colors.grey[400], size: 40),
//                       ),
//                     ),
//                   ),
//                 ),
//                 Container(
//                   width: w * 0.4,
//                   padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//                   decoration: BoxDecoration(
//                     gradient: LinearGradient(
//                       colors: [Colors.black87, Colors.transparent],
//                       begin: Alignment.bottomCenter,
//                       end: Alignment.topCenter,
//                     ),
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Expanded(
//                             child: Text(
//                               '@${user.pseudo!.startsWith('@') ? user.pseudo!.substring(1) : user.pseudo!}',
//                               style: TextStyle(
//                                 color: textColor,
//                                 fontSize: 12,
//                                 fontWeight: FontWeight.bold,
//                                 overflow: TextOverflow.ellipsis,
//                               ),
//                             ),
//                           ),
//                           if (user.isVerify!) Icon(Icons.verified, color: primaryGreen, size: 14),
//                         ],
//                       ),
//                       SizedBox(height: 4),
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Row(
//                             children: [
//                               Icon(Icons.group, size: 10, color: accentYellow),
//                               SizedBox(width: 2),
//                               Text(
//                                 formatNumber(user.userAbonnesIds?.length ?? 0),
//                                 style: TextStyle(
//                                   color: accentYellow,
//                                   fontSize: 10,
//                                   fontWeight: FontWeight.w500,
//                                 ),
//                               ),
//                             ],
//                           ),
//                           countryFlag(user.countryData?['countryCode'] ?? "", size: 16),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           if (!alreadySubscribed)
//             Container(
//               width: double.infinity,
//               padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
//               child: ElevatedButton(
//                 onPressed: () async {
//                   await authProvider.getUserById(user.id!).then((users) async {
//                     if (users.isNotEmpty) {
//                       showUserDetailsModalDialog(users.first, w, h, context);
//                     }
//                   });
//                 },
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: primaryGreen,
//                   foregroundColor: darkBackground,
//                   padding: EdgeInsets.symmetric(vertical: 4),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                 ),
//                 child: Text(
//                   'S\'abonner',
//                   style: TextStyle(
//                     fontSize: 12,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }
//
//
//   // MÉTHODES D'INTERACTION
//
//   void _showFilterOptions() {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) => Container(
//         padding: EdgeInsets.all(16),
//         decoration: BoxDecoration(
//           color: darkBackground,
//           borderRadius: BorderRadius.only(
//             topLeft: Radius.circular(16),
//             topRight: Radius.circular(16),
//           ),
//         ),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text('Trier par', style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
//             SizedBox(height: 16),
//             ListTile(
//               leading: Icon(Icons.new_releases, color: primaryGreen),
//               title: Text('Posts non vus en premier', style: TextStyle(color: textColor)),
//               onTap: () {
//                 Navigator.pop(context);
//                 _applyFilter(null);
//               },
//             ),
//             ListTile(
//               leading: Icon(Icons.trending_up, color: Colors.orange),
//               title: Text('Posts populaires', style: TextStyle(color: textColor)),
//               onTap: () {
//                 widget.sortType = "popular";
//
//                 Navigator.pop(context);
//                 _applyFilter('popular');
//               },
//             ),
//             ListTile(
//               leading: Icon(Icons.access_time, color: Colors.blue),
//               title: Text('Posts récents', style: TextStyle(color: textColor)),
//               onTap: () {
//                 widget.sortType = "recent";
//                 Navigator.pop(context);
//
//                 _applyFilter('recent');
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
//
//   void _applyFilter(String? sortType) {
//     // Dans une implémentation réelle, vous reconstruiriez le widget avec le nouveau sortType
//     // Pour l'instant, on recharge simplement avec le nouveau filtre
//     // _loadInitialPosts(sortType!);
//     // _initializeData(sortType!);
//     _loadInitialPosts(sortType!);
//   }
//
//   void _navigateToPostDetails(Post post) {
//     _recordPostView(post);
//     // Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailsPage(post: post)));
//   }
//
//   Future<void> _refreshData() async {
//     setState(() {
//       _posts = [];
//       _futureUsers  = Future.value([]);
//       _hasMorePosts = true;
//       _lastPostDocument = null;
//       _totalPostsLoaded = 0;
//       _postsViewedInSession.clear();
//       _visibilityTimers.forEach((key, timer) => timer.cancel());
//       _visibilityTimers.clear();
//     });
//     _futureUsers = userProvider.getProfileUsers(
//       authProvider.loginUserData.id!,
//       context,
//       limiteUsers,
//     );
//     // await _getTotalPostsCount(); // Recalculer le total
//     if(widget.sortType!=null){
//       await _loadInitialPosts(widget.sortType!);
//
//     }else{
//       await _loadInitialPosts("null");
//
//     }}
//
//   // MÉTHODES UTILITAIRES
//
//   String formatNumber(int number) {
//     if (number >= 1000) {
//       double nombre = number / 1000;
//       return nombre.toStringAsFixed(1) + 'k';
//     } else {
//       return number.toString();
//     }
//   }
//
//   Widget countryFlag(String countryCode, {double size = 24}) {
//     if (countryCode.isEmpty) return SizedBox.shrink();
//
//     try {
//       return Container(
//         width: size,
//         height: size,
//         decoration: BoxDecoration(
//           borderRadius: BorderRadius.circular(4),
//           border: Border.all(color: Colors.grey.shade300),
//         ),
//         child: ClipRRect(
//           borderRadius: BorderRadius.circular(4),
//           child: Image.asset(
//             'assets/flags/${countryCode.toLowerCase()}.png',
//             package: 'country_icons',
//             fit: BoxFit.cover,
//             errorBuilder: (context, error, stackTrace) => Icon(Icons.flag, size: size - 8),
//           ),
//         ),
//       );
//     } catch (e) {
//       return Icon(Icons.flag, size: size - 8, color: Colors.grey);
//     }
//   }
//
//   void _handleAppLifecycle(String? message) {
//     if (message?.contains('resume') == true) {
//       _setUserOnline();
//     } else {
//       _setUserOffline();
//     }
//   }
//
//   void _setUserOnline() {
//     if (authProvider.loginUserData != null) {
//       authProvider.loginUserData!.isConnected = true;
//       userProvider.changeState(
//           user: authProvider.loginUserData,
//           state: UserState.ONLINE.name
//       );
//     }
//   }
//
//   void _setUserOffline() {
//     if (authProvider.loginUserData != null) {
//       authProvider.loginUserData!.isConnected = false;
//       userProvider.changeState(
//           user: authProvider.loginUserData,
//           state: UserState.OFFLINE.name
//       );
//     }
//   }
//
//   void _changeColor() {
//     final colors = [Colors.blue, Colors.green, Colors.brown, Colors.blueAccent, Colors.red, Colors.yellow];
//     _color = colors[_random.nextInt(colors.length)];
//   }
//
//   Future<void> _checkAndShowDialog() async {
//     final SharedPreferences prefs = await SharedPreferences.getInstance();
//     bool shouldShow = await hasShownDialogToday();
//
//     if (shouldShow && mounted) {
//       // Votre logique pour afficher le dialogue
//     }
//   }
//
//   Future<bool> hasShownDialogToday() async {
//     final SharedPreferences prefs = await SharedPreferences.getInstance();
//     final String lastShownDateKey = 'lastShownDialogDate2';
//     DateTime now = DateTime.now();
//     String nowDate = DateFormat('dd, MMMM, yyyy').format(now);
//
//     if (prefs.getString(lastShownDateKey) == null ||
//         prefs.getString(lastShownDateKey) != nowDate) {
//       prefs.setString(lastShownDateKey, nowDate);
//       return true;
//     } else {
//       return false;
//     }
//   }
//
//   @override
//   void dispose() {
//     _scrollController.dispose();
//     _visibilityTimers.forEach((key, timer) => timer.cancel());
//     _starController.dispose();
//     _unlikeController.dispose();
//     WidgetsBinding.instance.removeObserver(this);
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     _changeColor();
//
//     double height = MediaQuery.of(context).size.height;
//     double width = MediaQuery.of(context).size.width;
//
//     return RefreshIndicator(
//       onRefresh: _refreshData,
//       child: Scaffold(
//         key: _scaffoldKey,
//         backgroundColor: darkBackground,
//         appBar: AppBar(
//           automaticallyImplyLeading: false,
//           backgroundColor: Colors.black,
//           title: Text(
//             'Découvrir',
//             style: TextStyle(
//               fontSize: 18,
//               color: Colors.white,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//           elevation: 0,
//           actions: [
//             IconButton(
//               icon: Icon(Icons.refresh, color: Colors.white),
//               onPressed: _refreshData,
//             ),
//           ],
//         ),
//         body: SafeArea(
//           child: Container(
//             decoration: BoxDecoration(
// color: Colors.black            ),
//             child: _buildContentScroll(context), // <-- ici
//           ),
//         ),
//       ),
//     );
//   }
// }