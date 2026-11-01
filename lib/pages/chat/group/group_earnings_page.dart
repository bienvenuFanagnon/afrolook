import 'package:afrotok/l10n/tr.dart';
import 'package:afrotok/services/api/groups_b2_api.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Gains d'un groupe payant (`GET /groups/{id}/earnings`) : total de MA part de créateur (pièces gagnées, convertibles) et une ligne par abonnement
/// ou renouvellement payé en pièces. Réservé au propriétaire du groupe (et à l'équipe) ; un groupe gratuit n'a rien à montrer.
class GroupEarningsPage extends StatefulWidget {
  const GroupEarningsPage({super.key, required this.groupId});

  final String groupId;

  @override
  State<GroupEarningsPage> createState() => _GroupEarningsPageState();
}

class _GroupEarningsPageState extends State<GroupEarningsPage> {
  final List<GroupEarningEntry> _entries = [];
  int _coins = 0;
  int _count = 0;
  String? _next;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final e = await GroupsB2Api.earnings(widget.groupId);
      if (!mounted) return;
      setState(() {
        _entries
          ..clear()
          ..addAll(e.entries);
        _coins = e.coins;
        _count = e.entriesCount;
        _next = e.next;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = GroupMessages.of(e);
        _loading = false;
      });
    }
  }

  Future<void> _more() async {
    if (_next == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final e = await GroupsB2Api.earnings(widget.groupId, cursor: _next);
      if (!mounted) return;
      setState(() {
        _entries.addAll(e.entries);
        _next = e.next;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(GroupMessages.of(e)),
        action: SnackBarAction(label: tr('Réessayer'), onPressed: _more),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final nf = NumberFormat.decimalPattern(lang);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        iconTheme: IconThemeData(color: c.textPrimary),
        title: Text(tr('Gains du groupe'), style: TextStyle(color: c.textPrimary, fontSize: 17)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary)),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _load, child: Text(tr('Réessayer'))),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF5C542).withOpacity(0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.savings_outlined, color: Color(0xFFF5C542), size: 30),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(tr('Total de tes gains'), style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                                  Text(tr('{n} pièces', {'n': nf.format(_coins)}), style: TextStyle(color: c.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
                                  Text(tr('Pièces gagnées : tu peux les convertir en argent.'), style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _count == 1 ? tr('{n} entrée payante', {'n': _count}) : tr('{n} entrées payantes', {'n': _count}),
                        style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
                      ),
                      const SizedBox(height: 8),
                      if (_entries.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(tr('Aucune entrée payante pour l\'instant.'), textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary)),
                        )
                      else
                        for (final e in _entries)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: c.surfaceVariant,
                              backgroundImage: e.buyerAvatar.isEmpty ? null : NetworkImage(e.buyerAvatar),
                              child: e.buyerAvatar.isEmpty ? Icon(Icons.person, color: c.textSecondary) : null,
                            ),
                            title: Text(e.buyerName.isEmpty ? tr('Membre') : '@${e.buyerName}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600)),
                            subtitle: Text(e.at == null ? '' : DateFormat.yMMMd(lang).add_Hm().format(e.at!.toLocal()), style: TextStyle(color: c.textSecondary, fontSize: 12)),
                            trailing: Text('+${nf.format(e.coins)}', style: const TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.w800, fontSize: 15)),
                          ),
                      if (_next != null)
                        Center(
                          child: _loadingMore
                              ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
                              : TextButton(onPressed: _more, child: Text(tr('Voir plus'))),
                        ),
                    ],
                  ),
                ),
    );
  }
}
