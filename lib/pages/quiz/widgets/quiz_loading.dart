import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/tr.dart';
import '../../../theme/app_colors.dart';
import 'hawk_mascot.dart';

enum QuizLoadingKind { home, level, challenge, daily, ranking, history, saving }

const Map<QuizLoadingKind, List<String>> _messages = {
  QuizLoadingKind.home: [
    "Je réveille l'épervier…",
    'Je prépare ton parcours…',
    "Je range les questions dans mon nid…",
    'Je compte tes points et ta série…',
    'Presque prêt !',
  ],
  QuizLoadingKind.level: [
    'Je choisis tes questions…',
    'Je mélange les réponses…',
    'Je vérifie que ce n\'est pas trop facile…',
    'Je prépare ton niveau…',
    'C\'est parti dans un instant !',
  ],
  QuizLoadingKind.challenge: [
    'Je prépare le Grand Défi…',
    'Je cache les pièges…',
    'Je range les jokers…',
    'Je règle le chronomètre…',
    'Respire, ça arrive !',
  ],
  QuizLoadingKind.daily: [
    'Je cherche les questions du jour…',
    'Les mêmes pour tout le monde…',
    'Presque prêt !',
  ],
  QuizLoadingKind.ranking: [
    'Je compte les points de la semaine…',
    'Je range les champions…',
    'Je compare les pays…',
    'Un instant…',
  ],
  QuizLoadingKind.history: [
    'Je retrouve tes réponses…',
    'Je classe tes questions…',
    'Un instant…',
  ],
  QuizLoadingKind.saving: [
    'Je corrige tes réponses…',
    'Je compte tes points…',
    'Je prépare ta récompense…',
  ],
};

/// Attente du quiz : l'épervier flotte et change d'humeur, les phrases défilent et une barre avance doucement,
/// pour que la personne sente que quelque chose se prépare au lieu de fixer un cercle.
class QuizLoading extends StatefulWidget {
  const QuizLoading({super.key, this.kind = QuizLoadingKind.home, this.compact = false});
  final QuizLoadingKind kind;

  /// Version réduite (dans une carte du fil).
  final bool compact;

  @override
  State<QuizLoading> createState() => _QuizLoadingState();
}

class _QuizLoadingState extends State<QuizLoading> with SingleTickerProviderStateMixin {
  static const _moods = [HawkMood.think, HawkMood.wave, HawkMood.idle, HawkMood.cheer];
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  Timer? _timer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (mounted) setState(() => _tick++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final list = _messages[widget.kind]!;
    final slow = _tick >= 5;
    // Les phrases défilent une fois, puis la dernière reste ; après ~9 s on rassure.
    final text = slow ? 'C\'est un peu plus long que d\'habitude, ne pars pas !' : list[_tick.clamp(0, list.length - 1)];
    final mood = _moods[(_tick ~/ 2) % _moods.length];
    final size = widget.compact ? 64.0 : 130.0;
    // Barre qui avance vite puis ralentit, sans jamais arriver au bout
    final progress = 1 - 1 / (1 + _tick * 0.55);

    final hawk = AnimatedBuilder(
      animation: _float,
      builder: (_, child) => Transform.translate(offset: Offset(0, -8 * Curves.easeInOut.transform(_float.value)), child: child),
      child: HawkMascot(mood: mood, size: size),
    );
    final label = AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(anim), child: child),
      ),
      child: Text(
        context.tr(text),
        key: ValueKey(text),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: widget.compact ? 13.5 : 16, fontWeight: FontWeight.w800, color: c.textPrimary, height: 1.3),
      ),
    );
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: progress),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOut,
        builder: (_, v, __) => LinearProgressIndicator(
          value: v,
          minHeight: widget.compact ? 6 : 9,
          backgroundColor: c.surfaceVariant,
          valueColor: AlwaysStoppedAnimation(c.primary),
        ),
      ),
    );

    if (widget.compact) {
      return Row(children: [
        hawk,
        const SizedBox(width: 12),
        Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(height: 36, child: Align(alignment: Alignment.centerLeft, child: label)),
          const SizedBox(height: 6),
          bar,
        ])),
      ]);
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          hawk,
          const SizedBox(height: 18),
          SizedBox(height: 48, child: Center(child: label)),
          const SizedBox(height: 14),
          SizedBox(width: 220, child: bar),
        ]),
      ),
    );
  }
}
