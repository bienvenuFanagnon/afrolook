import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/tr.dart';
import '../services/read_meter.dart';
import '../theme/app_colors.dart';

/// « Gagné grâce aux tâches » : total des pièces obtenues avec le mur de tâches (Tapjoy, ayeT-Studios), validées + en attente,
/// affiché sur la page des tâches ET sur la page Monétisation. Ces pièces sont créditées dans les Pièces gagnées une fois
/// validées (délai de 48 h) : ce bloc sert seulement à les montrer à part, il ne change aucun solde.
/// Lit Users/{id} (champs écrits par le serveur : totalOfferwallCoinsEarned, offerwallPendingCoins) ; invisible tant que le total est nul.
class OfferwallEarningsCard extends StatelessWidget {
  const OfferwallEarningsCard({super.key, required this.userId, this.compact = false});

  final String userId;
  final bool compact;

  static final NumberFormat _n = NumberFormat.decimalPattern('fr');

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) return const SizedBox.shrink();
    final c = AppColors.of(context);
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('Users').doc(userId).getM('offerwall_earnings_card'),
      builder: (context, snap) {
        final d = snap.data?.data();
        final earned = ((d?['totalOfferwallCoinsEarned'] as num?) ?? 0).toInt();
        final pending = ((d?['offerwallPendingCoins'] as num?) ?? 0).toInt().clamp(0, 1 << 31);
        final total = earned + pending;
        if (total <= 0) return const SizedBox.shrink();
        return Container(
          margin: EdgeInsets.only(top: compact ? 8 : 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: c.primary.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(Icons.task_alt_rounded, color: c.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tr('Gagné grâce aux tâches'), style: TextStyle(color: c.textSecondary, fontSize: 12)),
                const SizedBox(height: 2),
                Text('${_n.format(total)} ${context.tr('pièces')}', style: TextStyle(color: c.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
                Text(
                  pending > 0
                      ? '≈ ${_n.format((total * 0.4).round())} FCFA · ${context.tr('dont {n} en attente de validation', {'n': _n.format(pending)})}'
                      : '≈ ${_n.format((total * 0.4).round())} FCFA',
                  style: TextStyle(color: c.textSecondary, fontSize: 11.5),
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }
}
