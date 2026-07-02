import 'package:afrotok/models/model_data.dart';
import 'package:afrotok/pages/contenuPayant/content_detail_page.dart';
import 'package:afrotok/pages/contenuPayant/contentForm.dart' show ContentFormScreen;
import 'package:afrotok/pages/contenuPayant/widgets/boosted_content_strip.dart';
import 'package:afrotok/providers/authProvider.dart';
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
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

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
        q = q.where('isFree', isEqualTo: true).orderBy('createdAt', descending: true);
        break;
    }
    return q.limit(40);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    final isCreator = authProvider.userData?.isCreatorProfileEnabled ?? false;

    return Scaffold(
      backgroundColor: colors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            backgroundColor: colors.background,
            floating: true,
            snap: true,
            elevation: 0,
            title: Text(
              '🛍️ Boutique',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: colors.textPrimary,
              ),
            ),
            actions: [
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
              IconButton(
                icon: Icon(Icons.notifications_outlined,
                    color: colors.textSecondary),
                onPressed: () {},
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(94),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) =>
                          setState(() => _searchQuery = v.trim().toLowerCase()),
                      style: TextStyle(
                          fontSize: 13, color: colors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un contenu...',
                        hintStyle: TextStyle(color: colors.textSecondary),
                        prefixIcon: Icon(Icons.search,
                            color: colors.textSecondary, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.close,
                                    color: colors.textSecondary, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
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
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    indicatorColor: const Color(0xFF25D366),
                    indicatorWeight: 2,
                    labelColor: const Color(0xFF25D366),
                    unselectedLabelColor: colors.textSecondary,
                    labelStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700),
                    tabs: _tabs
                        .map((t) => Tab(text: t.$2))
                        .toList(),
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

            var items = snap.data!.docs
                .map((d) => ContentPaie.fromJson(
                    {...d.data() as Map<String, dynamic>, 'id': d.id}))
                .toList();

            if (_searchQuery.isNotEmpty) {
              items = items
                  .where((c) =>
                      c.title.toLowerCase().contains(_searchQuery) ||
                      c.hashtags.any((h) =>
                          h.toLowerCase().contains(_searchQuery)))
                  .toList();
            }

            final boosted = items.where((c) => c.isBoostActive).toList();
            final normal = items.where((c) => !c.isBoostActive).toList();
            final merged = [...boosted, ...normal];

            return CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(
                    child: BoostedContentStripWidget()),
                if (merged.isNotEmpty)
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
                        (_, i) => _ContentCard(
                            content: merged[i], colors: colors),
                        childCount: merged.length,
                      ),
                    ),
                  )
                else
                  SliverToBoxAdapter(child: _emptyState(colors)),
              ],
            );
          },
        ),
      ),
      floatingActionButton: isCreator
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF25D366),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ContentFormScreen()),
              ),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _emptyState(AppColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('🛍️', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            'Aucun contenu disponible',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Les créateurs publieront bientôt du contenu',
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
                    child: _MiniTypeBadge(type: content.contentType),
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
                          size: 10,
                          color: colors.textSecondary),
                      const SizedBox(width: 2),
                      Text(
                        _fmt(content.views),
                        style: TextStyle(
                            fontSize: 9,
                            color: colors.textSecondary),
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
            fontSize: 7, fontWeight: FontWeight.w800, color: Colors.white),
      ),
    );
  }

  (String, Color) _info(ContentType t) {
    switch (t) {
      case ContentType.VIDEO: return ('VIDÉO', const Color(0xFF4a90e2));
      case ContentType.EBOOK: return ('EBOOK', const Color(0xFF9b59b6));
      case ContentType.FORMATION: return ('FORM.', const Color(0xFF8e44ad));
      case ContentType.TEMPLATE: return ('TEMPLATE', const Color(0xFFe67e22));
      case ContentType.PACK_ZIP: return ('PACK', const Color(0xFF25D366));
      case ContentType.AUDIO: return ('AUDIO', const Color(0xFFe74c3c));
      case ContentType.PRESET: return ('PRESET', const Color(0xFF1abc9c));
      case ContentType.BUNDLE: return ('BUNDLE', const Color(0xFF16a085));
    }
  }
}
