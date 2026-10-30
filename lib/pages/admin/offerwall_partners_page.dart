import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../layout/centered_content.dart';
import '../../theme/app_colors.dart';

/// Suivi des partenaires de tâches (ayeT, Tapjoy, Adscend…) : lesquels on a, où en est leur validation, ce qu'il faut faire ensuite et quand relancer.
/// Réservé aux administrateurs ; les données sont lues et écrites par les fonctions du serveur (collection OfferwallPartners). Voir docs/OFFERWALL_TACHES.md §19.4.
class OfferwallPartnersPage extends StatefulWidget {
  const OfferwallPartnersPage({super.key});

  @override
  State<OfferwallPartnersPage> createState() => _OfferwallPartnersPageState();
}

const _statusLabels = {
  'a_demander': 'À demander',
  'demande_envoyee': 'Demande envoyée',
  'en_revue': 'En revue chez eux',
  'accepte': 'Accepté',
  'refuse': 'Refusé',
  'abandonne': 'Abandonné',
};
const _integrationLabels = {'aucune': 'Pas intégré', 'prete': 'Prêt à intégrer', 'integre': 'Intégré dans l\'application'};
const _kindLabels = {'taches': 'Tâches', 'sondages': 'Sondages', 'mixte': 'Tâches et sondages'};

class _OfferwallPartnersPageState extends State<OfferwallPartnersPage> {
  static final _df = DateFormat('dd/MM/yyyy');

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _partners = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<Map<String, dynamic>> _call(String name, [Map<String, dynamic>? data]) async {
    final res = await FirebaseFunctions.instance.httpsCallable(name).call(data ?? <String, dynamic>{});
    return Map<String, dynamic>.from(res.data as Map);
  }

  String _err(Object e) => e is FirebaseFunctionsException ? (e.message ?? e.code) : e.toString();

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _call('offerwallAdminPartners');
      if (mounted) setState(() { _partners = (r['partners'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(); _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = _err(e); _loading = false; });
    }
  }

  Future<void> _save(Map<String, dynamic> data) async {
    try {
      await _call('offerwallAdminPartnerSave', data);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_err(e))));
    }
  }

  Color _statusColor(String s, AppColors c) => switch (s) {
        'accepte' => c.primary,
        'refuse' => c.danger,
        'en_revue' || 'demande_envoyee' => c.warning,
        'abandonne' => c.textSecondary,
        _ => c.info,
      };

  String _date(Object? ms) {
    final v = (ms as num?)?.toInt() ?? 0;
    return v <= 0 ? '—' : _df.format(DateTime.fromMillisecondsSinceEpoch(v, isUtc: true));
  }

  Future<void> _edit(Map<String, dynamic> p) async {
    var status = '${p['status']}';
    var integration = '${p['integration']}';
    var next = (p['nextActionAt'] as num?)?.toInt() ?? 0;
    final notes = TextEditingController(text: '${p['notes'] ?? ''}');
    final link = TextEditingController(text: '${p['link'] ?? ''}');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('${p['name']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _statusLabels.containsKey(status) ? status : 'a_demander',
                decoration: const InputDecoration(labelText: 'Statut de la validation', border: OutlineInputBorder()),
                items: [for (final e in _statusLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => setS(() => status = v ?? status),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _integrationLabels.containsKey(integration) ? integration : 'aucune',
                decoration: const InputDecoration(labelText: 'Intégration dans l\'application', border: OutlineInputBorder()),
                items: [for (final e in _integrationLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => setS(() => integration = v ?? integration),
              ),
              const SizedBox(height: 10),
              TextField(controller: link, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Lien du tableau de bord (https://…)', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: notes, maxLines: 5, maxLength: 1200, decoration: const InputDecoration(labelText: 'Notes (réponses reçues, questions à poser…)', border: OutlineInputBorder())),
              Row(children: [
                Expanded(child: Text('Prochaine relance : ${_date(next)}')),
                TextButton(
                  onPressed: () async {
                    final d = await showDatePicker(context: ctx, initialDate: DateTime.now().add(const Duration(days: 2)), firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) setS(() => next = DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch);
                  },
                  child: const Text('Choisir'),
                ),
                if (next > 0) TextButton(onPressed: () => setS(() => next = 0), child: const Text('Effacer')),
              ]),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Enregistrer'))),
            ]),
          ),
        );
      }),
    );
    if (ok == true) {
      await _save({'id': p['id'], 'status': status, 'integration': integration, 'notes': notes.text, 'link': link.text.trim(), 'nextActionAt': next, 'touch': true});
    }
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final link = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajouter un partenaire'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom')),
          TextField(controller: link, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Lien (https://…, facultatif)')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ajouter'))],
      ),
    );
    if (ok == true && name.text.trim().length >= 2) {
      final id = name.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
      await _save({'id': id, 'name': name.text.trim(), 'link': link.text.trim()});
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final accepted = _partners.where((p) => p['status'] == 'accepte').length;
    final waiting = _partners.where((p) => p['status'] == 'demande_envoyee' || p['status'] == 'en_revue').length;
    final todayMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(backgroundColor: c.surface, foregroundColor: c.textPrimary, title: const Text('Partenaires de tâches')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _add, icon: const Icon(Icons.add_rounded), label: const Text('Partenaire')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: TextStyle(color: c.danger))))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                    children: [
                      CenteredContent(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.border)),
                            child: Text(
                              accepted > 0
                                  ? '$accepted partenaire(s) nous ont validés · $waiting en attente de réponse.'
                                  : 'Aucun partenaire ne nous a encore validés · $waiting en attente de réponse. Vérifier chaque tableau de bord et relancer aux dates indiquées.',
                              style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                          const SizedBox(height: 10),
                          for (final p in _partners) _card(c, p, todayMs),
                        ]),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _card(AppColors c, Map<String, dynamic> p, int todayMs) {
    final status = '${p['status']}';
    final next = (p['nextActionAt'] as num?)?.toInt() ?? 0;
    final overdue = next > 0 && next < todayMs - 86400000 && status != 'accepte' && status != 'abandonne';
    final link = '${p['link'] ?? ''}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _statusColor(status, c).withOpacity(0.5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('${p['name']}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: _statusColor(status, c).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Text(_statusLabels[status] ?? status, style: TextStyle(color: _statusColor(status, c), fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 4),
        Text('${_kindLabels['${p['kind']}'] ?? p['kind']} · ${_integrationLabels['${p['integration']}'] ?? p['integration']}', style: TextStyle(color: c.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          'Demande : ${_date(p['appliedAt'])} · dernière vérification : ${_date(p['lastCheckAt'])} · prochaine relance : ${_date(next)}${overdue ? '  (en retard)' : ''}',
          style: TextStyle(color: overdue ? c.danger : c.textSecondary, fontSize: 11.5, fontWeight: overdue ? FontWeight.w800 : FontWeight.w400),
        ),
        if ('${p['notes'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('${p['notes']}', style: TextStyle(color: c.textPrimary, fontSize: 12.5, height: 1.35)),
        ],
        const SizedBox(height: 6),
        Wrap(spacing: 8, children: [
          if (link.isNotEmpty)
            OutlinedButton.icon(
              onPressed: () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Ouvrir'),
            ),
          OutlinedButton.icon(
            onPressed: () => _save({'id': p['id'], 'touch': true}),
            icon: const Icon(Icons.check_rounded, size: 16),
            label: const Text('Vérifié aujourd\'hui'),
          ),
          FilledButton.icon(onPressed: () => _edit(p), icon: const Icon(Icons.edit_rounded, size: 16), label: const Text('Mettre à jour')),
        ]),
      ]),
    );
  }
}
