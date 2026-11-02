import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/tr.dart';
import '../../services/api/live_shop_api.dart';
import '../../theme/app_colors.dart';
import 'live_settings_admin_page.dart';

/// Administration de la vente en direct (équipe, droit « shop.manage ») : chiffres, litiges à trancher et toutes les commandes,
/// avec le remboursement par l'équipe (acheteur remboursé, sans pénalité) et la libération de l'argent au vendeur (commande expédiée).
class LiveShopAdminPage extends StatefulWidget {
  const LiveShopAdminPage({super.key});

  @override
  State<LiveShopAdminPage> createState() => _LiveShopAdminPageState();
}

class _LiveShopAdminPageState extends State<LiveShopAdminPage> {
  static final NumberFormat _n = NumberFormat.decimalPattern('fr');

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _stats = const {};
  List<Map<String, dynamic>> _disputes = const [];
  List<Map<String, dynamic>> _orders = const [];
  String _status = '';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await Future.wait<dynamic>([
        LiveShopApi.adminStats(),
        LiveShopApi.adminDisputes(),
        LiveShopApi.adminOrders(status: _status.isEmpty ? null : _status, q: _search.text.trim().isEmpty ? null : _search.text.trim()),
      ]);
      if (!mounted) return;
      setState(() { _stats = r[0] as Map<String, dynamic>; _disputes = r[1] as List<Map<String, dynamic>>; _orders = r[2] as List<Map<String, dynamic>>; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = LiveShopApi.message(e); _loading = false; });
    }
  }

  String _f(num v) => '${_n.format(v)} F';

  String _label(String s) => switch (s) {
        'pending_seller' => tr('En attente du vendeur'),
        'pending_buyer' => tr('Frais à accepter'),
        'accepted' => tr('Validée'),
        'shipped' => tr('Expédiée'),
        'completed' => tr('Terminée'),
        'cancelled' => tr('Annulée'),
        'disputed' => tr('Litige'),
        'refunded' => tr('Remboursée'),
        _ => s,
      };

  Future<void> _resolve(Map<String, dynamic> o, String outcome) async {
    final refund = outcome == 'refund';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(refund
            ? tr("Rembourser l'acheteur ({f}) sans pénalité ? Le vendeur ne reçoit rien.", {'f': _f((o['price_xof'] as num?) ?? 0)})
            : tr("Verser l'argent au vendeur ? L'acheteur ne sera pas remboursé.")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Non'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Confirmer'))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await LiveShopApi.adminResolve('${o['id']}', outcome);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Décision enregistrée.'))));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(LiveShopApi.message(e))));
    }
  }

  Widget _stat(AppColors c, String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
          ]),
        ),
      );

  Widget _card(AppColors c, Map<String, dynamic> o, {bool actions = true}) {
    final s = '${o['status']}';
    final open = const {'pending_seller', 'pending_buyer', 'accepted', 'shipped', 'disputed'}.contains(s);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: s == 'disputed' ? c.danger : c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${o['title']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800))),
          Text(_label(s), style: TextStyle(color: s == 'disputed' ? c.danger : c.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 4),
        Text(tr('{p} · acheteur {b} · vendeur {s}', {'p': _f((o['price_xof'] as num?) ?? 0), 'b': '${o['buyer_name'] ?? o['buyer_id']}', 's': '${o['seller_name'] ?? o['seller_id']}'}),
            style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
        if ('${o['dispute_reason'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('« ${o['dispute_reason']} »', style: TextStyle(color: c.textPrimary, fontSize: 12.5))),
        if (actions && open) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton(onPressed: () => _resolve(o, 'refund'), child: Text(tr("Rembourser l'acheteur"))),
            if (s == 'shipped' || s == 'disputed') FilledButton(onPressed: () => _resolve(o, 'release'), child: Text(tr('Payer le vendeur'))),
          ]),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final by = (_stats['orders'] is Map) ? Map<String, dynamic>.from(_stats['orders'] as Map) : const <String, dynamic>{};
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          backgroundColor: c.surface,
          foregroundColor: c.textPrimary,
          title: Text(tr('Vente en direct : administration')),
          actions: [
            IconButton(
              tooltip: tr('Réglages lives et ventes'),
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LiveSettingsAdminPage())),
            ),
          ],
          bottom: TabBar(
            labelColor: c.primary,
            unselectedLabelColor: c.textSecondary,
            indicatorColor: c.primary,
            tabs: [Tab(text: '${tr('Litiges')} (${_disputes.length})'), Tab(text: tr('Commandes'))],
          ),
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: c.primary))
            : _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary)), TextButton(onPressed: _load, child: Text(tr('Réessayer')))])))
                : TabBarView(children: [
                    RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
                        Row(children: [
                          _stat(c, tr('En séquestre'), _f((_stats['in_escrow_xof'] as num?) ?? 0)),
                          const SizedBox(width: 10),
                          _stat(c, tr('Commissions'), _f((_stats['commissions_xof'] as num?) ?? 0)),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          _stat(c, tr('Ventes terminées'), _f((_stats['sales_completed_xof'] as num?) ?? 0)),
                          const SizedBox(width: 10),
                          _stat(c, tr('Commandes terminées'), '${by['completed'] ?? 0}'),
                        ]),
                        const SizedBox(height: 16),
                        if (_disputes.isEmpty) Padding(padding: const EdgeInsets.all(28), child: Center(child: Text(tr('Aucun litige à trancher.'), style: TextStyle(color: c.textSecondary)))),
                        for (final o in _disputes) _card(c, o),
                      ]),
                    ),
                    RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
                        TextField(
                          controller: _search,
                          onSubmitted: (_) => _load(),
                          decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: tr('Article, acheteur ou vendeur'), border: const OutlineInputBorder()),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: [
                            for (final s in const ['', 'pending_seller', 'accepted', 'shipped', 'completed', 'cancelled', 'refunded'])
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: ChoiceChip(
                                  label: Text(s.isEmpty ? tr('Toutes') : _label(s)),
                                  selected: _status == s,
                                  onSelected: (_) { setState(() => _status = s); _load(); },
                                ),
                              ),
                          ]),
                        ),
                        const SizedBox(height: 12),
                        if (_orders.isEmpty) Padding(padding: const EdgeInsets.all(28), child: Center(child: Text(tr('Aucune commande.'), style: TextStyle(color: c.textSecondary)))),
                        for (final o in _orders) _card(c, o),
                      ]),
                    ),
                  ]),
      ),
    );
  }
}
