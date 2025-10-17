import 'package:afrotok/pages/afroshop/marketPlace/acceuil/produit_details.dart';
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

class HomeAfroshopPage extends StatefulWidget {
  const HomeAfroshopPage({super.key, required this.title});

  final String title;

  @override
  State<HomeAfroshopPage> createState() => _HomePageState();
}

class _HomePageState extends State<HomeAfroshopPage> {
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

  // États de chargement
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isLoadingBoosted = true;
  bool isSearchActive = false;
  bool _hasMoreData = true;

  // Pagination
  final int _pageSize = 5;
  int _currentPage = 0;
  DocumentSnapshot? _lastDocument;

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
    'createdAt_desc': 'Plus récents',
    'createdAt_asc': 'Plus anciens',
    'prix_asc': 'Prix croissant',
    'prix_desc': 'Prix décroissant',
    'popularite_desc': 'Plus populaires',
  };

  // Liste des codes ISO des pays africains (identique à la page de création)
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
    'DZ': 'Algérie',
    'AO': 'Angola',
    'BJ': 'Bénin',
    'BW': 'Botswana',
    'BF': 'Burkina Faso',
    'BI': 'Burundi',
    'CV': 'Cap-Vert',
    'CM': 'Cameroun',
    'CF': 'République centrafricaine',
    'TD': 'Tchad',
    'KM': 'Comores',
    'CD': 'République démocratique du Congo',
    'DJ': 'Djibouti',
    'EG': 'Égypte',
    'GQ': 'Guinée équatoriale',
    'ER': 'Érythrée',
    'SZ': 'Eswatini',
    'ET': 'Éthiopie',
    'GA': 'Gabon',
    'GM': 'Gambie',
    'GH': 'Ghana',
    'GN': 'Guinée',
    'GW': 'Guinée-Bissau',
    'CI': 'Côte d\'Ivoire',
    'KE': 'Kenya',
    'LS': 'Lesotho',
    'LR': 'Libéria',
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
    'ST': 'Sao Tomé-et-Principe',
    'SN': 'Sénégal',
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
    _initializeData();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
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
      // Définir le pays par défaut de l'utilisateur
      final userCountry = authProvider.loginUserData.countryData?['countryCode'] ?? 'TG';
      setState(() {
        selectedCountry = userCountry;
      });

      // Charger les catégories
      categories = await categorieProduitProvider.getCategories();

      // Charger les produits boostés
      _loadBoostedProducts();

      // Charger le premier lot de produits
      await _loadInitialProducts();

    } catch (e) {
      print("Error initializing data: $e");
      setState(() {
        _isLoading = false;
        _isLoadingBoosted = false;
      });
    }
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
      print("Error loading boosted products: $e");
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
      print("Error loading initial products: $e");
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

      // Vérifier s'il reste des données
      if (snapshot.docs.length < _pageSize) {
        _hasMoreData = false;
      }

      return articles;
    } catch (e) {
      print("Error fetching products batch: $e");
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
      print("Error loading more products: $e");
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _applyFilters() {
    List<ArticleData> filtered = List.from(allArticles);

    // Filtre par catégorie
    if (selectedCategoryIndex != -1 && categories.isNotEmpty) {
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
      // Réinitialiser la pagination quand le pays change
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
      // Réinitialiser la pagination quand le tri change
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // Liste des pays sans doublons
        final uniqueAfricanCountries = [
          'TG', 'DZ', 'AO', 'BJ', 'BW', 'BF', 'BI', 'CV', 'CM', 'CF', 'TD', 'KM',
          'CD', 'DJ', 'EG', 'GQ', 'ER', 'SZ', 'ET', 'GA', 'GM', 'GH', 'GN', 'GW',
          'CI', 'KE', 'LS', 'LR', 'LY', 'MG', 'MW', 'ML', 'MR', 'MU', 'MA', 'MZ',
          'NA', 'NE', 'NG', 'RW', 'ST', 'SN', 'SC', 'SL', 'SO', 'ZA', 'SS', 'SD',
          'TZ', 'TN', 'UG', 'ZM', 'ZW'
        ];

        // S'assurer que la valeur est valide
        String currentCountryValue = selectedCountry;
        if (!uniqueAfricanCountries.contains(currentCountryValue)) {
          currentCountryValue = ''; // Valeur par défaut si invalide
        }

        // Contrôleur pour la recherche dans le filtre
        final _filterSearchController = TextEditingController(text: searchQuery);

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Filtrer et Trier',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Recherche par nom de produit
                      _buildFilterSection(
                        title: 'Recherche par nom',
                        icon: Icons.search,
                        child: TextFormField(
                          controller: _filterSearchController,
                          decoration: InputDecoration(
                            hintText: 'Ex: Téléphone, Chaussures, Sac...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            prefixIcon: Icon(Icons.search, color: CustomConstants.kPrimaryColor),
                            suffixIcon: _filterSearchController.text.isNotEmpty
                                ? IconButton(
                              icon: Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                _filterSearchController.clear();
                                setState(() {
                                  searchQuery = '';
                                });
                              },
                            )
                                : null,
                          ),
                          onChanged: (value) {
                            setState(() {
                              searchQuery = value;
                            });
                          },
                        ),
                      ),

                      SizedBox(height: 20),

                      // Filtre par pays avec recherche
                      _buildFilterSection(
                        title: 'Pays',
                        icon: Icons.flag,
                        child: DropdownSearch<String>(
                          popupProps: PopupProps.menu(
                            showSearchBox: true,
                            searchFieldProps: TextFieldProps(
                              decoration: InputDecoration(
                                hintText: "Rechercher un pays...",
                                prefixIcon: Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            itemBuilder: (context, item, isSelected) {
                              final countryName = countryNames[item] ?? item;
                              return ListTile(
                                leading: countryFlag(item, size: 24),
                                title: Text(countryName),
                                subtitle: Text(item),
                                trailing: isSelected
                                    ? Icon(Icons.check, color: CustomConstants.kPrimaryColor)
                                    : null,
                              );
                            },
                          ),
                          dropdownBuilder: (context, selectedItem) {
                            if (selectedItem == null || selectedItem.isEmpty) {
                              return Padding(
                                padding: EdgeInsets.only(left: 8.0),
                                child: Text('Tous les pays africains'),
                              );
                            }
                            final countryName = countryNames[selectedItem] ?? selectedItem;
                            return Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: Row(
                                children: [
                                  countryFlag(selectedItem, size: 20),
                                  SizedBox(width: 8),
                                  Text(countryName),
                                ],
                              ),
                            );
                          },
                          items: uniqueAfricanCountries,
                          selectedItem: currentCountryValue.isEmpty ? null : currentCountryValue,
                          onChanged: (String? newValue) {
                            _onCountrySelected(newValue);
                          },
                          dropdownDecoratorProps: DropDownDecoratorProps(
                            dropdownSearchDecoration: InputDecoration(
                              labelText: "Sélectionner un pays",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 20),

                      // Filtre par catégorie
                      _buildFilterSection(
                        title: 'Catégories',
                        icon: Icons.category,
                        child: Container(
                          height: 50,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              _buildFilterChip('Tous', -1),
                              ...List.generate(categories.length, (index) {
                                return _buildFilterChip(
                                    categories[index].nom ?? "Catégorie", index);
                              }),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 20),

                      // Filtre par prix
                      _buildFilterSection(
                        title: 'Fourchette de prix',
                        icon: Icons.attach_money,
                        child: DropdownButtonFormField<String>(
                          value: selectedPriceRange.isEmpty ? null : selectedPriceRange,
                          decoration: InputDecoration(
                            labelText: 'Sélectionner une fourchette',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          items: priceRanges.entries.map((entry) {
                            return DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            );
                          }).toList(),
                          onChanged: _onPriceRangeSelected,
                        ),
                      ),

                      SizedBox(height: 20),

                      // Tri des produits
                      _buildFilterSection(
                        title: 'Trier par',
                        icon: Icons.sort,
                        child: DropdownButtonFormField<String>(
                          value: selectedSort,
                          decoration: InputDecoration(
                            labelText: 'Ordre d\'affichage',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          items: sortOptions.entries.map((entry) {
                            return DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            );
                          }).toList(),
                          onChanged: _onSortSelected,
                        ),
                      ),

                      // Résumé des filtres actifs
                      if (selectedCategoryIndex != -1 || selectedPriceRange.isNotEmpty || searchQuery.isNotEmpty || selectedCountry != (authProvider.loginUserData.countryData?['countryCode'] ?? 'TG'))
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 20),
                            _buildFilterSection(
                              title: 'Filtres actifs',
                              icon: Icons.filter_alt,
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (searchQuery.isNotEmpty)
                                    _buildActiveFilterChip(
                                      'Recherche: "$searchQuery"',
                                      onTap: () {
                                        _filterSearchController.clear();
                                        setState(() {
                                          searchQuery = '';
                                        });
                                      },
                                    ),
                                  if (selectedCategoryIndex != -1)
                                    _buildActiveFilterChip(
                                      'Catégorie: ${categories[selectedCategoryIndex].nom}',
                                      onTap: () {
                                        setState(() {
                                          selectedCategoryIndex = -1;
                                        });
                                      },
                                    ),
                                  if (selectedPriceRange.isNotEmpty)
                                    _buildActiveFilterChip(
                                      'Prix: ${priceRanges[selectedPriceRange]}',
                                      onTap: () {
                                        setState(() {
                                          selectedPriceRange = '';
                                        });
                                      },
                                    ),
                                  if (selectedCountry != (authProvider.loginUserData.countryData?['countryCode'] ?? 'TG') && selectedCountry.isNotEmpty)
                                    _buildActiveFilterChip(
                                      'Pays: ${countryNames[selectedCountry]}',
                                      onTap: () {
                                        setState(() {
                                          selectedCountry = authProvider.loginUserData.countryData?['countryCode'] ?? 'TG';
                                        });
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),

                      SizedBox(height: 30),

                      // Boutons d'action
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  selectedCategoryIndex = -1;
                                  selectedCountry = authProvider.loginUserData.countryData?['countryCode'] ?? 'TG';
                                  selectedPriceRange = '';
                                  selectedSort = 'createdAt_desc';
                                  searchQuery = '';
                                  _searchController.clear();
                                  _filterSearchController.clear();
                                });
                                Navigator.pop(context);
                                _loadInitialProducts();
                              },
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(color: CustomConstants.kPrimaryColor),
                              ),
                              child: Text(
                                'Tout effacer',
                                style: TextStyle(
                                  color: CustomConstants.kPrimaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _applyFilters();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: CustomConstants.kPrimaryColor,
                                padding: EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Appliquer',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

// Nouvelle méthode pour les chips de filtres actifs
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
                color: Colors.black87,
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
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) => _onCategorySelected(selected ? index : -1),
        backgroundColor: Colors.grey[200],
        selectedColor: CustomConstants.kPrimaryColor,
        labelPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: StadiumBorder(
          side: BorderSide(
            color: isSelected ? CustomConstants.kPrimaryColor : Colors.grey[300]!,
          ),
        ),
      ),
    );
  }

  void _showBottomSheetCompterNonValide() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
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
                      color: Colors.black
                  ),
                ),
                SizedBox(height: 15),
                Text(
                  "Pour mettre en ligne un produit, vous devez avoir un compte entreprise. Veuillez créer un compte entreprise depuis votre profil.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
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
                      Text('Créer un compte entreprise',
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
    final hasActiveFilters = selectedCategoryIndex != -1 ||
        selectedPriceRange.isNotEmpty ||
        searchQuery.isNotEmpty ||
        selectedCountry != (authProvider.loginUserData.countryData?['countryCode'] ?? 'TG');

    return AppBar(
      backgroundColor: Colors.black,
      elevation: 0,
      centerTitle: true,
      title: Container(
        height: 50,
        child: Image.asset(
          "assets/icons/afroshop_logo-removebg-preview.png",
          fit: BoxFit.contain,
        ),
      ),
      actions: [
        // Bouton filtre avec badge si des filtres sont actifs
        Stack(
          children: [
            IconButton(
              icon: Icon(
                  Icons.filter_list,
                  color: hasActiveFilters ? Colors.amber : Colors.white
              ),
              onPressed: _showFilterDialog,
            ),
            if (hasActiveFilters)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  constraints: BoxConstraints(
                    minWidth: 12,
                    minHeight: 12,
                  ),
                ),
              ),
          ],
        ),
        // Bouton publier
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: ElevatedButton.icon(
            onPressed: () {
              postProvider.getEntreprise(authProvider.loginUserData.id!).then((value) {
                if (value.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddAnnonceStep1(entrepriseData: value.first),
                    ),
                  );
                } else {
                  _showBottomSheetCompterNonValide();
                }
              });
            },
            icon: Icon(Icons.add, color: Colors.white, size: 18),
            label: Text("Publier",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: CustomConstants.kPrimaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildSearchBar() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.grey[300]!),
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
                hintStyle: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear, color: Colors.grey),
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
                'Produits Boostés',
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

        // Indicateur de chargement pour plus de données
        if (_isLoadingMore)
          Container(
            padding: EdgeInsets.all(20),
            child: Center(
              child: CircularProgressIndicator(
                color: CustomConstants.kPrimaryColor,
              ),
            ),
          ),

        if (!_hasMoreData && displayedArticles.isNotEmpty)
          Container(
            padding: EdgeInsets.all(20),
            child: Center(
              child: Text(
                'Vous avez vu tous les produits',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLoadingGrid() {
    return GridView.builder(
      physics: NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return _buildProductSkeleton();
      },
    );
  }

  Widget _buildProductSkeleton() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image skeleton
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            SizedBox(height: 8),
            // Title skeleton
            Container(
              height: 12,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            SizedBox(height: 6),
            // Price skeleton
            Container(
              height: 14,
              width: 80,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(4),
              ),
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
            Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text(
              "Aucun produit trouvé",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              "Essayez de modifier vos critères de recherche ou de filtres",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
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
              child: Text('Réinitialiser les filtres'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
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
              // Barre de recherche
              _buildSearchBar(),

              // Indicateur de pays sélectionné
              _buildCountryIndicator(),

              // Produits boostés avec Carousel
              _buildBoostedProductsCarousel(),

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
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Text(
                      '${displayedArticles.length} produit(s)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
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
    );
  }
}

