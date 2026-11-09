import 'package:flutter/material.dart';

import '../../../l10n/tr.dart';
import '../../../models/community_template.dart';
import '../../../services/api/community_templates_api.dart';
import '../../../services/api/template_stats_api.dart';
import '../../../theme/app_colors.dart';
import '../studio_theme.dart';

AppColors get _c => studioColors;

/// « Mes modèles » (espace créateur, 09/11/2026) : les modèles de la personne, leur statut (publié, ou retiré par l'équipe avec le motif), leurs utilisations et ses gains en
/// pièces. Elle peut changer le prix ou supprimer un modèle. Les gains se montrent en pièces seulement, jamais en pourcentage.
class MyTemplatesPage extends StatefulWidget {
  const MyTemplatesPage({super.key});

  @override
  State<MyTemplatesPage> createState() => _MyTemplatesPageState();
}

class _MyTemplatesPageState extends State<MyTemplatesPage> {
  List<CommunityTemplate>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await CommunityTemplatesApi.list(mine: true);
      if (mounted) setState(() => _items = r.items);
    } catch (e) {
      if (mounted) setState(() => _error = '${(e as dynamic).message ?? e}');
    }
  }

  int get _earned => (_items ?? const <CommunityTemplate>[]).fold(0, (a, t) => a + t.earnedCoins);

  Future<void> _changePrice(CommunityTemplate t) async {
    final p = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: _c.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Text(context.tr('Prix pour les autres'), style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w800, fontSize: 16)),
          for (final p in kCommunityPrices)
            ListTile(
              key: ValueKey('price_$p'),
              title: Text(p == 0 ? context.tr('Gratuit') : context.tr('{n} pièces', {'n': '$p'}), style: TextStyle(color: _c.textPrimary, fontWeight: p == t.priceCoins ? FontWeight.w900 : FontWeight.w600)),
              trailing: p == t.priceCoins ? Icon(Icons.check_rounded, color: _c.accentText) : null,
              onTap: () => Navigator.pop(ctx, p),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (p == null || p == t.priceCoins) return;
    try {
      await CommunityTemplatesApi.update(t.id, priceCoins: p);
      await _load();
    } catch (e) {
      _snack('${(e as dynamic).message ?? e}');
    }
  }

  Future<void> _delete(CommunityTemplate t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _c.surface,
        title: Text(context.tr('Supprimer ce modèle ?'), style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w800)),
        content: Text(context.tr('Il disparaît du catalogue. Les publications déjà faites avec ce modèle restent, et tes gains déjà reçus aussi.'), style: TextStyle(color: _c.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('Annuler'))),
          TextButton(key: const ValueKey('delete_ok'), onPressed: () => Navigator.pop(ctx, true), child: Text(context.tr('Supprimer'), style: TextStyle(color: _c.danger))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await CommunityTemplatesApi.delete(t.id);
      await _load();
    } catch (e) {
      _snack('${(e as dynamic).message ?? e}');
    }
  }

  void _snack(String m) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    syncStudioColors(context);
    return Scaffold(
      backgroundColor: _c.background,
      appBar: AppBar(backgroundColor: _c.background, foregroundColor: _c.textPrimary, elevation: 0, title: Text(context.tr('Mes modèles'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
      body: _body(),
    );
  }

  Widget _body() {
    final items = _items;
    if (_error != null) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: TextStyle(color: _c.danger))));
    if (items == null) return Center(child: CircularProgressIndicator(color: _c.primary));
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            context.tr('Tu n\'as pas encore de modèle. Dans le Studio, ouvre un modèle, règle-le comme tu veux, puis choisis « Enregistrer comme modèle ».'),
            key: const ValueKey('my_templates_empty'),
            textAlign: TextAlign.center,
            style: TextStyle(color: _c.textSecondary, height: 1.4),
          ),
        ),
      );
    }
    return ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 30), children: [
      Container(
        key: const ValueKey('my_templates_gain'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _c.border)),
        child: Row(children: [
          Expanded(child: Text(context.tr('Gains avec tes modèles'), style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w700))),
          Text(context.tr('{n} pièces', {'n': '$_earned'}), style: TextStyle(color: _c.accentText, fontWeight: FontWeight.w900, fontSize: 17)),
        ]),
      ),
      const SizedBox(height: 10),
      for (final t in items) _tile(t),
    ]);
  }

  Widget _tile(CommunityTemplate t) {
    final suspended = t.status == 'suspended';
    return Container(
      key: ValueKey('my_template_${t.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: suspended ? _c.danger : _c.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: suspended ? _c.danger.withValues(alpha: .15) : _c.primary.withValues(alpha: .16), borderRadius: BorderRadius.circular(99)),
            child: Text(suspended ? context.tr('Retiré par l\'équipe') : context.tr('Publié'), style: TextStyle(color: suspended ? _c.danger : _c.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w800)),
          ),
        ]),
        if (suspended && (t.refusalReason ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(t.refusalReason!, key: const ValueKey('my_template_reason'), style: TextStyle(color: _c.danger, fontSize: 12.5)),
        ],
        const SizedBox(height: 6),
        Text(
          [
            t.priceCoins == 0 ? context.tr('Gratuit') : context.tr('{n} pièces', {'n': '${t.priceCoins}'}),
            context.tr('{n} utilisations', {'n': TemplateStatsApi.format(t.usesCount)}),
            if (t.priceCoins > 0) context.tr('{n} pièces gagnées', {'n': '${t.earnedCoins}'}),
          ].join(' · '),
          style: TextStyle(color: _c.textSecondary, fontSize: 12.5),
        ),
        const SizedBox(height: 6),
        Row(children: [
          TextButton.icon(key: ValueKey('price_btn_${t.id}'), onPressed: () => _changePrice(t), icon: const Icon(Icons.sell_outlined, size: 18), label: Text(context.tr('Prix'))),
          TextButton.icon(key: ValueKey('delete_btn_${t.id}'), onPressed: () => _delete(t), icon: Icon(Icons.delete_outline_rounded, size: 18, color: _c.danger), label: Text(context.tr('Supprimer'), style: TextStyle(color: _c.danger))),
        ]),
      ]),
    );
  }
}
