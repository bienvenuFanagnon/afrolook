import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/model_data.dart';
import '../../pages/canaux/detailsCanal.dart';
import '../../services/active_creators_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/user_badge_widget.dart';
import 'creator_unseen_posts_page.dart';
import 'following_unseen_feed_page.dart';

// ── Type unifié pour mélanger créateurs et canaux dans une liste triée ────────

class _FeedItem {
  final ActiveCreator? creator;
  final ActiveCanal? canal;
  final int sortUs; // microsecondes — tri décroissant

  _FeedItem.creator(ActiveCreator c)
      : creator = c,
        canal = null,
        sortUs = c.lastActivityUs;

  _FeedItem.canal(ActiveCanal c)
      : canal = c,
        creator = null,
        sortUs = c.lastActivityUs;

  bool get isCreator => creator != null;
}

/// Liste paginée des créateurs actifs + canaux — affichage MIXTE trié par date.
///
/// Phase 1 – Créateurs avec posts non vus (mémoire, O(1)) → toujours en premier.
/// Phase 2 – Créateurs récents + canaux mélangés, triés par lastActivityUs.
class ActiveCreatorsListPage extends StatefulWidget {
  final List<String> abonnesIds;
  final List<String> viewedPostIds;
  final String currentUserId;

  /// Posts non vus par créateur (en mémoire depuis HomeConstPost).
  final Map<String, int> unseenCounts;

  /// IDs des canaux suivis.
  final List<String> followedCanalIds;

  /// Canaux pré-chargés par HomeConstPost avec timestamp d'activité.
  final List<ActiveCanal> recentCanaux;

  /// Créateurs déjà chargés depuis HomeConstPost (évite un double-fetch).
  final List<ActiveCreator> preloadedCreators;

  const ActiveCreatorsListPage({
    super.key,
    required this.abonnesIds,
    required this.viewedPostIds,
    required this.currentUserId,
    this.unseenCounts = const {},
    this.followedCanalIds = const [],
    this.recentCanaux = const [],
    this.preloadedCreators = const [],
  });

  @override
  State<ActiveCreatorsListPage> createState() => _ActiveCreatorsListPageState();
}

class _ActiveCreatorsListPageState extends State<ActiveCreatorsListPage> {
  final _service = ActiveCreatorsService();

  // Phase 1 : non-vus (haut de liste, triés par count desc)
  List<ActiveCreator> _unseenCreators = [];

  // Phase 2 : liste mixte créateurs + canaux, triée par date
  List<_FeedItem> _mixedItems = [];
  bool _loadingMixed = true;
  bool _hasMoreCreators = true;

  static const _pageSize = 10;

  @override
  void initState() {
    super.initState();
    // Les deux phases chargent en parallèle
    Future.wait([
      _loadUnseenCreators(),
      _loadNextMixedPage(),
    ]);
  }

  // ── Phase 1 ──────────────────────────────────────────────────────────────────

  Future<void> _loadUnseenCreators() async {
    // Si des créateurs pré-chargés sont disponibles, on les utilise directement
    if (widget.preloadedCreators.isNotEmpty) {
      final withUnseen = widget.preloadedCreators
          .where((c) => c.unseenCount > 0)
          .toList()
        ..sort((a, b) => b.unseenCount.compareTo(a.unseenCount));
      if (mounted && withUnseen.isNotEmpty) {
        setState(() => _unseenCreators = withUnseen);
      }
      return;
    }

    final unseenIds = widget.unseenCounts.keys.toList();
    if (unseenIds.isEmpty) return;
    try {
      final users = await _service.fetchUsersById(unseenIds);
      if (mounted) {
        setState(() {
          _unseenCreators = users
              .where((u) => u.id != null)
              .map((u) => ActiveCreator(
                    user: u,
                    unseenCount: widget.unseenCounts[u.id!] ?? 0,
                  ))
              .toList()
            ..sort((a, b) => b.unseenCount.compareTo(a.unseenCount));
        });
      }
    } catch (_) {}
  }

  // ── Phase 2 : liste mixte paginée ────────────────────────────────────────────

  Future<void> _loadNextMixedPage() async {
    if (!_hasMoreCreators) return;
    if (mounted) setState(() => _loadingMixed = true);

    // ── Première page avec créateurs pré-chargés ─────────────────────────────
    if (_mixedItems.isEmpty && widget.preloadedCreators.isNotEmpty) {
      final canalItems = widget.recentCanaux.map(_FeedItem.canal).toList();
      // Créateurs pré-chargés sans posts non vus (ceux avec non-vus sont en phase 1)
      final creatorItems = widget.preloadedCreators
          .where((c) => c.unseenCount == 0)
          .map(_FeedItem.creator)
          .toList();
      if (mounted) {
        setState(() {
          _mixedItems = [...creatorItems, ...canalItems]
            ..sort((a, b) => b.sortUs.compareTo(a.sortUs));
          _hasMoreCreators = widget.abonnesIds.length > widget.preloadedCreators.length;
        });
      }
      if (mounted) setState(() => _loadingMixed = false);
      return;
    }

    // ── Pages suivantes (ou première page sans pré-chargement) ────────────────
    final unseenIds = Set<String>.from(widget.unseenCounts.keys);
    final alreadyShownCreatorIds = {
      ...unseenIds,
      ..._mixedItems
          .where((i) => i.isCreator)
          .map((i) => i.creator!.user.id ?? ''),
    };

    try {
      final newCreators = await _service.fetchFollowedRecentCreators(
        widget.abonnesIds,
        limit: _pageSize,
        excludeIds: alreadyShownCreatorIds,
        viewedPostIds: widget.viewedPostIds,
      );

      if (mounted) {
        setState(() {
          if (_mixedItems.isEmpty) {
            final canalItems = widget.recentCanaux.map(_FeedItem.canal).toList();
            final creatorItems = newCreators.map(_FeedItem.creator).toList();
            _mixedItems = [...creatorItems, ...canalItems]
              ..sort((a, b) => b.sortUs.compareTo(a.sortUs));
          } else {
            final creatorItems = newCreators.map(_FeedItem.creator).toList();
            _mixedItems = [..._mixedItems, ...creatorItems]
              ..sort((a, b) => b.sortUs.compareTo(a.sortUs));
          }
          _hasMoreCreators = newCreators.length >= _pageSize;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingMixed = false);
  }

  // ── Navigation ────────────────────────────────────────────────────────────────

  void _openCreator(ActiveCreator ac) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreatorUnseenPostsPage(
          creator: ac.user,
          unseenCount: ac.unseenCount,
          viewedPostIds: widget.viewedPostIds,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
  }

  void _openCanal(Canal canal) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CanalDetails(canal: canal)),
    );
  }

  void _openUnseenFeed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FollowingUnseenFeedPage(
          unseenCreatorIds: widget.unseenCounts.keys.toList(),
          followedCanalIds: widget.followedCanalIds,
          totalUnseen: widget.unseenCounts.values.fold(0, (a, b) => a + b),
          currentUserId: widget.currentUserId,
          viewedPostIds: widget.viewedPostIds,
        ),
      ),
    );
  }

  // ── UI ───────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final hasUnseen = _unseenCreators.isNotEmpty;
    final totalUnseen = widget.unseenCounts.values.fold(0, (a, b) => a + b);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: Text(
          'Créateurs & Canaux',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          // ── Bouton "Voir tous les posts non vus" ───────────────────────────
          if (hasUnseen || totalUnseen > 0)
            SliverToBoxAdapter(
              child: GestureDetector(
                onTap: _openUnseenFeed,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFD700), Color(0xFF8B0000)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.play_circle_fill_rounded,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Voir tous les posts non vus',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            if (totalUnseen > 0)
                              Text(
                                '$totalUnseen nouveau${totalUnseen > 1 ? 'x' : ''} post${totalUnseen > 1 ? 's' : ''}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
            ),

          // ── Section : Posts non vus (toujours en tête) ────────────────────
          if (hasUnseen) ...[
            _sectionHeader(colors, 'Ont posté du nouveau'),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _CreatorTile(
                  creator: _unseenCreators[i],
                  colors: colors,
                  onTap: () => _openCreator(_unseenCreators[i]),
                ),
                childCount: _unseenCreators.length,
              ),
            ),
          ],

          // ── Section : Liste mixte créateurs + canaux triée par date ────────
          _sectionHeader(colors, 'Récents'),

          if (_loadingMixed && _mixedItems.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                    child: CircularProgressIndicator(color: colors.primary)),
              ),
            )
          else if (_mixedItems.isEmpty && !_loadingMixed)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Aucun créateur ou canal récent',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) {
                  final item = _mixedItems[i];
                  if (item.isCreator) {
                    return _CreatorTile(
                      creator: item.creator!,
                      colors: colors,
                      onTap: () => _openCreator(item.creator!),
                    );
                  } else {
                    return _CanalTile(
                      activeCanal: item.canal!,
                      colors: colors,
                      onTap: () => _openCanal(item.canal!.canal),
                    );
                  }
                },
                childCount: _mixedItems.length,
              ),
            ),

          // ── Bouton "Voir plus" ─────────────────────────────────────────────
          if (_hasMoreCreators || _loadingMixed)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
                  child: _loadingMixed
                      ? CircularProgressIndicator(
                          color: colors.primary, strokeWidth: 2)
                      : TextButton(
                          onPressed: _loadNextMixedPage,
                          child: Text(
                            'Voir plus',
                            style: TextStyle(color: colors.primary),
                          ),
                        ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  SliverToBoxAdapter _sectionHeader(AppColors colors, String title) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
        child: Text(
          title,
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── Tile créateur ─────────────────────────────────────────────────────────────

class _CreatorTile extends StatelessWidget {
  final ActiveCreator creator;
  final AppColors colors;
  final VoidCallback onTap;

  const _CreatorTile({
    required this.creator,
    required this.colors,
    required this.onTap,
  });

  String _flagEmoji(String code) => code.toUpperCase().codeUnits
      .map((c) => String.fromCharCode(c + 127397))
      .join();

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final user = creator.user;
    final rawCode = user.countryData?['countryCode']?.toUpperCase();
    final flag =
        rawCode != null && rawCode.length == 2 ? _flagEmoji(rawCode) : null;
    final followers =
        _formatCount(user.userAbonnesIds?.length ?? user.abonnes ?? 0);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colors.surfaceVariant,
                  backgroundImage:
                      user.imageUrl != null && user.imageUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(user.imageUrl!)
                          : null,
                  child: user.imageUrl == null || user.imageUrl!.isEmpty
                      ? Icon(Icons.person,
                          color: colors.textSecondary, size: 28)
                      : null,
                ),
                if (creator.unseenCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: colors.background, width: 1.5),
                      ),
                      child: Text(
                        '${creator.unseenCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '@${user.pseudo?.replaceAll('@', '') ?? 'user'}',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      UserBadgeWidget(
                          user: user, size: 12, withBackground: false),
                      if (flag != null) ...[
                        const SizedBox(width: 4),
                        Text(flag, style: const TextStyle(fontSize: 12)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.group,
                          size: 10, color: colors.textSecondary),
                      const SizedBox(width: 3),
                      Text(
                        followers,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        creator.unseenCount > 0
                            ? '${creator.unseenCount} nouveau${creator.unseenCount > 1 ? 'x' : ''} post${creator.unseenCount > 1 ? 's' : ''}'
                            : 'Actif récemment',
                        style: TextStyle(
                          color: creator.unseenCount > 0
                              ? colors.primary
                              : colors.textSecondary,
                          fontSize: 11,
                          fontWeight: creator.unseenCount > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tile canal ────────────────────────────────────────────────────────────────

class _CanalTile extends StatelessWidget {
  final ActiveCanal activeCanal;
  final AppColors colors;
  final VoidCallback onTap;

  const _CanalTile({
    required this.activeCanal,
    required this.colors,
    required this.onTap,
  });

  Canal get canal => activeCanal.canal;

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final name = canal.titre ?? 'Canal';
    final followers =
        _formatCount(canal.usersSuiviId?.length ?? canal.suivi ?? 0);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF8B0000), width: 2),
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: colors.surfaceVariant,
                backgroundImage:
                    canal.urlImage != null && canal.urlImage!.isNotEmpty
                        ? CachedNetworkImageProvider(canal.urlImage!)
                        : null,
                child: canal.urlImage == null || canal.urlImage!.isEmpty
                    ? Icon(Icons.campaign_rounded,
                        color: colors.textSecondary, size: 24)
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B0000)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Canal',
                          style: TextStyle(
                            color: Color(0xFF8B0000),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.group,
                          size: 10, color: colors.textSecondary),
                      const SizedBox(width: 3),
                      Text(
                        followers,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        activeCanal.lastActivityUs > 0
                            ? 'Actif récemment'
                            : 'Canal suivi',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: colors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
