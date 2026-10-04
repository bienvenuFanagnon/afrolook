import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../pages/canaux/detailsCanal.dart' show CanalDetails;
import '../../pages/component/showUserDetails.dart';
import '../../services/weekly_rewards_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/count_format.dart';
import 'week_picker.dart';

/// Top créateurs (utilisateurs et canaux) d'une semaine passée, au choix. Sans récompense.
class WeeklyTopCreatorsPage extends StatefulWidget {
  const WeeklyTopCreatorsPage({Key? key}) : super(key: key);

  @override
  State<WeeklyTopCreatorsPage> createState() => _WeeklyTopCreatorsPageState();
}

class _WeeklyTopCreatorsPageState extends State<WeeklyTopCreatorsPage> {
  static const _collection = 'WeeklyTopCreators';
  final _service = WeeklyRewardsService();
  List<WeeklyCreatorRanking> _rankings = [];
  List<String> _weeks = [];
  bool _loading = true;
  String? _error;
  String? _weekId;

  @override
  void initState() {
    super.initState();
    _loadLatest();
  }

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
      final data = await _service.getWeeklyTopCreators(weekId: weekId);
      if (mounted) setState(() { _rankings = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _pick() async {
    final w = await pickWeek(context, _weeks, _weekId);
    if (w != null && w != _weekId) _loadForWeek(w);
  }

  void _open(WeeklyCreatorRanking r) {
    final size = MediaQuery.of(context).size;
    if (r.isCanal && r.canal != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => CanalDetails(canal: r.canal!)));
    } else if (r.user != null) {
      showUserDetailsModalDialog(r.user!, size.width, size.height, context);
    }
  }

  Color _rankColor(int rank, AppColors colors) {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return colors.textSecondary;
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
            Text('🏆 Top Créateurs',
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
      body: _body(colors),
    );
  }

  Widget _body(AppColors colors) {
    if (_loading) return Center(child: CircularProgressIndicator(color: colors.primary));
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, size: 48, color: colors.textSecondary),
          const SizedBox(height: 12),
          Text('Erreur de chargement', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
          TextButton(onPressed: _loadLatest, child: Text('Réessayer', style: TextStyle(color: colors.primary))),
        ]),
      );
    }
    if (_rankings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.emoji_events_outlined, size: 72, color: colors.textSecondary),
            const SizedBox(height: 16),
            Text('Pas encore de classement',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colors.textPrimary)),
            const SizedBox(height: 8),
            Text('Le classement de la semaine est publié chaque lundi.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colors.textSecondary, height: 1.5)),
          ]),
        ),
      );
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
              'Score = publications, personnes ayant aimé, commentateurs et vues de la semaine.',
              style: TextStyle(fontSize: 11, color: colors.textSecondary, fontStyle: FontStyle.italic),
            ),
          ),
          ..._rankings.map((r) => _card(r, colors)),
        ],
      ),
    );
  }

  Widget _card(WeeklyCreatorRanking r, AppColors colors) {
    final rc = _rankColor(r.rank, colors);
    final medal = r.rank == 1 ? '🥇' : r.rank == 2 ? '🥈' : r.rank == 3 ? '🥉' : '#${r.rank}';
    final name = r.displayName.isNotEmpty ? r.displayName : '—';
    return GestureDetector(
      onTap: () => _open(r),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: r.rank <= 3 ? rc.withOpacity(0.5) : colors.border),
        ),
        child: Row(children: [
          SizedBox(width: 38, child: Text(medal, textAlign: TextAlign.center, style: TextStyle(fontSize: r.rank <= 3 ? 22 : 15, fontWeight: FontWeight.bold, color: rc))),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 24,
            backgroundColor: colors.surfaceVariant,
            backgroundImage: r.imageUrl.isNotEmpty ? CachedNetworkImageProvider(r.imageUrl) : null,
            child: r.imageUrl.isEmpty ? Icon(r.isCanal ? Icons.campaign : Icons.person, color: colors.textSecondary) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(r.isCanal ? '#$name' : '@$name',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                ),
                if (r.isCanal) ...[
                  const SizedBox(width: 6),
                  Text('Canal', style: TextStyle(color: colors.textSecondary, fontSize: 10)),
                ],
              ]),
              const SizedBox(height: 4),
              Text(
                '${r.postCount} post${r.postCount > 1 ? 's' : ''} · ❤ ${formatCompactCount(r.uniqueLovers)} · 💬 ${formatCompactCount(r.uniqueCommenters)} · 👁 ${formatCompactCount(r.totalViews)}',
                style: TextStyle(color: colors.textSecondary, fontSize: 11),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(r.score.toStringAsFixed(r.score >= 100 ? 0 : 1),
                style: TextStyle(color: rc, fontWeight: FontWeight.bold, fontSize: 16)),
            Text('pts', style: TextStyle(color: colors.textSecondary, fontSize: 10)),
          ]),
        ]),
      ),
    );
  }
}
