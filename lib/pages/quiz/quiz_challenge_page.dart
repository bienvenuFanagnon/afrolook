import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
import 'quiz_leaderboard_page.dart';
import 'widgets/hawk_mascot.dart';
import 'widgets/quiz_loading.dart';
import 'widgets/quiz_pace.dart';
import 'widgets/quiz_dialogs.dart';
import 'widgets/quiz_widgets.dart';

enum _Phase { loading, error, intro, play, end }

/// Grand Défi : 15 questions d'affilée, de plus en plus difficiles.
/// Paliers garantis à la 5e et à la 10e bonne réponse, deux jokers, un minuteur par question.
/// Tout est décidé par le serveur ; les points gagnés ne servent qu'au classement et à la boutique.
class QuizChallengePage extends StatefulWidget {
  const QuizChallengePage({super.key});

  @override
  State<QuizChallengePage> createState() => _QuizChallengePageState();
}

class _QuizChallengePageState extends State<QuizChallengePage> {
  static const _steps = 15;
  static const _safe = [4, 9];

  _Phase _phase = _Phase.loading;
  QuizChalReply? _info;
  QuizChalQuestion? _q;
  QuizChalReply? _fb; // réponse du serveur à la dernière réponse donnée
  QuizChalReply? _end;
  int? _selected;
  bool _busy = false;
  double _left = 30;
  Timer? _timer;
  final Stopwatch _watch = Stopwatch();
  HawkMood _mood = HawkMood.idle;
  final ConfettiController _confetti = ConfettiController(duration: const Duration(seconds: 3));

  @override
  void initState() {
    super.initState();
    QuizVoice.instance.load();
    _load();
  }

  @override
  void dispose() {
    QuizVoice.instance.stop();
    _timer?.cancel();
    _confetti.dispose();
    super.dispose();
  }

  List<int> get _prizes => (_info?.prizes.length ?? 0) == _steps ? _info!.prizes : const [10, 20, 30, 50, 100, 150, 200, 300, 400, 600, 800, 1000, 1500, 2000, 3000];

  Future<void> _load() async {
    setState(() => _phase = _Phase.loading);
    try {
      await QuizService.instance.loadConfig();
      final i = await QuizService.instance.challengeInfo();
      if (!mounted) return;
      setState(() {
        _info = i;
        _phase = _Phase.intro;
      });
    } on QuizException catch (e) {
      if (!mounted) return;
      if (e.code.contains('QUIZ_OFF')) {
        quizToast(context, context.tr('Le quiz est indisponible pour le moment.'), error: true);
        Navigator.pop(context);
        return;
      }
      setState(() => _phase = _Phase.error);
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.error);
    }
  }

  // ── Minuteur ──

  void _startTimer(int seconds, {double elapsed = 0}) {
    _timer?.cancel();
    _watch
      ..reset()
      ..start();
    _left = seconds - elapsed;
    _timer = Timer.periodic(const Duration(milliseconds: 200), (t) {
      if (!mounted) return;
      final left = seconds - elapsed - _watch.elapsedMilliseconds / 1000;
      if (left <= 0) {
        t.cancel();
        setState(() => _left = 0);
        if (_selected == null && !_busy) _submit(-1);
        return;
      }
      final changed = left.ceil() != _left.ceil();
      setState(() => _left = left);
      if (changed && left <= 5) QuizSound.fx(QuizSfx.tap);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _watch.stop();
  }

  // ── Parcours ──

  void _show(QuizChalQuestion q, {bool restartTimer = true}) {
    setState(() {
      _q = q;
      _selected = null;
      _fb = null;
      _busy = false;
      _mood = HawkMood.think;
      _phase = _Phase.play;
    });
    if (restartTimer) {
      _startTimer(_info?.seconds ?? 30);
      _read(q);
    }
  }

  /// Lecture à voix haute de la question (les réponses retirées par le 50/50 ne sont pas lues).
  void _read(QuizChalQuestion q) {
    QuizVoice.instance.speakQuestion(q.q, [for (var k = 0; k < q.o.length; k++) q.hide.contains(k) ? null : q.o[k]]);
  }

  Future<bool> _watchAd() async {
    final ok = await AdmobService.watchRewarded(userId: QuizService.instance.uid);
    if (!ok && mounted) {
      quizToast(context, context.tr("La pub n'est pas disponible pour le moment. Réessaie dans un instant."), error: true);
    }
    return ok;
  }

  String _errorText(Object e) {
    final code = e is QuizException ? e.code : '';
    if (code.contains('NO_ATTEMPTS')) return context.tr("Tu n'as plus de partie pour aujourd'hui.");
    if (code.contains('ALREADY_ACTIVE')) return context.tr('Une partie est déjà en cours.');
    return context.tr('Connexion impossible. Vérifie ta connexion.');
  }

  Future<void> _start({bool extra = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (extra && !await _watchAd()) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final r = await QuizService.instance.challengeStart(extra: extra);
      if (!mounted) return;
      QuizSound.fx(QuizSfx.hi);
      _info = r;
      _show(r.question!);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      quizToast(context, _errorText(e), error: true);
      if (e is QuizException && e.code.contains('ALREADY_ACTIVE')) _load();
    }
  }

  Future<void> _resume() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final r = await QuizService.instance.challengeResume();
      if (!mounted) return;
      _info = r;
      _show(r.question!);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _load();
    }
  }

  Future<void> _submit(int choice) async {
    final q = _q;
    if (q == null || _busy || _selected != null) return;
    _stopTimer();
    QuizVoice.instance.stop();
    if (choice >= 0) QuizSound.fx(QuizSfx.tap);
    setState(() {
      _selected = choice;
      _busy = true;
    });
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final r = await QuizService.instance.challengeAnswer(choice);
        if (!mounted) return;
        QuizSound.fx(r.correct ? QuizSfx.ok : QuizSfx.bad);
        setState(() {
          _fb = r;
          _busy = false;
          _mood = r.correct ? HawkMood.cheer : HawkMood.sad;
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
    quizToast(context, context.tr('Connexion impossible. Vérifie ta connexion.'), error: true);
    // La partie reste ouverte côté serveur : on la reprend.
    setState(() {
      _busy = false;
      _selected = null;
    });
    _resume();
  }

  Future<void> _afterFeedback() async {
    final r = _fb;
    if (r == null) return;
    QuizSound.fx(QuizSfx.tap);
    if (r.question != null) {
      _show(r.question!);
    } else if (r.pending) {
      await _rescueSheet(r);
    } else {
      _finish(r);
    }
  }

  void _finish(QuizChalReply r) {
    _stopTimer();
    setState(() {
      _end = r;
      _phase = _Phase.end;
      _mood = (r.win || r.gain > 0) ? HawkMood.cheer : HawkMood.sad;
    });
    if (r.win) {
      QuizSound.fx(QuizSfx.win);
      _confetti.play();
    } else if (r.gain > 0) {
      QuizSound.fx(QuizSfx.up);
      _confetti.play();
    }
  }

  Future<void> _rescueSheet(QuizChalReply r) async {
    final c = AppColors.of(context);
    final canWatch = quizCanOfferRewarded(context);
    final choice = await showModalBottomSheet<String>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        decoration: BoxDecoration(color: c.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const HawkMascot(mood: HawkMood.sad, size: 90),
            const SizedBox(height: 6),
            Text(ctx.tr('Oh non, tu es tombé !'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: c.textPrimary)),
            const SizedBox(height: 4),
            Text(
              ctx.tr('Tu peux continuer une seule fois avec une nouvelle question, ou t\'arrêter ici avec {n} points.', {'n': r.floor}),
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 16),
            if (canWatch)
              QuizChunkyButton(
                label: ctx.tr('Seconde chance · une pub'),
                icon: Icons.play_circle_rounded,
                color: c.accent,
                textColor: c.onAccent,
                onPressed: () => Navigator.pop(ctx, 'rescue'),
              ),
            const SizedBox(height: 10),
            QuizChunkyButton(
              label: ctx.tr('M\'arrêter ici'),
              color: c.surfaceVariant,
              textColor: c.textPrimary,
              onPressed: () => Navigator.pop(ctx, 'stop'),
            ),
          ]),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      if (choice == 'rescue') {
        if (!await _watchAd()) {
          if (!mounted) return;
          setState(() => _busy = false);
          await _rescueSheet(r);
          return;
        }
        final n = await QuizService.instance.challengeRescue();
        if (!mounted) return;
        QuizSound.fx(QuizSfx.up);
        _info = n;
        _show(n.question!);
      } else {
        final n = await QuizService.instance.challengeGiveUp();
        if (!mounted) return;
        _finish(n);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      quizToast(context, _errorText(e), error: true);
      _load();
    }
  }

  Future<void> _joker(bool fifty) async {
    final q = _q;
    if (q == null || _busy || _selected != null) return;
    if (fifty ? q.j50 : q.swap) return;
    QuizSound.fx(QuizSfx.hi);
    setState(() => _busy = true);
    try {
      final r = fifty ? await QuizService.instance.challengeFiftyFifty() : await QuizService.instance.challengeSwap();
      if (!mounted) return;
      if (fifty) {
        setState(() {
          _q = r.question;
          _busy = false;
        });
      } else {
        _show(r.question!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      quizToast(context, _errorText(e), error: true);
    }
  }

  Future<void> _cashOut() async {
    final q = _q;
    if (q == null || _busy || _selected != null || q.step == 0) return;
    final c = AppColors.of(context);
    final keep = _prizes[q.step - 1];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(ctx.tr('T\'arrêter maintenant ?'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900)),
        content: Text(ctx.tr('Tu repars avec {n} points.', {'n': keep}), style: TextStyle(color: c.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('Continuer'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('M\'arrêter ici'), style: TextStyle(color: c.primary, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final r = await QuizService.instance.challengeCashOut();
      if (!mounted) return;
      _finish(r);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      quizToast(context, _errorText(e), error: true);
    }
  }

  Future<bool> _confirmQuit() async {
    if (_phase != _Phase.play) return true;
    final c = AppColors.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(ctx.tr('Quitter le défi ?'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900)),
        content: Text(ctx.tr('Le temps continue de tourner : si tu ne reviens pas vite, la question sera ratée.'), style: TextStyle(color: c.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('Continuer'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.tr('Quitter'), style: TextStyle(color: c.danger))),
        ],
      ),
    );
    return ok == true;
  }

  void _leave() {
    if (_end != null && (_end!.gain > 0 || _end!.reached >= 5)) {
      quizMaybeInterstitial(context, () {
        if (mounted) Navigator.pop(context, true);
      });
    } else {
      Navigator.pop(context, true);
    }
  }

  // ── Affichage ──

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return WillPopScope(
      onWillPop: _confirmQuit,
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.background,
          elevation: 0,
          iconTheme: IconThemeData(color: c.textPrimary),
          title: Text(context.tr('Grand Défi'), style: TextStyle(fontWeight: FontWeight.w900, color: c.textPrimary)),
        ),
        body: Stack(children: [
          switch (_phase) {
            _Phase.loading => const QuizLoading(kind: QuizLoadingKind.challenge),
            _Phase.error => _errorView(c),
            _Phase.intro => _intro(c),
            _Phase.play => _play(c),
            _Phase.end => _endView(c),
          },
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 28,
              shouldLoop: false,
              colors: [c.primary, c.accent, c.info, c.warning],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _errorView(AppColors c) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const HawkMascot(mood: HawkMood.sad, size: 110),
            const SizedBox(height: 10),
            Text(context.tr('Impossible de charger le défi.'), textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: Text(context.tr('Réessayer'))),
          ]),
        ),
      );

  Widget _ladder(AppColors c, int step) {
    return Row(
      children: [
        for (var k = 0; k < _steps; k++)
          Expanded(
            child: Container(
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: k < step ? c.primary : (k == step ? c.accent : c.surfaceVariant),
                borderRadius: BorderRadius.circular(4),
                border: _safe.contains(k) ? Border.all(color: c.accent, width: 1.5) : null,
              ),
            ),
          ),
      ],
    );
  }

  Widget _intro(AppColors c) {
    final i = _info!;
    final active = i.active;
    final free = i.attemptsLeft;
    final canExtra = free <= 0 && i.extraLeft > 0 && quizCanOfferRewarded(context);
    final prizes = _prizes;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [c.accent.withOpacity(0.28), c.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.accent, width: 1.5),
        ),
        child: Row(children: [
          HawkMascot(mood: HawkMood.wave, size: 88, accessory: QuizService.instance.state.value?.equipped['accessory']),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(context.tr('15 bonnes réponses d\'affilée'), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: c.textPrimary)),
              const SizedBox(height: 4),
              Text(
                context.tr('Les questions deviennent de plus en plus difficiles. Une erreur et tu retombes au dernier palier.'),
                style: TextStyle(color: c.textSecondary, height: 1.3, fontSize: 13),
              ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        QuizPill(icon: Icons.timer_rounded, label: context.tr('{n} s par question', {'n': i.seconds}), color: c.info),
        QuizPill(icon: Icons.shield_rounded, label: context.tr('Paliers : 5 et 10'), color: c.accent),
        QuizPill(icon: Icons.emoji_events_rounded, label: context.tr('Ton record : {n}/15', {'n': i.best}), color: c.primary),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.border, width: 1.5)),
        child: Column(children: [
          for (var k = _steps - 1; k >= 0; k--)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              margin: const EdgeInsets.symmetric(vertical: 1.5),
              decoration: BoxDecoration(
                color: _safe.contains(k) ? c.accent.withOpacity(0.16) : (k == _steps - 1 ? c.primary.withOpacity(0.14) : Colors.transparent),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                SizedBox(width: 28, child: Text('${k + 1}', style: TextStyle(fontWeight: FontWeight.w900, color: c.textSecondary))),
                if (_safe.contains(k)) Icon(Icons.shield_rounded, size: 16, color: c.accent) else const SizedBox(width: 16),
                const Spacer(),
                Text('${prizes[k]}', style: TextStyle(fontWeight: FontWeight.w900, color: c.supportAccent, fontSize: 15)),
                const SizedBox(width: 3),
                Icon(Icons.star_rounded, size: 16, color: c.accent),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 8),
      Text(
        context.tr('Deux jokers : 50/50 et « Changer de question ». Les points ne valent pas d\'argent : ils servent au classement et à la boutique.'),
        style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.3),
      ),
      const SizedBox(height: 14),
      if (active)
        QuizChunkyButton(label: context.tr('Reprendre ma partie'), icon: Icons.play_arrow_rounded, loading: _busy, onPressed: _resume)
      else if (free > 0)
        QuizChunkyButton(label: context.tr('Lancer le défi'), icon: Icons.play_arrow_rounded, loading: _busy, onPressed: () => _start())
      else ...[
        Text(context.tr('Tu as joué ton défi du jour. Reviens demain !'),
            textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w800)),
        if (canExtra) ...[
          const SizedBox(height: 10),
          QuizChunkyButton(
            label: context.tr('Une partie de plus · une pub'),
            icon: Icons.play_circle_rounded,
            color: c.accent,
            textColor: c.onAccent,
            loading: _busy,
            onPressed: () => _start(extra: true),
          ),
        ],
      ],
    ]);
  }

  Widget _play(AppColors c) {
    final q = _q!;
    final fb = _fb;
    final answered = fb != null;
    final prizes = _prizes;
    final urgent = _left <= 5;
    final total = (_info?.seconds ?? 30).toDouble();
    final ratio = (_left / total).clamp(0.0, 1.0);

    QuizOptionState optState(int k) {
      if (q.hide.contains(k)) return QuizOptionState.dimmed;
      if (fb == null) return _selected == k ? QuizOptionState.selected : QuizOptionState.idle;
      if (k == fb.correctIndex) return QuizOptionState.correct;
      if (k == _selected) return QuizOptionState.wrong;
      return QuizOptionState.dimmed;
    }

    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
      Row(children: [
        QuizPill(icon: Icons.flag_rounded, label: context.tr('Question {n}/15', {'n': q.step + 1}), color: c.info),
        const Spacer(),
        QuizPill(icon: Icons.star_rounded, label: context.tr('{n} pts en jeu', {'n': prizes[q.step]}), color: c.accent),
        QuizVoiceButtons(onReplay: () => _read(q)),
      ]),
      const SizedBox(height: 10),
      _ladder(c, q.step),
      const SizedBox(height: 8),
      Row(children: [
        ValueListenableBuilder<bool>(
          valueListenable: QuizVoice.instance.speaking,
          builder: (_, speaking, __) => HawkMascot(
            mood: (!answered && _left <= 10) ? HawkMood.hurry : _mood,
            size: 64,
            accessory: QuizService.instance.state.value?.equipped['accessory'],
            speaking: speaking && !answered,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.timer_rounded, size: 18, color: urgent ? c.danger : c.textSecondary),
              const SizedBox(width: 4),
              Text(quizClock(_left.ceil().clamp(0, 99)),
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: urgent ? c.danger : c.textPrimary)),
              const Spacer(),
              Text(context.tr('Gain gardé : {n}', {'n': q.step > 0 ? prizes[q.step - 1] : 0}),
                  style: TextStyle(fontWeight: FontWeight.w800, color: c.textSecondary, fontSize: 12.5)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: answered ? 0 : ratio,
                minHeight: 9,
                backgroundColor: c.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(urgent ? c.danger : c.primary),
              ),
            ),
          ]),
        ),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.border, width: 1.5)),
        child: Text(q.q, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.35, color: c.textPrimary)),
      ),
      const SizedBox(height: 12),
      for (var k = 0; k < q.o.length; k++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: QuizOption(
            letter: 'ABCD'[k],
            text: q.o[k],
            state: optState(k),
            onTap: answered || _busy || q.hide.contains(k) ? null : () => _submit(k),
          ),
        ),
      if (!answered) ...[
        const SizedBox(height: 4),
        Row(children: [
          _jokerButton(c, Icons.content_cut_rounded, '50/50', q.j50, () => _joker(true)),
          const SizedBox(width: 8),
          _jokerButton(c, Icons.swap_horiz_rounded, context.tr('Changer'), q.swap, () => _joker(false)),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: q.step > 0 ? _cashOut : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: q.step > 0 ? c.primary : c.border, width: 1.5),
                ),
                child: Text(
                  context.tr('M\'arrêter ici'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w800, color: q.step > 0 ? c.primary : c.textSecondary, fontSize: 13),
                ),
              ),
            ),
          ),
        ]),
      ] else ...[
        if (fb.explanation.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: QuizBubble(child: Text(fb.explanation, style: TextStyle(color: c.textPrimary, height: 1.35, fontWeight: FontWeight.w600))),
          ),
        if (fb.late && !fb.correct)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(context.tr('Temps écoulé !'), style: TextStyle(color: c.danger, fontWeight: FontWeight.w900)),
          ),
        QuizChunkyButton(
          label: fb.correct && fb.win ? context.tr('Voir mon résultat') : context.tr('Suite'),
          icon: Icons.arrow_forward_rounded,
          color: fb.correct ? c.primary : c.danger,
          textColor: Colors.white,
          loading: _busy,
          onPressed: _afterFeedback,
        ),
      ],
    ]);
  }

  Widget _jokerButton(AppColors c, IconData icon, String label, bool used, VoidCallback onTap) {
    return GestureDetector(
      onTap: used || _busy ? null : onTap,
      child: Opacity(
        opacity: used ? 0.4 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: c.accent.withOpacity(0.16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.accent, width: 1.5),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18, color: c.accent),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontWeight: FontWeight.w900, color: c.textPrimary, fontSize: 13)),
          ]),
        ),
      ),
    );
  }

  Widget _endView(AppColors c) {
    final r = _end!;
    final user = context.read<UserAuthProvider>().loginUserData;
    final showAd = QuizService.instance.config.adsEnabled && AdGate.userSeesAds(user);
    final title = r.win
        ? context.tr('Champion !')
        : r.gain > 0
            ? context.tr('Bien joué !')
            : context.tr('Raté de peu');
    final capped = r.gain < r.prize;
    return ListView(padding: const EdgeInsets.all(20), children: [
      Center(child: HawkMascot(mood: _mood, size: 140, accessory: QuizService.instance.state.value?.equipped['accessory'])),
      const SizedBox(height: 6),
      Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: c.textPrimary)),
      const SizedBox(height: 4),
      Text(context.tr('Tu as réussi {n} questions sur 15.', {'n': r.reached}),
          textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [c.accent.withOpacity(0.28), c.surface]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.accent, width: 1.5),
        ),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.star_rounded, color: c.accent, size: 34),
            const SizedBox(width: 6),
            Text('+${r.gain}', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: c.textPrimary)),
          ]),
          Text(context.tr('points gagnés'), style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w700)),
          if (capped)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(context.tr('Limite de points du jour atteinte. Reviens demain !'),
                  textAlign: TextAlign.center, style: TextStyle(color: c.warning, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
        ]),
      ),
      const SizedBox(height: 16),
      QuizChunkyButton(label: context.tr('Terminer'), icon: Icons.check_rounded, onPressed: _leave),
      const SizedBox(height: 10),
      QuizChunkyButton(
        label: context.tr('Voir le classement'),
        icon: Icons.leaderboard_rounded,
        color: c.surfaceVariant,
        textColor: c.textPrimary,
        onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const QuizLeaderboardPage())),
      ),
      if (showAd) ...[
        const SizedBox(height: 14),
        AdSlot(kind: AdSlotKind.list, own: () => const AfrolookInlineAd(compact: true)),
      ],
    ]);
  }
}
