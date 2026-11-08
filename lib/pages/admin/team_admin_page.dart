import 'package:flutter/material.dart';

import '../../services/api/staff_api.dart';
import '../../theme/app_colors.dart';

/// Équipe d'administration (super-administrateurs seulement) : membres et leurs droits, demandes à valider par une AUTRE personne (règle des quatre yeux),
/// ajout d'un membre (pseudo ou e-mail), retrait, renouvellement d'un stagiaire. Les stagiaires ont une date de fin (90 jours au plus) et se ferment seuls.
class TeamAdminPage extends StatefulWidget {
  const TeamAdminPage({super.key});

  @override
  State<TeamAdminPage> createState() => _TeamAdminPageState();
}

const _typeLabels = {'super_admin': 'Super-administrateur', 'admin': 'Administrateur', 'collaborator': 'Collaborateur', 'trainee': 'Stagiaire'};

class _TeamAdminPageState extends State<TeamAdminPage> {
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _pending = [];
  Map<String, dynamic> _catalog = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await Future.wait([StaffApi.members(), StaffApi.pending(), StaffApi.catalog()]);
      if (!mounted) return;
      setState(() {
        _members = r[0] as List<Map<String, dynamic>>;
        _pending = r[1] as List<Map<String, dynamic>>;
        _catalog = r[2] as Map<String, dynamic>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _error = StaffApi.message(e);
        _loading = false;
      });
    }
  }

  void _say(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  String _name(Map? u, [String? fallback]) => u == null ? (fallback ?? 'Compte inconnu') : '@${u['username'] ?? u['id']}';

  String _date(Object? iso) {
    final d = DateTime.tryParse('$iso')?.toLocal();
    return d == null ? '' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  String _permLabel(String key) => '${(_catalog['permissions'] as Map?)?[key] ?? (_catalog['fine'] as Map?)?[key] ?? key}';

  Future<void> _run(Future<void> Function() action, String ok) async {
    try {
      await action();
      if (mounted) _say(ok);
      await _load();
    } catch (e) {
      if (mounted) _say(StaffApi.message(e));
    }
  }

  Future<bool> _confirm(String title, String body, String yes) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            TextButton(key: const ValueKey('team_confirm_yes'), onPressed: () => Navigator.pop(ctx, true), child: Text(yes)),
          ],
        ),
      ) ??
      false;

  Future<void> _revoke(Map<String, dynamic> m) async {
    if (!await _confirm('Retirer de l\'équipe ?', '${_name(m['user'] as Map?)} perd tous ses droits tout de suite. L\'action est inscrite dans le journal.', 'Retirer')) return;
    await _run(() => StaffApi.revoke('${m['user_id']}'), 'Membre retiré.');
  }

  Future<void> _renew(Map<String, dynamic> m) async {
    final days = (_catalog['trainee_max_days'] as num?)?.toInt() ?? 90;
    if (!await _confirm('Renouveler le stagiaire ?', '${_name(m['user'] as Map?)} garde les mêmes droits pour $days jours de plus.', 'Renouveler')) return;
    await _run(() async {
      await StaffApi.propose(userId: '${m['user_id']}', type: 'trainee', permissions: [for (final p in (m['permissions'] as List? ?? const [])) '$p'], expiresAt: DateTime.now().add(Duration(days: days)));
    }, 'Stagiaire renouvelé.');
  }

  Future<void> _add() async {
    final done = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddMemberSheet(catalog: _catalog),
    );
    if (done == null || !mounted) return;
    _say(done == 'pending' ? 'Demande envoyée : une autre personne doit la valider.' : 'Droits accordés.');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(backgroundColor: c.background, foregroundColor: c.textPrimary, elevation: 0, title: const Text('Équipe', style: TextStyle(fontWeight: FontWeight.w800))),
      floatingActionButton: _loading || _error != null ? null : FloatingActionButton.extended(key: const ValueKey('team_add'), onPressed: _add, icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Ajouter')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 10), OutlinedButton(onPressed: _load, child: const Text('Réessayer'))]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 90), children: [
                    if (_pending.isNotEmpty) ...[
                      Text('À valider (${_pending.length})', style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text('Une demande doit être validée par une autre personne que celle qui l\'a faite.', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
                      const SizedBox(height: 8),
                      for (final r in _pending) _requestCard(c, r),
                      const SizedBox(height: 18),
                    ],
                    Text('Membres (${_members.where((m) => m['status'] == 'active').length})', style: TextStyle(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    for (final m in _members) _memberCard(c, m),
                  ]),
                ),
    );
  }

  Widget _requestCard(AppColors c, Map<String, dynamic> r) {
    final perms = [for (final p in (r['permissions'] as List? ?? const [])) _permLabel('$p')];
    return Card(
      key: ValueKey('team_req_${r['id']}'),
      color: c.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_name(r['target_user'] as Map?)} → ${_typeLabels[r['type']] ?? r['type']}', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
          Text('Demandé par ${_name(r['requested_by_user'] as Map?)}${r['expires_at'] != null ? ' · jusqu\'au ${_date(r['expires_at'])}' : ''}', style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
          if (perms.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(perms.join(' · '), style: TextStyle(color: c.textSecondary, fontSize: 12))),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(key: ValueKey('team_reject_${r['id']}'), onPressed: () => _run(() => StaffApi.reject('${r['id']}'), 'Demande refusée.'), child: Text('Refuser', style: TextStyle(color: c.danger))),
            FilledButton(key: ValueKey('team_approve_${r['id']}'), onPressed: () => _run(() => StaffApi.approve('${r['id']}'), 'Demande validée.'), child: const Text('Valider')),
          ]),
        ]),
      ),
    );
  }

  Widget _memberCard(AppColors c, Map<String, dynamic> m) {
    final active = m['status'] == 'active';
    final perms = [for (final p in (m['permissions'] as List? ?? const [])) _permLabel('$p')];
    final expires = m['expires_at'];
    final expired = expires != null && (DateTime.tryParse('$expires')?.isBefore(DateTime.now()) ?? false);
    return Card(
      key: ValueKey('team_member_${m['user_id']}'),
      color: c.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_name(m['user'] as Map?), style: TextStyle(color: active && !expired ? c.textPrimary : c.textSecondary, fontWeight: FontWeight.w800)),
              Text(
                '${_typeLabels[m['type']] ?? m['type']}${!active || expired ? ' · fermé' : ''}${expires != null ? ' · fin le ${_date(expires)}' : ''}',
                style: TextStyle(color: expired || !active ? c.danger : c.textSecondary, fontSize: 12.5),
              ),
              if (m['type'] != 'super_admin' && perms.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(perms.join(' · '), style: TextStyle(color: c.textSecondary, fontSize: 12))),
              if (m['type'] == 'super_admin') Text('Tous les droits', style: TextStyle(color: c.textSecondary, fontSize: 12)),
            ]),
          ),
          if (active || m['type'] == 'trainee')
            PopupMenuButton<String>(
              key: ValueKey('team_menu_${m['user_id']}'),
              onSelected: (v) => v == 'revoke' ? _revoke(m) : _renew(m),
              itemBuilder: (_) => [
                if (m['type'] == 'trainee') const PopupMenuItem(value: 'renew', child: Text('Renouveler')),
                if (active) const PopupMenuItem(value: 'revoke', child: Text('Retirer de l\'équipe')),
              ],
            ),
        ]),
      ),
    );
  }
}

/// Ajout d'un membre : recherche du compte, statut, droits, date de fin du stagiaire.
class _AddMemberSheet extends StatefulWidget {
  const _AddMemberSheet({required this.catalog});

  final Map<String, dynamic> catalog;

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _q = TextEditingController();
  List<Map<String, dynamic>> _found = [];
  Map<String, dynamic>? _user;
  String _type = 'collaborator';
  final Set<String> _perms = {};
  double _days = 30;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Map get _all => {...(widget.catalog['permissions'] as Map? ?? const {}), ...(widget.catalog['fine'] as Map? ?? const {})};

  Future<void> _search() async {
    final q = _q.text.trim();
    if (q.length < 3) return;
    try {
      final r = await StaffApi.lookup(q);
      if (mounted) setState(() {
        _found = r;
        _error = r.isEmpty ? 'Aucun compte trouvé.' : null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = StaffApi.message(e));
    }
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final status = await StaffApi.propose(
        userId: '${_user!['id']}',
        type: _type,
        permissions: _type == 'super_admin' ? const [] : _perms.toList(),
        expiresAt: _type == 'trainee' ? DateTime.now().add(Duration(days: _days.round())) : null,
      );
      if (mounted) Navigator.pop(context, status);
    } catch (e) {
      if (mounted) setState(() {
        _busy = false;
        _error = StaffApi.message(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final money = {for (final m in (widget.catalog['money'] as List? ?? const [])) '$m'};
    final maxDays = (widget.catalog['trainee_max_days'] as num?)?.toDouble() ?? 90;
    final needsApproval = _type == 'super_admin' || _type == 'admin' || _perms.any(money.contains);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ListView(padding: const EdgeInsets.all(16), shrinkWrap: true, children: [
        Text('Ajouter un membre', style: TextStyle(color: c.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        if (_user == null) ...[
          TextField(key: const ValueKey('team_search'), controller: _q, decoration: InputDecoration(labelText: 'Pseudo ou adresse e-mail', suffixIcon: IconButton(icon: const Icon(Icons.search_rounded), onPressed: _search)), onSubmitted: (_) => _search()),
          for (final u in _found) ListTile(key: ValueKey('team_found_${u['id']}'), title: Text('@${u['username']}'), subtitle: Text('${u['name'] ?? ''}'), onTap: () => setState(() => _user = u)),
        ] else ...[
          ListTile(contentPadding: EdgeInsets.zero, title: Text('@${_user!['username']}', style: const TextStyle(fontWeight: FontWeight.w800)), trailing: TextButton(onPressed: () => setState(() => _user = null), child: const Text('Changer'))),
          Wrap(spacing: 8, children: [
            for (final t in (widget.catalog['types'] as List? ?? const ['collaborator']))
              ChoiceChip(key: ValueKey('team_type_$t'), label: Text(_typeLabels['$t'] ?? '$t'), selected: _type == t, onSelected: (_) => setState(() => _type = '$t')),
          ]),
          if (_type == 'trainee') ...[
            const SizedBox(height: 8),
            Text('Date de fin : dans ${_days.round()} jours (${maxDays.round()} au plus)', style: TextStyle(color: c.textSecondary)),
            Slider(key: const ValueKey('team_days'), value: _days.clamp(7, maxDays), min: 7, max: maxDays, divisions: ((maxDays - 7) / 1).round(), onChanged: (v) => setState(() => _days = v)),
          ],
          if (_type == 'super_admin')
            Padding(padding: const EdgeInsets.only(top: 8), child: Text('Le super-administrateur a tous les droits.', style: TextStyle(color: c.textSecondary)))
          else ...[
            const SizedBox(height: 6),
            Text('Droits accordés', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w800)),
            for (final e in _all.entries.where((e) => e.key != 'staff.manage'))
              CheckboxListTile(
                key: ValueKey('team_perm_${e.key}'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _perms.contains(e.key),
                title: Text('${e.value}', style: const TextStyle(fontSize: 13.5)),
                subtitle: money.contains(e.key) ? Text('Droit d\'argent : validation par une autre personne', style: TextStyle(color: c.danger, fontSize: 11.5)) : null,
                onChanged: (v) => setState(() => v == true ? _perms.add('${e.key}') : _perms.remove(e.key)),
              ),
          ],
          if (needsApproval) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Cette demande devra être validée par une autre personne.', style: TextStyle(color: c.textSecondary, fontSize: 12.5))),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, style: TextStyle(color: c.danger))),
          const SizedBox(height: 10),
          FilledButton(key: const ValueKey('team_send'), onPressed: _busy || (_type != 'super_admin' && _perms.isEmpty) ? null : _send, child: Text(needsApproval ? 'Envoyer la demande' : 'Accorder les droits')),
        ],
        if (_user == null && _error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(_error!, style: TextStyle(color: c.danger))),
      ]),
    );
  }
}
