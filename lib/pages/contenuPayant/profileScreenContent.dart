import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../models/model_data.dart';
import '../../providers/authProvider.dart';
import '../../providers/contenuPayantProvider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/user_badge_widget.dart';
import '../user/profile/profile.dart';
import 'contentDetails.dart';
import 'contentDetailsEbook.dart';
import 'contentForm.dart';
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
    final List<ContentPaie> userVideos;
    final List<ContentPaie> userSeries;

    if (widget.userId != null && widget.userId != authProvider.loginUserData.id) {
      user = contentProvider.otherUserData ?? authProvider.loginUserData;
      isCurrentUser = false;
      userVideos = contentProvider.otherUserContentPaies.where((c) => !c.isSeries).toList();
      userSeries = contentProvider.otherUserContentPaies.where((c) => c.isSeries).toList();
    } else {
      user = authProvider.loginUserData;
      isCurrentUser = true;
      userVideos = contentProvider.userContentPaies.where((c) => !c.isSeries).toList();
      userSeries = contentProvider.userContentPaies.where((c) => c.isSeries).toList();
    }

    if (isLoading) {
      return Scaffold(
        backgroundColor: colors.background,
        body: Center(child: CircularProgressIndicator(color: colors.primary)),
      );
    }

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
              expandedHeight: 340,
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: _buildHeader(user, isCurrentUser, colors),
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
                            const Icon(Icons.videocam, size: 18),
                            const SizedBox(width: 6),
                            const Text('Vidéos/Ebooks'),
                            const SizedBox(width: 4),
                            _countBadge('${userVideos.length}', colors),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.movie_filter, size: 18),
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
            _buildVideosTab(userVideos, isCurrentUser, colors),
            _buildSeriesTab(userSeries, isCurrentUser, colors),
          ],
        ),
      ),
    );
  }

  Widget _countBadge(String text, AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.primary)),
    );
  }

  Widget _buildHeader(UserData user, bool isCurrentUser, AppColors colors) {
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
        child: Column(
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
                        width: 90, height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, spreadRadius: 2)],
                        ),
                        child: ClipOval(
                          child: user.imageUrl != null && user.imageUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: _cdnUrl(user.imageUrl),
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(color: Colors.white24, child: const Icon(Icons.person, color: Colors.white, size: 40)),
                                  errorWidget: (_, __, ___) => Container(color: Colors.white24, child: const Icon(Icons.person, color: Colors.white, size: 40)),
                                )
                              : Container(color: Colors.white24, child: const Icon(Icons.person, color: Colors.white, size: 40)),
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
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        const Text('Créateur de contenu', style: TextStyle(fontSize: 14, color: Colors.white70)),
                        const SizedBox(height: 10),
                        _buildStatItem(Icons.people_rounded, '${user.userAbonnesIds?.length ?? 0}', 'Abonnés'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.add_circle, size: 20),
                        label: const Text('Nouveau contenu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserProfil())),
                      icon: const Icon(Icons.more_horiz, color: Colors.white, size: 28),
                      tooltip: 'Voir profil complet',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      const Text('Solde :', style: TextStyle(color: Colors.white, fontSize: 15)),
                      const Spacer(),
                      Text(
                        '${user.votre_solde_principal?.toStringAsFixed(0) ?? '0'} FCFA',
                        style: TextStyle(color: colors.accent, fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }

  Widget _buildVideosTab(List<ContentPaie> videos, bool isCurrentUser, AppColors colors) {
    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off_rounded, size: 80, color: colors.textSecondary.withOpacity(0.4)),
            const SizedBox(height: 20),
            Text(
              isCurrentUser ? 'Aucun contenu publié' : 'Aucun contenu disponible',
              style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              isCurrentUser ? 'Commencez par créer votre premier contenu' : 'Cet utilisateur n\'a pas encore publié',
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
                child: const Text('Créer un contenu', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUserData,
      color: colors.primary,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.71,
        ),
        itemCount: videos.length,
        itemBuilder: (context, index) => _buildContentCard(videos[index], colors),
      ),
    );
  }

  Widget _buildSeriesTab(List<ContentPaie> series, bool isCurrentUser, AppColors colors) {
    if (series.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie_filter_rounded, size: 80, color: colors.textSecondary.withOpacity(0.4)),
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

  Widget _buildContentCard(ContentPaie content, AppColors colors) {
    return GestureDetector(
      onTap: () {
        if (content.isEbook) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => EbookDetailScreen(content: content)));
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => ContentDetailScreen(content: content)));
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: SizedBox(
                    height: 130,
                    child: CachedNetworkImage(
                      imageUrl: _cdnUrl(content.thumbnailUrl),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (_, __) => Container(color: colors.shimmerBase, child: Center(child: CircularProgressIndicator(color: colors.primary, strokeWidth: 2))),
                      errorWidget: (_, __, ___) => Container(color: colors.shimmerBase, child: Center(child: Icon(content.isVideo ? Icons.videocam_rounded : Icons.menu_book_rounded, color: colors.textSecondary, size: 40))),
                    ),
                  ),
                ),
                // Dégradé bas
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter, end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.55), Colors.transparent, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),
                // Badge type
                Positioned(
                  top: 10, left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: content.isVideo ? colors.primary : colors.accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(content.isVideo ? Icons.play_arrow_rounded : Icons.book_rounded, color: content.isVideo ? colors.onPrimary : colors.onAccent, size: 13),
                        const SizedBox(width: 3),
                        Text(
                          content.isVideo ? 'VIDÉO' : 'EBOOK',
                          style: TextStyle(color: content.isVideo ? colors.onPrimary : colors.onAccent, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                // Badge prix
                Positioned(
                  bottom: 10, right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: content.isFree ? Colors.green : colors.accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      content.isFree ? 'GRATUIT' : '${content.price.toInt()} FCFA',
                      style: TextStyle(
                        color: content.isFree ? Colors.white : colors.onAccent,
                        fontSize: 11, fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                // Bouton play pour vidéos
                if (content.isVideo)
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
              ],
            ),
            // Infos
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary, height: 1.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildStatWithIcon(icon: Icons.remove_red_eye_outlined, value: '${content.views}', color: colors.textSecondary),
                      const SizedBox(width: 10),
                      _buildStatWithIcon(icon: Icons.thumb_up_outlined, value: '${content.likes}', color: colors.textSecondary),
                      const Spacer(),
                      if (content.isEbook && content.pageCount > 0)
                        _buildStatWithIcon(icon: Icons.menu_book_outlined, value: '${content.pageCount}p', color: colors.primary),
                      if (content.isVideo && content.duration > 0)
                        _buildStatWithIcon(icon: Icons.timer_outlined, value: _formatDuration(content.duration), color: colors.primary),
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

  Widget _buildSeriesCard(ContentPaie serie, bool isCurrentUser, AppColors colors) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SeriesDetailScreen(series: serie))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 12, offset: const Offset(0, 4))],
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
                // Dégradé
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter, end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.65), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ),
                // Titre
                Positioned(
                  left: 16, right: 16, bottom: 14,
                  child: Text(
                    serie.title,
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))]),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Badge SÉRIE
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
                      // Badge prix
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: serie.isFree ? Colors.green.withOpacity(0.1) : colors.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: serie.isFree ? Colors.green : colors.accent),
                        ),
                        child: Text(
                          serie.isFree ? 'GRATUIT' : '${serie.price.toInt()} FCFA',
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold,
                            color: serie.isFree ? Colors.green : colors.accent,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Épisodes
                      FutureBuilder<List<Episode>>(
                        future: Provider.of<ContentProvider>(context, listen: false).getEpisodesForSeries(serie.id!),
                        builder: (context, snapshot) {
                          final count = snapshot.hasData ? snapshot.data!.length : 0;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: colors.surfaceVariant,
                              borderRadius: BorderRadius.circular(12),
                            ),
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

  Widget _buildStatWithIcon({required IconData icon, required String value, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m';
    return '${seconds}s';
  }
}
