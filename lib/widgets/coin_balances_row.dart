import 'package:flutter/material.dart';

import '../models/model_data.dart';
import '../theme/app_colors.dart';
import '../utils/tx_amount.dart';
import '../l10n/tr.dart';

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
                Expanded(child: _balance(c, Icons.toll_rounded, c.supportAccent, context.tr('Pièces de dépôt'), depot)),
                VerticalDivider(width: 20, thickness: 1, color: c.border),
                Expanded(child: _balance(c, Icons.emoji_events_rounded, c.primary, context.tr('Pièces gagnées'), gagnees)),
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
        Text(tr('pièces'), style: TextStyle(color: c.textSecondary, fontSize: 11)),
      ],
    );
  }
}

/// Répartition du solde total en Pièces de dépôt et Pièces gagnées.
/// [total] : solde le plus récent (ex. CoinGiftUserProvider) ; par défaut celui de [user].
/// Les dépenses consomment d'abord le dépôt, comme sur le serveur.
class CoinSplit {
  final int depot;
  final int gagnees;

  const CoinSplit(this.depot, this.gagnees);

  factory CoinSplit.of(UserData? user, {int? total}) {
    final t = total ?? user?.giftCoinsBalance ?? 0;
    final d = (user?.lockedGiftCoins ?? 0).clamp(0, t < 0 ? 0 : t);
    return CoinSplit(d, (t - d).clamp(0, 1 << 62));
  }

  int get total => depot + gagnees;

  /// « Dépôt 1 200 · Gagnées 4 269 »
  String get label => tr('Dépôt {a} · Gagnées {b}', {'a': TxAmount.fmt(depot), 'b': TxAmount.fmt(gagnees)});
}

/// Les deux soldes sur une ligne, pour les fenêtres d'achat, de cadeau et d'abonnement.
class CoinBalancesInline extends StatelessWidget {
  final UserData? user;
  final int? total;
  /// Couleurs forcées pour les fonds sombres fixes (lives, feuilles de cadeaux).
  final bool onDark;

  const CoinBalancesInline({super.key, required this.user, this.total, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final s = CoinSplit.of(user, total: total);
    final fg = onDark ? Colors.white : c.textPrimary;
    final sub = onDark ? Colors.white70 : c.textSecondary;
    final bg = onDark ? Colors.white.withValues(alpha: 0.08) : c.surface;
    final border = onDark ? Colors.white24 : c.border;

    Widget pill(IconData icon, Color color, String label, int v) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border),
            ),
            child: Row(children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: sub, fontSize: 10.5)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(TxAmount.fmt(v),
                        style: TextStyle(
                            color: fg,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()])),
                  ),
                ]),
              ),
            ]),
          ),
        );

    return Row(children: [
      pill(Icons.toll_rounded, c.supportAccent, context.tr('Pièces de dépôt'), s.depot),
      const SizedBox(width: 8),
      pill(Icons.emoji_events_rounded, c.primary, context.tr('Pièces gagnées'), s.gagnees),
    ]);
  }
}
