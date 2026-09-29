import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_colors.dart';

/// Ce qu'un groupe privé payant a rapporté à son propriétaire (pièces reçues à chaque entrée).
/// Affichée seulement au-delà de 1 pièce. Calculée à partir des transactions : couvre aussi
/// les entrées antérieures à ce suivi.
class GroupRevenueCard extends StatefulWidget {
  final String groupId;
  final String ownerId;
  const GroupRevenueCard({super.key, required this.groupId, required this.ownerId});

  @override
  State<GroupRevenueCard> createState() => _GroupRevenueCardState();
}

class _GroupRevenueCardState extends State<GroupRevenueCard> {
  int _coins = 0;
  int _entries = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('TransactionSoldes')
          .where('user_id', isEqualTo: widget.ownerId)
          .where('purchaseKind', isEqualTo: 'group')
          .where('purchaseRefId', isEqualTo: widget.groupId)
          .get();
      var coins = 0, n = 0;
      for (final d in snap.docs) {
        final t = d.data();
        if (t['type'] != 'GAIN_PIECES') continue;
        coins += (t['montant'] as num? ?? 0).round();
        n++;
      }
      if (mounted) setState(() { _coins = coins; _entries = n; _loaded = true; });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _coins <= 1) return const SizedBox.shrink();
    final c = AppColors.of(context);
    final n = NumberFormat.decimalPattern('fr');
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF5C542).withOpacity(0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.savings_outlined, color: Color(0xFFF5C542), size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ce groupe t\'a rapporté',
                style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            Text('${n.format(_coins)} pièces',
                style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
          ]),
        ),
        Text('$_entries entrée${_entries > 1 ? 's' : ''} payante${_entries > 1 ? 's' : ''}',
            style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
      ]),
    );
  }
}
