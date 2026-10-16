// Choix de la devise d'affichage des montants. Les gains restent comptés en FCFA : seul l'affichage change.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/tr.dart';
import '../../services/currency_service.dart';
import '../../theme/app_colors.dart';

class CurrencyPickerPage extends StatefulWidget {
  const CurrencyPickerPage({super.key});

  @override
  State<CurrencyPickerPage> createState() => _CurrencyPickerPageState();
}

class _CurrencyPickerPageState extends State<CurrencyPickerPage> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _choose(String? code) async {
    await CurrencyService.instance.setOverride(code);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(code == null ? context.tr('Devise automatique, selon ton pays.') : context.tr('Devise changée : {a}', {'a': code})),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final cur = context.watch<CurrencyService>();
    final q = _q.text.trim().toLowerCase();
    final all = cur.currencies.where((code) => q.isEmpty || code.toLowerCase().contains(q) || CurrencyService.nameOf(code).toLowerCase().contains(q) || cur.symbol(code).toLowerCase().contains(q)).toList();
    final auto = cur.automaticCurrency;
    // Aperçu : 1 000 FCFA dans chaque devise
    String sample(String code) => cur.fmtLocal(cur.fromFcfa(1000, code), cur: code);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        iconTheme: IconThemeData(color: c.textPrimary),
        title: Text(context.tr('Devise d\'affichage'), style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
        Text(
          context.tr('Choisis la monnaie dans laquelle tu vois tes montants. Tes gains restent comptés en FCFA : seul l\'affichage change, avec le taux du jour.'),
          style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _q,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: context.tr('Chercher une devise'),
            hintStyle: TextStyle(color: c.textSecondary),
            prefixIcon: Icon(Icons.search, color: c.textSecondary),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        if (q.isEmpty)
          _tile(c, selected: cur.override == null, title: context.tr('Automatique'), subtitle: '${context.tr('Selon ton pays')} · $auto · ${sample(auto)}', leading: '🌍', onTap: () => _choose(null)),
        for (final code in all)
          _tile(
            c,
            selected: cur.override == code,
            title: '$code · ${CurrencyService.nameOf(code)}',
            subtitle: '1 000 FCFA = ${sample(code)}',
            leading: cur.symbol(code).length > 3 ? code.substring(0, 2) : cur.symbol(code),
            onTap: () => _choose(code),
          ),
        const SizedBox(height: 12),
        Text(context.tr('Les taux sont indicatifs et mis à jour chaque jour. Pour un retrait, la somme réellement versée suit le taux au moment du paiement.'),
            style: TextStyle(color: c.textSecondary, fontSize: 11.5, height: 1.4)),
      ]),
    );
  }

  Widget _tile(AppColors c, {required bool selected, required String title, required String subtitle, required String leading, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? c.primary.withValues(alpha: .1) : c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: selected ? c.primary : c.border),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(backgroundColor: c.primary.withValues(alpha: .12), child: Text(leading, style: TextStyle(color: c.primary, fontWeight: FontWeight.w800, fontSize: 13))),
        title: Text(title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(color: c.textSecondary, fontSize: 12)),
        trailing: Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined, color: selected ? c.primary : c.textSecondary),
      ),
    );
  }
}
