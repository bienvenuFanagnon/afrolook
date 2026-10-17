// Réglages du paiement par carte bancaire (site web) : interrupteur, frais, marge, taux FCFA/USD, packs et limites.
// Lus et écrits par les Cloud Functions cardCoinAdminConfig (document AppConfig/cardPayments) : effet immédiat, sans redéployer.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import 'admin_palette.dart';

class CardPaymentsAdminDialog extends StatefulWidget {
  const CardPaymentsAdminDialog({super.key});

  static Future<void> open(BuildContext context) => showDialog(context: context, builder: (_) => const CardPaymentsAdminDialog());

  @override
  State<CardPaymentsAdminDialog> createState() => _CardPaymentsAdminDialogState();
}

class _CardPaymentsAdminDialogState extends State<CardPaymentsAdminDialog> {
  static const _fields = <String, String>{
    'feePct': 'Frais FeexPay carte (%)',
    'marginPct': 'Marge de sécurité (%)',
    'xofPerUsd': 'Taux : FCFA pour 1 USD',
    'userPerDay': 'Paiements max / jour / compte',
    'ipPerDay': 'Paiements max / jour / IP',
    'userMonthUsd': 'Plafond mensuel / compte (USD, 0 = illimité)',
    'alertPerDay': 'Alerte admin au-delà de N paiements / jour (0 = aucune)',
  };

  final _ctl = {for (final k in _fields.keys) k: TextEditingController()};
  final _packs = TextEditingController();
  bool _enabled = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  HttpsCallable get _fn => FirebaseFunctions.instance.httpsCallable('cardCoinAdminConfig');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    _packs.dispose();
    super.dispose();
  }

  String _num(Object? v) => v is num ? (v == v.roundToDouble() ? '${v.toInt()}' : '$v') : '';

  void _fill(Map c) {
    _enabled = c['enabled'] != false;
    for (final k in _fields.keys) {
      _ctl[k]!.text = _num(c[k]);
    }
    _packs.text = ((c['packs'] as List?) ?? const []).join(', ');
  }

  Future<void> _load() async {
    try {
      final r = (await _fn.call({})).data as Map;
      if (mounted) setState(() { _fill(r['config'] as Map); _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Lecture impossible : $e'; _loading = false; });
    }
  }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      final set = <String, Object>{
        'enabled': _enabled,
        'packs': _packs.text.split(RegExp(r'[,\s]+')).map(int.tryParse).whereType<int>().toList(),
      };
      for (final k in _fields.keys) {
        final v = double.tryParse(_ctl[k]!.text.trim().replaceAll(',', '.'));
        if (v != null) set[k] = v;
      }
      final r = (await _fn.call({'set': set})).data as Map;
      if (!mounted) return;
      _fill(r['config'] as Map);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Réglages carte enregistrés.')));
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = 'Enregistrement impossible : $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    AdminPalette.of(context);
    return AlertDialog(
      backgroundColor: AdminPalette.card,
      title: Text('Paiement par carte (web)', style: TextStyle(color: AdminPalette.textP, fontWeight: FontWeight.w900)),
      content: SizedBox(
        width: 440,
        child: _loading
            ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                    title: Text('Carte activée sur le site', style: TextStyle(color: AdminPalette.textP, fontWeight: FontWeight.w700)),
                    subtitle: Text("Coupe immédiatement l'achat par carte si besoin.", style: TextStyle(color: AdminPalette.textS, fontSize: 12)),
                  ),
                  for (final e in _fields.entries) _field(_ctl[e.key]!, e.value),
                  _field(_packs, 'Packs vendus par carte (pièces, séparés par des virgules)'),
                  Text('Prix carte (USD) = prix du pack en FCFA ÷ taux ÷ (1 − frais − marge).', style: TextStyle(color: AdminPalette.textS, fontSize: 11.5)),
                  if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12.5))),
                ]),
              ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Fermer')),
        FilledButton(onPressed: (_loading || _saving) ? null : _save, child: Text(_saving ? 'Enregistrement…' : 'Enregistrer')),
      ],
    );
  }

  Widget _field(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          style: TextStyle(color: AdminPalette.textP, fontSize: 14),
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            filled: true,
            fillColor: AdminPalette.field,
            labelStyle: TextStyle(color: AdminPalette.textS, fontSize: 12.5),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AdminPalette.border)),
          ),
        ),
      );
}
