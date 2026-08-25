import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../services/weekly_rewards_service.dart';
import '../../../theme/app_colors.dart';

/// Affiché du lundi au mercredi dans le feed.
/// Montre le top 5 commentateurs de la semaine précédente avec leurs récompenses.
class WeeklyTopCommentatorsWidget extends StatefulWidget {
  const WeeklyTopCommentatorsWidget({Key? key}) : super(key: key);

  static bool get shouldShow {
    final day = DateTime.now().weekday; // 1=lun, 2=mar, 3=mer
    return day >= 1 && day <= 3;
  }

  // ── Cache statique partagé entre instances ─────────────────────────────────
  static Future<List<WeeklyCommentatorRanking>>? _sharedFuture;
  static String _sharedWeekId = '';

  static Future<List<WeeklyCommentatorRanking>> preload() {
    final weekId = WeeklyRewardsService.getLastWeekId();
    if (_sharedWeekId != weekId || _sharedFuture == null) {
      _sharedWeekId = weekId;
      _sharedFuture =
          WeeklyRewardsService().getWeeklyTopCommentators(weekId: weekId);
    }
    return _sharedFuture!;
  }

  @override
  State<WeeklyTopCommentatorsWidget> createState() =>
      _WeeklyTopCommentatorsWidgetState();
}

class _WeeklyTopCommentatorsWidgetState
    extends State<WeeklyTopCommentatorsWidget> {
  late Future<List<WeeklyCommentatorRanking>> _future;

  @override
  void initState() {
    super.initState();
    _future = WeeklyTopCommentatorsWidget.preload();
  }

  @override
  Widget build(BuildContext context) {
    if (!WeeklyTopCommentatorsWidget.shouldShow) return const SizedBox.shrink();
    final colors = AppColors.of(context);

    return FutureBuilder<List<WeeklyCommentatorRanking>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _buildSkeleton(colors);
        }
        final rankings = (snap.data ?? []).take(5).toList();
        if (rankings.isEmpty) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: const Color(0xFF5B9CFA).withOpacity(0.35)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF5B9CFA).withOpacity(0.07),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── En-tête ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 6),
                child: Row(
                  children: [
                    const Text('💬', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Top Commentateurs de la semaine',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary),
                          ),
                          Text(
                            'Classement · ${WeeklyRewardsService.getLastWeekId()}',
                            style: TextStyle(
                                fontSize: 10, color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Barème récompenses ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Row(
                  children: [
                    _rewardChip('🥇', '500'),
                    const SizedBox(width: 6),
                    _rewardChip('🥈', '300'),
                    const SizedBox(width: 6),
                    _rewardChip('🥉', '200'),
                    const SizedBox(width: 6),
                    _rewardChip('4e', '100'),
                    const SizedBox(width: 6),
                    _rewardChip('5e', '50'),
                  ],
                ),
              ),

              // ── Carrousel horizontal ──────────────────────────────────────
              SizedBox(
                height: 108,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  primary: false,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  itemCount: rankings.length,
                  itemBuilder: (context, i) =>
                      _CommentatorCard(ranking: rankings[i]),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _rewardChip(String label, String coins) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF5B9CFA).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: const Color(0xFF5B9CFA).withOpacity(0.3)),
      ),
      child: Text(
        '$label·${coins}🪙',
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
            color: Color(0xFF5B9CFA)),
      ),
    );
  }

  Widget _buildSkeleton(AppColors colors) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      height: 160,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Center(
          child: CircularProgressIndicator(
              color: colors.info, strokeWidth: 2)),
    );
  }
}

// ─── Mini-carte commentateur ──────────────────────────────────────────────────

class _CommentatorCard extends StatelessWidget {
  final WeeklyCommentatorRanking ranking;
  const _CommentatorCard({required this.ranking});

  Color _rankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return const Color(0xFF5B9CFA);
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
    final user = ranking.user;
    final imgUrl = user?.imageUrl ?? '';
    final pseudo = user?.pseudo ?? '…';
    final rankColor = _rankColor(ranking.rank);
    final rankLabel = _rankLabel(ranking.rank);

    return Container(
      width: 76,
      margin: const EdgeInsets.only(right: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar + badge rang
          Stack(
            alignment: Alignment.topRight,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: colors.shimmerBase,
                backgroundImage: imgUrl.isNotEmpty
                    ? CachedNetworkImageProvider(imgUrl)
                    : null,
                child: imgUrl.isEmpty
                    ? Icon(Icons.person, size: 24, color: colors.textSecondary)
                    : null,
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: rankColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.surface, width: 1.5),
                ),
                child: Text(rankLabel,
                    style: const TextStyle(fontSize: 9, height: 1)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Pseudo
          Text(
            '@$pseudo',
            style: TextStyle(
                fontSize: 9,
                color: colors.textPrimary,
                fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          // Nombre de commentaires
          Text(
            '${ranking.commentCount} 💬',
            style:
                TextStyle(fontSize: 9, color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
          // Récompense (si payé)
          if (ranking.paid && ranking.rewardedCoins > 0)
            Text(
              '+${ranking.rewardedCoins}🪙',
              style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFFFFD700),
                  fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
        ],
      ),
    );
  }
}
