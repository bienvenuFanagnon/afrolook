import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/tr.dart';
import '../../services/api/live_shop_api.dart';
import '../../theme/app_colors.dart';

/// Comptabilité des ventes, en consultation seulement :
/// - vendeur : « Solde des ventes » (ventes terminées, commission, net reçu, annulations, argent encore en séquestre) ;
/// - acheteur : « Mes dépenses » (achats payés, remboursements, argent en séquestre).
/// Par période : aujourd'hui, hier, 3 jours, 7 jours, 30 jours ou des dates choisies. L'argent des ventes est déjà sur le solde de gains.
class SalesLedgerPage extends StatefulWidget {
  const SalesLedgerPage({super.key, required this.seller, this.loader});

  final bool seller;

  /// Pour les essais : remplace la lecture sur l'API.
  final Future<Map<String, dynamic>> Function(String from, String to)? loader;

  @override
  State<SalesLedgerPage> createState() => _SalesLedgerPageState();
}

class _SalesLedgerPageState extends State<SalesLedgerPage> {
  static final NumberFormat _n = NumberFormat.decimalPattern('fr');
  static final DateFormat _day = DateFormat('EEEE d MMMM', 'fr');
  static final DateFormat _short = DateFormat('d MMM', 'fr');
  static final DateFormat _hm = DateFormat('HH:mm');

  String _period = 'today';   // today | yesterday | 3d | 7d | 30d | custom
  DateTimeRange? _custom;
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _key(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  (DateTime, DateTime) _range() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_period) {
      'yesterday' => (today.subtract(const Duration(days: 1)), today.subtract(const Duration(days: 1))),
      '3d' => (today.subtract(const Duration(days: 2)), today),
      '7d' => (today.subtract(const Duration(days: 6)), today),
      '30d' => (today.subtract(const Duration(days: 29)), today),
      'custom' => (_custom?.start ?? today, _custom?.end ?? today),
      _ => (today, today),
    };
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    final (a, b) = _range();
    try {
      final r = await (widget.loader?.call(_key(a), _key(b)) ?? LiveShopApi.ledger(seller: widget.seller, from: _key(a), to: _key(b)));
      if (mounted) setState(() { _data = r; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = LiveShopApi.message(e); _loading = false; });
    }
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _custom ?? DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
      helpText: tr('Choisis les dates'),
      saveText: tr('Valider'),
    );
    if (r == null) return;
    setState(() { _period = 'custom'; _custom = r; });
    _load();
  }

  String _f(num v) => '${_n.format(v)} F';

  String _signed(int v) => v > 0 ? '+${_f(v)}' : v < 0 ? '−${_f(-v)}' : _f(0);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(backgroundColor: c.surface, foregroundColor: c.textPrimary, title: Text(widget.seller ? tr('Solde des ventes') : tr('Mes dépenses'))),
      body: RefreshIndicator(
        color: c.primary,
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
          _periods(c),
          const SizedBox(height: 12),
          if (_loading)
            Padding(padding: const EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: c.primary)))
          else if (_error != null)
            Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary)))
          else ...[
            _summary(c),
            _chart(c),
            ..._lines(c),
          ],
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, size: 15, color: c.textSecondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                widget.seller
                    ? tr('Ce solde sert seulement à consulter et à faire tes comptes : l\'argent de chaque vente terminée est déjà ajouté à ton solde de gains (Portefeuille).')
                    : tr('Ces chiffres servent seulement à consulter : tes achats sont payés avec ton solde, et un remboursement y revient tout de suite.'),
                style: TextStyle(color: c.textSecondary, fontSize: 11.5, height: 1.35),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _periods(AppColors c) {
    final (a, b) = _range();
    Widget chip(String key, String label) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            label: Text(label),
            selected: _period == key,
            onSelected: (_) {
              if (key == 'custom') {
                _pickDates();
                return;
              }
              setState(() => _period = key);
              _load();
            },
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          chip('today', tr('Aujourd\'hui')),
          chip('yesterday', tr('Hier')),
          chip('3d', tr('3 jours')),
          chip('7d', tr('7 jours')),
          chip('30d', tr('30 jours')),
          chip('custom', _period == 'custom' && _custom != null ? '${_short.format(_custom!.start)} – ${_short.format(_custom!.end)}' : tr('Dates…')),
        ]),
      ),
      const SizedBox(height: 4),
      Text(a == b ? _day.format(a) : '${_day.format(a)} → ${_day.format(b)}', style: TextStyle(color: c.textSecondary, fontSize: 12)),
    ]);
  }

  Widget _summary(AppColors c) {
    final s = (_data?['summary'] as Map?) ?? const {};
    int i(String k) => (s[k] as num?)?.toInt() ?? 0;
    Widget line(String k, String v, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(k, style: TextStyle(color: c.textSecondary, fontSize: 13))),
            Text(v, style: TextStyle(color: color ?? c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w800)),
          ]),
        );
    return Container(
      key: const ValueKey('ledger_summary'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: widget.seller
          ? [
              Text(tr('Net reçu sur la période'), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
              Text(_f(i('net_xof')), style: TextStyle(color: c.primary, fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              line(tr('Ventes terminées'), '${i('sales')}'),
              line(tr('Total des ventes'), _f(i('gross_xof'))),
              line(tr('Commission de vente'), '−${_f(i('commission_xof'))}'),
              line(tr('Commandes annulées'), '${i('cancelled')}'),
              Divider(height: 18, color: c.border),
              line(tr('En attente de réception (aujourd\'hui)'), _f(i('in_escrow_xof')), color: c.warning),
            ]
          : [
              Text(tr('Dépensé sur la période'), style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
              Text(_f(i('net_spent_xof')), style: TextStyle(color: c.textPrimary, fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              line(tr('Achats'), tr('{n} · {f}', {'n': i('purchases'), 'f': _f(i('spent_xof'))})),
              line(tr('Remboursé'), '+${_f(i('refunded_xof'))}', color: c.primary),
              Divider(height: 18, color: c.border),
              line(tr('Protégé en séquestre (aujourd\'hui)'), _f(i('in_escrow_xof')), color: c.warning),
            ]),
    );
  }

  Widget _chart(AppColors c) {
    final days = ((_data?['by_day'] as List?) ?? const []).whereType<Map>().toList();
    if (days.length < 2) return const SizedBox.shrink();
    final max = days.fold<num>(1, (m, e) => (((e['amount_xof'] as num?) ?? 0).abs() > m) ? ((e['amount_xof'] as num).abs()) : m);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
      child: SizedBox(
        height: 60,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final e in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Tooltip(
                  message: '${e['day']} : ${_signed((e['amount_xof'] as num?)?.toInt() ?? 0)}',
                  child: Container(height: 4 + 52 * (((e['amount_xof'] as num?) ?? 0).abs() / max), decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(3))),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  List<Widget> _lines(AppColors c) {
    final lines = ((_data?['lines'] as List?) ?? const []).whereType<Map>().toList();
    if (lines.isEmpty) {
      return [Padding(padding: const EdgeInsets.all(28), child: Center(child: Text(widget.seller ? tr('Aucune vente sur cette période.') : tr('Aucun achat sur cette période.'), style: TextStyle(color: c.textSecondary))))];
    }
    final byDay = <String, List<Map>>{};
    for (final l in lines) {
      final d = DateTime.tryParse('${l['at']}')?.toLocal() ?? DateTime.now();
      byDay.putIfAbsent(_key(d), () => []).add(l);
    }
    final out = <Widget>[const SizedBox(height: 14)];
    for (final e in byDay.entries) {
      final total = e.value.fold<int>(0, (a, l) => a + ((l['amount_xof'] as num?)?.toInt() ?? 0));
      out.add(Padding(
        padding: const EdgeInsets.fromLTRB(2, 10, 2, 6),
        child: Row(children: [
          Expanded(child: Text(_day.format(DateTime.parse(e.key)), style: TextStyle(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w800))),
          Text(_signed(total), style: TextStyle(color: total >= 0 ? c.primary : c.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
      ));
      out.add(Container(
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
        child: Column(children: [
          for (var i = 0; i < e.value.length; i++) ...[
            if (i > 0) Divider(height: 1, color: c.border),
            _row(c, e.value[i]),
          ],
        ]),
      ));
    }
    return out;
  }

  Widget _row(AppColors c, Map l) {
    final kind = '${l['kind']}';
    final amount = (l['amount_xof'] as num?)?.toInt() ?? 0;
    final gross = (l['gross_xof'] as num?)?.toInt() ?? 0;
    final commission = (l['commission_xof'] as num?)?.toInt() ?? 0;
    final at = DateTime.tryParse('${l['at']}')?.toLocal();
    final other = '${l['other'] ?? ''}';
    final (IconData icon, Color color, String label) = switch (kind) {
      'sale' => (Icons.south_west_rounded, c.primary, tr('Vente')),
      'cancelled' => (Icons.block_rounded, c.textSecondary, tr('Annulée')),
      'refund' => (Icons.replay_rounded, c.primary, tr('Remboursement')),
      _ => (Icons.shopping_bag_outlined, c.textPrimary, tr('Achat')),
    };
    final who = other.isEmpty ? '' : (widget.seller ? tr('à @{p}', {'p': other}) : tr('chez @{p}', {'p': other}));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle), child: Icon(icon, size: 18, color: color)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${l['title']}${((l['quantity'] as num?)?.toInt() ?? 1) > 1 ? ' × ${l['quantity']}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700)),
            Text([label, if (who.isNotEmpty) who, if (at != null) _hm.format(at)].join(' · '), style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
            if (kind == 'sale') Text(tr('{g} − commission {c}', {'g': _f(gross), 'c': _f(commission)}), style: TextStyle(color: c.textSecondary, fontSize: 11)),
            if (kind == 'cancelled') Text(tr('{g} : aucun argent reçu', {'g': _f(gross)}), style: TextStyle(color: c.textSecondary, fontSize: 11)),
          ]),
        ),
        Text(kind == 'cancelled' ? '—' : _signed(amount), style: TextStyle(color: amount > 0 ? c.primary : c.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}
