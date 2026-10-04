import 'package:afrotok/widgets/name_tag.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/model_data.dart';
import '../../pages/postDetails.dart';
import '../../pages/postDetailsVideo.dart';
import '../../providers/authProvider.dart';
import '../../services/weekly_rewards_service.dart';
import '../../theme/app_colors.dart';
import 'week_picker.dart';

class WeeklyTopPostsPage extends StatefulWidget {
  const WeeklyTopPostsPage({Key? key}) : super(key: key);

  @override
  State<WeeklyTopPostsPage> createState() => _WeeklyTopPostsPageState();
}

class _WeeklyTopPostsPageState extends State<WeeklyTopPostsPage> {
  static const _collection = 'WeeklyTopPosts';
  final _service = WeeklyRewardsService();
  List<WeeklyPostRanking> _rankings = [];
  List<String> _weeks = [];
  bool _loading = true;
  String? _error;
  String? _weekId; // null = détection de la dernière semaine disponible

  @override
  void initState() {
    super.initState();
    _loadLatest();
  }

  /// Dernière semaine ayant un classement (la semaine en cours n'en a pas encore).
  Future<void> _loadLatest() async {
    setState(() { _loading = true; _error = null; });
    try {
      _weeks = await _service.getAvailableWeekIds(_collection);
      if (_weeks.isEmpty) {
        if (mounted) setState(() { _rankings = []; _weekId = null; _loading = false; });
        return;
      }
      await _loadForWeek(_weekId != null && _weeks.contains(_weekId) ? _weekId! : _weeks.first);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _loadForWeek(String weekId) async {
    setState(() { _loading = true; _error = null; _weekId = weekId; });
    try {
      final data = await _service.getWeeklyTopPosts(weekId: weekId);
      if (mounted) setState(() { _rankings = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _pick() async {
    final w = await pickWeek(context, _weeks, _weekId);
    if (w != null && w != _weekId) _loadForWeek(w);
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
            Text('🏆 Top Posts de la semaine',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colors.textPrimary)),
            Text(_weekId != null ? WeeklyRewardsService.formatWeekLabel(_weekId!) : 'Chargement…',
                style: TextStyle(fontSize: 11, color: colors.textSecondary)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today_outlined, color: colors.primary, size: 20),
            tooltip: 'Changer de semaine',
            onPressed: _loading ? null : _pick,
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
      return Center(child: CircularProgressIndicator(color: colors.primary));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.textSecondary),
            const SizedBox(height: 12),
            Text('Erreur de chargement', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadLatest, child: Text('Réessayer', style: TextStyle(color: colors.primary))),
          ],
        ),
      );
    }
    if (_rankings.isEmpty) {
      return _buildEmptyState(colors);
    }

    return RefreshIndicator(
      color: colors.primary,
      onRefresh: () async { _service.clearCache(); await _loadLatest(); },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Score = vues uniques + commentaires uniques + personnes ayant aimé',
              style: TextStyle(fontSize: 11, color: colors.textSecondary, fontStyle: FontStyle.italic),
            ),
          ),
          ..._rankings.map((r) => _WeeklyPostCard(ranking: r)),
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
            Icon(Icons.emoji_events_outlined, size: 72, color: colors.textSecondary),
            const SizedBox(height: 16),
            Text('Pas encore de classement',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary)),
            const SizedBox(height: 8),
            Text('Le classement de la semaine est publié chaque lundi.\nPublie des posts et engage la communauté pour figurer ici !',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colors.textSecondary, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

// ─── Card post ────────────────────────────────────────────────────────────────

class _WeeklyPostCard extends StatelessWidget {
  final WeeklyPostRanking ranking;
  const _WeeklyPostCard({required this.ranking});

  Color _rankColor(int rank) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return Colors.grey.shade400;
  }

  String _rankEmoji(int rank) {
    if (rank == 1) return '🥇';
    if (rank == 2) return '🥈';
    if (rank == 3) return '🥉';
    return '#${ranking.rank}';
  }

  void _openPost(BuildContext context) {
    final post = ranking.post;
    if (post == null) return;
    final route = post.dataType == PostDataType.VIDEO.name
        ? MaterialPageRoute(builder: (_) => VideoYoutubePageDetails(initialPost: post))
        : MaterialPageRoute(builder: (_) => DetailsPost(post: post));
    Navigator.push(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final rank = ranking.rank;
    final rankColor = _rankColor(rank);
    final isRewarded = rank <= 3 && ranking.rewardedCoins > 0;

    final post = ranking.post;
    final author = ranking.author ?? post?.user;
    final String thumb = post?.thumbnail ?? post?.url_media ?? author?.imageUrl ?? '';
    final String title = post?.description ?? '';
    final String pseudo = author?.pseudo ?? ranking.authorId;

    return GestureDetector(
      onTap: () => _openPost(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: rank <= 3 ? rankColor.withOpacity(0.5) : colors.border),
          boxShadow: rank <= 3
              ? [BoxShadow(color: rankColor.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          children: [
            // Miniature
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: SizedBox(
                width: 90,
                height: 90,
                child: thumb.isNotEmpty
                    ? CachedNetworkImage(imageUrl: thumb, fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _placeholder(colors))
                    : _placeholder(colors),
              ),
            ),

            // Contenu
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rang + récompense
                    Row(
                      children: [
                        Text(_rankEmoji(rank), style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 6),
                        if (isRewarded)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: rankColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: rankColor.withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('🪙', style: TextStyle(fontSize: 10)),
                                const SizedBox(width: 3),
                                Text('${ranking.rewardedCoins}',
                                    style: TextStyle(color: rankColor, fontWeight: FontWeight.bold, fontSize: 11)),
                              ],
                            ),
                          ),
                        if (!isRewarded)
                          Text('#$rank',
                              style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Titre / description
                    if (title.isNotEmpty)
                      Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),

                    const SizedBox(height: 4),

                    // Auteur
                    NameTag(label: '@$pseudo',
                        style: TextStyle(color: colors.primary, fontSize: 11, fontWeight: FontWeight.w600)),

                    const SizedBox(height: 6),

                    // Stats
                    Row(
                      children: [
                        _StatChip(icon: Icons.visibility_outlined, value: ranking.uniqueViews, color: colors.textSecondary),
                        const SizedBox(width: 8),
                        _StatChip(icon: Icons.comment_outlined, value: ranking.uniqueComments, color: colors.textSecondary),
                        const SizedBox(width: 8),
                        _StatChip(icon: Icons.favorite_outline, value: ranking.uniqueLikes, color: Colors.pinkAccent),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: colors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('Score ${ranking.score}',
                              style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 10)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(AppColors colors) => Container(
        color: colors.surfaceVariant,
        child: Icon(Icons.image_outlined, color: colors.textSecondary, size: 32),
      );
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final int value;
  final Color color;
  const _StatChip({required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 2),
        Text(_fmt(value), style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}
