import 'package:afrolook_api_client/afrolook_api_client.dart';
import 'package:flutter/material.dart';

import '../l10n/tr.dart';
import '../pages/user/userAbonnementPage.dart';
import '../services/api/regie_api.dart';
import '../theme/app_colors.dart';
import 'rewards_service.dart';

/// Portes Gold du Studio : l'export d'une création et les fonctions importantes sont libres avec Gold (ou une passe Gold gagnée avec des pubs) ;
/// sinon on propose de regarder des pubs plein écran (le serveur compte les pubs et décide) ou de passer Gold. Publier dans Afrolook reste toujours libre.
class GoldGate {
  GoldGate._();

  /// Export (enregistrer, partager hors d'Afrolook) : `true` si c'est permis (Gold, passe ou crédit d'export consommé).
  static Future<bool> export(BuildContext context, String uid) async {
    await RewardsService.loadConfig(force: true);
    try {
      await RegieApi.rewardsExport();
      return true;
    } on ApiException catch (e) {
      if (e.status != 402) {
        _say(context, e.message.isNotEmpty ? e.message : context.tr('Export impossible pour le moment.'));
        return false;
      }
    }
    if (!context.mounted) return false;
    final ads = RewardsService.exportAds;
    final choice = await _ask(
      context,
      title: context.tr('Exporter ta création'),
      text: context.tr('L\'export est libre avec le plan Gold. Sinon, regarde {n} pubs plein écran pour exporter cette création. Tu peux toujours la publier dans Afrolook gratuitement.', {'n': ads}),
      ads: ads,
    );
    if (choice == _Choice.gold) {
      if (context.mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => const AbonnementScreen()));
      return false;
    }
    if (choice != _Choice.ads || !context.mounted) return false;
    if (!await _watch(context, 'export', uid)) return false;
    try {
      await RegieApi.rewardsExport();
      return true;
    } on ApiException catch (e) {
      if (context.mounted) _say(context, e.message);
      return false;
    }
  }

  /// Fonction du Studio (clé du serveur) : `true` si elle est ouverte (Gold, passe ou débloquée aujourd'hui avec des pubs).
  static Future<bool> feature(BuildContext context, String uid, String key) async {
    await RewardsService.loadConfig();
    if (RewardsService.featureUnlocked(key)) return true;
    if (!context.mounted) return false;
    final ads = RewardsService.featureAds(key);
    final choice = await _ask(
      context,
      title: RewardsService.featureLabel(key),
      text: context.tr('Cette fonction est incluse dans le plan Gold. Sinon, regarde {n} pubs plein écran : elle reste ouverte jusqu\'à la fin de la journée.', {'n': ads}),
      ads: ads,
    );
    if (choice == _Choice.gold) {
      if (context.mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => const AbonnementScreen()));
      return false;
    }
    if (choice != _Choice.ads || !context.mounted) return false;
    final ok = await _watch(context, 'feature:$key', uid);
    if (ok) await RewardsService.loadConfig(force: true);
    return ok && RewardsService.featureUnlocked(key);
  }

  static Future<bool> _watch(BuildContext context, String offerId, String uid) async {
    try {
      final done = await RewardsService.watchAndClaim(offerId, uid);
      if (!done && context.mounted) _say(context, context.tr('Aucune vidéo disponible pour le moment, réessaie dans un instant.'));
      return done;
    } on ApiException catch (e) {
      if (context.mounted) _say(context, e.message.isNotEmpty ? e.message : context.tr('Impossible d\'obtenir la récompense pour le moment.'));
      return false;
    }
  }

  static void _say(BuildContext context, String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  static Future<_Choice?> _ask(BuildContext context, {required String title, required String text, required int ads}) {
    final c = AppColors.of(context);
    return showModalBottomSheet<_Choice>(
      context: context,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.workspace_premium_rounded, color: c.accentText),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w900))),
            ]),
            const SizedBox(height: 8),
            Text(text, style: TextStyle(color: c.textSecondary, fontSize: 14, height: 1.4)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('gate_ads'),
                onPressed: () => Navigator.pop(ctx, _Choice.ads),
                icon: const Icon(Icons.ondemand_video_rounded),
                label: Text(context.tr(ads > 1 ? 'Regarder {n} pubs' : 'Regarder {n} pub', {'n': ads})),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const ValueKey('gate_gold'),
                onPressed: () => Navigator.pop(ctx, _Choice.gold),
                child: Text(context.tr('Passer Gold · {p} F par mois', {'p': RewardsService.goldPriceMonth})),
              ),
            ),
            Center(child: TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.tr('Plus tard')))),
          ]),
        ),
      ),
    );
  }
}

enum _Choice { ads, gold }
