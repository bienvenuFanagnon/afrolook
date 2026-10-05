import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../ads/ad_config.dart';
import '../../../ads/ad_gate.dart';
import '../../../ads/admob_service.dart';
import '../../../l10n/tr.dart';
import '../../../providers/authProvider.dart';
import '../../../services/quiz/quiz_service.dart';
import '../../../services/quiz/quiz_sound.dart';
import '../../../theme/app_colors.dart';
import 'hawk_mascot.dart';
import 'quiz_widgets.dart';

/// Peut-on proposer une vidéo récompensée à ce joueur ? (pubs actives pour lui, jamais pour un Gold)
bool quizCanOfferRewarded(BuildContext context) {
  final cfg = QuizService.instance.config;
  if (!cfg.adsEnabled) return false;
  final user = context.read<UserAuthProvider>().loginUserData;
  return AdGate.canShowType(user, 'rewarded') && AdConfig.current.rewardsEnabled;
}

/// Fenêtre « Plus de cœurs » : attendre, ou regarder une pub pour récupérer un cœur.
Future<void> showQuizNoHearts(BuildContext context, QuizState state) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _NoHeartsSheet(state: state),
  );
}

class _NoHeartsSheet extends StatefulWidget {
  const _NoHeartsSheet({required this.state});
  final QuizState state;

  @override
  State<_NoHeartsSheet> createState() => _NoHeartsSheetState();
}

class _NoHeartsSheetState extends State<_NoHeartsSheet> {
  late int _left = widget.state.nextHeartInSec;
  Timer? _t;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    AdmobService.loadRewarded();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _left = _left > 0 ? _left - 1 : 0);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _watch() async {
    final uid = QuizService.instance.uid;
    setState(() => _busy = true);
    final ok = await AdmobService.watchRewarded(userId: uid);
    if (!mounted) return;
    if (!ok) {
      setState(() => _busy = false);
      quizToast(context, context.tr("La pub n'est pas disponible pour le moment. Réessaie dans un instant."), error: true);
      return;
    }
    try {
      await QuizService.instance.refillHeart();
      QuizSound.fx(QuizSfx.up);
      if (mounted) {
        Navigator.pop(context);
        quizToast(context, context.tr('+1 cœur !'));
      }
    } on QuizException {
      if (mounted) {
        setState(() => _busy = false);
        quizToast(context, context.tr("Tu as atteint la limite de cœurs offerts aujourd'hui."), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final canWatch = quizCanOfferRewarded(context) && widget.state.refillsLeft > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: c.border),
      ),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 44, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          const HawkMascot(mood: HawkMood.sad, size: 110),
          const SizedBox(height: 8),
          Text(context.tr('Plus de cœurs'),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: c.textPrimary)),
          const SizedBox(height: 6),
          Text(
            _left > 0
                ? context.tr('Prochain cœur dans {t}', {'t': quizClock(_left)})
                : context.tr('Un cœur est revenu, tu peux jouer !'),
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 18),
          if (canWatch)
            QuizChunkyButton(
              label: context.tr('Regarder une pub : +1 cœur'),
              icon: Icons.play_circle_fill_rounded,
              color: c.accent,
              textColor: c.onAccent,
              loading: _busy,
              onPressed: _watch,
            ),
          const SizedBox(height: 4),
          QuizChunkyButton(
            label: context.tr(_left > 0 ? "J'attends" : 'Continuer'),
            color: c.surfaceVariant,
            textColor: c.textPrimary,
            onPressed: () => Navigator.pop(context),
          ),
        ]),
      ),
    );
  }
}
