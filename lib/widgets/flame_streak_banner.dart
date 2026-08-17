import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/streakProvider.dart';
import '../providers/authProvider.dart';
import '../services/weekly_rewards_service.dart';
import '../theme/app_colors.dart';
import 'flame_leaderboard.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Niveaux — progression récompensante liée aux commentaires
// ─────────────────────────────────────────────────────────────────────────────
const _kLevels = [
  (emoji: '👀', label: 'Observateur',     range: '0j',     color: Color(0xFF8E8E93)),
  (emoji: '💬', label: 'Prise de Parole', range: '1-2j',   color: Color(0xFF5B9CFA)),
  (emoji: '🗣️', label: 'Animateur',       range: '3-6j',   color: Color(0xFFFF9500)),
  (emoji: '🔥', label: 'Influenceur',     range: '7-13j',  color: Color(0xFFFF6B35)),
  (emoji: '⚡', label: 'Ambassadeur',     range: '14-29j', color: Color(0xFFFF3B30)),
  (emoji: '👑', label: 'Icône des Comms', range: '30+j',   color: Color(0xFFAF52DE)),
];

String _levelEmoji(int level) => _kLevels[level.clamp(0, 5)].emoji;
String _levelLabel(int level) => _kLevels[level.clamp(0, 5)].label;
Color  _levelColor(int level) => _kLevels[level.clamp(0, 5)].color;

int _levelFromStreak(int streak) {
  if (streak >= 30) return 5;
  if (streak >= 14) return 4;
  if (streak >= 7)  return 3;
  if (streak >= 3)  return 2;
  if (streak >= 1)  return 1;
  return 0;
}

int _computeScore(int streak, int bestStreak) =>
    (streak * 10) + (bestStreak * 5);

// Modèle léger pour les avatars de la bannière
class _BannerUser {
  final String id;
  final String pseudo;
  final String? imageUrl;
  final int commentCount;
  _BannerUser({required this.id, required this.pseudo, this.imageUrl, required this.commentCount});
}

// ─────────────────────────────────────────────────────────────────────────────
// Bannière — affichée dans les pages de posts
// ─────────────────────────────────────────────────────────────────────────────
class FlameStreakBanner extends StatefulWidget {
  const FlameStreakBanner({super.key});

  @override
  State<FlameStreakBanner> createState() => _FlameStreakBannerState();
}

class _FlameStreakBannerState extends State<FlameStreakBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  List<_BannerUser> _topUsers = [];
  bool _topUsersIsFallback = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<UserAuthProvider>().loginUserData.id;
      if (uid != null && uid.isNotEmpty) {
        context.read<StreakProvider>().listenToUser(uid);
      }
      _loadTopUsers();
    });
  }

  Future<void> _loadTopUsers() async {
    try {
      final weekId = WeeklyRewardsService.getLastWeekId();
      final rankings = await WeeklyRewardsService().getWeeklyTopCommentators(weekId: weekId);
      if (!mounted) return;
      final users = rankings.take(5).map((r) => _BannerUser(
        id: r.userId,
        pseudo: r.user?.pseudo ?? r.userId,
        imageUrl: r.user?.imageUrl,
        commentCount: r.commentCount,
      )).toList();
      if (users.isNotEmpty) {
        setState(() => _topUsers = users);
      } else {
        await _loadTopUsersFallback();
      }
    } catch (_) {
      await _loadTopUsersFallback();
    }
  }

  // Fallback : top 5 par meilleure série all-time si aucune donnée hebdo disponible
  Future<void> _loadTopUsersFallback() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Users')
          .where('bestCommentStreak', isGreaterThan: 0)
          .orderBy('bestCommentStreak', descending: true)
          .limit(5)
          .get();
      if (!mounted) return;
      setState(() {
        _topUsers = snap.docs.map((d) {
          final data = d.data();
          return _BannerUser(
            id: d.id,
            pseudo: data['pseudo'] as String? ?? '',
            imageUrl: data['imageUrl'] as String?,
            commentCount: (data['bestCommentStreak'] as num?)?.toInt() ?? 0,
          );
        }).toList();
        _topUsersIsFallback = true;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StreakProvider>(
      builder: (ctx, streak, _) {
        final colors = AppColors.of(ctx);
        final bool cold = streak.commentStreak == 0 && streak.todayCount == 0;
        final bool done = streak.quotaReachedToday;
        final bool urgent =
            !done && !cold && streak.commentStreak > 0 && streak.todayCount < 3;

        final Color accent = done
            ? const Color(0xFF34C759)
            : urgent
                ? const Color(0xFFFF6B35)
                : cold
                    ? const Color(0xFF5B9CFA)
                    : const Color(0xFFFF9500);

        final String statusText = done
            ? '🎉 Série du jour validée !'
            : urgent
                ? '${streak.remainingToday} commentaire${streak.remainingToday > 1 ? 's' : ''} encore pour sauver ta série'
                : cold
                    ? 'Commence ta série de commentaires maintenant'
                    : '${streak.remainingToday} commentaire${streak.remainingToday > 1 ? 's' : ''} pour valider la journée';

        return GestureDetector(
          onTap: () => _openModal(ctx, streak),
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 6, 10, 6),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withOpacity(0.25), width: 1),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.07),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Barre supérieure colorée ──────────────────────────────
                  Container(height: 3, color: accent),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── En-tête : titre + badge série ─────────────────
                        Row(
                          children: [
                            AnimatedBuilder(
                              animation: _pulseCtrl,
                              builder: (_, __) => Transform.scale(
                                scale: urgent
                                    ? 1.0 + 0.15 * _pulseCtrl.value
                                    : 1.0,
                                child: Text(
                                  _levelEmoji(streak.level),
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Série Commentaires',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: colors.textPrimary,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _levelLabel(streak.level),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _levelColor(streak.level),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Badge jours de série
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(20),
                                border:
                                    Border.all(color: accent.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    streak.commentStreak > 0
                                        ? '${streak.commentStreak}'
                                        : '0',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: accent,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'j',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // ── Progression du jour ──────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  ...List.generate(3, (i) {
                                    final filled = i < streak.todayCount;
                                    return Expanded(
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(right: 6),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                              milliseconds: 300),
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: filled
                                                ? accent
                                                : colors.border,
                                            borderRadius:
                                                BorderRadius.circular(3),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${streak.todayCount}/3',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: accent,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      statusText,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: done || urgent
                                            ? accent
                                            : colors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  if (streak.shields > 0)
                                    Container(
                                      margin:
                                          const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: colors.surface,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        border: Border.all(
                                            color: colors.border, width: 1),
                                      ),
                                      child: Text(
                                        '🛡️ ${streak.shields}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ── Niveaux horizontaux ──────────────────────────────
                        LayoutBuilder(builder: (_, constraints) {
                          final available = constraints.maxWidth - 80.0;
                          final chipW = available / _kLevels.length;
                          final showLabel = chipW >= 44;

                          return Row(
                            children: [
                              ...List.generate(_kLevels.length, (i) {
                                final lv = _kLevels[i];
                                final isActive = i == streak.level;
                                final isPast = i < streak.level;
                                final opacity =
                                    (isActive || isPast) ? 1.0 : 0.28;
                                return Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                        right: i < _kLevels.length - 1
                                            ? 4
                                            : 0),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: isActive ? 5 : 3),
                                      decoration: isActive
                                          ? BoxDecoration(
                                              color: lv.color
                                                  .withOpacity(0.14),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                  color: lv.color
                                                      .withOpacity(0.5)),
                                            )
                                          : null,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(lv.emoji,
                                                style: TextStyle(
                                                    fontSize:
                                                        isActive ? 16 : 14,
                                                    color: Colors.white
                                                        .withOpacity(
                                                            opacity))),
                                            if (showLabel) ...[
                                              const SizedBox(width: 3),
                                              Text(
                                                lv.label,
                                                style: TextStyle(
                                                  fontSize: isActive
                                                      ? 13
                                                      : 11,
                                                  fontWeight: isActive
                                                      ? FontWeight.w800
                                                      : FontWeight.w500,
                                                  color: lv.color
                                                      .withOpacity(opacity),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              const SizedBox(width: 8),
                              Row(
                                children: [
                                  Text(
                                    'Mon score',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: accent,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward_ios,
                                      size: 10, color: accent),
                                ],
                              ),
                            ],
                          );
                        }),

                        // ── Top 5 Commentateurs ────────────────────────────
                        if (_topUsers.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Divider(height: 1, color: colors.border),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Text('💬', style: TextStyle(fontSize: 11)),
                              const SizedBox(width: 6),
                              Text(
                                _topUsersIsFallback ? 'Top séries 💬 (all-time)' : 'Top commentateurs · semaine passée',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: _topUsers.asMap().entries.map((e) {
                              final i = e.key;
                              final user = e.value;
                              const medals = ['🥇', '🥈', '🥉', '4️⃣', '5️⃣'];
                              return Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Stack(
                                      alignment: Alignment.topRight,
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: colors.shimmerBase,
                                          backgroundImage: (user.imageUrl?.isNotEmpty == true)
                                              ? CachedNetworkImageProvider(user.imageUrl!)
                                              : null,
                                          child: (user.imageUrl?.isEmpty ?? true)
                                              ? Icon(Icons.person, size: 16, color: colors.textSecondary)
                                              : null,
                                        ),
                                        Text(medals[i], style: const TextStyle(fontSize: 9)),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '@${user.pseudo}',
                                      style: TextStyle(fontSize: 9, color: colors.textSecondary, fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                    Text(
                                      _topUsersIsFallback
                                          ? '${user.commentCount}j 💬'
                                          : '${user.commentCount} 💬',
                                      style: TextStyle(fontSize: 9, color: colors.textSecondary),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openModal(BuildContext context, StreakProvider streak) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: streak,
        child: const _FlameStreakModal(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chip règle rapide
// ─────────────────────────────────────────────────────────────────────────────
class _RuleChip extends StatelessWidget {
  final String icon;
  final String label;
  final AppColors colors;
  const _RuleChip(
      {required this.icon, required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modal — détail complet : score, règles, niveaux, top commentateurs
// ─────────────────────────────────────────────────────────────────────────────
class _FlameStreakModal extends StatefulWidget {
  const _FlameStreakModal();

  @override
  State<_FlameStreakModal> createState() => _FlameStreakModalState();
}

class _FlameStreakModalState extends State<_FlameStreakModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _flameCtrl;
  late Animation<double> _flameScale;
  late Animation<double> _flameShake;

  @override
  void initState() {
    super.initState();
    _flameCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _flameScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _flameCtrl, curve: Curves.easeInOut),
    );
    _flameShake = Tween<double>(begin: -0.04, end: 0.04).animate(
      CurvedAnimation(parent: _flameCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Consumer<StreakProvider>(
      builder: (ctx, streak, _) {
        final bool done = streak.quotaReachedToday;
        final Color accent = done
            ? const Color(0xFF34C759)
            : streak.commentStreak > 0
                ? _levelColor(streak.level)
                : const Color(0xFF5B9CFA);

        final int myScore =
            _computeScore(streak.commentStreak, streak.bestStreak);

        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Poignée
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Emoji animé ─────────────────────────────────────────
                  AnimatedBuilder(
                    animation: _flameCtrl,
                    builder: (_, child) => Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..scale(_flameScale.value)
                        ..rotateZ(_flameShake.value),
                      child: child,
                    ),
                    child: Text(
                      _levelEmoji(streak.level),
                      style: const TextStyle(fontSize: 64),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Jours + label niveau ─────────────────────────────────
                  Text(
                    streak.commentStreak == 0
                        ? '0 jour'
                        : '${streak.commentStreak} jour${streak.commentStreak > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: accent,
                      letterSpacing: -1,
                    ),
                  ),
                  Text(
                    _levelLabel(streak.level).toUpperCase(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accent.withOpacity(0.7),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Progression du jour ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Commentaires aujourd'hui",
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.textSecondary,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                            Text(
                              '${streak.todayCount}/3',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: accent,
                                  fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: streak.todayCount / 3,
                            minHeight: 6,
                            backgroundColor: colors.border,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(accent),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          done
                              ? '🎉 Série du jour validée !'
                              : '${streak.remainingToday} commentaire${streak.remainingToday > 1 ? 's' : ''} sur des posts différents pour valider',
                          style: TextStyle(
                              fontSize: 12, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── Cartes stats : record · boucliers · mon score ────────
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: '🏆',
                          label: 'Record',
                          value: '${streak.bestStreak}j',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          icon: '🛡️',
                          label: 'Boucliers',
                          value: '${streak.shields}/3',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                          icon: '⭐',
                          label: 'Mes Points',
                          value: '$myScore pts',
                          highlight: accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Règles + niveaux ─────────────────────────────────────
                  _buildRulesSection(colors, streak.level),
                  const SizedBox(height: 16),

                  // ── Top Commentateurs (top 50) ───────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'TOP COMMENTATEURS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: colors.textSecondary,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const FlameLeaderboard(),
                  const SizedBox(height: 16),

                  // ── CTA ─────────────────────────────────────────────────
                  if (!done)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          'Commenter maintenant 💬',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRulesSection(AppColors colors, int currentLevel) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COMMENT MAINTENIR TA SÉRIE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          _buildRuleRow(
            '💬',
            'Envoie 3 commentaires sur 3 posts différents chaque jour pour valider ta série.',
            colors,
          ),
          const SizedBox(height: 6),
          _buildRuleRow(
            '🔁',
            'Un même post ne compte qu\'une seule fois par jour.',
            colors,
          ),
          const SizedBox(height: 6),
          _buildRuleRow(
            '🛡️',
            'Un bouclier absorbe un jour raté. Tu en gagnes 1 tous les 7 jours de série (max 3).',
            colors,
          ),
          const SizedBox(height: 6),
          _buildRuleRow(
            '⭐',
            'Tes points = (jours de série × 10) + (record × 5). Les likes reçus sur tes commentaires boosteront ton score prochainement.',
            colors,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          Text(
            'NIVEAUX DE COMMENTAIRES',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          ..._kLevels.indexed.map(
              ((int, ({String emoji, String label, String range, Color color}))
                      entry) {
            final idx = entry.$1;
            final lv = entry.$2;
            return _buildLevelRow(
              lv.emoji,
              lv.label,
              lv.range,
              lv.color,
              isActive: idx == currentLevel,
              isReached: idx < currentLevel,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRuleRow(String emoji, String text, AppColors colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
                fontSize: 12, color: colors.textSecondary, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildLevelRow(
    String emoji,
    String label,
    String range,
    Color color, {
    bool isActive = false,
    bool isReached = false,
  }) {
    final opacity = isActive || isReached ? 1.0 : 0.28;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: isActive
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 5)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: isActive
          ? BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.4)),
            )
          : null,
      child: Row(
        children: [
          Text(emoji,
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.white
                      .withOpacity(isActive || isReached ? 1.0 : 0.3))),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight:
                  isActive ? FontWeight.w800 : FontWeight.w600,
              color: color.withOpacity(opacity),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '·  $range',
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(opacity * 0.7),
            ),
          ),
          if (isActive) ...[
            const Spacer(),
            Text('← toi',
                style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Carte statistique
// ─────────────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color? highlight;
  const _StatCard(
      {required this.icon,
      required this.label,
      required this.value,
      this.highlight});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight?.withOpacity(0.3) ?? colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: colors.textSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: highlight ?? colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
