import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../../providers/authProvider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/chat/generic_share_sheet.dart';
import '../pub/native_ad_widget.dart';
import 'create_live_page.dart';
import 'live_ended_page.dart';
import 'livePage.dart';
import 'livesAgora.dart';
import 'mesLives.dart';

class LiveListPage extends StatefulWidget {
  @override
  _LiveListPageState createState() => _LiveListPageState();
}

class _LiveListPageState extends State<LiveListPage> with SingleTickerProviderStateMixin {
  final RefreshController _refreshController = RefreshController(initialRefresh: false);
  late TabController _tabController;
  int _selectedTab = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTab);
    _loadLives(reset: true);
  }

  void _handleTab() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _selectedTab = _tabController.index;
        _isLoading = true;
      });
      _loadLives(reset: true);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _loadLives({bool reset = false}) async {
    final lp = context.read<LiveProvider>();
    setState(() => _isLoading = true);
    try {
      if (_selectedTab == 1) {
        await lp.fetchActiveLivesBatch(reset: reset);
      } else {
        await lp.fetchAllLivesBatch(reset: reset);
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadMore() async {
    final lp = context.read<LiveProvider>();
    try {
      if (_selectedTab == 1) {
        await lp.fetchActiveLivesBatch();
      } else {
        await lp.fetchAllLivesBatch();
      }
      _refreshController.loadComplete();
    } catch (_) {
      _refreshController.loadFailed();
    }
  }

  void _onRefresh() async {
    await _loadLives(reset: true);
    _refreshController.refreshCompleted();
  }

  List<PostLive> _organizedLives(LiveProvider lp) {
    final actifs = lp.activeLives.isNotEmpty
        ? List<PostLive>.from(lp.activeLives)
        : lp.allLives.where((l) => l.isLive).toList();
    final termines = lp.endedLives.isNotEmpty
        ? List<PostLive>.from(lp.endedLives)
        : lp.allLives.where((l) => !l.isLive).toList();
    actifs.sort((a, b) => b.giftTotal.compareTo(a.giftTotal));
    termines.sort((a, b) => b.startTime.compareTo(a.startTime));
    return [...actifs, ...termines];
  }

  void _shareLive(PostLive live) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GenericShareSheet(
        itemId: live.liveId ?? '',
        itemType: 'live',
        title: live.title,
        subtitle: live.isLive ? '🔴 Live en cours' : 'Live terminé',
        thumbnail: live.hostImage ?? '',
        icon: Icons.live_tv_rounded,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<UserAuthProvider>();
    final lp = context.watch<LiveProvider>();

    final all = _organizedLives(lp);
    final actifs = all.where((l) => l.isLive).toList();
    final termines = all.where((l) => !l.isLive).toList();

    List<PostLive> displayed;
    if (_selectedTab == 1) {
      displayed = actifs;
    } else if (_selectedTab == 2) {
      displayed = all.where((l) => l.hostId == auth.userId).toList();
    } else {
      displayed = all;
    }

    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(auth, colors),
            _buildTabs(colors),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: colors.accent))
                  : SmartRefresher(
                      controller: _refreshController,
                      enablePullDown: true,
                      enablePullUp: displayed.length >= 10,
                      onRefresh: _onRefresh,
                      onLoading: _loadMore,
                      header: WaterDropHeader(
                        waterDropColor: colors.accent,
                        complete: Icon(Icons.check, color: colors.accent),
                      ),
                      child: _selectedTab == 0
                          ? _buildAllTab(actifs, termines, colors)
                          : _buildSimpleList(displayed, colors),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: colors.accent,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateLivePage())),
        child: Icon(Icons.videocam_rounded, color: colors.onAccent),
      ),
    );
  }

  Widget _buildHeader(UserAuthProvider auth, AppColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lives', style: TextStyle(color: colors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
              Text('Afrolook', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => UserLivesPage())),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: colors.surfaceVariant,
              backgroundImage: (auth.loginUserData.imageUrl?.isNotEmpty == true)
                  ? CachedNetworkImageProvider(auth.loginUserData.imageUrl!)
                  : null,
              child: auth.loginUserData.imageUrl?.isNotEmpty != true
                  ? Icon(Icons.person, color: colors.textSecondary, size: 18)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _loadLives(reset: true),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.border),
              ),
              child: Icon(Icons.refresh_rounded, color: colors.textSecondary, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(AppColors colors) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      height: 36,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Tous'),
          Tab(text: 'En cours'),
          Tab(text: 'Mes lives'),
        ],
        indicator: BoxDecoration(
          color: colors.accent,
          borderRadius: BorderRadius.circular(20),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: colors.onAccent,
        unselectedLabelColor: colors.textSecondary,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
      ),
    );
  }

  Widget _buildAllTab(List<PostLive> actifs, List<PostLive> termines, AppColors colors) {
    return CustomScrollView(
      slivers: [
        if (actifs.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: colors.danger, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${actifs.length} live${actifs.length > 1 ? 's' : ''} en cours',
                    style: TextStyle(color: colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildActiveCarousel(actifs, colors)),
        ],
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, actifs.isNotEmpty ? 28 : 20, 16, 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Récents', style: TextStyle(color: colors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                Text('${termines.length} lives', style: TextStyle(color: colors.textSecondary.withOpacity(0.6), fontSize: 12)),
              ],
            ),
          ),
        ),
        if (termines.isEmpty) const SliverToBoxAdapter(child: SizedBox()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                final live = termines[i];
                if (i > 0 && i % 4 == 0) {
                  return Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: colors.border),
                        ),
                        child: MrecAdWidget(key: ValueKey('ad_$i'), useBanner: true),
                      ),
                      const SizedBox(height: 10),
                    ],
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildEndedCard(live, colors),
                );
              },
              childCount: termines.length,
            ),
          ),
        ),
        if (termines.isEmpty && actifs.isEmpty)
          SliverFillRemaining(child: _buildEmptyState(colors)),
      ],
    );
  }

  Widget _buildSimpleList(List<PostLive> lives, AppColors colors) {
    if (lives.isEmpty) return _buildEmptyState(colors);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      itemCount: lives.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final live = lives[i];
        final colors = AppColors.of(context);
        return live.isLive ? _buildActiveListCard(live, colors) : _buildEndedCard(live, colors);
      },
    );
  }

  Widget _buildActiveCarousel(List<PostLive> actifs, AppColors colors) {
    return SizedBox(
      height: 240,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: actifs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _buildActiveCard(actifs[i], colors),
      ),
    );
  }

  Widget _buildActiveCard(PostLive live, AppColors colors) {
    final auth = context.read<UserAuthProvider>();
    final isHost = live.hostId == auth.userId;
    final isInvited = live.invitedUsers.contains(auth.userId);
    final cardImage = (live.coverImage?.isNotEmpty == true) ? live.coverImage! : (live.hostImage ?? '');

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => LivePage(
          liveId: live.liveId!, isHost: isHost,
          hostName: live.hostName!, hostImage: live.hostImage!,
          isInvited: isInvited, postLive: live,
        ),
      )),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 148,
          color: colors.surface,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (cardImage.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: cardImage, fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(color: colors.surfaceVariant),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xCC000000)], stops: [0.45, 1.0],
                  ),
                ),
              ),
              Positioned(top: 10, left: 10, child: _liveBadge()),
              if (live.isPaidLive)
                Positioned(
                  top: 10, right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: Colors.purple.withOpacity(0.85), borderRadius: BorderRadius.circular(20)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded, color: Colors.white, size: 9),
                        SizedBox(width: 3),
                        Text('PRIVÉ', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                )
              else
                Positioned(
                  top: 10, right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.remove_red_eye_rounded, color: Colors.white70, size: 10),
                        const SizedBox(width: 3),
                        Text(_formatCount(live.viewerCount), style: const TextStyle(color: Colors.white70, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              Positioned(
                bottom: 10, left: 10, right: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: live.hostImage?.isNotEmpty == true ? CachedNetworkImageProvider(live.hostImage!) : null,
                          backgroundColor: colors.surfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: Text(live.hostName ?? '', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(live.title, style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.favorite_rounded, color: Color(0xFFFF6B6B), size: 11),
                        const SizedBox(width: 3),
                        Text(_formatCount(live.likeCount ?? 0), style: const TextStyle(color: Colors.white60, fontSize: 10)),
                        const SizedBox(width: 8),
                        Icon(Icons.card_giftcard_rounded, color: colors.accent, size: 11),
                        const SizedBox(width: 3),
                        Text('${_formatCount(live.giftCoinsTotal)} pcs', style: const TextStyle(color: Colors.white60, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveListCard(PostLive live, AppColors colors) {
    final auth = context.read<UserAuthProvider>();
    final isHost = live.hostId == auth.userId;
    final isInvited = live.invitedUsers.contains(auth.userId);
    final cardImage = (live.coverImage?.isNotEmpty == true) ? live.coverImage! : (live.hostImage ?? '');

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => LivePage(
          liveId: live.liveId!, isHost: isHost,
          hostName: live.hostName!, hostImage: live.hostImage!,
          isInvited: isInvited, postLive: live,
        ),
      )),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.danger.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
              child: Stack(
                children: [
                  SizedBox(
                    width: 72, height: 90,
                    child: cardImage.isNotEmpty
                        ? CachedNetworkImage(imageUrl: cardImage, fit: BoxFit.cover)
                        : Container(color: colors.surfaceVariant),
                  ),
                  Positioned(top: 6, left: 6, child: _liveBadge(small: true)),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(radius: 9,
                          backgroundImage: live.hostImage?.isNotEmpty == true ? CachedNetworkImageProvider(live.hostImage!) : null,
                          backgroundColor: colors.surfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(child: Text(live.hostName ?? '', style: TextStyle(color: colors.textSecondary, fontSize: 11), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(live.title, style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _statChip(Icons.remove_red_eye_rounded, _formatCount(live.viewerCount), colors.textSecondary),
                        const SizedBox(width: 10),
                        _statChip(Icons.favorite_rounded, _formatCount(live.likeCount ?? 0), const Color(0xFFFF6B6B)),
                        const SizedBox(width: 10),
                        _statChip(Icons.card_giftcard_rounded, '${_formatCount(live.giftCoinsTotal)} pcs', colors.accent),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right_rounded, color: colors.border, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEndedCard(PostLive live, AppColors colors) {
    final duration = _formatDuration(live.startTime, live.endTime);
    final ago = _formatAgo(live.startTime);
    final cardImage = (live.coverImage?.isNotEmpty == true) ? live.coverImage! : (live.hostImage ?? '');

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LiveEndedPage(live: live))),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
              child: Stack(
                children: [
                  Container(
                    width: 80, height: 80,
                    color: colors.surfaceVariant,
                    child: cardImage.isNotEmpty
                        ? ColorFiltered(
                            colorFilter: const ColorFilter.mode(Colors.black45, BlendMode.darken),
                            child: CachedNetworkImage(imageUrl: cardImage, fit: BoxFit.cover),
                          )
                        : null,
                  ),
                  Positioned(
                    top: 6, left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(color: colors.textSecondary.withOpacity(0.7), borderRadius: BorderRadius.circular(10)),
                      child: const Text('FIN', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  if (live.isPaidLive)
                    const Positioned(top: 6, right: 6, child: Icon(Icons.lock_rounded, color: Colors.purpleAccent, size: 12)),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(radius: 9,
                          backgroundImage: live.hostImage?.isNotEmpty == true ? CachedNetworkImageProvider(live.hostImage!) : null,
                          backgroundColor: colors.surfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(child: Text(live.hostName ?? '', style: TextStyle(color: colors.textSecondary, fontSize: 11), overflow: TextOverflow.ellipsis)),
                        Text(ago, style: TextStyle(color: colors.textSecondary.withOpacity(0.5), fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(live.title, style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _statChip(Icons.remove_red_eye_rounded, _formatCount(live.totalspectateurs.length), colors.textSecondary.withOpacity(0.6)),
                        const SizedBox(width: 8),
                        _statChip(Icons.favorite_rounded, _formatCount(live.likeCount ?? 0), const Color(0xFFFF6B6B).withOpacity(0.7)),
                        const SizedBox(width: 8),
                        _statChip(Icons.card_giftcard_rounded, '${_formatCount(live.giftCoinsTotal)} pcs', colors.accent.withOpacity(0.7)),
                        const Spacer(),
                        Text(duration, style: TextStyle(color: colors.textSecondary.withOpacity(0.4), fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: () => _shareLive(live),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.ios_share_rounded, color: colors.border, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _liveBadge({bool small = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 5 : 8, vertical: small ? 2 : 3),
      decoration: BoxDecoration(color: const Color(0xFFFF3B30), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: small ? 4 : 5, height: small ? 4 : 5, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
          SizedBox(width: small ? 3 : 4),
          Text('LIVE', style: TextStyle(color: Colors.white, fontSize: small ? 8 : 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _statChip(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 11),
        const SizedBox(width: 3),
        Text(value, style: TextStyle(color: color, fontSize: 10)),
      ],
    );
  }

  Widget _buildEmptyState(AppColors colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off_rounded, size: 56, color: colors.textSecondary.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text('Aucun live', style: TextStyle(color: colors.textPrimary, fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Soyez le premier à lancer un live !', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateLivePage())),
            icon: Icon(Icons.add_rounded, color: colors.accent),
            label: Text('Créer un live', style: TextStyle(color: colors.accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  String _formatDuration(DateTime start, DateTime? end) {
    if (end == null) return 'En cours';
    final d = end.difference(start);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  String _formatAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 7) return DateFormat('dd/MM').format(date);
    if (diff.inDays >= 1) return 'il y a ${diff.inDays}j';
    if (diff.inHours >= 1) return 'il y a ${diff.inHours}h';
    if (diff.inMinutes >= 1) return 'il y a ${diff.inMinutes}m';
    return "à l'instant";
  }
}
