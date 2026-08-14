import 'package:afrotok/utils/responsive_sheet.dart';
import 'package:afrotok/pages/afroshop/marketPlace/acceuil/produit_details.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:afrotok/providers/postProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:carousel_slider/carousel_slider.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:dropdown_search/dropdown_search.dart';

import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';

import 'package:flutter/widgets.dart';

import 'package:flutter_vector_icons/flutter_vector_icons.dart';

import 'package:provider/provider.dart';

import 'package:like_button/like_button.dart';

import 'package:share_plus/share_plus.dart';

import '../../../../constant/custom_theme.dart';

import '../../../../models/model_data.dart';

import '../../../../providers/afroshop/authAfroshopProvider.dart';

import '../../../../providers/afroshop/categorie_produits_provider.dart';

import '../../../../providers/authProvider.dart';

import '../../../user/conponent.dart';

import '../component.dart';

import '../new/addProduit.dart';
import 'shop_video_feed.dart';
import '../../../../theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

class HomeAfroshopPage extends StatefulWidget {
  const HomeAfroshopPage({super.key, required this.title});

  final String title;

  @override
  State<HomeAfroshopPage> createState() => _HomePageState();
}

class _HomePageState extends State<HomeAfroshopPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late UserShopAuthProvider authShopProvider =
  Provider.of<UserShopAuthProvider>(context, listen: false);
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);
  late CategorieProduitProvider categorieProduitProvider =
  Provider.of<CategorieProduitProvider>(context, listen: false);

  List<ArticleData> allArticles = [];
  List<ArticleData> displayedArticles = [];
  List<ArticleData> boostedProducts = [];
  List<Categorie> categories = [];

  // Filtres
  int selectedCategoryIndex = -1;
  String selectedCountry = '';
  String selectedPriceRange = '';
  String searchQuery = "";
  String selectedSort = 'createdAt_desc';

  // Ã‰tats de chargement
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isLoadingBoosted = true;
  bool isSearchActive = false;
  bool _hasMoreData = true;

  // Pagination
  final int _pageSize = 5;
  int _currentPage = 0;
  DocumentSnapshot? _lastDocument;
  AppColors? _clrs;

  // CatÃ©gories favorites
  List<String> _favoriteCategories = [];
  bool _showFavoritesOnly = false;

  final _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Filtres disponibles
  final Map<String, String> priceRanges = {
    '': 'Tous les prix',
    '0-10000': '0 - 10.000 FCFA',
    '10000-50000': '10.000 - 50.000 FCFA',
    '50000-100000': '50.000 - 100.000 FCFA',
    '100000-500000': '100.000 - 500.000 FCFA',
    '500000+': '500.000 FCFA et plus',
  };

  final Map<String, String> sortOptions = {
    'createdAt_desc': 'Plus rÃ©cents',
    'createdAt_asc': 'Plus anciens',
    'prix_asc': 'Prix croissant',
    'prix_desc': 'Prix dÃ©croissant',
    'popularite_desc': 'Plus populaires',
  };

  // Liste des codes ISO des pays africains (identique Ã  la page de crÃ©ation)
  final List<String> africanCountries = [
    'TG', 'DZ', 'AO', 'BJ', 'BW', 'BF', 'BI', 'CV', 'CM', 'CF', 'TD', 'KM',
    'CD', 'DJ', 'EG', 'GQ', 'ER', 'SZ', 'ET', 'GA', 'GM', 'GH', 'GN', 'GW',
    'CI', 'KE', 'LS', 'LR', 'LY', 'MG', 'MW', 'ML', 'MR', 'MU', 'MA', 'MZ',
    'NA', 'NE', 'NG', 'RW', 'ST', 'SN', 'SC', 'SL', 'SO', 'ZA', 'SS', 'SD',
    'TZ', 'TN', 'UG', 'ZM', 'ZW'
  ];

  // Mapping des codes pays vers les noms complets
  final Map<String, String> countryNames = {
    'TG': 'Togo',
    'DZ': 'AlgÃ©rie',
    'AO': 'Angola',
    'BJ': 'BÃ©nin',
    'BW': 'Botswana',
    'BF': 'Burkina Faso',
    'BI': 'Burundi',
    'CV': 'Cap-Vert',
    'CM': 'Cameroun',
    'CF': 'RÃ©publique centrafricaine',
    'TD': 'Tchad',
    'KM': 'Comores',
    'CD': 'RÃ©publique dÃ©mocratique du Congo',
    'DJ': 'Djibouti',
    'EG': 'Ã‰gypte',
    'GQ': 'GuinÃ©e Ã©quatoriale',
    'ER': 'Ã‰rythrÃ©e',
    'SZ': 'Eswatini',
    'ET': 'Ã‰thiopie',
    'GA': 'Gabon',
    'GM': 'Gambie',
    'GH': 'Ghana',
    'GN': 'GuinÃ©e',
    'GW': 'GuinÃ©e-Bissau',
    'CI': 'CÃ´te d\'Ivoire',
    'KE': 'Kenya',
    'LS': 'Lesotho',
    'LR': 'LibÃ©ria',
    'LY': 'Libye',
    'MG': 'Madagascar',
    'MW': 'Malawi',
    'ML': 'Mali',
    'MR': 'Mauritanie',
    'MU': 'Maurice',
    'MA': 'Maroc',
    'MZ': 'Mozambique',
    'NA': 'Namibie',
    'NE': 'Niger',
    'NG': 'Nigeria',
    'RW': 'Rwanda',
    'ST': 'Sao TomÃ©-et-Principe',
    'SN': 'SÃ©nÃ©gal',
    'SC': 'Seychelles',
    'SL': 'Sierra Leone',
    'SO': 'Somalie',
    'ZA': 'Afrique du Sud',
    'SS': 'Soudan du Sud',
    'SD': 'Soudan',
    'TZ': 'Tanzanie',
    'TN': 'Tunisie',
    'UG': 'Ouganda',
    'ZM': 'Zambie',
    'ZW': 'Zimbabwe'
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeData();
    _loadFavoriteCategories();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _initializeData() async {
    setState(() {
      _isLoading = true;
      _isLoadingBoosted = true;
    });

    try {
      // DÃ©finir le pays par dÃ©faut de l'utilisateur
      final userCountry = authProvider.loginUserData.countryData?['countryCode'] ?? 'TG';
      setState(() {
        selectedCountry = userCountry;
      });

      // Charger les catÃ©gories
      categories = await categorieProduitProvider.getCategories();

      // Charger les produits boostÃ©s
      _loadBoostedProducts();

      // Charger le premier lot de produits
      await _loadInitialProducts();

    } catch (e) {
      printVm("Error initializing data: $e");
      setState(() {
        _isLoading = false;
        _isLoadingBoosted = false;
      });
    }
  }

  Future<void> _loadFavoriteCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('afroshop_fav_categories') ?? [];
    final isFirstTime = !prefs.containsKey('afroshop_fav_setup_done');
    if (mounted) {
      setState(() => _favoriteCategories = saved);
      if (isFirstTime && categories.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _showCategoryOnboarding());
      }
    }
  }

  Future<void> _saveFavoriteCategories(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('afroshop_fav_categories', ids);
    await prefs.setBool('afroshop_fav_setup_done', true);
    if (mounted) setState(() => _favoriteCategories = ids);
  }

  void _showCategoryOnboarding() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CategoryOnboardingSheet(
        categories: categories,
        initialFavorites: _favoriteCategories,
        onSave: (ids) {
          _saveFavoriteCategories(ids);
          Navigator.pop(context);
        },
        colors: _clrs ?? AppColors.of(context),
      ),
    );
  }

  void _loadBoostedProducts() async {
    try {
      final userCountryCode = authProvider.loginUserData.countryData?['countryCode'] ?? 'TG';

      final boosted = await categorieProduitProvider.getArticleBooster(userCountryCode);
      setState(() {
        boostedProducts = boosted;
        _isLoadingBoosted = false;
      });
    } catch (e) {
      printVm("Error loading boosted products: $e");
      setState(() {
        _isLoadingBoosted = false;
      });
    }
  }

  Future<void> _loadInitialProducts() async {
    try {
      setState(() {
        _isLoading = true;
        allArticles.clear();
        displayedArticles.clear();
        _currentPage = 0;
        _lastDocument = null;
        _hasMoreData = true;
      });

      final articles = await _fetchProductsBatch();
      setState(() {
        allArticles = articles;
        displayedArticles = articles;
        _isLoading = false;
      });
    } catch (e) {
      printVm("Error loading initial products: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<ArticleData>> _fetchProductsBatch() async {
    try {
      Query query = FirebaseFirestore.instance
          .collection('Articles')
          .where('disponible', isEqualTo: true);

      // Appliquer le filtre pays
      if (selectedCountry.isNotEmpty) {
        query = query.where('countryData.countryCode', isEqualTo: selectedCountry);
      }

      // Appliquer le tri
      final sortParts = selectedSort.split('_');
      final sortField = sortParts[0];
      final sortDirection = sortParts[1];
      query = query.orderBy(sortField, descending: sortDirection == 'desc');

      // Pagination
      query = query.limit(_pageSize);
      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }

      final articles = <ArticleData>[];
      for (var doc in snapshot.docs) {
        final article = ArticleData.fromJson(doc.data() as Map<String, dynamic>);
        article.id = doc.id;
        articles.add(article);
      }

      // VÃ©rifier s'il reste des donnÃ©es
      if (snapshot.docs.length < _pageSize) {
        _hasMoreData = false;
      }

      return articles;
    } catch (e) {
      printVm("Error fetching products batch: $e");
      return [];
    }
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final moreArticles = await _fetchProductsBatch();

      if (moreArticles.isNotEmpty) {
        setState(() {
          allArticles.addAll(moreArticles);
          _applyFilters();
        });
      }

      setState(() {
        _isLoadingMore = false;
      });
    } catch (e) {
      printVm("Error loading more products: $e");
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _applyFilters() {
    List<ArticleData> filtered = List.from(allArticles);

    // Filtre par catÃ©gorie
    if (_showFavoritesOnly && _favoriteCategories.isNotEmpty) {
      filtered = filtered.where((article) =>
          _favoriteCategories.contains(article.categorie_id)).toList();
    } else if (selectedCategoryIndex != -1 && categories.isNotEmpty) {
      final selectedCategory = categories[selectedCategoryIndex];
      filtered = filtered.where((article) =>
      article.categorie_id == selectedCategory.id).toList();
    }

    // Filtre par prix
    if (selectedPriceRange.isNotEmpty) {
      filtered = filtered.where((article) {
        final price = article.prix ?? 0;
        switch (selectedPriceRange) {
          case '0-10000':
            return price >= 0 && price <= 10000;
          case '10000-50000':
            return price >= 10000 && price <= 50000;
          case '50000-100000':
            return price >= 50000 && price <= 100000;
          case '100000-500000':
            return price >= 100000 && price <= 500000;
          case '500000+':
            return price >= 500000;
          default:
            return true;
        }
      }).toList();
    }

    // Filtre par recherche
    if (searchQuery.isNotEmpty) {
      filtered = filtered.where((article) =>
      (article.titre?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false) ||
          (article.description?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false))
          .toList();
    }

    setState(() {
      displayedArticles = filtered;
    });
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreProducts();
    }
  }

  void _onCategorySelected(int index) {
    setState(() {
      selectedCategoryIndex = index;
    });
    _applyFilters();
  }

  void _onCountrySelected(String? country) {
    setState(() {
      selectedCountry = country ?? '';
      // RÃ©initialiser la pagination quand le pays change
      _currentPage = 0;
      _lastDocument = null;
      _hasMoreData = true;
    });
    _loadInitialProducts();
  }

  void _onPriceRangeSelected(String? range) {
    setState(() {
      selectedPriceRange = range ?? '';
    });
    _applyFilters();
  }

  void _onSortSelected(String? sort) {
    setState(() {
      selectedSort = sort ?? 'createdAt_desc';
      // RÃ©initialiser la pagination quand le tri change
      _currentPage = 0;
      _lastDocument = null;
      _hasMoreData = true;
    });
    _loadInitialProducts();
  }

  void _onSearch(String query) {
    setState(() {
      searchQuery = query;
    });
    _applyFilters();
  }

  void _toggleSearch() {
    setState(() {
      isSearchActive = !isSearchActive;
      if (!isSearchActive) {
        _searchController.clear();
        searchQuery = "";
        _applyFilters();
      }
    });
  }

  void _showFilterDialog() {
    final colors = _clrs ?? AppColors.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bsCtx) => _FilterBottomSheet(
        colors: colors,
        selectedPriceRange: selectedPriceRange,
        selectedCountry: selectedCountry,
        selectedSort: selectedSort,
        searchQuery: searchQuery,
        priceRanges: priceRanges,
        sortOptions: sortOptions,
        africanCountries: africanCountries,
        countryNames: countryNames,
        defaultCountry: authProvider.loginUserData.countryData?['countryCode'] ?? 'TG',
        onApply: ({required String price, required String country, required String sort}) {
          final countryChanged = country != selectedCountry;
          final sortChanged = sort != selectedSort;
          setState(() {
            selectedPriceRange = price;
            selectedCountry = country;
            selectedSort = sort;
            if (countryChanged || sortChanged) {
              _currentPage = 0; _lastDocument = null; _hasMoreData = true;
            }
          });
          if (countryChanged || sortChanged) {
            _loadInitialProducts();
          } else {
            _applyFilters();
          }
          Navigator.pop(bsCtx);
        },
        onClear: () {
          setState(() {
            selectedPriceRange = '';
            selectedCountry = authProvider.loginUserData.countryData?['countryCode'] ?? 'TG';
            selectedSort = 'createdAt_desc';
            searchQuery = '';
            _searchController.clear();
            _currentPage = 0; _lastDocument = null; _hasMoreData = true;
          });
          _loadInitialProducts();
          Navigator.pop(bsCtx);
        },
      ),
    );
  }

// Nouvelle mÃ©thode pour les chips de filtres actifs
  Widget _buildActiveFilterChip(String label, {required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: CustomConstants.kPrimaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CustomConstants.kPrimaryColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: CustomConstants.kPrimaryColor,
              ),
            ),
            SizedBox(width: 4),
            GestureDetector(
              onTap: onTap,
              child: Icon(
                Icons.close,
                size: 14,
                color: CustomConstants.kPrimaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildFilterSection({required String title, required IconData icon, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: CustomConstants.kPrimaryColor, size: 20),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _clrs!.textPrimary,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final isSelected = selectedCategoryIndex == index;
    return Container(
      margin: EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : _clrs!.textPrimary,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) => _onCategorySelected(selected ? index : -1),
        backgroundColor: _clrs!.surfaceVariant,
        selectedColor: CustomConstants.kPrimaryColor,
        labelPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: StadiumBorder(
          side: BorderSide(
            color: isSelected ? CustomConstants.kPrimaryColor : _clrs!.border,
          ),
        ),
      ),
    );
  }

  void _showBottomSheetCompterNonValide() {
    showResponsiveBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: _clrs!.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: CustomConstants.kPrimaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.business_center,
                      size: 30,
                      color: CustomConstants.kPrimaryColor),
                ),
                SizedBox(height: 15),
                Text(
                  "Compte entreprise requis",
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _clrs!.textPrimary
                  ),
                ),
                SizedBox(height: 15),
                Text(
                  "Pour mettre en ligne un produit, vous devez avoir un compte entreprise. Veuillez crÃ©er un compte entreprise depuis votre profil.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _clrs!.textSecondary, fontSize: 14),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/home_profile_user');
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.business, color: Colors.white),
                      SizedBox(width: 8),
                      Text('CrÃ©er un compte entreprise',
                          style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CustomConstants.kPrimaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final colors = _clrs ?? AppColors.of(context);
    final hasActiveFilters = selectedCategoryIndex != -1 ||
        _showFavoritesOnly ||
        selectedPriceRange.isNotEmpty ||
        searchQuery.isNotEmpty ||
        selectedCountry != (authProvider.loginUserData.countryData?['countryCode'] ?? 'TG');

    return PreferredSize(
      preferredSize: const Size.fromHeight(148),
      child: Container(
        color: colors.surface,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // â”€â”€ Ligne 1 : logo + toggle vidÃ©o/grille + actions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                child: Row(
                  children: [
                    // Logo pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: CustomConstants.kPrimaryColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('AfroShop',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 10),
                    // Toggle vidÃ©o / grille
                    AnimatedBuilder(
                      animation: _tabController,
                      builder: (_, __) => Container(
                        decoration: BoxDecoration(
                          color: colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildTabToggle(Icons.play_circle_filled_rounded, 0, colors),
                            _buildTabToggle(Icons.grid_view_rounded, 1, colors),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Publier
                    GestureDetector(
                      onTap: () => postProvider.getEntreprise(authProvider.loginUserData.id!).then((v) {
                        if (v.isNotEmpty) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => AddNewProduit(entrepriseData: v.first)));
                        } else {
                          _showBottomSheetCompterNonValide();
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: CustomConstants.kPrimaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.add, color: Colors.white, size: 15),
                            SizedBox(width: 4),
                            Text('Publier', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Filtre avec badge
                    GestureDetector(
                      onTap: _showFilterDialog,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 34, height: 34,
                            decoration: BoxDecoration(
                              color: hasActiveFilters
                                  ? CustomConstants.kPrimaryColor.withOpacity(0.12)
                                  : colors.surfaceVariant,
                              shape: BoxShape.circle,
                              border: Border.all(color: hasActiveFilters
                                  ? CustomConstants.kPrimaryColor
                                  : colors.border),
                            ),
                            child: Icon(Icons.tune_rounded,
                                color: hasActiveFilters ? CustomConstants.kPrimaryColor : colors.textSecondary,
                                size: 18),
                          ),
                          if (hasActiveFilters)
                            Positioned(
                              top: -2, right: -2,
                              child: Container(
                                width: 10, height: 10,
                                decoration: BoxDecoration(
                                    color: colors.accent, shape: BoxShape.circle),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // â”€â”€ Ligne 2 : barre de recherche â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: colors.border),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearch,
                    style: TextStyle(color: colors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Rechercher un articleâ€¦',
                      hintStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      prefixIcon: Icon(Icons.search, color: colors.textSecondary, size: 18),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close, size: 16, color: colors.textSecondary),
                              onPressed: () { _searchController.clear(); _onSearch(''); })
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // â”€â”€ Ligne 3 : bandeau catÃ©gories scrollable â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: [
                    if (_favoriteCategories.isNotEmpty)
                      _buildCategoryChip('Mes favoris', -99, colors, icon: Icons.favorite_rounded),
                    _buildCategoryChip('Tous', -1, colors),
                    ...List.generate(categories.length, (i) =>
                        _buildCategoryChip(categories[i].nom ?? '', i, colors)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Divider(height: 1, color: colors.border),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabToggle(IconData icon, int index, AppColors colors) {
    final selected = _tabController.index == index;
    return GestureDetector(
      onTap: () => setState(() => _tabController.animateTo(index)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? CustomConstants.kPrimaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, color: selected ? Colors.white : colors.textSecondary, size: 16),
      ),
    );
  }

  Widget _buildCategoryChip(String label, int index, AppColors colors, {IconData? icon}) {
    final isFavChip = index == -99;
    final isSelected = isFavChip ? _showFavoritesOnly : (!_showFavoritesOnly && selectedCategoryIndex == index);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isFavChip) {
            _showFavoritesOnly = !_showFavoritesOnly;
            if (_showFavoritesOnly) selectedCategoryIndex = -1;
          } else {
            _showFavoritesOnly = false;
            selectedCategoryIndex = index;
          }
        });
        _applyFilters();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? CustomConstants.kPrimaryColor.withOpacity(0.12) : colors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? CustomConstants.kPrimaryColor : colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: isSelected ? CustomConstants.kPrimaryColor : colors.textSecondary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? CustomConstants.kPrimaryColor : colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _clrs!.surface,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: _clrs!.border),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(isSearchActive ? Icons.arrow_back : Icons.search,
                color: CustomConstants.kPrimaryColor),
            onPressed: _toggleSearch,
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: "Rechercher un article...",
                border: InputBorder.none,
                hintStyle: TextStyle(color: _clrs!.textSecondary),
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear, color: _clrs!.textSecondary),
              onPressed: () {
                _searchController.clear();
                _onSearch("");
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCountryIndicator() {
    if (selectedCountry.isEmpty) return SizedBox();

    final countryName = countryNames[selectedCountry] ?? selectedCountry;
    final isDefaultCountry = selectedCountry == (authProvider.loginUserData.countryData?['countryCode'] ?? 'TG');

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDefaultCountry
            ? CustomConstants.kPrimaryColor.withOpacity(0.1)
            : Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDefaultCountry
              ? CustomConstants.kPrimaryColor.withOpacity(0.3)
              : Colors.amber.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flag, size: 16,
              color: isDefaultCountry ? CustomConstants.kPrimaryColor : Colors.amber),
          SizedBox(width: 6),
          Text(
            isDefaultCountry ? 'Produits de votre pays ($countryName)' : 'Produits de $countryName',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDefaultCountry ? CustomConstants.kPrimaryColor : Colors.amber,
            ),
          ),
          SizedBox(width: 8),
          GestureDetector(
            onTap: () => _onCountrySelected(authProvider.loginUserData.countryData?['countryCode'] ?? 'TG'),
            child: Icon(Icons.close, size: 16,
                color: isDefaultCountry ? CustomConstants.kPrimaryColor : Colors.amber),
          ),
        ],
      ),
    );
  }

  Widget _buildBoostedProductsCarousel() {
    if (_isLoadingBoosted) {
      return Container(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(
            color: CustomConstants.kPrimaryColor,
          ),
        ),
      );
    }

    if (boostedProducts.isEmpty) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.local_fire_department,
                    color: Colors.red, size: 20),
              ),
              SizedBox(width: 8),
              Text(
                'Produits BoostÃ©s',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Container(
          child: CarouselSlider(
            items: boostedProducts.map((article) {
              return Builder(
                builder: (BuildContext context) {
                  return ProductWidget(
                    article: article,
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: MediaQuery.of(context).size.height * 0.8,
                    isOtherPage: false,
                  );
                },
              );
            }).toList(),
            options: CarouselOptions(
              autoPlay: true,
              enlargeCenterPage: false,
              viewportFraction: 0.3,
              aspectRatio: 2.5,
              autoPlayInterval: Duration(seconds: 3),
              autoPlayAnimationDuration: Duration(milliseconds: 800),
              autoPlayCurve: Curves.fastOutSlowIn,
            ),
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildProductsGrid() {
    if (_isLoading && displayedArticles.isEmpty) {
      return _buildLoadingGrid();
    }

    if (displayedArticles.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        GridView.builder(
          physics: NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 5,
            mainAxisSpacing: 12,
            childAspectRatio: 0.7,
          ),
          itemCount: displayedArticles.length,
          itemBuilder: (context, index) {
            return ArticleTile(
              article: displayedArticles[index],
              w: MediaQuery.of(context).size.width,
              h: MediaQuery.of(context).size.height,
            );
          },
        ),

        // Skeleton "load more" animé
        if (_isLoadingMore)
          Shimmer.fromColors(
            baseColor: _clrs!.shimmerBase,
            highlightColor: _clrs!.shimmerHighlight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(child: _buildProductSkeleton()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildProductSkeleton()),
                ],
              ),
            ),
          ),

        if (!_hasMoreData && displayedArticles.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                'Vous avez vu tous les produits',
                style: TextStyle(color: _clrs!.textSecondary, fontSize: 13),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingGrid() {
    final colors = _clrs!;
    return Shimmer.fromColors(
      baseColor: colors.shimmerBase,
      highlightColor: colors.shimmerHighlight,
      child: GridView.builder(
        physics: NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.75,
        ),
        itemCount: 6,
        itemBuilder: (context, index) => _buildProductSkeleton(),
      ),
    );
  }

  Widget _buildProductSkeleton() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Container(
              height: 130,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 10),
            // Titre ligne 1
            Container(
              height: 11,
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(height: 5),
            // Titre ligne 2 (plus courte)
            Container(
              height: 11,
              width: 100,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(height: 10),
            // Prix badge
            Container(
              height: 18,
              width: 70,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)),
            ),
            const Spacer(),
            // Stats row
            Row(
              children: [
                Container(height: 22, width: 42, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                const SizedBox(width: 6),
                Container(height: 22, width: 42, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                const SizedBox(width: 6),
                Container(height: 22, width: 42, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: _clrs!.textSecondary),
            SizedBox(height: 16),
            Text(
              "Aucun produit trouvÃ©",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _clrs!.textSecondary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Essayez de modifier vos critÃ¨res de recherche ou de filtres",
              style: TextStyle(
                fontSize: 14,
                color: _clrs!.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  selectedCategoryIndex = -1;
                  selectedCountry = authProvider.loginUserData.countryData?['countryCode'] ?? 'TG';
                  selectedPriceRange = '';
                  selectedSort = 'createdAt_desc';
                  searchQuery = '';
                  _searchController.clear();
                });
                _loadInitialProducts();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: CustomConstants.kPrimaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('RÃ©initialiser les filtres'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _clrs = AppColors.of(context);
    return Scaffold(
      backgroundColor: _clrs!.background,
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        physics: NeverScrollableScrollPhysics(),
        children: [
          // â”€â”€ Onglet VidÃ©os â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          ShopVideoFeed(
            articles: displayedArticles,
            onLoadMore: _loadMoreProducts,
          ),

          // â”€â”€ Onglet Grille â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          RefreshIndicator(
            onRefresh: () async {
              await _loadInitialProducts();
              _loadBoostedProducts();
            },
            color: CustomConstants.kPrimaryColor,
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Produits boostés avec Carousel
                  _buildBoostedProductsCarousel(),

                  // Banner personnalisé si favoris activés
                  if (_showFavoritesOnly && _favoriteCategories.isNotEmpty)
                    _buildPersonalizedBanner(),

                  // En-tête section produits avec compteur et tri
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: CustomConstants.kPrimaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.category,
                              color: CustomConstants.kPrimaryColor, size: 20),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            selectedCategoryIndex == -1
                                ? 'Tous les produits'
                                : 'Produits ${categories[selectedCategoryIndex].nom}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _clrs!.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '${displayedArticles.length} produit(s)',
                          style: TextStyle(
                            fontSize: 12,
                            color: _clrs!.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Grille de produits
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: _buildProductsGrid(),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalizedBanner() {
    final colors = _clrs!;
    return GestureDetector(
      onTap: _showCategoryOnboarding,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: CustomConstants.kPrimaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: CustomConstants.kPrimaryColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: CustomConstants.kPrimaryColor, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Sélection basée sur vos préférences',
                  style: TextStyle(fontSize: 12, color: CustomConstants.kPrimaryColor)),
            ),
            Text('Modifier', style: TextStyle(fontSize: 11, color: CustomConstants.kPrimaryColor, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _FilterBottomSheet extends StatefulWidget {
  final AppColors colors;
  final String selectedPriceRange;
  final String selectedCountry;
  final String selectedSort;
  final String searchQuery;
  final Map<String, String> priceRanges;
  final Map<String, String> sortOptions;
  final List<String> africanCountries;
  final Map<String, String> countryNames;
  final String defaultCountry;
  final void Function({required String price, required String country, required String sort}) onApply;
  final VoidCallback onClear;

  const _FilterBottomSheet({
    required this.colors,
    required this.selectedPriceRange,
    required this.selectedCountry,
    required this.selectedSort,
    required this.searchQuery,
    required this.priceRanges,
    required this.sortOptions,
    required this.africanCountries,
    required this.countryNames,
    required this.defaultCountry,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late String _price;
  late String _country;
  late String _sort;

  @override
  void initState() {
    super.initState();
    _price = widget.selectedPriceRange;
    _country = widget.selectedCountry;
    _sort = widget.selectedSort;
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(4)),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('Filtres', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.textPrimary)),
                const Spacer(),
                TextButton(
                  onPressed: widget.onClear,
                  child: Text('Tout effacer', style: TextStyle(fontSize: 13, color: CustomConstants.kPrimaryColor)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),
          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Prix ──
                  _sectionLabel('Fourchette de prix', c),
                  DropdownButtonFormField<String>(
                    value: _price.isEmpty ? null : _price,
                    dropdownColor: c.surface,
                    style: TextStyle(color: c.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Tous les prix',
                      hintStyle: TextStyle(color: c.textSecondary),
                      filled: true,
                      fillColor: c.surfaceVariant,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: widget.priceRanges.entries.map((e) => DropdownMenuItem(value: e.key.isEmpty ? null : e.key, child: Text(e.value))).toList(),
                    onChanged: (v) => setState(() => _price = v ?? ''),
                  ),
                  const SizedBox(height: 16),
                  // ── Pays ──
                  _sectionLabel('Pays / Région', c),
                  DropdownButtonFormField<String>(
                    value: _country.isEmpty ? null : _country,
                    dropdownColor: c.surface,
                    style: TextStyle(color: c.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Tous les pays',
                      hintStyle: TextStyle(color: c.textSecondary),
                      filled: true,
                      fillColor: c.surfaceVariant,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: widget.africanCountries.map((code) {
                      final name = widget.countryNames[code] ?? code;
                      return DropdownMenuItem(value: code, child: Text('$name ($code)'));
                    }).toList(),
                    onChanged: (v) => setState(() => _country = v ?? widget.defaultCountry),
                  ),
                  const SizedBox(height: 16),
                  // ── Tri ──
                  _sectionLabel('Trier par', c),
                  ...widget.sortOptions.entries.map((e) => GestureDetector(
                    onTap: () => setState(() => _sort = e.key),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: _sort == e.key ? CustomConstants.kPrimaryColor.withOpacity(0.08) : c.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _sort == e.key ? CustomConstants.kPrimaryColor : c.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(e.value, style: TextStyle(fontSize: 13, color: _sort == e.key ? CustomConstants.kPrimaryColor : c.textPrimary))),
                          if (_sort == e.key)
                            Icon(Icons.check_circle_rounded, color: CustomConstants.kPrimaryColor, size: 18),
                        ],
                      ),
                    ),
                  )),
                  const SizedBox(height: 8),
                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => widget.onApply(price: _price, country: _country, sort: _sort),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CustomConstants.kPrimaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Appliquer les filtres', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, AppColors c) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textSecondary, letterSpacing: .4)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Category onboarding sheet
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryOnboardingSheet extends StatefulWidget {
  final List<Categorie> categories;
  final List<String> initialFavorites;
  final void Function(List<String> ids) onSave;
  final AppColors colors;

  const _CategoryOnboardingSheet({
    required this.categories,
    required this.initialFavorites,
    required this.onSave,
    required this.colors,
  });

  @override
  State<_CategoryOnboardingSheet> createState() => _CategoryOnboardingSheetState();
}

class _CategoryOnboardingSheetState extends State<_CategoryOnboardingSheet> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialFavorites.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(4)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vos catégories préférées',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: c.textPrimary)),
                const SizedBox(height: 4),
                Text('Sélectionnez au moins 2 — votre fil sera personnalisé',
                    style: TextStyle(fontSize: 13, color: c.textSecondary)),
              ],
            ),
          ),
          Divider(height: 1, color: c.border),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: widget.categories.map((cat) {
                  final id = cat.id ?? '';
                  final nom = cat.nom ?? '';
                  final sel = _selected.contains(id);
                  return GestureDetector(
                    onTap: () => setState(() { if (sel) _selected.remove(id); else _selected.add(id); }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: sel ? CustomConstants.kPrimaryColor.withOpacity(0.12) : c.surfaceVariant,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: sel ? CustomConstants.kPrimaryColor : c.border),
                      ),
                      child: Text(nom,
                          style: TextStyle(
                            fontSize: 13,
                            color: sel ? CustomConstants.kPrimaryColor : c.textSecondary,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                          )),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                Text('${_selected.length} catégorie(s) sélectionnée(s)',
                    style: TextStyle(fontSize: 12, color: c.textSecondary)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _selected.isEmpty ? null : () => widget.onSave(_selected.toList()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CustomConstants.kPrimaryColor,
                      disabledBackgroundColor: c.border,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Voir ma sélection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onSave([]),
                  child: Text('Passer — tout afficher', style: TextStyle(fontSize: 13, color: c.textSecondary)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

