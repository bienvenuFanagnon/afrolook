import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/layout/responsive_layout.dart';
import 'dart:async';

import 'package:afrotok/models/model_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:afrotok/pages/contenuPayant/affiliation_marketplace_page.dart';
import 'package:afrotok/pages/contenuPayant/content_detail_page.dart';
import 'package:afrotok/pages/contenuPayant/contentForm.dart' show ContentFormScreen;
import 'package:afrotok/pages/contenuPayant/my_purchases_page.dart';
import 'package:afrotok/pages/contenuPayant/profileScreenContent.dart';
import 'package:afrotok/pages/contenuPayant/widgets/boosted_content_strip.dart';
import 'package:afrotok/providers/authProvider.dart';
import 'package:afrotok/providers/contenuPayantProvider.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


class DashboardContentScreen extends StatefulWidget {
  @override
  _DashboardContentScreenState createState() =>
      _DashboardContentScreenState();
}

class _DashboardContentScreenState extends State<DashboardContentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  ContentType? _filterType;
  String _sortMode = 'recent';
  String _searchQuery = '';
  String? _selectedCategory;

  // Creator search state
  List<String>? _creatorFilterIds; // null = no creator filter
  Timer? _debounce;

  static const _tabs = [
    (null, 'Tout'),
    (ContentType.FORMATION, '🎓'),
    (ContentType.TEMPLATE, '🎨'),
    (ContentType.PACK_ZIP, '📦'),
    (ContentType.VIDEO, '🎬'),
    (ContentType.EBOOK, '📘'),
    (ContentType.AUDIO, '🎵'),
    (ContentType.PRESET, '🎛️'),
    (ContentType.BUNDLE, '🗂️'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      setState(() {
        _filterType = _tabs[_tabController.index].$1;
      });
    });
    // Activer le profil créateur automatiquement à la première visite
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _ensureCreatorProfile();
      await _checkPendingContentDeepLink();
    });
  }

  Future<void> _ensureCreatorProfile() async {
    if (!mounted) return;
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final user = authProvider.loginUserData;
    if (user.id == null || user.isCreatorProfileEnabled == true) return;
    try {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.id)
          .update({'isCreatorProfileEnabled': true});
      user.isCreatorProfileEnabled = true;
      if (mounted) setState(() {});
    } catch (_) {
      // silencieux — l'activation sera retentée à la prochaine visite
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Vérifie si un deeplink /content/{id} est en attente depuis main.dart
  Future<void> _checkPendingContentDeepLink() async {
    final prefs = await SharedPreferences.getInstance();
    final contentId = prefs.getString('pending_content_deeplink');
    if (contentId == null || !mounted) return;
    await prefs.remove('pending_content_deeplink');
    try {
      final doc = await FirebaseFirestore.instance
          .collection('ContentPaies')
          .doc(contentId)
          .get();
      if (!doc.exists || !mounted) return;
      final content = ContentPaie.fromJson({...doc.data()!, 'id': doc.id});
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => ContentDetailPage(content: content)));
    } catch (_) {}
  }

  // Ouvre un contenu depuis un lien d'affiliation collé dans la barre de recherche
  Future<void> _openFromAffiliateLink(String raw) async {
    final normalized = raw.trim().startsWith('http') ? raw.trim() : 'https://${raw.trim()}';
    final uri = Uri.tryParse(normalized);
    if (uri == null) return;

    final segments = uri.pathSegments;
    // Format : /share/contenu/{id}?ref={affiliateId}
    final idx = segments.indexOf('contenu');
    if (idx < 0 || idx + 1 >= segments.length) return;
    final contentId = segments[idx + 1];
    if (contentId.isEmpty) return;

    final affiliateId = uri.queryParameters['ref'];

    // Sauvegarder la référence affilié avec TTL 30 jours
    if (affiliateId != null && affiliateId.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final key = 'affiliate_ref_$contentId';
      await prefs.setString(key, affiliateId);
      await prefs.setInt('${key}_ts', DateTime.now().millisecondsSinceEpoch);
    }

    // Charger le contenu depuis Firestore
    ContentPaie? content;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('ContentPaies')
          .doc(contentId)
          .get();
      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Contenu introuvable pour ce lien.'),
            backgroundColor: Colors.red,
          ));
        }
        return;
      }
      content = ContentPaie.fromJson({...doc.data()!, 'id': doc.id});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Impossible de charger le contenu.'),
          backgroundColor: Colors.red,
        ));
      }
      return;
    }

    if (!mounted) return;
    _searchCtrl.clear();
    setState(() {
      _searchQuery = '';
      _creatorFilterIds = null;
    });
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ContentDetailPage(content: content!)));
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final q = v.trim().toLowerCase();

      // Lien d'affiliation collé directement dans la barre de recherche
      if (q.contains('afrolookmedia.com/share/contenu/')) {
        _openFromAffiliateLink(v.trim());
        return;
      }
      if (q.startsWith('@') && q.length > 1) {
        // Creator search
        final pseudo = q.substring(1);
        final snap = await FirebaseFirestore.instance
            .collection('Users')
            .where('pseudo', isGreaterThanOrEqualTo: pseudo)
            .where('pseudo', isLessThan: pseudo + '')
            .limit(20)
            .get();
        if (!snap.docs.isEmpty) {
          final ids = snap.docs.map((d) => d.id).toList();
          if (mounted) setState(() {
            _searchQuery = '';
            _creatorFilterIds = ids;
          });
          return;
        }
        // Try email
        final snap2 = await FirebaseFirestore.instance
            .collection('Users')
            .where('email', isEqualTo: pseudo)
            .limit(5)
            .get();
        if (mounted) {
          setState(() {
            _searchQuery = '';
            _creatorFilterIds = snap2.docs.map((d) => d.id).toList();
          });
        }
      } else {
        if (mounted) setState(() {
          _searchQuery = q;
          _creatorFilterIds = null;
        });
      }
    });
  }

  bool get _isHomepageMode =>
      _filterType == null &&
      _searchQuery.isEmpty &&
      _creatorFilterIds == null &&
      _selectedCategory == null;

  Query<Map<String, dynamic>> get _query {
    Query<Map<String, dynamic>> q =
        FirebaseFirestore.instance.collection('ContentPaies');
    if (_filterType != null) {
      q = q.where('contentType',
          isEqualTo: _filterType!.toString().split('.').last);
    }
    switch (_sortMode) {
      case 'recent':
        q = q.orderBy('createdAt', descending: true);
        break;
      case 'popular':
        q = q.orderBy('views', descending: true);
        break;
      case 'free':
        q = q
            .where('isFree', isEqualTo: true)
            .orderBy('createdAt', descending: true);
        break;
    }
    return q.limit(100);
  }

  List<ContentPaie> _applyFilters(List<ContentPaie> items) {
    var result = items;

    // Content title/hashtag search
    if (_searchQuery.isNotEmpty) {
      result = result
          .where((c) =>
              c.title.toLowerCase().contains(_searchQuery) ||
              c.hashtags.any((h) => h.toLowerCase().contains(_searchQuery)))
          .toList();
    }

    // Creator filter
    if (_creatorFilterIds != null) {
      result = result
          .where((c) => _creatorFilterIds!.contains(c.ownerId))
          .toList();
    }

    // Category filter (résout aussi les anciens IDs stockés)
    if (_selectedCategory != null) {
      final contentProvider = Provider.of<ContentProvider>(context, listen: false);
      final idToName = {for (final c in contentProvider.categories) c.id!: c.name};
      final catId = idToName.entries
          .firstWhere((e) => e.value == _selectedCategory, orElse: () => MapEntry('', ''))
          .key;
      result = result.where((c) =>
          c.categories.contains(_selectedCategory) ||
          (catId.isNotEmpty && c.categories.contains(catId))).toList();
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final authProvider =
        Provider.of<UserAuthProvider>(context, listen: false);
    final isCreator =
        authProvider.loginUserData.isCreatorProfileEnabled ?? false;
    final isAdmin = authProvider.loginUserData.role == 'ADM';

    return Scaffold(
      backgroundColor: colors.background,
      body: CenteredContent(
        maxWidth: AppLayout.isDesktop(context) ? 900 : AppLayout.maxFeedWidth,
        child: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            backgroundColor: colors.background,
            floating: true,
            snap: true,
            elevation: 0,
            title: Text(
              'Afro Business',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
              ),
            ),
            actions: [
              // Mes achats
              IconButton(
                tooltip: 'Mes achats',
                icon: Icon(Icons.shopping_bag_outlined, color: colors.textSecondary),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyPurchasesPage()),
                ),
              ),
              // Affiliation
              IconButton(
                tooltip: 'Affiliation',
                icon: const Icon(Icons.handshake_outlined, color: Color(0xFF25D366)),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AffiliationMarketplacePage()),
                ),
              ),
              if (isCreator || isAdmin)
                IconButton(
                  tooltip: 'Mon profil créateur',
                  icon: Icon(Icons.storefront_rounded, color: colors.primary),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreenContenu(
                        userId: authProvider.loginUserData.id,
                      ),
                    ),
                  ),
                ),
              PopupMenuButton<String>(
                icon: Icon(Icons.sort, color: colors.textSecondary),
                onSelected: (v) => setState(() => _sortMode = v),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'recent', child: Text('Plus récents')),
                  const PopupMenuItem(
                      value: 'popular', child: Text('Plus populaires')),
                  const PopupMenuItem(
                      value: 'free', child: Text('Gratuits seulement')),
                ],
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(108),
              child: Column(
                children: [
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearchChanged,
                      style: TextStyle(
                          fontSize: 13, color: colors.textPrimary),
                      decoration: InputDecoration(
                        hintText:
                            'Rechercher, @créateur ou coller un lien affilié...',
                        hintStyle: TextStyle(
                            color: colors.textSecondary, fontSize: 12),
                        prefixIcon: Icon(Icons.search,
                            color: colors.textSecondary, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty ||
                                _creatorFilterIds != null
                            ? IconButton(
                                icon: Icon(Icons.close,
                                    color: colors.textSecondary,
                                    size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() {
                                    _searchQuery = '';
                                    _creatorFilterIds = null;
                                  });
                                })
                            : null,
                        filled: true,
                        fillColor: colors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  // Creator filter indicator
                  if (_creatorFilterIds != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
                      child: Row(
                        children: [
                          const Icon(Icons.person_search_outlined,
                              size: 14, color: Color(0xFF25D366)),
                          const SizedBox(width: 4),
                          Text(
                            '${_creatorFilterIds!.length} créateur(s) trouvé(s)',
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF25D366),
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  // Type tabs
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorColor: const Color(0xFF25D366),
                    indicatorWeight: 2,
                    labelColor: const Color(0xFF25D366),
                    unselectedLabelColor: colors.textSecondary,
                    labelStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                    tabs: _tabs.map((t) => Tab(text: t.$2)).toList(),
                  ),
                  // Si une catégorie est sélectionnée (depuis une section), afficher un badge effaçable
                  if (_selectedCategory != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                      child: Row(
                        children: [
                          const Icon(Icons.filter_list, size: 14, color: Color(0xFF25D366)),
                          const SizedBox(width: 4),
                          Text(_selectedCategory!,
                              style: const TextStyle(
                                  fontSize: 11, color: Color(0xFF25D366), fontWeight: FontWeight.w700)),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => setState(() => _selectedCategory = null),
                            child: const Icon(Icons.close, size: 14, color: Color(0xFF25D366)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        body: StreamBuilder<QuerySnapshot>(
          stream: _query.snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return _emptyState(colors);
            }

            final raw = snap.data!.docs
                .map((d) => ContentPaie.fromJson(
                    {...d.data() as Map<String, dynamic>, 'id': d.id}))
                .toList();

            final items = _applyFilters(raw);
            if (items.isEmpty) return _emptyState(colors);

            if (_isHomepageMode) {
              return _buildSectionedView(items, colors);
            }
            return _buildFlatGrid(items, colors);
          },
        ),
        ),
      ),
      floatingActionButton: isCreator
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF25D366),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ContentFormScreen()),
              ),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  // ── Vue homepage structurée en sections ─────────────────────────────────────
  Widget _buildSectionedView(List<ContentPaie> items, AppColors colors) {
    final recents = items.take(12).toList();
    final popular = [...items]..sort((a, b) => b.views.compareTo(a.views));
    final popularTop = popular.take(12).toList();
    final series = items.where((c) => c.isSeries).take(12).toList();

    final sections = <Widget>[
      const BoostedContentStripWidget(),
      _sectionHeader('🕐 Récents', colors, onVoirPlus: () {
        setState(() { _sortMode = 'recent'; _filterType = null; });
      }),
      _horizontalRail(recents, colors),
      _sectionHeader('🔥 Les plus vus', colors, onVoirPlus: () {
        setState(() { _sortMode = 'popular'; _filterType = null; });
      }),
      _horizontalRail(popularTop, colors),
      if (series.isNotEmpty) ...[
        _sectionHeader('📚 Séries', colors),
        _horizontalRail(series, colors),
      ],
    ];

    // Résolution IDs → noms (rétrocompatibilité avec anciens contenus stockés par ID)
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    final idToName = {for (final c in contentProvider.categories) c.id!: c.name};

    // Catégories dynamiques extraites du contenu, ordre aléatoire à chaque chargement
    final dynamicCats = items
        .expand((c) => c.categories)
        .where((c) => c.isNotEmpty)
        .map((rawCat) => idToName[rawCat] ?? rawCat) // résout l'ID en nom si possible
        .where((c) => !RegExp(r'^\d+$').hasMatch(c)) // filtre IDs non résolus
        .toSet()
        .toList()
      ..shuffle();
    for (final cat in dynamicCats) {
      // Chercher items par nom ET par ID (rétrocompatibilité)
      final catId = idToName.entries
          .firstWhere((e) => e.value == cat, orElse: () => MapEntry('', ''))
          .key;
      final catItems = items.where((c) =>
          c.categories.contains(cat) || (catId.isNotEmpty && c.categories.contains(catId))).take(8).toList();
      if (catItems.isEmpty) continue;
      sections.add(_sectionHeader(cat, colors, onVoirPlus: () {
        setState(() => _selectedCategory = cat);
      }));
      sections.add(_horizontalRail(catItems, colors));
    }

    sections.add(const SizedBox(height: 80));

    return CustomScrollView(
      slivers: sections.map((w) => SliverToBoxAdapter(child: w)).toList(),
    );
  }

  Widget _sectionHeader(String title, AppColors colors, {VoidCallback? onVoirPlus}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 12, 6),
      child: Row(
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary)),
          const Spacer(),
          if (onVoirPlus != null)
            TextButton(
              onPressed: onVoirPlus,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Voir plus',
                  style: TextStyle(
                      fontSize: 11,
                      color: colors.primary,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Widget _horizontalRail(List<ContentPaie> items, AppColors colors) {
    return SizedBox(
      height: 210,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: items.length,
        itemBuilder: (_, i) => SizedBox(
          width: 138,
          child: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _ContentCard(content: items[i], colors: colors),
          ),
        ),
      ),
    );
  }

  // ── Vue grille filtrée ───────────────────────────────────────────────────────
  Widget _buildFlatGrid(List<ContentPaie> items, AppColors colors) {
    final boosted = items.where((c) => c.isBoostActive).toList();
    final normal = items.where((c) => !c.isBoostActive).toList();
    final merged = [...boosted, ...normal];

    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: BoostedContentStripWidget()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          sliver: SliverGrid(
            gridDelegate:
                const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 0.72,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, i) => _ContentCard(content: merged[i], colors: colors),
              childCount: merged.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyState(AppColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🛍️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            'Aucun contenu trouvé',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            _selectedCategory != null || _searchQuery.isNotEmpty
                ? 'Essayez d\'autres filtres'
                : 'Les créateurs publieront bientôt du contenu',
            style:
                TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  final ContentPaie content;
  final AppColors colors;

  const _ContentCard({required this.content, required this.colors});

  @override
  Widget build(BuildContext context) {
    final authProvider =
        Provider.of<UserAuthProvider>(context, listen: false);
    final coverUrl = content.coverImages.isNotEmpty
        ? content.coverImages.first
        : content.thumbnailUrl;
    final cdnUrl = authProvider.convertToCdnUrl(
        coverUrl, authProvider.appDefaultData);

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ContentDetailPage(content: content))),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: content.isBoostActive
              ? Border.all(
                  color: const Color(0xFFFFD400).withOpacity(0.3),
                  width: 1.5)
              : Border.all(color: colors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  cdnUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: cdnUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _thumbPlaceholder(),
                        )
                      : _thumbPlaceholder(),
                  Positioned(
                    top: 6,
                    left: 6,
                    child:
                        _MiniTypeBadge(type: content.contentType),
                  ),
                  if (content.isBoostActive)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFFD400),
                              Color(0xFFFF8C00)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '⚡',
                          style: TextStyle(fontSize: 9),
                        ),
                      ),
                    ),
                  if (content.isFlashSaleActive)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '🔥 FLASH',
                          style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: Colors.white),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.5),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (content.isFlashSaleActive) ...[
                        Text(
                          '${content.price.toInt()} F',
                          style: TextStyle(
                            fontSize: 9,
                            color: colors.textSecondary,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${content.flashSalePrice!.toInt()} F',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.red,
                          ),
                        ),
                      ] else
                        Text(
                          content.isFree
                              ? 'GRATUIT'
                              : '${content.price.toInt()} F',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: content.isFree
                                ? const Color(0xFF25D366)
                                : const Color(0xFFFFD400),
                          ),
                        ),
                      const Spacer(),
                      Icon(Icons.visibility_outlined,
                          size: 10, color: colors.textSecondary),
                      const SizedBox(width: 2),
                      Text(
                        _fmt(content.views),
                        style: TextStyle(
                            fontSize: 9, color: colors.textSecondary),
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

  Widget _thumbPlaceholder() {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Center(
        child: Text(_emoji(content.contentType),
            style: const TextStyle(fontSize: 32)),
      ),
    );
  }

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  String _emoji(ContentType t) {
    switch (t) {
      case ContentType.VIDEO: return '🎬';
      case ContentType.EBOOK: return '📘';
      case ContentType.FORMATION: return '🎓';
      case ContentType.TEMPLATE: return '🎨';
      case ContentType.PACK_ZIP: return '📦';
      case ContentType.AUDIO: return '🎵';
      case ContentType.PRESET: return '🎛️';
      case ContentType.BUNDLE: return '🗂️';
    }
  }
}

class _MiniTypeBadge extends StatelessWidget {
  final ContentType type;
  const _MiniTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _info(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.85),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: const TextStyle(
            fontSize: 7,
            fontWeight: FontWeight.w800,
            color: Colors.white),
      ),
    );
  }

  (String, Color) _info(ContentType t) {
    switch (t) {
      case ContentType.VIDEO:
        return ('VIDÉO', const Color(0xFF4a90e2));
      case ContentType.EBOOK:
        return ('EBOOK', const Color(0xFF9b59b6));
      case ContentType.FORMATION:
        return ('FORM.', const Color(0xFF8e44ad));
      case ContentType.TEMPLATE:
        return ('TEMPLATE', const Color(0xFFe67e22));
      case ContentType.PACK_ZIP:
        return ('PACK', const Color(0xFF25D366));
      case ContentType.AUDIO:
        return ('AUDIO', const Color(0xFFe74c3c));
      case ContentType.PRESET:
        return ('PRESET', const Color(0xFF1abc9c));
      case ContentType.BUNDLE:
        return ('BUNDLE', const Color(0xFF16a085));
    }
  }
}
