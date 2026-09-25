import 'package:flutter/material.dart';

import '../models/model_data.dart';
import '../theme/app_colors.dart';
import '../utils/tx_amount.dart';

/// Les deux soldes de pièces, côte à côte : Pièces de dépôt (achetées, dépensables)
/// et Pièces gagnées (convertibles en argent). Même calcul que le serveur (coin_locks.ts).
class CoinBalancesRow extends StatelessWidget {
  final UserData? user;
  /// Phrase affichée sous les soldes (ex. : où vont les pièces achetées).
  final String? note;

  const CoinBalancesRow({super.key, required this.user, this.note});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final depot = user?.lockedGiftCoins ?? 0;
    final gagnees = user?.convertibleGiftCoins ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(child: _balance(c, Icons.toll_rounded, c.supportAccent, 'Pièces de dépôt', depot)),
                VerticalDivider(width: 20, thickness: 1, color: c.border),
                Expanded(child: _balance(c, Icons.emoji_events_rounded, c.primary, 'Pièces gagnées', gagnees)),
              ],
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: c.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(note!, style: TextStyle(color: c.textSecondary, fontSize: 11.5, height: 1.35)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _balance(AppColors c, IconData icon, Color color, String label, int coins) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: c.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            TxAmount.fmt(coins),
            style: TextStyle(
              color: c.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Text('pièces', style: TextStyle(color: c.textSecondary, fontSize: 11)),
      ],
    );
  }
}
