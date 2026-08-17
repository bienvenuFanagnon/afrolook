import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../models/model_data.dart';
import '../../../pages/postDetails.dart';
import '../../../pages/postDetailsVideo.dart';
import '../../../pages/weekly_top/weekly_top_posts_page.dart';
import '../../../services/weekly_rewards_service.dart';
import '../../../theme/app_colors.dart';

/// Affiché uniquement le lundi et le mardi dans le feed.
/// Montre le top 5 posts de la semaine avec un bouton vers la page complète.
class WeeklyTopPostsSectionWidget extends StatefulWidget {
  const WeeklyTopPostsSectionWidget({Key? key}) : super(key: key);

  static bool get shouldShow {
    final day = DateTime.now().weekday; // 1 = lundi, 2 = mardi
    return day == 1 || day == 2;
  }

  // ── Cache statique partagé entre instances ──────────────────────────────────
  static Future<List<WeeklyPostRanking>>? _sharedFuture;
  static String _sharedWeekId = '';

  static Future<List<WeeklyPostRanking>> preload() {
    final weekId = WeeklyRewardsService.getLastWeekId();
    if (_sharedWeekId != weekId || _sharedFuture == null) {
      _sharedWeekId = weekId;
      _sharedFuture = WeeklyRewardsService().getWeeklyTopPosts(weekId: weekId);
    }
    return _sharedFuture!;
  }

  @override
  State<WeeklyTopPostsSectionWidget> createState() =>
      _WeeklyTopPostsSectionWidgetState();
}

class _WeeklyTopPostsSectionWidgetState
    extends State<WeeklyTopPostsSectionWidget> {
  late Future<List<WeeklyPostRanking>> _future;

  @override
  void initState() {
    super.initState();
    _future = WeeklyTopPostsSectionWidget.preload();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return FutureBuilder<List<WeeklyPostRanking>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _buildSkeleton(colors);
        }
        final rankings = snap.data ?? [];
        if (rankings.isEmpty) return const SizedBox.shrink();

        final top5 = rankings.take(5).toList();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: const Color(0xFFFFD700).withOpacity(0.35)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withOpacity(0.08),
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
                    const Text('🏆', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Top Posts de la semaine passée',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: colors.textPrimary)),
                          Text(
                            'Classement · ${WeeklyRewardsService.getLastWeekId()}',
                            style: TextStyle(
                                fontSize: 10, color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const WeeklyTopPostsPage())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFFFD700).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: const Color(0xFFFFD700)
                                  .withOpacity(0.5)),
                        ),
                        child: Text('Voir tout',
                            style: TextStyle(
                                fontSize: 11,
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Liste horizontale mini-cards ─────────────────────────────
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  primary: false,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  itemCount: top5.length,
                  itemBuilder: (context, i) =>
                      _MiniPostCard(ranking: top5[i]),
                ),
              ),

              // ── Bouton bas ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const WeeklyTopPostsPage())),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text(
                        '🏅 Voir le top 20 de la semaine passée',
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSkeleton(AppColors colors) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      height: 180,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Center(
          child: CircularProgressIndicator(
              color: colors.primary, strokeWidth: 2)),
    );
  }
}

// ─── Mini-card horizontale ────────────────────────────────────────────────────

class _MiniPostCard extends StatelessWidget {
  final WeeklyPostRanking ranking;
  const _MiniPostCard({required this.ranking});

  Color _rankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return Colors.grey.shade400;
  }

  String _rankLabel(int rank) {
    if (rank == 1) return '🥇';
    if (rank == 2) return '🥈';
    if (rank == 3) return '🥉';
    return '#$rank';
  }

  void _openPost(BuildContext context) {
    final post = ranking.post;
    if (post == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => post.dataType == PostDataType.VIDEO.name
            ? VideoYoutubePageDetails(initialPost: post)
            : DetailsPost(post: post),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final rankColor = _rankColor(ranking.rank);
    final post = ranking.post;
    final thumb =
        post?.thumbnail ?? post?.url_media ?? ranking.author?.imageUrl ?? '';
    final pseudo = ranking.author?.pseudo ?? ranking.authorId;

    return GestureDetector(
      onTap: () => _openPost(context),
      child: Container(
        width: 88,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: rankColor.withOpacity(0.5)),
        ),
        child: Stack(
          children: [
            // Miniature
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: thumb.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: thumb,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Icon(
                            Icons.image_outlined,
                            color: colors.textSecondary))
                    : Icon(Icons.image_outlined,
                        color: colors.textSecondary),
              ),
            ),
            // Overlay dégradé
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.75)
                    ],
                  ),
                ),
              ),
            ),
            // Badge rang
            Positioned(
              top: 5,
              left: 5,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                    color: rankColor, shape: BoxShape.circle),
                child: Text(_rankLabel(ranking.rank),
                    style: const TextStyle(fontSize: 10)),
              ),
            ),
            // Score
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${ranking.score}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            // Pseudo
            Positioned(
              bottom: 5,
              left: 5,
              right: 5,
              child: Text('@$pseudo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
