import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/model_data.dart';
import '../pages/component/showUserDetails.dart';
import '../providers/authProvider.dart';
import '../services/weekly_rewards_service.dart';
import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Niveaux (synchronisés avec flame_streak_banner.dart)
// ─────────────────────────────────────────────────────────────────────────────
const _kLevels = [
  (emoji: '👀', label: 'Observateur',     minDays: 0,  color: Color(0xFF8E8E93)),
  (emoji: '💬', label: 'Prise de Parole', minDays: 1,  color: Color(0xFF5B9CFA)),
  (emoji: '🗣️', label: 'Animateur',       minDays: 3,  color: Color(0xFFFF9500)),
  (emoji: '🔥', label: 'Influenceur',     minDays: 7,  color: Color(0xFFFF6B35)),
  (emoji: '⚡', label: 'Ambassadeur',     minDays: 14, color: Color(0xFFFF3B30)),
  (emoji: '👑', label: 'Icône des Comms', minDays: 30, color: Color(0xFFAF52DE)),
];

int    _level(int s) {
  for (int i = _kLevels.length - 1; i >= 0; i--) {
    if (s >= _kLevels[i].minDays) return i;
  }
  return 0;
}
String _emoji(int s) => _kLevels[_level(s)].emoji;
String _label(int s) => _kLevels[_level(s)].label;
Color  _color(int s) => _kLevels[_level(s)].color;

int _computeScore(int streak, int bestStreak) =>
    (streak * 10) + (bestStreak * 5);

// ─────────────────────────────────────────────────────────────────────────────
// Modèle
// ─────────────────────────────────────────────────────────────────────────────
class _LeaderEntry {
  final String userId;
  final String pseudo;
  final String? imageUrl;
  final int streak;
  final int score;

  const _LeaderEntry({
    required this.userId,
    required this.pseudo,
    this.imageUrl,
    required this.streak,
    required this.score,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget principal — Top 50 Commentateurs
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
  int _myScore = 0;

  List<WeeklyCommentatorRanking> _weeklyEntries = [];
  bool _weeklyLoading = true;

  static const _medals = ['🥇', '🥈', '🥉'];

  @override
  void initState() {
    super.initState();
    _load();
    _loadWeekly();
  }

  Future<void> _load() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Users')
          .where('bestCommentStreak', isGreaterThan: 0)
          .orderBy('bestCommentStreak', descending: true)
          .limit(100)
          .get();

      final entries = snap.docs.map((d) {
        final data = d.data();
        final streak = (data['commentStreak'] as num?)?.toInt() ?? 0;
        final best   = (data['bestCommentStreak'] as num?)?.toInt() ?? 0;
        return _LeaderEntry(
          userId:   d.id,
          pseudo:   data['pseudo'] as String? ?? 'Utilisateur',
          imageUrl: data['imageUrl'] as String?,
          streak:   streak,
          score:    _computeScore(streak, best),
        );
      }).toList()
        ..sort((a, b) => b.score.compareTo(a.score));

      final top50 = entries.take(50).toList();
      if (!mounted) return;

      final myId = context.read<UserAuthProvider>().loginUserData.id;
      int myRank = -1, myScore = 0;
      for (int i = 0; i < top50.length; i++) {
        if (top50[i].userId == myId) {
          myRank = i + 1;
          myScore = top50[i].score;
          break;
        }
      }

      setState(() {
        _entries = top50;
        _myRank  = myRank;
        _myScore = myScore;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadWeekly() async {
    try {
      final weekId = WeeklyRewardsService.getLastWeekId();
      final entries = await WeeklyRewardsService().getWeeklyTopCommentators(weekId: weekId);
      if (!mounted) return;
      setState(() {
        _weeklyEntries = entries.take(5).toList();
        _weeklyLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _weeklyLoading = false);
    }
  }

  Future<void> _openProfile(BuildContext ctx, String userId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();
      if (!snap.exists || !ctx.mounted) return;
      final user = UserData.fromJson(snap.data()!);
      final size = MediaQuery.of(ctx).size;
      showUserDetailsModalDialog(user, size.width, size.height, ctx);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    if (_loading) return const _LeaderSkeleton();
    if (_entries.isEmpty) return const SizedBox.shrink();

    final visible = _expanded ? _entries : _entries.take(5).toList();

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top hebdomadaire ──────────────────────────────────────────────
          if (_weeklyLoading)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Row(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Container(
                    width: 140,
                    height: 11,
                    decoration: BoxDecoration(
                      color: colors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            )
          else if (_weeklyEntries.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
              child: Row(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Top Commentateurs · Semaine passée',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        Text(
                          WeeklyRewardsService.getLastWeekId(),
                          style: TextStyle(fontSize: 9, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 88,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                primary: false,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                itemCount: _weeklyEntries.length,
                itemBuilder: (context, i) {
                  final entry = _weeklyEntries[i];
                  final rank = entry.rank;
                  final user = entry.user;
                  final imgUrl = user?.imageUrl ?? '';
                  final pseudo = user?.pseudo ?? entry.userId;
                  const medals = ['🥇', '🥈', '🥉'];
                  final rankLabel = rank <= 3 ? medals[rank - 1] : '#$rank';
                  final rankColor = rank == 1
                      ? const Color(0xFFFFD700)
                      : rank == 2
                          ? const Color(0xFFC0C0C0)
                          : rank == 3
                              ? const Color(0xFFCD7F32)
                              : colors.border;

                  return GestureDetector(
                    onTap: () => _openProfile(context, entry.userId),
                    child: Container(
                      width: 64,
                      margin: const EdgeInsets.only(right: 8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            alignment: Alignment.topRight,
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: colors.shimmerBase,
                                backgroundImage: imgUrl.isNotEmpty
                                    ? CachedNetworkImageProvider(imgUrl)
                                    : null,
                                child: imgUrl.isEmpty
                                    ? Icon(Icons.person, size: 22, color: colors.textSecondary)
                                    : null,
                              ),
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: rankColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: colors.surfaceVariant, width: 1.5),
                                ),
                                child: Text(rankLabel, style: const TextStyle(fontSize: 9)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '@$pseudo',
                            style: TextStyle(fontSize: 9, color: colors.textSecondary, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            '${entry.commentCount} 💬',
                            style: TextStyle(fontSize: 9, color: colors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Divider(color: colors.border, height: 1),
            ),
          ],

          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 8),
            child: Row(
              children: [
                const Text('💬', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Top Commentateurs',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        'Classés par points · Top 50',
                        style: TextStyle(
                          fontSize: 10,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _expanded ? 'Réduire' : 'Voir les 50',
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

          // ── Lignes ────────────────────────────────────────────────────────
          ...visible.asMap().entries.map((e) {
            final rank  = e.key + 1;
            final entry = e.value;
            final myId  = context.read<UserAuthProvider>().loginUserData.id;
            return _LeaderRow(
              rank:   rank,
              entry:  entry,
              medal:  rank <= 3 ? _medals[rank - 1] : null,
              isMe:   entry.userId == myId,
              onTap:  () => _openProfile(context, entry.userId),
            );
          }),

          // ── Mon rang hors top visible ─────────────────────────────────────
          if (_myRank > visible.length && _myRank > 0) ...[
            Divider(height: 1, color: colors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '#$_myRank',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ta position',
                      style: TextStyle(
                          fontSize: 11, color: colors.textSecondary),
                    ),
                  ),
                  _ScoreBadge(score: _myScore, color: const Color(0xFFFF6B35)),
                ],
              ),
            ),
          ],

          // ── Info récompenses hebdomadaires ────────────────────────────────
          Divider(height: 1, color: colors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🎁', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 6),
                    Text('Récompenses du lundi',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.textPrimary)),
                  ],
                ),
                const SizedBox(height: 6),
                _WeeklyRewardRow(rank: 1, coins: 500, label: '1er commentateur', color: const Color(0xFFFFD700)),
                _WeeklyRewardRow(rank: 2, coins: 300, label: '2e commentateur',  color: const Color(0xFFC0C0C0)),
                _WeeklyRewardRow(rank: 3, coins: 200, label: '3e commentateur',  color: const Color(0xFFCD7F32)),
                _WeeklyRewardRow(rank: 4, coins: 100, label: '4e commentateur',  color: colors.textSecondary),
                _WeeklyRewardRow(rank: 5, coins: 50,  label: '5e commentateur',  color: colors.textSecondary),
                const SizedBox(height: 6),
                Text(
                  '⚠️ Seuls les commentaires originaux (≥ 10 caractères, sur des posts différents) comptent. Les suggestions IA sont exclues.',
                  style: TextStyle(fontSize: 9, color: colors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ligne récompense hebdomadaire (dans leaderboard)
// ─────────────────────────────────────────────────────────────────────────────
class _WeeklyRewardRow extends StatelessWidget {
  final int rank;
  final int coins;
  final String label;
  final Color color;
  const _WeeklyRewardRow({required this.rank, required this.coins, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(['🥇','🥈','🥉','4️⃣','5️⃣'][rank-1], style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: TextStyle(fontSize: 11, color: color))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 10)),
                const SizedBox(width: 3),
                Text('$coins', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ligne du classement — responsive
// ─────────────────────────────────────────────────────────────────────────────
class _LeaderRow extends StatelessWidget {
  final int rank;
  final _LeaderEntry entry;
  final String? medal;
  final bool isMe;
  final VoidCallback onTap;

  const _LeaderRow({
    required this.rank,
    required this.entry,
    required this.isMe,
    required this.onTap,
    this.medal,
  });

  @override
  Widget build(BuildContext context) {
    final colors   = AppColors.of(context);
    final lvColor  = _color(entry.streak);
    final lvEmoji  = _emoji(entry.streak);
    final lvLabel  = _label(entry.streak);

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isMe
            ? const Color(0xFFFF6B35).withOpacity(0.05)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            // ── Rang / médaille (largeur fixe) ───────────────────────────
            SizedBox(
              width: 26,
              child: Text(
                medal ?? '#$rank',
                style: TextStyle(
                  fontSize: medal != null ? 15 : 11,
                  fontWeight: FontWeight.w700,
                  color: medal != null ? null : colors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),

            // ── Avatar (taille fixe) ─────────────────────────────────────
            CircleAvatar(
              radius: 16,
              backgroundColor: colors.shimmerBase,
              backgroundImage: (entry.imageUrl?.isNotEmpty == true)
                  ? CachedNetworkImageProvider(entry.imageUrl!)
                  : null,
              child: (entry.imageUrl?.isEmpty ?? true)
                  ? Icon(Icons.person, size: 14, color: colors.textSecondary)
                  : null,
            ),
            const SizedBox(width: 10),

            // ── Pseudo + niveau (flexible, prend l'espace dispo) ─────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '@${entry.pseudo}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isMe ? FontWeight.w800 : FontWeight.w600,
                      color: isMe
                          ? colors.textPrimary
                          : colors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(lvEmoji,
                          style: const TextStyle(fontSize: 10)),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          lvLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: lvColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '· ${entry.streak}j',
                        style: TextStyle(
                          fontSize: 10,
                          color: lvColor.withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // ── Score (se compresse sur petits écrans) ───────────────────
            _ScoreBadge(score: entry.score, color: lvColor),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Badge score — FittedBox pour s'adapter à n'importe quelle largeur
// ─────────────────────────────────────────────────────────────────────────────
class _ScoreBadge extends StatelessWidget {
  final int score;
  final Color color;

  const _ScoreBadge({required this.score, required this.color});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 80),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(
            '⭐ $score pts',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton chargement
// ─────────────────────────────────────────────────────────────────────────────
class _LeaderSkeleton extends StatelessWidget {
  const _LeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      height: 130,
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
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
