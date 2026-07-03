import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/contenuPayantProvider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/user_badge_widget.dart';
import '../user/profile/profile.dart';
import 'content_detail_page.dart';
import 'affiliation_marketplace_page.dart';
import 'contentForm.dart';
import 'my_purchases_page.dart';
import 'seriesDetailScreenContenu.dart';

class ProfileScreenContenu extends StatefulWidget {
  final String? userId;
  const ProfileScreenContenu({super.key, this.userId});

  @override
  _ProfileScreenContenuState createState() => _ProfileScreenContenuState();
}

class _ProfileScreenContenuState extends State<ProfileScreenContenu>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool isLoading = true;
  ContentType? _contentTypeFilter;
  final ScrollController _scrollController = ScrollController();

  String _cdnUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    final p = Provider.of<UserAuthProvider>(context, listen: false);
    return p.convertToCdnUrl(url, p.appDefaultData);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => isLoading = true);
    final contentProvider = Provider.of<ContentProvider>(context, listen: false);
    final authProvider = Provider.of<UserAuthProvider>(context, listen: false);
    if (widget.userId != null && widget.userId != authProvider.loginUserData.id) {
      await contentProvider.loadOtherUserContentPaies(widget.userId!);
    } else {
      await contentProvider.loadUserContentPaies();
    }
    setState(() => isLoading = false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final authProvider = Provider.of<UserAuthProvider>(context);
    final contentProvider = Provider.of<ContentProvider>(context);

    final UserData user;
    final bool isCurrentUser;
    final List<ContentPaie> allContent;
    final List<ContentPaie> userSeries;

    if (widget.userId != null && widget.userId != authProvider.loginUserData.id) {
      user = contentProvider.otherUserData ?? authProvider.loginUserData;
      isCurrentUser = false;
      allContent = contentProvider.otherUserContentPaies.where((c) => !c.isSeries).toList();
      userSeries = contentProvider.otherUserContentPaies.where((c) => c.isSeries).toList();
    } else {
      user = authProvider.loginUserData;
      isCurrentUser = true;
      allContent = contentProvider.userContentPaies.where((c) => !c.isSeries).toList();
      userSeries = contentProvider.userContentPaies.where((c) => c.isSeries).toList();
    }

    if (isLoading) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(child: CircularProgressIndicator(color: colors.primary)),
      );
    }

    // ── Guard : profil créateur non activé pour l'utilisateur courant ──────────
    if (isCurrentUser && !(user.isCreatorProfileEnabled ?? false)) {
      return _buildCreatorCTA(colors);
    }

    // Filtre par type de contenu
    final displayed = _contentTypeFilter == null
        ? allContent
        : allContent.where((c) => c.contentType == _contentTypeFilter).toList();

    return Scaffold(
      backgroundColor: colors.background,
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              title: Text(
                isCurrentUser ? 'Mon Profil Créateur' : 'Profil Créateur',
                style: TextStyle(color: colors.onPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              backgroundColor: colors.primary,
              iconTheme: IconThemeData(color: colors.onPrimary),
              actions: isCurrentUser
                  ? [
                      IconButton(
                        icon: Icon(Icons.refresh_rounded, color: colors.onPrimary),
                        onPressed: _loadUserData,
                        tooltip: 'Rafraîchir',
                      ),
                    ]
                  : null,
              pinned: true,
              floating: true,
              snap: true,
              expandedHeight: isCurrentUser ? 500 : 280,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: _buildHeader(user, isCurrentUser, allContent.length, colors),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(46),
                child: Container(
                  color: colors.surface,
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: colors.primary,
                    indicatorWeight: 2,
                    labelColor: colors.primary,
                    unselectedLabelColor: colors.textSecondary,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.grid_view_rounded, size: 16),
                            const SizedBox(width: 6),
                            const Text('Contenus'),
                            const SizedBox(width: 4),
                            _countBadge('${allContent.length}', colors),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.movie_filter, size: 16),
                            const SizedBox(width: 6),
                            const Text('Séries'),
                            const SizedBox(width: 4),
                            _countBadge('${userSeries.length}', colors),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildContentsTab(displayed, allContent, isCurrentUser, colors),
            _buildSeriesTab(userSeries, isCurrentUser, colors),
          ],
        ),
      ),
    );
  }

  // ── CTA si profil créateur non activé ────────────────────────────────────────
  Widget _buildCreatorCTA(AppColors colors) {
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.primary,
        iconTheme: IconThemeData(color: colors.onPrimary),
        title: Text('Espace Créateur', style: TextStyle(color: colors.onPrimary, fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [colors.primary, colors.accent]),
                ),
                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 50),
              ),
              const SizedBox(height: 28),
              Text('Devenez Créateur',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: colors.textPrimary)),
              const SizedBox(height: 12),
              Text(
                'Activez votre profil créateur pour vendre des formations, ebooks, presets, packs et bien plus encore.',
                style: TextStyle(fontSize: 15, color: colors.textSecondary, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text('Commission : 88% des ventes reversés directement sur votre solde.',
                  style: TextStyle(fontSize: 13, color: colors.primary, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfil())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.rocket_launch_rounded),
                  label: const Text('Activer mon espace créateur', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _countBadge(String text, AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.primary)),
    );
  }

  Widget _buildHeader(UserData user, bool isCurrentUser, int totalContent, AppColors colors) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 50),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    // Avatar
                    Stack(
                      children: [
                        Container(
                          width: 84, height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, spreadRadius: 2)],
                          ),
                          child: ClipOval(
                            child: user.imageUrl != null && user.imageUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: _cdnUrl(user.imageUrl),
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(color: Colors.white24, child: const Icon(Icons.person, color: Colors.white, size: 36)),
                                    errorWidget: (_, __, ___) => Container(color: Colors.white24, child: const Icon(Icons.person, color: Colors.white, size: 36)),
                                  )
                                : Container(color: Colors.white24, child: const Icon(Icons.person, color: Colors.white, size: 36)),
                          ),
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: UserBadgeWidget(user: user, size: 18, withBackground: true),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '@${user.pseudo ?? 'Utilisateur'}',
                            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          const Text('Créateur de contenu', style: TextStyle(fontSize: 13, color: Colors.white70)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _statChip(Icons.people_rounded, '${user.userAbonnesIds?.length ?? 0}', 'abonnés'),
                              const SizedBox(width: 12),
                              _statChip(Icons.inventory_2_outlined, '$totalContent', 'contenus'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── Boutons action (créateur courant) ──────────────────────────
              if (isCurrentUser) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ContentFormScreen())),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: colors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                            elevation: 2,
                          ),
                          icon: const Icon(Icons.add_circle, size: 18),
                          label: const Text('Nouveau contenu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfil())),
                        icon: const Icon(Icons.more_horiz, color: Colors.white, size: 26),
                        tooltip: 'Voir profil complet',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── Solde principal ────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 10),
                        const Text('Solde disponible', style: TextStyle(color: Colors.white, fontSize: 13)),
                        const Spacer(),
                        Text(
                          '${user.votre_solde_principal?.toStringAsFixed(0) ?? '0'} FCFA',
                          style: TextStyle(color: colors.accent, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // ── Gains détaillés — 3 cartes ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _gainCard('📦', 'Ventes', user.solde_ventes, colors),
                      const SizedBox(width: 8),
                      _gainCard('🔗', 'Affiliation', user.solde_affiliation, colors),
                      const SizedBox(width: 8),
                      _gainCard('🏷️', 'Promo', user.solde_promo, colors),
                    ],
                  ),
                ),
                const SizedBox(height: 4),

                // ── Section partage profil Business ───────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Builder(builder: (ctx) {
                    final profileLink =
                        'https://afrolookmedia.com/share/creator/${user.id ?? ''}';
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.link_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              profileLink,
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Bouton Copier
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: profileLink));
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                    content: Text('Lien copié !'),
                                    duration: Duration(seconds: 2)),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('Copier',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: colors.primary,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Bouton Partager
                          GestureDetector(
                            onTap: () {

                              Share.share(
                                '🌍 Découvre le profil Business de ${user.pseudo ?? user.nom ?? ''} sur Afrolook !\n\n$profileLink',
                                subject: user.pseudo ?? user.nom ?? 'Profil Business',
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white38),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.share_rounded,
                                      color: Colors.white, size: 12),
                                  SizedBox(width: 4),
                                  Text('Partager',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 3),

                // ── Mes achats & Gains affiliation ─────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyPurchasesPage())),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          ),
                          icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                          label: const Text('Mes achats', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AffiliationMarketplacePage())),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white38),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          ),
                          icon: const Icon(Icons.link_rounded, size: 16),
                          label: const Text('Gains affiliation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 14),
        const SizedBox(width: 4),
        Text('$value ', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  Widget _gainCard(String emoji, String label, double amount, AppColors colors) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              '${amount.toStringAsFixed(0)} F',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  // ── Onglet "Tous les contenus" ─────────────────────────────────────────────
  Widget _buildContentsTab(List<ContentPaie> displayed, List<ContentPaie> all, bool isCurrentUser, AppColors colors) {
    return RefreshIndicator(
      onRefresh: _loadUserData,
      color: colors.primary,
      child: CustomScrollView(
        slivers: [
          // Chips filtre par type
          SliverToBoxAdapter(
            child: _buildTypeFilterChips(all, colors),
          ),

          if (displayed.isEmpty)
            SliverFillRemaining(
              child: _emptyContents(isCurrentUser, colors),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 80),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.71,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _buildContentCard(displayed[i], colors),
                  childCount: displayed.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTypeFilterChips(List<ContentPaie> all, AppColors colors) {
    // Détecter les types présents dans la liste
    final types = all.map((c) => c.contentType).toSet().toList();
    if (types.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        children: [
          _typeChip(null, 'Tous', colors),
          ...types.map((t) => _typeChip(t, _typeLabel(t), colors)),
        ],
      ),
    );
  }

  Widget _typeChip(ContentType? type, String label, AppColors colors) {
    final selected = _contentTypeFilter == type;
    return GestureDetector(
      onTap: () => setState(() => _contentTypeFilter = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? colors.primary : colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? colors.primary : colors.border),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? colors.onPrimary : colors.textSecondary,
            )),
      ),
    );
  }

  Widget _emptyContents(bool isCurrentUser, AppColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 72, color: colors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 20),
          Text(
            isCurrentUser ? 'Aucun contenu publié' : 'Aucun contenu disponible',
            style: TextStyle(color: colors.textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Text(
            isCurrentUser
                ? _contentTypeFilter == null
                    ? 'Commencez par créer votre premier contenu'
                    : 'Aucun contenu de ce type'
                : 'Cet utilisateur n\'a pas encore publié',
            style: TextStyle(color: colors.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          if (isCurrentUser && _contentTypeFilter == null) ...[
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ContentFormScreen())),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: const Text('Créer un contenu', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  // ── Onglet Séries ──────────────────────────────────────────────────────────
  Widget _buildSeriesTab(List<ContentPaie> series, bool isCurrentUser, AppColors colors) {
    if (series.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie_filter_rounded, size: 80, color: colors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 20),
            Text(
              isCurrentUser ? 'Aucune série créée' : 'Aucune série disponible',
              style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              isCurrentUser ? 'Créez votre première série de contenus' : 'Cet utilisateur n\'a pas encore créé de série',
              style: TextStyle(color: colors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (isCurrentUser) ...[
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ContentFormScreen())),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                child: const Text('Créer une série', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUserData,
      color: colors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: series.length,
        itemBuilder: (context, index) => _buildSeriesCard(series[index], isCurrentUser, colors),
      ),
    );
  }

  // ── Carte contenu ──────────────────────────────────────────────────────────
  Widget _buildContentCard(ContentPaie content, AppColors colors) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => ContentDetailPage(content: content))),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: CachedNetworkImage(
                      imageUrl: _cdnUrl(content.thumbnailUrl),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (_, __) => Container(
                          color: colors.shimmerBase,
                          child: Center(child: Icon(_typeIcon(content.contentType), color: colors.textSecondary, size: 36))),
                      errorWidget: (_, __, ___) => Container(
                          color: colors.shimmerBase,
                          child: Center(child: Icon(_typeIcon(content.contentType), color: colors.textSecondary, size: 36))),
                    ),
                  ),
                  // Dégradé bas
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black.withValues(alpha: 0.5), Colors.transparent, Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Badge type
                  Positioned(
                    top: 8, left: 8,
                    child: _buildTypeBadge(content.contentType, colors),
                  ),
                  // Badge prix
                  Positioned(
                    bottom: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: content.isFree ? Colors.green : colors.accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        content.isFree ? 'GRATUIT' : '${content.price.toInt()} F',
                        style: TextStyle(color: content.isFree ? Colors.white : colors.onAccent, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (content.isBoostActive)
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD400),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('⚡', style: TextStyle(fontSize: 10)),
                            const SizedBox(width: 2),
                            Text(
                              content.boostRemainingDays > 0
                                  ? '${content.boostRemainingDays}j'
                                  : 'BOOST',
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.title,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.textPrimary, height: 1.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.remove_red_eye_outlined, size: 11, color: colors.textSecondary),
                      const SizedBox(width: 3),
                      Text('${content.views}', style: TextStyle(fontSize: 10, color: colors.textSecondary)),
                      const SizedBox(width: 8),
                      Icon(Icons.thumb_up_outlined, size: 11, color: colors.textSecondary),
                      const SizedBox(width: 3),
                      Text('${content.likes}', style: TextStyle(fontSize: 10, color: colors.textSecondary)),
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

  Widget _buildTypeBadge(ContentType type, AppColors colors) {
    final (label, color) = _typeInfo(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
    );
  }

  // ── Carte série ────────────────────────────────────────────────────────────
  Widget _buildSeriesCard(ContentPaie serie, bool isCurrentUser, AppColors colors) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SeriesDetailScreen(series: serie))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: SizedBox(
                    height: 140, width: double.infinity,
                    child: CachedNetworkImage(
                      imageUrl: _cdnUrl(serie.thumbnailUrl), fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: colors.shimmerBase),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter, end: Alignment.topCenter,
                          colors: [Colors.black.withValues(alpha: 0.65), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 16, right: 16, bottom: 14,
                  child: Text(
                    serie.title,
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))]),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                ),
                Positioned(
                  top: 14, right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: colors.primary, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.movie_filter_rounded, color: colors.onPrimary, size: 13),
                        const SizedBox(width: 4),
                        Text('SÉRIE', style: TextStyle(color: colors.onPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (serie.description.isNotEmpty)
                    Text(serie.description,
                        style: TextStyle(fontSize: 13, color: colors.textSecondary, height: 1.4),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: serie.isFree ? Colors.green.withValues(alpha: 0.1) : colors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: serie.isFree ? Colors.green : colors.accent),
                        ),
                        child: Text(
                          serie.isFree ? 'GRATUIT' : '${serie.price.toInt()} FCFA',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: serie.isFree ? Colors.green : colors.accent),
                        ),
                      ),
                      const Spacer(),
                      FutureBuilder<List<Episode>>(
                        future: Provider.of<ContentProvider>(context, listen: false).getEpisodesForSeries(serie.id!),
                        builder: (context, snapshot) {
                          final count = snapshot.hasData ? snapshot.data!.length : 0;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(color: colors.surfaceVariant, borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.playlist_play_rounded, size: 14, color: colors.primary),
                                const SizedBox(width: 5),
                                Text('$count épisode${count != 1 ? 's' : ''}',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                              ],
                            ),
                          );
                        },
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ContentFormScreen(isEpisode: true, seriesId: serie.id),
                          )),
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
                            child: Icon(Icons.add_rounded, color: colors.onPrimary, size: 20),
                          ),
                        ),
                      ],
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

  // ── Helpers types ──────────────────────────────────────────────────────────
  String _typeLabel(ContentType t) {
    switch (t) {
      case ContentType.VIDEO: return '🎬 Vidéo';
      case ContentType.EBOOK: return '📘 Ebook';
      case ContentType.FORMATION: return '🎓 Formation';
      case ContentType.TEMPLATE: return '🎨 Template';
      case ContentType.PACK_ZIP: return '📦 Pack';
      case ContentType.AUDIO: return '🎵 Audio';
      case ContentType.PRESET: return '🎛️ Preset';
      case ContentType.BUNDLE: return '🗂️ Bundle';
    }
  }

  IconData _typeIcon(ContentType t) {
    switch (t) {
      case ContentType.VIDEO: return Icons.videocam_rounded;
      case ContentType.EBOOK: return Icons.menu_book_rounded;
      case ContentType.FORMATION: return Icons.school_rounded;
      case ContentType.TEMPLATE: return Icons.design_services_rounded;
      case ContentType.PACK_ZIP: return Icons.folder_zip_rounded;
      case ContentType.AUDIO: return Icons.headphones_rounded;
      case ContentType.PRESET: return Icons.tune_rounded;
      case ContentType.BUNDLE: return Icons.layers_rounded;
    }
  }

  (String, Color) _typeInfo(ContentType t) {
    switch (t) {
      case ContentType.VIDEO: return ('VIDÉO', const Color(0xFF4a90e2));
      case ContentType.EBOOK: return ('EBOOK', const Color(0xFF9b59b6));
      case ContentType.FORMATION: return ('FORMAT.', const Color(0xFF8e44ad));
      case ContentType.TEMPLATE: return ('TEMPLATE', const Color(0xFFe67e22));
      case ContentType.PACK_ZIP: return ('PACK', const Color(0xFF25D366));
      case ContentType.AUDIO: return ('AUDIO', const Color(0xFFe74c3c));
      case ContentType.PRESET: return ('PRESET', const Color(0xFF1abc9c));
      case ContentType.BUNDLE: return ('BUNDLE', const Color(0xFF16a085));
    }
  }
}
