import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/tr.dart';
import '../../../services/quiz/quiz_sound.dart';
import '../../../theme/app_colors.dart';
import 'hawk_mascot.dart';

/// Rythme d'une question : compte le temps (sans rien retirer au joueur) et fait
/// réagir l'épervier : il s'impatiente quand on traîne, et félicite les réponses « éclair » (rapides et justes).
class QuizPace extends ChangeNotifier {
  QuizPace({this.seconds = 25, this.hurryAt = 15, this.fastWithin = 10});

  final int seconds, hurryAt, fastWithin;

  /// Réponses éclair (justes, données en moins de [fastWithin] secondes) depuis le début de la partie.
  int fast = 0;

  /// Vrai juste après une réponse éclair (pour l'étincelle près de l'épervier).
  bool flash = false;

  Timer? _timer;
  final Stopwatch _watch = Stopwatch();
  bool _running = false;
  int _lastShown = -1;

  double get elapsed => _watch.elapsedMilliseconds / 1000;
  double get left => (seconds - elapsed).clamp(0, seconds).toDouble();
  bool get running => _running;
  bool get hurry => _running && elapsed >= hurryAt;
  bool get late => _running && elapsed >= seconds;

  /// Nouvelle question : relance le chrono.
  void start() {
    _timer?.cancel();
    flash = false;
    _watch
      ..reset()
      ..start();
    _running = true;
    _lastShown = -1;
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final shown = left.ceil();
      // On ne réveille l'écran que quand quelque chose change (seconde, humeur)
      if (shown != _lastShown) {
        _lastShown = shown;
        notifyListeners();
      }
    });
    notifyListeners();
  }

  /// Le joueur a répondu : arrête la voix et le chrono. Renvoie vrai si la réponse juste était assez rapide.
  bool answered({required bool correct}) {
    final quick = correct && elapsed <= fastWithin;
    stopTimer();
    if (quick) {
      fast++;
      flash = true;
      QuizSound.fx(QuizSfx.up);
    }
    notifyListeners();
    return quick;
  }

  void stopTimer() {
    _timer?.cancel();
    _watch.stop();
    _running = false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Barre de temps douce sous la question : verte, puis orange, puis rouge, avec des encouragements à répondre vite.
class QuizPaceBar extends StatelessWidget {
  const QuizPaceBar({super.key, required this.pace});
  final QuizPace pace;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ListenableBuilder(
      listenable: pace,
      builder: (_, __) {
        final ratio = pace.seconds == 0 ? 0.0 : pace.left / pace.seconds;
        final color = pace.late ? c.danger : pace.hurry ? c.warning : c.primary;
        final String msg;
        if (!pace.running) {
          msg = '';
        } else if (pace.late) {
          msg = context.tr('Tu dors ? Réponds !');
        } else if (pace.hurry) {
          msg = context.tr('Vite, le temps passe !');
        } else if (pace.elapsed <= pace.fastWithin) {
          msg = context.tr('Réponds vite : {n} s pour un éclair !', {'n': (pace.fastWithin - pace.elapsed).ceil()});
        } else {
          msg = context.tr('Plus que quelques secondes pour l\'éclair…');
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pace.running ? ratio : 0,
              minHeight: 6,
              backgroundColor: c.surfaceVariant,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          if (msg.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                Icon(Icons.bolt_rounded, size: 15, color: color),
                const SizedBox(width: 3),
                Flexible(child: Text(msg, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color))),
              ]),
            ),
        ]);
      },
    );
  }
}

/// Épervier de la question : s'agite quand le joueur traîne, étincelle sur une réponse éclair.
class QuizPaceHawk extends StatelessWidget {
  const QuizPaceHawk({super.key, required this.pace, required this.mood, required this.answered, this.size = 92, this.accessory});
  final QuizPace pace;
  final HawkMood mood;
  final bool answered;
  final double size;
  final String? accessory;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ListenableBuilder(
      listenable: pace,
      builder: (_, __) {
        final m = (!answered && pace.hurry) ? HawkMood.hurry : mood;
        return Stack(clipBehavior: Clip.none, children: [
          HawkMascot(mood: m, size: size, accessory: accessory),
          if (pace.flash && answered)
            Positioned(
              top: -4,
              right: -10,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (_, v, child) => Transform.scale(scale: v, child: child),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(999)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.bolt_rounded, size: 15, color: c.onAccent),
                    Text(context.tr('Éclair !'), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: c.onAccent)),
                  ]),
                ),
              ),
            ),
        ]);
      },
    );
  }
}
