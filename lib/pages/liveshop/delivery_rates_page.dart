import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/tr.dart';
import '../../services/api/live_shop_api.dart';
import '../../theme/app_colors.dart';

/// Tarifs de livraison du vendeur : un tarif par pays, et au besoin un tarif par ville (la ville l'emporte).
/// Ils servent à ESTIMER les frais montrés à l'acheteur ; la livraison se paie à la livraison et le vendeur peut modifier le montant pour chaque commande.
class DeliveryRatesPage extends StatefulWidget {
  const DeliveryRatesPage({super.key});

  @override
  State<DeliveryRatesPage> createState() => _DeliveryRatesPageState();
}

class _DeliveryRatesPageState extends State<DeliveryRatesPage> {
  static final NumberFormat _n = NumberFormat.decimalPattern('fr');

  List<Map<String, dynamic>> _rates = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await LiveShopApi.rates();
      if (mounted) setState(() { _rates = r; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = LiveShopApi.message(e); _loading = false; });
    }
  }

  Future<void> _add() async {
    final country = TextEditingController();
    final city = TextEditingController();
    final fee = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Nouveau tarif de livraison')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: country, maxLength: 2, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: tr('Pays (2 lettres, ex. TG)'), counterText: '')),
          TextField(controller: city, decoration: InputDecoration(labelText: tr('Ville (facultatif)'))),
          TextField(controller: fee, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('Frais en F CFA'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Annuler'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Enregistrer'))),
        ],
      ),
    );
    if (ok != true) return;
    final f = int.tryParse(fee.text.trim());
    if (country.text.trim().length != 2 || f == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Indique un pays à 2 lettres et un montant.'))));
      return;
    }
    try {
      final r = await LiveShopApi.setRate(country: country.text.trim().toUpperCase(), city: city.text, fee: f);
      if (mounted) setState(() => _rates = r);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(LiveShopApi.message(e))));
    }
  }

  Future<void> _delete(int id) async {
    try {
      final r = await LiveShopApi.deleteRate(id);
      if (mounted) setState(() => _rates = r);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(LiveShopApi.message(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(backgroundColor: c.surface, foregroundColor: c.textPrimary, title: Text(tr('Mes tarifs de livraison'))),
      floatingActionButton: FloatingActionButton.extended(onPressed: _add, backgroundColor: c.primary, icon: const Icon(Icons.add), label: Text(tr('Ajouter'))),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.primary))
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: TextStyle(color: c.textSecondary), textAlign: TextAlign.center)))
              : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), children: [
                  Text(tr("Ces tarifs servent à estimer la livraison pour l'acheteur. Elle est payée à la livraison, et tu peux changer le montant sur chaque commande."), style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 12),
                  if (_rates.isEmpty) Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(tr('Aucun tarif pour le moment.'), style: TextStyle(color: c.textSecondary)))),
                  for (final r in _rates)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
                      child: ListTile(
                        title: Text(r['city'] == null ? '${r['country']}' : '${r['city']} (${r['country']})', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700)),
                        subtitle: Text('${_n.format((r['fee_xof'] as num?) ?? 0)} F', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800)),
                        trailing: IconButton(icon: Icon(Icons.delete_outline_rounded, color: c.textSecondary), onPressed: () => _delete((r['id'] as num).toInt())),
                      ),
                    ),
                ]),
    );
  }
}
