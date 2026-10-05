import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/tr.dart';
import '../../../pages/quiz/quiz_daily.dart';
import '../../../pages/quiz/quiz_home_page.dart';
import '../../../pages/quiz/widgets/hawk_mascot.dart';
import '../../../pages/quiz/widgets/quiz_widgets.dart';
import '../../../services/quiz/quiz_service.dart';
import '../../../theme/app_colors.dart';

/// Carte du quiz dans le fil.
///  - [slot] 1 : les 3 questions du jour, jouables sans quitter le fil ; une fois terminées, une invitation à continuer l'aventure.
///  - [slot] 3 : fin du fil (plus de posts à voir), avant les widgets de fin : les questions du jour si elles restent, sinon l'invitation à continuer.
///  - [slot] 2 : un rappel plus loin dans le fil, seulement si la personne n'a pas encore joué aujourd'hui.
/// La croix masque la carte jusqu'à demain. Réglable à distance (AppConfig/quiz : enabled, feedCardEnabled).
class QuizFeedCard extends StatefulWidget {
  const QuizFeedCard({super.key, this.slot = 1});
  final int slot;

  @override
  State<QuizFeedCard> createState() => _QuizFeedCardState();
}

class _QuizFeedCardState extends State<QuizFeedCard> {
  static const _kHidden = 'quiz_feed_hidden_day';

  /// Une seule demande au serveur par session, partagée par toutes les cartes du fil.
  static Future<QuizState?>? _shared;
  static DateTime? _sharedAt;

  QuizState? _state;
  bool _dailyOpen = false;
  int _reload = 0;
  bool _ready = false;
  bool _hidden = false;

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var hidden = false;
    try {
      final sp = await SharedPreferences.getInstance();
      hidden = sp.getString(_kHidden) == _today();
    } catch (_) {}
    if (hidden) {
      if (mounted) {
        setState(() {
          _hidden = true;
          _ready = true;
        });
      }
      return;
    }
    final cfg = await QuizService.instance.loadConfig();
    if (!cfg.enabled || !cfg.feedCardEnabled) {
      if (mounted) setState(() => _ready = true);
      return;
    }
    // Les questions du jour décident seules s'il faut montrer le quiz (pas besoin d'attendre la progression) :
    // on les affiche tout de suite si on les a déjà, sinon dès que le serveur les envoie.
    if (widget.slot == 1 || widget.slot == 3) {
      final cached = await QuizService.instance.dailyCached();
      if (cached != null && !cached.done && mounted) {
        setState(() {
          _dailyOpen = true;
          _ready = true;
        });
      }
      QuizService.instance.dailyGet().then((d) {
        if (mounted) setState(() => _dailyOpen = !d.done);
      }).catchError((Object _) {});
    }
    final stale = _sharedAt == null || DateTime.now().difference(_sharedAt!).inMinutes > 10;
    if (_shared == null || stale) {
      _sharedAt = DateTime.now();
      _shared = () async {
        try {
          return await QuizService.instance.refresh();
        } catch (_) {
          return null;
        }
      }();
    }
    final s = await _shared;
    if (mounted) {
      setState(() {
        _state = s;
        _ready = true;
      });
    }
  }

  Future<void> _hide() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_kHidden, _today());
    } catch (_) {}
    if (mounted) setState(() => _hidden = true);
  }

  Future<void> _openQuiz() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizHomePage()));
    _shared = null;
    if (mounted) _load();
  }

  /// Reprendre les questions du jour sur la page du quiz, à la question suivante.
  Future<void> _openDaily() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizDailyPage()));
    _shared = null;
    if (mounted) {
      setState(() => _reload++);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _hidden) return const SizedBox.shrink();
    final c = AppColors.of(context);
    final s = _state;
    final showDaily = (widget.slot == 1 || widget.slot == 3) && _dailyOpen;
    if (!showDaily && s == null) return const SizedBox.shrink();
    if (!showDaily && widget.slot == 2 && s!.playedToday) return const SizedBox.shrink();

    final Widget body = showDaily
        ? QuizDailyPlayer(
            key: ValueKey('daily$_reload'),
            compact: true,
            onContinue: _openQuiz,
            onContinueDaily: _openDaily,
            onFinished: () {
              _shared = null;
            },
          )
        : _invite(c, s!);

    return Stack(children: [
      body,
      Positioned(
        top: 14,
        right: 20,
        child: GestureDetector(
          onTap: _hide,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(color: c.surfaceVariant, shape: BoxShape.circle),
            child: Icon(Icons.close_rounded, size: 16, color: c.textSecondary),
          ),
        ),
      ),
    ]);
  }

  Widget _invite(AppColors c, QuizState s) {
    final String msg;
    if (s.finishedAll) {
      msg = context.tr('Tu as tout terminé ! Reviens voir les nouveautés.');
    } else if (!s.playedToday && s.streak > 0) {
      msg = context.tr('Ne perds pas ta série de {n} jours !', {'n': s.streak});
    } else if (s.completed == 0) {
      msg = context.tr("Salut, je suis ton guide ! Commençons l'aventure.");
    } else {
      msg = context.tr('Le niveau {n} t’attend !', {'n': s.level});
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.primary.withOpacity(0.22), c.surface], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.primary.withOpacity(0.55), width: 1.5),
      ),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          HawkMascot(mood: HawkMood.wave, size: 72, accessory: s.equipped['accessory']),
          const SizedBox(width: 10),
          Expanded(
            child: QuizBubble(
              child: Text(msg, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, height: 1.3, color: c.textPrimary)),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        QuizChunkyButton(
          label: s.completed == 0 ? context.tr('Commencer le quiz') : context.tr('Jouer maintenant'),
          icon: Icons.play_arrow_rounded,
          onPressed: _openQuiz,
        ),
      ]),
    );
  }
}
