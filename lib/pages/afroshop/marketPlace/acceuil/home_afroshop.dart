import 'package:afrotok/pages/afroshop/marketPlace/acceuil/produit_details.dart';
import 'package:afrotok/providers/postProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  int selectedCategoryIndex = -1;
  bool showAllProducts = true;
  bool isSearchActive = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isLoadingBoosted = true;
  String searchQuery = "";

  final _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final int _pageSize = 20;
  int _currentPage = 0;
  bool _hasMoreData = true;

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
      // Charger les catégories
      categories = await categorieProduitProvider.getCategories();

      // Charger les produits boostés
      _loadBoostedProducts();

      // Démarrer le stream des articles
      _startArticlesStream();

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
      final boosted = await categorieProduitProvider.getArticleBooster();
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

  void _startArticlesStream() {
    final stream = categorieProduitProvider.getAllArticlesStream();

    stream.listen((article) {
      if (mounted) {
        setState(() {
          allArticles.add(article);
          _applyFilters();
        });
      }
    }, onError: (error) {
      print("Stream error: $error");
    }, onDone: () {
      print("Stream completed");
    });
  }

  void _applyFilters() {
    List<ArticleData> filtered = allArticles;

    // Filtre par catégorie
    if (selectedCategoryIndex != -1 && categories.isNotEmpty) {
      final selectedCategory = categories[selectedCategoryIndex];
      filtered = filtered.where((article) =>
      article.categorie_id == selectedCategory.id).toList();
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
      _isLoading = false;
    });
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      _loadMoreData();
    }
  }

  void _loadMoreData() {
    // Pour l'instant, le stream gère le chargement continu
  }

  void _onCategorySelected(int index) {
    setState(() {
      selectedCategoryIndex = index;
      showAllProducts = (index == -1);
      _applyFilters();
    });
  }

  void _onSearch(String query) {
    setState(() {
      searchQuery = query;
      _applyFilters();
    });
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

  Widget _buildAppBar() {
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

  Widget _buildCategories() {
    if (categories.isEmpty) {
      return SizedBox(
        height: 50,
        child: Center(child: CircularProgressIndicator(
          color: CustomConstants.kPrimaryColor,
          strokeWidth: 2,
        )),
      );
    }

    return Container(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          SizedBox(width: 16),
          // Bouton "Tous"
          _buildCategoryChip("Tous", -1),
          // Catégories
          ...List.generate(categories.length, (index) {
            return _buildCategoryChip(categories[index].nom ?? "Catégorie", index);
          }),
          SizedBox(width: 16),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, int index) {
    final isSelected = selectedCategoryIndex == index;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4),
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

    return GridView.builder(
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
              "Essayez de modifier vos critères de recherche",
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    double width = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white12,
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
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            allArticles.clear();
            displayedArticles.clear();
            boostedProducts.clear();
            _isLoading = true;
            _isLoadingBoosted = true;
          });
          _initializeData();
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

              // Catégories
              _buildCategories(),

              // Produits boostés avec Carousel
              _buildBoostedProductsCarousel(),

              // Titre section produits
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
                    Text(
                      selectedCategoryIndex == -1
                          ? 'Tous les produits'
                          : 'Produits ${categories[selectedCategoryIndex].nom}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Spacer(),
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