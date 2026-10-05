import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../l10n/tr.dart';
import '../../services/quiz/quiz_service.dart';
import '../../services/quiz/quiz_sound.dart';
import '../../services/quiz/quiz_usage.dart';
import '../../theme/app_colors.dart';
import '../etude/etude_home_page.dart';
import 'quiz_challenge_page.dart';
import 'quiz_daily.dart';
import 'quiz_history_page.dart';
import 'quiz_leaderboard_page.dart';
import 'quiz_level_page.dart';
import 'quiz_shop_page.dart';
import 'widgets/hawk_mascot.dart';
import 'widgets/quiz_consent.dart';
import 'widgets/quiz_loading.dart';
import 'widgets/quiz_dialogs.dart';
import 'widgets/quiz_widgets.dart';

/// Accueil du quiz : le parcours (200 niveaux en 40 unités), le quiz du jour, la série, les cœurs.
class QuizHomePage extends StatefulWidget {
  const QuizHomePage({super.key});

  @override
  State<QuizHomePage> createState() => _QuizHomePageState();
}

class _QuizHomePageState extends State<QuizHomePage> {
  static const double _unitHeader = 64;
  static const double _nodeRow = 96;
  static const double _unitH = _unitHeader + _nodeRow * 5 + 28;
  static const List<double> _zig = [-0.45, -0.1, 0.35, 0.45, 0.0];

  final ScrollController _scroll = ScrollController();
  final GlobalKey _mapKey = GlobalKey();
  Timer? _tick;
  bool _loading = true;
  String? _error;
  bool _muted = false;
  HawkMood _mood = HawkMood.wave;
  int _heartLeft = 0;
  bool _scrolled = false;
  final QuizUsageTracker _usage = QuizUsageTracker();

  @override
  void initState() {
    super.initState();
    _usage.start();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!await quizEnsureConsent(context) && mounted) Navigator.pop(context);
    });
    QuizSound.isMuted().then((m) {
      if (mounted) setState(() => _muted = m);
    });
    _refresh();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final s = QuizService.instance.state.value;
      if (s == null || s.hearts >= s.heartsMax) return;
      if (_heartLeft > 0) {
        setState(() => _heartLeft--);
      } else {
        _refresh(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _usage.stop();
    _tick?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false, bool scroll = false}) async {
    if (!silent) setState(() => _error = null);
    try {
      final s = await QuizService.instance.refresh();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _heartLeft = s.nextHeartInSec;
        if (!silent) _mood = HawkMood.wave;
      });
      if (!_scrolled || scroll) {
        _scrolled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
      }
    } catch (_) {
      if (mounted && !silent) {
        setState(() {
          _loading = false;
          _error = 'x';
        });
      }
    }
  }

  void _scrollToCurrent() {
    final s = QuizService.instance.state.value;
    final ctx = _mapKey.currentContext;
    if (s == null || ctx == null || !_scroll.hasClients) return;
    final ro = ctx.findRenderObject();
    if (ro == null) return;
    final base = RenderAbstractViewport.of(ro).getOffsetToReveal(ro, 0.0).offset;
    final unit = quizUnitOf(s.level.clamp(1, s.levels));
    final target = (base + unit * _unitH - 70).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target, duration: const Duration(milliseconds: 800), curve: Curves.easeInOutCubic);
  }

  Future<void> _tapNode(int n, QuizState s) async {
    if (n > s.level) {
      QuizSound.haptic(QuizSfx.bad);
      quizToast(context, context.tr("Termine d'abord les niveaux précédents."), error: true);
      return;
    }
    if (n == s.level && s.hearts <= 0) {
      await showQuizNoHearts(context, s);
      _refresh(silent: true);
      return;
    }
    QuizSound.fx(QuizSfx.hi);
    final done = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => QuizLevelPage(n: n)));
    if (!mounted) return;
    await _refresh(silent: true, scroll: done == true);
    if (done == true && mounted) setState(() => _mood = HawkMood.cheer);
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) _refresh(silent: true);
  }

  /// Phrases de la mascotte : variées (une par jour et par étape) et tournées vers le jeu, les points et le classement.
  String _pick(List<String> lines, QuizState s, [Map<String, Object?> args = const {}]) {
    final d = DateTime.now();
    final i = (d.year * 372 + d.month * 31 + d.day + s.completed) % lines.length;
    return context.tr(lines[i], args);
  }

  String _message(QuizState s) {
    if (s.finishedAll) return context.tr("Tu as terminé toute l'aventure, bravo ! De nouveaux niveaux arrivent bientôt.");
    if (s.hearts <= 0) return context.tr('Plus de cœurs… Reviens dans un moment ou regarde une pub !');
    if (s.completed == 0) {
      return _pick(const [
        'Un quiz, des points, un classement… prêt à montrer ce que tu sais ?',
        'Réponds juste, gagne des points et grimpe au classement !',
        'Chaque bonne réponse compte : montre ce que tu as dans la tête !',
        '3, 2, 1… à toi de jouer, ta première question t\'attend !',
      ], s);
    }
    if (!s.playedToday && s.streak > 0) {
      return _pick(const [
        'Ne perds pas ta série de {n} jours !',
        'Ta série de {n} jours t\'attend : une partie suffit !',
      ], s, {'n': s.streak});
    }
    if (s.playedToday && s.streak > 1) {
      return _pick(const [
        'Série de {n} jours, continue comme ça !',
        '{n} jours d\'affilée : tu es en feu !',
        '{n} jours de suite : le classement te regarde !',
      ], s, {'n': s.streak});
    }
    return _pick(const [
      'Prêt pour le niveau {n} ?',
      'Niveau {n} : réponds vite et bien pour les bonus !',
      'Un nouveau défi t\'attend au niveau {n} !',
      'Fais mieux qu\'hier : niveau {n}, c\'est parti !',
    ], s, {'n': s.level});
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        iconTheme: IconThemeData(color: c.textPrimary),
        title: Text(context.tr('Quiz'), style: TextStyle(fontWeight: FontWeight.w900, color: c.textPrimary)),
        actions: [
          IconButton(
            tooltip: context.tr('Son'),
            icon: Icon(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
            onPressed: () async {
              await QuizSound.setMuted(!_muted);
              setState(() => _muted = !_muted);
              if (!_muted) QuizSound.fx(QuizSfx.hi);
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<QuizState?>(
        valueListenable: QuizService.instance.state,
        builder: (_, s, __) {
          if (_error != null && s == null) return _errorView(c);
          if (s == null || _loading) return const QuizLoading(kind: QuizLoadingKind.home);
          if (!s.enabled) return _pausedView(c);
          return RefreshIndicator(
            onRefresh: () => _refresh(),
            child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _header(c, s)),
                SliverToBoxAdapter(child: _dailyCard(c, s)),
                SliverToBoxAdapter(child: _challengeCard(c, s)),
                SliverToBoxAdapter(child: _etudeCard(c)),
                SliverToBoxAdapter(child: _links(c)),
                SliverToBoxAdapter(child: SizedBox(key: _mapKey, height: 6)),
                SliverFixedExtentList(
                  itemExtent: _unitH,
                  delegate: SliverChildBuilderDelegate(
                    (ctx, u) => _unit(ctx, c, s, u),
                    childCount: s.levels ~/ 5,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _errorView(AppColors c) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const HawkMascot(mood: HawkMood.sad, size: 130),
            const SizedBox(height: 12),
            Text(context.tr('Impossible de charger le quiz.'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.textPrimary)),
            const SizedBox(height: 16),
            QuizChunkyButton(label: context.tr('Réessayer'), onPressed: () {
              setState(() => _loading = true);
              _refresh();
            }),
          ]),
        ),
      );

  Widget _pausedView(AppColors c) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const HawkMascot(size: 130),
            const SizedBox(height: 12),
            Text(context.tr('Le quiz est en pause pour le moment.'), textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.textPrimary)),
          ]),
        ),
      );

  Widget _header(AppColors c, QuizState s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          GestureDetector(
            onTap: () {
              QuizSound.fx(QuizSfx.hi);
              setState(() => _mood = _mood == HawkMood.cheer ? HawkMood.wave : HawkMood.cheer);
            },
            child: HawkMascot(mood: _mood, size: 104, accessory: s.equipped['accessory']),
          ),
          const SizedBox(width: 10),
          Expanded(child: QuizBubble(child: Text(_message(s), style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, height: 1.3, color: c.textPrimary)))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _stat(c, Icons.local_fire_department_rounded, c.warning, '${s.streak}', context.tr('série'))),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => showQuizNoHearts(context, s).then((_) => _refresh(silent: true)),
              child: _stat(
                c,
                Icons.favorite_rounded,
                c.danger,
                '${s.hearts}/${s.heartsMax}',
                s.hearts >= s.heartsMax ? context.tr('cœurs') : quizClock(_heartLeft),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => _open(const QuizShopPage()),
              child: _stat(c, Icons.star_rounded, c.accent, '${s.points}', context.tr('points')),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _stat(AppColors c, IconData icon, Color color, String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border, width: 1.5),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: c.textPrimary)),
        ]),
        Text(label, style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _dailyCard(AppColors c, QuizState s) {
    final done = s.dailyDone;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: GestureDetector(
        onTap: done ? null : () => _open(const QuizDailyPage()),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: done
                ? null
                : LinearGradient(colors: [c.primary.withOpacity(0.28), c.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
            color: done ? c.surface : null,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: done ? c.border : c.primary, width: 1.5),
          ),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: done ? c.surfaceVariant : c.accent, borderRadius: BorderRadius.circular(14)),
              child: Icon(done ? Icons.check_rounded : Icons.today_rounded, color: done ? c.primary : c.onAccent, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tr('Quiz du jour'), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: c.textPrimary)),
                Text(
                  done
                      ? context.tr('Terminé ! Reviens demain pour 3 nouvelles questions.')
                      : context.tr('3 questions, les mêmes pour tout le monde. Une minute suffit.'),
                  style: TextStyle(color: c.textSecondary, fontSize: 12.5),
                ),
              ]),
            ),
            if (!done) Icon(Icons.chevron_right_rounded, color: c.primary, size: 30),
          ]),
        ),
      ),
    );
  }

  Widget _challengeCard(AppColors c, QuizState s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: GestureDetector(
        onTap: () => _open(const QuizChallengePage()),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [c.accent.withOpacity(0.30), c.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.accent, width: 1.5),
          ),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.emoji_events_rounded, color: c.onPrimary, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tr('Grand Défi'), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: c.textPrimary)),
                Text(
                  s.challengeBest > 0
                      ? context.tr('15 bonnes réponses d\'affilée. Ton record : {n}/15', {'n': s.challengeBest})
                      : context.tr('15 bonnes réponses d\'affilée, paliers et jokers. Oseras-tu ?'),
                  style: TextStyle(color: c.textSecondary, fontSize: 12.5),
                ),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: c.accent, size: 30),
          ]),
        ),
      ),
    );
  }

  /// Entrée vers Étude : le quiz de culture et les parcours scolaires sont deux modules séparés.
  Widget _etudeCard(AppColors c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: GestureDetector(
        onTap: () => _open(const EtudeHomePage()),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [c.info.withOpacity(0.22), c.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.info, width: 1.5),
          ),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: c.info, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.school_rounded, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tr('Étude'), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: c.textPrimary)),
                Text(context.tr('Collège, lycée, université, entretien d\'embauche : valide tes classes et décroche ton diplôme.'), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: c.info, size: 30),
          ]),
        ),
      ),
    );
  }

  Widget _links(AppColors c) {
    Widget tile(IconData icon, String label, Color color, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: c.border, width: 1.5),
              ),
              child: Column(children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 3),
                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.textPrimary)),
              ]),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(children: [
        tile(Icons.leaderboard_rounded, context.tr('Classement'), c.accent, () => _open(const QuizLeaderboardPage())),
        const SizedBox(width: 8),
        tile(Icons.storefront_rounded, context.tr('Boutique'), c.primary, () => _open(const QuizShopPage())),
        const SizedBox(width: 8),
        tile(Icons.history_rounded, context.tr('Mes questions'), c.info, () => _open(const QuizHistoryPage())),
      ]),
    );
  }

  Widget _unit(BuildContext ctx, AppColors c, QuizState s, int u) {
    final theme = quizThemeOfUnit(u);
    final tier = u ~/ 8 + 1;
    final first = u * 5 + 1;
    final locked = first > s.level;
    return SizedBox(
      height: _unitH,
      child: Column(children: [
        SizedBox(
          height: _unitHeader,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: locked ? c.surfaceVariant : theme.color,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: (locked ? c.border : Color.lerp(theme.color, Colors.black, 0.3)!), offset: const Offset(0, 3))],
              ),
              child: Row(children: [
                Icon(theme.icon, color: locked ? c.textSecondary : Colors.white, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      ctx.tr('Unité {n}', {'n': u + 1}),
                      style: TextStyle(color: locked ? c.textSecondary : Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    ),
                    Text(theme.name(ctx), style: TextStyle(color: locked ? c.textSecondary : Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                  ]),
                ),
                Row(children: [
                  for (var k = 0; k < 5; k++)
                    Icon(Icons.star_rounded, size: 14, color: k < tier ? (locked ? c.textSecondary : c.accent) : (locked ? c.border : Colors.white24)),
                ]),
              ]),
            ),
          ),
        ),
        for (var j = 0; j < 5; j++) _nodeRowWidget(ctx, c, s, u * 5 + j + 1, _zig[j], theme),
        const SizedBox(height: 28),
      ]),
    );
  }

  Widget _nodeRowWidget(BuildContext ctx, AppColors c, QuizState s, int n, double x, QuizTheme theme) {
    final done = n < s.level;
    final current = n == s.level;
    final color = done ? c.accent : current ? theme.color : c.surfaceVariant;
    final edge = done ? const Color(0xFFB8860B) : current ? Color.lerp(theme.color, Colors.black, 0.35)! : c.border;
    final mascotRight = x < 0.1;
    return SizedBox(
      height: _nodeRow,
      child: Align(
        alignment: Alignment(x, 0),
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
          if (current)
            Positioned.fill(
              child: Center(
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: theme.color, width: 4)),
                )
                    .animate(onPlay: (ctl) => ctl.repeat())
                    .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.4, 1.4), duration: 1500.ms)
                    .fadeOut(duration: 1500.ms),
              ),
            ),
          GestureDetector(
            onTap: () => _tapNode(n, s),
            child: Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [BoxShadow(color: edge, offset: const Offset(0, 6))],
              ),
              child: Icon(
                done ? Icons.check_rounded : current ? Icons.star_rounded : Icons.lock_rounded,
                size: done || current ? 40 : 28,
                color: done ? const Color(0xFF3B2A00) : current ? Colors.white : c.textSecondary,
              ),
            ),
          ),
          if (current)
            Positioned(
              top: -26,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(color: c.textPrimary, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  ctx.tr('COMMENCER'),
                  style: TextStyle(color: c.background, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.6),
                ),
              ).animate(onPlay: (ctl) => ctl.repeat(reverse: true)).moveY(begin: 0, end: -5, duration: 700.ms),
            ),
          if (current)
            Positioned(
              left: mascotRight ? 90 : null,
              right: mascotRight ? null : 90,
              child: HawkMascot(size: 76, mood: HawkMood.idle, accessory: s.equipped['accessory'], flip: !mascotRight),
            ),
        ]),
      ),
    );
  }
}
