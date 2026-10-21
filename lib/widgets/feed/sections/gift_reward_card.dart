import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../ads/rewards_service.dart';
import '../../../l10n/tr.dart';
import '../../../pages/rewards/rewards_page.dart';
import '../../../providers/authProvider.dart';
import '../../../theme/app_colors.dart';

/// Carte « Un cadeau t'attend » dans le fil : la personne récupère 2 pièces cadeau après une courte vidéo (pub récompensée). Un touché lance directement la
/// vidéo (page Récompenses ouverte sur l'offre, qui garde toute la vérification serveur et les plafonds).
///
/// Garde-fous : au plus [_maxPerDay] affichages par jour et par appareil, seulement si les pubs récompensées sont proposées à la personne (jamais pour
/// un Gold), la croix masque la carte 2 jours. Réglable à distance : AppConfig/rewards (interrupteur général et offre coins_2).
class GiftRewardCard extends StatefulWidget {
  const GiftRewardCard({Key? key, this.slot = 1}) : super(key: key);

  /// Numéro de l'emplacement dans le fil (1 = milieu, 2 = fin) : un seul affichage par emplacement et par jour.
  final int slot;

  @override
  State<GiftRewardCard> createState() => _GiftRewardCardState();
}

class _GiftRewardCardState extends State<GiftRewardCard> {
  static const _maxPerDay = 2;
  static const _kHiddenUntil = 'gift_card_hidden_until';
  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

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
        final day = _today();
        if (now >= (sp.getInt(_kHiddenUntil) ?? 0)) {
          final used = sp.getInt('gift_card_count_$day') ?? 0;
          if (used < _maxPerDay) {
            show = true;
            await sp.setInt('gift_card_count_$day', used + 1);
          }
        }
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
    final user = context.watch<UserAuthProvider>().loginUserData;
    if (!_visible || !RewardsService.available(user)) return const SizedBox.shrink();
    final colors = AppColors.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colors.accent.withOpacity(0.22), colors.surface]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.accent.withOpacity(0.5)),
      ),
      child: Row(children: [
        const Text('🎁', style: TextStyle(fontSize: 30)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('Un cadeau t\'attend !'), style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 2),
            Text(context.tr('2 pièces offertes après une courte vidéo. Récupère-les maintenant.'),
                style: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.3)),
          ]),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RewardsPage(autoOffer: 'coins_2'))),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
          child: Text(context.tr('Récupérer'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        ),
        GestureDetector(
          onTap: _dismiss,
          child: Padding(padding: const EdgeInsets.all(8), child: Icon(Icons.close_rounded, size: 18, color: colors.textSecondary)),
        ),
      ]),
    );
  }
}
