import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/authProvider.dart';
import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modèle léger pour une entrée du leaderboard
// ─────────────────────────────────────────────────────────────────────────────
class _LeaderEntry {
  final String userId;
  final String pseudo;
  final String? imageUrl;
  final int streak;

  const _LeaderEntry({
    required this.userId,
    required this.pseudo,
    this.imageUrl,
    required this.streak,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget compact — Top flammes de la semaine
// ─────────────────────────────────────────────────────────────────────────────
class FlameLeaderboard extends StatefulWidget {
  const FlameLeaderboard({super.key});

  @override
  State<FlameLeaderboard> createState() => _FlameLeaderboardState();
}

class _FlameLeaderboardState extends State<FlameLeaderboard> {
  List<_LeaderEntry> _entries = [];
  bool _loading = true;
  bool _expanded = false;
  int _myRank = -1;

  static const _rankMedals = ['🥇', '🥈', '🥉'];
  static const _milestones = {7: '🛡️', 30: '⭐', 100: '👑'};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Users')
          .where('commentStreak', isGreaterThan: 0)
          .orderBy('commentStreak', descending: true)
          .limit(10)
          .get();

      final entries = snap.docs.map((d) {
        final data = d.data();
        return _LeaderEntry(
          userId: d.id,
          pseudo: data['pseudo'] as String? ?? 'Utilisateur',
          imageUrl: data['imageUrl'] as String?,
          streak: (data['commentStreak'] as num?)?.toInt() ?? 0,
        );
      }).toList();

      if (!mounted) return;

      final myId = context.read<UserAuthProvider>().loginUserData.id;
      int myRank = -1;
      for (int i = 0; i < entries.length; i++) {
        if (entries[i].userId == myId) {
          myRank = i + 1;
          break;
        }
      }

      setState(() {
        _entries = entries;
        _myRank = myRank;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _milestone(int streak) {
    for (final entry in _milestones.entries.toList().reversed) {
      if (streak >= entry.key) return entry.value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (_loading) return _LeaderSkeleton();
    if (_entries.isEmpty) return const SizedBox.shrink();

    final visible = _expanded ? _entries : _entries.take(3).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
            child: Row(
              children: [
                const Text('🏆', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  'Top Flammes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Row(
                    children: [
                      Text(
                        _expanded ? 'Réduire' : 'Voir tout',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFFF6B35),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        size: 14,
                        color: const Color(0xFFFF6B35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: colors.border),

          // ── Lignes ──────────────────────────────────────────────────────────
          ...visible.asMap().entries.map((e) {
            final rank = e.key + 1;
            final entry = e.value;
            final myId = context.read<UserAuthProvider>().loginUserData.id;
            final isMe = entry.userId == myId;
            return _LeaderRow(
              rank: rank,
              entry: entry,
              medal: rank <= 3 ? _rankMedals[rank - 1] : null,
              milestone: _milestone(entry.streak),
              isMe: isMe,
            );
          }),

          // ── Mon rang si hors top ─────────────────────────────────────────────
          if (_myRank > (_expanded ? _entries.length : 3) && _myRank > 0) ...[
            Divider(height: 1, color: colors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '#$_myRank',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Ta position',
                    style: TextStyle(
                        fontSize: 11, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ligne du classement
// ─────────────────────────────────────────────────────────────────────────────
class _LeaderRow extends StatelessWidget {
  final int rank;
  final _LeaderEntry entry;
  final String? medal;
  final String? milestone;
  final bool isMe;

  const _LeaderRow({
    required this.rank,
    required this.entry,
    this.medal,
    this.milestone,
    required this.isMe,
  });

  Color _streakColor(int s) {
    if (s >= 30) return const Color(0xFFFFD700);
    if (s >= 14) return const Color(0xFFFF3A00);
    if (s >= 7) return const Color(0xFFFF6B35);
    return const Color(0xFFFF9500);
  }

  String _streakEmoji(int s) {
    if (s == 0) return '🧊';
    if (s < 3) return '🌊';
    if (s < 7) return '☀️';
    if (s < 14) return '🔥';
    if (s < 30) return '💥';
    return '⚡';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final color = _streakColor(entry.streak);

    return Container(
      color: isMe
          ? const Color(0xFFFF6B35).withOpacity(0.05)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          // Rang / médaille
          SizedBox(
            width: 26,
            child: Text(
              medal ?? '#$rank',
              style: TextStyle(
                fontSize: medal != null ? 14 : 11,
                fontWeight: FontWeight.w700,
                color: medal != null ? null : colors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),

          // Avatar
          CircleAvatar(
            radius: 14,
            backgroundColor: colors.surfaceVariant,
            backgroundImage: (entry.imageUrl?.isNotEmpty == true)
                ? NetworkImage(entry.imageUrl!)
                : null,
            child: (entry.imageUrl?.isEmpty ?? true)
                ? Icon(Icons.person, size: 14, color: colors.textSecondary)
                : null,
          ),
          const SizedBox(width: 8),

          // Pseudo
          Expanded(
            child: Text(
              '@${entry.pseudo}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
                color: isMe ? colors.textPrimary : colors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Milestone badge
          if (milestone != null) ...[
            Text(milestone!, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
          ],

          // Flamme + compteur
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.3), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_streakEmoji(entry.streak), style: const TextStyle(fontSize: 10)),
                const SizedBox(width: 2),
                Text(
                  '${entry.streak}j',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton pendant le chargement
// ─────────────────────────────────────────────────────────────────────────────
class _LeaderSkeleton extends StatelessWidget {
  const _LeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      height: 130,
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(colors.border),
          ),
        ),
      ),
    );
  }
}
