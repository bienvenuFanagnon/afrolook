import 'package:afrotok/widgets/pseudo_tag.dart';
import 'package:afrotok/layout/centered_content.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/authProvider.dart';
import '../../services/monetization_config.dart';
import '../../theme/app_colors.dart';
import '../user/profile/adminprofil.dart';
import '../user/profile/retraitAdmin/userAllDetails.dart';

/// Admin — Rémunération des créateurs.
///
/// Suit ce que l'app verse aux créateurs (vues des posts : encaissements `cashViewEarnings`,
/// seul mode de paiement ; l'ancien paiement automatique a été supprimé le 27/09/2026), les récompenses en pièces
/// et les conversions, et permet de modifier le barème (`config/monetization`), lu par le
/// serveur ET l'app.
class RemunerationAdminPage extends StatefulWidget {
  const RemunerationAdminPage({super.key});

  @override
  State<RemunerationAdminPage> createState() => _RemunerationAdminPageState();
}

enum _Period { today, week, month30, thisMonth }

class _Payout {
  final String userId;
  final double montant;
  final String type; // auto | manuel
  final int createdAt;
  final String description;
  const _Payout(this.userId, this.montant, this.type, this.createdAt, this.description);
}

class _RemunerationAdminPageState extends State<RemunerationAdminPage> {
  final _db = FirebaseFirestore.instance;
  static final NumberFormat _money = NumberFormat('#,##0', 'fr');

  _Period _period = _Period.month30;
  bool _loading = true;

  // Versements FCFA
  List<_Payout> _payouts = [];
  // Pièces
  int _coinsRewarded = 0;
  int _coinsRewardCount = 0;
  double _convertedFcfa = 0;
  int _conversionsCount = 0;
  // Pseudos des créateurs du top
  final Map<String, String> _pseudos = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  (int, int) _range() {
    final now = DateTime.now();
    final start = switch (_period) {
      _Period.today => DateTime(now.year, now.month, now.day),
      _Period.week => now.subtract(const Duration(days: 7)),
      _Period.month30 => now.subtract(const Duration(days: 30)),
      _Period.thisMonth => DateTime(now.year, now.month, 1),
    };
    // Borne haute = maintenant : exclut les anciens documents dont createdAt est en microsecondes
    return (start.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
  }

  Query<Map<String, dynamic>> _tx(String type, int start, int end) => _db
      .collection('TransactionSoldes')
      .where('statut', isEqualTo: 'VALIDER')
      .where('type', isEqualTo: type)
      .where('createdAt', isGreaterThanOrEqualTo: start)
      .where('createdAt', isLessThanOrEqualTo: end);

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final (start, end) = _range();
      final results = await Future.wait([
        _tx('GAIN', start, end).get(),
        _tx('ENCAISSEMENT_VUES_POST', start, end).get(),
        _tx('GAIN_PIECES', start, end).get(),
        _tx('CONVERSION_PIECES', start, end).get(),
        MonetizationConfig.load(force: true).then((_) => null),
      ]);

      double num0(dynamic v) => (v as num?)?.toDouble() ?? 0;
      final payouts = <_Payout>[];
      for (final d in (results[0] as QuerySnapshot<Map<String, dynamic>>).docs) {
        final m = d.data();
        if (m['methode_paiement'] != 'vues_posts') continue; // uniquement les vues
        payouts.add(_Payout(m['user_id'] ?? '', num0(m['montant']), 'auto', m['createdAt'] ?? 0, m['description'] ?? ''));
      }
      for (final d in (results[1] as QuerySnapshot<Map<String, dynamic>>).docs) {
        final m = d.data();
        payouts.add(_Payout(m['user_id'] ?? '', num0(m['montant']), 'manuel', m['createdAt'] ?? 0, m['description'] ?? ''));
      }
      payouts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final coinDocs = (results[2] as QuerySnapshot<Map<String, dynamic>>).docs;
      final convDocs = (results[3] as QuerySnapshot<Map<String, dynamic>>).docs;

      // Pseudos des 10 meilleurs créateurs + des derniers versements
      final ids = {..._topCreators(payouts).map((e) => e.key), ...payouts.take(10).map((p) => p.userId)}
        ..removeWhere((id) => id.isEmpty || _pseudos.containsKey(id));
      final idList = ids.toList();
      for (var i = 0; i < idList.length; i += 30) {
        final chunk = idList.sublist(i, i + 30 > idList.length ? idList.length : i + 30);
        final snap = await _db.collection('Users').where(FieldPath.documentId, whereIn: chunk).get();
        for (final u in snap.docs) {
          _pseudos[u.id] = u.data()['pseudo'] as String? ?? 'Sans pseudo';
        }
      }

      if (!mounted) return;
      setState(() {
        _payouts = payouts;
        _coinsRewarded = coinDocs.fold(0, (s, d) => s + num0(d.data()['montant']).round());
        _coinsRewardCount = coinDocs.length;
        _convertedFcfa = convDocs.fold(0.0, (s, d) => s + num0(d.data()['montant']));
        _conversionsCount = convDocs.length;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur de chargement : $e')));
    }
  }

  List<MapEntry<String, double>> _topCreators(List<_Payout> payouts) {
    final totals = <String, double>{};
    for (final p in payouts) {
      if (p.userId.isEmpty) continue;
      totals[p.userId] = (totals[p.userId] ?? 0) + p.montant;
    }
    return totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

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
    final auto = _payouts.where((p) => p.type == 'auto');
    final manuel = _payouts.where((p) => p.type == 'manuel');
    final autoTotal = auto.fold(0.0, (s, p) => s + p.montant);
    final manuelTotal = manuel.fold(0.0, (s, p) => s + p.montant);
    final creators = _payouts.map((p) => p.userId).where((id) => id.isNotEmpty).toSet().length;

    return _card(c, Column(children: [
      Row(children: [
        Expanded(child: _metric(c, 'Total versé', '${_money.format(autoTotal + manuelTotal)} FCFA', c.primary, big: true)),
        Expanded(child: _metric(c, 'Créateurs payés', '$creators', c.info, big: true)),
      ]),
      Divider(height: 24, color: c.border),
      Row(children: [
        Expanded(
          child: _metric(c, 'Encaissements', '${_money.format(manuelTotal)} FCFA', c.textPrimary,
              sub: '${manuel.length} encaissement(s)'),
        ),
        Expanded(
          child: _metric(c, 'Ancien paiement auto.', '${_money.format(autoTotal)} FCFA', c.textSecondary,
              sub: '${auto.length} versement(s)'),
        ),
      ]),
      const SizedBox(height: 10),
      _note(c,
          "Les vues sont payées uniquement quand le créateur encaisse. L'ancien paiement automatique a été arrêté le 27/09/2026 (ses versements d'avant le 26/09 n'apparaissent pas ici)."),
    ]));
  }

  Widget _coinsCard(AppColors c) {
    return _card(c, Row(children: [
      Expanded(
        child: _metric(c, 'Pièces distribuées', '${_money.format(_coinsRewarded)} pièces', c.supportAccent,
            sub: '$_coinsRewardCount récompense(s)'),
      ),
      Expanded(
        child: _metric(c, 'Converties en argent', '${_money.format(_convertedFcfa)} FCFA', c.warning,
            sub: '$_conversionsCount conversion(s)'),
      ),
    ]));
  }

  Widget _topCard(AppColors c) {
    final top = _topCreators(_payouts).take(10).toList();
    if (top.isEmpty) return _card(c, _empty(c, 'Aucun versement sur la période'));
    return _card(
      c,
      Column(children: [
        for (var i = 0; i < top.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 0.5, color: c.border),
          InkWell(
            onTap: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => UserManagementPage(userId: top[i].key))),
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
                  child: PseudoTag(label: '@${_pseudos[top[i].key] ?? '…'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 13.5)),
                ),
                Text('${_money.format(top[i].value)} FCFA',
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
    final last = _payouts.take(10).toList();
    return _card(
      c,
      Column(children: [
        if (last.isEmpty) _empty(c, 'Aucun versement sur la période'),
        for (var i = 0; i < last.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 0.5, color: c.border),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(children: [
              Icon(last[i].type == 'auto' ? Icons.autorenew_rounded : Icons.touch_app_rounded,
                  size: 18, color: last[i].type == 'auto' ? c.info : c.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  PseudoTag(label: '@${_pseudos[last[i].userId] ?? '…'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(
                    '${last[i].type == 'auto' ? 'Ancien paiement auto.' : 'Encaissement'} · '
                    '${DateFormat('d MMM · HH:mm', 'fr').format(DateTime.fromMillisecondsSinceEpoch(last[i].createdAt))}',
                    style: TextStyle(color: c.textSecondary, fontSize: 11),
                  ),
                ]),
              ),
              Text('+${_money.format(last[i].montant)} F',
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
                        final adminId = context.read<UserAuthProvider>().userId;
                        await MonetizationConfig.save(base: base, newTiers: tiers, adminId: adminId);
                        if (ctx.mounted) Navigator.pop(ctx, true);
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
