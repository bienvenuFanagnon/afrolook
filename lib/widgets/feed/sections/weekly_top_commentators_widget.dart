import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../pages/weekly_top/weekly_top_commentators_page.dart';
import '../../../providers/authProvider.dart';
import '../../../providers/streakProvider.dart';
import '../../../services/weekly_rewards_service.dart';
import '../../../theme/app_colors.dart';
import '../../flame_streak_banner.dart';

/// Affiché du lundi au mercredi dans le feed.
/// Montre le top 5 commentateurs de la semaine précédente avec leurs récompenses.
class WeeklyTopCommentatorsWidget extends StatefulWidget {
  const WeeklyTopCommentatorsWidget({Key? key}) : super(key: key);

  /// Affiché du lundi au dimanche : les résultats sont publiés chaque lundi
  /// et restent valables toute la semaine.
  static bool get shouldShow => true;

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

    // Le container et la section "Mon niveau" sont toujours affichés.
    // Seul le classement (carousel + barème) dépend des données.
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF5B9CFA).withOpacity(0.35)),
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
          // ── En-tête ────────────────────────────────────────────────────
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
                GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(
                          builder: (_) => const WeeklyTopCommentatorsPage())),
                  child: Text('Tout voir',
                      style: TextStyle(
                          fontSize: 11,
                          color: const Color(0xFF5B9CFA),
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          // ── Classement (conditionnel) ───────────────────────────────────
          FutureBuilder<List<WeeklyCommentatorRanking>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return _buildRankingSkeleton(colors);
              }
              final rankings = (snap.data ?? []).take(5).toList();
              if (rankings.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: Text(
                    'Aucun classement disponible cette semaine.',
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Barème récompenses
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
                  // Carrousel horizontal
                  SizedBox(
                    height: 108,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      primary: false,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      itemCount: rankings.length,
                      itemBuilder: (context, i) =>
                          _CommentatorCard(ranking: rankings[i]),
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Mon niveau — toujours visible, tap → modal flamme ──────────
          Consumer2<UserAuthProvider, StreakProvider>(
            builder: (ctx, auth, streakProv, _) {
              final me = auth.loginUserData;
              final streak = me.commentStreak;
              final lvl = commentLevelForStreak(streak);
              return GestureDetector(
                onTap: () => showCommentStreakModal(ctx, streakProv),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: lvl.color.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: lvl.color.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: (me.imageUrl?.isNotEmpty == true)
                            ? CachedNetworkImageProvider(me.imageUrl!)
                            : null,
                        backgroundColor: colors.shimmerBase,
                        child: (me.imageUrl?.isEmpty ?? true)
                            ? Icon(Icons.person,
                                size: 14, color: colors.textSecondary)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      // Niveau + pseudo
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(lvl.emoji,
                                  style: const TextStyle(fontSize: 13)),
                              const SizedBox(width: 4),
                              Text(
                                lvl.label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: lvl.color,
                                ),
                              ),
                            ]),
                            Text(
                              'Mon niveau · Appuie pour voir les détails',
                              style: TextStyle(
                                  fontSize: 9, color: colors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // Badge streak
                      if (streak > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: lvl.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: lvl.color.withOpacity(0.4)),
                          ),
                          child: Text(
                            '🔥 $streak j',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: lvl.color),
                          ),
                        ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right,
                          size: 16, color: colors.textSecondary),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
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

  Widget _buildRankingSkeleton(AppColors colors) {
    return Container(
      height: 100,
      alignment: Alignment.center,
      child: CircularProgressIndicator(color: colors.info, strokeWidth: 2),
    );
  }
}

// ─── Mini-carte commentateur (carrousel feed) ─────────────────────────────────

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

  void _showDetailModal(BuildContext context) {
    final colors = AppColors.of(context);
    final user = ranking.user;
    final imgUrl = user?.imageUrl ?? '';
    final pseudo = user?.pseudo ?? '…';
    final rankColor = _rankColor(ranking.rank);
    final rankLabel = _rankLabel(ranking.rank);
    final streak = user?.commentStreak ?? 0;
    final level = commentLevelForStreak(streak);

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Poignée
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Avatar + badge rang
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: colors.shimmerBase,
                    backgroundImage: imgUrl.isNotEmpty
                        ? CachedNetworkImageProvider(imgUrl)
                        : null,
                    child: imgUrl.isEmpty
                        ? Icon(Icons.person, size: 36,
                            color: colors.textSecondary)
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: rankColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.surface, width: 2),
                    ),
                    child: Text(rankLabel,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Pseudo
              Text('@$pseudo',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary)),
              const SizedBox(height: 4),
              // Niveau
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: level.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: level.color.withOpacity(0.4)),
                ),
                child: Text('${level.emoji} ${level.label}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: level.color)),
              ),
              const SizedBox(height: 16),
              // Stats
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statTile('💬', '${ranking.commentCount}', 'posts commentés'),
                  if (streak > 0)
                    _statTile('🔥', '$streak', 'jours de série'),
                  if (ranking.rewardedCoins > 0)
                    _statTile('🪙', '+${ranking.rewardedCoins}',
                        ranking.paid ? 'reçus' : 'en attente'),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _statTile(String icon, String value, String label) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final user = ranking.user;
    final imgUrl = user?.imageUrl ?? '';
    final pseudo = user?.pseudo ?? '…';
    final rankColor = _rankColor(ranking.rank);
    final rankLabel = _rankLabel(ranking.rank);

    return GestureDetector(
      onTap: () => _showDetailModal(context),
      child: Container(
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
                      ? Icon(Icons.person, size: 24,
                          color: colors.textSecondary)
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
              style: TextStyle(fontSize: 9, color: colors.textSecondary),
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
      ),
    );
  }
}
