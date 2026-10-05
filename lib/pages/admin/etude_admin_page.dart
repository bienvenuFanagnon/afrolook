import 'package:flutter/material.dart';

import '../../services/etude/etude_service.dart';
import '../../theme/app_colors.dart';

int _n(dynamic v) => v is num ? v.toInt() : 0;

/// Admin d'Étude : participants, parcours commencés, classes validées, diplômes, déblocages et pubs.
/// Les données viennent de la fonction `etudeAdmin` (réservée aux admins).
class EtudeAdminPage extends StatefulWidget {
  const EtudeAdminPage({super.key});

  @override
  State<EtudeAdminPage> createState() => _EtudeAdminPageState();
}

class _EtudeAdminPageState extends State<EtudeAdminPage> {
  Map<String, dynamic>? _d;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final m = await EtudeService.instance.admin();
      if (mounted) setState(() => _d = m);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Widget _card(AppColors c, String title, Widget child) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border, width: 1.2)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 8),
          child,
        ]),
      );

  Widget _kpi(AppColors c, String v, String label) => Expanded(
        child: Column(children: [
          Text(v, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: c.textPrimary)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _row(AppColors c, String k, Object v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(k, style: TextStyle(color: c.textSecondary, fontSize: 13))),
          Text('$v', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 13)),
        ]),
      );

  Widget _map(AppColors c, Map<String, dynamic> m) {
    if (m.isEmpty) return Text('Aucun pour le moment', style: TextStyle(color: c.textSecondary, fontSize: 13));
    final e = m.entries.toList()..sort((a, b) => _n(b.value).compareTo(_n(a.value)));
    return Column(children: [for (final x in e) _row(c, x.key, _n(x.value))]);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final d = _d;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        iconTheme: IconThemeData(color: c.textPrimary),
        title: Text('Étude · admin', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900)),
        actions: [IconButton(onPressed: _load, icon: Icon(Icons.refresh_rounded, color: c.textPrimary))],
      ),
      body: _error != null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, style: TextStyle(color: c.danger)), TextButton(onPressed: _load, child: const Text('Réessayer'))]))
          : d == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    _card(c, 'Participation', Row(children: [
                      _kpi(c, '${_n(d['learners'])}', 'Apprenants'),
                      _kpi(c, '${_n(d['activeToday'])}', "Actifs aujourd'hui"),
                      _kpi(c, '${_n(d['active7'])}', 'Actifs sur 7 jours'),
                      _kpi(c, '${_n(d['successRate'])} %', 'Réussite'),
                    ])),
                    _card(c, 'Parcours commencés', _map(c, Map<String, dynamic>.from(d['started'] as Map))),
                    _card(c, 'Classes validées', _map(c, Map<String, dynamic>.from(d['classes'] as Map))),
                    _card(c, 'Diplômes et attestations', _map(c, Map<String, dynamic>.from(d['diplomas'] as Map))),
                    _card(c, 'Déblocages (pièces, pubs ou offerts)', _map(c, Map<String, dynamic>.from(d['unlocks'] as Map))),
                    _card(c, 'Pubs et pièces sur 7 jours', Column(children: [
                      _row(c, 'Pubs avec récompense', _n((d['ads7'] as Map)['rewarded'])),
                      _row(c, 'Pubs plein écran', _n((d['ads7'] as Map)['interstitial'])),
                      _row(c, 'Pièces dépensées', _n(d['coins7'])),
                    ])),
                    _card(c, 'Chapitres les plus terminés', Column(children: [
                      for (final t in (d['topChapters'] as List)) _row(c, '${(t as Map)['title']}', _n(t['n'])),
                      if ((d['topChapters'] as List).isEmpty) Text('Aucun pour le moment', style: TextStyle(color: c.textSecondary, fontSize: 13)),
                    ])),
                    _card(c, 'Contenu publié', Column(children: [
                      for (final t in (d['tracks'] as List)) _row(c, '${(t as Map)['title']}', '${_n(t['chapters'])} chapitres'),
                    ])),
                    _card(c, 'Réglages (AppConfig/etude)', Column(children: [
                      for (final e in (d['config'] as Map).entries) _row(c, '${e.key}', '${e.value}'),
                    ])),
                    if (d['truncated'] == true) Text('Liste tronquée à 10 000 apprenants.', style: TextStyle(color: c.textSecondary, fontSize: 12)),
                  ]),
                ),
    );
  }
}
