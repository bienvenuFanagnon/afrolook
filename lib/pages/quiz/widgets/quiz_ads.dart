import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../ads/ad_gate.dart';
import '../../../ads/ad_slot.dart';
import '../../../ads/admob_service.dart';
import '../../../ads/module_ads.dart';
import '../../../providers/authProvider.dart';
import '../../pub/afrolook_inline_ad.dart';

/// Pub discrète de Quiz & Étude : une bannière seulement quand l'écran est assez haut
/// (jamais sur un petit écran, jamais pour les comptes Gold). Aucune place vide si aucune pub n'est disponible.
class QuizAdBanner extends StatelessWidget {
  const QuizAdBanner({super.key, this.minHeight = 700, this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 8)});
  final double minHeight;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).size.height < minHeight) return const SizedBox.shrink();
    final user = context.read<UserAuthProvider>().loginUserData;
    if (!ModuleAds.shows(user)) return const SizedBox.shrink();
    return Padding(padding: padding, child: AdSlot(kind: AdSlotKind.detail, own: () => const AfrolookInlineAd(compact: true), admobFirst: true));
  }
}

/// Pub native dans une liste (accueil, classe, chapitre…), toujours entre deux blocs, jamais collée à un bouton.
class QuizAdInline extends StatelessWidget {
  const QuizAdInline({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<UserAuthProvider>().loginUserData;
    if (!ModuleAds.shows(user)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: AdSlot(kind: AdSlotKind.list, own: () => const AfrolookInlineAd(compact: true), admobFirst: true),
    );
  }
}

/// Pub plein écran à la fin d'un niveau réussi : une fois tous les [every] niveaux, au plus [maxPerDay] par jour.
/// Appelle [then] ensuite (que la pub ait été montrée ou non).
Future<void> levelEndInterstitial(BuildContext context, {required String prefix, int every = 3, int maxPerDay = 6, required VoidCallback then}) async {
  try {
    final user = context.read<UserAuthProvider>().loginUserData;
    if (!ModuleAds.adFree(user) && AdGate.canShowType(user, 'interstitial')) {
      final sp = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final day = '${now.year}-${now.month}-${now.day}';
      if (sp.getString('${prefix}_ad_day') != day) {
        await sp.setString('${prefix}_ad_day', day);
        await sp.setInt('${prefix}_ad_count', 0);
      }
      final since = (sp.getInt('${prefix}_lv_since_ad') ?? 0) + 1;
      final shown = sp.getInt('${prefix}_ad_count') ?? 0;
      if (since >= every && shown < maxPerDay) {
        await sp.setInt('${prefix}_lv_since_ad', 0);
        await sp.setInt('${prefix}_ad_count', shown + 1);
        final ok = await AdmobService.showInterstitialNow(onDismissed: then, onFailed: then);
        if (!ok) then();
        return;
      }
      await sp.setInt('${prefix}_lv_since_ad', since);
    }
  } catch (_) {}
  then();
}
