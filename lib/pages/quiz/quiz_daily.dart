import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/quiz/quiz_service.dart';
import '../../services/quiz/quiz_sound.dart';
import '../../theme/app_colors.dart';
import 'widgets/hawk_mascot.dart';
import 'widgets/quiz_widgets.dart';

/// Les 3 questions du jour : même chose pour tout le monde, jouables directement dans le fil
/// ([compact]) ou sur une page entière.
class QuizDailyPlayer extends StatefulWidget {
  const QuizDailyPlayer({super.key, this.compact = false, this.onContinue, this.onFinished});
  final bool compact;
  final VoidCallback? onContinue;
  final VoidCallback? onFinished;

  @override
  State<QuizDailyPlayer> createState() => _QuizDailyPlayerState();
}

class _QuizDailyPlayerState extends State<QuizDailyPlayer> {
  QuizDaily? _daily;
  bool _error = false;
  int _i = 0;
  int? _selected;
  QuizAnswerResult? _result;
  bool _busy = false;
  int _gain = 0;
  bool _finishedNow = false;
  int _correct = 0;
  HawkMood _mood = HawkMood.idle;
  final ConfettiController _confetti = ConfettiController(duration: const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    try {
      final d = await QuizService.instance.dailyGet();
      if (!mounted) return;
      setState(() {
        _daily = d;
        _i = d.answered;
        _correct = d.results.where((r) => r.correct).length;
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _choose(int idx) async {
    final d = _daily;
    if (d == null || _busy || _result != null) return;
    QuizSound.fx(QuizSfx.tap);
    setState(() {
      _selected = idx;
      _busy = true;
    });
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final r = await QuizService.instance.dailyAnswer(_i, idx);
        if (!mounted) return;
        QuizSound.fx(r.result.correct ? QuizSfx.ok : QuizSfx.bad);
        setState(() {
          _result = r.result;
          _busy = false;
          _mood = r.result.correct ? HawkMood.cheer : HawkMood.sad;
          if (r.result.correct) _correct++;
          if (r.finished) {
            _gain = r.gain;
            _finishedNow = true;
          }
        });
        return;
      } on QuizException catch (e) {
        if (e.code.contains('TOO_FAST') && attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 750));
          continue;
        }
        break;
      } catch (_) {
        break;
      }
    }
    if (!mounted) return;
    quizToast(context, context.tr('Une erreur est survenue, réessaie.'), error: true);
    setState(() {
      _busy = false;
      _selected = null;
    });
  }

  void _next() {
    QuizSound.fx(QuizSfx.tap);
    final d = _daily!;
    if (_finishedNow && _i >= d.questions.length - 1) {
      setState(() {
        _i = d.questions.length;
        _result = null;
        _selected = null;
        _mood = HawkMood.cheer;
      });
      QuizSound.fx(QuizSfx.win);
      _confetti.play();
      widget.onFinished?.call();
      return;
    }
    setState(() {
      _i++;
      _selected = null;
      _result = null;
      _mood = HawkMood.idle;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    if (_error) {
      return _frame(c, Row(children: [
        Expanded(child: Text(context.tr('Impossible de charger les questions du jour.'), style: TextStyle(color: c.textSecondary))),
        TextButton(onPressed: _load, child: Text(context.tr('Réessayer'))),
      ]));
    }
    final d = _daily;
    if (d == null) {
      return _frame(c, const SizedBox(height: 90, child: Center(child: CircularProgressIndicator(strokeWidth: 2.5))));
    }
    if (_i >= d.questions.length) return _summary(c, d);
    return _question(c, d);
  }

  Widget _frame(AppColors c, Widget child) {
    return Container(
      width: double.infinity,
      margin: widget.compact ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8) : EdgeInsets.zero,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.primary.withOpacity(0.5), width: 1.5),
      ),
      child: child,
    );
  }

  Widget _question(AppColors c, QuizDaily d) {
    final q = d.questions[_i];
    final equipped = QuizService.instance.state.value?.equipped['accessory'];
    final answered = _result != null;
    final last = _i == d.questions.length - 1;
    return _frame(
      c,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(6)),
            child: Text(
              context.tr('QUIZ DU JOUR').toUpperCase(),
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: c.onAccent, letterSpacing: 0.6),
            ),
          ),
          const Spacer(),
          for (var k = 0; k < d.questions.length; k++)
            Container(
              width: 22,
              height: 6,
              margin: const EdgeInsets.only(left: 4),
              decoration: BoxDecoration(
                color: k < _i || (k == _i && answered) ? c.primary : c.surfaceVariant,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          HawkMascot(mood: _mood, size: widget.compact ? 64 : 84, accessory: equipped),
          const SizedBox(width: 10),
          Expanded(
            child: QuizBubble(
              child: Text(q.q, style: TextStyle(fontSize: widget.compact ? 15 : 16, fontWeight: FontWeight.w800, height: 1.3, color: c.textPrimary)),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        for (var k = 0; k < q.o.length; k++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: QuizOption(
              letter: 'ABCD'[k],
              text: q.o[k],
              state: _state(k),
              onTap: answered || _busy ? null : () => _choose(k),
            ),
          ),
        if (answered) ...[
          const SizedBox(height: 2),
          Text(
            _result!.correct ? context.tr('Bravo !') : context.tr('Presque…'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _result!.correct ? c.primary : c.danger),
          ),
          const SizedBox(height: 4),
          Text(_result!.explanation, style: TextStyle(color: c.textPrimary, fontSize: 13, height: 1.35)),
          const SizedBox(height: 10),
          QuizChunkyButton(
            label: last ? context.tr('Voir mon score') : context.tr('Continuer'),
            color: _result!.correct ? c.primary : c.danger,
            textColor: _result!.correct ? c.onPrimary : Colors.white,
            onPressed: _next,
          ),
        ],
      ]),
    );
  }

  QuizOptionState _state(int k) {
    final r = _result;
    if (r == null) return _selected == k ? QuizOptionState.selected : QuizOptionState.idle;
    if (k == r.correctIndex) return QuizOptionState.correct;
    if (k == _selected) return QuizOptionState.wrong;
    return QuizOptionState.dimmed;
  }

  Widget _summary(AppColors c, QuizDaily d) {
    final equipped = QuizService.instance.state.value?.equipped['accessory'];
    final total = d.questions.length;
    return _frame(
      c,
      Stack(alignment: Alignment.topCenter, children: [
        Column(children: [
          Row(children: [
            HawkMascot(mood: HawkMood.cheer, size: widget.compact ? 70 : 96, accessory: equipped),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tr('Quiz du jour terminé !'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: c.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  context.tr('{c} bonnes réponses sur {n}', {'c': _correct, 'n': total}) +
                      (_gain > 0 ? '  ·  +$_gain ${context.tr('points')}' : ''),
                  style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(context.tr('Reviens demain pour 3 nouvelles questions.'), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
              ]),
            ),
          ]),
          if (widget.onContinue != null) ...[
            const SizedBox(height: 10),
            QuizChunkyButton(label: context.tr("Continuer l'aventure"), icon: Icons.explore_rounded, onPressed: widget.onContinue),
          ],
        ]),
        ConfettiWidget(
          confettiController: _confetti,
          blastDirectionality: BlastDirectionality.explosive,
          emissionFrequency: 0.05,
          numberOfParticles: 16,
          gravity: 0.3,
          colors: [c.primary, c.accent, c.warning, c.info],
        ),
      ]),
    );
  }
}

/// Page entière des questions du jour.
class QuizDailyPage extends StatelessWidget {
  const QuizDailyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        title: Text(context.tr('Quiz du jour'), style: TextStyle(fontWeight: FontWeight.w900, color: c.textPrimary)),
        iconTheme: IconThemeData(color: c.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: QuizDailyPlayer(onContinue: () => Navigator.pop(context, true)),
      ),
    );
  }
}
