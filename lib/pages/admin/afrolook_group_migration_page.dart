// afrolook_group_migration_page.dart — gestion des groupes OFFICIELS de l'application, via l'API (/admin/groups/official).
// Créer un groupe officiel et y faire entrer tous les comptes actifs. Toute personne qui se connecte entre déjà toute seule dans les groupes officiels (le serveur s'en charge au démarrage).
import 'package:afrotok/layout/centered_content.dart';
import 'package:afrotok/services/api/regie_api.dart';
import 'package:afrotok/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AfrolookGroupMigrationPage extends StatefulWidget {
  const AfrolookGroupMigrationPage({super.key});

  @override
  State<AfrolookGroupMigrationPage> createState() => _AfrolookGroupMigrationPageState();
}

class _AfrolookGroupMigrationPageState extends State<AfrolookGroupMigrationPage> {
  static final NumberFormat _nf = NumberFormat.decimalPattern('fr');

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _groups = [];
  int _activeUsers = 0;

  final _nameCtl = TextEditingController();
  final _descCtl = TextEditingController();
  bool _creating = false;
  String? _migratingId;
  String _status = '';
  bool _statusError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _descCtl.dispose();
    super.dispose();
  }

  static int _i(Object? v) => v is num ? v.toInt() : 0;
  static String _n(Object? v) => _nf.format(_i(v));

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await RegieApi.getMap('/admin/groups/official');
      if (!mounted) return;
      setState(() {
        _groups = ((r['groups'] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _activeUsers = _i(r['activeUsers']);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = RegieApi.err(e);
          _loading = false;
        });
      }
    }
  }

  void _say(String m, {bool error = false}) {
    if (mounted) setState(() {
      _status = m;
      _statusError = error;
    });
  }

  Future<void> _create() async {
    final name = _nameCtl.text.trim();
    if (name.isEmpty || _creating) return;
    setState(() => _creating = true);
    try {
      await RegieApi.post('/admin/groups/official', body: {'name': name, if (_descCtl.text.trim().isNotEmpty) 'description': _descCtl.text.trim()});
      _nameCtl.clear();
      _descCtl.clear();
      _say('Groupe « $name » créé. Fais maintenant entrer les utilisateurs avec le bouton du groupe.');
      await _load();
    } catch (e) {
      _say(RegieApi.err(e), error: true);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _migrate(Map<String, dynamic> g) async {
    final c = AppColors.of(context);
    final missing = _i(g['missing']);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text('Faire entrer tous les utilisateurs ?', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.bold)),
        content: Text('${_n(missing)} compte${missing > 1 ? 's' : ''} actif${missing > 1 ? 's' : ''} va${missing > 1 ? 'ont' : ''} être ajouté${missing > 1 ? 's' : ''} au groupe « ${g['name']} ». Les personnes déjà membres ne sont pas touchées, et personne ne pourra le quitter.',
            style: TextStyle(color: c.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Faire entrer')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _migratingId = '${g['id']}');
    try {
      final r = await RegieApi.post('/admin/groups/official/${g['id']}/migrate');
      final d = r is Map && r['data'] is Map ? Map<String, dynamic>.from(r['data'] as Map) : <String, dynamic>{};
      _say('« ${g['name']} » : ${_n(d['added'])} ajoutés, ${_n(d['already'])} déjà membres, ${_n(d['members'])} membres au total.');
      await _load();
    } catch (e) {
      _say(RegieApi.err(e), error: true);
    } finally {
      if (mounted) setState(() => _migratingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.textPrimary,
        elevation: 0,
        title: const Text('Groupes officiels'),
        actions: [IconButton(tooltip: 'Actualiser', icon: const Icon(Icons.refresh), onPressed: _load)],
      ),
      body: SafeArea(
        child: CenteredContent(
          maxWidth: 800,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: c.danger)),
                          const SizedBox(height: 12),
                          OutlinedButton(onPressed: _load, child: const Text('Réessayer')),
                        ]),
                      ),
                    )
                  : RefreshIndicator(onRefresh: _load, child: _content(c)),
        ),
      ),
    );
  }

  Widget _card(AppColors c, Widget child) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: c.border)),
        child: child,
      );

  Widget _content(AppColors c) {
    return ListView(padding: const EdgeInsets.all(14), children: [
      _card(
        c,
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline, color: c.info, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Toute personne qui se connecte entre automatiquement dans les groupes officiels, et ne peut pas les quitter. Seuls les administrateurs y écrivent. '
              'Utilise « Faire entrer tous les utilisateurs » pour y ajouter d\'un coup les comptes déjà inscrits (${_n(_activeUsers)} comptes actifs).',
              style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.45),
            ),
          ),
        ]),
      ),
      if (_status.isNotEmpty) _card(c, Text(_status, style: TextStyle(color: _statusError ? c.danger : c.primary, fontWeight: FontWeight.w600, fontSize: 13))),
      if (_groups.isEmpty) _card(c, Text('Aucun groupe officiel pour l\'instant. Crée le premier ci-dessous.', style: TextStyle(color: c.textSecondary))),
      for (final g in _groups)
        _card(
          c,
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.groups_rounded, color: c.info),
              const SizedBox(width: 10),
              Expanded(child: Text('${g['name']}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 16))),
              if (g['main'] == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: c.primary.withOpacity(0.13), borderRadius: BorderRadius.circular(20)),
                  child: Text('Principal', style: TextStyle(color: c.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ]),
            if ('${g['description'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${g['description']}', style: TextStyle(color: c.textSecondary, fontSize: 12.5))),
            const SizedBox(height: 8),
            Text('${_n(g['members'])} membres sur ${_n(g['activeUsers'])} comptes actifs · ${_n(g['missing'])} pas encore dedans', style: TextStyle(color: c.textPrimary, fontSize: 13)),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: (_migratingId != null || _i(g['missing']) == 0) ? null : () => _migrate(g),
                icon: _migratingId == '${g['id']}' ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.group_add_outlined, size: 18),
                label: Text(_migratingId == '${g['id']}' ? 'Entrée en cours…' : (_i(g['missing']) == 0 ? 'Tout le monde est dedans' : 'Faire entrer tous les utilisateurs')),
              ),
            ),
          ]),
        ),
      _card(
        c,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Créer un nouveau groupe officiel', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 10),
          TextField(controller: _nameCtl, maxLength: 60, decoration: const InputDecoration(labelText: 'Nom du groupe', border: OutlineInputBorder())),
          const SizedBox(height: 4),
          TextField(controller: _descCtl, maxLength: 500, maxLines: 2, decoration: const InputDecoration(labelText: 'Description (facultatif)', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: _creating ? null : _create,
              icon: _creating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.add, size: 18),
              label: const Text('Créer le groupe officiel'),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 20),
    ]);
  }
}
