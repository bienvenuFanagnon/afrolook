import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ads/ad_gate.dart';
import '../../ads/ad_slot.dart';
import '../../ads/admob_service.dart';
import '../../l10n/tr.dart';
import '../../providers/authProvider.dart';
import '../../services/quiz/quiz_service.dart';
import '../../services/quiz/quiz_sound.dart';
import '../../services/quiz/quiz_voice.dart';
import '../../theme/app_colors.dart';
import '../pub/afrolook_inline_ad.dart';
import 'widgets/hawk_mascot.dart';
import 'widgets/quiz_loading.dart';
import 'widgets/quiz_pace.dart';
import 'widgets/quiz_dialogs.dart';
import 'widgets/quiz_widgets.dart';

/// Un niveau : 5 questions, une mascotte qui réagit, un panneau de réponse, puis l'écran de fin.
/// Se ferme avec `true` quand le niveau a été terminé.
class QuizLevelPage extends StatefulWidget {
  const QuizLevelPage({super.key, required this.n});
  final int n;

  @override
  State<QuizLevelPage> createState() => _QuizLevelPageState();
}

class _QuizLevelPageState extends State<QuizLevelPage> {
  QuizLevelStart? _start;
  String? _error;
  int _i = 0;
  int? _selected;
  QuizAnswerResult? _result;
  bool _busy = false;
  bool _finishing = false;
  int _combo = 0;
  int _hearts = 5;
  HawkMood _mood = HawkMood.idle;
  QuizFinish? _finish;
  int _gain = 0;
  bool _doubled = false;
  bool _doubling = false;
  final ConfettiController _confetti = ConfettiController(duration: const Duration(seconds: 3));
  final QuizPace _pace = QuizPace();

  @override
  void initState() {
    super.initState();
    QuizVoice.instance.load();
    _load();
  }

  @override
  void dispose() {
    _pace.dispose();
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _start = null;
      _i = 0;
      _selected = null;
      _result = null;
      _finish = null;
      _combo = 0;
      _pace.fast = 0;
      _mood = HawkMood.idle;
    });
    try {
      final s = await QuizService.instance.startLevel(widget.n);
      if (!mounted) return;
      final user = context.read<UserAuthProvider>().loginUserData;
      AdmobService.warmUpInterstitial(user);
      if (quizCanOfferRewarded(context)) AdmobService.loadRewarded();
      setState(() {
        _start = s;
        _hearts = s.state.hearts;
      });
      QuizSound.fx(QuizSfx.hi);
      QuizVoice.instance.prefetch(s.questions.map((x) => (q: x.q, o: x.o)));
      _beginQuestion();
    } on QuizException catch (e) {
      if (!mounted) return;
      if (e.code.contains('NO_HEARTS')) {
        final st = QuizService.instance.state.value ?? await QuizService.instance.refresh();
        if (!mounted) return;
        await showQuizNoHearts(context, st);
        if (mounted) Navigator.pop(context, false);
        return;
      }
      setState(() => _error = e.code);
    } catch (_) {
      if (mounted) setState(() => _error = 'NETWORK');
    }
  }

  /// Lecture à voix haute et chrono de la question affichée.
  void _beginQuestion() {
    final q = _start?.questions[_i];
    if (q == null) return;
    _pace.start(question: q.q, options: q.o);
  }

  Future<void> _choose(int idx) async {
    if (_busy || _result != null || _start == null) return;
    QuizVoice.instance.stop();
    QuizSound.fx(QuizSfx.tap);
    setState(() {
      _selected = idx;
      _busy = true;
      _mood = HawkMood.think;
    });
    QuizAnswerResult? res;
    for (var attempt = 0; attempt < 2 && res == null; attempt++) {
      try {
        res = await QuizService.instance.answer(widget.n, _i, idx);
      } on QuizException catch (e) {
        if (e.code.contains('TOO_FAST') && attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 750));
          continue;
        }
        if (!mounted) return;
        quizToast(context, context.tr('Une erreur est survenue, réessaie.'), error: true);
        setState(() {
          _busy = false;
          _selected = null;
        });
        return;
      } catch (_) {
        if (!mounted) return;
        quizToast(context, context.tr('Connexion impossible. Vérifie ta connexion.'), error: true);
        setState(() {
          _busy = false;
          _selected = null;
        });
        return;
      }
    }
    if (!mounted || res == null) return;
    final r = res;
    _pace.answered(correct: r.correct);
    QuizSound.fx(r.correct ? QuizSfx.ok : QuizSfx.bad);
    setState(() {
      _result = r;
      _busy = false;
      _hearts = r.hearts;
      _combo = r.correct ? _combo + 1 : 0;
      _mood = r.correct ? HawkMood.cheer : HawkMood.sad;
    });
  }

  Future<void> _next() async {
    QuizSound.fx(QuizSfx.tap);
    final total = _start!.questions.length;
    if (_i < total - 1) {
      setState(() {
        _i++;
        _selected = null;
        _result = null;
        _mood = HawkMood.idle;
      });
      _beginQuestion();
      return;
    }
    setState(() => _finishing = true);
    try {
      final f = await QuizService.instance.finishLevel(widget.n);
      if (!mounted) return;
      setState(() {
        _finish = f;
        _gain = f.gain;
        _finishing = false;
        _mood = f.pass ? HawkMood.cheer : HawkMood.sad;
      });
      if (f.pass) {
        QuizSound.fx(QuizSfx.win);
        _confetti.play();
      } else {
        QuizSound.fx(QuizSfx.bad);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _finishing = false);
      quizToast(context, context.tr('Connexion impossible. Vérifie ta connexion.'), error: true);
    }
  }

  Future<void> _double() async {
    final f = _finish;
    if (f == null || _doubling || _doubled) return;
    setState(() => _doubling = true);
    final ok = await AdmobService.watchRewarded(userId: QuizService.instance.uid);
    if (!mounted) return;
    if (!ok) {
      setState(() => _doubling = false);
      quizToast(context, context.tr("La pub n'est pas disponible pour le moment. Réessaie dans un instant."), error: true);
      return;
    }
    try {
      final extra = await QuizService.instance.doublePoints(widget.n);
      if (!mounted) return;
      QuizSound.fx(QuizSfx.up);
      _confetti.play();
      setState(() {
        _gain += extra;
        _doubled = true;
        _doubling = false;
      });
    } catch (_) {
      if (mounted) setState(() => _doubling = false);
    }
  }

  /// Pub plein écran après quelques niveaux (réglable à distance), jamais pendant les questions.
  Future<void> _leave() async {
    final f = _finish;
    if (f != null && f.pass && !f.practice) {
      try {
        final cfg = QuizService.instance.config;
        final user = context.read<UserAuthProvider>().loginUserData;
        if (cfg.adsEnabled && AdGate.canShowType(user, 'interstitial')) {
          final sp = await SharedPreferences.getInstance();
          final now = DateTime.now();
          final day = '${now.year}-${now.month}-${now.day}';
          if (sp.getString('quiz_ad_day') != day) {
            await sp.setString('quiz_ad_day', day);
            await sp.setInt('quiz_ad_count', 0);
          }
          final since = (sp.getInt('quiz_lv_since_ad') ?? 0) + 1;
          final shown = sp.getInt('quiz_ad_count') ?? 0;
          if (since >= cfg.interstitialEveryLevels && shown < cfg.interstitialMaxPerDay) {
            await sp.setInt('quiz_lv_since_ad', 0);
            await sp.setInt('quiz_ad_count', shown + 1);
            final shownNow = await AdmobService.showInterstitialNow(onDismissed: _pop, onFailed: _pop);
            if (!shownNow) _pop();
            return;
          }
          await sp.setInt('quiz_lv_since_ad', since);
        }
      } catch (_) {}
    }
    _pop();
  }

  void _pop() {
    if (mounted) Navigator.pop(context, _finish != null);
  }

  Future<bool> _confirmQuit() async {
    if (_finish != null || _start == null || (_i == 0 && _result == null)) return true;
    final c = AppColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(ctx.tr('Quitter ce niveau ?'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
        content: Text(ctx.tr('Tu perdras ta progression dans ce niveau.'), style: TextStyle(color: c.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('Continuer'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('Quitter'), style: TextStyle(color: c.danger))),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (await _confirmQuit() && mounted) Navigator.pop(context, _finish != null);
      },
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: Stack(children: [
            _body(c),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.04,
                numberOfParticles: 24,
                gravity: 0.25,
                colors: [c.primary, c.accent, c.warning, c.info, const Color(0xFFFF5C9E)],
              ),
            ),
            if (_finishing)
              Positioned.fill(
                child: Container(
                  color: c.background.withOpacity(0.7),
                  alignment: Alignment.center,
                  child: const QuizLoading(kind: QuizLoadingKind.saving),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _body(AppColors c) {
    if (_error != null) return _errorView(c);
    final s = _start;
    if (s == null) {
      return const QuizLoading(kind: QuizLoadingKind.level);
    }
    if (_finish != null) return _resultView(c, _finish!);
    return _lesson(c, s);
  }

  Widget _errorView(AppColors c) {
    final off = _error!.contains('QUIZ_OFF');
    final locked = _error!.contains('LEVEL_LOCKED');
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const HawkMascot(mood: HawkMood.sad, size: 130),
        const SizedBox(height: 14),
        Text(
          off
              ? context.tr('Le quiz est en pause pour le moment.')
              : locked
                  ? context.tr("Ce niveau n'est pas encore débloqué.")
                  : context.tr('Impossible de charger le niveau.'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.textPrimary),
        ),
        const SizedBox(height: 18),
        if (!off && !locked) QuizChunkyButton(label: context.tr('Réessayer'), onPressed: _load),
        QuizChunkyButton(
          label: context.tr('Retour'),
          color: c.surfaceVariant,
          textColor: c.textPrimary,
          onPressed: () => Navigator.pop(context, false),
        ),
      ]),
    );
  }

  Widget _lesson(AppColors c, QuizLevelStart s) {
    final q = s.questions[_i];
    final total = s.questions.length;
    final answered = _result != null;
    final theme = quizThemeByKey(s.theme);
    final equipped = QuizService.instance.state.value?.equipped['accessory'];
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 14, 4),
        child: Row(children: [
          IconButton(
            icon: Icon(Icons.close_rounded, color: c.textSecondary),
            onPressed: () async {
              if (await _confirmQuit() && mounted) Navigator.pop(context, false);
            },
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (_i + (answered ? 1 : 0)) / total),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 14,
                  backgroundColor: c.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation(theme.color),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          QuizPill(icon: Icons.favorite_rounded, label: '$_hearts', color: c.danger),
          QuizVoiceButtons(onReplay: _replay),
        ]),
      ),
      if (s.practice)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(color: c.info.withOpacity(0.14), borderRadius: BorderRadius.circular(999)),
          child: Text(context.tr('Entraînement : pas de points, pas de cœurs perdus'),
              style: TextStyle(color: c.info, fontWeight: FontWeight.w700, fontSize: 12)),
        ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(children: [
                QuizPaceHawk(pace: _pace, mood: _mood, answered: answered, accessory: equipped),
                if (_combo >= 2)
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: c.warning, borderRadius: BorderRadius.circular(999)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.local_fire_department_rounded, size: 14, color: Colors.white),
                      Text(' x$_combo', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                    ]),
                  ),
              ]),
              const SizedBox(width: 12),
              Expanded(
                child: QuizBubble(
                  child: Text(q.q, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, height: 1.3, color: c.textPrimary)),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            if (!answered) QuizPaceBar(pace: _pace),
            const SizedBox(height: 6),
            Text(
              context.tr('Question {i} sur {n}', {'i': _i + 1, 'n': total}),
              style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 12),
            for (var k = 0; k < q.o.length; k++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: QuizOption(
                  letter: 'ABCD'[k],
                  text: q.o[k],
                  state: _optionState(k),
                  checking: _busy && !answered,
                  onTap: answered || _busy ? null : () => _choose(k),
                ),
              ),
            if (_busy && !answered) const QuizChecking(),
          ]),
        ),
      ),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (child, anim) => SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
          child: child,
        ),
        child: answered ? _feedback(c, _result!, s) : const SizedBox(key: ValueKey('nofeedback'), width: double.infinity),
      ),
    ]);
  }

  void _replay() {
    final q = _start?.questions[_i];
    if (q == null || _result != null) return;
    QuizVoice.instance.speakQuestion(q.q, q.o);
  }

  QuizOptionState _optionState(int k) {
    final r = _result;
    if (r == null) return _selected == k ? QuizOptionState.selected : QuizOptionState.idle;
    if (k == r.correctIndex) return QuizOptionState.correct;
    if (k == _selected) return QuizOptionState.wrong;
    return QuizOptionState.dimmed;
  }

  Widget _feedback(AppColors c, QuizAnswerResult r, QuizLevelStart s) {
    final color = r.correct ? c.primary : c.danger;
    final last = _i == s.questions.length - 1;
    return Container(
      key: ValueKey('fb$_i'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        border: Border(top: BorderSide(color: color, width: 2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Icon(r.correct ? Icons.check_circle_rounded : Icons.cancel_rounded, color: color, size: 26),
          const SizedBox(width: 8),
          Text(
            r.correct ? context.tr('Bravo !') : context.tr('Presque…'),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color),
          ),
        ]),
        if (!r.correct) ...[
          const SizedBox(height: 6),
          Text(
            context.tr('Bonne réponse : {r}', {'r': _start!.questions[_i].o[r.correctIndex]}),
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ],
        const SizedBox(height: 6),
        Text(r.explanation, style: TextStyle(color: c.textPrimary, fontSize: 13.5, height: 1.35)),
        const SizedBox(height: 12),
        SafeArea(
          top: false,
          child: QuizChunkyButton(
            label: last ? context.tr('Terminer') : context.tr('Continuer'),
            color: color,
            textColor: r.correct ? c.onPrimary : Colors.white,
            onPressed: _next,
          ),
        ),
      ]),
    );
  }

  Widget _resultView(AppColors c, QuizFinish f) {
    final user = context.read<UserAuthProvider>().loginUserData;
    final canDouble = f.pass && f.canDouble && !_doubled && quizCanOfferRewarded(context);
    final showAd = QuizService.instance.config.adsEnabled && AdGate.userSeesAds(user);
    final equipped = f.state.equipped['accessory'];
    final title = !f.pass
        ? context.tr('Raté de peu')
        : f.practice
            ? context.tr('Bien joué !')
            : f.perfect
                ? context.tr('Parfait !')
                : context.tr('Niveau terminé !');
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(children: [
        HawkMascot(mood: _mood, size: 150, accessory: equipped),
        const SizedBox(height: 6),
        Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: c.textPrimary)),
        const SizedBox(height: 4),
        Text(
          f.pass
              ? context.tr('{c} bonnes réponses sur {n}', {'c': f.correct, 'n': f.total})
              : context.tr('Il faut au moins 3 bonnes réponses pour passer.'),
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _statCard(c, Icons.star_rounded, c.accent, _gain, context.tr('points'), animate: true)),
          const SizedBox(width: 10),
          Expanded(child: _statCard(c, Icons.check_circle_rounded, c.primary, f.correct, '/ ${f.total}')),
          const SizedBox(width: 10),
          Expanded(child: _statCard(c, Icons.local_fire_department_rounded, c.warning, f.state.streak, context.tr('jours'))),
        ]),
        if (_pace.fast > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(child: QuizPill(icon: Icons.bolt_rounded, label: context.tr('{n} réponses éclair', {'n': _pace.fast}), color: c.accent)),
          ),
        if (f.practice)
          _note(c, context.tr("Entraînement : ce niveau était déjà gagné, il ne rapporte pas de points."))
        else if (f.capped)
          _note(c, context.tr("Tu as atteint le plafond de points du jour. Reviens demain !")),
        const SizedBox(height: 22),
        if (canDouble)
          QuizChunkyButton(
            label: context.tr('Doubler mes points · une pub'),
            icon: Icons.play_circle_fill_rounded,
            color: c.accent,
            textColor: c.onAccent,
            loading: _doubling,
            onPressed: _double,
          ),
        if (!f.pass)
          QuizChunkyButton(label: context.tr('Réessayer'), icon: Icons.refresh_rounded, onPressed: _load),
        QuizChunkyButton(
          label: f.pass ? context.tr('Continuer') : context.tr('Retour'),
          color: f.pass ? c.primary : c.surfaceVariant,
          textColor: f.pass ? c.onPrimary : c.textPrimary,
          onPressed: _leave,
        ),
        if (showAd) ...[
          const SizedBox(height: 10),
          AdSlot(kind: AdSlotKind.list, own: () => const AfrolookInlineAd(compact: true)),
        ],
      ]),
    );
  }

  Widget _statCard(AppColors c, IconData icon, Color color, int value, String label, {bool animate = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.6), width: 2),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.toDouble()),
          duration: Duration(milliseconds: animate ? 900 : 500),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Text(
            '${animate ? '+' : ''}${v.round()}',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: c.textPrimary),
          ),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
      ]),
    );
  }

  Widget _note(AppColors c, String text) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
      );
}
