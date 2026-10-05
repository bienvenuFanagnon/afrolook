import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/etude/etude_service.dart';
import '../../services/quiz/quiz_sound.dart';
import '../../theme/app_colors.dart';
import '../quiz/widgets/hawk_mascot.dart';
import '../quiz/widgets/quiz_ads.dart';
import '../quiz/widgets/quiz_loading.dart';
import '../quiz/widgets/quiz_widgets.dart';
import 'etude_diploma_page.dart';

/// Une partie d'Étude : niveau d'un chapitre, composition de classe, examen ou attestation.
/// Se ferme avec `true` quand la partie a été terminée.
class EtudePlayPage extends StatefulWidget {
  const EtudePlayPage({super.key, required this.start});
  final EtudeStart start;

  @override
  State<EtudePlayPage> createState() => _EtudePlayPageState();
}

class _EtudePlayPageState extends State<EtudePlayPage> {
  int _i = 0;
  int? _selected;
  EtudeAnswerResult? _result;
  bool _busy = false;
  bool _finishing = false;
  EtudeFinish? _finish;
  HawkMood _mood = HawkMood.idle;
  Timer? _timer;
  late int _left = widget.start.seconds;
  final ConfettiController _confetti = ConfettiController(duration: const Duration(seconds: 3));

  EtudeStart get _st => widget.start;
  bool get _timed => _st.seconds > 0;

  @override
  void initState() {
    super.initState();
    if (_timed) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _finish != null) return;
        setState(() => _left = _left > 0 ? _left - 1 : 0);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _choose(int idx) async {
    if (_busy || _result != null) return;
    QuizSound.fx(QuizSfx.tap);
    setState(() {
      _selected = idx;
      _busy = true;
      _mood = HawkMood.think;
    });
    EtudeAnswerResult? res;
    for (var attempt = 0; attempt < 2 && res == null; attempt++) {
      try {
        res = await EtudeService.instance.answer(_st.sid, _i, idx);
      } on EtudeException catch (e) {
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
    if (res == null) {
      quizToast(context, context.tr('Une erreur est survenue, réessaie.'), error: true);
      setState(() {
        _busy = false;
        _selected = null;
        _mood = HawkMood.idle;
      });
      return;
    }
    final r = res;
    QuizSound.fx(r.correct ? QuizSfx.ok : QuizSfx.bad);
    setState(() {
      _result = r;
      _busy = false;
      _mood = r.correct ? HawkMood.cheer : HawkMood.sad;
    });
  }

  Future<void> _next() async {
    QuizSound.fx(QuizSfx.tap);
    if (_i < _st.questions.length - 1) {
      setState(() {
        _i++;
        _selected = null;
        _result = null;
        _mood = HawkMood.idle;
      });
      return;
    }
    setState(() => _finishing = true);
    try {
      final f = await EtudeService.instance.finish(_st.sid);
      if (!mounted) return;
      setState(() {
        _finish = f;
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

  Future<bool> _confirmQuit() async {
    if (_finish != null || (_i == 0 && _result == null)) return true;
    final c = AppColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(ctx.tr('Quitter cette partie ?'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
        content: Text(ctx.tr('Tu perdras ta progression dans cette partie.'), style: TextStyle(color: c.textSecondary)),
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
            _finish != null ? _resultView(c, _finish!) : _questionView(c),
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
                child: Container(color: c.background.withOpacity(0.7), alignment: Alignment.center, child: const QuizLoading(kind: QuizLoadingKind.saving)),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _questionView(AppColors c) {
    final q = _st.questions[_i];
    final res = _result;
    final total = _st.questions.length;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 16, 0),
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
              child: LinearProgressIndicator(
                value: (_i + (res != null ? 1 : 0)) / total,
                minHeight: 12,
                backgroundColor: c.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(c.primary),
              ),
            ),
          ),
          if (_timed) ...[
            const SizedBox(width: 12),
            Icon(Icons.timer_outlined, size: 18, color: _left < 60 ? c.danger : c.textSecondary),
            const SizedBox(width: 3),
            Text(quizClock(_left), style: TextStyle(fontWeight: FontWeight.w800, color: _left < 60 ? c.danger : c.textPrimary)),
          ],
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        child: Row(children: [
          Expanded(child: Text(_st.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w700, fontSize: 12))),
          Text('${_i + 1}/$total', style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
        ]),
      ),
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            HawkMascot(mood: _mood, size: 84),
            const SizedBox(width: 10),
            Expanded(child: QuizBubble(child: Text(q.q, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 16, height: 1.35)))),
          ]),
          const SizedBox(height: 14),
          for (var k = 0; k < q.o.length; k++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: QuizOption(
                letter: String.fromCharCode(65 + k),
                text: q.o[k],
                checking: _busy && _selected == k,
                state: res == null
                    ? (_selected == k ? QuizOptionState.selected : QuizOptionState.idle)
                    : k == res.correctIndex
                        ? QuizOptionState.correct
                        : (k == _selected ? QuizOptionState.wrong : QuizOptionState.dimmed),
                onTap: res == null && !_busy ? () => _choose(k) : null,
              ),
            ),
          if (res != null) _feedback(c, res),
        ]),
      ),
      if (res != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: QuizChunkyButton(
            label: context.tr(_i < total - 1 ? 'Continuer' : 'Terminer'),
            color: res.correct ? c.primary : c.danger,
            textColor: res.correct ? c.onPrimary : Colors.white,
            onPressed: _next,
          ),
        ),
      const QuizAdBanner(),
    ]);
  }

  Widget _feedback(AppColors c, EtudeAnswerResult r) {
    final col = r.correct ? c.primary : c.danger;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: col.withOpacity(0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: col.withOpacity(0.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(r.correct ? context.tr('Bonne réponse !') : context.tr('Pas tout à fait'), style: TextStyle(color: col, fontWeight: FontWeight.w900, fontSize: 16)),
        if (r.explanation.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(r.explanation, style: TextStyle(color: c.textPrimary, fontSize: 14, height: 1.4)),
        ],
      ]),
    );
  }

  String _resultTitle(EtudeFinish f) {
    if (f.diploma != null) return context.tr('Félicitations, diplôme obtenu !');
    if (f.classValidated.isNotEmpty) return context.tr('Classe validée !');
    if (f.chapterFinished) return context.tr('Chapitre terminé !');
    return f.pass ? context.tr('Réussi !') : context.tr('Pas encore…');
  }

  Widget _resultView(AppColors c, EtudeFinish f) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const Spacer(),
        HawkMascot(mood: _mood, size: 150),
        const SizedBox(height: 10),
        Text(_resultTitle(f), textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: c.textPrimary)),
        const SizedBox(height: 8),
        Text(
          context.tr('{a} bonnes réponses sur {b} ({p} %)', {'a': '${f.correct}', 'b': '${f.total}', 'p': '${f.pct}'}),
          textAlign: TextAlign.center,
          style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w700, fontSize: 15),
        ),
        if (!f.pass) ...[
          const SizedBox(height: 4),
          Text(context.tr('Il faut au moins {n} % pour réussir.', {'n': '${f.need}'}), textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary)),
        ],
        if (f.xp > 0) ...[
          const SizedBox(height: 12),
          QuizPill(icon: Icons.bolt_rounded, label: '+${f.xp} XP', color: c.accent),
        ],
        const Spacer(),
        if (f.diploma != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: QuizChunkyButton(
              label: context.tr('Voir mon diplôme'),
              icon: Icons.workspace_premium_rounded,
              color: c.accent,
              textColor: c.onAccent,
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => EtudeDiplomaPage(diploma: f.diploma!))),
            ),
          ),
        QuizChunkyButton(
          label: context.tr('Continuer'),
          color: c.primary,
          textColor: c.onPrimary,
          onPressed: () {
            if (f.pass && widget.start.kind == 'level') {
              levelEndInterstitial(context, prefix: 'etude', every: 3, maxPerDay: 6, then: () {
                if (mounted) Navigator.pop(context, true);
              });
            } else {
              Navigator.pop(context, true);
            }
          },
        ),
        const QuizAdBanner(minHeight: 640),
      ]),
    );
  }
}
