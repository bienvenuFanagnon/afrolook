// admin_email_screen.dart — envoi groupé d'e-mails par l'équipe (API : POST /admin/emails/bulk).
// Ciblage par pays, par abonnement ou par inactivité ; 2 000 destinataires au plus par envoi ; le texte est mis en file puis envoyé par le serveur.

import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/services/api/regie_api.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:flutter/material.dart';

class AdminEmailScreen extends StatefulWidget {
  const AdminEmailScreen({super.key});

  @override
  State<AdminEmailScreen> createState() => _AdminEmailScreenState();
}

class _AdminEmailScreenState extends State<AdminEmailScreen> {
  final _subject = TextEditingController();
  final _body = TextEditingController();
  final _country = TextEditingController();
  final _inactiveDays = TextEditingController();
  String _plan = ''; // '', premium, gold
  bool _busy = false;
  String? _info;

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    _country.dispose();
    _inactiveDays.dispose();
    super.dispose();
  }

  Map<String, dynamic> _payload({required bool dryRun}) {
    final days = int.tryParse(_inactiveDays.text.trim());
    final cc = _country.text.trim();
    return {
      'subject': _subject.text.trim(),
      'body': _body.text.trim(),
      if (cc.length == 2) 'country': cc.toUpperCase(),
      if (_plan.isNotEmpty) 'plan': _plan,
      if (days != null && days > 0) 'inactive_days': days,
      if (dryRun) 'dry_run': true,
    };
  }

  String? _validate() {
    if (_subject.text.trim().length < 3) return 'L’objet doit faire 3 caractères au moins.';
    if (_body.text.trim().length < 10) return 'Le message doit faire 10 caractères au moins.';
    final cc = _country.text.trim();
    if (cc.isNotEmpty && cc.length != 2) return 'Le pays s’écrit avec 2 lettres (ex. TG).';
    return null;
  }

  Future<void> _count() async {
    final err = _validate();
    if (err != null) return setState(() => _info = err);
    setState(() {
      _busy = true;
      _info = null;
    });
    try {
      final r = await RegieApi.post('/admin/emails/bulk', body: _payload(dryRun: true));
      final d = (r is Map && r['data'] is Map) ? Map<String, dynamic>.from(r['data'] as Map) : <String, dynamic>{};
      if (mounted) setState(() => _info = '${d['matching'] ?? 0} personne(s) correspondent ; ${d['recipients'] ?? 0} recevraient le message (2 000 au plus par envoi).');
    } catch (e) {
      if (mounted) setState(() => _info = RegieApi.err(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _send() async {
    final err = _validate();
    if (err != null) return setState(() => _info = err);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Envoyer ce message ?'),
        content: const Text('Le message sera mis en file puis envoyé aux personnes qui correspondent au ciblage. Cette action ne peut pas être annulée.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Envoyer')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _busy = true;
      _info = null;
    });
    try {
      final r = await RegieApi.post('/admin/emails/bulk', body: _payload(dryRun: false));
      final d = (r is Map && r['data'] is Map) ? Map<String, dynamic>.from(r['data'] as Map) : <String, dynamic>{};
      if (mounted) setState(() => _info = 'Message mis en file pour ${d['queued'] ?? d['recipients'] ?? '?'} personne(s).');
    } catch (e) {
      if (mounted) setState(() => _info = RegieApi.err(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(backgroundColor: c.surface, foregroundColor: c.textPrimary, title: const Text('Emailing')),
      body: CenteredContent(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          TextField(controller: _subject, maxLength: 160, decoration: const InputDecoration(labelText: 'Objet')),
          const SizedBox(height: 8),
          TextField(controller: _body, maxLength: 5000, minLines: 6, maxLines: 14, decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true)),
          const SizedBox(height: 12),
          Text('Ciblage (facultatif)', style: TextStyle(color: c.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(controller: _country, maxLength: 2, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Pays (2 lettres, ex. TG)')),
          DropdownButtonFormField<String>(
            initialValue: _plan,
            decoration: const InputDecoration(labelText: 'Abonnement'),
            items: const [
              DropdownMenuItem(value: '', child: Text('Tous')),
              DropdownMenuItem(value: 'premium', child: Text('Premium')),
              DropdownMenuItem(value: 'gold', child: Text('Gold')),
            ],
            onChanged: (v) => setState(() => _plan = v ?? ''),
          ),
          const SizedBox(height: 8),
          TextField(controller: _inactiveDays, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Inactifs depuis (jours)')),
          const SizedBox(height: 16),
          if (_info != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_info!, style: TextStyle(color: c.textPrimary))),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: _busy ? null : _count, child: const Text('Compter les destinataires'))),
            const SizedBox(width: 12),
            Expanded(child: FilledButton(onPressed: _busy ? null : _send, child: Text(_busy ? 'Patiente…' : 'Envoyer'))),
          ]),
        ]),
      ),
    );
  }
}
