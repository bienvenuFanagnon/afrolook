import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/streakProvider.dart';
import '../providers/authProvider.dart';
import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Carte Flamme Streak — explique le concept + affiche la progression du jour
// ─────────────────────────────────────────────────────────────────────────────
class FlameStreakBanner extends StatefulWidget {
  const FlameStreakBanner({super.key});

  @override
  State<FlameStreakBanner> createState() => _FlameStreakBannerState();
}

class _FlameStreakBannerState extends State<FlameStreakBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

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
    });
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

        // Couleur accent selon état
        final Color accent = done
            ? const Color(0xFF34C759)
            : urgent
                ? const Color(0xFFFF6B35)
                : cold
                    ? const Color(0xFF5B9CFA)
                    : const Color(0xFFFF9500);

        final String statusText = done
            ? '🎉 Objectif du jour atteint !'
            : urgent
                ? '${streak.remainingToday} commentaire${streak.remainingToday > 1 ? 's' : ''} encore pour sauver ta flamme'
                : cold
                    ? 'Commence ta série dès maintenant'
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
                  // ── Barre supérieure colorée ────────────────────────────
                  Container(height: 3, color: accent),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── En-tête : titre + badge niveau ────────────────
                        Row(
                          children: [
                            AnimatedBuilder(
                              animation: _pulseCtrl,
                              builder: (_, __) => Transform.scale(
                                scale: urgent
                                    ? 1.0 + 0.15 * _pulseCtrl.value
                                    : 1.0,
                                child: Text(
                                  cold ? '🧊' : '🔥',
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
                                    'Flamme Streak',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900,
                                      color: colors.textPrimary,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  Text(
                                    'Commente 3 posts différents chaque jour',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Badge série
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

                        // ── Progression du jour ────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.surfaceVariant,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              // Dots + label
                              Row(
                                children: [
                                  ...List.generate(3, (i) {
                                    final filled = i < streak.todayCount;
                                    return Expanded(
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(right: 6),
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 300),
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
                                      margin: const EdgeInsets.only(left: 8),
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

                        // ── Pied de carte : règles rapides ─────────────────
                        Row(
                          children: [
                            _RuleChip(
                                icon: '📅',
                                label: '3 posts / jour',
                                colors: colors),
                            const SizedBox(width: 8),
                            _RuleChip(
                                icon: '🛡️',
                                label: 'Bouclier tous les 7j',
                                colors: colors),
                            const Spacer(),
                            Text(
                              'Voir détails',
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
// Modal bottom sheet — détail complet
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
                ? const Color(0xFFFF6B35)
                : const Color(0xFF5B9CFA);

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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                      streak.commentStreak == 0 ? '🧊' : '🔥',
                      style: const TextStyle(fontSize: 64),
                    ),
                  ),
                  const SizedBox(height: 12),

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
                    _streakLevelLabel(streak.level),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accent.withOpacity(0.7),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),

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
                              "Aujourd'hui",
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
                            valueColor: AlwaysStoppedAnimation<Color>(accent),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          done
                              ? '🎉 Flamme du jour sauvée !'
                              : '${streak.remainingToday} commentaire${streak.remainingToday > 1 ? 's' : ''} sur des posts différents pour valider',
                          style: TextStyle(
                              fontSize: 12, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                            icon: '🏆',
                            label: 'Record',
                            value: '${streak.bestStreak}j'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _StatCard(
                            icon: '🛡️',
                            label: 'Boucliers',
                            value: '${streak.shields}/3'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildRulesSection(colors),
                  const SizedBox(height: 16),

                  if (!done)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          'Aller commenter 🔥',
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

  Widget _buildRulesSection(AppColors colors) {
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
            'COMMENT GARDER TA FLAMME',
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
            'Envoie 3 commentaires sur 3 posts différents chaque jour pour valider ta flamme.',
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
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          Text(
            'NIVEAUX DE FLAMME',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          _buildLevelRow('🧊', 'Froid', '0 jour', colors.textSecondary),
          _buildLevelRow('🌊', 'Tiède', '1 – 2 jours', const Color(0xFF5B9CFA)),
          _buildLevelRow('☀️', 'Chaud', '3 – 6 jours', const Color(0xFFFF9500)),
          _buildLevelRow('🔥', 'Enflammé', '7 – 13 jours', const Color(0xFFFF6B35)),
          _buildLevelRow('💥', 'Brûlant', '14 – 29 jours', const Color(0xFFFF3B30)),
          _buildLevelRow('⚡', 'Légendaire', '30+ jours', const Color(0xFFAF52DE)),
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
            style: TextStyle(fontSize: 12, color: colors.textSecondary, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildLevelRow(String emoji, String label, String range, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '·  $range',
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.65),
            ),
          ),
        ],
      ),
    );
  }

  String _streakLevelLabel(int level) {
    const labels = [
      'Froid',
      'Tiède',
      'Chaud',
      'Enflammé',
      'Brûlant',
      'Légendaire'
    ];
    return labels[level.clamp(0, 5)].toUpperCase();
  }
}

class _StatCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  const _StatCard(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: colors.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
