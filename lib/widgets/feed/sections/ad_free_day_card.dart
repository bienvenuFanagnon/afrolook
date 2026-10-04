import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../ads/rewards_service.dart';
import '../../../pages/rewards/rewards_page.dart';
import '../../../l10n/tr.dart';
import '../../../providers/authProvider.dart';
import '../../../theme/app_colors.dart';

/// Carte du feed qui mène à la page « Récompenses » (Premium gratuit, journée sans pub, pièces…).
/// Affichée au plus une fois par jour et par appareil, seulement si les pubs sont actives pour la
/// personne (jamais pour un Gold) ; la croix la masque 3 jours.
class AdFreeDayCard extends StatefulWidget {
  const AdFreeDayCard({Key? key}) : super(key: key);

  @override
  State<AdFreeDayCard> createState() => _AdFreeDayCardState();
}

class _AdFreeDayCardState extends State<AdFreeDayCard> {
  static const _kDay = 'ad_free_card_day';
  static const _kHiddenUntil = 'ad_free_card_hidden_until';
  /// Décision du jour prise par la 1re carte de la session (les suivantes la suivent).
  static bool? _showToday;

  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  Future<void> _load() async {
    var show = false;
    try {
      if (_showToday != null) {
        show = _showToday!;
      } else {
        final sp = await SharedPreferences.getInstance();
        final now = DateTime.now().millisecondsSinceEpoch;
        final hidden = sp.getInt(_kHiddenUntil) ?? 0;
        show = now >= hidden && sp.getString(_kDay) != _today();
        if (show) await sp.setString(_kDay, _today());
        _showToday = show;
      }
    } catch (_) {}
    if (mounted) setState(() => _visible = show);
  }

  Future<void> _dismiss() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setInt(_kHiddenUntil, DateTime.now().add(const Duration(days: 3)).millisecondsSinceEpoch);
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
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: colors.accent.withOpacity(0.18), shape: BoxShape.circle),
          child: Icon(Icons.volunteer_activism_rounded, color: colors.accent, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('Récompenses gratuites'),
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 2),
            Text(context.tr('Regarde des pubs : Premium gratuit, journée sans pub, pièces cadeau…'),
                style: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.3)),
          ]),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RewardsPage())),
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: colors.onPrimary,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
          child: Text(context.tr('Voir'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
        ),
        GestureDetector(
          onTap: _dismiss,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(Icons.close_rounded, size: 18, color: colors.textSecondary),
          ),
        ),
      ]),
    );
  }
}
