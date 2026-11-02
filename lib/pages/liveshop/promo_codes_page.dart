import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/tr.dart';
import '../../services/api/live_shop_api.dart';
import '../../theme/app_colors.dart';

/// Codes promo du vendeur : créer (pourcentage ou montant fixe), voir les utilisations, désactiver.
class PromoCodesPage extends StatefulWidget {
  const PromoCodesPage({super.key});

  @override
  State<PromoCodesPage> createState() => _PromoCodesPageState();
}

class _PromoCodesPageState extends State<PromoCodesPage> {
  static final NumberFormat _n = NumberFormat.decimalPattern('fr');
  List<Map<String, dynamic>> _promos = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await LiveShopApi.promos();
      if (mounted) setState(() { _promos = l; _loading = false; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = LiveShopApi.message(e); });
    }
  }

  String _label(Map<String, dynamic> p) => p['kind'] == 'percent' ? '-${p['value']} %' : '-${_n.format(p['value'] as num)} F';

  Future<void> _create() async {
    final code = TextEditingController();
    final value = TextEditingController();
    final max = TextEditingController();
    final min = TextEditingController();
    String kind = 'percent';
    bool first = false;
    String? error;
    bool busy = false;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('Nouveau code promo'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              TextField(controller: code, textCapitalization: TextCapitalization.characters, maxLength: 24, decoration: InputDecoration(labelText: tr('Code (lettres et chiffres)'), counterText: '')),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [ButtonSegment(value: 'percent', label: Text(tr('Pourcentage'))), ButtonSegment(value: 'amount', label: Text(tr('Montant (F)')))],
                selected: {kind},
                onSelectionChanged: (s) => set(() => kind = s.first),
              ),
              TextField(controller: value, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: kind == 'percent' ? tr('Réduction (1 à 90 %)') : tr('Réduction en F'))),
              TextField(controller: max, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('Nombre d\'utilisations maximal (facultatif)'))),
              TextField(controller: min, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('Achat minimal en F (facultatif)'))),
              SwitchListTile(contentPadding: EdgeInsets.zero, value: first, onChanged: (v) => set(() => first = v), title: Text(tr('Première commande seulement'))),
              if (error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(error!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700))),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: busy
                      ? null
                      : () async {
                          final v = int.tryParse(value.text.trim());
                          if (!RegExp(r'^[A-Za-z0-9]{3,24}$').hasMatch(code.text.trim())) {
                            set(() => error = tr('Le code fait 3 à 24 lettres ou chiffres, sans espace.'));
                            return;
                          }
                          if (v == null || v < 1 || (kind == 'percent' && v > 90)) {
                            set(() => error = tr('Indique une réduction valide.'));
                            return;
                          }
                          set(() { busy = true; error = null; });
                          try {
                            await LiveShopApi.createPromo(code: code.text.trim().toUpperCase(), kind: kind, value: v, maxUses: int.tryParse(max.text.trim()), minPrice: int.tryParse(min.text.trim()), firstOrderOnly: first);
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (e) {
                            set(() { busy = false; error = LiveShopApi.message(e); });
                          }
                        },
                  child: Text(tr('Créer le code')),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    if (ok == true) _load();
  }

  Future<void> _remove(Map<String, dynamic> p) async {
    try {
      final l = await LiveShopApi.deletePromo('${p['id']}');
      if (mounted) setState(() => _promos = l);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(LiveShopApi.message(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(backgroundColor: c.surface, foregroundColor: c.textPrimary, title: Text(tr('Mes codes promo'))),
      floatingActionButton: FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add), label: Text(tr('Nouveau code'))),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary))))
              : _promos.isEmpty
                  ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(tr("Aucun code pour le moment. Crée un code et donne-le à tes acheteurs : il s'applique à l'achat."), textAlign: TextAlign.center, style: TextStyle(color: c.textSecondary))))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                      itemCount: _promos.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final p = _promos[i];
                        final active = p['active'] == true;
                        final uses = '${p['uses']}${p['max_uses'] != null ? ' / ${p['max_uses']}' : ''}';
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14)),
                          child: Row(children: [
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${p['code']}  ·  ${_label(p)}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
                                const SizedBox(height: 2),
                                Text('${tr('Utilisations')} : $uses${p['first_order_only'] == true ? ' · ${tr('1re commande')}' : ''}${(p['min_price_xof'] as num? ?? 0) > 0 ? ' · ${tr('dès')} ${_n.format(p['min_price_xof'] as num)} F' : ''}', style: TextStyle(color: c.textSecondary, fontSize: 12)),
                              ]),
                            ),
                            if (active) IconButton(tooltip: tr('Désactiver'), icon: const Icon(Icons.delete_outline), onPressed: () => _remove(p)) else Text(tr('désactivé'), style: TextStyle(color: c.textSecondary, fontSize: 12)),
                          ]),
                        );
                      },
                    ),
    );
  }
}
