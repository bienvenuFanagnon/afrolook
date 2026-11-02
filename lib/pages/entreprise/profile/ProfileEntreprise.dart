import 'package:afrotok/pages/liveshop/shopping_live_launcher.dart';
import 'package:afrotok/services/api/api_identity.dart';
import 'package:afrotok/services/read_meter.dart';
import 'package:afrotok/pages/admin/new_category.dart';
import 'package:afrotok/pages/component/consoleWidget.dart';

import 'package:afrotok/pages/entreprise/abonnement/MySubscription.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/api/shop_api.dart';

import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../../constant/custom_theme.dart';

import '../../../constant/logo.dart';

import '../../../models/model_data.dart';

import '../../../providers/authProvider.dart';

import '../../../providers/userProvider.dart';

import 'package:afrotok/pages/afroshop/marketPlace/acceuil/produit_details.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../../../providers/afroshop/categorie_produits_provider.dart';

import '../../../providers/postProvider.dart';
import '../../../theme/app_colors.dart';

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
  int _apiPage = 0;

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
      printVm("Erreur chargement entreprise: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _loadEntrepriseByUserId(String userId) async {
    try {
      // L'entreprise de la personne (API : /shop/businesses, entreprises à moi ou d'un autre selon l'identifiant du propriétaire)
      final all = await ShopApi.businesses(mine: userId == ApiIdentity.myId);
      final mine = all.where((e) => e.userId == userId).toList();
      if (mine.isNotEmpty) {
        entrepriseData = mine.first;
        return true;
      }
      return false;
    } catch (e) {
      printVm("Erreur loadEntrepriseByUserId: $e");
      return false;
    }
  }

  Future<void> _loadInitialProducts() async {
    try {
      setState(() {
        produits.clear();
        _apiPage = 0;
        _hasMoreData = true;
      });

      final articles = await _fetchProductsBatch();
      setState(() {
        produits = articles;
      });
    } catch (e) {
      printVm("Erreur chargement produits: $e");
    }
  }

  Future<List<ArticleData>> _fetchProductsBatch() async {
    try {
      if (entrepriseData == null) return [];

      final r = await ShopApi.articles(ownerId: entrepriseData!.userId!, page: _apiPage + 1, limit: _pageSize);
      _apiPage++;
      var articles = r.items;
      switch (_selectedFilter) {
        case 'boostés':
          articles = articles.where((a) => a.isBoosted == true).toList();
          break;
        case 'populaires':
          articles.sort((a, b) => (b.vues ?? 0).compareTo(a.vues ?? 0));
          break;
      }
      if (!r.more) {
        _hasMoreData = false;
      }

      return articles;
    } catch (e) {
      printVm("Erreur fetch produits: $e");
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
      printVm("Erreur load more produits: $e");
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

  // ── Design : couleurs du thème (clair ET sombre), une seule couleur d'accent, mêmes cartes et mêmes puces partout ──

  AppColors get _c => AppColors.of(context);

  BoxDecoration _card({double radius = 16}) => BoxDecoration(color: _c.surface, borderRadius: BorderRadius.circular(radius), border: Border.all(color: _c.border));

  Widget _buildHeader() {
    final c = _c;
    if (_isLoading) {
      return _buildHeaderSkeleton();
    }

    if (entrepriseData == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: _card(),
        child: Column(
          children: [
            Icon(Icons.business, size: 46, color: c.textSecondary),
            const SizedBox(height: 10),
            Text(
              _isOwner ? "Créez votre entreprise" : "Aucune entreprise trouvée",
              style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (_isOwner)
              FilledButton(
                onPressed: () => Navigator.pushNamed(context, '/new_entreprise'),
                style: FilledButton.styleFrom(backgroundColor: c.primary, minimumSize: const Size(200, 46), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text("Créer mon entreprise", style: TextStyle(color: c.onPrimary, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(radius: 18),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: c.primary, width: 2)),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: entrepriseData!.urlImage ?? '',
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: c.surfaceVariant, child: Icon(Icons.business, color: c.textSecondary)),
                    errorWidget: (context, url, error) => Container(color: c.surfaceVariant, child: Icon(Icons.business, color: c.textSecondary)),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entrepriseData!.titre ?? 'Entreprise',
                      style: TextStyle(color: c.textPrimary, fontSize: 19, fontWeight: FontWeight.w800),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(spacing: 14, runSpacing: 2, children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.people, size: 15, color: c.textSecondary),
                        const SizedBox(width: 4),
                        Text("${entrepriseData!.suivi ?? 0} abonnés", style: TextStyle(color: c.textSecondary, fontSize: 13)),
                      ]),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.shopping_bag, size: 15, color: c.textSecondary),
                        const SizedBox(width: 4),
                        Text("${produits.length}+ produits", style: TextStyle(color: c.textSecondary, fontSize: 13)),
                      ]),
                    ]),
                    if (entrepriseData!.description != null && entrepriseData!.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(entrepriseData!.description!, style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.35), maxLines: 3, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: c.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_isOwner || _isAdmin)
                Expanded(child: _buildStatItem(icon: Icons.monetization_on, value: "${entrepriseData!.publicash?.toStringAsFixed(0) ?? '0'}", label: "Publicash")),
              Expanded(child: _buildStatItem(icon: Icons.star, value: _getAbonnementLabel(), label: "Abonnement")),
              Expanded(child: _buildStatItem(icon: Icons.shopping_bag, value: "${produits.length}", label: "Produits")),
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

  Widget _buildStatItem({required IconData icon, required String value, required String label}) {
    final c = _c;
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: c.primary.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: c.primary),
        ),
        const SizedBox(height: 5),
        Text(value, style: TextStyle(color: c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(color: c.textSecondary, fontSize: 11)),
      ],
    );
  }

  Widget _skel({double? w, double h = 14, double r = 6}) => Container(width: w, height: h, decoration: BoxDecoration(color: _c.shimmerBase, borderRadius: BorderRadius.circular(r)));

  Widget _buildHeaderSkeleton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _card(radius: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 72, height: 72, decoration: BoxDecoration(shape: BoxShape.circle, color: _c.shimmerBase)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_skel(w: 150, h: 20), const SizedBox(height: 8), _skel(w: 200)])),
        ],
      ),
    );
  }

  Future<void> _startShoppingLive() => startShoppingLive(context, produits);

  Widget _buildActionButtons() {
    if (!_isOwner && !_isAdmin) return const SizedBox();
    final c = _c;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Actions rapides", style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildActionButton(
                icon: Icons.star,
                label: "Abonnement",
                onTap: () {
                  if (entrepriseData?.abonnement != null) {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => CurrentSubscriptionPage(abonnement: entrepriseData!.abonnement!, entreprise: entrepriseData!)));
                  }
                },
              ),
              if (_isAdmin)
                _buildActionButton(
                  icon: Icons.add,
                  label: "Annonce",
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
                  onTap: () async {
                    await userProvider.getGratuitInfos().then((value) {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => AddCategorie()));
                    });
                  },
                ),
              if (_isOwner) _buildActionButton(icon: Icons.live_tv_rounded, label: "Vente en direct", onTap: _startShoppingLive),
              _buildActionButton(
                icon: Icons.chat,
                label: "Clients",
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

  /// Bouton d'action : même taille, même style, même couleur d'icône pour tous.
  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    final c = _c;
    return Material(
      color: c.surfaceVariant,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: c.primary),
              const SizedBox(width: 7),
              Text(label, style: TextStyle(color: c.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final c = _c;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: _filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(_getFilterLabel(filter), style: TextStyle(color: isSelected ? c.onPrimary : c.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700)),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (selected) => _onFilterChanged(filter),
              backgroundColor: c.surface,
              selectedColor: c.primary,
              shape: StadiumBorder(side: BorderSide(color: isSelected ? c.primary : c.border)),
            ),
          );
        }).toList(),
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
    final c = _c;
    if (_isLoading) {
      return _buildProductsSkeleton();
    }

    if (produits.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.74),
          itemCount: produits.length,
          itemBuilder: (context, index) => _buildProductCard(produits[index]),
        ),
        if (_isLoadingMore)
          Padding(padding: const EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: c.primary))),
        if (!_hasMoreData && produits.isNotEmpty)
          Padding(padding: const EdgeInsets.all(20), child: Center(child: Text('Tous les produits sont affichés', style: TextStyle(color: c.textSecondary, fontSize: 13)))),
      ],
    );
  }

  Widget _buildProductCard(ArticleData article) {
    final c = _c;
    return Material(
      color: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: c.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ProduitDetail(productId: article.id!))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 128,
                  width: double.infinity,
                  child: CachedNetworkImage(
                    imageUrl: article.images?.isNotEmpty == true ? article.images!.first : '',
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: c.shimmerBase),
                    errorWidget: (context, url, error) => Container(color: c.surfaceVariant, child: Icon(Icons.shopping_bag, color: c.textSecondary)),
                  ),
                ),
                if (article.estBoosted)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: c.badgeFill, borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.rocket_launch, size: 10, color: c.onBadge),
                        const SizedBox(width: 3),
                        Text('BOOST', style: TextStyle(color: c.onBadge, fontSize: 9, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(article.titre ?? 'Produit', style: TextStyle(color: c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.2), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text('${article.prix ?? 0} FCFA', style: TextStyle(color: c.primary, fontSize: 15, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Row(children: [
                      Icon(Icons.remove_red_eye, size: 13, color: c.textSecondary),
                      const SizedBox(width: 4),
                      Text('${article.vues ?? 0}', style: TextStyle(color: c.textSecondary, fontSize: 11)),
                      const Spacer(),
                      Icon(Icons.favorite, size: 13, color: c.textSecondary),
                      const SizedBox(width: 4),
                      Text('${article.jaime ?? 0}', style: TextStyle(color: c.textSecondary, fontSize: 11)),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsSkeleton() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.74),
      itemCount: 6,
      itemBuilder: (context, index) => Container(
        decoration: _card(radius: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 128, width: double.infinity, decoration: BoxDecoration(color: _c.shimmerBase, borderRadius: const BorderRadius.vertical(top: Radius.circular(14)))),
            Padding(padding: const EdgeInsets.all(10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_skel(h: 12), const SizedBox(height: 8), _skel(w: 80)])),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final c = _c;
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 56, color: c.textSecondary),
            const SizedBox(height: 14),
            Text("Aucun produit trouvé", style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              _isOwner ? "Commencez par ajouter vos premiers produits" : "Cette entreprise n'a pas encore de produits",
              style: TextStyle(color: c.textSecondary, fontSize: 13.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    final c = _c;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: c.primary),
          const SizedBox(height: 16),
          Text("Chargement...", style: TextStyle(color: c.textPrimary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(widget.userId == null ? "Mon Entreprise" : "Boutique", style: TextStyle(color: c.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14.0),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.border)),
              child: Logo(),
            ),
          ),
        ],
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : RefreshIndicator(
              onRefresh: _loadInitialProducts,
              color: c.primary,
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Column(
                  children: [
                    _buildHeader(),
                    if ((_isOwner || _isAdmin) && entrepriseData != null) ...[
                      const SizedBox(height: 12),
                      _buildActionButtons(),
                    ],
                    if (entrepriseData != null) ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Icon(Icons.shopping_bag, color: c.primary, size: 20),
                          const SizedBox(width: 8),
                          Text("Produits", style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
                          const Spacer(),
                          Text('${produits.length} produit(s)', style: TextStyle(color: c.textSecondary, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Transform.translate(offset: const Offset(-16, 0), child: SizedBox(width: MediaQuery.of(context).size.width, child: _buildFilterChips())),
                      const SizedBox(height: 14),
                      _buildProductsGrid(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
