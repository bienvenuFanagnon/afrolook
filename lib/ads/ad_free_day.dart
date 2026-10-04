import 'package:flutter/material.dart';

import '../models/model_data.dart';
import '../theme/app_colors.dart';
import 'ad_config.dart';
import 'ad_gate.dart';
import 'admob_service.dart';

/// « Regarder une pub pour avoir 1 jour sans pub » (pub récompensée AdMob, au choix de l'utilisateur).
class AdFreeDay {
  AdFreeDay._();

  /// Proposer l'entrée de menu seulement si les pubs sont actives et que la personne en voit.
  static bool available(UserData? user) =>
      AdConfig.isMobile &&
      AdConfig.current.enabled &&
      AdConfig.current.rewardedEnabled &&
      AdConfig.current.unit('rewarded').isNotEmpty &&
      AdGate.userSeesAds(user);

  static Future<void> show(BuildContext context, UserData user) async {
    final colors = AppColors.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Une journée sans publicité', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800)),
        content: Text(
          'Regarde une courte vidéo : tu ne verras plus de publicité pendant 24 heures. '
          'Tu peux le faire ${AdConfig.current.rewardedMaxPerDay} fois par jour au maximum.',
          style: TextStyle(color: colors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Plus tard')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: colors.onPrimary),
            child: const Text('Regarder'),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    void say(String t) => messenger.showSnackBar(SnackBar(content: Text(t), duration: const Duration(seconds: 3)));

    AdmobService.loadRewarded();
    // La pub se charge en quelques secondes : on attend un peu avant d'abandonner
    for (var i = 0; i < 20 && !AdmobService.rewardedReady; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    final shown = AdmobService.showRewarded(onEarned: () async {
      final until = await AdmobService.claimAdFreeDay();
      if (until == null) {
        say('Impossible d\'activer la journée sans pub (limite du jour atteinte ?).');
        return;
      }
      user.adFreeUntil = until;
      say('C\'est activé : plus de publicité pendant 24 heures. 🎉');
    });
    if (!shown) say('Aucune vidéo disponible pour le moment, réessaie dans un instant.');
  }
}
