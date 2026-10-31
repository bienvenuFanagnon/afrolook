import 'package:afrotok/services/api/admin_complements_api.dart';
import 'package:afrotok/widgets/pseudo_tag.dart';
import 'package:afrotok/layout/centered_content.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../services/monetization_config.dart';
import '../../theme/app_colors.dart';
import '../user/profile/adminprofil.dart';
import '../user/profile/retraitAdmin/userAllDetails.dart';

/// Admin — Rémunération des créateurs.
///
/// Suit ce que l'app verse aux créateurs (vues des posts : encaissements `cashViewEarnings`,
/// seul mode de paiement ; l'ancien paiement automatique a été supprimé le 27/09/2026), les récompenses en pièces
/// et les conversions, et permet de modifier le barème (réglage `monetization`), lu par le
/// serveur ET l'app. Données : GET /admin/remuneration (droit « finance.view »), barème : PUT /admin/settings/monetization (droit « config.edit »).
class RemunerationAdminPage extends StatefulWidget {
  const RemunerationAdminPage({super.key});

  @override
  State<RemunerationAdminPage> createState() => _RemunerationAdminPageState();
}

enum _Period { today, week, month30, thisMonth }

class _RemunerationAdminPageState extends State<RemunerationAdminPage> {
  static final NumberFormat _money = NumberFormat('#,##0', 'fr');

  _Period _period = _Period.month30;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  static String _periodKey(_Period p) => switch (p) {
        _Period.today => 'today',
        _Period.week => 'week',
        _Period.month30 => 'month30',
        _Period.thisMonth => 'thisMonth',
      };

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await AdminComplementsApi.remuneration(_periodKey(_period));
      await MonetizationConfig.load(force: true);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AdminComplementsApi.message(e);
      });
    }
  }

  Map<String, dynamic> _sub(String k) => _data[k] is Map ? Map<String, dynamic>.from(_data[k] as Map) : <String, dynamic>{};
  List<Map<String, dynamic>> _rows(String k) => (_data[k] is List ? _data[k] as List : const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  num _n(Object? v) => v is num ? v : 0;

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: c.textPrimary),
        title: Text('Rémunération', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 17)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: c.textPrimary),
            tooltip: 'Actualiser',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: c.primary,
        child: CenteredContent(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _periodChips(c),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(children: [
                    Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: c.danger)),
                    const SizedBox(height: 12),
                    FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Réessayer')),
                  ]),
                )
              else ...[
                _label(c, 'Versements aux créateurs (vues des posts)'),
                _payoutsCard(c),
                const SizedBox(height: 20),
                _label(c, 'Pièces'),
                _coinsCard(c),
                const SizedBox(height: 20),
                _label(c, 'Top créateurs de la période'),
                _topCard(c),
                const SizedBox(height: 20),
                _label(c, 'Derniers versements'),
                _lastPayoutsCard(c),
              ],
              const SizedBox(height: 20),
              _label(c, 'Barème de rémunération des vues'),
              _baremeCard(c),
            ],
          ),
        ),
      ),
    );
  }

  Widget _periodChips(AppColors c) {
    const labels = {
      _Period.today: "Aujourd'hui",
      _Period.week: '7 jours',
      _Period.month30: '30 jours',
      _Period.thisMonth: 'Ce mois',
    };
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final e in labels.entries)
          GestureDetector(
            onTap: () {
              if (_period == e.key) return;
              setState(() => _period = e.key);
              _load();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: _period == e.key ? c.textPrimary : c.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _period == e.key ? c.textPrimary : c.border),
              ),
              child: Text(e.value,
                  style: TextStyle(
                    color: _period == e.key ? c.background : c.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  )),
            ),
          ),
      ],
    );
  }

  Widget _payoutsCard(AppColors c) {
    final manuel = _sub('cashouts');
    final auto = _sub('auto');
    final manuelTotal = _n(manuel['total_xof']);
    final autoTotal = _n(auto['total_xof']);

    return _card(c, Column(children: [
      Row(children: [
        Expanded(child: _metric(c, 'Total versé', '${_money.format(autoTotal + manuelTotal)} FCFA', c.primary, big: true)),
        Expanded(child: _metric(c, 'Créateurs payés', '${_n(_data['creators_paid']).toInt()}', c.info, big: true)),
      ]),
      Divider(height: 24, color: c.border),
      Row(children: [
        Expanded(
          child: _metric(c, 'Encaissements', '${_money.format(manuelTotal)} FCFA', c.textPrimary,
              sub: '${_n(manuel['count']).toInt()} encaissement(s)'),
        ),
        Expanded(
          child: _metric(c, 'Ancien paiement auto.', '${_money.format(autoTotal)} FCFA', c.textSecondary,
              sub: '${_n(auto['count']).toInt()} versement(s)'),
        ),
      ]),
      const SizedBox(height: 10),
      _note(c,
          "Les vues sont payées uniquement quand le créateur encaisse. L'ancien paiement automatique a été arrêté le 27/09/2026 (ses versements d'avant le 26/09 n'apparaissent pas ici)."),
    ]));
  }

  Widget _coinsCard(AppColors c) {
    final coins = _sub('coins');
    final conv = _sub('conversions');
    return _card(c, Row(children: [
      Expanded(
        child: _metric(c, 'Pièces distribuées', '${_money.format(_n(coins['rewarded']))} pièces', c.supportAccent,
            sub: '${_n(coins['count']).toInt()} récompense(s)'),
      ),
      Expanded(
        child: _metric(c, 'Converties en argent', '${_money.format(_n(conv['xof']))} FCFA', c.warning,
            sub: '${_n(conv['count']).toInt()} conversion(s)'),
      ),
    ]));
  }

  Widget _topCard(AppColors c) {
    final top = _rows('top');
    if (top.isEmpty) return _card(c, _empty(c, 'Aucun versement sur la période'));
    return _card(
      c,
      Column(children: [
        for (var i = 0; i < top.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 0.5, color: c.border),
          InkWell(
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => UserManagementPage(userId: '${top[i]['user_id']}'))),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(children: [
                SizedBox(
                  width: 26,
                  child: Text('${i + 1}',
                      style: TextStyle(
                          color: i < 3 ? c.supportAccent : c.textSecondary, fontWeight: FontWeight.w800)),
                ),
                Expanded(
                  child: PseudoTag(label: '@${top[i]['pseudo'] ?? '…'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 13.5)),
                ),
                Text('${_money.format(_n(top[i]['total_xof']))} FCFA',
                    style: TextStyle(color: c.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                Icon(Icons.chevron_right_rounded, color: c.textSecondary, size: 18),
              ]),
            ),
          ),
        ],
      ]),
      padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
    );
  }

  Widget _lastPayoutsCard(AppColors c) {
    final last = _rows('last');
    return _card(
      c,
      Column(children: [
        if (last.isEmpty) _empty(c, 'Aucun versement sur la période'),
        for (var i = 0; i < last.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 0.5, color: c.border),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(children: [
              Icon(last[i]['type'] == 'auto' ? Icons.autorenew_rounded : Icons.touch_app_rounded,
                  size: 18, color: last[i]['type'] == 'auto' ? c.info : c.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  PseudoTag(label: '@${last[i]['pseudo'] ?? '…'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(
                    '${last[i]['type'] == 'auto' ? 'Ancien paiement auto.' : 'Encaissement'} · '
                    '${DateFormat('d MMM · HH:mm', 'fr').format(DateTime.tryParse('${last[i]['created_at']}')?.toLocal() ?? DateTime.now())}',
                    style: TextStyle(color: c.textSecondary, fontSize: 11),
                  ),
                ]),
              ),
              Text('+${_money.format(_n(last[i]['amount_xof']))} F',
                  style: TextStyle(color: c.primary, fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          ),
        ],
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TransactionsListPage())),
            child: const Text('Toutes les transactions'),
          ),
        ),
      ]),
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
    );
  }
  Widget _baremeCard(AppColors c) {
    final tiers = MonetizationConfig.tiers;
    final base = MonetizationConfig.baseViewRate;
    return _card(c, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text('Taux de base : ${base.toStringAsFixed(2)} FCFA / vue',
              style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
        ),
        OutlinedButton.icon(
          onPressed: _editBareme,
          icon: const Icon(Icons.edit_rounded, size: 16),
          label: const Text('Modifier'),
          style: OutlinedButton.styleFrom(
            foregroundColor: c.primary,
            side: BorderSide(color: c.primary.withOpacity(0.5)),
            minimumSize: const Size(0, 34),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      for (final t in tiers)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(
                child: Text('${t.label}  (score ≥ ${t.minScore.toStringAsFixed(0)})',
                    style: TextStyle(color: c.textPrimary, fontSize: 13))),
            Text('${(t.multiplier * 100).toStringAsFixed(0)} %  ·  ${(base * t.multiplier * 1000).toStringAsFixed(0)} FCFA / 1 000 vues',
                style: TextStyle(color: c.textSecondary, fontSize: 12)),
          ]),
        ),
      const SizedBox(height: 8),
      _note(c,
          "Ce barème est utilisé pour l'encaissement des créateurs et l'affichage dans l'app. Minimum d'encaissement : 1 000 FCFA."),
    ]));
  }

  // ── Modification du barème ─────────────────────────────────────────────────

  Future<void> _editBareme() async {
    final c = AppColors.of(context);
    final baseCtrl = TextEditingController(text: MonetizationConfig.baseViewRate.toString());
    final rows = MonetizationConfig.tiers
        .map((t) => (
              label: TextEditingController(text: t.label),
              min: TextEditingController(text: t.minScore.toStringAsFixed(0)),
              pct: TextEditingController(text: (t.multiplier * 100).toStringAsFixed(0)),
            ))
        .toList();

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          InputDecoration deco(String label) => InputDecoration(
                labelText: label,
                isDense: true,
                filled: true,
                fillColor: c.surfaceVariant,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              );
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Modifier le barème',
                    style: TextStyle(color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                TextField(
                  controller: baseCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: c.textPrimary),
                  decoration: deco('Taux de base (FCFA par vue)'),
                ),
                const SizedBox(height: 14),
                Text('Paliers (score minimum, % du taux de base)',
                    style: TextStyle(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                for (var i = 0; i < rows.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Expanded(
                          flex: 3,
                          child: TextField(
                              controller: rows[i].label,
                              style: TextStyle(color: c.textPrimary),
                              decoration: deco('Nom'))),
                      const SizedBox(width: 6),
                      Expanded(
                          flex: 2,
                          child: TextField(
                              controller: rows[i].min,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: c.textPrimary),
                              decoration: deco('Score ≥'))),
                      const SizedBox(width: 6),
                      Expanded(
                          flex: 2,
                          child: TextField(
                              controller: rows[i].pct,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: c.textPrimary),
                              decoration: deco('%'))),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, color: c.danger),
                        onPressed: rows.length <= 1 ? null : () => setSheet(() => rows.removeAt(i)),
                      ),
                    ]),
                  ),
                TextButton.icon(
                  onPressed: () => setSheet(() => rows.add((
                        label: TextEditingController(text: 'Nouveau'),
                        min: TextEditingController(text: '0'),
                        pct: TextEditingController(text: '20'),
                      ))),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Ajouter un palier'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Les nouveaux paiements utiliseront ce barème immédiatement. Les vues déjà payées ne sont pas recalculées.',
                  style: TextStyle(color: c.warning, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: c.primary, foregroundColor: c.onPrimary),
                      onPressed: () async {
                        final base = double.tryParse(baseCtrl.text.replaceAll(',', '.'));
                        final tiers = <ScoreTier>[];
                        for (final r in rows) {
                          final min = double.tryParse(r.min.text);
                          final pct = double.tryParse(r.pct.text.replaceAll(',', '.'));
                          if (min == null || pct == null || pct < 0 || pct > 100 || r.label.text.trim().isEmpty) {
                            tiers.clear();
                            break;
                          }
                          tiers.add(ScoreTier(minScore: min, multiplier: pct / 100, label: r.label.text.trim()));
                        }
                        if (base == null || base < 0 || base > 100 || tiers.isEmpty || !tiers.any((t) => t.minScore == 0)) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Valeurs invalides : un palier doit commencer à 0, % entre 0 et 100.')));
                          return;
                        }
                        try {
                          await MonetizationConfig.save(base: base, newTiers: tiers);
                          if (ctx.mounted) Navigator.pop(ctx, true);
                        } catch (e) {
                          if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(AdminComplementsApi.message(e))));
                        }
                      },
                      child: const Text('Enregistrer'),
                    ),
                  ),
                ]),
              ]),
            ),
          );
        },
      ),
    );
    if (saved == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Barème enregistré')));
    }
  }

  // ── Petits éléments ────────────────────────────────────────────────────────

  Widget _label(AppColors c, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
        child: Text(t.toUpperCase(),
            style: TextStyle(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
      );

  Widget _card(AppColors c, Widget child, {EdgeInsets padding = const EdgeInsets.all(14)}) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: child,
      );

  Widget _metric(AppColors c, String label, String value, Color color, {String? sub, bool big = false}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: c.textSecondary, fontSize: 11.5)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
              style: TextStyle(
                color: color,
                fontSize: big ? 19 : 15,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              )),
        ),
        if (sub != null) Text(sub, style: TextStyle(color: c.textSecondary, fontSize: 11)),
      ]);

  Widget _note(AppColors c, String text) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline_rounded, size: 14, color: c.textSecondary),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: TextStyle(color: c.textSecondary, fontSize: 11.5, height: 1.35))),
      ]);

  Widget _empty(AppColors c, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(child: Text(text, style: TextStyle(color: c.textSecondary, fontSize: 13))),
      );
}
