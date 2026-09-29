import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/tr.dart';
import '../pages/coins/coin_recharge_screen.dart';
import '../providers/coin_gift_provider.dart';
import '../theme/app_colors.dart';

/// Règle d'inactivité des comptes : après 20 jours sans publication, un compte qui a déjà publié ne peut plus
/// publier (profil ou canal) ni créer de canal, de groupe ou de live tant qu'il n'est pas débloqué en pièces.
/// Le serveur applique la règle (publication refusée) ; cette porte affiche le blocage et propose le déblocage
/// AVANT d'ouvrir l'écran de création.
class AccountGate {
  static DateTime? _okUntil;

  /// true si le compte peut publier / créer (éventuellement après déblocage), false sinon.
  static Future<bool> ensureCanPublish(BuildContext context) async {
    final until = _okUntil;
    if (until != null && DateTime.now().isBefore(until)) return true;
    try {
      final r = await FirebaseFunctions.instance.httpsCallable('accountPublishStatus').call();
      final st = Map<String, dynamic>.from(r.data as Map);
      if (st['blocked'] != true) {
        _okUntil = DateTime.now().add(const Duration(minutes: 5));
        return true;
      }
      if (!context.mounted) return false;
      final ok = await _showBlocked(context, (st['cost'] as num?)?.toInt() ?? 0, (st['daysInactive'] as num?)?.toInt() ?? 20);
      if (ok) _okUntil = DateTime.now().add(const Duration(minutes: 5));
      return ok;
    } catch (_) {
      // Réseau ou serveur indisponible : on laisse passer, le serveur refusera de toute façon une publication non autorisée
      return true;
    }
  }

  static Future<bool> _showBlocked(BuildContext context, int cost, int days) async {
    final unlocked = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _BlockedDialog(cost: cost, days: days, parent: context),
    );
    return unlocked == true;
  }
}

class _BlockedDialog extends StatefulWidget {
  final int cost;
  final int days;
  final BuildContext parent;
  const _BlockedDialog({required this.cost, required this.days, required this.parent});

  @override
  State<_BlockedDialog> createState() => _BlockedDialogState();
}

class _BlockedDialogState extends State<_BlockedDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _unlock() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseFunctions.instance.httpsCallable('unlockAccount').call();
      try {
        final coin = Provider.of<CoinGiftUserProvider>(context, listen: false);
        final uid = coin.currentUser?.id;
        if (uid != null) await coin.refreshBalance(uid);
      } catch (_) {}
      if (mounted) Navigator.pop(context, true);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.code == 'resource-exhausted'
            ? context.tr('Il te faut {a} pièces pour débloquer ton compte.', {'a': widget.cost})
            : (e.message ?? context.tr('Déblocage impossible'));
      });
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return AlertDialog(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Icon(Icons.lock_rounded, color: c.danger),
        const SizedBox(width: 8),
        Expanded(child: Text(context.tr('Compte bloqué'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800))),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          context.tr('Tu n\'as rien publié depuis {a} jours. Tant que ton compte n\'est pas débloqué, tu ne peux pas publier, ni créer de canal, de groupe ou de live.', {'a': widget.days}),
          style: TextStyle(color: c.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 10),
        Text(context.tr('Déblocage : {a} pièces (selon ton nombre d\'abonnés)', {'a': widget.cost}),
            style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: c.danger, fontWeight: FontWeight.w700, fontSize: 12.5)),
        ],
        if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
      ]),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(context.tr('Annuler')),
        ),
        if (_error != null && _error!.contains('${widget.cost}'))
          TextButton(
            onPressed: () {
              Navigator.pop(context, false);
              Navigator.push(widget.parent, MaterialPageRoute(builder: (_) => const CoinRechargeScreen()));
            },
            child: Text(context.tr('Acheter des pièces')),
          ),
        FilledButton(
          onPressed: _busy ? null : _unlock,
          child: Text(context.tr('Débloquer · {a} pièces', {'a': widget.cost})),
        ),
      ],
    );
  }
}
