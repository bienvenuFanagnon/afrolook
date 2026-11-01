import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/pages/chat/group/group_earnings_page.dart';
import 'package:afrotok/services/api/groups_b2_api.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_colors.dart';

/// Ce qu'un groupe privé payant a rapporté à son propriétaire (`GET /groups/{id}/earnings` : sa part, en pièces gagnées).
/// Affichée seulement au-delà de 1 pièce ; un appui ouvre l'écran des gains avec le détail des entrées.
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
      final e = await GroupsB2Api.earnings(widget.groupId, limit: 1);
      if (mounted) setState(() { _coins = e.coins; _entries = e.entriesCount; _loaded = true; });
    } catch (_) {
      // La carte n'est qu'un résumé : sans réponse elle reste masquée (le détail, lui, propose « Réessayer »)
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _coins <= 1) return const SizedBox.shrink();
    final c = AppColors.of(context);
    final n = NumberFormat.decimalPattern(Localizations.localeOf(context).languageCode);
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupEarningsPage(groupId: widget.groupId))),
      child: Container(
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
              Text(tr('Ce groupe t\'a rapporté'), style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              Text(tr('{n} pièces', {'n': n.format(_coins)}), style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
            ]),
          ),
          Text(_entries > 1 ? tr('{n} entrées payantes', {'n': _entries}) : tr('{n} entrée payante', {'n': _entries}), style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
          Icon(Icons.chevron_right, color: c.textSecondary, size: 18),
        ]),
      ),
    );
  }
}
