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
  Map<String, dynamic> _overview = const {};
  String _period = 'today';   // today | 7d | 30d
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
        LiveShopApi.adminOverview(period: _period),
      ]);
      if (!mounted) return;
      setState(() { _stats = r[0] as Map<String, dynamic>; _disputes = r[1] as List<Map<String, dynamic>>; _orders = r[2] as List<Map<String, dynamic>>; _overview = r[3] as Map<String, dynamic>; _loading = false; });
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

  /// Vue d'ensemble unique : ventes par type, marchés et étals, gains des lives, minutes Agora.
  Widget _overviewView(AppColors c) {
    final o = _overview;
    final sales = (o['sales'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final market = (o['market'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final agora = (o['agora'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final kinds = ((sales['by_kind'] as List?) ?? const []).whereType<Map>().toList();
    final liveCoins = ((o['live_coins'] as List?) ?? const []).whereType<Map>().toList();
    final stalls = (market['stalls_now'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    int i(Object? v) => (v as num?)?.toInt() ?? 0;
    String kindName(String k) => switch (k) { 'live' => tr('Vente en direct'), 'market' => tr('Marché (étals)'), _ => tr('Boutique (hors live)') };
    String srcName(String k) => switch (k) {
          'cadeaux_live' => tr('Cadeaux en live'),
          'participation_live' => tr('Billets, frais de diffusion, places'),
          'etals_marche' => tr('Loyers des étals'),
          'contes_live' => tr('Contes (votes)'),
          'tirage_live' => tr('Tirages au sort'),
          'quiz_live' => tr('Quiz à cagnotte'),
          _ => tr('Lives privés'),
        };
    Widget title(String t) => Padding(padding: const EdgeInsets.fromLTRB(2, 18, 2, 8), child: Text(t.toUpperCase(), style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)));
    Widget box(List<Widget> kids) => Container(padding: const EdgeInsets.fromLTRB(14, 10, 14, 10), decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)), child: Column(children: kids));
    Widget line(String k, String v, {String? sub, bool alert = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(k, style: TextStyle(color: c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600))),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(v, style: TextStyle(color: alert ? c.danger : c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w800)),
              if (sub != null) Text(sub, style: TextStyle(color: c.textSecondary, fontSize: 11)),
            ]),
          ]),
        );
    final used = i(agora['used_minutes']);
    final pool = i(agora['pool_minutes']);
    final ticket = '${agora['mode']}' == 'ticket';
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(key: const ValueKey('hub_overview'), padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
        Wrap(spacing: 8, children: [
          for (final p in const [('today', 'Aujourd\'hui'), ('7d', '7 jours'), ('30d', '30 jours')])
            ChoiceChip(label: Text(tr(p.$2)), selected: _period == p.$1, onSelected: (_) { setState(() => _period = p.$1); _load(); }),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _stat(c, tr('Commission sur les ventes'), _f(i(sales['commission_xof']))),
          const SizedBox(width: 10),
          _stat(c, tr('Ventes passées'), _f(i(sales['sales_xof']))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _stat(c, tr('En séquestre'), _f(i(sales['in_escrow_xof']))),
          const SizedBox(width: 10),
          _stat(c, tr('À valider / litiges'), '${i(sales['to_validate'])} / ${i(sales['disputes_open'])}'),
        ]),
        title(tr('Ventes par type')),
        box([for (final k in kinds) line(kindName('${k['kind']}'), tr('{c} de commission', {'c': _f(i(k['commission_xof']))}), sub: tr('{n} commande(s) · {s} · {d} terminée(s)', {'n': i(k['orders']), 's': _f(i(k['sales_xof'])), 'd': i(k['completed'])}))]),
        title(tr('Marchés et étals')),
        box([
          line(tr('Marchés en cours'), '${i(market['markets_live'])}'),
          line(tr('Étals maintenant'), tr('{a} en vente · {c} appelé(s) · {b} réservé(s)', {'a': i(stalls['active']), 'c': i(stalls['calling']), 'b': i(stalls['booked'])})),
          line(tr('Étals lancés'), '${i(market['stalls_started'])}', sub: tr('{n} vendeur(s) différent(s)', {'n': i(market['vendors'])})),
          line(tr('Loyers payés'), tr('{n} pièces', {'n': _n.format(i(market['rent_coins']))}), sub: tr('part de l\'app : {n} pièces', {'n': _n.format(i(market['app_rent_coins']))})),
        ]),
        title(tr('Gains des lives (pièces)')),
        box([for (final x in liveCoins) line(srcName('${x['source']}'), tr('{n} pièces', {'n': _n.format(i(x['coins']))}))]),
        title(tr('Minutes Agora du mois')),
        box([
          line(ticket ? tr('Gratuit épuisé : billets payants') : tr('Gratuit en cours'), '${_n.format(used)} / ${_n.format(pool)} min', alert: ticket, sub: tr('Afrolook ne paie jamais au-delà du gratuit du mois')),
          Padding(padding: const EdgeInsets.only(top: 6), child: ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(minHeight: 8, value: pool == 0 ? 0 : (used / pool).clamp(0.0, 1.0), backgroundColor: c.border, color: ticket ? c.danger : c.primary))),
        ]),
      ]),
    );
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
      length: 3,
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
            tabs: [Tab(text: tr('Vue d\'ensemble')), Tab(text: '${tr('Litiges')} (${_disputes.length})'), Tab(text: tr('Commandes'))],
          ),
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: c.primary))
            : _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary)), TextButton(onPressed: _load, child: Text(tr('Réessayer')))])))
                : TabBarView(children: [
                    _overviewView(c),
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
