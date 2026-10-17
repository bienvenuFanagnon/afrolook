import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/tr.dart';
import '../../providers/authProvider.dart';
import '../../services/follower_milestone.dart';
import 'card_entry.dart';
import 'card_models.dart';

/// Un cap d'abonnés franchi (100, 500, 1 000, 10 000…) : l'application propose, une fois par cap, la carte de remerciement.
class CardMilestone {
  CardMilestone._();

  static Future<void> maybeShow(BuildContext context) async {
    if (kIsWeb) return;
    final me = context.read<UserAuthProvider>().loginUserData;
    final uid = me.id;
    if (uid == null || uid.isEmpty) return;
    final m = await FollowerMilestone.claim(uid, me.followersCount);
    if (m == null || !context.mounted) return;
    final go = await showDialog<bool>(context: context, builder: (_) => CardMilestoneDialog(milestone: m));
    if (go == true && context.mounted) {
      await CardEntry.openCompose(context, template: CardTemplateId.thanks);
    }
  }
}

class CardMilestoneDialog extends StatelessWidget {
  const CardMilestoneDialog({super.key, required this.milestone});
  final int milestone;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          color: const Color(0xFF111111),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              height: 150,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF6A1B9A), Color(0xFFE91E63), Color(0xFFFFB400)])),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('🎉', style: TextStyle(fontSize: 38)),
                Text(FollowerMilestone.format(milestone), style: const TextStyle(color: Colors.white, fontSize: 46, fontWeight: FontWeight.w900, height: 1.05)),
                Text(tr('abonnés').toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 4)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
              child: Column(children: [
                Text(tr('Plus de {n} abonnés !', {'n': FollowerMilestone.format(milestone)}), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, height: 1.2)),
                const SizedBox(height: 10),
                Text(tr('Remercie ta communauté avec une carte : le nombre est déjà rempli, tu choisis le style et tu publies.'), textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14.5, height: 1.4)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
              child: Column(children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), backgroundColor: const Color(0xFF2ECC71), foregroundColor: const Color(0xFF0E0E0E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.volunteer_activism_rounded),
                    label: Text(tr('Créer ma carte de remerciement'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
                TextButton(onPressed: () => Navigator.pop(context, false), child: Text(tr('Plus tard'), style: const TextStyle(color: Color(0xFF9E9E9E)))),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
