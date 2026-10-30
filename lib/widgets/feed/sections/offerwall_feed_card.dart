import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../l10n/tr.dart';
import '../../../pages/offerwall/offerwall_tasks_page.dart';
import '../../../services/offerwall/offerwall_promo.dart';
import '../../../services/offerwall/offerwall_service.dart';
import '../../../services/share/share_service.dart';
import '../../../theme/app_colors.dart';

/// Carte du fil « Travaille dans Afrolook et gagne de l'argent » : explique que les tâches sont un travail payé (jusqu'à X F par jour) et que les pièces gagnées
/// se convertissent en argent réel. Distincte de la carte « Un cadeau t'attend » (pub récompensée). Voir docs/OFFERWALL_TACHES.md §18.
///
/// Garde-fous : toujours affichée (pas de limite par jour), seulement si les tâches sont disponibles pour la personne
/// (clé de la régie, interrupteurs du serveur, compte non suspendu) ; la croix masque la carte 2 jours.
class OfferwallFeedCard extends StatefulWidget {
  const OfferwallFeedCard({Key? key, this.slot = 1}) : super(key: key);

  /// Emplacement dans le fil (1 = début, 2 = plus loin, 3 = fin) : un affichage par emplacement et par ouverture du fil.
  final int slot;

  @override
  State<OfferwallFeedCard> createState() => _OfferwallFeedCardState();
}

class _OfferwallFeedCardState extends State<OfferwallFeedCard> {
  static const _kHiddenUntil = 'offerwall_card_hidden_until';

  /// Décisions de la session : emplacement → affiché ou non (évite de recompter à chaque reconstruction).
  static final Map<int, bool> _decided = {};

  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var show = false;
    try {
      if (_decided.containsKey(widget.slot)) {
        show = _decided[widget.slot]!;
      } else {
        final sp = await SharedPreferences.getInstance();
        final now = DateTime.now().millisecondsSinceEpoch;
        // toujours affichée quand les tâches sont disponibles pour la personne (décision du propriétaire, 28/10/2026) : plus de limite par jour ;
        // seule la croix la masque 2 jours (ignorée en développement pour pouvoir la revoir)
        if ((kDebugMode || now >= (sp.getInt(_kHiddenUntil) ?? 0)) && await OfferwallService.isAvailable()) show = true;
        _decided[widget.slot] = show;
      }
    } catch (_) {}
    if (mounted) setState(() => _visible = show);
  }

  Future<void> _dismiss() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setInt(_kHiddenUntil, DateTime.now().add(const Duration(days: 2)).millisecondsSinceEpoch);
    } catch (_) {}
    if (mounted) setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final c = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c.primary.withOpacity(0.2), c.surface]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.primary.withOpacity(0.5)),
      ),
      child: Row(children: [
        const Text('💼', style: TextStyle(fontSize: 30)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(OfferwallService.isConfigured ? context.tr('Travaille dans Afrolook et gagne de l\'argent') : context.tr('Travaille et gagne de l\'argent'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 2),
            Text(
              OfferwallService.isConfigured
                  ? context.tr('Accomplis des tâches et gagne jusqu\'à {a} F par jour. Tes pièces se convertissent en argent réel.', {'a': OfferwallPromo.f(OfferwallPromo.maxPerDayFcfa)})
                  : context.tr('Partage des annonces sur WhatsApp, Telegram, Facebook… et gagne de l\'argent : environ {f} F par clic valide, jusqu\'à {m} F par jour.', {'f': ShareService.lastPerClickFcfa.round(), 'm': ShareService.lastDailyCapFcfa.round()}),
              style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.3),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OfferwallTasksPage())),
          style: ElevatedButton.styleFrom(
            backgroundColor: c.primary,
            foregroundColor: c.onPrimary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
          child: Text(context.tr('Voir les tâches'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        ),
        GestureDetector(
          onTap: _dismiss,
          child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.close_rounded, size: 18, color: c.textSecondary)),
        ),
      ]),
    );
  }
}
