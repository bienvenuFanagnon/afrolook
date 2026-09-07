import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../services/weekly_rewards_service.dart';
import '../../theme/app_colors.dart';

const _pageSize = 20;

class WeeklyTopCommentatorsPage extends StatefulWidget {
  const WeeklyTopCommentatorsPage({Key? key}) : super(key: key);

  @override
  State<WeeklyTopCommentatorsPage> createState() => _WeeklyTopCommentatorsPageState();
}

class _WeeklyTopCommentatorsPageState extends State<WeeklyTopCommentatorsPage> {
  final _service = WeeklyRewardsService();
  final _scrollController = ScrollController();

  List<WeeklyCommentatorRanking> _allRankings = [];
  int _shownCount = _pageSize;
  bool _loading = true;
  String? _error;
  String? _weekId; // null = détection en cours

  @override
  void initState() {
    super.initState();
    _loadLatest();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Détecte la semaine la plus récente dans Firestore, puis charge les données.
  Future<void> _loadLatest() async {
    setState(() { _loading = true; _error = null; });
    try {
      final latestWeekId = await _service.getLatestCommentatorsWeekId();
      // Fallback : semaine précédente si aucune donnée
      final wid = latestWeekId ?? WeeklyRewardsService.getLastWeekId();
      await _loadForWeek(wid, resetShown: true);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadForWeek(String weekId, {bool resetShown = false}) async {
    setState(() { _loading = true; _error = null; _weekId = weekId; });
    try {
      final data = await _service.getWeeklyTopCommentators(weekId: weekId);
      if (mounted) {
        setState(() {
          _allRankings = data;
          if (resetShown) _shownCount = _pageSize;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  /// Convertit "2026-W34" en "Août 2026 — 3e semaine du mois"
  String _formatWeekId(String weekId) {
    try {
      final parts = weekId.split('-W');
      if (parts.length != 2) return weekId;
      final year = int.parse(parts[0]);
      final isoWeek = int.parse(parts[1]);

      final jan4 = DateTime.utc(year, 1, 4);
      final day1 = jan4.subtract(Duration(days: jan4.weekday - 1));
      final monday = day1.add(Duration(days: (isoWeek - 1) * 7));

      const months = ['', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
          'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];

      // ISO : la semaine appartient au mois du jeudi (point milieu de la semaine)
      final thursday = monday.add(const Duration(days: 3));
      final weekOfMonth = ((thursday.day - 1) ~/ 7) + 1;
      final ordinal = weekOfMonth == 1 ? '1re' : '${weekOfMonth}e';

      return '${months[thursday.month]} ${thursday.year} — $ordinal semaine du mois';
    } catch (_) {
      return weekId;
    }
  }

  void _pickWeek() {
    final options = [
      WeeklyRewardsService.getLastWeekId(),
      WeeklyRewardsService.getCurrentWeekId(),
    ];
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final colors = AppColors.of(ctx);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text('Choisir une semaine',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: colors.textPrimary)),
            const SizedBox(height: 8),
            ...options.map((w) => ListTile(
              title: Text(_formatWeekId(w), style: TextStyle(color: colors.textPrimary)),
              subtitle: Text(w, style: TextStyle(color: colors.textSecondary, fontSize: 11)),
              trailing: _weekId == w ? Icon(Icons.check, color: colors.primary) : null,
              onTap: () {
                Navigator.pop(ctx);
                _service.clearCache();
                _loadForWeek(w, resetShown: true);
              },
            )),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('💬 Top Commentateurs',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary)),
            Text(
              _weekId != null ? _formatWeekId(_weekId!) : 'Chargement…',
              style: TextStyle(fontSize: 11, color: colors.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today_outlined, color: colors.primary, size: 20),
            tooltip: 'Changer de semaine',
            onPressed: _loading ? null : _pickWeek,
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: colors.primary),
            onPressed: _loading ? null : () { _service.clearCache(); _loadLatest(); },
          ),
        ],
      ),
      body: _buildBody(colors),
    );
  }

  Widget _buildBody(AppColors colors) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF5B9CFA)));
    }
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, size: 48, color: colors.textSecondary),
          const SizedBox(height: 12),
          Text('Erreur de chargement',
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loadLatest,
            child: Text('Réessayer', style: TextStyle(color: colors.primary)),
          ),
        ]),
      );
    }
    if (_allRankings.isEmpty) {
      return _buildEmptyState(colors);
    }

    final visible = _allRankings.take(_shownCount).toList();
    final hasMore = _shownCount < _allRankings.length;

    return RefreshIndicator(
      color: const Color(0xFF5B9CFA),
      onRefresh: () async { _service.clearCache(); await _loadLatest(); },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 32),
        itemCount: visible.length + 2, // +1 header, +1 footer "Voir plus"
        itemBuilder: (context, index) {
          if (index == 0) return _buildHeader(colors);
          final i = index - 1;
          if (i < visible.length) return _CommentatorCard(ranking: visible[i]);
          // Footer
          if (!hasMore) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _shownCount += _pageSize),
              icon: const Icon(Icons.expand_more),
              label: Text(
                'Voir plus (${_allRankings.length - _shownCount} restants)',
                style: const TextStyle(fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF5B9CFA),
                side: const BorderSide(color: Color(0xFF5B9CFA)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(AppColors colors) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF5B9CFA).withOpacity(0.12), colors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF5B9CFA).withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('💬 Récompenses hebdomadaires',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: colors.textPrimary)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF5B9CFA).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_allRankings.length} participants',
                style: const TextStyle(color: Color(0xFF5B9CFA), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text('Chaque lundi, les 5 meilleurs commentateurs sont récompensés.',
              style: TextStyle(fontSize: 11, color: colors.textSecondary, height: 1.4)),
          const SizedBox(height: 12),
          _RewardRow(rank: 1, coins: 500, color: const Color(0xFFFFD700)),
          _RewardRow(rank: 2, coins: 300, color: const Color(0xFFC0C0C0)),
          _RewardRow(rank: 3, coins: 200, color: const Color(0xFFCD7F32)),
          _RewardRow(rank: 4, coins: 100, color: const Color(0xFF5B9CFA)),
          _RewardRow(rank: 5, coins: 50,  color: const Color(0xFF5B9CFA)),
          const SizedBox(height: 8),
          Text(
            'Score = nombre de posts distincts commentés dans la semaine',
            style: TextStyle(fontSize: 10, color: colors.textSecondary, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💬', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('Pas encore de classement',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'Le classement sera disponible lundi prochain.\nCommente des posts pour figurer ici !',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colors.textSecondary, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ligne récompense ─────────────────────────────────────────────────────────

class _RewardRow extends StatelessWidget {
  final int rank;
  final int coins;
  final Color color;
  const _RewardRow({required this.rank, required this.coins, required this.color});

  @override
  Widget build(BuildContext context) {
    final medals = {1: '🥇', 2: '🥈', 3: '🥉', 4: '4e', 5: '5e'};
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text(medals[rank] ?? '#$rank', style: const TextStyle(fontSize: 16))),
          const SizedBox(width: 8),
          Text('$rank${rank == 1 ? 'er' : 'e'} commentateur',
              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('🪙', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text('$coins pièces',
                  style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Card commentateur ─────────────────────────────────────────────────────────

class _CommentatorCard extends StatelessWidget {
  final WeeklyCommentatorRanking ranking;
  const _CommentatorCard({required this.ranking});

  Color _rankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    if (rank <= 5) return const Color(0xFF5B9CFA);
    return const Color(0xFF90A4AE);
  }

  String _rankLabel(int rank) {
    if (rank == 1) return '🥇';
    if (rank == 2) return '🥈';
    if (rank == 3) return '🥉';
    return '#$rank';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final rank = ranking.rank;
    final rankColor = _rankColor(rank);
    final user = ranking.user;
    final imgUrl = user?.imageUrl ?? '';
    final pseudo = user?.pseudo ?? '…';
    final isPaid = ranking.paid && ranking.rewardedCoins > 0;
    final isRewarded = rank <= 5;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: rank <= 3 ? rankColor.withOpacity(0.4) : colors.border,
          width: rank <= 3 ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Badge rang
          SizedBox(
            width: 40,
            child: Text(
              _rankLabel(rank),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: rank <= 3 ? 20 : 13,
                fontWeight: FontWeight.bold,
                color: rankColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Avatar
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: rankColor, width: rank <= 3 ? 2 : 1),
            ),
            child: ClipOval(
              child: imgUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imgUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: colors.shimmerBase),
                      errorWidget: (_, __, ___) => _avatarFallback(colors),
                    )
                  : _avatarFallback(colors),
            ),
          ),
          const SizedBox(width: 10),
          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('@$pseudo',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: colors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(children: [
                  const Text('💬', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 3),
                  Text(
                    '${ranking.commentCount} post${ranking.commentCount > 1 ? 's' : ''} commenté${ranking.commentCount > 1 ? 's' : ''}',
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Récompense ou position non récompensée
          if (isPaid)
            _RewardBadge(coins: ranking.rewardedCoins, color: const Color(0xFFFFD700))
          else if (isRewarded)
            _RewardBadge(coins: [500, 300, 200, 100, 50][rank - 1], color: rankColor, pending: true)
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colors.border.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${ranking.commentCount} 💬',
                style: TextStyle(fontSize: 11, color: colors.textSecondary, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _avatarFallback(AppColors colors) => Container(
    color: colors.shimmerBase,
    child: Icon(Icons.person, color: colors.textSecondary, size: 22),
  );
}

class _RewardBadge extends StatelessWidget {
  final int coins;
  final Color color;
  final bool pending;
  const _RewardBadge({required this.coins, required this.color, this.pending = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(pending ? 0.06 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(pending ? 0.25 : 0.5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('🪙', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 3),
        Text(
          '+$coins',
          style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: color,
            decoration: pending ? TextDecoration.none : null,
          ),
        ),
        if (pending) ...[
          const SizedBox(width: 3),
          Icon(Icons.schedule, size: 10, color: color.withOpacity(0.6)),
        ],
      ]),
    );
  }
}
