import 'package:afrotok/pages/admin/new_category.dart';
import 'package:afrotok/pages/entreprise/abonnement/MySubscription.dart';
import 'package:afrotok/pages/entreprise/depot/depotPublicash.dart';
import 'package:afrotok/pages/entreprise/produit/component.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:contained_tab_bar_view_with_custom_page_navigator/contained_tab_bar_view_with_custom_page_navigator.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../constant/buttons.dart';
import '../../../constant/constColors.dart';
import '../../../constant/custom_theme.dart';
import '../../../constant/iconGradient.dart';
import '../../../constant/listItemsCarousel.dart';
import '../../../constant/logo.dart';
import '../../../constant/sizeText.dart';
import '../../../constant/textCustom.dart';
import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import '../produit/entrepriseProduit.dart';
import '../pubs/pub.dart';
import 'package:afrotok/pages/admin/new_category.dart';
import 'package:afrotok/pages/entreprise/abonnement/MySubscription.dart';
import 'package:afrotok/pages/entreprise/depot/depotPublicash.dart';
import 'package:afrotok/pages/afroshop/marketPlace/acceuil/produit_details.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../constant/constColors.dart';
import '../../../constant/logo.dart';
import '../../../constant/sizeText.dart';
import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import '../../../providers/afroshop/categorie_produits_provider.dart';
import '../../../providers/postProvider.dart';

import 'package:afrotok/pages/admin/new_category.dart';
import 'package:afrotok/pages/entreprise/abonnement/MySubscription.dart';
import 'package:afrotok/pages/entreprise/depot/depotPublicash.dart';
import 'package:afrotok/pages/afroshop/marketPlace/acceuil/produit_details.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../constant/constColors.dart';
import '../../../constant/logo.dart';
import '../../../models/model_data.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/userProvider.dart';
import '../../../providers/afroshop/categorie_produits_provider.dart';
import '../../../providers/postProvider.dart';

class EntrepriseProfil extends StatefulWidget {
  final String? userId;
  const EntrepriseProfil({super.key, this.userId});

  @override
  State<EntrepriseProfil> createState() => _EntrepriseProfilState();
}

class _EntrepriseProfilState extends State<EntrepriseProfil> {
  late UserAuthProvider authProvider =
  Provider.of<UserAuthProvider>(context, listen: false);
  late UserProvider userProvider =
  Provider.of<UserProvider>(context, listen: false);
  late CategorieProduitProvider categorieProduitProvider =
  Provider.of<CategorieProduitProvider>(context, listen: false);
  late PostProvider postProvider =
  Provider.of<PostProvider>(context, listen: false);

  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  EntrepriseData? entrepriseData;
  List<ArticleData> produits = [];
  bool _isLoading = true;
  bool _isOwner = false;
  bool _isAdmin = false;

  // Filtres et pagination
  String _selectedFilter = 'tous';
  final List<String> _filters = ['tous', 'boostés', 'populaires', 'récents'];
  final int _pageSize = 10;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastDocument;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadEntrepriseData();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadEntrepriseData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      String targetUserId = widget.userId ?? authProvider.loginUserData.id!;

      _isOwner = targetUserId == authProvider.loginUserData.id;
      _isAdmin = authProvider.loginUserData.role == UserRole.ADM.name;

      final haveEntreprise = await _loadEntrepriseByUserId(targetUserId);

      if (haveEntreprise && entrepriseData != null) {
        await _loadInitialProducts();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("Erreur chargement entreprise: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _loadEntrepriseByUserId(String userId) async {
    try {
      CollectionReference collectionRef = firestore.collection('Entreprises');
      QuerySnapshot querySnapshot = await collectionRef
          .where("userId", isEqualTo: userId)
          .get();

      List<EntrepriseData> listEntreprise = querySnapshot.docs.map((doc) {
        final entreprise = EntrepriseData.fromJson(doc.data() as Map<String, dynamic>);
        entreprise.id = doc.id;
        return entreprise;
      }).toList();

      if (listEntreprise.isNotEmpty) {
        listEntreprise.first.suivi = listEntreprise.first.usersSuiviId?.length ?? 0;
        entrepriseData = listEntreprise.first;
        return true;
      }

      return false;
    } catch (e) {
      print("Erreur loadEntrepriseByUserId: $e");
      return false;
    }
  }

  Future<void> _loadInitialProducts() async {
    try {
      setState(() {
        produits.clear();
        _lastDocument = null;
        _hasMoreData = true;
      });

      final articles = await _fetchProductsBatch();
      setState(() {
        produits = articles;
      });
    } catch (e) {
      print("Erreur chargement produits: $e");
    }
  }

  Future<List<ArticleData>> _fetchProductsBatch() async {
    try {
      if (entrepriseData == null) return [];

      Query query = firestore.collection('Articles')
          .where('disponible', isEqualTo: true)
          .where('user_id', isEqualTo: entrepriseData!.userId!);

      switch (_selectedFilter) {
        case 'boostés':
          query = query.where('booster', isEqualTo: 1);
          break;
        case 'populaires':
          query = query.orderBy('vues', descending: true);
          break;
        case 'récents':
        default:
          query = query.orderBy('createdAt', descending: true);
      }

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

      if (snapshot.docs.length < _pageSize) {
        _hasMoreData = false;
      }

      return articles;
    } catch (e) {
      print("Erreur fetch produits: $e");
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
          produits.addAll(moreArticles);
        });
      }

      setState(() {
        _isLoadingMore = false;
      });
    } catch (e) {
      print("Erreur load more produits: $e");
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreProducts();
    }
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _loadInitialProducts();
  }

  Widget _buildHeader() {
    if (_isLoading) {
      return _buildHeaderSkeleton();
    }

    if (entrepriseData == null) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Icon(Icons.business, size: 50, color: Colors.grey),
            SizedBox(height: 10),
            Text(
              _isOwner ? "Créez votre entreprise" : "Aucune entreprise trouvée",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            if (_isOwner)
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/new_entreprise');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: CustomConstants.kPrimaryColor,
                ),
                child: Text("Créer mon entreprise"),
              ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: CustomConstants.kPrimaryColor, width: 2),
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: entrepriseData!.urlImage ?? '',
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[800],
                      child: Icon(Icons.business, color: Colors.grey),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[800],
                      child: Icon(Icons.business, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entrepriseData!.titre ?? 'Entreprise',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.people, size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          "${entrepriseData!.suivi ?? 0} abonnés",
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        SizedBox(width: 16),
                        Icon(Icons.shopping_bag, size: 16, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          "${produits.length}+ produits",
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    if (entrepriseData!.description != null && entrepriseData!.description!.isNotEmpty)
                      Text(
                        entrepriseData!.description!,
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (_isOwner || _isAdmin) ...[
                _buildStatItem(
                  icon: Icons.monetization_on,
                  value: "${entrepriseData!.publicash?.toStringAsFixed(0) ?? '0'}",
                  label: "Publicash",
                  color: Colors.yellow,
                ),
              ],

              _buildStatItem(
                icon: Icons.star,
                value: "${_getAbonnementLabel()}",
                label: "Abonnement",
                color: CustomConstants.kPrimaryColor,
              ),

              _buildStatItem(
                icon: Icons.shopping_bag,
                value: "${produits.length}",
                label: "Produits",
                color: Colors.green,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getAbonnementLabel() {
    if (entrepriseData?.abonnement?.type == null) return 'Gratuit';

    final type = entrepriseData!.abonnement!.type!;
    if (type.contains('PREMIUM')) return 'Premium';
    if (type.contains('STANDARD')) return 'Standard';
    return 'Gratuit';
  }

  Widget _buildStatItem({required IconData icon, required String value, required String label, required Color color}) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderSkeleton() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 150,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: 8),
                Container(
                  width: 200,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (!_isOwner && !_isAdmin) return SizedBox();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Actions rapides",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildActionButton(
                icon: Icons.star,
                label: "Abonnement",
                color: CustomConstants.kPrimaryColor,
                onTap: () {
                  if (entrepriseData?.abonnement != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CurrentSubscriptionPage(
                          abonnement: entrepriseData!.abonnement!, entreprise: entrepriseData!,
                        ),
                      ),
                    );
                  }
                },
              ),

              if (_isAdmin)
                _buildActionButton(
                  icon: Icons.add,
                  label: "Annonce",
                  color: Colors.green,
                  onTap: () async {
                    await userProvider.getGratuitInfos().then((value) {
                      Navigator.pushNamed(context, '/new_annonce');
                    });
                  },
                ),

              if (_isAdmin)
                _buildActionButton(
                  icon: Icons.category,
                  label: "Catégories",
                  color: Colors.yellow,
                  onTap: () async {
                    await userProvider.getGratuitInfos().then((value) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AddCategorie()),
                      );
                    });
                  },
                ),

              _buildActionButton(
                icon: Icons.monetization_on,
                label: "Publicash",
                color: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => DepotPage()),
                  );
                },
              ),

              _buildActionButton(
                icon: Icons.chat,
                label: "Clients",
                color: Colors.purple,
                onTap: () {
                  userProvider.getUserEntreprise(authProvider.loginUserData.id!).then((value) {
                    if (value) {
                      Navigator.pushNamed(context, '/list_conversation_entreprise_user');
                    } else {
                      Navigator.pushNamed(context, '/new_entreprise');
                    }
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: FilterChip(
                label: Text(
                  _getFilterLabel(filter),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) => _onFilterChanged(filter),
                backgroundColor: Colors.grey[900],
                selectedColor: CustomConstants.kPrimaryColor,
                checkmarkColor: Colors.white,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: isSelected ? CustomConstants.kPrimaryColor : Colors.grey[700]!,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getFilterLabel(String filter) {
    switch (filter) {
      case 'tous': return 'Tous les produits';
      case 'boostés': return 'Produits boostés';
      case 'populaires': return 'Les plus populaires';
      case 'récents': return 'Les plus récents';
      default: return filter;
    }
  }

  Widget _buildProductsGrid() {
    if (_isLoading) {
      return _buildProductsSkeleton();
    }

    if (produits.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        GridView.builder(
          physics: NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: produits.length,
          itemBuilder: (context, index) {
            return _buildProductCard(produits[index]);
          },
        ),

        if (_isLoadingMore)
          Container(
            padding: EdgeInsets.all(20),
            child: Center(
              child: CircularProgressIndicator(
                color: CustomConstants.kPrimaryColor,
              ),
            ),
          ),

        if (!_hasMoreData && produits.isNotEmpty)
          Container(
            padding: EdgeInsets.all(20),
            child: Center(
              child: Text(
                'Tous les produits sont affichés',
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

  Widget _buildProductCard(ArticleData article) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProduitDetail(productId: article.id!),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 120,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: article.images?.isNotEmpty == true
                          ? article.images!.first
                          : '',
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[800],
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[800],
                        child: Icon(Icons.shopping_bag, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                if (article.estBoosted)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.rocket_launch, size: 10, color: Colors.white),
                          SizedBox(width: 2),
                          Text(
                            'BOOST',
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
              ],
            ),

            Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.titre ?? 'Produit',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${article.prix ?? 0} FCFA',
                    style: TextStyle(
                      color: CustomConstants.kPrimaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.remove_red_eye, size: 12, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                        '${article.vues ?? 0}',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),
                      Spacer(),
                      Icon(Icons.favorite, size: 12, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                        '${article.jaime ?? 0}',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
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

  Widget _buildProductsSkeleton() {
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
        return Container(
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
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 12,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      height: 14,
                      width: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 60, color: Colors.grey[600]),
            SizedBox(height: 16),
            Text(
              "Aucun produit trouvé",
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _isOwner ? "Commencez par ajouter vos premiers produits" : "Cette entreprise n'a pas encore de produits",
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: CustomConstants.kPrimaryColor),
          SizedBox(height: 16),
          Text(
            "Chargement...",
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          widget.userId == null ? "Mon Entreprise" : "Boutique",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Logo(),
          ),
        ],
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : RefreshIndicator(
        onRefresh: _loadInitialProducts,
        color: CustomConstants.kPrimaryColor,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildHeader(),

              SizedBox(height: 20),

              if ((_isOwner || _isAdmin) && entrepriseData != null)
                _buildActionButtons(),

              SizedBox(height: 20),

              if (entrepriseData != null) ...[
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.shopping_bag, color: CustomConstants.kPrimaryColor),
                      SizedBox(width: 8),
                      Text(
                        "Produits",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      Text(
                        '${produits.length} produit(s)',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 12),

                _buildFilterChips(),

                SizedBox(height: 16),

                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: _buildProductsGrid(),
                ),
              ],

              SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
