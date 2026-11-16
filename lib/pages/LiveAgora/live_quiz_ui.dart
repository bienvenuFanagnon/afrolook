import 'dart:async';
import 'dart:math' as math;

import 'package:afrotok/l10n/tr.dart';
import 'live_game_ui.dart';
import 'package:afrotok/services/coin_checkout.dart';
import 'package:afrotok/services/quiz/quiz_sound.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Quiz à cagnotte des lives, nouvelle version (maquette validée le 15/11/2026) : style « salle de jeu », une cagnotte par question,
/// 3 à 20 gagnants, jusqu'à 10 choix dont plusieurs justes, chargement au toucher, révélation avec pluie de pièces, sons, fond illustré.
/// Couleurs : jaune en fond seulement (texte foncé dessus), ambre pour les textes d'accent, vert pour les bonnes réponses.

const _gold = Color(0xFFFFE14D);
const _onGold = Color(0xFF3A2C00);
const _amber = Color(0xFFF9A825);
const _green = Color(0xFF2ECC71);
const _onGreen = Color(0xFF062B15);
const _red = Color(0xFFFF6B6F);
const _ink = Color(0xFF120D1D);

/// Couleurs des fenêtres et réglages du quiz (création du live, question, lancement, questions Afrolook, classement) : elles suivent le mode clair
/// ou sombre de l'application (16/11/2026). Le panneau posé sur la vidéo du live, lui, reste sombre.
class _QP {
  const _QP._(this.isDark);
  factory _QP.of(BuildContext context) => _QP._(Theme.of(context).brightness == Brightness.dark);

  final bool isDark;
  Color get sheet => isDark ? const Color(0xFF1B1430) : Colors.white;
  Color get sheetTop => isDark ? const Color(0xFF26223A) : const Color(0xFFF6F3FB);
  Color get sheetBottom => isDark ? const Color(0xFF15121F) : Colors.white;
  Color get box => isDark ? const Color(0xFF221A3A) : const Color(0xFFF6F3FB);
  Color get boxBorder => isDark ? const Color(0xFF3A2F5C) : const Color(0xFFE4DDF0);
  Color get text => isDark ? Colors.white : const Color(0xFF121212);
  Color get text2 => isDark ? Colors.white70 : const Color(0xFF3D3D38);
  Color get text3 => isDark ? Colors.white60 : const Color(0xFF63635E);
  Color get icon => isDark ? Colors.white54 : const Color(0xFF6B6B66);
  Color get faint => isDark ? Colors.white38 : const Color(0xFF8C8C87);
  Color get line => isDark ? Colors.white24 : const Color(0xFFCFCAD9);
  Color get line2 => isDark ? Colors.white12 : const Color(0xFFE5E5E0);
  Color get fill => isDark ? Colors.white.withOpacity(.06) : Colors.black.withOpacity(.04);
  /// Texte ou icône « jaune » : ambre foncé en mode clair (règle de lisibilité du 02/11/2026).
  Color get amber => isDark ? _amber : const Color(0xFF8A6500);
  Color get goldText => isDark ? _gold : const Color(0xFF8A6500);
  Color get red => isDark ? _red : const Color(0xFFD92D3A);
  Color get dangerText => isDark ? const Color(0xFFFFD3D4) : const Color(0xFFB3261E);
  Color get greenText => isDark ? _green : const Color(0xFF158246);
}

/// Coût payé par l'hôte pour faire gagner `pot` pièces (commission comprise, jamais affichée : on montre seulement ce coût). Même calcul que le serveur.
int quizCost(int pot) => pot <= 0 ? 0 : (pot * 10 + 8) ~/ 9;

/// Parts dégressives entre les N gagnants (poids N, N-1, … 1). Même calcul que le serveur.
List<int> quizSplit(int pot, int winners) {
  final w = [for (var i = winners; i >= 1; i--) i];
  final sum = w.fold<int>(0, (a, b) => a + b);
  return [for (final x in w) pot * x ~/ sum];
}

/// Temps proposés pour une question (15 s à 30 min) et sommes à gagner proposées.
const List<int> kQuizTimeChoices = [15, 30, 60, 120, 300, 600, 900, 1800];
const List<int> kQuizPotChoices = [0, 50, 100, 250, 500, 1000];

/// Durée d'un quiz enchaîné : chaque question dure son temps + 6 s de résultat + 5 s de préparation (comme le serveur).
int quizListSeconds(Iterable<int> questionSeconds) => questionSeconds.fold<int>(0, (a, s) => a + s + 11);

String quizDurationLabel(BuildContext context, int s) => s < 60 ? context.tr('{n} s', {'n': s}) : context.tr('{n} min', {'n': (s + 59) ~/ 60});

/// Durée du quiz face au temps qui reste au live : avertissement si le live s'arrêterait avant la fin du quiz.
Widget quizDurationNote(BuildContext context, int quizSeconds, int? liveSecondsLeft) {
  if (quizSeconds <= 0) return const SizedBox.shrink();
  final p = _QP.of(context);
  final over = liveSecondsLeft != null && quizSeconds > liveSecondsLeft;
  final text = liveSecondsLeft == null
      ? context.tr('Durée du quiz : environ {d}.', {'d': quizDurationLabel(context, quizSeconds)})
      : over
          ? context.tr('Ce quiz dure environ {d}, mais il ne reste que {r} au live : le live s\'arrêterait avant la fin. Mets moins de questions, des temps plus courts, ou prolonge le live.',
              {'d': quizDurationLabel(context, quizSeconds), 'r': quizDurationLabel(context, liveSecondsLeft)})
          : context.tr('Durée du quiz : environ {d} (il reste {r} au live).', {'d': quizDurationLabel(context, quizSeconds), 'r': quizDurationLabel(context, liveSecondsLeft)});
  return Container(
    key: ValueKey(over ? 'quiz_duration_over' : 'quiz_duration_ok'),
    margin: const EdgeInsets.only(top: 6, bottom: 4),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(color: over ? _red.withOpacity(.16) : p.fill, borderRadius: BorderRadius.circular(12), border: Border.all(color: over ? _red.withOpacity(.6) : p.line2)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(over ? Icons.warning_amber_rounded : Icons.schedule_rounded, size: 17, color: over ? p.red : p.text3),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: TextStyle(color: over ? p.dangerText : p.text2, fontSize: 12, height: 1.35, fontWeight: over ? FontWeight.w700 : FontWeight.w500))),
    ]),
  );
}

String quizTimeLabel(BuildContext context, int s) => s < 60 ? context.tr('{n} s', {'n': s}) : context.tr('{n} min', {'n': s ~/ 60});

/// Une question du quiz : texte, 2 à 10 choix, une ou plusieurs bonnes réponses, temps et somme à gagner.
class QuizQ {
  QuizQ({required this.text, required this.options, required this.correct, required this.seconds, required this.pot});

  String text;
  List<String> options;
  Set<int> correct;
  int seconds;
  int pot;

  int get cost => quizCost(pot);

  Map<String, dynamic> toJson() => {'text': text, 'options': options, 'correct': (correct.toList()..sort()), 'seconds': seconds, 'pot': pot};

  static QuizQ? fromJson(Object? j) {
    if (j is! Map) return null;
    final opts = [for (final o in (j['options'] as List? ?? const [])) '$o'];
    final c = j['correct'];
    final correct = <int>{if (c is num) c.toInt(), if (c is List) for (final x in c) if (x is num) x.toInt()};
    if (opts.length < 2 || correct.isEmpty) return null;
    return QuizQ(text: '${j['text'] ?? ''}', options: opts, correct: correct, seconds: (j['seconds'] as num?)?.toInt() ?? 15, pot: (j['pot'] as num?)?.toInt() ?? 0);
  }

  /// Message d'erreur en clair, ou `null` si la question est jouable (même règle que le serveur).
  String? problem(BuildContext context) {
    if (text.trim().length < 3) return context.tr('Écris la question.');
    final filled = options.where((o) => o.trim().isNotEmpty).length;
    if (filled < 2 || filled != options.length) return context.tr('Remplis entre 2 et 10 choix.');
    if (correct.isEmpty) return context.tr('Coche au moins une bonne réponse.');
    if (correct.length >= options.length) return context.tr('Il faut au moins une mauvaise réponse.');
    return null;
  }
}

/// Réglages de base du quiz, choisis à la création du live (pour tous) ; la liste préparée est réservée au Gold.
class QuizSettings {
  /// Par défaut sans cagnotte : les joueurs gagnent des points et le classement final désigne les gagnants (prix remis en personne).
  QuizSettings({this.winners = 3, this.seconds = 15, this.pot = 0, this.theme = 'scene', List<QuizQ>? questions}) : questions = questions ?? [];

  /// Récompense : prix remis en personne (classement seul, aucune pièce) ou cagnotte en pièces.
  bool get physical => pot <= 0;

  int winners;
  int seconds;
  int pot;
  String theme;
  final List<QuizQ> questions;

  int get listCost => questions.fold<int>(0, (a, q) => a + q.cost);

  Map<String, dynamic> toJson() => {'winners': winners, 'seconds': seconds, 'pot': pot, 'theme': theme, 'questions': [for (final q in questions) q.toJson()]};

  static QuizSettings fromOptions(Object? options) {
    final q = options is Map ? options['quiz'] : null;
    if (q is! Map) return QuizSettings();
    return QuizSettings(
      winners: ((q['winners'] as num?)?.toInt() ?? 3).clamp(3, 20),
      seconds: (q['seconds'] as num?)?.toInt() ?? 15,
      pot: (q['pot'] as num?)?.toInt() ?? 0,
      theme: '${q['theme'] ?? 'scene'}',
      questions: [for (final x in (q['questions'] as List? ?? const [])) if (QuizQ.fromJson(x) != null) QuizQ.fromJson(x)!],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Fond illustré (quand l'hôte n'a pas mis d'image) : scène avec projecteurs et pièces qui flottent
// ═══════════════════════════════════════════════════════════════════════════

const Map<String, (Color, Color, Color, String)> kQuizThemes = {
  'scene': (Color(0xFF2A1257), Color(0xFF0E0820), _gold, 'Scène'),
  'neon': (Color(0xFF07324A), Color(0xFF050B1A), _green, 'Néon'),
  'tresor': (Color(0xFF4A2A05), Color(0xFF140A02), Color(0xFFFFCF4D), 'Trésor'),
};

class QuizStageBackground extends StatefulWidget {
  const QuizStageBackground({super.key, this.theme = 'scene'});

  final String theme;

  @override
  State<QuizStageBackground> createState() => _QuizStageBackgroundState();
}

class _QuizStageBackgroundState extends State<QuizStageBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  final _dots = List.generate(18, (i) {
    final r = math.Random(i * 7 + 3);
    return (r.nextDouble(), r.nextDouble(), 1.5 + r.nextDouble() * 3.5, 0.3 + r.nextDouble(), r.nextBool());
  });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final t = kQuizThemes[widget.theme] ?? kQuizThemes['scene']!;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(painter: _StagePainter(reduce ? 0 : _c.value, t.$1, t.$2, t.$3, _dots), size: Size.infinite),
      ),
    );
  }
}

class _StagePainter extends CustomPainter {
  _StagePainter(this.t, this.a, this.b, this.dot, this.dots);

  final double t;
  final Color a, b, dot;
  final List<(double, double, double, double, bool)> dots;

  @override
  void paint(Canvas canvas, Size s) {
    final rect = Offset.zero & s;
    canvas.drawRect(rect, Paint()..shader = RadialGradient(center: const Alignment(0, -.6), radius: 1.2, colors: [a, b]).createShader(rect));
    for (var i = 0; i < 3; i++) {
      final ang = math.sin(t * 2 * math.pi + i * 2.1) * .35 + (i - 1) * .45;
      canvas.save();
      canvas.translate(s.width * (.2 + i * .3), -10);
      canvas.rotate(ang);
      final beam = Path()
        ..moveTo(-8, 0)
        ..lineTo(8, 0)
        ..lineTo(s.width * .35, s.height * 1.2)
        ..lineTo(-s.width * .35, s.height * 1.2)
        ..close();
      canvas.drawPath(beam, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [dot.withOpacity(.14), dot.withOpacity(0)]).createShader(Rect.fromLTWH(-s.width * .35, 0, s.width * .7, s.height * 1.2)));
      canvas.restore();
    }
    final p = Paint()..color = dot.withOpacity(.5);
    for (final d in dots) {
      final y = ((d.$2 - t * d.$4) % 1.0 + 1.0) % 1.0;
      final c = Offset(d.$1 * s.width, y * s.height);
      if (d.$5) {
        canvas.drawOval(Rect.fromCenter(center: c, width: d.$3 * 3, height: d.$3 * 3 * (math.cos(t * 30 + d.$1 * 9).abs() + .15)), p);
      } else {
        canvas.drawCircle(c, d.$3, p);
      }
    }
    canvas.drawRect(rect, Paint()..color = Colors.black.withOpacity(.22));
  }

  @override
  bool shouldRepaint(_StagePainter o) => o.t != t || o.a != a;
}

// ═══════════════════════════════════════════════════════════════════════════
// Pluie de pièces (gagnant)
// ═══════════════════════════════════════════════════════════════════════════

class _CoinRain extends StatefulWidget {
  const _CoinRain({required this.play});

  final int play;   // change de valeur = nouvelle pluie

  @override
  State<_CoinRain> createState() => _CoinRainState();
}

class _CoinRainState extends State<_CoinRain> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  final _coins = List.generate(46, (i) {
    final r = math.Random(i * 13 + 1);
    return (r.nextDouble(), -r.nextDouble() * .6, .7 + r.nextDouble() * .9, 6 + r.nextDouble() * 6, r.nextDouble() * 6);
  });

  @override
  void didUpdateWidget(covariant _CoinRain old) {
    super.didUpdateWidget(old);
    if (old.play != widget.play && widget.play > 0 && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(animation: _c, builder: (_, __) => _c.isAnimating ? CustomPaint(painter: _CoinPainter(_c.value, _coins), size: Size.infinite) : const SizedBox.shrink()),
      );
}

class _CoinPainter extends CustomPainter {
  _CoinPainter(this.t, this.coins);

  final double t;
  final List<(double, double, double, double, double)> coins;

  @override
  void paint(Canvas canvas, Size s) {
    final rim = Paint()..color = const Color(0xFFB8860B);
    final face = Paint()..color = const Color(0xFFFFD84A);
    for (final c in coins) {
      final y = (c.$2 + t * c.$3 * 1.6) * s.height;
      if (y < -20 || y > s.height + 20) continue;
      final sx = math.cos(c.$5 + t * 18).abs();
      final center = Offset(c.$1 * s.width, y);
      canvas.drawOval(Rect.fromCenter(center: center, width: c.$4 * 2 * sx + 3, height: c.$4 * 2), rim);
      canvas.drawOval(Rect.fromCenter(center: center, width: c.$4 * 1.6 * sx + 2, height: c.$4 * 1.6), face);
    }
  }

  @override
  bool shouldRepaint(_CoinPainter o) => o.t != t;
}

// ═══════════════════════════════════════════════════════════════════════════
// Panneau du quiz dans le live (joueur et hôte)
// ═══════════════════════════════════════════════════════════════════════════

class LiveQuizPanel extends StatefulWidget {
  const LiveQuizPanel({super.key, required this.game, required this.isHost, required this.onAnswer, this.onSendQuestion, this.imageUrl, this.onOpenImage, this.onClose, this.onShowRanking});

  final LiveGame game;
  final bool isHost;

  /// Envoie la réponse ; renvoie `false` si elle n'a pas été prise (le joueur peut retoucher).
  final Future<bool> Function(int option) onAnswer;

  /// Quiz en direct : l'hôte envoie la question suivante.
  final VoidCallback? onSendQuestion;

  /// Image épinglée par l'hôte (les questions peuvent porter sur elle) ; la toucher l'agrandit.
  final String? imageUrl;
  final VoidCallback? onOpenImage;

  /// Croix de l'en-tête : l'hôte arrête le quiz, un spectateur ferme un quiz terminé chez lui.
  final VoidCallback? onClose;

  /// Classement sur toutes les questions (les 20 premiers) : à la fin pour tous, pendant la partie pour l'hôte.
  final VoidCallback? onShowRanking;

  @override
  State<LiveQuizPanel> createState() => _LiveQuizPanelState();
}

class _LiveQuizPanelState extends State<LiveQuizPanel> {
  Timer? _tick;
  int _left = 0;
  int? _sending;   // choix en cours d'envoi
  int? _sentOption;
  int _sentIndex = -1;
  String _lastKey = '';
  int _rain = 0;
  bool _muted = false;
  /// Panneau réduit à une ligne (le spectateur garde la vue sur le live, la discussion, les cadeaux) ; il se rouvre tout seul à chaque nouvelle question.
  bool _reduced = false;

  Map get q => widget.game.quiz;
  String get stage => '${q['stage'] ?? 'answer'}';
  int get index => (q['index'] as num?)?.toInt() ?? 0;

  @override
  void initState() {
    super.initState();
    QuizSound.isMuted().then((m) => mounted ? setState(() => _muted = m) : null);
    _sync(first: true);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _left <= 0) return;
      setState(() => _left--);
      if (stage == 'answer' && _left > 0 && _left <= 5) QuizSound.play(QuizSfx.tick);
    });
  }

  @override
  void didUpdateWidget(covariant LiveQuizPanel old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// Recale le compte à rebours sur le serveur et joue les sons quand l'étape change.
  void _sync({bool first = false}) {
    _left = (q['left'] as num?)?.toInt() ?? 0;
    final key = '$stage:$index';
    if (key == _lastKey) return;
    _lastKey = key;
    if (_sentIndex != index) {
      _sentOption = null;
      _sending = null;
    }
    if (first) return;
    switch (stage) {
      case 'prep':
        QuizSound.play(QuizSfx.roll);
        break;
      case 'answer':
        _reduced = false;
        QuizSound.play(QuizSfx.go);
        break;
      case 'reveal':
        final gain = (q['my_gain'] as num?)?.toInt() ?? 0;
        final mine = (q['my_option'] as num?)?.toInt() ?? (_sentIndex == index ? _sentOption : null);
        if (gain > 0) {
          QuizSound.fx(QuizSfx.win);
          Future.delayed(const Duration(milliseconds: 450), () => QuizSound.play(QuizSfx.coins));
          _rain++;
        } else if (!widget.isHost && mine != null) {
          QuizSound.fx(QuizSfx.bad);
        }
        break;
    }
  }

  Future<void> _tap(int i) async {
    if (widget.isHost || _sending != null || _myOption != null || stage != 'answer') return;
    QuizSound.fx(QuizSfx.tap);
    setState(() => _sending = i);
    final ok = await widget.onAnswer(i);
    if (!mounted) return;
    setState(() {
      _sending = null;
      if (ok) {
        _sentOption = i;
        _sentIndex = index;
      }
    });
    if (ok) QuizSound.play(QuizSfx.saved);
  }

  int? get _myOption => (q['my_option'] as num?)?.toInt() ?? (_sentIndex == index ? _sentOption : null);
  int get _myTotalGain => (q['my_total_gain'] as num?)?.toInt() ?? 0;
  bool get _hasImage => (widget.imageUrl ?? '').isNotEmpty;

  /// Bonnes réponses de la question en cours, connues de l'hôte seulement (jamais pour une question tirée des quiz d'Afrolook).
  Set<int> get _hostCorrect {
    if (!widget.isHost) return const {};
    final hq = (q['host_questions'] as List? ?? const []);
    final cur = index < hq.length && hq[index] is Map ? hq[index] as Map : null;
    return {for (final c in (cur?['correct'] as List? ?? const [])) if (c is num) c.toInt()};
  }

  @override
  Widget build(BuildContext context) {
    final tint = switch ('${q['theme'] ?? 'scene'}') { 'neon' => const Color(0xFF1A0B33), 'tresor' => const Color(0xFF241605), _ => _ink };
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(children: [
        Positioned.fill(child: ColoredBox(color: tint.withOpacity(.80))),   // fond translucide : la vidéo de l'hôte reste devinée derrière
        Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: _gold.withOpacity(.35))),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _header(context),
              if (!_reduced) ...[
                const SizedBox(height: 8),
                if (stage == 'prep' || stage == 'wait') _prep(context) else if (stage == 'done') _done(context) else _question(context),
                if (widget.isHost) ...[const SizedBox(height: 10), _hostBox(context)],
              ],
            ]),
          ),
        ),
        Positioned.fill(child: IgnorePointer(child: _CoinRain(play: _rain))),
      ]),
    );
  }

  Widget _roundBtn(String key, IconData icon, String label, VoidCallback? onTap) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          key: ValueKey(key),
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.black.withOpacity(.4), shape: BoxShape.circle), child: Icon(icon, color: Colors.white70, size: 17)),
        ),
      );

  Widget _badge(IconData icon, Color bg, Color fg) => Container(width: 28, height: 28, decoration: BoxDecoration(color: bg, shape: BoxShape.circle), child: Icon(icon, color: fg, size: 16));

  /// En-tête : temps, titre (ou, réduit, l'état de ma réponse), cagnotte, réduire, son, fermer. Une seule ligne dans tous les cas.
  Widget _header(BuildContext context) {
    final pot = stage == 'prep' ? (q['next_pot'] as num?)?.toInt() ?? 0 : (q['pot'] as num?)?.toInt() ?? 0;
    final total = (q['total'] as num?)?.toInt() ?? 0;
    final Widget lead = _reduced && _hasImage
        ? _pinThumb(28)
        : switch (stage) {
            'answer' => _Ring(left: _left, total: (q['seconds'] as num?)?.toInt() ?? 1),
            'prep' => _badge(Icons.timer_rounded, _green, _onGreen),
            'reveal' => _badge(Icons.check_rounded, _green, _onGreen),
            'done' => _badge(Icons.emoji_events_rounded, _gold, _onGold),
            _ => _badge(Icons.hourglass_top_rounded, Colors.white12, Colors.white70),
          };
    final Widget title = _reduced
        ? GestureDetector(
            key: const ValueKey('quiz_reduced_line'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _reduced = false),
            child: Text(_reducedText(context), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: stage == 'answer' && _myOption == null && !widget.isHost ? _gold : Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
          )
        : Text(
            stage == 'done'
                ? context.tr('Quiz terminé')
                : total == 0
                    ? context.tr('Quiz à cagnotte')
                    : context.tr('Question {i} sur {n}', {'i': (index + 1).clamp(1, total), 'n': total}),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _amber, fontSize: 11.5, fontWeight: FontWeight.w900, letterSpacing: .5),
          );
    return Row(children: [
      lead,
      const SizedBox(width: 8),
      Expanded(child: title),
      if (pot > 0 && stage != 'done') ...[
        const SizedBox(width: 6),
        _Jackpot(amount: pot, label: stage == 'prep' ? context.tr('Prochaine cagnotte') : stage == 'reveal' ? context.tr('Cagnotte partagée') : context.tr('À gagner')),
      ],
      const SizedBox(width: 6),
      _roundBtn('quiz_reduce', _reduced ? Icons.unfold_more_rounded : Icons.unfold_less_rounded, _reduced ? context.tr('Agrandir le quiz') : context.tr('Réduire le quiz'), () => setState(() => _reduced = !_reduced)),
      const SizedBox(width: 6),
      _roundBtn('quiz_sound', _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, _muted ? context.tr('Son coupé') : context.tr('Son activé'), () async {
        setState(() => _muted = !_muted);
        await QuizSound.setMuted(_muted);
      }),
      if (widget.onClose != null) ...[const SizedBox(width: 6), _roundBtn('quiz_close', Icons.close_rounded, context.tr('Fermer'), widget.onClose)],
    ]);
  }

  /// Texte de la ligne réduite : temps et état de ma réponse (ou nombre de réponses pour l'hôte).
  String _reducedText(BuildContext context) {
    final mine = _myOption;
    return switch (stage) {
      'answer' => widget.isHost
          ? context.tr('{t} · {n} réponses', {'t': clock(_left), 'n': CoinCheckout.fmt((q['answers'] as num?)?.toInt() ?? 0)})
          : mine != null
              ? context.tr('{t} · Réponse enregistrée', {'t': clock(_left)})
              : context.tr('{t} · Touche pour répondre', {'t': clock(_left)}),
      'reveal' => ((q['my_gain'] as num?)?.toInt() ?? 0) > 0 ? context.tr('+{n} pièces', {'n': CoinCheckout.fmt((q['my_gain'] as num).toInt())}) : context.tr('Résultat de la question'),
      'prep' => context.tr('Prépare-toi : la question arrive.'),
      'done' => context.tr('Quiz terminé'),
      _ => widget.isHost ? context.tr('Envoie ta prochaine question quand tu veux.') : context.tr("L'hôte prépare la prochaine question. Reste là !"),
    };
  }

  Widget _pinThumb(double size) => GestureDetector(
        key: ValueKey(size >= 40 ? 'quiz_pin_image' : 'quiz_pin_image_small'),
        onTap: widget.onOpenImage,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: _gold, width: 1.6)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7.5),
            child: Stack(fit: StackFit.expand, children: [
              Image.network(widget.imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF333333))),
              if (size >= 40) const Positioned(right: 2, bottom: 2, child: Icon(Icons.zoom_out_map_rounded, color: Colors.white, size: 13, shadows: [Shadow(color: Colors.black87, blurRadius: 4)])),
            ]),
          ),
        ),
      );

  /// Préparation (liste Gold) ou attente de la question suivante (en direct) : une seule ligne.
  Widget _prep(BuildContext context) {
    final auto = stage == 'prep';
    return Row(key: ValueKey('quiz_prep_$stage'), children: [
      SizedBox(
        width: 40,
        child: auto
            ? TweenAnimationBuilder<double>(
                key: ValueKey('cd_$_left'),
                tween: Tween(begin: .6, end: 1),
                duration: const Duration(milliseconds: 420),
                curve: Curves.elasticOut,
                builder: (_, v, child) => Transform.scale(scale: v, child: child),
                child: Text('${_left.clamp(0, 99)}', textAlign: TextAlign.center, style: const TextStyle(color: _gold, fontSize: 32, fontWeight: FontWeight.w900, height: 1, shadows: [Shadow(color: Color(0x88FFE14D), blurRadius: 16)])),
              )
            : const _BouncingDots(),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(
            auto ? context.tr('Prépare-toi : la question arrive.') : (widget.isHost ? context.tr('Envoie ta prochaine question quand tu veux.') : context.tr("L'hôte prépare la prochaine question. Reste là !")),
            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.3),
          ),
          if (!widget.isHost && _myTotalGain > 0) ...[const SizedBox(height: 6), _myTotal(context)],
        ]),
      ),
      if (_hasImage) ...[const SizedBox(width: 10), _pinThumb(44)],
    ]);
  }

  Widget _myTotal(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(999)),
        child: Text(context.tr('Tes gains : +{n} pièces', {'n': CoinCheckout.fmt(_myTotalGain)}), style: const TextStyle(color: _onGreen, fontSize: 11.5, fontWeight: FontWeight.w900)),
      );

  Widget _question(BuildContext context) {
    final options = [for (final o in (q['options'] as List? ?? const [])) '$o'];
    final reveal = stage == 'reveal';
    final correct = <int>{for (final c in (q['correct_list'] as List? ?? const [])) if (c is num) c.toInt()};
    final mine = _myOption;
    final hostCorrect = _hostCorrect;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text('${q['text'] ?? ''}', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800, height: 1.3))),
        if (_hasImage) ...[const SizedBox(width: 10), _pinThumb(44)],
      ]),
      const SizedBox(height: 8),
      LayoutBuilder(builder: (_, box) {
        // 2 colonnes ; 3 quand les réponses sont toutes courtes (6 lettres ou moins) ; cases plus basses au-delà de 6 choix
        final cols = options.length > 4 && options.every((o) => o.characters.length <= 6) ? 3 : 2;
        const gap = 6.0;
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        final dense = options.length > 6;
        return Wrap(spacing: gap, runSpacing: dense ? 5 : gap, children: [
          for (var i = 0; i < options.length; i++) SizedBox(width: w, child: _option(i, options[i], reveal, correct, mine, dense: dense, hostOk: hostCorrect.contains(i))),
        ]);
      }),
      const SizedBox(height: 8),
      if (reveal) _result(context, mine, correct) else _status(context, mine, q['multi'] == true),
    ]);
  }

  Widget _option(int i, String text, bool reveal, Set<int> correct, int? mine, {bool dense = false, bool hostOk = false}) {
    final ok = reveal && correct.contains(i);
    final ko = reveal && !ok && mine == i;
    final chosen = !reveal && mine == i;
    final sending = _sending == i;
    final dim = reveal && !ok && !ko;
    final open = !widget.isHost && !reveal && mine == null && _sending == null && stage == 'answer';
    final border = ok ? _green : ko ? _red : (chosen || sending) ? _amber : hostOk ? _green.withOpacity(.8) : Colors.white24;
    final bg = ok ? _green.withOpacity(.24) : ko ? _red.withOpacity(.2) : (chosen || sending) ? _amber.withOpacity(.16) : Colors.white.withOpacity(.07);
    return Semantics(
      button: open,
      label: text,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('quiz_opt_$i'),
          borderRadius: BorderRadius.circular(10),
          onTap: open ? () => _tap(i) : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: dim ? .42 : 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: dense ? 30 : 36,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: border, width: ok || ko || chosen || sending ? 1.8 : 1.1)),
              child: Row(children: [
                Container(
                  width: 17,
                  height: 17,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(.14), borderRadius: BorderRadius.circular(5)),
                  child: Text(String.fromCharCode(65 + i), style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700))),
                if (sending)
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _amber))
                else if (ok)
                  const Icon(Icons.check_circle_rounded, color: _green, size: 16)
                else if (ko)
                  const Icon(Icons.cancel_rounded, color: _red, size: 16)
                else if (chosen)
                  const Icon(Icons.check_rounded, color: _amber, size: 16)
                else if (hostOk)
                  const Icon(Icons.check_rounded, color: _green, size: 15),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _status(BuildContext context, int? mine, bool multi) {
    final answers = context.tr('{n} réponses', {'n': CoinCheckout.fmt((q['answers'] as num?)?.toInt() ?? 0)});
    if (widget.isHost) return Text('${context.tr('Les joueurs répondent…')} · $answers', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 11.5, fontWeight: FontWeight.w700));
    final (Color c, Widget lead, String t) = _sending != null
        ? (_amber, const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: _amber)), context.tr('Envoi de ta réponse…'))
        : mine != null
            ? (_green, const Icon(Icons.check_rounded, color: _green, size: 15), context.tr('Réponse enregistrée · résultat à la fin du temps'))
            : (Colors.white70, const SizedBox.shrink(), '${multi ? context.tr('Plusieurs bonnes réponses : touches-en une') : context.tr('Touche ta réponse')} · $answers');
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Container(
        key: ValueKey(t),
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        decoration: BoxDecoration(color: c.withOpacity(.12), borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          lead,
          if (lead is! SizedBox || _sending != null) const SizedBox(width: 6),
          Flexible(child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w800))),
        ]),
      ),
    );
  }

  /// Résultat d'une question, sur une ligne : mon résultat, puis les 3 premiers (la liste complète reste dans l'historique).
  /// Sans cagnotte : mes points sur la question et ma place au classement.
  Widget _result(BuildContext context, int? mine, Set<int> correct) {
    final gain = (q['my_gain'] as num?)?.toInt() ?? 0;
    final noPot = ((q['pot'] as num?)?.toInt() ?? 0) <= 0;
    final qPoints = (q['my_q_points'] as num?)?.toInt() ?? 0;
    final myRank = (q['my_rank'] as num?)?.toInt();
    final list = [for (final w in (q['question_winners'] as List? ?? const [])) if (w is Map) w];
    Widget? me;
    if (!widget.isHost) {
      final (String t, Color bg, Color fg) = noPot && qPoints > 0
          ? (myRank != null ? context.tr('+{n} pts · place {r}', {'n': CoinCheckout.fmt(qPoints), 'r': myRank}) : context.tr('+{n} pts', {'n': CoinCheckout.fmt(qPoints)}), _green, _onGreen)
          : gain > 0
          ? (context.tr('+{n} pièces', {'n': CoinCheckout.fmt(gain)}), _green, _onGreen)
          : mine != null && correct.contains(mine)
              ? (context.tr('Bonne réponse'), Colors.white12, Colors.white)
              : mine == null
                  ? (context.tr('Trop tard'), Colors.white12, Colors.white70)
                  : (context.tr('Raté'), _red.withOpacity(.25), const Color(0xFFFFD3D4));
      me = TweenAnimationBuilder<double>(
        tween: Tween(begin: .6, end: 1),
        duration: const Duration(milliseconds: 450),
        curve: Curves.elasticOut,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: Container(
          key: const ValueKey('quiz_my_result'),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
          child: Text(t, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w900)),
        ),
      );
    }
    return Row(children: [
      if (me != null) ...[me, const SizedBox(width: 8)],
      Expanded(
        child: list.isEmpty
            ? Text(noPot ? context.tr('Personne n\'a trouvé la bonne réponse.') : context.tr('Personne n\'a gagné cette cagnotte : elle revient à l\'hôte.'), maxLines: 2, style: const TextStyle(color: Colors.white70, fontSize: 11.5))
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [for (final w in list.take(3)) Padding(padding: const EdgeInsets.only(right: 6), child: _winnerChip(w))]),
              ),
      ),
    ]);
  }

  static const _medals = [Color(0xFFFFC83D), Color(0xFFC9D1DB), Color(0xFFD08A4E)];

  Widget _winnerChip(Map w) {
    final rank = (w['rank'] as num?)?.toInt() ?? 0;
    final coins = (w['coins'] as num?)?.toInt() ?? 0;   // 0 = quiz sans cagnotte : on montre les points
    return Container(
      padding: const EdgeInsets.fromLTRB(5, 3, 8, 3),
      decoration: BoxDecoration(color: Colors.white.withOpacity(.1), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        rank >= 1 && rank <= 3
            ? Icon(Icons.emoji_events_rounded, size: 14, color: _medals[rank - 1])
            : Text('$rank', style: const TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w900)),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 90),
          child: Text('@${w['username'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 4),
        Text(coins > 0 ? '+${CoinCheckout.fmt(coins)}' : context.tr('{n} pts', {'n': CoinCheckout.fmt((w['points'] as num?)?.toInt() ?? 0)}), style: TextStyle(color: coins > 0 ? _gold : Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _done(BuildContext context) {
    final paid = [for (final w in widget.game.winners) if (w is Map && ((w['coins'] as num?)?.toInt() ?? 0) > 0) w];
    final ranking = [for (final (i, r) in (q['ranking'] as List? ?? const []).indexed) if (r is Map) {...r, 'rank': r['rank'] ?? i + 1, 'coins': 0}];
    final noCoins = paid.isEmpty;
    final list = noCoins ? ranking : paid;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (!widget.isHost && _myTotalGain > 0) ...[_myTotal(context), const SizedBox(height: 8)],
      if (list.isEmpty)
        Text(noCoins ? context.tr('Personne n\'a encore répondu.') : context.tr('Personne n\'a gagné cette cagnotte : elle revient à l\'hôte.'), style: const TextStyle(color: Colors.white70, fontSize: 11.5))
      else ...[
        Text((noCoins ? context.tr('Classement final') : context.tr('Gagnants du quiz')).toUpperCase(), style: const TextStyle(color: _amber, fontSize: 10.5, fontWeight: FontWeight.w900, letterSpacing: .8)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [for (final w in list.take(5)) _winnerChip(w)]),
        if (list.length > 5) ...[
          const SizedBox(height: 4),
          Text(context.tr('… et {n} autres gagnants', {'n': list.length - 5}), style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      ],
      if (widget.onShowRanking != null) ...[
        const SizedBox(height: 10),
        _rankingButton(context, filled: true),
      ],
    ]);
  }

  Widget _rankingButton(BuildContext context, {required bool filled}) => SizedBox(
        height: 38,
        width: double.infinity,
        child: filled
            ? FilledButton.icon(
                key: const ValueKey('quiz_full_ranking'),
                style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: _onGold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19))),
                onPressed: widget.onShowRanking,
                icon: const Icon(Icons.leaderboard_rounded, size: 18),
                label: Text(context.tr('Voir le classement final'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
              )
            : OutlinedButton.icon(
                key: const ValueKey('quiz_full_ranking'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19))),
                onPressed: widget.onShowRanking,
                icon: const Icon(Icons.leaderboard_rounded, size: 17),
                label: Text(context.tr('Classement provisoire'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
              ),
      );

  /// Hôte : chiffres en direct ; en direct, le bouton pour envoyer la question suivante.
  Widget _hostBox(BuildContext context) {
    final hq = (q['host_questions'] as List? ?? const []);
    final live = q['mode'] == 'live';
    final canSend = live && stage != 'prep' && stage != 'done' && widget.onSendQuestion != null;   // pendant une question, la suivante part après elle
    Widget stat(String v, String l) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(color: Colors.black.withOpacity(.3), borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              Text(v, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
              Text(l, style: const TextStyle(color: Colors.white60, fontSize: 10.5)),
            ]),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        stat(CoinCheckout.fmt((q['answers'] as num?)?.toInt() ?? 0), context.tr('réponses')),
        const SizedBox(width: 6),
        stat(stage == 'answer' ? clock(_left) : '–', context.tr('temps')),
        const SizedBox(width: 6),
        stat(CoinCheckout.fmt((q['pot'] as num?)?.toInt() ?? 0), context.tr('cagnotte')),
      ]),
      if (widget.onShowRanking != null && stage != 'done') ...[
        const SizedBox(height: 8),
        _rankingButton(context, filled: false),
      ],
      if (!live && hq.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(context.tr('Liste préparée : {d} sur {n} jouées, enchaînement automatique', {'d': hq.where((x) => x is Map && x['done'] == true).length, 'n': hq.length}),
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
      if (live) ...[
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: FilledButton.icon(
            key: const ValueKey('quiz_send_question'),
            style: FilledButton.styleFrom(backgroundColor: _green, foregroundColor: _onGreen, disabledBackgroundColor: Colors.white12, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19))),
            onPressed: canSend ? widget.onSendQuestion : null,
            icon: const Icon(Icons.send_rounded, size: 17),
            label: Text(
              stage == 'prep' ? context.tr('Question en préparation…') : context.tr('Envoyer une question'),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
        ),
      ],
    ]);
  }
}

/// Cagnotte en jeu : une pastille jaune compacte (pièce + montant qui défile).
class _Jackpot extends StatelessWidget {
  const _Jackpot({required this.amount, required this.label});

  final int amount;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$label ${CoinCheckout.fmt(amount)}',
        child: Container(
          key: const ValueKey('quiz_jackpot'),
          padding: const EdgeInsets.fromLTRB(4, 3, 9, 3),
          decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(999), boxShadow: [BoxShadow(color: _gold.withOpacity(.4), blurRadius: 12)]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF8A6508)), gradient: const RadialGradient(center: Alignment(-.3, -.4), colors: [Color(0xFFFFF6B0), Color(0xFFF5C518), Color(0xFFB8860B)])),
            ),
            const SizedBox(width: 5),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: amount.toDouble()),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => Text(CoinCheckout.fmt(v.round()), style: const TextStyle(color: _onGold, fontSize: 13.5, fontWeight: FontWeight.w900, height: 1.05, fontFeatures: [FontFeature.tabularFigures()])),
            ),
          ]),
        ),
      );
}

class _Ring extends StatelessWidget {
  const _Ring({required this.left, required this.total, this.color});

  final int left;
  final int total;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = total <= 0 ? 0.0 : (left / total).clamp(0.0, 1.0);
    final urgent = color == null && left <= 5;
    final c = color ?? (urgent ? _red : _gold);
    return SizedBox(
      width: 30,
      height: 30,
      child: Stack(alignment: Alignment.center, children: [
        SizedBox.expand(
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: p),
            duration: const Duration(milliseconds: 900),
            builder: (_, v, __) => CircularProgressIndicator(value: v, strokeWidth: 3, backgroundColor: Colors.white24, color: c),
          ),
        ),
        Text(left >= 60 ? '${(left / 60).ceil()}m' : '$left', style: TextStyle(color: urgent ? _red : Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class _BouncingDots extends StatefulWidget {
  const _BouncingDots();

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < 3; i++)
            Transform.translate(
              offset: Offset(0, -8 * math.sin(((_c.value - i * .15) % 1) * math.pi).clamp(0, 1)),
              child: Container(width: 7, height: 7, margin: const EdgeInsets.symmetric(horizontal: 3), decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle)),
            ),
        ]),
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// Éditeur d'une question (hôte)
// ═══════════════════════════════════════════════════════════════════════════

Future<QuizQ?> showQuizQuestionEditor(BuildContext context, {QuizQ? initial, int defSeconds = 15, int defPot = 100, String okLabel = 'Valider', bool showPot = true}) {
  return showModalBottomSheet<QuizQ>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _QP.of(context).sheet,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => _QuestionEditor(initial: initial, defSeconds: defSeconds, defPot: defPot, okLabel: okLabel, showPot: showPot),
  );
}

class _QuestionEditor extends StatefulWidget {
  const _QuestionEditor({this.initial, required this.defSeconds, required this.defPot, required this.okLabel, this.showPot = true});

  final bool showPot;
  final QuizQ? initial;
  final int defSeconds;
  final int defPot;
  final String okLabel;

  @override
  State<_QuestionEditor> createState() => _QuestionEditorState();
}

class _QuestionEditorState extends State<_QuestionEditor> {
  late final TextEditingController _text = TextEditingController(text: widget.initial?.text ?? '');
  late final List<TextEditingController> _opts = [for (final o in (widget.initial?.options ?? ['', '', ''])) TextEditingController(text: o)];
  late final Set<int> _correct = {...?widget.initial?.correct};
  late int _seconds = widget.initial?.seconds ?? widget.defSeconds;
  late int _pot = widget.initial?.pot ?? widget.defPot;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    for (final c in _opts) {
      c.dispose();
    }
    super.dispose();
  }

  QuizQ get _value => QuizQ(text: _text.text.trim(), options: [for (final c in _opts) c.text.trim()], correct: {..._correct}, seconds: _seconds, pot: _pot);

  @override
  Widget build(BuildContext context) {
    final p = _QP.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Text(context.tr('Question du quiz'), style: TextStyle(color: p.text, fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            _field(_text, context.tr('Ta question'), context.tr('Quel fleuve traverse Niamey ?'), key: const ValueKey('quiz_q_text')),
            const SizedBox(height: 10),
            Text(context.tr('Choix (coche les bonnes réponses, une ou plusieurs)'), style: TextStyle(color: p.text2, fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (var i = 0; i < _opts.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  InkWell(
                    key: ValueKey('quiz_q_correct_$i'),
                    onTap: () => setState(() => _correct.contains(i) ? _correct.remove(i) : _correct.add(i)),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: _correct.contains(i) ? _green : p.fill, borderRadius: BorderRadius.circular(8), border: Border.all(color: _correct.contains(i) ? _green : p.line)),
                      child: Icon(_correct.contains(i) ? Icons.check_rounded : Icons.close_rounded, color: _correct.contains(i) ? _onGreen : p.faint, size: 18, semanticLabel: _correct.contains(i) ? context.tr('Bonne réponse') : context.tr('Mauvaise réponse')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _field(_opts[i], '${context.tr('Choix')} ${String.fromCharCode(65 + i)}', '', key: ValueKey('quiz_q_opt_$i'))),
                  if (_opts.length > 2)
                    IconButton(
                      tooltip: context.tr('Retirer ce choix'),
                      onPressed: () => setState(() {
                        _opts.removeAt(i).dispose();
                        // les bonnes réponses après le choix retiré remontent d'un cran
                        final kept = {for (final x in _correct) if (x != i) x > i ? x - 1 : x};
                        _correct
                          ..clear()
                          ..addAll(kept);
                      }),
                      icon: Icon(Icons.remove_circle_outline_rounded, color: p.icon),
                    ),
                ]),
              ),
            if (_opts.length < 10)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const ValueKey('quiz_q_add_option'),
                  onPressed: () => setState(() => _opts.add(TextEditingController())),
                  icon: Icon(Icons.add_rounded, color: p.amber),
                  label: Text(context.tr('Ajouter un choix ({n} sur 10)', {'n': _opts.length}), style: TextStyle(color: p.amber, fontWeight: FontWeight.w800)),
                ),
              ),
            const SizedBox(height: 6),
            Text(context.tr('Temps pour répondre'), style: TextStyle(color: p.text2, fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            _chips(kQuizTimeChoices, _seconds, (v) => setState(() => _seconds = v), (v) => quizTimeLabel(context, v)),
            if (widget.showPot) ...[
              const SizedBox(height: 10),
              Text(context.tr('À gagner sur cette question'), style: TextStyle(color: p.text2, fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              _chips(kQuizPotChoices, _pot, (v) => setState(() => _pot = v), (v) => v == 0 ? context.tr('Sans cagnotte') : CoinCheckout.fmt(v)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: Text(context.tr('Coût pour toi'), style: TextStyle(color: p.text2, fontSize: 13))),
                Text(context.tr('{n} pièces', {'n': CoinCheckout.fmt(quizCost(_pot))}), style: TextStyle(color: p.amber, fontSize: 14, fontWeight: FontWeight.w900)),
              ]),
            ],
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: p.red, fontSize: 12.5, fontWeight: FontWeight.w700))),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('quiz_q_ok'),
              style: FilledButton.styleFrom(backgroundColor: _green, foregroundColor: _onGreen, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
              onPressed: () {
                final v = _value;
                final p = v.problem(context);
                if (p != null) {
                  setState(() => _error = p);
                  return;
                }
                Navigator.pop(context, v);
              },
              child: Text(context.tr(widget.okLabel), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, String hint, {Key? key}) => _fieldP(_QP.of(context), c, label, hint, key: key);

  Widget _fieldP(_QP p, TextEditingController c, String label, String hint, {Key? key}) => TextField(
        key: key,
        controller: c,
        onChanged: (_) => _error == null ? null : setState(() => _error = null),
        style: TextStyle(color: p.text),
        decoration: InputDecoration(
          isDense: true,
          labelText: label,
          hintText: hint.isEmpty ? null : hint,
          labelStyle: TextStyle(color: p.text3),
          hintStyle: TextStyle(color: p.faint),
          filled: true,
          fillColor: p.fill,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.line)),
        ),
      );
}

Widget _chips(List<int> values, int selected, ValueChanged<int> onPick, String Function(int) label) => Builder(builder: (context) {
      final p = _QP.of(context);
      return Wrap(spacing: 6, runSpacing: 6, children: [
        for (final v in values)
          ChoiceChip(
            key: ValueKey('chip_$v'),
            label: Text(label(v)),
            selected: selected == v,
            onSelected: (_) => onPick(v),
            labelStyle: TextStyle(color: selected == v ? _onGreen : p.text, fontWeight: FontWeight.w700, fontSize: 12.5),
            color: WidgetStatePropertyAll(selected == v ? _green : p.fill),
            side: BorderSide(color: selected == v ? _green : p.line),
            showCheckmark: false,
          ),
      ]);
    });

// ═══════════════════════════════════════════════════════════════════════════
// Réglages du quiz (création du live et lancement)
// ═══════════════════════════════════════════════════════════════════════════

/// Réglages de base pour tous, liste préparée pour le Gold. Utilisé à la création du live et au lancement du quiz.
class QuizSettingsEditor extends StatefulWidget {
  const QuizSettingsEditor({super.key, required this.settings, required this.isGold, required this.onChanged, this.onUpgrade});

  final QuizSettings settings;
  final bool isGold;
  final VoidCallback onChanged;
  final VoidCallback? onUpgrade;

  @override
  State<QuizSettingsEditor> createState() => _QuizSettingsEditorState();
}

class _QuizSettingsEditorState extends State<QuizSettingsEditor> {
  QuizSettings get s => widget.settings;

  void _set(VoidCallback f) {
    setState(f);
    widget.onChanged();
  }

  Widget _box(List<Widget> children) => _boxP(_QP.of(context), children);

  Widget _boxP(_QP p, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: p.box, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.boxBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );

  Text _label(String t) => Text(t, style: TextStyle(color: _QP.of(context).text2, fontSize: 12.5, fontWeight: FontWeight.w700));

  Widget _reward(String key, IconData icon, String title, String text, bool on, VoidCallback onTap) => _rewardP(_QP.of(context), key, icon, title, text, on, onTap);

  Widget _rewardP(_QP p, String key, IconData icon, String title, String text, bool on, VoidCallback onTap) => GestureDetector(
        key: ValueKey(key),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: on ? _gold.withOpacity(.14) : p.fill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: on ? _gold : p.line2, width: on ? 1.6 : 1),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: on ? p.goldText : p.text3, size: 20),
              const Spacer(),
              Icon(on ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: on ? p.goldText : p.faint, size: 18),
            ]),
            const SizedBox(height: 6),
            Text(title, style: TextStyle(color: p.text, fontSize: 13, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(text, style: TextStyle(color: p.text3, fontSize: 11, height: 1.3)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = _QP.of(context);
    final split = quizSplit(s.pot, s.winners);
    final maxPart = split.isEmpty || split.first == 0 ? 1 : split.first;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _box([
        _label(context.tr('Récompense')),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _reward('quiz_reward_physical', Icons.emoji_events_rounded, context.tr('Prix remis en personne'), context.tr('Aucune pièce. Les points désignent les gagnants au classement final.'), s.physical, () => _set(() => s.pot = 0))),
          const SizedBox(width: 8),
          Expanded(child: _reward('quiz_reward_coins', Icons.savings_rounded, context.tr('Cagnotte en pièces'), context.tr('Chaque question a sa cagnotte, partagée entre les plus rapides.'), !s.physical, () => _set(() => s.pot = s.pot > 0 ? s.pot : 100))),
        ]),
      ]),
      if (!s.physical) _box([
        Row(children: [Expanded(child: _label(context.tr('Nombre de gagnants par question'))), Text('${s.winners}', style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w900))]),
        Slider(key: const ValueKey('quiz_winners'), value: s.winners.toDouble(), min: 3, max: 20, divisions: 17, activeColor: _green, label: '${s.winners}', onChanged: (v) => _set(() => s.winners = v.round())),
        SizedBox(
          height: 34,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final p in split) Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 1), height: math.max(4, 34 * p / maxPart), decoration: BoxDecoration(color: _gold, borderRadius: const BorderRadius.vertical(top: Radius.circular(3))))),
          ]),
        ),
        const SizedBox(height: 4),
        Text(
          s.pot > 0
              ? context.tr('Pour {p} pièces : le 1er gagne {a}, le dernier {z}. Égalité de points : parts partagées.', {'p': CoinCheckout.fmt(s.pot), 'a': CoinCheckout.fmt(split.first), 'z': CoinCheckout.fmt(split.last)})
              : context.tr('Le 1er gagne le plus, puis de moins en moins.'),
          style: TextStyle(color: p.text3, fontSize: 11.5),
        ),
      ]),
      _box([
        _label(context.tr('Temps par question (par défaut)')),
        const SizedBox(height: 6),
        _chips(kQuizTimeChoices, s.seconds, (v) => _set(() => s.seconds = v), (v) => quizTimeLabel(context, v)),
      ]),
      if (!s.physical) _box([
        _label(context.tr('À gagner par question (par défaut)')),
        const SizedBox(height: 6),
        _chips(kQuizPotChoices, s.pot, (v) => _set(() => s.pot = v), (v) => v == 0 ? context.tr('Sans cagnotte') : CoinCheckout.fmt(v)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text(context.tr('Coût pour toi par question'), style: TextStyle(color: p.text2, fontSize: 13))),
          Text(context.tr('{n} pièces', {'n': CoinCheckout.fmt(quizCost(s.pot))}), style: TextStyle(color: p.amber, fontSize: 14, fontWeight: FontWeight.w900)),
        ]),
      ]),
      _box([
        _label(context.tr("Fond (sans image : illustré par l'application)")),
        const SizedBox(height: 6),
        Row(children: [
          for (final e in kQuizThemes.entries)
            Expanded(
              child: GestureDetector(
                key: ValueKey('quiz_theme_${e.key}'),
                onTap: () => _set(() => s.theme = e.key),
                child: Container(
                  height: 50,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: s.theme == e.key ? _green : Colors.transparent, width: 2)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(children: [
                      Positioned.fill(child: QuizStageBackground(theme: e.key)),
                      Positioned(left: 6, bottom: 4, child: Text(context.tr(e.value.$4), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, shadows: [Shadow(blurRadius: 3)]))),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ]),
      _box([
        Row(children: [
          Expanded(child: _label(context.tr('Questions préparées à l\'avance'))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(999)), child: const Text('GOLD', style: TextStyle(color: _onGold, fontSize: 10, fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 6),
        if (!widget.isGold) ...[
          Text(context.tr('Avec Gold, prépare jusqu\'à 50 questions avec leur temps et leur cagnotte : elles s\'enchaînent toutes seules pendant le live. Sans Gold, tu envoies tes questions une par une en direct.'),
              style: TextStyle(color: p.text3, fontSize: 12, height: 1.35)),
          if (widget.onUpgrade != null) Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: widget.onUpgrade, child: Text(context.tr('Passer à Gold'), style: TextStyle(color: p.amber, fontWeight: FontWeight.w900)))),
        ] else ...[
          for (var i = 0; i < s.questions.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 5),
              padding: const EdgeInsets.fromLTRB(8, 4, 2, 4),
              decoration: BoxDecoration(color: p.fill, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                SizedBox(width: 20, child: Text('${i + 1}', style: TextStyle(color: p.amber, fontWeight: FontWeight.w900))),
                Expanded(child: Text(s.questions[i].text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text, fontSize: 12.5, fontWeight: FontWeight.w700))),
                Text(s.physical ? quizTimeLabel(context, s.questions[i].seconds) : '${quizTimeLabel(context, s.questions[i].seconds)} · ${CoinCheckout.fmt(s.questions[i].pot)}', style: TextStyle(color: p.icon, fontSize: 11)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: context.tr('Modifier'),
                  icon: Icon(Icons.edit_rounded, color: p.icon, size: 18),
                  onPressed: () async {
                    final v = await showQuizQuestionEditor(context, initial: s.questions[i], showPot: !s.physical);
                    if (v != null) _set(() => s.questions[i] = v);
                  },
                ),
                IconButton(visualDensity: VisualDensity.compact, tooltip: context.tr('Supprimer'), icon: Icon(Icons.delete_outline_rounded, color: p.icon, size: 18), onPressed: () => _set(() => s.questions.removeAt(i))),
              ]),
            ),
          if (s.questions.length < 50)
            TextButton.icon(
              key: const ValueKey('quiz_add_question'),
              onPressed: () async {
                final v = await showQuizQuestionEditor(context, defSeconds: s.seconds, defPot: s.pot, okLabel: 'Ajouter', showPot: !s.physical);
                if (v != null) _set(() => s.questions.add(v));
              },
              icon: Icon(Icons.add_rounded, color: p.amber),
              label: Text(context.tr('Ajouter une question ({n} sur 50)', {'n': s.questions.length}), style: TextStyle(color: p.amber, fontWeight: FontWeight.w800)),
            ),
          if (s.questions.isNotEmpty && s.listCost > 0)
            Text(context.tr('Coût de la liste : {n} pièces, prélevées au lancement du quiz.', {'n': CoinCheckout.fmt(s.listCost)}), style: TextStyle(color: p.text3, fontSize: 11.5)),
        ],
      ]),
    ]);
  }
}

/// Lancement du quiz dans le live : réglages modifiables, puis « liste préparée » (Gold) ou « quiz en direct ».
/// Paquet de questions Afrolook choisi au lancement : thème et nombre de questions.
typedef QuizPackPick = ({String theme, int count});

/// Fenêtre de lancement : réglages, puis liste préparée (Gold), questions Afrolook (2 par mois sans Gold, illimité en Gold) ou questions en direct.
/// [packs] : catalogue renvoyé par le serveur (`GET /lives/quiz-packs`) ; absent = section masquée.
/// [liveSecondsLeft] : temps qui reste au live (avertissement si le quiz est plus long).
Future<({String mode, QuizSettings settings, QuizPackPick? pack})?> showQuizLaunchSheet(BuildContext context, {required QuizSettings settings, required bool isGold, VoidCallback? onUpgrade, Map<String, dynamic>? packs, int? liveSecondsLeft}) {
  var packTheme = 'mix';
  var packCount = 10;
  return showModalBottomSheet<({String mode, QuizSettings settings, QuizPackPick? pack})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _QP.of(context).sheet,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .88,
        maxChildSize: .95,
        builder: (_, scroll) => Builder(builder: (ctx) {
          final p = _QP.of(ctx);
          return ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 12),
          Text(ctx.tr('Quiz à cagnotte'), style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(ctx.tr('Jouer est gratuit pour le public. Chaque bonne réponse rapporte des points (plus on répond vite, plus on en gagne) : le classement final désigne les gagnants.'), style: TextStyle(color: p.text3, fontSize: 12.5, height: 1.35)),
          const SizedBox(height: 12),
          QuizSettingsEditor(settings: settings, isGold: isGold, onUpgrade: onUpgrade, onChanged: () => setS(() {})),
          if (isGold && settings.questions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FilledButton.icon(
                key: const ValueKey('quiz_launch_planned'),
                style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: _onGold, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                onPressed: () => Navigator.pop(ctx, (mode: 'planned', settings: settings, pack: null)),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text(settings.listCost > 0 ? ctx.tr('Lancer la liste ({n} questions) · {c} pièces', {'n': settings.questions.length, 'c': CoinCheckout.fmt(settings.listCost)}) : ctx.tr('Lancer la liste ({n} questions)', {'n': settings.questions.length}), style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          if (isGold && settings.questions.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: quizDurationNote(ctx, quizListSeconds(settings.questions.map((q) => q.seconds)), liveSecondsLeft)),
          if (packs != null) ...[
            QuizPacksBox(
              footer: quizDurationNote(ctx, quizListSeconds(List.filled(packCount, settings.seconds)), liveSecondsLeft),
              packs: packs,
              theme: packTheme,
              count: packCount,
              pot: settings.pot,
              onTheme: (v) => setS(() => packTheme = v),
              onCount: (v) => setS(() => packCount = v),
              onLaunch: () => Navigator.pop(ctx, (mode: 'planned', settings: settings, pack: (theme: packTheme, count: packCount))),
              onUpgrade: onUpgrade,
            ),
            const SizedBox(height: 12),
          ],
          FilledButton.icon(
            key: const ValueKey('quiz_launch_live'),
            style: FilledButton.styleFrom(backgroundColor: _green, foregroundColor: _onGreen, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
            onPressed: () => Navigator.pop(ctx, (mode: 'live', settings: settings, pack: null)),
            icon: const Icon(Icons.bolt_rounded),
            label: Text(ctx.tr('Ouvrir le quiz en direct (questions une par une)'), style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ]);
        }),
      ),
    ),
  );
}

/// Questions Afrolook (tirées des quiz de l'application) : thème, nombre de questions, utilisations gratuites restantes, lancement.
class QuizPacksBox extends StatelessWidget {
  const QuizPacksBox({super.key, required this.packs, required this.theme, required this.count, required this.pot, required this.onTheme, required this.onCount, required this.onLaunch, this.onUpgrade, this.footer});

  /// Durée estimée du paquet face au temps qui reste au live.
  final Widget? footer;

  final Map<String, dynamic> packs;
  final String theme;
  final int count;
  final int pot;
  final ValueChanged<String> onTheme;
  final ValueChanged<int> onCount;
  final VoidCallback onLaunch;
  final VoidCallback? onUpgrade;

  Widget _chip(_QP p, String key, String label, bool on, VoidCallback onTap) => ChoiceChip(
        key: ValueKey(key),
        label: Text(label),
        selected: on,
        onSelected: (_) => onTap(),
        color: WidgetStatePropertyAll(on ? _gold : p.fill),
        labelStyle: TextStyle(color: on ? _onGold : p.text, fontWeight: FontWeight.w700, fontSize: 12.5),
        side: BorderSide.none,
        showCheckmark: false,
      );

  @override
  Widget build(BuildContext context) {
    final themes = [for (final t in (packs['themes'] as List? ?? const [])) if (t is Map) t];
    final counts = [for (final c in (packs['counts'] as List? ?? const [5, 10, 20])) if (c is num) c.toInt()];
    final freeLeft = (packs['free_left'] as num?)?.toInt();   // null = sans limite (Gold)
    final perMonth = (packs['free_per_month'] as num?)?.toInt() ?? 2;
    final blocked = freeLeft != null && freeLeft <= 0;
    final cost = count * quizCost(pot);
    final p = _QP.of(context);
    return Container(
      key: const ValueKey('quiz_packs_box'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.fill, borderRadius: BorderRadius.circular(16), border: Border.all(color: _gold.withOpacity(.35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.auto_stories_rounded, color: p.amber, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(context.tr('Questions Afrolook'), style: TextStyle(color: p.text, fontSize: 15, fontWeight: FontWeight.w900))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: freeLeft == null ? _gold : blocked ? _red.withOpacity(.25) : _green.withOpacity(.2), borderRadius: BorderRadius.circular(999)),
            child: Text(
              freeLeft == null ? context.tr('Illimité avec Gold') : context.tr('{n} sur {m} gratuits ce mois-ci', {'n': freeLeft, 'm': perMonth}),
              style: TextStyle(color: freeLeft == null ? _onGold : blocked ? p.dangerText : p.greenText, fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text(context.tr("Des questions prêtes, tirées de nos quiz. Elles s'enchaînent toutes seules et tu découvres les réponses en même temps que les joueurs."),
            style: TextStyle(color: p.text3, fontSize: 12, height: 1.35)),
        const SizedBox(height: 12),
        Text(context.tr('Thème'), style: TextStyle(color: p.text2, fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final t in themes) _chip(p, 'quiz_pack_theme_${t['id']}', context.tr('${t['label']}'), theme == t['id'], () => onTheme('${t['id']}')),
        ]),
        const SizedBox(height: 12),
        Text(context.tr('Nombre de questions'), style: TextStyle(color: p.text2, fontSize: 12, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final c in counts) _chip(p, 'quiz_pack_count_$c', '$c', count == c, () => onCount(c)),
        ]),
        if (footer != null) footer!,
        const SizedBox(height: 10),
        FilledButton.icon(
          key: const ValueKey('quiz_launch_pack'),
          style: FilledButton.styleFrom(backgroundColor: blocked ? p.text : _gold, foregroundColor: blocked ? p.sheet : _onGold, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
          onPressed: blocked ? onUpgrade : onLaunch,
          icon: Icon(blocked ? Icons.workspace_premium_rounded : Icons.play_arrow_rounded),
          label: Text(
            blocked
                ? context.tr('Passer à Gold pour continuer')
                : cost > 0
                    ? context.tr('Lancer {n} questions · {c} pièces', {'n': count, 'c': CoinCheckout.fmt(cost)})
                    : context.tr('Lancer {n} questions', {'n': count}),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        if (blocked) ...[
          const SizedBox(height: 6),
          Text(context.tr('Tu as utilisé tes quiz Afrolook gratuits de ce mois-ci. Ils reviennent le 1er du mois.'), textAlign: TextAlign.center, style: TextStyle(color: p.text3, fontSize: 11.5)),
        ],
      ]),
    );
  }
}

/// Classement du quiz sur toutes les questions (les 20 premiers, ma place à part) : sert à remettre des prix lors des événements.
Future<void> showQuizRankingSheet(BuildContext context, Future<Map<String, dynamic>> future, {bool isHost = false}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuizRankingSheet(future: future, isHost: isHost),
    );

class QuizRankingSheet extends StatelessWidget {
  const QuizRankingSheet({super.key, required this.future, this.isHost = false});

  final Future<Map<String, dynamic>> future;
  final bool isHost;

  static const _medals = [Color(0xFFFFC83D), Color(0xFFC9D1DB), Color(0xFFD08A4E)];

  /// Texte du classement à copier (remise des prix) : une ligne par personne.
  static String asText(BuildContext context, Map<String, dynamic> d) {
    final q = (d['questions'] as num?)?.toInt() ?? 0;
    final rows = [for (final r in (d['rows'] as List? ?? const [])) if (r is Map) r];
    final b = StringBuffer('${d['final'] == true ? context.tr('Classement final') : context.tr('Classement provisoire')} · ${context.tr('{n} questions', {'n': q})}\n');
    for (final r in rows) {
      b.writeln('${r['rank']}. @${r['username']} · ${context.tr('{n} points', {'n': CoinCheckout.fmt((r['points'] as num?)?.toInt() ?? 0)})} · ${context.tr('{c} sur {q} bonnes réponses', {'c': r['correct'], 'q': q})}');
    }
    return b.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final p = _QP.of(context);
    return Container(
      key: const ValueKey('quiz_ranking_sheet'),
      height: MediaQuery.of(context).size.height * .82,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [p.sheetTop, p.sheetBottom]),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (ctx, snap) {
          final d = snap.data;
          final q = (d?['questions'] as num?)?.toInt() ?? 0;
          final rows = [for (final r in (d?['rows'] as List? ?? const [])) if (r is Map) r];
          final me = d?['me'] is Map ? d!['me'] as Map : null;
          final meInTop = me != null && rows.any((r) => r['user_id'] == me['user_id']);
          return Column(children: [
            const SizedBox(height: 8),
            Container(width: 38, height: 4, decoration: BoxDecoration(color: p.line, borderRadius: BorderRadius.circular(99))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
              child: Row(children: [
                Icon(Icons.leaderboard_rounded, color: p.amber, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d?['final'] == false ? ctx.tr('Classement provisoire') : ctx.tr('Classement final'), style: TextStyle(color: p.text, fontSize: 18, fontWeight: FontWeight.w900)),
                    if (d != null)
                      Text(ctx.tr('{p} joueurs · {q} questions · les {t} premiers', {'p': d['players'] ?? rows.length, 'q': q, 't': d['top'] ?? 20}),
                          style: TextStyle(color: p.text3, fontSize: 12)),
                  ]),
                ),
                IconButton(tooltip: ctx.tr('Fermer'), icon: Icon(Icons.close_rounded, color: p.icon), onPressed: () => Navigator.pop(ctx)),
              ]),
            ),
            Expanded(
              child: snap.connectionState != ConnectionState.done
                  ? Center(child: CircularProgressIndicator(color: p.amber))
                  : snap.hasError || rows.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(snap.hasError ? ctx.tr('Classement indisponible pour le moment.') : ctx.tr('Personne n\'a encore répondu.'),
                                textAlign: TextAlign.center, style: TextStyle(color: p.text3, height: 1.4)),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _row(ctx, rows[i], q, mine: me != null && rows[i]['user_id'] == me['user_id']),
                        ),
            ),
            if (me != null && !meInTop)
              Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: _row(ctx, {...me, 'username': ctx.tr('Toi')}, q, mine: true, plainName: true)),
            if (isHost && rows.isNotEmpty)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton.icon(
                      key: const ValueKey('quiz_ranking_copy'),
                      style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: _onGold, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23))),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: asText(ctx, d!)));
                        if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(ctx.tr('Classement copié : tu peux le coller où tu veux pour la remise des prix.'))));
                      },
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: Text(ctx.tr('Copier le classement'), style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
              ),
          ]);
        },
      ),
    );
  }

  Widget _row(BuildContext ctx, Map r, int q, {bool mine = false, bool plainName = false}) {
    final rank = (r['rank'] as num?)?.toInt() ?? 0;
    final avatar = '${r['avatar_url'] ?? ''}';
    final display = '${r['display_name'] ?? ''}'.trim();
    final coins = (r['coins'] as num?)?.toInt() ?? 0;
    final p = _QP.of(ctx);
    return Container(
      key: ValueKey('quiz_rank_$rank'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? _green.withOpacity(.16) : p.fill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: mine ? _green.withOpacity(.6) : rank <= 3 ? _medals[(rank - 1).clamp(0, 2)].withOpacity(.45) : Colors.transparent),
      ),
      child: Row(children: [
        SizedBox(
          width: 34,
          child: rank >= 1 && rank <= 3
              ? Icon(Icons.emoji_events_rounded, color: _medals[rank - 1], size: 24)
              : Text('$rank', textAlign: TextAlign.center, style: TextStyle(color: p.text2, fontSize: 15, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          radius: 18,
          backgroundColor: p.line2,
          backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
          onBackgroundImageError: avatar.isNotEmpty ? (_, __) {} : null,
          child: avatar.isEmpty ? Icon(Icons.person_rounded, color: p.icon, size: 20) : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(plainName ? '${r['username']}' : '@${r['username'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text, fontSize: 14, fontWeight: FontWeight.w800)),
            Text(display.isNotEmpty && !plainName ? display : ctx.tr('{c} sur {q} bonnes réponses', {'c': r['correct'] ?? 0, 'q': q}),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.text3, fontSize: 11.5)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(ctx.tr('{n} pts', {'n': CoinCheckout.fmt((r['points'] as num?)?.toInt() ?? 0)}), style: TextStyle(color: p.goldText, fontSize: 14, fontWeight: FontWeight.w900)),
          Text(
            display.isNotEmpty && !plainName ? ctx.tr('{c}/{q} justes', {'c': r['correct'] ?? 0, 'q': q}) : coins > 0 ? '+${CoinCheckout.fmt(coins)}' : '',
            style: TextStyle(color: p.text3, fontSize: 11),
          ),
        ]),
      ]),
    );
  }
}
