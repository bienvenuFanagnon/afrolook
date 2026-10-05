import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/tr.dart';
import '../../../services/quiz/quiz_sound.dart';
import '../../../services/quiz/quiz_voice.dart';
import '../../../theme/app_colors.dart';
import 'hawk_mascot.dart';
import 'quiz_widgets.dart';

/// Rythme d'une question : lit la question à voix haute, compte le temps (sans rien retirer au joueur) et fait
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

  /// Nouvelle question : relance le chrono et la lecture à voix haute si [read] est vrai.
  void start({String? question, List<String?> options = const [], bool read = true}) {
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
    if (read && question != null) QuizVoice.instance.speakQuestion(question, options);
    notifyListeners();
  }

  /// Le joueur a répondu : arrête la voix et le chrono. Renvoie vrai si la réponse juste était assez rapide.
  bool answered({required bool correct}) {
    QuizVoice.instance.stop();
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
    QuizVoice.instance.stop();
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

/// Épervier de la question : bec qui bouge quand la voix parle, s'agite quand le joueur traîne, étincelle sur une réponse éclair.
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
      listenable: Listenable.merge([pace, QuizVoice.instance.speaking]),
      builder: (_, __) {
        final m = (!answered && pace.hurry) ? HawkMood.hurry : mood;
        return Stack(clipBehavior: Clip.none, children: [
          HawkMascot(mood: m, size: size, accessory: accessory, speaking: QuizVoice.instance.speaking.value && !answered),
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

/// Boutons voix : réécouter la question et ouvrir les réglages (activer, voix de femme ou d'homme).
class QuizVoiceButtons extends StatelessWidget {
  const QuizVoiceButtons({super.key, required this.onReplay});
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: QuizVoice.instance.settingsVersion,
      builder: (_, __, ___) {
        final on = QuizVoice.instance.enabled;
        return Row(mainAxisSize: MainAxisSize.min, children: [
          if (on)
            GestureDetector(
              onTap: onReplay,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: c.info.withOpacity(0.14), borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.volume_up_rounded, size: 16, color: c.info),
                  const SizedBox(width: 4),
                  Text(context.tr('Réécouter'), style: TextStyle(color: c.info, fontWeight: FontWeight.w800, fontSize: 12)),
                ]),
              ),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: context.tr('Voix'),
            icon: Icon(on ? Icons.record_voice_over_rounded : Icons.voice_over_off_rounded, color: on ? c.primary : c.textSecondary),
            onPressed: () => showQuizVoiceSheet(context),
          ),
        ]);
      },
    );
  }
}

/// Réglages de la voix : lecture des questions oui/non, voix de femme (par défaut) ou d'homme, écoute d'un exemple.
Future<void> showQuizVoiceSheet(BuildContext context) async {
  await QuizVoice.instance.load();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _VoiceSheet(),
  );
  QuizVoice.instance.stop();
}

class _VoiceSheet extends StatelessWidget {
  const _VoiceSheet();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final v = QuizVoice.instance;
    return ValueListenableBuilder<int>(
      valueListenable: v.settingsVersion,
      builder: (ctx, _, __) {
        Widget choice(String g, String label, IconData icon) {
          final sel = v.gender == g;
          return Expanded(
            child: GestureDetector(
              onTap: () async {
                await v.setGender(g);
                v.speakSample();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: sel ? c.primary.withOpacity(0.16) : c.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: sel ? c.primary : c.border, width: 2),
                ),
                child: Column(children: [
                  Icon(icon, color: sel ? c.primary : c.textSecondary, size: 28),
                  const SizedBox(height: 4),
                  Text(label, style: TextStyle(fontWeight: FontWeight.w900, color: sel ? c.primary : c.textPrimary)),
                ]),
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: BoxDecoration(color: c.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(26))),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                ValueListenableBuilder<bool>(
                  valueListenable: v.speaking,
                  builder: (_, sp, __) => HawkMascot(size: 64, mood: HawkMood.wave, speaking: sp),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(ctx.tr('Voix de l\'épervier'), style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: c.textPrimary))),
              ]),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: c.primary,
                title: Text(ctx.tr('Lire les questions à voix haute'), style: TextStyle(fontWeight: FontWeight.w800, color: c.textPrimary)),
                value: v.enabled,
                onChanged: (on) => v.setEnabled(on),
              ),
              if (v.enabled) ...[
                const SizedBox(height: 4),
                Row(children: [
                  choice('f', ctx.tr('Voix de femme'), Icons.face_3_rounded),
                  const SizedBox(width: 12),
                  choice('m', ctx.tr('Voix d\'homme'), Icons.face_6_rounded),
                ]),
                const SizedBox(height: 12),
                QuizChunkyButton(
                  label: ctx.tr('Écouter un exemple'),
                  icon: Icons.volume_up_rounded,
                  color: c.surfaceVariant,
                  textColor: c.textPrimary,
                  onPressed: () => v.speakSample(),
                ),
              ],
            ]),
          ),
        );
      },
    );
  }
}
